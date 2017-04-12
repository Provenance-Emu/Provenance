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
#include <algorithm>

static struct
{
 uint32 t;
 uint8 mask;
} TimeDrawn[128];

static unsigned TDIndex;
static MDFN_Surface *FPSSurface = NULL;
static MDFN_Rect FPSRect;
static volatile float cur_vfps, cur_dfps, cur_bfps;
static uint8 inc_mask;

void FPS_Init(void)
{
 TDIndex = 0;

 inc_mask = 0;

 cur_vfps = 0;
 cur_dfps = 0;
 cur_bfps = 0;

 memset(TimeDrawn, 0, sizeof(TimeDrawn));
}

void FPS_IncVirtual(void)
{
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

const int box_width = 6 * 5;
const int box_height = 3 * 7;

bool FPS_IsActive(int *w, int *h)
{
 if(!isactive)
  return(FALSE);

 if(w)
  *w = box_width;

 if(h)
  *h = box_height;

 return(TRUE);
}

void FPS_UpdateCalc(void)
{
 uint32 curtime = SDL_GetTicks();
 uint32 mintime = ~0U;

 TimeDrawn[TDIndex].t = curtime;
 TimeDrawn[TDIndex].mask = inc_mask;
 TDIndex = (TDIndex + 1) & 127;
 inc_mask = 0;
 
 if(!isactive)
  return;

 uint32 vt_frames_drawn = 0, dt_frames_drawn = 0, bt_frames_drawn = 0;

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
   }

   mintime = std::min<uint32>(TimeDrawn[qi].t, mintime);
  }
 }

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

void FPS_Draw(MDFN_Surface *target, const int xpos, const int ypos)
{
 if(!isactive)
  return;

 const uint32 bg_color = target->MakeColor(0, 0, 0);
 const uint32 text_color = target->MakeColor(0xFF, 0xFF, 0xFF);
 char virtfps[32], drawnfps[32], blitfps[32];

 CalcFramerates(virtfps, drawnfps, blitfps, 32);

 MDFN_DrawFillRect(target, xpos, ypos, box_width, box_height, bg_color);

 DrawTextTrans(target->pixels + xpos + ypos * target->pitch32, target->pitch32 << 2, box_width, virtfps, text_color, FALSE, TRUE);
 DrawTextTrans(target->pixels + xpos + (ypos + 7) * target->pitch32, target->pitch32 << 2, box_width, drawnfps, text_color, FALSE, TRUE);
 DrawTextTrans(target->pixels + xpos + (ypos + 7 * 2) * target->pitch32, target->pitch32 << 2, box_width, blitfps, text_color, FALSE, TRUE);
}

#define MK_COLOR_A(surface, r,g,b,a) ( surface->MakeColor(r, g, b, a))
void FPS_DrawToScreen(SDL_Surface *screen, int rs, int gs, int bs, int as, unsigned offsx, unsigned offsy)
{
 if(!isactive) 
 {
  if(FPSSurface)
  {
   delete FPSSurface;
   FPSSurface = NULL;
  }
  return;
 }

 if(!FPSSurface)
 {
  FPSSurface = new MDFN_Surface(NULL, box_width, box_height, box_width, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, rs, gs, bs, as));
  FPSRect.w = box_width;
  FPSRect.h = box_height;
  FPSRect.x = FPSRect.y = 0;
 }

 char virtfps[32], drawnfps[32], blitfps[32];

 CalcFramerates(virtfps, drawnfps, blitfps, 32);

 FPSSurface->Fill(0, 0, 0, 0x80);

 DrawTextTrans(FPSSurface->pixels, FPSSurface->pitchinpix << 2, FPSSurface->w, virtfps, MK_COLOR_A(FPSSurface, 0xFF, 0xFF, 0xFF, 0xFF), FALSE, TRUE);
 DrawTextTrans(FPSSurface->pixels + 7 * FPSSurface->pitchinpix, FPSSurface->pitchinpix << 2, FPSSurface->w, drawnfps, MK_COLOR_A(FPSSurface, 0xFF, 0xFF, 0xFF, 0xFF), FALSE, TRUE);
 DrawTextTrans(FPSSurface->pixels + 7 * 2 * FPSSurface->pitchinpix, FPSSurface->pitchinpix << 2, FPSSurface->w, blitfps, MK_COLOR_A(FPSSurface, 0xFF, 0xFF, 0xFF, 0xFF), FALSE, TRUE);

 MDFN_Rect drect;
 drect.x = offsx;
 drect.y = offsy;
 drect.w = FPSRect.w;
 drect.h = FPSRect.h;

 BlitRaw(FPSSurface, &FPSRect, &drect, -1);
}
