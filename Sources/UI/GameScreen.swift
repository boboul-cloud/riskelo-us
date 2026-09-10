//
//  GameScreen.swift
//  Riskelo US
//
//  The game screen: a bar that says where you stand, the board, and a bar
//  that says what you can do.
//
//  The composition rule is the one board games use: you never ask the player
//  to guess whose turn it is, or of what. The phase is spelled out, so is
//  what is left to do, and the playable cells are the only ones not in
//  shadow.
//

import SwiftUI

/// The game screen's coordinate space. The board and the panels that cover it
/// measure each other in it.
enum Space { static let screen = "screen" }

/// Where whatever covers the bottom of the screen begins: the duel sheet, the
/// assault panel, the move panel.
///
/// The covered share used to be estimated, in tenths of the board — "the
/// assault panel covers six tenths of the map on an iPhone". Measured on a
/// large phone, it is wrong on a small one: a sheet has a height in points,
/// not in tenths of a screen. On an iPhone SE, the one asking how many troops
/// advance covers more than eight tenths of the board. So the reframing
/// brought the two places into a band it believed free and which was not —
/// you could no longer see where you were fighting, at the very moment you
/// had to decide about it.
struct PanelTop: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        guard let next = nextValue() else { return }
        value = min(value ?? .infinity, next)
    }
}

extension View {
    /// Declares that this view covers the bottom of the screen, and says
    /// where it starts.
    func coversBottom() -> some View {
        background(GeometryReader { geo in
            Color.clear.preference(key: PanelTop.self,
                                   value: geo.frame(in: .named(Space.screen)).minY)
        })
    }
}

struct GameScreen: View {

