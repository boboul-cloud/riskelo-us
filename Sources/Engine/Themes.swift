//
//  Themes.swift
//  Riskelo US
//
//  A question's theme, and the list of the ones this device knows.
//
//  It used to be an enum with six cases, and each one's name, icon and color
//  were written across three `switch` statements scattered through the code.
//  An enum does not grow after compilation: while it stayed one, adding a
//  theme meant reopening four files and rebuilding the game.
//
//  A theme is now a **value that declares itself**, at the head of its own
//  question file. Adding a theme means dropping in a file. That is what makes
//  a theme sold separately possible one day — but the gain is already there
//  without selling anything: a theme's name is corrected where its questions
//  are, not three files away.
//
//  What the theme keeps of its own is reduced to its identifier. The name,
//  the color, the icon are not in the game: they are in the catalogue, and
//  the game carries only the short name. A saved game therefore stays as
//  small as before, and a renamed theme reads back without conversion.
//

import Foundation

// MARK: - A question's theme

/// The theme, reduced to its identifier — "history", "history-8".
///
/// It encodes as plain text, exactly as the string-valued enum it replaces
/// did: saved games read back, and the shape of network messages does not
/// move by a single byte.
///
/// It gains along the way that it never again refuses a value it does not
/// know. The enum threw an error on an unknown theme — and since it sat in
/// the middle of the game state, it was the whole game that became
/// unreadable, in silence.
struct Category: Hashable, Identifiable, Codable {

    let id: String

    init(_ id: String) { self.id = id }

    init(from decoder: Decoder) throws {
        id = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(id)
    }

    /// The readable name. Failing a catalogue entry — a theme received from a
    /// device that knows more — the identifier itself: unreadable, but never
    /// empty.
    var label: String { Themes.known(self)?.name ?? id }

    /// The name as it appears in front of the word "question": "History
    /// question", "Science question". English needs no article here, where
    /// French had to declare its own elision.
    var asQuestion: String { "\(label) question" }

    /// The pie-slice name, for the eye: the view hangs its color on it.
    var symbol: String { Themes.known(self)?.icon ?? "questionmark.circle" }

    /// Its color, as three values from 0 to 1. The engine does not know
    /// SwiftUI, and does not need to in order to carry a hue.
    var tint: Theme.Tint { Themes.known(self)?.tint ?? Theme.Tint(r: 0.5, g: 0.5, b: 0.5) }

    /// The item that unlocks it, if it is for sale.
    var product: String? { Themes.known(self)?.product }
}

// MARK: - What a theme declares

/// A theme's identity card, read at the head of its question file.
struct Theme: Hashable, Identifiable, Codable {

    /// A color, outside any display library.
    struct Tint: Hashable, Codable {
        let r: Double, g: Double, b: Double
    }

    let id: String
    let name: String
    let icon: String
    let tint: Tint
    /// One sentence, for the packs page. Empty for the themes that ship with
    /// the game: you do not explain "History", you explain "History — 8th".
    let detail: String
    /// The App Store item that unlocks it.
    ///
    /// Absent, the theme is in the game and belongs to everyone. Present, you
    /// have to own it to **choose** it — but its file is on every device,
    /// which lets someone joining a table play the host's pack without having
    /// bought it.
    let product: String?
    /// Its place in the grid of themes. Two themes of the same rank are
    /// separated by their identifier: the displayed order must never depend
    /// on the order in which the system happened to return the files.
    let rank: Int

    var category: Category { Category(id) }
}

// MARK: - The catalogue

/// The themes this device knows.
///
/// Built once, on first request, by reading the files in the bundle. It does
/// not change afterwards: a theme appearing in the middle of a game would
/// shift the draw under the players' feet.
///
/// Every theme that ships is present on every device of the same version —
/// that is what lets two devices draw the same question without ever sending
/// each other a bank. The day a theme is sold, it will be the **choice** of
/// the theme that is reserved to the buyer, not its presence: whoever joins
/// will be able to play the host's theme without having bought it.
enum Themes {

    private static let catalogue: [String: Theme] = {
        Dictionary(uniqueKeysWithValues: QuestionBank.allThemes.map { ($0.theme.id, $0.theme) })
    }()

    /// The themes in the order they are displayed.
    static let all: [Category] = catalogue.values
        .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.id < $1.id }
        .map(\.category)

    static func known(_ c: Category) -> Theme? { catalogue[c.id] }

    /// The themes that ship with the game — the ones with no price.
    static let base: [Category] = all.filter { known($0)?.product == nil }

    /// The packs, the ones that are bought.
    static let packs: [Category] = all.filter { known($0)?.product != nil }

    /// The named theme, if it exists. Used by tests and tools.
    static func named(_ id: String) -> Category? { catalogue[id].map(\.category) }
}
