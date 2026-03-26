//
//  LightGunCursorNotification.swift
//  PVCoreBridge
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Defines the `Notification.Name` and `userInfo` key constants for the
//  light-gun cursor-position notification posted by `GCMouseLightGunDriver`.
//

import Foundation

extension Notification.Name {
    /// Posted on the main thread by `GCMouseLightGunDriver` whenever the
    /// light-gun cursor position changes.
    ///
    /// `userInfo` keys: see `LightGunCursorNotification`.
    public static let lightGunCursorDidMove = Notification.Name("PVLightGunCursorDidMove")
}

/// Namespace for the `userInfo` dictionary keys used in `.lightGunCursorDidMove` notifications.
public enum LightGunCursorNotification {
    /// `NSNumber` — normalised X coordinate in [0, 1]. 0 = left edge, 1 = right edge.
    public static let positionXKey = "positionX"
    /// `NSNumber` — normalised Y coordinate in [0, 1]. 0 = top edge, 1 = bottom edge.
    public static let positionYKey = "positionY"
    /// `Bool` — `true` when the gun is pointed off-screen (right-click / reload gesture).
    public static let isOffscreenKey = "isOffscreen"
}
