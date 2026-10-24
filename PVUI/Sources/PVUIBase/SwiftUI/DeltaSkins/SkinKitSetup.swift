//
//  SkinKitSetup.swift
//  PVUI
//
//  Wires SkinKit (https://github.com/Provenance-Emu/SkinKit) to Provenance's settings, theme,
//  systems and storage. SkinKit's hooks default to inert values, so a missed one fails silently
//  (no case-controller skins, no bundled skins, default colors): call `configure()` before anything
//  touches `DeltaSkinManager.shared` or shows a skin view.
//

import Defaults
import Foundation
import PVLibrary
import PVLogging
import PVPrimitives
import PVSettings
import PVSystems
import SkinCatalogKit
import SkinKitCore
import SkinKitManager
import SkinKitUI
import SwiftUI

public enum SkinKitSetup {
    private static let lock = NSLock()
    private static var isConfigured = false

    /// Name of Provenance's own catalog cache before SkinCatalogKit (`Caches/skin_catalog.json`).
    static let legacyCatalogCacheFileName = "skin_catalog.json"

    /// Sets every SkinKit hook. Safe to call more than once; only the first call does anything.
    public static func configure() {
        let shouldConfigure: Bool = lock.withLock {
            guard !isConfigured else { return false }
            isConfigured = true
            return true
        }
        guard shouldConfigure else { return }

        configureLogging()
        ILOG("skins: Configuring SkinKit")
        configureSelection()
        configureManager()
        configureRendering()
        configureSystems()
        configureTheme()
        seedCatalogCache()
    }

    // MARK: - Logging

    /// Manager messages (scan, import, selection) go to PVLogging, as they did before the move, so
    /// they stay in the session logs. SkinKitCore, SkinKitUI and the shared catalog service log to
    /// `os.Logger` (subsystem `com.provenance-emu.SkinKit`) with no hook.
    private static func configureLogging() {
        SkinManagerLog.logger = { level, message in
            switch level {
            case .debug: DLOG(message)
            case .info: ILOG(message)
            case .warning: WLOG(message)
            case .error: ELOG(message)
            }
        }
    }

    // MARK: - Selection and storage

    private static func configureSelection() {
        DeltaSkinCompanionSkinDetection.matcher = { CaseControllerDetector.isCompanionSkinForKnownCase($0) }
        DeltaSkinSelectionManager.shared.allowsCaseControllerSkinFallback = {
            Defaults[.caseCompanionSkins] && CaseControllerDetector.isKnownPhysicalCaseControllerConnected
        }
        // Physical iPhone cases only make sense on iOS / Mac Catalyst.
        #if os(iOS) || targetEnvironment(macCatalyst)
        DeltaSkinPreferences.shared.systemSkinSelectionObserver = { _ = CaseControllerDetector.notifyIfCaseSkin($0) }
        #endif
    }

    /// Provenance's layout: `<URL.documentsPath>/DeltaSkins` (follows the library location and the
    /// tvOS Caches mapping), plus the main bundle's skins and PVUIBase's `DefaultSkins`.
    static var managerConfiguration: DeltaSkinManager.Configuration {
        var configuration = DeltaSkinManager.Configuration.provenance(
            documents: URL.documentsPath,
            bundledSkinLocations: { DeltaSkinManager.Configuration.mainBundleSkins() + bundledDefaultSkins() }
        )
        configuration.isAllowedInAutomaticSelection = { CaseControllerDetector.isAllowedInAutomaticSkinSelection($0) }
        return configuration
    }

    private static func configureManager() {
        DeltaSkinManager.shared = DeltaSkinManager(configuration: managerConfiguration)
    }

    /// The default skins bundled in this module's resources.
    static func bundledDefaultSkins() -> [URL] {
        let deltaSkins = Bundle.module.urls(forResourcesWithExtension: "deltaskin", subdirectory: "DefaultSkins") ?? []
        let manicSkins = Bundle.module.urls(forResourcesWithExtension: "manicskin", subdirectory: "DefaultSkins") ?? []
        return deltaSkins + manicSkins
    }

    // MARK: - Rendering and input

    private static func configureRendering() {
        DeltaSkinRendering.defaultSkinProvider = { gameType in
            guard let system = gameType.systemIdentifier else { return nil }
            let skin = try? await DeltaSkinManager.shared.defaultSkin(for: system)
            return skin?.renderable
        }
        DeltaSkinInteractionSettings.current = DeltaSkinInteractionSettings(
            isButtonVibrationEnabled: { Defaults[.buttonVibration] },
            isButtonSoundEnabled: { Defaults[.buttonSound] != .none },
            isTurboEnabled: { Defaults[.turboEnabled] },
            isStickyButtonsEnabled: { Defaults[.stickyButtonsEnabled] },
            isMultiButtonTouchEnabled: { Defaults[.skinMultiButtonTouch] },
            turboRateHz: { Defaults[.turboRateHz] },
            playButtonPressSound: { pan, volume in ButtonSoundGenerator.shared.playButtonPressSound(pan: pan, volume: volume) },
            isCaseCompanionSkinsEnabled: { Defaults[.caseCompanionSkins] }
        )
    }

    // MARK: - Systems

