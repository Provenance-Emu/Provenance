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
}
