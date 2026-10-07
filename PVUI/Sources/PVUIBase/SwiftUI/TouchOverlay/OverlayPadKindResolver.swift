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
    /// The subtype the overlay draws (see `resolvedVariantID`), or `standard` for an unbound system.
    static func padKind(for system: SystemIdentifier, variantProvider: (any ConsoleVariantConfigurable)?,
                        gameMD5: String) -> OverlayPadKind {
        guard let subtype = resolvedVariantID(for: system, variantProvider: variantProvider, gameMD5: gameMD5) else {
            return .standard(system)
        }
        return OverlayPadKind(system: system, subtype: subtype)
    }

    /// The first candidate the system's binding has a family for, in order: the per-game
    /// choice, the variant `variantProvider` reports it is running, the per-system choice,
    /// then the binding's own default (not `defaultControllerLayoutVariant`, which for Wii is
    /// the sideways remote). A candidate without a family is skipped, not taken. `nil` only
    /// for a system without an overlay binding.
    ///
    /// The overlay passes the core as `variantProvider`; the emulator view controller passes
    /// `nil` to get the settings' answer, which it then pushes into the core at boot.
    static func resolvedVariantID(for system: SystemIdentifier, variantProvider: (any ConsoleVariantConfigurable)?,
                                  gameMD5: String) -> String? {
        guard let binding = SystemOverlayBindings.binding(for: system) else { return nil }
        let candidates: [String?] = [
            gameMD5.isEmpty ? nil : Defaults[.controllerLayoutVariantsByGame][gameMD5],
            variantProvider?.currentControllerLayoutVariantID,
            Defaults.controllerLayoutVariant(forSystemID: system.rawValue)
        ]
        return candidates.compactMap { $0 }.first { binding.families[$0] != nil } ?? binding.defaultSubtype
    }
}
