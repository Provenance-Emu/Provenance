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
#include "libretro.h"

extern retro_environment_t environ_cb;
extern unsigned GPU_LR_FRAMEBUFFER_NATIVE_WIDTH;
extern unsigned GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT;

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

- (CGRect)screenRect {
    struct retro_variable var = { "desmume_screens_layout", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

    unsigned width = GPU_LR_FRAMEBUFFER_NATIVE_WIDTH;
    unsigned height = GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT;

    if (var.value) {
        if (strstr(var.value, "hybrid")) {
            return CGRectMake(0, 0, width + (width/3), height);
        } else if (strstr(var.value, "top only") || strstr(var.value, "bottom only")) {
            return CGRectMake(0, 0, width, height);
        } else if (strstr(var.value, "top/bottom") || strstr(var.value, "bottom/top")) {
            return CGRectMake(0, 0, width, height * 2);
        }
    }

    return CGRectMake(0, 0, width, height);
}

- (CGSize)bufferSize {
    struct retro_variable var = { "desmume_screens_layout", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

    /// Base dimensions for a single DS screen
    unsigned width = GPU_LR_FRAMEBUFFER_NATIVE_WIDTH;
    unsigned height = GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT;

    if (var.value) {
        if (strstr(var.value, "hybrid")) {
            /// Hybrid layout needs extra width for the small screen
            return CGSizeMake(width + (width/3), height);
        } else if (strstr(var.value, "top only") || strstr(var.value, "bottom only")) {
            /// Single screen layout
            return CGSizeMake(width, height);
        } else if (strstr(var.value, "top/bottom") || strstr(var.value, "bottom/top")) {
            /// Vertical layout
            return CGSizeMake(width, height * 2);
        }
    }

    /// Default to single screen size
    return CGSizeMake(width, height);
}

- (CGSize)aspectSize {
    struct retro_variable var = { "desmume_screens_layout", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

    if (var.value) {
        if (strstr(var.value, "top only") || strstr(var.value, "bottom only")) {
            return CGSizeMake(1, 1);  /// Square aspect for single screen
        } else if (strstr(var.value, "left/right") || strstr(var.value, "right/left")) {
            return CGSizeMake(2, 1);  /// 2:1 aspect for horizontal layout
        }
    }

    return CGSizeMake(1, 2);  /// Default 1:2 aspect for vertical layout
}

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

@end
