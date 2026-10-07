//
//  OverlayPadKindResolver.swift
//  PVUIBase
//
//  Picks the controller subtype the overlay draws for a game.
//

import Foundation
import PVCoreBridge
import PVSettings
import PVSystems
import PVTouchOverlay

enum OverlayPadKindResolver {
    /// The first candidate the system's binding has a family for, in order: the per-game
    /// choice, the variant the core reports it is running, the per-system choice. Falls back
    /// to the binding's own default (not `defaultControllerLayoutVariant`, which for Wii is
    /// the sideways remote). A candidate without a family is skipped, not taken.
    static func padKind(for system: SystemIdentifier, variantProvider: (any ConsoleVariantConfigurable)?,
                        gameMD5: String) -> OverlayPadKind {
        guard let binding = SystemOverlayBindings.binding(for: system) else { return .standard(system) }
        let candidates: [String?] = [
            gameMD5.isEmpty ? nil : Defaults[.controllerLayoutVariantsByGame][gameMD5],
            variantProvider?.currentControllerLayoutVariantID,
            Defaults.controllerLayoutVariant(forSystemID: system.rawValue)
        ]
        let subtype = candidates.compactMap { $0 }.first { binding.families[$0] != nil } ?? binding.defaultSubtype
        return OverlayPadKind(system: system, subtype: subtype)
    }
}
