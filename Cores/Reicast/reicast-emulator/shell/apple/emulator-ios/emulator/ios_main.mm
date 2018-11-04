//
//  ios_main.m
//  emulator
//
//  Created by admin on 12/17/14.
//  Copyright (c) 2014 Karen Tsai (angelXwind). All rights reserved.
//

#import <Foundation/Foundation.h>

#include <assert.h>
#include <poll.h>
#include <termios.h>
//#include <curses.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#include "hw/sh4/dyna/blockmanager.h"
#include <unistd.h>
#include "hw/maple/maple_cfg.h"


int msgboxf(const wchar* text,unsigned int type,...)
{
    va_list args;

    wchar temp[2048];
    va_start(args, type);
    vsprintf(temp, text, args);
    va_end(args);

    //printf(NULL,temp,VER_SHORTNAME,type | MB_TASKMODAL);
    puts(temp);
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


void common_linux_setup();
int dc_init(int argc,wchar* argv[]);
void dc_run();

u16 kcode[4];
u32 vks[4];
s8 joyx[4],joyy[4];
u8 rt[4],lt[4];

extern "C" int reicast_main(int argc, wchar* argv[])
{
    //if (argc==2)
    //ndcid=atoi(argv[1]);

#if TARGET_OS_TV
    string homedir = [ [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] objectAtIndex:0] path] UTF8String];
#else
	string homedir = [ [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0] path] UTF8String];
#endif
    set_user_config_dir(homedir);
    set_user_data_dir(homedir);

    freopen( (homedir + "/log.txt").c_str(), "wb", stdout);

    printf("Config dir is: %s\n", get_writable_config_path("/").c_str());
    printf("Data dir is:   %s\n", get_writable_data_path("/").c_str());

    common_linux_setup();

    settings.profile.run_counts=0;

    dc_init(argc,argv);

    dc_run();

    return 0;
}

void os_DoEvents() {

}


u32  os_Push(void*, u32, bool) {
    return 1;
}

void os_SetWindowText(const char* t) {
    puts(t);
}

void os_CreateWindow() {

}

void os_SetupInput() {
	mcfg_CreateDevicesFromConfig();
}

void UpdateInputState(u32 port) {

}

void UpdateVibration(u32 port, u32 value) {

}

void get_mic_data(u8* ) {

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

}
