/*  Copyright 2003-2004 Guillaume Duhamel
    Copyright 2004-2008 Theo Berkau
    Copyright 2006 Fabien Coulon
    Copyright 2010 Lawrence Sebald

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

#include <dispatch/dispatch.h>

#include "vidgcd.h"
#include "vidshared.h"
#include "debug.h"
#include "vdp2.h"

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
#define COLOR_ADD(l,r,g,b)      (COLOR_ADDb(l & 0xFF, r) << 24) | \
                                (COLOR_ADDb((l >> 8) & 0xFF, g) << 16) | \
                                (COLOR_ADDb((l >> 16) & 0xFF, b) << 8) | \
                                ((l >> 24) & 0xFF)
#else
#define COLOR_ADD(l,r,g,b)	COLOR_ADDb((l & 0xFF), r) | \
                                (COLOR_ADDb((l >> 8) & 0xFF, g) << 8) | \
                                (COLOR_ADDb((l >> 16) & 0xFF, b) << 16) | \
				(l & 0xFF000000)
#endif

static void PushUserClipping(int mode);
static void PopUserClipping(void);

int VIDGCDInit(void);
void VIDGCDDeInit(void);
void VIDGCDResize(unsigned int, unsigned int, int);
int VIDGCDIsFullscreen(void);
int VIDGCDVdp1Reset(void);
void VIDGCDVdp1DrawStart(void);
void VIDGCDVdp1DrawEnd(void);
void VIDGCDVdp1NormalSpriteDraw(void);
void VIDGCDVdp1ScaledSpriteDraw(void);
void VIDGCDVdp1DistortedSpriteDraw(void);
void VIDGCDVdp1PolygonDraw(void);
void VIDGCDVdp1PolylineDraw(void);
void VIDGCDVdp1LineDraw(void);
void VIDGCDVdp1UserClipping(void);
void VIDGCDVdp1SystemClipping(void);
void VIDGCDVdp1LocalCoordinate(void);
int VIDGCDVdp2Reset(void);
void VIDGCDVdp2DrawStart(void);
void VIDGCDVdp2DrawEnd(void);
void VIDGCDVdp2DrawScreens(void);
void VIDGCDVdp2SetResolution(u16 TVMD);
void FASTCALL VIDGCDVdp2SetPriorityNBG0(int priority);
void FASTCALL VIDGCDVdp2SetPriorityNBG1(int priority);
void FASTCALL VIDGCDVdp2SetPriorityNBG2(int priority);
void FASTCALL VIDGCDVdp2SetPriorityNBG3(int priority);
void FASTCALL VIDGCDVdp2SetPriorityRBG0(int priority);
void VIDGCDGetGlSize(int *width, int *height);
void VIDGCDVdp1SwapFrameBuffer(void);
void VIDGCDVdp1EraseFrameBuffer(void);

VideoInterface_struct VIDGCD = {
VIDCORE_GCD,
"Grand Central Dispatch Software Video Interface",
VIDGCDInit,
VIDGCDDeInit,
VIDGCDResize,
VIDGCDIsFullscreen,
VIDGCDVdp1Reset,
VIDGCDVdp1DrawStart,
VIDGCDVdp1DrawEnd,
VIDGCDVdp1NormalSpriteDraw,
VIDGCDVdp1ScaledSpriteDraw,
VIDGCDVdp1DistortedSpriteDraw,
//for the actual hardware, polygons are essentially identical to distorted sprites
//the actual hardware draws using diagonal lines, which is why using half-transparent processing
//on distorted sprites and polygons is not recommended since the hardware overdraws to prevent gaps
//thus, with half-transparent processing some pixels will be processed more than once, producing moire patterns in the drawn shapes
VIDGCDVdp1DistortedSpriteDraw,
VIDGCDVdp1PolylineDraw,
VIDGCDVdp1LineDraw,
VIDGCDVdp1UserClipping,
VIDGCDVdp1SystemClipping,
VIDGCDVdp1LocalCoordinate,
VIDGCDVdp2Reset,
VIDGCDVdp2DrawStart,
VIDGCDVdp2DrawEnd,
VIDGCDVdp2DrawScreens,
VIDGCDGetGlSize,
};

static u32 *dispbuffer=NULL;
static u8 *vdp1framebuffer[2]= { NULL, NULL };
static u8 *vdp1frontframebuffer;
static u8 *vdp1backframebuffer;
static u32 *vdp2framebuffer=NULL;

static int vdp1width;
static int vdp1height;
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

struct {
    vdp2draw_struct info;
    u8 prioritytable[8];
    u32 coloroffset;
    int islinewindow;
    clipping_struct clip[2];
    u32 linewnd0addr, linewnd1addr;
    int priosused[8];
} vdp1draw_info;

//////////////////////////////////////////////////////////////////////////////

static INLINE void vdp2putpixel32(s32 x, s32 y, u32 color, int priority)
{
   vdp2framebuffer[(y * vdp2width) + x] = COLSAT2YAB32(priority, color);
}

//////////////////////////////////////////////////////////////////////////////

static INLINE u8 Vdp2GetPixelPriority(u32 pixel)
{
#if defined WORDS_BIGENDIAN
   return pixel;
#else
   return pixel >> 24;
#endif
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void puthline16(s32 x, s32 y, s32 width, u16 color, int priority)
{
   u32 *buffer = vdp2framebuffer + (y * vdp2width) + x;
   u32 dot=COLSAT2YAB16(priority, color);
   int i;

   for (i = 0; i < width; i++)
      buffer[i] = dot;
}

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
         return (((tmp & 0x1F) << 3) | ((tmp & 0x03E0) << 6) | ((tmp & 0x7C00) << 9));
      }
      case 1:
      {
         u32 tmp;
         addr <<= 1;
         tmp = T2ReadWord(Vdp2ColorRam, addr & 0xFFF);
         return (((tmp & 0x1F) << 3) | ((tmp & 0x03E0) << 6) | ((tmp & 0x7C00) << 9));
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
         info->paladdr = (tmp1 & 0x7F) << 4;
         info->specialfunction = (tmp1 & 0x2000) >> 13;
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

static INLINE u32 FASTCALL DoColorCalc(void *info, u32 pixel)
{
#if 0
   u8 oldr, oldg, oldb;
   u8 r, g, b;
   u32 oldpixel = 0x00FFFFFF; // fix me

   static int topratio[32] = {
      31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16,
      15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
   };
   static int bottomratio[32] = {
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
   };

   // separate color components for top and second pixel
   r = (pixel & 0xFF) * topratio[((vdp2draw_struct *)info)->alpha] >> 5;
   g = ((pixel >> 8) & 0xFF) * topratio[((vdp2draw_struct *)info)->alpha] >> 5;
   b = ((pixel >> 16) & 0xFF) * topratio[((vdp2draw_struct *)info)->alpha] >> 5;

#ifdef WORDS_BIGENDIAN
   oldr = ((oldpixel >> 24) & 0xFF) * bottomratio[((vdp2draw_struct *)info)->alpha] >> 5;
   oldg = ((oldpixel >> 16) & 0xFF) * bottomratio[((vdp2draw_struct *)info)->alpha] >> 5;
   oldb = ((oldpixel >> 8) & 0xFF) * bottomratio[((vdp2draw_struct *)info)->alpha] >> 5;
#else
   oldr = (oldpixel & 0xFF) * bottomratio[((vdp2draw_struct *)info)->alpha] >> 5;
   oldg = ((oldpixel >> 8) & 0xFF) * bottomratio[((vdp2draw_struct *)info)->alpha] >> 5;
   oldb = ((oldpixel >> 16) & 0xFF) * bottomratio[((vdp2draw_struct *)info)->alpha] >> 5;
#endif

   // add color components and reform the pixel
   pixel = ((b + oldb) << 16) | ((g + oldg) << 8) | (r + oldr);
#endif
   return pixel;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE u32 FASTCALL DoColorCalcWithColorOffset(void *info, u32 pixel)
{
   pixel = DoColorCalc(info, pixel);

   return COLOR_ADD(pixel, ((vdp2draw_struct *)info)->cor,
                    ((vdp2draw_struct *)info)->cog,
                    ((vdp2draw_struct *)info)->cob);
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void ReadVdp2ColorOffset(vdp2draw_struct *info, int clofmask, int ccmask)
{
   if (Vdp2Regs->CLOFEN & clofmask)
   {
      // color offset enable
      if (Vdp2Regs->CLOFSL & clofmask)
      {
         // color offset B
         info->cor = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            info->cor |= 0xFFFFFF00;

         info->cog = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            info->cog |= 0xFFFFFF00;

         info->cob = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            info->cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         info->cor = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            info->cor |= 0xFFFFFF00;

         info->cog = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            info->cog |= 0xFFFFFF00;

         info->cob = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            info->cob |= 0xFFFFFF00;
      }

      if (info->cor == 0 && info->cog == 0 && info->cob == 0)
      {
         if (Vdp2Regs->CCCTL & ccmask)
            info->PostPixelFetchCalc = &DoColorCalc;
         else
            info->PostPixelFetchCalc = &DoNothing;
      }
      else
      {
         if (Vdp2Regs->CCCTL & ccmask)
            info->PostPixelFetchCalc = &DoColorCalcWithColorOffset;
         else
            info->PostPixelFetchCalc = &DoColorOffset;
      }
   }
   else // color offset disable
   {
      if (Vdp2Regs->CCCTL & ccmask)
         info->PostPixelFetchCalc = &DoColorCalc;
      else
         info->PostPixelFetchCalc = &DoNothing;
   }

}

//////////////////////////////////////////////////////////////////////////////

static INLINE int Vdp2FetchPixel(vdp2draw_struct *info, int x, int y, u32 *color)
{
   u32 dot;

   switch(info->colornumber)
   {
      case 0: // 4 BPP
         dot = T1ReadByte(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) / 2) & 0x7FFFF));
         if (!(x & 0x1)) dot >>= 4;
         if (!(dot & 0xF) && info->transparencyenable) return 0;
         else
         {
            *color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | (dot & 0xF)));
            return 1;
         }
      case 1: // 8 BPP
         dot = T1ReadByte(Vdp2Ram, ((info->charaddr + (y * info->cellw) + x) & 0x7FFFF));
         if (!(dot & 0xFF) && info->transparencyenable) return 0;
         else
         {
            *color = Vdp2ColorRamGetColor(info->coloroffset + (info->paladdr | (dot & 0xFF)));
            return 1;
         }
      case 2: // 16 BPP(palette)
         dot = T1ReadWord(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) * 2) & 0x7FFFF));
         if ((dot == 0) && info->transparencyenable) return 0;
         else
         {
            *color = Vdp2ColorRamGetColor(info->coloroffset + dot);
            return 1;
         }
      case 3: // 16 BPP(RGB)      
         dot = T1ReadWord(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) * 2) & 0x7FFFF));
         if (!(dot & 0x8000) && info->transparencyenable) return 0;
         else
         {
            *color = COLSAT2YAB16(0, dot);
            return 1;
         }
      case 4: // 32 BPP
         dot = T1ReadLong(Vdp2Ram, ((info->charaddr + ((y * info->cellw) + x) * 4) & 0x7FFFF));
         if (!(dot & 0x80000000) && info->transparencyenable) return 0;
         else
         {
            *color = COLSAT2YAB32(0, dot);
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
   }
   return 1;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void GeneratePlaneAddrTable(vdp2draw_struct *info, u32 *planetbl)
{
   int i;

   for (i = 0; i < (info->mapwh*info->mapwh); i++)
   {
      info->PlaneAddr(info, i);
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

static INLINE void SetupScreenVars(vdp2draw_struct *info, screeninfo_struct *sinfo)
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
      sinfo->xmask = sinfo->screenwidth-1;
      sinfo->ymask = sinfo->screenheight-1;
      GeneratePlaneAddrTable(info, sinfo->planetbl);
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

/* FIXME: This function will not work on Big Endian systems. Since its only here
   in vidgcd, and the only thing that this vidcore will work on right now is
   Mac OS X 10.6 (which is only available for Little Endian systems), its ok for
   the time being... */
