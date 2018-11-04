//
//  osx-main.cpp
//  emulator-osx
//
//  Created by admin on 8/5/15.
//  Copyright (c) 2015 reicast. All rights reserved.
//
#import <Carbon/Carbon.h>

#include "types.h"
#include "hw/maple/maple_cfg.h"
#include <sys/stat.h>

#include <OpenGL/gl3.h>

int msgboxf(const wchar* text,unsigned int type,...)
{
    va_list args;

    wchar temp[2048];
    va_start(args, type);
    vsprintf(temp, text, args);
    va_end(args);

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

u16 kcode[4] = { 0xFFFF };
u32 vks[4];
s8 joyx[4],joyy[4];
u8 rt[4],lt[4];

int get_mic_data(u8* buffer) { return 0; }
int push_vmu_screen(u8* buffer) { return 0; }

void os_SetWindowText(const char * text) {
    puts(text);
}

void os_DoEvents() {

}


void UpdateInputState(u32 port) {

}

void UpdateVibration(u32 port, u32 value) {

}

void os_CreateWindow() {

}

void os_SetupInput() {
	mcfg_CreateDevicesFromConfig();
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

int dc_init(int argc,wchar* argv[]);
void dc_run();
void dc_term();
void dc_stop();

bool has_init = false;
void* emuthread(void*) {
    settings.profile.run_counts=0;
    string home = (string)getenv("HOME");
    if(home.c_str())
    {
        home += "/.reicast";
        mkdir(home.c_str(), 0755); // create the directory if missing
        set_user_config_dir(home);
        set_user_data_dir(home);
    }
    else
    {
        set_user_config_dir(".");
        set_user_data_dir(".");
    }
    char* argv[] = { "reicast" };

    dc_init(1,argv);

    has_init = true;

    dc_run();

    has_init = false;

    dc_term();

    return 0;
}

extern "C" void emu_dc_stop()
{
    dc_stop();
}

pthread_t emu_thread;
extern "C" void emu_main() {
    pthread_create(&emu_thread, 0, &emuthread, 0);
}

extern int screen_width,screen_height;
bool rend_single_frame();
bool gles_init();

extern "C" int emu_single_frame(int w, int h) {
    if (!has_init)
        return true;
    screen_width = w;
    screen_height = h;
    return rend_single_frame();
}

extern "C" void emu_gles_init() {
    gles_init();
}

enum DCPad {
    Btn_C		= 1,
    Btn_B		= 1<<1,
    Btn_A		= 1<<2,
    Btn_Start	= 1<<3,
    DPad_Up		= 1<<4,
    DPad_Down	= 1<<5,
    DPad_Left	= 1<<6,
    DPad_Right	= 1<<7,
    Btn_Z		= 1<<8,
    Btn_Y		= 1<<9,
    Btn_X		= 1<<10,
    Btn_D		= 1<<11,
    DPad2_Up	= 1<<12,
    DPad2_Down	= 1<<13,
    DPad2_Left	= 1<<14,
    DPad2_Right	= 1<<15,

    Axis_LT= 0x10000,
    Axis_RT= 0x10001,
    Axis_X= 0x20000,
    Axis_Y= 0x20001,
};

void handle_key(int dckey, int state) {
    if (state)
        kcode[0] &= ~dckey;
    else
        kcode[0] |= dckey;
}

void handle_trig(u8* dckey, int state) {
    if (state)
        dckey[0] = 255;
    else
        dckey[0] = 0;
}

extern "C" void emu_key_input(char* keyt, int state) {
    int key = keyt[0];
    switch(key) {
        case 'z':     handle_key(Btn_X, state); break;
        case 'x':     handle_key(Btn_Y, state); break;
        case 'c':     handle_key(Btn_B, state); break;
        case 'v':     handle_key(Btn_A, state); break;

        case 'a':     handle_trig(lt, state); break;
        case 's':     handle_trig(rt, state); break;

        case 'j':     handle_key(DPad_Left, state); break;
        case 'k':     handle_key(DPad_Down, state); break;
        case 'l':     handle_key(DPad_Right, state); break;
        case 'i':     handle_key(DPad_Up, state); break;
        case 0xa:     handle_key(Btn_Start, state); break;
    }
}
