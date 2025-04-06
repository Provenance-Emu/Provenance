import SwiftUI
import MetalKit
import PVCoreAudio
import PVThemes

/// A Metal-based audio visualizer with retrowave aesthetics for the Dynamic Island
@available(iOS 14.0, *)
public struct MetalRetrowaveVisualizer: UIViewRepresentable {
    // MARK: - Properties
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let updateInterval: TimeInterval
    
    // MARK: - Initialization
    public init(audioEngine: AudioEngineProtocol, 
                numberOfPoints: Int = 128,
                updateInterval: TimeInterval = 0.03) {
        self.audioEngine = audioEngine
        self.numberOfPoints = numberOfPoints
        self.updateInterval = updateInterval
    }
    
    // MARK: - Coordinator
    public class Coordinator: NSObject {
        var parent: MetalRetrowaveVisualizer
        var renderer: MetalWaveformRenderer
        var displayLink: CADisplayLink?
        var lastUpdateTime: CFTimeInterval = 0
        var metalView: MTKView?
        
        init(parent: MetalRetrowaveVisualizer) {
            self.parent = parent
            self.renderer = MetalWaveformRenderer(maxPoints: parent.numberOfPoints)
            super.init()
            
            // Set up colors based on theme
            let primaryColor = ThemeManager.shared.currentPalette.defaultTintColor.swiftUIColor ?? Color.retroPink
            let secondaryColor = Color.retroCyan
            renderer.setColors(primary: primaryColor, secondary: secondaryColor)
        }
        
        func setupDisplayLink() {
            // Remove any existing display link
            displayLink?.invalidate()
            
            // Create new display link
            displayLink = CADisplayLink(target: self, selector: #selector(updateDisplay))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .main, forMode: .common)
        }
        
        @objc func updateDisplay(displayLink: CADisplayLink) {
            guard let metalView = self.metalView,
                  let currentDrawable = metalView.currentDrawable else {
                return
            }
            
            let currentTime = displayLink.timestamp
            let deltaTime = Float(currentTime - lastUpdateTime)
            
            // Update audio data at specified interval
            if currentTime - lastUpdateTime >= parent.updateInterval {
                let waveformData = parent.audioEngine.getWaveformData(numberOfPoints: parent.numberOfPoints)
                renderer.updateAudioData(waveformData)
            }
            
            lastUpdateTime = currentTime
            
            // Update animation
            renderer.update(deltaTime: deltaTime)
            
            // Render to drawable texture
            renderer.render(to: currentDrawable.texture)
            
            // Present drawable
            currentDrawable.present()
        }
        
        deinit {
            // Clean up resources
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // MARK: - UIViewRepresentable
    public func makeUIView(context: Context) -> MTKView {
        // Create Metal view
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.backgroundColor = .clear
        
        // Store reference in coordinator
        context.coordinator.metalView = mtkView
        
        // Set up display link for animation
        context.coordinator.setupDisplayLink()
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        // Nothing to do here as we're using CADisplayLink for updates
    }
    
    public static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        // Clean up resources
        coordinator.displayLink?.invalidate()
        coordinator.displayLink = nil
    }
}

/// A SwiftUI wrapper for the Metal-based Dynamic Island audio visualizer
@available(iOS 14.0, *)
public struct MetalDynamicIslandAudioVisualizer: View {
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let updateInterval: TimeInterval
    private let isCircular: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Initialize the Metal-based Dynamic Island audio visualizer
    /// - Parameters:
    ///   - audioEngine: The audio engine to get waveform data from
    ///   - numberOfPoints: Number of data points to use for visualization
    ///   - updateInterval: How frequently to update the visualization
    public init(
        audioEngine: AudioEngineProtocol,
        numberOfPoints: Int = 128,
        updateInterval: TimeInterval = 0.03,
        isCircular: Bool = false
    ) {
        self.audioEngine = audioEngine
        self.numberOfPoints = numberOfPoints
        self.updateInterval = updateInterval
        self.isCircular = isCircular
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic Island shape with Metal visualization
                dynamicIslandVisualization()
            }
            .frame(height: 60)
            .frame(width: geometry.size.width)
            // Explicitly center in the parent view
            .position(x: geometry.size.width / 2, y: 30)
        }
    }
    
