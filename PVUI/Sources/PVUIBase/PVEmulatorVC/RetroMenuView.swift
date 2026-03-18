//
//  RetroMenuView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI
import UIKit
import PVCoreBridge
import PVLogging
import PVSettings
import GameController
import PVSupport
import PVLibrary
import PVFeatureFlags
import UniformTypeIdentifiers
import PVThemes
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - SwiftUI Menu Views

// Main menu view with retrowave styling
struct RetroMenuView: View {
    let emulatorVC: PVEmulatorViewController
    let dismissAction: (Bool) -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.showFPSCount) private var showFPSCount

    @State private var selectedCategory: MenuCategory = .main
    /// Tracks whether the user is actively dragging the category scroll bar.
    /// Using @GestureState ensures the flag is always reset — even on gesture cancellation —
    /// which prevents the tab bar from locking up when a scroll ends mid-state-update.
    @GestureState private var isDraggingCategoryBar: Bool = false

    private var palette: UXThemePalette { themeManager.currentPalette }

    /// Dismisses the menu without resuming emulation - use when opening sub-sheets that should keep the game paused
    private func dismissMenuForSubSheet() {
        dismissMenuForSubSheetThen {}
    }

    private func dismissMenuForSubSheetThen(_ action: @escaping () -> Void) {
        emulatorVC.dismissNav(resumeEmulation: false, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                action()
            }
        })
    }

    /// Environment value to detect screen size
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Get device orientation
    #if os(iOS)
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    #endif

    /// Compute if we're in landscape mode
    private var isLandscape: Bool {
        #if os(iOS)
        // Use size classes as the primary indicator (more reliable)
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            return true
        }
        // Fall back to device orientation
        return orientation.isLandscape
        #else
        return true
        #endif
    }

    // Background with retrowave styling
    var background: some View {
        Color.clear
            .modifier(RetrowaveBackgroundModifier())
            .ignoresSafeArea()
            .onTapGesture {
                dismissAction(true)
            }
    }

    // Menu content based on selected category
    var menuContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: menuSpacing) {
                switch selectedCategory {
                case .main:
                    mainMenuButtons
                case .core:
                    coreMenuButtons
                case .states:
                    stateMenuButtons
                case .options:
                    optionsMenuButtons
                #if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
                case .skins:
                    skinsMenuButtons
                #endif
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16) // Add padding at top and bottom
        }
        .frame(maxWidth: menuWidth)
    }

    /// Compute the appropriate menu width based on orientation and device
    private var menuWidth: CGFloat {
        if isLandscape {
            // In landscape, use a narrower menu that doesn't overwhelm the screen
            return min(450, UIScreen.main.bounds.width * 0.45)
        } else {
            // In portrait, use a wider menu but with a max width
            return min(420, UIScreen.main.bounds.width * 0.9)
        }
    }

    /// Maximum menu height constraint to prevent overwhelming the screen
    private var menuHeight: CGFloat {
        if isLandscape {
            return min(UIScreen.main.bounds.height * 0.9, 640)
        } else {
            return min(UIScreen.main.bounds.height * 0.8, 640)
        }
    }

    /// Vertical spacing for menu items based on orientation
    private var menuSpacing: CGFloat {
        return isLandscape ? 8 : 12
    }

    // Menu container
    var menuContainer: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Container for the menu
                VStack(spacing: 0) {
                    // Title with neon glow effect
                    title

                    // Retrowave scrollable category selector
                    catagories

                    // Menu content based on selected category
                    menuContent
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                .opacity(palette.dark ? 0.9 : 0.95)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(palette.defaultTintColor.swiftUIColor, lineWidth: 2)
                        )
                )
                .frame(width: menuWidth)
                // Fix the horizontal size, allow vertical to adjust with constraints
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxHeight: menuHeight)
                // Add animation for smooth transitions between categories
                .animation(.easeInOut(duration: 0.2), value: selectedCategory)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// Computed height for title component
    private var title: some View {
        Text(String(localized: "GAME OPTIONS"))
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(palette.gameLibraryHeaderText.swiftUIColor)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.8 : 0.5), radius: 10, x: 0, y: 0)
    }

    // Retrowave scrollable category selector
    var catagories: some View {
        ZStack {
            // Gradient background for scrollable area
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(palette.dark ? 0.2 : 0.1),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 50)

            // Grid lines for retrowave effect
            HStack(spacing: 15) {
                ForEach(0..<10) { _ in
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.3 : 0.15))
                }
            }

            // Scrollable buttons with fade edges
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            categoryButton(title: String(localized: "MAIN"), isSelected: selectedCategory == .main, action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = .main
                                }
                            })
                            .id("main")
                            // Always show CORE tab so sibling tabs stay in a fixed position.
                            // Grey it out in-place when no core features are available.
                            categoryButton(title: String(localized: "CORE"), isSelected: selectedCategory == .core, action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = .core
                                }
                            })
                            .id("core")
                            .opacity(hasCoreFeatures ? 1.0 : 0.4)
                            categoryButton(title: String(localized: "STATES"), isSelected: selectedCategory == .states, action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = .states
                                }
                            })
                            .id("states")
                            categoryButton(title: String(localized: "OPTIONS"), isSelected: selectedCategory == .options, action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = .options
                                }
                            })
                            .id("options")
                            #if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
                            // Always show skins category - display message if not supported
                            categoryButton(title: String(localized: "SKINS"), isSelected: selectedCategory == .skins, action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = .skins
                                }
                            })
                            .id("skins")
                            #endif
                        }
                        .padding(.horizontal, 20)
                    }
                    #if !os(tvOS)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .updating($isDraggingCategoryBar) { _, state, _ in
                                state = true
                            }
                    )
                    #endif
                    .onChange(of: selectedCategory) { newCategory in
                        // Only programmatically scroll if user is not actively dragging
                        guard !isDraggingCategoryBar else { return }

                        // Scroll to selected category
                        let categoryId: String
                        switch newCategory {
                        case .main: categoryId = "main"
                        case .core: categoryId = "core"
                        case .states: categoryId = "states"
                        case .options: categoryId = "options"
                        #if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
                        case .skins: categoryId = "skins"
                        #endif
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(categoryId, anchor: .center)
                        }
                    }
                }

                // Left fade edge indicator - shows more content to the left
                HStack {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(palette.dark ? 0.95 : 0.98), location: 0),
                            .init(color: Color.clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 30)
                    .allowsHitTesting(false)
                    Spacer()
                }

                // Right fade edge indicator - shows more content to the right
                HStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(palette.dark ? 0.95 : 0.98), location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 30)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 50)
        .padding(.bottom, 16)
    }

    var body: some View {
        ZStack {
            // Background with retrowave styling
            background

            // Menu container
            menuContainer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingSaveStateBrowser) {
            PauseMenuSaveStateBrowserView(emulatorVC: emulatorVC) { stateToLoad in
                showingSaveStateBrowser = false
                guard let state = stateToLoad else {
                    // User dismissed the browser without loading — return to pause menu.
                    return
                }
                // User chose to load a state — close the pause menu, then load.
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
        // Listen for orientation changes
#if !os(tvOS) && !os(macOS) && !targetEnvironment(macCatalyst)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let previousOrientation = self.orientation
            self.orientation = UIDevice.current.orientation

                // Only handle actual orientation changes (not face up/down or unknown)
                if previousOrientation.isLandscape != self.orientation.isLandscape &&
                   (self.orientation.isLandscape || self.orientation.isPortrait) {
                    // Update the current orientation for skin management
                    let newOrientation = self.orientation.isLandscape ? SkinOrientation.landscape : .portrait
                    self.currentOrientation = newOrientation

                    // Reapply session skin if we have one stored for the new orientation
                    Task {
                        let skinId = newOrientation == .portrait ? sessionPortraitSkinIdentifier : sessionLandscapeSkinIdentifier
                        if let skinId = skinId {
                            await reapplySessionSkin(skinId: skinId, orientation: newOrientation)
                        } else {
                            // No session skin for this orientation, check preferences
                            await applySkinForCurrentOrientation()
                        }
                    }
                }
        }
        #endif
        // Initial orientation detection
#if !os(tvOS)
        .onAppear {
            self.orientation = UIDevice.current.orientation
            // Initialize current orientation to match device
            currentOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        }
#endif
        // Handle tvOS Menu/Back button - resume game when dismissed
#if os(tvOS)
        .onExitCommand {
            // Same behavior as pressing "RESUME GAME" button
            dismissAction(true)
        }
#endif
    }

    /// Check if core has features that warrant a CORE tab
    private var hasCoreFeatures: Bool {
        #if !os(tvOS)
        return emulatorVC.core is CoreOptional ||
        (emulatorVC.core as? CoreActions)?.coreActions != nil ||
        emulatorVC.coreSupportsVirtualKeyboard ||
        emulatorVC.coreSupportsVirtualMouse ||
        hasPortDeviceOptions
        #else
        return emulatorVC.core is CoreOptional ||
        (emulatorVC.core as? CoreActions)?.coreActions != nil ||
        hasPortDeviceOptions
        #endif
    }

    /// Whether the game qualifies for a save on quit based on play time and auto-save settings.
    private var shouldSaveOnQuit: Bool {
        guard let game = emulatorVC.game else { return false }

        let lastPlayed: Date = game.lastPlayed ?? Date()
        let minimumPlayTimeToMakeAutosave: TimeInterval = 60 * 2

        let twoMinutes: TimeInterval = 120
        let oneMinute: TimeInterval = 60
        var result: Bool = Defaults[.autoSave]
        result = result && abs(lastPlayed.timeIntervalSinceNow) > minimumPlayTimeToMakeAutosave
        result = result && (game.lastAutosaveAge ?? twoMinutes) > oneMinute
        result = result && abs((!game.isInvalidated ? game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow : nil) ?? twoMinutes) > oneMinute
        result = result && emulatorVC.core.supportsSaveStates

        return result
    }

    // Main menu buttons - essential game controls only
    private var mainMenuButtons: some View {
        let shouldSave: Bool = shouldSaveOnQuit
        // Determine cheat support once so button position stays fixed
        let supportsCheatCodes: Bool = (emulatorVC.core as? GameWithCheat)?.supportsCheatCode == true

        return VStack(spacing: menuSpacing) {
            // Position 1 — Resume game (green = safe/go); primary action
            menuButton(title: String(localized: "RESUME GAME"), icon: "play.fill", color: .retroGreen, role: .primary) {
                dismissAction(true)
            }

            // Position 2 — Reset game (orange = caution); destructive — resets progress
            menuButton(title: String(localized: "RESET GAME"), icon: "arrow.counterclockwise", color: .retroOrange, role: .destructive) {
                dismissAction(true)
                emulatorVC.core.resetEmulation()
            }

            // Position 3 — Game info (blue = informational)
            menuButton(title: String(localized: "GAME INFO"), icon: "info.circle", color: .retroBlue) {
                dismissMenuForSubSheetThen {
                    emulatorVC.showMoreInfo()
                }
            }

            // Position 4 — Cheat codes (purple = special/magic)
            // Always rendered at this position so QUIT stays at position 5.
            // Disabled/dimmed when the core does not support cheat codes.
            menuButton(title: String(localized: "CHEAT CODES"), icon: "wand.and.stars", color: supportsCheatCodes ? .retroPurple : .gray) {
                if supportsCheatCodes {
                    dismissMenuForSubSheetThen {
                        emulatorVC.showCheatsMenu()
                    }
                }
            }
            .opacity(supportsCheatCodes ? 1.0 : 0.4)
            .allowsHitTesting(supportsCheatCodes)

            // Position 5 — Quit (red/pink = destructive action); clearly marks irreversible exit
            // Label changes based on whether a save prompt is offered; position is always 5.
            menuButton(title: shouldSave ? String(localized: "QUIT (WITHOUT SAVING)") : String(localized: "QUIT GAME"), icon: "xmark.circle", color: .retroPink, role: .destructive) {
                dismissAction(false)
                Task { @MainActor in
                    await emulatorVC.quit(optionallySave: false)
                }
            }

            // Position 6 — Save & Quit (cyan = safe save action); only shown when applicable
            if shouldSave {
                menuButton(title: String(localized: "SAVE & QUIT"), icon: "square.and.arrow.down", color: .retroCyan) {
                    dismissAction(false)
                    let image = emulatorVC.captureScreenshot()

                    Task { @MainActor in
                        do {
                            try await emulatorVC.createNewSaveState(auto: true, screenshot: image)
                            await emulatorVC.quit(optionallySave: false)
                        } catch {
                            ELOG("Autosave failed to make save state: \(error.localizedDescription)")
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Core-specific menu buttons - core actions and options
    private var coreMenuButtons: some View {
        VStack(spacing: menuSpacing) {
            // Core action buttons (if available) - show first for prominence
            if let actionableCore = emulatorVC.core as? CoreActions, let actions = actionableCore.coreActions {
                ForEach(actions) { coreAction in
                    menuButton(title: coreAction.title, icon: "bolt", color: .retroYellow) {
                        dismissAction(true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            actionableCore.selected(action: coreAction)
                            self.emulatorVC.core.setPauseEmulation(false)
                            if coreAction.requiresReset {
                                self.emulatorVC.core.resetEmulation()
                            }
                        }
                    }
                }
            }

            // Core options button (if available)
            if emulatorVC.core is CoreOptional {
                menuButton(title: String(localized: "CORE OPTIONS"), icon: "gearshape", color: .retroPurple) {
                    dismissMenuForSubSheetThen {
                        emulatorVC.showCoreOptions()
                    }
                }
            }

            #if !os(tvOS)
            if emulatorVC.coreSupportsVirtualKeyboard {
                menuButton(
                    title: emulatorVC.isVirtualKeyboardVisible ? String(localized: "HIDE KEYBOARD") : String(localized: "VIRTUAL KEYBOARD"),
                    icon: "keyboard",
                    color: .retroBlue
                ) {
                    dismissAction(false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        emulatorVC.toggleVirtualKeyboard()
                        emulatorVC.core.setPauseEmulation(false)
                    }
                }
            }

            if emulatorVC.coreSupportsVirtualMouse {
                menuButton(
                    title: emulatorVC.isVirtualMouseVisible ? String(localized: "HIDE MOUSE") : String(localized: "VIRTUAL MOUSE"),
                    icon: "computermouse",
                    color: .retroCyan
                ) {
                    dismissAction(false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        emulatorVC.toggleVirtualMouse()
                        emulatorVC.core.setPauseEmulation(false)
                    }
                }
            }
            #endif

            // Per-port device type picker (e.g. Joypad → Mouse for Mario Paint)
            portDevicePickerSection

            // If no core features available, show message
            if !hasCoreFeatures {
                Text(String(localized: "No core-specific features available"))
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Save state related buttons
    private var stateMenuButtons: some View {
        let supportsSaveStates = emulatorVC.core.supportsSaveStates
        let allSaves: [PVSaveState] = {
            guard let game = emulatorVC.game, !game.isInvalidated else { return [] }
            return Array(game.saveStates.sorted(byKeyPath: "date", ascending: false))
        }()
        let saveCount = allSaves.count
        let lastSaveDate = allSaves.first?.date
        let hasAnySave = saveCount > 0

        return VStack(spacing: menuSpacing) {
            // MARK: - Save States section
            skinSectionHeader(String(localized: "SAVE STATES"), systemImage: "internaldrive")

            // Summary info: N saves · last saved X ago
            if supportsSaveStates {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                    if saveCount == 0 {
                        Text(String(localized: "No saves"))
                    } else {
                        Text("\(saveCount) save\(saveCount == 1 ? "" : "s")")
                        if let date = lastSaveDate {
                            Text("·")
                            (Text(date, style: .relative) + Text(" ago"))
                                .lineLimit(1)
                        }
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            }

            // SAVE STATE — creates a new save
            menuButton(title: String(localized: "SAVE STATE"), icon: "square.and.arrow.down", color: .retroCyan) {
                let screenshot = emulatorVC.captureScreenshot()
                Task { @MainActor in
                    do {
                        try await emulatorVC.createNewSaveState(auto: false, screenshot: screenshot)
                    } catch {
                        ELOG("Failed to save state: \(error.localizedDescription)")
                    }
                    dismissAction(true)
                }
            }
            .opacity(supportsSaveStates ? 1.0 : 0.4)
            .disabled(!supportsSaveStates)

            // QUICK LOAD — immediately loads the most recent save state
            menuButton(title: String(localized: "QUICK LOAD"), icon: "arrowshape.turn.up.left", color: .retroBlue) {
                guard let game = emulatorVC.game, !game.isInvalidated,
                      let mostRecent = game.saveStates.sorted(byKeyPath: "date", ascending: false).first else { return }
                dismissAction(false)
                Task { @MainActor [weak emulatorVC = emulatorVC] in
                    await emulatorVC?.loadSaveState(mostRecent)
                }
            }
            .opacity(supportsSaveStates && hasAnySave ? 1.0 : 0.4)
            .disabled(!supportsSaveStates || !hasAnySave)

            // BROWSE SAVES — opens a SwiftUI save state picker within the pause menu flow
            menuButton(title: String(localized: "BROWSE SAVES"), icon: "list.bullet.rectangle.portrait", color: .retroPurple) {
                showingSaveStateBrowser = true
            }
            .opacity(supportsSaveStates ? 1.0 : 0.4)
            .disabled(!supportsSaveStates)

            // MARK: - Capture section
            skinSectionHeader(String(localized: "CAPTURE"), systemImage: "camera")

#if os(iOS) || targetEnvironment(macCatalyst)
            menuButton(title: String(localized: "SAVE SCREENSHOT"), icon: "camera", color: .retroYellow) {
                dismissAction(true)
                emulatorVC.takeScreenshot()
            }

            menuButton(title: String(localized: "SCREENSHOTS"), icon: "photo.on.rectangle.angled", color: .retroOrange) {
                showingScreenshotBrowser = true
            }
#endif

#if os(iOS)
            recordingButton
#endif

            // MARK: - Peripherals section
            peripheralsSection

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Peripherals section — shows available device interfaces (mic, camera, MIDI, sensors)
    /// and per-port device type pickers when the core reports controller info.
    @ViewBuilder
    private var peripheralsSection: some View {
        let core = emulatorVC.core

        // Check if any peripherals are relevant
        let hasMic = (core as? KeyboardResponder)?.gameSupportsKeyboard == true || true // TODO: proper mic check
        let hasMouse = (core as? MouseResponder)?.gameSupportsMouse == true
        let hasKeyboard = (core as? KeyboardResponder)?.gameSupportsKeyboard == true

        // Check for thin wrapper port info
        let portInfo: [[NSDictionary]]? = {
            guard let bridge = (core as? NSObject)?.value(forKey: "_bridge") as? NSObject,
                  bridge.responds(to: Selector(("controllerPortInfo"))) else { return nil }
            return bridge.value(forKey: "controllerPortInfo") as? [[NSDictionary]]
        }()

        let showSection = hasMouse || hasKeyboard || (!hasPortDeviceOptions && portInfo != nil && !(portInfo?.isEmpty ?? true))

        if showSection {
            skinSectionHeader(String(localized: "PERIPHERALS"), systemImage: "cable.connector")

            if hasKeyboard {
                menuButton(title: "VIRTUAL KEYBOARD", icon: "keyboard", color: .retroBlue) {
                    dismissAction(false)
                    #if os(tvOS)
                    emulatorVC.toggleSiriRemoteKeyboard()
                    #else
                    emulatorVC.showVirtualKeyboard(animated: true, startExpanded: true)
                    #endif
                }
            }

            if hasMouse {
                menuButton(title: "VIRTUAL MOUSE", icon: "computermouse", color: .retroPurple) {
                    dismissAction(false)
                    #if os(tvOS)
                    emulatorVC.toggleSiriRemoteMouse()
                    #else
                    emulatorVC.showVirtualMouse()
                    #endif
                }
            }

            // Per-port device type picker (from SET_CONTROLLER_INFO) — only shown when the
            // core does NOT conform to PortDeviceConfigurable (which gets its own richer UI
            // in the CORE tab via portDevicePickerSection, preventing duplicate controls).
            if !hasPortDeviceOptions, let portInfo = portInfo, !portInfo.isEmpty {
                ForEach(Array(portInfo.enumerated()), id: \.offset) { portIndex, devices in
                    if devices.count > 1 { // Only show if there are multiple options
                        let deviceNames = devices.compactMap { $0["desc"] as? String }
                        Menu {
                            ForEach(Array(devices.enumerated()), id: \.offset) { idx, device in
                                if let desc = device["desc"] as? String,
                                   let deviceId = device["id"] as? UInt32 {
                                    Button(desc) {
                                        if let bridge = (core as? NSObject)?.value(forKey: "_bridge") as? NSObject,
                                           bridge.responds(to: Selector(("setControllerPortDevice:forPort:"))) {
                                            bridge.perform(
                                                Selector(("setControllerPortDevice:forPort:")),
                                                with: NSNumber(value: deviceId),
                                                with: NSNumber(value: UInt32(portIndex))
                                            )
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "gamecontroller")
                                    .foregroundColor(.retroBlue)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PORT \(portIndex + 1)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.retroBlue.opacity(0.8))
                                    Text(deviceNames.joined(separator: " / "))
                                        .font(.system(size: isLandscape ? 13 : 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.retroBlue.opacity(0.5))
                            }
                            .padding(.vertical, isLandscape ? 8 : 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.55))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.retroBlue.opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    // Screen recording button with Plus gating
#if os(iOS)
    @ViewBuilder
    private var recordingButton: some View {
        let isRecording = AppState.shared.emulationUIState.isRecording
        let isAvailable = PVRecordingManager.shared.isAvailable
        if isAvailable {
            let title = isRecording ? "STOP RECORDING" : "RECORD GAMEPLAY"
            let icon = isRecording ? "stop.circle" : "record.circle"
            let color: Color = isRecording ? .retroPink : .retroOrange
            let role: MenuButtonRole = isRecording ? .destructive : .secondary
#if canImport(FreemiumKit)
            PaidFeatureView {
                menuButton(title: title, icon: icon, color: color, role: role) {
                    if isRecording {
                        // Keep game paused while the ReplayKit preview sheet is shown;
                        // emulation resumes automatically when the preview is dismissed.
                        dismissMenuForSubSheetThen {
                            emulatorVC.stopScreenRecording()
                        }
                    } else {
                        dismissAction(true)
                        emulatorVC.startScreenRecording()
                    }
                }
            } lockedView: {
                HStack {
                    menuButton(title: title, icon: icon, color: color, role: role) {}
                        .disabled(true)
                        .opacity(0.6)
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("PLUS")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.retroPink.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                    .padding(.trailing, 8)
                }
            }
            .freemiumKitColorReset()
#else
            menuButton(title: title, icon: icon, color: color, role: role) {
                if isRecording {
                    // Keep game paused while the ReplayKit preview sheet is shown;
                    // emulation resumes automatically when the preview is dismissed.
                    dismissMenuForSubSheetThen {
                        emulatorVC.stopScreenRecording()
                    }
                } else {
                    dismissAction(true)
                    emulatorVC.startScreenRecording()
                }
            }
#endif
        }
    }
#endif

    // Options related buttons - game settings and enhancements
    private var optionsMenuButtons: some View {
        VStack(spacing: menuSpacing) {
            // Game speed button (yellow = speed/performance)
            menuButton(title: String(localized: "GAME SPEED"), icon: "speedometer", color: .retroYellow) {
                dismissMenuForSubSheetThen {
                    emulatorVC.showSpeedMenu()
                }
            }

            // Performance overlay toggle
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "PERFORMANCE"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))

                menuToggleRow(
                    title: String(localized: "SHOW FPS COUNTER"),
                    icon: "speedometer",
                    color: .retroYellow,
                    isOn: $showFPSCount
                )
            }


                            // Screen filter selection
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "SCREEN FILTER"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))

                Button(action: {
                    // Show filter picker
                    showingFilterPicker = true
                }) {
                    HStack {
                        Text(selectedMetalFilter == .none ? "None" : selectedMetalFilter.description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(palette.defaultTintColor.swiftUIColor)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                    .opacity(palette.dark ? 0.6 : 0.9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(palette.defaultTintColor.swiftUIColor, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                #if os(tvOS)
                .fullScreenCover(isPresented: $showingFilterPicker, onDismiss: {
                }) {
                    filterPickerView
                }
                #else
                .sheet(isPresented: $showingFilterPicker) {
                    filterPickerView
                }
                #endif
                .onAppear {
                    syncSelectedFilterFromSettings()
                }
                .onChange(of: metalFilterMode) { _ in
                    syncSelectedFilterFromSettings()
                }
            }

            #if os(iOS)
            // Audio visualizer button (iOS 16+ only, if supported by core)
            if emulatorVC.core.supportsAudioVisualizer {
                AudioVisualizerButton(emulatorVC: emulatorVC, dismissAction: dismissAction)
            }
            #endif

            // RetroArch settings button (only for libretro cores)
            if emulatorVC.core.coreIdentifier?.contains("libretro") == true,
               PauseMenuViewRegistry.retroArchSettingsView() != nil {
                menuButton(title: String(localized: "RETROARCH SETTINGS"), icon: "gearshape.2", color: .retroCyan) {
                    showingRetroArchSettings = true
                }
                .sheet(isPresented: $showingRetroArchSettings) {
                    PauseMenuViewRegistry.retroArchSettingsView()
                }
            }

            let wantsStartSelectInMenu: Bool = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(emulatorVC.game.system?.identifier ?? SystemIdentifier.RetroArch.rawValue)

            // P1 controls (blue = primary player)
            if let player1 = PVControllerManager.shared.player1 {
#if os(iOS)
                if Defaults[.missingButtonsAlwaysOn] || (player1.extendedGamepad != nil || wantsStartSelectInMenu) {
                    menuButton(title: String(localized: "P1 CONTROLS"), icon: "gamecontroller", color: .retroBlue) {
                        dismissAction(true)
                    }
                }
#else
                if player1.extendedGamepad != nil || wantsStartSelectInMenu {
                    menuButton(title: String(localized: "P1 CONTROLS"), icon: "gamecontroller", color: .retroBlue) {
                        dismissAction(true)
                    }
                }
#endif
            }

            // P2 controls (purple = secondary player)
            if let player2 = PVControllerManager.shared.player2 {
                if player2.extendedGamepad != nil || wantsStartSelectInMenu {
                    menuButton(title: String(localized: "P2 CONTROLS"), icon: "gamecontroller", color: .retroPurple) {
                        dismissAction(true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func menuToggleRow(title: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    .foregroundColor(color)
                    // Neon glow on icon — matches menuButton and AudioVisualizerButton style
                    .shadow(color: color.opacity(0.8), radius: 4, x: 0, y: 0)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Text(isOn.wrappedValue ? "ON" : "OFF")
                    .font(.system(size: isLandscape ? 14 : 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isOn.wrappedValue ? color : Color.gray.opacity(0.6))
            }
            .padding(.vertical, isLandscape ? 10 : 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // Subtle color tint — matches updated menuButton background style
                    .fill(color.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color, lineWidth: 1.5)
                    )
            )
            .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 0)
        }
        .retroFocusButtonStyle(
            focusScale: 1.06,
            cornerRadius: 12,
            primaryColor: color,
            secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? color,
            glowRadius: 10,
            showBorder: false,
            showGlow: true,
            showScale: true
        )
    }

    // Skins and filters related buttons
    @State private var selectedSkin: String = "Default"
    @State private var selectedPortraitSkin: String = "Default"
    @State private var selectedLandscapeSkin: String = "Default"
    @Default(.metalFilterMode) private var metalFilterMode
    @State private var selectedMetalFilter: MetalFilterSelectionOption = .none
    @State private var availableSkins: [String] = ["Default"]
    @State private var availableSkinObjects: [DeltaSkinProtocol] = []
    @State private var showingSkinPicker = false
    @State private var showingFilterPicker = false
    @State private var showingRetroArchSettings = false
    @State private var showingDocumentPicker = false
    @State private var showingSkinCatalog = false
    #if os(iOS)
    @State private var currentOrientation: SkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
    #else
    @State private var currentOrientation: SkinOrientation = .landscape
    #endif
    @State private var isLoadingSkins = false
    @State private var didLoadSkins = false

    // Store the session skin identifiers to preserve them during orientation changes
    @State private var sessionPortraitSkinIdentifier: String? = nil
    @State private var sessionLandscapeSkinIdentifier: String? = nil

    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var isHoveredSkinId: String? = nil

    // Button effect and sound settings
    @Default(.buttonPressEffect) var buttonPressEffect
    @Default(.buttonSound) var buttonSound
    @State internal var showingButtonEffectPicker = false
    @State internal var showingButtonSoundPicker = false
    @State private var showingSaveStateBrowser = false
    @State private var showingScreenshotBrowser = false

    // Scope to save skin selection under (set once, applies to all picks in the session)
    @State private var selectedSkinScope: SkinScope = .game

    private var skinsMenuButtons: some View {
        VStack(spacing: menuSpacing) {
            // Show message if skins are not supported
            if !emulatorVC.core.supportsSkins {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                        .padding(.bottom, 8)

                    Text(String(localized: "SKINS UNDER DEVELOPMENT"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)

                    Text(String(localized: "Skins are not yet supported for this core, but development is in progress."))
                        .font(.system(size: 14))
                        .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                .opacity(palette.dark ? 0.7 : 0.9)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.5 : 0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 8)

                Spacer(minLength: 0)
            } else {
                // ── SKIN SELECTION ──────────────────────────────────────────
                skinSectionHeader(String(localized: "SKIN SELECTION"), systemImage: "paintbrush.pointed")

                // Scope picker — choose where to save the skin BEFORE picking it.
                // This replaces the post-selection alert with an upfront control.
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "SAVE FOR"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.6))
                        .tracking(1.5)

                    Picker("Scope", selection: $selectedSkinScope) {
                        Text("Session").tag(SkinScope.session)
                        Text("This Game").tag(SkinScope.game)
                        Text("System").tag(SkinScope.system)
                    }
                    .pickerStyle(.segmented)
                }

                // Portrait + Landscape selectors — both always visible.
                // Wrapping in a VStack lets us attach the shared sheet here.
                VStack(spacing: 8) {
                    skinOrientationRow(orientation: .portrait)
                    skinOrientationRow(orientation: .landscape)
                }
                .sheet(isPresented: $showingSkinPicker, onDismiss: {
                    if isLoadingSkins { isLoadingSkins = false }
                }) {
                    skinPickerView
                }

                // ── BUTTON CONTROLS ─────────────────────────────────────────
                skinSectionHeader(String(localized: "BUTTON CONTROLS"), systemImage: "hand.tap")

                menuButton(title: String(localized: "BUTTON EFFECT"), icon: "wand.and.sparkles", color: .retroPurple) {
                    showingButtonEffectPicker = true
                }
                .overlay(alignment: .trailing) {
                    Text(buttonPressEffect.description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .padding(.trailing, 38)
                        .allowsHitTesting(false)
                }
                .sheet(isPresented: $showingButtonEffectPicker) {
                    buttonEffectPickerView
                }

                menuButton(title: String(localized: "BUTTON SOUND"), icon: "speaker.wave.2", color: .retroBlue) {
                    showingButtonSoundPicker = true
                }
                .overlay(alignment: .trailing) {
                    Text(buttonSound.description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .padding(.trailing, 38)
                        .allowsHitTesting(false)
                }
                .sheet(isPresented: $showingButtonSoundPicker) {
                    buttonSoundPickerView
                }

                // ── TOOLS ───────────────────────────────────────────────────
                skinSectionHeader(String(localized: "TOOLS"), systemImage: "wrench.and.screwdriver")

                menuButton(title: String(localized: "IMPORT SKIN FILE"), icon: "square.and.arrow.down", color: .retroCyan) {
                    showingDocumentPicker = true
                }
#if !os(tvOS)
                .sheet(isPresented: $showingDocumentPicker) {
                    SkinDocumentPicker { urls in
                        Task { await importSkins(from: urls) }
                    }
                }
#endif

                menuButton(title: String(localized: "BROWSE SKIN CATALOG"), icon: "arrow.down.circle.fill", color: .retroOrange) {
                    showingSkinCatalog = true
                }
                .sheet(isPresented: $showingSkinCatalog, onDismiss: {
                    Task {
                        await MainActor.run { didLoadSkins = false }
                        await loadAvailableSkins()
                    }
                }) {
                    NavigationStack {
                        SkinCatalogBrowserView(
                            preselectedSystem: emulatorVC.game.system?.systemIdentifier.skinCatalogSystemCode ?? nil
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showingSkinCatalog = false }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        // Pre-load skin names as soon as the SKINS tab becomes visible
        .task {
            if !didLoadSkins && !isLoadingSkins {
                await loadAvailableSkins()
            }
        }
    }

    /// Styled section-header label used inside `skinsMenuButtons`.
    @ViewBuilder
    private func skinSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
        }
        .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.55))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    /// A tappable row that opens the skin picker for a specific orientation.
    @ViewBuilder
    private func skinOrientationRow(orientation: SkinOrientation) -> some View {
        let isPortrait = orientation == .portrait
        let skinName   = isPortrait ? selectedPortraitSkin : selectedLandscapeSkin
        let icon       = isPortrait ? "rectangle.portrait" : "rectangle.landscape"
        let color: Color = isPortrait ? .retroBlue : .retroPurple
        let label      = isPortrait ? "PORTRAIT" : "LANDSCAPE"

        Button {
            currentOrientation = orientation
            showingSkinPicker  = true
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.8), radius: 4, x: 0, y: 0)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(color.opacity(0.85))
                        .tracking(1.5)
                    Text(skinName)
                        .font(.system(size: isLandscape ? 15 : 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color.opacity(0.55))
            }
            .padding(.vertical, isLandscape ? 10 : 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color, lineWidth: 1.5)
                    )
            )
            .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 0)
        }
        .retroFocusButtonStyle(
            focusScale: 1.06,
            cornerRadius: 12,
            primaryColor: color,
            secondaryColor: palette.settingsCellBackground?.swiftUIColor ?? color,
            glowRadius: 10,
            showBorder: false,
            showGlow: true,
            showScale: true
        )
    }

    // Skin picker sheet view with retrowave styling
    private var skinPickerView: some View {
        NavigationStack {
            ZStack {
                // Theme-aware background
                Color(palette.gameLibraryBackground)
                    .edgesIgnoringSafeArea(.all)

                // Grid overlay
                RetroGrid(
                    lineSpacing: 20,
                    lineColor: palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.07 : 0.05)
                )
                .opacity(palette.dark ? 0.3 : 0.2)

                // Main content with loading state handling
                VStack {
                    // Header with orientation indicator
                    VStack(spacing: 8) {
                        Text(String(localized: "SELECT SKIN"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(palette.gameLibraryHeaderText.swiftUIColor)
                            .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(glowOpacity), radius: 5, x: 0, y: 0)

                        HStack(spacing: 8) {
                            Image(systemName: currentOrientation == .portrait ? "rectangle.portrait" : "rectangle.landscape")
                                .font(.system(size: 14, weight: .semibold))
                            Text(currentOrientation == .portrait ? "PORTRAIT" : "LANDSCAPE")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                        .opacity(palette.dark ? 0.5 : 0.8)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor, lineWidth: 1)
                                )
                        )
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    // Loading indicator or content
                    if isLoadingSkins {
                        VStack(spacing: 20) {
                            // Custom retrowave loading spinner
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 4)
                                    .foregroundColor((palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(0.5))
                                    .frame(width: 50, height: 50)

                                Circle()
                                    .trim(from: 0, to: 0.75)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                palette.defaultTintColor.swiftUIColor,
                                                (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(Angle(degrees: glowOpacity * 360))
                            }
                            .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(glowOpacity), radius: 5)

                            Text(String(localized: "LOADING SKINS..."))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(palette.defaultTintColor.swiftUIColor)
                                .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(glowOpacity), radius: 3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, 50) // Offset to center visually
                    } else {
                        // Skin content when loaded
                        ScrollView {
                            VStack(spacing: 16) {
                                // Default skin option - always show
                                skinItemView(
                                    name: "Default",
                                    preview: nil,
                                    isSelected: (currentOrientation == .portrait ? selectedPortraitSkin : selectedLandscapeSkin) == "Default",
                                    skinId: nil,
                                    onSelect: {
                                        showingSkinPicker = false
                                        // Apply immediately using the scope already chosen in the SKINS tab
                                        Task { @MainActor in
                                            await applySkinSelection(skinName: "Default", identifier: "", orientation: currentOrientation, scope: selectedSkinScope)
                                            await applySkinAndFilterChanges()
                                        }
                                    }
                                )

                                // Custom skins with previews (filtered by selected orientation)
                                ForEach(availableSkinObjects.filter { skinSupportsOrientation($0, orientation: currentOrientation) }, id: \.identifier) { skin in
                                    SkinPreviewItemView(
                                        skin: skin,
                                        isSelected: (currentOrientation == .portrait ? selectedPortraitSkin : selectedLandscapeSkin) == skin.name,
                                        glowOpacity: glowOpacity,
                                        isHovered: isHoveredSkinId == skin.identifier,
                                        onSelect: {
                                            showingSkinPicker = false
                                            // Apply immediately using the scope already chosen in the SKINS tab
                                            Task { @MainActor in
                                                await applySkinSelection(skinName: skin.name, identifier: skin.identifier, orientation: currentOrientation, scope: selectedSkinScope)
                                                await applySkinAndFilterChanges()
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            #if !os(tvOS)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingSkinPicker = false
                    }) {
                        Text(String(localized: "DONE"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(LinearGradient(
                                        gradient: Gradient(colors: [
                                            (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor),
                                            palette.defaultTintColor.swiftUIColor
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ), lineWidth: 1.5)
                            )
                            .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity), radius: 3, x: 0, y: 0)
                    }
                }
            }
            #endif
                .onAppear {
                // Start animations
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }

                // Always reload to ensure we have the latest selection
                ILOG("skins: skinPickerView onAppear - reloading skins, didLoadSkins: \(didLoadSkins)")
                Task {
                    // Reset didLoadSkins to force reload to get latest preferences
                    await MainActor.run {
                        didLoadSkins = false
                    }
                    await loadAvailableSkins()
                }
            }
        }
    }

    // Custom skin item view for Default option
    private func skinItemView(name: String, preview: UIImage?, isSelected: Bool, skinId: String? = nil, onSelect: @escaping () -> Void) -> some View {
        GeometryReader { geometry in
            Button(action: onSelect) {
                HStack(spacing: geometry.size.width < 350 ? 8 : 16) {
                    // Preview image or placeholder
                    ZStack {
                        if let preview = preview {
                            Image(uiImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width < 350 ? 60 : 80, height: geometry.size.width < 350 ? 60 : 80)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                                                    palette.defaultTintColor.swiftUIColor
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                        .opacity(palette.dark ? 0.5 : 0.7)
                                )
                                .frame(width: geometry.size.width < 350 ? 60 : 80, height: geometry.size.width < 350 ? 60 : 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                                                    palette.defaultTintColor.swiftUIColor
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .overlay(
                                    Image(systemName: "gamecontroller.fill")
                                        .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                        .font(.system(size: geometry.size.width < 350 ? 24 : 30))
                                        .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity), radius: 3, x: 0, y: 0)
                                )
                        }
                    }

                    // Skin name and details
                    VStack(alignment: .leading, spacing: geometry.size.width < 350 ? 4 : 8) {
                        Text(name)
                            .font(.system(size: geometry.size.width < 350 ? 16 : 18, weight: .bold))
                            .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                            .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                            .lineLimit(1)

                        if name != "Default" {
                            Text(String(localized: "Custom Skin"))
                                .font(.system(size: geometry.size.width < 350 ? 12 : 14))
                                .foregroundColor((palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor))
                                .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        } else {
                            Text(String(localized: "System Default"))
                                .font(.system(size: geometry.size.width < 350 ? 12 : 14))
                                .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        }
                    }

                    Spacer()

                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                            .font(.system(size: geometry.size.width < 350 ? 20 : 24))
                            .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity), radius: 3, x: 0, y: 0)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                .opacity(palette.dark ? 0.7 : 0.9)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            isSelected ? palette.defaultTintColor.swiftUIColor : (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor),
                                            (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isHoveredSkinId == skinId || isSelected ? 2.0 : 1.5
                                )
                                .shadow(color: (isSelected ? palette.defaultTintColor.swiftUIColor : (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)).opacity(glowOpacity),
                                        radius: isHoveredSkinId == skinId || isSelected ? 5 : 3,
                                        x: 0,
                                        y: 0)
                        )
                )
#if !os(tvOS)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHoveredSkinId = hovering ? skinId : nil
                    }
                }
                #endif
            }
            .retroFocusButtonStyle(
                focusScale: 1.04,
                cornerRadius: 12,
                primaryColor: palette.defaultTintColor.swiftUIColor,
                secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                glowRadius: 8,
                showBorder: false,  // Row already has its own border
                showGlow: true,
                showScale: true
            )
        }
        .frame(height: UIScreen.main.bounds.width < 350 ? 84 : 104)
    }

    // Skin preview item view with cached image loading
    private struct SkinPreviewItemView: View {
        let skin: DeltaSkinProtocol
        let isSelected: Bool
        let glowOpacity: Double
        let isHovered: Bool
        let onSelect: () -> Void

        @State private var previewImage: UIImage? = nil
        @ObservedObject private var themeManager = ThemeManager.shared

        private var palette: UXThemePalette { themeManager.currentPalette }

        var body: some View {
            GeometryReader { geometry in
                Button(action: onSelect) {
                    HStack {
                        // Preview image or placeholder
                        ZStack {
                            if let preview = previewImage {
                                Image(uiImage: preview)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width < 350 ? 60 : 80, height: geometry.size.width < 350 ? 60 : 80)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                                                        palette.defaultTintColor.swiftUIColor
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                            .opacity(palette.dark ? 0.5 : 0.7)
                                    )
                                    .frame(width: geometry.size.width < 350 ? 60 : 80, height: geometry.size.width < 350 ? 60 : 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                                                        palette.defaultTintColor.swiftUIColor
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .overlay(
                                        Image(systemName: "gamecontroller.fill")
                                            .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                            .font(.system(size: geometry.size.width < 350 ? 24 : 30))
                                            .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity), radius: 3, x: 0, y: 0)
                                    )
                            }
                        }

                        // Skin name and details
                        VStack(alignment: .leading, spacing: geometry.size.width < 350 ? 4 : 8) {
                            Text(skin.name)
                                .font(.system(size: geometry.size.width < 350 ? 16 : 18, weight: .bold))
                                .foregroundColor(palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                                .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                                .lineLimit(1)

                            Text(String(localized: "Custom Skin"))
                                .font(.system(size: geometry.size.width < 350 ? 12 : 14))
                                .foregroundColor((palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor))
                                .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        }

                        Spacer()

                        // Selection indicator
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                .font(.system(size: geometry.size.width < 350 ? 20 : 24))
                                .shadow(color: (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                    .opacity(palette.dark ? 0.7 : 0.9)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                isSelected ? palette.defaultTintColor.swiftUIColor : (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor),
                                                (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isHovered || isSelected ? 2.0 : 1.5
                                    )
                                    .shadow(color: (isSelected ? palette.defaultTintColor.swiftUIColor : (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor)).opacity(glowOpacity),
                                            radius: isHovered || isSelected ? 5 : 3,
                                            x: 0,
                                            y: 0)
                            )
                    )
                }
                .retroFocusButtonStyle(
                    focusScale: 1.04,
                    cornerRadius: 12,
                    primaryColor: palette.defaultTintColor.swiftUIColor,
                    secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                    glowRadius: 8,
                    showBorder: false,  // Row already has its own border
                    showGlow: true,
                    showScale: true
                )
            }
            .frame(height: UIScreen.main.bounds.width < 350 ? 84 : 104)
            .task {
                // Load preview image asynchronously with current device type
                if previewImage == nil {
                    let device: DeltaSkinDevice = {
                        #if os(tvOS)
                        return .tv
                        #else
                        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
                        #endif
                    }()
                    previewImage = await DeltaSkinManager.shared.previewImage(for: skin, device: device)
                }
            }
        }
    }

    // MARK: - Filter Picker Helper Views

    /// Filter option row for the filter picker
    @ViewBuilder
    private func filterOptionRow(for option: MetalFilterSelectionOption, isCompact: Bool) -> some View {
        let isSelected = option == selectedMetalFilter
        let label = option == .none ? "None" : option.description
        let textColor = isSelected
            ? (palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
            : (palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7)
        let bgOpacity = isSelected ? (palette.dark ? 0.4 : 0.6) : (palette.dark ? 0.6 : 0.8)
        let borderColor = isSelected
            ? palette.defaultTintColor.swiftUIColor
            : palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.3 : 0.2)
        let borderWidth: CGFloat = isSelected ? 3 : 1

        Button(action: {
            selectedMetalFilter = option
            applyFilterImmediately(option)
            // Keep the picker open when selecting a filter with editable parameters
            if !option.hasEditableParameters {
                showingFilterPicker = false
            }
        }) {
            filterOptionContent(label: label, isSelected: isSelected, textColor: textColor, isCompact: isCompact)
                .background(filterOptionBackground(bgOpacity: bgOpacity, borderColor: borderColor, borderWidth: borderWidth))
        }
        .retroFocusButtonStyle(
            focusScale: 1.04,
            cornerRadius: 12,
            primaryColor: palette.defaultTintColor.swiftUIColor,
            secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
            glowRadius: 8,
            showBorder: false,  // Row already has its own border
            showGlow: true,
            showScale: true
        )
    }

    @ViewBuilder
    private func filterOptionContent(label: String, isSelected: Bool, textColor: Color, isCompact: Bool) -> some View {
        HStack {
            Text(label)
                #if os(tvOS)
                .font(.system(size: 28, weight: .bold))
                #else
                .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                #endif
                .foregroundColor(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    #if os(tvOS)
                    .font(.system(size: 32))
                    #else
                    .font(.system(size: 20))
                    #endif
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }
        }
        #if os(tvOS)
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        #else
        .padding(.vertical, isLandscape ? 8 : 12)
        .padding(.horizontal, 20)
        #endif
    }

    @ViewBuilder
    private func filterOptionBackground(bgOpacity: Double, borderColor: Color, borderWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill((palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(bgOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
    }

    /// Returns the parameter editor view for the given Metal filter.
    @ViewBuilder
    private func shaderParametersSection(for filter: MetalFilterSelectionOption) -> some View {
        switch filter {
        case .simpleCRT:
            SimpleCRTParametersView(palette: palette)
        case .complexCRT:
            ComplexCRTParametersView(palette: palette)
        case .lcd:
            LCDParametersView(palette: palette)
        case .megaTron:
            MegaTronParametersView(palette: palette)
        case .ulTron:
            UlTronParametersView(palette: palette)
        case .gameBoy:
            GameBoyParametersView(palette: palette)
        case .vhs:
            VHSParametersView(palette: palette)
        case .none:
            EmptyView()
        }
    }

    /// Done button for filter picker
    @ViewBuilder
    private var filterPickerDoneButton: some View {
        let buttonGradient = LinearGradient(
            gradient: Gradient(colors: [
                palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
                palette.defaultTintColor.swiftUIColor
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        let textColor = palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor
        let shadowColor = (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(0.5)

        Button(action: { showingFilterPicker = false }) {
            Text("DONE")
                #if os(tvOS)
                .font(.system(size: 28, weight: .bold))
                .padding(.vertical, 24)
                #else
                .font(.system(size: 18, weight: .bold))
                .padding(.vertical, 16)
                #endif
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(buttonGradient))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(textColor.opacity(0.5), lineWidth: 1))
                .shadow(color: shadowColor, radius: 8, x: 0, y: 0)
        }
        .retroFocusButtonStyle(
            focusScale: 1.05,
            cornerRadius: 12,
            primaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
            secondaryColor: palette.defaultTintColor.swiftUIColor,
            glowRadius: 10,
            showBorder: false,  // Button already has its own border
            showGlow: true,
            showScale: true
        )
        #if os(tvOS)
        .padding(.horizontal, 30)
        .padding(.bottom, 50)
        #else
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
        #endif
    }

    // Filter picker sheet view
    private var filterPickerView: some View {
        #if os(tvOS)
        NavigationStack {
            SwiftUI.Form(content: {
                tvOSFilterPickerContent
            })
            .navigationTitle("Screen Filters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingFilterPicker = false
                    }
                    .font(.headline)
                }
            }
        }
        .onAppear { syncSelectedFilterFromSettings() }
        .onChange(of: selectedMetalFilter) { newValue in
            applyFilterImmediately(newValue)
        }
        #else
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 400

            ZStack {
                // Theme-aware background
                Color(palette.gameLibraryBackground)
                    .edgesIgnoringSafeArea(.all)

                // Grid overlay
                RetroGrid(
                    lineSpacing: 20,
                    lineColor: palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.1 : 0.05)
                )
                .opacity(palette.dark ? 0.3 : 0.2)

                // Content
                filterPickerContent(geometry: geometry, isCompact: isCompact)
            }
        }
        .edgesIgnoringSafeArea(.all)
        #endif
    }

    #if os(tvOS)
    @ViewBuilder
    private var tvOSFilterPickerContent: some View {
        SwiftUI.Section {
            SwiftUI.Picker("Screen Filter", selection: $selectedMetalFilter) {
                ForEach(MetalFilterSelectionOption.allCases, id: \.self) { option in
                    Text(option == .none ? "None" : option.description)
                        .tag(option)
                }
            }
            .pickerStyle(.navigationLink)
        }

        if selectedMetalFilter != .none {
            SwiftUI.Section {
                FilterPreviewBarsView(filter: selectedMetalFilter, palette: palette)
            }

            SwiftUI.Section {
                shaderParametersSection(for: selectedMetalFilter)
            }
        }
    }
    #endif

    @ViewBuilder
    private func filterPickerContent(geometry: GeometryProxy, isCompact: Bool) -> some View {
        let headerShadow = palette.defaultTintColor.swiftUIColor.opacity(palette.dark ? 0.8 : 0.5)
        let containerBg = (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(palette.dark ? 0.7 : 0.95)

        #if os(tvOS)
        // tvOS: Center content with generous sizing
        HStack {
            Spacer()
            VStack(spacing: 0) {
                // Header
                Text("SCREEN FILTERS")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .padding(.top, 80)
                    .padding(.bottom, 40)
                    .foregroundColor(palette.gameLibraryHeaderText.swiftUIColor)
                    .shadow(color: headerShadow, radius: 10, x: 0, y: 0)

                // Filter options - larger for TV
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(MetalFilterSelectionOption.allCases, id: \.self) { option in
                            filterOptionRow(for: option, isCompact: false)
                        }

                        // Show shader parameters for the selected filter
                        if selectedMetalFilter.hasEditableParameters {
                            Rectangle()
                                .fill(palette.defaultTintColor.swiftUIColor.opacity(0.5))
                                .frame(height: 1)
                                .padding(.vertical, 8)

                            FilterPreviewBarsView(filter: selectedMetalFilter, palette: palette)
                                .padding(.bottom, 4)

                            shaderParametersSection(for: selectedMetalFilter)
                        }
                    }
                    .padding(.horizontal, 60)
                }
                .frame(maxWidth: 900)

                Spacer()

                // Done button
                filterPickerDoneButton
                    .padding(.bottom, 60)
            }
            .frame(width: min(1000, geometry.size.width * 0.6))
            .background(containerBg)
            .cornerRadius(24)
            .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(0.4), radius: 30)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        VStack(spacing: 0) {
            // Header
            Text("SCREEN FILTERS")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .padding(.top, 30)
                .padding(.bottom, 20)
                .foregroundColor(palette.gameLibraryHeaderText.swiftUIColor)
                .shadow(color: headerShadow, radius: 10, x: 0, y: 0)

            // Filter options and shader parameters
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(MetalFilterSelectionOption.allCases, id: \.self) { option in
                        filterOptionRow(for: option, isCompact: isCompact)
                    }

                    // Show shader parameters for the selected filter
                    if selectedMetalFilter.hasEditableParameters {
                        Rectangle()
                            .fill(palette.defaultTintColor.swiftUIColor.opacity(0.5))
                            .frame(height: 1)
                            .padding(.vertical, 8)

                        FilterPreviewBarsView(filter: selectedMetalFilter, palette: palette)
                            .padding(.bottom, 4)

                        shaderParametersSection(for: selectedMetalFilter)
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Done button
            filterPickerDoneButton
        }
        .frame(
            width: isLandscape ? min(400, geometry.size.width * 0.8) : min(500, geometry.size.width * 0.9),
            height: isLandscape ? geometry.size.height * 0.9 : min(700, geometry.size.height * 0.85)
        )
        .background(containerBg)
        .cornerRadius(20)
        .shadow(color: palette.defaultTintColor.swiftUIColor.opacity(0.3), radius: 20)
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        #endif
    }

    // Load available skins for the current system
    private func loadAvailableSkins() async {
        // Prevent multiple concurrent loads or reloading if already loaded
        guard !isLoadingSkins && !didLoadSkins else {
            // If we're already loaded but the skin picker was dismissed and reopened,
            // make sure we're not stuck in a loading state
            if didLoadSkins && isLoadingSkins {
                await MainActor.run {
                    isLoadingSkins = false
                }
            }
            return
        }
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }

        // Set loading flag to prevent loops
        await MainActor.run {
            isLoadingSkins = true
        }

        do {
            // Get skins from DeltaSkinManager
            let allSkins = try await DeltaSkinManager.shared.skins(for: systemId)

            // Filter skins to only show those that support the current device (iPad on iPad, iPhone on iPhone)
            let filteredSkins = allSkins.filter { skin in
                return skinSupportsCurrentDevice(skin)
            }

            // Update the available skins list on the main thread
            await MainActor.run {
                // Store the actual skin objects for previews (filtered by device support)
                self.availableSkinObjects = filteredSkins

                // Create a set of unique skin names to avoid duplicates
                var uniqueSkinNames = Set<String>()
                uniqueSkinNames.insert("Default")

                // Add names of available skins, avoiding duplicates
                for skin in filteredSkins {
                    uniqueSkinNames.insert(skin.name)
                }

                // Convert to array and sort
                self.availableSkins = Array(uniqueSkinNames).sorted()

                // Start animations for retrowave effects
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    self.glowOpacity = 1.0
                }

                // Mark as loaded and reset loading flag
                self.didLoadSkins = true
                self.isLoadingSkins = false
            }

            // Set current selection for both orientations - use centralized selection manager
            let gameId = emulatorVC.game.md5Hash ?? emulatorVC.game.crc

            // Load portrait selection - use centralized selection manager
            let portraitSkinId: String?
            if !gameId.isEmpty {
                portraitSkinId = await MainActor.run {
                    DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
                        for: systemId,
                        gameId: gameId,
                        orientation: .portrait
                    )
                }
                ILOG("skins: loadAvailableSkins - portrait effectiveGameSkinIdentifier for gameId \(gameId): \(portraitSkinId ?? "nil")")
            } else {
                portraitSkinId = await MainActor.run {
                    DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                        for: systemId,
                        gameId: nil,
                        orientation: .portrait
                    )
                }
                ILOG("skins: loadAvailableSkins - portrait effectiveSkinIdentifier: \(portraitSkinId ?? "nil")")
            }

            await MainActor.run {
                if let portraitSkinId = portraitSkinId,
                   let portraitSkin = filteredSkins.first(where: { $0.identifier == portraitSkinId }) {
                    self.selectedPortraitSkin = portraitSkin.name
                    ILOG("skins: loadAvailableSkins - set portrait skin to: \(portraitSkin.name)")
                } else {
                    self.selectedPortraitSkin = "Default"
                    ILOG("skins: loadAvailableSkins - set portrait skin to: Default")
                }
            }

                    // Load landscape selection - use centralized selection manager
                    let landscapeSkinId: String?
                    if !gameId.isEmpty {
                        landscapeSkinId = await MainActor.run {
                            DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
                                for: systemId,
                                gameId: gameId,
                                orientation: .landscape
                            )
                        }
                        ILOG("skins: loadAvailableSkins - landscape effectiveGameSkinIdentifier for gameId \(gameId): \(landscapeSkinId ?? "nil")")
                    } else {
                        landscapeSkinId = await MainActor.run {
                            DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                                for: systemId,
                                gameId: nil,
                                orientation: .landscape
                            )
                        }
                        ILOG("skins: loadAvailableSkins - landscape effectiveSkinIdentifier: \(landscapeSkinId ?? "nil")")
                    }

            await MainActor.run {
                if let landscapeSkinId = landscapeSkinId,
                   let landscapeSkin = filteredSkins.first(where: { $0.identifier == landscapeSkinId }) {
                    self.selectedLandscapeSkin = landscapeSkin.name
                    ILOG("skins: loadAvailableSkins - set landscape skin to: \(landscapeSkin.name)")
                } else {
                    self.selectedLandscapeSkin = "Default"
                    ILOG("skins: loadAvailableSkins - set landscape skin to: Default")
                }
            }
        } catch {
            print("Error loading skins: \(error)")
            // Reset loading flag even if there's an error, but don't mark as loaded
            await MainActor.run {
                isLoadingSkins = false
                // We don't set didLoadSkins = true here to allow retry on next appearance
            }
        }
    }



    /// Get the current device type
    private var currentDevice: DeltaSkinDevice {
        #if os(tvOS)
        return .tv
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }

    /// Check if a skin supports the current device (iPad on iPad, iPhone on iPhone)
    /// This is stricter than skinSupportsOrientation - it only checks the current device, no fallback
    private func skinSupportsCurrentDevice(_ skin: DeltaSkinProtocol) -> Bool {
        let device = currentDevice
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        let orientations: [SkinOrientation] = [.portrait, .landscape]

        // Check if skin supports at least one orientation for the current device
        for orientation in orientations {
            for display in displayTypes {
                let traits = DeltaSkinTraits(
                    device: device,
                    displayType: display,
                    orientation: orientation.deltaSkinOrientation
                )
                if skin.supports(traits) { return true }
            }
        }
        return false
    }

    /// Check if a skin supports a given orientation for the current device
    private func skinSupportsOrientation(_ skin: DeltaSkinProtocol, orientation: SkinOrientation) -> Bool {
        let device = currentDevice
        // Try multiple display types and devices to robustly detect support
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        for display in displayTypes {
            let traits = DeltaSkinTraits(
                device: device,
                displayType: display,
                orientation: orientation.deltaSkinOrientation
            )
            if skin.supports(traits) { return true }
        }
        return false
    }

    /// Import skins from URLs
    private func importSkins(from urls: [URL]) async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }

        for url in urls {
            do {
                // Import the skin archive
                try await DeltaSkinManager.shared.importSkin(from: url)

                // Reload skins so the newly imported skin is available for immediate selection/application
                await DeltaSkinManager.shared.reloadSkins()

                // Reload available skins in the picker UI
                await MainActor.run {
                    didLoadSkins = false
                }

                // Optionally show a success notification that the skin was imported;
                // the most recently imported skin will be applied automatically using the current SKINS tab scope.
                await MainActor.run {
                    // e.g. present a toast/banner if desired
                }
            } catch {
                ELOG("Failed to import skin from \(url.lastPathComponent): \(error)")
            }
        }

        // After importing, automatically apply the most recently imported skin immediately,
        // using whichever scope is currently selected in the SKINS tab (no separate Apply button step).
        if let skins = try? await DeltaSkinManager.shared.skins(for: systemId),
           let lastImported = skins.last {
            ILOG("skins: Auto-applying imported skin '\(lastImported.name)' (\(lastImported.identifier ?? "no identifier")) with scope \(selectedSkinScope)")
            await applySkinSelection(
                skinName: lastImported.name,
                identifier: lastImported.identifier,
                orientation: currentOrientation,
                scope: selectedSkinScope
            )
            await applySkinAndFilterChanges()
        }
    }

    /// Apply skin selection with specified scope
    /// Uses centralized DeltaSkinSelectionManager for all logic
    private func applySkinSelection(skinName: String, identifier: String? = nil, orientation: SkinOrientation, scope: SkinScope) async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else {
            ELOG("skins: applySkinSelection failed - no systemId")
            return
        }

        let gameId: String? = emulatorVC.game.md5Hash ?? emulatorVC.game.crc
        ILOG("skins: applySkinSelection called - skin: \(skinName), identifier: \(identifier ?? "nil"), orientation: \(orientation.rawValue), scope: \(scope.rawValue), systemId: \(systemId.rawValue), gameId: \(gameId ?? "nil")")

        do {
            let skinIdentifier: String?

            if skinName != "Default" {
                // Find the skin by identifier if provided, otherwise by name
                let skins = try await DeltaSkinManager.shared.skins(for: systemId)
                let skin: DeltaSkinProtocol?
                if let identifier = identifier, !identifier.isEmpty {
                    skin = skins.first(where: { $0.identifier == identifier })
                } else {
                    skin = skins.first(where: { $0.name == skinName })
                }

                guard let skin = skin,
                      let emulatorVC = emulatorVC as? PVEmulatorViewController else {
                    return
                }

                // Check if skin supports the selected orientation
                let supportsSelectedOrientation = skinSupportsOrientation(skin, orientation: orientation)

                if !supportsSelectedOrientation {
                    // Skin doesn't support the selected orientation
                    await MainActor.run {
                        if orientation == .portrait {
                            selectedPortraitSkin = "Default"
                        } else {
                            selectedLandscapeSkin = "Default"
                        }
                    }
                    return
                }

                skinIdentifier = skin.identifier

                // Use centralized selection manager - handles all scope logic including session updates
                await MainActor.run {
                    DeltaSkinSelectionManager.shared.setSkin(
                        skinIdentifier,
                        for: systemId,
                        gameId: gameId,
                        orientation: orientation,
                        scope: scope
                    )

                    // Update local session tracking for UI
                    if orientation == .portrait {
                        sessionPortraitSkinIdentifier = skinIdentifier
                    } else {
                        sessionLandscapeSkinIdentifier = skinIdentifier
                    }

                    // Update UI display immediately
                    if orientation == .portrait {
                        selectedPortraitSkin = skin.name
                    } else {
                        selectedLandscapeSkin = skin.name
                    }
                    // Force reload on next open
                    didLoadSkins = false
                }

                // Don't apply skin immediately - wait for apply button to be clicked
                ILOG("skins: Skin preference saved, will be applied when Apply button is clicked")
            } else {
                // User selected "Default" skin - clear selection
                skinIdentifier = nil

                guard let emulatorVC = emulatorVC as? PVEmulatorViewController else {
                    return
                }

                // Use centralized selection manager to clear
                await MainActor.run {
                    DeltaSkinSelectionManager.shared.setSkin(
                        nil,
                        for: systemId,
                        gameId: gameId,
                        orientation: orientation,
                        scope: scope
                    )

                    // Update local session tracking
                    if orientation == .portrait {
                        sessionPortraitSkinIdentifier = nil
                    } else {
                        sessionLandscapeSkinIdentifier = nil
                    }

                    // Update UI display immediately
                    if orientation == .portrait {
                        selectedPortraitSkin = "Default"
                    } else {
                        selectedLandscapeSkin = "Default"
                    }
                    // Force reload on next open
                    didLoadSkins = false
                }

                // Don't reset skin immediately - wait for apply button to be clicked
                ILOG("skins: Default skin preference saved, will be applied when Apply button is clicked")
            }
        } catch {
            ELOG("Error applying skin selection: \(error)")
        }
    }

    /// Apply skin and filter changes after menu is dismissed
    /// This ensures the game doesn't unpause while the menu is still open
    private func applySkinAndFilterChanges() async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier,
              let emulatorVC = emulatorVC as? PVEmulatorViewController else {
            return
        }

        let gameId = emulatorVC.game.md5Hash ?? emulatorVC.game.crc

        // Apply filter changes immediately
        applyFilterImmediately(selectedMetalFilter)

        // Apply skin for current orientation using effective skin identifier
        #if !os(tvOS)
        let currentOrientation = UIDevice.current.orientation.isLandscape ? SkinOrientation.landscape : .portrait
        #else
        let currentOrientation = SkinOrientation.landscape
        #endif

        do {
            // Get effective skin identifier for current orientation
            let skinId: String? = await MainActor.run {
                if !gameId.isEmpty {
                    return DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
                        for: systemId,
                        gameId: gameId,
                        orientation: currentOrientation
                    )
                } else {
                    return DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                        for: systemId,
                        gameId: nil,
                        orientation: currentOrientation
                    )
                }
            }

            if let skinId = skinId {
                // Find and apply the skin with fallback support
                let skins = try await DeltaSkinManager.shared.skins(for: systemId)
                if let skin = skins.first(where: { $0.identifier == skinId }) {
                    ILOG("skins: Applying skin '\(skin.name)' for current orientation (\(currentOrientation.rawValue))")
                    // applySkin will automatically handle fallback if skin doesn't support orientation
                    try await emulatorVC.applySkin(skin)
                } else {
                    ILOG("skins: Skin with identifier '\(skinId)' not found, resetting to default")
                    try await emulatorVC.resetToDefaultSkin()
                }
            } else {
                // No skin preference, reset to default
                ILOG("skins: No skin preference for current orientation, resetting to default")
                try await emulatorVC.resetToDefaultSkin()
            }
        } catch {
            ELOG("Error applying skin and filter changes: \(error)")
        }
    }

    /// Apply filter immediately when selected
    private func applyFilterImmediately(_ filter: MetalFilterSelectionOption) {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }

        let gameId = emulatorVC.game.md5Hash ?? emulatorVC.game.crc

        // Update global Metal filter mode
        if filter == .none {
            metalFilterMode = .none
        } else {
            metalFilterMode = .always(filter: filter)
        }

        // Apply filter changes for skin overlays via notification and legacy preferences
        let overlayName = overlayFilterName(for: filter)

        if filter != .none {
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyScreenFilter"),
                object: nil,
                userInfo: ["filterName": overlayName]
            )

            if !gameId.isEmpty {
                UserDefaults.standard.set(overlayName, forKey: "ScreenFilter_Game_\(gameId)")
            } else {
                UserDefaults.standard.set(overlayName, forKey: "ScreenFilter_System_\(systemId.rawValue)")
            }
        } else {
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyScreenFilter"),
                object: nil,
                userInfo: ["filterName": "None"]
            )

            if !gameId.isEmpty {
                UserDefaults.standard.removeObject(forKey: "ScreenFilter_Game_\(gameId)")
            } else {
                UserDefaults.standard.removeObject(forKey: "ScreenFilter_System_\(systemId.rawValue)")
            }
        }
    }

    /// Map a Metal filter selection to the legacy string name used by skin overlays
    private func overlayFilterName(for filter: MetalFilterSelectionOption) -> String {
        switch filter {
        case .none:
            return "None"
        case .lcd:
            return "LCD"
        case .gameBoy:
            return "Game Boy"
        case .simpleCRT, .complexCRT, .megaTron, .ulTron, .vhs:
            return "CRT"
        }
    }

    /// Keep in-menu filter selection in sync with the global Metal filter mode
    private func syncSelectedFilterFromSettings() {
        switch metalFilterMode {
        case .none:
            selectedMetalFilter = .none
        case .always(filter: let filter):
            selectedMetalFilter = filter
        case .auto(crt: let crt, lcd: let lcd):
            if crt != .none {
                selectedMetalFilter = crt
            } else if lcd != .none {
                selectedMetalFilter = lcd
            } else {
                selectedMetalFilter = .none
            }
        }
    }

    /// Reapply a session skin after orientation change
    private func reapplySessionSkin(skinId: String, orientation: SkinOrientation) async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }

        do {
            // Get all available skins
            let skins = try await DeltaSkinManager.shared.skins(for: systemId)

            // Find the skin by identifier
            if let skin = skins.first(where: { $0.identifier == skinId }) {
                // Update the selected skin name to match
                await MainActor.run {
                    if orientation == .portrait {
                        selectedPortraitSkin = skin.name
                    } else {
                        selectedLandscapeSkin = skin.name
                    }
                }

                // Update the session skin in DeltaSkinManager for the new orientation
                DeltaSkinManager.shared.setSessionSkin(skinId, for: systemId, orientation: orientation)

                let gameId = emulatorVC.game.md5Hash ?? emulatorVC.game.crc
                DeltaSkinManager.shared.setSessionSkin(skinId, for: systemId, gameId: gameId, orientation: orientation)

                // Apply the skin directly without changing preferences
                if let emulatorVC = emulatorVC as? PVEmulatorViewController {
                    try await emulatorVC.applySkin(skin)
                }
            }
        } catch {
            ELOG("Error reapplying session skin: \(error)")
        }
    }

    /// Apply skin for current orientation using centralized selection manager
    private func applySkinForCurrentOrientation() async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }

        #if !os(tvOS)
        let orientation = UIDevice.current.orientation.isLandscape ? SkinOrientation.landscape : .portrait
        #else
        let orientation = SkinOrientation.landscape
        #endif

        do {
            let gameId = emulatorVC.game.md5Hash ?? emulatorVC.game.crc

            // Use centralized selection manager for effective skin lookup
            let skinId: String? = await MainActor.run {
                if !gameId.isEmpty {
                    return DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
                        for: systemId,
                        gameId: gameId,
                        orientation: orientation
                    )
                } else {
                    return DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                        for: systemId,
                        gameId: nil,
                        orientation: orientation
                    )
                }
            }

            if let skinId = skinId {
                let skins = try await DeltaSkinManager.shared.skins(for: systemId)
                if let skin = skins.first(where: { $0.identifier == skinId }),
                   let emulatorVC = emulatorVC as? PVEmulatorViewController {
                    // Update UI
                    await MainActor.run {
                        if orientation == .portrait {
                            selectedPortraitSkin = skin.name
                        } else {
                            selectedLandscapeSkin = skin.name
                        }
                    }
                    // Apply skin
                    try await emulatorVC.applySkin(skin)
                }
            } else {
                // No preference, reset to default
                if let emulatorVC = emulatorVC as? PVEmulatorViewController {
                    try await emulatorVC.resetToDefaultSkin()
                }
                await MainActor.run {
                    if orientation == .portrait {
                        selectedPortraitSkin = "Default"
                    } else {
                        selectedLandscapeSkin = "Default"
                    }
                }
            }
        } catch {
            ELOG("Error applying skin for current orientation: \(error)")
        }
    }

    // Helper function for category buttons in the header
    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(
                        isSelected
                            ? (palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
                            : (palette.settingsCellText?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.6)
                    )

                // Indicator line
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? palette.defaultTintColor.swiftUIColor : .clear)
            }
            .frame(height: 40)
            .padding(.horizontal, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(palette.dark ? 0.2 : 0.1),
                                (palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor).opacity(palette.dark ? 0.5 : 0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(8)
        }
        .retroFocusButtonStyle(
            focusScale: 1.05,
            focusBorderWidth: 2,
            cornerRadius: 8,
            primaryColor: palette.defaultTintColor.swiftUIColor,
            secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? palette.defaultTintColor.swiftUIColor,
            glowRadius: 6
        )
    }

    // Helper function to create menu buttons.
    // Each button carries a semantic `role` that drives visual weight:
    //   .primary    — bold fill + strong glow (e.g. Resume)
    //   .destructive — red tinted fill + intense glow (e.g. Quit, Reset)
    //   .secondary  — subtle tint, standard weight (all other actions)
    // (modelled after AudioVisualizerButton's accent-color glow reference style)
    private enum MenuButtonRole {
        case primary, secondary, destructive
    }

    private func menuButton(
        title: String,
        icon: String,
        color: Color,
        role: MenuButtonRole = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        struct MenuButtonVisualConfig {
            let iconGlowRadius: CGFloat
            let outerGlowRadius: CGFloat
            let outerGlowOpacity: Double
            let borderWidth: CGFloat
            let backgroundTint: Double
            let titleWeight: Font.Weight
        }

        // Visual tuning per role
        let config: MenuButtonVisualConfig
        switch role {
        case .destructive:
            config = MenuButtonVisualConfig(
                iconGlowRadius: 8,
                outerGlowRadius: 12,
                outerGlowOpacity: 0.6,
                borderWidth: 2.0,
                backgroundTint: 0.18,
                titleWeight: .bold
            )
        case .primary:
            config = MenuButtonVisualConfig(
                iconGlowRadius: 6,
                outerGlowRadius: 10,
                outerGlowOpacity: 0.5,
                borderWidth: 2.0,
                backgroundTint: 0.14,
                titleWeight: .heavy
            )
        case .secondary:
            config = MenuButtonVisualConfig(
                iconGlowRadius: 4,
                outerGlowRadius: 6,
                outerGlowOpacity: 0.3,
                borderWidth: 1.5,
                backgroundTint: 0.08,
                titleWeight: .bold
            )
        }

        let buttonRole: ButtonRole? = role == .destructive ? .destructive : nil

        return Button(role: buttonRole, action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    .foregroundColor(color)
                    // Neon glow on icon — matches AudioVisualizerButton reference style
                    .shadow(color: color.opacity(0.9), radius: config.iconGlowRadius, x: 0, y: 0)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: isLandscape ? 16 : 18, weight: config.titleWeight))
                    .foregroundColor(role == .destructive ? color : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: isLandscape ? 12 : 14))
                    .foregroundColor(color.opacity(0.7))
            }
            .padding(.vertical, isLandscape ? 10 : 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // Subtle color tint in background — differentiates buttons at a glance
                    .fill(color.opacity(config.backgroundTint))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color, lineWidth: config.borderWidth)
                    )
            )
            .shadow(color: color.opacity(config.outerGlowOpacity), radius: config.outerGlowRadius, x: 0, y: 0)
        }
        .retroFocusButtonStyle(
            focusScale: 1.06,
            cornerRadius: 12,
            primaryColor: color,
            secondaryColor: palette.settingsHeaderText?.swiftUIColor ?? color,
            glowRadius: 10,
            showBorder: false,  // Button already has its own border
            showGlow: true,
            showScale: true
        )
    }
}

