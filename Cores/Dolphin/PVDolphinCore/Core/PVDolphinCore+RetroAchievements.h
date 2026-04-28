//
//  PVDolphinCore+RetroAchievements.h
//  PVDolphin
//
//  Memory accessors for the rcheevos integration.
//
//  GameCube exposes MEM1 (24 MiB) at rcheevos / GC bus address 0x80000000.
//  Wii additionally exposes MEM2 (64 MiB) at rcheevos / Wii bus address
//  0x90000000. The bridge surfaces both pointers so the Swift conformance
//  can build the correct region list for the loaded title.
//

#import "PVDolphinCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVDolphinCoreBridge (RetroAchievements)

/// Pointer to the start of MEM1 (GameCube/Wii main RAM, 24 MiB).
/// Returns NULL when the emulator is not yet initialised.
@property (nonatomic, readonly, nullable) void *systemRAMPtr;

/// Size in bytes of the MEM1 block exposed via @c systemRAMPtr.
@property (nonatomic, readonly) NSUInteger systemRAMSize;

/// Pointer to MEM2 (Wii extended RAM, 64 MiB). NULL on GameCube titles.
@property (nonatomic, readonly, nullable) void *systemEXRAMPtr;

/// Size in bytes of the MEM2 block exposed via @c systemEXRAMPtr. 0 on GameCube.
@property (nonatomic, readonly) NSUInteger systemEXRAMSize;

@end

NS_ASSUME_NONNULL_END
