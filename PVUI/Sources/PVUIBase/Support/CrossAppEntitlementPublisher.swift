// Same-device, same-team Plus recognition. This bridge is not a cross-device
// restore service: keychain items are not synchronizable, and StoreKit only
// supplies purchases for the purchasing app.
//
// Shared contract with iFly and iCube:
// group $(AppIdentifierPrefix)com.joemattiello.shared
// service com.joemattiello.shared.entitlements
// seller-owned accounts provenance.plus / ifly.pro
// v1 JSON: v, period (monthly/yearly/lifetime), status (active/grace/expired),
// expiresAt (Unix seconds, required for subscriptions, absent for lifetime),
// updatedAt (Unix seconds). Legacy bare "active" remains supported.
// Readers preserve the existing seven-day subscription renewal grace.
// Only verified direct StoreKit ownership is published: sibling and debug
// grants never become independent lifetime ownership. Completion of the
// StoreKit sequence settles loading; no fixed launch timer clears ownership.

import Foundation
import Security
import StoreKit
import PVLogging
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - Shared keychain plumbing

/// Generic-password plumbing for the shared same-team entitlement items.
/// File-scope `private` so the publisher and the reader below share a single
/// team-prefix probe (mirrors iFly's `CrossAppEntitlement` plumbing verbatim).
private enum SharedEntitlementKeychain {
    static let service = "com.joemattiello.shared.entitlements"
    /// Legacy v0 payload: the bare string, treated as an active lifetime grant.
    static let activeValue = "active"

    private static let accessGroupSuffix = "com.joemattiello.shared"

