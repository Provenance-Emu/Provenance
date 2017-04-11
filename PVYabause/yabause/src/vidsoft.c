/*  Copyright 2003-2004 Guillaume Duhamel
    Copyright 2004-2008 Theo Berkau
    Copyright 2006 Fabien Coulon

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

/*! \file vidsoft.c
    \brief Software video renderer interface.
*/

#include "vidsoft.h"
#include "ygl.h"
#include "vidshared.h"
#include "debug.h"
#include "vdp2.h"
#include "titan/titan.h"

#ifdef HAVE_LIBGL
#define USE_OPENGL
#endif

#ifdef USE_OPENGL
#include "ygl.h"
#endif

#include "yui.h"

#include <stdlib.h>
#include <limits.h>

#if defined WORDS_BIGENDIAN
static INLINE u32 COLSAT2YAB16(int priority,u32 temp)            { return (priority | (temp & 0x7C00) << 1 | (temp & 0x3E0) << 14 | (temp & 0x1F) << 27); }
static INLINE u32 COLSAT2YAB32(int priority,u32 temp)            { return (((temp & 0xFF) << 24) | ((temp & 0xFF00) << 8) | ((temp & 0xFF0000) >> 8) | priority); }
static INLINE u32 COLSAT2YAB32_2(int priority,u32 temp1,u32 temp2)   { return (((temp2 & 0xFF) << 24) | ((temp2 & 0xFF00) << 8) | ((temp1 & 0xFF) << 8) | priority); }
static INLINE u32 COLSATSTRIPPRIORITY(u32 pixel)              { return (pixel | 0xFF); }
#else
static INLINE u32 COLSAT2YAB16(int priority,u32 temp) { return (priority << 24 | (temp & 0x1F) << 3 | (temp & 0x3E0) << 6 | (temp & 0x7C00) << 9); }
static INLINE u32 COLSAT2YAB32(int priority, u32 temp) { return (priority << 24 | (temp & 0xFF0000) | (temp & 0xFF00) | (temp & 0xFF)); }
static INLINE u32 COLSAT2YAB32_2(int priority,u32 temp1,u32 temp2)   { return (priority << 24 | ((temp1 & 0xFF) << 16) | (temp2 & 0xFF00) | (temp2 & 0xFF)); }
static INLINE u32 COLSATSTRIPPRIORITY(u32 pixel) { return (0xFF000000 | pixel); }
#endif

#define COLOR_ADDt(b)		(b>0xFF?0xFF:(b<0?0:b))
#define COLOR_ADDb(b1,b2)	COLOR_ADDt((signed) (b1) + (b2))
#ifdef WORDS_BIGENDIAN
#define COLOR_ADD(l,r,g,b)      (l & 0xFF) | \
                                (COLOR_ADDb((l >> 8) & 0xFF, b) << 8) | \
                                (COLOR_ADDb((l >> 16) & 0xFF, g) << 16) | \
                                (COLOR_ADDb((l >> 24), r) << 24)
#else
#define COLOR_ADD(l,r,g,b)	COLOR_ADDb((l & 0xFF), r) | \
                                (COLOR_ADDb((l >> 8) & 0xFF, g) << 8) | \
                                (COLOR_ADDb((l >> 16) & 0xFF, b) << 16) | \
				(l & 0xFF000000)
#endif

static void PushUserClipping(int mode);
static void PopUserClipping(void);

int VIDSoftInit(void);
void VIDSoftDeInit(void);
void VIDSoftResize(unsigned int, unsigned int, int);
int VIDSoftIsFullscreen(void);
int VIDSoftVdp1Reset(void);
void VIDSoftVdp1DrawStart(void);
void VIDSoftVdp1DrawEnd(void);
void VIDSoftVdp1NormalSpriteDraw(void);
void VIDSoftVdp1ScaledSpriteDraw(void);
void VIDSoftVdp1DistortedSpriteDraw(void);
void VIDSoftVdp1PolygonDraw(void);
void VIDSoftVdp1PolylineDraw(void);
void VIDSoftVdp1LineDraw(void);
void VIDSoftVdp1UserClipping(void);
void VIDSoftVdp1SystemClipping(void);
void VIDSoftVdp1LocalCoordinate(void);
int VIDSoftVdp2Reset(void);
void VIDSoftVdp2DrawStart(void);
void VIDSoftVdp2DrawEnd(void);
void VIDSoftVdp2DrawScreens(void);
void VIDSoftVdp2SetResolution(u16 TVMD);
void FASTCALL VIDSoftVdp2SetPriorityNBG0(int priority);
void FASTCALL VIDSoftVdp2SetPriorityNBG1(int priority);
void FASTCALL VIDSoftVdp2SetPriorityNBG2(int priority);
void FASTCALL VIDSoftVdp2SetPriorityNBG3(int priority);
void FASTCALL VIDSoftVdp2SetPriorityRBG0(int priority);
void VIDSoftGetGlSize(int *width, int *height);
void VIDSoftVdp1SwapFrameBuffer(void);
void VIDSoftVdp1EraseFrameBuffer(void);

VideoInterface_struct VIDSoft = {
VIDCORE_SOFT,
"Software Video Interface",
VIDSoftInit,
VIDSoftDeInit,
VIDSoftResize,
VIDSoftIsFullscreen,
VIDSoftVdp1Reset,
VIDSoftVdp1DrawStart,
VIDSoftVdp1DrawEnd,
VIDSoftVdp1NormalSpriteDraw,
VIDSoftVdp1ScaledSpriteDraw,
VIDSoftVdp1DistortedSpriteDraw,
//for the actual hardware, polygons are essentially identical to distorted sprites
//the actual hardware draws using diagonal lines, which is why using half-transparent processing
//on distorted sprites and polygons is not recommended since the hardware overdraws to prevent gaps
//thus, with half-transparent processing some pixels will be processed more than once, producing moire patterns in the drawn shapes
VIDSoftVdp1DistortedSpriteDraw,
VIDSoftVdp1PolylineDraw,
VIDSoftVdp1LineDraw,
VIDSoftVdp1UserClipping,
VIDSoftVdp1SystemClipping,
VIDSoftVdp1LocalCoordinate,
VIDSoftVdp2Reset,
VIDSoftVdp2DrawStart,
VIDSoftVdp2DrawEnd,
VIDSoftVdp2DrawScreens,
VIDSoftGetGlSize,
};

pixel_t *dispbuffer=NULL;
u8 *vdp1framebuffer[2]= { NULL, NULL };
u8 *vdp1frontframebuffer;
u8 *vdp1backframebuffer;

static int vdp1width;
static int vdp1height;
static int vdp1interlace;
static int vdp1clipxstart;
static int vdp1clipxend;
static int vdp1clipystart;
static int vdp1clipyend;
static int vdp1pixelsize;
static int vdp1spritetype;
int vdp2width;
int vdp2height;
static int nbg0priority=0;
static int nbg1priority=0;
static int nbg2priority=0;
static int nbg3priority=0;
static int rbg0priority=0;
#ifdef USE_OPENGL
static int outputwidth;
static int outputheight;
#endif
static int resxratio;
static int resyratio;

typedef struct { s16 x; s16 y; } vdp1vertex;

typedef struct
{
   int pagepixelwh, pagepixelwh_bits, pagepixelwh_mask;
   int planepixelwidth, planepixelwidth_bits, planepixelwidth_mask;
   int planepixelheight, planepixelheight_bits, planepixelheight_mask;
   int screenwidth;
   int screenheight;
   int oldcellx, oldcelly, oldcellcheck;
   int xmask, ymask;
   u32 planetbl[16];
} screeninfo_struct;

//////////////////////////////////////////////////////////////////////////////

static INLINE u32 FASTCALL Vdp2ColorRamGetColor(u32 addr)
{
   switch(Vdp2Internal.ColorMode)
   {
      case 0:
      {
         u32 tmp;
         addr <<= 1;
         tmp = T2ReadWord(Vdp2ColorRam, addr & 0xFFF);
         /* we preserve MSB for special color calculation mode 3 (see Vdp2 user's manual 3.4 and 12.3) */
         return (((tmp & 0x1F) << 3) | ((tmp & 0x03E0) << 6) | ((tmp & 0x7C00) << 9)) | ((tmp & 0x8000) << 16);
      }
      case 1:
      {
         u32 tmp;
         addr <<= 1;
         tmp = T2ReadWord(Vdp2ColorRam, addr & 0xFFF);
         /* we preserve MSB for special color calculation mode 3 (see Vdp2 user's manual 3.4 and 12.3) */
         return (((tmp & 0x1F) << 3) | ((tmp & 0x03E0) << 6) | ((tmp & 0x7C00) << 9)) | ((tmp & 0x8000) << 16);
      }
      case 2:
      {
         addr <<= 2;   
         return T2ReadLong(Vdp2ColorRam, addr & 0xFFF);
      }
      default: break;
   }

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void Vdp2PatternAddr(vdp2draw_struct *info)
{
   switch(info->patterndatasize)
   {
      case 1:
      {
         u16 tmp = T1ReadWord(Vdp2Ram, info->addr);         

         info->addr += 2;
         info->specialfunction = (info->supplementdata >> 9) & 0x1;
         info->specialcolorfunction = (info->supplementdata >> 8) & 0x1;

         switch(info->colornumber)
         {
            case 0: // in 16 colors
               info->paladdr = ((tmp & 0xF000) >> 8) | ((info->supplementdata & 0xE0) << 3);
               break;
            default: // not in 16 colors
               info->paladdr = (tmp & 0x7000) >> 4;
               break;
         }

         switch(info->auxmode)
         {
            case 0:
               info->flipfunction = (tmp & 0xC00) >> 10;

               switch(info->patternwh)
               {
                  case 1:
                     info->charaddr = (tmp & 0x3FF) | ((info->supplementdata & 0x1F) << 10);
                     break;
                  case 2:
                     info->charaddr = ((tmp & 0x3FF) << 2) | (info->supplementdata & 0x3) | ((info->supplementdata & 0x1C) << 10);
                     break;
               }
               break;
            case 1:
               info->flipfunction = 0;

               switch(info->patternwh)
               {
                  case 1:
                     info->charaddr = (tmp & 0xFFF) | ((info->supplementdata & 0x1C) << 10);
                     break;
                  case 2:
                     info->charaddr = ((tmp & 0xFFF) << 2) | (info->supplementdata & 0x3) | ((info->supplementdata & 0x10) << 10);
                     break;
               }
               break;
         }

         break;
      }
      case 2: {
         u16 tmp1 = T1ReadWord(Vdp2Ram, info->addr);
         u16 tmp2 = T1ReadWord(Vdp2Ram, info->addr+2);
         info->addr += 4;
         info->charaddr = tmp2 & 0x7FFF;
         info->flipfunction = (tmp1 & 0xC000) >> 14;
         switch(info->colornumber) {
            case 0:
               info->paladdr = (tmp1 & 0x7F) << 4;
               break;
            default:
               info->paladdr = ((tmp1 & 0x70) << 4);
               break;
         }
         info->specialfunction = (tmp1 & 0x2000) >> 13;
         info->specialcolorfunction = (tmp1 & 0x1000) >> 12;
         break;
      }
   }

   if (!(Vdp2Regs->VRSIZE & 0x8000))
      info->charaddr &= 0x3FFF;

   info->charaddr *= 0x20; // selon Runik
   if (info->specialprimode == 1) {
      info->priority = (info->priority & 0xE) | (info->specialfunction & 1);
   }
}

//////////////////////////////////////////////////////////////////////////////

static INLINE u32 FASTCALL DoNothing(UNUSED void *info, u32 pixel)
{
   return pixel;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE u32 FASTCALL DoColorOffset(void *info, u32 pixel)
{
    return COLOR_ADD(pixel, ((vdp2draw_struct *)info)->cor,
                     ((vdp2draw_struct *)info)->cog,
                     ((vdp2draw_struct *)info)->cob);
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void ReadVdp2ColorOffset(Vdp2 * regs, vdp2draw_struct *info, int clofmask, int ccmask)
{
   if (regs->CLOFEN & clofmask)
   {
      // color offset enable
      if (regs->CLOFSL & clofmask)
      {
         // color offset B
         info->cor = regs->COBR & 0xFF;
         if (regs->COBR & 0x100)
            info->cor |= 0xFFFFFF00;

         info->cog = regs->COBG & 0xFF;
         if (regs->COBG & 0x100)
            info->cog |= 0xFFFFFF00;

         info->cob = regs->COBB & 0xFF;
         if (regs->COBB & 0x100)
            info->cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         info->cor = regs->COAR & 0xFF;
         if (regs->COAR & 0x100)
            info->cor |= 0xFFFFFF00;

         info->cog = regs->COAG & 0xFF;
         if (regs->COAG & 0x100)
            info->cog |= 0xFFFFFF00;

         info->cob = regs->COAB & 0xFF;
         if (regs->COAB & 0x100)
            info->cob |= 0xFFFFFF00;
      }

      info->PostPixelFetchCalc = &DoColorOffset;
   }
   else // color offset disable
      info->PostPixelFetchCalc = &DoNothing;

}

//////////////////////////////////////////////////////////////////////////////

static INLINE int Vdp2FetchPixel(vdp2draw_struct *info, int x, int y, u32 *color, u32 *dot)
{
   switch(info->colornumber)
   {
      case 0: // 4 BPP
         *dot = T1ReadByte(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) / 2) & 0x7FFFF));
         if (!(x & 0x1)) *dot >>= 4;
         if (!(*dot & 0xF) && info->transparencyenable) return 0;
         else
         {
            *color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | (*dot & 0xF)));
            return 1;
         }
      case 1: // 8 BPP
         *dot = T1ReadByte(Vdp2Ram, ((info->charaddr + (y * info->cellw) + x) & 0x7FFFF));
         if (!(*dot & 0xFF) && info->transparencyenable) return 0;
         else
         {
            *color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | (*dot & 0xFF)));
            return 1;
         }
      case 2: // 16 BPP(palette)
         *dot = T1ReadWord(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) * 2) & 0x7FFFF));
         if ((*dot == 0) && info->transparencyenable) return 0;
         else
         {
            *color = Vdp2ColorRamGetColor(info->coloroffset + *dot);
            return 1;
         }
      case 3: // 16 BPP(RGB)      
         *dot = T1ReadWord(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) * 2) & 0x7FFFF));
         if (!(*dot & 0x8000) && info->transparencyenable) return 0;
         else
         {
            *color = COLSAT2YAB16(0, *dot);
            return 1;
         }
      case 4: // 32 BPP
         *dot = T1ReadLong(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) * 4) & 0x7FFFF));
         if (!(*dot & 0x80000000) && info->transparencyenable) return 0;
         else
         {
            *color = COLSAT2YAB32(0, *dot);
            return 1;
         }
      default:
         return 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

