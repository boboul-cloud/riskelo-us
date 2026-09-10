//
//  QuestionsFile.swift
//  Riskelo US
//
//  The bank, read from one file per theme.
//
//  It used to be hard-coded, and that was fair while it fitted in a few
//  dozen: the compiler was its best proofreader. Past a thousand, the
//  arithmetic flips — a literal with a thousand elements wrecks build times,
//  a typo demands a rebuild, and the file is no longer readable.
//
//  The format is not JSON: a thousand questions would run to fourteen
//  thousand lines. One line per question, six fields separated by bars. A
//  file of a thousand questions is a thousand lines long, reads back, gets
//  corrected, and sorts.
//
//      M | Which river runs through Cairo? | The Nile | The Euphrates | The Jordan | The Niger
//
//  What the compiler no longer checks, the tests check — and better: it never
//  could tell that a decoy was identical to the correct answer.
//
//  A file opens by introducing itself. Lines beginning with "!" declare the
//  theme — its name, its icon, its color, its place in the grid. They are
//  declarations, not comments, and the mark tells them apart: a comment is
//  lost without consequence, a missing declaration has to show.
//
//      ! id   | history
//      ! name | History
//
//  Themes are no longer listed anywhere: the folder is read. Dropping in a
//  file adds a theme, and that is all there is to do.
//

import Foundation

/// Used to find the application bundle, including from the tests.
private final class BundleMarker {}

extension QuestionBank {

    /// A theme and its questions, as one file carries them.
    struct ThemeFile {
        let theme: Theme
        let questions: [Question]
    }

    /// Everything this device can ask, theme by theme.
    ///
    /// Read once. The folder is walked rather than listed: that is what makes
    /// it possible to add a theme without touching the code.
    static let allThemes: [ThemeFile] = load()

    static let all: [Question] = allThemes.flatMap(\.questions)

    /// One theme's questions, as its file carries them.
    static func questions(in category: Category) -> [Question] {
        allThemes.first { $0.theme.category == category }?.questions ?? []
    }

    // MARK: - Finding the files

    /// The question files, wherever they are.
    ///
    /// Two paths, and two are needed. The application bundle first — that is
    /// the one for the app and for the tests. Then the source folder, for
    /// command-line tools: the simulation has no bundle, and the move to
    /// resources had left it without a single question, saying nothing.
    private static func files() -> [URL] {
        let bundle = Bundle(for: BundleMarker.self)
        // A command-line tool has no bundle. `Bundle(for:)` then returns the
        // binary's folder — "/tmp" for the simulation — and we were picking
        // up whatever ".txt" happened to be there, believing we had found the
        // bank. The bundle counts only if it is one.
        let isABundle = ["app", "xctest", "bundle", "framework"]
            .contains(bundle.bundleURL.pathExtension)
        if isABundle {
            for sub in ["Questions", nil] {
                let found = bundle.urls(forResourcesWithExtension: "txt",
                                        subdirectory: sub) ?? []
                if !found.isEmpty { return found }
            }
        }
        // The source folder, for the tools: the simulation has no bundle, and
        // the move to resources had left it without a single question, saying
        // nothing.
        let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Questions")
        let contents = (try? FileManager.default.contentsOfDirectory(at: source,
                                                                     includingPropertiesForKeys: nil))
        return (contents ?? []).filter { $0.pathExtension == "txt" }
    }

    private static func load() -> [ThemeFile] {
        var loaded: [ThemeFile] = []
        for url in files() {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let file = read(text, fileName: url.deletingPathExtension().lastPathComponent)
            else { continue }
            guard !loaded.contains(where: { $0.theme.id == file.theme.id }) else {
                assertionFailure("two files declare the theme \"\(file.theme.id)\"")
                continue
            }
            loaded.append(file)
        }
        // An empty bank makes the game silently unplayable: better to say so,
        // debug build or not.
        if loaded.isEmpty {
            FileHandle.standardError.write(Data("Riskelo US — no theme found\n".utf8))
        }
        return loaded.sorted { $0.theme.id < $1.theme.id }
    }

    // MARK: - Reading a file

