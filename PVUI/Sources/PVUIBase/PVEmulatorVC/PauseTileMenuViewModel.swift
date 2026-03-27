//
//  PauseTileMenuViewModel.swift
//  PVUI
//
//  Caches the tile sections array so it is not recomputed on every SwiftUI body
//  evaluation. Call `rebuild(...)` once on appear and again after each option toggle.
//

import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVFeatureFlags
import PVPrimitives
import PVSettings
import PVLibrary
#if canImport(PVNetplay)
import PVNetplay
#endif

/// Ranked search hit for a tile menu query.
struct PauseMenuSearchResult: Identifiable, Hashable {
    /// Stable ID combining route and tile identity.
    var id: String { "\(route.rawValue)::\(tile.id)" }
    let route: PauseTileMenuRoute
    let tile: PauseMenuTile
    let matchedTitle: Bool
    let matchedDescription: Bool
    let isCurrentRoute: Bool
}

// MARK: - PauseTileMenuViewModel

/// Lightweight cache that owns the `[PauseMenuTileSection]` array.
///
/// Sections are rebuilt only when ``rebuild`` is called explicitly,
/// avoiding the costly per-render recomputation of `gameSections`.
@MainActor
// swiftlint:disable type_body_length
final class PauseTileMenuViewModel: ObservableObject {

    @Published private(set) var sections: [PauseMenuTileSection] = []

    /// Flat lookup table: tile ID -> description text.
    /// Built alongside `sections` so the info shelf can resolve descriptions in O(1).
    private(set) var descriptionsByTileID: [String: String] = [:]
    static let hardwareSwitchTilePrefix = "hardwareSwitch_"
    static let hardwareMomentaryTilePrefix = "hardwareMomentary_"
    /// Cache of route -> visible sections to support global search.
    private var sectionsByRoute: [PauseTileMenuRoute: [PauseMenuTileSection]] = [:]

