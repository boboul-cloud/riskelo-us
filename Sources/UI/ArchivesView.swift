//
//  ArchivesView.swift
//  Riskelo US
//
//  The library: past games, and the moments you can go back to.
//
//  Two levels, not one. The list of games reads like a shelf — the board, the
//  mode, the date, against whom — and you only open a game's moments once you
//  have chosen which game. Laying it all out flat would have given five
//  hundred indistinguishable rows.
//
//  Each moment shows the balance of power it had, in side colors. That is
//  what lets you find "the moment it turned" without opening the positions
//  one by one.
//

import SwiftUI

struct ArchivesView: View {

    var onOpen: (GameState) -> Void
    var onClose: () -> Void

    @State private var games: [ArchivedGame] = []
    @State private var opened: ArchivedGame?
    @State private var unreadable = false

    var body: some View {
        // The bar sits in the safe-area inset rather than stacked: that is
        // what the system expects, and the content scrolls under it cleanly.
        //
        // The content is bounded in width — otherwise it would spread out on
        // a Mac — while the bar takes the whole screen.
        content
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(Palette.sea)
        .onAppear { games = Archives.shared.list() }
        .alert("This moment will no longer read back",
               isPresented: $unreadable) {
            Button("OK") { }
        } message: {
            Text("It was saved on a board whose drawing has changed since.")
        }
    }

    @ViewBuilder private var content: some View {
        if games.isEmpty {
            empty
        } else if let p = opened {
            moments(of: p)
        } else {
            shelf
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                if opened != nil { withAnimation { opened = nil } } else { onClose() }
            } label: {
                Label(opened == nil ? "Close" : "All games",
                      systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer(minLength: 12)
        }
        // The title as an overlay rather than between two spacers: it stays
        // centered on the bar whatever the length of the left-hand button.
        .overlay {
            Text(opened == nil ? "Saved games" : "Go back to a moment")
                .font(.headline).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.panel)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40)).foregroundStyle(Palette.dim)
            Text("No games shelved yet.")
                .font(.headline).foregroundStyle(Palette.ink)
            Text("Every turn played drops a moment here, on its own.")
                .font(.footnote).foregroundStyle(Palette.dim)
        }
        .multilineTextAlignment(.center)
        .frame(maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - The shelf

    private var shelf: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(games) { p in
                    Button { withAnimation { opened = p } } label: { row(p) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func row(_ p: ArchivedGame) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(p.board.label).font(.headline).foregroundStyle(Palette.ink)
                    Text("· \(p.mode.label)").font(.caption).foregroundStyle(Palette.dim)
                }
                HStack(spacing: 6) {
                    ForEach(Array(p.players.enumerated()), id: \.offset) { i, name in
                        Text(name + (p.bots.contains(i) ? " ⌘" : ""))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Palette.side(i).opacity(0.28), in: Capsule())
                            .foregroundStyle(Palette.side(i))
                    }
                }
                Text(status(p)).font(.caption).foregroundStyle(Palette.dim)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Text(p.last.formatted(.dateTime.day().month(.abbreviated)
                                          .hour().minute()))
                    .font(.caption2).foregroundStyle(Palette.dim)
                Button {
                    Archives.shared.delete(p.id)
                    withAnimation { games = Archives.shared.list() }
                } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(Palette.dim.opacity(0.7))
            }
        }
        .padding(14)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private func status(_ p: ArchivedGame) -> String {
        let n = p.moments.count
        let moments = "\(n) moment\(n > 1 ? "s" : "")"
        if let w = p.winner, w < p.players.count {
            return "\(p.players[w]) won · \(moments)"
        }
        return "Broken off on turn \(p.moments.last?.turn ?? 1) · \(moments)"
    }

    // MARK: - The moments of one game

    private func moments(of p: ArchivedGame) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Choosing a moment resumes the game from there without "
                     + "erasing this one: what you play next is shelved separately.")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)

                ForEach(p.moments.reversed()) { m in
                    Button {
                        if let g = Archives.shared.load(m) { onOpen(g) } else { unreadable = true }
                    } label: { moment(m, of: p) }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func moment(_ m: ArchivedGame.Moment, of p: ArchivedGame) -> some View {
        let total = max(1, m.territories.reduce(0, +))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if m.marked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2).foregroundStyle(Palette.held)
                } else {
                    Circle().fill(Palette.side(m.side)).frame(width: 8, height: 8)
                }
                Text(m.label).font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(m.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2).foregroundStyle(Palette.dim)
            }
            // The balance of power, in one bar: that is what makes you
            // recognize the moment you are looking for.
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(Array(m.territories.enumerated()), id: \.offset) { i, n in
                        if n > 0 {
                            Capsule().fill(Palette.side(i))
                                .frame(width: max(3, g.size.width * Double(n) / Double(total)))
                        }
                    }
                }
            }
            .frame(height: 6)
            HStack(spacing: 8) {
                ForEach(Array(m.territories.enumerated()), id: \.offset) { i, n in
                    Text("\(p.players.indices.contains(i) ? p.players[i] : "?") \(n)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.side(i))
                }
            }
        }
        .padding(13)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
    }
}
