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
#import <os/lock.h>

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

// ── Thread safety ─────────────────────────────────────────────────────────────
// LightGun callbacks arrive on the main thread while the emulation loop reads
// `input` on its own thread.  A single unfair lock serialises our writes.
// The emulation side does not hold this lock on read; individual int16_t writes
// on ARM64 are naturally atomic, so the practical worst-case is a momentary
// sub-frame glitch rather than memory corruption.
static os_unfair_lock sLightGunLock = OS_UNFAIR_LOCK_INIT;

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

// Returns YES when both port B indices (4 and 5) must be updated.
// Konami Justifiers dynamically switch between indices 4 and 5 depending on
// which gun fired last (justifier_write sets lightgun.Port = 4 + (data>>5 & 1)).
// Mirroring both ensures gun #2 reads from index 5 see consistent aim/trigger.
- (BOOL)needsJustifierDualPort {
    return input.system[1] == SYSTEM_JUSTIFIER_GP;
}

// MARK: – LightGunResponder: position update

- (void)lightGunMovedToPoint:(CGPoint)point isOffscreen:(BOOL)isOffscreen {
    if (!self.gameSupportsLightGun) { return; }

    int port = (int)self.lightGunPort;
    BOOL dualPort = self.needsJustifierDualPort;

    os_unfair_lock_lock(&sLightGunLock);

    if (isOffscreen) {
        // Move cursor well outside the active area so the scanline comparator
        // never matches → the hardware sees a "miss", triggering reload/penalty.
        input.analog[port][0] = -64;
        input.analog[port][1] = -64;
        if (dualPort) {
            input.analog[5][0] = -64;
            input.analog[5][1] = -64;
        }
        os_unfair_lock_unlock(&sLightGunLock);
        return;
    }

    int vpX = bitmap.viewport.x;
    int vpY = bitmap.viewport.y;
    int vpW = bitmap.viewport.w;
    int vpH = bitmap.viewport.h;

    // The underlying buffer includes borders/overscan: total = viewport + 2 * offset.
    int totalW = vpW + 2 * vpX;
    int totalH = vpH + 2 * vpY;

    if (vpW <= 0 || vpH <= 0 || totalW <= 0 || totalH <= 0) {
        os_unfair_lock_unlock(&sLightGunLock);
        return;
    }

    // Clamp to [0, 1] before scaling.
    float nx = (float)MAX(0.0, MIN(1.0, point.x));
    float ny = (float)MAX(0.0, MIN(1.0, point.y));

    // First map normalised UI coordinates into the full presented buffer.
    float bufX = nx * (float)(totalW - 1);
    float bufY = ny * (float)(totalH - 1);

    // Then shift into viewport space by subtracting the border/overscan.
    float viewX = bufX - (float)vpX;
    float viewY = bufY - (float)vpY;

    // Clamp to the valid viewport pixel range [0, vpW-1] / [0, vpH-1].
    if (viewX < 0.0f) { viewX = 0.0f; }
    if (viewY < 0.0f) { viewY = 0.0f; }
    float maxViewX = (float)(vpW - 1);
    float maxViewY = (float)(vpH - 1);
    if (viewX > maxViewX) { viewX = maxViewX; }
    if (viewY > maxViewY) { viewY = maxViewY; }

    input.analog[port][0] = (int16_gp)viewX;
    input.analog[port][1] = (int16_gp)viewY;
    if (dualPort) {
        input.analog[5][0] = (int16_gp)viewX;
        input.analog[5][1] = (int16_gp)viewY;
    }

    os_unfair_lock_unlock(&sLightGunLock);
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
    int port = (int)self.lightGunPort;
    BOOL dualPort = self.needsJustifierDualPort;
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[port] |= INPUT_A_GP;
    if (dualPort) { input.pad[5] |= INPUT_A_GP; }
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunTriggerUp {
    if (!self.gameSupportsLightGun) { return; }
    int port = (int)self.lightGunPort;
    BOOL dualPort = self.needsJustifierDualPort;
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[port] &= ~INPUT_A_GP;
    if (dualPort) { input.pad[5] &= ~INPUT_A_GP; }
    os_unfair_lock_unlock(&sLightGunLock);
}

// MARK: – LightGunResponder: off-screen reload
//
// Long-press / right-click gesture = move off screen then fire once.

- (void)lightGunReloadDown {
    if (!self.gameSupportsLightGun) { return; }
    int port = (int)self.lightGunPort;
    BOOL dualPort = self.needsJustifierDualPort;
    os_unfair_lock_lock(&sLightGunLock);
    input.analog[port][0] = -64;
    input.analog[port][1] = -64;
    input.pad[port] |= INPUT_A_GP;
    if (dualPort) {
        input.analog[5][0] = -64;
        input.analog[5][1] = -64;
        input.pad[5] |= INPUT_A_GP;
    }
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunReloadUp {
    if (!self.gameSupportsLightGun) { return; }
    int port = (int)self.lightGunPort;
    BOOL dualPort = self.needsJustifierDualPort;
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[port] &= ~INPUT_A_GP;
    if (dualPort) { input.pad[5] &= ~INPUT_A_GP; }
    os_unfair_lock_unlock(&sLightGunLock);
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
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[self.lightGunPort] |= INPUT_C_GP;
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunAuxAUp {
    if (!self.gameSupportsLightGun) { return; }
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[self.lightGunPort] &= ~INPUT_C_GP;
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunAuxBDown {
    if (!self.gameSupportsLightGun) { return; }
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[self.lightGunPort] |= INPUT_B_GP;
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunAuxBUp {
    if (!self.gameSupportsLightGun) { return; }
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[self.lightGunPort] &= ~INPUT_B_GP;
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunStartDown {
    if (!self.gameSupportsLightGun) { return; }
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[self.lightGunPort] |= INPUT_START_GP;
    os_unfair_lock_unlock(&sLightGunLock);
}

- (void)lightGunStartUp {
    if (!self.gameSupportsLightGun) { return; }
    os_unfair_lock_lock(&sLightGunLock);
    input.pad[self.lightGunPort] &= ~INPUT_START_GP;
    os_unfair_lock_unlock(&sLightGunLock);
}

@end
