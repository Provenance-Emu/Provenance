//
//  PVEmulatorCore.h
//  PVEmulatorCore
//
//  Created by Joseph Mattiello on 1/4/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for PVEmulatorCore.
FOUNDATION_EXPORT double PVEmulatorCoreVersionNumber;

//! Project version string for PVEmulatorCore.
FOUNDATION_EXPORT const unsigned char PVEmulatorCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVEmulatorCore/PublicHeader.h>

# pragma mark - Emulator Core
#import <PVEmulatorCoreObjC/EmulatorCore.h>
# pragma mark - Audio
#import <PVEmulatorCoreObjC/OEGameAudio.h>
# pragma mark - Video
#import <PVEmulatorCoreObjC/OEGeometry.h>
# pragma mark - Extensions
#import <PVEmulatorCoreObjC/NSObject+PVAbstractAdditions.h>
# pragma mark - Swift
#import <PVEmulatorCoreObjC/PVEmulatorCoreObjC-Swift.h>

//#import <PVEmulatorCoreSwift-Swift.h>
//#import <PVEmulatorCoreSwift/PVEmulatorCore-Swift.h>b
