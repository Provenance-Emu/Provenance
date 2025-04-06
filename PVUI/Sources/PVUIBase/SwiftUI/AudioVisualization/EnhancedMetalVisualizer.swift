import SwiftUI
import MetalKit
import PVCoreAudio
import PVThemes
import Combine

/// An enhanced Metal-based audio visualizer with retrowave aesthetics
@available(iOS 14.0, *)
public struct EnhancedMetalVisualizer: View {
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let updateInterval: TimeInterval
    
    @StateObject private var audioState: AudioVisualizationState
    
    public init(
        audioEngine: AudioEngineProtocol,
        numberOfPoints: Int = 128,
        updateInterval: TimeInterval = 0.008
    ) {
        self.audioEngine = audioEngine
        self.numberOfPoints = numberOfPoints
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
            // Award-winning visualization with multiple layers
            VStack(spacing: 0) {
                // Main waveform bars
                HStack(spacing: 1) {
                    ForEach(0..<min(audioState.smoothedAmplitudes.count, numberOfPoints), id: \.self) { index in
                        let amplitude = audioState.smoothedAmplitudes[index] * 30
                        
                        // Create a bar with multiple segments for a more dynamic look
                        VStack(spacing: 1) {
                            // Top segment (brightest)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 3, height: max(3, amplitude * 0.7))
                                .cornerRadius(1.5)
                                .shadow(color: Color(hex: "#FF00FF").opacity(0.8), radius: 2, x: 0, y: 0)
                            
                            // Middle segment (reflection)
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#00FFFF").opacity(0.7), Color(hex: "#FF00FF").opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 3, height: max(2, amplitude * 0.3))
                                .cornerRadius(1.5)
                                .blur(radius: 0.5)
                        }
                        .id("enhanced_bar_\(index)_\(amplitude)")
                    }
                }
                
                // Reflection surface (horizontal line)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF00FF").opacity(0.3), Color(hex: "#00FFFF").opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .blur(radius: 0.5)
            }
        }
        .onAppear {
            audioState.startUpdating()
        }
        .onDisappear {
            audioState.stopUpdating()
        }
    }
}
