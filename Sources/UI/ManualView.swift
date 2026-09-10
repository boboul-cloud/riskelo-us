//
//  ManualView.swift
//  Riskelo US
//
//  The manual, inside the app.
//
//  A board game is played with its rules on the table, and these do not fit
//  on a home screen. So they live here, in fourteen chapters, and they open
//  as readily before a game as during one: the question mark in the top bar
//  lays them over the board without interrupting anything — the turn waits,
//  the game is untouched.
//
//  Two levels, like the library: a table of contents you can take in at a
//  glance, then one chapter at a time. All of it flat would have made two
//  thousand words in one block, which is to say a text nobody opens twice.
//
//  The text is written here and nowhere else, and the numbers it quotes —
//  fifteen seconds, the card scale, the victory threshold — are read from the
//  engine rather than copied. A setting that moves over there corrects itself
//  here.
//

import SwiftUI

// MARK: - The screen

struct ManualView: View {

    /// Laid over a game, the manual closes; opened from the home screen, it
    /// closes too. It is the same gesture.
    var onClose: () -> Void

    @State private var chapter: Chapter?

    var body: some View {
        content
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(Palette.sea)
            .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        if let chapter {
            page(chapter)
        } else {
            contents
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                if chapter != nil { withAnimation { chapter = nil } } else { onClose() }
            } label: {
                Label(chapter == nil ? "Close" : "Contents", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer(minLength: 12)
        }
        // The title as an overlay rather than between two spacers: it stays
        // centered whatever the length of the left-hand button.
        .overlay {
            Text(chapter?.title ?? "How to play")
                .font(.headline).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 90)
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.panel)
    }

    // MARK: Table of contents

    private var contents: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Riskelo US")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("A conquest game where the roll of the dice is replaced by a "
                         + "trivia question. Everything the app does is written down "
                         + "here.")
                        .font(.footnote).foregroundStyle(Palette.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)

                ForEach(Manual.chapters) { c in
                    Button { withAnimation { chapter = c } } label: { row(c) }
                        .buttonStyle(.plain)
                }

                Text("Riskelo US \(Manual.version) — \(Manual.site)")
                    .font(.caption2).foregroundStyle(Palette.dim.opacity(0.7))
                    .padding(.top, 10)
            }
            .padding(18)
        }
    }

    private func row(_ c: Chapter) -> some View {
        HStack(spacing: 13) {
            Image(systemName: c.icon)
                .font(.system(size: 16))
                .frame(width: 30, height: 30)
                .background(c.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(c.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(c.summary).font(.caption).foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.dim.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: One chapter

    private func page(_ c: Chapter) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: c.icon).font(.system(size: 15))
                        .foregroundStyle(c.tint)
                    Text(c.summary).font(.caption).foregroundStyle(Palette.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 2)

                ForEach(Array(c.blocks.enumerated()), id: \.offset) { _, block in
                    BlockView(block: block, tint: c.tint)
                }

                if let next = Manual.after(c) {
                    Button { withAnimation { chapter = next } } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Next chapter").font(.caption2)
                                    .foregroundStyle(Palette.dim)
                                Text(next.title).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.dim)
                        }
                        .padding(13)
                        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - The building blocks of a chapter

/// A chapter is a run of blocks, and each block has one shape and one only.
/// Writing the manual therefore means writing data, never views, and
/// correcting the text does not touch the layout.
enum Block {
    /// A paragraph.
    case p(String)
    /// A subheading.
    case h(String)
    /// A bulleted list.
    case bullets([String])
    /// A term and what it does — the shape of the settings.
    case terms([(String, String)])
    /// A table with equal columns, header included.
    case table([String], [[String]])
    /// A monospaced block: a scale, a ladder.
    case code(String)
    /// What you should not miss.
    case note(String)
    /// Links that leave the app: a title, what you find there, and the
    /// address. The one place in the manual that leads outside.
    case links([(String, String, String)])
}

private struct BlockView: View {
    let block: Block
    let tint: Color

    var body: some View {
        switch block {
        case let .p(text):
            Text(text)
                .font(.subheadline).foregroundStyle(Palette.ink.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .h(text):
            Text(text.uppercased())
                .font(.caption.weight(.semibold)).kerning(0.6)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

        case let .bullets(items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(tint.opacity(0.8))
                            .frame(width: 5, height: 5).padding(.top, 7)
                        Text(item).font(.subheadline)
                            .foregroundStyle(Palette.ink.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .terms(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0).font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(item.1).font(.caption).foregroundStyle(Palette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(13)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))

        case let .table(headers, rows):
            VStack(spacing: 0) {
                row(headers, header: true)
                ForEach(Array(rows.enumerated()), id: \.offset) { i, line in
                    Divider().overlay(Palette.dim.opacity(0.25))
                    row(line, header: false, even: i.isMultiple(of: 2))
                }
            }
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Palette.dim.opacity(0.18), lineWidth: 1))

        case let .code(text):
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

        case let .links(items):
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    if i > 0 { Divider().overlay(Palette.dim.opacity(0.25)) }
                    // A malformed address does not give a dead row: it gives
                    // no row at all.
                    //
                    // `SwiftUI.Link` spelled out: in this module, `Link` on
                    // its own means the wire between two devices.
                    if let url = URL(string: item.2) {
                        SwiftUI.Link(destination: url) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                    Text(item.1).font(.caption).foregroundStyle(Palette.dim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: item.2.hasPrefix("mailto:")
                                      ? "envelope" : "arrow.up.right.square")
                                    .font(.footnote).foregroundStyle(tint)
                            }
                            .padding(.horizontal, 13).padding(.vertical, 12)
                            // The whole row answers, not just the text.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))

        case let .note(text):
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb.fill").font(.caption)
                    .foregroundStyle(tint).padding(.top, 2)
                Text(text).font(.footnote)
                    .foregroundStyle(Palette.ink.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.4), lineWidth: 1))
        }
    }

    private func row(_ cells: [String], header: Bool, even: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(c)
                    .font(header ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(header ? tint
                                     : (i == 0 ? Palette.ink : Palette.ink.opacity(0.85)))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(header ? Color.white.opacity(0.05)
                    : (even ? Color.clear : Color.white.opacity(0.02)))
    }
}

// MARK: - The text

struct Chapter: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let icon: String
    let tint: Color
    let blocks: [Block]

    static func == (a: Chapter, b: Chapter) -> Bool { a.id == b.id }
}

