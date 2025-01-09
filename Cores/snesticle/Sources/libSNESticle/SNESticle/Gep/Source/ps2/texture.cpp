
#include <stdio.h>
#include "types.h"
#include "texture.h"
#include "surface.h"
extern "C" {
#include "gpprim.h"
};


static Uint32 _TextureLog2(Uint32 uVal)
{
	Uint32 n=0;

	while (uVal > (Uint32)(1<<n))
	{
		n++;
	}
	return n;	
}


void TextureNew(TextureT *pTexture, Uint32 uWidth, Uint32 uHeight, TexFormatE eTexFormat)
{
	Uint32 uWidthPow2, uHeightPow2;

//	assert(eTexFormat < TEX_FORMAT_NUM);

	pTexture->uWidth  		= uWidth;
	pTexture->uHeight 		= uHeight;
	pTexture->uWidthLog2  	= _TextureLog2(uWidth);
	pTexture->uHeightLog2 	= _TextureLog2(uHeight);
	pTexture->eFormat		= eTexFormat;

	uWidthPow2  = (1<<pTexture->uWidthLog2);
	uHeightPow2 = (1<<pTexture->uHeightLog2);

	pTexture->fInvWidth 	= 1.0f / ((Float32)uWidthPow2);
	pTexture->fInvHeight	= 1.0f / ((Float32)uHeightPow2);

	pTexture->eFilter   	= 0;
	pTexture->uPitch    	= 0;
	pTexture->nBytes 		= pTexture->uPitch * uHeightPow2;

	// allocate memory for texture data
	pTexture->uVramAddr = 0;

}

void TextureSetAddr(TextureT *pTexture, Uint32 uAddr)
{
    pTexture->uVramAddr = uAddr;
}


void TextureUpload(TextureT *pTexture, Uint8 *pData)
{
    GPPrimUploadTexture(
            pTexture->uVramAddr, 
            pTexture->uWidth, 
            0, 0, 
            pTexture->eFormat, 
            pData, 
            pTexture->uWidth, 
            pTexture->uHeight
            );

}


void TextureDelete(TextureT *pTexture)
{
    #if 0
	if (pTexture->pVramAddr)
	{
		pvr_mem_free(pTexture->pVramAddr);
		pTexture->pVramAddr = NULL;
	}
    #endif
}

Uint32 TextureGetAddr(TextureT *pTexture)
{
	return pTexture->uVramAddr;
}

void TextureSetFilter(TextureT *pTexture, Uint32 eFilter)
{
	pTexture->eFilter = eFilter;
}




