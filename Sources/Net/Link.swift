//
//  Link.swift
//  Riskelo US
//
//  The wire between two devices.
//
//  Bonjour to find each other, TCP to talk — through the Network framework.
//
//  It used to be MultipeerConnectivity, and that looked like the obvious
//  choice: it takes Bluetooth and peer-to-peer Wi-Fi without your having to
//  choose, asks for neither an account nor a network, and works on a train.
//
//  It had one flaw no setting fixes. Its game session accepts ONLY
//  peer-to-peer Wi-Fi — the system log says so word for word: "use awdl,
//  prohibit fallback". And peer-to-peer Wi-Fi is forbidden on the 5 GHz
//  channels known as "radar" (52 to 140), which routers pick by themselves
//  and change without warning. On such a channel, discovery works, the
//  invitation goes through, and the game never starts: "Sendmsg failed with
//  error No route to host", ten times over, then it gives up. Measured here,
//  on channel 104, between a Mac and an iPhone that pinged each other
//  perfectly.
//
//  A player has neither the logs nor any say over their router. Making the
//  game depend on a condition they can neither see nor fix was not tenable.
//
//  Hence this wire. Discovery is still Bonjour, exactly the same; the data
//  goes over an ordinary TCP connection. `includePeerToPeer` stays on, so
//  peer-to-peer Wi-Fi still serves when it is there — on a train, with no
//  router at all. But it becomes a bonus instead of a requirement.
//
//  And the whole dance of invitations goes with it. There is no longer an
//  invitation to accept, no backup to send six seconds later, no roles to
//  keep symmetrical, no forty-six-second delay at the end of which you give
//  up: whoever joins opens a connection, and it either succeeds or it fails.
//  A whole family of failures leaves with it.
//
//  This file knows nothing about the game: it carries packets of bytes and
//  says who is there. What travels inside them is `Match`'s business.
//

import Foundation
import Network
#if os(iOS)
import UIKit
#endif

/// A device at the other end of the wire.
///
/// Two devices are the same if their identity is the same. The name
/// distinguishes nothing: since iOS 16 every iPhone is called "iPhone" to
/// anyone without permission to ask for more.
struct Pair: Hashable, Sendable {
    /// Kept from one launch to the next. See `Link.identity()`.
    let id: String
    /// What is shown on screen.
    let name: String

    static func == (a: Pair, b: Pair) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@Observable
@MainActor
final class Link {

    /// The service name. Fifteen characters at most, lowercase and hyphens:
    /// that is a Bonjour constraint, not a taste.
    ///
    /// It is not the French app's "riskelo-jeu", deliberately: the two apps
    /// ship different question packs, so a French device and an American one
    /// must not find each other and sit down to a table neither can play.
    nonisolated static let service = "riskelo-us"

    /// What the host says about itself in its advertisement.
    ///
    /// The keys are short because all of this travels in a Bonjour record,
    /// which is small. Only the host advertises now: whoever joins has
    /// nothing left to make known to anyone, they connect.
    nonisolated static let keyRole = "r", keyName = "n", keyID = "i"
    /// Where to reach the host, without having to ask anyone.
    ///
    /// Letting the system resolve a Bonjour service seemed natural, and it
    /// was the shortest path on paper. On one iPhone here it led nowhere: the
    /// table was visible, its address was never obtained, and the connection
    /// stayed "preparing" until it timed out — no error, nothing to hold on
    /// to.
    ///
    /// And yet the same iPhone reached the Mac in a second from Safari, and
    /// the server log confirmed it from the other end: its packets arrive,
    /// over IPv4 as over IPv6. It is resolving the *service* that fails,
    /// nothing else. So we advertise where we are, and the guest goes there
    /// with no question to ask.
    ///
    /// An **address**, and not a hostname. I tried the name, taken from
    /// `ProcessInfo.hostName`: on the Mac it returns "macbook-air.local", but
    /// on the iPad it returns "customer.lndngbr1.isp.starlink.com" — the name
    /// the internet provider assigns to the connection. Sticking ".local" on
    /// the end gave an address that designates nothing. An IP address, at
    /// least, is not guessed at: it is read.
    nonisolated static let keyAddress = "a", keyPort = "p"
    nonisolated static let host = "h"