enum Manual {

    /// A board's possible conquests, spelled out.
    ///
    /// Generated, not copied. The deck is cut to fit the board — two big
    /// continents, three small, shares of territory — and a list written by
    /// hand would start lying at the first continent that changes size. The
    /// elimination cards are left out: they take one sentence, and there is
    /// one per side.
    static func conquests(_ board: Boards) -> [String] {
        Objective.deck(for: board.board, players: 2).map { $0.text(board.board) }
    }

    /// What the fallback costs, board by board — read from the engine. Three
    /// numbers written by hand would lie the day the share changes, and it
    /// would be the manual that was wrong.
    static var fallbacks: String {
        Objective.list(Boards.allCases.map { board in
            "\(Objective.fallback(board.board).countRequired ?? 0) on \(board.label)"
        })
    }

    /// The victory thresholds, board by board and by number of players — read
    /// from the rules rather than tabulated by hand, for the same reason.
    static var victoryRows: [[String]] {
        let rules = Rules()
        return Boards.allCases.map { board in
            let total = board.board.map.order.count
            return ["\(board.label) — \(total) territories"]
                + [2, 3, 4].map {
                    "\(rules.dominationThreshold(territories: total, playerCount: $0))"
                }
        }
    }

    /// The themes that ship with the game, named by the catalogue. Read from
    /// the question files, so that a theme added or renamed does not leave
    /// the manual behind.
    static var baseThemes: [String] { Themes.base.map(\.label) }

    /// How many questions the app carries, counted rather than claimed.
    static var questionCount: Int { QuestionBank.all.count }

    /// The version, read from the bundle and not copied here.
    ///
    /// It used to be written by hand, and it stayed at "1.0" when the project
    /// moved to 1.1: the manual announced a version the app no longer was,
    /// and it is the one place a player reads a number. One source —
    /// `project.yml`, which writes the plist — and nothing left to keep up to
    /// date.
    static let version: String = {
        let number = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return "version \(number ?? "—")"
    }()
    static let site = "boboul-cloud.github.io/riskelo-us"
    static let contact = "bob.oulhen@gmail.com"

    /// The app's four addresses, written here and nowhere else: the home
    /// screen draws its own from these. A site that moves is corrected in one
    /// place.
    static let siteURL = "https://boboul-cloud.github.io/riskelo-us/"
    static let privacyURL = "https://boboul-cloud.github.io/riskelo-us/privacy.html"
    static let termsURL = "https://boboul-cloud.github.io/riskelo-us/terms.html"
    static let contactURL = "mailto:bob.oulhen@gmail.com"

    static func after(_ c: Chapter) -> Chapter? {
        guard let i = chapters.firstIndex(of: c), i + 1 < chapters.count else { return nil }
        return chapters[i + 1]
    }

    static let chapters: [Chapter] = [
        firstGame, duel, showdown, turn, victory, setup, screen,
        cards, file, memory, network, bank, tips, legal,
    ]

    // MARK: 1

