/*  Copyright 2003-2006 Guillaume Duhamel
    Copyright 2004 Lawrence Sebald
    Copyright 2004-2007 Theo Berkau

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

/*! \file vidogl.c
    \brief OpenGL video renderer
*/

#if defined(HAVE_LIBGL) || defined(__ANDROID__)

#include <math.h>
#define EPSILON (1e-10 )


#include "vidogl.h"
#include "vidshared.h"
#include "debug.h"
#include "vdp2.h"
#include "yabause.h"
#include "ygl.h"
#include "yui.h"

#if defined WORDS_BIGENDIAN
#define SAT2YAB1(alpha,temp)      (alpha | (temp & 0x7C00) << 1 | (temp & 0x3E0) << 14 | (temp & 0x1F) << 27)
#else
#define SAT2YAB1(alpha,temp)      (alpha << 24 | (temp & 0x1F) << 3 | (temp & 0x3E0) << 6 | (temp & 0x7C00) << 9)
#endif

#if defined WORDS_BIGENDIAN
#define SAT2YAB2(alpha,dot1,dot2)       ((dot2 & 0xFF << 24) | ((dot2 & 0xFF00) << 8) | ((dot1 & 0xFF) << 8) | alpha)
#else
#define SAT2YAB2(alpha,dot1,dot2)       (alpha << 24 | ((dot1 & 0xFF) << 16) | (dot2 & 0xFF00) | (dot2 & 0xFF))
#endif

#define COLOR_ADDt(b)      (b>0xFF?0xFF:(b<0?0:b))
#define COLOR_ADDb(b1,b2)   COLOR_ADDt((signed) (b1) + (b2))
#ifdef WORDS_BIGENDIAN
#define COLOR_ADD(l,r,g,b)   (COLOR_ADDb((l >> 24) & 0xFF, r) << 24) | \
            (COLOR_ADDb((l >> 16) & 0xFF, g) << 16) | \
            (COLOR_ADDb((l >> 8) & 0xFF, b) << 8) | \
            (l & 0xFF)
#else
#define COLOR_ADD(l,r,g,b)   COLOR_ADDb((l & 0xFF), r) | \
            (COLOR_ADDb((l >> 8 ) & 0xFF, g) << 8) | \
            (COLOR_ADDb((l >> 16 ) & 0xFF, b) << 16) | \
            (l & 0xFF000000)
#endif

int VIDOGLInit(void);
void VIDOGLDeInit(void);
void VIDOGLResize(unsigned int, unsigned int, int);
int VIDOGLIsFullscreen(void);
int VIDOGLVdp1Reset(void);
void VIDOGLVdp1DrawStart(void);
void VIDOGLVdp1DrawEnd(void);
void VIDOGLVdp1NormalSpriteDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer);
void VIDOGLVdp1ScaledSpriteDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer);
void VIDOGLVdp1DistortedSpriteDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer);
void VIDOGLVdp1PolygonDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer);
void VIDOGLVdp1PolylineDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer);
void VIDOGLVdp1LineDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer);
void VIDOGLVdp1UserClipping(u8 * ram, Vdp1 * regs);
void VIDOGLVdp1SystemClipping(u8 * ram, Vdp1 * regs);
void VIDOGLVdp1LocalCoordinate(u8 * ram, Vdp1 * regs);
int VIDOGLVdp2Reset(void);
void VIDOGLVdp2DrawStart(void);
void VIDOGLVdp2DrawEnd(void);
void VIDOGLVdp2DrawScreens(void);
void VIDOGLVdp2SetResolution(u16 TVMD);
void YglGetGlSize(int *width, int *height);
void VIDOGLGetNativeResolution(int *width, int *height, int*interlace);
void VIDOGLVdp1ReadFrameBuffer(u32 type, u32 addr, void * out);

VideoInterface_struct VIDOGL = {
VIDCORE_OGL,
"OpenGL Video Interface",
VIDOGLInit,
VIDOGLDeInit,
VIDOGLResize,
VIDOGLIsFullscreen,
VIDOGLVdp1Reset,
VIDOGLVdp1DrawStart,
VIDOGLVdp1DrawEnd,
VIDOGLVdp1NormalSpriteDraw,
VIDOGLVdp1ScaledSpriteDraw,
VIDOGLVdp1DistortedSpriteDraw,
VIDOGLVdp1PolygonDraw,
VIDOGLVdp1PolylineDraw,
VIDOGLVdp1LineDraw,
VIDOGLVdp1UserClipping,
VIDOGLVdp1SystemClipping,
VIDOGLVdp1LocalCoordinate,
VIDOGLVdp1ReadFrameBuffer,
NULL,
VIDOGLVdp2Reset,
VIDOGLVdp2DrawStart,
VIDOGLVdp2DrawEnd,
VIDOGLVdp2DrawScreens,
YglGetGlSize,
VIDOGLGetNativeResolution,
};

float vdp1wratio=1;
float vdp1hratio=1;

int GlWidth=320;
int GlHeight=224;

int vdp1cor=0;
int vdp1cog=0;
int vdp1cob=0;

static int vdp2width;
static int vdp2height;
static int nbg0priority=0;
static int nbg1priority=0;
static int nbg2priority=0;
static int nbg3priority=0;
static int rbg0priority=0;

static u32 Vdp2ColorRamGetColor(u32 colorindex, int alpha);
static void Vdp2PatternAddrPos(vdp2draw_struct *info, int planex, int x, int planey, int y);
static void Vdp2DrawPatternPos(vdp2draw_struct *info, YglTexture *texture, int x, int y, int cx, int cy);
static INLINE void ReadVdp2ColorOffset(Vdp2 * regs, vdp2draw_struct *info, int mask);

// Window Parameter
static vdp2WindowInfo * m_vWindinfo0 = NULL;
static int m_vWindinfo0_size = -1;
static int m_b0WindowChg;
static vdp2WindowInfo * m_vWindinfo1 = NULL;
static int m_vWindinfo1_size = -1;
static int m_b1WindowChg;

static vdp2Lineinfo lineNBG0[512];
static vdp2Lineinfo lineNBG1[512];



// Rotate Screen
static vdp2rotationparameter_struct  paraA;
static vdp2rotationparameter_struct  paraB;



vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue2W( vdp2rotationparameter_struct * param, int index );
vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue1W( vdp2rotationparameter_struct * param, int index );
vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue2Wm3( vdp2rotationparameter_struct * param, int index );
vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue1Wm3( vdp2rotationparameter_struct * param, int index );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode00NoK( vdp2draw_struct * info, int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode00WithK( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode01NoK( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode01WithK( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode02NoK( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode02WithKA( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode02WithKB( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03NoK( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03WithKA( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03WithKB( vdp2draw_struct * info,int h, int v );
vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03WithK( vdp2draw_struct * info,int h, int v );


static void FASTCALL Vdp1ReadPriority(vdp1cmd_struct *cmd, int * priority, int * colorcl, int * normal_shadow );
static void FASTCALL Vdp1ReadTexture(vdp1cmd_struct *cmd, YglSprite *sprite, YglTexture *texture);

u32 FASTCALL Vdp2ColorRamGetColorCM01SC0(vdp2draw_struct * info, u32 colorindex, int alpha );
u32 FASTCALL Vdp2ColorRamGetColorCM01SC1(vdp2draw_struct * info, u32 colorindex, int alpha );
u32 FASTCALL Vdp2ColorRamGetColorCM01SC3(vdp2draw_struct * info, u32 colorindex, int alpha );
u32 FASTCALL Vdp2ColorRamGetColorCM2(vdp2draw_struct * info, u32 colorindex, int alpha );


//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL Vdp1ReadPolygonColor(vdp1cmd_struct *cmd)
{
	int shadow = 0;
	int priority = 0;
	int colorcl = 0;

	int ednmode;
	int endcnt = 0;
	int nromal_shadow = 0;

	u8 SPD = ((cmd->CMDPMOD & 0x40) != 0);
	u8 END = ((cmd->CMDPMOD & 0x80) != 0);
	u8 MSB = ((cmd->CMDPMOD & 0x8000) != 0);
	u32 alpha = 0xFF;
	u32 color = 0x00;
	int SPCCCS = (Vdp2Regs->SPCTL >> 12) & 0x3;

	VDP1LOG("Making new sprite %08X\n", charAddr);

	Vdp1ReadPriority(cmd, &priority, &colorcl, &nromal_shadow);
	alpha = 0xF8;
	if (((Vdp2Regs->CCCTL >> 6) & 0x01) == 0x01)
	{
		switch (SPCCCS)
		{
		case 0:
			if (priority <= ((Vdp2Regs->SPCTL >> 8) & 0x07))
				alpha = 0xF8 - ((colorcl << 3) & 0xF8);
			break;
		case 1:
			if (priority == ((Vdp2Regs->SPCTL >> 8) & 0x07))
				alpha = 0xF8 - ((colorcl << 3) & 0xF8);
			break;
		case 2:
			if (priority >= ((Vdp2Regs->SPCTL >> 8) & 0x07))
				alpha = 0xF8 - ((colorcl << 3) & 0xF8);
			break;
		case 3:
			//if( priority <= (Vdp2Regs->SPCTL>>8)&0x07 )
			//   alpha = 0xF8-((colorcl<<3)&0xF8);
			break;
		}
	}

	alpha |= priority;

	switch ((cmd->CMDPMOD >> 3) & 0x7)
	{
	case 0:
	{
		// 4 bpp Bank mode
		u32 colorBank = cmd->CMDCOLR;
		u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
		u16 i;

		// Pixel 1
		if (!SPD) color = 0x00;
		else if (MSB) color = (alpha << 24);
		else if (colorBank == 0x0000){
			u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
			talpha |= priority;
			color = Vdp2ColorRamGetColor(colorBank + colorOffset, talpha);
		}
		else if (colorBank == nromal_shadow){
			u32 talpha = (u8)0xF8 - (u8)0x80;
			talpha |= priority;
			color = (talpha << 24);
		}
		else{

			if (SPCCCS == 0x03 ){
				u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorBank + colorOffset)<<2)&0xFFF );
				if (checkcol & 0x8000){
					u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
					talpha |= priority;
					color = Vdp2ColorRamGetColor(colorBank + colorOffset, talpha);
				}
				else{
					color = Vdp2ColorRamGetColor(colorBank + colorOffset, alpha);
				}
			}
			else{
				color = Vdp2ColorRamGetColor(colorBank + colorOffset, alpha);
			}
		}
		break;
	}
	case 1:
	{
		// 4 bpp LUT mode
		u16 temp;
		u32 colorLut = cmd->CMDCOLR * 8;
		u16 i;
		u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;

		if (!SPD) color = 0;
		else{
			temp = T1ReadWord(Vdp1Ram, colorLut & 0x7FFFF);
			if (temp & 0x8000)
			{
				if (MSB) color = (alpha << 24);
				else color = SAT2YAB1(alpha, temp);
			}else if (temp != 0x0000)
			{
				Vdp1ProcessSpritePixel(Vdp2Regs->SPCTL & 0xF, &temp, &shadow, &priority, &colorcl);
				if (shadow != 0)
				{
					u32 talpha = (u8)0xF8 - (u8)0x80;
					talpha |= priority;
					color = (talpha << 24);
				}
				else{
#ifdef WORDS_BIGENDIAN
					priority = ((u8 *)&Vdp2Regs->PRISA)[priority ^ 1] & 0x7;
					colorcl = ((u8 *)&Vdp2Regs->CCRSA)[colorcl ^ 1] & 0x1F;
#else
					priority = ((u8 *)&Vdp2Regs->PRISA)[priority] & 0x7;
					colorcl = ((u8 *)&Vdp2Regs->CCRSA)[colorcl] & 0x1F;
#endif
					alpha = 0xF8;
					if (((Vdp2Regs->CCCTL >> 6) & 0x01) == 0x01)
					{
						switch ((Vdp2Regs->SPCTL >> 12) & 0x03)
						{
						case 0:
							if (priority <= ((Vdp2Regs->SPCTL >> 8) & 0x07))
								alpha = 0xF8 - ((colorcl << 3) & 0xF8);
							break;
						case 1:
							if (priority == ((Vdp2Regs->SPCTL >> 8) & 0x07))
								alpha = 0xF8 - ((colorcl << 3) & 0xF8);
							break;
						case 2:
							if (priority >= ((Vdp2Regs->SPCTL >> 8) & 0x07))
								alpha = 0xF8 - ((colorcl << 3) & 0xF8);
							break;
						case 3:
						{
							u16 checkcol = T2ReadWord(Vdp2ColorRam, ((temp + colorOffset) << Vdp2Internal.ColorMode) & 0xFFF);
							if (checkcol & 0x8000){
								alpha = 0xF8 - ((colorcl << 3) & 0xF8);
							}
						}
							break;
						}
					}
					alpha |= priority;
					if (MSB) color = (alpha << 24);
					else color = Vdp2ColorRamGetColor(temp + colorOffset, alpha);
				}
			}else{
				color = 0x0;
			}
		}

		break;
	}
	case 2:
	{
		// 8 bpp(64 color) Bank mode
		u32 colorBank = cmd->CMDCOLR & 0xFFC0;
		u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
		if (!SPD) color = 0x00;
		else if (MSB) color = (alpha << 24);
		else if ( colorBank == nromal_shadow){
			u32 talpha = (u8)0xF8 - (u8)0x80;
			talpha |= priority;
			color = (talpha << 24);
		}else{
			const int colorindex = (colorBank) + colorOffset;
			if (SPCCCS == 0x03){
				u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
				if (checkcol & 0x8000){
					u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
					talpha |= priority;
					color = Vdp2ColorRamGetColor(colorindex, talpha);
				}
				else{
					color = Vdp2ColorRamGetColor(colorindex, alpha);
				}
			}
			else{
				color = Vdp2ColorRamGetColor(colorindex, alpha);
			}
		}
		break;
	}
	case 3:
	{
		// 8 bpp(128 color) Bank mode
		u32 colorBank = cmd->CMDCOLR & 0xFF80;
		u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
		if (!SPD) color = 0x00;
		else if (MSB) color= (alpha << 24);
		else if (colorBank == nromal_shadow){
			u32 talpha = (u8)0xF8 - (u8)0x80;
			talpha |= priority;
			color = (talpha << 24);
		}
		else{
			const int colorindex = (colorBank)+colorOffset;
			if (SPCCCS == 0x03){
				u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
				if (checkcol & 0x8000){
					u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
					talpha |= priority;
					color = Vdp2ColorRamGetColor(colorindex, talpha);
				}
				else{
					color = Vdp2ColorRamGetColor(colorindex, alpha);
				}
			}
			else{
				color = Vdp2ColorRamGetColor(colorindex, alpha);
			}
		}
		break;
	}
	case 4:
	{
		// 8 bpp(256 color) Bank mode
		u32 colorBank = cmd->CMDCOLR & 0xFF00;
		u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
		if (!SPD) color = 0x00;
		else if (MSB) color = (alpha << 24);
		else if (color == nromal_shadow){
			u32 talpha = (u8)0xF8 - (u8)0x80;
			talpha |= priority;
			color = (talpha << 24);
		}
		else{
			const int colorindex = (colorBank)+colorOffset;
			if (SPCCCS == 0x03){
				u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
				if (checkcol & 0x8000){
					u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
					talpha |= priority;
					color = Vdp2ColorRamGetColor(colorindex, talpha);
				}
				else{
					color = Vdp2ColorRamGetColor(colorindex, alpha);
				}
			}
			else{
				color = Vdp2ColorRamGetColor(colorindex, alpha);
			}
		}
	}
		break;
	case 5:
	{
		// 16 bpp Bank mode
		u32 charAddr = cmd->CMDSRCA * 8;
		u16 dot = T1ReadWord(Vdp1Ram, charAddr & 0x7FFFF);
		//if (!(dot & 0x8000) && (Vdp2Regs->SPCTL & 0x20)) printf("mixed mode\n");
		if (!(dot & 0x8000) && !SPD) color = 0x00;
		else if ((dot == 0x7FFF) && !END) color = 0x0;
		else if (MSB) color = (alpha << 24);
		else if (dot == nromal_shadow){
			u32 talpha = (u8)0xF8 - (u8)0x80;
			talpha |= priority;
			color = (talpha << 24);
		}else if (SPCCCS == 0x03 && (dot & 0x8000)){
			u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
			talpha |= priority;
			color = SAT2YAB1(talpha, dot);
		}
		else{
			color = SAT2YAB1(alpha, dot);
		}
	}
		break;
	default:
		VDP1LOG("Unimplemented sprite color mode: %X\n", (cmd->CMDPMOD >> 3) & 0x7);
		break;
	}

	return color;
}



static void FASTCALL Vdp1ReadTexture(vdp1cmd_struct *cmd, YglSprite *sprite, YglTexture *texture)
{
   int shadow = 0;
   int priority = 0;
   int colorcl = 0;

   int ednmode;
   int endcnt = 0;
   int nromal_shadow = 0;

   u32 charAddr = cmd->CMDSRCA * 8;
   u32 dot;
   u8 SPD = ((cmd->CMDPMOD & 0x40) != 0);
   u8 END = ((cmd->CMDPMOD & 0x80) != 0);
   u8 MSB = ((cmd->CMDPMOD & 0x8000) != 0);
   u32 alpha = 0xFF;
   int SPCCCS = (Vdp2Regs->SPCTL >> 12) & 0x3;
   VDP1LOG("Making new sprite %08X\n", charAddr);


   if( (cmd->CMDPMOD & 0x20) == 0)
      ednmode = 1;
   else
      ednmode = 0;

   Vdp1ReadPriority(cmd, &priority, &colorcl, &nromal_shadow );


   alpha = 0xF8;
   if( ((Vdp2Regs->CCCTL >> 6) & 0x01) == 0x01  )
   {
	   switch (SPCCCS)
      {
      case 0:
         if( priority <= ((Vdp2Regs->SPCTL>>8)&0x07) )
         alpha = 0xF8-((colorcl<<3)&0xF8);
         break;
      case 1:
         if( priority == ((Vdp2Regs->SPCTL>>8)&0x07) )
         alpha = 0xF8-((colorcl<<3)&0xF8);
         break;
      case 2:
         if( priority >= ((Vdp2Regs->SPCTL>>8)&0x07) )
         alpha = 0xF8-((colorcl<<3)&0xF8);
         break;
      case 3:
         //if( priority <= (Vdp2Regs->SPCTL>>8)&0x07 )
      //   alpha = 0xF8-((colorcl<<3)&0xF8);
         break;
      }
   }

   alpha |= priority;

   switch((cmd->CMDPMOD >> 3) & 0x7)
   {
      case 0:
      {
         // 4 bpp Bank mode
         u32 colorBank = cmd->CMDCOLR;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
         u16 i;

         for(i = 0;i < sprite->h;i++)
         {
            u16 j;
            j = 0;
            while(j < sprite->w)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);

               // Pixel 1
               if (((dot >> 4) == 0) && !SPD) *texture->textdata++ = 0x00;
               else if( ((dot >> 4) == 0x0F) && !END ) *texture->textdata++ = 0x00;
               else if( MSB ) *texture->textdata++ = (alpha<<24);
			   else if (((dot >> 4) | colorBank) == 0x0000){
				   //u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
				   //talpha |= priority;
				   *texture->textdata++ = 0; //Vdp2ColorRamGetColor(((dot >> 4) | colorBank) + colorOffset, talpha);
			   }
			   else if (((dot >> 4) | colorBank) == nromal_shadow){
				   u32 talpha = (u8)0xF8 - (u8)0x80;
				   talpha |= priority;
				   *texture->textdata++ = (talpha << 24);
			   }
			   else{
				   int colorindex = ((dot >> 4) | colorBank) + colorOffset;
				   if (SPCCCS == 0x03){
					   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
					   if (checkcol & 0x8000){
						   u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
						   talpha |= priority;
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, talpha);
					   }
					   else{
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
					   }
				   }
				   else{
					   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
				   }
			   }
               j += 1;

               // Pixel 2
               if (((dot & 0xF) == 0) && !SPD) *texture->textdata++  = 0x00;
               else if( ((dot & 0xF) == 0x0F) && !END ) *texture->textdata++ = 0x00;
               else if( MSB ) *texture->textdata++ = (alpha<<24);
               else if (((dot & 0x0F) | colorBank) == 0x0000){
                 //u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
                 //talpha |= priority;
				   *texture->textdata++ = 0; // Vdp2ColorRamGetColor(((dot & 0xF) | colorBank) + colorOffset, talpha);
			   }
			   else if (((dot & 0xF) | colorBank) == nromal_shadow){
				   u32 talpha = (u8)0xF8 - (u8)0x80;
				   talpha |= priority;
				   *texture->textdata++ = (talpha << 24);
			   }
			   else{
				   int colorindex = ((dot & 0xF) | colorBank) + colorOffset;
				   if (SPCCCS == 0x03){
					   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
					   if (checkcol & 0x8000){
						   u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
						   talpha |= priority;
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, talpha);
					   }
					   else{
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
					   }
				   }
				   else{
					   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
				   }
			   }
               j += 1;

               charAddr += 1;
            }
            texture->textdata += texture->w;
         }
         break;
      }
      case 1:
      {
         // 4 bpp LUT mode
         u16 temp;
         u32 colorLut = cmd->CMDCOLR * 8;
         u16 i;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;

         for(i = 0;i < sprite->h;i++)
         {
            u16 j;
            j = 0;
            endcnt = 0;
            while(j < sprite->w)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);

               if( ednmode && endcnt >= 2 )
               {
                  *texture->textdata++ = 0x00;
               }else if (((dot >> 4) == 0) && !SPD)
               {
                  *texture->textdata++ = 0;
               }else if (((dot >> 4) == 0x0F) && !END ) // 6. Commandtable end code
               {
                  *texture->textdata++ = 0x0;
                  endcnt++;

               }else{
                  temp = T1ReadWord(Vdp1Ram, ((dot >> 4) * 2 + colorLut) & 0x7FFFF);
                  if (temp & 0x8000)
                  {
                     if( MSB ) *texture->textdata++ = (alpha<<24);
                     else *texture->textdata++ = SAT2YAB1(alpha, temp);
                  }else if( temp != 0x0000)
                  {
                     Vdp1ProcessSpritePixel(Vdp2Regs->SPCTL & 0xF, &temp, &shadow, &priority, &colorcl);
                     if( shadow != 0 )
                     {
						 u32 talpha = (u8)0xF8 - (u8)0x80;
						 talpha |= priority;
						 *texture->textdata++ = (talpha << 24);
                     }else{
#ifdef WORDS_BIGENDIAN
                        priority = ((u8 *)&Vdp2Regs->PRISA)[priority^1]&0x7;
                        colorcl =  ((u8 *)&Vdp2Regs->CCRSA)[colorcl^1]&0x1F;
#else
                        priority = ((u8 *)&Vdp2Regs->PRISA)[priority]&0x7;
                        colorcl =  ((u8 *)&Vdp2Regs->CCRSA)[colorcl]&0x1F;
#endif
                        alpha = 0xF8;
                        if( ((Vdp2Regs->CCCTL >> 6) & 0x01) == 0x01  )
                        {
							switch (SPCCCS)
                           {
                           case 0:
                              if( priority <= ((Vdp2Regs->SPCTL>>8)&0x07) )
                              alpha = 0xF8-((colorcl<<3)&0xF8);
                              break;
                           case 1:
                              if( priority == ((Vdp2Regs->SPCTL>>8)&0x07) )
                              alpha = 0xF8-((colorcl<<3)&0xF8);
                              break;
                           case 2:
                              if( priority >= ((Vdp2Regs->SPCTL>>8)&0x07) )
                              alpha = 0xF8-((colorcl<<3)&0xF8);
                              break;
						   case 3:
						   {
							   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((temp + colorOffset) << Vdp2Internal.ColorMode) & 0xFFF);
							   if (checkcol & 0x8000){
								   alpha = 0xF8 - ((colorcl << 3) & 0xF8);
							   }
						   }
                              break;
                           }
                        }
                        alpha |= priority;
                        if( MSB ) *texture->textdata++ = (alpha<<24);
                        else *texture->textdata++ = Vdp2ColorRamGetColor(temp+colorOffset, alpha);

                     }
                  }else{
                     *texture->textdata++ = 0x0;
                  }
               }

               j += 1;

               if( ednmode && endcnt >= 2 )
               {
                  *texture->textdata++ = 0x00;
               }else if (((dot & 0xF) == 0) && !SPD)
               {
                  *texture->textdata++ = 0x00;
               }else if (((dot&0x0F) == 0x0F) && !END )
               {
                  *texture->textdata++ = 0x0;
                  endcnt++;
               }else{

                  temp = T1ReadWord(Vdp1Ram, ((dot & 0xF) * 2 + colorLut) & 0x7FFFF);

                  if (temp & 0x8000)
                  {
                     if( MSB ) *texture->textdata++ = (alpha<<24);
                     else *texture->textdata++ = SAT2YAB1(alpha, temp);
                  }else if( temp != 0x0000)
                  {

                     Vdp1ProcessSpritePixel(Vdp2Regs->SPCTL & 0xF, &temp, &shadow, &priority, &colorcl);
                     if( shadow != 0 )
                     {
						 u32 talpha = (u8)0xF8 - (u8)0x80;
						 talpha |= priority;
						 *texture->textdata++ = (talpha << 24);
                     }else{
#ifdef WORDS_BIGENDIAN
                        priority = ((u8 *)&Vdp2Regs->PRISA)[priority^1]&0x7;
                        colorcl =  ((u8 *)&Vdp2Regs->CCRSA)[colorcl^1]&0x1F;
#else
                        priority = ((u8 *)&Vdp2Regs->PRISA)[priority]&0x7;
                        colorcl =  ((u8 *)&Vdp2Regs->CCRSA)[colorcl]&0x1F;
#endif
                        alpha = 0xF8;
                        if( ((Vdp2Regs->CCCTL >> 6) & 0x01) == 0x01  )
                        {
							switch (SPCCCS)
                           {
                           case 0:
                              if( priority <= ((Vdp2Regs->SPCTL>>8)&0x07) )
                              alpha = 0xF8-((colorcl<<3)&0xF8);
                              break;
                           case 1:
                              if( priority == ((Vdp2Regs->SPCTL>>8)&0x07) )
                              alpha = 0xF8-((colorcl<<3)&0xF8);
                              break;
                           case 2:
                              if( priority >= ((Vdp2Regs->SPCTL>>8)&0x07) )
                              alpha = 0xF8-((colorcl<<3)&0xF8);
                              break;
						   case 3:
						   {
							   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((temp + colorOffset) << Vdp2Internal.ColorMode) & 0xFFF);
							   if (checkcol & 0x8000){
								   alpha = 0xF8 - ((colorcl << 3) & 0xF8);
							   }
						   }
                              break;
                           }
                        }
                        alpha |= priority;
                        if( MSB ) *texture->textdata++ = (alpha<<24);
                        else *texture->textdata++ = Vdp2ColorRamGetColor(temp+colorOffset, alpha);
                     }
                  }else
                     *texture->textdata++ = 0x0;
               }

               j += 1;

               charAddr += 1;
            }
            texture->textdata += texture->w;
         }
         break;
      }
      case 2:
      {
         // 8 bpp(64 color) Bank mode
        u32 colorBank = cmd->CMDCOLR & 0xFFC0;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;

         u16 i, j;

         for(i = 0;i < sprite->h;i++)
         {
            for(j = 0;j < sprite->w;j++)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF) & 0x3F;
               charAddr++;

               if ((dot == 0) && !SPD) *texture->textdata++ = 0x00;
			   else if (dot == 0x0000){ *texture->textdata++ = 0x00; }
               else if( (dot == 0x3F) && !END ) *texture->textdata++ = 0x00;
               else if( MSB ) *texture->textdata++ = (alpha<<24);
			   else if ((dot | colorBank) == nromal_shadow){
				   u32 talpha = (u8)0xF8 - (u8)0x80;
				   talpha |= priority;
				   *texture->textdata++ = (talpha << 24);
			   }
			   else{
				   const int colorindex = (dot | colorBank) + colorOffset;
				   if (SPCCCS == 0x03){
					   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
					   if (checkcol & 0x8000){
						   u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
						   talpha |= priority;
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, talpha);
					   }
					   else{
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
					   }
				   }
				   else{
					   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
				   }
			   }
            }
            texture->textdata += texture->w;
         }
         break;
      }
      case 3:
      {
         // 8 bpp(128 color) Bank mode
        u32 colorBank = cmd->CMDCOLR & 0xFF80;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
         u16 i, j;

         for(i = 0;i < sprite->h;i++)
         {
            for(j = 0;j < sprite->w;j++)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF) &0x7F;
               charAddr++;

               if ((dot == 0) && !SPD) *texture->textdata++ = 0x00;
			   else if (dot == 0x0000){ *texture->textdata++ = 0x00; }
               else if( (dot == 0x7F) && !END ) *texture->textdata++ = 0x00;
               else if( MSB ) *texture->textdata++ = (alpha<<24);
			   else if ((dot | colorBank) == nromal_shadow){
				   u32 talpha = (u8)0xF8 - (u8)0x80;
				   talpha |= priority;
				   *texture->textdata++ = (talpha << 24);
			   }else{
				   const int colorindex = (dot | colorBank) + colorOffset;
				   if (SPCCCS == 0x03){
					   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
					   if (checkcol & 0x8000){
						   u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
						   talpha |= priority;
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, talpha);
					   }
					   else{
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
					   }
				   }
				   else{
					   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
				   }
			   }

            }
            texture->textdata += texture->w;
         }
         break;
      }
      case 4:
      {
         // 8 bpp(256 color) Bank mode
        u32 colorBank = cmd->CMDCOLR & 0xFF00;
         u32 colorOffset = (Vdp2Regs->CRAOFB & 0x70) << 4;
         u16 i, j;

         for(i = 0;i < sprite->h;i++)
         {
            for(j = 0;j < sprite->w;j++)
            {
               dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);
               charAddr++;

               if ((dot == 0) && !SPD) *texture->textdata++ = 0x00;
			   else if (dot == 0x0000){ *texture->textdata++ = 0x00; }
               else if( (dot == 0xFF) && !END ) *texture->textdata++ = 0x0;
               else if( MSB ) *texture->textdata++ = (alpha<<24);
			   else if ((dot | colorBank) == nromal_shadow){
				   u32 talpha = (u8)0xF8 - (u8)0x80;
				   talpha |= priority;
				   *texture->textdata++ = (talpha << 24);
			   }
			   else{
				   const int colorindex = (dot | colorBank) + colorOffset;
				   if (SPCCCS == 0x03){
					   u16 checkcol = T2ReadWord(Vdp2ColorRam, ((colorindex) << Vdp2Internal.ColorMode) & 0xFFF);
					   if (checkcol & 0x8000){
						   u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
						   talpha |= priority;
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, talpha);
					   }
					   else{
						   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
					   }
				   }
				   else{
					   *texture->textdata++ = Vdp2ColorRamGetColor(colorindex, alpha);
				   }
			   }
            }
            texture->textdata += texture->w;
         }
         break;
      }
      case 5:
      {
         // 16 bpp Bank mode
         u16 i, j;
         for(i = 0;i < sprite->h;i++)
         {
            for(j = 0;j < sprite->w;j++)
            {
               dot = T1ReadWord(Vdp1Ram, charAddr & 0x7FFFF);
               charAddr += 2;

               //if (!(dot & 0x8000) && (Vdp2Regs->SPCTL & 0x20)) printf("mixed mode\n");
               if (!(dot & 0x8000) && !SPD) *texture->textdata++ = 0x00;
			   else if (dot == 0x0000){ *texture->textdata++ = 0x00; }
               else if( (dot == 0x7FFF) && !END ) *texture->textdata++ = 0x0;
               else if( MSB ) *texture->textdata++ = (alpha<<24);
			   else if (dot == nromal_shadow){
				   u32 talpha = (u8)0xF8 - (u8)0x80;
				   talpha |= priority;
				   *texture->textdata++ = (talpha << 24);
			   }
			   else if (SPCCCS == 0x03 && (dot&0x8000) ){
				   u32 talpha = 0xF8 - ((colorcl << 3) & 0xF8);
				   talpha |= priority;
				   *texture->textdata++ = SAT2YAB1(talpha, dot);
			   }
			   else *texture->textdata++ = SAT2YAB1(alpha, dot);
            }
            texture->textdata += texture->w;
         }
         break;
      }
      default:
         VDP1LOG("Unimplemented sprite color mode: %X\n", (cmd->CMDPMOD >> 3) & 0x7);
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL Vdp1ReadPriority(vdp1cmd_struct *cmd, int * priority, int * colorcl, int * normal_shadow )
{
   u8 SPCLMD = Vdp2Regs->SPCTL;
   u8 sprite_register;
   u8 *sprprilist = (u8 *)&Vdp2Regs->PRISA;
   u8 *cclist = (u8 *)&Vdp2Regs->CCRSA;
   u16 lutPri;
   u16 *reg_src = &cmd->CMDCOLR;
   int not_lut = 1;

   // is the sprite is RGB or LUT (in fact, LUT can use bank color, we just hope it won't...)
   if ((SPCLMD & 0x20) && (cmd->CMDCOLR & 0x8000))
   {
      // RGB data, use register 0
      *priority = Vdp2Regs->PRISA & 0x7;
      return;
   }

   if (((cmd->CMDPMOD >> 3) & 0x7) == 1) {
      u32 charAddr, dot, colorLut;

      *priority = Vdp2Regs->PRISA & 0x7;

      charAddr = cmd->CMDSRCA * 8;
      dot = T1ReadByte(Vdp1Ram, charAddr & 0x7FFFF);
      colorLut = cmd->CMDCOLR * 8;
      lutPri = T1ReadWord(Vdp1Ram, (dot >> 4) * 2 + colorLut);
      if (!(lutPri & 0x8000)) {
         not_lut = 0;
         reg_src = &lutPri;
      } else
         return;
   }

   {
      u8 sprite_type = SPCLMD & 0xF;
      switch(sprite_type)
      {
         case 0:
            sprite_register = (*reg_src & 0xC000) >> 14;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x07)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[(cmd->CMDCOLR>>11)&0x07]&0x1F;
#endif
			*normal_shadow = 0x7FE;
            if (not_lut) cmd->CMDCOLR &= 0x7FF;
            break;
         case 1:
            sprite_register = (*reg_src & 0xE000) >> 13;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x03)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[(cmd->CMDCOLR>>11)&0x03]&0x1F;
#endif
			*normal_shadow = 0x7FE;
            if (not_lut) cmd->CMDCOLR &= 0x7FF;
            break;
         case 2:
            sprite_register = (*reg_src >> 14) & 0x1;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x07)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[(cmd->CMDCOLR>>11)&0x07]&0x1F;
