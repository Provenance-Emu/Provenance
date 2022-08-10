//
//  PVSupport Framework.h
//  PVSupport Framework
//
//  Created by Joseph Mattiello on 8/15/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_WATCH
#import <GameController/GameController.h>
#endif
#import <libkern/OSAtomic.h>
#import <string.h>

//! Project version number for PVSupport Framework.
FOUNDATION_EXPORT double PVSupport_FrameworkVersionNumber;

//! Project version string for PVSupport Framework.
FOUNDATION_EXPORT const unsigned char PVSupport_FrameworkVersionString[];

//#if SWIFT_PACKAGE
//#else
#import <PVSupport/DebugUtils.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/NSFileManager+OEHashingAdditions.h>
#import <PVSupport/PVLogging.h>
#import <PVSupport/PVProvenanceLogging.h>
#import <PVSupport/OEGeometry.h>

