/* Star Wars Rogue Squadron ucode
 * Initial implementation ported from Lemmy's LemNemu plugin
 * Microcode decoding: olivieryuyu
 */

#include <assert.h>
#include <array>
#include <algorithm>
#include <cmath>
#include <GLideN64.h>
#include <DebugDump.h>
#include "F3D.h"
#include "F3DEX.h"
#include <N64.h>
#include <RSP.h>
#include <RDP.h>
#include <gSP.h>
#include <gDP.h>
#include <GBI.h>
#include <FrameBuffer.h>
#include <DisplayWindow.h>

#define F3DSWRS_VTXCOLOR			0x02
#define F3DSWRS_MOVEMEM				0x03
#define F3DSWRS_VTX					0x04
#define F3DSWRS_TRI_GEN				0x05
#define F3DSWRS_DL					0x06
#define F3DSWRS_BRANCHDL			0x07

#define F3DSWRS_SETOTHERMODE_L_EX	0xB3
#define F3DSWRS_TRI2				0xB4
#define F3DSWRS_JUMPSWDL			0xB5
#define F3DSWRS_ENDDL				0xB8
#define F3DSWRS_MOVEWORD			0xBC
#define F3DSWRS_TEXRECT_GEN			0xBD
#define F3DSWRS_SETOTHERMODE_H_EX	0xBE
#define F3DSWRS_TRI1				0xBF

#define F3DSWRS_MV_TEXSCALE			0x82
#define F3DSWRS_MW_FOG_MULTIPLIER	0x08
#define F3DSWRS_MW_FOG_OFFSET		0x0A

static u32 G_SETOTHERMODE_H_EX, G_SETOTHERMODE_L_EX, G_JUMPSWDL;
static u32 F3DSWRS_ViewportAddress;
static u32 F3DSWRS_PerspMatrixAddress;

struct SWRSTriangle
{
	u32 V0, V1, V2;
	int avrgZ;

};

bool SWRSTriangleCompare(const SWRSTriangle & _first, const SWRSTriangle & _second)
{
	return _first.avrgZ > _second.avrgZ;
}

static
SWRSTriangle TriGen0000_defaultTriangleOrder[32] = {
	// D1	D1	D2	D2	D3	D6	D3	D6	D4	D4
	// D7	D6	D8	D7	D9	D12	D8	D11	D10	D9
	// D2	D7	D3	D8	D4	D7	D9	D12	D5	D10
	{ 0, 6, 1, 0 },
	{ 0, 5, 6, 0 },
	{ 1, 7, 2, 0 },
	{ 1, 6, 7, 0 },
	{ 2, 8, 3, 0 },
	{ 5, 11, 6, 0 },
	{ 2, 7, 8, 0 },
	{ 5, 10, 11, 0 },
	{ 3, 9, 4, 0 },
	{ 3, 8, 9, 0 },

	// D7	D7	D11	D8	D11	D8	D9	D12	D9	D12
	// D13	D12	D17	D14	D16	D13	D15	D18	D14	D17
	// D8	D13	D12	D9	D17	D14	D10	D13	D15	D18
	{ 6, 12, 7, 0 },
	{ 6, 11, 12, 0 },
	{ 10, 16, 11, 0 },
	{ 7, 13, 8, 0 },
	{ 10, 15, 16, 0 },
	{ 7, 12, 13, 0 },
	{ 8, 14, 9, 0 },
	{ 11, 17, 12, 0 },
	{ 8, 13, 14, 0 },
	{ 11, 16, 17, 0 },

	// D16	D13	D16	D13	D14	D17	D17	D14	D18	D18
	// D22	D19	D21	D18	D20	D23	D22	D19	D24	D23
	// D17	D14	D22	D19	D15	D18	D23	D20	D19	D24
	{ 15, 21, 16, 0 },
	{ 12, 18, 13, 0 },
	{ 15, 20, 21, 0 },
	{ 12, 17, 18, 0 },
	{ 13, 19, 14, 0 },
	{ 16, 22, 17, 0 },
	{ 16, 21, 22, 0 },
	{ 13, 18, 19, 0 },
	{ 17, 23, 18, 0 },
	{ 17, 22, 23, 0 },

	// D19	D19
	// D25	D24
	// D20	D25
	{ 18, 24, 19, 0 },
	{ 18, 23, 24, 0 }
};

static
SWRSTriangle TriGen0001_defaultTriangleOrder[8] = {
	// D1	D1	D2	D2	D4	D4	D5	D5
	// D4	D5	D5	D6	D7	D8	D8	D9
	// D5	D2	D6	D3	D8	D5	D9	D6
	{ 0, 3, 4, 0 },
	{ 0, 4, 1, 0 },
	{ 1, 4, 5, 0 },
	{ 1, 5, 2, 0 },
	{ 3, 6, 7, 0 },
	{ 3, 7, 4, 0 },
	{ 4, 7, 8, 0 },
	{ 4, 8, 5, 0 }
};

inline
void _updateSWDL()
{
	// Lemmy's note:
	// differs from the other DL commands because it does skip the first command
	// the first 32 bits are stored, because they are
	// used as branch target address in the command in the QUAD "slot"
	RSP.swDL[RSP.PCi] = _SHIFTR(*(u32*)&RDRAM[RSP.PC[RSP.PCi]], 0, 24);
}

void F3DSWRS_Mtx(u32 w0, u32 w1)
{
	const u32 param = _SHIFTR(w0, 16, 8);
	if ((param & G_MTX_PROJECTION) != 0)
		F3DSWRS_PerspMatrixAddress = _SHIFTR(w1, 0, 24);
	F3D_Mtx(w0, w1);
}

void F3DSWRS_VertexColor(u32, u32 _w1)
{
	gSPSetVertexColorBase(_w1);
}

