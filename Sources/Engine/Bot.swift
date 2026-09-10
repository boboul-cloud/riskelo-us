//
//  Bot.swift
//  Riskelo US
//
//  The machine opponent.
//
//  It serves two purposes: playing solo, and above all running a thousand
//  games in a second to see whether a rule holds. Its decisions are therefore
//  pure functions of the state — no hidden memory, nothing that fails to
//  replay.
//
//  Its "knowledge" is a number: the share of correct answers it gives on an
//  average question, at full time. The siege presses it as it would press a
//  human — less time, fewer correct answers.
//

import Foundation

enum Bot {

    /// How the machine maneuvers. Nothing to do with its knowledge: you can
    /// be learned and play badly.
    ///
    /// The three levels stack, each adding one skill to the one before — and
    /// each was measured against the level below, or they would be nothing
    /// but three names.
    enum Style: String, Equatable, Codable, CaseIterable {
        /// Greedy. It steps forward onto any target where it has one troop
        /// more, and leaves the minimum behind — hence the one-troop
        /// garrisons scattered through enemy land.
        case easy
        /// It holds what it takes: after a conquest it leaves its base what
        /// it needs and moves everything else forward. For the rest it keeps
        /// the dash of the easy level — and that is deliberate: caution
        /// without concentration is **worse than nothing**. Measured, a
        /// machine that held its stacks back without knowing where to carry
        /// them lost four games out of five against the greedy one.
        case medium
        /// It plays Risk: it concentrates its reinforcements on a single
        /// spearhead, aims at the continent closest to complete, tries to
        /// break the opponent's — and it exploits the clock, which is what is
        /// peculiar to this game: a place already pressed this turn answers
        /// in a shorter time, so you finish it off rather than open another.
        case strong

        var label: String {
            switch self {
            case .easy:   "Easy"
            case .medium: "Medium"
            case .strong: "Strong"
            }
        }

        var detail: String {
            switch self {
            case .easy:
                "It advances at random and scatters one-troop garrisons."
            case .medium:
                "It holds what it takes and looks for your weak spots."
            case .strong:
                "It concentrates, aims at a continent, and knows where to hit you."
            }
        }

        /// Does it leave its base enough to hold, instead of the bare
        /// minimum?
        var garrisons: Bool { self != .easy }
        /// Does it hold back its spent stacks? This discipline only pays with
        /// concentration: on its own it makes the machine passive.
        var holdsBackStacks: Bool { self == .strong }
        /// Does it pour its reinforcements onto a single spearhead?
        var concentrates: Bool { self == .strong }
        /// Does it aim at a continent, and try to break the one across the
        /// table?
        var aimsForContinent: Bool { self == .strong }
        /// Does it finish off a place already broken into rather than open
        /// another? This is the strategy peculiar to this game: the
        /// defender's clock tightens with every question faced within the
        /// turn.
        var exploitsTheClock: Bool { self == .strong }

        /// How far it aims at the opponent's weaknesses when choosing the
        /// ground for the question.
        ///
        /// This is the decisive lever, and it took measuring to see it:
        /// maneuvering only separates the machines on a large board, because
        /// anywhere else the game settles in seven turns and **the quiz is
        /// what decides**. Choosing the ground is the attacker's only skill
        /// in this variant, and it weighs on every duel. Zero: it draws at
        /// random without looking at the file.
        var flair: Double {
            switch self {
            case .easy:   0
            case .medium: 1.2
            case .strong: 3.0
            }
        }
    }

    // MARK: - What the machine looks at

    /// What presses a place: the enemy troops touching it.
    static func threat(_ g: GameState, _ id: TerritoryID) -> Int {
        g.map.neighbors(of: id)
            .filter { g.owner[$0] != g.owner[id] }
            .reduce(0) { $0 + g.armies($1) }
    }

    /// What a place makes possible: the best available advantage from it.
    /// This is the measure of an attacking spearhead.
    static func potential(_ g: GameState, _ id: TerritoryID) -> Int {
        g.targets(from: id).map { g.armies(id) - 1 - g.armies($0) }.max() ?? -99
    }

    /// The continent aimed at: the one closest to complete, and at equal
    /// bonus the largest. A continent already held stays the objective —
    /// defending it is worth what it pays.
    static func targetContinent(_ g: GameState, _ player: PlayerID) -> Continent? {
        var best: Continent?
        var fewestMissing = Int.max
        for c in g.map.continentsInOrder {
            var missing = 0
            for id in c.territories where g.owner[id] != player { missing += 1 }
            if missing < fewestMissing
                || (missing == fewestMissing && c.bonus > (best?.bonus ?? 0)) {
                fewestMissing = missing
                best = c
            }
        }
        return best
    }

