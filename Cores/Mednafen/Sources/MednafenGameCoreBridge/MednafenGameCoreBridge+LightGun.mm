//
//  MednafenGameCoreBridge+LightGun.mm
//  PVCoreMednafen
//
//  Implements LightGunResponder for the Mednafen light-gun peripherals:
//
//  ── Saturn (MednaSystemSS) ─────────────────────────────────────────────────
//  Supported peripherals:
//    - Sega Virtua Gun  (used by Virtua Cop 1/2, House of the Dead, etc.)
//    - Konami Stunner   (used by Crypt Killer; same serial protocol, same driver)
//
//  The Saturn gun peripheral (IODevice_Gun) accepts a 5-byte input buffer:
//    bytes [0..1]  X coordinate  (int16, little-endian) in Mednafen pointer space
//    bytes [2..3]  Y coordinate  (int16, little-endian) in Mednafen pointer space
//    byte  [4]     button bitfield:
//                    bit 0 = trigger        (1 = pressed)
//                    bit 1 = start          (1 = pressed)
//                    bit 2 = offscreen shot (1 = gun aimed off-screen / reload)
//
//  ── PSX (MednaSystemPSX) ──────────────────────────────────────────────────
//  Supported peripheral:
//    - Namco GunCon (used by Point Blank, Time Crisis, etc.)
//
//  GunCon input buffer layout (5 bytes, stored in inputBuffer[0]):
//    bytes[0-1] : int16 LE  — X axis: 16-bit value scaled to the current visible area width
//                             (roughly 0..videoWidth-1 + videoOffsetX; INT16_MIN = off-screen)
//    bytes[2-3] : int16 LE  — Y axis: 16-bit value scaled to the current visible area height
//                             (roughly 0..videoHeight-1 + videoOffsetY; INT16_MIN = off-screen)
//    byte[4]    : button bitmask
//                   bit 0 — trigger (primary fire)
//                   bit 1 — button A  (left side button)
//                   bit 2 — button B  (back button)
//                   bit 3 — off-screen shot (simulated; forces a "miss")
//
//  ── NES / FDS (MednaSystemNES) ────────────────────────────────────────────
//  Supported peripheral:
//    - Nintendo Zapper (Duck Hunt, Hogan's Alley, Wild Gunman, etc.)
//
//  Zapper input buffer layout (5 bytes, written into inputBuffer[1] — the
//  Zapper plugs into the player-2 controller port on real hardware):
//    bytes[0-1] : int16 LE — X in NES pixel space (0..255, off-screen = far OOB)
//    bytes[2-3] : int16 LE — Y in NES pixel space (0..239)
//    byte[4]    : button bitmask
//                   bit 0 — trigger
//                   bit 1 — "away trigger" / off-screen shot (forces miss)
//  Source: mednafen/src/nes/input/zapper.cpp `UpdateZapper`.
//
//  ── SNES (MednaSystemSNES, legacy `snes` module only) ────────────────────
//  Supported peripheral:
//    - Nintendo Super Scope (Yoshi's Safari, Battle Clash, X-Zone, etc.)
//
//  Super Scope buffer layout (5 bytes, written into inputBuffer[1]):
//    bytes[0-1] : int16 LE — X in SNES pixel space, clamped by core to [-16, 272]
//    bytes[2-3] : int16 LE — Y in SNES pixel space, clamped by core to [-16, 256]
//    byte[4]    : button bitmask
//                   bit 0 — trigger
//                   bit 1 — offscreen_shot (simulated forced miss)
//                   bit 2 — pause
//                   bit 3 — turbo
//                   bit 4 — cursor
//  Source: mednafen/src/snes/interface.cpp + snes/src/system/input/input.cpp.
//
//  The Mednafen Super Scope driver is only present in the legacy `snes`
//  module (bSNES-derived). `snes_faust` has no Super Scope, so the bridge
//  refuses to advertise gun support when `snes_faust` is the active module.
//
//  ── Genesis / SMS — NOT SUPPORTED ─────────────────────────────────────────
//  Mednafen 1.x has no Menacer (Genesis) or Light Phaser (SMS) driver
//  upstream — only `gamepad`, `megamouse`, `multitap`, `4way` exist for MD,
//  and SMS only exposes a fixed gamepad pio. We therefore decline to
//  advertise gun support for those subsystems even when the cross-core
//  registry says the game uses a light gun.
//

