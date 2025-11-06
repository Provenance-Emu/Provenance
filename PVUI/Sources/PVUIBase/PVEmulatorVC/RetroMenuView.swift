//
//  RetroMenuView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI
import UIKit
import SwiftUI
import PVCoreBridge
import PVLogging
import PVSettings
import GameController
import PVSupport
import PVLibrary
import PVFeatureFlags
import UniformTypeIdentifiers

// MARK: - SwiftUI Menu Views

// Main menu view with retrowave styling
struct RetroMenuView: View {
    let emulatorVC: PVEmulatorViewController
    let dismissAction: () -> Void
    @StateObject private var advancedSkinFeaturesFlag = PVFeatureFlagsManager.shared.flag(.advancedSkinFeatures)

    @State private var selectedCategory: MenuCategory = .main
    @State private var showSkinsCategoryButton: Bool = false // Add new @State variable

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
                dismissAction()
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
                case .skins:
                    skinsMenuButtons
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16) // Add padding at top and bottom
        }
        .frame(maxWidth: menuWidth)
    }

    /// Calculate appropriate content height based on category
    private func menuContentHeight(for category: MenuCategory) -> CGFloat {
        // Define base heights for each category
        let baseHeights: [MenuCategory: CGFloat] = [
            .main: isLandscape ? 180 : 220,     // Main menu (4-5 items)
            .core: isLandscape ? 200 : 240,     // Core menu (core actions, options)
            .states: isLandscape ? 200 : 240,   // States menu (3-4 items)
            .options: isLandscape ? 200 : 240,  // Options menu (game speed, cheats, controls)
            .skins: isLandscape ? 320 : 380     // Skins menu (most complex UI)
        ]

        // Get height for current category with fallback
        return baseHeights[category] ?? 220
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
                        .fill(Color.retroBlack.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.retroNeon, lineWidth: 2)
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
        Text("GAME OPTIONS")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.retroPink)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .shadow(color: .retroPink.opacity(0.8), radius: 10, x: 0, y: 0)
    }

    // Retrowave scrollable category selector
    var catagories: some View {
        ZStack {
            // Gradient background for scrollable area
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.retroPurple.opacity(0.2), Color.clear]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 50)

            // Grid lines for retrowave effect
            HStack(spacing: 15) {
                ForEach(0..<10) { _ in
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color.retroPink.opacity(0.3))
                }
            }

            // Scrollable buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    categoryButton(title: "MAIN", isSelected: selectedCategory == .main, action: { selectedCategory = .main })
                    // Show CORE tab if core has actions or options
                    if hasCoreFeatures {
                        categoryButton(title: "CORE", isSelected: selectedCategory == .core, action: { selectedCategory = .core })
                    }
                    categoryButton(title: "STATES", isSelected: selectedCategory == .states, action: { selectedCategory = .states })
                    categoryButton(title: "OPTIONS", isSelected: selectedCategory == .options, action: { selectedCategory = .options })
                    // Only show skins category if core supports skins and the feature flag is enabled
                    if emulatorVC.core.supportsSkins && showSkinsCategoryButton {
                        categoryButton(title: "SKINS", isSelected: selectedCategory == .skins, action: { selectedCategory = .skins })
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(height: 50)
        .padding(.bottom, 16)
        .onAppear { // Update the @State var on appear
            self.showSkinsCategoryButton = advancedSkinFeaturesFlag.value
        }
        .onChange(of: advancedSkinFeaturesFlag.value) { newValue in // And on change
            self.showSkinsCategoryButton = newValue
        }
    }

    var body: some View {
        ZStack {
            // Background with retrowave styling
            background

            // Menu container
            menuContainer
        }
        // Listen for orientation changes
#if !os(tvOS)
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
    }

    /// Check if core has features that warrant a CORE tab
    private var hasCoreFeatures: Bool {
        emulatorVC.core is CoreOptional ||
        (emulatorVC.core as? CoreActions)?.coreActions != nil
    }

    // Main menu buttons - essential game controls only
    private var mainMenuButtons: some View {
        // Calculate if we should show the save & quit option
        let shouldSave: Bool = {
            guard let game = emulatorVC.game else { return false }

            let lastPlayed = game.lastPlayed ?? Date()
            let minimumPlayTimeToMakeAutosave: TimeInterval = 60 * 2 // 2 minutes

            var shouldSave = Defaults[.autoSave]
            shouldSave = shouldSave && abs(lastPlayed.timeIntervalSinceNow) > minimumPlayTimeToMakeAutosave
            shouldSave = shouldSave && (game.lastAutosaveAge ?? minutes(2)) > minutes(1)
            shouldSave = shouldSave && abs(game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow ?? minutes(2)) > minutes(1)
            shouldSave = shouldSave && emulatorVC.core.supportsSaveStates

            return shouldSave
        }()

        return VStack(spacing: menuSpacing) {
            // Resume game button
            menuButton(title: "RESUME GAME", icon: "play.fill", color: .retroBlue) {
                dismissAction()
            }

            // Reset game button
            menuButton(title: "RESET GAME", icon: "arrow.counterclockwise", color: .retroOrange) {
                dismissAction()
                emulatorVC.core.resetEmulation()
            }

            // Game info button
            menuButton(title: "GAME INFO", icon: "info.circle", color: .retroPurple) {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    emulatorVC.showMoreInfo()
                }
            }

            // Quit game button - show different title if save option is available
            menuButton(title: shouldSave ? "QUIT (WITHOUT SAVING)" : "QUIT GAME", icon: "xmark.circle", color: .retroPink) {
                dismissAction()
                Task {
                    await emulatorVC.quit(optionallySave: false)
                }
            }

            // Save & Quit button - only show if save option is available
            if shouldSave {
                menuButton(title: "SAVE & QUIT", icon: "square.and.arrow.down", color: .retroPink) {
                    dismissAction()
                    let image = emulatorVC.captureScreenshot()

                    Task {
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
                    menuButton(title: coreAction.title, icon: "bolt", color: .retroOrange) {
                        dismissAction()
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
                menuButton(title: "CORE OPTIONS", icon: "gearshape", color: .retroPurple) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showCoreOptions()
                    }
                }
            }

            // If no core features available, show message
            if !hasCoreFeatures {
                Text("No core-specific features available")
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Save state related buttons
    private var stateMenuButtons: some View {
        VStack(spacing: menuSpacing) {
            if emulatorVC.core.supportsSaveStates {
                // Save state button
                menuButton(title: "SAVE STATE", icon: "square.and.arrow.down", color: .retroBlue) {
                    dismissAction()
                    Task {
                        let screenshot = emulatorVC.captureScreenshot()
                        do {
                            try await emulatorVC.createNewSaveState(auto: false, screenshot: screenshot)
                        } catch {
                            ELOG("Failed to save state: \(error.localizedDescription)")
                        }
                    }
                }

                // Load state button
                menuButton(title: "LOAD STATE", icon: "square.and.arrow.up", color: .retroPurple) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showSaveStateMenu()
                    }
                }

                // Save states menu button
                menuButton(title: "SAVE STATES", icon: "list.bullet", color: .retroYellow) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showSaveStateMenu()
                    }
                }
            } else {
                Text("Save states not supported")
                    .foregroundColor(.gray)
                    .padding()
            }

            // Screenshot button
#if os(iOS) || targetEnvironment(macCatalyst)
            menuButton(title: "SAVE SCREENSHOT", icon: "camera", color: .retroOrange) {
                dismissAction()
                emulatorVC.takeScreenshot()
            }
#endif

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Options related buttons - game settings and enhancements
    private var optionsMenuButtons: some View {
        VStack(spacing: menuSpacing) {
            // Game speed button
            menuButton(title: "GAME SPEED", icon: "speedometer", color: .retroBlue) {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    emulatorVC.showSpeedMenu()
                }
            }

            // Cheat codes button (if supported)
            if let gameWithCheat = emulatorVC.core as? GameWithCheat, gameWithCheat.supportsCheatCode {
                menuButton(title: "CHEAT CODES", icon: "wand.and.stars", color: .retroPink) {
                    dismissAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        emulatorVC.showCheatsMenu()
                    }
                }
            }

            #if os(iOS)
            // Audio visualizer button (iOS 16+ only, if supported by core)
            if emulatorVC.core.supportsAudioVisualizer {
                AudioVisualizerButton(emulatorVC: emulatorVC, dismissAction: dismissAction)
            }
            #endif

            let wantsStartSelectInMenu: Bool = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(emulatorVC.game.system?.identifier ?? SystemIdentifier.RetroArch.rawValue)

            // P1 controls (if available)
            if let player1 = PVControllerManager.shared.player1 {
#if os(iOS)
                if Defaults[.missingButtonsAlwaysOn] || (player1.extendedGamepad != nil || wantsStartSelectInMenu) {
                    menuButton(title: "P1 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P1 controls submenu
                        dismissAction()
                    }
                }
#else
                if player1.extendedGamepad != nil || wantsStartSelectInMenu {
                    menuButton(title: "P1 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P1 controls submenu
                        dismissAction()
                    }
                }
#endif
            }

            // P2 controls (if available)
            if let player2 = PVControllerManager.shared.player2 {
                if player2.extendedGamepad != nil || wantsStartSelectInMenu {
                    menuButton(title: "P2 CONTROLS", icon: "gamecontroller", color: .retroYellow) {
                        // Show P2 controls submenu
                        dismissAction()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Skins and filters related buttons
    @State private var selectedSkin: String = "Default"
    @State private var selectedPortraitSkin: String = "Default"
    @State private var selectedLandscapeSkin: String = "Default"
    @State private var selectedFilter: String = "None"
    @State private var availableSkins: [String] = ["Default"]
    @State private var availableSkinObjects: [DeltaSkinProtocol] = []
    @State private var showingSkinPicker = false
    @State private var showingFilterPicker = false
    @State private var showingSkinScopeAlert = false
    @State private var showingDocumentPicker = false
    @State private var pendingSkinSelection: (name: String, identifier: String, orientation: SkinOrientation)? = nil
    #if os(iOS)
    @State private var currentOrientation: SkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
    #else
    @State private var currentOrientation: SkinOrientation = .landscape
    #endif
    @State private var isLoadingSkins = false
    @State private var didLoadSkins = false

    // Store the session skin identifier to preserve it during orientation changes
    @State private var sessionSkinIdentifier: String? = nil
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

    private var skinsMenuButtons: some View {
        VStack(spacing: menuSpacing) {
            // Current skin selection - simplified UI
            VStack(alignment: .leading, spacing: 8) {
                Text("SKIN SELECTION")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                // Current skin button - shows current orientation's skin
                Button(action: {
                    // Use current device orientation for skin selection
                    #if !os(tvOS)
                    currentOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
                    #else
                    currentOrientation = .landscape
                    #endif
                    showingSkinPicker = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: currentOrientation == .portrait ? "rectangle.portrait" : "rectangle.landscape")
                                    .font(.system(size: 10))
                                Text(currentOrientation == .portrait ? "PORTRAIT SKIN" : "LANDSCAPE SKIN")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.gray)
                            Text(currentOrientation == .portrait ? selectedPortraitSkin : selectedLandscapeSkin)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.retroBlue)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroBlue, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingSkinPicker, onDismiss: {
                    // Ensure we don't get stuck in a loading state if dismissed while loading
                    if isLoadingSkins {
                        isLoadingSkins = false
                    }
                }) {
                    skinPickerView
                }

                // Import skin button
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .medium))
                        Text("IMPORT SKIN")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.retroPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroPurple, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingDocumentPicker) {
                    SkinDocumentPicker { urls in
                        Task {
                            await importSkins(from: urls)
                        }
                    }
                }
                .alert("Save Skin Selection", isPresented: $showingSkinScopeAlert) {
                    Button("Session Only") {
                        ILOG("skins: Alert - Session Only selected")
                        if let pending = pendingSkinSelection {
                            ILOG("skins: Alert - Applying session skin: \(pending.name)")
                            Task {
                                await applySkinSelection(skinName: pending.name, identifier: pending.identifier, orientation: pending.orientation, scope: .session)
                            }
                        } else {
                            ELOG("skins: Alert - Session Only selected but pendingSkinSelection is nil")
                        }
                        pendingSkinSelection = nil
                    }
                    Button("This Game") {
                        ILOG("skins: Alert - This Game selected")
                        if let pending = pendingSkinSelection {
                            ILOG("skins: Alert - Applying game skin: \(pending.name)")
                            Task {
                                await applySkinSelection(skinName: pending.name, identifier: pending.identifier, orientation: pending.orientation, scope: .game)
                            }
                        } else {
                            ELOG("skins: Alert - This Game selected but pendingSkinSelection is nil")
                        }
                        pendingSkinSelection = nil
                    }
                    Button("This System") {
                        ILOG("skins: Alert - This System selected")
                        if let pending = pendingSkinSelection {
                            ILOG("skins: Alert - Applying system skin: \(pending.name)")
                            Task {
                                await applySkinSelection(skinName: pending.name, identifier: pending.identifier, orientation: pending.orientation, scope: .system)
                            }
                        } else {
                            ELOG("skins: Alert - This System selected but pendingSkinSelection is nil")
                        }
                        pendingSkinSelection = nil
                    }
                    Button("Cancel", role: .cancel) {
                        ILOG("skins: Alert - Cancel selected")
                        pendingSkinSelection = nil
                    }
                } message: {
                    if let pending = pendingSkinSelection {
                        Text("How would you like to save '\(pending.name)' for \(pending.orientation == .portrait ? "portrait" : "landscape") orientation?")
                    }
                }
            }

            // Screen filter selection
            VStack(alignment: .leading, spacing: 4) {
                Text("SCREEN FILTER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                Button(action: {
                    // Show filter picker
                    showingFilterPicker = true
                }) {
                    HStack {
                        Text(selectedFilter)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.retroPink)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroPink, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingFilterPicker) {
                    filterPickerView
                }
            }

            // Button Effect Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("BUTTON EFFECT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                Button(action: {
                    // Show button effect picker
                    showingButtonEffectPicker = true
                }) {
                    HStack {
                        Text(buttonPressEffect.description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.retroPurple)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroPurple, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingButtonEffectPicker) {
                    buttonEffectPickerView
                }
            }

            // Button Sound Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("BUTTON SOUND")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                Button(action: {
                    // Show button sound picker
                    showingButtonSoundPicker = true
                }) {
                    HStack {
                        Text(buttonSound.description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.retroBlue)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.retroBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroBlue, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showingButtonSoundPicker) {
                    buttonSoundPickerView
                }
            }

            // Apply button - applies both skin and filter changes after dismissing menu
            menuButton(title: "APPLY SKIN AND FILTER", icon: "checkmark.circle", color: .retroBlue) {
                dismissAction()
                // Apply skin and filter changes after menu is dismissed
                Task {
                    await applySkinAndFilterChanges()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Skin picker sheet view with retrowave styling
    private var skinPickerView: some View {
        NavigationView {
            ZStack {
                // RetroWave background
                RetroTheme.retroBackground

                // Grid overlay
                RetroGrid()
                    .opacity(0.3)

                // Main content with loading state handling
                VStack {
                    // Header with orientation indicator
                    VStack(spacing: 8) {
                        Text("SELECT SKIN")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(RetroTheme.retroPink)
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)

                        HStack(spacing: 8) {
                            Image(systemName: currentOrientation == .portrait ? "rectangle.portrait" : "rectangle.landscape")
                                .font(.system(size: 14, weight: .semibold))
                            Text(currentOrientation == .portrait ? "PORTRAIT" : "LANDSCAPE")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
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
                                    .foregroundColor(RetroTheme.retroDarkBlue)
                                    .frame(width: 50, height: 50)

                                Circle()
                                    .trim(from: 0, to: 0.75)
                                    .stroke(RetroTheme.retroGradient, lineWidth: 4)
                                    .frame(width: 50, height: 50)
                                    .rotationEffect(Angle(degrees: glowOpacity * 360))
                            }
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5)

                            Text("LOADING SKINS...")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(RetroTheme.retroPink)
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, 50) // Offset to center visually
                    } else {
                        // Skin content when loaded
                        ScrollView {
                            VStack(spacing: 16) {
                                // Default skin option
                                if !availableSkins.contains(where: { $0 == "Default" }) {
                                    skinItemView(
                                        name: "Default",
                                        preview: nil,
                                        isSelected: (currentOrientation == .portrait ? selectedPortraitSkin : selectedLandscapeSkin) == "Default",
                                        skinId: nil,
                                        onSelect: {
                                            showingSkinPicker = false
                                            // Show scope selection alert
                                            pendingSkinSelection = (name: "Default", identifier: "", orientation: currentOrientation)
                                            showingSkinScopeAlert = true
                                        }
                                    )
                                }

                                // Custom skins with previews
                                ForEach(availableSkinObjects, id: \.identifier) { skin in
                                    SkinPreviewItemView(
                                        skin: skin,
                                        isSelected: (currentOrientation == .portrait ? selectedPortraitSkin : selectedLandscapeSkin) == skin.name,
                                        glowOpacity: glowOpacity,
                                        isHovered: isHoveredSkinId == skin.identifier,
                                        onSelect: {
                                            showingSkinPicker = false
                                            // Show scope selection alert
                                            pendingSkinSelection = (name: skin.name, identifier: skin.identifier, orientation: currentOrientation)
                                            showingSkinScopeAlert = true
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
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSkinPicker = false
                    }) {
                        Text("DONE")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(RetroTheme.retroPurple)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroPink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ), lineWidth: 1.5)
                            )
                            .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                    }
                }
            }
            #endif
                .onAppear {
                // Start animations
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }

                // Ensure picker orientation matches what's displayed
                // The picker orientation should already be set when the button is tapped,
                // but ensure it's correct here as well
                #if !os(tvOS)
                let currentDeviceOrientation = UIDevice.current.orientation.isLandscape ? SkinOrientation.landscape : .portrait
                #else
                let currentDeviceOrientation = SkinOrientation.landscape
                #endif

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
        .preferredColorScheme(.dark)
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
                                                gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.5))
                                .frame(width: geometry.size.width < 350 ? 60 : 80, height: geometry.size.width < 350 ? 60 : 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .overlay(
                                    Image(systemName: "gamecontroller.fill")
                                        .foregroundColor(RetroTheme.retroBlue)
                                        .font(.system(size: geometry.size.width < 350 ? 24 : 30))
                                        .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                                )
                        }
                    }

                    // Skin name and details
                    VStack(alignment: .leading, spacing: geometry.size.width < 350 ? 4 : 8) {
                        Text(name)
                            .font(.system(size: geometry.size.width < 350 ? 16 : 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                            .lineLimit(1)

                        if name != "Default" {
                            Text("Custom Skin")
                                .font(.system(size: geometry.size.width < 350 ? 12 : 14))
                                .foregroundColor(RetroTheme.retroPurple)
                                .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        } else {
                            Text("System Default")
                                .font(.system(size: geometry.size.width < 350 ? 12 : 14))
                                .foregroundColor(RetroTheme.retroBlue)
                                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        }
                    }

                    Spacer()

                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(RetroTheme.retroBlue)
                            .font(.system(size: geometry.size.width < 350 ? 20 : 24))
                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            isSelected ? RetroTheme.retroPink : RetroTheme.retroBlue,
                                            RetroTheme.retroPurple
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isHoveredSkinId == skinId || isSelected ? 2.0 : 1.5
                                )
                                .shadow(color: (isSelected ? RetroTheme.retroPink : RetroTheme.retroBlue).opacity(glowOpacity),
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
            .buttonStyle(PlainButtonStyle())
#if os(tvOS)
            .focusable(true)
#endif
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
                                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: geometry.size.width < 350 ? 60 : 80, height: geometry.size.width < 350 ? 60 : 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .overlay(
                                        Image(systemName: "gamecontroller.fill")
                                            .foregroundColor(RetroTheme.retroBlue)
                                            .font(.system(size: geometry.size.width < 350 ? 24 : 30))
                                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                                    )
                            }
                        }

                        // Skin name and details
                        VStack(alignment: .leading, spacing: geometry.size.width < 350 ? 4 : 8) {
                            Text(skin.name)
                                .font(.system(size: geometry.size.width < 350 ? 16 : 18, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity * 0.8), radius: 2, x: 0, y: 0)
                                .lineLimit(1)

                            Text("Custom Skin")
                                .font(.system(size: geometry.size.width < 350 ? 12 : 14))
                                .foregroundColor(RetroTheme.retroPurple)
                                .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity * 0.6), radius: 1, x: 0, y: 0)
                        }

                        Spacer()

                        // Selection indicator
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(RetroTheme.retroBlue)
                                .font(.system(size: geometry.size.width < 350 ? 20 : 24))
                                .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                isSelected ? RetroTheme.retroPink : RetroTheme.retroBlue,
                                                RetroTheme.retroPurple
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isHovered || isSelected ? 2.0 : 1.5
                                    )
                                    .shadow(color: (isSelected ? RetroTheme.retroPink : RetroTheme.retroBlue).opacity(glowOpacity),
                                            radius: isHovered || isSelected ? 5 : 3,
                                            x: 0,
                                            y: 0)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: UIScreen.main.bounds.width < 350 ? 84 : 104)
            .task {
                // Load preview image asynchronously
                if previewImage == nil {
                    previewImage = await DeltaSkinManager.shared.previewImage(for: skin)
                }
            }