#endif
			*normal_shadow = 0x7FE;
            if (not_lut) cmd->CMDCOLR &= 0x7FF;
            break;
         case 3:
            sprite_register = (*reg_src & 0x6000) >> 13;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x03)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x03)]&0x1F;
#endif
			*normal_shadow = 0x7FE;
            if (not_lut) cmd->CMDCOLR &= 0x7FF;
            break;
         case 4:
            sprite_register = (*reg_src & 0x6000) >> 13;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>10)&0x07)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>10)&0x07)]&0x1F;
#endif
			*normal_shadow = 0x3FE;
            if (not_lut) cmd->CMDCOLR &= 0x3FF;
            break;
         case 5:
            sprite_register = (*reg_src & 0x7000) >> 12;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x01)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>11)&0x01)]&0x1F;
#endif
			*normal_shadow = 0x7FE;
            if (not_lut) cmd->CMDCOLR &= 0x7FF;
            break;
         case 6:
            sprite_register = (*reg_src & 0x7000) >> 12;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>10)&0x03)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>10)&0x03)]&0x1F;
#endif
			*normal_shadow = 0x3FE;
            if (not_lut) cmd->CMDCOLR &= 0x3FF;
            break;
         case 7:
            sprite_register = (*reg_src & 0x7000) >> 12;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>9)&0x07)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>9)&0x07)]&0x1F;
#endif
			*normal_shadow = 0x1FE;
            if (not_lut) cmd->CMDCOLR &= 0x1FF;
            break;
         case 8:
            sprite_register = (*reg_src & 0x80) >> 7;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
#else
            *priority = sprprilist[sprite_register] & 0x7;
#endif
			*normal_shadow = 0x7E;
            *colorcl =  cclist[0]&0x1F;
            if (not_lut) cmd->CMDCOLR &= 0x7F;
            break;
         case 9:
            sprite_register = (*reg_src & 0x80) >> 7;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x01)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x01)]&0x1F;
#endif
			*normal_shadow = 0x3E;
            if (not_lut) cmd->CMDCOLR &= 0x3F;
            break;
         case 10:
            sprite_register = (*reg_src & 0xC0) >> 6;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
#else
            *priority = sprprilist[sprite_register] & 0x7;
#endif
            *colorcl =  cclist[0]&0x1F;
            if (not_lut) cmd->CMDCOLR &= 0x3F;
            break;
         case 11:
            sprite_register = 0;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x03)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x03)]&0x1F;
#endif
			*normal_shadow = 0x3E;
            if (not_lut) cmd->CMDCOLR &= 0x3F;
            break;
         case 12:
            sprite_register = (*reg_src & 0x80) >> 7;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
#else
            *priority = sprprilist[sprite_register] & 0x7;
#endif
            *colorcl =  cclist[0]&0x1F;
			*normal_shadow = 0x3E;
            if (not_lut) cmd->CMDCOLR &= 0xFF;
            break;
         case 13:
            sprite_register = (*reg_src & 0x80) >> 7;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x01)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x01)]&0x1F;
#endif
			*normal_shadow = 0xFE;
            if (not_lut) cmd->CMDCOLR &= 0xFF;
            break;
         case 14:
            sprite_register = (*reg_src & 0xC0) >> 6;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[0]&0x1F;
#endif
			*normal_shadow = 0xFE;
            if (not_lut) cmd->CMDCOLR &= 0xFF;
            break;
         case 15:
            sprite_register = 0;
#ifdef WORDS_BIGENDIAN
            *priority = sprprilist[sprite_register^1] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x03)^1]&0x1F;
#else
            *priority = sprprilist[sprite_register] & 0x7;
            *colorcl =  cclist[((cmd->CMDCOLR>>6)&0x03)]&0x1F;
#endif
			*normal_shadow = 0xFE;
            if (not_lut) cmd->CMDCOLR &= 0xFF;
            break;
         default:
            VDP1LOG("sprite type %d not implemented\n", sprite_type);

            // if we don't know what to do with a sprite, we put it on top
            *priority = 7;
            break;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp1SetTextureRatio(int vdp2widthratio, int vdp2heightratio)
{
   float vdp1w=1;
   float vdp1h=1;

   // may need some tweaking

   // Figure out which vdp1 screen mode to use
   switch (Vdp1Regs->TVMR & 7)
   {
      case 0:
      case 2:
      case 3:
          vdp1w=1;
          break;
      case 1:
          vdp1w=2;
          break;
      default:
          vdp1w=1;
          vdp1h=1;
          break;
   }

   // Is double-interlace enabled?
   if (Vdp1Regs->FBCR & 0x8)
      vdp1h=2;

   vdp1wratio = (float)vdp2widthratio / vdp1w;
   vdp1hratio = (float)vdp2heightratio / vdp1h;
}

//////////////////////////////////////////////////////////////////////////////

static u32 Vdp2ColorRamGetColor(u32 colorindex, int alpha)
{
   switch(Vdp2Internal.ColorMode)
   {
      case 0:
      case 1:
      {
         u32 tmp;
         colorindex <<= 1;
         tmp = T2ReadWord(Vdp2ColorRam, colorindex & 0xFFF);
         return SAT2YAB1(alpha, tmp);
      }
      case 2:
      {
         u32 tmp1, tmp2;
         colorindex <<= 2;
         colorindex &= 0xFFF;
         tmp1 = T2ReadWord(Vdp2ColorRam, colorindex);
         tmp2 = T2ReadWord(Vdp2ColorRam, colorindex+2);
         return SAT2YAB2(alpha, tmp1, tmp2);
      }
      default: break;
   }
   return 0;
}

u32 FASTCALL Vdp2ColorRamGetColorCM01SC0(vdp2draw_struct * info, u32 colorindex, int alpha )
{
   u32 tmp;
   tmp = T2ReadWord(Vdp2ColorRam, (colorindex<<1) & 0xFFF);
   return SAT2YAB1(alpha,tmp);
}

u32 FASTCALL Vdp2ColorRamGetColorCM01SC1(vdp2draw_struct * info, u32 colorindex, int alpha )
{
   u32 tmp;
   tmp = T2ReadWord(Vdp2ColorRam, (colorindex<<1) & 0xFFF);
   if( (info->specialcolorfunction & 1) == 0 )
   {
      return SAT2YAB1(0xFF,tmp);
   }
   return SAT2YAB1(alpha,tmp);
}

u32 FASTCALL Vdp2ColorRamGetColorCM01SC3(vdp2draw_struct * info, u32 colorindex, int alpha )
{
   u32 tmp;
   colorindex <<= 1;
   tmp = T2ReadWord(Vdp2ColorRam, colorindex & 0xFFF);
   if( ((tmp & 0x8000) == 0) )
   {
      return SAT2YAB1(0xFF,tmp);
   }
   return SAT2YAB1(alpha,tmp);
}

u32 FASTCALL Vdp2ColorRamGetColorCM2(vdp2draw_struct * info, u32 colorindex, int alpha )
{
   u32 tmp1, tmp2;
   colorindex <<= 2;
   colorindex &= 0xFFF;
   tmp1 = T2ReadWord(Vdp2ColorRam, colorindex);
   tmp2 = T2ReadWord(Vdp2ColorRam, colorindex+2);
   return SAT2YAB2(alpha, tmp1, tmp2);
}

static int Vdp2SetGetColor( vdp2draw_struct * info )
{
   switch(Vdp2Internal.ColorMode)
   {
      case 0:
      case 1:
         switch( info->specialcolormode )
         {
         case 0:
            info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM01SC0;
            break;
         case 1:
            info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM01SC1;
            break;
         case 2:
            info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM01SC0; // Not Supported Yet!
            break;
         case 3:
            info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM01SC3;
            break;
         default:
            info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM01SC0;
            break;
         }
         break;
      case 2:
         info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM2;
         break;
      default:
         info->Vdp2ColorRamGetColor = (Vdp2ColorRamGetColor_func) Vdp2ColorRamGetColorCM01SC0;
         break;
   }
   return 0;
}

//////////////////////////////////////////////////////////////////////////////
// Window

