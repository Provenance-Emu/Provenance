//
//  PVGLViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <GLKit/GLKit.h>

@class PVEmulatorCore;

@interface PVGLViewController : GLKViewController

@property (nonatomic, weak) PVEmulatorCore *emulatorCore;

- (instancetype)initWithEmulatorCore:(PVEmulatorCore *)emulatorCore;

@end
