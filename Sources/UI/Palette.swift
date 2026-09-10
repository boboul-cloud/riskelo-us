//
//  Palette.swift
//  Riskelo US
//
//  The colors, and nothing else.
//
//  They are written here rather than in an asset catalogue for a reason of
//  reading: on a board, what matters is the gap between two sides, and a gap
//  is tuned by looking at the values side by side. They hold on the screen as
//  on paper — the game's ground is dark either way, this is a night table,
//  not a document.
//

import SwiftUI

enum Palette {

    /// The sides. Chosen to stay distinct once washed out by the shading of
    /// an unselected territory, and not to pair off for an eye that has
    /// trouble telling red from green.
    static let sides: [Color] = [
        Color(red: 0.24, green: 0.51, blue: 0.78),   // slate blue
        Color(red: 0.80, green: 0.31, blue: 0.24),   // brick red
        Color(red: 0.36, green: 0.60, blue: 0.36),   // olive green
        Color(red: 0.87, green: 0.66, blue: 0.20),   // amber
        Color(red: 0.55, green: 0.40, blue: 0.72),   // purple
    ]

    static func side(_ player: PlayerID) -> Color {
        sides[((player % sides.count) + sides.count) % sides.count]
    }

    /// The same sides, but light enough to read at small sizes.
    ///
    /// The colors above are made to **fill** a hexagon: dark, so that the
    /// white number laid on top stands out. Reduced to a hairline, to an
    /// eight-point dot or a nine-point check, on the matte ground of the
    /// panel, the same value disappears — brick red at 50% opacity gives 1.7
    /// of contrast out of 21, which is to say nothing. Blue and purple are
    /// hardly better.
    ///
    /// Hence this second set, a notch and a half lighter: you recognize the
    /// side, but you can see it. It is reserved for what is thin or small — a
    /// line, a dot, a check. A solid surface keeps the dark color, or the
    /// white text it carries would be lost in turn.
    static let brightSides: [Color] = [
        Color(red: 0.45, green: 0.70, blue: 0.98),   // slate blue, lightened
        Color(red: 0.98, green: 0.48, blue: 0.41),   // brick red, lightened
        Color(red: 0.54, green: 0.82, blue: 0.54),   // olive green, lightened
        Color(red: 1.00, green: 0.79, blue: 0.34),   // amber, lightened
        Color(red: 0.74, green: 0.60, blue: 0.94),   // purple, lightened
    ]

    static func brightSide(_ player: PlayerID) -> Color {
        brightSides[((player % brightSides.count) + brightSides.count) % brightSides.count]
    }

    /// The continents. Taken from the continent's rank and not from the
    /// letter in its plan — a board may have six or eight, and they all have
    /// to be told apart.
    ///
    /// They used to be muted so as not to fight the color of the side holding
    /// the cell; the line was wide and the hue dimmed, and the continents
    /// were no longer visible. The bargain was reversed: **bright hues, a
    /// line half as wide**. A bright hairline reads as a border, a bright
    /// band would have fought the fill.
    ///
    /// All of them are light, where the sides are dark: it is that gap in
    /// value, and not the hue, that keeps a continent outline from being
    /// mistaken for a player's color.
    static let continents: [Color] = [
        Color(red: 0.42, green: 0.78, blue: 1.00),   // sky
        Color(red: 1.00, green: 0.84, blue: 0.30),   // gold
        Color(red: 0.42, green: 0.92, blue: 0.55),   // bright green
        Color(red: 1.00, green: 0.55, blue: 0.42),   // coral
        Color(red: 0.76, green: 0.58, blue: 1.00),   // light purple
        Color(red: 0.30, green: 0.90, blue: 0.85),   // turquoise
        Color(red: 1.00, green: 0.52, blue: 0.75),   // bright pink
        Color(red: 0.85, green: 0.92, blue: 0.35),   // lemon
    ]

    static func continent(rank: Int) -> Color {
        continents[((rank % continents.count) + continents.count) % continents.count]
    }

    /// The pie slices. The hue is declared by the theme, in its question
    /// file: it is the only way an added theme does not come out grey.
    static func category(_ c: Category) -> Color {
        let t = c.tint
        return Color(red: t.r, green: t.g, blue: t.b)
    }

    /// The hues of the manual's chapters.
    ///
    /// They used to be borrowed from the question themes — "the color of
    /// geography" for the rules chapter. A theme changing color has nothing
    /// to do with the manual, and since themes declare themselves in their
    /// files, a theme removed left a chapter grey. These are now six house
    /// colors, and nothing else.
    static let blue   = Color(red: 0.26, green: 0.55, blue: 0.80)
    static let green  = Color(red: 0.34, green: 0.65, blue: 0.42)
    static let wood   = Color(red: 0.62, green: 0.45, blue: 0.34)
    static let gold   = Color(red: 0.85, green: 0.66, blue: 0.22)
    static let mauve  = Color(red: 0.75, green: 0.40, blue: 0.62)
    static let orange = Color(red: 0.88, green: 0.52, blue: 0.24)

