/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "sdl.h"
#include "sdl-opengl.h"
#include "../common/vidblit.h"

#include "sdl-icon.h"
#include "dface.h"

SDL_Surface *screen;
SDL_Surface *BlitBuf;		// Used as a buffer when using hardware-accelerated blits.
SDL_Surface *IconSurface=NULL;

static int curbpp;
static int srendline,erendline;
static int tlines;
static int inited=0;

#ifdef OPENGL
extern int sdlhaveogl;
static int usingogl;
static double exs,eys;
#else
static int exs,eys;
#endif
static int eefx;

#define NWIDTH	(256-((eoptions&EO_CLIPSIDES)?16:0))
#define NOFFSET	(eoptions&EO_CLIPSIDES?8:0)


static int paletterefresh;

/* Return 1 if video was killed, 0 otherwise(video wasn't initialized). */
int KillVideo(void)
{
 if(IconSurface)
 {
  SDL_FreeSurface(IconSurface);
  IconSurface=0;
 }

 if(inited&1)
 {
  #ifdef OPENGL
  if(usingogl)
   KillOpenGL();
  else
  #endif
  if(curbpp>8)
   KillBlitToHigh();
  SDL_QuitSubSystem(SDL_INIT_VIDEO);
  inited&=~1;
  return(1);
 }
 inited=0;
 return(0);
}

static int sponge;

