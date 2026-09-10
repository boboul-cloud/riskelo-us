//
//  CombatTests.swift
//  RiskeloUSTests
//
//  The variant fits in one sentence — "a correct answer is worth a higher
//  die" — and that is the sentence to nail down. The direction of the loss
//  flips on one character: if the attacker lost a troop on a wrong answer,
//  the game would still run, backwards, and nobody could say why they never
//  take anything.
//

import Foundation
import Testing
@testable import RiskeloUS

struct CombatTests {

    private func duel(_ allowance: TimeInterval = 15, siege: Int = 0) -> Duel {
        var rng = SeededRandom(seed: 1)
        let asked = QuestionBank.all[0].asked(using: &rng)
        return Duel(question: asked, allowance: allowance, siege: siege)
    }

    @Test func correctAnswerPushesTheAssaultBack() {
        let d = duel()
        let r = Combat.resolve(.chosen(d.question.answer, elapsed: 4), of: d)
        #expect(r.correct)
        #expect(r.outcome == .defenderHolds)
    }

    @Test func wrongAnswerOpensThePlace() {
        let d = duel()
        let wrong = (0..<4).first { $0 != d.question.answer }!
        let r = Combat.resolve(.chosen(wrong, elapsed: 4), of: d)
        #expect(!r.correct)
        #expect(r.outcome == .attackerBreaks)
    }

    @Test func silenceCountsAsAWrongAnswer() {
        let r = Combat.resolve(.timeout, of: duel())
        #expect(r.outcome == .attackerBreaks)
        #expect(r.dice.defender == 1)
    }

    /// Time is part of the question: right but late does not count.
    @Test func aCorrectButLateAnswerDoesNotCount() {
        let d = duel(15)
        let r = Combat.resolve(.chosen(d.question.answer, elapsed: 15.4), of: d)
        #expect(!r.correct)
        #expect(r.outcome == .attackerBreaks)
    }

    @Test func theDiceEquivalenceFollowsTheRule() {
        let d = duel(15)
        let fast = Combat.resolve(.chosen(d.question.answer, elapsed: 2), of: d)
        let slow = Combat.resolve(.chosen(d.question.answer, elapsed: 13), of: d)
        let wrong = Combat.resolve(.chosen((d.question.answer + 1) % 4, elapsed: 2), of: d)
        #expect(fast.dice.defender > fast.dice.attacker)
        #expect(slow.dice.defender > slow.dice.attacker)   // correct, so higher
        #expect(fast.dice.defender > slow.dice.defender)   // but fast is worth more
        #expect(wrong.dice.defender < wrong.dice.attacker)
    }

    /// The judgment, exercised over the whole bank: every question, several
    /// shuffles, and the four choices one after another. A single inversion —
    /// a `==` become a `!=`, an index shifted by a shuffle — would turn the
    /// game inside out without breaking anything, and nobody could say why
    /// they lose by answering correctly.
    @Test func noAnswerIsJudgedBackwards() {
        var rng = SeededRandom(seed: 77)
        for question in QuestionBank.all {
            for _ in 0 ..< 6 {
                let asked = question.asked(using: &rng)
                #expect(asked.choices[asked.answer] == question.correct,
                        "\(question.id): the shuffle lost the correct answer")
                let d = Duel(question: asked, allowance: 15, siege: 0)
                for i in asked.choices.indices {
                    let right = asked.choices[i] == question.correct
                    let r = Combat.resolve(.chosen(i, elapsed: 3), of: d)
                    #expect(r.correct == right, "\(question.id): \"\(asked.choices[i])\"")
                    #expect(r.outcome == (right ? .defenderHolds : .attackerBreaks))
                    #expect(right ? r.dice.defender > r.dice.attacker
                                  : r.dice.defender < r.dice.attacker)
                }
            }
        }
    }

    /// The machine always answers. A timeout marks no choice on screen: all
    /// you saw was the correct answer in green while the verdict announced
    /// silence, and you thought the app was judging a correct answer wrong.
    @Test func theMachineDoesNotLetTimeRunOut() {
        var rng = SeededRandom(seed: 21)
        var bank = QuestionBank()
        let rules = Rules()
        for level in [0.20, 0.45, 0.70, 0.95] {
            for _ in 0 ..< 300 {
                let asked = bank.draw(category: nil, difficulty: nil, using: &rng)!
                let d = Duel(question: asked, allowance: rules.answerTime(siege: 4), siege: 4)
                let answer = Bot.answer(to: d, level: level, rules: rules, using: &rng)
                #expect(answer != .timeout, "the machine went silent (level \(level))")
            }
        }
    }

    /// The wear of a siege: it is what replaces the attacker's statistical
    /// advantage in Risk. Without it, a player who knows never loses anything.
    @Test func theClockTightensWithEveryQuestion() {
        let r = Rules()
        let times = (0..<6).map { r.answerTime(siege: $0) }
        for (before, after) in zip(times, times.dropFirst()) {
            #expect(after <= before)
        }
        #expect(times[0] == r.baseSeconds)
        #expect(times.last == r.minSeconds)
        #expect(times[1] < times[0])
    }
}
