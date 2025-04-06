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
        updateInterval: TimeInterval = 0.05
    ) {
        self.audioEngine = audioEngine
        self.numberOfPoints = numberOfPoints
        self.updateInterval = updateInterval
        self.visualizationState = AudioVisualizationState(
            audioEngine: audioEngine,
            numberOfPoints: numberOfPoints,
            updateInterval: updateInterval
        )
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic Island detection and layout
                if isDynamicIslandDevice() {
                    dynamicIslandVisualization(in: geometry)
                } else {
                    standardVisualization(in: geometry)
                }
            }
            .onAppear {
                visualizationState.startUpdating()
                animator.startAnimations()
            }
            .onDisappear {
                visualizationState.stopUpdating()
                animator.stopAnimations()
            }
        }
        .frame(height: 60)
    }
    
    /// Visualization specifically designed for Dynamic Island
    private func dynamicIslandVisualization(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height: CGFloat = 60
        
        return ZStack {
            // Background grid for retrowave effect
            VisualizationRetrowaveGrid()
                .opacity(0.3)
                .mask(
                    RoundedRectangle(cornerRadius: 35 / 2)
                        .frame(width: 120, height: 35)
                        .position(x: width / 2, y: 25)
                )
            
            // Waveform visualization
                WaveformPath(amplitudes: visualizationState.smoothedAmplitudes)
                    .stroke(
                        LinearGradient(
                            colors: [Color.pink, Color.purple, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color.cyan, radius: animator.isGlowing ? 4 : 2)
                    .mask(
                        RoundedRectangle(cornerRadius: 35 / 2)
                            .frame(width: 120, height: 35)
                            .position(x: width / 2, y: 25)
                    )
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
                .frame(width: 120, height: 35)
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
        .frame(width: width, height: height)
    }
    
    /// Standard visualization for devices without Dynamic Island
    private func standardVisualization(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height: CGFloat = 60
        
        return ZStack {
            // Background grid for retrowave effect
            VisualizationRetrowaveGrid()
                .opacity(0.3)
            
            // Waveform visualization
                WaveformPath(amplitudes: visualizationState.smoothedAmplitudes)
                    .stroke(
                        LinearGradient(
                            colors: [Color.pink, Color.purple, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color.cyan, radius: animator.isGlowing ? 4 : 2)
            
            // Glow effect
                WaveformPath(amplitudes: visualizationState.smoothedAmplitudes)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 3)
                    .blur(radius: 3)
                    .scaleEffect(animator.pulseScale)
                    .opacity(animator.isGlowing ? 0.8 : 0.4)
        }
        .frame(width: width, height: height)
        .padding(.horizontal, 20)
    }
    

    
    /// Check if the device has a Dynamic Island
    private func isDynamicIslandDevice() -> Bool {
        // Approximate detection based on device model
        let deviceName = UIDevice.current.name
        return deviceName.contains("iPhone 14 Pro") || 
               deviceName.contains("iPhone 15 Pro") ||
               deviceName.contains("iPhone 15")
    }
    
    /// Create a shape that matches the Dynamic Island
    private func dynamicIslandShape(width: CGFloat) -> some View {
        let islandWidth: CGFloat = 120
        let islandHeight: CGFloat = 35
        let cornerRadius: CGFloat = islandHeight / 2
        
        return RoundedRectangle(cornerRadius: cornerRadius)
            .frame(width: islandWidth, height: islandHeight)
            .position(x: width / 2, y: 25)
    }
}

/// Retrowave grid background
private struct VisualizationRetrowaveGrid: View {
    var body: some View {
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