static INLINE int TestWindow(int wctl, int enablemask, int inoutmask, clipping_struct *clip, int x, int y)
{
   if (wctl & enablemask) 
   {
      if (wctl & inoutmask)
      {
         // Draw inside of window
         if (x < clip->xstart || x > clip->xend ||
             y < clip->ystart || y > clip->yend)
            return 0;
      }
      else
      {
         // Draw outside of window
         if (x >= clip->xstart && x <= clip->xend &&
             y >= clip->ystart && y <= clip->yend)
            return 0;

		 //it seems to overflow vertically on hardware
		 if(clip->yend > vdp2height && (x >= clip->xstart && x <= clip->xend ))
			 return 0;
      }
      return 1; // return inactive;
   }
   return 3; // return disabled | inactive;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE int TestBothWindow(int wctl, clipping_struct *clip, int x, int y)
{
    int w0 = TestWindow(wctl, 0x2, 0x1, &clip[0], x, y);
    int w1 = TestWindow(wctl, 0x8, 0x4, &clip[1], x, y);

    /* if window 0 is disabled, return window 1 */
    if (w0 & 2) return w1 & 1;
    /* if window 1 is disabled, return window 0 */
    if (w1 & 2) return w0 & 1;

    /* if both windows are active */
    if ((wctl & 0x80) == 0x80)
        /* AND logic, returns 0 only if both the windows are active */
        return w0 || w1;
    else
        /* OR logic, returns 0 if one of the windows is active */
        return w0 && w1;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void GeneratePlaneAddrTable(vdp2draw_struct *info, u32 *planetbl, void FASTCALL (* PlaneAddr)(void *, int))
{
   int i;

   for (i = 0; i < (info->mapwh*info->mapwh); i++)
   {
      PlaneAddr(info, i);
      planetbl[i] = info->addr;
   }
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void FASTCALL Vdp2MapCalcXY(vdp2draw_struct *info, int *x, int *y,
                                 screeninfo_struct *sinfo)
{
   int planenum;
   const int pagesize_bits=info->pagewh_bits*2;
   const int cellwh=(2 + info->patternwh);

   const int check = ((y[0] >> cellwh) << 16) | (x[0] >> cellwh);
   //if ((x[0] >> cellwh) != sinfo->oldcellx || (y[0] >> cellwh) != sinfo->oldcelly)
   if(check != sinfo->oldcellcheck)
   {
      sinfo->oldcellx = x[0] >> cellwh;
      sinfo->oldcelly = y[0] >> cellwh;
	  sinfo->oldcellcheck = (sinfo->oldcelly << 16) | sinfo->oldcellx;

      // Calculate which plane we're dealing with
      planenum = ((y[0] >> sinfo->planepixelheight_bits) * info->mapwh) + (x[0] >> sinfo->planepixelwidth_bits);
      x[0] = (x[0] & sinfo->planepixelwidth_mask);
      y[0] = (y[0] & sinfo->planepixelheight_mask);

      // Fetch and decode pattern name data
      info->addr = sinfo->planetbl[planenum];

      // Figure out which page it's on(if plane size is not 1x1)
      info->addr += ((  ((y[0] >> sinfo->pagepixelwh_bits) << pagesize_bits) << info->planew_bits) +
                     (   (x[0] >> sinfo->pagepixelwh_bits) << pagesize_bits) +
                     (((y[0] & sinfo->pagepixelwh_mask) >> cellwh) << info->pagewh_bits) +
                     ((x[0] & sinfo->pagepixelwh_mask) >> cellwh)) << (info->patterndatasize_bits+1);

      Vdp2PatternAddr(info); // Heh, this could be optimized
   }

   // Figure out which pixel in the tile we want
   if (info->patternwh == 1)
   {
      x[0] &= 8-1;
      y[0] &= 8-1;

	  switch(info->flipfunction & 0x3)
	  {
	  case 0: //none
		  break;
	  case 1: //horizontal flip
		  x[0] = 8 - 1 - x[0];
		  break;
	  case 2: // vertical flip
         y[0] = 8 - 1 - y[0];
		 break;
	  case 3: //flip both
         x[0] = 8 - 1 - x[0];
		 y[0] = 8 - 1 - y[0];
		 break;
	  }
   }
   else
   {
      if (info->flipfunction)
      {
         y[0] &= 16 - 1;
         if (info->flipfunction & 0x2)
         {
            if (!(y[0] & 8))
               y[0] = 8 - 1 - y[0] + 16;
            else
               y[0] = 16 - 1 - y[0];
         }
         else if (y[0] & 8)
            y[0] += 8;

         if (info->flipfunction & 0x1)
         {
            if (!(x[0] & 8))
               y[0] += 8;

            x[0] &= 8-1;
            x[0] = 8 - 1 - x[0];
         }
         else if (x[0] & 8)
         {
            y[0] += 8;
            x[0] &= 8-1;
         }
         else
            x[0] &= 8-1;
      }
      else
      {
         y[0] &= 16 - 1;

         if (y[0] & 8)
            y[0] += 8;
         if (x[0] & 8)
            y[0] += 8;
         x[0] &= 8-1;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void SetupScreenVars(vdp2draw_struct *info, screeninfo_struct *sinfo, void FASTCALL (* PlaneAddr)(void *, int))
{
   if (!info->isbitmap)
   {
      sinfo->pagepixelwh=64*8;
	  sinfo->pagepixelwh_bits = 9;
	  sinfo->pagepixelwh_mask = 511;

      sinfo->planepixelwidth=info->planew*sinfo->pagepixelwh;
	  sinfo->planepixelwidth_bits = 8+info->planew;
	  sinfo->planepixelwidth_mask = (1<<(sinfo->planepixelwidth_bits))-1;

      sinfo->planepixelheight=info->planeh*sinfo->pagepixelwh;
	  sinfo->planepixelheight_bits = 8+info->planeh;
	  sinfo->planepixelheight_mask = (1<<(sinfo->planepixelheight_bits))-1;

      sinfo->screenwidth=info->mapwh*sinfo->planepixelwidth;
      sinfo->screenheight=info->mapwh*sinfo->planepixelheight;
      sinfo->oldcellx=-1;
      sinfo->oldcelly=-1;
      sinfo->oldcellcheck=-1;
      sinfo->xmask = sinfo->screenwidth-1;
      sinfo->ymask = sinfo->screenheight-1;
      GeneratePlaneAddrTable(info, sinfo->planetbl, PlaneAddr);
   }
   else
   {
      sinfo->pagepixelwh = 0;
	  sinfo->pagepixelwh_bits = 0;
	  sinfo->pagepixelwh_mask = 0;
      sinfo->planepixelwidth=0;
	  sinfo->planepixelwidth_bits=0;
	  sinfo->planepixelwidth_mask=0;
      sinfo->planepixelheight=0;
	  sinfo->planepixelheight_bits=0;
	  sinfo->planepixelheight_mask=0;
      sinfo->screenwidth=0;
      sinfo->screenheight=0;
      sinfo->oldcellx=0;
      sinfo->oldcelly=0;
      sinfo->oldcellcheck=0;
      sinfo->xmask = info->cellw-1;
      sinfo->ymask = info->cellh-1;
   }
}

//////////////////////////////////////////////////////////////////////////////

static u8 FASTCALL GetAlpha(vdp2draw_struct * info, u32 color, u32 dot)
{
   if (((info->specialcolormode == 1) || (info->specialcolormode == 2)) && ((info->specialcolorfunction & 1) == 0)) {
      /* special color calculation mode 1 and 2 enables color calculation only when special color function = 1 */
      return 0x3F;
   } else if (info->specialcolormode == 2) {
      /* special color calculation 2 enables color calculation according to lower bits of the color code */
      if ((info->specialcode & (1 << ((dot & 0xF) >> 1))) == 0) {
         return 0x3F;
      }
   } else if ((info->specialcolormode == 3) && ((color & 0x80000000) == 0)) {
      /* special color calculation mode 3 enables color calculation only for dots with MSB = 1 */
      return 0x3F;
   }
   return info->alpha;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL Vdp2DrawScroll(vdp2draw_struct *info)
{
   int i, j;
   int x, y;
   clipping_struct clip[2];
   u32 linewnd0addr, linewnd1addr;
   screeninfo_struct sinfo;
   int scrolly;
   int *mosaic_y, *mosaic_x;
   clipping_struct colorcalcwindow[2];

   info->coordincx *= (float)resxratio;
   info->coordincy *= (float)resyratio;

   SetupScreenVars(info, &sinfo, info->PlaneAddr);

   scrolly = info->y;

   clip[0].xstart = clip[0].ystart = clip[0].xend = clip[0].yend = 0;
   clip[1].xstart = clip[1].ystart = clip[1].xend = clip[1].yend = 0;
   ReadWindowData(info->wctl, clip);
   linewnd0addr = linewnd1addr = 0;
   ReadLineWindowData(&info->islinewindow, info->wctl, &linewnd0addr, &linewnd1addr);
   /* color calculation window: in => no color calc, out => color calc */
   ReadWindowData(Vdp2Regs->WCTLD >> 8, colorcalcwindow);
   {
	   static int tables_initialized = 0;
	   static int mosaic_table[16][1024];
	   if(!tables_initialized)
	   {
		   tables_initialized = 1;
			for(i=0;i<16;i++)
			{
				int m = i+1;
				for(j=0;j<1024;j++)
					mosaic_table[i][j] = j/m*m;
			}
	   }
	   mosaic_x = mosaic_table[info->mosaicxmask-1];
	   mosaic_y = mosaic_table[info->mosaicymask-1];
   }

   for (j = 0; j < vdp2height; j++)
   {
      int Y;
      int linescrollx = 0;
      // precalculate the coordinate for the line(it's faster) and do line
      // scroll
      if (info->islinescroll)
      {
         if (info->islinescroll & 0x1)
         {
            linescrollx = (T1ReadLong(Vdp2Ram, info->linescrolltbl) >> 16) & 0x7FF;
            info->linescrolltbl += 4;
         }
         if (info->islinescroll & 0x2)
         {
            info->y = ((T1ReadWord(Vdp2Ram, info->linescrolltbl) & 0x7FF) * resyratio) + scrolly;
            info->linescrolltbl += 4;
            y = info->y;
         }
         else
            //y = info->y+((int)(info->coordincy *(float)(info->mosaicymask > 1 ? (j / info->mosaicymask * info->mosaicymask) : j)));
			y = info->y + info->coordincy*mosaic_y[j];
         if (info->islinescroll & 0x4)
         {
            info->coordincx = (T1ReadLong(Vdp2Ram, info->linescrolltbl) & 0x7FF00) / (float)65536.0;
            info->coordincx *= resxratio;
            info->linescrolltbl += 4;
         }
      }
      else
         //y = info->y+((int)(info->coordincy *(float)(info->mosaicymask > 1 ? (j / info->mosaicymask * info->mosaicymask) : j)));
		 y = info->y + info->coordincy*mosaic_y[j];

      // if line window is enabled, adjust clipping values
      ReadLineWindowClip(info->islinewindow, clip, &linewnd0addr, &linewnd1addr);
      y &= sinfo.ymask;

      if (info->isverticalscroll)
      {
         // this is *wrong*, vertical scroll use a different value per cell
         // info->verticalscrolltbl should be incremented by info->verticalscrollinc
         // each time there's a cell change and reseted at the end of the line...
         // or something like that :)
         y += T1ReadLong(Vdp2Ram, info->verticalscrolltbl) >> 16;
         y &= 0x1FF;
      }

      Y=y;

      info->LoadLineParams(info, j);

      for (i = 0; i < vdp2width; i++)
      {
         u32 color, dot;
         /* I'm really not sure about this... but I think the way we handle
         high resolution gets in the way with window process. I may be wrong...
         This was added for Cotton Boomerang */
         int resxi = i * resxratio;

         // See if screen position is clipped, if it isn't, continue
         if (!TestBothWindow(info->wctl, clip, resxi, j))
         {
            continue;
         }

         //x = info->x+((int)(info->coordincx*(float)((info->mosaicxmask > 1) ? (i / info->mosaicxmask * info->mosaicxmask) : i)));
		 x = info->x + mosaic_x[i]*info->coordincx;
         x &= sinfo.xmask;
		 
         if (linescrollx) {
            x += linescrollx;
            x &= 0x3FF;
         }

         // Fetch Pixel, if it isn't transparent, continue
         if (!info->isbitmap)
         {
            // Tile
            y=Y;
            Vdp2MapCalcXY(info, &x, &y, &sinfo);
         }

         if (!Vdp2FetchPixel(info, x, y, &color, &dot))
         {
            continue;
         }

         // check special priority somewhere here

         // Apply color offset and color calculation/special color calculation
         // and then continue.
         // We almost need to know well ahead of time what the top
         // and second pixel is in order to work this.

         {
            u8 alpha;
            /* if we're in the valid area of the color calculation window, don't do color calculation */
            if (!TestBothWindow(Vdp2Regs->WCTLD >> 8, colorcalcwindow, i, j))
               alpha = 0x3F;
            else
               alpha = GetAlpha(info, color, dot);

            TitanPutPixel(info->priority, i, j, info->PostPixelFetchCalc(info, COLSAT2YAB32(alpha, color)), info->linescreen);
         }
      }
   }    
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL Vdp2DrawRotationFP(vdp2draw_struct *info, vdp2rotationparameterfp_struct *parameter)
{
   int i, j;
   int x, y;
   screeninfo_struct sinfo;
   vdp2rotationparameterfp_struct *p=&parameter[info->rotatenum];
   clipping_struct clip[2];
   u32 linewnd0addr, linewnd1addr;

   clip[0].xstart = clip[0].ystart = clip[0].xend = clip[0].yend = 0;
   clip[1].xstart = clip[1].ystart = clip[1].xend = clip[1].yend = 0;
   ReadWindowData(info->wctl, clip);
   linewnd0addr = linewnd1addr = 0;
   ReadLineWindowData(&info->islinewindow, info->wctl, &linewnd0addr, &linewnd1addr);

   Vdp2ReadRotationTableFP(info->rotatenum, p);

   if (!p->coefenab)
   {
      fixed32 xmul, ymul, C, F;

      // Since coefficients aren't being used, we can simplify the drawing process
      if (IsScreenRotatedFP(p))
      {
         // No rotation
         info->x = touint(mulfixed(p->kx, (p->Xst - p->Px)) + p->Px + p->Mx);
         info->y = touint(mulfixed(p->ky, (p->Yst - p->Py)) + p->Py + p->My);
         info->coordincx = tofloat(p->kx);
         info->coordincy = tofloat(p->ky);
      }
      else
      {
         GenerateRotatedVarFP(p, &xmul, &ymul, &C, &F);

         // Do simple rotation
         CalculateRotationValuesFP(p);

         SetupScreenVars(info, &sinfo, info->PlaneAddr);

         for (j = 0; j < vdp2height; j++)
         {
            info->LoadLineParams(info, j);
            ReadLineWindowClip(info->islinewindow, clip, &linewnd0addr, &linewnd1addr);

            for (i = 0; i < vdp2width; i++)
            {
               u32 color, dot;

               if (!TestBothWindow(info->wctl, clip, i, j))
                  continue;

               x = GenerateRotatedXPosFP(p, i, xmul, ymul, C) & sinfo.xmask;
               y = GenerateRotatedYPosFP(p, i, xmul, ymul, F) & sinfo.ymask;

               // Convert coordinates into graphics
               if (!info->isbitmap)
               {
                  // Tile
                  Vdp2MapCalcXY(info, &x, &y, &sinfo);
               }
 
               // Fetch pixel
               if (!Vdp2FetchPixel(info, x, y, &color, &dot))
               {
                  continue;
               }

               TitanPutPixel(info->priority, i, j, info->PostPixelFetchCalc(info, COLSAT2YAB32(GetAlpha(info, color, dot), color)), info->linescreen);
            }
            xmul += p->deltaXst;
            ymul += p->deltaYst;
         }

         return;
      }
   }
   else
   {
      fixed32 xmul, ymul, C, F;
      u32 coefx, coefy;
      u32 rcoefx, rcoefy;
      u32 lineAddr, lineColor, lineInc;
      u16 lineColorAddr;

      fixed32 xmul2, ymul2, C2, F2;
      u32 coefx2, coefy2;
      u32 rcoefx2, rcoefy2;
      screeninfo_struct sinfo2;
      vdp2rotationparameterfp_struct *p2 = NULL;

      clipping_struct rpwindow[2];
      int userpwindow = 0;
      int isrplinewindow = 0;
      u32 rplinewnd0addr, rplinewnd1addr;

      if ((Vdp2Regs->RPMD & 3) == 2)
         p2 = &parameter[1 - info->rotatenum];
      else if ((Vdp2Regs->RPMD & 3) == 3)
      {
         ReadWindowData(Vdp2Regs->WCTLD, rpwindow);
         rplinewnd0addr = rplinewnd1addr = 0;
         ReadLineWindowData(&isrplinewindow, Vdp2Regs->WCTLD, &rplinewnd0addr, &rplinewnd1addr);
         userpwindow = 1;
         p2 = &parameter[1 - info->rotatenum];
      }

      GenerateRotatedVarFP(p, &xmul, &ymul, &C, &F);

      // Rotation using Coefficient Tables(now this stuff just gets wacky. It
      // has to be done in software, no exceptions)
      CalculateRotationValuesFP(p);

      SetupScreenVars(info, &sinfo, p->PlaneAddr);
      coefx = coefy = 0;
      rcoefx = rcoefy = 0;

      if (p2 != NULL)
      {
         Vdp2ReadRotationTableFP(1 - info->rotatenum, p2);
         GenerateRotatedVarFP(p2, &xmul2, &ymul2, &C2, &F2);
         CalculateRotationValuesFP(p2);
         SetupScreenVars(info, &sinfo2, p2->PlaneAddr);
         coefx2 = coefy2 = 0;
         rcoefx2 = rcoefy2 = 0;
      }

      if (info->linescreen)
      {
         if ((info->rotatenum == 0) && (Vdp2Regs->KTCTL & 0x10))
            info->linescreen = 2;
         else if (Vdp2Regs->KTCTL & 0x1000)
            info->linescreen = 3;
         if (Vdp2Regs->VRSIZE & 0x8000)
            lineAddr = (Vdp2Regs->LCTA.all & 0x7FFFF) << 1;
         else
            lineAddr = (Vdp2Regs->LCTA.all & 0x3FFFF) << 1;

         lineInc = Vdp2Regs->LCTA.part.U & 0x8000 ? 2 : 0;
      }

      for (j = 0; j < vdp2height; j++)
      {
         if (p->deltaKAx == 0)
         {
            Vdp2ReadCoefficientFP(p,
                                  p->coeftbladdr +
                                  (coefy + touint(rcoefy)) *
                                  p->coefdatasize);
         }
         if ((p2 != NULL) && p2->coefenab && (p2->deltaKAx == 0))
         {
            Vdp2ReadCoefficientFP(p2,
                                  p2->coeftbladdr +
                                  (coefy2 + touint(rcoefy2)) *
                                  p2->coefdatasize);
         }

         if (info->linescreen > 1)
         {
            lineColorAddr = (T1ReadWord(Vdp2Ram, lineAddr) & 0x780) | p->linescreen;
            lineColor = Vdp2ColorRamGetColor(lineColorAddr);
            lineAddr += lineInc;
            TitanPutLineHLine(info->linescreen, j, COLSAT2YAB32(0x3F, lineColor));
         }

         info->LoadLineParams(info, j);
         ReadLineWindowClip(info->islinewindow, clip, &linewnd0addr, &linewnd1addr);

         if (userpwindow)
            ReadLineWindowClip(isrplinewindow, rpwindow, &rplinewnd0addr, &rplinewnd1addr);

         for (i = 0; i < vdp2width; i++)
         {
            u32 color, dot;

            if (p->deltaKAx != 0)
            {
               Vdp2ReadCoefficientFP(p,
                                     p->coeftbladdr +
                                     (coefy + coefx + toint(rcoefx + rcoefy)) *
                                     p->coefdatasize);
               coefx += toint(p->deltaKAx);
               rcoefx += decipart(p->deltaKAx);
            }
            if ((p2 != NULL) && p2->coefenab && (p2->deltaKAx != 0))
            {
               Vdp2ReadCoefficientFP(p2,
                                     p2->coeftbladdr +
                                     (coefy2 + coefx2 + toint(rcoefx2 + rcoefy2)) *
                                     p2->coefdatasize);
               coefx2 += toint(p2->deltaKAx);
               rcoefx2 += decipart(p2->deltaKAx);
            }

            if (!TestBothWindow(info->wctl, clip, i, j))
               continue;

            if (((! userpwindow) && p->msb) || (userpwindow && (! TestBothWindow(Vdp2Regs->WCTLD, rpwindow, i, j))))
            {
               if ((p2 == NULL) || (p2->coefenab && p2->msb)) continue;

               x = GenerateRotatedXPosFP(p2, i, xmul2, ymul2, C2);
               y = GenerateRotatedYPosFP(p2, i, xmul2, ymul2, F2);

               switch(p2->screenover) {
                  case 0:
                     x &= sinfo2.xmask;
                     y &= sinfo2.ymask;
                     break;
                  case 1:
                     VDP2LOG("Screen-over mode 1 not implemented");
                     x &= sinfo2.xmask;
                     y &= sinfo2.ymask;
                     break;
                  case 2:
                     if ((x > sinfo2.xmask) || (y > sinfo2.ymask)) continue;
                     break;
                  case 3:
                     if ((x > 512) || (y > 512)) continue;
               }

               // Convert coordinates into graphics
               if (!info->isbitmap)
               {
                  // Tile
                  Vdp2MapCalcXY(info, &x, &y, &sinfo2);
               }
            }
            else if (p->msb) continue;
            else
            {
               x = GenerateRotatedXPosFP(p, i, xmul, ymul, C);
               y = GenerateRotatedYPosFP(p, i, xmul, ymul, F);

               switch(p->screenover) {
                  case 0:
                     x &= sinfo.xmask;
                     y &= sinfo.ymask;
                     break;
                  case 1:
                     VDP2LOG("Screen-over mode 1 not implemented");
                     x &= sinfo.xmask;
                     y &= sinfo.ymask;
                     break;
                  case 2:
                     if ((x > sinfo.xmask) || (y > sinfo.ymask)) continue;
                     break;
                  case 3:
                     if ((x > 512) || (y > 512)) continue;
               }

               // Convert coordinates into graphics
               if (!info->isbitmap)
               {
                  // Tile
                  Vdp2MapCalcXY(info, &x, &y, &sinfo);
               }
            }

            // Fetch pixel
            if (!Vdp2FetchPixel(info, x, y, &color, &dot))
            {
               continue;
            }

            TitanPutPixel(info->priority, i, j, info->PostPixelFetchCalc(info, COLSAT2YAB32(GetAlpha(info, color, dot), color)), info->linescreen);
         }
         xmul += p->deltaXst;
         ymul += p->deltaYst;
         coefx = 0;
         rcoefx = 0;
         coefy += toint(p->deltaKAst);
         rcoefy += decipart(p->deltaKAst);

         if (p2 != NULL)
         {
            xmul2 += p2->deltaXst;
            ymul2 += p2->deltaYst;
            if (p2->coefenab)
            {
               coefx2 = 0;
               rcoefx2 = 0;
               coefy2 += toint(p2->deltaKAst);
               rcoefy2 += decipart(p2->deltaKAst);
            }
         }
      }
      return;
   }

   Vdp2DrawScroll(info);
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawBackScreen(void)
{
   int i, j;

   // Only draw black if TVMD's DISP and BDCLMD bits are cleared
   if ((Vdp2Regs->TVMD & 0x8000) == 0 && (Vdp2Regs->TVMD & 0x100) == 0)
   {
      // Draw Black
      for (j = 0; j < vdp2height; j++)
         TitanPutBackHLine(j, COLSAT2YAB32(0x3F, 0));
   }
   else
   {
      // Draw Back Screen
      u32 scrAddr;
      u16 dot;

      if (Vdp2Regs->VRSIZE & 0x8000)
         scrAddr = (((Vdp2Regs->BKTAU & 0x7) << 16) | Vdp2Regs->BKTAL) * 2;
      else
         scrAddr = (((Vdp2Regs->BKTAU & 0x3) << 16) | Vdp2Regs->BKTAL) * 2;

      if (Vdp2Regs->BKTAU & 0x8000)
      {
         // Per Line
         for (i = 0; i < vdp2height; i++)
         {
            dot = T1ReadWord(Vdp2Ram, scrAddr);
            scrAddr += 2;

            TitanPutBackHLine(i, COLSAT2YAB16(0x3F, dot));
         }
      }
      else
      {
         // Single Color
         dot = T1ReadWord(Vdp2Ram, scrAddr);

         for (j = 0; j < vdp2height; j++)
            TitanPutBackHLine(j, COLSAT2YAB16(0x3F, dot));
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawLineScreen(void)
{
   u32 scrAddr;
   u16 color;
   u32 dot;
   int i;

   /* no need to go further if no screen is using the line screen */
   if (Vdp2Regs->LNCLEN == 0)
      return;

   if (Vdp2Regs->VRSIZE & 0x8000)
      scrAddr = (Vdp2Regs->LCTA.all & 0x7FFFF) << 1;
   else
      scrAddr = (Vdp2Regs->LCTA.all & 0x3FFFF) << 1;

   if (Vdp2Regs->LCTA.part.U & 0x8000)
   {
      /* per line */
      for (i = 0; i < vdp2height; i++)
      {
         color = T1ReadWord(Vdp2Ram, scrAddr) & 0x7FF;
         dot = Vdp2ColorRamGetColor(color);
         scrAddr += 2;

         TitanPutLineHLine(1, i, COLSAT2YAB32(0x3F, dot));
      }
   }
   else
   {
      /* single color, implemented but not tested... */
      color = T1ReadWord(Vdp2Ram, scrAddr) & 0x7FF;
      dot = Vdp2ColorRamGetColor(color);
      for (i = 0; i < vdp2height; i++)
         TitanPutLineHLine(1, i, COLSAT2YAB32(0x3F, dot));
   }
}

//////////////////////////////////////////////////////////////////////////////

static void LoadLineParamsNBG0(vdp2draw_struct * info, int line)
{
   Vdp2 * regs;

   regs = Vdp2RestoreRegs(line);
   if (regs == NULL) return;
   ReadVdp2ColorOffset(regs, info, 0x1, 0x1);
   info->specialprimode = regs->SFPRMD & 0x3;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG0(void)
{
   vdp2draw_struct info;
   vdp2rotationparameterfp_struct parameter[2];

   parameter[0].PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterAPlaneAddr;
   parameter[1].PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterBPlaneAddr;

   if (Vdp2Regs->BGON & 0x20)
   {
      // RBG1 mode
      info.enable = Vdp2Regs->BGON & 0x20;

      // Read in Parameter B
      Vdp2ReadRotationTableFP(1, &parameter[1]);

      if((info.isbitmap = Vdp2Regs->CHCTLA & 0x2) != 0)
      {
         // Bitmap Mode
         ReadBitmapSize(&info, Vdp2Regs->CHCTLA >> 2, 0x3);

         info.charaddr = (Vdp2Regs->MPOFR & 0x70) * 0x2000;
         info.paladdr = (Vdp2Regs->BMPNA & 0x7) << 8;
         info.flipfunction = 0;
         info.specialfunction = 0;
         info.specialcolorfunction = (Vdp2Regs->BMPNA & 0x10) >> 4;
      }
      else
      {
         // Tile Mode
         info.mapwh = 4;
         ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 12);
         ReadPatternData(&info, Vdp2Regs->PNCN0, Vdp2Regs->CHCTLA & 0x1);
      }

      info.rotatenum = 1;
      info.rotatemode = 0;
      info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterBPlaneAddr;
   }
   else if (Vdp2Regs->BGON & 0x1)
   {
      // NBG0 mode
      info.enable = Vdp2Regs->BGON & 0x1;

      if((info.isbitmap = Vdp2Regs->CHCTLA & 0x2) != 0)
      {
         // Bitmap Mode
         ReadBitmapSize(&info, Vdp2Regs->CHCTLA >> 2, 0x3);

         info.x = Vdp2Regs->SCXIN0 & 0x7FF;
         info.y = Vdp2Regs->SCYIN0 & 0x7FF;

         info.charaddr = (Vdp2Regs->MPOFN & 0x7) * 0x20000;
         info.paladdr = (Vdp2Regs->BMPNA & 0x7) << 8;
         info.flipfunction = 0;
         info.specialfunction = 0;
         info.specialcolorfunction = (Vdp2Regs->BMPNA & 0x10) >> 4;
      }
      else
      {
         // Tile Mode
         info.mapwh = 2;

         ReadPlaneSize(&info, Vdp2Regs->PLSZ);

         info.x = Vdp2Regs->SCXIN0 & 0x7FF;
         info.y = Vdp2Regs->SCYIN0 & 0x7FF;
         ReadPatternData(&info, Vdp2Regs->PNCN0, Vdp2Regs->CHCTLA & 0x1);
      }

      info.coordincx = (Vdp2Regs->ZMXN0.all & 0x7FF00) / (float) 65536;
      info.coordincy = (Vdp2Regs->ZMYN0.all & 0x7FF00) / (float) 65536;
      info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG0PlaneAddr;
   }
   else
      // Not enabled
      return;

   info.transparencyenable = !(Vdp2Regs->BGON & 0x100);
   info.specialprimode = Vdp2Regs->SFPRMD & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLA & 0x70) >> 4;

   if (Vdp2Regs->CCCTL & 0x201)
      info.alpha = ((~Vdp2Regs->CCRNA & 0x1F) << 1) + 1;
   else
      info.alpha = 0x3F;
   if ((Vdp2Regs->CCCTL & 0x201) == 0x201) info.alpha |= 0x80;
   else if ((Vdp2Regs->CCCTL & 0x101) == 0x101) info.alpha |= 0x80;
   info.specialcolormode = Vdp2Regs->SFCCMD & 0x3;
   if (Vdp2Regs->SFSEL & 0x1)
      info.specialcode = Vdp2Regs->SFCODE >> 8;
   else
      info.specialcode = Vdp2Regs->SFCODE & 0xFF;
   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x1)
      info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7) << 8;
   ReadVdp2ColorOffset(Vdp2Regs, &info, 0x1, 0x1);
   info.priority = nbg0priority;

   if (!(info.enable & Vdp2External.disptoggle))
      return;

   ReadMosaicData(&info, 0x1);
   ReadLineScrollData(&info, Vdp2Regs->SCRCTL & 0xFF, Vdp2Regs->LSTA0.all);
   if (Vdp2Regs->SCRCTL & 1)
   {
      info.isverticalscroll = 1;
      info.verticalscrolltbl = (Vdp2Regs->VCSTA.all & 0x7FFFE) << 1;
      if (Vdp2Regs->SCRCTL & 0x100)
         info.verticalscrollinc = 8;
      else
         info.verticalscrollinc = 4;
   }
   else
      info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLA;

   info.LoadLineParams = (void (*)(void *, int)) LoadLineParamsNBG0;

   if (info.enable == 1)
   {
      // NBG0 draw
      Vdp2DrawScroll(&info);
   }
   else
   {
      // RBG1 draw
      Vdp2DrawRotationFP(&info, parameter);
   }
}

//////////////////////////////////////////////////////////////////////////////

static void LoadLineParamsNBG1(vdp2draw_struct * info, int line)
{
   Vdp2 * regs;

   regs = Vdp2RestoreRegs(line);
   if (regs == NULL) return;
   ReadVdp2ColorOffset(regs, info, 0x2, 0x2);
   info->specialprimode = (regs->SFPRMD >> 2) & 0x3;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG1(void)
{
   vdp2draw_struct info;

   info.enable = Vdp2Regs->BGON & 0x2;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x200);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 2) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLA & 0x3000) >> 12;

   if((info.isbitmap = Vdp2Regs->CHCTLA & 0x200) != 0)
   {
      ReadBitmapSize(&info, Vdp2Regs->CHCTLA >> 10, 0x3);

      info.x = Vdp2Regs->SCXIN1 & 0x7FF;
      info.y = Vdp2Regs->SCYIN1 & 0x7FF;

      info.charaddr = ((Vdp2Regs->MPOFN & 0x70) >> 4) * 0x20000;
      info.paladdr = Vdp2Regs->BMPNA & 0x700;
      info.flipfunction = 0;
      info.specialfunction = 0;
      info.specialcolorfunction = (Vdp2Regs->BMPNA & 0x1000) >> 12;
   }
   else
   {
      info.mapwh = 2;

      ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 2);

      info.x = Vdp2Regs->SCXIN1 & 0x7FF;
      info.y = Vdp2Regs->SCYIN1 & 0x7FF;

      ReadPatternData(&info, Vdp2Regs->PNCN1, Vdp2Regs->CHCTLA & 0x100);
   }

   if (Vdp2Regs->CCCTL & 0x202)
      info.alpha = ((~Vdp2Regs->CCRNA & 0x1F00) >> 7) + 1;
   else
      info.alpha = 0x3F;
   if ((Vdp2Regs->CCCTL & 0x202) == 0x202) info.alpha |= 0x80;
   else if ((Vdp2Regs->CCCTL & 0x102) == 0x102) info.alpha |= 0x80;
   info.specialcolormode = (Vdp2Regs->SFCCMD >> 2) & 0x3;
   if (Vdp2Regs->SFSEL & 0x2)
      info.specialcode = Vdp2Regs->SFCODE >> 8;
   else
      info.specialcode = Vdp2Regs->SFCODE & 0xFF;
   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x2)
      info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x70) << 4;
   ReadVdp2ColorOffset(Vdp2Regs, &info, 0x2, 0x2);
   info.coordincx = (Vdp2Regs->ZMXN1.all & 0x7FF00) / (float) 65536;
   info.coordincy = (Vdp2Regs->ZMYN1.all & 0x7FF00) / (float) 65536;

   info.priority = nbg1priority;
   info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG1PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle) ||
       (Vdp2Regs->BGON & 0x1 && (Vdp2Regs->CHCTLA & 0x70) >> 4 == 4)) // If NBG0 16M mode is enabled, don't draw
      return;

   ReadMosaicData(&info, 0x2);
   ReadLineScrollData(&info, Vdp2Regs->SCRCTL >> 8, Vdp2Regs->LSTA1.all);
   if (Vdp2Regs->SCRCTL & 0x100)
   {
      info.isverticalscroll = 1;
      if (Vdp2Regs->SCRCTL & 0x1)
      {
         info.verticalscrolltbl = 4 + ((Vdp2Regs->VCSTA.all & 0x7FFFE) << 1);
         info.verticalscrollinc = 8;
      }
      else
      {
         info.verticalscrolltbl = (Vdp2Regs->VCSTA.all & 0x7FFFE) << 1;
         info.verticalscrollinc = 4;
      }
   }
   else
      info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLA >> 8;

   info.LoadLineParams = (void (*)(void *, int)) LoadLineParamsNBG1;

   Vdp2DrawScroll(&info);
}

//////////////////////////////////////////////////////////////////////////////

static void LoadLineParamsNBG2(vdp2draw_struct * info, int line)
{
   Vdp2 * regs;

   regs = Vdp2RestoreRegs(line);
   if (regs == NULL) return;
   ReadVdp2ColorOffset(regs, info, 0x4, 0x4);
   info->specialprimode = (regs->SFPRMD >> 4) & 0x3;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG2(void)
{
   vdp2draw_struct info;

   info.enable = Vdp2Regs->BGON & 0x4;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x400);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 4) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x2) >> 1;	
   info.mapwh = 2;

   ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 4);
   info.x = Vdp2Regs->SCXN2 & 0x7FF;
   info.y = Vdp2Regs->SCYN2 & 0x7FF;
   ReadPatternData(&info, Vdp2Regs->PNCN2, Vdp2Regs->CHCTLB & 0x1);
    
   if (Vdp2Regs->CCCTL & 0x204)
      info.alpha = ((~Vdp2Regs->CCRNB & 0x1F) << 1) + 1;
   else
      info.alpha = 0x3F;
   if ((Vdp2Regs->CCCTL & 0x204) == 0x204) info.alpha |= 0x80;
   else if ((Vdp2Regs->CCCTL & 0x104) == 0x104) info.alpha |= 0x80;
   info.specialcolormode = (Vdp2Regs->SFCCMD >> 4) & 0x3;
   if (Vdp2Regs->SFSEL & 0x4)
      info.specialcode = Vdp2Regs->SFCODE >> 8;
   else
      info.specialcode = Vdp2Regs->SFCODE & 0xFF;
   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x4)
      info.linescreen = 1;

   info.coloroffset = Vdp2Regs->CRAOFA & 0x700;
   ReadVdp2ColorOffset(Vdp2Regs, &info, 0x4, 0x4);
   info.coordincx = info.coordincy = 1;

   info.priority = nbg2priority;
   info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG2PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle) ||
      (Vdp2Regs->BGON & 0x1 && (Vdp2Regs->CHCTLA & 0x70) >> 4 >= 2)) // If NBG0 2048/32786/16M mode is enabled, don't draw
      return;

   ReadMosaicData(&info, 0x4);
   info.islinescroll = 0;
   info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLB;
   info.isbitmap = 0;

   info.LoadLineParams = (void (*)(void *, int)) LoadLineParamsNBG2;

   Vdp2DrawScroll(&info);
}

