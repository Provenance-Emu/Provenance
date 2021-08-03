/****************************************************************************
 *  libretro.c
 *
 *  Genesis Plus GX libretro port
 *
 *  Copyright Eke-Eke (2007-2020)
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

#ifndef _MSC_VER
#include <stdbool.h>
#endif
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>

#ifdef _MSC_VER
#define snprintf _snprintf
#endif

#ifdef _XBOX1
#include <xtl.h>
#endif

#define RETRO_DEVICE_MDPAD_3B             RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 0)
#define RETRO_DEVICE_MDPAD_6B             RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 1)
#define RETRO_DEVICE_MSPAD_2B             RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 2)
#define RETRO_DEVICE_MDPAD_3B_WAYPLAY     RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 3)
#define RETRO_DEVICE_MDPAD_6B_WAYPLAY     RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 4)
#define RETRO_DEVICE_MDPAD_3B_TEAMPLAYER  RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 5)
#define RETRO_DEVICE_MDPAD_6B_TEAMPLAYER  RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 6)
#define RETRO_DEVICE_MSPAD_2B_MASTERTAP   RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_JOYPAD, 7)
#define RETRO_DEVICE_PADDLE               RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_ANALOG, 0)
#define RETRO_DEVICE_SPORTSPAD            RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_ANALOG, 1)
#define RETRO_DEVICE_XE_1AP               RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_ANALOG, 2)
#define RETRO_DEVICE_PHASER               RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_LIGHTGUN, 0)
#define RETRO_DEVICE_MENACER              RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_LIGHTGUN, 1)
#define RETRO_DEVICE_JUSTIFIERS           RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_LIGHTGUN, 2)
#define RETRO_DEVICE_GRAPHIC_BOARD        RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_POINTER, 0)

#include "libretro.h"
//#include <streams/file_stream.h>

#include "shared.h"
#include "md_ntsc.h"
#include "sms_ntsc.h"

#define STATIC_ASSERT(name, test) typedef struct { int assert_[(test)?1:-1]; } assert_ ## name ## _
#define M68K_MAX_CYCLES 1107
#define Z80_MAX_CYCLES 345
#define OVERCLOCK_FRAME_DELAY 100

#ifdef M68K_OVERCLOCK_SHIFT
#define HAVE_OVERCLOCK
STATIC_ASSERT(m68k_overflow,
              M68K_MAX_CYCLES <= UINT_MAX >> (M68K_OVERCLOCK_SHIFT + 1));
#endif

#ifdef Z80_OVERCLOCK_SHIFT
#ifndef HAVE_OVERCLOCK
#define HAVE_OVERCLOCK
#endif
STATIC_ASSERT(z80_overflow,
              Z80_MAX_CYCLES <= UINT_MAX >> (Z80_OVERCLOCK_SHIFT + 1));
#endif

sms_ntsc_t *sms_ntsc;
md_ntsc_t  *md_ntsc;

t_config config;

char GG_ROM[256];
char AR_ROM[256];
char SK_ROM[256];
char SK_UPMEM[256];
char MD_BIOS[256];
char GG_BIOS[256];
char MS_BIOS_EU[256];
char MS_BIOS_JP[256];
char MS_BIOS_US[256];
char CD_BIOS_EU[256];
char CD_BIOS_US[256];
char CD_BIOS_JP[256];
char CD_BRAM_JP[256];
char CD_BRAM_US[256];
char CD_BRAM_EU[256];
char CART_BRAM[256];

static int vwidth;
static int vheight;
static double vaspect_ratio;

static uint32_t brm_crc[2];
static uint8_t brm_format[0x40] =
{
  0x5f,0x5f,0x5f,0x5f,0x5f,0x5f,0x5f,0x5f,0x5f,0x5f,0x5f,0x00,0x00,0x00,0x00,0x40,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x53,0x45,0x47,0x41,0x5f,0x43,0x44,0x5f,0x52,0x4f,0x4d,0x00,0x01,0x00,0x00,0x00,
  0x52,0x41,0x4d,0x5f,0x43,0x41,0x52,0x54,0x52,0x49,0x44,0x47,0x45,0x5f,0x5f,0x5f
};

static bool is_running = 0;
static uint8_t temp[0x10000];
int16 soundbuffer[3068];
static uint32_t bitmap_data_[720 * 576];

static bool restart_eq = false;

static char g_rom_dir[256];
static char g_rom_name[256];
static void *g_rom_data;
static size_t g_rom_size;
static char *save_dir;

static retro_log_printf_t log_cb;
static retro_video_refresh_t video_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static retro_environment_t environ_cb;
static retro_audio_sample_batch_t audio_cb;

/* Cheat Support */
#define MAX_CHEATS (150)

typedef struct
{
 bool enable;
 uint16_t data;
 uint16_t old;
 uint32_t address;
 uint8_t *prev;
} CHEATENTRY;

static int maxcheats = 0;
static int maxROMcheats = 0;
static int maxRAMcheats = 0;

static CHEATENTRY cheatlist[MAX_CHEATS];
static uint8_t cheatIndexes[MAX_CHEATS];

static char ggvalidchars[] = "ABCDEFGHJKLMNPRSTVWXYZ0123456789";

static char arvalidchars[] = "0123456789ABCDEF";

/* Some games appear to calibrate music playback speed for PAL/NTSC by
   actually counting CPU cycles per frame during startup, resulting in
   hilariously fast music.  Delay overclocking for a while as a
   workaround */
#ifdef HAVE_OVERCLOCK
static uint32_t overclock_delay;
#endif

#define SOUND_FREQUENCY 44100

/* Hide the EQ settings for now */
/*#define HAVE_EQ*/

/************************************
 * Genesis Plus GX implementation
 ************************************/
#undef  CHUNKSIZE
#define CHUNKSIZE   (0x10000)

void error(char * fmt, ...)
{
   char buffer[256];
   va_list ap;
   va_start(ap, fmt);
   vsprintf(buffer, fmt, ap);
//   if (log_cb)
      fprintf(stderr, "%s\n", buffer);
   va_end(ap);
}

int load_archive(char *filename, unsigned char *buffer, int maxsize, char *extension)
{
  int64_t left = 0;
  int64_t size = 0;
  //  FILE *fd;

  /* Get filename extension */
  if (extension)
  {
    memcpy(extension, &filename[strlen(filename) - 3], 3);
    extension[3] = 0;
  }

  /* Check if this was called to load ROM file from the frontend (not BOOT ROM or Lock-On ROM files from the core) */
  if (maxsize >= 0x800000)
  {
    /* Check if loaded game is already in memory */
    if ((g_rom_data != NULL) && (g_rom_size > 0))
    {
      size = g_rom_size;
      if (size > maxsize)
        size = maxsize;
      memcpy(buffer, g_rom_data, size);
      return size;
    }
  }

  /* Open file */
  FILE *fd = fopen(filename, "rb");

  if (!fd)
  {
    /* Master System & Game Gear BIOS are optional files */
    if (!strcmp(filename,MS_BIOS_US) || !strcmp(filename,MS_BIOS_EU) || !strcmp(filename,MS_BIOS_JP) || !strcmp(filename,GG_BIOS))
    {
      return 0;
    }
  
    /* Mega CD BIOS are required files */
    if (!strcmp(filename,CD_BIOS_US) || !strcmp(filename,CD_BIOS_EU) || !strcmp(filename,CD_BIOS_JP)) 
    {
   //    if (log_cb)
          fprintf(stderr, "Unable to open CD BIOS: %s.\n", filename);
       return 0;
    }

  //  if (log_cb)
       fprintf(stderr, "Unable to open file.\n");
    return 0;
  }

  /* Get file size */
  fseek(fd, 0, SEEK_END);
  size = ftell(fd);

  /* size limit */
  if (size > MAXROMSIZE)
  {
    fclose(fd);
   
       fprintf(stderr, "File is too large.\n");
    return 0;
  }
  else if (size > maxsize)
    size = maxsize;

  
    fprintf(stderr, "INFORMATION - Loading %d bytes ...\n", size);

  /* Read into buffer */
  left = size;
  fseek(fd, 0, SEEK_SET);
  while (left > CHUNKSIZE)
  {
    fread(buffer, CHUNKSIZE, 1, fd);
    buffer += CHUNKSIZE;
    left -= CHUNKSIZE;
  }

  /* Read remaining bytes */
  fread(buffer, left, 1, fd);

  /* Close file */
  fclose(fd);

  /* Return loaded ROM size */
  return size;
}

static void RAMCheatUpdate(void);

