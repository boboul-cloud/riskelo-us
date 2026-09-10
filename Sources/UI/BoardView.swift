//
//  BoardView.swift
//  Riskelo US
//
//  The board.
//
//  Nothing here is written in points: the centers come from the engine in
//  relative units, and everything multiplies by the side available. The same
//  board therefore fits on an iPhone in portrait and on a Mac screen, without
//  a line of conditional.
//

import SwiftUI

struct BoardView: View {

    let session: GameSession
    /// Where the panel covering the bottom of the screen starts, as measured
    /// by the game screen. Absent — nothing is covering, or the measurement
    /// has not arrived yet — we fall back on the session's estimate.
    var panelTop: CGFloat?

    /// The board moves and zooms. That is what makes boards larger than the
    /// screen possible: a world map does not fit on a phone at a size where
    /// the names can be read, but it fits very well if you can walk it around
    /// under your finger.
    @State private var zoom: CGFloat = 1
    @State private var fitted = false
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    /// How far the board was lifted to make room for the panel. It comes back
    /// down by as much when the panel leaves: without that the map stayed
    /// perched at the top, an empty band beneath it, until the next reframing
    /// — and the higher the larger the panel had been.
    @State private var liftApplied: CGFloat = 0

    private var scale: CGFloat { min(4, max(0.9, zoom * pinch)) }
    private var moved: Bool { scale != 1 || offset != .zero }

    var body: some View {
        GeometryReader { geo in
            let layout = session.game.board.layout
            let side = min(geo.size.width, geo.size.height / layout.aspect)
            let radius = layout.cellRadius * side
            let covered = coveredFraction(geo.frame(in: .named(Space.screen)))
            let marker = Marker(covered: covered, stage: session.stage, target: session.target)
            ZStack {
                ForEach(session.game.map.order, id: \.self) { id in
                    tile(id, side: side, radius: radius,
                         center: layout.centers[id] ?? Point(x: 0, y: 0))
                }
                crossings(side: side, radius: radius)
                arrow(side: side, radius: radius)
            }
            .frame(width: side, height: side * layout.aspect)
            .scaleEffect(scale)
            .offset(x: offset.width + drag.width, y: offset.height + drag.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Panning and zooming live alongside taps on the cells: a finger
            // that does not move stays a tap.
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                        clamp(in: geo.size, side: side, aspect: layout.aspect,
                              covered: covered)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        zoom = min(4, max(0.9, zoom * value.magnification))
                        clamp(in: geo.size, side: side, aspect: layout.aspect,
                              covered: covered)
                    }
            )
            // There used to be a double-tap here to recenter the map. It cost
            // a lot and returned nothing: a **single** tap on a cell had to
            // wait for the double-tap window to close before being recognized
            // as single — a quarter of a second of delay on every tap in the
            // game. The recenter button, bottom right, already does the same
            // thing without delaying anything.
            .clipped()
            // A large board arrives at a size where the names cannot be read.
            // We zoom it in from the start just enough for them to appear —
            // the rest is walked around under the finger.
            .onAppear {
                guard !fitted else { return }
                fitted = true
                zoom = min(2.2, max(1, 54 / max(radius * 1.7, 1)))
            }
            // Three things call for a reframe, and all of them come through
            // here. The stage of the duel, because the sheet rising takes the
            // bottom of the screen and the fight has to stay visible above
            // it. The target being aimed at, because the assault panel covers
            // exactly the bottom of the board, where the two places may have
            // been. And the panel's height, because the one asking how many
            // troops advance is taller than the summary it replaces.
            //
            // All of them wait a beat. A panel rising changes height at every
            // frame: without that wait, the board reframed against an already
            // stale coverage, and judged "already visible" an offset that was
            // still moving — the two places ended up straddling the edge of
            // the panel.
            .task(id: marker) {
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                if covered == 0 {
                    easeBackDown(in: geo.size, side: side, aspect: layout.aspect)
                } else {
                    focusOnAssault(in: geo.size, side: side, aspect: layout.aspect,
                                   covered: covered)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if moved {
                    Button {
                        withAnimation(.snappy) { zoom = 1; offset = .zero; liftApplied = 0 }
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(9)
                            .background(Palette.panel.opacity(0.92), in: Circle())
                            .foregroundStyle(Palette.dim)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity)
                }
            }
        }
    }

    /// What calls for a reframe: the fraction covered, the stage of the duel,
    /// the target aimed at. Gathered into a single value, they trigger only
    /// one wait — and therefore one reframe — when they change together,
    /// which is the ordinary case.
    private struct Marker: Equatable {
        let covered: CGFloat
        let stage: GameSession.Stage?
        let target: TerritoryID?
    }

