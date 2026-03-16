//
//  PVRetroArchCore+BIOS+AtariST.m
//  PVRetroArch
//
//  Atari ST / Hatari TOS BIOS setup, repair, and validation.
//  Extracted from PVRetroArchCore+RetroArchUI.m to keep that file manageable.
//
//  Created by Provenance Team.
//  Copyright © 2024 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVRetroArchCoreBridge.h"
#import <PVLogging/PVLoggingObjC.h>

// ---------------------------------------------------------------------------
// MARK: - TOS filename registry
// ---------------------------------------------------------------------------

/// All known TOS ROM filenames, in preference order.
/// The canonical name for Hatari is tos.img; the remaining entries are
/// alternate names that users may import (e.g. tos102.img).
/// All TOS-related search, repair, and copy loops derive from this list.
static NSArray<NSString *> *TOSAllFilenames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[
            @"tos.img",
            @"tos100.img",  @"tos100de.img",
            @"tos102.img",  @"tos102us.img", @"tos102uk.img", @"tos102de.img",
            @"tos104.img",  @"tos104de.img", @"tos104uk.img",
            @"tos106.img",  @"tos162.img",   @"tos206.img",
            @"emutos1m.img",
        ];
    });
    return names;
}

// ---------------------------------------------------------------------------
// MARK: - BIOSAtariST category interface
// ---------------------------------------------------------------------------

@interface PVRetroArchCoreBridge (BIOSAtariST)

/// YES when the current system/core is Atari ST / Hatari.
- (BOOL)pv_isHatariSystem;

/// Validate and repair a TOS ROM file in-place.
///
/// - Removes the file if it is a ZIP archive (magic bytes PK).
/// - Corrects the three byte-swapped load-address patterns introduced by
///   Provenance bug Spike 2823 (old patching code wrote addresses in wrong byte order).
/// - Returns YES if the file exists and is not a ZIP after the call.
- (BOOL)repairTOSImageAtPath:(NSString *)tosPath;

/// Final TOS validation before Hatari launches.
/// Logs a clear diagnostic if neither path contains a bootable TOS.
- (void)validateTOSReadyOrLog:(NSString *)primaryPath fallback:(NSString *)fallbackPath;

/// Search *directory* for the best usable TOS ROM.
/// Checks every name in TOSAllFilenames() and returns the full path of the
/// first file that is ≥128 KB, not a ZIP, and has a known-valid load address.
/// Returns nil if no usable TOS is found.
- (nullable NSString *)findBestTOSInDirectory:(NSString *)directory;

/// Log a diagnostic inventory of every TOS file found in biosDir and systemDir.
/// Call this when debugging boot failures.
- (void)logTOSInventoryForSystemDir:(NSString *)systemDir biosDir:(NSString *)biosDir;

/// Full Hatari TOS setup: find the best TOS from biosDir, repair it, and
/// write it to systemDir/tos.img and systemDir/hatari/tos.img.
/// Also repairs any stale TOS files already present in those destinations
/// (e.g. files that arrived via CloudKit sync or a previous buggy install).
- (void)setupHatariTOSForSystemDir:(NSString *)systemDir;

/// Write hatari.cfg to systemDir/hatari/hatari.cfg (primary) and
/// systemDir/hatari.cfg (legacy), patching the TOS image path and
/// disk-image directory to absolute runtime paths.
- (void)writeHatariConfigForSystemDir:(NSString *)systemDir;

/// Post-sync repair: called after syncResources to repair any byte-swapped
/// TOS files that may have been copied from the BIOS directory.
- (void)repairHatariTOSInSystemDir:(NSString *)systemDir;

@end

// ---------------------------------------------------------------------------
// MARK: - BIOSAtariST implementation
// ---------------------------------------------------------------------------

@implementation PVRetroArchCoreBridge (BIOSAtariST)

- (BOOL)pv_isHatariSystem {
    return [self.systemIdentifier containsString:@"atarist"] ||
           [self.coreIdentifier   containsString:@"hatari"];
}

// ---------------------------------------------------------------------------
// MARK: repairTOSImageAtPath:
// ---------------------------------------------------------------------------

