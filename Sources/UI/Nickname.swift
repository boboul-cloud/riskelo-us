//
//  Nickname.swift
//  Riskelo US
//
//  The name of whoever is holding the device.
//
//  The sides are called Blue, Red, Green: that is as it should be, because
//  the board knows nothing but colors and a name that cannot be found on it
//  is no use. But with four sides, three of them machines, "which one am I"
//  gets asked again at every glance.
//
//  Hence this name, optional, which is added to the side without replacing it
//  — "Red · Robert" and not "Robert". The color stays what ties the name to
//  the board; the nickname only says which side of the screen you are on.
//
//  It lives in the system preferences and not in the game: it names the
//  owner of the device, not a player in a particular game. A game resumed six
//  months later will carry the name of the moment, and that is as it should
//  be.
//

import Foundation

enum Nickname {

    static let key = "riskelo.us.nickname"

    /// The length beyond which the strip of sides overflows on a phone. It
    /// fits on one line, and a long name would set it scrolling for nothing.
    static let maxLength = 14

    /// The name given, or nothing if there is none. Never an empty string nor
    /// spaces alone: "nothing" and "three spaces" have to behave the same, or
    /// the badge shows a separator followed by emptiness.
    static var current: String? {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        let clean = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        return clean.isEmpty ? nil : clean
    }
}