    private static let firstGame = Chapter(
        id: "start", title: "In two minutes",
        summary: "What you need to play your first turn.",
        icon: "bolt.fill", tint: Palette.side(0),
        blocks: [
            .p("Riskelo US is a conquest game: territories, troops, and an opponent "
               + "to dislodge. There are no dice. When you attack, a trivia question "
               + "decides the outcome."),
            .h("Your first turn"),
            .bullets([
                "Tap \"Quick game\": two players, the Ring board, a machine of medium "
                + "knowledge. The settings can wait.",
                "Your territories carry your color and the number of troops holding "
                + "them. The ones you cannot play stay in shadow.",
                "Reinforce: tap your territories to lay down the troops the hint "
                + "names, one per tap.",
                "Attack: tap one of your territories with at least two troops, then an "
                + "enemy neighbor. A panel opens — pick the theme of the question and "
                + "how many questions, then \"Launch the assault\".",
                "Move: one only, to a territory of yours linked to the one you start "
                + "from. Then \"End turn\".",
            ]),
            .note("The bottom bar always says what is expected of you, and the feed of "
                  + "three steps says how far along the turn you are. When in doubt, "
                  + "that is where to look."),
            .h("What the question decides"),
            .p("The defender answers, within the time on the clock. Answer right and "
               + "you lose a troop; answer wrong or let the time run out and they do. "
               + "One question is worth exactly one pair of dice in Risk: it costs one "
               + "side a troop."),
            .p("The second mode, \"showdown\", puts the same question to both players "
               + "— it has a chapter of its own."),
        ])

    // MARK: 2

    private static let duel = Chapter(
        id: "duel", title: "The duel",
        summary: "The question stands in for the die — who asks, who answers, how long they have.",
        icon: "questionmark.circle.fill", tint: Palette.blue,
        blocks: [
            .p("The attacker chooses two things: the theme of the question, and how "
               + "many questions — one or two. Those are their dice. The defender "
               + "answers."),
            .table(["What the defender does", "The dice equivalent", "Who loses a troop"],
                   [["Right answer", "Higher die", "The attacker"],
                    ["Wrong answer", "Lower die", "The defender"],
                    ["Time runs out", "The lowest die", "The defender"]]),
            .h("One question or two"),
            .p("Two questions means two chances to take the place — and two possible "
               + "losses on your side. The bet is Risk's. You can only launch as many "
               + "questions as your stack can pay for: a territory of two troops asks "
               + "one."),
            .h("The theme never wanders"),
            .p("The theme you ask for is honored: the bank never leaves the category "
               + "you chose. Once it runs dry it starts over rather than drifting to "
               + "another subject. That is what makes choosing the ground reliable — "
               + "and that is where your skill lies."),
            .h("Or the theme left to chance"),
            .p("Under the six theme tiles sits a seventh choice: \"at random\". The "
               + "question is then drawn from the whole bank, theme included. You give "
               + "up your only advantage — and in a showdown, where you answer too, "
               + "you give up a ground you were picking for yourself as much as for "
               + "your opponent."),
            .h("A question does not come back"),
            .p("Within a game, a theme serves all its questions before repeating one. "
               + "Between games too: the device remembers what has already come up, "
               + "and at equal difficulty a question never seen goes ahead of one "
               + "already asked. The count is in the settings, where you can also "
               + "clear it."),
            .h("The clock, and the wear of a siege"),
            .p("Fifteen seconds on the first question. A player who knows would never "
               + "lose their place: what replaces the statistics of the die is time "
               + "tightening. Every question the same territory faces, within the same "
               + "turn, shortens the clock."),
            .code("1st question    15.0 s\n2nd             11.7 s\n3rd              9.1 s\n"
                  + "4th              7.1 s\n5th and after    6.0 s"),
            .p("The clock resets between turns. Pressing a place therefore pays in the "
               + "end — but it is the defender's breath that gives out, not the luck of "
               + "a roll."),
            .h("Taking the place"),
            .p("When the last garrison falls, you choose how many troops advance: at "
               + "least as many as there were questions, and never your last troop — a "
               + "territory always keeps one."),
            .note("The machine always answers something: running out of time is a human "
                  + "act, and a human one only."),
        ])

    // MARK: 3