void osd_input_update(void)
{
  int i, player = 0;
  unsigned int temp;

  input_poll_cb();

  /* Update RAM patches */
  RAMCheatUpdate();

  for (i = 0; i < MAX_INPUTS; i++)
  {
    temp = 0;
    switch (input.dev[i])
    {
      case DEVICE_PAD6B:
      {
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L))
          temp |= INPUT_X;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X))
          temp |= INPUT_Y;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R))
          temp |= INPUT_Z;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT))
          temp |= INPUT_MODE;
      }

      case DEVICE_PAD3B:
      {
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y))
          temp |= INPUT_A;
      }

      case DEVICE_PAD2B:
      {
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B))
          temp |= INPUT_B;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A))
          temp |= INPUT_C;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START))
          temp |= INPUT_START;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP))
          temp |= INPUT_UP;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN))
          temp |= INPUT_DOWN;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT))
          temp |= INPUT_LEFT;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT))
          temp |= INPUT_RIGHT;

        player++;
        break;
      }

      case DEVICE_MOUSE:
      {
        input.analog[i][0] = input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_X);
        if (config.invert_mouse)
          input.analog[i][1] = input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_Y);
        else
          input.analog[i][1] = -input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_Y);

        if (input.analog[i][0] < -255)
          input.analog[i][0] = -255;
        else if (input.analog[i][0] > 255)
          input.analog[i][0] = 255;
        if (input.analog[i][1] < -255)
          input.analog[i][1] = -255;
        else if (input.analog[i][1] > 255)
          input.analog[i][1] = 255;

        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_LEFT))
          temp |= INPUT_MOUSE_LEFT;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_RIGHT))
          temp |= INPUT_MOUSE_RIGHT;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_WHEELDOWN))
          temp |= INPUT_MOUSE_CENTER;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_MIDDLE))
          temp |= INPUT_START;

        player++;
        break;
      }

      case DEVICE_LIGHTGUN:
      {
        if ( input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_IS_OFFSCREEN) )
        {
           input.analog[i][0] = -1000;
           input.analog[i][1] = -1000;
        }
        else
        {
           input.analog[i][0] = ((input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X) + 0x7fff) * bitmap.viewport.w) / 0xfffe;
           input.analog[i][1] = ((input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y) + 0x7fff) * bitmap.viewport.h) / 0xfffe;
        }

        if (input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER))
          temp |= INPUT_A;
        if (input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_AUX_A))
          temp |= INPUT_B;
        if (input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_AUX_B))
          temp |= INPUT_C;
        if (input_state_cb(player, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_START))
          temp |= INPUT_START;

        player++;
        break;
      }

      case DEVICE_PADDLE:
      {
        input.analog[i][0] = (input_state_cb(player, RETRO_DEVICE_ANALOG, 0, RETRO_DEVICE_ID_ANALOG_X) + 0x8000) >> 8;

        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B))
          temp |= INPUT_BUTTON1;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START))
          temp |= INPUT_START;

        player++;
        break;
      }

      case DEVICE_SPORTSPAD:
      {
        input.analog[i][0] = (input_state_cb(player, RETRO_DEVICE_ANALOG, 0, RETRO_DEVICE_ID_ANALOG_X) + 0x8000) >> 8;
        input.analog[i][1] = (input_state_cb(player, RETRO_DEVICE_ANALOG, 0, RETRO_DEVICE_ID_ANALOG_Y) + 0x8000) >> 8;

        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B))
          temp |= INPUT_BUTTON1;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A))
          temp |= INPUT_BUTTON2;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START))
          temp |= INPUT_START;

        player++;
        break;
      }

      case DEVICE_PICO:
      {
        input.analog[i][0] = 0x03c + ((input_state_cb(player, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_X) + 0x7fff) * (0x17c-0x03c)) / 0xfffe;
        input.analog[i][1] = 0x1fc + ((input_state_cb(player, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_Y) + 0x7fff) * (0x2f7-0x1fc)) / 0xfffe;

        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_LEFT))
          temp |= INPUT_PICO_PEN;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_RIGHT))
          temp |= INPUT_PICO_RED;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_WHEELUP))
          pico_current = (pico_current - 1) & 7;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_WHEELDOWN))
          pico_current = (pico_current + 1) & 7;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP))
          temp |= INPUT_UP;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN))
          temp |= INPUT_DOWN;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT))
          temp |= INPUT_LEFT;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT))
          temp |= INPUT_RIGHT;

        player++;
        break;
      }

      case DEVICE_TEREBI:
      {
        input.analog[i][0] = ((input_state_cb(player, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_X) + 0x7fff) * 250) / 0xfffe;
        input.analog[i][1] = ((input_state_cb(player, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_Y) + 0x7fff) * 250) / 0xfffe;

        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_LEFT))
          temp |= INPUT_BUTTON1;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_MIDDLE))
          temp |= INPUT_START;

        player++;
        break;
      }

      case DEVICE_GRAPHIC_BOARD:
      {
        input.analog[i][0] = ((input_state_cb(player, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_X) + 0x7fff) * 255) / 0xfffe;
        input.analog[i][1] = ((input_state_cb(player, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_Y) + 0x7fff) * 255) / 0xfffe;

        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_LEFT))
          temp |= INPUT_GRAPHIC_PEN;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_MIDDLE))
          temp |= INPUT_GRAPHIC_DO;
        if (input_state_cb(player, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_RIGHT))
          temp |= INPUT_GRAPHIC_MENU;

        player++;
        break;
      }

      case DEVICE_XE_1AP:
      {
        int rx = input.analog[i][0] = input_state_cb(player, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X);
        int ry = input.analog[i][1] = input_state_cb(player, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_Y);
        if (abs(rx) > abs(ry))
        {
         input.analog[i+1][0] = (rx + 0x8000) >> 8;
        }
        else 
        {
         input.analog[i+1][0] = (0x7fff - ry) >> 8;
        }
        input.analog[i][0] = (input_state_cb(player, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X) + 0x8000) >> 8;
        input.analog[i][1] = (input_state_cb(player, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_Y) + 0x8000) >> 8;

        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R))
          temp |= INPUT_XE_A;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2))
          temp |= INPUT_XE_B;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L))
          temp |= INPUT_XE_C;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2))
          temp |= INPUT_XE_D;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y))
          temp |= INPUT_XE_E1;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B))
          temp |= INPUT_XE_E2;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT))
          temp |= INPUT_XE_SELECT;
        if (input_state_cb(player, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START))
          temp |= INPUT_XE_START;

        player++;
        break;
      }

      default:
        break;
    }

    input.pad[i] = temp;
  }
}

static void draw_cursor(int16_t x, int16_t y, uint8_t color)
{
   int i;

   /* crosshair center position */   
   uint8_t *ptr = (uint8_t *)bitmap.data + ((bitmap.viewport.y + y) * bitmap.width) + x + bitmap.viewport.x;

   /* default crosshair dimension */
   int x_start = x - 3;
   int x_end  = x + 3;
   int y_start = y - 3;
   int y_end = y + 3;

   /* off-screen? */
   if ( x < 0 && y < 0 )
      return;

   /* framebuffer limits */
   if (x_start < -bitmap.viewport.x) x_start = -bitmap.viewport.x;
   if (x_end >= (bitmap.viewport.w + bitmap.viewport.x)) x_end = bitmap.viewport.w + bitmap.viewport.x - 1;
   if (y_start < -bitmap.viewport.y) y_start = -bitmap.viewport.y;
   if (y_end >= (bitmap.viewport.h + bitmap.viewport.y)) y_end = bitmap.viewport.h + bitmap.viewport.y - 1;

   /* draw crosshair */
   for (i = (x_start - x); i <= (x_end - x); i++)
      ptr[i] = (i & 1) ? color : 0xffff;
   for (i = (y_start - y); i <= (y_end - y); i++)
      ptr[i * bitmap.width] = (i & 1) ? color : 0xffff;
}

static void init_bitmap(void)
{
   memset(&bitmap, 0, sizeof(bitmap));
   bitmap.width      = 720;
   bitmap.height     = 576;
   bitmap.pitch      = bitmap.width * sizeof(uint32_t);
   bitmap.data       = (uint8_t *)bitmap_data_;
}

static void config_default(void)
{
   int i;
   
   /* sound options */
   config.psg_preamp     = 150;
   config.fm_preamp      = 100;
   config.hq_fm          = 1; /* high-quality FM resampling (slower) */
   config.hq_psg         = 1; /* high-quality PSG resampling (slower) */
   config.filter         = 1; /* no filter */
   config.lp_range       = 0x8ccd; /* = 55% in 0.16 fixed point to match a Model1 VA2 US Genesis, was 0x7fff */
   config.low_freq       = 880;
   config.high_freq      = 5000;
   config.lg             = 100;
   config.mg             = 100;
   config.hg             = 100;
//   config.ym2612         = YM2612_DISCRETE;
   config.ym2413         = 2; /* AUTO */
   config.mono           = 0; /* STEREO output */
#ifdef HAVE_YM3438_CORE
   OPN2_SetChipType(ym3438_mode_ym2612);
   config.ym3438         = 1;
#endif
#ifdef HAVE_OPLL_CORE
   config.opll           = 1;
#endif

   /* system options */
   config.system         = 0; /* AUTO */
   config.region_detect  = 0; /* AUTO */
   config.vdp_mode       = 0; /* AUTO */
   config.master_clock   = 0; /* AUTO */
   config.force_dtack    = 0;
   config.addr_error     = 1;
   config.bios           = 0;
   config.lock_on        = 0;
   config.lcd            = 0; /* 0.8 fixed point */
#ifdef HAVE_OVERCLOCK
   config.overclock      = 100;
#endif
   config.no_sprite_limit = 0;

   /* video options */
   config.overscan = 0; /* 0 = no borders , 1 = vertical borders only, 2 = horizontal borders only, 3 = full borders */
   config.aspect_ratio = 0;
   config.gg_extra = 0; /* 1 = show extended Game Gear screen (256x192) */
   config.ntsc     = 0;
   config.lcd      = 0;
   config.render   = 0;

   /* input options */
   input.system[0] = SYSTEM_GAMEPAD;
   input.system[1] = SYSTEM_GAMEPAD;
   for (i=0; i<MAX_INPUTS; i++)
   {
     config.input[i].padtype = DEVICE_PAD2B | DEVICE_PAD3B | DEVICE_PAD6B;
   }
}

