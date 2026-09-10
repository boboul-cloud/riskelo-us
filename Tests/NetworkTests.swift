//
//  NetworkTests.swift
//  RiskeloUSTests
//
//  What travels between two devices.
//
//  The wire is the place in the game where a failure says nothing:
//  `Message.data` and `Message.read` swallow their errors, and a message that
//  will not encode simply does not leave. The device across the table sits on
//  "waiting for the launch…" with nothing showing anywhere.
//

import Foundation
import Testing
@testable import RiskeloUS

struct NetworkTests {

    private func freshGame(_ mode: Rules.Mode = .classic,
                           cards: Bool = false, board: Boards = .ring) -> GameState {
        var r = Rules(); r.mode = mode; r.territoryCards = cards
        return GameState.start(board: board,
                               players: (0..<3).map { Player(id: $0, name: "P\($0)") },
                               rules: r, seed: 11)
    }

    /// The handshake: the host sends the whole game, once.
    @Test func theGameSurvivesTheWire() {
        for board in Boards.allCases {
            for mode in Rules.Mode.allCases {
                let game = freshGame(mode, cards: true, board: board)
                guard let data = Message.game(game, yourSeat: 1, number: 0).data else {
                    Issue.record("\(board.label)/\(mode.label): the game will not encode")
                    continue
                }
                guard case let .message(.game(received, seat, number)) = Message.read(data) else {
                    Issue.record("\(board.label)/\(mode.label): the game will not read back")
                    continue
                }
                #expect(seat == 1)
                #expect(number == 0)
                // The digest is what the two devices will compare at every
                // move: if it differs from the handshake on, they will play
                // two different games believing them the same.
                #expect(received.digest == game.digest, "\(board.label)/\(mode.label)")
                #expect(received.map.order == game.map.order)
                #expect(received.rules == game.rules)
            }
        }
    }

    /// An assault in progress travels too: a game can be resumed at any
    /// moment, including in the middle of a duel.
    @Test func anAssaultInProgressSurvivesTheWire() {
        var r = Rules(); r.mode = .showdown
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: r, seed: 42)
        g.debugSkipToAttack()
        guard let (base, target) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("no assault possible"); return
        }
        let declared = g.declareAssault(from: base, to: target, questions: 2, category: .history)
        #expect(declared)
        g.raise()
        _ = g.answer(.chosen(0, elapsed: 3.5))     // the defender has answered

        guard let data = Message.game(g, yourSeat: 1, number: 7).data,
              case let .message(.game(received, _, _)) = Message.read(data) else {
            Issue.record("an assault in progress does not survive the wire"); return
        }
        #expect(received.assault?.stake == 2)
        #expect(received.assault?.defenderAnswer != nil)
        #expect(received.whoAnswers == received.assault?.attacker)
        #expect(received.digest == g.digest)
    }

    /// Every move in the game has to be able to travel: not one of them is
    /// allowed to stay on the dock.
    @Test func everyMoveCrossesTheWire() {
        let moves: [Action] = [
            .place("A1"),
            .declareAssault(from: "A1", to: "A2", questions: 2, category: .science),
            .declareAssault(from: "A1", to: "A2", questions: 1, category: nil),
            .answer(.chosen(2, elapsed: 4.25)),
            .answer(.timeout),
            .raise,
            .dismissAssault,
            .occupy(3),
            .fortify(from: "A1", to: "A2", count: 2),
            .advance,
            .endTurn,
            .exchangeCards([1, 2, 3]),
        ]
        for move in moves {
            guard let data = Message.move(move, number: 3, digest: 987_654).data,
                  case let .message(.move(received, number, digest)) = Message.read(data) else {
                Issue.record("\(move) does not cross the wire"); continue
            }
            #expect(received == move)
            #expect(number == 3)
            #expect(digest == 987_654)
        }
        guard let data = Message.lost.data, case .message(.lost) = Message.read(data) else {
            Issue.record("\"lost\" does not cross the wire"); return
        }
    }

    // MARK: - The envelope

    /// Rebuilds a packet identical to the real thing in every respect except
    /// the dialect number. This is a device that does not have the same
    /// version of the game.
    private func packet(_ message: Message, dialect: Int) -> Data {
        guard let real = message.data,
              var object = try? JSONSerialization.jsonObject(with: real) as? [String: Any]
        else { return Data() }
        object["dialect"] = dialect
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    /// The dialect reads **without decoding the message**. That is the entire
    /// reason the envelope exists: reading it from the inside required first
    /// succeeding at precisely what a version disagreement makes fail.
    @Test func aForeignDialectIsNamed() {
        let data = packet(.lost, dialect: 99)
        #expect(!data.isEmpty)
        guard case let .otherDialect(number) = Message.read(data) else {
            Issue.record("a foreign dialect is not recognized as one"); return
        }
        #expect(number == 99)
    }

    /// And it reads even when the message it wraps is unreadable — which is
    /// the real case: two different versions mean two different message
    /// shapes.
    @Test func aForeignDialectIsNamedEvenUnderAnUnreadableMessage() {
        let data = Data(#"{"dialect":42,"message":{"spell":{"_0":"?"}}}"#.utf8)
        guard case let .otherDialect(number) = Message.read(data) else {
            Issue.record("the dialect must read on its own, without the message"); return
        }
        #expect(number == 42)
    }

    /// A version from before the envelope announces no dialect at all. That
    /// is the failure that cost an evening: it has to be named too.
    @Test func aVersionWithNoEnvelopeIsNamed() {
        guard let old = try? JSONEncoder().encode(Message.lost) else {
            Issue.record("the bare message will not encode"); return
        }
        // The ancestor's packet: the message on its own, with no header.
        guard case let .otherDialect(number) = Message.read(old) else {
            Issue.record("a packet with no envelope is not recognized"); return
        }
        #expect(number == nil, "a version that announces nothing must announce nothing")
    }

    /// What is not a packet from this game is not a version disagreement, and
    /// must not be announced as one.
    @Test func whatIsNotAPacketIsUnreadable() {
        guard case .unreadable = Message.read(Data([0x00, 0x01, 0xFF])) else {
            Issue.record("arbitrary bytes pass for a dialect"); return
        }
    }

    /// The name you give yourself makes the trip. It is what lets a device
    /// name the other sides: if it were lost, each player would see "Red"
    /// where the other sees "Red · Marie", and nothing on screen would say
    /// why.
    @Test func theChosenNameCrossesTheWire() {
        guard let data = Message.hello(name: "Marie").data,
              case let .message(.hello(name)) = Message.read(data) else {
            Issue.record("the greeting does not survive the wire"); return
        }
        #expect(name == "Marie")

        // With no name, the greeting leaves anyway: the host has to be able
        // to tell "I have no name" from "I said nothing".
        guard let empty = Message.hello(name: "").data,
              case let .message(.hello(nothing)) = Message.read(empty) else {
            Issue.record("a greeting with no name will not read"); return
        }
        #expect(nothing.isEmpty)
    }

    /// Everything that leaves carries the dialect, without exception: it is
    /// the only way the far end always has something to go on.
    @Test func everyPacketCarriesItsDialect() {
        let messages: [Message] = [
            .game(freshGame(), yourSeat: 2, number: 0),
            .move(.endTurn, number: 1, digest: 7),
            .lost,
            .hello(name: "Robert"),
        ]
        for message in messages {
            guard let data = message.data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { Issue.record("\(message) will not encode"); continue }
            #expect(object["dialect"] as? Int == Message.dialect)
            // And the header really is IN FRONT, at the top level: nothing to
            // decode to reach it.
            #expect(object["message"] != nil)
        }
    }
}
