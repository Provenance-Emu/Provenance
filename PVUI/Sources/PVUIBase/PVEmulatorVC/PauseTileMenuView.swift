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
//  - Retrowave neon aesthetic
//  - iOS and tvOS compatible; controller/keyboard focus via FocusState
//

import SwiftUI
import PVCoreBridge
import PVFeatureFlags
import PVLogging
import PVLibrary
import PVPrimitives
import PVSettings
import PVShaders
import PVThemes
import SkinKitManager
import SkinKitUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - Panel metrics

/// Sizing constants for the floating pause panel.
///
/// The `desktop*` values apply only when the iOS binary runs on Apple Silicon
/// ("Designed for iPad", `ProcessInfo.processInfo.isiOSAppOnMac`). Mac Catalyst is
/// not supported and must never be used to detect this.
enum PauseTilePanelMetrics {
    /// Total horizontal breathing room kept between the panel and the window edge.
    static let horizontalInset: CGFloat = 32

    /// Total vertical breathing room kept between the panel and the safe area.
    static let verticalInset: CGFloat = 24

    /// The tallest a centred panel gets, so the game stays visible around it.
    static let regularMaxHeight: CGFloat = 680

    /// Height of the pinned title row on iOS.
    static let headerHeight: CGFloat = 34
    static let tvHeaderHeight: CGFloat = 56
    /// Below this panel width Quit and Save & Quit show their glyphs alone.
    static let compactHeaderWidth: CGFloat = 430
    /// How much of the screen's height the phone sheet may take; the game shows above it.
    static let sheetHeightFraction: CGFloat = 0.74
    /// Gap kept around the panel on a phone held sideways.
    static let railInset: CGFloat = 8
    /// Gap between the panel and the description that floats beside it.
    static let infoPillGap: CGFloat = 8
    /// The narrowest the panel gets when its sections need few columns: room for the
    /// title, search and the three header capsules.
    static let minimumWidth: CGFloat = 380
    static let tvMinimumWidth: CGFloat = 680

    /// Fraction of the window width the panel occupies on macOS.
    ///
    /// 0.55 keeps the paused game visible on either side of the panel (the overlay
    /// is deliberately a floating panel, not a full-screen sheet) while still
    /// filling enough of a desktop window to not read as a phone-sized column.
    static let desktopWidthFraction: CGFloat = 0.55

    /// Floor for the macOS panel width.
    ///
    /// 560pt matches the existing iPad landscape maximum, so the desktop panel is
    /// never narrower than what a tablet already shows, and it still yields the
    /// familiar 5-column grid in a small window.
    static let desktopMinWidth: CGFloat = 560

    /// Ceiling for the macOS panel width.
    ///
    /// 1100pt is where the 8-column grid tops out at ~129pt cells. Past that the
    /// grid stops gaining columns and the panel would just stretch, which looks
    /// absurd on a 5K/6K display, so the panel stays centered instead.
    static let desktopMaxWidth: CGFloat = 1100
}

