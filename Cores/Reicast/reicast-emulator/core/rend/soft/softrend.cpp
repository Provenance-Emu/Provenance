#include <omp.h>
#include "hw/pvr/Renderer_if.h"
#include "hw/pvr/pvr_mem.h"
#include "oslib/oslib.h"

/*
	SSE/MMX based softrend

	Initial code by skmp and gigaherz

	This is a rather weird very basic pvr softrend.
	Renders	in some kind of tile format (that I forget now),
	and does depth and color, but no alpha, texture, or pixel
	processing. All of the pipeline is based on quads.
*/

#include <mmintrin.h>
#include <xmmintrin.h>
#include <emmintrin.h>
#include <smmintrin.h>

#include <cmath>

#include "rend/gles/gles.h"

u32 decoded_colors[3][65536];

#define MAX_RENDER_WIDTH 640
#define MAX_RENDER_HEIGHT 480
#define MAX_RENDER_PIXELS (MAX_RENDER_WIDTH * MAX_RENDER_HEIGHT)

#define STRIDE_PIXEL_OFFSET MAX_RENDER_WIDTH
#define Z_BUFFER_PIXEL_OFFSET MAX_RENDER_PIXELS

DECL_ALIGN(32) u32 render_buffer[MAX_RENDER_PIXELS * 2]; //Color + depth
DECL_ALIGN(32) u32 pixels[MAX_RENDER_PIXELS];

#if HOST_OS != OS_WINDOWS

struct RECT {
	int left, top, right, bottom;
};

#include     <X11/Xlib.h>
#endif

union m128i {
	__m128i mm;
	int8_t m128i_u8[16];
	int8_t m128i_i8[16];
	int16_t m128i_i16[8];
	int32_t m128i_i32[4];
	uint32_t m128i_u32[4];
};

static __m128 _mm_load_scaled_float(float v, float s)
{
	return _mm_setr_ps(v, v + s, v + s + s, v + s + s + s);
}
static __m128 _mm_broadcast_float(float v)
{
	return _mm_setr_ps(v, v, v, v);
}
static __m128i _mm_broadcast_int(int v)
{
	__m128i rv = _mm_cvtsi32_si128(v);
	return _mm_shuffle_epi32(rv, 0);
}
static __m128 _mm_load_ps_r(float a, float b, float c, float d)
{
	DECL_ALIGN(128) float v[4];
	v[0] = a;
	v[1] = b;
	v[2] = c;
	v[3] = d;

	return _mm_load_ps(v);
}

__forceinline int iround(float x)
{
	return _mm_cvtt_ss2si(_mm_load_ss(&x));
}

float mmin(float a, float b, float c, float d)
{
	float rv = min(a, b);
	rv = min(c, rv);
	return max(d, rv);
}

float mmax(float a, float b, float c, float d)
{
	float rv = max(a, b);
	rv = max(c, rv);
	return min(d, rv);
}

//i think this gives false positives ...
//yup, if ANY of the 3 tests fail the ANY tests fails.
__forceinline void EvalHalfSpace(bool& all, bool& any, float cp, float sv, float lv)
{
	//bool a00 = C1 + DX12 * y0 - DY12 * x0 > 0;
	//bool a10 = C1 + DX12 * y0 - DY12 * x0 > qDY12;
	//bool a01 = C1 + DX12 * y0 - DY12 * x0 > -qDX12;
	//bool a11 = C1 + DX12 * y0 - DY12 * x0 > (qDY12-qDX12);

	//C1 + DX12 * y0 - DY12 * x0 > 0
	// + DX12 * y0 - DY12 * x0 > 0 - C1
	//int pd=DX * y0 - DY * x0;

	bool a = cp > sv;	//needed for ANY
	bool b = cp > lv;	//needed for ALL

	any &= a;
	all &= b;
}

//return true if any is positive
__forceinline bool EvalHalfSpaceFAny(float cp12, float cp23, float cp31)
{
	bool svt = cp12 > 0; //needed for ANY
	svt |= cp23 > 0;
	svt |= cp31 > 0;

	return svt;
}

__forceinline bool EvalHalfSpaceFAll(float cp12, float cp23, float cp31, float lv12, float lv23, float lv31)
{
	bool lvt = (cp12 - lv12) > 0;
	lvt &= (cp23 - lv23) > 0;
	lvt &= (cp31 - lv31) > 0;	//needed for all

	return lvt;
}

__forceinline void PlaneMinMax(float& MIN, float& MAX, float DX, float DY, float q)
{
	float q_fp = (q - 1);
	float v1 = 0;
	float v2 = q_fp*DY;
	float v3 = -q_fp*DX;
	float v4 = q_fp*(DY - DX);

	MIN = min(v1, min(v2, min(v3, v4)));
	MAX = max(v1, max(v2, max(v3, v4)));
}

struct PlaneStepper
{
	__m128 ddx, ddy;
	__m128 c;

	void Setup(const Vertex &v1, const Vertex &v2, const Vertex &v3, int minx, int miny, int q
		, float v1_a, float v2_a, float v3_a
		, float v1_b, float v2_b, float v3_b
		, float v1_c, float v2_c, float v3_c
		, float v1_d, float v2_d, float v3_d)
	{
		//			float v1_z=v1.z,v2_z=v2.z,v3_z=v3.z;
		float Aa = ((v3_a - v1_a) * (v2.y - v1.y) - (v2_a - v1_a) * (v3.y - v1.y));
		float Ba = ((v3.x - v1.x) * (v2_a - v1_a) - (v2.x - v1.x) * (v3_a - v1_a));

		float Ab = ((v3_b - v1_b) * (v2.y - v1.y) - (v2_b - v1_b) * (v3.y - v1.y));
		float Bb = ((v3.x - v1.x) * (v2_b - v1_b) - (v2.x - v1.x) * (v3_b - v1_b));

		float Ac = ((v3_c - v1_c) * (v2.y - v1.y) - (v2_c - v1_c) * (v3.y - v1.y));
		float Bc = ((v3.x - v1.x) * (v2_c - v1_c) - (v2.x - v1.x) * (v3_c - v1_c));

		float Ad = ((v3_d - v1_d) * (v2.y - v1.y) - (v2_d - v1_d) * (v3.y - v1.y));
		float Bd = ((v3.x - v1.x) * (v2_d - v1_d) - (v2.x - v1.x) * (v3_d - v1_d));

		float C = ((v2.x - v1.x) * (v3.y - v1.y) - (v3.x - v1.x) * (v2.y - v1.y));
		float ddx_s_a = -Aa / C;
		float ddy_s_a = -Ba / C;

		float ddx_s_b = -Ab / C;
		float ddy_s_b = -Bb / C;

		float ddx_s_c = -Ac / C;
		float ddy_s_c = -Bc / C;

		float ddx_s_d = -Ad / C;
		float ddy_s_d = -Bd / C;

		ddx = _mm_load_ps_r(ddx_s_a, ddx_s_b, ddx_s_c, ddx_s_d);
		ddy = _mm_load_ps_r(ddy_s_a, ddy_s_b, ddy_s_c, ddy_s_d);

		float c_s_a = (v1_a - ddx_s_a *v1.x - ddy_s_a*v1.y);
		float c_s_b = (v1_b - ddx_s_b *v1.x - ddy_s_b*v1.y);
		float c_s_c = (v1_c - ddx_s_c *v1.x - ddy_s_c*v1.y);
		float c_s_d = (v1_d - ddx_s_d *v1.x - ddy_s_d*v1.y);

		c = _mm_load_ps_r(c_s_a, c_s_b, c_s_c, c_s_d);

		//z = z1 + dzdx * (minx - v1.x) + dzdy * (minx - v1.y);
		//z = (z1 - dzdx * v1.x - v1.y*dzdy) +  dzdx*inx + dzdy *iny;
	}

	__forceinline __m128 Ip(__m128 x, __m128 y) const
	{
		__m128 p1 = _mm_mul_ps(x, ddx);
		__m128 p2 = _mm_mul_ps(y, ddy);

		__m128 s1 = _mm_add_ps(p1, p2);
		return _mm_add_ps(s1, c);
	}

	__forceinline __m128 InStep(__m128 bas) const
	{
		return _mm_add_ps(bas, ddx);
	}
};

struct IPs
{
	PlaneStepper ZUV;
	PlaneStepper Col;

