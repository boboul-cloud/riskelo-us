//
//  Combat.swift
//  Riskelo US
//
//  The duel: one question in place of a pair of dice.
//
//  The rule fits in two lines. The attacker picks a category and asks one or
//  two questions — their dice. The defender answers.
//
//      correct answer            → the defender's die is higher → the attacker loses a soldier
//      wrong, or time runs out   → the attacker's die wins      → the defender loses a soldier
//
//  A pair of dice, one loss: that is exactly Risk's comparison, and the bet
//  is the same — two questions means two possible losses on your own side.
//
//  A tie, in Risk, favors the defender. It has no equivalent in classic play:
//  a question has no draw. The principle survives — doubt stays on the side
//  of whoever holds the place.
//
//  In a **showdown** it finds one again. Both players answer the same
//  question, and there is no longer one answer but two to compare:
//
//      only one knows      → they win the exchange
//      both know           → the quicker wins, a tie goes to the defender
//      neither knows       → the place holds, the attacker leaves a troop
//
//  That is where, and only where, speed decides anything. It never separates
//  two unequal answers — a fast ignoramus does not beat a slow scholar — it
//  serves only to settle what Risk settled with the number on the die.
//

import Foundation

/// What the defender did with the question.
enum Answer: Equatable, Codable {
    case chosen(Int, elapsed: TimeInterval)
    case timeout
}

enum DuelOutcome: Equatable {
    /// Correct answer: the place holds, the attacker leaves a troop.
    case defenderHolds
    /// Wrong answer or silence: the line gives way.
    case attackerBreaks
}

/// The question in play, with the time allowed for it.
struct Duel: Equatable, Codable {
    let question: AskedQuestion
    let allowance: TimeInterval
    /// How many questions this territory has already faced this turn.
    let siege: Int
}

/// The equivalent in dice. It decides nothing — it shows the rule. A correct
/// answer comes out above the assault, the higher the faster it arrived; a
/// wrong one comes out below.
///
/// In classic play it is half mute: since the attacker does not answer, their
/// die is a 3 by convention. In a showdown both faces are real.
struct DiceEquivalence: Equatable {
    var attacker: Int
    var defender: Int

    /// What an answer is worth, on six faces.
    static func face(_ answer: Answer?, allowance: TimeInterval, correct: Bool) -> Int {
        guard correct, case let .chosen(_, elapsed)? = answer else {
            return answer == .timeout ? 1 : 2
        }
        let part = allowance > 0 ? elapsed / allowance : 1
        return part < 0.34 ? 6 : (part < 0.67 ? 5 : 4)
    }

    static func from(_ answer: Answer, allowance: TimeInterval, correct: Bool) -> DiceEquivalence {
        DiceEquivalence(attacker: 3,
                        defender: face(answer, allowance: allowance, correct: correct))
    }
}

/// How the exchange was decided. This is what the sheet tells the player, and
/// it is the one thing that really changes from one mode to the other.
enum DuelVerdict: String, Equatable, Codable {
    /// Classic: the defender alone was answering.
    case answered
    /// Showdown: only one of the two knew.
    case onlyOne
    /// Showdown: both knew, the hourglass settled it.
    case speed
    /// Showdown: neither knew. The place holds — Risk's tie.
    case tie
}

/// The report of a duel, as the view tells it.
struct DuelReport: Equatable, Identifiable {
    let id = UUID()
    let question: AskedQuestion
    /// The defender's: they are the one who answers in both modes.
    let answer: Answer
    let correct: Bool
    /// In a showdown, what the attacker answered.
    var attackerAnswer: Answer?
    var attackerCorrect = false
    let outcome: DuelOutcome
    var verdict: DuelVerdict = .answered
    /// What the exchange costs the loser: one troop, two if the defender had
    /// raised.
    var stake = 1
    let dice: DiceEquivalence
    let allowance: TimeInterval

    static func == (a: DuelReport, b: DuelReport) -> Bool { a.id == b.id }
}