    private static let showdown = Chapter(
        id: "showdown", title: "Showdown",
        summary: "The second mode: both players answer the same question.",
        icon: "person.2.fill", tint: Palette.side(1),
        blocks: [
            .p("In classic play only one hand rolls the dice: the defender answers, and "
               + "the attacker's knowledge does them no good while attacking. It is "
               + "armor, never a weapon. In a showdown, both get the same question."),
            .table(["What happens", "What follows"],
                   [["Only one of them knows", "They win the exchange"],
                    ["Both know", "The clock settles it; a strict tie goes to the defender"],
                    ["Neither knows", "The place holds — Risk's tie"]]),
            .p("Settling it on the clock is not an ornament: without it nobody would "
               + "ever take a place again and the game would freeze. It settles about "
               + "four exchanges in ten."),
            .note("Speed never separates two unequal answers: a fast ignoramus does not "
                  + "beat a slow scholar. It only decides what Risk decided with the "
                  + "number on the die."),
            .h("The verdict sheet"),
            .p("Both answers appear side by side, each with its time, and a crown on "
               + "the one that wins. It is necessary: without it you answer correctly, "
               + "lose a place, and can only think the game got it wrong."),
            .h("The raise — doubling the stake"),
            .p("Before answering, the defender can double: the exchange will be worth "
               + "two troops instead of one, whichever way it falls. The button appears "
               + "only for them, and only before they answer."),
            .p("Doubling is not a show of strength, it is a throw of the dice: when "
               + "both players know, the exchange comes down to the clock, which is a "
               + "coin toss — for two troops. And chance serves whoever is behind and "
               + "costs whoever leads."),
            .note("A stake of two never pays more than the stack across the line can "
                  + "afford: you do not strip the attacker of their last garrison. "
                  + "Doubling against a stack of two troops therefore wins one troop."),
            .h("On a shared device"),
            .p("Each player answers in turn, the device passes between them, and the "
               + "screen waits for an \"I'm ready\" before starting the clock — nobody "
               + "sees the question before their turn."),
        ])

    // MARK: 4

    private static let turn = Chapter(
        id: "turn", title: "The turn",
        summary: "Reinforce, attack, one move — then the turn passes.",
        icon: "arrow.triangle.2.circlepath", tint: Palette.side(2),
        blocks: [
            .h("1 — Reinforcements"),
            .p("One troop per three territories held, with a floor of three troops, "
               + "plus the bonus of every continent you hold whole. Tap your "
               + "territories to lay them down, one per tap. While any remain, the turn "
               + "does not pass."),
            .h("2 — Attacks"),
            .p("As many assaults as you like, as long as you have stacks of at least "
               + "two troops. Tap the territory you set out from, then an enemy "
               + "neighbor: the assault panel opens. It shows the balance of forces, "
               + "the six themes with what the defender has shown on each — or the "
               + "theme at random — and the choice of one or two questions."),
            .p("A place taken is garrisoned at once: you choose how many troops "
               + "advance, at least as many as there were questions."),
            .h("3 — The move"),
            .p("One only, at the end of the turn: from one of your territories to "
               + "another of yours, linked to the first by an unbroken chain of "
               + "friendly territories. You can also end without moving anything."),
            .note("A territory is never left empty: one troop always stays, at the "
                  + "start as at the finish."),
            .h("What the turn pays as it passes"),
            .bullets([
                "The scholarship reinforcement: one extra troop for every N correct "
                + "answers within one theme, if the rule is in play.",
                "A territory card, if the rule is in play and you took at least one "
                + "place during the turn.",
            ]),
        ])

    // MARK: 5

    private static let victory = Chapter(
        id: "victory", title: "Winning the game",
        summary: "The domination threshold, personal conquests, elimination.",
        icon: "flag.checkered", tint: Palette.held,
        blocks: [
            .p("Winning does not require taking everything: you have to hold your "
               + "starting share plus seven territories. It is a gap, not a fixed share "
               + "of the world — one player in four starts from 25%, not 50%."),
            .table(["Board", "2 players", "3", "4"], Manual.victoryRows),
            .p("The top bar carries that count at all times: your territories over the "
               + "threshold to cross. Personal conquests, further down, withdraw that "
               + "threshold: the bar then shows the whole board."),
            .h("Total war"),
            .p("The option removes the threshold: every territory, no exceptions. "
               + "Expect about twice as many questions — 112 instead of 71 with two "
               + "players. It is a whole evening's game, and that is the point."),
            .h("Personal conquests"),
            .p("The option deals everyone a secret objective at the start. Filling it "
               + "wins the game on the spot, and it is the only way to win: the "
               + "threshold in the table above withdraws. The count in the top bar then "
               + "says nothing about who is going to win — whoever looks behind may be "
               + "holding their two continents."),
            .bullets([
                "Hold two big continents, or three small ones — taken from the size of "
                + "the board, since the Ring has no Australia.",
                "Hold so many territories: about half the board, or fewer if two or "
                + "three troops are required on each.",
                "Bring down a side, by your own hand — at three players and above.",
            ]),
            .p("Here they all are, board by board. They are dealt without replacement: "
               + "two players never have the same one."),
            .h("On the Ring"),
            .bullets(Manual.conquests(.ring)),
            .h("On Europe"),
            .bullets(Manual.conquests(.europe)),
            .h("On the World"),
            .bullets(Manual.conquests(.world)),
            .p("At three players and above, one card per side is added: \"wipe out "
               + "Red's side\", or Green's, Amber's or Purple's — and never your own."),
            .p("A target somebody else brings down before you does not count: your card "
               + "turns over and becomes a territory conquest, as in Risk. Otherwise "
               + "you would spend the rest of the game unable to win."),
            .p("That fallback asks for four places out of five on the board — "
               + "\(Manual.fallbacks). It is the only threshold left in a game with "
               + "conquests, and it counts only for the player whose card has died: any "
               + "cheaper and bad luck would become a shortcut, and you would win faster "
               + "for having lost your prey than for having held your continents."),
            .p("The target button in the top bar shows yours and how far along you are. "
               + "It never shows anyone else's: across devices, each player sees only "
               + "their own; on a shared device, it shows the conquest of whoever is "
               + "playing — you do not look at your neighbor's card. They all turn over "
               + "at the end, on the victory screen."),
            .note("The machine is dealt a conquest like you, and can win by it. It does "
                  + "not chase it, though: it plays the way it has always played, and "
                  + "that is your advantage."),
            .h("Elimination"),
            .p("A player who loses their last territory is eliminated; their name stays "
               + "struck through in the strip of sides. If territory cards are in play, "
               + "whoever finishes them off takes their hand."),
            .h("Opening costs"),
            .p("With two players, whoever goes first starts two troops down: without "
               + "that they would win six games in ten. Beyond two players the advantage "
               + "dilutes on its own — whoever strikes first exposes themselves to two "
               + "neighbors instead of one."),
        ])

