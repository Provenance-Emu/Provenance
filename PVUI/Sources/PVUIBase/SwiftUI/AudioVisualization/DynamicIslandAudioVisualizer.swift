import SwiftUI
import PVCoreAudio

/// A Dynamic Island audio visualizer for iOS devices with a notch
@available(iOS 16.0, *)
public struct DynamicIslandAudioVisualizer: View {
    private let audioEngine: AudioEngineProtocol
    private let primaryColor: Color
    private let secondaryColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Initialize the Dynamic Island audio visualizer
    /// - Parameters:
    ///   - audioEngine: The audio engine to get waveform data from
    ///   - primaryColor: Main color for the waveform (default: system accent color)
    ///   - secondaryColor: Secondary color for the glow effect (default: purple)
    public init(
        audioEngine: AudioEngineProtocol,
        primaryColor: Color? = nil,
        secondaryColor: Color = .purple
    ) {
        self.audioEngine = audioEngine
        self.primaryColor = primaryColor ?? Color.accentColor
        self.secondaryColor = secondaryColor
    }
    
    public var body: some View {
        GeometryReader { geometry in
            if #available(iOS 17.0, *) {
                // Use Dynamic Island API on iOS 17+
                dynamicIslandView(geometry: geometry)
            } else {
                // Fallback for iOS 16
                legacyNotchView(geometry: geometry)
            }
        }
    }
    
    private func dynamicIslandView(geometry: GeometryProxy) -> some View {
        // Position at the top center where the Dynamic Island would be
        VStack {
            RetrowaveAudioVisualizer(
                audioEngine: audioEngine,
                numberOfPoints: 60,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                height: 40,
                lineWidth: 2,
                updateInterval: 0.05
            )
            .frame(width: min(geometry.size.width * 0.6, 200))
            .frame(height: 40)
            .padding(.horizontal, 8)
        }
    }
    
    private func legacyNotchView(geometry: GeometryProxy) -> some View {
        VStack {
            // Position the visualizer at the top of the screen
            HStack {
                Spacer()
                RetrowaveAudioVisualizer(
                    audioEngine: audioEngine,
                    numberOfPoints: 60,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    height: 30,
                    lineWidth: 1.5,
                    updateInterval: 0.05
                )
                .frame(width: 200, height: 30)
                .padding(.top, 5)
                Spacer()
            }
            Spacer()
        }
    }
}

/// Extension to add the Dynamic Island audio visualizer to any view
@available(iOS 16.0, *)
public extension View {
    /// Adds a retrowave-styled audio visualizer to the Dynamic Island
    /// - Parameters:
    ///   - isPresented: Binding to control the visibility of the visualizer
    ///   - audioEngine: The audio engine to get waveform data from
    ///   - primaryColor: Main color for the waveform
    ///   - secondaryColor: Secondary color for the glow effect
    /// - Returns: The modified view with the audio visualizer
    func dynamicIslandAudioVisualizer(
        isPresented: Binding<Bool>,
        audioEngine: AudioEngineProtocol,
        primaryColor: Color? = nil,
        secondaryColor: Color = .purple
    ) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    DynamicIslandAudioVisualizer(
                        audioEngine: audioEngine,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor
                    )
                }
            }
        )
    }
}
