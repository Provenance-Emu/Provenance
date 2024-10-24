
#include <kos.h>
#include "types.h"
#include "vector.h"
#include "texture.h"
#include "poly.h"
#include "texture.h"

static Float32 _Poly_Color[4];
static Float32 _Poly_Z = 10.0f;
static Vec2FT  _Poly_ST[2];
static TextureT *_Poly_pTexture = NULL;
static Uint32  _Poly_uMode;

static void _PolyRect_c(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
	vertex_oc_t vert;
	poly_hdr_t	poly;

	ta_poly_hdr_col(&poly, _Poly_uMode);
	pvr_prim(&poly, sizeof(poly));
	
	vert.flags = TA_VERTEX_NORMAL;
	vert.r = _Poly_Color[0]; 
	vert.g = _Poly_Color[1]; 
	vert.b = _Poly_Color[2];
	vert.a = _Poly_Color[3]; 

	vert.x = x0;
	vert.y = y0 + h;
	vert.z = _Poly_Z;
	pvr_prim(&vert, sizeof(vert));

	vert.y = y0;
	pvr_prim(&vert, sizeof(vert));

	vert.x = x0 + w;
	vert.y = y0 + h;
	pvr_prim(&vert, sizeof(vert));

	vert.flags = TA_VERTEX_EOL;
	vert.y = y0;
	pvr_prim(&vert, sizeof(vert));
}

static void _PolyRect_tc(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
	vertex_ot_t vert;

/*	poly_hdr_t	poly;
	
	ta_poly_hdr_txr((poly_hdr_t *)&poly, 
				 	_Poly_uMode,
					(_Poly_pTexture->eFormat << 27) | PVR_TXRFMT_NONTWIDDLED, 
					(1<<_Poly_pTexture->uWidthLog2), 
					(1<<_Poly_pTexture->uHeightLog2), 
					(Uint32)_Poly_pTexture->pVramAddr,  
					_Poly_pTexture->eFilter);
					*/
	pvr_poly_cxt_t context;
	pvr_poly_hdr_t poly;
	
	pvr_poly_cxt_txr(&context, 
		_Poly_uMode,
		(_Poly_pTexture->eFormat << 27) | PVR_TXRFMT_NONTWIDDLED, 
		(1<<_Poly_pTexture->uWidthLog2), 
		(1<<_Poly_pTexture->uHeightLog2), 
		_Poly_pTexture->pVramAddr,  
		_Poly_pTexture->eFilter

		);
	context.depth.comparison = PVR_DEPTHCMP_ALWAYS;
	context.depth.write      = PVR_DEPTHWRITE_DISABLE;
	context.gen.culling      = PVR_CULLING_NONE;
	context.fmt.color = PVR_CLRFMT_4FLOATS;
	context.txr.uv_clamp     = PVR_UVCLAMP_UV;
	pvr_poly_compile(&poly, &context);


	pvr_prim(&poly, sizeof(poly));

	vert.flags = TA_VERTEX_NORMAL;
	vert.r = _Poly_Color[0]; 
	vert.g = _Poly_Color[1]; 
	vert.b = _Poly_Color[2];
	vert.a = _Poly_Color[3]; 
	vert.z = _Poly_Z;

	vert.x = x0;
	vert.y = y0 + h;
	vert.u = _Poly_ST[0].vx;
	vert.v = _Poly_ST[1].vy;
	pvr_prim(&vert, sizeof(vert));

	vert.y = y0;
	vert.u = _Poly_ST[0].vx;
	vert.v = _Poly_ST[0].vy;
	pvr_prim(&vert, sizeof(vert));

	vert.x = x0 + w;
	vert.y = y0 + h;
	vert.u = _Poly_ST[1].vx;
	vert.v = _Poly_ST[1].vy;
	pvr_prim(&vert, sizeof(vert));

	vert.flags = TA_VERTEX_EOL;
	vert.y = y0;
	vert.u = _Poly_ST[1].vx;
	vert.v = _Poly_ST[0].vy;
	pvr_prim(&vert, sizeof(vert));
}





union ieee32_t {
	float flt32;
	uint32 uit32;
};

static float16 tofloat16(float f) {
	union ieee32_t float32;
	uint32 f16;
	uint32 sign, exponent, mantissa;

	float32.flt32 = f;
	sign = exponent = mantissa = float32.uit32;
	//if (exponent == 0) 
	return 0;

	sign = (sign>>16)&0x8000;
	exponent = (((exponent>>23)&0xff)-127)&0xff;
	mantissa = (mantissa>>8)&0x7f00;
	f16 = sign | mantissa | exponent;
	return (float16)f16;
}


