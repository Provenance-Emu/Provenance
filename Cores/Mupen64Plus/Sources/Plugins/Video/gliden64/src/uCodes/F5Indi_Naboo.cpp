/* Ucodes for "Indiana Jones and the Infernal Machine" and "Star Wars Episode I - Battle for Naboo".
 * Microcode decoding: olivieryuyu
 */

#include <assert.h>
#include <stdlib.h>
#include <time.h>
#include <memory.h>
#include <cmath>
#include <vector>
#include "GLideN64.h"
#include "F3D.h"
#include "F5Indi_Naboo.h"
#include "RSP.h"
#include "RDP.h"
#include "gSP.h"
#include "gDP.h"
#include "Config.h"
#include "Combiner.h"
#include "FrameBuffer.h"
#include "DisplayWindow.h"
#include "Debugger.h"

#include "DebugDump.h"
#include "Log.h"

#define F5INDI_MOVEMEM			0x01
#define F5INDI_SET_DLIST_ADDR	0x02
#define F5INDI_GEOMETRY_GEN		0x05
#define F5INDI_DL				0x06
#define F5INDI_BRANCHDL			0x07
#define F5INDI_TRI2				0xB4
#define F5INDI_JUMPDL			0xB5
#define F5INDI_ENDDL			0xB8
#define F5INDI_MOVEWORD			0xBC
#define F5INDI_TRI1				0xBF
#define F5INDI_TEXRECT			0xE4
#define F5INDI_SETOTHERMODE		0xBA
#define F5INDI_SETOTHERMODE_C	0xB9
#define F5NABOO_BE				0xBE

#define CAST_DMEM(type, addr) reinterpret_cast<type>(DMEM + addr)
#define CAST_RDRAM(type, addr) reinterpret_cast<type>(RDRAM + addr)

static u32 G_SET_DLIST_ADDR, G_BE, G_JUMPDL, G_INDI_TEXRECT;

struct IndiData {
	s32 mtx_st_adjust[16];
	f32 mtx_vtx_gen[4][4];
};

IndiData & getIndiData()
{
	static IndiData data;
	return data;
}

struct NabooData {
	u16 AA;
	s16 BB;
	s16 EE;
	s16 HH;
	u8 DD;
	u8 CC;
	u8 TT;
	u8 pad;
};

static
NabooData & getNabooData()
{
	static NabooData data;
	return data;
}

static
void _updateF5DL()
{
	RSP.F5DL[RSP.PCi] = _SHIFTR(*CAST_RDRAM(u32*, RSP.PC[RSP.PCi]), 0, 24);
}

static
void F5INDI_LoadSTMatrix()
{
	const u16* mtx_i = CAST_DMEM(const u16*, 0xE40);
	const u16* mtx_f = CAST_DMEM(const u16*, 0xE60);
	s32 * mtx = getIndiData().mtx_st_adjust;
	for (u32 i = 0; i < 16; ++i)
		mtx[i] = (mtx_i[i ^ 1] << 16) | mtx_f[i ^ 1];
}

static
void F5INDI_DMA_Direct(u32 _w0, u32 _w1)
{
	u32 * pSrc = CAST_RDRAM(u32*, _SHIFTR(_w1, 0, 24));
	u32 * pDst = CAST_DMEM(u32*, _SHIFTR(_w0, 8, 12));
	const u32 count = (_SHIFTR(_w0, 0, 8) + 1) >> 2;
	for (u32 i = 0; i < count; ++i) {
		pDst[i] = pSrc[i];
	}
}

static
void F5INDI_DMA_Segmented(u32 _w0, u32 _w1)
{
	if (_SHIFTR(_w0, 0, 8) == 0)
		return;
	u32 * FD4 = CAST_DMEM(u32*, 0xFD4);
	u32 * FD8 = CAST_DMEM(u32*, 0xFD8);
	u32 * FDC = CAST_DMEM(u32*, 0xFDC);
	s32 A0 = _SHIFTR(_w0, 0, 8);
	u32 A2 = *FDC;
	s32 A3 = A0 + 1;
	s32 A1 = A2 - A3;
	u32 V1 = _SHIFTR(_w0, 8, 12);
	while (A1 < 0) {
		u32 V0 = *FD4;
		A3 = A0 - A2;
		memcpy(DMEM + V1, RDRAM + _SHIFTR(V0, 0, 24), A2);

		V1 += A2;
		A0 = A3;
		_w1 = *FD8;

		u32 * pSrc = CAST_RDRAM(u32*, _SHIFTR(_w1, 0, 24));
		*FD8 = *pSrc;
		*FDC = 0x100;
		*FD4 = _w1 + 0x08;

		A2 = *FDC;
		A3 = A0 + 1;
		A1 = A2 - A3;
	}

	u32 V0 = *FD4;
	u32 T0 = V0 + A3;
	memcpy(DMEM + V1, RDRAM + _SHIFTR(V0, 0, 24), A0 + 1);
	*FDC = A1;
	*FD4 = T0;
}

static
void F5INDI_Lighting_Overlay1(u32 _w0, u32 _w1)
{
	const u32 S = ((_SHIFTR(_w1, 24, 7) << 2) + 4) & 0xFFF8;
	memset(DMEM + 0xD40, 0, S);

	u8 L = *(DMEM + (0x58B ^ 3));
	if (L == 0) {
		*CAST_DMEM(u64*, 0x05B0) = 0U;
		return;
	}

	u32 lightAddr = 0xB10;
	const u32 dataAddr = _SHIFTR(_w0, 8, 12);

	while (true) {
		u8 * dst = DMEM + 0xD40;
		const u8* data = DMEM + dataAddr;
		const u8* light = DMEM + lightAddr;
		if (*light == 0) {
			const u32 count = S >> 3;
			for (u32 i = 0; i < count; ++i) {
				const u8* factor = DMEM + 0x158;
				dst[0] = (data[0] * factor[0]) >> 8;
				for (u32 j = 1; j < 4; ++j) {
					dst[j] = std::min(((data[j] * factor[j] * light[j]) >> 16) + dst[j], 0xFF);
				}
				factor += 4;
				dst += 4;
				data += 4;
				dst[0] = (data[0] * factor[0]) >> 8;
				for (u32 j = 1; j < 4; ++j) {
					dst[j] = std::min(((data[j] * factor[j] * light[j]) >> 16) + dst[j], 0xFF);
				}
				dst += 4;
				data += 4;
			}
		} else {
			u8* offsetAddr = DMEM + 0x380;
			u32 offsetAddrIdx = 0;
			u64 vtxAddrPos = *CAST_DMEM(u64*, 0x05B0);
			const u32 factors[2] = { *CAST_DMEM(u32*, 0x158), *CAST_DMEM(u32*, 0x15C) };
			const u32 count = S >> 3;
			for (u32 i = 0; i < count; ++i) {
				u32 vtxAddr[2];
				switch (vtxAddrPos & 3) {
				case 0:
					vtxAddr[0] = vtxAddr[1] = lightAddr - 0x10;
					break;
				case 1:
					vtxAddr[0] = lightAddr - 0x08;
					vtxAddr[1] = lightAddr - 0x10;
					break;
				case 2:
					vtxAddr[0] = lightAddr - 0x10;
					vtxAddr[1] = lightAddr - 0x08;
					break;
				case 3:
					vtxAddr[0] = vtxAddr[1] = lightAddr - 0x08;
					break;
				}
				vtxAddrPos >>= 2;
				for (u32 j = 0; j < 2; ++j) {
					const u32 * V = CAST_DMEM(const u32*, vtxAddr[j]);
					s16 X1 = (s16)_SHIFTR(*V, 16, 16);
					s16 Y1 = (s16)_SHIFTR(*V, 0, 16);
					++V;
					s16 Z1 = (s16)_SHIFTR(*V, 16, 16);

					V = CAST_DMEM(const u32*, 0x170 + offsetAddr[offsetAddrIdx^3]);
					offsetAddrIdx++;
					s16 X = (s16)_SHIFTR(*V, 16, 16);
					s16 Y = (s16)_SHIFTR(*V, 0, 16);
					++V;
					s16 Z = (s16)_SHIFTR(*V, 16, 16);
					X -= X1;
					Y -= Y1;
					Z -= Z1;

					u64 T = *CAST_DMEM(const u32*, lightAddr + 4);
					T = 0xFFFF000000000000 | (T << 16);
					u64 K = (X * X + Y * Y + Z * Z) * T;
					u32 P = K >> 32;
					u32 P1 = 0;
					if ((P & 0xFFFF0000) == 0xFFFF0000)
						P1 = P & 0xFFFF;

					V = CAST_DMEM(const u32*, lightAddr);

					u32 D = (_SHIFTR(*V, 24, 8) * P1) >> 16;
					u32 E = (_SHIFTR(*V, 16, 8) * P1) >> 16;
					u32 F = (_SHIFTR(*V, 8, 8) * P1) >> 16;
					u32 J = (_SHIFTR(factors[j], 0, 8) * data[3 ^ 3]) >> 8;

					if (*light == 4) {
						*dst = J;
						dst++;
						*dst = std::min(*dst + F, 0xFFU);
						dst++;
						*dst = std::min(*dst + E, 0xFFU);
						dst++;
						*dst = std::min(*dst + D, 0xFFU);
						dst++;
					} else {
						D += (_SHIFTR(factors[j], 24, 8) * data[0 ^ 3]) >> 8;
						E += (_SHIFTR(factors[j], 16, 8) * data[1 ^ 3]) >> 8;
						F += (_SHIFTR(factors[j], 8, 8) * data[2 ^ 3]) >> 8;
						*dst = J;
						dst++;
						*dst = std::min(F >> 1, 0xFFU);
						dst++;
						*dst = std::min(E >> 1, 0xFFU);
						dst++;
						*dst = std::min(D >> 1, 0xFFU);
						dst++;
					}
					data += 4;
				}
			}
		}

		--L;
		if (L == 0) {
			*CAST_DMEM(u64*, 0x05B0) = 0U;
			const u32 A = *CAST_DMEM(const u32*, 0x5A8);
			if (A == 0xFFFFFFFF)
				return;
			u8 * dst = DMEM + 0xD40;
			const u8* factor = DMEM + 0x5A8;
			const u32 count = S >> 2;
			for (u32 i = 0; i < count; ++i) {
				for (u32 j = 0; j < 4; ++j) {
					dst[j] = (dst[j] * factor[j]) >> 8;
				}
				dst += 4;
			}
			return;
		}

		lightAddr += 0x18;
	}
}

static
void F5INDI_Lighting_Overlay2(u32 _w0, u32 _w1)
{
	const u32 S = ((_SHIFTR(_w1, 24, 7) << 2) + 4) & 0xFFF8;
	memset(DMEM + 0xD40, 0, S + 8);

	u8 L = *(DMEM + (0x58B ^ 3));
	if (L == 0) {
		*CAST_DMEM(u64*, 0x05B0) = 0U;
		return;
	}

	u32 lightAddr = 0xB10;
	const u32 dataAddr = _SHIFTR(_w0, 8, 12);

	while (true) {
		u8 * dst = DMEM + 0xD40;
		const u8* data = DMEM + dataAddr;
		const u8* light = DMEM + lightAddr;
		if (*light == 0) {
			const u32 count = S >> 3;
			for (u32 i = 0; i < count; ++i) {
				const u8* factor = DMEM + 0x158;
				dst[0] = (data[0] * factor[0]) >> 8;
				for (u32 j = 1; j < 4; ++j) {
					dst[j] = std::min(((data[j] * factor[j] * light[j]) >> 16) + dst[j], 0xFF);
				}
				factor += 4;
				dst += 4;
				data += 4;
				dst[0] = (data[0] * factor[0]) >> 8;
				for (u32 j = 1; j < 4; ++j) {
					dst[j] = std::min(((data[j] * factor[j] * light[j]) >> 16) + dst[j], 0xFF);
				}
				dst += 4;
				data += 4;
			}
		} else if (*light == 1) {
			u32 factor2Addr = 0x380;
			u64 vtxAddrPos = *CAST_DMEM(const u64*, 0x05B0);
			const u32 factors[2] = { *CAST_DMEM(const u32*, 0x158), *CAST_DMEM(const u32*, 0x15C) };
			const u32 count = S >> 3;
			for (u32 i = 0; i < count; ++i) {
				u32 vtxAddr[2];
				switch (vtxAddrPos & 3) {
				case 0:
					vtxAddr[0] = vtxAddr[1] = lightAddr - 0x10;
					break;
				case 1:
					vtxAddr[0] = lightAddr - 0x08;
					vtxAddr[1] = lightAddr - 0x10;
					break;
				case 2:
					vtxAddr[0] = lightAddr - 0x10;
					vtxAddr[1] = lightAddr - 0x08;
					break;
				case 3:
					vtxAddr[0] = vtxAddr[1] = lightAddr - 0x08;
					break;
				}
				vtxAddrPos >>= 2;
				for (u32 j = 0; j < 2; ++j) {
					u32 V = *CAST_DMEM(const u32*, vtxAddr[j]);
					s16 X = (s16)_SHIFTR(V, 16, 16);
					s16 Y = (s16)_SHIFTR(V, 0, 16);
					V = *CAST_DMEM(const u32*, vtxAddr[j] + 0x04);
					s16 Z = (s16)_SHIFTR(V, 16, 16);

					V = *CAST_DMEM(const u32*, factor2Addr);
					u32 I = (u32)(((X * char(_SHIFTR(V, 24, 8)) + Y * char(_SHIFTR(V, 16, 8)) + Z * char(_SHIFTR(V, 8, 8))) >> 8) & 0xFFFF);
					if ((I & 0x8000) != 0)
						I = 0;
					V = *CAST_DMEM(const u32*, lightAddr);
					u32 D = (_SHIFTR(V, 24, 8) * I) >> 8;
					u32 E = (_SHIFTR(V, 16, 8) * I) >> 8;
					u32 F = (_SHIFTR(V, 8, 8) * I) >> 8;
					V = factors[j];
					u32 K = _SHIFTR(V, 0, 8) * (*data++);
					u32 J = _SHIFTR(V, 8, 8) * (*data++);
					u32 H = _SHIFTR(V, 16, 8) * (*data++);
					u32 G = _SHIFTR(V, 24, 8) * (*data++);
					*dst = K >> 8;
					dst++;
					*dst = std::min(*dst + ((F * J) >> 22), 0xFFU);
					dst++;
					*dst = std::min(*dst + ((E * H) >> 22), 0xFFU);
					dst++;
					*dst = std::min(*dst + ((D * G) >> 22), 0xFFU);
					dst++;
					factor2Addr += 4;
				}
			}
		} else {
			u32 offsetAddr = 0x380;
			const u32 factors[2] = { *CAST_DMEM(const u32*, 0x158), *CAST_DMEM(const u32*, 0x15C) };
			const u32 count = S >> 3;
			u32 vtxAddr[2] = { lightAddr - 0x10, lightAddr - 0x10 };
			for (u32 i = 0; i < count; ++i) {
				for (u32 j = 0; j < 2; ++j) {
					const u32 * V = CAST_DMEM(const u32*, vtxAddr[j]);
					s16 X1 = (s16)_SHIFTR(*V, 16, 16);
					s16 Y1 = (s16)_SHIFTR(*V, 0, 16);
					++V;
					s16 Z1 = (s16)_SHIFTR(*V, 16, 16);

					u32 offset = *CAST_DMEM(const u32*, offsetAddr + j * 4);
					V = CAST_DMEM(const u32*, 0x170 + _SHIFTR(offset, 0, 8));
					s16 X = (s16)_SHIFTR(*V, 16, 16);
					s16 Y = (s16)_SHIFTR(*V, 0, 16);
					++V;
					s16 Z = (s16)_SHIFTR(*V, 16, 16);
					X -= X1;
					Y -= Y1;
					Z -= Z1;

					u64 T = *CAST_DMEM(const u32*, lightAddr + 4);
					T = 0xFFFF000000000000 | (T << 16);
					u64 K = (X * X + Y * Y + Z * Z) * T;
					u32 P = static_cast<u32>(K >> 32);
					u32 P1 = 0;
					if ((P & 0xFFFF0000) == 0xFFFF0000)
						P1 = P & 0xFFFF;

					const u8* factor = DMEM + 0x158 + j * 4;
					dst[0] = (data[0] * factor[0]) >> 8;
					const u8* light = DMEM + lightAddr;
					for (u32 k = 1; k < 4; ++k) {
						dst[k] = std::min(((((light[k] * P1) >> 16) * data[k] * factor[k] + 0x8000) >> 16) + dst[k], 0xFFU);
					}
					dst += 4;
					data += 4;
				}
				offsetAddr += 8;
			}
		}

		--L;
		if (L == 0) {
			*CAST_DMEM(u64*, 0x05B0) = 0U;
			return;
		}

		lightAddr += 0x18;
	}
}