static void bram_load(void)
{
    FILE *fp;

    /* automatically load internal backup RAM */
    switch (region_code)
    {
       case REGION_JAPAN_NTSC:
          fp = fopen(CD_BRAM_JP, "rb");
          break;
       case REGION_EUROPE:
          fp = fopen(CD_BRAM_EU, "rb");
          break;
       case REGION_USA:
          fp = fopen(CD_BRAM_US, "rb");
          break;
       default:
          return;
    }

    if (fp != NULL)
    {
      fread(scd.bram, 0x2000, 1, fp);
      fclose(fp);

      /* update CRC */
      brm_crc[0] = crc32(0, scd.bram, 0x2000);
    }
    else
    {
      /* force internal backup RAM format (does not use previous region backup RAM) */
      scd.bram[0x1fff] = 0;
    }

    /* check if internal backup RAM is correctly formatted */
    if (memcmp(scd.bram + 0x2000 - 0x20, brm_format + 0x20, 0x20))
    {
      /* clear internal backup RAM */
      memset(scd.bram, 0x00, 0x2000 - 0x40);

      /* internal Backup RAM size fields */
      brm_format[0x10] = brm_format[0x12] = brm_format[0x14] = brm_format[0x16] = 0x00;
      brm_format[0x11] = brm_format[0x13] = brm_format[0x15] = brm_format[0x17] = (sizeof(scd.bram) / 64) - 3;

      /* format internal backup RAM */
      memcpy(scd.bram + 0x2000 - 0x40, brm_format, 0x40);

      /* clear CRC to force file saving (in case previous region backup RAM was also formatted) */
      brm_crc[0] = 0;
    }

    /* automatically load cartridge backup RAM (if enabled) */
    if (scd.cartridge.id)
    {
      fp = fopen(CART_BRAM, "rb");
      if (fp != NULL)
      {
        int filesize = scd.cartridge.mask + 1;
        int done = 0;
        
        /* Read into buffer (2k blocks) */
        while (filesize > CHUNKSIZE)
        {
          fread(scd.cartridge.area + done, CHUNKSIZE, 1, fp);
          done += CHUNKSIZE;
          filesize -= CHUNKSIZE;
        }

        /* Read remaining bytes */
        if (filesize)
        {
          fread(scd.cartridge.area + done, filesize, 1, fp);
        }

        /* close file */
        fclose(fp);

        /* update CRC */
        brm_crc[1] = crc32(0, scd.cartridge.area, scd.cartridge.mask + 1);
      }

      /* check if cartridge backup RAM is correctly formatted */
      if (memcmp(scd.cartridge.area + scd.cartridge.mask + 1 - 0x20, brm_format + 0x20, 0x20))
      {
        /* clear cartridge backup RAM */
        memset(scd.cartridge.area, 0x00, scd.cartridge.mask + 1);

        /* Cartridge Backup RAM size fields */
        brm_format[0x10] = brm_format[0x12] = brm_format[0x14] = brm_format[0x16] = (((scd.cartridge.mask + 1) / 64) - 3) >> 8;
        brm_format[0x11] = brm_format[0x13] = brm_format[0x15] = brm_format[0x17] = (((scd.cartridge.mask + 1) / 64) - 3) & 0xff;

        /* format cartridge backup RAM */
        memcpy(scd.cartridge.area + scd.cartridge.mask + 1 - 0x40, brm_format, 0x40);
      }
    }
}

static void bram_save(void)
{
    FILE *fp;

    /* verify that internal backup RAM has been modified */
    if (crc32(0, scd.bram, 0x2000) != brm_crc[0])
    {
      /* check if it is correctly formatted before saving */
      if (!memcmp(scd.bram + 0x2000 - 0x20, brm_format + 0x20, 0x20))
      {
        switch (region_code)
    {
        case REGION_JAPAN_NTSC:
            fp = fopen(CD_BRAM_JP, "wb");
            break;
        case REGION_EUROPE:
            fp = fopen(CD_BRAM_EU, "wb");
            break;
        case REGION_USA:
            fp = fopen(CD_BRAM_US, "wb");
            break;
        default:
                return;
    }
        if (fp != NULL)
        {
          fwrite(scd.bram, 0x2000, 1, fp);
          fclose(fp);

          /* update CRC */
          brm_crc[0] = crc32(0, scd.bram, 0x2000);
        }
      }
    }

    /* verify that cartridge backup RAM has been modified */
    if (scd.cartridge.id && (crc32(0, scd.cartridge.area, scd.cartridge.mask + 1) != brm_crc[1]))
    {
      /* check if it is correctly formatted before saving */
      if (!memcmp(scd.cartridge.area + scd.cartridge.mask + 1 - 0x20, brm_format + 0x20, 0x20))
      {
        fp = fopen(CART_BRAM, "wb");
        if (fp != NULL)
        {
          int filesize = scd.cartridge.mask + 1;
          int done = 0;
        
          /* Write to file (2k blocks) */
          while (filesize > CHUNKSIZE)
          {
            fwrite(scd.cartridge.area + done, CHUNKSIZE, 1, fp);
            done += CHUNKSIZE;
            filesize -= CHUNKSIZE;
          }

          /* Write remaining bytes */
          if (filesize)
          {
            fwrite(scd.cartridge.area + done, filesize, 1, fp);
          }

          /* Close file */
          fclose(fp);

          /* update CRC */
          brm_crc[1] = crc32(0, scd.cartridge.area, scd.cartridge.mask + 1);
        }
      }
    }
}


static void extract_name(char *buf, const char *path, size_t size)
{
   char *base = strrchr(path, '/');
   if (!base)
      base = strrchr(path, '\\');

   if (base)
   {
      snprintf(buf, size, "%s", base);
      base = strrchr(buf, '.');
      if (base)
         *base = '\0';
   }
   else
      buf[0] = '\0';
}

static void extract_directory(char *buf, const char *path, size_t size)
{
   char *base;
   strncpy(buf, path, size - 1);
   buf[size - 1] = '\0';

   base = strrchr(buf, '/');
   if (!base)
      base = strrchr(buf, '\\');

   if (base)
      *base = '\0';
   else
      buf[0] = '\0';
}

static double calculate_display_aspect_ratio(void)
{
   double videosamplerate, dotrate;
   bool is_h40 = false;
   if (config.aspect_ratio == 0)
   {
      if ((system_hw == SYSTEM_GG || system_hw == SYSTEM_GGMS) && config.overscan == 0 && config.gg_extra == 0)
         return (6.0 / 5.0) * ((double)vwidth / (double)vheight);
   }

   is_h40  = bitmap.viewport.w == 320; /* Could be read directly from the register as well. */
   dotrate = system_clock / (is_h40 ? 8.0 : 10.0);

   if (config.aspect_ratio == 1) /* Force NTSC PAR */
      videosamplerate = 135000000.0 / 11.0;
   else if (config.aspect_ratio == 2) /* Force PAL PAR */
      videosamplerate = 14750000.0;
   else
      videosamplerate = vdp_pal ? 14750000.0 : 135000000.0 / 11.0;

   return (videosamplerate / dotrate) * ((double)vwidth / ((double)vheight * 2.0));
}

static bool update_viewport(void)
{
  int ow = vwidth;
  int oh = vheight;
  double oar = vaspect_ratio;

  vwidth  = bitmap.viewport.w + (bitmap.viewport.x * 2);
  vheight = bitmap.viewport.h + (bitmap.viewport.y * 2);
  vaspect_ratio = calculate_display_aspect_ratio();

   if (config.ntsc)
   {
      if (reg[12] & 1)
         vwidth = MD_NTSC_OUT_WIDTH(vwidth);
      else
         vwidth = SMS_NTSC_OUT_WIDTH(vwidth);
   }

   if (config.render && interlaced)
   {
      vheight = vheight * 2;
   }
   return ((ow != vwidth) || (oh != vheight) || (oar != vaspect_ratio));
}

#ifdef HAVE_OVERCLOCK
static void update_overclock(void)
{
#ifdef M68K_OVERCLOCK_SHIFT
    m68k.cycle_ratio = 1 << M68K_OVERCLOCK_SHIFT;
#endif
#ifdef Z80_OVERCLOCK_SHIFT
    z80_cycle_ratio = 1 << Z80_OVERCLOCK_SHIFT;
#endif
    if (overclock_delay == 0)
    {
      /* Cycle ratios multiply per-instruction cycle counts, so use
         reciprocals */
#ifdef M68K_OVERCLOCK_SHIFT
      if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
        m68k.cycle_ratio = (100 << M68K_OVERCLOCK_SHIFT) / config.overclock;
#endif
#ifdef Z80_OVERCLOCK_SHIFT
      if ((system_hw & SYSTEM_PBC) != SYSTEM_MD)
        z80_cycle_ratio = (100 << Z80_OVERCLOCK_SHIFT) / config.overclock;
#endif
    }
}
#endif

