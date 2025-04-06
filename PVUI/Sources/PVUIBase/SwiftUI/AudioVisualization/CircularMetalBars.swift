import SwiftUI
import PVCoreAudio
import PVThemes

/// A view that creates circular metal bars that update with audio data
struct CircularMetalBars: View {
    private let audioEngine: AudioEngineProtocol
    private let numberOfPoints: Int
    private let islandWidth: CGFloat
    private let islandHeight: CGFloat
    private let updateInterval: TimeInterval
    
    @StateObject private var audioState: AudioVisualizationState
    
    init(audioEngine: AudioEngineProtocol, numberOfPoints: Int, islandWidth: CGFloat, islandHeight: CGFloat, updateInterval: TimeInterval) {
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
    
    var body: some View {
        ZStack {
            // Metal visualizer in a circle around the Dynamic Island
            ForEach(0..<numberOfPoints, id: \.self) { index in
                let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(numberOfPoints)
                let amplitude = audioState.smoothedAmplitudes.count > index ? audioState.smoothedAmplitudes[index] * 8 : 2
                
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
                    .id("metal_bar_\(index)_\(amplitude)")
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
