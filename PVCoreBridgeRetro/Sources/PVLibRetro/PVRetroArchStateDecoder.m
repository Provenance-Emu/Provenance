//
//  PVRetroArchStateDecoder.m
//  PVCoreBridgeRetro
//
//  Formats, from the RetroArch commit Provenance 3.3.1 pinned
//  (libretro/RetroArch 9ea790783d656711a21113e4e54ce2dbf626e008):
//
//  rzip (libretro-common/streams/rzip_stream.c):
//    20-byte header: '#','R','Z','I','P','v', version (0x01), '#'
//                    uint32 LE uncompressed chunk size  (bytes 8-11, non-zero)
//                    uint64 LE total uncompressed size  (bytes 12-19, non-zero)
//    then chunks:    uint32 LE compressed size (non-zero), followed by that many
//                    bytes holding one complete zlib stream (deflateInit2 with
//                    window bits 15, finished with Z_FINISH, so each chunk
//                    inflates on its own).
//    A file shorter than 20 bytes, or without the magic, is read as plain data.
//
//  RASTATE (tasks/task_save.c, content_write_serialized_state /
//  content_load_rastate1):
//    'R','A','S','T','A','T','E', version (0x01 binary, not ASCII '1')
//    then blocks:    4-char ID, uint32 LE payload size, payload padded to a
//                    multiple of 8. IDs: "RPLY" (3.3.1 writes it before MEM),
//                    "MEM " (core data, size unaligned), "ACHV", "END " (size 0).
//    Unknown IDs are skipped. Only the "MEM " payload goes to the core.
//

#import "PVRetroArchStateDecoder.h"

#include <zlib.h>

NSErrorDomain const PVRetroArchStateDecoderErrorDomain = @"org.provenance-emu.PVRetroArchStateDecoder";

// MARK: - Format constants

static const uint8_t kRZIPMagicPrefix[] = { '#', 'R', 'Z', 'I', 'P', 'v' };
static const uint8_t kRZIPMagicSuffix = '#';
static const NSUInteger kRZIPVersionOffset = 6;
static const NSUInteger kRZIPMagicLength = 8;
static const uint8_t kRZIPSupportedVersion = 1;
static const NSUInteger kRZIPHeaderLength = 20;
static const NSUInteger kRZIPChunkSizeOffset = 8;
static const NSUInteger kRZIPTotalSizeOffset = 12;
static const NSUInteger kRZIPChunkHeaderLength = 4;

static const uint8_t kRASTATEMagic[] = { 'R', 'A', 'S', 'T', 'A', 'T', 'E' };
static const NSUInteger kRASTATEVersionOffset = 7;
static const NSUInteger kRASTATEHeaderLength = 8;
static const uint8_t kRASTATESupportedVersion = 1;
static const NSUInteger kRASTATEBlockHeaderLength = 8;
static const NSUInteger kRASTATEBlockIDLength = 4;
static const uint64_t kRASTATEBlockAlignment = 8;
static const char kRASTATEMemBlockID[] = "MEM ";
static const char kRASTATEEndBlockID[] = "END ";

/// zlib cannot expand data by more than about 1032:1, so a header that claims
/// more than that is lying and would only make us allocate for nothing.
static const uint64_t kZlibMaximumExpansionRatio = 1032;

/// 512 MiB. The largest libretro states (PSP, Saturn, N64) are tens of MiB.
static const uint64_t kMaximumDecodedSize = 512ull * 1024ull * 1024ull;

// MARK: - Helpers

static inline uint32_t PVReadLE32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static inline uint64_t PVReadLE64(const uint8_t *p) {
    return (uint64_t)PVReadLE32(p) | ((uint64_t)PVReadLE32(p + 4) << 32);
}

static NSError *PVStateDecoderError(PVRetroArchStateDecoderError code, NSString *reason) {
    return [NSError errorWithDomain:PVRetroArchStateDecoderErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: @"Could not decode RetroArch save state",
                                       NSLocalizedFailureReasonErrorKey: reason }];
}

#define PV_FAIL(code, ...)                                                  \
    do {                                                                    \
        if (error) {                                                        \
            *error = PVStateDecoderError((code), [NSString stringWithFormat:__VA_ARGS__]); \
        }                                                                   \
        return nil;                                                         \
    } while (0)

@implementation PVRetroArchStateDecoder

+ (uint64_t)maximumDecodedSize {
    return kMaximumDecodedSize;
}

+ (BOOL)isRZIPData:(NSData *)data {
    if (data.length < kRZIPMagicLength) {
        return NO;
    }
    const uint8_t *bytes = data.bytes;
    return memcmp(bytes, kRZIPMagicPrefix, sizeof(kRZIPMagicPrefix)) == 0
        && bytes[kRZIPMagicLength - 1] == kRZIPMagicSuffix;
}

