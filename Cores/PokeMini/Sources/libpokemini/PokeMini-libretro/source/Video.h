/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef POKEMINI_VIDEO
#define POKEMINI_VIDEO

#include <stdint.h>

#define GetValL24(a) ((a) & 255)
#define GetValM24(a) (((a) >> 8) & 255)
#define GetValH24(a) (((a) >> 16) & 255)
#ifndef RGB24
#define RGB24(r, g, b) ((r) | ((g) << 8) | ((b) << 16))
#endif

#define GetValL16(a) ((a) & 31)
#define GetValM16(a) (((a) >> 5) & 63)
#define GetValH16(a) (((a) >> 11) & 31)
#ifndef RGB16
#define RGB16(r, g, b) ((r) | ((g) << 5) | ((b) << 11))
#endif

#define GetValL15(a) ((a) & 31)
#define GetValM15(a) (((a) >> 5) & 31)
#define GetValH15(a) (((a) >> 10) & 31)
#ifndef RGB15
#define RGB15(r, g, b) ((r) | ((g) << 5) | ((b) << 10))
#endif

typedef void (*TPokeMini_DrawVideo16)(uint16_t *, int);
typedef void (*TPokeMini_DrawVideo32)(uint32_t *, int);
typedef void (*TPokeMini_DrawVideoPtr)(void *, int);

typedef TPokeMini_DrawVideo16 (*TPokeMini_GetVideo16)(int, int);
typedef TPokeMini_DrawVideo32 (*TPokeMini_GetVideo32)(int, int);

typedef struct {
	int WScale;
	int HScale;
	TPokeMini_GetVideo16 Get16;
	TPokeMini_GetVideo32 Get32;
} TPokeMini_VideoSpec;

#ifndef inline
#define inline __inline
#endif

static inline int Interpolate8(int a, int b, int pos)
{
	return ((255-pos) * a + pos * b) >> 8;
}

static inline int Interpolate16(int a, int b, int pos)
{
	return ((255-pos) * a + pos * b) >> 16;
}

static inline uint32_t InterpolateRGB24(uint32_t src, uint32_t des, int dir)
{
	int r = Interpolate8((int)GetValL24(src), (int)GetValL24(des), dir);
	int g = Interpolate8((int)GetValM24(src), (int)GetValM24(des), dir);
	int b = Interpolate8((int)GetValH24(src), (int)GetValH24(des), dir);
	return RGB24(r, g, b);
}

static inline uint16_t InterpolateRGB16(uint16_t src, uint16_t des, int dir)
{
	int r = Interpolate8((int)GetValL16(src), (int)GetValL16(des), dir);
	int g = Interpolate8((int)GetValM16(src), (int)GetValM16(des), dir);
	int b = Interpolate8((int)GetValH16(src), (int)GetValH16(des), dir);
	return RGB16(r, g, b);
}

static inline uint16_t InterpolateRGB15(uint16_t src, uint16_t des, int dir)
{
	int r = Interpolate8((int)GetValL15(src), (int)GetValL15(des), dir);
	int g = Interpolate8((int)GetValM15(src), (int)GetValM15(des), dir);
	int b = Interpolate8((int)GetValH15(src), (int)GetValH15(des), dir);
	return RGB15(r, g, b) | 0x8000;
}

// For Graphics Filtering
enum {
	PokeMini_NoFilter = 0,
	PokeMini_Matrix,
	PokeMini_Scanline
};

// For Pixel Layout
enum {
	PokeMini_BGR16 = 0,
	PokeMini_RGB16,
	PokeMini_RGB15,
	PokeMini_BGR32 = 16,
	PokeMini_RGB32
};

extern int VidPixelLayout;
extern int VidEnableHighcolor;
extern uint32_t *VidPalette32;
extern uint16_t *VidPalette16;
extern uint32_t *VidPalColor32;
extern uint16_t *VidPalColor16;
extern uint32_t *VidPalColorH32;
extern uint16_t *VidPalColorH16;
extern TPokeMini_VideoSpec *PokeMini_VideoCurrent;
extern int PokeMini_VideoDepth;
extern TPokeMini_DrawVideo16 PokeMini_VideoBlit16;
extern TPokeMini_DrawVideo32 PokeMini_VideoBlit32;
extern TPokeMini_DrawVideoPtr PokeMini_VideoBlit;

// Set video, return bpp
int PokeMini_SetVideo(TPokeMini_VideoSpec *videospec, int bpp, int filter, int lcdmode);

// Drawing rectangle
void PokeMini_VideoRect_32(uint32_t *screen, int pitchW, int x, int y, int width, int height, uint32_t color);
void PokeMini_VideoRect_16(uint16_t *screen, int pitchW, int x, int y, int width, int height, uint16_t color);

// Video palette handling
void PokeMini_VideoPalette_Init(int pixellayout, int enablehighcolor);
void PokeMini_VideoPalette_32(uint32_t P0Color, uint32_t P1Color, int contrastboost, int brightoffset);
void PokeMini_VideoPalette_16(uint16_t P0Color, uint16_t P1Color, int contrastboost, int brightoffset);
void PokeMini_VideoPalette_Index(int index, uint32_t *CustomMonoPal, int contrastboost, int brightoffset);
void PokeMini_VideoPalette_Free(void);

// Render to a preview 96x64 buffer
void PokeMini_VideoPreview_32(uint32_t *screen, int pitchW, int lcdmode);
void PokeMini_VideoPreview_16(uint16_t *screen, int pitchW, int lcdmode);
void PokeMini_VideoPreviewA_32(uint32_t *screen, int pitchW);
void PokeMini_VideoPreviewA_16(uint16_t *screen, int pitchW);
void PokeMini_VideoPreview2_32(uint32_t *screen, int pitchW);
void PokeMini_VideoPreview2_16(uint16_t *screen, int pitchW);
void PokeMini_VideoPreview3_32(uint32_t *screen, int pitchW);
void PokeMini_VideoPreview3_16(uint16_t *screen, int pitchW);
void PokeMini_VideoPreviewC_32(uint32_t *screen, int pitchW);
void PokeMini_VideoPreviewC_16(uint16_t *screen, int pitchW);
void PokeMini_VideoPreviewCH_32(uint32_t *screen, int pitchW);
void PokeMini_VideoPreviewCH_16(uint16_t *screen, int pitchW);

#endif
