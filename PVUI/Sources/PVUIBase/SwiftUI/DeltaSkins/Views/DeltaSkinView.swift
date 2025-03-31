import SwiftUI
import AudioToolbox
import AVFoundation  // Add this for audio buffer types
import PVLogging
import PVEmulatorCore

/// Core view for rendering a DeltaSkin with test patterns and interactive elements
public struct DeltaSkinView: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let showDebugOverlay: Bool
    let showHitTestOverlay: Bool
    let screenAspectRatio: CGFloat?  // Optional aspect ratio
    let isInEmulator: Bool
    let inputHandler: DeltaSkinInputHandler

    /// State for touch and button interactions
    @State private var touchLocation: CGPoint?
    @State private var activeButton: (frame: CGRect, mappingSize: CGSize, buttonId: String)?
    @State private var lastButtonPressed: String?
    @State private var isButtonHapticEnabled = true  // Add this state

    /// State for skin loading
    @State private var skinImage: UIImage?
    @State private var thumbstickImage: UIImage?

    @State private var activeThumbsticks: [(frame: CGRect, image: UIImage, size: CGSize)] = []

    // Add feedback generator
    #if !os(tvOS)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    // Audio engine for positional audio
    private static let audioEngine = AudioEngine()

    // Single set of sound IDs without left/right variants
    internal static let buttonSounds: [String: PCMBuffer] = createButtonSounds()

    // Track multiple active buttons
    @State private var activeButtons: [(frame: CGRect, mappingSize: CGSize, buttonId: String, timestamp: Date)] = []

    // Track the currently pressed button
    @State private var currentlyPressedButton: DeltaSkinButton?
    
    // Track the current preview size
    @State private var previewSize: CGSize = .zero

    /// State for the loaded skin image
    @State private var loadingError: Error?
    @State private var screenGroups: [DeltaSkinScreenGroup]?
    @State private var buttonMappings: [DeltaSkinButtonMapping]?

    @State private var pressedButtons: Set<String> = []

    private static func createButtonSounds() -> [String: PCMBuffer] {
        let soundConfigs = [
            ("dpad", 1800.0, 0.5, 0.4),     // (name, frequency, volume, noise)
            ("small", 2200.0, 0.6, 0.3),
            ("medium", 1900.0, 0.5, 0.35),
            ("large", 1600.0, 0.4, 0.45)
        ]

        var sounds: [String: PCMBuffer] = [:]
        for (name, freq, vol, noise) in soundConfigs {
            if let buffer = createClickBuffer(
                frequency: freq,
                volume: vol,
                noiseAmount: noise
            ) {
                sounds[name] = buffer
            }
        }

        sounds["thumbstick_release"] = createThumbstickReleaseBuffer()
        return sounds
    }

    private static func createClickBuffer(
        frequency: Double,
        volume: Double,
        noiseAmount: Double
    ) -> PCMBuffer? {
        let sampleRate = 44100.0
        let duration = 0.02
        let numSamples = Int(duration * sampleRate)

        guard let buffer = PCMBuffer(
            sampleRate: sampleRate,
            channels: 1,
            frames: UInt32(numSamples)
        ) else { return nil }

        guard let data = buffer.getChannelData() else { return nil }

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate

            // Main tone with pitch drop
            let freqDrop = frequency * (1.0 - t * 4)
            let mainTone = sin(2.0 * .pi * freqDrop * t)

            // Add noise for mechanical feel
            let noise = Double.random(in: -1.0...1.0) * noiseAmount

            // Envelope
            let envelope = exp(-t * 200) * (1.0 - exp(-t * 3000))

            // Combine components
            data[i] = Float(volume * (mainTone + noise) * envelope)
        }

        return buffer
    }

    private static func createThumbstickReleaseBuffer() -> PCMBuffer? {
        let sampleRate = 44100.0
        let duration = 0.06  // Shorter duration (60ms)
        let numSamples = Int(duration * sampleRate)
        var samples = [Int16]()

        // Create mechanical spring release sound
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate

            // Lower frequency sweep for more mechanical feel
            let frequency = 800.0 + (400.0 * exp(-t * 50))  // Lower base frequency

            // Plastic impact noise
            let noise = Double.random(in: -0.5...0.5)

            // Lower frequency modulation for subtle rattle
            let rattle = sin(2.0 * .pi * 60.0 * t)  // Slower modulation

            // Quick attack, medium decay
            let envelope = 0.5 * exp(-t * 40)  // Softer volume, medium decay

            // Combine components with adjusted mix
            let sample = Int16(32767.0 * envelope * (
                0.5 * sin(2.0 * .pi * frequency * t) +  // Main tone (reduced)
                0.3 * noise +                           // More plastic noise
                0.2 * rattle                           // Subtle rattle
            ))

            samples.append(sample)
        }

        return createWavBuffer(name: "thumbstick_release", samples: samples, sampleRate: sampleRate)
    }

    private static func createWavBuffer(name: String, samples: [Int16], sampleRate: Double) -> PCMBuffer? {
        // Create mono buffer
        guard let buffer = PCMBuffer(
            sampleRate: sampleRate,
            channels: 1,  // Always create mono buffers
            frames: UInt32(samples.count)
        ) else { return nil }

        // Copy samples to buffer
        guard let data = buffer.getChannelData() else { return nil }

        for i in 0..<samples.count {
            data[i] = Float(samples[i]) / 32767.0  // Convert to float [-1, 1]
        }

        return buffer
    }

    public init(
        skin: any DeltaSkinProtocol,
        traits: DeltaSkinTraits,
        filters: Set<TestPatternEffect> = [],
        showDebugOverlay: Bool = false,
        showHitTestOverlay: Bool = false,
        screenAspectRatio: CGFloat? = nil,
        isInEmulator: Bool = false,
        inputHandler: DeltaSkinInputHandler
    ) {
        self.skin = skin
        self.traits = traits
        self.filters = filters
        self.showDebugOverlay = showDebugOverlay
        self.showHitTestOverlay = showHitTestOverlay
        self.screenAspectRatio = screenAspectRatio
        self.isInEmulator = isInEmulator
        self.inputHandler = inputHandler
    }

    internal struct SkinLayout: Equatable, Hashable {
        let scale: CGFloat
        let width: CGFloat
        let height: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat
    }

    private func hasScreenPosition(for traits: DeltaSkinTraits) -> Bool {
        // Check both formats
        if let screens = skin.screens(for: traits), !screens.isEmpty {
            return true
        }

        // Check if representation has gameScreenFrame
        if let representations = skin.jsonRepresentation["representations"] as? [String: Any],
           let deviceRep = representations[traits.device.rawValue] as? [String: Any],
           let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
           let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
           orientationRep["gameScreenFrame"] != nil {
            return true
        }

        return false
    }

    internal func calculateLayout(for geometry: GeometryProxy) -> SkinLayout? {
        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

        // Calculate the scale to fit the skin in the available space
        var scale: CGFloat

        // For portrait mode on iPhone, prioritize filling width while maintaining aspect ratio
        if traits.device == .iphone && traits.orientation == .portrait {
            // Start with width scale to fill screen
            scale = geometry.size.width / mappingSize.width

            // Calculate resulting height
            let scaledHeight = mappingSize.height * scale

            // If height exceeds screen, scale down while maintaining aspect ratio
            if scaledHeight > geometry.size.height {
                let heightScale = geometry.size.height / mappingSize.height
                scale = min(scale, heightScale)
            }
        } else {
            // For landscape, use standard fit scaling
            scale = min(
                geometry.size.width / mappingSize.width,
                geometry.size.height / mappingSize.height
            )
        }

        let scaledWidth = mappingSize.width * scale
        let scaledHeight = mappingSize.height * scale

        // Center horizontally
        let xOffset = (geometry.size.width - scaledWidth) / 2

        // For portrait mode on iPhone, position at bottom of screen
        // For landscape or iPad, center vertically
        let yOffset: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Position at bottom of screen
            yOffset = geometry.size.height - scaledHeight
        } else {
            // Center vertically
            yOffset = (geometry.size.height - scaledHeight) / 2
        }

        return SkinLayout(
            scale: scale,
            width: scaledWidth,
            height: scaledHeight,
            xOffset: xOffset,
            yOffset: yOffset
        )
    }

    private func logLayoutInfo(geometry: GeometryProxy, layout: SkinLayout) {
        let debugInfo = """
        ===== DeltaSkinView Layout Info =====
        Device: \(traits.device.rawValue)
        Display Type: \(traits.displayType.rawValue)
        Orientation: \(traits.orientation.rawValue)

        Container Info:
          Size: \(geometry.size)
          Safe Area: \(geometry.safeAreaInsets)
          Frame: \(geometry.frame(in: .global))
          Local Frame: \(geometry.frame(in: .local))

        Skin Info:
          Name: \(skin.name)
          Mapping Size: \(skin.mappingSize(for: traits) ?? .zero)
          Has Screen Position: \(hasScreenPosition(for: traits))
          Screen Frame: \(skin.screens(for: traits)?.first?.outputFrame ?? .zero)

        Layout Calculations:
          Scale: \(layout.scale)
          Width: \(layout.width)
          Height: \(layout.height)
          X Offset: \(layout.xOffset)
          Y Offset: \(layout.yOffset)

        Position Calculations:
          Bottom Edge: \(layout.yOffset + layout.height)
          Screen Bottom: \(geometry.size.height)
          Safe Area Bottom: \(geometry.size.height - geometry.safeAreaInsets.bottom)
          Center Y Position: \(geometry.size.height - (layout.height / 2) - geometry.safeAreaInsets.bottom)
          Final Frame: \(CGRect(x: layout.xOffset, y: layout.yOffset, width: layout.width, height: layout.height))

        Screen Layer Info:
          Container Height: \(geometry.size.height)
          Available Space: \(geometry.size.height - layout.height)
          Screen Dimensions: \(calculateScreenDimensions(in: geometry))

        Button Layout:
        \(skin.buttons(for: traits)?.enumerated().map { index, button in
            """
              Button \(index): \(button.id)
                Frame: \(button.frame)
                Scaled Frame: \(scaledButtonFrame(button.frame, layout: layout, in: geometry))
                Extended Edges: \(button.extendedEdges ?? .zero)
            """
        }.joined(separator: "\n") ?? "No buttons")

        Parent Context:
          Safe Area Insets: \(UIApplication.shared.windows.first?.safeAreaInsets ?? .zero)
          Screen Bounds: \(UIScreen.main.bounds)
          Scale: \(UIScreen.main.scale)
        =================================
        """

        DLOG("Layout Debug:\n\(debugInfo)")
    }

    // Helper function to calculate scaled button frames
    private func scaledButtonFrame(_ frame: CGRect, layout: SkinLayout, in geometry: GeometryProxy) -> CGRect {
        CGRect(
            x: frame.minX * layout.scale + layout.xOffset,
            y: frame.minY * layout.scale + layout.yOffset,
            width: frame.width * layout.scale,
            height: frame.height * layout.scale
        )
    }

    // Helper function to calculate screen dimensions
    private func calculateScreenDimensions(in geometry: GeometryProxy) -> String { 
        guard let mappingSize = skin.mappingSize(for: traits) else { return "No mapping size" }

        let availableWidth = geometry.size.width
        let availableHeight = geometry.size.height
        let aspectRatio = mappingSize.width / mappingSize.height

        let maxWidth = availableWidth
        let maxHeight = availableHeight

        let width = min(maxWidth, maxHeight * aspectRatio)
        let height = width / aspectRatio

        return """
        Width: \(width)
        Height: \(height)
        Aspect Ratio: \(aspectRatio)
        Available Space: \(availableWidth)x\(availableHeight)
        """
    }

    public var body: some View {
        GeometryReader { geometry in
            // Store the geometry size for coordinate transformations
            Color.clear.onAppear {
                self.previewSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                self.previewSize = newSize
            }
            ZStack {
                if let layout = calculateLayout(for: geometry) {
                    ZStack {
                        // Always create a screen position wrapper, even when in emulator
                        // This ensures we can get the correct position whether color bars are visible or not
                        DeltaSkinScreenPositionWrapper(
                            skin: skin,
                            traits: traits,
                            filters: filters,
                            size: geometry.size,
                            screenAspectRatio: screenAspectRatio,
                            isInEmulator: isInEmulator
                        )
                        .zIndex(0)

                        // Base skin image
                        if let skinImage = skinImage {
                            Image(uiImage: skinImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: layout.width, height: layout.height)
                        } else {
                            // Loading placeholder
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: layout.width, height: layout.height)
                        }

                        // Screen groups
                        if let groups = screenGroups {
                            ForEach(groups, id: \.id) { group in
                                screenGroup(group, in: geometry, layout: layout)
                            }
                        }

                        // Button mappings
                        if let mappings = buttonMappings {
                            ForEach(mappings, id: \.id) { mapping in
                                buttonMapping(mapping, in: geometry, layout: layout)
                            }
                        }

                        // Debug/hit test overlays
                        if showDebugOverlay {
                            DeltaSkinDebugOverlay(
                                skin: skin,
                                traits: traits,
                                size: geometry.size
                            )
                            .zIndex(2)
                        }
                        if showHitTestOverlay {
                            DeltaSkinHitTestOverlay(
                                skin: skin,
                                traits: traits,
                                size: geometry.size
                            )
                            .zIndex(2)
                        }

                        // Effects and thumbsticks inside the skin container
                        ForEach(activeButtons, id: \.timestamp) { button in
                            DeltaSkinButtonHighlight(
                                frame: button.frame,
                                mappingSize: button.mappingSize,
                                previewSize: geometry.size,
                                buttonId: button.buttonId
                            )
                            .zIndex(3)
                        }

                        // Thumbstick layer - should be on top
                        ForEach(activeThumbsticks, id: \.frame) { thumbstick in
                            DeltaSkinThumbstick(
                                frame: thumbstick.frame,
                                thumbstickImage: thumbstick.image,
                                thumbstickSize: thumbstick.size,
                                mappingSize: skin.mappingSize(for: traits) ?? .zero
                            )
                            .zIndex(4)
                        }

                        // Touch indicators - always on top
                        if let location = touchLocation {
                            DeltaSkinTouchIndicator(at: location)
                                .zIndex(5)
                        }
                    }
                    .frame(width: layout.width, height: layout.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - layout.height / 2)
                    .environment(\.skinLayout, layout)
                    .onAppear {
                        DLOG("DeltaSkinView appeared")
                        logLayoutInfo(geometry: geometry, layout: layout)
                        loadSkinResources()
                    }
                }

                // Only show test patterns if not in emulator mode
                if !isInEmulator, let layout = calculateLayout(for: geometry) {
                    // Test pattern container
                    ZStack {
                        // Only show in preview mode, not in emulator
                        if let screens = skin.screens(for: traits) {
                            ForEach(screens, id: \.id) { screen in
                                if let outputFrame = screen.outputFrame {
                                    let scaledFrame = CGRect(
                                        x: outputFrame.minX * layout.width,
                                        y: outputFrame.minY * layout.height,
                                        width: outputFrame.width * layout.width,
                                        height: outputFrame.height * layout.height
                                    )

                                    DeltaSkinTestPatternView(
                                        frame: CGRect(
                                            x: 0,
                                            y: 0,
                                            width: scaledFrame.width,
                                            height: scaledFrame.height
                                        ),
                                        filters: filters
                                    )
                                    .frame(width: scaledFrame.width, height: scaledFrame.height)
                                    .position(x: scaledFrame.midX, y: scaledFrame.midY)
                                }
                            }
                        }
                    }
                    .frame(width: layout.width, height: layout.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - layout.height / 2)
                }
            }
            .onChange(of: geometry.size) { newSize in
                DLOG("Container size changed to: \(newSize)")
                if let layout = calculateLayout(for: geometry) {
                    logLayoutInfo(geometry: geometry, layout: layout)
                }
            }
            .onChange(of: traits) { newTraits in
                DLOG("Traits changed to: \(newTraits)")
                if let layout = calculateLayout(for: geometry) {
                    logLayoutInfo(geometry: geometry, layout: layout)
                }
            }
            #if !os(tvOS)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleTouch(at: value.location, in: geometry.size)
                    }
                    .onEnded { _ in
                        // Play release sound if we had a pressed button
                        if let button = currentlyPressedButton,
                           let mappingSize = skin.mappingSize(for: traits) {
                            // Use same position calculations for consistent audio
                            let panPosition = Float((button.frame.midX / mappingSize.width) * 2 - 1)
                            let area = button.frame.width * button.frame.height
                            let maxArea = mappingSize.width * mappingSize.height
                            let normalizedSize = Float((area / maxArea) * 0.5 + 0.5)

                            // Play release sound using current sound setting
                            let soundType = Defaults[.buttonSound]
                            ButtonSoundGenerator.shared.playButtonReleaseSound(
                                sound: soundType,
                                pan: panPosition,
                                volume: normalizedSize
                            )
                            
                            // Extract the input command and call the input handler's buttonReleased method
                            let inputCommand = extractInputCommand(from: button)
                            inputHandler.buttonReleased(inputCommand)
                        }

                        touchLocation = nil
                        currentlyPressedButton = nil
                    }
            )
            #endif
        }
    }

    private func loadSkinResources() {
        Task {
            // Load skin image
            do {
                skinImage = try await skin.image(for: traits)
                DLOG("Loaded skin image: \(skinImage?.size ?? .zero)")
            } catch {
                loadingError = error
                ELOG("Error loading skin image: \(error)")
            }

            // Load screen groups
            screenGroups = skin.screenGroups(for: traits)
            DLOG("Loaded screen groups: \(screenGroups?.count ?? 0)")

            // Load button mappings
            buttonMappings = skin.buttonMappings(for: traits)
            DLOG("Loaded button mappings: \(buttonMappings?.count ?? 0)")
        }
    }

    private func loadThumbstickImage(for button: DeltaSkinButton) async -> (UIImage, CGSize)? {
        guard let items = skin.jsonRepresentation["representations"] as? [String: Any],
              let deviceItems = items[traits.device.rawValue] as? [String: Any],
              let displayItems = deviceItems[traits.displayType.rawValue] as? [String: Any],
              let orientationItems = displayItems[traits.orientation.rawValue] as? [String: Any],
              let buttonItems = orientationItems["items"] as? [[String: Any]] else {
            return nil
        }

        // Find matching button item
        guard let item = buttonItems.first(where: { item in
            guard let frame = item["frame"] as? [String: Any],
                  let x = frame["x"] as? CGFloat,
                  let y = frame["y"] as? CGFloat,
                  let width = frame["width"] as? CGFloat,
                  let height = frame["height"] as? CGFloat else {
                return false
            }
            return CGRect(x: x, y: y, width: width, height: height) == button.frame
        }),
        let thumbstick = item["thumbstick"] as? [String: Any],
        let imageName = thumbstick["name"] as? String,
        let width = thumbstick["width"] as? CGFloat,
        let height = thumbstick["height"] as? CGFloat else {
            return nil
        }

        do {
            let image = try await skin.loadThumbstickImage(named: imageName)
            return (image, CGSize(width: width, height: height))
        } catch {
            ELOG("Failed to load thumbstick image: \(error)")
            return nil
        }
    }

    private func playClickSound(for button: DeltaSkinButton) {
        guard let mappingSize = skin.mappingSize(for: traits) else { return }

        // Calculate pan position based on button location (-1...1)
        let panPosition = Float((button.frame.midX / mappingSize.width) * 2 - 1)

        // Calculate volume based on button size (0.5...1.0)
        let area = button.frame.width * button.frame.height
        let maxArea = (mappingSize.width * mappingSize.height / 2)
        let normalizedSize = Float((area / maxArea) * 0.5 + 0.5)

        ButtonSoundGenerator.shared.playButtonPressSound(pan: panPosition, volume: normalizedSize)
    }

    private func handleTouch(at location: CGPoint, in size: CGSize) {
        // Store the touch location for visual feedback and direction detection
        touchLocation = location

        guard let buttons = skin.buttons(for: traits),
              let mappingSize = skin.mappingSize(for: traits) else { return }

        // Use same transformation as hit test overlay
        let scale = min(
            size.width / mappingSize.width,
            size.height / mappingSize.height
        )

        let scaledSkinWidth = mappingSize.width * scale
        let scaledSkinHeight = mappingSize.height * scale
        let xOffset = (size.width - scaledSkinWidth) / 2

        // Check if skin has fixed screen position
        let hasScreenPosition = skin.screens(for: traits) != nil

        // Calculate Y offset based on skin type
        let yOffset: CGFloat = hasScreenPosition ?
            ((size.height - scaledSkinHeight) / 2) :
            (size.height - scaledSkinHeight)

        // Find the button being touched
        var touchedButton: DeltaSkinButton?
        var isDPadButton = false
        
        // First check if we're already pressing a D-pad button and still within its extended hit area
        if let currentButton = currentlyPressedButton, case .directional = currentButton.input {
            // For D-pad, use a larger hit area to allow sliding between directions
            let extendedHitFrame = currentButton.frame.insetBy(dx: -40, dy: -40) // Larger hit area for D-pad
            let scaledFrame = CGRect(
                x: extendedHitFrame.minX * scale + xOffset,
                y: yOffset + (extendedHitFrame.minY * scale),
                width: extendedHitFrame.width * scale,
                height: extendedHitFrame.height * scale
            )
            
            if scaledFrame.contains(location) {
                touchedButton = currentButton
                isDPadButton = true
                DLOG("Still within D-pad extended hit area")
            } else {
                // We've moved outside the D-pad hit area, release the current direction
                let inputCommand = extractInputCommand(from: currentButton)
                DLOG("Moved outside D-pad area - releasing direction: \(inputCommand)")
                inputHandler.buttonReleased(inputCommand)
                currentlyPressedButton = nil
            }
        }
        
        // If we're not continuing with a D-pad press, check all buttons normally
        if !isDPadButton {
            for button in buttons {
                let hitFrame = button.frame.insetBy(dx: -20, dy: -20)
                let scaledFrame = CGRect(
                    x: hitFrame.minX * scale + xOffset,
                    y: yOffset + (hitFrame.minY * scale),
                    width: hitFrame.width * scale,
                    height: hitFrame.height * scale
                )

                if scaledFrame.contains(location) {
                    touchedButton = button
                    break
                }
            }
        }

        // Handle button state changes
        if let button = touchedButton {
            if isThumbstick(button) {
                // Handle thumbstick
                Task {
                    if let (image, size) = await loadThumbstickImage(for: button) {
                        activeThumbsticks.append((frame: button.frame, image: image, size: size))
                    }
                }
            } else if case .directional = button.input {
                // Special handling for D-pad buttons to allow direction changes
                handleDPadInput(button, scale: scale, xOffset: xOffset, yOffset: yOffset, mappingSize: mappingSize)
            } else if button != currentlyPressedButton {
                // For non-D-pad buttons, only trigger effects for new button presses
                // Release any previous button first
                if let previousButton = currentlyPressedButton {
                    let previousCommand = extractInputCommand(from: previousButton)
                    DLOG("Releasing previous button: \(previousCommand)")
                    inputHandler.buttonReleased(previousCommand)
                }
                
                // Set the new button as current
                currentlyPressedButton = button

                // Add visual feedback
                let highlightButtonId = button.id
                
                let newButton = (
                    frame: button.frame,
                    mappingSize: mappingSize,
                    buttonId: highlightButtonId,
                    timestamp: Date()
                )
                activeButtons.append(newButton)
                #if !os(tvOS)
                buttonGenerator.impactOccurred(intensity: 0.8)
                #endif
                // Play sound with current position
                playClickSound(for: button)
                
                // Extract the input command
                let inputCommand = extractInputCommand(from: button)
                
                // Log both the input command and the highlight button ID
                DLOG("Button press - inputCommand: \(inputCommand), highlightButtonId: \(highlightButtonId)")
                
                // Use the input handler for all buttons
                // The input handler will determine whether to use the controller or core
                inputHandler.buttonPressed(inputCommand)

                // Clean up old highlights after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    activeButtons.removeAll { $0.timestamp <= newButton.timestamp }
                }
            }
        
        } else if let previousButton = currentlyPressedButton {
            // Touch is not on any button, but we had a pressed button
            // Extract the input command using the proper method
            let inputCommand = extractInputCommand(from: previousButton)
            
            // Log the input command for release
            DLOG("Button release - inputCommand: \(inputCommand)")
            
            // Use the input handler for all buttons
            // The input handler will determine whether to use the controller or core
            inputHandler.buttonReleased(inputCommand)
            currentlyPressedButton = nil
        } else {
            // Touch is not on any button and no previous button was pressed
            currentlyPressedButton = nil
        }
    }

    #if !os(tvOS)
    private let buttonGenerator: UIImpactFeedbackGenerator = {
        // Haptic feedback
        let buttonGenerator = UIImpactFeedbackGenerator(style: .medium)
        buttonGenerator.prepare()
        return buttonGenerator
    }()
    #endif

    private func transformFrame(_ frame: CGRect, in geometry: GeometryProxy, mappingSize: CGSize) -> CGRect {
        let scale = min(
            geometry.size.width / mappingSize.width,
            geometry.size.height / mappingSize.height
        )

        let scaledSkinWidth = mappingSize.width * scale
        let scaledSkinHeight = mappingSize.height * scale
        let xOffset = (geometry.size.width - scaledSkinWidth) / 2

        // Check if skin has fixed screen position
        let hasScreenPosition = skin.screens(for: traits) != nil

        // Calculate Y offset based on skin type
        let yOffset: CGFloat = hasScreenPosition ?
            ((geometry.size.height - scaledSkinHeight) / 2) :
            (geometry.size.height - scaledSkinHeight)

        return CGRect(
            x: frame.minX * scale + xOffset,
            y: yOffset + (frame.minY * scale),
            width: frame.width * scale,
            height: frame.height * scale
        )
    }

    /// Handle D-pad input with support for direction changes
    private func handleDPadInput(_ button: DeltaSkinButton, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat, mappingSize: CGSize) {
        guard let touchLocation = touchLocation else { return }
        
        // Calculate the button center in view coordinates
        let buttonCenterX = button.frame.midX * scale + xOffset
        let buttonCenterY = button.frame.midY * scale + yOffset
        
        // Calculate the touch position relative to the button center
        let relativeX = touchLocation.x - buttonCenterX
        let relativeY = touchLocation.y - buttonCenterY
        
        // Define the center dead zone (15% of button size - smaller dead zone)
        let buttonWidth = button.frame.width * scale
        let buttonHeight = button.frame.height * scale
        let deadZoneRadius = min(buttonWidth, buttonHeight) * 0.15
        
        // Add debug logging to help diagnose direction issues
        DLOG("D-pad highlight: relativeX=\(relativeX), relativeY=\(relativeY)")
        
        // Determine which direction to highlight
        let newDirection: String
        if sqrt(relativeX * relativeX + relativeY * relativeY) < deadZoneRadius {
            // In dead zone, use a special center highlight
            DLOG("D-pad highlight: In dead zone")
            newDirection = "dpad_center"
        } else if abs(relativeX) > abs(relativeY) {
            // Horizontal movement is dominant
            if relativeX > 0 {
                DLOG("D-pad highlight: RIGHT direction detected")
                newDirection = "right"
            } else {
                DLOG("D-pad highlight: LEFT direction detected")
                newDirection = "left"
            }
        } else {
            // Vertical movement is dominant
            if relativeY > 0 {
                DLOG("D-pad highlight: DOWN direction detected")
                newDirection = "down"
            } else {
                DLOG("D-pad highlight: UP direction detected")
                newDirection = "up"
            }
        }
        
        // Check if the direction has changed
        let previousDirection = currentlyPressedButton.flatMap { extractInputCommand(from: $0) }
        
        // If this is a new press or the direction has changed
        if currentlyPressedButton != button || previousDirection != newDirection {
            // Release the previous direction if there was one
            if let previousButton = currentlyPressedButton, let previousDirection = previousDirection, previousDirection != "dpad_center" {
                DLOG("Releasing previous D-pad direction: \(previousDirection)")
                inputHandler.buttonReleased(previousDirection)
            }
            
            // Update the current button
            currentlyPressedButton = button
            
            // Add visual feedback for the new direction
            let newButton = (
                frame: button.frame,
                mappingSize: mappingSize,
                buttonId: newDirection,
                timestamp: Date()
            )
            activeButtons.append(newButton)
            
            #if !os(tvOS)
            buttonGenerator.impactOccurred(intensity: 0.8)
            #endif
            
            // Play sound with current position
            playClickSound(for: button)
            
            // Press the new direction if it's not the center
            if newDirection != "dpad_center" {
                DLOG("Pressing new D-pad direction: \(newDirection)")
                inputHandler.buttonPressed(newDirection)
            }
            
            // Clean up old highlights after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                activeButtons.removeAll { $0.timestamp <= newButton.timestamp }
            }
        }
    }
    
    // For hit testing
    func hitTest(_ point: CGPoint, in geometry: GeometryProxy) -> DeltaSkinButton? {
        guard let buttons = skin.buttons(for: traits),
              let mappingSize = skin.mappingSize(for: traits) else {
            return nil
        }

        return buttons.first { button in
            let hitFrame = button.frame.insetBy(dx: -20, dy: -20)
            let scaledFrame = transformFrame(hitFrame, in: geometry, mappingSize: mappingSize)
            return scaledFrame.contains(point)
        }
    }

    private func isThumbstick(_ button: DeltaSkinButton) -> Bool {
        // Check if button has thumbstick configuration in skin JSON
        guard let items = skin.jsonRepresentation["representations"] as? [String: Any],
              let deviceItems = items[traits.device.rawValue] as? [String: Any],
              let displayItems = deviceItems[traits.displayType.rawValue] as? [String: Any],
              let orientationItems = displayItems[traits.orientation.rawValue] as? [String: Any],
              let buttonItems = orientationItems["items"] as? [[String: Any]] else {
            return false
        }

        return buttonItems.contains { item in
            guard let frame = item["frame"] as? [String: Any],
                  let x = frame["x"] as? CGFloat,
                  let y = frame["y"] as? CGFloat,
                  let width = frame["width"] as? CGFloat,
                  let height = frame["height"] as? CGFloat,
                  let thumbstick = item["thumbstick"] as? [String: Any] else {
                return false
            }

            let buttonFrame = CGRect(x: x, y: y, width: width, height: height)
            return buttonFrame == button.frame
        }
    }

    private func loadThumbsticks() async {
        guard let buttons = skin.buttons(for: traits) else { return }

        for button in buttons {
            if isThumbstick(button),
               let (image, size) = await loadThumbstickImage(for: button) {
                activeThumbsticks.append((frame: button.frame, image: image, size: size))
            }
        }
    }

    // Add this helper function to format CGRect as a string
    private func formatRect(_ rect: CGRect) -> String {
        String(format: "(%.1f, %.1f, %.1f, %.1f)",
               rect.origin.x, rect.origin.y,
               rect.size.width, rect.size.height)
    }

    // Update the screenView method to use DeltaSkinTestPatternView instead of TestPatternView
    @ViewBuilder
    private func screenView(_ screen: DeltaSkinScreen, in geometry: GeometryProxy, layout: SkinLayout) -> some View {
        guard let outputFrame = screen.outputFrame else {
            return AnyView(EmptyView())
        }

        let scaledFrame = CGRect(
            x: outputFrame.minX * layout.width,
            y: outputFrame.minY * layout.height,
            width: outputFrame.width * layout.width,
            height: outputFrame.height * layout.height
        )

        return AnyView(
            ZStack {
                // Screen frame - make it completely transparent to show the game screen underneath
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: scaledFrame.width, height: scaledFrame.height)
                    .blendMode(.normal) // Ensure normal blending
                    .overlay(
                        // Show a border for debugging
                        showDebugOverlay ?
                        Rectangle()
                            .stroke(Color.purple, lineWidth: 3)
                            .overlay(
                                VStack(alignment: .leading) {
                                    Text(screen.id)
                                        .font(.caption)
                                    if let inputFrame = screen.inputFrame {
                                        Text("In: \(formatRect(inputFrame))")
                                            .font(.caption2)
                                    }
                                    Text("Out: \(formatRect(outputFrame))")
                                        .font(.caption2)
                                    Text("Place: \(screen.placement.rawValue)")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                            )
                        : nil
                    )
                    // Only show test pattern if not in emulator
                    .overlay(
                        !isInEmulator ?
                        DeltaSkinTestPatternView(
                            frame: CGRect(
                                x: 0,
                                y: 0,
                                width: scaledFrame.width,
                                height: scaledFrame.height
                            ),
                            filters: filters
                        )
                        : nil
                    )
                    // Add a tag to help identify this view for debugging
                    .accessibility(identifier: "ScreenView-\(screen.id)")
            }
            .position(
                x: scaledFrame.midX,
                y: scaledFrame.midY
            )
        )
    }

    @ViewBuilder
    private func screenGroup(_ group: DeltaSkinScreenGroup, in geometry: GeometryProxy, layout: SkinLayout) -> some View {
        ZStack {
            // Translucent background if needed
            if group.translucent ?? false {
                Rectangle()
                    .fill(.black.opacity(0.5))
            }

            // Screens in this group
            ForEach(group.screens, id: \.id) { screen in
                screenView(screen, in: geometry, layout: layout)
            }
        }
    }

    @ViewBuilder
    private func buttonMapping(_ mapping: DeltaSkinButtonMapping, in geometry: GeometryProxy, layout: SkinLayout) -> some View {
        if let frame = mapping.frame {
            let scaledFrame = CGRect(
                x: frame.minX * layout.width,
                y: frame.minY * layout.height,
                width: frame.width * layout.width,
                height: frame.height * layout.height
            )

            // Calculate the absolute position in the parent view
            let absoluteX = scaledFrame.midX + layout.xOffset
            let absoluteY = scaledFrame.midY + layout.yOffset

            if mapping.id.lowercased() == "dpad" {
                // Special handling for D-pad
                dpadMapping(frame: scaledFrame, absolutePosition: CGPoint(x: absoluteX, y: absoluteY))
            } else if mapping.id.lowercased().contains("analog") || mapping.id.lowercased().contains("stick") {
                // Analog stick
                analogStickMapping(mapping: mapping, frame: scaledFrame, absolutePosition: CGPoint(x: absoluteX, y: absoluteY))
            } else {
                // Regular button
                Button(action: {
                    // Pass the button ID directly instead of the button object
                    handleButtonPress(mapping.id)
                }) {
                    if showDebugOverlay {
                        // Show debug overlay for the button
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .background(Color.red.opacity(0.3))
                            .overlay(
                                Text(mapping.id)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(4)
                            )
                    } else {
                        // Invisible button area in normal mode
                        Color.clear
                    }
                }
                .frame(width: scaledFrame.width, height: scaledFrame.height)
                .position(x: absoluteX, y: absoluteY)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Pass the button ID directly
                            handleButtonPress(mapping.id)
                        }
                        .onEnded { _ in
                            // Pass the button ID directly
                            handleButtonRelease(mapping.id)
                        }
                )
                .accessibility(identifier: "Button-\(mapping.id)")
            }
        }
    }

    @ViewBuilder
    private func dpadMapping(frame: CGRect, absolutePosition: CGPoint) -> some View {
        // Create a view for the D-pad with regions for each direction
        ZStack {
            if showDebugOverlay {
                // Debug overlay for the entire D-pad
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .background(Color.red.opacity(0.1))
                    .overlay(
                        Text("D-Pad")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            } else {
                Color.clear
            }

            // Up region
            Rectangle()
                .fill(showDebugOverlay ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width / 2,
                    y: frame.height * 0.16
                )
                .overlay(showDebugOverlay ? Text("Up").font(.caption2).foregroundColor(.white) : nil)

            // Down region
            Rectangle()
                .fill(showDebugOverlay ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width / 2,
                    y: frame.height * 0.84
                )
                .overlay(showDebugOverlay ? Text("Down").font(.caption2).foregroundColor(.white) : nil)

            // Left region
            Rectangle()
                .fill(showDebugOverlay ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width * 0.16,
                    y: frame.height / 2
                )
                .overlay(showDebugOverlay ? Text("Left").font(.caption2).foregroundColor(.white) : nil)

            // Right region
            Rectangle()
                .fill(showDebugOverlay ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width * 0.84,
                    y: frame.height / 2
                )
                .overlay(showDebugOverlay ? Text("Right").font(.caption2).foregroundColor(.white) : nil)
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: absolutePosition.x, y: absolutePosition.y)
    }

    @ViewBuilder
    private func analogStickMapping(mapping: DeltaSkinButtonMapping, frame: CGRect, absolutePosition: CGPoint) -> some View {
        // Determine if this is left or right analog stick
        let isLeftStick = mapping.id.lowercased().contains("left")

        // Create a draggable analog stick
        ZStack {
            if showDebugOverlay {
                // Debug overlay
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.1))
            } else {
                Color.clear
            }

            // Stick handle
            Circle()
                .fill(showDebugOverlay ? Color.white.opacity(0.5) : Color.clear)
                .frame(
                    width: frame.width * 0.5,
                    height: frame.height * 0.5
                )
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: absolutePosition.x, y: absolutePosition.y)
        .overlay(
            showDebugOverlay ?
                Text(isLeftStick ? "Left Analog" : "Right Analog")
                    .font(.caption2)
                    .foregroundColor(.white)
                : nil
        )
    }

    private func handleButtonPress(_ buttonId: String) {
        // Pass the button ID directly to the input handler
        inputHandler.buttonPressed(buttonId)
    }

    private func handleButtonRelease(_ buttonId: String) {
        // Pass the button ID directly to the input handler
        inputHandler.buttonReleased(buttonId)
    }
    
    /// Extract the actual input command from a button
    private func extractInputCommand(from button: DeltaSkinButton) -> String {
        // First, try to get the command from the button's input property
        switch button.input {
        case .single(let command):
            return command
        case .directional(let commands):
            // For directional inputs, we need to determine which direction is being pressed
            // This requires checking the touch location relative to the button's center
            if let touchLocation = touchLocation, let mappingSize = skin.mappingSize(for: traits) {
                // We need to use the same coordinate transformation as in handleTouch
                // to ensure consistent direction detection
                let scale = min(
                    previewSize.width / mappingSize.width,
                    previewSize.height / mappingSize.height
                )
                
                let scaledSkinWidth = mappingSize.width * scale
                let scaledSkinHeight = mappingSize.height * scale
                let xOffset = (previewSize.width - scaledSkinWidth) / 2
                
                // Check if skin has fixed screen position
                let hasScreenPosition = skin.screens(for: traits) != nil
                
                // Calculate Y offset based on skin type
                let yOffset: CGFloat = hasScreenPosition ?
                    ((previewSize.height - scaledSkinHeight) / 2) :
                    (previewSize.height - scaledSkinHeight)
                
                // Calculate the button center in view coordinates
                let buttonCenterX = button.frame.midX * scale + xOffset
                let buttonCenterY = button.frame.midY * scale + yOffset
                
                // Calculate the touch position relative to the button center
                let relativeX = touchLocation.x - buttonCenterX
                let relativeY = touchLocation.y - buttonCenterY
                
                // Add debug logging to help diagnose direction issues
                DLOG("D-pad: relativeX=\(relativeX), relativeY=\(relativeY)")
                
                // Define the center dead zone (15% of button size - smaller dead zone)
                let buttonWidth = button.frame.width * scale
                let buttonHeight = button.frame.height * scale
                let deadZoneRadius = min(buttonWidth, buttonHeight) * 0.15
                
                // Check if touch is in the dead zone
                if sqrt(relativeX * relativeX + relativeY * relativeY) < deadZoneRadius {
                    // In dead zone, return a special "center" command or nothing
                    DLOG("D-pad: In dead zone")
                    // Don't send any command when in the dead zone
                    return "none"
                }
                
                // Determine which direction is being pressed based on the touch position
                if abs(relativeX) > abs(relativeY) {
                    // Horizontal movement is dominant
                    if relativeX > 0 {
                        DLOG("D-pad: RIGHT direction detected")
                        return commands["right"] ?? "right"
                    } else {
                        DLOG("D-pad: LEFT direction detected")
                        return commands["left"] ?? "left"
                    }
                } else {
                    // Vertical movement is dominant
                    if relativeY > 0 {
                        DLOG("D-pad: DOWN direction detected")
                        return commands["down"] ?? "down"
                    } else {
                        DLOG("D-pad: UP direction detected")
                        return commands["up"] ?? "up"
                    }
                }
            }
            
            // Fallback if we can't determine the direction
            if let firstCommand = commands.values.first {
                return firstCommand
            }
        }
        
        // If we couldn't get a command from the input, try to extract it from the button ID
        // This is a fallback for compatibility with existing code
        let buttonId = button.id.lowercased()
        
        if buttonId.contains("up") {
            return "up"
        } else if buttonId.contains("down") {
            return "down"
        } else if buttonId.contains("left") {
            return "left"
        } else if buttonId.contains("right") {
            return "right"
        } else if buttonId.contains("a") {
            return "a"
        } else if buttonId.contains("b") {
            return "b"
        } else if buttonId.contains("x") {
            return "x"
        } else if buttonId.contains("y") {
            return "y"
        } else if buttonId.contains("l") && !buttonId.contains("select") {
            return "l"
        } else if buttonId.contains("r") && !buttonId.contains("start") {
            return "r"
        } else if buttonId.contains("start") {
            return "start"
        } else if buttonId.contains("select") {
            return "select"
        }
        
        // If all else fails, just use the button ID
        return button.id
    }
}

