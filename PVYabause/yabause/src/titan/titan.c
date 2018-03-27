/*  Copyright 2012 Guillaume Duhamel

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

#include "titan.h"
#include "../vidshared.h"
#include "../vidsoft.h"
#include "../threads.h"

#include <stdlib.h>

/* private */
typedef u32 (*TitanBlendFunc)(u32 top, u32 bottom);
typedef int FASTCALL (*TitanTransFunc)(u32 pixel);
void TitanRenderLines(pixel_t * dispbuffer, int start_line, int end_line);
extern int vdp2_interlace;

int vidsoft_num_priority_threads = 0;

struct PixelData
{
   u32 pixel;
   u8 priority;
   u8 linescreen;
   u8 shadow_type;
   u8 shadow_enabled;
};

static struct TitanContext {
   int inited;
   struct PixelData * vdp2framebuffer[6];
   u32 * linescreen[4];
   int vdp2width;
   int vdp2height;
   TitanBlendFunc blend;
   TitanTransFunc trans;
   struct PixelData * backscreen;
   int layer_priority[6];
} tt_context = {
   0,
   { NULL, NULL, NULL, NULL, NULL, NULL },
   { NULL, NULL, NULL, NULL },
   320,
   224,
   NULL,NULL,NULL
};

struct
{
   volatile int need_draw[5];
   volatile int draw_finished[5];
   struct
   {
      volatile int start;
      volatile int end;
   }lines[5];

   pixel_t * dispbuffer;
   int use_simplified;
}priority_thread_context;

#if defined WORDS_BIGENDIAN
#ifdef USE_RGB_555
static INLINE u32 TitanFixAlpha(u32 pixel) { return (((pixel >> 27) & 0x1F) | ((pixel >> 14) & 0x7C0) | (pixel >> 1) & 0xF8); }
#elif USE_RGB_565
static INLINE u32 TitanFixAlpha(u32 pixel) { return (((pixel >> 27) & 0x1F) | ((pixel >> 13) & 0x7E0) | (pixel & 0xF8)); }
#else
static INLINE u32 TitanFixAlpha(u32 pixel) { return ((((pixel & 0x3F) << 2) + 0x03) | (pixel & 0xFFFFFF00)); }
#endif

static INLINE u8 TitanGetAlpha(u32 pixel) { return pixel & 0x3F; }
static INLINE u8 TitanGetRed(u32 pixel) { return (pixel >> 8) & 0xFF; }
static INLINE u8 TitanGetGreen(u32 pixel) { return (pixel >> 16) & 0xFF; }
static INLINE u8 TitanGetBlue(u32 pixel) { return (pixel >> 24) & 0xFF; }
static INLINE u32 TitanCreatePixel(u8 alpha, u8 red, u8 green, u8 blue) { return alpha | (red << 8) | (green << 16) | (blue << 24); }
#else
#ifdef USE_RGB_555
static INLINE u32 TitanFixAlpha(u32 pixel) { return (((pixel << 7) & 0x7C00) | ((pixel >> 6) & 0x3C0) | ((pixel >> 19) & 0x1F)); }
#elif USE_RGB_565
static INLINE u32 TitanFixAlpha(u32 pixel) { return (((pixel << 8) & 0xF800) | ((pixel >> 5) & 0x7C0) | ((pixel >> 19) & 0x1F)); }
#else
static INLINE u32 TitanFixAlpha(u32 pixel) { return ((((pixel & 0x3F000000) << 2) + 0x03000000) | (pixel & 0x00FFFFFF)); }
#endif

static INLINE u8 TitanGetAlpha(u32 pixel) { return (pixel >> 24) & 0x3F; }
static INLINE u8 TitanGetRed(u32 pixel) { return (pixel >> 16) & 0xFF; }
static INLINE u8 TitanGetGreen(u32 pixel) { return (pixel >> 8) & 0xFF; }
static INLINE u8 TitanGetBlue(u32 pixel) { return pixel & 0xFF; }
static INLINE u32 TitanCreatePixel(u8 alpha, u8 red, u8 green, u8 blue) { return (alpha << 24) | (red << 16) | (green << 8) | blue; }
#endif


