//
//  ProgrammaticOverlaySupport.swift
//  PVUIBase
//
//  Shared decisions about when the programmatic touch overlay applies to a game.
//

import Foundation
import PVSystems
import PVTouchOverlay

enum ProgrammaticOverlaySupport {
    /// A game's system: the linked `PVSystem` when present, else the persisted
    /// `PVGame.systemIdentifier` (the relationship can be missing).
    static func systemIdentifier(linked: SystemIdentifier?, persisted: String) -> SystemIdentifier? {
        linked ?? SystemIdentifier(rawValue: persisted)
    }

    /// Whether the overlay stands in for missing skin controls: the setting is on and the
    /// system has an overlay binding.
    static func covers(_ systemId: SystemIdentifier?, enabled: Bool) -> Bool {
        guard enabled, let systemId else { return false }
        return SystemOverlayBindings.binding(for: systemId) != nil
    }
}