//static void check_variables(void)
//{
//  unsigned orig_value;
//  struct retro_system_av_info info;
//  bool update_viewports = false;
//  bool reinit = false;
//  struct retro_variable var = {0};
//
//  var.key = "genesis_plus_gx_bram";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//#if defined(_WIN32)
//    char slash = '\\';
//#else
//    char slash = '/';
//#endif
//
//   if (!var.value || !strcmp(var.value, "per bios"))
//   {
//     snprintf(CD_BRAM_EU, sizeof(CD_BRAM_EU), "%s%cscd_E.brm", save_dir, slash);
//     snprintf(CD_BRAM_US, sizeof(CD_BRAM_US), "%s%cscd_U.brm", save_dir, slash);
//     snprintf(CD_BRAM_JP, sizeof(CD_BRAM_JP), "%s%cscd_J.brm", save_dir, slash);
//   }
//   else
//   {
//     snprintf(CD_BRAM_EU, sizeof(CD_BRAM_EU), "%s%c%s.brm", save_dir, slash, g_rom_name);
//     snprintf(CD_BRAM_US, sizeof(CD_BRAM_US), "%s%c%s.brm", save_dir, slash, g_rom_name);
//     snprintf(CD_BRAM_JP, sizeof(CD_BRAM_JP), "%s%c%s.brm", save_dir, slash, g_rom_name);
//   }
//  }
//
//  var.key = "genesis_plus_gx_system_hw";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.system;
//    if (var.value && !strcmp(var.value, "sg-1000"))
//      config.system = SYSTEM_SG;
//    else if (var.value && !strcmp(var.value, "sg-1000 II"))
//      config.system = SYSTEM_SGII;
//    else if (var.value && !strcmp(var.value, "mark-III"))
//      config.system = SYSTEM_MARKIII;
//    else if (var.value && !strcmp(var.value, "master system"))
//      config.system = SYSTEM_SMS;
//    else if (var.value && !strcmp(var.value, "master system II"))
//      config.system = SYSTEM_SMS2;
//    else if (var.value && !strcmp(var.value, "game gear"))
//      config.system = SYSTEM_GG;
//    else if (var.value && !strcmp(var.value, "mega drive / genesis"))
//      config.system = SYSTEM_MD;
//    else
//      config.system = 0;
//
//    if (orig_value != config.system)
//    {
//      if (system_hw)
//      {
//        switch (config.system)
//        {
//          case 0:
//            system_hw = romtype; /* AUTO */
//            break;
//
//          case SYSTEM_MD:
//            system_hw = (romtype & SYSTEM_MD) ? romtype : SYSTEM_PBC;
//            break;
//
//          case SYSTEM_GG:
//            system_hw = (romtype == SYSTEM_GG) ? SYSTEM_GG : SYSTEM_GGMS;
//            break;
//
//          default:
//            system_hw = config.system;
//            break;
//        }
//
//        reinit = true;
//      }
//    }
//  }
//
//  var.key = "genesis_plus_gx_bios";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.bios;
//    if (var.value && !strcmp(var.value, "enabled"))
//      config.bios = 3;
//    else
//      config.bios = 0;
//
//    if (orig_value != config.bios)
//    {
//      if (system_hw)
//      {
//        reinit = true;
//      }
//    }
//  }
//
//  var.key = "genesis_plus_gx_region_detect";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.region_detect;
//    if (var.value && !strcmp(var.value, "ntsc-u"))
//      config.region_detect = 1;
//    else if (var.value && !strcmp(var.value, "pal"))
//      config.region_detect = 2;
//    else if (var.value && !strcmp(var.value, "ntsc-j"))
//      config.region_detect = 3;
//    else
//      config.region_detect = 0;
//
//    if (orig_value != config.region_detect)
//    {
//      if (system_hw)
//      {
//        get_region(NULL);
//
//        if ((system_hw == SYSTEM_MCD) || ((system_hw & SYSTEM_SMS) && config.bios))
//        {
//          /* system with region BIOS should be reinitialized */
//          reinit = true;
//        }
//        else
//        {
//          static const uint16 vc_table[4][2] =
//          {
//            /* NTSC, PAL */
//            {0xDA , 0xF2},  /* Mode 4 (192 lines) */
//            {0xEA , 0x102}, /* Mode 5 (224 lines) */
//            {0xDA , 0xF2},  /* Mode 4 (192 lines) */
//            {0x106, 0x10A}  /* Mode 5 (240 lines) */
//          };
//
//          /* framerate might have changed, reinitialize audio timings */
//          audio_set_rate(44100, 0);
//
//          /* reinitialize I/O region register */
//          if (system_hw == SYSTEM_MD)
//          {
//            io_reg[0x00] = 0x20 | region_code | (config.bios & 1);
//          }
//          else if (system_hw == SYSTEM_MCD)
//          {
//            io_reg[0x00] = region_code | (config.bios & 1);
//          }
//          else
//          {
//            io_reg[0x00] = 0x80 | (region_code >> 1);
//          }
//
//          /* reinitialize VDP timings */
//          lines_per_frame = vdp_pal ? 313 : 262;
//
//          /* reinitialize NTSC/PAL mode in VDP status */
//          if (system_hw & SYSTEM_MD)
//          {
//            status = (status & ~1) | vdp_pal;
//          }
//
//          /* reinitialize VC max value */
//          switch (bitmap.viewport.h)
//          {
//            case 192:
//              vc_max = vc_table[0][vdp_pal];
//              break;
//            case 224:
//              vc_max = vc_table[1][vdp_pal];
//              break;
//            case 240:
//              vc_max = vc_table[3][vdp_pal];
//              break;
//          }
//
//          update_viewports = true;
//        }
//      }
//    }
//  }
//
//  var.key = "genesis_plus_gx_force_dtack";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "enabled"))
//      config.force_dtack = 1;
//    else
//      config.force_dtack = 0;
//  }
//
//  var.key = "genesis_plus_gx_addr_error";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "enabled"))
//      m68k.aerr_enabled = config.addr_error = 1;
//    else
//      m68k.aerr_enabled = config.addr_error = 0;
//  }
//
//  var.key = "genesis_plus_gx_lock_on";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.lock_on;
//    if (var.value && !strcmp(var.value, "game genie"))
//      config.lock_on = TYPE_GG;
//    else if (var.value && !strcmp(var.value, "action replay (pro)"))
//      config.lock_on = TYPE_AR;
//    else if (var.value && !strcmp(var.value, "sonic & knuckles"))
//      config.lock_on = TYPE_SK;
//    else
//      config.lock_on = 0;
//
//    if (orig_value != config.lock_on)
//    {
//      if (system_hw == SYSTEM_MD)
//        reinit = true;
//    }
//  }
//
//  var.key = "genesis_plus_gx_ym2413";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.ym2413;
//    if (var.value && !strcmp(var.value, "enabled"))
//      config.ym2413 = 1;
//    else if (var.value && !strcmp(var.value, "disabled"))
//      config.ym2413 = 0;
//    else
//      config.ym2413 = 2;
//
//    if (orig_value != config.ym2413)
//    {
//      if (system_hw && (config.ym2413 & 2) && ((system_hw & SYSTEM_PBC) != SYSTEM_MD))
//      {
//        memcpy(temp, sram.sram, sizeof(temp));
//        sms_cart_init();
//        memcpy(sram.sram, temp, sizeof(temp));
//      }
//    }
//  }
//
//#ifdef HAVE_OPLL_CORE
//  var.key = "genesis_plus_gx_ym2413_core";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.opll;
//    if (var.value && !strcmp(var.value, "nuked"))
//    {
//      config.opll = 1;
//    }
//    else
//    {
//      config.opll = 0;
//    }
//
//    if (((orig_value == 0) && (config.opll > 0)) || ((orig_value > 0) && (config.opll == 0)))
//    {
//      sound_init();
//      sound_reset();
//    }
//  }
//#endif
//
//  var.key = "genesis_plus_gx_sound_output";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (var.value && !strcmp(var.value, "mono"))
//      config.mono = 1;
//    else if (!var.value || !strcmp(var.value, "stereo"))
//      config.mono = 0;
//  }
//
//  var.key = "genesis_plus_gx_audio_filter";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (var.value && !strcmp(var.value, "low-pass"))
//      config.filter = 1;
//
//#if HAVE_EQ
//    else if (var.value && !strcmp(var.value, "EQ"))
//      config.filter = 2;
//#endif
//
//    else
//      config.filter = 0;
//  }
//
//  var.key = "genesis_plus_gx_lowpass_range";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    config.lp_range = (!var.value) ? 60 : ((atoi(var.value) * 65536) / 100);
//  }
//
//#if HAVE_EQ
//  var.key = "genesis_plus_gx_audio_eq_low";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    uint8_t new_lg = (!var.value) ? 100 : atoi(var.value);
//    if (new_lg != config.lg) restart_eq = true;
//    config.lg = new_lg;
//  }
//
//  var.key = "genesis_plus_gx_audio_eq_mid";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    uint8_t new_mg = (!var.value) ? 100 : atoi(var.value);
//    if (new_mg != config.mg) restart_eq = true;
//    config.mg = new_mg;
//  }
//
//  var.key = "genesis_plus_gx_audio_eq_high";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    uint8_t new_hg = (!var.value) ? 100 : atoi(var.value);
//    if (new_hg != config.hg) restart_eq = true;
//    config.hg = new_hg;
//
//  }
//#endif
//
//  var.key = "genesis_plus_gx_ym2612";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//#ifdef HAVE_YM3438_CORE
//    orig_value = config.ym3438;
//    if (var.value && !strcmp(var.value, "nuked (ym2612)"))
//    {
//      OPN2_SetChipType(ym3438_mode_ym2612);
//      config.ym3438 = 1;
//    }
//    else if (var.value && !strcmp(var.value, "nuked (ym3438)"))
//    {
//      OPN2_SetChipType(ym3438_mode_readmode);
//      config.ym3438 = 2;
//    }
//    else
//    {
//      config.ym3438 = 0;
//    }
//
//    if (((orig_value == 0) && (config.ym3438 > 0)) || ((orig_value > 0) && (config.ym3438 == 0)))
//    {
//      sound_init();
//      sound_reset();
//    }
//#endif
//
//    if (!var.value || !strcmp(var.value, "mame (ym2612)"))
//    {
//      config.ym2612 = YM2612_DISCRETE;
//      YM2612Config(YM2612_DISCRETE);
//    }
//    else if (var.value && !strcmp(var.value, "mame (asic ym3438)"))
//    {
//      config.ym2612 = YM2612_INTEGRATED;
//      YM2612Config(YM2612_INTEGRATED);
//    }
//    else
//    {
//      config.ym2612 = YM2612_ENHANCED;
//      YM2612Config(YM2612_ENHANCED);
//    }
//  }
//
//  var.key = "genesis_plus_gx_blargg_ntsc_filter";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.ntsc;
//
//    if (!var.value || !strcmp(var.value, "disabled"))
//      config.ntsc = 0;
//    else if (var.value && !strcmp(var.value, "monochrome"))
//    {
//      config.ntsc = 1;
//      sms_ntsc_init(sms_ntsc, &sms_ntsc_monochrome);
//      md_ntsc_init(md_ntsc,   &md_ntsc_monochrome);
//    }
//    else if (var.value && !strcmp(var.value, "composite"))
//    {
//      config.ntsc = 1;
//      sms_ntsc_init(sms_ntsc, &sms_ntsc_composite);
//      md_ntsc_init(md_ntsc,   &md_ntsc_composite);
//    }
//    else if (var.value && !strcmp(var.value, "svideo"))
//    {
//      config.ntsc = 1;
//      sms_ntsc_init(sms_ntsc, &sms_ntsc_svideo);
//      md_ntsc_init(md_ntsc,   &md_ntsc_svideo);
//    }
//    else if (var.value && !strcmp(var.value, "rgb"))
//    {
//      config.ntsc = 1;
//      sms_ntsc_init(sms_ntsc, &sms_ntsc_rgb);
//      md_ntsc_init(md_ntsc,   &md_ntsc_rgb);
//    }
//
//    if (orig_value != config.ntsc)
//      update_viewports = true;
//  }
//
//  var.key = "genesis_plus_gx_lcd_filter";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "disabled"))
//      config.lcd = 0;
//    else if (var.value && !strcmp(var.value, "enabled"))
//      config.lcd = (uint8)(0.80 * 256);
//  }
//
//  var.key = "genesis_plus_gx_overscan";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.overscan;
//    if (!var.value || !strcmp(var.value, "disabled"))
//        config.overscan = 0;
//    else if (var.value && !strcmp(var.value, "top/bottom"))
//      config.overscan = 1;
//    else if (var.value && !strcmp(var.value, "left/right"))
//      config.overscan = 2;
//    else if (var.value && !strcmp(var.value, "full"))
//      config.overscan = 3;
//    if (orig_value != config.overscan)
//      update_viewports = true;
//  }
//
//  var.key = "genesis_plus_gx_gg_extra";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.gg_extra;
//    if (!var.value || !strcmp(var.value, "disabled"))
//      config.gg_extra = 0;
//    else if (var.value && !strcmp(var.value, "enabled"))
//      config.gg_extra = 1;
//    if (orig_value != config.gg_extra)
//      update_viewports = true;
//  }
//
//  var.key = "genesis_plus_gx_aspect_ratio";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.aspect_ratio;
//    if (var.value && !strcmp(var.value, "NTSC PAR"))
//      config.aspect_ratio = 1;
//    else if (var.value && !strcmp(var.value, "PAL PAR"))
//      config.aspect_ratio = 2;
//    else
//      config.aspect_ratio = 0;
//    if (orig_value != config.aspect_ratio)
//      update_viewports = true;
//  }
//
//  var.key = "genesis_plus_gx_render";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    orig_value = config.render;
//    if (!var.value || !strcmp(var.value, "single field"))
//      config.render = 0;
//    else
//      config.render = 1;
//    if (orig_value != config.render)
//      update_viewports = true;
//  }
//
//  var.key = "genesis_plus_gx_gun_cursor";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "disabled"))
//      config.gun_cursor = 0;
//    else
//      config.gun_cursor = 1;
//  }
//
//  var.key = "genesis_plus_gx_invert_mouse";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "disabled"))
//      config.invert_mouse = 0;
//    else
//      config.invert_mouse = 1;
//  }
//
//#ifdef HAVE_OVERCLOCK
//  var.key = "genesis_plus_gx_overclock";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "100%"))
//      config.overclock = 100;
//    else if (var.value && !strcmp(var.value, "125%"))
//      config.overclock = 125;
//    else if (var.value && !strcmp(var.value, "150%"))
//      config.overclock = 150;
//    else if (var.value && !strcmp(var.value, "175%"))
//      config.overclock = 175;
//    else if (var.value && !strcmp(var.value, "200%"))
//      config.overclock = 200;
//
//    if (system_hw)
//      update_overclock();
//  }
//#endif
//
//  var.key = "genesis_plus_gx_no_sprite_limit";
//  environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
//  {
//    if (!var.value || !strcmp(var.value, "disabled"))
//      config.no_sprite_limit = 0;
//    else
//      config.no_sprite_limit = 1;
//  }
//
//  if (reinit) // uncommented overclock below 12152020
//  {
//#ifdef HAVE_OVERCLOCK
//    overclock_delay = OVERCLOCK_FRAME_DELAY;
//#endif
//    audio_init(SOUND_FREQUENCY, 0);
//    memcpy(temp, sram.sram, sizeof(temp));
//    system_init();
//    system_reset();
//    memcpy(sram.sram, temp, sizeof(temp));
//    update_viewports = true;
//  }
//
//  if (update_viewports)
//  {
//    bitmap.viewport.changed = 11;
//    if ((system_hw == SYSTEM_GG) && !config.gg_extra)
//      bitmap.viewport.x = (config.overscan & 2) ? 14 : -48;
//    else
//      bitmap.viewport.x = (config.overscan & 2) * 7;
//  }
//}

