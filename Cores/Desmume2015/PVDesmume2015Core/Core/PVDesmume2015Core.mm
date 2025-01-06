//
//  PVDesmume2015Core.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVDesmume2015Core.h"
#import "PVDesmume2015Core+Controls.h"
#import "PVDesmume2015Core+Audio.h"
#import "PVDesmume2015Core+Video.h"

#import "PVDesmume2015+Audio.h"

#import <Foundation/Foundation.h>
#import <PVLogging/PVLogging.h>

@import PVCoreBridge;

#pragma mark - PVDesmume2015Core Begin
#import <dlfcn.h>
#import <errno.h>
#import <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>


@implementation PVDesmume2015CoreBridge

- (instancetype)init {
	if (self = [super init]) {
        pitch_shift = 1;
        _current = self;
	}
	return self;
}

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);


    #define V(x) strcmp(variable, x) == 0

    if (V("desmume_cpu_mode")) {
            // interpreter|jit
        char * value = strdup("interpreter");
        return value;
    } else if (V("desmume_internal_resolution")) {
        // 256x192|512x384|768x576|1024x768|1280x960|1536x1152|1792x1344|2048x1536|2304x1728|2560x1920
        char * value = strdup("1024x768");
        return value;
    } else if (V("desmume_num_cores")) {
            // CPU cores; 1|2|3|4
        char * value = strdup("4");
        return value;
    } else if (V("desmume_pointer_type")) {
            // mouse|touch
            char * value = strdup("touch");
            return value;
    } else if (V("desmume_load_to_memory")) {
            // disabled|enabled
            char * value = strdup("enabled");
            return value;
    } else if (V("desmume_gfx_txthack")) {
            // disabled|enabled
            char * value = strdup("disabled");
            return value;
    } else if (V("desmume_mic_mode")) {
            // internal|sample|random|physical
            char * value = strdup("physical");
            return value;
    } else if (V("desmume_pointer_colour")) {
            // white|black|red|blue|yellow
            char * value = strdup("blue");
            return value;
    } else if (V("desmume_screens_layout")) {
            // top/bottom|bottom/top|left/right|right/left|top only|bottom only|quick switch|hybrid/top|hybrid/bottom
            char * value = strdup("top/bottom");
            return value;
    } else if (V("desmume_hybrid_showboth_screens")) {
            // Hybrid layout show both screens; enabled|disabled
            char * value = strdup("enabled");
            return value;
    } else if (V("desmume_hybrid_layout_scale")) {
            // 1|3
            char * value = strdup("1");
            return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return NULL;
    }

#undef V
    return NULL;
}

@end

