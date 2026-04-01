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

NS_ASSUME_NONNULL_BEGIN

__attribute__((weak_import))
@interface PVLibRetroGLESCoreBridge : PVLibRetroCoreBridge

/// Hardware rendering setup — called from environment callback
- (BOOL)setHardwareRenderCallback:(NSValue *_Nonnull)callbackValue;
- (void)setupHardwareContext:(enum retro_hw_context_type)contextType;
- (void)destroyHardwareContext;

/// Hardware rendering callbacks invoked by libretro
- (void)contextReset;
- (void)contextDestroy;
- (uintptr_t)getCurrentFramebuffer;
- (void *_Nullable)getProcAddress:(const char *_Nonnull)symbol;
- (BOOL)getHardwareRenderInterface:(const struct retro_hw_render_interface * _Nullable * _Nonnull)renderInterface;

/// GL context and FBO management for the emu thread
- (void)makeGLContextCurrent;
- (void)setupEmuThreadFBO;
- (void)destroyEmuThreadFBO;

@end

NS_ASSUME_NONNULL_END