+ (BOOL)isRASTATEData:(NSData *)data {
    if (data.length < sizeof(kRASTATEMagic)) {
        return NO;
    }
    return memcmp(data.bytes, kRASTATEMagic, sizeof(kRASTATEMagic)) == 0;
}

+ (NSString *)nameForFormat:(PVRetroArchStateFormat)format {
    switch (format) {
        case PVRetroArchStateFormatRaw: return @"raw";
        case PVRetroArchStateFormatRASTATE: return @"RASTATE";
        case PVRetroArchStateFormatRZIPRaw: return @"rzip+raw";
        case PVRetroArchStateFormatRZIPRASTATE: return @"rzip+RASTATE";
    }
    return @"unknown";
}

+ (nullable NSData *)coreDataFromStateData:(NSData *)data
                                    format:(nullable PVRetroArchStateFormat *)format
                                     error:(NSError **)error {
    if (format) {
        *format = PVRetroArchStateFormatRaw;
    }

    NSData *payload = data;
    BOOL compressed = NO;
    if ([self isRZIPData:data]) {
        compressed = YES;
        if (format) {
            *format = PVRetroArchStateFormatRZIPRaw;
        }
        payload = [self inflateRZIPData:data error:error];
        if (!payload) {
            return nil;
        }
    }

    if ([self isRASTATEData:payload]) {
        if (format) {
            *format = compressed ? PVRetroArchStateFormatRZIPRASTATE : PVRetroArchStateFormatRASTATE;
        }
        return [self memBlockFromRASTATEData:payload error:error];
    }

    return payload;
}

+ (nullable NSData *)inflateRZIPData:(NSData *)data error:(NSError **)error {
    if (![self isRZIPData:data]) {
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader, @"missing rzip magic");
    }
    const NSUInteger length = data.length;
    const uint8_t *bytes = data.bytes;

    if (bytes[kRZIPVersionOffset] != kRZIPSupportedVersion) {
        PV_FAIL(PVRetroArchStateDecoderErrorUnsupportedRZIPVersion,
                @"unsupported rzip version %u", (unsigned)bytes[kRZIPVersionOffset]);
    }
    if (length < kRZIPHeaderLength) {
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader,
                @"rzip header truncated (%lu of %lu bytes)", (unsigned long)length, (unsigned long)kRZIPHeaderLength);
    }

    const uint32_t chunkSize = PVReadLE32(bytes + kRZIPChunkSizeOffset);
    const uint64_t totalSize = PVReadLE64(bytes + kRZIPTotalSizeOffset);
    if (chunkSize == 0) {
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader, @"rzip chunk size is 0");
    }
    if (totalSize == 0) {
        // RetroArch writes the size last, at close; 0 means the write never finished.
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader, @"rzip total size is 0 (incomplete write)");
    }
    if (chunkSize > kMaximumDecodedSize || totalSize > kMaximumDecodedSize) {
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader,
                @"rzip sizes too large (chunk %u, total %llu, cap %llu)",
                chunkSize, totalSize, kMaximumDecodedSize);
    }
    if (totalSize / kZlibMaximumExpansionRatio > (uint64_t)length) {
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader,
                @"rzip total size %llu is impossible for %lu compressed bytes",
                totalSize, (unsigned long)length);
    }

    NSMutableData *output = [NSMutableData dataWithLength:(NSUInteger)totalSize];
    if (!output) {
        PV_FAIL(PVRetroArchStateDecoderErrorMalformedRZIPHeader,
                @"could not allocate %llu bytes for rzip output", totalSize);
    }
    uint8_t *out = output.mutableBytes;

    // RetroArch's reader sizes its output buffer chunk + chunk/4 and rejects more.
    const uint64_t maxChunkOutput = (uint64_t)chunkSize + ((uint64_t)chunkSize >> 2);

    NSUInteger offset = kRZIPHeaderLength;
    uint64_t produced = 0;
    NSUInteger chunkIndex = 0;
    while (produced < totalSize) {
        if (length - offset < kRZIPChunkHeaderLength) {
            PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRZIPChunk,
                    @"rzip data ends at chunk %lu after %llu of %llu bytes",
                    (unsigned long)chunkIndex, produced, totalSize);
        }
        const uint32_t compressedSize = PVReadLE32(bytes + offset);
        offset += kRZIPChunkHeaderLength;
        if (compressedSize == 0) {
            PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRZIPChunk,
                    @"rzip chunk %lu has compressed size 0", (unsigned long)chunkIndex);
        }
        if ((uint64_t)compressedSize > (uint64_t)(length - offset)) {
            PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRZIPChunk,
                    @"rzip chunk %lu claims %u bytes, %lu remain",
                    (unsigned long)chunkIndex, compressedSize, (unsigned long)(length - offset));
        }

        z_stream stream;
        memset(&stream, 0, sizeof(stream));
        if (inflateInit(&stream) != Z_OK) {
            PV_FAIL(PVRetroArchStateDecoderErrorRZIPInflateFailed, @"inflateInit failed");
        }
        const uint64_t remaining = totalSize - produced;
        stream.next_in = (Bytef *)(bytes + offset);
        stream.avail_in = (uInt)compressedSize;
        stream.next_out = (Bytef *)(out + produced);
        stream.avail_out = (uInt)remaining; // remaining <= kMaximumDecodedSize < UINT_MAX
        const int status = inflate(&stream, Z_FINISH);
        const uint64_t written = (uint64_t)stream.total_out;
        const uInt unconsumed = stream.avail_in;
        const uInt outLeft = stream.avail_out;
        inflateEnd(&stream);

        if (status != Z_STREAM_END) {
            if (outLeft == 0) {
                PV_FAIL(PVRetroArchStateDecoderErrorRZIPInflateFailed,
                        @"rzip chunk %lu inflates past the declared total size %llu",
                        (unsigned long)chunkIndex, totalSize);
            }
            PV_FAIL(PVRetroArchStateDecoderErrorRZIPInflateFailed,
                    @"rzip chunk %lu is not a complete zlib stream (zlib status %d)",
                    (unsigned long)chunkIndex, status);
        }
        if (unconsumed != 0) {
            PV_FAIL(PVRetroArchStateDecoderErrorRZIPInflateFailed,
                    @"rzip chunk %lu has %u bytes after its zlib stream", (unsigned long)chunkIndex, unconsumed);
        }
        if (written == 0 || written > maxChunkOutput) {
            PV_FAIL(PVRetroArchStateDecoderErrorRZIPInflateFailed,
                    @"rzip chunk %lu inflated to %llu bytes (chunk size %u)",
                    (unsigned long)chunkIndex, written, chunkSize);
        }

        produced += written;
        offset += compressedSize;
        chunkIndex++;
    }
    // Like RetroArch, anything after the declared size is ignored.
    return output;
}