int InitVideo(FCEUGI *gi)
{
 const SDL_VideoInfo *vinf;
 int flags=0;

 FCEUI_printf("Initializing video...");

 FCEUI_GetCurrentVidSystem(&srendline,&erendline);

 if(_fullscreen) sponge=Settings.specialfs;
 else sponge=Settings.special;


 #ifdef OPENGL
 usingogl=0;
 if(_opengl && sdlhaveogl && !sponge)
 {
  flags=SDL_OPENGL;
  usingogl=1;
 }
 #endif

 #ifdef EXTGUI
 GUI_SetVideo(_fullscreen, 0, 0);
 #endif

 if(!(SDL_WasInit(SDL_INIT_VIDEO)&SDL_INIT_VIDEO))
  if(SDL_InitSubSystem(SDL_INIT_VIDEO)==-1)
  {
   FCEUD_PrintError(SDL_GetError());
   return(0);
  }
 inited|=1;

 SDL_ShowCursor(0);
 tlines=erendline-srendline+1;

 vinf=SDL_GetVideoInfo();

 if(vinf->hw_available)
  flags|=SDL_HWSURFACE;

 if(_fullscreen)
  flags|=SDL_FULLSCREEN;

 flags|=SDL_HWPALETTE;

 //flags|=SDL_DOUBLEBUF;
 #ifdef OPENGL
 if(usingogl)
 {
  FCEU_printf("\n Initializing with OpenGL(Use \"-opengl 0\" to disable).\n");
  if(_doublebuf)
   SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
 }
 else
 #endif
  if(_doublebuf && (flags&SDL_HWSURFACE))
   flags|=SDL_DOUBLEBUF;

 if(_fullscreen)
 {
  int desbpp=_bpp;

  exs=_xscalefs;
  eys=_yscalefs;
  eefx=_efxfs;

  #ifdef OPENGL
  if(!usingogl) {exs=(int)exs;eys=(int)eys;}
  else desbpp=0;

  if(sponge)
  {
   exs=eys=2;
   if(sponge == 3 || sponge == 4) exs = eys = 3;
   eefx=0;
   if(sponge == 1 || sponge == 3) desbpp = 32;
  }


  if( (usingogl && !_stretchx) || !usingogl)
  #endif
   if(_xres<NWIDTH*exs || exs <= 0.01)
   {
    FCEUD_PrintError("xscale out of bounds.");
    KillVideo();
    return(0);
   }

  #ifdef OPENGL
  if( (usingogl && !_stretchy) || !usingogl)
  #endif
   if(_yres<tlines*eys || eys <= 0.01)
   {
    FCEUD_PrintError("yscale out of bounds.");
    KillVideo();
    return(0);
   }

  #ifdef EXTGUI
  GUI_SetVideo(_fullscreen, _xres, _yres);
  #endif

  #ifdef OPENGL
  if(!(screen = SDL_SetVideoMode(_xres, _yres, desbpp, flags)))
  #else
  if(!(screen = SDL_SetVideoMode(_xres, _yres, desbpp, flags)))
  #endif
  {
   FCEUD_PrintError(SDL_GetError());
   return(0);
  }
 }
 else
 {
  int desbpp=0;

  exs=_xscale;
  eys=_yscale;
  eefx=_efx;

  if(sponge) 
  {
   exs=eys=2;
   if(sponge >= 3) exs=eys=3;
   eefx=0;
   // SDL's 32bpp->16bpp code is slighty faster than mine, at least :/
   if(sponge == 1 || sponge == 3) desbpp=32;
  }

  #ifdef OPENGL
  if(!usingogl) {exs=(int)exs;eys=(int)eys;}
  if(exs <= 0.01) 
  {
   FCEUD_PrintError("xscale out of bounds.");
   KillVideo();
   return(0);
  }
  if(eys <= 0.01)
  {
   FCEUD_PrintError("yscale out of bounds.");
   KillVideo();
   return(0);
  }
  #endif

  #ifdef EXTGUI
  GUI_SetVideo(_fullscreen, (NWIDTH*exs), tlines*eys);
  #endif

  screen = SDL_SetVideoMode((NWIDTH*exs), tlines*eys, desbpp, flags);
 }
 curbpp=screen->format->BitsPerPixel;
 if(!screen)
 {
  FCEUD_PrintError(SDL_GetError());
  KillVideo();
  return(0);
 }
 //BlitBuf=SDL_CreateRGBSurface(SDL_HWSURFACE,256,240,screen->format->BitsPerPixel,screen->format->Rmask,screen->format->Gmask,screen->format->Bmask,0);

 inited=1;

 FCEU_printf(" Video Mode: %d x %d x %d bpp %s\n",screen->w,screen->h,screen->format->BitsPerPixel,_fullscreen?"full screen":"");
 if(curbpp!=16 && curbpp!=24 && curbpp!=8 && curbpp!=32)
 {
  FCEU_printf("  Sorry, %dbpp modes are not supported by FCE Ultra.  Supported bit depths are 8bpp, 16bpp, and 32bpp.\n",curbpp);
  KillVideo();
  return(0);
 }

 if(gi->name)
  SDL_WM_SetCaption(gi->name,gi->name);
 else
  SDL_WM_SetCaption("FCE Ultra","FCE Ultra");

 #ifdef LSB_FIRST
 IconSurface=SDL_CreateRGBSurfaceFrom((void *)fceu_playicon.pixel_data,32,32,24,32*3,0xFF,0xFF00,0xFF0000,0x00);
 #else
 IconSurface=SDL_CreateRGBSurfaceFrom((void *)fceu_playicon.pixel_data,32,32,24,32*3,0xFF0000,0xFF00,0xFF,0x00);
 #endif

 SDL_WM_SetIcon(IconSurface,0);

 paletterefresh=1;

 if(curbpp>8)
 #ifdef OPENGL
  if(!usingogl)
 #endif
  InitBlitToHigh(curbpp>>3,screen->format->Rmask,screen->format->Gmask,screen->format->Bmask,eefx,sponge);
 #ifdef OPENGL
 if(usingogl)
  if(!InitOpenGL((eoptions&EO_CLIPSIDES)?8:0,256-((eoptions&EO_CLIPSIDES)?8:0),srendline,erendline+1,exs,eys,eefx,_openglip,_stretchx,_stretchy,screen))
  {
   FCEUD_PrintError("Error initializing OpenGL.");
   KillVideo();
   return(0);
  }
 #endif
 return 1;
}