//////////////////////////////////////////////////////////////////////////////

static void LoadLineParamsNBG3(vdp2draw_struct * info, int line)
{
   Vdp2 * regs;

   regs = Vdp2RestoreRegs(line);
   if (regs == NULL) return;
   ReadVdp2ColorOffset(regs, info, 0x8, 0x8);
   info->specialprimode = (regs->SFPRMD >> 6) & 0x3;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG3(void)
{
   vdp2draw_struct info;

   info.enable = Vdp2Regs->BGON & 0x8;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x800);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 6) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x20) >> 5;
	
   info.mapwh = 2;

   ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 6);
   info.x = Vdp2Regs->SCXN3 & 0x7FF;
   info.y = Vdp2Regs->SCYN3 & 0x7FF;
   ReadPatternData(&info, Vdp2Regs->PNCN3, Vdp2Regs->CHCTLB & 0x10);

   if (Vdp2Regs->CCCTL & 0x208)
      info.alpha = ((~Vdp2Regs->CCRNB & 0x1F00) >> 7) + 1;
   else
      info.alpha = 0x3F;
   if ((Vdp2Regs->CCCTL & 0x208) == 0x208) info.alpha |= 0x80;
   else if ((Vdp2Regs->CCCTL & 0x108) == 0x108) info.alpha |= 0x80;
   info.specialcolormode = (Vdp2Regs->SFCCMD >> 6) & 0x3;
   if (Vdp2Regs->SFSEL & 0x8)
      info.specialcode = Vdp2Regs->SFCODE >> 8;
   else
      info.specialcode = Vdp2Regs->SFCODE & 0xFF;
   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x8)
      info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7000) >> 4;
   ReadVdp2ColorOffset(Vdp2Regs, &info, 0x8, 0x8);
   info.coordincx = info.coordincy = 1;

   info.priority = nbg3priority;
   info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG3PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle) ||
      (Vdp2Regs->BGON & 0x1 && (Vdp2Regs->CHCTLA & 0x70) >> 4 == 4) || // If NBG0 16M mode is enabled, don't draw
      (Vdp2Regs->BGON & 0x2 && (Vdp2Regs->CHCTLA & 0x3000) >> 12 >= 2)) // If NBG1 2048/32786 is enabled, don't draw
      return;

   ReadMosaicData(&info, 0x8);
   info.islinescroll = 0;
   info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLB >> 8;
   info.isbitmap = 0;

   info.LoadLineParams = (void (*)(void *, int)) LoadLineParamsNBG3;

   Vdp2DrawScroll(&info);
}

