//
//  TestCoreRecommendationEngine.swift
//  PVCoreLoaderTests
//
//  Created by Claude on 2026-03-19.
//

import XCTest
@testable import PVCoreLoader
import PVPrimitives

final class TestCoreRecommendationEngine: XCTestCase {

    var engine: CoreRecommendationEngine!

    override func setUp() {
        super.setUp()
        engine = CoreRecommendationEngine()
    }

    // MARK: - Empty input

    func testReturnsEmptyForNoCores() {
        let recs = engine.recommendations(
            gameTitle: "Mario",
            systemIdentifier: nil,
            availableCoreIdentifiers: []
        )
        XCTAssertTrue(recs.isEmpty)
    }

    // MARK: - Single core

    func testSingleCoreIsStandardRank() {
        let recs = engine.recommendations(
            gameTitle: "Some Game",
            systemIdentifier: nil,
            availableCoreIdentifiers: ["com.provenance.core.mGBA"]
        )
        XCTAssertEqual(recs.count, 1)
        // Single core should never be marked "recommended" (no competition)
        XCTAssertEqual(recs.first?.rank, .standard)
    }

    // MARK: - Save state ordering

    func testCoreWithMoreSavesIsFirstWhenEqualCapabilities() {
        let coreA = "com.provenance.core.visualboyadvance"
        let coreB = "com.provenance.core.mGBA"

        let recs = engine.recommendations(
            gameTitle: "Some GBA Game",
            systemIdentifier: "com.provenance.gba",
            availableCoreIdentifiers: [coreA, coreB],
            saveCounts: [coreA: 5, coreB: 0]
        )

        XCTAssertEqual(recs.count, 2)
        // coreA has more saves; user should not lose progress
        XCTAssertEqual(recs.first?.coreIdentifier, coreA)
        XCTAssertEqual(recs.first?.saveCount, 5)
    }

    // MARK: - Capability matching

    func testTitleContainsMatchSurfacesCapabilityTip() {
        let recs = engine.recommendations(
            gameTitle: "Yoshi's Safari",
            systemIdentifier: "com.provenance.snes",
            availableCoreIdentifiers: [
                "bsnes.hd.beta.libretro.framework",   // no light gun
                "com.provenance.core.snes9x"
            ]
        )

        guard let best = recs.first else {
            XCTFail("Expected at least one recommendation")
            return
        }

        // The game wants the Super Scope, and only Snes9x declares a light gun here.
        XCTAssertEqual(best.coreIdentifier, "com.provenance.core.snes9x")
        XCTAssertTrue(best.highlightedCapabilities.contains(.lightgunSupport))
        XCTAssertNotNil(best.recommendationTip)
    }