#if os(tvOS)
            .focusable(true)
#endif
        }
    }

    // Filter picker sheet view with retrowave styling
    private var filterPickerView: some View {
        GeometryReader { geometry in
            ZStack {
                // Retrowave background
                VStack(spacing: 0) {
                    // Gradient sky
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black,
                            Color(red: 0.1, green: 0.0, blue: 0.3),
                            Color(red: 0.5, green: 0.0, blue: 0.5)
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 200)

                    // Grid floor
                    ZStack {
                        // Horizontal grid lines
                        VStack(spacing: 10) {
                            ForEach(0..<10) { _ in
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color.retroPink.opacity(0.5))
                            }
                            Spacer()
                        }

                        // Vertical grid lines
                        HStack(spacing: 20) {
                            ForEach(0..<10) { _ in
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color.retroPink.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                }

                // Content
                VStack(spacing: 0) {
                    // Header
                    Text("SCREEN FILTERS")
                        .font(.system(size: geometry.size.width < 400 ? 24 : 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                        .shadow(color: Color.retroPink.opacity(0.8), radius: 10, x: 0, y: 0)

                    // Filter options
                    VStack(spacing: isLandscape ? 8 : 12) {
                        ForEach(["None", "CRT", "LCD", "Scanlines", "Game Boy", "GBA"], id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                                showingFilterPicker = false
                            }) {
                                HStack {
                                    Text(filter)
                                        .font(.system(size: geometry.size.width < 400 ? 16 : 18, weight: .bold))
                                        .foregroundColor(filter == selectedFilter ? .white : .white.opacity(0.7))

                                    Spacer()

                                    if filter == selectedFilter {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.retroPink)
                                    }
                                }
                                .padding(.vertical, isLandscape ? 8 : 12)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(filter == selectedFilter ?
                                              Color.retroPurple.opacity(0.4) :
                                                Color.black.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(
                                                    filter == selectedFilter ?
                                                    Color.retroPink :
                                                        Color.retroPink.opacity(0.3),
                                                    lineWidth: filter == selectedFilter ? 2 : 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Done button
                    Button(action: {
                        showingFilterPicker = false
                    }) {
                        Text("DONE")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.retroBlue, Color.retroPurple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.retroBlue.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .frame(
                    width: isLandscape ? min(400, geometry.size.width * 0.8) : min(500, geometry.size.width * 0.9),
                    height: isLandscape ? geometry.size.height * 0.9 : min(600, geometry.size.height * 0.8)
                )
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
                .shadow(color: Color.retroPink.opacity(0.3), radius: 20)
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
            }
        }
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
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
            let skins = try await DeltaSkinManager.shared.skins(for: systemId)

            // Update the available skins list on the main thread
            await MainActor.run {
                // Store the actual skin objects for previews
                self.availableSkinObjects = skins

                // Create a set of unique skin names to avoid duplicates
                var uniqueSkinNames = Set<String>()
                uniqueSkinNames.insert("Default")

                // Add names of available skins, avoiding duplicates
                for skin in skins {
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
                   let portraitSkin = skins.first(where: { $0.identifier == portraitSkinId }) {
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
                   let landscapeSkin = skins.first(where: { $0.identifier == landscapeSkinId }) {
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



    /// Check if a skin supports a given orientation for the current device
    private func skinSupportsOrientation(_ skin: DeltaSkinProtocol, orientation: SkinOrientation) -> Bool {
        #if os(tvOS)
        let device: DeltaSkinDevice = .tv
        #else
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
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

        // Fallback: try the alternate device category (many skins declare only iPhone or iPad)
        #if os(tvOS)
        return false
        #else
        let altDevice: DeltaSkinDevice = (device == .ipad) ? .iphone : .ipad
        for display in displayTypes {
            let altTraits = DeltaSkinTraits(
                device: altDevice,
                displayType: display,
                orientation: orientation.deltaSkinOrientation
            )
            if skin.supports(altTraits) { return true }
        }
        return false
        #endif
    }

    /// Import skins from URLs
    private func importSkins(from urls: [URL]) async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else { return }

        for url in urls {
            do {
                // Import the skin
                try await DeltaSkinManager.shared.importSkin(from: url)

                // Reload skins to include the new one
                await DeltaSkinManager.shared.reloadSkins()

                // Reload available skins in the picker
                await MainActor.run {
                    didLoadSkins = false
                }

                // Show success message
                await MainActor.run {
                    // Optionally show a success notification
                }
            } catch {
                ELOG("Failed to import skin from \(url.lastPathComponent): \(error)")
            }
        }

        // After importing, prompt user to use the new skin
        if let skins = try? await DeltaSkinManager.shared.skins(for: systemId),
           let lastImported = skins.last {
            await MainActor.run {
                pendingSkinSelection = (name: lastImported.name, identifier: lastImported.identifier, orientation: currentOrientation)
                showingSkinScopeAlert = true
            }
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

        // Apply filter changes
        if selectedFilter != "None" {
            // Post notification to apply the filter
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyScreenFilter"),
                object: nil,
                userInfo: ["filterName": selectedFilter]
            )

            // Store filter preference - save to game if available, otherwise system
            if !gameId.isEmpty {
                UserDefaults.standard.set(selectedFilter, forKey: "ScreenFilter_Game_\(gameId)")
            } else {
                UserDefaults.standard.set(selectedFilter, forKey: "ScreenFilter_System_\(systemId.rawValue)")
            }
        } else {
            // Clear filter
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyScreenFilter"),
                object: nil,
                userInfo: ["filterName": "None"]
            )

            // Clear filter preferences - clear game if available, otherwise system
            if !gameId.isEmpty {
                UserDefaults.standard.removeObject(forKey: "ScreenFilter_Game_\(gameId)")
            } else {
                UserDefaults.standard.removeObject(forKey: "ScreenFilter_System_\(systemId.rawValue)")
            }
        }

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
                // Find and apply the skin
                let skins = try await DeltaSkinManager.shared.skins(for: systemId)
                if let skin = skins.first(where: { $0.identifier == skinId }) {
                    ILOG("skins: Applying skin '\(skin.name)' for current orientation (\(currentOrientation.rawValue))")
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

    // Apply skin and filter changes (legacy - kept for compatibility, not used)
    private func applySkinAndFilterChangesLegacy() async {
        guard let systemId = emulatorVC.game.system?.systemIdentifier else {
            return
        }

        let gameId: String? = emulatorVC.game.md5Hash ?? emulatorVC.game.crc

        do {
            // Apply filter changes if needed
            // Use notification pattern instead of direct property access
            if selectedFilter != "None" {
                // Post notification to apply the filter
                NotificationCenter.default.post(
                    name: NSNotification.Name("ApplyScreenFilter"),
                    object: nil,
                    userInfo: ["filterName": selectedFilter]
                )

                // Store filter preference - save to game if available, otherwise system
                if let gameId = gameId, !gameId.isEmpty {
                    UserDefaults.standard.set(selectedFilter, forKey: "ScreenFilter_Game_\(gameId)")
                } else {
                    UserDefaults.standard.set(selectedFilter, forKey: "ScreenFilter_System_\(systemId.rawValue)")
                }
            } else {
                // Clear filter
                NotificationCenter.default.post(
                    name: NSNotification.Name("ApplyScreenFilter"),
                    object: nil,
                    userInfo: ["filterName": "None"]
                )

                // Clear filter preferences - clear game if available, otherwise system
                if let gameId = gameId, !gameId.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "ScreenFilter_Game_\(gameId)")
                } else {
                    UserDefaults.standard.removeObject(forKey: "ScreenFilter_System_\(systemId.rawValue)")
                }
            }

            // Apply skin changes if needed
            if selectedSkin != "Default" {
                // Find the skin by name
                let skins = try await DeltaSkinManager.shared.skins(for: systemId)
                if let skin = skins.first(where: { $0.name == selectedSkin }),
                   let emulatorVC = emulatorVC as? PVEmulatorViewController {

                    // Clear any session skin for this system/game when setting an explicit preference
                    // This ensures session skins don't override the user's explicit choice
                    #if !os(tvOS)
                    let currentOrientation = UIDevice.current.orientation.isLandscape ? SkinOrientation.landscape : .portrait
                    let oppositeOrientation = currentOrientation == .landscape ? SkinOrientation.portrait : .landscape
                    #else
                    let currentOrientation = SkinOrientation.landscape
                    let oppositeOrientation = SkinOrientation.landscape
                    #endif

                    // Clear session skins for both orientations using setSessionSkin(nil, ...)
                    DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, orientation: currentOrientation)
                    DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, orientation: oppositeOrientation)

                    if let gameId = gameId {
                        // Also clear game-specific session skins
                        DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, gameId: gameId, orientation: currentOrientation)
                        DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, gameId: gameId, orientation: oppositeOrientation)
                    }

                    // Legacy function - this shouldn't be called anymore, but if it is, default to session
                    // Session scope - store in the session skin identifier
                    sessionSkinIdentifier = skin.identifier
                    DeltaSkinManager.shared.setSessionSkin(skin.identifier, for: systemId, orientation: currentOrientation)
                    if let gameId = gameId {
                        DeltaSkinManager.shared.setSessionSkin(skin.identifier, for: systemId, gameId: gameId, orientation: currentOrientation)
                    }

                    // Apply the skin
                    try await emulatorVC.applySkin(skin)
                }
            } else {
                // User selected "Default" skin
                if let emulatorVC = emulatorVC as? PVEmulatorViewController {
                    // Clear any session skins for this system/game
                    #if !os(tvOS)
                    let currentOrientation = UIDevice.current.orientation.isLandscape ? SkinOrientation.landscape : .portrait
                    let oppositeOrientation = currentOrientation == .landscape ? SkinOrientation.portrait : .landscape
                    #else
                    let currentOrientation = SkinOrientation.landscape
                    let oppositeOrientation = SkinOrientation.portrait
                    #endif

                    // Clear session skins for both orientations using setSessionSkin(nil, ...)
                    DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, orientation: currentOrientation)
                    DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, orientation: oppositeOrientation)

                    if let gameId = gameId {
                        // Also clear game-specific session skins
                        DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, gameId: gameId, orientation: currentOrientation)
                        DeltaSkinManager.shared.setSessionSkin(nil, for: systemId, gameId: gameId, orientation: oppositeOrientation)
                    }

                    // Legacy function - clear session skins only
                    // Preferences are managed through the new applySkinSelection function

                    // Also clear session skin identifier
                    sessionSkinIdentifier = nil

                    // Reset to default skin
                    try await emulatorVC.resetToDefaultSkin()
                }
            }
        } catch {
            ELOG("Error applying skin and filter changes: \(error)")
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

    // Helper to apply skin to emulator
    private func applySkinToEmulator(skin: DeltaSkinProtocol, systemId: SystemIdentifier) {
        // Notify the emulator to refresh its skin
        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshDeltaSkin"),
            object: nil,
            userInfo: [
                "systemId": systemId.rawValue,
                "skinIdentifier": skin.identifier
            ]
        )

        // Directly apply skin to the current view controller if possible
        if let emulatorVC = self.emulatorVC as? PVEmulatorViewController {
            Task {
                try? await emulatorVC.applySkin(skin)
            }
        }
    }

    // Helper function for category buttons in the header
    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))

                // Indicator line
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .retroPink : .clear)
            }
            .frame(height: 40)
            .padding(.horizontal, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.retroPurple.opacity(0.2), Color.retroPurple.opacity(0.5)]),
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
        .buttonStyle(PlainButtonStyle())
    }

    // Helper function to create menu buttons
    private func menuButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: isLandscape ? 16 : 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: isLandscape ? 12 : 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, isLandscape ? 10 : 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(color, lineWidth: 2)
                    )
            )
            .shadow(color: color.opacity(0.5), radius: 5, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
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
