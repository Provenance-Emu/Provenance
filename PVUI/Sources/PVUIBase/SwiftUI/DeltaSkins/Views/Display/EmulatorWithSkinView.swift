import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVSystems
import Combine
import ObjectiveC
import PVLogging
import RealmSwift

/// A SwiftUI view that displays a custom skin for the emulator
struct EmulatorWithSkinView: View {
    // Store only the necessary properties from the game
    let gameTitle: String
    let systemName: String?
    let systemId: SystemIdentifier?

    let coreInstance: PVEmulatorCore
    let onSkinLoaded: () -> Void
    let onRefreshRequested: () -> Void

    @EnvironmentObject internal var inputHandler: DeltaSkinInputHandler
    @StateObject private var skinLoader = DeltaSkinLoader()
    @State private var skinRenderComplete = false

    // State for orientation
    @State private var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation

    // Debug mode
    @State private var showDebugOverlay = false

    // Add this to the struct to track rotation changes
    @State private var rotationCount: Int = 0

    // State for D-pad/joystick toggle in default skin
    @State internal var useJoystick = false

    // Initialize with a game, extracting the necessary properties
    init(game: PVGame, coreInstance: PVEmulatorCore, onSkinLoaded: @escaping () -> Void, onRefreshRequested: @escaping () -> Void) {
        self.gameTitle = game.title
        self.systemName = game.system?.name

        // Convert string system identifier to enum
        self.systemId = game.system?.systemIdentifier

        self.coreInstance = coreInstance
        self.onSkinLoaded = onSkinLoaded
        self.onRefreshRequested = onRefreshRequested
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - make it transparent to show the game screen
                Color.clear.edgesIgnoringSafeArea(.all)

                if skinLoader.isLoading {
                    // Loading view with progress
                    loadingView
                } else if let skin = skinLoader.selectedSkin {
                    // Render the skin
                    skinContentView(skin: skin, geometry: geometry)
                        .background(Color.clear) // Ensure background is transparent
                        .onAppear {
                            // When the skin content appears, mark as complete after a short delay
                            // to ensure it's fully rendered
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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

                                    // Request a refresh after the skin is loaded
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onRefreshRequested()
                                    }
                                }
                            }
                        }
                } else {
                    // Fallback controller with input handling
                    defaultControllerSkin()
                        .background(Color.clear) // Ensure background is transparent
                        .onAppear {
                            // Even with the fallback, notify that we're ready
                            onSkinLoaded()
                        }
                }

                // Debug overlay if enabled
                if showDebugOverlay {
                    debugOverlayView
                }

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
            }
            .background(Color.clear) // Ensure the background is transparent
            .onAppear {
                // Set the emulator core in the input handler
                inputHandler.setEmulatorCore(coreInstance)

                // Start loading the skin using a simplified approach
                Task {
                    await loadSkinSafely()
                }

                // Set up orientation handling
                setupOrientationHandling()
            }
            .onDisappear {
                // Clean up notification
                NotificationCenter.default.removeObserver(self)
            }
            .environment(\.debugSkinMappings, showDebugOverlay)
        }
        .background(Color.clear) // Ensure the background is transparent
    }

    // MARK: - Loading View

    private var loadingView: some View {
        /// A retrowave-themed loading view with neon colors, grid background, and animated elements
        GeometryReader { geometry in
            ZStack {
                // Retrowave background gradient
                LinearGradient(gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2),
                    Color(red: 0.2, green: 0.0, blue: 0.3)
                ]), startPoint: .bottom, endPoint: .top)
                .edgesIgnoringSafeArea(.all)

                // Grid overlay
                RetroGrid()
                    .opacity(0.4)

                // Content container
                VStack(spacing: 30) {
                    // Title with glow effect
                    Text("LOADING \(systemName?.uppercased() ?? "GAME") SKIN")
                        .font(.custom("Futura-Bold", size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .retroPink.opacity(0.8), radius: 10, x: 0, y: 0)
                        .shadow(color: .retroPink.opacity(0.4), radius: 20, x: 0, y: 0)
                        .padding(.bottom, 10)

                    // Retrowave sun with progress indicator
                    ZStack {
                        // Sun backdrop
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        .retroYellow,
                                        .retroPink,
                                        Color(red: 0.1, green: 0.0, blue: 0.2)
                                    ]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 5)

                        // Horizon line
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 220, height: 80)
                            .offset(y: 40)

                        // Progress circle
                        Circle()
                            .trim(from: 0, to: CGFloat(skinLoader.loadingProgress))
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: skinLoader.loadingProgress)
                    }
                    .padding(.bottom, 20)

                    // Loading status with retro terminal styling
                    VStack(spacing: 12) {
                        Text(skinLoader.loadingStage.rawValue.uppercased())
                            .font(.custom("Menlo", size: 14))
                            .tracking(1.5)
                            .foregroundColor(.retroBlue)
                            .shadow(color: .retroBlue.opacity(0.8), radius: 5, x: 0, y: 0)

                        // Percentage text
                        Text("\(Int(skinLoader.loadingProgress * 100))%")
                            .font(.custom("Menlo-Bold", size: 20))
                            .foregroundColor(.retroBlue)
                            .shadow(color: .retroBlue.opacity(0.8), radius: 8, x: 0, y: 0)
                            .frame(width: 60)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )

                    // Animated cassette tape (decorative)
                    RetroTapeAnimation()
                        .frame(width: 120, height: 80)
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .scaleEffect(1.5)
            .rotationEffect(Angle(degrees: 60))
            .offset(y: animateGrid ? 100 : -100)
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
                // Tape case
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .frame(width: 100, height: 60)

                // Cassette label
                RoundedRectangle(cornerRadius: 4)
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
                    .frame(width: 70, height: 30)

                // Reels
                HStack(spacing: 30) {
                    Circle()
                        .stroke(Color.retroBlue, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 12, height: 12)
                        )
                        .rotationEffect(Angle(degrees: rotateReels ? 360 : 0))

                    Circle()
                        .stroke(Color.retroBlue, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .frame(width: 12, height: 12)
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
        let traits = createSkinTraits()

        return Group {
            if let deltaSkin = skin as? DeltaSkin {
                // If we have a DeltaSkin, use the specialized view
                DeltaSkinView(
                    skin: deltaSkin,
                    traits: traits,
                    showDebugOverlay: showDebugOverlay,
                    showHitTestOverlay: false,
                    isInEmulator: true,
                    inputHandler: inputHandler
                )
                .id("skin-view-\(rotationCount)")
            } else {
                // For other skin types
                DeltaSkinView(
                    skin: skin,
                    traits: traits,
                    showDebugOverlay: showDebugOverlay,
                    showHitTestOverlay: false,
                    isInEmulator: true,
                    inputHandler: inputHandler
                )
                .id("async-skin-view-\(rotationCount)")
            }
        }
        .environmentObject(inputHandler)
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

            Text("Orientation: \(currentOrientation.isLandscape ? "Landscape" : "Portrait")")
                .foregroundColor(.white)

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
    }

    /// Refresh the view after orientation changes
    private func refreshView() {
        // This will be called by the parent view controller
        DLOG("🎮 EmulatorWithSkinView: Refreshing view")
    }

    // MARK: - Skin Traits

    /// Create skin traits based on current device and orientation
    private func createSkinTraits() -> DeltaSkinTraits {
        let isLandscape = currentOrientation.isLandscape ||
                         UIDevice.current.orientation == .unknown &&
                         UIScreen.main.bounds.width > UIScreen.main.bounds.height

        // Determine device type
        let deviceType: DeltaSkinDevice
        if UIDevice.current.userInterfaceIdiom == .pad {
            deviceType = .ipad
        } else if UIDevice.current.userInterfaceIdiom == .tv {
            deviceType = .iphone // Use iPhone as fallback since there's no Apple TV option
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

    // MARK: - Loading Logic

    /// Load the skin safely without Realm threading issues
    private func loadSkinSafely() async {
        DLOG("🎮 EmulatorWithSkinView: Starting to load skin safely")

        // If we have a system ID, we can load the skin directly
        if let systemId = systemId {
            _ = await skinLoader.loadSkin(forSystem: systemId, systemName: systemName ?? "Unknown")
        } else {
            ELOG("🎮 EmulatorWithSkinView: No system ID available, cannot load skin")
            await MainActor.run {
                skinLoader.loadingError = NSError(domain: "EmulatorWithSkinView", code: 404, userInfo: [NSLocalizedDescriptionKey: "No system ID available"])
                skinLoader.isLoading = false
                onSkinLoaded() // Still notify that we're done, even with an error
            }
        }
    }
}
