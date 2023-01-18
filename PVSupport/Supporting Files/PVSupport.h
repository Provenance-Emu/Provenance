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

// In this header, you should import all the public headers of your framework using statements like #import <PVSupport/PublicHeader.h>
//#if SWIFT_PACKAGE
//    #import <PVSupportObjC/DebugUtils.h>
//    #import <PVSupportObjC/PVEmulatorCore.h>
//    #import <PVSupportObjC/NSObject+PVAbstractAdditions.h>
//    #import <PVSupportObjC/NSFileManager+OEHashingAdditions.h>
//    #import <PVSupportObjC/PVLogging.h>
//    #import <PVSupportObjC/PVLogEntry.h>
//    #import <PVSupportObjC/PVProvenanceLogging.h>
//
//    # pragma mark - Audio
//    #import <PVSupportObjC/TPCircularBuffer.h>
//    #import <PVSupportObjC/OERingBuffer.h>
//    #import <PVSupportObjC/OEGameAudio.h>
//    #ifdef __cplusplus
//    #import <PVSupportObjC/CARingBuffer.h>
//    //#import <PVSupport/CAAtomic.h>
//    #import <PVSupportObjC/CAAudioTimeStamp.h>
//    #endif
//    #import <PVSupportObjC/OEGeometry.h>
//#else
    #import <PVSupport/DebugUtils.h>
    #import <PVSupport/PVEmulatorCore.h>
    #import <PVSupport/NSObject+PVAbstractAdditions.h>
    #import <PVSupport/NSFileManager+OEHashingAdditions.h>
    #import <PVLogging/PVLogging.h>

    # pragma mark - Audio
    #import <PVSupport/TPCircularBuffer.h>
    #import <PVSupport/OERingBuffer.h>
    #import <PVSupport/OEGameAudio.h>
    #ifdef __cplusplus
        #import <PVSupport/CARingBuffer.h>
        //#import <PVSupport/CAAtomic.h>
        #import <PVSupport/CAAudioTimeStamp.h>
    #endif
    #import <PVSupport/OEGeometry.h>
//#endif

