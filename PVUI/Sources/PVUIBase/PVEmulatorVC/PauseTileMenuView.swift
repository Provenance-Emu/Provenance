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
import PVSettings
import PVThemes
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - PauseTileMenuView

/// Compact tile/grid pause overlay that floats over the game screen.
/// Enabled when the `pauseTileMenu` feature flag is on; otherwise `PVGameMenuOverlay`
/// falls back to the classic `RetroMenuView`.
struct PauseTileMenuView: View {
    let emulatorVC: PVEmulatorViewController
    let dismissAction: (Bool) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var indicatorRegistry = PVIndicatorRegistry.shared
    @StateObject private var viewModel = PauseTileMenuViewModel()

    // MARK: Sheet state

    @State private var showingSaveStateBrowser = false
    @State private var showingScreenshotBrowser = false
    @State private var showingControllerProfiles = false
    @State private var showingTransferPakConfig = false
    @State private var showingN64PakConfig = false
    @State private var showingPalettePicker = false
    @State private var showingNetworkPlay = false
    /// Core action awaiting option picker confirmation.
    @State private var pendingCoreAction: CoreAction?
    /// Cached result of the Realm query — refreshed on appear, not on every render.
    @State private var hasControllerProfiles = false
    /// Description text shown in the bottom info shelf when a tile is focused/long-pressed.
    @State private var infoText: String?

    // MARK: tvOS Focus

    @FocusState private var focusedTileID: String?