    /// The fraction of the board the panel eats — measured when we know it,
    /// estimated otherwise.
    ///
    /// Rounded to the hundredth: a panel breathing by one point must not set
    /// the reframing off again.
    private func coveredFraction(_ frame: CGRect) -> CGFloat {
        guard let panelTop, frame.height > 0 else { return CGFloat(session.coveredFraction) }
        let part = (frame.maxY - panelTop) / frame.height
        return min(0.9, max(0, (part * 100).rounded() / 100))
    }

    /// Brings the midpoint of the two places to the center of what remains
    /// visible.
    ///
    /// No effect if they are already there: nothing would be more irritating
    /// than a map that starts sliding on its own for no gain.
    private func focusOnAssault(in size: CGSize, side: CGFloat, aspect: Double,
                                covered: CGFloat) {
        guard let (from, to) = placesInPlay,
              let start = session.game.board.layout.centers[from],
              let end = session.game.board.layout.centers[to] else { return }
        // Nothing to do if the two places already fit in what remains
        // visible: a map sliding for no reason gets in the way more than the
        // reframing helps. A whole board on screen, with nothing over it,
        // falls into this case by itself — it is the old rule, but stated in
        // terms of what you see rather than what exists.
        let radius = CGFloat(session.game.board.layout.cellRadius) * side * scale
        if visible(start, in: size, side: side, aspect: aspect, margin: radius,
                   covered: covered),
           visible(end, in: size, side: side, aspect: aspect, margin: radius,
                   covered: covered) { return }

        let middle = CGPoint(x: (start.x + end.x) / 2 * side,
                             y: (start.y + end.y) / 2 * side)
        // The duel sheet — or the setup panel — eats the bottom: the center
        // of what you see rises by as much, and the two places have to land
        // there.
        let lift = size.height * covered / 2
        withAnimation(.easeInOut(duration: 0.45)) {
            offset = CGSize(width: -scale * (middle.x - side / 2),
                            height: -scale * (middle.y - side * CGFloat(aspect) / 2) - lift)
            clamp(in: size, side: side, aspect: aspect, covered: covered)
            liftApplied = lift
        }
    }

