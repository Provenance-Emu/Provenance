import SwiftUI
import MetalKit
import PVCoreAudio
import PVThemes
import Combine

/// An award-winning audio visualizer that perfectly incorporates the Dynamic Island pill design
@available(iOS 14.0, *)
public struct EnhancedCircularMetalVisualizer: View {
    // MARK: - Properties
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let islandWidth: CGFloat
    private let islandHeight: CGFloat
    private let updateInterval: TimeInterval
    
    @StateObject private var audioState: AudioVisualizationState
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.8
    @State private var beatPulse: CGFloat = 0.0
    @State private var energyLevel: CGFloat = 0.0
    @State private var islandGlow: CGFloat = 1.0
    
    // MARK: - Initialization
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
    
    // MARK: - Body
    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center) {
                // Offset the entire ZStack to center properly on the pill
                ZStack(alignment: .center) {
                    // Background grid for retrowave effect
                    VisualizationRetrowaveGrid()
                        .opacity(0.3)
                        .frame(width: geometry.size.width * 1.2, height: geometry.size.height * 1.2)
                        .scaleEffect(1.0 + beatPulse * 0.05)
                    
                    // Dynamic Island shape with glow
                    RoundedRectangle(cornerRadius: islandHeight / 2)
                        .fill(Color.black)
                        .frame(width: islandWidth, height: islandHeight)
                    
                    // Reactive energy waves emanating from the pill
                    ForEach(0..<3) { layer in
                        createEnergyWave(layer: layer, in: geometry)
                    }
                    
                    // Dynamic Island outline with premium glow
                    RoundedRectangle(cornerRadius: islandHeight / 2)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2.0 + beatPulse * 1.5
                        )
                        .frame(width: islandWidth, height: islandHeight)
                        .shadow(
                            color: Color(hex: "#FF00FF").opacity(0.5 + islandGlow * 0.5),
                            radius: 8 + islandGlow * 4,
                            x: 0,
                            y: 0
                        )
                    
                    // Particle system
                    ForEach(0..<20) { i in
                        createParticle(index: i, in: geometry)
                    }
                    
                    // Frequency spectrum visualization
                    createFrequencySpectrum()
                }
                .onChange(of: audioState.smoothedAmplitudes) { newAmplitudes in
                    updateVisualization(with: newAmplitudes)
                }
            }
        }
        // Use the centered positioning with a horizontal offset to align perfectly
        .centeredAtDynamicIsland(horizontalOffset: -islandWidth/2)
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
    }
    
    // MARK: - Helper Methods
    
    /// Creates an energy wave that emanates from the Dynamic Island pill
    private func createEnergyWave(layer: Int, in geometry: GeometryProxy) -> some View {
        let baseScale = 1.0 + CGFloat(layer) * 0.15
        let baseOpacity = 0.7 - CGFloat(layer) * 0.15
        let animationOffset = Double(layer) * 0.1
        
        return ZStack {
            // Create a pill shape that scales with the audio
            RoundedRectangle(cornerRadius: (islandHeight * baseScale) / 2)
                .strokeBorder(
                    getGradientForLayer(layer),
                    lineWidth: 2.0 - CGFloat(layer) * 0.3
                )
                .frame(
                    width: islandWidth * baseScale + energyLevel * 20.0 * CGFloat(layer + 1),
                    height: islandHeight * baseScale + energyLevel * 10.0 * CGFloat(layer + 1)
                )
                .opacity(baseOpacity)
                .scaleEffect(1.0 + beatPulse * 0.1 * CGFloat(3 - layer))
                .rotationEffect(.degrees(rotation * (layer % 2 == 0 ? 0.02 : -0.02)))
                .shadow(
                    color: getGlowColorForLayer(layer).opacity(0.5 + energyLevel * 0.5),
                    radius: 5 + energyLevel * 5,
                    x: 0,
                    y: 0
                )
            
            // Add frequency-specific details to each layer
            ForEach(0..<min(numberOfPoints, 40), id: \.self) { index in
                let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(min(numberOfPoints, 40))
                let layerOffset = CGFloat(layer) * 20.0
                let amplitude = getAmplitudeForLayer(layer, at: index) * 15.0
                
                if amplitude > 3.0 {
                    Circle()
                        .fill(getGlowColorForLayer(layer))
                        .frame(width: 3 + amplitude * 0.3, height: 3 + amplitude * 0.3)
                        .offset(
                            x: cos(angle) * (islandWidth/2 + layerOffset + amplitude),
                            y: sin(angle) * (islandHeight/2 + layerOffset/2 + amplitude/2)
                        )
                        .opacity(min(amplitude * 0.1, 0.8))
                        .blur(radius: 1)
                }
            }
        }
    }
    
    /// Creates a particle that orbits around the Dynamic Island
    private func createParticle(index: Int, in geometry: GeometryProxy) -> some View {
        let angle = Double(index) * .pi / 10 + rotation * 0.02
        let baseDistance = 40.0 + Double(index % 5) * 10.0
        let distance = baseDistance + sin(rotation * 0.01 + Double(index)) * 5.0
        let particleSize = 2.0 + energyLevel * 3.0 * (index % 3 == 0 ? 1.5 : 1.0)
        
        return Circle()
            .fill(index % 2 == 0 ? Color(hex: "#FF00FF") : Color(hex: "#00FFFF"))
            .frame(width: particleSize, height: particleSize)
            .offset(
                x: cos(angle) * distance,
                y: sin(angle) * distance * (islandHeight / islandWidth)
            )
            .opacity(0.7 + energyLevel * 0.3)
            .blur(radius: energyLevel * 1.5)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: energyLevel)
    }
    
    /// Creates a frequency spectrum visualization
    private func createFrequencySpectrum() -> some View {
        ZStack {
            ForEach(0..<min(numberOfPoints/4, 30), id: \.self) { index in
                let normalizedIndex = CGFloat(index) / CGFloat(min(numberOfPoints/4, 30))
                let xPos = normalizedIndex * islandWidth - islandWidth/2
                
                let amplitude = audioState.smoothedAmplitudes.count > index ?
                audioState.smoothedAmplitudes[index] * 12 : 2
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#00FFFF").opacity(0.7),
                                Color(hex: "#FF00FF").opacity(0.7)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: islandWidth / CGFloat(min(numberOfPoints/4, 30)) * 0.8, height: max(2, amplitude * 3))
                    .cornerRadius(1)
                    .offset(x: xPos, y: islandHeight/2 + 5 + amplitude/2)
                    .opacity(0.7)
            }
        }
    }
    
    /// Updates the visualization based on new audio data
    private func updateVisualization(with amplitudes: [CGFloat]) {
        // Calculate overall energy level for this frame
        let newEnergyLevel = amplitudes.prefix(10).reduce(0, +) / 10
        
        // Detect beats for pulse effect
        let bassEnergy = amplitudes.prefix(5).reduce(0, +) / 5
        if bassEnergy > energyLevel * 1.5 && bassEnergy > 0.4 {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                beatPulse = min(bassEnergy * 2, 1.0)
                islandGlow = min(bassEnergy * 3, 1.0)
            }
            
            // Reset beat pulse after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    beatPulse = 0.0
                }
            }
            
            // Reset island glow after a slightly longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    islandGlow = 0.2
                }
            }
        }
        
        // Smoothly update energy level
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            energyLevel = newEnergyLevel
        }
    }
    
    /// Gets the appropriate amplitude for a specific layer and index
    private func getAmplitudeForLayer(_ layer: Int, at index: Int) -> CGFloat {
        let adjustedIndex: Int
        
        switch layer {
        case 0: // High frequencies
            adjustedIndex = Int(Double(numberOfPoints) * 0.66) + (index % (numberOfPoints / 3))
        case 1: // Mid frequencies
            adjustedIndex = Int(Double(numberOfPoints) * 0.33) + (index % (numberOfPoints / 3))
        case 2: // Low frequencies
            adjustedIndex = index % (numberOfPoints / 3)
        default:
            adjustedIndex = index
        }
        
        return audioState.smoothedAmplitudes.count > adjustedIndex ?
        audioState.smoothedAmplitudes[adjustedIndex] : 0
    }
    
    /// Gets the appropriate gradient for a specific layer
    private func getGradientForLayer(_ layer: Int) -> LinearGradient {
        switch layer {
        case 0: // High frequencies - Cyan/Blue
            return LinearGradient(
                colors: [Color(hex: "#00FFFF"), Color(hex: "#0088FF")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case 1: // Mid frequencies - Pink/Orange
            return LinearGradient(
                colors: [Color(hex: "#FF00AA"), Color(hex: "#FF5500")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case 2: // Low frequencies - Magenta/Purple
            return LinearGradient(
                colors: [Color(hex: "#FF00FF"), Color(hex: "#AA00FF")],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    /// Gets the appropriate glow color for a specific layer
    private func getGlowColorForLayer(_ layer: Int) -> Color {
        switch layer {
        case 0: return .retroCyan // Cyan for high frequencies
        case 1: return .retroPink // Pink for mid frequencies
        case 2: return Color(hex: "#FF00FF") // Magenta for low frequencies
        case 3: return .retroBlue
        case 4: return .retroGreen
        default: return Color(hex: "#FF00FF")
        }
    }
}
