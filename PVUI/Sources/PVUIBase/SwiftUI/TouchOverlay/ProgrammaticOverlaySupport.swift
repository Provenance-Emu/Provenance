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

enum ProgrammaticOverlaySupport {
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

    /// Whether a packaged skin may load. Classic mode (skins Off) and cores without skin
    /// support show only the overlay.
    @MainActor
    static func allowsPackagedSkins(for core: PVEmulatorCore) -> Bool {
        Defaults[.skinMode] != .off && core.supportsSkins
    }
}
