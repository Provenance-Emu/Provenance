//
//  PVDolphinCore+RetroAchievements.mm
//  PVDolphin
//

#import "PVDolphinCore+RetroAchievements.h"

#include "Core/HW/Memmap.h"
#include "Core/System.h"

@implementation PVDolphinCoreBridge (RetroAchievements)

- (void *)systemRAMPtr {
    auto& memory = Core::System::GetInstance().GetMemory();
    return memory.GetRAM();
}

- (NSUInteger)systemRAMSize {
    auto& memory = Core::System::GetInstance().GetMemory();
    return (NSUInteger)memory.GetRamSize();
}

- (void *)systemEXRAMPtr {
    auto& memory = Core::System::GetInstance().GetMemory();
    return memory.GetEXRAM();
}

- (NSUInteger)systemEXRAMSize {
    auto& memory = Core::System::GetInstance().GetMemory();
    return (NSUInteger)memory.GetExRamSize();
}

@end
