//
//  PVProSystemCoreBridge+LightGun.mm
//  PVProSystem
//
//  Created by Provenance EMU on 2026-05-20.
//  Copyright (c) 2026 Provenance EMU. All rights reserved.
//
//  ObjC++ category that exposes the bridge's existing lightgun plumbing
//  (cycle/scanline aim, trigger toggling on _inputState[3]) to the Swift
//  `LightGunResponder` extension on `PVProSystemCore`.
//
//  The five commercial Atari 7800 lightgun titles are a finite, known set.
//  Their headerless MD5s are hard-coded here so we can advertise lightgun
//  support even when a dumped cart's header byte is wrong or zero.
//

#import "PVProSystemCoreBridge.h"
#import "PVProSystemCoreBridge+LightGun.h"

@import libprosystem;

#include <string>

// Forward-declare the selectors implemented as an anonymous category in
// PVProSystemCoreBridge.mm so the compiler stops warning.  Dispatch is
// dynamic so the actual implementation always resolves at runtime.
@interface PVProSystemGameCore (PVProSystemMouseForwardDecl)
- (void)mouseMovedAtPoint:(CGPoint)point;
- (void)leftMouseDownAtPoint:(CGPoint)point;
- (void)leftMouseUp;
@end

// MARK: - Known lightgun titles (headerless MD5, lowercase hex)
//
// 7800 supports the XG-1 light gun on five commercial cartridges.  Crossbow,
// Sentinel and Alien Brigade ship with the gun enabled in the header byte;
// Barnyard Blaster and Meltdown sometimes do not, depending on the dump.
// Matching by MD5 here guarantees `gameSupportsLightGun` returns YES for
// every clean dump regardless of header quality.
//
// Sources: Atari Age cart database, ProSystem.dat shipped with this core.

static NSSet<NSString *> *PVProSystemLightGunMD5Set(void) {
    static NSSet<NSString *> *sSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSet = [NSSet setWithArray:@[
            // Alien Brigade (NTSC)
            @"e51030251e440cffaab1ac63438b44ae",
            // Crossbow (NTSC)
            @"4ae8c76cd6f24a2e181ae874d4d2aa3d",
            // Sentinel (NTSC)
            @"57fe6c84efa6abdb0c80d50d127feddd",
            // Barnyard Blaster (NTSC)
            @"f5dc7dc8e38072d3d65bd90a660148ce",
            // Meltdown (NTSC)
            @"f1ae6305fa33a948e36deb0ef12af852",
        ]];
    });
    return sSet;
}

// MARK: - Thread safety
//
// Lightgun input arrives on the main thread (touch / GCMouse / GCPointer)
// while `executeFrame` runs `prosystem_ExecuteFrame` on the emulation queue.
// `lightgun_scanline`/`lightgun_cycle` are `int`/`float` writes — naturally
// atomic on ARM64 — and the existing mouse path in PVProSystemCoreBridge.mm
// is unlocked; we follow that convention here to avoid a behaviour change.

@implementation PVProSystemGameCore (LightGun)

// MARK: - Accessors

- (BOOL)isLightGunEnabled {
    // The instance variable `_isLightgunEnabled` is set in `loadFileAtPath:`
    // based on `cartridge_controller[0] & CARTRIDGE_CONTROLLER_LIGHTGUN`.
    // Categories cannot access ivars directly, so we re-read the upstream
    // state and OR in the known-title MD5 check.
    BOOL cartFlag = (cartridge_controller[0] & CARTRIDGE_CONTROLLER_LIGHTGUN) != 0;
    if (cartFlag) { return YES; }

    NSString *md5 = self.cartridgeMD5;
    if (md5 == nil) { return NO; }
    return [PVProSystemLightGunMD5Set() containsObject:md5];
}

- (NSString *)cartridgeMD5 {
    if (cartridge_digest.empty()) { return nil; }
    return [[NSString stringWithUTF8String:cartridge_digest.c_str()] lowercaseString];
}

// MARK: - Last-known aim
//
// We delegate to the bridge's existing `mouseMovedAtPoint:` / `leftMouseDownAtPoint:`
// selectors which expect *pixel-space* coordinates within the visible area.
// The most recent pixel-space point is cached so the trigger handler can
// re-apply it without the caller having to bundle aim + trigger together.

static CGPoint sLastAimPixel = CGPointZero;
static BOOL    sLastAimValid = NO;

// MARK: - Aim

- (void)lightGunMoveNormalized:(CGPoint)normalisedPoint isOffscreen:(BOOL)isOffscreen {
    if (!self.isLightGunEnabled) { return; }

    if (isOffscreen) {
        // Park the scanline match well past the last visible line so the
        // detector in prosystem.cpp never fires.  Any value above 312 (PAL
        // total scanlines) is sufficient.
        lightgun_scanline = 0x7FFF;
        lightgun_cycle    = 0;
        sLastAimValid = NO;
        return;
    }

    int videoWidth  = maria_visibleArea.GetLength();
    int videoHeight = maria_visibleArea.GetHeight();
    if (videoWidth <= 0 || videoHeight <= 0) { return; }

    // Clamp normalised coordinates to [0, 1] then convert to pixel space.
    CGFloat nx = MAX((CGFloat)0.0, MIN((CGFloat)1.0, normalisedPoint.x));
    CGFloat ny = MAX((CGFloat)0.0, MIN((CGFloat)1.0, normalisedPoint.y));
    CGPoint pixelPoint = CGPointMake(nx * (CGFloat)(videoWidth  - 1),
                                     ny * (CGFloat)(videoHeight - 1));

    sLastAimPixel = pixelPoint;
    sLastAimValid = YES;

    // Forward to the existing bridge implementation which performs the
    // cycle/scanline calculation against the current cartridge region.
    [self mouseMovedAtPoint:pixelPoint];
}

// MARK: - Trigger
//
// On the 7800, the light-gun trigger is wired to the joystick "up" line.
// The bridge's `loadFileAtPath:` sets `_inputState[3] = 1` when lightgun is
// enabled (idle = high); pressing the trigger drives it low via
// `leftMouseDownAtPoint:`, and `leftMouseUp` restores the idle state.

- (void)lightGunTriggerPressed {
    if (!self.isLightGunEnabled) { return; }
    CGPoint aim = sLastAimValid ? sLastAimPixel : CGPointZero;
    [self leftMouseDownAtPoint:aim];
}

- (void)lightGunTriggerReleased {
    if (!self.isLightGunEnabled) { return; }
    [self leftMouseUp];
}

@end