- (BOOL)repairTOSImageAtPath:(NSString *)tosPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:tosPath]) return NO;

    NSError *readErr = nil;
    NSData *tosData = [NSData dataWithContentsOfFile:tosPath
                                            options:NSDataReadingMappedIfSafe
                                              error:&readErr];
    if (!tosData) {
        ELOG(@"TOS repair: failed to read %@: %@", tosPath, readErr.localizedDescription);
        return NO;
    }
    if (tosData.length < 12) {
        WLOG(@"TOS repair: %@ is too short (%zu bytes)", tosPath, (size_t)tosData.length);
        return NO;
    }

    const unsigned char *b = (const unsigned char *)tosData.bytes;

    // ZIP check — syncResources may have copied a still-archived BIOS.
    if (b[0] == 0x50 && b[1] == 0x4B) {
        ELOG(@"TOS repair: removing ZIP at %@ — BIOS must be extracted before use", tosPath);
        NSError *rmErr = nil;
        if (![fm removeItemAtPath:tosPath error:&rmErr]) {
            ELOG(@"TOS repair: failed to remove ZIP at %@: %@", tosPath, rmErr.localizedDescription);
        }
        return NO;
    }

    // Byte-swap check: Hatari reads the load address big-endian from bytes 8-11.
    // Valid:   0x00FC0000 (TOS 1.x), 0x00E00000 (TOS 2.x), 0x00E80000 (TOS 4.x).
    // Buggy:   0x0000FC00, 0x0000E000, 0x0000E800  (old Provenance Spike 2823 patterns)
    uint32_t addr = ((uint32_t)b[8]  << 24) |
                    ((uint32_t)b[9]  << 16) |
                    ((uint32_t)b[10] <<  8) |
                    ((uint32_t)b[11]);
    BOOL addrOK = (addr == 0x00FC0000 || addr == 0x00E00000 || addr == 0x00E80000);
    if (addrOK) return YES;

    uint32_t fixAddr = 0;
    if      (addr == 0x0000FC00) fixAddr = 0x00FC0000;
    else if (addr == 0x0000E000) fixAddr = 0x00E00000;
    else if (addr == 0x0000E800) fixAddr = 0x00E80000;

    if (fixAddr == 0) {
        WLOG(@"TOS repair: unrecognised load address 0x%08X in %@ — leaving untouched", addr, tosPath);
        return YES; // file is present, even if Hatari may reject it
    }

    NSMutableData *fixed = [tosData mutableCopy];
    unsigned char *fb = (unsigned char *)fixed.mutableBytes;
    fb[8]  = (fixAddr >> 24) & 0xFF;
    fb[9]  = (fixAddr >> 16) & 0xFF;
    fb[10] = (fixAddr >>  8) & 0xFF;
    fb[11] = (fixAddr      ) & 0xFF;
    NSError *writeErr = nil;
    if ([fixed writeToFile:tosPath options:NSDataWritingAtomic error:&writeErr]) {
        ILOG(@"TOS repair: corrected load address 0x%08X → 0x%08X in %@", addr, fixAddr, tosPath);
        return YES;
    } else {
        ELOG(@"TOS repair: write failed for %@: %@", tosPath, writeErr.localizedDescription);
        return NO;
    }
}

// ---------------------------------------------------------------------------
// MARK: validateTOSReadyOrLog:fallback:
// ---------------------------------------------------------------------------