	void Setup(PolyParam* pp, text_info* texture, const Vertex &v1, const Vertex &v2, const Vertex &v3, int minx, int miny, int q)
	{
		u32 w = 0, h = 0;
		if (texture) {
			w = texture->width;
			h = texture->height;
		}

		ZUV.Setup(v1, v2, v3, minx, miny, q,
			v1.z, v2.z, v3.z,
			v1.u * w * v1.z, v2.u * w* v2.z, v3.u * w* v3.z,
			v1.v * h* v1.z, v2.v * h* v2.z, v3.v * h* v3.z,
			0, -1, 1);

		Col.Setup(v1, v2, v3, minx, miny, q,
			v1.col[2], v2.col[2], v3.col[2],
			v1.col[1], v2.col[1], v3.col[1],
			v1.col[0], v2.col[0], v3.col[0],
			v1.col[3], v2.col[3], v3.col[3]
			);
	}
};


#define TPL_DECL_pixel template<bool useoldmsk, int alpha_mode, bool pp_UseAlpha, bool pp_Texture, bool pp_IgnoreTexA, int pp_ShadInstr, bool pp_Offset >
#define TPL_DECL_triangle template<int alpha_mode, bool pp_UseAlpha, bool pp_Texture, bool pp_IgnoreTexA, int pp_ShadInstr, bool pp_Offset >

#define TPL_PRMS_pixel(useoldmsk) <useoldmsk, alpha_mode, pp_UseAlpha, pp_Texture, pp_IgnoreTexA, pp_ShadInstr, pp_Offset >
#define TPL_PRMS_triangle <alpha_mode, pp_UseAlpha, pp_Texture, pp_IgnoreTexA, pp_ShadInstr, pp_Offset >


//<alpha_blend, pp_UseAlpha, pp_Texture, pp_IgnoreTexA, pp_ShadInstr, pp_Offset >
typedef void(*RendtriangleFn)(PolyParam* pp, int vertex_offset, const Vertex &v1, const Vertex &v2, const Vertex &v3, u32* colorBuffer, RECT* area);
RendtriangleFn RendtriangleFns[3][2][2][2][4][2];


__m128i const_setAlpha;

__m128i shuffle_alpha;