    let session: GameSession
    var onQuit: () -> Void
    /// The manual lays itself over the game without interrupting anything:
    /// you open it in the middle of a turn to check a rule, you close it, and
    /// the turn waits.
    @State private var manualOpen = false
    /// The top of the panel covering the bottom, measured at every layout.
    /// The board uses it to know what it really has left.
    @State private var panelTop: CGFloat?

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            VStack(spacing: 0) {
                // The state of the game at the top, what you can do about it
                // at the bottom. The two used to follow each other under the
                // map, and the bottom of the screen carried four lines: who
                // is playing, the continents, the hint and the button. You
                // read the count of lands in the very place you were looking
                // for your next move.
                StandingsBar(session: session)
                BoardView(session: session, panelTop: panelTop)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .overlay { PhaseBanner(session: session) }
                BottomBar(session: session)
            }
            if session.target != nil, case .attack = session.game.phase {
                AssaultPanel(session: session).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if session.target != nil, case .fortify = session.game.phase {
                FortifyPanel(session: session).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            DuelOverlay(session: session)
            // Not as soon as the engine has decided: the last question runs
            // to its end first — its correct answer, the place falling, the
            // winner's name on the board — and the victory screen brings up
            // the rear. It used to cover all of that.
            if session.victoryShown, case let .finished(winner) = session.game.phase {
                VictoryOverlay(session: session, winner: winner, onQuit: onQuit)
                    .transition(.opacity)
            }
        }
        .coordinateSpace(name: Space.screen)
        .onPreferenceChange(PanelTop.self) { top in panelTop = top }
        // The top bar sits in the safe-area inset, and not in the stack: in
        // the stack, the duel sheet went over it. And that sheet carries the
        // "tap to continue" gesture across its whole surface — so it
        // swallowed the "quit" button for the machine's entire turn. In the
        // inset, the bar stays above everything and always answers.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopBar(session: session, onQuit: onQuit, onManual: { manualOpen = true })
        }
        // Tightened up: these are not latencies, but they were adding to the
        // double-tap delay and the game felt sluggish. The assault panel
        // follows the finger closely; only the duel sheet, which comes from
        // further away, keeps enough to be seen rising.
        .animation(.snappy(duration: 0.15), value: session.target)
        .animation(.snappy(duration: 0.22), value: session.stage)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: session.announcement)
        .animation(.easeOut(duration: 0.4), value: session.victoryShown)
        .sheet(isPresented: Binding(get: { session.journalOpen },
                                    set: { session.journalOpen = $0 })) {
            JournalSheet(session: session)
        }
        .sheet(isPresented: Binding(get: { session.fileOpen },
                                    set: { session.fileOpen = $0 })) {
            FileSheet(session: session)
        }
        .sheet(isPresented: Binding(get: { session.cardsOpen },
                                    set: { session.cardsOpen = $0 })) {
            CardsSheet(session: session)
        }
        .sheet(isPresented: Binding(get: { session.objectiveOpen },
                                    set: { session.objectiveOpen = $0 })) {
            ObjectiveSheet(session: session)
        }
        .sheet(isPresented: $manualOpen) {
            ManualView(onClose: { manualOpen = false })
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @State private var marked = false
    let session: GameSession
    var onQuit: () -> Void
    var onManual: () -> Void

    var body: some View {
        let g = session.game
        HStack(spacing: 12) {
            Button(action: onQuit) {
                Image(systemName: "chevron.left").font(.headline)
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)

            Circle().fill(Palette.side(g.currentPlayer.id)).frame(width: 12, height: 12)
            // The phase used to be spelled out here. The feed at the bottom
            // shows it now, and places it among the three steps of the turn:
            // saying the same thing twice in two places taught nothing.
            Text(session.displayName(g.currentPlayer, withMe: false))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                // A long name pushes neither the turn nor the five buttons
                // that follow: it tightens up, and gets clipped if it must.
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Turn \(g.turn)").font(.caption).foregroundStyle(Palette.dim)
                Text("\(g.territories(of: g.currentPlayer.id).count)/\(g.dominationThreshold)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Palette.ink)
            }
            // The personal conquest can be consulted at any time: you forget
            // it after three turns, and rereading it costs nobody anything
            // since it only shows your own.
            if session.objectiveShown != nil {
                Button { session.objectiveOpen = true } label: {
                    Image(systemName: "target")
                }
                .buttonStyle(.plain).foregroundStyle(Palette.dim)
            }
            if g.rules.territoryCards, session.myTurnToPlay {
                Button { session.cardsOpen = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "rectangle.stack")
                        let n = g.hand(of: g.currentPlayer.id).count
                        if n > 0 {
                            Text("\(n)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(3)
                                .background(g.mustExchange(g.currentPlayer.id)
                                            ? Palette.lost : Palette.side(g.currentPlayer.id),
                                            in: Circle())
                                .offset(x: 8, y: -7)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(g.mustExchange(g.currentPlayer.id) ? Palette.lostBright : Palette.dim)
            }
            Button {
                session.mark()
                marked = true
            } label: {
                Image(systemName: marked ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.plain).foregroundStyle(marked ? Palette.held : Palette.dim)
            .task(id: marked) {
                guard marked else { return }
                try? await Task.sleep(for: .seconds(1.6))
                marked = false
            }
            Button { session.fileOpen = true } label: {
                Image(systemName: "person.text.rectangle")
            }.buttonStyle(.plain).foregroundStyle(Palette.dim)
            Button { session.journalOpen = true } label: {
                Image(systemName: "list.bullet.rectangle")
            }.buttonStyle(.plain).foregroundStyle(Palette.dim)
            // A board game's rules are consulted during the game, not before:
            // it is when you hesitate that you go looking for them.
            Button(action: onManual) {
                Image(systemName: "questionmark.circle")
            }.buttonStyle(.plain).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.panel)
    }
}

// MARK: - Announcing a step

/// "Blue, your turn!", "Attack!" — for a beat, across the board.
///
/// It decides nothing and cannot be touched. It is there so you know you have
/// just changed step without having to read the top bar: a game is followed
/// out of the corner of your eye.
private struct PhaseBanner: View {
    let session: GameSession

    var body: some View {
        if let a = session.announcement {
            VStack(spacing: 4) {
                Text(a.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Palette.side(a.side).opacity(0.9), radius: 12)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                if let sub = a.sub {
                    Text(sub.uppercased())
                        .font(.caption.weight(.bold)).kerning(2)
                        .foregroundStyle(Palette.side(a.side))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(Palette.sea.opacity(0.72), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.side(a.side).opacity(0.7), lineWidth: 2))
            .allowsHitTesting(false)
            .id(a.id)
            // It arrives large and pulls in, it leaves by opening out: that
            // is what gives it its snap.
            .transition(.asymmetric(
                insertion: .scale(scale: 1.55).combined(with: .opacity),
                removal: .scale(scale: 1.25).combined(with: .opacity)))
        }
    }
}

// MARK: - The balance of forces

/// Who holds what. On a Risk board this reads at a glance from the colors; on
/// a phone screen the cells are too small to count. So we write it down.
private struct StandingsBar: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        VStack(spacing: 7) {
            // Each side named, and a flag on whoever has the turn. The dot
            // alone was not enough: it gave the color, not who it was, and
            // "who is playing" read as a shade of opacity.
            //
            // It used to be a grid, and it folded onto two lines as soon as
            // there were three players on a phone: two lines taken from the
            // board, which is what you came to look at. So it scrolls, like
            // the strip of continents just below.
            //
            // The objection to a scrolling strip held, and still holds: a
            // player you cannot see does not exist. It is answered not by the
            // grid but by the scrolling itself — whoever has the turn is
            // brought back under your eyes at every change of turn, and they
            // are the only one you really need to see at that instant.
            sides(g)

            // Horizontal scrolling: "British Isles" and "Central Europe" do
            // not fit side by side on a phone, and folded into their pill
            // they became unreadable.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // The pill keeps the continent's color, held or not. It
                    // used to switch entirely to its owner's color, and the
                    // strip then stopped pointing back to the map: the
                    // British Isles were ringed in yellow on the board and
                    // blue here. Yet the color is exactly what ties the two
                    // together — that is what it is for.
                    //
                    // Who holds it is therefore said differently, and in the
                    // terms of the line above: the side's dot and an outline
                    // in its color, the very ones that mark the player with
                    // the turn. The ground goes a little stronger, so a
                    // continent held can be spotted without reading.
                    ForEach(g.map.continentsInOrder) { c in
                        let owner = heldBy(c)
                        let tint = Palette.continent(rank: c.tint)
                        HStack(spacing: 3) {
                            if let owner {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Palette.brightSide(owner))
                            }
                            Text(c.name).font(.system(size: 10, weight: .medium))
                            Text("+\(c.bonus)").font(.system(size: 10, weight: .bold))
                        }
                        .fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(tint.opacity(owner != nil ? 0.30 : 0.16), in: Capsule())
                        .overlay(Capsule().strokeBorder(
                            owner.map { Palette.brightSide($0).opacity(0.9) } ?? .clear,
                            lineWidth: 1.2))
                        .foregroundStyle(tint)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    /// The sides on a single line, brought back to whoever is playing.
    ///
    /// `ScrollViewReader` rather than a fixed order: the sides keep their
    /// seat at the table — you always look for them in the same place — and
    /// it is the view that moves, not them.
    private func sides(_ g: GameState) -> some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(g.players) { p in sideChip(p).fixedSize().id(p.id) }
                }
                .padding(.vertical, 1)
                // Room to breathe at both ends: without it the last pill
                // sticks to the edge and you no longer know whether the strip
                // has finished or has merely been cut off.
                .padding(.horizontal, 2)
            }
            .onChange(of: g.currentPlayer.id) { _, who in
                withAnimation(.snappy(duration: 0.35)) {
                    reader.scrollTo(who, anchor: .center)
                }
            }
            .onAppear { reader.scrollTo(g.currentPlayer.id, anchor: .center) }
        }
    }

    private func sideChip(_ p: Player) -> some View {
        let g = session.game
        let hasTurn = p.id == g.currentPlayer.id && !g.isOver
        let lands = g.territories(of: p.id).count
        let troops = g.territories(of: p.id).reduce(0) { $0 + g.armies($1) }
        return HStack(spacing: 4) {
            Image(systemName: hasTurn ? "flag.fill" : "circle.fill")
                .font(.system(size: hasTurn ? 11 : 8))
                .foregroundStyle(Palette.brightSide(p.id))
            Text(session.displayName(p))
                .font(.caption.weight(hasTurn ? .bold : .medium))
                .foregroundStyle(Palette.ink)
                .strikethrough(p.eliminated, color: Palette.dim)
                .fixedSize()
            Image(systemName: "hexagon.fill")
                .font(.system(size: 7)).foregroundStyle(Palette.dim)
            Text("\(lands)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
            Image(systemName: "person.fill")
                .font(.system(size: 8)).foregroundStyle(Palette.dim)
            Text("\(troops)")
                .font(.caption.monospacedDigit()).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(hasTurn ? Palette.side(p.id).opacity(0.22) : Color.white.opacity(0.04),
                    in: Capsule())
        .overlay(Capsule().strokeBorder(hasTurn ? Palette.brightSide(p.id).opacity(0.9) : .clear,
                                        lineWidth: 1.3))
        .opacity(p.eliminated ? 0.4 : 1)
        .animation(.snappy(duration: 0.25), value: hasTurn)
    }

    private func heldBy(_ c: Continent) -> PlayerID? {
        let g = session.game
        guard let first = g.owner[c.territories[0]],
              c.territories.allSatisfy({ g.owner[$0] == first }) else { return nil }
        return first
    }
}

// MARK: - Bottom bar

private struct BottomBar: View {
    let session: GameSession

    /// Moving cannot be taken back: once the attack is closed, you do not
    /// return to it that turn. Yet the button sits under the thumb, in the
    /// place you press without reading — hence this question asked first.
    @State private var leavingAttack = false

    var body: some View {
        let g = session.game
        VStack(spacing: 8) {
            if session.stage == .announcing, let a = session.assault {
                announcement(a)
            } else {
                hintCapsule
            }

            HStack(spacing: 8) {
                if session.myTurnToPlay {
                    TurnFeed(session: session)
                    Spacer(minLength: 6)
                    switch g.phase {
                    case .reinforcement(let left):
                        action("Attack", "arrow.right.circle.fill",
                               enabled: left == 0
                                   && !g.mustExchange(g.currentPlayer.id)) { session.endPhase() }
                    case .attack:
                        action("Move", "figure.walk",
                               enabled: session.assault == nil) { leavingAttack = true }
                    case .fortify:
                        action("End turn", "checkmark.circle.fill") { session.endTurn() }
                    default:
                        EmptyView()
                    }
                } else if !g.isOver {
                    // No button during the other player's turn: the feed
                    // takes the whole width, and shows how far the machine
                    // has got in theirs.
                    TurnFeed(session: session).frame(maxWidth: .infinity)
                }
            }
        }
        // Tight at ten points rather than fourteen: every point gained here
        // is one more for the word naming the current step, which otherwise
        // disappears on an iPhone in favor of the numbered milestones alone.
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
        .background(Palette.panel)
        // An alert and not a confirmation dialog: on an iPhone the dialog
        // renders as a bubble hooked to the button, and shows only "Yes"
        // there — you cancelled by touching beside it, with nothing saying
        // so. An alert carries both its answers, on all three machines.
        .alert("Have you finished attacking?", isPresented: $leavingAttack) {
            // "Yes" without the destructive role: this is not a loss, only a
            // door closing. The refusal takes the cancel role, and therefore
            // the place of the gesture that slips.
            Button("Yes, on to the move") {
                // The phase may have turned while the question was up.
                if case .attack = session.game.phase { session.endPhase() }
            }
            Button("No, I'm still attacking", role: .cancel) { }
        } message: {
            Text(moveWarning)
        }
    }

    /// What you risk by moving on. The second sentence only appears if it has
    /// cause to: nothing conquered this turn, so no card at the end — and
    /// that is exactly the regret we want to spare the hurried player.
    private var moveWarning: String {
        let g = session.game
        let base = "You cannot go back to attacking once the move has started."
        guard g.rules.territoryCards, !g.conqueredThisTurn else { return base }
        return base + " And without a single conquest this turn, you draw no card."
    }

    /// The hint has the shape of the button — same capsule, same width — but
    /// not its clothes: matte ground, dimmed text, no side color. It gains
    /// the weight it was missing without promising a tap it cannot honor. The
    /// distinction matters more here than elsewhere: that same place **is**
    /// tappable while an assault is being announced, and two neighbors that
    /// look alike, only one of which answers, cost dearly.
    @ViewBuilder private var hintCapsule: some View {
        let text = hint
        let (tint, icon) = hintTone
        if !text.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    // Without this, "Five cards in hand: three have to be
                    // traded before laying any down" gets clipped on an
                    // iPhone.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(tint.opacity(0.13), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.8), lineWidth: 1.2))
        }
    }

    /// The hint's color and its sign.
    ///
    /// It used to be grey on a matte ground — restrained enough not to pass
    /// for a button, but to the point of not being seen at all. So it takes
    /// color back, without taking the button's clothes: the button is solid
    /// and its text is white and bold, the hint is a tinted veil ringed with
    /// a hairline, and its text stays ordinary ink.
    ///
    /// Three tones, because the hint says three different things: what is
    /// expected of you, what is blocking you, and that it is not your turn.
    private var hintTone: (Color, String) {
        let g = session.game
        // The bright hue, and not the board's: here it fills nothing, it
        // rings a hairline and draws a sign the size of a word.
        if !session.myTurnToPlay && !g.isOver {
            return (Palette.brightSide(g.currentPlayer.id), "ellipsis.bubble.fill")
        }
        if g.mustExchange(g.currentPlayer.id), case .reinforcement = g.phase {
            return (Palette.lostBright, "exclamationmark.triangle.fill")
        }
        return (Palette.brightSide(g.currentPlayer.id), "hand.tap.fill")
    }

    /// What the machine is about to do. Said here, under the map, and not
    /// over it: the two places concerned are often at the top of the board,
    /// and a floating banner would have hidden exactly those.
    @ViewBuilder
    private func announcement(_ a: Assault) -> some View {
        let g = session.game
        Button { session.skipAhead() } label: {
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.brightSide(a.attacker)).frame(width: 8, height: 8)
                    Text("\(session.player(a.attacker)?.name ?? "?") attacks")
                        .font(.caption).foregroundStyle(Palette.dim)
                }
                Text("\(g.name(a.from)) → \(g.name(a.to))")
                    .font(.headline).foregroundStyle(Palette.ink)
                Label("\(a.volley) question\(a.volley > 1 ? "s" : "") "
                      + "\(a.category.map { "on \($0.label)" } ?? "at random")",
                      systemImage: a.category?.symbol ?? "dice")
                    .font(.caption2)
                    .foregroundStyle(a.category.map(Palette.category) ?? Palette.dim)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    /// The button no longer takes the whole width — it makes room for the
    /// turn feed. Its **height** does not move: forty-four points, the floor
    /// for what can be touched without missing, and it is the most tapped
    /// button in the game.
    private func action(_ title: String, _ icon: String, enabled: Bool = true,
                        _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.side(session.game.currentPlayer.id))
        .disabled(!enabled)
        // The button serves itself first and does not compress: "On to the
        // mo…" was showing on an iPhone. It is the feed's job to fold when
        // the line is short, never the button's to get clipped.
        .fixedSize()
        .layoutPriority(1)
    }

    private var hint: String {
        let g = session.game
        if !session.myTurnToPlay && !g.isOver {
            return session.networked ? "\(g.currentPlayer.name) to play, on the other device…"
                                     : "\(g.currentPlayer.name) is playing…"
        }
        switch g.phase {
        case .reinforcement(let n):
            if g.mustExchange(g.currentPlayer.id) {
                return "Five cards in hand: three have to be traded before laying any down."
            }
            return n > 0 ? "Touch your territories to lay down your \(n) reinforcements."
                         : "All the reinforcements are laid down."
        case .attack:
            if let base = session.selected {
                return "From \(g.name(base)) — touch an enemy neighbor to attack."
            }
            return "Touch one of your territories with at least two troops to set out from it."
        case .occupation:
            return "Choose how many troops advance."
        case .fortify:
            if let base = session.selected {
                return "From \(g.name(base)) — touch one of your linked territories."
            }
            return "One move only, then the turn passes. Or end it right away."
        case .finished:
            return ""
        }
    }
}

