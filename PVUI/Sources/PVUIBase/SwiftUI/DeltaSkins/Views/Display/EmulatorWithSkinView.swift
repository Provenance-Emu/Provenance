import SwiftUI
import PVCoreBridge
import PVEmulatorCore
import PVFeatureFlags
import PVLibrary
import PVSystems
import Combine
import ObjectiveC
import PVLogging
import RealmSwift
import Defaults

/// A SwiftUI view that displays a custom skin for the emulator
struct EmulatorWithSkinView: View {
    // Store only the necessary properties from the game
    let gameTitle: String
    let systemName: String?
    let systemId: SystemIdentifier?
    let gameId: String?

    let coreInstance: PVEmulatorCore
    let onSkinLoaded: () -> Void
    let onRefreshRequested: () -> Void
    /// Optional override to force a specific skin for this session (identifier)
    let preselectedSkinIdentifier: String?
    /// Unblocks ``PVEmulatorViewController/awaitDeltaSkinInitialResolutionIfNeeded()`` after the first resolution pass.
    let onInitialSkinResolutionComplete: (() -> Void)?

    @EnvironmentObject internal var inputHandler: DeltaSkinInputHandler
    @StateObject private var skinLoader = DeltaSkinLoader()
    @State private var skinRenderComplete = false

    // State for orientation
    #if os(iOS)
    @State private var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation
    #endif

    // Debug mode
    @State private var showDebugOverlay = false

    // Layout edit mode — when true, each button shows a drag handle for repositioning
    @State private var isEditMode = false

    // Shared button offsets manager
    @ObservedObject private var buttonOffsets = DeltaSkinButtonOffsets.shared

    // Add this to the struct to track rotation changes
    @State private var rotationCount: Int = 0

    // State for D-pad/joystick toggle in default skin
    @State internal var useJoystick = false

    // Notification observer tokens — removed on disappear to prevent duplicates
    @State private var orientationObserver: NSObjectProtocol?
    @State private var skinChangeObserver: NSObjectProtocol?
    @State private var filterChangeObserver: NSObjectProtocol?

    // Active skin-loading task — cancelled when a new load starts or the view disappears
    @State private var activeSkinLoadTask: Task<Void, Never>?

    // Live binding to built-in filter selection
    @Default(.metalFilterMode) private var metalFilterMode

    // User-selected filter from pause menu (takes precedence)
    @State private var selectedFilterName: String?

    // Track if we have a user-selected filter
    @State private var hasUserSelectedFilter = false

    // MARK: - Light gun crosshair overlay

    /// Whether the active core supports a light gun.
    /// Evaluated once on appear and cached to avoid repeated protocol casts.
    @State private var coreSupportsLightGun: Bool = false

    // MARK: - Keyboard overlay (iOS only)

    /// Whether the virtual keyboard overlay is currently shown.
    /// Only relevant when the loaded skin declares a `keyboardOverlay` config.
    #if !os(tvOS)
    @State private var isKeyboardOverlayVisible: Bool = false
    #endif