//////////////////////////////////////////////////////////////////////////////

static void LoadLineParamsRBG0(vdp2draw_struct * info, int line)
{
   Vdp2 * regs;

   regs = Vdp2RestoreRegs(line);
   if (regs == NULL) return;
   ReadVdp2ColorOffset(regs, info, 0x10, 0x10);
   info->specialprimode = (regs->SFPRMD >> 8) & 0x3;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawRBG0(void)
{
   vdp2draw_struct info;
   vdp2rotationparameterfp_struct parameter[2];

   parameter[0].PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterAPlaneAddr;
   parameter[1].PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterBPlaneAddr;

   info.enable = Vdp2Regs->BGON & 0x10;
   info.priority = rbg0priority;
   if (!(info.enable & Vdp2External.disptoggle))
      return;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x1000);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 8) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x7000) >> 12;

   // Figure out which Rotation Parameter we're using
   switch (Vdp2Regs->RPMD & 0x3)
   {
      case 0:
         // Parameter A
         info.rotatenum = 0;
         info.rotatemode = 0;
         info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterAPlaneAddr;
         break;
      case 1:
         // Parameter B
         info.rotatenum = 1;
         info.rotatemode = 0;
         info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterBPlaneAddr;
         break;
      case 2:
         // Parameter A+B switched via coefficients
      case 3:
         // Parameter A+B switched via rotation parameter window
      default:
         info.rotatenum = 0;
         info.rotatemode = 1 + (Vdp2Regs->RPMD & 0x1);
         info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterAPlaneAddr;
         break;
   }

   Vdp2ReadRotationTableFP(info.rotatenum, &parameter[info.rotatenum]);

   if((info.isbitmap = Vdp2Regs->CHCTLB & 0x200) != 0)
   {
      // Bitmap Mode
      ReadBitmapSize(&info, Vdp2Regs->CHCTLB >> 10, 0x1);

      if (info.rotatenum == 0)
         // Parameter A
         info.charaddr = (Vdp2Regs->MPOFR & 0x7) * 0x20000;
      else
         // Parameter B
         info.charaddr = (Vdp2Regs->MPOFR & 0x70) * 0x2000;

      info.paladdr = (Vdp2Regs->BMPNB & 0x7) << 8;
      info.flipfunction = 0;
      info.specialfunction = 0;
      info.specialcolorfunction = (Vdp2Regs->BMPNB & 0x10) >> 4;
   }
   else
   {
      // Tile Mode
      info.mapwh = 4;

      if (info.rotatenum == 0)
         // Parameter A
         ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 8);
      else
         // Parameter B
         ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 12);

      ReadPatternData(&info, Vdp2Regs->PNCR, Vdp2Regs->CHCTLB & 0x100);
   }

   if (Vdp2Regs->CCCTL & 0x210)
      info.alpha = ((~Vdp2Regs->CCRR & 0x1F) << 1) + 1;
   else
      info.alpha = 0x3F;
   if ((Vdp2Regs->CCCTL & 0x210) == 0x210) info.alpha |= 0x80;
   else if ((Vdp2Regs->CCCTL & 0x110) == 0x110) info.alpha |= 0x80;
   info.specialcolormode = (Vdp2Regs->SFCCMD >> 8) & 0x3;
   if (Vdp2Regs->SFSEL & 0x10)
      info.specialcode = Vdp2Regs->SFCODE >> 8;
   else
      info.specialcode = Vdp2Regs->SFCODE & 0xFF;
   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x10)
      info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFB & 0x7) << 8;

   ReadVdp2ColorOffset(Vdp2Regs, &info, 0x10, 0x10);
   info.coordincx = info.coordincy = 1;

   ReadMosaicData(&info, 0x10);
   info.islinescroll = 0;
   info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLC;

   info.LoadLineParams = (void (*)(void *, int)) LoadLineParamsRBG0;

   Vdp2DrawRotationFP(&info, parameter);
}

