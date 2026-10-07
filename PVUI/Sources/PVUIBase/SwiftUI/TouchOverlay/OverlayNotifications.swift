//
//  OverlayNotifications.swift
//  PVUIBase
//
//  Notifications between the programmatic touch overlay and the emulator view
//  controller. Both sides live in PVUIBase. Not platform-gated, so the view
//  controller's observers compile on tvOS too.
//

import Foundation
import CoreGraphics

public extension Notification.Name {
    /// Asks the mounted overlay to open its layout editor (pause menu "Edit Layout").
    static let overlayEditLayoutRequested = Notification.Name("PVOverlayEditLayoutRequested")

    /// The overlay's game-screen frames changed (see `OverlayNotificationPayload.frames(from:)`):
    /// one frame, two for DS (top screen first), or none when the overlay goes away. A
    /// non-empty payload therefore also means "the overlay is mounted".
    static let overlayScreenFramesDidChange = Notification.Name("PVOverlayScreenFramesDidChange")

    /// The overlay's layout editor opened or closed (see `OverlayNotificationPayload.editing(from:)`).
    static let overlayEditingDidChange = Notification.Name("PVOverlayEditingDidChange")

    /// Posted by `PVThinLibretroCore` when the core reports new AV info (late geometry). The
    /// constant itself lives in PVCoreBridgeRetro, which PVUI does not depend on.
    static let thinLibretroCoreAVInfoDidUpdate = Notification.Name("PVThinLibretroCoreAVInfoDidUpdate")
}

/// Encodes and decodes the `userInfo` of the overlay notifications.
public enum OverlayNotificationPayload {
    static let framesKey = "frames"
    static let editingKey = "editing"

    public static func userInfo(frames: [CGRect]) -> [AnyHashable: Any] {
        [framesKey: frames.map { NSValue(cgRect: $0) }]
    }

    /// Frames of an `.overlayScreenFramesDidChange` notification; empty when absent.
    public static func frames(from userInfo: [AnyHashable: Any]?) -> [CGRect] {
        (userInfo?[framesKey] as? [NSValue] ?? []).map(\.cgRectValue)
    }

    public static func userInfo(editing: Bool) -> [AnyHashable: Any] {
        [editingKey: editing]
    }

    /// Editing state of an `.overlayEditingDidChange` notification; `nil` when absent.
    public static func editing(from userInfo: [AnyHashable: Any]?) -> Bool? {
        userInfo?[editingKey] as? Bool
    }
}