static void Vdp2GenerateWindowInfo(void)
{
    int i;
    int HShift;
    int v = 0;
    u32 LineWinAddr;

    // Is there BG uses Window0?
    if( (Vdp2Regs->WCTLA & 0X2) || (Vdp2Regs->WCTLA & 0X200) || (Vdp2Regs->WCTLB & 0X2) || (Vdp2Regs->WCTLB & 0X200) ||
        (Vdp2Regs->WCTLC & 0X2) || (Vdp2Regs->WCTLC & 0X200) || (Vdp2Regs->WCTLD & 0X2) || (Vdp2Regs->WCTLD & 0X200) || (Vdp2Regs->RPMD == 0X03) )
    {

        // resize to fit resolusion
        if( m_vWindinfo0_size != vdp2height )
        {
            if(m_vWindinfo0 != NULL) free(m_vWindinfo0);
            m_vWindinfo0 = (vdp2WindowInfo*)malloc(sizeof(vdp2WindowInfo)*(vdp2height+8));

            for( i=0; i<vdp2height; i++ )
            {
               m_vWindinfo0[i].WinShowLine = 1;
               m_vWindinfo0[i].WinHStart   = 0;
               m_vWindinfo0[i].WinHEnd     = 1024;
            }

            m_vWindinfo0_size = vdp2height;
            m_b0WindowChg = 1;
        }

        HShift = 0;
        if( vdp2width>=640 ) HShift = 0; else HShift = 1;


        // Line Table mode
        if( (Vdp2Regs->LWTA0.part.U & 0x8000) )
        {
            int preHStart = -1;
            int preHEnd = -1;

            // start address
            LineWinAddr = (u32)((( (Vdp2Regs->LWTA0.part.U & 0x07) << 15) | (Vdp2Regs->LWTA0.part.L >> 1) ) << 2);
            _Ygl->win0_vertexcnt = 0;

            for( v = 0; v < vdp2height; v++ )
            {
                if( v < Vdp2Regs->WPSY0 || v > Vdp2Regs->WPEY0 )
                {
                    if( m_vWindinfo0[v].WinShowLine ) m_b0WindowChg = 1;
                    m_vWindinfo0[v].WinShowLine = 0;

                }else{
                    short HStart = Vdp2RamReadWord(LineWinAddr + (v << 2) );
                    short HEnd   = Vdp2RamReadWord(LineWinAddr + (v << 2) + 2);

                    if( HStart < HEnd )
                    {
                        HStart >>= HShift;
                        HEnd   >>= HShift;

                        if( !( m_vWindinfo0[v].WinHStart == HStart && m_vWindinfo0[v].WinHEnd == HEnd ) )
                        {
                            m_b0WindowChg = 1;
                        }

                        m_vWindinfo0[v].WinHStart = HStart;
                        m_vWindinfo0[v].WinHEnd   = HEnd;
                        m_vWindinfo0[v].WinShowLine = 1;

                    }else{
                        if( m_vWindinfo0[v].WinShowLine ) m_b0WindowChg = 1;
                        m_vWindinfo0[v].WinHStart = 0;
                        m_vWindinfo0[v].WinHEnd   = 0;
                        m_vWindinfo0[v].WinShowLine = 0;

                    }

					if (v == Vdp2Regs->WPSY0)
					{
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 0] = HStart;
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 1] = v;
						_Ygl->win0_vertexcnt++;
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 0] = HEnd;
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 1] = v;
						_Ygl->win0_vertexcnt++;

					}
					else if ((HStart != preHStart || HEnd != preHEnd) || v == (Vdp2Regs->WPEY0 - 1))
					{
						if ((v - 1) != _Ygl->win0v[(_Ygl->win0_vertexcnt - 1) * 2 + 1])
						{
							_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 0] = preHStart;
							_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 1] = v - 1;
							_Ygl->win0_vertexcnt++;
							_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 0] = preHEnd;
							_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 1] = v - 1;
							_Ygl->win0_vertexcnt++;
						}

						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 0] = HStart;
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 1] = v;
						_Ygl->win0_vertexcnt++;
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 0] = HEnd;
						_Ygl->win0v[_Ygl->win0_vertexcnt * 2 + 1] = v;
						_Ygl->win0_vertexcnt++;
					}

					preHStart = HStart;
					preHEnd = HEnd;


                }
            }

        // Parameter Mode
        }else{

            // Check Update
            if( !( m_vWindinfo0[0].WinHStart == (Vdp2Regs->WPSX0>>HShift) && m_vWindinfo0[0].WinHEnd == (Vdp2Regs->WPEX0>>HShift) ) )
            {
                m_b0WindowChg = 1;
            }

            for( v = 0; v < vdp2height; v++ )
            {

                m_vWindinfo0[v].WinHStart = Vdp2Regs->WPSX0 >> HShift;
                m_vWindinfo0[v].WinHEnd   = Vdp2Regs->WPEX0 >> HShift;
                if( v < Vdp2Regs->WPSY0 || v >= Vdp2Regs->WPEY0 )
                {
                    if( m_vWindinfo0[v].WinShowLine ) m_b0WindowChg = 1;
                    m_vWindinfo0[v].WinShowLine = 0;
                }else{
                   if( m_vWindinfo0[v].WinShowLine == 0) m_b0WindowChg = 1;
                    m_vWindinfo0[v].WinShowLine = 1;
                }
            }

            _Ygl->win0v[0]= Vdp2Regs->WPSX0 >> HShift;
            _Ygl->win0v[1]= Vdp2Regs->WPSY0;
            _Ygl->win0v[2]= Vdp2Regs->WPEX0 >> HShift;
            _Ygl->win0v[3]= Vdp2Regs->WPSY0;
            _Ygl->win0v[4]= Vdp2Regs->WPSX0 >> HShift;
            _Ygl->win0v[5]= Vdp2Regs->WPEY0;
            _Ygl->win0v[6]= Vdp2Regs->WPEX0 >> HShift;
            _Ygl->win0v[7]= Vdp2Regs->WPEY0;
            _Ygl->win0_vertexcnt = 4;

        }

    // there is no Window BG
    }else{
       if( m_vWindinfo0_size != 0 )
       {
          m_b0WindowChg = 1;
       }


        if( m_vWindinfo0 != NULL )
        {
            free(m_vWindinfo0);
            m_vWindinfo0 = NULL;
        }
        m_vWindinfo0_size = 0;
        _Ygl->win0_vertexcnt = 0;

    }


    // Is there BG uses Window1?
    if( (Vdp2Regs->WCTLA & 0x8) || (Vdp2Regs->WCTLA & 0x800) || (Vdp2Regs->WCTLB & 0x8) || (Vdp2Regs->WCTLB & 0x800) ||
        (Vdp2Regs->WCTLC & 0x8) || (Vdp2Regs->WCTLC & 0x800) || (Vdp2Regs->WCTLD & 0x8) || (Vdp2Regs->WCTLD & 0x800)  )
    {

        // resize to fit resolution
        if( m_vWindinfo1_size != vdp2height )
        {
            if(m_vWindinfo1 != NULL) free(m_vWindinfo1);
            m_vWindinfo1 = (vdp2WindowInfo*)malloc(sizeof(vdp2WindowInfo)*vdp2height);

            for( i=0; i<vdp2height; i++ )
            {
               m_vWindinfo1[i].WinShowLine = 1;
               m_vWindinfo1[i].WinHStart   = 0;
               m_vWindinfo1[i].WinHEnd     = 1024;
            }

            m_vWindinfo1_size = vdp2height;
            m_b1WindowChg = 1;
        }

        if( vdp2width>=640 ) HShift = 0; else HShift = 1;


        // LineTable mode
        if( (Vdp2Regs->LWTA1.part.U & 0x8000) )
        {
            int preHStart = -1;
            int preHEnd = -1;

            _Ygl->win1_vertexcnt = 0;
            // start address for Window table
            LineWinAddr = (u32)((( (Vdp2Regs->LWTA1.part.U & 0x07) << 15) | (Vdp2Regs->LWTA1.part.L >> 1) ) << 2);

            for( v = 0; v < vdp2height; v++ )
            {
                if( v < Vdp2Regs->WPSY1 || v > Vdp2Regs->WPEY1 )
                {
                    if( m_vWindinfo1[v].WinShowLine ) m_b1WindowChg = 1;
                    m_vWindinfo1[v].WinShowLine = 0;
                }else{
                    short HStart = Vdp2RamReadWord(LineWinAddr + (v << 2) );
                    short HEnd   = Vdp2RamReadWord(LineWinAddr + (v << 2) + 2);
                    if( HStart < HEnd )
                    {
                        HStart >>= HShift;
                        HEnd   >>= HShift;

                        if( !( m_vWindinfo1[v].WinHStart == HStart && m_vWindinfo1[v].WinHEnd == HEnd ) )
                        {
                            m_b1WindowChg = 1;
                        }

                        m_vWindinfo1[v].WinHStart = HStart;
                        m_vWindinfo1[v].WinHEnd   = HEnd;
                        m_vWindinfo1[v].WinShowLine = 1;

                    }else{
                        if( m_vWindinfo1[v].WinShowLine ) m_b1WindowChg = 1;
                        m_vWindinfo1[v].WinShowLine = 0;
                    }

                        if( v == Vdp2Regs->WPSY1  )
                        {
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+0]= HStart;
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+1]= v;
                           _Ygl->win1_vertexcnt++;
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+0]= HEnd;
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+1]= v;
                           _Ygl->win1_vertexcnt++;

                        }else if( ( HStart != preHStart || HEnd != preHEnd) || v == (Vdp2Regs->WPEY1-1) )
                        {
                           if( (v-1) != _Ygl->win1v[(_Ygl->win1_vertexcnt-1)*2+1] )
                           {
                              _Ygl->win1v[_Ygl->win1_vertexcnt*2+0]= preHStart;
                              _Ygl->win1v[_Ygl->win1_vertexcnt*2+1]= v-1;
                              _Ygl->win1_vertexcnt++;
                              _Ygl->win1v[_Ygl->win1_vertexcnt*2+0]= preHEnd;
                              _Ygl->win1v[_Ygl->win1_vertexcnt*2+1]= v-1;
                              _Ygl->win1_vertexcnt++;
                           }

                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+0]= HStart;
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+1]= v;
                           _Ygl->win1_vertexcnt++;
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+0]= HEnd;
                           _Ygl->win1v[_Ygl->win1_vertexcnt*2+1]= v;
                           _Ygl->win1_vertexcnt++;
                        }

                        preHStart = HStart;
                        preHEnd = HEnd;

                }
            }

        // parameter mode
        }else{

            // check update
            if( !( m_vWindinfo1[0].WinHStart == (Vdp2Regs->WPSX1>>HShift) && m_vWindinfo1[0].WinHEnd == (Vdp2Regs->WPEX1>>HShift) ) )
            {
                m_b1WindowChg = 1;
            }

            for( v = 0; v < vdp2height; v++ )
            {
                m_vWindinfo1[v].WinHStart = Vdp2Regs->WPSX1 >> HShift;
                m_vWindinfo1[v].WinHEnd   = Vdp2Regs->WPEX1 >> HShift;
                if( v < Vdp2Regs->WPSY1 || v > Vdp2Regs->WPEY1 )
                {
                    if( m_vWindinfo1[v].WinShowLine ) m_b1WindowChg = 1;
                    m_vWindinfo1[v].WinShowLine = 0;
                }else{
                   if( m_vWindinfo1[v].WinShowLine == 0) m_b1WindowChg = 1;
                    m_vWindinfo1[v].WinShowLine = 1;
                }
            }

            _Ygl->win1v[0]= Vdp2Regs->WPSX1 >> HShift;
            _Ygl->win1v[1]= Vdp2Regs->WPSY1;
            _Ygl->win1v[2]= Vdp2Regs->WPEX1 >> HShift;
            _Ygl->win1v[3]= Vdp2Regs->WPSY1;
            _Ygl->win1v[4]= Vdp2Regs->WPSX1 >> HShift;
            _Ygl->win1v[5]= Vdp2Regs->WPEY1;
            _Ygl->win1v[6]= Vdp2Regs->WPEX1 >> HShift;
            _Ygl->win1v[7]= Vdp2Regs->WPEY1;
            _Ygl->win1_vertexcnt = 4;

        }

    // no BG uses Window1
    }else{

       if( m_vWindinfo1_size != 0 )
       {
          m_b1WindowChg = 1;
       }

        if( m_vWindinfo1 != NULL )
        {
             free(m_vWindinfo1);
            m_vWindinfo1 = NULL;
        }
        m_vWindinfo1_size = 0;
        _Ygl->win1_vertexcnt = 0;
    }

   if( m_b1WindowChg || m_b0WindowChg )
   {
       YglNeedToUpdateWindow();
       m_b0WindowChg = 0;
       m_b1WindowChg = 0;
   }

}

// 0 .. outside,1 .. inside
static INLINE int Vdp2CheckWindow(vdp2draw_struct *info, int x, int y, int area, vdp2WindowInfo * vWindinfo )
{
   // inside
    if( area == 1 )
    {
        if( vWindinfo[y].WinShowLine == 0  ) return 0;
        if( x > vWindinfo[y].WinHStart && x < vWindinfo[y].WinHEnd )
        {
            return 1;
        }else{
            return 0;
        }
    // outside
    }else{
        if( vWindinfo[y].WinShowLine == 0  ) return 1;
        if( x < vWindinfo[y].WinHStart ) return 1;
        if( x > vWindinfo[y].WinHEnd ) return 1;
        return 0;
    }
    return 0;
}

// 0 .. outside,1 .. inside
static int FASTCALL Vdp2CheckWindowDot(vdp2draw_struct *info, int x, int y )
{
    if( info->bEnWin0 != 0 &&  info->bEnWin1 == 0 )
    {
		if (m_vWindinfo0==NULL) Vdp2GenerateWindowInfo();
        return Vdp2CheckWindow(info, x, y, info->WindowArea0, m_vWindinfo0 );
    }else if( info->bEnWin0 == 0 &&  info->bEnWin1 != 0 )
    {
		if (m_vWindinfo1 == NULL) Vdp2GenerateWindowInfo();
        return Vdp2CheckWindow(info, x, y, info->WindowArea1, m_vWindinfo1 );
    }else if( info->bEnWin0 != 0 &&  info->bEnWin1 != 0 )
    {
		if (m_vWindinfo0 == NULL || m_vWindinfo1 == NULL) Vdp2GenerateWindowInfo();
        if( info->LogicWin == 0 )
        {
            return (Vdp2CheckWindow(info, x, y, info->WindowArea0, m_vWindinfo0 )&
                    Vdp2CheckWindow(info, x, y, info->WindowArea1, m_vWindinfo1 ));
        }else{
            return (Vdp2CheckWindow(info, x, y, info->WindowArea0, m_vWindinfo0 )|
                    Vdp2CheckWindow(info, x, y, info->WindowArea1, m_vWindinfo1 ));
        }
    }
    return 0;
}

// 0 .. all outsize, 1~3 .. partly inside, 4.. all inside
static int FASTCALL Vdp2CheckWindowRange(vdp2draw_struct *info, int x, int y, int w, int h )
{
    int rtn=0;

    if( info->bEnWin0 != 0 &&  info->bEnWin1 == 0 )
    {
        rtn += Vdp2CheckWindow(info, x, y, info->WindowArea0, m_vWindinfo0 );
        rtn += Vdp2CheckWindow(info, x+w, y, info->WindowArea0, m_vWindinfo0 );
        rtn += Vdp2CheckWindow(info, x+w, y+h, info->WindowArea0, m_vWindinfo0 );
        rtn += Vdp2CheckWindow(info, x, y+h, info->WindowArea0, m_vWindinfo0 );
        return rtn;
    }else if( info->bEnWin0 == 0 &&  info->bEnWin1 != 0 )
    {
        rtn += Vdp2CheckWindow(info, x, y, info->WindowArea1, m_vWindinfo1 );
        rtn += Vdp2CheckWindow(info, x+w, y, info->WindowArea1, m_vWindinfo1 );
        rtn += Vdp2CheckWindow(info, x+w, y+h, info->WindowArea1, m_vWindinfo1 );
        rtn += Vdp2CheckWindow(info, x, y+h, info->WindowArea1, m_vWindinfo1 );
        return rtn;
    }else if( info->bEnWin0 != 0 &&  info->bEnWin1 != 0 )
    {
        if( info->LogicWin == 0 )
        {
            rtn += (Vdp2CheckWindow(info, x, y, info->WindowArea0, m_vWindinfo0 ) &
                    Vdp2CheckWindow(info, x, y, info->WindowArea1, m_vWindinfo1 ) );
            rtn += (Vdp2CheckWindow(info, x+w, y, info->WindowArea0, m_vWindinfo0 )&
                    Vdp2CheckWindow(info, x+w, y, info->WindowArea1, m_vWindinfo1 ) );
            rtn += (Vdp2CheckWindow(info, x+w, y+h, info->WindowArea0, m_vWindinfo0 )&
                    Vdp2CheckWindow(info, x+w, y+h, info->WindowArea1, m_vWindinfo1 ) );
            rtn += (Vdp2CheckWindow(info, x, y+h, info->WindowArea0, m_vWindinfo0 ) &
                    Vdp2CheckWindow(info, x, y+h, info->WindowArea1, m_vWindinfo1 ) );
            return rtn;
        }else{
            rtn += (Vdp2CheckWindow(info, x, y, info->WindowArea0, m_vWindinfo0 ) |
                    Vdp2CheckWindow(info, x, y, info->WindowArea1, m_vWindinfo1 ) );
            rtn += (Vdp2CheckWindow(info, x+w, y, info->WindowArea0, m_vWindinfo0 ) |
                    Vdp2CheckWindow(info, x+w, y, info->WindowArea1, m_vWindinfo1 ) );
            rtn += (Vdp2CheckWindow(info, x+w, y+h, info->WindowArea0, m_vWindinfo0 ) |
                    Vdp2CheckWindow(info, x+w, y+h, info->WindowArea1, m_vWindinfo1 ) );
            rtn += (Vdp2CheckWindow(info, x, y+h, info->WindowArea0, m_vWindinfo0 ) |
                    Vdp2CheckWindow(info, x, y+h, info->WindowArea1, m_vWindinfo1 ) );
            return rtn;
        }
    }
    return 0;
}

void Vdp2GenLineinfo( vdp2draw_struct *info )
{
   int bound = 0;
   int i;
   u16 val1,val2;
   int index = 0;
   int lineindex = 0;
   if( info->lineinc == 0 || info->islinescroll == 0 ) return;

   if( VDPLINE_SY(info->islinescroll)) bound += 0x04;
   if( VDPLINE_SX(info->islinescroll)) bound += 0x04;
   if( VDPLINE_SZ(info->islinescroll)) bound += 0x04;

   for( i = 0; i < vdp2height; i += info->lineinc )
   {
      index = 0;
      if( VDPLINE_SX(info->islinescroll))
      {
		  info->lineinfo[lineindex].LineScrollValH = T1ReadWord(Vdp2Ram, info->linescrolltbl + (i / info->lineinc)*bound);
		  if ((info->lineinfo[lineindex].LineScrollValH & 0x400)) info->lineinfo[lineindex].LineScrollValH |= 0xF800; else info->lineinfo[lineindex].LineScrollValH &= 0x07FF;
         index += 4;
      }else{
		  info->lineinfo[lineindex].LineScrollValH = 0;
      }

      if( VDPLINE_SY(info->islinescroll))
      {
		  info->lineinfo[lineindex].LineScrollValV = T1ReadWord(Vdp2Ram, info->linescrolltbl + (i / info->lineinc)*bound + index);
		  if ((info->lineinfo[lineindex].LineScrollValV & 0x400)) info->lineinfo[lineindex].LineScrollValV |= 0xF800; else info->lineinfo[lineindex].LineScrollValV &= 0x07FF;
         index += 4;
      }else{
		  info->lineinfo[lineindex].LineScrollValV = 0;
      }

      if( VDPLINE_SZ(info->islinescroll))
      {
         val1=T1ReadWord(Vdp2Ram, info->linescrolltbl+(i/info->lineinc)*bound+index);
         val2=T1ReadWord(Vdp2Ram, info->linescrolltbl+(i/info->lineinc)*bound+index+2);
         //info->lineinfo[i].CoordinateIncH = (float)( (int)((val1) & 0x07) + (float)( (val2) >> 8) / 255.0f );
		 info->lineinfo[lineindex].CoordinateIncH = (((int)((val1)& 0x07) << 8) | (int)((val2) >> 8));
		 if (info->lineinfo[lineindex].CoordinateIncH == 0){
			 info->lineinfo[lineindex].CoordinateIncH = 0x0100;
		 }
         index += 4;
      }else{
		  info->lineinfo[lineindex].CoordinateIncH = 0x0100;
      }

	  lineindex++;
   }
}

static void FASTCALL Vdp2DrawCell(vdp2draw_struct *info, YglTexture *texture)
{
   u32 color;
   int i, j;

   switch(info->colornumber)
   {
      case 0: // 4 BPP
         for(i = 0;i < info->cellh;i++)
         {
            for(j = 0;j < info->cellw;j+=4)
            {
               u16 dot = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);

               info->charaddr += 2;
               if (!(dot & 0xF000) && info->transparencyenable) color = 0x00000000;
               else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + ((info->paladdr << 4) | ((dot & 0xF000) >> 12)), info->alpha);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
               if (!(dot & 0xF00) && info->transparencyenable) color = 0x00000000;
               else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + ((info->paladdr << 4) | ((dot & 0xF00) >> 8)), info->alpha);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
               if (!(dot & 0xF0) && info->transparencyenable) color = 0x00000000;
               else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + ((info->paladdr << 4) | ((dot & 0xF0) >> 4)), info->alpha);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
               if (!(dot & 0xF) && info->transparencyenable) color = 0x00000000;
               else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + ((info->paladdr << 4) | (dot & 0xF)), info->alpha);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
            }
            texture->textdata += texture->w;
         }
         break;
      case 1: // 8 BPP
         for(i = 0;i < info->cellh;i++)
         {
            for(j = 0;j < info->cellw;j+=2)
            {
               u16 dot = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);

               info->charaddr += 2;
               if (!(dot & 0xFF00) && info->transparencyenable) color = 0x00000000;
               else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + ((info->paladdr << 4) | ((dot & 0xFF00) >> 8)), info->alpha);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
               if (!(dot & 0xFF) && info->transparencyenable) color = 0x00000000;
               else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + ((info->paladdr << 4) | (dot & 0xFF)), info->alpha);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
            }
            texture->textdata += texture->w;
         }
         break;
    case 2: // 16 BPP(palette)
      for(i = 0;i < info->cellh;i++)
      {
        for(j = 0;j < info->cellw;j++)
        {
          u16 dot = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);
          if ((dot == 0) && info->transparencyenable) color = 0x00000000;
          else color = info->Vdp2ColorRamGetColor(info,info->coloroffset + dot, info->alpha);
          info->charaddr += 2;
          *texture->textdata++ = info->PostPixelFetchCalc(info, color);
    }
        texture->textdata += texture->w;
      }
      break;
    case 3: // 16 BPP(RGB)
	  if (info->isbitmap && info->islinescroll) // Nights Movie
      {
         for(i = 0;i < info->cellh;i++)
         {
            int sh,sv;
            u32 baseaddr;
            vdp2Lineinfo * line;
            baseaddr = (u32)info->charaddr;
            line = &(info->lineinfo[i*info->lineinc]);

            if( VDPLINE_SX(info->islinescroll) )
               sh = line->LineScrollValH+info->sh;
            else
               sh = info->sh;

            if( VDPLINE_SY(info->islinescroll) )
               sv = line->LineScrollValV;
            else
               sv = i+info->sv;

            sh &= (info->cellw-1);
            sv &= (info->cellh-1);
            if( line->LineScrollValH < sh ) sv-=1;

            baseaddr += ((sh+ sv * info->cellw)<<1);

            for(j = 0;j < info->cellw;j++)
            {
               u16 dot;
               u32 addr;
               if( Vdp2CheckWindowDot(info,j,i)==0 ){ *texture->textdata++=0; continue; }
               addr = baseaddr + (j<<1);
               dot = T1ReadWord(Vdp2Ram, addr & 0x7FFFF);
               if (!(dot & 0x8000) && info->transparencyenable) color = 0x00000000;
               else color = SAT2YAB1(0xFF,dot);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
            }
            texture->textdata += texture->w;
         }

      }else{
         for(i = 0;i < info->cellh;i++)
         {
         for(j = 0;j < info->cellw;j++)
         {
            u16 dot = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);
            info->charaddr += 2;
            if (!(dot & 0x8000) && info->transparencyenable) color = 0x00000000;
            else color = SAT2YAB1(0xFF, dot);
            *texture->textdata++ = info->PostPixelFetchCalc(info, color);
         }
         texture->textdata += texture->w;
         }
      }
      break;
    case 4: // 32 BPP
	  if (info->isbitmap && info->islinescroll) // Nights Movie
      {
         for(i = 0;i < info->cellh;i++)
         {
            int sh,sv;
            u32 baseaddr;
            vdp2Lineinfo * line;
         	baseaddr = (u32)info->charaddr;
            line = &(info->lineinfo[i*info->lineinc]);

			   if( VDPLINE_SX(info->islinescroll) )
				   sh = line->LineScrollValH+info->sh;
			   else
				   sh = info->sh;

			   if( VDPLINE_SY(info->islinescroll) )
				   sv = line->LineScrollValV;
			   else
               sv = i+info->sv;

            sh &= (info->cellw-1);
            sv &= (info->cellh-1);
            if( line->LineScrollValH < sh ) sv-=1;

            baseaddr += ((sh+ sv * info->cellw)<<2);

            for(j = 0;j < info->cellw;j++)
            {
               u16 dot1, dot2;
               u32 addr;
   			   if( Vdp2CheckWindowDot(info,j,i)==0 ){ *texture->textdata++=0; continue; }
	   		   addr = baseaddr + (j<<2);
               dot1 = T1ReadWord(Vdp2Ram, addr & 0x7FFFF);
               dot2 = T1ReadWord(Vdp2Ram, (addr+2) & 0x7FFFF);
               if (!(dot1 & 0x8000) && info->transparencyenable) color = 0x00000000;
               else color = SAT2YAB2(info->alpha, dot1, dot2);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
            }
            texture->textdata += texture->w;
         }
      }else{
         for(i = 0;i < info->cellh;i++)
         {
            for(j = 0;j < info->cellw;j++)
            {
               u16 dot1, dot2;
               dot1 = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);
               info->charaddr += 2;
               dot2 = T1ReadWord(Vdp2Ram, info->charaddr & 0x7FFFF);
               info->charaddr += 2;
               if (!(dot1 & 0x8000) && info->transparencyenable) color = 0x00000000;
               else color = SAT2YAB2(info->alpha, dot1, dot2);
               *texture->textdata++ = info->PostPixelFetchCalc(info, color);
            }
            texture->textdata += texture->w;
         }
      }
      break;
  }
}

static void Vdp2DrawPatternPos(vdp2draw_struct *info, YglTexture *texture, int x, int y, int cx, int cy  )
{
	u32 cacheaddr = ((u32)(info->alpha >> 3) << 27) | (info->paladdr << 20) | info->charaddr | info->transparencyenable;
	YglCache c;
	YglSprite tile;
	int winmode = 0;
	tile.dst = 0;
	tile.uclipmode = 0;
	tile.blendmode = info->blendmode;
	tile.linescreen = info->linescreen;

	tile.w = tile.h = info->patternpixelwh;
	tile.flip = info->flipfunction;

	if (info->specialprimode == 1)
		tile.priority = (info->priority & 0xFFFFFFFE) | info->specialfunction;
	else
		tile.priority = info->priority;

	tile.vertices[0] = x;
	tile.vertices[1] = y;
	tile.vertices[2] = (x + tile.w);
	tile.vertices[3] = y;
	tile.vertices[4] = (x + tile.w);
	tile.vertices[5] = (y + (float)info->lineinc);
	tile.vertices[6] = x;
	tile.vertices[7] = (y + (float)info->lineinc);

	// Screen culling
	//if (tile.vertices[0] >= vdp2width || tile.vertices[1] >= vdp2height || tile.vertices[2] < 0 || tile.vertices[5] < 0)
	//{
	//	return;
	//}

	if ((info->bEnWin0 != 0 || info->bEnWin1 != 0) && info->coordincx == 1.0f)
	{                                                 // coordinate inc is not supported yet.
		winmode = Vdp2CheckWindowRange(info, x-cx, y-cy, tile.w, info->lineinc);
		if (winmode == 0) // all outside, no need to draw
		{
			return;
		}
	}

	tile.cor = info->cor;
	tile.cog = info->cog;
	tile.cob = info->cob;


	if (1 == YglIsCached(cacheaddr, &c))
	{
		YglCachedQuadOffset(&tile, &c, cx, cy, info->coordincx, info->coordincy);
		return;
	}

	YglQuadOffset(&tile, texture, &c, cx, cy, info->coordincx, info->coordincy);
	YglCacheAdd(cacheaddr, &c);

	switch (info->patternwh)
	{
	case 1:
		Vdp2DrawCell(info, texture);
		break;
	case 2:
		texture->w += 8;
		Vdp2DrawCell(info, texture);
		texture->textdata -= (texture->w + 8) * 8 - 8;
		Vdp2DrawCell(info, texture);
		texture->textdata -= 8;
		Vdp2DrawCell(info, texture);
		texture->textdata -= (texture->w + 8) * 8 - 8;
		Vdp2DrawCell(info, texture);
		break;
	}
}