void set_layer_y(const int start_line, int * layer_y)
{
   if (vdp2_interlace)
      *layer_y = start_line / 2;
   else
      *layer_y = start_line;
}

void TitanRenderLinesSimplified(pixel_t * dispbuffer, int start_line, int end_line)
{
   int x, y, i, layer, j, layer_y;
   int line_increment, interlace_line;
   int sorted_layers[8] = { 0 };
   int num_layers = 0;

   if (!tt_context.inited || (!tt_context.trans))
   {
      return;
   }

   Vdp2GetInterlaceInfo(&interlace_line, &line_increment);

   //pre-sort the layers so it doesn't have to be done per-pixel
   for (i = 7; i >= 0; i--)
   {
      for (layer = TITAN_RBG0; layer >= 0; layer--)
      {
         if (tt_context.layer_priority[layer] > 0 && tt_context.layer_priority[layer] == i)
            sorted_layers[num_layers++] = layer;
      }
   }

   //last layer is always the back screen
   sorted_layers[num_layers++] = TITAN_BACK;

   set_layer_y(start_line, &layer_y);

   for (y = start_line + interlace_line; y < end_line; y += line_increment)
   {
      for (x = 0; x < tt_context.vdp2width; x++)
      {
         int layer_pos = (layer_y * tt_context.vdp2width) + x;
         i = (y * tt_context.vdp2width) + x;

         dispbuffer[i] = 0;

         for (j = 0; j < num_layers; j++)
         {
            struct PixelData sprite = tt_context.vdp2framebuffer[TITAN_SPRITE][layer_pos];

            int bg_layer = sorted_layers[j];

            //if the top layer is the back screen
            if (bg_layer == TITAN_BACK)
            {
               //use a sprite pixel if it is not transparent
               if (sprite.pixel)
               {
                  dispbuffer[i] = TitanFixAlpha(sprite.pixel);
                  break;
               }
               else
               {
                  //otherwise use the back screen pixel
                  dispbuffer[i] = TitanFixAlpha(tt_context.backscreen[y].pixel);
                  break;
               }
            }
            //if the top layer is a sprite pixel
            else if (sprite.priority >= tt_context.layer_priority[bg_layer])
            {
               //use the sprite pixel if it is not transparent
               if (sprite.pixel)
               {
                  dispbuffer[i] = TitanFixAlpha(sprite.pixel);
                  break;
               }
            }
            else
            {
               //use the bg layer if it is not covered with a sprite pixel and not transparent
               if (tt_context.vdp2framebuffer[bg_layer][layer_pos].pixel)
               {
                  dispbuffer[i] = TitanFixAlpha(tt_context.vdp2framebuffer[bg_layer][layer_pos].pixel);
                  break;
               }
            }
         }
      }
      layer_y++;
   }
}

void TitanRenderSimplifiedCheck(pixel_t * buf, int start, int end, int can_use_simplified_rendering)
{
   if (can_use_simplified_rendering)
      TitanRenderLinesSimplified(buf, start, end);
   else
      TitanRenderLines(buf, start, end);
}

#define DECLARE_PRIORITY_THREAD(FUNC_NAME, THREAD_NUMBER) \
void FUNC_NAME(void* data) \
{ \
   for (;;) \
   { \
      if (priority_thread_context.need_draw[THREAD_NUMBER]) \
      { \
         priority_thread_context.need_draw[THREAD_NUMBER] = 0; \
         TitanRenderSimplifiedCheck(priority_thread_context.dispbuffer, priority_thread_context.lines[THREAD_NUMBER].start, priority_thread_context.lines[THREAD_NUMBER].end, priority_thread_context.use_simplified); \
         priority_thread_context.draw_finished[THREAD_NUMBER] = 1; \
      } \
      YabThreadSleep(); \
   } \
}