static
void F5INDI_Lighting_Basic(u32 _w0, u32 _w1)
{
	s32 count = _SHIFTR(_w1, 24, 7);
	const u8* factor = DMEM + 0x158;
	const u8* data = DMEM + _SHIFTR(_w0, 8, 12);
	u8 * dst = DMEM + 0xD40;
	while (count > 0) {
		for (u32 j = 0; j < 8; ++j) {
			dst[j] = (data[j] * factor[j]) >> 8;
		}
		dst += 8;
		data += 8;
		for (u32 j = 0; j < 8; ++j) {
			dst[j] = (data[j] * factor[j]) >> 8;
		}
		dst += 8;
		data += 8;
		count -= 4;
	}
}

static
void F5INDI_RebuildAndAdjustColors(u32 _w0, u32 _w1)
{
	const u32 addr = _SHIFTR(_w0, 8, 12);
	const u32 count = std::min(_SHIFTR(_w1, 24, 8), (0x588 - addr) >> 2);
	const u16* data = CAST_DMEM(const u16*, addr);
	std::vector<u32> vres(count);
	for (u32 i = 0; i < count; ++i) {
		u16 V = data[i ^ 1];
		u32 I = (V >> 8) & 0xF8;
		u32 J = (V & 0x7E0) >> 3;
		u32 K = (V & 0x1F) << 3;
		vres[i] = (I << 24) | (J << 16) | (K << 8) | 0xFF;
	}
	memcpy(DMEM + addr, vres.data(), count << 2);
}

static
const SWVertex * F5INDI_LoadVtx(u32 _w0, u32 _w1, std::vector<SWVertex> & _vres)
{
	const u32 count = _SHIFTR(_w1, 24, 8);
	const u32 dmem_addr = _SHIFTR(_w0, 8, 12);
	const u16* dmem_data = CAST_DMEM(const u16*, dmem_addr);
	const u32 base_addr = *CAST_DMEM(const u32*, 0x154);
	u32 * pres = reinterpret_cast<u32*>(_vres.data());
	const u16* v0_data = CAST_DMEM(const u16*, 0x128);
	const u16 X0 = v0_data[0 ^ 1];
	const u16 Y0 = v0_data[1 ^ 1];
	const u16 Z0 = v0_data[2 ^ 1];
	for (u32 i = 0; i < count; ++i) {
		const u32 rdram_addr = dmem_data[i ^ 1] * 6 + base_addr;
		const u16* rdram_data = CAST_RDRAM(const u16*, (rdram_addr & 0x00FFFFF8));
		const u32 shift = (rdram_addr & 7) >> 1;
		const u16 X = rdram_data[(shift + 0) ^ 1] + X0;
		const u16 Y = rdram_data[(shift + 1) ^ 1] + Y0;
		const u16 Z = rdram_data[(shift + 2) ^ 1] + Z0;
		*pres++ = (X << 16) | Y;
		*pres++ = Z << 16;
	}
	return _vres.data();
}

static
const SWVertex * F5INDI_AdjustVtx(u32 _w0, u32 _w1, std::vector<SWVertex> & _vres)
{
	const u32 dmem_addr = _SHIFTR(_w0, 8, 12);
	if (*CAST_DMEM(const u64*, 0x128) == 0)
		return CAST_DMEM(const SWVertex*, dmem_addr);
	const u16* v0_data = CAST_DMEM(const u16*, 0x128);
	const u16 X0 = v0_data[0 ^ 1];
	const u16 Y0 = v0_data[1 ^ 1];
	const u16 Z0 = v0_data[2 ^ 1];
	const u32 count = _SHIFTR(_w1, 24, 7);
	_vres.resize(count);
	u32 * pres = reinterpret_cast<u32*>(_vres.data());
	const u16* dmem_data = CAST_DMEM(const u16*, dmem_addr);
	for (u32 i = 0; i < count; ++i) {
		const u16 X = dmem_data[0 ^ 1] + X0;
		const u16 Y = dmem_data[1 ^ 1] + Y0;
		const u16 Z = dmem_data[2 ^ 1] + Z0;
		*pres++ = (X << 16) | Y;
		*pres++ = Z << 16;
		dmem_data += 4;
	}
	return _vres.data();
}

static
void F5INDI_MoveMem(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_01Cmd (0x%08x, 0x%08x)\n", _w0, _w1);

	if (_SHIFTR(_w1, 0, 24) != 0)
		F5INDI_DMA_Direct(_w0, _w1);
	else
		F5INDI_DMA_Segmented(_w0, _w1);

	switch (_w0 & 0x00f00000) {
	case 0x00000000:
		switch (_w0) {
		case 0x0101300F:
			gSPViewport(_w1);
			break;
		case 0x0105C03F:
			gSPForceMatrix(_w1);
			break;
		case 0x010E403F:
			RSP_LoadMatrix(getIndiData().mtx_vtx_gen, _SHIFTR(_w1, 0, 24));
			F5INDI_LoadSTMatrix();
			break;
		}
		break;

	case 0x00100000:
		{
		std::vector<SWVertex> vertices;
		const u32 n = _SHIFTR(_w1, 24, 7);
		gSPSWVertex(F5INDI_AdjustVtx(_w0, _w1, vertices), n, nullptr);
		}
		break;

	case 0x00300000:
		// Set num of lights
		*(DMEM + (0x058B^3)) = static_cast<u8>(_w1 >> 24);
		break;

	case 0x00500000:
	{
		const u32 n = _SHIFTR(_w1, 24, 7);
		std::vector<SWVertex> vres(n);
		gSPSWVertex(F5INDI_LoadVtx(_w0, _w1, vres), n, nullptr);
	}
	break;

	default:
		if (_SHIFTR(_w0, 8, 12) == 0x480) {
			// Lighting
			const u32 F = (_w0 >> 22);
			if ((F & 2) != 0)
				F5INDI_RebuildAndAdjustColors(_w0, _w1);
			const u8 L = *(DMEM + (0x58B ^ 3));
			const u32 C = _SHIFTR(_w1, 24, 8) | L;
			if ((C & 0x80) == 0) {
				if ((F & 1) != 0)
					F5INDI_Lighting_Overlay1(_w0, _w1);
				else
					F5INDI_Lighting_Overlay2(_w0, _w1);
			} else
				F5INDI_Lighting_Basic(_w0, _w1);
		}
	break;
	}
}

static
void F5INDI_SetDListAddr(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_SetDListAddr (0x%08x, 0x%08x)\n", _w0, _w1);
	const u32 count = _w0 & 0x1FF;
	const u32 * pSrc = CAST_RDRAM(const u32*, _SHIFTR(_w1, 0, 24));
	u32 * pDst = CAST_DMEM(u32*, 0xFD4);
	pDst[0] = _w1 + 8;
	pDst[1] = *pSrc;
	pDst[2] = count;
}

static
void F5INDI_DList(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_DList (0x%08x)\n", _w1);
	gSPDisplayList(_w1);
	_updateF5DL();
}

static
void F5INDI_BranchDList(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_BranchDList (0x%08x)\n", _w1);
	gSPBranchList(_w1);
	_updateF5DL();
}

static
void F5INDI_CalcST(const u32* params, u32 * _st)
{
	const s16 * subs = CAST_DMEM(const s16*, 0x0F0);
	const u16 * muls = CAST_DMEM(const u16*, 0x0EC);
	const s32 * mtx = getIndiData().mtx_st_adjust;

	const u32 num = (RSP.cmd == F5INDI_TRI2) ? 4 : 3;

	for (u32 i = 0; i < num; ++i) {
		const u32 idx = _SHIFTR(params[i + 4], 0, 8);
		const s16 * coords = CAST_DMEM(const s16*, 0x170 + idx);
		s16 X = coords[0 ^ 1];
		s16 Y = coords[1 ^ 1];
		s16 Z = coords[2 ^ 1];
		s32 X1 = X * mtx[0 + 4 * 0] + Y * mtx[0 + 4 * 1] + Z * mtx[0 + 4 * 2] + mtx[0 + 4 * 3];
		s32 Y1 = X * mtx[1 + 4 * 0] + Y * mtx[1 + 4 * 1] + Z * mtx[1 + 4 * 2] + mtx[1 + 4 * 3];
		s32 Z1 = X * mtx[2 + 4 * 0] + Y * mtx[2 + 4 * 1] + Z * mtx[2 + 4 * 2] + mtx[2 + 4 * 3];
		X1 -= subs[0 ^ 1] << 16;
		Y1 -= subs[1 ^ 1] << 16;
		Z1 -= subs[2 ^ 1] << 16;
		u64 X2 = static_cast<s32>(X1);
		u64 X2_2 = (X2 * X2) >> 16;
		u64 Y2 = static_cast<s32>(Y1);
		u64 Y2_2 = (Y2 * Y2) >> 16;
		u64 Z2 = static_cast<s32>(Z1);
		u64 Z2_2 = (Z2 * Z2) >> 16;
		u64 R = X2_2 + Y2_2 + Z2_2;
		u32 R1 = static_cast<u32>(R);
		if (R > 0x0000FFFFFFFF)
			R1 = 0x7FFF0000 | (R & 0xFFFF);
		u32 D = static_cast<u32>(sqrt(R1));
		D = (0xFFFFFFFF / D) >> 1;
		D = (D * 0xAB) >> 16;
		u32 V = static_cast<u32>((D * X2) >> 16);
		u32 W = static_cast<u32>((D * Y2) >> 16);
		u32 S = (V * muls[0 ^ 1]) >> 16;
		u32 T = (W * muls[1 ^ 1]) >> 16;
		_st[i] = (S << 16) | T;
	}
}

static
void F5INDI_DoSubDList()
{
	const u32 dlistAddr = _SHIFTR(*CAST_DMEM(const u32*, 0x58C), 0, 24);
	if (dlistAddr == 0)
		return;

	DebugMsg(DEBUG_LOW, "Start Sub DList\n");

	RSP.PCi++;
	RSP.F5DL[RSP.PCi] = _SHIFTR(*CAST_RDRAM(const u32*, dlistAddr), 0, 24);
	RSP.PC[RSP.PCi] = dlistAddr + 8;

	while (true) {
		RSP.w0 = *CAST_RDRAM(u32*, RSP.PC[RSP.PCi]);
		RSP.w1 = *CAST_RDRAM(u32*, RSP.PC[RSP.PCi] + 4);

		RSP.cmd = _SHIFTR(RSP.w0, 24, 8);

		DebugMsg(DEBUG_LOW, "0x%08lX: CMD=0x%02X W0=0x%08X W1=0x%08X\n", RSP.PC[RSP.PCi], RSP.cmd, RSP.w0, RSP.w1);

		if (RSP.w0 == 0xB8000000 && RSP.w1 == 0xFFFFFFFF)
			break;

		RSP.nextCmd = _SHIFTR(*CAST_RDRAM(const u32*, RSP.PC[RSP.PCi] + 8), 24, 8);

		GBI.cmd[RSP.cmd](RSP.w0, RSP.w1);
		RSP.PC[RSP.PCi] += 8;

		if (RSP.nextCmd == 0xBD) {
			// Naboo
			u32* command = CAST_DMEM(u32*, 0xE58);
			command[0] = RSP.w0;
			command[1] = RSP.w1;
			break;
		}
	}

	RSP.PCi--;
	*CAST_DMEM(u32*, 0x58C) = 0U;
	DebugMsg(DEBUG_LOW, "End Sub DList\n");
}

