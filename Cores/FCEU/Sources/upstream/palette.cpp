/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 2002,2003 Xodnizel
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


#include "types.h"
#include "file.h"
#include "fceu.h"
#include "driver.h"
#include "boards/mapinc.h"
#ifdef _S9XLUA_H
#include "fceulua.h"
#endif

#include "palette.h"
#include "palettes/palettes.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstring>

bool force_grayscale = false;

pal palette_game[64*8]; //custom palette for an individual game. (formerly palettei)
pal palette_user[64*8]; //user's overridden palette (formerly palettec)
pal palette_ntsc[64*8]; //mathematically generated NTSC palette (formerly paletten)

static bool palette_game_available; //whether palette_game is available
static bool palette_user_available; //whether palette_user is available

//ntsc parameters:
bool ntsccol_enable = false; //whether NTSC palette is selected
static int ntsctint = 46+10;
static int ntschue = 72;

//the default basic palette
int default_palette_selection = 0;

//library of default palettes
static pal *default_palette[8]=
{
	palette,
	rp2c04001,
	rp2c04002,
	rp2c04003,
	rp2c05004,
};

static void CalculatePalette(void);
static void ChoosePalette(void);
static void WritePalette(void);

//points to the actually selected current palette
pal *palo;

#define RGB_TO_YIQ( r, g, b, y, i ) (\
	(y = (r) * 0.299f + (g) * 0.587f + (b) * 0.114f),\
	(i = (r) * 0.596f - (g) * 0.275f - (b) * 0.321f),\
	((r) * 0.212f - (g) * 0.523f + (b) * 0.311f)\
)

#define YIQ_TO_RGB( y, i, q, to_rgb, type, r, g ) (\
	r = (type) (y + to_rgb [0] * i + to_rgb [1] * q),\
	g = (type) (y + to_rgb [2] * i + to_rgb [3] * q),\
	(type) (y + to_rgb [4] * i + to_rgb [5] * q)\
)

static void ApplyDeemphasisNTSC(int entry, u8& r, u8& g, u8& b)
{
				static float const to_float = 1.0f / 0xFF;
				float fr = to_float * r;
				float fg = to_float * g;
				float fb = to_float * b;
				float y, i, q = RGB_TO_YIQ( fr, fg, fb, y, i );


	//---------------------------------
	//it seems a bit bogus here to use this segment which is essentially part of the base palette generation,
	//but it's needed for 'hi'
	static float const lo_levels [4] = { -0.12f, 0.00f, 0.31f, 0.72f };
	static float const hi_levels [4] = {  0.40f, 0.68f, 1.00f, 1.00f };
	int level = entry >> 4 & 0x03;
	float lo = lo_levels [level];
	float hi = hi_levels [level];
		
	int color = entry & 0x0F;
	if ( color == 0 )
		lo = hi;
	if ( color == 0x0D )
		hi = lo;
	if ( color > 0x0D )
		hi = lo = 0.0f;
	//---------------------------------

	int tint = (entry >> 6) & 7;
	if ( tint && color <= 0x0D )
	{
		static float const phases [0x10 + 3] = {
			-1.0f, -0.866025f, -0.5f, 0.0f,  0.5f,  0.866025f,
			 1.0f,  0.866025f,  0.5f, 0.0f, -0.5f, -0.866025f,
			-1.0f, -0.866025f, -0.5f, 0.0f,  0.5f,  0.866025f,
			 1.0f
		};
		#define TO_ANGLE_SIN( color )   phases [color]
		#define TO_ANGLE_COS( color )   phases [(color) + 3]

		static float const atten_mul = 0.79399f;
		static float const atten_sub = 0.0782838f;
					
		if ( tint == 7 )
		{
			y = y * (atten_mul * 1.13f) - (atten_sub * 1.13f);
		}
		else
		{
			static unsigned char const tints [8] = { 0, 6, 10, 8, 2, 4, 0, 0 };
			int const tint_color = tints [tint];
			float sat = hi * (0.5f - atten_mul * 0.5f) + atten_sub * 0.5f;
			y -= sat * 0.5f;
			if ( tint >= 3 && tint != 4 )
			{
				//combined tint bits
				sat *= 0.6f;
				y -= sat;
			}
			i += TO_ANGLE_SIN( tint_color ) * sat;
			q += TO_ANGLE_COS( tint_color ) * sat;
		}
	}

	static float const default_decoder [6] =
		{ 0.956f, 0.621f, -0.272f, -0.647f, -1.105f, 1.702f };
	fb = YIQ_TO_RGB( y, i, q, default_decoder, float, fr, fg );

	#define CLAMP(x) ((x)<0?0:((x)>1.0f?1.0f:(x)))
	r = (u8)(CLAMP(fr)*255);
	g = (u8)(CLAMP(fg)*255);
	b = (u8)(CLAMP(fb)*255);

	//doesnt help
	//float gamma=1.8f;
 //       auto gammafix = [=](float f) { return f < 0.f ? 0.f : std::pow(f, 2.2f / gamma); };
 //       auto clamp = [](int v) { return v<0 ? 0 : v>255 ? 255 : v; };
 //       r = clamp(255 * gammafix(y +  0.946882f*i +  0.623557f*q));
 //       g = clamp(255 * gammafix(y + -0.274788f*i + -0.635691f*q));
 //       b = clamp(255 * gammafix(y + -1.108545f*i +  1.709007f*q));
}