    // Initialize with a game, extracting the necessary properties
    init(
        game: PVGame,
        coreInstance: PVEmulatorCore,
        onSkinLoaded: @escaping () -> Void,
        onRefreshRequested: @escaping () -> Void,
        preselectedSkinIdentifier: String? = nil,
        onInitialSkinResolutionComplete: (() -> Void)? = nil
    ) {
        self.gameTitle = game.title
        self.systemName = game.system?.name

        // Convert string system identifier to enum
        self.systemId = game.system?.systemIdentifier

        // Get game ID for skin preferences (must match game.id used in skin selection)
        self.gameId = game.id

        self.coreInstance = coreInstance
        self.onSkinLoaded = onSkinLoaded
        self.onRefreshRequested = onRefreshRequested
        self.preselectedSkinIdentifier = preselectedSkinIdentifier
        self.onInitialSkinResolutionComplete = onInitialSkinResolutionComplete
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - make it transparent to show the game screen
                Color.clear.edgesIgnoringSafeArea(.all)

                if skinLoader.isLoading {
                    loadingView
                } else if let skin = skinLoader.selectedSkin, skin.supports(createSkinTraits()) {
                    // Skin supports the current orientation — render it
                    skinContentView(skin: skin, geometry: geometry)
                        .background(Color.clear)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if !skinRenderComplete {
                                    skinRenderComplete = true
                                    onSkinLoaded()
                                    DLOG("🎮 EmulatorWithSkinView: Skin render complete, notifying observers")

                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("DeltaSkinLoaded"),
                                        object: nil,
                                        userInfo: ["skinId": skin.identifier]
                                    )
                                    DLOG("🎮 Posted DeltaSkinLoaded notification for skin: \(skin.identifier)")

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onRefreshRequested()
                                    }

                                    #if !os(tvOS)
                                    if let kbConfig = skin.keyboardOverlay, kbConfig.autoShow {
                                        isKeyboardOverlayVisible = true
                                        DLOG("🎮 EmulatorWithSkinView: Auto-showing keyboard overlay (variant: \(kbConfig.variant.rawValue))")
                                    }
                                    #endif
                                }
                            }
                        }
                } else {
                    // No skin, or selected skin doesn't support the current orientation.
                    // Show the built-in fallback controller so the game remains playable.
                    defaultControllerSkin()
                        .background(Color.clear)
                        .onAppear {
                            if !skinRenderComplete {
                                skinRenderComplete = true
                                onSkinLoaded()
                                DLOG("🎮 EmulatorWithSkinView: Showing fallback controller (no skin or unsupported orientation)")
                            }
                        }
                }

                // Light gun crosshair overlay (gated by feature flag)
                if coreSupportsLightGun && PVFeatureFlagsManager.shared.lightGunCrosshair {
                    LightGunCrosshairView()
                        .allowsHitTesting(false)
                }

                // Debug overlay if enabled
                if showDebugOverlay {
                    debugOverlayView
                }

                // Edit Layout toolbar — shown only when the skinButtonReposition feature flag
                // is enabled, a skin is active AND supports the current traits. iOS only; tvOS
                // lacks DragGesture so edit mode is unsupported there.
                #if !os(tvOS)
                if PVFeatureFlagsManager.shared.skinButtonReposition,
                   let activeSkin = skinLoader.selectedSkin, activeSkin.supports(createSkinTraits()) {
                    VStack {
                        HStack {
                            Spacer()
                            DeltaSkinEditModeToolbar(
                                isEditMode: $isEditMode,
                                skinIdentifier: activeSkin.identifier,
                                buttonOffsets: buttonOffsets,
                                hasCustomOffsets: buttonOffsets.hasCustomOffsets(
                                    for: activeSkin.identifier
                                )
                            )
                            .padding(.top, geometry.safeAreaInsets.top + 12)
                            .padding(.trailing, 12)
                        }
                        Spacer()
                    }
                }
                #endif

                #if DEBUG
                // Debug toggle button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showDebugOverlay.toggle()
                        }) {
                            Image(systemName: showDebugOverlay ? "ladybug.fill" : "ladybug")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
                #endif

                // MARK: Keyboard overlay (iOS only)
                #if !os(tvOS)
                if let skin = skinLoader.selectedSkin,
                   let kbConfig = skin.keyboardOverlay {
                    // Keyboard toggle button — shown in the bottom-left corner so it
                    // does not overlap the debug ladybug (bottom-right).
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                isKeyboardOverlayVisible.toggle()
                            }) {
                                Image(systemName: isKeyboardOverlayVisible
                                      ? "keyboard.fill"
                                      : "keyboard")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding()
                            Spacer()
                        }
                    }

                    // The keyboard sheet itself
                    DeltaSkinKeyboardOverlayView(
                        config: kbConfig,
                        inputHandler: inputHandler,
                        isVisible: $isKeyboardOverlayVisible
                    )
                }
                #endif
            }
            .background(Color.clear) // Ensure the background is transparent
            .onAppear {
                // Determine whether the active core supports a light gun
                coreSupportsLightGun = (coreInstance as? LightGunResponder)?.gameSupportsLightGun == true

                // Set the emulator core in the input handler
                inputHandler.setEmulatorCore(coreInstance)

                // Load user-selected filter preference
                selectedFilterName = getUserSelectedFilter()
                hasUserSelectedFilter = selectedFilterName != nil
                ILOG("skins: Loaded filter preference on appear: \(selectedFilterName ?? "none")")

                // Start loading the skin - completely non-blocking
                loadSkinSafely()

                // Set up orientation handling
                setupOrientationHandling()

                // Listen for filter changes from pause menu
                setupFilterNotificationObserver()

                // Listen for skin selection changes to refresh view dynamically
                setupSkinChangeNotificationObserver()

                // Auto-show keyboard overlay if the skin was already loaded and requests it (iOS only)
                #if !os(tvOS)
                if let kbConfig = skinLoader.selectedSkin?.keyboardOverlay, kbConfig.autoShow {
                    isKeyboardOverlayVisible = true
                }
                #endif
            }
            .onDisappear {
                // Cancel any in-flight skin loading task
                activeSkinLoadTask?.cancel()
                activeSkinLoadTask = nil
                // Clean up closure-based notification observers using stored tokens
                if let obs = orientationObserver { NotificationCenter.default.removeObserver(obs) }
                if let obs = skinChangeObserver { NotificationCenter.default.removeObserver(obs) }
                if let obs = filterChangeObserver { NotificationCenter.default.removeObserver(obs) }
                orientationObserver = nil
                skinChangeObserver = nil
                filterChangeObserver = nil
            }
            .onChange(of: selectedFilterName) { _ in
                // Filter changes propagate naturally via state to DeltaSkinView's filters parameter
                // No need to force view recreation - this was causing AG::precondition_failure crashes
                ILOG("skins: Filter changed to: \(selectedFilterName ?? "none")")
            }
            .onChange(of: metalFilterMode) { _ in
                // Same for metalFilterMode - state changes propagate naturally
                ILOG("skins: metalFilterMode changed to: \(metalFilterMode.rawValue)")
            }
            .environment(\.debugSkinMappings, showDebugOverlay)
        }
        .background(Color.clear) // Ensure the background is transparent
    }

    // MARK: - Skin Content View

    private func skinContentView(skin: any DeltaSkinProtocol, geometry: GeometryProxy) -> some View {
        // Create traits reactively - this will be recalculated when currentOrientation changes
        let traits = createSkinTraits()

        // Get overlay effects with proper priority (user filter > skin filter > metalFilterMode)
        let effects = overlayEffects(for: skin)

        // Calculate aspect ratio from core's aspectSize or bufferSize/screenRect
        let aspectRatio: CGFloat? = {
            let aspectSize = coreInstance.aspectSize
            let bufferSize = coreInstance.bufferSize
            let screenRect = coreInstance.screenRect

            DLOG("🎮 SKIN: Calculating aspect ratio - aspectSize: \(aspectSize), bufferSize: \(bufferSize), screenRect: \(screenRect)")

            var calculatedRatio: CGFloat?

            if aspectSize.width > 0 && aspectSize.height > 0 {
                var ratio = aspectSize.width / aspectSize.height

                // Validate aspect ratio - ensure it's reasonable (most games are 4:3 or 16:9)
                // Check if aspectSize looks like screen dimensions instead of game aspect ratio
                let looksLikeScreenSize = aspectSize.width > 100 || aspectSize.height > 100

                // Most games have aspect ratios between 1.0 (square) and 2.0 (ultrawide)
                if looksLikeScreenSize || ratio < 0.5 || ratio > 2.0 {
                    if looksLikeScreenSize {
                        DLOG("🎮 SKIN: aspectSize looks like screen dimensions, using default 4:3")
                        ratio = 4.0 / 3.0
                    } else {
                        // Try inverted: swap width and height
                        let invertedRatio = aspectSize.height / aspectSize.width
                        if invertedRatio >= 0.5 && invertedRatio <= 2.0 {
                            ratio = invertedRatio
                            DLOG("🎮 SKIN: Aspect ratio was inverted, using corrected ratio: \(ratio)")
                        } else {
                            ratio = 4.0 / 3.0
                            DLOG("🎮 SKIN: Aspect ratio out of bounds, using default 4:3")
                        }
                    }
                }

                calculatedRatio = ratio
                DLOG("🎮 SKIN: Using aspectSize for aspect ratio: \(ratio)")
            }

            // Fallback to bufferSize/screenRect if aspectSize is invalid
            if calculatedRatio == nil {
                if screenRect.width > 0 && screenRect.height > 0 {
                    let ratio = screenRect.width / screenRect.height
                    calculatedRatio = ratio
                    DLOG("🎮 SKIN: Using screenRect for aspect ratio: \(ratio)")
                } else if bufferSize.width > 0 && bufferSize.height > 0 {
                    let ratio = bufferSize.width / bufferSize.height
                    calculatedRatio = ratio
                    DLOG("🎮 SKIN: Using bufferSize for aspect ratio: \(ratio)")
                }
            }

            // Return the validated aspect ratio
            if let ratio = calculatedRatio {
                return ratio
            }

            DLOG("🎮 SKIN: No valid aspect ratio found, will use default 4:3")
            return nil
        }()

        return DeltaSkinView(
            skin: skin,
            traits: traits,
            filters: effects,
            showDebugOverlay: showDebugOverlay,
            showHitTestOverlay: false,
            screenAspectRatio: aspectRatio,
            isInEmulator: true,
            inputHandler: inputHandler,
            core: coreInstance,
            isEditMode: $isEditMode,
            buttonOffsets: buttonOffsets
        )
        .environmentObject(inputHandler)
        // NOTE: Removed aggressive .id() modifier that was causing AG::precondition_failure crashes
        // when changing filters. The filter is passed as a parameter to DeltaSkinView and updates
        // automatically when state changes. Using .id() to force full view recreation corrupts
        // SwiftUI's attribute graph when combined with the complex ForEach hierarchy in DeltaSkinView.
        #if !os(tvOS)
        // Only use orientation for identity - rotation count and filter changes update via state
        .id(currentOrientation.rawValue)
        #endif
    }

    // MARK: - Debug Overlay

    private var debugOverlayView: some View {
        VStack(alignment: .leading) {
            Text("Debug Info")
                .font(.headline)
                .foregroundColor(.white)

            Text("Skin: \(skinLoader.selectedSkin?.name ?? "None")")
                .foregroundColor(.white)

            Text("Loading Stage: \(skinLoader.loadingStage.rawValue)")
                .foregroundColor(.white)

            Text("Progress: \(Int(skinLoader.loadingProgress * 100))%")
                .foregroundColor(.white)
            #if os(iOS)
            Text("Orientation: \(currentOrientation.isLandscape ? "Landscape" : "Portrait")")
                .foregroundColor(.white)
            #endif

            Text("Rotation Count: \(rotationCount)")
                .foregroundColor(.white)

            Text("Game: \(gameTitle)")
                .foregroundColor(.white)

            Text("System: \(systemName ?? "Unknown")")
                .foregroundColor(.white)

            if let error = skinLoader.loadingError {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }

            Button("Refresh View") {
                onRefreshRequested()
            }
            .padding(8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Orientation Handling

    /// Set up orientation handling
    private func setupOrientationHandling() {
        // We still need to use NotificationCenter for device orientation changes
        // as it's a system notification
#if os(iOS)
        // Remove any previous observer to prevent duplicates
        if let old = orientationObserver { NotificationCenter.default.removeObserver(old) }
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let newOrientation = UIDevice.current.orientation
            // Only act on real landscape/portrait changes, and only when the
            // landscape vs portrait category actually flipped.  Going from
            // faceDown → portrait (picking up the phone) used to trigger a
            // full skin reload even though the effective orientation hadn't
            // changed, causing a visible flicker mid-gameplay.
            guard newOrientation.isLandscape || newOrientation.isPortrait else { return }
            let wasLandscape = self.currentOrientation.isLandscape
            let nowLandscape = newOrientation.isLandscape
            guard wasLandscape != nowLandscape else { return }

            self.currentOrientation = newOrientation
            self.rotationCount += 1
            // Reset so DeltaSkinLoaded fires again when skin view reappears after rotation.
            self.skinRenderComplete = false
            DLOG("🎮 EmulatorWithSkinView: Orientation changed to: \(nowLandscape ? "landscape" : "portrait"), rotation count: \(self.rotationCount)")

            // Request a layout refresh after a brief delay, then reload the skin
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onRefreshRequested()
            }
            Task { @MainActor in self.loadSkinSafely() }
        }
#endif
    }

    // MARK: - Skin Traits

    /// Create skin traits based on current device and orientation
    private func createSkinTraits() -> DeltaSkinTraits {
        #if !os(tvOS)
        let isLandscape = currentOrientation.isLandscape ||
                         UIDevice.current.orientation == .unknown &&
                         UIScreen.main.bounds.width > UIScreen.main.bounds.height
        #else
        let isLandscape = true
        #endif

        // Determine device type
        let deviceType: DeltaSkinDevice
        if UIDevice.current.userInterfaceIdiom == .pad {
            deviceType = .ipad
        } else if UIDevice.current.userInterfaceIdiom == .tv {
            deviceType = .ipad // iPad landscape skins work best at TV scale; no real skins use "tv"
        } else {
            deviceType = .iphone
        }

        // Determine display type
        let displayType: DeltaSkinDisplayType
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
        displayType = bottomInset > 0 ? .edgeToEdge : .standard

        // Determine iPad model if applicable
        let iPadModel: DeltaSkinIPadModel? = deviceType == .ipad ? .mini : nil

        return DeltaSkinTraits(
            device: deviceType,
            displayType: displayType,
            orientation: isLandscape ? .landscape : .portrait,
            iPadModel: iPadModel,
            externalDisplay: .none,
            gameIdentifier: gameTitle
        )
    }

    // MARK: - Filter Handling

    /// Map filter name from pause menu to overlay effects
    private func filterNameToEffects(_ filterName: String) -> Set<TestPatternEffect> {
        switch filterName.lowercased() {
        case "none":
            return []
        case "crt", "scanlines":
            return [.scanlines]
        case "lcd":
            return [.lcd, .subpixel]
        case "game boy", "gba":
            return [.scanlines]
        default:
            return []
        }
    }

    /// Get user-selected filter from UserDefaults (game-specific or system-specific)
    /// Returns the filter name including "None" if explicitly set
    private func getUserSelectedFilter() -> String? {
        // Check game-specific filter first
        if let gameId = gameId,
           let gameFilter = UserDefaults.standard.string(forKey: "ScreenFilter_Game_\(gameId)") {
            ILOG("skins: Found game-specific filter: \(gameFilter)")
            return gameFilter // Return even if "None" - that's an explicit user choice
        }

        // Check system-specific filter
        if let systemId = systemId,
           let systemFilter = UserDefaults.standard.string(forKey: "ScreenFilter_System_\(systemId.rawValue)") {
            ILOG("skins: Found system-specific filter: \(systemFilter)")
            return systemFilter // Return even if "None" - that's an explicit user choice
        }

        return nil
    }

    /// Get overlay effects, prioritizing user-selected filter, then skin filters, then metalFilterMode
    private func overlayEffects(for skin: any DeltaSkinProtocol) -> Set<TestPatternEffect> {
        // Check if user has explicitly selected a filter (including "None")
        let userFilter = selectedFilterName ?? getUserSelectedFilter()

        // 1. If user selected a filter (even if "None"), use it (replaces skin filter)
        if let filter = userFilter {
            if filter == "None" {
                ILOG("skins: User selected 'None' - checking for skin filters")
                // User explicitly selected None, but check if skin has filters to use instead
                if let screens = skin.screens(for: createSkinTraits()),
                   let screen = screens.first,
                   let skinFilters = screen.filters,
                   !skinFilters.isEmpty {
                    ILOG("skins: User selected None but skin has \(skinFilters.count) custom CIFilters - skin filters will be used")
                    // Skin filters are CIFilters applied to the image, not overlay effects
                    // Return empty overlay effects since skin handles its own filters
                    return []
                }
                // User selected None and no skin filters - return empty
                ILOG("skins: User selected 'None' and no skin filters")
                return []
            } else {
                // User selected a specific filter - use it (replaces skin filter)
                ILOG("skins: Using user-selected filter: \(filter) (replacing any skin filters)")
                return filterNameToEffects(filter)
            }
        }

        // 2. No user selection - check if skin has its own filters
        if let screens = skin.screens(for: createSkinTraits()),
           let screen = screens.first,
           let skinFilters = screen.filters,
           !skinFilters.isEmpty {
            ILOG("skins: No user filter selected, skin has \(skinFilters.count) custom CIFilters - using skin filters")
            // Skin filters are CIFilters applied to the image, not overlay effects
            // Return empty overlay effects since skin handles its own filters
            return []
        }

        // 3. No user filter and no skin filters - fall back to metalFilterMode setting
        ILOG("skins: No user filter and no skin filters, using metalFilterMode setting")
        switch metalFilterMode {
        case .none:
            return []
        case .auto(crt: let crt, lcd: let lcd):
            var s: Set<TestPatternEffect> = []
            if crt != .none { s.insert(.scanlines) }
            if lcd != .none { s.insert(.lcd); s.insert(.subpixel) }
            return s
        case .always(filter: let filter):
            switch filter {
            case .lcd:
                return [.lcd, .subpixel]
            case .none:
                return []
            case .simpleCRT, .complexCRT, .megaTron, .ulTron, .gameBoy, .vhs:
                return [.scanlines]
            }
        }
    }

    /// Set up notification observer for skin selection changes
    /// Reloads skin when selection changes to ensure view updates immediately
    private func setupSkinChangeNotificationObserver() {
        if let old = skinChangeObserver { NotificationCenter.default.removeObserver(old) }
        skinChangeObserver = NotificationCenter.default.addObserver(
            forName: DeltaSkinSelectionManager.selectionChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Check if this notification is for our system/game
            guard let systemId = self.systemId,
                  let userInfo = notification.userInfo,
                  let notificationSystemId = userInfo["systemId"] as? String,
                  notificationSystemId == systemId.rawValue else {
                // Not for us, ignore
                return
            }

            DLOG("🎮 EmulatorWithSkinView: Received skin selection change notification, reloading skin")

            // Reload skin to pick up the new effective skin identifier
            Task { @MainActor in
                self.loadSkinSafely()
            }
        }
    }

    private func setupFilterNotificationObserver() {
        if let old = filterChangeObserver { NotificationCenter.default.removeObserver(old) }
        filterChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ApplyScreenFilter"),
            object: nil,
            queue: .main
        ) { notification in

            if let filterName = notification.userInfo?["filterName"] as? String {
                ILOG("skins: Received ApplyScreenFilter notification: \(filterName)")

                // Update selected filter on main actor
                // State changes automatically propagate to DeltaSkinView via overlayEffects()
                // No need to force view recreation - that was causing AG::precondition_failure crashes
                Task { @MainActor in
                    selectedFilterName = filterName == "None" ? nil : filterName
                    hasUserSelectedFilter = filterName != "None"

                    // Reload filter preference from UserDefaults to ensure consistency
                    selectedFilterName = getUserSelectedFilter()

                    ILOG("skins: Updated filter to: \(selectedFilterName ?? "none")")
                }
            }
        }
    }
}