static
bool F5INDI_AddVertices(const u32 _vert[3], GraphicsDrawer & _drawer)
{
	if (_drawer.isClipped(_vert[0], _vert[1], _vert[2])) {
		return false;
	}

	for (u32 i = 0; i < 3; ++i) {
		SPVertex & vtx = _drawer.getVertex(_vert[i]);

		if ((gSP.geometryMode & G_SHADE) == 0) {
			// Prim shading
			vtx.flat_r = gDP.primColor.r;
			vtx.flat_g = gDP.primColor.g;
			vtx.flat_b = gDP.primColor.b;
			vtx.flat_a = gDP.primColor.a;
		}

		if (gDP.otherMode.depthSource == G_ZS_PRIM)
			vtx.z = gDP.primDepth.z * vtx.w;

		_drawer.getCurrentDMAVertex() = vtx;
	}

	return true;
}

void F5INDI_Tri(u32 _w0, u32 _w1)
{
	const bool bTri2 = RSP.cmd == F5INDI_TRI2;
	DebugMsg(DEBUG_NORMAL, "F5INDI_Tri%d (0x%08x, 0x%08x)\n", bTri2 ? 2 : 1, _w0, _w1);

	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);
	const u32 w3 = params[3];
	const u32 v1 = (_SHIFTR(_w1, 16, 12) - 0x600) / 40;
	const u32 v2 = (_SHIFTR(_w1,  0, 12) - 0x600) / 40;
	const u32 v3 = (_SHIFTR( w3, 16, 12) - 0x600) / 40;
	const u32 v4 = (_SHIFTR( w3,  0, 12) - 0x600) / 40;
	const u32 vert[4] = { v1, v2, v3, v4 };

	const u32 w2 = params[2];
	const u32 S1 = _SHIFTR(w2, 16, 8);
	const u32 S2 = _SHIFTR(w2,  8, 8);
	const u32 S3 = _SHIFTR(w2,  0, 8);
	const u32 S4 = _SHIFTR(w2, 24, 8);

	const u32 C1 = *CAST_DMEM(const u32*, 0xD40 + S1);
	const u32 C2 = *CAST_DMEM(const u32*, 0xD40 + S2);
	const u32 C3 = *CAST_DMEM(const u32*, 0xD40 + S3);
	const u32 C4 = *CAST_DMEM(const u32*, 0xD40 + S4);
	const u32 colors[4] = { C1, C2, C3, C4 };

	const bool useTex = (_w0 & 0x0200) != 0;

	u32 ST[4];
	const u32 * texbase;
	if ((_w0 & 0x0800) != 0) {
		F5INDI_CalcST(params, ST);
		texbase = ST;
	} else {
		texbase = params + 4;
	}

	// PrepareVertices
	const bool persp = gDP.otherMode.texturePersp != 0;
	const u8* colorbase = reinterpret_cast<const u8*>(colors);
	const u32 count = bTri2 ? 4 : 3;
	GraphicsDrawer & drawer = dwnd().getDrawer();
	for (u32 i = 0; i < count; ++i) {
		SPVertex & vtx = drawer.getVertex(vert[i]);
		const u8 *color = colorbase;
		colorbase += 4;
		vtx.r = color[3] * 0.0039215689f;
		vtx.g = color[2] * 0.0039215689f;
		vtx.b = color[1] * 0.0039215689f;
		vtx.a = color[0] * 0.0039215689f;

		if (useTex) {
			const u32 st = texbase[i];
			s16 s = (s16)_SHIFTR(st, 16, 16);
			s16 t = (s16)_SHIFTR(st, 0, 16);
			if (persp) {
				vtx.s = _FIXED2FLOAT(s, 5);
				vtx.t = _FIXED2FLOAT(t, 5);
			} else {
				vtx.s = _FIXED2FLOAT(s, 4);
				vtx.t = _FIXED2FLOAT(t, 4);
			}
		}
	}

	const u32 vert1[3] = { v1, v2, v3 };
	bool triAdded = F5INDI_AddVertices(vert1, drawer);
	if (bTri2) {
		const u32 vert2[3] = { v1, v3, v4 };
		triAdded |= F5INDI_AddVertices(vert2, drawer);
	}

	if (triAdded)
		F5INDI_DoSubDList();

	RSP.nextCmd = _SHIFTR(params[8], 24, 8);
	if (RSP.nextCmd != G_TRI1 && RSP.nextCmd != G_TRI2) {
		const u32 geometryMode = gSP.geometryMode;
		if (useTex) {
			if ((gSP.geometryMode & G_CULL_BOTH) == G_CULL_BOTH)
				gSP.geometryMode &= ~(G_CULL_FRONT);
		} else {
			// culling not used for polygons without textures.
			gSP.geometryMode &= ~(G_CULL_BOTH);
		}
		drawer.drawDMATriangles(drawer.getDMAVerticesCount());
		gSP.geometryMode = geometryMode;
	}

	if (useTex)
		RSP.PC[RSP.PCi] += 16;

	RSP.PC[RSP.PCi] += 8;
}

void F5INDI_GenVertices(u32 _w0, u32 _w1)
{
	f32 combined[4][4];
	memcpy(combined, gSP.matrix.combined, sizeof(combined));
	memcpy(gSP.matrix.combined, getIndiData().mtx_vtx_gen, sizeof(gSP.matrix.combined));

	const SWVertex * vertex = CAST_DMEM(const SWVertex*, 0x170);
	bool verticesToProcess[32];

	u32 A = (_w0 & 0x0000FFFF) | (_w1 & 0xFFFF0000);
	u32 B = 1;
	u32 count = 0;

	while (A != 0) {
		u32 C = A & B;
		verticesToProcess[count++] = C != 0;
		if (C != 0) {
			A ^= C;
		}
		B <<= 1;
	}

	gSPSWVertex(vertex, count, verticesToProcess);

	memcpy(gSP.matrix.combined, combined, sizeof(gSP.matrix.combined));
}

void F5INDI_GenParticlesVertices()
{
	static const u32 dpc_clock0 = static_cast<u32>(time(NULL));
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);
	*CAST_DMEM(u64*, 0xC10) = *CAST_RDRAM(const u64*, _SHIFTR(params[3], 0, 24));
	const u32 L = *CAST_DMEM(const u32*, 0xC10);
	if (L == 0)
		return;
	u32 U = L;
	memcpy(DMEM + 0x170, RDRAM + _SHIFTR(params[2], 0, 24), 256);
	const u32 corrector = _SHIFTR(params[0], 0, 16);
	const u32 M = _SHIFTR(params[5], 0, 16);
	u32 vtxAddr = 0x170;
	u32 lightAddr = 0xB00;
	u32 factorAddr = 0x380;
	u32 colorAddr = 0x480;
	u32 count = 0;
	u32 Q = 0;
	while (U != 0) {
		SWVertex * vertex = CAST_DMEM(SWVertex*, vtxAddr);
		u16* light = CAST_DMEM(u16*, lightAddr);
		u16 F = (((light[0 ^ 1] << 12) + light[1 ^ 1] * corrector) << 4) >> 16;
		bool endCycle = false;
		if ((M & 0x2000) == 0) {
			// Step 2
			s16 F1;
			do {
				F = (((light[0 ^ 1] << 12) + light[1 ^ 1] * corrector) << 4) >> 16;
				F1 = F + 0xF000;
				if (F1 < 0) {
					light[0 ^ 1] = F;
					if ((M & 0x40) != 0)
						vertex->flag = (((F >> 4)&0xFC) << 8) | (vertex->flag & 0xFF);
					if ((M & 0x20) != 0)
						vertex->flag = ((F >> 4) & 0xFC) | (vertex->flag & 0xFF00);
				} else {
					light[0 ^ 1] = 0U;
					if ((M & 0x4000) != 0) {
						//const u32 dpc_clock = *REG.DPC_CLOCK;
						const u32 dpc_clock = static_cast<u32>(time(NULL)) - dpc_clock0;
						const u32* V = CAST_DMEM(const u32*, 0xC18);
						vertex->x = (dpc_clock        & _SHIFTR(V[0], 16, 16)) + _SHIFTR(V[2], 16, 16);
						vertex->y = ((dpc_clock >> 3) & _SHIFTR(V[0],  0, 16)) + _SHIFTR(V[2],  0, 16);
						vertex->z = ((dpc_clock >> 6) & _SHIFTR(V[1], 16, 16)) + _SHIFTR(V[3], 16, 16);
						vertex->flag &= _SHIFTR(V[1], 0, 16);
					} else {
						Q |= 1 << count;
						endCycle = true;
						break;
					}
				}
			} while (F1 >= 0);
		}
		if (!endCycle) {
			// Step 3
			u32 X = (u32)_SHIFTL(vertex->x, 12, 16) + (u32)(static_cast<s16>(_SHIFTR(params[4], 16, 16)) * corrector);
			u32 Y = (u32)_SHIFTL(vertex->y, 12, 16) + (u32)(static_cast<s16>(_SHIFTR(params[4], 0, 16)) * corrector);
			u32 Z = (u32)_SHIFTL(vertex->z, 12, 16) + (u32)(static_cast<s16>(_SHIFTR(params[5], 16, 16)) * corrector);
			if ((M & 0x0380) != 0) {
				u32 offset = factorAddr - 0x380;
				if ((M & 0x0200) == 0) {
					if ((M & 0x080) != 0) {
						offset = _SHIFTR(F, 4, 8) & 0xF8;
					} else {
						const u32 p = *CAST_DMEM(const u32*, lightAddr + 4);
						offset = _SHIFTR(p, 24, 8) << 3;
					}
				}
				const u32* factor = CAST_DMEM(const u32*, 0x380 + offset);
				X += static_cast<s16>(_SHIFTR(factor[0], 16, 16)) * corrector;
				Y += static_cast<s16>(_SHIFTR(factor[0], 0, 16)) * corrector;
				Z += static_cast<s16>(_SHIFTR(factor[1], 16, 16)) * corrector;
			}
			// Step 4
			if ((M & 0x1C00) != 0) {
				u32 offset = colorAddr - 0x480;
				if ((M & 0x1000) == 0) {
					if ((M & 0x0400) != 0) {
						offset = _SHIFTR(F, 4, 8) & 0xF8;
					} else {
						const u32 p = *CAST_DMEM(const u32*, lightAddr + 4);
						offset = _SHIFTR(p, 16, 8) << 3;
					}
				}
				const u32* factor = CAST_DMEM(const u32*, 0x480 + offset);
				X += static_cast<s16>(_SHIFTR(factor[0], 16, 16)) * corrector;
				Y += static_cast<s16>(_SHIFTR(factor[0], 0, 16)) * corrector;
				Z += static_cast<s16>(_SHIFTR(factor[1], 16, 16)) * corrector;
			}
			// Step 5
			X = (X << 4) >> 16;
			Y = (Y << 4) >> 16;
			Z = (Z << 4) >> 16;
			vertex->x = X;
			vertex->y = Y;
			vertex->z = Z;
			if ((M & 0x0008) != 0) {
				const u32* V = CAST_DMEM(const u32*, 0xC00);
				if (vertex->x < static_cast<s16>(_SHIFTR(V[0], 16, 16)))
					vertex->x += static_cast<s16>(_SHIFTR(V[2], 16, 16));
				if (vertex->x > static_cast<s16>(_SHIFTR(V[0], 16, 16)) + static_cast<s16>(_SHIFTR(V[2], 16, 16)))
					vertex->x -= static_cast<s16>(_SHIFTR(V[2], 16, 16));

				if (vertex->y < static_cast<s16>(_SHIFTR(V[0], 0, 16)))
					vertex->y += static_cast<s16>(_SHIFTR(V[2], 0, 16));
				if (vertex->y > static_cast<s16>(_SHIFTR(V[0], 0, 16)) + static_cast<s16>(_SHIFTR(V[2], 0, 16)))
					vertex->y -= static_cast<s16>(_SHIFTR(V[2], 0, 16));

				if (vertex->z < static_cast<s16>(_SHIFTR(V[1], 16, 16)))
					vertex->z += static_cast<s16>(_SHIFTR(V[3], 16, 16));
				if (vertex->z > static_cast<s16>(_SHIFTR(V[1], 16, 16)) + static_cast<s16>(_SHIFTR(V[3], 16, 16)))
					vertex->z -= static_cast<s16>(_SHIFTR(V[3], 16, 16));
			}
		}
		vtxAddr += 8;
		lightAddr += 8;
		factorAddr += 8;
		colorAddr += 8;
		U >>= 1;
		count++;
	}

	memcpy(RDRAM + _SHIFTR(params[2], 0, 24), DMEM + 0x170, 256);

	if ((M & 0x04) == 0) {
		*CAST_RDRAM(u32*, _SHIFTR(params[3], 0, 24)) = L & (~Q);
		memcpy(RDRAM + _SHIFTR(params[1], 8, 24), DMEM + 0xB00, count * 8);
	}
}

static
u32 F5INDI_TexrectGenVertexMask(u32 _mask, u32 _limAddr, u32 _vtxAddr)
{
	const u32* V = CAST_DMEM(const u32*, _limAddr);
	const s16 XL = _SHIFTR(*V, 16, 16);
	const s16 YL = _SHIFTR(*V, 0, 16);
	++V;
	const s16 ZL = _SHIFTR(*V, 16, 16);
	++V;
	const s16 XR = _SHIFTR(*V, 16, 16);
	const s16 YR = _SHIFTR(*V, 0, 16);
	++V;
	const s16 ZR = _SHIFTR(*V, 16, 16);

	u32 S = 0xFFFFFFFE;
	const SWVertex * vertex = CAST_RDRAM(const SWVertex*, _vtxAddr);
	for (u32 i = 0; i < 0x20; ++i) {
		if (vertex[i].x > XL && vertex[i].x < XR &&
				vertex[i].y > YL && vertex[i].y < YR &&
				vertex[i].z > ZL && vertex[i].z < ZR) {
			_mask &= S;
		}
		S = (S << 1) | 1;
	}
	return _mask;
}

