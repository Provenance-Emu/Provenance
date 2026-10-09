//
//  Batch3HandlerTokenTests.swift
//  PVUIBaseTests
//
//  A batch 3 overlay token reaches the core through `DeltaSkinInputHandler.normalizeSkinButtonId` and then
//  the system's button enum. The binding tests check the enum alone; these check that the normaliser leaves
//  every token on the button it names.
//

import Foundation
import Testing
import PVCoreBridge
import PVSystems
import PVTouchOverlay
@testable import PVUIBase

@Suite("Batch 3 handler tokens") @MainActor
struct Batch3HandlerTokenTests {
    /// The enum `DeltaSkinInputHandler.trySystemResponderCall` builds for each batch 3 system.
    private static func buttonType(_ system: SystemIdentifier) -> any EmulatorCoreButton.Type {
        switch system {
        case .AtariST, .DOS, .Quake, .Quake2, .C64, .ZXSpectrum, .Macintosh, .PalmOS, .AppleII, .PC98:
            return PVDOSButton.self
        case .MegaDuck: return PVGBButton.self
        case .FDS: return PVNESButton.self
        case .GameGear: return PVGenesisButton.self
        case .TIC80: return PVTIC80Button.self
        default: return system.controllerType
        }
    }

    @Test("The normaliser keeps every binding token and d-pad direction on its button",
          arguments: SystemOverlayBindings.batch3Systems)
    func normaliserKeepsTokens(system: SystemIdentifier) throws {
        let handler = DeltaSkinInputHandler()
        let type = Self.buttonType(system)
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for (slot, token) in binding.tokens {
            let normalised = handler.normalizeSkinButtonId(token, for: system)
            #expect(type.init(normalised).rawValue == type.init(token).rawValue,
                    "\(system) \(slot.rawValue): \(token) -> \(normalised) changes the button")
        }
        let directions = ["up", "down", "left", "right"]
        let buttons = directions.map { type.init(handler.normalizeSkinButtonId($0, for: system)).rawValue }
        #expect(Set(buttons).count == 4, "\(system) d-pad directions collapse: \(buttons)")
    }

    @Test("Supervision A and B reach the top and bottom-left actions, not the d-pad")
    func supervision() {
        let handler = DeltaSkinInputHandler()
        #expect(PVSupervisionButton(handler.normalizeSkinButtonId("a", for: .Supervision)) == .topAction)
        #expect(PVSupervisionButton(handler.normalizeSkinButtonId("b", for: .Supervision)) == .bottomLeftAction)
        #expect(PVSupervisionButton(handler.normalizeSkinButtonId("start", for: .Supervision)) == .enter)
        #expect(PVSupervisionButton(handler.normalizeSkinButtonId("select", for: .Supervision)) == .clear)
    }

    @Test("Mega Duck keeps the Game Boy normalisation")
    func megaDuck() {
        let handler = DeltaSkinInputHandler()
        #expect(["a", "b", "start", "select"].map { handler.normalizeSkinButtonId($0, for: .MegaDuck) }
                == ["a", "b", "start", "select"])
    }
}
