//
//  Rules.swift
//  Riskelo US
//
//  Every lever in the game, in one place — and what the simulation answered
//  when they were turned.
//
//  Risk gets its balance from chance: the attacker rolls more dice than the
//  defender and statistically ends up getting through. Replacing the die with
//  a question removes that spring. Two consequences, both measured over
//  thousands of games played by the machine against itself:
//
//  1. The share of duels won by the attacker is exactly "one minus the
//     defender's rate of correct answers". At thirty seconds a question, the
//     defender held seven times out of ten: attacking became a bad deal, and
//     it took close to two hundred questions to finish a game. At fifteen
//     seconds the attacker wins 48% of duels — the range of the original
//     Risk, where they win 39% of two-dice-against-two comparisons, 42% of
//     one against one.
//
//  2. Without chance, a player who knows never loses their place, whatever
//     army stands across from them. What replaces the statistics is wear: the
//     hourglass gets shorter with every question the same territory faces
//     within the same turn. Pressing a place eventually pays, as in Risk —
//     but it is the defender's breath that gives out, not the luck of a roll.
//
//  One lever deliberately does not push that way: question difficulty does
//  not climb with the siege. Two settings that pull at the same point can no
//  longer be tuned separately.
//

import Foundation

struct Rules: Equatable, Codable {

    // MARK: - The duel

    /// The mode of play, chosen at setup.
    ///
    /// In **classic**, the attacker chooses the ground and the defender alone
    /// answers: knowledge is armor, never a weapon, and the attacker spends
    /// their own turn watching the other think.
    ///
    /// In a **showdown**, both answer the same question. This is the duel of
    /// Risk recovered — both roll — and it took borrowing two rules
    /// unchanged from the die to get there:
    ///
    ///     both know          → the hourglass decides, the quicker wins
    ///     neither knows      → the place holds, as on a tie
    ///
    /// Settling it on the hourglass is not an ornament, it is what holds the
    /// balance. Without it the attacker would win only `p × (1−p)` of
    /// exchanges — 23% at a 65% answer rate — and the game would freeze, with
    /// nobody able to take a place any more. With it we come back up to 44%,
    /// the range of die-against-die in Risk (41.7%).
    var mode: Mode = .classic

    enum Mode: String, CaseIterable, Identifiable, Codable {
        case classic
        case showdown

        var id: String { rawValue }

        var label: String {
            switch self {
            case .classic:  "Classic"
            case .showdown: "Showdown"
            }
        }

        var detail: String {
            switch self {
            case .classic:
                "The attacker picks the theme, the defender alone answers."
            case .showdown:
                "Both answer the same question. The defender can double the stake."
            }
        }
    }

    /// The attacker's "dice": one or two questions per assault.
    var maxQuestions = 2

    /// Hourglass for the first question of a siege.
    ///
    /// Fifteen seconds, not thirty: this is the setting that decides the
    /// whole balance of the game (see the header). Time to read the prompt,
    /// to know, and to answer.
    var baseSeconds: TimeInterval = 15

    /// What is left of the hourglass at each further question on the same
    /// territory within the same turn: 15s, 11.7s, 9.1s, 7.1s, 6s.
    var siegePressure: Double = 0.78

    /// Below this, the question stops being a question and becomes a reflex.
    var minSeconds: TimeInterval = 6

    /// Draw weights for the three difficulty levels.
    var difficultyWeights: [Difficulty: Int] = Mix.mixed.weights

    /// The themes in play, by identifier.
    ///
    /// This is a rule of the game and not a device setting: it travels with
    /// the game, and whoever joins plays the host's themes. Two devices that
    /// disagreed about this would not ask the same questions.
    ///
    /// Absent or empty means **all** — not none. Two reasons: a game saved
    /// before this setting existed does not have one and must resume as it
    /// was, and a theme added later joins the games of anyone who chose
    /// nothing on its own. A list of every theme ticked would be a list that
    /// ages.
    var themes: Set<String>?

    /// The difficulty mix, as chosen at setup. This is a game setting — you
    /// choose how tough the game runs, the way you choose the machine's
    /// knowledge.
    enum Mix: String, CaseIterable, Identifiable, Codable {
        case easy, mixed, tough
        var id: String { rawValue }

        var label: String {
            switch self {
            case .easy:  "Easy"
            case .mixed: "Mixed"
            case .tough: "Tough"
            }
        }

        var detail: String {
            switch self {
            case .easy:  "Gentle enough to play with children."
            case .mixed: "All three levels, as in a boxed game."
            case .tough: "For anyone who finds the rest too easy."
            }
        }

        var weights: [Difficulty: Int] {
            switch self {
            case .easy:  [.easy: 6, .medium: 3, .hard: 1]
            case .mixed: [.easy: 4, .medium: 4, .hard: 2]
            case .tough: [.easy: 1, .medium: 3, .hard: 6]
            }
        }
    }