float bisqwit_gammafix(float f, float gamma) { return f < 0.f ? 0.f : std::pow(f, 2.2f / gamma); }
int bisqwit_clamp(int v) { return v<0 ? 0 : v>255 ? 255 : v; }

// Calculate the luma and chroma by emulating the relevant circuits:
int bisqwit_wave(int p, int color) { return (color+p+8)%12 < 6; }

static void ApplyDeemphasisBisqwit(int entry, u8& r, u8& g, u8& b)
{
	if(entry<64) return;
	int myr, myg, myb;
	// The input value is a NES color index (with de-emphasis bits).
	// We need RGB values. Convert the index into RGB.
	// For most part, this process is described at:
	//    http://wiki.nesdev.com/w/index.php/NTSC_video

	// Decode the color index
	int color = (entry & 0x0F), level = color<0xE ? (entry>>4) & 3 : 1;

	// Voltage levels, relative to synch voltage
	static const float black=.518f, white=1.962f, attenuation=.746f,
		levels[8] = {.350f, .518f, .962f,1.550f,  // Signal low
		1.094f,1.506f,1.962f,1.962f}; // Signal high

	float lo_and_hi[2] = { levels[level + 4 * (color == 0x0)],
		levels[level + 4 * (color <  0xD)] };



	//fceux alteration: two passes
	//1st pass calculates bisqwit's base color
	//2nd pass calculates it with deemph
	//finally, we'll do something dumb: find a 'scale factor' between them and apply it to the input palette. (later, we could pregenerate the scale factors)
	//whatever, it gets the job done.
	for(int pass=0;pass<2;pass++)
	{
		float y=0.f, i=0.f, q=0.f, gamma=1.8f;
		for(int p=0; p<12; ++p) // 12 clock cycles per pixel.
		{
			// NES NTSC modulator (square wave between two voltage levels):
			float spot = lo_and_hi[bisqwit_wave(p,color)];

			// De-emphasis bits attenuate a part of the signal:
			if(pass==1)
			{
				if(((entry & 0x40) && bisqwit_wave(p,12))
					|| ((entry & 0x80) && bisqwit_wave(p, 4))
					|| ((entry &0x100) && bisqwit_wave(p, 8))) spot *= attenuation;
			}

			// Normalize:
			float v = (spot - black) / (white-black) / 12.f;

			// Ideal TV NTSC demodulator:
			y += v;
			i += v * std::cos(3.141592653 * p / 6);
			q += v * std::sin(3.141592653 * p / 6); // Or cos(... p-3 ... )
			// Note: Integrating cos() and sin() for p-0.5 .. p+0.5 range gives
			//       the exactly same result, scaled by a factor of 2*cos(pi/12).
		}

		// Convert YIQ into RGB according to FCC-sanctioned conversion matrix.

		int rt = bisqwit_clamp(255 * bisqwit_gammafix(y +  0.946882f*i +  0.623557f*q,gamma));
		int gt = bisqwit_clamp(255 * bisqwit_gammafix(y + -0.274788f*i + -0.635691f*q,gamma));
		int bt = bisqwit_clamp(255 * bisqwit_gammafix(y + -1.108545f*i +  1.709007f*q,gamma));

		if(pass==0) myr = rt, myg = gt, myb = bt;
		else
		{
			float rscale = (float)rt / myr;
			float gscale = (float)gt / myg;
			float bscale = (float)bt / myb;
			#define BCLAMP(x) ((x)<0?0:((x)>255?255:(x)))
			if(myr!=0) r = (u8)(BCLAMP(r*rscale));
			if(myg!=0) g = (u8)(BCLAMP(g*gscale));
			if(myb!=0) b = (u8)(BCLAMP(b*bscale));
		}
	}



}

