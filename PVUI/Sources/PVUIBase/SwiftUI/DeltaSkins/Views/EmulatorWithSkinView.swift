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

    // State for the skin
    @State private var selectedSkin: DeltaSkin?
    @State private var isLoading = true
    @State private var asyncSkin: DeltaSkinProtocol?

    // State for orientation
    @State private var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation

    // Input handling
    private let inputSubject = PassthroughSubject<DeltaSkinButtonInput, Never>()

    // Debug mode
    @State private var showDebugOverlay = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)

                if let skin = selectedSkin {
                    // If we have a skin, use DeltaSkinScreensView with input handling
                    DeltaSkinScreensView(
                        skin: skin,
                        traits: createSkinTraits(),
                        containerSize: geometry.size
                    )
                    .environmentObject(createInputHandler())
                } else if let asyncSkin = asyncSkin {
                    // If we have an async skin, use DeltaSkinScreensView with input handling
                    DeltaSkinScreensView(
                        skin: asyncSkin,
                        traits: createSkinTraits(),
                        containerSize: geometry.size
                    )
                    .environmentObject(createInputHandler())
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
                // Try to load a skin when the view appears
                Task {
                    await loadSkin()
                }

                // Set up orientation notification
                setupOrientationNotification()
            }
            .onDisappear {
                // Clean up notification
                NotificationCenter.default.removeObserver(self)
            }
            .environment(\.debugSkinMappings, showDebugOverlay)
        }
    }

    /// Load a skin for the current game
    private func loadSkin() async {
        isLoading = true

        // Get the system identifier
        if let systemId = game.system?.systemIdentifier {
            print("Loading skin for system: \(systemId)")

            // Try to get a skin from the manager using our new synchronous method
            selectedSkin = await DeltaSkinManager.shared.skin(for: systemId)

            if selectedSkin != nil {
                print("Successfully loaded skin for \(systemId): \(selectedSkin!.name)")
                isLoading = false
            } else {
                print("No skin available from sync method for \(systemId)")

                // Try to get all skins for this system synchronously
                let systemSkins = await DeltaSkinManager.shared.availableSkinsSync(for: systemId)
                print("Available skins (sync): \(systemSkins.count)")

                // If there are any skins, use the first one
                if let firstSkin = systemSkins.first {
                    selectedSkin = firstSkin
                    print("Using first available skin (sync): \(firstSkin.name)")
                    isLoading = false
                } else {
                    // Try to get a skin asynchronously
                    Task {
                        do {
                            // Try to get the skin to use
                            asyncSkin = try await DeltaSkinManager.shared.skinToUse(for: systemId)

                            if asyncSkin != nil {
                                print("Loaded async skin for \(systemId): \(asyncSkin!.identifier)")
                            } else {
                                print("No async skin available for \(systemId)")

                                // Try to get all skins for this system
                                let systemSkins = try await DeltaSkinManager.shared.availableSkins(for: systemId)
                                print("Available skins (async): \(systemSkins.count)")

                                // If there are any skins, use the first one
                                if let firstSkin = systemSkins.first {
                                    await MainActor.run {
                                        selectedSkin = firstSkin as? DeltaSkin
                                    }
                                    print("Using first available skin (async): \(firstSkin.identifier)")
                                }
                            }
                        } catch {
                            print("Error loading async skin: \(error)")
                        }

                        // Update loading state on the main thread
                        await MainActor.run {
                            isLoading = false
                        }
                    }
                }
            }
        } else {
            print("No system identifier available for game: \(game.title)")
            isLoading = false
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

    // Create input handler for the skin
    private func createInputHandler() -> DeltaSkinInputHandler {
        let handler = DeltaSkinInputHandler()

        // Set up the handler to forward inputs to the emulator core
        handler.onButtonInput = { input in
            handleButtonInput(input)
        }

        return handler
    }

    // Handle button input from the skin
    private func handleButtonInput(_ input: DeltaSkinButtonInput) {
        print("Button input: \(input.button), pressed: \(input.isPressed), x: \(input.x), y: \(input.y)")

        // Handle analog sticks
        if case .analogLeft = input.button {
            // Try to set analog values using a more generic approach
            print("Setting left analog stick: x=\(input.x), y=\(input.y)")

            // Try different methods that might exist
            if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("setAnalogJoypadAxisValue:forAxis:forPlayer:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Float, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("setAnalogJoypadAxisValue:forAxis:forPlayer:"), input.x, 0, 0)
                function(coreInstance, NSSelectorFromString("setAnalogJoypadAxisValue:forAxis:forPlayer:"), input.y, 1, 0)
            } else if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("setAnalogValue:forAxis:player:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Float, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("setAnalogValue:forAxis:player:"), input.x, 0, 0)
                function(coreInstance, NSSelectorFromString("setAnalogValue:forAxis:player:"), input.y, 1, 0)
            }
            return
        } else if case .analogRight = input.button {
            // Try to set analog values using a more generic approach
            print("Setting right analog stick: x=\(input.x), y=\(input.y)")

            // Try different methods that might exist
            if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("setAnalogJoypadAxisValue:forAxis:forPlayer:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Float, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("setAnalogJoypadAxisValue:forAxis:forPlayer:"), input.x, 2, 0)
                function(coreInstance, NSSelectorFromString("setAnalogJoypadAxisValue:forAxis:forPlayer:"), input.y, 3, 0)
            } else if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("setAnalogValue:forAxis:player:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Float, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("setAnalogValue:forAxis:player:"), input.x, 2, 0)
                function(coreInstance, NSSelectorFromString("setAnalogValue:forAxis:player:"), input.y, 3, 0)
            }
            return
        }

        // Handle digital buttons
        if input.isPressed {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif

            // Map button to player input
            let buttonIndex: Int
            switch input.button {
            case .dpadUp:
                buttonIndex = 0
            case .dpadDown:
                buttonIndex = 1
            case .dpadLeft:
                buttonIndex = 2
            case .dpadRight:
                buttonIndex = 3
            case .buttonA:
                buttonIndex = 4
            case .buttonB:
                buttonIndex = 5
            case .buttonX:
                buttonIndex = 6
            case .buttonY:
                buttonIndex = 7
            case .buttonL:
                buttonIndex = 8
            case .buttonR:
                buttonIndex = 9
            case .buttonStart:
                buttonIndex = 10
            case .buttonSelect:
                buttonIndex = 11
            case .custom(let id):
                // Handle custom buttons based on ID
                handleCustomButton(id, pressed: true)
                return
            default:
                return
            }

            // Use the correct method to press the button
            if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("player:didPressButton:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("player:didPressButton:"), 0, buttonIndex)
            } else if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("pushButton:forPlayer:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("pushButton:forPlayer:"), buttonIndex, 0)
            }
        } else {
            // Map button to player input
            let buttonIndex: Int
            switch input.button {
            case .dpadUp:
                buttonIndex = 0
            case .dpadDown:
                buttonIndex = 1
            case .dpadLeft:
                buttonIndex = 2
            case .dpadRight:
                buttonIndex = 3
            case .buttonA:
                buttonIndex = 4
            case .buttonB:
                buttonIndex = 5
            case .buttonX:
                buttonIndex = 6
            case .buttonY:
                buttonIndex = 7
            case .buttonL:
                buttonIndex = 8
            case .buttonR:
                buttonIndex = 9
            case .buttonStart:
                buttonIndex = 10
            case .buttonSelect:
                buttonIndex = 11
            case .custom(let id):
                // Handle custom buttons based on ID
                handleCustomButton(id, pressed: false)
                return
            default:
                return
            }

            // Use the correct method to release the button
            if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("player:didReleaseButton:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("player:didReleaseButton:"), 0, buttonIndex)
            } else if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("releaseButton:forPlayer:")) {
                let imp = method_getImplementation(method)
                let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector, Int, Int) -> Void).self)
                function(coreInstance, NSSelectorFromString("releaseButton:forPlayer:"), buttonIndex, 0)
            }
        }
    }

    // Handle custom buttons
    private func handleCustomButton(_ id: String, pressed: Bool) {
        // Map custom button IDs to actions
        switch id.lowercased() {
        case "menu":
            if pressed {
                // Show menu
                NotificationCenter.default.post(name: Notification.Name("PauseGame"), object: nil)
            }
        case "togglefastforward":
            if pressed {
                // Toggle fast forward - check if the method exists
                if let method = class_getInstanceMethod(type(of: coreInstance), NSSelectorFromString("toggleFastForward")) {
                    let imp = method_getImplementation(method)
                    let function = unsafeBitCast(imp, to: (@convention(c) (Any, Selector) -> Void).self)
                    function(coreInstance, NSSelectorFromString("toggleFastForward"))
                } else {
                    // Fallback - try to set a fast forward flag if available
                    print("Fast forward not supported by this core")
                }
            }
        default:
            print("Unknown custom button: \(id)")
        }
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
                print("Orientation changed to: \(newOrientation.isLandscape ? "landscape" : "portrait")")
            }
        }
    }
}

// Input handler for Delta Skin
class DeltaSkinInputHandler: ObservableObject {
    var onButtonInput: ((DeltaSkinButtonInput) -> Void)?

    func handleButtonInput(_ input: DeltaSkinButtonInput) {
        onButtonInput?(input)
    }
}

// Button input structure
struct DeltaSkinButtonInput {
    enum Button {
        case dpadUp, dpadDown, dpadLeft, dpadRight
        case buttonA, buttonB, buttonX, buttonY
        case buttonL, buttonR, buttonL2, buttonR2
        case buttonStart, buttonSelect, buttonHome
        case analogLeft, analogRight
        case custom(String)
    }

    let button: Button
    let isPressed: Bool
    let x: Float
    let y: Float

    init(button: Button, isPressed: Bool, x: Float = 0, y: Float = 0) {
        self.button = button
        self.isPressed = isPressed
        self.x = x
        self.y = y
    }
}
