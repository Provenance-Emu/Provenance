//
//  PVLibretro.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PVSupport/PVSupport.h>
#import <PVSupport/PVSupport-Swift.h>

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

@class PVLibRetroCore;
static __weak PVLibRetroCore *_current;

__attribute__((weak_import))
@interface PVLibRetroCore : PVEmulatorCore {
}

@end

#pragma clang diagnostic pop
