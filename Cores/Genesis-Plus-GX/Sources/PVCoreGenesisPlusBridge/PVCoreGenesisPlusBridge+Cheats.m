//
//  PVCoreGenesisPlusBridge+Cheats.m
//  PVCoreGenesisPlus
//
//  Created by Joseph Mattiello on 3/3/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

#import "PVCoreGenesisPlusBridge.h"
@import PVLoggingObjC;

// Forward-declare the libretro cheat API used by Genesis Plus GX
void retro_cheat_set(unsigned index, bool enabled, const char *code);

@implementation PVCoreGenesisPlusBridge (Cheats)

#pragma mark - Cheats

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error {
    DLOG(@"Genesis Plus GX setCheat: %@ type: %@ codeType: %@ index: %hhu enabled: %d",
          code, type, codeType, cheatIndex, enabled);

    const char *cCode = [code cStringUsingEncoding:NSUTF8StringEncoding];
    if (!cCode) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSFileWriteInapplicableStringEncodingError
                                     userInfo:@{NSLocalizedDescriptionKey: @"Cheat code could not be encoded as UTF-8"}];
        }
        return NO;
    }
    retro_cheat_set((unsigned)cheatIndex, enabled, cCode);
    return YES;
}

@end
