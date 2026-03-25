//
//  PVRetroArchCoreBridge+Language.swift
//  PVRetroArchCore
//
//  Created by Claude on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Defaults
import Foundation
import PVSettings
import PVSupport

/// Provides the resolved `user_language` integer for use in `retroarch.cfg`.
///
/// The ObjC bridge calls `+resolvedUserLanguage` immediately after writing the
/// config file, then updates the `user_language` key in that file.
@objc public extension PVRetroArchCoreBridge {

    /// Returns the RetroArch `user_language` integer that should be written to
    /// `retroarch.cfg`.
    ///
    /// Reads the typed `CoreLanguageSetting` via the `Defaults` API.
    /// - If the setting is `.systemLocale` (the default), the method resolves
    ///   `Locale.current` via `CoreLocaleMapper`.
    /// - Otherwise the setting's `rawValue` is returned directly (explicit override).
    @objc class func resolvedUserLanguage() -> Int {
        let setting = Defaults[.coreLanguage]
        return setting.retroArchLanguageID ?? CoreLocaleMapper.currentRetroArchLanguageID
    }
}