TPL_DECL_pixel
static void PixelFlush(PolyParam* pp, text_info* texture, __m128 x, __m128 y, u8* cb, __m128 oldmask, IPs& ip)
{
	x = _mm_shuffle_ps(x, x, 0);
	__m128 invW = ip.ZUV.Ip(x, y);
	__m128 u = ip.ZUV.InStep(invW);
	__m128 v = ip.ZUV.InStep(u);
	__m128 ws = ip.ZUV.InStep(v);

	_MM_TRANSPOSE4_PS(invW, u, v, ws);

	u = _mm_div_ps(u, invW);
	v = _mm_div_ps(v, invW);

	//invW : {z1,z2,z3,z4}
	//u    : {u1,u2,u3,u4}
	//v    : {v1,v2,v3,v4}
	//wx   : {?,?,?,?}

	__m128* zb = (__m128*)&cb[Z_BUFFER_PIXEL_OFFSET * 4];

	__m128 ZMask = _mm_cmpge_ps(invW, *zb);
	if (useoldmsk)
		ZMask = _mm_and_ps(oldmask, ZMask);
	u32 msk = _mm_movemask_ps(ZMask);//0xF

	if (msk == 0)
		return;

	__m128i rv;

	{
		__m128 a = ip.Col.Ip(x, y);
		__m128 b = ip.Col.InStep(a);
		__m128 c = ip.Col.InStep(b);
		__m128 d = ip.Col.InStep(c);

		//we need :

		__m128i ab = _mm_packs_epi32(_mm_cvttps_epi32(a), _mm_cvttps_epi32(b));
		__m128i cd = _mm_packs_epi32(_mm_cvttps_epi32(c), _mm_cvttps_epi32(d));

		rv = _mm_packus_epi16(ab, cd);

		if (!pp_UseAlpha) {
			rv = _mm_or_si128(rv, const_setAlpha);
		}

		if (pp_Texture) {

			__m128i ui = _mm_cvttps_epi32(u);
			__m128i vi = _mm_cvttps_epi32(v);

			__m128 uf = _mm_sub_ps(u, _mm_cvtepi32_ps(ui));
			__m128 vf = _mm_sub_ps(v, _mm_cvtepi32_ps(vi));

			__m128i ufi = _mm_cvttps_epi32(_mm_mul_ps(uf, _mm_set1_ps(256)));
			__m128i vfi = _mm_cvttps_epi32(_mm_mul_ps(vf, _mm_set1_ps(256)));

			//(int)v<<x+(int)u
			m128i textadr;

			textadr.mm =  _mm_add_epi32(_mm_slli_epi32(vi, 16), ui);//texture addresses ! 4x of em !
			m128i textel;

			for (int i = 0; i < 4; i++) {
				u32 u = textadr.m128i_i16[i * 2 + 0];
				u32 v = textadr.m128i_i16[i * 2 + 1];

				__m128i mufi_ = _mm_shuffle_epi32(ufi, _MM_SHUFFLE(0, 0, 0, 0));
				__m128i mufi_n = _mm_sub_epi32(_mm_set1_epi32(255), mufi_);

				__m128i mvfi_ = _mm_shuffle_epi32(vfi, _MM_SHUFFLE(0, 0, 0, 0));
				__m128i mvfi_n = _mm_sub_epi32(_mm_set1_epi32(255), mvfi_);

				ufi = _mm_shuffle_epi32(ufi, _MM_SHUFFLE(0,3,2,1));
				vfi = _mm_shuffle_epi32(vfi, _MM_SHUFFLE(0,3,2,1));

				u32 pixel;

#if 0
				u32 textel_size = 2;

				u32 pixel00 = decoded_colors[texture->textype][texture->pdata[((u + 1) % texture->width + (v + 1) % texture->height * texture->width)]];
				u32 pixel01 = decoded_colors[texture->textype][texture->pdata[((u + 0) % texture->width + (v + 1) % texture->height * texture->width)]];
				u32 pixel10 = decoded_colors[texture->textype][texture->pdata[((u + 1) % texture->width + (v + 0) % texture->height * texture->width)]];
				u32 pixel11 = decoded_colors[texture->textype][texture->pdata[((u + 0) % texture->width + (v + 0) % texture->height * texture->width)]];


				for (int j = 0; j < 4; j++) {
				((u8*)&pixel)[j] =

				(((u8*)&pixel00)[j] * uf.m128_f32[i] + ((u8*)&pixel01)[j] * (1 - uf.m128_f32[i])) * vf.m128_f32[i] + (((u8*)&pixel10)[j] * uf.m128_f32[i] + ((u8*)&pixel11)[j] * (1 - uf.m128_f32[i])) * (1 - vf.m128_f32[i]);
				}
#endif

				__m128i px = ((__m128i*)texture->pdata)[((u + 0) % texture->width + (v + 0) % texture->height * texture->width)];



				__m128i tex_00 = _mm_cvtepu8_epi32(px);
				__m128i tex_01 = _mm_cvtepu8_epi32(_mm_shuffle_epi32(px, _MM_SHUFFLE(0, 0, 0, 1)));
				__m128i tex_10 = _mm_cvtepu8_epi32(_mm_shuffle_epi32(px, _MM_SHUFFLE(0, 0, 0, 2)));
				__m128i tex_11 = _mm_cvtepu8_epi32(_mm_shuffle_epi32(px, _MM_SHUFFLE(0, 0, 0, 3)));

				tex_00 = _mm_add_epi32(_mm_mullo_epi32(tex_00, mufi_), _mm_mullo_epi32(tex_01, mufi_n));
				tex_10 = _mm_add_epi32(_mm_mullo_epi32(tex_10, mufi_), _mm_mullo_epi32(tex_10, mufi_n));

				tex_00 = _mm_add_epi32(_mm_mullo_epi32(tex_00, mvfi_), _mm_mullo_epi32(tex_10, mvfi_n));
				tex_00 = _mm_srli_epi32(tex_00, 16);

				tex_00 = _mm_packus_epi32(tex_00, tex_00);
				tex_00 = _mm_packus_epi16(tex_00, tex_00);
				pixel = _mm_cvtsi128_si32(tex_00);
#if 0
				//top    = c0 * a + c1 * (1-a)
				//bottom = c2 * a + c3 * (1-a)

				//[c0 c2] [c1 c3]
				//[c0 c2]*a + [c1 c3] * (1 - a) = [cx cy]
				//[cx * d + cy * (1-d)]
				//cf
				_mm_unpacklo_epi8()
				__m128i y = _mm_cvtps_epi32(x);    // Convert them to 32-bit ints
				y = _mm_packus_epi32(y, y);        // Pack down to 16 bits
				y = _mm_packus_epi16(y, y);        // Pack down to 8 bits
				*(int*)out = _mm_cvtsi128_si32(y); // Store the lower 32 bits

				// 0x000000FF * 0x00010001 = 0x00FF00FF




				__m128i px = ((__m128i*)texture->pdata)[((u) & ( texture->width - 1) + (v) & (texture->height-1) * texture->width)];

				__m128i lo_px = _mm_cvtepu8_epi16(px);
				__m128i hi_px = _mm_cvtepu8_epi16(_mm_shuffle_epi32(px, _MM_SHUFFLE(1, 0, 3, 2)));
#endif
				textel.m128i_i32[i] = pixel;
			}

			if (pp_IgnoreTexA) {
				textel.mm = _mm_or_si128(textel.mm, const_setAlpha);
			}

			if (pp_ShadInstr == 0){
					//color.rgb = texcol.rgb;
					//color.a = texcol.a;
				rv = textel.mm;
			}
			else if (pp_ShadInstr == 1) {
				//color.rgb *= texcol.rgb;
				//color.a = texcol.a;

				//color.a = 1
				rv = _mm_or_si128(rv, const_setAlpha);

				//color *= texcol
				__m128i lo_rv = _mm_cvtepu8_epi16(rv);
				__m128i hi_rv = _mm_cvtepu8_epi16(_mm_shuffle_epi32(rv, _MM_SHUFFLE(1, 0, 3, 2)));


				__m128i lo_fb = _mm_cvtepu8_epi16(textel.mm);
				__m128i hi_fb = _mm_cvtepu8_epi16(_mm_shuffle_epi32(textel.mm, _MM_SHUFFLE(1, 0, 3, 2)));


				lo_rv = _mm_mullo_epi16(lo_rv, lo_fb);
				hi_rv = _mm_mullo_epi16(hi_rv, hi_fb);

				rv = _mm_packus_epi16(_mm_srli_epi16(lo_rv, 8), _mm_srli_epi16(hi_rv, 8));
			}
			else if (pp_ShadInstr == 2) {
				//color.rgb=mix(color.rgb,texcol.rgb,texcol.a);

				// a bit wrong atm, as it also mixes alphas
				__m128i lo_rv = _mm_cvtepu8_epi16(rv);
				__m128i hi_rv = _mm_cvtepu8_epi16(_mm_shuffle_epi32(rv, _MM_SHUFFLE(1, 0, 3, 2)));


				__m128i lo_fb = _mm_cvtepu8_epi16(textel.mm);
				__m128i hi_fb = _mm_cvtepu8_epi16(_mm_shuffle_epi32(textel.mm, _MM_SHUFFLE(1, 0, 3, 2)));

				__m128i lo_rv_alpha = _mm_shuffle_epi8(lo_fb, shuffle_alpha);
				__m128i hi_rv_alpha = _mm_shuffle_epi8(hi_fb, shuffle_alpha);

				__m128i lo_fb_alpha = _mm_sub_epi16(_mm_set1_epi16(255), lo_rv_alpha);
				__m128i hi_fb_alpha = _mm_sub_epi16(_mm_set1_epi16(255), hi_rv_alpha);


				lo_rv = _mm_mullo_epi16(lo_rv, lo_rv_alpha);
				hi_rv = _mm_mullo_epi16(hi_rv, hi_rv_alpha);

				lo_fb = _mm_mullo_epi16(lo_fb, lo_fb_alpha);
				hi_fb = _mm_mullo_epi16(hi_fb, hi_fb_alpha);

				rv = _mm_packus_epi16(_mm_srli_epi16(_mm_adds_epu16(lo_rv, lo_fb), 8), _mm_srli_epi16(_mm_adds_epu16(hi_rv, hi_fb), 8));
			}
			else if (pp_ShadInstr == 3) {
				//color*=texcol
				__m128i lo_rv = _mm_cvtepu8_epi16(rv);
				__m128i hi_rv = _mm_cvtepu8_epi16(_mm_shuffle_epi32(rv, _MM_SHUFFLE(1, 0, 3, 2)));


				__m128i lo_fb = _mm_cvtepu8_epi16(textel.mm);
				__m128i hi_fb = _mm_cvtepu8_epi16(_mm_shuffle_epi32(textel.mm, _MM_SHUFFLE(1, 0, 3, 2)));


				lo_rv = _mm_mullo_epi16(lo_rv, lo_fb);
				hi_rv = _mm_mullo_epi16(hi_rv, hi_fb);

				rv = _mm_packus_epi16(_mm_srli_epi16(lo_rv, 8), _mm_srli_epi16(hi_rv, 8));
			}

			if (pp_Offset) {
				//add offset
			}


			//textadr = _mm_add_epi32(textadr, _mm_setr_epi32(tex_addr, tex_addr, tex_addr, tex_addr));
			//rv = textel.mm; // _mm_xor_si128(rv, textadr);
		}
	}

	//__m128i rv=ip.col;//_mm_xor_si128(_mm_cvtps_epi32(_mm_mul_ps(x,Z.c)),_mm_cvtps_epi32(y));

	//Alpha test
	if (alpha_mode == 1) {
		__m128i fb = *(__m128i*)cb;

#if 1
		m128i mm_rv, mm_fb;
		mm_rv.mm = rv;
		mm_fb.mm = fb;
		//ALPHA_TEST
		for (int i = 0; i < 4; i++) {
			if (mm_rv.m128i_u8[i * 4 + 3] < PT_ALPHA_REF) {
				mm_rv.m128i_u32[i] = mm_fb.m128i_u32[i];
			}
		}

		rv = mm_rv.mm;
#else
		__m128i ALPHA_TEST = _mm_set1_epi8(PT_ALPHA_REF);
		__m128i mask = _mm_cmplt_epi8(_mm_subs_epu16(ALPHA_TEST, rv), _mm_setzero_si128());

		mask = _mm_srai_epi32(mask, 31); //FF on the pixels we want to keep

		rv = _mm_or_si128(_mm_and_si128(rv, mask), _mm_andnot_si128(mask, cb));
#endif

	}
	else if (alpha_mode == 2) {
		__m128i fb = *(__m128i*)cb;
#if 0
		for (int i = 0; i < 16; i += 4) {
			u8 src_blend[4] = { rv.m128i_u8[i + 3], rv.m128i_u8[i + 3], rv.m128i_u8[i + 3], rv.m128i_u8[i + 3] };
			u8 dst_blend[4] = { 255 - rv.m128i_u8[i + 3], 255 - rv.m128i_u8[i + 3], 255 - rv.m128i_u8[i + 3], 255 - rv.m128i_u8[i + 3] };
			for (int j = 0; j < 4; j++) {
				rv.m128i_u8[i + j] = (rv.m128i_u8[i + j] * src_blend[j]) / 256 + (fb.m128i_u8[i + j] * dst_blend[j]) / 256;
			}
		}
#else


		__m128i lo_rv = _mm_cvtepu8_epi16(rv);
		__m128i hi_rv = _mm_cvtepu8_epi16(_mm_shuffle_epi32(rv, _MM_SHUFFLE(1, 0, 3, 2)));


		__m128i lo_fb = _mm_cvtepu8_epi16(fb);
		__m128i hi_fb = _mm_cvtepu8_epi16(_mm_shuffle_epi32(fb, _MM_SHUFFLE(1, 0, 3, 2)));

		__m128i lo_rv_alpha = _mm_shuffle_epi8(lo_rv, shuffle_alpha);
		__m128i hi_rv_alpha = _mm_shuffle_epi8(hi_rv, shuffle_alpha);

		__m128i lo_fb_alpha = _mm_sub_epi16(_mm_set1_epi16(255), lo_rv_alpha);
		__m128i hi_fb_alpha = _mm_sub_epi16(_mm_set1_epi16(255), hi_rv_alpha);


		lo_rv = _mm_mullo_epi16(lo_rv, lo_rv_alpha);
		hi_rv = _mm_mullo_epi16(hi_rv, hi_rv_alpha);

		lo_fb = _mm_mullo_epi16(lo_fb, lo_fb_alpha);
		hi_fb = _mm_mullo_epi16(hi_fb, hi_fb_alpha);

		rv = _mm_packus_epi16(_mm_srli_epi16(_mm_adds_epu16(lo_rv, lo_fb), 8), _mm_srli_epi16(_mm_adds_epu16(hi_rv, hi_fb), 8));
#endif
	}

	if (msk != 0xF)
	{
		rv = _mm_and_si128(rv, *(__m128i*)&ZMask);
		rv = _mm_or_si128(_mm_andnot_si128(*(__m128i*)&ZMask, *(__m128i*)cb), rv);

		invW = _mm_and_ps(invW, ZMask);
		invW = _mm_or_ps(_mm_andnot_ps(ZMask, *zb), invW);

	}
	*zb = invW;
	*(__m128i*)cb = rv;
}

