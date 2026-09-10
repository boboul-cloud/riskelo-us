//
//  Helpers.swift
//  RiskeloUSTests
//
//  What it takes to bring a game to the point you want to examine, without
//  opening anything up in the engine: everything goes through ordinary moves,
//  plus the one door provided for it, `seize`.
//

import Foundation
@testable import RiskeloUS

extension GameState {

    /// Settles the reinforcements on your own lands and opens the attack
    /// phase.
    mutating func debugSkipToAttack() {
        guard case let .reinforcement(left) = phase else { return }
        let mine = territories(of: currentPlayer.id)[0]
        for _ in 0 ..< left { place(on: mine) }
    }

    mutating func debugSkipToFortify() {
        debugSkipToAttack()
        advance()
    }

    /// Sets up a clean assault: a base of your own, a neighboring enemy
    /// target, and the garrisons you want on each side.
    mutating func debugFirstAssault(minArmies: Int, targetArmies: Int)
    -> (base: TerritoryID, target: TerritoryID)? {
        let me = currentPlayer.id
        guard let base = territories(of: me).first(where: { !targets(from: $0).isEmpty }),
              let target = targets(from: base).first, let other = owner[target] else { return nil }
        seize(base, by: me, armies: minArmies)
        seize(target, by: other, armies: targetArmies)
        return (base, target)
    }
}

/// The themes that ship with the game, named for the tests.
///
/// Production code no longer names any theme — that was the whole point of
/// moving from an enum to a catalogue read from the folder. The tests, on the
/// other hand, exercise the real bank: they need to point at this one rather
/// than that one, and a test writing `Category("history")` twenty times would
/// read badly.
///
/// So these names live here, in the test target, and nowhere else. If one of
/// them disappeared from the questions folder, the tests would say so — which
/// is exactly what they are for.
///
/// `pack` points at one school pack in particular — the eighth-grade
/// history deck. Any of the sixteen would do; the tests only need one that
/// is sold rather than free.
///
/// The name is qualified: `Category` on its own is ambiguous in the test
/// target.
extension RiskeloUS.Category {
    static let geography = RiskeloUS.Category("geography")
    static let history   = RiskeloUS.Category("history")
    static let science   = RiskeloUS.Category("science")
    static let arts      = RiskeloUS.Category("arts")
    static let sports    = RiskeloUS.Category("sports")
    static let screen    = RiskeloUS.Category("screen")
    static let pack      = RiskeloUS.Category("history-8")
}
