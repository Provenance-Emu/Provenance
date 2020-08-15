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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <stdlib.h>
#include <math.h>
#include "scalebit.h"
#include "hq2x.h"
#include "hq3x.h"

#include "../../fceu.h"
#include "../../types.h"
#include "../../palette.h"
#include "../../utils/memory.h"
#include "nes_ntsc.h"

extern u8 *XBuf;
extern u8 *XBackBuf;
extern u8 *XDBuf;
extern u8 *XDBackBuf;
extern pal *palo;

#include "../../ppu.h"  // for PPU[]

nes_ntsc_t* nes_ntsc;
uint8 burst_phase = 0;

static uint32 CBM[3];
static uint32 *palettetranslate=0;
static int backBpp, backshiftr[3], backshiftl[3];
static int silt;
static int Bpp;	// BYTES per pixel
static int highefx;
//static uint32 backmask[3];

static uint16 *specbuf=NULL;		// 8bpp -> 16bpp, pre hq2x/hq3x
static uint32 *specbuf32bpp= NULL;	// Buffer to hold output of hq2x/hq3x when converting to 16bpp and 24bpp
static uint8  *specbuf8bpp = NULL;	// For 2xscale, 3xscale.
static uint8  *ntscblit    = NULL;	// For nes_ntsc
static uint32 *prescalebuf = NULL;	// Prescale pointresizes to 2x-4x to allow less blur with hardware acceleration.

//////////////////////
// PAL filter start //
//////////////////////
#define PAL_PHASES 108			// full vertical subcarrier cycle for 3x resolution (18) * full horizontal cycle (6)
static uint32 *palrgb  = NULL;	// buffer for lookup values of RGB with applied moir phases
static uint32 *palrgb2 = NULL;	// buffer for lookup values of blended moir phases
static float  *moire   = NULL;	// modulated signal
const  float   phasex  = (float) 5/18*2;
const  float   phasey  = (float) 1/ 6*2;
const  float   pi      = 3.14f;
int    palnotch        = 90;
int    palsaturation   = 100;
int    palsharpness    = 50;
int    palcontrast     = 100;
int    palbrightness   = 50;
bool   palupdate       = 1;
bool   paldeemphswap   = 0;

static int Round(float value)
{
   return (int) floor(value + 0.5);
}

static int PAL_LUT(uint32 *buffer, int index, int x, int y)
{
	return buffer[index*PAL_PHASES + (x%18) + 18*(y%6)];
}
////////////////////
// PAL filter end //
////////////////////

static void CalculateShift(uint32 *CBM, int *cshiftr, int *cshiftl)
{
	int a,x,z,y;
	cshiftl[0]=cshiftl[1]=cshiftl[2]=-1;
	for(a=0;a<3;a++)
	{
		for(x=0,y=-1,z=0;x<32;x++)
		{
			if(CBM[a]&(1<<x))
			{
				if(cshiftl[a]==-1) cshiftl[a]=x;
				z++;
			}
		}
		cshiftr[a]=(8-z);
	}
}