static INLINE u32 FASTCALL Vdp2Blend(vdp2draw_struct *info, u32 src, u32 dst) {
    u32 alpha, s1, s2, d1, d2, o1, o2, pri;

    pri = Vdp2GetPixelPriority(dst);

    /* If we're not doing color calculation on this plane, then there's no need
       to do any blending... */
    if(info->PostPixelFetchCalc != &DoColorCalc &&
       info->PostPixelFetchCalc != &DoColorCalcWithColorOffset) {
        /* If the old pixel is of higher priority, use it. */
        if(pri > info->priority) {
            return dst;
        }

        return src;
    }

    if(pri < info->priority) {
        pri = info->priority;
    }

    alpha = 255 - (((info->alpha) << 3) + 0x07);

    /* Magic alpha blending! */
    s1 = src & 0x00FF00FF;
    s2 = src & 0x0000FF00;
    d1 = dst & 0x00FF00FF;
    d2 = dst & 0x0000FF00;

    o1 = (d1 + (((s1 - d1) * alpha) >> 8)) & 0x00FF00FF;
    o2 = (d2 + (((s2 - d2) * alpha) >> 8)) & 0x0000FF00;

    return o1 | o2 | (pri << 24);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL GCDVdp2DrawScroll(vdp2draw_struct *_info, u32 *_textdata, int width, int height)
{
    int i, j;
    clipping_struct _clip[2], _clip1, _clip2;
    u32 _linewnd0addr, _linewnd1addr;
    screeninfo_struct _sinfo;
    int scrollx, scrolly;
    int *mosaic_y, *mosaic_x;
    int linescrollmult = (_info->islinescroll & 1) +
        ((_info->islinescroll & 2) >> 1) + ((_info->islinescroll & 4) >> 2);
    
    _info->coordincx *= (float)resxratio;
    _info->coordincy *= (float)resyratio;
    
    SetupScreenVars(_info, &_sinfo);
    
    scrollx = _info->x;
    scrolly = _info->y;
    
    _clip[0].xstart = _clip[0].ystart = _clip[0].xend = _clip[0].yend = 0;
    _clip[1].xstart = _clip[1].ystart = _clip[1].xend = _clip[1].yend = 0;
    ReadWindowData(_info->wctl, _clip);
    _clip1 = _clip[0];
    _clip2 = _clip[1];
    _linewnd0addr = _linewnd1addr = 0;
    ReadLineWindowData(&_info->islinewindow, _info->wctl, &_linewnd0addr, &_linewnd1addr);

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
        mosaic_x = mosaic_table[_info->mosaicxmask-1];
        mosaic_y = mosaic_table[_info->mosaicymask-1];
    }
    
    dispatch_apply(height, dispatch_get_global_queue(2, 0), ^(size_t j) {
        int x, y, i;
        u32 *textdata = _textdata + (j * width);
        u32 linewnd0addr = _linewnd0addr, linewnd1addr = _linewnd1addr;
        screeninfo_struct sinfo = _sinfo;
        clipping_struct clip[2] = { _clip1, _clip2 };
        vdp2draw_struct inf = *_info;
        vdp2draw_struct *info = &inf;
        int Y;
        int linescrollx = 0;
        
        // if line window is enabled, adjust clipping values
        if(info->islinewindow) {
            // Fetch new xstart and xend values from table
            if (info->islinewindow & 0x1)
            {
                // Window 0
                linewnd0addr = _linewnd0addr + j * 4;
                clip[0].xstart = (T1ReadWord(Vdp2Ram, linewnd0addr) & 0x3FF) >> 1; // fix me
                linewnd0addr += 2;
                clip[0].xend = (T1ReadWord(Vdp2Ram, linewnd0addr) & 0x3FF) >> 1; // fix me
            }
            if (info->islinewindow & 0x2)
            {
                // Window 1
                linewnd1addr = _linewnd1addr + j * 4;
                clip[1].xstart = (T1ReadWord(Vdp2Ram, linewnd1addr) & 0x3FF) >> 1; // fix me
                linewnd1addr += 2;
                clip[1].xend = (T1ReadWord(Vdp2Ram, linewnd1addr) & 0x3FF) >> 1; // fix me
            }
        }

        // precalculate the coordinate for the line(it's faster) and do line
        // scroll
        if (info->islinescroll)
        {
            /* Figure out where we actually are in the line scroll table. */
            info->linescrolltbl += linescrollmult * (j << 2);

            if (info->islinescroll & 0x1)
            {
                linescrollx = (T1ReadLong(Vdp2Ram, info->linescrolltbl) >> 16) & 0x7FF;
                info->linescrolltbl += 4;
            }
            if (info->islinescroll & 0x2)
            {
                info->y = (T1ReadWord(Vdp2Ram, info->linescrolltbl) & 0x7FF) + scrolly;
                info->linescrolltbl += 4;
                y = info->y;
            }
            else
                //y = info->y+((int)(info->coordincy *(float)(info->mosaicymask > 1 ? (j / info->mosaicymask * info->mosaicymask) : j)));
                y = info->y + info->coordincy*mosaic_y[j];
            if (info->islinescroll & 0x4)
            {
                info->coordincx = (T1ReadLong(Vdp2Ram, info->linescrolltbl) & 0x7FF00) / (float)65536.0;
                info->linescrolltbl += 4;
            }
        }
        else
            //y = info->y+((int)(info->coordincy *(float)(info->mosaicymask > 1 ? (j / info->mosaicymask * info->mosaicymask) : j)));
            y = info->y + info->coordincy * mosaic_y[j];
        
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
        
        for (i = 0; i < width; i++)
        {
            u32 color;
            
            // See if screen position is clipped, if it isn't, continue
            // AND window logic
            if(!TestWindow(info->wctl, 0x2, 0x1, &clip[0], i, j) && !TestWindow(info->wctl, 0x8, 0x4, &clip[1], i, j) && (info->wctl & 0x80) == 0x80)
            {
                textdata++;
                continue;
            }
            //OR window logic
            else if ((info->wctl & 0x80) == 0)
            {
                if (!TestWindow(info->wctl, 0x2, 0x1, &clip[0], i, j))
                {
                    textdata++;
                    continue;
                }
                
                // Window 1
                if (!TestWindow(info->wctl, 0x8, 0x4, &clip[1], i,j))
                {
                    textdata++;
                    continue;
                }
            }
            
            //x = info->x+((int)(info->coordincx*(float)((info->mosaicxmask > 1) ? (i / info->mosaicxmask * info->mosaicxmask) : i)));
            x = info->x + mosaic_x[i]*info->coordincx;
            x &= sinfo.xmask;
            
            if (linescrollx) {
                x += linescrollx;
                x &= 0x3FF;
            }
            
            if (!info->isbitmap)
            {
                // Tile
                y=Y;
                // need to calculate this without history!
                Vdp2MapCalcXY(info, &x, &y, &sinfo);
            }
            
            // If priority of screen is less than current top pixel and per
            // pixel priority isn't used, skip it
#ifndef CRAB_REWRITE
            if (Vdp2GetPixelPriority(textdata[0]) > info->priority)
            {
                textdata++;
                continue;
            }
#endif
            
            // Fetch Pixel, if it isn't transparent, continue
            if (!Vdp2FetchPixel(info, x, y, &color))
            {
                textdata++;
                continue;
            }
            
            // check special priority somewhere here
            
            // Apply color offset and color calculation/special color calculation
            // and then continue.
            // We almost need to know well ahead of time what the top
            // and second pixel is in order to work this.
            
#ifndef CRAB_REWRITE
            textdata[0] = COLSAT2YAB32(info->priority, info->PostPixelFetchCalc(info, color));
            textdata++;
#else
            color = COLSAT2YAB32(info->priority, info->PostPixelFetchCalc(info, color));
            *textdata++ = Vdp2Blend(info, color, *textdata);
#endif
        }
    });
}