void F3DSWRS_MoveMem(u32 _w0, u32)
{
	switch (_SHIFTR(_w0, 16, 8)) {
	case F3D_MV_VIEWPORT://G_MV_VIEWPORT:
		F3DSWRS_ViewportAddress = _SHIFTR((RSP.PC[RSP.PCi] + 8), 0, 24);
		gSPViewport(F3DSWRS_ViewportAddress);
		break;
	case F3DSWRS_MV_TEXSCALE:
		gSP.textureCoordScale[0] = *(u32*)&RDRAM[RSP.PC[RSP.PCi] + 16];
		gSP.textureCoordScale[1] = *(u32*)&RDRAM[RSP.PC[RSP.PCi] + 12];
		DebugMsg(DEBUG_NORMAL, "F3DSWRS_MoveMem Texscale(0x%08x, 0x%08x)\n",
				 gSP.textureCoordScale[0], gSP.textureCoordScale[1]);
		break;
	}
	RSP.PC[RSP.PCi] += 16;
}

void F3DSWRS_Vtx(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_Vtx (0x%08x, 0x%08x)\n", _w0, _w1);

	const u32 address = RSP_SegmentToPhysical(_w1);
	const u32 n = _SHIFTR(_w0, 10, 6);

	if ((address + sizeof(SWVertex)* n) > RDRAMSize)
		return;

	const SWVertex * vertex = (const SWVertex*)&RDRAM[address];
	gSPSWVertex(vertex, n, 0 );
}

static
void F3DSWRS_PrepareVertices(const u32* _vert,
							 const u8* _colorbase,
							 const u32* _colorIdx,
							 const u8* _texbase,
							 bool _useTex,
							 bool _persp,
							 u32 _num)
{
	const u32 sscale = _SHIFTR(gSP.textureCoordScale[0], 16, 16);
	const u32 tscale = _SHIFTR(gSP.textureCoordScale[0], 0, 16);
	const u32 sscale1 = _SHIFTR(gSP.textureCoordScale[1], 16, 16);
	const u32 tscale1 = _SHIFTR(gSP.textureCoordScale[1], 0, 16);

	GraphicsDrawer & drawer = dwnd().getDrawer();

	for (u32 i = 0; i < _num; ++i) {
		SPVertex & vtx = drawer.getVertex(_vert != nullptr ? _vert[i] : i);
		const u8 *color = _colorbase + _colorIdx[i];
		vtx.r = color[3] * 0.0039215689f;
		vtx.g = color[2] * 0.0039215689f;
		vtx.b = color[1] * 0.0039215689f;
		vtx.a = color[0] * 0.0039215689f;

		if (_useTex) {
			const u32 st = *(u32*)&_texbase[4 * i];
			u32 s = (s16)_SHIFTR(st, 16, 16);
			u32 t = (s16)_SHIFTR(st, 0, 16);
			if ((s & 0x8000) != 0)
				s |= ~0xffff;
			if ((t & 0x8000) != 0)
				t |= ~0xffff;
			const u32 VMUDN_S = s * sscale;
			const u32 VMUDN_T = t * tscale;
			const s16 low_acum_S = _SHIFTR(VMUDN_S, 16, 16);
			const s16 low_acum_T = _SHIFTR(VMUDN_T, 16, 16);
			const u32 VMADH_S = s * sscale1;
			const u32 VMADH_T = t * tscale1;
			const s16 hi_acum_S = _SHIFTR(VMADH_S, 0, 16);
			const s16 hi_acum_T = _SHIFTR(VMADH_T, 0, 16);
			const s16 scaledS = low_acum_S + hi_acum_S;
			const s16 scaledT = low_acum_T + hi_acum_T;

			if (_persp) {
				vtx.s = _FIXED2FLOAT(scaledS, 5);
				vtx.t = _FIXED2FLOAT(scaledT, 5);
			} else {
				vtx.s = _FIXED2FLOAT(scaledS, 4);
				vtx.t = _FIXED2FLOAT(scaledT, 4);
			}
		}
	}
}

static
void TriGen0000_PrepareColorData(const u32 * _params, std::vector<u32> & _data)
{
	assert((_params[3] & 0x07) % 4 == 0);
	const u32* data32 = (const u32*)&RDRAM[_SHIFTR(_params[3], 0, 24)];
	std::copy_n(data32, 25, _data.begin());
}

static
void TriGen0001_PrepareColorData(const u32 * _params, std::vector<u32> & _data)
{
	assert((_params[3] & 0x07) % 4 == 0);
	const u32 dataSize = (((_SHIFTR(_params[4], 0, 16) + 0x13) & 0xFF0) - (_params[3] & 0x07)) / 4;
	const u32 dataAddr = (_SHIFTR(_params[3], 0, 24) & 0x00FFFFF8) +(_params[3] & 0x07);
	const u32* data32 = (const u32*)&RDRAM[dataAddr];

	u32 idx32 = 0;
	do {
		_data.push_back(data32[idx32++]);
		idx32++;
		_data.push_back(data32[idx32++]);
		idx32++;
		_data.push_back(data32[idx32]);
		idx32 += 6;
	} while(dataSize > idx32);

	const size_t colorDataSize = _data.size();
}

static
void TriGen0000_PrepareVtxData(const u32 * _params, std::vector<u16> & _data)
{
	const u32 dataAddr = _SHIFTR(_params[2], 0, 24) & 0x00FFFFF8;
	const s8* rdram_data8 = (const s8*)(RDRAM + dataAddr);

	u32 idx8 = _params[2] & 0x07;
	u32 dataIdx = 0;

	for (u32 i = 0; i < 25; ++i) {
		const s8 val = rdram_data8[idx8^3];
		++idx8;
		u16 res = _SHIFTL(val, 4, 8) | (val < 0 ? 0xF000 : 0);
		_data[dataIdx^1] = res;
		++dataIdx;
	}
}

static
void TriGen0001_PrepareVtxData(const u32 * _params, std::vector<u16> & _data)
{
	const u32 dataSize = (_SHIFTR(_params[4], 16, 16) + 0x16) & 0xFF0;
	_data.resize(dataSize / 2);
	const u32 dataAddr = _SHIFTR(_params[2], 0, 24) & 0x00FFFFF8;

	const s8* rdram_data8 = (const s8*)(RDRAM + dataAddr);

	u32 idx8 = _params[2] & 0x07;
	u32 dataIdx = 0;

	do {
		for (u32 i = 0; i < 3; ++i) {
			const s8 val = rdram_data8[idx8^3];
			idx8 += 2;
			u16 res = _SHIFTL(val, 4, 8) | (val < 0 ? 0xF000 : 0);
			_data[dataIdx^1] = res;
			++dataIdx;
		}
		idx8 += 4;
	} while(dataSize > idx8);
}

