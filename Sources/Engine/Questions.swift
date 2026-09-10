//
//  Questions.swift
//  Riskelo US
//
//  The trivia question, which replaces the die.
//
//  A question does not store its choices in order: it keeps its correct
//  answer on one side, its decoys on the other, and the order is drawn at the
//  moment of asking. Two reasons: you cannot get the index wrong while
//  writing the bank — the commonest and most invisible mistake — and nobody
//  ends up learning that the right answer is "usually the second one".
//

import Foundation

enum Difficulty: Int, CaseIterable, Comparable, Hashable, Codable {
    case easy = 1, medium = 2, hard = 3
    static func < (a: Difficulty, b: Difficulty) -> Bool { a.rawValue < b.rawValue }
    var label: String {
        switch self {
        case .easy:   "Easy"
        case .medium: "Medium"
        case .hard:   "Hard"
        }
    }
}

struct Question: Identifiable, Hashable, Codable {
    let id: String
    let category: Category
    let difficulty: Difficulty
    let prompt: String
    let correct: String
    let decoys: [String]

    /// The question as it is asked, with the correct answer on the requested
    /// row. The decoys are always shuffled among themselves: it is the
    /// position of the correct answer, and that alone, that the bank keeps an
    /// eye on.
    func asked<G: RandomNumberGenerator>(placingCorrectAt row: Int,
                                         using rng: inout G) -> AskedQuestion {
        var choices = decoys
        choices.shuffle(using: &rng)
        let slot = min(max(0, row), choices.count)
        choices.insert(correct, at: slot)
        return AskedQuestion(question: self, choices: choices, answer: slot)
    }

    /// With no instruction about position: it is drawn at random. This is the
    /// door for tests — the bank itself always goes through the bag of slots.
    func asked<G: RandomNumberGenerator>(using rng: inout G) -> AskedQuestion {
        let row = Int.random(in: 0 ... decoys.count, using: &rng)
        return asked(placingCorrectAt: row, using: &rng)
    }
}

struct AskedQuestion: Identifiable, Hashable, Codable {
    let question: Question
    let choices: [String]
    let answer: Int
    var id: String { question.id }
    var prompt: String { question.prompt }
    var category: Category { question.category }
    var difficulty: Difficulty { question.difficulty }
    func isCorrect(_ index: Int) -> Bool { index == answer }
}

/// The stock of questions, and two memories of what has already been asked.
///
/// The game's memory: a question does not come back while others remain in
/// the theme. And the device's memory, which carries from one game to the
/// next: at equal difficulty, the bank serves what has never come up first.
struct QuestionBank {

    /// How many choices a question carries: four rows.
    static let rows = 4

    private(set) var questions: [Question]
    private var served: Set<String> = []

    /// What the player has already seen, from one game to the next: how many
    /// times each question has come up.
    ///
    /// `served` only holds for the current game; the next one starts from a
    /// full bag, and the same questions come out again. Across a thousand
    /// questions that should not show — but a game asks a hundred of them,
    /// drawn at random from the whole bag, so two games in a row share a good
    /// dozen. Someone playing alone runs games back to back, and sees nothing
    /// but those repeats.
    ///
    /// The draw takes from the least-seen first — so from those never asked,
    /// while any remain. This is not a weight but a priority: the bank is a
    /// deck of a thousand cards dealt without replacement and reshuffled only
    /// once empty. A weight would have let yesterday's question return while
    /// a hundred had never been used, and that is exactly what players hold
    /// against the game.
    ///
    /// The count travels with the game — and therefore reaches the second
    /// device, which has to draw the same questions as the first. It is
    /// frozen at the opening: what the game asks afterwards is in `served`,
    /// and joins the count at save time.
    private var seen: [String: Int] = [:]

    /// The bag of slots — which row the correct answer falls on.
    ///
    /// The draw was honest, and that was the flaw. An honest coin comes up
    /// heads three times running once in eight; across the sixty questions of
    /// a game, seeing the right answer on the same row three times in a row
    /// happens in ninety-five games out of a hundred. The player does not see
    /// randomness in that — they see a habit of the machine, and start
    /// playing against it rather than against the question. A single run is
    /// enough to plant the suspicion, and nothing afterwards removes it.
    ///
    /// So the four slots are drawn like four cards from a deck: without
    /// replacement, reshuffled when empty. Every group of four questions
    /// carries the right answer once on each row, in an unpredictable order;
    /// twice running in the same place is the most anyone can see, and never
    /// three times.
    private var slots: [Int] = []

    init(questions: [Question] = QuestionBank.all, seen: [String: Int] = [:]) {
        self.questions = questions
        restore(seen: seen)
    }

    var count: Int { questions.count }

    /// What has already been asked, for saving the game. The questions
    /// themselves are in the bundle: this is all there is to keep.
    var alreadyServed: Set<String> { served }

    mutating func restore(served: Set<String>) {
        self.served = served.filter { id in questions.contains { $0.id == id } }
    }

    /// What the long memory knew when the game opened.
    var alreadySeen: [String: Int] { seen }