    private static func configureSystems() {
        // Sorted as the system skin browser sorted `SystemIdentifier`s (by full name).
        let systems = SystemIdentifier.allCases.sorted().map(\.deltaSkinSystem)
        DeltaSkinSystemDirectory.current = DeltaSkinSystemDirectory(
            systems: systems,
            displayNameForCatalogCode: { SystemIdentifier.displayName(forCatalogCode: $0) },
            relatedCatalogSystemCodes: { SystemIdentifier.relatedCatalogSystemCodes(forCatalogCode: $0) },
            canonicalCatalogCode: { SystemIdentifier.canonicalSkinCatalogCode($0) },
            systemForGameType: { $0.systemIdentifier?.deltaSkinSystem }
        )
    }

    // MARK: - Theme

    private static func configureTheme() {
        var theme = SkinKitTheme()
        theme.pink = .retroPink
        theme.purple = .retroPurple
        theme.blue = .retroBlue
        theme.darkBlue = .retroDarkBlue
        theme.black = .retroBlack
        theme.cyan = .retroCyan
        theme.radiusSM = RetroPauseChrome.radiusSM
        theme.menuCellFillOpacityUnfocused = RetroPauseChrome.menuCellFillOpacityUnfocused
        theme.menuCellFillOpacityFocused = RetroPauseChrome.menuCellFillOpacityFocused
        theme.menuCellStrokeOpacityUnfocused = RetroPauseChrome.menuCellStrokeOpacityUnfocused
        theme.menuCellStrokeOpacityFocused = RetroPauseChrome.menuCellStrokeOpacityFocused
        theme.menuCellStrokeWidthUnfocused = RetroPauseChrome.menuCellStrokeWidthUnfocused
        theme.menuCellStrokeWidthFocused = RetroPauseChrome.menuCellStrokeWidthFocused
        theme.sectionTitleMutedOpacity = RetroPauseChrome.sectionTitleMutedOpacity
        theme.panelCornerRadius = RetroPauseChrome.panelCornerRadius
        theme.panelStrokeLineWidth = RetroPauseChrome.panelStrokeLineWidth
        theme.panelFillOpacityDark = RetroPauseChrome.panelFillOpacityDark
        theme.panelFillOpacityLight = RetroPauseChrome.panelFillOpacityLight
        theme.background = { AnyView(RetroTheme.retroBackground) }
        theme.alert = { content, title, message, isPresented, actions in
            AnyView(content.retroAlert(title, message: message, isPresented: isPresented) { actions })
        }
        theme.focusButtonStyle = { content, focusScale, cornerRadius, showBorder in
            AnyView(content.retroFocusButtonStyle(focusScale: focusScale, cornerRadius: cornerRadius, showBorder: showBorder))
        }
        theme.sectionHeaderTypography = { AnyView($0.retroPauseSectionHeaderTypography()) }
        SkinKitTheme.current = theme
    }

    // MARK: - Catalog

    /// `catalog_seed.json` in this module's resources.
    static var bundledCatalogSeedURL: URL? {
        Bundle.module.url(forResource: "catalog_seed", withExtension: "json")
    }

    /// Gives SkinCatalogKit's cache a starting point when it has none: Provenance's old catalog cache if
    /// it still decodes, otherwise the bundled `catalog_seed.json`. Provenance's own service fell back to
    /// that seed when the network and its cache both failed; SkinCatalogKit has no seed, so an offline
    /// first launch would show an error instead. The copy is dated in the past, so it never counts as
    /// fresh: the next load still goes to the network and only uses it if that fails.
    static func seedCatalogCache(
        cacheURL: URL = SkinCatalogService.defaultCacheURL,
        legacyCacheURL: URL = SkinCatalogService.defaultCacheURL
            .deletingLastPathComponent().appendingPathComponent(legacyCatalogCacheFileName),
        seedURL: URL? = SkinKitSetup.bundledCatalogSeedURL
    ) {
        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: legacyCacheURL) }
        guard !fileManager.fileExists(atPath: cacheURL.path) else { return }

        let candidates = [legacyCacheURL, seedURL].compactMap { $0 }
        guard let data = candidates.lazy
            .compactMap({ try? Data(contentsOf: $0) })
            .first(where: { (try? SkinCatalog.decode($0)) != nil }) else {
            WLOG("skins: No catalog seed to give SkinCatalogKit's cache")
            return
        }
        do {
            try data.write(to: cacheURL, options: .atomic)
            try fileManager.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: cacheURL.path)
            ILOG("skins: Seeded the skin catalog cache (\(data.count) bytes)")
        } catch {
            ELOG("skins: Could not seed the skin catalog cache: \(error.localizedDescription)")
        }
    }
}

// MARK: - SystemIdentifier → SkinKit values

extension SystemIdentifier {
    /// This system as SkinKitUI's pickers and catalog views take it.
    public var deltaSkinSystem: DeltaSkinSystem {
        DeltaSkinSystem(
            id: skinSystemID,
            fullName: fullName,
            gameType: DeltaSkinGameType(systemIdentifier: self),
            skinCatalogSystemCode: skinCatalogSystemCode ?? "",
            relatedSkinCatalogSystemCodes: Set(relatedSkinCatalogSystemCodes)
        )
    }
}

extension PVGame {
    /// This game as the per-game skin picker takes it.
    public var deltaSkinGameContext: DeltaSkinGameContext {
        DeltaSkinGameContext(id: id, title: title, md5Hash: md5Hash, crc: crc)
    }
}
