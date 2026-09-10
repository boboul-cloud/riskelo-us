//
//  Game.swift
//  Riskelo US
//
//  The game: the complete state, and the only moves that can change it.
//
//  Everything here is a value — including the random draw, including the
//  question bank. A game is therefore copyable, replayable and comparable:
//  you can run a thousand of them in a test to see whether the attacker wins
//  too often, which no rule written along the way inside the interface allows.
//
//  The sequence of a turn, as in Risk: reinforcements, attacks, move.
//

import Foundation

struct Player: Identifiable, Equatable, Codable {
    enum Kind: Equatable, Codable {
        case human
        /// The machine opponent: its knowledge — the share of correct answers
        /// it gives on an average question — and its way of playing, which
        /// has nothing to do with it. You can be learned and maneuver badly.
        case machine(level: Double, style: Bot.Style)
    }
    let id: PlayerID
    var name: String
    var kind: Kind = .human
    var eliminated = false
    var isBot: Bool { if case .machine = kind { return true } else { return false } }

    var style: Bot.Style {
        if case let .machine(_, style) = kind { return style } else { return .strong }
    }
}

enum Phase: Equatable, Codable {
    case reinforcement(remaining: Int)
    case attack
    /// Place taken: how many troops advance.
    case occupation(from: TerritoryID, to: TerritoryID, minimum: Int, maximum: Int)
    case fortify
    case finished(winner: PlayerID)
}

struct Entry: Identifiable, Equatable, Codable {
    enum Kind: Equatable, Codable { case turn, reinforcement, duel, conquest, elimination, end }
    let id = UUID()
    let turn: Int
    let player: PlayerID?
    let kind: Kind
    let text: String
    static func == (a: Entry, b: Entry) -> Bool { a.id == b.id }

    /// The identifier serves display only: it is remade on reading.
    private enum CodingKeys: String, CodingKey { case turn, player, kind, text }
}

/// What a player has managed in one category.
struct Score: Equatable, Codable {
    var asked = 0
    var correct = 0
    var rate: Double { asked == 0 ? 0.5 : Double(correct) / Double(asked) }
}

struct GameState {

    /// The board, and which one it is: the second is used to find it again
    /// when loading a game, the first saves looking it up at every glance.
    let boardKind: Boards
    let board: Board
    var rules: Rules
    var players: [Player]
    private(set) var owner: [TerritoryID: PlayerID] = [:]
    private(set) var armies: [TerritoryID: Int] = [:]
    private(set) var current: Int = 0
    private(set) var phase: Phase = .attack
    private(set) var assault: Assault?
    /// What each player has shown they know, category by category. This is
    /// the counterpart to the rule "the attacker asks the question": whoever
    /// attacks chooses the ground, but they still have to know where to
    /// strike.
    private(set) var knowledge: [PlayerID: [Category: Score]] = [:]
    /// What has already been paid out in scholarship reinforcement, so as not
    /// to pay it twice: the count of correct answers itself never goes back
    /// down.
    private(set) var bonusPaid: [PlayerID: Int] = [:]

    // MARK: - Territory cards

    /// The deck, the discard pile, and each player's hand.
    private(set) var deck: [Card] = []
    private(set) var discard: [Card] = []
    private(set) var hands: [PlayerID: [Card]] = [:]
    /// How many exchanges have taken place in the game: the scale climbs with
    /// them.
    private(set) var exchanges = 0
    /// Has a place been taken this turn? A card is only earned that way.
    private(set) var conqueredThisTurn = false
    /// The last category put to each player. Used to avoid working them twice
    /// running on the same subject — which exhausts the category and makes
    /// the attacker predictable.
    private(set) var lastCategoryAgainst: [PlayerID: Category] = [:]
    /// Questions already faced per territory, reset every turn: this is the
    /// memory of the siege, and therefore of the shortening clock.
    private(set) var siege: [TerritoryID: Int] = [:]
    private(set) var turn = 1
    private(set) var journal: [Entry] = []
    /// What each player is secretly after, when the rule is in play. The
    /// state carries them all — they have to travel with the game and survive
    /// a resumption — and it is the screen that shows only one: yours.
    private(set) var objectives: [PlayerID: Objective] = [:]
    /// Who brought down whom. A side eliminated by a third party does not
    /// count for the player who was asked to bring them down: their card
    /// turns over instead, as in Risk.
    private(set) var eliminated: [PlayerID: PlayerID] = [:]

