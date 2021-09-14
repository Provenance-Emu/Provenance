//
//  PVSupport Framework.h
//  PVSupport Framework
//
//  Created by Joseph Mattiello on 8/15/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#import <libkern/OSAtomic.h>
#import <string.h>

//! Project version number for PVSupport Framework.
FOUNDATION_EXPORT double PVSupport_FrameworkVersionNumber;

//! Project version string for PVSupport Framework.
FOUNDATION_EXPORT const unsigned char PVSupport_FrameworkVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVSupport/PublicHeader.h>
#import <PVSupport/DebugUtils.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVGameControllerUtilities.h>
#import <PVSupport/NSObject+PVAbstractAdditions.h>
#import <PVSupport/NSFileManager+OEHashingAdditions.h>
#import <PVSupport/PVLogging.h>
#import <PVSupport/PVLogEntry.h>
#import <PVSupport/PVProvenanceLogging.h>

# pragma mark - Audio
#import <PVSupport/TPCircularBuffer.h>
#import <PVSupport/OERingBuffer.h>
#import <PVSupport/OEGameAudio.h>
#ifdef __cplusplus
#import <PVSupport/CARingBuffer.h>
//#import <PVSupport/CAAtomic.h>
#import <PVSupport/CAAudioTimeStamp.h>
#endif
