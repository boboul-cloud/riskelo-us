//
//  SetupView.swift
//  Riskelo US
//
//  Who plays, and against whom.
//
//  The machine's level is not an abstract difficulty: it is its share of
//  correct answers on an average question, at full time. So you know exactly
//  what you are up against — and the simulation showed that five points of
//  difference in knowledge is enough to tip two games out of three.
//

import SwiftUI

struct SetupView: View {

    // This screen opens on the quick game: "Settings" is not another game, it
    // is the same one, opened up. The values are therefore taken where the
    // home screen takes them, and not copied out here.
    @State private var count = QuickGame.sides
    @State private var humans = QuickGame.humans
    @State private var level = QuickGame.level
    @State private var style: Bot.Style = QuickGame.style
    /// Zero removes the rule; otherwise one correct answer in so many is
    /// worth a troop.
    @State private var scholarship = QuickGame.scholarship
    @State private var mix: Rules.Mix = QuickGame.mix
    @State private var board: Boards = QuickGame.board
    @State private var cards = QuickGame.cards
    @State private var totalWar = QuickGame.totalWar
    @State private var objectives = QuickGame.objectives
    @State private var mode: Rules.Mode = QuickGame.mode
    /// Sound is not a rule of the game: it holds for the app and is kept from
    /// one game to the next. Hence the system preferences rather than a state
    /// of this view.
    @AppStorage(Sounds.key) private var sounds = true
    /// The name of whoever is holding the device. Like the sound, it holds
    /// for the app and not for one game.
    @AppStorage(Nickname.key) private var nickname = ""
    /// How many different questions this device has already seen. Read once
    /// when the screen opens: the file does not move while a game is being
    /// set up, unless you ask to forget everything.
    @State private var seen = QuestionMemory.shared.distinctSeen()
    /// The same settings, opened from the lobby of a multi-device table. What
    /// makes no sense there disappears: the number of players is what the
    /// lobby asks for — one device per player — and a networked game has no
    /// machine, so neither strategy nor knowledge to give it. The button at
    /// the bottom launches nothing: it hands the settings back to the lobby,
    /// which will open the table with them.
    var forNetwork = false
    var onStart: ([Player], Rules, Boards) -> Void
    var onNetwork: (Rules, Boards) -> Void = { _, _ in }
    /// The full manual — it opens from inside a game too.
    var onManual: () -> Void = { }
    /// Offered only if there is something on the shelves.
    var onArchives: (() -> Void)?
    /// The way back to the home screen. Resuming a game in progress lives
    /// there now: it has no business among the sliders.
    var onBack: () -> Void = { }

    /// The settings as they already are, when you come back to change them.
    ///
    /// Without this, the screen started again from the quick game's values:
    /// a host who had chosen the World in showdown mode, and reopened to
    /// change a single box, found the Ring in classic mode — and left with it,
    /// without noticing. A settings screen must show what is, not what was on
    /// first launch.
    init(forNetwork: Bool = false,
         from start: (rules: Rules, board: Boards)? = nil,
         onStart: @escaping ([Player], Rules, Boards) -> Void,
         onNetwork: @escaping (Rules, Boards) -> Void = { _, _ in },
         onManual: @escaping () -> Void = { },
         onArchives: (() -> Void)? = nil,
         onBack: @escaping () -> Void = { }) {
        self.forNetwork = forNetwork
        self.onStart = onStart
        self.onNetwork = onNetwork
        self.onManual = onManual
        self.onArchives = onArchives
        self.onBack = onBack
        guard let start else { return }
        let r = start.rules
        _board = State(initialValue: start.board)
        _mode = State(initialValue: r.mode)
        _scholarship = State(initialValue: r.answersPerBonusMan ?? 0)
        _cards = State(initialValue: r.territoryCards)
        _totalWar = State(initialValue: r.dominationOverride == 0)
        _objectives = State(initialValue: r.objectives)
        // The mix cannot be read back from the rules: it has melted into draw
        // weights there. We find it again by comparing, failing which it
        // would have to be kept twice — and two copies always end up
        // differing.
        _mix = State(initialValue: Rules.Mix.allCases
            .first { $0.weights == r.difficultyWeights } ?? QuickGame.mix)
    }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            // The content centers itself in the height available rather than
            // sticking to the top: on an iPad or a Mac it floated at the top
            // of an empty screen. Scrolling only serves if the screen is too
            // short — an iPhone in landscape.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 26) {
                        Text(mode == .classic
                             ? "The die is replaced by a question.\nThe attacker picks the ground, the defender answers."
                             : "The die is replaced by a question.\nBoth get it: the surer, or the quicker, wins.")
                            .font(.subheadline).foregroundStyle(Palette.dim)
                            .multilineTextAlignment(.center)
                            .padding(.top, 22)

                        section("Mode of play") {
                            Picker("", selection: $mode) {
                                ForEach(Rules.Mode.allCases) { m in Text(m.label).tag(m) }
                            }
                            .pickerStyle(.segmented)
                            Text(mode.detail)
                                .font(.caption2).foregroundStyle(Palette.dim)
                            if mode == .showdown {
                                Text("Both know: the clock settles it. Neither of them: the "
                                     + "place holds, as on a tie of dice.")
                                    .font(.caption2).foregroundStyle(Palette.dim.opacity(0.8))
                            }
                        }

