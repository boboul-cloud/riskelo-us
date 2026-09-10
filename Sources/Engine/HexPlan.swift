//
//  HexPlan.swift
//  Riskelo US
//
//  The board plan, written the way you would sketch it on a notepad.
//
//  A Risk map is usually built by hand, territory by territory, with its
//  adjacencies typed in one at a time — and a wrong adjacency does not show:
//  it merely makes a territory unassailable, three games later. Here the plan
//  is a checkerboard of hexagons described by a drawing in plain characters;
//  the adjacencies follow from it, and so they cannot be wrong. The board is
//  reworked by moving a letter.
//
//  "odd-r" offset: every other row is pushed half a cell to the right, like
//  a honeycomb.
//

import Foundation

enum HexPlan {

    struct ContinentSpec {
        let id: ContinentID
        let name: String
        let bonus: Int
        /// Territory names, consumed in the plan's reading order.
        let names: [String]
    }

    /// Builds map and drawing from the plan. `rows` reads line by line, one
    /// character per cell; a dot is sea, spaces are ignored.
    static func build(rows: [String], continents: [ContinentSpec],
                      seaRoutes: [(String, String)] = []) -> Board {
        var cells: [(col: Int, row: Int, key: Character)] = []
        for (r, line) in rows.enumerated() {
            var c = 0
            for ch in line where ch != " " {
                if ch != "." { cells.append((c, r, ch)) }
                c += 1
            }
        }

        // Naming: each continent draws from its list, in reading order. If
        // the list is too short we number instead of crashing — a plan being
        // reworked has to stay playable.
        var used: [Character: Int] = [:]
        var idOf: [String: TerritoryID] = [:]      // "col,row" -> identifier
        var nameOf: [TerritoryID: String] = [:]
        var continentOf: [TerritoryID: ContinentID] = [:]
        let specs = Dictionary(uniqueKeysWithValues: continents.map { (Character($0.id), $0) })

        for cell in cells {
            let spec = specs[cell.key]
            let n = used[cell.key, default: 0]
            used[cell.key] = n + 1
            let name = spec.map { n < $0.names.count ? $0.names[n] : "\($0.name) \(n + 1)" } ?? "\(cell.key)\(n)"
            let id = "\(cell.key)\(n)"
            idOf["\(cell.col),\(cell.row)"] = id
            nameOf[id] = name
            continentOf[id] = spec?.id ?? String(cell.key)
        }

        // "odd-r" adjacency.
        func neighbourKeys(col c: Int, row r: Int) -> [String] {
            let odd = r % 2 != 0
            let deltas: [(Int, Int)] = odd
                ? [(-1, 0), (1, 0), (0, -1), (1, -1), (0, 1), (1, 1)]
                : [(-1, 0), (1, 0), (-1, -1), (0, -1), (-1, 1), (0, 1)]
            return deltas.map { "\(c + $0.0),\(r + $0.1)" }
        }

        var territories: [Territory] = []
        for cell in cells {
            let id = idOf["\(cell.col),\(cell.row)"]!
            let ns = neighbourKeys(col: cell.col, row: cell.row).compactMap { idOf[$0] }
            territories.append(Territory(id: id, name: nameOf[id]!,
                                         continent: continentOf[id]!, neighbors: ns))
        }

        // Crossings are named by territory name: that is what reads back.
        var idByName: [String: TerritoryID] = [:]
        for (id, name) in nameOf { idByName[name] = id }
        var routes: [SeaRoute] = []
        for (a, b) in seaRoutes {
            guard let ia = idByName[a], let ib = idByName[b] else {
                assertionFailure("Crossing to an unknown territory: \(a) – \(b)")
                continue
            }
            routes.append(SeaRoute(from: ia, to: ib))
        }
        for route in routes {
            if let i = territories.firstIndex(where: { $0.id == route.from }),
               !territories[i].neighbors.contains(route.to) {
                territories[i].neighbors.append(route.to)
            }
            if let i = territories.firstIndex(where: { $0.id == route.to }),
               !territories[i].neighbors.contains(route.from) {
                territories[i].neighbors.append(route.from)
            }
        }

        var grouped: [ContinentID: [TerritoryID]] = [:]
        for t in territories { grouped[t.continent, default: []].append(t.id) }
        let conts = continents.enumerated().map { rank, spec in
            Continent(id: spec.id, name: spec.name, bonus: spec.bonus,
                      territories: grouped[spec.id] ?? [], tint: rank)
        }

        // Geometry: pointy-top hexagon, radius 1. Width √3, height 2, rows
        // overlapping by a quarter of their height.
        let w = 3.0.squareRoot()
        var raw: [TerritoryID: Point] = [:]
        for cell in cells {
            let id = idOf["\(cell.col),\(cell.row)"]!
            let dx = (cell.row % 2 != 0) ? w / 2 : 0
            raw[id] = Point(x: Double(cell.col) * w + dx, y: Double(cell.row) * 1.5)
        }

        // Scaled on x only: the hexagons stay regular.
        let minX = raw.values.map(\.x).min() ?? 0, maxX = raw.values.map(\.x).max() ?? 1
        let minY = raw.values.map(\.y).min() ?? 0, maxY = raw.values.map(\.y).max() ?? 1
        let span = (maxX - minX) + w              // one cell of margin: the edge
        let height = (maxY - minY) + 2.0          // must not clip the points
        var centers: [TerritoryID: Point] = [:]
        for (id, p) in raw {
            centers[id] = Point(x: (p.x - minX + w / 2) / span,
                                y: (p.y - minY + 1.0) / span)
        }

        // The six directions, in the order of the drawn edges: edge 0 leaves
        // the top vertex heading right, and we turn clockwise. Each one has a
        // neighbor across it — or the sea.
        func directions(row r: Int) -> [(Int, Int)] {
            let odd = r % 2 != 0
            return [
                odd ? (1, -1) : (0, -1),   // 0 — upper right
                (1, 0),                     // 1 — right
                odd ? (1, 1) : (0, 1),      // 2 — lower right
                odd ? (0, 1) : (-1, 1),     // 3 — lower left
                (-1, 0),                    // 4 — left
                odd ? (0, -1) : (-1, -1),   // 5 — upper left
            ]
        }
        var frontiers: [TerritoryID: Set<Int>] = [:]
        for cell in cells {
            let id = idOf["\(cell.col),\(cell.row)"]!
            var edges = Set<Int>()
            for (k, d) in directions(row: cell.row).enumerated() {
                let neighbor = idOf["\(cell.col + d.0),\(cell.row + d.1)"]
                if neighbor == nil || continentOf[neighbor!] != continentOf[id] { edges.insert(k) }
            }
            frontiers[id] = edges
        }

        let layout = BoardLayout(centers: centers,
                                 cellRadius: 1.0 / span,
                                 aspect: height / span,
                                 frontierEdges: frontiers,
                                 seaRoutes: routes)
        return Board(map: GameMap(territories: territories, continents: conts), layout: layout)
    }
}
