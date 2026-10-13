//
//  PVRetroArchStateDecoder.h
//  PVCoreBridgeRetro
//
//  Unwraps save states written by the full RetroArch runtime (Provenance 3.3.x,
//  `content_save_state` in RetroArch's tasks/task_save.c) so the thin wrapper
//  can hand the core's own serialized bytes to `retro_unserialize`.
//
//  A 3.3.x state file can be any of:
//    1. rzip-compressed (`savestate_file_compression = "true"`, the 3.3.1
//       retroarch.cfg default), wrapping 2 or 3;
//    2. a RetroArch state container ("RASTATE" + version byte, then blocks);
//    3. raw core data (what the thin wrapper itself writes).
//
//  Pure: no I/O, no logging. The caller logs the detected format.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for `PVRetroArchStateDecoder` failures.
FOUNDATION_EXPORT NSErrorDomain const PVRetroArchStateDecoderErrorDomain;

typedef NS_ERROR_ENUM(PVRetroArchStateDecoderErrorDomain, PVRetroArchStateDecoderError) {
    /// rzip magic matched but the header is short or carries a zero/oversized size.
    PVRetroArchStateDecoderErrorMalformedRZIPHeader NS_SWIFT_NAME(malformedRZIPHeader) = 1,
    /// rzip magic matched but the format version byte is not one we know.
    PVRetroArchStateDecoderErrorUnsupportedRZIPVersion NS_SWIFT_NAME(unsupportedRZIPVersion) = 2,
    /// A chunk header or its payload runs past the end of the data, or the
    /// chunks end before the declared uncompressed size is reached.
    PVRetroArchStateDecoderErrorTruncatedRZIPChunk NS_SWIFT_NAME(truncatedRZIPChunk) = 3,
    /// zlib rejected a chunk, or a chunk inflated past the declared size.
    PVRetroArchStateDecoderErrorRZIPInflateFailed NS_SWIFT_NAME(rzipInflateFailed) = 4,
    /// "RASTATE" magic matched but the version byte is not one we know.
    PVRetroArchStateDecoderErrorUnsupportedRASTATEVersion NS_SWIFT_NAME(unsupportedRASTATEVersion) = 5,
    /// A RASTATE block header or payload runs past the end of the data.
    PVRetroArchStateDecoderErrorTruncatedRASTATEBlock NS_SWIFT_NAME(truncatedRASTATEBlock) = 6,
    /// The RASTATE container has no "MEM " block (no core data).
    PVRetroArchStateDecoderErrorMissingMEMBlock NS_SWIFT_NAME(missingMEMBlock) = 7,
};

/// What the input turned out to be.
typedef NS_ENUM(NSInteger, PVRetroArchStateFormat) {
    /// Raw core data (no container, no compression). Passed through unchanged.
    PVRetroArchStateFormatRaw NS_SWIFT_NAME(raw) = 0,
    /// Uncompressed RetroArch "RASTATE" container.
    PVRetroArchStateFormatRASTATE NS_SWIFT_NAME(rastate) = 1,
    /// rzip-compressed raw core data.
    PVRetroArchStateFormatRZIPRaw NS_SWIFT_NAME(rzipRaw) = 2,
    /// rzip-compressed "RASTATE" container.
    PVRetroArchStateFormatRZIPRASTATE NS_SWIFT_NAME(rzipRASTATE) = 3,
};

@interface PVRetroArchStateDecoder : NSObject

/// Hard cap on a decoded state (and on any single rzip chunk). Larger
/// declared sizes are rejected before anything is allocated.
@property (class, nonatomic, readonly) uint64_t maximumDecodedSize;

/// Returns the bytes to pass to `retro_unserialize`.
///
/// Raw input is returned as is (same object). Recognised input that fails to
/// decode returns nil with an error in `PVRetroArchStateDecoderErrorDomain`;
/// it is never passed through, since the container bytes would only corrupt
/// the core. `format` is set whenever the input was recognised, even on failure.
+ (nullable NSData *)coreDataFromStateData:(NSData *)data
                                    format:(nullable PVRetroArchStateFormat *)format
                                     error:(NSError **)error NS_SWIFT_NAME(coreData(from:format:));

/// True when `data` starts with the 8-byte rzip magic ("#RZIPv", version, "#")
/// for any version byte, and so would be treated as rzip.
+ (BOOL)isRZIPData:(NSData *)data NS_SWIFT_NAME(isRZIP(_:));

/// True when `data` starts with the 7-byte "RASTATE" magic (any version byte).
+ (BOOL)isRASTATEData:(NSData *)data NS_SWIFT_NAME(isRASTATE(_:));

/// Inflates an rzip stream. nil + error on any malformation.
+ (nullable NSData *)inflateRZIPData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(inflateRZIP(_:));

/// Returns the payload of the first "MEM " block of a RASTATE container
/// (unaligned size, as RetroArch passes it to the core). nil + error otherwise.
+ (nullable NSData *)memBlockFromRASTATEData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(memBlock(fromRASTATE:));

/// Short human-readable name for logs ("raw", "RASTATE", "rzip+raw", "rzip+RASTATE").
+ (NSString *)nameForFormat:(PVRetroArchStateFormat)format NS_SWIFT_NAME(name(for:));

@end

NS_ASSUME_NONNULL_END
