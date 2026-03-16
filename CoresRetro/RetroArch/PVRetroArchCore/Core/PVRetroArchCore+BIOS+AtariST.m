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
#import "PVRetroArchCoreBridge+BIOSAtariST.h"
#import <PVLogging/PVLoggingObjC.h>

// Forward declaration for syncResource:to: which is implemented in
// PVRetroArchCore+RetroArchUI.m. Declaring it here suppresses the
// "may not respond to selector" warning in this compilation unit.
@interface PVRetroArchCoreBridge (RetroArchUIForward)
- (void)syncResource:(NSString *)from to:(NSString *)to;
@end

// ---------------------------------------------------------------------------
// MARK: - TOS filename registry
// ---------------------------------------------------------------------------

/// All known TOS ROM filenames, in preference order.
/// The canonical name for Hatari is tos.img; the remaining entries are
/// alternate names that users may import.  Both .img and .rom extensions are
/// included because many ROM packs distribute TOS images with a .rom suffix.
/// Regional variants (us/uk/de/se/fr) are included to match common dumps.
/// All TOS-related search, repair, and copy loops derive from this list.
static NSArray<NSString *> *TOSAllFilenames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[
            // Canonical name Hatari expects
            @"tos.img",
            // TOS 1.00
            @"tos100.img",    @"tos100.rom",
            @"tos100us.img",  @"tos100us.rom",
            @"tos100de.img",  @"tos100de.rom",
            @"tos100uk.img",  @"tos100uk.rom",
            // TOS 1.02
            @"tos102.img",    @"tos102.rom",
            @"tos102us.img",  @"tos102us.rom",
            @"tos102uk.img",  @"tos102uk.rom",
            @"tos102de.img",  @"tos102de.rom",
            // TOS 1.04
            @"tos104.img",    @"tos104.rom",
            @"tos104us.img",  @"tos104us.rom",
            @"tos104uk.img",  @"tos104uk.rom",
            @"tos104de.img",  @"tos104de.rom",
            @"tos104se.img",  @"tos104se.rom",
            @"tos104fr.img",  @"tos104fr.rom",
            // TOS 1.06 / 1.62
            @"tos106.img",    @"tos106.rom",
            @"tos106us.img",  @"tos106us.rom",
            @"tos106uk.img",  @"tos106uk.rom",
            @"tos162.img",    @"tos162.rom",
            // TOS 2.05 / 2.06
            @"tos205.img",    @"tos205.rom",
            @"tos205us.img",  @"tos205us.rom",
            @"tos206.img",    @"tos206.rom",
            @"tos206us.img",  @"tos206us.rom",
            @"tos206uk.img",  @"tos206uk.rom",
            @"tos206de.img",  @"tos206de.rom",
            // EmuTOS (open-source TOS replacement)
            @"emutos1m.img",  @"emutos1m.rom",
            @"emutos2m.img",  @"emutos2m.rom",
            @"emutos512.img", @"emutos512.rom",
        ];
    });
    return names;
}

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

    // Log the first bytes for diagnosis
    ILOG(@"TOS repair check: %@ — first bytes: %02X %02X %02X %02X  addr bytes: %02X %02X %02X %02X",
         tosPath.lastPathComponent,
         b[0], b[1], b[2], b[3],
         b[8], b[9], b[10], b[11]);

    // Full word-swap check — detect if the entire ROM is byte-swapped (every 16-bit
    // word has its bytes reversed).  A genuine Atari ST TOS image starts with a 68000
    // BRA instruction encoded big-endian as 0x60, 0x1A.  If the first two bytes are
    // 0x1A, 0x60 the ROM has been dumped in word-swapped order and must be corrected
    // before Hatari can use it.  (Hatari standalone auto-detects this, but the
    // Hatari libretro core v1.8.0 shipped with Provenance does not.)
    if (b[0] == 0x1A && b[1] == 0x60) {
        uint32_t preAddr = ((uint32_t)b[8]  << 24) | ((uint32_t)b[9]  << 16) |
                           ((uint32_t)b[10] <<  8) | ((uint32_t)b[11]);
        ILOG(@"TOS repair: word-swapped ROM detected at %@ (preAddr=0x%08X) — applying full word-swap",
             tosPath, preAddr);

        NSMutableData *swapped = [tosData mutableCopy];
        unsigned char *sb = (unsigned char *)swapped.mutableBytes;
        for (NSUInteger i = 0; i + 1 < swapped.length; i += 2) {
            unsigned char tmp = sb[i];
            sb[i] = sb[i + 1];
            sb[i + 1] = tmp;
        }

        // After the full word-swap, check if the load address is valid.
        // This handles "partially-fixed" ROMs where a prior code path already corrected
        // bytes 8-11 (the load address) but left the rest of the ROM still word-swapped.
        // The full word-swap above would put bytes 0-1 right but swap bytes 8-11 back to
        // the wrong endianness.  Detect this and apply the address fix again.
        uint32_t postAddr = ((uint32_t)sb[8]  << 24) | ((uint32_t)sb[9]  << 16) |
                            ((uint32_t)sb[10] <<  8) | ((uint32_t)sb[11]);
        BOOL postAddrOK = (postAddr == 0x00FC0000 || postAddr == 0x00E00000 || postAddr == 0x00E80000);
        if (!postAddrOK) {
            uint32_t fixAddr = 0;
            if      (postAddr == 0xFC000000 || postAddr == 0x0000FC00) fixAddr = 0x00FC0000;
            else if (postAddr == 0xE0000000 || postAddr == 0x0000E000) fixAddr = 0x00E00000;
            else if (postAddr == 0xE8000000 || postAddr == 0x0000E800) fixAddr = 0x00E80000;
            if (fixAddr) {
                sb[8]  = (fixAddr >> 24) & 0xFF;
                sb[9]  = (fixAddr >> 16) & 0xFF;
                sb[10] = (fixAddr >>  8) & 0xFF;
                sb[11] = (fixAddr      ) & 0xFF;
                ILOG(@"TOS repair: also corrected post-swap address 0x%08X → 0x%08X "
                     @"(file was partially-fixed by older code)", postAddr, fixAddr);
                postAddr = fixAddr;
            } else {
                WLOG(@"TOS repair: post-swap address 0x%08X is unrecognised — "
                     @"ROM may be corrupt but will proceed", postAddr);
            }
        }

        NSError *writeErr = nil;
        if ([swapped writeToFile:tosPath options:NSDataWritingAtomic error:&writeErr]) {
            uint32_t logAddr = ((uint32_t)sb[8]  << 24) | ((uint32_t)sb[9]  << 16) |
                               ((uint32_t)sb[10] <<  8) | ((uint32_t)sb[11]);
            ILOG(@"TOS repair: word-swap applied to %@ (%zu bytes, addr=0x%08X, "
                 @"version bytes: %02X%02X)",
                 tosPath, (size_t)swapped.length, logAddr, sb[2], sb[3]);
            return YES;
        } else {
            ELOG(@"TOS repair: failed to write word-swapped ROM to %@: %@",
                 tosPath, writeErr.localizedDescription);
            return NO;
        }
    }

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
             @"Import a TOS ROM (tos.img, tos102.img, tos102.rom, etc.) via the BIOS import screen.",
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

    // Log full header for diagnosis regardless of validity
    uint16_t tosVersion = ((uint16_t)b[2] << 8) | (uint16_t)b[3];
    uint32_t addr = ((uint32_t)b[8]  << 24) |
                    ((uint32_t)b[9]  << 16) |
                    ((uint32_t)b[10] <<  8) |
                    ((uint32_t)b[11]);
    ILOG(@"TOS validate: %@ — size=%zu bytes, hdr[0..3]=%02X %02X %02X %02X, "
         @"version=0x%04X (%d.%02d), addr=0x%08X",
         usablePath.lastPathComponent, (size_t)data.length,
         b[0], b[1], b[2], b[3],
         tosVersion, (tosVersion >> 8) & 0xFF, tosVersion & 0xFF,
         addr);

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

    // Check BRA instruction at bytes 0-1 (0x60 0x1A for a valid Atari ST TOS)
    if (b[0] == 0x1A && b[1] == 0x60) {
        ELOG(@"HATARI BOOT WILL FAIL: TOS ROM at %@ still has word-swapped BRA instruction "
             @"(bytes 0-1 = 0x1A 0x60, should be 0x60 0x1A). "
             @"The word-swap repair was not applied — try deleting and reimporting the TOS ROM.",
             usablePath);
        return;
    }
    if (b[0] != 0x60 || b[1] != 0x1A) {
        WLOG(@"HATARI BOOT MAY FAIL: TOS ROM at %@ has unexpected bytes at 0-1: 0x%02X 0x%02X "
             @"(expected 0x60 0x1A for a valid 68000 BRA instruction). ROM may be corrupt.",
             usablePath, b[0], b[1]);
    }

    BOOL addrOK = (addr == 0x00FC0000 || addr == 0x00E00000 || addr == 0x00E80000);
    if (!addrOK) {
        ELOG(@"HATARI BOOT MAY FAIL: TOS ROM at %@ has unexpected load address 0x%08X "
             @"(expected 0x00FC0000, 0x00E00000, or 0x00E80000). ROM may be corrupt.",
             usablePath, addr);
    } else {
        ILOG(@"TOS ROM validated OK: %@ (version=0x%04X=%d.%02d, addr=0x%08X, size=%zu bytes)",
             usablePath, tosVersion,
             (tosVersion >> 8) & 0xFF, tosVersion & 0xFF,
             addr, (size_t)data.length);
    }
}

