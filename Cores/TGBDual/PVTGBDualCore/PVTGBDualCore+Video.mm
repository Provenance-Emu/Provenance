//
//  PVTGBDualCore+Video.mm
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualCore+Video.h"

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

#include "libretro.h"

#define TGBDUAL_PIXEL_TYPE       GL_UNSIGNED_SHORT_5_6_5
#define TGBDUAL_PIXEL_FORMAT     GL_RGB
#define TGBDUAL_INTERNAL_FORMAT  GL_RGB

@implementation PVTGBDualCore (Video)

- (void)executeFrameSkippingFrame:(BOOL)skip {
    retro_run();
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (CGSize)bufferSize {
    return CGSizeMake(160 * 2, 144);
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, self.videoWidth, self.videoHeight);
}

- (CGSize)aspectSize {
    return CGSizeMake(self.videoWidth, self.videoHeight);
}

-(BOOL)rendersToOpenGL {
    return NO;
}

- (const void *)videoBuffer {
    return _videoBuffer;
}

- (GLenum)pixelFormat {
    return TGBDUAL_PIXEL_FORMAT;
}

- (GLenum)pixelType {
    return TGBDUAL_PIXEL_TYPE;
}

- (GLenum)internalPixelFormat {
    return TGBDUAL_INTERNAL_FORMAT;
}

@end
