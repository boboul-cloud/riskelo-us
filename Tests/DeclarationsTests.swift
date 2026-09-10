//
//  DeclarationsTests.swift
//  RiskeloUSTests
//
//  What the app declares to the system.
//
//  Playing across devices does not depend on the code alone: without two
//  entries in the Info.plist, iOS refuses the local network, and it refuses
//  it **in silence**. The devices still see each other — discovery goes over
//  Bluetooth — but the link never establishes. Nothing in the code can notice,
//  and no build fails.
//
//  This file exists because the failure happened: two build folders coexisted,
//  and one held a version made without those entries. A test that questions
//  the bundle itself would have said so at once.
//

import Foundation
import Testing
@testable import RiskeloUS

struct DeclarationsTests {

    private var bundle: Bundle { Bundle(for: Link.self) }

    @Test func localNetworkIsDeclared() {
        let reason = bundle.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription")
        // Without NSLocalNetworkUsageDescription, iOS never asks for
        // permission and the link fails without a word.
        #expect(reason is String)

        let services = bundle.object(forInfoDictionaryKey: "NSBonjourServices") as? [String]
        #expect(services != nil, "NSBonjourServices is missing from the Info.plist")
        // The service name and its declaration have to travel together:
        // separating them is one more silent failure, and nothing else links
        // them.
        #expect(services?.contains("_\(Link.service)._tcp") == true)
        #expect(services?.contains("_\(Link.service)._udp") == true)
    }

    /// Bonjour will not take any name: fifteen characters at most, lowercase,
    /// digits and hyphens. An invalid name makes browsing fail at startup,
    /// with no sign beyond a callback nobody was listening to.
    @Test func serviceNameIsValid() {
        let name = Link.service
        #expect(!name.isEmpty && name.count <= 15)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let valid = name.unicodeScalars.allSatisfy { allowed.contains($0) }
        #expect(valid, "this is not a valid Bonjour service name")
        #expect(!name.hasPrefix("-") && !name.hasSuffix("-"))
    }

    /// Riskelo US must not share a wire with the French app: the two ship
    /// different question packs, and two devices that found each other would
    /// sit down to a table neither could play.
    @Test func serviceNameIsNotTheFrenchAppsOne() {
        #expect(Link.service != "riskelo-jeu")
    }
}

/// The device's identity on the wire.
@MainActor
struct IdentityTests {

    /// It has to survive the next launch. An identity remade at every start
    /// leaves the system with stale identities for the same device: the link
    /// works once, then never again.
    @Test func identityDoesNotChangeBetweenCalls() {
        let a = Link.identity()
        let b = Link.identity()
        #expect(a == b, "two calls must return the same identity")
        #expect(a.name == b.name)
        #expect(!a.name.isEmpty)
    }
}
