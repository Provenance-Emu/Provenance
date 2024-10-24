/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* gfxdebugger.cpp:
**  Copyright (C) 2006-2023 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "main.h"
#include "gfxdebugger.h"
#include "debugger.h"
#include "nongl.h"

#include <trio/trio.h>

static MDFN_Surface *gd_surface = NULL;
static bool IsActive = 0;
static const char *LayerNames[16];
static int LayerScanline[16] = { 0 };
static int LayerScroll[16] = { 0 };
static int LayerPBN[16] = { 0 };
static int LayerCount = 0;
static int CurLayer = 0;

static void RedoSGD(bool instant = 0)
{
 CurGame->Debugger->SetGraphicsDecode(gd_surface, instant ? -1 : LayerScanline[CurLayer], CurLayer, 0, LayerScroll[CurLayer], LayerPBN[CurLayer]);
}

// Call this function from the game thread.
void GfxDebugger_SetActive(bool newia)
{
 if(CurGame->Debugger && CurGame->Debugger->SetGraphicsDecode && CurGame->LayerNames)
 {
  IsActive = newia;

  if(IsActive && !LayerCount)
  {
   LayerCount = 0;

   int clen;
   const char *lnp = CurGame->LayerNames;
   while((clen = strlen(lnp)))
   {
    LayerNames[LayerCount] = lnp;
    LayerCount++;
    lnp += clen + 1;
   }
  }

  if(!IsActive)
  {
   if(gd_surface)
   {
    delete gd_surface;
    gd_surface = NULL;
   }
  }
  else if(IsActive)
  {
   if(!gd_surface)
    gd_surface = new MDFN_Surface(NULL, 128, 128, 128 * 3, MDFN_PixelFormat::ABGR32_8888);
  }
  RedoSGD();
 }
}

// Call this function from the game thread
void GfxDebugger_Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect)
{
 if(!IsActive)
  return;
 //
 //
 const MDFN_PixelFormat pf_cache = surface->format;
 const uint32 text_bg_color = pf_cache.MakeColor(0x00, 0x00, 0x00, 0xC0);
 const uint32 text_color = pf_cache.MakeColor(0xF0, 0xF0, 0xF0, 0xFF);
 const uint32 text_shadow_color = pf_cache.MakeColor(0x00, 0x00, 0x00, 0xFF);

 const uint32* src_pixels;
 const bool ism = Debugger_GT_IsInSteppingMode();

 if(ism)
 {
  RedoSGD(true);
 }

 if(surface->format.opp == 4)
  gd_surface->SetFormat(surface->format, true);

 src_pixels = gd_surface->pixels;

 if(!src_pixels)
  return;
 //
 //
 const unsigned scale = 2;
 const MDFN_Rect gd_srect = { 0, 0, (int32)gd_surface->w, (int32)gd_surface->h };
 const MDFN_Rect drect = { (int32)(rect->w - gd_surface->w * scale) / 2, 0, (int32)(gd_surface->w * scale), (int32)(gd_surface->h * scale) };

 if(gd_surface->format == surface->format)
  MDFN_StretchBlitSurface(gd_surface, gd_srect, surface, drect);
 else
 {
  std::unique_ptr<MDFN_Surface> tsurf(gd_surface->DupeCompactConvert(surface->format));

  MDFN_StretchBlitSurface(tsurf.get(), gd_srect, surface, drect);
 }

 // Draw layer name
 {
  char buf[256];

  MDFN_DrawFillRect(surface, 0, gd_surface->h * scale, rect->w, 18, text_bg_color);

  if(ism)
   trio_snprintf(buf, 256, "%s, PBN: %d, Scroll: %d, Instant", LayerNames[CurLayer], LayerPBN[CurLayer], LayerScroll[CurLayer]);
  else
   trio_snprintf(buf, 256, "%s, PBN: %d, Scroll: %d, Line: %d", LayerNames[CurLayer], LayerPBN[CurLayer], LayerScroll[CurLayer], LayerScanline[CurLayer]);

  DrawTextShadow(surface, 0, gd_surface->h * scale, buf, text_color, text_shadow_color, MDFN_FONT_9x18_18x18, rect->w);
 }

 int mousex, mousey;
 int vx, vy;

 SDL_GetMouseState(&mousex, &mousey);

 vx = (mousex - screen_rect->x) * rect->w / screen_rect->w - drect.x;
 vy = (mousey - screen_rect->y) * rect->h / screen_rect->h - drect.y;

 vx /= scale;
 vy /= scale;

 if(vx < gd_surface->w && vy < gd_surface->h && vx >= 0 && vy >= 0)
 {
  if(src_pixels[vx + vy * gd_surface->pitchinpix] & (0xFF << surface->format.Ashift))
  {
   char buf[256];

   MDFN_DrawFillRect(surface, 0, gd_surface->h * scale + 22, rect->w, 18, text_bg_color);

   trio_snprintf(buf, 256, "Tile: %08x, Address: %08x", src_pixels[gd_surface->w * 1 + vx + vy * gd_surface->pitchinpix], src_pixels[gd_surface->w * 2 + vx + vy * gd_surface->pitchinpix]);

   DrawTextShadow(surface, 0, gd_surface->h * scale + 22, buf, text_color, text_shadow_color, MDFN_FONT_9x18_18x18, rect->w);
  }
 }
}

static void ChangeScanline(int delta)
{
 LayerScanline[CurLayer] = std::max<int64>(0, (int64)LayerScanline[CurLayer] + delta);
 RedoSGD();
}

static void ChangePBN(int delta)
{
 LayerPBN[CurLayer] = std::max<int64>(-1, (int64)LayerPBN[CurLayer] + delta);
 RedoSGD();
}

static void ChangeScroll(int delta)
{
 LayerScroll[CurLayer] = std::max<int64>(0, (int64)LayerScroll[CurLayer] + delta);
 RedoSGD();
}

// Call this from the game thread
int GfxDebugger_Event(const SDL_Event *event)
{
 if(!IsActive)
  return true;

 if(event->type == SDL_KEYDOWN)
 {
  switch(event->key.keysym.sym)
  {
   default:
	break;

   case SDLK_MINUS:
	ChangeScanline(-1);
	break;

   case SDLK_EQUALS:
	ChangeScanline(1);
	break;

   case SDLK_UP:
	if(event->key.keysym.mod & KMOD_CTRL)
	 ChangeScanline(1);
	else
	 ChangeScroll(-1);
	break;

   case SDLK_DOWN:
	if(event->key.keysym.mod & KMOD_CTRL)
	 ChangeScanline(-1);
	else
	 ChangeScroll(1);
	break;

   case SDLK_PAGEUP:
	ChangeScroll(-8);
	break;

   case SDLK_PAGEDOWN:
	ChangeScroll(8);
	break;

   case SDLK_LEFT:
	if(event->key.keysym.mod & KMOD_CTRL)
	 ChangePBN(-1);
	else
	{
	 CurLayer = (CurLayer - 1);

	 if(CurLayer < 0)
	  CurLayer = LayerCount - 1;

	 RedoSGD();
	}
	break;

   case SDLK_RIGHT:
	if(event->key.keysym.mod & KMOD_CTRL)
	 ChangePBN(1);
	else
	{
	 CurLayer = (CurLayer + 1) % LayerCount;
	 RedoSGD();
	}
	break;

   case SDLK_COMMA:
	ChangePBN(-1);
	break;

   case SDLK_PERIOD:
	ChangePBN(1);
	break;
  }
 }
 return true;
}