private struct SkinLayoutKey: EnvironmentKey {
    static let defaultValue: DeltaSkinView.SkinLayout? = nil
}

extension EnvironmentValues {
    var skinLayout: DeltaSkinView.SkinLayout? {
        get { self[SkinLayoutKey.self] }
        set { self[SkinLayoutKey.self] = newValue }
    }
}

/// Overlay showing hit test areas for buttons
private struct DeltaSkinHitTestOverlay: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let size: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let buttons = skin.buttons(for: traits),
               let mappingSize = skin.mappingSize(for: traits) {
                // Calculate the scale to fit the skin in the available space
                let scale = min(
                    geometry.size.width / mappingSize.width,
                    geometry.size.height / mappingSize.height
                )

                let scaledSkinWidth = mappingSize.width * scale
                let scaledSkinHeight = mappingSize.height * scale

                // Calculate the offset to center the skin
                let xOffset = (geometry.size.width - scaledSkinWidth) / 2
                let yOffset = (geometry.size.height - scaledSkinHeight) / 2

                // Draw hit boxes for each button
                ForEach(buttons, id: \.id) { button in
                    let scaledFrame = CGRect(
                        x: button.frame.minX * scale + xOffset,
                        y: button.frame.minY * scale + yOffset,
                        width: button.frame.width * scale,
                        height: button.frame.height * scale
                    )

                    Rectangle()
                        .stroke(.red.opacity(0.5), lineWidth: 1)
                        .frame(width: scaledFrame.width, height: scaledFrame.height)
                        .position(x: scaledFrame.midX, y: scaledFrame.midY)
                        .overlay(
                            Text(button.id)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .padding(2)
                        )
                }
            }
        }
    }
}

