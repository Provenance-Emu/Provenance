//
//  DualSenseMicButtonAction.swift
//  PVSettings
//
//  What the DualSense microphone button does during gameplay.
//

import Defaults

/// Stored as its raw value, the same strings the key held when it was a plain `String`.
public enum DualSenseMicButtonAction: String, CaseIterable, Defaults.Serializable, Sendable {
    case muteAudio
    /// Not `none`: a `.none` case reads as `Optional.none` wherever the value is optional.
    case doNothing = "none"

    public var displayName: String {
        switch self {
        case .muteAudio: return "Mute Audio"
        case .doNothing: return "None"
        }
    }
}
