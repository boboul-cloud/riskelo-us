//
//  PacksView.swift
//  Riskelo US
//
//  The packs: what you play, and what you buy.
//
//  Choosing themes used to live in "Game settings", and it only half worked
//  there — for a fundamental reason. That screen does not configure the app:
//  it sets up **one** game, and its start button is the only thing that reads
//  what was ticked. A quick game launched from the home screen, a resumed
//  game, a table opened over the network all started from factory values. You
//  unticked a theme, and it came back.
//
//  A pack is not a game setting. It is something you own, that is kept, and
//  that holds for every game until you decide otherwise. Hence this separate
//  page, and its door on the home screen.
//
//  What is chosen here nevertheless leaves **with** the game, in its rules:
//  whoever joins a table plays the host's themes, or the two devices would
//  not ask the same questions.
//

import SwiftUI
import StoreKit

// MARK: - What the device keeps

/// The pack choice, kept from one game to the next.
///
/// In the system preferences and not in a view: it holds for the whole app,
/// like the sound and the nickname, and not for the game currently being set
/// up.
enum Packs {

    static let keyChosen = "riskelo.us.packs.chosen"
    static let keyWithBase = "riskelo.us.packs.base"

    /// The packs ticked, by theme identifier.
    static var chosen: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: keyChosen) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: keyChosen) }
    }

    /// Do we also play the six general-knowledge themes?
    static var withBase: Bool {
        get { UserDefaults.standard.object(forKey: keyWithBase) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyWithBase) }
    }

    /// The themes games must use.
    ///
    /// Never empty: unticking everything would make the game unplayable, and
    /// a game without a question is indistinguishable from a breakdown.
    /// Failing everything, the base game — the one everyone owns.
    static var inPlay: Set<String> {
        var ids = withBase ? Set(Themes.base.map(\.id)) : []
        ids.formUnion(chosen)
        return ids.isEmpty ? Set(Themes.base.map(\.id)) : ids
    }

    /// Sets aside what is no longer owned — a refund, a new device.
    static func forgetWhatWeNoLongerOwn(_ owned: Set<String>) {
        let valid = chosen.filter { id in
            guard let product = Themes.known(Category(id))?.product else { return false }
            return owned.contains(product)
        }
        if valid != chosen { chosen = Set(valid) }
    }
}

// MARK: - The screen

struct PacksView: View {

    var onClose: () -> Void

    @State private var shop = Shop.shared
    @State private var chosen = Packs.chosen
    @State private var withBase = Packs.withBase

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    baseGame
                    ForEach(Themes.packs) { pack in row(pack) }
                    restoreSection
                    summary
                }
                .padding(18)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
        .task {
            await shop.open()
            Packs.forgetWhatWeNoLongerOwn(shop.owned)
            chosen = Packs.chosen
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Label("Home", systemImage: "chevron.left").font(.subheadline)
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer()
            Text("Packs").font(.headline).foregroundStyle(Palette.ink)
            Spacer()
            // A gap the width of the button, so the title is centered on the
            // screen and not on what is left of it.
            Label("Home", systemImage: "chevron.left").font(.subheadline).hidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Palette.panel)
    }

    private var intro: some View {
        Text("A pack is a set of questions added to yours. Tick the ones you want "
             + "to play — one, or several mixed together. The choice holds for all "
             + "your games, and whoever opens the table decides for everyone.")
            .font(.caption).foregroundStyle(Palette.dim)
    }

    // MARK: - The base game

    private var baseGame: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                // You cannot remove everything: with no theme, no question.
                guard !withBase || !chosen.isEmpty else { return }
                withBase.toggle()
                Packs.withBase = withBase
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe.americas")
                        .font(.system(size: 17)).frame(width: 24)
                        .foregroundStyle(withBase ? Palette.side(0) : Palette.dim)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("General knowledge").font(.subheadline.weight(.semibold))
                            .foregroundStyle(withBase ? Palette.ink : Palette.dim)
                        Text("The six themes that ship with the game — \(count(Themes.base)) questions.")
                            .font(.caption2).foregroundStyle(Palette.dim)
                    }
                    Spacer()
                    check(withBase, tint: Palette.side(0))
                }
                .padding(14).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - One pack

    @ViewBuilder private func row(_ pack: Category) -> some View {
        let owned = shop.owns(pack)
        let ticked = owned && chosen.contains(pack.id)
        let tint = Palette.category(pack)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: pack.symbol)
                    .font(.system(size: 17)).frame(width: 24)
                    .foregroundStyle(ticked ? tint : Palette.dim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.label).font(.subheadline.weight(.semibold))
                        .foregroundStyle(ticked ? Palette.ink : Palette.dim)
                    Text(Themes.known(pack)?.detail ?? "")
                        .font(.caption2).foregroundStyle(Palette.dim)
                    Text("\(count([pack])) questions")
                        .font(.caption2.monospacedDigit()).foregroundStyle(Palette.dim)
                }
                Spacer()
                if owned {
                    Button {
                        // The last theme ticked cannot be unticked.
                        if ticked {
                            guard withBase || chosen.count > 1 else { return }
                            chosen.remove(pack.id)
                        } else {
                            chosen.insert(pack.id)
                        }
                        Packs.chosen = chosen
                    } label: {
                        check(ticked, tint: tint)
                    }
                    .buttonStyle(.plain)
                } else {
                    purchaseButton(pack, tint: tint)
                }
            }
        }
        .padding(14)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(ticked ? tint.opacity(0.45) : .clear, lineWidth: 1))
    }

    @ViewBuilder private func purchaseButton(_ pack: Category, tint: Color) -> some View {
        if shop.pending == pack.product {
            ProgressView().controlSize(.small)
        } else if let price = shop.price(pack) {
            Button(price) { Task { await shop.buy(pack) } }
                .buttonStyle(.borderedProminent).tint(tint)
                .font(.subheadline.weight(.semibold))
        } else if shop.hasOpened {
            // The item exists in the game but not in the App Store: that is a
            // configuration mistake, and better said than shown as a button
            // that does nothing.
            Text("unavailable").font(.caption2).foregroundStyle(Palette.dim)
        } else {
            ProgressView().controlSize(.small)
        }
    }

    // MARK: - The foot of the page

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let failure = shop.failure {
                Text(failure).font(.caption).foregroundStyle(Palette.lostBright)
            }
            Button("Restore my purchases") { Task { await shop.restore() } }
                .buttonStyle(.bordered).tint(Palette.dim)
                .font(.subheadline)
            Text("A pack you buy follows you across your devices. Whoever joins your "
                 + "table plays your packs without having to buy them.")
                .font(.caption2).foregroundStyle(Palette.dim)
        }
    }

    private var summary: some View {
        let inPlay = Themes.all.filter { Packs.inPlay.contains($0.id) }
        return Text("\(inPlay.count) theme\(inPlay.count > 1 ? "s" : "") in play — "
                    + "\(count(inPlay)) questions.")
            .font(.caption.weight(.medium)).foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The details

    private func check(_ on: Bool, tint: Color) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20))
            .foregroundStyle(on ? tint : Palette.dim.opacity(0.5))
    }

    private func count(_ themes: [Category]) -> Int {
        let ids = Set(themes.map(\.id))
        return QuestionBank.all.filter { ids.contains($0.category.id) }.count
    }
}