/* Cheat Support */
static uint32_t decode_cheat(char *string, int index)
{
   char *p;
   int i,n;
   uint32_t len = 0;
   uint32_t address = 0;
   uint16_t data = 0;
   uint8_t ref = 0;

   if ((system_hw & SYSTEM_PBC) == SYSTEM_MD){
      /*If system is Genesis-based*/

      /*Game-Genie*/
      if ((strlen(string) >= 9) && (string[4] == '-'))
      {
         for (i = 0; i < 8; i++)
         {
            if (i == 4) string++;
            p = strchr (ggvalidchars, *string++);
            if (p == NULL) return 0;
            n = p - ggvalidchars;
            switch (i)
            {
               case 0:
                  data |= n << 3;
                  break;
               case 1:
                  data |= n >> 2;
                  address |= (n & 3) << 14;
                  break;
               case 2:
                  address |= n << 9;
                  break;
               case 3:
                  address |= (n & 0xF) << 20 | (n >> 4) << 8;
                  break;
               case 4:
                  data |= (n & 1) << 12;
                  address |= (n >> 1) << 16;
                  break;
               case 5:
                  data |= (n & 1) << 15 | (n >> 1) << 8;
                  break;
               case 6:
                  data |= (n >> 3) << 13;
                  address |= (n & 7) << 5;
                  break;
               case 7:
                  address |= n;
                  break;
            }
         }
         /* code length */
         len = 9;
      }

      /*Patch and PAR*/
      else if ((strlen(string) >=9) && (string[6] == ':'))
      {
         /* decode 24-bit address */
         for (i=0; i<6; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            address |= (n << ((5 - i) * 4));
         }
         /* decode 16-bit data */
         string++;
         for (i=0; i<4; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) break;
            n = (p - arvalidchars) & 0xF;
            data |= (n << ((3 - i) * 4));
         }
         /* code length */
         len = 11;
      }
   } else {
      /*If System is Master-based*/

      /*Game Genie*/
      if ((strlen(string) >=7) && (string[3] == '-'))
      {
         /* decode 8-bit data */
         for (i=0; i<2; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            data |= (n << ((1 - i) * 4));
         }
         /* decode 16-bit address (low 12-bits) */
         for (i=0; i<3; i++)
         {
            if (i==1) string++; /* skip separator */
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            address |= (n << ((2 - i) * 4));
         }
         /* decode 16-bit address (high 4-bits) */
         p = strchr (arvalidchars, *string++);
         if (p == NULL) return 0;
         n = (p - arvalidchars) & 0xF;
         n ^= 0xF; /* bits inversion */
         address |= (n << 12);
         /* Optional: decode reference 8-bit data */
         if (*string=='-')
         {
            for (i=0; i<2; i++)
            {
               string++; /* skip separator and 2nd digit */
               p = strchr (arvalidchars, *string++);
               if (p == NULL) return 0;
               n = (p - arvalidchars) & 0xF;
               ref |= (n << ((1 - i) * 4));
            }
            ref = (ref >> 2) | ((ref & 0x03) << 6); /* 2-bit right rotation */
            ref ^= 0xBA; /* XOR */
            /* code length */
            len = 11;
         }
         else
         {
            /* code length */
            len = 7;
         }
      }

      /*Action Replay*/
      else if ((strlen(string) >=9) && (string[4] == '-')){
         string+=2;
         /* decode 16-bit address */
         for (i=0; i<4; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            address |= (n << ((3 - i) * 4));
            if (i==1) string++;
         }
         /* decode 8-bit data */
         for (i=0; i<2; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            data |= (n << ((1 - i) * 4));
         }
         /* code length */
         len = 9;
      }

      /*Fusion RAM*/
      else if ((strlen(string) >=7) && (string[4] == ':'))
      {
         /* decode 16-bit address */
         for (i=0; i<4; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            address |= (n << ((3 - i) * 4));
         }
         /* decode 8-bit data */
         string++;
         for (i=0; i<2; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            data |= (n << ((1 - i) * 4));
         }
         /* code length */
         len = 7;
      }

      /*Fusion ROM*/
      else if ((strlen(string) >=9) && (string[6] == ':'))
      {
         /* decode reference 8-bit data */
         for (i=0; i<2; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            ref |= (n << ((1 - i) * 4));
         }
         /* decode 16-bit address */
         for (i=0; i<4; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            address |= (n << ((3 - i) * 4));
         }
         /* decode 8-bit data */
         string++;
         for (i=0; i<2; i++)
         {
            p = strchr (arvalidchars, *string++);
            if (p == NULL) return 0;
            n = (p - arvalidchars) & 0xF;
            data |= (n << ((1 - i) * 4));
         }
         /* code length */
         len = 9;
      }
      /* convert to 24-bit Work RAM address */
      if (address >= 0xC000)
      {
         address = 0xFF0000 | (address & 0x1FFF);
      }
   }
   /* Valid code found ? */
   if (len)
   {
      /* update cheat address & data values */
      cheatlist[index].address = address;
      cheatlist[index].data = data;
      cheatlist[index].old = ref;
   }
   /* return code length (0 = invalid) */
   return len;
}

static void apply_cheats(void)
{
   uint8_t *ptr;
   int i;
   /* clear ROM&RAM patches counter */
   maxROMcheats = maxRAMcheats = 0;

   for (i = 0; i < maxcheats; i++)
   {
      if (cheatlist[i].enable)
      {
         if (cheatlist[i].address < cart.romsize)
         {
            if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
            {
               /* patch ROM data */
               cheatlist[i].old = *(uint16_t *)(cart.rom + (cheatlist[i].address & 0xFFFFFE));
               *(uint16_t *)(cart.rom + (cheatlist[i].address & 0xFFFFFE)) = cheatlist[i].data;
            }
            else
            {
               /* add ROM patch */
               maxROMcheats++;
               cheatIndexes[MAX_CHEATS - maxROMcheats] = i;
               /* get current banked ROM address */
               ptr = &z80_readmap[(cheatlist[i].address) >> 10][cheatlist[i].address & 0x03FF];
               /* check if reference matches original ROM data */
               if (((uint8_t)cheatlist[i].old) == *ptr)
               {
                  /* patch data */
                  *ptr = cheatlist[i].data;
                  /* save patched ROM address */
                  cheatlist[i].prev = ptr;
               }
               else
               {
                  /* no patched ROM address yet */
                  cheatlist[i].prev = NULL;
               }
            }
         }
         else if (cheatlist[i].address >= 0xFF0000)
         {
            /* add RAM patch */
            cheatIndexes[maxRAMcheats++] = i;
         }
      }
   }
}