inline
void TriGen00_correctVertexForOption(std::vector<u16> & _vtxData, u32 _src1, u32 _src2, u32 _dst)
{
	const s16 vd = (s16)_vtxData[_src1] + (s16)_vtxData[_src2];
	_vtxData[_dst] = (u16)(vd / 2);
}

inline
void TriGen00_correctColorForOption(u32* _pColor, u32 _src1, u32 _src2, u32 _dst)
{
	u8* pSrc1 = (u8*)(_pColor + _src1);
	u8* pSrc2 = (u8*)(_pColor + _src2);
	u8* pDst =  (u8*)(_pColor + _dst);
	for (u32 i = 0; i < 4; ++i) {
		const u16 c = pSrc1[i] + pSrc2[i];
		pDst[i] = _SHIFTR(c, 1, 8);
	}
}

inline
void TriGen00_correctVertexForPonderation(std::vector<u16> & _vtxData, u32 _src1, u32 _src2, u32 _dst, u16 ponderation)
{
	const s16 * vtxData = (const s16*)_vtxData.data();
	s32 vd = vtxData[_dst] * (0x10000 - ponderation);
	vd += ((vtxData[_src1] + vtxData[_src2]) * ponderation) >> 1;
	_vtxData[_dst] = _SHIFTR(vd, 16, 16);
}

inline
void TriGen00_correctColorForPonderation(u32* _pColor, u32 _src1, u32 _src2, u32 _dst, u16 ponderation)
{
	u8* pSrc1 = (u8*)(_pColor + _src1);
	u8* pSrc2 = (u8*)(_pColor + _src2);
	u8* pDst =  (u8*)(_pColor + _dst);
	for (u32 i = 0; i < 4; ++i) {
		const u32 c = pDst[i] * (0x10000 - ponderation) + (((pSrc1[i] + pSrc2[i]) * ponderation) >> 1);
		pDst[i] = _SHIFTR(c, 16, 8);
	}
}

static
void TriGen0000_option_00000100(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData, std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF00) != 0x0100)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 1, 3, 0);
	TriGen00_correctVertexForOption(_vtxData, 3, 5, 2);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 0, 2, 1);
	TriGen00_correctColorForOption(_colorData.data(), 2, 4, 3);

	// Additional triangle
	SWRSTriangle t1 = { 0, 10, 5, 0 };
	_triangles.push_back(t1);
	SWRSTriangle t2 = { 10, 20, 15, 0 };
	_triangles.push_back(t2);
}

static
void TriGen0000_ponderation1(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation1 = _SHIFTR(_params[6], 0, 16);
	if (ponderation1 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 1, 3, 0, ponderation1);
	TriGen00_correctVertexForPonderation(_vtxData, 3, 5, 2, ponderation1);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 0, 2, 1, ponderation1);
	TriGen00_correctColorForPonderation(_colorData.data(), 2, 4, 3, ponderation1);
}

static
void TriGen0000_option_00000001(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData, std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF) != 0x01)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 21, 23, 20);
	TriGen00_correctVertexForOption(_vtxData, 23, 25, 22);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 20, 22, 21);
	TriGen00_correctColorForOption(_colorData.data(), 22, 24, 23);

	// Additional triangle
	SWRSTriangle t1 = { 4, 9, 14, 0 };
	_triangles.push_back(t1);
	SWRSTriangle t2 = { 14, 19, 24, 0 };
	_triangles.push_back(t2);
}

static
void TriGen0000_ponderation2(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation2 = _SHIFTR(_params[7], 16, 16);
	if (ponderation2 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 21, 23, 20, ponderation2);
	TriGen00_correctVertexForPonderation(_vtxData, 23, 25, 22, ponderation2);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 20, 22, 21, ponderation2);
	TriGen00_correctColorForPonderation(_colorData.data(), 22, 24, 23, ponderation2);
}

static
void TriGen0000_option_01000000(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData, std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF000000) != 0x01000000)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 1, 11, 4);
	TriGen00_correctVertexForOption(_vtxData, 11, 21,  14);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 0, 10, 5);
	TriGen00_correctColorForOption(_colorData.data(), 10, 20, 15);

	// Additional triangle
	SWRSTriangle t1 = { 0, 1, 2, 0 };
	_triangles.push_back(t1);
	SWRSTriangle t2 = { 2, 3, 4, 0 };
	_triangles.push_back(t2);
}

static
void TriGen0000_ponderation3(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation3 = _SHIFTR(_params[5], 0, 16);
	if (ponderation3 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 1, 11, 4, ponderation3);
	TriGen00_correctVertexForPonderation(_vtxData, 11, 21, 14, ponderation3);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 0, 10, 5, ponderation3);
	TriGen00_correctColorForPonderation(_colorData.data(), 10, 20, 15, ponderation3);
}

static
void TriGen0000_option_00010000(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData, std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF0000) != 0x010000)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 5, 15, 8);
	TriGen00_correctVertexForOption(_vtxData, 15, 25, 18);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 4, 14, 9);
	TriGen00_correctColorForOption(_colorData.data(), 14, 24, 19);

	// Additional triangle
	SWRSTriangle t1 = { 22, 24, 23, 0 };
	_triangles.push_back(t1);
	SWRSTriangle t2 = { 20, 22, 21, 0 };
	_triangles.push_back(t2);
}

static
void TriGen0000_ponderation4(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation4 = _SHIFTR(_params[6], 16, 16);
	if (ponderation4 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 5, 15, 8, ponderation4);
	TriGen00_correctVertexForPonderation(_vtxData, 15, 25, 18, ponderation4);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 4, 14, 9, ponderation4);
	TriGen00_correctColorForPonderation(_colorData.data(), 14, 24, 19, ponderation4);
}

