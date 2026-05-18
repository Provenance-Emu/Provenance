//
//  MednafenGameCoreBridge+LightGun.mm
//  PVCoreMednafen
//
//  Implements LightGunResponder for two Mednafen light gun peripherals:
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
    // All other Mednafen subsystems (NES, FDS, SNES, MD/Genesis, SMS, etc.)
    // defer to the cross-core LightGunGameRegistry so Duck Hunt / Hogan's
    // Alley / Yoshi's Safari / Menacer titles surface the touch-lightgun
    // pause-menu tile. Without this, those games would silently fall
    // through to the default NO branch and the user would never see the
    // overlay toggle.
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
    }
}

- (void)lightGunTriggerUp {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].trigger = NO;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] &= ~(1 << 0);
    }
}

#pragma mark - LightGunResponder — auxiliary buttons

- (void)lightGunAuxADown {
    if (self.systemType == MednaSystemPSX) {
        // GunCon "A" button (left side of the barrel).
        ((uint8_t *)self->inputBuffer[0])[4] |= (1 << 1);
    }
    // Saturn gun has no auxiliary A button — no-op.
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
    // Saturn gun has no auxiliary B button — no-op.
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
    }
}

- (void)lightGunReloadUp {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].offscreen = NO;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        ((uint8_t *)self->inputBuffer[0])[4] &= ~((1 << 3) | (1 << 0)); // clear off-screen flag + trigger
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
    }
}

- (void)lightGunStartUp {
    if (self.systemType == MednaSystemSS) {
        const int player = 0;
        ssGunState[player].start = NO;
        flushGunState(self->inputBuffer, player, ssGunState[player]);
    } else if (self.systemType == MednaSystemPSX) {
        [self lightGunAuxAUp];
    }
}

- (void)lightGunSelectDown {
    if (self.systemType == MednaSystemPSX) {
        // GunCon "B" button doubles as select in some games.
        [self lightGunAuxBDown];
    }
    // Saturn gun has no select button — no-op.
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
}

@end