/// Type sizes for the pause grid.
///
/// Cells carry option names and their current values, so these are sized to be
/// read at arm's length on a phone and across a room on tvOS rather than to
/// keep the grid as dense as possible.
enum PauseTileMetrics {
    #if os(tvOS)
    static let iconSize: CGFloat = 30
    static let tileHeight: CGFloat = 112
    static let labelSize: CGFloat = 16
    static let badgeSize: CGFloat = 13
    static let sectionTitleSize: CGFloat = 16
    #else
    static let iconSize: CGFloat = 22
    /// Glyph size where the horizontal size class is regular (iPad, Mac).
    static let regularIconSize: CGFloat = 26
    static let tileHeight: CGFloat = 72
    static let regularTileHeight: CGFloat = 78
    /// Floor for a tile at accessibility type sizes, where labels take three lines.
    static let accessibilityTileHeight: CGFloat = 112
    static let labelSize: CGFloat = 11.5
    static let badgeSize: CGFloat = 9.5
    static let sectionTitleSize: CGFloat = 11
    #endif
    static let iconLabelGap: CGFloat = 2
    /// Vertical room around the glyph, so symbols of different heights share a baseline.
    static let iconSlotPadding: CGFloat = 4
    /// Long option names shrink this far before truncating.
    static let labelMinimumScale: CGFloat = 0.8
    /// Keeps a full-width value badge clear of the cell's leading edge.
    static let badgeLeadingInset: CGFloat = 8
}

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
    /// Set by "Remap Controller"; presents the remapping screen for that controller.
    @State private var controllerRemapTarget: ControllerRemapTarget?
    @State private var showingTransferPakConfig = false
    /// Frozen snapshot of `emulatorVC.game` captured on the main thread before the sheet opens.
    /// The sheet closure reads this instead of the live Realm object to avoid thread-violation crashes.
    @State private var frozenTransferPakGame: PVGame?
    @State private var showingN64PakConfig = false
    @State private var showingPalettePicker = false
    @State private var showingNetworkPlay = false
    @State private var startNetplayHosting = false
    /// Close the pause menu once the Network Play sheet has gone (see `netplayReturnToGame`).
    @State private var resumeAfterNetworkPlay = false
    /// Triggers the AirPlay route-picker sheet via the hidden AVRoutePickerView bridge.
    #if os(iOS) || targetEnvironment(macCatalyst)
    @State private var triggerAirPlayPicker = false
    #endif
    @State private var showingShaderSettings = false
    @State private var showingShaderBrowser = false
    @State private var showingBezels = false
    @State private var showingPortDevices = false
    #if os(iOS)
    @State private var showingExternalDisplay = false
    #endif
    #if !os(tvOS)
    @State private var controllerLayoutContext: ControllerLayoutSheetContext?
    #endif
    @State private var showingMIDIPicker = false
    @State private var showingSystemSkinSelection = false
    @State private var showingSkinCatalog = false
    @State private var showingButtonEffectPicker = false
    @State private var showingButtonSoundPicker = false
    @State private var showingPlusPaywall = false
    @State private var showingLogViewer = false
    @State private var showingAppSettings = false
    /// Core action awaiting option picker confirmation.
    @State private var pendingCoreAction: CoreAction?
    /// Cached result of the Realm query — refreshed on appear, not on every render.
    @State private var hasControllerProfiles = false
    /// Query string for global tile search.
    @State private var searchText: String = ""
    @State private var showsSearch = false
    /// Whether rows remain below the scroll viewport.
    @State private var hasMoreBelow = false
    /// The page of the first level on show. L1 and R1, or a tap on the page bar, change it.
    @State private var rootTab: PauseMenuTab = .game
    /// Ranked search results across the full pause-menu tree.
    @State private var searchResults: [PauseMenuSearchResult] = []
    /// Description text shown in the bottom info shelf when a tile is focused/long-pressed.
    @State private var infoText: String?
    /// Tracks whether changed core options require a deferred reset prompt.
    @State private var pendingCoreReset = false
    /// Controls display of restart prompt when user exits the pause menu.
    @State private var showingDeferredRestartPrompt = false
    /// Asks before "Reset Options" puts the core's options back to their defaults.
    @State private var showingResetCoreOptionsConfirm = false

    // MARK: Focus

    /// The tile the controller is on. tvOS keeps it in the focus engine. iOS has no focus
    /// engine for buttons without a hardware keyboard (a `@FocusState` there never takes
    /// a value), so it is plain state moved by `controllerInput`.
    #if os(tvOS)
    @FocusState private var focusedTileID: String?
    #else
    @State private var focusedTileID: String?
    #endif
    @State private var routeStack: [PauseTileMenuRoute] = []
    #if os(tvOS)
    /// System uptime when the menu took focus; see `handleRemoteBackCommand`.
    @State private var appearedUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    #endif

    // MARK: Layout and environment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The cell label size, scaled as `PauseTileFace` scales it, for sizing the pages.
    @ScaledMetric(relativeTo: .caption) private var cellLabelSize = PauseTileMetrics.labelSize
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.scenePhase) private var scenePhase

    // Metal filter state — read/write directly to react to changes.

    // Haptic feedback toggle
    @Default(.rumbleEnabled) private var rumbleEnabled
    @Default(.showFPSCount) private var showFPSCount
    @Default(.buttonPressEffect) private var buttonPressEffect
    @Default(.buttonSound) private var buttonSound
    @Default(.mouseInputSource) private var mouseInputSource
    @Default(.mouseSensitivity) private var mouseSensitivity
    /// Whether core option writes should be scoped to the current game hash (if available).
    @AppStorage(CoreOptionsScope.perGameDefaultsKey) private var coreOptionsPerGame = true
    /// Easy kill-switch for the deferred restart workflow.
    @AppStorage("PauseTileMenu.deferredRestartPromptEnabled") private var deferredRestartPromptEnabled = true

    // Camera position for recording overlay — iOS only
    #if os(iOS)
    @Default(.recordingCameraPosition) private var recordingCameraPosition
    #endif

    /// Samples the connected pads while the menu is up; see `handleControllerCommand`.
    @State private var controllerInput = PauseMenuControllerInput()
    #if os(iOS)
    @ObservedObject private var gamepadManager = GamepadManager.shared
    /// The panel's shape as last laid out, so the cursor walks the controls in drawn order.
    @State private var currentMode: PauseMenuLayoutMode = .panel
    /// Columns the grid is drawn with (set from the layout in `body`), so controller
    /// navigation walks the same rows the panel shows.
    @State private var currentColumns = 0
    #endif

    #if os(tvOS)
    private static let isTV = true
    #else
    private static let isTV = false
    #endif

    /// Slack before the grid counts as scrolled to its end.
    private static let scrollEndTolerance: CGFloat = 4

    /// Scroll anchor for the panel's title row.
    private static let panelTopID = "pauseMenu.panelTop"

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
        rebuildSections(hardwareSwitchPositions: emulatorVC.coreInputHandler.hardwareSwitchPositionIndexes)
    }

    private func rebuildSections(hardwareSwitchPositions: [String: Int]) {
        viewModel.rebuild(
            emulatorVC: emulatorVC,
            showFPSCount: showFPSCount,
            rumbleEnabled: rumbleEnabled,
            featureFlags: featureFlags,
            indicatorRegistry: indicatorRegistry,
            hasControllerProfiles: hasControllerProfiles,
            hardwareSwitchStates: hardwareSwitchPositions,
            coreOptionsMD5: currentCoreOptionsMD5Scope,
            coreOptionsPerGame: coreOptionsPerGame,
            route: currentRoute
        )
        refreshSearchResults()
    }

    /// What the grid shows: one page of the first level, or a submenu's sections.
    private var visibleSections: [PauseMenuTileSection] {
        guard currentRoute == .root else { return viewModel.sections }
        return viewModel.sections(for: rootTab).filter { !$0.tiles.isEmpty }
    }

    /// Returns the first focusable tile identifier in display order.
    private func firstEnabledTileID() -> String? {
        for section in visibleSections {
            if let tile = section.tiles.first(where: { $0.isEnabled }) {
                return tile.id
            }
        }
        return nil
    }

    /// Returns the enabled tile object for an ID, if any.
    private func tile(forID id: String) -> PauseMenuTile? {
        for section in visibleSections {
            if let tile = section.tiles.first(where: { $0.id == id && $0.isEnabled }) {
                return tile
            }
        }
        return nil
    }

    #if os(iOS)
    /// Columns the grid is drawn with. Before the first layout pass has reported them,
    /// the count for a panel at its widest: the grid then has at most that many.
    private func currentColumnCount() -> Int {
        if currentColumns > 0 { return currentColumns }
        let width = ProcessInfo.processInfo.isiOSAppOnMac ? PauseTilePanelMetrics.desktopMinWidth : panelMaxWidth
        return columnCount(for: width)
    }

    /// Everything the controller cursor can reach, top to bottom as drawn: the exit
    /// buttons and the save row around the grid. Disabled controls are left out.
    private var cursorGrid: PauseMenuCursorGrid {
        let columns = currentColumnCount()
        let cells = visibleSections.flatMap { section in
            PauseMenuCursorGrid.chunk(section.tiles.map(\.id), columns: columns).map { row in
                row.filter { id in section.tiles.first { $0.id == id }?.isEnabled == true }
            }
        }
        let saves = saveControls.filter(\.isEnabled).map(\.id)
        /// The sheet has its exit buttons under the grid; the other shapes have them in the title row.
        return currentMode == .sheet
            ? PauseMenuCursorGrid(above: [saves], cells: cells, below: [exitControlIDs], columns: columns)
            : PauseMenuCursorGrid(above: [exitControlIDs, saves], cells: cells, columns: columns)
    }
    #endif

    /// The exit buttons, in their fixed order.
    private var exitControlIDs: [String] {
        [PauseMenuChromeID.quit]
            + (viewModel.offersSaveAndQuit ? [PauseMenuChromeID.saveQuit] : [])
            + [PauseMenuChromeID.resume]
    }

    /// One control of the save row: its chrome identifier and the root control it stands for.
    private struct SaveControl {
        let id: String
        let tileID: String
        let isEnabled: Bool
    }

    /// The save row, shown on the first level only.
    private var saveControls: [SaveControl] {
        guard currentRoute == .root else { return [] }
        return Self.chromeTileIDs.filter { Self.saveChromeIDs.contains($0.chrome) }
            .map { SaveControl(id: $0.chrome, tileID: $0.tile, isEnabled: viewModel.rootTile(withID: $0.tile)?.isEnabled == true) }
    }

    private static let saveChromeIDs = [PauseMenuChromeID.save, PauseMenuChromeID.load, PauseMenuChromeID.allSaves]

    /// Each chrome control and the root control whose action and description it shares.
    private static let chromeTileIDs: [(chrome: String, tile: String)] = [
        (PauseMenuChromeID.save, "saveState"), (PauseMenuChromeID.load, "loadState"),
        (PauseMenuChromeID.allSaves, "browseSaves"), (PauseMenuChromeID.quit, "quit"),
        (PauseMenuChromeID.saveQuit, "saveQuit"), (PauseMenuChromeID.resume, "resume")
    ]

    /// Runs a chrome control. Returns false when `id` is not one.
    @discardableResult
    private func performChrome(_ id: String) -> Bool {
        switch id {
        case PauseMenuChromeID.quit: quitWithoutSaving()
        case PauseMenuChromeID.saveQuit: saveAndQuit()
        case PauseMenuChromeID.resume: requestPauseMenuClose()
        case PauseMenuChromeID.save, PauseMenuChromeID.load, PauseMenuChromeID.allSaves:
            let tileID = Self.chromeTileIDs.first { $0.chrome == id }?.tile
            if let tile = tileID.flatMap({ viewModel.rootTile(withID: $0) }), tile.isEnabled {
                handle(tile)
            }
        default: return false
        }
        return true
    }

    /// The description for whatever the cursor is on, a chrome control included.
    private func description(forCursor id: String?) -> String? {
        let tileID = Self.chromeTileIDs.first { $0.chrome == id }?.tile ?? id
        return viewModel.description(forTileID: tileID)
    }

    /// Shows the page `offset` steps away and puts the cursor on its first control.
    private func switchTab(by offset: Int) {
        guard currentRoute == .root else { return }
        selectTab(rootTab.next(by: offset, in: viewModel.visibleTabs))
    }

    private func selectTab(_ tab: PauseMenuTab) {
        guard tab != rootTab else { return }
        rootTab = tab
        reattachTVOSFocusIfNeeded()
    }

    /// Activates the currently focused tile via the standard tile handler.
    private func activateFocusedTile() {
        guard let id = focusedTileID, !performChrome(id), let tile = tile(forID: id) else { return }
        handle(tile)
    }

    /// Puts the cursor back on a valid tile when the one it was on is gone: a submenu
    /// replaced the grid, or tvOS dropped focus across a lifecycle transition.
    private func reattachTVOSFocusIfNeeded() {
        let focusedID = focusedTileID
        #if !os(tvOS)
        /// No cursor means touch is driving the menu; leave it without one.
        guard focusedID != nil else { return }
        #endif
        let hasValidFocus = visibleSections.contains { section in
            section.tiles.contains(where: { $0.id == focusedID && $0.isEnabled })
        } || exitControlIDs.contains(focusedID ?? "") || saveControls.contains { $0.id == focusedID && $0.isEnabled }
        guard !hasValidFocus else { return }
        guard let fallbackID = firstEnabledTileID() else { return }
        DispatchQueue.main.async {
            focusedTileID = fallbackID
        }
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

    #if os(iOS)
    /// Whether something is presented over the menu (a sheet, a cover or an alert).
    /// Those screens take the controller themselves, so the grid behind them stays put.
    private var isCoveredByPresentation: Bool {
        emulatorVC.menuPresentationViewController?.presentedViewController != nil
            || emulatorVC.isPresentingPVAlert
            || showingBezels
            || gamepadManager.isModalAlertPresented
    }

    /// One step from the controller: the d-pad or left stick moves the cursor, A opens
    /// what is under it, B goes back a level then closes the menu, L1 and R1 change
    /// page, X and Y save and load.
    private func handleControllerCommand(_ command: PauseMenuNavigationCommand) {
        guard !isCoveredByPresentation else { return }
        let grid = cursorGrid
        switch command {
        case .left: focusedTileID = grid.move(from: focusedTileID, .left)
        case .right: focusedTileID = grid.move(from: focusedTileID, .right)
        case .up: focusedTileID = grid.move(from: focusedTileID, .up)
        case .down: focusedTileID = grid.move(from: focusedTileID, .down)
        case .activate: activateFocusedTile()
        case .back: handleBackCommand()
        case .previousTab: switchTab(by: -1)
        case .nextTab: switchTab(by: 1)
        case .quickSave: performChrome(PauseMenuChromeID.save)
        case .quickLoad: performChrome(PauseMenuChromeID.load)
        }
    }
    #endif

    #if os(tvOS)
    /// Back / Play-Pause from the focus engine.
    ///
    /// The menu is presented on a button's press-down for GameController-driven
    /// pause sources, and controller input is handed to UIKit at that moment —
    /// so the release of that same press can arrive here as an exit command and
    /// close the menu the instant it opens. Nobody backs out deliberately that
    /// fast, so commands inside the coalescing window are dropped.
    private func handleRemoteBackCommand() {
        let sinceAppear = ProcessInfo.processInfo.systemUptime - appearedUptime
        guard sinceAppear >= PauseToggleCoalescer.defaultWindow else {
            ILOG("Pause menu: back command \(String(format: "%.2f", sinceAppear))s after appear — treated as the opening press, ignored")
            return
        }
        handleBackCommand()
    }
    #endif

    /// Current header title for the active tile-menu route.
    private var routeTitle: String {
        switch currentRoute {
        case .root:
            return String(localized: "Game menu")
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

    /// Recording/broadcast/clip are Plus features on App Store builds.
    /// Non-AppStore builds (dev / TestFlight / sideloaded) are treated as premium.
    private var recordingRequiresPlus: Bool {
        #if canImport(FreemiumKit)
        return AppState.shared.isAppStore && !PlusEntitlement.isUnlocked
        #else
        return false
        #endif
    }

    /// Creates an automatic save state, then exits to the library.
    private func saveAndQuit() {
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
    }

    /// Exits to the library without saving.
    private func quitWithoutSaving() {
        dismissAction(false)
        Task { @MainActor in
            await emulatorVC.quit(optionallySave: false)
        }
    }

    private func handle(_ tile: PauseMenuTile) {
        guard tile.isEnabled else { return }
        if let destination = tile.destinationRoute {
            pushRoute(destination)
            return
        }
        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        // Disc swap long-press options — IDs are "disc_<number>".
        if tile.id.hasPrefix("disc_") {
            if let discNum = UInt(tile.id.dropFirst(5)),
               let discCore = emulatorVC.core as? DiscSwappable {
                discCore.swapDisc(number: discNum)
                rebuildSections()
            }
            return
        }

        // Scaling long-press options — IDs are "scaling_<ScalingMode.rawValue>".
        if tile.id.hasPrefix(PauseTileMenuViewModel.scalingTilePrefix) {
            let token = String(tile.id.dropFirst(PauseTileMenuViewModel.scalingTilePrefix.count))
            if let mode = ScalingMode(rawValue: token) {
                applyScalingMode(mode)
            }
            return
        }

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
        #if os(iOS) || os(tvOS)
        case PauseTileMenuViewModel.bezelsTileID:
            showingBezels = true
        #endif
        case "gameInfo":
            dismissForSubSheetThen { self.emulatorVC.showMoreInfo() }
        case "networkPlay":
            showingNetworkPlay = true
        case "controllerProfile":
            showingControllerProfiles = true
        case PauseTileMenuViewModel.remapControllerTileID:
            controllerRemapTarget = emulatorVC.remappableController.map { ControllerRemapTarget(controller: $0) }
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
            saveAndQuit()
        case "quit":
            quitWithoutSaving()

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
            showingShaderBrowser = true
        case "mouseInputSource":
            let sources = availableMouseInputSources()
            guard !sources.isEmpty else { return }
            let currentIndex = sources.firstIndex(of: mouseInputSource) ?? 0
            let next = sources[(currentIndex + 1) % sources.count]
            mouseInputSource = next
            rebuildSections()
        case "mouseSensitivity":
            cycleMouseSensitivity()
        case "discSwap":
            emulatorVC.showSwapDiscsMenu()
        case "scalingCycle":
            let modes = ScalingMode.allCases
            let current = Defaults[.scalingMode]
            let idx = modes.firstIndex(of: current) ?? 0
            applyScalingMode(modes[(idx + 1) % modes.count])
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
            _ = emulatorVC.features.handlePauseMenuTile(id: tile.id)
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
            rumbleEnabled.toggle()
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

        #if os(iOS)
        case PauseTileMenuViewModel.externalDisplayTileID:
            showingExternalDisplay = true
        #endif

        // MARK: Programmatic touch overlay
        #if !os(tvOS)
        case PauseTileMenuViewModel.controllerLayoutTileID:
            controllerLayoutContext = makeControllerLayoutContext()
        case PauseTileMenuViewModel.editOverlayLayoutTileID:
            emulatorVC.openLayoutEditor()
        #endif

        // MARK: MIDI device picker
        case "midiDevice":
            showingMIDIPicker = true
        case "midiToggle":
            Defaults[.retroArchMIDIEnabled].toggle()
            rebuildSections()

        // MARK: Light gun overlay toggle (iOS-only)
        case "lightGun":
            #if os(iOS) && !targetEnvironment(macCatalyst)
            emulatorVC.toggleLightGun()
            // Persist the user's choice via the registry's per-game override
            // so the next launch of this ROM auto-installs (or doesn't) to
            // match what they last set — no need to re-toggle every session.
            if let md5 = emulatorVC.core.romMD5 {
                LightGunGameRegistry.shared.setUserOverride(
                    emulatorVC.isLightGunVisible,
                    forMD5: md5
                )
            }
            rebuildSections()
            #endif

        // MARK: Virtual mouse overlay toggle (iOS-only)
        case "virtualMouse":
            #if os(iOS) && !targetEnvironment(macCatalyst)
            emulatorVC.toggleVirtualMouseManually()
            // Mirror the Light Gun pattern — persist via MouseGameRegistry
            // so the next launch matches what the user last picked.
            if let md5 = emulatorVC.core.romMD5 {
                MouseGameRegistry.shared.setUserOverride(
                    emulatorVC.isVirtualMouseVisible,
                    forMD5: md5
                )
            }
            rebuildSections()
            #endif

        // MARK: Skins submenu actions
        case "skins_choose", "skins_pick_for_system":
            showingSystemSkinSelection = true
        case PauseTileMenuViewModel.skinCatalogTileID:
            showingSkinCatalog = true
        case "skins_button_effect":
            showingButtonEffectPicker = true
        case "skins_button_sound":
            showingButtonSoundPicker = true

        // MARK: Recording / broadcast / clip
        // Recording, broadcasting, and clip export are Provenance Plus
        // features on App Store builds (matches the record button gate in
        // EmulatorQuickActionBar). Stop actions stay ungated so a
        // lapsed subscriber can always end an in-progress session.
        case "recording":
            #if os(iOS)
            if recordingRequiresPlus, !emulatorVC.isRecording {
                showingPlusPaywall = true
                return
            }
            if emulatorVC.isRecording {
                dismissForSubSheetThen { self.emulatorVC.stopScreenRecording() }
            } else {
                dismissThenResumeAndRun { self.emulatorVC.startScreenRecording() }
            }
            #endif
        case "broadcast":
            #if os(iOS) || os(tvOS)
            if recordingRequiresPlus, !emulatorVC.isBroadcasting {
                showingPlusPaywall = true
                return
            }
            if emulatorVC.isBroadcasting {
                dismissForSubSheetThen { self.emulatorVC.stopBroadcast() }
            } else {
                dismissForSubSheetThen { self.emulatorVC.startBroadcast() }
            }
            #endif
        case "saveClip":
            #if os(iOS) || os(tvOS)
            if recordingRequiresPlus {
                showingPlusPaywall = true
                return
            }
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
            guard let descriptor = hardwareSwitchDescriptor(forTileID: id),
                  let input = emulatorVC.coreInputHandler.nextConsoleButtonID(for: descriptor.id) else { return }
            dispatchHardwareSwitchButton(input)
        case let id where id.hasPrefix(PauseTileMenuViewModel.hardwareMomentaryTilePrefix):
            guard let descriptor = hardwareMomentaryDescriptor(forTileID: id) else { return }
            dispatchHardwareSwitchButton(descriptor.buttonId)

        case let id where id.hasPrefix(SystemButtonTileProvider.tileIDPrefix):
            dispatchSystemButton(tileID: id)

        // MARK: Core page scope
        case PauseTileMenuViewModel.coreOptionsScopeTileID:
            coreOptionsPerGame.toggle()
            rebuildSections()
        case PauseTileMenuViewModel.resetCoreOptionsTileID:
            showingResetCoreOptionsConfirm = true

        // MARK: Audio and quick preferences
        case PauseTileMenuViewModel.volumeTileID:
            emulatorVC.setGameVolume(PauseTileMenuViewModel.nextVolumePreset(after: Defaults[.volume]))
            rebuildSections()
        case PauseTileMenuViewModel.muteTileID:
            emulatorVC.setAudioMuted(!emulatorVC.isAudioMuted)
            rebuildSections()
        case PauseTileMenuViewModel.saveOnQuitTileID:
            Defaults[.autoSave].toggle()
            rebuildSections()
        case PauseTileMenuViewModel.buttonHapticsTileID:
            Defaults[.buttonVibration].toggle()
            rebuildSections()
        case PauseTileMenuViewModel.systemButtonsTileID:
            Defaults[.missingButtonsAlwaysOn].toggle()
            rebuildSections()
        case PauseTileMenuViewModel.launchSaveTileID:
            PauseLaunchSaveMode.current.next.apply()
            rebuildSections()
        case let id where PauseTileMenuViewModel.preferenceKey(forCellID: id) != nil:
            if let key = PauseTileMenuViewModel.preferenceKey(forCellID: id) { Defaults[key].toggle() }
            rebuildSections()

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
            // Quick picks apply to the scope already in effect for this game.
            let store = ShaderLibraryStore.shared
            let scope = store.effectiveScope(gameMD5: emulatorVC.shaderGameMD5, systemID: emulatorVC.shaderSystemID)
            if lpOption.id == PauseTileMenuViewModel.filterOffOptionID {
                store.setSelection(.off, for: scope)
            } else if lpOption.id.hasPrefix(PauseTileMenuViewModel.filterOptionPrefix) {
                let id = ShaderID(rawValue: String(lpOption.id.dropFirst(PauseTileMenuViewModel.filterOptionPrefix.count)))
                store.setSelection(.always(id), for: scope)
            }
            emulatorVC.shaderSelectionDidChange()
            rebuildSections()
            return
        }

        if tile.id == PauseTileMenuViewModel.launchSaveTileID {
            let raw = lpOption.id.dropFirst(PauseTileMenuViewModel.launchSaveOptionPrefix.count)
            PauseLaunchSaveMode(rawValue: String(raw))?.apply()
            rebuildSections()
            return
        }

        if tile.id == PauseTileMenuViewModel.volumeTileID {
            let prefix = PauseTileMenuViewModel.volumeOptionPrefix
            if lpOption.id.hasPrefix(prefix), let percent = Float(lpOption.id.dropFirst(prefix.count)) {
                emulatorVC.setGameVolume(percent / 100)
                rebuildSections()
            }
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

    private var pauseSkinOrientation: SkinOrientation {
        #if os(tvOS)
        return .landscape
        #else
        return .portrait
        #endif
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

    private func applyScalingMode(_ mode: ScalingMode) {
        Defaults[.scalingMode] = mode
        Defaults[.userExplicitlySetScalingMode] = true
        rebuildSections()
    }

    /// Applies a game-speed change. Fast-forward is handled by the core's `setGameSpeed:`.
    private func applyGameSpeed(_ speed: GameSpeed) {
        emulatorVC.setGameSpeedRespectingAchievements(speed)
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

    /// Plays a sample click when selecting a button sound style.
    private func playButtonSoundSample(_ sound: ButtonSound) {
        guard sound != .none else { return }
        ButtonSoundGenerator.shared.playSound(sound, pan: 0, volume: 1.0)
    }

    // MARK: - Layout helpers

    /// Uses the same measured width for layout and controller navigation.
    private func columnCount(for width: CGFloat) -> Int {
        #if os(tvOS)
        return 6
        #else
        return PauseTileLayout.columns(panelWidth: width, accessibility: dynamicTypeSize.isAccessibilitySize)
        #endif
    }

    private var panelMaxWidth: CGFloat {
        #if os(tvOS)
        return 860
        #else
        return 840
        #endif
    }

    /// Width of the floating pause panel for the currently available layout width.
    ///
    /// - On iPhone/iPad/tvOS the panel follows the available width minus its edge inset,
    ///   capped at `panelMaxWidth` so wide layouts can fit eight compact columns.
    /// - On macOS the panel scales with the *window* instead, clamped between
    ///   `desktopMinWidth` and `desktopMaxWidth`.
    ///
    /// Callers must pass the live `GeometryReader` width so the panel re-derives on
    /// every window resize rather than caching a value from first layout.
    private func panelWidth(forAvailableWidth availableWidth: CGFloat) -> CGFloat {
        let insetWidth = max(0, availableWidth - PauseTilePanelMetrics.horizontalInset)
        #if os(iOS)
        if ProcessInfo.processInfo.isiOSAppOnMac {
            let scaled = availableWidth * PauseTilePanelMetrics.desktopWidthFraction
            let clamped = min(max(scaled, PauseTilePanelMetrics.desktopMinWidth),
                              PauseTilePanelMetrics.desktopMaxWidth)
            // Never exceed the window — the user can shrink it below `desktopMinWidth`.
            return min(insetWidth, clamped)
        }
        #endif
        return min(insetWidth, panelMaxWidth)
    }

    /// The panel's width before it is fitted to its columns: the whole screen for the
    /// phone sheet, nearly all of it for a phone on its side, the floating width otherwise.
    private func fullPanelWidth(in size: CGSize, mode: PauseMenuLayoutMode) -> CGFloat {
        switch mode {
        case .sheet: return size.width
        case .rail: return max(0, size.width - PauseTilePanelMetrics.railInset * 2)
        case .panel: return panelWidth(forAvailableWidth: size.width)
        }
    }

    /// The sheet leaves the game showing above it, a phone on its side gives the panel
    /// all the height it has, and wider layouts cap it and keep the game visible around it.
    private func panelMaxHeight(in size: CGSize, mode: PauseMenuLayoutMode) -> CGFloat {
        switch mode {
        case .sheet: return size.height * PauseTilePanelMetrics.sheetHeightFraction
        case .rail: return max(0, size.height - PauseTilePanelMetrics.railInset * 2)
        case .panel:
            let available = max(0, size.height - PauseTilePanelMetrics.verticalInset)
            return min(PauseTilePanelMetrics.regularMaxHeight, available)
        }
    }

    // MARK: - Tile view

    @ViewBuilder
    private func tileView(for tile: PauseMenuTile) -> some View {
        let accentColor = color(for: tile.colorKey)
        let opacity: Double = tile.isEnabled ? 1.0 : 0.4
        let isFocused = focusedTileID == tile.id

        Button {
            handle(tile)
        } label: {
            PauseTileFace(label: tile.label, icon: tile.icon, badge: tile.badge,
                          accent: accentColor, isFocused: isFocused)

        }
        .buttonStyle(TileButtonStyle(isFocused: isFocused))
        .opacity(opacity)
        .disabled(!tile.isEnabled)
        .id(tile.id)
        #if os(tvOS)
        .focused($focusedTileID, equals: tile.id)
        #endif
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
        case .indigo: return Color(red: 0.35, green: 0.18, blue: 0.92)
        }
    }

    /// Translucent like the library dock: the paused game stays visible through the panel.
    /// The theme's menu colour tints the material; the sheet is square where it meets the screen edge.
    private func panelBackground(theme: PauseMenuTheme, mode: PauseMenuLayoutMode) -> some View {
        let radius = RetroPauseChrome.chromeCornerRadius
        let foot = mode == .sheet ? 0 : radius
        let shape = UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: foot,
                                           bottomTrailingRadius: foot, topTrailingRadius: radius)
        return shape.fill(.ultraThinMaterial)
            .overlay { shape.fill(theme.panelTint.opacity(PauseMenuTheme.panelTintOpacity)) }
            .overlay { shape.strokeBorder(theme.border) }
            .ignoresSafeArea(edges: mode == .sheet ? .bottom : [])
    }

    /// The game's name on the first level, the submenu's name below it.
    private var panelTitle: String {
        guard currentRoute == .root, let game = emulatorVC.game, !game.isInvalidated, !game.title.isEmpty else {
            return routeTitle
        }
        return game.title
    }

    /// The pinned title row: back, the title, search, and the exit buttons where the shape puts them here.
    private func titleRow(theme: PauseMenuTheme, showsExits: Bool, compactExits: Bool,
                          inlineInfo: String? = nil) -> some View {
        let rowHeight = tvOSAdjusted(PauseTilePanelMetrics.headerHeight, tvOS: PauseTilePanelMetrics.tvHeaderHeight)
        return HStack(spacing: 6) {
            if routeStack.count > 1 {
                Button { _ = popRoute() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: RetroPauseChrome.controlHeight, height: rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            Text(panelTitle)
                .font(.system(size: tvOSAdjusted(15, tvOS: 22), weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(PauseTileMetrics.labelMinimumScale)
            if let inlineInfo {
                Text(inlineInfo)
                    .font(.system(size: PauseMenuChromeMetrics.fontSize))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(PauseTileMetrics.labelMinimumScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }
            Button { showsSearch.toggle() } label: {
                Image(systemName: "magnifyingglass")
                    .frame(width: RetroPauseChrome.controlHeight, height: rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search settings")
            if showsExits {
                exitButtons(theme: theme, compact: compactExits, expands: false,
                            height: PauseMenuChromeMetrics.controlHeight)
            }
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, tvOSAdjusted(RetroPauseChrome.chromeInset, tvOS: 20))
        .padding(.top, 6)
        .padding(.bottom, 4)
        #if os(tvOS)
        .focusSection()
        #endif
    }

    /// Quit, Save & Quit, Resume: always in that order, Resume the primary one.
    @ViewBuilder
    private func exitButtons(theme: PauseMenuTheme, compact: Bool, expands: Bool, height: CGFloat) -> some View {
        PauseChromeButton(title: String(localized: "Quit"), symbol: compact ? "xmark.circle" : nil,
                          tint: theme.destructive, iconOnly: compact, expands: expands, height: height,
                          isCursor: focusedTileID == PauseMenuChromeID.quit, action: quitWithoutSaving)
        if viewModel.offersSaveAndQuit {
            PauseChromeButton(title: String(localized: "Save & Quit"),
                              symbol: compact ? "square.and.arrow.down.on.square" : nil,
                              tint: theme.accent, iconOnly: compact, expands: expands, height: height,
                              isCursor: focusedTileID == PauseMenuChromeID.saveQuit, action: saveAndQuit)
        }
        PauseChromeButton(title: String(localized: "Resume"), tint: theme.accent, prominent: true,
                          expands: expands, height: height,
                          isCursor: focusedTileID == PauseMenuChromeID.resume, action: requestPauseMenuClose)
    }

    /// The exit buttons as a full-width bar under the phone sheet, at the thumb.
    private func exitBar(theme: PauseMenuTheme) -> some View {
        HStack(spacing: 6) {
            exitButtons(theme: theme, compact: false, expands: true, height: PauseMenuChromeMetrics.sheetActionHeight)
        }
        .padding(.horizontal, RetroPauseChrome.chromeInset)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { theme.divider.frame(height: 1) }
    }

    /// Save, Load and All saves in one slim row, so the grid keeps the room.
    private func saveRow(theme: PauseMenuTheme) -> some View {
        HStack(spacing: 6) {
            ForEach(saveControls, id: \.id) { control in
                PauseChromeButton(title: Self.saveTitle(for: control.id), symbol: Self.saveSymbol(for: control.id),
                                  detail: saveDetail(for: control.id), tint: Self.saveTint(for: control.id),
                                  expands: true, isEnabled: control.isEnabled,
                                  isCursor: focusedTileID == control.id) { performChrome(control.id) }
            }
        }
        .padding(.horizontal, tvOSAdjusted(RetroPauseChrome.chromeInset, tvOS: 20))
        .padding(.bottom, 6)
        #if os(tvOS)
        .focusSection()
        #endif
    }

    private static func saveTitle(for id: String) -> String {
        switch id {
        case PauseMenuChromeID.save: return String(localized: "Save")
        case PauseMenuChromeID.load: return String(localized: "Load")
        default: return String(localized: "All Saves")
        }
    }

    private static func saveSymbol(for id: String) -> String {
        switch id {
        case PauseMenuChromeID.save: return "square.and.arrow.down"
        case PauseMenuChromeID.load: return "arrowshape.turn.up.left"
        default: return "square.grid.2x2"
        }
    }

    private static func saveTint(for id: String) -> Color {
        switch id {
        case PauseMenuChromeID.save: return .retroCyan
        case PauseMenuChromeID.load: return .retroBlue
        default: return .retroPurple
        }
    }

    /// The age of the newest save beside Load, and the number of saves beside All Saves.
    private func saveDetail(for id: String) -> String? {
        switch id {
        case PauseMenuChromeID.load:
            return viewModel.latestSaveDate.map { Self.saveAgeFormatter.localizedString(for: $0, relativeTo: Date()) }
        case PauseMenuChromeID.allSaves:
            return viewModel.saveStateCount > 0 ? String(viewModel.saveStateCount) : nil
        default:
            return nil
        }
    }

    private static let saveAgeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Whether a controller can switch pages, so the page bar shows L1 and R1.
    private var showsShoulderKeys: Bool {
        #if os(tvOS)
        return true
        #else
        return gamepadManager.isControllerConnected
        #endif
    }

    private func tabBar(_ style: PauseMenuTabBar.Style, theme: PauseMenuTheme) -> some View {
        PauseMenuTabBar(pages: viewModel.visibleTabs, selection: rootTab, style: style, theme: theme,
                        showsShoulderKeys: style == .labels && showsShoulderKeys, select: selectTab)
            .padding(.horizontal, style == .rail ? 0 : tvOSAdjusted(RetroPauseChrome.chromeInset, tvOS: 20))
            .padding(.vertical, 4)
    }

    #if os(iOS)
    /// What each button does, shown under a panel while a controller is connected.
    private static let legendEntries: [PauseMenuLegend.Entry] = [
        .init(keys: ["A"], action: String(localized: "Open")),
        .init(keys: ["B"], action: String(localized: "Back")),
        .init(keys: ["X"], action: String(localized: "Save")),
        .init(keys: ["Y"], action: String(localized: "Load")),
        .init(keys: ["L1", "R1"], action: String(localized: "Page"))
    ]
    #endif

    /// The panel's content for its shape. See `PauseMenuLayoutMode`.
    @ViewBuilder
    private func panelContent(mode: PauseMenuLayoutMode, theme: PauseMenuTheme, sections: [PauseMenuTileSection],
                              cols: Int, spacing: CGFloat, showsGrid: Bool, compactExits: Bool) -> some View {
        let isRoot = currentRoute == .root
        switch mode {
        case .panel:
            VStack(spacing: 0) {
                titleRow(theme: theme, showsExits: true, compactExits: compactExits)
                if isRoot {
                    saveRow(theme: theme)
                    tabBar(.labels, theme: theme)
                }
                gridScroll(sections: sections, cols: cols, spacing: spacing, showsGrid: showsGrid)
                #if os(iOS)
                if gamepadManager.isControllerConnected {
                    PauseMenuLegend(entries: Self.legendEntries, theme: theme)
                }
                #endif
            }
        case .sheet:
            VStack(spacing: 0) {
                titleRow(theme: theme, showsExits: false, compactExits: false)
                if isRoot { saveRow(theme: theme) }
                gridScroll(sections: sections, cols: cols, spacing: spacing, showsGrid: showsGrid)
                if isRoot {
                    tabBar(.stacked, theme: theme)
                        .overlay(alignment: .top) { theme.divider.frame(height: 1) }
                }
                exitBar(theme: theme)
            }
        case .rail:
            HStack(spacing: 0) {
                if isRoot {
                    tabBar(.rail, theme: theme)
                        .overlay(alignment: .trailing) { theme.divider.frame(width: 1) }
                }
                VStack(spacing: 0) {
                    titleRow(theme: theme, showsExits: true, compactExits: compactExits, inlineInfo: infoText)
                    if isRoot { saveRow(theme: theme) }
                    gridScroll(sections: sections, cols: cols, spacing: spacing, showsGrid: showsGrid)
                }
            }
        }
    }

    /// The description of the control under the cursor, floating outside the panel: above
    /// the phone sheet and below a centred panel. A phone on its side has no room outside,
    /// so there it is written into the title row's empty space (`titleRow`).
    @ViewBuilder
    private func infoPill(mode: PauseMenuLayoutMode, theme: PauseMenuTheme) -> some View {
        if let infoText, mode != .rail {
            let gap = PauseTilePanelMetrics.infoPillGap
            /// A frame of no height on the panel's edge, with the pill hanging off its far side.
            PauseMenuInfoPill(text: infoText, theme: theme)
                .padding(.horizontal, RetroPauseChrome.chromeInset)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 0, alignment: mode == .sheet ? .bottom : .top)
                .offset(y: mode == .sheet ? -gap : gap)
        }
    }

    // MARK: - Section view

    private func sectionView(section: PauseMenuTileSection, cols: Int, spacing: CGFloat) -> some View {
        return VStack(alignment: .leading, spacing: Self.sectionTitleGap) {
            if let title = section.title {
                Text(title)
                    .font(.system(size: PauseTileMetrics.sectionTitleSize, weight: .heavy))
                    .foregroundColor(Color.primary.opacity(0.6))
                    .tracking(tvOSAdjusted(1.5, tvOS: 2.5))
                    .lineLimit(1)
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
                                .frame(height: PauseTileMetrics.tileHeight)
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
                .foregroundColor(Color.primary.opacity(0.7))
            TextField(String(localized: "Search settings"), text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: tvOSAdjusted(11, tvOS: 15), weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                // Exclude the search field from controller / focus-engine
                // navigation. Without this, tvOS focus engine and iOS
                // keyboard-driven focus latch onto the TextField on first
                // d-pad press and never escape — user can't reach the tiles
                // below it. Tapping the search bar with touch still works on
                // iOS (touch hit-testing isn't gated by .focusable).
                .focusable(false)
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
            .foregroundColor(Color.primary.opacity(0.92))
            .padding(.horizontal, tvOSAdjusted(10, tvOS: 14))
            .padding(.vertical, tvOSAdjusted(6, tvOS: 10))
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                    .fill(Color.primary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                            .strokeBorder(accent.opacity(RetroPauseChrome.menuCellStrokeOpacityUnfocused))
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
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: tvOSAdjusted(9, tvOS: 12), weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.6))
                }
                Spacer(minLength: 6)
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill((isOn.wrappedValue ? Color.retroCyan : Color.primary.opacity(0.20)).opacity(0.22))
                        .overlay(
                            Capsule()
                                .strokeBorder(isOn.wrappedValue ? Color.retroCyan.opacity(0.95) : Color.primary.opacity(0.45))
                        )
                        .frame(width: tvOSAdjusted(50, tvOS: 70), height: tvOSAdjusted(24, tvOS: 30))
                    Circle()
                        .fill(isOn.wrappedValue ? Color.retroCyan : Color.primary.opacity(0.85))
                        .frame(width: tvOSAdjusted(18, tvOS: 24), height: tvOSAdjusted(18, tvOS: 24))
                        .padding(.horizontal, tvOSAdjusted(3, tvOS: 4))
                        .shadow(color: (isOn.wrappedValue ? Color.retroCyan : Color.primary).opacity(0.75), radius: 6, x: 0, y: 0)
                }
            }
            .padding(.horizontal, tvOSAdjusted(10, tvOS: 14))
            .padding(.vertical, tvOSAdjusted(8, tvOS: 11))
            .background(
                RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: tvOSAdjusted(8, tvOS: 12))
                            .strokeBorder(RetroPauseChrome.chromeBorder)
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
                .foregroundColor(Color.primary.opacity(0.45))
                .tracking(tvOSAdjusted(1.5, tvOS: 2.5))
                .padding(.horizontal, 2)

            if searchResults.isEmpty {
                Text(String(localized: "No matching settings found."))
                    .font(.system(size: tvOSAdjusted(10, tvOS: 14), weight: .medium, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.65))
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
                                    .foregroundColor(.primary)
                                Text(result.route.rawValue.uppercased())
                                    .font(.system(size: tvOSAdjusted(8, tvOS: 11), weight: .bold))
                                    .foregroundColor(Color.primary.opacity(0.55))
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
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .tvOSDisableFocusEffect()
                }
            }
        }
    }

    /// The scrolling part of the panel: search, the grid or the search results, and a submenu's own rows.
    private func gridScroll(sections: [PauseMenuTileSection], cols: Int, spacing: CGFloat, showsGrid: Bool) -> some View {
        ScrollViewReader { scrollProxy in
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: tvOSAdjusted(12, tvOS: 20)) {
                Color.clear.frame(height: 0).id(Self.panelTopID)
                if showsSearch || !searchText.isEmpty {
                    searchBarView
                }
                if currentRoute == .core {
                    coreScopeControlsView
                }

                if showsGrid {
                    // Grouped sections — one outer focus section for the whole
                    // tile grid so tvOS treats it as a single focus region.
                    // Per-section focusSections caused focus to snap to the top
                    // when navigating between sections with off-screen tiles
                    // (LazyVGrid defers rendering of rows below the fold).
                    VStack(alignment: .leading, spacing: tvOSAdjusted(12, tvOS: 20)) {
                        ForEach(sections) { section in
                            sectionView(section: section, cols: cols, spacing: spacing)
                            if section.id != sections.last?.id {
                                Color.primary.opacity(PauseMenuTheme.dividerOpacity).frame(height: 1)
                            }
                        }
                    }
                    // Every page is as tall as the tallest, so changing page never resizes the panel.
                    .frame(minHeight: currentRoute == .root ? rootGridMinHeight(cols: cols, spacing: spacing) : 0,
                           alignment: .topLeading)
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
            .padding([.horizontal, .top], tvOSAdjusted(RetroPauseChrome.chromeInset, tvOS: 20))
            // Lets the last row scroll clear of the bottom fade.
            .padding(.bottom, RetroPauseChrome.scrollEdgeFade)
            .background {
                GeometryReader { content in
                    // A Bool, so the preference changes when the end is reached, not on every scrolled frame.
                    let visibleBottom = content.bounds(of: .scrollView)?.maxY ?? content.size.height
                    Color.clear.preference(key: PauseScrollHasMoreBelowKey.self,
                                           value: content.size.height - visibleBottom > Self.scrollEndTolerance)
                }
            }
        }
        .onPreferenceChange(PauseScrollHasMoreBelowKey.self) { hasMoreBelow = $0 }
        // Rows fade out at the edges, the indicator flashes once and a chevron
        // marks rows below the fold, so it is clear the grid scrolls.
        .retroScrollEdgeFade()
        .scrollIndicatorsFlash(onAppear: true)
        .overlay(alignment: .bottom) {
            if hasMoreBelow {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: tvOSAdjusted(20, tvOS: 28), weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasMoreBelow)
        /// A submenu is a new page: start it at its top rather than
        /// wherever the previous one happened to be scrolled.
        .onChange(of: routeStack) { _ in
            scrollProxy.scrollTo(Self.panelTopID, anchor: .top)
        }
        .onChange(of: focusedTileID) { newID in
            guard let newID else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(newID, anchor: .center)
            }
        }
        } // ScrollViewReader
    }

    /// The tallest first-level page's grid height, so every page is drawn that tall and the
    /// panel keeps its size when the page changes. Worked out from cell counts and fixed
    /// cell heights rather than laid out, so no hidden copy of every page is drawn.
    private func rootGridMinHeight(cols: Int, spacing: CGFloat) -> CGFloat {
        let cellHeight = PauseTileFace.height(accessibility: dynamicTypeSize.isAccessibilitySize,
                                              regular: horizontalSizeClass == .regular, labelSize: cellLabelSize)
        return viewModel.pageGroupShapes.map { groups in
            PauseTileLayout.gridHeight(groups: groups, columns: cols, tileHeight: cellHeight, spacing: spacing,
                                       titleHeight: Self.sectionTitleLineHeight, titleGap: Self.sectionTitleGap,
                                       sectionSpacing: tvOSAdjusted(12, tvOS: 20))
        }.max() ?? 0
    }

    /// Gap between a section title and its cells.
    private static let sectionTitleGap: CGFloat = 6

    /// Line height of a section title (`sectionView`), which is a fixed size.
    private static let sectionTitleLineHeight: CGFloat = {
        #if canImport(UIKit)
        return ceil(UIFont.systemFont(ofSize: PauseTileMetrics.sectionTitleSize, weight: .heavy).lineHeight)
        #else
        return ceil(PauseTileMetrics.sectionTitleSize * 1.2)
        #endif
    }()

    // MARK: - Body

    /// The library lobby launched this game to host: go straight to Network Play.
    private func openNetworkPlayIfRequested() {
        #if canImport(PVNetplay)
        if emulatorVC.takeNetworkPlayMenuRequest() {
            startNetplayHosting = true
            showingNetworkPlay = true
        }
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed game background — tapping it resumes
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { requestPauseMenuClose() }

                // The panel takes one of three shapes for the space it has, and on a
                // centred panel is only as wide as its page needs. Everything is derived
                // from the live size, so a window resize or a rotation re-flows it.
                let mode = PauseMenuLayoutMode.resolve(size: geo.size, isTV: Self.isTV)
                let theme = PauseMenuTheme(palette: palette)
                let spacing: CGFloat = tvOSAdjusted(6, tvOS: 12)
                let sections = visibleSections
                let showsGrid = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let fullWidth = fullPanelWidth(in: geo.size, mode: mode)
                let gridWidth = mode == .rail && currentRoute == .root ? fullWidth - PauseMenuChromeMetrics.railWidth : fullWidth
                let fit = mode == .panel
                    ? PauseTileLayout.fit(
                        fullWidth: fullWidth,
                        maxColumns: columnCount(for: fullWidth),
                        tileCounts: viewModel.pageTileCounts,
                        inset: tvOSAdjusted(RetroPauseChrome.chromeInset, tvOS: 20),
                        spacing: spacing,
                        minimumWidth: tvOSAdjusted(PauseTilePanelMetrics.minimumWidth, tvOS: PauseTilePanelMetrics.tvMinimumWidth))
                    : PauseTileLayout.Fit(columns: columnCount(for: gridWidth), width: fullWidth)
                let cols = fit.columns

                panelContent(mode: mode, theme: theme, sections: sections, cols: cols, spacing: spacing,
                             showsGrid: showsGrid, compactExits: fit.width < PauseTilePanelMetrics.compactHeaderWidth)
                    .background(panelBackground(theme: theme, mode: mode))
                    .frame(width: fit.width)
                    .frame(maxHeight: panelMaxHeight(in: geo.size, mode: mode))
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay(alignment: mode == .sheet ? .top : .bottom) { infoPill(mode: mode, theme: theme) }
                    .animation(.easeInOut(duration: 0.2), value: infoText)
                    .environment(\.colorScheme, theme.colorScheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: mode == .sheet ? .bottom : .center)
                    #if os(iOS)
                    // Mirror the drawn columns and shape into @State so controller
                    // navigation walks the controls the panel shows.
                    .task(id: cols) { currentColumns = cols }
                    .task(id: mode) { currentMode = mode }
                    #endif
            }
        }
        .onReceive(emulatorVC.coreInputHandler.$hardwareSwitchPositionIndexes.removeDuplicates()) { positions in
            // A rebuild re-evaluates this body, which can subscribe again, and a new subscription
            // is sent the current positions at once. Rebuilding for positions already drawn
            // would then repeat without end and hang the menu.
            guard positions != viewModel.renderedHardwareSwitchStates else { return }
            // @Published sends before assignment. Rebuild with the new positions.
            rebuildSections(hardwareSwitchPositions: positions)
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
        #if canImport(FreemiumKit)
        .paywall(isPresented: $showingPlusPaywall)
        #endif
        .sheet(isPresented: $showingControllerProfiles) {
            InSessionProfilePickerView(emulatorVC: emulatorVC) {
                showingControllerProfiles = false
            }
        }
        // Back to the game once remapping is done.
        .controllerRemapSheet(target: $controllerRemapTarget) {
            dismissAction(true)
        }
        .fullScreenCover(isPresented: $showingLogViewer) {
            RetroLogView(isFullscreen: $showingLogViewer)
        }
        // On tvOS the default `.sheet` modal renders narrow and centred,
        // which makes Settings (a deep nested form) hard to read and
        // navigate with the focus engine. Use `.fullScreenCover` for the
        // App Settings on tvOS — same pattern already used for
        // `showingLogViewer` above. iOS goes through `settingsPresentation`:
        // a sheet on iPhone, a full-screen cover on iPad, where the sheet
        // was a cramped ~540pt form sheet (#3780). The settings view's own
        // "Done" button calls `dismissAction` so the user can leave the cover.
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
        .settingsPresentation(isPresented: $showingAppSettings) {
            if let appSettings = PauseMenuViewRegistry.appSettingsView(dismissAction: {
                showingAppSettings = false
            }) {
                appSettings
            } else {
                EmptyView()
            }
        }
        #endif
        #if os(iOS) || os(tvOS)
        .fullScreenCover(isPresented: $showingBezels, onDismiss: rebuildSections) {
            GameplayBezelOptionsView(emulatorVC: emulatorVC)
        }
        #endif
        .pauseSkinPresentation(isPresented: $showingSystemSkinSelection) {
            NavigationStack {
                SystemSkinSelectionView(
                    system: activeSystemIdentifier.deltaSkinSystem,
                    game: emulatorVC.game.deltaSkinGameContext,
                    preferredOrientation: pauseSkinOrientation,
                    emptySelectionMeansBuiltIn: ProgrammaticOverlaySupport.skinPickerDefaultsToBuiltIn(for: emulatorVC.core)
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingSystemSkinSelection = false }
                    }
                }
            }
        }
        // The catalog, filtered to the running system; a download can be applied to this game.
        .pauseSkinPresentation(isPresented: $showingSkinCatalog) {
            NavigationStack {
                SkinCatalogBrowserView(
                    preselectedSystem: activeSystemIdentifier.skinCatalogSystemCode,
                    activationContextSystemIdentifier: activeSystemIdentifier.deltaSkinSystem,
                    activationContextGameId: emulatorVC.game?.id
                )
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingSkinCatalog = false }
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
        .netplayPresentation(isPresented: $showingNetworkPlay, onDismiss: {
            startNetplayHosting = false
            if resumeAfterNetworkPlay {
                resumeAfterNetworkPlay = false
                requestPauseMenuClose()
            }
        }, content: {
            NetplayLobbyView(
                gameName: emulatorVC.game?.title ?? "",
                coreIdentifier: emulatorVC.core.coreIdentifier ?? "",
                localGameHash: emulatorVC.game?.md5Hash ?? "",
                gameSerial: emulatorVC.game?.romSerial ?? "",
                systemIdentifier: emulatorVC.game?.systemIdentifier ?? "",
                coreVersion: RomDatabase.sharedInstance.realm.object(ofType: PVCore.self, forPrimaryKey: emulatorVC.core.coreIdentifier ?? "")?.projectVersion ?? "",
                isPatched: emulatorVC.game?.isPatchVariant ?? false,
                startHosting: startNetplayHosting
            )
            // The host started the game or this device joined a room: close the netplay
            // screens, then the menu, once the sheet is gone.
            .environment(\.netplayReturnToGame, NetplayReturnToGameAction {
                resumeAfterNetworkPlay = true
                showingNetworkPlay = false
            })
        })
        #endif
        #if os(tvOS)
        .fullScreenCover(isPresented: $showingShaderBrowser, onDismiss: rebuildSections) {
            ShaderPauseSheet(emulatorVC: emulatorVC)
        }
        .fullScreenCover(isPresented: $showingShaderSettings, onDismiss: rebuildSections) {
            ShaderPauseSheet(emulatorVC: emulatorVC, startInEditor: true)
        }
        #else
        .sheet(isPresented: $showingShaderBrowser, onDismiss: rebuildSections) {
            ShaderPauseSheet(emulatorVC: emulatorVC)
        }
        .sheet(isPresented: $showingShaderSettings, onDismiss: rebuildSections) {
            ShaderPauseSheet(emulatorVC: emulatorVC, startInEditor: true)
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: $showingExternalDisplay, onDismiss: rebuildSections) {
            ExternalDisplayPauseSheet(emulatorVC: emulatorVC)
        }
        #endif
        .sheet(isPresented: $showingPortDevices) {
            PortDevicesPauseSheet(emulatorVC: emulatorVC)
        }
        #if !os(tvOS)
        .sheet(item: $controllerLayoutContext, onDismiss: { rebuildSections() }, content: { context in
            ControllerLayoutPauseSheet(context: context, core: emulatorVC.core)
        })
        #endif
        #if canImport(CoreMIDI) && !os(tvOS) && !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingMIDIPicker) {
            if #available(iOS 16.0, *) {
                MIDIDevicePauseSheet()
            }
        }
        #endif
        // Core action option picker — shown when a CoreAction exposes multiple options.
        .pvAlert(item: $pendingCoreAction) { action in
            let options = action.options ?? []
            let emulatorVC = self.emulatorVC
            let optionActions = options.map { opt in
                PVAlertAction(opt.title) {
                    let selectedAction = CoreAction(
                        title: action.title,
                        requiresReset: action.requiresReset,
                        options: options.map { CoreActionOption(title: $0.title, selected: $0 == opt) },
                        style: action.style
                    )
                    emulatorVC.dismissNav(resumeEmulation: true) {
                        emulatorVC.handleCoreAction(selectedAction)
                    }
                }
            }
            return PVAlert(title: action.title, style: .actionSheet, actions: optionActions + [.cancel()])
        }
        .pvAlert(isPresented: $showingResetCoreOptionsConfirm) {
            PVAlert(
                title: String(localized: "Reset Core Options?"),
                message: coreOptionsPerGame
                    ? String(localized: "This game's options for this core go back to their defaults.")
                    : String(localized: "This core's options go back to their defaults for every game."),
                type: .warning,
                actions: [
                    PVAlertAction(String(localized: "Reset"), role: .destructive) {
                        resetCoreSettingsForCurrentScope()
                    },
                    .cancel()
                ]
            )
        }
        .pvAlert(isPresented: $showingDeferredRestartPrompt) {
            PVAlert(
                title: String(localized: "Restart Required"),
                message: String(localized: "Some core settings require a restart. Apply them now?"),
                type: .warning,
                actions: [
                    PVAlertAction(String(localized: "Save State and Restart")) {
                        performDeferredCoreRestart(createSaveState: true)
                    },
                    PVAlertAction(String(localized: "Restart Without Saving"), role: .destructive) {
                        performDeferredCoreRestart(createSaveState: false)
                    },
                    .cancel(String(localized: "Not Now"))
                ]
            )
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
        .onAppear {
            routeStack = initialRoute == .root ? [.root] : [.root, initialRoute]
            refreshControllerProfileState()
            rebuildSections()
            /// A cursor only where something can move it: touch users see no highlight.
            if focusedTileID == nil, gamepadManager.isNavigationInputAvailable {
                focusedTileID = firstEnabledTileID()
            }
            controllerInput.start()
            openNetworkPlayIfRequested()
        }
        .onDisappear { controllerInput.stop() }
        .onChange(of: focusedTileID) { newID in
            withAnimation(.easeInOut(duration: 0.2)) {
                infoText = description(forCursor: newID)
            }
        }
        .onReceive(controllerInput.commands) { handleControllerCommand($0) }
        #elseif os(tvOS)
        .onAppear {
            appearedUptime = ProcessInfo.processInfo.systemUptime
            routeStack = initialRoute == .root ? [.root] : [.root, initialRoute]
            refreshControllerProfileState()
            rebuildSections()
            reattachTVOSFocusIfNeeded()
            controllerInput.start()
            openNetworkPlayIfRequested()
        }
        .onDisappear { controllerInput.stop() }
        /// The focus engine moves the cursor here; the shoulder buttons change page.
        .onReceive(controllerInput.commands) { command in
            guard !showingBezels else { return }
            if command == .previousTab { switchTab(by: -1) }
            if command == .nextTab { switchTab(by: 1) }
        }
        .onChange(of: focusedTileID) { newID in
            withAnimation(.easeInOut(duration: 0.2)) {
                infoText = description(forCursor: newID)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            reattachTVOSFocusIfNeeded()
        }
        .onExitCommand { handleRemoteBackCommand() }
        .onPlayPauseCommand { handleRemoteBackCommand() }
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

    /// Sends a short switch press/release edge to the core.
    /// Wrapped in `withCoreRunningForInput` because the pause menu stops the core, and
    /// level-sampled cores only see a press if a frame runs while it is held.
    private func dispatchHardwareSwitchButton(_ buttonId: String) {
        withCoreRunningForInput {
            let inputHandler = emulatorVC.coreInputHandler
            inputHandler.sendHardwareSwitch(buttonId, isPressed: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + HardwareSwitchTiming.pressDuration) {
                inputHandler.sendHardwareSwitch(buttonId, isPressed: false)
            }
        }
    }

    /// Runs `input` (a press whose release is already scheduled) with the core
    /// resumed, then re-pauses it. The pause menu pauses the core, so `retro_run()`
    /// never executes and a push/release pair is never sampled by level-sampled
    /// cores (Stella, thin libretro, fmsx...).
    ///
    /// We deliberately do NOT toggle `isShowingMenu`: `cleanupAfterMenuDismissal()`
    /// is gated on `isShowingMenu == true`, so flipping it false during this window
    /// would make a concurrent menu dismissal silently skip cleanup (input
    /// re-enable, overlay restore) and leave the VC stuck. The menu stays open.
    ///
    /// No-op wrapper when the core is not paused: `input` runs and nothing is
    /// resumed or re-paused.
    private func withCoreRunningForInput(window: TimeInterval = HardwareSwitchTiming.pausedMenuSampleWindow,
                                         _ input: () -> Void) {
        let core = emulatorVC.core
        guard core.isOn, core.isEmulationPaused else {
            input()
            return
        }
        core.setPauseEmulation(false)
        input()
        DispatchQueue.main.asyncAfter(deadline: .now() + window) { [weak emulatorVC] in
            // Menu dismissed in the meantime: dismissal owns the pause state.
            guard let emulatorVC, emulatorVC.menuPresentationViewController != nil else { return }
            emulatorVC.core.setPauseEmulation(true)
        }
    }

    /// Briefly fires a press → release on the main queue, mimicking a momentary
    /// physical button tap. The delay matches `dispatchHardwareSwitchButton`.
    private func fireMomentaryRelease(after: TimeInterval = HardwareSwitchTiming.pressDuration, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: block)
    }

    /// Dispatches a system-specific button (Start/Select/Coin/etc.) tile press.
    ///
    /// The pause menu keeps the core paused, so the press/release pair below
    /// would never be sampled by level-sampled cores (Stella, thin libretro):
    /// `withCoreRunningForInput` resumes the core for the sample window, the
    /// same way hardware switches and the coin slot are handled.
    private func dispatchSystemButton(tileID: String) {
        guard let parsed = SystemButtonTileProvider.parse(tileID: tileID) else { return }
        guard emulatorVC.core.isOn else { return }
        withCoreRunningForInput {
            pressSystemButton(parsed)
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Presses a system-specific button by casting the running core to the
    /// appropriate `PV<System>SystemResponderClient` and calling
    /// `didPush(...)`/`didRelease(...)` for the encoded player.
    ///
    /// Tile IDs are `systemButton_pN_<btn>` and the button strings come from
    /// `SystemMenuButton.id`. Call through `dispatchSystemButton` so the core
    /// is running while the press is held.
    private func pressSystemButton(_ parsed: (player: Int, buttonId: String)) {
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
                // Coin has no physical-controller equivalent, so this entry is
                // the only way to trigger it. It needs a longer press than the
                // other buttons to register.
                r.didPush(.coin, forPlayer: player)
                fireMomentaryRelease(after: HardwareSwitchTiming.coinPressDuration) {
                    r.didRelease(.coin, forPlayer: player)
                }
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
        if result.route == .root, let tab = viewModel.tab(containingTileID: result.tile.id) {
            rootTab = tab
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

}
// swiftlint:enable type_body_length

// MARK: - Scroll measurement

/// Whether the tile grid has rows below its scroll viewport.
private struct PauseScrollHasMoreBelowKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

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