static
void TriGen0000_ponderation5(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation5 = _SHIFTR(_params[5], 16, 16);
	if (ponderation5 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 1, 13, 7, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 3, 13, 6, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 3, 15, 9, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 11, 13, 10, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 13, 15, 12, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 11, 23, 17, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 13, 23, 16, ponderation5);
	TriGen00_correctVertexForPonderation(_vtxData, 13, 25, 19, ponderation5);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 0, 12, 6, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 2, 12, 7, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 2, 14, 8, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 10, 12, 11, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 12, 14, 13, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 10, 22, 16, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 12, 22, 17, ponderation5);
	TriGen00_correctColorForPonderation(_colorData.data(), 12, 24, 18, ponderation5);
}

static
void TriGen0001_option_01010201(const u32 * _params,
								std::vector<u16> & _vtxData,
								std::vector<u32> & _colorData,
								std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF00) != 0x0200)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 1, 3, 0);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 0, 2, 1);

	// Additional triangle
	SWRSTriangle t = { 0, 6, 3, 0 };
	_triangles.push_back(t);
}

static
void TriGen0001_ponderation1(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation1 = _SHIFTR(_params[6], 0, 16);
	if (ponderation1 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 1, 3, 0, ponderation1);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 0, 2, 1, ponderation1);
}

static
void TriGen0001_option_01010102(const u32 * _params,
								std::vector<u16> & _vtxData,
								std::vector<u32> & _colorData,
								std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF) != 0x02)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 7, 9, 8);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 6, 8, 7);

	// Additional triangle
	SWRSTriangle t = { 2, 5, 8, 0 };
	_triangles.push_back(t);
}

static
void TriGen0001_ponderation2(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation2 = _SHIFTR(_params[7], 16, 16);
	if (ponderation2 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 7, 9, 6, ponderation2);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 6, 8, 7, ponderation2);
}

static
void TriGen0001_option_02010101(const u32 * _params,
								std::vector<u16> & _vtxData,
								std::vector<u32> & _colorData,
								std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0xFF000000) != 0x02000000)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 1, 7, 2);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 0, 6, 3);

	// Additional triangle
	SWRSTriangle t = { 0, 1, 2, 0 };
	_triangles.push_back(t);
}

static
void TriGen0001_ponderation3(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation3 = _SHIFTR(_params[5], 0, 16);
	if (ponderation3 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 1, 7, 2, ponderation3);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 0, 6, 3, ponderation3);
}

static
void TriGen0001_option_01020101(const u32 * _params,
								std::vector<u16> & _vtxData,
								std::vector<u32> & _colorData,
								std::vector<SWRSTriangle> & _triangles)
{
	if ((_params[1] & 0x00FF0000) != 0x00020000)
		return;

	// Correct vertex data
	TriGen00_correctVertexForOption(_vtxData, 3, 9, 4);

	// Correct color data
	TriGen00_correctColorForOption(_colorData.data(), 2, 8, 5);

	// Additional triangle
	SWRSTriangle t = { 6, 8, 7, 0 };
	_triangles.push_back(t);
}

static
void TriGen0001_ponderation4(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation4 = _SHIFTR(_params[6], 16, 16);
	if (ponderation4 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 3, 9, 4, ponderation4);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 2, 8, 5, ponderation4);
}

static
void TriGen0001_ponderation5(const u32 * _params, std::vector<u16> & _vtxData, std::vector<u32> & _colorData)
{
	const u16 ponderation5 = _SHIFTR(_params[5], 16, 16);
	if (ponderation5 == 0)
		return;

	// Correct vertex data
	TriGen00_correctVertexForPonderation(_vtxData, 1, 9, 5, ponderation5);

	// Correct color data
	TriGen00_correctColorForPonderation(_colorData.data(), 0, 8, 4, ponderation5);
}

struct Vector2 {
	union {
		u16 vec16[4];
		u32 vec32[2];
		u64 qw;
	} data;

	Vector2() {
		data.qw = 0;
	}

	Vector2 ADD(const Vector2 & _v) const {
		Vector2 res;
		for (u32 i = 0; i < 4; ++i)
			res.data.vec16[i] = data.vec16[i] + _v.data.vec16[i];
		return res;
	}

	void VAL(u32 _idx, u16 _val) {
		data.vec16[_idx] = _val;
	}
};

static
void TriGen02_BuildVtxData(const u32 * _params, u32 * _output)
{
	Vector2  v0, v1, v2, v3;
	u16 V0 = _SHIFTR(_params[9], 0, 16);
	u16 V1 = _SHIFTR(_params[8], 0, 16);
	V1 <<= 4;
	v0.VAL(1, _SHIFTR(_params[8], 16, 16));
	v0.VAL(0, V1);
	v0.VAL(3, _SHIFTR(_params[9], 16, 16));
	v2.VAL(1, V0);
	v3.VAL(3, V0);
	v1.VAL(0, _SHIFTR(_params[1], 16, 16));
	v1 = v1.ADD(v0);
	_output[0] = v1.data.vec32[0];
	_output[1] = v1.data.vec32[1];
	v1 = v2;
	v1.VAL(0, _SHIFTR(_params[1], 0, 16));
	v1 = v1.ADD(v0);
	_output[2] = v1.data.vec32[0];
	_output[3] = v1.data.vec32[1];
	v1 = v3;
	v1.VAL(0, _SHIFTR(_params[2], 16, 16));
	v1 = v1.ADD(v0);
	_output[4] = v1.data.vec32[0];
	_output[5] = v1.data.vec32[1];
	v1 = v2.ADD(v3);
	v1.VAL(0, _SHIFTR(_params[2], 0, 16));
	v1 = v1.ADD(v0);
	_output[6] = v1.data.vec32[0];
	_output[7] = v1.data.vec32[1];
}

static
void TriGen00_BuildVtxData(const u32 * _params, u32 _step, const std::vector<u16> & _input, std::vector<u32> & _output)
{
	u16 V0 = _SHIFTR(_params[9], 0, 16);
	u16 V1 = _SHIFTR(_params[8], 0, 16);
	V1 <<= 4;
	Vector2 v0;
	v0.VAL(1, _SHIFTR(_params[8], 16, 16));
	v0.VAL(3, _SHIFTR(_params[9], 16, 16));
	v0.VAL(0, V1);
	Vector2 v2;
	v2.VAL(1, V0);
	Vector2 v3;
	v3.VAL(3, V0);
	Vector2 v1;

	const u32 bound = _step * (_step - 1) + 1;
	for (u32 startDataIdx = 0; startDataIdx < _step; ++startDataIdx) {
		for (u32 idx = 0; idx < bound; idx += _step) {
			v1.VAL(0, _input[(startDataIdx + idx) ^ 1]);
			Vector2 v4 = v1.ADD(v0);
			_output.push_back(v4.data.vec32[0]);
			_output.push_back(v4.data.vec32[1]);
			v1 = v1.ADD(v3);
		}
		v1 = v1.ADD(v2);
		v1.VAL(3, 0);
	}
}

