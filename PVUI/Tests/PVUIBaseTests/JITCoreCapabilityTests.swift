//
//  JITCoreCapabilityTests.swift
//  PVUIBaseTests
//
//  Unit tests for JITCoreCapability lookup helpers.
//  Locks in expected true/false results so regressions are caught
//  when new core keywords are added.
//

import Testing
@testable import PVUIBase

@Suite("JITCoreCapability Tests")
struct JITCoreCapabilityTests {

    // MARK: - isJITRelevant (any core that uses JIT at all)

    @Test("dolphin identifiers are JIT-relevant")
    func dolphinIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("pvdolphin") == true)
        #expect(JITCoreCapability.isJITRelevant("dolphin") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.dolphin") == true)
        #expect(JITCoreCapability.isJITRelevant("gamecube") == true)
        #expect(JITCoreCapability.isJITRelevant("wii") == true)
    }

    @Test("ppsspp identifier is JIT-relevant")
    func ppssppIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("ppsspp") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.ppsspp") == true)
    }

    @Test("azahar / citra / 3ds identifiers are JIT-relevant")
    func azaharIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("azahar") == true)
        #expect(JITCoreCapability.isJITRelevant("citra") == true)
        #expect(JITCoreCapability.isJITRelevant("3ds") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.azahar") == true)
    }

    @Test("pcsx2 identifier is JIT-relevant")
    func pcsx2IsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("pcsx2") == true)
        #expect(JITCoreCapability.isJITRelevant("ps2") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.pcsx2") == true)
    }

    @Test("flycast / dreamcast identifiers are JIT-relevant (recommended, not required)")
    func flycastIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("flycast") == true)
        #expect(JITCoreCapability.isJITRelevant("dreamcast") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.flycast") == true)
    }

    @Test("mupen / n64 identifiers are JIT-relevant (recommended, not required)")
    func mupenIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("mupen") == true)
        #expect(JITCoreCapability.isJITRelevant("n64") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.mupen64plus") == true)
    }

    // MARK: - coreIsJITRequired (only cores that need JIT for playable performance)

    @Test("dolphin, ppsspp, azahar, pcsx2 are JIT-required")
    func jitRequiredCores() {
        #expect(JITCoreCapability.coreIsJITRequired("pvdolphin") == true)
        #expect(JITCoreCapability.coreIsJITRequired("ppsspp") == true)
        #expect(JITCoreCapability.coreIsJITRequired("azahar") == true)
        #expect(JITCoreCapability.coreIsJITRequired("citra") == true)
        #expect(JITCoreCapability.coreIsJITRequired("pcsx2") == true)
        #expect(JITCoreCapability.coreIsJITRequired("ps2") == true)
    }

    @Test("flycast and mupen are JIT-relevant but NOT JIT-required")
    func jitRecommendedNotRequired() {
        #expect(JITCoreCapability.isJITRelevant("flycast") == true)
        #expect(JITCoreCapability.coreIsJITRequired("flycast") == false)

        #expect(JITCoreCapability.isJITRelevant("mupen") == true)
        #expect(JITCoreCapability.coreIsJITRequired("mupen") == false)

        #expect(JITCoreCapability.isJITRelevant("dreamcast") == true)
        #expect(JITCoreCapability.coreIsJITRequired("dreamcast") == false)

        #expect(JITCoreCapability.isJITRelevant("n64") == true)
        #expect(JITCoreCapability.coreIsJITRequired("n64") == false)
    }

    // MARK: - Cores that are NOT JIT-relevant

    @Test("snes9x is not JIT-relevant")
    func snes9xNotJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("snes9x") == false)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.snes9x") == false)
        #expect(JITCoreCapability.coreIsJITRequired("snes9x") == false)
    }

    @Test("nestopia / nes is not JIT-relevant")
    func nestopiaNotJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("nestopia") == false)
        #expect(JITCoreCapability.isJITRelevant("fceux") == false)
    }

    @Test("gambatte is not JIT-relevant")
    func gambatteNotJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("gambatte") == false)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.gambatte") == false)
    }

    @Test("empty string is not JIT-relevant")
    func emptyStringNotJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("") == false)
        #expect(JITCoreCapability.coreIsJITRequired("") == false)
    }

    // MARK: - capability(for:) lookup

    @Test("capability(for:) returns the correct case")
    func capabilityLookup() {
        #expect(JITCoreCapability.capability(for: "dolphin") == .dolphin)
        #expect(JITCoreCapability.capability(for: "flycast") == .flycast)
        #expect(JITCoreCapability.capability(for: "mupen") == .mupen)
        #expect(JITCoreCapability.capability(for: "snes9x") == nil)
    }

    // MARK: - Case-insensitivity

    @Test("lookup is case-insensitive")
    func lookupCaseInsensitive() {
        #expect(JITCoreCapability.isJITRelevant("PVDOLPHIN") == true)
        #expect(JITCoreCapability.isJITRelevant("PPSSPP") == true)
        #expect(JITCoreCapability.isJITRelevant("FLYCAST") == true)
        #expect(JITCoreCapability.isJITRelevant("SNES9X") == false)
        #expect(JITCoreCapability.coreIsJITRequired("FLYCAST") == false)
    }

    // MARK: - Deprecated API compatibility

    @Test("deprecated coreRequiresJIT(_:) still delegates to isJITRelevant")
    func deprecatedAPICompat() {
        #expect(JITCoreCapability.coreRequiresJIT("dolphin") == true)
        #expect(JITCoreCapability.coreRequiresJIT("flycast") == true)
        #expect(JITCoreCapability.coreRequiresJIT("snes9x") == false)
    }
}
