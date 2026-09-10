//
//  Archives.swift
//  Riskelo US
//
//  The library of games: going back to them, not just finishing them.
//
//  There was already a save — the one that hands back the game in progress
//  from one launch to the next. It keeps a single state, the last one, and
//  overwrites it at every move. That is what resuming needs, and it is
//  exactly what going back must not have: by the moment you think "that is
//  where I lost it all", the instant in question was wiped long ago.
//
//  Hence three build decisions:
//
//  We save **every turn**, without being asked. A strategic moment is only
//  recognized afterwards: asking the player to remember to save before making
//  the mistake is offering them nothing at all. The "mark" button exists too,
//  but it is only an extra.
//
//  One file per moment, not one big file per game. A twenty-turn game
//  rewritten twenty times costs twenty times more than one written once per
//  turn, and an interrupted write would not take the other nineteen with it.
//
//  A separate, light index for the list. Opening twenty whole games to show
//  twenty rows would be absurd: the index carries the names, the dates and
//  the territory counts, and the states sleep until they are asked for.
//

import Foundation

/// A shelved game, as the list shows it.
struct ArchivedGame: Codable, Identifiable, Equatable {

    /// A moment of this game, one you can come back to.
    struct Moment: Codable, Identifiable, Equatable {
        var id = UUID()
        var turn: Int
        /// The side whose turn it was. `turn` counts rounds of the **table**,
        /// not player turns: without the side, a two-player game would keep
        /// only every other moment, and a four-player game one in four.
        var side: Int
        var date: Date
        var label: String
        /// The number of territories per side, at that very moment. It is
        /// here and not in the state so the list can draw the balance of
        /// power without opening a single file.
        var territories: [Int]
        var file: String
        /// Marked by hand by the player, or laid down by the passing turn.
        var marked = false
    }

    var id = UUID()
    var started: Date
    var last: Date
    var board: Boards
    var mode: Rules.Mode
    var players: [String]
    /// The seats held by the machine: enough to say who you were playing
    /// against.
    var bots: [Int]
    var moments: [Moment] = []
    /// The winner's seat, if the game ran to its end.
    var winner: Int?

    var isFinished: Bool { winner != nil }
}

/// The shelving.
///
/// Every write is atomic and none of them interrupts the game: an archive you
/// cannot write is an archive you will not have, and that is no reason to
/// stop playing.
struct Archives {

    static let shared = Archives()

    /// How many games are kept. Beyond that, the oldest goes.
    static let gamesKept = 12
    /// How many moments per game. Measured games run to four or twenty-three
    /// of them; eighty is a levee, not a useful ceiling.
    static let momentsKept = 80

    private let folder: URL

    /// The shelf can be moved: the tests write into a folder of their own
    /// rather than into the player's games.
    init(folder: URL? = nil) {
        let d = folder ?? {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil, create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            return base.appendingPathComponent("RiskeloUS/Games", isDirectory: true)
        }()
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        self.folder = d
    }

    private var indexURL: URL { folder.appendingPathComponent("index.json") }

    // MARK: - Reading

    func list() -> [ArchivedGame] {
        guard let data = try? Data(contentsOf: indexURL),
              let l = try? JSONDecoder().decode([ArchivedGame].self, from: data)
        else { return [] }
        return l.sorted { $0.last > $1.last }
    }

    func load(_ moment: ArchivedGame.Moment) -> GameState? {
        let url = folder.appendingPathComponent(moment.file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            // A board plan reworked since: better to refuse than to restore a
            // game that no longer lines up.
            print("Riskelo US — unreadable moment: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Writing

    /// Shelves one moment of the game. No effect if the turn is already
    /// shelved and this is not a mark from the player: we keep one moment per
    /// turn, not one per move.
    func store(_ g: GameState, game: UUID, label: String, marked: Bool = false) {
        var all = list()
        var p: ArchivedGame
        if let i = all.firstIndex(where: { $0.id == game }) {
            p = all.remove(at: i)
        } else {
            p = ArchivedGame(id: game, started: Date(), last: Date(),
                             board: g.boardKind, mode: g.rules.mode,
                             players: g.players.map(\.name),
                             bots: g.players.filter(\.isBot).map(\.id))
        }
        if !marked, p.moments.contains(where: {
            $0.turn == g.turn && $0.side == g.current && !$0.marked
        }) {
            all.append(p)
            write(all)
            return
        }
        guard marked || p.moments.count < Archives.momentsKept else {
            all.append(p); write(all); return
        }

        let counts = g.players.map { p in g.owner.values.filter { $0 == p.id }.count }
        let name = "\(game.uuidString)-\(p.moments.count).json"
        do {
            let data = try JSONEncoder().encode(g)
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        } catch {
            print("Riskelo US — moment not shelved: \(error)")
            all.append(p); write(all); return
        }

        p.moments.append(.init(turn: g.turn, side: g.current, date: Date(),
                               label: label, territories: counts,
                               file: name, marked: marked))
        p.last = Date()
        if case let .finished(w) = g.phase { p.winner = w }
        all.append(p)
        write(all)
    }

    func delete(_ id: UUID) {
        var all = list()
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        for m in all[i].moments {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(m.file))
        }
        all.remove(at: i)
        write(all)
    }

    /// Writes the index, and tidies up: games over the limit leave with their
    /// files, or the folder would grow without end.
    private func write(_ list: [ArchivedGame]) {
        var l = list.sorted { $0.last > $1.last }
        // A game with no moments at all has no business in the list.
        l.removeAll { $0.moments.isEmpty }
        while l.count > Archives.gamesKept {
            let oldest = l.removeLast()
            for m in oldest.moments {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(m.file))
            }
        }
        guard let data = try? JSONEncoder().encode(l) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