//classic algorithm
static void ApplyDeemphasisClassic(int entry, u8& r, u8& g, u8& b)
{
	//DEEMPH BITS MAY BE ORDERED WRONG. PLEASE CHECK

	static const float rtmul[] = { 1.239f, 0.794f, 1.019f, 0.905f, 1.023f, 0.741f, 0.75f };
	static const float gtmul[] = { 0.915f, 1.086f, 0.98f,  1.026f, 0.908f, 0.987f, 0.75f };
	static const float btmul[] = { 0.743f, 0.882f, 0.653f, 1.277f, 0.979f, 0.101f, 0.75f };

	int deemph_bits = entry >> 6;

	if (deemph_bits == 0) return;

	int d = deemph_bits - 1;
	int nr = (int)(r * rtmul[d]);
	int ng = (int)(g * gtmul[d]);
	int nb = (int)(b * btmul[d]);
	if (nr > 0xFF) nr = 0xFF;
	if (ng > 0xFF) ng = 0xFF;
	if (nb > 0xFF) nb = 0xFF;
	r = (u8)nr;
	g = (u8)ng;
	b = (u8)nb;
}

static void ApplyDeemphasisComplete(pal* pal512)
{
	//for each deemph level beyond 0
	for(int i=0,idx=0;i<8;i++)
	{
		//for each palette entry
		for(int p=0;p<64;p++,idx++)
		{
			pal512[idx] = pal512[p];
			ApplyDeemphasisBisqwit(idx,pal512[idx].r,pal512[idx].g,pal512[idx].b);
		}
	}
}

void FCEUI_SetUserPalette(uint8 *pal, int nEntries)
{
	if(!pal)
	{
		palette_user_available = false;
	}
	else
	{
		palette_user_available = true;
		memcpy(palette_user,pal,nEntries*3);

		//if palette is incomplete, generate deemph entries
		if(nEntries != 512)
			ApplyDeemphasisComplete(palette_user);
	}
	FCEU_ResetPalette();
}

void FCEU_LoadGamePalette(void)
{
	palette_game_available = false;
	std::string path = FCEU_MakeFName(FCEUMKF_PALETTE,0,0);
	FILE* fp = FCEUD_UTF8fopen(path,"rb");
	if(fp)
	{
		int readed = fread(palette_game,1,64*8*3,fp);
		int nEntries = readed/3;
		fclose(fp);

		//if palette is incomplete, generate deemph entries
		if(nEntries != 512)
			ApplyDeemphasisComplete(palette_game);

		palette_game_available = true;
	}

	//not sure whether this is needed
	FCEU_ResetPalette();
}

void FCEUI_SetNTSCTH(bool en, int tint, int hue)
{
	ntsctint=tint;
	ntschue=hue;
	ntsccol_enable = en;
	FCEU_ResetPalette();
}

