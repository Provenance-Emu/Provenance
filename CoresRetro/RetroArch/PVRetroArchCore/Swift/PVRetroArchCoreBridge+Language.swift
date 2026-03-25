//
//  PVRetroArchCoreBridge+Language.swift
//  PVRetroArchCore
//
//  Created by Claude on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

/// Provides the resolved `user_language` integer for use in `retroarch.cfg`.
///
/// The ObjC bridge calls `+resolvedUserLanguage` immediately after writing the
/// config file, then updates the `user_language` key in that file.
@objc public extension PVRetroArchCoreBridge {

    /// Returns the RetroArch `user_language` integer that should be written to
    /// `retroarch.cfg`.
    ///
    /// Reads the `coreLanguage` value stored in `UserDefaults` (key `"coreLanguage"`).
    /// - If the stored raw value is `-1` (system locale) **or** absent, the
    ///   method resolves `Locale.current` via `CoreLocaleMapper`.
    /// - Otherwise the stored integer is returned directly (explicit override).
    @objc class func resolvedUserLanguage() -> Int {
        let stored = UserDefaults.standard.integer(forKey: "coreLanguage")
        // -1 is the sentinel for .systemLocale; 0 is also the default when the
        // key is absent (UserDefaults returns 0 for missing integer keys).
        // Distinguish "explicitly set to English (0)" from "never set (-1/missing)":
        // we use the presence of the key to detect a real stored value.
        if UserDefaults.standard.object(forKey: "coreLanguage") == nil {
            // Key never written → follow system locale
            return CoreLocaleMapper.currentRetroArchLanguageID
        }
        if stored == -1 {
            return CoreLocaleMapper.currentRetroArchLanguageID
        }
        return stored
    }
}
