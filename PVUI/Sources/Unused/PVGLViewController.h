//
//  PVGLViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

@import Foundation;

#import "PVGPUViewController.h"

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface PVGLViewController : PVGPUViewController

@property (nonatomic, weak, nullable) PVEmulatorCore *emulatorCore;

#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;
@property (nonatomic, assign) NSInteger  framesPerSecond;
#endif

- (instancetype)initWithEmulatorCore:(PVEmulatorCore * _Nonnull)emulatorCore NS_DESIGNATED_INITIALIZER;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