static void clear_cheats(void)
{
   int i = maxcheats;
   /* disable cheats in reversed order in case the same address is used by multiple patches */
   while (i > 0)
   {
      if (cheatlist[i-1].enable)
      {
         if (cheatlist[i-1].address < cart.romsize)
         {
            if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
            {
               /* restore original ROM data */
               *(uint16_t *)(cart.rom + (cheatlist[i-1].address & 0xFFFFFE)) = cheatlist[i-1].old;
            }
            else
            {
               /* check if previous banked ROM address has been patched */
               if (cheatlist[i-1].prev != NULL)
               {
                  /* restore original data */
                  *cheatlist[i-1].prev = cheatlist[i-1].old;
                  /* no more patched ROM address */
                  cheatlist[i-1].prev = NULL;
               }
            }
         }
      }
      i--;
   }
}

/****************************************************************************
* RAMCheatUpdate
*
* Apply RAM patches (this should be called once per frame)
*
****************************************************************************/
static void RAMCheatUpdate(void)
{
   int index, cnt = maxRAMcheats;
   while (cnt)
   {
      /* get cheat index */
      index = cheatIndexes[--cnt];
      /* apply RAM patch */
      if (cheatlist[index].data & 0xFF00)
      {
         /* 16-bit patch */
         *(uint16_t *)(work_ram + (cheatlist[index].address & 0xFFFE)) = cheatlist[index].data;
      }
      else
      {
         /* 8-bit patch */
         work_ram[cheatlist[index].address & 0xFFFF] = cheatlist[index].data;
      }
   }
}

/****************************************************************************
 * ROMCheatUpdate
 *
 * Apply ROM patches (this should be called each time banking is changed)
 *
 ****************************************************************************/ 
void ROMCheatUpdate(void)
{
  int index, cnt = maxROMcheats;
  uint8_t *ptr;
  
  while (cnt)
  {
    /* get cheat index */
    index = cheatIndexes[MAX_CHEATS - cnt];

    /* check if previous banked ROM address was patched */
    if (cheatlist[index].prev != NULL)
    {
      /* restore original data */
      *cheatlist[index].prev = cheatlist[index].old;

      /* no more patched ROM address */
      cheatlist[index].prev = NULL;
    }

    /* get current banked ROM address */
    ptr = &z80_readmap[(cheatlist[index].address) >> 10][cheatlist[index].address & 0x03FF];

    /* check if reference exists and matches original ROM data */
    if (!cheatlist[index].old || ((uint8_t)cheatlist[index].old) == *ptr)
    {
      /* patch data */
      *ptr = cheatlist[index].data;

      /* save patched ROM address */
      cheatlist[index].prev = ptr;
    }

    /* next ROM patch */
    cnt--;
  }
}

/****************************************************************************
 * Disk control interface
 ****************************************************************************/ 
#define MAX_DISKS 4
static int disk_index;
static int disk_count;
static char *disk_info[MAX_DISKS];

static bool disk_set_eject_state(bool ejected)
{
  if (system_hw != SYSTEM_MCD)
    return false;

  if (ejected)
  {
    cdd.status = CD_OPEN;
    scd.regs[0x36>>1].byte.h = 0x01;
  }
  else if (cdd.status == CD_OPEN)
  {
    cdd.status = cdd.loaded ? CD_TOC : NO_DISC;
  }

  return true;
}

static bool disk_get_eject_state(void)
{
  if (system_hw != SYSTEM_MCD)
    return false;

  return (cdd.status == CD_OPEN);
}

static unsigned int disk_get_image_index(void)
{
  if ((system_hw != SYSTEM_MCD) || !cdd.loaded)
    return disk_count;

  return disk_index;
}

static bool disk_set_image_index(unsigned int index)
{
  char header[0x210];

  if (system_hw != SYSTEM_MCD)
    return false;

  if (index >= disk_count)
  {
    cdd.loaded = 0;
    return true;
  }

  if (disk_info[index] == NULL)
    return false;

  cdd_load(disk_info[index], header);

  if (!cdd.loaded)
    return false;

  disk_index = index;
  return true;
}

static unsigned int disk_get_num_images(void)
{
  return disk_count;
}

static bool disk_replace_image_index(unsigned index, const struct retro_game_info *info)
{
  if (system_hw != SYSTEM_MCD)
    return false;

  if (index >= disk_count)
    return false;

  if (disk_info[index] != NULL)
    free(disk_info[index]);

  disk_info[index] = NULL;

  if (info != NULL)
  {
    if (info->path == NULL)
      return false;

    disk_info[index] = strdup(info->path);

    if (index == disk_index)
      return disk_set_image_index(index);
  }
  else
  {
    int i = index;

    while (i < (disk_count-1))
    {
      disk_info[i]   = disk_info[i+1];
      disk_info[i+1] = NULL;
    }

    disk_count--;

    if (index < disk_index)
      disk_index--;
  }

  return true;
}

static bool disk_add_image_index(void)
{
  if (system_hw != SYSTEM_MCD)
    return false;

  if (disk_count >= MAX_DISKS)
    return false;

  disk_count++;
  return true;
}

static struct retro_disk_control_callback disk_ctrl =
{
  disk_set_eject_state,
  disk_get_eject_state,
  disk_get_image_index,
  disk_set_image_index,
  disk_get_num_images,
  disk_replace_image_index,
  disk_add_image_index
};

/************************************
 * libretro implementation
 ************************************/
unsigned retro_api_version(void) { return RETRO_API_VERSION; }

void retro_set_environment(retro_environment_t cb)
{
   struct retro_vfs_interface_info vfs_iface_info;
   static const struct retro_variable vars[] = {
      { "genesis_plus_gx_system_hw", "System hardware; auto|sg-1000|sg-1000 II|mark-III|master system|master system II|game gear|mega drive / genesis" },
      { "genesis_plus_gx_region_detect", "System region; auto|ntsc-u|pal|ntsc-j" },
      { "genesis_plus_gx_force_dtack", "System lockups; enabled|disabled" },
      { "genesis_plus_gx_bios", "System bootrom; disabled|enabled" },
      { "genesis_plus_gx_bram", "CD System BRAM; per bios|per game" },
      { "genesis_plus_gx_addr_error", "68k address error; enabled|disabled" },
      { "genesis_plus_gx_lock_on", "Cartridge lock-on; disabled|game genie|action replay (pro)|sonic & knuckles" },
      { "genesis_plus_gx_ym2413", "Master System FM (YM2413); auto|disabled|enabled" },
#ifdef HAVE_OPLL_CORE
      { "genesis_plus_gx_ym2413_core", "Master System FM (YM2413) core; mame|nuked" },
#endif
#ifdef HAVE_YM3438_CORE
      { "genesis_plus_gx_ym2612", "Mega Drive / Genesis FM; mame (ym2612)|mame (asic ym3438)|mame (enhanced ym3438)|nuked (ym2612)|nuked (ym3438)" },
#else
      { "genesis_plus_gx_ym2612", "Mega Drive / Genesis FM; mame (ym2612)|mame (asic ym3438)|mame (enhanced ym3438)" },
#endif

      { "genesis_plus_gx_sound_output", "Sound output; stereo|mono" },
      { "genesis_plus_gx_audio_filter", "Audio filter; disabled|low-pass" },
      { "genesis_plus_gx_lowpass_range", "Low-pass filter %; 60|65|70|75|80|85|90|95|5|10|15|20|25|30|35|40|45|50|55"},
      
      #if HAVE_EQ     
      { "genesis_plus_gx_audio_eq_low",  "EQ Low;  100|0|5|10|15|20|25|30|35|40|45|50|55|60|65|70|75|80|85|90|95" },
      { "genesis_plus_gx_audio_eq_mid",  "EQ Mid;  100|0|5|10|15|20|25|30|35|40|45|50|55|60|65|70|75|80|85|90|95" },
      { "genesis_plus_gx_audio_eq_high", "EQ High; 100|0|5|10|15|20|25|30|35|40|45|50|55|60|65|70|75|80|85|90|95" },
      #endif
      
      { "genesis_plus_gx_blargg_ntsc_filter", "Blargg NTSC filter; disabled|monochrome|composite|svideo|rgb" },
      { "genesis_plus_gx_lcd_filter", "LCD Ghosting filter; disabled|enabled" },
      { "genesis_plus_gx_overscan", "Borders; disabled|top/bottom|left/right|full" },
      { "genesis_plus_gx_gg_extra", "Game Gear extended screen; disabled|enabled" },
      { "genesis_plus_gx_aspect_ratio", "Core-provided aspect ratio; auto|NTSC PAR|PAL PAR" },
      { "genesis_plus_gx_render", "Interlaced mode 2 output; single field|double field" },
      { "genesis_plus_gx_gun_cursor", "Show Lightgun crosshair; disabled|enabled" },
      { "genesis_plus_gx_invert_mouse", "Invert Mouse Y-axis; disabled|enabled" },
#ifdef HAVE_OVERCLOCK
      { "genesis_plus_gx_overclock", "CPU speed; 100%|125%|150%|175%|200%" },
#endif
      { "genesis_plus_gx_no_sprite_limit", "Remove per-line sprite limit; disabled|enabled" },
      { NULL, NULL },
   };

   static const struct retro_controller_description port_1[] = {
      { "Joypad Auto", RETRO_DEVICE_JOYPAD },
      { "Joypad Port Empty", RETRO_DEVICE_NONE },
      { "MD Joypad 3 Button", RETRO_DEVICE_MDPAD_3B },
      { "MD Joypad 6 Button", RETRO_DEVICE_MDPAD_6B },
      { "MS Joypad 2 Button", RETRO_DEVICE_MSPAD_2B },
      { "MD Joypad 3 Button + 4-WayPlay", RETRO_DEVICE_MDPAD_3B_WAYPLAY },
      { "MD Joypad 6 Button + 4-WayPlay", RETRO_DEVICE_MDPAD_6B_WAYPLAY },
      { "MD Joypad 3 Button + Teamplayer", RETRO_DEVICE_MDPAD_3B_TEAMPLAYER },
      { "MD Joypad 6 Button + Teamplayer", RETRO_DEVICE_MDPAD_6B_TEAMPLAYER },
      { "MS Joypad 2 Button + Master Tap", RETRO_DEVICE_MSPAD_2B_MASTERTAP },
      { "MS Light Phaser", RETRO_DEVICE_PHASER },
      { "MS Paddle Control", RETRO_DEVICE_PADDLE },
      { "MS Sports Pad", RETRO_DEVICE_SPORTSPAD },
      { "MS Graphic Board", RETRO_DEVICE_GRAPHIC_BOARD },
      { "MD XE-1AP", RETRO_DEVICE_XE_1AP },
      { "MD Mouse", RETRO_DEVICE_MOUSE },
   };

   static const struct retro_controller_description port_2[] = {
      { "Joypad Auto", RETRO_DEVICE_JOYPAD },
      { "Joypad Port Empty", RETRO_DEVICE_NONE },
      { "MD Joypad 3 Button", RETRO_DEVICE_MDPAD_3B },
      { "MD Joypad 6 Button", RETRO_DEVICE_MDPAD_6B },
      { "MS Joypad 2 Button", RETRO_DEVICE_MSPAD_2B },
      { "MD Joypad 3 Button + 4-WayPlay", RETRO_DEVICE_MDPAD_3B_WAYPLAY },
      { "MD Joypad 6 Button + 4-WayPlay", RETRO_DEVICE_MDPAD_6B_WAYPLAY },
      { "MD Joypad 3 Button + Teamplayer", RETRO_DEVICE_MDPAD_3B_TEAMPLAYER },
      { "MD Joypad 6 Button + Teamplayer", RETRO_DEVICE_MDPAD_6B_TEAMPLAYER },
      { "MS Joypad 2 Button + Master Tap", RETRO_DEVICE_MSPAD_2B_MASTERTAP },
      { "MD Menacer", RETRO_DEVICE_MENACER },
      { "MD Justifiers", RETRO_DEVICE_JUSTIFIERS },
      { "MS Light Phaser", RETRO_DEVICE_PHASER },
      { "MS Paddle Control", RETRO_DEVICE_PADDLE },
      { "MS Sports Pad", RETRO_DEVICE_SPORTSPAD },
      { "MS Graphic Board", RETRO_DEVICE_GRAPHIC_BOARD },
      { "MD XE-1AP", RETRO_DEVICE_XE_1AP },
      { "MD Mouse", RETRO_DEVICE_MOUSE },
  };

   static const struct retro_controller_info ports[] = {
      { port_1, 16 },
      { port_2, 18 },
      { 0 },
   };

   static const struct retro_input_descriptor desc[] = {
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 4, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 5, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 6, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "C" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "A" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "X" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Z" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Mode" },
      { 7, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" },

      { 0 },
   };

   environ_cb = cb;
   cb(RETRO_ENVIRONMENT_SET_VARIABLES, (void*)vars);
   cb(RETRO_ENVIRONMENT_SET_CONTROLLER_INFO, (void*)ports);
   cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, (void*)desc);

   vfs_iface_info.required_interface_version = 1;
   vfs_iface_info.iface                      = NULL;