static void Vdp2DrawPattern(vdp2draw_struct *info, YglTexture *texture)
{
	u32 cacheaddr = ((u32)(info->alpha >> 3) << 27) | (info->paladdr << 20) | info->charaddr | info->transparencyenable;
   YglCache c;
   YglSprite tile;
   int winmode=0;
   tile.dst = 0;
   tile.uclipmode = 0;
   tile.blendmode = info->blendmode;
    tile.linescreen = info->linescreen;
  tile.w = tile.h = info->patternpixelwh;
  tile.flip = info->flipfunction;

   if (info->islinescroll){
	   tile.h = info->lineinc;
   }


   if (info->specialprimode == 1)
      tile.priority = (info->priority & 0xFFFFFFFE) | info->specialfunction;
   else
      tile.priority = info->priority;


   tile.vertices[0] = info->x * info->coordincx;
   tile.vertices[1] = info->y * info->coordincy;
   tile.vertices[2] = (info->x + tile.w) * info->coordincx;
   tile.vertices[3] = info->y * info->coordincy;
   tile.vertices[4] = (info->x + tile.w) * info->coordincx;
   tile.vertices[5] = (info->y + tile.h) * info->coordincy;
   tile.vertices[6] = info->x * info->coordincx;
   tile.vertices[7] = (info->y + tile.h) * info->coordincy;


   // Screen culling
   if( tile.vertices[0] >= vdp2width || tile.vertices[1] >= vdp2height || tile.vertices[2] < 0 || tile.vertices[5] < 0 )
   {
      info->x += tile.w;
      info->y += tile.h;
      return;
   }

   if( (info->bEnWin0 != 0 || info->bEnWin1 != 0) && info->coordincy == 1.0f )
   {                                                 // coordinate inc is not supported yet.
      winmode=Vdp2CheckWindowRange( info,info->x,info->y,tile.w,tile.h);
      if( winmode == 0 ) // all outside, no need to draw
      {
         info->x += tile.w;
         info->y += tile.h;
         return;
      }
   }

   tile.cor = info->cor;
   tile.cog = info->cog;
   tile.cob = info->cob;

   if (1 == YglIsCached(cacheaddr,&c) )
   {
      YglCachedQuad(&tile, &c);
      info->x += tile.w;
      info->y += tile.h;
      return;
   }

   YglQuad(&tile, texture, &c);
   YglCacheAdd(cacheaddr, &c);

   switch(info->patternwh)
   {
      case 1:
         Vdp2DrawCell(info, texture);
         break;
      case 2:
         texture->w += 8;
         Vdp2DrawCell(info, texture);
         texture->textdata -= (texture->w + 8) * 8 - 8;
         Vdp2DrawCell(info, texture);
         texture->textdata -= 8;
         Vdp2DrawCell(info, texture);
         texture->textdata -= (texture->w + 8) * 8 - 8;
         Vdp2DrawCell(info, texture);
         break;
   }
   info->x += tile.w;
   info->y += tile.h;
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2PatternAddr(vdp2draw_struct *info)
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
               info->paladdr = ((tmp & 0xF000) >> 12) | ((info->supplementdata & 0xE0) >> 1);
               break;
            default: // not in 16 colors
               info->paladdr = (tmp & 0x7000) >> 8;
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
               info->paladdr = (tmp1 & 0x7F);
               break;
            default:
               info->paladdr = (tmp1 & 0x70);
               break;
         }
         info->specialfunction = (tmp1 & 0x2000) >> 13;
         info->specialcolorfunction = (tmp1 & 0x1000) >> 12;
         break;
      }
   }

   if (!(Vdp2Regs->VRSIZE & 0x8000))
      info->charaddr &= 0x3FFF;

   info->charaddr *= 0x20; // thanks Runik
}