int InitBlitToHigh(int b, uint32 rmask, uint32 gmask, uint32 bmask, int efx, int specfilt, int specfilteropt)
{
	//paldeemphswap = 0; // determine this in FCEUPPU_SetVideoSystem() instead

	// -Video Modes Tag-
	if(specfilt == 3) // NTSC 2x
	{
		//nes_ntsc variables
		nes_ntsc_setup_t ntsc_setup = nes_ntsc_composite;
		
		switch (specfilteropt)
		{
		//case 0: // Composite
			//ntsc_setup = nes_ntsc_composite;
			//break;
		case 1: //S-Video
			ntsc_setup = nes_ntsc_svideo;
			break;
		case 2: //RGB
			ntsc_setup = nes_ntsc_rgb;
			break;
		case 3: //Monochrome
			ntsc_setup = nes_ntsc_monochrome;
			break;			
		}
		
		nes_ntsc = (nes_ntsc_t*) FCEU_dmalloc( sizeof (nes_ntsc_t) );
		
		if ( nes_ntsc )
		{
			nes_ntsc_init( nes_ntsc, &ntsc_setup, b );			
			ntscblit = (uint8*)FCEU_dmalloc(602*257*b);
		}
		
	} // -Video Modes Tag-
	else if(specfilt == 2 || specfilt == 5) // scale2x and scale3x
	{
		int multi = ((specfilt == 2) ? 2 * 2 : 3 * 3);		
		specbuf8bpp = (uint8*)FCEU_dmalloc(256*240*multi); //mbg merge 7/17/06 added cast		
	} // -Video Modes Tag-
	else if(specfilt == 1 || specfilt == 4) // hq2x and hq3x
	{ 
		if(b == 1) 
			return(0);
		
		if(b == 2 || b == 3)          // 8->16->(hq2x)->32-> 24 or 16.  YARGH.
		{
			uint32 tmpCBM[3];
			backBpp = b;
			tmpCBM[0]=rmask;
			tmpCBM[1]=gmask;
			tmpCBM[2]=bmask;
			
			CalculateShift(tmpCBM, backshiftr, backshiftl);
			
			if(b == 2)
			{
				// ark
				backshiftr[0] += 16;
				backshiftr[1] += 8;
				backshiftr[2] += 0;
				
				// Begin iffy code(requires 16bpp and 32bpp to have same RGB order)
				//backmask[0] = (rmask>>backshiftl[0]) << (backshiftr[0]);
				//backmask[1] = (gmask>>backshiftl[1]) << (backshiftr[1]);
				//backmask[2] = (bmask>>backshiftl[2]) << (backshiftr[2]);
				
				//int x;
				//for(x=0;x<3;x++) 
				// backshiftr[x] -= backshiftl[x];
				// End iffy code
			}
			// -Video Modes Tag-
			if(specfilt == 1)
				specbuf32bpp = (uint32*)FCEU_dmalloc(256*240*4*sizeof(uint32)); //mbg merge 7/17/06 added cast
			else if(specfilt == 4)
				specbuf32bpp = (uint32*)FCEU_dmalloc(256*240*9*sizeof(uint32)); //mbg merge 7/17/06 added cast
		}
		
		efx=0;
		b=2;
		rmask=0x1F<<11;
		gmask=0x3F<<5;
		bmask=0x1F;
		
		// -Video Modes Tag-
		if(specfilt == 4)
			hq3x_InitLUTs();
		else
			hq2x_InitLUTs();
		
		specbuf=(uint16*)FCEU_dmalloc(256*240*sizeof(uint16)); //mbg merge 7/17/06 added cast
	}
	else if (specfilt >= 6 && specfilt <= 8)
	{
		int multi = specfilt - 4; // magic assuming prescales are specfilt >= 6
		prescalebuf = (uint32 *)FCEU_dmalloc(256*240*multi*sizeof(uint32));
	}
	else if (specfilt == 9)
	{
		palrgb     = (uint32 *)FCEU_dmalloc((256+512)*PAL_PHASES*sizeof(uint32));
		palrgb2    = (uint32 *)FCEU_dmalloc((256+512)*PAL_PHASES*sizeof(uint32));
		moire      = (float  *)FCEU_dmalloc(          PAL_PHASES*sizeof(float));
	}

	silt = specfilt;	
	Bpp=b;	
	highefx=efx;
	
	if(Bpp<=1 || Bpp>4)
		return(0);
	
	//allocate adequate room for 32bpp palette
	palettetranslate=(uint32*)FCEU_dmalloc(256*4 + 512*4);
	
	if(!palettetranslate)
		return(0);
	
	
	CBM[0]=rmask;
	CBM[1]=gmask;
	CBM[2]=bmask;
	return(1);
}

void KillBlitToHigh(void)
{
	if(palettetranslate)
	{
		free(palettetranslate);
		palettetranslate=NULL;
	}
	
	if(specbuf8bpp)
	{
		free(specbuf8bpp);
		specbuf8bpp = NULL;
	}
	if(specbuf32bpp)
	{
		free(specbuf32bpp);
		specbuf32bpp = NULL;
	}
	if(specbuf)
	{
	// -Video Modes Tag-
		if(silt == 4)
			hq3x_Kill();
		else
			hq2x_Kill();
		specbuf=NULL;
	}
	if (nes_ntsc) {
		free(nes_ntsc);
		nes_ntsc = NULL;
	}
	if (ntscblit) {
		free(ntscblit);
		ntscblit = NULL;
	}
	if (prescalebuf) {
		free(prescalebuf);
		prescalebuf = NULL;
	}
	if (palrgb) {
		free(palrgb);
		palrgb = NULL;
		free(palrgb2);
		palrgb2 = NULL;
		free(moire);
		moire = NULL;
	}
}


