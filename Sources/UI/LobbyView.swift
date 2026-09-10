//
//  LobbyView.swift
//  Riskelo US
//
//  Finding each other, up to four devices.
//
//  One player opens the table, the others join it. Nothing to type, no
//  account, no network to configure: the devices see each other if they are
//  in the same room.
//
//  Whoever opens chooses the board, the rules and the number of players, and
//  sends them along with the game. The others have nothing to set — that
//  would be so many chances to disagree. It is also they who give each player
//  their seat, in order of arrival.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LobbyView: View {

    /// The table's board and rules. They arrive from the screen you came from
    /// — the settings, or the home screen and its quick game.
    let board: Boards
    let rules: Rules
    var onReady: (GameSession) -> Void
    var onCancel: () -> Void
    /// Going to change them. The host decides the game for everyone, and it
    /// is when opening the table that you think of it — not before.
    var onSettings: () -> Void = { }

    @State private var link = Link()
    /// The name each linked device has given itself. Empty until it has said
    /// hello — or if it has no name, which amounts to the same thing here.
    @State private var names: [Pair: String] = [:]
    @State private var playerCount = 2
    @State private var launched = false
    /// The game arrived, but in a language we do not speak.
    @State private var versionMismatch = false
    /// Linked, and nothing came. This is not a network failure — the link is
    /// good — and it has to be said, or you wait forever.
    @State private var silent = false
    /// We are searching and finding nothing. Another screen that spun forever
    /// while letting you believe that was normal.
    @State private var nothingInSight = false

    private var expected: Int { playerCount - 1 }
    private var missing: Int { max(0, expected - link.linked.count) }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 42)).foregroundStyle(Palette.side(0))
                Text("Play across devices")
                    .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)

                content
                Spacer()
                Button("Cancel") { link.stop(); onCancel() }
                    .buttonStyle(.bordered).tint(Palette.dim)
            }
            .frame(maxWidth: 420)
            .padding(26)
        }
        .preferredColorScheme(.dark)
        // The screen must not go dark while you fetch the other device: a
        // sleeping app stops advertising its table.
        #if os(iOS)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        .onDisappear { if !launched { link.stop() } }
    }

    /// What we are about to open, in one line: the board, the mode, and the
    /// options that really change the game.
    private var theGameWeOpen: String {
        var parts = [board.label, rules.mode.label]
        if rules.territoryCards { parts.append("cards") }
        if rules.objectives { parts.append("personal conquests") }
        if rules.dominationOverride == 0 { parts.append("total war") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var content: some View {
        switch link.state {
        case .stopped:
            Text("The devices have to be close by. No account, no network: "
                 + "Bluetooth or Wi-Fi is enough.")
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("HOW MANY PLAYERS").font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.dim).kerning(0.6)
                Picker("", selection: $playerCount) {
                    ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                Text("One device per player.")
                    .font(.caption2).foregroundStyle(Palette.dim)
            }

            button("Open the table", "plus.circle.fill", Palette.side(0)) {
                prepare()
                link.expected = expected
                link.open()
            }
            button("Join a table", "magnifyingglass", Palette.side(1)) {
                prepare(); link.search()
            }

            // The game that will be opened, and how to change it. Said before
            // opening, because afterwards it is too late: the host sets it,
            // and the others receive it as it stands.
            VStack(spacing: 8) {
                Text(theGameWeOpen)
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                Button(action: onSettings) {
                    Label("Game settings", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered).tint(Palette.dim)
                Text("Whoever opens the table chooses for everyone.")
                    .font(.caption2).foregroundStyle(Palette.dim.opacity(0.8))
            }
            .padding(.top, 4)

        case .open:
            hostTable

        case .searching:
            if link.found.isEmpty {
                ProgressView().tint(Palette.dim)
                Text("Looking for open tables…")
                    .font(.subheadline).foregroundStyle(Palette.dim)
                if nothingInSight {
                    Text("No table in sight.")
                        .font(.headline).foregroundStyle(Palette.lostBright)
                    VStack(alignment: .leading, spacing: 6) {
                        cause("Both devices have to be on **the same Wi-Fi "
                              + "network**. This is by far the commonest cause: "
                              + "one on the router, the other on the guest network, "
                              + "and they cannot see each other.")
                        cause("On the other device: \"Open the table\", and leave "
                              + "its screen awake.")
                        cause("Settings → Privacy & Security → Local Network: "
                              + "Riskelo US turned on, on both.")
                    }
                    .font(.caption).foregroundStyle(Palette.dim)
                } else {
                    Color.clear.frame(height: 1).task {
                        try? await Task.sleep(for: .seconds(20))
                        nothingInSight = true
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(link.found, id: \.self) { pair in
                        Button { link.join(pair) } label: {
                            Label(pair.name, systemImage: "iphone")
                                .font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent).tint(Palette.side(1))
                    }
                }
            }

        case .calling(let name):
            ProgressView().tint(Palette.side(1))
            Text("Connecting to \(name)…").font(.headline).foregroundStyle(Palette.ink)
            Text("If a device asks for permission to use the local network, "
                 + "accept it: without it the link cannot be established.")
                .font(.caption).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)

        case .refused(let name):
            // The commonest failure, and the most silent: the "local network"
            // permission is refused once and never asked for again. The
            // system says nothing, the connection expires quietly, and you
            // are left on the list of devices wondering whether the tap
            // registered. So the cause has to be named and the fix pointed to.
            //
            // The advice changed with the transport. It used to say "turn off
            // Wi-Fi", because the game then required peer-to-peer Wi-Fi and
            // the router only got in the way. It is the reverse now: the
            // router is the normal path, and turning it off is only a last
            // resort when it keeps its own devices apart.
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34)).foregroundStyle(Palette.lostBright)
            Text("The link could not be established")
                .font(.headline).foregroundStyle(Palette.lostBright)
            Text(name.isEmpty
                 ? "The system refused to open the local network."
                 : "\(name) did not answer.")
                .font(.subheadline).foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 7) {
                cause("Both devices have to be on **the same Wi-Fi "
                      + "network** — or both with no network at all, in which case "
                      + "they link up directly.")
                cause("Riskelo US has to be **on screen** on the other device. In "
                      + "the background, or with the screen locked, it stops "
                      + "answering.")
                cause("Settings → Privacy & Security → Local Network: "
                      + "Riskelo US turned on, on both.")
                cause("Some routers forbid two devices from talking to each other. "
                      + "In that case only, **turn Wi-Fi off from Control Center** "
                      + "(the button, not Settings) on both sides: they will link "
                      + "up without going through it.")
            }
            .font(.caption).foregroundStyle(Palette.dim)
            button("Try again", "arrow.clockwise", Palette.side(0)) { link.stop() }

        case .linked(let name):
            // `case .open, .linked where …` does not mean what it looks like
            // it means: the `where` applies only to the second pattern. We
            // split them, so the code reads the way it behaves.
            if link.iAmHost {
                hostTable
            } else {
                waiting(for: name)
            }

        case .notAllowed:
            // This is not a disaster: it is a switch to flip. The first
            // version of this screen announced it in red, hand raised and
            // four paragraphs — enough to worry someone for nothing. One
            // sentence, one button, and off we go.
            Image(systemName: "gearshape.fill")
                .font(.system(size: 30)).foregroundStyle(Palette.dim)
            Text("A permission is missing")
                .font(.headline).foregroundStyle(Palette.ink)
            Text("iOS asks for your consent before a game can see the other "
                 + "devices in the house. Riskelo US does not have it yet.")
                .font(.subheadline).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
            #if os(iOS)
            button("Open Settings", "arrow.up.forward.app", Palette.side(0)) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Text("Privacy & Security → Local Network → Riskelo US")
                .font(.caption2).foregroundStyle(Palette.dim.opacity(0.8))
            #endif
            Button("Try again") { link.stop() }
                .buttonStyle(.bordered).tint(Palette.dim)

        case .lost(let name):
            Image(systemName: "wifi.slash")
                .font(.system(size: 34)).foregroundStyle(Palette.lostBright)
            Text("Link lost with \(name).")
                .font(.subheadline).foregroundStyle(Palette.lostBright)
            button("Try again", "arrow.clockwise", Palette.side(0)) { link.stop() }
        }
    }

    /// What whoever joined sees, between the link and the launch.
    ///
    /// Two failures used to hide behind the spinner: the game arrives but
    /// will not read — the two devices do not have the same version — or
    /// nothing arrives at all. In both cases you waited indefinitely, in
    /// front of a screen that said "waiting for the launch" and was wrong:
    /// there was nothing left to wait for.
    @ViewBuilder private func waiting(for name: String) -> some View {
        if versionMismatch {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34)).foregroundStyle(Palette.lostBright)
            Text("Different versions").font(.headline).foregroundStyle(Palette.lostBright)
            Text("\(name) sent a game this device cannot read. "
                 + "Install the same version of Riskelo US on both, then "
                 + "start again.")
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        } else {
            ProgressView().tint(Palette.held)
            Text("Linked to \(name)").font(.headline).foregroundStyle(Palette.held)
            if silent {
                Text("Nothing came from \(name).")
                    .font(.subheadline).foregroundStyle(Palette.lostBright)
                Text("The link is good: it is the launch that is not arriving. "
                     + "Check that \(name) really tapped \"Start\", and that both "
                     + "devices have the same version of Riskelo US.")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            } else {
                Text("Waiting for the launch…")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .task {
                        try? await Task.sleep(for: .seconds(15))
                        silent = true
                    }
            }
        }
    }

    /// What whoever opened the table sees, while they wait or have not
    /// launched yet.
    @ViewBuilder private var hostTable: some View {
        VStack(spacing: 12) {
            Text(missing > 0
                 ? "Waiting for \(missing) player\(missing > 1 ? "s" : "")…"
                 : "Everyone is here.")
                .font(.headline).foregroundStyle(missing > 0 ? Palette.ink : Palette.held)
            if missing > 0 {
                ProgressView().tint(Palette.dim)
                if nothingInSight {
                    Text("Nobody has turned up. Wi-Fi has to be on at both ends — "
                         + "it is what carries the link, even with no network in "
                         + "common — and Riskelo US allowed on the local network.")
                        .font(.caption).foregroundStyle(Palette.dim)
                        .multilineTextAlignment(.center)
                } else {
                    Color.clear.frame(height: 1).task {
                        try? await Task.sleep(for: .seconds(25))
                        nothingInSight = true
                    }
                }
            }

            VStack(spacing: 6) {
                row(Nickname.current ?? "You", side: 0)
                ForEach(Array(link.linked.enumerated()), id: \.element) { i, pair in
                    row(names[pair] ?? pair.name, side: i + 1)
                }
            }
            Text("On the other devices: \"Join a table\".\n"
                 + "Leave this screen awake until the launch.")
                .font(.caption).foregroundStyle(Palette.dim.opacity(0.85))
                .multilineTextAlignment(.center)

            if missing == 0 {
                button("Start", "flag.fill", Palette.held) { launch() }
            }
        }
    }

    /// One possible cause, in the order it is worth trying them.
    private func cause(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("•")
            Text(.init(text)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ name: String, side: PlayerID) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.side(side)).frame(width: 10, height: 10)
            Text(name).font(.subheadline).foregroundStyle(Palette.ink)
            Spacer()
            Text(Boards.sideName(side)).font(.caption).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private func button(_ title: String, _ icon: String, _ tint: Color,
                        _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(tint)
    }

    /// Whoever joins waits for the game before showing anything at all —
    /// without that they would see a fake game for a beat.
    private func prepare() {
        // Each device says its name on arrival, without waiting to be asked:
        // with four devices, one request per device would be four chances to
        // get lost.
        link.onConnected = { _, pair in
            if let data = Message.hello(name: Nickname.current ?? "").data {
                link.send(data, to: pair)
            }
        }
        link.onReceive = { data, pair in
            switch Message.read(data) {
            case let .message(.hello(name)):
                names[pair] = name.isEmpty ? nil : name

            case let .message(.game(state, seat, number)):
                launched = true
                onReady(GameSession(link: link, hosting: false, game: state,
                                    mySeat: seat, counter: number))

            case .message:
                // A move, before even having the game: there is nothing to be
                // done with it, and above all it is not a disagreement.
                // Everything that was not the game used to be counted as one,
                // and a packet arriving a fraction of a second too early
                // therefore showed "Different versions" to two devices in
                // perfect agreement.
                break

            case .otherDialect, .unreadable:
                versionMismatch = true
            }
        }
    }

    /// The host creates the game and gives each player their seat, in order
    /// of arrival. Each device receives its own, and only its own.
    private func launch() {
        link.closeTable()
        // Each side carries the name of whoever holds it, when they have
        // given themselves one: "Red · Marie". The name leaves with the
        // state, and so all four devices see the same players — this is the
        // only place that composition happens, and the only moment the host
        // knows them all.
        let sides = (0..<playerCount).map { seat -> Player in
            let side = Boards.sideName(seat)
            let chosen = seat == 0 ? Nickname.current
                                   : link.linked.indices.contains(seat - 1)
                                     ? names[link.linked[seat - 1]] : nil
            return Player(id: seat, name: chosen.map { "\(side) · \($0)" } ?? side)
        }
        // The hosting device's memory leaves with the game: both devices then
        // draw the same questions, and whoever joins does not have to know
        // the other's evenings.
        let game = GameState.start(board: board, players: sides, rules: rules,
                                   bank: QuestionBank(seen: QuestionMemory.shared.load()))

        var seats: [Pair: PlayerID] = [:]
        for (i, pair) in link.linked.enumerated() {
            let seat = i + 1
            seats[pair] = seat
            if let data = Message.game(game, yourSeat: seat, number: 0).data {
                link.send(data, to: pair)
            }
        }
        launched = true
        onReady(GameSession(link: link, hosting: true, game: game,
                            mySeat: 0, seats: seats, counter: 0))
    }
}