    /// The garrison a place must keep so as not to be retaken on the first
    /// assault. This is the whole flaw of the greedy opponent: it left one
    /// troop and lost the place next turn.
    static func garrison(_ g: GameState, _ id: TerritoryID) -> Int {
        let m = threat(g, id)
        if m == 0 { return 1 }
        return max(2, min(m / 2 + 1, 5))
    }

    // MARK: - Answering

    /// Two factors, not one: knowing, and having the time to say it.
    ///
    /// The second is not simulation decoration — it is what carries the whole
    /// balance of the game. Three seconds go to reading the prompt and the
    /// four choices; beyond a dozen useful seconds, knowing more no longer
    /// translates into answers. Below that, memory no longer has time to
    /// surface, and what is left is reflex.

    /// What a player knows better, and less well.
    ///
    /// Nobody is equally strong everywhere, and that is the whole point of
    /// the attacker choosing the ground. Without that relief, a simulated
    /// machine answers geography as well as sports, the opponent's file
    /// contains nothing but noise — and there is no way to measure whether
    /// aiming at weaknesses is worth anything. The profile is deterministic:
    /// each player keeps their strengths from one end of the game to the
    /// other.
    static func aptitude(_ player: PlayerID, _ category: Category) -> Double {
        let relief = [0.16, 0.09, 0.0, -0.09, -0.16, 0.0]
        // The rank used to come from the theme's position in the enum. A
        // theme added shifted the relief of every theme after it: the machine
        // changed strengths because a file had been dropped in. It is now
        // derived from the theme's name, which does not move when its
        // neighbors move.
        let rank = Int(QuestionBank.digest(category.id) % UInt64(relief.count))
        return relief[(rank + player * 2) % relief.count]
    }

    static func probability(level: Double, difficulty: Difficulty,
                            allowance: TimeInterval, rules: Rules) -> Double {
        let knowledge: Double
        switch difficulty {
        case .easy:   knowledge = level + 0.15
        case .medium: knowledge = level
        case .hard:   knowledge = level - 0.20
        }
        let time = min(1, max(0.35, (allowance - 3) / 12))
        return min(0.98, max(0.02, knowledge * time))
    }

    /// The machine always answers something — right or wrong, never nothing.
    ///
    /// It used to let the time run out one in seven times when it was wrong.
    /// Three reasons for removing that. A machine that runs out of time is
    /// not believable. Above all, the screen had nothing to show: a timeout
    /// marks no choice in red, so all you saw was the correct answer in green
    /// while the verdict announced silence — and you thought the app was
    /// counting a correct answer as a wrong one. Finally, it served no
    /// purpose: to the engine, silence and a mistake have exactly the same
    /// consequence.
    ///
    /// The timeout stays what it should be: the act of a human who did not
    /// answer, and who knows perfectly well why.
    static func answer(to duel: Duel, level: Double, rules: Rules,
                       player: PlayerID = 0,
                       using rng: inout SeededRandom) -> Answer {
        let p = probability(level: level + aptitude(player, duel.question.category),
                            difficulty: duel.question.difficulty,
                            allowance: duel.allowance, rules: rules)
        let elapsed = Double.random(in: 0.25 ... 0.85, using: &rng) * duel.allowance
        if Double.random(in: 0 ... 1, using: &rng) < p {
            return .chosen(duel.question.answer, elapsed: elapsed)
        }
        let wrong = (0 ..< duel.question.choices.count).filter { $0 != duel.question.answer }
        return .chosen(wrong.randomElement(using: &rng) ?? 0, elapsed: elapsed)
    }