// MARK: - The turn feed

/// The three beats of a turn, and where you stand.
///
/// A turn is played in three steps — lay down your reinforcements, attack,
/// move — and nothing said so. The top bar named the current phase, which
/// answers "where am I" but never "what comes next", which is the question of
/// someone discovering the game. It no longer names it: the same thing said
/// in two places taught nothing more.
///
/// Occupying a conquered place is not a fourth step — it is a moment of the
/// attack, and the milestone stays there.
///
/// The feed also serves when it is not your turn: there is no button then,
/// and it shows how far the machine has got in theirs.
private struct TurnFeed: View {
    let session: GameSession

    private enum Step: Int, CaseIterable {
        case reinforce, attack, move

        var label: String {
            switch self {
            case .reinforce: "Reinforce"
            case .attack:    "Attack"
            case .move:      "Move"
            }
        }
    }

    private var current: Step? {
        switch session.game.phase {
        case .reinforcement:       .reinforce
        case .attack, .occupation: .attack
        case .fortify:             .move
        case .finished:            nil
        }
    }

    var body: some View {
        if let current {
            // The three words if the line can carry them, otherwise the
            // current step's word alone: on an iPhone, three labels plus the
            // button do not fit side by side.
            //
            // Three fallbacks, from the most talkative to the plainest. The
            // last — three bare milestones — fits any width: `ViewThatFits`
            // keeps its last proposal even if it overflows, so that has to be
            // the one that never overflows.
            ViewThatFits(in: .horizontal) {
                feed(current, words: .all)
                feed(current, words: .currentOnly)
                feed(current, words: .none)
            }
        }
    }

