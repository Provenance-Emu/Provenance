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
    // swiftlint:disable:next function_body_length
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
            PauseMenuTile(
                id: "resume",
                icon: "play.fill",
                label: String(localized: "Resume"),
                description: String(localized: "Close the menu and return to the game."),
                colorKey: .green
            )
        ]
        if shouldSave {
            gameTiles.append(PauseMenuTile(
                id: "saveQuit",
                icon: "square.and.arrow.down.on.square",
                label: String(localized: "Save & Quit"),
                description: String(localized: "Create a save state, then exit to the library."),
                colorKey: .cyan
            ))
        }
        gameTiles.append(PauseMenuTile(
            id: "quit",
            icon: "xmark.circle",
            label: shouldSave ? String(localized: "Quit (No Save)") : String(localized: "Quit"),
            description: String(localized: "Exit to the library without saving."),
            colorKey: .pink
        ))

        let stateTiles: [PauseMenuTile] = [
            PauseMenuTile(
                id: "saveState",
                icon: "square.and.arrow.down",
                label: String(localized: "Quick Save"),
                description: String(localized: "Capture a save state of the current moment."),
                isEnabled: supportsSaveStates,
                colorKey: .cyan
            ),
            PauseMenuTile(
                id: "loadState",
                icon: "arrowshape.turn.up.left",
                label: String(localized: "Quick Load"),
                description: String(localized: "Load the most recent save state."),
                isEnabled: supportsSaveStates && hasSave,
                colorKey: .blue
            ),
            PauseMenuTile(
                id: "browseSaves",
                icon: "list.bullet.rectangle.portrait",
                label: String(localized: "Browse Saves"),
                description: String(localized: "View, load, or delete every save state for this game."),
                isEnabled: supportsSaveStates,
                colorKey: .purple,
                dismissOnTap: false
            ),
            Self.timedAutoSaveTile(isEnabled: supportsSaveStates)
        ]

        gameTiles.append(PauseMenuTile(
            id: "reset",
            icon: "arrow.counterclockwise",
            label: String(localized: "Reset"),
            description: String(localized: "Soft-reset the emulated system."),
            colorKey: .orange
        ))
        if supportsCheatCodes {
            gameTiles.append(PauseMenuTile(
                id: "cheats",
                icon: "wand.and.stars",
                label: String(localized: "Cheats"),
                description: String(localized: "Enable, disable, or add cheat codes."),
                colorKey: .purple
            ))
        }
        gameTiles.append(Self.fastForwardToggleTile(core: emulatorVC.core))
        gameTiles.append(Self.gameSpeedTile(core: emulatorVC.core))

        #if os(iOS) || targetEnvironment(macCatalyst)
        gameTiles.append(PauseMenuTile(
            id: "screenshot",
            icon: "camera",
            label: String(localized: "Screenshot"),
            description: String(localized: "Capture the current frame to Photos."),
            colorKey: .yellow
        ))
        gameTiles.append(PauseMenuTile(
            id: "screenshots",
            icon: "photo.on.rectangle",
            label: String(localized: "Screenshots"),
            description: String(localized: "Browse screenshots captured from this game."),
            colorKey: .yellow,
            dismissOnTap: false
        ))
        #endif

        // Broadcast — feature-flagged, iOS + tvOS
        var recordingTiles: [PauseMenuTile] = []
        #if os(iOS) || os(tvOS)
        if Defaults[.liveBroadcast] {
            let isBcast = emulatorVC.isBroadcasting
            recordingTiles.append(PauseMenuTile(
                id: "broadcast",
                icon: isBcast ? "stop.circle" : "dot.radiowaves.left.and.right",
                label: String(localized: isBcast ? "Stop Live" : "Go Live"),
                badge: isBcast ? "LIVE" : nil,
                description: String(localized: "Broadcast gameplay live via ReplayKit."),
                colorKey: isBcast ? .pink : .cyan,
                dismissOnTap: false
            ))
        }
        // Save Clip — feature-flagged, only visible when clip buffering is active
        if (featureFlags.clipBuffering || featureFlags.clipBuffering) && emulatorVC.isClipBufferingActive {
            recordingTiles.append(PauseMenuTile(
                id: "saveClip",
                icon: "scissors.badge.ellipsis",
                label: String(localized: "Save Clip"),
                description: String(localized: "Export the last few seconds of gameplay."),
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
                description: String(localized: "Record gameplay video to Photos."),
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
                    description: String(localized: "Pick which corner the facecam overlay appears in."),
                    colorKey: .blue,
                    dismissOnTap: false,
                    longPressOptions: lpOptions
                ))
            }
        }
        #endif

        // Root **SETTINGS** section (after STATES): core, app, logs, RetroArch, AirPlay, shader, etc.
        var settingsTiles: [PauseMenuTile] = []

        gameTiles.append(PauseMenuTile(
            id: "gameInfo",
            icon: "info.circle",
            label: String(localized: "Game Info"),
            description: String(localized: "View title, artwork, and metadata for this game."),
            colorKey: .blue
        ))

        let coreTypeName = String(describing: type(of: emulatorVC.core))
        let usingThinWrapper = coreTypeName.contains("ThinLibretro")

        // RetroArch — full RetroArch cores only (not thin wrapper cores which lack RetroArch's menu system).
        // The legacy wrapper class is PVRetroArchCoreCore; its coreIdentifier is `com.provenance.core.retroarch`
        // (no "libretro" substring), so we identify it by class name instead.
        if !usingThinWrapper, coreTypeName.contains("RetroArch") {
            settingsTiles.append(PauseMenuTile(
                id: "retroArchMenu",
                icon: "square.grid.2x2",
                label: String(localized: "RetroArch Menu"),
                description: String(localized: "Open RetroArch's built-in quick menu."),
                colorKey: .purple,
                dismissOnTap: false
            ))
            if PauseMenuViewRegistry.retroArchSettingsView() != nil {
                settingsTiles.append(PauseMenuTile(
                    id: "retroArchSettings",
                    icon: "gearshape.2",
                    label: String(localized: "RetroArch Settings"),
                    description: String(localized: "Configure RetroArch core and system settings."),
                    colorKey: .cyan,
                    dismissOnTap: false
                ))
            }
        }

        settingsTiles.append(PauseMenuTile(
            id: "menu_core",
            icon: "cpu",
            label: String(localized: "Core"),
            description: String(localized: "Core options, actions, and hardware controls."),
            colorKey: .purple,
            dismissOnTap: false,
            destinationRoute: .core
        ))
        settingsTiles.append(PauseMenuTile(
            id: "appSettings",
            icon: "gearshape",
            label: String(localized: "App Settings"),
            description: String(localized: "Open global app settings"),
            colorKey: .teal,
            dismissOnTap: false
        ))
        settingsTiles.append(PauseMenuTile(
            id: "logViewer",
            icon: "doc.text.magnifyingglass",
            label: String(localized: "Log Viewer"),
            description: String(localized: "Open runtime logs"),
            colorKey: .cyan,
            dismissOnTap: false
        ))

        // AirPlay — iOS / Catalyst only; hidden until video AirPlay is implemented
        #if os(iOS) || targetEnvironment(macCatalyst)
        if featureFlags.airPlayMenu || featureFlags.airPlayMenu {
            settingsTiles.append(PauseMenuTile(
                id: "airPlay",
                icon: "airplayaudio",
                label: String(localized: "AirPlay"),
                description: String(localized: "Stream audio to AirPlay devices"),
                colorKey: .cyan,
                dismissOnTap: false
            ))
        }
        #endif

        // Input/controller-related tiles shown under **Controls** (not on the root GAME grid).
        var controlsTiles: [PauseMenuTile] = []
        controlsTiles.append(PauseMenuTile(
            id: "controllerProfile",
            icon: "gamecontroller",
            label: String(localized: "Controller"),
            description: String(localized: "Apply or edit a controller profile for this game."),
            isEnabled: hasControllerProfiles,
            colorKey: .purple,
            dismissOnTap: false
        ))

        if Defaults[.netplayEnabled] && Self.coreSupportsNetplay(emulatorVC) {
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
        if featureFlags.companionController || featureFlags.companionController {
            controlsTiles.append(PauseMenuTile(
                id: "companionController",
                icon: "iphone.and.arrow.forward",
                label: String(localized: "Companion"),
                description: String(localized: "Use another device as a second controller."),
                colorKey: .orange,
                dismissOnTap: false
            ))
        }
        #endif
        // NOTE: The "P1 Controls" / "P2 Controls" tiles were previously listed
        // here but their tap handler was a no-op (just dismissed the menu).
        // They are omitted until per-player controls surface a real sub-sheet.
        if gameSystemID == n64ID {
            controlsTiles.append(PauseMenuTile(
                id: "n64PakSlots",
                icon: "gamecontroller.fill",
                label: String(localized: "Pak Slots"),
                description: String(localized: "Configure Controller Pak, Rumble Pak, and Transfer Pak slots."),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        // ── SCALING — root-level first group so the user can change the
        // global video scaling without diving into Settings. Gated on
        // systems that actually render video (skip Music, etc.). The
        // tap handler writes Defaults[.scalingMode] + flips
        // userExplicitlySetScalingMode so the renderer's
        // effectiveScalingMode() honours the choice on this and future
        // launches.
        if Self.coreSupportsVideoScaling(emulatorVC: emulatorVC) {
            let scalingTiles = Self.scalingModeTiles()
            built.append(PauseMenuTileSection(
                id: "scaling",
                title: String(localized: "SCALING"),
                tiles: scalingTiles
            ))
        }

        built.append(PauseMenuTileSection(id: "game", title: String(localized: "GAME"), tiles: gameTiles))
        built.append(PauseMenuTileSection(id: "statesData", title: String(localized: "STATES"), tiles: stateTiles))

        // ── QUICK SETTINGS (rewind / JIT); fast forward and game speed live under **GAME**.
        var displayTiles: [PauseMenuTile] = []
        let rewindQuickControlAdded = Self.appendRewindTileIfSupported(
            to: &displayTiles,
            core: emulatorVC.core,
            coreOptionsMD5: coreOptionsMD5
        )

        var screenDisplayTiles: [PauseMenuTile] = [
            PauseMenuTile(
                id: "menu_skins",
                icon: "paintbrush.pointed",
                label: String(localized: "Skins"),
                description: String(localized: "Controller skins and on-screen layout"),
                colorKey: .orange,
                dismissOnTap: false,
                destinationRoute: .skins
            ),
            Self.fpsCounterToggleTile(showFPSCount: showFPSCount),
            Self.filterCycleTile(metalFilterMode: metalFilterMode)
        ]
        // Shader parameters live under **SETTINGS** with other configuration tiles.
        let currentFilter = MetalFilterModeOption.parseCurrentFilter(from: metalFilterMode)
        if currentFilter.hasEditableParameters {
            settingsTiles.append(PauseMenuTile(
                id: "shaderSettings",
                icon: "slider.horizontal.3",
                label: String(localized: "Shader Settings"),
                description: String(localized: "Tune parameters for the active Metal shader."),
                colorKey: .teal,
                dismissOnTap: false
            ))
        }
        if let rumbleTile = Self.rumbleToggleTile(core: emulatorVC.core, hapticFeedbackEnabled: hapticFeedbackEnabled) {
            controlsTiles.append(rumbleTile)
        }
        if emulatorVC.virtualInputState.supportsMouse {
            controlsTiles.append(Self.mouseInputSourceTile(source: Defaults[.mouseInputSource]))
            controlsTiles.append(Self.mouseSensitivityTile(sensitivity: Defaults[.mouseSensitivity]))
        }
        if let jitTile = Self.jitStatusTile(core: emulatorVC.core, indicatorRegistry: indicatorRegistry) {
            displayTiles.append(jitTile)
        }
        #if os(iOS)
        if emulatorVC.core.supportsAudioVisualizer {
            screenDisplayTiles.append(Self.audioVisualizerTile(currentMode: emulatorVC.visualizerMode))
        }
        #endif
        #if canImport(UIKit) && !os(tvOS)
        if let keyboardTile = Self.keyboardToggleTile(emulatorVC: emulatorVC) {
            controlsTiles.append(keyboardTile)
        }
        if let mouseTile = Self.mouseToggleTile(emulatorVC: emulatorVC) {
            controlsTiles.append(mouseTile)
        }
        #endif
        if !settingsTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "settingsData", title: String(localized: "SETTINGS"), tiles: settingsTiles))
        }
        if !displayTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "quickSettingsData", title: String(localized: "QUICK SETTINGS"), tiles: displayTiles))
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
           Defaults[.mupenTransferPak],
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
                controlsTiles.append(PauseMenuTile(
                    id: "transferPak",
                    icon: "arrow.triangle.2.circlepath",
                    label: String(localized: "Transfer Pak"),
                    badge: badge,
                    description: String(localized: "Configure a Game Boy ROM for each N64 Transfer Pak slot."),
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
                description: String(localized: "Choose a color palette for this system."),
                colorKey: .purple,
                dismissOnTap: false
            ))
        }

        // Port device type picker — shown when core supports per-port device selection
        if let portDeviceCore = emulatorVC.core as? (any PortDeviceConfigurable),
           !portDeviceCore.controllerPortDescriptors.isEmpty {
            controlsTiles.append(PauseMenuTile(
                id: "portDevices",
                icon: "gamecontroller",
                label: String(localized: "Port Devices"),
                description: String(localized: "Pick the device type plugged into each controller port."),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        // Light Gun overlay toggle — shown when the active core supports light
        // gun input (NES with Zapper, SNES with Super Scope, PSX with GunCon,
        // Saturn with Stunner, etc.). Auto-install is disabled in
        // setupLightGunIfNeeded() to avoid a stray cursor on plain gamepad
        // games; this tile is the explicit opt-in.
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if let gunCore = emulatorVC.core as? LightGunResponder, gunCore.gameSupportsLightGun {
            let isOn = emulatorVC.isLightGunVisible
            controlsTiles.append(PauseMenuTile(
                id: "lightGun",
                icon: isOn ? "scope" : "scope",
                label: String(localized: "Light Gun"),
                badge: isOn ? "ON" : "OFF",
                description: String(localized: "Show the touch-aim crosshair for Zapper / Super Scope / GunCon games."),
                colorKey: isOn ? .green : .gray,
                dismissOnTap: false
            ))
        }
        #endif

        // Virtual Mouse overlay toggle — shown when the system has ANY mouse
        // support (SNES Mouse, Dreamcast, PSX, PCE, etc.), even when the
        // specific ROM isn't in MouseGameRegistry's static MD5/title list.
        // Auto-install is per-game; this tile is the manual override so users
        // can opt in on unrecognised titles.
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if (emulatorVC.core as? MouseResponder) != nil,
           let sysID = SystemIdentifier(rawValue: emulatorVC.core.systemIdentifier ?? ""),
           MouseGameRegistry.shared.systemHasAnyMouseSupport(sysID) {
            let isOn = emulatorVC.isVirtualMouseVisible
            controlsTiles.append(PauseMenuTile(
                id: "virtualMouse",
                icon: "computermouse",
                label: String(localized: "Virtual Mouse"),
                badge: isOn ? "ON" : "OFF",
                description: String(localized: "Show the touch trackpad for mouse-aware games like Mario Paint."),
                colorKey: isOn ? .green : .gray,
                dismissOnTap: false
            ))
        }
        #endif

        // MIDI device picker — shown when core supports MIDI (iOS only, not tvOS or macCatalyst).
        // Note: RetroMenuView+MIDIPicker uses `#if canImport(CoreMIDI) && !os(tvOS)` and therefore
        // includes macCatalyst. The tile menu intentionally excludes macCatalyst because the compact
        // tile layout doesn't adapt well to pointer/keyboard workflows; users can still reach MIDI
        // settings via the classic RetroMenuView on macCatalyst.
        #if canImport(CoreMIDI) && !os(tvOS) && !targetEnvironment(macCatalyst)
        if emulatorVC.core.supportsMIDI {
            controlsTiles.append(PauseMenuTile(
                id: "midiDevice",
                icon: "pianokeys",
                label: String(localized: "MIDI Device"),
                description: String(localized: "Route emulator audio through a CoreMIDI instrument."),
                colorKey: .purple,
                dismissOnTap: false
            ))
        }
        #endif

        if Self.isRetroArchMIDICapable(emulatorVC: emulatorVC) {
            controlsTiles.append(PauseMenuTile(
                id: "retroArchMIDIToggle",
                icon: Defaults[.retroArchMIDIEnabled] ? "pianokeys" : "pianokeys.inverse",
                label: String(localized: "RetroArch MIDI"),
                badge: Defaults[.retroArchMIDIEnabled] ? "ON" : "OFF",
                description: String(localized: "Enable MIDI input for RetroArch cores."),
                colorKey: Defaults[.retroArchMIDIEnabled] ? .green : .gray,
                dismissOnTap: false
            ))
        }
        if Self.hasLegacyPortDeviceOptions(core: emulatorVC.core) {
            controlsTiles.append(PauseMenuTile(
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
            // Legacy RA wrapper (`PVRetroArchCoreCore`) reports `com.provenance.core.retroarch`
            // which doesn't contain "libretro", so we also detect by class name.
            let isLibretro = emulatorVC.core.coreIdentifier?.contains("libretro") == true
                || coreTypeName.contains("RetroArch")
                || usingThinWrapper
            let retroArchInputActions: Set<String> = [
                RetroArchCoreActionTitles.toggleTouchKeyboard,
                RetroArchCoreActionTitles.toggleTouchMouse
            ]
            let actionsForControlsRoute = actions.filter { retroArchInputActions.contains($0.title) }
            let filteredActions = actions.filter { action in
                if retroArchInputActions.contains(action.title) { return false }
                if isPaletteProviding && action.title == changePaletteLegacyActionTitle { return false }
                if isLibretro && action.title == RetroArchCoreActionTitles.internalMenu { return false }
                return true
            }
            if !filteredActions.isEmpty {
                coreTiles += CoreActionTileProvider.tiles(from: filteredActions)
            }
            if !actionsForControlsRoute.isEmpty {
                controlsTiles += CoreActionTileProvider.tiles(from: actionsForControlsRoute)
            }
        }

        // System-specific menu buttons (Start/Select/Coin/etc.) for controllers
        // that lack them (Siri Remote, older BT pads) and always-on Coin for arcade.
        if let systemForButtons = Self.resolvedSystemIdentifier(emulatorVC: emulatorVC) {
            let missingOn = Defaults[.missingButtonsAlwaysOn]
            let systemTiles = SystemButtonTileProvider.tiles(
                for: systemForButtons,
                controllerManager: PVControllerManager.shared,
                missingButtonsAlwaysOn: missingOn
            )
            controlsTiles.append(contentsOf: systemTiles)
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
                    description: String(localized: "Toggle this physical hardware switch."),
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
                    description: String(localized: "Send a momentary press to this hardware button."),
                    colorKey: .orange,
                    dismissOnTap: false
                ))
            }
        }

        if !coreTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "core", title: String(localized: "CORE"), tiles: coreTiles))
        }

        if !controlsTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "controlsData", title: String(localized: "CONTROLS"), tiles: controlsTiles))
        }

        let menuTiles: [PauseMenuTile] = [
            PauseMenuTile(
                id: "menu_recording",
                icon: "record.circle",
                label: String(localized: "Recording"),
                description: String(localized: "Recording, broadcasting, and clip tools."),
                colorKey: .pink,
                dismissOnTap: false,
                destinationRoute: .recording
            )
        ]
        built.insert(PauseMenuTileSection(id: "menu", title: String(localized: "MENU"), tiles: menuTiles), at: 2)

        if !screenDisplayTiles.isEmpty {
            built.append(PauseMenuTileSection(id: "displayData", title: String(localized: "DISPLAY"), tiles: screenDisplayTiles))
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
            // Peer sections on the root grid (like STATES); CONTROLS is not a MENU drill-in.
            let rootSectionOrder = ["game", "statesData", "settingsData", "controlsData", "quickSettingsData", "menu", "displayData"]
            let byID = Dictionary(uniqueKeysWithValues: rootSections.map { ($0.id, $0) })
            return rootSectionOrder.compactMap { byID[$0] }
        case .states:
            let stateIDs: Set<String> = ["saveState", "loadState", "browseSaves", "autoSaveState", "screenshot", "screenshots"]
            let tiles = tiles(matching: stateIDs, from: rootSections)
            return [PauseMenuTileSection(id: "states_route", title: String(localized: "STATES"), tiles: tiles)]
        case .options:
            let optionIDs: Set<String> = [
                "fastForwardToggle", "gameSpeedCycle", "fpsCounterToggle", "rewindToggle",
                "filterCycle", "shaderSettings", "airPlay",
                "audioVisualizer"
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
                PauseMenuTile(
                    id: "skins_pick_portrait",
                    icon: "rectangle.portrait",
                    label: String(localized: "Choose Portrait Skin"),
                    badge: systemLabel,
                    description: String(localized: "Pick the skin used in portrait orientation."),
                    colorKey: .orange,
                    dismissOnTap: false
                ),
                PauseMenuTile(
                    id: "skins_pick_landscape",
                    icon: "rectangle.landscape",
                    label: String(localized: "Choose Landscape Skin"),
                    badge: systemLabel,
                    description: String(localized: "Pick the skin used in landscape orientation."),
                    colorKey: .purple,
                    dismissOnTap: false
                ),
                PauseMenuTile(
                    id: "skins_button_effect",
                    icon: "wand.and.sparkles",
                    label: String(localized: "Button Effect"),
                    badge: Defaults[.buttonPressEffect].description,
                    description: String(localized: "Visual effect played when on-screen buttons are pressed."),
                    colorKey: .purple,
                    dismissOnTap: false
                ),
                PauseMenuTile(
                    id: "skins_button_sound",
                    icon: "speaker.wave.2",
                    label: String(localized: "Button Sound"),
                    badge: Defaults[.buttonSound].description,
                    description: String(localized: "Audible feedback played when on-screen buttons are pressed."),
                    colorKey: .blue,
                    dismissOnTap: false
                ),
                PauseMenuTile(
                    id: "skins_browse_catalog",
                    icon: "arrow.down.circle.fill",
                    label: String(localized: "Browse Catalog"),
                    description: String(localized: "Browse and download community-made skins."),
                    colorKey: .orange,
                    dismissOnTap: false
                )
            ]
            #if !os(tvOS)
            tiles.insert(PauseMenuTile(
                id: "skins_import_file",
                icon: "square.and.arrow.down",
                label: String(localized: "Import Skin File"),
                description: String(localized: "Import a .deltaskin or .provskin file from the Files app."),
                colorKey: .cyan,
                dismissOnTap: false
            ), at: 3)
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

    // MARK: - Scaling

    /// Pause-menu tile IDs are matched on this prefix by the dispatcher in
    /// PauseTileMenuView. Keep the trailing token in sync with
    /// `ScalingMode.rawValue` so `String(droppingPrefix:)` recovers the mode.
    static let scalingTilePrefix = "scaling_"

    /// Build a tile per `ScalingMode` case, marking the currently-active one
    /// with a green accent + ★ badge. The renderer reads `Defaults[.scalingMode]`
    /// live (observed in PVMetalViewController / PVGLViewController), so the tap
    /// handler only needs to write the default + flip the explicit-set gate.
    static func scalingModeTiles() -> [PauseMenuTile] {
        let current = Defaults[.scalingMode]
        return ScalingMode.allCases.map { mode in
            let isActive = mode == current
            return PauseMenuTile(
                id: "\(scalingTilePrefix)\(mode.rawValue)",
                icon: mode.symbolName,
                label: mode.displayName,
                badge: isActive ? "★" : nil,
                description: mode.subtitle,
                colorKey: isActive ? .green : .gray,
                dismissOnTap: false
            )
        }
    }

    /// Predicate: the active core renders video (so global scaling settings
    /// are actually visible to the user). Music / audio-only systems get no
    /// scaling section because there's nothing to scale.
    private static func coreSupportsVideoScaling(emulatorVC: PVEmulatorViewController) -> Bool {
        let raw = emulatorVC.game?.systemIdentifier ?? emulatorVC.core.systemIdentifier ?? ""
        guard let systemID = SystemIdentifier(rawValue: raw) else { return true }
        switch systemID {
        case .Music:
            return false
        default:
            return true
        }
    }

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
            description: String(localized: "Tap to cycle screen filters. Long-press to pick one."),
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
            description: String(localized: "Toggle rumble / haptic feedback for this core."),
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
            description: String(localized: "Show or hide the on-screen virtual keyboard."),
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
            description: String(localized: "Show or hide the on-screen virtual mouse."),
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
            description: String(localized: "JIT compilation status for this core."),
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

    /// True for cores like RetroArch: CORE tab hides the port picker (empty ``PortDeviceConfigurable/controllerPortDescriptors``)
    /// but ``PauseMenuLibretroPortPickerSource`` still exposes SET_CONTROLLER_INFO for the pause/tile menu.
    private static func hasLegacyPortDeviceOptions(core: PVEmulatorCore) -> Bool {
        guard let pause = core as? PauseMenuLibretroPortPickerSource else { return false }
        let hasCORETabPortPicker = (core as? PortDeviceConfigurable).map { !$0.controllerPortDescriptors.isEmpty } ?? false
        guard !hasCORETabPortPicker else { return false }
        return pause.pauseMenuPortDeviceDescriptors.contains { $0.count > 1 }
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
            description: String(localized: "Speed up emulation to quickly skip ahead."),
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
            description: String(localized: "Tap to cycle emulation speed. Long-press to pick an exact multiplier."),
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
            description: String(localized: "Show the current frames-per-second on screen."),
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
            description: String(localized: "Enable rewind to step back through recent gameplay."),
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
