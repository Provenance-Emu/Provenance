//
//  PVProSystemGameCore+LightGun.swift
//  PVProSystem
//
//  Created by Provenance EMU on 2026-05-20.
//  Copyright (c) 2026 Provenance EMU. All rights reserved.
//
//  `LightGunResponder` conformance for the Atari 7800 ProSystem core.
//
//  The 7800 supports the XG-1 light gun on a finite, known set of
//  commercial cartridges:
//
//    - Alien Brigade
//    - Crossbow
//    - Sentinel
//    - Barnyard Blaster
//    - Meltdown
//
//  Game detection is delegated to the ObjC bridge (`isLightGunEnabled`)
//  which checks both the cartridge header byte and a hard-coded MD5 set
//  for clean dumps whose header is incorrect.  All coordinate / trigger
//  routing reuses the cycle-accurate scanline path that already powers
//  the bridge's mouse implementation.
//

import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVProSystemBridge

// MARK: - LightGunResponder

extension PVProSystemCore: LightGunResponder {

    /// `true` only when the loaded cartridge is one of the five known
    /// commercial 7800 light-gun titles (Alien Brigade, Crossbow, Sentinel,
    /// Barnyard Blaster, Meltdown) or when its header byte declares
    /// lightgun support.
    public var gameSupportsLightGun: Bool {
        return _bridge.isLightGunEnabled
    }

    /// The 7800 light gun is always optional — every supported title is
    /// also playable (poorly) with the joystick — so we never force the
    /// overlay onto the user.
    public var requiresLightGun: Bool { false }

    public func lightGunMovedToPoint(_ point: CGPoint, isOffscreen: Bool) {
        _bridge.lightGunMoveNormalized(point, isOffscreen: isOffscreen)
    }

    public func lightGunTriggerDown() {
        _bridge.lightGunTriggerPressed()
    }

    public func lightGunTriggerUp() {
        _bridge.lightGunTriggerReleased()
    }

    public func lightGunReloadDown() {
        // Reload = aim offscreen then fire once.  The bridge parks the
        // scanline match outside the visible area in the offscreen branch
        // of `lightGunMoveNormalized:` so the shot registers as a miss
        // (which is how the XG-1 cartridges implement "reload").
        _bridge.lightGunMoveNormalized(.zero, isOffscreen: true)
        _bridge.lightGunTriggerPressed()
    }

    public func lightGunReloadUp() {
        _bridge.lightGunTriggerReleased()
    }
}
