
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include "types.h"
#include "font.h"
#include "surface.h"
#include "surface.h"
extern "C" {
#include "gs.h"
#include "gpprim.h"
#include "gpfifo.h"
};

#define FIXED4(_x) ((Int32)((_x)*16.0f))
#define FIXED7(_x) ((Int32)((_x)*128.0f))

extern unsigned char _FontData_04b16b[32768];

struct FontStateT
{
    Uint32 uColor;
	Float32 vz;
	FontT   *pFont;
};

static FontStateT _Font_State;
static FontT _Font_Default;
static FontT _Font_Fixed;
static FontT *_Font_pFonts[4];

static Int32 _FontDrawChar(FontCharT *pFontChar, float fX, float fY, float z1, Uint32 uColor, int c) 
{
	Uint32 u0,v0,u1,v1;
    Uint32 x0,y0,x1,y1;
    Int32 width;

    width = pFontChar->u1 - pFontChar->u0;

/*
	u0 = FIXED4(pFontChar->u0);
	v0 = FIXED4(pFontChar->v0);
	u1 = FIXED4(pFontChar->u1);
	v1 = FIXED4(pFontChar->v1);
  */
	u0 = pFontChar->u0 << 4;
	v0 = pFontChar->v0 << 4;
	u1 = pFontChar->u1 << 4;
	v1 = pFontChar->v1 << 4;

    u0 += 8;
    v0 += 8;
    u1 += 8;
    v1 += 8;

    x0 = FIXED4(fX);
    y0 = FIXED4(fY);

    fX += width;
    fY += pFontChar->v1 - pFontChar->v0 ;

    x1 = FIXED4(fX);
    y1 = FIXED4(fY);

    x0&=0xFFFF;
    y0&=0xFFFF;
    y1&=0xFFFF;
    x1&=0xFFFF;

	GPPrimTexRect(x0, y0, u0, v0, x1, y1, u1, v1, 10, uColor, 1);
    return width;

}

Int32 FontGetStrWidth(Char *pStr)
{
    Int32 iWidth = 0;
	FontT *pFont;
	pFont = _Font_State.pFont;
	if (!pFont) return 0;

    while (*pStr)
    {
		if (*pStr != ' ') 
		{
            FontCharT *pFontChar = &pFont->CharMap[*pStr];
			iWidth += (pFontChar->u1 - pFontChar->u0) + 1;
		} else
        {
            // swa
		    iWidth += pFont->uCharX;
        }

        pStr++;
    }
	return iWidth;
}


static void _FontDrawStr(FontT *pFont, Float32 vx, Float32 vy, Float32 vz, char *pStr, Uint32 uColor)
{
    TextureT *pTexture = &pFont->Texture;
    if (!pTexture) return;


	// Set texture/clut regs
	GPPrimSetTex(pTexture->uVramAddr, pTexture->uWidth, pTexture->uWidthLog2, pTexture->uHeightLog2, pTexture->eFormat, 0, 0, 0, 0);

	while (*pStr) 
	{
		if (*pStr != ' ') 
		{
            //if (*pStr < pFont->nChars)
            {
                FontCharT *pFontChar = &pFont->CharMap[*pStr];
                Int32 iWidth;

                iWidth =_FontDrawChar(  pFontChar, vx, vy, vz, uColor,	*pStr) + 1;

                if (pFont->uFixedWidth) iWidth = (Int32)pFont->uFixedWidth;
			    vx += iWidth;
            }
		} else
        {
		    vx+=pFont->uCharX;
        }
		pStr++;
	}
}

static void _FontSetCharMap(FontT *pFont, Uint8 uChar, Uint32 u, Uint32 v, Uint32 w, Uint32 h)
{
	pFont->CharMap[uChar].u0 = u;
	pFont->CharMap[uChar].v0 = v;
	pFont->CharMap[uChar].u1 = u + w;
	pFont->CharMap[uChar].v1 = v + h;
}

static void _FontSetCharSize(FontT *pFont, Uint32 w, Uint32 h)
{
	pFont->uCharX = w;
	pFont->uCharY = h;
}

