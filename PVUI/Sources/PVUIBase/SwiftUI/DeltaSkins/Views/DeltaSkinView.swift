import SwiftUI
import AudioToolbox
import AVFoundation  // Add this for audio buffer types
import PVLogging
import PVEmulatorCore
#if canImport(UIKit)
import PVSettings
#endif

// MARK: - Identifiable wrapper types for stable ForEach IDs

/// Wrapper for active button info with stable ID to prevent SwiftUI view graph corruption
private struct ActiveButtonInfo: Identifiable {
    let id: String  // Unique ID combining buttonId + UUID
    let frame: CGRect
    let mappingSize: CGSize
    let buttonId: String
    let timestamp: Date

    init(frame: CGRect, mappingSize: CGSize, buttonId: String, timestamp: Date = Date()) {
        self.id = "\(buttonId)-\(UUID().uuidString)"
        self.frame = frame
        self.mappingSize = mappingSize
        self.buttonId = buttonId
        self.timestamp = timestamp
    }
}

/// Wrapper for active thumbstick info with stable ID
private struct ActiveThumbstickInfo: Identifiable {
    let id: String
    let frame: CGRect
    let image: UIImage
    let size: CGSize
    let buttonId: String

    init(frame: CGRect, image: UIImage, size: CGSize, buttonId: String) {
        self.id = "\(buttonId)-\(UUID().uuidString)"
        self.frame = frame
        self.image = image
        self.size = size
        self.buttonId = buttonId
    }
}

/// Wrapper for touch location with stable ID
private struct TouchLocationInfo: Identifiable {
    let id: String
    let location: CGPoint

