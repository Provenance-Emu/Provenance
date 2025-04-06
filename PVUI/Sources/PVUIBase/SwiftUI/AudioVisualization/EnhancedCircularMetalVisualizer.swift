import SwiftUI
import MetalKit
import PVCoreAudio
import PVThemes
import Combine

/// An award-winning circular Metal visualizer with premium retrowave aesthetics
@available(iOS 14.0, *)
public struct EnhancedCircularMetalVisualizer: View {
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let islandWidth: CGFloat
    private let islandHeight: CGFloat
    private let updateInterval: TimeInterval
    
    @StateObject private var audioState: AudioVisualizationState
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.8
    
    public init(
        audioEngine: AudioEngineProtocol,
        numberOfPoints: Int,
        islandWidth: CGFloat,
        islandHeight: CGFloat,
        updateInterval: TimeInterval = 0.008
    ) {
        self.audioEngine = audioEngine
        self.numberOfPoints = numberOfPoints
        self.islandWidth = islandWidth
        self.islandHeight = islandHeight
        self.updateInterval = updateInterval
        
        // Initialize the state object with the audio engine
        _audioState = StateObject(wrappedValue: AudioVisualizationState(
            audioEngine: audioEngine,
            numberOfPoints: numberOfPoints,
            updateInterval: updateInterval
        ))
    }
    
    public var body: some View {
        ZStack {
            // Dynamic Island shape outline with premium glow
            RoundedRectangle(cornerRadius: islandHeight / 2)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.0
                )
                .frame(width: islandWidth, height: islandHeight)
                .shadow(color: Color(hex: "#FF00FF").opacity(glowIntensity), radius: 4, x: 0, y: 0)
            
            // Premium circular visualization with multiple layers
            ForEach(0..<min(numberOfPoints, 40), id: \.self) { index in
                let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(min(numberOfPoints, 40))
                let amplitude = audioState.smoothedAmplitudes.count > index ? audioState.smoothedAmplitudes[index] * 15 : 2
                let baseOffset = (islandWidth/2 + 6)
                
                // Main bar
                ZStack {
                    // Glow background
                    Rectangle()
                        .fill(Color(hex: "#FF00FF").opacity(0.3))
                        .frame(width: 4, height: max(5, amplitude * 1.5))
                        .cornerRadius(2)
                        .blur(radius: 2)
                        .offset(
                            x: baseOffset * cos(angle),
                            y: baseOffset * sin(angle)
                        )
                    
                    // Main bar with gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: max(5, amplitude * 1.5))
                        .cornerRadius(2)
                        .shadow(color: Color(hex: "#FF00FF").opacity(0.8), radius: 3, x: 0, y: 0)
                        .offset(
                            x: baseOffset * cos(angle),
                            y: baseOffset * sin(angle)
                        )
                }
                .rotationEffect(.degrees(rotation * (index % 2 == 0 ? 1 : -1) * 0.05))
                .id("enhanced_circular_bar_\(index)_\(amplitude)")
            }
            
            // Circular particle effects
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * .pi / 6 + rotation * 0.02
                let distance = 50.0 + sin(rotation * 0.01 + Double(i)) * 5.0
                
                Circle()
                    .fill(i % 2 == 0 ? Color(hex: "#FF00FF") : Color(hex: "#00FFFF"))
                    .frame(width: 3, height: 3)
                    .offset(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance
                    )
                    .opacity(0.7)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            audioState.startUpdating()
            
            // Start animation loops
            withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Pulse animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
                glowIntensity = 1.0
            }
        }
        .onDisappear {
            audioState.stopUpdating()
        }
        .scaleEffect(pulseScale)
    }
}
