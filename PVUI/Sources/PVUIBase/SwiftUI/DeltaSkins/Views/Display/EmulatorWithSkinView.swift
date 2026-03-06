import SwiftUI
import PVEmulatorCore
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

    @EnvironmentObject internal var inputHandler: DeltaSkinInputHandler
    @StateObject private var skinLoader = DeltaSkinLoader()
    @State private var skinRenderComplete = false

    // State for orientation
    #if os(iOS)
    @State private var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation
    #endif

    // Debug mode
    @State private var showDebugOverlay = false

    // Add this to the struct to track rotation changes
    @State private var rotationCount: Int = 0

    // State for D-pad/joystick toggle in default skin
    @State internal var useJoystick = false

    // Timeout for skin loading to prevent hanging
    @State private var loadingTimeoutTask: Task<Void, Never>?

    // Live binding to built-in filter selection
    @Default(.metalFilterMode) private var metalFilterMode

    // User-selected filter from pause menu (takes precedence)
    @State private var selectedFilterName: String?

    // Track if we have a user-selected filter
    @State private var hasUserSelectedFilter = false

    // Initialize with a game, extracting the necessary properties
    init(game: PVGame, coreInstance: PVEmulatorCore, onSkinLoaded: @escaping () -> Void, onRefreshRequested: @escaping () -> Void, preselectedSkinIdentifier: String? = nil) {
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
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - make it transparent to show the game screen
                Color.clear.edgesIgnoringSafeArea(.all)

                if skinLoader.isLoading {
                    // Loading view with progress
                    loadingView
                        .onAppear {
                            // Set timeout to prevent hanging - call onSkinLoaded after 2 seconds max
                            loadingTimeoutTask?.cancel()
                            loadingTimeoutTask = Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                                if !Task.isCancelled && skinLoader.isLoading {
                                    DLOG("🎮 EmulatorWithSkinView: Skin loading timeout - proceeding without skin")
                                    await MainActor.run {
                                        // Force completion to show game view
                                        skinLoader.isLoading = false
                                        onSkinLoaded()
                                    }
                                }
                            }
                        }
                        .onDisappear {
                            loadingTimeoutTask?.cancel()
                        }
                } else if let skin = skinLoader.selectedSkin {
                    // Render the skin
                    skinContentView(skin: skin, geometry: geometry)
                        .background(Color.clear) // Ensure background is transparent
                        .onAppear {
                            // Cancel timeout since skin loaded successfully
                            loadingTimeoutTask?.cancel()

                            // When the skin content appears, wait for layout to stabilize
                            // before marking as complete to ensure correct initial positioning
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if !skinRenderComplete {
                                    skinRenderComplete = true
                                    onSkinLoaded()
                                    DLOG("🎮 EmulatorWithSkinView: Skin render complete, notifying observers")

                                    // Post a notification that the skin is loaded
                                    // This will trigger the GPU view positioning in PVEmulatorViewController
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("DeltaSkinLoaded"),
                                        object: nil,
                                        userInfo: ["skinId": skin.identifier]
                                    )
                                    DLOG("🎮 Posted DeltaSkinLoaded notification for skin: \(skin.identifier)")

                                    // Request a refresh after the skin is loaded to ensure screen positions are correct
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onRefreshRequested()
                                    }
                                }
                            }
                        }
                } else {
                    // No skin loaded - show fallback controller with input handling
                    // This ensures the game is always playable even if skin loading fails
                    defaultControllerSkin()
                        .background(Color.clear) // Ensure background is transparent
                        .onAppear {
                            // Cancel timeout if we got here
                            loadingTimeoutTask?.cancel()
                            // Even with the fallback, notify that we're ready
                            if !skinRenderComplete {
                                skinRenderComplete = true
                                onSkinLoaded()
                                DLOG("🎮 EmulatorWithSkinView: Showing fallback controller, skin loading failed or no skin available")
                            }
                        }
                }

                // Debug overlay if enabled
                if showDebugOverlay {
                    debugOverlayView
                }

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
            }
            .background(Color.clear) // Ensure the background is transparent
            .onAppear {
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
            }
            .onDisappear {
                // Clean up notifications
                NotificationCenter.default.removeObserver(self)
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

    // MARK: - Loading View

    private var loadingView: some View {
        /// A compact retrowave-themed loading view with neon colors and animated elements
        GeometryReader { geometry in
            ZStack {
                // Retrowave background gradient
                LinearGradient(gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2),
                    Color(red: 0.2, green: 0.0, blue: 0.3)
                ]), startPoint: .bottom, endPoint: .top)
                .edgesIgnoringSafeArea(.all)

                // Grid overlay - smaller scale for a more compact look
                RetroGrid()
                    .opacity(0.3)
                    .scaleEffect(0.8)

                // Content container - reduced spacing for more compact layout
                VStack(spacing: 15) {
                    // Smaller title with maintained glow effect
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

                    // Smaller Retrowave sun with progress indicator
                    ZStack {
                        // Sun backdrop - reduced size
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

                        // Horizon line - reduced size
//                        Rectangle()
//                            .fill(Color.black)
//                            .frame(width: 140, height: 50)
//                            .offset(y: 25)

                        // Progress circle - reduced size
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

                    // Compact loading status with system name
                    HStack(spacing: 10) {
                        // System name and loading stage in one line
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

                        // Percentage in more prominent display
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

                    // Smaller animated cassette tape
                    RetroTapeAnimation()
                        .frame(width: 80, height: 50)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(0.95) // Slightly scale down the entire content for more compact look
            }
        }
    }

    /// A retrowave grid background
    private struct RetroGrid: View {
        @State private var animateGrid = false

        var body: some View {
            VStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { y in
                    HStack(spacing: 0) {
                        ForEach(0..<20, id: \.self) { x in
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
            .scaleEffect(1.2) // Reduced scale from 1.5
            .rotationEffect(Angle(degrees: 60))
            .offset(y: animateGrid ? 80 : -80) // Reduced offset from 100
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

    /// Animated cassette tape
    private struct RetroTapeAnimation: View {
        @State private var rotateReels = false

        var body: some View {
            ZStack {
                // Tape case - reduced size
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

                // Cassette label - reduced size
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

                // Reels - reduced size and spacing
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

        return Group {
            if let deltaSkin = skin as? DeltaSkin {
                // If we have a DeltaSkin, use the specialized view
                DeltaSkinView(
                    skin: deltaSkin,
                    traits: traits,
                    filters: effects,
                    showDebugOverlay: showDebugOverlay,
                    showHitTestOverlay: false,
                    screenAspectRatio: aspectRatio,
                    isInEmulator: true,
                    inputHandler: inputHandler,
                    core: coreInstance
                )
            } else {
                // For other skin types
                DeltaSkinView(
                    skin: skin,
                    traits: traits,
                    filters: effects,
                    showDebugOverlay: showDebugOverlay,
                    showHitTestOverlay: false,
                    screenAspectRatio: aspectRatio,
                    isInEmulator: true,
                    inputHandler: inputHandler,
                    core: coreInstance
                )
            }
        }
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
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isLandscape || newOrientation.isPortrait {
                self.currentOrientation = newOrientation
                self.rotationCount += 1
                DLOG("🎮 EmulatorWithSkinView: Orientation changed to: \(newOrientation.isLandscape ? "landscape" : "portrait"), rotation count: \(self.rotationCount)")

                // Refresh the view
                self.refreshView()
            }
        }
#endif
    }

    /// Refresh the view after orientation changes
    private func refreshView() {
        // Force traits recalculation by updating rotation count
        // This triggers trait recalculation without full view rebuild
        rotationCount += 1
        DLOG("🎮 EmulatorWithSkinView: Refreshing view, rotation count: \(rotationCount)")

        // Request a refresh after orientation change to update screen positions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onRefreshRequested()
        }
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
        if #available(iOS 11.0, *) {
            let window = UIApplication.shared.windows.first
            let bottomInset = window?.safeAreaInsets.bottom ?? 0
            displayType = bottomInset > 0 ? .edgeToEdge : .standard
        } else {
            displayType = .standard
        }

        // Determine iPad model if applicable
        let iPadModel: DeltaSkinIPadModel?
        if deviceType == .ipad {
            let screenSize = UIScreen.main.bounds.size
            let maxDimension = max(screenSize.width, screenSize.height)

            // Just use mini for all iPad models since we don't know the exact enum values
            iPadModel = .mini
        } else {
            iPadModel = nil
        }

        return DeltaSkinTraits(
            device: deviceType,
            displayType: displayType,
            orientation: isLandscape ? .landscape : .portrait,
            iPadModel: iPadModel,
            externalDisplay: .none
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
        NotificationCenter.default.addObserver(
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
        NotificationCenter.default.addObserver(
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

    // MARK: - Loading Logic

    /// Load the skin safely without Realm threading issues
    /// Completely non-blocking: sets isLoading=false immediately, loads skin in background
    /// Now checks effective skin identifier (session > game > system preferences) dynamically
    @MainActor
    private func loadSkinSafely() {
        DLOG("🎮 EmulatorWithSkinView: Starting to load skin safely")

        // IMMEDIATELY set loading to false so UI doesn't block
        skinLoader.isLoading = false
        skinLoader.loadingProgress = 1.0
        skinLoader.loadingStage = .complete
        onSkinLoaded()
        DLOG("🎮 EmulatorWithSkinView: Set loading=false immediately, game can boot now")

        guard let systemId = systemId else {
            ELOG("🎮 EmulatorWithSkinView: No system ID available")
            return
        }

        // Load skin in background without blocking
        Task.detached(priority: .utility) {
            let manager = DeltaSkinManager.shared
            var foundSkin: (any DeltaSkinProtocol)? = nil

            // Determine current orientation for effective skin lookup
            #if !os(tvOS)
            let currentOrientation: SkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
            #else
            let currentOrientation: SkinOrientation = .landscape
            #endif

            // Helper function to check if skin supports current device
            func skinSupportsCurrentDevice(_ skin: DeltaSkinProtocol) -> Bool {
                #if os(tvOS)
                let device: DeltaSkinDevice = .ipad // No real skins use "tv"; iPad landscape is best for tvOS
                #else
                let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
                #endif
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

            // PRIORITY 1: If a specific skin has been requested for this session (preselectedSkinIdentifier), honor it immediately
            if let overrideId = preselectedSkinIdentifier {
                if manager.skinsAreLoaded, let skin = manager.loadedSkins.first(where: { $0.identifier == overrideId }) {
                    // Verify skin supports current device before using it
                    if skinSupportsCurrentDevice(skin) {
                        foundSkin = skin
                        DLOG("🎮 EmulatorWithSkinView: Using preselected skin from cache: \(skin.name)")
                    } else {
                        DLOG("🎮 EmulatorWithSkinView: Preselected skin \(skin.name) doesn't support current device, skipping")
                    }
                } else {
                    // Attempt to resolve skin by identifier even if not in cache yet
                    if let resolved = try? await manager.skin(withIdentifier: overrideId) {
                        // Verify resolved skin supports current device before using it
                        if skinSupportsCurrentDevice(resolved) {
                            foundSkin = resolved
                            DLOG("🎮 EmulatorWithSkinView: Resolved preselected skin by identifier: \(resolved.name)")
                        } else {
                            DLOG("🎮 EmulatorWithSkinView: Resolved preselected skin \(resolved.name) doesn't support current device, skipping")
                        }
                    }
                }
            }

            // PRIORITY 2: Check effective skin identifier using centralized selection manager
            if foundSkin == nil {
                let effectiveId: String?
                if let gameId = self.gameId, !gameId.isEmpty {
                    // Use centralized selection manager for game-specific lookup
                    effectiveId = await MainActor.run {
                        DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(
                            for: systemId,
                            gameId: gameId,
                            orientation: currentOrientation
                        )
                    }
                } else {
                    // Use centralized selection manager for system-level lookup
                    effectiveId = await MainActor.run {
                        DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                            for: systemId,
                            gameId: nil,
                            orientation: currentOrientation
                        )
                    }
                }

                if let effectiveId = effectiveId {
                    if manager.skinsAreLoaded, let skin = manager.loadedSkins.first(where: { $0.identifier == effectiveId }) {
                        // Verify skin supports current device before using it
                        if skinSupportsCurrentDevice(skin) {
                            foundSkin = skin
                            DLOG("🎮 EmulatorWithSkinView: Found effective skin: \(skin.name) (id: \(effectiveId))")
                        } else {
                            DLOG("🎮 EmulatorWithSkinView: Effective skin \(skin.name) doesn't support current device, skipping")
                        }
                    } else if let resolved = try? await manager.skin(withIdentifier: effectiveId) {
                        // Verify resolved skin supports current device before using it
                        if skinSupportsCurrentDevice(resolved) {
                            foundSkin = resolved
                            DLOG("🎮 EmulatorWithSkinView: Resolved effective skin: \(resolved.name)")
                        } else {
                            DLOG("🎮 EmulatorWithSkinView: Resolved skin \(resolved.name) doesn't support current device, skipping")
                        }
                    }
                }
            }

            // PRIORITY 3: Fallback to default skin if nothing found
            if foundSkin == nil {
                if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                   manager.skinsAreLoaded,
                   let defaultSkin = manager.loadedSkins.first(where: {
                       let matchesType = $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                       return matchesType && skinSupportsCurrentDevice($0)
                   }) {
                    foundSkin = defaultSkin
                    DLOG("🎮 EmulatorWithSkinView: Using default skin: \(defaultSkin.name)")
                } else {
                    // Try to get a device-compatible default skin
                    if let defaultSkin = try? await DeltaSkinManager.shared.skinToUse(for: systemId),
                       skinSupportsCurrentDevice(defaultSkin) {
                        foundSkin = defaultSkin
                    }
                }
            }

            // Update UI with skin if found
            if let skin = foundSkin {
                await MainActor.run {
                    self.skinLoader.selectedSkin = skin
                }
                DLOG("🎮 EmulatorWithSkinView: Updated UI with skin: \(skin.name)")
            } else {
                DLOG("🎮 EmulatorWithSkinView: No skin found, will use default controller")
            }
        }
    }
}
