//
//  OverlayNotifications.swift
//  PVUIBase
//
//  Notifications between the programmatic touch overlay and the emulator view
//  controller. Both sides live in PVUIBase. Not platform-gated, so the view
//  controller's observer compiles on tvOS too.
//

import Foundation

public extension Notification.Name {
    /// Asks the mounted overlay to open its layout editor (pause menu "Edit Layout").
    static let overlayEditLayoutRequested = Notification.Name("PVOverlayEditLayoutRequested")

    /// The overlay's game-screen frames changed. `userInfo[OverlayScreenFramesKey.frames]`
    /// holds `[NSValue]` (CGRect, view coordinates): one frame, two for DS (top screen
    /// first), or none when the overlay goes away.
    static let overlayScreenFramesDidChange = Notification.Name("PVOverlayScreenFramesDidChange")
}

public enum OverlayScreenFramesKey {
    /// `userInfo` key of `.overlayScreenFramesDidChange`.
    public static let frames = "frames"
}