    // MARK: - The turn

    /// Minimum reinforcement per turn, whatever happens.
    var reinforcementFloor = 3

    /// One reinforcement per so many territories. Going to four lengthens the
    /// game by half without changing the balance at all.
    var territoriesPerReinforcement = 3

    /// Starting armies, before they are spread over the territories dealt.
    var startingArmies = 22

    /// Risk's territory cards. Optional: they change the economics of
    /// reinforcement, and the board plays perfectly well without them.
    var territoryCards = false

    /// Personal conquests: each player is dealt an objective at the start
    /// that they alone know, giving them a second way to win.
    ///
    /// Optional, and off by default: it changes the game completely. The
    /// territory count in the top bar stops saying who is winning, and you no
    /// longer know what the other player is after — which is the whole point,
    /// but is not the game anyone expects if they did not ask for it.
    ///
    /// With the rule on, conquest becomes the only way to win: the domination
    /// threshold withdraws, and only the whole board is left — which is to
    /// say nobody is left. A card that became impossible does not leave its
    /// player without a way out for all that: it turns over into a fallback,
    /// and that fallback carries the threshold (see `Objective.fallback`).
    var objectives = false

    /// One extra troop for every so many correct answers within one theme.
    /// `nil` removes the rule.
    ///
    /// Only the defender answers: this reinforcement therefore rewards
    /// whoever holds their place by knowing, and it falls above all to
    /// whoever is being attacked — that is to say, most often, to whoever is
    /// losing. Whether that closes the gaps or widens them is another
    /// question: it has been measured.
    var answersPerBonusMan: Int? = 5

    /// Does the end-of-turn move follow a chain of friendly territories
    /// ("modern" rule), or only direct adjacency?
    var fortifyAlongChain = true

    // MARK: - The end

    /// The share of the world that is enough to win, without having to sweep
    /// up the crumbs. `nil` takes the measured value; `0` asks for **total
    /// war** — every territory, no exceptions.
    ///
    /// Full conquest drags the ending out: the last territories are held by a
    /// player with nothing left to lose who simply answers correctly. With
    /// two players it costs 177 questions where the 65% threshold asks for
    /// 90 — and the winner is the same.
    var dominationOverride: Double?

    /// What each player after the first receives in addition at the start.
    /// `nil` takes the measured value.
    ///
    /// Opening is expensive: with two players and no compensation, whoever
    /// goes first wins 61% of games. Two troops restore the split (51/48 over
    /// six hundred games).
    var compensationOverride: Int?

    // MARK: - What follows from it

    func answerTime(siege: Int) -> TimeInterval {
        max(minSeconds, baseSeconds * pow(siegePressure, Double(max(0, siege))))
    }

    func reinforcements(territories: Int, continentBonus: Int) -> Int {
        max(reinforcementFloor, territories / territoriesPerReinforcement) + continentBonus
    }

    func drawDifficulty<G: RandomNumberGenerator>(using rng: inout G) -> Difficulty {
        let table = Difficulty.allCases.flatMap { d in
            Array(repeating: d, count: difficultyWeights[d] ?? 1)
        }
        return table.randomElement(using: &rng) ?? .medium
    }

    /// The victory threshold: a player's starting share, plus three and a
    /// half territories. It is not a fixed share of the world — 65% does not
    /// mean the same thing with two players as with four, where you start
    /// from 25%. It is a gap, and the gap is what sets the length: whatever
    /// the number of players, it takes a dozen turns to cross.
    func dominationThreshold(territories: Int, playerCount: Int) -> Int {
        // Personal conquests take the game on themselves. The threshold
        // stopped being one more door and became the door: with two players
        // on the World board it decided five games out of six, and with four
        // it decided all of them — the card was useless, and the player who
        // won on count saw their unmet conquest displayed under their name.
        // So it stays here only to say "there was nobody left across the
        // table".
        if objectives { return territories }
        if let dominationOverride {
            return dominationOverride <= 0 ? territories
                : Int((Double(territories) * dominationOverride).rounded(.up))
        }
        let start = Double(territories) / Double(max(2, playerCount))
        return min(territories, Int((start + victoryGap).rounded(.up)))
    }

    /// The gap to take, in territories, over your starting share. Seven gives
    /// games of 65 questions with two players, 120 with three, 160 with four
    /// — twenty minutes to an hour. Each point adds about ten questions.
    var victoryGap: Double = 7

    /// The turn-order compensation, as the simulation settled it: two troops
    /// with two players, nothing beyond that. At three and above, the
    /// advantage of opening dilutes on its own — whoever strikes first
    /// exposes themselves to two neighbors instead of one.
    func compensation(playerCount: Int) -> Int {
        if let compensationOverride { return compensationOverride }
        return playerCount <= 2 ? 2 : 0
    }
}
