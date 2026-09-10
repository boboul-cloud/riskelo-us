//
//  Cards.swift
//  Riskelo US
//
//  Territory cards, the way the box has them.
//
//  One card per territory, plus two wild cards. You draw one at the end of a
//  turn in which you took at least one place — which is what rewards nerve
//  rather than waiting. Three matching cards trade for troops, and the scale
//  climbs with every exchange in the game: four, six, eight, ten, twelve,
//  fifteen, then five more each time. That is what keeps a game from bogging
//  down — the longer it runs, the heavier the exchanges weigh.
//
//  The rule is optional: it changes the economics of reinforcement, and the
//  board plays perfectly well without it.
//

import Foundation

struct Card: Codable, Equatable, Hashable, Identifiable {

    enum Symbol: Int, Codable, CaseIterable {
        case infantry, cavalry, artillery

        var label: String {
            switch self {
            case .infantry:  "Infantry"
            case .cavalry:   "Cavalry"
            case .artillery: "Artillery"
            }
        }

        var icon: String {
            switch self {
            case .infantry:  "figure.walk"
            case .cavalry:   "hare.fill"
            case .artillery: "burst.fill"
            }
        }
    }

    let id: Int
    /// The territory it carries. Absent, it is a wild card.
    let territory: TerritoryID?
    let symbol: Symbol

    var isWild: Bool { territory == nil }
}

enum Deck {

    /// A board's deck: one card per territory, two wild cards. Symbols are
    /// dealt round-robin, so that none is missing.
    static func build(for map: GameMap) -> [Card] {
        var cards = map.order.enumerated().map { rank, id in
            Card(id: rank, territory: id,
                 symbol: Card.Symbol.allCases[rank % Card.Symbol.allCases.count])
        }
        cards.append(Card(id: cards.count, territory: nil, symbol: .infantry))
        cards.append(Card(id: cards.count, territory: nil, symbol: .infantry))
        return cards
    }

    /// Do three cards make a set?
    ///
    /// Three identical symbols, or three different ones. A wild card stands
    /// in for anything — with one wild card, any two cards are always enough
    /// to complete one case or the other.
    static func isASet(_ cards: [Card]) -> Bool {
        guard cards.count == 3, Set(cards.map(\.id)).count == 3 else { return false }
        let real = cards.filter { !$0.isWild }.map(\.symbol)
        if real.count < 3 { return true }
        return Set(real).count == 1 || Set(real).count == 3
    }

    /// The first set found in a hand, if there is one.
    static func firstSet(in hand: [Card]) -> [Card]? {
        guard hand.count >= 3 else { return nil }
        for i in hand.indices {
            for j in hand.indices where j > i {
                for k in hand.indices where k > j {
                    let trio = [hand[i], hand[j], hand[k]]
                    if isASet(trio) { return trio }
                }
            }
        }
        return nil
    }

    /// The Risk scale: 4, 6, 8, 10, 12, 15, then five more at every exchange.
    /// `rank` is the number of the exchange within the game, starting at 1.
    static func value(forExchange rank: Int) -> Int {
        let scale = [4, 6, 8, 10, 12, 15]
        guard rank >= 1 else { return scale[0] }
        if rank <= scale.count { return scale[rank - 1] }
        return 15 + 5 * (rank - scale.count)
    }
}