static
void TriGen00_BuildColorIndices(u32 _step, u32 _vtxSize, std::vector<u32> & _colorIndices)
{
	u32 startColorIdx = 0;
	u32 colorIdx = 0;
	for (u32 i = 0; i < _vtxSize; i += _step) {
		for (u32 j = 0; j < _step; ++j) {
			_colorIndices[colorIdx++] = (startColorIdx + j * _step) << 2;
		}
		startColorIdx++;
	}
}

static
void TriGen00_BuildTextureCoords(u32 _step, const u32 * _params, std::vector<u32> & _texCoords)
{
	const u16 tex = _SHIFTR(_params[7], 0, 16);
	union {
		u16 w[2];
		u32 dw;
	} texCoord;
	u32 texIdx = 0;
	for (u32 i = 0; i < _step; ++i) {
		texCoord.w[0] = tex * (_step - 1);
		texCoord.w[1] = tex * i;
		for (u32 j = 0; j < _step; ++j) {
			_texCoords[texIdx++] = texCoord.dw;
			texCoord.dw -= tex;
		}
	}
}

inline
int screenZ(const SPVertex & _v)
{
	return int(((_v.z / _v.w) * gSP.viewport.vscale[2] + gSP.viewport.vtrans[2])*32768.0f);
}

static
int calcAvrgZ(GraphicsDrawer & drawer, const SWRSTriangle & t)
{
	int zsum = screenZ(drawer.getVertex(t.V0));
	zsum += screenZ(drawer.getVertex(t.V1));
	zsum += screenZ(drawer.getVertex(t.V2));
	return zsum / 3;
}

static
void TriGen0000()
{
	const u32* params = (const u32*)&RDRAM[RSP.PC[RSP.PCi]];

	// Step 1. Load data from RDRAM

	std::vector<u32> colorData(25);
	TriGen0000_PrepareColorData(params, colorData);

	std::vector<u16> vtxData16(26, 0);
	TriGen0000_PrepareVtxData(params, vtxData16);

	std::vector<SWRSTriangle> triangles;

	// Step 1.1 Options

	TriGen0000_option_00000100(params, vtxData16, colorData, triangles);
	TriGen0000_ponderation1(params, vtxData16, colorData);
	TriGen0000_option_00000001(params, vtxData16, colorData, triangles);
	TriGen0000_ponderation2(params, vtxData16, colorData);
	TriGen0000_option_01000000(params, vtxData16, colorData, triangles);
	TriGen0000_ponderation3(params, vtxData16, colorData);
	TriGen0000_option_00010000(params, vtxData16, colorData, triangles);
	TriGen0000_ponderation4(params, vtxData16, colorData);
	TriGen0000_ponderation5(params, vtxData16, colorData);

	// Step 2. Build vertex data from bytes obtained on Step 1.

	std::vector<u32> vtxData32;
	TriGen00_BuildVtxData(params, 5, vtxData16, vtxData32);

	// Step 3. Process vertices
	const SWVertex * vertex = (const SWVertex*)vtxData32.data();
	const size_t vtxSize = vtxData32.size() / 2;
	gSPSWVertex(vertex, vtxSize, 0);

	// Step 4. Prepare color indices and texture coordinates. Prepare vertices for rendering

	std::vector<u32> colorIndices(vtxSize);
	TriGen00_BuildColorIndices(5, vtxSize, colorIndices);

	std::vector<u32> texCoords(vtxSize);
	TriGen00_BuildTextureCoords(5, params, texCoords);

	F3DSWRS_PrepareVertices(nullptr, (u8*)colorData.data(),
							colorIndices.data(), (u8*)texCoords.data(), true, false, vtxSize);

	// Step 5. Prepare triangles, sort them by z and draw.

	GraphicsDrawer & drawer = dwnd().getDrawer();

	for (auto& t : triangles) {
		t.avrgZ = calcAvrgZ(drawer, t);
	}
	for (u32 i = 0; i < 32; ++i) {
		const SWRSTriangle & t = TriGen0000_defaultTriangleOrder[i];
		triangles.push_back(t);
		triangles.back().avrgZ = calcAvrgZ(drawer, t);
	}
	std::stable_sort(triangles.begin(), triangles.end(), SWRSTriangleCompare);

	for (const auto& t : triangles) {
		gSP1Triangle(t.V0, t.V1, t.V2);
	}
	drawer.drawTriangles();
}

