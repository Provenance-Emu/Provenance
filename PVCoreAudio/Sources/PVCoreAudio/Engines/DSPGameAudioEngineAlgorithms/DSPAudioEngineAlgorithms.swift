//
//  DSPAudioEngineAlgorithms.swift
//  PVCoreAudio
//
//  Created by Joseph Mattiello on 11/7/24.
//

import Foundation
import AVFoundation
import PVSettings

internal typealias DSPAudioEngineRenderBlock = ((AVAudioPCMBuffer) -> Int)

public enum DSPAudioEngineAlgorithms: String, CaseIterable, CustomStringConvertible {
    case SIMD_LinearInterpolation
    
    static let `default`: Self = .SIMD_LinearInterpolation
    
    public var description: String {
        switch self {
        case .SIMD_LinearInterpolation:
            return "SIMD Linear Interpolation"
        }
    }
}

import PVSettings

extension DSPAudioEngineAlgorithms: Defaults.Serializable {}

public
extension Defaults.Keys {
    /// - Note: Uses the closure `default:` overload so the `swift_once` block never calls
    ///   `UserDefaults.register(defaults:)` — see the rationale on `Defaults.Keys.auEffectsChain`
    ///   in `AUFilters/AUFilterSettings.swift`.
    static let audioEngineDSPAlgorithm =
    Key<DSPAudioEngineAlgorithms>("audioEngineDSPAlgorithm",
                                  default: { DSPAudioEngineAlgorithms.`default` })
}
