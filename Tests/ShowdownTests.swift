//
//  ShowdownTests.swift
//  RiskeloUSTests
//
//  The mode where both players answer.
//
//  Three rules are borrowed from the die here and only one of them shows on
//  screen; the other two silently decide the balance of the game: a strict tie
//  goes to the defender, and two ignorances count as a tie. Without them the
//  attacker would drop to 23% of exchanges and nobody would take a territory
//  any more. That is exactly the kind of rule a test has to hold, because a
//  game played inside out looks like a game.
//

import Foundation
import Testing
@testable import RiskeloUS

struct ShowdownTests {

    private var showdown: Rules {
        var r = Rules(); r.mode = .showdown; return r
    }

    private func duel(_ allowance: TimeInterval = 15) -> Duel {
        var rng = SeededRandom(seed: 1)
        return Duel(question: QuestionBank.all[0].asked(using: &rng),
                    allowance: allowance, siege: 0)
    }

    private func wrong(_ d: Duel) -> Int { (0..<4).first { $0 != d.question.answer }! }

    // MARK: - The four outcomes

    @Test func whoeverAloneKnowsWinsTheExchange() {
        let d = duel()
        let taken = Combat.resolveShowdown(defender: .chosen(wrong(d), elapsed: 3),
                                           attacker: .chosen(d.question.answer, elapsed: 9),
                                           of: d, stake: 1)
        #expect(taken.outcome == .attackerBreaks)
        #expect(taken.verdict == .onlyOne)
        // Slowness does not make up for ignorance: a fast ignoramus does not
        // beat a slow scholar.
        let holds = Combat.resolveShowdown(defender: .chosen(d.question.answer, elapsed: 14),
                                           attacker: .chosen(wrong(d), elapsed: 1),
                                           of: d, stake: 1)
        #expect(holds.outcome == .defenderHolds)
        #expect(holds.verdict == .onlyOne)
    }

    @Test func whenBothKnowTheClockSettlesIt() {
        let d = duel()
        let quick = Combat.resolveShowdown(defender: .chosen(d.question.answer, elapsed: 9),
                                           attacker: .chosen(d.question.answer, elapsed: 3),
                                           of: d, stake: 1)
        #expect(quick.outcome == .attackerBreaks)
        #expect(quick.verdict == .speed)
    }

    /// Risk's tie: you have to be quicker, not as quick.
    @Test func aStrictTieStaysWithTheDefender() {
        let d = duel()
        let r = Combat.resolveShowdown(defender: .chosen(d.question.answer, elapsed: 5),
                                       attacker: .chosen(d.question.answer, elapsed: 5),
                                       of: d, stake: 1)
        #expect(r.outcome == .defenderHolds)
    }

    /// Two ignorances count as a tie of dice: the place holds.
    @Test func nobodyKnowsAndThePlaceHolds() {
        let d = duel()
        let r = Combat.resolveShowdown(defender: .timeout, attacker: .chosen(wrong(d), elapsed: 2),
                                       of: d, stake: 1)
        #expect(r.outcome == .defenderHolds)
        #expect(r.verdict == .tie)
        #expect(!r.correct && !r.attackerCorrect)
    }

    // MARK: - The sequence of the two answers

