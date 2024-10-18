
#include <kos.h>
#include "types.h"
#include "font.h"

struct FontStateT
{
	Float32 r,g,b,a;
	Float32 vz;
	FontT   *pFont;
};

static FontStateT _Font_State;
static FontT _Font_Bios;
static FontT _Font_Fonts[4];

FontT *FontGetBios()
{
	return &_Font_Bios;
}

static void _FontDrawChar(FontT *pFont, float x1, float y1, float z1, float a, float r, float g, float b, int c) 
{
	vertex_ot_t	vert;
	Float32 u1,v1,u2,v2;
	Float32 fCharX, fCharY;

	fCharX = pFont->uCharX;
	fCharY = pFont->uCharY;

	u1 = ((Float32)pFont->CharMap[c].u0) * pFont->Texture.fInvWidth; 
	v1 = ((Float32)pFont->CharMap[c].v0) * pFont->Texture.fInvHeight;
	u2 = ((Float32)pFont->CharMap[c].u1) * pFont->Texture.fInvWidth; 
	v2 = ((Float32)pFont->CharMap[c].v1) * pFont->Texture.fInvHeight;

	vert.flags = TA_VERTEX_NORMAL;
	vert.x = x1;
	vert.y = y1 + fCharY;
	vert.z = z1;
	vert.u = u1;
	vert.v = v2;
	vert.dummy1 = vert.dummy2 = 0;
	vert.a = a;
	vert.r = r;
	vert.g = g;
	vert.b = b;
	vert.oa = vert.or = vert.og = vert.ob = 0.0f;
	pvr_prim(&vert, sizeof(vert));
	
	vert.x = x1;
	vert.y = y1;
	vert.u = u1;
	vert.v = v1;
	pvr_prim(&vert, sizeof(vert));
	
	vert.x = x1 + fCharX;
	vert.y = y1 + fCharY;
	vert.u = u2;
	vert.v = v2;
	pvr_prim(&vert, sizeof(vert));

	vert.flags = TA_VERTEX_EOL;
	vert.x = x1 + fCharX;
	vert.y = y1;
	vert.u = u2;
	vert.v = v1;
	pvr_prim(&vert, sizeof(vert));
}


static void _FontDrawStr(FontT *pFont, Float32 vx, Float32 vy, Float32 vz, char *pStr, Float32 a, Float32 r, Float32 g, Float32 b)
{
	pvr_poly_hdr_t poly;
	TextureT *pTexture = &pFont->Texture;

	ta_poly_hdr_txr((poly_hdr_t *)&poly, 
		TA_TRANSLUCENT, 
		(pTexture->eFormat << 27) | PVR_TXRFMT_NONTWIDDLED, 
		(1<<pTexture->uWidthLog2), 
		(1<<pTexture->uHeightLog2), 
		(Uint32)pTexture->pVramAddr, 
		pTexture->eFilter
		);
	pvr_prim(&poly, sizeof(poly));
	while (*pStr) 
	{
		if (*pStr != ' ') 
		{
			_FontDrawChar(
				pFont,
				vx, vy, 15.0f, 
				a, r, g, b, 
		    	*pStr
		    	);
		}

		vx+=pFont->uCharX;
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

static void _FontBiosDraw(uint16 *buffer, int bufwidth, int opaque, int c) {
	uint8 *ch = (uint8*)bfont_find_char(c);
	uint16 word;
	int x, y;

	for (y=0; y<24; ) {
		/* Do the first row */
		word = (((uint16)ch[0]) << 4) | ((ch[1] >> 4) & 0x0f);
		for (x=0; x<12; x++) {
			if (word & (0x0800 >> x))
				*buffer = 0xffff;
			else {
				*buffer = 0x0fff;
			}
			buffer++;
		}
		buffer += bufwidth - 12;
		y++;
		
		/* Do the second row */
		word = ( (((uint16)ch[1]) << 8) & 0xf00) | ch[2];
		for (x=0; x<12; x++) {
			if (word & (0x0800 >> x))
				*buffer = 0xffff;
			else {
				*buffer = 0x0fff;
			}
			buffer++;
		}
		buffer += bufwidth - 12;
		y++;
		
		ch += 3;
	}
}

static void _FontBiosMake(FontT *pFont)
{
	uint16 *vram;
	int x, y;

	TextureNew(&pFont->Texture, 256, 256, TEX_FORMAT_ARGB4444);

	_FontSetCharSize(pFont, 12, 24);

	vram = (uint16 *)TextureGetData(&pFont->Texture);
	for (y=0; y<8; y++) {
		for (x=0; x<16; x++) 
		{
			_FontSetCharMap(pFont, y*16 + x, x * 16, y * 24, 12, 24);
			_FontBiosDraw(vram, 256, 0, y*16+x);
			vram += 16;
		}
		vram += 23*256;
	}
}

static void _FontClone(FontT *pDest, FontT *pSrc)
{
	memcpy(pDest, pSrc, sizeof(FontT));
}


//
//
//


void FontColor4f(Float32 r, Float32 g, Float32 b, Float32 a)
{
	_Font_State.r = r;
	_Font_State.g = g;
	_Font_State.b = b;
	_Font_State.a = a;
}

void FontPuts(Float32 vx, Float32 vy, Char *pStr)
{
	FontT *pFont;
	pFont = _Font_State.pFont;
	if (!pFont) return;

	_FontDrawStr(pFont, 
				vx + 1.0f, vy + 1.0f, 18.0f, 
				pStr,
				_Font_State.a, 0.0f, 0.0f, 0.0f
				);

	_FontDrawStr(pFont, 
				vx, vy, 15.0f, 
				pStr,
				_Font_State.a, 
				_Font_State.r, 
				_Font_State.g, 
				_Font_State.b
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
	_Font_State.pFont = &_Font_Fonts[iFont];
}

Int32 FontGetWidth()
{
	return _Font_State.pFont->uCharX;
}

Int32 FontGetHeight()
{
	return _Font_State.pFont->uCharY;
}


void FontDelete(FontT *pFont)
{
	TextureDelete(&pFont->Texture);
}


void FontInit()
{
	Uint32 texture;

	_FontBiosMake(&_Font_Bios);

	_FontClone(&_Font_Fonts[0], &_Font_Bios);
	_FontClone(&_Font_Fonts[1], &_Font_Bios);
	_FontClone(&_Font_Fonts[2], &_Font_Bios);
	_FontClone(&_Font_Fonts[3], &_Font_Bios);

	_FontSetCharSize(&_Font_Fonts[0], FONT_WIDTH, FONT_HEIGHT);
	_FontSetCharSize(&_Font_Fonts[1], 12, 12);
	_FontSetCharSize(&_Font_Fonts[2], 8, 8);
	_FontSetCharSize(&_Font_Fonts[3], 12, 12);

	FontSelect(0);
	FontColor4f(1.0f, 1.0f, 1.0f, 1.0f);
}

void FontShutdown()
{
	FontDelete(&_Font_Bios);
}
