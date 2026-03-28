//
//  CoreLanguageSetting.swift
//  PVSettings
//
//  Created by Claude on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Defaults
import Foundation

/// Controls the language used by emulator cores (RetroArch `user_language` and
/// native-core equivalents such as DuckStation's `Language` and PPSSPP's `Language`).
///
/// The integer raw values mirror the `RETRO_LANGUAGE_*` enum in `libretro.h` so
/// that `CoreLanguageSetting.rawValue` can be written directly to `user_language`
/// in `retroarch.cfg`. `systemLocale` (-1) is a sentinel that means "resolve at
/// launch from `Locale.current`".
public enum CoreLanguageSetting: Int, Codable, Equatable, CaseIterable,
                                  UserDefaultsRepresentable, Defaults.Serializable {

    /// Resolve language from the device locale at core launch (default).
    case systemLocale          = -1

    // MARK: - Explicit language overrides
    // Raw values match RETRO_LANGUAGE_* in libretro.h exactly.
    case english               = 0   // RETRO_LANGUAGE_ENGLISH
    case japanese              = 1   // RETRO_LANGUAGE_JAPANESE
    case french                = 2   // RETRO_LANGUAGE_FRENCH
    case spanish               = 3   // RETRO_LANGUAGE_SPANISH
    case german                = 4   // RETRO_LANGUAGE_GERMAN
    case italian               = 5   // RETRO_LANGUAGE_ITALIAN
    case dutch                 = 6   // RETRO_LANGUAGE_DUTCH
    case portugueseBrazil      = 7   // RETRO_LANGUAGE_PORTUGUESE_BRAZIL
    case portuguesePortugal    = 8   // RETRO_LANGUAGE_PORTUGUESE_PORTUGAL
    case russian               = 9   // RETRO_LANGUAGE_RUSSIAN
    case korean                = 10  // RETRO_LANGUAGE_KOREAN
    case chineseTraditional    = 11  // RETRO_LANGUAGE_CHINESE_TRADITIONAL
    case chineseSimplified     = 12  // RETRO_LANGUAGE_CHINESE_SIMPLIFIED
    case esperanto             = 13  // RETRO_LANGUAGE_ESPERANTO
    case polish                = 14  // RETRO_LANGUAGE_POLISH
    case vietnamese             = 15  // RETRO_LANGUAGE_VIETNAMESE
    case arabic                = 16  // RETRO_LANGUAGE_ARABIC
    case greek                 = 17  // RETRO_LANGUAGE_GREEK
    case turkish               = 18  // RETRO_LANGUAGE_TURKISH
    case slovak                = 19  // RETRO_LANGUAGE_SLOVAK
    case persian               = 20  // RETRO_LANGUAGE_PERSIAN
    case hebrew                = 21  // RETRO_LANGUAGE_HEBREW
    case asturian              = 22  // RETRO_LANGUAGE_ASTURIAN
    case finnish               = 23  // RETRO_LANGUAGE_FINNISH

    /// Human-readable display name shown in the Settings UI.
    public var description: String {
        switch self {
        case .systemLocale:         return "System Language"
        case .english:              return "English"
        case .japanese:             return "Japanese (日本語)"
        case .french:               return "French (Français)"
        case .spanish:              return "Spanish (Español)"
        case .german:               return "German (Deutsch)"
        case .italian:              return "Italian (Italiano)"
        case .dutch:                return "Dutch (Nederlands)"
        case .portugueseBrazil:     return "Portuguese — Brazil (Português)"
        case .portuguesePortugal:   return "Portuguese — Portugal (Português)"
        case .russian:              return "Russian (Русский)"
        case .korean:               return "Korean (한국어)"
        case .chineseTraditional:   return "Chinese Traditional (繁體中文)"
        case .chineseSimplified:    return "Chinese Simplified (简体中文)"
        case .esperanto:            return "Esperanto"
        case .polish:               return "Polish (Polski)"
        case .vietnamese:           return "Vietnamese (Tiếng Việt)"
        case .arabic:               return "Arabic (العربية)"
        case .greek:                return "Greek (Ελληνικά)"
        case .turkish:              return "Turkish (Türkçe)"
        case .slovak:               return "Slovak (Slovenčina)"
        case .persian:              return "Persian (فارسی)"
        case .hebrew:               return "Hebrew (עברית)"
        case .asturian:             return "Asturian (Asturianu)"
        case .finnish:              return "Finnish (Suomi)"
        }
    }

    /// The RetroArch `user_language` integer, or `nil` for `.systemLocale`
    /// (caller must resolve via `Locale.current`).
    public var retroArchLanguageID: Int? {
        guard self != .systemLocale else { return nil }
        return rawValue
    }
}
