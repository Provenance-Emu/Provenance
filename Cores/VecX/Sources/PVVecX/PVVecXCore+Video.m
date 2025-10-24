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
#import <PVVecX/PVVecX-Swift.h>

#if !TARGET_OS_OSX
// OpenGL ES headers are managed by libretro common headers (rglgen_headers.h)
// Direct includes removed to avoid typedef conflicts with HAVE_OPENGLES3
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
    BOOL  rendersToOpenGL = [VecxOptions.useHardware isEqualToString:@"Hardware"];
    return rendersToOpenGL;
}
//
//- (BOOL)isDoubleBuffered {
//    return YES;
//}

- (const void *)videoBuffer {
    const void * videoBuffer = self.rendersToOpenGL ? NULL : [super videoBuffer];
    return videoBuffer;
}

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

//- (GLenum)pixelFormat {
//    return GL_RGB;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_SHORT_1_5_5_5_REV;
//}
//
//- (GLenum)internalPixelFormat {
//    // TODO: use struct retro_pixel_format var, set with, RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
//#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
//        return GL_RGB565;
//#else
//         return GL_UNSIGNED_SHORT_5_6_5;
//#endif
//}

//
//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
