//
//  PVFlycast.mm
//  PVFlycast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVFlycastCore.h"
#import "PVFlycastCore+Controls.h"
#import "PVFlycastCore+Video.h"

#import "PVFlycast+Audio.h"

#include <stdio.h>

    // Flycast imports
#include "types.h"
//#include "profiler/profiler.h"
#include "cfg/cfg.h"
//#include "rend/rend.h"
#include "rend/TexCache.h"
#include "hw/maple/maple_devs.h"
#include "hw/maple/maple_if.h"
#include "hw/maple/maple_cfg.h"

#pragma mark - Flycast C++ interface
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
//#include "hw/sh4/dyna/blockmanager.h"
#include <unistd.h>
#import <sys/types.h>

void move_pthread_to_realtime_scheduling_class(pthread_t pthread)
{
    mach_timebase_info_data_t timebase_info;
    mach_timebase_info(&timebase_info);

    const uint64_t NANOS_PER_MSEC = 1000000ULL;
    double clock2abs = ((double)timebase_info.denom / (double)timebase_info.numer) * NANOS_PER_MSEC;

    thread_time_constraint_policy_data_t policy;
    policy.period      = 0;
    policy.computation = (uint32_t)(5 * clock2abs); // 5 ms of work
    policy.constraint  = (uint32_t)(10 * clock2abs);
    policy.preemptible = FALSE;

    int kr = thread_policy_set(pthread_mach_thread_np(pthread_self()),
                               THREAD_TIME_CONSTRAINT_POLICY,
                               (thread_policy_t)&policy,
                               THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (kr != KERN_SUCCESS) {
        mach_error("thread_policy_set:", kr);
        exit(1);
    }
}

void MakeCurrentThreadRealTime()
{
    move_pthread_to_realtime_scheduling_class(pthread_self());
}

#pragma mark Debugging calls

//int msgboxf(const wchar* text,unsigned int type,...)
//{
////    va_list args;
////
////    wchar temp[2048];
////    va_start(args, type);
////    vsprintf(temp, text, args);
////    va_end(args);
////
////        //printf(NULL,temp,VER_SHORTNAME,type | MB_TASKMODAL);
////    NSLog(@"%s", temp);
//    return 0;
//}
//
//int darw_printf(const wchar* text,...) {
////    va_list args;
////
////    wchar temp[2048];
////    va_start(args, text);
////    vsprintf(temp, text, args);
////    va_end(args);
////
////    NSLog(@"%s", temp);
//
//    return 0;
//}

#pragma mark C Lifecycle calls
void os_DoEvents() {
    GET_CURRENT_OR_RETURN();
//    [current videoInterrupt];
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
//    mcfg_CreateDevicesFromConfig();
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