    var bank: QuestionBank
    var rng: SeededRandom

    var map: GameMap { board.map }
    var currentPlayer: Player { players[current] }

    // MARK: - Setting up

    /// The core: the board, the rules, the players, the bank and the draw.
    /// Everything else is laid down afterwards — by `start` for a new game,
    /// by `init(restoring:)` for a resumed one. It is written by hand because
    /// declaring an initializer removes the one Swift wrote on its own.
    private init(boardKind: Boards, rules: Rules, players: [Player],
                 bank: QuestionBank, rng: SeededRandom) {
        self.boardKind = boardKind
        self.board = boardKind.board
        self.rules = rules
        self.players = players
        self.bank = bank
        self.rng = rng
    }

    static func start(board: Boards = .ring,
                      players: [Player],
                      rules: Rules = Rules(),
                      bank: QuestionBank = QuestionBank(),
                      seed: UInt64 = UInt64.random(in: .min ... .max)) -> GameState {
        var g = GameState(boardKind: board, rules: rules, players: players,
                          bank: bank, rng: SeededRandom(seed: seed))

        // Territories are dealt at random, one at a time, the way cards are
        // dealt: nobody picks their starting position.
        var ids = g.map.order
        ids.shuffle(using: &g.rng)
        for (i, id) in ids.enumerated() {
            let p = players[i % players.count].id
            g.owner[id] = p
            g.armies[id] = 1
        }

        // Then the rest of the armies, spread at random over their own lands.
        for (rank, player) in players.enumerated() {
            let stock = rules.startingArmies + rank * rules.compensation(playerCount: players.count)
            let mine = g.territories(of: player.id)
            guard !mine.isEmpty else { continue }
            for _ in 0 ..< max(0, stock - mine.count) {
                let id = mine.randomElement(using: &g.rng)!
                g.armies[id, default: 0] += 1
            }
        }

        if rules.territoryCards {
            g.deck = Deck.build(for: g.map)
            g.deck.shuffle(using: &g.rng)
        }
        if rules.objectives {
            g.objectives = Objective.deal(for: g.board, players: players.count,
                                          using: &g.rng)
        }
        g.phase = .reinforcement(remaining: g.reinforcements(for: g.currentPlayer.id))
        g.note(.turn, "Turn \(g.turn) — \(g.currentPlayer.name) to play.")
        return g
    }

    /// Rebuilds a game exactly as it was saved.
    ///
    /// Same spirit as `seize`: the door is named, it is the only one, and an
    /// ordinary game never goes through it. Everything that is read-only from
    /// the outside is set back here, and nowhere else.
    init(restoring board: Boards, rules: Rules, players: [Player],
         bank: QuestionBank, rng: SeededRandom,
         owner: [TerritoryID: PlayerID], armies: [TerritoryID: Int],
         current: Int, phase: Phase, assault: Assault?,
         siege: [TerritoryID: Int], knowledge: [PlayerID: [Category: Score]],
         lastCategoryAgainst: [PlayerID: Category], bonusPaid: [PlayerID: Int],
         deck: [Card], discard: [Card], hands: [PlayerID: [Card]],
         exchanges: Int, conqueredThisTurn: Bool,
         objectives: [PlayerID: Objective], eliminated: [PlayerID: PlayerID],
         turn: Int, journal: [Entry]) {
        self.init(boardKind: board, rules: rules, players: players, bank: bank, rng: rng)
        self.owner = owner
        self.armies = armies
        self.current = min(max(0, current), max(0, players.count - 1))
        self.phase = phase
        self.assault = assault
        self.siege = siege
        self.knowledge = knowledge
        self.lastCategoryAgainst = lastCategoryAgainst
        self.bonusPaid = bonusPaid
        self.deck = deck
        self.discard = discard
        self.hands = hands
        self.exchanges = exchanges
        self.conqueredThisTurn = conqueredThisTurn
        self.objectives = objectives
        self.eliminated = eliminated
        self.turn = turn
        self.journal = journal
    }

    // MARK: - The cards

    func hand(of player: PlayerID) -> [Card] { hands[player] ?? [] }

    /// The value of the next exchange, so it can be announced before it is
    /// made.
    var nextExchangeValue: Int { Deck.value(forExchange: exchanges + 1) }

