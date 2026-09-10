//
//  Persistence.swift
//  Riskelo US
//
//  Keeping the game in progress from one launch to the next.
//
//  The whole game state is already a value — that was the engine's bet — so
//  all that is needed is knowing how to write it. Three build decisions:
//
//  The board is not saved: it is regenerated from the plan, identically. We
//  keep its signature — the list of its territories — and set the save aside
//  if it no longer matches. A reworked plan must not restore a game that no
//  longer lines up, it must refuse it.
//
//  Nor is the question bank: only the list of those already asked is kept,
//  the questions themselves are in the bundle.
//
//  The random draw, on the other hand, is saved. Without it a resumed game
//  would no longer be the same one: it would be another game starting in the
//  same place.
//

import Foundation

// MARK: - What it takes to write the engine's values

extension SeededRandom: Codable {
    private enum CodingKeys: String, CodingKey { case state }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(seed: try c.decode(UInt64.self, forKey: .state))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rawState, forKey: .state)
    }
}

extension QuestionBank: Codable {
    private enum CodingKeys: String, CodingKey { case served, slots, seen }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        restore(served: try c.decode(Set<String>.self, forKey: .served))
        // The bag of slots travels with the bank. Missing, we start from a
        // full bag, which is without consequence.
        restore(slots: try c.decodeIfPresent([Int].self, forKey: .slots) ?? [])
        // The long memory travels too, and it is indispensable to the second
        // device: whoever joins receives the whole game and must draw exactly
        // the same questions as the host. If they started from their own
        // memory, the two screens would ask two different questions at the
        // same second.
        restore(seen: try c.decodeIfPresent([String: Int].self, forKey: .seen) ?? [:])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(alreadyServed, forKey: .served)
        try c.encode(remainingSlots, forKey: .slots)
        try c.encode(alreadySeen, forKey: .seen)
    }
}

// MARK: - The game

extension GameState: Codable {

    private enum CodingKeys: String, CodingKey {
        case board, signature, rules, players, owner, armies, current, phase, assault
        case siege, knowledge, lastCategoryAgainst, bonusPaid, turn, journal, bank, rng
        case deck, discard, hands, exchanges, conqueredThisTurn, objectives, eliminated
    }

    /// What identifies the board: the list of its territories, in order. Two
    /// different plans cannot share it.
    static func signature(of board: Board) -> String {
        board.map.order.joined(separator: ",")
    }

    enum LoadError: Error, LocalizedError {
        case otherBoard
        var errorDescription: String? {
            "This game was played on another board."
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // The board itself is not saved: we note which one it was, and check
        // that its drawing has not changed since.
        let board = try c.decodeIfPresent(Boards.self, forKey: .board) ?? .ring
        guard try c.decode(String.self, forKey: .signature) == GameState.signature(of: board.board)
        else { throw LoadError.otherBoard }
        self.init(restoring: board,
                  rules: try c.decode(Rules.self, forKey: .rules),
                  players: try c.decode([Player].self, forKey: .players),
                  bank: try c.decode(QuestionBank.self, forKey: .bank),
                  rng: try c.decode(SeededRandom.self, forKey: .rng),
                  owner: try c.decode([TerritoryID: PlayerID].self, forKey: .owner),
                  armies: try c.decode([TerritoryID: Int].self, forKey: .armies),
                  current: try c.decode(Int.self, forKey: .current),
                  phase: try c.decode(Phase.self, forKey: .phase),
                  assault: try c.decodeIfPresent(Assault.self, forKey: .assault),
                  siege: try c.decode([TerritoryID: Int].self, forKey: .siege),
                  knowledge: try c.decode([PlayerID: [Category: Score]].self, forKey: .knowledge),
                  lastCategoryAgainst: try c.decode([PlayerID: Category].self,
                                                    forKey: .lastCategoryAgainst),
                  // These fields are read leniently: a state written by a
                  // half-finished build, or truncated on disk, should degrade
                  // into a playable game rather than into nothing at all.
                  bonusPaid: try c.decodeIfPresent([PlayerID: Int].self, forKey: .bonusPaid) ?? [:],
                  deck: try c.decodeIfPresent([Card].self, forKey: .deck) ?? [],
                  discard: try c.decodeIfPresent([Card].self, forKey: .discard) ?? [],
                  hands: try c.decodeIfPresent([PlayerID: [Card]].self, forKey: .hands) ?? [:],
                  exchanges: try c.decodeIfPresent(Int.self, forKey: .exchanges) ?? 0,
                  conqueredThisTurn: try c.decodeIfPresent(Bool.self,
                                                           forKey: .conqueredThisTurn) ?? false,
                  objectives: try c.decodeIfPresent([PlayerID: Objective].self,
                                                    forKey: .objectives) ?? [:],
                  eliminated: try c.decodeIfPresent([PlayerID: PlayerID].self,
                                                    forKey: .eliminated) ?? [:],
                  turn: try c.decode(Int.self, forKey: .turn),
                  journal: try c.decode([Entry].self, forKey: .journal))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(boardKind, forKey: .board)
        try c.encode(GameState.signature(of: board), forKey: .signature)
        try c.encode(rules, forKey: .rules)
        try c.encode(players, forKey: .players)
        try c.encode(owner, forKey: .owner)
        try c.encode(armies, forKey: .armies)
        try c.encode(current, forKey: .current)
        try c.encode(phase, forKey: .phase)
        try c.encodeIfPresent(assault, forKey: .assault)
        try c.encode(siege, forKey: .siege)
        try c.encode(knowledge, forKey: .knowledge)
        try c.encode(lastCategoryAgainst, forKey: .lastCategoryAgainst)
        try c.encode(bonusPaid, forKey: .bonusPaid)
        try c.encode(deck, forKey: .deck)
        try c.encode(discard, forKey: .discard)
        try c.encode(hands, forKey: .hands)
        try c.encode(exchanges, forKey: .exchanges)
        try c.encode(conqueredThisTurn, forKey: .conqueredThisTurn)
        try c.encode(objectives, forKey: .objectives)
        try c.encode(eliminated, forKey: .eliminated)
        try c.encode(turn, forKey: .turn)
        try c.encode(journal, forKey: .journal)
        try c.encode(bank, forKey: .bank)
        try c.encode(rng, forKey: .rng)
    }
}

// MARK: - The drawer

/// Where the game in progress sleeps.
///
/// A file, and not the system settings: a game is a document. The write is
/// atomic — a power cut in the middle of saving would otherwise leave a
/// half-written file, which is a game lost while believing it saved.
struct GameStore {

