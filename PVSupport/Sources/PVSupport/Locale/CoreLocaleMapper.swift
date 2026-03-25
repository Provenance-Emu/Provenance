//
//  CoreLocaleMapper.swift
//  PVSupport
//
//  Created by Claude on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Maps iOS/macOS locale identifiers to emulator-core language integers.
///
/// RetroArch uses a flat `user_language` integer (RETRO_LANGUAGE_* enum).
/// This utility converts `Locale.current` — or any locale — to that integer
/// so it can be written into `retroarch.cfg` at core launch.
///
/// Usage:
/// ```swift
/// let langID = CoreLocaleMapper.retroArchLanguageID(for: Locale.current)
/// // Write "user_language = \(langID)" into retroarch.cfg
/// ```
public enum CoreLocaleMapper {

    // MARK: - RetroArch language IDs (RETRO_LANGUAGE_*)
    public static let retroArchEnglish              = 0
    public static let retroArchJapanese             = 1
    public static let retroArchFrench               = 2
    public static let retroArchGerman               = 3
    public static let retroArchSpanish              = 4
    public static let retroArchItalian              = 5
    public static let retroArchPortuguese           = 6
    public static let retroArchDutch                = 7
    public static let retroArchEsperanto            = 8  // also mapped for Swedish
    public static let retroArchPolish               = 9
    public static let retroArchChineseSimplified    = 11
    public static let retroArchKorean               = 12
    public static let retroArchChineseTraditional   = 13
    public static let retroArchArabic               = 14
    public static let retroArchGreek                = 15
    public static let retroArchRussian              = 16

    // MARK: - Mapping

    /// Returns the RetroArch `user_language` integer that best matches `locale`.
    /// Falls back to English (0) for unrecognised locales.
    public static func retroArchLanguageID(for locale: Locale) -> Int {
        // Prefer `Locale.language.languageCode` (iOS 16+) with fallback to
        // the legacy `languageCode` property for broader OS support.
        let languageCode: String
        if #available(iOS 16, tvOS 16, macOS 13, *) {
            languageCode = locale.language.languageCode?.identifier ?? locale.languageCode ?? "en"
        } else {
            languageCode = locale.languageCode ?? "en"
        }

        // For Chinese variants we also need the script subtag.
        let scriptCode: String?
        if #available(iOS 16, tvOS 16, macOS 13, *) {
            scriptCode = locale.language.script?.identifier
        } else {
            scriptCode = locale.scriptCode
        }

        switch languageCode {
        case "ja":                          return retroArchJapanese
        case "fr":                          return retroArchFrench
        case "de":                          return retroArchGerman
        case "es":                          return retroArchSpanish
        case "it":                          return retroArchItalian
        case "pt":                          return retroArchPortuguese
        case "nl":                          return retroArchDutch
        case "sv", "eo":                    return retroArchEsperanto
        case "pl":                          return retroArchPolish
        case "ko":                          return retroArchKorean
        case "ar":                          return retroArchArabic
        case "el":                          return retroArchGreek
        case "ru":                          return retroArchRussian
        case "zh":
            // zh-Hans → Simplified, zh-Hant → Traditional
            if let script = scriptCode {
                return script == "Hans" ? retroArchChineseSimplified : retroArchChineseTraditional
            }
            // Region heuristic: Mainland China / Singapore → Simplified
            let regionCode: String?
            if #available(iOS 16, tvOS 16, macOS 13, *) {
                regionCode = locale.region?.identifier
            } else {
                regionCode = locale.regionCode
            }
            switch regionCode {
            case "CN", "SG": return retroArchChineseSimplified
            default:         return retroArchChineseTraditional
            }
        default:
            return retroArchEnglish
        }
    }

    /// Convenience: resolve from `Locale.current`.
    public static var currentRetroArchLanguageID: Int {
        retroArchLanguageID(for: .current)
    }

    // MARK: - CTR (3DS / Citra / Azahar) language IDs
    //
    // Matches the Citra/Azahar SystemLanguage enum:
    //   0=Japanese 1=English 2=French 3=German 4=Italian 5=Spanish
    //   6=SimplifiedChinese 7=Korean 8=Dutch 9=Portuguese 10=Russian 11=TraditionalChinese

    /// Returns the CTR (3DS) language integer that best matches `locale`.
    /// Falls back to English (1) for unrecognised locales.
    public static func ctrLanguageID(for locale: Locale) -> Int {
        let languageCode: String
        if #available(iOS 16, tvOS 16, macOS 13, *) {
            languageCode = locale.language.languageCode?.identifier ?? locale.languageCode ?? "en"
        } else {
            languageCode = locale.languageCode ?? "en"
        }

        let scriptCode: String?
        if #available(iOS 16, tvOS 16, macOS 13, *) {
            scriptCode = locale.language.script?.identifier
        } else {
            scriptCode = locale.scriptCode
        }

        switch languageCode {
        case "ja": return 0
        case "fr": return 2
        case "de": return 3
        case "it": return 4
        case "es": return 5
        case "ko": return 7
        case "nl": return 8
        case "pt": return 9
        case "ru": return 10
        case "zh":
            if let script = scriptCode {
                return script == "Hans" ? 6 : 11
            }
            let regionCode: String?
            if #available(iOS 16, tvOS 16, macOS 13, *) {
                regionCode = locale.region?.identifier
            } else {
                regionCode = locale.regionCode
            }
            return (regionCode == "CN" || regionCode == "SG") ? 6 : 11
        default:
            return 1 // English
        }
    }

    /// Convenience: resolve CTR language ID from `Locale.current`.
    public static var currentCTRLanguageID: Int {
        ctrLanguageID(for: .current)
    }

    // MARK: - NDS (DS) firmware language strings
    //
    // Used by melonDS (`melonds_language`) and Desmume2015 (`desmume_firmware_language`).
    // Supported values: "Japanese" | "English" | "French" | "German" | "Italian" | "Spanish"

    /// Returns the NDS firmware language string that best matches `locale`.
    /// Falls back to "English" for unrecognised locales.
    public static func ndsLanguageString(for locale: Locale) -> String {
        let languageCode: String
        if #available(iOS 16, tvOS 16, macOS 13, *) {
            languageCode = locale.language.languageCode?.identifier ?? locale.languageCode ?? "en"
        } else {
            languageCode = locale.languageCode ?? "en"
        }

        switch languageCode {
        case "ja": return "Japanese"
        case "fr": return "French"
        case "de": return "German"
        case "it": return "Italian"
        case "es": return "Spanish"
        default:   return "English"
        }
    }

    /// Convenience: resolve NDS language string from `Locale.current`.
    public static var currentNDSLanguageString: String {
        ndsLanguageString(for: .current)
    }
}
