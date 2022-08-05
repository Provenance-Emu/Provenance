//
//  PVMelonDS+Video.m
//  PVMelonDS
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVMelonDSCore+Video.h"
#import "PVMelonDSCore.h"

#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

@implementation PVMelonDSCore (Video)

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
//    return CGRectMake(0, 0, self.videoWidth, self.videoHeight);
//}
//
//- (CGSize)aspectSize {
//    return CGSizeMake(256, 192);
//}
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

//- (GLenum)pixelFormat {
//    return GL_BGRA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_SHORT_5_6_5;
//}

//- (GLenum)pixelFormat {
//    return GL_RGBA;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_BGRA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_BYTE;
//}

//- (GLenum)internalPixelFormat {
//    // TODO: use struct retro_pixel_format var, set with, RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
//    return GL_BGRA;
//}

//- (GLenum)depthFormat {
//        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
//    return GL_DEPTH_COMPONENT24;
//}
@end
