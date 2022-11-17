//
//  PVDosBox+Video.m
//  PVDosBox
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDosBoxCore+Video.h"
#import "PVDosBoxCore.h"

#if !__has_include(<OpenGL/OpenGL.h>)
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

@implementation PVDosBoxCore (Video)

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

//- (GLenum)pixelFormat {
//    return GL_RGBA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_BYTE;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGBA;
//}
//
//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