/*
static void _FontBiosMake(FontT *pFont)
{
	int x, y;

	TextureNew(&pFont->Texture, vixar_width, vixar_height, GS_PSMT8);
    TextureSetAddr(&pFont->Texture, FONT_TEX);

	_FontSetCharSize(pFont, 8, 12);

	for (y=0; y<8; y++) {
		for (x=0; x<16; x++) 
		{
            Uint8 uChar  = y * 16 + x;
			_FontSetCharMap(pFont, uChar, x * 16, y * 16, vixarmet[uChar], 16);
//			_FontSetCharMap(pFont, uChar, x * 16, y * 16, 8, 16);
		}
	}

	gp_uploadTexture(&thegp, FONT_TEX, 256, 0, 0, GS_PSMT8, vixar_image, vixar_width, vixar_height);
	gp_uploadTexture(&thegp, FONT_CLUT, 256, 0, 0, GS_PSMCT16, vixar_clut, 256, 1);
	gp_hardflush(&thegp);
}
  */


void FontMake(FontT *pFont, CSurface *pSurface, Uint32 uVramAddr, Char *pCharList)
{
    TextureT *pTexture = &pFont->Texture;

    FontNew(pFont);
    FontParseChars(pFont, pSurface, pCharList);

    // allocate texture in GS Memory
    TextureNew(pTexture, pSurface->GetWidth(), pSurface->GetHeight(), GS_PSMCT32);
    TextureSetAddr(pTexture, uVramAddr);

    // upload texture data to memory
    TextureUpload(pTexture,  pSurface->GetLinePtr(0));
    GPFifoFlush();
}






//
//
//


void FontColor4f(Float32 r, Float32 g, Float32 b, Float32 a)
{
    Uint32 uR, uG, uB, uA;

    uR = FIXED7(r);
    uG = FIXED7(g);
    uB = FIXED7(b);
    uA = FIXED7(a);

	_Font_State.uColor = GS_SET_RGBA(uR, uG, uB, uA);
//	_Font_State.uColor = GS_SET_RGBA(0x40, 0x40, 0x40, uA);

}

void FontPuts(Float32 vx, Float32 vy, Char *pStr)
{
	FontT *pFont;
	pFont = _Font_State.pFont;
	if (!pFont) return;

	_FontDrawStr(pFont, 
				vx, vy, 15.0f, 
				pStr,
				_Font_State.uColor 
				);

}

void FontPrintf(Float32 vx, Float32 vy, Char *pFormat, ...)
{
	static char strbuf[1024];
	va_list args;
	
	va_start(args, pFormat);
	vsprintf(strbuf, pFormat, args);
	va_end(args);

	FontPuts(vx,vy,strbuf);
}

void FontSelect(Int32 iFont)
{
	_Font_State.pFont = _Font_pFonts[iFont];
}


void FontSetFont(Int32 iFont, FontT *pFont)
{
    _Font_pFonts[iFont] = pFont;
}


Int32 FontGetWidth()
{
	return _Font_State.pFont ? _Font_State.pFont->uCharX : 0;
}

Int32 FontGetHeight()
{
	return _Font_State.pFont ? _Font_State.pFont->uCharY : 0;
}


