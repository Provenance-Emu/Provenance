//
//  PVCoreGenesisPlusBridge+LightGun.m
//  Provenance
//
//  Created by Provenance EMU on 2026-03-25.
//  Copyright (c) 2026 Provenance EMU. All rights reserved.
//
//  Implements LightGunResponder for Genesis Plus GX:
//    - Sega Menacer  (Genesis/MD port B, 6-button)
//    - Konami Justifiers (Genesis/MD port B, 2-gun)
//    - Sega Light Phaser (Master System port A or B)
//

#import "PVCoreGenesisPlusBridge.h"
@import PVCoreBridge;
@import PVLoggingObjC;

// ── Genesis Plus GX types ────────────────────────────────────────────────────
// Forward-declare only what this category needs so we don't pull in the entire
// (platform-specific) Genesis Plus GX header tree.

typedef unsigned char  uint8_gp;
typedef unsigned short uint16_gp;
typedef signed short   int16_gp;

#define MAX_DEVICES_GP  (8)

typedef struct {
    uint8_gp  system[2];                  /* SYSTEM_* port types           */
    uint8_gp  dev[MAX_DEVICES_GP];        /* DEVICE_* per-device types     */
    uint16_gp pad[MAX_DEVICES_GP];        /* digital button bits (INPUT_*) */
    int16_gp  analog[MAX_DEVICES_GP][2];  /* analog[port][0]=X, [1]=Y      */
    int       x_offset;
    int       y_offset;
} t_input_gp;

typedef struct {
    uint8_gp *data;
    int       width;
    int       height;
    int       pitch;
    struct {
        int x, y, w, h;
        int ow, oh;
        int changed;
    } viewport;
} t_bitmap_gp;

extern t_input_gp  input;
extern t_bitmap_gp bitmap;

// ── System type constants (mirror input.h) ───────────────────────────────────
#define SYSTEM_MENACER_GP      (3)
#define SYSTEM_JUSTIFIER_GP    (4)
#define SYSTEM_LIGHTPHASER_GP  (7)

// ── Input button bitmasks (mirror input.h) ───────────────────────────────────
#define INPUT_START_GP   (0x0080)
#define INPUT_A_GP       (0x0040)   /* primary fire / trigger */
#define INPUT_C_GP       (0x0020)   /* Menacer top button     */
#define INPUT_B_GP       (0x0010)   /* Menacer side button    */

// ── Port indices ─────────────────────────────────────────────────────────────
static const int kPortA = 0;   /* SMS/GG port A → analog[0] */
static const int kPortB = 4;   /* Genesis / SMS port B → analog[4] */

static inline BOOL isLightGunSystem(int sysType) {
    return sysType == SYSTEM_MENACER_GP
        || sysType == SYSTEM_JUSTIFIER_GP
        || sysType == SYSTEM_LIGHTPHASER_GP;
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - LightGun category
// ─────────────────────────────────────────────────────────────────────────────

@implementation PVCoreGenesisPlusBridge (LightGun)

// MARK: – LightGunResponder required properties

- (BOOL)gameSupportsLightGun {
    return isLightGunSystem(input.system[0]) || isLightGunSystem(input.system[1]);
}

- (BOOL)requiresLightGun {
    return NO;
}

// MARK: – Active port helper

- (NSInteger)lightGunPort {
    // Menacer & Justifiers are port-B only.
    // Light Phaser can be in either port; port A is system[0], port B is system[1].
    if (isLightGunSystem(input.system[1])) {
        return kPortB;
    }
    if (isLightGunSystem(input.system[0])) {
        return kPortA;
    }
    return kPortB; // conventional fallback
}

// MARK: – LightGunResponder: position update

- (void)lightGunMovedToPoint:(CGPoint)point isOffscreen:(BOOL)isOffscreen {
    if (!self.gameSupportsLightGun) { return; }

    int port = (int)self.lightGunPort;

    if (isOffscreen) {
        // Move cursor well outside the active area so the scanline comparator
        // never matches → the hardware sees a "miss", triggering reload/penalty.
        input.analog[port][0] = -64;
        input.analog[port][1] = -64;
        return;
    }

    int vpW = bitmap.viewport.w;
    int vpH = bitmap.viewport.h;
    if (vpW <= 0 || vpH <= 0) { return; }

    // Clamp to [0, 1] before scaling.
    float nx = (float)MAX(0.0, MIN(1.0, point.x));
    float ny = (float)MAX(0.0, MIN(1.0, point.y));

    input.analog[port][0] = (int16_gp)(nx * (vpW - 1));
    input.analog[port][1] = (int16_gp)(ny * (vpH - 1));
}

// MARK: – LightGunResponder: trigger
//
// All three gun types use INPUT_A as the primary-fire bit:
//   menacer_read()  : data = input.pad[4] >> 4 → bit5 = trigger (D1)
//   phaser_read()   : ~((input.pad[port] >> 2) & 0x10) → TL active-low
//   justifier_read(): (~input.pad[port] >> 6) & 0x01 → D0 active-low
// In every case, setting INPUT_A in pad[] signals "trigger pressed".

- (void)lightGunTriggerDown {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] |= INPUT_A_GP;
}

- (void)lightGunTriggerUp {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] &= ~INPUT_A_GP;
}

// MARK: – LightGunResponder: off-screen reload
//
// Long-press / right-click gesture = move off screen then fire once.

- (void)lightGunReloadDown {
    if (!self.gameSupportsLightGun) { return; }
    int port = (int)self.lightGunPort;
    input.analog[port][0] = -64;
    input.analog[port][1] = -64;
    input.pad[port] |= INPUT_A_GP;
}

- (void)lightGunReloadUp {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] &= ~INPUT_A_GP;
}

// MARK: – LightGunResponder: Menacer aux buttons
//
// Menacer button mapping (from lightgun.c menacer_read):
//   INPUT_B  → AuxB (bottom-right button, D0)
//   INPUT_A  → Trigger (D1, handled above)
//   INPUT_C  → AuxA  (top button, D2)
//   INPUT_START → Start (D3)

- (void)lightGunAuxADown {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] |= INPUT_C_GP;
}

- (void)lightGunAuxAUp {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] &= ~INPUT_C_GP;
}

- (void)lightGunAuxBDown {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] |= INPUT_B_GP;
}

- (void)lightGunAuxBUp {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] &= ~INPUT_B_GP;
}

- (void)lightGunStartDown {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] |= INPUT_START_GP;
}

- (void)lightGunStartUp {
    if (!self.gameSupportsLightGun) { return; }
    input.pad[self.lightGunPort] &= ~INPUT_START_GP;
}

@end