- (void)validateTOSReadyOrLog:(NSString *)primaryPath fallback:(NSString *)fallbackPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *usablePath = nil;
    for (NSString *path in @[primaryPath, fallbackPath]) {
        if ([fm fileExistsAtPath:path]) { usablePath = path; break; }
    }
    if (!usablePath) {
        ELOG(@"HATARI BOOT WILL FAIL: No TOS ROM found at %@ or %@. "
             @"Import a TOS ROM (tos.img, tos102.img, etc.) via the BIOS import screen.",
             primaryPath, fallbackPath);
        return;
    }

    NSError *readErr = nil;
    NSData *data = [NSData dataWithContentsOfFile:usablePath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readErr];
    if (!data || data.length < 12) {
        ELOG(@"HATARI BOOT WILL FAIL: TOS ROM at %@ unreadable or too small (%zu bytes). "
             @"Delete and reimport a valid TOS ROM.",
             usablePath, data ? (size_t)data.length : 0);
        return;
    }

    const unsigned char *b = (const unsigned char *)data.bytes;

    if (b[0] == 0x50 && b[1] == 0x4B) {
        ELOG(@"HATARI BOOT WILL FAIL: TOS ROM at %@ is a ZIP. Extract and reimport the .img file.",
             usablePath);
        return;
    }
    if (data.length < 128 * 1024) {
        ELOG(@"HATARI BOOT WILL FAIL: TOS ROM at %@ is only %zu bytes (expected ≥128 KB). "
             @"File may be truncated or corrupt.", usablePath, (size_t)data.length);
        return;
    }

    uint32_t addr = ((uint32_t)b[8]  << 24) |
                    ((uint32_t)b[9]  << 16) |
                    ((uint32_t)b[10] <<  8) |
                    ((uint32_t)b[11]);
    BOOL addrOK = (addr == 0x00FC0000 || addr == 0x00E00000 || addr == 0x00E80000);
    if (!addrOK) {
        ELOG(@"HATARI BOOT MAY FAIL: TOS ROM at %@ has unexpected load address 0x%08X "
             @"(expected 0x00FC0000, 0x00E00000, or 0x00E80000). ROM may be corrupt.",
             usablePath, addr);
    } else {
        ILOG(@"TOS ROM validated OK: %@ (addr=0x%08X, size=%zu bytes)",
             usablePath, addr, (size_t)data.length);
    }
}

// ---------------------------------------------------------------------------
// MARK: findBestTOSInDirectory:
// ---------------------------------------------------------------------------

- (nullable NSString *)findBestTOSInDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *name in TOSAllFilenames()) {
        NSString *candidate = [directory stringByAppendingPathComponent:name];
        if (![fm fileExistsAtPath:candidate]) continue;

        NSError *err = nil;
        NSData *data = [NSData dataWithContentsOfFile:candidate
                                              options:NSDataReadingMappedIfSafe
                                                error:&err];
        if (!data || data.length < 128 * 1024) {
            WLOG(@"TOS search: skipping %@ (too small or unreadable: %zu bytes)",
                 candidate, data ? (size_t)data.length : 0);
            continue;
        }
        const unsigned char *b = (const unsigned char *)data.bytes;
        if (b[0] == 0x50 && b[1] == 0x4B) {
            WLOG(@"TOS search: skipping %@ (is a ZIP archive)", candidate);
            continue;
        }
        uint32_t addr = ((uint32_t)b[8]  << 24) |
                        ((uint32_t)b[9]  << 16) |
                        ((uint32_t)b[10] <<  8) |
                        ((uint32_t)b[11]);
        BOOL addrOK = (addr == 0x00FC0000 || addr == 0x00E00000 || addr == 0x00E80000);
        if (!addrOK) {
            // Check if it's a known byte-swap pattern we can repair
            BOOL repairable = (addr == 0x0000FC00 || addr == 0x0000E000 || addr == 0x0000E800);
            if (!repairable) {
                WLOG(@"TOS search: skipping %@ (unrecognised address 0x%08X)", candidate, addr);
                continue;
            }
            // Repairable — repair in place, then accept
            ILOG(@"TOS search: found repairable TOS at %@ (addr 0x%08X)", candidate, addr);
            [self repairTOSImageAtPath:candidate];
        }
        ILOG(@"TOS search: selected %@ (addr=0x%08X, size=%zu bytes)",
             candidate, addr, (size_t)data.length);
        return candidate;
    }
    return nil;
}

// ---------------------------------------------------------------------------
// MARK: logTOSInventoryForSystemDir:biosDir:
// ---------------------------------------------------------------------------

