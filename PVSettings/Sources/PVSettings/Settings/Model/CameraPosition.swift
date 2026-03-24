// CameraPosition.swift
// PVSettings
//
// Camera overlay position for screen recording face-cam.

import Foundation
import Defaults

/// Position of the camera preview overlay during screen recording.
///
/// Maps to the four corners of the screen. The default is `.bottomRight`
/// which is the conventional position for face-cam overlays.
public enum CameraPosition: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    case topLeft     = "topLeft"
    case topRight    = "topRight"
    case bottomLeft  = "bottomLeft"
    case bottomRight = "bottomRight"

    public var displayName: String {
        switch self {
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }

    public var symbolName: String {
        switch self {
        case .topLeft:     return "arrow.up.left.square"
        case .topRight:    return "arrow.up.right.square"
        case .bottomLeft:  return "arrow.down.left.square"
        case .bottomRight: return "arrow.down.right.square"
        }
    }
}
