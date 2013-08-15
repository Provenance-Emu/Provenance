//
//  PVEmulatorViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <GLKit/GLKit.h>

@class PVGenesisEmulatorCore;

@interface PVGLViewController : GLKViewController

@property (nonatomic, strong) PVGenesisEmulatorCore *genesisCore;

- (instancetype)initWithGenesisCore:(PVGenesisEmulatorCore *)genesisCore;

@end