- (void)logTOSInventoryForSystemDir:(NSString *)systemDir biosDir:(NSString *)biosDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *hatariDir = [systemDir stringByAppendingPathComponent:@"hatari"];

    NSArray<NSString *> *scanDirs = @[biosDir, systemDir, hatariDir];
    NSArray<NSString *> *scanLabels = @[@"BIOS", @"system", @"system/hatari"];

    ILOG(@"=== Atari ST TOS inventory ===");
    for (NSUInteger di = 0; di < scanDirs.count; di++) {
        NSString *dir = scanDirs[di];
        NSString *label = scanLabels[di];
        BOOL isDir = NO;
        BOOL exists = [fm fileExistsAtPath:dir isDirectory:&isDir];
        if (!exists) {
            ILOG(@"  [%@] directory not found: %@", label, dir);
            continue;
        } else if (!isDir) {
            ILOG(@"  [%@] path exists but is not a directory: %@", label, dir);
            continue;
        }
        BOOL foundAny = NO;
        for (NSString *name in TOSAllFilenames()) {
            NSString *path = [dir stringByAppendingPathComponent:name];
            if (![fm fileExistsAtPath:path]) continue;
            foundAny = YES;
            NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
            unsigned long long size = [attrs fileSize];
            NSError *err = nil;
            NSData *hdr = [NSData dataWithContentsOfFile:path
                                                 options:NSDataReadingMappedIfSafe
                                                   error:&err];
            if (!hdr || hdr.length < 16) {
                ILOG(@"  [%@] %@ — %llu bytes (unreadable header)", label, name, size);
                continue;
            }
            const unsigned char *b = (const unsigned char *)hdr.bytes;
            uint32_t addr = ((uint32_t)b[8]  << 24) |
                            ((uint32_t)b[9]  << 16) |
                            ((uint32_t)b[10] <<  8) |
                            ((uint32_t)b[11]);
            BOOL isZip = (b[0] == 0x50 && b[1] == 0x4B);
            BOOL addrOK = (addr == 0x00FC0000 || addr == 0x00E00000 || addr == 0x00E80000);
            NSString *status = isZip ? @"ZIP!" :
                               (!addrOK ? [NSString stringWithFormat:@"BAD addr 0x%08X", addr] :
                               @"OK");
            ILOG(@"  [%@] %@ — %llu bytes, addr=0x%08X [%@]  hdr: %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X",
                 label, name, size, addr, status,
                 b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],
                 b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15]);
        }
        if (!foundAny) {
            ILOG(@"  [%@] — no TOS files found in %@", label, dir);
        }
    }
    ILOG(@"=== end TOS inventory ===");
}

// ---------------------------------------------------------------------------
// MARK: setupHatariTOSForSystemDir:
// ---------------------------------------------------------------------------

