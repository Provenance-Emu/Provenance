#include <assert.h>
#include <algorithm>
#include "DepthBufferRender/ClipPolygon.h"
#include "DepthBufferRender/DepthBufferRender.h"
#include "gSP.h"
#include "SoftwareRender.h"
#include "DepthBuffer.h"
#include "Config.h"

inline
void clipTest(vertexclip & _vtx)
{
	_vtx.visible = 0;
	if (_vtx.x > gSP.viewport.width)
		_vtx.visible |= RIGHT;
	if (_vtx.x < 0)
		_vtx.visible |= LEFT;
	if (_vtx.y > gSP.viewport.height)
		_vtx.visible |= TOP;
	if (_vtx.y < 0)
		_vtx.visible |= BOT;
}

static
bool calcScreenCoordinates(SPVertex * _vsrc, vertexclip * _vclip, u32 _numVertex, bool & _clockwise)
{
	for (u32 i = 0; i < _numVertex; ++i) {
		SPVertex & v = _vsrc[i];

		if ((v.modify & MODIFY_XY) == 0) {
			_vclip[i].x = gSP.viewport.vtrans[0] + (v.x / v.w) * gSP.viewport.vscale[0];
			_vclip[i].y = gSP.viewport.vtrans[1] + (v.y / v.w) * -gSP.viewport.vscale[1];
		} else {
			_vclip[i].x = v.x;
			_vclip[i].y = v.y;
		}

		if ((v.modify & MODIFY_Z) == 0) {
			_vclip[i].z = (gSP.viewport.vtrans[2] + (v.z / v.w) * gSP.viewport.vscale[2]) * 32767.0f;
		} else {
			_vclip[i].z = v.z * 32767.0f;
		}

		clipTest(_vclip[i]);
	}

	if (_numVertex > 3) // Don't cull w-clipped vertices
		return true;

	// Check culling
	const float x1 = _vclip[0].x - _vclip[1].x;
	const float y1 = _vclip[0].y - _vclip[1].y;
	const float x2 = _vclip[2].x - _vclip[1].x;
	const float y2 = _vclip[2].y - _vclip[1].y;

	_clockwise = (x1*y2 - y1*x2) >= 0.0f;

	const u32 cullMode = (gSP.geometryMode & G_CULL_BOTH);

	if (cullMode == G_CULL_FRONT) {
		if (_clockwise) //clockwise, negative
			return false;
	} else if (cullMode == G_CULL_BACK) {
		if (!_clockwise) //counter-clockwise, positive
			return false;
	}

	return true;
}

inline
int floatToFixed16(double _v)
{
	return static_cast<int>(_v * 65536.0);
}

static
int calcDzDx(vertexclip * _v)
{
	double X0 = _v[0].x;
	double Y0 = _v[0].y;
	double X1 = _v[1].x;
	double Y1 = _v[1].y;
	double X2 = _v[2].x;
	double Y2 = _v[2].y;
	double diffy_02 = Y0 - Y2;
	double diffy_12 = Y1 - Y2;
	double diffx_02 = X0 - X2;
	double diffx_12 = X1 - X2;

	double denom = (diffx_02 * diffy_12 - diffx_12 * diffy_02);
	if(denom*denom > 0.0) {
		double diffz_02 = _v[0].z - _v[2].z;
		double diffz_12 = _v[1].z - _v[2].z;
		double fdzdx = (diffz_02 * diffy_12 - diffz_12 * diffy_02) / denom;
		return floatToFixed16(fdzdx);
	}
	return 0;
}

static
int calcDzDx2(const SPVertex ** _vsrc)
{
	const SPVertex * v = _vsrc[0];
	double X0 = gSP.viewport.vtrans[0] + (v->x / v->w) * gSP.viewport.vscale[0];
	double Y0 = gSP.viewport.vtrans[1] + (v->y / v->w) * -gSP.viewport.vscale[1];
	double Z0 = (gSP.viewport.vtrans[2] + (v->z / v->w) * gSP.viewport.vscale[2]) * 32767.0f;
	v = _vsrc[1];
	double X1 = gSP.viewport.vtrans[0] + (v->x / v->w) * gSP.viewport.vscale[0];
	double Y1 = gSP.viewport.vtrans[1] + (v->y / v->w) * -gSP.viewport.vscale[1];
	double Z1 = (gSP.viewport.vtrans[2] + (v->z / v->w) * gSP.viewport.vscale[2]) * 32767.0f;
	v = _vsrc[2];
	double X2 = gSP.viewport.vtrans[0] + (v->x / v->w) * gSP.viewport.vscale[0];
	double Y2 = gSP.viewport.vtrans[1] + (v->y / v->w) * -gSP.viewport.vscale[1];
	double Z2 = (gSP.viewport.vtrans[2] + (v->z / v->w) * gSP.viewport.vscale[2]) * 32767.0f;
	double diffy_02 = Y0 - Y2;
	double diffy_12 = Y1 - Y2;
	double diffx_02 = X0 - X2;
	double diffx_12 = X1 - X2;

	double denom = (diffx_02 * diffy_12 - diffx_12 * diffy_02);
	if (denom*denom > 0.0) {
		double diffz_02 = Z0 - Z2;
		double diffz_12 = Z1 - Z2;
		double fdzdx = (diffz_02 * diffy_12 - diffz_12 * diffy_02) / denom;
		return floatToFixed16(fdzdx);
	}
	return 0;
}

