//
//  PVDesmume2015+Video.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVDesmume2015Core+Video.h"
#import "PVDesmume2015Core.h"

#if !__has_include(<OpenGL/OpenGL.h>)
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

extern unsigned GPU_LR_FRAMEBUFFER_NATIVE_WIDTH;
extern unsigned GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT;
extern unsigned scale;

@implementation PVDesmume2015Core (Video)

# pragma mark - Methods

//- (void)videoInterrupt {
//        //dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
//
//        //dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
//}
//
//- (void)swapBuffers {
//    [self.renderDelegate didRenderFrameOnAlternateThread];
//}
//
//- (void)executeFrameSkippingFrame:(BOOL)skip {
//        //dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//
//        //dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
//}
//
//- (void)executeFrame {
//    [self executeFrameSkippingFrame:NO];
//}

# pragma mark - Properties
//
//- (CGSize)bufferSize {
//    return CGSizeMake(1024, 512);
//}
//
//- (CGRect)screenRect {
//    return CGRectMake(0, 0, GPU_LR_FRAMEBUFFER_NATIVE_WIDTH * scale, GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT * scale);
//}
//
- (CGSize)aspectSize {
    return CGSizeMake(GPU_LR_FRAMEBUFFER_NATIVE_WIDTH, GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT);
}
//
//- (BOOL)rendersToOpenGL {
//    return YES;
//}
//
//- (void)swapBuffers
//{
//    if (bitmap.data == (uint8_t*)videoBufferA)
//    {
//        videoBuffer = videoBufferA;
//        bitmap.data = (uint8_t*)videoBufferB;
//    }
//    else
//    {
//        videoBuffer = videoBufferB;
//        bitmap.data = (uint8_t*)videoBufferA;
//    }
//}
//
//-(BOOL)isDoubleBuffered {
//    return YES;
//}

//- (const void *)videoBuffer {
//    return videoBuffer;
//}

- (GLenum)pixelFormat {
    return GL_RGB;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    // TODO: use struct retro_pixel_format var, set with, RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
#if __has_include(<OpenGL/OpenGL.h>)
    return GL_UNSIGNED_SHORT_5_6_5;
#else
    return GL_RGB565;
#endif
}

//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