//this prepares the 'deemph' palette which was a horrible idea to jam a single deemph palette into 0xC0-0xFF of the 8bpp palette.
//its needed for GUI and lua and stuff, so we're leaving it, despite having a newer codepath for applying deemph
static uint8 lastd=0;
void SetNESDeemph_OldHacky(uint8 d, int force)
{
	static uint16 rtmul[]={
        static_cast<uint16>(32768*1.239),
        static_cast<uint16>(32768*.794),
        static_cast<uint16>(32768*1.019),
        static_cast<uint16>(32768*.905),
        static_cast<uint16>(32768*1.023),
        static_cast<uint16>(32768*.741),
        static_cast<uint16>(32768*.75)
    };
	static uint16 gtmul[]={
        static_cast<uint16>(32768*.915),
        static_cast<uint16>(32768*1.086),
        static_cast<uint16>(32768*.98),
        static_cast<uint16>(32768*1.026),
        static_cast<uint16>(32768*.908),
        static_cast<uint16>(32768*.987),
        static_cast<uint16>(32768*.75)
    };
	static uint16 btmul[]={
        static_cast<uint16>(32768*.743),
        static_cast<uint16>(32768*.882),
        static_cast<uint16>(32768*.653),
        static_cast<uint16>(32768*1.277),
        static_cast<uint16>(32768*.979),
        static_cast<uint16>(32768*.101),
        static_cast<uint16>(32768*.75)
    };

	uint32 r,g,b;
	int x;

	/* If it's not forced(only forced when the palette changes),
	don't waste cpu time if the same deemphasis bits are set as the last call.
	*/
	if(!force)
	{
		if(d==lastd)
			return;
	}
	else   /* Only set this when palette has changed. */
	{
		#ifdef _S9XLUA_H
		FCEU_LuaUpdatePalette();
		#endif

		r=rtmul[6];
		g=rtmul[6];
		b=rtmul[6];

		for(x=0;x<0x40;x++)
		{
			uint32 m,n,o;
			m=palo[x].r;
			n=palo[x].g;
			o=palo[x].b;
			m=(m*r)>>15;
			n=(n*g)>>15;
			o=(o*b)>>15;
			if(m>0xff) m=0xff;
			if(n>0xff) n=0xff;
			if(o>0xff) o=0xff;
			FCEUD_SetPalette(x|0xC0,m,n,o);
		}
	}
	if(!d) return; /* No deemphasis, so return. */

	r=rtmul[d-1];
	g=gtmul[d-1];
	b=btmul[d-1];

	for(x=0;x<0x40;x++)
	{
		uint32 m,n,o;

		m=palo[x].r;
		n=palo[x].g;
		o=palo[x].b;
		m=(m*r)>>15;
		n=(n*g)>>15;
		o=(o*b)>>15;
		if(m>0xff) m=0xff;
		if(n>0xff) n=0xff;
		if(o>0xff) o=0xff;

		FCEUD_SetPalette(x|0x40,m,n,o);
	}

	lastd=d;
	#ifdef _S9XLUA_H
	FCEU_LuaUpdatePalette();
	#endif
}

// Converted from Kevin Horton's qbasic palette generator.
static void CalculatePalette(void)
{
	//PRECONDITION: ntsc palette is enabled
 	if(!ntsccol_enable)
		return;

	int x,z;
	int r,g,b;
	double s,luma,theta;
	static uint8 cols[16]={0,24,21,18,15,12,9,6,3,0,33,30,27,0,0,0};
	static uint8 br1[4]={6,9,12,12};
	static double br2[4]={.29,.45,.73,.9};
	static double br3[4]={0,.24,.47,.77};

	for(x=0;x<=3;x++)
		for(z=0;z<16;z++)
		{
			s=(double)ntsctint/128;
			luma=br2[x];
			if(z==0)  {s=0;luma=((double)br1[x])/12;}

			if(z>=13)
			{
				s=luma=0;
				if(z==13)
					luma=br3[x];
			}

			theta=(double)M_PI*(double)(((double)cols[z]*10+ (((double)ntschue/2)+300) )/(double)180);
			r=(int)((luma+s*sin(theta))*256);
			g=(int)((luma-(double)27/53*s*sin(theta)+(double)10/53*s*cos(theta))*256);
			b=(int)((luma-s*cos(theta))*256);


			if(r>255) r=255;
			if(g>255) g=255;
			if(b>255) b=255;
			if(r<0) r=0;
			if(g<0) g=0;
			if(b<0) b=0;

			palette_ntsc[(x<<4)+z].r=r;
			palette_ntsc[(x<<4)+z].g=g;
			palette_ntsc[(x<<4)+z].b=b;
		}

	//can't call FCEU_ResetPalette(), it would be re-entrant
	//see precondition for this function
	WritePalette();
}

void FCEU_ResetPalette(void)
{
	if(GameInfo)
	{
		ChoosePalette();
		WritePalette();
	}
}