DECLARE_PRIORITY_THREAD(VidsoftPriorityThread0, 0);
DECLARE_PRIORITY_THREAD(VidsoftPriorityThread1, 1);
DECLARE_PRIORITY_THREAD(VidsoftPriorityThread2, 2);
DECLARE_PRIORITY_THREAD(VidsoftPriorityThread3, 3);
DECLARE_PRIORITY_THREAD(VidsoftPriorityThread4, 4);

static u32 TitanBlendPixelsTop(u32 top, u32 bottom)
{
   u8 alpha, ralpha, tr, tg, tb, br, bg, bb;

   alpha = (TitanGetAlpha(top) << 2) + 3;
   ralpha = 0xFF - alpha;

   tr = (TitanGetRed(top) * alpha) / 0xFF;
   tg = (TitanGetGreen(top) * alpha) / 0xFF;
   tb = (TitanGetBlue(top) * alpha) / 0xFF;

   br = (TitanGetRed(bottom) * ralpha) / 0xFF;
   bg = (TitanGetGreen(bottom) * ralpha) / 0xFF;
   bb = (TitanGetBlue(bottom) * ralpha) / 0xFF;

   return TitanCreatePixel(0x3F, tr + br, tg + bg, tb + bb);
}

static u32 TitanBlendPixelsBottom(u32 top, u32 bottom)
{
   u8 alpha, ralpha, tr, tg, tb, br, bg, bb;

   if ((top & 0x80000000) == 0) return top;

   alpha = (TitanGetAlpha(bottom) << 2) + 3;
   ralpha = 0xFF - alpha;

   tr = (TitanGetRed(top) * alpha) / 0xFF;
   tg = (TitanGetGreen(top) * alpha) / 0xFF;
   tb = (TitanGetBlue(top) * alpha) / 0xFF;

   br = (TitanGetRed(bottom) * ralpha) / 0xFF;
   bg = (TitanGetGreen(bottom) * ralpha) / 0xFF;
   bb = (TitanGetBlue(bottom) * ralpha) / 0xFF;

   return TitanCreatePixel(TitanGetAlpha(top), tr + br, tg + bg, tb + bb);
}

static u32 TitanBlendPixelsAdd(u32 top, u32 bottom)
{
   u32 r, g, b;

   r = TitanGetRed(top) + TitanGetRed(bottom);
   if (r > 0xFF) r = 0xFF;

   g = TitanGetGreen(top) + TitanGetGreen(bottom);
   if (g > 0xFF) g = 0xFF;

   b = TitanGetBlue(top) + TitanGetBlue(bottom);
   if (b > 0xFF) b = 0xFF;

   return TitanCreatePixel(0x3F, r, g, b);
}

static INLINE int FASTCALL TitanTransAlpha(u32 pixel)
{
   return TitanGetAlpha(pixel) < 0x3F;
}

static INLINE int FASTCALL TitanTransBit(u32 pixel)
{
   return pixel & 0x80000000;
}