static
void TriGen0001()
{
	const u32* params = (const u32*)&RDRAM[RSP.PC[RSP.PCi]];

	// Step 1. Load data from RDRAM

	std::vector<u32> colorData;
	TriGen0001_PrepareColorData(params, colorData);

	std::vector<u16> vtxData16;
	TriGen0001_PrepareVtxData(params, vtxData16);

	std::vector<SWRSTriangle> triangles;

	// Step 1.1 Options

	TriGen0001_option_01010201(params, vtxData16, colorData, triangles);
	TriGen0001_ponderation1(params, vtxData16, colorData);
	TriGen0001_option_01010102(params, vtxData16, colorData, triangles);
	TriGen0001_ponderation2(params, vtxData16, colorData);
	TriGen0001_option_02010101(params, vtxData16, colorData, triangles);
	TriGen0001_ponderation3(params, vtxData16, colorData);
	TriGen0001_option_01020101(params, vtxData16, colorData, triangles);
	TriGen0001_ponderation4(params, vtxData16, colorData);
	TriGen0001_ponderation5(params, vtxData16, colorData);

	// Step 2. Build vertex data from bytes obtained on Step 1.

	std::vector<u32> vtxData32;
	TriGen00_BuildVtxData(params, 3, vtxData16, vtxData32);

	// Step 3. Process vertices
	const SWVertex * vertex = (const SWVertex*)vtxData32.data();
	const size_t vtxSize = vtxData32.size() / 2;
	gSPSWVertex(vertex, vtxSize, 0);

	// Step 4. Prepare color indices and texture coordinates. Prepare vertices for rendering

	std::vector<u32> colorIndices(vtxSize);
	TriGen00_BuildColorIndices(3, vtxSize, colorIndices);

	std::vector<u32> texCoords(vtxSize);
	TriGen00_BuildTextureCoords(3, params, texCoords);

	F3DSWRS_PrepareVertices(nullptr, (u8*)colorData.data(),
							colorIndices.data(), (u8*)texCoords.data(), true, false, vtxSize);

	// Step 5. Prepare triangles, sort them by z and draw.

	GraphicsDrawer & drawer = dwnd().getDrawer();

	for (auto& t : triangles) {
		t.avrgZ = calcAvrgZ(drawer, t);
	}
	for (u32 i = 0; i < 8; ++i) {
		const SWRSTriangle & t = TriGen0001_defaultTriangleOrder[i];
		triangles.push_back(t);
		triangles.back().avrgZ = calcAvrgZ(drawer, t);
	}
	std::stable_sort(triangles.begin(), triangles.end(), SWRSTriangleCompare);

	for (const auto& t : triangles) {
		gSP1Triangle(t.V0, t.V1, t.V2);
	}
	drawer.drawTriangles();
}

static
void TriGen02()
{
	const u32* params = (const u32*)&RDRAM[RSP.PC[RSP.PCi]];

	u32 vecdata[8];
	TriGen02_BuildVtxData(params, vecdata);
	const SWVertex * vertex = (const SWVertex*)&vecdata[0];
	gSPSWVertex(vertex, 4, 0);
	GraphicsDrawer & drawer = dwnd().getDrawer();

	const u32 v1 = 0;
	const u32 v2 = 1;
	const u32 v3 = 2;
	const u32 v4 = 3;
	const u32 vert[4] = { v1, v2, v3, v4 };

	const u32 colorbase[4] = { params[3], params[4], params[5], params[6] };
	const u32 color[4] = { 0, 4, 8, 12 };

	const u32 tex = _SHIFTR(params[7], 0, 16);
	const u32 texbase[4] = { tex, tex | (tex << 16), 0, (tex << 16) };

	F3DSWRS_PrepareVertices(vert, (u8*)colorbase, color, (u8*)texbase, true, false, 4);

	SPVertex & vtx2 = drawer.getVertex(v2);
	SPVertex & vtx3 = drawer.getVertex(v3);

	if (vtx3.z / vtx3.w > vtx2.z / vtx2.w)
		gSP2Triangles(v1, v2, v4, 0, v1, v4, v3, 0);
	else
		gSP2Triangles(v1, v4, v3, 0, v1, v2, v4, 0);
	drawer.drawTriangles();
}

void F3DSWRS_TriGen(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_TriGen (0x%08x, 0x%08x)\n", _w0, _w1);

	const u32 nextCmd = RSP.nextCmd;
	RSP.nextCmd = G_TRI1;

	const u32 mode = _SHIFTR(_w0, 8, 8);
	switch (mode) {
	case 0x00:
	{
		const u32 mode00 = _SHIFTR(_w0, 0, 8);
		switch (mode00) {
		case 0x00:
			TriGen0000();
			break;
		case 0x01:
			TriGen0001();
			break;
		default:
			break;
		}
	}
		break;
	case 0x02:
		TriGen02();
		break;
	default:
		break;
	}

	RSP.nextCmd = nextCmd;
	RSP.PC[RSP.PCi] += 32;
}

void F3DSWRS_JumpSWDL(u32, u32)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_JumpSWDL\n");
	RSP.PC[RSP.PCi] = RSP.swDL[RSP.PCi];
	_updateSWDL();
}

void F3DSWRS_DList(u32, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_DList (0x%08x)\n", _w1);
	gSPDisplayList(_w1);
	_updateSWDL();
}

void F3DSWRS_BranchDList(u32, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_BranchDList (0x%08x)\n", _w1);
	gSPBranchList(_w1);
	_updateSWDL();
}

void F3DSWRS_EndDisplayList(u32, u32)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_EndDisplayList\n");
	gSPEndDisplayList();
//	_updateSWDL();
}

static
void _addVertices(const u32 _vert[3], GraphicsDrawer & _drawer)
{
	if (_drawer.isClipped(_vert[0], _vert[1], _vert[2]))
		return;

	SPVertex & vtx0 = _drawer.getVertex(_vert[(((RSP.w1 >> 24) & 3) % 3)]);

	for (u32 i = 0; i < 3; ++i) {
		SPVertex & vtx = _drawer.getVertex(_vert[i]);

		if ((gSP.geometryMode & G_SHADE) == 0) {
			// Prim shading
			vtx.flat_r = gDP.primColor.r;
			vtx.flat_g = gDP.primColor.g;
			vtx.flat_b = gDP.primColor.b;
			vtx.flat_a = gDP.primColor.a;
		} else if ((gSP.geometryMode & G_SHADING_SMOOTH) == 0) {
			// Flat shading
			vtx.r = vtx.flat_r = vtx0.r;
			vtx.g = vtx.flat_g = vtx0.g;
			vtx.b = vtx.flat_b = vtx0.b;
			vtx.a = vtx.flat_a = vtx0.a;
		}

		if (gDP.otherMode.depthSource == G_ZS_PRIM)
			vtx.z = gDP.primDepth.z * vtx.w;

		_drawer.getCurrentDMAVertex() = vtx;
	}
}

