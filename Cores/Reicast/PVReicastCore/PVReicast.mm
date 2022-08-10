//
//  PVReicast.mm
//  PVReicast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVReicastCore.h"
#import "PVReicastCore+Controls.h"
#import "PVReicastCore+Video.h"
#import <PVSupport/PVSupport-Swift.h>

#import "PVReicast+Audio.h"

#include <stdio.h>

    // Reicast imports
#include "types.h"
#include "profiler/profiler.h"
#include "cfg/cfg.h"
#include "rend/rend.h"
#include "rend/TexCache.h"
#include "hw/maple/maple_devs.h"
#include "hw/maple/maple_if.h"
#include "hw/maple/maple_cfg.h"

#pragma mark - Reicast C++ interface
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <assert.h>
#include <poll.h>
#include <termios.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#include "hw/sh4/dyna/blockmanager.h"
#include <unistd.h>

void MakeCurrentThreadRealTime()
{
    [NSThread setRealTimePriority];
}

#pragma mark Debugging calls

int msgboxf(const wchar* text,unsigned int type,...)
{
    va_list args;

    wchar temp[2048];
    va_start(args, type);
    vsprintf(temp, text, args);
    va_end(args);

        //printf(NULL,temp,VER_SHORTNAME,type | MB_TASKMODAL);
    NSLog(@"%s", temp);
    return 0;
}

int darw_printf(const wchar* text,...) {
    va_list args;

    wchar temp[2048];
    va_start(args, text);
    vsprintf(temp, text, args);
    va_end(args);

    NSLog(@"%s", temp);

    return 0;
}

#pragma mark C Lifecycle calls
void os_DoEvents() {
    GET_CURRENT_OR_RETURN();
    [current videoInterrupt];
        ////
        ////    is_dupe = false;
        //    [current updateControllers];
        //
        //    if (settings.UpdateMode || settings.UpdateModeForced)
        //    {
        //        inside_loop = false;
        //        rend_end_render();
        //    }
}

u32  os_Push(void*, u32, bool) {
    return 1;
}

void os_SetWindowText(const char* t) {
    NSLog(@"WindowText: %s", t);
}

void os_CreateWindow() {

}

void os_SetupInput() {
    mcfg_CreateDevicesFromConfig();
}

void UpdateInputState(u32 port) {
    GET_CURRENT_OR_RETURN();
    [current pollControllers];
}

void UpdateVibration(u32 port, u32 value) {

}

int get_mic_data(unsigned char* ) {
    return 0;
}

void* libPvr_GetRenderTarget() {
    return 0;
}

void* libPvr_GetRenderSurface() {
    return 0;

}

bool gl_init(void*, void*) {
    return true;
}

void gl_term() {

}

void gl_swap() {
    GET_CURRENT_OR_RETURN();
    [current swapBuffers];
}