    private enum Words { case all, currentOnly, none }

    private func feed(_ current: Step, words: Words) -> some View {
        let side = Palette.side(session.game.currentPlayer.id)
        // The feed is made of nothing but two-point lines and
        // eighteen-point circles: it needs the bright hue. Only the current
        // milestone stays filled with the dark color — it carries a white
        // number.
        let bright = Palette.brightSide(session.game.currentPlayer.id)
        return HStack(spacing: 5) {
            ForEach(Array(Step.allCases.enumerated()), id: \.element) { rank, step in
                if rank > 0 {
                    Capsule()
                        .fill(step.rawValue <= current.rawValue
                              ? bright.opacity(0.8) : Palette.dim.opacity(0.3))
                        .frame(width: 9, height: 2)
                }
                milestone(step, current: current, side: side, bright: bright,
                          word: words == .all || (words == .currentOnly && step == current))
            }
        }
        // Without this, the word got clipped to "…" instead of letting the
        // next fallback take over.
        .fixedSize()
    }

    private func milestone(_ step: Step, current: Step, side: Color, bright: Color,
                           word: Bool) -> some View {
        let past = step.rawValue < current.rawValue
        let here = step == current
        return HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(here ? side : Color.clear)
                    // The current step carries a bright ring over its dark
                    // ground: it lights up without its white number having to
                    // lose legibility.
                    .overlay(
                        Circle().stroke(here ? bright
                                             : (past ? bright.opacity(0.8)
                                                     : Palette.dim.opacity(0.45)),
                                        lineWidth: 1.5)
                    )
                    .frame(width: 18, height: 18)
                if past {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(bright)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(here ? Palette.ink : Palette.dim)
                }
            }
            if word {
                Text(step.label)
                    .font(.caption2.weight(here ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(here ? Palette.ink
                                          : Palette.dim.opacity(past ? 0.85 : 0.6))
            }
        }
    }
}

