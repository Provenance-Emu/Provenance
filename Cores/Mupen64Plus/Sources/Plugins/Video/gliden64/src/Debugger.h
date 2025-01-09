#ifndef DEBUGGER_H

#include <set>
#include <list>
#include <array>
#include <vector>
#include <memory>
#include "Graphics/Context.h"
#include "Graphics/Parameters.h"
#include "gSP.h"
#include "gDP.h"
#include "Textures.h"

enum TriangleType {
	ttTriangle,
	ttTexrect,
	ttFillrect,
	ttBackground
};

class Debugger
{
public:
	Debugger();
	~Debugger();

	void checkDebugState();

	void addTriangles(const graphics::Context::DrawTriangleParameters & _params);

	void addRects(const graphics::Context::DrawRectParameters & _params);

	bool isDebugMode() const { return m_bDebugMode; }
	bool isCaptureMode() const { return m_bCapture; }

	void draw();

private:
	struct TexInfo {
		f32 scales, scalet;
		const CachedTexture * texture;
		gDPLoadTileInfo texLoadInfo;
	};

	struct Vertex {
		f32 x, y, z, w;
		f32 r, g, b, a;
		f32 s0, t0, s1, t1;
		u32 modify;

		Vertex() = default;

		Vertex(const SPVertex & _v)
			: x(_v.x)
			, y(_v.y)
			, z(_v.z)
			, w(_v.w)
			, r(_v.r)
			, g(_v.g)
			, b(_v.b)
			, a(_v.a)
			, s0(_v.s)
			, t0(_v.t)
			, s1(_v.s)
			, t1(_v.t)
			, modify(_v.modify)
		{}

		Vertex(const RectVertex & _v)
			: x(_v.x)
			, y(_v.y)
			, z(_v.z)
			, w(_v.w)
			, s0(_v.s0)
			, t0(_v.t0)
			, s1(_v.s1)
			, t1(_v.t1)
			, modify(MODIFY_XY | MODIFY_Z)
		{
			r = g = b = a = 0.0f;
		}
	};

	struct TriInfo {
		std::array<Vertex, 3> vertices;
		gDPCombine combine; 	// Combine mode at the time of rendering
		u32 cycle_type;
		gDPInfo::OtherMode otherMode;
		u32	geometryMode;	// geometry mode flags
		u32 frameBufferAddress;
		u32	tri_n;		// Triangle number

		TriangleType type;	// 0-normal, 1-texrect, 2-fillrect

		gSPInfo::Viewport viewport;

		// texture info
		std::array<std::unique_ptr<TexInfo>, 2> tex_info;

		// colors
		gDPInfo::Color fog_color;
		gDPInfo::Color blend_color;
		gDPInfo::Color env_color;
		gDPInfo::FillColor fill_color;
		gDPInfo::PrimColor prim_color;
		f32 primDepthZ, primDepthDeltaZ;
		s32 K4, K5;

		f32 getScreenX(const Vertex & _v) const;
		f32 getScreenY(const Vertex & _v) const;
		f32 getScreenZ(const Vertex & _v) const;
		f32 getModelX(const Vertex & _v) const;
		f32 getModelY(const Vertex & _v) const;
		f32 getModelZ(const Vertex & _v) const;

		bool isInside(long x, long y) const;
	};

	enum class Page {
		general,
		tex1,
		tex2,
		colors,
		blender,
		othermode_l,
		othermode_h,
		texcoords,
		coords,
		texinfo
	};

	enum class TextureMode {
		texture,
		alpha,
		both
	};

	void _fillTriInfo(TriInfo & _info);
	void _addTriangles(const graphics::Context::DrawTriangleParameters & _params);
	void _addTrianglesByElements(const graphics::Context::DrawTriangleParameters & _params);
	void _debugKeys();
	void _drawFrameBuffer(FrameBuffer * _pBuffer);
	void _drawDebugInfo(FrameBuffer * _pBuffer);
	void _setTextureCombiner();
	void _setLineCombiner();
	void _drawTextureFrame(const RectVertex * _rect);
	void _drawTextureCache();

	void _drawGeneral(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawTex(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawColors(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawBlender(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawOthermodeL(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawOthermodeH(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawTexCoords(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawVertexCoords(f32 _ulx, f32 _uly, f32 _yShift);
	void _drawTexture(f32 _ulx, f32 _uly, f32 _lrx, f32 _lry, f32 _yShift);
	void _drawTriangleFrame();
	void _drawMouseCursor();
	void _findSelected();

	typedef std::list<TriInfo> Triangles;
	typedef std::list<const TexInfo*> TexInfos;
	typedef std::set<u32> FrameBufferAddrs;

	Triangles m_triangles;
	Triangles::const_iterator m_triSel;
	const TexInfo * m_pCurTexInfo = nullptr;
	TextureMode m_textureMode = TextureMode::both;

	FrameBufferAddrs m_fbAddrs;
	FrameBufferAddrs::const_iterator m_curFBAddr;

	Page m_curPage = Page::general;
	bool m_bDebugMode = false;
	bool m_bCapture = false;

	long m_clickX = 0;
	long m_clickY = 0;

	u32 m_tmu = 0;
	u32 m_startTexRow[2];
	TexInfos m_texturesToDisplay[2];
	struct {
		u32 row, col;
	} m_selectedTexPos[2];

	const u32 m_cacheViewerRows = 4;
	const u32 m_cacheViewerCols = 16;
};

extern Debugger g_debugger;

#endif // DEBUGGER_H