    // MARK: 6

    private static let setup = Chapter(
        id: "settings", title: "Setting up",
        summary: "Every setting behind the \"Settings\" button, one by one.",
        icon: "slider.horizontal.3", tint: Palette.green,
        blocks: [
            .h("Mode of play"),
            .terms([
                ("Classic", "The attacker picks the theme, the defender alone answers."),
                ("Showdown", "Both answer the same question; the defender can double "
                 + "the stake."),
            ]),
            .h("Board"),
            .terms([
                ("The Ring", "An invented world, five lands in a circle. 28 territories. "
                 + "The shortest game."),
                ("Europe", "From the Atlantic to the Black Sea. 38 territories, six regions."),
                ("World", "The six continents, 42 territories — like the box."),
            ]),
            .h("Players, and humans on this device"),
            .p("Two to four players. The second setting says how many are sitting in "
               + "front of this screen: the rest are held by the machine. With several "
               + "humans on one device, it is passed before each question, and the "
               + "screen waits for an \"I'm ready\"."),
            .h("Machine strategy"),
            .terms([
                ("Easy", "It advances at random and scatters one-troop garrisons."),
                ("Medium", "It holds what it takes and looks for your weak spots."),
                ("Strong", "It concentrates its reinforcements on a single spearhead, "
                 + "aims at the continent closest to complete, finishes off a place "
                 + "already pressed whose clock has shortened, and stops attacking when "
                 + "its stack is down to two troops."),
            ]),
            .h("Machine knowledge"),
            .p("This is not an abstract difficulty: it is the machine's share of "
               + "correct answers on an average question, from 35% to 90%. So you know "
               + "exactly what you are up against. Distracted, fair, well-read, "
               + "formidable — five points of difference is enough to tip two games in "
               + "three."),
            .p("Its knowledge and its maneuvering are two separate settings: you can be "
               + "learned and play badly."),
            .h("Questions"),
            .terms([
                ("Easy", "Gentle enough to play with children."),
                ("Mixed", "All three levels, as in a boxed game."),
                ("Tough", "For anyone who finds the rest too easy."),
            ]),
            .h("Scholarship reinforcement"),
            .p("One extra troop for every N correct answers within one theme. The "
               + "slider runs from 0 to 10; at zero the rule is removed. Five is the "
               + "default; three makes knowledge weigh more."),
            .p("In classic play only the defender answers, so this reinforcement goes "
               + "to whoever holds their place by knowing. In a showdown it goes to "
               + "whoever knows, attacking or defending."),
            .h("Game rules"),
            .terms([
                ("Territory cards", "One card per turn in which you take a place; three "
                 + "matching are worth troops, and the scale climbs."),
                ("Total war", "Every territory, no exceptions. About twice as many "
                 + "questions."),
                ("Personal conquests", "A secret objective each; filling it wins, and "
                 + "the territory threshold withdraws."),
            ]),
            .h("You"),
            .p("A name, optional, for whoever is holding the device. It is added to the "
               + "side's color without replacing it — \"Blue · Alex\" — because the "
               + "board knows nothing but colors: a name that cannot be found there "
               + "would be no use. Fourteen characters at most, so the strip of sides "
               + "fits on one line."),
            .p("Over the network it travels: each device says its name on arriving in "
               + "the lobby, and all four screens show the same players. Yours carries "
               + "\"me\" at the end — otherwise, with everyone seeing the same thing, "
               + "nothing would say which one is yours."),
            .h("Sound"),
            .p("A short muted note for every troop you lay down — discreet enough to "
               + "repeat ten times running without wearing thin. Then a note at the "
               + "outcome of every exchange: rising when it goes your way, falling when "
               + "it goes against you. Two machines fighting each other stay silent — "
               + "you have no part in it. Plus the opening, when the app launches."),
            .p("It is the one setting on this screen that is not about the game: it "
               + "holds for the whole app and is kept from one game to the next. On an "
               + "iPhone the silent switch mutes it, and the music you were listening "
               + "to carries on."),
            .h("The buttons at the bottom"),
            .terms([
                ("Start", "Launches the game with what is set above. Resuming a game in "
                 + "progress is on the home screen instead."),
                ("Saved games", "The library of moments — see the chapter \"Resume, "
                 + "mark, go back\"."),
                ("Play across devices", "One device per player, up to four, in the same "
                 + "room."),
            ]),
        ])

