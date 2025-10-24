//
//  PVRetroArch+Video.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Video.h"
@import PVCoreBridge;
@import PVCoreAudio;
@import PVAudio;
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

@implementation PVRetroArchCoreBridge (Video)

# pragma mark - Methods
- (void)videoInterrupt {}
- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}
- (void)executeFrame {}

# pragma mark - Properties
- (CGSize)bufferSize {
	return CGSizeMake(0,0);
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
@end
