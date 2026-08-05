//
//  iCloudConstants.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import CloudKit
#if os(macOS) || targetEnvironment(macCatalyst)
import Security
#endif
#if targetEnvironment(simulator)
/// For `_dyld_get_image_header` / `getsectiondata` — used to read the entitlements
/// blob the linker embeds in simulator builds.
import MachO
#endif
import PVLogging

public enum iCloudConstants {
    // MARK: - Container identifiers

    public static let defaultProvenanceContainerIdentifier = "iCloud.org.provenance-emu.provenance"
    public static let devContainerIdentifier = "iCloud.org.provenance-emu.provenance.dev"

    /// Primary container identifier — reads NSUbiquitousContainers from Info.plist so sideloaded
    /// apps that remap the bundle ID (Sideloadly, Feather, AltStore) get the correct container.
    /// In DEBUG builds, defaults to the dev container.
    public static let containerIdentifier: String = {
        if let plistID = (Bundle.main.infoDictionary?["NSUbiquitousContainers"] as? [String: AnyObject])?.keys.first {
            return plistID
        }
        #if DEBUG
        return devContainerIdentifier
        #else
        return defaultProvenanceContainerIdentifier
        #endif
    }()

    // MARK: - Entitlement check

    /// Returns true if the running binary's code signature includes the CloudKit container
    /// entitlement, without triggering CloudKit framework initialization.
    ///
    /// - macOS / Catalyst: uses `SecTaskCopyValueForEntitlement` (reads live code signature).
    /// - iOS / tvOS device: parses `embedded.mobileprovision` when present (sideloaded /
    ///   AdHoc / TestFlight). App Store builds strip the provisioning profile, so absence
    ///   of the file is treated as "entitlement present" (App Store validation guarantees it).
    /// - Simulator: uses `FileManager.ubiquityIdentityToken`, which is nil without the
    ///   ubiquity entitlement. Simulator builds carry no `embedded.mobileprovision` *and*
    ///   may carry no entitlements at all, so nothing may be assumed here — and the
    ///   macOS `SecTask*` path is unavailable (that header ships only in the macOS SDK).
    public static let isCloudKitEntitlementPresent: Bool = {
        #if targetEnvironment(simulator)
        // `NSUbiquitousContainers` is an Info.plist *declaration*, not an entitlement.
        // It is always present in this bundle, so keying off it returned true even for
        // simulator builds signed without entitlements (CI's CODE_SIGNING_ALLOWED=NO,
        // ad-hoc re-signs, screenshot automation). `CKContainer(identifier:)` then traps
        // on first access and the app dies at launch.
        //
        // Neither of the obvious proxies is correct here:
        //  - `SecTaskCopyValueForEntitlement` (used by the macOS branch below) doesn't
        //    exist for simulator targets — `SecTask.h` ships in the macOS SDK only.
        //  - `FileManager.ubiquityIdentityToken` reflects the *ubiquity* entitlement and
        //    account state, not `com.apple.developer.icloud-container-identifiers`, so a
        //    build holding one but not the other would still trap.
        //
        // Read the entitlements the linker embeds in `__TEXT,__entitlements` for
        // simulator builds — the actual list CloudKit validates against.
        return _embeddedEntitlementContainers()?.isEmpty == false
        #elseif os(macOS) || targetEnvironment(macCatalyst)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.icloud-container-identifiers" as CFString
        guard let value = SecTaskCopyValueForEntitlement(task, key, nil),
              let containers = value as? [String] else { return false }
        return !containers.isEmpty
        #else
        // iOS / tvOS device: check embedded.mobileprovision.
        // If absent (App Store build), assume present — the store validates entitlements.
        return _cloudKitEntitlementFromProvisioningProfile() ?? true
        #endif
    }()

#if targetEnvironment(simulator)
    /// Returns the CloudKit container identifiers from the entitlements blob the linker
    /// embeds in `__TEXT,__entitlements` for simulator builds, or `nil` when the section
    /// is absent (i.e. the build carries no entitlements at all).
    ///
    /// Simulator apps aren't code-signed the way device builds are, so the entitlements
    /// live in a Mach-O section rather than a signature — which is why the macOS
    /// `SecTask*` path and the device `embedded.mobileprovision` path both miss them.
    private static func _embeddedEntitlementContainers() -> [String]? {
        guard let header = _dyld_get_image_header(0) else { return nil }
        var size: UInt = 0
        let sectionPointer = header.withMemoryRebound(to: mach_header_64.self, capacity: 1) { pointer in
            getsectiondata(pointer, "__TEXT", "__entitlements", &size)
        }
        guard let sectionPointer, size > 0 else { return nil }

        let data = Data(bytes: sectionPointer, count: Int(size))
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let entitlements = plist as? [String: Any],
              let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] else {
            return nil
        }
        return containers
    }
#endif

    /// Parses the `embedded.mobileprovision` PKCS#7 blob to check for the CloudKit
    /// container entitlement. Returns `nil` when no provisioning profile is embedded
    /// (App Store distribution), so the caller can treat absence as "assume present".
    private static func _cloudKitEntitlementFromProvisioningProfile() -> Bool? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else {
            return nil // No profile → App Store build → assume entitlements are valid
        }
        // The mobileprovision file is a PKCS#7 signed blob with a plist in plain text inside.
        guard let raw = String(data: data, encoding: .ascii),
              let plistStart = raw.range(of: "<?xml"),
              let plistEnd   = raw.range(of: "</plist>") else { return nil }
        let plistSlice = String(raw[plistStart.lowerBound ..< plistEnd.upperBound]) + "</plist>"
        guard let plistData = plistSlice.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return nil }
        if let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] {
            return !containers.isEmpty
        }
        return false
    }

    // MARK: - Containers

    /// Primary CloudKit container. Nil when running without CloudKit entitlements
    /// (e.g. sideloaded with a different team ID). Always check before using.
    public static let container: CKContainer? = {
        guard isCloudKitEntitlementPresent else {
            WLOG("[iCloudConstants] CloudKit entitlement not present — container unavailable (sideloaded?)")
            return nil
        }
        return CKContainer(identifier: containerIdentifier)
    }()

    /// Fallback containers tried for **reads only** when the primary container returns no record.
    ///
    /// In production/TestFlight builds the dev container is added as a fallback so that
    /// records synced during development are still readable without re-uploading to production.
    /// Writes always go to `container` (primary) — fallbacks are read-only.
    ///
    /// The dev container is validated lazily: if the first access produces a `badContainer`
    /// error (code 5), `invalidateFallbackContainers()` should be called to disable further
    /// attempts for the rest of the session.
    public static var fallbackContainers: [CKContainer] = {
        guard isCloudKitEntitlementPresent else { return [] }
        #if DEBUG
        // Debug: primary is dev, no fallback needed
        return []
        #else
        // Production/TestFlight: fall back to dev container for reads.
        // Regular TestFlight users won't have access to the dev container —
        // the caller must catch badContainer errors and call invalidateFallbackContainers().
        return [CKContainer(identifier: devContainerIdentifier)]
        #endif
    }()

    /// Disables fallback containers for the remainder of this process lifetime.
    /// Call this when a fallback fetch returns `CKError.badContainer` (code 5),
    /// indicating the user doesn't have access to the dev container.
    public static func invalidateFallbackContainers() {
        if !fallbackContainers.isEmpty {
            ILOG("[iCloudConstants] Disabling fallback containers — dev container not accessible")
            fallbackContainers = []
        }
    }

    /// All containers in priority order: primary first, then fallbacks.
    public static var allContainers: [CKContainer] {
        [container].compactMap { $0 } + fallbackContainers
    }
}
