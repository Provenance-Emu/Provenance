//
//  PVMetalViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

@import Foundation;
#import "PVGPUViewController.h"
@import MetalKit.MTKView;

@class PVEmulatorCore;

@interface PVMetalViewController : PVGPUViewController

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;
@property (nonatomic, strong) MTKView *mtlview;
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;
@property (nonatomic, assign) NSInteger  framesPerSecond;
#endif


- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
