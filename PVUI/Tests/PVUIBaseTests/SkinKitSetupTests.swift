//
//  SkinKitSetupTests.swift
//  PVUIBaseTests
//
//  SkinKit's hooks default to inert values, so a hook `SkinKitSetup.configure()` forgets to set
//  fails silently. These check that each one carries Provenance's value.
//

import Defaults
import Foundation
import PVSettings
import PVSystems
import SkinCatalogKit
import SkinKitCore
import SkinKitManager
import SkinKitUI
import SwiftUI
import Testing
@testable import PVUIBase

@Suite("SkinKit setup", .serialized)
struct SkinKitSetupTests {
    init() {
        SkinKitSetup.configure()
    }

    @Test("The manager stores skins under URL.documentsPath and scans the bundled default skins")
    func managerConfiguration() {
        let configuration = DeltaSkinManager.shared.configuration
        #expect(configuration.skinsDirectory.standardizedFileURL
            == URL.documentsPath.appendingPathComponent("DeltaSkins", isDirectory: true).standardizedFileURL)
        let bundled = SkinKitSetup.bundledDefaultSkins()
        #expect(bundled.count >= 23)
        let scanned = Set(configuration.bundledSkinLocations())
        #expect(Set(bundled).isSubset(of: scanned))
    }

    @Test("Bundled default skins load through the configured manager")
    func bundledSkinsLoad() async throws {
        let skins = try await DeltaSkinManager.shared.availableSkins()
        let identifiers = Set(skins.map(\.identifier))
        #expect(identifiers.contains { $0.hasPrefix("com.provenance.defaultskins.") })
    }

    @Test("Case-controller skin detection uses CaseControllerDetector")
    func companionMatcher() {
        let caseSkin = "com.provenance.defaultskins.backbone.snes"
        #expect(CaseControllerDetector.isCompanionSkinForKnownCase(caseSkin))
        #expect(DeltaSkinCompanionSkinDetection.matcher(caseSkin))
        #expect(!DeltaSkinCompanionSkinDetection.matcher("com.provenance.defaultskins.snes"))
        // `isAllowedInAutomaticSelection` asks GameController for connected pads, which hangs in the
        // test host (as `CaseControllerDetectorTests` does); a plain skin passes before that check.
        #expect(DeltaSkinManager.shared.configuration.isAllowedInAutomaticSelection("com.provenance.defaultskins.snes"))
    }

    @Test("Skin interaction settings read Provenance's Defaults")
    func interactionSettings() {
        let settings = DeltaSkinInteractionSettings.current
        #expect(settings.turboRateHz() == Defaults[.turboRateHz])
        #expect(settings.isButtonVibrationEnabled() == Defaults[.buttonVibration])
        #expect(settings.isButtonSoundEnabled() == (Defaults[.buttonSound] != .none))
        #expect(settings.isStickyButtonsEnabled() == Defaults[.stickyButtonsEnabled])
        #expect(settings.isMultiButtonTouchEnabled() == Defaults[.skinMultiButtonTouch])
        #expect(settings.isCaseCompanionSkinsEnabled() == Defaults[.caseCompanionSkins])
    }

    @Test("The system directory lists every SystemIdentifier with its catalog codes")
    func systemDirectory() {
        let directory = DeltaSkinSystemDirectory.current
        #expect(directory.systems.count == SystemIdentifier.allCases.count)
        #expect(directory.systems.map(\.fullName) == SystemIdentifier.allCases.sorted().map(\.fullName))
        let genesis = SystemIdentifier.Genesis.deltaSkinSystem
        #expect(genesis.gameType == .genesis)
        #expect(genesis.skinCatalogSystemCode == SystemIdentifier.Genesis.skinCatalogSystemCode)
        #expect(directory.systemForGameType(.genesis)?.id == genesis.id)
        #expect(directory.displayNameForCatalogCode("threeds") == SystemIdentifier.displayName(forCatalogCode: "threeds"))
        #expect(directory.relatedCatalogSystemCodes("genesis") == SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: "genesis"))
    }

    @Test("A system with no catalog code gets nil, so its Get More link is unfiltered")
    func systemWithoutCatalogCode() throws {
        let uncoded = try #require(SystemIdentifier.allCases.first { $0.skinCatalogSystemCode == nil })
        #expect(uncoded.deltaSkinSystem.skinCatalogSystemCode == nil)
    }

    @Test("The input handler owns a usable sticky manager")
    func stickyManager() {
        #expect(DeltaSkinInputHandler().stickyManager.stickyButtons.isEmpty)
    }

    @Test("The skin views use Provenance's RetroWave colors")
    func theme() {
        let theme = SkinKitTheme.current
        #expect(theme.pink == Color.retroPink)
        #expect(theme.cyan == Color.retroCyan)
        #expect(theme.panelCornerRadius == RetroPauseChrome.panelCornerRadius)
    }

    @Test("The multi-touch diagnostic flag is shared with SkinKitUI")
    func diagnostics() {
        InputDiagnostics.hasLoggedMultiTouch = true
        #expect(DeltaSkinInputDiagnostics.hasLoggedMultiTouch)
        InputDiagnostics.resetAll()
        #expect(!DeltaSkinInputDiagnostics.hasLoggedMultiTouch)
    }
}