    /// Should the stake be doubled? The defender's only bet, in a showdown.
    ///
    /// It is not won by knowing, it is won by knowing **what the other does
    /// not**. Doubling on an easy question is a trap: the attacker knows it
    /// too, and the exchange then comes down to the clock — two troops on a
    /// coin toss. So the machine bets on what it holds *and* what is rare.
    static func shouldRaise(_ g: GameState, duel: Duel, level: Double,
                            style: Style, player: PlayerID) -> Bool {
        guard style != .easy else { return false }
        let p = probability(level: level + aptitude(player, duel.question.category),
                            difficulty: duel.question.difficulty,
                            allowance: duel.allowance, rules: g.rules)
        let rare: Double
        switch duel.question.difficulty {
        case .easy:   rare = 0
        case .medium: rare = 0.12
        case .hard:   rare = 0.25
        }
        // Doubling is not a show of strength, it is a throw of the dice: it
        // multiplies the swing without moving the expectation when both know
        // — the exchange then comes down to the clock, a coin toss, for two
        // troops. And chance serves whoever is behind and costs whoever
        // leads. Measured: raising whenever it felt sure, the strong machine
        // doubled one time in four and **lost its rank** against the medium
        // one (39 to 49% depending on the board). So it raises only when it
        // knows *and* has something to catch up.
        var mine = 0, bestOther = 0
        for other in g.players {
            let n = g.owner.values.filter { $0 == other.id }.count
            if other.id == player { mine = n } else { bestOther = max(bestOther, n) }
        }
        let behind = mine < bestOther
        let threshold: Double
        switch (style, behind) {
        case (.strong, true):  threshold = 0.70
        case (.strong, false): threshold = 0.95
        case (_, true):        threshold = 0.80
        default:               threshold = 0.97
        }
        return p + rare > threshold
    }

    // MARK: - Reinforcements

    /// Where to lay a troop down.
    ///
    /// The greedy one lays it on the most pressed cell, and starts over for
    /// each troop: it therefore spreads its reinforcements across the whole
    /// front. The strategist does the opposite — it first plugs whatever
    /// falls to the first blow, then pours all the rest onto **a single**
    /// spearhead. This is Risk's first lesson: one big stack beats five small
    /// ones.
    static func reinforcement(_ g: GameState) -> TerritoryID? {
        let me = g.currentPlayer.id
        let mine = g.territories(of: me)
        guard !mine.isEmpty else { return nil }
        guard g.currentPlayer.style.concentrates else {
            return mine.max { a, b in pressure(g, a) < pressure(g, b) }
        }

        // 1. A one-troop place the enemy can take in a single blow will fall:
        //    it is worth a reinforcement before anything else.
        let fragile = mine.filter { g.armies($0) == 1 && threat(g, $0) >= 3 }
        if let worst = fragile.max(by: { threat(g, $0) < threat(g, $1) }) { return worst }

        // 2. Everything else onto the best spearhead.
        return spearhead(g, me) ?? mine.max { a, b in threat(g, a) < threat(g, b) }
    }

    /// The place the offensive will start from: the one that touches the
    /// enemy, that promises the most, and that serves the objective.
    static func spearhead(_ g: GameState, _ player: PlayerID) -> TerritoryID? {
        let target = targetContinent(g, player)
        return g.territories(of: player)
            .filter { !g.targets(from: $0).isEmpty }
            .max { a, b in spearheadValue(g, a, target) < spearheadValue(g, b, target) }
    }

    private static func spearheadValue(_ g: GameState, _ id: TerritoryID,
                                       _ target: Continent?) -> Double {
        var v = Double(g.armies(id)) * 0.6 + Double(potential(g, id)) * 0.8
        // A spearhead opening onto the continent being aimed at is worth more
        // than another.
        if let target, g.targets(from: id).contains(where: {
            g.map[$0]?.continent == target.id && g.owner[$0] != g.currentPlayer.id
        }) { v += 4 }
        return v
    }

    /// The greedy one's old measure, kept for it alone.
    private static func pressure(_ g: GameState, _ id: TerritoryID) -> Double {
        let enemies = threat(g, id)
        guard enemies > 0 else { return -100 }
        let bonus = g.map.continentsInOrder.first { $0.id == g.map[id]?.continent }
            .map { c -> Double in
                let held = c.territories.filter { g.owner[$0] == g.owner[id] }.count
                return held >= c.territories.count - 1 ? 2 : 0
            } ?? 0
        return Double(enemies) - Double(g.armies(id)) + bonus
    }

    // MARK: - Attacking

    struct Plan: Equatable {
        let from: TerritoryID
        let to: TerritoryID
        let questions: Int
        let category: Category
    }

