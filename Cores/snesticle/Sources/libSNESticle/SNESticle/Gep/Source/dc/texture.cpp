
#include <kos.h>
#include "types.h"
#include "texture.h"
#include "pixelformat.h"
#include "surface.h"
#include "surface.h"
#include "bmpfile.h"

static Uint8 _Texture_BPP[TEX_FORMAT_NUM] = 
{
	16, // PVR_TXRFMT_ARGB1555 
	16, // PVR_TXRFMT_RGB565   
	16, // PVR_TXRFMT_ARGB4444 
	 8, // PVR_TXRFMT_YUV422   
	16, // PVR_TXRFMT_BUMP	   
	 4, // PVR_TXRFMT_PAL4BPP  
	 8, // PVR_TXRFMT_PAL8BPP  
	 0, // PVR_TXRFMT_RESERVED 
};


static PixelFormatT _Texture_Fmt_ARGB1555=
{
	PIXELFORMAT_BGR555,
	FALSE,
	16,
	10, 5,
	 5, 5,
	 0, 5,
	15, 1,
};



static PixelFormatT _Texture_Fmt_RGB565 =
{
	PIXELFORMAT_BGR565,
	FALSE,
	16,
	11, 5,
	 5, 6,
	 0, 5,
	 0, 0,
};


static PixelFormatT _Texture_Fmt_ARGB4444 =
{
	PIXELFORMAT_BGRA4444,
	FALSE,
	16,
	 8, 4,
	 4, 4,
	 0, 4,
	12, 4,
};


static PixelFormatT *_Texture_PixelFormat[TEX_FORMAT_NUM] =
{
	&_Texture_Fmt_ARGB1555,
	&_Texture_Fmt_RGB565  ,
	&_Texture_Fmt_ARGB4444,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
};



static void _Convert_RGBA4444_BGR8(CSurface *pDst, CSurface *pSrc)
{
	Int32 iLine, nLines;

	pSrc->Lock();
	pDst->Lock();

	nLines = pSrc->GetHeight();
	for (iLine=0; iLine < nLines; iLine++)
	{
		Uint16 *pOut;
		Uint8 *pIn;
		Int32 iPixel, nPixels;
		Uint16 color = 0;

		pOut = (Uint16 *)pDst->GetLinePtr(iLine);
		pIn  = (Uint8  *)pSrc->GetLinePtr(iLine);

		nPixels = pSrc->GetWidth();
		for (iPixel=0; iPixel < nPixels; iPixel++)
		{	
			Uint32 r,g,b,a;

			r = (pIn[2] >> 4) & 0x0F;
			g = (pIn[1] >> 4) & 0x0F;
			b = (pIn[0] >> 4) & 0x0F;
			a = 0xF;
			color = (a<<12) | (r<<8) | (g<<4) | (b<<0);

			*pOut++ = color;
			pIn+=3;
		} 
		
		// fill to end of line
		nPixels = pDst->GetWidth();
		for (; iPixel < nPixels; iPixel++)
		{	
			*pOut++ = color;
		} 

	}
	pDst->Unlock();
	pSrc->Unlock();
}


static void _Convert_RGB565_BGR8(CSurface *pDst, CSurface *pSrc)
{
	Int32 iLine, nLines;

	pSrc->Lock();
	pDst->Lock();

	nLines = pSrc->GetHeight();
	for (iLine=0; iLine < nLines; iLine++)
	{
		Uint16 *pOut;
		Uint8 *pIn;
		Int32 iPixel, nPixels;
		Uint16 color = 0;

		pOut = (Uint16 *)pDst->GetLinePtr(iLine);
		pIn  = (Uint8  *)pSrc->GetLinePtr(iLine);

		nPixels = pSrc->GetWidth();
		for (iPixel=0; iPixel < nPixels; iPixel++)
		{	
			Uint32 r,g,b,a;

			r = (pIn[2] >> 3) & 0x1F;
			g = (pIn[1] >> 2) & 0x3F;
			b = (pIn[0] >> 3) & 0x1F;
			a = 0;

			color = (a<<16) | (r<<11) | (g<<5) | (b<<0);

			*pOut++ = color;
			pIn+=3;
		} 
		
		// fill to end of line
		nPixels = pDst->GetWidth();
		for (; iPixel < nPixels; iPixel++)
		{	
			*pOut++ = color;
		} 
	}
	pDst->Unlock();
	pSrc->Unlock();
}



