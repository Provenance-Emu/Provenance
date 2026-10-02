//
//  PVDolphinCore+RetroAchievements.mm
//  PVDolphin
//
//  The views returned here are raw guest memory in big-endian byte order:
//  the same bytes Dolphin's own AchievementManager::MemoryPeeker hands
//  rcheevos via MMU::HostTryRead<u8>(…, RequestedAddressSpace::Physical).
//

#import "PVDolphinCore+RetroAchievements.h"

#include "Core/HW/Memmap.h"
#include "Core/System.h"

@implementation PVDolphinCoreBridge (RetroAchievements)

- (void *)systemRAMPtr {
    auto& memory = Core::System::GetInstance().GetMemory();
    if (!memory.IsInitialized())
        return nullptr;
    return memory.GetRAM();
}

// GetRamSize() is the power-of-two allocation (32 MiB for a 24 MiB retail
// console); the emulated console only sees GetRamSizeReal() bytes.
- (NSUInteger)systemRAMSize {
    auto& memory = Core::System::GetInstance().GetMemory();
    if (!memory.IsInitialized())
        return 0;
    return (NSUInteger)memory.GetRamSizeReal();
}

// MEM2 is Wii-only. Gate on the booted title, not the pointer alone:
// GetExRamSize() is non-zero on GameCube too, and MemoryManager::Init() never
// clears a WII_ONLY region's `active` flag left over from an earlier Wii boot.
- (void *)systemEXRAMPtr {
    auto& system = Core::System::GetInstance();
    auto& memory = system.GetMemory();
    if (!memory.IsInitialized() || !system.IsWii())
        return nullptr;
    return memory.GetEXRAM();
}

- (NSUInteger)systemEXRAMSize {
    auto& system = Core::System::GetInstance();
    auto& memory = system.GetMemory();
    if (!memory.IsInitialized() || !system.IsWii())
        return 0;
    return (NSUInteger)memory.GetExRamSizeReal();
}

@end