static void _PolySprite_tc(Float32 x0, Float32 y0, Float32 w, Float32 h)
{
	pvr_sprite_t vert;
	pvr_poly_cxt_t context;
	pvr_sprite_hdr_t sprite;
	
	pvr_poly_cxt_txr(&context, 
		_Poly_uMode,
		(_Poly_pTexture->eFormat << 27) | PVR_TXRFMT_NONTWIDDLED, 
		(1<<_Poly_pTexture->uWidthLog2), 
		(1<<_Poly_pTexture->uHeightLog2), 
		_Poly_pTexture->pVramAddr,  
		_Poly_pTexture->eFilter

		);
//	context.txr.enable = PVR_TEXTURE_DISABLE;
	context.depth.comparison = PVR_DEPTHCMP_ALWAYS;
	context.depth.write      = PVR_DEPTHWRITE_DISABLE;
	context.gen.culling      = PVR_CULLING_NONE;
	context.gen.shading = 0;
	context.fmt.color = 0;
	context.fmt.uv    = PVR_UVFMT_32BIT;
//	context.txr.uv_clamp     = PVR_UVCLAMP_UV;
	pvr_poly_compile((pvr_poly_hdr_t *)&sprite, &context);
	sprite.cmd&= ~PVR_CMD_POLYHDR;
	sprite.cmd|= PVR_CMD_SPRITE;
	/*
	sprite.r = 0.0f; 
	sprite.g = 0.0f; 
	sprite.b = 0.0f;
	sprite.a = 0.5f; 
	*/
	sprite.rgba = 0xFFFFFFFF;

	pvr_prim(&sprite, sizeof(sprite));

	memset(&vert, 0x00, sizeof(vert));

	vert.flags = TA_VERTEX_EOL;
	vert.ax = x0;
	vert.ay = y0 + h;
	vert.az = _Poly_Z;

	vert.bx = x0;
	vert.by = y0;
	vert.bz = _Poly_Z;

	vert.cx = x0 + w;
	vert.cy = y0;
	vert.cz = _Poly_Z;

	vert.dx = x0 + w;
	vert.dy = y0 + h;
//	vert.dz = _Poly_Z;

	vert.au = tofloat16(_Poly_ST[0].vx);
	vert.av = tofloat16(_Poly_ST[0].vy);
	vert.bu = tofloat16(_Poly_ST[0].vx);
	vert.bv = tofloat16(_Poly_ST[0].vy);
	vert.cu = tofloat16(_Poly_ST[0].vx);
	vert.cv = tofloat16(_Poly_ST[0].vy);

	pvr_prim(&vert, sizeof(vert));
//	pvr_prim(&vert, sizeof(vert));

//	printf("%d\n", sizeof(vert));

/*
	vert.flags = TA_VERTEX_NORMAL;
	vert.r = _Poly_Color[0]; 
	vert.g = _Poly_Color[1]; 
	vert.b = _Poly_Color[2];
	vert.a = _Poly_Color[3]; 
	vert.z = _Poly_Z;

	vert.x = x0;
	vert.y = y0 + h;
	vert.u = _Poly_ST[0].vx;
	vert.v = _Poly_ST[1].vy;
	pvr_prim(&vert, sizeof(vert));

	vert.y = y0;
	vert.u = _Poly_ST[0].vx;
	vert.v = _Poly_ST[0].vy;
	pvr_prim(&vert, sizeof(vert));

	vert.x = x0 + w;
	vert.y = y0 + h;
	vert.u = _Poly_ST[1].vx;
	vert.v = _Poly_ST[1].vy;
	pvr_prim(&vert, sizeof(vert));

	vert.flags = TA_VERTEX_EOL;
	vert.y = y0;
	vert.u = _Poly_ST[1].vx;
	vert.v = _Poly_ST[0].vy;
	pvr_prim(&vert, sizeof(vert));
	*/
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
		PolyUV(0, 0, pTexture->uWidth, pTexture->uHeight);
//	printf("pt: %dx%d\n", pTexture->uWidth, pTexture->uHeight);
}

void PolyColor4f(Float32 r, Float32 g, Float32 b, Float32 a)
{
	_Poly_Color[0] = r;
	_Poly_Color[1] = g;
	_Poly_Color[2] = b;
	_Poly_Color[3] = a;
}

void PolyST(Float32 s0, Float32 t0, Float32 s1, Float32 t1)
{
	_Poly_ST[0].vx = s0;
	_Poly_ST[0].vy = t0;
	_Poly_ST[1].vx = s1;
	_Poly_ST[1].vy = t1;
}

void PolyUV(Int32 u0, Int32 v0, Int32 w, Int32 h)
{
	_Poly_ST[0].vx = ((Float32)u0) * _Poly_pTexture->fInvWidth;
	_Poly_ST[0].vy = ((Float32)v0) * _Poly_pTexture->fInvHeight;
	_Poly_ST[1].vx = ((Float32)(u0+w)) * _Poly_pTexture->fInvWidth;
	_Poly_ST[1].vy = ((Float32)(v0+h)) * _Poly_pTexture->fInvHeight;
}

void PolyMode(Uint32 uMode)
{
	_Poly_uMode = uMode;
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
		_PolySprite_tc(x0,y0,w,h);
	} else
	{
//		_PolySprite_c(x0,y0,w,h);
	}
}














