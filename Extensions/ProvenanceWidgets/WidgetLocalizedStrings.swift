//
//  WidgetLocalizedStrings.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import Foundation

/// Shared lookup helpers for widget UI strings.
///
/// Static copy uses `String(localized:defaultValue:comment:)` with literal keys and English
/// `defaultValue` fallbacks. Formatted or interpolated values use
/// `NSLocalizedString(_:bundle:comment:)` plus `String(format:locale:)` with literal keys.
/// Keys are mirrored in `en.lproj/Localizable.strings` for translators.
enum WidgetLocalizedStrings {
    /// Product name shown when no game title is available (Quick Launch, empty states, Library Stats header).
    static var brandName: String {
        String(localized: "widget.common.brand-name", defaultValue: "Provenance", comment: "Product name when no game title is available")
    }

    /// Placeholder when a system abbreviation is missing in compact badges.
    static var unknownSystemAbbreviation: String {
        String(localized: "widget.common.unknown-system", defaultValue: "???", comment: "Placeholder when system abbreviation is missing")
    }
}
#endif
