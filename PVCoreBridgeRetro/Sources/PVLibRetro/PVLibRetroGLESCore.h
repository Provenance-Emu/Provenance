//
//  PVLibRetroGLESCore.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PVCoreBridgeRetro/libretro.h>
#import <PVCoreBridgeRetro/PVLibRetroCore.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

/// Diagnostic push/pop are handled in the .m file, not here.

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

__attribute__((weak_import))
@interface PVLibRetroGLESCoreBridge : PVLibRetroCoreBridge

/// Hardware rendering setup — called from environment callback
- (BOOL)setHardwareRenderCallback:(NSValue *)callbackValue;
- (void)setupHardwareContext:(enum retro_hw_context_type)contextType;
- (void)destroyHardwareContext;

/// Hardware rendering callbacks invoked by libretro
- (void)contextReset;
- (void)contextDestroy;
- (uintptr_t)getCurrentFramebuffer;
- (void*)getProcAddress:(const char*)symbol;
- (BOOL)getHardwareRenderInterface:(const struct retro_hw_render_interface * _Nullable * _Nonnull)renderInterface;

/// GL context and FBO management for the emu thread
- (void)makeGLContextCurrent;
- (void)setupEmuThreadFBO;
- (void)destroyEmuThreadFBO;

// Touch and mouse input support
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
- (void)handleTouchEvent:(UIEvent *)event;
#else
- (void)handleMouseEvent:(NSEvent *)event;
#endif
- (int16_t)getPointerState:(unsigned)port device:(unsigned)device index:(unsigned)index id:(unsigned)id;

@end