    // MARK: 7

    private static let screen = Chapter(
        id: "screen", title: "The game screen",
        summary: "What each bar carries, and what answers to a finger.",
        icon: "rectangle.3.group.fill", tint: Palette.wood,
        blocks: [
            .h("The top bar"),
            .terms([
                ("The chevron", "Leaves the game. It is saved before you go out: "
                 + "nothing is lost."),
                ("The dot and the name", "The side with the turn. Yours reads \"Red · "
                 + "Marie · me\": the color, the name you gave yourself in the "
                 + "settings, and \"me\" to say it is yours."),
                ("Turn, and the count", "The number of the round, and your territories "
                 + "over the victory threshold — over the whole board when personal "
                 + "conquests are in play, since there is no threshold then."),
                ("The deck of cards", "Your hand, when the rule is in play. The badge "
                 + "turns red when the trade becomes compulsory."),
                ("The bookmark", "Shelves the present moment in the library."),
                ("The file card", "The file: what each player has shown they know, "
                 + "theme by theme."),
                ("The list", "The game's log, move by move."),
                ("The question mark", "This manual, without leaving the game."),
            ]),
            .h("The board"),
            .bullets([
                "A single tap on a territory: it is the only gesture in the game, and "
                + "what it does depends on the current step.",
                "Two fingers to zoom, one finger dragging to pan. The button at the "
                + "bottom right recenters it.",
                "The playable territories are the only ones not in shadow.",
                "A bright hairline marks continental borders; a thin dotted line, the "
                + "sea crossings.",
            ]),
            .h("The strip of sides"),
            .p("Under the map: each player, their territories, their troops, and a flag "
               + "in their color on whoever has the turn. An eliminated player is "
               + "struck through."),
            .p("Below that, a strip names the continents with their bonus. Each keeps "
               + "its own color — the color of its outline on the map, and that is what "
               + "ties the two together. A continent held whole also carries the dot "
               + "and outline of its owner: that is how you see at a glance who is "
               + "close to the bonus."),
            .h("The bottom bar"),
            .terms([
                ("The hint", "What is expected of you. It has the shape of a button but "
                 + "not its clothes: veiled ground, ordinary text. Three tones — the "
                 + "side's color when it is waiting for something, red when something "
                 + "is blocking you, the other side's color when it is not your turn."),
                ("The turn feed", "The three beats — reinforce, attack, move — and how "
                 + "far along you are. When it is the machine's turn, it shows how far "
                 + "along it is in theirs."),
                ("The button", "\"Attack\", \"Move\", \"End turn\". It stays dimmed "
                 + "while an obligation is unmet — reinforcements not laid down, an "
                 + "assault in progress, five cards in hand. \"Move\" asks for "
                 + "confirmation before closing the attack, which does not reopen that "
                 + "turn."),
            ]),
            .h("Following the machine"),
            .p("When it attacks, the game goes through the map before the duel: the two "
               + "places light up, an arrow runs from one to the other, and the bottom "
               + "bar says who is attacking what, with how many questions and on what "
               + "ground. A tap cuts the announcement short — as everywhere else."),
            .h("The duel"),
            .p("The question rises from the bottom without hiding the board: you see "
               + "the troops fall while you answer. The time bar is in color when it is "
               + "your clock, grey when it is the other player's reading time. After "
               + "the answer, the right choice turns green and yours turns red if you "
               + "got it wrong; the verdict always names whoever answered."),
        ])

    // MARK: 8

    private static let cards = Chapter(
        id: "cards", title: "Territory cards",
        summary: "The option that changes the economics of reinforcement.",
        icon: "rectangle.stack.fill", tint: Palette.gold,
        blocks: [
            .p("As in the box: one card per territory, plus two wild cards. Each card "
               + "carries a symbol — infantry, cavalry, artillery."),
            .h("How you earn them"),
            .p("One card at the end of a turn in which you took at least one place. "
               + "Waiting pays nothing: nerve is what draws."),
            .h("The trade"),
            .p("Three matching cards — three identical symbols or three different ones, "
               + "the wild card standing in for any — trade for troops during the "
               + "reinforcement phase. Open your hand from the deck in the top bar, "
               + "pick three cards, trade."),
            .h("The scale climbs with every trade in the game"),
            .code("1st trade      4 troops\n2nd            6\n3rd            8\n"
                  + "4th           10\n5th           12\n6th           15\n"
                  + "then          +5 each time"),
            .p("Two extra troops if one of the three cards carries a territory you "
               + "hold. The climbing scale is what keeps a game from bogging down — and "
               + "holding your cards does not make them gain value, it only lets the "
               + "value climb for your opponent."),
            .note("Five cards in hand: the trade becomes compulsory. You cannot leave "
                  + "the reinforcement phase without having settled three."),
            .h("The loser's cards"),
            .p("Whoever finishes a player off takes their hand. Without that rule the "
               + "loser's cards would leave the game for good and the deck would grow "
               + "poorer with every elimination."),
            .p("Measured: the balance does not move, the game runs two or three "
               + "questions longer, and knowledge weighs slightly more."),
        ])

