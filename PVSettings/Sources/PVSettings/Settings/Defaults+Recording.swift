// Defaults+Recording.swift
// PVSettings
//
// Recording & Streaming preference keys.

import Defaults

// MARK: Recording & Streaming

public extension Defaults.Keys {
    /// Enable microphone audio capture during screen recording.
    static let recordingMicEnabled = Key<Bool>("recordingMicEnabled", default: false)

    /// Enable camera capture during screen recording (iOS only).
    static let recordingCameraEnabled = Key<Bool>("recordingCameraEnabled", default: false)

    /// Automatically save completed recordings to the Photos library.
    static let recordingAutoSave = Key<Bool>("recordingAutoSave", default: true)

    /// Show the recording button in the in-game HUD overlay.
    static let showRecordingOSD = Key<Bool>("showRecordingOSD", default: true)

    /// Default clip duration in seconds for new recording sessions.
    static let recordingClipDuration = Key<Int>("recordingClipDuration", default: 30)

    /// Enable always-on clip buffering (requires ReplayKit permission).
    /// Off by default to avoid prompting for permissions on first launch.
    static let clipBufferingEnabled = Key<Bool>("clipBufferingEnabled", default: false)
}
