//
//  PVMetalViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#ifdef __cplusplus
# import <Foundation/Foundation.h>
#else
@import Foundation;
#endif
#import <PVSupport/PVGPUViewController.h>

@class PVEmulatorCore;

@interface PVMetalViewController : PVGPUViewController

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;
@property (nonatomic, assign) NSInteger  framesPerSecond;
#endif


- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