    init(location: CGPoint) {
        self.id = UUID().uuidString
        self.location = location
    }
}

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
    let core: PVEmulatorCore?  // Core for protocol-based viewport updates

    /// When `true`, button input is suspended and each button shows a drag handle.
    @Binding var isEditMode: Bool

    /// Per-button position offsets managed by the user via drag-to-reposition.
    @ObservedObject var buttonOffsets: DeltaSkinButtonOffsets

    /// Observed so the view re-renders when turbo buttons change.
    @ObservedObject var turboManager: TurboManager

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// State for touch and button interactions
    @State private var touchLocations: Set<CGPoint> = []
    @State private var activeButton: (frame: CGRect, mappingSize: CGSize, buttonId: String)?
    @State private var lastButtonPressed: String?
    @State private var isButtonHapticEnabled = true  // Add this state

    /// Buttons currently in "sticky" (toggle-held) mode — mirrors the sticky manager for SwiftUI updates.
    @State private var stickyButtonIds: Set<String> = []

    /// State for skin loading
    @State private var skinImage: UIImage?
    @State private var thumbstickImage: UIImage?

    @State private var activeThumbsticks: [ActiveThumbstickInfo] = []

    // Add feedback generator
    #if !os(tvOS)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    // Audio engine for positional audio
    private static let audioEngine = AudioEngine()

    // Single set of sound IDs without left/right variants
    internal static let buttonSounds: [String: PCMBuffer] = createButtonSounds()

    // Track multiple active buttons - using Identifiable wrapper for stable ForEach IDs
    @State private var activeButtons: [ActiveButtonInfo] = []

    // Track the currently pressed button (legacy support)
    @State private var currentlyPressedButton: DeltaSkinButton?

    // Track multiple touch points for multi-touch support
    @State private var touchPoints: [ObjectIdentifier: CGPoint] = [:]

    // Map touch IDs to button IDs for tracking which touch is pressing which button
    @State private var touchToButtonMap: [ObjectIdentifier: String] = [:]

    // Map touch IDs to D-pad button for tracking which touch is on the D-pad
    @State private var touchToDPadMap: [ObjectIdentifier: DeltaSkinButton] = [:]

    // Map touch IDs to their locations for D-pad input calculation
    @State private var touchLocationsMap: [ObjectIdentifier: CGPoint] = [:]

    // Track which touches have been processed (to avoid re-processing in .moved)
    @State private var processedTouches: Set<ObjectIdentifier> = []

    // Track the current preview size
    @State private var previewSize: CGSize = .zero

    /// Get the smallest screen (the actual game screen) from screens array
    /// Larger screens are typically effect screens (blurred backgrounds), smaller screens are the game screen
    private func getSmallestScreen(from screens: [DeltaSkinScreen], mappingSize: CGSize) -> DeltaSkinScreen? {
        // Filter out screens that are too small (likely buttons or UI elements)
        let validScreens = screens.compactMap { screen -> (screen: DeltaSkinScreen, frame: CGRect, area: CGFloat)? in
            guard let frame = screen.outputFrame else { return nil }
            let area = frame.width * frame.height
            // Minimum reasonable screen size: at least 100x100 pixels or normalized equivalent
            let minSize: CGFloat = 100.0
            let isAbsolutePixels = frame.width > mappingSize.width || frame.height > mappingSize.height ||
                                   (frame.width > 1.0 && frame.height > 1.0 &&
                                    frame.width < mappingSize.width && frame.height < mappingSize.height)
            let actualMinSize = isAbsolutePixels ? minSize : (minSize / max(mappingSize.width, mappingSize.height))

            if frame.width >= actualMinSize && frame.height >= actualMinSize {
                return (screen, frame, area)
            }
            return nil
        }

        // Return the smallest screen (the actual game screen)
        return validScreens.min(by: { $0.area < $1.area })?.screen
    }

    /// State for the loaded skin image
    @State private var loadingError: Error?
    @State private var screenGroups: [DeltaSkinScreenGroup]?
    @State private var buttonMappings: [DeltaSkinButtonMapping]?

    @State private var pressedButtons: Set<String> = []

    // MARK: - Turbo long-press state
    /// Timer used to detect a long-press for turbo toggle (fires after 0.6s)
    @State private var turboLongPressTimers: [ObjectIdentifier: Timer] = [:]
    /// Tracks buttons whose turbo was just toggled in this touch so we skip the normal release
    @State private var turboToggledThisTouch: Set<ObjectIdentifier> = []

    // Cache of per-button asset images (normal/pressed) keyed by button id
    @State private var buttonAssetImages: [String: (normal: UIImage, pressed: UIImage?)] = [:]

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
        inputHandler: DeltaSkinInputHandler,
        core: PVEmulatorCore? = nil,
        isEditMode: Binding<Bool> = .constant(false),
        buttonOffsets: DeltaSkinButtonOffsets = .shared
    ) {
        self.skin = skin
        self.traits = traits
        self.filters = filters
        self.showDebugOverlay = showDebugOverlay
        self.showHitTestOverlay = showHitTestOverlay
        self.screenAspectRatio = screenAspectRatio
        self.core = core
        self.isInEmulator = isInEmulator
        self.inputHandler = inputHandler
        self._isEditMode = isEditMode
        self._buttonOffsets = ObservedObject(wrappedValue: buttonOffsets)
        self._turboManager = ObservedObject(wrappedValue: inputHandler.turboManager)

        ILOG("skins: DeltaSkinView init - skin: \(skin.name), device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue), iPadModel: \(traits.iPadModel?.rawValue ?? "nil")")
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
        VLOG("skins: calculateLayout() geometry=\(geometry.size) device=\(traits.device.rawValue)")
        guard let mappingSize = skin.mappingSize(for: traits) else {
            ELOG("skins: ERROR - calculateLayout() failed: no mapping size for traits: \(traits.description)")
            return nil
        }
        VLOG("skins: calculateLayout() - mappingSize: \(mappingSize)")

        // For simple image-based skins (no screens array, just background image),
        // use the actual image size for scaling instead of mappingSize
        // A gameScreenFrame alone doesn't make it a complex skin - it's just metadata
        let effectiveImageSize: CGSize
        if let image = skinImage {
            // Check if this is a simple image-based skin (no screens array defined)
            let hasScreens = skin.screens(for: traits) != nil || skin.screenGroups(for: traits) != nil

            if !hasScreens {
                // Simple image-based skin: use actual image size for scaling
                // Even if it has gameScreenFrame, it's still a simple image skin
                effectiveImageSize = image.size
                VLOG("Simple image-based skin detected. Image size: \(effectiveImageSize), mappingSize: \(mappingSize)")
            } else {
                // Complex skin with screens array: use mappingSize as before
                effectiveImageSize = mappingSize
            }
        } else {
            // No image loaded yet, use mappingSize
            effectiveImageSize = mappingSize
        }

        // Account for safe area insets when calculating available space for scaling
        let safeInsets = geometry.safeAreaInsets
        let availableWidth = geometry.size.width - safeInsets.leading - safeInsets.trailing
        let availableHeight = geometry.size.height - safeInsets.top - safeInsets.bottom

        // Calculate the scale to fit the skin in the available space (accounting for safe areas)
        var scale: CGFloat

        // For portrait mode on iPhone, prioritize filling width while maintaining aspect ratio
        if traits.device == .iphone && traits.orientation == .portrait {
            // Start with width scale to fill available width
            scale = availableWidth / effectiveImageSize.width

            // Calculate resulting height
            let scaledHeight = effectiveImageSize.height * scale

            // If height exceeds available height, scale down while maintaining aspect ratio
            if scaledHeight > availableHeight {
                let heightScale = availableHeight / effectiveImageSize.height
                scale = min(scale, heightScale)
            }
        } else {
            // For landscape or iPad, use standard fit scaling within safe area
            scale = min(
                availableWidth / effectiveImageSize.width,
                availableHeight / effectiveImageSize.height
            )
        }

        let scaledWidth = effectiveImageSize.width * scale
        let scaledHeight = effectiveImageSize.height * scale

        // Center horizontally accounting for safe areas
        let xOffset = safeInsets.leading + (availableWidth - scaledWidth) / 2

        // For portrait mode on iPhone, position at bottom of screen
        // For landscape or iPad, center vertically accounting for safe areas
        let yOffset: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Position at bottom of screen, accounting for safe area
            yOffset = geometry.size.height - scaledHeight - safeInsets.bottom
        } else {
            // Center vertically in safe area
            yOffset = safeInsets.top + (availableHeight - scaledHeight) / 2
        }

        let layout = SkinLayout(
            scale: scale,
            width: scaledWidth,
            height: scaledHeight,
            xOffset: xOffset,
            yOffset: yOffset
        )
        ILOG("skins: calculateLayout() - calculated layout: scale=\(scale), width=\(scaledWidth), height=\(scaledHeight), xOffset=\(xOffset), yOffset=\(yOffset)")
        return layout
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
                        // Animated background (shown beneath the game screen and skin image)
                        // Skipped when the user has enabled Reduce Motion for accessibility/battery reasons.
                        if !reduceMotion, let bgAnimation = skin.backgroundAnimation(for: traits) {
                            DeltaSkinAnimatedBackgroundView(animation: bgAnimation, skin: skin)
                                .frame(width: layout.width, height: layout.height)
                                .clipped()
                                .allowsHitTesting(false)
                                .zIndex(-1)
                        }

                        // Always create a screen position wrapper, even when in emulator
                        // This ensures we can get the correct position whether color bars are visible or not
                        DeltaSkinScreenPositionWrapper(
                            skin: skin,
                            traits: traits,
                            filters: filters,
                            size: geometry.size,
                            screenAspectRatio: screenAspectRatio,
                            isInEmulator: isInEmulator,
                            core: core,
                            layout: layout
                        )
                        .zIndex(0)

                        // Base skin image
                        if let skinImage = skinImage {
                            Image(uiImage: skinImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: layout.width, height: layout.height)
                                .clipped()
                            // Draw per-button asset layers (if provided by the skin)
                            if let buttons = skin.buttons(for: traits),
                               let mappingSize = skin.mappingSize(for: traits) {
                                // Button coordinates are always in mappingSize space
                                // Layout is calculated based on effective image size (image size for simple skins, mappingSize for complex)
                                // So button scaling automatically accounts for the difference
                                let scaleX = layout.width / mappingSize.width
                                let scaleY = layout.height / mappingSize.height
                                ForEach(buttons, id: \.id) { button in
                                    if let assets = buttonAssetImages[button.id] {
                                        // Determine pressed state based on mapped input(s)
                                        let isPressed: Bool = {
                                            switch button.input {
                                            case .single(let command):
                                                return pressedButtons.contains(command)
                                            case .directional(let mapping):
                                                return mapping.values.contains(where: { pressedButtons.contains($0) })
                                            }
                                        }()
                                        let imageToUse = (isPressed ? (assets.pressed ?? assets.normal) : assets.normal)
                                        // Apply user-saved position offset for this button
                                        let effective = buttonWithEffectiveFrame(button)

                                        Image(uiImage: imageToUse)
                                            .resizable()
                                            .frame(
                                                width: effective.frame.width * scaleX,
                                                height: effective.frame.height * scaleY
                                            )
                                            .position(
                                                x: effective.frame.midX * scaleX,
                                                y: effective.frame.midY * scaleY
                                            )
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        } else {
                            // Loading placeholder
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: layout.width, height: layout.height)
                                .overlay(
                                    Text("No Image")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                )
                                .onAppear {
                                    ILOG("skins: WARNING - No skin image loaded, showing placeholder")
                                }
                        }

                        // Screen groups - in preview mode, only show the smallest screen (game screen)
                        if let groups = screenGroups {
                            ForEach(groups, id: \.id) { group in
                                if isInEmulator {
                                    // In emulator mode, show all screens
                                    screenGroup(group, in: geometry, layout: layout)
                                } else {
                                    // In preview mode, only show the smallest screen (game screen)
                                    if let mappingSize = skin.mappingSize(for: traits),
                                       let smallestScreen = getSmallestScreen(from: group.screens, mappingSize: mappingSize) {
                                        screenView(smallestScreen, in: geometry, layout: layout)
                                    }
                                }
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
                            .allowsHitTesting(false)
                        }
                        if showHitTestOverlay {
                            DeltaSkinHitTestOverlay(
                                skin: skin,
                                traits: traits,
                                size: geometry.size,
                                skinImage: skinImage
                            )
                            .zIndex(2)
                            .allowsHitTesting(false)
                        }

                        // Effects and thumbsticks inside the skin container
                        ForEach(activeButtons) { button in
                            DeltaSkinButtonHighlight(
                                frame: button.frame,
                                mappingSize: button.mappingSize,
                                previewSize: geometry.size,
                                buttonId: button.buttonId
                            )
                            .zIndex(3)
                            .allowsHitTesting(false)
                        }

                        // Turbo badges for buttons with turbo enabled
                        if Defaults[.turboEnabled] {
                            let turboButtons = turboManager.turboButtons
                            if !turboButtons.isEmpty,
                               let buttons = skin.buttons(for: traits),
                               let mappingSize = skin.mappingSize(for: traits) {
                                let scale = min(
                                    geometry.size.width / mappingSize.width,
                                    geometry.size.height / mappingSize.height
                                )
                                let scaledSkinWidth = mappingSize.width * scale
                                let scaledSkinHeight = mappingSize.height * scale
                                let xOff = (geometry.size.width - scaledSkinWidth) / 2
                                let yOff = (geometry.size.height - scaledSkinHeight) / 2

                                ForEach(buttons.filter { turboButtons.contains($0.id) }) { button in
                                    let effective = buttonWithEffectiveFrame(button)
                                    let scaledFrame = CGRect(
                                        x: effective.frame.minX * scaledSkinWidth + xOff,
                                        y: effective.frame.minY * scaledSkinHeight + yOff,
                                        width: effective.frame.width * scaledSkinWidth,
                                        height: effective.frame.height * scaledSkinHeight
                                    )
                                    DeltaSkinTurboBadge(
                                        buttonFrame: scaledFrame
                                    )
                                    .zIndex(6)
                                    .allowsHitTesting(false)
                                }
                            }
                        }

                        // Sticky button indicators
                        if !stickyButtonIds.isEmpty,
                           let buttons = skin.buttons(for: traits),
                           let mappingSize = skin.mappingSize(for: traits) {
                            ForEach(buttons.filter { stickyButtonIds.contains($0.id) }, id: \.id) { button in
                                DeltaSkinStickyIndicator(
                                    frame: buttonWithEffectiveFrame(button).frame,
                                    mappingSize: mappingSize
                                )
                                .zIndex(3.5)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.2), value: stickyButtonIds)
                            }
                        }

                        // Thumbstick layer - should be on top
                        ForEach(activeThumbsticks) { thumbstick in
                            DeltaSkinThumbstick(
                                frame: thumbstick.frame,
                                thumbstickImage: thumbstick.image,
                                thumbstickSize: thumbstick.size,
                                mappingSize: skin.mappingSize(for: traits) ?? .zero,
                                buttonId: thumbstick.buttonId,
                                inputHandler: inputHandler
                            )
                            .zIndex(4)
                        }

                        // Touch indicators - always on top
                        // Use enumerated with index as ID to avoid CGPoint hash instability
                        ForEach(Array(touchLocations.enumerated()), id: \.offset) { _, location in
                            DeltaSkinTouchIndicator(at: location)
                                .zIndex(5)
                                .allowsHitTesting(false)
                        }

                        // Edit mode overlay — drag handles for repositioning buttons
                        if isEditMode, let mappingSize = skin.mappingSize(for: traits) {
                            DeltaSkinEditModeOverlay(
                                skin: skin,
                                traits: traits,
                                mappingSize: mappingSize,
                                containerSize: CGSize(width: layout.width, height: layout.height),
                                buttonOffsets: buttonOffsets,
                                onOffsetChanged: { buttonId, newOffset in
                                    Task { @MainActor in
                                        buttonOffsets.setOffset(newOffset, for: buttonId, skinIdentifier: skin.identifier)
                                    }
                                }
                            )
                            .zIndex(10)
                        }
                    }
                    .frame(width: layout.width, height: layout.height)
                    .position(
                        x: layout.xOffset + layout.width / 2,
                        y: layout.yOffset + layout.height / 2
                    )
                    .environment(\.skinLayout, layout)
                    .onAppear {
                        ILOG("skins: DeltaSkinView appeared - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue), iPadModel: \(traits.iPadModel?.rawValue ?? "nil")")
                        ILOG("skins: DeltaSkinView - skin name: \(skin.name)")
                        ILOG("skins: Rendering DeltaSkinView with layout - device: \(traits.device.rawValue), layout size: \(layout.width)x\(layout.height)")
                        if let skinImage = skinImage {
                            ILOG("skins: Rendering skin image: \(skinImage.size) at layout size: \(layout.width)x\(layout.height)")
                        }
                        logLayoutInfo(geometry: geometry, layout: layout)
                        loadSkinResources()
                        // Preload thumbstick caps so they render immediately
                        Task { await loadThumbsticks() }
                    }
                }

                // Only show test patterns if not in emulator mode
                if !isInEmulator, let layout = calculateLayout(for: geometry) {
                    // Test pattern container
                    ZStack {
                        // Only show in preview mode, not in emulator
                        // In preview mode, only show the smallest screen (game screen) to avoid oversized effect screens
                        if let screens = skin.screens(for: traits),
                           let mappingSize = skin.mappingSize(for: traits),
                           let smallestScreen = getSmallestScreen(from: screens, mappingSize: mappingSize),
                           let outputFrame = smallestScreen.outputFrame {
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
                    .frame(width: layout.width, height: layout.height)
                    .position(
                        x: (traits.device == .iphone && traits.orientation == .portrait)
                           ? (layout.xOffset + layout.width / 2)
                           : (geometry.size.width / 2),
                        y: (traits.device == .iphone && traits.orientation == .portrait)
                           ? (layout.yOffset + layout.height / 2)
                           : (geometry.size.height - layout.height / 2)
                    )
                } else {
                    // Layout calculation failed - show empty view
                    // Error is already logged in calculateLayout()
                    Color.clear
                        .onAppear {
                            ELOG("skins: ERROR - calculateLayout() returned nil, view will not render")
                        }
                }
            }
            .onChange(of: geometry.size) { newSize in
                ILOG("skins: Container size changed to: \(newSize)")
                if let layout = calculateLayout(for: geometry) {
                    logLayoutInfo(geometry: geometry, layout: layout)
                } else {
                    ELOG("skins: ERROR - calculateLayout() returned nil after size change")
                }
            }
            .onChange(of: traits) { newTraits in
                ILOG("skins: Traits changed to: device=\(newTraits.device.rawValue), displayType=\(newTraits.displayType.rawValue), orientation=\(newTraits.orientation.rawValue), iPadModel=\(newTraits.iPadModel?.rawValue ?? "nil")")
                if let layout = calculateLayout(for: geometry) {
                    logLayoutInfo(geometry: geometry, layout: layout)
                } else {
                    ELOG("skins: ERROR - calculateLayout() returned nil after traits change")
                }
            }
            #if !os(tvOS)
            .overlay(
                MultiTouchView(
                    touchHandler: { touchPhase, touches in
                        // In edit mode, touches are handled by the drag handles — ignore them here.
                        guard !isEditMode else { return }

                        VLOG("MultiTouchView callback: phase=\(touchPhase), touches=\(touches.count)")

                        switch touchPhase {
                        case .began:
                            // Process each new touch
                            for touch in touches {
                                let location = touch.location
                                DLOG("Processing NEW touch: \(touch.id) at \(location)")

                                // Store this touch point for visualization
                                touchLocations.insert(location)

                                // Store the mapping between touch ID and location for D-pad tracking
                                touchLocationsMap[touch.id] = location

                                // Mark this touch as processed
                                processedTouches.insert(touch.id)

                                // Handle this touch location
                                handleTouchAtLocation(location, in: geometry.size, touchId: touch.id)

                                // Start a long-press timer for turbo toggle (0.6s hold)
                                if Defaults[.turboEnabled] {
                                    let touchId = touch.id
                                    let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
                                        Task { @MainActor in
                                            // Determine which button this touch is on
                                            if let buttonId = touchToButtonMap[touchId] {
                                                let wasEnabled = inputHandler.turboManager.toggleTurbo(for: buttonId)
                                                turboToggledThisTouch.insert(touchId)
                                                DLOG("Turbo toggled via long-press for \(buttonId): \(wasEnabled ? "ON" : "OFF")")
                                                #if canImport(UIKit) && !os(tvOS)
                                                if !ProcessInfo.processInfo.isiOSAppOnMac {
                                                    let generator = UINotificationFeedbackGenerator()
                                                    generator.notificationOccurred(wasEnabled ? .success : .warning)
                                                }
                                                #endif
                                            }
                                        }
                                    }
                                    turboLongPressTimers[touchId] = timer
                                }
                            }
                            DLOG("Current touch points: \(touchLocations.count)")

                        case .moved:
                            // Only process touches that have actually moved significantly OR are on D-pad
                            // D-pad touches need continuous processing for direction updates
                            // Regular button touches should only process if moved significantly
                            for touch in touches {
                                let location = touch.location
                                let previousLocation = touchLocationsMap[touch.id]

                                // Check if this touch is associated with a D-pad (needs continuous processing)
                                let isDPadTouch = touchToDPadMap[touch.id] != nil

                                // Check if touch has moved significantly (more than 1 point)
                                let hasMoved: Bool
                                if let prev = previousLocation {
                                    let dx = location.x - prev.x
                                    let dy = location.y - prev.y
                                    let distance = sqrt(dx * dx + dy * dy)
                                    hasMoved = distance > 1.0
                                } else {
                                    // New touch that wasn't tracked (shouldn't happen, but handle it)
                                    hasMoved = true
                                }

                                // Process if: D-pad touch (always needs updates) OR has moved significantly
                                if isDPadTouch || hasMoved {
                                    // Cancel turbo long-press timer if touch moved
                                    if hasMoved {
                                        turboLongPressTimers[touch.id]?.invalidate()
                                        turboLongPressTimers.removeValue(forKey: touch.id)
                                    }

                                    if isDPadTouch {
                                        DLOG("Processing D-PAD touch: \(touch.id) at \(location)")
                                    } else {
                                        DLOG("Processing MOVED touch: \(touch.id) at \(location) (was at \(previousLocation ?? .zero))")
                                    }

                                    // Update touch location
                                    touchLocations.insert(location)
                                    touchLocationsMap[touch.id] = location

                                    // Handle this touch location
                                    handleTouchAtLocation(location, in: geometry.size, touchId: touch.id)
                                } else {
                                    DLOG("Skipping touch \(touch.id) - hasn't moved significantly and not D-pad")
                                }
                            }

                        case .ended, .cancelled:
                            // Process ended touches
                            for touch in touches {
                                DLOG("Ending touch: \(touch.id)")

                                // Cancel any pending turbo long-press timer
                                turboLongPressTimers[touch.id]?.invalidate()
                                turboLongPressTimers.removeValue(forKey: touch.id)
                                turboToggledThisTouch.remove(touch.id)

                                // Remove this touch point from visualization
                                touchLocations.remove(touch.location)

                                // Remove touch location mapping
                                touchLocationsMap.removeValue(forKey: touch.id)

                                // Remove from processed touches
                                processedTouches.remove(touch.id)

                                // Release any button associated with this touch
                                // Remove from map FIRST, then check if button should be released
                                if let buttonId = touchToButtonMap[touch.id] {
                                    DLOG("Releasing button \(buttonId) for touch \(touch.id)")
                                    touchToButtonMap.removeValue(forKey: touch.id)
                                    handleButtonRelease(buttonId)
                                }

                                // Release D-pad directions if this touch was on the D-pad
                                if touchToDPadMap[touch.id] != nil {
                                    DLOG("Releasing D-pad directions for touch \(touch.id)")
                                    releaseDPadDirectionsForTouch(touch.id)
                                    touchToDPadMap.removeValue(forKey: touch.id)
                                }
                            }

                            // If all touches are gone, ensure everything is reset
                            if touchToButtonMap.isEmpty && touchToDPadMap.isEmpty {
                                DLOG("All touches ended, cleaning up")

                                // Clear active buttons to ensure visual feedback is removed
                                activeButtons.removeAll()

                                // Reset state
                                touchLocations.removeAll()
                                processedTouches.removeAll()
                                currentlyPressedButton = nil

                                // Double-check that all D-pad buttons are released
                                for direction in ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"] {
                                    if pressedButtons.contains(direction) {
                                        DLOG("Force releasing stuck D-pad button: \(direction)")
                                        handleButtonRelease(direction)
                                    }
                                }

                                // Clear all pressed buttons as a final safety measure
                                let allButtons = pressedButtons
                                for buttonId in allButtons {
                                    handleButtonRelease(buttonId)
                                }
                            }
                        }
                    }
                    , ignoredRects: thumbstickIgnoredRects(in: geometry)
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(!isEditMode)
            )
            #endif
        }
    }

    /// Compute regions (in view coordinates) occupied by thumbsticks.
    /// Touches within these rects should pass through the MultiTouch overlay to reach the thumbstick drag gesture.
    private func thumbstickIgnoredRects(in geometry: GeometryProxy) -> [CGRect] {
        guard let buttons = skin.buttons(for: traits), let mappingSize = skin.mappingSize(for: traits) else { return [] }
        // Use the same transform used for button hit testing to ensure coordinates match overlay space
        let margin: CGFloat = 12
        return buttons.compactMap { button in
            guard isThumbstick(button) else { return nil }
            let effective = buttonWithEffectiveFrame(button)
            let scaled = transformFrame(effective.frame, in: geometry, mappingSize: mappingSize)
            return scaled.insetBy(dx: -margin, dy: -margin)
        }
    }

    private func loadSkinResources() {
        ILOG("skins: loadSkinResources() called - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue)")
        ILOG("skins: Checking if skin supports traits: \(traits.description)")

        let supportsTraits = skin.supports(traits)
        ILOG("skins: Skin supports traits: \(supportsTraits)")

        if let mappingSize = skin.mappingSize(for: traits) {
            ILOG("skins: Skin mapping size: \(mappingSize)")
        } else {
            ELOG("skins: ERROR - Skin has no mapping size for traits: \(traits.description)")
        }

        Task {
            // Load skin image
            ILOG("skins: Attempting to load skin image for traits: \(traits.description)")
            do {
                skinImage = try await skin.image(for: traits)
                if let image = skinImage {
                    ILOG("skins: Successfully loaded skin image: \(image.size)")
                } else {
                    ELOG("skins: ERROR - Skin image is nil after loading")
                }
            } catch {
                loadingError = error
                ELOG("skins: ERROR loading skin image: \(error)")
                ELOG("skins: Error details - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue)")
            }

            // Load screen groups
            screenGroups = skin.screenGroups(for: traits)
            ILOG("skins: Loaded screen groups: \(screenGroups?.count ?? 0)")

            // Load button mappings
            buttonMappings = skin.buttonMappings(for: traits)
            ILOG("skins: Loaded button mappings: \(buttonMappings?.count ?? 0)")

            // Load per-button asset images (if any)
            await loadButtonAssets()
        }
    }

    /// Load and cache per-button images defined in the skin JSON under each item's `asset` or `states` key
    private func loadButtonAssets() async {
        guard let buttons = skin.buttons(for: traits) else { return }
        var cache: [String: (normal: UIImage, pressed: UIImage?)] = [:]

        for button in buttons {
            // Prefer typed `states` from decoded model (Manic EMU format)
            if let states = button.states {
                if let normalName = states.normal?.image {
                    do {
                        let normal = try await skin.loadThumbstickImage(named: normalName)
                        var pressedImage: UIImage? = nil
                        if let pressedName = states.pressed?.image {
                            do {
                                pressedImage = try await skin.loadThumbstickImage(named: pressedName)
                            } catch {
                                ELOG("Failed to load pressed state image '\(pressedName)' for button \(button.id): \(error)")
                            }
                        }
                        cache[button.id] = (normal: normal, pressed: pressedImage)
                        continue // Successfully loaded from typed states; skip legacy path
                    } catch {
                        ELOG("Failed to load button state image(s) for \(button.id): \(error)")
                        // Fall through to legacy asset path
                    }
                }
                // states.normal was nil or image load failed — fall through to legacy path
            }

            // Fall back to legacy `asset` dictionary in raw JSON
            guard let (normalName, pressedName) = parseButtonAssetNames(for: button) else { continue }
            do {
                let normal = try await skin.loadThumbstickImage(named: normalName)
                var pressedImage: UIImage? = nil
                if let pn = pressedName {
                    do {
                        pressedImage = try await skin.loadThumbstickImage(named: pn)
                    } catch {
                        ELOG("Failed to load pressed asset image '\(pn)' for button \(button.id): \(error)")
                    }
                }
                cache[button.id] = (normal: normal, pressed: pressedImage)
            } catch {
                ELOG("Failed to load button asset image(s) for \(button.id): \(error)")
            }
        }

        await MainActor.run {
            self.buttonAssetImages = cache
        }
    }

    /// Find `asset.normal` and optional `asset.pressed` for the JSON item matching this button
    private func parseButtonAssetNames(for button: DeltaSkinButton) -> (String, String?)? {
        guard let reps = skin.jsonRepresentation["representations"] as? [String: Any],
              let deviceRep = reps[traits.device.rawValue] as? [String: Any],
              let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
              let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
              let items = orientationRep["items"] as? [[String: Any]] else {
            return nil
        }

        // Match by exact frame to locate the correct item
        guard let item = items.first(where: { item in
            guard let frame = item["frame"] as? [String: Any],
                  let x = frame["x"] as? CGFloat,
                  let y = frame["y"] as? CGFloat,
                  let w = frame["width"] as? CGFloat,
                  let h = frame["height"] as? CGFloat else { return false }
            return CGRect(x: x, y: y, width: w, height: h) == button.frame
        }) else { return nil }

        guard let asset = item["asset"] as? [String: Any],
              let normal = asset["normal"] as? String else { return nil }
        let pressed = asset["pressed"] as? String
        return (normal, pressed)
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

    /// Calculate distance from a point to the center of a button
    private func distanceToButtonCenter(_ location: CGPoint, button: DeltaSkinButton, buttonScaleX: CGFloat, buttonScaleY: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> CGFloat {
        let buttonCenterX = button.frame.midX * buttonScaleX + xOffset
        let buttonCenterY = button.frame.midY * buttonScaleY + yOffset
        let dx = location.x - buttonCenterX
        let dy = location.y - buttonCenterY
        return sqrt(dx * dx + dy * dy)
    }

    /// Check if a touch location is within a D-pad direction's hit area
    /// Calculates bounding box from all four direction hit boxes and treats center as valid
    /// No dead zone - center touches resolve to nearest direction
    private func isLocationInDPadDirection(_ location: CGPoint, button: DeltaSkinButton, buttonScaleX: CGFloat, buttonScaleY: CGFloat, xOffset: CGFloat, yOffset: CGFloat) -> Bool {
        // Calculate scaled button dimensions
        let scaledButtonWidth = button.frame.width * buttonScaleX
        let scaledButtonHeight = button.frame.height * buttonScaleY

        // Calculate the bounding box for each direction (matching dpadMapping layout)
        // Each direction is 0.33 width/height of the button
        let dirSizeW = scaledButtonWidth * 0.33
        let dirSizeH = scaledButtonHeight * 0.33

        // Button frame in view coordinates (the actual button.frame scaled and positioned)
        let buttonFrame = CGRect(
            x: button.frame.minX * buttonScaleX + xOffset,
            y: button.frame.minY * buttonScaleY + yOffset,
            width: scaledButtonWidth,
            height: scaledButtonHeight
        )

        // Calculate bounding boxes for each direction (matching dpadMapping .position() calls)
        // Up: center x, y = frame.height * 0.16 (relative to frame origin)
        let upRect = CGRect(
            x: buttonFrame.midX - dirSizeW / 2,
            y: buttonFrame.minY + buttonFrame.height * 0.16 - dirSizeH / 2,
            width: dirSizeW,
            height: dirSizeH
        )

        // Down: center x, y = frame.height * 0.84
        let downRect = CGRect(
            x: buttonFrame.midX - dirSizeW / 2,
            y: buttonFrame.minY + buttonFrame.height * 0.84 - dirSizeH / 2,
            width: dirSizeW,
            height: dirSizeH
        )

        // Left: x = frame.width * 0.16, center y
        let leftRect = CGRect(
            x: buttonFrame.minX + buttonFrame.width * 0.16 - dirSizeW / 2,
            y: buttonFrame.midY - dirSizeH / 2,
            width: dirSizeW,
            height: dirSizeH
        )

        // Right: x = frame.width * 0.84, center y
        let rightRect = CGRect(
            x: buttonFrame.minX + buttonFrame.width * 0.84 - dirSizeW / 2,
            y: buttonFrame.midY - dirSizeH / 2,
            width: dirSizeW,
            height: dirSizeH
        )

        // Calculate overall bounding box that contains all four direction boxes
        let minX = min(upRect.minX, downRect.minX, leftRect.minX, rightRect.minX)
        let maxX = max(upRect.maxX, downRect.maxX, leftRect.maxX, rightRect.maxX)
        let minY = min(upRect.minY, downRect.minY, leftRect.minY, rightRect.minY)
        let maxY = max(upRect.maxY, downRect.maxY, leftRect.maxY, rightRect.maxY)

        // Add small padding to the bounding box (12pt in view space)
        let padding: CGFloat = 12
        let boundingBox = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + (padding * 2),
            height: (maxY - minY) + (padding * 2)
        )

        // If touch is within the overall D-pad bounding box, it's a D-pad hit
        // No dead zone - center will be resolved to nearest direction in handleDPadInput
        return boundingBox.contains(location)
    }

    /// Handle a touch at the given location
    private func handleTouchAtLocation(_ location: CGPoint, in size: CGSize, touchId: ObjectIdentifier) {
        DLOG("handleTouchAtLocation: location=\(location), touchId=\(touchId)")
        // Store the touch location for visual feedback and direction detection
        touchLocations.insert(location)

        guard let buttons = skin.buttons(for: traits),
              let mappingSize = skin.mappingSize(for: traits) else { return }

        // Use the same transformation logic as transformFrame
        let (buttonScaleX, buttonScaleY, xOffset, yOffset) = calculateButtonTransform(in: size, mappingSize: mappingSize)

        // Check if THIS specific touch is already associated with a D-pad button
        // Only check and update if this touch was previously on a D-pad
        if let existingDPadButton = touchToDPadMap[touchId], case .directional = existingDPadButton.input {
            let effectiveDPad = buttonWithEffectiveFrame(existingDPadButton)
            // This touch is already on a D-pad - check if it's still within the hit area
            if isLocationInDPadDirection(location, button: effectiveDPad, buttonScaleX: buttonScaleX, buttonScaleY: buttonScaleY, xOffset: xOffset, yOffset: yOffset) {
                // Still within D-pad hit area, update D-pad input for this touch
                handleDPadInput(effectiveDPad, scale: buttonScaleX, xOffset: xOffset, yOffset: yOffset, mappingSize: mappingSize, touchId: touchId)
                return
            } else {
                // This touch moved outside the D-pad hit area, release directions for THIS touch only
                DLOG("Touch \(touchId) moved outside D-pad area - releasing directions for this touch")
                releaseDPadDirectionsForTouch(touchId)
                touchToDPadMap.removeValue(forKey: touchId)
                // Continue to check if touch is now on another button
            }
        }

        // Check if THIS specific touch is already associated with a regular button
        // If it is and still on that button, don't re-process
        if let existingButtonId = touchToButtonMap[touchId] {
            // Check if touch is still on the same button
            if let buttons = skin.buttons(for: traits) {
                let existingButton = buttons.first { button in
                    let inputCommand = extractInputCommand(from: button)
                    return inputCommand == existingButtonId
                }

                if let button = existingButton {
                    let effective = buttonWithEffectiveFrame(button)
                    let hitFrame = effective.frame.insetBy(dx: -20, dy: -20)
                    let scaledFrame = CGRect(
                        x: hitFrame.minX * buttonScaleX + xOffset,
                        y: yOffset + (hitFrame.minY * buttonScaleY),
                        width: hitFrame.width * buttonScaleX,
                        height: hitFrame.height * buttonScaleY
                    )

                    if scaledFrame.contains(location) {
                        // Still on the same button, no need to re-process
                        DLOG("Touch \(touchId) still on button \(existingButtonId), skipping re-processing")
                        return
                    }
                }
            }

            // Touch moved off the button it was associated with
            // Remove this touch's association FIRST, then check if button should be released
            DLOG("Touch \(touchId) moved off button \(existingButtonId), releasing")
            touchToButtonMap.removeValue(forKey: touchId)
            // Now check if any other touches are still holding this button
            handleButtonRelease(existingButtonId)
        }

        // Find all candidate buttons (both D-pad and regular) that the touch might be hitting
        struct ButtonCandidate {
            let button: DeltaSkinButton
            let distance: CGFloat
            let isDPad: Bool
        }

        var candidates: [ButtonCandidate] = []

        for button in buttons {
            let effective = buttonWithEffectiveFrame(button)
            // Check if button is a D-pad by examining its input type
            let isDPad: Bool
            switch button.input {
            case .directional:
                isDPad = true
            default:
                isDPad = false
            }

            if isDPad {
                // For D-pad, check if location is in any direction's hit area
                if isLocationInDPadDirection(location, button: effective, buttonScaleX: buttonScaleX, buttonScaleY: buttonScaleY, xOffset: xOffset, yOffset: yOffset) {
                    let distance = distanceToButtonCenter(location, button: effective, buttonScaleX: buttonScaleX, buttonScaleY: buttonScaleY, xOffset: xOffset, yOffset: yOffset)
                    candidates.append(ButtonCandidate(button: button, distance: distance, isDPad: true))
                }
            } else {
                // For regular buttons, use standard hit area with extension
                let hitFrame = effective.frame.insetBy(dx: -20, dy: -20)
                let scaledFrame = CGRect(
                    x: hitFrame.minX * buttonScaleX + xOffset,
                    y: yOffset + (hitFrame.minY * buttonScaleY),
                    width: hitFrame.width * buttonScaleX,
                    height: hitFrame.height * buttonScaleY
                )

                if scaledFrame.contains(location) {
                    let distance = distanceToButtonCenter(location, button: effective, buttonScaleX: buttonScaleX, buttonScaleY: buttonScaleY, xOffset: xOffset, yOffset: yOffset)
                    candidates.append(ButtonCandidate(button: button, distance: distance, isDPad: false))
                }
            }
        }

        // Sort candidates by priority: distance-based with D-pad preference
        // If a D-pad is detected, prioritize it unless a regular button is significantly closer
        candidates.sort { candidate1, candidate2 in
            // If both are D-pad or both are regular, prefer closer one
            if candidate1.isDPad == candidate2.isDPad {
                return candidate1.distance < candidate2.distance
            }

            // Mixed types: prefer D-pad unless regular button is much closer
            // Use a threshold: if regular button is 2x closer, prioritize it
            if candidate1.isDPad && !candidate2.isDPad {
                // candidate1 is D-pad, candidate2 is regular
                // Prefer D-pad unless regular is significantly closer
                return candidate2.distance > candidate1.distance * 2.0
            } else {
                // candidate1 is regular, candidate2 is D-pad
                // Prefer D-pad unless regular is significantly closer
                return candidate1.distance < candidate2.distance * 2.0
            }
        }

        // Get the best candidate based on distance and type priority
        let touchedButton = candidates.first?.button
        let isDPadButton = candidates.first?.isDPad ?? false

        // Handle button state changes
        if let button = touchedButton {
            if isThumbstick(button) {
                // Handle thumbstick
                Task {
                    if let (image, size) = await loadThumbstickImage(for: button) {
                        // Determine stick ID based on button ID (check for "left" or "right" in button ID)
                        let stickId = button.id.lowercased().contains("right") ? "rightAnalog" : "leftAnalog"
                        let effectiveThumbstick = buttonWithEffectiveFrame(button)
                        activeThumbsticks.append(ActiveThumbstickInfo(frame: effectiveThumbstick.frame, image: image, size: size, buttonId: stickId))
                    }
                }
            } else if isDPadButton, case .directional = button.input {
                // Special handling for D-pad buttons to allow direction changes
                // Track this touch as being on the D-pad
                touchToDPadMap[touchId] = button
                handleDPadInput(button, scale: buttonScaleX, xOffset: xOffset, yOffset: yOffset, mappingSize: mappingSize, touchId: touchId)
            } else {
                // For non-D-pad buttons, use our multi-button press system
                // If this touch was previously on the D-pad, release D-pad directions for it
                if touchToDPadMap[touchId] != nil {
                    DLOG("Touch moved from D-pad to non-D-pad button, releasing D-pad directions")
                    // Remove from map first so releaseDPadDirectionsForTouch doesn't include it
                    touchToDPadMap.removeValue(forKey: touchId)
                    releaseDPadDirectionsForTouch(touchId)
                }

                // Extract the input command
                let inputCommand = extractInputCommand(from: button)

                // Use our enhanced button press handling that supports multiple buttons
                // Only press if not already pressed (supports multiple touches on same button)
                if !pressedButtons.contains(inputCommand) {
                    handleButtonPress(inputCommand)
                    DLOG("Pressed button \(inputCommand) via touch \(touchId)")
                }

                // Associate this touch with this button (update mapping even if already pressed)
                touchToButtonMap[touchId] = inputCommand
                DLOG("Associated touch \(touchId) with button \(inputCommand)")

                // Don't update currentlyPressedButton - it's legacy and causes issues with multi-touch
                // Each touch is tracked independently via touchToButtonMap and touchToDPadMap

                // Add visual feedback
                let highlightButtonId = button.id

                let newButton = ActiveButtonInfo(
                    frame: buttonWithEffectiveFrame(button).frame,
                    mappingSize: mappingSize,
                    buttonId: highlightButtonId
                )
                activeButtons.append(newButton)

                // Clean up old highlights after delay
                let buttonTimestamp = newButton.timestamp
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    activeButtons.removeAll { $0.timestamp <= buttonTimestamp }
                }
            }

        } else {
            // Touch is not on any button
            // Only release if this specific touch was associated with a button/D-pad
            if let dpadButton = touchToDPadMap[touchId] {
                // This touch was on D-pad but moved off, release D-pad directions for this touch only
                DLOG("Touch \(touchId) moved off D-pad, releasing directions for this touch")
                releaseDPadDirectionsForTouch(touchId)
                touchToDPadMap.removeValue(forKey: touchId)
            } else if let buttonId = touchToButtonMap[touchId] {
                // This touch was on a non-D-pad button but moved off, release it
                // Remove this touch's association FIRST, then check if button should be released
                DLOG("Touch \(touchId) moved off button \(buttonId), releasing")
                touchToButtonMap.removeValue(forKey: touchId)
                // Now check if any other touches are still holding this button
                handleButtonRelease(buttonId)
            }
            // Note: Don't clear currentlyPressedButton here - it's managed per-touch now
        }
    }

    // We're now using a simplified approach with DragGesture instead of individual touch tracking

    #if !os(tvOS)
    private let buttonGenerator: UIImpactFeedbackGenerator = {
        // Haptic feedback
        let buttonGenerator = UIImpactFeedbackGenerator(style: .medium)
        buttonGenerator.prepare()
        return buttonGenerator
    }()
    #endif

    /// Calculate button transformation parameters using the same logic as calculateLayout
    private func calculateButtonTransform(in size: CGSize, mappingSize: CGSize) -> (buttonScaleX: CGFloat, buttonScaleY: CGFloat, xOffset: CGFloat, yOffset: CGFloat) {
        // Use the same logic as calculateLayout to determine effective image size
        let effectiveImageSize: CGSize
        if let image = skinImage {
            // Check if this is a simple image-based skin (no screens array defined)
            // A gameScreenFrame alone doesn't make it a complex skin - it's just metadata
            let hasScreens = skin.screens(for: traits) != nil || skin.screenGroups(for: traits) != nil

            if !hasScreens {
                // Simple image-based skin: use actual image size for scaling
                // Even if it has gameScreenFrame, it's still a simple image skin
                effectiveImageSize = image.size
            } else {
                // Complex skin with screens array: use mappingSize as before
                effectiveImageSize = mappingSize
            }
        } else {
            // No image loaded yet, use mappingSize
            effectiveImageSize = mappingSize
        }

        // Use the same scale calculation as calculateLayout
        var scale: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Start with width scale to fill screen
            scale = size.width / effectiveImageSize.width

            // Calculate resulting height
            let scaledHeight = effectiveImageSize.height * scale

            // If height exceeds screen, scale down while maintaining aspect ratio
            if scaledHeight > size.height {
                let heightScale = size.height / effectiveImageSize.height
                scale = min(scale, heightScale)
            }
        } else {
            // For landscape, use standard fit scaling
            scale = min(
                size.width / effectiveImageSize.width,
                size.height / effectiveImageSize.height
            )
        }

        let scaledSkinWidth = effectiveImageSize.width * scale
        let scaledSkinHeight = effectiveImageSize.height * scale
        let xOffset = (size.width - scaledSkinWidth) / 2

        // Use the same Y offset calculation as calculateLayout
        let yOffset: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Position at bottom of screen for iPhone portrait
            yOffset = size.height - scaledSkinHeight
        } else {
            // Center vertically for landscape or iPad
            yOffset = (size.height - scaledSkinHeight) / 2
        }

        // Calculate button frame scale factor (for mapping button coordinates from mappingSize space to effectiveImageSize space)
        let buttonScaleX = scaledSkinWidth / mappingSize.width
        let buttonScaleY = scaledSkinHeight / mappingSize.height

        return (buttonScaleX, buttonScaleY, xOffset, yOffset)
    }

    /// Returns a copy of the button with its frame shifted by any saved user offset.
    /// When there is no saved offset the original button is returned unchanged.
    private func buttonWithEffectiveFrame(_ button: DeltaSkinButton) -> DeltaSkinButton {
        let offset = buttonOffsets.offset(for: button.id, skinIdentifier: skin.identifier)
        guard offset != .zero else { return button }
        return DeltaSkinButton(
            id: button.id,
            input: button.input,
            frame: CGRect(
                x: button.frame.minX + offset.x,
                y: button.frame.minY + offset.y,
                width: button.frame.width,
                height: button.frame.height
            ),
            extendedEdges: button.extendedEdges,
            haptic: button.haptic,
            states: button.states,
            selfRetracting: button.selfRetracting
        )
    }

    private func transformFrame(_ frame: CGRect, in geometry: GeometryProxy, mappingSize: CGSize) -> CGRect {
        let (buttonScaleX, buttonScaleY, xOffset, yOffset) = calculateButtonTransform(in: geometry.size, mappingSize: mappingSize)

        return CGRect(
            x: frame.minX * buttonScaleX + xOffset,
            y: yOffset + (frame.minY * buttonScaleY),
            width: frame.width * buttonScaleX,
            height: frame.height * buttonScaleY
        )
    }

    /// Release D-pad directions for a specific touch
    /// Since we support multiple directions simultaneously, we need to recalculate
    /// which directions should remain active based on other active D-pad touches
    private func releaseDPadDirectionsForTouch(_ touchId: ObjectIdentifier) {
        // Calculate what directions should remain active from other D-pad touches
        var remainingDirections: Set<String> = []

        for (remainingTouchId, dpadButton) in touchToDPadMap {
            if remainingTouchId != touchId, let location = touchLocationsMap[remainingTouchId] {
                guard let mappingSize = skin.mappingSize(for: traits) else { continue }
                let (buttonScaleX, buttonScaleY, xOffset, yOffset) = calculateButtonTransform(
                    in: previewSize.width > 0 && previewSize.height > 0 ? previewSize : CGSize(width: location.x * 2, height: location.y * 2),
                    mappingSize: mappingSize
                )

                let buttonCenterX = dpadButton.frame.midX * buttonScaleX + xOffset
                let buttonCenterY = dpadButton.frame.midY * buttonScaleY + yOffset
                let relativeX = location.x - buttonCenterX
                let relativeY = location.y - buttonCenterY

                let buttonWidth = dpadButton.frame.width * buttonScaleX
                let buttonHeight = dpadButton.frame.height * buttonScaleY
                let thresholdX = buttonWidth * 0.3
                let thresholdY = buttonHeight * 0.3

                // Compute cardinal directions for this remaining touch
                var touchDirections: Set<String> = []
                var addedFromThisTouch = false
                if relativeY < -thresholdY { touchDirections.insert("up"); addedFromThisTouch = true }
                if relativeY > thresholdY { touchDirections.insert("down"); addedFromThisTouch = true }
                if relativeX > thresholdX { touchDirections.insert("right"); addedFromThisTouch = true }
                if relativeX < -thresholdX { touchDirections.insert("left"); addedFromThisTouch = true }

                // If nothing crossed thresholds, resolve to nearest direction for this touch
                if !addedFromThisTouch {
                    if abs(relativeX) >= abs(relativeY) {
                        touchDirections.insert(relativeX >= 0 ? "right" : "left")
                    } else {
                        touchDirections.insert(relativeY >= 0 ? "down" : "up")
                    }
                }

                // Resolve diagonals for this touch's button and merge into remaining
                remainingDirections.formUnion(resolveDiagonalDirections(touchDirections, forButton: dpadButton))
            }
        }

        // Track all D-pad tokens (cardinal + diagonal) so diagonal tokens in pressedButtons are released correctly
        let allDpadTokens = ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"]
        let currentDirections: Set<String> = Set(allDpadTokens.filter { pressedButtons.contains($0) })

        // Release directions that are no longer needed
        for direction in currentDirections.subtracting(remainingDirections) {
            ILOG("skins: Releasing D-pad direction after touch ended: \(direction)")
            handleButtonRelease(direction)
        }

        // Clear currentlyPressedButton if no D-pad touches remain
        if touchToDPadMap.isEmpty {
            currentlyPressedButton = nil
        }
    }

    /// Handle D-pad input with support for direction changes and diagonals
    private func handleDPadInput(_ button: DeltaSkinButton, scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat, mappingSize: CGSize, touchId: ObjectIdentifier, touchLocation: CGPoint? = nil) {
        // Get the touch location for this specific touch ID
        let location = touchLocation ?? touchLocationsMap[touchId] ?? touchLocations.first
        guard let touchLocation = location else { return }

        // Use the actual preview size instead of estimating from touch location
        // The scale parameter passed in is buttonScaleX, we need buttonScaleY
        // Recalculate transform using actual view size (fallback to passed values if previewSize not set)
        let viewSize = previewSize.width > 0 && previewSize.height > 0 ? previewSize : CGSize(width: touchLocation.x * 2, height: touchLocation.y * 2)
        let (buttonScaleXActual, buttonScaleYActual, buttonXOffset, buttonYOffset) = calculateButtonTransform(in: viewSize, mappingSize: mappingSize)

        // Calculate the button center in view coordinates
        let buttonCenterX = button.frame.midX * buttonScaleXActual + buttonXOffset
        let buttonCenterY = button.frame.midY * buttonScaleYActual + buttonYOffset

        // Calculate the touch position relative to the button center
        let relativeX = touchLocation.x - buttonCenterX
        let relativeY = touchLocation.y - buttonCenterY

        // Define the center dead zone (very small to avoid a noticeable dead area)
        let buttonWidth = button.frame.width * buttonScaleXActual
        let buttonHeight = button.frame.height * buttonScaleYActual
        let deadZoneRadius = min(buttonWidth, buttonHeight) * 0.02

        // Add debug logging to help diagnose direction issues
        DLOG("D-pad highlight: relativeX=\(relativeX), relativeY=\(relativeY)")

        // Track currently active directions for D-pad
        var activeDirections: Set<String> = []

        // Determine which directions to activate based on touch position
        if sqrt(relativeX * relativeX + relativeY * relativeY) < deadZoneRadius {
            // Near center; we'll resolve to nearest direction via fallback below
            DLOG("skins: D-pad highlight: Near center - using nearest-direction fallback")
        } else {
            // Use threshold-based detection instead of angle to properly support diagonals
            // Calculate thresholds as a percentage of button size
            let thresholdX = buttonWidth * 0.3
            let thresholdY = buttonHeight * 0.3

            ILOG("skins: D-pad input - relativeX=\(relativeX), relativeY=\(relativeY), thresholdX=\(thresholdX), thresholdY=\(thresholdY)")

            // Determine vertical component - check if touch is above or below center
            if relativeY < -thresholdY {
                activeDirections.insert("up")
                ILOG("skins: D-pad detected UP")
            } else if relativeY > thresholdY {
                activeDirections.insert("down")
                ILOG("skins: D-pad detected DOWN")
            }

            // Determine horizontal component - check if touch is left or right of center
            if relativeX > thresholdX {
                activeDirections.insert("right")
                ILOG("skins: D-pad detected RIGHT")
            } else if relativeX < -thresholdX {
                activeDirections.insert("left")
                ILOG("skins: D-pad detected LEFT")
            }

            // Prevent opposite directions on the same axis from being active simultaneously
            // This should never happen with threshold-based detection, but add safety check
            if activeDirections.contains("up") && activeDirections.contains("down") {
                // If both vertical directions detected, choose the stronger one
                if abs(relativeY) > abs(relativeX) {
                    if relativeY < 0 {
                        activeDirections.remove("down")
                    } else {
                        activeDirections.remove("up")
                    }
                } else {
                    // If horizontal component is stronger, remove both vertical directions
                    activeDirections.remove("up")
                    activeDirections.remove("down")
                }
            }

            if activeDirections.contains("left") && activeDirections.contains("right") {
                // If both horizontal directions detected, choose the stronger one
                if abs(relativeX) > abs(relativeY) {
                    if relativeX < 0 {
                        activeDirections.remove("right")
                    } else {
                        activeDirections.remove("left")
                    }
                } else {
                    // If vertical component is stronger, remove both horizontal directions
                    activeDirections.remove("left")
                    activeDirections.remove("right")
                }
            }
        }

        // If no direction was activated (near center or below thresholds), resolve to the nearest single direction
        if activeDirections.isEmpty {
            if abs(relativeX) >= abs(relativeY) {
                activeDirections.insert(relativeX >= 0 ? "right" : "left")
            } else {
                activeDirections.insert(relativeY >= 0 ? "down" : "up")
            }
            ILOG("skins: D-pad fallback to nearest direction: \(activeDirections)")
        }

        // Build resolved directions set from active directions
        var resolvedDirections: Set<String> = activeDirections

        // Resolve cardinal combos to diagonal tokens if the button's directional mapping supports them.
        // This allows skins/cores that expect 'upleft' to receive it instead of separate 'up'+'left'.
        let resolvedWithDiagonals = resolveDiagonalDirections(resolvedDirections, forButton: button)

        // Merge directions from all active D-pad touches
        // Calculate desired directions for ALL active D-pad touches
        var allResolvedDirections: Set<String> = resolvedWithDiagonals

        // Add directions from other active D-pad touches
        for (otherTouchId, otherDPadButton) in touchToDPadMap {
            if otherTouchId != touchId, let otherLocation = touchLocationsMap[otherTouchId] {
                // Calculate directions for this other touch
                let (otherButtonScaleX, otherButtonScaleY, otherXOffset, otherYOffset) = calculateButtonTransform(
                    in: previewSize.width > 0 && previewSize.height > 0 ? previewSize : CGSize(width: otherLocation.x * 2, height: otherLocation.y * 2),
                    mappingSize: mappingSize
                )

                let otherButtonCenterX = otherDPadButton.frame.midX * otherButtonScaleX + otherXOffset
                let otherButtonCenterY = otherDPadButton.frame.midY * otherButtonScaleY + otherYOffset
                let otherRelativeX = otherLocation.x - otherButtonCenterX
                let otherRelativeY = otherLocation.y - otherButtonCenterY

                let otherButtonWidth = otherDPadButton.frame.width * otherButtonScaleX
                let otherButtonHeight = otherDPadButton.frame.height * otherButtonScaleY
                let otherThresholdX = otherButtonWidth * 0.3
                let otherThresholdY = otherButtonHeight * 0.3

                // Compute cardinal directions for this other touch
                var otherTouchDirections: Set<String> = []
                var addedFromThisTouch = false
                if otherRelativeY < -otherThresholdY { otherTouchDirections.insert("up"); addedFromThisTouch = true }
                if otherRelativeY > otherThresholdY { otherTouchDirections.insert("down"); addedFromThisTouch = true }
                if otherRelativeX > otherThresholdX { otherTouchDirections.insert("right"); addedFromThisTouch = true }
                if otherRelativeX < -otherThresholdX { otherTouchDirections.insert("left"); addedFromThisTouch = true }

                // If nothing crossed thresholds (center touch), resolve to nearest direction for this touch
                if !addedFromThisTouch {
                    if abs(otherRelativeX) >= abs(otherRelativeY) {
                        otherTouchDirections.insert(otherRelativeX >= 0 ? "right" : "left")
                    } else {
                        otherTouchDirections.insert(otherRelativeY >= 0 ? "down" : "up")
                    }
                }

                // Resolve diagonals for this touch's button too, then merge
                allResolvedDirections.formUnion(resolveDiagonalDirections(otherTouchDirections, forButton: otherDPadButton))
            }
        }

        // Track all D-pad tokens including diagonals so releases are handled correctly
        let allDpadTokens = ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"]
        let currentDirections: Set<String> = Set(allDpadTokens.filter { pressedButtons.contains($0) })

        // Release directions not in the merged resolved set
        for direction in currentDirections.subtracting(allResolvedDirections) {
            ILOG("skins: Releasing D-pad direction: \(direction)")
            handleButtonRelease(direction)
        }

        // Press directions in the merged resolved set that aren't already active
        for direction in allResolvedDirections.subtracting(currentDirections) {
            ILOG("skins: Pressing D-pad direction: \(direction)")
            handleButtonPress(direction)
        }

        // Update the current button for legacy support (only if this is the only D-pad touch)
        if touchToDPadMap.count == 1 {
            currentlyPressedButton = button
        }

        // Add visual feedback for active directions (show all merged directions)
        if !allResolvedDirections.isEmpty {
            for direction in allResolvedDirections {
                let newButton = ActiveButtonInfo(
                    frame: button.frame,
                    mappingSize: mappingSize,
                    buttonId: direction
                )
                activeButtons.append(newButton)
            }

            #if canImport(UIKit) && !os(tvOS)
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                if let haptic = button.haptic {
                    haptic.play()
                } else if Defaults[.buttonVibration] {
                    buttonGenerator.impactOccurred(intensity: 0.6)
                }
            }
            #endif

            // Play sound with current position (only once)
            playClickSound(for: button)

            // Clean up old highlights after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.activeButtons.removeAll { buttonInfo in
                    let now = Date()
                    return now.timeIntervalSince(buttonInfo.timestamp) > 0.2
                }
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
            let effective = buttonWithEffectiveFrame(button)
            let hitFrame = effective.frame.insetBy(dx: -20, dy: -20)
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
                // Determine stick ID based on button ID (check for "right" or "right" in button ID)
                let stickId = button.id.lowercased().contains("right") ? "rightAnalog" : "leftAnalog"
                activeThumbsticks.append(ActiveThumbstickInfo(frame: buttonWithEffectiveFrame(button).frame, image: image, size: size, buttonId: stickId))
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
        let scaledFrame = screen.outputFrame.map { frame in
            CGRect(
                x: frame.minX * layout.width,
                y: frame.minY * layout.height,
                width: frame.width * layout.width,
                height: frame.height * layout.height
            )
        } ?? CGRect(
            x: 0,
            y: 0,
            width: layout.width,
            height: layout.height
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
                                    Text("Out: \(formatRect(scaledFrame))")
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
                    .overlay {
                        if !isInEmulator {
                            DeltaSkinTestPatternView(
                                frame: CGRect(
                                    x: 0,
                                    y: 0,
                                    width: scaledFrame.width,
                                    height: scaledFrame.height
                                ),
                                filters: filters
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    // Apply default filter overlays in emulator mode
                    .overlay {
                        if isInEmulator && !filters.isEmpty {
                            ZStack {
                                if filters.contains(.scanlines) {
                                    ScanlinesEffect()
                                }
                                if filters.contains(.lcd) {
                                    LCDEffect()
                                }
                                if filters.contains(.subpixel) {
                                    SubpixelEffect()
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
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
                ZStack {
                    // Visual feedback for pressed state
                    let isPressed = pressedButtons.contains(mapping.id)

                    if showDebugOverlay {
                        // Show debug overlay for the button
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .background(Color.red.opacity(isPressed ? 0.6 : 0.3))
                            .overlay(
                                Text(mapping.id)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(4)
                            )
                    } else {
                        // Invisible button area in normal mode with subtle visual feedback
                        Rectangle()
                            .fill(Color.clear)
                            .background(isPressed ? Color.white.opacity(0.2) : Color.clear)
                    }
                }
                .frame(width: scaledFrame.width, height: scaledFrame.height)
                .position(x: absoluteX, y: absoluteY)
                #if !os(tvOS)
                .gesture(
                    // Use a direct gesture without SimultaneousGesture since we removed the main gesture
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
                #endif
                // Make sure this view doesn't block other touch events
                .allowsHitTesting(true)
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
                .fill(showDebugOverlay || pressedButtons.contains("up") ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width / 2,
                    y: frame.height * 0.16
                )
                .overlay(showDebugOverlay ? Text("Up").font(.caption2).foregroundColor(.white) : nil)
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            handleButtonPress("up")
                        }
                        .onEnded { _ in
                            handleButtonRelease("up")
                        }
                )
            #endif
            // Down region
            Rectangle()
                .fill(showDebugOverlay || pressedButtons.contains("down") ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width / 2,
                    y: frame.height * 0.84
                )
                .overlay(showDebugOverlay ? Text("Down").font(.caption2).foregroundColor(.white) : nil)
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            handleButtonPress("down")
                        }
                        .onEnded { _ in
                            handleButtonRelease("down")
                        }
                )
            #endif

            // Left region
            Rectangle()
                .fill(showDebugOverlay || pressedButtons.contains("left") ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width * 0.16,
                    y: frame.height / 2
                )
                .overlay(showDebugOverlay ? Text("Left").font(.caption2).foregroundColor(.white) : nil)
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            handleButtonPress("left")
                        }
                        .onEnded { _ in
                            handleButtonRelease("left")
                        }
                )
            #endif

            // Right region
            Rectangle()
                .fill(showDebugOverlay || pressedButtons.contains("right") ? Color.green.opacity(0.3) : Color.clear)
                .frame(
                    width: frame.width * 0.33,
                    height: frame.height * 0.33
                )
                .position(
                    x: frame.width * 0.84,
                    y: frame.height / 2
                )
                .overlay(showDebugOverlay ? Text("Right").font(.caption2).foregroundColor(.white) : nil)
#if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            handleButtonPress("right")
                        }
                        .onEnded { _ in
                            handleButtonRelease("right")
                        }
                )
            #endif
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
        DLOG("🔴 handleButtonPress called with buttonId: \(buttonId)")

        // --- Sticky button logic ---
        #if canImport(UIKit)
        if Defaults[.stickyButtonsEnabled] {
            let action = inputHandler.stickyManager.handlePress(buttonId)
            stickyButtonIds = inputHandler.stickyManager.stickyButtons
            switch action {
            case .press:
                break // continue with normal press below
            case .release:
                // Double-tap on a sticky button: release it
                pressedButtons.remove(buttonId)
                inputHandler.buttonReleased(buttonId)
                return
            case .ignore:
                return
            }
        }
        #endif

        // Safety check for duplicate press events
        if pressedButtons.contains(buttonId) {
            DLOG("⚠️ Button \(buttonId) already pressed, skipping press event")
            return
        }

        // Add to the set of currently pressed buttons
        pressedButtons.insert(buttonId)
        DLOG("✅ Button pressed: \(buttonId) - Total pressed buttons: \(pressedButtons.count)")
        DLOG("Current pressed buttons: \(pressedButtons)")

        // Play button sound
        if let button = skin.buttons(for: traits)?.first(where: { $0.id == buttonId }) {
            // Haptic feedback — use per-button config when available, fall back to default
            #if canImport(UIKit) && !os(tvOS)
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                if let haptic = button.haptic {
                    haptic.play()
                } else if Defaults[.buttonVibration] {
                    impactGenerator.impactOccurred()
                }
            }
            #endif

            // Play sound with current position (only once)
            playClickSound(for: button)

        }

        // Pass to the input handler
        inputHandler.buttonPressed(buttonId)
    }

    private func handleButtonRelease(_ buttonId: String) {
        DLOG("🔵 handleButtonRelease called with buttonId: \(buttonId)")

        // --- Sticky button logic ---
        #if canImport(UIKit)
        if Defaults[.stickyButtonsEnabled] {
            let action = inputHandler.stickyManager.handleRelease(buttonId)
            if action == .ignore {
                DLOG("Sticky: suppressing release for \(buttonId)")
                return
            }
        }
        #endif

        // Safety check to prevent releasing buttons that weren't pressed
        if !pressedButtons.contains(buttonId) {
            DLOG("⚠️ Button \(buttonId) not pressed, skipping release event")
            return
        }

        // Check if any other touches are still holding this button
        // Only release if no other touches are associated with this button
        let otherTouchesHoldingButton = touchToButtonMap.values.contains(buttonId)

        // For D-pad buttons, check if any other D-pad touches would still activate this direction
        // This is a safety check - releaseDPadDirectionsForTouch should handle D-pad logic correctly
        let dpadButtons = ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"]
        let isDPadButton = dpadButtons.contains(buttonId)

        if otherTouchesHoldingButton {
            DLOG("⚠️ Other touches still holding button \(buttonId), skipping release")
            return
        }

        // For D-pad buttons, if there are other D-pad touches active,
        // releaseDPadDirectionsForTouch should have already calculated if this direction should remain
        // So we allow the release to proceed - the caller (releaseDPadDirectionsForTouch) is responsible
        // for ensuring correct D-pad state

        // Remove from the set of currently pressed buttons
        pressedButtons.remove(buttonId)
        DLOG("✅ Button released: \(buttonId) - Remaining pressed buttons: \(pressedButtons.count)")
        DLOG("Current pressed buttons after release: \(pressedButtons)")

        // Pass to the input handler
        DLOG("Forwarding button release to input handler: \(buttonId)")
        inputHandler.buttonReleased(buttonId)
    }

    /// Resolve cardinal direction combinations to diagonal tokens when the button's directional
    /// mapping supports them. For example, "up"+"left" becomes "upleft" if the mapping contains
    /// an "upleft" key. Falls back to individual cardinal tokens when the mapping has no diagonal keys.
    /// This ensures cores that expect 'upleft' receive the correct token.
    private func resolveDiagonalDirections(_ directions: Set<String>, forButton button: DeltaSkinButton) -> Set<String> {
        guard case .directional(let mapping) = button.input else {
            // Not a directional button or no mapping — pass through unchanged
            return directions
        }

        let hasUp = directions.contains("up")
        let hasDown = directions.contains("down")
        let hasLeft = directions.contains("left")
        let hasRight = directions.contains("right")

        var result = directions

        if hasUp && hasLeft, let token = mapping["upleft"] {
            result.remove("up")
            result.remove("left")
            result.insert(token)
        } else if hasUp && hasRight, let token = mapping["upright"] {
            result.remove("up")
            result.remove("right")
            result.insert(token)
        } else if hasDown && hasLeft, let token = mapping["downleft"] {
            result.remove("down")
            result.remove("left")
            result.insert(token)
        } else if hasDown && hasRight, let token = mapping["downright"] {
            result.remove("down")
            result.remove("right")
            result.insert(token)
        }

        return result
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
            if let touchLocation = touchLocations.first, let mappingSize = skin.mappingSize(for: traits) {
                // Use the same coordinate transformation as handleTouch for consistency
                let viewSize = previewSize.width > 0 && previewSize.height > 0 ? previewSize : CGSize(width: touchLocation.x * 2, height: touchLocation.y * 2)
                let (buttonScaleX, buttonScaleY, xOffset, yOffset) = calculateButtonTransform(in: viewSize, mappingSize: mappingSize)

                // Calculate the button center in view coordinates
                let buttonCenterX = button.frame.midX * buttonScaleX + xOffset
                let buttonCenterY = button.frame.midY * buttonScaleY + yOffset

                // Calculate the touch position relative to the button center
                let relativeX = touchLocation.x - buttonCenterX
                let relativeY = touchLocation.y - buttonCenterY

                // Add debug logging to help diagnose direction issues
                DLOG("D-pad: relativeX=\(relativeX), relativeY=\(relativeY)")

                // Define the center dead zone (very small to avoid a noticeable dead area)
                let buttonWidth = button.frame.width * buttonScaleX
                let buttonHeight = button.frame.height * buttonScaleY
                let deadZoneRadius = min(buttonWidth, buttonHeight) * 0.02

                // Check if touch is near the center and resolve to nearest direction
                if sqrt(relativeX * relativeX + relativeY * relativeY) < deadZoneRadius {
                    if abs(relativeX) >= abs(relativeY) {
                        DLOG("D-pad: Near center - resolving to \(relativeX >= 0 ? "RIGHT" : "LEFT")")
                        return relativeX >= 0 ? (commands["right"] ?? "right") : (commands["left"] ?? "left")
                    } else {
                        DLOG("D-pad: Near center - resolving to \(relativeY >= 0 ? "DOWN" : "UP")")
                        return relativeY >= 0 ? (commands["down"] ?? "down") : (commands["up"] ?? "up")
                    }
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

    /// Reset touch state completely
    private func resetTouchState() {
        DLOG("Resetting DeltaSkinView touch state")
        touchLocations.removeAll()
        touchToButtonMap.removeAll()
        currentlyPressedButton = nil
        activeButtons.removeAll()
        activeThumbsticks.removeAll()
    }

    /// Release all pressed buttons
    private func releaseAllButtons() {
        DLOG("Releasing all pressed buttons in DeltaSkinView: \(pressedButtons)")

        // Release any sticky buttons first so their releases are not suppressed
        let releasedSticky = inputHandler.stickyManager.releaseAll()
        stickyButtonIds.removeAll()
        for buttonId in releasedSticky {
            if !pressedButtons.contains(buttonId) {
                // Sticky button that was not physically pressed — send release to core
                inputHandler.buttonReleased(buttonId)
            }
        }

        // Ensure all D-pad buttons are released
        for direction in ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"] {
            if pressedButtons.contains(direction) {
                handleButtonRelease(direction)
            }
        }

        // Release all other buttons
        let allButtons = pressedButtons
        for buttonId in allButtons {
            handleButtonRelease(buttonId)
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
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let size: CGSize
    let skinImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            if let buttons = skin.buttons(for: traits),
               let mappingSize = skin.mappingSize(for: traits) {
                hitTestOverlayContent(geometry: geometry, buttons: buttons, mappingSize: mappingSize)
            }
        }
    }

    @ViewBuilder
    private func hitTestOverlayContent(geometry: GeometryProxy, buttons: [DeltaSkinButton], mappingSize: CGSize) -> some View {
        // Use the same logic as calculateLayout to determine effective image size
        let effectiveImageSize: CGSize = {
            if let image = skinImage {
                // Check if this is a simple image-based skin (no screens array defined)
                // A gameScreenFrame alone doesn't make it a complex skin - it's just metadata
                let hasScreens = skin.screens(for: traits) != nil || skin.screenGroups(for: traits) != nil

                if !hasScreens {
                    // Simple image-based skin: use actual image size for scaling
                    // Even if it has gameScreenFrame, it's still a simple image skin
                    return image.size
                } else {
                    // Complex skin with screens array: use mappingSize as before
                    return mappingSize
                }
            } else {
                // No image loaded yet, use mappingSize
                return mappingSize
            }
        }()

        // Use the same scale calculation as calculateLayout
        let scale: CGFloat = {
            if traits.device == .iphone && traits.orientation == .portrait {
                // Start with width scale to fill screen
                var scale = geometry.size.width / effectiveImageSize.width

                // Calculate resulting height
                let scaledHeight = effectiveImageSize.height * scale

                // If height exceeds screen, scale down while maintaining aspect ratio
                if scaledHeight > geometry.size.height {
                    let heightScale = geometry.size.height / effectiveImageSize.height
                    scale = min(scale, heightScale)
                }
                return scale
            } else {
                // For landscape, use standard fit scaling
                return min(
                    geometry.size.width / effectiveImageSize.width,
                    geometry.size.height / effectiveImageSize.height
                )
            }
        }()

        let scaledSkinWidth = effectiveImageSize.width * scale
        let scaledSkinHeight = effectiveImageSize.height * scale
        let xOffset = (geometry.size.width - scaledSkinWidth) / 2

        // Use the same Y offset calculation as calculateLayout
        let yOffset: CGFloat = {
            if traits.device == .iphone && traits.orientation == .portrait {
                // Position at bottom of screen for iPhone portrait
                return geometry.size.height - scaledSkinHeight
            } else {
                // Center vertically for landscape or iPad
                return (geometry.size.height - scaledSkinHeight) / 2
            }
        }()

        // Calculate button frame scale factor (for mapping button coordinates from mappingSize space to effectiveImageSize space)
        let buttonScaleX = scaledSkinWidth / mappingSize.width
        let buttonScaleY = scaledSkinHeight / mappingSize.height

        // Draw hit boxes for each button
        ForEach(buttons, id: \.id) { button in
            let scaledFrame = CGRect(
                x: button.frame.minX * buttonScaleX + xOffset,
                y: yOffset + (button.frame.minY * buttonScaleY),
                width: button.frame.width * buttonScaleX,
                height: button.frame.height * buttonScaleY
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