    /// The shared group needs the team-ID prefix, which isn't in Info.plist.
    /// Standard trick: add (or find) a probe item in the app's DEFAULT group
    /// ("<TEAMID>.<bundle id>") and read the prefix off its access group.
    private static let teamPrefix: String? = {
        let probeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "org.provenance-emu.team-probe",
            kSecAttrAccount as String: "probe",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(probeQuery as CFDictionary, &result)
        if status == errSecItemNotFound {
            var addQuery = probeQuery
            addQuery.removeValue(forKey: kSecReturnAttributes as String)
            addQuery.removeValue(forKey: kSecMatchLimit as String)
            addQuery[kSecValueData as String] = Data("probe".utf8)
            addQuery[kSecReturnAttributes as String] = true
            status = SecItemAdd(addQuery as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attrs = result as? [String: Any],
              let group = attrs[kSecAttrAccessGroup as String] as? String,
              let dot = group.firstIndex(of: ".") else { return nil }
        return String(group[..<dot])
    }()

    private static var sharedGroup: String? {
        teamPrefix.map { "\($0).\(accessGroupSuffix)" }
    }

    private static func baseQuery(account: String, group: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group
        ]
    }

    static func read(account: String) -> String? {
        guard let group = sharedGroup else { return nil }
        var query = baseQuery(account: account, group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(account: String, value: String) {
        guard let group = sharedGroup else { return }
        let base = baseQuery(account: account, group: group)
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func delete(account: String) {
        guard let group = sharedGroup else { return }
        SecItemDelete(baseQuery(account: account, group: group) as CFDictionary)
    }
}

// MARK: - Publisher (Provenance Plus → siblings)

public enum CrossAppEntitlementPublisher {
    private static let account = "provenance.plus"
    /// StoreKit product identifiers for Plus all share this prefix.
    private static let plusProductIDPrefix = "provenance.plus"

    /// Refresh direct verified ownership before publishing. Completion of the
    /// StoreKit sequence, rather than a fixed launch delay, settles ownership.
    @MainActor
    public static func publishPlusState() {
        if reconciliationTask == nil {
            reconciliationTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    guard !Task.isCancelled else { return }
                    await refresh()
                }
            }
        }
        if updatesTask == nil {
            updatesTask = Task {
                for await result in StoreKit.Transaction.updates {
                    guard case .verified(let transaction) = result,
                          transaction.productID.hasPrefix(plusProductIDPrefix) else { continue }
                    await refresh()
                }
            }
        }
        Task { await refresh() }
    }

    @MainActor
    public static func publishPlusStateAtLaunch() { publishPlusState() }

    @MainActor
    private static var updatesTask: Task<Void, Never>?
    @MainActor
    private static var reconciliationTask: Task<Void, Never>?

    public private(set) static var storeKitSettled = false

    @MainActor
    public static func refresh() async {
        CloudSyncUpsellView.reconcileFreeSyncScope()
        let entitlement = await currentPlusEntitlement()
        if let entitlement {
            let mirror = Mirror(period: entitlement.period, status: "active", expiresAt: entitlement.expiresAt)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            if let data = try? encoder.encode(mirror), let value = String(data: data, encoding: .utf8) {
                SharedEntitlementKeychain.write(account: account, value: value)
            }
        } else {
            SharedEntitlementKeychain.delete(account: account)
        }
        storeKitSettled = true
        CrossAppEntitlementReader.applySiblingGrantIfNeeded(directlyOwned: entitlement != nil)
        CloudSyncUpsellView.reconcileFreeSyncScope()
    }

    // MARK: - v1 mirror payload

    /// v1 status payload iFly decodes (JSON, dates = unix seconds). Field
    /// names/types mirror iFly's `CrossAppEntitlement.Mirror` exactly.
    private struct Mirror: Encodable {
        var v: Int = 1
        var period: String?          // "monthly" | "yearly" | "lifetime"
        var status: String           // "active" | "grace" | "expired"
        var expiresAt: Date?         // nil = lifetime / none
        var updatedAt: Date = Date()
    }

    /// Only verified, unrevoked matching transactions may be published. A
    /// debug/promo tier or a sibling mirror is not an independent purchase.
    private static func currentPlusEntitlement() async -> (period: String, expiresAt: Date?)? {
        var best: (period: String, expiresAt: Date?)?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  transaction.productID.hasPrefix(plusProductIDPrefix),
                  let period = period(forProductID: transaction.productID) else { continue }
            if period == "lifetime", transaction.expirationDate == nil { return (period, nil) }
            guard let expiry = transaction.expirationDate, expiry.addingTimeInterval(CrossAppEntitlementReader.renewalGrace) > Date() else { continue }
            if best == nil || expiry > (best?.expiresAt ?? .distantPast) { best = (period, expiry) }
        }
        return best
    }

    /// Derive the subscription period from the product identifier, e.g.
    /// `provenance.plus.monthly1`, `provenance.plus.annually.lite1`,
    /// `provenance.plus.lifetime1`.
    private static func period(forProductID id: String) -> String? {
        switch id {
        case "provenance.plus.lifetime1": return "lifetime"
        case "provenance.plus.monthly1", "provenance.plus.monthly.lite1": return "monthly"
        case "provenance.plus.annually1", "provenance.plus.annually.lite1": return "yearly"
        default: return nil
        }
    }
}

// MARK: - Reader (iFly Pro → Provenance Plus)

/// Reads the sibling `ifly.pro` mirror and, when it grants, unlocks Provenance
/// Plus. The reverse of `CrossAppEntitlementPublisher`; the status/expiry rules
/// match iFly's reader exactly so both directions decay identically.
public enum CrossAppEntitlementReader {
    private static let iFlyProAccount = "ifly.pro"

    /// FreemiumKit tier that corresponds to Provenance Plus.
    private static let plusTier = 1

    /// Slack past `expiresAt` before a subscription mirror stops counting —
    /// covers the renewal window when the selling app hasn't re-mirrored yet.
    static let renewalGrace: TimeInterval = 7 * 24 * 60 * 60

    /// Statuses that still confer the entitlement (subject to expiry below).
    private static let grantingStatuses: Set<String> = ["active", "grace"]

    /// True while an active sibling mirror supplies the tier override.
    /// Read by `CrossAppEntitlementPublisher` to avoid mirroring a tier it
    /// granted itself, and by `PlusEntitlement.isUnlocked`. Main-thread only.
    public private(set) static var didGrantPlusFromSibling = false

    /// v1 mirror payload; only an explicit lifetime period may omit expiry.
    struct Mirror: Decodable {
        var v: Int
        var period: String?          // "monthly" | "yearly" | "lifetime"
        var status: String           // "active" | "grace" | "expired"
        var expiresAt: Date?
        var updatedAt: Date
    }