//////////////////////////////////////////////////////////////////////////////

static void LoadLineParamsSprite(vdp2draw_struct * info, int line)
{
   Vdp2 * regs;

   regs = Vdp2RestoreRegs(line);
   if (regs == NULL) return;
   ReadVdp2ColorOffset(regs, info, 0x40, 0x40);
}

//////////////////////////////////////////////////////////////////////////////

int VIDSoftInit(void)
{
   if (TitanInit() == -1)
      return -1;

   if ((dispbuffer = (pixel_t *)calloc(sizeof(pixel_t), 704 * 512)) == NULL)
      return -1;

   // Initialize VDP1 framebuffer 1
   if ((vdp1framebuffer[0] = (u8 *)calloc(sizeof(u8), 0x40000)) == NULL)
      return -1;

   // Initialize VDP1 framebuffer 2
   if ((vdp1framebuffer[1] = (u8 *)calloc(sizeof(u8), 0x40000)) == NULL)
      return -1;

   vdp1backframebuffer = vdp1framebuffer[0];
   vdp1frontframebuffer = vdp1framebuffer[1];
   vdp2width = 320;
   vdp2height = 224;

#ifdef USE_OPENGL
   glClear(GL_COLOR_BUFFER_BIT);

   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrtho(0, 320, 224, 0, 1, 0);

   glMatrixMode(GL_TEXTURE);
   glLoadIdentity();
   glOrtho(-320, 320, -224, 224, 1, 0);
   outputwidth = 320;
   outputheight = 224;
#endif

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftDeInit(void)
{
   if (dispbuffer)
   {
      free(dispbuffer);
      dispbuffer = NULL;
   }

   if (vdp1framebuffer[0])
      free(vdp1framebuffer[0]);

   if (vdp1framebuffer[1])
      free(vdp1framebuffer[1]);
}

//////////////////////////////////////////////////////////////////////////////

static int IsFullscreen = 0;

void VIDSoftResize(unsigned int w, unsigned int h, int on)
{
#ifdef USE_OPENGL
   IsFullscreen = on;

   glClear(GL_COLOR_BUFFER_BIT);

   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrtho(0, w, h, 0, 1, 0);

   glMatrixMode(GL_TEXTURE);
   glLoadIdentity();
   glOrtho(-(signed)w, w, -(signed)h, h, 1, 0);

   glViewport(0, 0, w, h);
   outputwidth = w;
   outputheight = h;
#endif
}

//////////////////////////////////////////////////////////////////////////////

int VIDSoftIsFullscreen(void) {
   return IsFullscreen;
}

//////////////////////////////////////////////////////////////////////////////

int VIDSoftVdp1Reset(void)
{
   vdp1clipxstart = 0;
   vdp1clipxend = 512;
   vdp1clipystart = 0;
   vdp1clipyend = 256;
   
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1DrawStart(void)
{
   if (Vdp1Regs->FBCR & 8)
      vdp1interlace = 2;
   else
      vdp1interlace = 1;
   if (Vdp1Regs->TVMR & 0x1)
   {
      if (Vdp1Regs->TVMR & 0x2)
      {
         // Rotation 8-bit
         vdp1width = 512;
         vdp1height = 512;
      }
      else
      {
         // Normal 8-bit
         vdp1width = 1024;
         vdp1height = 256;
      }

      vdp1pixelsize = 1;
   }
   else
   {
      // Rotation/Normal 16-bit
      vdp1width = 512;
      vdp1height = 256;
      vdp1pixelsize = 2;
   }

   VIDSoftVdp1EraseFrameBuffer();

   vdp1clipxstart = Vdp1Regs->userclipX1 = Vdp1Regs->systemclipX1 = 0;
   vdp1clipystart = Vdp1Regs->userclipY1 = Vdp1Regs->systemclipY1 = 0;
   vdp1clipxend = Vdp1Regs->userclipX2 = Vdp1Regs->systemclipX2 = vdp1width;
   vdp1clipyend = Vdp1Regs->userclipY2 = Vdp1Regs->systemclipY2 = vdp1height;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1DrawEnd(void)
{
}

//////////////////////////////////////////////////////////////////////////////

static INLINE u16  Vdp1ReadPattern16( u32 base, u32 offset ) {

  u16 dot = T1ReadByte(Vdp1Ram, ( base + (offset>>1)) & 0x7FFFF);
  if ((offset & 0x1) == 0) dot >>= 4; // Even pixel
  else dot &= 0xF; // Odd pixel
  return dot;
}

static INLINE u16  Vdp1ReadPattern64( u32 base, u32 offset ) {

  return T1ReadByte(Vdp1Ram, ( base + offset ) & 0x7FFFF) & 0x3F;
}

static INLINE u16  Vdp1ReadPattern128( u32 base, u32 offset ) {

  return T1ReadByte(Vdp1Ram, ( base + offset ) & 0x7FFFF) & 0x7F;
}

static INLINE u16  Vdp1ReadPattern256( u32 base, u32 offset ) {

  return T1ReadByte(Vdp1Ram, ( base + offset ) & 0x7FFFF) & 0xFF;
}

static INLINE u16  Vdp1ReadPattern64k( u32 base, u32 offset ) {

  return T1ReadWord(Vdp1Ram, ( base + 2*offset) & 0x7FFFF);
}

////////////////////////////////////////////////////////////////////////////////

static INLINE u32 alphablend16(u32 d, u32 s, u32 level)
{
	int r,g,b,sr,sg,sb,dr,dg,db;

	int invlevel = 256-level;
	sr = s & 0x001f; dr = d & 0x001f; 
	r = (sr*level + dr*invlevel)>>8; r&= 0x1f;
	sg = s & 0x03e0; dg = d & 0x03e0;
	g = (sg*level + dg*invlevel)>>8; g&= 0x03e0;
	sb = s & 0x7c00; db = d & 0x7c00;
	b = (sb*level + db*invlevel)>>8; b&= 0x7c00;
	return r|g|b;
}

typedef struct _COLOR_PARAMS
{
	double r,g,b;
} COLOR_PARAMS;

COLOR_PARAMS leftColumnColor;

vdp1cmd_struct cmd;

int currentPixel;
int currentPixelIsVisible;
int characterWidth;
int characterHeight;

static int getpixel(int linenumber, int currentlineindex) {
	
	u32 characterAddress;
	u32 colorlut;
	u16 colorbank;
	u8 SPD;
	int endcode;
	int endcodesEnabled;
	int untexturedColor = 0;
	int isTextured = 1;
	int currentShape = cmd.CMDCTRL & 0x7;
	int flip;

	characterAddress = cmd.CMDSRCA << 3;
	colorbank = cmd.CMDCOLR;
	colorlut = (u32)colorbank << 3;
	SPD = ((cmd.CMDPMOD & 0x40) != 0);//show the actual color of transparent pixels if 1 (they won't be drawn transparent)
	endcodesEnabled = (( cmd.CMDPMOD & 0x80) == 0 )?1:0;
	flip = (cmd.CMDCTRL & 0x30) >> 4;

	//4 polygon, 5 polyline or 6 line
	if(currentShape == 4 || currentShape == 5 || currentShape == 6) {
		isTextured = 0;
		untexturedColor = cmd.CMDCOLR;
	}

	switch( flip ) {
		case 1:
			// Horizontal flipping
			currentlineindex = characterWidth - currentlineindex-1;
			break;
		case 2:
			// Vertical flipping
			linenumber = characterHeight - linenumber-1;

			break;
		case 3:
			// Horizontal/Vertical flipping
			linenumber = characterHeight - linenumber-1;
			currentlineindex = characterWidth - currentlineindex-1;
			break;
	}

	switch ((cmd.CMDPMOD >> 3) & 0x7)
	{
		case 0x0: //4bpp bank
			endcode = 0xf;
			currentPixel = Vdp1ReadPattern16( characterAddress + (linenumber*(characterWidth>>1)), currentlineindex );
			if(isTextured && endcodesEnabled && currentPixel == endcode)
				return 1;
			if (!((currentPixel == 0) && !SPD)) 
				currentPixel = colorbank | currentPixel;
			currentPixelIsVisible = 0xf;
			break;

		case 0x1://4bpp lut
			endcode = 0xf;
			currentPixel = Vdp1ReadPattern16( characterAddress + (linenumber*(characterWidth>>1)), currentlineindex );
			if(isTextured && endcodesEnabled && currentPixel == endcode)
				return 1;
			if (!(currentPixel == 0 && !SPD))
				currentPixel = T1ReadWord(Vdp1Ram, (currentPixel * 2 + colorlut) & 0x7FFFF);
			currentPixelIsVisible = 0xffff;
			break;
		case 0x2://8pp bank (64 color)
			//is there a hardware bug with endcodes in this color mode?
			//there are white lines around some characters in scud
			//using an endcode of 63 eliminates the white lines
			//but also causes some dropout due to endcodes being triggered that aren't triggered on hardware
			//the closest thing i can do to match the hardware is make all pixels with color index 63 transparent
			//this needs more hardware testing

			endcode = 63;
			currentPixel = Vdp1ReadPattern64( characterAddress + (linenumber*(characterWidth)), currentlineindex );
			if(isTextured && endcodesEnabled && currentPixel == endcode)
				currentPixel = 0;
		//		return 1;
			if (!((currentPixel == 0) && !SPD)) 
				currentPixel = colorbank | currentPixel;
			currentPixelIsVisible = 0x3f;
			break;
		case 0x3://128 color
			endcode = 0xff;
			currentPixel = Vdp1ReadPattern128( characterAddress + (linenumber*characterWidth), currentlineindex );
			if(isTextured && endcodesEnabled && currentPixel == endcode)
				return 1;
			if (!((currentPixel == 0) && !SPD)) 
				currentPixel = colorbank | currentPixel;
			currentPixelIsVisible = 0x7f;
			break;
		case 0x4://256 color
			endcode = 0xff;
			currentPixel = Vdp1ReadPattern256( characterAddress + (linenumber*characterWidth), currentlineindex );
			if(isTextured && endcodesEnabled && currentPixel == endcode)
				return 1;
			currentPixelIsVisible = 0xff;
			if (!((currentPixel == 0) && !SPD)) 
				currentPixel = colorbank | currentPixel;
			break;
		case 0x5://16bpp bank
			endcode = 0x7fff;
			currentPixel = Vdp1ReadPattern64k( characterAddress + (linenumber*characterWidth*2), currentlineindex );
			if(isTextured && endcodesEnabled && currentPixel == endcode)
				return 1;

			/* the transparent pixel in 16bpp is supposed to be 0x0000
			but some games use pixels with invalid values and expect
			them to be transparent (see vdp1 doc p. 92) */
			if (!(currentPixel & 0x8000) && !SPD)
				currentPixel = 0;

			currentPixelIsVisible = 0xffff;
			break;
	}

	if(!isTextured)
		currentPixel = untexturedColor;

	//force the MSB to be on if MSBON is set
	//currentPixel |= cmd.CMDPMOD & (1 << 15);

	return 0;
}

static int gouraudAdjust( int color, int tableValue )
{
	color += (tableValue - 0x10);

	if ( color < 0 ) color = 0;
	if ( color > 0x1f ) color = 0x1f;

	return color;
}

static void putpixel8(int x, int y) {

    int x2 = x / 2;
    int y2 = y / vdp1interlace;
    u8 * iPix = &vdp1backframebuffer[(y2 * vdp1width) + x2];
    int mesh = cmd.CMDPMOD & 0x0100;
    int SPD = ((cmd.CMDPMOD & 0x40) != 0);//show the actual color of transparent pixels if 1 (they won't be drawn transparent)

    if (iPix >= (vdp1backframebuffer + 0x40000))
        return;

    currentPixel &= 0xFF;

    if(mesh && ((x2 ^ y2) & 1)) {
        return;
    }

    {
        int clipped;

        if (cmd.CMDPMOD & 0x0400) PushUserClipping((cmd.CMDPMOD >> 9) & 0x1);

        clipped = ! (x2 >= vdp1clipxstart &&
            x2 < vdp1clipxend &&
            y2 >= vdp1clipystart &&
            y2 < vdp1clipyend);

        if (cmd.CMDPMOD & 0x0400) PopUserClipping();

        if (clipped) return;
    }

    if ( SPD || (currentPixel & currentPixelIsVisible))
    {
        switch( cmd.CMDPMOD & 0x7 )//we want bits 0,1,2
        {
        default:
        case 0:	// replace
            if (!((currentPixel == 0) && !SPD))
                *(iPix) = currentPixel;
            break;
        }
    }
}

static void putpixel(int x, int y) {

	u16* iPix;
	int mesh = cmd.CMDPMOD & 0x0100;
	int SPD = ((cmd.CMDPMOD & 0x40) != 0);//show the actual color of transparent pixels if 1 (they won't be drawn transparent)

	y /= vdp1interlace;
	iPix = &((u16 *)vdp1backframebuffer)[(y * vdp1width) + x];

	if (iPix >= (u16*) (vdp1backframebuffer + 0x40000))
		return;

	if(mesh && (x^y)&1)
		return;

	{
		int clipped;

		if (cmd.CMDPMOD & 0x0400) PushUserClipping((cmd.CMDPMOD >> 9) & 0x1);

		clipped = ! (x >= vdp1clipxstart &&
			x < vdp1clipxend &&
			y >= vdp1clipystart &&
			y < vdp1clipyend);

		if (cmd.CMDPMOD & 0x0400) PopUserClipping();

		if (clipped) return;
	}

	if ((cmd.CMDPMOD & (1 << 15)) && ((Vdp2Regs->SPCTL & 0x10) == 0))
	{
		if (currentPixel) {
			*iPix |= 0x8000;
			return;
		}
	}

	if ( SPD || (currentPixel & currentPixelIsVisible))
	{
		switch( cmd.CMDPMOD & 0x7 )//we want bits 0,1,2
		{
		case 0:	// replace
			if (!((currentPixel == 0) && !SPD)) 
				*(iPix) = currentPixel;
			break;
		case 1: // shadow
			if (*(iPix) & (1 << 15)) // only if MSB of framebuffer data is set
				*(iPix) = alphablend16(*(iPix), 0, (1 << 7)) | (1 << 15);
			break;
		case 2: // half luminance
			*(iPix) = ((currentPixel & ~0x8421) >> 1) | (1 << 15);
			break;
		case 3: // half transparent
			if ( *(iPix) & (1 << 15) )//only if MSB of framebuffer data is set 
				*(iPix) = alphablend16( *(iPix), currentPixel, (1 << 7) ) | (1 << 15);
			else
				*(iPix) = currentPixel;
			break;
		case 4: //gouraud
			#define COLOR(r,g,b)    (((r)&0x1F)|(((g)&0x1F)<<5)|(((b)&0x1F)<<10) |0x8000 )

			//handle the special case demonstrated in the sgl chrome demo
			//if we are in a paletted bank mode and the other two colors are unused, adjust the index value instead of rgb
			if(
				(((cmd.CMDPMOD >> 3) & 0x7) != 5) &&
				(((cmd.CMDPMOD >> 3) & 0x7) != 1) && 
				(int)leftColumnColor.g == 16 && 
				(int)leftColumnColor.b == 16) 
			{
				int c = (int)(leftColumnColor.r-0x10);
				if(c < 0) c = 0;
				currentPixel = currentPixel+c;
				*(iPix) = currentPixel;
				break;
			}
			*(iPix) = COLOR(
				gouraudAdjust(
				currentPixel&0x001F,
				(int)leftColumnColor.r),

				gouraudAdjust(
				(currentPixel&0x03e0) >> 5,
				(int)leftColumnColor.g),

				gouraudAdjust(
				(currentPixel&0x7c00) >> 10,
				(int)leftColumnColor.b)
				);
			break;
		default:
			*(iPix) = alphablend16( COLOR((int)leftColumnColor.r,(int)leftColumnColor.g, (int)leftColumnColor.b), currentPixel, (1 << 7) ) | (1 << 15);
			break;
		}
	}
}

static int iterateOverLine(int x1, int y1, int x2, int y2, int greedy, void *data,
			   int (*line_callback)(int x, int y, int i, void *data)) {
	int i, a, ax, ay, dx, dy;

	a = i = 0;
	dx = x2 - x1;
	dy = y2 - y1;
	ax = (dx >= 0) ? 1 : -1;
	ay = (dy >= 0) ? 1 : -1;

	//burning rangers tries to draw huge shapes
	//this will at least let it run
	if(abs(dx) > 999 || abs(dy) > 999)
		return INT_MAX;

	if (abs(dx) > abs(dy)) {
		if (ax != ay) dx = -dx;

		for (; x1 != x2; x1 += ax, i++) {
			if (line_callback && line_callback(x1, y1, i, data) != 0) return i + 1;

			a += dy;
			if (abs(a) >= abs(dx)) {
				a -= dx;
				y1 += ay;

				// Make sure we 'fill holes' the same as the Saturn
				if (greedy) {
					i ++;
					if (ax == ay) {
						if (line_callback &&
						    line_callback(x1 + ax, y1 - ay, i, data) != 0)
							return i + 1;
					} else {
						if (line_callback &&
						    line_callback(x1, y1, i, data) != 0)
							return i + 1;
					}
				}
			}
		}

		// If the line isn't greedy here, we end up with gaps that don't occur on the Saturn
		if (/*(i == 0) || (y1 != y2)*/1) {
			if (line_callback) line_callback(x2, y2, i, data);
			i ++;
		}
	} else {
		if (ax != ay) dy = -dy;

		for (; y1 != y2; y1 += ay, i++) {
			if (line_callback && line_callback(x1, y1, i, data) != 0) return i + 1;

			a += dx;
			if (abs(a) >= abs(dy)) {
				a -= dy;
				x1 += ax;

				if (greedy) {
					i ++;
					if (ay == ax) {
						if (line_callback &&
						    line_callback(x1, y1, i, data) != 0)
							return i + 1;
					} else {
						if (line_callback &&
						    line_callback(x1 - ax, y1 + ay, i, data) != 0)
							return i + 1;
					}
				}
			}
		}

		if (/*(i == 0) || (y1 != y2)*/1) {
			if (line_callback) line_callback(x2, y2, i, data);
			i ++;
		}
	}

	return i;
}

typedef struct {
	double linenumber;
	double texturestep;
	double xredstep;
	double xgreenstep;
	double xbluestep;
	int endcodesdetected;
	int previousStep;
} DrawLineData;

static int DrawLineCallback(int x, int y, int i, void *data)
{
	int currentStep;
	DrawLineData *linedata = data;

	leftColumnColor.r += linedata->xredstep;
	leftColumnColor.g += linedata->xgreenstep;
	leftColumnColor.b += linedata->xbluestep;

	currentStep = (int)i * linedata->texturestep;
	if (getpixel(linedata->linenumber, currentStep)) {
		if (currentStep != linedata->previousStep) {
			linedata->previousStep = currentStep;
			linedata->endcodesdetected ++;
		}
	} else if (vdp1pixelsize == 2) {
		putpixel(x, y);
	} else {
		putpixel8(x, y);
    }

	if (linedata->endcodesdetected == 2) return -1;

	return 0;
}

static int DrawLine( int x1, int y1, int x2, int y2, int greedy, double linenumber, double texturestep, double xredstep, double xgreenstep, double xbluestep)
{
	DrawLineData data;

	data.linenumber = linenumber;
	data.texturestep = texturestep;
	data.xredstep = xredstep;
	data.xgreenstep = xgreenstep;
	data.xbluestep = xbluestep;
	data.endcodesdetected = 0;
	data.previousStep = 123456789;

	return iterateOverLine(x1, y1, x2, y2, greedy, &data, DrawLineCallback);
}

static INLINE double interpolate(double start, double end, int numberofsteps) {

	double stepvalue = 0;

	if(numberofsteps == 0)
		return 1;

	stepvalue = (end - start) / numberofsteps;

	return stepvalue;
}

typedef union _COLOR { // xbgr x555
	struct {
#ifdef WORDS_BIGENDIAN
	u16 x:1;
	u16 b:5;
	u16 g:5;
	u16 r:5;
#else
     u16 r:5;
     u16 g:5;
     u16 b:5;
     u16 x:1;
#endif
	};
	u16 value;
} COLOR;


COLOR gouraudA;
COLOR gouraudB;
COLOR gouraudC;
COLOR gouraudD;

static void gouraudTable(void)
{
	int gouraudTableAddress;

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

	gouraudTableAddress = (((unsigned int)cmd.CMDGRDA) << 3);

	gouraudA.value = T1ReadWord(Vdp1Ram,gouraudTableAddress);
	gouraudB.value = T1ReadWord(Vdp1Ram,gouraudTableAddress+2);
	gouraudC.value = T1ReadWord(Vdp1Ram,gouraudTableAddress+4);
	gouraudD.value = T1ReadWord(Vdp1Ram,gouraudTableAddress+6);
}

int xleft[1000];
int yleft[1000];
int xright[1000];
int yright[1000];

static int
storeLineCoords(int x, int y, int i, void *arrays) {
	int **intArrays = arrays;

	intArrays[0][i] = x;
	intArrays[1][i] = y;

	return 0;
}

//a real vdp1 draws with arbitrary lines
//this is why endcodes are possible
//this is also the reason why half-transparent shading causes moire patterns
//and the reason why gouraud shading can be applied to a single line draw command
static void drawQuad(s16 tl_x, s16 tl_y, s16 bl_x, s16 bl_y, s16 tr_x, s16 tr_y, s16 br_x, s16 br_y){

	int totalleft;
	int totalright;
	int total;
	int i;
	int *intarrays[2];

	COLOR_PARAMS topLeftToBottomLeftColorStep = {0,0,0}, topRightToBottomRightColorStep = {0,0,0};
		
	//how quickly we step through the line arrays
	double leftLineStep = 1;
	double rightLineStep = 1; 

	//a lookup table for the gouraud colors
	COLOR colors[4];

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);
	characterWidth = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
	characterHeight = cmd.CMDSIZE & 0xFF;

	intarrays[0] = xleft; intarrays[1] = yleft;
	totalleft  = iterateOverLine(tl_x, tl_y, bl_x, bl_y, 0, intarrays, storeLineCoords);
	intarrays[0] = xright; intarrays[1] = yright;
	totalright  = iterateOverLine(tr_x, tr_y, br_x, br_y, 0, intarrays, storeLineCoords);

	//just for now since burning rangers will freeze up trying to draw huge shapes
	if(totalleft == INT_MAX || totalright == INT_MAX)
		return;

	total = totalleft > totalright ? totalleft : totalright;


	if(cmd.CMDPMOD & (1 << 2)) {

		gouraudTable();

		{ colors[0] = gouraudA; colors[1] = gouraudD; colors[2] = gouraudB; colors[3] = gouraudC; }

		topLeftToBottomLeftColorStep.r = interpolate(colors[0].r,colors[1].r,total);
		topLeftToBottomLeftColorStep.g = interpolate(colors[0].g,colors[1].g,total);
		topLeftToBottomLeftColorStep.b = interpolate(colors[0].b,colors[1].b,total);

		topRightToBottomRightColorStep.r = interpolate(colors[2].r,colors[3].r,total);
		topRightToBottomRightColorStep.g = interpolate(colors[2].g,colors[3].g,total);
		topRightToBottomRightColorStep.b = interpolate(colors[2].b,colors[3].b,total);
	}

	//we have to step the equivalent of less than one pixel on the shorter side
	//to make sure textures stretch properly and the shape is correct
	if(total == totalleft && totalleft != totalright) {
		//left side is larger
		leftLineStep = 1;
		rightLineStep = (double)totalright / totalleft;
	}
	else if(totalleft != totalright){
		//right side is larger
		rightLineStep = 1;
		leftLineStep = (double)totalleft / totalright;
	}

	for(i = 0; i < total; i++) {

		int xlinelength;

		double xtexturestep;
		double ytexturestep;

		COLOR_PARAMS rightColumnColor;

		COLOR_PARAMS leftToRightStep = {0,0,0};

		//get the length of the line we are about to draw
		xlinelength = iterateOverLine(
			xleft[(int)(i*leftLineStep)],
			yleft[(int)(i*leftLineStep)],
			xright[(int)(i*rightLineStep)],
			yright[(int)(i*rightLineStep)],
			1, NULL, NULL);

		//so from 0 to the width of the texture / the length of the line is how far we need to step
		xtexturestep=interpolate(0,characterWidth,xlinelength);

		//now we need to interpolate the y texture coordinate across multiple lines
		ytexturestep=interpolate(0,characterHeight,total);

		//gouraud interpolation
		if(cmd.CMDPMOD & (1 << 2)) {

			//for each new line we need to step once more through each column
			//and add the orignal color + the number of steps taken times the step value to the bottom of the shape
			//to get the current colors to use to interpolate across the line

			leftColumnColor.r = colors[0].r +(topLeftToBottomLeftColorStep.r*i);
			leftColumnColor.g = colors[0].g +(topLeftToBottomLeftColorStep.g*i);
			leftColumnColor.b = colors[0].b +(topLeftToBottomLeftColorStep.b*i);

			rightColumnColor.r = colors[2].r +(topRightToBottomRightColorStep.r*i);
			rightColumnColor.g = colors[2].g +(topRightToBottomRightColorStep.g*i);
			rightColumnColor.b = colors[2].b +(topRightToBottomRightColorStep.b*i);

			//interpolate colors across to get the right step values
			leftToRightStep.r = interpolate(leftColumnColor.r,rightColumnColor.r,xlinelength);
			leftToRightStep.g = interpolate(leftColumnColor.g,rightColumnColor.g,xlinelength);
			leftToRightStep.b = interpolate(leftColumnColor.b,rightColumnColor.b,xlinelength);
		}

		DrawLine(
			xleft[(int)(i*leftLineStep)],
			yleft[(int)(i*leftLineStep)],
			xright[(int)(i*rightLineStep)],
			yright[(int)(i*rightLineStep)],
			1,
			ytexturestep*i, 
			xtexturestep,
			leftToRightStep.r,
			leftToRightStep.g,
			leftToRightStep.b
			);
	}
}

void VIDSoftVdp1NormalSpriteDraw() {

	s16 topLeftx,topLefty,topRightx,topRighty,bottomRightx,bottomRighty,bottomLeftx,bottomLefty;
	int spriteWidth;
	int spriteHeight;
	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

	topLeftx = cmd.CMDXA + Vdp1Regs->localX;
	topLefty = cmd.CMDYA + Vdp1Regs->localY;
	spriteWidth = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
	spriteHeight = cmd.CMDSIZE & 0xFF;

	topRightx = topLeftx + (spriteWidth - 1);
	topRighty = topLefty;
	bottomRightx = topLeftx + (spriteWidth - 1);
	bottomRighty = topLefty + (spriteHeight - 1);
	bottomLeftx = topLeftx;
	bottomLefty = topLefty + (spriteHeight - 1);

	drawQuad(topLeftx,topLefty,bottomLeftx,bottomLefty,topRightx,topRighty,bottomRightx,bottomRighty);
}

void VIDSoftVdp1ScaledSpriteDraw(){

	s32 topLeftx,topLefty,topRightx,topRighty,bottomRightx,bottomRighty,bottomLeftx,bottomLefty;
	int x0,y0,x1,y1;
	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

	x0 = cmd.CMDXA + Vdp1Regs->localX;
	y0 = cmd.CMDYA + Vdp1Regs->localY;

	switch ((cmd.CMDCTRL >> 8) & 0xF)
	{
	case 0x0: // Only two coordinates
	default:
		x1 = ((int)cmd.CMDXC) - x0 + Vdp1Regs->localX + 1;
		y1 = ((int)cmd.CMDYC) - y0 + Vdp1Regs->localY + 1;
		break;
	case 0x5: // Upper-left
		x1 = ((int)cmd.CMDXB) + 1;
		y1 = ((int)cmd.CMDYB) + 1;
		break;
	case 0x6: // Upper-Center
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		x0 = x0 - x1/2;
		x1++;
		y1++;
		break;
	case 0x7: // Upper-Right
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		x0 = x0 - x1;
		x1++;
		y1++;
		break;
	case 0x9: // Center-left
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		y0 = y0 - y1/2;
		x1++;
		y1++;
		break;
	case 0xA: // Center-center
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		x0 = x0 - x1/2;
		y0 = y0 - y1/2;
		x1++;
		y1++;
		break;
	case 0xB: // Center-right
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		x0 = x0 - x1;
		y0 = y0 - y1/2;
		x1++;
		y1++;
		break;
	case 0xD: // Lower-left
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		y0 = y0 - y1;
		x1++;
		y1++;
		break;
	case 0xE: // Lower-center
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		x0 = x0 - x1/2;
		y0 = y0 - y1;
		x1++;
		y1++;
		break;
	case 0xF: // Lower-right
		x1 = ((int)cmd.CMDXB);
		y1 = ((int)cmd.CMDYB);
		x0 = x0 - x1;
		y0 = y0 - y1;
		x1++;
		y1++;
		break;
	}

	topLeftx = x0;
	topLefty = y0;

	topRightx = x1+x0 - 1;
	topRighty = topLefty;

	bottomRightx = x1+x0 - 1;
	bottomRighty = y1+y0 - 1;

	bottomLeftx = topLeftx;
	bottomLefty = y1+y0 - 1;

	drawQuad(topLeftx,topLefty,bottomLeftx,bottomLefty,topRightx,topRighty,bottomRightx,bottomRighty);
}

void VIDSoftVdp1DistortedSpriteDraw() {

	s32 xa,ya,xb,yb,xc,yc,xd,yd;

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

    xa = (s32)(cmd.CMDXA + Vdp1Regs->localX);
    ya = (s32)(cmd.CMDYA + Vdp1Regs->localY);

    xb = (s32)(cmd.CMDXB + Vdp1Regs->localX);
    yb = (s32)(cmd.CMDYB + Vdp1Regs->localY);

    xc = (s32)(cmd.CMDXC + Vdp1Regs->localX);
    yc = (s32)(cmd.CMDYC + Vdp1Regs->localY);

    xd = (s32)(cmd.CMDXD + Vdp1Regs->localX);
    yd = (s32)(cmd.CMDYD + Vdp1Regs->localY);

	drawQuad(xa,ya,xd,yd,xb,yb,xc,yc);
}

static void gouraudLineSetup(double * redstep, double * greenstep, double * bluestep, int length, COLOR table1, COLOR table2) {

	gouraudTable();

	*redstep =interpolate(table1.r,table2.r,length);
	*greenstep =interpolate(table1.g,table2.g,length);
	*bluestep =interpolate(table1.b,table2.b,length);

	leftColumnColor.r = table1.r;
	leftColumnColor.g = table1.g;
	leftColumnColor.b = table1.b;
}

void VIDSoftVdp1PolylineDraw(void)
{
	int X[4];
	int Y[4];
	double redstep = 0, greenstep = 0, bluestep = 0;
	int length;

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

	X[0] = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C));
	Y[0] = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E));
	X[1] = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x10));
	Y[1] = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12));
	X[2] = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14));
	Y[2] = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16));
	X[3] = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x18));
	Y[3] = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1A));

	length = iterateOverLine(X[0], Y[0], X[1], Y[1], 1, NULL, NULL);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudA, gouraudB);
	DrawLine(X[0], Y[0], X[1], Y[1], 0, 0,0,redstep,greenstep,bluestep);

	length = iterateOverLine(X[1], Y[1], X[2], Y[2], 1, NULL, NULL);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudB, gouraudC);
	DrawLine(X[1], Y[1], X[2], Y[2], 0, 0,0,redstep,greenstep,bluestep);

	length = iterateOverLine(X[2], Y[2], X[3], Y[3], 1, NULL, NULL);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudD, gouraudC);
	DrawLine(X[3], Y[3], X[2], Y[2], 0, 0,0,redstep,greenstep,bluestep);

	length = iterateOverLine(X[3], Y[3], X[0], Y[0], 1, NULL, NULL);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudA,gouraudD);
	DrawLine(X[0], Y[0], X[3], Y[3], 0, 0,0,redstep,greenstep,bluestep);
}

