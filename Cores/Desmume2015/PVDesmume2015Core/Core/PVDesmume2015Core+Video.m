//
//  PVDesmume2015+Video.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVDesmume2015Core+Video.h"
#import "PVDesmume2015Core.h"

#import <PVLogging/PVLoggingObjC.h>

#if !__has_include(<OpenGL/OpenGL.h>)
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif
@implementation PVDesmume2015CoreBridge (Video)

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

//- (CGSize)bufferSize {
//    CGSize size = CGSizeMake(av_info.geometry.max_width, av_info.geometry.max_height);
//    DLOG(@"<%i, %i>", size.width, size.height);
//    return size;
//}
//- (CGRect)screenRect {
//    CGRect rect = CGRectMake(0, 0, av_info.geometry.base_width, av_info.geometry.base_height);
//    DLOG(@"<%i, %i>", rect.size.width, rect.size.height * 2);
//    return rect;
//}

//- (CGSize)aspectSize {
//    CGSize size = CGSizeMake(1, av_info.geometry.aspect_ratio);
//    DLOG(@"<%i, %i>", size.width, size.height);
//    return size;
//}
//
- (CGSize)bufferSize {
    return CGSizeMake(2048, 2048);
}
////
/// 1024 / 1536
//- (CGRect)screenRect {
//    return CGRectMake(0, 0, 256, 512);
//}
////
- (CGSize)aspectSize {
    // DS dual screens: 256x192 each, stacked = 256x384 total
    // Correct aspect ratio: 256:384 = 2:3
    return CGSizeMake(2, 3);
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

#define USE_565 0

#if 0
// For reference @JoeMatt
 /* DataType */
 #define GL_BYTE                                          0x1400
 #define GL_UNSIGNED_BYTE                                 0x1401
 #define GL_SHORT                                         0x1402
 #define GL_UNSIGNED_SHORT                                0x1403
 #define GL_INT                                           0x1404
 #define GL_UNSIGNED_INT                                  0x1405
 #define GL_FLOAT                                         0x1406
 #define GL_FIXED                                         0x140C

 /* PixelFormat */
 #define GL_DEPTH_COMPONENT                               0x1902
 #define GL_ALPHA                                         0x1906
 #define GL_RGB                                           0x1907
 #define GL_RGBA                                          0x1908
 #define GL_LUMINANCE                                     0x1909
 #define GL_LUMINANCE_ALPHA                               0x190A

 /* PixelType */
 /*      GL_UNSIGNED_BYTE */
 #define GL_UNSIGNED_SHORT_4_4_4_4                        0x8033
 #define GL_UNSIGNED_SHORT_5_5_5_1                        0x8034
 #define GL_UNSIGNED_SHORT_5_6_5                          0x8363
#endif

- (GLenum)pixelFormat {
#if USE_565
    return GL_RGB;
#else
    return GL_RGBA;
//    return GL_RGB5_A1;
#endif
//    return GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT;
//    return GL_UNSIGNED_SHORT_1_5_5_5_REV;
}

- (GLenum)pixelType {
#if USE_565
    return GL_UNSIGNED_SHORT_5_6_5;
#else
    return GL_UNSIGNED_SHORT_5_5_5_1;
#endif
//    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    // TODO: use struct retro_pixel_format var, set with, RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
#if __has_include(<OpenGL/OpenGL.h>)
    return GL_UNSIGNED_SHORT_5_6_5;
#else
#if USE_565
    return GL_RGB565;
#else
    return GL_RGB5_A1; // GL_RGBA RETRO_PIXEL_FORMAT_0RGB1555
#endif
#endif
}

//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