    /// Decode a raw shared-keychain value. The legacy v0 bare string is
    /// upgraded to an active lifetime mirror; anything unparseable is `nil`.
    static func decode(_ raw: String) -> Mirror? {
        if raw == SharedEntitlementKeychain.activeValue {
            return Mirror(v: 0, period: "lifetime", status: "active", expiresAt: nil, updatedAt: Date())
        }
        guard let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Mirror.self, from: data)
    }

    /// Does this raw mirror value grant the entitlement as of `now`?
    ///
    /// Status-aware: the mirror must say active/grace AND (for subscriptions)
    /// be within expiry + renewal grace — enforced HERE so a stale mirror
    /// decays even if the selling app never runs again (uninstalled, or lapsed
    /// while Provenance is the only app in use). Pure: `now` is injected so the
    /// grace window is testable.
    static func grantsPlus(rawValue: String?, now: Date) -> Bool {
        guard let rawValue, let mirror = decode(rawValue) else { return false }
        guard mirror.v == 0 || mirror.v == 1, grantingStatuses.contains(mirror.status) else { return false }
        switch mirror.period {
        case "lifetime": return mirror.expiresAt == nil
        case "monthly", "yearly":
            guard let expiry = mirror.expiresAt else { return false }
            return now < expiry.addingTimeInterval(renewalGrace)
        default: return false
        }
    }

    /// Is there a currently-granting `ifly.pro` mirror in the shared keychain?
    public static var iFlyProActive: Bool {
        grantsPlus(rawValue: SharedEntitlementKeychain.read(account: iFlyProAccount), now: Date())
    }

    /// Unlock Provenance Plus if the sibling `ifly.pro` mirror grants it.
    /// Call at launch and on foreground (the user may buy Pro in iFly while
    /// Provenance is backgrounded); idempotent and cheap after the first grant.
    ///
    /// Integration point: FreemiumKit's tier override. Provenance already ships
    /// this exact call for non-App-Store builds (`ProvenanceApp.onAppear`), and
    /// it's the only hook that makes *every* Plus gate honor the grant —
    /// `PaidFeatureView` / `PaidStatusView` read FreemiumKit-internal state and
    /// can't be routed through an app-level accessor.
    ///
    /// Reconcile a previous sibling override against the completed direct
    /// ownership snapshot so expiry/refunds do not leave a sticky grant.
    @MainActor
    public static func applySiblingGrantIfNeeded(directlyOwned: Bool = false) {
        #if canImport(FreemiumKit)
        let active = iFlyProActive
        if didGrantPlusFromSibling {
            // Both interpretations of override(nil) are safe after a completed
            // direct StoreKit snapshot: restore a real purchase explicitly.
            FreemiumKit.shared.overrideForDebug(purchasedTier: directlyOwned || active ? plusTier : nil)
            didGrantPlusFromSibling = active && !directlyOwned
        } else if active && !directlyOwned && FreemiumKit.shared.purchasedTier == nil {
            didGrantPlusFromSibling = true
            FreemiumKit.shared.overrideForDebug(purchasedTier: plusTier)
        }
        #endif
    }
}

// MARK: - App-level Plus accessor

/// Single answer to "does this user have Provenance Plus?" for app code that
/// checks the tier directly instead of wrapping UI in `PaidFeatureView`.
///
/// ORs FreemiumKit's state with the cross-app grant. The grant is also pushed
/// into FreemiumKit itself (see `applySiblingGrantIfNeeded`), so this is belt
/// and braces — it keeps explicit gates correct even if the tier override is
/// ever ignored.
public enum PlusEntitlement {
    /// Reads the cached grant latch, not the keychain — safe to call from a
    /// SwiftUI `body`.
    public static var isUnlocked: Bool {
        #if canImport(FreemiumKit)
        if FreemiumKit.shared.purchasedTier != nil { return true }
        return CrossAppEntitlementReader.didGrantPlusFromSibling
        #else
        return false
        #endif
    }

    /// True once StoreKit entitlements have actually loaded (or the grant
    /// latch already says Plus). `isUnlocked` is false during the async
    /// StoreKit load window on cold launch, so destructive "not premium"
    /// decisions (e.g. force-disabling iCloud sync) MUST wait for this or
    /// they punish real subscribers.
    public static var isSettled: Bool {
        #if canImport(FreemiumKit)
        return CrossAppEntitlementPublisher.storeKitSettled || FreemiumKit.shared.purchasesLoaded || isUnlocked
        #else
        return true
        #endif
    }
}
