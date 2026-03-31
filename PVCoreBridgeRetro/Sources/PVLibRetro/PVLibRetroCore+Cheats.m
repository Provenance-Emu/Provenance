//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVCoreBridgeRetro.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmacro-redefined"
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wdocumentation-unknown-command"
#pragma clang diagnostic ignored "-Wstrict-prototypes"

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include <dynamic/dylib.h>
#include <string/stdstring.h>
#include "core.h"

@implementation PVLibRetroCoreBridge (Cheats)

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
    [self setCheat:code setType:type setCodeType:type setIndex:0 setEnabled:enabled error:nil];
}

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error {
    if (!core) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSKeyValueValidationError userInfo:@{NSLocalizedDescriptionKey: @"Core is not initialised"}];
        }
        return NO;
    }
    const char* cCode = code ? [code cStringUsingEncoding:NSUTF8StringEncoding] : NULL;
    if (!cCode) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSKeyValueValidationError userInfo:@{NSLocalizedDescriptionKey: @"Cheat code must not be nil or non-UTF8"}];
        }
        return NO;
    }
    core->retro_cheat_set((unsigned)cheatIndex, enabled, cCode);
    return YES;
}

- (void)resetCheatCodes {
    if (core) {
        core->retro_cheat_reset();
    }
}

@end

#pragma clang diagnostic pop