- (void)setupHatariTOSForSystemDir:(NSString *)systemDir {
    NSFileManager *fm = [NSFileManager defaultManager];

    // --- Ensure hatari working subdirectory exists ---
    NSString *hatariDir = [systemDir stringByAppendingPathComponent:@"hatari"];
    BOOL hatariDirUsable = YES;
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:hatariDir isDirectory:&isDir]) {
        if (!isDir) {
            ELOG(@"Hatari: expected directory at %@ but found a file", hatariDir);
            hatariDirUsable = NO;
        }
    } else {
        NSError *mkErr = nil;
        if (![fm createDirectoryAtPath:hatariDir
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&mkErr]) {
            ELOG(@"Hatari: failed to create working dir %@: %@",
                 hatariDir, mkErr.localizedDescription);
            hatariDirUsable = NO;
        } else {
            ILOG(@"Hatari: created working directory %@", hatariDir);
        }
    }

    NSString *sysTosPath    = [systemDir   stringByAppendingPathComponent:@"tos.img"];
    NSString *hatariTosPath = hatariDirUsable
                                ? [hatariDir stringByAppendingPathComponent:@"tos.img"]
                                : sysTosPath;

    // --- Log inventory before doing anything, useful for diagnosing stuck-BIOS issues ---
    [self logTOSInventoryForSystemDir:systemDir biosDir:self.BIOSPath];

    // --- Find the best TOS in the BIOS directory ---
    // Unlike the old code, we validate each candidate before accepting it.
    // This means a stale/corrupt tos.img in BIOS won't block a valid tos102.img
    // imported later (e.g., via CloudKit or manual import).
    NSString *biosTosSource = [self findBestTOSInDirectory:self.BIOSPath];

    if (biosTosSource) {
        NSError *readErr = nil;
        NSData *tosData = [NSData dataWithContentsOfFile:biosTosSource
                                                 options:NSDataReadingMappedIfSafe
                                                   error:&readErr];
        if (!tosData) {
            ELOG(@"Hatari: failed to read TOS from %@: %@",
                 biosTosSource, readErr.localizedDescription);
        } else {
            // Apply any needed byte-swap repair in memory before writing.
            NSMutableData *tosToWrite = [tosData mutableCopy];
            if (tosToWrite.length >= 12) {
                unsigned char *fb = (unsigned char *)tosToWrite.mutableBytes;
                uint32_t addr = ((uint32_t)fb[8]  << 24) |
                                ((uint32_t)fb[9]  << 16) |
                                ((uint32_t)fb[10] <<  8) |
                                ((uint32_t)fb[11]);
                uint32_t fixAddr = 0;
                if      (addr == 0x0000FC00) fixAddr = 0x00FC0000;
                else if (addr == 0x0000E000) fixAddr = 0x00E00000;
                else if (addr == 0x0000E800) fixAddr = 0x00E80000;
                if (fixAddr) {
                    fb[8]  = (fixAddr >> 24) & 0xFF;
                    fb[9]  = (fixAddr >> 16) & 0xFF;
                    fb[10] = (fixAddr >>  8) & 0xFF;
                    fb[11] = (fixAddr      ) & 0xFF;
                    ILOG(@"Hatari: corrected TOS address 0x%08X → 0x%08X (from %@)",
                         addr, fixAddr, biosTosSource);
                }
            }

            unsigned long long sizeBytes = tosToWrite.length;
            if (sizeBytes < 128 * 1024) {
                WLOG(@"Hatari: TOS source %@ is too small (%llu bytes) — skipping write",
                     biosTosSource, sizeBytes);
            } else {
                // Write to system/tos.img (absolute path referenced in hatari.cfg)
                NSError *writeErr = nil;
                if ([tosToWrite writeToFile:sysTosPath options:NSDataWritingAtomic error:&writeErr]) {
                    ILOG(@"Hatari: TOS written to %@ (%llu bytes)", sysTosPath, sizeBytes);
                } else {
                    ELOG(@"Hatari: failed to write TOS to %@: %@",
                         sysTosPath, writeErr.localizedDescription);
                }

                // Also write to system/hatari/tos.img (Hatari's working dir)
                if (![sysTosPath isEqualToString:hatariTosPath]) {
                    writeErr = nil;
                    if ([tosToWrite writeToFile:hatariTosPath options:NSDataWritingAtomic error:&writeErr]) {
                        ILOG(@"Hatari: TOS written to %@ (%llu bytes)", hatariTosPath, sizeBytes);
                    } else {
                        ELOG(@"Hatari: failed to write TOS to %@: %@",
                             hatariTosPath, writeErr.localizedDescription);
                    }
                }

                if (sizeBytes != 192*1024 && sizeBytes != 256*1024 && sizeBytes != 512*1024) {
                    WLOG(@"Hatari: TOS size %llu bytes is unusual (expected 192KB, 256KB, or 512KB)",
                         sizeBytes);
                }
            }
        }
    } else {
        ELOG(@"Hatari: no valid TOS ROM found in BIOS directory %@. "
             @"Import a TOS ROM (tos.img, tos102.img, etc.) via the BIOS import screen.",
             self.BIOSPath);
    }

    // In-place repair of any stale TOS files that may already exist in system dirs
    // (from a previous buggy install, CloudKit sync, or old Provenance version).
    // This runs even when no BIOS source was available, to auto-fix existing bad files.
    [self repairHatariTOSInSystemDir:systemDir];

    // Final validation — helps spot issues during boot, check logs for diagnostics.
    [self validateTOSReadyOrLog:hatariTosPath fallback:sysTosPath];
}

// ---------------------------------------------------------------------------
// MARK: writeHatariConfigForSystemDir:
// ---------------------------------------------------------------------------