static void Vdp2PatternAddrPos(vdp2draw_struct *info, int planex, int x, int planey, int y )
{
	u32 addr = info->addr +
		(info->pagewh*info->pagewh*info->planew*planey +
		info->pagewh*info->pagewh*planex +
		info->pagewh*y +
		x)*info->patterndatasize*2;

	switch (info->patterndatasize)
	{
	case 1:
	{
		u16 tmp = T1ReadWord(Vdp2Ram, addr);

		info->specialfunction = (info->supplementdata >> 9) & 0x1;
		info->specialcolorfunction = (info->supplementdata >> 8) & 0x1;

		switch (info->colornumber)
		{
		case 0: // in 16 colors
			info->paladdr = ((tmp & 0xF000) >> 12) | ((info->supplementdata & 0xE0) >> 1);
			break;
		default: // not in 16 colors
			info->paladdr = (tmp & 0x7000) >> 8;
			break;
		}

		switch (info->auxmode)
		{
		case 0:
			info->flipfunction = (tmp & 0xC00) >> 10;

			switch (info->patternwh)
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

			switch (info->patternwh)
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
		u16 tmp1 = T1ReadWord(Vdp2Ram, addr);
		u16 tmp2 = T1ReadWord(Vdp2Ram, addr+2);
		info->charaddr = tmp2 & 0x7FFF;
		info->flipfunction = (tmp1 & 0xC000) >> 14;
		switch (info->colornumber) {
		case 0:
			info->paladdr = (tmp1 & 0x7F);
			break;
		default:
			info->paladdr = (tmp1 & 0x70);
			break;
		}
		info->specialfunction = (tmp1 & 0x2000) >> 13;
		info->specialcolorfunction = (tmp1 & 0x1000) >> 12;
		break;
	}
	}

	if (!(Vdp2Regs->VRSIZE & 0x8000))
		info->charaddr &= 0x3FFF;

	info->charaddr *= 0x20; // thanks Runik
}


static void Vdp2DrawPage(vdp2draw_struct *info, YglTexture *texture)
{
   int X, Y;
   int i, j;

   X = info->x;
   for(i = 0;i < info->pagewh;i++)
   {
      Y = info->y;
      info->x = X;
      for(j = 0;j < info->pagewh;j++)
      {
         info->y = Y;
         if ((info->x >= -info->patternpixelwh) &&
             (info->y >= -info->patternpixelwh) &&
             (info->x <= info->draww) &&
             (info->y <= info->drawh))
         {
            Vdp2PatternAddr(info);
            Vdp2DrawPattern(info, texture);
         }
         else
         {
            info->addr += info->patterndatasize * 2;
            info->x += info->patternpixelwh;
            info->y += info->patternpixelwh;
         }
      }
   }
}

//////////////////////////////////////////////////////////////////////////////


static void Vdp2DrawPlane(vdp2draw_struct *info, YglTexture *texture)
{
   int X, Y;
   int i, j;

   X = info->x;
   for(i = 0;i < info->planeh;i++)
   {
      Y = info->y;
      info->x = X;
      for(j = 0;j < info->planew;j++)
      {
		 info->y = Y;
         Vdp2DrawPage(info, texture);
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawMapPerLine(vdp2draw_struct *info, YglTexture *texture){

	int lineindex = 0;

	int sx; //, sy;
	int mapx, mapy;
	int planex, planey;
	int pagex, pagey;
	int charx, chary;
    int dot_on_planey;
    int dot_on_pagey;
    int dot_on_planex;
    int dot_on_pagex;
    int h,v;
    const int planeh_shift = 9 + (info->planeh-1);
    const int planew_shift = 9 + (info->planew-1);
    const int plane_shift = 9;
    const int plane_mask = 0x1FF;
    const int page_shift = 9 - 7 + (64/info->pagewh);
    const int page_mask = 0x0f >> ((info->pagewh/32)-1);

	info->patternpixelwh = 8*info->patternwh;
	info->draww = (int)((float)vdp2width / info->coordincx);
	info->drawh = (int)((float)vdp2height / info->coordincy);




	for (v = 0; v < info->drawh; v += info->lineinc){  // ToDo: info->coordincy
		int targetv = 0;
		Vdp2 * regs;
		sx = info->x + info->lineinfo[lineindex].LineScrollValH;
		if (VDPLINE_SY(info->islinescroll)) {
			targetv = info->y + info->lineinfo[lineindex].LineScrollValV;
		}else{
			targetv = info->y + v;
		}

		if (info->isverticalscroll)	{
			// this is *wrong*, vertical scroll use a different value per cell
			// info->verticalscrolltbl should be incremented by info->verticalscrollinc
			// each time there's a cell change and reseted at the end of the line...
			// or something like that :)
			targetv += T1ReadLong(Vdp2Ram, info->verticalscrolltbl) >> 16;
		}

		info->coordincx = info->lineinfo[lineindex].CoordinateIncH / 256.0f;
		info->coordincx = 1.0f / info->coordincx;
		if (info->coordincx < info->maxzoom) info->coordincx = info->maxzoom;
		info->draww = (int)((float)vdp2width / info->coordincx);

		regs = Vdp2RestoreRegs(v, Vdp2Lines);
		if (regs) ReadVdp2ColorOffset(regs, info, info->linecheck_mask);

		// determine which chara shoud be used.
		//mapy   = (v+sy) / (512 * info->planeh);
		mapy = (targetv) >> planeh_shift;
		//int dot_on_planey = (v + sy) - mapy*(512 * info->planeh);
		dot_on_planey = (targetv)-(mapy << planeh_shift);
		mapy = mapy & 0x01;
		//planey = dot_on_planey / 512;
		planey = dot_on_planey >> plane_shift;
		//int dot_on_pagey = dot_on_planey - planey * 512;
        dot_on_pagey = dot_on_planey & plane_mask;
		planey = planey & (info->planeh - 1);
		//pagey = dot_on_pagey / (512 / info->pagewh);
		pagey = dot_on_pagey >> page_shift;
		//chary = dot_on_pagey - pagey*(512 / info->pagewh);
		chary = dot_on_pagey & page_mask;
		if (pagey < 0) pagey = info->pagewh - 1 + pagey;

		for (h = -info->patternpixelwh; h < info->draww + info->patternpixelwh; h += info->patternpixelwh){

			//mapx = (h + sx) / (512 * info->planew);
			mapx = (h + sx) >> planew_shift;
			//int dot_on_planex = (h + sx) - mapx*(512 * info->planew);
            dot_on_planex = (h + sx) - (mapx << planew_shift);
			mapx = mapx & 0x01;
			//planex = dot_on_planex / 512;
			planex = dot_on_planex >> plane_shift;
			//int dot_on_pagex = dot_on_planex - planex * 512;
            dot_on_pagex = dot_on_planex & plane_mask;
			planex = planex & (info->planew - 1);
			//pagex = dot_on_pagex / (512 / info->pagewh);
			pagex = dot_on_pagex >> page_shift;
			//charx = dot_on_pagex - pagex*(512 / info->pagewh);
			charx = dot_on_pagex & page_mask;
			if (pagex < 0) pagex = info->pagewh - 1 + pagex;

			info->PlaneAddr(info, info->mapwh * mapy + mapx, Vdp2Regs);
			Vdp2PatternAddrPos(info, planex,pagex, planey,pagey);
			Vdp2DrawPatternPos(info, texture, h, v, charx, chary);

		}

		lineindex++;
	}

}

static void Vdp2DrawMapTest(vdp2draw_struct *info, YglTexture *texture){

	int lineindex = 0;

	int sx; //, sy;
	int mapx, mapy;
	int planex, planey;
	int pagex, pagey;
	int charx, chary;
	int dot_on_planey;
	int dot_on_pagey;
	int dot_on_planex;
	int dot_on_pagex;
	int h, v;
	const int planeh_shift = 9 + (info->planeh - 1);
	const int planew_shift = 9 + (info->planew - 1);
	const int plane_shift = 9;
	const int plane_mask = 0x1FF;
	const int page_shift = 9 - 7 + (64 / info->pagewh);
	const int page_mask = 0x0f >> ((info->pagewh / 32) - 1);

	info->patternpixelwh = 8 * info->patternwh;
	info->draww = (int)((float)vdp2width / info->coordincx);
	info->drawh = (int)((float)vdp2height / info->coordincy);
	info->lineinc = info->patternpixelwh;

	//info->coordincx = 1.0f;

	for (v = -info->patternpixelwh; v < info->drawh + info->patternpixelwh; v += info->patternpixelwh){
		int targetv = 0;
		sx = info->x;
		targetv = info->y + v;

		if (info->isverticalscroll)	{
			// this is *wrong*, vertical scroll use a different value per cell
			// info->verticalscrolltbl should be incremented by info->verticalscrollinc
			// each time there's a cell change and reseted at the end of the line...
			// or something like that :)
			targetv += T1ReadLong(Vdp2Ram, info->verticalscrolltbl) >> 16;
		}

		// determine which chara shoud be used.
		//mapy   = (v+sy) / (512 * info->planeh);
		mapy = (targetv) >> planeh_shift;
		//int dot_on_planey = (v + sy) - mapy*(512 * info->planeh);
		dot_on_planey = (targetv)-(mapy << planeh_shift);
		mapy = mapy & 0x01;
		//planey = dot_on_planey / 512;
		planey = dot_on_planey >> plane_shift;
		//int dot_on_pagey = dot_on_planey - planey * 512;
		dot_on_pagey = dot_on_planey & plane_mask;
		planey = planey & (info->planeh - 1);
		//pagey = dot_on_pagey / (512 / info->pagewh);
		pagey = dot_on_pagey >> page_shift;
		//chary = dot_on_pagey - pagey*(512 / info->pagewh);
		chary = dot_on_pagey & page_mask;
		if (pagey < 0) pagey = info->pagewh - 1 + pagey;

		for (h = -info->patternpixelwh; h < info->draww + info->patternpixelwh; h += info->patternpixelwh){

			//mapx = (h + sx) / (512 * info->planew);
			mapx = (h + sx) >> planew_shift;
			//int dot_on_planex = (h + sx) - mapx*(512 * info->planew);
			dot_on_planex = (h + sx) - (mapx << planew_shift);
			mapx = mapx & 0x01;
			//planex = dot_on_planex / 512;
			planex = dot_on_planex >> plane_shift;
			//int dot_on_pagex = dot_on_planex - planex * 512;
			dot_on_pagex = dot_on_planex & plane_mask;
			planex = planex & (info->planew - 1);
			//pagex = dot_on_pagex / (512 / info->pagewh);
			pagex = dot_on_pagex >> page_shift;
			//charx = dot_on_pagex - pagex*(512 / info->pagewh);
			charx = dot_on_pagex & page_mask;
			if (pagex < 0) pagex = info->pagewh - 1 + pagex;

			info->PlaneAddr(info, info->mapwh * mapy + mapx, Vdp2Regs);
			Vdp2PatternAddrPos(info, planex, pagex, planey, pagey);
			Vdp2DrawPatternPos(info, texture, h - charx, v - chary, 0, 0);

		}

		lineindex++;
	}

}


//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawMap(vdp2draw_struct *info, YglTexture *texture)
{
   int i, j;
   int X, Y;
   int xx,yy;

   info->patternpixelwh = 8 * info->patternwh;
   info->draww = (int)((float)vdp2width / info->coordincx);
   info->drawh = (int)((float)vdp2height / info->coordincy);

   i=0;
   X = info->x;
   yy = info->y*info->coordincy;
   while( yy < vdp2height )
   {
      Y = info->y;
      j=0;
      info->x = X;
      xx = info->x*info->coordincx;
      while( xx < vdp2width )
      {
         info->y = Y;
         info->PlaneAddr(info, info->mapwh * i + j, Vdp2Regs);
         Vdp2DrawPlane(info, texture);
         j++;
         j &= (info->mapwh-1);
         xx += (info->patternpixelwh*info->pagewh*info->planew) * info->coordincx;
      }
      i++;
      i&=(info->mapwh-1);
      yy += (info->patternpixelwh*info->pagewh*info->planeh) * info->coordincy;
   }
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DoNothing(UNUSED void *info, u32 pixel)
{
   return pixel;
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL DoColorOffset(void *info, u32 pixel)
{
    return pixel;
}

#if 0
static u32 FASTCALL DoColorOffset(void *info, u32 pixel)
{
    return COLOR_ADD(pixel, ((vdp2draw_struct *)info)->cor,
                     ((vdp2draw_struct *)info)->cog,
                     ((vdp2draw_struct *)info)->cob);
}
#endif



//////////////////////////////////////////////////////////////////////////////

static INLINE void ReadVdp2ColorOffset(Vdp2 * regs, vdp2draw_struct *info, int mask)
{
	if (regs->CLOFEN & mask)
   {
      // color offset enable
	   if (regs->CLOFSL & mask)
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
   else{ // color offset disable

      info->PostPixelFetchCalc = &DoNothing;
    info->cor=0;
      info->cob=0;
      info->cog=0;

    }
}

//////////////////////////////////////////////////////////////////////////////

static INLINE u32 Vdp2RotationFetchPixel(vdp2draw_struct *info, int x, int y, int cellw)
{
   u32 dot;

   switch(info->colornumber)
   {
      case 0: // 4 BPP
         dot = T1ReadByte(Vdp2Ram, ((info->charaddr + ((y * cellw) + x) / 2) & 0x7FFFF));
         if (!(x & 0x1)) dot >>= 4;
         if (!(dot & 0xF) && info->transparencyenable) return 0x00000000;
         else return Vdp2ColorRamGetColor(info->coloroffset + ((info->paladdr << 4) | (dot & 0xF)), info->alpha);
      case 1: // 8 BPP
         dot = T1ReadByte(Vdp2Ram, ((info->charaddr + (y * cellw) + x) & 0x7FFFF));
         if (!(dot & 0xFF) && info->transparencyenable) return 0x00000000;
         else return Vdp2ColorRamGetColor(info->coloroffset + ((info->paladdr << 4) | (dot & 0xFF)), info->alpha);
      case 2: // 16 BPP(palette)
         dot = T1ReadWord(Vdp2Ram, ((info->charaddr + ((y * cellw) + x) * 2) & 0x7FFFF));
         if ((dot == 0) && info->transparencyenable) return 0x00000000;
         else return Vdp2ColorRamGetColor(info->coloroffset + dot, info->alpha);
      case 3: // 16 BPP(RGB)
         dot = T1ReadWord(Vdp2Ram, ((info->charaddr + ((y * cellw) + x) * 2) & 0x7FFFF));
         if (!(dot & 0x8000) && info->transparencyenable) return 0x00000000;
         else return SAT2YAB1(0xFF, dot);
      case 4: // 32 BPP
         dot = T1ReadLong(Vdp2Ram, ((info->charaddr + ((y * cellw) + x) * 4) & 0x7FFFF));
         if (!(dot & 0x80000000) && info->transparencyenable) return 0x00000000;
         else return SAT2YAB2(info->alpha, (dot >> 16), dot);
      default:
         return 0;
   }
}

//////////////////////////////////////////////////////////////////////////////
static void FASTCALL Vdp2DrawRotation(vdp2draw_struct *info, vdp2rotationparameter_struct *dmy, YglTexture *texture)
{
   int useb = 0;
   int i, j;
   int x, y;
   int cellw, cellh;
   int pagepixelwh;
   int planepixelwidth;
   int planepixelheight;
   int screenwidth;
   int screenheight;
   int oldcellx=-1, oldcelly=-1;
   u32 color;
   int vres,hres;
   int h;
   int v;
   int pagesize;
   int patternshift;
   u32 LineColorRamAdress;
   vdp2draw_struct line_info;
   YglTexture line_texture;
   int lineInc = Vdp2Regs->LCTA.part.U & 0x8000 ? 2 : 0;
   int linecl = 0xFF;
   vdp2rotationparameter_struct *parameter;
   Vdp2 * regs;
   if ((Vdp2Regs->CCCTL >> 5) & 0x01){
	   linecl = ((~Vdp2Regs->CCRLB & 0x1F) << 3) + 0x7;
   }

   if( vdp2height >= 448 ) vres = (vdp2height>>1); else vres = vdp2height;
   if( vdp2width >= 640 ) hres = (vdp2width>>1); else hres = vdp2width;
   info->vertices[0] = 0;
   info->vertices[1] = 0;
   info->vertices[2] = vdp2width;
   info->vertices[3] = 0;
   info->vertices[4] = vdp2width;
   info->vertices[5] = vdp2height;
   info->vertices[6] = 0;
   info->vertices[7] = vdp2height;
   cellw = info->cellw;
   cellh = info->cellh;
   info->cellw = hres;
   info->cellh = vres;
   info->flipfunction = 0;
   info->linescreen = 0;
   info->cor = 0x00;
   info->cog = 0x00;
   info->cob = 0x00;

   if( Vdp2Regs->RPMD != 0 ) useb = 1;

   if (!info->isbitmap)
   {
      pagepixelwh=64*8;
      planepixelwidth=info->planew*pagepixelwh;
      planepixelheight=info->planeh*pagepixelwh;
      screenwidth=4*planepixelwidth;
      screenheight=4*planepixelheight;
      oldcellx=-1;
      oldcelly=-1;
      pagesize=info->pagewh*info->pagewh;
      patternshift = (2+info->patternwh);
   }
   else
   {
      pagepixelwh=0;
      planepixelwidth=0;
      planepixelheight=0;
      screenwidth=0;
      screenheight=0;
      oldcellx=0;
      oldcelly=0;
      pagesize=0;
      patternshift = 0;
   }

   regs = Vdp2RestoreRegs(3, Vdp2Lines);
   if (regs) ReadVdp2ColorOffset(regs, info, info->linecheck_mask);

   line_texture.textdata = NULL;
   if( info->LineColorBase !=0 )
   {
	   memcpy(&line_info, info, sizeof(vdp2draw_struct));
	   line_info.blendmode = 0;
	   YglQuad((YglSprite *)&line_info, &line_texture, NULL);
	   LineColorRamAdress = (T1ReadWord(Vdp2Ram, info->LineColorBase) & 0x7FF);// +info->coloroffset;
   }else{
      LineColorRamAdress = 0x00;
   }

   YglQuad((YglSprite *)info, texture, NULL);
   info->cellw = cellw;
   info->cellh = cellh;
   x = 0;
   y = 0;

    paraA.dx = paraA.A * paraA.deltaX + paraA.B * paraA.deltaY;
    paraA.dy = paraA.D * paraA.deltaX + paraA.E * paraA.deltaY;
    paraA.Xp = paraA.A * (paraA.Px - paraA.Cx) +
               paraA.B * (paraA.Py - paraA.Cy) +
               paraA.C * (paraA.Pz - paraA.Cz) + paraA.Cx + paraA.Mx;
    paraA.Yp = paraA.D * (paraA.Px - paraA.Cx) +
               paraA.E * (paraA.Py - paraA.Cy) +
               paraA.F * (paraA.Pz - paraA.Cz) + paraA.Cy + paraA.My;

    if(useb)
    {
      paraB.dx = paraB.A * paraB.deltaX + paraB.B * paraB.deltaY;
      paraB.dy = paraB.D * paraB.deltaX + paraB.E * paraB.deltaY;
      paraB.Xp = paraB.A * (paraB.Px - paraB.Cx) + paraB.B * (paraB.Py - paraB.Cy)
               + paraB.C * (paraB.Pz - paraB.Cz) + paraB.Cx + paraB.Mx;
      paraB.Yp = paraB.D * (paraB.Px - paraB.Cx) + paraB.E * (paraB.Py - paraB.Cy)
               + paraB.F * (paraB.Pz - paraB.Cz) + paraB.Cy + paraB.My;
    }


   for (j = 0; j < vres; j++)
   {
      paraA.Xsp = paraA.A * ((paraA.Xst + paraA.deltaXst * j) - paraA.Px) +
                  paraA.B * ((paraA.Yst + paraA.deltaYst * j) - paraA.Py) +
                  paraA.C * (paraA.Zst - paraA.Pz);

      paraA.Ysp = paraA.D * ((paraA.Xst + paraA.deltaXst *j) - paraA.Px) +
                  paraA.E * ((paraA.Yst + paraA.deltaYst * j) - paraA.Py) +
                  paraA.F * (paraA.Zst - paraA.Pz);

      paraA.KtablV = paraA.deltaKAst* j;
      if(useb)
      {
         paraB.Xsp = paraB.A * ((paraB.Xst + paraB.deltaXst * j) - paraB.Px) +
                  paraB.B * ((paraB.Yst + paraB.deltaYst * j) - paraB.Py) +
                  paraB.C * (paraB.Zst - paraB.Pz);

         paraB.Ysp = paraB.D * ((paraB.Xst + paraB.deltaXst * j) - paraB.Px) +
                  paraB.E * ((paraB.Yst + paraB.deltaYst * j) - paraB.Py) +
                  paraB.F * (paraB.Zst - paraB.Pz);

         paraB.KtablV = paraB.deltaKAst * j;
      }


      if( (Vdp2Regs->LCTA.part.U & 0x8000) != 0 && info->LineColorBase !=0 )
      {
		  LineColorRamAdress = (T1ReadWord(Vdp2Ram, info->LineColorBase) & 0x7FF);
		 info->LineColorBase += lineInc;
      }

//	  Vdp2 * regs = Vdp2RestoreRegs(j);
//	  if (regs) ReadVdp2ColorOffset(regs, info, info->linecheck_mask);

	  for (i = 0; i < hres; i++)
	  {
		  parameter = info->GetRParam(info, i, j);
		  if (parameter == NULL)
		  {
			  *(texture->textdata++) = 0x00000000;
			  if (line_texture.textdata) *(line_texture.textdata++) = 0x00000000;
			  continue;
		  }

		  h = (parameter->ky * (parameter->Xsp + parameter->dx * i) + parameter->Xp);
		  v = (parameter->ky * (parameter->Ysp + parameter->dy * i) + parameter->Yp);

		  if (info->isbitmap)
		  {
			  h &= cellw - 1;
			  v &= cellh - 1;

			  // Fetch Pixel
			  color = Vdp2RotationFetchPixel(info, h, v, cellw);
		  }
		  else
		  {
			  // Tile
			  int planenum;
			  if ((h < 0 || h >= parameter->MaxH) || (v < 0 || v >= parameter->MaxV))
			  {
				  switch (parameter->screenover)
				  {
				  case OVERMODE_REPEAT:
					  h &= (parameter->MaxH - 1);
					  v &= (parameter->MaxH - 1);
					  break;
				  case OVERMODE_SELPATNAME:
					  *(texture->textdata++) = 0x00;  // ToDO
					  if (line_texture.textdata) *(line_texture.textdata++) = 0x00000000;
					  continue;
					  break;
				  default:
					  *(texture->textdata++) = 0x00;
					  if (line_texture.textdata) *(line_texture.textdata++) = 0x00000000;
					  continue;
				  }
			  }

			  x = h;
			  y = v;


			  if ((x >> patternshift) != oldcellx || (y >> patternshift) != oldcelly)
			  {
				  oldcellx = x >> patternshift;
				  oldcelly = y >> patternshift;

				  // Calculate which plane we're dealing with
				  planenum = (x >> parameter->ShiftPaneX) + ((y >> parameter->ShiftPaneY) << 2);
				  x &= parameter->MskH;
				  y &= parameter->MskV;
				  info->addr = parameter->PlaneAddrv[planenum];

				  // Figure out which page it's on(if plane size is not 1x1)
				  info->addr += (((y >> 9) * pagesize * info->planew) +
					  ((x >> 9) * pagesize) +
					  (((y & 511) >> patternshift) * info->pagewh) +
					  ((x & 511) >> patternshift)) << info->patterndatasize;

				  Vdp2PatternAddr(info); // Heh, this could be optimized
			  }

			  // Figure out which pixel in the tile we want
			  if (info->patternwh == 1)
			  {
				  x &= 8 - 1;
				  y &= 8 - 1;

				  // vertical flip
				  if (info->flipfunction & 0x2)
					  y = 8 - 1 - y;

				  // horizontal flip
				  if (info->flipfunction & 0x1)
					  x = 8 - 1 - x;
			  }
			  else
			  {
				  if (info->flipfunction)
				  {
					  y &= 16 - 1;
					  if (info->flipfunction & 0x2)
					  {
						  if (!(y & 8))
							  y = 8 - 1 - y + 16;
						  else
							  y = 16 - 1 - y;
					  }
					  else if (y & 8)
						  y += 8;

					  if (info->flipfunction & 0x1)
					  {
						  if (!(x & 8))
							  y += 8;

						  x &= 8 - 1;
						  x = 8 - 1 - x;
					  }
					  else if (x & 8)
					  {
						  y += 8;
						  x &= 8 - 1;
					  }
					  else
						  x &= 8 - 1;
				  }
				  else
				  {
					  y &= 16 - 1;
					  if (y & 8)
						  y += 8;
					  if (x & 8)
						  y += 8;
					  x &= 8 - 1;
				  }
			  }

			  // Fetch pixel
			  color = Vdp2RotationFetchPixel(info, x, y, 8);
		  }

		  if (line_texture.textdata) {
			  if ((color & 0xFF000000) == 0) {
				  *(line_texture.textdata++) = 0x00000000;
			  }else{
				  if (parameter->lineaddr != 0xFFFFFFFF)
				  {
					  u32 linecolor = Vdp2ColorRamGetColor(LineColorRamAdress | parameter->lineaddr, linecl);
					  *(line_texture.textdata++) = linecolor;
				  } else{
					  *(line_texture.textdata++) = 0x0 | (linecl << 24);
				  }
			  }
		  }

		  *(texture->textdata++) = color;
		}
		if (line_texture.textdata) line_texture.textdata += line_texture.w;
        texture->textdata += texture->w;
   }


}




//////////////////////////////////////////////////////////////////////////////

static void SetSaturnResolution(int width, int height)
{
   YglChangeResolution(width, height);

   vdp2width=width;
   vdp2height=height;
}

//////////////////////////////////////////////////////////////////////////////

int VIDOGLInit(void)
{

   if (YglInit(2048, 1024, 8) != 0)
      return -1;

   SetSaturnResolution(320, 224);

   vdp1wratio = 1;
   vdp1hratio = 1;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLDeInit(void)
{
   YglDeInit();
}

//////////////////////////////////////////////////////////////////////////////

int _VIDOGLIsFullscreen;

void VIDOGLResize(unsigned int w, unsigned int h, int on)
{
//   glDeleteTextures(1, &_Ygl->texture);

   _VIDOGLIsFullscreen = on;

   GlHeight=h;
   GlWidth=w;

   _Ygl->width = w;
   _Ygl->height = h;


   YglGLInit(2048, 1024);
   glViewport(0, 0, w, h);
   YglNeedToUpdateWindow();

   SetSaturnResolution(vdp2width, vdp2height);

}

//////////////////////////////////////////////////////////////////////////////

int VIDOGLIsFullscreen(void) {
   return _VIDOGLIsFullscreen;
}

//////////////////////////////////////////////////////////////////////////////

int VIDOGLVdp1Reset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1DrawStart(void)
{
   int i;
   int maxpri;
   int minpri;
   u8 *sprprilist = (u8 *)&Vdp2Regs->PRISA;

   if (YglTM->texture == NULL) {
     glActiveTexture(GL_TEXTURE0);
     glBindTexture(GL_TEXTURE_2D, _Ygl->texture);
     glBindBuffer(GL_PIXEL_UNPACK_BUFFER, _Ygl->pixelBufferID);
     YglTM->texture = (int*)glMapBufferRange(GL_PIXEL_UNPACK_BUFFER, 0, 2048 * 1024 * 4, GL_MAP_WRITE_BIT);
	 if (YglTM->texture == NULL){
		 abort();
	 }
   }

   YglCacheReset();


   maxpri = 0x00;
   minpri = 0x07;
   for( i=0; i<8; i++ )
   {
      if( (sprprilist[i]&0x07) < minpri ) minpri = (sprprilist[i]&0x07);
      if( (sprprilist[i]&0x07) > maxpri ) maxpri = (sprprilist[i]&0x07);
   }
   _Ygl->vdp1_maxpri = maxpri;
   _Ygl->vdp1_minpri = minpri;

   if (Vdp2Regs->CLOFEN & 0x40)
   {
      // color offset enable
      if (Vdp2Regs->CLOFSL & 0x40)
      {
         // color offset B
         vdp1cor = Vdp2Regs->COBR & 0xFF;
         if (Vdp2Regs->COBR & 0x100)
            vdp1cor |= 0xFFFFFF00;

         vdp1cog = Vdp2Regs->COBG & 0xFF;
         if (Vdp2Regs->COBG & 0x100)
            vdp1cog |= 0xFFFFFF00;

         vdp1cob = Vdp2Regs->COBB & 0xFF;
         if (Vdp2Regs->COBB & 0x100)
            vdp1cob |= 0xFFFFFF00;
      }
      else
      {
         // color offset A
         vdp1cor = Vdp2Regs->COAR & 0xFF;
         if (Vdp2Regs->COAR & 0x100)
            vdp1cor |= 0xFFFFFF00;

         vdp1cog = Vdp2Regs->COAG & 0xFF;
         if (Vdp2Regs->COAG & 0x100)
            vdp1cog |= 0xFFFFFF00;

         vdp1cob = Vdp2Regs->COAB & 0xFF;
         if (Vdp2Regs->COAB & 0x100)
            vdp1cob |= 0xFFFFFF00;
      }
   }
   else // color offset disable
      vdp1cor = vdp1cog = vdp1cob = 0;

   Vdp1DrawCommands(Vdp1Ram, Vdp1Regs, NULL);
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1DrawEnd(void)
{
  YglRenderVDP1();
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1NormalSpriteDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer)
{
   vdp1cmd_struct cmd;
   YglSprite sprite;
   YglTexture texture;
   YglCache cash;
   u32 tmp;
   s16 x, y;
   u16 CMDPMOD;
   u16 color2;
   float col[4*4];
   int i;
   short CMDXA;
   short CMDYA;


   Vdp1ReadCommand(&cmd, Vdp1Regs->addr, Vdp1Ram);
   sprite.dst=0;
   sprite.blendmode=0;
   sprite.linescreen = 0;

   CMDXA = cmd.CMDXA;
   CMDYA = cmd.CMDYA;

   if ((CMDXA & 0x800)) CMDXA |= 0xF800; else CMDXA &= ~(0xF800);
   if ((CMDYA & 0x800)) CMDYA |= 0xF800; else CMDYA &= ~(0xF800);

   x = CMDXA + Vdp1Regs->localX;
   y = CMDYA + Vdp1Regs->localY;
   sprite.w = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
   sprite.h = cmd.CMDSIZE & 0xFF;

   sprite.flip = (cmd.CMDCTRL & 0x30) >> 4;

   sprite.vertices[0] = (int)((float)x * vdp1wratio);
   sprite.vertices[1] = (int)((float)y * vdp1hratio);
   sprite.vertices[2] = (int)((float)(x + sprite.w) * vdp1wratio);
   sprite.vertices[3] = (int)((float)y * vdp1hratio);
   sprite.vertices[4] = (int)((float)(x + sprite.w) * vdp1wratio);
   sprite.vertices[5] = (int)((float)(y + sprite.h) * vdp1hratio);
   sprite.vertices[6] = (int)((float)x * vdp1wratio);
   sprite.vertices[7] = (int)((float)(y + sprite.h) * vdp1hratio);

   tmp = cmd.CMDSRCA;
   tmp <<= 16;
   tmp |= cmd.CMDCOLR;

   sprite.priority = 8;

   CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x4);

   sprite.uclipmode=(CMDPMOD>>9)&0x03;

   // Half trans parent to VDP1 Framebuffer
   if( (CMDPMOD & 0x3)==0x03 || (CMDPMOD & 0x100) )
   {
      tmp |= 0x00010000;
      sprite.blendmode = 0x80;
   }

   if((CMDPMOD & 0x8000) != 0)
   {
      tmp |= 0x00020000;
   }

   if( (CMDPMOD & 4)  )
   {
      for (i=0; i<4; i++)
      {
         color2 = T1ReadWord(Vdp1Ram, (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1C) << 3) + (i << 1));
         col[(i << 2) + 0] = (float)((color2 & 0x001F))/(float)(0x1F)-0.5f;
         col[(i << 2) + 1] = (float)((color2 & 0x03E0)>>5)/(float)(0x1F)-0.5f;
         col[(i << 2) + 2] = (float)((color2 & 0x7C00)>>10)/(float)(0x1F)-0.5f;
         col[(i << 2) + 3] = 1.0f;
      }

      if (sprite.w > 0 && sprite.h > 0)
      {
         if (1 == YglIsCached(tmp,&cash) )
         {
            YglCacheQuadGrowShading(&sprite, col,&cash);
            return;
         }

         YglQuadGrowShading(&sprite, &texture,col,&cash);
         YglCacheAdd(tmp,&cash);
         Vdp1ReadTexture(&cmd, &sprite, &texture);
         return;
      }

   }
   else // No Gouraud shading, use same color for all 4 vertices
   {
      if (sprite.w > 0 && sprite.h > 0)
      {
         if (1 == YglIsCached(tmp,&cash) )
         {
            YglCacheQuadGrowShading(&sprite, NULL,&cash);
            return;
         }

         YglQuadGrowShading(&sprite, &texture,NULL,&cash);
         YglCacheAdd(tmp,&cash);

         Vdp1ReadTexture(&cmd, &sprite, &texture);
	  }
   }
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1ScaledSpriteDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer)
{
   vdp1cmd_struct cmd;
   YglSprite sprite;
   YglTexture texture;
   YglCache cash;
   u32 tmp;
   s16 rw=0, rh=0;
   s16 x, y;
   u16 CMDPMOD;
   u16 color2;
   float col[4*4];
   int i;

   Vdp1ReadCommand(&cmd, Vdp1Regs->addr, Vdp1Ram);
   sprite.dst=0;
   sprite.blendmode=0;
   sprite.linescreen = 0;

   if ((cmd.CMDYA & 0x800)) cmd.CMDYA |= 0xF800; else cmd.CMDYA &= ~(0xF800);
   if ((cmd.CMDYC & 0x800)) cmd.CMDYC |= 0xF800; else cmd.CMDYC &= ~(0xF800);
   if ((cmd.CMDYB & 0x800)) cmd.CMDYB |= 0xF800; else cmd.CMDYB &= ~(0xF800);
   if ((cmd.CMDYD & 0x800)) cmd.CMDYD |= 0xF800; else cmd.CMDYD &= ~(0xF800);

   x = cmd.CMDXA + Vdp1Regs->localX;
   y = cmd.CMDYA + Vdp1Regs->localY;
   sprite.w = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
   sprite.h = cmd.CMDSIZE & 0xFF;
   sprite.flip = (cmd.CMDCTRL & 0x30) >> 4;

   // Setup Zoom Point
   switch ((cmd.CMDCTRL & 0xF00) >> 8)
   {
      case 0x0: // Only two coordinates
         rw = cmd.CMDXC - x + Vdp1Regs->localX + 1;
         rh = cmd.CMDYC - y + Vdp1Regs->localY + 1;
         break;
      case 0x5: // Upper-left
         rw = cmd.CMDXB + 1;
         rh = cmd.CMDYB + 1;
         break;
      case 0x6: // Upper-Center
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         x = x - rw/2;
         rw++;
         rh++;
         break;
      case 0x7: // Upper-Right
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         x = x - rw;
         rw++;
         rh++;
         break;
      case 0x9: // Center-left
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         y = y - rh/2;
         rw++;
         rh++;
         break;
      case 0xA: // Center-center
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         x = x - rw/2;
         y = y - rh/2;
         rw++;
         rh++;
         break;
      case 0xB: // Center-right
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         x = x - rw;
         y = y - rh/2;
         rw++;
         rh++;
         break;
      case 0xD: // Lower-left
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         y = y - rh;
         rw++;
         rh++;
         break;
      case 0xE: // Lower-center
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         x = x - rw/2;
         y = y - rh;
         rw++;
         rh++;
         break;
      case 0xF: // Lower-right
         rw = cmd.CMDXB;
         rh = cmd.CMDYB;
         x = x - rw;
         y = y - rh;
         rw++;
         rh++;
         break;
      default: break;
   }

   sprite.vertices[0] = (int)((float)x * vdp1wratio);
   sprite.vertices[1] = (int)((float)y * vdp1hratio);
   sprite.vertices[2] = (int)((float)(x + rw) * vdp1wratio);
   sprite.vertices[3] = (int)((float)y * vdp1hratio);
   sprite.vertices[4] = (int)((float)(x + rw) * vdp1wratio);
   sprite.vertices[5] = (int)((float)(y + rh) * vdp1hratio);
   sprite.vertices[6] = (int)((float)x * vdp1wratio);
   sprite.vertices[7] = (int)((float)(y + rh) * vdp1hratio);

   tmp = cmd.CMDSRCA;
   tmp <<= 16;
   tmp |= cmd.CMDCOLR;

   CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x4);
   sprite.uclipmode=(CMDPMOD>>9)&0x03;

   sprite.priority = 8;

   // Half trans parent to VDP1 Framebuffer
   if( (CMDPMOD & 0x3)==0x03 || (CMDPMOD & 0x100) )
   {
      tmp |= 0x00010000;
      sprite.blendmode = 0x80;
   }

   // MSB
   if((CMDPMOD & 0x8000) != 0)
   {
      tmp |= 0x00020000;
   }


   if ( (CMDPMOD & 4) )
   {
      for (i=0; i<4; i++)
      {
         color2 = T1ReadWord(Vdp1Ram, (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1C) << 3) + (i << 1));
         col[(i << 2) + 0] = (float)((color2 & 0x001F))/(float)(0x1F)-0.5f;
         col[(i << 2) + 1] = (float)((color2 & 0x03E0)>>5)/(float)(0x1F)-0.5f;
         col[(i << 2) + 2] = (float)((color2 & 0x7C00)>>10)/(float)(0x1F)-0.5f;
         col[(i << 2) + 3] = 1.0f;
      }

      if (sprite.w > 0 && sprite.h > 0)
      {
         if (1 == YglIsCached(tmp,&cash) )
         {
            YglCacheQuadGrowShading(&sprite, col,&cash);
            return;
         }

         YglQuadGrowShading(&sprite, &texture,col,&cash);
         YglCacheAdd(tmp,&cash);
         Vdp1ReadTexture(&cmd, &sprite, &texture);
         return;
	  }


   }
   else // No Gouraud shading, use same color for all 4 vertices
   {
      if (sprite.w > 0 && sprite.h > 0)
      {
         if (1 == YglIsCached(tmp,&cash) )
         {
            YglCacheQuadGrowShading(&sprite, NULL,&cash);
            return;
         }

         YglQuadGrowShading(&sprite, &texture,NULL,&cash);
         YglCacheAdd(tmp,&cash);

         Vdp1ReadTexture(&cmd, &sprite, &texture);
	  }

   }

}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1DistortedSpriteDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer)
{
   vdp1cmd_struct cmd;
   YglSprite sprite;
   YglTexture texture;
   YglCache cash;
   u32 tmp;
   u16 CMDPMOD;
   u16 color2;
   int i;
   float col[4*4];
   int isSquare;


   Vdp1ReadCommand(&cmd, Vdp1Regs->addr, Vdp1Ram);
   sprite.blendmode=0;
   sprite.linescreen = 0;
   sprite.dst = 1;
   sprite.w = ((cmd.CMDSIZE >> 8) & 0x3F) * 8;
   sprite.h = cmd.CMDSIZE & 0xFF;
   sprite.cor = 0;
   sprite.cog = 0;
   sprite.cob = 0;

   sprite.flip = (cmd.CMDCTRL & 0x30) >> 4;

   if ((cmd.CMDYA & 0x800)) cmd.CMDYA |= 0xF800; else cmd.CMDYA &= ~(0xF800);
   if ((cmd.CMDYC & 0x800)) cmd.CMDYC |= 0xF800; else cmd.CMDYC &= ~(0xF800);
   if ((cmd.CMDYB & 0x800)) cmd.CMDYB |= 0xF800; else cmd.CMDYB &= ~(0xF800);
   if ((cmd.CMDYD & 0x800)) cmd.CMDYD |= 0xF800; else cmd.CMDYD &= ~(0xF800);


   sprite.vertices[0] = (s16)cmd.CMDXA;
   sprite.vertices[1] = (s16)cmd.CMDYA;
   sprite.vertices[2] = (s16)cmd.CMDXB;
   sprite.vertices[3] = (s16)cmd.CMDYB;
   sprite.vertices[4] = (s16)cmd.CMDXC;
   sprite.vertices[5] = (s16)cmd.CMDYC;
   sprite.vertices[6] = (s16)cmd.CMDXD;
   sprite.vertices[7] = (s16)cmd.CMDYD;

   isSquare = 1;
   for (i = 0; i < 3; i++){
	   float dx = sprite.vertices[((i + 1) << 1) + 0] - sprite.vertices[((i + 0) << 1) + 0];
	   float dy = sprite.vertices[((i + 1) << 1) + 1] - sprite.vertices[((i + 0) << 1) + 1];
	   float d2x = sprite.vertices[(((i + 2)&0x3) << 1) + 0] - sprite.vertices[((i + 1) << 1) + 0];
	   float d2y = sprite.vertices[(((i + 2)&0x3) << 1) + 1] - sprite.vertices[((i + 1) << 1) + 1];
	   float dot = dx*d2x + dy*d2y;
	   if (dot >= EPSILON || dot <= -EPSILON){
		   isSquare = 0;
		   break;
	   }
   }
   if (isSquare){
	   float minx;
	   float miny;
	   int lt_index;

	   sprite.dst = 0;

	   // find upper left opsition
	   minx = 65535.0f;
	   miny = 65535.0f;
	   lt_index = -1;
	   for( i = 0; i < 4; i++){
		   if (sprite.vertices[(i << 1) + 0] <= minx && sprite.vertices[(i << 1) + 1] <= miny){
			   minx = sprite.vertices[(i << 1) + 0];
			   miny = sprite.vertices[(i << 1) + 1];
			   lt_index = i;
		   }
	   }

	   for (i = 0; i < 4; i++){
		   if (i != lt_index){
			   float nx;
			   float ny;
			   // vectorize
			   float dx = sprite.vertices[(i << 1) + 0] - sprite.vertices[((lt_index) << 1) + 0];
			   float dy = sprite.vertices[(i << 1) + 1] - sprite.vertices[((lt_index) << 1) + 1];

			   // normalize
			   float len = fabsf(sqrtf(dx*dx + dy*dy));
			   if (len <= EPSILON){
				   continue;
			   }
			   nx = dx / len;
			   ny = dy / len;
			   if (nx >= EPSILON) nx = 1.0f; else nx = 0.0f;
			   if (ny >= EPSILON) ny = 1.0f; else ny = 0.0f;

			   // expand vertex
			   sprite.vertices[(i << 1) + 0] += nx;
			   sprite.vertices[(i << 1) + 1] += ny;
		   }
	   }
   }

   sprite.vertices[0] = (sprite.vertices[0] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[1] = (sprite.vertices[1] + Vdp1Regs->localY) * vdp1hratio;
   sprite.vertices[2] = (sprite.vertices[2] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[3] = (sprite.vertices[3] + Vdp1Regs->localY) * vdp1hratio;
   sprite.vertices[4] = (sprite.vertices[4] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[5] = (sprite.vertices[5] + Vdp1Regs->localY) * vdp1hratio;
   sprite.vertices[6] = (sprite.vertices[6] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[7] = (sprite.vertices[7] + Vdp1Regs->localY) * vdp1hratio;


   tmp = cmd.CMDSRCA;

   tmp <<= 16;
   tmp |= cmd.CMDCOLR;

   CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x4);

   sprite.priority = 8;

   sprite.uclipmode=(CMDPMOD>>9)&0x03;

   // Half trans parent to VDP1 Framebuffer
   if( (CMDPMOD & 0x3)==0x03 || (CMDPMOD & 0x100) )
   {
      tmp |= 0x00010000;
      sprite.blendmode = 0x80;
   }

   // MSB
   if((CMDPMOD & 0x8000) != 0)
   {
      tmp |= 0x00020000;
   }

   // Check if the Gouraud shading bit is set and the color mode is RGB
   if ( (CMDPMOD & 4) )
   {
      for (i=0; i<4; i++)
      {
         color2 = T1ReadWord(Vdp1Ram, (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1C) << 3) + (i << 1));
         col[(i << 2) + 0] = (float)((color2 & 0x001F))/(float)(0x1F)-0.5f;
         col[(i << 2) + 1] = (float)((color2 & 0x03E0)>>5)/(float)(0x1F)-0.5f;
         col[(i << 2) + 2] = (float)((color2 & 0x7C00)>>10)/(float)(0x1F)-0.5f;
         col[(i << 2) + 3] = 1.0f;
      }

      if (1 == YglIsCached(tmp,&cash) )
      {
	      YglCacheQuadGrowShading(&sprite, col,&cash);
          return;
      }

		YglQuadGrowShading(&sprite, &texture,col,&cash);
		YglCacheAdd(tmp,&cash);
		Vdp1ReadTexture(&cmd, &sprite, &texture);
		return;
   }
   else // No Gouraud shading, use same color for all 4 vertices
   {
		if (1 == YglIsCached(tmp,&cash) )
        {
			YglCacheQuadGrowShading(&sprite, NULL,&cash);
			return;
		}
		YglQuadGrowShading(&sprite, &texture,NULL,&cash);
		YglCacheAdd(tmp,&cash);
		Vdp1ReadTexture(&cmd, &sprite, &texture);
   }

   return ;
}

//////////////////////////////////////////////////////////////////////////////

#define IS_MESH(a) (a&0x100)
#define IS_GLOWSHADING(a) (a&0x04)
#define IS_REPLACE(a) ((a&0x03)==0x00)
#define IS_DONOT_DRAW_OR_SHADOW(a) ((a&0x03)==0x01)
#define IS_HALF_LUMINANCE(a)   ((a&0x03)==0x02)
#define IS_REPLACE_OR_HALF_TRANSPARENT(a) ((a&0x03)==0x03)


void VIDOGLVdp1PolygonDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer)
{
   s16 X[4];
   s16 Y[4];
   u16 color;
   u16 CMDPMOD;
   u8 alpha;
   YglSprite sprite;
   YglTexture texture;
   u16 color2;
   int i;
   float col[4*4];
   int gouraud=0;
   int priority;
   short CMDYA;
   short CMDYB;
   short CMDYC;
   short CMDYD;
   int isSquare;

   vdp1cmd_struct cmd;

   sprite.linescreen = 0;

   Vdp1ReadCommand(&cmd, Vdp1Regs->addr, Vdp1Ram);

   CMDYA = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xE);
   CMDYB = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12);
   CMDYC = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);
   CMDYD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1A);

   if ((CMDYA & 0x800)) CMDYA |= 0xF800; else CMDYA &= ~(0xF800);
   if ((CMDYC & 0x800)) CMDYC |= 0xF800; else CMDYC &= ~(0xF800);
   if ((CMDYB & 0x800)) CMDYB |= 0xF800; else CMDYB &= ~(0xF800);
   if ((CMDYD & 0x800)) CMDYD |= 0xF800; else CMDYD &= ~(0xF800);

   sprite.blendmode = 0;
   sprite.dst = 0;


   sprite.vertices[0] = (s16)cmd.CMDXA;
   sprite.vertices[1] = (s16)cmd.CMDYA;
   sprite.vertices[2] = (s16)cmd.CMDXB;
   sprite.vertices[3] = (s16)cmd.CMDYB;
   sprite.vertices[4] = (s16)cmd.CMDXC;
   sprite.vertices[5] = (s16)cmd.CMDYC;
   sprite.vertices[6] = (s16)cmd.CMDXD;
   sprite.vertices[7] = (s16)cmd.CMDYD;

   isSquare = 1;
   for (i = 0; i < 3; i++){
	   float dx = sprite.vertices[((i + 1) << 1) + 0] - sprite.vertices[((i + 0) << 1) + 0];
	   float dy = sprite.vertices[((i + 1) << 1) + 1] - sprite.vertices[((i + 0) << 1) + 1];
	   float d2x = sprite.vertices[(((i + 2) & 0x3) << 1) + 0] - sprite.vertices[((i + 1) << 1) + 0];
	   float d2y = sprite.vertices[(((i + 2) & 0x3) << 1) + 1] - sprite.vertices[((i + 1) << 1) + 1];
	   float dot = dx*d2x + dy*d2y;
	   if (dot >= EPSILON || dot <= -EPSILON){
		   isSquare = 0;
		   break;
	   }
   }
   if (isSquare){
	   // find upper left opsition
	   float minx = 65535.0f;
	   float miny = 65535.0f;
	   int lt_index = -1;

	   sprite.dst = 0;

	   for (i = 0; i < 4; i++){
		   if (sprite.vertices[(i << 1) + 0] <= minx && sprite.vertices[(i << 1) + 1] <= miny){
			   minx = sprite.vertices[(i << 1) + 0];
			   miny = sprite.vertices[(i << 1) + 1];
			   lt_index = i;
		   }
	   }

	   for (i = 0; i < 4; i++){
		   if (i != lt_index){
			   // vectorize
			   float dx = sprite.vertices[(i << 1) + 0] - sprite.vertices[((lt_index) << 1) + 0];
			   float dy = sprite.vertices[(i << 1) + 1] - sprite.vertices[((lt_index) << 1) + 1];
			   float nx;
			   float ny;

			   // normalize
			   float len = fabsf(sqrtf(dx*dx + dy*dy));
			   if (len <= EPSILON){
				   continue;
			   }
			   nx = dx / len;
			   ny = dy / len;
			   if (nx >= EPSILON) nx = 1.0f; else nx = 0.0f;
			   if (ny >= EPSILON) ny = 1.0f; else ny = 0.0f;

			   // expand vertex
			   sprite.vertices[(i << 1) + 0] += nx;
			   sprite.vertices[(i << 1) + 1] += ny;
		   }
	   }
   }

   // Line Polygon
   if ( (sprite.vertices[1] == sprite.vertices[3]) &&
	   (sprite.vertices[3]  == sprite.vertices[5]) &&
	   (sprite.vertices[5]  == sprite.vertices[7])) {
	   sprite.vertices[5] += 1;
	   sprite.vertices[7] += 1;
   }

   sprite.vertices[0] = (sprite.vertices[0] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[1] = (sprite.vertices[1] + Vdp1Regs->localY) * vdp1hratio;
   sprite.vertices[2] = (sprite.vertices[2] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[3] = (sprite.vertices[3] + Vdp1Regs->localY) * vdp1hratio;
   sprite.vertices[4] = (sprite.vertices[4] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[5] = (sprite.vertices[5] + Vdp1Regs->localY) * vdp1hratio;
   sprite.vertices[6] = (sprite.vertices[6] + Vdp1Regs->localX) * vdp1wratio;
   sprite.vertices[7] = (sprite.vertices[7] + Vdp1Regs->localY) * vdp1hratio;

   color = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x6);
   CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x4);
   sprite.uclipmode = (CMDPMOD >> 9) & 0x03;


   // Half trans parent to VDP1 Framebuffer
   if( (CMDPMOD & 0x3)==0x03 || (CMDPMOD & 0x100) )
   {
	   sprite.blendmode = 0x80;
   }

   // Check if the Gouraud shading bit is set and the color mode is RGB
   if( (CMDPMOD & 4) )
   {
      for (i=0; i<4; i++)
      {
         color2 = T1ReadWord(Vdp1Ram, (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1C) << 3) + (i << 1));
         col[(i << 2) + 0] = (float)((color2 & 0x001F))/(float)(0x1F)-0.5f;
         col[(i << 2) + 1] = (float)((color2 & 0x03E0)>>5)/(float)(0x1F)-0.5f;
         col[(i << 2) + 2] = (float)((color2 & 0x7C00)>>10)/(float)(0x1F)-0.5f;
         col[(i << 2) + 3] = 1.0f;
      }
      gouraud = 1;
   }

   if (color & 0x8000)
      priority = Vdp2Regs->PRISA & 0x7;
   else
   {
      int shadow, colorcalc;
      priority = 0;  // Avoid compiler warning
      Vdp1ProcessSpritePixel(Vdp2Regs->SPCTL & 0xF, &color, &shadow, &priority, &colorcalc);
#ifdef WORDS_BIGENDIAN
      priority = ((u8 *)&Vdp2Regs->PRISA)[priority^1] & 0x7;
#else
      priority = ((u8 *)&Vdp2Regs->PRISA)[priority] & 0x7;
#endif
   }


   sprite.priority = 8;
   sprite.w = 1;
   sprite.h = 1;
   sprite.flip = 0;
   sprite.cor = 0x00;
   sprite.cog = 0x00;
   sprite.cob = 0x00;



   if (color == 0 || color == 0x8000 )
   {
	  YglQuad(&sprite, &texture, NULL);
      alpha = 0;
      priority = 0;
	  *texture.textdata = 0;
	  return;
   }


   alpha = 0xF8;
   if (gouraud == 1)
   {
	   YglQuadGrowShading(&sprite, &texture, col, NULL);
   }
   else{
	   YglQuadGrowShading(&sprite, &texture, NULL, NULL);
   }

   if (IS_REPLACE(CMDPMOD)){
	   alpha = 0xF8;
   }
   else if (IS_DONOT_DRAW_OR_SHADOW(CMDPMOD)){
	   alpha = 0x00;
   }
   else if (IS_HALF_LUMINANCE(CMDPMOD)){
	   alpha = 0xF8;

   }
   else if (IS_REPLACE_OR_HALF_TRANSPARENT(CMDPMOD)){
	   alpha = 0x80;
   }

   if (IS_MESH(CMDPMOD)){
	   alpha = 0x80;
   }



   if (Vdp2Regs->SDCTL & 0x100 ){
   }

   /*
   if( (CMDPMOD & 0x100) || (CMDPMOD & 0x7) == 0x3)
   {
      alpha = 0x80;
   }
   */


   alpha |= priority;
   if (color & 0x8000){
	   *texture.textdata = SAT2YAB1(alpha, color);
   }else{
	   *texture.textdata = Vdp1ReadPolygonColor(&cmd);
   }
}

//////////////////////////////////////////////////////////////////////////////


static void  makeLinePolygon(s16 *v1, s16 *v2, float *outv){
	float dx;
	float dy;
	float len;
	float nx;
	float ny;
	float ex;
	float ey;
	float offset;

	if (v1[0] == v2[0] && v1[1] == v2[1]){
		outv[0] = v1[0];
		outv[1] = v1[1];
		outv[2] = v2[0];
		outv[3] = v2[1];
		outv[4] = v2[0];
		outv[5] = v2[1];
		outv[6] = v1[0];
		outv[7] = v1[1];
		return;
	}

	// vectorize;
	dx = v2[0] - v1[0];
	dy = v2[1] - v1[1];

	// normalize
	len = fabs( sqrtf((dx*dx) + (dy*dy)) );
	if (len < EPSILON ){
		// fail;
		outv[0] = v1[0];
		outv[1] = v1[1];
		outv[2] = v2[0];
		outv[3] = v2[1];
		outv[4] = v2[0];
		outv[5] = v2[1];
		outv[6] = v1[0];
		outv[7] = v1[1];
		return;
	}

	nx = dx / len;
	ny = dy / len;

	// turn
	dx = ny  * 0.5f;
	dy = -nx * 0.5f;

	// extend
	ex = nx * 0.5f;
	ey = ny * 0.5f;

	// offset
	offset = 0.5f;

	// triangle
	outv[0] = v1[0] - ex - dx + offset;
	outv[1] = v1[1] - ey - dy + offset;
	outv[2] = v1[0] - ex + dx + offset;
	outv[3] = v1[1] - ey + dy + offset;
	outv[4] = v2[0] + ex + dx + offset;
	outv[5] = v2[1] + ey + dy + offset;
	outv[6] = v2[0] + ex - dx + offset;
	outv[7] = v2[1] + ey - dy + offset;


}

void VIDOGLVdp1PolylineDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer)
{
   s16 v[8];
   float line_poygon[8];
   u16 color;
   u16 CMDPMOD;
   u8 alpha;
   YglSprite polygon;
   YglTexture texture;
   YglCache c;
   int priority;
   vdp1cmd_struct cmd;
   float col[4 * 4];
   float linecol[4 * 4];
   int gouraud = 0;
   u16 color2;

   polygon.blendmode=0;
   polygon.linescreen = 0;
   polygon.dst = 0;
   v[0] = Vdp1Regs->localX + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C) );
   v[1] = Vdp1Regs->localY + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E) );
   v[2] = Vdp1Regs->localX + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x10) );
   v[3] = Vdp1Regs->localY + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12) );
   v[4] = Vdp1Regs->localX + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14) );
   v[5] = Vdp1Regs->localY + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16) );
   v[6] = Vdp1Regs->localX + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x18) );
   v[7] = Vdp1Regs->localY + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1A) );

   color = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x6);
   CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x4);
   polygon.uclipmode=(CMDPMOD>>9)&0x03;


   // Half trans parent to VDP1 Framebuffer
   if( (CMDPMOD & 0x3)==0x03 || (CMDPMOD & 0x100) )
   {
      polygon.blendmode = 0x80;
   }

   if (color & 0x8000)
      priority = Vdp2Regs->PRISA & 0x7;
   else
   {
      int shadow, colorcalc;

      priority = 0;  // Avoid compiler warning
      Vdp1ProcessSpritePixel(Vdp2Regs->SPCTL & 0xF, &color, &shadow, &priority, &colorcalc);
#ifdef WORDS_BIGENDIAN
      priority = ((u8 *)&Vdp2Regs->PRISA)[priority^1] & 0x7;
#else
      priority = ((u8 *)&Vdp2Regs->PRISA)[priority] & 0x7;
#endif
   }

   polygon.priority = 8;
   polygon.w = 1;
   polygon.h = 1;
   polygon.flip = 0;

   if ((CMDPMOD & 4))
   {
	   int i;
	   for (i = 0; i<4; i++)
	   {
		   color2 = T1ReadWord(Vdp1Ram, (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1C) << 3) + (i << 1));
		   col[(i << 2) + 0] = (float)((color2 & 0x001F)) / (float)(0x1F) - 0.5f;
		   col[(i << 2) + 1] = (float)((color2 & 0x03E0) >> 5) / (float)(0x1F) - 0.5f;
		   col[(i << 2) + 2] = (float)((color2 & 0x7C00) >> 10) / (float)(0x1F) - 0.5f;
		   col[(i << 2) + 3] = 1.0f;
	   }
	   gouraud = 1;
   }

   makeLinePolygon(&v[0], &v[2], line_poygon);
   polygon.vertices[0] = line_poygon[0] * vdp1wratio;
   polygon.vertices[1] = line_poygon[1] * vdp1hratio;
   polygon.vertices[2] = line_poygon[2] * vdp1wratio;
   polygon.vertices[3] = line_poygon[3] * vdp1hratio;
   polygon.vertices[4] = line_poygon[4] * vdp1wratio;
   polygon.vertices[5] = line_poygon[5] * vdp1hratio;
   polygon.vertices[6] = line_poygon[6] * vdp1wratio;
   polygon.vertices[7] = line_poygon[7] * vdp1hratio;

   if (gouraud){
	   linecol[0] = col[(0 << 2) + 0];
	   linecol[1] = col[(0 << 2) + 1];
	   linecol[2] = col[(0 << 2) + 2];
	   linecol[3] = col[(0 << 2) + 3];
	   linecol[4] = col[(0 << 2) + 0];
	   linecol[5] = col[(0 << 2) + 1];
	   linecol[6] = col[(0 << 2) + 2];
	   linecol[7] = col[(0 << 2) + 3];
	   linecol[8] = col[(1 << 2) + 0];
	   linecol[9] = col[(1 << 2) + 1];
	   linecol[10] = col[(1 << 2) + 2];
	   linecol[11] = col[(1 << 2) + 3];
	   linecol[12] = col[(1 << 2) + 0];
	   linecol[13] = col[(1 << 2) + 1];
	   linecol[14] = col[(1 << 2) + 2];
	   linecol[15] = col[(1 << 2) + 3];
	   YglQuadGrowShading(&polygon, &texture, linecol, &c);
   }
   else{
	   YglQuadGrowShading(&polygon, &texture, NULL, &c);
   }

   if (color == 0)
   {
	   alpha = 0;
	   priority = 0;
   }
   else{
	   alpha = 0xF8;
	   if (CMDPMOD & 0x100)
	   {
		   alpha = 0x80;
	   }
   }

   alpha |= priority;

   if (color & 0x8000)
	   *texture.textdata = SAT2YAB1(alpha, color);
   else{
      Vdp1ReadCommand(&cmd, Vdp1Regs->addr, Vdp1Ram);
	   *texture.textdata = Vdp1ReadPolygonColor(&cmd);
   }

   makeLinePolygon(&v[2], &v[4], line_poygon);
   polygon.vertices[0] = line_poygon[0] * vdp1wratio;
   polygon.vertices[1] = line_poygon[1] * vdp1hratio;
   polygon.vertices[2] = line_poygon[2] * vdp1wratio;
   polygon.vertices[3] = line_poygon[3] * vdp1hratio;
   polygon.vertices[4] = line_poygon[4] * vdp1wratio;
   polygon.vertices[5] = line_poygon[5] * vdp1hratio;
   polygon.vertices[6] = line_poygon[6] * vdp1wratio;
   polygon.vertices[7] = line_poygon[7] * vdp1hratio;
   if (gouraud){
	   linecol[0] = col[(1 << 2) + 0];
	   linecol[1] = col[(1 << 2) + 1];
	   linecol[2] = col[(1 << 2) + 2];
	   linecol[3] = col[(1 << 2) + 3];

	   linecol[4] = col[(1 << 2) + 0];
	   linecol[5] = col[(1 << 2) + 1];
	   linecol[6] = col[(1 << 2) + 2];
	   linecol[7] = col[(1 << 2) + 3];

	   linecol[8]  = col[(2 << 2) + 0];
	   linecol[9]  = col[(2 << 2) + 1];
	   linecol[10] = col[(2 << 2) + 2];
	   linecol[11] = col[(2 << 2) + 3];

	   linecol[12] = col[(2 << 2) + 0];
	   linecol[13] = col[(2 << 2) + 1];
	   linecol[14] = col[(2 << 2) + 2];
	   linecol[15] = col[(2 << 2) + 3];

	   YglCacheQuadGrowShading(&polygon, linecol, &c);
   }
   else{
	   YglCacheQuadGrowShading(&polygon, NULL, &c);
   }

   makeLinePolygon(&v[4], &v[6], line_poygon);
   polygon.vertices[0] = line_poygon[0] * vdp1wratio;
   polygon.vertices[1] = line_poygon[1] * vdp1hratio;
   polygon.vertices[2] = line_poygon[2] * vdp1wratio;
   polygon.vertices[3] = line_poygon[3] * vdp1hratio;
   polygon.vertices[4] = line_poygon[4] * vdp1wratio;
   polygon.vertices[5] = line_poygon[5] * vdp1hratio;
   polygon.vertices[6] = line_poygon[6] * vdp1wratio;
   polygon.vertices[7] = line_poygon[7] * vdp1hratio;
   if (gouraud){
	   linecol[0] = col[(2 << 2) + 0];
	   linecol[1] = col[(2 << 2) + 1];
	   linecol[2] = col[(2 << 2) + 2];
	   linecol[3] = col[(2 << 2) + 3];
	   linecol[4] = col[(2 << 2) + 0];
	   linecol[5] = col[(2 << 2) + 1];
	   linecol[6] = col[(2 << 2) + 2];
	   linecol[7] = col[(2 << 2) + 3];
	   linecol[8] = col[(3 << 2) + 0];
	   linecol[9] = col[(3 << 2) + 1];
	   linecol[10] = col[(3 << 2) + 2];
	   linecol[11] = col[(3 << 2) + 3];
	   linecol[12] = col[(3 << 2) + 0];
	   linecol[13] = col[(3 << 2) + 1];
	   linecol[14] = col[(3 << 2) + 2];
	   linecol[15] = col[(3 << 2) + 3];
	   YglCacheQuadGrowShading(&polygon, linecol, &c);
   }
   else{
	   YglCacheQuadGrowShading(&polygon, NULL, &c);
   }


   if ( !(v[6] == v[0] && v[7] == v[1]) ){
	   makeLinePolygon(&v[6], &v[0], line_poygon);
	   polygon.vertices[0] = line_poygon[0] * vdp1wratio;
	   polygon.vertices[1] = line_poygon[1] * vdp1hratio;
	   polygon.vertices[2] = line_poygon[2] * vdp1wratio;
	   polygon.vertices[3] = line_poygon[3] * vdp1hratio;
	   polygon.vertices[4] = line_poygon[4] * vdp1wratio;
	   polygon.vertices[5] = line_poygon[5] * vdp1hratio;
	   polygon.vertices[6] = line_poygon[6] * vdp1wratio;
	   polygon.vertices[7] = line_poygon[7] * vdp1hratio;
	   if (gouraud){
		   linecol[0] = col[(3 << 2) + 0];
		   linecol[1] = col[(3 << 2) + 1];
		   linecol[2] = col[(3 << 2) + 2];
		   linecol[3] = col[(3 << 2) + 3];
		   linecol[4] = col[(3 << 2) + 0];
		   linecol[5] = col[(3 << 2) + 1];
		   linecol[6] = col[(3 << 2) + 2];
		   linecol[7] = col[(3 << 2) + 3];
		   linecol[8] = col[(0 << 2) + 0];
		   linecol[9] = col[(0 << 2) + 1];
		   linecol[10] = col[(0 << 2) + 2];
		   linecol[11] = col[(0 << 2) + 3];
		   linecol[12] = col[(0 << 2) + 0];
		   linecol[13] = col[(0 << 2) + 1];
		   linecol[14] = col[(0 << 2) + 2];
		   linecol[15] = col[(0 << 2) + 3];
		   YglCacheQuadGrowShading(&polygon, linecol, &c);
	   }
	   else{
		   YglCacheQuadGrowShading(&polygon, NULL, &c);
	   }
   }


}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1LineDraw(u8 * ram, Vdp1 * regs, u8* back_framebuffer)
{
   s16 v[4];
   u16 color;
   u16 CMDPMOD;
   u8 alpha;
   YglSprite polygon;
   YglTexture texture;
   int priority;
   float line_poygon[8];
   vdp1cmd_struct cmd;
   float col[4 * 2];
   int gouraud = 0;
   u16 color2;

   polygon.blendmode=0;
   polygon.linescreen = 0;
   polygon.dst = 0;
   v[0] = Vdp1Regs->localX + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0C));
   v[1] = Vdp1Regs->localY + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x0E));
   v[2] = Vdp1Regs->localX + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x10));
   v[3] = Vdp1Regs->localY + (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x12));

   color = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x6);
   CMDPMOD = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x4);
   polygon.uclipmode=(CMDPMOD>>9)&0x03;

   // Half trans parent to VDP1 Framebuffer
   if( (CMDPMOD & 0x3)==0x03 || (CMDPMOD & 0x100) )
   {
      polygon.blendmode = 0x80;
   }

   if (color & 0x8000)
      priority = Vdp2Regs->PRISA & 0x7;
   else
   {
      int shadow, colorcalc;

      priority = 0;  // Avoid compiler warning
      Vdp1ProcessSpritePixel(Vdp2Regs->SPCTL & 0xF, &color, &shadow, &priority, &colorcalc);
#ifdef WORDS_BIGENDIAN
      priority = ((u8 *)&Vdp2Regs->PRISA)[priority^1] & 0x7;
#else
      priority = ((u8 *)&Vdp2Regs->PRISA)[priority] & 0x7;
#endif
   }

   polygon.priority = 8;

   // Check if the Gouraud shading bit is set and the color mode is RGB
   if ((CMDPMOD & 4))
   {
	   int i;
	   for (i = 0; i<2; i++)
	   {
		   color2 = T1ReadWord(Vdp1Ram, (T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x1C) << 3) + (i << 1));
		   col[(i << 2) + 0] = (float)((color2 & 0x001F)) / (float)(0x1F) - 0.5f;
		   col[(i << 2) + 1] = (float)((color2 & 0x03E0) >> 5) / (float)(0x1F) - 0.5f;
		   col[(i << 2) + 2] = (float)((color2 & 0x7C00) >> 10) / (float)(0x1F) - 0.5f;
		   col[(i << 2) + 3] = 1.0f;
	   }
	   gouraud = 1;
   }


   makeLinePolygon(&v[0], &v[2], line_poygon);
   polygon.vertices[0] = line_poygon[0] * vdp1wratio;
   polygon.vertices[1] = line_poygon[1] * vdp1hratio;
   polygon.vertices[2] = line_poygon[2] * vdp1wratio;
   polygon.vertices[3] = line_poygon[3] * vdp1hratio;
   polygon.vertices[4] = line_poygon[4] * vdp1wratio;
   polygon.vertices[5] = line_poygon[5] * vdp1hratio;
   polygon.vertices[6] = line_poygon[6] * vdp1wratio;
   polygon.vertices[7] = line_poygon[7] * vdp1hratio;

   polygon.w = 1;
   polygon.h = 1;
   polygon.flip = 0;

   if (gouraud == 1){
	   YglQuadGrowShading(&polygon, &texture, col, NULL);
   }
   else{
	   YglQuadGrowShading(&polygon, &texture, NULL, NULL);
   }

   if (color == 0)
   {
      alpha = 0;
      priority = 0;
   }else{
      alpha = 0xF8;
      if (CMDPMOD & 0x100)
      {
         alpha = 0x80;
      }
   }
   alpha |= priority;



   if (color & 0x8000)
      *texture.textdata = SAT2YAB1(alpha,color);
   else{
      Vdp1ReadCommand(&cmd, Vdp1Regs->addr, Vdp1Ram);
	   *texture.textdata = Vdp1ReadPolygonColor(&cmd);
   }
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1UserClipping(u8 * ram, Vdp1 * regs)
{
   Vdp1Regs->userclipX1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xC);
   Vdp1Regs->userclipY1 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xE);
   Vdp1Regs->userclipX2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
   Vdp1Regs->userclipY2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1SystemClipping(u8 * ram, Vdp1 * regs)
{
   Vdp1Regs->systemclipX1 = 0;
   Vdp1Regs->systemclipY1 = 0;
   Vdp1Regs->systemclipX2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x14);
   Vdp1Regs->systemclipY2 = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0x16);
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp1LocalCoordinate(u8 * ram, Vdp1 * regs)
{
   Vdp1Regs->localX = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xC);
   Vdp1Regs->localY = T1ReadWord(Vdp1Ram, Vdp1Regs->addr + 0xE);
}