    /// What someone says when they want in and cannot get there.
    ///
    /// On one iPhone here, iOS lets the app **listen and advertise**, and
    /// refuses it **outgoing** connections to the local network — with the
    /// settings switch green, and the log saying `localNetworkDenied` at
    /// every attempt. Measured: the joining iPhone never gets through; the
    /// iPhone holding the table is joined in a second. The failure runs one
    /// way, and no setting lifts it.
    ///
    /// So we reverse the direction. Whoever joins advertises in turn — "I
    /// want in at that table" — and it is the host who comes to them. Both
    /// paths are tried at once; the first to succeed wins, the other closes
    /// on its own (see `identify`). It is therefore enough that **one of the
    /// two** devices can dial out, instead of requiring it to be the one
    /// joining.
    nonisolated static let guest = "v"
    /// The table they are aiming at: only its host should call them back, and
    /// not every open table on the network.
    nonisolated static let keyTarget = "c"

    enum State: Equatable {
        case stopped
        /// We are holding a table and waiting for someone to come.
        case open
        /// We are looking for someone holding one.
        case searching
        /// The connection has left, we are waiting for it to succeed.
        case calling(String)
        case linked(String)
        case lost(String)
        /// The system refused to open the network, or the connection did not
        /// succeed.
        case refused(String)
        /// The system is cutting this app off from the local network.
        ///
        /// It says so in one way only, and from a long way off: "Network is
        /// down" on an address that is perfectly valid and reachable. Nothing
        /// on screen, nothing in the settings that leaps out — the "local
        /// network" permission is refused once and never asked for again.
        /// Without this case, the player saw only "did not answer" and went
        /// looking at their Wi-Fi, where there was nothing to find.
        case notAllowed
    }

    private(set) var state: State = .stopped
    /// The tables found nearby, for the player who is searching.
    private(set) var found: [Pair] = []
    /// The devices linked, in the order they arrived: that order is what
    /// decides the seats.
    private(set) var linked: [Pair] = []

    var iAmHost: Bool { hosting }

    /// What arrives from another device, and from whom.
    var onReceive: ((Data, Pair) -> Void)?
    /// Called for each device linked, with `true` if we are the one who
    /// opened the game. With four players it is called three times.
    var onConnected: ((Bool, Pair) -> Void)?

    /// How many devices the host is waiting for in all, not counting itself.
    /// It stops advertising as soon as the table is full.
    var expected = 1

    /// Our identity on the wire.
    let me = Link.identity()

    /// Are we on a network?
    ///
    /// The whole question of peer-to-peer Wi-Fi hangs on this. A listener
    /// that turns it on advertises under a hostname shaped like an identifier
    /// — measured here: "49f8cb31-8eb0-….local" instead of
    /// "MacBook-Air.local", and it is `includePeerToPeer` alone that decides
    /// it. And that name does not always resolve over the ordinary network:
    /// the guest then stays stuck in preparing, with no error, until the
    /// timeout settles it. They find the table and never reach its address.
    ///
    /// Hence the rule: **peer-to-peer serves only for want of a network**. On
    /// a train it is the only path; on a network it does nothing but harm.
    @ObservationIgnored private let watcher = NWPathMonitor()
    private var onANetwork = true

    init() {
        watcher.pathUpdateHandler = { [weak self] path in
            let on = path.status == .satisfied
                && (path.usesInterfaceType(.wifi)
                    || path.usesInterfaceType(.wiredEthernet))
            MainActor.assumeIsolated { self?.onANetwork = on }
        }
        watcher.start(queue: .main)
    }

    deinit { watcher.cancel() }

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var hosting = false
    /// The table is held — even once we have stopped accepting because it was
    /// full. It only closes for good at launch time.
    private var tableOpen = false

