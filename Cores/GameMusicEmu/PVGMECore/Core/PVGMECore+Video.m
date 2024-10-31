//
//  PVGME+Video.m
//  PVGME
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVGMECore+Video.h"
#import "PVGMECore.h"
#import <PVLogging/PVLoggingObjC.h>

#if !__has_include(<OpenGL/OpenGL.h>)
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

@implementation PVGMECoreBridge (Video)

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

- (CGSize)bufferSize {
    CGSize size = CGSizeMake(av_info.geometry.max_width, av_info.geometry.max_height);
    DLOG(@"<%i, %i>", size.width, size.height);
    return size;
}

// 320,240
- (CGRect)screenRect {
    CGRect rect = CGRectMake(0, 0, av_info.geometry.base_width, av_info.geometry.base_height);
    DLOG(@"<%i, %i>", rect.size.width, rect.size.height);
    return rect;
}
//
//- (CGSize)aspectSize {
//    CGSize size = CGSizeMake(1, av_info.geometry.aspect_ratio);
//    DLOG(@"<%i, %i>", size.width, size.height);
//    return size;
//}

//- (BOOL)rendersToOpenGL {
//    return YES;
//}
//
//- (BOOL)isDoubleBuffered {
//    return YES;
//}

//- (const void *)videoBuffer {
//    return NULL;
//}

- (GLenum)pixelFormat {
    return GL_RGB565;
}

// 565, 2 bytes per pixel
- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT; // GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT_5_6_5
}

- (GLenum)internalPixelFormat {
    return GL_RGB565; // GL_RGB565
}

//
//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