//////////////////////////////////////////////////////////////////////////////

int VIDOGLVdp2Reset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp2DrawStart(void)
{
   YglReset();
   YglCacheReset();
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp2DrawEnd(void)
{
   YglRender();
   /* It would be better to reset manualchange in a Vdp1SwapFrameBuffer
   function that would be called here and during a manual change */
   //Vdp1External.manualchange = 0;
}

//////////////////////////////////////////////////////////////////////////////



static void Vdp2DrawBackScreen(void)
{
   u32 scrAddr;
   int dot;

   static unsigned char lineColors[512 * 3];
   static int line[512*4];

   if (Vdp2Regs->VRSIZE & 0x8000)
	   scrAddr = (((Vdp2Regs->BKTAU & 0x7) << 16) | Vdp2Regs->BKTAL) * 2;
   else
	   scrAddr = (((Vdp2Regs->BKTAU & 0x3) << 16) | Vdp2Regs->BKTAL) * 2;

#if defined(__ANDROID__) || defined(_OGLES3_) || defined(_OGL3_)
   dot = T1ReadWord(Vdp2Ram, scrAddr);
   YglSetClearColor(
	   (float)(dot & 0x1F) / (float)(0x1F),
	   (float)((dot & 0x3E0) >> 5) / (float)(0x1F),
	   (float)((dot & 0x7C00) >> 10)/ (float)(0x1F)
	   );
#else
   if (Vdp2Regs->BKTAU & 0x8000)
   {
		int y;

      for(y = 0; y < vdp2height; y++)
      {
         dot = T1ReadWord(Vdp2Ram, scrAddr);
         scrAddr += 2;

         lineColors[3*y+0] = (dot & 0x1F) << 3;
         lineColors[3*y+1] = (dot & 0x3E0) >> 2;
         lineColors[3*y+2] = (dot & 0x7C00) >> 7;
         line[4*y+0] = 0;
         line[4*y+1] = y;
         line[4*y+2] = vdp2width;
         line[4*y+3] = y;
      }

      glColorPointer(3, GL_UNSIGNED_BYTE, 0, lineColors);
      glEnableClientState(GL_COLOR_ARRAY);
      glVertexPointer(2, GL_INT, 0, line);
      glEnableClientState(GL_VERTEX_ARRAY);
      glDrawArrays(GL_LINES,0,vdp2height*2);
      glDisableClientState(GL_COLOR_ARRAY);
      glColor3ub(0xFF, 0xFF, 0xFF);
   }
   else
   {
      dot = T1ReadWord(Vdp2Ram, scrAddr);

      glColor3ub((dot & 0x1F) << 3, (dot & 0x3E0) >> 2, (dot & 0x7C00) >> 7);

      line[0] = 0;
      line[1] = 0;
      line[2] = vdp2width;
      line[3] = 0;
      line[4] = vdp2width;
      line[5] = vdp2height;
      line[6] = 0;
      line[7] = vdp2height;

      glDisable(GL_TEXTURE_2D);
      glVertexPointer(2, GL_INT, 0, line);
      glEnableClientState(GL_VERTEX_ARRAY);
      glDisableClientState(GL_TEXTURE_COORD_ARRAY);
      glDrawArrays(GL_TRIANGLE_FAN,0,8);
      glColor3ub(0xFF, 0xFF, 0xFF);
      glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   }
#endif
}

//////////////////////////////////////////////////////////////////////////////
// 11.3 Line Color insertion
//  7.1 Line Color Screen
static void Vdp2DrawLineColorScreen(void)
{

  u32 cacheaddr = 0xFFFFFFFF;
  int inc = 0;
  int line_cnt = vdp2height;
  int i;
  u32 * line_pixel_data;
  u32 addr;

  if ( Vdp2Regs->LNCLEN == 0) return;

  line_pixel_data = YglGetLineColorPointer();
  if( line_pixel_data == NULL ){
      return;
  }

  if ((Vdp2Regs->LCTA.part.U & 0x8000)){
    inc = 0x02; // single color
  } else{
    inc = 0x00; // color per line
  }

  addr = (Vdp2Regs->LCTA.all & 0x7FFFF) * 0x2;
  for (i = 0; i < line_cnt; i++){

    u16 LineColorRamAdress = T1ReadWord(Vdp2Ram, addr);
    *(line_pixel_data) = Vdp2ColorRamGetColor(LineColorRamAdress, 0xFF);
    line_pixel_data++;
    addr += inc;
  }

  YglSetLineColor( line_pixel_data, line_cnt );

}


//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG0(void)
{
   vdp2draw_struct info;
   YglTexture texture;
   YglCache tmpc;
   vdp2rotationparameter_struct parameter;
   info.dst=0;
   info.uclipmode=0;

   info.coordincx = 1.0f;
   info.coordincy = 1.0f;

   info.cor = 0;
   info.cog = 0;
   info.cob = 0;


   if (Vdp2Regs->BGON & 0x20)
   {
      // RBG1 mode
      info.enable = Vdp2Regs->BGON & 0x20;

      // Read in Parameter B
      Vdp2ReadRotationTable(1, &parameter, Vdp2Regs, Vdp2Ram);

      if((info.isbitmap = Vdp2Regs->CHCTLA & 0x2) != 0)
      {
         // Bitmap Mode

         ReadBitmapSize(&info, Vdp2Regs->CHCTLA >> 2, 0x3);

         info.charaddr = (Vdp2Regs->MPOFR & 0x70) * 0x2000;
         info.paladdr = (Vdp2Regs->BMPNA & 0x7) << 4;
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
      info.PlaneAddr = (void FASTCALL (*)(void *, int, Vdp2*))&Vdp2ParameterBPlaneAddr;
      parameter.coefenab = Vdp2Regs->KTCTL & 0x100;

      info.LineColorBase = 0x00;
      if (paraB.coefenab)
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode01WithK;
      else
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode01NoK;
   }
   else if (Vdp2Regs->BGON & 0x1)
   {
      // NBG0 mode
      info.enable = Vdp2Regs->BGON & 0x1;

      if((info.isbitmap = Vdp2Regs->CHCTLA & 0x2) != 0)
      {
         // Bitmap Mode

         ReadBitmapSize(&info, Vdp2Regs->CHCTLA >> 2, 0x3);

         info.x = - ((Vdp2Regs->SCXIN0 & 0x7FF) % info.cellw);
         info.y = - ((Vdp2Regs->SCYIN0 & 0x7FF) % info.cellh);

         info.charaddr = (Vdp2Regs->MPOFN & 0x7) * 0x20000;
         info.paladdr = (Vdp2Regs->BMPNA & 0x7) << 4;
         info.flipfunction = 0;
         info.specialfunction = 0;
      }
      else
      {
         // Tile Mode
         info.mapwh = 2;

         ReadPlaneSize(&info, Vdp2Regs->PLSZ);

         info.x = - ((Vdp2Regs->SCXIN0 & 0x7FF) % (512 * info.planew));
         info.y = - ((Vdp2Regs->SCYIN0 & 0x7FF) % (512 * info.planeh));
         ReadPatternData(&info, Vdp2Regs->PNCN0, Vdp2Regs->CHCTLA & 0x1);
      }

      if( (Vdp2Regs->ZMXN0.all & 0x7FF00) == 0 )
         info.coordincx = 1.0f;
      else
         info.coordincx = (float) 65536 / (Vdp2Regs->ZMXN0.all & 0x7FF00);

      switch(Vdp2Regs->ZMCTL&0x03)
      {
      case 0:
		  info.maxzoom = 1.0f;
         break;
      case 1:
		  info.maxzoom = 0.5f;
         if( info.coordincx < 0.5f )  info.coordincx = 0.5f;
         break;
      case 2:
      case 3:
		  info.maxzoom = 0.25f;
         if( info.coordincx < 0.25f )  info.coordincx = 0.25f;
         break;
      }

      if( (Vdp2Regs->ZMYN0.all & 0x7FF00) == 0 )
         info.coordincy = 1.0f;
      else
         info.coordincy = (float) 65536 / (Vdp2Regs->ZMYN0.all & 0x7FF00);

      info.PlaneAddr = (void FASTCALL(*)(void *, int, Vdp2*))&Vdp2NBG0PlaneAddr;
   }
   else
      // Not enabled
      return;

   info.transparencyenable = !(Vdp2Regs->BGON & 0x100);
   info.specialprimode   = Vdp2Regs->SFPRMD & 0x3;
   info.specialcolormode = Vdp2Regs->SFCCMD & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLA & 0x70) >> 4;


   if(Vdp2Regs->CCCTL & 0x1)
   {
      info.alpha = ((~Vdp2Regs->CCRNA & 0x1F) << 3) + 0x7;
      if(Vdp2Regs->CCCTL & 0x100 && info.specialcolormode == 0)
         info.blendmode=2;
      else
         info.blendmode=1;
   }else{
      info.alpha = 0xFF;
      info.blendmode=0;
   }

   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x1)
     info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7) << 8;
   ReadVdp2ColorOffset(Vdp2Regs,&info, 0x1);
   info.linecheck_mask = 0x01;
   info.priority = Vdp2Regs->PRINA & 0x7;

   if (!(info.enable & Vdp2External.disptoggle) || (info.priority == 0))
      return;

   // Window Mode
   info.bEnWin0 = (Vdp2Regs->WCTLA >> 1) &0x01;
   info.WindowArea0 = (Vdp2Regs->WCTLA >> 0) & 0x01;
   info.bEnWin1 = (Vdp2Regs->WCTLA >> 3) &0x01;
   info.WindowArea1 = (Vdp2Regs->WCTLA >> 2) & 0x01;
   info.LogicWin    = (Vdp2Regs->WCTLA >> 7 ) & 0x01;


   if( info.bEnWin0 || info.bEnWin1 )
      YglStartWindow(&info,info.bEnWin0, info.WindowArea0,info.bEnWin1, info.WindowArea1,info.LogicWin);

   ReadLineScrollData(&info, Vdp2Regs->SCRCTL & 0xFF, Vdp2Regs->LSTA0.all);
   info.lineinfo = lineNBG0;
   Vdp2GenLineinfo( &info );
   Vdp2SetGetColor( &info );

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

   if (info.enable == 1)
   {
      // NBG0 draw
      if (info.isbitmap)
      {
         int xx,yy;
         int isCached = 0;

         if(info.islinescroll) // Nights Movie
         {
            info.sh = (Vdp2Regs->SCXIN0 & 0x7FF);
            info.sv = (Vdp2Regs->SCYIN0 & 0x7FF);
            info.x = 0;
            info.y = 0;
         }

         yy = info.y;
         while( yy < vdp2height )
         {
            xx = info.x;
            while( xx < vdp2width )
            {
               info.vertices[0] = xx * info.coordincx;
               info.vertices[1] = yy * info.coordincy;
               info.vertices[2] = (xx + info.cellw) * info.coordincx;
               info.vertices[3] = yy * info.coordincy;
               info.vertices[4] = (xx + info.cellw) * info.coordincx;
               info.vertices[5] = (yy + info.cellh) * info.coordincy;
               info.vertices[6] = xx * info.coordincx;
               info.vertices[7] = (yy + info.cellh) * info.coordincy;

               if( isCached == 0 )
               {
                  YglQuad((YglSprite *)&info, &texture,&tmpc);
                  Vdp2DrawCell(&info, &texture);
                  isCached = 1;
               }else{
                  YglCachedQuad((YglSprite *)&info, &tmpc);
               }
               xx += info.cellw* info.coordincx;
            }
            yy += info.cellh* info.coordincy;
         }

      }
      else
      {
		  if (info.islinescroll){
			  info.x = Vdp2Regs->SCXIN0 & 0x7FF;
			  info.y = Vdp2Regs->SCYIN0 & 0x7FF;
			  Vdp2DrawMapPerLine(&info, &texture);
		  }
		  else{
			  info.x = Vdp2Regs->SCXIN0 & 0x7FF;
			  info.y = Vdp2Regs->SCYIN0 & 0x7FF;
			  Vdp2DrawMapTest(&info, &texture);
		  }
      }
   }
   else
   {
      // RBG1 draw
      Vdp2DrawRotation(&info, &parameter, &texture);
   }

   if( info.bEnWin0 || info.bEnWin1 )
      YglEndWindow(&info);

}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG1(void)
{
   vdp2draw_struct info;
   YglTexture texture;
   YglCache tmpc;
   info.dst=0;
   info.uclipmode=0;
   info.cor = 0;
   info.cog = 0;
   info.cob = 0;

   info.enable = Vdp2Regs->BGON & 0x2;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x200);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 2) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLA & 0x3000) >> 12;

   if((info.isbitmap = Vdp2Regs->CHCTLA & 0x200) != 0)
   {
      ReadBitmapSize(&info, Vdp2Regs->CHCTLA >> 10, 0x3);

      info.x = -((Vdp2Regs->SCXIN1 & 0x7FF) % info.cellw);
      info.y = -((Vdp2Regs->SCYIN1 & 0x7FF) % info.cellh);
      info.charaddr = ((Vdp2Regs->MPOFN & 0x70) >> 4) * 0x20000;
      info.paladdr = (Vdp2Regs->BMPNA & 0x700) >> 4;
      info.flipfunction = 0;
      info.specialfunction = 0;
   }
   else
   {
      info.mapwh = 2;

      ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 2);

      info.x = - ((Vdp2Regs->SCXIN1 & 0x7FF) % (512 * info.planew));
      info.y = - ((Vdp2Regs->SCYIN1 & 0x7FF) % (512 * info.planeh));

      ReadPatternData(&info, Vdp2Regs->PNCN1, Vdp2Regs->CHCTLA & 0x100);
   }

   info.specialcolormode = (Vdp2Regs->SFCCMD>>2) & 0x3;

   if (Vdp2Regs->CCCTL & 0x2)
   {
      info.alpha = ((~Vdp2Regs->CCRNA & 0x1F00) >> 5) + 0x7;
      if(Vdp2Regs->CCCTL & 0x100 && info.specialcolormode == 0 )
      {
         info.blendmode=2;
      }else{
         info.blendmode=1;
      }
   }else{
      info.alpha = 0xFF;
      info.blendmode=0;
   }

   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x2)
     info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x70) << 4;
   ReadVdp2ColorOffset(Vdp2Regs,&info, 0x2);
   info.linecheck_mask = 0x02;

   if( (Vdp2Regs->ZMXN1.all & 0x7FF00) == 0 )
      info.coordincx = 1.0f;
   else
      info.coordincx = (float) 65536 / (Vdp2Regs->ZMXN1.all & 0x7FF00);

   switch((Vdp2Regs->ZMCTL>>8)&0x03)
   {
   case 0:
		info.maxzoom = 1.0f;
      break;
   case 1:
	   info.maxzoom = 0.5f;
      if( info.coordincx < 0.5f )  info.coordincx = 0.5f;
      break;
   case 2:
   case 3:
	   info.maxzoom = 0.25f;
      if( info.coordincx < 0.25f )  info.coordincx = 0.25f;
      break;
   }

   if( (Vdp2Regs->ZMYN1.all & 0x7FF00) == 0 )
      info.coordincy = 1.0f;
   else
      info.coordincy = (float) 65536 / (Vdp2Regs->ZMYN1.all & 0x7FF00);


   info.priority = (Vdp2Regs->PRINA >> 8) & 0x7;;
   info.PlaneAddr = (void FASTCALL(*)(void *, int, Vdp2*))&Vdp2NBG1PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle) || (info.priority == 0) ||
      (Vdp2Regs->BGON & 0x1 && (Vdp2Regs->CHCTLA & 0x70) >> 4 == 4)) // If NBG0 16M mode is enabled, don't draw
      return;

   // Window Mode
   info.bEnWin0 = (Vdp2Regs->WCTLA >> 9) &0x01;
   info.WindowArea0 = (Vdp2Regs->WCTLA >> 8) & 0x01;
   info.bEnWin1 = (Vdp2Regs->WCTLA >> 11) &0x01;
   info.WindowArea1 = (Vdp2Regs->WCTLA >> 10) & 0x01;
   info.LogicWin    = (Vdp2Regs->WCTLA >> 15 ) & 0x01;

   if( info.bEnWin0 || info.bEnWin1 )
      YglStartWindow(&info,info.bEnWin0, info.WindowArea0,info.bEnWin1, info.WindowArea1,info.LogicWin);

   ReadLineScrollData(&info, Vdp2Regs->SCRCTL >> 8, Vdp2Regs->LSTA1.all);
   info.lineinfo = lineNBG1;
   Vdp2GenLineinfo( &info );
   Vdp2SetGetColor( &info );

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


   if (info.isbitmap)
   {
      int xx,yy;
      int isCached = 0;
      if(info.islinescroll)
      {
          info.sh = (Vdp2Regs->SCXIN1 & 0x7FF);
          info.sv = (Vdp2Regs->SCYIN1 & 0x7FF);
          info.x = 0;
          info.y = 0;
      }

      yy = info.y;
      while( yy < vdp2height )
      {
         xx = info.x;
         while( xx < vdp2width )
         {
            info.vertices[0] = xx * info.coordincx;
            info.vertices[1] = yy * info.coordincy;
            info.vertices[2] = (xx + info.cellw) * info.coordincx;
            info.vertices[3] = yy * info.coordincy;
            info.vertices[4] = (xx + info.cellw) * info.coordincx;
            info.vertices[5] = (yy + info.cellh) * info.coordincy;
            info.vertices[6] = xx * info.coordincx;
            info.vertices[7] = (yy + info.cellh) * info.coordincy;

            if( isCached == 0 )
            {
               YglQuad((YglSprite *)&info, &texture,&tmpc);
               Vdp2DrawCell(&info, &texture);
               isCached = 1;
            }else{
               YglCachedQuad((YglSprite *)&info, &tmpc);
            }
            xx += info.cellw* info.coordincx;
         }
         yy += info.cellh* info.coordincy;
      }

   }
   else{
	   if (info.islinescroll){
		   info.x = (Vdp2Regs->SCXIN1 & 0x7FF);
		   info.y = (Vdp2Regs->SCYIN1 & 0x7FF);
		   Vdp2DrawMapPerLine(&info, &texture);
	   }
	   else{
		   //Vdp2DrawMap(&info, &texture);
		   info.x = Vdp2Regs->SCXIN1 & 0x7FF;
		   info.y = Vdp2Regs->SCYIN1 & 0x7FF;
		   Vdp2DrawMapTest(&info, &texture);
	   }
   }

   if( info.bEnWin0 || info.bEnWin1 )
      YglEndWindow(&info);
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG2(void)
{
   vdp2draw_struct info;
   YglTexture texture;
   info.dst=0;
   info.uclipmode=0;
   info.cor = 0;
   info.cog = 0;
   info.cob = 0;

   info.enable = Vdp2Regs->BGON & 0x4;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x400);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 4) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x2) >> 1;
   info.mapwh = 2;

   ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 4);
   info.x = - ((Vdp2Regs->SCXN2 & 0x7FF) % (512 * info.planew));
   info.y = - ((Vdp2Regs->SCYN2 & 0x7FF) % (512 * info.planeh));
   ReadPatternData(&info, Vdp2Regs->PNCN2, Vdp2Regs->CHCTLB & 0x1);

   info.specialcolormode = (Vdp2Regs->SFCCMD>>4) & 0x3;

   if (Vdp2Regs->CCCTL & 0x4)
   {
      info.alpha = ((~Vdp2Regs->CCRNB & 0x1F) << 3) + 0x7;
      if(Vdp2Regs->CCCTL & 0x100 && info.specialcolormode == 0 )
      {
         info.blendmode=2;
      }else{
         info.blendmode=1;
      }
   }else{
      info.alpha = 0xFF;
      info.blendmode=0;
   }

   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x4)
     info.linescreen = 1;

   info.coloroffset = Vdp2Regs->CRAOFA & 0x700;
   ReadVdp2ColorOffset(Vdp2Regs,&info, 0x4);
   info.linecheck_mask = 0x04;
   info.coordincx = info.coordincy = 1;

   info.priority = Vdp2Regs->PRINB & 0x7;;
   info.PlaneAddr = (void FASTCALL(*)(void *, int, Vdp2*))&Vdp2NBG2PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle) || (info.priority == 0) ||
      (Vdp2Regs->BGON & 0x1 && (Vdp2Regs->CHCTLA & 0x70) >> 4 >= 2)) // If NBG0 2048/32786/16M mode is enabled, don't draw
      return;

   // Window Mode
   info.bEnWin0 = (Vdp2Regs->WCTLB >> 1) &0x01;
   info.WindowArea0 = (Vdp2Regs->WCTLB >> 0) & 0x01;
   info.bEnWin1 = (Vdp2Regs->WCTLB >> 3) &0x01;
   info.WindowArea1 = (Vdp2Regs->WCTLB >> 2) & 0x01;
   info.LogicWin    = (Vdp2Regs->WCTLB >> 7 ) & 0x01;

   Vdp2SetGetColor( &info );

   if( info.bEnWin0 || info.bEnWin1 )
      YglStartWindow(&info,info.bEnWin0, info.WindowArea0,info.bEnWin1, info.WindowArea1,info.LogicWin);

   info.islinescroll = 0;
   info.linescrolltbl = 0;
   info.lineinc = 0;
   info.isverticalscroll = 0;
   info.x = Vdp2Regs->SCXN2 & 0x7FF;
   info.y = Vdp2Regs->SCYN2 & 0x7FF;
   Vdp2DrawMapTest(&info, &texture);

   if( info.bEnWin0 || info.bEnWin1 )
      YglEndWindow(&info);
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawNBG3(void)
{
   vdp2draw_struct info;
   YglTexture texture;
   info.dst=0;
   info.uclipmode=0;
   info.cor = 0;
   info.cog = 0;
   info.cob = 0;

   info.enable = Vdp2Regs->BGON & 0x8;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x800);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 6) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x20) >> 5;

   info.mapwh = 2;

   ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 6);
   info.x = - ((Vdp2Regs->SCXN3 & 0x7FF) % (512 * info.planew));
   info.y = - ((Vdp2Regs->SCYN3 & 0x7FF) % (512 * info.planeh));
   ReadPatternData(&info, Vdp2Regs->PNCN3, Vdp2Regs->CHCTLB & 0x10);

   info.specialcolormode = (Vdp2Regs->SFCCMD>>6) & 0x03;

   if (Vdp2Regs->CCCTL & 0x8)
   {
      info.alpha = ((~Vdp2Regs->CCRNB & 0x1F00) >> 5) + 0x7;
      if(Vdp2Regs->CCCTL & 0x100 && info.specialcolormode == 0 )
      {
         info.blendmode=2;
      }else{
         info.blendmode=1;
      }
   }else{
      info.alpha = 0xFF;
      info.blendmode=0;
   }

   info.linescreen = 0;
   if (Vdp2Regs->LNCLEN & 0x8)
     info.linescreen = 1;

   info.coloroffset = (Vdp2Regs->CRAOFA & 0x7000) >> 4;
   ReadVdp2ColorOffset(Vdp2Regs,&info, 0x8);
   info.linecheck_mask = 0x08;
   info.coordincx = info.coordincy = 1;

   info.priority = (Vdp2Regs->PRINB >> 8) & 0x7;
   info.PlaneAddr = (void FASTCALL (*)(void *, int, Vdp2*))&Vdp2NBG3PlaneAddr;

   if (!(info.enable & Vdp2External.disptoggle) || (info.priority == 0) ||
      (Vdp2Regs->BGON & 0x1 && (Vdp2Regs->CHCTLA & 0x70) >> 4 == 4) || // If NBG0 16M mode is enabled, don't draw
      (Vdp2Regs->BGON & 0x2 && (Vdp2Regs->CHCTLA & 0x3000) >> 12 >= 2)) // If NBG1 2048/32786 is enabled, don't draw
      return;

   // Window Mode
   info.bEnWin0 = (Vdp2Regs->WCTLB >> 9) &0x01;
   info.WindowArea0 = (Vdp2Regs->WCTLB >> 8) & 0x01;
   info.bEnWin1 = (Vdp2Regs->WCTLB >> 11) &0x01;
   info.WindowArea1 = (Vdp2Regs->WCTLB >> 10) & 0x01;
   info.LogicWin    = (Vdp2Regs->WCTLB >> 15 ) & 0x01;

   Vdp2SetGetColor( &info );

   if( info.bEnWin0 || info.bEnWin1 )
      YglStartWindow(&info,info.bEnWin0, info.WindowArea0,info.bEnWin1, info.WindowArea1,info.LogicWin);

   info.islinescroll = 0;
   info.linescrolltbl = 0;
   info.lineinc = 0;
   info.isverticalscroll = 0;
   info.x = Vdp2Regs->SCXN3 & 0x7FF;
   info.y = Vdp2Regs->SCYN3 & 0x7FF;
   Vdp2DrawMapTest(&info, &texture);

   if( info.bEnWin0 || info.bEnWin1 )
      YglEndWindow(&info);
}

