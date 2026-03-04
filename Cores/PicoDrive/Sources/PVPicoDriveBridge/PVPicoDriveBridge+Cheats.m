//
//  PVPicoDriveBridge+Cheats.m
//  PVCorePicoDrive
//
//  Created by Joseph Mattiello on 3/3/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

#import "PVPicoDriveBridge.h"
@import PVLoggingObjC;

// Forward-declare the libretro cheat API used by PicoDrive
void retro_cheat_reset(void);
void retro_cheat_set(unsigned index, bool enabled, const char *code);

@implementation PVPicoDriveBridge (Cheats)

#pragma mark - Cheats

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error {
    DLOG(@"PicoDrive setCheat: %@ type: %@ codeType: %@ index: %hhu enabled: %d",
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
    retro_cheat_set((unsigned)cheatIndex, (bool)enabled, cCode);
    return YES;
}

- (void)resetCheatCodes {
    DLOG(@"PicoDrive resetCheatCodes");
    retro_cheat_reset();
}

@end
