//
//  PVGLViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

@import UIKit;

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
#define BaseViewController UIViewController
#else
@import GLKit;
#define BaseViewController GLKViewController
#endif
@class PVEmulatorCore;

@interface PVGLViewController : BaseViewController

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;
@property (nonatomic, assign) NSInteger  framesPerSecond;
#endif


- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