void SetPaletteBlitToHigh(uint8 *src)
{ 
	int cshiftr[3];
	int cshiftl[3];
	
	CalculateShift(CBM, cshiftr, cshiftl);

	switch(Bpp)
	{
	case 2:
		for(int x=0;x<256;x++)
		{
			uint32 r = src[x<<2];
			uint32 g = src[(x<<2)+1];
			uint32 b = src[(x<<2)+2];
			u16 color = (r>>cshiftr[0])<<cshiftl[0];
			color |= (g>>cshiftr[1])<<cshiftl[1];
			color |= (b>>cshiftr[2])<<cshiftl[2];
			palettetranslate[x]=color;
		}

		//full size deemph palette
		if(palo)
		{
			for(int x=0;x<512;x++)
			{
				uint32 r=palo[x].r;
				uint32 g=palo[x].g;
				uint32 b=palo[x].b;
				u16 color = (r>>cshiftr[0])<<cshiftl[0];
				color |= (g>>cshiftr[1])<<cshiftl[1];
				color |= (b>>cshiftr[2])<<cshiftl[2];
				palettetranslate[256+x]=color;
			}
		}

		break;

	case 3:
	case 4:
		for(int x=0;x<256;x++)
		{
			uint32 r=src[x<<2];
			uint32 g=src[(x<<2)+1];
			uint32 b=src[(x<<2)+2];
			palettetranslate[x]=(r<<cshiftl[0])|(g<<cshiftl[1])|(b<<cshiftl[2]);
		}

		//full size deemph palette
		if(palo)
		{
			for(int x=0;x<512;x++)
			{
				uint32 r=palo[x].r;
				uint32 g=palo[x].g;
				uint32 b=palo[x].b;
				palettetranslate[256+x]=(r<<cshiftl[0])|(g<<cshiftl[1])|(b<<cshiftl[2]);
			}
		}

		break;
	}
}

void Blit32to24(uint32 *src, uint8 *dest, int xr, int yr, int dpitch)
{
	int x,y;
	
	for(y=yr;y;y--)
	{
		for(x=xr;x;x--)
		{
			uint32 tmp = *src;
			*dest = tmp;
			dest++;
			*dest = tmp>>8;
			dest++;
			*dest = tmp>>16;
			dest++;
			src++;
		}
		dest += dpitch / 3 - xr;
	}
}

void Blit32to16(uint32 *src, uint16 *dest, int xr, int yr, int dpitch, int shiftr[3], int shiftl[3])
{
	int x,y;
	//printf("%d\n",shiftl[1]);
	for(y=yr;y;y--)
	{
		for(x=xr;x;x--)
		{
			uint32 tmp = *src;
			uint16 dtmp;
			
			// Begin iffy code
			//dtmp = (tmp & backmask[2]) >> shiftr[2];
			//dtmp |= (tmp & backmask[1]) >> shiftr[1];
			//dtmp |= (tmp & backmask[0]) >> shiftr[0];
			// End iffy code
			
			// Begin non-iffy code
			dtmp =  ((tmp&0x0000FF) >> shiftr[2]) << shiftl[2];
			dtmp |= ((tmp&0x00FF00) >> shiftr[1]) << shiftl[1];
			dtmp |= ((tmp&0xFF0000) >> shiftr[0]) << shiftl[0];
			// End non-iffy code
			
			//dtmp = ((tmp&0x0000FF) >> 3);
			//dtmp |= ((tmp&0x00FC00) >>5);
			//dtmp |= ((tmp&0xF80000) >>8);
			
			*dest = dtmp;
			src++;
			dest++;
		}
		dest += dpitch / 2 - xr;
	}
}


