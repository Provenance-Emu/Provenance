// CompanionLayoutFactoryTests.swift
// PVUIBaseTests
//
// Unit tests for CompanionLayoutFactory routing logic.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Testing
@testable import PVUIBase

@Suite("CompanionLayoutFactory")
@MainActor
struct CompanionLayoutFactoryTests {

    // MARK: - System routing

    @Test("Atari 5200 maps to Atari5200Layout")
    func atari5200MapsToAtari5200Layout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.atari5200", router: router)
        #expect(layout is Atari5200Layout)
    }

    @Test("ColecoVision maps to ColecoVisionLayout")
    func colecoVisionMapsToColecoVisionLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.colecovision", router: router)
        #expect(layout is ColecoVisionLayout)
    }

    @Test("Vectrex maps to VectrexLayout")
    func vectrexMapsToVectrexLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.vectrex", router: router)
        #expect(layout is VectrexLayout)
    }

    @Test("DOS maps to DOSKeyboardLayout")
    func dosMapsToDoSKeyboardLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.dos", router: router)
        #expect(layout is DOSKeyboardLayout)
    }

    @Test("DOOM maps to DOSKeyboardLayout")
    func doomMapsToDoSKeyboardLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.doom", router: router)
        #expect(layout is DOSKeyboardLayout)
    }

    // MARK: - Fallback behaviour

    @Test("Unknown system falls back to GenericCompanionLayout")
    func unknownSystemFallsBackToGenericLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.unknown", router: router)
        #expect(layout is GenericCompanionLayout)
    }

    @Test("Atari 2600 falls back to GenericCompanionLayout (trackball not yet wired)")
    func atari2600FallsBackToGenericLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "com.provenance.2600", router: router)
        #expect(layout is GenericCompanionLayout)
    }

    @Test("Empty system ID falls back to GenericCompanionLayout")
    func emptySystemIDFallsBackToGenericLayout() {
        let router = CompanionInputRouter()
        let layout = CompanionLayoutFactory.makeLayout(systemID: "", router: router)
        #expect(layout is GenericCompanionLayout)
    }
}
#endif // !os(tvOS)
