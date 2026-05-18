//
//  SystemIdentifier+ObjCBridge.swift
//  PVCoreBridgeRetro
//
//  Bridges `SystemIdentifier.systemDirectoryName` to Objective-C so that
//  ObjC/ObjC++ files in this module (e.g. PVThinLibretroFrontend.mm) can
//  query the canonical system-directory name without duplicating the lookup
//  table. Import via `#import <PVLibRetro/PVLibRetro-Swift.h>`.
//

import Foundation
import PVSystems

/// Thin `@objc` wrapper that exposes `SystemIdentifier.systemDirectoryName`
/// to Objective-C callers inside `PVLibRetro`.
@objc(PVSystemDirectoryHelper)
public final class PVSystemDirectoryHelper: NSObject {

    /// Returns the conventional short directory name for the given PVSystem
    /// identifier string (e.g. `"com.provenance.psp"` → `"PSP"`), or `nil`
    /// when the system has no dedicated system directory.
    ///
    /// This delegates to `SystemIdentifier.systemDirectoryName` in `PVPrimitives`
    /// and is the single source of truth — no separate lookup table needed.
    @objc public static func systemDirectoryName(forIdentifier identifier: String?) -> String? {
        guard let identifier else { return nil }
        return SystemIdentifier(rawValue: identifier)?.systemDirectoryName
    }

    /// Returns the subdirectory name a libretro core looks for via
    /// `RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY` (e.g.
    /// `"com.provenance.psp"` → `"PPSSPP"`, `"com.provenance.dreamcast"` →
    /// `"dc"`). This differs from ``systemDirectoryName(forIdentifier:)``
    /// for systems whose upstream libretro fork hard-codes a specific
    /// lowercase / branded name. Used by thin-wrapper + RA full-wrapper
    /// callers that need the directory the core actually scans.
    ///
    /// Returns `nil` for systems without a libretro fork in our matrix or
    /// when the core reads from the BIOS root.
    ///
    /// Delegates to `SystemIdentifier.retroArchSystemDirectoryName`.
    @objc public static func retroArchSystemDirectoryName(forIdentifier identifier: String?) -> String? {
        guard let identifier else { return nil }
        return SystemIdentifier(rawValue: identifier)?.retroArchSystemDirectoryName
    }
}
