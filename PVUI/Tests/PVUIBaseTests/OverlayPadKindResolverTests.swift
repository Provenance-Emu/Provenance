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
        #expect(subtype(.Genesis, provider) == "genesis-3btn")
        Defaults.setControllerLayoutVariant("genesis-6btn", forSystemID: SystemIdentifier.Genesis.rawValue)
        #expect(subtype(.Genesis, provider) == "genesis-6btn")
        provider.reported = "genesis-3btn"
        #expect(subtype(.Genesis, provider) == "genesis-3btn")
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-6btn"]
        #expect(subtype(.Genesis, provider) == "genesis-6btn")
    }

    @Test("Binding defaults when nothing is set")
    func bindingDefaults() {
        resetSettings()
        defer { resetSettings() }
        #expect(subtype(.Genesis, nil) == "genesis-3btn")
        // Not `defaultControllerLayoutVariant`, which for Wii is the sideways remote.
        #expect(subtype(.Wii, nil) == "wii-wiimote-nunchuck")
        #expect(subtype(.PSX, nil) == "psx-dualshock")
    }

    @Test("An unknown candidate is skipped and resolution continues")
    func unknownSkipped() {
        resetSettings()
        defer { resetSettings() }
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "not-a-variant"]
        #expect(subtype(.Genesis, VariantProvider()) == "genesis-3btn")
        Defaults.setControllerLayoutVariant("genesis-6btn", forSystemID: SystemIdentifier.Genesis.rawValue)
        #expect(subtype(.Genesis, VariantProvider()) == "genesis-6btn")
        // Another system's variant is not a candidate for this one.
        let provider = VariantProvider()
        provider.reported = "wii-classic"
        #expect(subtype(.Genesis, provider) == "genesis-6btn")
    }

    @Test("An empty MD5 skips the per-game lookup")
    func emptyMD5() {
        resetSettings()
        defer { resetSettings() }
        Defaults[.controllerLayoutVariantsByGame] = ["": "genesis-6btn"]
        #expect(subtype(.Genesis, nil, md5: "") == "genesis-3btn")
    }

    @Test("32X and Sega CD resolve the Genesis subtypes")
    func genesisFamily() {
        resetSettings()
        defer { resetSettings() }
        Defaults.setControllerLayoutVariant("genesis-6btn", forSystemID: SystemIdentifier.Sega32X.rawValue)
        #expect(subtype(.Sega32X, nil) == "genesis-6btn")
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-6btn"]
        #expect(subtype(.SegaCD, nil) == "genesis-6btn")
        #expect(SystemIdentifier.SegaCD.availableControllerLayoutVariants == [.genesis3Button, .genesis6Button])
    }

    @Test("A system without variants keeps its standard subtype")
    func standardSystem() {
        resetSettings()
        defer { resetSettings() }
        Defaults[.controllerLayoutVariantsByGame] = [Self.md5: "genesis-6btn"]
        #expect(subtype(.SNES, nil) == OverlayPadKind.standardSubtype)
    }
}
