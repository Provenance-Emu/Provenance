//
//  OverlayPadKindResolverTests.swift
//  PVUIBaseTests
//
//  Which controller subtype the programmatic overlay draws: the per-game choice, then
//  what the core reports, then the per-system choice, then the binding default. A
//  candidate the binding has no family for is skipped, not taken.
//

import Foundation
import Testing
import Defaults
import PVCoreBridge
import PVSettings
import PVSystems
import PVTouchOverlay
@testable import PVUIBase

@Suite("OverlayPadKindResolver", .serialized) @MainActor
struct OverlayPadKindResolverTests {
    /// Stands in for a core that can report its running variant.
    final class VariantProvider: ConsoleVariantConfigurable {
        var reported: String?
        func applyControllerLayoutVariant(_ variantID: String) { reported = variantID }
        var currentControllerLayoutVariantID: String? { reported }
    }

    private static let md5 = "0123456789abcdef"

    private func subtype(_ system: SystemIdentifier, _ provider: VariantProvider?,
                         md5: String = Self.md5) -> String {
        OverlayPadKindResolver.padKind(for: system, variantProvider: provider, gameMD5: md5).subtype
    }

    private func resetSettings() {
        Defaults.reset(.controllerLayoutVariantsBySystem)
        Defaults.reset(.controllerLayoutVariantsByGame)
    }

    @Test("Order: per-game, then core, then system setting, then binding default")
    func order() {
        resetSettings()
        defer { resetSettings() }
        let provider = VariantProvider()
        #expect(subtype(.Genesis, provider) == "genesis-6btn")
        Defaults.setControllerLayoutVariant("genesis-3btn", forSystemID: SystemIdentifier.Genesis.rawValue)
        #expect(subtype(.Genesis, provider) == "genesis-3btn")
        provider.reported = "genesis-6btn"
        #expect(subtype(.Genesis, provider) == "genesis-6btn")
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-3btn"]
        #expect(subtype(.Genesis, provider) == "genesis-3btn")
    }

    @Test("Binding defaults when nothing is set")
    func bindingDefaults() {
        resetSettings()
        defer { resetSettings() }
        // 6-button is a superset of the core's "Joypad Auto".
        #expect(subtype(.Genesis, nil) == "genesis-6btn")
        // Not `defaultControllerLayoutVariant`, which for Wii is the sideways remote.
        #expect(subtype(.Wii, nil) == "wii-wiimote-nunchuck")
        #expect(subtype(.PSX, nil) == "psx-dualshock")
    }