    // MARK: Size class / orientation

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.featureFlags) private var featureFlags

    // Metal filter state — read/write directly to react to changes.
    @Default(.metalFilterMode) private var metalFilterMode

    // Haptic feedback toggle
    @Default(.hapticFeedback) private var hapticFeedbackEnabled

    #if os(iOS)
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
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

    // MARK: - Rebuild cached sections via view model

    /// Triggers a full section rebuild. Call on appear and after any option mutation.
    private func rebuildSections() {
        viewModel.rebuild(
            emulatorVC: emulatorVC,
            metalFilterMode: metalFilterMode,
            hapticFeedbackEnabled: hapticFeedbackEnabled,
            featureFlags: featureFlags,
            indicatorRegistry: indicatorRegistry,
            hasControllerProfiles: hasControllerProfiles
        )
    }

    // MARK: - Tile action dispatcher

    private func handle(_ tile: PauseMenuTile) {
        guard tile.isEnabled else { return }
        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        switch tile.id {
        case "resume":
            dismissAction(true)
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
            showingTransferPakConfig = true

        // MARK: N64 Controller Pak slot picker
        case "n64PakSlots":
            showingN64PakConfig = true

        // MARK: Palette picker sheet
        case "palette":
            showingPalettePicker = true

        // MARK: Quick-settings tiles
        case "filterCycle":
            cycleFilter()
        case "rumbleToggle":
            hapticFeedbackEnabled.toggle()
            rebuildSections()
        case "keyboardToggle":
            #if canImport(UIKit) && !os(tvOS)
            emulatorVC.toggleVirtualKeyboard()
            rebuildSections()
            #endif
        case "mouseToggle":
            #if canImport(UIKit) && !os(tvOS)
            emulatorVC.toggleVirtualMouse()
            rebuildSections()
            #endif
        case "jitStatus":
            break // read-only

        // MARK: Recording / broadcast / clip
        case "recording":
            #if os(iOS)
            if emulatorVC.isRecording {
                dismissForSubSheetThen { self.emulatorVC.stopScreenRecording() }
            } else {
                dismissAction(true)
                emulatorVC.startScreenRecording()
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
                let currentValue: Bool = coreClass.valueForOption(option)
                coreClass.setValue(!currentValue, forOption: option, andMD5: coreClass.currentGameMD5)
            case .enumeration, .multi:
                CoreOptionTileProvider.cycleNextValue(for: option, coreClass: coreClass)
            default:
                break
            }
            rebuildSections()

        // MARK: Core settings gateway
        case CoreOptionTileProvider.coreSettingsTileID:
            dismissForSubSheetThen { self.emulatorVC.showCoreOptions() }

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
            CoreOptionTileProvider.selectValue(titled: lpOption.title, for: option, coreClass: coreClass)
            rebuildSections()
        }
    }

    private func dismissForSubSheetThen(_ action: @escaping () -> Void) {
        emulatorVC.dismissNav(resumeEmulation: false, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
        })
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
        let cornerRadius: CGFloat = 14
        #else
        let iconSize: CGFloat = 20
        let labelSize: CGFloat = 10
        let badgeSize: CGFloat = 8
        let cornerRadius: CGFloat = 10
        #endif

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
                    .fill(accentColor.opacity(isFocused ? 0.22 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(accentColor.opacity(isFocused ? 0.85 : 0.35), lineWidth: isFocused ? 2 : 1)
                    )
            )
            .shadow(color: isFocused ? accentColor.opacity(0.5) : .clear, radius: 14, x: 0, y: 3)
        }
        .buttonStyle(TileButtonStyle(isFocused: isFocused))
        .opacity(opacity)
        .disabled(!tile.isEnabled)
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
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.retroPurple.opacity(0.65), .retroPink.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }

    // MARK: - Section view

    private func sectionView(section: PauseMenuTileSection, cols: Int, spacing: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols)
        return VStack(alignment: .leading, spacing: 6) {
            if let title = section.title {
                Text(title)
                    .font(.system(size: tvOSAdjusted(9, tvOS: 13), weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(tvOSAdjusted(1.5, tvOS: 2.5))
                    .padding(.horizontal, 2)
            }
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(section.tiles) { tile in
                    tileView(for: tile)
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
                    .onTapGesture { dismissAction(true) }

                // Floating tile panel
                let panelWidth = min(geo.size.width - 32, panelMaxWidth)
                let cols = columnCount(for: panelWidth)
                let spacing: CGFloat = tvOSAdjusted(6, tvOS: 12)
                let sections = viewModel.sections

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: tvOSAdjusted(12, tvOS: 20)) {
                            // Panel title
                            HStack {
                                Spacer()
                                Text(String(localized: "GAME MENU"))
                                    .font(.system(size: tvOSAdjusted(12, tvOS: 18), weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.55))
                                    .tracking(tvOSAdjusted(2, tvOS: 3.5))
                                Spacer()
                            }
                            .padding(.top, tvOSAdjusted(2, tvOS: 6))

                            // Grouped sections
                            ForEach(sections) { section in
                                sectionView(section: section, cols: cols, spacing: spacing)
                                if section.id != sections.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.12))
                                }
                            }
                        }
                        .padding(tvOSAdjusted(12, tvOS: 20))
                    }

                    // Info shelf — shows description for focused/long-pressed tile
                    infoShelfView
                }
                .background(panelBackground)
                .frame(width: panelWidth)
                .frame(maxHeight: geo.size.height * 0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .retroPurple.opacity(0.25), radius: 18, x: 0, y: 0)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
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
        .sheet(isPresented: $showingTransferPakConfig) {
            if let game = emulatorVC.game, !game.isInvalidated {
                let transferCore = emulatorVC.core as? TransferPakSupport
                TransferPakConfigView(
                    game: game,
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
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
        .onAppear {
            orientation = UIDevice.current.orientation
            refreshControllerProfileState()
            rebuildSections()
        }
        .onChange(of: focusedTileID) { newID in
            withAnimation(.easeInOut(duration: 0.2)) {
                infoText = viewModel.description(forTileID: newID)
            }
        }
        #elseif os(tvOS)
        .onAppear {
            refreshControllerProfileState()
            rebuildSections()
            if let firstEnabled = viewModel.sections.first?.tiles.first(where: { $0.isEnabled }) {
                focusedTileID = firstEnabled.id
            }
        }
        .onChange(of: focusedTileID) { newID in
            withAnimation(.easeInOut(duration: 0.2)) {
                infoText = viewModel.description(forTileID: newID)
            }
        }
        .onExitCommand { dismissAction(true) }
        .onPlayPauseCommand { dismissAction(true) }
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

    private func tvOSAdjusted(_ standard: CGFloat, tvOS tvOSValue: CGFloat) -> CGFloat {
        #if os(tvOS)
        return tvOSValue
        #else
        return standard
        #endif
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
