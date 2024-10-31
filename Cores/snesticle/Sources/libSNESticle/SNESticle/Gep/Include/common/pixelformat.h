
#ifndef _PIXELFORMAT_H
#define _PIXELFORMAT_H


// enum of some default pixel formats
enum PixelFormatE
{
	PIXELFORMAT_NONE,
	PIXELFORMAT_CUSTOM,
	PIXELFORMAT_CI8,
	PIXELFORMAT_BGR565,
	PIXELFORMAT_BGR555,
	PIXELFORMAT_BGR8,
	PIXELFORMAT_BGRA8,
	PIXELFORMAT_BGRA4444,
	PIXELFORMAT_RGBA5551,
	PIXELFORMAT_RGB555,
	PIXELFORMAT_RGBA8,
};

// struct representing pixel format 
struct PixelFormatT
{
	PixelFormatE	eFormat;

	Uint8	bColorIndex;
	Uint8	uBitDepth;

	Uint8	uRedShift;
	Uint8	uRedBits;

	Uint8	uGreenShift;
	Uint8	uGreenBits;

	Uint8	uBlueShift;
	Uint8	uBlueBits;

	Uint8	uAlphaShift;
	Uint8	uAlphaBits;
};

PixelFormatT *PixelFormatGetByEnum(PixelFormatE eFormat);

#endif
