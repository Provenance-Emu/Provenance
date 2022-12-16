//
//  PVDolphin+Video.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Video.h"
#import "PVDolphinCore.h"

#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#include "DolHost.h"

@implementation PVDolphinCore (Video)

# pragma mark - Methods

- (void)videoInterrupt {
        //dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        //dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {

//	if (![self isEmulationPaused])
//	 {
//		 if(!dol_host->CoreRunning()) {
//		 dol_host->Pause(false);
//		 }
//
//	   dol_host->UpdateFrame();
//	 }
        //dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

        //dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

# pragma mark - Properties

- (CGSize)bufferSize {
    return CGSizeMake(1024, 512);
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
