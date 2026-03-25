/*
 mGBAGameCoreBridge+Achievements.mm

 Implements achievement memory region accessors and lifecycle helpers for
 the mGBA core bridge.

 GBA memory region IDs mirror the high byte of the address bus:
   0x02 — EWRAM (External Working RAM, 256 KiB at 0x02000000)
   0x03 — IWRAM (Internal Working RAM, 32 KiB at 0x03000000)
   0x0E — Cart SRAM (at 0x0E000000)

 GB/GBC region IDs mirror the high nibble of the 16-bit address:
   0x8 — VRAM (at 0x8000)
   0xC — WRAM bank 0 (at 0xC000)
   0xD — WRAM bank 1–7 (at 0xD000, GBC only)
*/

#import "mGBAGameCoreBridge+Achievements.h"
#import <objc/runtime.h>

#include <mgba-util/common.h>
#include <mgba/core/core.h>
#include <mgba/core/interface.h>

// GBA memory region IDs (high byte of bus address, per mGBA convention)
#define GBA_REGION_EWRAM   0x02u
#define GBA_REGION_IWRAM   0x03u
#define GBA_REGION_SRAM    0x0Eu

// GB/GBC memory region IDs (high nibble of 16-bit bus address)
#define GB_REGION_VRAM     0x08u
#define GB_REGION_WRAM_0   0x0Cu
#define GB_REGION_WRAM_1   0x0Du

// Associated-object keys for stored properties added via category
static const char kHardcoreModeKey    = 0;
static const char kAchievementsActiveKey = 0;

// ---------------------------------------------------------------------------
// Forward declaration: access the `core` ivar from the main @implementation.
// The ivar is declared in mGBAGameCoreBridge.m as `struct mCore* core`.
// We reach it via a private accessor defined in the main implementation file.
// ---------------------------------------------------------------------------
@interface PVmGBAGameCoreBridge ()
- (struct mCore *)_mCore;
@end

@implementation PVmGBAGameCoreBridge (Achievements)

// MARK: - hardcoreMode (stored via associated object)

- (BOOL)hardcoreMode {
    NSNumber *val = objc_getAssociatedObject(self, &kHardcoreModeKey);
    return val.boolValue;
}

- (void)setHardcoreMode:(BOOL)hardcoreMode {
    objc_setAssociatedObject(self, &kHardcoreModeKey,
                             @(hardcoreMode),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// MARK: - achievementsActive (stored via associated object)

- (BOOL)achievementsActive {
    NSNumber *val = objc_getAssociatedObject(self, &kAchievementsActiveKey);
    return val.boolValue;
}

- (void)setAchievementsActive:(BOOL)achievementsActive {
    objc_setAssociatedObject(self, &kAchievementsActiveKey,
                             @(achievementsActive),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// MARK: - GBA memory region accessors

- (nullable void *)ewramPointer:(nonnull NSUInteger *)sizeOut {
    struct mCore *c = [self _mCore];
    if (!c || !c->getMemoryBlock) { *sizeOut = 0; return NULL; }
    size_t sz = 0;
    void *ptr = c->getMemoryBlock(c, GBA_REGION_EWRAM, &sz);
    *sizeOut = (NSUInteger)sz;
    return ptr;
}

- (nullable void *)iwramPointer:(nonnull NSUInteger *)sizeOut {
    struct mCore *c = [self _mCore];
    if (!c || !c->getMemoryBlock) { *sizeOut = 0; return NULL; }
    size_t sz = 0;
    void *ptr = c->getMemoryBlock(c, GBA_REGION_IWRAM, &sz);
    *sizeOut = (NSUInteger)sz;
    return ptr;
}

- (nullable void *)sramPointer:(nonnull NSUInteger *)sizeOut {
    struct mCore *c = [self _mCore];
    if (!c || !c->getMemoryBlock) { *sizeOut = 0; return NULL; }
    size_t sz = 0;
    void *ptr = c->getMemoryBlock(c, GBA_REGION_SRAM, &sz);
    *sizeOut = (NSUInteger)sz;
    return ptr;
}

// MARK: - GB platform check

- (BOOL)isGBGame {
    struct mCore *c = [self _mCore];
    if (!c || !c->platform) { return NO; }
    return c->platform(c) == mPLATFORM_GB;
}

// MARK: - GB/GBC memory region accessors

- (nullable void *)gbWramPointer:(nonnull NSUInteger *)sizeOut {
    struct mCore *c = [self _mCore];
    if (!c || !c->getMemoryBlock) { *sizeOut = 0; return NULL; }

    size_t bank0Size = 0;
    uint8_t *bank0 = (uint8_t *)c->getMemoryBlock(c, GB_REGION_WRAM_0, &bank0Size);
    if (!bank0) { *sizeOut = 0; return NULL; }

    // On GBC, bank1 immediately follows bank0 in the returned pointer range.
    // We return bank0 as the base and sum both bank sizes for the total.
    size_t bank1Size = 0;
    c->getMemoryBlock(c, GB_REGION_WRAM_1, &bank1Size); // size only; pointer is contiguous

    *sizeOut = (NSUInteger)(bank0Size + bank1Size);
    return bank0;
}

- (nullable void *)gbVramPointer:(nonnull NSUInteger *)sizeOut {
    struct mCore *c = [self _mCore];
    if (!c || !c->getMemoryBlock) { *sizeOut = 0; return NULL; }
    size_t sz = 0;
    void *ptr = c->getMemoryBlock(c, GB_REGION_VRAM, &sz);
    *sizeOut = (NSUInteger)sz;
    return ptr;
}

@end
