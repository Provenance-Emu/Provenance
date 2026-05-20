//
//  PVProSystemCoreBridge+LightGun.h
//  PVProSystem
//
//  Created by Provenance EMU on 2026-05-20.
//  Copyright (c) 2026 Provenance EMU. All rights reserved.
//
//  Lightweight ObjC category exposing the bridge state required by the
//  Swift-side `LightGunResponder` conformance.  All work is delegated to
//  the existing mouse-handling code in PVProSystemCoreBridge.mm — this
//  category only exposes accessors + a normalised-coordinate wrapper.
//

#import "PVProSystemCoreBridge.h"

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface PVProSystemGameCore (LightGun)

/// `YES` when the loaded cartridge declares lightgun support in its header
/// (`cartridge_controller[0] & CARTRIDGE_CONTROLLER_LIGHTGUN`) or when its
/// MD5 matches one of the five known commercial 7800 lightgun titles.
@property (nonatomic, readonly) BOOL isLightGunEnabled;

/// Headerless MD5 of the currently loaded cartridge, or `nil` if no cart is
/// loaded.  Used by the Swift wrapper to gate `gameSupportsLightGun` per-game.
@property (nonatomic, readonly, nullable, copy) NSString *cartridgeMD5;

/// Update the lightgun aim using normalised [0, 1] screen coordinates.
/// `isOffscreen == YES` parks the cursor outside the visible playfield so
/// the cycle/scanline match never triggers (used for reload gestures).
- (void)lightGunMoveNormalized:(CGPoint)normalisedPoint isOffscreen:(BOOL)isOffscreen;

/// Trigger press / release.  The 7800 light-gun reads the cartridge "up"
/// direction line (`_inputState[3]`) inverted, mirroring the original mouse
/// path in this bridge.
- (void)lightGunTriggerPressed;
- (void)lightGunTriggerReleased;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