/// Document picker specifically for skin files (.deltaskin, .manicskin)
#if !os(tvOS)
private struct SkinDocumentPicker: UIViewControllerRepresentable {
    let onImport: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Support both .deltaskin and .manicskin in file and package forms
        var skinTypes: [UTType] = []

        // Prefer explicit identifiers if the system recognizes them
        skinTypes.append(UTType.deltaSkin)
        skinTypes.append(UTType.deltaAppSkin)
        skinTypes.append(UTType.manicSkin)

        // Accept files with these extensions (generic data)
        if let deltaskinData = UTType(filenameExtension: "deltaskin", conformingTo: .data) {
            skinTypes.append(deltaskinData)
        }
        if let manicData = UTType(filenameExtension: "manicskin", conformingTo: .data) {
            skinTypes.append(manicData)
        }

        // Accept package (directory bundle) variants (some providers surface bundles)
        if let deltaskinPackage = UTType(filenameExtension: "deltaskin", conformingTo: .package) {
            skinTypes.append(deltaskinPackage)
        }
        if let manicPackage = UTType(filenameExtension: "manicskin", conformingTo: .package) {
            skinTypes.append(manicPackage)
        }

        // IMPORTANT: Accept archive-conforming variants (these are actually ZIPs with custom extensions)
        if let deltaskinArchive = UTType(filenameExtension: "deltaskin", conformingTo: .archive) {
            skinTypes.append(deltaskinArchive)
        }
        if let manicArchive = UTType(filenameExtension: "manicskin", conformingTo: .archive) {
            skinTypes.append(manicArchive)
        }

