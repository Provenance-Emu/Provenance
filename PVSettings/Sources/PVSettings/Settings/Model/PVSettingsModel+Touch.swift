//
//  PVSettingsModel+Touch.swift
//  PVSettings
//
//  On-screen controller touch preferences.
//

import Foundation
import Defaults

// Touch controls
public extension Defaults.Keys {
    /// Controller skins: one finger covering two gameplay buttons presses both, instead of only the
    /// closest. The d-pad, sticks and menu / save / load / fast-forward style buttons are unaffected.
    /// Off by default, as in iFly ("Skin Multi-Button Touch").
    static let skinMultiButtonTouch = Key<Bool>("skinMultiButtonTouch", default: false)

    /// Built-in arcade controller: a finger between two panel buttons presses both, for fighting-game
    /// combos. On by default, as in iFly ("Arcade Multi-Button Touch").
    static let arcadeMultiButtonTouch = Key<Bool>("arcadeMultiButtonTouch", default: true)
}
