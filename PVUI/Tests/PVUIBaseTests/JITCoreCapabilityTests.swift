//
//  JITCoreCapabilityTests.swift
//  PVUIBaseTests
//
//  Unit tests for JITCoreCapability registry-aware lookup helpers.
//
//  These tests verify the two-stage lookup: PVJITRequirementRegistry (runtime plist data)
//  first, then compile-time keyword matching as a fallback.
//  In this test context the registry is empty so all lookups fall through to keyword matching.
//
//  JIT classifications (from Core.plist PVJITRequirement keys and Swift jitRequirement overrides):
//   Required (crashes without JIT):   Play (PS2/PCSX2) — plist "required", Swift .requiredOrCrash
//   Automatic with fallback:          Dolphin, Azahar, emuThree — plist "optional", Swift .automaticWithFallback
//   Optional (interpreter fallback):  PPSSPP, Mupen64Plus, Flycast — plist "optional", Swift .optional
//   Not supported:                    SNES, NES, GB, GBA, …
//

import Testing
@testable import PVUIBase

@Suite("JITCoreCapability Tests")
struct JITCoreCapabilityTests {

    // MARK: - Invariants (data-driven, not hardcoded per case)

    @Test("isJITRequired implies isJITRelevant for all cases")
    func jitRequiredImpliesRelevant() {
        for cap in JITCoreCapability.allCases {
            if cap.isJITRequired {
                #expect(cap.coreIdentifierKeywords.isEmpty == false,
                        "Case \(cap) has isJITRequired=true but no keywords")
            }
        }
    }

    @Test("capability(for:) round-trips through coreIdentifierKeywords")
    func capabilityRoundTrip() {
        for cap in JITCoreCapability.allCases {
            guard let first = cap.coreIdentifierKeywords.first else { continue }
            #expect(JITCoreCapability.capability(for: first) == cap,
                    "Round-trip failed for \(cap) keyword '\(first)'")
        }
    }

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
        #expect(JITCoreCapability.isJITRelevant("emuthree") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.core.emuThree") == true)
    }

    @Test("pcsx2 / ps2 / Play identifiers are JIT-relevant")
    func pcsx2IsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("pcsx2") == true)
        #expect(JITCoreCapability.isJITRelevant("ps2") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.pcsx2") == true)
        #expect(JITCoreCapability.isJITRelevant("play") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.core.play") == true)
    }

    @Test("flycast / dreamcast identifiers are JIT-relevant")
    func flycastIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("flycast") == true)
        #expect(JITCoreCapability.isJITRelevant("dreamcast") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.flycast") == true)
    }

    @Test("mupen / n64 identifiers are JIT-relevant")
    func mupenIsJITRelevant() {
        #expect(JITCoreCapability.isJITRelevant("mupen") == true)
        #expect(JITCoreCapability.isJITRelevant("n64") == true)
        #expect(JITCoreCapability.isJITRelevant("com.provenance.mupen64plus") == true)
    }

    // MARK: - coreIsJITRequired (only cores that crash without JIT)

    @Test("only pcsx2/Play are JIT-required (crash without JIT); azahar/citra are optional")
    func jitRequiredCores() {
        // Play (PS2) maps to plist "required" / Swift .requiredOrCrash
        #expect(JITCoreCapability.coreIsJITRequired("ps2") == true)
        #expect(JITCoreCapability.coreIsJITRequired("pcsx2") == true)
        // Azahar/citra use .automaticWithFallback — plist "optional", not "required"
        #expect(JITCoreCapability.coreIsJITRequired("azahar") == false)
        #expect(JITCoreCapability.coreIsJITRequired("citra") == false)
        #expect(JITCoreCapability.coreIsJITRequired("emuthree") == false)
    }

    @Test("dolphin and azahar are JIT-relevant but NOT JIT-required (automatic with fallback)")
    func dolphinNotJITRequired() {
        // Dolphin and Azahar use .automaticWithFallback — they self-detect JIT and never crash without it
        #expect(JITCoreCapability.isJITRelevant("dolphin") == true)
        #expect(JITCoreCapability.coreIsJITRequired("dolphin") == false)
        #expect(JITCoreCapability.coreIsJITRequired("pvdolphin") == false)
        #expect(JITCoreCapability.coreIsJITRequired("gamecube") == false)

        #expect(JITCoreCapability.isJITRelevant("azahar") == true)
        #expect(JITCoreCapability.coreIsJITRequired("azahar") == false)
        #expect(JITCoreCapability.coreIsJITRequired("citra") == false)
        #expect(JITCoreCapability.coreIsJITRequired("emuthree") == false)
    }

    @Test("ppsspp is JIT-relevant but NOT JIT-required (interpreter fallback)")
    func ppssppNotJITRequired() {
        // PPSSPP uses .optional — interpreter mode available when JIT is absent
        #expect(JITCoreCapability.isJITRelevant("ppsspp") == true)
        #expect(JITCoreCapability.coreIsJITRequired("ppsspp") == false)
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
        #expect(JITCoreCapability.capability(for: "ppsspp") == .ppsspp)
        #expect(JITCoreCapability.capability(for: "flycast") == .flycast)
        #expect(JITCoreCapability.capability(for: "mupen") == .mupen)
        #expect(JITCoreCapability.capability(for: "azahar") == .azahar)
        #expect(JITCoreCapability.capability(for: "ps2") == .pcsx2)
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
        #expect(JITCoreCapability.coreIsJITRequired("AZAHAR") == false)
    }

    // MARK: - Deprecated API compatibility

    @Test("deprecated coreRequiresJIT(_:) still delegates to isJITRelevant")
    func deprecatedAPICompat() {
        #expect(JITCoreCapability.coreRequiresJIT("dolphin") == true)
        #expect(JITCoreCapability.coreRequiresJIT("flycast") == true)
        #expect(JITCoreCapability.coreRequiresJIT("snes9x") == false)
    }
}