static u32 TitanDigPixel(int pos, int y)
{
   struct PixelData pixel_stack[2] = { 0 };

   int pixel_stack_pos = 0;

   int priority;

   //sort the pixels from highest to lowest priority
   for (priority = 7; priority > 0; priority--)
   {
      int which_layer;

      for (which_layer = TITAN_SPRITE; which_layer >= 0; which_layer--)
      {
         if (tt_context.vdp2framebuffer[which_layer][pos].priority == priority)
         {
            pixel_stack[pixel_stack_pos] = tt_context.vdp2framebuffer[which_layer][pos];
            pixel_stack_pos++;

            if (pixel_stack_pos == 2)
               goto finished;//backscreen is unnecessary in this case
         }
      }
   }

   pixel_stack[pixel_stack_pos] = tt_context.backscreen[pos];

finished:

   if (pixel_stack[0].linescreen)
   {
      pixel_stack[0].pixel = tt_context.blend(pixel_stack[0].pixel, tt_context.linescreen[pixel_stack[0].linescreen][y]);
   }

   if ((pixel_stack[0].shadow_type == TITAN_MSB_SHADOW) && ((pixel_stack[0].pixel & 0xFFFFFF) == 0))
   {
      //transparent sprite shadow
      if (pixel_stack[1].shadow_enabled)
      {
         pixel_stack[0].pixel = TitanBlendPixelsTop(0x20000000, pixel_stack[1].pixel);
      }
      else
      {
         pixel_stack[0].pixel = pixel_stack[1].pixel;
      }
   }
   else if (pixel_stack[0].shadow_type == TITAN_MSB_SHADOW && ((pixel_stack[0].pixel & 0xFFFFFF) != 0))
   {
      if (tt_context.trans(pixel_stack[0].pixel))
      {
         u32 bottom = pixel_stack[1].pixel;
         pixel_stack[0].pixel = tt_context.blend(pixel_stack[0].pixel, bottom);
      }

      //sprite self-shadowing, only if sprite window is not enabled
      if (!(Vdp2Regs->SPCTL & 0x10))
         pixel_stack[0].pixel = TitanBlendPixelsTop(0x20000000, pixel_stack[0].pixel);
   }
   else if (pixel_stack[0].shadow_type == TITAN_NORMAL_SHADOW)
   {
      if (pixel_stack[1].shadow_enabled)
      {
         pixel_stack[0].pixel = TitanBlendPixelsTop(0x20000000, pixel_stack[1].pixel);
      }
      else
      {
         pixel_stack[0].pixel = pixel_stack[1].pixel;
      }
   }
   else
   {
      if (tt_context.trans(pixel_stack[0].pixel))
      {
         u32 bottom = pixel_stack[1].pixel;
         pixel_stack[0].pixel = tt_context.blend(pixel_stack[0].pixel, bottom);
      }
   }

   return pixel_stack[0].pixel;
}

/* public */
int TitanInit()
{
   int i;

   if (! tt_context.inited)
   {
      for(i = 0;i < 6;i++)
      {
         if ((tt_context.vdp2framebuffer[i] = (struct PixelData *)calloc(sizeof(struct PixelData), 704 * 256)) == NULL)
            return -1;
      }

      /* linescreen 0 is not initialized as it's not used... */
      for(i = 1;i < 4;i++)
      {
         if ((tt_context.linescreen[i] = (u32 *)calloc(sizeof(u32), 512)) == NULL)
            return -1;
      }

      if ((tt_context.backscreen = (struct PixelData  *)calloc(sizeof(struct PixelData), 704 * 512)) == NULL)
         return -1;

      for (i = 0; i < 5; i++)
      {
         priority_thread_context.draw_finished[i] = 1;
         priority_thread_context.need_draw[i] = 0;
      }

      YabThreadStart(YAB_THREAD_VIDSOFT_PRIORITY_0, VidsoftPriorityThread0, NULL);
      YabThreadStart(YAB_THREAD_VIDSOFT_PRIORITY_1, VidsoftPriorityThread1, NULL);
      YabThreadStart(YAB_THREAD_VIDSOFT_PRIORITY_2, VidsoftPriorityThread2, NULL);
      YabThreadStart(YAB_THREAD_VIDSOFT_PRIORITY_3, VidsoftPriorityThread3, NULL);
      YabThreadStart(YAB_THREAD_VIDSOFT_PRIORITY_4, VidsoftPriorityThread4, NULL);

      tt_context.inited = 1;
   }

   for(i = 0;i < 6;i++)
      memset(tt_context.vdp2framebuffer[i], 0, sizeof(u32) * 704 * 256);

   for(i = 1;i < 4;i++)
      memset(tt_context.linescreen[i], 0, sizeof(u32) * 512);

   return 0;
}

void TitanErase()
{
   int i = 0;

   int height = tt_context.vdp2height;

   if (vdp2_interlace)
      height /= 2;

   for (i = 0; i < 6; i++)
      memset(tt_context.vdp2framebuffer[i], 0, sizeof(struct PixelData) * tt_context.vdp2width * height);
}

