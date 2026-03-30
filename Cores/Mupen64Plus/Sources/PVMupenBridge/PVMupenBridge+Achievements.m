/*
 PVMupenBridge+Achievements.m

 Implements achievement memory region accessor and lifecycle helpers for
 the Mupen64Plus core bridge.

 N64 memory layout:
   RDRAM — 0x00000000 to 0x007FFFFF (8 MiB, Mupen64Plus always allocates full size)
   rcheevos maps N64 addresses starting at 0x00000000 as RC_MEMORY_TYPE_SYSTEM_RAM.

 The RDRAM pointer is obtained from the global AudioInfo struct populated when
 the Mupen64Plus audio plugin calls InitiateAudio(). It remains valid for the
 duration of the emulation session.
*/

#import "PVMupenBridge+Achievements.h"
#import <objc/runtime.h>

// Pull in the AUDIO_INFO type definition from the Mupen64Plus audio plugin API.
#import "api/m64p_plugin.h"

// AudioInfo is declared and populated in PVMupenBridge+Mupen.m.
// It is set by MupenOpenAudio() when the audio plugin initialises.
extern AUDIO_INFO AudioInfo;

// N64 RDRAM size: Mupen64Plus always allocates 8 MiB regardless of whether
// an Expansion Pak is present. rcheevos is tolerant of the extra pages when
// only a 4 MiB base configuration is active.
static const NSUInteger kN64RDRAMSize = 8u * 1024u * 1024u; // 8 MiB

// Associated-object keys for stored properties added via ObjC category.
// The address of each variable is used as the unique key (not the value).
// Non-const so the linker/optimiser cannot merge them into one symbol.
static char kHardcoreModeKey;
static char kAchievementsActiveKey;

@implementation PVMupenBridge (Achievements)

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

// MARK: - N64 RDRAM memory region accessor

- (nullable void *)rdramPointer:(nullable NSUInteger *)sizeOut {
    // AudioInfo.RDRAM is NULL until the audio plugin calls InitiateAudio().
    if (AudioInfo.RDRAM == NULL) {
        if (sizeOut) { *sizeOut = 0; }
        return NULL;
    }
    if (sizeOut) { *sizeOut = kN64RDRAMSize; }
    return (void *)AudioInfo.RDRAM;
}

@end
