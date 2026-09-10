//
//  Objectives.swift
//  Riskelo US
//
//  The personal conquest: what each player is after, and only they know.
//
//  Without it a game has only one ending — holding the threshold number of
//  territories — and everyone sees it coming: you only have to count the
//  cells in the top bar to know where the other player stands. The personal
//  conquest makes that count misleading. Whoever looks behind may be holding
//  their two continents, and whoever leads does not know what is wanted of
//  them.
//
//  Three families, as in the box:
//
//      whole continents     — two big ones, or three small
//      territories held     — so many places, with so many troops on each
//      a side to bring down — and it has to be you who does it
//
//  The numbers of the original Risk are shares of the world and not absolute
//  counts: 24 territories out of 42 is 57%; 18 with two troops, 43%. Not
//  every board here has forty-two places, so it is the shares that carry
//  across.
//
//  Conquest is the only way to win when the rule is on. The domination
//  threshold withdrew badly from the game: it decided five games out of six
//  with two players, and every one of them with four. So only the whole board
//  is left, which is to say nobody is left.
//
//  A card cannot become impossible for all that: "bring down that side", when
//  someone else brings them down before you, turns over into a fallback —
//  four places out of five on the board. That is the one place where a
//  threshold survives, and it counts only for the player whose card has died.
//

import Foundation

enum Objective: Equatable, Hashable, Codable {

    /// Hold these continents whole, at the same time.
    case continents([ContinentID])

    /// Hold so many territories, with at least so many troops on each.
    case territories(count: Int, troops: Int)

    /// Wipe out a side — by your own hand. If they fall to someone else's
    /// blows, or if the side named is your own, the card turns over and
    /// becomes a territory conquest: that is Risk's rule, and it keeps an
    /// objective from becoming impossible through no fault of your own.
    case eliminate(PlayerID)

    // MARK: - The deck, cut to fit the board

    /// The shares of the world inherited from Risk, and the demand that goes
    /// with each.
    private static let shares: [(share: Double, troops: Int)] = [
        (0.57, 1),   // 24 territories out of 42
        (0.43, 2),   // 18 with two troops
        (0.29, 3),   // 12 with three
    ]

    /// What a personal conquest must not exceed: beyond this it would be
    /// harder than the domination threshold, and would stop being a shortcut.
    private static let maxShare = 0.60

    /// What the fallback carries: four places out of five on the board.
    ///
    /// With the domination threshold withdrawn, a card that turns over cannot
    /// turn over into something easy — bad luck would become a shortcut, and
    /// the player whose prey was killed would win faster than those who have
    /// to hold whole continents. So it is the fallback that now carries the
    /// threshold, and for that player alone.
    static let fallbackShare = 0.80

    /// The fallback: what a "bring down that side" card becomes when that
    /// side is no longer there to take.
    static func fallback(_ board: Board) -> Objective {
        .territories(count: count(fallbackShare, of: board), troops: 1)
    }

    private static func count(_ share: Double, of board: Board) -> Int {
        max(2, Int((Double(board.map.order.count) * share).rounded()))
    }

    /// Everything that can be asked on this board, in a stable order.
    ///
    /// Continents are taken by their size and not by their name: "two big
    /// ones" and "three small ones" only mean anything relative to the board,
    /// and the Ring has no Australia.
    static func deck(for board: Board, players: Int) -> [Objective] {
        let map = board.map
        let total = map.order.count
        let bySize = map.continentsInOrder.sorted {
            ($0.territories.count, $0.id) > ($1.territories.count, $1.id)
        }
        func size(_ ids: [ContinentID]) -> Int {
            ids.reduce(0) { $0 + (map.continents[$1]?.territories.count ?? 0) }
        }
        func holdable(_ ids: [ContinentID]) -> Bool {
            Double(size(ids)) / Double(total) <= maxShare
        }

        var deck: [Objective] = []

        // Two big continents. The top half of the board, two at a time.
        let big = Array(bySize.prefix(max(2, (bySize.count + 1) / 2)))
        for i in big.indices {
            for j in big.indices where j > i {
                let pair = [big[i].id, big[j].id]
                if holdable(pair) { deck.append(.continents(pair)) }
            }
        }

        // Three small ones. The four leanest, three at a time.
        let small = Array(bySize.suffix(min(4, max(3, bySize.count - 1))))
        for i in small.indices {
            for j in small.indices where j > i {
                for k in small.indices where k > j {
                    let trio = [small[i].id, small[j].id, small[k].id]
                    if holdable(trio) { deck.append(.continents(trio)) }
                }
            }
        }

        // Territories held, in three demands.
        for (share, troops) in shares {
            deck.append(.territories(count: count(share, of: board), troops: troops))
        }

        // Bring down a side. With two players that would amount to winning
        // the ordinary game — the card only joins the deck at three players
        // and above.
        if players >= 3 {
            for rank in 0 ..< players { deck.append(.eliminate(rank)) }
        }
        return deck
    }

