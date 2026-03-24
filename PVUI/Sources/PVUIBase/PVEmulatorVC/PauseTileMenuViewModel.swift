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
import PVSettings
import PVLibrary
#if canImport(PVNetplay)
import PVNetplay
#endif

// MARK: - PauseTileMenuViewModel

/// Lightweight cache that owns the `[PauseMenuTileSection]` array.
///
/// Sections are rebuilt only when ``rebuild`` is called explicitly,
/// avoiding the costly per-render recomputation of `gameSections`.
@MainActor
final class PauseTileMenuViewModel: ObservableObject {

    @Published private(set) var sections: [PauseMenuTileSection] = []

    /// Flat lookup table: tile ID -> description text.
    /// Built alongside `sections` so the info shelf can resolve descriptions in O(1).
    private(set) var descriptionsByTileID: [String: String] = [:]

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
        hapticFeedbackEnabled: Bool,
        featureFlags: PVFeatureFlagsManager,
        indicatorRegistry: PVIndicatorRegistry,
        hasControllerProfiles: Bool
    ) {
        var built: [PauseMenuTileSection] = []

        // ── GAME section ────────────────────────────────────────────────
        let supportsSaveStates = emulatorVC.core.supportsSaveStates
        let hasSave: Bool = {
            guard let game = emulatorVC.game, !game.isInvalidated else { return false }
            return !game.saveStates.isEmpty
        }()
        let supportsCheatCodes = (emulatorVC.core as? GameWithCheat)?.supportsCheatCode == true
        let shouldSave = Self.shouldSaveOnQuit(emulatorVC: emulatorVC)

        var gameTiles: [PauseMenuTile] = [
            PauseMenuTile(id: "resume",     icon: "play.fill",                 label: String(localized: "Resume"),      colorKey: .green),
            PauseMenuTile(id: "saveState",  icon: "square.and.arrow.down",     label: String(localized: "Save State"),  isEnabled: supportsSaveStates,           colorKey: .cyan),
            PauseMenuTile(id: "loadState",  icon: "arrowshape.turn.up.left",   label: String(localized: "Quick Load"),  isEnabled: supportsSaveStates && hasSave, colorKey: .blue),
            PauseMenuTile(id: "browseSaves",icon: "list.bullet.rectangle.portrait", label: String(localized: "Saves"),  isEnabled: supportsSaveStates,           colorKey: .purple, dismissOnTap: false),
            PauseMenuTile(id: "reset",      icon: "arrow.counterclockwise",    label: String(localized: "Reset"),       colorKey: .orange),
        ]
        if supportsCheatCodes {
            gameTiles.append(PauseMenuTile(id: "cheats", icon: "wand.and.stars", label: String(localized: "Cheats"), colorKey: .purple))
        }

        #if os(iOS) || targetEnvironment(macCatalyst)
        gameTiles.append(PauseMenuTile(id: "screenshot",  icon: "camera",            label: String(localized: "Screenshot"),  colorKey: .yellow))
        gameTiles.append(PauseMenuTile(id: "screenshots", icon: "photo.on.rectangle", label: String(localized: "Screenshots"), colorKey: .yellow, dismissOnTap: false))
        #endif

        // Recording — iOS only, hardware-gated (no feature flag in RetroMenuView either)
        #if os(iOS)
        if emulatorVC.isRecordingAvailable {
            let isRec = emulatorVC.isRecording
            gameTiles.append(PauseMenuTile(
                id: "recording",
                icon: isRec ? "stop.circle" : "record.circle",
                label: String(localized: isRec ? "Stop Rec" : "Record"),
                badge: isRec ? "REC" : nil,
                colorKey: isRec ? .pink : .orange,
                dismissOnTap: true
            ))
            // Camera position — only when camera overlay is enabled
            if Defaults[.recordingCameraEnabled] {
                let pos = Defaults[.recordingCameraPosition]
                let lpOptions = CameraPosition.allCases.map { camPos in
                    PauseMenuTileLongPressOption(
                        id: "camPos_\(camPos.rawValue)",
                        title: camPos.displayName,
                        isSelected: camPos == pos
                    )
                }
                gameTiles.append(PauseMenuTile(
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

        // Broadcast — feature-flagged, iOS + tvOS
        #if os(iOS) || os(tvOS)
        if featureFlags.liveBroadcast {
            let isBcast = emulatorVC.isBroadcasting
            gameTiles.append(PauseMenuTile(
                id: "broadcast",
                icon: isBcast ? "stop.circle" : "dot.radiowaves.left.and.right",
                label: String(localized: isBcast ? "Stop Live" : "Go Live"),
                badge: isBcast ? "LIVE" : nil,
                colorKey: isBcast ? .pink : .cyan,
                dismissOnTap: false
            ))
        }
        // Save Clip — feature-flagged, only visible when clip buffering is active
        if featureFlags.clipBuffering && emulatorVC.isClipBufferingActive {
            gameTiles.append(PauseMenuTile(
                id: "saveClip",
                icon: "scissors.badge.ellipsis",
                label: String(localized: "Save Clip"),
                colorKey: .purple,
                dismissOnTap: true
            ))
        }
        #endif

        gameTiles.append(PauseMenuTile(id: "gameInfo",          icon: "info.circle",    label: String(localized: "Game Info"),   colorKey: .blue))
        gameTiles.append(PauseMenuTile(id: "controllerProfile", icon: "gamecontroller", label: String(localized: "Controller"),  isEnabled: hasControllerProfiles, colorKey: .purple, dismissOnTap: false))
        if featureFlags.netplayEnabled && Self.coreSupportsNetplay(emulatorVC) {
            gameTiles.append(PauseMenuTile(
                id: "networkPlay",
                icon: "antenna.radiowaves.left.and.right",
                label: String(localized: "Network Play"),
                colorKey: .blue,
                dismissOnTap: false
            ))
        }

        #if os(iOS) || targetEnvironment(macCatalyst)
        if featureFlags.companionController {
            gameTiles.append(PauseMenuTile(
                id: "companionController",
                icon: "iphone.and.arrow.forward",
                label: String(localized: "Companion"),
                colorKey: .orange,
                dismissOnTap: false
            ))
        }
        #endif

        if shouldSave {
            gameTiles.append(PauseMenuTile(id: "saveQuit", icon: "square.and.arrow.down.on.square", label: String(localized: "Save & Quit"), colorKey: .cyan))
        }
        gameTiles.append(PauseMenuTile(id: "quit", icon: "xmark.circle", label: shouldSave ? String(localized: "Quit (No Save)") : String(localized: "Quit"), colorKey: .pink))

        built.append(PauseMenuTileSection(id: "game", title: String(localized: "GAME"), tiles: gameTiles))

        // ── QUICK SETTINGS section ──────────────────────────────────────
        var displayTiles: [PauseMenuTile] = []
        displayTiles.append(Self.filterCycleTile(metalFilterMode: metalFilterMode))
        if let rumbleTile = Self.rumbleToggleTile(core: emulatorVC.core, hapticFeedbackEnabled: hapticFeedbackEnabled) {
            displayTiles.append(rumbleTile)
        }
        if let jitTile = Self.jitStatusTile(core: emulatorVC.core, indicatorRegistry: indicatorRegistry) {
            displayTiles.append(jitTile)
        }
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

        // ── CORE section (dynamic, per-core) ────────────────────────────
        var coreTiles: [PauseMenuTile] = []

        // Show Transfer Pak tile only for known compatible titles.
        // Showing it for all N64 games is misleading — most games don't use the Transfer Pak.
        let gameTitle = emulatorVC.game?.title ?? ""
        if let transferCore = emulatorVC.core as? TransferPakSupport,
           featureFlags.mupenTransferPak,
           transferCore.transferPakSlotCount > 0,
           TransferPakCompatibleGames.isKnownTransferPakGame(gameTitle)
               || (0..<transferCore.transferPakSlotCount).contains(where: { transferCore.transferPakROM(forPort: $0) != nil }) {
            let configuredCount = (0..<transferCore.transferPakSlotCount).filter {
                transferCore.transferPakROM(forPort: $0) != nil
            }.count
            coreTiles.append(PauseMenuTile(
                id: "transferPak",
                icon: "memorychip",
                label: String(localized: "Transfer Pak"),
                badge: configuredCount > 0 ? "\(configuredCount)" : nil,
                colorKey: .green,
                dismissOnTap: false
            ))
        }

        let n64ID = SystemIdentifier.N64.rawValue
        let gameSystemID = emulatorVC.game?.systemIdentifier ?? emulatorVC.core.systemIdentifier
        if gameSystemID == n64ID {
            coreTiles.append(PauseMenuTile(
                id: "n64PakSlots",
                icon: "gamecontroller.fill",
                label: String(localized: "Pak Slots"),
                colorKey: .blue,
                dismissOnTap: false
            ))
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
            coreTiles += CoreOptionTileProvider.tiles(from: coreClass.options, coreClass: coreClass)
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

        sections = built
        descriptionsByTileID = descs
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
        guard let bridge = emulatorVC.core as? any PVNetplayCapable else { return false }
        return bridge.supportsNetplay
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
}

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
