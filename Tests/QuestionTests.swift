//
//  QuestionTests.swift
//  RiskeloUSTests
//
//  A malformed question — a decoy equal to the correct answer, a duplicated
//  prompt, an empty category — does not make the game fail: it makes a player
//  lose without understanding why. That is the worst kind of fault, and the
//  only one nobody reports.
//

import Testing
@testable import RiskeloUS

struct QuestionTests {

    /// The file replaces the compiler: what it no longer proofreads, this
    /// test proofreads. And better — the compiler never could tell that a
    /// decoy was identical to the correct answer.
    @Test(arguments: Themes.all)
    func everyFileReadsBack(_ c: Category) {
        let read = QuestionBank.questions(in: c)
        #expect(!read.isEmpty, "\(c.label): file missing or empty")
        #expect(read.allSatisfy { $0.category == c })
    }

    /// The folder makes the list: a file dropped in is one more theme, and no
    /// code enumerates them. The catalogue still has to find them.
    @Test func theFolderMakesTheListOfThemes() {
        #expect(Themes.all.count >= 7, "a theme is missing from the roll call")
        for c in Themes.all {
            let t = Themes.known(c)
            #expect(t != nil, "\(c.id): theme with no identity card")
            #expect(t?.name.isEmpty == false, "\(c.id): theme with no name")
        }
        // The displayed order must not depend on the order the system
        // returned the files in: two devices would show two different grids.
        let ranks = Themes.all.compactMap { Themes.known($0)?.rank }
        #expect(ranks == ranks.sorted(), "the grid is not in the declared order")
    }