- (void)writeHatariConfigForSystemDir:(NSString *)systemDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *hatariDir        = [systemDir stringByAppendingPathComponent:@"hatari"];
    NSString *hatariCfgPath    = [systemDir stringByAppendingPathComponent:@"hatari.cfg"];
    NSString *hatariWorkCfgPath = [hatariDir stringByAppendingPathComponent:@"hatari.cfg"];
    NSString *sysTosPath       = [systemDir stringByAppendingPathComponent:@"tos.img"];
    NSString *cfgSource = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]]
                           pathForResource:@"hatari.cfg" ofType:nil];

    if (!cfgSource) {
        ELOG(@"Hatari: bundled hatari.cfg not found — cannot write config");
        return;
    }

    NSError *readErr = nil;
    NSString *cfgContent = [NSString stringWithContentsOfFile:cfgSource
                                                      encoding:NSUTF8StringEncoding
                                                         error:&readErr];
    if (!cfgContent) {
        ELOG(@"Hatari: failed to read hatari.cfg template from %@: %@",
             cfgSource, readErr.localizedDescription);
        // Fall back to a simple copy
        [self syncResource:cfgSource to:hatariCfgPath];
        [self syncResource:cfgSource to:hatariWorkCfgPath];
        return;
    }

    // Embed absolute TOS path so Hatari finds the ROM regardless of cwd.
    cfgContent = [cfgContent
        stringByReplacingOccurrencesOfString:@"szTosImageFileName = tos.img"
                                  withString:[NSString stringWithFormat:@"szTosImageFileName = %@", sysTosPath]];

    // Update disk image directory to the system-specific ROMs folder.
    NSString *romsDirectory = [self.documentsDirectory stringByAppendingPathComponent:@"ROMs"];
    if (self.systemIdentifier) {
        romsDirectory = [romsDirectory stringByAppendingPathComponent:self.systemIdentifier];
    }
    NSError *regexErr = nil;
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"szDiskImageDirectory = ~/Documents/ROMs/[^\n]+"
                             options:0
                               error:&regexErr];
    if (regex) {
        cfgContent = [regex
            stringByReplacingMatchesInString:cfgContent
                                     options:0
                                       range:NSMakeRange(0, cfgContent.length)
                                withTemplate:[NSString stringWithFormat:@"szDiskImageDirectory = %@/", romsDirectory]];
    } else {
        ELOG(@"Hatari: regex for szDiskImageDirectory failed: %@", regexErr);
    }

    // Ensure hatari working directory exists
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:hatariDir isDirectory:&isDir] || !isDir) {
        [fm createDirectoryAtPath:hatariDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSError *workWriteErr = nil;
    BOOL workOK = [cfgContent writeToFile:hatariWorkCfgPath
                               atomically:NO
                                 encoding:NSUTF8StringEncoding
                                    error:&workWriteErr];
    NSError *legacyWriteErr = nil;
    BOOL legacyOK = [cfgContent writeToFile:hatariCfgPath
                                 atomically:NO
                                   encoding:NSUTF8StringEncoding
                                      error:&legacyWriteErr];
    if (workOK && legacyOK) {
        ILOG(@"Hatari: hatari.cfg written — TOS: %@, ROMs: %@", sysTosPath, romsDirectory);
    } else {
        if (!workOK) ELOG(@"Hatari: failed to write hatari.cfg to %@: %@", hatariWorkCfgPath, workWriteErr);
        if (!legacyOK) ELOG(@"Hatari: failed to write hatari.cfg to %@: %@", hatariCfgPath, legacyWriteErr);
    }
}

// ---------------------------------------------------------------------------
// MARK: repairHatariTOSInSystemDir:
// ---------------------------------------------------------------------------

- (void)repairHatariTOSInSystemDir:(NSString *)systemDir {
    NSString *hatariDir = [systemDir stringByAppendingPathComponent:@"hatari"];
    ILOG(@"Hatari: scanning system dirs for byte-swapped or invalid TOS files...");
    for (NSString *name in TOSAllFilenames()) {
        for (NSString *dir in @[systemDir, hatariDir]) {
            NSString *path = [dir stringByAppendingPathComponent:name];
            [self repairTOSImageAtPath:path];
        }
    }
}

@end
