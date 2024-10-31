
#include <stdio.h>
#include "types.h"
#include "vector.h"
#include "texture.h"
#include "poly.h"
#include "texture.h"
extern "C" {
#include "gs.h"
#include "gpprim.h"
};

static Float32 _Poly_Color[4];
static Uint32 _Poly_Color32;
static Float32 _Poly_Z = 10.0f;
//static Vec2FT  _Poly_ST[2];
static Vec2FT  _Poly_UV[2];
static TextureT *_Poly_pTexture = NULL;
static Uint32  _Poly_uMode;
static Uint32  _Poly_uBlend = 0;

#define FIXED4(_x) ((Int32)((_x)*16.0f))
#define FIXED7(_x) ((Int32)((_x)*128.0f))

static void _PolyRect_c(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
    Float32 x1,y1;

    x1 = x0 + w;
    y1 = y0 + h;

    GPPrimRect(
        FIXED4(x0),
        FIXED4(y0),
        _Poly_Color32,

        FIXED4(x1),
        FIXED4(y1),
        _Poly_Color32,

        FIXED4(_Poly_Z),
        _Poly_uBlend

        );
}

static void _PolyRect_tc(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
    Float32 x1,y1;

    x1 = x0 + w;
    y1 = y0 + h;

	GPPrimTexRect(
        FIXED4(x0),
        FIXED4(y0),

        FIXED4(_Poly_UV[0].vx) + 8,
        FIXED4(_Poly_UV[0].vy) + 8,

        FIXED4(x1),
        FIXED4(y1),

        FIXED4(_Poly_UV[1].vx) + 8,
        FIXED4(_Poly_UV[1].vy) + 8,

        FIXED4(_Poly_Z),

        _Poly_Color32,
        _Poly_uBlend
        );
}


void PolyInit()
{
}

void PolyShutdown()
{

}

void PolyTexture(TextureT *pTexture)
{
	_Poly_pTexture = pTexture;
	if (pTexture)
    {
		PolyUV(0, 0, pTexture->uWidth, pTexture->uHeight);

        GPPrimSetTex(
            pTexture->uVramAddr,
            pTexture->uWidth, 

            pTexture->uWidthLog2, 
            pTexture->uHeightLog2, 
            pTexture->eFormat,

            0, 256, GS_PSMCT16,
            0
           );
    }



//	printf("pt: %dx%d\n", pTexture->uWidth, pTexture->uHeight);
}

void PolyColor4f(Float32 r, Float32 g, Float32 b, Float32 a)
{
    Uint32 uR, uG, uB, uA;

    uR = FIXED7(r);
    uG = FIXED7(g);
    uB = FIXED7(b);
    uA = FIXED7(a);

	_Poly_Color[0] = r;
	_Poly_Color[1] = g;
	_Poly_Color[2] = b;
	_Poly_Color[3] = a;

    _Poly_Color32 = GS_SET_RGBA(uR, uG, uB, uA);
}



void PolyST(Float32 s0, Float32 t0, Float32 s1, Float32 t1)
{
    #if 0
	_Poly_ST[0].vx = s0;
	_Poly_ST[0].vy = t0;
	_Poly_ST[1].vx = s1;
	_Poly_ST[1].vy = t1;
    #endif

	_Poly_UV[0].vx = s0 * _Poly_pTexture->uWidth;
	_Poly_UV[0].vy = t0 * _Poly_pTexture->uHeight;
	_Poly_UV[1].vx = s1 * _Poly_pTexture->uWidth;
	_Poly_UV[1].vy = t1 * _Poly_pTexture->uHeight;

}

void PolyUV(Int32 u0, Int32 v0, Int32 w, Int32 h)
{
    #if 0
	_Poly_ST[0].vx = ((Float32)u0) * _Poly_pTexture->fInvWidth;
	_Poly_ST[0].vy = ((Float32)v0) * _Poly_pTexture->fInvHeight;
	_Poly_ST[1].vx = ((Float32)(u0+w)) * _Poly_pTexture->fInvWidth;
	_Poly_ST[1].vy = ((Float32)(v0+h)) * _Poly_pTexture->fInvHeight;
    #endif

	_Poly_UV[0].vx = ((Float32)u0);
	_Poly_UV[0].vy = ((Float32)v0);
	_Poly_UV[1].vx = ((Float32)(u0+w));
	_Poly_UV[1].vy = ((Float32)(v0+h));

}

void PolyMode(Uint32 uMode)
{
	_Poly_uMode = uMode;
}

void PolyBlend(Uint32 uBlend)
{
    _Poly_uBlend = uBlend & 1;
}

void PolyRect(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
	if (_Poly_pTexture)
	{
		_PolyRect_tc(x0,y0,w,h);
	} else
	{
		_PolyRect_c(x0,y0,w,h);
	}
}


void PolySprite(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
	if (_Poly_pTexture)
	{
//		_PolySprite_tc(x0,y0,w,h);
	} else
	{
//		_PolySprite_c(x0,y0,w,h);
	}
}