//u32 nok,fok;
TPL_DECL_triangle
static void Rendtriangle(PolyParam* pp, int vertex_offset, const Vertex &v1, const Vertex &v2, const Vertex &v3, u32* colorBuffer, RECT* area)
{
	text_info texture = { 0 };

	if (pp_Texture) {

		#pragma omp critical (texture_lookup)
		{
			texture = raw_GetTexture(pp->tsp, pp->tcw);
		}

	}

	const int stride_bytes = STRIDE_PIXEL_OFFSET * 4;
	//Plane equation


	// 28.4 fixed-point coordinates
	const float Y1 = v1.y;// iround(16.0f * v1.y);
	const float Y2 = v2.y;// iround(16.0f * v2.y);
	const float Y3 = v3.y;// iround(16.0f * v3.y);

	const float X1 = v1.x;// iround(16.0f * v1.x);
	const float X2 = v2.x;// iround(16.0f * v2.x);
	const float X3 = v3.x;// iround(16.0f * v3.x);

	int sgn = 1;

	// Deltas
	{
		//area: (X1-X3)*(Y2-Y3)-(Y1-Y3)*(X2-X3)
		float area = ((X1 - X3)*(Y2 - Y3) - (Y1 - Y3)*(X2 - X3));

		if (area>0)
			sgn = -1;

		if (pp->isp.CullMode != 0) {
			float abs_area = fabsf(area);

			if (abs_area < FPU_CULL_VAL)
				return;

			if (pp->isp.CullMode >= 2) {
				u32 mode = vertex_offset ^ pp->isp.CullMode & 1;

				if (
					(mode == 0 && area < 0) ||
					(mode == 1 && area > 0)) {
					return;
				}
			}
		}
	}

	const float DX12 = sgn*(X1 - X2);
	const float DX23 = sgn*(X2 - X3);
	const float DX31 = sgn*(X3 - X1);

	const float DY12 = sgn*(Y1 - Y2);
	const float DY23 = sgn*(Y2 - Y3);
	const float DY31 = sgn*(Y3 - Y1);

	// Fixed-point deltas
	const float FDX12 = DX12;// << 4;
	const float FDX23 = DX23;// << 4;
	const float FDX31 = DX31;// << 4;

	const float FDY12 = DY12;// << 4;
	const float FDY23 = DY23;// << 4;
	const float FDY31 = DY31;// << 4;

	// Block size, standard 4x4 (must be power of two)
	const int q = 4;

	// Bounding rectangle
	int minx = iround(mmin(X1, X2, X3, area->left));// +0xF) >> 4;
	int miny = iround(mmin(Y1, Y2, Y3, area->top));// +0xF) >> 4;

	// Start in corner of block
	minx &= ~(q - 1);
	miny &= ~(q - 1);

	int spanx = iround(mmax(X1 + 0.5f, X2 + 0.5f, X3 + 0.5f, area->right)) - minx;
	int spany = iround(mmax(Y1 + 0.5f, Y2 + 0.5f, Y3 + 0.5f, area->bottom)) - miny;

	//Inside scissor area?
	if (spanx < 0 || spany < 0)
		return;


	// Half-edge constants
	float C1 = DY12 * X1 - DX12 * Y1;
	float C2 = DY23 * X2 - DX23 * Y2;
	float C3 = DY31 * X3 - DX31 * Y3;

	// Correct for fill convention
	if (DY12 < 0 || (DY12 == 0 && DX12 > 0)) C1++;
	if (DY23 < 0 || (DY23 == 0 && DX23 > 0)) C2++;
	if (DY31 < 0 || (DY31 == 0 && DX31 > 0)) C3++;

	float MAX_12, MAX_23, MAX_31, MIN_12, MIN_23, MIN_31;

	PlaneMinMax(MIN_12, MAX_12, DX12, DY12, q);
	PlaneMinMax(MIN_23, MAX_23, DX23, DY23, q);
	PlaneMinMax(MIN_31, MAX_31, DX31, DY31, q);

	const float FDqX12 = FDX12 * q;
	const float FDqX23 = FDX23 * q;
	const float FDqX31 = FDX31 * q;

	const float FDqY12 = FDY12 * q;
	const float FDqY23 = FDY23 * q;
	const float FDqY31 = FDY31 * q;

	const float FDX12mq = FDX12 + FDY12*q;
	const float FDX23mq = FDX23 + FDY23*q;
	const float FDX31mq = FDX31 + FDY31*q;

	float hs12 = C1 + FDX12 * (miny + 0.5f) - FDY12 * (minx + 0.5f) + FDqY12 - MIN_12;
	float hs23 = C2 + FDX23 * (miny + 0.5f) - FDY23 * (minx + 0.5f) + FDqY23 - MIN_23;
	float hs31 = C3 + FDX31 * (miny + 0.5f) - FDY31 * (minx + 0.5f) + FDqY31 - MIN_31;

	MAX_12 -= MIN_12;
	MAX_23 -= MIN_23;
	MAX_31 -= MIN_31;

	float C1_pm = MIN_12;
	float C2_pm = MIN_23;
	float C3_pm = MIN_31;


	u8* cb_y = (u8*)colorBuffer;
	cb_y += miny*stride_bytes + minx*(q * 4);

	DECL_ALIGN(64) IPs ip;

	ip.Setup(pp, &texture, v1, v2, v3, minx, miny, q);


	__m128 y_ps = _mm_broadcast_float(miny);
	__m128 minx_ps = _mm_load_scaled_float(minx - q, 1);
	static DECL_ALIGN(16) float ones_ps[4] = { 1, 1, 1, 1 };
	static DECL_ALIGN(16) float q_ps[4] = { q, q, q, q };

	// Loop through blocks
	for (int y = spany; y > 0; y -= q)
	{
		float Xhs12 = hs12;
		float Xhs23 = hs23;
		float Xhs31 = hs31;
		u8* cb_x = cb_y;
		__m128 x_ps = minx_ps;
		for (int x = spanx; x > 0; x -= q)
		{
			Xhs12 -= FDqY12;
			Xhs23 -= FDqY23;
			Xhs31 -= FDqY31;
			x_ps = _mm_add_ps(x_ps, *(__m128*)q_ps);

			// Corners of block
			bool any = EvalHalfSpaceFAny(Xhs12, Xhs23, Xhs31);

			// Skip block when outside an edge
			if (!any)
			{
				cb_x += q*q * 4;
				continue;
			}

			bool all = EvalHalfSpaceFAll(Xhs12, Xhs23, Xhs31, MAX_12, MAX_23, MAX_31);

			// Accept whole block when totally covered
			if (all)
			{
				__m128 yl_ps = y_ps;
				for (int iy = q; iy > 0; iy--)
				{
					PixelFlush TPL_PRMS_pixel(false) (pp, &texture, x_ps, yl_ps, cb_x, x_ps, ip);
					yl_ps = _mm_add_ps(yl_ps, *(__m128*)ones_ps);
					cb_x += sizeof(__m128);
				}
			}
			else // Partially covered block
			{
				float CY1 = C1_pm + Xhs12;
				float CY2 = C2_pm + Xhs23;
				float CY3 = C3_pm + Xhs31;

				__m128 pfdx12 = _mm_broadcast_float(FDX12);
				__m128 pfdx23 = _mm_broadcast_float(FDX23);
				__m128 pfdx31 = _mm_broadcast_float(FDX31);

				__m128 pcy1 = _mm_load_scaled_float(CY1, -FDY12);
				__m128 pcy2 = _mm_load_scaled_float(CY2, -FDY23);
				__m128 pcy3 = _mm_load_scaled_float(CY3, -FDY31);

				__m128 pzero = _mm_setzero_ps();

				//bool ok=false;
				__m128 yl_ps = y_ps;

				for (int iy = q; iy > 0; iy--)
				{
					__m128 mask1 = _mm_cmple_ps(pcy1, pzero);
					__m128 mask2 = _mm_cmple_ps(pcy2, pzero);
					__m128 mask3 = _mm_cmple_ps(pcy3, pzero);
					__m128 summary = _mm_or_ps(mask3, _mm_or_ps(mask2, mask1));

					__m128i a = _mm_cmpeq_epi32((__m128i&)summary, (__m128i&)pzero);
					int msk = _mm_movemask_ps((__m128&)a);

					if (msk != 0)
					{
						if (msk != 0xF)
							PixelFlush TPL_PRMS_pixel(true) (pp, &texture, x_ps, yl_ps, cb_x, *(__m128*)&a, ip);
						else
							PixelFlush TPL_PRMS_pixel(false) (pp, &texture, x_ps, yl_ps, cb_x, *(__m128*)&a, ip);
					}

					yl_ps = _mm_add_ps(yl_ps, *(__m128*)ones_ps);
					cb_x += sizeof(__m128);

					//CY1 += FDX12mq;
					//CY2 += FDX23mq;
					//CY3 += FDX31mq;
					pcy1 = _mm_add_ps(pcy1, pfdx12);
					pcy2 = _mm_add_ps(pcy2, pfdx23);
					pcy3 = _mm_add_ps(pcy3, pfdx31);
				}
				/*
				if (!ok)
				{
				nok++;
				}
				else
				{
				fok++;
				}*/
			}
		}
	next_y:
		hs12 += FDqX12;
		hs23 += FDqX23;
		hs31 += FDqX31;
		cb_y += stride_bytes*q;
		y_ps = _mm_add_ps(y_ps, *(__m128*)q_ps);
	}
}