void Blit8To8(uint8 *src, uint8 *dest, int xr, int yr, int pitch, int xscale, int yscale, int efx, int special)
{
	int x,y;
	int pinc;
	
	// -Video Modes Tag-
	if(special==3) //NTSC 2x
		return; //Incompatible with 8-bit output. This is here for SDL.
	
	// -Video Modes Tag-
	if(special==2)
	{
		if(xscale!=2 || yscale!=2) return;
		
		scale(2,dest,pitch,src,256,1,xr,yr);
		return;
	}
	
	// -Video Modes Tag-
	if(special==5)
	{
		if(xscale!=3 || yscale!=3) return;
		scale(3,dest,pitch,src,256,1,xr,yr);
		return;
	}     
	
	pinc=pitch-(xr*xscale);
	if(xscale!=1 || yscale!=1)
	{
		for(y=yr;y;y--,src+=256-xr)
		{
			int doo=yscale;
			do
			{
				for(x=xr;x;x--,src++)
				{
					int too=xscale;
					do
					{
						*(uint8 *)dest=*(uint8 *)src;
						dest++;
					} while(--too);
				}
				src-=xr;
				dest+=pinc;
			} while(--doo);
			src+=xr;
		}
	}
	else
	{
		for(y=yr;y;y--,dest+=pinc,src+=256-xr)
			for(x=xr;x;x-=4,dest+=4,src+=4)
				*(uint32 *)dest=*(uint32 *)src;
	}
}

/* Todo:  Make sure 24bpp code works right with big-endian cpus */

//takes a pointer to XBuf and applies fully modern deemph palettizing
u32 ModernDeemphColorMap(u8* src, u8* srcbuf, int xscale, int yscale)
{
	u8 pixel = *src;
	
	//look up the legacy translation
	u32 color = palettetranslate[pixel];

	int ofs = src-srcbuf;
	int xofs = ofs&255;
	int yofs = ofs>>8;
	if(xscale!=1) xofs /= xscale; //untested optimization
	if(yscale!=1) yofs /= yscale; //untested optimization
	ofs = xofs+yofs*256;

	//find out which deemph bitplane value we're on
	uint8 deemph = XDBuf[ofs];

	//if it was a deemph'd value, grab it from the deemph palette
	if(deemph != 0)
		color = palettetranslate[256+(pixel&0x3F)+deemph*64];

	return color;
}

