//
//  ThemeBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import PVLogging
import PVThemes

/// Applies the user's saved UI theme.
///
/// Depends on `BootstrapKey.settings` so that user defaults are loaded first.
/// Provides `BootstrapKey.theme`.
@MainActor
struct ThemeBootstrapTask: BootstrapTask {
    var name: String { "Theme" }
    var dependencies: [String] { [BootstrapKey.settings] }
    var provisions: [String] { [BootstrapKey.theme] }

    func execute() async throws {
        ThemeManager.applySavedTheme()
        let palette = ThemeManager.shared.currentPalette
        themeAppUI(withPalette: palette)
#if os(tvOS)
        UIWindow.appearance().tintColor = .provenanceBlue
#endif
        ILOG("ThemeBootstrapTask: Applied theme '\(palette.name)'")
    }
}
