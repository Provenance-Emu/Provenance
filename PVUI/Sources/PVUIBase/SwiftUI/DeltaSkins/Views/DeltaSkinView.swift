import SwiftUI
import AudioToolbox
import AVFoundation  // Add this for audio buffer types

/// Core view for rendering a DeltaSkin with test patterns and interactive elements
public struct DeltaSkinView: View {
    let skin: DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let showDebugOverlay: Bool
    let showHitTestOverlay: Bool
    let screenAspectRatio: CGFloat?  // Optional aspect ratio

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
        skin: DeltaSkinProtocol,
        traits: DeltaSkinTraits,
        filters: Set<TestPatternEffect> = [],
        showDebugOverlay: Bool = false,
        showHitTestOverlay: Bool = false,
        screenAspectRatio: CGFloat? = nil
    ) {
        self.skin = skin
        self.traits = traits
        self.filters = filters
        self.showDebugOverlay = showDebugOverlay
        self.showHitTestOverlay = showHitTestOverlay
        self.screenAspectRatio = screenAspectRatio
    }

    internal struct SkinLayout {
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

        // For portrait mode on iPhone, prioritize filling width while maintaining aspect ratio
        var scale: CGFloat
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

        // Calculate Y offset based on orientation and screen presence
        let yOffset: CGFloat
        if hasScreenPosition(for: traits) {
            // If screen position is specified, center the skin
            yOffset = (geometry.size.height - scaledHeight) / 2
        } else {
            // For portrait skins without screen position, position at bottom
            if traits.orientation == .portrait {
                yOffset = geometry.size.height - scaledHeight
            } else {
                // For landscape, center vertically
                yOffset = (geometry.size.height - scaledHeight) / 2
            }
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
        Container size: \(geometry.size)
        Mapping size: \(skin.mappingSize(for: traits) ?? .zero)
        Layout:
          - scale: \(layout.scale)
          - width: \(layout.width)
          - height: \(layout.height)
          - xOffset: \(layout.xOffset)
          - yOffset: \(layout.yOffset)
        Skin buttons:
        \(skin.buttons(for: traits)?.map { "  - \($0.id): \($0.frame)" }.joined(separator: "\n") ?? "none")
        Screen frame: \(skin.screens(for: traits)?.first?.outputFrame ?? .zero)
        """

        DLOG("DeltaSkinView frame info:\n\(debugInfo)")
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                if let layout = calculateLayout(for: geometry) {
                    ZStack {
                        // Screen layer (color bars) - positioned independently
                        DeltaSkinScreenLayer(
                            skin: skin,
                            traits: traits,
                            filters: filters,
                            size: geometry.size,
                            screenAspectRatio: screenAspectRatio
                        )
                        .zIndex(1)

                        // Skin and controls container - positioned at bottom
                        ZStack {
                            // Skin image layer
                            if let skinImage {
                                Image(uiImage: skinImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: layout.width, height: layout.height)
                                    .clipped()
                            }

                            // Debug/hit test overlays
                            if showDebugOverlay {
                                DeltaSkinDebugOverlay(
                                    skin: skin,
                                    traits: traits,
                                    size: geometry.size
                                )
                            }
                            if showHitTestOverlay {
                                DeltaSkinHitTestOverlay(
                                    skin: skin,
                                    traits: traits,
                                    size: geometry.size
                                )
                            }

                            // Effects and thumbsticks inside the skin container
                            ForEach(activeButtons, id: \.timestamp) { button in
                                DeltaSkinButtonHighlight(
                                    frame: button.frame,
                                    mappingSize: button.mappingSize,
                                    previewSize: geometry.size,
                                    buttonId: button.buttonId
                                )
                                .zIndex(4)
                            }

                            // Thumbstick layer
                            ForEach(activeThumbsticks, id: \.frame) { thumbstick in
                                DeltaSkinThumbstick(
                                    frame: thumbstick.frame,
                                    thumbstickImage: thumbstick.image,
                                    thumbstickSize: thumbstick.size,
                                    mappingSize: skin.mappingSize(for: traits) ?? .zero
                                )
                                .zIndex(5)
                            }
                        }
                        .frame(width: layout.width, height: layout.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height - layout.height / 2)
                    }
                    .environment(\.skinLayout, layout)
                    .onAppear {
                        logLayoutInfo(geometry: geometry, layout: layout)
                    }
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
                        }

                        touchLocation = nil
                        currentlyPressedButton = nil
                    }
            )
            #endif
        }
        .task {
            await loadSkin()
            await loadThumbsticks()
        }
    }

    private func loadSkin() async {
        do {
            skinImage = try await skin.image(for: traits)
        } catch {
            ELOG("Failed to load skin image: \(error)")
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

        // Handle button state changes
        if let button = touchedButton {
            if isThumbstick(button) {
                // Handle thumbstick
                Task {
                    if let (image, size) = await loadThumbstickImage(for: button) {
                        activeThumbsticks.append((frame: button.frame, image: image, size: size))
                    }
                }
            } else if button != currentlyPressedButton {
                // Only trigger effects for new button presses
                currentlyPressedButton = button

                // Add visual feedback
                let newButton = (
                    frame: button.frame,
                    mappingSize: mappingSize,
                    buttonId: button.id,
                    timestamp: Date()
                )
                activeButtons.append(newButton)
                #if !os(tvOS)
                buttonGenerator.impactOccurred(intensity: 0.8)
                #endif
                // Play sound with current position
                playClickSound(for: button)

                // Clean up old highlights after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    activeButtons.removeAll { $0.timestamp <= newButton.timestamp }
                }
            }
        } else {
            // Touch is not on any button
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
    let skin: DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let size: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let buttons = skin.buttons(for: traits),
               let mappingSize = skin.mappingSize(for: traits) {
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

                ForEach(buttons, id: \.id) { button in
                    let hitFrame = button.frame.insetBy(dx: -20, dy: -20)
                    let scaledFrame = CGRect(
                        x: hitFrame.minX * scale + xOffset,
                        y: yOffset + (hitFrame.minY * scale),
                        width: hitFrame.width * scale,
                        height: hitFrame.height * scale
                    )

                    Rectangle()
                        .stroke(.red.opacity(0.5), lineWidth: 1)
                        .frame(width: scaledFrame.width, height: scaledFrame.height)
                        .position(x: scaledFrame.midX, y: scaledFrame.midY)
                }
            }
        }
        .allowsHitTesting(false)
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
