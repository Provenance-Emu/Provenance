//
//  CoreLanguageSetting.swift
//  PVSettings
//
//  Created by Claude on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Controls the language used by emulator cores (RetroArch `user_language` and
/// native-core equivalents such as DuckStation's `Language` and PPSSPP's `Language`).
///
/// The integer raw values mirror the RetroArch `RETRO_LANGUAGE_*` enum so that
/// `CoreLanguageSetting.rawValue` can be written directly to `user_language` in
/// `retroarch.cfg`. `systemLocale` (-1) is a sentinel that means "resolve at
/// launch from `Locale.current`".
public enum CoreLanguageSetting: Int, Codable, Equatable, CaseIterable,
                                  UserDefaultsRepresentable, Defaults.Serializable {

    /// Resolve language from the device locale at core launch (default).
    case systemLocale   = -1

    // MARK: - Explicit language overrides (values match RETRO_LANGUAGE_* enum)
    case english        = 0
    case japanese       = 1
    case french         = 2
    case german         = 3
    case spanish        = 4
    case italian        = 5
    case portuguese     = 6
    case dutch          = 7
    case esperanto      = 8   // Swedish / Esperanto in RetroArch
    case polish         = 9
    case russian        = 16
    case korean         = 12
    case chineseSimplified  = 11
    case chineseTraditional = 13
    case arabic         = 14
    case greek          = 15

    /// Human-readable display name shown in the Settings UI.
    public var description: String {
        switch self {
        case .systemLocale:         return "System Language"
        case .english:              return "English"
        case .japanese:             return "Japanese (日本語)"
        case .french:               return "French (Français)"
        case .german:               return "German (Deutsch)"
        case .spanish:              return "Spanish (Español)"
        case .italian:              return "Italian (Italiano)"
        case .portuguese:           return "Portuguese (Português)"
        case .dutch:                return "Dutch (Nederlands)"
        case .esperanto:            return "Esperanto / Swedish"
        case .polish:               return "Polish (Polski)"
        case .russian:              return "Russian (Русский)"
        case .korean:               return "Korean (한국어)"
        case .chineseSimplified:    return "Chinese Simplified (简体中文)"
        case .chineseTraditional:   return "Chinese Traditional (繁體中文)"
        case .arabic:               return "Arabic (العربية)"
        case .greek:                return "Greek (Ελληνικά)"
        }
    }

    /// The RetroArch `user_language` integer, or `nil` for `.systemLocale`
    /// (caller must resolve via `Locale.current`).
    public var retroArchLanguageID: Int? {
        guard self != .systemLocale else { return nil }
        return rawValue
    }
}
