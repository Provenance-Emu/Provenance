
#include <stdlib.h>
#include "types.h"
#include "pixelformat.h"

static PixelFormatT _PixelFormat_CI8 =
{
	PIXELFORMAT_CI8,
	TRUE,
	8,
	 0, 8,
	 8, 8,
	16, 8,
	24, 8,
};

static PixelFormatT _PixelFormat_BGRA8 =
{
	PIXELFORMAT_BGRA8,
	FALSE,
	32,
	16, 8,
	 8, 8,
	 0, 8,
	24, 8,
};

static PixelFormatT _PixelFormat_RGBA8 =
{
	PIXELFORMAT_RGBA8,
	FALSE,
	32,
	 0, 8,
	 8, 8,
	16, 8,
	24, 8,
};

static PixelFormatT _PixelFormat_BGR8 =
{
	PIXELFORMAT_BGR8,
	FALSE,
	24,
	16, 8,
	 8, 8,
	 0, 8,
	 0, 0,
};

static PixelFormatT _PixelFormat_BGR555 =
{
	PIXELFORMAT_BGR555,
	FALSE,
	16,
	10, 5,
	 5, 5,
	 0, 5,
	15, 1,     
};

static PixelFormatT _PixelFormat_BGR565 =
{
	PIXELFORMAT_BGR565,
	FALSE,
	16,
	11, 5,
	 5, 6,
	 0, 5,
	 0, 0,
};


static PixelFormatT _PixelFormat_RGB555 =
{
	PIXELFORMAT_RGB555,
	FALSE,
	16,
	 0, 5,
	 5, 5,
	10, 5,
	 0, 0,
};

static PixelFormatT _PixelFormat_RGBA5551 =
{
	PIXELFORMAT_RGBA5551,
	FALSE,
	16,
	 0, 5,
	 5, 5,
	10, 5,
	15, 1,
};


PixelFormatT *PixelFormatGetByEnum(PixelFormatE eFormat)
{
	switch (eFormat)
	{
	case PIXELFORMAT_BGRA8:   return &_PixelFormat_BGRA8;
	case PIXELFORMAT_RGBA8:   return &_PixelFormat_RGBA8;
	case PIXELFORMAT_BGR8:    return &_PixelFormat_BGR8;
	case PIXELFORMAT_BGR555:  return &_PixelFormat_BGR555;
	case PIXELFORMAT_BGR565:  return &_PixelFormat_BGR565;
	case PIXELFORMAT_RGBA5551:  return &_PixelFormat_RGBA5551;
	case PIXELFORMAT_RGB555:  return &_PixelFormat_RGB555;
	case PIXELFORMAT_CI8:     return &_PixelFormat_CI8;
	default:
		return NULL;
	};
}






