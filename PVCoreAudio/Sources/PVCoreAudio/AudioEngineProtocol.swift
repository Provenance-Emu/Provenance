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

    
    var description: String {
        switch self {
        case .engineFailedToStart(let code): return "Engine failed to start with code \(code)"
        case .failedToCreateAudioEngine(let code): return "Failed to create audio engine with code \(code)"
        case .failedToSetOutputDevice(let code): return "Failed to set output device with code \(code)"
        }
    }
}

extension AudioEngineError: CustomNSError {
    public var errorCode: Int {
        switch self {
        case .engineFailedToStart(let code): return Int(code)
        case .failedToCreateAudioEngine(let code): return Int(code)
        case .failedToSetOutputDevice(let code): return Int(code)
        }
    }
    
    public var errorUserInfo: [String: Any] {
        [
            "description" : description,
            "NSLocalizedDescription"  : description
        ]
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
    
//    func setOutputDeviceID(_ newOutputDeviceID: AudioDeviceID)
}

public extension AudioEngineProtocol {
    mutating func setVolume(_ volume: Float)
    {
        self.volume = volume
    }
}

public protocol MonoAudioEngine: AudioEngineProtocol {
    func setMono(_ isMono: Bool)
    func toggleMonoOutput()
}
