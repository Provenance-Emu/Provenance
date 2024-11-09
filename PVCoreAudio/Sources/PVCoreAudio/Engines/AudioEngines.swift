//
//  AudioEngines.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 11/7/24.
//

import Foundation

@objc
public enum AudioEngines: Int, CaseIterable, CustomStringConvertible {
    case audioUnitGameAudioEngine
    case avAudioEngineGameAudioEngine
    case dspGameAudioEngine
    
    static let `default`: Self = .avAudioEngineGameAudioEngine
    
    public var description: String {
        switch self {
        case .audioUnitGameAudioEngine:
            return "AudioUnit (Legacy)"
        case .avAudioEngineGameAudioEngine:
            return "AVAudioEngine"
        case .dspGameAudioEngine:
            return "AVAudioEngine + DSP"
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
