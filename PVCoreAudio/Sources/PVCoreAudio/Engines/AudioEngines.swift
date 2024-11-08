//
//  AudioEngines.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 11/7/24.
//

import Foundation

public enum AudioEngines: String, CaseIterable, CustomStringConvertible {
    case audioUnitGameAudioEngine
    case avAudioEngineGameAudioEngine
    case dspGameAudioEngine
    
    static let `default`: Self = .audioUnitGameAudioEngine
    
    public var description: String {
        switch self {
        case .audioUnitGameAudioEngine:
            return "AudioUnit"
        case .avAudioEngineGameAudioEngine:
            return "AVAudioEngine"
        case .dspGameAudioEngine:
            return "DSP"
        }
    }
    
    public func makeAudioEngine() -> any AudioEngineProtocol {
        switch self {
        case .audioUnitGameAudioEngine:
            return AudioUnitGameAudioEngine()
        case .avAudioEngineGameAudioEngine:
            return AVAudioEngineGameAudioEngine()
        case .dspGameAudioEngine:
            return DSPGameAudioEngine()
        }
    }
}

import PVSettings

extension AudioEngines: Defaults.Serializable {}

public
extension Defaults.Keys {
    static let audioEngine = Key<AudioEngines>("audioEngine",
                                               default: AudioEngines.`default`)
}