// MARK: - Packaged skin resolution (extension keeps the main ``EmulatorWithSkinView`` body under SwiftLint limits)

extension EmulatorWithSkinView {

    /// Resolves the effective skin on a background task, shows loading until a packaged skin is chosen or the user is on the built-in-only path.
    @MainActor
    fileprivate func loadSkinSafely() {
        // Cancel any in-flight skin load to avoid stale tasks mutating state
        activeSkinLoadTask?.cancel()
        activeSkinLoadTask = nil

        DLOG("🎮 EmulatorWithSkinView: Starting to load skin safely")

        guard let systemId = systemId else {
            ELOG("🎮 EmulatorWithSkinView: No system ID available")
            skinLoader.isLoading = false
            skinLoader.loadingStage = .complete
            skinLoader.loadingProgress = 1.0
            onInitialSkinResolutionComplete?()
            return
        }

        // Capture UIKit values once on the main thread
        #if !os(tvOS)
        let currentOrientation: SkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #else
        let currentOrientation: SkinOrientation = .landscape
        let currentDevice: DeltaSkinDevice = .ipad
        #endif

        let prefersBuiltInOnly: Bool = {
            if let gameId = gameId, !gameId.isEmpty {
                return DeltaSkinSelectionManager.shared.prefersBuiltInControllerSkin(for: systemId, gameId: gameId, orientation: currentOrientation)
            }
            return DeltaSkinSelectionManager.shared.prefersBuiltInControllerSkin(for: systemId, gameId: nil, orientation: currentOrientation)
        }()

        if prefersBuiltInOnly {
            skinLoader.isLoading = false
            skinLoader.selectedSkin = nil
            skinLoader.loadingProgress = 1.0
            skinLoader.loadingStage = .complete
            skinRenderComplete = false
            onInitialSkinResolutionComplete?()
            DLOG("🎮 EmulatorWithSkinView: Built-in skin preference — skipping packaged skin load")
            return
        }

        let shouldPauseDuringResolve = skinLoader.selectedSkin != nil
        if shouldPauseDuringResolve {
            coreInstance.setPauseEmulation(true)
        }

        skinRenderComplete = false
        skinLoader.isLoading = true
        skinLoader.loadingStage = .loading
        skinLoader.loadingProgress = 0.5

        let preselected = preselectedSkinIdentifier
        let gameIdSnapshot = gameId
        let onResolved = onInitialSkinResolutionComplete

        // Safety timeout: if skin resolution takes longer than 5 seconds, proceed without a skin.
        let skinLoaderRef = skinLoader
        let coreRef = coreInstance
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                if skinLoaderRef.isLoading {
                    WLOG("🎮 EmulatorWithSkinView: Skin loading timeout (5s) — proceeding without skin")
                    skinLoaderRef.selectedSkin = nil
                    skinLoaderRef.isLoading = false
                    skinLoaderRef.loadingProgress = 1.0
                    skinLoaderRef.loadingStage = .complete
                    if shouldPauseDuringResolve {
                        coreRef.setPauseEmulation(false)
                    }
                    onResolved?()
                }
            }
        }

        activeSkinLoadTask = Task.detached(priority: .userInitiated) {
            defer { timeoutTask.cancel() }
            let manager = DeltaSkinManager.shared
            var foundSkin: (any DeltaSkinProtocol)?

            func skinSupportsCurrentDevice(_ skin: DeltaSkinProtocol) -> Bool {
                let device = currentDevice
                let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
                let orientations: [SkinOrientation] = [.portrait, .landscape]
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

            if let overrideId = preselected {
                if await MainActor.run(body: { manager.skinsAreLoaded }),
                   let skin = await MainActor.run(body: { manager.loadedSkins.first(where: { $0.identifier == overrideId }) }),
                   skinSupportsCurrentDevice(skin) {
                    foundSkin = skin
                    DLOG("🎮 EmulatorWithSkinView: Using preselected skin from cache: \(skin.name)")
                } else if let resolved = try? await manager.skin(withIdentifier: overrideId), skinSupportsCurrentDevice(resolved) {
                    foundSkin = resolved
                    DLOG("🎮 EmulatorWithSkinView: Resolved preselected skin by identifier: \(resolved.name)")
                }
            }

            if foundSkin == nil {
                let effectiveId: String?
                if let gameId = gameIdSnapshot, !gameId.isEmpty {
                    effectiveId = await MainActor.run {
                        DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
                            for: systemId,
                            gameId: gameId,
                            orientation: currentOrientation
                        )
                    }
                } else {
                    effectiveId = await MainActor.run {
                        DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                            for: systemId,
                            gameId: nil,
                            orientation: currentOrientation
                        )
                    }
                }

                if let effectiveId {
                    if await MainActor.run(body: { manager.skinsAreLoaded }),
                       let skin = await MainActor.run(body: { manager.loadedSkins.first(where: { $0.identifier == effectiveId }) }),
                       skinSupportsCurrentDevice(skin) {
                        foundSkin = skin
                        DLOG("🎮 EmulatorWithSkinView: Found effective skin: \(skin.name) (id: \(effectiveId))")
                    } else if let resolved = try? await manager.skin(withIdentifier: effectiveId), skinSupportsCurrentDevice(resolved) {
                        foundSkin = resolved
                        DLOG("🎮 EmulatorWithSkinView: Resolved effective skin: \(resolved.name)")
                    }
                }
            }

            let skipPackagedSkinFallback = await MainActor.run { () -> Bool in
                if let gameId = gameIdSnapshot, !gameId.isEmpty {
                    return DeltaSkinSelectionManager.shared.prefersBuiltInControllerSkin(for: systemId, gameId: gameId, orientation: currentOrientation)
                }
                return DeltaSkinSelectionManager.shared.prefersBuiltInControllerSkin(for: systemId, gameId: nil, orientation: currentOrientation)
            }

            if foundSkin == nil, !skipPackagedSkinFallback {
                if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                   await MainActor.run(body: { manager.skinsAreLoaded }),
                   let defaultSkin = await MainActor.run(body: {
                       manager.loadedSkins.first(where: {
                           let matchesType = $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                           guard matchesType && skinSupportsCurrentDevice($0) else { return false }
                           return CaseControllerDetector.isAllowedInAutomaticSkinSelection($0.identifier)
                       })
                   }) {
                    foundSkin = defaultSkin
                    DLOG("🎮 EmulatorWithSkinView: Using default skin: \(defaultSkin.name)")
                } else if let defaultSkin = try? await DeltaSkinManager.shared.skinToUse(for: systemId), skinSupportsCurrentDevice(defaultSkin) {
                    foundSkin = defaultSkin
                }
            }

            // Don't apply results if this task was cancelled (a newer load replaced us)
            guard !Task.isCancelled else {
                DLOG("🎮 EmulatorWithSkinView: Skin load task cancelled — discarding results")
                return
            }

            await MainActor.run {
                self.skinLoader.selectedSkin = foundSkin
                self.skinLoader.isLoading = false
                self.skinLoader.loadingProgress = 1.0
                self.skinLoader.loadingStage = .complete
                if shouldPauseDuringResolve {
                    self.coreInstance.setPauseEmulation(false)
                }
                onResolved?()
                if let skin = foundSkin {
                    DLOG("🎮 EmulatorWithSkinView: Updated UI with skin: \(skin.name)")
                } else {
                    DLOG("🎮 EmulatorWithSkinView: No packaged skin — programmatic controller")
                }
            }
        }
    }

    // MARK: - Loading View

    fileprivate var loadingView: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2),
                    Color(red: 0.2, green: 0.0, blue: 0.3)
                ]), startPoint: .bottom, endPoint: .top)
                .edgesIgnoringSafeArea(.all)

                RetroGrid()
                    .opacity(0.3)
                    .scaleEffect(0.8)

                VStack(spacing: 15) {
                    Text("LOADING SKIN")
                        .font(.custom("Futura-Bold", size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .retroPink.opacity(0.7), radius: 8, x: 0, y: 0)
                        .shadow(color: .retroPink.opacity(0.3), radius: 15, x: 0, y: 0)
                        .padding(.bottom, 5)

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        .retroYellow,
                                        .retroPink,
                                        Color(red: 0.1, green: 0.0, blue: 0.2)
                                    ]),
                                    center: .center,
                                    startRadius: 3,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 3)

                        Circle()
                            .trim(from: 0, to: CGFloat(skinLoader.loadingProgress))
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 85, height: 85)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: skinLoader.loadingProgress)
                    }
                    .padding(.bottom, 10)

                    HStack(spacing: 10) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(systemName?.uppercased() ?? "GAME")
                                .font(.custom("Menlo-Bold", size: 12))
                                .tracking(1)
                                .foregroundColor(.retroPink)
                                .shadow(color: .retroPink.opacity(0.6), radius: 3, x: 0, y: 0)

                            Text(skinLoader.loadingStage.rawValue.uppercased())
                                .font(.custom("Menlo", size: 10))
                                .tracking(1)
                                .foregroundColor(.retroBlue)
                                .shadow(color: .retroBlue.opacity(0.6), radius: 3, x: 0, y: 0)
                        }

                        Text("\(Int(skinLoader.loadingProgress * 100))%")
                            .font(.custom("Menlo-Bold", size: 18))
                            .foregroundColor(.retroBlue)
                            .shadow(color: .retroBlue.opacity(0.7), radius: 6, x: 0, y: 0)
                            .frame(width: 50)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )

                    RetroTapeAnimation()
                        .frame(width: 80, height: 50)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(0.95)
            }
        }
    }

    private struct RetroGrid: View {
        @State private var animateGrid = false

        var body: some View {
            VStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<20, id: \.self) { _ in
                            Rectangle()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.retroPurple.opacity(0.3),
                                            Color.retroPink.opacity(0.1)
                                        ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .scaleEffect(1.2)
            .rotationEffect(Angle(degrees: 60))
            .offset(y: animateGrid ? 80 : -80)
            .animation(
                Animation.linear(duration: 20)
                    .repeatForever(autoreverses: false),
                value: animateGrid
            )
            .onAppear {
                animateGrid = true
            }
        }
    }

    private struct RetroTapeAnimation: View {
        @State private var rotateReels = false

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: 70, height: 40)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.retroPurple.opacity(0.5),
                                Color.retroPink.opacity(0.5)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 20)

                HStack(spacing: 20) {
                    Circle()
                        .stroke(Color.retroBlue, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 8, height: 8)
                        )
                        .rotationEffect(Angle(degrees: rotateReels ? 360 : 0))

                    Circle()
                        .stroke(Color.retroBlue, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 8, height: 8)
                        )
                        .rotationEffect(Angle(degrees: rotateReels ? 360 : 0))
                }
            }
            .onAppear {
                withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotateReels = true
                }
            }
        }
    }
}
