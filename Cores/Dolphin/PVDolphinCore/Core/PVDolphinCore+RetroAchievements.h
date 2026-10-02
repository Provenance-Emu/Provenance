//
//  PVDolphinCore+RetroAchievements.h
//  PVDolphin
//
//  Memory accessors for the rcheevos integration.
//
//  Surfaces MEM1 (GameCube/Wii, 24 MiB) and MEM2 (Wii only, 64 MiB) so the
//  Swift conformance can build the rcheevos region list for the loaded
//  title. Pointers are raw guest memory (big-endian byte order); the rcheevos
//  addresses they map to are chosen in PVDolphinCore+RetroAchievements.swift.
//

#import "PVDolphinCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVDolphinCoreBridge (RetroAchievements)

/// Pointer to the start of MEM1 (GameCube/Wii main RAM, 24 MiB).
/// Returns NULL until Dolphin's memory manager is initialised (i.e. before boot).
@property (nonatomic, readonly, nullable) void *systemRAMPtr;

/// Emulated size in bytes of MEM1 (GetRamSizeReal, not the power-of-two
/// allocation). 0 before boot.
@property (nonatomic, readonly) NSUInteger systemRAMSize;

/// Pointer to MEM2 (Wii extended RAM, 64 MiB). NULL on GameCube titles and before boot.
@property (nonatomic, readonly, nullable) void *systemEXRAMPtr;

/// Emulated size in bytes of MEM2. 0 on GameCube titles and before boot.
@property (nonatomic, readonly) NSUInteger systemEXRAMSize;

@end

NS_ASSUME_NONNULL_END