#ifdef F5INDI_PARTICLE_OPT
static
void F5INDI_AddParticle(f32 _ulx, f32 _uly, f32 _lrx, f32 _lry, s16 _s0, s16 _t0, f32 _dsdx, f32 _dtdy)
{
	const f32 Z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : 0.0f;
	const f32 W = 1.0f;

	const f32 offsetX = (_lrx - _ulx) * _dsdx;
	const f32 offsetY = (_lry - _uly) * _dtdy;
	const f32 uls = _FIXED2FLOAT(_s0, 5);
	const f32 lrs = uls + offsetX;
	const f32 ult = _FIXED2FLOAT(_t0, 5);
	const f32 lrt = ult + offsetY;

	GraphicsDrawer & drawer = dwnd().getDrawer();
	auto setupVertex = [&](f32 _x, f32 _y, f32 _s, f32 _t)
	{
		SPVertex & vtx = drawer.getCurrentDMAVertex();
		vtx.x = _x;
		vtx.y = _y;
		vtx.z = Z;
		vtx.w = W;
		vtx.s = _s;
		vtx.t = _t;
		vtx.r = gDP.primColor.r;
		vtx.g = gDP.primColor.g;
		vtx.b = gDP.primColor.b;
		vtx.a = gDP.primColor.a;
	};

	setupVertex(_ulx, _uly, uls, ult);
	setupVertex(_lrx, _uly, lrs, ult);
	setupVertex(_ulx, _lry, uls, lrt);
	setupVertex(_lrx, _uly, lrs, ult);
	setupVertex(_ulx, _lry, uls, lrt);
	setupVertex(_lrx, _lry, lrs, lrt);
}

static
void F5INDI_DrawParticle()
{
	const u32* pNextCmd = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi] + 40);
	if (_SHIFTR(pNextCmd[0], 24, 8) != F5INDI_GEOMETRY_GEN ||
		_SHIFTR(pNextCmd[1], 0, 8) != 0x24)	{
		// Replace combiner to use vertex color instead of PRIMITIVE
		const gDPCombine curCombine = gDP.combine;
		if (gDP.combine.mRGB0 == G_CCMUX_PRIMITIVE)
			gDP.combine.mRGB0 = G_CCMUX_SHADE;
		if (gDP.combine.mA0 == G_ACMUX_PRIMITIVE)
			gDP.combine.mA0 = G_ACMUX_SHADE;
		if (gDP.combine.mRGB1 == G_CCMUX_PRIMITIVE)
			gDP.combine.mRGB1 = G_CCMUX_SHADE;
		if (gDP.combine.mA1 == G_ACMUX_PRIMITIVE)
			gDP.combine.mA1 = G_ACMUX_SHADE;
		const u32 othermodeL = gDP.otherMode.l;
		gDP.otherMode.depthSource = G_ZS_PIXEL;
		// Replace blending mode
		gDP.otherMode.l = 0x00550000 | (gDP.otherMode.l & 0xFFFF);
		const u32 geometryMode = gSP.geometryMode;
		gSP.geometryMode |= G_ZBUFFER;
		gSP.geometryMode &= ~G_FOG;
		CombinerInfo::get().setCombine(gDP.combine.mux);
		const u32 enableLegacyBlending = config.generalEmulation.enableLegacyBlending;
		config.generalEmulation.enableLegacyBlending = 1;
		gDP.changed |= CHANGED_COMBINE | CHANGED_RENDERMODE;
		GraphicsDrawer & drawer = dwnd().getDrawer();
		drawer.drawScreenSpaceTriangle(drawer.getDMAVerticesCount(), graphics::drawmode::TRIANGLES);
		gDP.combine = curCombine;
		gDP.otherMode.l = othermodeL;
		gSP.geometryMode = geometryMode;
		config.generalEmulation.enableLegacyBlending = enableLegacyBlending;
		gDP.changed |= CHANGED_COMBINE | CHANGED_RENDERMODE;
	}
}
#endif //F5INDI_PARTICLE_OPT

static
void F5INDI_TexrectGen()
{
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);
	GraphicsDrawer & drawer = dwnd().getDrawer();
//	const u32 perspNorm = *CAST_DMEM(const u32*, 0x14C);
	const u32 vp = *CAST_DMEM(const u32*, 0x130);
	const u32 vpx = _SHIFTR(vp, 17, 15);
	const u32 vpy = _SHIFTR(vp,  1, 15);
	const u32 maxX = (_SHIFTR(params[0],  0, 16) * vpx) >> 16;
	const u32 maxY = (_SHIFTR(params[1], 16, 16) * vpy) >> 16;
	const u64 MX = (params[4] & 0xFFFF0000) | _SHIFTR(params[5], 16, 16);
	const u64 xScale = MX * _SHIFTR(params[7], 16, 16) * 1 * vpx;
	const u64 MY = (_SHIFTL(params[4], 16, 16)) | _SHIFTR(params[5], 0, 16);
	const u64 yScale = MY * _SHIFTR(params[7], 0, 16) * vpy;
	const u32 mp = *CAST_DMEM(const u32*, 0x5C8);
	const u64 Q = (params[6] & 0xFFFF0000) | _SHIFTR(mp, 16, 16);
	const u64 R = (_SHIFTL(params[6], 16, 16)) | _SHIFTR(mp, 0, 16);
	const u32 colorScale = params[3];

	s32 count = _SHIFTR(params[0], 16, 8);
	u32 vtxAddr = _SHIFTR(params[2], 0, 24);
	for (; count > 0; --count) {
		const SWVertex * vertex = CAST_RDRAM(const SWVertex*, vtxAddr);
		gSPSWVertex(vertex, 0x20, nullptr);
		u32 K = params[8];
		u32 B = params[9] & 0xFF;
		u32 limAddr = 0xC28;
		while (B != 0) {
			K = F5INDI_TexrectGenVertexMask(K, limAddr, vtxAddr);
			B--;
			limAddr += 0x10;
		}
		for (u32 i = 0; i < 0x20; ++i) {
			const u32 D = K & 1;
			K >>= 1;
			if (D == 0)
				continue;

			const SPVertex & v = drawer.getVertex(i);
			if (v.clip != 0)
				continue;
			const f32 screenX = v.x / v.w * gSP.viewport.vscale[0] + gSP.viewport.vtrans[0];
			const f32 screenY = -v.y / v.w * gSP.viewport.vscale[1] + gSP.viewport.vtrans[1];
			const u32 w_i = std::max(1U, u32(v.w));
			const u32 inv_w = 0xFFFFFFFF / w_i;

			const u32 val = *CAST_DMEM(const u32*, 0x480 + _SHIFTR(vertex[i].flag, 8, 8));
			const u32 A = _SHIFTR(val, 16, 16);
			const u32 C = _SHIFTR(val, 0, 16);

			u64 offset_x_i = (xScale * inv_w) >> 32;
			offset_x_i = (offset_x_i * A) >> 32;
			if (offset_x_i > maxX)
				offset_x_i = maxX;
			if (offset_x_i < 4)
				offset_x_i = 4;
			const f32 offset_x_f = _FIXED2FLOAT(static_cast<u32>(offset_x_i), 2);
			const f32 ulx = screenX - offset_x_f;
			s32 G = screenX - offset_x_f > 0.0f ? 0 : static_cast<s32>(screenX - offset_x_f);
			const f32 lrx = std::max(0.0f, screenX + offset_x_f);
			if (lrx - ulx <= 0.0f)
				continue;

			u64 offset_y_i = (yScale * inv_w) >> 32;
			offset_y_i = (offset_y_i * C) >> 32;
			if (offset_y_i > maxY)
				offset_y_i = maxY;
			if (offset_y_i < 4)
				offset_y_i = 4;
			const f32 offset_y_f = _FIXED2FLOAT(static_cast<u32>(offset_y_i), 2);
			const f32 uly = screenY - offset_y_f;
			s32 H = screenY - offset_y_f > 0.0f ? 0 : static_cast<s32>(screenY - offset_y_f);
			const f32 lry = std::max(0.0f, screenY + offset_y_f);
			if (lry - uly <= 0.0f)
				continue;

			const u64 Q1 = Q * 0x40 / offset_x_i;
			const u16 dsdx_i = static_cast<u16>(Q1 >> 16);
			const u64 R1 = R * 0x40 / offset_y_i;
			const u16 dtdy_i = static_cast<u16>(R1 >> 16);

			const u64 U = std::min(Q1 * 0x40U, static_cast<u64>(0x7FFFFFFFU));
			const u16 U1 = static_cast<u16>(((0-U) * G) >> 16);
			const s16 S = (U1 - 2) * 8;

			const u64 V = std::min(R1 * 0x40U, static_cast<u64>(0x7FFFFFFFU));
			const u16 V1 = static_cast<u16>(((0-V) * H) >> 16);
			const s16 T = (V1 - 2) * 8;

			const f32 dsdx = _FIXED2FLOAT((s16)dsdx_i, 10);
			const f32 dtdy = _FIXED2FLOAT((s16)dtdy_i, 10);

			gDP.primDepth.z = v.z / v.w;
			gDP.primDepth.deltaZ = 0.0f;
			DebugMsg(DEBUG_NORMAL, "SetPrimDepth( %f, %f );\n", gDP.primDepth.z, gDP.primDepth.deltaZ);

			const u32 primColor = *CAST_DMEM(const u32*, 0x380 + _SHIFTR(vertex[i].flag, 0, 8));
			gDP.primColor.r = _FIXED2FLOATCOLOR(((_SHIFTR(primColor, 24, 8) * _SHIFTR(colorScale, 24, 8)) >> 8), 8);
			gDP.primColor.g = _FIXED2FLOATCOLOR(((_SHIFTR(primColor, 16, 8) * _SHIFTR(colorScale, 16, 8)) >> 8), 8);
			gDP.primColor.b = _FIXED2FLOATCOLOR(((_SHIFTR(primColor,  8, 8) * _SHIFTR(colorScale,  8, 8)) >> 8), 8);
			gDP.primColor.a = _FIXED2FLOATCOLOR(((_SHIFTR(primColor,  0, 8) * _SHIFTR(colorScale,  0, 8)) >> 8), 8);
			DebugMsg(DEBUG_NORMAL, "SetPrimColor( %f, %f, %f, %f )\n",
			         gDP.primColor.r, gDP.primColor.g, gDP.primColor.b, gDP.primColor.a);

#ifdef F5INDI_PARTICLE_OPT
			F5INDI_AddParticle(ulx, uly, lrx, lry, S, T, dsdx, dtdy);
#else
			gDPTextureRectangle(ulx, uly, lrx, lry, 0, S, T, dsdx, dtdy, false);
#endif
		}
		vtxAddr += 0x100;
	}

#ifdef F5INDI_PARTICLE_OPT
	F5INDI_DrawParticle();
#endif
}

static
void F5Naboo_TexrectGen()
{
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);

	const u32 vtxIdx = ((params[0] >> 5) & 0x07F8) / 40;
	const SPVertex & v = dwnd().getDrawer().getVertex(vtxIdx);
	if (v.clip != 0)
		return;

	const f32 screenX = v.x / v.w * gSP.viewport.vscale[0] + gSP.viewport.vtrans[0];
	const f32 screenY = -v.y / v.w * gSP.viewport.vscale[1] + gSP.viewport.vtrans[1];

	const bool flip = (params[0] & 1) != 0;

	const u32 w_i = std::max(1U, u32(v.w));
	const u32 viewport = *CAST_DMEM(const u32*, 0x130);
	const u32 viewportX = _SHIFTR(viewport, 17, 15);
	const u32 viewportY = _SHIFTR(viewport, 1, 15);

	const u32 perspMatrixX = (params[5] & 0xFFFF0000) | _SHIFTR(params[6], 16, 16);
	const u32 perspMatrixY = _SHIFTL(params[5], 16, 16) | _SHIFTR(params[6], 0, 16);
	u64 param3X = _SHIFTR(params[3], 16, 16);
	u64 param3Y = _SHIFTR(params[3], 0, 16);
	if (flip)
		std::swap(param3X, param3Y);

	u32 offset_x_i = static_cast<u32>(((param3X * viewportX * perspMatrixX) / w_i) >> 16);
	u32 offset_y_i = static_cast<u32>(((param3Y * viewportY * perspMatrixY) / w_i) >> 16);
	const f32 offset_x_f = _FIXED2FLOAT(offset_x_i, 2);
	const f32 offset_y_f = _FIXED2FLOAT(offset_y_i, 2);

	const f32 ulx = screenX - offset_x_f;
	const f32 lrx = screenX + offset_x_f;
	if (lrx - ulx <= 0.0f)
		return;
	const f32 uly = screenY - offset_y_f;
	const f32 lry = screenY + offset_y_f;
	if (lry - uly <= 0.0f)
		return;

	u32 param4X = params[4] & 0xFFFF0000;
	u32 param4Y = _SHIFTL(params[4], 16, 16);
	float intpart;
	const f32 frac_x_f = fabs(modff(gSP.matrix.combined[0][0], &intpart));
	const u32 combMatrixFracX = u32(frac_x_f*65536.0f);
	const f32 frac_y_f = fabs(modff(gSP.matrix.combined[0][1], &intpart));
	const u32 combMatrixFracY = u32(frac_y_f*65536.0f);
	param4X |= combMatrixFracX;
	param4Y |= combMatrixFracY;

	if (flip)
		std::swap(offset_x_i, offset_y_i);

	u16 dsdx_i = (u16)((param4X / offset_x_i) >> 10);
	u16 dtdy_i = (u16)((param4Y / offset_y_i) >> 10);
	u16 E = 0, F = 0;

	if ((params[0] & 2) != 0) {
		dsdx_i = -dsdx_i;
		E = _SHIFTR(params[4], 16, 16);;
	}

	if ((params[0] & 4) != 0) {
		dtdy_i = -dtdy_i;
		F = _SHIFTR(params[4], 0, 16);;
	}

	const f32 dsdx = _FIXED2FLOAT((s16)dsdx_i, 10);
	const f32 dtdy = _FIXED2FLOAT((s16)dtdy_i, 10);

	if (flip)
		std::swap(dsdx_i, dtdy_i);

	u16 S, T;

	if (ulx > 0) {
		S = E + 0xFFF0;
	} else {
		const int ulx_i = int(ulx * 4.0f);
		S = ((0 - (dsdx_i << 6) * ulx_i) << 3) + E + 0xFFF0;
	}

	if (uly > 0) {
		T = F + 0xFFF0;
	} else {
		const int uly_i = int(uly * 4.0f);
		T = ((0 - (dtdy_i << 6) * uly_i) << 3) + F + 0xFFF0;
	}

	F5INDI_DoSubDList();

	gDP.primDepth.z = v.z / v.w;
	gDP.primDepth.deltaZ = 0.0f;

	const u32 primColor = params[7];
	gDP.primColor.r = _FIXED2FLOATCOLOR(_SHIFTR(primColor, 24, 8), 8);
	gDP.primColor.g = _FIXED2FLOATCOLOR(_SHIFTR(primColor, 16, 8), 8);
	gDP.primColor.b = _FIXED2FLOATCOLOR(_SHIFTR(primColor,  8, 8), 8);
	gDP.primColor.a = _FIXED2FLOATCOLOR(_SHIFTR(primColor,  0, 8), 8);
	DebugMsg(DEBUG_NORMAL, "SetPrimColor( %f, %f, %f, %f )\n",
	         gDP.primColor.r, gDP.primColor.g, gDP.primColor.b, gDP.primColor.a);

	if ((gSP.geometryMode & G_FOG) != 0) {
		const u32 fogColor = (params[7] & 0xFFFFFF00) | u32(v.a*255.0f);
		gDPSetFogColor(_SHIFTR(fogColor, 24, 8),	// r
		                _SHIFTR(fogColor, 16, 8),	// g
		                _SHIFTR(fogColor, 8, 8),	// b
		                _SHIFTR(fogColor, 0, 8));	// a
	}

	gDPTextureRectangle(ulx, uly, lrx, lry, gSP.texture.tile, (s16)S, (s16)T, dsdx, dtdy, flip);
}

