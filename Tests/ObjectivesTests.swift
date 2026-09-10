//
//  ObjectivesTests.swift
//  RiskeloUSTests
//
//  A personal conquest is played in secret: it therefore cannot be checked by
//  playing. If it fills without anyone noticing, or becomes impossible
//  without turning over, nobody will report it — the player will simply think
//  the game went wrong.
//

import Foundation
import Testing
@testable import RiskeloUS

struct ObjectivesTests {

    private func withObjectives() -> Rules {
        var r = Rules()
        r.objectives = true
        return r
    }

    private func game(_ n: Int = 2, seed: UInt64 = 42) -> GameState {
        GameState.start(players: (0..<n).map { Player(id: $0, name: "P\($0)") },
                        rules: withObjectives(), seed: seed)
    }

    /// The whole board to one side: enough to set up a position without the
    /// opening deal counting behind the test's back.
    private func clear(_ g: inout GameState, to player: PlayerID = 1) {
        for id in g.map.order { g.seize(id, by: player, armies: 1) }
    }

    // MARK: - The deck and the deal

    @Test func everyoneGetsOneConquestAndOnlyOne() {
        var rng = SeededRandom(seed: 3)
        let dealt = Objective.deal(for: Boards.world.board, players: 4, using: &rng)
        #expect(dealt.count == 4)
        #expect(Set(dealt.values).count == 4, "two players were dealt the same conquest")
        for (seat, card) in dealt {
            #expect(card != .eliminate(seat), "nobody is asked to disappear")
        }
    }

    /// Both devices replay the same game: they have to deal the same
    /// conquests, or each plays a different game without knowing it.
    @Test func theDealIsReproducible() {
        var a = SeededRandom(seed: 9), b = SeededRandom(seed: 9)
        let here = Objective.deal(for: Boards.ring.board, players: 3, using: &a)
        let there = Objective.deal(for: Boards.ring.board, players: 3, using: &b)
        #expect(here == there)
    }