#if HOST_OS == OS_WINDOWS
	BITMAPINFOHEADER bi = { sizeof(BITMAPINFOHEADER), 0, 0, 1, 32, BI_RGB };
#endif


struct softrend : Renderer
{
	virtual bool Process(TA_context* ctx) {
		//disable RTTs for now ..
		if (ctx->rend.isRTT)
			return false;

		ctx->rend_inuse.Lock();
		ctx->MarkRend();

		if (!ta_parse_vdrc(ctx))
			return false;

		return true;
	}



	template <int alpha_mode>
	void RenderParamList(List<PolyParam>* param_list, RECT* area) {

		Vertex* verts = pvrrc.verts.head();
		u16* idx = pvrrc.idx.head();

		PolyParam* params = param_list->head();
		int param_count = param_list->used();

		for (int i = 0; i < param_count; i++)
		{
			int vertex_count = params[i].count - 2;

			u16* poly_idx = &idx[params[i].first];

			for (int v = 0; v < vertex_count; v++) {
				////<alpha_blend, pp_UseAlpha, pp_Texture, pp_IgnoreTexA, pp_ShadInstr, pp_Offset >
				RendtriangleFn fn = RendtriangleFns[alpha_mode][params[i].tsp.UseAlpha][params[i].pcw.Texture][params[i].tsp.IgnoreTexA][params[i].tsp.ShadInstr][params[i].pcw.Offset];

				fn(&params[i], v, verts[poly_idx[v]], verts[poly_idx[v + 1]], verts[poly_idx[v + 2]], render_buffer, area);
			}
		}
	}
	virtual bool Render() {
		bool is_rtt = pvrrc.isRTT;

		memset(render_buffer, 0, sizeof(render_buffer));

		if (pvrrc.verts.used()<3)
			return false;

		if (pvrrc.isAutoSort)
			SortPParams();

		int tcount = omp_get_num_procs() - 1;
		if (tcount == 0) tcount = 1;
		if (tcount > settings.pvr.MaxThreads) tcount = settings.pvr.MaxThreads;
#pragma omp parallel num_threads(tcount)
		{
			int thd = omp_get_thread_num();
			int y_offs = 480 % omp_get_num_threads();
			int y_thd = 480 / omp_get_num_threads();
			int y_start = (!!thd) * y_offs + y_thd * thd;
			int y_end =  y_offs + y_thd * (thd + 1);

			RECT area = { 0, y_start, 640, y_end };
			RenderParamList<0>(&pvrrc.global_param_op, &area);
			RenderParamList<1>(&pvrrc.global_param_pt, &area);
			RenderParamList<2>(&pvrrc.global_param_tr, &area);
		}




		/*
		for (int y = 0; y < 480; y++) {
			for (int x = 0; x < 640; x++) {
				color_buffer[x + y * 640] = rand();
			}
		} */

		return !is_rtt;
	}

#if HOST_OS == OS_WINDOWS
	HWND hWnd;
	HBITMAP hBMP = 0, holdBMP;
	HDC hmem;
#endif