#import "MednafenGameCoreBridge.h"
@import PVLoggingObjC;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import mednafen;
@import MednafenGameCoreOptions;

// -------------------------------------------------------------------------
// Saturn: Per-player light gun state
// -------------------------------------------------------------------------
// We use file-scoped static state because ObjC categories cannot add stored
// properties, and only one emulator session runs at a time.

static struct SSGunState {
    CGFloat normX;        // normalised aim X [0.0, 1.0]
    CGFloat normY;        // normalised aim Y [0.0, 1.0]
    BOOL    trigger;      // trigger held
    BOOL    start;        // start button held
    BOOL    offscreen;    // aim explicitly off-screen (reload gesture)
} ssGunState[2] = {
    // Default aim position to screen centre so a trigger press before any
    // lightGunMovedToPoint event targets the middle of the screen rather than
    // the top-left corner (which would be (0,0) zero-initialisation).
    {0.5, 0.5, NO, NO, NO},
    {0.5, 0.5, NO, NO, NO},
};

// -------------------------------------------------------------------------
// Saturn: Helper — write the current per-player state into inputBuffer[player]
// -------------------------------------------------------------------------
static void flushGunState(uint32_t **inputBuffer, int player, const SSGunState &s) {
    uint8_t *buf = (uint8_t *)inputBuffer[player];

    // Convert normalised coordinates to Mednafen pointer space.
    // MDFNGameInfo->mouse_scale_x/y and mouse_offs_x/y are set per-frame by
    // the Saturn VDP2 renderer (vdp2_render.cpp) so these values are always current.
    const float scaleX = Mednafen::MDFNGameInfo ? Mednafen::MDFNGameInfo->mouse_scale_x : 21472.0f;
    const float offsX  = Mednafen::MDFNGameInfo ? Mednafen::MDFNGameInfo->mouse_offs_x  : 0.0f;
    const float scaleY = Mednafen::MDFNGameInfo ? Mednafen::MDFNGameInfo->mouse_scale_y : 224.0f;
    const float offsY  = Mednafen::MDFNGameInfo ? Mednafen::MDFNGameInfo->mouse_offs_y  : 16.0f;

    const float rawX = (float)s.normX * scaleX + offsX;
    const float rawY = (float)s.normY * scaleY + offsY;

    const int16_t ix = (int16_t)std::max(-32768.0f, std::min(32767.0f, std::floor(0.5f + rawX)));
    const int16_t iy = (int16_t)std::max(-32768.0f, std::min(32767.0f, std::floor(0.5f + rawY)));

    Mednafen::MDFN_en16lsb(&buf[0], (uint16_t)ix);
    Mednafen::MDFN_en16lsb(&buf[2], (uint16_t)iy);

    // Build button byte.
    uint8_t buttons = 0;
    if (s.trigger)   buttons |= 0x01;  // bit 0: trigger
    if (s.start)     buttons |= 0x02;  // bit 1: start
    if (s.offscreen) buttons |= 0x04;  // bit 2: offscreen shot
    buf[4] = buttons;
}

// -------------------------------------------------------------------------
// PSX: Default GunCon screen dimensions for coordinate mapping.
// -------------------------------------------------------------------------
static const int16_t kGunConScreenWidth  = 320;
static const int16_t kGunConScreenHeight = 240;

// PSX: Convenience — write little-endian 16-bit into a uint8_t buffer.
static inline void gc_write16(uint8_t *buf, int offset, int16_t value) {
    Mednafen::MDFN_en16lsb(buf + offset, (uint16_t)value);
}

// -------------------------------------------------------------------------
// NES Zapper / SNES Super Scope: native (raw pixel space) screen extents.
// These are the values upstream uses for hit detection and clamping; we map
// normalised touch input directly into this space so the on-screen reticle
// from the touch overlay matches what the emulator sees.
// -------------------------------------------------------------------------
static const int16_t kNESZapperWidth   = 256;  // NES PPU active scanline width
static const int16_t kNESZapperHeight  = 240;  // NES PPU active scanline count
static const int16_t kSNESScopeWidth   = 256;  // SNES H-resolution (Mode 0/1/3 active)
static const int16_t kSNESScopeHeight  = 224;  // NTSC active height; PAL is 240

// NES Zapper button bits (see input/zapper.cpp `UpdateZapper`).
static const uint8_t kNESZapperBitTrigger    = (1 << 0);
static const uint8_t kNESZapperBitOffscreen  = (1 << 1); // "away_trigger" forces a miss