void F3DSWRS_Tri1(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_Tri1 (0x%08x, 0x%08x)\n", _w0, _w1);
	const u32 v1 = (_SHIFTR(_w1, 13, 11) & 0x7F8) / 40;
	const u32 v2 = (_SHIFTR( _w1,  5, 11 ) & 0x7F8) / 40;
	const u32 v3 = ((_w1 <<  3) & 0x7F8) / 40;
	const u32 vert[3] = { v1, v2, v3 };

	const u32 colorParam = *(u32*)&RDRAM[RSP.PC[RSP.PCi] + 8];
	const u32 colorIdx[3] = { _SHIFTR(colorParam, 16, 8), _SHIFTR(colorParam, 8, 8), _SHIFTR(colorParam, 0, 8) };

	const bool useTex = (_w0 & 2) != 0;
    const u8 * texbase = RDRAM + RSP.PC[RSP.PCi] + 16;
	F3DSWRS_PrepareVertices(vert, RDRAM + gSP.vertexColorBase, colorIdx, texbase, useTex, gDP.otherMode.texturePersp != 0, 3);

	if (useTex)
		RSP.PC[RSP.PCi] += 16;

	RSP.nextCmd = _SHIFTR(*(u32*)&RDRAM[RSP.PC[RSP.PCi] + 16], 24, 8);
	GraphicsDrawer & drawer = dwnd().getDrawer();
	_addVertices(vert, drawer);
	if (RSP.nextCmd != G_TRI1 && RSP.nextCmd != G_TRI2)
		drawer.drawDMATriangles(drawer.getDMAVerticesCount());

	RSP.PC[RSP.PCi] += 8;
}

void F3DSWRS_Tri2(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_Tri2 (0x%08x, 0x%08x)\n", _w0, _w1);
	const u32 v1 = (_SHIFTR(_w1, 13, 11) & 0x7F8) / 40;
	const u32 v2 = (_SHIFTR( _w1,  5, 11 ) & 0x7F8) / 40;
	const u32 v3 = ((_w1 <<  3) & 0x7F8) / 40;
	const u32 v4 = (_SHIFTR( _w1,  21, 11 ) & 0x7F8) / 40;
	const u32 vert[4] = { v1, v2, v3, v4 };

	const u32 colorParam = *(u32*)&RDRAM[RSP.PC[RSP.PCi] + 8];
	const u32 colorIdx[4] = { _SHIFTR(colorParam, 16, 8), _SHIFTR(colorParam, 8, 8),
							_SHIFTR(colorParam, 0, 8), _SHIFTR(colorParam, 24, 8) };

	const bool useTex = (_w0 & 2) != 0;
    const u8 * texbase = RDRAM + RSP.PC[RSP.PCi] + 16;
	F3DSWRS_PrepareVertices(vert, RDRAM + gSP.vertexColorBase, colorIdx, texbase, useTex, gDP.otherMode.texturePersp != 0, 4);

	if (useTex)
		RSP.PC[RSP.PCi] += 16;

	RSP.nextCmd = _SHIFTR(*(u32*)&RDRAM[RSP.PC[RSP.PCi] + 16], 24, 8);
	GraphicsDrawer & drawer = dwnd().getDrawer();
	const u32 vert1[3] = { v1, v2, v3 };
	_addVertices(vert1, drawer);
	const u32 vert2[3] = { v1, v3, v4 };
	_addVertices(vert2, drawer);
	if (RSP.nextCmd != G_TRI1 && RSP.nextCmd != G_TRI2)
		drawer.drawDMATriangles(drawer.getDMAVerticesCount());

	RSP.PC[RSP.PCi] += 8;
}

void F3DSWRS_MoveWord(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_MoveWord (0x%08x, 0x%08x)\n", _w0, _w1);
	switch (_SHIFTR(_w0, 0, 8)){
	case G_MW_CLIP:
		gSPClipRatio( _w1 );
		break;
	case G_MW_SEGMENT:
		gSPSegment( _SHIFTR( _w0, 8, 16 ) >> 2, _w1 & 0x00FFFFFF );
		break;
	case F3DSWRS_MW_FOG_MULTIPLIER:
		gSP.fog.multiplierf = _FIXED2FLOAT((s32)_w1, 16);
		gSP.changed |= CHANGED_FOGPOSITION;
		break;
	case F3DSWRS_MW_FOG_OFFSET:
		gSP.fog.offsetf = _FIXED2FLOAT((s32)_w1, 16);
		gSP.changed |= CHANGED_FOGPOSITION;
		break;
	case G_MW_PERSPNORM:
		gSPPerspNormalize( _w1 );
		break;
	}
}

