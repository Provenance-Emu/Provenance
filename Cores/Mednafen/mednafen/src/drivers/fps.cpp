/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"
#include "video.h"
#include <trio/trio.h>

static struct
{
 //int64 vcycles;
 uint32 t;
 uint8 mask;
} TimeDrawn[128];

static unsigned TDIndex;
static MDFN_Surface *FPSSurface = NULL;
static MDFN_Rect FPSRect;
static volatile float cur_vfps, cur_dfps, cur_bfps;
static uint8 inc_mask;
//static int64 inc_vcycles;

static unsigned position;
static unsigned scale;

static unsigned font;
static unsigned font_width;
static unsigned font_height;

static uint32 text_color;
static uint32 bg_color;

void FPS_Init(const unsigned fps_pos, const unsigned fps_scale, const unsigned fps_font, const uint32 fps_tcolor, const uint32 fps_bgcolor)
{
 TDIndex = 0;

 inc_mask = 0;
 //inc_vcycles = 0;

 cur_vfps = 0;
 cur_dfps = 0;
 cur_bfps = 0;

 memset(TimeDrawn, 0, sizeof(TimeDrawn));

 position = fps_pos;
 scale = fps_scale;
 font = fps_font;
 font_width = GetTextPixLength("0", font);
 font_height = GetFontHeight(fps_font);

 text_color = fps_tcolor;
 bg_color = fps_bgcolor;

 FPSRect.x = FPSRect.y = 0;
 FPSRect.w = 6 * font_width;
 FPSRect.h = 3 * font_height;

 FPSSurface = new MDFN_Surface(NULL, FPSRect.w, FPSRect.h, FPSRect.w, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, 0, 8, 16, 24));
}

void FPS_IncVirtual(int64 vcycles)
{
 //inc_vcycles = vcycles;
 inc_mask |= 1;
}

void FPS_IncDrawn(void)
{
 inc_mask |= 2;
}

void FPS_IncBlitted(void)
{
 inc_mask |= 4;
}

static bool isactive = 0;

void FPS_ToggleView(void)
{
 isactive ^= 1;
}

void FPS_UpdateCalc(void)
{
 uint32 curtime = Time::MonoMS();
 uint32 mintime = ~0U;

 TimeDrawn[TDIndex].t = curtime;
 //TimeDrawn[TDIndex].vcycles = inc_vcycles;
 TimeDrawn[TDIndex].mask = inc_mask;
 TDIndex = (TDIndex + 1) & 127;
 inc_mask = 0;
 //inc_vcycles = 0; 

 if(!isactive)
  return;

 uint32 vt_frames_drawn = 0, dt_frames_drawn = 0, bt_frames_drawn = 0;
 //uint64 vcyc_accum = 0;

 for(int x = 0; x < 128; x++)
 {
  int qi = (x + TDIndex) & 127;

  if(TimeDrawn[qi].t >= (curtime - 1000))
  {
   if(mintime != ~0U)
   {
    vt_frames_drawn += (bool)(TimeDrawn[qi].mask & 0x1);
    dt_frames_drawn += (bool)(TimeDrawn[qi].mask & 0x2);
    bt_frames_drawn += (bool)(TimeDrawn[qi].mask & 0x4);

    //vcyc_accum += TimeDrawn[qi].vcycles;
   }

   mintime = std::min<uint32>(TimeDrawn[qi].t, mintime);
  }
 }

 //printf("%llu, %.1f\n", vcyc_accum, 100 * 1000.0 * vcyc_accum / ((curtime - mintime) * (CurGame->MasterClock >> 32)));

 if(curtime > mintime)
 {
  cur_vfps = (float)vt_frames_drawn * 1000 / (curtime - mintime);
  cur_dfps = (float)dt_frames_drawn * 1000 / (curtime - mintime);
  cur_bfps = (float)bt_frames_drawn * 1000 / (curtime - mintime);
 }
 else
 {
  cur_vfps = 0;
  cur_dfps = 0;
  cur_bfps = 0;
 }
}

static void CalcFramerates(char *virtfps, char *drawnfps, char *blitfps, size_t maxlen)
{
 double vf = cur_vfps, df = cur_dfps, bf = cur_bfps;

 if(vf != 0)
  trio_snprintf(virtfps, maxlen, "%f", vf);
 else
  trio_snprintf(virtfps, maxlen, "?");

 if(df != 0)
  trio_snprintf(drawnfps, maxlen, "%f", df);
 else
  trio_snprintf(drawnfps, maxlen, "?");

 if(bf != 0)
  trio_snprintf(blitfps, maxlen, "%f", bf);
 else
  trio_snprintf(blitfps, maxlen, "?");
}

void FPS_DrawToScreen(int rs, int gs, int bs, int as, const MDFN_Rect& cr, unsigned min_screen_w_h)
{
 if(!isactive) 
  return;

 FPSSurface->SetFormat(MDFN_PixelFormat(MDFN_COLORSPACE_RGB, rs, gs, bs, as), false);
 //
 const unsigned eff_scale = scale ? scale : std::max<unsigned>(1, /*std::min(cr.w, cr.h)*/min_screen_w_h / std::max(FPSRect.w, FPSRect.h) / 8);
 char virtfps[32], drawnfps[32], blitfps[32];
 const uint32 surf_text_color = FPSSurface->MakeColor((text_color >> 16) & 0xFF, (text_color >> 8) & 0xFF, (text_color >> 0) & 0xFF, (text_color >> 24) & 0xFF);

 CalcFramerates(virtfps, drawnfps, blitfps, 32);

 FPSSurface->Fill((bg_color >> 16) & 0xFF, (bg_color >> 8) & 0xFF, (bg_color >> 0) & 0xFF, (bg_color >> 24) & 0xFF);

 DrawText(FPSSurface, 0, font_height * 0, virtfps, surf_text_color, font);
 DrawText(FPSSurface, 0, font_height * 1, drawnfps, surf_text_color, font);
 DrawText(FPSSurface, 0, font_height * 2, blitfps, surf_text_color, font);
 //
 //
 MDFN_Rect drect;

 drect.w = FPSRect.w * eff_scale;
 drect.h = FPSRect.h * eff_scale;

 if(position)
 {
  drect.x = cr.x + (cr.w - drect.w);
  drect.y = cr.y;
 }
 else
 {
  drect.x = cr.x;
  drect.y = cr.y;
 }

 BlitRaw(FPSSurface, &FPSRect, &drect, -1);
}
