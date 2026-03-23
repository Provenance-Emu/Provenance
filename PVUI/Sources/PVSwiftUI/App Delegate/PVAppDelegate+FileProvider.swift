//
//  PVAppDelegate+FileProvider.swift
//  Provenance
//
//  Copyright © 2024 Provenance Emu. All rights reserved.
//
//  Registers the ROM library NSFileProviderDomain so that Files.app shows
//  "Provenance" as a location under Browse > Locations.
//
//  The domain must be registered from the host application on every launch
//  before the extension process is started by the system.
//

import Foundation
import FileProvider
import PVLogging

/// Domain registration helpers for the ROM File Provider extension.
///
/// Call `PVFileProviderDomain.registerIfNeeded()` once at app launch
/// (e.g. inside `PVAppDelegate.initializeAppComponents()`).
public enum PVFileProviderDomain {

    /// Uniquely identifies this file provider domain to the system.
    ///
    /// Must be the same value used when calling `NSFileProviderManager.add(_:)` from
    /// the host app and when the system routes requests to the extension process.
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
            }
            guard !(existingDomains ?? []).contains(where: { $0.identifier == domainIdentifier }) else {
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
                    // domainAlreadyRegistered (-2006) is benign — can occur if a concurrent
                    // call races past the pre-check above.
                    let isAlreadyRegistered = nsErr.domain == NSFileProviderErrorDomain
                        && NSFileProviderError.Code(rawValue: nsErr.code) == .domainAlreadyRegistered
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

#if !os(tvOS)
// MARK: - PVAppDelegate hook

extension PVAppDelegate {
    /// Call from `initializeAppComponents()` to register the file provider domain.
    func registerFileProviderDomain() {
        PVFileProviderDomain.registerIfNeeded()
    }
}
#endif
