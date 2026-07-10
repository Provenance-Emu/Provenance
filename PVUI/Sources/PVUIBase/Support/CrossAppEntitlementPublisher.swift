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
//    account:      "provenance.plus"  → value "active" while Plus is owned
//
//  Requires the `keychain-access-groups` entitlement to include the shared
//  group (added to the -AppStore entitlements alongside this file). Writes
//  are best-effort: a keychain failure only costs the cross-app perk.
//
//  Plus itself is FreemiumKit-managed (no purchase hooks exposed in-repo),
//  so this mirrors `FreemiumKit.shared.purchasedTier` at launch (twice — the
//  second pass catches StoreKit's async entitlement load) and on every
//  foreground.
//

import Foundation
import Security
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
            write(activeValue)
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