static
void F5Naboo_CopyDataFF()
{
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);
	*CAST_DMEM(u32*, 0x100) = 0;
	u32* data = CAST_DMEM(u32*, 0xDB8);
	data[0] = _SHIFTR(data[0], 0, 16);
	data[1] = _SHIFTL(params[0], 16, 16) | _SHIFTR(data[1], 0, 16);
	u32 V = _SHIFTR(params[0], 16, 8);
	data[2] = _SHIFTL(V, 24, 8) | 0x00FFFF;
	data[3] = V * 2;
	data[4] = _SHIFTL(V, 24, 8);
	V = _SHIFTR(params[1], 24, 8);
	data[5] = V;
	//data[6]
	data[7] = (data[7] & 0xFFFF0000) | V * 2;
	//data[8]
	//data[9]
	V = _SHIFTR(params[2], 16, 16);
	data[10] = (data[10] & 0xFFFF0000) | V;
	//data[11]
	data[12] = (data[12] & 0xFFFF0000) | V;
	//data[13]
	V = _SHIFTR(params[2], 0, 16);
	data[14] = (data[14] & 0xFFFF0000) | V;
	//data[15]
	data[16] = (data[16] & 0xFFFF0000) | V;
	//data[17]
	V = _SHIFTR(params[3], 16, 16);
	data[18] = (data[18] & 0xFFFF0000) | V;
	//data[19]
	data[20] = (data[20] & 0xFFFF0000) | V;
	//data[21]
	V = _SHIFTR(params[3], 0, 16);
	data[22] = (data[22] & 0xFFFF0000) | V;
	//data[23]
	data[24] = (data[24] & 0xFFFF0000) | V;
	//data[25]
	//data[26]
	V = _SHIFTR(params[1], 8, 16);
	data[27] = (data[27] & 0xFFFF0000) | V;
	//data[28]
	data[29] = (data[29] & 0xFFFF0000) | V;
}

static
void F5Naboo_CopyData00()
{
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);

	// Step 1
	*CAST_DMEM(u32*, 0x0F8) = params[3];
	u32 V = _SHIFTR(params[0], 16, 8);
	*CAST_DMEM(u32*, 0x0FC) = (V << 24) | _SHIFTL(params[10], 16, 8);

	// Step 2
	u32* data = CAST_DMEM(u32*, 0xDD0);
	data[0] = (params[2] & 0xFFFF0000) | _SHIFTR(params[14], 16, 16);
	data[1] = _SHIFTL(params[2], 16, 16) | _SHIFTR(data[1], 0, 16);
	data[2] = (params[2] & 0xFFFF0000) | _SHIFTR(params[14], 0, 16);
	data[3] = _SHIFTL(params[2], 16, 16) | 0x0100;
	V = (params[4] & 0xFFFF0000);
	data[4] = V | _SHIFTR(data[4], 0, 16);
	//data[5]
	data[6] = V | _SHIFTR(data[6], 0, 16);
	//data[7]
	V = _SHIFTL(params[4], 16, 16);
	data[8] = V | _SHIFTR(data[8], 0, 16);
	//data[9]
	data[10] = V | _SHIFTR(data[10], 0, 16);
	//data[11]
	V = (params[5] & 0xFFFF0000);
	data[12] = V | _SHIFTR(data[12], 0, 16);
	//data[13]
	data[14] = V | _SHIFTR(data[14], 0, 16);
	//data[15]
	V = _SHIFTL(params[5], 16, 16);
	data[16] = V | _SHIFTR(data[16], 0, 16);
	//data[17]
	data[18] = V | _SHIFTR(data[18], 0, 16);

	// Step 3
	V = (params[6] & 0xFFFF0000) | _SHIFTR(params[8], 16, 16);
	data[5] = V;
	data[7] = V;
	V = _SHIFTL(params[6], 16, 16) | _SHIFTR(params[8], 0, 16);
	data[9] = V;
	data[11] = V;
	V = (params[7] & 0xFFFF0000) | _SHIFTR(params[9], 16, 16);
	data[13] = V;
	data[15] = V;
	V = _SHIFTL(params[7], 16, 16) | _SHIFTR(params[9], 0, 16);
	data[17] = V;
	data[19] = V;

	// Step 4
	V = _SHIFTL(params[0], 16, 16) | _SHIFTR(params[13], 16, 16);
	data[20] = V;
	data[21] = (params[15] & 0xFFFF0000) | _SHIFTR(data[21], 0, 16);
	data[22] = _SHIFTR(params[11], 0, 8);
	if (data[22] > 127)
		data[22] |= 0xFF00;
	V = (_SHIFTR(params[0], 0, 16) + 0x00FF) & 0xFF00;
	data[22] |= V << 16;
	data[23] = _SHIFTL(params[15], 16, 16) | _SHIFTR(data[23], 0, 16);
	data[24] = 0x7FFF7FFF;
	data[25] = params[12];
	data[26] = 0x7FFF7FFF;
	data[27] = params[12];
	data[28] = params[10];
	data[29] = params[10];
	data[30] = params[11];
	data[31] = params[11];

	// Step 5
	memcpy(DMEM + 0xC68, RDRAM + _SHIFTR(params[1], 8, 24), 0xF0);

	// Step 6
	*(DMEM + (0x37E ^ 3)) = 0xFF;

	const u32 data_D58[] = {
		0x06000628
		,0x06500678
		,0x06A006C8
		,0x06F00718
		,0x07400768
		,0x079007B8
		,0x07E00808
		,0x08300858
		,0x088008A8
		,0x08D008F8
		,0x09200948
		,0x09700998
		,0x09C009E8
		,0x0A100A38
	};

	memcpy(DMEM + 0xD58, data_D58, sizeof(data_D58));
	u32* _D90 = CAST_DMEM(u32*, 0xD90);
	_D90[0] = 0x0A600000 | _SHIFTR(_D90[0], 0, 16);
}

static
void F5Naboo_PrepareAndDrawTriangle(const u32 _vert[3], GraphicsDrawer & _drawer)
{
	if (!F5INDI_AddVertices(_vert, _drawer))
		return;

	const u16 A = _SHIFTR(*CAST_DMEM(const u32*, 0x100), 8, 16);
	const u8 B = *(DMEM + (0x103 ^ 3));
	const u32 C = A | B;
	CAST_DMEM(u16*, 0x100)[0^1] = C;

	auto doCommands = [](u32 addr)
	{
		const u32 * commands = CAST_DMEM(const u32*, addr);
		u32 w0 = commands[0];
		u32 w1 = commands[1];
		u32 cmd = _SHIFTR(w0, 24, 8);
		GBI.cmd[cmd](w0, w1);
		w0 = commands[2];
		w1 = commands[3];
		cmd = _SHIFTR(w0, 24, 8);
		GBI.cmd[cmd](w0, w1);
	};

	const u32 dlistAddr = _SHIFTR(*CAST_DMEM(const u32*, 0x58C), 0, 24);
	if (dlistAddr == 0) {
		if ((C << 8) != B)
			doCommands(0xE50 + B);
		_drawer.drawDMATriangles(_drawer.getDMAVerticesCount());
		return;
	}

	F5INDI_DoSubDList();

	gDPInfo::OtherMode curOtherMode;
	curOtherMode._u64 = gDP.otherMode._u64;
	curOtherMode.h = 0xEF000000 | (curOtherMode.h & 0x00FFFFFF);
	u32 * pOtherMode = CAST_DMEM(u32*, 0xE50);
	pOtherMode[0] = curOtherMode.h;
	pOtherMode[1] = curOtherMode.l;
	const u32 E = curOtherMode.h & 0xFFCFFFFF;

	*CAST_DMEM(u32*, 0xE70) = E;
	const u32 F = E | 0x00100000;
	*CAST_DMEM(u32*, 0xE60) = F;
	const u8 G = *(DMEM + (0x101 ^ 3));
	if (G != 0) {
		doCommands(0xE50 + G);
	}
	_drawer.drawDMATriangles(_drawer.getDMAVerticesCount());
}

static
void F5Naboo_DrawPolygons()
{
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);
	NabooData & data = getNabooData();
	GraphicsDrawer & drawer = dwnd().getDrawer();
	const u32 cmd = _SHIFTR(params[0], 24, 8);
	u32 step = 5;

	if (cmd == 0xBE) {
		// Step 1
		data.HH = _SHIFTR(params[0], 0, 16);

		// Step 2
		u32 GG = data.EE - data.DD;
		const u16* idx16 = CAST_DMEM(const u16*, GG);
		const u32 Idx1 = (idx16[0x09 ^ 1] + data.CC) >> 1;
		const u32 Idx2 = (idx16[0x0A ^ 1] + data.CC) >> 1;
		const u32 Idx3 = (idx16[0x0B ^ 1] + data.CC) >> 1;
		const u32 Idx4 = (idx16[0x0E ^ 1] + data.CC) >> 1;

		idx16 = CAST_DMEM(const u16*, 0xD58);
		const u32 VtxAddr1 = idx16[Idx1 ^ 1];
		const u32 VtxAddr2 = idx16[Idx2 ^ 1];
		const u32 VtxAddr3 = idx16[Idx3 ^ 1];
		const u32 VtxAddr4 = idx16[Idx4 ^ 1];

		const u32 v1 = (VtxAddr1 - 0x600) / 40;
		const u32 v2 = (VtxAddr2 - 0x600) / 40;
		const u32 v3 = (VtxAddr3 - 0x600) / 40;
		const u32 v4 = (VtxAddr4 - 0x600) / 40;

		SPVertex & vtx1 = drawer.getVertex(v1);
		vtx1.s = 0.0f;
		vtx1.t = _FIXED2FLOAT((s16)_SHIFTR(params[1], 0, 16), 5);
		SPVertex & vtx2 = drawer.getVertex(v2);
		vtx2.s = _FIXED2FLOAT((s16)_SHIFTR(params[1], 16, 16), 5);
		vtx2.t = 0.0f;
		SPVertex & vtx3 = drawer.getVertex(v3);
		vtx3.s = 0.0f;
		vtx3.t = 0.0f;
		SPVertex & vtx4 = drawer.getVertex(v4);
		vtx4.s = vtx2.s;
		vtx4.t = vtx1.t;

		step = 3;
	}

	auto Step3 = [&](u32 GG) {
		const u16* idx16 = CAST_DMEM(const u16*, GG);
		const u32 Idx1 = idx16[0x09 ^ 1] + data.CC;
		const u32 Idx2 = idx16[0x0A ^ 1] + data.CC;
		const u32 Idx3 = idx16[0x0B ^ 1] + data.CC;
		const u32 idxs[3] = { Idx1, Idx2, Idx3 };
		idx16 = CAST_DMEM(const u16*, 0xD58);
		u32 vtxIdx[3];
		u32 alphaSum = 0;
		for (u32 i = 0; i < 3; ++i)
		{
			const u32 vtxAddr = idx16[(idxs[i]/2) ^ 1];
			vtxIdx[i] = (vtxAddr - 0x600) / 40;
			SPVertex & vtx = drawer.getVertex(vtxIdx[i]);
			u8* color = DMEM + 0x0B78 + idxs[i] * 2 + (data.HH & 0xFFF);
			vtx.r = _FIXED2FLOATCOLOR(color[0 ^ 3], 8);
			vtx.g = _FIXED2FLOATCOLOR(color[1 ^ 3], 8);
			vtx.b = _FIXED2FLOATCOLOR(color[2 ^ 3], 8);
			vtx.a = _FIXED2FLOATCOLOR(color[3 ^ 3], 8);
			alphaSum += color[3 ^ 3];
		}
		if (data.HH == 0) {
			*CAST_DMEM(u32*, 0x100) = 0;
			F5Naboo_PrepareAndDrawTriangle(vtxIdx, drawer);
		} else {
			if (alphaSum == 0) {
				*(DMEM + (0x103 ^ 3)) = 0x00;
				F5Naboo_PrepareAndDrawTriangle(vtxIdx, drawer);
			} else {
				if (data.HH > 0) {
					*(DMEM + (0x103 ^ 3)) = 0x10;
					F5Naboo_PrepareAndDrawTriangle(vtxIdx, drawer);
				} else {
					if (alphaSum != 0x02FD) { // 0xFF * 3
						*(DMEM + (0x103 ^ 3)) = 0x00;
						F5Naboo_PrepareAndDrawTriangle(vtxIdx, drawer);
					} else {
						u32 alphaSum2 = 0;
						u8 alphas[3];
						for (u32 i = 0; i < 3; ++i) {
							u32 offset = 0xB00 + idxs[i] * 2 + (data.HH & 0xFFF);
							u8* color = DMEM + offset;
							alphas[i] = color[3 ^ 3];
							alphaSum2 += alphas[i];
						}
						if (alphaSum2 == 0) {
							SPVertex & vtx = drawer.getVertex(vtxIdx[0]);
							vtx.a = _FIXED2FLOATCOLOR(alphas[0], 8);
							*(DMEM + (0x103 ^ 3)) = 0x20;
							F5Naboo_PrepareAndDrawTriangle(vtxIdx, drawer);
						} else {
							*(DMEM + (0x103 ^ 3)) = 0x10;
							for (u32 i = 0; i < 3; ++i) {
								SPVertex & vtx = drawer.getVertex(vtxIdx[i]);
								vtx.a = _FIXED2FLOATCOLOR(alphas[i], 8);
							}
							F5Naboo_PrepareAndDrawTriangle(vtxIdx, drawer);
						}
					}
				}
			}
		}
	};

	while (true) {
		switch (step)
		{
		case 3:
			Step3(data.EE - data.DD);
			Step3(data.EE - data.DD + 0x08);
			step = 4;
			break;
		case 4:
			if (data.DD == 0x10) {
				step = 6;
			} else {
				data.CC += data.TT;
				if (((data.AA & 0xFF) | (data.BB & 0xFF)) == 0)
					return;
				step = 5;
			}
			break;
		case 5:
			data.DD = 0x10;
			if ((data.AA & 0x80) == 0) {
				data.AA <<= 1;
				step = 6;
			} else {
				if ((data.AA & 0x8000) == 0) {
					data.AA <<= 1;
					step = 3;
				} else {
					data.AA <<= 1;
					return;
				}
			}
			break;
		case 6:
			data.DD = 0;
			if ((data.BB & 0x80) == 0) {
				data.BB <<= 1;
				step = 4;
			} else {
				if ((data.BB & 0x8000) == 0) {
					data.BB <<= 1;
					step = 3;
				} else {
					data.BB <<= 1;
					return;
				}
			}
			break;
		}
	}
}

