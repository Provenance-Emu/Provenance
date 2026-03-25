// Defaults+Recording.swift
// PVSettings
//
// Recording & Streaming preference keys.

import Defaults

// MARK: - Camera Overlay Types

/// Size of the face-cam PIP overlay in screen points.
public enum CameraOverlaySize: String, Codable, Defaults.Serializable, CaseIterable, Sendable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    /// Diameter/side length in points (Double; cast to CGFloat at call site).
    public var points: Double {
        switch self {
        case .small:  return 80
        case .medium: return 120
        case .large:  return 160
        }
    }

    public var displayName: String {
        switch self {
        case .small:  return "Small (80 pt)"
        case .medium: return "Medium (120 pt)"
        case .large:  return "Large (160 pt)"
        }
    }
}

/// Shape mask applied to the camera overlay.
public enum CameraOverlayShape: String, Codable, Defaults.Serializable, CaseIterable, Sendable {
    case circle      = "circle"
    case roundedRect = "roundedRect"

    public var displayName: String {
        switch self {
        case .circle:      return "Circle"
        case .roundedRect: return "Rounded Rectangle"
        }
    }
}

// MARK: Recording & Streaming

public extension Defaults.Keys {
    /// Enable microphone audio capture during screen recording.
    static let recordingMicEnabled = Key<Bool>("recordingMicEnabled", default: false)

    /// Enable camera capture during screen recording (iOS only).
    static let recordingCameraEnabled = Key<Bool>("recordingCameraEnabled", default: false)

    /// Corner position for the camera preview overlay (iOS only).
    static let recordingCameraPosition = Key<CameraPosition>("recordingCameraPosition", default: .bottomRight)

    /// Size of the face-cam overlay. iOS only.
    static let cameraOverlaySize = Key<CameraOverlaySize>("cameraOverlaySize", default: .medium)

    /// Shape mask for the face-cam overlay. iOS only.
    static let cameraOverlayShape = Key<CameraOverlayShape>("cameraOverlayShape", default: .circle)

    /// Automatically save completed recordings to the Photos library.
    static let recordingAutoSave = Key<Bool>("recordingAutoSave", default: true)

    /// Show the recording button in the in-game HUD overlay.
    static let showRecordingOSD = Key<Bool>("showRecordingOSD", default: true)

    /// Default clip duration in seconds for new recording sessions.
    static let recordingClipDuration = Key<Int>("recordingClipDuration", default: 30)

    /// Enable always-on clip buffering (requires ReplayKit permission).
    /// Off by default to avoid prompting for permissions on first launch.
    static let clipBufferingEnabled = Key<Bool>("clipBufferingEnabled", default: false)

    /// Whether the user has already seen (and responded to) the in-app
    /// clip buffering opt-in prompt. Once true, we never show it again.
    static let clipBufferingPermissionAsked = Key<Bool>("clipBufferingPermissionAsked", default: false)
}