inline
void copyVertex(SPVertex & _dst, const SPVertex * _src)
{
	_dst.x = _src->x;
	_dst.y = _src->y;
	_dst.z = _src->z;
	_dst.w = _src->w;
	_dst.modify = _src->modify;
}

static
u32 clipW(const SPVertex ** _vsrc, SPVertex * _vdst)
{
	u32 dsti = 0;
	for (int n = 0; n < 3; ++n) {
		const SPVertex * src1 = _vsrc[n];               // current vertex
		const SPVertex * src2 = _vsrc[n + 1];           // next vertex
		if (src1->w >= 0.01f) {
			copyVertex(_vdst[dsti++], src1);          // add visible vertex to list
			if (src2->w >= 0.01f)
				continue;
		} else if (src2->w < 0.01f)
			continue;
		float a = (-src1->w) / (src2->w - src1->w);
		float ima = 1.0f - a;
		// create new vertex
		_vdst[dsti].x = src1->x*ima + src2->x*a;
		_vdst[dsti].y = src1->y*ima + src2->y*a;
		_vdst[dsti].z = src1->z*ima + src2->z*a;
		_vdst[dsti].w = 0.01f;
        _vdst[dsti].modify = 0;
        dsti++;
	}
	return dsti;
}

f32 renderTriangles(const SPVertex * _pVertices, const u16 * _pElements, u32 _numElements)
{
	vertexclip vclip[16];
	vertexi vdraw[12];
	const SPVertex * vsrc[4];
	SPVertex vdata[6];
	f32 maxY = 0.0f;
	for (u32 i = 0; i < _numElements; i += 3) {
		u32 orbits = 0;
		if (_pElements != nullptr) {
			for (u32 j = 0; j < 3; ++j) {
				vsrc[j] = &_pVertices[_pElements[i + j]];
				orbits |= vsrc[j]->clip;
			}
		} else {
			for (u32 j = 0; j < 3; ++j) {
				vsrc[j] = &_pVertices[i + j];
				orbits |= vsrc[j]->clip;
			}
		}
		vsrc[3] = vsrc[0];

		u32 numVertex = clipW(vsrc, vdata);

		bool clockwise = true;
		if (!calcScreenCoordinates(vdata, vclip, numVertex, clockwise))
			continue;

		const int dzdx = ((orbits & CLIP_W) == 0) ? calcDzDx(vclip) : calcDzDx2(vsrc);

		if (orbits == 0) {
			assert(numVertex == 3);
			if (clockwise) {
				for (int k = 0; k < 3; ++k) {
					maxY = std::max(maxY, vclip[k].y);
					vdraw[k].x = floatToFixed16(vclip[k].x);
					vdraw[k].y = floatToFixed16(vclip[k].y);
					vdraw[k].z = floatToFixed16(vclip[k].z);
				}
			} else {
				for (int k = 0; k < 3; ++k) {
					const u32 idx = 3 - k - 1;
					maxY = std::max(maxY, vclip[idx].y);
					vdraw[k].x = floatToFixed16(vclip[idx].x);
					vdraw[k].y = floatToFixed16(vclip[idx].y);
					vdraw[k].z = floatToFixed16(vclip[idx].z);
				}
			}
		} else {
			vertexclip ** vtx;
			numVertex = ClipPolygon(&vtx, vclip, numVertex);
			if (numVertex < 3)
				continue;

			if (clockwise) {
				for (u32 k = 0; k < numVertex; ++k) {
					maxY = std::max(maxY, vtx[k]->y);
					vdraw[k].x = floatToFixed16(vtx[k]->x);
					vdraw[k].y = floatToFixed16(vtx[k]->y);
					vdraw[k].z = floatToFixed16(vtx[k]->z);
				}
			} else {
				for (u32 k = 0; k < numVertex; ++k) {
					const u32 idx = numVertex - k - 1;
					maxY = std::max(maxY, vtx[idx]->y);
					vdraw[k].x = floatToFixed16(vtx[idx]->x);
					vdraw[k].y = floatToFixed16(vtx[idx]->y);
					vdraw[k].z = floatToFixed16(vtx[idx]->z);
				}
			}
		}

		//Current depth buffer can be null if we are loading from a save state
		if (depthBufferList().getCurrent() != nullptr &&
			config.frameBufferEmulation.copyDepthToRDRAM == Config::cdSoftwareRender &&
			gDP.otherMode.depthUpdate != 0)
			Rasterize(vdraw, numVertex, dzdx);
	}
	return maxY;
}