    // MARK: 9

    private static let file = Chapter(
        id: "file", title: "The file and the log",
        summary: "What each player has shown they know, and everything that has happened.",
        icon: "person.text.rectangle.fill", tint: Palette.mauve,
        blocks: [
            .h("The file"),
            .p("It fills itself in, question after question: for each player and each "
               + "theme, correct answers over questions faced. It is what you consult "
               + "before choosing your ground."),
            .p("One convention, and one only: a score belongs to whoever made it, and "
               + "its color says their level — green, they answer it well; red, they "
               + "stumble on it. Everywhere, in the file as in the assault panel."),
            .p("Where to strike is said differently: a scope marks the defender's weak "
               + "spot, and only if there is one — that is, under one correct answer in "
               + "two."),
            .note("In a showdown, a theme your opponent stumbles on only helps you if "
                  + "you stay on your feet there: you answer too."),
            .h("The log"),
            .p("Everything that has happened, newest first: the turns, the "
               + "reinforcements, the duels, the conquests, the card trades, the "
               + "eliminations. Turn headings are in white, the rest in grey."),
            .h("What the machine knows about you"),
            .p("When it attacks, it draws its ground at random, weighted by the "
               + "weaknesses it knows about, without ever locking on: aiming every time "
               + "at your exact weak spot would be the optimal move and the dullest of "
               + "them all."),
        ])

    // MARK: 10

    private static let memory = Chapter(
        id: "memory", title: "Resume, mark, go back",
        summary: "The game in progress, the bookmark, and the library of moments.",
        icon: "books.vertical.fill", tint: Palette.side(3),
        blocks: [
            .h("The game saves itself"),
            .p("It survives closing the app: you find it where you left it, with "
               + "nothing to do. The \"Resume game in progress\" button then appears on "
               + "the home screen. A duel left waiting goes back through \"I'm ready\" "
               + "— the clock does not run while you turn your device back on."),
            .h("The library"),
            .p("The save above keeps a single state, the last one, and overwrites it at "
               + "every move: that is what resuming needs, and exactly what going back "
               + "must not have. The library keeps one moment per turn and per side, "
               + "unasked — a decisive moment is only recognized afterwards."),
            .p("Each game reads like a shelf: the board, the mode, the date, against "
               + "whom. Its moments show the balance of power they had, in side colors "
               + "— which is what lets you find the moment it all turned without "
               + "opening them one by one."),
            .h("The bookmark"),
            .p("The bookmark in the top bar shelves the present moment by hand. It is "
               + "only an extra: the automatic save already does the work."),
            .h("Going back to a moment"),
            .p("Choosing a moment resumes the game from there — and opens a fresh "
               + "branch: the original game stays whole. Replaying an ending does not "
               + "erase the ending you wanted to keep."),
            .note("A moment saved on a board whose drawing has changed since will no "
                  + "longer read back. The app says so rather than restoring a game "
                  + "that no longer lines up."),
        ])

    // MARK: 11

    private static let network = Chapter(
        id: "network", title: "Playing across devices",
        summary: "Up to four devices, with no account and no configuration.",
        icon: "iphone.gen3.radiowaves.left.and.right", tint: Palette.side(0),
        blocks: [
            .p("One device per player, up to four. Nothing to type, no account, no "
               + "network to configure: the devices find each other over the local "
               + "network, or directly over Wi-Fi when there is no network at all — so "
               + "it works on a train."),
            .h("Opening and joining"),
            .bullets([
                "One player taps \"Play across devices\", picks the number of players, "
                + "then \"Open the table\".",
                "The others tap \"Join a table\" and pick its name from the list.",
                "Whoever opens chooses the board and the rules, and sends them with the "
                + "game: the others have nothing to set. They also give each player "
                + "their seat, in order of arrival.",
                "When everyone is there, they start the game.",
            ]),
            .p("On each device, only the player whose turn it is can act — and only the "
               + "defender can answer, wherever they are."),
            .note("No machine in a networked game: an artificial opponent would have to "
                  + "be played by every device at once."),
            .h("What you need, and nothing more"),
            .bullets([
                "The devices in the same room.",
                "Both on the same Wi-Fi network — or both with no network at all, in "
                + "which case they link up directly.",
                "The \"local network\" permission, which the system asks for once. "
                + "Refused, the devices never see each other: you can turn it back on "
                + "in Settings ▸ Riskelo US.",
                "The same version of Riskelo US on both.",
            ]),
            .h("When it does not work"),
            .terms([
                ("No table in sight", "Check that the other device really did open the "
                 + "table, that both are on the same Wi-Fi network, and that the "
                 + "devices are close by."),
                ("The link could not be established", "The connection timed out after "
                 + "fifteen seconds. Start again — and if a network permission is "
                 + "asked for, accept it right away."),
                ("Linked, but nothing comes", "The link is good: it is the launch that "
                 + "is not arriving. It is up to whoever opened the table to start the "
                 + "game."),
                ("Different versions", "One device sent a game the other cannot read. "
                 + "Update both."),
                ("Still nothing happens", "Swap the roles: let whoever was searching "
                 + "open the table. A link can go through in one direction only."),
            ]),
        ])

