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

    /// Whether the host should push `resolved` into the core: the core runs something else
    /// and the host has not pushed this id already. A different resolved id is pushed again.
    static func shouldApplyVariant(resolved: String, current: String?, lastApplied: String?) -> Bool {
        resolved != current && resolved != lastApplied
    }

    /// The variant the host pushes into the core at boot, or `nil` to leave the core alone.
    ///
    /// - `explicit`: the player's per-game or per-system choice the binding has a family for
    ///   (`explicitVariantID`). It is always the target.
    /// - Otherwise the binding default `resolvedDefault` is the target only when the core has
    ///   port devices (`hasSavedPortDevice != nil`), the player saved no Port Devices choice
    ///   for port 0, and the core reports a variant (`coreCurrent != nil`). A `nil` read-back
    ///   is a device that is no variant, e.g. Genesis "Joypad Auto", which stays as it is.
    ///   Cores without port devices (Dolphin) get explicit choices only.
    ///
    /// The target is then pushed only when `shouldApplyVariant` agrees.
    static func variantToPush(explicit: String?, resolvedDefault: String, coreCurrent: String?,
                              hasSavedPortDevice: Bool?, lastApplied: String?) -> String? {
        let target: String
        if let explicit {
            target = explicit
        } else {
            guard hasSavedPortDevice == false, coreCurrent != nil else { return nil }
            target = resolvedDefault
        }
        return shouldApplyVariant(resolved: target, current: coreCurrent, lastApplied: lastApplied) ? target : nil
    }

    /// The player's own choice for the game: per-game, else per-system, skipping any that is
    /// not selectable (`selectableVariants`). `nil` when neither is set (or the system is unbound).
    static func explicitVariantID(for system: SystemIdentifier, gameMD5: String) -> String? {
        let selectable = Set(selectableVariants(for: system).map(\.id))
        let candidates: [String?] = [
            gameMD5.isEmpty ? nil : Defaults[.controllerLayoutVariantsByGame][gameMD5],
            Defaults.controllerLayoutVariant(forSystemID: system.rawValue)
        ]
        return candidates.compactMap { $0 }.first { selectable.contains($0) }
    }

    /// The system's controller layout variants the overlay can draw: those the system offers
    /// (`availableControllerLayoutVariants`, in its order) that its overlay binding has a
    /// family for. Empty for an unbound system or one whose only family is `standard` (NES).
    static func selectableVariants(for system: SystemIdentifier) -> [ControllerLayoutVariant] {
        guard let binding = SystemOverlayBindings.binding(for: system),
              let variants = system.availableControllerLayoutVariants else { return [] }
        return variants.filter { binding.families[$0.id] != nil }
    }

    /// Whether the pause menu offers the Controller Layout picker: any selectable variant. A
    /// single one (GameCube) is still shown, as the in-game way to overwrite a stored choice
    /// the overlay cannot draw (e.g. `gc-bongos` saved before it was unbound).
    static func offersVariantChoice(for system: SystemIdentifier) -> Bool {
        !selectableVariants(for: system).isEmpty
    }

    /// The first candidate the system's binding has a family for, in order: the per-game
    /// choice, the variant `variantProvider` reports it is running, the per-system choice,
    /// then the binding's own default (not `defaultControllerLayoutVariant`, which for Wii is
    /// the sideways remote). A candidate without a family is skipped, not taken. `nil` only
    /// for a system without an overlay binding.
    ///
    /// The overlay passes the core as `variantProvider`. The emulator view controller's boot
    /// push goes through `explicitVariantID` and `variantToPush` instead.
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
