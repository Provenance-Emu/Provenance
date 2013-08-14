//
//  PVEmulatorViewController.h
//  Provenance
//
//  Created by James Addyman on 08/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <GLKit/GLKit.h>

@interface PVGLViewController : GLKViewController

@property (nonatomic, assign) uint16_t *videoBuffer;
@property (nonatomic, assign) NSTimeInterval frameInterval;
@property (nonatomic, assign) CGSize bufferSize;

@end
