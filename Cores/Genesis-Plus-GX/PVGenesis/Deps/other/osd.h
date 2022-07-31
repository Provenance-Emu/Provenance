/****************************************************************************
 *  osd.h
 *
 *  Genesis Plus GX libretro port
 *
 *  Copyright Eke-Eke (2007-2016)
 *
 *  Copyright Daniel De Matteis (2012-2016)
 *
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************************/

#ifndef _OSD_H
#define _OSD_H

#ifdef _MSC_VER
#include <stdio.h>
#define strncasecmp _strnicmp
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
//#include <streams/file_stream.h>
//#include <streams/file_stream_transforms.h>

#define MAX_INPUTS 8
#define MAX_KEYS 8
#define MAXPATHLEN 1024

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef M_PI
#define M_PI 3.1415926535897932385
#endif

#include "scrc32.h"

#define CHEATS_UPDATE() ROMCheatUpdate()

#define HAVE_NO_SPRITE_LIMIT
#define MAX_SPRITES_PER_LINE 80
#define TMS_MAX_SPRITES_PER_LINE (config.no_sprite_limit ? MAX_SPRITES_PER_LINE : 4)
#define MODE4_MAX_SPRITES_PER_LINE (config.no_sprite_limit ? MAX_SPRITES_PER_LINE : 8)
#define MODE5_MAX_SPRITES_PER_LINE (config.no_sprite_limit ? MAX_SPRITES_PER_LINE : (bitmap.viewport.w >> 4))
#define MODE5_MAX_SPRITE_PIXELS (config.no_sprite_limit ? MAX_SPRITES_PER_LINE * 32 : max_sprite_pixels)

typedef struct
{
  int8 device;
  uint8 port;
  uint8 padtype;
} t_input_config;

typedef struct
{
  char version[16];
  uint8 hq_fm;
  uint8 filter;
  uint8 hq_psg;
  uint8 ym2612;
  uint8 ym2413;
#ifdef HAVE_YM3438_CORE
  uint8 ym3438;
#endif
#ifdef HAVE_OPLL_CORE
  uint8 opll;
#endif
  uint8 mono;
  int16 psg_preamp;
  int16 fm_preamp;
  uint16 lp_range;
  int16 low_freq;
  int16 high_freq;
  int16 lg;
  int16 mg;
  int16 hg;
  uint8 system;
  uint8 region_detect;
  uint8 master_clock;
  uint8 vdp_mode;
  uint8 force_dtack;
  uint8 addr_error;
  uint8 bios;
  uint8 lock_on;
  uint8 overscan;
  uint8 aspect_ratio;
  uint8 ntsc;
  uint8 lcd;
  uint8 gg_extra;
  uint8 render;
  t_input_config input[MAX_INPUTS];
  uint8 invert_mouse;
  uint8 gun_cursor;
  uint32 overclock;
  uint8 no_sprite_limit;
} t_config;

t_config config; //extern t_config config;

extern char GG_ROM[256];
extern char AR_ROM[256];
extern char SK_ROM[256];
extern char SK_UPMEM[256];
extern char GG_BIOS[256];
extern char MD_BIOS[256];
extern char CD_BIOS_EU[256];
extern char CD_BIOS_US[256];
extern char CD_BIOS_JP[256];
extern char MS_BIOS_US[256];
extern char MS_BIOS_EU[256];
extern char MS_BIOS_JP[256];

extern void osd_input_update(void);
extern int load_archive(char *filename, unsigned char *buffer, int maxsize, char *extension);
extern void ROMCheatUpdate(void);

extern int16 soundbuffer[3068];

#ifndef cdStream
#define cdStream            RFILE
#define cdStreamOpen(fname) rfopen(fname, "rb")
#define cdStreamClose       rfclose
#define cdStreamRead        rfread
#define cdStreamSeek        rfseek
#define cdStreamTell        rftell
#define cdStreamGets        rfgets
#endif

#endif /* _OSD_H */