    /// A theme excluded at setup never comes out — neither by its button nor
    /// by "at random".
    ///
    /// It is the only check that counts for this setting: excluding a theme
    /// without filtering the draw would have excluded only its button, and
    /// the player would have seen "at random" bring back exactly what they
    /// had just removed.
    @Test func anExcludedThemeNeverComesOut() {
        var r = Rules()
        r.themes = ["sports", "arts"]
        var g = GameState.start(board: .ring,
                                players: [Player(id: 0, name: "A", kind: .human),
                                          Player(id: 1, name: "B", kind: .human)],
                                rules: r, seed: 3)
        #expect(g.themesInPlay.map(\.id).sorted() == ["arts", "sports"])

        var rng = SeededRandom(seed: 3)
        for _ in 0 ..< 200 {
            let q = g.bank.draw(category: nil, among: g.themesInPlay,
                                difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(["sports", "arts"].contains(q!.question.category.id),
                    "\"at random\" produced an excluded theme")
        }
        // And the theme asked for by name is refused too: a move arriving
        // from the network must not be able to force a theme the table has
        // removed.
        let forced = g.bank.draw(category: .history, among: g.themesInPlay,
                                 difficulty: nil, using: &rng)
        #expect(forced == nil, "an excluded theme came out when named")
    }

    /// Nothing chosen means the base game — neither everything nor nothing.
    ///
    /// Not nothing, because a game without a question is indistinguishable
    /// from a breakdown. Not everything, because packs are chosen: they must
    /// not invite themselves into the game of someone who did not ask for
    /// them.
    @Test func noThemeChosenMeansTheBaseGame() {
        let g = GameState.start(board: .ring,
                                players: [Player(id: 0, name: "A", kind: .human),
                                          Player(id: 1, name: "B", kind: .human)],
                                rules: Rules(), seed: 1)
        #expect(g.themesInPlay.map(\.id).sorted() == Themes.base.map(\.id).sorted())
        #expect(g.themesInPlay.allSatisfy { $0.product == nil }, "a pack invited itself")

        // And rules naming only themes that are absent do not leave a game
        // without a question.
        var r = Rules()
        r.themes = ["a-theme-that-does-not-exist"]
        let h = GameState.start(board: .ring,
                                players: [Player(id: 0, name: "A", kind: .human),
                                          Player(id: 1, name: "B", kind: .human)],
                                rules: r, seed: 1)
        #expect(h.themesInPlay.count == Themes.base.count)
    }

    /// A pack declares itself for sale, and the catalogue files it on the
    /// right side.
    @Test func aPackIsToldApartFromTheBaseGame() {
        #expect(Themes.base.count == 6, "the base game has six themes")
        #expect(Themes.packs.count == 17, "seventeen packs ship")
        // A pack is sold: it has to last several evenings. Measured over
        // twenty runs of five games, two hundred questions give two clean
        // evenings and an acceptable third; below a hundred and fifty, the
        // second evening is already a rerun.
        for pack in Themes.packs {
            #expect(QuestionBank.questions(in: pack).count >= 200,
                    "\(pack.id): too thin to be sold")
        }
        #expect(Themes.base.allSatisfy { $0.product == nil })
        for pack in Themes.packs {
            let t = Themes.known(pack)
            #expect(t?.product?.hasPrefix("com.oulhen.riskelo.us.pack.") == true,
                    "\(pack.id): badly named item")
            #expect(t?.detail.isEmpty == false, "\(pack.id): nothing to show in the shop")
        }
        // The items are distinct: two packs on the same item would unlock
        // each other.
        let items = Themes.packs.compactMap(\.product)
        #expect(Set(items).count == items.count)
    }

    /// The pack choice holds for **every** way of launching a game, and not
    /// only the one that goes through the settings screen.
    ///
    /// That is the fault use turned up, and it was worth it: the choice lived
    /// in "Game settings", whose start button is the only one of five that
    /// reads what is ticked there. Quick game, resuming and the networked
    /// table all started from `QuickGame.rules()`, which is to say from
    /// factory values. You unticked a theme, and it came back.
    @Test func thePackChoiceHoldsForTheQuickGame() {
        let chosenBefore = Packs.chosen
        let baseBefore = Packs.withBase
        defer { Packs.chosen = chosenBefore; Packs.withBase = baseBefore }

        // One pack alone, with no general knowledge.
        Packs.withBase = false
        Packs.chosen = ["history-8"]
        let alone = GameState.start(board: .ring,
                                    players: [Player(id: 0, name: "A", kind: .human),
                                              Player(id: 1, name: "B", kind: .human)],
                                    rules: QuickGame.rules(), seed: 1)
        #expect(alone.themesInPlay.map(\.id) == ["history-8"],
                "the quick game ignores the pack choice")

        // Two packs mixed, still with no general knowledge.
        Packs.chosen = ["history-8", "history-9"]
        let mixed = GameState.start(board: .ring,
                                    players: [Player(id: 0, name: "A", kind: .human),
                                              Player(id: 1, name: "B", kind: .human)],
                                    rules: QuickGame.rules(), seed: 1)
        #expect(mixed.themesInPlay.map(\.id).sorted() == ["history-8", "history-9"])

        // And general knowledge on top.
        Packs.withBase = true
        let with = GameState.start(board: .ring,
                                   players: [Player(id: 0, name: "A", kind: .human),
                                             Player(id: 1, name: "B", kind: .human)],
                                   rules: QuickGame.rules(), seed: 1)
        #expect(with.themesInPlay.count == Themes.base.count + 2)
    }

    /// Unticking everything is not allowed: the base game comes back.
    @Test func youNeverPlayWithNoThemeAtAll() {
        let chosenBefore = Packs.chosen
        let baseBefore = Packs.withBase
        defer { Packs.chosen = chosenBefore; Packs.withBase = baseBefore }

        Packs.withBase = false
        Packs.chosen = []
        #expect(Packs.inPlay == Set(Themes.base.map(\.id)))
    }

    /// A malformed line has to be seen, not guessed at.
    @Test func aMalformedLineWillNotGetThrough() {
        let header = "! id | test\n! name | Test\n"
        let read = QuestionBank.read(header + """
            # a comment

            E | What is two plus two? | Four | Three | Five | Six
            """, fileName: "test")
        #expect(read?.questions.count == 1)
        #expect(read?.questions.first?.decoys.count == 3)
        #expect(read?.questions.first?.difficulty == .easy)
        #expect(QuestionBank.read(header, fileName: "test")?.questions.isEmpty == true)
        #expect(QuestionBank.read(header + "# nothing but comments",
                                  fileName: "test")?.questions.isEmpty == true)
    }

    /// A theme declares itself, and what it declares reaches the screen.
    @Test func aThemeDeclaresItselfInItsFile() {
        let read = QuestionBank.read("""
            ! id    | test
            ! name  | Test
            ! icon  | flask
            ! tint  | 0.10 0.20 0.30
            ! rank  | 4

            E | What is two plus two? | Four | Three | Five | Six
            """, fileName: "another-name")
        let t = read?.theme
        #expect(t?.id == "test", "the declared identifier comes before the file name")
        #expect(t?.name == "Test")
        #expect(t?.icon == "flask")
        #expect(t?.tint == Theme.Tint(r: 0.10, g: 0.20, b: 0.30))
        #expect(t?.rank == 4)
    }

    /// A question's identifier hangs on its prompt, not on its position.
    ///
    /// That is what makes it possible to correct a file that has been sold
    /// without erasing the memory of those who bought it: inserting a
    /// question at the top shifted every identifier after it, and the game
    /// then believed it had already asked questions it had never seen.
    @Test func theIdentifierSurvivesAnInsertedQuestion() {
        let header = "! id | test\n! name | Test\n"
        let before = QuestionBank.read(header + """
            E | What is two plus two? | Four | Three | Five | Six
            """, fileName: "test")
        let after = QuestionBank.read(header + """
            E | What is three plus three? | Six | Five | Seven | Eight
            E | What is two plus two? | Four | Three | Five | Six
            """, fileName: "test")
        #expect(before?.questions.first?.id == after?.questions.last?.id)
        // And it depends on no hash salted at startup.
        #expect(QuestionBank.identifier(theme: "test", prompt: "Two plus two?")
                == QuestionBank.identifier(theme: "test", prompt: "Two plus two?"))
    }

    /// The same question twice in a theme is one question fewer and a player
    /// who thinks they hit a bug. By hand, over a thousand lines, it happens.
    @Test(arguments: Themes.all)
    func noPromptIsRepeatedWithinATheme(_ c: Category) {
        let read = QuestionBank.questions(in: c)
        let prompts = read.map { $0.prompt.lowercased() }
        #expect(Set(prompts).count == prompts.count,
                "\(c.label): duplicated prompt")
    }

    /// A prompt carries one question, and one only, and it ends with the
    /// question mark.
    ///
    /// This test is not a matter of style: writing a batch by hand, I left my
    /// own hesitation in the text three times over — "Which game is played
    /// with dominoes... or rather: how many faces does a die have?". Nothing
    /// crashes, and the player reads an absurd sentence.
    @Test(arguments: Themes.all)
    func everyPromptIsOneSingleQuestion(_ c: Category) {
        for q in QuestionBank.questions(in: c) {
            #expect(q.prompt.filter { $0 == "?" }.count == 1,
                    "one question mark expected: \(q.prompt)")
            #expect(q.prompt.hasSuffix("?"), "the prompt has to end with \"?\": \(q.prompt)")
            #expect(!q.prompt.contains("..."), "hesitation left in the prompt: \(q.prompt)")
            #expect(!q.prompt.contains("…"), "hesitation left in the prompt: \(q.prompt)")
        }
    }

    /// A question that does not fit in the sheet gets clipped, and the answer
    /// becomes a guess.
    @Test(arguments: Themes.all)
    func nothingIsTooLong(_ c: Category) {
        for q in QuestionBank.questions(in: c) {
            #expect(q.prompt.count <= 110, "too long: \(q.prompt)")
            for p in [q.correct] + q.decoys {
                #expect(p.count <= 46, "choice too long: \(p)")
                #expect(!p.isEmpty, "empty choice in \"\(q.prompt)\"")
            }
        }
    }

    @Test func theBankIsWellFormed() {
        for q in QuestionBank.all {
            #expect(q.decoys.count == 3, "\(q.id) does not have three decoys")
            #expect(!q.decoys.contains(q.correct), "\(q.id): a decoy is the correct answer")
            #expect(Set(q.decoys).count == 3, "\(q.id): two identical decoys")
            #expect(q.prompt.hasSuffix("?"), "\(q.id) is not a question")
        }
    }

    @Test func noPromptOrIdentifierIsDuplicated() {
        let all = QuestionBank.all
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map(\.prompt)).count == all.count)
    }

    /// Every category has to sustain a long assault without repeating itself.
    @Test func everyCategoryIsWellStocked() {
        for c in Themes.all {
            #expect(QuestionBank().count(in: c) >= 8, "\(c.label) is too thin")
        }
    }

    @Test func theChoicesAreShuffled() {
        var rng = SeededRandom(seed: 7)
        var positions = Set<Int>()
        for _ in 0 ..< 40 {
            let asked = QuestionBank.all[0].asked(using: &rng)
            #expect(asked.choices.count == 4)
            #expect(asked.choices[asked.answer] == QuestionBank.all[0].correct)
            positions.insert(asked.answer)
        }
        #expect(positions.count == 4, "the correct answer always falls in the same place")
    }

    /// The correct answer does not settle on one row.
    ///
    /// The free draw was honest — a quarter per row, measured — and yet gave
    /// the same row three times running in more than nine games out of ten.
    /// The bag of slots forbids it: four questions, four rows, once each.
    @Test func theSlotsShuffleWithoutThreeInARow() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 21)
        var rows: [Int] = []
        for _ in 0 ..< 400 {
            guard let q = bank.draw(category: nil, difficulty: nil, using: &rng) else { break }
            #expect(q.choices[q.answer] == q.question.correct, "the correct answer moved")
            rows.append(q.answer)
        }
        #expect(rows.count == 400)
        for start in stride(from: 0, to: rows.count, by: QuestionBank.rows) {
            let group = rows[start ..< start + QuestionBank.rows]
            #expect(Set(group).count == QuestionBank.rows,
                    "group \(start / QuestionBank.rows): the same row twice")
        }
        for i in 2 ..< rows.count {
            #expect(!(rows[i] == rows[i - 1] && rows[i - 1] == rows[i - 2]),
                    "the same row three times at draw \(i)")
        }
    }

    /// A resumed game does not reshuffle in the middle of a group: what is
    /// left in the bag goes back exactly like the list of questions served.
    /// The trip through the save itself is exercised with the whole game.
    @Test func theBagOfSlotsGoesBackInPlace() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 4)
        _ = bank.draw(category: .science, difficulty: nil, using: &rng)
        _ = bank.draw(category: .science, difficulty: nil, using: &rng)
        let left = bank.remainingSlots
        #expect(left.count == QuestionBank.rows - 2)
        var resumed = QuestionBank()
        resumed.restore(served: bank.alreadyServed)
        resumed.restore(slots: left)
        #expect(resumed.remainingSlots == left)
        // A slot outside the four rows does not restore: a damaged save would
        // otherwise drop the correct answer nowhere at all.
        resumed.restore(slots: [0, 9, 2])
        #expect(resumed.remainingSlots == [0, 2])
    }

    @Test func aQuestionDoesNotComeBackWhileOthersRemain() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 3)
        var seen = Set<String>()
        for _ in 0 ..< QuestionBank().count(in: .history) {
            let q = bank.draw(category: .history, difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(seen.insert(q!.id).inserted, "question asked again too soon")
        }
    }

    /// The sneakiest fault this game ever had: the bank, short of questions
    /// in the category asked for, served one from another. You chose History
    /// and got "Who painted the Mona Lisa?". Nothing crashed, nothing showed
    /// — the only promise made to the attacker was broken in silence.
    @Test func theBankDoesNotLeaveTheGroundAskedFor() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 11)
        for round in 0 ..< 200 {
            let q = bank.draw(category: .sports, difficulty: .hard, using: &rng)
            #expect(q != nil)
            #expect(q?.category == .sports, "draw \(round): left the category asked for")
        }
    }

    /// An exhausted category starts over. Seeing again a question you
    /// insisted on is honest; getting one from another subject is not.
    @Test func anExhaustedCategoryStartsOverInsteadOfWandering() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 5)
        let stock = QuestionBank().count(in: .arts)
        var seen: [String] = []
        for _ in 0 ..< stock { seen.append(bank.draw(category: .arts, difficulty: nil, using: &rng)!.id) }
        #expect(Set(seen).count == stock, "the category has to be served in full first")
        // The next one starts from the beginning, and stays in the category.
        let after = bank.draw(category: .arts, difficulty: nil, using: &rng)
        #expect(after?.category == .arts)
    }

    // MARK: - Memory from one game to the next

    /// What has never been seen goes first.
    ///
    /// Every game used to open with a fresh bank: it drew from the full bag,
    /// and so asked yesterday's questions again. Someone playing alone runs
    /// games back to back — they recognized the question before having read
    /// it, and the duel stopped deciding anything.
    @Test func questionsNeverAskedComeFirst() {
        let all = QuestionBank().questions.filter { $0.category == .science }
        let never = Set(all.prefix(3).map(\.id))
        var seen: [String: Int] = [:]
        for q in all where !never.contains(q.id) { seen[q.id] = 1 }

        var bank = QuestionBank(seen: seen)
        var rng = SeededRandom(seed: 13)
        for round in 0 ..< never.count {
            let q = bank.draw(category: .science, difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(never.contains(q?.id ?? ""),
                    "draw \(round): a question already seen came before a fresh one")
        }
    }

    /// The mix of questions is a rule chosen at setup; the memory is only a
    /// comfort, and a comfort does not undo a rule. A "tough" game stays
    /// tough, even if that means asking a question already seen.
    @Test func theLevelAskedForComesBeforeFreshness() {
        let all = QuestionBank().questions.filter { $0.category == .arts }
        var seen: [String: Int] = [:]
        for q in all where q.difficulty == .hard { seen[q.id] = 1 }
        #expect(!seen.isEmpty, "we need hard questions to exercise the rule")

        var bank = QuestionBank(seen: seen)
        var rng = SeededRandom(seed: 17)
        for _ in 0 ..< 5 {
            let q = bank.draw(category: .arts, difficulty: .hard, using: &rng)
            #expect(q?.difficulty == .hard, "the level asked for gave way to freshness")
        }
    }

    /// What one game asked, the next avoids.
    @Test func theMemoryCarriesFromOneGameToTheNext() {
        var first = QuestionBank()
        var rng = SeededRandom(seed: 8)
        var asked: Set<String> = []
        for _ in 0 ..< 12 {
            asked.insert(first.draw(category: .sports, difficulty: nil, using: &rng)!.id)
        }
        #expect(first.seenUpToDate.count == 12)
        #expect(first.seenUpToDate.values.allSatisfy { $0 == 1 })

        var second = QuestionBank(seen: first.seenUpToDate)
        for _ in 0 ..< (QuestionBank().count(in: .sports) - 12) {
            let q = second.draw(category: .sports, difficulty: nil, using: &rng)!
            #expect(!asked.contains(q.id), "the next game asks a question from the first")
        }
    }

    /// The count is recomputed whole instead of incremented: the game saves
    /// at every move, and one question must not be counted as many times as
    /// there are saves.
    @Test func theMemoryNeverCountsTheSameQuestionTwice() {
        // A real question from the bank: identifiers are computed from the
        // prompt, they are not written by hand any more.
        let old = QuestionBank.questions(in: .history)[0].id
        var bank = QuestionBank(seen: [old: 2])
        var rng = SeededRandom(seed: 2)
        let asked = bank.draw(category: .history, difficulty: nil, using: &rng)!.id
        #expect(bank.seenUpToDate[asked] == 1)
        #expect(bank.seenUpToDate[old] == (asked == old ? 3 : 2))
        // Two saves in a row give the same count.
        #expect(bank.seenUpToDate == QuestionBank(seen: bank.seenUpToDate).alreadySeen)
    }

    /// Whoever joins a networked game plays with the host's memory — they
    /// have to, or the two devices would ask two different questions — but
    /// they do not inherit the host's evenings: their own memory records only
    /// what was asked in that game.
    @Test func whoeverJoinsDoesNotInheritTheHostsEvenings() {
        let hosts = QuestionBank.questions(in: .history).prefix(2).map(\.id)
        let mine = QuestionBank.questions(in: .arts)[0].id
        var received = QuestionBank(seen: Dictionary(uniqueKeysWithValues: hosts.map { ($0, 4) }))
        var rng = SeededRandom(seed: 6)
        let asked = received.draw(category: .history, difficulty: nil, using: &rng)!.id
        #expect(received.seenUpToDate(from: [mine: 1], excluding: []) == [mine: 1, asked: 1])
    }

    /// A resumed game does not recount yesterday's questions.
    ///
    /// The record is recomputed whole at every save, and a reopened game
    /// finds in its bank everything it had already asked: without the
    /// exception, a game opened three times would have counted its first
    /// questions three times, and made them look more worn than they are.
    @Test func aResumedGameDoesNotRecountItsQuestions() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 9)
        let yesterday = bank.draw(category: .science, difficulty: nil, using: &rng)!.id
        let memory = bank.seenUpToDate            // what the device recorded yesterday
        let counted = bank.alreadyServed          // what the resume finds again
        let today = bank.draw(category: .science, difficulty: nil, using: &rng)!.id
        let after = bank.seenUpToDate(from: memory, excluding: counted)
        #expect(after[yesterday] == 1, "yesterday's question is counted twice")
        #expect(after[today] == 1)
    }

    /// A memory that speaks of another bank is worth nothing: the questions
    /// it names no longer exist.
    @Test func aForeignMemoryIsSetAside() {
        let known = QuestionBank.questions(in: .sports)[0].id
        let atZero = QuestionBank.questions(in: .arts)[1].id
        let bank = QuestionBank(seen: [known: 3, "unknown-42": 9, atZero: 0])
        #expect(bank.alreadySeen == [known: 3])
    }

    /// The bank has to last an evening, and several. A game asks between
    /// fifty and a hundred and sixty questions, and one theme can burn
    /// through twenty-five of them in a single game.
    @Test func theBankLastsSeveralEvenings() {
        for c in Themes.all {
            #expect(QuestionBank().count(in: c) >= 30, "\(c.label) would run dry too fast")
        }
    }
}