    static let shared = GameStore()

    private let url: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("RiskeloUS", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("game-in-progress.json")
    }()

    /// The identity of the game in progress within the library. It lives
    /// beside the state, not inside it: changing it does not invalidate the
    /// saves already written.
    private var idURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("game-in-progress-id.txt")
    }

    var hasSavedGame: Bool { FileManager.default.fileExists(atPath: url.path) }

    func saveID(_ id: UUID) {
        try? id.uuidString.write(to: idURL, atomically: true, encoding: .utf8)
    }

    func loadID() -> UUID? {
        (try? String(contentsOf: idURL, encoding: .utf8)).flatMap(UUID.init)
    }

    func save(_ game: GameState) {
        do {
            let data = try JSONEncoder().encode(game)
            try data.write(to: url, options: .atomic)
        } catch {
            // A failed save must not interrupt a game: we will try again on
            // the next move, and there is one every second.
            print("Riskelo US — could not save: \(error)")
        }
    }

    func load() -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            // A save from another board, or from a build that no longer reads
            // back: we set it aside rather than resume a game that is wrong.
            print("Riskelo US — save set aside: \(error.localizedDescription)")
            discard()
            return nil
        }
    }

    func discard() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - The question memory

/// What this device has already seen go by, from one game to the next.
///
/// A game does not know this by itself: it opens with a fresh bank, draws
/// from the full bag, and therefore asks yesterday's questions again. Someone
/// playing alone runs games back to back, and they are the only one it leaps
/// out at — they recognize the question before having read it, and the duel
/// stops deciding anything.
///
/// The count is kept here, beside the game and in the same form: a file,
/// because it is a register of a thousand lines that grows, and not a
/// setting. It survives the game, the archives and resumption; it does not
/// survive being uninstalled, and that is as it should be.
struct QuestionMemory {

    static let shared = QuestionMemory()

    private let url: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("RiskeloUS", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("questions-already-asked.json")
    }()

    /// How many times each question has already come up.
    func load() -> [String: Int] {
        guard let data = try? Data(contentsOf: url),
              let count = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return count
    }

    /// The write is atomic, like the game's: a cut in the middle would leave
    /// an unreadable file, and therefore a lost memory.
    func save(_ counts: [String: Int]) {
        guard let data = try? JSONEncoder().encode(counts) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Forget everything. A player who has been all the way through the bank
    /// may want to take it fresh rather than watch it repeat on the second
    /// pass.
    func forget() {
        try? FileManager.default.removeItem(at: url)
    }

    /// How many different questions have already come up. It is the only
    /// figure shown to the player.
    func distinctSeen() -> Int { load().count }
}
