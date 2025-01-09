//
//  AudioEngines+Settings.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 11/8/24.
//


import PVSettings
import Defaults

extension AudioEngines: Defaults.Serializable {}

public
extension Defaults.Keys {
    static let audioEngine = Key<AudioEngines>("audioEngine",
                                               default: AudioEngines.`default`)
}

// MARK: Audio Settings

import Foundation
import Defaults
import PVAudio

@objc
public extension PVSettingsWrapper {
    @objc
    static var audioEngine: AudioEngines {
        get { Defaults[.audioEngine] }
        set { Defaults[.audioEngine] = newValue }}
    
    @objc
    static var audioRingBufferType: RingBufferType {
        get { Defaults[.audioRingBufferType] }
        set { Defaults[.audioRingBufferType] = newValue }}
}
