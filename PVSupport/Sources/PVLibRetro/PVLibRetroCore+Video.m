//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibretro.h"

#import <PVSupport/PVSupport-Swift.h>

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include <dynamic/dylib.h>
#include <string/stdstring.h>

#include "command.h"
#include "core_info.h"

#include "managers/state_manager.h"
//#include "audio/audio_driver.h"
//#include "camera/camera_driver.h"
//#include "location/location_driver.h"
//#include "record/record_driver.h"
#include "core.h"
#include "runloop.h"
#include "performance_counters.h"
#include "system.h"
#include "record/record_driver.h"
//#include "queues/message_queue.h"
#include "gfx/video_driver.h"
#include "gfx/video_context_driver.h"
#include "gfx/scaler/scaler.h"
//#include "gfx/video_frame.h"

#include <retro_assert.h>

#include "cores/internal_cores.h"
#include "frontend/frontend_driver.h"
#include "content.h"
#ifdef HAVE_CHEEVOS
#include "cheevos.h"
#endif
#include "retroarch.h"
#include "configuration.h"
#include "general.h"
#include "msg_hash.h"
#include "verbosity.h"

char rotation_lut[4][32] =
{
   "Normal",
   "90 deg",
   "180 deg",
   "270 deg"
};

struct aspect_ratio_elem aspectratio_lut[ASPECT_RATIO_END] = {
   { "4:3",           1.3333f },
   { "16:9",          1.7778f },
   { "16:10",         1.6f },
   { "16:15",         16.0f / 15.0f },
   { "1:1",           1.0f },
   { "2:1",           2.0f },
   { "3:2",           1.5f },
   { "3:4",           0.75f },
   { "4:1",           4.0f },
   { "4:4",           1.0f },
   { "5:4",           1.25f },
   { "6:5",           1.2f },
   { "7:9",           0.7777f },
   { "8:3",           2.6666f },
   { "8:7",           1.1428f },
   { "19:12",         1.5833f },
   { "19:14",         1.3571f },
   { "30:17",         1.7647f },
   { "32:9",          3.5555f },
   { "Config",        0.0f },
   { "Square pixel",  1.0f },
   { "Core provided", 1.0f },
   { "Custom",        0.0f }
};

@implementation PVLibRetroCore (Audio)

# pragma mark - Video

- (NSTimeInterval)frameInterval {
    NSTimeInterval fps = av_info.timing.fps ?: 60;
    VLOG(@"%f", fps);
    return fps;
}

- (void)swapBuffers {
    if (videoBuffer == videoBufferA) {
        videoBuffer = videoBufferB;
    } else {
        videoBuffer = videoBufferA;
    }
}

-(BOOL)isDoubleBuffered {
    return YES;
}

- (CGFloat)videoWidth {
    return av_info.geometry.base_width;
}

- (CGFloat)videoHeight {
    return av_info.geometry.base_height;
}

- (const void *)videoBuffer {
    return videoBuffer;
}

- (CGRect)screenRect {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.base_height;
    unsigned width = av_info.geometry.base_width;

//    unsigned height = _videoHeight;
//    unsigned width = _videoWidth;
    
    return CGRectMake(0, 0, width, height);
}

- (CGSize)aspectSize {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    float aspect_ratio = av_info.geometry.aspect_ratio;
    //    unsigned height = av_info.geometry.max_height;
    //    unsigned width = av_info.geometry.max_width;
    if (aspect_ratio == 1.0) {
        return CGSizeMake(1, 1);
    } else if (aspect_ratio < 1.2 && aspect_ratio > 1.1) {
        return CGSizeMake(10, 9);
    } else if (aspect_ratio < 1.26 && aspect_ratio > 1.24) {
        return CGSizeMake(5, 4);
    } else if (aspect_ratio < 1.4 && aspect_ratio > 1.3) {
        return CGSizeMake(4, 3);
    } else if (aspect_ratio < 1.6 && aspect_ratio > 1.4) {
        return CGSizeMake(3, 2);
    } else if (aspect_ratio < 1.7 && aspect_ratio > 1.6) {
        return CGSizeMake(16, 9);
    } else {
        return CGSizeMake(4, 3);
    }
}

- (CGSize)bufferSize {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.max_height;
    unsigned width = av_info.geometry.max_width;
    
    return CGSizeMake(width, height);
}

- (GLenum)pixelFormat {
    switch (pix_fmt)
    {
       case RETRO_PIXEL_FORMAT_0RGB1555:
            return GL_RGB5_A1; // GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT
#if !TARGET_OS_MAC
       case RETRO_PIXEL_FORMAT_RGB565:
            return GL_RGB565;
#else
        case RETRO_PIXEL_FORMAT_RGB565:
             return GL_UNSIGNED_SHORT_5_6_5;
#endif
       case RETRO_PIXEL_FORMAT_XRGB8888:
            return GL_RGBA8; // GL_RGBA8
       default:
            return GL_RGBA;
    }
}

- (GLenum)internalPixelFormat {
    switch (pix_fmt)
    {
       case RETRO_PIXEL_FORMAT_0RGB1555:
            return GL_RGB5_A1;
#if !TARGET_OS_MAC
       case RETRO_PIXEL_FORMAT_RGB565:
            return GL_RGB565;
#else
        case RETRO_PIXEL_FORMAT_RGB565:
             return GL_UNSIGNED_SHORT_5_6_5;
#endif
       case RETRO_PIXEL_FORMAT_XRGB8888:
            return GL_RGBA8;
       default:
            return GL_RGBA;
    }

    return GL_RGBA;
}

- (GLenum)pixelType {
    // GL_UNSIGNED_SHORT_5_6_5
    // GL_UNSIGNED_BYTE
    return GL_UNSIGNED_SHORT;
}

@end
