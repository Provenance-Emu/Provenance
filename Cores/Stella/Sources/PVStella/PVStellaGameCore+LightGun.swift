//
//  PVStellaGameCore+LightGun.swift
//  PVStella
//
//  LightGunResponder conformance for the Atari 2600 (Stella) core.
//
//  The 2600's XG-1 / Light Rifle is supported by Stella's libretro core via
//  `Controller::Type::Lightgun` on port 0. The ObjC bridge
//  (`PVStellaBridge+LightGun`) handles ROM detection (MD5 lookup) and the
//  per-frame `input_state_callback` mapping into
//  `RETRO_DEVICE_ID_LIGHTGUN_*`. This Swift extension just forwards the
//  Provenance `LightGunResponder` protocol calls to that bridge.
//
//  Coordinate system: Provenance delivers normalised aim in `[0,1] × [0,1]`
//  (origin top-left). The bridge converts to libretro's centred 16-bit signed
//  screen-space.
//

import Foundation
import CoreGraphics
import PVCoreBridge
import PVLogging
import PVStellaBridge

extension PVStellaGameCore: LightGunResponder {

    /// Reports whether the currently-loaded ROM is a known 2600 light-gun
    /// cart (Sentinel, Shooting Arcade prototypes, etc.). The bridge fills
    /// this in after `loadFileAtPath:` by MD5-matching against the upstream
    /// Stella cartridge database.
    public var gameSupportsLightGun: Bool {
        return (bridge as? PVStellaBridge)?.isStellaLightGunGame ?? false
    }

    /// The XG-1 was never required to play any 2600 cart — every supported
    /// title also accepts joystick input — so never force the on-screen
    /// overlay on the user.
    public var requiresLightGun: Bool { false }

    public func lightGunMovedToPoint(_ point: CGPoint, isOffscreen: Bool) {
        (bridge as? PVStellaBridge)?.setLightGunNormalisedX(point.x, y: point.y, isOffscreen: isOffscreen)
    }

    public func lightGunTriggerDown() {
        (bridge as? PVStellaBridge)?.setLightGunTrigger(true)
    }

    public func lightGunTriggerUp() {
        (bridge as? PVStellaBridge)?.setLightGunTrigger(false)
    }

    // The XG-1 has a single trigger, no aux/start/select buttons. The
    // off-screen reload gesture is handled implicitly by toggling the
    // `isOffscreen` flag on `lightGunMovedToPoint(_:isOffscreen:)` while the
    // trigger is held — see `setLightGunNormalisedX:y:isOffscreen:` in the
    // bridge, which steers a held trigger to `RETRO_DEVICE_ID_LIGHTGUN_RELOAD`
    // when off-screen and to `RETRO_DEVICE_ID_LIGHTGUN_TRIGGER` when on-screen.
}
