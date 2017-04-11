/*  Copyright 2003 Guillaume Duhamel
    Copyright 2004-2010 Lawrence Sebald

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include <stdio.h>
#include <time.h>
#include <arch/arch.h>
#include <dc/video.h>
#include <dc/biosfont.h>
#include <dc/maple.h>
#include <dc/maple/controller.h>
#include <kos/fs.h>

#include "../yui.h"
#include "../peripheral.h"
#include "../cs0.h"
#include "../m68kcore.h"
#include "../m68kc68k.h"
#include "perdc.h"
#include "viddc.h"
#include "sh2rec/sh2rec.h"

SH2Interface_struct *SH2CoreList[] = {
    &SH2Interpreter,
    &SH2Dynarec,
    NULL
};

PerInterface_struct *PERCoreList[] = {
    &PERDC,
    NULL
};

CDInterface *CDCoreList[] = {
    &ArchCD,
    &DummyCD,
    NULL
};

SoundInterface_struct *SNDCoreList[] = {
    &SNDDummy,
    NULL
};

VideoInterface_struct *VIDCoreList[] = {
    &VIDDummy,
    &VIDDC,
    NULL
};

M68K_struct * M68KCoreList[] = {
    &M68KDummy,
    &M68KC68K,
#ifdef HAVE_Q68
    &M68KQ68,
#endif
    NULL
};

static const char *bios = "/ram/saturn.bin";
static int emulate_bios = 0;

int YuiInit(int sh2core)   {
    yabauseinit_struct yinit;

    yinit.percoretype = PERCORE_DC;
    yinit.sh2coretype = sh2core;
    yinit.vidcoretype = VIDCORE_DC;
    yinit.m68kcoretype = M68KCORE_C68K;
    yinit.sndcoretype = SNDCORE_DUMMY;
    yinit.cdcoretype = CDCORE_ARCH;
    yinit.carttype = CART_NONE;
    yinit.regionid = REGION_AUTODETECT;
    yinit.biospath = emulate_bios ? NULL : bios;
    yinit.cdpath = NULL;
    yinit.buppath = NULL;
    yinit.mpegpath = NULL;
    yinit.cartpath = NULL;
    yinit.frameskip = 0;
    yinit.videoformattype = VIDEOFORMATTYPE_NTSC;
    yinit.clocksync = 0;
    yinit.basetime = 0;

    if(YabauseInit(&yinit) != 0)
      return -1;

    for(;;) {
        PERCore->HandleEvents();
    }

    return 0;
}

void YuiErrorMsg(const char *error_text)    {
    fprintf(stderr, "Error: %s\n", error_text);
    arch_exit();
}

void YuiSwapBuffers(void)   {
    /* Nothing here. */
}

int DoGui()  {
    struct coord    {
        int x;
        int y;
    };

    struct coord snowflakes[1024];
    int i;
    int offset;
    int start_pressed = 0;
    int phase = 0;
    int core = SH2CORE_INTERPRETER;

    srand(time(NULL));

    for(i = 0; i < 1024; ++i)    {
        snowflakes[i].x = (rand() % 640);
        snowflakes[i].y = -(rand() % 480);
    }

    while(!start_pressed)   {
        offset = 64 * 640 + 64; /* 64 pixels in from the left, 64 down */
        
        bfont_draw_str(vram_s + offset, 640, 0, "Yabause " VERSION);
        offset += 640 * 128;

        if(phase == 0)  {
            FILE *fp;

            fp = fopen("/cd/saturn.bin", "r");
            if(fp)  {
                fclose(fp);

                fs_copy("/cd/saturn.bin", bios);
                phase = 1;
                continue;
            }

            bfont_draw_str(vram_s + offset, 640, 0,
                           "Please insert a CD containing the Saturn BIOS");
            offset += 640 * 24;
            bfont_draw_str(vram_s + offset, 640, 0,
                           "on the root of the disc, named saturn.bin.");
            offset += 640 * 48;
            bfont_draw_str(vram_s + offset, 640, 0,
                           "Or, to use the BIOS emulation feature, insert");
            offset += 640 * 24;
            bfont_draw_str(vram_s + offset, 640, 0,
                           "a Sega Saturn CD and press Start.");
        }
        else    {
            bfont_draw_str(vram_s + offset, 640, 0,
                           "Please insert a Sega Saturn CD");
            offset += 640 * 24;
            bfont_draw_str(vram_s + offset, 640, 0, "and press start.");
        }

        for(i = 0; i < 1024; ++i)    {
            int dx = 1 - (rand() % 3);

            if(snowflakes[i].y >= 0)
                vram_s[640 * snowflakes[i].y + snowflakes[i].x] = 0x0000;

            snowflakes[i].x += dx;
            snowflakes[i].y += 1;

            if(snowflakes[i].x < 0)
                snowflakes[i].x = 639;
            else if(snowflakes[i].x > 639)
                snowflakes[i].x = 0;

            if(snowflakes[i].y > 479)
                snowflakes[i].y = 0;

            if(snowflakes[i].y >= 0)
                vram_s[640 * snowflakes[i].y + snowflakes[i].x] = 0xD555;
        }

        MAPLE_FOREACH_BEGIN(MAPLE_FUNC_CONTROLLER, cont_state_t, st)
            if(st->buttons & CONT_START)    {
                if(phase == 0)  {
                    emulate_bios = 1;
                }

                start_pressed = 1;
            }

            if(st->buttons & CONT_Y) {
                core = SH2CORE_DYNAREC;

                if(phase == 0)  {
                    emulate_bios = 1;
                }

                start_pressed = 1;
            }
        MAPLE_FOREACH_END()

        vid_waitvbl();
        vid_flip(1);
    }

    return core;
}

int main(int argc, char *argv[])    {
    int core;

    printf("...\n");

    bfont_set_encoding(BFONT_CODE_ISO8859_1);
    core = DoGui();
    YuiInit(core);

    return 0;
}