    /// Risk forces an exchange as soon as you hold five cards: without that
    /// you would pile them up without ever making the game livelier, which is
    /// the whole point of the climbing scale.
    func mustExchange(_ player: PlayerID) -> Bool {
        rules.territoryCards && hand(of: player).count >= 5
            && Deck.firstSet(in: hand(of: player)) != nil
    }

    /// Trades three cards for troops, added to the reinforcements in hand.
    @discardableResult
    mutating func exchange(_ ids: [Int]) -> Bool {
        guard rules.territoryCards, case let .reinforcement(remaining) = phase else { return false }
        let player = currentPlayer.id
        let hand = hand(of: player)
        let trio = ids.compactMap { id in hand.first { $0.id == id } }
        guard trio.count == 3, Deck.isASet(trio) else { return false }

        var value = Deck.value(forExchange: exchanges + 1)
        // Risk's bonus: a card carrying one of your own places is worth two
        // extra troops. They go to the common pool rather than onto the cell,
        // so as not to add a separate placement step.
        if trio.contains(where: { card in card.territory.map { owner[$0] == player } ?? false }) {
            value += 2
        }
        exchanges += 1
        hands[player] = hand.filter { !ids.contains($0.id) }
        discard.append(contentsOf: trio)
        phase = .reinforcement(remaining: remaining + value)
        note(.reinforcement, "\(currentPlayer.name) trades three cards: \(value) troops.")
        return true
    }

    /// Draws a card, reshuffling the discard pile if the deck is empty.
    private mutating func drawCard(_ player: PlayerID) {
        if deck.isEmpty {
            deck = discard
            discard = []
            deck.shuffle(using: &rng)
        }
        guard let card = deck.popLast() else { return }
        hands[player, default: []].append(card)
        note(.reinforcement, "\(players.first { $0.id == player }?.name ?? "?") earns a card.")
    }

    // MARK: - Reading

    func territories(of player: PlayerID) -> [TerritoryID] {
        map.order.filter { owner[$0] == player }
    }

    func armies(_ id: TerritoryID) -> Int { armies[id] ?? 0 }

    func continentsHeld(by player: PlayerID) -> [Continent] {
        map.continentsInOrder.filter { c in c.territories.allSatisfy { owner[$0] == player } }
    }

    func reinforcements(for player: PlayerID) -> Int {
        rules.reinforcements(territories: territories(of: player).count,
                             continentBonus: continentsHeld(by: player).reduce(0) { $0 + $1.bonus })
            + scholarshipOwed(player)
    }

    /// The total earned since the start, across all themes.
    func scholarshipEarned(_ player: PlayerID) -> Int {
        guard let threshold = rules.answersPerBonusMan, threshold > 0 else { return 0 }
        return themesInPlay.reduce(0) { $0 + record(of: player, in: $1).correct / threshold }
    }

    /// What is owed to them and has not yet been paid out.
    func scholarshipOwed(_ player: PlayerID) -> Int {
        max(0, scholarshipEarned(player) - (bonusPaid[player] ?? 0))
    }

    /// Settles the scholarship reinforcement at the moment it is paid.
    private mutating func settleScholarship(_ player: PlayerID) {
        let owed = scholarshipOwed(player)
        guard owed > 0 else { return }
        bonusPaid[player] = scholarshipEarned(player)
        note(.reinforcement, "\(troops(owed)) more for "
             + "\(players.first { $0.id == player }?.name ?? "?"): their correct answers.")
    }

    /// Where you can attack from: your own lands, with more than one troop,
    /// touching an enemy neighbor.
    func canLaunch(from id: TerritoryID) -> Bool {
        owner[id] == currentPlayer.id && armies(id) >= 2 && !targets(from: id).isEmpty
    }

    func targets(from id: TerritoryID) -> [TerritoryID] {
        map.neighbors(of: id).filter { owner[$0] != owner[id] }
    }

    /// The number of possible questions: one die per troop beyond the first,
    /// within the limit set by the rules. A garrison must always be left
    /// behind.
    func maxQuestions(from id: TerritoryID) -> Int {
        max(0, min(rules.maxQuestions, armies(id) - 1))
    }

