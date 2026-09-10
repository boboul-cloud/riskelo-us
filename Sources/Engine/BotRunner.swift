//
//  BotRunner.swift
//  Riskelo US
//
//  The machine's turn, played one gesture at a time.
//
//  One gesture per call, and not the whole turn in a block: the interface
//  needs to breathe between two moves so you can see what is happening, while
//  the simulation only has to loop. The same code serves both — it is the
//  only way to be sure that what we simulate is what we play.
//

import Foundation

enum BotRunner {

    enum Step: Equatable {
        case exchanged(Int)
        case placed(TerritoryID)
        case declared(from: TerritoryID, to: TerritoryID)
        case answered(correct: Bool)
        /// Showdown: the first of the two answers. It settles nothing, it
        /// waits for the other.
        case pending
        case occupied(Int)
        case fortified
        case endedTurn
        /// A human has to answer: the machine stops and hands back control.
        case waitingForHuman
        /// Nothing left to do (game over, or not its turn).
        case idle
    }

    @discardableResult
    static func step(_ g: inout GameState, boldness: Double = 1.0) -> Step {
        guard !g.isOver else { return .idle }

        // A duel in progress takes priority over everything: somebody has to
        // answer.
        if let a = g.assault, let duel = a.current {
            // In a showdown it is no longer necessarily the defender: both
            // answer, each in turn, and the engine says which.
            guard let who = g.whoAnswers,
                  let responder = g.players.first(where: { $0.id == who }) else { return .idle }
            guard case let .machine(level, style) = responder.kind else { return .waitingForHuman }
            if g.canRaise, who == a.defender,
               Bot.shouldRaise(g, duel: duel, level: level, style: style, player: who) {
                g.raise()
            }
            let answer = Bot.answer(to: duel, level: level, rules: g.rules,
                                    player: who, using: &g.rng)
            guard let report = g.answer(answer) else { return .pending }
            return .answered(correct: report.correct)
        }
        if let a = g.assault, a.isOver, case .attack = g.phase {
            g.dismissAssault()
        }

        guard g.currentPlayer.isBot else { return .idle }

        switch g.phase {
        case .reinforcement(let remaining):
            // A set in hand goes out at once: the scale climbs with the
            // game's exchanges, so holding cards does not make them gain
            // value — it only lets the value climb for the opponent.
            if g.rules.territoryCards,
               let trio = Deck.firstSet(in: g.hand(of: g.currentPlayer.id)) {
                let value = g.nextExchangeValue
                if g.exchange(trio.map(\.id)) { return .exchanged(value) }
            }
            guard remaining > 0 else { g.advance(); return .idle }
            guard let id = Bot.reinforcement(g) else { g.advance(); return .idle }
            g.place(on: id)
            return .placed(id)

        case .attack:
            // The generator is taken out of the game, then handed straight
            // back: you cannot pass `g` by value and `&g.rng` in the same
            // call. It has to be handed back BEFORE `declareAssault`, which
            // uses it in turn to draw the question — leaving it to a `defer`
            // would overwrite the progress that call had just made, and the
            // following draws would repeat.
            var rng = g.rng
            // Failing an advantageous assault, an assault at even strength —
            // otherwise two cautious machines never meet.
            let choice = Bot.assault(g, boldness: boldness, using: &rng)
                ?? Bot.assault(g, boldness: boldness + 1, using: &rng)
            g.rng = rng
            guard let plan = choice else {
                g.advance()
                return .idle
            }
            guard g.declareAssault(from: plan.from, to: plan.to,
                                   questions: plan.questions, category: plan.category) else {
                g.advance()
                return .idle
            }
            return .declared(from: plan.from, to: plan.to)

        case .occupation:
            let n = Bot.occupation(g)
            g.occupy(n)
            return .occupied(n)

        case .fortify:
            if let move = Bot.fortification(g),
               g.fortify(from: move.from, to: move.to, count: move.count) {
                return .fortified
            }
            g.endTurn()
            return .endedTurn

        case .finished:
            return .idle
        }
    }

    /// Runs the machine's full turn. Hands back control as soon as a human
    /// has to answer, or when the turn has passed.
    @discardableResult
    static func runTurn(_ g: inout GameState, boldness: Double = 1.0, limit: Int = 4000) -> Step {
        let startedTurn = g.turn
        let startedPlayer = g.current
        for _ in 0 ..< limit {
            let step = step(&g, boldness: boldness)
            if step == .waitingForHuman { return step }
            if g.isOver { return .idle }
            if g.turn != startedTurn || g.current != startedPlayer { return .endedTurn }
            if step == .idle && !g.currentPlayer.isBot { return .idle }
        }
        return .idle
    }
}