//////////////////////////////////////////////////////////////////////////////

static void SetupRotationInfo(vdp2draw_struct *info, vdp2rotationparameterfp_struct *p)
{
   if (info->rotatenum == 0)
   {
      Vdp2ReadRotationTableFP(0, p);
      info->PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterAPlaneAddr;
   }
   else
   {
      Vdp2ReadRotationTableFP(1, &p[1]);
      info->PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2ParameterBPlaneAddr;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL Vdp2DrawRotationFP(vdp2draw_struct *info, vdp2rotationparameterfp_struct *parameter)
{
   int i, j;
   int x, y;
   screeninfo_struct sinfo;
   vdp2rotationparameterfp_struct *p=&parameter[info->rotatenum];

   SetupRotationInfo(info, parameter);

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
         u32 *textdata=vdp2framebuffer;

         GenerateRotatedVarFP(p, &xmul, &ymul, &C, &F);

         // Do simple rotation
         CalculateRotationValuesFP(p);

         SetupScreenVars(info, &sinfo);

         for (j = 0; j < vdp2height; j++)
         {
            for (i = 0; i < vdp2width; i++)
            {
               u32 color;

               x = GenerateRotatedXPosFP(p, i, xmul, ymul, C) & sinfo.xmask;
               y = GenerateRotatedYPosFP(p, i, xmul, ymul, F) & sinfo.ymask;
               xmul += p->deltaXst;

               // Convert coordinates into graphics
               if (!info->isbitmap)
               {
                  // Tile
                  Vdp2MapCalcXY(info, &x, &y, &sinfo);
               }
 
               // If priority of screen is less than current top pixel and per
               // pixel priority isn't used, skip it
               if (Vdp2GetPixelPriority(textdata[0]) > info->priority)
               {
                  textdata++;
                  continue;
               }

               // Fetch pixel
               if (!Vdp2FetchPixel(info, x, y, &color))
               {
                  textdata++;
                  continue;
               }

               textdata[0] = COLSAT2YAB32(info->priority, info->PostPixelFetchCalc(info, color));
               textdata++;
            }
            ymul += p->deltaYst;
         }

         return;
      }
   }
   else
   {
      fixed32 xmul, ymul, C, F;
      fixed32 coefx, coefy;
      u32 *textdata=vdp2framebuffer;

      GenerateRotatedVarFP(p, &xmul, &ymul, &C, &F);

      // Rotation using Coefficient Tables(now this stuff just gets wacky. It
      // has to be done in software, no exceptions)
      CalculateRotationValuesFP(p);

      SetupScreenVars(info, &sinfo);
      coefx = coefy = 0;

      for (j = 0; j < vdp2height; j++)
      {
         if (p->deltaKAx == 0)
         {
            Vdp2ReadCoefficientFP(p,
                                  p->coeftbladdr +
                                  touint(coefy) *
                                  p->coefdatasize);
         }

         for (i = 0; i < vdp2width; i++)
         {
            u32 color;

            if (p->deltaKAx != 0)
            {
               Vdp2ReadCoefficientFP(p,
                                     p->coeftbladdr +
                                     toint(coefy + coefx) *
                                     p->coefdatasize);
               coefx += p->deltaKAx;
            }

            if (p->msb)
            {
               textdata++;
               continue;
            }

            x = GenerateRotatedXPosFP(p, i, xmul, ymul, C) & sinfo.xmask;
            y = GenerateRotatedYPosFP(p, i, xmul, ymul, F) & sinfo.ymask;
            xmul += p->deltaXst;

            // Convert coordinates into graphics
            if (!info->isbitmap)
            {
               // Tile
               Vdp2MapCalcXY(info, &x, &y, &sinfo);
            }

            // If priority of screen is less than current top pixel and per
            // pixel priority isn't used, skip it
            if (Vdp2GetPixelPriority(textdata[0]) > info->priority)
            {
               textdata++;
               continue;
            }

            // Fetch pixel
            if (!Vdp2FetchPixel(info, x, y, &color))
            {
               textdata++;
               continue;
            }

            textdata[0] = COLSAT2YAB32(info->priority, info->PostPixelFetchCalc(info, color));
            textdata++;
         }
         ymul += p->deltaYst;
         coefx = 0;
         coefy += p->deltaKAst;
      }
      return;
   }

   GCDVdp2DrawScroll(info, vdp2framebuffer, vdp2width, vdp2height);
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawBackScreen(void)
{
   int i;

   // Only draw black if TVMD's DISP and BDCLMD bits are cleared
   if ((Vdp2Regs->TVMD & 0x8000) == 0 && (Vdp2Regs->TVMD & 0x100) == 0)
   {
      // Draw Black
      for (i = 0; i < (vdp2width * vdp2height); i++)
         vdp2framebuffer[i] = 0;
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

            puthline16(0, i, vdp2width, dot, 0);
         }
      }
      else
      {
         // Single Color
         dot = T1ReadWord(Vdp2Ram, scrAddr);

         for (i = 0; i < (vdp2width * vdp2height); i++)
            vdp2framebuffer[i] = COLSAT2YAB16(0, dot);
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG0(void)
{
   vdp2draw_struct info;
   vdp2rotationparameterfp_struct parameter[2];

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

   if (Vdp2Regs->CCCTL & 0x1)
      info.alpha = Vdp2Regs->CCRNA & 0x1F;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7) << 8;
   ReadVdp2ColorOffset(&info, 0x1, 0x1);
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

   if (info.enable == 1)
   {
      // NBG0 draw
      GCDVdp2DrawScroll(&info, vdp2framebuffer, vdp2width, vdp2height);
   }
   else
   {
      // RBG1 draw
      Vdp2DrawRotationFP(&info, parameter);
   }
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
   }
   else
   {
      info.mapwh = 2;

      ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 2);

      info.x = Vdp2Regs->SCXIN1 & 0x7FF;
      info.y = Vdp2Regs->SCYIN1 & 0x7FF;

      ReadPatternData(&info, Vdp2Regs->PNCN1, Vdp2Regs->CHCTLA & 0x100);
   }

   if (Vdp2Regs->CCCTL & 0x2)
      info.alpha = (Vdp2Regs->CCRNA >> 8) & 0x1F;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x70) << 4;
   ReadVdp2ColorOffset(&info, 0x2, 0x2);
   info.coordincx = (Vdp2Regs->ZMXN1.all & 0x7FF00) / (float) 65536;
   info.coordincy = (Vdp2Regs->ZMYN1.all & 0x7FF00) / (float) 65536;

   info.priority = nbg1priority;
   info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG1PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle))
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

   GCDVdp2DrawScroll(&info, vdp2framebuffer, vdp2width, vdp2height);
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
    
   if (Vdp2Regs->CCCTL & 0x4)
      info.alpha = Vdp2Regs->CCRNB & 0x1F;

   info.coloroffset = Vdp2Regs->CRAOFA & 0x700;
   ReadVdp2ColorOffset(&info, 0x4, 0x4);
   info.coordincx = info.coordincy = 1;

   info.priority = nbg2priority;
   info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG2PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle))
      return;

   ReadMosaicData(&info, 0x4);
   info.islinescroll = 0;
   info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLB;
   info.isbitmap = 0;

   GCDVdp2DrawScroll(&info, vdp2framebuffer, vdp2width, vdp2height);
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

   if (Vdp2Regs->CCCTL & 0x8)
      info.alpha = (Vdp2Regs->CCRNB >> 8) & 0x1F;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7000) >> 4;
   ReadVdp2ColorOffset(&info, 0x8, 0x8);
   info.coordincx = info.coordincy = 1;

   info.priority = nbg3priority;
   info.PlaneAddr = (void FASTCALL (*)(void *, int))&Vdp2NBG3PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle))
      return;

   ReadMosaicData(&info, 0x8);
   info.islinescroll = 0;
   info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLB >> 8;
   info.isbitmap = 0;

   GCDVdp2DrawScroll(&info, vdp2framebuffer, vdp2width, vdp2height);
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawRBG0(void)
{
   vdp2draw_struct info;
   vdp2rotationparameterfp_struct parameter[2];

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

   if (Vdp2Regs->CCCTL & 0x10)
      info.alpha = Vdp2Regs->CCRR & 0x1F;

   info.coloroffset = (Vdp2Regs->CRAOFB & 0x7) << 8;

   ReadVdp2ColorOffset(&info, 0x10, 0x10);
   info.coordincx = info.coordincy = 1;

   ReadMosaicData(&info, 0x10);
   info.islinescroll = 0;
   info.isverticalscroll = 0;
   info.wctl = Vdp2Regs->WCTLC;

   Vdp2DrawRotationFP(&info, parameter);
}

