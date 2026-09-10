//
//  Boards.swift
//  Riskelo US
//
//  The boards, and the choice between them.
//
//  Each one is a drawing in plain characters, from which the adjacencies
//  follow: that is what makes it safe to add another without risking the
//  invisible mistake — a mistyped adjacency crashes nothing, it makes a
//  territory unassailable and turns up three games later.
//
//  The real maps here are hexagons laid over the geography, not traced
//  coastlines. What that buys is a plan you rework by moving a letter, drawn
//  borders, and tests that check at every build that the world holds
//  together. What it costs is the shape of the coasts — which nobody would
//  make out at this size on a phone. Since the engine knows nothing but
//  adjacency, a realistic rendering could replace this one without a single
//  line of the rules moving.
//

import Foundation

enum Boards: String, CaseIterable, Identifiable, Codable {

    /// The name of a side. It belongs here rather than in a view: two
    /// devices must name the same players the same way.
    static func sideName(_ rank: PlayerID) -> String {
        let names = ["Blue", "Red", "Green", "Amber", "Purple"]
        return names[((rank % names.count) + names.count) % names.count]
    }

    case ring, europe, world

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ring:   "The Ring"
        case .europe: "Europe"
        case .world:  "World"
        }
    }

    var detail: String {
        switch self {
        case .ring:   "An invented world, five lands in a circle. 28 territories."
        case .europe: "From the Atlantic to the Black Sea. 38 territories."
        case .world:  "The six continents, 42 territories — like the box."
        }
    }

    /// Built once and for all: a board never changes.
    var board: Board { Boards.all[self]! }

    private static let all: [Boards: Board] = Dictionary(
        uniqueKeysWithValues: Boards.allCases.map { ($0, $0.build()) })

    private func build() -> Board {
        switch self {
        case .ring:   HexPlan.build(rows: Boards.ringPlan, continents: Boards.ringLands)
        case .europe: HexPlan.build(rows: Boards.europePlan, continents: Boards.europeLands,
                                    seaRoutes: Boards.europeCrossings)
        case .world:  HexPlan.build(rows: Boards.worldPlan, continents: Boards.worldLands,
                                    seaRoutes: Boards.worldCrossings)
        }
    }

    // MARK: - The Ring

    /// Five lands set in a circle — Borea, Ostmark, Meridia, Zephyria,
    /// Westmark, and back around. None of them has a single door: the land
    /// with only one way in becomes unassailable and decides the game on its
    /// own, which is the flaw of Australia in the original Risk.
    static let ringPlan = [
        ". A A A . .",
        ". A A . B .",
        "C C . B B B",
        "C C C . B .",
        ". C . . D D",
        ". C E . D .",
        ". E E E D D",
        ". . E E . .",
    ]

    static let ringLands: [HexPlan.ContinentSpec] = [
        .init(id: "A", name: "Borea", bonus: 3,
              names: ["Fjordane", "Greymoor", "Havenhold", "Skerry", "Whitecape"]),
        .init(id: "B", name: "Ostmark", bonus: 3,
              names: ["High Steppe", "Khanate", "Hourglass", "Oldport", "Redmount"]),
        .init(id: "C", name: "Westmark", bonus: 4,
              names: ["Thornmere", "Hedgerow", "Brightvale", "The Marches",
                      "Saltings", "Greystone", "High Moors"]),
        .init(id: "D", name: "Meridia", bonus: 2,
              names: ["Olivegrove", "Sirocco", "Gold Bay", "Dune", "Serrat"]),
        .init(id: "E", name: "Zephyria", bonus: 3,
              names: ["Tradewind", "Coral", "Reef", "Palmgrove", "Lagoon", "Mangrove"]),
    ]

    // MARK: - Europe

    /// The shape of Europe, as far as a checkerboard allows: the Scandinavian
    /// arm reaching north, the Iberian peninsula dropping southwest, the
    /// Italian boot, Greece and its islands at the bottom, and the British
    /// Isles offshore — joined by the Channel, which is a crossing.
    static let europePlan = [
        ". . . A A A . .",
        ". . . A . F . .",
        ". B . C F F . .",
        ". B C C E F . .",
        ". . C C E F F .",
        "D . C C E E F .",
        "D D C E E E F .",
        ". D D E E . . .",
        ". . D D . . . .",
    ]

    static let europeLands: [HexPlan.ContinentSpec] = [
        .init(id: "A", name: "Scandinavia", bonus: 2,
              names: ["Norway", "Sweden", "Finland", "Denmark"]),
        .init(id: "B", name: "British Isles", bonus: 2,
              names: ["Scotland", "England"]),
        .init(id: "C", name: "Western Europe", bonus: 4,
              names: ["Netherlands", "Belgium", "Germany", "France",
                      "Czechia", "Austria", "Switzerland", "Northern Italy"]),
        .init(id: "D", name: "Mediterranean", bonus: 3,
              names: ["Portugal", "Spain", "Balearics", "Corsica",
                      "Sardinia", "Italy", "Sicily"]),
        .init(id: "E", name: "Central Europe", bonus: 4,
              names: ["Poland", "Slovakia", "Hungary", "Slovenia",
                      "Croatia", "Serbia", "Albania", "Greece", "Crete"]),
        .init(id: "F", name: "Eastern Europe", bonus: 4,
              names: ["Baltic States", "Russia", "Belarus", "Ukraine",
                      "Moldova", "Romania", "Bulgaria", "Turkey"]),
    ]

    /// The Channel: without it, the islands would be out of reach.
    static let europeCrossings: [(String, String)] = [
        ("England", "Belgium"),
        ("England", "France"),
        ("Scotland", "Norway"),
    ]

    // MARK: - World

    /// The six continents of Risk, laid out as on the box: the Americas on
    /// the left, Asia filling the whole northeast, Africa center-south,
    /// Australia in its corner. The crossings do the rest — this is how the
    /// original game joins Alaska to Kamchatka.
    static let worldPlan = [
        "N N N . E E . A A A .",
        "N N N . E E E A A A A",
        ". N N . E E . A A . .",
        ". N . . F F A A A . .",
        ". S . . F F . . . O O",
        ". S S . F F . . . O O",
        ". S . . . . . . . . .",
    ]

    static let worldLands: [HexPlan.ContinentSpec] = [
        .init(id: "N", name: "North America", bonus: 5,
              names: ["Alaska", "Northwest Territory", "Greenland",
                      "Alberta", "Ontario", "Quebec",
                      "Western United States", "Eastern United States",
                      "Central America"]),
        .init(id: "S", name: "South America", bonus: 2,
              names: ["Venezuela", "Peru", "Brazil", "Argentina"]),
        .init(id: "E", name: "Europe", bonus: 5,
              names: ["Iceland", "Scandinavia", "Great Britain",
                      "Northern Europe", "Ukraine", "Western Europe",
                      "Southern Europe"]),
        .init(id: "F", name: "Africa", bonus: 3,
              names: ["North Africa", "Egypt", "Congo",
                      "East Africa", "South Africa", "Madagascar"]),
        .init(id: "A", name: "Asia", bonus: 7,
              names: ["Siberia", "Yakutsk", "Kamchatka",
                      "Ural", "Irkutsk", "Mongolia", "Japan",
                      "Afghanistan", "China",
                      "Middle East", "India", "Siam"]),
        .init(id: "O", name: "Australia", bonus: 2,
              names: ["Indonesia", "New Guinea",
                      "Western Australia", "Eastern Australia"]),
    ]

    /// Three crossings, and three only.
    ///
    /// South America has been pushed away from Africa: the two used to touch
    /// at Brazil, which let you walk from one continent into the other. They
    /// are now separated by sea, with a single door — Congo–Brazil. In the
    /// same way Australia hangs onto Asia by Siam–Indonesia alone, and those
    /// two touch, so they need no route.
    static let worldCrossings: [(String, String)] = [
        ("Alaska", "Kamchatka"),
        ("Greenland", "Iceland"),
        ("Congo", "Brazil"),
    ]
}

/// The default board, the one used by tests and previews.
enum TestBoard {
    static var board: Board { Boards.ring.board }
}