void Blit8ToHigh(uint8 *src, uint8 *dest, int xr, int yr, int pitch, int xscale, int yscale)
{
	int x,y;
	int pinc;
	uint8 *destbackup = NULL;	/* For hq2x */
	int pitchbackup = 0;

	
	//static int google=0;
	//google^=1;
	
	if(specbuf8bpp)                  // 2xscale/3xscale
	{
		int mult; 
		int base;
		
		// -Video Modes Tag-
		if(silt == 2) mult = 2;
		else mult = 3;
		
		Blit8To8(src, specbuf8bpp, xr, yr, 256*mult, xscale, yscale, 0, silt);
		int mdcmxs = xscale*mult;
		int mdcmys = yscale*mult;
		
		xr *= mult;
		yr *= mult;
		xscale=yscale=1;
		src = specbuf8bpp;
		base = 256*mult;
		
		switch(Bpp)
		{
		case 4:
			pinc=pitch-(xr<<2);
			for(y=yr;y;y--,src+=base-xr)
			{
				for(x=xr;x;x--)
				{
				 *(uint32 *)dest=ModernDeemphColorMap(src,specbuf8bpp,mdcmxs, mdcmys);
				 dest+=4;
				 src++;
				}
				dest+=pinc;
			}
			break;
		case 3:
			pinc=pitch-(xr+xr+xr);
			for(y=yr;y;y--,src+=base-xr)
			{
				for(x=xr;x;x--)
				{
					uint32 tmp=ModernDeemphColorMap(src,specbuf8bpp,mdcmxs, mdcmys);
					*(uint8 *)dest=tmp;
					*((uint8 *)dest+1)=tmp>>8;
					*((uint8 *)dest+2)=tmp>>16;
					dest+=3;
					src++;
					src++;
				}
				dest+=pinc;
			}
			break; 
		case 2:
			pinc=pitch-(xr<<1);
			
			for(y=yr;y;y--,src+=base-xr)
			{
				for(x=xr>>1;x;x--)
				{
					//*(uint32 *)dest=palettetranslate[*(uint16 *)src]; //16bpp is doomed
					dest+=4;
					src+=2;
				}
				dest+=pinc;
			}
			break;
		}
		return;
	}
	else if(prescalebuf)             // bare prescale
	{
		destbackup = dest;
		dest = (uint8 *)prescalebuf;
		pitchbackup = pitch;		
		pitch = xr*sizeof(uint32);
		pinc = pitch-(xr<<2);

		for(y=yr; y; y--, src+=256-xr)
		{
			for(x=xr; x; x--)
			{
				*(uint32 *)dest = ModernDeemphColorMap(src,XBuf,1,1);
				dest += 4;
				src++;
			}
			dest += pinc;
		}

		if (Bpp == 4) // are other modes really needed?
		{
			uint32 *s = prescalebuf;
			uint32 *d = (uint32 *)destbackup; // use 32-bit pointers ftw
			int subpixel;

			for (y=0; y<yr*yscale; y++)
			{
				int back = xr*(y%yscale>0); // bool as multiplier
				for (x=0; x<xr; x++)
				{
					for (subpixel=0; subpixel<xscale; subpixel++)
					{
						*d++ = *(s-back);
					}
					s++;
				}
				if (back)
					s -= xr;
			}
		}
		return;
	}
	else if (palrgb)                 // pal moire
	{
		// skip usual palette translation, fill lookup array of RGB+moire values per palette update, and send directly to DX dest
		// written by feos in 2015, credits to HardWareMan and r57shell
		if (palupdate)
		{
			uint8 *source = (uint8 *)palettetranslate;
			int16 R,G,B;
			float Y,U,V;
			float alpha;
			float sat = (float) palsaturation/100;
			float contrast = (float) palcontrast/100;
			int bright = palbrightness - 50;
			int notch = palnotch;
			int unnotch = 100 - palnotch;
			int mixR[PAL_PHASES], mixG[PAL_PHASES], mixB[PAL_PHASES];

			for (int i=0; i<256+512; i++)
			{
				// fetch color
				R = source[i*4  ];
				G = source[i*4+1];
				B = source[i*4+2];
			
				// rgb -> yuv, sdtv bt.601
				Y =  0.299  *R + 0.587  *G + 0.114  *B;
				U = -0.14713*R - 0.28886*G + 0.436  *B;
				V =  0.615  *R - 0.51499*G - 0.10001*B;

				// all variants of this color
				for (int x=0; x<18; x++)
				{
					for (y=0; y<6; y++)
					{
						alpha = (x*phasex + y*phasey)*pi;                // 2*pi*freq*t
						if (y%2 == 0) alpha = -alpha;                    // phase alternating line!
						moire[x+y*18] = Y + U*sin(alpha) + V*cos(alpha); // modulated composite signal
					}
				}

				for (int j=0; j<PAL_PHASES; j++)
				{
					// yuv -> rgb, sdtv bt.601
					R = Round(moire[j]*contrast+bright                 + 1.13983*V*sat);
					G = Round(moire[j]*contrast+bright - 0.39465*U*sat - 0.58060*V*sat);
					B = Round(moire[j]*contrast+bright + 2.03211*U*sat                );

					// clamp
					if (R > 0xff) R = 0xff; else if (R < 0) R = 0;
					if (G > 0xff) G = 0xff; else if (G < 0) G = 0;
					if (B > 0xff) B = 0xff; else if (B < 0) B = 0;

					// store colors to mix
					mixR[j] = R;
					mixG[j] = G;
					mixB[j] = B;

					// moirecolor
					palrgb[i*PAL_PHASES+j] = (B<<16)|(G<<8)|R;
				}

				for (int j=0; j<PAL_PHASES; j++)
				{
					// mix to simulate notch
					R = (mixR[j]*unnotch + (mixR[0]+mixR[1]+mixR[2]+mixR[3]+mixR[4]+mixR[5])/6*notch)/100;
					G = (mixG[j]*unnotch + (mixG[0]+mixG[1]+mixG[2]+mixG[3]+mixG[4]+mixG[5])/6*notch)/100;
					B = (mixB[j]*unnotch + (mixB[0]+mixB[1]+mixB[2]+mixB[3]+mixB[4]+mixB[5])/6*notch)/100;

					// notchcolor
					palrgb2[i*PAL_PHASES+j] = (B<<16)|(G<<8)|R;
				}
			}
			palupdate = 0;
		}

		if (Bpp == 4)
		{
			uint32 *d = (uint32 *)dest;
			uint8  xsub      = 0;
			uint16 xabs      = 0;
			uint32 index     = 0;
			uint32 lastindex = 0;
			uint32 newindex  = 0;
			int sharp   = 50 + palsharpness;
			int unsharp = 50 - palsharpness;
			int rmask   = 0xff0000;
			int gmask   = 0x00ff00;
			int bmask   = 0x0000ff;
			int r, g, b, ofs;
			uint8 deemph;
			uint32 color, moirecolor, notchcolor, finalcolor, lastcolor = 0;

			for (y=0; y<yr; y++)
			{
				for (x=0; x<xr; x++)
				{
					ofs = src-XBuf;                  //find out which deemph bitplane value we're on
					deemph = XDBuf[ofs];
					int temp = *src;
					index = (*src&63) | (deemph*64); //get combined index from basic value and preemph bitplane
					index += 256;

					src++;
					
					ofs = src-XBuf;
					deemph = XDBuf[ofs];
					newindex = (*src&63) | (deemph*64);
					newindex += 256;

					if(GameInfo->type==GIT_NSF)
					{
						*d++ = palettetranslate[temp];
						*d++ = palettetranslate[temp];
						*d++ = palettetranslate[temp];
					}
					else
					{
						for (xsub = 0; xsub < 3; xsub++)
						{
							xabs = x*3 + xsub;
							moirecolor = PAL_LUT(palrgb,  index, xabs, y);							
							notchcolor = PAL_LUT(palrgb2, index, xabs, y);

							// | | |*|*| | |
							if (index !=  newindex && xsub == 2 ||
								index != lastindex && xsub == 0)
							{
								r = ((moirecolor&rmask)*90 + (notchcolor&rmask)*10)/100;
								g = ((moirecolor&gmask)*90 + (notchcolor&gmask)*10)/100;
								b = ((moirecolor&bmask)*90 + (notchcolor&bmask)*10)/100;
								color = r&rmask | g&gmask | b&bmask;
							}
							// | |*| | |*| |
							else if (index !=  newindex && xsub == 1 ||
									 index != lastindex && xsub == 1)
							{
								r = ((moirecolor&rmask)*60 + (notchcolor&rmask)*40)/100;
								g = ((moirecolor&gmask)*60 + (notchcolor&gmask)*40)/100;
								b = ((moirecolor&bmask)*60 + (notchcolor&bmask)*40)/100;
								color = r&rmask | g&gmask | b&bmask;
							}
							// |*| | | | |*|
							else if (index !=  newindex && xsub == 0 ||
									 index != lastindex && xsub == 2)
							{
								r = ((moirecolor&rmask)*30 + (notchcolor&rmask)*70)/100;
								g = ((moirecolor&gmask)*30 + (notchcolor&gmask)*70)/100;
								b = ((moirecolor&bmask)*30 + (notchcolor&bmask)*70)/100;
								color = r&rmask | g&gmask | b&bmask;
							}
							else
							{
								color = notchcolor;
							}
							
							if (color != lastcolor && sharp < 100)
							{
								r = ((color&rmask)*sharp + (lastcolor&rmask)*unsharp)/100;
								g = ((color&gmask)*sharp + (lastcolor&gmask)*unsharp)/100;
								b = ((color&bmask)*sharp + (lastcolor&bmask)*unsharp)/100;
								finalcolor = r&rmask | g&gmask | b&bmask;

								r = ((lastcolor&rmask)*sharp + (color&rmask)*unsharp)/100;
								g = ((lastcolor&gmask)*sharp + (color&gmask)*unsharp)/100;
								b = ((lastcolor&bmask)*sharp + (color&bmask)*unsharp)/100;
								lastcolor = r&rmask | g&gmask | b&bmask;

								*d-- = lastcolor;
								d++;
							}
							else
								finalcolor = color;
						
							lastcolor = color;
							*d++ = finalcolor;
						}
						lastindex = index;
					}
				}
			}

		}
		return;
	}
	else if(specbuf)                 // hq2x/hq3x
	{
		destbackup=dest;
		dest=(uint8 *)specbuf;
		pitchbackup=pitch;
		
		pitch=xr*sizeof(uint16);
		xscale=1;
		yscale=1;
	}
	
	{
		if(xscale!=1 || yscale!=1)
		{
			switch(Bpp)
			{
			case 4:
				if ( nes_ntsc && GameInfo->type!=GIT_NSF) {
					int outxr = 301;
					//if(xr == 282) outxr = 282; //hack for windows
					burst_phase ^= 1;
					nes_ntsc_blit( nes_ntsc, (unsigned char*)src, xr, burst_phase, (PPU[1] >> 5) << 6, xr, yr, ntscblit, (2*outxr) * Bpp );

					const uint8 *in = ntscblit + (Bpp * xscale);
					uint8 *out = dest;
					const int in_stride = Bpp * outxr * 2;
					const int out_stride = pitch;
					for( int y = 0; y < yr; y++, in += in_stride, out += 2*out_stride ) {
						memcpy(out, in, Bpp * outxr * xscale);
						memcpy(out + out_stride, in, Bpp * outxr * xscale);
					}
				} else {
					pinc=pitch-((xr*xscale)<<2);
					for(y=yr;y;y--,src+=256-xr)
					{
						int doo=yscale;
						        
						do
						{
							for(x=xr;x;x--,src++)
							{
								int too=xscale;
								do
								{
									*(uint32 *)dest=palettetranslate[*src];
									dest+=4;
								} while(--too);
							}
							src-=xr;
							dest+=pinc;
						} while(--doo);
						src+=xr;
					}
				}
				break;
			
			case 3:
				pinc=pitch-((xr*xscale)*3);
				for(y=yr;y;y--,src+=256-xr)
				{  
					int doo=yscale;
					 
					do
					{
						for(x=xr;x;x--,src++)
						{    
							int too=xscale;
							do
							{
								uint32 tmp=palettetranslate[(uint32)*src];
								*(uint8 *)dest=tmp;
								*((uint8 *)dest+1)=tmp>>8;
								*((uint8 *)dest+2)=tmp>>16;
								dest+=3;
								
								//*(uint32 *)dest=palettetranslate[*src];
								//dest+=4;
							} while(--too);
						}
						src-=xr;
						dest+=pinc;
					} while(--doo);
					src+=xr;
				}
				break;
						
			case 2:
				pinc=pitch-((xr*xscale)<<1);
				   
				for(y=yr;y;y--,src+=256-xr)
				{   
					int doo=yscale;
					   
					do
					{
						for(x=xr;x;x--,src++)
						{
							int too=xscale;
							do
							{
								//*(uint16 *)dest=palettetranslate[*src]; 16bpp is doomed right now
								dest+=2;
							} while(--too);
						}
					src-=xr;
					dest+=pinc;
					} while(--doo);
					src+=xr;
				}  
				break;
			}
		}
		else
			switch(Bpp)
			{
			case 4:
				pinc=pitch-(xr<<2);
				for(y=yr;y;y--,src+=256-xr)
				{
					for(x=xr;x;x--)
					{
						//THE MAIN BLITTING CODEPATH (there may be others that are important)
						*(uint32 *)dest = ModernDeemphColorMap(src,XBuf,1,1);
						dest+=4;
						src++;
					}
					dest+=pinc;
				}
				break;
			case 3:
				pinc=pitch-(xr+xr+xr);
				for(y=yr;y;y--,src+=256-xr)
				{
					for(x=xr;x;x--)
					{     
						uint32 tmp = ModernDeemphColorMap(src,XBuf,1,1);
						*(uint8 *)dest=tmp;
						*((uint8 *)dest+1)=tmp>>8;
						*((uint8 *)dest+2)=tmp>>16;
						dest+=3;
						src++;
					}
					dest+=pinc;
				}
				break;
			case 2:
				pinc=pitch-(xr<<1);
				for(y=yr;y;y--,src+=256-xr)
				{
					for(x=xr;x;x--)
					{
						*(uint16 *)dest = ModernDeemphColorMap(src,XBuf,1,1);
						dest+=2;
						src++;
					}
					dest+=pinc;
				}
				break;
			}
	}
	
	if(specbuf)
	{
		if(specbuf32bpp)
		{
			// -Video Modes Tag-
			int mult = (silt == 4)?3:2;
			
			if(silt == 4)
				hq3x_32((uint8 *)specbuf,(uint8*)specbuf32bpp,xr,yr,xr*3*sizeof(uint32));
			else
				hq2x_32((uint8 *)specbuf,(uint8*)specbuf32bpp,xr,yr,xr*2*sizeof(uint32));
			
			if(backBpp == 2)
				Blit32to16(specbuf32bpp, (uint16*)destbackup, xr*mult, yr*mult, pitchbackup, backshiftr,backshiftl);
			else // == 3
				Blit32to24(specbuf32bpp, (uint8*)destbackup, xr*mult, yr*mult, pitchbackup);
		}
		else
		{
			// -Video Modes Tag-
			if(silt == 4)
				hq3x_32((uint8 *)specbuf,destbackup,xr,yr,pitchbackup);
			else
				hq2x_32((uint8 *)specbuf,destbackup,xr,yr,pitchbackup);
		}
	}
}
