//
//  PVGLViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

@import UIKit;
#if !TARGET_OS_MACCATALYST
@import GLKit;
#define BASE_CLASS
#else
@import Metal;
@import OpenGL;
@import GLUT;
#define BASE_CLASS UIViewController
#endif

@class PVEmulatorCore;

@interface PVGLViewController : BASE_CLASS

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;
#if TARGET_OS_MACCATALYST
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;
@property (nonatomic, assign) NSInteger  framesPerSecond;
#endif


- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
