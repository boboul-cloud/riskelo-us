//
//  HomeView.swift
//  Riskelo US
//
//  The front door.
//
//  The app used to open on its settings: a page of sliders and switches
//  before you had seen a single cell. That is asking someone to choose a
//  board, a mix of questions and the machine's knowledge before they know
//  what a question is in this game. The home screen reverses the order — a
//  game ready to play, and the settings for whoever wants them.
//

import SwiftUI

// MARK: - The game you launch without setting anything

/// These are exactly the values the settings screen opens with: "Quick game"
/// does not offer a different game, it skips the screen. Both take them from
/// here, so they cannot drift apart.
enum QuickGame {
    static let board: Boards = .ring
    static let sides = 2
    static let humans = 1
    static let level = 0.65
    static let style: Bot.Style = .medium
    /// Zero removes the rule; otherwise one correct answer in so many is
    /// worth a troop.
    static let scholarship = 5
    static let mix: Rules.Mix = .mixed
    static let cards = false
    static let totalWar = false
    static let objectives = false
    static let mode: Rules.Mode = .classic
    /// The themes in play: what the packs page kept, and not a factory value.
    /// That is what was missing — "Quick game", resuming and the networked
    /// table all started here, and so all ignored what had been ticked
    /// elsewhere.
    static var themes: Set<String> { Packs.inPlay }

    /// What is being played right now, in one line: without it, "Packs" does
    /// not say whether you have one, nor which is running.
    static var packsInOneLine: String {
        let inPlay = Themes.all.filter { Packs.inPlay.contains($0.id) }
        let packs = inPlay.filter { $0.product != nil }
        let base = inPlay.contains { $0.product == nil }
        if packs.isEmpty {
            return "General knowledge only"
        }
        let names = packs.map(\.label).joined(separator: " · ")
        return base ? "General knowledge · " + names : names
    }

    /// The rules, assembled from what the settings screen offers. Called with
    /// nothing, it gives the default game.
    static func rules(scholarship: Int = QuickGame.scholarship,
                      mix: Rules.Mix = QuickGame.mix,
                      cards: Bool = QuickGame.cards,
                      mode: Rules.Mode = QuickGame.mode,
                      totalWar: Bool = QuickGame.totalWar,
                      objectives: Bool = QuickGame.objectives,
                      themes: Set<String> = QuickGame.themes) -> Rules {
        var r = Rules()
        r.answersPerBonusMan = scholarship == 0 ? nil : scholarship
        r.difficultyWeights = mix.weights
        r.territoryCards = cards
        r.mode = mode
        r.objectives = objectives
        r.themes = themes.isEmpty ? nil : themes
        if totalWar { r.dominationOverride = 0 }
        return r
    }

    static func players(count: Int = QuickGame.sides,
                        humans: Int = QuickGame.humans,
                        level: Double = QuickGame.level,
                        style: Bot.Style = QuickGame.style) -> [Player] {
        (0..<count).map { i in
            Player(id: i, name: Boards.sideName(i),
                   kind: i < humans ? .human : .machine(level: level, style: style))
        }
    }

    /// The word that says what the machine is worth. The same scale serves
    /// the home screen, which announces the quick game, and the settings,
    /// which vary it.
    static func levelNamed(_ n: Double) -> String {
        switch n {
        case ..<0.45: "Distracted"
        case ..<0.60: "Fair"
        case ..<0.75: "Well-read"
        default:      "Formidable"
        }
    }

    /// What you get by tapping, said in one sentence. Written from the values
    /// above: it therefore cannot promise anything other than what launches.
    static var inOneLine: String {
        "\(sides) sides on \(board.label), against a "
            + levelNamed(level).lowercased() + " machine."
    }
}

// MARK: - The icon, in motion

/// Half a hexagon, cut along the axis joining the two points. It is the only
/// cut that leaves the two sides identical — the icon's cut.
struct HalfHexagon: Shape {
    let left: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: left ? r.minX : r.maxX, y: r.minY + r.height * 0.25))
        p.addLine(to: CGPoint(x: left ? r.minX : r.maxX, y: r.minY + r.height * 0.75))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The app icon, redrawn in views rather than as an image: that is what
/// allows it to open in two. An image would have had to be cut into two
/// files, and the two halves would have stopped following the palette.
///
/// The two halves are sides 3 and 2 of the board, green and red — the same
/// pair `outils/icone.swift` draws. Not sides 1 and 2: the French app is the
/// blue one, and a player who taps a green icon must not land on a blue
/// hexagon. This view *is* the icon, so it follows it.
struct RiskeloLogo: View {
    /// From 0 — the two sides wide apart — to 1, joined.
    var join: Double = 1
    var size: CGFloat = 132

    /// A pointy-top hexagon is taller than it is wide, in this ratio.
    private var width: CGFloat { size * 0.866 }

    /// The "?" only arrives once the cell has closed: it is what settles
    /// things between the two sides, and it would have nothing to settle
    /// before then.
    private var reveal: Double { max(0, min(1, (join - 0.62) / 0.38)) }

