//
//  iCloudConstants.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import CloudKit
import Security
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
    /// entitlement. Uses SecTask so it reads the actual entitlements without triggering
    /// CloudKit framework initialization (safe to call before any CKContainer usage).
    /// Returns false for sideloaded builds signed without CloudKit entitlements.
    public static let isCloudKitEntitlementPresent: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.icloud-container-identifiers" as CFString
        guard let value = SecTaskCopyValueForEntitlement(task, key, nil),
              let containers = value as? [String] else { return false }
        return !containers.isEmpty
    }()

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
    public static let fallbackContainers: [CKContainer] = {
        guard isCloudKitEntitlementPresent else { return [] }
        #if DEBUG
        // Debug: primary is dev, no fallback needed
        return []
        #else
        // Production/TestFlight: fall back to dev container for reads
        return [CKContainer(identifier: devContainerIdentifier)]
        #endif
    }()

    /// All containers in priority order: primary first, then fallbacks.
    public static var allContainers: [CKContainer] {
        [container].compactMap { $0 } + fallbackContainers
    }
}