// SNES Super Scope button bits (see snes/interface.cpp `SuperScopeIDII`).
static const uint8_t kSNESScopeBitTrigger    = (1 << 0);
static const uint8_t kSNESScopeBitOffscreen  = (1 << 1);
static const uint8_t kSNESScopeBitPause      = (1 << 2);
// NOLINTNEXTLINE -- kept for future surfacing of turbo/cursor through the
// LightGunResponder protocol (currently no protocol method maps to them).
static const uint8_t kSNESScopeBitTurbo      __attribute__((unused)) = (1 << 3);
static const uint8_t kSNESScopeBitCursor     __attribute__((unused)) = (1 << 4);

// -------------------------------------------------------------------------
// LightGunResponder implementation — dispatches on self.systemType
// -------------------------------------------------------------------------

@implementation MednafenGameCoreBridge (LightGun)

#pragma mark - LightGunResponder — capability

- (BOOL)gameSupportsLightGun {
    // Saturn + PSX: use the curated Mednafen-side lookup tables. These are
    // tighter than the cross-core LightGunGameRegistry (serial-keyed for
    // PSX, per-game player-count for Saturn) and feed downstream wiring
    // (`_isLightGunGame`, `_lightGunPlayerCount`).
    if (self.systemType == MednaSystemSS) {
        return self->_isLightGunGame;
    }
    if (self.systemType == MednaSystemPSX) {
        NSString *serial = self.romSerial;
        if (!serial) {
            return NO;
        }
        return [MednafenGameCoreOptions psxLightGunGames][serial] != nil;
    }

    // Mednafen has no Menacer (Genesis) or Light Phaser (SMS) device upstream
    // in this version, so refuse to advertise gun support for those subsystems
    // even when the cross-core registry knows about the ROM. Showing the
    // pause-menu tile without a working backend would be a worse UX than
    // hiding it entirely.
    if (self.systemType == MednaSystemMD || self.systemType == MednaSystemSMS) {
        return NO;
    }

    // SNES Super Scope is only implemented by the legacy `snes` module
    // (bSNES-derived). When the user has the "Fast SNES" option enabled the
    // active module is `snes_faust`, which has no Super Scope — decline.
    if (self.systemType == MednaSystemSNES &&
        [self->mednafenCoreModule isEqualToString:@"snes_faust"]) {
        return NO;
    }

    // NES / FDS / SNES (legacy module): defer to the cross-core
    // LightGunGameRegistry so Duck Hunt / Hogan's Alley / Yoshi's Safari /
    // Super Scope 6 titles surface the touch-lightgun pause-menu tile.
    NSString *sysID = [self valueForKey:@"systemIdentifier"];
    if (sysID.length == 0) { return NO; }
    NSString *md5 = [self valueForKey:@"romMD5"];
    NSString *title = self->romName;
    return [PVLightGunGameRegistry gameSupportsLightGunForSystemIdentifier:sysID
                                                                       md5:md5
                                                                     title:title];
}

- (BOOL)requiresLightGun {
    return NO;
}

#pragma mark - LightGunResponder — position

// NES Zapper / SNES Super Scope: shared helper to write XY into inputBuffer[1].
// `extW`/`extH` are the device's native screen extents in raw pixels.
- (void)mdfn_writeGunXYToPort1:(CGPoint)point
                    isOffscreen:(BOOL)isOffscreen
                          width:(int16_t)extW
                         height:(int16_t)extH
                  offscreenMask:(uint8_t)offMask {
    uint8_t *buf = (uint8_t *)self->inputBuffer[1];
    if (isOffscreen) {
        // Sentinel: place far outside the visible area; assert the per-device
        // off-screen bit so the emulator skips hit-detection on this frame.
        gc_write16(buf, 0, INT16_MIN);
        gc_write16(buf, 2, INT16_MIN);
        buf[4] |= offMask;
    } else {
        const CGFloat cx = MAX(0.0, MIN(1.0, point.x));
        const CGFloat cy = MAX(0.0, MIN(1.0, point.y));
        const int16_t px = (int16_t)(cx * (extW - 1));
        const int16_t py = (int16_t)(cy * (extH - 1));
        gc_write16(buf, 0, px);
        gc_write16(buf, 2, py);
        buf[4] &= ~offMask;
    }
}

