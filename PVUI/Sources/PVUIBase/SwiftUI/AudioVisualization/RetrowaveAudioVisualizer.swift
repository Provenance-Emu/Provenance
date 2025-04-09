import SwiftUI
import PVCoreAudio
import Accelerate
import QuartzCore

/// A retrowave-styled audio waveform visualizer that can be used with Dynamic Island
@available(iOS 16.0, *)
public struct RetrowaveAudioVisualizer: View {
    @ObservedObject private var visualizationState: AudioVisualizationState
    private let numberOfPoints: Int
    private let primaryColor: Color
    private let secondaryColor: Color
    private let height: CGFloat
    private let lineWidth: CGFloat
    
    /// Initialize the audio visualizer
    /// - Parameters:
    ///   - audioEngine: The audio engine to get waveform data from
    ///   - numberOfPoints: Number of data points to display
    ///   - primaryColor: Main color for the waveform
    ///   - secondaryColor: Secondary color for the glow effect
    ///   - height: Height of the visualization
    ///   - lineWidth: Width of the waveform lines
    ///   - updateInterval: How frequently to update the visualization (in seconds)
    public init(
        audioEngine: AudioEngineProtocol,
        numberOfPoints: Int = 60,
        primaryColor: Color = .cyan,
        secondaryColor: Color = .purple,
        height: CGFloat = 40,
        lineWidth: CGFloat = 2,
        updateInterval: TimeInterval = 0.05
    ) {
        self.visualizationState = AudioVisualizationState(
            audioEngine: audioEngine,
            numberOfPoints: numberOfPoints,
            updateInterval: updateInterval
        )
        self.numberOfPoints = numberOfPoints
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.height = height
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid lines for retrowave effect
                RetrowaveGrid()
                    .opacity(0.3)
                
                // Waveform visualization
                WaveformPath(amplitudes: visualizationState.smoothedAmplitudes)
                    .stroke(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: lineWidth
                    )
                    .shadow(color: primaryColor.opacity(0.8), radius: 4)
                
                // Glow effect
                WaveformPath(amplitudes: visualizationState.smoothedAmplitudes)
                    .stroke(primaryColor.opacity(0.5), lineWidth: lineWidth * 2)
                    .blur(radius: 3)
            }
            .frame(width: geometry.size.width, height: height)
        }
        .frame(height: height)
        .onAppear {
            visualizationState.startUpdating()
        }
        .onDisappear {
            visualizationState.stopUpdating()
        }
    }
}
