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
    /// - Note: Uses the closure `default:` overload so the `swift_once` block never calls
    ///   `UserDefaults.register(defaults:)` — see the rationale on `Defaults.Keys.auEffectsChain`
    ///   in `AUFilters/AUFilterSettings.swift`. This key in particular is first touched from
    ///   `-[_PVCoreObjCBridge ringBufferAtIndex:]`, which runs on the emulation thread as well
    ///   as on main.
    static let audioRingBufferType = Key<RingBufferType>("audioRingBufferType",
                                                         default: { RingBufferType.`default` })
}
