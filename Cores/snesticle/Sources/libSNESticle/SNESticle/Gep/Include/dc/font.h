
#ifndef _FONT_H
#define _FONT_H

#include "texture.h"

struct FontCharT
{
	Uint8 u0, v0;
	Uint8 u1, v1;
};

struct FontT 
{
	TextureT 	Texture;
	FontCharT	CharMap[256];
	Int32	 	uCharX, uCharY;
};

#define FONT_WIDTH 12
#define FONT_HEIGHT 12

void FontInit();
void FontShutdown();

Int32 FontGetHeight();
Int32 FontGetWidth();

void FontSelect(Int32 iFont);
void FontPrintf(Float32 vx, Float32 vy, Char *pFormat, ...);
void FontPuts(Float32 vx, Float32 vy, Char *pStr);
void FontColor4f(Float32 r, Float32 g, Float32 b, Float32 a);

#endif