    /// The count as it stands **now**: what was known at the opening, plus
    /// what the game has asked since. This is what is kept on the device.
    ///
    /// It is recomputed each time instead of being incremented: it can
    /// therefore be written at every save — there is one per move — without
    /// ever counting the same question twice.
    var seenUpToDate: [String: Int] { seenUpToDate(from: seen, excluding: []) }

    /// The same count, laid over a base other than its own, and without
    /// recounting what was already counted.
    ///
    /// The base, because whoever joins a networked game receives the host's
    /// bank, and therefore the host's memory: they play with it — that is
    /// what makes both devices draw the same question — but they should not
    /// inherit the other player's evenings. They add to their own only what
    /// was asked here.
    ///
    /// The exception, because a resumed game finds yesterday's questions
    /// again in `served`, and those are already counted: without this, a game
    /// opened three times would count its first questions three times over.
    func seenUpToDate(from base: [String: Int], excluding counted: Set<String>) -> [String: Int] {
        var count = base
        for id in served.subtracting(counted) { count[id, default: 0] += 1 }
        return count
    }

    /// A memory that speaks of another bank is worth nothing: the questions
    /// it names no longer exist. We keep what can be found again.
    mutating func restore(seen: [String: Int]) {
        let known = Set(questions.map(\.id))
        self.seen = seen.filter { known.contains($0.key) && $0.value > 0 }
    }

    /// What is left in the bag of slots: a resumed game must find it exactly
    /// as it was, or it reshuffles in the middle of a group.
    var remainingSlots: [Int] { slots }

    mutating func restore(slots: [Int]) {
        self.slots = slots.filter { (0 ..< QuestionBank.rows).contains($0) }
    }

    /// The next slot, drawn from the bag; the bag is reshuffled when empty.
    private mutating func nextSlot<G: RandomNumberGenerator>(among count: Int,
                                                             using rng: inout G) -> Int {
        if slots.isEmpty {
            slots = Array(0 ..< QuestionBank.rows)
            slots.shuffle(using: &rng)
        }
        let drawn = slots.removeLast()
        // A question that did not have its four choices should not always
        // land at the end for that: it goes back to the free draw.
        return drawn < count ? drawn : Int.random(in: 0 ..< count, using: &rng)
    }

    func count(in category: Category) -> Int {
        questions.filter { $0.category == category }.count
    }

    /// Draws a question in the requested category — and never leaves it.
    ///
    /// The first version widened the search when the category ran dry: you
    /// asked for History and, past the tenth question, got "Who painted the
    /// Mona Lisa?". That silently broke the only promise made to the
    /// attacker, the promise of choosing the ground. Now an exhausted
    /// category forgets what it has served and starts over: a question
    /// already seen is honest — you insisted on that subject — where an
    /// off-topic question is a lie.
    ///
    /// Difficulty, on the other hand, stays indicative: it is a wish, not a
    /// contract. `among` is the list of themes the game allows. The filter
    /// applies even when a theme is asked for by name: a move arriving from
    /// the network must not be able to pull a question out of a theme the
    /// table has excluded.
    ///
    /// "At random" means at random **among what is in play** — otherwise
    /// excluding a theme would have excluded only its button.
    mutating func draw<G: RandomNumberGenerator>(category: Category?,
                                                 among themes: [Category] = Themes.all,
                                                 difficulty: Difficulty?,
                                                 using rng: inout G) -> AskedQuestion? {
        let allowed = Set(themes.map(\.id))
        let field = questions.filter {
            (category == nil || $0.category == category) && allowed.contains($0.category.id)
        }
        guard !field.isEmpty else { return nil }

        if field.allSatisfy({ served.contains($0.id) }) {
            for q in field { served.remove(q.id) }
        }
        let free = field.filter { !served.contains($0.id) }
        let atLevel = free.filter { difficulty == nil || $0.difficulty == difficulty }
        // Difficulty first, freshness second: the mix of questions is a rule
        // chosen at setup, the memory is only a comfort, and a comfort does
        // not undo a rule.
        let candidates = atLevel.isEmpty ? free : atLevel
        let fewest = candidates.map { seen[$0.id] ?? 0 }.min() ?? 0
        // Sorted by identifier, not left in file order.
        //
        // `randomElement` draws an index, not a question: two devices that
        // store their questions in a different order draw the same index and
        // ask two different questions. The order came from the files, that is
        // to say from whatever the system returned first — nothing that is
        // promised to be the same on an iPhone and on an iPad.
        //
        // The identifier, on the other hand, is computed from the prompt. So
        // the sort is the same everywhere, and will stay so when a theme is
        // added.
        let freshest = candidates.filter { (seen[$0.id] ?? 0) == fewest }
            .sorted { $0.id < $1.id }
        guard let drawn = freshest.randomElement(using: &rng) else { return nil }

        served.insert(drawn.id)
        // The slot first, the question second: two accesses to `rng` in the
        // same call would not do, and the order has to stay the same on both
        // devices.
        let row = nextSlot(among: drawn.decoys.count + 1, using: &rng)
        return drawn.asked(placingCorrectAt: row, using: &rng)
    }
}
