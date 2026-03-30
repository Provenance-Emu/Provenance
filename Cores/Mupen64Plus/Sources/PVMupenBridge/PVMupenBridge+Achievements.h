/*
 PVMupenBridge+Achievements.h

 Exposes N64 RDRAM memory region and achievement-lifecycle properties needed
 by MupenGameCore's CoreRetroAchievements conformance.

 Memory layout:
   N64 RDRAM — up to 8 MiB at virtual address 0x00000000
               (4 MiB base; 8 MiB with Expansion Pak)
   Mupen64Plus always allocates 8 MiB; the rcheevos client is tolerant of
   receiving a larger region than the game actually uses.
*/

#import "PVMupenBridge.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Achievement-related memory access and lifecycle for the Mupen64Plus core bridge.
@interface PVMupenBridge (Achievements)

// MARK: - Hardcore mode

/// When YES, save-state *loads* are rejected to enforce hardcore rules.
/// Save-state *saves* are still permitted.
@property (nonatomic, assign) BOOL hardcoreMode;
// MARK: - Achievement session state

/// Indicates whether the achievement runtime is currently active.
/// Set to YES by the Swift layer after a successful RA session start;
/// reset to NO on stopAchievements / ROM unload.
@property (nonatomic, assign) BOOL achievementsActive;

// MARK: - N64 memory region

/// Pointer to the beginning of N64 RDRAM (up to 8 MiB).
///
/// The pointer is sourced from the audio plugin's AUDIO_INFO.RDRAM field,
/// which is populated by Mupen64Plus when the audio plugin is initialised
/// (i.e., after the ROM is loaded and the emulation core is running).
///
/// Returns NULL before emulation starts (AUDIO_INFO not yet populated).
/// @param sizeOut Written with the RDRAM region size in bytes (8 MiB); ignored when NULL.
- (nullable void *)rdramPointer:(nullable NSUInteger *)sizeOut;

@end

NS_ASSUME_NONNULL_END
