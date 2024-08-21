//
//  PVMednafenGameCoreC.h
//  PVMednafenGameCoreC
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for PVMednafenGameCoreC.
FOUNDATION_EXPORT double PVMednafenGameCoreCVersionNumber;

//! Project version string for PVMednafenGameCoreC.
FOUNDATION_EXPORT const unsigned char PVMednafenGameCoreCVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVMednafenGameCoreC/PublicHeader.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
#pragma clang diagnostic ignored "-Wextra"
#import <mednafen/mednafen.h>
#import <mednafen/settings-driver.h>
#import <mednafen/state-driver.h>
#import <mednafen/mednafen-driver.h>
#import <mednafen/MemoryStream.h>
#import <mednafen/mempatcher.h>

#pragma clang diagnostic pop