    static let sea = Color(red: 0.09, green: 0.12, blue: 0.16)
    static let ink = Color(red: 0.93, green: 0.94, blue: 0.95)
    static let dim = Color(red: 0.58, green: 0.62, blue: 0.68)
    static let panel = Color(red: 0.14, green: 0.17, blue: 0.21)
    static let held = Color(red: 0.36, green: 0.72, blue: 0.45)
    static let lost = Color(red: 0.86, green: 0.35, blue: 0.30)
    /// The red of an alert, for the same small uses as `brightSides`: a line
    /// or a mark on the panel, never a solid surface.
    static let lostBright = Color(red: 0.99, green: 0.53, blue: 0.47)
    /// The pink of the home screen. It designates neither a side nor a state
    /// of the board: it is the color of a door — the settings door — and so
    /// it keeps clear of the five colors that mean "whose cell is this".
    /// Light enough to read as lettering on the night ground.
    static let pink = Color(red: 1.00, green: 0.52, blue: 0.75)
}

/// A crossing, straight or as an arc.
///
/// The arc is not an affectation: Alaska and Kamchatka are at opposite ends
/// of the map, and the straight line joining them ran through Greenland,
/// Iceland and the whole of Siberia. There was no telling what it joined. A
/// route going round the top of the world reads at a glance.
struct SeaLink: Shape {
    var from: CGPoint
    var to: CGPoint
    var pullback: CGFloat
    /// The point that bends the curve. Absent, the route is straight.
    var control: CGPoint?

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let control else {
            let dx = to.x - from.x, dy = to.y - from.y
            let d = max(0.001, (dx * dx + dy * dy).squareRoot())
            p.move(to: CGPoint(x: from.x + dx / d * pullback, y: from.y + dy / d * pullback))
            p.addLine(to: CGPoint(x: to.x - dx / d * pullback, y: to.y - dy / d * pullback))
            return p
        }
        // The ends pull back toward the control point, which is the curve's
        // tangent: the route leaves the cell in the right direction.
        func towardControl(_ p0: CGPoint) -> CGPoint {
            let dx = control.x - p0.x, dy = control.y - p0.y
            let d = max(0.001, (dx * dx + dy * dy).squareRoot())
            return CGPoint(x: p0.x + dx / d * pullback, y: p0.y + dy / d * pullback)
        }
        p.move(to: towardControl(from))
        p.addQuadCurve(to: towardControl(to), control: control)
        return p
    }
}

/// The arrow of an assault, from one cell to another.
///
/// It pulls back at both ends so as not to bite into the two hexagons: what
/// you want to see is the path between the two places, not a line laid over
/// the numbers.
struct AttackArrow: Shape {
    var from: CGPoint
    var to: CGPoint
    var pullback: CGFloat
    var head: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let dx = to.x - from.x, dy = to.y - from.y
        let d = max(0.001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / d, uy = dy / d
        let start = CGPoint(x: from.x + ux * pullback, y: from.y + uy * pullback)
        let end = CGPoint(x: to.x - ux * pullback, y: to.y - uy * pullback)
        p.move(to: start)
        p.addLine(to: end)
        // The point, two oblique strokes rather than a solid triangle: it
        // reads just as well and does not block the cell being aimed at.
        let wings: CGFloat = 0.55
        p.move(to: CGPoint(x: end.x - ux * head - uy * head * wings,
                           y: end.y - uy * head + ux * head * wings))
        p.addLine(to: end)
        p.addLine(to: CGPoint(x: end.x - ux * head + uy * head * wings,
                              y: end.y - uy * head - ux * head * wings))
        return p
    }
}

/// The edges of a cell that make a border, drawn on their own.
///
/// They are pulled in toward the center rather than laid on the edge: two
/// neighboring continents each draw their own, and superimposed they would
/// fight over the same line. Pulled in, they make a double line — the atlas
/// kind, which shows plainly that there are two lands and not one seam.
struct BorderEdges: Shape {
    let edges: Set<Int>
    var inset: CGFloat = 0.10

    func path(in rect: CGRect) -> Path {
        guard !edges.isEmpty else { return Path() }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2 * (1 - inset)
        let ry = rect.height / 2 * (1 - inset)
        func vertex(_ i: Int) -> CGPoint {
            let a = Double(i % 6) * .pi / 3 - .pi / 2
            return CGPoint(x: c.x + rx * cos(a) * 2 / 3.0.squareRoot(),
                           y: c.y + ry * sin(a))
        }
        var p = Path()
        for k in edges {
            p.move(to: vertex(k))
            p.addLine(to: vertex(k + 1))
        }
        return p
    }
}

/// The pointy-top hexagon, drawn inside its rectangle.
///
/// It knows how to shrink — `InsettableShape` — so that the outline's stroke
/// stays inside the cell instead of biting into its neighbor.
struct Hexagon: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> Hexagon {
        Hexagon(inset: inset + amount)
    }

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: inset, dy: inset)
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX + w / 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.75))
        p.addLine(to: CGPoint(x: rect.minX + w / 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.75))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.25))
        p.closeSubpath()
        return p
    }
}
