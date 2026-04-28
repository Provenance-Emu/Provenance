//
//  PVPPSSPPCore+RetroAchievements.mm
//  PVPPSSPP
//

#import "PVPPSSPPCore+RetroAchievements.h"

#include "Core/MemMap.h"

@implementation PVPPSSPPCoreBridge (RetroAchievements)

- (void *)systemRAMPtr {
    if (Memory::base == nullptr) { return nullptr; }
    return Memory::base + 0x08000000;
}

- (NSUInteger)systemRAMSize {
    return (NSUInteger)Memory::g_MemorySize;
}

@end