void F3DSWRS_TexrectGen(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_TexrectGen (0x%08x, 0x%08x)\n", _w0, _w1);

	const u32 vtxIdx = ((_w0 >> 5) & 0x07F8) / 40;

	const u32* params = (const u32*)&RDRAM[RSP.PC[RSP.PCi]];

	RSP.PC[RSP.PCi] += 16;

	const SPVertex & v = dwnd().getDrawer().getVertex(vtxIdx);
	if (v.clip != 0)
		return;

	const f32 screenX = v.x / v.w * gSP.viewport.vscale[0] + gSP.viewport.vtrans[0];
	const f32 screenY = -v.y / v.w * gSP.viewport.vscale[1] + gSP.viewport.vtrans[1];

	const bool flip = (_w0 & 1) != 0;

	const u32 w_i = std::max(1U, u32(v.w));
	const u32 viewport = *(u32*)&RDRAM[F3DSWRS_ViewportAddress];
	const u32 viewportX = _SHIFTR(viewport, 17, 15);
	const u32 viewportY = _SHIFTR(viewport, 1, 15);
	const u32* const perspMatrix = (u32*)&RDRAM[F3DSWRS_PerspMatrixAddress];
	const u32 perspMatrixX = (perspMatrix[0] & 0xFFFF0000) | _SHIFTR(perspMatrix[8], 16, 16);
	const u32 perspMatrixY = _SHIFTL(perspMatrix[2], 16, 16) | _SHIFTR(perspMatrix[10], 0, 16);
	u64 param3X = _SHIFTR(params[3], 16, 16);
	u64 param3Y = _SHIFTR(params[3], 0, 16);
	if (flip)
		std::swap(param3X, param3Y);

	u32 offset_x_i = (u32)(((param3X * viewportX * perspMatrixX) / w_i) >> 16);
	u32 offset_y_i = (u32)(((param3Y * viewportY * perspMatrixY) / w_i) >> 16);
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

	if ((_w0 & 2) != 0) {
		dsdx_i = -dsdx_i;
		E = _SHIFTR(params[4], 16, 16);;
	}

	if ((_w0 & 4) != 0) {
		dtdy_i = -dtdy_i;
		F = _SHIFTR(params[4], 0, 16);;
	}

	const f32 dsdx = _FIXED2FLOAT((s16)dsdx_i, 10);
	const f32 dtdy = _FIXED2FLOAT((s16)dtdy_i, 10);

	if (flip)
		std::swap(dsdx_i, dtdy_i);

	u16 S, T;

	if (ulx > 0)  {
		S = E + 0xFFF0;
	} else {
		const int ulx_i = int(ulx * 4.0f);
		S = ((0 - (dsdx_i << 6) * ulx_i) << 3) + E + 0xFFF0;
	}

	if (uly > 0)  {
		T = F + 0xFFF0;
	} else {
		const int uly_i = int(uly * 4.0f);
		T = ((0 - (dtdy_i << 6) * uly_i) << 3) + F + 0xFFF0;
	}

	gDP.primDepth.z = v.z/v.w;
	gDP.primDepth.deltaZ = 0.0f;

	const u32 primColor = params[1];
	gDPSetPrimColor( u32(gDP.primColor.m*255.0f),	// m
					 u32(gDP.primColor.l*255.0f),	// l
					 _SHIFTR( primColor, 24, 8 ),	// r
					 _SHIFTR( primColor, 16, 8 ),	// g
					 _SHIFTR( primColor,  8, 8 ),	// b
					 _SHIFTR( primColor,  0, 8 ) );	// a

	if ((gSP.geometryMode & G_FOG) != 0) {
		const u32 fogColor = (params[1] & 0xFFFFFF00) | u32(v.a*255.0f);
		gDPSetFogColor( _SHIFTR( fogColor, 24, 8 ),		// r
						_SHIFTR( fogColor, 16, 8 ),		// g
						_SHIFTR( fogColor,  8, 8 ),		// b
						_SHIFTR( fogColor,  0, 8 ) );	// a
	}

	gDPTextureRectangle(ulx, uly, lrx, lry, gSP.texture.tile, (s16)S, (s16)T, dsdx, dtdy, flip);
}

void F3DSWRS_SetOtherMode_H_EX(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_SetOtherMode_H_EX (0x%08x, 0x%08x)\n", _w0, _w1);
	RSP.PC[RSP.PCi] += 8;
	gDP.otherMode.h &= *(u32*)&RDRAM[RSP.PC[RSP.PCi]];
	gDP.otherMode.h |= _w1;
}

void F3DSWRS_SetOtherMode_L_EX(u32 _w0, u32 _w1)
{
	DebugMsg(DEBUG_NORMAL, "F3DSWRS_SetOtherMode_L_EX (0x%08x, 0x%08x)\n", _w0, _w1);
	RSP.PC[RSP.PCi] += 8;
	gDP.otherMode.l &= *(u32*)&RDRAM[RSP.PC[RSP.PCi]];
	gDP.otherMode.l |= _w1;
}

void F3DSWRS_Init()
{
	gSPSetupFunctions();
	// Set GeometryMode flags
	GBI_InitFlags( F3D );

	GBI.PCStackSize = 10;

	//          GBI Command             Command Value				Command Function
	GBI_SetGBI( G_SPNOOP,				F3D_SPNOOP,					F3D_SPNoOp );
	GBI_SetGBI( G_MTX,					F3D_MTX,					F3DSWRS_Mtx );
	GBI_SetGBI( G_RESERVED0,			F3DSWRS_VTXCOLOR,			F3DSWRS_VertexColor );
	GBI_SetGBI( G_MOVEMEM,				F3DSWRS_MOVEMEM,			F3DSWRS_MoveMem );
	GBI_SetGBI( G_VTX,					F3DSWRS_VTX,				F3DSWRS_Vtx );
	GBI_SetGBI( G_RESERVED1,			F3DSWRS_TRI_GEN,			F3DSWRS_TriGen );
	GBI_SetGBI( G_DL,					F3DSWRS_DL,					F3DSWRS_DList );
	GBI_SetGBI( G_RESERVED2,			F3DSWRS_BRANCHDL,			F3DSWRS_BranchDList );
	GBI_SetGBI( G_RESERVED3,			F3D_RESERVED3,				F3D_Reserved3 );

	GBI_SetGBI( G_TRI1,					F3DSWRS_TRI1,				F3DSWRS_Tri1 );
	GBI_SetGBI( G_SETOTHERMODE_H_EX,	F3DSWRS_SETOTHERMODE_H_EX,	F3DSWRS_SetOtherMode_H_EX );
	GBI_SetGBI( G_POPMTX,				F3DSWRS_TEXRECT_GEN,		F3DSWRS_TexrectGen );
	GBI_SetGBI( G_MOVEWORD,				F3DSWRS_MOVEWORD,			F3DSWRS_MoveWord );
	GBI_SetGBI( G_TEXTURE,				F3D_TEXTURE,				F3D_Texture );
	GBI_SetGBI( G_SETOTHERMODE_H,		F3D_SETOTHERMODE_H,			F3D_SetOtherMode_H );
	GBI_SetGBI( G_SETOTHERMODE_L,		F3D_SETOTHERMODE_L,			F3D_SetOtherMode_L );
	GBI_SetGBI( G_ENDDL,				F3DSWRS_ENDDL,				F3DSWRS_EndDisplayList );
	GBI_SetGBI( G_SETGEOMETRYMODE,		F3D_SETGEOMETRYMODE,		F3D_SetGeometryMode );
	GBI_SetGBI( G_CLEARGEOMETRYMODE,	F3D_CLEARGEOMETRYMODE,		F3D_ClearGeometryMode );
	GBI_SetGBI( G_JUMPSWDL,				F3DSWRS_JUMPSWDL,			F3DSWRS_JumpSWDL );
	GBI_SetGBI( G_TRI2,					F3DSWRS_TRI2,				F3DSWRS_Tri2 );
	GBI_SetGBI( G_SETOTHERMODE_L_EX,	F3DSWRS_SETOTHERMODE_L_EX,	F3DSWRS_SetOtherMode_L_EX );
}
