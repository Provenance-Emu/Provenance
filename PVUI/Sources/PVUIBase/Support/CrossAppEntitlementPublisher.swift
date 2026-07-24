//
//  CrossAppEntitlementPublisher.swift
//  PVUIBase
//
//  Publishes "Provenance Plus owned" into a shared same-team keychain access
//  group so sibling apps can honor it — concretely: a Plus purchase unlocks
//  iFly Pro. Contract (mirrored in iFly's CrossAppEntitlement.swift and
//  documented in iFly's docs/dev/ecosystem-protocol.md):
//
//    access group: $(AppIdentifierPrefix)com.joemattiello.shared
//    service:      "com.joemattiello.shared.entitlements"
//    account:      "provenance.plus"
//    value (v1 JSON): {"v":1,"period":"monthly|yearly|lifetime",
//                      "status":"active","expiresAt":<unix secs, absent=lifetime>,
//                      "updatedAt":<unix secs>}
//      A lapsed monthly/yearly Plus MUST NOT grant iFly Pro forever, so we
//      publish the StoreKit expiry; iFly self-expires it (+7d grace) even if
//      Provenance is never reopened. Legacy readers still accept the bare
//      string "active" (treated as lifetime); we fall back to it only if JSON
//      encoding fails.
//
//  Requires the `keychain-access-groups` entitlement to include the shared
//  group (added to the -AppStore entitlements alongside this file). Writes
//  are best-effort: a keychain failure only costs the cross-app perk.
//
//  Whether Plus is owned comes from FreemiumKit (`purchasedTier`); the
//  period/expiry in the payload come from StoreKit `currentEntitlements`.
//  Mirrored at launch (twice — the second pass catches StoreKit's async
//  entitlement load) and on every foreground.
//

import Foundation
import Security
import StoreKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif

public enum CrossAppEntitlementPublisher {
    private static let accessGroupSuffix = "com.joemattiello.shared"
    private static let service = "com.joemattiello.shared.entitlements"
    private static let account = "provenance.plus"
    private static let activeValue = "active"

    /// Mirror the current Plus state into the shared keychain. Call at app
    /// launch and on foreground; safe to call repeatedly.
    @MainActor
    public static func publishPlusState() {
        #if canImport(FreemiumKit)
        let active = FreemiumKit.shared.purchasedTier != nil
        #else
        let active = false
        #endif
        if active {
            Task { await writeActivePlusMirror() }
        } else {
            delete()
        }
    }

    /// Launch-time convenience: publish now, then once more after StoreKit's
    /// async entitlement load has had time to settle.
    @MainActor
    public static func publishPlusStateAtLaunch() {
        publishPlusState()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            publishPlusState()
        }
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

    /// Encode the owned Plus entitlement as v1 JSON and write it. Period and
    /// expiry come from StoreKit so a lapsed subscription self-expires on the
    /// reader side even if Provenance is never reopened.
    private static func writeActivePlusMirror() async {
        let entitlement = await currentPlusEntitlement()
        let mirror = Mirror(period: entitlement?.period,
                            status: "active",
                            expiresAt: entitlement?.expiresAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(mirror),
           let json = String(data: data, encoding: .utf8) {
            write(json)
        } else {
            write(activeValue)   // degraded v0 fallback (reader treats as lifetime)
        }
    }

    /// The active Provenance Plus entitlement from StoreKit, if any: its period
    /// and expiry (nil expiry = lifetime, or FreemiumKit-only state with no
    /// matching StoreKit transaction — e.g. a promotional/dev grant).
    private static func currentPlusEntitlement() async -> (period: String?, expiresAt: Date?)? {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID.hasPrefix("provenance.plus") else { continue }
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

    // MARK: - Keychain plumbing (mirrors iFly's CrossAppEntitlement)

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

    private static func write(_ value: String) {
        guard let group = sharedGroup else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group
        ]
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

    private static func delete() {
        guard let group = sharedGroup else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group
        ]
        SecItemDelete(query as CFDictionary)
    }
}