/// An assault: a declaration, then one or two questions.
struct Assault: Equatable, Codable {
    let attacker: PlayerID
    let defender: PlayerID
    let from: TerritoryID
    let to: TerritoryID
    /// The category, chosen by the attacker. That is where their skill lies:
    /// they answer nothing, but they choose the ground.
    ///
    /// Absent means they did not choose it: the question is drawn from the
    /// whole bank, themes included. The attacker gives up their only
    /// advantage — in a showdown, where they answer too, it is a ground they
    /// do not pick for themselves either.
    let category: Category?
    /// The number of questions declared: one die or two.
    let volley: Int

    /// Showdown: the defender's answer waits for the attacker's. Showing it
    /// earlier would hand the solution to someone who still has to answer —
    /// that is the only reason it sleeps here.
    var defenderAnswer: Answer?

    /// The defender's stake. One troop, or two if they raised: that is their
    /// second die, the one Risk gives them and classic mode refused them.
    var stake = 1

    var asked = 0
    var attackerLosses = 0
    var defenderLosses = 0
    var conquered = false
    var current: Duel?
    var reports: [DuelReport] = []

    /// The assault is over when the place is taken or the volley spent.
    var isOver: Bool { conquered || (current == nil && asked >= volley) }

    static func == (a: Assault, b: Assault) -> Bool {
        a.from == b.from && a.to == b.to && a.asked == b.asked
            && a.conquered == b.conquered && a.current == b.current
    }

    /// The reports are not saved: they serve only the summary of an assault
    /// in progress, and a resumed game restarts from the question asked, not
    /// from its summary.
    private enum CodingKeys: String, CodingKey {
        case attacker, defender, from, to, category, volley
        case asked, attackerLosses, defenderLosses, conquered, current
        case defenderAnswer, stake
    }
}

enum Combat {

    /// Is an answer correct? Time is part of the question: arriving after the
    /// hourglass, it does not count, even if exact.
    static func isCorrect(_ answer: Answer, of duel: Duel) -> Bool {
        switch answer {
        case .timeout: false
        case let .chosen(index, elapsed):
            duel.question.isCorrect(index) && elapsed <= duel.allowance
        }
    }

    /// The time taken, capped at the hourglass. That is what separates two
    /// correct answers, and nothing else.
    static func timeTaken(_ answer: Answer, of duel: Duel) -> TimeInterval {
        guard case let .chosen(_, elapsed) = answer else { return duel.allowance }
        return min(elapsed, duel.allowance)
    }

    /// Classic: the one place where the outcome of a question is decided.
    static func resolve(_ answer: Answer, of duel: Duel) -> DuelReport {
        let correct = isCorrect(answer, of: duel)
        return DuelReport(question: duel.question,
                          answer: answer,
                          correct: correct,
                          outcome: correct ? .defenderHolds : .attackerBreaks,
                          dice: .from(answer, allowance: duel.allowance, correct: correct),
                          allowance: duel.allowance)
    }

    /// Showdown: both answered the same question.
    static func resolveShowdown(defender: Answer, attacker: Answer,
                                of duel: Duel, stake: Int) -> DuelReport {
        let d = isCorrect(defender, of: duel)
        let a = isCorrect(attacker, of: duel)

        let outcome: DuelOutcome
        let verdict: DuelVerdict
        switch (d, a) {
        case (true, false):
            outcome = .defenderHolds
            verdict = .onlyOne
        case (false, true):
            outcome = .attackerBreaks
            verdict = .onlyOne
        case (true, true):
            // Both know. The hourglass settles it, and a strict tie stays
            // with the defender: you have to be quicker, not as quick.
            outcome = timeTaken(attacker, of: duel) < timeTaken(defender, of: duel)
                ? .attackerBreaks : .defenderHolds
            verdict = .speed
        case (false, false):
            // Nobody knew. In Risk a tie costs the attacker a troop: the
            // place holds.
            outcome = .defenderHolds
            verdict = .tie
        }

        return DuelReport(question: duel.question,
                          answer: defender,
                          correct: d,
                          attackerAnswer: attacker,
                          attackerCorrect: a,
                          outcome: outcome,
                          verdict: verdict,
                          stake: stake,
                          dice: DiceEquivalence(
                            attacker: DiceEquivalence.face(attacker,
                                                           allowance: duel.allowance, correct: a),
                            defender: DiceEquivalence.face(defender,
                                                           allowance: duel.allowance, correct: d)),
                          allowance: duel.allowance)
    }
}