static
struct NabooVertexData {
	SWVertex vtx;
	u32 E;
	u16 K, L, M, N, I, J;
	union {
		struct {
			u8 a, b, g, r;
		};
		u32 color;
	} color1, color2;
} vd1, vd2;

static
s32 multAndClip(s32 s, s32 t, s32 max)
{
	const u32 sign1 = s & 0x80000000;
	const u32 sign2 = t & 0x80000000;
	s32 res = 0;
	if ((sign1 ^ sign2) == 0) {
		// both positive or both negative
		res = static_cast<s32>(std::min(s64(max), (s64(s) * s64(t)) >> 32));
	}
	return res;
}

static
void F5Naboo_GenVertices0C()
{
	const u32 rdramAddr0 = _SHIFTR(*CAST_DMEM(const u32*, 0x0F8), 0, 24);
	memcpy(DMEM + 0x380, RDRAM + rdramAddr0, 512);

	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);

	// Step 1
	u32 dmemSrcAddr = (params[0] & 0xFFF);
	u32 dmemDstAddr = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr), 16, 16);
	u32 rdramAddr = _SHIFTR(params[4], 0, 24);
	memcpy(DMEM + dmemDstAddr, RDRAM + rdramAddr, 40);

	u32 dmemSrcAddr2 = dmemSrcAddr + 8;
	u32 dmemDstAddr2 = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr2), 16, 16);
	u32 rdramAddrShift = _SHIFTR(*CAST_DMEM(const u32*, 0xDBC), 16, 16);
	memcpy(DMEM + dmemDstAddr2, RDRAM + rdramAddr + rdramAddrShift, 40);

	const u32 flag = _SHIFTR(params[0], 12, 4);
	if (flag > 7) {
		u32 rdramAddr2 = _SHIFTR(params[5], 0, 24);
		memcpy(DMEM + dmemDstAddr + 0x78, RDRAM + rdramAddr2, 40);
		memcpy(DMEM + dmemDstAddr2 + 0x78, RDRAM + rdramAddr2 + rdramAddrShift, 40);
	}

	// Step 2
	const u32 A = s8(_SHIFTR(params[1], 24, 8)) * 0x10000;
	const u32 C32 = A - _SHIFTR(*CAST_DMEM(const u32*, 0xDD0), 16, 16);
	const s64 C64 = s64(s32(C32));
	const u32 C2 = static_cast<u32>((C64 * C64) >> 16);
	const u32 F = _SHIFTL(*CAST_DMEM(const u32*, 0xDCC), 16, 16);
	u32 G = C32 * _SHIFTR(*CAST_DMEM(const u32*, 0xDC4), 0, 16) + F;

	auto PrepareVertexDataStep2 = [&](u32 _V, const u32* _p, NabooVertexData & _vd) {
		_vd.vtx.x = _SHIFTL(_SHIFTR(_V, 24, 8), 8, 8);
		_vd.vtx.z = _SHIFTL(_SHIFTR(_V, 8, 8), 8, 8);
		_vd.vtx.flag = _SHIFTL(_SHIFTR(_V, 0, 8), 8, 8);
		u32 B = s8(_SHIFTR(_V, 8, 8)) * 0x10000;
		u32 D = B - _SHIFTR(_p[1], 16, 16);
		s64 D64 = s64(s32(D));
		_vd.E = C2 + static_cast<u32>((D64 * D64) >> 16);
	};

	PrepareVertexDataStep2(params[1] + _SHIFTR(*CAST_DMEM(const u32*, 0xDC0), 16, 16), CAST_DMEM(const u32*, 0xDD0), vd1);
	PrepareVertexDataStep2(params[1], CAST_DMEM(const u32*, 0xDD8), vd2);

	const u32 _E20 = *CAST_DMEM(const u32*, 0xE20);
	const u32 _E24 = *CAST_DMEM(const u32*, 0xE24);
	const u32 _E28 = *CAST_DMEM(const u32*, 0xE28);
	const u32 _E2C = *CAST_DMEM(const u32*, 0xE2C);
	const u32 I = (_E2C & 0xFFFF0000) | _SHIFTR(_E24, 16, 16);

	const u32 _DE0 = *CAST_DMEM(const u32*, 0xDE0);
	const u32 _DE4 = *CAST_DMEM(const u32*, 0xDE4);
	const u32 _DF0 = *CAST_DMEM(const u32*, 0xDF0);
	const u32 _DF4 = *CAST_DMEM(const u32*, 0xDF4);
	const s32 K = (s32((_DF0 & 0xFFFF0000) | _SHIFTR(_DE0, 16, 16)));
	const s32 L = (s32(_SHIFTL(_SHIFTR(_DF0, 0, 16), 16, 16) | _SHIFTR(_DE0, 0, 16)));
	const s32 M = (s32((_DF4 & 0xFFFF0000) | _SHIFTR(_DE4, 16, 16)));
	const s32 N = (s32(_SHIFTL(_SHIFTR(_DF4, 0, 16), 16, 16) | _SHIFTR(_DE4, 0, 16)));

	const u32 _E00 = *CAST_DMEM(const u32*, 0xE00);
	const u32 _E04 = *CAST_DMEM(const u32*, 0xE04);
	const u32 _E10 = *CAST_DMEM(const u32*, 0xE10);
	const u32 _E14 = *CAST_DMEM(const u32*, 0xE14);
	const s32 O = (s32((_E10 & 0xFFFF0000) | _SHIFTR(_E00, 16, 16)));
	const s32 P = (s32(_SHIFTL(_SHIFTR(_E10, 0, 16), 16, 16) | _SHIFTR(_E00, 0, 16)));
	const s32 Q = (s32((_E14 & 0xFFFF0000) | _SHIFTR(_E04, 16, 16)));
	const s32 R = (s32(_SHIFTL(_SHIFTR(_E14, 0, 16), 16, 16) | _SHIFTR(_E04, 0, 16)));

	const u32 _E34 = *CAST_DMEM(const u32*, 0xE34);
	const u32 startAddr = _SHIFTR(params[4], 24, 8);
	const u32 endAddr = _SHIFTR(params[5], 24, 8);

	// Step 3
	auto PrepareVertexDataStep3 = [&](NabooVertexData & _vd) {
		s32 K1 = (K - _vd.E);
		s32 K2 = multAndClip(K1, O, 0x7FFF);
		s32 L1 = (L - _vd.E);
		s32 L2 = multAndClip(L1, P, 0x7FFF);
		s32 M1 = (M - _vd.E);
		const s32 maxM = _SHIFTR(_E34, 16, 16);
		s32 M2 = multAndClip(M1, Q, maxM);
		s32 N1 = (N - _vd.E);
		const u32 maxN = _SHIFTR(_E34, 0, 16);
		s32 N2 = multAndClip(N1, R, maxN);
		u64 J = (u64(_vd.E) * u64(I)) >> 16;
		J *= J;
		_vd.K = static_cast<u16>(K2);
		_vd.L = static_cast<u16>(L2);
		_vd.M = static_cast<u16>(M2);
		_vd.N = static_cast<u16>(N2);
		_vd.J = std::min(u16(0x7FFF), static_cast<u16>(J >> 47));
	};

	const u32 _E40 = *CAST_DMEM(const u32*, 0xE40);
	const u32 _E48 = *CAST_DMEM(const u32*, 0xE48);
	const u32 _DD0 = *CAST_DMEM(const u32*, 0xDD0);
	const u32 _DD4 = *CAST_DMEM(const u32*, 0xDD4);
	const u32 _DD6 = _SHIFTL(_SHIFTR(_DD4, 0, 16), 16, 16);
	const u32 _DD8 = *CAST_DMEM(const u32*, 0xDD8);
	const u8 RR = *(DMEM + (0x0FC ^ 3));
	const u8 HH = *(DMEM + (0x0FD ^ 3));

	auto PrepareVertexDataStep4_7 = [&](u32 _addr, NabooVertexData & _vd) {
		const u32 factor = 0xFFFE - _vd.M - _vd.N;
		u32 U1 = *CAST_DMEM(const u32*, _addr);
		_vd.color1.r = static_cast<u8>((factor * _SHIFTR(U1, 24, 8) + _vd.M * _SHIFTR(_E40, 24, 8) + _vd.N * _SHIFTR(_E48, 24, 8)) >> 16);
		_vd.color1.g = static_cast<u8>((factor * _SHIFTR(U1, 16, 8) + _vd.M * _SHIFTR(_E40, 16, 8) + _vd.N * _SHIFTR(_E48, 16, 8)) >> 16);
		_vd.color1.b = static_cast<u8>((factor * _SHIFTR(U1,  8, 8) + _vd.M * _SHIFTR(_E40,  8, 8) + _vd.N * _SHIFTR(_E48, 8, 8)) >> 16);

		// Step 5
		u32 U2 = *CAST_DMEM(const u32*, _addr + 0x78);
		u8 u1 = ((U1 & 0xFF) + RR) & 0xFF;
		u8 u2 = ((U2 & 0xFF) + HH) & 0xFF;
		u32 u3 = u32(static_cast<s8>(*(DMEM + ((0x380 + u1) ^ 3))));
		u32 u4 = u32(static_cast<s8>(*(DMEM + ((0x380 + u2) ^ 3))));
		u32 L1 = _SHIFTL(_SHIFTR(_E28, 0, 16), 16, 16) | _SHIFTR(_E20, 0, 16);
		u32 L2 = _SHIFTL(_SHIFTR(_DD8, 0, 16), 16, 16) | _SHIFTR(_DD0, 0, 16);
		u16 u5 = (u3 * L1 + u4 * L2) >> 16;
		u16 u6 = (u5 + _SHIFTR(_E20, 16, 16)) & 0xFFFF;
		u16 u7 = ((0x7FFF - _vd.K) * u6 + _vd.K * _SHIFTR(_E28, 16, 16)) >> 16;
		_vd.vtx.y = ((0x7FFF - _vd.J) * u7 + _vd.J * _SHIFTR(_E24, 0, 16)) >> 16;

		// Step 6
		u8 A1 = *(DMEM + ((0x4FF + u4)^3));
		u16 factor1 = 0xFF - A1;
		u16 factor2 = 0xFF * A1;
		u8 Va = (factor1 * _SHIFTR(U2, 24, 8) + factor2) >> 8;
		u8 Vb = (factor1 * _SHIFTR(U2, 16, 8) + factor2) >> 8;
		u8 Vc = (factor1 * _SHIFTR(U2,  8, 8) + factor2) >> 8;

		_vd.color2.r = static_cast<u8>((factor * Va + _vd.M * _SHIFTR(_E40, 24, 8) + _vd.N * _SHIFTR(_E48, 24, 8)) >> 16);
		_vd.color2.g = static_cast<u8>((factor * Vb + _vd.M * _SHIFTR(_E40, 16, 8) + _vd.N * _SHIFTR(_E48, 16, 8)) >> 16);
		_vd.color2.b = static_cast<u8>((factor * Vc + _vd.M * _SHIFTR(_E40,  8, 8) + _vd.N * _SHIFTR(_E48,  8, 8)) >> 16);

		// Step 7
		const u32 factor3 = 0x7FFF - _vd.K;
		_vd.color2.r = (((factor3 * _vd.color2.r + _vd.K * _vd.color1.r) << 1) >> 16) + 1;
		_vd.color2.g = (((factor3 * _vd.color2.g + _vd.K * _vd.color1.g) << 1) >> 16) + 1;
		_vd.color2.b = (((factor3 * _vd.color2.b + _vd.K * _vd.color1.b) << 1) >> 16) + 1;

		_vd.color1.a = static_cast<u8>((_vd.K * _vd.K) >> 22);
		_vd.color2.a = static_cast<u8>(((((0x7FFF - _vd.L) * A1 + _vd.L * 0xFF) << 1) >> 16) + 1);

		*CAST_DMEM(u32*, _addr + 0x0F0) = _vd.color1.color;
		*CAST_DMEM(u32*, _addr + 0x168) = _vd.color2.color;

	};

	for (u32 addrShift = startAddr; addrShift <= endAddr; addrShift += 4) {

		PrepareVertexDataStep3(vd1);
		PrepareVertexDataStep3(vd2);

		// Step 4
		const u32 addr1 = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr), 16, 16) + addrShift;
		const u32 addr2 = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr + 8), 16, 16) + addrShift;
		PrepareVertexDataStep4_7(addr1, vd1);
		PrepareVertexDataStep4_7(addr2, vd2);

		// Step 8
		*CAST_DMEM(SWVertex*, 0x170 + addrShift * 2) = vd1.vtx;
		*CAST_DMEM(SWVertex*, 0x1C0 + addrShift * 2) = vd2.vtx;

		// Step 9
		const u32* V = CAST_DMEM(const u32*, 0xDC0);
		vd1.vtx.x += _SHIFTR(V[0], 16, 16);
		vd1.vtx.flag += _SHIFTR(V[1], 0, 16);
		vd2.vtx.x += _SHIFTR(V[0], 16, 16);
		vd2.vtx.flag += _SHIFTR(V[3], 0, 16);

		vd1.E += G;
		vd2.E += G;

		G += _DD6;
	}

	// Step 10
	const u16* v0_data = CAST_DMEM(const u16*, 0x128);
	const u16 X0 = v0_data[0 ^ 1];
	const u16 Y0 = v0_data[1 ^ 1];
	const u16 Z0 = v0_data[2 ^ 1];
	const bool needAdjustVertices = (X0 | Y0 | Z0) != 0;

	auto processVertices = [&](u32 _param, u32 _dmemSrcAddr, u32 _dstOffset) {
		const u32 numVtx = _param & 0x1F;
		if (numVtx == 0)
			return;
		const u32 offset = _param >> 5;
		const u32 vtxSrcAddr = _dmemSrcAddr + offset;
		const u32 vtxDstAddr = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr + _dstOffset), 16, 16) + offset * 5;
		DebugMsg(DEBUG_NORMAL, "GenVetices srcAddr = 0x%04x, dstAddr = 0x%04x, n = %i\n", vtxSrcAddr, vtxDstAddr, numVtx);
		if (!needAdjustVertices) {
			gSPSWVertex(CAST_DMEM(const SWVertex*, vtxSrcAddr), (vtxDstAddr - 0x600) / 40, numVtx);
			return;
		}
		std::vector<SWVertex> vtxData(numVtx);
		const SWVertex * pVtxSrc = CAST_DMEM(const SWVertex*, vtxSrcAddr);
		for (size_t i = 0; i < numVtx; ++i) {
			vtxData[i] = pVtxSrc[i];
			vtxData[i].x += X0;
			vtxData[i].y += Y0;
			vtxData[i].x += Z0;
		}
		gSPSWVertex(vtxData.data(), (vtxDstAddr - 0x600) / 40, numVtx);
	};
	processVertices(_SHIFTR(params[2], 16, 16), 0x170, 0x10);
	processVertices(_SHIFTR(params[2], 0, 16), 0x1C0, 0x18);

	// Step 11
	NabooData & data = getNabooData();
	u8* params8 = RDRAM + RSP.PC[RSP.PCi];
	u16* params16 = reinterpret_cast<u16*>(params8);
	data.AA = params16[6 ^ 1];
	data.BB = params16[7 ^ 1];
	data.CC = params8[1 ^ 3];
	data.TT = params8[5 ^ 3];
	data.EE = dmemSrcAddr;
	data.HH = _SHIFTR(*CAST_DMEM(const u32*, 0xDB8), 16, 16);
	data.DD = 0;
	F5Naboo_DrawPolygons();
}

