//
//  PauseTileMenuView.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #3248/#3249 — tile-based pause menu (feature-flagged, default OFF)
//
//  Design goals:
//  - Compact floating grid overlay; does NOT cover the full screen
//  - Square tiles in a tight # grid with section headers for grouping
//  - Dynamic column count based on available width
//  - Works in skins / legacy UIKit controller layout
//  - Retrowave neon aesthetic consistent with RetroMenuView
//  - iOS and tvOS compatible; controller/keyboard focus via FocusState
//

import SwiftUI
import PVCoreBridge
import PVFeatureFlags
import PVLogging
import PVLibrary
import PVPrimitives
import PVSettings
import PVThemes
#if canImport(UIKit)
import UIKit
#endif
#if !os(tvOS)
import UniformTypeIdentifiers
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - PauseTileMenuView

// swiftlint:disable type_body_length
/// Compact tile/grid pause overlay that floats over the game screen.
/// This is the default pause menu for all platforms.
struct PauseTileMenuView: View {
    let emulatorVC: PVEmulatorViewController
    let dismissAction: (Bool) -> Void
    var initialRoute: PauseTileMenuRoute = .root

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var indicatorRegistry = PVIndicatorRegistry.shared
    @StateObject private var viewModel = PauseTileMenuViewModel()

    // MARK: Sheet state

    @State private var showingSaveStateBrowser = false
    @State private var showingScreenshotBrowser = false
    @State private var showingControllerProfiles = false
    @State private var showingTransferPakConfig = false
    /// Frozen snapshot of `emulatorVC.game` captured on the main thread before the sheet opens.
    /// The sheet closure reads this instead of the live Realm object to avoid thread-violation crashes.
    @State private var frozenTransferPakGame: PVGame?
    @State private var showingN64PakConfig = false
    @State private var showingPalettePicker = false
    @State private var showingNetworkPlay = false
    /// Triggers the AirPlay route-picker sheet via the hidden AVRoutePickerView bridge.
    #if os(iOS) || targetEnvironment(macCatalyst)
    @State private var triggerAirPlayPicker = false
    #endif
    @State private var showingShaderSettings = false
    @State private var showingPortDevices = false
    @State private var showingMIDIPicker = false
    @State private var showingSystemSkinSelection = false
    @State private var showingLegacyPortDevices = false
    @State private var showingSkinCatalog = false
    @State private var showingButtonEffectPicker = false
    @State private var showingButtonSoundPicker = false
    @State private var showingLogViewer = false
    @State private var showingRetroArchSettings = false
    @State private var showingAppSettings = false
    #if !os(tvOS)
    @State private var showingSkinImporter = false
    @State private var showingSkinImportError = false
    @State private var skinImportErrorMessage: String?
    #endif
    /// Core action awaiting option picker confirmation.
    @State private var pendingCoreAction: CoreAction?
    /// Cached result of the Realm query — refreshed on appear, not on every render.
    @State private var hasControllerProfiles = false
    /// In-memory on/off states for hardware switch tiles (e.g. Atari difficulty / TV type).
    @State private var hardwareSwitchStates: [String: Bool] = [:]
    /// Query string for global tile search.
    @State private var searchText: String = ""
    /// Ranked search results across the full pause-menu tree.
    @State private var searchResults: [PauseMenuSearchResult] = []
    /// Description text shown in the bottom info shelf when a tile is focused/long-pressed.
    @State private var infoText: String?
    /// Tracks whether changed core options require a deferred reset prompt.
    @State private var pendingCoreReset = false
    /// Controls display of restart prompt when user exits the pause menu.
    @State private var showingDeferredRestartPrompt = false

    // MARK: tvOS Focus

    @FocusState private var focusedTileID: String?
    @State private var routeStack: [PauseTileMenuRoute] = []