	virtual bool Init() {

		const_setAlpha = _mm_set1_epi32(0xFF000000);
		u8 ushuffle[] = { 0x0E, 0x80, 0x0E, 0x80, 0x0E, 0x80, 0x0E, 0x80, 0x06, 0x80, 0x06, 0x80, 0x06, 0x80, 0x06, 0x80};
		memcpy(&shuffle_alpha, ushuffle, sizeof(shuffle_alpha));

#if HOST_OS == OS_WINDOWS
		hWnd = (HWND)libPvr_GetRenderTarget();

		bi.biWidth = 640;
		bi.biHeight = 480;

		RECT rect;

		GetClientRect(hWnd, &rect);

		HDC hdc = GetDC(hWnd);

		FillRect(hdc, &rect, (HBRUSH)(COLOR_BACKGROUND));

		bi.biSizeImage = bi.biWidth * bi.biHeight * 4;

		hBMP = CreateCompatibleBitmap(hdc, bi.biWidth, bi.biHeight);
		hmem = CreateCompatibleDC(hdc);
		holdBMP = (HBITMAP)SelectObject(hmem, hBMP);
		ReleaseDC(hWnd, hdc);
#endif

		#define REP_16(x) ((x)* 16 + (x))
		#define REP_32(x) ((x)* 8 + (x)/4)
		#define REP_64(x) ((x)* 4 + (x)/16)

		for (int c = 0; c < 65536; c++) {
			//565
			decoded_colors[0][c] = 0xFF000000 | (REP_32((c >> 11) % 32) << 16) | (REP_64((c >> 5) % 64) << 8) | (REP_32((c >> 0) % 32) << 0);
			//1555
			decoded_colors[1][c] = ((c >> 0) % 2 * 255 << 24) | (REP_32((c >> 11) % 32) << 16) | (REP_32((c >> 6) % 32) << 8) | (REP_32((c >> 1) % 32) << 0);
			//4444
			decoded_colors[2][c] = (REP_16((c >> 0) % 16) << 24) | (REP_16((c >> 12) % 16) << 16) | (REP_16((c >> 8) % 16) << 8) | (REP_16((c >> 4) % 16) << 0);
		}

		{
			RendtriangleFns[0][0][1][0][0][0] = &Rendtriangle<0, 0, 1, 0, 0, 0>;
			RendtriangleFns[0][0][1][0][0][1] = &Rendtriangle<0, 0, 1, 0, 0, 1>;
			RendtriangleFns[0][0][1][0][1][0] = &Rendtriangle<0, 0, 1, 0, 1, 0>;
			RendtriangleFns[0][0][1][0][1][1] = &Rendtriangle<0, 0, 1, 0, 1, 1>;
			RendtriangleFns[0][0][1][0][2][0] = &Rendtriangle<0, 0, 1, 0, 2, 0>;
			RendtriangleFns[0][0][1][0][2][1] = &Rendtriangle<0, 0, 1, 0, 2, 1>;
			RendtriangleFns[0][0][1][0][3][0] = &Rendtriangle<0, 0, 1, 0, 3, 0>;
			RendtriangleFns[0][0][1][0][3][1] = &Rendtriangle<0, 0, 1, 0, 3, 1>;
			RendtriangleFns[0][0][1][1][0][0] = &Rendtriangle<0, 0, 1, 1, 0, 0>;
			RendtriangleFns[0][0][1][1][0][1] = &Rendtriangle<0, 0, 1, 1, 0, 1>;
			RendtriangleFns[0][0][1][1][1][0] = &Rendtriangle<0, 0, 1, 1, 1, 0>;
			RendtriangleFns[0][0][1][1][1][1] = &Rendtriangle<0, 0, 1, 1, 1, 1>;
			RendtriangleFns[0][0][1][1][2][0] = &Rendtriangle<0, 0, 1, 1, 2, 0>;
			RendtriangleFns[0][0][1][1][2][1] = &Rendtriangle<0, 0, 1, 1, 2, 1>;
			RendtriangleFns[0][0][1][1][3][0] = &Rendtriangle<0, 0, 1, 1, 3, 0>;
			RendtriangleFns[0][0][1][1][3][1] = &Rendtriangle<0, 0, 1, 1, 3, 1>;
			RendtriangleFns[0][0][0][0][0][0] = &Rendtriangle<0, 0, 0, 0, 0, 0>;
			RendtriangleFns[0][0][0][0][0][1] = &Rendtriangle<0, 0, 0, 0, 0, 1>;
			RendtriangleFns[0][0][0][0][1][0] = &Rendtriangle<0, 0, 0, 0, 1, 0>;
			RendtriangleFns[0][0][0][0][1][1] = &Rendtriangle<0, 0, 0, 0, 1, 1>;
			RendtriangleFns[0][0][0][0][2][0] = &Rendtriangle<0, 0, 0, 0, 2, 0>;
			RendtriangleFns[0][0][0][0][2][1] = &Rendtriangle<0, 0, 0, 0, 2, 1>;
			RendtriangleFns[0][0][0][0][3][0] = &Rendtriangle<0, 0, 0, 0, 3, 0>;
			RendtriangleFns[0][0][0][0][3][1] = &Rendtriangle<0, 0, 0, 0, 3, 1>;
			RendtriangleFns[0][0][0][1][0][0] = &Rendtriangle<0, 0, 0, 1, 0, 0>;
			RendtriangleFns[0][0][0][1][0][1] = &Rendtriangle<0, 0, 0, 1, 0, 1>;
			RendtriangleFns[0][0][0][1][1][0] = &Rendtriangle<0, 0, 0, 1, 1, 0>;
			RendtriangleFns[0][0][0][1][1][1] = &Rendtriangle<0, 0, 0, 1, 1, 1>;
			RendtriangleFns[0][0][0][1][2][0] = &Rendtriangle<0, 0, 0, 1, 2, 0>;
			RendtriangleFns[0][0][0][1][2][1] = &Rendtriangle<0, 0, 0, 1, 2, 1>;
			RendtriangleFns[0][0][0][1][3][0] = &Rendtriangle<0, 0, 0, 1, 3, 0>;
			RendtriangleFns[0][0][0][1][3][1] = &Rendtriangle<0, 0, 0, 1, 3, 1>;
			RendtriangleFns[0][1][1][0][0][0] = &Rendtriangle<0, 1, 1, 0, 0, 0>;
			RendtriangleFns[0][1][1][0][0][1] = &Rendtriangle<0, 1, 1, 0, 0, 1>;
			RendtriangleFns[0][1][1][0][1][0] = &Rendtriangle<0, 1, 1, 0, 1, 0>;
			RendtriangleFns[0][1][1][0][1][1] = &Rendtriangle<0, 1, 1, 0, 1, 1>;
			RendtriangleFns[0][1][1][0][2][0] = &Rendtriangle<0, 1, 1, 0, 2, 0>;
			RendtriangleFns[0][1][1][0][2][1] = &Rendtriangle<0, 1, 1, 0, 2, 1>;
			RendtriangleFns[0][1][1][0][3][0] = &Rendtriangle<0, 1, 1, 0, 3, 0>;
			RendtriangleFns[0][1][1][0][3][1] = &Rendtriangle<0, 1, 1, 0, 3, 1>;
			RendtriangleFns[0][1][1][1][0][0] = &Rendtriangle<0, 1, 1, 1, 0, 0>;
			RendtriangleFns[0][1][1][1][0][1] = &Rendtriangle<0, 1, 1, 1, 0, 1>;
			RendtriangleFns[0][1][1][1][1][0] = &Rendtriangle<0, 1, 1, 1, 1, 0>;
			RendtriangleFns[0][1][1][1][1][1] = &Rendtriangle<0, 1, 1, 1, 1, 1>;
			RendtriangleFns[0][1][1][1][2][0] = &Rendtriangle<0, 1, 1, 1, 2, 0>;
			RendtriangleFns[0][1][1][1][2][1] = &Rendtriangle<0, 1, 1, 1, 2, 1>;
			RendtriangleFns[0][1][1][1][3][0] = &Rendtriangle<0, 1, 1, 1, 3, 0>;
			RendtriangleFns[0][1][1][1][3][1] = &Rendtriangle<0, 1, 1, 1, 3, 1>;
			RendtriangleFns[0][1][0][0][0][0] = &Rendtriangle<0, 1, 0, 0, 0, 0>;
			RendtriangleFns[0][1][0][0][0][1] = &Rendtriangle<0, 1, 0, 0, 0, 1>;
			RendtriangleFns[0][1][0][0][1][0] = &Rendtriangle<0, 1, 0, 0, 1, 0>;
			RendtriangleFns[0][1][0][0][1][1] = &Rendtriangle<0, 1, 0, 0, 1, 1>;
			RendtriangleFns[0][1][0][0][2][0] = &Rendtriangle<0, 1, 0, 0, 2, 0>;
			RendtriangleFns[0][1][0][0][2][1] = &Rendtriangle<0, 1, 0, 0, 2, 1>;
			RendtriangleFns[0][1][0][0][3][0] = &Rendtriangle<0, 1, 0, 0, 3, 0>;
			RendtriangleFns[0][1][0][0][3][1] = &Rendtriangle<0, 1, 0, 0, 3, 1>;
			RendtriangleFns[0][1][0][1][0][0] = &Rendtriangle<0, 1, 0, 1, 0, 0>;
			RendtriangleFns[0][1][0][1][0][1] = &Rendtriangle<0, 1, 0, 1, 0, 1>;
			RendtriangleFns[0][1][0][1][1][0] = &Rendtriangle<0, 1, 0, 1, 1, 0>;
			RendtriangleFns[0][1][0][1][1][1] = &Rendtriangle<0, 1, 0, 1, 1, 1>;
			RendtriangleFns[0][1][0][1][2][0] = &Rendtriangle<0, 1, 0, 1, 2, 0>;
			RendtriangleFns[0][1][0][1][2][1] = &Rendtriangle<0, 1, 0, 1, 2, 1>;
			RendtriangleFns[0][1][0][1][3][0] = &Rendtriangle<0, 1, 0, 1, 3, 0>;
			RendtriangleFns[0][1][0][1][3][1] = &Rendtriangle<0, 1, 0, 1, 3, 1>;
			RendtriangleFns[1][0][1][0][0][0] = &Rendtriangle<1, 0, 1, 0, 0, 0>;
			RendtriangleFns[1][0][1][0][0][1] = &Rendtriangle<1, 0, 1, 0, 0, 1>;
			RendtriangleFns[1][0][1][0][1][0] = &Rendtriangle<1, 0, 1, 0, 1, 0>;
			RendtriangleFns[1][0][1][0][1][1] = &Rendtriangle<1, 0, 1, 0, 1, 1>;
			RendtriangleFns[1][0][1][0][2][0] = &Rendtriangle<1, 0, 1, 0, 2, 0>;
			RendtriangleFns[1][0][1][0][2][1] = &Rendtriangle<1, 0, 1, 0, 2, 1>;
			RendtriangleFns[1][0][1][0][3][0] = &Rendtriangle<1, 0, 1, 0, 3, 0>;
			RendtriangleFns[1][0][1][0][3][1] = &Rendtriangle<1, 0, 1, 0, 3, 1>;
			RendtriangleFns[1][0][1][1][0][0] = &Rendtriangle<1, 0, 1, 1, 0, 0>;
			RendtriangleFns[1][0][1][1][0][1] = &Rendtriangle<1, 0, 1, 1, 0, 1>;
			RendtriangleFns[1][0][1][1][1][0] = &Rendtriangle<1, 0, 1, 1, 1, 0>;
			RendtriangleFns[1][0][1][1][1][1] = &Rendtriangle<1, 0, 1, 1, 1, 1>;
			RendtriangleFns[1][0][1][1][2][0] = &Rendtriangle<1, 0, 1, 1, 2, 0>;
			RendtriangleFns[1][0][1][1][2][1] = &Rendtriangle<1, 0, 1, 1, 2, 1>;
			RendtriangleFns[1][0][1][1][3][0] = &Rendtriangle<1, 0, 1, 1, 3, 0>;
			RendtriangleFns[1][0][1][1][3][1] = &Rendtriangle<1, 0, 1, 1, 3, 1>;
			RendtriangleFns[1][0][0][0][0][0] = &Rendtriangle<1, 0, 0, 0, 0, 0>;
			RendtriangleFns[1][0][0][0][0][1] = &Rendtriangle<1, 0, 0, 0, 0, 1>;
			RendtriangleFns[1][0][0][0][1][0] = &Rendtriangle<1, 0, 0, 0, 1, 0>;
			RendtriangleFns[1][0][0][0][1][1] = &Rendtriangle<1, 0, 0, 0, 1, 1>;
			RendtriangleFns[1][0][0][0][2][0] = &Rendtriangle<1, 0, 0, 0, 2, 0>;
			RendtriangleFns[1][0][0][0][2][1] = &Rendtriangle<1, 0, 0, 0, 2, 1>;
			RendtriangleFns[1][0][0][0][3][0] = &Rendtriangle<1, 0, 0, 0, 3, 0>;
			RendtriangleFns[1][0][0][0][3][1] = &Rendtriangle<1, 0, 0, 0, 3, 1>;
			RendtriangleFns[1][0][0][1][0][0] = &Rendtriangle<1, 0, 0, 1, 0, 0>;
			RendtriangleFns[1][0][0][1][0][1] = &Rendtriangle<1, 0, 0, 1, 0, 1>;
			RendtriangleFns[1][0][0][1][1][0] = &Rendtriangle<1, 0, 0, 1, 1, 0>;
			RendtriangleFns[1][0][0][1][1][1] = &Rendtriangle<1, 0, 0, 1, 1, 1>;
			RendtriangleFns[1][0][0][1][2][0] = &Rendtriangle<1, 0, 0, 1, 2, 0>;
			RendtriangleFns[1][0][0][1][2][1] = &Rendtriangle<1, 0, 0, 1, 2, 1>;
			RendtriangleFns[1][0][0][1][3][0] = &Rendtriangle<1, 0, 0, 1, 3, 0>;
			RendtriangleFns[1][0][0][1][3][1] = &Rendtriangle<1, 0, 0, 1, 3, 1>;
			RendtriangleFns[1][1][1][0][0][0] = &Rendtriangle<1, 1, 1, 0, 0, 0>;
			RendtriangleFns[1][1][1][0][0][1] = &Rendtriangle<1, 1, 1, 0, 0, 1>;
			RendtriangleFns[1][1][1][0][1][0] = &Rendtriangle<1, 1, 1, 0, 1, 0>;
			RendtriangleFns[1][1][1][0][1][1] = &Rendtriangle<1, 1, 1, 0, 1, 1>;
			RendtriangleFns[1][1][1][0][2][0] = &Rendtriangle<1, 1, 1, 0, 2, 0>;
			RendtriangleFns[1][1][1][0][2][1] = &Rendtriangle<1, 1, 1, 0, 2, 1>;
			RendtriangleFns[1][1][1][0][3][0] = &Rendtriangle<1, 1, 1, 0, 3, 0>;
			RendtriangleFns[1][1][1][0][3][1] = &Rendtriangle<1, 1, 1, 0, 3, 1>;
			RendtriangleFns[1][1][1][1][0][0] = &Rendtriangle<1, 1, 1, 1, 0, 0>;
			RendtriangleFns[1][1][1][1][0][1] = &Rendtriangle<1, 1, 1, 1, 0, 1>;
			RendtriangleFns[1][1][1][1][1][0] = &Rendtriangle<1, 1, 1, 1, 1, 0>;
			RendtriangleFns[1][1][1][1][1][1] = &Rendtriangle<1, 1, 1, 1, 1, 1>;
			RendtriangleFns[1][1][1][1][2][0] = &Rendtriangle<1, 1, 1, 1, 2, 0>;
			RendtriangleFns[1][1][1][1][2][1] = &Rendtriangle<1, 1, 1, 1, 2, 1>;
			RendtriangleFns[1][1][1][1][3][0] = &Rendtriangle<1, 1, 1, 1, 3, 0>;
			RendtriangleFns[1][1][1][1][3][1] = &Rendtriangle<1, 1, 1, 1, 3, 1>;
			RendtriangleFns[1][1][0][0][0][0] = &Rendtriangle<1, 1, 0, 0, 0, 0>;
			RendtriangleFns[1][1][0][0][0][1] = &Rendtriangle<1, 1, 0, 0, 0, 1>;
			RendtriangleFns[1][1][0][0][1][0] = &Rendtriangle<1, 1, 0, 0, 1, 0>;
			RendtriangleFns[1][1][0][0][1][1] = &Rendtriangle<1, 1, 0, 0, 1, 1>;
			RendtriangleFns[1][1][0][0][2][0] = &Rendtriangle<1, 1, 0, 0, 2, 0>;
			RendtriangleFns[1][1][0][0][2][1] = &Rendtriangle<1, 1, 0, 0, 2, 1>;
			RendtriangleFns[1][1][0][0][3][0] = &Rendtriangle<1, 1, 0, 0, 3, 0>;
			RendtriangleFns[1][1][0][0][3][1] = &Rendtriangle<1, 1, 0, 0, 3, 1>;
			RendtriangleFns[1][1][0][1][0][0] = &Rendtriangle<1, 1, 0, 1, 0, 0>;
			RendtriangleFns[1][1][0][1][0][1] = &Rendtriangle<1, 1, 0, 1, 0, 1>;
			RendtriangleFns[1][1][0][1][1][0] = &Rendtriangle<1, 1, 0, 1, 1, 0>;
			RendtriangleFns[1][1][0][1][1][1] = &Rendtriangle<1, 1, 0, 1, 1, 1>;
			RendtriangleFns[1][1][0][1][2][0] = &Rendtriangle<1, 1, 0, 1, 2, 0>;
			RendtriangleFns[1][1][0][1][2][1] = &Rendtriangle<1, 1, 0, 1, 2, 1>;
			RendtriangleFns[1][1][0][1][3][0] = &Rendtriangle<1, 1, 0, 1, 3, 0>;
			RendtriangleFns[1][1][0][1][3][1] = &Rendtriangle<1, 1, 0, 1, 3, 1>;


			RendtriangleFns[2][0][1][0][0][0] = &Rendtriangle<2, 0, 1, 0, 0, 0>;
			RendtriangleFns[2][0][1][0][0][1] = &Rendtriangle<2, 0, 1, 0, 0, 1>;
			RendtriangleFns[2][0][1][0][1][0] = &Rendtriangle<2, 0, 1, 0, 1, 0>;
			RendtriangleFns[2][0][1][0][1][1] = &Rendtriangle<2, 0, 1, 0, 1, 1>;
			RendtriangleFns[2][0][1][0][2][0] = &Rendtriangle<2, 0, 1, 0, 2, 0>;
			RendtriangleFns[2][0][1][0][2][1] = &Rendtriangle<2, 0, 1, 0, 2, 1>;
			RendtriangleFns[2][0][1][0][3][0] = &Rendtriangle<2, 0, 1, 0, 3, 0>;
			RendtriangleFns[2][0][1][0][3][1] = &Rendtriangle<2, 0, 1, 0, 3, 1>;
			RendtriangleFns[2][0][1][1][0][0] = &Rendtriangle<2, 0, 1, 1, 0, 0>;
			RendtriangleFns[2][0][1][1][0][1] = &Rendtriangle<2, 0, 1, 1, 0, 1>;
			RendtriangleFns[2][0][1][1][1][0] = &Rendtriangle<2, 0, 1, 1, 1, 0>;
			RendtriangleFns[2][0][1][1][1][1] = &Rendtriangle<2, 0, 1, 1, 1, 1>;
			RendtriangleFns[2][0][1][1][2][0] = &Rendtriangle<2, 0, 1, 1, 2, 0>;
			RendtriangleFns[2][0][1][1][2][1] = &Rendtriangle<2, 0, 1, 1, 2, 1>;
			RendtriangleFns[2][0][1][1][3][0] = &Rendtriangle<2, 0, 1, 1, 3, 0>;
			RendtriangleFns[2][0][1][1][3][1] = &Rendtriangle<2, 0, 1, 1, 3, 1>;
			RendtriangleFns[2][0][0][0][0][0] = &Rendtriangle<2, 0, 0, 0, 0, 0>;
			RendtriangleFns[2][0][0][0][0][1] = &Rendtriangle<2, 0, 0, 0, 0, 1>;
			RendtriangleFns[2][0][0][0][1][0] = &Rendtriangle<2, 0, 0, 0, 1, 0>;
			RendtriangleFns[2][0][0][0][1][1] = &Rendtriangle<2, 0, 0, 0, 1, 1>;
			RendtriangleFns[2][0][0][0][2][0] = &Rendtriangle<2, 0, 0, 0, 2, 0>;
			RendtriangleFns[2][0][0][0][2][1] = &Rendtriangle<2, 0, 0, 0, 2, 1>;
			RendtriangleFns[2][0][0][0][3][0] = &Rendtriangle<2, 0, 0, 0, 3, 0>;
			RendtriangleFns[2][0][0][0][3][1] = &Rendtriangle<2, 0, 0, 0, 3, 1>;
			RendtriangleFns[2][0][0][1][0][0] = &Rendtriangle<2, 0, 0, 1, 0, 0>;
			RendtriangleFns[2][0][0][1][0][1] = &Rendtriangle<2, 0, 0, 1, 0, 1>;
			RendtriangleFns[2][0][0][1][1][0] = &Rendtriangle<2, 0, 0, 1, 1, 0>;
			RendtriangleFns[2][0][0][1][1][1] = &Rendtriangle<2, 0, 0, 1, 1, 1>;
			RendtriangleFns[2][0][0][1][2][0] = &Rendtriangle<2, 0, 0, 1, 2, 0>;
			RendtriangleFns[2][0][0][1][2][1] = &Rendtriangle<2, 0, 0, 1, 2, 1>;
			RendtriangleFns[2][0][0][1][3][0] = &Rendtriangle<2, 0, 0, 1, 3, 0>;
			RendtriangleFns[2][0][0][1][3][1] = &Rendtriangle<2, 0, 0, 1, 3, 1>;
			RendtriangleFns[2][1][1][0][0][0] = &Rendtriangle<2, 1, 1, 0, 0, 0>;
			RendtriangleFns[2][1][1][0][0][1] = &Rendtriangle<2, 1, 1, 0, 0, 1>;
			RendtriangleFns[2][1][1][0][1][0] = &Rendtriangle<2, 1, 1, 0, 1, 0>;
			RendtriangleFns[2][1][1][0][1][1] = &Rendtriangle<2, 1, 1, 0, 1, 1>;
			RendtriangleFns[2][1][1][0][2][0] = &Rendtriangle<2, 1, 1, 0, 2, 0>;
			RendtriangleFns[2][1][1][0][2][1] = &Rendtriangle<2, 1, 1, 0, 2, 1>;
			RendtriangleFns[2][1][1][0][3][0] = &Rendtriangle<2, 1, 1, 0, 3, 0>;
			RendtriangleFns[2][1][1][0][3][1] = &Rendtriangle<2, 1, 1, 0, 3, 1>;
			RendtriangleFns[2][1][1][1][0][0] = &Rendtriangle<2, 1, 1, 1, 0, 0>;
			RendtriangleFns[2][1][1][1][0][1] = &Rendtriangle<2, 1, 1, 1, 0, 1>;
			RendtriangleFns[2][1][1][1][1][0] = &Rendtriangle<2, 1, 1, 1, 1, 0>;
			RendtriangleFns[2][1][1][1][1][1] = &Rendtriangle<2, 1, 1, 1, 1, 1>;
			RendtriangleFns[2][1][1][1][2][0] = &Rendtriangle<2, 1, 1, 1, 2, 0>;
			RendtriangleFns[2][1][1][1][2][1] = &Rendtriangle<2, 1, 1, 1, 2, 1>;
			RendtriangleFns[2][1][1][1][3][0] = &Rendtriangle<2, 1, 1, 1, 3, 0>;
			RendtriangleFns[2][1][1][1][3][1] = &Rendtriangle<2, 1, 1, 1, 3, 1>;
			RendtriangleFns[2][1][0][0][0][0] = &Rendtriangle<2, 1, 0, 0, 0, 0>;
			RendtriangleFns[2][1][0][0][0][1] = &Rendtriangle<2, 1, 0, 0, 0, 1>;
			RendtriangleFns[2][1][0][0][1][0] = &Rendtriangle<2, 1, 0, 0, 1, 0>;
			RendtriangleFns[2][1][0][0][1][1] = &Rendtriangle<2, 1, 0, 0, 1, 1>;
			RendtriangleFns[2][1][0][0][2][0] = &Rendtriangle<2, 1, 0, 0, 2, 0>;
			RendtriangleFns[2][1][0][0][2][1] = &Rendtriangle<2, 1, 0, 0, 2, 1>;
			RendtriangleFns[2][1][0][0][3][0] = &Rendtriangle<2, 1, 0, 0, 3, 0>;
			RendtriangleFns[2][1][0][0][3][1] = &Rendtriangle<2, 1, 0, 0, 3, 1>;
			RendtriangleFns[2][1][0][1][0][0] = &Rendtriangle<2, 1, 0, 1, 0, 0>;
			RendtriangleFns[2][1][0][1][0][1] = &Rendtriangle<2, 1, 0, 1, 0, 1>;
			RendtriangleFns[2][1][0][1][1][0] = &Rendtriangle<2, 1, 0, 1, 1, 0>;
			RendtriangleFns[2][1][0][1][1][1] = &Rendtriangle<2, 1, 0, 1, 1, 1>;
			RendtriangleFns[2][1][0][1][2][0] = &Rendtriangle<2, 1, 0, 1, 2, 0>;
			RendtriangleFns[2][1][0][1][2][1] = &Rendtriangle<2, 1, 0, 1, 2, 1>;
			RendtriangleFns[2][1][0][1][3][0] = &Rendtriangle<2, 1, 0, 1, 3, 0>;
			RendtriangleFns[2][1][0][1][3][1] = &Rendtriangle<2, 1, 0, 1, 3, 1>;
		}

		return true;
	}