// Helper for byte conversion
extension UInt32 {
    var bytes: [UInt8] {
        [
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF)
        ]
    }
}

extension UInt16 {
    var bytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8(self >> 8)]
    }
}

// Add helper for Int16 byte conversion
extension Int16 {
    var bytes: [UInt8] {
        let value = UInt16(bitPattern: self)  // Convert to unsigned while preserving bit pattern
        return [UInt8(value & 0xFF), UInt8(value >> 8)]
    }
}

// Audio engine for positional playback
internal class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var players: [AVAudioPlayerNode] = []  // Pool of players
    private let maxPlayers = 4  // Maximum concurrent sounds
    private var currentPlayer = 0  // Index of next player to use

    init() {
        format = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 1
        )!

        // Create player pool
        for _ in 0..<maxPlayers {
            let player = AVAudioPlayerNode()
            let panner = AVAudioMixerNode()

            engine.attach(player)
            engine.attach(panner)

            engine.connect(player, to: panner, format: format)
            engine.connect(panner, to: engine.mainMixerNode, format: format)

            players.append(player)
        }

        try? engine.start()
    }

    func playSound(buffer: PCMBuffer, pan: CGFloat) {
        // Get next available player
        let player = players[currentPlayer]
        let panner = engine.outputConnectionPoints(for: player, outputBus: 0)[0].node as! AVAudioMixerNode

        // Update pan position immediately
        panner.pan = Float(pan)

        // Schedule and play sound
        player.scheduleBuffer(buffer.buffer, at: nil, options: .interrupts) {
            // Optional cleanup when sound finishes
        }
        player.play()

        // Move to next player
        currentPlayer = (currentPlayer + 1) % maxPlayers
    }
}

// Helper for creating audio buffers
internal class PCMBuffer {
    let buffer: AVAudioPCMBuffer

    func getChannelData() -> UnsafeMutablePointer<Float>? {
        buffer.floatChannelData?[0]
    }

    init?(sampleRate: Double, channels: Int = 1, frames: UInt32) {  // Default to mono
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: UInt32(channels)
        )

        guard let format = format,
              let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frames
              ) else { return nil }

        pcmBuffer.frameLength = frames
        self.buffer = pcmBuffer
    }
}