void VIDSoftVdp1LineDraw(void)
{
	int x1, y1, x2, y2;
	double redstep = 0, greenstep = 0, bluestep = 0;
	int length;

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

	x1 = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C));
	y1 = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E));
	x2 = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x10));
	y2 = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12));

	length = iterateOverLine(x1, y1, x2, y2, 1, NULL, NULL);
	gouraudLineSetup(&redstep,&bluestep,&greenstep,length, gouraudA, gouraudB);
	DrawLine(x1, y1, x2, y2, 0, 0,0,redstep,greenstep,bluestep);
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1UserClipping(void)
{
   Vdp1Regs->userclipX1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xC);
   Vdp1Regs->userclipY1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xE);
   Vdp1Regs->userclipX2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
   Vdp1Regs->userclipY2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);

#if 0
   vdp1clipxstart = Vdp1Regs->userclipX1;
   vdp1clipxend = Vdp1Regs->userclipX2;
   vdp1clipystart = Vdp1Regs->userclipY1;
   vdp1clipyend = Vdp1Regs->userclipY2;

   // This needs work
   if (vdp1clipxstart > Vdp1Regs->systemclipX1)
      vdp1clipxstart = Vdp1Regs->userclipX1;
   else
      vdp1clipxstart = Vdp1Regs->systemclipX1;

   if (vdp1clipxend < Vdp1Regs->systemclipX2)
      vdp1clipxend = Vdp1Regs->userclipX2;
   else
      vdp1clipxend = Vdp1Regs->systemclipX2;

   if (vdp1clipystart > Vdp1Regs->systemclipY1)
      vdp1clipystart = Vdp1Regs->userclipY1;
   else
      vdp1clipystart = Vdp1Regs->systemclipY1;

   if (vdp1clipyend < Vdp1Regs->systemclipY2)
      vdp1clipyend = Vdp1Regs->userclipY2;
   else
      vdp1clipyend = Vdp1Regs->systemclipY2;