    /// Recomputes every tile section from the current emulator state.
    ///
    /// - Parameters:
    ///   - emulatorVC: The active emulator view controller.
    ///   - metalFilterMode: Current metal filter preference.
    ///   - hapticFeedbackEnabled: Whether rumble/haptic is on.
    ///   - featureFlags: Feature flag environment value.
    ///   - indicatorRegistry: Shared indicator state registry.
    ///   - hasControllerProfiles: Whether any controller profiles exist.
    func rebuild(
        emulatorVC: PVEmulatorViewController,
        metalFilterMode: MetalFilterModeOption,
        showFPSCount: Bool,
        hapticFeedbackEnabled: Bool,
        featureFlags: PVFeatureFlagsManager,
        indicatorRegistry: PVIndicatorRegistry,
        hasControllerProfiles: Bool,
        hardwareSwitchStates: [String: Bool],
        coreOptionsMD5: String?,
        route: PauseTileMenuRoute
    ) {
        var built: [PauseMenuTileSection] = []

        // ── GAME section ────────────────────────────────────────────────
        let supportsSaveStates = emulatorVC.core.supportsSaveStates
        let hasSave: Bool = {
            guard let game = emulatorVC.game, !game.isInvalidated else { return false }
            return !game.saveStates.isEmpty
        }()
        let n64ID = SystemIdentifier.N64.rawValue
        let gameSystemID = emulatorVC.game?.systemIdentifier ?? emulatorVC.core.systemIdentifier
        let supportsCheatCodes = (emulatorVC.core as? GameWithCheat)?.supportsCheatCode == true
        let shouldSave = Self.shouldSaveOnQuit(emulatorVC: emulatorVC)

        // Resume + quit tiles are placed at the top (positions 0-2) to match
        // RetroMenuView's ordering where quit is near the top of the main section.
        var gameTiles: [PauseMenuTile] = [
            PauseMenuTile(id: "resume", icon: "play.fill", label: String(localized: "Resume"), colorKey: .green)
        ]
        if shouldSave {
            gameTiles.append(PauseMenuTile(id: "saveQuit", icon: "square.and.arrow.down.on.square", label: String(localized: "Save & Quit"), colorKey: .cyan))
        }
        gameTiles.append(PauseMenuTile(id: "quit", icon: "xmark.circle", label: shouldSave ? String(localized: "Quit (No Save)") : String(localized: "Quit"), colorKey: .pink))

        let stateTiles: [PauseMenuTile] = [
            PauseMenuTile(id: "saveState", icon: "square.and.arrow.down", label: String(localized: "Quick Save"), isEnabled: supportsSaveStates, colorKey: .cyan),
            PauseMenuTile(id: "loadState", icon: "arrowshape.turn.up.left", label: String(localized: "Quick Load"), isEnabled: supportsSaveStates && hasSave, colorKey: .blue),
            PauseMenuTile(
                id: "browseSaves",
                icon: "list.bullet.rectangle.portrait",
                label: String(localized: "Browse Saves"),
                isEnabled: supportsSaveStates,
                colorKey: .purple,
                dismissOnTap: false
            ),
            Self.timedAutoSaveTile(isEnabled: supportsSaveStates)
        ]

        gameTiles.append(PauseMenuTile(id: "reset", icon: "arrow.counterclockwise", label: String(localized: "Reset"), colorKey: .orange))
        if supportsCheatCodes {
            gameTiles.append(PauseMenuTile(id: "cheats", icon: "wand.and.stars", label: String(localized: "Cheats"), colorKey: .purple))
        }

        #if os(iOS) || targetEnvironment(macCatalyst)
        gameTiles.append(PauseMenuTile(id: "screenshot", icon: "camera", label: String(localized: "Screenshot"), colorKey: .yellow))
        gameTiles.append(PauseMenuTile(id: "screenshots", icon: "photo.on.rectangle", label: String(localized: "Screenshots"), colorKey: .yellow, dismissOnTap: false))
        #endif

        // Broadcast — feature-flagged, iOS + tvOS
        var recordingTiles: [PauseMenuTile] = []
        #if os(iOS) || os(tvOS)
        if featureFlags.liveBroadcast || PVFeatureFlagsManager.shared.liveBroadcast {
            let isBcast = emulatorVC.isBroadcasting
            recordingTiles.append(PauseMenuTile(
                id: "broadcast",
                icon: isBcast ? "stop.circle" : "dot.radiowaves.left.and.right",
                label: String(localized: isBcast ? "Stop Live" : "Go Live"),
                badge: isBcast ? "LIVE" : nil,
                colorKey: isBcast ? .pink : .cyan,
                dismissOnTap: false
            ))
        }
        // Save Clip — feature-flagged, only visible when clip buffering is active
        if (featureFlags.clipBuffering || PVFeatureFlagsManager.shared.clipBuffering) && emulatorVC.isClipBufferingActive {
            recordingTiles.append(PauseMenuTile(
                id: "saveClip",
                icon: "scissors.badge.ellipsis",
                label: String(localized: "Save Clip"),
                colorKey: .purple,
                dismissOnTap: true
            ))
        }
        #endif

        #if os(iOS)
        if emulatorVC.isRecordingAvailable {
            let isRec = emulatorVC.isRecording
            recordingTiles.insert(PauseMenuTile(
                id: "recording",
                icon: isRec ? "stop.circle" : "record.circle",
                label: String(localized: isRec ? "Stop Rec" : "Record"),
                badge: isRec ? "REC" : nil,
                colorKey: isRec ? .pink : .orange,
                dismissOnTap: true
            ), at: 0)
            if Defaults[.recordingCameraEnabled] {
                let pos = Defaults[.recordingCameraPosition]
                let lpOptions = CameraPosition.allCases.map { camPos in
                    PauseMenuTileLongPressOption(
                        id: "camPos_\(camPos.rawValue)",
                        title: camPos.displayName,
                        isSelected: camPos == pos
                    )
                }
                recordingTiles.append(PauseMenuTile(
                    id: "cameraPosition",
                    icon: pos.symbolName,
                    label: String(localized: "Cam Corner"),
                    badge: pos.displayName,
                    colorKey: .blue,
                    dismissOnTap: false,
                    longPressOptions: lpOptions
                ))
            }
        }
        #endif

        // AirPlay — iOS / Catalyst only; lets users stream audio+video without leaving the game
        #if os(iOS) || targetEnvironment(macCatalyst)
        gameTiles.append(PauseMenuTile(
            id: "airPlay",
            icon: "airplayvideo",
            label: String(localized: "AirPlay"),
            description: String(localized: "Stream audio and video to AirPlay devices"),
            colorKey: .cyan,
            dismissOnTap: false
        ))
        #endif

        gameTiles.append(PauseMenuTile(id: "gameInfo", icon: "info.circle", label: String(localized: "Game Info"), colorKey: .blue))
        gameTiles.append(PauseMenuTile(id: "controllerProfile", icon: "gamecontroller", label: String(localized: "Controller"), isEnabled: hasControllerProfiles, colorKey: .purple, dismissOnTap: false))
        if (featureFlags.netplayEnabled || PVFeatureFlagsManager.shared.netplayEnabled) && Self.coreSupportsNetplay(emulatorVC) {
            gameTiles.append(PauseMenuTile(
                id: "networkPlay",
                icon: "antenna.radiowaves.left.and.right",
                label: String(localized: "Network Play"),
                description: String(localized: "Host, browse, or spectate netplay rooms"),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        #if os(iOS) || targetEnvironment(macCatalyst)
        if featureFlags.companionController || PVFeatureFlagsManager.shared.companionController {
            gameTiles.append(PauseMenuTile(
                id: "companionController",
                icon: "iphone.and.arrow.forward",
                label: String(localized: "Companion"),
                colorKey: .orange,
                dismissOnTap: false
            ))
        }
        #endif
        let wantsStartSelectInMenu = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(
            emulatorVC.game?.system?.identifier ?? SystemIdentifier.RetroArch.rawValue
        )
        if let player1 = PVControllerManager.shared.player1 {
#if os(iOS)
            if Defaults[.missingButtonsAlwaysOn] || player1.extendedGamepad != nil || wantsStartSelectInMenu {
                gameTiles.append(PauseMenuTile(
                    id: "p1Controls",
                    icon: "gamecontroller",
                    label: String(localized: "P1 Controls"),
                    colorKey: .blue
                ))
            }
#else
            if player1.extendedGamepad != nil || wantsStartSelectInMenu {
                gameTiles.append(PauseMenuTile(
                    id: "p1Controls",
                    icon: "gamecontroller",
                    label: String(localized: "P1 Controls"),
                    colorKey: .blue
                ))
            }
#endif
        }
        if let player2 = PVControllerManager.shared.player2,
           player2.extendedGamepad != nil || wantsStartSelectInMenu {
            gameTiles.append(PauseMenuTile(
                id: "p2Controls",
                icon: "gamecontroller",
                label: String(localized: "P2 Controls"),
                colorKey: .purple
            ))
        }
        if gameSystemID == n64ID {
            gameTiles.append(PauseMenuTile(
                id: "n64PakSlots",
                icon: "gamecontroller.fill",
                label: String(localized: "Pak Slots"),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        built.append(PauseMenuTileSection(id: "game", title: String(localized: "GAME"), tiles: gameTiles))
        built.append(PauseMenuTileSection(id: "statesData", title: String(localized: "STATES"), tiles: stateTiles))

        let menuTiles: [PauseMenuTile] = [
            PauseMenuTile(id: "menu_recording", icon: "record.circle", label: String(localized: "Recording"), colorKey: .pink, dismissOnTap: false, destinationRoute: .recording),
            PauseMenuTile(id: "menu_core", icon: "cpu", label: String(localized: "Core"), colorKey: .purple, dismissOnTap: false, destinationRoute: .core),
            PauseMenuTile(id: "menu_skins", icon: "paintbrush.pointed", label: String(localized: "Skins"), colorKey: .orange, dismissOnTap: false, destinationRoute: .skins),
            PauseMenuTile(
                id: "appSettings",
                icon: "gearshape",
                label: String(localized: "App Settings"),
                description: String(localized: "Open global app settings"),
                colorKey: .teal,
                dismissOnTap: false
            ),
            PauseMenuTile(
                id: "logViewer",
                icon: "doc.text.magnifyingglass",
                label: String(localized: "Log Viewer"),
                description: String(localized: "Open runtime logs"),
                colorKey: .cyan,
                dismissOnTap: false
            )
        ] + {
            guard emulatorVC.core.coreIdentifier?.contains("libretro") == true,
                  PauseMenuViewRegistry.retroArchSettingsView() != nil else { return [] }
            return [
                PauseMenuTile(
                    id: "retroArchSettings",
                    icon: "gearshape.2",
                    label: String(localized: "RetroArch Quick Settings"),
                    description: String(localized: "Open curated RetroArch settings"),
                    colorKey: .cyan,
                    dismissOnTap: false
                )
            ]
        }()
        built.append(PauseMenuTileSection(id: "menu", title: String(localized: "MENU"), tiles: menuTiles))

        // ── QUICK SETTINGS section ──────────────────────────────────────
        var displayTiles: [PauseMenuTile] = []
        displayTiles.append(Self.fastForwardToggleTile(core: emulatorVC.core))
        displayTiles.append(Self.gameSpeedTile(core: emulatorVC.core))
        displayTiles.append(Self.fpsCounterToggleTile(showFPSCount: showFPSCount))
        let rewindQuickControlAdded = Self.appendRewindTileIfSupported(
            to: &displayTiles,
            core: emulatorVC.core,
            coreOptionsMD5: coreOptionsMD5
        )
        displayTiles.append(Self.filterCycleTile(metalFilterMode: metalFilterMode))
        // Shader settings tile — shown when the current filter has adjustable parameters
        let currentFilter = MetalFilterModeOption.parseCurrentFilter(from: metalFilterMode)
        if currentFilter.hasEditableParameters {
            displayTiles.append(PauseMenuTile(
                id: "shaderSettings",
                icon: "slider.horizontal.3",
                label: String(localized: "Shader Settings"),
                colorKey: .teal,
                dismissOnTap: false
            ))
        }
        if let rumbleTile = Self.rumbleToggleTile(core: emulatorVC.core, hapticFeedbackEnabled: hapticFeedbackEnabled) {
            displayTiles.append(rumbleTile)
        }
        if emulatorVC.virtualInputState.supportsMouse {
            displayTiles.append(Self.mouseInputSourceTile(source: Defaults[.mouseInputSource]))
            displayTiles.append(Self.mouseSensitivityTile(sensitivity: Defaults[.mouseSensitivity]))
        }
        if let jitTile = Self.jitStatusTile(core: emulatorVC.core, indicatorRegistry: indicatorRegistry) {
            displayTiles.append(jitTile)
        }
        #if os(iOS)
        if emulatorVC.core.supportsAudioVisualizer {
            displayTiles.append(Self.audioVisualizerTile(currentMode: emulatorVC.visualizerMode))
        }
        #endif
        #if canImport(UIKit) && !os(tvOS)
        if let keyboardTile = Self.keyboardToggleTile(emulatorVC: emulatorVC) {
            displayTiles.append(keyboardTile)
        }
        if let mouseTile = Self.mouseToggleTile(emulatorVC: emulatorVC) {
            displayTiles.append(mouseTile)
        }
        #endif
        if !displayTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "display", title: String(localized: "QUICK SETTINGS"), tiles: displayTiles))
        }
        if !recordingTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "recording", title: String(localized: "RECORDING"), tiles: recordingTiles))
        }

        // ── CORE section (dynamic, per-core) ────────────────────────────
        var coreTiles: [PauseMenuTile] = []

        // Show Transfer Pak tile only for known compatible titles.
        // Showing it for all N64 games is misleading — most games don't use the Transfer Pak.
        let gameTitle = emulatorVC.game?.title ?? ""
        if let transferCore = emulatorVC.core as? TransferPakSupport,
           featureFlags.mupenTransferPak || PVFeatureFlagsManager.shared.mupenTransferPak,
           transferCore.transferPakSlotCount > 0 {
            // Count configured slots in one pass; reuse for both the visibility guard and
            // the badge label to avoid calling transferPakROM(forPort:) more than once per slot.
            let configuredCount = (0..<transferCore.transferPakSlotCount).reduce(0) { count, port in
                count + (transferCore.transferPakROM(forPort: port) != nil ? 1 : 0)
            }
            let isKnown = TransferPakCompatibleGames.isKnownTransferPakGame(gameTitle)
            if isKnown || configuredCount > 0 {
                // Show "!" badge when this is a known Transfer Pak game but nothing is configured —
                // this nudges the user to set it up without blocking launch.
                let badge: String? = configuredCount > 0 ? "\(configuredCount)" : "!"
                coreTiles.append(PauseMenuTile(
                    id: "transferPak",
                    icon: "arrow.triangle.2.circlepath",
                    label: String(localized: "Transfer Pak"),
                    badge: badge,
                    colorKey: .pink,
                    dismissOnTap: false
                ))
            }
        }

        if let paletteCore = emulatorVC.core as? PaletteProviding,
           !paletteCore.availablePalettes.isEmpty {
            let currentName = paletteCore.currentPalette?.displayName ?? "–"
            coreTiles.append(PauseMenuTile(
                id: "palette",
                icon: "paintpalette.fill",
                label: String(localized: "Palette"),
                badge: currentName,
                colorKey: .purple,
                dismissOnTap: false
            ))
        }

        // Port device type picker — shown when core supports per-port device selection
        if let portDeviceCore = emulatorVC.core as? (any PortDeviceConfigurable),
           !portDeviceCore.controllerPortDescriptors.isEmpty {
            coreTiles.append(PauseMenuTile(
                id: "portDevices",
                icon: "gamecontroller",
                label: String(localized: "Port Devices"),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        // MIDI device picker — shown when core supports MIDI (iOS only, not tvOS or macCatalyst).
        // Note: RetroMenuView+MIDIPicker uses `#if canImport(CoreMIDI) && !os(tvOS)` and therefore
        // includes macCatalyst. The tile menu intentionally excludes macCatalyst because the compact
        // tile layout doesn't adapt well to pointer/keyboard workflows; users can still reach MIDI
        // settings via the classic RetroMenuView on macCatalyst.
        #if canImport(CoreMIDI) && !os(tvOS) && !targetEnvironment(macCatalyst)
        if emulatorVC.core.supportsMIDI {
            coreTiles.append(PauseMenuTile(
                id: "midiDevice",
                icon: "pianokeys",
                label: String(localized: "MIDI Device"),
                colorKey: .purple,
                dismissOnTap: false
            ))
        }
        #endif

        if Self.isRetroArchMIDICapable(emulatorVC: emulatorVC) {
            coreTiles.append(PauseMenuTile(
                id: "retroArchMIDIToggle",
                icon: Defaults[.retroArchMIDIEnabled] ? "pianokeys" : "pianokeys.inverse",
                label: String(localized: "RetroArch MIDI"),
                badge: Defaults[.retroArchMIDIEnabled] ? "ON" : "OFF",
                colorKey: Defaults[.retroArchMIDIEnabled] ? .green : .gray,
                dismissOnTap: false
            ))
        }
        if Self.hasLegacyPortDeviceOptions(core: emulatorVC.core) {
            coreTiles.append(PauseMenuTile(
                id: "legacyPortDevices",
                icon: "gamecontroller",
                label: String(localized: "Port Devices (Legacy)"),
                description: String(localized: "Configure core-reported controller port device types"),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        if let actions = (emulatorVC.core as? CoreActions)?.coreActions {
            let isPaletteProviding = (emulatorVC.core as? PaletteProviding)?.availablePalettes.isEmpty == false
            let filteredActions = isPaletteProviding
                ? actions.filter { $0.title != changePaletteLegacyActionTitle }
                : actions
            if !filteredActions.isEmpty {
                coreTiles += CoreActionTileProvider.tiles(from: filteredActions)
            }
        }

        if let coreClass = type(of: emulatorVC.core) as? CoreOptional.Type {
            coreTiles += CoreOptionTileProvider.tiles(from: coreClass.options, coreClass: coreClass, md5Scope: coreOptionsMD5)
            if rewindQuickControlAdded {
                coreTiles.removeAll { $0.id.hasPrefix(CoreOptionTileProvider.idPrefix) && $0.label.localizedCaseInsensitiveContains("rewind") }
            }
        }

        if let activeSystem = Self.resolvedSystemIdentifier(emulatorVC: emulatorVC) {
            let hardwareSwitches = activeSystem.hardwareSwitches ?? []
            let hardwareMomentaryButtons = activeSystem.hardwareMomentaryButtons ?? []

            for descriptor in hardwareSwitches {
                let isOn = hardwareSwitchStates[descriptor.id] ?? descriptor.defaultState
                let activePosition = isOn ? descriptor.positions.on : descriptor.positions.off
                coreTiles.append(PauseMenuTile(
                    id: "\(Self.hardwareSwitchTilePrefix)\(descriptor.id)",
                    icon: "switch.2",
                    label: descriptor.title,
                    badge: activePosition.label,
                    colorKey: isOn ? .green : .gray,
                    dismissOnTap: false
                ))
            }

            for descriptor in hardwareMomentaryButtons {
                coreTiles.append(PauseMenuTile(
                    id: "\(Self.hardwareMomentaryTilePrefix)\(descriptor.id)",
                    icon: "dot.radiowaves.left.and.right",
                    label: descriptor.title,
                    badge: descriptor.label,
                    colorKey: .orange,
                    dismissOnTap: false
                ))
            }
        }

        if !coreTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "core", title: String(localized: "CORE"), tiles: coreTiles))
        }

        // Build description lookup table
        var descs: [String: String] = [:]
        for section in built {
            for tile in section.tiles {
                if let desc = tile.description, !desc.isEmpty {
                    descs[tile.id] = desc
                }
            }
        }

        var rebuiltByRoute: [PauseTileMenuRoute: [PauseMenuTileSection]] = [:]
        for routeCase in PauseTileMenuRoute.allCases {
            rebuiltByRoute[routeCase] = sections(for: routeCase, from: built, emulatorVC: emulatorVC)
        }
        sectionsByRoute = rebuiltByRoute
        sections = rebuiltByRoute[route] ?? []
        descriptionsByTileID = descs
    }

    /// Returns the visible sections for the active tile-menu route.
    private func sections(
        for route: PauseTileMenuRoute,
        from rootSections: [PauseMenuTileSection],
        emulatorVC: PVEmulatorViewController
    ) -> [PauseMenuTileSection] {
        switch route {
        case .root:
            return rootSections.filter { $0.id == "game" || $0.id == "statesData" || $0.id == "display" || $0.id == "menu" }
        case .states:
            let stateIDs: Set<String> = ["saveState", "loadState", "browseSaves", "autoSaveState", "screenshot", "screenshots"]
            let tiles = tiles(matching: stateIDs, from: rootSections)
            return [PauseMenuTileSection(id: "states_route", title: String(localized: "STATES"), tiles: tiles)]
        case .options:
            let optionIDs: Set<String> = [
                "fastForwardToggle", "gameSpeedCycle", "fpsCounterToggle", "rewindToggle",
                "filterCycle", "shaderSettings", "rumbleToggle", "airPlay", "keyboardToggle", "mouseToggle",
                "retroArchSettings", "audioVisualizer", "mouseInputSource", "mouseSensitivity"
            ]
            let tiles = tiles(matching: optionIDs, from: rootSections)
            return [PauseMenuTileSection(id: "options_route", title: String(localized: "OPTIONS"), tiles: tiles)]
        case .recording:
            let recordingIDs: Set<String> = ["recording", "broadcast", "saveClip", "cameraPosition"]
            let tiles = tiles(matching: recordingIDs, from: rootSections)
            return [PauseMenuTileSection(id: "recording_route", title: String(localized: "RECORDING"), tiles: tiles)]
        case .core:
            let core = rootSections.first(where: { $0.id == "core" })
            return core.map { [PauseMenuTileSection(id: "core_route", title: String(localized: "CORE"), tiles: $0.tiles)] } ?? []
        case .skins:
            if !emulatorVC.core.supportsSkins {
                let tiles: [PauseMenuTile] = [
                    PauseMenuTile(
                        id: "skins_unsupported_info",
                        icon: "exclamationmark.triangle.fill",
                        label: String(localized: "Skins Unsupported"),
                        description: String(localized: "Skins are not supported by this core yet."),
                        isEnabled: false,
                        colorKey: .gray,
                        dismissOnTap: false
                    )
                ]
                return [PauseMenuTileSection(id: "skins_root", title: String(localized: "SKINS"), tiles: tiles)]
            }
            let systemIdentifier = SystemIdentifier(rawValue: emulatorVC.game?.systemIdentifier ?? emulatorVC.core.systemIdentifier ?? "")
            let systemLabel = systemIdentifier?.fullName ?? String(localized: "Current System")
            let savedScopeRaw = UserDefaults.standard.string(forKey: "PauseTileMenu.skinScope") ?? SkinScope.game.rawValue
            let skinScope = SkinScope(rawValue: savedScopeRaw) ?? .game
            let scopeLabel = skinScope.rawValue
            var tiles: [PauseMenuTile] = [
                PauseMenuTile(
                    id: "skins_scope",
                    icon: "line.3.horizontal.decrease.circle",
                    label: String(localized: "Skin Scope"),
                    badge: scopeLabel,
                    description: String(localized: "Choose Session, Game, or System scope"),
                    colorKey: .teal,
                    dismissOnTap: false,
                    longPressOptions: SkinScope.allCases.map {
                        PauseMenuTileLongPressOption(id: "skinScope_\($0.rawValue)", title: $0.rawValue, isSelected: $0 == skinScope)
                    }
                ),
                PauseMenuTile(id: "skins_pick_portrait", icon: "rectangle.portrait", label: String(localized: "Choose Portrait Skin"), badge: systemLabel, colorKey: .orange, dismissOnTap: false),
                PauseMenuTile(id: "skins_pick_landscape", icon: "rectangle.landscape", label: String(localized: "Choose Landscape Skin"), badge: systemLabel, colorKey: .purple, dismissOnTap: false),
                PauseMenuTile(id: "skins_button_effect", icon: "wand.and.sparkles", label: String(localized: "Button Effect"), badge: Defaults[.buttonPressEffect].description, colorKey: .purple, dismissOnTap: false),
                PauseMenuTile(id: "skins_button_sound", icon: "speaker.wave.2", label: String(localized: "Button Sound"), badge: Defaults[.buttonSound].description, colorKey: .blue, dismissOnTap: false),
                PauseMenuTile(id: "skins_browse_catalog", icon: "arrow.down.circle.fill", label: String(localized: "Browse Catalog"), colorKey: .orange, dismissOnTap: false)
            ]
            #if !os(tvOS)
            tiles.insert(PauseMenuTile(id: "skins_import_file", icon: "square.and.arrow.down", label: String(localized: "Import Skin File"), colorKey: .cyan, dismissOnTap: false), at: 3)
            #endif
            return [PauseMenuTileSection(id: "skins_root", title: String(localized: "SKINS"), tiles: tiles)]
        }
    }

    /// Searches all routes by tile label/description and ranks current-route title hits first.
    func search(query: String, currentRoute: PauseTileMenuRoute) -> [PauseMenuSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = trimmed.lowercased()

        var bestByTileID: [String: PauseMenuSearchResult] = [:]

        for (route, sections) in sectionsByRoute {
            for section in sections {
                for tile in section.tiles {
                    let titleMatch = tile.label.lowercased().contains(needle)
                    let descriptionMatch = tile.description?.lowercased().contains(needle) == true
                    guard titleMatch || descriptionMatch else { continue }

                    let candidate = PauseMenuSearchResult(
                        route: route,
                        tile: tile,
                        matchedTitle: titleMatch,
                        matchedDescription: descriptionMatch,
                        isCurrentRoute: route == currentRoute
                    )

                    if let existing = bestByTileID[tile.id] {
                        if shouldReplace(existing: existing, with: candidate) {
                            bestByTileID[tile.id] = candidate
                        }
                    } else {
                        bestByTileID[tile.id] = candidate
                    }
                }
            }
        }

        return bestByTileID.values.sorted { lhs, rhs in
            if lhs.isCurrentRoute != rhs.isCurrentRoute { return lhs.isCurrentRoute && !rhs.isCurrentRoute }
            if lhs.matchedTitle != rhs.matchedTitle { return lhs.matchedTitle && !rhs.matchedTitle }
            if lhs.matchedDescription != rhs.matchedDescription { return lhs.matchedDescription && !rhs.matchedDescription }
            return lhs.tile.label.localizedCaseInsensitiveCompare(rhs.tile.label) == .orderedAscending
        }
    }

    private func shouldReplace(existing: PauseMenuSearchResult, with candidate: PauseMenuSearchResult) -> Bool {
        if existing.isCurrentRoute != candidate.isCurrentRoute { return candidate.isCurrentRoute }
        if existing.matchedTitle != candidate.matchedTitle { return candidate.matchedTitle }
        if existing.matchedDescription != candidate.matchedDescription { return candidate.matchedDescription }
        return candidate.route == .root && existing.route != .root
    }

    /// Returns matching tiles in their original section order.
    private func tiles(matching ids: Set<String>, from sections: [PauseMenuTileSection]) -> [PauseMenuTile] {
        var matches: [PauseMenuTile] = []
        for section in sections {
            for tile in section.tiles where ids.contains(tile.id) {
                matches.append(tile)
            }
        }
        return matches
    }

    /// Looks up the description for a tile by ID, returning nil when none exists.
    func description(forTileID id: String?) -> String? {
        guard let id else { return nil }
        return descriptionsByTileID[id]
    }

    // MARK: - Static tile builders

    private static func filterCycleTile(metalFilterMode: MetalFilterModeOption) -> PauseMenuTile {
        let currentFilter = MetalFilterModeOption.parseCurrentFilter(from: metalFilterMode)
        let allFilters = MetalFilterSelectionOption.allCases
        let badge: String = {
            switch currentFilter {
            case .none: return "None"
            default: return currentFilter.description
            }
        }()
        let lpOptions = allFilters.map { f in
            PauseMenuTileLongPressOption(
                id: "filter_\(f.rawValue)",
                title: f == .none ? "None" : f.description,
                isSelected: f == currentFilter
            )
        }
        return PauseMenuTile(
            id: "filterCycle",
            icon: "camera.filters",
            label: String(localized: "Screen Filter"),
            badge: badge,
            colorKey: .teal,
            dismissOnTap: false,
            longPressOptions: lpOptions
        )
    }

    private static func rumbleToggleTile(core: PVEmulatorCore, hapticFeedbackEnabled: Bool) -> PauseMenuTile? {
        guard let rumbleCore = core as? EmulatorCoreRumbleDataSource,
              rumbleCore.supportsRumble else { return nil }
        return PauseMenuTile(
            id: "rumbleToggle",
            icon: hapticFeedbackEnabled ? "waveform.path" : "waveform.path.badge.minus",
            label: String(localized: "Rumble"),
            badge: hapticFeedbackEnabled ? "ON" : "OFF",
            colorKey: hapticFeedbackEnabled ? .green : .gray,
            dismissOnTap: false
        )
    }

    #if canImport(UIKit) && !os(tvOS)
    private static func keyboardToggleTile(emulatorVC: PVEmulatorViewController) -> PauseMenuTile? {
        guard emulatorVC.coreSupportsVirtualKeyboard else { return nil }
        let isVisible = emulatorVC.isVirtualKeyboardVisible
        return PauseMenuTile(
            id: "keyboardToggle",
            icon: isVisible ? "keyboard.fill" : "keyboard",
            label: String(localized: "Keyboard"),
            badge: isVisible ? "ON" : "OFF",
            colorKey: isVisible ? .green : .gray,
            dismissOnTap: false
        )
    }

    private static func mouseToggleTile(emulatorVC: PVEmulatorViewController) -> PauseMenuTile? {
        guard emulatorVC.coreSupportsVirtualMouse else { return nil }
        let isVisible = emulatorVC.isVirtualMouseVisible
        return PauseMenuTile(
            id: "mouseToggle",
            icon: "cursorarrow",
            label: String(localized: "Mouse"),
            badge: isVisible ? "ON" : "OFF",
            colorKey: isVisible ? .green : .gray,
            dismissOnTap: false
        )
    }
    #endif

    private static func jitStatusTile(core: PVEmulatorCore, indicatorRegistry: PVIndicatorRegistry) -> PauseMenuTile? {
        guard core.jitRequirement.hasJIT else { return nil }
        let jitState = indicatorRegistry.state(for: .jitStatus)
        let isActive = jitState?.color == .green
        return PauseMenuTile(
            id: "jitStatus",
            icon: isActive ? "bolt.fill" : "bolt.slash",
            label: "JIT",
            badge: isActive ? "ON" : "OFF",
            isEnabled: false,
            colorKey: isActive ? .green : .orange,
            dismissOnTap: false
        )
    }

    /// Returns true only when the running core both conforms to `PVNetplayCapable`
    /// and reports `supportsNetplay == true`. Falls back to false when PVNetplay is
    /// not linked (e.g. stripped builds) so the tile is never shown unnecessarily.
    private static func coreSupportsNetplay(_ emulatorVC: PVEmulatorViewController) -> Bool {
#if canImport(PVNetplay)
        if let bridge = emulatorVC.core as? any PVNetplayCapable, bridge.supportsNetplay {
            return true
        }
        // Fallback for bridge/type-erasure edge cases where protocol conformance isn't visible
        // from this module even though the runtime core supports netplay.
        let coreID = (emulatorVC.core.coreIdentifier ?? "").lowercased()
        let knownNetplayCoreHints = ["libretro", "dolphin", "ppsspp", "mgba", "melonds", "mednafen"]
        return knownNetplayCoreHints.contains { coreID.contains($0) }
#else
        return false
#endif
    }

    private static func shouldSaveOnQuit(emulatorVC: PVEmulatorViewController) -> Bool {
        guard let game = emulatorVC.game, !game.isInvalidated else { return false }
        let twoMinutes: TimeInterval = 120
        let oneMinute: TimeInterval = 60
        let minimumPlayTime: TimeInterval = 60 * 2
        var result = Defaults[.autoSave]
        result = result && abs((game.lastPlayed ?? Date()).timeIntervalSinceNow) > minimumPlayTime
        result = result && (game.lastAutosaveAge ?? twoMinutes) > oneMinute
        result = result && abs((!game.isInvalidated ? game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow : nil) ?? twoMinutes) > oneMinute
        result = result && emulatorVC.core.supportsSaveStates
        return result
    }

    /// Resolves the most accurate runtime system identifier for tile-generation.
    /// Prefers concrete game-system identifiers before core-level fallback.
    private static func resolvedSystemIdentifier(emulatorVC: PVEmulatorViewController) -> SystemIdentifier? {
        let candidates: [String?] = [
            emulatorVC.game?.system?.identifier,
            emulatorVC.game?.systemIdentifier,
            emulatorVC.core.systemIdentifier
        ]
        let parsed = candidates.compactMap { raw -> SystemIdentifier? in
            guard let raw, !raw.isEmpty else { return nil }
            return SystemIdentifier(rawValue: raw)
        }
        return parsed.first(where: { $0 != .RetroArch }) ?? parsed.first
    }

    private static func isRetroArchMIDICapable(emulatorVC: PVEmulatorViewController) -> Bool {
#if canImport(CoreMIDI) && !os(tvOS)
        let coreID = (emulatorVC.core.coreIdentifier ?? "").lowercased()
        let isLibretroCore = coreID.contains("libretro") || coreID.contains("retroarch")
        guard isLibretroCore else { return false }
        guard let game = emulatorVC.game,
              let sysID = SystemIdentifier(rawValue: game.systemIdentifier) else { return false }
        return MIDISystemRegistry.shared.supportsMIDI(sysID)
#else
        return false
#endif
    }

    private static func hasLegacyPortDeviceOptions(core: PVEmulatorCore) -> Bool {
        guard core as? PortDeviceConfigurable == nil else { return false }
        guard let coreObject = core as? NSObject,
              let bridge = coreObject.value(forKey: "_bridge") as? NSObject else { return false }
        let selector = Selector(("controllerPortInfo"))
        guard bridge.responds(to: selector),
              let info = bridge.value(forKey: "controllerPortInfo") as? [[NSDictionary]] else { return false }
        return info.contains { $0.count > 1 }
    }
}
// swiftlint:enable type_body_length

// MARK: - MetalFilterModeOption extension

extension MetalFilterModeOption {
    /// Extracts the currently-active `MetalFilterSelectionOption` from a mode option.
    static func parseCurrentFilter(from mode: MetalFilterModeOption) -> MetalFilterSelectionOption {
        switch mode {
        case .none:
            return .none
        case let .always(filter: f):
            return f
        case let .auto(crt: crt, lcd: lcd):
            return crt != .none ? crt : lcd
        }
    }
}

private extension PauseTileMenuViewModel {
    static func fastForwardToggleTile(core: PVEmulatorCore) -> PauseMenuTile {
        let isFastForwarding = core.gameSpeed == .fast || core.gameSpeed == .veryFast
        return PauseMenuTile(
            id: "fastForwardToggle",
            icon: isFastForwarding ? "forward.fill" : "forward",
            label: String(localized: "Fast Forward"),
            badge: isFastForwarding ? "ON" : "OFF",
            colorKey: isFastForwarding ? .green : .gray,
            dismissOnTap: false
        )
    }

    static func gameSpeedTile(core: PVEmulatorCore) -> PauseMenuTile {
        let speed = core.gameSpeed
        let badge = String(format: "%.2gx", speed.multiplier)
        let isBoosted = speed == .fast || speed == .veryFast
        let lpOptions = GameSpeed.allCases.map { value in
            PauseMenuTileLongPressOption(
                id: "gameSpeed_\(value.rawValue)",
                title: value.description,
                isSelected: value == speed
            )
        }
        return PauseMenuTile(
            id: "gameSpeedCycle",
            icon: "speedometer",
            label: String(localized: "Game Speed"),
            badge: badge,
            colorKey: isBoosted ? .yellow : .cyan,
            dismissOnTap: false,
            longPressOptions: lpOptions
        )
    }

    static func fpsCounterToggleTile(showFPSCount: Bool) -> PauseMenuTile {
        PauseMenuTile(
            id: "fpsCounterToggle",
            icon: "speedometer",
            label: String(localized: "FPS Counter"),
            badge: showFPSCount ? "ON" : "OFF",
            colorKey: showFPSCount ? .green : .gray,
            dismissOnTap: false
        )
    }

    static func mouseInputSourceTile(source: MouseInputSource) -> PauseMenuTile {
        let availableSources = MouseInputSource.allCases.filter { sourceOption in
            #if os(tvOS)
            return sourceOption != .touchscreen
            #else
            return true
            #endif
        }
        let options = availableSources.map {
            PauseMenuTileLongPressOption(
                id: "mouseSource_\($0.rawValue)",
                title: $0.displayName,
                isSelected: $0 == source
            )
        }
        return PauseMenuTile(
            id: "mouseInputSource",
            icon: source.symbolName,
            label: String(localized: "Mouse Input Source"),
            badge: source.displayName,
            description: String(localized: "Tap to cycle source. Long-press to choose exact source."),
            colorKey: .blue,
            dismissOnTap: false,
            longPressOptions: options
        )
    }

    static func mouseSensitivityTile(sensitivity: Double) -> PauseMenuTile {
        let presets: [Double] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0]
        let options = presets.map { preset in
            PauseMenuTileLongPressOption(
                id: "mouseSensitivity_\(Int((preset * 100).rounded()))",
                title: String(format: "%.2gx", preset),
                isSelected: abs(preset - sensitivity) < 0.01
            )
        }
        return PauseMenuTile(
            id: "mouseSensitivity",
            icon: "slider.horizontal.3",
            label: String(localized: "Mouse Sensitivity"),
            badge: String(format: "%.2gx", sensitivity),
            description: String(localized: "Tap to cycle sensitivity. Long-press for exact value presets."),
            colorKey: .purple,
            dismissOnTap: false,
            longPressOptions: options
        )
    }

    /// Builds the timed auto-save control tile with quick interval/off choices.
    static func timedAutoSaveTile(isEnabled: Bool) -> PauseMenuTile {
        let timedEnabled = Defaults[.timedAutoSaves]
        let interval = Defaults[.timedAutoSaveInterval]
        let intervalMinutes = max(1, Int((interval / 60.0).rounded()))
        let quickIntervals: [Int] = [2, 5, 10, 15, 30]
        let lpOptions: [PauseMenuTileLongPressOption] = [
            PauseMenuTileLongPressOption(
                id: "autosave_off",
                title: String(localized: "Off"),
                isSelected: !timedEnabled
            )
        ] + quickIntervals.map { minutes in
            PauseMenuTileLongPressOption(
                id: "autosave_interval_\(minutes * 60)",
                title: "\(minutes)m",
                isSelected: timedEnabled && intervalMinutes == minutes
            )
        }
        return PauseMenuTile(
            id: "autoSaveState",
            icon: timedEnabled ? "clock.arrow.circlepath" : "clock.badge.xmark",
            label: String(localized: "Timed Auto Save"),
            badge: timedEnabled ? "\(intervalMinutes)m" : "OFF",
            description: String(localized: "Tap to toggle timed auto saves. Long-press to set interval or turn off."),
            isEnabled: isEnabled,
            colorKey: timedEnabled ? .teal : .gray,
            dismissOnTap: false,
            longPressOptions: lpOptions
        )
    }

    /// Builds an audio visualizer tile with toggle tap behavior and long-press mode selection.
    static func audioVisualizerTile(currentMode: VisualizerMode) -> PauseMenuTile {
        let modeOptions = VisualizerMode.allCases.map { mode in
            PauseMenuTileLongPressOption(
                id: "audioViz_mode_\(mode.rawValue)",
                title: mode.description,
                isSelected: mode == currentMode
            )
        }
        return PauseMenuTile(
            id: "audioVisualizer",
            icon: currentMode == .off ? "waveform" : "waveform.path.ecg",
            label: String(localized: "Audio Visualizer"),
            badge: currentMode == .off ? "OFF" : currentMode.description,
            description: String(localized: "Tap to toggle on/off. Long-press to choose visualizer style."),
            colorKey: currentMode == .off ? .gray : .teal,
            dismissOnTap: false,
            longPressOptions: modeOptions
        )
    }

    @discardableResult
    static func appendRewindTileIfSupported(
        to tiles: inout [PauseMenuTile],
        core: PVEmulatorCore,
        coreOptionsMD5: String?
    ) -> Bool {
        guard let coreClass = type(of: core) as? CoreOptional.Type,
              let rewindOption = findRewindOption(in: coreClass.options) else { return false }
        let isEnabled: Bool = coreClass.valueForOption(rewindOption, andMD5: coreOptionsMD5)
        tiles.append(PauseMenuTile(
            id: "rewindToggle",
            icon: isEnabled ? "backward.fill" : "backward",
            label: String(localized: "Rewind"),
            badge: isEnabled ? "ON" : "OFF",
            colorKey: isEnabled ? .green : .gray,
            dismissOnTap: false
        ))
        return true
    }

    static func findRewindOption(in options: [CoreOption]) -> CoreOption? {
        for option in options {
            switch option {
            case let .bool(display, _, _) where display.title.localizedCaseInsensitiveContains("rewind"):
                return option
            case .bool where option.key.localizedCaseInsensitiveContains("rewind"):
                return option
            case let .group(_, subOptions):
                if let nested = findRewindOption(in: subOptions) {
                    return nested
                }
            default:
                continue
            }
        }
        return nil
    }
}
