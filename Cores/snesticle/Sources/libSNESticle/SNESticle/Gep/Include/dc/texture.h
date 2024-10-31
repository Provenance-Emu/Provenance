

#ifndef _TEXTURE_H
#define _TEXTURE_H

enum TexFormatE
{
	TEX_FORMAT_ARGB1555 = 0,
	TEX_FORMAT_RGB565	= 1,
	TEX_FORMAT_ARGB4444	= 2,
	TEX_FORMAT_YUV422	= 3,
	TEX_FORMAT_BUMP		= 4,
	TEX_FORMAT_PAL4BPP	= 5,
	TEX_FORMAT_PAL8BPP	= 6,
	TEX_FORMAT_RESERVED	= 7,

	TEX_FORMAT_NUM
};

struct TextureT
{
	Uint32		uWidthLog2, uHeightLog2;
	Uint32		uWidth, uHeight;
	TexFormatE	eFormat;
	Uint32		eFilter;

	void		*pVramAddr;		// address in vram
	Uint32		uPitch;
	Uint32		nBytes;

	Float32		fInvWidth, fInvHeight;
};

void TextureNew(TextureT *pTexture, Uint32 uWidth, Uint32 uHeight, TexFormatE eTexFormat);
void TextureDelete(TextureT *pTexture);
void *TextureGetData(TextureT *pTexture);
void TextureSetFilter(TextureT *pTexture, Uint32 eFilter);
void TextureCopy(TextureT *pTexture, class CSurface *pSurface);
Bool TextureLoad(TextureT *pTexture, Char *pTexFile);

#endif