                        section("Board") {
                            Picker("", selection: $board) {
                                ForEach(Boards.allCases) { b in Text(b.label).tag(b) }
                            }
                            .pickerStyle(.segmented)
                            Text(board.detail)
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        if !forNetwork {
                        section("Players") {
                            Picker("", selection: $count) {
                                ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: count) { _, n in humans = min(humans, n) }
                        }

                        section("On this device") {
                            Picker("", selection: $humans) {
                                ForEach(1...count, id: \.self) {
                                    Text($0 == 1 ? "1 human" : "\($0) humans").tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            if humans > 1 {
                                Text("Taking turns: the device is passed before each question.")
                                    .font(.caption2).foregroundStyle(Palette.dim)
                            }
                        }

                        if humans < count {
                            section("Machine strategy") {
                                Picker("", selection: $style) {
                                    ForEach(Bot.Style.allCases, id: \.self) { st in
                                        Text(st.label).tag(st)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text(style.detail)
                                    .font(.caption2).foregroundStyle(Palette.dim)
                            }

                            section("Machine knowledge") {
                                HStack {
                                    Text(levelLabel).font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Spacer()
                                    Text("\(Int(level * 100))% correct answers")
                                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.dim)
                                }
                                Slider(value: $level, in: 0.35...0.90, step: 0.05)
                                    .tint(Palette.side(1))
                            }
                        }

                        }

                        section("Questions") {
                            Picker("", selection: $mix) {
                                ForEach(Rules.Mix.allCases) { d in
                                    Text(d.label).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(mix.detail)
                                .font(.caption2).foregroundStyle(Palette.dim)
                            questionTally
                        }

                        section("Scholarship reinforcement") {
                            HStack {
                                Text(scholarship == 0 ? "Off" : "One extra troop")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text(scholarship == 0 ? "—" : "every \(scholarship) correct answers")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Palette.dim)
                            }
                            Slider(value: Binding(get: { Double(scholarship) },
                                                  set: { scholarship = Int($0.rounded()) }),
                                   in: 0...10, step: 1)
                                .tint(Palette.held)
                            Text(mode == .classic
                                 ? "Only the defender answers: this reinforcement goes to whoever "
                                   + "holds their place by knowing. Measured, it widens the gap a "
                                   + "little between two unequal levels of knowledge — markedly so "
                                   + "below four."
                                 : "Both answer: the reinforcement goes to whoever knows, "
                                   + "attacking or defending.")
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        section("Game rules") {
                            Toggle(isOn: $cards) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Territory cards")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("One card per turn in which you take a place. "
                                         + "Three matching are worth troops, and the scale climbs.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.held)

                            Toggle(isOn: exclusive($totalWar, with: $objectives)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Total war")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("Every territory, no exceptions. "
                                         + "Expect about twice as many questions.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.lost)

                            Toggle(isOn: exclusive($objectives, with: $totalWar)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Personal conquests")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("Everyone is dealt a secret objective at the start — two "
                                         + "continents, so many places held, a side to bring down "
                                         + "— and filling it wins the game. The territory "
                                         + "threshold withdraws: the card decides, or nobody. The "
                                         + "count in the top bar then says nothing at all about "
                                         + "who is going to win.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.side(3))

                            if totalWar || objectives {
                                Text("These two do not go together: turning one on turns "
                                     + "the other off. Take the whole world, or fill your "
                                     + "conquest — you have to choose how the game ends.")
                                    .font(.caption2).foregroundStyle(Palette.dim.opacity(0.8))
                            }
                        }

                        section("You") {
                            TextField("No name", text: $nickname)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.white.opacity(0.06), in: Capsule())
                                .overlay(Capsule().stroke(Palette.dim.opacity(0.3), lineWidth: 1))
                                // Bounded on entry and not on display: the
                                // strip of sides fits on a single line, and a
                                // long name would set it scrolling for nothing.
                                .onChange(of: nickname) { _, typed in
                                    let short = String(typed.prefix(Nickname.maxLength))
                                    if short != typed { nickname = short }
                                }
                            Text("Optional. Your side will read \"Blue · "
                                 + "\(Nickname.current ?? "Alex") · me\" — the color, your "
                                 + "name, and \"me\" to say it is yours. Over the network it "
                                 + "travels: the others will see you that way, and you will "
                                 + "see them the same.")
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        section("Sound") {
                            Toggle(isOn: $sounds) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Game sounds")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("A short note for every troop laid down, another at "
                                         + "the outcome of every exchange — rising when it "
                                         + "goes your way, falling otherwise — and the "
                                         + "opening at launch. Holds for every game, not for "
                                         + "this one alone.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.held)
                        }

                        VStack(spacing: 4) {
                            Text(victorySummary)
                                .font(.footnote).foregroundStyle(Palette.dim)
                                .multilineTextAlignment(.center)
                            if compensation > 0 {
                                Text("Whoever opens starts \(compensation) troops down: "
                                     + "here the defense wins, and opening costs.")
                                    .font(.caption2).foregroundStyle(Palette.dim)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        if forNetwork {
                            Button { onNetwork(rules, board) } label: {
                                Label("Open the table with these settings",
                                      systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent).tint(Palette.side(4))
                        } else {
                        Button { onStart(players, rules, board) } label: {
                            Text("Start").font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent).tint(Palette.side(0))

                        if let onArchives {
                            Button(action: onArchives) {
                                Label("Saved games", systemImage: "books.vertical")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered).tint(Palette.dim)
                        }

                        Button { onNetwork(rules, board) } label: {
                            Label("Play across devices",
                                  systemImage: "iphone.gen3.radiowaves.left.and.right")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered).tint(Palette.dim)
                        }

                        Button(action: onManual) {
                            Label("How to play", systemImage: "book")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered).tint(Palette.dim)

                        // The legal text is in the manual too, but nobody
                        // hunts for their terms of use in chapter fourteen of
                        // a handbook: it belongs where you wonder what you are
                        // signing up for, before starting. Three links, small,
                        // under everything else.
                        legalFooter
                            .padding(.bottom, 30)
                    }
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
        // The bar sits in the safe-area inset rather than at the head of the
        // scroll: the page is long, and a back button that leaves as soon as
        // you scroll down is no longer a back button.
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                // You go back where you came from, and we do not promise it
                // wrongly: from a table's lobby, it is not the home screen
                // waiting behind.
                Label(forNetwork ? "The table" : "Home", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer(minLength: 12)
        }
        // The title as an overlay rather than between two spacers: it stays
        // centered on the bar whatever the length of the left-hand button.
        .overlay {
            Text("Settings").font(.headline).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.panel)
    }

    /// Privacy, terms, website: the three public addresses, at the foot of
    /// the home screen. They leave the app — the system opens the browser —
    /// and so they are written in grey, like everything that is not a move to
    /// play.
    private var legalFooter: some View {
        HStack(spacing: 9) {
            link("Privacy", Manual.privacyURL)
            separator
            link("Terms", Manual.termsURL)
            separator
            link("Website", Manual.siteURL)
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Text("·").font(.caption).foregroundStyle(Palette.dim.opacity(0.45))
    }

    /// `SwiftUI.Link` spelled out: in this module, `Link` on its own means the
    /// wire between two devices, and that one wins.
    @ViewBuilder private func link(_ title: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            SwiftUI.Link(title, destination: url)
                .foregroundStyle(Palette.dim)
        }
    }

    /// What the device has already seen go by, and how to forget it all.
    ///
    /// Nothing is set here: a question never asked comes before a question
    /// already seen, and that is all. But it shows — without it the player
    /// would know neither why their questions stop coming back, nor what to
    /// do the day they have been all the way through the bank.
    private var questionTally: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Already asked on this device: \(seen) of \(QuestionBank.all.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.ink)
                Text("From one game to the next, a question never asked comes before "
                     + "a question already seen.")
                    .font(.caption2).foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if seen > 0 {
                Button("Forget") {
                    QuestionMemory.shared.forget()
                    seen = 0
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered).tint(Palette.dim)
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased()).font(.caption.weight(.semibold))
                .foregroundStyle(Palette.dim).kerning(0.6)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var levelLabel: String { QuickGame.levelNamed(level) }

    /// Two rules that cannot stand together: turning this one on turns the
    /// other off.
    ///
    /// Total war demands the whole board, a personal conquest is often won in
    /// three continents: side by side, the second always ends the game before
    /// the first, and the first no longer means anything. So the setting
    /// decides for the player, instead of letting them compose a game half of
    /// which would be dead.
    ///
    /// They resemble each other more since conquest withdrew the threshold —
    /// both are played with no count to cross — but they do not end the same
    /// way: one asks for the board, the other for a card.
    private func exclusive(_ this: Binding<Bool>, with other: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { this.wrappedValue },
                set: { on in
                    this.wrappedValue = on
                    if on { other.wrappedValue = false }
                })
    }

    private var threshold: Int {
        Rules().dominationThreshold(territories: board.board.map.order.count,
                                    playerCount: count)
    }

    /// What has to be done to win, in one line, under the settings.
    ///
    /// Personal conquests withdraw the threshold: announcing a number of
    /// territories would be false, and that was the misunderstanding — you
    /// won on count while believing you were playing your card.
    private var victorySummary: String {
        let total = board.board.map.order.count
        if objectives {
            return "Victory by personal conquest, and nothing else"
        }
        return totalWar
            ? "Victory by taking all \(total) territories"
            : "Victory at \(threshold) territories out of \(total)"
    }

    private var compensation: Int { Rules().compensation(playerCount: count) }

    private var rules: Rules {
        QuickGame.rules(scholarship: scholarship, mix: mix, cards: cards,
                        mode: mode, totalWar: totalWar, objectives: objectives)
    }

    private var players: [Player] {
        QuickGame.players(count: count, humans: humans,
                          level: level, style: style)
    }
}