    var body: some View {
        let gap = (1 - join) * size * 0.8
        ZStack {
            HalfHexagon(left: true).fill(Palette.side(2))
                .frame(width: width, height: size)
                .offset(x: -gap)
            HalfHexagon(left: false).fill(Palette.side(1))
                .frame(width: width, height: size)
                .offset(x: gap)
            // The outline: what makes the hexagon a game piece and not a
            // blot. It only closes along with it.
            Hexagon()
                .strokeBorder(Palette.ink.opacity(0.34), lineWidth: max(1.5, size * 0.014))
                .frame(width: width, height: size)
                .opacity(reveal)
            Text("?")
                .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .opacity(reveal)
                .scaleEffect(0.75 + 0.25 * reveal)
        }
        .frame(width: width, height: size)
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - The home screen

struct HomeView: View {

    /// The default game, without going through the settings.
    var onQuickGame: () -> Void
    /// The multi-device table, also without going through the settings: it is
    /// a way of playing, not a game setting.
    var onNetwork: () -> Void
    var onSettings: () -> Void
    /// The packs page. It is not under "Settings": a pack is not a game
    /// setting, it is something you own that holds for every game.
    var onPacks: () -> Void = { }
    /// Offered only if there is a game waiting: a button that leads nowhere
    /// is better absent.
    var onResume: (() -> Void)?
    var onManual: () -> Void
    /// Offered only if there is something on the shelves.
    var onArchives: (() -> Void)?
    /// The opening plays once per launch. Seeing it again on every return
    /// from a game would be a toll.
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var join: Double = 0
    @State private var text: Double = 0

    /// While the opening is not playing, everything is already in place: that
    /// is what avoids the picture where the screen appears empty before
    /// filling up.
    private var opens: Bool { animated && !reduceMotion }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 24)
                        RiskeloLogo(join: opens ? join : 1)
                        title
                            .padding(.top, 22)
                            .opacity(opens ? text : 1)
                        Spacer(minLength: 32)
                        buttons
                            .opacity(opens ? text : 1)
                        Spacer(minLength: 24)
                        // The legal text belongs where you wonder what you are
                        // signing up for: before starting, and therefore here.
                        legalFooter
                            .opacity(opens ? text : 1)
                            .padding(.bottom, 26)
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
        .onAppear {
            guard opens else { return }
            // The two sides come together, then the rest of the screen
            // arrives. The spring overshoots a little and comes back: the two
            // halves close like a piece being set down, not like a door being
            // pulled shut.
            //
            // Half a second of wait, and not a tenth: on a Mac the view
            // appears well before its window is on screen, and the opening
            // played into the void — you opened the app onto an icon that had
            // already closed.
            withAnimation(.spring(response: 0.72, dampingFraction: 0.68).delay(0.45)) {
                join = 1
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.9)) { text = 1 }
        }
        // The sound leaves at the same instant as the motion, and falls quiet
        // with it: its two voices meet on the chord that lands as the two
        // halves touch. Put in `task` and not in `onAppear` so that leaving
        // the home screen during the wait cancels it.
        .task {
            guard animated else { return }
            try? await Task.sleep(for: .seconds(opens ? 0.45 : 0.15))
            Sounds.shared.play(.opening)
        }
        .preferredColorScheme(.dark)
    }

    private var title: some View {
        VStack(spacing: 7) {
            Text("Riskelo US")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("The die is replaced by a question.")
                .font(.subheadline).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var buttons: some View {
        VStack(spacing: 12) {
            // First, because you come here on purpose: when two people are
            // there with their devices, it is the only thing they are trying
            // to do. It used to be under "Game settings", where you do not go
            // in order to play together.
            Button(action: onNetwork) {
                Label("Play across devices",
                      systemImage: "iphone.gen3.radiowaves.left.and.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent).tint(Palette.side(4))

            if let onResume {
                Button(action: onResume) {
                    Label("Resume game in progress", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent).tint(Palette.held)
            }

            VStack(spacing: 6) {
                Button(action: onQuickGame) {
                    Label("Quick game", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Palette.side(0))
                // Say what you are launching before launching it: without
                // this line, "quick" means nothing in particular.
                Text(QuickGame.inOneLine)
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSettings) {
                Label("Game settings", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.bordered).tint(Palette.pink)

            // Below the settings, because you do not go there for every game
            // — but on the home screen, because you go there on purpose, and
            // a pack you bought has to be found without hunting.
            VStack(spacing: 6) {
                Button(action: onPacks) {
                    Label("Question packs", systemImage: "square.stack.3d.up.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.bordered).tint(Palette.side(3))
                Text(QuickGame.packsInOneLine)
                    .font(.caption2).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }

            // Two service doors, set back: they are not for playing, but
            // burying them under "Settings" would have misrepresented what is
            // there.
            HStack(spacing: 10) {
                smallButton("How to play", "book", onManual)
                if let onArchives {
                    separator
                    smallButton("Saved games", "books.vertical", onArchives)
                }
            }
            .padding(.top, 4)
        }
    }

    private func smallButton(_ title: String, _ icon: String,
                             _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.dim)
        }
        .buttonStyle(.plain)
    }

    /// Privacy, terms, website: the three public addresses. They leave the app
    /// — the system opens the browser — and so they are in grey, like
    /// everything that is not a move to play.
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
}

#Preview("Home") {
    HomeView(onQuickGame: {}, onNetwork: {}, onSettings: {}, onResume: {},
             onManual: {}, onArchives: {}, animated: true)
}