//////////////////////////////////////////////////////////////////////////////

int VIDGCDInit(void)
{
   // Initialize output buffer
   if ((dispbuffer = (u32 *)calloc(sizeof(u32), 704 * 512)) == NULL)
      return -1;

   // Initialize VDP1 framebuffer 1
   if ((vdp1framebuffer[0] = (u8 *)calloc(sizeof(u8), 0x40000)) == NULL)
      return -1;

   // Initialize VDP1 framebuffer 2
   if ((vdp1framebuffer[1] = (u8 *)calloc(sizeof(u8), 0x40000)) == NULL)
      return -1;

   // Initialize VDP2 framebuffer
   if ((vdp2framebuffer = (u32 *)calloc(sizeof(u32), 704 * 512)) == NULL)
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

void VIDGCDDeInit(void)
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

   if (vdp2framebuffer)
      free(vdp2framebuffer);
}

//////////////////////////////////////////////////////////////////////////////

static int IsFullscreen = 0;

void VIDGCDResize(unsigned int w, unsigned int h, int on)
{
#ifdef USE_OPENGL
   IsFullscreen = on;

   glClear(GL_COLOR_BUFFER_BIT);

   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrtho(0, w, h, 0, 1, 0);

   glMatrixMode(GL_TEXTURE);
   glLoadIdentity();
   glOrtho(-w, w, -h, h, 1, 0);

   glViewport(0, 0, w, h);
   outputwidth = w;
   outputheight = h;
#endif
}

//////////////////////////////////////////////////////////////////////////////

int VIDGCDIsFullscreen(void) {
   return IsFullscreen;
}

//////////////////////////////////////////////////////////////////////////////