    /// Two friendly territories joined by a chain of friendly territories.
    func areLinked(_ a: TerritoryID, _ b: TerritoryID, for player: PlayerID) -> Bool {
        guard owner[a] == player, owner[b] == player else { return false }
        if !rules.fortifyAlongChain { return map.areAdjacent(a, b) }
        var seen: Set<TerritoryID> = [a]
        var stack = [a]
        while let id = stack.popLast() {
            if id == b { return true }
            for n in map.neighbors(of: id) where owner[n] == player && !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return false
    }

    /// The category where this player has stumbled most — and where they
    /// really do stumble: from two questions asked, and below one correct
    /// answer in two. Under that bar it is not a weakness, it is chance;
    /// above it, it is not one at all, and marking it with a target would
    /// contradict the score shown in green right beside it.
    func weakness(of player: PlayerID) -> Category? {
        knowledge[player]?
            .filter { $0.value.asked >= 2 && $0.value.rate < 0.5 }
            .min { $0.value.rate < $1.value.rate ? true
                 : $0.value.rate > $1.value.rate ? false
                 : $0.key.id < $1.key.id }?.key
    }

    /// The themes this game uses, in the order of the grid.
    ///
    /// Nothing stated means the base game — the themes everyone owns — and
    /// not every theme the device knows: packs are chosen, they do not invite
    /// themselves.
    ///
    /// A fallback rather than an empty list: rules naming only themes absent
    /// from this device would make the game unplayable, and a game without a
    /// question is indistinguishable from a breakdown.
    var themesInPlay: [Category] {
        guard let chosen = rules.themes, !chosen.isEmpty else { return Themes.base }
        let kept = Themes.all.filter { chosen.contains($0.id) }
        return kept.isEmpty ? Themes.base : kept
    }

    func record(of player: PlayerID, in category: Category) -> Score {
        knowledge[player]?[category] ?? Score()
    }

    /// Do they hold enough of the world for the game to be decided?
    func dominates(_ player: PlayerID) -> Bool {
        territories(of: player).count >= dominationThreshold
    }

    /// How many territories must be held for the game to be decided.
    var dominationThreshold: Int {
        rules.dominationThreshold(territories: map.order.count, playerCount: players.count)
    }

    var isOver: Bool { if case .finished = phase { true } else { false } }

    /// Setting up a position from scratch: a territory, its owner, its
    /// garrison. An ordinary game never goes through here — this is the door
    /// for tests and scenarios, and the only one.
    mutating func seize(_ id: TerritoryID, by player: PlayerID, armies count: Int = 1) {
        owner[id] = player
        armies[id] = max(0, count)
    }

    /// The same door, for a hand of cards.
    mutating func seizeHand(of player: PlayerID, _ cards: [Card]) {
        hands[player] = cards
    }

    /// The same door, for a personal conquest and what becomes of it.
    mutating func seize(objective: Objective, of player: PlayerID) {
        objectives[player] = objective
    }

    mutating func seize(eliminated victim: PlayerID, by killer: PlayerID) {
        self.eliminated[victim] = killer
    }

    /// The same door, for what a player has shown they know in a category.
    mutating func seize(_ category: Category, of player: PlayerID, asked: Int, correct: Int) {
        knowledge[player, default: [:]][category] = Score(asked: max(0, asked),
                                                          correct: max(0, min(asked, correct)))
    }

    // MARK: - Reinforcements

    @discardableResult
    mutating func place(on id: TerritoryID, count: Int = 1) -> Bool {
        guard case let .reinforcement(remaining) = phase,
              owner[id] == currentPlayer.id, count > 0, count <= remaining else { return false }
        armies[id, default: 0] += count
        let left = remaining - count
        phase = .reinforcement(remaining: left)
        if left == 0 {
            note(.reinforcement, "\(currentPlayer.name) has placed their reinforcements.")
            phase = .attack
        }
        // An objective asking for so many places at two or three troops is
        // met by laying down a reinforcement, not only by taking a place.
        checkObjective()
        return true
    }

    /// The personal conquest is checked everywhere it can be achieved: a
    /// place taken, a troop laid down, an end-of-turn move. The domination
    /// threshold, on the other hand, depends only on the number of
    /// territories and is checked where those change hands.
    ///
    /// It can only be achieved during your own turn — you do not win during
    /// someone else's, even if they hand you a continent by withdrawing.
    private mutating func checkObjective() {
        guard rules.objectives, !isOver, players.count > 1,
              objectiveAchieved(currentPlayer.id) else { return }
        assault = nil
        phase = .finished(winner: currentPlayer.id)
        note(.end, objectiveStory(currentPlayer.id))
    }

    // MARK: - Assault

    /// Is the assault allowed? Kept apart from carrying it out because a move
    /// played over the network has to be checked before being sent, not
    /// after.
    func canDeclare(from: TerritoryID, to: TerritoryID, questions: Int) -> Bool {
        guard case .attack = phase, assault == nil,
              owner[from] == currentPlayer.id,
              let defender = owner[to], defender != currentPlayer.id,
              map.areAdjacent(from, to),
              questions >= 1, questions <= maxQuestions(from: from) else { return false }
        return true
    }

    @discardableResult
    mutating func declareAssault(from: TerritoryID, to: TerritoryID,
                                 questions: Int, category: Category?) -> Bool {
        guard canDeclare(from: from, to: to, questions: questions),
              let defender = owner[to] else { return false }

        var a = Assault(attacker: currentPlayer.id, defender: defender,
                        from: from, to: to, category: category, volley: questions)
        note(.duel, "\(currentPlayer.name) attacks \(name(to)) from \(name(from)) — "
             + "\(questions) question\(questions > 1 ? "s" : "") "
             + "\(category.map { "on \($0.label)" } ?? "at random").")
        // Ground left to chance does not count as ground chosen: the machine
        // forbids itself the same theme twice running, and "at random"
        // commits it to nothing.
        if let category { lastCategoryAgainst[defender] = category }
        if !drawQuestion(&a) { assault = nil; return false }
        assault = a
        return true
    }

    private mutating func drawQuestion(_ a: inout Assault) -> Bool {
        let level = rules.drawDifficulty(using: &rng)
        guard let asked = bank.draw(category: a.category, among: themesInPlay,
                                    difficulty: level, using: &rng) else {
            return false
        }
        let pressure = siege[a.to] ?? 0
        a.current = Duel(question: asked,
                         allowance: rules.answerTime(siege: pressure),
                         siege: pressure)
        return true
    }

    /// Who has to answer the question asked.
    ///
    /// In classic play, the defender, and them alone. In a showdown, the
    /// defender **then** the attacker — in that order, and the order is not
    /// indifferent. On a shared device, whoever answers second has had time
    /// to think while the other was searching; that advantage therefore goes
    /// to the attacker, who already loses every tie.
    var whoAnswers: PlayerID? {
        guard let a = assault, a.current != nil else { return nil }
        guard rules.mode == .showdown else { return a.defender }
        return a.defenderAnswer == nil ? a.defender : a.attacker
    }

    /// Can the defender still double the stake? Once per question, and before
    /// having answered — afterwards it would no longer be a bet.
    var canRaise: Bool {
        guard rules.mode == .showdown, let a = assault, a.current != nil else { return false }
        return a.defenderAnswer == nil && a.stake == 1
    }

    /// The raise: the defender's second die.
    ///
    /// In Risk the defender chooses one die or two, and two dice win or lose
    /// more. Here they bet on their own knowledge of the theme the attacker
    /// has just chosen: the exchange will be worth two troops instead of one,
    /// whichever way it falls.
    mutating func raise() {
        guard canRaise else { return }
        assault?.stake = 2
        note(.duel, "\(playerName(assault?.defender ?? -1)) raises: "
             + "the exchange will be worth two troops.")
    }

    func playerName(_ id: PlayerID) -> String {
        players.first { $0.id == id }?.name ?? "?"
    }

    private mutating func credit(_ player: PlayerID, _ category: Category, correct: Bool) {
        var score = knowledge[player]?[category] ?? Score()
        score.asked += 1
        if correct { score.correct += 1 }
        knowledge[player, default: [:]][category] = score
    }

    private func troops(_ n: Int) -> String { "\(n) troop\(n > 1 ? "s" : "")" }

    /// An answer arrives. This is the only move that draws blood — except the
    /// first of the two in a showdown, which only waits for the other.
    @discardableResult
    mutating func answer(_ response: Answer) -> DuelReport? {
        guard var a = assault, let duel = a.current else { return nil }

        // Showdown, first beat: the defender has answered, and their answer
        // sleeps until the attacker's. Nothing is revealed, or the attacker
        // would read the solution before answering the same question.
        if rules.mode == .showdown, a.defenderAnswer == nil {
            a.defenderAnswer = response
            assault = a
            return nil
        }

        let report: DuelReport
        if rules.mode == .showdown, let defense = a.defenderAnswer {
            report = Combat.resolveShowdown(defender: defense, attacker: response,
                                            of: duel, stake: a.stake)
            credit(a.defender, duel.question.category, correct: report.correct)
            // The attacker answers, so their knowledge counts too: that is
            // the whole point of the mode, and the scholarship reinforcement
            // follows.
            credit(a.attacker, duel.question.category, correct: report.attackerCorrect)
        } else {
            report = Combat.resolve(response, of: duel)
            credit(a.defender, duel.question.category, correct: report.correct)
        }

        a.current = nil
        a.defenderAnswer = nil
        a.asked += 1
        a.reports.append(report)
        siege[a.to, default: 0] += 1

        switch report.outcome {
        case .defenderHolds:
            // The attacker is never stripped of their garrison: a stake of
            // two only pays what the stack across the line can pay.
            let loss = max(0, min(report.stake, armies(a.from) - 1))
            armies[a.from, default: 0] -= loss
            a.attackerLosses += loss
            note(.duel, story(report, place: name(a.to), loss: loss))
        case .attackerBreaks:
            let loss = min(report.stake, armies(a.to))
            armies[a.to, default: 0] -= loss
            a.defenderLosses += loss
            note(.duel, story(report, place: name(a.to), loss: loss))
        }

        a.stake = 1
        if armies(a.to) <= 0 {
            a.conquered = true
            assault = a
            conquer(from: a.from, to: a.to, volley: a.volley)
            return report
        }

        // The volley continues while a declared question remains and there is
        // one troop to spare to carry it: you never attack with your garrison.
        if a.asked < a.volley && armies(a.from) >= 2 {
            _ = drawQuestion(&a)
        }
        assault = a
        return report
    }

    /// What the log keeps of the exchange. Showdown mode has four outcomes
    /// where classic has two, and they have to be named: a player who loses a
    /// place must know whether it was because they did not know, or because
    /// they were slower.
    private func story(_ r: DuelReport, place: String, loss: Int) -> String {
        let holds = r.outcome == .defenderHolds
        switch r.verdict {
        case .answered:
            return holds
                ? "\(place) holds: correct answer, the attacker leaves \(troops(loss))."
                : (r.answer == .timeout
                   ? "Time is up: \(place) loses \(troops(loss))."
                   : "Wrong answer: \(place) loses \(troops(loss)).")
        case .onlyOne:
            return holds
                ? "\(place) holds: the defender knew, the attacker did not — \(troops(loss)) fewer for them."
                : "The attacker knew, the place did not: \(place) loses \(troops(loss))."
        case .speed:
            return holds
                ? "Both knew: the defender was quicker, \(place) holds and costs \(troops(loss))."
                : "Both knew: the attacker was quicker, \(place) loses \(troops(loss))."
        case .tie:
            return "Nobody knew: \(place) holds, and the attacker leaves \(troops(loss))."
        }
    }

    /// Files away the finished assault and hands back control.
    mutating func dismissAssault() {
        guard let a = assault, a.isOver else { return }
        assault = nil
    }

    /// The loser's cards pass to whoever finishes them off.
    ///
    /// This is Risk's rule, and it has a reason you only see by removing it:
    /// without it, the loser's hand stays frozen where it is and those cards
    /// leave the game for good. The deck grows poorer with every elimination,
    /// silently, until it has nothing left to give.
    ///
    /// Risk requires coming back under five cards on the spot, with troops
    /// laid down straight after. Here we let the rule that already exists
    /// handle it: `mustExchange` blocks at five, and the surplus is settled
    /// when the next turn opens. The only departure from the original rule is
    /// when the troops arrive — and it avoids inventing a placement step in
    /// the middle of an assault, the one place in the game where nothing is
    /// ever laid down.
    private mutating func inherit(from loser: PlayerID) {
        let spoils = hand(of: loser)
        guard !spoils.isEmpty else { return }
        hands[loser] = []
        hands[currentPlayer.id, default: []].append(contentsOf: spoils)
        note(.reinforcement, "\(currentPlayer.name) inherits \(spoils.count) card"
             + "\(spoils.count > 1 ? "s" : "") from the loser.")
    }

    private mutating func conquer(from: TerritoryID, to: TerritoryID, volley: Int) {
        let loser = owner[to]
        owner[to] = currentPlayer.id
        armies[to] = 0
        conqueredThisTurn = true
        note(.conquest, "\(name(to)) falls. \(currentPlayer.name) takes it.")

        if let loser, territories(of: loser).isEmpty,
           let i = players.firstIndex(where: { $0.id == loser }) {
            players[i].eliminated = true
            eliminated[loser] = currentPlayer.id
            note(.elimination, "\(players[i].name) is eliminated.")
            inherit(from: loser)
        }

        let survivors = players.filter { !$0.eliminated }
        // The garrison does not stop halfway when the game is won: we do not
        // ask "how many troops advance" for a place that has no tomorrow.
        let byObjective = objectiveAchieved(currentPlayer.id)
        guard survivors.count > 1, !dominates(currentPlayer.id), !byObjective else {
            // Everything is taken: the garrison follows, and the game stops.
            armies[to] = max(1, armies(from) - 1)
            armies[from] = 1
            assault = nil
            phase = .finished(winner: currentPlayer.id)
            // Conquest comes before the threshold when the same place opens
            // both gates: conquest is what was being played, and the
            // threshold would have been crossed anyway. The case no longer
            // arises now that the threshold withdraws in front of conquests —
            // the condition stays so that the day a threshold comes back, it
            // does not bury the card at the very moment it pays.
            if byObjective, survivors.count > 1 {
                note(.end, objectiveStory(currentPlayer.id))
            } else {
                note(.end, survivors.count > 1
                     ? "\(currentPlayer.name) holds enough of the world for the rest to stop counting."
                     : "\(currentPlayer.name) holds the whole world.")
            }
            return
        }

        let available = max(1, armies(from) - 1)
        phase = .occupation(from: from, to: to,
                            minimum: min(volley, available), maximum: available)
    }

    /// How many troops advance into the conquered place. At least as many as
    /// there were questions asked — the equivalent of "at least as many as
    /// there were dice".
    @discardableResult
    mutating func occupy(_ count: Int) -> Bool {
        guard case let .occupation(from, to, minimum, maximum) = phase else { return false }
        let n = min(max(count, minimum), maximum)
        armies[from, default: 0] -= n
        armies[to, default: 0] += n
        assault = nil
        phase = .attack
        note(.conquest, "\(n) troop\(n > 1 ? "s advance" : " advances") into \(name(to)).")
        checkObjective()
        return true
    }

    // MARK: - Moving and ending the turn

    @discardableResult
    mutating func fortify(from: TerritoryID, to: TerritoryID, count: Int) -> Bool {
        guard case .fortify = phase,
              areLinked(from, to, for: currentPlayer.id), from != to,
              count > 0, count <= armies(from) - 1 else { return false }
        armies[from, default: 0] -= count
        armies[to, default: 0] += count
        note(.reinforcement, "\(troops(count)) from \(name(from)) to \(name(to)).")
        // Before handing over: a move can bring the last place up to two
        // troops, and it is still your turn.
        checkObjective()
        endTurn()
        return true
    }

    /// Moves to the next step of the turn, and to the next player if there
    /// are no steps left.
    mutating func advance() {
        switch phase {
        case .reinforcement(let remaining):
            // You do not pass your turn with reinforcements in your pocket.
            if remaining == 0 { phase = .attack }
        case .attack:
            guard assault == nil else { return }
            phase = .fortify
        case .occupation:
            return
        case .fortify:
            endTurn()
        case .finished:
            return
        }
    }

    mutating func endTurn() {
        guard !isOver else { return }
        if rules.territoryCards, conqueredThisTurn { drawCard(currentPlayer.id) }
        conqueredThisTurn = false
        assault = nil
        siege.removeAll()     // the defender's breath comes back between turns
        var next = current
        repeat {
            next = (next + 1) % players.count
            if next == 0 { turn += 1 }
        } while players[next].eliminated
        current = next
        let reinforcements = reinforcements(for: currentPlayer.id)
        settleScholarship(currentPlayer.id)
        phase = .reinforcement(remaining: reinforcements)
        note(.turn, "Turn \(turn) — \(currentPlayer.name) to play.")
    }

    // MARK: - Log

    func name(_ id: TerritoryID) -> String { map[id]?.name ?? id }

    private mutating func note(_ kind: Entry.Kind, _ text: String) {
        journal.append(Entry(turn: turn, player: players.indices.contains(current) ? currentPlayer.id : nil,
                             kind: kind, text: text))
        if journal.count > 400 { journal.removeFirst(journal.count - 400) }
    }
}
