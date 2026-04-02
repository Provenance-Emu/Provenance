//
//  PVRetroArchCoreBridge+BIOSAtariST.h
//  PVRetroArch
//
//  Atari ST / Hatari TOS BIOS category header.
//  Import this header in any compilation unit that calls the BIOSAtariST
//  category methods (e.g. PVRetroArchCore+RetroArchUI.m) to keep builds
//  warning-free.
//
//  Created by Provenance Team.
//  Copyright © 2024 Provenance. All rights reserved.
//

#import <PVRetroArch/PVRetroArchCoreBridge.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVRetroArchCoreBridge (BIOSAtariST)

/// YES when the current system/core is Atari ST / Hatari.
- (BOOL)pv_isHatariSystem;

/// Validate and repair a TOS ROM file in-place.
/// Returns YES if the file exists and is not a ZIP archive.
/// Note: also returns YES when the load address is unrecognised and left
/// untouched — the file is present but Hatari may still reject it if the
/// address is unsupported. Returns NO if the file is missing, unreadable,
/// too short, a ZIP archive, or the byte-swap repair write failed.
- (BOOL)repairTOSImageAtPath:(NSString *)tosPath;

/// Final TOS validation before Hatari launches.
/// Logs a clear diagnostic if neither path contains a bootable TOS.
- (void)validateTOSReadyOrLog:(NSString *)primaryPath fallback:(NSString *)fallbackPath;

/// Search *directory* for the best usable TOS ROM.
/// Returns the full path of the first valid TOS, or nil if none is found.
- (nullable NSString *)findBestTOSInDirectory:(NSString *)directory;

/// Log a diagnostic inventory of every TOS file found in biosDir and systemDir.
- (void)logTOSInventoryForSystemDir:(NSString *)systemDir biosDir:(NSString *)biosDir;

/// Full Hatari TOS setup: find, repair, and write TOS to the system directories.
- (void)setupHatariTOSForSystemDir:(NSString *)systemDir;

/// Write hatari.cfg to the system and hatari working directories.
- (void)writeHatariConfigForSystemDir:(NSString *)systemDir;

/// Post-sync repair: repair any byte-swapped TOS files in the system directories.
- (void)repairHatariTOSInSystemDir:(NSString *)systemDir;

/// Validate that a usable TOS ROM is present. Returns YES if TOS is found and valid.
/// On failure sets *error with a user-friendly description.
/// Call from loadFileAtPath:error: to prevent Hatari from crashing when TOS is
/// missing or corrupt (null input_gui → EXC_BAD_ACCESS in Dialog_DoProperty).
- (BOOL)validateHatariTOSOrError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