static void ChoosePalette(void)
{
	//NSF uses a fixed palette always:
	if(GameInfo->type==GIT_NSF)
		palo = default_palette[0];
	//user palette takes priority over others
	else if(palette_user_available)
		palo = palette_user;
	//NTSC takes priority next, if it's appropriate
	else if(ntsccol_enable && !PAL && GameInfo->type!=GIT_VSUNI)
	{
		//for NTSC games, we can actually use the NTSC palette
		palo = palette_ntsc;
		CalculatePalette();
	}
	//select the game's overridden palette if available
	else if(palette_game_available)
		palo = palette_game;
	//finally, use a default built-in palette
	else
	{
		palo = default_palette[default_palette_selection];
		//need to calcualte a deemph on the fly.. sorry. maybe support otherwise later
		ApplyDeemphasisComplete(palo);
	}
}

void WritePalette(void)
{
	int x;

	//set the 'unvarying' palettes to low < 64 palette entries
	for(x=0;x<7;x++)
		FCEUD_SetPalette(x,palette_unvarying[x].r,palette_unvarying[x].g,palette_unvarying[x].b);

	//clear everything else to a deterministic state.
	//it seems likely that the text rendering on NSF has been broken since the beginning of fceux, depending on palette entries 205,205,205 everywhere
	//this was just whatever msvc filled malloc with. on non-msvc platforms, there was no backdrop on the rendering.
	for(x=7;x<256;x++)
		FCEUD_SetPalette(x,205,205,205);

	//sets palette entries >= 128 with the 64 selected main colors
	for(x=0;x<64;x++)
		FCEUD_SetPalette(128+x,palo[x].r,palo[x].g,palo[x].b);
	SetNESDeemph_OldHacky(lastd,1);
	#ifdef _S9XLUA_H
	FCEU_LuaUpdatePalette();
	#endif
}

void FCEUI_GetNTSCTH(int *tint, int *hue)
{
	*tint = ntsctint;
	*hue = ntschue;
}

static int controlselect=0;
static int controllength=0;

void FCEUI_NTSCDEC(void)
{
	if(ntsccol_enable && GameInfo->type!=GIT_VSUNI &&!PAL && GameInfo->type!=GIT_NSF)
	{
		int which;
		if(controlselect)
		{
			if(controllength)
			{
				which=controlselect==1?ntschue:ntsctint;
				which--;
				if(which<0) which=0;
				if(controlselect==1)
					ntschue=which;
				else ntsctint=which;
				CalculatePalette();
			}
			controllength=360;
		}
	}
}

void FCEUI_NTSCINC(void)
{
	if(ntsccol_enable && GameInfo->type!=GIT_VSUNI && !PAL && GameInfo->type!=GIT_NSF)
		if(controlselect)
		{
			if(controllength)
			{
				switch(controlselect)
				{
				case 1:ntschue++;
					if(ntschue>128) ntschue=128;
					CalculatePalette();
					break;
				case 2:ntsctint++;
					if(ntsctint>128) ntsctint=128;
					CalculatePalette();
					break;
				}
			}
			controllength=360;
		}
}

void FCEUI_NTSCSELHUE(void)
{
	if(ntsccol_enable && GameInfo->type!=GIT_VSUNI && !PAL && GameInfo->type!=GIT_NSF){controlselect=1;controllength=360;}
}

void FCEUI_NTSCSELTINT(void)
{
	if(ntsccol_enable && GameInfo->type!=GIT_VSUNI && !PAL && GameInfo->type!=GIT_NSF){controlselect=2;controllength=360;}
}

void FCEU_DrawNTSCControlBars(uint8 *XBuf)
{
	uint8 *XBaf;
	int which=0;
	int x,x2;

	if(!controllength) return;
	controllength--;
	if(!XBuf) return;

	if(controlselect==1)
	{
		DrawTextTrans(XBuf+128-12+180*256, 256, (uint8 *)"Hue", 0x85);
		which=ntschue<<1;
	}
	else if(controlselect==2)
	{
		DrawTextTrans(XBuf+128-16+180*256, 256, (uint8 *)"Tint", 0x85);
		which=ntsctint<<1;
	}

	XBaf=XBuf+200*256;
	for(x=0;x<which;x+=2)
	{
		for(x2=6;x2>=-6;x2--)
		{
			XBaf[x-256*x2]=0x85;
		}
	}
	for(;x<256;x+=2)
	{
		for(x2=2;x2>=-2;x2--)
			XBaf[x-256*x2]=0x85;
	}
}
