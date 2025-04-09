//
//  AudioEngineProtocol.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 9/22/24.
//

import Foundation
import PVCoreBridge

public enum AudioEngineError: Error {
    case engineFailedToStart(_ : OSStatus)
    case failedToCreateAudioEngine(_ : OSStatus)
    case failedToSetOutputDevice(_ : OSStatus)
    case engineStartFailed
    
    var description: String {
        switch self {
        case .engineFailedToStart(let code): return "Engine failed to start with code \(code)"
        case .failedToCreateAudioEngine(let code): return "Failed to create audio engine with code \(code)"
        case .failedToSetOutputDevice(let code): return "Failed to set output device with code \(code)"
        case .engineStartFailed: return "Engine start failed"
        }
    }
}

extension AudioEngineError: CustomNSError {
    public var errorCode: Int {
        switch self {
        case .engineFailedToStart(let code): return Int(code)
        case .failedToCreateAudioEngine(let code): return Int(code)
        case .failedToSetOutputDevice(let code): return Int(code)
        case .engineStartFailed: return -1
        }
    }
    
    public var errorUserInfo: [String: Any] {
        [
            "description" : description,
            "NSLocalizedDescription"  : description
        ]
    }
}

/// Structure to hold waveform data for visualization
public struct WaveformData {
    /// Array of normalized amplitude values (between 0.0 and 1.0)
    public let amplitudes: [Float]
    /// Timestamp when this data was captured
    public let timestamp: TimeInterval
    
    public init(amplitudes: [Float], timestamp: TimeInterval = CACurrentMediaTime()) {
        self.amplitudes = amplitudes
        self.timestamp = timestamp
    }
}

public protocol AudioEngineProtocol {
    func startAudio() throws
    func pauseAudio()
    func stopAudio()
//    func resumeAudio()
    
    var volume: Float { get set }
    func setVolume(_ volume: Float)
    
    func setupAudioGraph(for gameCore: EmulatorCoreAudioDataSource) throws
    
    /// Get current waveform data for visualization
    /// - Parameter numberOfPoints: The number of data points to return
    /// - Returns: WaveformData containing normalized amplitude values
    func getWaveformData(numberOfPoints: Int) -> WaveformData
    
//    func setOutputDeviceID(_ newOutputDeviceID: AudioDeviceID)
}

public extension AudioEngineProtocol {
    mutating func setVolume(_ volume: Float)
    {
        self.volume = volume
    }
    
    /// Default implementation returns empty waveform data
    /// Subclasses should override this with actual implementation
    func getWaveformData(numberOfPoints: Int) -> WaveformData {
        return WaveformData(amplitudes: Array(repeating: 0.0, count: numberOfPoints))
    }
}

public protocol MonoAudioEngine: AudioEngineProtocol {
    func setMono(_ isMono: Bool)
    func toggleMonoOutput()
}