//////////////////////////////////////////////////////////////////////////////

static void Vdp2DrawRBG0(void)
{
   vdp2draw_struct info;
   YglTexture texture;
   vdp2rotationparameter_struct parameter;
   info.dst=0;
   info.uclipmode=0;
   info.cor = 0;
   info.cog = 0;
   info.cob = 0;

   info.enable = Vdp2Regs->BGON & 0x10;
   info.priority = Vdp2Regs->PRIR & 0x7;
   if (!(info.enable & Vdp2External.disptoggle) || (info.priority == 0))
      return;
   info.transparencyenable = !(Vdp2Regs->BGON & 0x1000);
   info.specialprimode = (Vdp2Regs->SFPRMD >> 8) & 0x3;

   info.colornumber = (Vdp2Regs->CHCTLB & 0x7000) >> 12;

   info.bEnWin0     = (Vdp2Regs->WCTLC >> 1) & 0x01;
   info.WindowArea0 = (Vdp2Regs->WCTLC >> 0) & 0x01;

   info.bEnWin1     = (Vdp2Regs->WCTLC >> 3) & 0x01;
   info.WindowArea1 = (Vdp2Regs->WCTLC >> 2) & 0x01;

   info.LogicWin    = (Vdp2Regs->WCTLC >> 7 ) & 0x01;

   info.islinescroll = 0;
   info.linescrolltbl = 0;
   info.lineinc = 0;

   Vdp2ReadRotationTable(0, &paraA, Vdp2Regs, Vdp2Ram);
   Vdp2ReadRotationTable(1, &paraB, Vdp2Regs, Vdp2Ram);
   paraA.PlaneAddr = (void FASTCALL (*)(void *, int, Vdp2*))&Vdp2ParameterAPlaneAddr;
   paraB.PlaneAddr = (void FASTCALL (*)(void *, int, Vdp2*))&Vdp2ParameterBPlaneAddr;
   paraA.charaddr = (Vdp2Regs->MPOFR & 0x7) * 0x20000;
   paraB.charaddr = (Vdp2Regs->MPOFR & 0x70) * 0x2000;
   ReadPlaneSizeR(&paraA,Vdp2Regs->PLSZ >> 8);
   ReadPlaneSizeR(&paraB,Vdp2Regs->PLSZ >> 12);



    if( paraA.coefdatasize == 2)
    {
        if(paraA.coefmode < 3 )
        {
            info.GetKValueA = vdp2rGetKValue1W;
        }else{
            info.GetKValueA = vdp2rGetKValue1Wm3;
        }

    }else{
        if(paraA.coefmode < 3 )
        {
            info.GetKValueA = vdp2rGetKValue2W;
        }else{
            info.GetKValueA = vdp2rGetKValue2Wm3;
        }
    }

    if( paraB.coefdatasize == 2)
    {
        if(paraB.coefmode < 3 )
        {
            info.GetKValueB = vdp2rGetKValue1W;
        }else{
            info.GetKValueB = vdp2rGetKValue1Wm3;
        }

    }else{
        if(paraB.coefmode < 3 )
        {
            info.GetKValueB = vdp2rGetKValue2W;
        }else{
            info.GetKValueB = vdp2rGetKValue2Wm3;
        }
    }

   if( Vdp2Regs->RPMD == 0x00 )
   {
      if(!(paraA.coefenab))
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode00NoK;
      }else{
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode00WithK;
      }

   }else if( Vdp2Regs->RPMD == 0x01 )
   {
      if(!(paraB.coefenab))
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode01NoK;
      }else{
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode01WithK;
      }

   }else if( Vdp2Regs->RPMD == 0x02 )
   {
      if(!(paraA.coefenab))
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode02NoK;
      }else{
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode02WithKA;
      }

   }else if( Vdp2Regs->RPMD == 0x03 )
   {
      // Window0
      if( ((Vdp2Regs->WCTLD >> 1) & 0x01) == 0x01 )
      {
         info.pWinInfo = m_vWindinfo0;
         info.WindwAreaMode = (Vdp2Regs->WCTLD & 0x01) ;
      }else if(  ((Vdp2Regs->WCTLD >> 3) & 0x01) == 0x01 )
      {
         info.pWinInfo = m_vWindinfo1;
         info.WindwAreaMode = ((Vdp2Regs->WCTLD >>2)& 0x01) ;
      }else{
         info.pWinInfo = m_vWindinfo0;
         info.WindwAreaMode = (Vdp2Regs->WCTLD & 0x01) ;
      }

      if( paraA.coefenab == 0 && paraB.coefenab == 0 )
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode03NoK;
      }else if( paraA.coefenab && paraB.coefenab == 0 )
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode03WithKA;
      }else if( paraA.coefenab == 0 && paraB.coefenab )
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode03WithKB;
      }else if( paraA.coefenab && paraB.coefenab )
      {
         info.GetRParam = (Vdp2GetRParam_func) vdp2RGetParamMode03WithK;
      }
   }


   paraA.screenover = (Vdp2Regs->PLSZ >> 10)  & 0x03;
   paraB.screenover = (Vdp2Regs->PLSZ >> 14)  & 0x03;



   // Figure out which Rotation Parameter we're uqrt
   switch (Vdp2Regs->RPMD & 0x3)
   {
      case 0:
         // Parameter A
         info.rotatenum = 0;
		 info.rotatemode = 0;
       info.PlaneAddr = (void FASTCALL(*)(void *, int, Vdp2*))&Vdp2ParameterAPlaneAddr;
         break;
      case 1:
         // Parameter B
         info.rotatenum = 1;
		 info.rotatemode = 0;
       info.PlaneAddr = (void FASTCALL(*)(void *, int, Vdp2*))&Vdp2ParameterBPlaneAddr;
         break;
      case 2:
         // Parameter A+B switched via coefficients
         // FIX ME(need to figure out which Parameter is being used)
      case 3:
      default:
         // Parameter A+B switched via rotation parameter window
         // FIX ME(need to figure out which Parameter is being used)
         VDP2LOG("Rotation Parameter Mode %d not supported!\n", Vdp2Regs->RPMD & 0x3);
         info.rotatenum = 0;
		 info.rotatemode = 1 + (Vdp2Regs->RPMD & 0x1);
       info.PlaneAddr = (void FASTCALL(*)(void *, int, Vdp2*))&Vdp2ParameterAPlaneAddr;
         break;
   }



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

      info.paladdr = (Vdp2Regs->BMPNB & 0x7) << 4;
      info.flipfunction = 0;
      info.specialfunction = 0;
   }
   else
   {
      int i;
      // Tile Mode
      info.mapwh = 4;

      if (info.rotatenum == 0)
         // Parameter A
         ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 8);
      else
         // Parameter B
         ReadPlaneSize(&info, Vdp2Regs->PLSZ >> 12);

      ReadPatternData(&info, Vdp2Regs->PNCR, Vdp2Regs->CHCTLB & 0x100);

      paraA.ShiftPaneX = 8 + paraA.planew;
      paraA.ShiftPaneY = 8 + paraA.planeh;
      paraB.ShiftPaneX = 8 + paraB.planew;
      paraB.ShiftPaneY = 8 + paraB.planeh;

      paraA.MskH = (8 * 64 * paraA.planew)-1;
      paraA.MskV = (8 * 64 * paraA.planeh)-1;
      paraB.MskH = (8 * 64 * paraB.planew)-1;
      paraB.MskV = (8 * 64 * paraB.planeh)-1;

	   paraA.MaxH = 8 * 64 * paraA.planew * 4;
	   paraA.MaxV = 8 * 64 * paraA.planeh * 4;
	   paraB.MaxH = 8 * 64 * paraB.planew * 4;
	   paraB.MaxV = 8 * 64 * paraB.planeh * 4;

	   if( paraA.screenover == OVERMODE_512 )
	   {
		   paraA.MaxH = 512;
		   paraA.MaxV = 512;
	   }

	   if( paraB.screenover == OVERMODE_512 )
	   {
		   paraB.MaxH = 512;
		   paraB.MaxV = 512;
	   }

	   for( i=0; i<16; i++ )
       {
         paraA.PlaneAddr(&info,i, Vdp2Regs);
         paraA.PlaneAddrv[i] = info.addr;
         paraB.PlaneAddr(&info, i, Vdp2Regs);
         paraB.PlaneAddrv[i] = info.addr;
       }
   }

   info.specialcolormode = (Vdp2Regs->SFCCMD>>8) & 0x03;

   info.blendmode=0;
   if( (Vdp2Regs->LNCLEN & 0x10) == 0x00 )
   {
      info.LineColorBase = 0x00;
      paraA.lineaddr = 0xFFFFFFFF;
      paraB.lineaddr = 0xFFFFFFFF;
   }else{
//      info.alpha = 0xFF;
      info.LineColorBase = ((Vdp2Regs->LCTA.all)&0x7FFFF) << 1;
      if( info.LineColorBase >= 0x80000 ) info.LineColorBase = 0x00;
      paraA.lineaddr = 0xFFFFFFFF;
      paraB.lineaddr = 0xFFFFFFFF;
   }

   if ( (Vdp2Regs->CCCTL & 0x410) == 0x10 )
   {
	   info.alpha = ((~Vdp2Regs->CCRR & 0x1F) << 3) + 0x7;
	   if (Vdp2Regs->CCCTL & 0x100 && info.specialcolormode == 0)
	   {
		   info.blendmode = 2;
	   }
	   else{
		   info.blendmode = 1;
	   }
   }
   else{
	   info.alpha = 0xFF;
   }

   info.coloroffset = (Vdp2Regs->CRAOFB & 0x7) << 8;

   ReadVdp2ColorOffset(Vdp2Regs,&info, 0x10);
   info.linecheck_mask = 0x10;
   info.coordincx = info.coordincy = 1;

   // Window Mode
   info.bEnWin0 = (Vdp2Regs->WCTLC >> 1) &0x01;
   info.WindowArea0 = (Vdp2Regs->WCTLC >> 0) & 0x01;
   info.bEnWin1 = (Vdp2Regs->WCTLC >> 3) &0x01;
   info.WindowArea1 = (Vdp2Regs->WCTLC >> 2) & 0x01;
   info.LogicWin    = (Vdp2Regs->WCTLC >> 7 ) & 0x01;

   Vdp2SetGetColor( &info );

   if( info.bEnWin0 || info.bEnWin1 )
      YglStartWindow(&info,info.bEnWin0, info.WindowArea0,info.bEnWin1, info.WindowArea1,info.LogicWin);

   Vdp2DrawRotation(&info, &parameter, &texture);

   if( info.bEnWin0 || info.bEnWin1 )
      YglEndWindow(&info);
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp2DrawScreens(void)
{
	if (YglTM->texture == NULL) {
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, _Ygl->texture);
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER, _Ygl->pixelBufferID);
		YglTM->texture = (int*)glMapBufferRange(GL_PIXEL_UNPACK_BUFFER, 0, 2048 * 1024 * 4, GL_MAP_WRITE_BIT);
		if (YglTM->texture == NULL){
			abort();
		}
	}

   VIDOGLVdp2SetResolution(Vdp2Regs->TVMD);
   Vdp2GenerateWindowInfo();
   Vdp2DrawBackScreen();
   Vdp2DrawLineColorScreen();

   Vdp2DrawNBG3();
   Vdp2DrawNBG2();
   Vdp2DrawNBG1();
   Vdp2DrawNBG0();
   Vdp2DrawRBG0();
}