    /// Visualization specifically designed for Dynamic Island
    private func dynamicIslandVisualization() -> some View {
        // Get dimensions based on device model
        let dimensions = dynamicIslandDimensions()
        let islandWidth = dimensions.width
        let islandHeight = dimensions.height
        
        return ZStack(alignment: .center) {
            // Background grid for retrowave effect
            VisualizationRetrowaveGrid()
                .opacity(0.3)
                .frame(width: islandWidth + 20, height: islandHeight + 20)
                .clipShape(RoundedRectangle(cornerRadius: (islandHeight + 20) / 2))
            
            // Dynamic Island shape
            RoundedRectangle(cornerRadius: islandHeight / 2)
                .fill(Color.black)
                .frame(width: islandWidth, height: islandHeight)
            
            if isCircular {
                // Circular Metal-based waveform visualization around the Dynamic Island
                ZStack {
                    // First, add the Metal visualizer as a background
                    MetalRetrowaveVisualizer(
                        audioEngine: audioEngine,
                        numberOfPoints: numberOfPoints,
                        updateInterval: updateInterval
                    )
                    .frame(width: islandWidth + 30, height: islandHeight + 30)
                    
                    // Add a black overlay to hide the center
                    RoundedRectangle(cornerRadius: islandHeight / 2)
                        .fill(Color.black)
                        .frame(width: islandWidth, height: islandHeight)
                    
                    // Add circular waveform outline with neon glow
                    DynamicIslandCircularWaveform(
                        amplitudes: Array(repeating: 0.5, count: 128), // Static outline
                        islandWidth: islandWidth,
                        islandHeight: islandHeight,
                        amplitudeScale: 6,
                        padding: 4
                    )
                    .stroke(
                        LinearGradient(
                            colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(color: Color.retroPink.opacity(0.8), radius: 3, x: 0, y: 0)
                }
            } else {
                // Standard bar-style Metal visualization
                MetalRetrowaveVisualizer(
                    audioEngine: audioEngine,
                    numberOfPoints: numberOfPoints,
                    updateInterval: updateInterval
                )
                .frame(width: islandWidth, height: islandHeight)
                .clipShape(RoundedRectangle(cornerRadius: islandHeight / 2))
            }
            
            // Add neon border for retrowave effect
            RoundedRectangle(cornerRadius: islandHeight / 2)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: islandWidth, height: islandHeight)
        }
    }
    
    /// Check if the device has a Dynamic Island
    private func isDynamicIslandDevice() -> Bool {
        // Dynamic Island is available on iPhone 14 Pro, iPhone 14 Pro Max, iPhone 15 series, and iPhone 16 series
        let deviceName = UIDevice.current.name
        
        return deviceName.contains("iPhone 14 Pro") || 
               deviceName.contains("iPhone 15") ||
               deviceName.contains("iPhone 16")
    }
    
    /// Get Dynamic Island dimensions based on device model
    private func dynamicIslandDimensions() -> (width: CGFloat, height: CGFloat, topOffset: CGFloat) {
        let screenWidth = UIScreen.main.bounds.width
        let deviceName = UIDevice.current.name
        
        // Default dimensions for iPhone 14 Pro/15 Pro
        var islandWidth: CGFloat = 126
        var islandHeight: CGFloat = 37
        var topOffset: CGFloat = 11 // Distance from top of screen to center of island
        
        // iPhone 14 Pro Max/15 Pro Max has slightly different dimensions
        if deviceName.contains("Max") {
            islandWidth = 126
            islandHeight = 37
            topOffset = 12
        }
        // iPhone 15/16 base models
        else if deviceName.contains("iPhone 15") || deviceName.contains("iPhone 16") {
            islandWidth = 126
            islandHeight = 37
            topOffset = 11
        }
        
        return (islandWidth, islandHeight, topOffset)
    }
}