static void _Convert_ARGB1555_BGR8(CSurface *pDst, CSurface *pSrc)
{
	Int32 iLine, nLines;

	pSrc->Lock();
	pDst->Lock();

	nLines = pSrc->GetHeight();
	for (iLine=0; iLine < nLines; iLine++)
	{
		Uint16 *pOut;
		Uint8 *pIn;
		Int32 iPixel, nPixels;
		Uint16 color = 0;

		pOut = (Uint16 *)pDst->GetLinePtr(iLine);
		pIn  = (Uint8  *)pSrc->GetLinePtr(iLine);

		nPixels = pSrc->GetWidth();
		for (iPixel=0; iPixel < nPixels; iPixel++)
		{	
			Uint32 r,g,b,a;

			r = (pIn[2] >> 3) & 0x1F;
			g = (pIn[1] >> 3) & 0x1F;
			b = (pIn[0] >> 3) & 0x1F;
			a = 1;

			if (pIn[0]==255 && pIn[1]==0 && pIn[2]==255) a=0;

			color = (a<<15) | (r<<10) | (g<<5) | (b<<0);

			*pOut++ = color;
			pIn+=3;
		} 
		
		// fill to end of line
		nPixels = pDst->GetWidth();
		for (; iPixel < nPixels; iPixel++)
		{	
			*pOut++ = color;
		} 
	}
	pDst->Unlock();
	pSrc->Unlock();
}






static Uint32 _TextureLog2(Uint32 uVal)
{
	Uint32 n=0;

	while (uVal > (1<<n))
	{
		n++;
	}
	return n;	
}


void TextureNew(TextureT *pTexture, Uint32 uWidth, Uint32 uHeight, TexFormatE eTexFormat)
{
	Uint32 uWidthPow2, uHeightPow2;

	assert(eTexFormat < TEX_FORMAT_NUM);

	pTexture->uWidth  		= uWidth;
	pTexture->uHeight 		= uHeight;
	pTexture->uWidthLog2  	= _TextureLog2(uWidth);
	pTexture->uHeightLog2 	= _TextureLog2(uHeight);
	pTexture->eFormat		= eTexFormat;

	uWidthPow2  = (1<<pTexture->uWidthLog2);
	uHeightPow2 = (1<<pTexture->uHeightLog2);

	pTexture->fInvWidth 	= 1.0f / ((Float32)uWidthPow2);
	pTexture->fInvHeight	= 1.0f / ((Float32)uHeightPow2);

	pTexture->eFilter   	= TA_BILINEAR_FILTER;
//	pTexture->eFilter   	= TA_NO_FILTER;

	pTexture->uPitch    	= uWidthPow2 * _Texture_BPP[pTexture->eFormat] / 8;
	pTexture->nBytes 		= pTexture->uPitch * uHeightPow2;

	// allocate memory for texture data
	pTexture->pVramAddr = (void *)pvr_mem_malloc(pTexture->nBytes);

	printf("%dx%d %08X\n", uWidthPow2, uHeightPow2, pTexture->pVramAddr);
}


void TextureCopy(TextureT *pTexture, CSurface *pSurface)
{
	CMemSurface TexSurface;
	PixelFormatT *pSrcFmt, *pDstFmt;

	// create surface for texture
	TexSurface.Set((Uint8 *)TextureGetData(pTexture), 1 << pTexture->uWidthLog2, 1 << pTexture->uHeightLog2, pTexture->uPitch, _Texture_PixelFormat[pTexture->eFormat]);

	pSrcFmt = pSurface->GetFormat();
	pDstFmt = TexSurface.GetFormat();

	if (pSrcFmt->eFormat == PIXELFORMAT_BGR8 && pDstFmt->eFormat==PIXELFORMAT_BGRA4444)
	{
		_Convert_RGBA4444_BGR8(&TexSurface, pSurface);
	} else
	if (pSrcFmt->eFormat == PIXELFORMAT_BGR8 && pDstFmt->eFormat==PIXELFORMAT_BGR565)
	{
		_Convert_RGB565_BGR8(&TexSurface, pSurface);
	} else
	if (pSrcFmt->eFormat == PIXELFORMAT_BGR8 && pDstFmt->eFormat==PIXELFORMAT_BGR555)
	{
		_Convert_ARGB1555_BGR8(&TexSurface, pSurface);
	} 
}



Bool TextureLoad(TextureT *pTexture, Char *pTexFile)
{
	CMemSurface surface;
	
	if (BMPReadFile(pTexFile, &surface))
	{
		printf("BMP: %dx%d %s\n", surface.GetWidth(), surface.GetHeight(), pTexFile);
		TextureNew(pTexture, surface.GetWidth(), surface.GetHeight(), TEX_FORMAT_ARGB1555);
		TextureCopy(pTexture, &surface);
		return TRUE;
	} else
	{
		return FALSE;
	}
}




void TextureDelete(TextureT *pTexture)
{
	if (pTexture->pVramAddr)
	{
		pvr_mem_free(pTexture->pVramAddr);
		pTexture->pVramAddr = NULL;
	}
}

void *TextureGetData(TextureT *pTexture)
{
	return pTexture->pVramAddr;
}

void TextureSetFilter(TextureT *pTexture, Uint32 eFilter)
{
	pTexture->eFilter = eFilter;
}






/*												   
	{
		uint16 *texture;
		int x, y;
		texture = (uint16*)ta_txr_map(_frametex[0]);
		for (y=0; y<256; y++)
			for (x=0; x<256; x++) {
				int v = ((x*4)^(y*4)) & 255;
				*texture++ = ((v >> 3) << 11)
					| ((v >> 2) << 5)
					| ((v >> 3) << 0); 
			}
	}*/

