//
//  PVMednafen.h
//  PVMednafen
//
//  Created by Mattiello, Joseph R on 12/19/16.
//
//

#import <Foundation/Foundation.h>

//! Project version number for PVMednafen.
FOUNDATION_EXPORT double PVMednafenVersionNumber;

//! Project version string for PVMednafen.
FOUNDATION_EXPORT const unsigned char PVMednafenVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVMednafen/PublicHeader.h>
#import <PVMednafen/MednafenGameCore.h>

#if __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
#pragma clang diagnostic ignored "-Wextra"
//#include <mednafen/mednafen.h>
//#include <mednafen/settings-driver.h>
#include <mednafen/state-driver.h>
#include <mednafen/mednafen-driver.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/mempatcher.h>
#pragma clang diagnostic pop
#endif