static
void F5Naboo_GenVertices09()
{
	const u32* params = CAST_RDRAM(const u32*, RSP.PC[RSP.PCi]);

	// Step 1
	u32 dmemSrcAddr = (params[0] & 0xFFF);
	u32 dmemDstAddr = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr), 16, 16);
	u32 rdramAddr = _SHIFTR(params[4], 0, 24);
	memcpy(DMEM + dmemDstAddr, RDRAM + rdramAddr, 40);

	u32 dmemSrcAddr2 = dmemSrcAddr + 8;
	u32 dmemDstAddr2 = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr2), 16, 16);
	u32 rdramAddrShift = _SHIFTR(*CAST_DMEM(const u32*, 0xDBC), 16, 16);
	memcpy(DMEM + dmemDstAddr2, RDRAM + rdramAddr + rdramAddrShift, 40);

	const u32 flag = _SHIFTR(params[0], 12, 4);
	if (flag > 7) {
		u32 rdramAddr2 = _SHIFTR(params[5], 0, 24);
		memcpy(DMEM + dmemDstAddr + 0x78, RDRAM + rdramAddr2, 40);
		memcpy(DMEM + dmemDstAddr2 + 0x78, RDRAM + rdramAddr2 + rdramAddrShift, 40);
	}

	// Step 2
	const u32 A = s8(_SHIFTR(params[1], 24, 8)) * 0x10000;
	const u32 C32 = A - _SHIFTR(*CAST_DMEM(const u32*, 0xDD0), 16, 16);
	const s64 C64 = s64(s32(C32));
	const u32 C2 = static_cast<u32>((C64 * C64) >> 16);
	const u32 F = _SHIFTL(*CAST_DMEM(const u32*, 0xDCC), 16, 16);
	u32 G = C32 * _SHIFTR(*CAST_DMEM(const u32*, 0xDC4), 0, 16) + F;

	auto PrepareVertexDataStep2 = [&](u32 _V, const u32* _p, NabooVertexData & _vd) {
		_vd.vtx.x = _SHIFTL(_SHIFTR(_V, 24, 8), 8, 8);
		_vd.vtx.z = _SHIFTL(_SHIFTR(_V, 8, 8), 8, 8);
		_vd.vtx.flag = _SHIFTL(_SHIFTR(_V, 0, 8), 8, 8);
		u32 B = s8(_SHIFTR(_V, 8, 8)) * 0x10000;
		u32 D = B - _SHIFTR(_p[1], 16, 16);
		s64 D64 = s64(s32(D));
		_vd.E = C2 + static_cast<u32>((D64 * D64) >> 16);
	};

	PrepareVertexDataStep2(params[1] + _SHIFTR(*CAST_DMEM(const u32*, 0xDC0), 16, 16), CAST_DMEM(const u32*, 0xDD0), vd1);
	PrepareVertexDataStep2(params[1], CAST_DMEM(const u32*, 0xDD8), vd2);

	const u32 _E24 = *CAST_DMEM(const u32*, 0xE24);
	const u32 _E2C = *CAST_DMEM(const u32*, 0xE2C);
	const u32 I = (_E2C & 0xFFFF0000) | _SHIFTR(_E24, 16, 16);

	const u32 _DE0 = *CAST_DMEM(const u32*, 0xDE0);
	const u32 _DE4 = *CAST_DMEM(const u32*, 0xDE4);
	const u32 _DF0 = *CAST_DMEM(const u32*, 0xDF0);
	const u32 _DF4 = *CAST_DMEM(const u32*, 0xDF4);
	const s32 K = (s32((_DF0 & 0xFFFF0000) | _SHIFTR(_DE0, 16, 16)));
	const s32 L = (s32(_SHIFTL(_SHIFTR(_DF0, 0, 16), 16, 16) | _SHIFTR(_DE0, 0, 16)));
	const s32 M = (s32((_DF4 & 0xFFFF0000) | _SHIFTR(_DE4, 16, 16)));
	const s32 N = (s32(_SHIFTL(_SHIFTR(_DF4, 0, 16), 16, 16) | _SHIFTR(_DE4, 0, 16)));

	const u32 _E00 = *CAST_DMEM(const u32*, 0xE00);
	const u32 _E04 = *CAST_DMEM(const u32*, 0xE04);
	const u32 _E10 = *CAST_DMEM(const u32*, 0xE10);
	const u32 _E14 = *CAST_DMEM(const u32*, 0xE14);
	const s32 O = (s32((_E10 & 0xFFFF0000) | _SHIFTR(_E00, 16, 16)));
	const s32 P = (s32(_SHIFTL(_SHIFTR(_E10, 0, 16), 16, 16) | _SHIFTR(_E00, 0, 16)));
	const s32 Q = (s32((_E14 & 0xFFFF0000) | _SHIFTR(_E04, 16, 16)));
	const s32 R = (s32(_SHIFTL(_SHIFTR(_E14, 0, 16), 16, 16) | _SHIFTR(_E04, 0, 16)));

	const u32 _E34 = *CAST_DMEM(const u32*, 0xE34);
	const u32 startAddr = _SHIFTR(params[4], 24, 8);
	const u32 endAddr = _SHIFTR(params[5], 24, 8);

	// Step 3
	auto PrepareVertexDataStep3 = [&](NabooVertexData & _vd) {
		s32 K1 = (K - _vd.E);
		s32 K2 = multAndClip(K1, O, 0x7FFF);
		s32 L1 = (L - _vd.E);
		s32 L2 = multAndClip(L1, P, 0x7FFF);
		s32 M1 = (M - _vd.E);
		const s32 maxM = _SHIFTR(_E34, 16, 16);
		s32 M2 = multAndClip(M1, Q, maxM);
		s32 N1 = (N - _vd.E);
		const u32 maxN = _SHIFTR(_E34, 0, 16);
		s32 N2 = multAndClip(N1, R, maxN);
		u64 J = (u64(_vd.E) * u64(I)) >> 16;
		J *= J;
		_vd.K = static_cast<u16>(K2);
		_vd.L = static_cast<u16>(L2);
		_vd.M = static_cast<u16>(M2);
		_vd.N = static_cast<u16>(N2);
		_vd.J = std::min(u16(0x7FFF), static_cast<u16>(J >> 47));
	};

	const u32 _E40 = *CAST_DMEM(const u32*, 0xE40);
	const u32 _E48 = *CAST_DMEM(const u32*, 0xE48);

	auto PrepareVertexDataStep4 = [&](u32 _addr, u32 _V, u32 _addrShift, NabooVertexData & _vd) {
		auto sumBytes = [](u32 src1, u32 src2, u8* pDst) {
			const u8* pSrc1 = DMEM + src1;
			const u8* pSrc2 = DMEM + src2;
			for (u32 i = 0; i < 4; ++i)
				pDst[i] = (pSrc1[i] + pSrc2[i]) >> 1;
		};
		const u32 addr3 = _SHIFTR(_V, 16, 16) + _addrShift + (_addrShift & 4);
		const u32 addr4 = _SHIFTR(_V, 0, 16) + _addrShift - (_addrShift & 4);
		const u32 factor1 = 0x7FFF - _vd.L;
		const u32 factor2 = 0xFFFE - _vd.M - _vd.N;
		u32 U = *CAST_DMEM(const u32*, _addr);
		u32 T = 0;
		sumBytes(addr3, addr4, reinterpret_cast<u8*>(&T));
		u64 Va = factor1 * _SHIFTR(U, 24, 8) + _vd.L * _SHIFTR(T, 24, 8);
		Va *= factor2;
		Va >>= 16;
		u64 Vb = factor1 * _SHIFTR(U, 16, 8) + _vd.L * _SHIFTR(T, 16, 8);
		Vb *= factor2;
		Vb >>= 16;
		u64 Vc = factor1 * _SHIFTR(U, 8, 8) + _vd.L * _SHIFTR(T, 8, 8);
		Vc *= factor2;
		Vc >>= 16;
		u32 TA = ((*CAST_DMEM(const u32*, addr3) & 0xFF) << 7) +
			((*CAST_DMEM(const u32*, addr4) & 0xFF) << 7);
		u32 Vy1 = (factor1 * (_SHIFTR(U, 0, 8) << 8)) >> 16;
		u32 Vy2 = (_vd.L * TA) >> 16;
		u32 Vy = Vy1 + Vy2;
		_vd.color1.r = static_cast<u8>(((Va << 1) + _vd.M * _SHIFTR(_E40, 24, 8) + _vd.N * _SHIFTR(_E48, 24, 8)) >> 16);
		_vd.color1.g = static_cast<u8>(((Vb << 1) + _vd.M * _SHIFTR(_E40, 16, 8) + _vd.N * _SHIFTR(_E48, 16, 8)) >> 16);
		_vd.color1.b = static_cast<u8>(((Vc << 1) + _vd.M * _SHIFTR(_E40, 8, 8) + _vd.N * _SHIFTR(_E48, 8, 8)) >> 16);
		const u16 Y1 = static_cast<u16>((Vy * (0x7FFF - _vd.J) + _vd.J * _SHIFTR(_E24, 0, 16)) >> 16);

		U = *CAST_DMEM(const u32*, _addr + 0x78);
		sumBytes(addr3 + 0x78, addr4 + 0x78, reinterpret_cast<u8*>(&T));
		Va = factor1 * _SHIFTR(U, 24, 8) + _vd.L * _SHIFTR(T, 24, 8);
		Va *= factor2;
		Va >>= 16;
		Vb = factor1 * _SHIFTR(U, 16, 8) + _vd.L * _SHIFTR(T, 16, 8);
		Vb *= factor2;
		Vb >>= 16;
		Vc = factor1 * _SHIFTR(U, 8, 8) + _vd.L * _SHIFTR(T, 8, 8);
		Vc *= factor2;
		Vc >>= 16;
		TA = ((*CAST_DMEM(const u32*, addr3 + 0x78) & 0xFF) << 7) +
			((*CAST_DMEM(const u32*, addr4 + 0x78) & 0xFF) << 7);
		Vy1 = (factor1 * (_SHIFTR(U, 0, 8) << 8)) >> 16;
		Vy2 = (_vd.L * TA) >> 16;
		Vy = Vy1 + Vy2;
		_vd.color2.r = static_cast<u8>(((Va << 1) + _vd.M * _SHIFTR(_E40, 24, 8) + _vd.N * _SHIFTR(_E48, 24, 8)) >> 16);
		_vd.color2.g = static_cast<u8>(((Vb << 1) + _vd.M * _SHIFTR(_E40, 16, 8) + _vd.N * _SHIFTR(_E48, 16, 8)) >> 16);
		_vd.color2.b = static_cast<u8>(((Vc << 1) + _vd.M * _SHIFTR(_E40, 8, 8) + _vd.N * _SHIFTR(_E48, 8, 8)) >> 16);
		const u16 Y2 = static_cast<u16>((Vy * (0x7FFF - _vd.J) + _vd.J * _SHIFTR(_E24, 0, 16)) >> 16);

		// Step 5
		const u32 factor3 = 0x7FFF - _vd.K;
		_vd.color2.r = (((factor3 * _vd.color2.r + _vd.K * _vd.color1.r) << 1) >> 16) + 1;
		_vd.color2.g = (((factor3 * _vd.color2.g + _vd.K * _vd.color1.g) << 1) >> 16) + 1;
		_vd.color2.b = (((factor3 * _vd.color2.b + _vd.K * _vd.color1.b) << 1) >> 16) + 1;
		_vd.vtx.y = ((factor3 * Y2 + _vd.K * Y1) << 1) >> 16;

		// Step 7
		_vd.color1.a = _vd.color2.a = static_cast<u8>((_vd.K * _vd.K) >> 22);
		*CAST_DMEM(u32*, _addr + 0x0F0) = _vd.color1.color;
		*CAST_DMEM(u32*, _addr + 0x168) = _vd.color2.color;
	};

	for (u32 addrShift = startAddr; addrShift <= endAddr; addrShift += 4) {

		PrepareVertexDataStep3(vd1);
		PrepareVertexDataStep3(vd2);

		// Step 4
		const u32 addr1 = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr), 16, 16) + addrShift;
		const u32 addr2 = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr + 8), 16, 16) + addrShift;
		//const u32 addrShift2 = addrShift + (addrShift & 4);

		PrepareVertexDataStep4(addr1, *CAST_DMEM(const u32*, dmemSrcAddr + 0x20), addrShift, vd1);
		PrepareVertexDataStep4(addr2, *CAST_DMEM(const u32*, dmemSrcAddr + 0x24), addrShift, vd2);

		// Step 6
		*CAST_DMEM(SWVertex*, 0x170 + addrShift * 2) = vd1.vtx;
		*CAST_DMEM(SWVertex*, 0x1C0 + addrShift * 2) = vd2.vtx;

		// Step 8
		const u32* V = CAST_DMEM(const u32*, 0xDC0);
		vd1.vtx.x += _SHIFTR(V[0], 16, 16);
		vd1.vtx.flag += _SHIFTR(V[1], 0, 16);
		vd2.vtx.x += _SHIFTR(V[0], 16, 16);
		vd2.vtx.flag += _SHIFTR(V[3], 0, 16);

		vd1.E += G;
		vd2.E += G;

		const u32 _DD4 = *CAST_DMEM(const u32*, 0xDD4);
		const u32 _DD6 = _SHIFTL(_SHIFTR(_DD4, 0, 16), 16, 16);
		G += _DD6;
	}

	// Step 9
	const u16* v0_data = CAST_DMEM(const u16*, 0x128);
	const u16 X0 = v0_data[0 ^ 1];
	const u16 Y0 = v0_data[1 ^ 1];
	const u16 Z0 = v0_data[2 ^ 1];
	const bool needAdjustVertices = (X0 | Y0 | Z0) != 0;

	auto processVertices = [&](u32 _param, u32 _dmemSrcAddr, u32 _dstOffset) {
		const u32 numVtx = _param & 0x1F;
		if (numVtx == 0)
			return;
		const u32 offset = _param >> 5;
		const u32 vtxSrcAddr = _dmemSrcAddr + offset;
		const u32 vtxDstAddr = _SHIFTR(*CAST_DMEM(const u32*, dmemSrcAddr + _dstOffset), 16, 16) + offset * 5;
		DebugMsg(DEBUG_NORMAL, "GenVetices srcAddr = 0x%04x, dstAddr = 0x%04x, n = %i\n", vtxSrcAddr, vtxDstAddr, numVtx);
		if (!needAdjustVertices) {
			gSPSWVertex(CAST_DMEM(const SWVertex*, vtxSrcAddr), (vtxDstAddr - 0x600) / 40, numVtx);
			return;
		}
		std::vector<SWVertex> vtxData(numVtx);
		const SWVertex * pVtxSrc = CAST_DMEM(const SWVertex*, vtxSrcAddr);
		for (size_t i = 0; i < numVtx; ++i) {
			vtxData[i] = pVtxSrc[i];
			vtxData[i].x += X0;
			vtxData[i].y += Y0;
			vtxData[i].x += Z0;
		}
		gSPSWVertex(vtxData.data(), (vtxDstAddr - 0x600) / 40, numVtx);
	};
	processVertices(_SHIFTR(params[2], 16, 16), 0x170, 0x10);
	processVertices(_SHIFTR(params[2], 0, 16), 0x1C0, 0x18);

	// Step 10
	NabooData & data = getNabooData();
	u8* params8 = RDRAM + RSP.PC[RSP.PCi];
	u16* params16 = reinterpret_cast<u16*>(params8);
	data.AA = params16[6 ^ 1];
	data.BB = params16[7 ^ 1];
	data.CC = params8[1 ^ 3];
	data.TT = params8[5 ^ 3];
	data.EE = dmemSrcAddr;
	data.HH = _SHIFTR(*CAST_DMEM(const u32*, 0xDB8), 16, 16);
	data.DD = 0;
	F5Naboo_DrawPolygons();
}