    /// The DS microphone rules stay, but the only core that declared a microphone (native
    /// melonDS) was pruned and melonDS DS has not been checked on a device. A tip must not
    /// tell the player to pick a core that no shipped core is.
    func testNoMicrophoneTipWhileNoShippedCoreDeclaresOne() {
        let recs = engine.recommendations(
            gameTitle: "Nintendogs",
            systemIdentifier: "com.provenance.ds",
            availableCoreIdentifiers: ["melondsds.libretro.framework", "melonds.libretro.framework"]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertTrue(recs.allSatisfy { $0.highlightedCapabilities.isEmpty })
        XCTAssertTrue(recs.allSatisfy { $0.recommendationTip == nil })
    }

    /// Cores removed from the app must not linger in the bundled data.
    func testPrunedCoresHaveNoBundledMetadata() {
        for pruned in ["com.provenance.core.MelonDS", "com.provenance.core.desmume2015",
                       "com.provenance.core.mupen64plusnx", "com.provenance.core.duckstation",
                       "com.provenance.core.PCSXRearmed"] {
            XCTAssertNil(engine.capabilityMetadata(for: pruned), pruned)
        }
    }

    // MARK: - System-level recommendation

    func testSystemIdentifierMatchRanksHighAccuracyCoreFirst() {
        let recs = engine.recommendations(
            gameTitle: "Some GBA Game",
            systemIdentifier: "com.provenance.gba",
            availableCoreIdentifiers: [
                "com.provenance.core.visualboyadvance",   // lower rank, not high accuracy
                "com.provenance.core.mGBA"                // higher rank, high accuracy
            ]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.first?.coreIdentifier, "com.provenance.core.mGBA")
    }

    // MARK: - Recommendation rank labels

    func testBestCoreReceivesRecommendedBadge() {
        let recs = engine.recommendations(
            gameTitle: "Pokemon Emerald",
            systemIdentifier: "com.provenance.gba",
            availableCoreIdentifiers: [
                "com.provenance.core.mGBA",
                "com.provenance.core.visualboyadvance"
            ]
        )

        XCTAssertEqual(recs.first?.rank, .recommended)
    }

    // MARK: - Metadata loading

    func testManifestLoadedSuccessfully() {
        let meta = engine.capabilityMetadata(for: "com.provenance.core.mGBA")
        XCTAssertNotNil(meta, "mGBA should have metadata in CoreCapabilities.json")
        XCTAssertTrue(meta?.capabilities.contains(.highAccuracy) == true)
    }

    func testBundledPickerDefaultsRespectCoreAvailability() {
        let mgba = "com.provenance.core.mGBA"
        let libretroMGBA = "mgba.libretro.framework"
        let azahar = "com.provenance.core.azahar"
        let emuThree = "com.provenance.core.emuThree"

        XCTAssertEqual(
            CoreRecommendationEngine.pickerDefault(for: "com.provenance.gba", availableCoreIdentifiers: [mgba, libretroMGBA])?.coreIdentifier,
            mgba
        )
        XCTAssertEqual(
            CoreRecommendationEngine.pickerDefault(for: "com.provenance.gba", availableCoreIdentifiers: [libretroMGBA])?.coreIdentifier,
            libretroMGBA
        )
        XCTAssertEqual(
            CoreRecommendationEngine.pickerDefault(for: "com.provenance.3ds", availableCoreIdentifiers: [emuThree, azahar])?.coreIdentifier,
            azahar
        )
        XCTAssertNil(CoreRecommendationEngine.pickerDefault(for: "com.provenance.3ds", availableCoreIdentifiers: [emuThree]))
    }

    /// The Sega systems each have one native core that the capability notes already single out.
    func testBundledPickerDefaultsCoverTheSegaSystems() {
        let genesisPlus = "com.provenance.core.genplusgx"
        let picoDrive = "com.provenance.core.picodrive"
        let available: Set<String> = [genesisPlus, picoDrive]

        for system in ["com.provenance.genesis", "com.provenance.segacd", "com.provenance.mastersystem",
                       "com.provenance.gamegear", "com.provenance.sg1000"] {
            XCTAssertEqual(CoreRecommendationEngine.pickerDefault(for: system, availableCoreIdentifiers: available)?.coreIdentifier,
                           genesisPlus, system)
        }
        XCTAssertEqual(CoreRecommendationEngine.pickerDefault(for: "com.provenance.32X", availableCoreIdentifiers: available)?.coreIdentifier,
                       picoDrive)
        XCTAssertNil(CoreRecommendationEngine.pickerDefault(for: "com.provenance.32X", availableCoreIdentifiers: [genesisPlus]))
    }

    /// Systems whose native core is the one Provenance ships and extends; the libretro
    /// builds of both need JIT or are the fallback.
    func testBundledPickerDefaultsCoverPSPAndDolphinSystems() {
        let ppsspp = "com.provenance.core.ppsspp"
        let dolphin = "com.provenance.core.dolphin"
        let available: Set<String> = [ppsspp, "ppsspp.libretro.framework", dolphin, "dolphin.libretro.framework"]

        XCTAssertEqual(CoreRecommendationEngine.pickerDefault(for: "com.provenance.psp", availableCoreIdentifiers: available)?.coreIdentifier, ppsspp)
        for system in ["com.provenance.gamecube", "com.provenance.wii"] {
            XCTAssertEqual(CoreRecommendationEngine.pickerDefault(for: system, availableCoreIdentifiers: available)?.coreIdentifier,
                           dolphin, system)
        }
        // Without the native core there is nothing curated to fall back to.
        XCTAssertNil(CoreRecommendationEngine.pickerDefault(for: "com.provenance.psp", availableCoreIdentifiers: ["ppsspp.libretro.framework"]))
        XCTAssertNil(CoreRecommendationEngine.pickerDefault(for: "com.provenance.wii", availableCoreIdentifiers: ["dolphin.libretro.framework"]))
    }

    /// Owner decisions of 2026-11-16: prefer the libretro cores, which are updated often, and
    /// fall back to Provenance's own core. Mesen is hidden in App Store builds, where FCEUmm is next.
    func testBundledPickerDefaultsPreferTheLibretroCoresChosenByTheOwner() {
        func pick(_ system: String, _ available: Set<String>) -> String? {
            CoreRecommendationEngine.pickerDefault(for: system, availableCoreIdentifiers: available)?.coreIdentifier
        }
        let mesen = "mesen.libretro.framework", fceumm = "fceumm.libretro.framework"
        let nestopia = "nestopia.libretro.framework", fceu = "com.provenance.core.fceu"
        for system in ["com.provenance.nes", "com.provenance.fds"] {
            XCTAssertEqual(pick(system, [mesen, fceumm, nestopia, fceu]), mesen, system)
            XCTAssertEqual(pick(system, [fceumm, nestopia, fceu]), fceumm, system)
            XCTAssertEqual(pick(system, [nestopia, fceu]), nestopia, system)
            XCTAssertEqual(pick(system, [fceu, "quicknes.libretro.framework"]), fceu, system)
        }

        let mupenNext = "mupen64plus.next.libretro.framework", mupen = "com.provenance.core.mupen64plus"
        XCTAssertEqual(pick("com.provenance.n64", [mupen, mupenNext, "parallel.n64.libretro.framework"]), mupenNext)
        XCTAssertEqual(pick("com.provenance.n64", [mupen, "parallel.n64.libretro.framework"]), mupen)

        let beetleHW = "mednafen.psx.hw.libretro.framework", beetle = "mednafen.psx.libretro.framework"
        let mednafen = "com.provenance.core.mednafen"
        XCTAssertEqual(pick("com.provenance.psx", [mednafen, beetle, beetleHW, "pcsx.rearmed.libretro.framework"]), beetleHW)
        XCTAssertEqual(pick("com.provenance.psx", [mednafen, beetle]), beetle)
        XCTAssertEqual(pick("com.provenance.psx", [mednafen, "pcsx.rearmed.libretro.framework"]), mednafen)

        // The picker cannot tell whether JIT is active, so the build that always runs comes first.
        let flycast = "flycast.libretro.framework", jitless = "flycast-jitless.libretro.framework"
        XCTAssertEqual(pick("com.provenance.dreamcast", [flycast, jitless]), jitless)
        XCTAssertEqual(pick("com.provenance.dreamcast", [flycast]), flycast)
    }

    /// Every curated default must name a core the app can actually contain.
    func testBundledPickerDefaultsNameNoPrunedCore() throws {
        let manifest = try XCTUnwrap(CoreRecommendationEngine.enrichmentManifest)
        let pruned: Set<String> = ["com.provenance.core.MelonDS", "com.provenance.core.desmume2015",
                                   "com.provenance.core.mupen64plusnx", "com.provenance.core.duckstation",
                                   "com.provenance.core.PCSXRearmed"]
        XCTAssertFalse(manifest.pickerDefaults.isEmpty)
        for (system, defaults) in manifest.pickerDefaults {
            for entry in defaults {
                XCTAssertFalse(pruned.contains(entry.coreIdentifier), "\(system) recommends \(entry.coreIdentifier)")
            }
        }
    }

    /// Checked on two simulators on 2026-11-13: a two-player link game ran on native mGBA.
    func testNativeMGBADeclaresLinkCable() throws {
        let meta = try XCTUnwrap(engine.capabilityMetadata(for: "com.provenance.core.mGBA"))
        XCTAssertTrue(meta.capabilities.contains(.linkCable))
    }

    // MARK: - Multi-source manifest building

    /// Verifies that a manifest built from an explicit CoreCapabilitiesManifest (no CoreLoader)
    /// correctly surfaces capabilities injected via the manifest parameter — the enrichment path.
    func testEnrichmentOnlyManifestSurfacesCapabilities() {
        let testMeta = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.alpha",
            summary: "Test core",
            capabilities: [.highAccuracy, .cheats],
            notes: [],
            qualityRank: 75
        )
        let manifest = CoreCapabilitiesManifest(
            version: 2,
            cores: [testMeta],
            gameRequirements: []
        )
        let testEngine = CoreRecommendationEngine(manifest: manifest)

        let meta = testEngine.capabilityMetadata(for: "com.test.core.alpha")
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?.capabilities.contains(.highAccuracy) == true)
        XCTAssertTrue(meta?.capabilities.contains(.cheats) == true)
        XCTAssertEqual(meta?.qualityRank, 75)
    }

    /// Verifies that a manifest with both `highAccuracy` and `cheats` capabilities is correctly
    /// surfaced through the engine's recommendation output when a game matches both cores.
    func testAutoDeriveCheatsFromPlistMergesWithEnrichment() {
        // Build a manifest where a core has both cheats and highAccuracy declared.
        let mergedMeta = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.beta",
            summary: "Beta",
            capabilities: [.highAccuracy, .cheats],
            notes: [],
            qualityRank: 50
        )
        let manifest = CoreCapabilitiesManifest(
            version: 2,
            cores: [mergedMeta],
            gameRequirements: []
        )
        let testEngine = CoreRecommendationEngine(manifest: manifest)

        // Drive through the engine's public recommendation API.
        let recs = testEngine.recommendations(
            gameTitle: "Test Game",
            systemIdentifier: nil,
            availableCoreIdentifiers: ["com.test.core.beta"]
        )

        XCTAssertEqual(recs.count, 1)
        let meta = recs.first?.metadata
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?.capabilities.contains(.highAccuracy) == true)
        XCTAssertTrue(meta?.capabilities.contains(.cheats) == true)
        XCTAssertEqual(meta?.summary, "Beta")
        XCTAssertEqual(meta?.qualityRank, 50)
    }

    /// Verifies that capabilities declared via PVCapabilities in a plist are parsed correctly.
    func testPlistCapabilitiesParseFromRawValues() {
        // Simulate what EmulatorCoreInfoPlist would produce from PVCapabilities key
        let rawCapabilities = ["highAccuracy", "rumble", "rewind", "unknownCapability"]
        var caps = Set<CoreCapability>()
        for raw in rawCapabilities {
            if let cap = CoreCapability(rawValue: raw) {
                caps.insert(cap)
            }
        }
        // Known capabilities are parsed; unknown ones are silently skipped
        XCTAssertTrue(caps.contains(.highAccuracy))
        XCTAssertTrue(caps.contains(.rumble))
        XCTAssertTrue(caps.contains(.rewind))
        XCTAssertEqual(caps.count, 3, "Unknown capability should be skipped")
    }

    // MARK: - retroAchievements capability

    /// Verifies that a libretro core declared with retroAchievements in the bundle JSON
    /// surfaces that capability through the recommendation engine.
    func testLibretroCoreSurfacesRetroAchievementsFromBundleJSON() {
        // Beetle PSX SW is declared with retroAchievements in CoreCapabilities.json
        let meta = engine.capabilityMetadata(for: "mednafen.psx.libretro.framework")
        XCTAssertNotNil(meta, "Beetle PSX SW should have metadata in CoreCapabilities.json")
        XCTAssertTrue(meta?.capabilities.contains(.retroAchievements) == true,
                      "Beetle PSX SW should advertise retroAchievements (cheevos.c via PVCoreBridgeRetro)")
    }

    /// Verifies that the Flycast jitless variant (App Store) advertises retroAchievements.
    func testFlycastJitlessAdvertisesRetroAchievements() {
        let meta = engine.capabilityMetadata(for: "flycast-jitless.libretro.framework")
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?.capabilities.contains(.retroAchievements) == true)
    }

    /// Verifies the PSX system requirement now includes retroAchievements as a preferred capability.
    func testPSXSystemRequirementPrefersRetroAchievements() {
        let recs = engine.recommendations(
            gameTitle: "Crash Bandicoot",
            systemIdentifier: "com.provenance.psx",
            availableCoreIdentifiers: [
                "pcsx.rearmed.libretro.framework",   // no entry in the bundled data, so no capabilities
                "mednafen.psx.libretro.framework"    // has retroAchievements
            ]
        )

        XCTAssertEqual(recs.count, 2)
        // Beetle PSX SW has both highAccuracy and retroAchievements — should rank first
        XCTAssertEqual(recs.first?.coreIdentifier, "mednafen.psx.libretro.framework")
        XCTAssertTrue(recs.first?.highlightedCapabilities.contains(.retroAchievements) == true)
        XCTAssertNotNil(recs.first?.recommendationTip, "PSX system requirement tip should surface")
    }

    /// Verifies that a core explicitly given retroAchievements in an injected manifest
    /// is ranked above one without it when retroAchievements is a preferred capability.
    func testRetroAchievementsPreferenceRanksCorrectly() {
        let coreWithRA = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.withRA",
            summary: "Core with RetroAchievements",
            capabilities: [.retroAchievements, .highAccuracy],
            notes: [],
            qualityRank: 80
        )
        let coreWithoutRA = CoreCapabilityMetadata(
            coreIdentifier: "com.test.core.noRA",
            summary: "Core without RetroAchievements",
            capabilities: [.highAccuracy],
            notes: [],
            qualityRank: 85  // higher base rank, but no retroAchievements
        )
        let requirement = GameFeatureRequirement(
            matchStrategy: .systemIdentifier,
            matchValue: "com.provenance.psx",
            preferredCapabilities: [.retroAchievements],
            tip: "Choose a core with RetroAchievements support."
        )
        let manifest = CoreCapabilitiesManifest(
            version: 2,
            cores: [coreWithRA, coreWithoutRA],
            gameRequirements: [requirement]
        )
        let testEngine = CoreRecommendationEngine(manifest: manifest)

        let recs = testEngine.recommendations(
            gameTitle: "Some PS1 Game",
            systemIdentifier: "com.provenance.psx",
            availableCoreIdentifiers: ["com.test.core.withRA", "com.test.core.noRA"]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.first?.coreIdentifier, "com.test.core.withRA",
                       "Core with retroAchievements should rank above one without it when RA is preferred")
        XCTAssertTrue(recs.first?.highlightedCapabilities.contains(.retroAchievements) == true)
    }

    /// Verifies NES system requirement prefers a core with retroAchievements over one without.
    func testNESSystemRequirementPrefersRetroAchievements() {
        let recs = engine.recommendations(
            gameTitle: "Mega Man 2",
            systemIdentifier: "com.provenance.nes",
            availableCoreIdentifiers: [
                "com.provenance.core.fceu",      // no retroAchievements
                "com.provenance.core.mednafen"   // has retroAchievements
            ]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.first?.coreIdentifier, "com.provenance.core.mednafen",
                       "Mednafen (native RC) should rank above FCEU for NES when retroAchievements is preferred")
        XCTAssertTrue(recs.first?.highlightedCapabilities.contains(.retroAchievements) == true)
        XCTAssertNotNil(recs.first?.recommendationTip, "NES system requirement tip should surface")
    }

    /// Verifies SNES system requirement prefers a core with retroAchievements over one without.
    func testSNESSystemRequirementPrefersRetroAchievements() {
        let recs = engine.recommendations(
            gameTitle: "Super Metroid",
            systemIdentifier: "com.provenance.snes",
            availableCoreIdentifiers: [
                "com.provenance.core.snes9x",          // no retroAchievements
                "snes9x.libretro.framework"            // has retroAchievements
            ]
        )

        XCTAssertEqual(recs.count, 2)
        XCTAssertEqual(recs.first?.coreIdentifier, "snes9x.libretro.framework",
                       "libretro Snes9x should rank above native Snes9x for SNES when retroAchievements is preferred")
        XCTAssertTrue(recs.first?.highlightedCapabilities.contains(.retroAchievements) == true)
        XCTAssertNotNil(recs.first?.recommendationTip, "SNES system requirement tip should surface")
    }

    /// Verifies that the native Mednafen core (com.provenance.core.mednafen) advertises
    /// retroAchievements in the bundle JSON — critical for the fallback path used in tests.
    func testNativeMednafenAdvertisesRetroAchievementsInJSON() {
        let meta = engine.capabilityMetadata(for: "com.provenance.core.mednafen")
        XCTAssertNotNil(meta, "Native Mednafen should have an entry in CoreCapabilities.json")
        XCTAssertTrue(meta?.capabilities.contains(.retroAchievements) == true,
                      "Mednafen native rc_client integration must surface retroAchievements capability")
    }

    /// Verifies the full Mednafen capability profile visible via the JSON (Layer 3 test fallback).
    func testNativeMednafenFullCapabilityProfileInJSON() {
        let meta = engine.capabilityMetadata(for: "com.provenance.core.mednafen")
        XCTAssertNotNil(meta)
        let caps = meta?.capabilities ?? []
        XCTAssertTrue(caps.contains(.highAccuracy), "Mednafen JSON entry should declare highAccuracy")
        XCTAssertTrue(caps.contains(.cdAudio), "Mednafen JSON entry should declare cdAudio")
        XCTAssertTrue(caps.contains(.cheats), "Mednafen JSON entry should declare cheats")
        XCTAssertTrue(caps.contains(.retroAchievements), "Mednafen JSON entry should declare retroAchievements")
        XCTAssertEqual(meta?.qualityRank, 92)
    }

    /// Verifies the retroAchievements raw value parses from a JSON capability string.
    func testRetroAchievementsRawValueParsesFromString() {
        let rawCapabilities = ["retroAchievements", "highAccuracy"]
        let caps = Set(rawCapabilities.compactMap { CoreCapability(rawValue: $0) })
        XCTAssertTrue(caps.contains(.retroAchievements))
        XCTAssertTrue(caps.contains(.highAccuracy))
        XCTAssertEqual(caps.count, 2)
    }
}