int TitanDeInit()
{
   int i;

   for(i = 0;i < 6;i++)
      free(tt_context.vdp2framebuffer[i]);

   for(i = 1;i < 4;i++)
      free(tt_context.linescreen[i]);

   return 0;
}

void TitanSetResolution(int width, int height)
{
   tt_context.vdp2width = width;
   tt_context.vdp2height = height;
}

void TitanGetResolution(int * width, int * height)
{
   *width = tt_context.vdp2width;
   *height = tt_context.vdp2height;
}

void TitanSetBlendingMode(int blend_mode)
{
   if (blend_mode == TITAN_BLEND_BOTTOM)
   {
      tt_context.blend = TitanBlendPixelsBottom;
      tt_context.trans = TitanTransBit;
   }
   else if (blend_mode == TITAN_BLEND_ADD)
   {
      tt_context.blend = TitanBlendPixelsAdd;
      tt_context.trans = TitanTransBit;
   }
   else
   {
      tt_context.blend = TitanBlendPixelsTop;
      tt_context.trans = TitanTransAlpha;
   }
}

void TitanPutBackHLine(s32 y, u32 color)
{
   struct PixelData* buffer = &tt_context.backscreen[(y * tt_context.vdp2width)];
   int i;

   for (i = 0; i < tt_context.vdp2width; i++)
      buffer[i].pixel = color;
}

void TitanPutLineHLine(int linescreen, s32 y, u32 color)
{
   if (linescreen == 0) return;

   {
      u32 * buffer = tt_context.linescreen[linescreen] + y;
      *buffer = color;
   }
}

void TitanPutPixel(int priority, s32 x, s32 y, u32 color, int linescreen, vdp2draw_struct* info)
{
   if (priority == 0) return;

   {
      int pos = (y * tt_context.vdp2width) + x;
      tt_context.vdp2framebuffer[info->titan_which_layer][pos].pixel = color;
      tt_context.vdp2framebuffer[info->titan_which_layer][pos].priority = priority;
      tt_context.vdp2framebuffer[info->titan_which_layer][pos].linescreen = linescreen;
      tt_context.vdp2framebuffer[info->titan_which_layer][pos].shadow_enabled = info->titan_shadow_enabled;
      tt_context.vdp2framebuffer[info->titan_which_layer][pos].shadow_type = info->titan_shadow_type;
   }
}

void TitanPutHLine(int priority, s32 x, s32 y, s32 width, u32 color)
{
   if (priority == 0) return;

   {
      struct PixelData * buffer = &tt_context.vdp2framebuffer[priority][ (y * tt_context.vdp2width) + x];
      int i;

      for (i = 0; i < width; i++)
         buffer[i].pixel = color;
   }
}

void TitanRenderLines(pixel_t * dispbuffer, int start_line, int end_line)
{
   int x, y, layer_y;
   u32 dot;
   int line_increment, interlace_line;

   if (!tt_context.inited || (!tt_context.trans))
   {
      return;
   }

   Vdp2GetInterlaceInfo(&interlace_line, &line_increment);

   set_layer_y(start_line, &layer_y);

   for (y = start_line + interlace_line; y < end_line; y += line_increment)
   {
      for (x = 0; x < tt_context.vdp2width; x++)
      {
         int i = (y * tt_context.vdp2width) + x;
         int layer_pos = (layer_y * tt_context.vdp2width) + x;

         dispbuffer[i] = 0;

         dot = TitanDigPixel(layer_pos, y);

         if (dot)
         {
            dispbuffer[i] = TitanFixAlpha(dot);
         }
      }

      layer_y++;
   }
}

//num + 1 needs to be an even number to avoid issues with interlace modes
void VIDSoftSetNumPriorityThreads(int num)
{
   vidsoft_num_priority_threads = num > 5 ? 5 : num;

   if (num == 2)
      vidsoft_num_priority_threads = 1;

   if (num == 4)
      vidsoft_num_priority_threads = 3;
}