    /// The open channels, by device.
    private var channels: [Pair: Channel] = [:]
    /// The channels that have not yet said who they are. A guest arriving is
    /// a stranger first: it is their greeting that names them.
    private var anonymous: [Channel] = []
    /// Where to reach each table found.
    private var addresses: [Pair: NWEndpoint] = [:]
    /// The same, as a bare IP address — for the probe only. See `probe`.
    private var rawAddresses: [Pair: NWEndpoint] = [:]
    /// The deadline of a connection in progress.
    private var deadline: Task<Void, Never>?
    /// What our own advertisement says: host, or guest waiting for a call
    /// back.
    private var myRole = Link.host
    private var myTarget: String?
    /// The table we are waiting for a call back from. An incoming connection
    /// can only come from it: we do not let ourselves be picked up by
    /// another.
    private var expectedTarget: Pair?
    /// The guests already called back, so as not to call them twice a second
    /// — discovery refreshes constantly.
    private var called: Set<String> = []

    /// The transport settings.
    ///
    /// `includePeerToPeer` leaves peer-to-peer Wi-Fi available — that is what
    /// makes it possible to play with no router at all, on a train. The
    /// difference from MultipeerConnectivity comes down to one word: here it
    /// is *permitted*, there it was *required*.
    ///
    /// But permitted is not enough: when both paths exist, the system may
    /// choose peer-to-peer Wi-Fi — and that is forbidden on the 5 GHz radar
    /// channels, where it fails in silence. So we open discovery to both, and
    /// try the connection **over the network first**, peer-to-peer being
    /// tried only afterwards. The common case takes the safe path; the train
    /// stays possible.
    private static func settings(direct: Bool = true) -> NWParameters {
        let p = NWParameters.tcp
        p.includePeerToPeer = direct
        // We forbid no interface.
        //
        // I had forbidden cellular, telling myself a game is played in the
        // same room and that path leads nowhere. It was a hunch, held without
        // proof, and it cost dearly: the system then answered "Network is
        // down" — there was no path left it would allow itself to take.
        // Forbidding one useless path amounted to closing them all. We let
        // the system choose: it knows perfectly well that a ".local" name is
        // not reached over cellular.
        //
        // A game cannot bear a move waiting: without this, TCP groups small
        // sends together and delays the most urgent ones.
        if let tcp = p.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            // A dead link has to show, but without haste: five seconds of
            // silence is an ordinary turn of play.
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 20
        }
        return p
    }

    /// The call-back test bench.
    ///
    /// The failure that made it necessary only happens on a device whose
    /// system refuses outgoing calls to the local network — we do not have
    /// one to hand, and we cannot ask iOS for it. With
    /// `RISKELO_NO_OUTGOING=1`, the app pretends: it advertises and calls
    /// nobody. The link then has to happen anyway, from the other direction.
    /// It is the only way to exercise that path without waiting for a player
    /// to run into it.
    nonisolated static let noOutgoingCalls =
        ProcessInfo.processInfo.environment["RISKELO_NO_OUTGOING"] == "1"

    /// This device's identity, **kept from one launch to the next**.
    ///
    /// It now serves only to recognize each other from one end of the wire to
    /// the other, but it has to stay stable: two devices that changed
    /// identity along the way would count themselves twice.
    static func identity() -> Pair {
        let defaults = UserDefaults.standard
        let key = "riskelo.us.identity"
        let id: String
        if let kept = defaults.string(forKey: key), !kept.isEmpty {
            id = kept
        } else {
            id = UUID().uuidString
            defaults.set(id, forKey: key)
        }
        return Pair(id: id, name: Link.deviceName)
    }