        // Also allow generic archives (some skins are zipped variants)
        skinTypes.append(.archive)

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: skinTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: ([URL]) -> Void

        init(onImport: @escaping ([URL]) -> Void) {
            self.onImport = onImport
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onImport(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled, do nothing
        }
    }
}
#endif

// MARK: - Pause-menu screenshot browser

/// Screenshot gallery presented as a sheet from the pause menu.
///
/// Shows all captured screenshots for the current game with share and delete
/// actions. The auto-add-to-Photo-Library toggle maps to the
/// `saveScreenshotsToPhotoLibrary` setting.
@MainActor
struct PauseMenuScreenshotBrowserView: View {
    let emulatorVC: PVEmulatorViewController
    let onDismiss: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var screenshots: [PVImageFile] = []
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @Default(.saveScreenshotsToPhotoLibrary) private var saveToPhotos

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        NavigationView {
            Group {
                if screenshots.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
                        Text("No Screenshots")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.6))
                        Text("Use \"Save Screenshot\" from the pause menu to capture screenshots.")
                            .font(.caption)
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Auto-save toggle at the top
                        Toggle(isOn: $saveToPhotos) {
                            Label("Auto-Save to Photos", systemImage: "photo.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(palette.gameLibraryText.swiftUIColor)
                        }
                        .tint(palette.defaultTintColor.swiftUIColor)
                        .listRowBackground(
                            (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(0.8)
                        )

                        ForEach(screenshots, id: \.partialPath) { shot in
                            screenshotRow(shot)
                                .listRowBackground(
                                    (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(0.8)
                                )
                        }
                        .onDelete { indexSet in
                            for index in indexSet { deleteScreenshot(screenshots[index]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(palette.gameLibraryBackground))
            .navigationTitle("Screenshots")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { onDismiss() }.font(.headline)
                }
            }
#endif
        }
#if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
#endif
        .onAppear { reload() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Row

    @ViewBuilder
    private func screenshotRow(_ shot: PVImageFile) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let url = shot.url, let img = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
                }
            }
            .frame(width: 96, height: 72)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(0.2), lineWidth: 0.5)
            )

            // Filename / date
            VStack(alignment: .leading, spacing: 4) {
                Text(shot.url?.deletingPathExtension().lastPathComponent ?? shot.partialPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(palette.gameLibraryText.swiftUIColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            // Share button
            Button {
                if let url = shot.url, let img = UIImage(contentsOfFile: url.path) {
                    shareItems = [img]
                    showingShareSheet = true
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func reload() {
        screenshots = Array(emulatorVC.game.screenShots.sorted(byKeyPath: "partialPath", ascending: false))
    }

    private func deleteScreenshot(_ shot: PVImageFile) {
        do {
            if let url = shot.url { try? FileManager.default.removeItem(at: url) }
            try RomDatabase.sharedInstance.delete(shot)
            reload()
        } catch {
            ELOG("Failed to delete screenshot: \(error)")
        }
    }
}

// MARK: - Pause-menu save state browser

/// Lightweight SwiftUI save-state picker presented as a sheet from the pause menu.
///
/// The caller provides an `onAction` closure that receives an optional frozen `PVSaveState`:
/// - `nil` → user dismissed without loading (sheet can close, pause menu stays open)
/// - non-nil → load the state (sheet should close AND pause menu should dismiss)
///
/// This view intentionally stays within the app's SwiftUI stack so that
/// dismissing it (without loading) returns the user to the pause menu rather than
/// abandoning it entirely.
@MainActor
struct PauseMenuSaveStateBrowserView: View {
    let emulatorVC: PVEmulatorViewController
    /// Called with a frozen `PVSaveState` to load, or `nil` to just close the sheet.
    let onAction: (PVSaveState?) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var saveStates: [PVSaveState] = []

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        NavigationView {
            Group {
                if saveStates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 48))
                            .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
                        Text("No Save States")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.6))
                        Text("Use \"Save State\" from the pause menu to create saves.")
                            .font(.caption)
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(saveStates, id: \.id) { state in
                            saveStateRow(state)
                                .listRowBackground(
                                    (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground))
                                        .opacity(0.8)
                                )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                deleteSaveState(saveStates[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(palette.gameLibraryBackground))
            .navigationTitle("Save States")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        onAction(nil)
                    }
                    .font(.headline)
                }
            }
#endif
        }
        .onAppear { reload() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Row

    @ViewBuilder
    private func saveStateRow(_ state: PVSaveState) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView(for: state)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if state.isAutosave {
                        Label("Auto", systemImage: "clock.badge.checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.7))
                    }
                    Text(state.date, style: .date)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.gameLibraryText.swiftUIColor)
                }
                HStack(spacing: 4) {
                    Text(state.date, style: .time)
                        .font(.system(size: 11, design: .monospaced))
                    Text("·")
                    (Text(state.date, style: .relative) + Text(" ago"))
                        .font(.system(size: 11))
                }
                .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.55))

                if let coreName = state.core?.projectName {
                    Text(coreName)
                        .font(.system(size: 10))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.5))
                }
            }

            Spacer()

            // Load button
            Button {
                let frozen = state.isFrozen ? state : state.freeze()
                onAction(frozen)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailView(for state: PVSaveState) -> some View {
        Group {
            if let imageURL = state.image?.url, let uiImage = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
            }
        }
        .frame(width: 72, height: 54)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func reload() {
        guard let game = emulatorVC.game, !game.isInvalidated else {
            saveStates = []
            return
        }
        // Refresh the Realm to pick up writes from other threads/contexts
        // (e.g., registerSaveState which opens its own Realm instance)
        game.realm?.refresh()
        saveStates = Array(
            game.saveStates
                .sorted(byKeyPath: "date", ascending: false)
        )
    }

    private func deleteSaveState(_ state: PVSaveState) {
        do {
            try PVSaveState.delete(state)
            reload()
        } catch {
            ELOG("Failed to delete save state: \(error)")
        }
    }
}