// Position update — called every frame with current aim normalised to [0,1].
- (void)lightGunMovedToPoint:(CGPoint)point isOffscreen:(BOOL)isOffscreen {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        // Clamp defensively to [0,1].
        ssGunState[player].normX     = fmin(fmax(point.x, 0.0), 1.0);
        ssGunState[player].normY     = fmin(fmax(point.y, 0.0), 1.0);
        ssGunState[player].offscreen = isOffscreen;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        uint8_t *buf = (uint8_t *)self->inputBuffer[0];
        if (isOffscreen) {
            // Write a sentinel far outside the visible area so the GunCon misses.
            gc_write16(buf, 0, INT16_MIN);
            gc_write16(buf, 2, INT16_MIN);
            buf[4] |= (1 << 3);
        } else {
            // Map normalized (0,1) → Mednafen internal coordinates.
            // Mednafen applies per-frame video offsets (visible scanline start) to GunCon hits,
            // so we add videoOffsetX/Y to keep the mapped position inside the visible area.
            int width  = (self->videoWidth  > 0) ? self->videoWidth  : (int)kGunConScreenWidth;
            int height = (self->videoHeight > 0) ? self->videoHeight : (int)kGunConScreenHeight;
            CGFloat cx = MAX(0.0, MIN(1.0, point.x));
            CGFloat cy = MAX(0.0, MIN(1.0, point.y));
            int16_t px = (int16_t)(cx * (width  - 1)) + (int16_t)self->videoOffsetX;
            int16_t py = (int16_t)(cy * (height - 1)) + (int16_t)self->videoOffsetY;
            gc_write16(buf, 0, px);
            gc_write16(buf, 2, py);
            buf[4] &= ~(1 << 3); // clear off-screen bit when on-screen
        }
    } else if (self.systemType == MednaSystemNES) {
        [self mdfn_writeGunXYToPort1:point
                          isOffscreen:isOffscreen
                                width:kNESZapperWidth
                               height:kNESZapperHeight
                        offscreenMask:kNESZapperBitOffscreen];
    } else if (self.systemType == MednaSystemSNES) {
        [self mdfn_writeGunXYToPort1:point
                          isOffscreen:isOffscreen
                                width:kSNESScopeWidth
                               height:kSNESScopeHeight
                        offscreenMask:kSNESScopeBitOffscreen];
    }
}

#pragma mark - LightGunResponder — trigger

- (void)lightGunTriggerDown {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].trigger = YES;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] |= (1 << 0);
    } else if (self.systemType == MednaSystemNES) {
        ((uint8_t *)self->inputBuffer[1])[4] |= kNESZapperBitTrigger;
    } else if (self.systemType == MednaSystemSNES) {
        ((uint8_t *)self->inputBuffer[1])[4] |= kSNESScopeBitTrigger;
    }
}

- (void)lightGunTriggerUp {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].trigger = NO;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] &= ~(1 << 0);
    } else if (self.systemType == MednaSystemNES) {
        ((uint8_t *)self->inputBuffer[1])[4] &= ~kNESZapperBitTrigger;
    } else if (self.systemType == MednaSystemSNES) {
        ((uint8_t *)self->inputBuffer[1])[4] &= ~kSNESScopeBitTrigger;
    }
}

#pragma mark - LightGunResponder — auxiliary buttons

- (void)lightGunAuxADown {
    if (self.systemType == MednaSystemPSX) {
        // GunCon "A" button (left side of the barrel).
        ((uint8_t *)self->inputBuffer[0])[4] |= (1 << 1);
    }
    // Saturn gun / NES Zapper / SNES Super Scope have no auxiliary A button — no-op.
}

- (void)lightGunAuxAUp {
    if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] &= ~(1 << 1);
    }
}

- (void)lightGunAuxBDown {
    if (self.systemType == MednaSystemPSX) {
        // GunCon "B" button (back of the gun).
        ((uint8_t *)self->inputBuffer[0])[4] |= (1 << 2);
    }
    // Saturn gun / NES Zapper / SNES Super Scope have no auxiliary B button — no-op.
}

- (void)lightGunAuxBUp {
    if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] &= ~(1 << 2);
    }
}

#pragma mark - LightGunResponder — reload / off-screen

