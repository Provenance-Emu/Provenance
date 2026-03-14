//
//  JITCoreCapabilityTests.swift
//  PVUIBaseTests
//
//  Unit tests for JITCoreCapability.coreRequiresJIT(_:).
//  Locks in expected true/false results so regressions are caught
//  when new core keywords are added.
//

import Testing
@testable import PVUIBase

@Suite("JITCoreCapability Tests")
struct JITCoreCapabilityTests {

    // MARK: - Cores that require JIT

    @Test("dolphin identifiers are JIT-required")
    func dolphinRequiresJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("pvdolphin") == true)
        #expect(JITCoreCapability.coreRequiresJIT("dolphin") == true)
        #expect(JITCoreCapability.coreRequiresJIT("com.provenance.dolphin") == true)
        #expect(JITCoreCapability.coreRequiresJIT("gamecube") == true)
        #expect(JITCoreCapability.coreRequiresJIT("wii") == true)
    }

    @Test("ppsspp identifier is JIT-required")
    func ppssppRequiresJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("ppsspp") == true)
        #expect(JITCoreCapability.coreRequiresJIT("com.provenance.ppsspp") == true)
    }

    @Test("azahar / citra / 3ds identifiers are JIT-required")
    func azaharRequiresJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("azahar") == true)
        #expect(JITCoreCapability.coreRequiresJIT("citra") == true)
        #expect(JITCoreCapability.coreRequiresJIT("3ds") == true)
        #expect(JITCoreCapability.coreRequiresJIT("com.provenance.azahar") == true)
    }

    @Test("pcsx2 identifier is JIT-required")
    func pcsx2RequiresJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("pcsx2") == true)
        #expect(JITCoreCapability.coreRequiresJIT("ps2") == true)
        #expect(JITCoreCapability.coreRequiresJIT("com.provenance.pcsx2") == true)
    }

    // MARK: - Cores that do NOT require JIT

    @Test("snes9x does not require JIT")
    func snes9xDoesNotRequireJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("snes9x") == false)
        #expect(JITCoreCapability.coreRequiresJIT("com.provenance.snes9x") == false)
    }

    @Test("nestopia / nes does not require JIT")
    func nestopiaDoesNotRequireJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("nestopia") == false)
        #expect(JITCoreCapability.coreRequiresJIT("fceux") == false)
    }

    @Test("gambatte does not require JIT")
    func gambatteDoesNotRequireJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("gambatte") == false)
        #expect(JITCoreCapability.coreRequiresJIT("com.provenance.gambatte") == false)
    }

    @Test("empty string does not require JIT")
    func emptyStringDoesNotRequireJIT() {
        #expect(JITCoreCapability.coreRequiresJIT("") == false)
    }

    // MARK: - Case-insensitivity

    @Test("lookup is case-insensitive")
    func lookupCaseInsensitive() {
        #expect(JITCoreCapability.coreRequiresJIT("PVDOLPHIN") == true)
        #expect(JITCoreCapability.coreRequiresJIT("PPSSPP") == true)
        #expect(JITCoreCapability.coreRequiresJIT("SNES9X") == false)
    }
}