    /// With two players, "bring down the side across the table" is not a
    /// personal conquest: it is the ordinary game.
    @Test func withTwoPlayersEliminationStaysOutOfTheDeck() {
        let deck = Objective.deck(for: Boards.ring.board, players: 2)
        #expect(!deck.contains { if case .eliminate = $0 { true } else { false } })
        #expect(Objective.deck(for: Boards.ring.board, players: 3)
            .contains { if case .eliminate = $0 { true } else { false } })
    }

    /// Every board must have enough to serve four players, and no conquest
    /// may ask for more than the domination threshold — it would stop being a
    /// shortcut and become a detour.
    @Test(arguments: Boards.allCases)
    func everyBoardHasEnoughToDeal(_ board: Boards) {
        let b = board.board
        let deck = Objective.deck(for: b, players: 4)
        #expect(deck.count >= 8, "\(board.label): only \(deck.count) conquests")

        let threshold = Rules().dominationThreshold(territories: b.map.order.count,
                                                    playerCount: 2)
        for card in deck {
            switch card {
            case .continents(let ids):
                let size = ids.reduce(0) { $0 + (b.map.continents[$1]?.territories.count ?? 0) }
                #expect(size < threshold,
                        "\(board.label): \(ids) asks for \(size) places against a threshold of \(threshold)")
            case let .territories(count, _):
                #expect(count <= threshold,
                        "\(board.label): \(count) places asked against a threshold of \(threshold)")
            case .eliminate:
                break
            }
        }
    }

    // MARK: - What they ask for

    @Test func holdingTheContinentsAskedFor() {
        var g = game()
        let aimed = g.map.continentsInOrder.prefix(2).map(\.id)
        clear(&g)
        g.seize(objective: .continents(Array(aimed)), of: 0)
        #expect(!g.objectiveAchieved(0))

        for id in aimed.dropLast() {
            for t in g.map.continents[id]!.territories { g.seize(t, by: 0, armies: 1) }
        }
        #expect(!g.objectiveAchieved(0), "one continent out of two is not enough")

        for t in g.map.continents[aimed.last!]!.territories { g.seize(t, by: 0, armies: 1) }
        #expect(g.objectiveAchieved(0))
    }

    /// "Hold so many places with two troops" does not count places held with
    /// one: that is the whole difference between the two cards.
    @Test func placesCountTheirTroops() {
        var g = game()
        clear(&g)
        let mine = Array(g.map.order.prefix(4))
        for id in mine { g.seize(id, by: 0, armies: 1) }
        g.seize(objective: .territories(count: 3, troops: 2), of: 0)
        #expect(g.territories(of: 0, withAtLeast: 1) == 4)
        #expect(!g.objectiveAchieved(0), "four places at one troop are not three at two")

        for id in mine.prefix(3) { g.seize(id, by: 0, armies: 2) }
        #expect(g.objectiveAchieved(0))
    }

    @Test func eliminationCountsWhenYouAreTheOneWhoDidIt() {
        var g = game(3)
        g.seize(objective: .eliminate(2), of: 0)
        #expect(!g.objectiveAchieved(0))
        g.seize(eliminated: 2, by: 0)
        #expect(g.objectiveAchieved(0))
    }

    /// The card turns over when a third party takes your prey: without that
    /// the objective would become impossible through no fault of your own,
    /// and the player would spend the rest of the game unable to win.
    @Test func theCardTurnsOverWhenSomeoneElseBringsTheTargetDown() {
        var g = game(3)
        g.seize(objective: .eliminate(2), of: 0)
        #expect(g.objective(of: 0) == .eliminate(2))
        g.seize(eliminated: 2, by: 1)
        #expect(g.objective(of: 0) == Objective.fallback(g.board))
        #expect(!g.objectiveAchieved(0), "the fallback is not won by itself")
    }

    /// And likewise if the draw names your own side — the deck avoids it, but
    /// a save from another version could carry it.
    @Test func youAreNeverAskedToWipeYourselfOut() {
        var g = game(3)
        g.seize(objective: .eliminate(0), of: 0)
        #expect(g.objective(of: 0) == Objective.fallback(g.board))
    }

    // MARK: - The end of the game

    @Test func theGameStopsAsSoonAsTheConquestIsFilled() {
        var g = game()
        clear(&g)
        let mine = Array(g.map.order.prefix(2))
        for id in mine { g.seize(id, by: 0, armies: 1) }
        g.seize(objective: .territories(count: 2, troops: 2), of: 0)

        #expect(!g.isOver)
        g.place(on: mine[0])
        #expect(!g.isOver, "one place out of two does not end the game")
        g.place(on: mine[1])
        #expect(g.isOver)
        if case let .finished(winner) = g.phase {
            #expect(winner == 0)
        } else {
            Issue.record("the game should have been won")
        }
        #expect(g.journal.last?.kind == .end)
    }

    /// Without the rule, nothing is dealt and nothing is checked: the game is
    /// exactly what it was before.
    @Test func withoutTheRuleNothingChanges() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: Rules(), seed: 7)
        #expect(g.objectives.isEmpty)
        g.seize(objective: .territories(count: 1, troops: 1), of: 0)
        #expect(!g.objectiveAchieved(0), "with the rule off, the conquest does not count")
    }

    @Test func conquestsSurviveTheSave() throws {
        var g = game(3)
        g.seize(eliminated: 2, by: 1)
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(g))
        #expect(back.objectives == g.objectives)
        #expect(back.eliminated == g.eliminated)
        #expect(!back.objectives.isEmpty, "the game should have dealt some")
    }

    /// What the player reads. A conquest that cannot be put into words is no
    /// use: it is the only place they learn what is being asked of them.
    @Test func everyConquestCanBeSaid() {
        var g = game(3)
        for card in Objective.deck(for: g.board, players: 3) {
            g.seize(objective: card, of: 0)
            let text = g.text(card)
            #expect(text.count > 12 && text.hasSuffix("."), "badly said: \(text)")
            #expect(!g.progress(card, for: 0).isEmpty)
        }
    }

    // MARK: - The threshold withdraws

    /// The rule as intended: conquest decides, or nobody does. The threshold
    /// must no longer be able to win a game with conquests — it won five
    /// games out of six with two players, and all of them with four.
    @Test(arguments: Boards.allCases)
    func theThresholdWithdrawsBeforeConquests(_ board: Boards) {
        let total = board.board.map.order.count
        for sides in 2 ... 4 {
            var r = Rules(); r.objectives = true
            #expect(r.dominationThreshold(territories: total, playerCount: sides) == total,
                    "\(board.label) at \(sides): the threshold still comes before conquest")
            #expect(Rules().dominationThreshold(territories: total, playerCount: sides) < total,
                    "without the rule, the threshold must stay what it was")
        }
    }

    /// The whole board minus one place does not win: there is no count left
    /// to cross, and that is the entire point.
    @Test func holdingNearlyEverythingDoesNotWin() {
        var g = game()
        clear(&g, to: 0)
        g.seize(g.map.order.last!, by: 1, armies: 1)
        g.seize(objective: .continents([g.map[g.map.order.last!]!.continent]), of: 0)
        #expect(!g.dominates(0), "27 places out of 28 are not a victory")
        #expect(!g.objectiveAchieved(0))
    }

    /// The fallback carries the threshold, and for that player alone. Any
    /// cheaper and bad luck would become a shortcut: the player whose prey
    /// was killed would win faster than those who have to hold whole
    /// continents.
    @Test(arguments: Boards.allCases)
    func theFallbackAsksForFourPlacesOutOfFive(_ board: Boards) {
        let total = board.board.map.order.count
        guard case let .territories(count, troops) = Objective.fallback(board.board) else {
            Issue.record("the fallback has to be a territory conquest"); return
        }
        #expect(troops == 1)
        #expect(count == Int((Double(total) * 0.80).rounded()),
                "\(board.label): \(count) places instead of four out of five")
        for card in Objective.deck(for: board.board, players: 4) {
            if case let .territories(asked, required) = card, required == 1 {
                #expect(asked < count,
                        "\(board.label): the fallback has to cost more than the ordinary card, or a dead card is a windfall")
            }
        }
    }

    // MARK: - Which gate the game was won through

    /// The victory screen has to say. Winning on the threshold with your
    /// conquest displayed just below, unmet and without a word of
    /// explanation, reads like a broken rule.
    @Test func theVictoryScreenSaysWhichGate() {
        var g = game()
        clear(&g, to: 0)
        #expect(g.victoryGate(0) == .wholeBoard)

        // One place left to the other side, and the conquest met.
        g.seize(g.map.order.last!, by: 1, armies: 1)
        g.seize(objective: .territories(count: 2, troops: 1), of: 0)
        #expect(g.victoryGate(0) == .conquest)
        #expect(g.victoryGateText(0).contains(g.text(g.objective(of: 0)!)))

        // Without the rule, the threshold wins, and it names itself.
        var plain = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                    rules: Rules(), seed: 42)
        for id in plain.map.order.dropLast() { plain.seize(id, by: 0, armies: 1) }
        plain.seize(plain.map.order.last!, by: 1, armies: 1)
        #expect(plain.victoryGate(0) == .threshold)
        #expect(plain.victoryGateText(0).contains("\(plain.dominationThreshold) territories"))
    }

    /// What the log keeps when the card pays: the conquest's own sentence,
    /// and not a count of territories. It is what you reread to understand
    /// why the game stopped there.
    @Test func theLogTellsTheConquestWhenItWins() {
        var g = game()
        let aimed = g.map.continentsInOrder.sorted { $0.territories.count > $1.territories.count }
            .prefix(2).map(\.id)
        g.seize(objective: .continents(Array(aimed)), of: 0)
        clear(&g, to: 0)

        // One place of the first continent stays with the other side, plus a
        // few lands elsewhere so it survives that continent's fall.
        let missing = g.map.continents[aimed[0]]!.territories[0]
        let elsewhere = g.map.order.filter { id in
            !aimed.contains { g.map.continents[$0]!.territories.contains(id) }
        }.prefix(4)
        for id in elsewhere { g.seize(id, by: 1, armies: 1) }
        g.seize(missing, by: 1, armies: 1)

        let base = g.map.neighbors(of: missing).first { g.owner[$0] == 0 }!
        g.seize(base, by: 0, armies: 6)
        g.debugSkipToAttack()
        #expect(!g.dominates(0), "the threshold must no longer be able to win this game")
        #expect(!g.objectiveAchieved(0))

        // The defender is the one who answers: their wrong answer costs them
        // the place.
        g.declareAssault(from: base, to: missing, questions: 1, category: .history)
        let wrong = (g.assault!.current!.question.answer + 1) % 4
        g.answer(.chosen(wrong, elapsed: 2))
        #expect(g.isOver, "a conquest filled has to stop the game on the spot")
        #expect(g.victoryGate(0) == .conquest)
        #expect(g.journal.last?.text == g.objectiveStory(0),
                "the log did not tell the conquest: \(g.journal.last?.text ?? "nothing")")
    }
}
