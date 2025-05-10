import SwiftUI
import PVCoreAudio
import PVThemes
import Accelerate
import QuartzCore

/// Helper class to manage timers and animations
private class VisualizerAnimator: ObservableObject {
    @Published var isGlowing = false
    @Published var pulseScale: CGFloat = 1.0
    @Published var rotationAngle: Double = 0
    @Published var effectIntensity: Double = 0
    
    private var effectTimer: Timer?
    
    func startAnimations() {
        // Glow animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            self.isGlowing = true
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            self.pulseScale = 1.05
        }
        
        // Rotation animation
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            self.rotationAngle = 2 * .pi
        }
        
        // Start random effects timer
        startEffectTimer()
    }
    
    func startEffectTimer() {
        // Cancel any existing timer
        effectTimer?.invalidate()
        
        // Start a timer for random effects
        effectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            withAnimation(.easeInOut(duration: 1.0)) {
                self.effectIntensity = Double.random(in: 0.5...1.0)
            }
            
            // Reset after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.effectIntensity = 0
                }
            }
        }
    }
    
    func stopAnimations() {
        effectTimer?.invalidate()
        effectTimer = nil
    }
    
    deinit {
        stopAnimations()
    }
}

/// A retrowave-styled audio visualizer that integrates with the Dynamic Island
public struct RetrowaveDynamicIslandAudioVisualizer: View {
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let updateInterval: TimeInterval
    private let isCircular: Bool
    
    @ObservedObject private var visualizationState: AudioVisualizationState
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Animation helper
    @StateObject private var animator = VisualizerAnimator()
    
    /// Initialize the Dynamic Island audio visualizer
    /// - Parameters:
    ///   - audioEngine: The audio engine to get waveform data from
    ///   - numberOfPoints: Number of data points to display
    ///   - updateInterval: How frequently to update the visualization (in seconds)
    public init(
        audioEngine: AudioEngineProtocol,
        numberOfPoints: Int = 60,
        updateInterval: TimeInterval = 0.05,
        isCircular: Bool = false
    ) {
        self.audioEngine = audioEngine
        self.numberOfPoints = numberOfPoints
        self.updateInterval = updateInterval
        self.isCircular = isCircular
        self.visualizationState = AudioVisualizationState(
            audioEngine: audioEngine,
            numberOfPoints: numberOfPoints,
            updateInterval: updateInterval
        )
    }
    
    public var body: some View {
        // Use Dynamic Island visualization positioned exactly at the notch
        dynamicIslandVisualization()
            .positionedAtDynamicIsland()
            .onAppear {
                visualizationState.startUpdating()
                animator.startAnimations()
                
                // Debug: Print waveform data periodically
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    let data = audioEngine.getWaveformData(numberOfPoints: 10)
                    // VLOG("Waveform data sample: \(data.amplitudes[0..<min(10, data.amplitudes.count)])")
                }
            }
            .onDisappear {
                visualizationState.stopUpdating()
                animator.stopAnimations()
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
                // Animated circular waveform visualization around the Dynamic Island
                ZStack {
                    // Dynamic Island shape outline with glow
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
                        .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color.cyan,
                                radius: animator.isGlowing ? 4 : 2)
                    
                    // Simple waveform bars arranged in a circle around the Dynamic Island
                    ForEach(0..<min(visualizationState.smoothedAmplitudes.count, 40), id: \.self) { index in
                        let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(min(visualizationState.smoothedAmplitudes.count, 40))
                        let amplitude = visualizationState.smoothedAmplitudes[index] * 12
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 4, height: max(5, amplitude * 1.5))
                            .cornerRadius(2)
                            .shadow(color: Color(hex: "#FF00FF").opacity(0.8), radius: 3, x: 0, y: 0)
                            .offset(
                                x: (islandWidth/2 + 6) * cos(angle),
                                y: (islandHeight/2 + 6) * sin(angle)
                            )
                        // Force view update with each amplitude change
                            .id("bar_\(index)_\(amplitude)")
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: visualizationState.smoothedAmplitudes)
            } else {
                // Standard bar visualization
                HStack(spacing: 1) {
                    ForEach(0..<min(visualizationState.amplitudes.count, 32), id: \.self) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: max(3, visualizationState.amplitudes[index] * 25))
                            .cornerRadius(1.5)
                            .shadow(color: Color(hex: "#FF00FF").opacity(0.8), radius: 2, x: 0, y: 0)
                    }
                }
                .offset(y: islandHeight / 2 + 5) // Position below the Dynamic Island
            }
        }
        
        // Glow effect that pulses with the audio
        RoundedRectangle(cornerRadius: 35 / 2)
            .stroke(
                LinearGradient(
                    colors: [Color.pink, Color.purple, Color.cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
            .frame(width: islandWidth, height: islandHeight)
            .scaleEffect(animator.pulseScale)
            .opacity(animator.isGlowing ? 0.8 : 0.4)
            .blur(radius: 3)
        
        // Special effect - rotating particles
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .fill(i % 2 == 0 ? Color.retroPink : Color.retroCyan)
                .frame(width: 4, height: 4)
                .offset(x: cos(Double(i) * .pi / 4 + animator.rotationAngle) * 50 * animator.effectIntensity,
                        y: sin(Double(i) * .pi / 4 + animator.rotationAngle) * 20 * animator.effectIntensity)
                .opacity(animator.effectIntensity * 0.8)
                .blur(radius: 2)
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
    
    /// Create a shape that matches the Dynamic Island
    private func dynamicIslandShape(width: CGFloat) -> some View {
        // Adjust these values based on the actual Dynamic Island dimensions
        let islandWidth: CGFloat = 125
        let islandHeight: CGFloat = 37
        let cornerRadius: CGFloat = islandHeight / 2
        
        return RoundedRectangle(cornerRadius: cornerRadius)
            .frame(width: islandWidth, height: islandHeight)
    }
}

/// Retrowave grid background
public struct VisualizationRetrowaveGrid: View {
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal grid lines
                VStack(spacing: 10) {
                    ForEach(0..<Int(geometry.size.height / 10) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.retroPurple.opacity(0.3))
                            .frame(height: 1)
                    }
                }
                
                // Vertical grid lines
                HStack(spacing: 20) {
                    ForEach(0..<Int(geometry.size.width / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.retroCyan.opacity(0.3))
                            .frame(width: 1)
                    }
                }
                
                // Horizon line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.retroPink.opacity(0.7), .retroPurple.opacity(0.3)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: 2)
                    .offset(y: geometry.size.height / 2 - 10)
            }
        }
    }
}