// ---------------------------------------------------------------------------
// MARK: findBestTOSInDirectory:
// ---------------------------------------------------------------------------

- (nullable NSString *)findBestTOSInDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    ILOG(@"TOS search: scanning directory %@", directory);
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

        // Also check the BRA instruction at bytes 0-1 even when the address looks valid.
        // A "partially-fixed" ROM (where old code corrected only bytes 8-11) will pass the
        // address check but still have the word-swapped BRA (0x1A 0x60) at bytes 0-1, which
        // Hatari rejects.  Treat this case as repairable.
        BOOL braOK = (b[0] == 0x60 && b[1] == 0x1A);

        if (addrOK && braOK) {
            uint16_t tosVersion = ((uint16_t)b[2] << 8) | (uint16_t)b[3];
            ILOG(@"TOS search: selected %@ (version=0x%04X=%d.%02d, addr=0x%08X, size=%zu bytes)",
                 candidate, tosVersion,
                 (tosVersion >> 8) & 0xFF, tosVersion & 0xFF,
                 addr, (size_t)data.length);
            return candidate;
        }

        // Determine if the file is repairable:
        // - Full word-swap: bytes 0-1 are 0x1A 0x60 (address will also be wrong)
        // - Address-only swap (old Provenance Spike 2823 bug): address bytes mangled
        // - Partially-fixed: bytes 0-1 are 0x1A 0x60 but address is valid (old code fixed addr only)
        BOOL isWordSwapped = (b[0] == 0x1A && b[1] == 0x60);
        BOOL addrRepairable = (addr == 0x0000FC00 || addr == 0x0000E000 || addr == 0x0000E800);
        BOOL repairable = isWordSwapped || addrRepairable || (!braOK && addrOK);

        if (!repairable) {
            WLOG(@"TOS search: skipping %@ (unrecognised address 0x%08X, "
                 @"first bytes 0x%02X%02X — not repairable)",
                 candidate, addr, b[0], b[1]);
            continue;
        }

        // Repairable — repair in place, then re-read to confirm the fix took effect
        ILOG(@"TOS search: found repairable TOS at %@ "
             @"(addr=0x%08X, firstBytes=0x%02X%02X, wordSwapped=%d, addrOnly=%d, partialFix=%d)",
             candidate, addr, b[0], b[1],
             (int)isWordSwapped, (int)addrRepairable, (int)(!braOK && addrOK));
        BOOL repaired = [self repairTOSImageAtPath:candidate];
        if (!repaired) {
            WLOG(@"TOS search: repair failed for %@ — skipping", candidate);
            continue;
        }
        // Re-read the header to verify the corrected result
        NSError *verifyErr = nil;
        NSData *fixedData = [NSData dataWithContentsOfFile:candidate
                                                   options:NSDataReadingMappedIfSafe
                                                     error:&verifyErr];
        if (!fixedData || fixedData.length < 12) {
            WLOG(@"TOS search: could not re-read repaired TOS at %@ — skipping", candidate);
            continue;
        }
        const unsigned char *fb = (const unsigned char *)fixedData.bytes;
        uint32_t fixedAddr = ((uint32_t)fb[8]  << 24) |
                             ((uint32_t)fb[9]  << 16) |
                             ((uint32_t)fb[10] <<  8) |
                             ((uint32_t)fb[11]);
        BOOL fixedAddrOK = (fixedAddr == 0x00FC0000 || fixedAddr == 0x00E00000 || fixedAddr == 0x00E80000);
        BOOL fixedBraOK  = (fb[0] == 0x60 && fb[1] == 0x1A);
        if (!fixedAddrOK || !fixedBraOK) {
            WLOG(@"TOS search: repaired TOS at %@ still invalid "
                 @"(addr=0x%08X, bytes[0..1]=0x%02X%02X) — skipping",
                 candidate, fixedAddr, fb[0], fb[1]);
            continue;
        }
        uint16_t fixedVer = ((uint16_t)fb[2] << 8) | (uint16_t)fb[3];
        ILOG(@"TOS search: selected (after repair) %@ "
             @"(version=0x%04X=%d.%02d, addr=0x%08X→0x%08X, size=%zu bytes)",
             candidate, fixedVer,
             (fixedVer >> 8) & 0xFF, fixedVer & 0xFF,
             addr, fixedAddr, (size_t)fixedData.length);
        return candidate;
    }
    WLOG(@"TOS search: no valid TOS ROM found in %@", directory);
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
            uint16_t tosVersion = ((uint16_t)b[2] << 8) | (uint16_t)b[3];
            BOOL isZip = (b[0] == 0x50 && b[1] == 0x4B);
            BOOL addrOK = (addr == 0x00FC0000 || addr == 0x00E00000 || addr == 0x00E80000);
            BOOL braOK  = (b[0] == 0x60 && b[1] == 0x1A);
            NSString *status;
            if (isZip) {
                status = @"ZIP!";
            } else if (!braOK) {
                status = [NSString stringWithFormat:@"BAD bra[0..1]=0x%02X%02X", b[0], b[1]];
            } else if (!addrOK) {
                status = [NSString stringWithFormat:@"BAD addr 0x%08X", addr];
            } else {
                status = [NSString stringWithFormat:@"OK ver=%d.%02d",
                          (tosVersion >> 8) & 0xFF, tosVersion & 0xFF];
            }
            ILOG(@"  [%@] %@ — %llu bytes, version=0x%04X, addr=0x%08X [%@]  "
                 @"hdr: %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X %02X%02X",
                 label, name, size, tosVersion, addr, status,
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

    ILOG(@"Hatari: === TOS setup start === systemDir=%@, BIOSPath=%@", systemDir, self.BIOSPath);

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

    // --- Log full inventory before we start ---
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
            // The BIOS source was already repaired in-place by findBestTOSInDirectory:,
            // so these checks are a safety net for any edge cases we missed.
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
                const unsigned char *dbg = (const unsigned char *)tosToWrite.bytes;
                uint16_t ver = ((uint16_t)dbg[2] << 8) | (uint16_t)dbg[3];
                uint32_t dbgAddr = ((uint32_t)dbg[8]  << 24) | ((uint32_t)dbg[9]  << 16) |
                                   ((uint32_t)dbg[10] <<  8) | ((uint32_t)dbg[11]);
                ILOG(@"Hatari: preparing to write TOS — source=%@, size=%llu, "
                     @"version=0x%04X (%d.%02d), addr=0x%08X, bra=%02X%02X",
                     biosTosSource.lastPathComponent, sizeBytes,
                     ver, (ver >> 8) & 0xFF, ver & 0xFF,
                     dbgAddr, dbg[0], dbg[1]);

                // Always write (overwrite) to system/tos.img — referenced by hatari.cfg
                NSError *writeErr = nil;
                if ([tosToWrite writeToFile:sysTosPath options:NSDataWritingAtomic error:&writeErr]) {
                    ILOG(@"Hatari: TOS written to %@ (%llu bytes)", sysTosPath, sizeBytes);
                } else {
                    ELOG(@"Hatari: failed to write TOS to %@: %@",
                         sysTosPath, writeErr.localizedDescription);
                }

                // Always write (overwrite) to system/hatari/tos.img — Hatari's working dir
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
             @"Import a TOS ROM (tos.img, tos102.img, tos102.rom, etc.) via the BIOS import screen.",
             self.BIOSPath);
        // Log a full inventory to help diagnose where the missing/invalid TOS files are.
        [self logTOSInventoryForSystemDir:systemDir biosDir:self.BIOSPath];
    }

    // In-place repair of any stale TOS files that may already exist in system dirs
    // (from a previous buggy install, CloudKit sync, or old Provenance version).
    // This runs even when no BIOS source was available, to auto-fix existing bad files.
    [self repairHatariTOSInSystemDir:systemDir];

    // Final validation — helps spot issues during boot, check logs for diagnostics.
    [self validateTOSReadyOrLog:hatariTosPath fallback:sysTosPath];

    ILOG(@"Hatari: === TOS setup complete ===");
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
    // The template uses "szTosImageFileName = tos.img" — replace with absolute path.
    NSString *tosReplacement = [NSString stringWithFormat:@"szTosImageFileName = %@", sysTosPath];
    NSString *updatedContent = [cfgContent
        stringByReplacingOccurrencesOfString:@"szTosImageFileName = tos.img"
                                  withString:tosReplacement];
    if ([updatedContent isEqualToString:cfgContent]) {
        // Fallback: template didn't match the expected pattern; try a regex
        WLOG(@"Hatari: hatari.cfg TOS path replacement had no effect — trying regex fallback");
        NSError *regexErr2 = nil;
        NSRegularExpression *tosRegex = [NSRegularExpression
            regularExpressionWithPattern:@"szTosImageFileName\\s*=\\s*[^\n]*"
                                 options:0
                                   error:&regexErr2];
        if (tosRegex) {
            updatedContent = [tosRegex
                stringByReplacingMatchesInString:cfgContent
                                         options:0
                                           range:NSMakeRange(0, cfgContent.length)
                                    withTemplate:tosReplacement];
        }
    }

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
        updatedContent = [regex
            stringByReplacingMatchesInString:updatedContent
                                     options:0
                                       range:NSMakeRange(0, updatedContent.length)
                                withTemplate:[NSString stringWithFormat:@"szDiskImageDirectory = %@/", romsDirectory]];
    } else {
        ELOG(@"Hatari: regex for szDiskImageDirectory failed: %@", regexErr);
    }

    // Ensure hatari working directory exists
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:hatariDir isDirectory:&isDir] || !isDir) {
        NSError *mkErr = nil;
        if (![fm createDirectoryAtPath:hatariDir withIntermediateDirectories:YES attributes:nil error:&mkErr]) {
            ELOG(@"Hatari: failed to create working dir %@ for config: %@",
                 hatariDir, mkErr.localizedDescription);
        }
    }

    NSError *workWriteErr = nil;
    BOOL workOK = [updatedContent writeToFile:hatariWorkCfgPath
                                   atomically:NO
                                     encoding:NSUTF8StringEncoding
                                        error:&workWriteErr];
    NSError *legacyWriteErr = nil;
    BOOL legacyOK = [updatedContent writeToFile:hatariCfgPath
                                     atomically:NO
                                       encoding:NSUTF8StringEncoding
                                          error:&legacyWriteErr];
    if (workOK && legacyOK) {
        ILOG(@"Hatari: hatari.cfg written to both paths — TOS: %@, ROMs: %@",
             sysTosPath, romsDirectory);
    } else {
        if (!workOK) ELOG(@"Hatari: failed to write hatari.cfg to %@: %@", hatariWorkCfgPath, workWriteErr);
        if (!legacyOK) ELOG(@"Hatari: failed to write hatari.cfg to %@: %@", hatariCfgPath, legacyWriteErr);
    }

    // Verify the TOS path was actually embedded
    if ([updatedContent containsString:sysTosPath]) {
        ILOG(@"Hatari: hatari.cfg TOS path verified: %@", sysTosPath);
    } else {
        WLOG(@"Hatari: hatari.cfg does NOT contain expected TOS path '%@' — "
             @"Hatari may use wrong TOS or fall back to working-dir tos.img", sysTosPath);
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