// MARK: - Declaring an assault

private struct AssaultPanel: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        if let base = session.selected, let target = session.target,
           let defender = g.owner[target] {
            let attacker = g.owner[base] ?? g.currentPlayer.id
            VStack(spacing: 0) {
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(g.name(base)) → \(g.name(target))")
                                .font(.headline).foregroundStyle(Palette.ink)
                            Text("\(g.armies(base)) troops against \(g.armies(target))")
                                .font(.caption).foregroundStyle(Palette.dim)
                        }
                        Spacer()
                        Button { session.cancelDraft() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3)
                        }.buttonStyle(.plain).foregroundStyle(Palette.dim)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(g.rules.mode == .classic
                             ? "You ask the question — choose the ground"
                             : "You choose the ground — but you answer on it too")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.dim)
                        Text(g.rules.mode == .classic
                             ? "The score is theirs: green, they answer it well; red, they "
                               + "stumble on it. The scope marks their weak spot."
                             : "The score is theirs: green, they answer it well; red, they "
                               + "stumble on it. Careful — a theme they stumble on only helps "
                               + "you if you stay on your feet.")
                            .font(.system(size: 10)).foregroundStyle(Palette.dim.opacity(0.8))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7),
                                                 count: 3), spacing: 7) {
                            ForEach(session.game.themesInPlay) { c in
                                categoryTile(c, against: defender)
                            }
                        }
                        atRandom
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("How many questions — your dice")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.dim)
                        Picker("", selection: Binding(get: { session.draftQuestions },
                                                      set: { session.draftQuestions = $0 })) {
                            ForEach(1...max(1, g.maxQuestions(from: base)), id: \.self) { n in
                                Text(n == 1 ? "One question" : "Two questions").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(diceLegend(g))
                            .font(.caption2).foregroundStyle(Palette.dim)
                    }

                    Button { withAnimation { session.declare() } } label: {
                        Label("Launch the assault", systemImage: "flame.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.lost)
                }
                .padding(18)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
                // The panel takes the attacker's color, as an outline only:
                // the ground stays matte, or the six theme tiles laid on it
                // would become unreadable. Enough to remind you, with two
                // players on one screen, whose finger is on the button.
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Palette.brightSide(attacker).opacity(0.7), lineWidth: 3))
                .padding(10)
                .frame(maxWidth: 560)
                .coversBottom()
            }
        }
    }

    /// What the declared volley costs. Four cases: one or two questions, in
    /// classic play or in a showdown — where the defender can still double.
    private func diceLegend(_ g: GameState) -> String {
        let one = session.draftQuestions == 1
        if g.rules.mode == .classic {
            return one
                ? "One duel: at most one troop lost on each side."
                : "Two duels in a row. The clock tightens on the second — but two correct "
                    + "answers cost you two troops."
        }
        return one
            ? "One duel, the same question for both of you. If they double the stake, it "
                + "will be worth two troops."
            : "Two duels in a row, the same question each time for both of you. The clock "
                + "tightens on the second, and they can double the stake on each."
    }

    /// The seventh ground: the one you do not choose.
    ///
    /// It takes the whole line under the six theme tiles, and not a cell
    /// among them: this is not one more theme, it is the refusal to choose
    /// one. No color either — the six each have one, this one has none, and
    /// that is what it announces.
    ///
    /// It serves two players. The one who finds it tedious to weigh six
    /// scores at every assault, and the one playing a showdown, where
    /// choosing the ground amounts to choosing it for yourself as well.
    private var atRandom: some View {
        let chosen = session.draftCategory == nil
        return Button { session.chooseCategory(nil) } label: {
            HStack(spacing: 7) {
                Image(systemName: "dice").font(.system(size: 14))
                Text("At random").font(.caption2.weight(.semibold))
                Spacer(minLength: 4)
                Text("all categories mixed")
                    .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(Palette.dim)
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 10).padding(.vertical, 8)
            .background(chosen ? Color.white.opacity(0.14) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(chosen ? Palette.ink.opacity(0.75) : .clear, lineWidth: 1.5))
            .foregroundStyle(chosen ? Palette.ink : Palette.ink.opacity(0.8))
        }
        .buttonStyle(.plain)
        // Without this, the line reads as two pieces — "At random", then "all
        // categories mixed" — and it is the first piece, not the button, that
        // takes the tap: nothing happens.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }

    /// Each theme tile carries what the opponent has shown on it: that is the
    /// attacker's whole skill in this variant.
    ///
    /// The color says the level **of whoever owns the score**, here as in
    /// their file: green, they answer it well; red, they stumble on it. It
    /// used to say the attacker's interest — so green on "2/2" because that
    /// ground was to be avoided — and the same number looked green on one
    /// side and red on the other. You thought the app was confused about what
    /// is right and what is not.
    ///
    /// Where to strike is said differently: the scope marks the weak spot.
    private func categoryTile(_ c: Category, against defender: PlayerID) -> some View {
        let score = session.game.record(of: defender, in: c)
        let chosen = session.draftCategory == c
        let weakSpot = session.game.weakness(of: defender) == c
        return Button { session.chooseCategory(c) } label: {
            VStack(spacing: 3) {
                Image(systemName: c.symbol).font(.system(size: 15))
                Text(c.label).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    if weakSpot {
                        Image(systemName: "scope").font(.system(size: 9))
                            .foregroundStyle(Palette.lostBright)
                    }
                    Text(score.asked == 0 ? "—" : "\(score.correct)/\(score.asked)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(score.asked == 0 ? Palette.dim
                                         : (score.rate < 0.5 ? Palette.lostBright : Palette.held))
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(chosen ? Palette.category(c).opacity(0.32) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(chosen ? Palette.category(c) : .clear, lineWidth: 1.5))
            .foregroundStyle(chosen ? Palette.category(c) : Palette.ink.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Moving

private struct FortifyPanel: View {
    let session: GameSession
    @State private var count = 1

    var body: some View {
        let g = session.game
        if let base = session.selected, let target = session.target {
            let maximum = max(1, g.armies(base) - 1)
            VStack {
                Spacer()
                VStack(spacing: 14) {
                    Text("\(g.name(base)) → \(g.name(target))")
                        .font(.headline).foregroundStyle(Palette.ink)
                    Stepper(value: $count, in: 1...maximum) {
                        Text("\(count) troop\(count > 1 ? "s" : "") of \(maximum)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.ink)
                    }
                    HStack(spacing: 10) {
                        Button("Cancel") { session.cancelDraft() }
                            .buttonStyle(.bordered)
                        Button { session.fortify(count) } label: {
                            Text("Move and end the turn").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.side(g.currentPlayer.id))
                    }
                }
                .padding(18)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
                .padding(10)
                .frame(maxWidth: 460)
                .coversBottom()
            }
            .onAppear { count = 1 }
        }
    }
}

// MARK: - Victory

private struct VictoryOverlay: View {
    let session: GameSession
    let winner: PlayerID
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Palette.sea.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 54)).foregroundStyle(Palette.side(winner))
                Text("\(session.player(winner)?.name ?? "?") wins")
                    .font(.title2.weight(.bold)).foregroundStyle(Palette.ink)
                Text("\(session.game.territories(of: winner).count) territories out of \(session.game.map.order.count), in \(session.game.turn) turns.")
                    .font(.subheadline).foregroundStyle(Palette.dim)
                // Through which gate. Without this line, whoever wins on the
                // threshold reads their conquest just below, unmet, and
                // concludes that the rule did not count — which is false, but
                // nothing on screen set them right.
                Text(session.game.victoryGateText(winner))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                // The cards turn over at the end, as in Risk: that is when
                // you understand what the other player was after, and why
                // they kept going at that one continent.
                if session.game.rules.objectives {
                    VStack(spacing: 8) {
                        Text("What each player was after")
                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.dim)
                        ForEach(session.game.players) { player in
                            if let card = session.game.objective(of: player.id) {
                                let met = session.game.objectiveAchieved(player.id)
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(Palette.brightSide(player.id))
                                        .frame(width: 8, height: 8).padding(.top, 5)
                                    Text("**\(player.name)** — \(session.game.text(card))"
                                         + (met ? " *Met.*" : ""))
                                        .font(.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    // Where each of them stood: the count was
                                    // missing, and it is what says whether the
                                    // card was a race or a dead letter.
                                    Text(session.game.progress(card, for: player.id))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(Palette.dim)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: 150, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .foregroundStyle(Palette.ink.opacity(0.9))
                    .padding(14)
                    .frame(maxWidth: 420)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 18)
                }
                Button(action: onQuit) {
                    Text("New game").font(.headline)
                        .frame(maxWidth: 260).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent).tint(Palette.side(winner))
            }
        }
    }
}

// MARK: - Log and file

private struct JournalSheet: View {
    let session: GameSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(session.game.journal.reversed()) { e in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(e.player.map { Palette.side($0) } ?? Palette.dim)
                            .frame(width: 7, height: 7).padding(.top, 6)
                        Text(e.text).font(.footnote)
                            .foregroundStyle(e.kind == .turn ? Palette.ink : Palette.dim)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }
}

/// The personal conquest, that of whoever is holding the device.
///
/// It never shows anyone else's — that is the whole rule. On a shared device
/// it shows the conquest of whoever is playing: with two people around a
/// table you do not look at your neighbor's card, and the app does no better
/// than a piece of cardboard laid face down.
private struct ObjectiveSheet: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        ScrollView {
            if let (player, card) = session.objectiveShown {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Circle().fill(Palette.brightSide(player)).frame(width: 10, height: 10)
                        Text("\(g.playerName(player))'s conquest")
                            .font(.headline).foregroundStyle(Palette.ink)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "target")
                            .font(.system(size: 30)).foregroundStyle(Palette.brightSide(player))
                        Text(g.text(card))
                            .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(g.progress(card, for: player))
                            .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Palette.brightSide(player).opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Palette.brightSide(player).opacity(0.6), lineWidth: 1.5))

                    // The sheet carries the rule in full, including what
                    // happens to a dead card: it is the only place the player
                    // can learn it before it lands on them.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Filling it wins the game, on the spot. There is no other "
                             + "gate: no number of territories wins the game.")
                        if case .eliminate = card {
                            Text("If somebody else brings that side down before you, your card "
                                 + "turns over and becomes \"hold "
                                 + "\(Objective.fallback(g.board).countRequired ?? 0) territories\" — "
                                 + "four places out of five on the board.")
                        } else if g.conquestTurnedOver(of: player) {
                            Text("This is not the card you drew: the side you were asked to "
                                 + "bring down fell to somebody else's blows. It turned over "
                                 + "into this fallback, so you can still win.")
                        }
                        Text(session.networked
                             ? "The other devices show only their own."
                             : "On a shared device, this screen shows the conquest of whoever is playing.")
                    }
                    .font(.caption).foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)

                    Button { session.objectiveOpen = false } label: {
                        Text("Close").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.bordered).tint(Palette.dim)
                }
                .padding(18)
            }
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }
}

