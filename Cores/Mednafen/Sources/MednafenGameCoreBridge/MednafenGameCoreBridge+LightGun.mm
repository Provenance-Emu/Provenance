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
//    bytes[0-1] : int16 LE  — X coordinate in PSX screen space (0..319)
//    bytes[2-3] : int16 LE  — Y coordinate in PSX screen space (0..239)
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
    return NO;
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
            int width  = (self->videoWidth  > 0) ? self->videoWidth  : (int)kGunConScreenWidth;
            int height = (self->videoHeight > 0) ? self->videoHeight : (int)kGunConScreenHeight;
            CGFloat cx = MAX(0.0, MIN(1.0, point.x));
            CGFloat cy = MAX(0.0, MIN(1.0, point.y));
            gc_write16(buf, 0, (int16_t)(cx * (width  - 1)));
            gc_write16(buf, 2, (int16_t)(cy * (height - 1)));
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
        uint8_t *buf = (uint8_t *)self->inputBuffer[0];
        buf[4] |= (1 << 3);
        // Also move coordinates off-screen, using a sentinel far outside the visible area.
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
        ((uint8_t *)self->inputBuffer[0])[4] &= ~(1 << 3);
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
