

#ifndef _TEXTURE_H
#define _TEXTURE_H

typedef Uint32 TexFormatE;

struct TextureT
{
	Uint32		uWidthLog2, uHeightLog2;
	Uint32		uWidth, uHeight;
	TexFormatE	eFormat;
	Uint32		eFilter;

    Uint32      uVramAddr;      // address in vram
	Uint32		uPitch;
	Uint32		nBytes;

	Float32		fInvWidth, fInvHeight;
};


struct ClutT
{
	Uint32		uWidth, uHeight;
	TexFormatE	eFormat;

    Uint32      uVramAddr;      // address in vram
	Uint32		uPitch;
	Uint32		nBytes;
};

void TextureNew(TextureT *pTexture, Uint32 uWidth, Uint32 uHeight, TexFormatE eTexFormat);
void TextureDelete(TextureT *pTexture);
Uint32 TextureGetAddr(TextureT *pTexture);
void TextureSetAddr(TextureT *pTexture, Uint32 uAddr);
void TextureSetFilter(TextureT *pTexture, Uint32 eFilter);
void TextureUpload(TextureT *pTexture, Uint8 *pData);

#endif

