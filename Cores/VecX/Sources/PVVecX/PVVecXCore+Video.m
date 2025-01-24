//
//  PVVecX+Video.m
//  PVVecX
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVVecXCore+Video.h"
#import "PVVecXCore.h"
#import <PVLogging/PVLoggingObjC.h>

#if !TARGET_OS_OSX
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#import <GLKit/GLKit.h>
#endif

@implementation PVVecXCoreBridge (Video)

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
//
//	if (![self isEmulationPaused])
//	 {
//	 }
//        //dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//
//        //dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
//}
//
//- (void)executeFrame {
//    [self executeFrameSkippingFrame:NO];
//}

# pragma mark - Properties

//- (CGSize)bufferSize {
//    CGSize size = CGSizeMake(av_info.geometry.max_width, av_info.geometry.max_height);
//    DLOG(@"<%i, %i>", size.width, size.height);
//    return size;
//}
//
//- (CGRect)screenRect {
//    CGRect rect = CGRectMake(0, 0, av_info.geometry.base_width, av_info.geometry.base_height);
//    DLOG(@"<%i, %i>", rect.size.width, rect.size.height);
//    return rect;
//}
//
//- (CGSize)aspectSize {
//    CGSize size = CGSizeMake(1, av_info.geometry.aspect_ratio);
//    DLOG(@"<%i, %i>", size.width, size.height);
//    return size;
//}

- (BOOL)rendersToOpenGL {
#if HAS_GPU
    return YES;
#else
    return NO;
#endif
}
//
//- (BOOL)isDoubleBuffered {
//    return YES;
//}

//- (const void *)videoBuffer {
//    return NULL;
//}

/*
 memset(info, 0, sizeof(*info));
 info->timing.fps            = 50.0;
 info->timing.sample_rate    = 44100;
 info->geometry.base_width   = 330;
 info->geometry.base_height  = 410;
#if defined(_3DS) || defined(RETROFW)
 info->geometry.max_width    = 330;
 info->geometry.max_height   = 410;
#else
 info->geometry.max_width    = 2048;
 info->geometry.max_height   = 2048;
#endif

 info->geometry.aspect_ratio = 33.0 / 41.0;
 */

#if HAS_GPU
#else
- (GLenum)internalPixelFormat {
    return GL_RGB5_A1;
}

- (GLenum)pixelFormat {
    return GL_BGRA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_1_5_5_5_REV;
}
#endif
@end