    // MARK: 12

    private static let bank = Chapter(
        id: "questions", title: "The questions",
        summary: "The themes that ship with the game, and the three difficulty levels.",
        icon: "text.book.closed.fill", tint: Palette.orange,
        blocks: [
            .p("\(Manual.questionCount) multiple-choice questions ship with the app. "
               + "They are inside it: no connection is needed to play."),
            .h("The themes in the game"),
            .bullets(Manual.baseThemes),
            .p("Packs add more, and are bought separately — see the \"Packs\" page on "
               + "the home screen. Whoever opens a table plays their packs for "
               + "everyone: the others do not have to own them."),
            .h("The three levels"),
            .p("Every question carries a level — easy, medium, hard — and the mix "
               + "chosen at setup decides their proportion. The draw never leaves the "
               + "theme asked for: once it runs dry it starts over rather than "
               + "wandering."),
            .p("A game asks between fifty and a hundred and sixty questions, and a "
               + "single theme can burn through twenty-five of them. Four hundred per "
               + "theme is a bank that lasts months without repeating."),
            .note("Found a typo in a question? Write to \(contact) and it will be "
                  + "fixed in the next version."),
        ])

    // MARK: 13

    private static let tips = Chapter(
        id: "tips", title: "Tips",
        summary: "What measurement showed about the good moves and the bad ones.",
        icon: "lightbulb.fill", tint: Palette.held,
        blocks: [
            .bullets([
                "One big stack beats five small ones. Pouring your reinforcements onto "
                + "a single spearhead is better than plugging the whole front.",
                "Do not take a place with your last pair of troops: the strong machine "
                + "forbids itself that move, and that one line is worth twenty points "
                + "of games won.",
                "Press the same place: the defender's clock tightens with every "
                + "question in the turn, and a place already broken into is easier to "
                + "finish than another is to open.",
                "Check the file before choosing the theme. The scope marks the weak "
                + "spot; striking there amounts to rolling one more die.",
                "A whole continent is worth its bonus every turn: it is the only income "
                + "that does not depend on how many territories you hold.",
                "With cards, waiting pays nothing — the card is drawn by taking. And "
                + "the scale climbs for everyone, so holding your hand only enriches "
                + "your opponent.",
                "In a showdown, do not double while you are ahead: chance serves "
                + "whoever is behind.",
            ]),
        ])

    // MARK: 14

    private static let legal = Chapter(
        id: "legal", title: "Privacy and contact",
        summary: "What the app does with your data — which is nothing.",
        icon: "hand.raised.fill", tint: Palette.dim,
        blocks: [
            .h("No data leaves the device"),
            .bullets([
                "No account, no sign-up, no email address asked for.",
                "No analytics, no trackers, no ads.",
                "Your games are saved on the device alone, and go with the app if you "
                + "delete it.",
                "Playing across devices goes through no server: the moves travel "
                + "directly from one device to the other over the local network, and "
                + "nothing is kept.",
                "No internet connection is needed to play.",
            ]),
            .h("The full texts"),
            .links([
                ("Privacy policy",
                 "What is saved, where, and what never leaves the device.",
                 privacyURL),
                ("Terms of use",
                 "License, ownership, warranties, governing law.",
                 termsURL),
                ("The Riskelo US site",
                 site,
                 siteURL),
            ]),
            .h("Contact"),
            .p("A question, a typo in a question, something broken: write in and you "
               + "will get an answer."),
            .links([
                ("Write to the author", contact, contactURL),
            ]),
            .h("Notices"),
            .p("Riskelo US is an independent game, inspired by traditional conquest "
               + "games. It is not affiliated with any board game publisher or any of "
               + "their trademarks."),
            .p("Riskelo US \(Manual.version) — © 2026 Robert Oulhen. All rights "
               + "reserved."),
        ])
}

#Preview("Manual") {
    ManualView(onClose: {})
}