static
void F5NABOO_TexturedPolygons(u32, u32)
{
	F5Naboo_DrawPolygons();
}

static
void F5INDI_GeometryGen(u32 _w0, u32 _w1)
{
	const u32 mode = _SHIFTR(_w1, 0, 8);
	DebugMsg(DEBUG_NORMAL, "F5INDI_GeometryGen (0x%08x, 0x%08x): mode=0x%02x\n", _w0, _w1, mode);
	switch (mode) {
	case 0x09: // Naboo
		F5Naboo_GenVertices09();
		RSP.PC[RSP.PCi] += 16;
		break;
	case 0x0C: // Naboo
		F5Naboo_GenVertices0C();
		RSP.PC[RSP.PCi] += 16;
		break;
	case 0x0F: // Naboo
		if (*(DMEM + (0x37E ^ 3)) == 0) {
			F5Naboo_CopyData00();
			RSP.PC[RSP.PCi] += 56;
		} else {
			F5Naboo_CopyDataFF();
			RSP.PC[RSP.PCi] += 8;
		}
		break;
	case 0x15: // Naboo
		F5Naboo_TexrectGen();
		RSP.PC[RSP.PCi] += 24;
		break;
	case 0x18:
		F5INDI_GenVertices(_w0, _w1);
		break;
	case 0x24:
		F5INDI_DoSubDList();
		F5INDI_TexrectGen();
		RSP.PC[RSP.PCi] += 32;
		break;
	case 0x27:
		F5INDI_GenParticlesVertices();
		RSP.PC[RSP.PCi] += 16;
		break;
	case 0x4F: // Naboo
		*(DMEM + (0x37E ^ 3)) = 0;
		break;
	}
}

static
void F5INDI_Texrect(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_Texrect (0x%08x, 0x%08x)\n", _w0, _w1);
	F5INDI_DoSubDList();
	RDP_TexRect(_w0, _w1);
}

static
void F5INDI_JumpDL(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_JumpDL\n");
	RSP.PC[RSP.PCi] = RSP.F5DL[RSP.PCi];
	_updateF5DL();
}

static
void F5INDI_EndDisplayList(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_EndDisplayList\n");
	gSPEndDisplayList();
}

static
void F5INDI_MoveWord(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F5INDI_MoveWord (0x%08x, 0x%08x)\n", _w0, _w1);
	const u32 destAddr = _SHIFTR(_w0, 0, 12);
	*CAST_DMEM(u32*, destAddr) = _w1;

	switch (destAddr) {
	case G_MWO_CLIP_RNX:
	case G_MWO_CLIP_RNY:
	case G_MWO_CLIP_RPX:
	case G_MWO_CLIP_RPY:
		gSPClipRatio(_w1);
		break;
	case G_MW_SEGMENT:
		assert(false);
		break;
	case 0x158:
	case 0x15C:
		// Used to adjust colors (See command 0x01 - Case 02)
		break;
	case 0x160:
		gSP.fog.multiplierf = _FIXED2FLOAT((s32)_w1, 16);
		gSP.changed |= CHANGED_FOGPOSITION;
		break;
	case 0x164:
		gSP.fog.offsetf = _FIXED2FLOAT((s32)_w1, 16);
		gSP.changed |= CHANGED_FOGPOSITION;
		break;
	case 0x14C:
		gSPPerspNormalize(_w1);
		break;
	case 0x58C:
		// sub dlist address;
		break;
	case 0x5B0:
	case 0x5B4:
		// Used to adjust colors (See command 0x01 - Case 02)
		break;
	}
}

static
void F5INDI_SetOtherMode(u32 w0, u32 w1)
{
	s32 AT = 0x80000000;
	AT >>= _SHIFTR(w0, 0, 5);
	u32 mask = u32(AT) >> _SHIFTR(w0, 8, 5);

	const u32 A0 = _SHIFTR(w0, 16, 3);
	if (A0 == 0) {
		gDP.otherMode.h = (gDP.otherMode.h&(~mask)) | w1;
		if (mask & 0x00300000)  // cycle type
			gDP.changed |= CHANGED_CYCLETYPE;
	} else if (A0 == 4) {
		gDP.otherMode.l = (gDP.otherMode.l&(~mask)) | w1;

		if (mask & 0x00000003)  // alpha compare
			gDP.changed |= CHANGED_ALPHACOMPARE;

		if (mask & 0xFFFFFFF8)  // rendermode / blender bits
			gDP.changed |= CHANGED_RENDERMODE;
	}
}

static
void F5INDI_SetOtherMode_Conditional(u32 w0, u32 w1)
{
	if (_SHIFTR(w0, 23, 1) != *CAST_DMEM(const u32*, 0x11C))
		return;

	F5INDI_SetOtherMode(w0, w1);
}

static
void F5INDI_ClearGeometryMode(u32 w0, u32 w1)
{
	gSPClearGeometryMode(~w1);
}

static
void F5INDI_Texture(u32 w0, u32 w1)
{
	F3D_Texture(w0, w1);
	*CAST_DMEM(u32*, 0x148) = w0;
	const u32 V0 = (gSP.geometryMode ^ w0) & 2;
	gSP.geometryMode ^= V0;
}

void F5Indi_Naboo_Init()
{
	srand((unsigned int)time(NULL));

	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags(F3D);
	G_SHADING_SMOOTH = G_SHADE;

	GBI.PCStackSize = 10;

	//			GBI Command				Command Value				Command Function
	GBI_SetGBI(G_SPNOOP,				F3D_SPNOOP,					F3D_SPNoOp);
	GBI_SetGBI(G_MOVEMEM,				F5INDI_MOVEMEM,				F5INDI_MoveMem);
	GBI_SetGBI(G_SET_DLIST_ADDR,		F5INDI_SET_DLIST_ADDR,		F5INDI_SetDListAddr);
	GBI_SetGBI(G_RESERVED1,				F5INDI_GEOMETRY_GEN,		F5INDI_GeometryGen);
	GBI_SetGBI(G_DL,					F5INDI_DL,					F5INDI_DList);
	GBI_SetGBI(G_RESERVED2,				F5INDI_BRANCHDL,			F5INDI_BranchDList);
	GBI_SetGBI(G_TRI2,					F5INDI_TRI2,				F5INDI_Tri);
	GBI_SetGBI(G_JUMPDL,				F5INDI_JUMPDL,				F5INDI_JumpDL);
	GBI_SetGBI(G_SETGEOMETRYMODE,		F3D_SETGEOMETRYMODE,		F3D_SetGeometryMode);
	GBI_SetGBI(G_CLEARGEOMETRYMODE,		F3D_CLEARGEOMETRYMODE,		F5INDI_ClearGeometryMode);
	GBI_SetGBI(G_ENDDL,					F5INDI_ENDDL,				F5INDI_EndDisplayList);
	GBI_SetGBI(G_SETOTHERMODE_L,		F5INDI_SETOTHERMODE_C,		F5INDI_SetOtherMode_Conditional);
	GBI_SetGBI(G_SETOTHERMODE_H,		F5INDI_SETOTHERMODE,		F5INDI_SetOtherMode);
	GBI_SetGBI(G_TEXTURE,				F3D_TEXTURE,				F5INDI_Texture );
	GBI_SetGBI(G_MOVEWORD,				F5INDI_MOVEWORD,			F5INDI_MoveWord);
	GBI_SetGBI(G_BE,					F5NABOO_BE,					F5NABOO_TexturedPolygons);
	GBI_SetGBI(G_TRI1,					F5INDI_TRI1,				F5INDI_Tri);
	GBI_SetGBI(G_INDI_TEXRECT,			F5INDI_TEXRECT,				F5INDI_Texrect);
}
