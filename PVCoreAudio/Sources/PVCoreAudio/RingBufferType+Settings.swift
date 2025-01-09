//
//  RingBufferType+Settings.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 11/8/24.
//

import Foundation
import Defaults
import PVAudio

extension RingBufferType: Defaults.Serializable {}

public
extension Defaults.Keys {
    static let audioRingBufferType = Key<RingBufferType>("audioRingBufferType",
                                                         default: RingBufferType.`default`)
}
