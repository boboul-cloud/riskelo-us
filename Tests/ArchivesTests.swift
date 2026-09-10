//
//  ArchivesTests.swift
//  RiskeloUSTests
//
//  The library promises to hand back exactly the position entrusted to it.
//  That is a promise you cannot check by eye: a position restored wrong looks
//  like a position.
//

import Foundation
import Testing
@testable import RiskeloUS

struct ArchivesTests {

    private func freshShelf() -> Archives {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("riskelo-us-tests-\(UUID().uuidString)", isDirectory: true)
        return Archives(folder: d)
    }

    private func game(_ seed: UInt64 = 42) -> GameState {
        GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")], seed: seed)
    }

    @Test func theMomentHandedBackIsTheMomentEntrusted() {
        let shelf = freshShelf()
        var g = game()
        g.debugSkipToAttack()
        let id = UUID()
        shelf.store(g, game: id, label: "Turn 1")

        guard let m = shelf.list().first?.moments.first,
              let back = shelf.load(m) else {
            Issue.record("nothing was shelved"); return
        }
        #expect(back.turn == g.turn)
        #expect(back.current == g.current)
        #expect(back.map.order.allSatisfy { back.owner[$0] == g.owner[$0] })
        #expect(back.map.order.allSatisfy { back.armies($0) == g.armies($0) })
        // The draw as well, or what follows would no longer be the same game.
        #expect(back.digest == g.digest)
    }

    /// One moment per turn, not one per move: otherwise a ten-turn game would
    /// leave a thousand indistinguishable positions.
    @Test func oneMomentPerTurnOnly() {
        let shelf = freshShelf()
        var g = game()
        let id = UUID()
        for _ in 0 ..< 5 { shelf.store(g, game: id, label: "Turn \(g.turn)") }
        #expect(shelf.list().first?.moments.count == 1)

        // A mark laid down by hand goes through anyway: that is its whole
        // purpose.
        shelf.store(g, game: id, label: "Position marked", marked: true)
        #expect(shelf.list().first?.moments.count == 2)
        #expect(shelf.list().first?.moments.last?.marked == true)

        // The next player's turn lays down its own — and it is the side that
        // tells them apart: `turn` only moves at the end of the table.
        let turnBefore = g.turn
        g.debugSkipToFortify()
        g.endTurn()
        #expect(g.turn == turnBefore, "with two players the counter only moves on the second")
        shelf.store(g, game: id, label: "Turn \(g.turn) — \(g.currentPlayer.name)")
        #expect(shelf.list().first?.moments.count == 3)
        #expect(shelf.list().first?.moments.last?.side == g.current)
    }

    @Test func theListCarriesEnoughToRecognizeAGame() {
        let shelf = freshShelf()
        var r = Rules(); r.mode = .showdown
        var g = GameState.start(board: .europe,
                                players: [Player(id: 0, name: "Blue"),
                                          Player(id: 1, name: "Red",
                                                 kind: .machine(level: 0.6, style: .strong))],
                                rules: r, seed: 7)
        g.debugSkipToAttack()
        shelf.store(g, game: UUID(), label: "Turn 1")

        guard let p = shelf.list().first else { Issue.record("nothing was shelved"); return }
        #expect(p.board == .europe)
        #expect(p.mode == .showdown)
        #expect(p.players == ["Blue", "Red"])
        #expect(p.bots == [1])
        #expect(!p.isFinished)
        // The balance of power is in the index: the list has to draw it
        // without opening a single state.
        let counts = p.moments[0].territories
        #expect(counts.reduce(0, +) == g.map.order.count)
    }

    @Test func deletingTakesTheFilesWithIt() {
        let shelf = freshShelf()
        let g = game()
        let id = UUID()
        shelf.store(g, game: id, label: "Turn 1")
        guard let m = shelf.list().first?.moments.first else {
            Issue.record("nothing was shelved"); return
        }
        shelf.delete(id)
        #expect(shelf.list().isEmpty)
        #expect(shelf.load(m) == nil, "the state must not be left lying on disk")
    }

    /// The shelf does not grow without end.
    @Test func oldGamesGoAway() {
        let shelf = freshShelf()
        let g = game()
        for _ in 0 ..< (Archives.gamesKept + 4) {
            shelf.store(g, game: UUID(), label: "Turn 1")
        }
        #expect(shelf.list().count == Archives.gamesKept)
    }
}