    /// One card each, and never the same one twice.
    ///
    /// The draw goes through the game's own generator: two devices replaying
    /// the same moves must deal the same objectives, or they would not be
    /// playing the same game.
    static func deal<G: RandomNumberGenerator>(for board: Board, players: Int,
                                               using rng: inout G) -> [PlayerID: Objective] {
        var pile = deck(for: board, players: players)
        pile.shuffle(using: &rng)
        var dealt: [PlayerID: Objective] = [:]
        for rank in 0 ..< players {
            // Nobody is dealt their own disappearance.
            if let i = pile.firstIndex(where: { $0 != .eliminate(rank) }) {
                dealt[rank] = pile.remove(at: i)
            } else {
                dealt[rank] = fallback(board)
            }
        }
        return dealt
    }
}

// MARK: - What the objective asks, and where the player stands

extension GameState {

    /// This player's objective, as it counts **now**: the card dealt, or its
    /// fallback if that card has become impossible.
    func objective(of player: PlayerID) -> Objective? {
        guard let card = objectives[player] else { return nil }
        guard case let .eliminate(target) = card else { return card }
        if target == player { return Objective.fallback(board) }
        // Eliminated by someone else: the card turns over. Eliminated by you:
        // it is won, and stays what it is.
        if let killer = eliminated[target], killer != player { return Objective.fallback(board) }
        return card
    }

    /// Has the card turned over? The player then reads a fallback they did
    /// not draw, and they need to be told where it came from.
    func conquestTurnedOver(of player: PlayerID) -> Bool {
        guard let drawn = objectives[player] else { return false }
        return objective(of: player) != drawn
    }

    /// Is the objective met?
    func objectiveAchieved(_ player: PlayerID) -> Bool {
        guard rules.objectives, let card = objective(of: player) else { return false }
        switch card {
        case .continents(let ids):
            return ids.allSatisfy { holdsContinent($0, player) }
        case let .territories(count, troops):
            return territories(of: player, withAtLeast: troops) >= count
        case .eliminate(let target):
            return eliminated[target] == player
        }
    }

    /// Does this player hold this continent whole?
    func holdsContinent(_ id: ContinentID, _ player: PlayerID) -> Bool {
        guard let continent = map.continents[id] else { return false }
        return continent.territories.allSatisfy { owner[$0] == player }
    }

    /// How many places this player holds with at least so many troops.
    func territories(of player: PlayerID, withAtLeast troops: Int) -> Int {
        territories(of: player).filter { armies($0) >= troops }.count
    }

    /// The objective spelled out, for whoever is reading it.
    func text(_ card: Objective) -> String {
        card.text(board, sideName: playerName)
    }

    /// Where the player stands on their objective, in one line. It never says
    /// anything about the others: it is your own you are looking at.
    func progress(_ card: Objective, for player: PlayerID) -> String {
        switch card {
        case .continents(let ids):
            let held = ids.filter { holdsContinent($0, player) }.count
            let detail = ids.compactMap { id -> String? in
                guard let c = map.continents[id] else { return nil }
                let mine = c.territories.filter { owner[$0] == player }.count
                return "\(c.name) \(mine)/\(c.territories.count)"
            }
            return "\(held) of \(ids.count) — " + detail.joined(separator: " · ")
        case let .territories(count, troops):
            return "\(territories(of: player, withAtLeast: troops)) of \(count)"
        case .eliminate(let target):
            let left = territories(of: target).count
            return left == 0 ? "The side has fallen"
                             : "They have \(left) territor\(left == 1 ? "y" : "ies") left"
        }
    }

