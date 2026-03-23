//
//  AppGroupID.swift
//  PVAppIntents
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Single source of truth for the App Group identifier within PVAppIntents.
//
//  PVAppIntents intentionally has no dependency on PVLibrary (it must stay
//  lightweight so widget extensions can link against it). The canonical
//  definition used by code that *can* import PVLibrary is:
//      PVLibrary/Sources/PVFileSystem/Paths.swift  →  `public let PVAppGroupId`
//
//  Sideloaders or AltStore users can change their team ID and App Group ID via
//  the APP_GROUP_IDENTIFIER build setting in Xcode or a CodeSigning.xcconfig.
//  Both this file and PVLibrary's Paths.swift read from the same Info.plist key,
//  so the value is always correct for the running build.
//

import Foundation

/// The App Group identifier for this build.
///
/// Resolved at runtime from the `APP_GROUP_IDENTIFIER` Info.plist key
/// (set via the `APP_GROUP_IDENTIFIER` Xcode build setting).  Falls back
/// to the default value for development and CI builds that don't set the key.
///
/// All code within PVAppIntents must use this constant — never inline the
/// string literal `"group.org.provenance-emu.provenance"` directly.
internal let pvAppGroupID: String = {
    let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
    // Guard against unexpanded Xcode build-variable placeholders (e.g. "$(APP_GROUP_IDENTIFIER)")
    // which appear when a target's Info.plist is evaluated outside of an Xcode build.
    guard let raw, !raw.isEmpty, !raw.contains("$(") else {
        return "group.org.provenance-emu.provenance"
    }
    return raw
}()

/// Convenience: opens the App Group `UserDefaults` suite, or `nil` if unavailable.
internal var pvAppGroupDefaults: UserDefaults? {
    UserDefaults(suiteName: pvAppGroupID)
}
