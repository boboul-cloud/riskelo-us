//
//  GameSession.swift
//  Riskelo US
//
//  What ties the engine to the screen: time passing, the opponent thinking,
//  and the order in which things are shown.
//
//  The engine knows nothing of either: it receives an answer and returns a
//  report. Everything that follows — the hourglass, the second of waiting
//  before the machine answers, the time left to read the result — is theater,
//  and the theater is here.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class GameSession {

    /// Where the duel stands on screen. The engine has none of these states:
    /// to it, a question is either asked or it is not.
    enum Stage: Equatable {
        /// The map, long enough to see where the assault leaves from and
        /// where it lands. Without it, the duel screen covered everything as
        /// soon as it was declared and you never knew what the machine was
        /// doing.
        case announcing
        /// "Pass the device", or "ready?": the hourglass does not start
        /// before whoever is answering has said they were.
        case handover
        /// Showdown: the other player is answering, and the question must not
        /// appear yet. It did appear, so you saw the prompt, then a "ready?"
        /// screen, then the same prompt — two screens for one question, and
        /// the feeling that the game was stuttering.
        case opponentAnswering
        case asking
        case revealed
        /// The assault is over: what it cost, and what it took.
        case summary
    }

    /// This game's identity in the library.
    ///
    /// It survives a resume — reopening the app must not open a second game —
    /// but **not** a step back: going back to a shelved moment opens a new
    /// branch, or replaying the end of a game would erase the very ending you
    /// meant to keep.
    let gameID: UUID

    /// Shelves the present moment in the library.
    ///
    /// Off the main thread: shelving a moment rereads the whole index,
    /// encodes the game and writes two files. It was being done in the middle
    /// of the tap on "End turn", which therefore stuttered.
    ///
    /// The shelvings queue up behind each other — each waits for the last —
    /// because `store` reads the index, changes it and rewrites it: two at
    /// once would overwrite each other.
    private func shelve(_ label: String, marked: Bool = false) {
        let snapshot = game, id = gameID
        let previous = shelving
        shelving = Task.detached(priority: .utility) {
            await previous?.value
            Archives.shared.store(snapshot, game: id, label: label, marked: marked)
        }
    }

    private var shelving: Task<Void, Never>?

    /// The player puts a bookmark on the position. The passing turn lays one
    /// down by itself; this one is for holding on to a moment in the middle
    /// of a turn.
    func mark() {
        shelve("Position marked", marked: true)
    }

    /// Every mutation of the game triggers its save — it is the only place it
    /// leaves from, so there is no move that can forget it. The write is
    /// deferred by half a second: during the machine's turn, moves follow
    /// several times a second, and only the last one counts.
    private(set) var game: GameState {
        didSet {
            scheduleSave()
            notePhaseChange(from: oldValue)
        }
    }

    /// The share of the bottom of the screen the duel sheet takes. The board
    /// uses it to reframe: the fight has to stay visible ABOVE it, not under
    /// it.
    var coveredFraction: Double {
        switch stage {
        case .handover, .asking, .revealed, .summary: return 0.55
        case .opponentAnswering: return 0.4
        default: break
        }
        // The two setup panels take the bottom of the screen the way the duel
        // sheet does, and the board has to give them as much room: you chose
        // your ground without being able to see what you were attacking any
        // more. The assault one is tall — six grounds, the number of
        // questions, the button; the move one fits in three lines.
        guard target != nil else { return 0 }
        // Measured on screen rather than deduced: the assault panel covers
        // six tenths of the map on an iPhone, the move one barely more than a
        // tenth.
        switch game.phase {
        case .attack:  return 0.60
        case .fortify: return 0.12
        default:       return 0
        }
    }

    /// Spots changes of step and announces them. Goes through the game's
    /// `didSet`: it is the only place the game can change from, so no change
    /// can escape.
    private func notePhaseChange(from before: GameState) {
        guard !game.isOver else {
            // The winner is not announced here. The game is decided in the
            // middle of a question — the last place falls on an answer — and
            // announcing it on the spot covered the answer you were reading.
            // `announceVictory` takes care of it, once the duel sheet has
            // closed. The shelving, which is invisible, can leave right away.
            if case .finished = game.phase, !before.isOver { shelve("End of game") }
            return
        }
        let newTurn = before.current != game.current
        if newTurn {
            // One moment per turn, laid down unasked: it is afterwards that
            // you know which one counted.
            shelve("Turn \(game.turn) — \(game.currentPlayer.name)")
            let name = game.currentPlayer.name
            let mine = !networked || game.currentPlayer.id == mySeat
            show(Announcement(title: mine ? "\(name), your turn!" : "\(name)'s turn",
                              sub: "Reinforcements", side: game.currentPlayer.id))
            return
        }
        switch (before.phase, game.phase) {
        case (.reinforcement, .attack):
            show(Announcement(title: "Attack!", sub: nil, side: game.currentPlayer.id))
        case (.attack, .fortify), (.occupation, .fortify):
            show(Announcement(title: "Move", sub: "One only, then the turn passes",
                              side: game.currentPlayer.id))
        case (_, .occupation):
            show(Announcement(title: "Place taken!", sub: nil, side: game.currentPlayer.id))
        default:
            break
        }
    }

    /// The opening. It does not go through the `didSet` — the game is laid
    /// down in the initializer, and a property being installed does not watch
    /// itself. So the first turn stayed silent.
    private func announceOpening() {
        guard !game.isOver else { return }
        let name = game.currentPlayer.name
        let mine = !networked || game.currentPlayer.id == mySeat
        show(Announcement(title: mine ? "\(name), your turn!" : "\(name)'s turn",
                          sub: "Reinforcements", side: game.currentPlayer.id))
    }

    private func show(_ a: Announcement) {
        announcement = a
        announcementWork?.cancel()
        announcementWork = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_400))
            guard let self, !Task.isCancelled else { return }
            self.announcement = nil
        }
    }

    /// What is announced on screen for a beat: "Blue, your turn!", "Attack!".
    /// Nothing that decides anything — but without it, you do not know you
    /// have just changed step.
    struct Announcement: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let sub: String?
        let side: PlayerID
        static func == (a: Announcement, b: Announcement) -> Bool { a.id == b.id }
    }

    private(set) var announcement: Announcement?
    private var announcementWork: Task<Void, Never>?

    private(set) var stage: Stage?

    /// Is the victory screen due?
    ///
    /// The engine decides the instant the last place falls, which is to say
    /// in the middle of a question: the victory screen therefore landed on
    /// top of the answer in progress, and you never saw whether you had been
    /// right, nor the place fall. We finish the action, announce the winner
    /// on the board, and the victory screen comes last.
    private(set) var victoryShown = false
    private var victoryAnnounced = false

    private(set) var report: DuelReport?
    private(set) var remaining: TimeInterval = 0
    private(set) var thinking = false

    var selected: TerritoryID?
    var target: TerritoryID?
    /// The ground of the assault being prepared. Empty means "at random": the
    /// attacker gives up choosing, and the question is drawn from the whole
    /// bank.
    ///
    /// The theme offered up front is the first in the grid. It used to be
    /// named — "geography" — and a theme named in the code is a theme you can
    /// no longer take out of its folder without breaking the build. It is
    /// brought back into what the table allows as soon as a target is picked.
    private(set) var draftCategory: Category? = Themes.all.first
    var draftQuestions = 1
    /// Has the player yet chosen a ground themselves? While they have not,
    /// the app suggests the opponent's weakness — once, to show what that
    /// choice is for. Afterwards it says nothing: suggesting again at every
    /// assault pushes them to hammer the same category, and a hammered
    /// category runs dry.
    private var categoryChosen = false

    func chooseCategory(_ c: Category?) {
        draftCategory = c
        categoryChosen = true
    }
    var journalOpen = false
    var fileOpen = false
    var cardsOpen = false
    var objectiveOpen = false

    /// The objective to show on **this** device, and whose it is.
    ///
    /// Over the network, yours and never anyone else's: each player holds
    /// their own device, and the complete state they receive is only read
    /// through this screen.
    ///
    /// On a single device, that of whoever is playing — they are the one
    /// holding it, and it is Risk's rule around a table: you do not show your
    /// card. During the machine's turn, the first human's, so it can be
    /// reread while waiting for your turn.
    var objectiveShown: (player: PlayerID, card: Objective)? {
        guard game.rules.objectives else { return nil }
        let who: PlayerID
        if networked {
            who = mySeat
        } else if !game.currentPlayer.isBot {
            who = game.currentPlayer.id
        } else if let human = game.players.first(where: { !$0.isBot }) {
            who = human.id
        } else {
            return nil
        }
        guard let card = game.objective(of: who) else { return nil }
        return (who, card)
    }

    /// The cards held in hand, waiting to be traded.
    var chosenCards: Set<Int> = []

    func toggleCard(_ id: Int) {
        if chosenCards.contains(id) { chosenCards.remove(id) }
        else if chosenCards.count < 3 { chosenCards.insert(id) }
    }

    /// Do the three cards held make a set?
    var setReady: Bool {
        let hand = game.hand(of: game.currentPlayer.id)
        let trio = hand.filter { chosenCards.contains($0.id) }
        return Deck.isASet(trio)
    }

    func exchange() {
        guard setReady else { return }
        play(.exchangeCards(Array(chosenCards)))
        chosenCards = []
        resume()
    }

    /// The screen's tempo. Nothing here touches the rules: this is the time
    /// left for the eye, and that alone.
    ///
    /// A question put to the machine used to be settled in three seconds —
    /// time to watch it go by, not to read it. Yet it is the liveliest moment
    /// of the game for the attacker: they chose the ground, they know the
    /// question, and they answer it in their head before their opponent. They
    /// have to be given the time. But sixty questions in a game make sixty
    /// waits: each one is cut short by a tap.
    private enum Tempo {
        /// Floor and ceiling of the reading time, by length of text.
        static let readingMin: Double = 4.0
        static let readingMax: Double = 9.0
        /// Characters read per second, reading attentively.
        static let charsPerSecond: Double = 17
        /// The time left on the result: the correct answer, the dice, and who
        /// loses a troop. That is three things to read.
        static let verdict: Double = 4.5
        /// In a showdown there are two answers and two times to read on top
        /// of the correct answer: the same moment is no longer enough.
        static let verdictShowdown: Double = 9.5
        /// The summary of an assault you have been subjected to: what it
        /// cost, and what it took. When you attack yourself it waits for a
        /// tap; when you are on the receiving end it passes on its own so as
        /// not to chop up the other player's turn.
        static let summary: Double = 5.5
        /// The time spent on the map before an assault by the machine: enough
        /// to follow the arrow and recognize the two places. Five seconds,
        /// and not three and a half: on a large board the view first moves
        /// toward the fight, and you have to be given time to arrive and then
        /// to look.
        static let announcement: Double = 5.0
        /// Showdown: how long the machine appears to think, when its answer
        /// will not be shown.
        static let thinking: Double = 2.2
    }

    /// The time left on the result, by how much there is to read in it.
    private var verdictTime: Double {
        game.rules.mode == .showdown ? Tempo.verdictShowdown : Tempo.verdict
    }

    /// What is left of the current moment, from 1 to 0. The top bar uses it
    /// when it is the machine defending — a human has their real hourglass.
    ///
    /// One descent per question, reading and verdict included. The first
    /// version made two: the bar emptied during the reading, filled again,
    /// and emptied again during the verdict. You thought there was a second
    /// countdown for the same question.
    private(set) var waitPart: Double = 1
    /// A tap during a wait: we move on.
    private var skipped = false

    /// Is there anything to cut short?
    ///
    /// The moment lets itself be cut short — but not in its first second. A
    /// tap that left too early, or the second of a double tap, carried off
    /// the verdict before it could be read.
    var canSkip: Bool {
        (thinking || stage == .revealed || stage == .announcing || stage == .summary)
            && waitPart < 0.85
    }

    func skipAhead() { skipped = true }

    private var pump: Task<Void, Never>?
    private var ticker: Timer?
    private var saveWork: Task<Void, Never>?

    // MARK: - The second device

    private(set) var link: Link?
    /// Which of the players is the one holding this device.
    private(set) var mySeat: PlayerID = 0
    private var hosting = false
    /// How many moves have been played since the start. Serves as an order: a
    /// move already seen is recognized, a missing move shows.
    private var counter = 0
    /// Each linked device's seat, so we know who to send what back to.
    private var seats: [Pair: PlayerID] = [:]

    var networked: Bool { link != nil }

    /// My turn to act? Off the network, that means "not the machine's".
    var myTurnToPlay: Bool {
        guard !game.isOver else { return false }
        guard networked else { return !game.currentPlayer.isBot }
        return game.currentPlayer.id == mySeat
    }

    /// My turn to answer? In classic play it is always the defender; in a
    /// showdown, the defender then the attacker.
    var myTurnToAnswer: Bool {
        guard game.assault != nil else { return false }
        guard networked else { return responderIsHuman }
        return responder == mySeat
    }

    /// The one point through which a game changes, and therefore the only one
    /// a move leaves from toward the other device. No move can be forgotten:
    /// there is no other door.
    @discardableResult
    private func play(_ action: Action) -> DuelReport? {
        let duelReport = game.apply(action)
        if let link {
            counter += 1
            if let data = Message.move(action, number: counter, digest: game.digest).data {
                link.send(data)
            }
        }
        return duelReport
    }

    /// What arrives from another device.
    private func received(_ data: Data, from pair: Pair) {
        // A packet we cannot read mid-game can no longer be a version
        // disagreement — the handshake would have said so — and so there is
        // nothing better to do than ignore it. `Message.read` leaves a trace
        // in the console for both cases.
        guard case let .message(message) = Message.read(data) else { return }
        switch message {
        case let .game(state, yourSeat, number):
            mySeat = yourSeat
            counter = number
            game = state
            report = nil
            stage = nil
            announceOpening()
            resume()

        case .hello:
            // A greeting arriving after the launch: the names have been fixed
            // since the game left, so there is nothing left to do with it.
            // Better to pass over it than to count it as a fault.
            break

        case let .move(action, number, digest):
            // Already played: with four devices the host relays, and a move
            // can arrive twice. We recognize it by its number.
            guard number > counter else { return }
            // One is missing: picking up here would play a different game.
            guard number == counter + 1 else { requestGameAgain(); return }

            counter = number
            let duelReport = game.apply(action)
            guard game.digest == digest else {
                // The games have drifted apart. Each stays coherent on its
                // own side — which is precisely the danger — so we do not go
                // on.
                requestGameAgain()
                return
            }
            // The host passes it on to the others: nothing guarantees that
            // two guests can see each other directly.
            if hosting, let link { link.send(data, except: pair) }

            pump?.cancel()
            pump = Task { @MainActor [weak self] in
                await self?.afterRemoteMove(action, duelReport)
            }

        case .lost:
            guard hosting, let link, let seat = seats[pair],
                  let data = Message.game(game, yourSeat: seat, number: counter).data
            else { return }
            link.send(data, to: pair)
        }
    }

    private func requestGameAgain() {
        guard let data = Message.lost.data else { return }
        link?.send(data)
    }

    /// What the screen has to show of a move played across the table.
    private func afterRemoteMove(_ action: Action, _ duelReport: DuelReport?) async {
        switch action {
        case .declareAssault:
            stage = .announcing
            await pause(Tempo.announcement)
            if Task.isCancelled { return }
        case .answer:
            // In a showdown, the first of the two answers settles nothing:
            // there is no report, so nothing to show and nothing to sound.
            if let duelReport { reveal(duelReport) } else { report = nil; stage = .revealed }
            await pause(Tempo.verdict)
            if Task.isCancelled { return }
            report = nil
        default:
            break
        }
        stage = nil
        resume()
    }

    // MARK: - The drawer

    /// Saves right away. To be called when the app goes to the background: it
    /// can be stopped without further notice.
    func saveNow() {
        saveWork?.cancel()
        rememberQuestions()
        if game.isOver { GameStore.shared.discard() } else { GameStore.shared.save(game) }
    }

    /// What this game has asked joins the device's memory, so the next one
    /// avoids it.
    ///
    /// The count is recomputed whole every time — it does not increment — and
    /// saving it twice therefore never counts twice. We still only rewrite
    /// the file when one more question has been asked: there is one save per
    /// move, and most of them ask none.
    private func rememberQuestions() {
        guard game.bank.alreadyServed != servedSaved else { return }
        servedSaved = game.bank.alreadyServed
        QuestionMemory.shared.save(
            game.bank.seenUpToDate(from: memoryAtStart, excluding: servedAtOpening))
    }

    private var servedSaved: Set<String> = []

    /// What **this** device knew when the game opened.
    ///
    /// The memory is written from there, and not from the one that travels
    /// with the game: whoever joins plays with the host's bank — they have to,
    /// or the two screens would ask two different questions — but they add to
    /// their own only what was asked here.
    private let memoryAtStart = QuestionMemory.shared.load()

    /// What the game had already asked when we opened it. That has been
    /// counted in the memory for a long time: a game resumed three times must
    /// not count its first questions three times.
    private var servedAtOpening: Set<String> = []

    private func scheduleSave() {
        saveWork?.cancel()
        saveWork = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    init(players: [Player], rules: Rules = Rules(), board: Boards = .ring,
         seed: UInt64 = UInt64.random(in: .min ... .max)) {
        // The game opens knowing what the device has already seen go by: that
        // is what keeps the second evening from asking the first one's
        // questions again.
        game = GameState.start(board: board, players: players, rules: rules,
                               bank: QuestionBank(seen: QuestionMemory.shared.load()),
                               seed: seed)
        gameID = UUID()
        servedAtOpening = game.bank.alreadyServed
        GameStore.shared.saveID(gameID)
        saveNow()
        shelve("Opening")
        announceOpening()
        resume()
    }

    /// Opens a game across two devices. Whoever hosts creates the game and
    /// sends it; whoever joins receives it before showing anything at all.
    init(link: Link, hosting: Bool, game newGame: GameState, mySeat seat: PlayerID,
         seats: [Pair: PlayerID] = [:], counter: Int = 0) {
        game = newGame
        gameID = UUID()
        self.link = link
        self.hosting = hosting
        self.mySeat = seat
        self.seats = seats
        self.counter = counter
        servedAtOpening = game.bank.alreadyServed
        link.onReceive = { [weak self] data, pair in self?.received(data, from: pair) }
        announceOpening()
        resume()
    }

    /// Resumes a saved game. A duel waiting on a human will go back through
    /// "ready?" by itself: the hourglass must not run while you turn the
    /// device back on.
    ///
    /// `branch` is only given by the library, which then opens a fresh
    /// branch; an ordinary resume finds again the identity left beside the
    /// save.
    init(resuming saved: GameState, branch: UUID? = nil) {
        game = saved
        gameID = branch ?? GameStore.shared.loadID() ?? UUID()
        servedAtOpening = game.bank.alreadyServed
        GameStore.shared.saveID(gameID)
        if branch != nil { shelve("Resumed here") }
        announceOpening()
        resume()
    }

    // MARK: - What the screen asks for

    var duel: Duel? { game.assault?.current }
    var assault: Assault? { game.assault }

    /// The verdict appears, and sounds. Going through here rather than
    /// assigning the report by hand: it is the only place the sound leaves
    /// from, so no verdict can forget it — the same rule as for saving.
    private func reveal(_ duelReport: DuelReport) {
        report = duelReport
        stage = .revealed
        guard let a = game.assault, let side = sideOfMine(in: a) else { return }
        let won = duelReport.outcome == .attackerBreaks ? side == a.attacker
                                                        : side == a.defender
        Sounds.shared.play(won ? .won : .lost)
    }

    /// Which side of the assault whoever is holding the device stands on.
    ///
    /// Over the network, my seat — and nothing if the assault does not
    /// concern me. Otherwise the human answering, since they are the one
    /// holding the device at verdict time, and failing that the human
    /// attacking. Two machines fighting each other do not sound: "won" and
    /// "lost" mean nothing to someone watching without playing.
    private func sideOfMine(in a: Assault) -> PlayerID? {
        if networked {
            return a.attacker == mySeat || a.defender == mySeat ? mySeat : nil
        }
        if !(player(a.defender)?.isBot ?? true) { return a.defender }
        if !(player(a.attacker)?.isBot ?? true) { return a.attacker }
        return nil
    }

    /// The side of whoever is holding the device, if they hold one.
    ///
    /// Over the network, my seat. Off the network, the first human at the
    /// table: with two humans on one device, that is whoever opened it.
    var mySide: PlayerID? {
        networked ? mySeat : game.players.first { !$0.isBot }?.id
    }

    /// A side's name as it is displayed.
    ///
    /// Three parts at most, from the most lasting to the most personal:
    ///
    ///     Red · Marie · me
    ///     └ the side  └ who  └ this side is mine
    ///
    /// The color first, because it is what ties the name to the board. The
    /// name next, when there is one. And "me" last, for the side of whoever
    /// is holding the device: over the network everyone sees the same names
    /// on all four screens, and without it nothing would say which one is
    /// theirs. That is what the old "(you)" said, less well — it could not
    /// live alongside a name.
    ///
    /// `withMe` is false for the top bar: it shows only one side, the one
    /// with the turn, and the rest of the screen already says it is yours.
    /// The "me" taught nothing there and pushed the name onto two lines — the
    /// bar grew by as much, at the board's expense.
    func displayName(_ p: Player, withMe: Bool = true) -> String {
        // A name already composed arrives as it is from the other device: the
        // host laid it down at launch, and adding this device's nickname to
        // it would stick mine on them. So we only compose ourselves what has
        // not been composed.
        var name = p.name
        if name == Boards.sideName(p.id), p.id == mySide, let nickname = Nickname.current {
            name += " · \(nickname)"
        }
        return withMe && p.id == mySide ? name + " · me" : name
    }

    /// Who has to answer — or, once the question is resolved, who has just
    /// done so: the verdict sheet appears after the engine has filed the
    /// question away, and it still needs to name someone.
    var responder: PlayerID? { game.whoAnswers ?? game.assault?.defender }

    var responderIsHuman: Bool {
        guard let who = responder else { return false }
        return !(player(who)?.isBot ?? true)
    }

    /// Can the defender double, and is it mine to decide?
    var canIRaise: Bool {
        game.canRaise && myTurnToAnswer && stage == .asking && report == nil
    }

    func raise() {
        guard canIRaise else { return }
        play(.raise)
    }

    func player(_ id: PlayerID) -> Player? { game.players.first { $0.id == id } }

    /// The territory touched by a finger. What it triggers depends on the
    /// phase: this is the only place the board is driven from.
    func tap(_ id: TerritoryID) {
        guard stage == nil, myTurnToPlay else { return }
        let me = game.currentPlayer.id
        switch game.phase {
        case .reinforcement:
            if game.owner[id] == me {
                // The note only lands if the troop is really laid down: the
                // move can be refused — no reinforcements left in reserve, or
                // five cards in hand that have to be traded first — and a
                // sound that sounds when nothing happens teaches you to stop
                // listening to it.
                let before = game.armies(id)
                play(.place(id))
                if game.armies(id) > before { Sounds.shared.play(.place) }
            }
            if case .attack = game.phase { selected = nil }

        case .attack:
            if game.owner[id] == me {
                selected = (selected == id) ? nil : (game.canLaunch(from: id) ? id : nil)
                target = nil
            } else if let base = selected, game.map.areAdjacent(base, id) {
                target = id
                draftQuestions = min(draftQuestions, game.maxQuestions(from: base))
                if !categoryChosen {
                    draftCategory = game.weakness(of: game.owner[id] ?? -1) ?? draftCategory
                }
                // The theme offered has to be one of the table's. Without
                // this reminder, a game that excludes the first theme in the
                // grid would open on a button the grid does not show: nothing
                // would appear chosen, and the player would not know why.
                if let c = draftCategory, !game.themesInPlay.contains(c) {
                    draftCategory = game.themesInPlay.first
                }
            }

        case .fortify:
            if game.owner[id] == me {
                if let base = selected, base != id, game.areLinked(base, id, for: me),
                   game.armies(base) >= 2 {
                    target = id
                } else {
                    selected = (selected == id) ? nil : id
                    target = nil
                }
            }

        case .occupation, .finished:
            break
        }
    }

    func cancelDraft() { target = nil }

    // MARK: - The assault

    func declare() {
        guard let base = selected, let aim = target else { return }
        guard game.canDeclare(from: base, to: aim, questions: draftQuestions) else { return }
        play(.declareAssault(from: base, to: aim,
                             questions: draftQuestions, category: draftCategory))
        target = nil
        resume()
    }

    /// Whoever is answering says they are ready: the hourglass starts at that
    /// instant, and not before. Without it, a player handing the device to
    /// another gives them three seconds less.
    func beginAnswering() {
        guard let duel else { return }
        stage = .asking
        startCountdown(duel.allowance)
    }

    func answer(_ index: Int?) {
        guard let duel, stage == .asking else { return }
        stopCountdown()
        let elapsed = max(0, duel.allowance - remaining)
        let duelReport = play(.answer(index.map { .chosen($0, elapsed: elapsed) } ?? .timeout))
        // Showdown: the first of the two answers shows nothing. Revealing it
        // would hand the solution to whoever still has to answer.
        guard let duelReport else {
            // Showdown: your answer is taken, but it settles nothing until
            // the other player has answered. Closing the sheet here was the
            // worst of choices — the screen came back to the same question,
            // the tap seemed lost, and you tapped a second time. That second
            // tap then landed on the verdict and whisked it away: the two
            // faults were really one.
            report = nil
            stage = .opponentAnswering
            resume()
            return
        }
        reveal(duelReport)
        pump?.cancel()
        pump = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pause(self.verdictTime)
            guard !Task.isCancelled else { return }
            self.report = nil
            self.stage = nil
            self.resume()
        }
    }

    /// After a finished assault: file it away, and take back control.
    func closeAssault() {
        play(.dismissAssault)
        report = nil
        stage = nil
        selected = nil
        resume()
    }

    func occupy(_ count: Int) {
        play(.occupy(count))
        report = nil
        stage = nil
        selected = nil
        resume()
    }

    // MARK: - The turn

    func endPhase() {
        guard myTurnToPlay else { return }
        play(.advance)
        selected = nil
        target = nil
        resume()
    }

    func fortify(_ count: Int) {
        guard let base = selected, let aim = target else { return }
        play(.fortify(from: base, to: aim, count: count))
        selected = nil
        target = nil
        resume()
    }

    func endTurn() {
        play(.endTurn)
        selected = nil
        target = nil
        resume()
    }

    // MARK: - The hourglass

    private func startCountdown(_ allowance: TimeInterval) {
        remaining = allowance
        ticker?.invalidate()
        // The timer does not hold on to the session: if it has gone, the
        // timer unplugs itself. A `deinit` cannot do it — it is not on the
        // main actor, and the timer lives there.
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                guard self.stage == .asking else { return }
                self.remaining = max(0, self.remaining - 0.1)
                if self.remaining <= 0 { self.answer(nil) }
            }
        }
        // "common" mode: the hourglass must not stop because you scroll the
        // log with one hand while thinking with the other.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopCountdown() {
        ticker?.invalidate()
        ticker = nil
    }

    /// A wait you can cut short, and whose end you can see coming.
    ///
    /// `from` and `to` say where the bar stands at the start and where it has
    /// to arrive: two waits in a row can therefore draw a single continuous
    /// one.
    private func pause(_ seconds: Double, from start: Double = 1, to end: Double = 0) async {
        skipped = false
        waitPart = start
        let began = Date()
        while !skipped {
            let elapsed = min(1, Date().timeIntervalSince(began) / seconds)
            waitPart = start + (end - start) * elapsed
            if elapsed >= 1 { break }
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return }
        }
        skipped = false
        waitPart = end
    }

    /// The time it takes to read the prompt and its four choices.
    private func readingTime(_ q: AskedQuestion) -> Double {
        let chars = q.prompt.count + q.choices.reduce(0) { $0 + $1.count }
        return min(Tempo.readingMax,
                   max(Tempo.readingMin, Double(chars) / Tempo.charsPerSecond))
    }

    // MARK: - The machines' thread

    private func resume() {
        pump?.cancel()
        pump = Task { @MainActor [weak self] in await self?.loop() }
    }

    private func loop() async {
        while !game.isOver {
            // 1. A question is waiting for an answer.
            if let a = game.assault, let duel = a.current {
                report = nil
                // Over the network nobody "thinks" here: either it is my turn
                // to answer, or I am waiting for the move across the table.
                if networked {
                    if myTurnToAnswer {
                        stage = .handover
                    } else {
                        stage = game.rules.mode == .showdown ? .opponentAnswering : .asking
                    }
                    thinking = !myTurnToAnswer
                    return
                }
                guard let who = game.whoAnswers, let answerer = player(who) else { return }
                guard case let .machine(level, style) = answerer.kind else {
                    stage = .handover        // for a human to say "ready"
                    return
                }
                // Showdown: the defending machine first decides whether to
                // double the stake, before answering — afterwards it would no
                // longer be a bet.
                if game.canRaise, who == a.defender,
                   Bot.shouldRaise(game, duel: duel, level: level,
                                   style: style, player: who) {
                    game.raise()
                }
                // The first of the two answers reveals nothing: no verdict to
                // read, just time to watch it think.
                //
                // In a showdown the question never reappears while someone
                // else is answering it: whoever is watching has already read
                // it, and often already settled it.
                let showdown = game.rules.mode == .showdown
                let mute = showdown && a.defenderAnswer == nil
                stage = showdown ? .opponentAnswering : .asking
                thinking = true
                // Reading then verdict make one single moment, and therefore
                // one single descent of the bar: you read the question and
                // answer it in your head, then you see what it gave.
                let reading = showdown ? Tempo.thinking : readingTime(duel.question)
                let hinge = mute ? 0 : verdictTime / (reading + verdictTime)
                await pause(reading, from: 1, to: hinge)
                if Task.isCancelled { return }
                thinking = false
                let duelReport = game.answer(Bot.answer(to: duel, level: level,
                                                        rules: game.rules, player: who,
                                                        using: &game.rng))
                guard let duelReport else { stage = nil; continue }
                reveal(duelReport)
                await pause(verdictTime, from: hinge, to: 0)
                if Task.isCancelled { return }
                report = nil
                stage = nil
                continue
            }

            // 2. A finished assault. The machine files it away on its own;
            //    the human wants to look.
            if let a = game.assault, a.isOver {
                if game.currentPlayer.isBot {
                    // An assault you have been subjected to deserves its
                    // summary too. Without it, the place fell and the machine
                    // carried straight on: you had no time to see what you
                    // had just lost. It passes on its own, so as not to chop
                    // up its turn.
                    let concernsMe = networked
                        ? a.defender == mySeat
                        : !(player(a.defender)?.isBot ?? true)
                    if concernsMe {
                        report = nil
                        stage = .summary
                        await pause(Tempo.summary)
                        if Task.isCancelled { return }
                        stage = nil
                    }
                    if case .attack = game.phase { game.dismissAssault() }
                } else {
                    stage = .summary
                    return
                }
            }

            // 3. Otherwise: the machine's turn to play, or the human's to
            //    decide.
            guard game.currentPlayer.isBot else { stage = nil; return }
            let before = game.phase
            let step = BotRunner.step(&game)
            if step == .idle, before == game.phase, case .fortify = game.phase {
                game.endTurn()
            }
            // The machine has just declared: we stay on the map long enough
            // to see where the assault leaves from and where it lands.
            if case .declared = step {
                stage = .announcing
                await pause(Tempo.announcement)
                if Task.isCancelled { return }
                stage = nil
                continue
            }
            try? await Task.sleep(for: .milliseconds(step == .idle ? 120 : 380))
            if Task.isCancelled { return }
        }
        stage = nil
        thinking = false
        await announceVictory()
    }

    /// The ending, in its order: the duel sheet has closed, the board shows
    /// the last place taken, the winner is named — and that is where the
    /// sound lands, along with the name — and only then does the victory
    /// screen settle in.
    ///
    /// The sound is put here and not on the victory screen: on the screen,
    /// the music and the sheet opening would tread on each other. Here it has
    /// the board to itself, and the duel's last verdict finished sounding
    /// seconds ago — `Tempo.summary` is worth five and a half, and one sound
    /// interrupts another.
    private func announceVictory() async {
        guard case let .finished(winner) = game.phase else { return }
        if !victoryAnnounced {
            victoryAnnounced = true
            Sounds.shared.play(endSound(winner))
            show(Announcement(title: "\(game.playerName(winner)) wins!",
                              sub: nil, side: winner))
            // A wait that lets itself be interrupted: the loop is restarted
            // at every move, and a victory screen that never arrives would be
            // worse than one that arrives too early.
            try? await Task.sleep(for: .milliseconds(1_700))
        }
        victoryShown = true
    }

    /// The sound of the ending, according to who is living it.
    ///
    /// Two sounds are only worth it if the device knows who it is sounding
    /// for. Over the network it knows: my seat is mine, and the other screen
    /// will sound the opposite. Alone against the machine too — there is only
    /// one human, and it is the one watching.
    ///
    /// But with two humans on one phone, "my side" is whoever opened it and
    /// not whoever has just won: we would sound defeat at the winner half the
    /// time. There, the fanfare for everyone — the game was won by somebody
    /// in the room.
    private func endSound(_ winner: PlayerID) -> Sounds.Signal {
        let humans = game.players.filter { !$0.isBot }.count
        guard networked || humans == 1 else { return .victory }
        return winner == mySide ? .victory : .defeat
    }
}
