//
//  ProgrammaticOverlaySupport.swift
//  PVUIBase
//
//  Shared decisions about when the programmatic touch overlay applies to a game.
//

import Foundation
import Defaults
import PVEmulatorCore
import PVSettings
import PVSystems
import PVTouchOverlay

public enum ProgrammaticOverlaySupport {
    /// A game's system: the linked `PVSystem` when present, else the persisted
    /// `PVGame.systemIdentifier` (the relationship can be missing).
    static func systemIdentifier(linked: SystemIdentifier?, persisted: String) -> SystemIdentifier? {
        linked ?? SystemIdentifier(rawValue: persisted)
    }

    /// Whether the overlay stands in for missing skin controls: any game with a known system
    /// gets either its system's binding or `SystemOverlayBindings.generic`.
    static func covers(_ systemId: SystemIdentifier?) -> Bool {
        systemId != nil
    }

    /// Only Always mode may choose an unselected packaged skin. Explicit-selection cores
    /// must keep their built-in controller until the player picks a skin.
    static func allowsAutomaticSkin(mode: SkinMode, requiresExplicitSelection: Bool) -> Bool {
        mode == .always && !requiresExplicitSelection
    }

    /// Whether an empty skin pick shows the built-in controls, so skin pickers highlight their
    /// Built-in cell. Pass the running core from the pause menu; library pickers have none.
    @MainActor
    public static func skinPickerDefaultsToBuiltIn(for core: PVEmulatorCore? = nil) -> Bool {
        !allowsAutomaticSkin(mode: Defaults[.skinMode], requiresExplicitSelection: core?.requiresExplicitSkinSelection ?? false)
    }

    /// Whether a packaged skin may load. Classic mode (skins Off) and cores without skin
    /// support show only the overlay.
    @MainActor
    static func allowsPackagedSkins(for core: PVEmulatorCore) -> Bool {
        Defaults[.skinMode] != .off && core.supportsSkins
    }
}