//////////////////////////////////////////////////////////////////////////////

void VIDOGLVdp2SetResolution(u16 TVMD)
{
   int width=0, height=0;
   int wratio=1, hratio=1;

   // Horizontal Resolution
   switch (TVMD & 0x7)
   {
      case 0:
         width = 320;
         wratio = 1;
         break;
      case 1:
         width = 352;
         wratio = 1;
         break;
      case 2:
         width = 640;
         wratio = 2;
         break;
      case 3:
         width = 704;
         wratio = 2;
         break;
      case 4:
         width = 320;
         wratio = 1;
         break;
      case 5:
         width = 352;
         wratio = 1;
         break;
      case 6:
         width = 640;
         wratio = 2;
         break;
      case 7:
         width = 704;
         wratio = 2;
         break;
   }

   // Vertical Resolution
   switch ((TVMD >> 4) & 0x3)
   {
      case 0:
         height = 224;
         break;
      case 1: height = 240;
                 break;
      case 2: height = 256;
                 break;
      default: break;
   }

   hratio = 1;

   // Check for interlace
   switch ((TVMD >> 6) & 0x3)
   {
      case 3: // Double-density Interlace
         height *= 2;
         hratio = 2;
         break;
      case 2: // Single-density Interlace
      case 0: // Non-interlace
      default: break;
   }

   SetSaturnResolution(width, height);
   Vdp1SetTextureRatio(wratio, hratio);
}

//////////////////////////////////////////////////////////////////////////////

void YglGetGlSize(int *width, int *height)
{
   *width = GlWidth;
   *height = GlHeight;
}

void VIDOGLGetNativeResolution(int *width, int *height, int*interlace)
{
   *width = 0;
   *height = 0;
   *interlace = 0;
}

vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue2W( vdp2rotationparameter_struct * param, int index )
{
   float kval;
   int   kdata;

   kdata = T1ReadLong(Vdp2Ram, (param->coeftbladdr&0x7FFFF) + (index<<2) );
   if( kdata & 0x80000000 ) return NULL;

   kval = (float) (int) ((kdata & 0x00FFFFFF) | (kdata & 0x00800000 ? 0xFF800000 : 0x00000000)) / 65536.0f;

   switch( param->coefmode )
   {
   case 0:
       param->kx = kval;
       param->ky = kval;
       break;
   case 1:
       param->kx = kval;
       break;
   case 2:
       param->ky = kval;
       break;
   }

   param->lineaddr = (kdata >> 24)&0x7F;
   return param;
}

vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue1W( vdp2rotationparameter_struct * param, int index )
{
   float kval;
   u16   kdata;

   kdata = T1ReadWord(Vdp2Ram, param->coeftbladdr + (index<<1) );
   if( kdata & 0x8000 ) return NULL;

   kval = (float) (signed) ((kdata & 0x7FFF) | (kdata & 0x4000 ? 0x8000 : 0x0000)) / 1024.0f;

   switch( param->coefmode )
   {
   case 0:
       param->kx = kval;
       param->ky = kval;
       break;
   case 1:
       param->kx = kval;
       break;
   case 2:
       param->ky = kval;
       break;
   }
   return param;

}

vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue2Wm3( vdp2rotationparameter_struct * param, int index )
{
   return param; // ToDo:
}

vdp2rotationparameter_struct * FASTCALL vdp2rGetKValue1Wm3( vdp2rotationparameter_struct * param, int index )
{
   return param; // ToDo:
}


vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode00NoK( vdp2draw_struct * info, int h, int v )
{
   return &paraA;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode00WithK( vdp2draw_struct * info,int h, int v )
{
   h = paraA.KtablV+(paraA.deltaKAx * h);
   return info->GetKValueA( &paraA, h );
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode01NoK( vdp2draw_struct * info,int h, int v )
{
    return &paraB;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode01WithK( vdp2draw_struct * info,int h, int v )
{
   h = (paraB.KtablV+(paraB.deltaKAx * h));
   return info->GetKValueB( &paraB, h );
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode02NoK( vdp2draw_struct * info,int h, int v )
{
   return &paraA;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode02WithKA( vdp2draw_struct * info,int h, int v )
{
    h = (paraA.KtablV+(paraA.deltaKAx * h));
    if( info->GetKValueA( &paraA, h ) == NULL )
    {
        return &paraB;
    }
    return &paraA;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode02WithKB( vdp2draw_struct * info,int h, int v )
{
   return &paraA;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03NoK( vdp2draw_struct * info,int h, int v )
{
   if( info->WindwAreaMode == 0 )
   {
      if( info->pWinInfo[v].WinShowLine == 0  )
      {
         return (&paraB);
      }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            return (&paraB);
         }else{
            return (&paraA);
         }
      }
   }
   else
   {
      if( info->pWinInfo[v].WinShowLine == 0 )
      {
         return (&paraB);
      }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            return (&paraA);
         }else{
            return (&paraB);
         }
      }
   }
   return NULL;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03WithKA( vdp2draw_struct * info,int h, int v )
{

    if( info->WindwAreaMode == 0 )
   {
      if( info->pWinInfo[v].WinShowLine == 0 )
      {
         return (&paraB);
      }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            return (&paraB);
         }else{
            h = (paraA.KtablV+(paraA.deltaKAx * h));
            return info->GetKValueA( &paraA, h );
         }
      }
   }else{
        if( info->pWinInfo[v].WinShowLine == 0 )
        {
            h = (paraA.KtablV+(paraA.deltaKAx * h));
            return info->GetKValueA( &paraA, h );
        }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            h = (paraA.KtablV+(paraA.deltaKAx * h));
            return info->GetKValueA( &paraA, h );
         }else{
            return (&paraB);
         }
      }
   }
   return NULL;

}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03WithKB( vdp2draw_struct * info,int h, int v )
{
   if( info->WindwAreaMode == 0 )
   {
      if( info->pWinInfo[v].WinShowLine == 0 )
      {
         h = (paraB.KtablV+(paraB.deltaKAx * h));
         return info->GetKValueB( &paraB, h );
      }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            h = (paraB.KtablV+(paraB.deltaKAx * h));
            return info->GetKValueB( &paraB, h );
         }else{
            return &paraA;
         }
      }
   }else{
      {
        if( info->pWinInfo[v].WinShowLine == 0 )
        {
            return &paraA;
        }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            h = (paraA.KtablV+(paraA.deltaKAx * h));
            return info->GetKValueA( &paraA, h );
         }else{
            h = (paraB.KtablV+(paraB.deltaKAx * h));
            return info->GetKValueB( &paraB, h );
         }
         }
      }
   }
   return NULL;
}

vdp2rotationparameter_struct * FASTCALL vdp2RGetParamMode03WithK( vdp2draw_struct * info,int h, int v )
{
   vdp2rotationparameter_struct * p;

   if( info->WindwAreaMode == 0 )
   {
      if( info->pWinInfo[v].WinShowLine == 0 )
      {
		  h = (paraB.KtablV + (paraB.deltaKAx * h));
		  p = info->GetKValueB(&paraB, h);
		  if (p) return p;
		  h = (paraA.KtablV + (paraA.deltaKAx * h));
		  return info->GetKValueA(&paraA, h);
      }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
            h = (paraB.KtablV+(paraB.deltaKAx * h));
			p = info->GetKValueB(&paraB, h);
			if (p) return p;
			h = (paraA.KtablV + (paraA.deltaKAx * h));
			return info->GetKValueA(&paraA, h);
         }else{
            h = (paraA.KtablV+(paraA.deltaKAx * h));
			p =  info->GetKValueA(&paraA, h);
			if (p) return p;
			h = (paraB.KtablV + (paraB.deltaKAx * h));
			return info->GetKValueB(&paraB, h);
         }
      }
   }else{
      if( info->pWinInfo[v].WinShowLine == 0 )
      {
		  h = (paraB.KtablV + (paraB.deltaKAx * h));
		  p = info->GetKValueB(&paraB, h);
		  if (p) return p;
		  h = (paraA.KtablV + (paraA.deltaKAx * h));
		  return info->GetKValueA(&paraA, h);
      }else{
         if( h < info->pWinInfo[v].WinHStart || h >= info->pWinInfo[v].WinHEnd )
         {
			 h = (paraB.KtablV + (paraB.deltaKAx * h));
			 p = info->GetKValueB(&paraB, h);
			 if (p) return p;
			 h = (paraA.KtablV + (paraA.deltaKAx * h));
			 return info->GetKValueA(&paraA, h);
         }else{
			 h = (paraA.KtablV + (paraA.deltaKAx * h));
			 p = info->GetKValueA(&paraA, h);
			 if (p) return p;
			 h = (paraB.KtablV + (paraB.deltaKAx * h));
			 return info->GetKValueB(&paraB, h);
         }
      }
   }

   return NULL;
}


#endif