    /// The parsing, kept apart so the tests can feed it by hand.
    static func read(_ text: String, fileName: String) -> ThemeFile? {
        var headers: [String: String] = [:]
        var lines: [(rank: Int, fields: [String])] = []

        for (rank, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("!") {
                let fields = line.dropFirst().split(separator: "|", maxSplits: 1)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard fields.count == 2 else {
                    assertionFailure("\(fileName).txt line \(rank + 1): "
                                     + "a declaration is written \"! key | value\"")
                    continue
                }
                headers[fields[0]] = fields[1]
                continue
            }

            let fields = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count == 6 else {
                assertionFailure("\(fileName).txt line \(rank + 1): "
                                 + "six fields expected, \(fields.count) found")
                continue
            }
            lines.append((rank, fields))
        }

        guard let theme = theme(headers, fileName: fileName) else { return nil }

        var questions: [Question] = []
        for (rank, fields) in lines {
            guard let level = Difficulty(letter: fields[0]) else {
                assertionFailure("\(fileName).txt line \(rank + 1): "
                                 + "unknown level \"\(fields[0])\"")
                continue
            }
            questions.append(Question(id: identifier(theme: theme.id, prompt: fields[1]),
                                      category: theme.category, difficulty: level,
                                      prompt: fields[1], correct: fields[2],
                                      decoys: Array(fields[3...])))
        }
        return ThemeFile(theme: theme, questions: questions)
    }

    /// The identity card declared at the head. The file name is the last
    /// resort for the identifier, and for that alone: a theme with no
    /// readable name is a mistake you should see, not one you should have to
    /// guess.
    private static func theme(_ e: [String: String], fileName: String) -> Theme? {
        let id = e["id"] ?? fileName
        guard let name = e["name"] else {
            assertionFailure("\(fileName).txt: \"! name | …\" missing")
            return nil
        }
        return Theme(id: id,
                     name: name,
                     icon: e["icon"] ?? "questionmark.circle",
                     tint: tint(e["tint"]),
                     detail: e["detail"] ?? "",
                     // An empty item counts as no item: a declaration left
                     // blank must not make a theme both unsellable and
                     // unusable at once.
                     product: e["product"].flatMap { $0.isEmpty ? nil : $0 },
                     rank: e["rank"].flatMap(Int.init) ?? 99)
    }

    /// "0.85 0.66 0.22" — three numbers from 0 to 1. A mid grey by default:
    /// visible, and ugly enough that the omission gets noticed.
    private static func tint(_ raw: String?) -> Theme.Tint {
        let n = (raw ?? "").split(separator: " ").compactMap { Double($0) }
        guard n.count == 3 else { return Theme.Tint(r: 0.5, g: 0.5, b: 0.5) }
        return Theme.Tint(r: min(1, max(0, n[0])),
                          g: min(1, max(0, n[1])),
                          b: min(1, max(0, n[2])))
    }

    // MARK: - A question's identifier

    /// The identifier is computed from the prompt, not from the position in
    /// the file.
    ///
    /// It used to be the rank — "history-12". Inserting a question at the top
    /// therefore shifted the thousand that followed, and the memory of what
    /// had already been asked started naming questions other than the ones it
    /// meant. Nobody noticed: nothing crashes, the questions simply come back
    /// sooner than they should.
    ///
    /// Computed from the prompt, the identifier survives every correction
    /// that does not touch the prompt — a decoy replaced, a level revised, a
    /// question added in the middle. What the sort gets out of it is a stable
    /// order, the same on both devices, whatever order the system returned
    /// the files in.
    static func identifier(theme: String, prompt: String) -> String {
        "\(theme):\(String(digest(prompt), radix: 16))"
    }

    /// A number derived from a text, the same everywhere and at every launch.
    ///
    /// Swift's hashing will not do: it is salted at every start, so it
    /// differs from one launch to the next and from one device to the next.
    /// This one is not — which is all that is asked of it.
    static func digest(_ text: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h &*= 0x0000_0100_0000_01B3
        }
        return h
    }
}

extension Difficulty {
    init?(letter: String) {
        switch letter.uppercased() {
        case "E": self = .easy
        case "M": self = .medium
        case "H": self = .hard
        default: return nil
        }
    }
}
