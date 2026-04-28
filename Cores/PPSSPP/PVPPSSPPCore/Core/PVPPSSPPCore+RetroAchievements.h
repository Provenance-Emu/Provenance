//
//  PVPPSSPPCore+RetroAchievements.h
//  PVPPSSPP
//
//  Memory accessors for the rcheevos integration. PSP main RAM is exposed
//  at PSP virtual address 0x08000000 in the standard rcheevos PSP map.
//

#import "PVPPSSPPCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVPPSSPPCoreBridge (RetroAchievements)

/// Pointer to the start of PSP main RAM (`Memory::base + 0x08000000`).
/// Returns NULL when the emulator is not yet initialised.
@property (nonatomic, readonly, nullable) void *systemRAMPtr;

/// Size in bytes of the main RAM block exposed via @c systemRAMPtr.
/// 32 MiB on retail PSP, 64 MiB on PSP-2000.
@property (nonatomic, readonly) NSUInteger systemRAMSize;

@end

NS_ASSUME_NONNULL_END
