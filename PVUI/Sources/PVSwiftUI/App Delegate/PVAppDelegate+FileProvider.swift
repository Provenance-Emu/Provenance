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

    /// The domain identifier must match the `NSExtensionFileProviderDocumentGroup`
    /// value in `Extensions/ROM File Provider/Info.plist`.
    static let domainIdentifier = NSFileProviderDomainIdentifier("org.provenance-emu.provenance.roms")

    /// Human-readable name shown in Files.app under Browse > Locations.
    static let displayName = "Provenance"

    /// Registers the ROM library domain with `NSFileProviderManager`.
    ///
    /// Safe to call multiple times — if the domain is already registered the
    /// completion handler receives a non-fatal `NSFileProviderError.providerNotFound`
    /// which is silently ignored.
    public static func registerIfNeeded() {
        let domain = NSFileProviderDomain(
            identifier: domainIdentifier,
            displayName: displayName
        )
        NSFileProviderManager.add(domain) { error in
            if let error = error as NSError? {
                // Code 4 = domain already registered — not an error.
                if error.domain == NSFileProviderErrorDomain,
                   error.code == NSFileProviderError.providerNotFound.rawValue {
                    DLOG("FileProvider: domain already registered")
                    return
                }
                ELOG("FileProvider: failed to register domain — \(error.localizedDescription)")
            } else {
                ILOG("FileProvider: domain '\(displayName)' registered successfully")
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
