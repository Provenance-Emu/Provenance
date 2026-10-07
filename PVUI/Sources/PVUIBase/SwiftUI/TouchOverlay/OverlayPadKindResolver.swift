//
//  OverlayPadKindResolver.swift
//  PVUIBase
//
//  Picks the controller subtype the overlay draws for a game.
//

import Foundation
import PVEmulatorCore
import PVSystems
import PVTouchOverlay

enum OverlayPadKindResolver {
    /// Phase 1 stub: the binding's default subtype. Task 15 adds the per-game,
    /// core read-back and per-system settings.
    static func padKind(for system: SystemIdentifier, core: PVEmulatorCore, gameMD5: String) -> OverlayPadKind {
        let subtype = SystemOverlayBindings.binding(for: system)?.defaultSubtype ?? OverlayPadKind.standardSubtype
        return OverlayPadKind(system: system, subtype: subtype)
    }
}