@Suite("Skin catalog cache seed")
struct SkinCatalogCacheSeedTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SkinCatalogCacheSeedTests-\(UUID().uuidString)", isDirectory: true)

    private var cacheURL: URL { directory.appendingPathComponent(SkinCatalogService.cacheFileName) }
    private var legacyURL: URL { directory.appendingPathComponent(SkinKitSetup.legacyCatalogCacheFileName) }

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func seedFile() -> URL? {
        SkinKitSetup.bundledCatalogSeedURL
    }

    private func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    @Test("With no cache, the bundled seed is copied in, dated so it is never fresh")
    func seedsFromBundle() throws {
        let seed = try #require(seedFile())
        SkinKitSetup.seedCatalogCache(cacheURL: cacheURL, legacyCacheURL: legacyURL, seedURL: seed)
        let data = try Data(contentsOf: cacheURL)
        #expect(data == (try Data(contentsOf: seed)))
        #expect(try SkinCatalog.decode(data).skins.isEmpty == false)
        let modified = try #require(modificationDate(cacheURL))
        #expect(Date().timeIntervalSince(modified) > SkinCatalogService.defaultTTL)
    }

    @Test("A decodable legacy cache is preferred over the seed, then removed")
    func prefersLegacyCache() throws {
        let seed = try #require(seedFile())
        let legacy = Data(#"{"version": 1, "skins": [{"id": "legacy-skin", "name": "Legacy", "systems": ["nes"], "downloadURL": "https://example.com/legacy.deltaskin"}]}"#.utf8)
        try legacy.write(to: legacyURL)
        SkinKitSetup.seedCatalogCache(cacheURL: cacheURL, legacyCacheURL: legacyURL, seedURL: seed)
        #expect(try Data(contentsOf: cacheURL) == legacy)
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test("An unreadable legacy cache falls back to the seed")
    func unreadableLegacyUsesSeed() throws {
        let seed = try #require(seedFile())
        try Data("not json".utf8).write(to: legacyURL)
        SkinKitSetup.seedCatalogCache(cacheURL: cacheURL, legacyCacheURL: legacyURL, seedURL: seed)
        #expect(try Data(contentsOf: cacheURL) == (try Data(contentsOf: seed)))
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test("An existing SkinCatalogKit cache is left alone")
    func keepsExistingCache() throws {
        let seed = try #require(seedFile())
        let existing = Data("existing".utf8)
        try existing.write(to: cacheURL)
        SkinKitSetup.seedCatalogCache(cacheURL: cacheURL, legacyCacheURL: legacyURL, seedURL: seed)
        #expect(try Data(contentsOf: cacheURL) == existing)
    }
}
