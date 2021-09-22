//
//  PVGLViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

@import UIKit;
@import GLKit;

@class PVEmulatorCore;

@interface PVGLViewController : GLKViewController

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;
#if TARGET_OS_MACCATALYST
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;
@property (nonatomic, assign) NSInteger  framesPerSecond;
#endif


- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
