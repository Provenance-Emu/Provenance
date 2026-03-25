/*
 mGBAGameCoreBridge+Achievements.h

 Exposes mGBA memory regions and achievement-lifecycle methods needed by
 PVmGBACore's CoreRetroAchievements conformance.

 Memory layout exposed:
   GBA:
     EWRAM (External Working RAM) — 256 KiB at 0x02000000
     IWRAM (Internal Working RAM) — 32  KiB at 0x03000000
     Cart SRAM                    — variable at 0x0E000000

   GB / GBC:
     WRAM (Working RAM)  — 8 KiB (GB) / 32 KiB (GBC) at 0xC000
     VRAM (Video RAM)    — 8 KiB (GB) / 16 KiB (GBC) at 0x8000
*/

#import "mGBAGameCoreBridge.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Achievement-related memory access and lifecycle for the mGBA core bridge.
@interface PVmGBAGameCoreBridge (Achievements)

// MARK: - Hardcore mode

/// When YES, save-state *loads* are rejected to enforce hardcore rules.
/// Save-state *saves* are still permitted.
@property (nonatomic, assign) BOOL hardcoreMode;

// MARK: - Achievement session state

/// Indicates whether the achievement runtime is currently active.
/// Set to YES by the Swift layer after a successful RA session start;
/// reset to NO on stopAchievements / ROM unload.
@property (nonatomic, assign) BOOL achievementsActive;

// MARK: - GBA memory regions

/// Pointer to External Working RAM (EWRAM, 256 KiB).
/// Returns NULL when the core has not yet loaded a ROM.
- (nullable void *)ewramPointer:(nonnull NSUInteger *)sizeOut;

/// Pointer to Internal Working RAM (IWRAM, 32 KiB).
/// Returns NULL when the core has not yet loaded a ROM.
- (nullable void *)iwramPointer:(nonnull NSUInteger *)sizeOut;

/// Pointer to cartridge SRAM (size varies by game; may be NULL if the
/// cartridge has no battery-backed RAM).
- (nullable void *)sramPointer:(nonnull NSUInteger *)sizeOut;

// MARK: - GB / GBC memory regions

/// YES when the currently-loaded ROM is a Game Boy or Game Boy Color game.
@property (nonatomic, readonly) BOOL isGBGame;

/// Pointer to GB/GBC Working RAM (WRAM).
/// 8 KiB on DMG/SGB, 32 KiB on GBC (all banks combined).
- (nullable void *)gbWramPointer:(nonnull NSUInteger *)sizeOut;

/// Pointer to GB/GBC Video RAM (VRAM).
/// 8 KiB on DMG/SGB, 16 KiB on GBC (both banks).
- (nullable void *)gbVramPointer:(nonnull NSUInteger *)sizeOut;

@end

NS_ASSUME_NONNULL_END