    /// The first answer draws no blood, and above all shows nothing:
    /// revealing it would hand the solution to whoever still has to answer.
    @Test func theFirstAnswerSettlesNothing() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: showdown, seed: 42)
        g.debugSkipToAttack()
        guard let (base, target) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("no assault possible"); return
        }
        let declared = g.declareAssault(from: base, to: target, questions: 1, category: .history)
        #expect(declared)
        #expect(g.whoAnswers == g.assault?.defender)

        let beforeBase = g.armies(base), beforeTarget = g.armies(target)
        let nothing = g.answer(.chosen(0, elapsed: 3))
        #expect(nothing == nil, "the defender's answer returns no report")
        #expect(g.armies(base) == beforeBase && g.armies(target) == beforeTarget)
        #expect(g.assault?.current != nil, "the question stays open for the attacker")
        #expect(g.whoAnswers == g.assault?.attacker)

        let report = g.answer(.chosen(0, elapsed: 3))
        #expect(report != nil, "the second answer settles it")
        #expect(g.armies(base) + g.armies(target) == beforeBase + beforeTarget - 1)
    }

    /// In classic play, none of that: one answer, one report.
    @Test func classicSettlesOnTheFirstBlow() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                seed: 42)
        g.debugSkipToAttack()
        guard let (base, target) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("no assault possible"); return
        }
        let declared = g.declareAssault(from: base, to: target, questions: 1, category: .history)
        #expect(declared)
        #expect(!g.canRaise, "you do not raise in classic play")
        let settled = g.answer(.chosen(0, elapsed: 3))
        #expect(settled != nil)
    }

    // MARK: - The raise

    @Test func theRaiseDoublesWhatTheExchangeCosts() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: showdown, seed: 42)
        g.debugSkipToAttack()
        guard let (base, target) = g.debugFirstAssault(minArmies: 9, targetArmies: 5) else {
            Issue.record("no assault possible"); return
        }
        let declared = g.declareAssault(from: base, to: target, questions: 1, category: .history)
        #expect(declared)
        #expect(g.canRaise)
        g.raise()
        #expect(g.assault?.stake == 2)
        #expect(!g.canRaise, "you raise once only, and before answering")

        let right = g.assault!.current!.question.answer
        let wrong = (0..<4).first { $0 != right }!
        let beforeTarget = g.armies(target)
        _ = g.answer(.chosen(wrong, elapsed: 3))   // the defender does not know
        _ = g.answer(.chosen(right, elapsed: 3))   // the attacker does
        #expect(g.armies(target) == beforeTarget - 2, "a doubled stake costs two troops")
    }

    /// A stake of two only pays what the stack across the line can afford:
    /// the attacker is never stripped of their last garrison.
    @Test func theRaiseNeverEmptiesTheGarrison() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: showdown, seed: 42)
        g.debugSkipToAttack()
        guard let (base, target) = g.debugFirstAssault(minArmies: 2, targetArmies: 6) else {
            Issue.record("no assault possible"); return
        }
        let declared = g.declareAssault(from: base, to: target, questions: 1, category: .history)
        #expect(declared)
        g.raise()
        let right = g.assault!.current!.question.answer
        let wrong = (0..<4).first { $0 != right }!
        _ = g.answer(.chosen(right, elapsed: 3))   // the defender knows
        _ = g.answer(.chosen(wrong, elapsed: 3))   // the attacker does not
        #expect(g.armies(base) == 1, "the attacker always keeps one troop")
    }

    // MARK: - What the machine gains from it

    /// Both answer: the attacker's knowledge finally counts, and their
    /// scholarship reinforcement with it.
    @Test func theAttackersKnowledgeIsCounted() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: showdown, seed: 42)
        g.debugSkipToAttack()
        let me = g.currentPlayer.id
        guard let (base, target) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("no assault possible"); return
        }
        #expect(g.record(of: me, in: .history).asked == 0)
        let declared = g.declareAssault(from: base, to: target, questions: 1, category: .history)
        #expect(declared)
        let right = g.assault!.current!.question.answer
        _ = g.answer(.chosen(right, elapsed: 3))
        _ = g.answer(.chosen(right, elapsed: 8))
        #expect(g.record(of: me, in: .history).asked == 1,
                "the attacker answered: that has to count for them")
        #expect(g.record(of: me, in: .history).correct == 1)
    }

    /// The rule that changes sign from one mode to the other: the strong
    /// machine keeps its last pair in classic play, and uses it in a
    /// showdown. Measured — holding it back costs fourteen points against the
    /// medium machine.
    @Test func theLastPairServesInAShowdown() {
        for mode in Rules.Mode.allCases {
            var r = Rules(); r.mode = mode
            var g = GameState.start(
                players: [Player(id: 0, name: "A", kind: .machine(level: 0.7, style: .strong)),
                          Player(id: 1, name: "B")],
                rules: r, seed: 42)
            g.debugSkipToAttack()
            let me = g.currentPlayer.id
            // Everyone down to one troop, except a single base at two: the
            // strong machine has only its last pair to attack with.
            for id in g.map.order { g.seize(id, by: g.owner[id] ?? me, armies: 1) }
            guard let base = g.territories(of: me).first(where: { !g.targets(from: $0).isEmpty })
            else { Issue.record("no front line"); return }
            g.seize(base, by: me, armies: 2)
            // Boldness 2: that is `BotRunner`'s second try, the one that
            // accepts an assault at even strength. At boldness 1 a stack of
            // two clears no bar at all and the test would say nothing.
            var rng = SeededRandom(seed: 3)
            let plan = Bot.assault(g, boldness: 2, using: &rng)
            if mode == .classic {
                #expect(plan == nil, "in classic play it holds its last pair")
            } else {
                #expect(plan?.from == base, "in a showdown it uses it")
            }
        }
    }
}
