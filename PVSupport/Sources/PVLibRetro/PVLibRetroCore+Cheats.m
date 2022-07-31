//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibretro.h"

#import <PVSupport/PVSupport-Swift.h>

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include <dynamic/dylib.h>
#include <string/stdstring.h>
#include "core.h"

@implementation PVLibRetroCore (Cheats)

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
    unsigned index = 0;
    const char* cCode = [code cStringUsingEncoding:NSUTF8StringEncoding];
    core->retro_cheat_set(index, enabled, cCode);
    // void retro_cheat_reset(void) { }
    //    void retro_cheat_set(unsigned index, bool enabled, const char *code) { (void)index; (void)enabled; (void)code; }
}

@end