    @Test("An unknown candidate is skipped and resolution continues")
    func unknownSkipped() {
        resetSettings()
        defer { resetSettings() }
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "not-a-variant"]
        #expect(subtype(.Genesis, VariantProvider()) == "genesis-6btn")
        Defaults.setControllerLayoutVariant("genesis-3btn", forSystemID: SystemIdentifier.Genesis.rawValue)
        #expect(subtype(.Genesis, VariantProvider()) == "genesis-3btn")
        // Another system's variant is not a candidate for this one.
        let provider = VariantProvider()
        provider.reported = "psx-digital"
        #expect(subtype(.Genesis, provider) == "genesis-3btn")
    }

    @Test("An empty MD5 skips the per-game lookup")
    func emptyMD5() {
        resetSettings()
        defer { resetSettings() }
        Defaults[.controllerLayoutVariantsByGame] = ["": "genesis-3btn"]
        #expect(subtype(.Genesis, nil, md5: "") == "genesis-6btn")
    }

    @Test("32X and Sega CD resolve the Genesis subtypes")
    func genesisFamily() {
        resetSettings()
        defer { resetSettings() }
        Defaults.setControllerLayoutVariant("genesis-3btn", forSystemID: SystemIdentifier.Sega32X.rawValue)
        #expect(subtype(.Sega32X, nil) == "genesis-3btn")
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-3btn"]
        #expect(subtype(.SegaCD, nil) == "genesis-3btn")
        #expect(SystemIdentifier.SegaCD.availableControllerLayoutVariants == [.genesis3Button, .genesis6Button])
    }

    @Test("Host resolution: per-game beats system beats binding default; no core read-back")
    func resolvedVariantID() {
        resetSettings()
        defer { resetSettings() }
        let resolve = { (provider: VariantProvider?) in
            OverlayPadKindResolver.resolvedVariantID(for: .PSX, variantProvider: provider, gameMD5: Self.md5)
        }
        #expect(resolve(nil) == "psx-dualshock")
        Defaults.setControllerLayoutVariant("psx-digital", forSystemID: SystemIdentifier.PSX.rawValue)
        #expect(resolve(nil) == "psx-digital")
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "psx-dualshock"]
        #expect(resolve(nil) == "psx-dualshock")
        // With a provider the core's report sits between per-game and system choices.
        Defaults[.controllerLayoutVariantsByGame] = [:]
        let provider = VariantProvider()
        provider.reported = "psx-dualshock"
        #expect(resolve(provider) == "psx-dualshock")
        // Unbound systems have nothing to resolve.
        #expect(OverlayPadKindResolver.resolvedVariantID(for: .RetroArch, variantProvider: nil,
                                                         gameMD5: Self.md5) == nil)
    }

    @Test("The host applies a variant the core is not running, once per resolved id")
    func shouldApplyVariant() {
        #expect(OverlayPadKindResolver.shouldApplyVariant(resolved: "psx-dualshock", current: "psx-digital",
                                                          lastApplied: nil))
        #expect(OverlayPadKindResolver.shouldApplyVariant(resolved: "psx-dualshock", current: nil, lastApplied: nil))
        #expect(!OverlayPadKindResolver.shouldApplyVariant(resolved: "psx-dualshock", current: "psx-dualshock",
                                                           lastApplied: nil))
        #expect(!OverlayPadKindResolver.shouldApplyVariant(resolved: "psx-dualshock", current: "psx-digital",
                                                           lastApplied: "psx-dualshock"))
        #expect(OverlayPadKindResolver.shouldApplyVariant(resolved: "psx-digital", current: "psx-dualshock",
                                                          lastApplied: "psx-dualshock"))
    }

    @Test("Explicit choice: per-game beats per-system; unbound or unset is nil")
    func explicitVariantID() {
        resetSettings()
        defer { resetSettings() }
        #expect(OverlayPadKindResolver.explicitVariantID(for: .Genesis, gameMD5: Self.md5) == nil)
        Defaults.setControllerLayoutVariant("genesis-3btn", forSystemID: SystemIdentifier.Genesis.rawValue)
        #expect(OverlayPadKindResolver.explicitVariantID(for: .Genesis, gameMD5: Self.md5) == "genesis-3btn")
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-6btn"]
        #expect(OverlayPadKindResolver.explicitVariantID(for: .Genesis, gameMD5: Self.md5) == "genesis-6btn")
        // A per-game choice the binding has no family for falls through to the system one.
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "wii-classic"]
        #expect(OverlayPadKindResolver.explicitVariantID(for: .Genesis, gameMD5: Self.md5) == "genesis-3btn")
        #expect(OverlayPadKindResolver.explicitVariantID(for: .RetroArch, gameMD5: Self.md5) == nil)
    }

    private func push(explicit: String? = nil, resolvedDefault: String = "psx-dualshock",
                      current: String?, saved: Bool?, lastApplied: String? = nil) -> String? {
        OverlayPadKindResolver.variantToPush(explicit: explicit, resolvedDefault: resolvedDefault,
                                             coreCurrent: current, hasSavedPortDevice: saved,
                                             lastApplied: lastApplied)
    }

    @Test("Boot push: an explicit choice is pushed whatever the port holds")
    func pushExplicit() {
        #expect(push(explicit: "psx-digital", current: "psx-dualshock", saved: true) == "psx-digital")
        #expect(push(explicit: "psx-digital", current: "psx-dualshock", saved: false) == "psx-digital")
        // Dolphin (no port devices) takes explicit choices.
        #expect(push(explicit: "wii-wiimote", resolvedDefault: "wii-wiimote-nunchuck",
                     current: "wii-wiimote-nunchuck", saved: nil) == "wii-wiimote")
        // Genesis Joypad Auto (nil read-back) still takes an explicit choice.
        #expect(push(explicit: "genesis-3btn", resolvedDefault: "genesis-6btn", current: nil, saved: false)
                == "genesis-3btn")
        // Already running it, or already pushed: nothing.
        #expect(push(explicit: "psx-digital", current: "psx-digital", saved: false) == nil)
        #expect(push(explicit: "psx-digital", current: "psx-dualshock", saved: false,
                     lastApplied: "psx-digital") == nil)
    }

    @Test("Boot push: the binding default only into an unsaved port that reports a variant")
    func pushDefault() {
        // Untouched PSX port (plain joypad = digital) with no saved choice gets DualShock.
        #expect(push(current: "psx-digital", saved: false) == "psx-dualshock")
        // A saved Port Devices choice is never overridden by a default.
        #expect(push(current: "psx-digital", saved: true) == nil)
        // Cores without port devices (Dolphin) never get a default.
        #expect(push(resolvedDefault: "wii-wiimote-nunchuck", current: "wii-wiimote", saved: nil) == nil)
        // Genesis Joypad Auto reads back nil and is left alone.
        #expect(push(resolvedDefault: "genesis-6btn", current: nil, saved: false) == nil)
        // Already running the default, or already pushed it.
        #expect(push(current: "psx-dualshock", saved: false) == nil)
        #expect(push(current: "psx-digital", saved: false, lastApplied: "psx-dualshock") == nil)
    }

    @Test("Selectable variants: the system's variants the binding has a family for, in system order")
    func selectableVariants() {
        let ids = { (system: SystemIdentifier) in OverlayPadKindResolver.selectableVariants(for: system).map(\.id) }
        #expect(ids(.Genesis) == ["genesis-3btn", "genesis-6btn"])
        #expect(ids(.PSX) == ["psx-dualshock", "psx-digital"])
        #expect(ids(.Wii) == ["wii-wiimote", "wii-wiimote-nunchuck"])
        #expect(ids(.GameCube) == ["gc-standard"])
        // NES binds only `standard`, which is no layout variant.
        #expect(ids(.NES).isEmpty)
        #expect(ids(.SNES).isEmpty)
        #expect(ids(.Atari5200).isEmpty)
    }

    @Test("The Controller Layout picker needs more than one selectable variant")
    func offersVariantChoice() {
        for system in [SystemIdentifier.Genesis, .Sega32X, .SegaCD, .PSX, .Wii] {
            #expect(OverlayPadKindResolver.offersVariantChoice(for: system), "\(system)")
        }
        for system in [SystemIdentifier.NES, .GameCube, .SNES, .Atari5200] {
            #expect(!OverlayPadKindResolver.offersVariantChoice(for: system), "\(system)")
        }
    }

    @Test("An explicit choice outside the selectable variants is not pushed")
    func explicitIgnoresUnselectable() {
        resetSettings()
        defer { resetSettings() }
        Defaults.setControllerLayoutVariant("gc-bongos", forSystemID: SystemIdentifier.GameCube.rawValue)
        #expect(OverlayPadKindResolver.explicitVariantID(for: .GameCube, gameMD5: Self.md5) == nil)
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "wii-classic"]
        #expect(OverlayPadKindResolver.explicitVariantID(for: .Wii, gameMD5: Self.md5) == nil)
    }

    @Test("A system without variants keeps its standard subtype")
    func standardSystem() {
        resetSettings()
        defer { resetSettings() }
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-6btn"]
        #expect(subtype(.SNES, nil) == OverlayPadKind.standardSubtype)
    }
}