//   if (environ_cb(RETRO_ENVIRONMENT_GET_VFS_INTERFACE, &vfs_iface_info))
//	   filestream_vfs_init(&vfs_iface_info);

}

void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) { (void)cb; }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }
void retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }


void retro_get_system_info(struct retro_system_info *info)
{
   info->library_name = "Genesis Plus GX";
#ifndef GIT_VERSION
#define GIT_VERSION "58758aef3d8e12189899d67344db3b95c6379561"
#endif
   info->library_version = "v1.7.4" GIT_VERSION;
   info->valid_extensions = "m3u|mdx|md|smd|gen|bin|cue|iso|chd|sms|gg|sg";
   info->block_extract = false;
   info->need_fullpath = true;
}

void retro_get_system_av_info(struct retro_system_av_info *info)
{
   info->geometry.base_width    = vwidth;
   info->geometry.base_height   = bitmap.viewport.h + (2 * bitmap.viewport.y);
   info->geometry.max_width     = 720;
   info->geometry.max_height    = 576;
   info->geometry.aspect_ratio  = vaspect_ratio;
   info->timing.fps             = (double)(system_clock) / (double)lines_per_frame / (double)MCYCLES_PER_LINE;
   info->timing.sample_rate     = SOUND_FREQUENCY;
}

void retro_set_controller_port_device(unsigned port, unsigned device)
{
   (void)port;
   (void)device;
}

size_t retro_serialize_size(void) { return STATE_SIZE; }

bool retro_serialize(void *data, size_t size)
{ 
   if (size != STATE_SIZE)
      return FALSE;

   state_save(data);

   return TRUE;
}

bool retro_unserialize(const void *data, size_t size)
{
   if (size != STATE_SIZE)
      return FALSE;

   if (!state_load((uint8_t*)data))
      return FALSE;

#ifdef HAVE_OVERCLOCK
   overclock_delay = OVERCLOCK_FRAME_DELAY;
   update_overclock();
#endif

   return TRUE;
}

void retro_cheat_reset(void)
{
   /* clear existing ROM patches */
   clear_cheats();
   /* delete all cheats */
   maxcheats = maxROMcheats = maxRAMcheats = 0;
}

void retro_cheat_set(unsigned index, bool enabled, const char *code)
{
	char codeCopy[256];
	char *buff;

	/* Avoid crashing when giving no input */
	if (code==NULL) return;

	/* clear existing ROM patches */
	clear_cheats();

	/* Detect and split multiline cheats */
	strncpy(codeCopy,code,255);
	codeCopy[255] = '\0';
	buff = strtok(codeCopy,"+");

	while (buff != NULL)
	{
      /* interpret code and check if this is a valid cheat code */
      if (decode_cheat((char *)buff, maxcheats))
      {
         int i;

         /* check if cheat code already exists */
         for (i=0; i<maxcheats; i++)
         {
            if ((cheatlist[i].address == cheatlist[maxcheats].address)
                   && (cheatlist[i].data == cheatlist[maxcheats].data))
               break;
         }

         /* cheat can be enabled or disabled */
         cheatlist[i].enable = enabled;

         /* if new cheat code, check current cheat count */
         if ((i == maxcheats) && (i < MAX_CHEATS))
         {
            /* increment cheat count */
            maxcheats++;
         }
      }
      buff = strtok(NULL,"+");
	}

	/* apply ROM patches */
	apply_cheats();
}

bool retro_load_game(const struct retro_game_info *info)
{
   int i;
   char *dir = NULL;
#if defined(_WIN32)
   char slash      = '\\';
#else
   char slash      = '/';
#endif

   if (!info)
      return false;

   if (!info->path)
      return false;

#ifdef FRONTEND_SUPPORTS_RGB565
   {
      unsigned rgb565 = RETRO_PIXEL_FORMAT_RGB565;
      if(environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &rgb565))
        fprintf(stderr, "Frontend supports RGB565 - will use that instead of XRGB1555.\n");
   }
#endif

   sms_ntsc = calloc(1, sizeof(sms_ntsc_t));
   md_ntsc  = calloc(1, sizeof(md_ntsc_t));
    
   init_bitmap();
   config_default();

   extract_directory(g_rom_dir, info->path, sizeof(g_rom_dir));
   extract_name(g_rom_name, info->path, sizeof(g_rom_name));

   if (!environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &dir) || !dir)
   {
   //   if (log_cb)
         fprintf(stderr, "[genplus]: Defaulting system directory to %s.\n", g_rom_dir);
      dir = g_rom_dir;
   }

   if (!environ_cb(RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY, &save_dir) || !save_dir)
   {
   //   if (log_cb)
         fprintf(stderr, "[genplus]: Defaulting save directory to %s.\n", g_rom_dir);
      save_dir = g_rom_dir;
   }

   snprintf(GG_ROM, sizeof(GG_ROM), "%s%cggenie.bin", dir, slash);
   snprintf(AR_ROM, sizeof(AR_ROM), "%s%careplay.bin", dir, slash);
   snprintf(SK_ROM, sizeof(SK_ROM), "%s%csk.bin", dir, slash);
   snprintf(SK_UPMEM, sizeof(SK_UPMEM), "%s%csk2chip.bin", dir, slash);
   snprintf(MD_BIOS, sizeof(MD_BIOS), "%s%cbios_MD.bin", dir, slash);
   snprintf(GG_BIOS, sizeof(GG_BIOS), "%s%cbios.gg", dir, slash);
   snprintf(MS_BIOS_EU, sizeof(MS_BIOS_EU), "%s%cbios_E.sms", dir, slash);
   snprintf(MS_BIOS_US, sizeof(MS_BIOS_US), "%s%cbios_U.sms", dir, slash);
   snprintf(MS_BIOS_JP, sizeof(MS_BIOS_JP), "%s%cbios_J.sms", dir, slash);
   snprintf(CD_BIOS_EU, sizeof(CD_BIOS_EU), "%s%cbios_CD_E.bin", dir, slash);
   snprintf(CD_BIOS_US, sizeof(CD_BIOS_US), "%s%cbios_CD_U.bin", dir, slash);
   snprintf(CD_BIOS_JP, sizeof(CD_BIOS_JP), "%s%cbios_CD_J.bin", dir, slash);
   snprintf(CART_BRAM, sizeof(CART_BRAM), "%s%ccart.brm", save_dir, slash);

