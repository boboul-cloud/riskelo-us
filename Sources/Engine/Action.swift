//
//  Action.swift
//  Riskelo US
//
//  A move, as a value.
//
//  The engine already knew how to be changed by named methods; what it
//  lacked was a way to receive those moves in a form that travels. That is
//  the whole condition of play between two devices: each holds the same
//  game, and only what changes it is sent — a few dozen bytes per move
//  instead of copying the entire state.
//
//  This works only because the engine is reproducible: same moves, same
//  draw, same game. That is the property proved by game resumption, and the
//  test that guards it holds for the network too.
//

import Foundation

enum Action: Codable, Equatable {
    case place(TerritoryID)
    /// No category means "at random": the question is drawn from the whole
    /// bank.
    case declareAssault(from: TerritoryID, to: TerritoryID, questions: Int, category: Category?)
    case answer(Answer)
    /// The defender doubles the stake, in a showdown.
    case raise
    case dismissAssault
    case occupy(Int)
    case fortify(from: TerritoryID, to: TerritoryID, count: Int)
    case advance
    case endTurn
    /// Trading three cards for troops. Cards travel by their number: that is
    /// what makes them identical from one device to the other.
    case exchangeCards([Int])

    /// Who is allowed to play this move: whoever's turn it is, except around
    /// the duel. In classic play the defender alone answers; in a showdown
    /// both answer, each in turn, and it is the engine that says which.
    func author(in game: GameState) -> PlayerID? {
        switch self {
        case .answer: game.whoAnswers ?? game.assault?.defender
        case .raise: game.assault?.defender
        default: game.currentPlayer.id
        }
    }
}

extension GameState {

    /// The only path by which a game changes. Everything the interface does
    /// goes through here — and so everything that goes through here can be
    /// sent to the other device, or replayed.
    @discardableResult
    mutating func apply(_ action: Action) -> DuelReport? {
        switch action {
        case .place(let id):
            place(on: id)
        case let .declareAssault(from, to, questions, category):
            declareAssault(from: from, to: to, questions: questions, category: category)
        case .answer(let response):
            return answer(response)
        case .raise:
            raise()
        case .dismissAssault:
            dismissAssault()
        case .occupy(let n):
            occupy(n)
        case let .fortify(from, to, count):
            fortify(from: from, to: to, count: count)
        case .advance:
            advance()
        case .endTurn:
            endTurn()
        case .exchangeCards(let ids):
            exchange(ids)
        }
        return nil
    }

    /// A digest of the game, to check that the two devices have not drifted
    /// apart. Drift does not show: both screens display a coherent game, and
    /// they are two different games. Better to notice on the next move than
    /// at the end.
    var digest: UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func fold(_ v: Int) {
            h = (h ^ UInt64(bitPattern: Int64(v))) &* 0x100_0000_01b3
        }
        fold(turn); fold(current)
        for id in map.order {
            fold((owner[id] ?? -1) &* 97 &+ armies(id))
        }
        fold(assault?.asked ?? -1)
        fold(assault?.stake ?? 0)
        fold(exchanges)
        for p in players { fold(hand(of: p.id).count) }
        // Never `hashValue`: Swift salts it on every launch, and two healthy
        // devices would think they had drifted. The territory's rank, on the
        // other hand, is the same everywhere.
        fold(assault.flatMap { map.order.firstIndex(of: $0.from) } ?? -1)
        return h
    }
}