    /// This machine's address on the local network, if it has one.
    ///
    /// The first IPv4 address of an "en…" interface — Wi-Fi or Ethernet.
    /// Nothing to guess at: we read it from the system.
    ///
    /// `nil` when there is no network. That is exactly the case where
    /// peer-to-peer Wi-Fi takes over, and where the guest has to fall back on
    /// resolving the service: there, no fixed address would mean anything.
    static var localAddress: String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let start = list else { return nil }
        defer { freeifaddrs(list) }
        var current: UnsafeMutablePointer<ifaddrs>? = start
        while let ptr = current {
            let entry = ptr.pointee
            current = entry.ifa_next
            let name = String(cString: entry.ifa_name)
            let flags = Int32(entry.ifa_flags)
            guard let address = entry.ifa_addr,
                  flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  address.pointee.sa_family == UInt8(AF_INET),
                  name.hasPrefix("en")
            else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len),
                              &buffer, socklen_t(buffer.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            return String(cString: buffer)
        }
        return nil
    }

    /// The name the device carries.
    ///
    /// It is no longer `nonisolated`. It was in the days of
    /// MultipeerConnectivity, whose callbacks arrived on their own thread and
    /// had to be able to read it. Nothing reads it outside the main actor now
    /// — and `UIDevice.current` is bound to it precisely.
    static var deviceName: String {
        #if os(iOS)
        String(UIDevice.current.name.prefix(30))
        #else
        String((Host.current().localizedName ?? "Mac").prefix(30))
        #endif
    }

    // MARK: - Opening, searching, hanging up

    /// Hold a table: we listen, and we advertise.
    func open() {
        stop()
        hosting = true
        tableOpen = true
        myRole = Link.host
        myTarget = nil
        startListening()
        // And we search at the same time: a guest whose system refuses
        // outgoing calls leaves their address, and we are the ones who call.
        startBrowsing()
    }

    /// Listen, and advertise. Redone as is if the table reopens.
    private func startListening() {
        guard listener == nil else { return }
        do {
            // Peer-to-peer only if there is no network: see `onANetwork`. It
            // is this choice that decides the advertised name, and therefore
            // the guest's ability to reach us.
            let direct = !onANetwork
            print("Riskelo US — table open " + (direct ? "over peer-to-peer Wi-Fi" : "on the network"))
            let listening = try NWListener(using: Link.settings(direct: direct))
            listening.service = advertisement(port: nil)
            listening.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated { self?.listenerChanged(state) }
            }
            listening.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(connection) }
            }
            listener = listening
            listening.start(queue: .main)
            state = .open
        } catch {
            print("Riskelo US — table impossible: \(error)")
            state = .refused("")
        }
    }

    /// Look for a table.
    func search() {
        stop()
        hosting = false
        describeNetwork()
        startBrowsing()
        state = .searching
    }

    /// Watch what is advertised around us. Both roles use it: whoever joins
    /// finds the tables there, whoever hosts finds the guests who cannot get
    /// through.
    private func startBrowsing() {
        guard browser == nil else { return }
        // The same rule as for listening, and for the same reason: browsing
        // in peer-to-peer mode returns addresses cut for that path. On a
        // network, it is the network that has to be asked.
        let browsing = NWBrowser(for: .bonjourWithTXTRecord(type: "_\(Link.service)._tcp",
                                                            domain: nil),
                                 using: Link.settings(direct: !onANetwork))
        browsing.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.browserChanged(state) }
        }
        browsing.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated { self?.tablesSeen(results) }
        }
        browser = browsing
        browsing.start(queue: .main)
    }

    /// Join a table: we open a connection, and that is all.
    ///
    /// There is no longer an invitation to have accepted, and therefore
    /// nothing left that can go unanswered. Either the connection succeeds,
    /// or it fails and says so.
    ///
    /// A single attempt, by the same path the host chose — the network if
    /// there is one, peer-to-peer otherwise. There used to be two: the
    /// network first, peer-to-peer six seconds later. That second attempt
    /// went out over the first at the precise moment the first succeeded, and
    /// closed it. The host saw its link cut dead — "Connection reset by peer"
    /// — right after accepting it. A race nothing required us to run: both
    /// sides already apply the same rule.
    func join(_ pair: Pair) {
        guard let endpoint = addresses[pair] else { return }
        let direct = !onANetwork
        print("Riskelo US — connecting to \(pair.name) "
              + (direct ? "over peer-to-peer Wi-Fi" : "on the network") + " → \(endpoint)")
        state = .calling(pair.name)
        if let raw = rawAddresses[pair] { Link.probe(to: raw) }
        if !Link.noOutgoingCalls {
            let connection = NWConnection(to: endpoint, using: Link.settings(direct: direct))
            openChannel(connection, expecting: pair)
        } else {
            print("Riskelo US — outgoing call cut off for the test: waiting to be called back")
        }
        // And we advertise in turn: "I want in at that table". If the system
        // refuses us the outgoing call, the host will call us back — and if
        // it succeeds first, this advertisement will have served no purpose.
        expectedTarget = pair
        myRole = Link.guest
        myTarget = pair.id
        startListening()
        // TCP can take a long time to give up, and the screen would have sat
        // on "connecting…" saying nothing. We settle it ourselves.
        deadline?.cancel()
        deadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, !Task.isCancelled, case .calling = self.state else { return }
            print("Riskelo US — \(pair.name) did not answer")
            self.state = .refused(pair.name)
        }
    }

    /// A probe connection, to the host's **bare IP address**.
    ///
    /// It serves only to check one thing, at every attempt: that iOS really
    /// does refuse that path while granting the declared service. If it ever
    /// succeeds, the rule has changed.
    ///
    /// It sends nothing and closes after five seconds.
    static func probe(to endpoint: NWEndpoint) {
        let t = NWConnection(to: endpoint, using: .tcp)
        t.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Riskelo US — PROBE (Apple's settings): LINKED ✅")
                t.cancel()
            case .waiting(let e):
                let c = t.currentPath
                print("Riskelo US — PROBE waiting: \(e)"
                      + " | reason: \(String(describing: c?.unsatisfiedReason))")
            case .failed(let e):
                print("Riskelo US — PROBE failed: \(e)")
            default:
                break
            }
        }
        t.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { t.cancel() }
    }

    /// What this device sees of the network, spelled out.
    ///
    /// To be compared from one device to the other: it is the one place where
    /// an iPhone and an iPad can differ while running the same code.
    private func describeNetwork() {
        let c = watcher.currentPath
        print("""
            Riskelo US — network as seen by \(me.name):
              status      : \(String(describing: c.status))
              reason      : \(String(describing: c.unsatisfiedReason))
              wifi        : \(c.usesInterfaceType(.wifi))
              ethernet    : \(c.usesInterfaceType(.wiredEthernet))
              cellular    : \(c.usesInterfaceType(.cellular))
              interfaces  : \(c.availableInterfaces.map { "\($0.name)(\($0.type))" }.joined(separator: ", "))
              on a network: \(onANetwork)
            """)
    }

    /// Stop accepting, without giving up the table.
    ///
    /// The connections already open are unaffected — stopping listening cuts
    /// nothing that is established.
    private func stopAccepting() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
    }

    /// Close the table for good: the game is starting, we are waiting for
    /// nobody.
    func closeTable() {
        tableOpen = false
        stopAccepting()
    }

    /// Reopen, because a seat came free before launch.
    ///
    /// Without this, a guest who links then leaves — they quit the lobby, or
    /// their app goes to the background — left the host walled in: it had
    /// stopped listening believing itself full, and never started again. The
    /// table was still advertised, and therefore visible: you saw it, you
    /// touched it, and nothing ever came of it again.
    private func reopenTable() {
        guard hosting, tableOpen, linked.count < expected else { return }
        print("Riskelo US — a seat came free, the table reopens")
        startListening()
    }

    func stop() {
        deadline?.cancel(); deadline = nil
        tableOpen = false
        expectedTarget = nil
        called = []
        myRole = Link.host
        myTarget = nil
        stopAccepting()
        channels.values.forEach { $0.close() }
        channels = [:]
        anonymous.forEach { $0.close() }
        anonymous = []
        addresses = [:]
        rawAddresses = [:]
        found = []
        linked = []
        state = .stopped
    }

    // MARK: - What the system tells us

    /// What the host says about itself. The port is only known once the
    /// listener is ready: the advertisement is then redone, complete.
    private func advertisement(port: NWEndpoint.Port?) -> NWListener.Service {
        var txt = NWTXTRecord()
        txt[Link.keyRole] = myRole
        txt[Link.keyName] = me.name
        txt[Link.keyID] = me.id
        if let myTarget { txt[Link.keyTarget] = myTarget }
        if let port, let address = Link.localAddress {
            txt[Link.keyAddress] = address
            txt[Link.keyPort] = String(port.rawValue)
        }
        // The Bonjour instance name has to be unique on the network; the
        // device's name is not (every iPhone is called "iPhone"). So we
        // attach a fragment of our identity to it.
        return NWListener.Service(name: "\(me.name) \(me.id.prefix(4))",
                                  type: "_\(Link.service)._tcp",
                                  txtRecord: txt)
    }

    private func listenerChanged(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            // The port is known: we say who we are again, address included.
            if let listening = listener, let port = listening.port {
                print("Riskelo US — " + (myRole == Link.host ? "table ready" : "address left")
                      + " at \(Link.localAddress ?? "no address"):\(port)")
                listening.service = advertisement(port: port)
            }
        case .failed(let error):
            // Almost always the "local network" permission.
            print("Riskelo US — table impossible: \(error)")
            state = .refused("")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func browserChanged(_ newState: NWBrowser.State) {
        if case .failed(let error) = newState {
            print("Riskelo US — browsing impossible: \(error)")
            // At the host, this browsing is only a backup: its table stands
            // without it, and failing it must not close the table.
            if !hosting { state = .refused("") }
        }
    }

    /// The tables seen around us.
    private func tablesSeen(_ results: Set<NWBrowser.Result>) {
        if hosting { callBackGuests(results); return }
        var seen: [Pair] = []
        var endpoints: [Pair: NWEndpoint] = [:]
        for t in results {
            guard case let .bonjour(txt) = t.metadata,
                  txt[Link.keyRole] == Link.host,
                  let id = txt[Link.keyID], !id.isEmpty
            else { continue }
            // Never offer ourselves to ourselves.
            guard id != me.id else { continue }
            let pair = Pair(id: id, name: txt[Link.keyName] ?? "Device")
            print("Riskelo US — table seen: \(t.endpoint)"
                  + " over [\(t.interfaces.map(\.name).joined(separator: ", "))]")
            if !seen.contains(pair) { seen.append(pair) }

            // **The service, not the address.**
            //
            // iOS does not grant an app "the local network" wholesale: it
            // grants it the services it declared in `NSBonjourServices`. A
            // bare IP address appears in no declaration, and gets refused —
            // `localNetworkDenied` — even with the switch in Settings green.
            //
            // I had moved to the address to work around a resolution that
            // looked stuck. It was not: what was stuck was an invented
            // hostname, addresses nailed to the wrong interface, and two
            // connections cutting each other off — three faults fixed since.
            // By moving to the IP address, I had traded the permitted path
            // for a forbidden one.
            //
            // **Without the interface**: Bonjour finds the same table once
            // per interface, and the address it returns is nailed to the one
            // it saw it through. Detached, it is up to the system to choose.
            if case let .service(name, type, domain, _) = t.endpoint {
                endpoints[pair] = .service(name: name, type: type, domain: domain, interface: nil)
            } else {
                endpoints[pair] = t.endpoint
            }
            // The advertised address now serves only the probe, which checks
            // at every attempt that this path is indeed still the wrong one.
            if let raw = txt[Link.keyAddress], !raw.isEmpty,
               let n = txt[Link.keyPort], let number = UInt16(n),
               let port = NWEndpoint.Port(rawValue: number) {
                rawAddresses[pair] = .hostPort(host: NWEndpoint.Host(raw), port: port)
            }
        }
        addresses = endpoints
        found = seen
    }

    /// Call back those who cannot get through.
    ///
    /// We only call back guests aiming at **us**, once each, and only while a
    /// seat remains. One more call to someone already linked would add
    /// nothing but a wire that `identify` would close again straight away.
    private func callBackGuests(_ results: Set<NWBrowser.Result>) {
        guard tableOpen, linked.count < expected else { return }
        for t in results {
            guard case let .bonjour(txt) = t.metadata,
                  txt[Link.keyRole] == Link.guest,
                  txt[Link.keyTarget] == me.id,
                  let id = txt[Link.keyID], id != me.id,
                  !called.contains(id)
            else { continue }
            let pair = Pair(id: id, name: txt[Link.keyName] ?? "Device")
            guard channels[pair] == nil else { continue }
            called.insert(id)
            // Without the interface, as for the tables: it is up to the
            // system to choose which way to go.
            let endpoint: NWEndpoint
            if case let .service(name, type, domain, _) = t.endpoint {
                endpoint = .service(name: name, type: type, domain: domain, interface: nil)
            } else {
                endpoint = t.endpoint
            }
            print("Riskelo US — \(pair.name) cannot get through: calling them → \(endpoint)")
            openChannel(NWConnection(to: endpoint, using: Link.settings(direct: !onANetwork)),
                        expecting: pair)
        }
    }

    /// A guest presents themselves at our table — or, when we are the ones
    /// joining, the host answering our call.
    private func accept(_ connection: NWConnection) {
        guard hosting else {
            // We are not hosting: the only legitimate incoming connection is
            // from the table we touched.
            guard let expected = expectedTarget else { connection.cancel(); return }
            openChannel(connection, expecting: expected)
            return
        }
        guard linked.count < expected else {
            // The table is full: refuse outright rather than leave a
            // connection open that nobody will read.
            connection.cancel()
            return
        }
        openChannel(connection, expecting: nil)
    }

    // MARK: - The channels

    private func openChannel(_ connection: NWConnection, expecting: Pair?) {
        let channel = Channel(connection: connection)
        anonymous.append(channel)
        channel.onReady = { [weak self, weak channel] in
            guard let self, let channel else { return }
            // Each side says who it is as soon as the wire is open. Without
            // that, whoever accepts a connection would never know who had
            // just arrived: an address is not an identity.
            channel.send(self.greeting())
        }
        channel.onPacket = { [weak self, weak channel] data in
            guard let self, let channel else { return }
            self.received(data, on: channel, expecting: expecting)
        }
        channel.onForbidden = { [weak self] in
            guard let self else { return }
            self.deadline?.cancel(); self.deadline = nil
            self.state = .notAllowed
        }
        channel.onClosed = { [weak self, weak channel] in
            guard let self, let channel else { return }
            self.channelClosed(channel)
        }
        channel.start()
    }

    /// Our calling card: the identity and the name, nothing else.
    ///
    /// It travels in its own packet, ahead of everything else, and never
    /// changes shape — it is the one contract every future version has to
    /// keep on this wire. The game's dialect is `Match`'s business, and it is
    /// negotiated afterwards.
    private func greeting() -> Data {
        let card = ["id": me.id, "name": me.name]
        return (try? JSONSerialization.data(withJSONObject: card)) ?? Data()
    }

    private func received(_ data: Data, on channel: Channel, expecting: Pair?) {
        // Until they have named themselves, everything arriving is their
        // greeting.
        if channel.pair == nil {
            guard let card = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let id = card["id"], !id.isEmpty
            else {
                print("Riskelo US — a device introduced itself without naming itself")
                channel.close()
                return
            }
            let pair = Pair(id: id, name: card["name"] ?? "Device")
            // If we were aiming at someone, they are who we must find.
            if let expecting, expecting != pair {
                print("Riskelo US — expected \(expecting.name), got \(pair.name)")
                channel.close()
                return
            }
            identify(channel, pair)
            return
        }
        guard let pair = channel.pair else { return }
        onReceive?(data, pair)
    }

    /// A channel has just said who it is: the link is made.
    private func identify(_ channel: Channel, _ pair: Pair) {
        anonymous.removeAll { $0 === channel }
        // Two wires to the same device: keep the first.
        if channels[pair] != nil {
            channel.close()
            return
        }
        channel.pair = pair
        channels[pair] = channel
        if !linked.contains(pair) { linked.append(pair) }
        deadline?.cancel(); deadline = nil
        state = .linked(pair.name)
        print("Riskelo US — \(pair.name): linked")
        // Whoever joins has finished searching. Whoever hosts keeps accepting
        // until the table is full, and stops there.
        if !hosting || linked.count >= expected { stopAccepting() }
        onConnected?(hosting, pair)
    }

    private func channelClosed(_ channel: Channel) {
        anonymous.removeAll { $0 === channel }
        guard let pair = channel.pair else {
            // It never said its name: this is a connection that did not
            // succeed. Only the deadline concludes, so as not to kill a link
            // that was about to be made.
            return
        }
        guard channels[pair] === channel else { return }
        channels[pair] = nil
        linked.removeAll { $0 == pair }
        // They can be called back if they advertise again.
        called.remove(pair.id)
        print("Riskelo US — \(pair.name): link lost")
        if case .linked = state { state = .lost(pair.name) }
        reopenTable()
    }

    // MARK: - Sending

    /// To everyone. A lost move would desynchronize the games: TCP guarantees
    /// order and delivery, there is nothing to add.
    func send(_ data: Data) {
        channels.values.forEach { $0.send(data) }
    }

    /// To a single device: each has to learn its own seat, and only its own.
    func send(_ data: Data, to pair: Pair) {
        channels[pair]?.send(data)
    }

    /// To everyone but one: this is how the host relays a player's move to
    /// the others without sending it back to them.
    func send(_ data: Data, except pair: Pair) {
        for (who, channel) in channels where who != pair { channel.send(data) }
    }
}

