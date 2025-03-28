import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVSystems
import Combine
import ObjectiveC
import PVLogging

/// A SwiftUI view that displays a custom skin for the emulator
struct EmulatorWithSkinView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore
    let onSkinLoaded: () -> Void
    let onRefreshRequested: () -> Void
    let onMenuRequested: () -> Void

    @EnvironmentObject private var inputHandler: DeltaSkinInputHandler
    @StateObject private var skinLoader = DeltaSkinLoader()
    @State private var skinRenderComplete = false

    // State for orientation
    @State private var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation

    // Input handling
    private let inputSubject = PassthroughSubject<String, Never>()

    // Debug mode
    @State private var showDebugOverlay = false

    // Add this to the struct to track rotation changes
    @State private var rotationCount: Int = 0

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
                        .onAppear {
                            // When the skin content appears, mark as complete after a short delay
                            // to ensure it's fully rendered
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if !skinRenderComplete {
                                    skinRenderComplete = true
                                    onSkinLoaded()
                                    DLOG("🎮 EmulatorWithSkinView: Skin render complete, notifying observers")
                                }
                            }
                        }
                } else {
                    // Fallback controller with input handling
                    defaultControllerSkin()
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
            .onAppear {
                // Set the emulator core in the input handler
                inputHandler.setEmulatorCore(coreInstance)

                // Update the menu button handler to use the direct callback
                inputHandler.menuButtonHandler = {
                    onMenuRequested()
                }

                // Start loading the skin
                Task {
                    _ = await skinLoader.loadSkin(for: game)
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
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            Text("Loading \(game.system?.name ?? "Game") Skin...")
                .font(.headline)
                .foregroundColor(.white)

            ProgressView(value: skinLoader.loadingProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(width: 200)

            Text(skinLoader.loadingStage.rawValue)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
        )
        .shadow(radius: 10)
    }

    // MARK: - Skin Content View

    private func skinContentView(skin: DeltaSkinProtocol, geometry: GeometryProxy) -> some View {
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

            Text("Game: \(game.title)")
                .foregroundColor(.white)

            Text("System: \(game.system?.name ?? "Unknown")")
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

    // MARK: - Default Controller

    /// Default controller skin as a fallback
    private func defaultControllerSkin() -> some View {
        VStack(spacing: 20) {
            // D-Pad
            dPadView()

            // Action buttons
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    circleButton(label: "Y", color: .yellow)
                    circleButton(label: "X", color: .blue)
                }

                VStack(spacing: 10) {
                    circleButton(label: "B", color: .red)
                    circleButton(label: "A", color: .green)
                }
            }

            // Start/Select buttons
            HStack(spacing: 20) {
                pillButton(label: "SELECT", color: .black)
                pillButton(label: "START", color: .black)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.5))
        .cornerRadius(20)
    }

    /// D-Pad view
    private func dPadView() -> some View {
        VStack(spacing: 0) {
            Button(action: { inputHandler.buttonPressed("up") }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in inputHandler.buttonReleased("up") }
            )

            HStack(spacing: 0) {
                Button(action: { inputHandler.buttonPressed("left") }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in inputHandler.buttonReleased("left") }
                )

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)

                Button(action: { inputHandler.buttonPressed("right") }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in inputHandler.buttonReleased("right") }
                )
            }

            Button(action: { inputHandler.buttonPressed("down") }) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in inputHandler.buttonReleased("down") }
            )
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }

    /// Circle button view
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
    }

    /// Pill-shaped button view
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 30)
                .background(color)
                .cornerRadius(15)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
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
}