#endif
}

//////////////////////////////////////////////////////////////////////////////

static void PushUserClipping(int mode)
{
   if (mode == 1)
   {
      VDP1LOG("User clipping mode 1 not implemented\n");
      return;
   }

   vdp1clipxstart = Vdp1Regs->userclipX1;
   vdp1clipxend = Vdp1Regs->userclipX2;
   vdp1clipystart = Vdp1Regs->userclipY1;
   vdp1clipyend = Vdp1Regs->userclipY2;

   // This needs work
   if (vdp1clipxstart > Vdp1Regs->systemclipX1)
      vdp1clipxstart = Vdp1Regs->userclipX1;
   else
      vdp1clipxstart = Vdp1Regs->systemclipX1;

   if (vdp1clipxend < Vdp1Regs->systemclipX2)
      vdp1clipxend = Vdp1Regs->userclipX2;
   else
      vdp1clipxend = Vdp1Regs->systemclipX2;

   if (vdp1clipystart > Vdp1Regs->systemclipY1)
      vdp1clipystart = Vdp1Regs->userclipY1;
   else
      vdp1clipystart = Vdp1Regs->systemclipY1;

   if (vdp1clipyend < Vdp1Regs->systemclipY2)
      vdp1clipyend = Vdp1Regs->userclipY2;
   else
      vdp1clipyend = Vdp1Regs->systemclipY2;
}

//////////////////////////////////////////////////////////////////////////////

static void PopUserClipping(void)
{
   vdp1clipxstart = Vdp1Regs->systemclipX1;
   vdp1clipxend = Vdp1Regs->systemclipX2;
   vdp1clipystart = Vdp1Regs->systemclipY1;
   vdp1clipyend = Vdp1Regs->systemclipY2;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1SystemClipping(void)
{
   Vdp1Regs->systemclipX1 = 0;
   Vdp1Regs->systemclipY1 = 0;
   Vdp1Regs->systemclipX2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
   Vdp1Regs->systemclipY2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);

   vdp1clipxstart = Vdp1Regs->systemclipX1;
   vdp1clipxend = Vdp1Regs->systemclipX2;
   vdp1clipystart = Vdp1Regs->systemclipY1;
   vdp1clipyend = Vdp1Regs->systemclipY2;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1LocalCoordinate(void)
{
   Vdp1Regs->localX = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xC);
   Vdp1Regs->localY = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xE);
}

//////////////////////////////////////////////////////////////////////////////

