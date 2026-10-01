//
//  PVPPSSPPCore+RetroAchievements.mm
//  PVPPSSPP
//

#import "PVPPSSPPCore+RetroAchievements.h"

#include "Core/MemMap.h"
#include "Core/System.h"

@implementation PVPPSSPPCoreBridge (RetroAchievements)

// PSP RAM is only valid once the game has finished booting (`PSP_IsInited()`);
// `Memory::base` can be non-null earlier (the memory map is set up before the
// game loads) and may dangle after shutdown, so gate on both.
- (void *)systemRAMPtr {
    if (!PSP_IsInited() || Memory::base == nullptr || Memory::g_MemorySize == 0) { return nullptr; }
    return Memory::base + 0x08000000;
}

- (NSUInteger)systemRAMSize {
    if (!PSP_IsInited()) { return 0; }
    return (NSUInteger)Memory::g_MemorySize;
}

@end
