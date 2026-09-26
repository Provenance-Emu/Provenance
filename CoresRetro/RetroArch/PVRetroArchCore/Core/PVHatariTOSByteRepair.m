//
//  PVHatariTOSByteRepair.m
//  PVRetroArch
//
//  See PVHatariTOSByteRepair.h — disabled by default (issue #2383).
//
//  Copyright © 2024 Provenance. All rights reserved.
//

#import "PVHatariTOSByteRepair.h"

// Hatari reads the load address big-endian from bytes 8-11 and the version from bytes 2-3.
static const NSUInteger kTOSHeaderMinLength = 12;
static const uint32_t kTOSLoadAddress1x = 0x00FC0000;
static const uint32_t kTOSLoadAddress2x = 0x00E00000;
static const uint32_t kTOSLoadAddress4x = 0x00E80000;

static uint32_t PVTOSLoadAddress(const unsigned char *b) {
    return ((uint32_t)b[8] << 24) | ((uint32_t)b[9] << 16) | ((uint32_t)b[10] << 8) | (uint32_t)b[11];
}

/// Maps a byte-swapped load address to the valid one. Returns 0 when unrecognised.
///   Old Provenance LE-write bug: header fields written as native LE ints
///     (0x00FC0000 → bytes 00 00 FC 00 → reads as 0x0000FC00; version bytes swapped too).
///   Word-swapped (interleaved) dump: every 16-bit word has its bytes swapped
///     (bytes 00 FC 00 00 → FC 00 00 00 → reads as 0xFC000000).
static uint32_t PVTOSFixedLoadAddress(uint32_t address, BOOL *isWordSwap) {
    *isWordSwap = NO;
    switch (address) {
        case 0x0000FC00: return kTOSLoadAddress1x;
        case 0x0000E000: return kTOSLoadAddress2x;
        case 0x0000E800: return kTOSLoadAddress4x;
        case 0xFC000000: *isWordSwap = YES; return kTOSLoadAddress1x;
        case 0xE0000000: *isWordSwap = YES; return kTOSLoadAddress2x;
        case 0xE8000000: *isWordSwap = YES; return kTOSLoadAddress4x;
        default: return 0;
    }
}

@implementation PVHatariTOSByteRepair

+ (BOOL)isEnabled {
    return PV_HATARI_TOS_BYTE_REPAIR != 0;
}

+ (BOOL)isRepairableLoadAddress:(uint32_t)address {
    BOOL isWordSwap = NO;
    return [self isEnabled] && PVTOSFixedLoadAddress(address, &isWordSwap) != 0;
}

+ (nullable NSData *)repairedDataForTOSData:(NSData *)data
                                    summary:(NSString *_Nullable *_Nullable)summary {
    if (![self isEnabled] || data.length < kTOSHeaderMinLength) {
        return nil;
    }
    const unsigned char *b = (const unsigned char *)data.bytes;
    uint32_t addr = PVTOSLoadAddress(b);

    if (addr == kTOSLoadAddress1x || addr == kTOSLoadAddress2x || addr == kTOSLoadAddress4x) {
        // Address is valid — catch a partially-repaired ROM whose version bytes are
        // still swapped (major version must be at b[2], big-endian).
        unsigned char expectedMajor = (addr == kTOSLoadAddress1x) ? 0x01 :
                                      (addr == kTOSLoadAddress2x) ? 0x02 : 0x04;
        unsigned char v0 = b[2], v1 = b[3];
        if (!(v1 == expectedMajor && v0 != expectedMajor)) {
            return nil;
        }
        NSMutableData *fixed = [data mutableCopy];
        unsigned char *fb = (unsigned char *)fixed.mutableBytes;
        fb[2] = v1;
        fb[3] = v0;
        if (summary) {
            *summary = [NSString stringWithFormat:@"corrected byte-swapped version bytes (0x%02X%02X → 0x%02X%02X)",
                        v0, v1, v1, v0];
        }
        return fixed;
    }

    BOOL isWordSwap = NO;
    uint32_t fixAddr = PVTOSFixedLoadAddress(addr, &isWordSwap);
    if (fixAddr == 0) {
        return nil;
    }

    NSMutableData *fixed = [data mutableCopy];
    unsigned char *fb = (unsigned char *)fixed.mutableBytes;
    if (isWordSwap) {
        // Swap every byte pair so both the header and the 68000 code are corrected.
        size_t len = fixed.length & ~(size_t)1;
        for (size_t i = 0; i < len; i += 2) {
            unsigned char tmp = fb[i];
            fb[i] = fb[i + 1];
            fb[i + 1] = tmp;
        }
        if (summary) {
            *summary = [NSString stringWithFormat:@"full word-swap applied (%zu bytes)", (size_t)fixed.length];
        }
    } else {
        fb[8]  = (fixAddr >> 24) & 0xFF;
        fb[9]  = (fixAddr >> 16) & 0xFF;
        fb[10] = (fixAddr >>  8) & 0xFF;
        fb[11] = (fixAddr      ) & 0xFF;
        unsigned char tmp = fb[2];
        fb[2] = fb[3];
        fb[3] = tmp;
        if (summary) {
            *summary = [NSString stringWithFormat:@"corrected LE-written header (addr 0x%08X → 0x%08X, version swapped)",
                        addr, fixAddr];
        }
    }
    return fixed;
}

@end
