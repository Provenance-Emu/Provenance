//
//  PVLibretro.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PVSupport/PVSupport.h>
#import <PVSupport/PVSupport-Swift.h>
#import <PVLibRetro/libretro.h>
//#import <PVLibRetro/dynamic.h>

//#pragma clang diagnostic push
//#pragma clang diagnostic error "-Wall"

#define RETRO_API_VERSION 1

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

typedef struct retro_core_t retro_core_t;


@class PVLibRetroCore;
static __weak PVLibRetroCore *_current;

__attribute__((weak_import))
@interface PVLibRetroCore : PVEmulatorCore {
    @public
    unsigned short pitch_shift;
    
    uint32_t *videoBuffer;
    uint32_t *videoBufferA;
    uint32_t *videoBufferB;
    
    int16_t _pad[2][12];
    
    retro_core_t* core;

    // MARK: - Retro Structs
    unsigned                 core_poll_type;
    bool                     core_input_polled;
    bool                     core_has_set_input_descriptors;
    struct retro_system_av_info av_info;
    enum retro_pixel_format pix_fmt;
}
- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player;
- (void)pollControllers;

- (void *)getVariable:(const char *)variable;

@property (nonatomic, readonly) CGFloat videoWidth;
@property (nonatomic, readonly) CGFloat videoHeight;
@property (nonatomic, retain, nullable) NSString * romPath;

@end

#define SYMBOL(x) \
do { \
    function_t func = dylib_proc(lib_handle, #x); \
    memcpy(&current_core->x, &func, sizeof(func)); \
    if (current_core->x == NULL) { \
        ELOG(@"Failed to load symbol: \"%s\"\n", #x); \
        retroarch_fail(1, "init_libretro_sym()"); \
    } \
} while (0)

#define SYMBOL_DUMMY(x) current_core->x = libretro_dummy_##x

//#pragma clang diagnostic pop