int VIDGCDVdp1Reset(void)
{
   vdp1clipxstart = 0;
   vdp1clipxend = 512;
   vdp1clipystart = 0;
   vdp1clipyend = 256;
   
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp1DrawStart(void)
{
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
         vdp1width = 256;
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

   VIDGCDVdp1EraseFrameBuffer();
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp1DrawEnd(void)
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
			currentPixelIsVisible = 0xffff;
			break;
	}

	if(!isTextured)
		currentPixel = untexturedColor;

	//force the MSB to be on if MSBON is set
	currentPixel |= cmd.CMDPMOD & (1 << 15);

	return 0;
}

static int gouraudAdjust( int color, int tableValue )
{
	color += (tableValue - 0x10);

	if ( color < 0 ) color = 0;
	if ( color > 0x1f ) color = 0x1f;

	return color;
}

static void putpixel(int x, int y) {

	u16* iPix = &((u16 *)vdp1backframebuffer)[(y * vdp1width) + x];
	int mesh = cmd.CMDPMOD & 0x0100;
	int SPD = ((cmd.CMDPMOD & 0x40) != 0);//show the actual color of transparent pixels if 1 (they won't be drawn transparent)
	int currentShape = cmd.CMDCTRL & 0x7;
	int isTextured=1;

	if(mesh && (x^y)&1)
		return;

	if(currentShape == 4 || currentShape == 5 || currentShape == 6)
		isTextured = 0;

	if (cmd.CMDPMOD & 0x0400) PushUserClipping((cmd.CMDPMOD >> 9) & 0x1);

	if (x >= vdp1clipxstart &&
		x < vdp1clipxend &&
		y >= vdp1clipystart &&
		y < vdp1clipyend)
	{}
	else
		return;

	if (cmd.CMDPMOD & 0x0400) PopUserClipping();


	if ( SPD || (currentPixel & currentPixelIsVisible))
	{
		switch( cmd.CMDPMOD & 0x7 )//we want bits 0,1,2
		{
		case 0:	// replace
			if (!((currentPixel == 0) && !SPD)) 
				*(iPix) = currentPixel;
			break;
		case 1: // shadow, TODO
			*(iPix) = currentPixel;
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

        if(*iPix & 0x8000) {
            vdp1draw_info.priosused[vdp1draw_info.prioritytable[0]] = 1;
        }
        else if(*iPix) {
            u16 p = *iPix;
            int s, prio, c;

            Vdp1ProcessSpritePixel(vdp1spritetype, &p, &s, &prio, &c);
            vdp1draw_info.priosused[prio] = 1;
        }
	}
}

//TODO consolidate the following 3 functions
static int bresenham( int x1, int y1, int x2, int y2, int x[], int y[])
{
	int dx, dy, xf, yf, a, b, c, i;

	if (x2>x1) {
		dx = x2-x1;
		xf = 1;
	}
	else {
		dx = x1-x2;
		xf = -1;
	}

	if (y2>y1) {
		dy = y2-y1;
		yf = 1;
	}
	else {
		dy = y1-y2;
		yf = -1;
	}

	//burning rangers tries to draw huge shapes
	//this will at least let it run
	if(dx > 999 || dy > 999)
		return INT_MAX;

	if (dx>dy) {
		a = dy+dy;
		c = a-dx;
		b = c-dx;
		for (i=0;i<=dx;i++) {
			x[i] = x1; y[i] = y1;
			x1 += xf;
			if (c<0) {
				c += a;
			}
			else {
				c += b;
				y1 += yf;
			}
		}
		return dx+1;
	}
	else {
		a = dx+dx;
		c = a-dy;
		b = c-dy;
		for (i=0;i<=dy;i++) {
			x[i] = x1; y[i] = y1;
			y1 += yf;
			if (c<0) {
				c += a;
			}
			else {
				c += b;
				x1 += xf;
			}
		}
		return dy+1;
	}
}

static int DrawLine( int x1, int y1, int x2, int y2, double linenumber, double texturestep, double xredstep, double xgreenstep, double xbluestep)
{
	int dx, dy, xf, yf, a, b, c, i;
	int endcodesdetected=0;
	int previousStep = 123456789;

	if (x2>x1) {
		dx = x2-x1;
		xf = 1;
	}
	else {
		dx = x1-x2;
		xf = -1;
	}

	if (y2>y1) {
		dy = y2-y1;
		yf = 1;
	}
	else {
		dy = y1-y2;
		yf = -1;
	}

	if (dx>dy) {
		a = dy+dy;
		c = a-dx;
		b = c-dx;
		for (i=0;i<=dx;i++) {
			leftColumnColor.r+=xredstep;
			leftColumnColor.g+=xgreenstep;
			leftColumnColor.b+=xbluestep;

			if(getpixel(linenumber,(int)i*texturestep)) {
				if(currentPixel != previousStep) {
					previousStep = (int)i*texturestep;
					endcodesdetected++;
				}
			}
			else
				putpixel(x1,y1);

			previousStep = currentPixel;

			if(endcodesdetected==2)
				break;

			x1 += xf;
			if (c<0) {
				c += a;
			}
			else {
				getpixel(linenumber,(int)i*texturestep);
				putpixel(x1,y1);
				c += b;
				y1 += yf;
/*
				//same as sega's way, but just move the code down here instead
				//and use the pixel we already have instead of the next one
				if(xf>1&&yf>1) putpixel(x1,y1-1); //case 1
				if(xf<1&&yf<1) putpixel(x1,y1+1); //case 2
				if(xf<1&&yf>1) putpixel(x1+1,y1); //case 7
				if(xf>1&&yf<1) putpixel(x1-1,y1); //case 8*/
			}
		}
		return dx+1;
	}
	else {
		a = dx+dx;
		c = a-dy;
		b = c-dy;	
	for (i=0;i<=dy;i++) {
			leftColumnColor.r+=xredstep;
			leftColumnColor.g+=xgreenstep;
			leftColumnColor.b+=xbluestep;

			if(getpixel(linenumber,(int)i*texturestep)) {
				if(currentPixel != previousStep) {
					previousStep = (int)i*texturestep;
					endcodesdetected++;
				}
			}
			else
				putpixel(x1,y1);

			previousStep = currentPixel;

			if(endcodesdetected==2)
				break;

			y1 += yf;
			if (c<0) {
				c += a;
			}
			else {
				getpixel(linenumber,(int)i*texturestep);
				putpixel(x1,y1);
				c += b;
				x1 += xf;
/*				
				if(xf>1&&yf>1) putpixel(x1,y1-1); //case 3
				if(xf<1&&yf<1) putpixel(x1,y1+1); //case 4
				if(xf<1&&yf>1) putpixel(x1+1,y1); //case 5
				if(xf>1&&yf<1) putpixel(x1-1,y1); //case 6*/

			}
		}
		return dy+1;
	}
}

static int getlinelength(int x1, int y1, int x2, int y2) {
	int dx, dy, xf, yf, a, b, c, i;

	if (x2>x1) {
		dx = x2-x1;
		xf = 1;
	}
	else {
		dx = x1-x2;
		xf = -1;
	}

	if (y2>y1) {
		dy = y2-y1;
		yf = 1;
	}
	else {
		dy = y1-y2;
		yf = -1;
	}

	if (dx>dy) {
		a = dy+dy;
		c = a-dx;
		b = c-dx;
		for (i=0;i<=dx;i++) {

			x1 += xf;
			if (c<0) {
				c += a;
			}
			else {
				c += b;
				y1 += yf;
			}
		}
		return dx+1;
	}
	else {
		a = dx+dx;
		c = a-dy;
		b = c-dy;	
	for (i=0;i<=dy;i++) {
			y1 += yf;
			if (c<0) {
				c += a;
			}
			else {
				c += b;
				x1 += xf;
			}
		}
		return dy+1;
	}
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

//a real vdp1 draws with arbitrary lines
//this is why endcodes are possible
//this is also the reason why half-transparent shading causes moire patterns
//and the reason why gouraud shading can be applied to a single line draw command
static void drawQuad(s32 tl_x, s32 tl_y, s32 bl_x, s32 bl_y, s32 tr_x, s32 tr_y, s32 br_x, s32 br_y){

	int totalleft;
	int totalright;
	int total;
	int i;

	COLOR_PARAMS topLeftToBottomLeftColorStep = {0,0,0}, topRightToBottomRightColorStep = {0,0,0};
		
	//how quickly we step through the line arrays
	double leftLineStep = 1;
	double rightLineStep = 1; 

	//a lookup table for the gouraud colors
	COLOR colors[4];

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);
	characterWidth = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
	characterHeight = cmd.CMDSIZE & 0xFF;

	totalleft  = bresenham(tl_x,tl_y,bl_x,bl_y,xleft,yleft);
	totalright = bresenham(tr_x,tr_y,br_x,br_y,xright,yright);

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
		xlinelength = getlinelength(
			xleft[(int)(i*leftLineStep)],
			yleft[(int)(i*leftLineStep)],
			xright[(int)(i*rightLineStep)],
			yright[(int)(i*rightLineStep)]);

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
			ytexturestep*i, 
			xtexturestep,
			leftToRightStep.r,
			leftToRightStep.g,
			leftToRightStep.b
			);
	}
}

