//  PVEmuThree+Video.m
//  Copyright © 2023 Provenance. All rights reserved.

#import "PVEmuThreeCore+Video.h"
#import "PVEmuThreeCore.h"

#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

@implementation PVEmuThreeCore (Video)

# pragma mark - Methods
- (void)videoInterrupt {
}

- (void)swapBuffers {
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
}

- (void)executeFrame {
	[self executeFrameSkippingFrame:NO];
}

# pragma mark - Properties

- (CGSize)bufferSize {
	return CGSizeMake(0,0);
}

- (CGRect)screenRect {
	return CGRectMake(0, 0, self.videoWidth * self.resFactor , self.videoHeight * self.resFactor);
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