    // MARK: Size class / orientation

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.scenePhase) private var scenePhase

    // Metal filter state — read/write directly to react to changes.
    @Default(.metalFilterMode) private var metalFilterMode

    // Haptic feedback toggle
    @Default(.hapticFeedback) private var hapticFeedbackEnabled
    @Default(.showFPSCount) private var showFPSCount
    @Default(.buttonPressEffect) private var buttonPressEffect
    @Default(.buttonSound) private var buttonSound
    @Default(.mouseInputSource) private var mouseInputSource
    @Default(.mouseSensitivity) private var mouseSensitivity
    /// Whether core option writes should be scoped to the current game hash (if available).
    @AppStorage("PauseTileMenu.coreOptionsPerGame") private var coreOptionsPerGame = true
    /// Easy kill-switch for the deferred restart workflow.
    @AppStorage("PauseTileMenu.deferredRestartPromptEnabled") private var deferredRestartPromptEnabled = true
    @AppStorage("PauseTileMenu.skinScope") private var skinScopeRaw = SkinScope.game.rawValue
    @State private var selectedSkinOrientation: SkinOrientation = .portrait

    // Camera position for recording overlay — iOS only
    #if os(iOS)
    @Default(.recordingCameraPosition) private var recordingCameraPosition
    #endif

    #if os(iOS)
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @StateObject private var gamepadManager = GamepadManager.shared
    /// Live width of the floating tile panel (driven by GeometryReader in `body`).
    /// Mirrors the `panelWidth` local in the layout so that controller nav helpers
    /// can compute the actual column count per row without re-deriving from UIScreen.
    @State private var currentPanelWidth: CGFloat = 0
    #endif

    private var isLandscape: Bool {
        #if os(iOS)
        if horizontalSizeClass == .regular && verticalSizeClass == .compact { return true }
        return orientation.isLandscape
        #else
        return true
        #endif
    }

    private var palette: UXThemePalette { themeManager.currentPalette }
    private var currentRoute: PauseTileMenuRoute { routeStack.last ?? .root }
    private var currentCoreOptionsMD5Scope: String? {
        guard coreOptionsPerGame else { return nil }
        guard let coreClass = type(of: emulatorVC.core) as? CoreOptional.Type else { return nil }
        return coreClass.currentGameMD5
    }

    /// Resolves the active game/system identifier to a concrete `SystemIdentifier`.
    private var activeSystemIdentifier: SystemIdentifier {
        let candidates: [String?] = [
            emulatorVC.game?.system?.identifier,
            emulatorVC.game?.systemIdentifier,
            emulatorVC.core.systemIdentifier
        ]
        let parsed = candidates.compactMap { raw -> SystemIdentifier? in
            guard let raw, !raw.isEmpty else { return nil }
            return SystemIdentifier(rawValue: raw)
        }
        return parsed.first(where: { $0 != .RetroArch }) ?? parsed.first ?? .RetroArch
    }

    // MARK: - Rebuild cached sections via view model

    /// Triggers a full section rebuild. Call on appear and after any option mutation.
    private func rebuildSections() {
        viewModel.rebuild(
            emulatorVC: emulatorVC,
            metalFilterMode: metalFilterMode,
            showFPSCount: showFPSCount,
            hapticFeedbackEnabled: hapticFeedbackEnabled,
            featureFlags: featureFlags,
            indicatorRegistry: indicatorRegistry,
            hasControllerProfiles: hasControllerProfiles,
            hardwareSwitchStates: hardwareSwitchStates,
            coreOptionsMD5: currentCoreOptionsMD5Scope,
            route: currentRoute
        )
        refreshSearchResults()
    }

    /// Returns the first focusable tile identifier in display order.
    private func firstEnabledTileID() -> String? {
        for section in viewModel.sections {
            if let tile = section.tiles.first(where: { $0.isEnabled }) {
                return tile.id
            }
        }
        return nil
    }

    /// Returns the enabled tile object for an ID, if any.
    private func tile(forID id: String) -> PauseMenuTile? {
        for section in viewModel.sections {
            if let tile = section.tiles.first(where: { $0.id == id && $0.isEnabled }) {
                return tile
            }
        }
        return nil
    }

    /// Grid coordinate for a tile within its section: (sectionIndex, row, col).
    /// `row` and `col` are computed against `cols` (the live column count); rows
    /// are full-width except the last, which may be partial.
    private struct TileGridCoord: Equatable {
        let sectionIndex: Int
        let row: Int
        let col: Int
    }

    /// Locates the grid coordinate for a tile ID, using `cols` as the row width.
    /// Returns nil when the tile isn't part of the currently rendered grid.
    private func gridCoord(forTileID id: String, cols: Int) -> TileGridCoord? {
        guard cols > 0 else { return nil }
        for (sectionIndex, section) in viewModel.sections.enumerated() {
            if let idx = section.tiles.firstIndex(where: { $0.id == id }) {
                return TileGridCoord(sectionIndex: sectionIndex, row: idx / cols, col: idx % cols)
            }
        }
        return nil
    }

    /// Returns the tile ID at the given grid coordinate, walking past disabled
    /// tiles to the nearest enabled tile in the same row/section.
    /// Search order: requested col → leftward in row → rightward in row.
    private func tileID(at coord: TileGridCoord, cols: Int) -> String? {
        guard cols > 0,
              coord.sectionIndex >= 0,
              coord.sectionIndex < viewModel.sections.count else { return nil }
        let tiles = viewModel.sections[coord.sectionIndex].tiles
        let rowStart = coord.row * cols
        guard rowStart < tiles.count else { return nil }
        let rowEnd = min(rowStart + cols, tiles.count)
        let rowTiles = Array(tiles[rowStart..<rowEnd])
        let clampedCol = max(0, min(rowTiles.count - 1, coord.col))
        // Try requested column first, then expand outward.
        if rowTiles[clampedCol].isEnabled { return rowTiles[clampedCol].id }
        for offset in 1..<rowTiles.count {
            let left = clampedCol - offset
            if left >= 0, rowTiles[left].isEnabled { return rowTiles[left].id }
            let right = clampedCol + offset
            if right < rowTiles.count, rowTiles[right].isEnabled { return rowTiles[right].id }
        }
        return nil
    }

    /// Row count for a section given the current column count.
    private func rowCount(forSectionIndex sectionIndex: Int, cols: Int) -> Int {
        guard cols > 0,
              sectionIndex >= 0,
              sectionIndex < viewModel.sections.count else { return 0 }
        let n = viewModel.sections[sectionIndex].tiles.count
        return (n + cols - 1) / cols
    }

    #if os(iOS)
    /// Current column count, derived from the live panel width measured by
    /// the GeometryReader in `body`. Falls back to 2 if width hasn't propagated
    /// yet (e.g. first frame).
    private func currentColumnCount() -> Int {
        let width = currentPanelWidth > 0 ? currentPanelWidth : panelMaxWidth
        return columnCount(for: width)
    }
    #endif

    /// Moves focus horizontally within the current row. Clamps at row edges
    /// (no wraparound to adjacent rows), matching platform convention.
    private func moveFocus(deltaCol: Int, cols: Int) {
        guard deltaCol != 0, cols > 0 else { return }
        guard let id = focusedTileID else {
            focusedTileID = firstEnabledTileID()
            return
        }
        guard let coord = gridCoord(forTileID: id, cols: cols) else {
            focusedTileID = firstEnabledTileID()
            return
        }
        let tiles = viewModel.sections[coord.sectionIndex].tiles
        let rowStart = coord.row * cols
        let rowEnd = min(rowStart + cols, tiles.count)
        let rowWidth = rowEnd - rowStart
        let step = deltaCol > 0 ? 1 : -1
        var col = coord.col + step
        while col >= 0, col < rowWidth {
            if tiles[rowStart + col].isEnabled {
                focusedTileID = tiles[rowStart + col].id
                return
            }
            col += step
        }
        // No enabled tile found in this row in that direction — stay put.
    }

    /// Moves focus vertically, first walking rows within the current section
    /// then crossing into the adjacent section's nearest row while preserving
    /// the column (snapped to the last column when the new row is shorter).
    private func moveFocus(deltaRow: Int, cols: Int) {
        guard deltaRow != 0, cols > 0 else { return }
        guard let id = focusedTileID else {
            focusedTileID = firstEnabledTileID()
            return
        }
        guard let coord = gridCoord(forTileID: id, cols: cols) else {
            focusedTileID = firstEnabledTileID()
            return
        }
        let step = deltaRow > 0 ? 1 : -1
        var sectionIndex = coord.sectionIndex
        var row = coord.row + step
        // Walk row-by-row (and section-by-section at boundaries) until an
        // enabled tile is found or we run off the ends.
        while sectionIndex >= 0, sectionIndex < viewModel.sections.count {
            let rows = rowCount(forSectionIndex: sectionIndex, cols: cols)
            if row < 0 {
                // Step into previous section's last row.
                sectionIndex -= 1
                if sectionIndex < 0 { return }
                row = max(0, rowCount(forSectionIndex: sectionIndex, cols: cols) - 1)
                continue
            }
            if row >= rows {
                // Step into next section's first row.
                sectionIndex += 1
                row = 0
                continue
            }
            let candidate = TileGridCoord(sectionIndex: sectionIndex, row: row, col: coord.col)
            if let nextID = tileID(at: candidate, cols: cols) {
                focusedTileID = nextID
                return
            }
            row += step
        }
    }

    /// Activates the currently focused tile via the standard tile handler.
    private func activateFocusedTile() {
        guard let id = focusedTileID, let tile = tile(forID: id) else { return }
        handle(tile)
    }

    /// Reattaches focus to a valid tile when tvOS focus is lost after lifecycle transitions.
    private func reattachTVOSFocusIfNeeded() {
        #if os(tvOS)
        let focusedID = focusedTileID
        let hasValidFocus = viewModel.sections.contains { section in
            section.tiles.contains(where: { $0.id == focusedID && $0.isEnabled })
        }
        guard !hasValidFocus else { return }
        guard let fallbackID = firstEnabledTileID() else { return }
        DispatchQueue.main.async {
            focusedTileID = fallbackID
        }
        #endif
    }

    /// Pushes a submenu route and refreshes section data/focus.
    private func pushRoute(_ route: PauseTileMenuRoute) {
        if route == .root {
            routeStack = [.root]
        } else {
            routeStack.append(route)
        }
        rebuildSections()
        reattachTVOSFocusIfNeeded()
    }

    /// Pops one submenu level; returns true when a route was popped.
    @discardableResult
    private func popRoute() -> Bool {
        guard routeStack.count > 1 else { return false }
        routeStack.removeLast()
        rebuildSections()
        reattachTVOSFocusIfNeeded()
        return true
    }

    /// Handles controller/menu back by popping submenus before dismissing the pause menu.
    private func handleBackCommand() {
        if !popRoute() {
            requestPauseMenuClose()
        }
    }

    /// Current header title for the active tile-menu route.
    private var routeTitle: String {
        switch currentRoute {
        case .root:
            return String(localized: "GAME MENU")
        case .states:
            return String(localized: "STATES")
        case .options:
            return String(localized: "OPTIONS")
        case .recording:
            return String(localized: "RECORDING")
        case .core:
            return String(localized: "CORE")
        case .skins:
            return String(localized: "SKINS")
        }
    }

    // MARK: - Tile action dispatcher

    private func handle(_ tile: PauseMenuTile) {
        guard tile.isEnabled else { return }
        if let destination = tile.destinationRoute {
            pushRoute(destination)
            return
        }
        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        switch tile.id {
        case "resume":
            requestPauseMenuClose()
        case "saveState":
            let screenshot = emulatorVC.captureScreenshot()
            Task { @MainActor in
                do {
                    try await emulatorVC.createNewSaveState(auto: false, screenshot: screenshot)
                } catch {
                    ELOG("Tile menu save state error: \(error.localizedDescription)")
                }
                dismissAction(true)
            }
        case "loadState":
            guard let game = emulatorVC.game, !game.isInvalidated,
                  let mostRecent = game.saveStates.sorted(byKeyPath: "date", ascending: false).first else { return }
            dismissAction(false)
            Task { @MainActor [weak emulatorVC = emulatorVC] in
                await emulatorVC?.loadSaveState(mostRecent)
            }
        case "browseSaves":
            showingSaveStateBrowser = true
        case "autoSaveState":
            Defaults[.timedAutoSaves].toggle()
            rebuildSections()
        case "reset":
            dismissAction(true)
            emulatorVC.core.resetEmulation()
        case "cheats":
            dismissForSubSheetThen { self.emulatorVC.showCheatsMenu() }
        case "gameInfo":
            dismissForSubSheetThen { self.emulatorVC.showMoreInfo() }
        case "networkPlay":
            showingNetworkPlay = true
        case "controllerProfile":
            showingControllerProfiles = true
        case "screenshot":
            dismissAction(true)
            emulatorVC.takeScreenshot()
        case "screenshots":
            showingScreenshotBrowser = true
        case "logViewer":
            showingLogViewer = true
        case "appSettings":
            showingAppSettings = true
        case "saveQuit":
            dismissAction(false)
            let image = emulatorVC.captureScreenshot()
            Task { @MainActor in
                do {
                    try await emulatorVC.createNewSaveState(auto: true, screenshot: image)
                    await emulatorVC.quit(optionallySave: false)
                } catch {
                    ELOG("Tile menu save & quit error: \(error.localizedDescription)")
                }
            }
        case "quit":
            dismissAction(false)
            Task { @MainActor in
                await emulatorVC.quit(optionallySave: false)
            }

        // MARK: Companion Controller
        case "companionController":
            #if os(iOS) || targetEnvironment(macCatalyst)
            dismissForSubSheetThen { self.emulatorVC.presentCompanionController() }
            #endif

        // MARK: Transfer Pak config sheet
        case "transferPak":
            // Freeze the Realm object on the current (main) thread before opening the sheet,
            // so the sheet closure never touches a live Realm instance on an unknown thread.
            // Only present the sheet when the game is available and not invalidated.
            if let rawGame = emulatorVC.game, !rawGame.isInvalidated {
                frozenTransferPakGame = rawGame.isFrozen ? rawGame : rawGame.freeze()
                showingTransferPakConfig = true
            } else {
                ELOG("Transfer Pak config requested but emulatorVC.game was nil or invalidated; sheet will not be shown.")
            }

        // MARK: N64 Controller Pak slot picker
        case "n64PakSlots":
            showingN64PakConfig = true

        // MARK: Palette picker sheet
        case "palette":
            showingPalettePicker = true

        // MARK: Quick-settings tiles
        case "filterCycle":
            cycleFilter()
        case "mouseInputSource":
            let sources = availableMouseInputSources()
            guard !sources.isEmpty else { return }
            let currentIndex = sources.firstIndex(of: mouseInputSource) ?? 0
            let next = sources[(currentIndex + 1) % sources.count]
            mouseInputSource = next
            rebuildSections()
        case "mouseSensitivity":
            cycleMouseSensitivity()
        case "fastForwardToggle":
            let isFastForwarding = emulatorVC.core.gameSpeed == .fast || emulatorVC.core.gameSpeed == .veryFast
            applyGameSpeed(isFastForwarding ? .normal : .fast)
        case "gameSpeedCycle":
            let speeds = GameSpeed.allCases
            let current = emulatorVC.core.gameSpeed
            let currentIndex = speeds.firstIndex(of: current) ?? 0
            let next = speeds[(currentIndex + 1) % speeds.count]
            applyGameSpeed(next)
        case "fpsCounterToggle":
            showFPSCount.toggle()
            rebuildSections()
        case "rewindToggle":
            guard let coreClass = type(of: emulatorVC.core) as? CoreOptional.Type,
                  let rewindOption = findRewindOption(in: coreClass.options) else { return }
            let currentValue: Bool = coreClass.valueForOption(rewindOption, andMD5: currentCoreOptionsMD5Scope)
            coreClass.setValue(!currentValue, forOption: rewindOption, andMD5: currentCoreOptionsMD5Scope)
            if optionRequiresRestart(rewindOption), deferredRestartPromptEnabled {
                pendingCoreReset = true
            }
            rebuildSections()
        case "rumbleToggle":
            hapticFeedbackEnabled.toggle()
            rebuildSections()
        case "keyboardToggle":
            #if canImport(UIKit) && !os(tvOS)
            emulatorVC.toggleVirtualKeyboard()
            // Dismiss the menu so the user can interact with the keyboard overlay.
            // The tile menu keeping the game paused while showing the overlay is unhelpful.
            dismissAction(true)
            #endif
        case "mouseToggle":
            #if canImport(UIKit) && !os(tvOS)
            emulatorVC.toggleVirtualMouse()
            // Dismiss the menu so the user can interact with the mouse overlay.
            dismissAction(true)
            #endif
        case "jitStatus":
            break // read-only

        // MARK: Shader settings sheet
        case "shaderSettings":
            showingShaderSettings = true

        // MARK: Port device type picker
        case "portDevices":
            showingPortDevices = true
        case "legacyPortDevices":
            showingLegacyPortDevices = true

        // MARK: MIDI device picker
        case "midiDevice":
            showingMIDIPicker = true
        case "retroArchMIDIToggle":
            Defaults[.retroArchMIDIEnabled].toggle()
            rebuildSections()

        // MARK: Light gun overlay toggle (iOS-only)
        case "lightGun":
            #if os(iOS) && !targetEnvironment(macCatalyst)
            emulatorVC.toggleLightGun()
            rebuildSections()
            #endif

        // MARK: Skins submenu actions
        case "skins_pick_for_system":
            showingSystemSkinSelection = true
        case "skins_scope":
            let allScopes = SkinScope.allCases
            let currentScope = SkinScope(rawValue: skinScopeRaw) ?? .game
            let currentIndex = allScopes.firstIndex(of: currentScope) ?? 0
            let nextScope = allScopes[(currentIndex + 1) % allScopes.count]
            skinScopeRaw = nextScope.rawValue
            rebuildSections()
        case "skins_pick_portrait":
            selectedSkinOrientation = .portrait
            showingSystemSkinSelection = true
        case "skins_pick_landscape":
            selectedSkinOrientation = .landscape
            showingSystemSkinSelection = true
        case "skins_button_effect":
            showingButtonEffectPicker = true
        case "skins_button_sound":
            showingButtonSoundPicker = true
        case "skins_browse_catalog":
            showingSkinCatalog = true
        case "skins_import_file":
            #if !os(tvOS)
            showingSkinImporter = true
            #endif

        // MARK: Recording / broadcast / clip
        case "recording":
            #if os(iOS)
            if emulatorVC.isRecording {
                dismissForSubSheetThen { self.emulatorVC.stopScreenRecording() }
            } else {
                dismissThenResumeAndRun { self.emulatorVC.startScreenRecording() }
            }
            #endif
        case "broadcast":
            #if os(iOS) || os(tvOS)
            if emulatorVC.isBroadcasting {
                dismissForSubSheetThen { self.emulatorVC.stopBroadcast() }
            } else {
                dismissForSubSheetThen { self.emulatorVC.startBroadcast() }
            }
            #endif
        case "saveClip":
            #if os(iOS) || os(tvOS)
            dismissAction(true)
            emulatorVC.saveClip()
            #endif

        // MARK: Camera position cycle
        case "cameraPosition":
            #if os(iOS)
            let all = CameraPosition.allCases
            if let idx = all.firstIndex(of: recordingCameraPosition) {
                recordingCameraPosition = all[(idx + 1) % all.count]
            }
            rebuildSections()
            #endif

        // MARK: AirPlay
        case "airPlay":
            #if os(iOS) || targetEnvironment(macCatalyst)
            triggerAirPlayPicker = true
            #else
            break
            #endif
        case "retroArchMenu":
            guard let action = (emulatorVC.core as? CoreActions)?.coreActions?.first(where: { $0.title == RetroArchCoreActionTitles.internalMenu }) else {
                ELOG("retroArchMenu: failed to get CoreAction — core type: \(type(of: emulatorVC.core)), conforms to CoreActions: \(emulatorVC.core is CoreActions)")
                return
            }
            DLOG("retroArchMenu: got action, dismissing then toggling RA menu")
            let emulatorVC = self.emulatorVC
            emulatorVC.dismissNav(resumeEmulation: true) {
                DLOG("retroArchMenu: dismiss completed, calling handleCoreAction")
                emulatorVC.handleCoreAction(action)
            }
        case "retroArchSettings":
            showingRetroArchSettings = true
        case "audioVisualizer":
            #if os(iOS)
            if emulatorVC.visualizerMode == .off {
                let restoreMode = VisualizerMode.current != .off ? VisualizerMode.current : .standard
                emulatorVC.setVisualizerMode(restoreMode)
            } else {
                emulatorVC.setVisualizerMode(.off)
            }
            rebuildSections()
            #endif

        // MARK: Core action tiles
        case let id where id.hasPrefix(CoreActionTileProvider.idPrefix):
            guard let actionTitle = CoreActionTileProvider.actionTitle(fromTileID: id),
                  let coreWithActions = emulatorVC.core as? CoreActions,
                  let action = coreWithActions.coreActions?.first(where: { $0.title == actionTitle }) else { return }
            if action.options != nil {
                pendingCoreAction = action
            } else {
                let emulatorVC = self.emulatorVC
                emulatorVC.dismissNav(resumeEmulation: true) {
                    emulatorVC.handleCoreAction(action)
                }
            }

        // MARK: Core option toggle/cycle tiles
        case let id where id.hasPrefix(CoreOptionTileProvider.idPrefix):
            guard let (optIndex, key) = CoreOptionTileProvider.optionIndexAndKey(fromTileID: id),
                  let coreClass = type(of: emulatorVC.core) as? CoreOptional.Type,
                  let option = CoreOptionTileProvider.findOption(atIndex: optIndex, key: key, in: coreClass.options) else { return }
            switch option {
            case .bool:
                let currentValue: Bool = coreClass.valueForOption(option, andMD5: currentCoreOptionsMD5Scope)
                coreClass.setValue(!currentValue, forOption: option, andMD5: currentCoreOptionsMD5Scope)
            case .enumeration, .multi:
                CoreOptionTileProvider.cycleNextValue(for: option, coreClass: coreClass, md5Scope: currentCoreOptionsMD5Scope)
            default:
                break
            }
            if optionRequiresRestart(option), deferredRestartPromptEnabled {
                pendingCoreReset = true
            }
            rebuildSections()

        // MARK: Core settings gateway
        case CoreOptionTileProvider.coreSettingsTileID:
            dismissForSubSheetThen { self.emulatorVC.showCoreOptions() }
        case let id where id.hasPrefix(PauseTileMenuViewModel.hardwareSwitchTilePrefix):
            guard let descriptor = hardwareSwitchDescriptor(forTileID: id) else { return }
            let current = hardwareSwitchStates[descriptor.id] ?? descriptor.defaultState
            let next = !current
            hardwareSwitchStates[descriptor.id] = next
            let selectedButtonId = next ? descriptor.positions.on.buttonId : descriptor.positions.off.buttonId
            dispatchHardwareSwitchButton(selectedButtonId)
            rebuildSections()
        case let id where id.hasPrefix(PauseTileMenuViewModel.hardwareMomentaryTilePrefix):
            guard let descriptor = hardwareMomentaryDescriptor(forTileID: id) else { return }
            dispatchHardwareSwitchButton(descriptor.buttonId)

        case let id where id.hasPrefix(SystemButtonTileProvider.tileIDPrefix):
            dispatchSystemButton(tileID: id)

        default:
            break
        }
    }

    /// Handle a long-press option selection (e.g. pick a specific filter or enum value).
    private func handleLongPressOption(_ lpOption: PauseMenuTileLongPressOption, for tile: PauseMenuTile) {
        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        if tile.id == "filterCycle" {
            // Match by stable ID (filter_<rawValue>) to avoid brittle title/description comparisons.
            let selected = MetalFilterSelectionOption.allCases.first { f in
                "filter_\(f.rawValue)" == lpOption.id
            }
            if let filter = selected {
                metalFilterMode = .always(filter: filter)
            }
            rebuildSections()
            return
        }

        if tile.id == "gameSpeedCycle" {
            if lpOption.id.hasPrefix("gameSpeed_"),
               let raw = Int(lpOption.id.replacingOccurrences(of: "gameSpeed_", with: "")),
               let selectedSpeed = GameSpeed(rawValue: raw) {
                applyGameSpeed(selectedSpeed)
            }
            return
        }

        if tile.id == "audioVisualizer" {
            #if os(iOS)
            if lpOption.id.hasPrefix("audioViz_mode_"),
               let rawValue = Int(lpOption.id.replacingOccurrences(of: "audioViz_mode_", with: "")),
               let mode = VisualizerMode(rawValue: rawValue) {
                emulatorVC.setVisualizerMode(mode)
                rebuildSections()
            }
            #endif
            return
        }

        if tile.id == "mouseInputSource" {
            if lpOption.id.hasPrefix("mouseSource_") {
                let raw = lpOption.id.replacingOccurrences(of: "mouseSource_", with: "")
                if let source = MouseInputSource(rawValue: raw) {
                    mouseInputSource = source
                    rebuildSections()
                }
            }
            return
        }

        if tile.id == "mouseSensitivity" {
            if lpOption.id.hasPrefix("mouseSensitivity_"),
               let hundredths = Double(lpOption.id.replacingOccurrences(of: "mouseSensitivity_", with: "")) {
                mouseSensitivity = hundredths / 100.0
                rebuildSections()
            }
            return
        }

        if tile.id == "skins_scope" {
            if lpOption.id.hasPrefix("skinScope_") {
                let raw = lpOption.id.replacingOccurrences(of: "skinScope_", with: "")
                if let scope = SkinScope(rawValue: raw) {
                    skinScopeRaw = scope.rawValue
                    rebuildSections()
                }
            }
            return
        }

        if tile.id == "autoSaveState" {
            if lpOption.id == "autosave_off" {
                Defaults[.timedAutoSaves] = false
                rebuildSections()
                return
            }
            if lpOption.id.hasPrefix("autosave_interval_"),
               let seconds = TimeInterval(lpOption.id.replacingOccurrences(of: "autosave_interval_", with: "")) {
                Defaults[.timedAutoSaveInterval] = seconds
                Defaults[.timedAutoSaves] = true
                rebuildSections()
            }
            return
        }

        #if os(iOS)
        if tile.id == "cameraPosition" {
            if let pos = CameraPosition.allCases.first(where: { "camPos_\($0.rawValue)" == lpOption.id }) {
                recordingCameraPosition = pos
                rebuildSections()
            }
            return
        }
        #endif

        if tile.id.hasPrefix(CoreActionTileProvider.idPrefix) {
            guard let actionTitle = CoreActionTileProvider.actionTitle(fromTileID: tile.id),
                  let coreWithActions = emulatorVC.core as? CoreActions,
                  let action = coreWithActions.coreActions?.first(where: { $0.title == actionTitle }),
                  let opts = action.options else { return }
            let selectedAction = CoreAction(
                title: action.title,
                requiresReset: action.requiresReset,
                options: opts.map { CoreActionOption(title: $0.title, selected: $0.title == lpOption.title) },
                style: action.style
            )
            emulatorVC.dismissNav(resumeEmulation: true) {
                self.emulatorVC.handleCoreAction(selectedAction)
            }
            return
        }

        if tile.id.hasPrefix(CoreOptionTileProvider.idPrefix) {
            guard let (optIndex, key) = CoreOptionTileProvider.optionIndexAndKey(fromTileID: tile.id),
                  let coreClass = type(of: emulatorVC.core) as? CoreOptional.Type,
                  let option = CoreOptionTileProvider.findOption(atIndex: optIndex, key: key, in: coreClass.options) else { return }
            CoreOptionTileProvider.selectValue(titled: lpOption.title, for: option, coreClass: coreClass, md5Scope: currentCoreOptionsMD5Scope)
            if optionRequiresRestart(option), deferredRestartPromptEnabled {
                pendingCoreReset = true
            }
            rebuildSections()
        }
    }

    private func dismissForSubSheetThen(_ action: @escaping () -> Void) {
        emulatorVC.dismissNav(resumeEmulation: false, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
        })
    }

    /// Dismisses the tile menu while resuming emulation, then runs follow-up work.
    /// This avoids running ReplayKit start logic while the pause-menu dismissal
    /// transition is still in flight.
    private func dismissThenResumeAndRun(_ action: @escaping () -> Void) {
        emulatorVC.dismissNav(resumeEmulation: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
        })
    }

    /// Routes pause-menu closure through deferred restart flow when enabled.
    private func requestPauseMenuClose() {
        guard pendingCoreReset, deferredRestartPromptEnabled else {
            dismissAction(true)
            return
        }
        showingDeferredRestartPrompt = true
    }

    /// Resets core options for the selected scope (per-game or global).
    private func resetCoreSettingsForCurrentScope() {
        guard let coreClass = type(of: emulatorVC.core) as? CoreOptional.Type else { return }
        if let md5 = currentCoreOptionsMD5Scope, !md5.isEmpty {
            coreClass.resetAllOptions(forMD5: md5)
        } else {
            coreClass.resetAllOptions()
        }
        if deferredRestartPromptEnabled, coreHasRestartRequiredOption(in: coreClass.options) {
            pendingCoreReset = true
        }
        rebuildSections()
    }

    private func coreHasRestartRequiredOption(in options: [CoreOption]) -> Bool {
        for option in options {
            switch option {
            case let .group(_, subOptions):
                if coreHasRestartRequiredOption(in: subOptions) {
                    return true
                }
            default:
                if optionRequiresRestart(option) {
                    return true
                }
            }
        }
        return false
    }

    /// Applies game-speed changes and mirrors fast-forward toggling for libretro cores.
    private func applyGameSpeed(_ speed: GameSpeed) {
        let wasFastForwarding = emulatorVC.core.gameSpeed == .fast || emulatorVC.core.gameSpeed == .veryFast
        emulatorVC.setGameSpeedRespectingAchievements(speed)
        let isFastForwarding = emulatorVC.core.gameSpeed == .fast || emulatorVC.core.gameSpeed == .veryFast
        if emulatorVC.core.coreIdentifier?.contains("libretro") == true, wasFastForwarding != isFastForwarding {
            dispatchHardwareButton("togglefastforward")
        }
        rebuildSections()
    }

    /// Handles a deferred core restart after closing the pause menu.
    private func performDeferredCoreRestart(createSaveState: Bool) {
        let screenshot = createSaveState ? emulatorVC.captureScreenshot() : nil
        dismissAction(true)
        Task { @MainActor in
            if let screenshot {
                do {
                    try await emulatorVC.createNewSaveState(auto: true, screenshot: screenshot)
                } catch {
                    ELOG("Deferred restart autosave failed: \(error.localizedDescription)")
                }
            }
            emulatorVC.core.resetEmulation()
            pendingCoreReset = false
        }
    }

    /// Returns true when an option's metadata indicates a restart is required.
    private func optionRequiresRestart(_ option: CoreOption) -> Bool {
        switch option {
        case let .bool(display, _, _),
             let .range(display, _, _, _),
             let .rangef(display, _, _, _),
             let .multi(display, _, _),
             let .enumeration(display, _, _, _),
             let .string(display, _, _):
            return display.requiresRestart
        case .group:
            return false
        }
    }

    // MARK: - Filter cycling helper

    private func cycleFilter() {
        let all = MetalFilterSelectionOption.allCases
        let current = MetalFilterModeOption.parseCurrentFilter(from: metalFilterMode)
        let idx = all.firstIndex(of: current) ?? 0
        let next = all[(idx + 1) % all.count]
        metalFilterMode = next == .none ? .none : .always(filter: next)
        rebuildSections()
    }

    /// Plays a sample click when selecting a button sound style.
    private func playButtonSoundSample(_ sound: ButtonSound) {
        guard sound != .none else { return }
        ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
    }

    #if !os(tvOS)
    /// Supported import types for skin package files.
    private var supportedSkinTypes: [UTType] {
        var skinTypes: [UTType] = [UTType.deltaSkin, UTType.deltaAppSkin, UTType.manicSkin, .archive]
        if let deltaskinData = UTType(filenameExtension: "deltaskin", conformingTo: .data) { skinTypes.append(deltaskinData) }
        if let manicData = UTType(filenameExtension: "manicskin", conformingTo: .data) { skinTypes.append(manicData) }
        if let deltaskinPackage = UTType(filenameExtension: "deltaskin", conformingTo: .package) { skinTypes.append(deltaskinPackage) }
        if let manicPackage = UTType(filenameExtension: "manicskin", conformingTo: .package) { skinTypes.append(manicPackage) }
        if let deltaskinArchive = UTType(filenameExtension: "deltaskin", conformingTo: .archive) { skinTypes.append(deltaskinArchive) }
        if let manicArchive = UTType(filenameExtension: "manicskin", conformingTo: .archive) { skinTypes.append(manicArchive) }
        return skinTypes
    }

    /// Imports selected skin files and refreshes the tile badges afterward.
    private func importSkins(from urls: [URL]) async {
        do {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                try await DeltaSkinManager.shared.importSkin(from: url)
            }
            await DeltaSkinManager.shared.reloadSkins()
            rebuildSections()
        } catch {
            skinImportErrorMessage = error.localizedDescription
            showingSkinImportError = true
            ELOG("Tile menu skin import failed: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Layout helpers

    /// Column count driven by available horizontal space.
    private func columnCount(for width: CGFloat) -> Int {
        #if os(tvOS)
        return 6
        #else
        if width >= 500 { return 5 }
        if width >= 400 { return 4 }
        if width >= 280 { return 3 }
        return 2
        #endif
    }

    private var panelMaxWidth: CGFloat {
        #if os(tvOS)
        return 860
        #else
        return isLandscape ? 560 : 420
        #endif
    }

    // MARK: - Tile view

    @ViewBuilder
    private func tileView(for tile: PauseMenuTile) -> some View {
        let accentColor = color(for: tile.colorKey)
        let opacity: Double = tile.isEnabled ? 1.0 : 0.4
        let isFocused = focusedTileID == tile.id

        #if os(tvOS)
        let iconSize: CGFloat = 30
        let labelSize: CGFloat = 13
        let badgeSize: CGFloat = 10
        #else
        let iconSize: CGFloat = 20
        let labelSize: CGFloat = 10
        let badgeSize: CGFloat = 8
        #endif
        let cornerRadius = RetroPauseChrome.menuCellCornerRadius()

        Button {
            handle(tile)
        } label: {
            GeometryReader { geo in
                let side = geo.size.width
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Image(systemName: tile.icon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundColor(accentColor)
                            .shadow(color: accentColor.opacity(isFocused ? 1.0 : 0.7), radius: isFocused ? 10 : 5)

                        Text(tile.label)
                            .font(.system(size: labelSize, weight: isFocused ? .bold : .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 4)
                        Spacer(minLength: 0)
                    }
                    .frame(width: side, height: side)

                    if let badge = tile.badge {
                        Text(badge)
                            .font(.system(size: badgeSize, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(accentColor)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(width: side, height: side)
            }
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(accentColor.opacity(isFocused ? RetroPauseChrome.menuCellFillOpacityFocused : RetroPauseChrome.menuCellFillOpacityUnfocused))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                accentColor.opacity(isFocused ? RetroPauseChrome.menuCellStrokeOpacityFocused : RetroPauseChrome.menuCellStrokeOpacityUnfocused),
                                lineWidth: isFocused ? RetroPauseChrome.menuCellStrokeWidthFocused : RetroPauseChrome.menuCellStrokeWidthUnfocused
                            )
                    )
            )
            .shadow(
                color: isFocused ? accentColor.opacity(RetroPauseChrome.menuCellFocusShadowOpacity) : .clear,
                radius: RetroPauseChrome.menuCellFocusShadowRadius,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(TileButtonStyle(isFocused: isFocused))
        .opacity(opacity)
        .disabled(!tile.isEnabled)
        .id(tile.id)
        .focused($focusedTileID, equals: tile.id)
        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isFocused)
        .optionalContextMenu(tile.longPressOptions) { opt in
            handleLongPressOption(opt, for: tile)
        }
    }

    private func color(for key: PauseMenuTileColor) -> Color {
        switch key {
        case .green:  return .retroGreen
        case .orange: return .retroOrange
        case .blue:   return .retroBlue
        case .purple: return .retroPurple
        case .pink:   return .retroPink
        case .cyan:   return .retroCyan
        case .yellow: return .retroYellow
        case .gray:   return .gray
        case .teal:   return Color(red: 0.0, green: 0.8, blue: 0.75)
        case .red:    return Color(red: 0.95, green: 0.2, blue: 0.25)
        }
    }

    private var panelBackground: some View {
        RetroPausePanelBackground(isDark: true)
    }

    // MARK: - Section view

    private func sectionView(section: PauseMenuTileSection, cols: Int, spacing: CGFloat) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            if let title = section.title {
                Text(title)
                    .font(.system(size: tvOSAdjusted(9, tvOS: 13), weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(tvOSAdjusted(1.5, tvOS: 2.5))
                    .padding(.horizontal, 2)
            }
            #if os(tvOS)
            /// Eager row layout on tvOS: `LazyVGrid` defers rendering of rows below
            /// the scroll viewport, which the focus engine reads as "no downward
            /// candidate" and snaps focus back to the first tile. Rendering every
            /// row up-front (pause menu has ~30 tiles, not a large list) gives the
            /// focus engine stable vertical navigation across all sections.
            eagerTileRows(tiles: section.tiles, cols: cols, spacing: spacing)
            #else
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols), spacing: spacing) {
                ForEach(section.tiles) { tile in
                    tileView(for: tile)
                }
            }
            #endif
        }
    }

    #if os(tvOS)
    /// Eagerly-rendered row-major grid built from a linear tile list. Used on tvOS
    /// in place of `LazyVGrid` so the focus engine can see every row as a valid
    /// navigation target even when it's currently scrolled off-screen.
    private func eagerTileRows(tiles: [PauseMenuTile], cols: Int, spacing: CGFloat) -> some View {
        let chunks = stride(from: 0, to: tiles.count, by: cols).map {
            Array(tiles[$0..<min($0 + cols, tiles.count)])
        }
        return VStack(spacing: spacing) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { tile in
                        tileView(for: tile)
                            .frame(maxWidth: .infinity)
                    }
                    if row.count < cols {
                        ForEach(0..<(cols - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
    #endif

    /// Thin stylized search bar for global tile lookup.
    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: tvOSAdjusted(11, tvOS: 15), weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            TextField(String(localized: "Search settings"), text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: tvOSAdjusted(11, tvOS: 15), weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, tvOSAdjusted(10, tvOS: 14))
        .padding(.vertical, tvOSAdjusted(6, tvOS: 10))
        .background {
            RetroPauseSearchFieldBackground()
        }
    }

    /// Core-specific toggle controls for option scope and deferred restart behavior.
    private var coreScopeControlsView: some View {
        VStack(spacing: tvOSAdjusted(10, tvOS: 14)) {
            neonToggleRow(
                title: String(localized: "Per-Game Core Options"),
                subtitle: String(localized: "When off, edits apply globally to this core"),
                isOn: $coreOptionsPerGame
            )
            neonToggleRow(
                title: String(localized: "Prompt Restart On Close"),
                subtitle: String(localized: "Ask to save state + restart for required changes"),
                isOn: $deferredRestartPromptEnabled,
                onToggle: { isEnabled in
                    if !isEnabled {
                        pendingCoreReset = false
                    }
                }
            )
        }
    }

    /// Core route footer actions matching the thin neon search-bar styling.
    private var coreRouteFooterActionsView: some View {
        HStack(spacing: tvOSAdjusted(8, tvOS: 12)) {
            coreRouteActionButton(
                title: String(localized: "Reset Game"),
                icon: "arrow.counterclockwise",
                accent: .retroOrange
            ) {
                dismissAction(true)
                emulatorVC.core.resetEmulation()
            }
            coreRouteActionButton(
                title: String(localized: "Reset Core Settings"),
                icon: "gearshape.2",
                accent: .retroCyan
            ) {
                resetCoreSettingsForCurrentScope()
            }
        }
    }

    private func coreRouteActionButton(title: String, icon: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: tvOSAdjusted(11, tvOS: 15), weight: .semibold))
                Text(title)
                    .font(.system(size: tvOSAdjusted(11, tvOS: 15), weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, tvOSAdjusted(10, tvOS: 14))
            .padding(.vertical, tvOSAdjusted(6, tvOS: 10))
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                            .strokeBorder(accent.opacity(0.55), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .tvOSDisableFocusEffect()
    }

    /// Thin neon-styled toggle row that is tap-friendly on iOS and tvOS.
    private func neonToggleRow(title: String, subtitle: String, isOn: Binding<Bool>, onToggle: ((Bool) -> Void)? = nil) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            onToggle?(isOn.wrappedValue)
            rebuildSections()
        } label: {
            HStack(spacing: tvOSAdjusted(10, tvOS: 14)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: tvOSAdjusted(10, tvOS: 14), weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: tvOSAdjusted(9, tvOS: 12), weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer(minLength: 6)
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill((isOn.wrappedValue ? Color.retroCyan : Color.white.opacity(0.20)).opacity(0.22))
                        .overlay(
                            Capsule()
                                .strokeBorder(isOn.wrappedValue ? Color.retroCyan.opacity(0.95) : Color.white.opacity(0.45), lineWidth: 1.2)
                        )
                        .frame(width: tvOSAdjusted(50, tvOS: 70), height: tvOSAdjusted(24, tvOS: 30))
                    Circle()
                        .fill(isOn.wrappedValue ? Color.retroCyan : Color.white.opacity(0.85))
                        .frame(width: tvOSAdjusted(18, tvOS: 24), height: tvOSAdjusted(18, tvOS: 24))
                        .padding(.horizontal, tvOSAdjusted(3, tvOS: 4))
                        .shadow(color: (isOn.wrappedValue ? Color.retroCyan : Color.white).opacity(0.75), radius: 6, x: 0, y: 0)
                }
            }
            .padding(.horizontal, tvOSAdjusted(10, tvOS: 14))
            .padding(.vertical, tvOSAdjusted(8, tvOS: 11))
            .background(
                RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                            .strokeBorder(Color.retroCyan.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .tvOSDisableFocusEffect()
    }

    /// Search result list grouped by ranking order.
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "SEARCH RESULTS"))
                .font(.system(size: tvOSAdjusted(9, tvOS: 13), weight: .heavy))
                .foregroundColor(.white.opacity(0.45))
                .tracking(tvOSAdjusted(1.5, tvOS: 2.5))
                .padding(.horizontal, 2)

            if searchResults.isEmpty {
                Text(String(localized: "No matching settings found."))
                    .font(.system(size: tvOSAdjusted(10, tvOS: 14), weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.top, 4)
            } else {
                ForEach(searchResults) { result in
                    Button {
                        handleSearchResult(result)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: result.tile.icon)
                                .foregroundColor(color(for: result.tile.colorKey))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.tile.label)
                                    .font(.system(size: tvOSAdjusted(11, tvOS: 16), weight: .semibold))
                                    .foregroundColor(.white)
                                Text(result.route.rawValue.uppercased())
                                    .font(.system(size: tvOSAdjusted(8, tvOS: 11), weight: .bold))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            Spacer()
                            if let badge = result.tile.badge {
                                Text(badge)
                                    .font(.system(size: tvOSAdjusted(9, tvOS: 12), weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(color(for: result.tile.colorKey))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, tvOSAdjusted(10, tvOS: 14))
                        .padding(.vertical, tvOSAdjusted(7, tvOS: 10))
                        .background(
                            RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .tvOSDisableFocusEffect()
                }
            }
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed game background — tapping it resumes
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { requestPauseMenuClose() }

                // Floating tile panel
                let panelWidth = min(geo.size.width - 32, panelMaxWidth)
                let cols = columnCount(for: panelWidth)
                let spacing: CGFloat = tvOSAdjusted(6, tvOS: 12)
                let sections = viewModel.sections

                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: tvOSAdjusted(12, tvOS: 20)) {
                            // Panel title
                            HStack {
                                if routeStack.count > 1 {
                                    Button {
                                        _ = popRoute()
                                    } label: {
                                        Label(String(localized: "Back"), systemImage: "chevron.left")
                                            .font(.system(size: tvOSAdjusted(11, tvOS: 17), weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Spacer().frame(width: tvOSAdjusted(46, tvOS: 68))
                                }

                                Spacer()
                                Text(routeTitle)
                                    .font(.system(size: tvOSAdjusted(12, tvOS: 18), weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.55))
                                    .tracking(tvOSAdjusted(2, tvOS: 3.5))
                                Spacer()

                                Spacer().frame(width: tvOSAdjusted(46, tvOS: 68))
                            }
                            .padding(.top, tvOSAdjusted(2, tvOS: 6))

                            searchBarView
                            if currentRoute == .core {
                                coreScopeControlsView
                            }

                            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // Grouped sections — one outer focus section for the whole
                                // tile grid so tvOS treats it as a single focus region.
                                // Per-section focusSections caused focus to snap to the top
                                // when navigating between sections with off-screen tiles
                                // (LazyVGrid defers rendering of rows below the fold).
                                VStack(alignment: .leading, spacing: tvOSAdjusted(12, tvOS: 20)) {
                                    ForEach(sections) { section in
                                        sectionView(section: section, cols: cols, spacing: spacing)
                                        if section.id != sections.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.12))
                                        }
                                    }
                                }
                                #if os(tvOS)
                                .focusSection()
                                #endif
                            } else {
                                searchResultsView
                            }

                            if currentRoute == .core {
                                coreRouteFooterActionsView
                            }
                        }
                        .padding(tvOSAdjusted(12, tvOS: 20))
                    }
                    #if os(tvOS)
                    .onChange(of: focusedTileID) { newID in
                        guard let newID else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scrollProxy.scrollTo(newID, anchor: .center)
                        }
                    }
                    #endif
                    } // ScrollViewReader

                    // Info shelf — shows description for focused/long-pressed tile
                    infoShelfView
                }
                .background(panelBackground)
                .frame(width: panelWidth)
                .frame(maxHeight: geo.size.height * 0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .retroPurple.opacity(0.25), radius: 18, x: 0, y: 0)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                #if os(iOS)
                // Mirror the live panel width into @State so iOS controller
                // navigation helpers can compute the active column count.
                .task(id: panelWidth) { currentPanelWidth = panelWidth }
                #endif
            }
        }
        .sheet(isPresented: $showingSaveStateBrowser) {
            PauseMenuSaveStateBrowserView(emulatorVC: emulatorVC) { stateToLoad in
                showingSaveStateBrowser = false
                guard let state = stateToLoad else { return }
                dismissAction(false)
                Task { @MainActor [weak emulatorVC = emulatorVC] in
                    await emulatorVC?.loadSaveState(state)
                }
            }
        }
        .sheet(isPresented: $showingScreenshotBrowser) {
            PauseMenuScreenshotBrowserView(emulatorVC: emulatorVC) {
                showingScreenshotBrowser = false
            }
        }
        .sheet(isPresented: $showingControllerProfiles) {
            InSessionProfilePickerView(emulatorVC: emulatorVC) {
                showingControllerProfiles = false
            }
        }
        .fullScreenCover(isPresented: $showingLogViewer) {
            RetroLogView(isFullscreen: $showingLogViewer)
        }
        // On tvOS the default `.sheet` modal renders narrow and centred,
        // which makes Settings (a deep nested form) hard to read and
        // navigate with the focus engine. Use `.fullScreenCover` for the
        // App Settings on tvOS — same pattern already used for
        // `showingLogViewer` above. iOS keeps the standard sheet, which
        // sizes correctly there. The settings view's own "Done" button
        // calls `dismissAction` so the user can leave the cover.
        // RetroArch Settings stays as a sheet for now — its registered
        // view doesn't accept a dismissAction, so a fullScreenCover
        // could trap the user without a visible exit on tvOS.
        #if os(tvOS)
        .fullScreenCover(isPresented: $showingAppSettings) {
            if let appSettings = PauseMenuViewRegistry.appSettingsView(dismissAction: {
                showingAppSettings = false
            }) {
                appSettings
            } else {
                EmptyView()
            }
        }
        #else
        .sheet(isPresented: $showingAppSettings) {
            if let appSettings = PauseMenuViewRegistry.appSettingsView(dismissAction: {
                showingAppSettings = false
            }) {
                appSettings
            } else {
                EmptyView()
            }
        }
        #endif
        .sheet(isPresented: $showingRetroArchSettings) {
            if let retroArchSettings = PauseMenuViewRegistry.retroArchSettingsView() {
                retroArchSettings
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingSystemSkinSelection) {
            NavigationStack {
                SystemSkinSelectionView(
                    system: activeSystemIdentifier,
                    game: emulatorVC.game,
                    preferredScope: SkinScope(rawValue: skinScopeRaw) ?? .game,
                    preferredOrientation: selectedSkinOrientation
                )
            }
        }
        .sheet(isPresented: $showingLegacyPortDevices) {
            NavigationStack {
                List {
                    if legacyPortDeviceInfo.isEmpty {
                        Text(String(localized: "No legacy port devices available."))
                    } else {
                        ForEach(Array(legacyPortDeviceInfo.enumerated()), id: \.offset) { portIndex, devices in
                            if devices.count > 1 {
                                SwiftUI.Section(String(format: String(localized: "Port %d"), portIndex + 1)) {
                                    ForEach(devices, id: \.deviceType) { device in
                                        Button(device.name) {
                                            setLegacyPortDevice(device.deviceType, forPort: portIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "Port Devices"))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "Done")) {
                            showingLegacyPortDevices = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSkinCatalog) {
            NavigationStack {
                SkinCatalogBrowserView(
                    preselectedSystem: activeSystemIdentifier.skinCatalogSystemCode,
                    activationContextSystemIdentifier: activeSystemIdentifier,
                    activationContextGameId: emulatorVC.game.flatMap { $0.id.isEmpty ? nil : $0.id }
                )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(String(localized: "Done")) { showingSkinCatalog = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingButtonEffectPicker) {
            NavigationStack {
                List {
                    ForEach(ButtonPressEffect.allCases, id: \.self) { effect in
                        Button {
                            buttonPressEffect = effect
                            showingButtonEffectPicker = false
                            rebuildSections()
                        } label: {
                            HStack {
                                Text(effect.description)
                                Spacer()
                                if effect == buttonPressEffect {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "Button Effect"))
            }
        }
        .sheet(isPresented: $showingButtonSoundPicker) {
            NavigationStack {
                List {
                    ForEach(ButtonSound.allCases, id: \.self) { sound in
                        Button {
                            buttonSound = sound
                            playButtonSoundSample(sound)
                            showingButtonSoundPicker = false
                            rebuildSections()
                        } label: {
                            HStack {
                                Text(sound.description)
                                Spacer()
                                if sound == buttonSound {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "Button Sound"))
            }
        }
        .sheet(isPresented: $showingTransferPakConfig, onDismiss: { frozenTransferPakGame = nil }) {
            if let frozenGame = frozenTransferPakGame {
                let transferCore = emulatorVC.core as? TransferPakSupport
                TransferPakConfigView(
                    game: frozenGame,
                    slotCount: transferCore?.transferPakSlotCount ?? 4,
                    applyLiveSlotChange: transferCore.map { core in
                        { port, rom in core.setTransferPakROM(rom, forPort: port) }
                    },
                    onDismiss: { showingTransferPakConfig = false }
                )
            }
        }
        .sheet(isPresented: $showingN64PakConfig) {
            N64ControllerPakView(
                gameMD5: emulatorVC.game?.md5Hash,
                gameTitle: emulatorVC.game?.title,
                onDismiss: { showingN64PakConfig = false }
            )
        }
        .sheet(isPresented: $showingPalettePicker) {
            if let paletteCore = emulatorVC.core as? PaletteProviding {
                PalettePickerView(paletteCore: paletteCore) {
                    showingPalettePicker = false
                    rebuildSections()
                }
            }
        }
        #if !os(watchOS)
        .sheet(isPresented: $showingNetworkPlay) {
            NetplayLobbyView(
                gameName: emulatorVC.game?.title ?? "",
                coreIdentifier: emulatorVC.core.coreIdentifier ?? "",
                localGameHash: emulatorVC.game?.md5Hash ?? ""
            )
        }
        #endif
        .sheet(isPresented: $showingShaderSettings) {
            ShaderSettingsPauseSheet()
        }
        .sheet(isPresented: $showingPortDevices) {
            PortDevicesPauseSheet(emulatorVC: emulatorVC)
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingSkinImporter,
            allowedContentTypes: supportedSkinTypes,
            allowsMultipleSelection: true
        ) { result in
            Task {
                do {
                    let urls = try result.get()
                    await importSkins(from: urls)
                } catch {
                    skinImportErrorMessage = error.localizedDescription
                    showingSkinImportError = true
                }
            }
        }
        .alert(String(localized: "Skin Import Error"), isPresented: $showingSkinImportError) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text(skinImportErrorMessage ?? String(localized: "Unable to import selected skin files."))
        }
        #endif
        #if canImport(CoreMIDI) && !os(tvOS) && !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingMIDIPicker) {
            if #available(iOS 16.0, *) {
                MIDIDevicePauseSheet()
            }
        }
        #endif
        // Core action option picker — shown when a CoreAction exposes multiple options.
        .confirmationDialog(
            pendingCoreAction?.title ?? "",
            isPresented: Binding(
                get: { pendingCoreAction != nil },
                set: { if !$0 { pendingCoreAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingCoreAction,
               let options = action.options {
                ForEach(options, id: \.title) { opt in
                    Button(opt.title) {
                        pendingCoreAction = nil
                        let selectedAction = CoreAction(
                            title: action.title,
                            requiresReset: action.requiresReset,
                            options: options.map { CoreActionOption(title: $0.title, selected: $0 == opt) },
                            style: action.style
                        )
                        let emulatorVC = self.emulatorVC
                        emulatorVC.dismissNav(resumeEmulation: true) {
                            emulatorVC.handleCoreAction(selectedAction)
                        }
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    pendingCoreAction = nil
                }
            }
        }
        .confirmationDialog(
            String(localized: "Restart Required"),
            isPresented: $showingDeferredRestartPrompt,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Save State and Restart")) {
                performDeferredCoreRestart(createSaveState: true)
            }
            Button(String(localized: "Restart Without Saving"), role: .destructive) {
                performDeferredCoreRestart(createSaveState: false)
            }
            Button(String(localized: "Not Now"), role: .cancel) { }
        } message: {
            Text(String(localized: "Some core settings require a restart. Apply them now?"))
        }
        // AirPlay trigger — invisible bridge that fires the system route-picker sheet.
        #if os(iOS) || targetEnvironment(macCatalyst)
        .overlay(
            AirPlayPickerTrigger(show: $triggerAirPlayPicker)
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false),
            alignment: .center
        )
        #endif
        .onChange(of: searchText) { _ in
            refreshSearchResults()
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
        .onAppear {
            orientation = UIDevice.current.orientation
            routeStack = initialRoute == .root ? [.root] : [.root, initialRoute]
            refreshControllerProfileState()
            initializeHardwareSwitchStatesIfNeeded()
            rebuildSections()
            if focusedTileID == nil, let first = firstEnabledTileID() {
                focusedTileID = first
            }
        }
        .onChange(of: focusedTileID) { newID in
            withAnimation(.easeInOut(duration: 0.2)) {
                infoText = viewModel.description(forTileID: newID)
            }
        }
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected else { return }
            let cols = currentColumnCount()
            switch event {
            case .horizontalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(deltaCol: value < 0 ? -1 : 1, cols: cols)
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                // Gamepad vertical: positive value = "up" semantically; we
                // walk rows so positive value should move to the previous row.
                moveFocus(deltaRow: value > 0 ? -1 : 1, cols: cols)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                activateFocusedTile()
            case .buttonB(let isPressed):
                guard isPressed else { return }
                handleBackCommand()
            case .menuToggle(let isPressed):
                guard isPressed else { return }
                handleBackCommand()
            case .start(let isPressed):
                guard isPressed else { return }
                handleBackCommand()
            default:
                break
            }
        }
        #elseif os(tvOS)
        .onAppear {
            routeStack = initialRoute == .root ? [.root] : [.root, initialRoute]
            refreshControllerProfileState()
            initializeHardwareSwitchStatesIfNeeded()
            rebuildSections()
            reattachTVOSFocusIfNeeded()
        }
        .onChange(of: focusedTileID) { newID in
            withAnimation(.easeInOut(duration: 0.2)) {
                infoText = viewModel.description(forTileID: newID)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            reattachTVOSFocusIfNeeded()
        }
        .onExitCommand { handleBackCommand() }
        .onPlayPauseCommand { handleBackCommand() }
        #endif
    }

    // MARK: - Helpers

    private func refreshControllerProfileState() {
        let controllers = PVControllerManager.shared.controllers
        let db = RomDatabase.sharedInstance
        hasControllerProfiles = controllers.contains { c in
            guard let name = c.vendorName else { return false }
            return !db.controllerProfiles(forVendor: name).isEmpty
        }
    }

    /// Seeds local switch states from system defaults once per menu presentation.
    private func initializeHardwareSwitchStatesIfNeeded() {
        guard hardwareSwitchStates.isEmpty else { return }
        let switches = activeSystemIdentifier.hardwareSwitches ?? []
        hardwareSwitchStates = switches.reduce(into: [:]) { partialResult, descriptor in
            partialResult[descriptor.id] = descriptor.defaultState
        }
    }

    private func hardwareSwitchDescriptor(forTileID id: String) -> HardwareSwitchDescriptor? {
        guard id.hasPrefix(PauseTileMenuViewModel.hardwareSwitchTilePrefix) else { return nil }
        let descriptorID = String(id.dropFirst(PauseTileMenuViewModel.hardwareSwitchTilePrefix.count))
        return activeSystemIdentifier.hardwareSwitches?.first(where: { $0.id == descriptorID })
    }

    private func hardwareMomentaryDescriptor(forTileID id: String) -> HardwareMomentaryDescriptor? {
        guard id.hasPrefix(PauseTileMenuViewModel.hardwareMomentaryTilePrefix) else { return nil }
        let descriptorID = String(id.dropFirst(PauseTileMenuViewModel.hardwareMomentaryTilePrefix.count))
        return activeSystemIdentifier.hardwareMomentaryButtons?.first(where: { $0.id == descriptorID })
    }

    /// Sends a short press/release edge through the active input route.
    private func dispatchHardwareButton(_ buttonId: String) {
        if let inputHandler = emulatorVC.sharedInputHandler {
            inputHandler.buttonPressed(buttonId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                inputHandler.buttonReleased(buttonId)
            }
            return
        }
        emulatorVC.controllerViewController?.didReceiveHardwareSwitchInput(buttonId: buttonId, player: 0)
    }

    /// Sends switch input through the controller bridge first, then falls back to skin input.
    private func dispatchHardwareSwitchButton(_ buttonId: String) {
        if emulatorVC.controllerViewController != nil {
            emulatorVC.controllerViewController?.didReceiveHardwareSwitchInput(buttonId: buttonId, player: 0)
            return
        }
        dispatchHardwareButton(buttonId)
    }

    /// Briefly fires a press → release on the main queue, mimicking a momentary
    /// physical button tap. The 50 ms delay matches `dispatchHardwareButton`.
    private func fireMomentaryRelease(after: TimeInterval = 0.05, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: block)
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Dispatches a system-specific button (Start/Select/Coin/etc.) by casting
    /// the running core to the appropriate `PV<System>SystemResponderClient`
    /// and calling `didPush(...)`/`didRelease(...)` for the encoded player.
    ///
    /// Tile IDs are `systemButton_pN_<btn>` and the button strings come from
    /// `SystemMenuButton.id`.
    private func dispatchSystemButton(tileID: String) {
        guard let parsed = SystemButtonTileProvider.parse(tileID: tileID) else { return }
        let player = parsed.player
        let btn = parsed.buttonId
        let core = emulatorVC.core
        let sys = activeSystemIdentifier

        switch sys {
        case .NES, .FDS:
            guard let r = core as? PVNESSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .SNES:
            guard let r = core as? PVSNESSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .GB, .GBC, .MegaDuck:
            guard let r = core as? PVGBSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .GBA:
            guard let r = core as? PVGBASystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .Genesis, .SegaCD, .GameGear:
            guard let r = core as? PVGenesisSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "mode":
                r.didPush(.mode, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.mode, forPlayer: player) }
            default: break
            }
        case .Sega32X:
            guard let r = core as? PVSega32XSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "mode":
                r.didPush(.mode, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.mode, forPlayer: player) }
            default: break
            }
        case .SG1000:
            guard let r = core as? PVSG1000SystemResponderClient else { return }
            if btn == "start" {
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            }
        case .PCE, .PCECD:
            guard let r = core as? PVPCESystemResponderClient else { return }
            switch btn {
            case "run":
                r.didPush(.run, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.run, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .PCFX, .SGFX:
            guard let r = core as? PVPCFXSystemResponderClient else { return }
            switch btn {
            case "run":
                r.didPush(.run, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.run, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .NGP, .NGPC:
            guard let r = core as? PVNeoGeoPocketSystemResponderClient else { return }
            if btn == "option" {
                r.didPush(.option, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.option, forPlayer: player) }
            }
        case .WonderSwan, .WonderSwanColor:
            guard let r = core as? PVWonderSwanSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "sound":
                r.didPush(.sound, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.sound, forPlayer: player) }
            default: break
            }
        case .N64:
            guard let r = core as? PVN64SystemResponderClient else { return }
            if btn == "start" {
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            }
        case .PSX:
            guard let r = core as? PVPSXSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .PS2, .PS3:
            guard let r = core as? PVPS2SystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .PSP:
            guard let r = core as? PVPSPSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .Saturn:
            guard let r = core as? PVSaturnSystemResponderClient else { return }
            if btn == "start" {
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            }
        case .Dreamcast:
            guard let r = core as? PVDreamcastSystemResponderClient else { return }
            if btn == "start" {
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            }
        case .GameCube:
            guard let r = core as? PVGameCubeSystemResponderClient else { return }
            if btn == "start" {
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            }
        case .DS:
            guard let r = core as? PVDSSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .VirtualBoy:
            guard let r = core as? PVVirtualBoySystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case .Lynx:
            guard let r = core as? PVLynxSystemResponderClient else { return }
            switch btn {
            case "pause":
                r.didPush(LynxButton: .pause, forPlayer: player)
                fireMomentaryRelease {
                    r.didRelease(LynxButton: .pause, forPlayer: player)
                }
            case "option1":
                r.didPush(LynxButton: .option1, forPlayer: player)
                fireMomentaryRelease {
                    r.didRelease(LynxButton: .option1, forPlayer: player)
                }
            case "option2":
                r.didPush(LynxButton: .option2, forPlayer: player)
                fireMomentaryRelease {
                    r.didRelease(LynxButton: .option2, forPlayer: player)
                }
            default: break
            }
        case .AtariJaguar, .AtariJaguarCD:
            guard let r = core as? PVJaguarSystemResponderClient else { return }
            switch btn {
            case "pause":
                r.didPush(jaguarButton: .pause, forPlayer: player)
                fireMomentaryRelease {
                    r.didRelease(jaguarButton: .pause, forPlayer: player)
                }
            case "option":
                r.didPush(jaguarButton: .option, forPlayer: player)
                fireMomentaryRelease {
                    r.didRelease(jaguarButton: .option, forPlayer: player)
                }
            default: break
            }
        case .MAME, .CPS1, .CPS2, .CPS3:
            guard let r = core as? PVMAMESystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            case "coin":
                r.didPush(.coin, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.coin, forPlayer: player) }
            default: break
            }
        case .NeoGeo, .NeoGeoCD:
            guard let r = core as? PVNeoGeoSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.start, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.start, forPlayer: player) }
            case "select":
                r.didPush(.select, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.select, forPlayer: player) }
            default: break
            }
        case ._3DO:
            guard let r = core as? PV3DOSystemResponderClient else { return }
            switch btn {
            case "stop":
                r.didPush(.X, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.X, forPlayer: player) }
            case "p":
                r.didPush(.P, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.P, forPlayer: player) }
            default: break
            }
        case .Supervision:
            guard let r = core as? PVSupervisionSystemResponderClient else { return }
            switch btn {
            case "start":
                r.didPush(.enter, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.enter, forPlayer: player) }
            case "select":
                r.didPush(.clear, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.clear, forPlayer: player) }
            default: break
            }
        case .PokemonMini:
            guard let r = core as? PVPokeMiniSystemResponderClient else { return }
            switch btn {
            case "power":
                r.didPush(.power, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.power, forPlayer: player) }
            case "shake":
                r.didPush(.shake, forPlayer: player)
                fireMomentaryRelease { r.didRelease(.shake, forPlayer: player) }
            default: break
            }
        default:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    /// Locates a rewind-related bool option in the active core option tree.
    private func findRewindOption(in options: [CoreOption]) -> CoreOption? {
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

    /// Updates ranked global search hits from the current query text.
    private func refreshSearchResults() {
        searchResults = viewModel.search(query: searchText, currentRoute: currentRoute)
    }

    /// Navigates to a result route (if needed), then executes the tile action.
    private func handleSearchResult(_ result: PauseMenuSearchResult) {
        searchText = ""
        if result.route != currentRoute {
            routeStack = result.route == .root ? [.root] : [.root, result.route]
            rebuildSections()
        }
        handle(result.tile)
    }

    private func tvOSAdjusted(_ standard: CGFloat, tvOS tvOSValue: CGFloat) -> CGFloat {
        #if os(tvOS)
        return tvOSValue
        #else
        return standard
        #endif
    }

    private func availableMouseInputSources() -> [MouseInputSource] {
        MouseInputSource.allCases.filter { source in
            #if os(tvOS)
            return source != .touchscreen
            #else
            return true
            #endif
        }
    }

    private func cycleMouseSensitivity() {
        let presets: [Double] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0]
        let nearestIndex = presets.enumerated().min {
            abs($0.element - mouseSensitivity) < abs($1.element - mouseSensitivity)
        }?.offset ?? 0
        let next = presets[(nearestIndex + 1) % presets.count]
        mouseSensitivity = next
        rebuildSections()
    }

    private var legacyPortDeviceInfo: [[PortDeviceDescriptor]] {
        (emulatorVC.core as? PauseMenuLibretroPortPickerSource)?.pauseMenuPortDeviceDescriptors ?? []
    }

    private func setLegacyPortDevice(_ deviceID: UInt, forPort portIndex: Int) {
        (emulatorVC.core as? PauseMenuLibretroPortPickerSource)?.setPauseMenuPortDevice(deviceID, forPort: portIndex)
        rebuildSections()
    }

    // MARK: - Info shelf

    /// Bottom bar that slides in to show the focused tile's description text.
    @ViewBuilder
    private var infoShelfView: some View {
        if let text = infoText {
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.15))
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: tvOSAdjusted(10, tvOS: 14)))
                        .foregroundColor(.white.opacity(0.5))
                    Text(text)
                        .font(.system(size: tvOSAdjusted(10, tvOS: 14), weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, tvOSAdjusted(12, tvOS: 20))
                .padding(.vertical, tvOSAdjusted(8, tvOS: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
// swiftlint:enable type_body_length

// MARK: - TileButtonStyle

private struct TileButtonStyle: ButtonStyle {
    var isFocused: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isFocused)
            .animation(.easeInOut(duration: 0.09), value: configuration.isPressed)
    }
}

// MARK: - Optional Context Menu Modifier

/// Applies `.contextMenu` only when long-press options are present,
/// avoiding `AnyView` type erasure that breaks SwiftUI's structural diffing.
private struct OptionalContextMenuModifier: ViewModifier {
    let options: [PauseMenuTileLongPressOption]?
    let handler: (PauseMenuTileLongPressOption) -> Void

    func body(content: Content) -> some View {
        if let options, !options.isEmpty {
            content.contextMenu {
                ForEach(options) { opt in
                    Button {
                        handler(opt)
                    } label: {
                        if opt.isSelected {
                            Label(opt.title, systemImage: "checkmark")
                        } else {
                            Text(opt.title)
                        }
                    }
                }
            }
        } else {
            content
        }
    }
}

private extension View {
    func optionalContextMenu(
        _ options: [PauseMenuTileLongPressOption]?,
        handler: @escaping (PauseMenuTileLongPressOption) -> Void
    ) -> some View {
        modifier(OptionalContextMenuModifier(options: options, handler: handler))
    }
}