void VIDGCDVdp1NormalSpriteDraw() {

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

void VIDGCDVdp1ScaledSpriteDraw(){

	s32 topLeftx,topLefty,topRightx,topRighty,bottomRightx,bottomRighty,bottomLeftx,bottomLefty;
	int spriteWidth;
	int spriteHeight;
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

	spriteWidth = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
	spriteHeight = cmd.CMDSIZE & 0xFF;

	topLeftx = x0;
	topLefty = y0;

	topRightx = x1 + x0 - 1;
	topRighty = topLefty;

	bottomRightx = x1 + x0 - 1;
	bottomRighty = y1 + y0 - 1;

	bottomLeftx = topLeftx;
	bottomLefty = y1 + y0 - 1;

	drawQuad(topLeftx,topLefty,bottomLeftx,bottomLefty,topRightx,topRighty,bottomRightx,bottomRighty);
}

void VIDGCDVdp1DistortedSpriteDraw() {

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

void VIDGCDVdp1PolylineDraw(void)
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

	length = getlinelength(X[0], Y[0], X[1], Y[1]);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudA, gouraudB);
	DrawLine(X[0], Y[0], X[1], Y[1], 0,0,redstep,greenstep,bluestep);

	length = getlinelength(X[1], Y[1], X[2], Y[2]);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudB, gouraudC);
	DrawLine(X[1], Y[1], X[2], Y[2], 0,0,redstep,greenstep,bluestep);

	length = getlinelength(X[2], Y[2], X[3], Y[3]);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudD, gouraudC);
	DrawLine(X[3], Y[3], X[2], Y[2], 0,0,redstep,greenstep,bluestep);

	length = getlinelength(X[3], Y[3], X[0], Y[0]);
	gouraudLineSetup(&redstep,&greenstep,&bluestep,length, gouraudA,gouraudD);
	DrawLine(X[0], Y[0], X[3], Y[3], 0,0,redstep,greenstep,bluestep);
}

void VIDGCDVdp1LineDraw(void)
{
	int x1, y1, x2, y2;
	double redstep = 0, greenstep = 0, bluestep = 0;
	int length;

	Vdp1ReadCommand(&cmd, Vdp1Regs->addr);

	x1 = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C));
	y1 = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E));
	x2 = (int)Vdp1Regs->localX + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x10));
	y2 = (int)Vdp1Regs->localY + (int)((s16)T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12));

	length = getlinelength(x1, y1, x2, y2);
	gouraudLineSetup(&redstep,&bluestep,&greenstep,length, gouraudA, gouraudB);
	DrawLine(x1, y1, x2, y2, 0,0,redstep,greenstep,bluestep);
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp1UserClipping(void)
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

void VIDGCDVdp1SystemClipping(void)
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

void VIDGCDVdp1LocalCoordinate(void)
{
   Vdp1Regs->localX = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xC);
   Vdp1Regs->localY = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xE);
}

//////////////////////////////////////////////////////////////////////////////

