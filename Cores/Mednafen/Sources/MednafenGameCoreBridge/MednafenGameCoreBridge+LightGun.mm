//
//  MednafenGameCoreBridge+LightGun.mm
//  PVCoreMednafen
//
//  Implements LightGunResponder for the Mednafen Saturn core.
//
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
//  The X/Y coordinates must be written in the "pre-TransformInput" space, which
//  is identical to the range the Mednafen driver uses for IDIT_POINTER_X/Y:
//    X = normalised_x * MDFNGameInfo->mouse_scale_x + MDFNGameInfo->mouse_offs_x
//    Y = normalised_y * MDFNGameInfo->mouse_scale_y + MDFNGameInfo->mouse_offs_y
//
//  For Saturn NTSC (typical game):
//    mouse_scale_x ≈ 21472  (sub-pixel horizontal clock units across full screen)
//    mouse_offs_x  ≈ 0
//    mouse_scale_y ≈ 224    (visible scanlines)
//    mouse_offs_y  ≈ 16     (first visible scanline — LineVisFirst)
//
//  Mednafen's SMPC_TransformInput() then converts the clock-unit X value to the
//  real hardware-timing value before UpdateInput() uses it for light detection.
//

#import "MednafenGameCoreBridge.h"
@import PVLoggingObjC;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import mednafen;
@import MednafenGameCoreOptions;

// -------------------------------------------------------------------------
// Per-player light gun state
// -------------------------------------------------------------------------
// We use file-scoped static state because ObjC categories cannot add stored
// properties, and only one emulator session runs at a time.

static struct SSGunState {
    CGFloat normX;        // normalised aim X [0.0, 1.0]
    CGFloat normY;        // normalised aim Y [0.0, 1.0]
    BOOL    trigger;      // trigger held
    BOOL    start;        // start button held
    BOOL    offscreen;    // aim explicitly off-screen (reload gesture)
} ssGunState[2];

// -------------------------------------------------------------------------
// Helper: write the current per-player state into inputBuffer[player]
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
// LightGunResponder implementation
// -------------------------------------------------------------------------

@implementation MednafenGameCoreBridge (LightGun)

- (BOOL)gameSupportsLightGun {
    return self->_isLightGunGame;
}

- (BOOL)requiresLightGun {
    return self->_isLightGunGame;
}

// -------------------------------------------------------------------------
// Position update — called every frame with current aim normalised to [0,1].
// Player 0 (port 0) is the primary gun; player 1 (port 1) is the second gun.
// The LightGunResponder protocol has no player index so we always route to
// player 0.  Dual-gun support can be extended by adding a second responder
// or a player-index variant in the future.
// -------------------------------------------------------------------------
- (void)lightGunMovedToPoint:(CGPoint)point isOffscreen:(BOOL)isOffscreen {
    const int player = 0;
    ssGunState[player].normX      = point.x;
    ssGunState[player].normY      = point.y;
    ssGunState[player].offscreen  = isOffscreen;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

// -------------------------------------------------------------------------
// Trigger
// -------------------------------------------------------------------------
- (void)lightGunTriggerDown {
    const int player = 0;
    ssGunState[player].trigger = YES;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

- (void)lightGunTriggerUp {
    const int player = 0;
    ssGunState[player].trigger = NO;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

// -------------------------------------------------------------------------
// Start button (maps to gun "START" button in IDII)
// -------------------------------------------------------------------------
- (void)lightGunStartDown {
    const int player = 0;
    ssGunState[player].start = YES;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

- (void)lightGunStartUp {
    const int player = 0;
    ssGunState[player].start = NO;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

// -------------------------------------------------------------------------
// Reload / off-screen shot
// Setting the offscreen bit causes Mednafen's IODevice_Gun::UpdateInput() to
// activate its 250 ms off-screen timer (osshot_counter), which simulates the
// real-world trick of firing at the ceiling to reload.
// -------------------------------------------------------------------------
- (void)lightGunReloadDown {
    const int player = 0;
    ssGunState[player].offscreen = YES;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

- (void)lightGunReloadUp {
    const int player = 0;
    ssGunState[player].offscreen = NO;
    flushGunState(self->inputBuffer, player, ssGunState[player]);
}

// -------------------------------------------------------------------------
// Aux buttons (not used by standard Saturn gun peripherals)
// -------------------------------------------------------------------------
- (void)lightGunAuxADown  { /* no-op: Saturn gun has no auxiliary A button */ }
- (void)lightGunAuxAUp    { /* no-op */ }
- (void)lightGunAuxBDown  { /* no-op */ }
- (void)lightGunAuxBUp    { /* no-op */ }
- (void)lightGunSelectDown{ /* no-op */ }
- (void)lightGunSelectUp  { /* no-op */ }

@end