private extension NWError {
    /// "Network is down" on a local-network address does not mean the network
    /// is cut — we have just reached it another way. It means the system is
    /// closing it **to this app**.
    var isLocalNetworkRefusal: Bool {
        if case let .posix(code) = self { return code == .ENETDOWN }
        return false
    }
}

// MARK: - A channel, and its packets

/// A TCP connection, and what it takes to pass whole packets over it.
///
/// TCP is a stream of bytes: it knows nothing of messages. Two sends can
/// arrive stuck together, one can arrive cut in two. Each packet therefore
/// leaves preceded by its length on four bytes, and a packet is only handed
/// up once it is there in full. Without that, every other message would be
/// unreadable — and the failure would look like a version disagreement.
@MainActor
private final class Channel {

    let connection: NWConnection
    var pair: Pair?

    var onReady: (() -> Void)?
    /// The system is closing the local network to us. See `State.notAllowed`.
    var onForbidden: (() -> Void)?
    var onPacket: ((Data) -> Void)?
    var onClosed: (() -> Void)?

    /// What has arrived but is not yet complete.
    private var buffer = Data()
    private var closed = false

    /// Beyond this, it is no longer a packet from this game: the whole game
    /// fits very comfortably within this size, and an absurd length can only
    /// come from a misaligned stream.
    private static let maxSize = 8 * 1024 * 1024

