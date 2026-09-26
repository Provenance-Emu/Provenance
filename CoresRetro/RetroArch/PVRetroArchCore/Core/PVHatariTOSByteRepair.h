//
//  PVHatariTOSByteRepair.h
//  PVRetroArch
//
//  Byte-level TOS ROM patching for Atari ST / Hatari (thick RetroArch wrapper).
//
//  This is a workaround ("TOS hack") that rewrote the TOS header / word order
//  so Hatari would accept images with a byte-swapped load address. It stops
//  the boot crash but produces wrong colors, glitched video and broken input,
//  so it is DISABLED by default while the root cause is worked out with the
//  Hatari developers. See issue #2383 and spike #2823.
//
//  Build with PV_HATARI_TOS_BYTE_REPAIR=1 (GCC_PREPROCESSOR_DEFINITIONS) to
//  re-enable it for comparison testing.
//
//  Copyright © 2024 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef PV_HATARI_TOS_BYTE_REPAIR
#define PV_HATARI_TOS_BYTE_REPAIR 0
#endif

NS_ASSUME_NONNULL_BEGIN

@interface PVHatariTOSByteRepair : NSObject

/// YES only when built with PV_HATARI_TOS_BYTE_REPAIR=1.
@property (class, nonatomic, readonly, getter=isEnabled) BOOL enabled;

/// YES when *address* is a known byte-swapped form of a valid TOS load address
/// that the repair knows how to patch. Always NO when the repair is disabled.
+ (BOOL)isRepairableLoadAddress:(uint32_t)address;

/// Returns a patched copy of *data*, or nil when no patch applies or the repair
/// is disabled. *summary* receives a human-readable description of the patch.
+ (nullable NSData *)repairedDataForTOSData:(NSData *)data
                                    summary:(NSString *_Nullable *_Nullable)summary;

@end

NS_ASSUME_NONNULL_END
