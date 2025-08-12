import SwiftUI
import PVCoreAudio
import Accelerate
import QuartzCore
import PVCoreBridge
import PVLogging

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

@available(iOS 16.0, *)
public final class RAAudioTapEngine: AudioEngineProtocol {

    public var volume: Float = 1.0
    private weak var provider: (any EmulatorCoreWaveformProvider)?
    public init(provider: (any EmulatorCoreWaveformProvider)?) { self.provider = provider }
    public func setVolume(_ volume: Float) { }
    public func startAudio() throws {}
    public func pauseAudio() {}
    public func stopAudio() {}
    public func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws {}
    private var logTick: Int = 0
    private var lastFetchTime: CFTimeInterval = 0
    private var scratch: [Float] = Array(repeating: 0, count: 1024)
    public func getWaveformData(numberOfPoints: Int) -> WaveformData {
        guard let provider = provider else {
            if logTick % 30 == 0 { DLOG("RAAudioTapEngine: no provider") }
            logTick &+= 1
            return WaveformData(amplitudes: Array(repeating: 0.0, count: numberOfPoints))
        }
        // Throttle to ~60 Hz to reduce bridge overhead
        let now = CACurrentMediaTime()
        if now - lastFetchTime < 1.0/30.0 {
            logTick &+= 1
            return WaveformData(amplitudes: Array(repeating: 0.0, count: numberOfPoints))
        }
        lastFetchTime = now

        let requested = min(max(1, numberOfPoints/2), 128)
        if scratch.count < requested { scratch = Array(repeating: 0, count: requested) }
        let written = provider.copyWaveformAmplitudes(to: &scratch, maxCount: UInt(requested))
        let floats = Array(scratch.prefix(Int(written)))
        if logTick % 30 == 0 {
            let peak = floats.reduce(0) { max($0, abs($1)) }
            DLOG("RAAudioTapEngine: count=\(floats.count) peak=\(String(format: "%.3f", peak)) first=\(String(format: "%.3f", floats.first ?? 0))")
        }
        logTick &+= 1
        // Optionally decimate if we fetched more than needed
        if floats.isEmpty { return WaveformData(amplitudes: Array(repeating: 0.0, count: numberOfPoints)) }
        if floats.count == numberOfPoints { return WaveformData(amplitudes: floats) }
        let step = max(1, floats.count / numberOfPoints)
        var out: [Float] = []
        out.reserveCapacity(numberOfPoints)
        var i = 0
        while out.count < numberOfPoints && i < floats.count {
            out.append(floats[i])
            i += step
        }
        return WaveformData(amplitudes: out)
    }
}