    init(connection: NWConnection) { self.connection = connection }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.onReady?()
                    self.read()
                case .preparing:
                    print("Riskelo US — channel preparing")
                case .waiting(let error):
                    // The state the log was missing. A connection that does
                    // not succeed does not "fail": it *waits*, keeping its
                    // reason to itself.
                    //
                    // And "Network is down" does not say *which* of its
                    // reasons. The system keeps the exact count, though —
                    // permission denied, Wi-Fi denied, nothing available — in
                    // `NWPath.unsatisfiedReason`. That is the one place where
                    // it names the cause, and that is the one to read.
                    let path = self.connection.currentPath
                    print("""
                        Riskelo US — channel waiting: \(error)
                          path status  : \(String(describing: path?.status))
                          reason       : \(String(describing: path?.unsatisfiedReason))
                          interfaces   : \(path?.availableInterfaces.map(\.name).joined(separator: ", ") ?? "none")
                          costly/capped: \(String(describing: path?.isExpensive)) / \(String(describing: path?.isConstrained))
                        """)
                    if path?.unsatisfiedReason == .localNetworkDenied
                        || error.isLocalNetworkRefusal {
                        self.onForbidden?()
                    }
                case .failed(let error):
                    print("Riskelo US — channel broken: \(error)")
                    self.close()
                case .cancelled:
                    self.reportClosure()
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    func send(_ data: Data) {
        guard !closed else { return }
        var length = UInt32(data.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(data)
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error {
                print("Riskelo US — packet not sent: \(error)")
            }
        })
    }

    func close() {
        guard !closed else { return }
        closed = true
        connection.cancel()
        onClosed?()
    }

    private func reportClosure() {
        guard !closed else { return }
        closed = true
        onClosed?()
    }

    private func read() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] chunk, _, done, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let chunk, !chunk.isEmpty {
                    self.buffer.append(chunk)
                    self.split()
                }
                if let error {
                    print("Riskelo US — read interrupted: \(error)")
                    self.close()
                    return
                }
                if done { self.close(); return }
                guard !self.closed else { return }
                self.read()
            }
        }
    }

    /// Hands up every whole packet present in the buffer.
    private func split() {
        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(0) { Int($0) << 8 | Int($1) }
            guard length > 0, length <= Channel.maxSize else {
                print("Riskelo US — absurd packet length (\(length))")
                close()
                return
            }
            guard buffer.count >= 4 + length else { return }
            let body = buffer.subdata(in: 4 ..< (4 + length))
            buffer.removeSubrange(0 ..< (4 + length))
            onPacket?(body)
        }
    }
}