+ (nullable NSData *)memBlockFromRASTATEData:(NSData *)data error:(NSError **)error {
    if (![self isRASTATEData:data]) {
        PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRASTATEBlock, @"missing RASTATE magic");
    }
    const NSUInteger length = data.length;
    const uint8_t *bytes = data.bytes;
    if (length < kRASTATEHeaderLength) {
        PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRASTATEBlock, @"RASTATE header has no version byte");
    }
    if (bytes[kRASTATEVersionOffset] != kRASTATESupportedVersion) {
        PV_FAIL(PVRetroArchStateDecoderErrorUnsupportedRASTATEVersion,
                @"unsupported RASTATE version %u", (unsigned)bytes[kRASTATEVersionOffset]);
    }

    NSUInteger offset = kRASTATEHeaderLength;
    while (length - offset >= kRASTATEBlockHeaderLength) {
        const uint8_t *blockID = bytes + offset;
        const uint32_t blockSize = PVReadLE32(bytes + offset + kRASTATEBlockIDLength);
        const NSUInteger payloadOffset = offset + kRASTATEBlockHeaderLength;
        const uint64_t available = (uint64_t)(length - payloadOffset);

        if (memcmp(blockID, kRASTATEEndBlockID, kRASTATEBlockIDLength) == 0) {
            break;
        }
        if (memcmp(blockID, kRASTATEMemBlockID, kRASTATEBlockIDLength) == 0) {
            if ((uint64_t)blockSize > available) {
                PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRASTATEBlock,
                        @"RASTATE MEM block claims %u bytes, %llu remain", blockSize, available);
            }
            if (blockSize == 0) {
                PV_FAIL(PVRetroArchStateDecoderErrorMissingMEMBlock, @"RASTATE MEM block is empty");
            }
            return [data subdataWithRange:NSMakeRange(payloadOffset, blockSize)];
        }

        const uint64_t aligned = ((uint64_t)blockSize + (kRASTATEBlockAlignment - 1)) & ~(kRASTATEBlockAlignment - 1);
        if (aligned > available) {
            PV_FAIL(PVRetroArchStateDecoderErrorTruncatedRASTATEBlock,
                    @"RASTATE block '%.4s' claims %u bytes, %llu remain",
                    (const char *)blockID, blockSize, available);
        }
        offset = payloadOffset + (NSUInteger)aligned;
    }

    PV_FAIL(PVRetroArchStateDecoderErrorMissingMEMBlock, @"RASTATE container has no MEM block");
}

@end
