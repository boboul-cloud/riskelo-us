//
//  Shop.swift
//  Riskelo US
//
//  The packs that are bought, and what the device owns.
//
//  A pack is a question theme sold separately. Its file is inside the app, on
//  every device: what is bought is not the content, it is the right to
//  **choose** it. Two reasons, and the second counts more than the first.
//
//  There is nothing to download — four hundred questions weigh fifty
//  kilobytes, less than a photograph. A server, a download and a network
//  failure for that would be three troubles for nothing.
//
//  And above all: whoever joins a table plays the host's themes. If the pack
//  were not already there, it would have to be sent to them in the middle of
//  the game, or they would have to be refused the table. As it is, the host
//  buys and everyone plays — which is the best advertising a pack can have.
//
//  To try it without creating anything at Apple:
//  "Resources/RiskeloUS.storekit" is a desktop App Store, attached to the
//  scheme. You can buy there, restore, cancel and get refunded, and nothing
//  is charged. The real items will be created in App Store Connect under the
//  same identifiers.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class Shop {

    static let shared = Shop()

    /// The items as the App Store describes them — name and price included,
    /// in the currency of whoever is looking. A price is never written in
    /// code.
    private(set) var items: [String: Product] = [:]

    /// What this device has bought.
    private(set) var owned: Set<String> = []

    /// The purchase in progress, so the button knows it is waiting.
    private(set) var pending: String?

    /// What went wrong, in one showable sentence.
    private(set) var failure: String?

    /// Has the shop answered at least once?
    private(set) var hasOpened = false

    private var watch: Task<Void, Never>?

    private init() {
        // A purchase can arrive without going through our buttons: a restore,
        // family sharing, a purchase started on another device. Without this
        // watch, you would have to relaunch the app to see it.
        watch = Task { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(t) = result else { continue }
                await t.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    // MARK: - What the screen asks for

    func open() async {
        await loadItems()
        await refreshEntitlements()
        hasOpened = true
    }

    /// Is this theme playable here? A theme with no price belongs to
    /// everyone.
    func owns(_ c: Category) -> Bool {
        guard let product = c.product else { return true }
        return owned.contains(product)
    }

    func price(_ c: Category) -> String? {
        guard let product = c.product else { return nil }
        return items[product]?.displayPrice
    }

    func buy(_ c: Category) async {
        guard let id = c.product, let item = items[id] else {
            failure = "This item is not available."
            return
        }
        pending = id
        failure = nil
        defer { pending = nil }
        do {
            switch try await item.purchase() {
            case let .success(verification):
                guard case let .verified(t) = verification else {
                    failure = "The purchase could not be verified."
                    return
                }
                await t.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                // "Ask to Buy": a parent has to approve. It is neither a
                // failure nor a purchase, and the screen has to say so.
                failure = "The purchase is waiting for approval."
            @unknown default:
                break
            }
        } catch {
            failure = "The purchase did not go through."
        }
    }

    /// Apple requires it, and it is useful: a new device, a reinstall.
    func restore() async {
        failure = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            failure = "The restore did not go through."
        }
    }

    // MARK: - The App Store

    private func loadItems() async {
        let ids = Themes.packs.compactMap(\.product)
        guard !ids.isEmpty else { return }
        do {
            let found = try await Product.products(for: ids)
            items = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
            // An item declared by a theme but absent from the App Store gets
            // said, and brings nothing down.
            //
            // It used to be an `assertionFailure`, and it did exactly what it
            // should not have: the app launched outside Xcode does not have
            // the StoreKit test file — it is attached to the scheme — so no
            // items, so a hard stop on opening the page. A shop that does not
            // answer is an ordinary incident, on a par with a cut network,
            // and the screen already knows how to show it.
            let missing = Set(ids).subtracting(items.keys)
            if !missing.isEmpty {
                FileHandle.standardError.write(
                    Data("Riskelo US — items not found: \(missing.sorted())\n".utf8))
            }
        } catch {
            failure = "The shop did not answer."
        }
    }

    private func refreshEntitlements() async {
        var granted: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case let .verified(t) = result else { continue }
            // A refunded purchase is withdrawn.
            if t.revocationDate == nil { granted.insert(t.productID) }
        }
        owned = granted
    }
}