void FontInit(Uint32 uVramAddr)
{
    CSurface Surface;

    // load font data 
    Surface.Set(_FontData_04b16b, 256, 32, 256 * 4,  PixelFormatGetByEnum(PIXELFORMAT_RGBA8));

    FontMake(&_Font_Default, &Surface, uVramAddr, 
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789({[<!@#$%^&*?_+-=;,\"/~>]}).:'\\|"
            )
            ;

    FontMake(&_Font_Fixed, &Surface, uVramAddr, 
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789({[<!@#$%^&*?_+-=;,\"/~>]}).:'\\|"
            );
    _Font_Fixed.uFixedWidth = _Font_Fixed.uCharX;

    FontSetFont(0, &_Font_Default);
    FontSetFont(1, &_Font_Fixed);
    FontSetFont(2, &_Font_Default);
    FontSetFont(3, &_Font_Default);

	FontSelect(0);
	FontColor4f(1.0f, 1.0f, 1.0f, 1.0f);
}

void FontShutdown()
{
	FontDelete(&_Font_Default);
	FontDelete(&_Font_Fixed);
}



//
//
//




void FontNew(FontT *pFont)
{
//    pFont->pTexture = NULL;
//    pFont->pClut    = NULL;
    pFont->nChars   = 0;
    pFont->uFixedWidth = 0;
    memset(&pFont->CharMap, 0, sizeof(pFont->CharMap));
}

void FontDelete(FontT *pFont)
{
//    pFont->pTexture=NULL;
}

static Bool _FontScanHorizWhite(CSurface *pSurface, Uint32 uStartX, Uint32 uEndX, Uint32 uY)
{
    Uint32 uX;
    Uint32 *pLine;
    pLine = (Uint32 *)pSurface->GetLinePtr(uY);
    if (!pLine) return TRUE;

    for (uX = uStartX; uX < uEndX; uX++)
    {
        if (pLine[uX] & 0xFF000000)
        {
            return FALSE;
        }
    }

    return TRUE;
}

static Bool _FontScanVertWhite(CSurface *pSurface, Uint32 uStartY, Uint32 uEndY, Uint32 uX)
{
    Uint32 uY;
    Uint32 *pLine;

    for (uY = uStartY; uY < uEndY; uY++)
    {
        pLine = (Uint32 *)pSurface->GetLinePtr(uY);
        if (!pLine) return TRUE;

        if (pLine[uX] & 0xFF000000)
        {
            return FALSE;
        }
    }

    return TRUE;
}

Char *_FontParseLine(FontT *pFont, CSurface *pSurface, Char *pCharList, Uint32 uStartY, Uint32 uEndY)
{
    Uint32 uX;
    Uint32 uWidth, uHeight;

    uWidth = pSurface->GetWidth();
    uHeight = pSurface->GetHeight();

    uX = 0;
    while (uX < uWidth)
    {
        Uint32 uStartX, uEndX;

        // scan for non-white space
        while ((uX < uWidth) && _FontScanVertWhite(pSurface, uStartY, uEndY, uX))
        {
            uX++;
        }

        if (uX < uWidth)
        {

            // get start of char
            uStartX = uX;

            // scan for white space
            while ((uX < uWidth) && !_FontScanVertWhite(pSurface, uStartY, uEndY, uX))
            {
                uX++;
            }

            // get end of char
            uEndX = uX;

            _FontSetCharMap(pFont, *pCharList,  uStartX, uStartY, uEndX - uStartX, uEndY - uStartY);
            pCharList++;

//            printf("char %d,%d -> %d,%d\n", uStartX, uStartY, uEndX, uEndY);
            uX++;
        }
        

    }

    return pCharList;
}

void FontParseChars(FontT *pFont, CSurface *pSurface, Char *pCharList)
{
    Uint32 uY;
    Uint32 uWidth, uHeight;
    Uint32 uFontHeight = 0;

    uWidth = pSurface->GetWidth();
    uHeight = pSurface->GetHeight();

    uY=0;
    while (uY < uHeight)
    {
        Uint32 uStartY, uEndY;
        // scan for non-white space
        while ((uY < uHeight) && _FontScanHorizWhite(pSurface, 0, uWidth, uY))
        {
            uY++;
        }

        if (uY < uHeight)
        {

            // get start of line
            uStartY = uY;

            // scan for white space
            while ((uY < uHeight) && !_FontScanHorizWhite(pSurface, 0, uWidth, uY))
            {
                uY++;
            }

            uEndY = uY;

            if (uFontHeight == 0)
            {
                // font height is height of first line
                uFontHeight = uEndY - uStartY;
            }

            pCharList = _FontParseLine(pFont, pSurface, pCharList, uStartY, uEndY);
            uY++;
        }
    } 

	_FontSetCharSize(pFont, 5, uFontHeight);

}