    // MARK: - Which gate the game was won through

    /// The phase records only the winner, never the reason. So it is read
    /// back from the final board — and it has to be announced: whoever won on
    /// the threshold used to see their conquest displayed under their name,
    /// without a word to say it had not counted, and thought the rule was
    /// broken.
    enum Gate { case conquest, threshold, wholeBoard }

    /// The whole board is read from the territories and not from the
    /// eliminated sides: the two say the same thing in a real game, and the
    /// count of places stays true for a position set up by hand.
    func victoryGate(_ player: PlayerID) -> Gate {
        if territories(of: player).count == map.order.count { return .wholeBoard }
        return objectiveAchieved(player) ? .conquest : .threshold
    }

    /// What ended the game, in one line, for the victory screen.
    func victoryGateText(_ player: PlayerID) -> String {
        switch victoryGate(player) {
        case .wholeBoard:
            return "The whole board, without a territory left behind."
        case .conquest:
            guard let card = objective(of: player) else { return "Their personal conquest." }
            return "Their personal conquest — \(text(card))"
        case .threshold:
            return "The threshold of \(dominationThreshold) territories out of \(map.order.count)."
        }
    }

    /// What goes in the log when the game is won this way.
    func objectiveStory(_ player: PlayerID) -> String {
        guard let card = objective(of: player) else { return "" }
        switch card {
        case .continents(let ids):
            let names = ids.compactMap { map.continents[$0]?.name }
            return "\(playerName(player)) held " + Objective.list(names)
                + " — that was their conquest."
        case let .territories(count, troops):
            return troops > 1
                ? "\(playerName(player)) holds \(count) places at "
                    + "\(Objective.spelledOut(troops)) troops — that was their conquest."
                : "\(playerName(player)) holds \(count) territories — that was their conquest."
        case .eliminate(let target):
            return "\(playerName(player)) brought down \(playerName(target)) — that was their conquest."
        }
    }
}

extension Objective {

    /// The objective spelled out, from the board alone.
    ///
    /// The manual lists the possible conquests before any game exists: it
    /// needs the same sentence, and above all it must not copy it out. A list
    /// written by hand would start lying the day a continent changes size, or
    /// the day a board is added.
    func text(_ board: Board, sideName: (PlayerID) -> String = Boards.sideName) -> String {
        switch self {
        case .continents(let ids):
            let names = ids.compactMap { board.map.continents[$0]?.name }
            return "Hold " + Objective.list(names) + " whole."
        case let .territories(count, troops):
            guard troops > 1 else { return "Hold \(count) territories." }
            return "Hold \(count) territories with at least "
                + "\(Objective.spelledOut(troops)) troops on each."
        case .eliminate(let target):
            return "Wipe out \(sideName(target))'s side — by your own hand."
        }
    }

    /// How many places the card asks for, when it asks for any. The sheet
    /// states the fallback in plain numbers rather than "80%": a player
    /// counts territories, not percentages.
    var countRequired: Int? {
        if case let .territories(count, _) = self { return count }
        return nil
    }

    /// "A", "A and B", "A, B, and C" — with the serial comma, as American
    /// usage wants it.
    static func list(_ words: [String]) -> String {
        guard let last = words.last else { return "" }
        guard words.count > 1 else { return last }
        guard words.count > 2 else { return words[0] + " and " + last }
        return words.dropLast().joined(separator: ", ") + ", and " + last
    }

    static func spelledOut(_ n: Int) -> String {
        switch n {
        case 1: "one"
        case 2: "two"
        case 3: "three"
        case 4: "four"
        default: "\(n)"
        }
    }
}
