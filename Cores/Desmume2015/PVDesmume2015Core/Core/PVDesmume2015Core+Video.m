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
extern int current_layout;
extern int hybrid_layout_scale;
extern unsigned scale;

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
    return CGRectMake(0, 0, self.bufferSize.width, self.bufferSize.height);
}

- (CGSize)bufferSize {
    /// Get current resolution
    struct retro_variable res = { "desmume_internal_resolution", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &res);

    /// Get current layout
    struct retro_variable layout = { "desmume_screens_layout", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &layout);

    /// Base dimensions for a single DS screen
    unsigned width = GPU_LR_FRAMEBUFFER_NATIVE_WIDTH;
    unsigned height = GPU_LR_FRAMEBUFFER_NATIVE_HEIGHT;

    CGSize size;
    /// Adjust dimensions based on layout
    if (layout.value) {
        if (strstr(layout.value, "hybrid")) {
            /// Hybrid layout needs extra width for the small screen
            int awidth = width/3;
            size = CGSizeMake(width + awidth, height);
        } else if (strstr(layout.value, "left/right") || strstr(layout.value, "right/left")) {
            /// Side by side layout - double width
            size = CGSizeMake(width * 2, height);
        } else if (strstr(layout.value, "top/bottom") || strstr(layout.value, "bottom/top")) {
            /// Vertical layout - double height
            size = CGSizeMake(width, height * 2);
        } else {
            /// Single screen layout
            size = CGSizeMake(width, height);
        }
    } else {
        size = CGSizeMake(width, height);
    }

    ILOG(@"Buffer size calculation:");
    ILOG(@"Layout: %s", layout.value ? layout.value : "default");
    ILOG(@"Resolution: %ux%u", width, height);
    ILOG(@"Final size: %.0fx%.0f", size.width, size.height);

    return size;
}

- (CGSize)aspectSize {
    struct retro_variable var = { "desmume_screens_layout", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

    CGSize aspect;
    if (var.value) {
        if (strstr(var.value, "left/right") || strstr(var.value, "right/left")) {
            aspect = CGSizeMake(2, 1);  /// 2:1 aspect for horizontal layout
        } else if (strstr(var.value, "top/bottom") || strstr(var.value, "bottom/top")) {
            aspect = CGSizeMake(1, 2);  /// 1:2 aspect for vertical layout
        } else if (strstr(var.value, "hybrid")) {
            aspect = CGSizeMake(4, 3);  /// 4:3 aspect for hybrid layout
        } else {
            aspect = CGSizeMake(1, 1);  /// Square aspect for single screen
        }
    } else {
        aspect = CGSizeMake(1, 1);
    }

    ILOG(@"Aspect size calculation:");
    ILOG(@"Layout: %s", var.value ? var.value : "default");
    ILOG(@"Aspect: %.0f:%.0f", aspect.width, aspect.height);

    return aspect;
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