    /// The best assault available, if it is worth the trouble.
    ///
    /// `boldness` sets the advantage required: 1 asks for one troop more than
    /// the place aimed at, 2 accepts a fight at even strength. The second is
    /// not madness — the wear of the siege means the fifth question of a turn
    /// is won three times out of four. It is in fact indispensable: two
    /// machines that both demand the advantage dig in facing each other and
    /// the game never ends.
    ///
    /// The strategist adds two things to the greedy one. It does not take its
    /// stack below three troops — a spent stack holds nothing and takes
    /// nothing more. And it weighs what the place is worth: completing a
    /// continent, breaking the opponent's, or being one more cell.
    static func assault<G: RandomNumberGenerator>(_ g: GameState, boldness: Double = 1.0,
                                                  using rng: inout G) -> Plan? {
        let me = g.currentPlayer.id
        let style = g.currentPlayer.style
        let strategic = style.aimsForContinent
        let target = strategic ? targetContinent(g, me) : nil
        var best: (score: Double, plan: Plan)?

        for from in g.territories(of: me) where g.armies(from) >= 2 {
            // A stack down to two troops no longer attacks: it holds.
            //
            // This line is expensive, and I measured it by loosening it:
            // letting the machine pick up an undefended place drops the
            // strategist from 51% to 32% on Europe. Taking a cell with your
            // last pair of troops is exactly the flaw being corrected.
            //
            // And in a showdown, exactly the reverse. It is the one rule in
            // the game that changes sign from one mode to the other: holding
            // back costs the strong machine 14 points against the medium one
            // (44% instead of 58% on Europe, 41 instead of 56 on the World),
            // where flair, the spearhead and the continent do not move by two
            // points. The reason lies in what an exchange is worth: in
            // classic play it costs one troop and takes only one, so a stack
            // of two never finishes anything; in a showdown, whoever knows
            // wins the exchange outright, and a raise can take two at once.
            // The last pair of troops can therefore finish off a place — and
            // going without that is giving up real conquests.
            if style.holdsBackStacks, g.rules.mode == .classic,
               g.armies(from) <= 2, threat(g, from) > 0 { continue }
            for to in g.targets(from: from) {
                let advantage = Double(g.armies(from) - 1 - g.armies(to))
                // A place already pressed this turn answers on a shorter
                // clock: it is worth more than a fresh place at equal
                // strength. The clock tightens with every question the same
                // place faces within the turn: finishing off a place already
                // broken into costs far less than opening another. This is
                // the strategy peculiar to this game, and the strong machine
                // is the only one that uses it.
                //
                // In a showdown this lever loses its edge without changing
                // direction. The shortened clock applies to both, and when
                // nobody knows the place holds: pressing therefore
                // manufactures ties, which belong to the defender — at equal
                // p on both sides, the attacker wins `p − p²/2` of exchanges,
                // that is 44% at 0.65 but 35% at 0.45. I tried to draw the
                // conclusion and make it avoid places already broken into: it
                // was a mistake. The machine stopped finishing what it had
                // started, games went from 13 to 23 turns, thirteen out of
                // three hundred no longer finished at all. A fresh place is
                // not better — it is only new, and the troops already spent
                // on the other one are lost.
                let wear = Double(g.siege[to] ?? 0) * (style.exploitsTheClock ? 1.6 : 0.7)
                guard advantage + wear >= 2 - boldness else { continue }

                var score = advantage + wear
                if let c = g.map.continentsInOrder.first(where: { $0.id == g.map[to]?.continent }) {
                    // Completing a continent is worth more than nibbling.
                    if c.territories.filter({ g.owner[$0] != me }).count == 1 {
                        score += Double(c.bonus) * 1.5
                    }
                    if strategic {
                        // Push into the continent being aimed at, and break
                        // the one the opponent is about to hold.
                        if c.id == target?.id { score += 3 }
                        let opponent = g.owner[to]
                        if let opponent, c.territories.allSatisfy({ g.owner[$0] == opponent }) {
                            score += Double(c.bonus)
                        }
                    }
                }
                if strategic {
                    // Do not throw yourself at a place you will not be able
                    // to keep.
                    score -= Double(threat(g, to)) * 0.15
                }
                let plan = Plan(from: from, to: to,
                                questions: min(g.maxQuestions(from: from), advantage >= 2 ? 2 : 1),
                                category: category(g, against: g.owner[to] ?? -1, using: &rng))
                if best == nil || score > best!.score { best = (score, plan) }
            }
        }
        return best?.plan
    }