//   check_variables();

   //if (log_cb)
   {
      fprintf(stderr, "Game Genie ROM should be located at: %s\n", GG_ROM);
      fprintf(stderr, "Action Replay (Pro) ROM should be located at: %s\n", AR_ROM);
      fprintf(stderr, "Sonic & Knuckles (2 MB) ROM should be located at: %s\n", SK_ROM);
      fprintf(stderr, "Sonic & Knuckles UPMEM (256 KB) ROM should be located at: %s\n", SK_UPMEM);
      fprintf(stderr, "Mega Drive TMSS BOOTROM should be located at: %s\n", MD_BIOS);
      fprintf(stderr, "Game Gear TMSS BOOTROM should be located at: %s\n", GG_BIOS);
      fprintf(stderr, "Master System (PAL) BOOTROM should be located at: %s\n", MS_BIOS_EU);
      fprintf(stderr, "Master System (NTSC-U) BOOTROM should be located at: %s\n", MS_BIOS_US);
      fprintf(stderr, "Master System (NTSC-J) BOOTROM should be located at: %s\n", MS_BIOS_JP);
      fprintf(stderr, "Mega CD (PAL) BIOS should be located at: %s\n", CD_BIOS_EU);
      fprintf(stderr, "Sega CD (NTSC-U) BIOS should be located at: %s\n", CD_BIOS_US);
      fprintf(stderr, "Mega CD (NTSC-J) BIOS should be located at: %s\n", CD_BIOS_JP);
      fprintf(stderr, "Mega CD (PAL) BRAM is located at: %s\n", CD_BRAM_EU);
      fprintf(stderr, "Sega CD (NTSC-U) BRAM is located at: %s\n", CD_BRAM_US);
      fprintf(stderr, "Mega CD (NTSC-J) BRAM is located at: %s\n", CD_BRAM_JP);
      fprintf(stderr, "Sega/Mega CD RAM CART is located at: %s\n", CART_BRAM);
   }

   g_rom_data = (void *)info->data;
   g_rom_size = info->size;

   /* Clear disk interface (already done in retro_unload_game but better be safe) */
   disk_count = 0;
   disk_index = 0;
   for (i=0; i<MAX_DISKS; i++)
   {
      if (disk_info[i] != NULL)
      {
         free(disk_info[i]);
         disk_info[i] = NULL;
      }
   }

   /* M3U file list support */
   if ((strlen(info->path) > 4) && !strncmp(info->path + strlen(info->path) - 4, ".m3u", 4))
  {
      FILE *fd = fopen(info->path, "rb");
      if (fd)
      {
         int len;
         char linebuf[512];
         while ((fgets(fd, linebuf, 512) != NULL) && (disk_count < MAX_DISKS))
         {
            /* skip commented lines */
            if (linebuf[0] != '#')
            {
               len = strlen(linebuf);
               if (len > 0)
               {
                  /* remove end-of-line character */
                  if (linebuf[len-1] == '\n')
                  {
                     linebuf[len-1] = 0;
                     len--;
                  }

                  /* remove carriage-return character */
                  if (len && (linebuf[len-1] == '\r'))
                  {
                     linebuf[len-1] = 0;
                     len--;
                  }

                  /* append file path to disk image file name */
                  disk_info[disk_count] = malloc(strlen(g_rom_dir) + len + 2);
                  if (disk_info[disk_count] != NULL)
                  {
                     /* add file to disk interface */
                     sprintf(disk_info[disk_count], "%s%c%s", g_rom_dir, slash, linebuf);
                     disk_count++;
                   //  if (log_cb)
                       fprintf(stderr, "Disk #%d added from M3U file list: %s\n", disk_count, disk_info[disk_count-1]);
                  }
               }
            }
         }
      }

      /* automatically try to load first disk if at least one file was added to disk interface from M3U file list */
      if (disk_count > 0)
      {
         if (!load_rom(disk_info[0]))
         {
           // if (log_cb)
               fprintf(stderr, "Could not load %s from M3U file list\n", disk_info[0]);

            /* clear initialized disk interface before returning an error */
            for (i=0; i<disk_count; i++)
            {
               if (disk_info[i] != NULL)
               {
                  free(disk_info[i]);
                  disk_info[i] = NULL;
               }
            }
            disk_count = 0;
            return false;
         }
      }
      else
      {
         /* error adding disks from M3U */
         return false;
      }
   }
   else
   {
      if (load_rom((char *)info->path) <= 0)
         return false;

      /* automatically add loaded CD to disk interface */
      if ((system_hw == SYSTEM_MCD) && cdd.loaded)
      {
         disk_count = 1;
         disk_info[0] = strdup(info->path);
      }
   }

   if ((config.bios & 1) && !(system_bios & SYSTEM_MD))
   {
      memset(boot_rom, 0xFF, 0x800);
      if (load_archive(MD_BIOS, boot_rom, 0x800, NULL) > 0)
      {
         if (!memcmp((char *)(boot_rom + 0x120),"GENESIS OS", 10))
         {
            system_bios |= SYSTEM_MD;
         }

#ifdef LSB_FIRST
         for (i=0; i<0x800; i+=2)
         {
            uint8 temp = boot_rom[i];
            boot_rom[i] = boot_rom[i+1];
            boot_rom[i+1] = temp;
         }
#endif
      }
   }

   audio_init(SOUND_FREQUENCY, 0);
   system_init();
   system_reset();
   is_running = false;

   if (system_hw == SYSTEM_MCD)
      bram_load();

   update_viewport();

#ifdef HAVE_OVERCLOCK
   overclock_delay = OVERCLOCK_FRAME_DELAY;
   update_overclock();
#endif

   return true;
}

bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info)
{
   (void)game_type;
   (void)info;
   (void)num_info;
   return FALSE;
}

void retro_unload_game(void) 
{
   /* Clear disk interface */
   int i;
   disk_count = 0;
   disk_index = 0;
   for (i=0; i<MAX_DISKS; i++)
   {
      if (disk_info[i] != NULL)
      {
         free(disk_info[i]);
         disk_info[i] = NULL;
      }
   }

   if (system_hw == SYSTEM_MCD)
      bram_save();

   audio_shutdown();
#if defined(USE_NTSC)
    free(md_ntsc);
    free(sms_ntsc);
#endif
//   if (md_ntsc)
//      free(md_ntsc);
//   if (sms_ntsc)
//      free(sms_ntsc);
}

unsigned retro_get_region(void) { return vdp_pal ? RETRO_REGION_PAL : RETRO_REGION_NTSC; }

void *retro_get_memory_data(unsigned id)
{
   switch (id)
   {
      case RETRO_MEMORY_SAVE_RAM:
         return sram.on ? sram.sram : NULL;
      case RETRO_MEMORY_SYSTEM_RAM:
         return work_ram;
      default:
         return NULL;
   }
}

size_t retro_get_memory_size(unsigned id)
{
   int i;

   switch (id)
   {
      case RETRO_MEMORY_SAVE_RAM:
      {
        if (!sram.on)
          return 0;

        /* if emulation is not running, we assume the frontend is requesting SRAM size for loading */
        if (!is_running)
        {
          /* max supported size is returned */
          return 0x10000;
        }

        /* otherwise, we assume this is for saving and we need to check if SRAM data has been modified */
        /* this is obviously not %100 safe since the frontend could still be trying to load SRAM while emulation is running */
        /* a better solution would be that the frontend itself checks if data has been modified before writing it to a file */
        for (i=0xffff; i>=0; i--)
        {
          if (sram.sram[i] != 0xff)
          {
            /* only save modified size */
            return (i+1);
          }
        }
      }
      case RETRO_MEMORY_SYSTEM_RAM:
         if (system_hw == SYSTEM_SMS || system_hw == SYSTEM_SMS2 || system_hw == SYSTEM_GG || system_hw == SYSTEM_GGMS)
            return 0x02000;
         else
            return 0x10000;
      default:
         return 0;
   }
}

static void check_system_specs(void)
{
   unsigned level = 7;
   environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);
}

void retro_init(void)
{
   struct retro_log_callback log;
   unsigned level                = 1;
   uint64_t serialization_quirks = RETRO_SERIALIZATION_QUIRK_PLATFORM_DEPENDENT;

   environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);

   if (environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
      log_cb = log.log;
   else
      log_cb = NULL;

   check_system_specs();

   environ_cb(RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS, &serialization_quirks);
   environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE, &disk_ctrl);
}

void retro_deinit(void)
{
}

void retro_reset(void)
{
#ifdef HAVE_OVERCLOCK
   overclock_delay = OVERCLOCK_FRAME_DELAY;
   update_overclock();
#endif
   gen_reset(0);
}

void retro_run(void) 
{
   bool updated = false;
   is_running = true;

#ifdef HAVE_OVERCLOCK
  /* update overclock delay */
  if (overclock_delay && --overclock_delay == 0)
      update_overclock();
#endif

   if (system_hw == SYSTEM_MCD)
   {
      system_frame_scd(0);
   }
   else if ((system_hw & SYSTEM_PBC) == SYSTEM_MD)
   {
      system_frame_gen(0);
   }
   else
   {
      system_frame_sms(0);
   }

   if (bitmap.viewport.changed & 9)
   {
      bool geometry_updated = update_viewport();
      bitmap.viewport.changed &= ~1;
      if (bitmap.viewport.changed & 8)
      {
        struct retro_system_av_info info;
        bitmap.viewport.changed &= ~8; 
        retro_get_system_av_info(&info);
        environ_cb(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO, &info);
      }
      else if (geometry_updated)
      {
        struct retro_system_av_info info;
        retro_get_system_av_info(&info);
        environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &info.geometry);
      }
   }

   if (config.gun_cursor)
   {
      if (input.system[0] == SYSTEM_LIGHTPHASER)
      {
         draw_cursor(input.analog[0][0], input.analog[0][1], 0x001f);
      }
      else if (input.dev[4] == DEVICE_LIGHTGUN)
      {
         draw_cursor(input.analog[4][0], input.analog[4][1], 0x001f);
      }

      if (input.system[1] == SYSTEM_LIGHTPHASER)
      {
         draw_cursor(input.analog[4][0], input.analog[4][1], 0xf800);
      }
      else if (input.dev[5] == DEVICE_LIGHTGUN)
      {
         draw_cursor(input.analog[5][0], input.analog[5][1], 0xf800);
      }
   }

   video_cb(bitmap.data, vwidth, vheight, 720 * 2);
   audio_cb(soundbuffer, audio_update(soundbuffer));

   environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated);
   if (updated)
   {
//      check_variables();
      if (restart_eq)
      {
         audio_set_equalizer();
         restart_eq = false;
      }
   }
}

#undef  CHUNKSIZE