void ToggleFS(void)
{
 extern FCEUGI *CurGame;
 KillVideo();
 _fullscreen=!_fullscreen;

 if(!InitVideo(CurGame))
 {
  _fullscreen=!_fullscreen;
  InitVideo(CurGame);
 }
}

static SDL_Color psdl[256];
void FCEUD_SetPalette(uint8 index, uint8 r, uint8 g, uint8 b)
{
 psdl[index].r=r;
 psdl[index].g=g;
 psdl[index].b=b;

 paletterefresh=1;
}

void FCEUD_GetPalette(uint8 index, uint8 *r, uint8 *g, uint8 *b)
{
 *r=psdl[index].r;
 *g=psdl[index].g;
 *b=psdl[index].b;
}

static void RedoPalette(void)
{
 #ifdef OPENGL
 if(usingogl)
  SetOpenGLPalette((uint8*)psdl);
 else
 #endif
 {
  if(curbpp>8)
   SetPaletteBlitToHigh((uint8*)psdl); 
  else
  {
   SDL_SetPalette(screen,SDL_PHYSPAL,psdl,0,256);
  }
 }
}

void LockConsole(){}
void UnlockConsole(){}
void BlitScreen(uint8 *XBuf)
{
 SDL_Surface *TmpScreen;
 uint8 *dest;
 int xo=0,yo=0;

 if(!screen) return;

 if(paletterefresh)
 {
  RedoPalette();
  paletterefresh=0;
 }

 #ifdef OPENGL
 if(usingogl)
 {
  BlitOpenGL(XBuf);
  return;
 }
 #endif

 XBuf+=srendline*256;

 if(BlitBuf) TmpScreen=BlitBuf;
 else TmpScreen=screen;

 if(SDL_MUSTLOCK(TmpScreen))
  if(SDL_LockSurface(TmpScreen))
  {   
   return;
  }

 dest=(uint8*)TmpScreen->pixels;

 if(_fullscreen)
 {
  xo=(((TmpScreen->w-NWIDTH*exs))/2);
  dest+=xo*(curbpp>>3);
  if(TmpScreen->h>(tlines*eys))
  {
   yo=((TmpScreen->h-tlines*eys)/2);
   dest+=yo*TmpScreen->pitch;
  }
 }

 if(curbpp>8)
 {
  if(BlitBuf)
   Blit8ToHigh(XBuf+NOFFSET,dest, NWIDTH, tlines, TmpScreen->pitch,1,1);
  else
   Blit8ToHigh(XBuf+NOFFSET,dest, NWIDTH, tlines, TmpScreen->pitch,exs,eys);
 }
 else
 {
  if(BlitBuf)
   Blit8To8(XBuf+NOFFSET,dest, NWIDTH, tlines, TmpScreen->pitch,1,1,0,sponge);
  else
   Blit8To8(XBuf+NOFFSET,dest, NWIDTH, tlines, TmpScreen->pitch,exs,eys,eefx,sponge);
 }
 if(SDL_MUSTLOCK(TmpScreen))
  SDL_UnlockSurface(TmpScreen);

 if(BlitBuf)
 {
  SDL_Rect srect;
  SDL_Rect drect;

  srect.x=0;
  srect.y=0;
  srect.w=NWIDTH;
  srect.h=tlines;

  drect.x=0;
  drect.y=0;
  drect.w=exs*NWIDTH;
  drect.h=eys*tlines;

  SDL_BlitSurface(BlitBuf, &srect,screen,&drect);
 }

 SDL_UpdateRect(screen, xo, yo, NWIDTH*exs, tlines*eys);

 if(screen->flags&SDL_DOUBLEBUF)
  SDL_Flip(screen);
}

uint32 PtoV(uint16 x, uint16 y)
{
 y=(double)y/eys;
 x=(double)x/exs;
 if(eoptions&EO_CLIPSIDES)
  x+=8;
 y+=srendline;
 return(x|(y<<16));
}
