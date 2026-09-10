//
//  Match.swift
//  Riskelo US
//
//  What travels on the wire.
//
//  Only three kinds of message. The complete state once, on connecting —
//  simpler and safer than making the other device guess the setup. Then the
//  moves, one at a time. And a request to resend, if the two games ever drift
//  apart.
//
//  Every move travels with the digest of the game as it stands AFTER playing
//  it. Whoever receives it compares: if they do not find the same one, they
//  ask for the complete state rather than go on playing a different game from
//  their opponent. It is the only safeguard possible — drift does not show,
//  both screens stay coherent each on its own side.
//

import Foundation

enum Message: Codable {

    /// The dialect spoken on the wire. To be raised as soon as the shape of a
    /// message changes — and it changes as soon as `Action` or `GameState` is
    /// touched.
    ///
    /// Two devices that do not speak the same dialect cannot play together.
    /// Without this number, a device receiving a game it cannot read does not
    /// read it, says nothing, and waits forever: the hardest fault in the
    /// whole game to understand, because it looks like a network failure when
    /// the link is perfect.
    ///
    /// It used to sit **inside** the message, and so protected only one side:
    /// reading it meant decoding the message first, which is precisely what a
    /// version disagreement makes fail. It now sits in front, in an envelope
    /// whose shape never changes.
    ///
    /// 1: the first dialect of this app. It starts over at one — Riskelo US
    ///    shares no wire with the French app, whose Bonjour service is not
    ///    even the same, so there is no older version to humor here.
    static let dialect = 1

    /// The whole game, sent by whoever opened it — each player's seat, and
    /// the count of moves already played.
    case game(GameState, yourSeat: PlayerID, number: Int)
    /// A move: its rank in the sequence, and the digest expected once it has
    /// been played.
    ///
    /// The number serves twice. With four devices the host relays moves to
    /// the others, and a device can receive the same one twice — it
    /// recognizes it and ignores it. And if a number is missing, a move has
    /// been lost: better to ask for the game again than to carry on without
    /// it.
    case move(Action, number: Int, digest: UInt64)
    /// "I am no longer in the same game as you, send it again."
    case lost
    /// "This is what I am called."
    ///
    /// Sent by each device as soon as the link is up, before any game.
    /// Whoever hosts uses it to name the sides: the name then leaves with the
    /// state, and every device sees the same players.
    ///
    /// The device name would not have been enough. Since iOS 16 it answers
    /// "iPhone" to anyone without permission to ask for more: two phones
    /// arrive in the lobby under the same name.
    ///
    /// Empty when no name has been given — the side then keeps its color for
    /// its only name, and that is perfectly fine.
    case hello(name: String)

    /// What is found in a packet received.
    ///
    /// Three outcomes and not two. "I did not understand" does not say *why*,
    /// and that is exactly what needed naming: on screen, "install the same
    /// version" and "this is a bug in the game" do not ask the same thing of
    /// the player.
    enum Reading {
        case message(Message)
        /// The packet comes from another version of the game. The number is
        /// the one that version announces — or `nil` if it predates the
        /// envelope and announces none.
        case otherDialect(Int?)
        /// The dialect is right and the content will not read. This is no
        /// longer a matter of versions: it means the shape of a message
        /// changed without the number being raised.
        case unreadable
    }

    /// The envelope: the dialect in front, the message behind.
    ///
    /// Its shape is the one contract every future version has to keep.
    /// Everything else may move.
    private struct Packet: Codable {
        let dialect: Int
        let message: Message
    }

    /// The header alone.
    ///
    /// It reads **even when the message that follows is written in a language
    /// we do not know**: a decoder asks only for the keys it knows about, and
    /// this one knows about exactly one. That is the entire reason the
    /// envelope exists.
    private struct Header: Decodable {
        let dialect: Int
    }

    var data: Data? {
        do {
            return try JSONEncoder().encode(Packet(dialect: Message.dialect,
                                                   message: self))
        } catch {
            // A message that does not leave keeps the other device waiting
            // with nothing showing anywhere. At least let it say so.
            print("Riskelo US — message not sent: \(error)")
            return nil
        }
    }

    static func read(_ data: Data) -> Reading {
        let decoder = JSONDecoder()

        guard let header = try? decoder.decode(Header.self, from: data) else {
            // No header at all. Two cases, and it is worth separating them:
            // JSON without an envelope comes from a version older than this
            // one — that is a version disagreement, and it should be said.
            // What is not JSON is not a packet from this game.
            if (try? JSONSerialization.jsonObject(with: data)) != nil {
                print("Riskelo US — packet with no dialect: version older than the envelope")
                return .otherDialect(nil)
            }
            print("Riskelo US — unreadable packet: this is not JSON")
            return .unreadable
        }

        guard header.dialect == Message.dialect else {
            print("Riskelo US — dialect \(header.dialect) received, \(Message.dialect) expected")
            return .otherDialect(header.dialect)
        }

        do {
            return .message(try decoder.decode(Packet.self, from: data).message)
        } catch {
            print("Riskelo US — unreadable message under the right dialect: \(error)")
            return .unreadable
        }
    }
}
