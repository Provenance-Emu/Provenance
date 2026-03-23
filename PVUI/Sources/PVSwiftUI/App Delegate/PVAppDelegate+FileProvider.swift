//
//  PVAppDelegate+FileProvider.swift
//  Provenance
//
//  Copyright © 2024 Provenance Emu. All rights reserved.
//
//  Registers the ROM library NSFileProviderDomain so that Files.app shows
//  "Provenance" as a location under Browse > Locations.
//
//  Supported platforms: iOS, macOS, visionOS (FileProvider is unavailable on tvOS).
//
//  The domain must be registered from the host application on every launch
//  before the extension process is started by the system.
//

import Foundation
import PVLogging

#if canImport(FileProvider) && (os(iOS) || targetEnvironment(macCatalyst) || os(visionOS))
import FileProvider

/// Domain registration helpers for the ROM File Provider extension.
///
/// Call `PVFileProviderDomain.registerIfNeeded()` once at app launch
/// (e.g. inside `PVAppDelegate.initializeAppComponents()`).
public enum PVFileProviderDomain {

    /// Uniquely identifies this file provider domain to the system.
    ///
    /// The domain identifier is used by `NSFileProviderManager.add(_:)` in the host app
    /// and when the system routes requests to the extension process.
    static let domainIdentifier = NSFileProviderDomainIdentifier("org.provenance-emu.provenance.roms")

    /// Human-readable name shown in Files.app under Browse > Locations.
    static let displayName = "Provenance"

    /// Registers the ROM library domain with `NSFileProviderManager`.
    ///
    /// Safe to call multiple times — checks existing domains first to avoid
    /// redundant registration attempts.
    public static func registerIfNeeded() {
        NSFileProviderManager.getDomainsWithCompletionHandler { existingDomains, fetchError in
            if let fetchError = fetchError {
                ELOG("FileProvider: failed to query existing domains — \(fetchError.localizedDescription)")
                return
            }
            guard !existingDomains.contains(where: { $0.identifier == domainIdentifier }) else {
                DLOG("FileProvider: domain already registered, skipping")
                return
            }
            let domain = NSFileProviderDomain(
                identifier: domainIdentifier,
                displayName: displayName
            )
            NSFileProviderManager.add(domain) { error in
                if let error = error {
                    let nsErr = error as NSError
                    // Error code -1 with NSCocoaErrorDomain or any FileProvider error where
                    // the domain already exists is benign — can occur if a concurrent call
                    // races past the pre-check above.
                    let isAlreadyRegistered = nsErr.domain == NSFileProviderErrorDomain
                        && nsErr.code == -1
                    if isAlreadyRegistered {
                        DLOG("FileProvider: domain already registered (benign race) — OK")
                    } else {
                        ELOG("FileProvider: failed to register domain — \(error.localizedDescription)")
                    }
                } else {
                    ILOG("FileProvider: domain '\(displayName)' registered successfully")
                }
            }
        }
    }
}

#endif // canImport(FileProvider) && platforms

// MARK: - PVAppDelegate hook (unconditional — body guards with same #if)

extension PVAppDelegate {
    /// Call from `initializeAppComponents()` to register the file provider domain.
    /// Always defined so the call site never needs a `#if canImport(FileProvider)` guard.
    func registerFileProviderDomain() {
        #if canImport(FileProvider) && (os(iOS) || targetEnvironment(macCatalyst) || os(visionOS))
        PVFileProviderDomain.registerIfNeeded()
        #endif
    }
}