int VIDGCDVdp2Reset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp2DrawStart(void)
{
    int wctl;
   Vdp2DrawBackScreen();

    vdp1draw_info.prioritytable[0] = Vdp2Regs->PRISA & 0x7;
    vdp1draw_info.prioritytable[1] = (Vdp2Regs->PRISA >> 8) & 0x7;
    vdp1draw_info.prioritytable[2] = Vdp2Regs->PRISB & 0x7;
    vdp1draw_info.prioritytable[3] = (Vdp2Regs->PRISB >> 8) & 0x7;
    vdp1draw_info.prioritytable[4] = Vdp2Regs->PRISC & 0x7;
    vdp1draw_info.prioritytable[5] = (Vdp2Regs->PRISC >> 8) & 0x7;
    vdp1draw_info.prioritytable[6] = Vdp2Regs->PRISD & 0x7;
    vdp1draw_info.prioritytable[7] = (Vdp2Regs->PRISD >> 8) & 0x7;

    vdp1draw_info.coloroffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
    vdp1spritetype = Vdp2Regs->SPCTL & 0xF;

    if(Vdp2Regs->CLOFEN & 0x40) {
        // color offset enable
        if(Vdp2Regs->CLOFSL & 0x40) {
            // color offset B
            vdp1draw_info.info.cor = Vdp2Regs->COBR & 0xFF;
            if(Vdp2Regs->COBR & 0x100)
                vdp1draw_info.info.cor |= 0xFFFFFF00;
            
            vdp1draw_info.info.cog = Vdp2Regs->COBG & 0xFF;
            if(Vdp2Regs->COBG & 0x100)
                vdp1draw_info.info.cog |= 0xFFFFFF00;
            
            vdp1draw_info.info.cob = Vdp2Regs->COBB & 0xFF;
            if(Vdp2Regs->COBB & 0x100)
                vdp1draw_info.info.cob |= 0xFFFFFF00;
        }
        else {
            // color offset A
            vdp1draw_info.info.cor = Vdp2Regs->COAR & 0xFF;
            if(Vdp2Regs->COAR & 0x100)
                vdp1draw_info.info.cor |= 0xFFFFFF00;
            
            vdp1draw_info.info.cog = Vdp2Regs->COAG & 0xFF;
            if(Vdp2Regs->COAG & 0x100)
                vdp1draw_info.info.cog |= 0xFFFFFF00;
            
            vdp1draw_info.info.cob = Vdp2Regs->COAB & 0xFF;
            if(Vdp2Regs->COAB & 0x100)
                vdp1draw_info.info.cob |= 0xFFFFFF00;
        }
        
        if(vdp1draw_info.info.cor == 0 && vdp1draw_info.info.cog == 0 && vdp1draw_info.info.cob == 0) {
            if(Vdp2Regs->CCCTL & 0x40)
                vdp1draw_info.info.PostPixelFetchCalc = &DoColorCalc;
            else
                vdp1draw_info.info.PostPixelFetchCalc = &DoNothing;
        }
        else {
            if(Vdp2Regs->CCCTL & 0x40)
                vdp1draw_info.info.PostPixelFetchCalc = &DoColorCalcWithColorOffset;
            else
                vdp1draw_info.info.PostPixelFetchCalc = &DoColorOffset;
        }
    }
    else { // color offset disable
        if(Vdp2Regs->CCCTL & 0x40)
            vdp1draw_info.info.PostPixelFetchCalc = &DoColorCalc;
        else
            vdp1draw_info.info.PostPixelFetchCalc = &DoNothing;
    }

    wctl = Vdp2Regs->WCTLC >> 8;
    vdp1draw_info.clip[0].xstart = vdp1draw_info.clip[0].ystart = 0;
    vdp1draw_info.clip[0].xend = vdp1draw_info.clip[0].yend = 0;
    vdp1draw_info.clip[1].xstart = vdp1draw_info.clip[1].ystart = 0;
    vdp1draw_info.clip[1].xend = vdp1draw_info.clip[1].yend = 0;
    ReadWindowData(wctl, vdp1draw_info.clip);
    vdp1draw_info.linewnd0addr = vdp1draw_info.linewnd1addr = 0;
    ReadLineWindowData(&vdp1draw_info.islinewindow, wctl, &vdp1draw_info.linewnd0addr, &vdp1draw_info.linewnd1addr);
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp2DrawEnd(void)
{
#ifndef CRAB_REWRITE
   int i, i2;
   u16 pixel;
   u8 prioritytable[8];
   u32 vdp1coloroffset;
   int colormode = Vdp2Regs->SPCTL & 0x20;
   vdp2draw_struct info;
   u32 *dst=dispbuffer;
   u32 *vdp2src=vdp2framebuffer;
   int islinewindow;
   clipping_struct clip[2];
   u32 linewnd0addr, linewnd1addr;
   int wctl;

   // Figure out whether to draw vdp1 framebuffer or vdp2 framebuffer pixels
   // based on priority
   if (Vdp1External.disptoggle)
   {
      prioritytable[0] = Vdp2Regs->PRISA & 0x7;
      prioritytable[1] = (Vdp2Regs->PRISA >> 8) & 0x7;
      prioritytable[2] = Vdp2Regs->PRISB & 0x7;
      prioritytable[3] = (Vdp2Regs->PRISB >> 8) & 0x7;
      prioritytable[4] = Vdp2Regs->PRISC & 0x7;
      prioritytable[5] = (Vdp2Regs->PRISC >> 8) & 0x7;
      prioritytable[6] = Vdp2Regs->PRISD & 0x7;
      prioritytable[7] = (Vdp2Regs->PRISD >> 8) & 0x7;

      vdp1coloroffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
      vdp1spritetype = Vdp2Regs->SPCTL & 0xF;

      if (Vdp2Regs->CLOFEN & 0x40)
      {
         // color offset enable
         if (Vdp2Regs->CLOFSL & 0x40)
         {
            // color offset B
            info.cor = Vdp2Regs->COBR & 0xFF;
            if (Vdp2Regs->COBR & 0x100)
               info.cor |= 0xFFFFFF00;

            info.cog = Vdp2Regs->COBG & 0xFF;
            if (Vdp2Regs->COBG & 0x100)
               info.cog |= 0xFFFFFF00;

            info.cob = Vdp2Regs->COBB & 0xFF;
            if (Vdp2Regs->COBB & 0x100)
               info.cob |= 0xFFFFFF00;
         }
         else
         {
            // color offset A
            info.cor = Vdp2Regs->COAR & 0xFF;
            if (Vdp2Regs->COAR & 0x100)
               info.cor |= 0xFFFFFF00;

            info.cog = Vdp2Regs->COAG & 0xFF;
            if (Vdp2Regs->COAG & 0x100)
               info.cog |= 0xFFFFFF00;

            info.cob = Vdp2Regs->COAB & 0xFF;
            if (Vdp2Regs->COAB & 0x100)
               info.cob |= 0xFFFFFF00;
         }

         if (info.cor == 0 && info.cog == 0 && info.cob == 0)
         {
            if (Vdp2Regs->CCCTL & 0x40)
               info.PostPixelFetchCalc = &DoColorCalc;
            else
               info.PostPixelFetchCalc = &DoNothing;
         }
         else
         {
            if (Vdp2Regs->CCCTL & 0x40)
               info.PostPixelFetchCalc = &DoColorCalcWithColorOffset;
            else
               info.PostPixelFetchCalc = &DoColorOffset;
         }
      }
      else // color offset disable
      {
         if (Vdp2Regs->CCCTL & 0x40)
            info.PostPixelFetchCalc = &DoColorCalc;
         else
            info.PostPixelFetchCalc = &DoNothing;
      }

      wctl = Vdp2Regs->WCTLC >> 8;
      clip[0].xstart = clip[0].ystart = clip[0].xend = clip[0].yend = 0;
      clip[1].xstart = clip[1].ystart = clip[1].xend = clip[1].yend = 0;
      ReadWindowData(wctl, clip);
      linewnd0addr = linewnd1addr = 0;
      ReadLineWindowData(&islinewindow, wctl, &linewnd0addr, &linewnd1addr);

      for (i2 = 0; i2 < vdp2height; i2++)
      {
         ReadLineWindowClip(islinewindow, clip, &linewnd0addr, &linewnd1addr);

         for (i = 0; i < vdp2width; i++)
         {
            // See if screen position is clipped, if it isn't, continue
            // Window 0
            if (!TestWindow(wctl, 0x2, 0x1, &clip[0], i, i2))
            {
               dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               vdp2src++;
               dst++;
               continue;
            }

            // Window 1
            if (!TestWindow(wctl, 0x8, 0x4, &clip[1], i, i2))
            {
               vdp2src++;
               dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               dst++;
               continue;
            }

            if (vdp1pixelsize == 2)
            {
               // 16-bit pixel size
               pixel = ((u16 *)vdp1frontframebuffer)[(i2 * vdp1width) + i];

               if (pixel == 0)
                  dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               else if (pixel & 0x8000 && colormode)
               {
                  // 16 BPP               
                  if (prioritytable[0] >= Vdp2GetPixelPriority(vdp2src[0]))
                  {
                     // if pixel is 0x8000, only draw pixel if sprite window
                     // is disabled/sprite type 2-7. sprite types 0 and 1 are
                     // -always- drawn and sprite types 8-F are always
                     // transparent.
                     if (pixel != 0x8000 || vdp1spritetype < 2 || (vdp1spritetype < 8 && !(Vdp2Regs->SPCTL & 0x10)))
                        dst[0] = info.PostPixelFetchCalc(&info, COLSAT2YAB16(0xFF, pixel));
                     else
                        dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
                  }
                  else               
                     dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               }
               else
               {
                  // Color bank
		  int priority;
		  int shadow;
		  int colorcalc;
		  priority = 0;  // Avoid compiler warning
                  Vdp1ProcessSpritePixel(vdp1spritetype, &pixel, &shadow, &priority, &colorcalc);
                  if (prioritytable[priority] >= Vdp2GetPixelPriority(vdp2src[0]))
                     dst[0] = info.PostPixelFetchCalc(&info, COLSAT2YAB32(0xFF, Vdp2ColorRamGetColor(vdp1coloroffset + pixel)));
                  else               
                     dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               }
            }
            else
            {
               // 8-bit pixel size
               pixel = vdp1frontframebuffer[(i2 * vdp1width) + i];

               if (pixel == 0)
                  dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               else
               {
                  // Color bank(fix me)
                  LOG("8-bit Color Bank draw - %02X\n", pixel);
                  dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
               }
            }
            vdp2src++;
            dst++;
         }
      }
   }
   else
   {
      // Render VDP2 only
      for (i = 0; i < (vdp2width*vdp2height); i++)
         dispbuffer[i] = COLSATSTRIPPRIORITY(vdp2framebuffer[i]);
   }
#endif

   VIDGCDVdp1SwapFrameBuffer();

   if (OSDUseBuffer())
      OSDDisplayMessages(dispbuffer, vdp2width, vdp2height);

#ifdef USE_OPENGL
   glRasterPos2i(0, 0);
   glPixelZoom((float)outputwidth / (float)vdp2width, 0 - ((float)outputheight / (float)vdp2height));
#ifndef CRAB_REWRITE
   glDrawPixels(vdp2width, vdp2height, GL_RGBA, GL_UNSIGNED_BYTE, dispbuffer);
#else
    glDisable(GL_BLEND);
    glDrawPixels(vdp2width, vdp2height, GL_RGBA, GL_UNSIGNED_BYTE, vdp2framebuffer);
#endif

   if (! OSDUseBuffer())
      OSDDisplayMessages(NULL, -1, -1);
#endif

   YuiSwapBuffers();
}

/* FIXME: Support Vdp1 8-bit mode sometime... */
static void Vdp1DrawPriority(int prio) {
    int colormode = Vdp2Regs->SPCTL & 0x20;
    vdp2draw_struct *info = &vdp1draw_info.info;
    int islinewindow = vdp1draw_info.islinewindow;
    int wctl= Vdp2Regs->WCTLC >> 8;

    // Figure out whether to draw vdp1 framebuffer or vdp2 framebuffer pixels
    // based on priority
    if(Vdp1External.disptoggle) {
        dispatch_apply(vdp2height, dispatch_get_global_queue(2, 0), ^(size_t i2) {
            u16 *fb16 = (u16 *)(vdp1frontframebuffer) + (i2 * vdp1width);
            u32 *fb = vdp2framebuffer + (i2 * vdp2width);
            int i;
            u16 pixel;
            u32 linewnd0addr = vdp1draw_info.linewnd0addr;
            u32 linewnd1addr = vdp1draw_info.linewnd1addr;

            ReadLineWindowClip(islinewindow, vdp1draw_info.clip, &linewnd0addr, &linewnd1addr);
            
            for(i = 0; i < vdp2width; ++i, ++fb16, ++fb) {
                // See if screen position is clipped, if it isn't, continue
                // Window 0
                if(!TestWindow(wctl, 0x2, 0x1, &vdp1draw_info.clip[0], i, i2)) {
                    continue;
                }
                
                // Window 1
                if(!TestWindow(wctl, 0x8, 0x4, &vdp1draw_info.clip[1], i, i2)) {
                    continue;
                }
                
                if (vdp1pixelsize == 2) {
                    // 16-bit pixel size
                    pixel = *fb16;

                    if(pixel & 0x8000 && colormode && vdp1draw_info.prioritytable[0] == prio &&
                       prio >= Vdp2GetPixelPriority(*fb)) {
                        // 16 BPP
                        // if pixel is 0x8000, only draw pixel if sprite window
                        // is disabled/sprite type 2-7. sprite types 0 and 1 are
                        // -always- drawn and sprite types 8-F are always
                        // transparent.
                        if(pixel != 0x8000 || vdp1spritetype < 2 || (vdp1spritetype < 8 && !(Vdp2Regs->SPCTL & 0x10)))
                            *fb = info->PostPixelFetchCalc(info, COLSAT2YAB16(0xFF, pixel));
                    }
                    else if(pixel) {
                        // Color bank
                        int priority;
                        int shadow;
                        int colorcalc;
                        priority = 0;  // Avoid compiler warning
                        Vdp1ProcessSpritePixel(vdp1spritetype, &pixel, &shadow, &priority, &colorcalc);
                        priority = vdp1draw_info.prioritytable[priority];
                        if(priority == prio && priority >= Vdp2GetPixelPriority(*fb))
                            *fb = info->PostPixelFetchCalc(info, COLSAT2YAB32(0xFF, Vdp2ColorRamGetColor(vdp1draw_info.coloroffset + pixel)));
                    }
                }
                //else
                //{
                //    // 8-bit pixel size
                //    pixel = vdp1frontframebuffer[(i2 * vdp1width) + i];
                //    
                //    if (pixel == 0)
                //        dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
                //    else
                //    {
                //        // Color bank(fix me)
                //        LOG("8-bit Color Bank draw - %02X\n", pixel);
                //        dst[0] = COLSATSTRIPPRIORITY(vdp2src[0]);
                //    }
                //}
            }
        });
    }
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp2DrawScreens(void)
{
   int i;

   VIDGCDVdp2SetResolution(Vdp2Regs->TVMD);
   VIDGCDVdp2SetPriorityNBG0(Vdp2Regs->PRINA & 0x7);
   VIDGCDVdp2SetPriorityNBG1((Vdp2Regs->PRINA >> 8) & 0x7);
   VIDGCDVdp2SetPriorityNBG2(Vdp2Regs->PRINB & 0x7);
   VIDGCDVdp2SetPriorityNBG3((Vdp2Regs->PRINB >> 8) & 0x7);
   VIDGCDVdp2SetPriorityRBG0(Vdp2Regs->PRIR & 0x7);

    /* Draw all the screens, from the lowest priority one forward. */
    for(i = 1; i < 8; ++i)
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

        /* Draw anything in VDP1 that should be shown at this priority level. */
        if(vdp1draw_info.priosused[i])
            Vdp1DrawPriority(i);
        vdp1draw_info.priosused[i] = 0;
    }
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp2SetResolution(u16 TVMD)
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
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDGCDVdp2SetPriorityNBG0(int priority)
{
   nbg0priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDGCDVdp2SetPriorityNBG1(int priority)
{
   nbg1priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDGCDVdp2SetPriorityNBG2(int priority)
{
   nbg2priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDGCDVdp2SetPriorityNBG3(int priority)
{
   nbg3priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void FASTCALL VIDGCDVdp2SetPriorityRBG0(int priority)
{
   rbg0priority = priority;
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDGetScreenSize(int *width, int *height)
{
   *width = vdp2width;
   *height = vdp2height;
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp1SwapFrameBuffer(void)
{
   u8 *temp = vdp1frontframebuffer;
   vdp1frontframebuffer = vdp1backframebuffer;
   vdp1backframebuffer = temp;
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDVdp1EraseFrameBuffer(void)
{   
    int s, s2;
    int w,h;

    h = (Vdp1Regs->EWRR & 0x1FF) + 1;
    if (h > vdp1height) h = vdp1height;
    w = ((Vdp1Regs->EWRR >> 6) & 0x3F8) + 8;
    if (w > vdp1width) w = vdp1width;

    s = Vdp1Regs->EWLR & 0x1FF;
    s2 = (Vdp1Regs->EWLR >> 6) & 0x1F8;

    dispatch_apply(h - s, dispatch_get_global_queue(2, 0), ^(size_t i2) {
        int i;
        i2 += s;
        for (i = s2; i < w; i++) {
            ((u16 *)vdp1backframebuffer)[(i2 * vdp1width) + i] = Vdp1Regs->EWDR;
        }
    });
}

//////////////////////////////////////////////////////////////////////////////

void VIDGCDGetGlSize(int *width, int *height)
{
#ifdef USE_OPENGL
   *width = outputwidth;
   *height = outputheight;
#else
   *width = vdp2width;
   *height = vdp2height;
#endif
}
