//
//  OpenGLES+Extensions.h
//  Provenance
//
//  Created by Joseph Mattiello on 6/12/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

@import Foundation;
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
@import OpenGL;
@import AppKit;
@import GLUT;
@import CoreImage;
@import OpenGL.IOSurface;
@import OpenGL.GL3;
@import OpenGL.OpenGLAvailability;
@import OpenGL.GL;
@import CoreVideo;
@import IOSurface;
#else
@import OpenGLES.EAGL;
@import OpenGLES.EAGLDrawable;
@import OpenGLES.EAGLIOSurface;
@import OpenGLES.ES3;
@import OpenGLES.gltypes;
@import IOSurface;
#endif

// Add SPI https://developer.apple.com/documentation/opengles/eaglcontext/2890259-teximageiosurface?language=objc
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
// TODO: This?
//        [CAOpenGLLayer layer];
//        CGLPixelFormatObj *pf;
//        CGLTexImageIOSurface2D(self.mEAGLContext, GL_TEXTURE_2D, GL_RGBA, width, height, GL_RGBA, GL_UNSIGNED_BYTE, backingIOSurface, 0)
#else
@interface EAGLContext()
- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface target:(NSUInteger)target internalFormat:(NSUInteger)internalFormat width:(uint32_t)width height:(uint32_t)height format:(NSUInteger)format type:(NSUInteger)type plane:(uint32_t)plane;
@end
#endif
