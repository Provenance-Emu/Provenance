//
//  PVMelonDSCore.m
//  PVMelonDS
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVMelonDSCore.h"
#import "PVMelonDSCore+Controls.h"
#import "PVMelonDSCore+Audio.h"
#import "PVMelonDSCore+Video.h"

#import "PVMelonDS+Audio.h"

#import <Foundation/Foundation.h>

#import <PVLogging/PVLogging.h>

@import PVCoreBridge;

#pragma mark - PVMelonDSCore Begin
#import <dlfcn.h>
#import <errno.h>
#import <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>

@implementation PVMelonDSCoreBridge

- (instancetype)init {
	if (self = [super init]) {
        _current = self;
	}
	return self;
}


#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    #define V(x) strcmp(variable, x) == 0
    
    if (V("melonds_console_mode")) {
        // Console Mode; DS|DSi
        char * value = strdup("DS");
        return value;
    } else if (V("melonds_boot_directly")) {
        // Boot game directly; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_threaded_renderer")) {
        // Threaded software renderer; disabled|enabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_touch_mode")) {
        // disabled|Mouse|Touch|Joystick
        char * value = strdup("touch");
        return value;
    } else if (V("melonds_jit_enable")) {
        // JIT Enable (Restart); enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_jit_branch_optimisations")) {
        // JIT Branch optimisations; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_jit_literal_optimisations")) {
        // JIT Literal optimisations; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_jit_fast_memory")) {
        // JIT Fast memory; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_dsi_sdcard")) {
        // Enable DSi SD card; disabled|enabled
        char * value = strdup("disabled");
        return value;
    } else if (V("melonds_audio_bitrate")) {
        // Audio bitrate; Automatic|10-bit|16-bit
        char * value = strdup("16-bit");
        return value;
    } else if (V("melonds_audio_interpolation")) {
        // Audio Interpolation; None|Linear|Cosine|Cubic
        char * value = strdup("Cubic");
        return value;
    } else if (V("melonds_opengl_filtering")) {
        // "OpenGL filtering; nearest|linear"
        char * value = strdup("linear");
        return value;
    } else if (V("melonds_opengl_better_polygons")) {
        // OpenGL Improved polygon splitting; disabled|enabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_opengl_renderer")) {
        // OpenGL Renderer (Restart); disabled|enabled
        char * value = strdup("disabled");
        return value;
    } else if (V("melonds_hybrid_ratio")) {
        // Hybrid ratio (OpenGL only); 2|3
        char * value = strdup("3");
        return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
    
#undef V
    return NULL;
}

@end

