//
//  Random.swift
//  Riskelo US
//
//  A draw that can be replayed.
//
//  The system generator cannot be replayed: a game that goes wrong is lost
//  for analysis, and a test that fails once in thirty teaches nothing. This
//  one is a SplitMix64 — a few lines, a seed, and the same game twice.
//

import Foundation

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }
    init() { state = UInt64.random(in: .min ... .max) }

    /// How far along the sequence is. Resuming a game without this would not
    /// be resuming it: it would be another game starting in the same place.
    /// `init(seed:)` puts it back exactly where it was.
    var rawState: UInt64 { state }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
