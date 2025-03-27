import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVSystems
import Combine
import ObjectiveC

/// A SwiftUI view that displays a custom skin for the emulator
struct EmulatorWithSkinView: View {
    let game: PVGame
    let coreInstance: PVEmulatorCore

    @EnvironmentObject private var inputHandler: DeltaSkinInputHandler
    @State private var selectedSkin: DeltaSkin?
    @State private var isLoading = true
    @State private var asyncSkin: DeltaSkinProtocol?

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

                if let skin = selectedSkin {
                    // If we have a skin, use DeltaSkinView with input handling
                    DeltaSkinView(
                        skin: skin,
                        traits: createSkinTraits(),
                        showDebugOverlay: showDebugOverlay,
                        showHitTestOverlay: false,
                        isInEmulator: true,  // Set to true to hide test patterns
                        inputHandler: inputHandler
                    )
                    .environmentObject(inputHandler)
                    .id("skin-view-\(rotationCount)") // Force recreation on rotation
                } else if let asyncSkin = asyncSkin {
                    // If we have an async skin, use DeltaSkinView with input handling
                    DeltaSkinView(
                        skin: asyncSkin,
                        traits: createSkinTraits(),
                        showDebugOverlay: showDebugOverlay,
                        showHitTestOverlay: false,
                        isInEmulator: true,  // Set to true to hide test patterns
                        inputHandler: inputHandler
                    )
                    .environmentObject(inputHandler)
                    .id("async-skin-view-\(rotationCount)") // Force recreation on rotation
                } else if isLoading {
                    // Loading indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .foregroundColor(.white)
                } else {
                    // Fallback controller with input handling
                    defaultControllerSkin()
                }

                // Debug overlay
                if showDebugOverlay {
                    VStack(alignment: .leading) {
                        Text("Debug Info")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Skin: \(selectedSkin?.name ?? "None")")
                            .foregroundColor(.white)

                        Text("Orientation: \(currentOrientation.isLandscape ? "Landscape" : "Portrait")")
                            .foregroundColor(.white)

                        Text("Rotation Count: \(rotationCount)")
                            .foregroundColor(.white)

                        Text("Game: \(game.title)")
                            .foregroundColor(.white)

                        Text("System: \(game.system?.name ?? "Unknown")")
                            .foregroundColor(.white)

                        if let core = coreInstance as? NSObject {
                            Text("Core: \(type(of: core))")
                                .foregroundColor(.white)
                        }

                        Button("Refresh GPU View") {
                            NotificationCenter.default.post(name: Notification.Name("RefreshGPUView"), object: nil)
                        }
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        // Add view hierarchy info
                        Text("View Borders:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 8)

                        HStack {
                            Rectangle().fill(Color.yellow).frame(width: 20, height: 20)
                            Text("Main View").foregroundColor(.white)
                        }

                        HStack {
                            Rectangle().fill(Color.red).frame(width: 20, height: 20)
                            Text("Game Screen View").foregroundColor(.white)
                        }

                        HStack {
                            Rectangle().fill(Color.blue).frame(width: 20, height: 20)
                            Text("Skin View").foregroundColor(.white)
                        }

                        HStack {
                            Rectangle().fill(Color.green).frame(width: 20, height: 20)
                            Text("Skin Subviews").foregroundColor(.white)
                        }

                        HStack {
                            Rectangle().fill(Color.orange).frame(width: 20, height: 20)
                            Text("DeltaSkinScreensView").foregroundColor(.white)
                        }

                        HStack {
                            Rectangle().fill(Color.purple).frame(width: 20, height: 20)
                            Text("Screen View").foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

                // Load the appropriate skin
                loadSkin()

                // Set up orientation notification
                setupOrientationNotification()

                // Post a notification to refresh the GPU view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: Notification.Name("RefreshGPUView"), object: nil)
                }

                // Set up a timer to periodically refresh the GPU view
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    NotificationCenter.default.post(name: Notification.Name("RefreshGPUView"), object: nil)
                }
            }
            .onDisappear {
                // Clean up notification
                NotificationCenter.default.removeObserver(self)
            }
            .environment(\.debugSkinMappings, showDebugOverlay)
        }
    }

    /// Load a skin for the current game
    private func loadSkin() {
        Task {
            do {
                if let systemId = game.system?.systemIdentifier {
                    if let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                        DispatchQueue.main.async {
                            // Store the skin in the appropriate property based on its type
                            if let deltaSkin = skin as? DeltaSkin {
                                self.selectedSkin = deltaSkin
                            } else {
                                self.asyncSkin = skin
                            }
                            self.isLoading = false
                        }
                    } else {
                        ELOG("No skin available for system: \(systemId)")
                        // Use a fallback skin or default UI
                    }
                } else {
                    ELOG("No system identifier available for game: \(game.title)")
                    // Use a fallback skin or default UI
                }
            } catch {
                ELOG("Error loading skin: \(error)")
                // Use a fallback skin or default UI
            }
        }
    }

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
            Button(action: {}) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }

            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)

                Button(action: {}) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }

            Button(action: {}) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }

    /// Circle button view
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
    }

    /// Pill-shaped button view
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 30)
                .background(color)
                .cornerRadius(15)
        }
    }

    // Create skin traits based on current device and orientation
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

    // Set up orientation notification
    private func setupOrientationNotification() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isLandscape || newOrientation.isPortrait {
                self.currentOrientation = newOrientation
                self.rotationCount += 1 // Increment rotation count to force view recreation
                print("Orientation changed to: \(newOrientation.isLandscape ? "landscape" : "portrait"), rotation count: \(self.rotationCount)")

                // Post a notification to refresh the GPU view
                NotificationCenter.default.post(name: Notification.Name("RefreshGPUView"), object: nil)
            }
        }
    }
}
