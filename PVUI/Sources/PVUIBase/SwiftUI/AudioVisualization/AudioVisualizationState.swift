import SwiftUI
import PVCoreAudio
import Accelerate
import Combine

/// State object to manage audio visualization updates
public class AudioVisualizationState: ObservableObject {
    /// The audio engine to get waveform data from
    private let audioEngine: AudioEngineProtocol
    
    /// Number of data points to display
    private let numberOfPoints: Int
    
    /// How frequently to update the visualization (in seconds)
    private let updateInterval: TimeInterval
    
    /// Timer for updating the visualization
    private var updateTimer: Timer?
    
    /// Published amplitude values for visualization
    @Published public var amplitudes: [CGFloat] = []
    
    /// Smoothed amplitude values for visualization
    @Published public var smoothedAmplitudes: [CGFloat] = []
    
    /// Previous amplitude values for smoothing
    private var previousAmplitudes: [CGFloat] = []
    
    /// Initialize the visualization state
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
        
        // Initialize with empty arrays
        self.amplitudes = Array(repeating: 0, count: numberOfPoints)
        self.smoothedAmplitudes = Array(repeating: 0, count: numberOfPoints)
        self.previousAmplitudes = Array(repeating: 0, count: numberOfPoints)
    }
    
    /// Start updating the visualization
    public func startUpdating() {
        // Stop any existing timer
        stopUpdating()
        
        // Create a new timer to update the visualization
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateVisualization()
        }
    }
    
    /// Stop updating the visualization
    public func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Update the visualization with new data
    private func updateVisualization() {
        // Get waveform data from the audio engine
        let waveformData = audioEngine.getWaveformData(numberOfPoints: numberOfPoints)
        
        // Convert to CGFloat for SwiftUI
        let newAmplitudes = waveformData.amplitudes.map { CGFloat($0) }
        
        // Apply smoothing
        let smoothingFactor: CGFloat = 0.3
        var smoothed: [CGFloat] = []
        
        for i in 0..<newAmplitudes.count {
            let previous = i < previousAmplitudes.count ? previousAmplitudes[i] : 0
            let current = newAmplitudes[i]
            let smoothedValue = previous + smoothingFactor * (current - previous)
            smoothed.append(smoothedValue)
        }
        
        // Update the published values on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.amplitudes = newAmplitudes
            self?.smoothedAmplitudes = smoothed
            self?.previousAmplitudes = smoothed
        }
    }
}
