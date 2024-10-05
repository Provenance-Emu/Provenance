//
//  PVLibRetro.h
//  PVLibRetro
//
//  Created by Joseph Mattiello on 5/14/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for PVLibRetro.
FOUNDATION_EXPORT double PVLibRetroVersionNumber;

//! Project version string for PVLibRetro.
FOUNDATION_EXPORT const unsigned char PVLibRetroVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVLibRetro/PublicHeader.h>

#import <PVLibRetro/PVLibRetroCoreBridge.h>
#import <PVLibRetro/PVLibRetroGLESCoreBridge.h>

#import <libretro/libretro.h>
#import <libretro/retro_inline.h>
