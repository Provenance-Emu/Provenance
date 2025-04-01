//
//  ProvenanceThemes.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 10/23/24.
//

import UIKit

public enum ProvenanceThemes: String, CaseIterable, PaletteProvider {
    case `default`
    case dark
    case light
    case retrowave

    public var palette: any UXThemePalette {
        let palette: any UXThemePalette
        switch self {
        case .default:
            palette = UITraitCollection.current.userInterfaceStyle == .dark ? DarkThemePalette() : LightThemePalette()
        case .dark:
            palette = DarkThemePalette()
        case .light:
            palette = LightThemePalette()
        case .retrowave:
            palette = RetroWaveThemePalette()
        }
        return palette
    }
}
