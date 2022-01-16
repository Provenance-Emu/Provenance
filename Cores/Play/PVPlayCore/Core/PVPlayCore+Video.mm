//
//  PVPlay+Video.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore+Video.h"
#import "PVPlayCore.h"

#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

//#import "PS2VM.h"
//#import "gs/GSH_OpenGL/GSH_OpenGL.h"
//#import "PadHandler.h"
//#import "SoundHandler.h"
//#import "PS2VM_Preferences.h"
//#import "AppConfig.h"
//#import "StdStream.h"

@implementation PVPlayCore (Video)

# pragma mark - Methods


- (void)videoInterrupt {
        //dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        //dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
        //dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

        //dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

# pragma mark - Properties

- (CGSize)bufferSize {
    return CGSizeMake(640, 480);
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, self.videoWidth, self.videoHeight);
}

- (CGSize)aspectSize {
    return CGSizeMake(self.videoWidth, self.videoHeight);
}

- (BOOL)rendersToOpenGL {
    return YES;
}

- (BOOL)isDoubleBuffered {
    return YES;
}

- (const void *)videoBuffer {
    return NULL;
}

- (GLenum)pixelFormat {
    return GL_RGBA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

- (GLenum)depthFormat {
        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
    return GL_DEPTH_COMPONENT24;
}
@end

#pragma mark - Graphics callbacks

//static CGSHandler *GSHandlerFactory()
//{
//	return new CGSH_OpenEmu();
//}
//
//CGSHandler::FactoryFunction CGSH_OpenEmu::GetFactoryFunction()
//{
//	return GSHandlerFactory;
//}
//
//void CGSH_OpenEmu::InitializeImpl()
//{
//	GET_CURRENT_OR_RETURN();
//
//	[current.renderDelegate willRenderFrameOnAlternateThread];
//	CGSH_OpenGL::InitializeImpl();
//
//	this->m_presentFramebuffer = [current.renderDelegate.presentationFramebuffer intValue];
//
//	glClearColor(0,0,0,0);
//	glClear(GL_COLOR_BUFFER_BIT);
//}
//
//void CGSH_OpenEmu::PresentBackbuffer()
//{
//	GET_CURRENT_OR_RETURN();
//
//	[current.renderDelegate didRenderFrameOnAlternateThread];
//
//	// Start the next one.
//	[current.renderDelegate willRenderFrameOnAlternateThread];
//}

