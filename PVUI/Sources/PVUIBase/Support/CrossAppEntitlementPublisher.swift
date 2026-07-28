//
//  CrossAppEntitlementPublisher.swift
//  PVUIBase
//
//  Two-way cross-app entitlement bridge over a shared same-team keychain
//  access group, so a purchase in one of Joe's apps unlocks the sibling app's
//  premium tier. No server, works offline, survives reinstalls.
//
//  Contract (mirrored in iFly's CrossAppEntitlement.swift and documented in
//  iFly's docs/dev/ecosystem-protocol.md):
//
//    access group: $(AppIdentifierPrefix)com.joemattiello.shared
//    service:      "com.joemattiello.shared.entitlements"
//    accounts:     "provenance.plus"  (written by Provenance, read by iFly)
//                  "ifly.pro"         (written by iFly, read by Provenance)
//    value (v1 JSON): {"v":1,"period":"monthly|yearly|lifetime",
//                      "status":"active","expiresAt":<unix secs, absent=lifetime>,
//                      "updatedAt":<unix secs>}
//      A lapsed monthly/yearly entitlement MUST NOT grant the sibling app's
//      premium forever, so the seller-of-record publishes the StoreKit expiry
//      and the READER self-expires it (+7d renewal grace) even if the selling
//      app is never reopened. Legacy readers/writers still accept the bare
//      string "active" (treated as lifetime); we emit it only if JSON encoding
//      fails.
//
//  Requires the `keychain-access-groups` entitlement to include the shared
//  group (added to the -AppStore entitlements alongside this file). Keychain
//  access is best-effort: a failure only costs the cross-app perk.
//
//  This file holds both halves:
//    * `CrossAppEntitlementPublisher` — publishes `provenance.plus`.
//      Ownership comes from FreemiumKit (`purchasedTier`); the period/expiry in
//      the payload come from StoreKit `currentEntitlements`. Mirrored at launch
//      (twice — the second pass catches StoreKit's async entitlement load) and
//      on every foreground. Deletes are deferred until that load settles so a
//      short launch can't clear a real owner's mirror.
//    * `CrossAppEntitlementReader` — reads `ifly.pro` and, when it grants,
//      unlocks Provenance Plus via FreemiumKit's tier override so every
//      existing Plus gate (`PaidFeatureView`, `PaidStatusView`, `purchasedTier`
//      checks) honors it with no per-gate changes.
//
//  Trust model: any same-team binary can write these items — exactly the
//  boundary we want (only Joe's apps sign with this team).
//

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

    /// Mirror the current Plus state into the shared keychain. Call at app
    /// launch and on foreground; safe to call repeatedly.
    @MainActor
    public static func publishPlusState() {
        #if canImport(FreemiumKit)
        let tierOwned = FreemiumKit.shared.purchasedTier != nil
        #else
        let tierOwned = false
        #endif
        let siblingGranted = CrossAppEntitlementReader.didGrantPlusFromSibling
        let allowClear = storeKitSettled
        Task { await mirrorPlusState(tierOwned: tierOwned, siblingGranted: siblingGranted, allowClear: allowClear) }
    }

    /// Launch-time convenience: publish now, then once more after StoreKit's
    /// async entitlement load has had time to settle.
    @MainActor
    public static func publishPlusStateAtLaunch() {
        publishPlusState()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: storeKitSettleDelay)
            storeKitSettled = true
            publishPlusState()
        }
    }

    /// How long to wait for StoreKit's async `currentEntitlements` load before
    /// the catch-up publish pass.
    private static let storeKitSettleDelay: UInt64 = 8_000_000_000

    /// Flipped by the delayed launch pass once FreemiumKit/StoreKit have had
    /// time to load. Until then `mirrorPlusState` must never DELETE the shared
    /// item: `purchasedTier` is nil while StoreKit is still loading, so a
    /// launch shorter than the settle delay would clear a real owner's mirror
    /// and silently break the sibling crossover until the next long run.
    /// Writes are always allowed — a positive ownership signal is trustworthy
    /// at any time.
    @MainActor
    private static var storeKitSettled = false

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

    /// Write (or clear) the shared `provenance.plus` item.
    ///
    /// `tierOwned` is FreemiumKit's view of Plus. When we granted Plus
    /// ourselves off a sibling app's `ifly.pro` mirror, FreemiumKit's tier is
    /// *contaminated by that grant* — republishing it would loop iFly Pro
    /// straight back out as Provenance Plus and grant it forever. In that case
    /// StoreKit's `currentEntitlements` is the only uncontaminated ownership
    /// signal, so a real purchase still publishes and a pure cross-app grant
    /// does not. We deliberately do NOT gate on the grant latch alone: at
    /// launch `purchasedTier` is nil until StoreKit finishes loading, so a user
    /// who owns both would otherwise never publish their real Plus.
    ///
    /// `allowClear` gates the delete paths on StoreKit having settled (see
    /// `storeKitSettled`): a "not owned" verdict computed before the async
    /// entitlement load finishes is not evidence of non-ownership, so acting
    /// on it would poison a valid mirror. Positive publishes are never gated.
    private static func mirrorPlusState(tierOwned: Bool, siblingGranted: Bool, allowClear: Bool) async {
        // Cheap path for free users: nothing can make `owned` true below, so
        // don't spin up a StoreKit entitlement query on every foreground.
        guard tierOwned || siblingGranted else {
            if allowClear { SharedEntitlementKeychain.delete(account: account) }
            return
        }
        let entitlement = await currentPlusEntitlement()
        let owned = siblingGranted ? (entitlement != nil) : tierOwned
        guard owned else {
            if allowClear { SharedEntitlementKeychain.delete(account: account) }
            return
        }
        let mirror = Mirror(period: entitlement?.period,
                            status: "active",
                            expiresAt: entitlement?.expiresAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(mirror),
           let json = String(data: data, encoding: .utf8) {
            SharedEntitlementKeychain.write(account: account, value: json)
        } else {
            // Degraded v0 fallback (reader treats it as lifetime).
            SharedEntitlementKeychain.write(account: account,
                                            value: SharedEntitlementKeychain.activeValue)
        }
    }

    /// The active Provenance Plus entitlement from StoreKit, if any: its period
    /// and expiry (nil expiry = lifetime, or FreemiumKit-only state with no
    /// matching StoreKit transaction — e.g. a promotional/dev grant).
    private static func currentPlusEntitlement() async -> (period: String?, expiresAt: Date?)? {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID.hasPrefix(plusProductIDPrefix) else { continue }
            return (period(forProductID: transaction.productID), transaction.expirationDate)
        }
        return nil
    }

    /// Derive the subscription period from the product identifier, e.g.
    /// `provenance.plus.monthly1`, `provenance.plus.annually.lite1`,
    /// `provenance.plus.lifetime1`.
    private static func period(forProductID id: String) -> String? {
        if id.contains("lifetime") { return "lifetime" }
        if id.contains("monthly") { return "monthly" }
        if id.contains("annually") || id.contains("yearly") { return "yearly" }
        return nil
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

    /// True once we've unlocked Plus off a sibling app's mirror this launch.
    /// Read by `CrossAppEntitlementPublisher` to avoid mirroring a tier it
    /// granted itself, and by `PlusEntitlement.isUnlocked`. Main-thread only.
    public private(set) static var didGrantPlusFromSibling = false

    /// v1 mirror payload (see the file header contract). `expiresAt` nil = lifetime.
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
        guard grantingStatuses.contains(mirror.status) else { return false }
        guard let expiresAt = mirror.expiresAt else { return true }   // lifetime
        return now < expiresAt.addingTimeInterval(renewalGrace)
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
    /// We never pass `nil` to clear the override: it's undocumented whether
    /// that restores the real tier or forces "no tier" (which would clobber a
    /// real purchase). Revocation therefore takes effect on the next launch,
    /// where the grant simply isn't re-applied.
    @MainActor
    public static func applySiblingGrantIfNeeded() {
        #if canImport(FreemiumKit)
        guard !didGrantPlusFromSibling else { return }
        // Already Plus (real purchase, promo, or a dev/sideload override) —
        // nothing to grant, and overriding would contaminate the publisher.
        guard FreemiumKit.shared.purchasedTier == nil else { return }
        guard iFlyProActive else { return }
        didGrantPlusFromSibling = true
        FreemiumKit.shared.overrideForDebug(purchasedTier: plusTier)
        ILOG("CrossAppEntitlement: active iFly Pro found — unlocking Provenance Plus")
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
}