	virtual void Resize(int w, int h) {

	}

	virtual void Term() {
#if HOST_OS == OS_WINDOWS
		if (hBMP) {
			DeleteObject(SelectObject(hmem, holdBMP));
			DeleteDC(hmem);
		}
#endif
	}

	#define RR(x, a, b, c, d) (x + a), (x + b), (x + c), (x + d)
	#define R(a, b, c, d) RR(12, a, b, c, d), RR(8, a, b, c, d), RR(4, a, b, c, d),  RR(0, a, b, c, d)

	//R coefs should be adjusted to match pixel format
	INLINE __m128 shuffle_pixel(__m128 v) {
		return _mm_cvtepi32_ps(_mm_shuffle_epi8(_mm_cvtps_epi32(v), _mm_set_epi8(R(0x80, 2, 1, 0))));
	}

	virtual void Present() {

		__m128* psrc = (__m128*)render_buffer;
		__m128* pdst = (__m128*)pixels;

		#define SHUFFL(v) v
		//	#define SHUFFL(v) shuffle_pixel(v)

		#if HOST_OS == OS_WINDOWS
			#define FLIP_Y 479 -
		#else
			#define FLIP_Y
		#endif

		const int stride = STRIDE_PIXEL_OFFSET / 4;
		for (int y = 0; y<MAX_RENDER_HEIGHT; y += 4)
		{
			for (int x = 0; x<MAX_RENDER_WIDTH; x += 4)
			{
				pdst[(FLIP_Y (y + 0))*stride + x / 4] = SHUFFL(*psrc++);
				pdst[(FLIP_Y (y + 1))*stride + x / 4] = SHUFFL(*psrc++);
				pdst[(FLIP_Y (y + 2))*stride + x / 4] = SHUFFL(*psrc++);
				pdst[(FLIP_Y (y + 3))*stride + x / 4] = SHUFFL(*psrc++);
			}
		}

#if HOST_OS == OS_WINDOWS
		SetDIBits(hmem, hBMP, 0, 480, pixels, (BITMAPINFO*)&bi, DIB_RGB_COLORS);

		RECT clientRect;

		GetClientRect(hWnd, &clientRect);

		HDC hdc = GetDC(hWnd);
		int w = clientRect.right - clientRect.left;
		int h = clientRect.bottom - clientRect.top;
		int x = (w - 640) / 2;
		int y = (h - 480) / 2;

		BitBlt(hdc, x, y, 640 , 480 , hmem, 0, 0, SRCCOPY);
		ReleaseDC(hWnd, hdc);
#elif defined(SUPPORT_X11)
		extern Window x11_win;
		extern Display* x11_disp;
		extern Visual* x11_vis;

		int width = 640;
		int height = 480;

		extern int x11_width;
		extern int x11_height;

		XImage* ximage = XCreateImage(x11_disp, x11_vis, 24, ZPixmap, 0, (char *)pixels, width, height, 32, width * 4);

		GC gc = XCreateGC(x11_disp, x11_win, 0, 0);
		XPutImage(x11_disp, x11_win, gc, ximage, 0, 0, (x11_width - width)/2, (x11_height - height)/2, width, height);
		XFree(ximage);
		XFreeGC(x11_disp, gc);
#else
	// TODO softrend without X11 (SDL f.e.)
	#error Cannot use softrend without X11
#endif
	}
};

Renderer* rend_softrend() {
	return new(_mm_malloc(sizeof(softrend), 32)) softrend();
}