void TitanStartPriorityThread(int which)
{
   priority_thread_context.need_draw[which] = 1;
   priority_thread_context.draw_finished[which] = 0;
   YabThreadWake(YAB_THREAD_VIDSOFT_PRIORITY_0 + which);
}

void TitanWaitForPriorityThread(int which)
{
   while (!priority_thread_context.draw_finished[which]){}
}

void TitanRenderThreads(pixel_t * dispbuffer, int can_use_simplified)
{
   int i;
   int total_jobs = vidsoft_num_priority_threads + 1;//main thread runs a job
   int num_lines_per_job = tt_context.vdp2height / total_jobs;
   int remainder = tt_context.vdp2height % total_jobs;
   int starts[6] = { 0 };
   int ends[6] = { 0 };

   priority_thread_context.dispbuffer = dispbuffer;
   priority_thread_context.use_simplified = can_use_simplified;

   for (i = 0; i < total_jobs; i++)
   {
      starts[i] = num_lines_per_job * i;
      ends[i] = ((i + 1) * num_lines_per_job);
   }

   for (i = 0; i < vidsoft_num_priority_threads; i++)
   {
      priority_thread_context.lines[i].start = starts[i+1];
      priority_thread_context.lines[i].end = ends[i+1];
   }

   //put any remaining lines on the last thread
   priority_thread_context.lines[vidsoft_num_priority_threads - 1].end += remainder;

   for (i = 0; i < vidsoft_num_priority_threads; i++)
   {
      TitanStartPriorityThread(i);
   }

   TitanRenderSimplifiedCheck(dispbuffer, starts[0], ends[0], can_use_simplified);

   for (i = 0; i < vidsoft_num_priority_threads; i++)
   {
      TitanWaitForPriorityThread(i);
   }
}

void TitanRender(pixel_t * dispbuffer)
{
   int can_use_simplified_rendering = 1;

   if (!tt_context.inited || (!tt_context.trans))
   {
      return;
   }

   //using color calculation
   if ((Vdp2Regs->CCCTL & 0x807f) != 0)
      can_use_simplified_rendering = 0;

   //using special priority
   if ((Vdp2Regs->SFPRMD & 0x3ff) != 0)
      can_use_simplified_rendering = 0;

   //using line screen
   if ((Vdp2Regs->LNCLEN & 0x1f) != 0)
      can_use_simplified_rendering = 0;

   //using shadow
   if ((Vdp2Regs->SDCTL & 0x13F) != 0)
      can_use_simplified_rendering = 0;

   tt_context.layer_priority[TITAN_NBG0] = Vdp2Regs->PRINA & 0x7;
   tt_context.layer_priority[TITAN_NBG1] = ((Vdp2Regs->PRINA >> 8) & 0x7);
   tt_context.layer_priority[TITAN_NBG2] = (Vdp2Regs->PRINB & 0x7);
   tt_context.layer_priority[TITAN_NBG3] = ((Vdp2Regs->PRINB >> 8) & 0x7);
   tt_context.layer_priority[TITAN_RBG0] = (Vdp2Regs->PRIR & 0x7);

   if (vidsoft_num_priority_threads > 0)
   {
      TitanRenderThreads(dispbuffer, can_use_simplified_rendering);
   }
   else
   {
      TitanRenderSimplifiedCheck(dispbuffer, 0, tt_context.vdp2height, can_use_simplified_rendering);
   }
}

#ifdef WORDS_BIGENDIAN
void TitanWriteColor(pixel_t * dispbuffer, s32 bufwidth, s32 x, s32 y, u32 color)
{
   int pos = (y * bufwidth) + x;
   pixel_t * buffer = dispbuffer + pos;
   *buffer = ((color >> 24) & 0xFF) | ((color >> 8) & 0xFF00) | ((color & 0xFF00) << 8) | ((color & 0xFF) << 24);
}
#else
void TitanWriteColor(pixel_t * dispbuffer, s32 bufwidth, s32 x, s32 y, u32 color)
{
   int pos = (y * bufwidth) + x;
   pixel_t * buffer = dispbuffer + pos;
   *buffer = color;
}
#endif