// Setting the offscreen bit causes Mednafen's IODevice_Gun::UpdateInput() to
// activate its 250 ms off-screen timer (osshot_counter) on Saturn, simulating
// the real-world trick of firing at the ceiling to reload.
- (void)lightGunReloadDown {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].offscreen = YES;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        // Per the LightGunResponder contract, an off-screen reload requires both:
        //   • the off-screen bit (bit 3) so Mednafen skips hit-detection, and
        //   • the trigger bit  (bit 0) so the game registers an actual shot event.
        uint8_t *buf = (uint8_t *)self->inputBuffer[0];
        buf[4] |= (1 << 3) | (1 << 0); // off-screen flag + trigger press
        // Move coordinates far outside the visible area (unambiguous sentinel).
        gc_write16(buf, 0, INT16_MIN);
        gc_write16(buf, 2, INT16_MIN);
    } else if (self.systemType == MednaSystemNES) {
        // NES Zapper reload: away-trigger bit + trigger press (so the game
        // registers the shot but it's guaranteed to miss).
        uint8_t *buf = (uint8_t *)self->inputBuffer[1];
        gc_write16(buf, 0, INT16_MIN);
        gc_write16(buf, 2, INT16_MIN);
        buf[4] |= kNESZapperBitOffscreen | kNESZapperBitTrigger;
    } else if (self.systemType == MednaSystemSNES) {
        // SNES Super Scope reload: offscreen_shot bit + trigger press.
        uint8_t *buf = (uint8_t *)self->inputBuffer[1];
        gc_write16(buf, 0, INT16_MIN);
        gc_write16(buf, 2, INT16_MIN);
        buf[4] |= kSNESScopeBitOffscreen | kSNESScopeBitTrigger;
    }
}

- (void)lightGunReloadUp {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].offscreen = NO;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] &= ~((1 << 3) | (1 << 0)); // clear off-screen flag + trigger
    } else if (self.systemType == MednaSystemNES) {
        ((uint8_t *)self->inputBuffer[1])[4] &= ~(kNESZapperBitOffscreen | kNESZapperBitTrigger);
    } else if (self.systemType == MednaSystemSNES) {
        ((uint8_t *)self->inputBuffer[1])[4] &= ~(kSNESScopeBitOffscreen | kSNESScopeBitTrigger);
    }
}

#pragma mark - LightGunResponder — start button

- (void)lightGunStartDown {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].start = YES;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        // GunCon "A" button doubles as start/confirm in some games.
        [self lightGunAuxADown];
    } else if (self.systemType == MednaSystemSNES) {
        // Super Scope has its own Pause button — map Start to it.
        ((uint8_t *)self->inputBuffer[1])[4] |= kSNESScopeBitPause;
    }
    // NES Zapper has no Start button — no-op.
}

- (void)lightGunStartUp {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].start = NO;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        [self lightGunAuxAUp];
    } else if (self.systemType == MednaSystemSNES) {
        ((uint8_t *)self->inputBuffer[1])[4] &= ~kSNESScopeBitPause;
    }
}

- (void)lightGunSelectDown {
    if (self.systemType == MednaSystemPSX) {
        // GunCon "B" button doubles as select in some games.
        [self lightGunAuxBDown];
    }
    // Saturn gun / NES Zapper / SNES Super Scope have no select button — no-op.
}

- (void)lightGunSelectUp {
    if (self.systemType == MednaSystemPSX) {
        [self lightGunAuxBUp];
    }
}

#pragma mark - Session lifecycle

// Called at game load and stop to prevent stale state from leaking across
// emulator sessions (e.g. trigger held at session end).
- (void)resetLightGunState {
    ssGunState[0] = {0.5, 0.5, NO, NO, NO};
    ssGunState[1] = {0.5, 0.5, NO, NO, NO};
    // NES Zapper / SNES Super Scope live on port 1. Centre the cursor and
    // clear all button bits so a stale trigger/pause from a previous session
    // cannot bleed into a fresh boot.
    if (self.systemType == MednaSystemNES || self.systemType == MednaSystemSNES) {
        uint8_t *buf = (uint8_t *)self->inputBuffer[1];
        const int16_t cx = (self.systemType == MednaSystemNES ? kNESZapperWidth  : kSNESScopeWidth ) / 2;
        const int16_t cy = (self.systemType == MednaSystemNES ? kNESZapperHeight : kSNESScopeHeight) / 2;
        gc_write16(buf, 0, cx);
        gc_write16(buf, 2, cy);
        buf[4] = 0;
    }
}

@end