    /// Where to strike. This is the attacker's whole craft in this variant —
    /// and it is also where a machine becomes unbearable if you let it play
    /// at its best.
    ///
    /// Aiming every time at the exact weakness is the optimal move, and the
    /// worst of all: you get the same subject ten times running, the category
    /// runs dry, and every duel looks like the last. A real player probes. So
    /// the draw is weighted — what is missed weighs heavily, what is answered
    /// weighs little, what is still unknown keeps its chance — and the same
    /// subject twice in a row becomes unlikely without being ruled out.
    static func category<G: RandomNumberGenerator>(_ g: GameState, against player: PlayerID,
                                                   using rng: inout G) -> Category {
        let style = g.currentPlayer.style
        // Without flair it does not even look at the file.
        // An empty catalogue cannot happen — the game would have no questions
        // at all — but it must not bring the app down either.
        guard style.flair > 0 else {
            return g.themesInPlay.randomElement(using: &rng) ?? Category("")
        }

        let previous = style == .strong ? g.lastCategoryAgainst[player] : nil
        let weights: [(Category, Double)] = g.themesInPlay.map { c in
            let score = g.record(of: player, in: c)
            // With no sample, we credit the opponent with an average success
            // rate: neither fearsome nor a gift, and therefore worth probing.
            let theirs = score.asked == 0 ? 0.5 : score.rate
            var p: Double
            if g.rules.mode == .classic {
                let failure = 1 - theirs
                p = 0.20 + failure * failure * style.flair
            } else {
                // In a showdown we answer too: what to look for is no longer
                // the weakness across the table, it is the **gap**. Choosing
                // the other's ignorance and throwing yourself into it is
                // trapping yourself along with them — and the exchange then
                // settles on a tie, which belongs to the defender.
                let own = g.record(of: g.currentPlayer.id, in: c)
                let myRate = own.asked == 0 ? 0.5 : own.rate
                let gap = max(0, myRate - theirs)
                p = 0.20 + gap * gap * style.flair
            }
            if c == previous { p *= 0.22 }
            return (c, p)
        }
        let total = weights.reduce(0) { $0 + $1.1 }
        var draw = Double.random(in: 0 ..< total, using: &rng)
        for (c, p) in weights {
            draw -= p
            if draw <= 0 { return c }
        }
        return weights.last!.0
    }

    // MARK: - Occupying, moving

    /// How many troops advance into the conquered place.
    ///
    /// This is where the greedy one sowed its one-troop garrisons: as soon as
    /// its base still touched an enemy, it advanced only the minimum, and the
    /// place it had taken fell again next turn. The strategist does the
    /// opposite sum: it keeps at the base what it needs to hold, and **all
    /// the rest advances**. A place taken is a place to defend.
    static func occupation(_ g: GameState) -> Int {
        guard case let .occupation(from, _, minimum, maximum) = g.phase else { return 1 }
        guard g.currentPlayer.style.garrisons else {
            let exposed = g.map.neighbors(of: from).contains { g.owner[$0] != g.owner[from] }
            return exposed ? minimum : maximum
        }
        // What stays behind: enough to hold the base, no more.
        let left = garrison(g, from)
        let advancing = g.armies(from) - left
        return min(maximum, max(minimum, advancing))
    }

    /// Bringing the rear up to the front.
    ///
    /// The greedy one aims at the most pressed cell: it plugs holes. The
    /// strategist aims at its spearhead: it prepares the next turn. Plugging
    /// everywhere is being strong nowhere.
    static func fortification(_ g: GameState) -> (from: TerritoryID, to: TerritoryID, count: Int)? {
        let me = g.currentPlayer.id
        let mine = g.territories(of: me)
        let front = mine.filter { id in g.map.neighbors(of: id).contains { g.owner[$0] != me } }
        let rear = mine.filter { !front.contains($0) && g.armies($0) >= 2 }
        guard let source = rear.max(by: { g.armies($0) < g.armies($1) }) else { return nil }

        let reachable = front.filter { g.areLinked(source, $0, for: me) }
        guard !reachable.isEmpty else { return nil }

        let chosen: TerritoryID?
        if g.currentPlayer.style.concentrates {
            let aim = targetContinent(g, me)
            // A place that falls to the first assault comes before the
            // spearhead: losing a territory costs a reinforcement every turn
            // after.
            let atRisk = reachable.filter { g.armies($0) == 1 && threat(g, $0) >= 3 }
            chosen = atRisk.max(by: { threat(g, $0) < threat(g, $1) })
                ?? reachable.max(by: {
                    spearheadValue(g, $0, aim) < spearheadValue(g, $1, aim)
                })
        } else {
            chosen = reachable.max(by: { pressure(g, $0) < pressure(g, $1) })
        }
        guard let target = chosen else { return nil }
        return (source, target, g.armies(source) - 1)
    }
}