    /// The panel leaves: the board takes back the room it had given up.
    /// Nothing else moves — neither the zoom, nor what the player has walked
    /// around under their finger in the meantime.
    private func easeBackDown(in size: CGSize, side: CGFloat, aspect: Double) {
        guard liftApplied != 0 else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            offset.height += liftApplied
            liftApplied = 0
            clamp(in: size, side: side, aspect: aspect, covered: 0)
        }
    }

    /// The two places the view has to keep an eye on: those of the assault in
    /// progress, or, while it is not yet declared, the ones being chosen. A
    /// start with no target does not count: the map has no business sliding
    /// on the first tap, only when a panel comes to cover it.
    private var placesInPlay: (TerritoryID, TerritoryID)? {
        if let a = session.assault { return (a.from, a.to) }
        if let base = session.selected, let target = session.target { return (base, target) }
        return nil
    }

    /// Is a place somewhere it can be seen: on screen, and above the panel
    /// eating the bottom of it?
    private func visible(_ p: Point, in size: CGSize, side: CGFloat, aspect: Double,
                         margin: CGFloat, covered: CGFloat) -> Bool {
        let x = size.width / 2 + offset.width
            + scale * (CGFloat(p.x) * side - side / 2)
        let y = size.height / 2 + offset.height
            + scale * (CGFloat(p.y) * side - side * CGFloat(aspect) / 2)
        let bottom = size.height * (1 - covered)
        return x > margin && x < size.width - margin
            && y > margin && y < bottom - margin
    }

    /// Keeps the board from wandering off screen: there is always enough left
    /// to catch it by.
    private func clamp(in size: CGSize, side: CGFloat, aspect: Double,
                       covered: CGFloat) {
        let wide = side * scale, tall = side * CGFloat(aspect) * scale
        let maxX = Framing.horizontalBound(viewWidth: size.width, boardWidth: wide)
        offset.width = min(maxX, max(-maxX, offset.width))
        let bounds = Framing.verticalBounds(viewHeight: size.height,
                                            boardHeight: tall, covered: covered)
        offset.height = min(bounds.upperBound, max(bounds.lowerBound, offset.height))
    }

    /// The crossings, dotted. Without them, a player seeing two cells
    /// separated by sea has no reason to believe they can get from one to the
    /// other — and will never try.
    private func crossings(side: CGFloat, radius: CGFloat) -> some View {
        let layout = session.game.board.layout
        return ForEach(layout.seaRoutes, id: \.self) { route in
            if let a = layout.centers[route.from], let b = layout.centers[route.to] {
                let start = CGPoint(x: a.x * side, y: a.y * side)
                let end = CGPoint(x: b.x * side, y: b.y * side)
                let path = SeaLink(from: start, to: end, pullback: radius * 0.80,
                                   control: curvature(start, end,
                                                      side: side, aspect: layout.aspect,
                                                      radius: radius))
                // Two strokes on top of each other: a wide dark one beneath,
                // which lifts the route off the sea, and the light dotted one
                // over it. A single pale stroke was lost against the ground,
                // and you could not tell you were allowed through.
                ZStack {
                    path.stroke(Palette.sea.opacity(0.9),
                                style: StrokeStyle(lineWidth: max(5, radius * 0.30),
                                                   lineCap: .round))
                    path.stroke(Palette.ink.opacity(0.72),
                                style: StrokeStyle(lineWidth: max(2.5, radius * 0.15),
                                                   lineCap: .round,
                                                   dash: [radius * 0.30, radius * 0.26]))
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// A short crossing goes straight. A long one arcs, and bends away from
    /// the center of the board — which takes it over the map rather than
    /// through it.
    private func curvature(_ a: CGPoint, _ b: CGPoint,
                           side: CGFloat, aspect: Double, radius: CGFloat) -> CGPoint? {
        let dx = b.x - a.x, dy = b.y - a.y
        let d = (dx * dx + dy * dy).squareRoot()
        guard d > radius * 4 else { return nil }

        let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let center = CGPoint(x: side / 2, y: side * CGFloat(aspect) / 2)
        // Of the two perpendiculars, we take the one heading away from the
        // center.
        var nx = -dy / d, ny = dx / d
        if (middle.x - center.x) * nx + (middle.y - center.y) * ny < 0 { nx = -nx; ny = -ny }
        let bulge = d * 0.34
        return CGPoint(x: middle.x + nx * bulge, y: middle.y + ny * bulge)
    }

    /// Where the assault leaves from and where it lands. The line only shows
    /// during an assault: the rest of the time the board has nothing to tell.
    @ViewBuilder
    private func arrow(side: CGFloat, radius: CGFloat) -> some View {
        if let a = session.assault,
           let start = session.game.board.layout.centers[a.from],
           let end = session.game.board.layout.centers[a.to] {
            AttackArrow(from: CGPoint(x: start.x * side, y: start.y * side),
                        to: CGPoint(x: end.x * side, y: end.y * side),
                        // Two neighboring cells have only a radius and a half
                        // between their centers: pulling back a full radius
                        // on each side left nothing to draw. So the arrow
                        // starts inside the cell and crosses the border.
                        pullback: radius * 0.44, head: radius * 0.40)
                .stroke(Palette.side(a.attacker),
                        style: StrokeStyle(lineWidth: max(3, radius * 0.19),
                                           lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - One cell

    private func tile(_ id: TerritoryID, side: CGFloat, radius: CGFloat, center: Point) -> some View {
        let w: CGFloat = radius * 1.732 * 0.97
        let h: CGFloat = radius * 2 * 0.97
        return Hexagon()
            .fill(fill(id))
            .overlay(Hexagon().strokeBorder(border(id), lineWidth: borderWidth(id)))
            .overlay(frontier(id, radius: radius))
            .overlay(legend(id, radius: radius, scale: scale))
            .frame(width: w, height: h)
            .contentShape(Hexagon())
            .position(x: center.x * side, y: center.y * side)
            .onTapGesture { withAnimation(.snappy(duration: 0.11)) { session.tap(id) } }
            .animation(.easeInOut(duration: 0.16), value: session.game.armies(id))
    }

    /// The continent's border line, on this cell's side of it.
    private func frontier(_ id: TerritoryID, radius: CGFloat) -> some View {
        let edges = session.game.board.layout.frontierEdges[id] ?? []
        let tint = Palette.continent(rank: session.game.map.tint(of: id))
        // Half as thin as before: that is what lets the hue be bright without
        // fighting the color of the side filling the cell.
        return BorderEdges(edges: edges)
            .stroke(tint, style: StrokeStyle(lineWidth: max(1.5, radius * 0.075),
                                             lineCap: .round, lineJoin: .round))
    }

    /// The number of troops, and the name if the cell is wide enough to read
    /// it.
    private func legend(_ id: TerritoryID, radius: CGFloat, scale: CGFloat) -> some View {
        let count: Int = session.game.armies(id)
        let name: String = session.game.name(id)
        // It is the size actually seen that decides: a cell too small for its
        // name gets it back as soon as you zoom the map in.
        let wide: Bool = radius * scale * 1.7 > 52
        return VStack(spacing: 0) {
            Text("\(count)")
                .font(.system(size: max(11, radius * 0.62), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                // The number rolls instead of jumping: that is what makes it
                // visible that a troop has just fallen, while you answer.
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: count)
            if wide {
                Text(name)
                    .font(.system(size: radius * 0.27, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - What the color says

    private func fill(_ id: TerritoryID) -> some ShapeStyle {
        let g = session.game
        let base = Palette.side(g.owner[id] ?? 0)
        // Under the spotlight: the two places of an assault, then whatever is
        // playable.
        if session.assault?.to == id || session.assault?.from == id {
            return AnyShapeStyle(base.opacity(1))
        }
        if isTarget(id) || session.selected == id { return AnyShapeStyle(base.opacity(0.95)) }
        return AnyShapeStyle(base.opacity(playable(id) ? 0.72 : 0.45))
    }

    private func border(_ id: TerritoryID) -> Color {
        if session.assault?.to == id { return Palette.lost }
        if let a = session.assault, a.from == id { return Palette.side(a.attacker) }
        if session.selected == id { return .white }
        if isTarget(id) { return Palette.lost.opacity(0.9) }
        // A cell's outline no longer has to carry the continent: the border
        // lines take care of that. It only separates the cells from each
        // other, and so it keeps back.
        return Palette.sea.opacity(0.7)
    }

    private func borderWidth(_ id: TerritoryID) -> CGFloat {
        if session.assault?.to == id || session.assault?.from == id { return 3.5 }
        return session.selected == id || isTarget(id) ? 3 : 1.5
    }

    /// A cell the player can act on right now.
    private func playable(_ id: TerritoryID) -> Bool {
        let g = session.game
        guard !g.currentPlayer.isBot else { return true }
        switch g.phase {
        case .reinforcement: return g.owner[id] == g.currentPlayer.id
        case .attack: return g.canLaunch(from: id)
        case .fortify: return g.owner[id] == g.currentPlayer.id
        default: return true
        }
    }

    /// A target reachable from the cell held.
    private func isTarget(_ id: TerritoryID) -> Bool {
        guard let base = session.selected else { return false }
        let g = session.game
        switch g.phase {
        case .attack:
            return g.map.areAdjacent(base, id) && g.owner[id] != g.currentPlayer.id
        case .fortify:
            return id != base && g.owner[id] == g.currentPlayer.id
                && g.areLinked(base, id, for: g.currentPlayer.id)
        default:
            return false
        }
    }
}

// MARK: - The bounds of the pan

/// How far the board can move under the finger — or under the reframing.
///
/// This is arithmetic, and it is kept out of the view because it can be
/// checked: it, and not the reframing, was what left the two places under the
/// panel. The reframing aimed true; the bound stopped it on the way, saying
/// nothing.
enum Framing {

    /// How much board we always keep on screen, in points. A generous margin:
    /// any less and you would no longer know where to catch the map.
    static let margin: CGFloat = 90

    static func horizontalBound(viewWidth: CGFloat, boardWidth: CGFloat) -> CGFloat {
        max(0, (boardWidth - viewWidth) / 2 + margin)
    }

    /// The vertical offset allowed, stated in terms of **what you see**.
    ///
    /// It used to be "half of what overflows, plus a margin" — a rule that
    /// knows only the screen. But a panel eating three quarters of the bottom
    /// leaves only a narrow band at the top, and bringing two places from the
    /// bottom of the map into that band requires lifting the board by far
    /// more than half its overflow. The bound stood in the way: the places
    /// stayed under the panel, which is exactly what the reframing existed to
    /// avoid.
    ///
    /// So the rule is stated differently, and without mentioning the screen:
    /// the board can rise while a margin of it remains below the top, and
    /// descend while a margin remains in the free band. It is not symmetrical,
    /// and it does not have to be — it is the bottom that gets eaten.
    static func verticalBounds(viewHeight: CGFloat, boardHeight: CGFloat,
                               covered: CGFloat) -> ClosedRange<CGFloat> {
        let band = viewHeight * (1 - min(max(covered, 0), 0.95))
        // The bottom of the board stays below the top of the screen…
        let highest = margin - (viewHeight + boardHeight) / 2
        // …and its top stays within the band no panel covers.
        let lowest = band - margin - (viewHeight - boardHeight) / 2
        return min(highest, lowest) ... max(highest, lowest)
    }
}
