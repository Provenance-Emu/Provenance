//
// Audio Overload SDK
//
// Fake ao.h to set up the general Audio Overload style environment
//

#ifndef __AO_H
#define __AO_H

#include "../yabause.h"

#define AO_SUCCESS					1
#define AO_FAIL						0

enum
{
   COMMAND_NONE = 0,
   COMMAND_PREV,
   COMMAND_NEXT,
   COMMAND_RESTART,
   COMMAND_HAS_PREV,
   COMMAND_HAS_NEXT,
   COMMAND_GET_MIN,
   COMMAND_GET_MAX,
   COMMAND_JUMP
};

#define MAX_DISP_INFO_LENGTH		256

typedef struct
{
   char title[9][MAX_DISP_INFO_LENGTH];
   char info[9][MAX_DISP_INFO_LENGTH];
} ao_display_info;

extern ao_display_info ssf_info;

int ao_get_lib(char *filename, u8 **buffer, u64 *length);
s32 ssf_start(u8 *buffer, u32 length, int m68k_core, int sndcore);
s32 ssf_fill_info(ao_display_info *);

#ifdef _MSC_VER
#define strcasecmp _strcmpi
#endif

#ifndef WORDS_BIG_ENDIAN
#define LE16(x) (x)
#define LE32(x) (x)

#else

static unsigned short INLINE LE16(unsigned short x)
{
   unsigned short res = (((x & 0xFF00) >> 8) | ((x & 0xFF) << 8));
   return res;
}

static unsigned long INLINE LE32(unsigned long addr)
{
   unsigned long res = (((addr & 0xff000000) >> 24) |
      ((addr & 0x00ff0000) >> 8) |
      ((addr & 0x0000ff00) << 8) |
      ((addr & 0x000000ff) << 24));

   return res;
}

#endif
#endif // AO_H
