//
//  Map.swift
//  Riskelo US
//
//  The territory, the continent, and what touches what.
//
//  Two things are kept apart here, and they must stay apart: the map in the
//  sense of the rules — who neighbors whom, which continent is worth what —
//  and the drawing of the board. The first decides which moves are legal;
//  the second is only a way of showing it. The test board is a checkerboard
//  of hexagons; the day a real world map replaces it, only the second half
//  will change.
//

import Foundation

typealias TerritoryID = String
typealias ContinentID = String
typealias PlayerID = Int

/// A point on the board, in normalized 0…1 coordinates. Neither CGPoint nor
/// SwiftUI: the engine has to run on its own, outside any application.
struct Point: Hashable, Codable {
    var x: Double
    var y: Double
}

struct Territory: Identifiable, Hashable {
    let id: TerritoryID
    let name: String
    let continent: ContinentID
    /// The territories that can be attacked from this one, and vice versa.
    var neighbors: [TerritoryID]
}

struct Continent: Identifiable, Hashable {
    let id: ContinentID
    let name: String
    /// Extra reinforcement per turn, for whoever holds it whole.
    let bonus: Int
    let territories: [TerritoryID]
    /// Its rank on the board, which is where the view takes its tint from.
    /// The color used to hang off the letter in the plan — five known
    /// letters, and every continent on a new board came out the same color.
    let tint: Int
}

/// The map in the sense of the rules.
struct GameMap {
    private(set) var territories: [TerritoryID: Territory]
    private(set) var continents: [ContinentID: Continent]
    /// A stable traversal order: a dictionary has none, and a replayed game
    /// must deal out territories in the same order.
    private(set) var order: [TerritoryID]

    init(territories: [Territory], continents: [Continent]) {
        self.territories = Dictionary(uniqueKeysWithValues: territories.map { ($0.id, $0) })
        self.continents = Dictionary(uniqueKeysWithValues: continents.map { ($0.id, $0) })
        self.order = territories.map(\.id)
    }

    subscript(id: TerritoryID) -> Territory? { territories[id] }

    func neighbors(of id: TerritoryID) -> [TerritoryID] { territories[id]?.neighbors ?? [] }

    func areAdjacent(_ a: TerritoryID, _ b: TerritoryID) -> Bool {
        territories[a]?.neighbors.contains(b) ?? false
    }

    var continentsInOrder: [Continent] {
        continents.values.sorted { $0.tint < $1.tint }
    }

    /// The rank of the continent this territory belongs to.
    func tint(of id: TerritoryID) -> Int {
        territories[id].flatMap { continents[$0.continent]?.tint } ?? 0
    }

    /// Does the whole map hold together in one piece? An isolated territory
    /// would be unassailable, and the game could never end.
    var isConnected: Bool {
        guard let start = order.first else { return false }
        var seen: Set<TerritoryID> = [start]
        var stack = [start]
        while let id = stack.popLast() {
            for n in neighbors(of: id) where !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return seen.count == territories.count
    }

    /// The links that cross a continental border. All the tension of the
    /// board runs through them: too many and no continent can be defended;
    /// too few and the game bogs down.
    var continentalGateways: [(TerritoryID, TerritoryID)] {
        var seen = Set<String>()
        var links: [(TerritoryID, TerritoryID)] = []
        for id in order {
            guard let t = territories[id] else { continue }
            for n in t.neighbors {
                guard let other = territories[n], other.continent != t.continent else { continue }
                let key = [id, n].sorted().joined(separator: "|")
                if seen.insert(key).inserted { links.append((id, n)) }
            }
        }
        return links
    }
}

/// A crossing: two territories separated by sea and joined by a route.
///
/// On a checkerboard of hexagons, only cells that touch are neighbors. That
/// is what keeps adjacency safe from mistakes — but it rules out islands and
/// straits, and therefore any map that looks like the world. Crossings are
/// declared by hand instead, a handful per board, and the tests check that
/// they are reciprocal and that they lead somewhere. This is how the
/// original Risk does it: Alaska–Kamchatka, Brazil–North Africa.
struct SeaRoute: Hashable {
    let from: TerritoryID
    let to: TerritoryID
}

/// Where to place each territory on screen. Pure presentation.
struct BoardLayout {
    /// Center of each territory, in 0…1.
    var centers: [TerritoryID: Point]
    /// Circumradius of a cell, in the same units.
    var cellRadius: Double
    /// Board height relative to its width. Centers are normalized on x
    /// alone: putting both x and y on 0…1 would squash the hexagons as soon
    /// as the map is not square. Reserving the right height is the view's
    /// job, not something the board should distort itself for.
    var aspect: Double
    /// The edges of each cell that face another continent or the sea — the
    /// ones that make the border. Numbered like the vertices: edge `k` joins
    /// vertex `k` to the next.
    ///
    /// Without them a continent is invisible: cells carry the color of
    /// whoever holds them, not that of the land they belong to, and a player
    /// cannot see what is left to take to earn the bonus.
    var frontierEdges: [TerritoryID: Set<Int>] = [:]

    /// The crossings, so they can be drawn: a link you cannot see is a link
    /// that does not exist, from the player's point of view.
    var seaRoutes: [SeaRoute] = []

    /// The cell's vertices, ready to draw.
    func corners(of id: TerritoryID) -> [Point] {
        guard let c = centers[id] else { return [] }
        // A "pointy-top" hexagon: the first vertex is due north.
        return (0..<6).map { i -> Point in
            let angle = Double(i) * .pi / 3 - .pi / 2
            return Point(x: c.x + cellRadius * cos(angle),
                         y: c.y + cellRadius * sin(angle))
        }
    }
}

/// A map and its drawing, delivered together.
struct Board {
    var map: GameMap
    var layout: BoardLayout
}