/// The hand of cards, and the trade.
///
/// Three matching cards — three identical symbols or three different ones,
/// the wild card standing in for any of them — are worth troops. The scale
/// climbs with every exchange in the game: holding your cards does not make
/// them gain value, it only lets the value climb for your opponent.
private struct CardsSheet: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        let hand = g.hand(of: g.currentPlayer.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your cards").font(.headline).foregroundStyle(Palette.ink)
                    Text(hand.isEmpty
                         ? "A card is earned by taking at least one place during the turn."
                         : "Three identical symbols, or three different ones. "
                           + "The next trade is worth \(g.nextExchangeValue) troops.")
                        .font(.caption).foregroundStyle(Palette.dim)
                    if g.mustExchange(g.currentPlayer.id) {
                        Text("Five cards in hand: the trade is compulsory.")
                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.lostBright)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(hand) { card in cardTile(card) }
                }

                Button { session.exchange(); session.cardsOpen = false } label: {
                    Label("Trade for \(g.nextExchangeValue) troops", systemImage: "arrow.2.squarepath")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent).tint(Palette.held)
                .disabled(!session.setReady)
            }
            .padding(18)
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }

    private func cardTile(_ card: Card) -> some View {
        let held = session.chosenCards.contains(card.id)
        let name = card.territory.map { session.game.name($0) } ?? "Wild"
        return Button { session.toggleCard(card.id) } label: {
            VStack(spacing: 6) {
                Image(systemName: card.isWild ? "star.fill" : card.symbol.icon)
                    .font(.system(size: 20))
                Text(name).font(.caption2).lineLimit(2)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.7)
                Text(card.isWild ? "any symbol" : card.symbol.label)
                    .font(.system(size: 9)).foregroundStyle(Palette.dim)
            }
            .frame(maxWidth: .infinity).frame(height: 92)
            .background(held ? Palette.held.opacity(0.25) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(held ? Palette.held : .clear, lineWidth: 2))
            .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
    }
}

/// What each player has shown they know. The table fills itself in, question
/// after question — and it is what you consult before choosing your ground.
private struct FileSheet: View {
    let session: GameSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("What each player has shown they know")
                    .font(.headline).foregroundStyle(Palette.ink)
                ForEach(session.game.players) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Circle().fill(Palette.side(p.id)).frame(width: 9, height: 9)
                            Text(session.displayName(p)).font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            if p.eliminated {
                                Text("eliminated").font(.caption).foregroundStyle(Palette.dim)
                            }
                        }
                        ForEach(session.game.themesInPlay) { c in
                            let s = session.game.record(of: p.id, in: c)
                            HStack {
                                Label(c.label, systemImage: c.symbol)
                                    .font(.caption).foregroundStyle(Palette.dim)
                                Spacer()
                                Text(s.asked == 0 ? "—" : "\(s.correct)/\(s.asked)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(s.asked == 0 ? Palette.dim
                                                     : (s.rate < 0.5 ? Palette.lostBright : Palette.held))
                            }
                        }
                    }
                    .padding(12)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(18)
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }
}