int VIDSoftVdp2Reset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp2DrawStart(void)
{
   int titanblendmode = TITAN_BLEND_TOP;
   if (Vdp2Regs->CCCTL & 0x100) titanblendmode = TITAN_BLEND_ADD;
   else if (Vdp2Regs->CCCTL & 0x200) titanblendmode = TITAN_BLEND_BOTTOM;
   TitanSetBlendingMode(titanblendmode);

   Vdp2DrawBackScreen();
   Vdp2DrawLineScreen();
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp2DrawEnd(void)
{
   int i, i2;
   u16 pixel;
   u8 prioritytable[8];
   u32 vdp1coloroffset;
   int colormode = Vdp2Regs->SPCTL & 0x20;
   vdp2draw_struct info;
   int islinewindow;
   clipping_struct clip[2];
   u32 linewnd0addr, linewnd1addr;
   int wctl;
   clipping_struct colorcalcwindow[2];

   // Figure out whether to draw vdp1 framebuffer or vdp2 framebuffer pixels
   // based on priority
   if (Vdp1External.disptoggle && (Vdp2Regs->TVMD & 0x8000))
   {
      int SPCCCS = (Vdp2Regs->SPCTL >> 12) & 0x3;
      int SPCCN = (Vdp2Regs->SPCTL >> 8) & 0x7;
      u8 colorcalctable[8];
      vdp2rotationparameterfp_struct p;
      int x, y;

      prioritytable[0] = Vdp2Regs->PRISA & 0x7;
      prioritytable[1] = (Vdp2Regs->PRISA >> 8) & 0x7;
      prioritytable[2] = Vdp2Regs->PRISB & 0x7;
      prioritytable[3] = (Vdp2Regs->PRISB >> 8) & 0x7;
      prioritytable[4] = Vdp2Regs->PRISC & 0x7;
      prioritytable[5] = (Vdp2Regs->PRISC >> 8) & 0x7;
      prioritytable[6] = Vdp2Regs->PRISD & 0x7;
      prioritytable[7] = (Vdp2Regs->PRISD >> 8) & 0x7;
      colorcalctable[0] = ((~Vdp2Regs->CCRSA & 0x1F) << 1) + 1;
      colorcalctable[1] = ((~Vdp2Regs->CCRSA >> 7) & 0x3E) + 1;
      colorcalctable[2] = ((~Vdp2Regs->CCRSB & 0x1F) << 1) + 1;
      colorcalctable[3] = ((~Vdp2Regs->CCRSB >> 7) & 0x3E) + 1;
      colorcalctable[4] = ((~Vdp2Regs->CCRSC & 0x1F) << 1) + 1;
      colorcalctable[5] = ((~Vdp2Regs->CCRSC >> 7) & 0x3E) + 1;
      colorcalctable[6] = ((~Vdp2Regs->CCRSD & 0x1F) << 1) + 1;
      colorcalctable[7] = ((~Vdp2Regs->CCRSD >> 7) & 0x3E) + 1;

      vdp1coloroffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
      vdp1spritetype = Vdp2Regs->SPCTL & 0xF;

      ReadVdp2ColorOffset(Vdp2Regs, &info, 0x40, 0x40);

      wctl = Vdp2Regs->WCTLC >> 8;
      clip[0].xstart = clip[0].ystart = clip[0].xend = clip[0].yend = 0;
      clip[1].xstart = clip[1].ystart = clip[1].xend = clip[1].yend = 0;
      ReadWindowData(wctl, clip);
      linewnd0addr = linewnd1addr = 0;
      ReadLineWindowData(&islinewindow, wctl, &linewnd0addr, &linewnd1addr);

      /* color calculation window: in => no color calc, out => color calc */
      ReadWindowData(Vdp2Regs->WCTLD >> 8, colorcalcwindow);

      if (Vdp1Regs->TVMR & 2)
         Vdp2ReadRotationTableFP(0, &p);

      for (i2 = 0; i2 < vdp2height; i2++)
      {
         ReadLineWindowClip(islinewindow, clip, &linewnd0addr, &linewnd1addr);

         LoadLineParamsSprite(&info, i2);

         for (i = 0; i < vdp2width; i++)
         {
            // See if screen position is clipped, if it isn't, continue
            if (!TestBothWindow(wctl, clip, i * resxratio, i2))
            {
               continue;
            }

            if (Vdp1Regs->TVMR & 2) {
               x = (touint(p.Xst + i * p.deltaX + i2 * p.deltaXst)) & (vdp1width - 1);
               y = (touint(p.Yst + i * p.deltaY + i2 * p.deltaYst)) & (vdp1height - 1);
            }
            else
            {
               x = i;
               y = i2;
            }

            if (vdp1pixelsize == 2)
            {
               // 16-bit pixel size
               pixel = ((u16 *)vdp1frontframebuffer)[(y * vdp1width) + x];

               if (pixel == 0)
                  ;
               else if (pixel & 0x8000 && colormode)
               {
                  // 16 BPP               
                  u8 alpha = 0x3F;
                  if ((SPCCCS == 3) && TestBothWindow(Vdp2Regs->WCTLD >> 8, colorcalcwindow, i, i2) && (Vdp2Regs->CCCTL & 0x40))
                  {
                     alpha = colorcalctable[0];
                     if (Vdp2Regs->CCCTL & 0x300) alpha |= 0x80;
                  }
                  // if pixel is 0x8000, only draw pixel if sprite window
                  // is disabled/sprite type 2-7. sprite types 0 and 1 are
                  // -always- drawn and sprite types 8-F are always
                  // transparent.
                  if (pixel != 0x8000 || vdp1spritetype < 2 || (vdp1spritetype < 8 && !(Vdp2Regs->SPCTL & 0x10)))
                     TitanPutPixel(prioritytable[0], i, i2, info.PostPixelFetchCalc(&info, COLSAT2YAB16(alpha, pixel)), 0);
               }
               else
               {
                  // Color bank
                  spritepixelinfo_struct spi;
                  u8 alpha = 0x3F;
                  u32 dot;

                  Vdp1GetSpritePixelInfo(vdp1spritetype, &pixel, &spi);
                  if (spi.normalshadow)
                  {
                     TitanPutShadow(prioritytable[spi.priority], i, i2);
                     continue;
                  }
                  if (spi.msbshadow)
                  {
                     if (Vdp2Regs->SPCTL & 0x10) {
                        /* sprite window, not handled yet... we avoid displaying garbage */
                     } else {
                        /* msb shadow */
                        if (pixel)
                        {
                            dot = Vdp2ColorRamGetColor(vdp1coloroffset + pixel);
                            TitanPutPixel(prioritytable[spi.priority], i, i2, info.PostPixelFetchCalc(&info, COLSAT2YAB32(0x3F, dot)), 0);
                        }
                        TitanPutShadow(prioritytable[spi.priority], i, i2);
                     }
                     continue;
                  }

                  dot = Vdp2ColorRamGetColor(vdp1coloroffset + pixel);

                  if (TestBothWindow(Vdp2Regs->WCTLD >> 8, colorcalcwindow, i, i2) && (Vdp2Regs->CCCTL & 0x40))
                  {
                     int transparent = 0;

                     /* Sprite color calculation */
                     switch(SPCCCS) {
                        case 0:
                           if (prioritytable[spi.priority] <= SPCCN)
                              transparent = 1;
                           break;
                        case 1:
                           if (prioritytable[spi.priority] == SPCCN)
                              transparent = 1;
                           break;
                        case 2:
                           if (prioritytable[spi.priority] >= SPCCN)
                              transparent = 1;
                           break;
                        case 3:
                           if (dot & 0x80000000)
                              transparent = 1;
                           break;
                     }

                     if (Vdp2Regs->CCCTL & 0x200) {
                        /* "bottom" mode, the alpha channel will be used by another layer,
                        so we set it regardless of whether sprites are transparent or not.
                        The highest priority bit is only set if the sprite is transparent
                        (in this case, it's the alpha channel of the lower priority layer
                        that will be used. */
                        alpha = colorcalctable[spi.colorcalc];
                        if (transparent) alpha |= 0x80;
                     } else if (transparent) {
                        alpha = colorcalctable[spi.colorcalc];
                        if (Vdp2Regs->CCCTL & 0x100) alpha |= 0x80;
                     }
                  }

                  TitanPutPixel(prioritytable[spi.priority], i, i2, info.PostPixelFetchCalc(&info, COLSAT2YAB32(alpha, dot)), 0);
               }
            }
            else
            {
               // 8-bit pixel size
               pixel = vdp1frontframebuffer[(y * vdp1width) + x];

               if (pixel != 0)
               {
                  // Color bank(fix me)
                  spritepixelinfo_struct spi;
                  u8 alpha = 0x3F;
                  u32 dot;

                  Vdp1GetSpritePixelInfo(vdp1spritetype, &pixel, &spi);
                  if (spi.normalshadow)
                  {
                     TitanPutShadow(prioritytable[spi.priority], i, i2);
                     continue;
                  }

                  dot = Vdp2ColorRamGetColor(vdp1coloroffset + pixel);

                  if (TestBothWindow(Vdp2Regs->WCTLD >> 8, colorcalcwindow, i, i2) && (Vdp2Regs->CCCTL & 0x40))
                  {
                     int transparent = 0;

                     /* Sprite color calculation */
                     switch(SPCCCS) {
                        case 0:
                           if (prioritytable[spi.priority] <= SPCCN)
                              transparent = 1;
                           break;
                        case 1:
                           if (prioritytable[spi.priority] == SPCCN)
                              transparent = 1;
                           break;
                        case 2:
                           if (prioritytable[spi.priority] >= SPCCN)
                              transparent = 1;
                           break;
                        case 3:
                           if (dot & 0x80000000)
                              transparent = 1;
                           break;
                     }

                     if (Vdp2Regs->CCCTL & 0x200) {
                        /* "bottom" mode, the alpha channel will be used by another layer,
                        so we set it regardless of whether sprites are transparent or not.
                        The highest priority bit is only set if the sprite is transparent
                        (in this case, it's the alpha channel of the lower priority layer
                        that will be used. */
                        alpha = colorcalctable[spi.colorcalc];
                        if (transparent) alpha |= 0x80;
                     } else if (transparent) {
                        alpha = colorcalctable[spi.colorcalc];
                        if (Vdp2Regs->CCCTL & 0x100) alpha |= 0x80;
                     }
                  }

                  TitanPutPixel(prioritytable[spi.priority], i, i2, info.PostPixelFetchCalc(&info, COLSAT2YAB32(alpha, dot)), 0);
               }
            }
         }
      }
   }
   TitanRender(dispbuffer);

   VIDSoftVdp1SwapFrameBuffer();

   if (OSDUseBuffer())
      OSDDisplayMessages(dispbuffer, vdp2width, vdp2height);

#ifdef USE_OPENGL	
	if (vdp2height == 224)
		i = 8;
	else
		i = 0;

   glRasterPos2i(0, outputheight * i / vdp2height);
   glPixelZoom((float)outputwidth / (float)vdp2width, 0 - ((float)outputheight / (float)(vdp2height+i+i)));
   glDrawPixels(vdp2width, vdp2height, GL_RGBA, GL_UNSIGNED_BYTE, dispbuffer);

   if (! OSDUseBuffer())
      OSDDisplayMessages(NULL, -1, -1);
#endif

   YuiSwapBuffers();
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp2DrawScreens(void)
{
   int i;

   VIDSoftVdp2SetResolution(Vdp2Regs->TVMD);
   VIDSoftVdp2SetPriorityNBG0(Vdp2Regs->PRINA & 0x7);
   VIDSoftVdp2SetPriorityNBG1((Vdp2Regs->PRINA >> 8) & 0x7);
   VIDSoftVdp2SetPriorityNBG2(Vdp2Regs->PRINB & 0x7);
   VIDSoftVdp2SetPriorityNBG3((Vdp2Regs->PRINB >> 8) & 0x7);
   VIDSoftVdp2SetPriorityRBG0(Vdp2Regs->PRIR & 0x7);

   for (i = 7; i > 0; i--)
   {   
      if (nbg3priority == i)
         Vdp2DrawNBG3();
      if (nbg2priority == i)
         Vdp2DrawNBG2();
      if (nbg1priority == i)
         Vdp2DrawNBG1();
      if (nbg0priority == i)
         Vdp2DrawNBG0();
      if (rbg0priority == i)
         Vdp2DrawRBG0();
   }
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp2DrawScreen(int screen)
{
   VIDSoftVdp2SetResolution(Vdp2Regs->TVMD);
   VIDSoftVdp2SetPriorityNBG0(Vdp2Regs->PRINA & 0x7);
   VIDSoftVdp2SetPriorityNBG1((Vdp2Regs->PRINA >> 8) & 0x7);
   VIDSoftVdp2SetPriorityNBG2(Vdp2Regs->PRINB & 0x7);
   VIDSoftVdp2SetPriorityNBG3((Vdp2Regs->PRINB >> 8) & 0x7);
   VIDSoftVdp2SetPriorityRBG0(Vdp2Regs->PRIR & 0x7);
   switch(screen)
   {
      case 0:
         Vdp2DrawNBG0();
         break;
      case 1:
         Vdp2DrawNBG1();
         break;
      case 2:
         Vdp2DrawNBG2();
         break;
      case 3:
         Vdp2DrawNBG3();
         break;
      case 4:
         Vdp2DrawRBG0();
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp2SetResolution(u16 TVMD)
{
   // This needs some work

   // Horizontal Resolution
   switch (TVMD & 0x7)
   {
      case 0:
         vdp2width = 320;
         resxratio=1;
         break;
      case 1:
         vdp2width = 352;
         resxratio=1;
         break;
      case 2: // 640
         vdp2width = 320;
         resxratio=2;
         break;
      case 3: // 704
         vdp2width = 352;
         resxratio=2;
         break;
      case 4:
         vdp2width = 320;
         resxratio=1;
         break;
      case 5:
         vdp2width = 352;
         resxratio=1;
         break;
      case 6: // 640
         vdp2width = 320;
         resxratio=2;
         break;
      case 7: // 704
         vdp2width = 352;
         resxratio=2;
         break;
   }

   // Vertical Resolution
   switch ((TVMD >> 4) & 0x3)
   {
      case 0:
         vdp2height = 224;
         break;
      case 1:
         vdp2height = 240;
         break;
      case 2:
         vdp2height = 256;
         break;
      default: break;
   }
   resyratio=1;

   // Check for interlace
   switch ((TVMD >> 6) & 0x3)
   {
      case 3: // Double-density Interlace
//         vdp2height *= 2;
         resyratio=2;
         break;
      case 2: // Single-density Interlace
      case 0: // Non-interlace
      default: break;
   }

   TitanSetResolution(vdp2width, vdp2height);
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDSoftVdp2SetPriorityNBG0(int priority)
{
   nbg0priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDSoftVdp2SetPriorityNBG1(int priority)
{
   nbg1priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDSoftVdp2SetPriorityNBG2(int priority)
{
   nbg2priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDSoftVdp2SetPriorityNBG3(int priority)
{
   nbg3priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDSoftVdp2SetPriorityRBG0(int priority)
{
   rbg0priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1SwapFrameBuffer(void)
{
   if (((Vdp1Regs->FBCR & 2) == 0) || Vdp1External.manualchange)
   {
      u8 *temp = vdp1frontframebuffer;
      vdp1frontframebuffer = vdp1backframebuffer;
      vdp1backframebuffer = temp;
      Vdp1External.manualchange = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftVdp1EraseFrameBuffer(void)
{   
   int i,i2;
   int w,h;

   if (((Vdp1Regs->FBCR & 2) == 0) || Vdp1External.manualerase)
   {
      h = (Vdp1Regs->EWRR & 0x1FF) + 1;
      if (h > vdp1height) h = vdp1height;
      w = ((Vdp1Regs->EWRR >> 6) & 0x3F8) + 8;
      if (w > vdp1width) w = vdp1width;

      if (vdp1pixelsize == 2)
      {
         for (i2 = (Vdp1Regs->EWLR & 0x1FF); i2 < h; i2++)
         {
            for (i = ((Vdp1Regs->EWLR >> 6) & 0x1F8); i < w; i++)
               ((u16 *)vdp1backframebuffer)[(i2 * vdp1width) + i] = Vdp1Regs->EWDR;
         }
      }
      else
      {
         for (i2 = (Vdp1Regs->EWLR & 0x1FF); i2 < h; i2++)
         {
            for (i = ((Vdp1Regs->EWLR >> 6) & 0x1F8); i < w; i++)
               vdp1backframebuffer[(i2 * vdp1width) + i] = Vdp1Regs->EWDR & 0xFF;
         }
      }
      Vdp1External.manualerase = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

void VIDSoftGetGlSize(int *width, int *height)
{
#ifdef USE_OPENGL
   *width = outputwidth;
   *height = outputheight;
#else
   *width = vdp2width;
   *height = vdp2height;
#endif
}
