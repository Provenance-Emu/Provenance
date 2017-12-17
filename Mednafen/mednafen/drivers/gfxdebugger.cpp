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
#include "gfxdebugger.h"
#include "debugger.h"
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
 if(CurGame->Debugger && CurGame->Debugger->SetGraphicsDecode)
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
    gd_surface = new MDFN_Surface(NULL, 128, 128, 128 * 3, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, 0, 8, 16, 24));
  }
  RedoSGD();
 }
}

#define MK_COLOR_A(r,g,b,a) (pf_cache.MakeColor(r, g, b, a))

// Call this function from the game thread
void GfxDebugger_Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect)
{
 if(!IsActive)
  return;

 const MDFN_PixelFormat pf_cache = surface->format;
 uint32 *src_pixels;
 uint32 * pixels = surface->pixels;
 uint32 pitch32 = surface->pitchinpix;
 const bool ism = Debugger_GT_IsInSteppingMode();

 if(ism)
 {
  RedoSGD(TRUE);
 }

 if(gd_surface->format.Rshift != surface->format.Rshift || gd_surface->format.Gshift != surface->format.Gshift ||
  gd_surface->format.Bshift != surface->format.Bshift || gd_surface->format.Ashift != surface->format.Ashift ||
  gd_surface->format.colorspace != surface->format.colorspace)
 {
  //puts("Convert Meow");
  gd_surface->SetFormat(surface->format, TRUE);
 }

 src_pixels = gd_surface->pixels;

 if(!src_pixels)
 {
  
  return;
 }

 for(unsigned int y = 0; y < 128; y++)
 {
  uint32 *row = pixels + ((rect->w - 256) / 2) + y * pitch32 * 2;
  for(unsigned int x = 0; x < 128; x++)
  {
   //printf("%d %d %d\n", y, x, pixels);
   row[x*2] = row[x*2 + 1] = row[pitch32 + x*2] = row[pitch32 + x*2 + 1] = src_pixels[x + y * 128 * 3];
   //row[x] = MK_COLOR_A(0, 0, 0, 0xc0);
   //row[x] = MK_COLOR_A(0x00, 0x00, 0x00, 0x7F);
  }
 }


 // Draw layer name
 {
  for(int y = 256; y < 256 + 18; y++)
  {
   for(int x = 0; x < rect->w; x++)
   {
    pixels[y * pitch32 + x] = MK_COLOR_A(0x00, 0x00, 0x00, 0xC0);
   }
  }
  char buf[256];

  if(ism)
   trio_snprintf(buf, 256, "%s, PBN: %d, Scroll: %d, Instant", LayerNames[CurLayer], LayerPBN[CurLayer], LayerScroll[CurLayer]);
  else
   trio_snprintf(buf, 256, "%s, PBN: %d, Scroll: %d, Line: %d", LayerNames[CurLayer], LayerPBN[CurLayer], LayerScroll[CurLayer], LayerScanline[CurLayer]);
  DrawTextTransShadow(pixels + 256 * pitch32, surface->pitchinpix << 2, rect->w, buf, MK_COLOR_A(0xF0, 0xF0, 0xF0, 0xFF), MK_COLOR_A(0, 0, 0, 0xFF), 1, FALSE);
 }

 int mousex, mousey;
 SDL_GetMouseState(&mousex, &mousey);
 int vx, vy;

 vx = (mousex - screen_rect->x) * rect->w / screen_rect->w - ((rect->w - 256) / 2);
 vy = (mousey - screen_rect->y) * rect->h / screen_rect->h;

 vx /= 2;
 vy /= 2;

 if(vx < 128 && vy < 128 && vx >= 0 && vy >= 0)
 {
  if(src_pixels[vx + vy * 128 * 3] & (0xFF << surface->format.Ashift))
  {
   for(int y = 278; y < 278 + 18; y++)
    for(int x = 0; x < rect->w; x++)
    {
     pixels[y * pitch32 + x] = MK_COLOR_A(0x00, 0x00, 0x00, 0xC0);
    }
   char buf[256];

   trio_snprintf(buf, 256, "Tile: %08x, Address: %08x", src_pixels[128 + vx + vy * 128 * 3], src_pixels[256 + vx + vy * 128 * 3]);

   DrawTextTransShadow(pixels + 278 * pitch32, surface->pitchinpix << 2, rect->w, buf, MK_COLOR_A(0xF0, 0xF0, 0xF0, 0xFF), MK_COLOR_A(0, 0, 0, 0xFF), 1, FALSE);  
  }
 }

 
}

// Call this from the game thread
int GfxDebugger_Event(const SDL_Event *event)
{
 switch(event->type)
 {
  case SDL_KEYDOWN:
	switch(event->key.keysym.sym)
	{
	 default: break;

	 case SDLK_MINUS:
		       
		       if(LayerScanline[CurLayer])
		       {
			LayerScanline[CurLayer]--;
			RedoSGD();
		       }
		       
		       break;
	 case SDLK_EQUALS:
		       
		       LayerScanline[CurLayer]++;
		       RedoSGD();
		       
		       break;
         case SDLK_UP: 
		       if(LayerScroll[CurLayer])
		       {
                        LayerScroll[CurLayer]--;
                        RedoSGD();
		       }
                       
                       break;

         case SDLK_PAGEUP:
                         
                         LayerScroll[CurLayer] -= 8;
			 if(LayerScroll[CurLayer] < 0)
			  LayerScroll[CurLayer] = 0;
                         RedoSGD();
                         
                         break;

	 case SDLK_PAGEDOWN:
			 
			 LayerScroll[CurLayer] += 8;
			 RedoSGD();
			 
			 break;
	 case SDLK_DOWN: 
			 LayerScroll[CurLayer]++;
			 RedoSGD();
			 
			 break;
	 case SDLK_LEFT: 
			 CurLayer = (CurLayer - 1);

			 if(CurLayer < 0) CurLayer = LayerCount - 1;

			 RedoSGD();
			 
			 break;
	 case SDLK_RIGHT: 
			  CurLayer = (CurLayer + 1) % LayerCount;
			  RedoSGD();
			  
			  break;


	 case SDLK_COMMA: 
			  if(LayerPBN[CurLayer] >= 0)
			   LayerPBN[CurLayer]--;
			  RedoSGD();
			  
			  break;

	 case SDLK_PERIOD:
			  
			  LayerPBN[CurLayer]++;
			  RedoSGD();
			  
			  break;
	}
	break;
 }
 return(1);
}

