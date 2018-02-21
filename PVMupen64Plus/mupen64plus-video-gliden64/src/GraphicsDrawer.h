#pragma once
#include <memory>
#include <array>
#include <vector>
#include <list>
#include <chrono>
#include <string>
#include "gSP.h"
#include "TexrectDrawer.h"
#include "Graphics/ObjectHandle.h"
#include "Graphics/Parameter.h"

namespace graphics {
	class CombinerProgram;
}

struct CachedTexture;
struct FrameBuffer;

#define VERTBUFF_SIZE 256U
#define ELEMBUFF_SIZE 1024U

enum class DrawingState
{
	Non = 0,
	Line = 1,
	Triangle = 2,
	Rect = 3,
	TexRect = 4,
};

struct RectVertex
{
	float x, y, z, w;
	float s0, t0, s1, t1;
};

typedef std::chrono::milliseconds Milliseconds;

class GraphicsDrawer
{
public:
	void addTriangle(int _v0, int _v1, int _v2);

	void drawTriangles();

	void drawScreenSpaceTriangle(u32 _numVtx);

	void drawDMATriangles(u32 _numVtx);

	void drawLine(int _v0, int _v1, float _width);

	void drawRect(int _ulx, int _uly, int _lrx, int _lry);

	struct TexturedRectParams
	{
		float ulx, uly, lrx, lry;
		float dsdx, dtdy;
		s16 s, t;
		bool flip, forceAjustScale, texrectCmd;
		const FrameBuffer * pBuffer;
		TexturedRectParams(float _ulx, float _uly, float _lrx, float _lry,
			float _dsdx, float _dtdy,
			s16 _s, s16 _t,
			bool _flip, bool _forceAjustScale, bool _texrectCmd,
			const FrameBuffer * _pBuffer
			) :
			ulx(_ulx), uly(_uly), lrx(_lrx), lry(_lry),
			dsdx(_dsdx), dtdy(_dtdy),
			s(_s), t(_t),
			flip(_flip), forceAjustScale(_forceAjustScale), texrectCmd(_texrectCmd),
			pBuffer(_pBuffer)
		{}
	private:
		friend class GraphicsDrawer;
		TexturedRectParams() :
			ulx(0), uly(0), lrx(0), lry(0)
		{};
	};

	void correctTexturedRectParams(TexturedRectParams & _params);

	void drawTexturedRect(const TexturedRectParams & _params);

	struct CopyRectParams
	{
		s32 srcX0 = 0;
		s32 srcY0 = 0;
		s32 srcX1;
		s32 srcY1;
		u32 srcWidth;
		u32 srcHeight;
		s32 dstX0 = 0;
		s32 dstY0 = 0;
		s32 dstX1;
		s32 dstY1;
		u32 dstWidth;
		u32 dstHeight;
		bool invertX = false;
		bool invertY = false;
		typedef std::array<CachedTexture *, 2> Textures;
		Textures tex = Textures{ { nullptr, nullptr } };
		graphics::CombinerProgram * combiner = nullptr;
		graphics::TextureParam filter;
	};

	void copyTexturedRect(const CopyRectParams & _params);

	struct BlitOrCopyRectParams : public CopyRectParams
	{
		graphics::ObjectHandle readBuffer;
		graphics::ObjectHandle drawBuffer;
		graphics::BlitMaskParam mask;
	};

	void blitOrCopyTexturedRect(const BlitOrCopyRectParams & _params);

	void drawText(const char *_pText, float x, float y);

	void drawOSD();

	void showMessage(std::string _message, Milliseconds _interval);

	void clearDepthBuffer(u32 _ulx, u32 _uly, u32 _lrx, u32 _lry);

	void clearColorBuffer(float * _pColor);

	int getTrianglesCount() const { return triangles.num; }

	bool isClipped(s32 _v0, s32 _v1, s32 _v2) const
	{
		return (triangles.vertices[_v0].clip & triangles.vertices[_v1].clip & triangles.vertices[_v2].clip) != 0;
	}

	bool isImageTexturesSupported() const { return m_bImageTexture; }

	SPVertex & getVertex(u32 _v) { return triangles.vertices[_v]; }

	SPVertex * getVertexPtr(u32 _v) { return triangles.vertices.data() + _v; }

	void setDMAVerticesSize(u32 _size) { if (m_dmaVertices.size() < _size) m_dmaVertices.resize(_size); }

	SPVertex * getDMAVerticesData() { return m_dmaVertices.data(); }

	SPVertex & getCurrentDMAVertex();
	size_t getDMAVerticesCount() const { return m_dmaVerticesNum; }

	void updateScissor(FrameBuffer * _pBuffer) const;

	DrawingState getDrawingState() const { return m_drawingState; }

	void dropRenderState() { m_drawingState = DrawingState::Non; }

	void flush() { m_texrectDrawer.draw(); }

private:
	friend class DisplayWindow;
	friend TexrectDrawer;

	GraphicsDrawer();
	~GraphicsDrawer();

	GraphicsDrawer(const GraphicsDrawer &) = delete;

	void _initStates();
	void _initData();
	void _destroyData();

	void _setSpecialTexrect() const;

	void _setBlendMode() const;
	void _updateCullFace() const;
	void _updateViewport() const;
	void _updateScreenCoordsViewport() const;
	void _updateDepthUpdate() const;
	void _updateDepthCompare() const;
	void _updateTextures() const;
	void _updateStates(DrawingState _drawingState) const;
	void _prepareDrawTriangle();
	bool _canDraw() const;
	void _drawThickLine(int _v0, int _v1, float _width);

	void _drawOSD(const char *_pText, float _x, float & _y);

	typedef std::list<std::string> OSDMessages;
	void _removeOSDMessage(OSDMessages::iterator _iter, Milliseconds _interval);

	DrawingState m_drawingState;
	TexturedRectParams m_texrectParams;

	struct {
		std::array<SPVertex, VERTBUFF_SIZE> vertices;
		std::array<u8, ELEMBUFF_SIZE> elements;
		u32 num = 0;
		int maxElement = 0;
	} triangles;

	std::vector<SPVertex> m_dmaVertices;
	size_t m_dmaVerticesNum;

	RectVertex m_rect[4];

	u32 m_modifyVertices;
	f32 m_maxLineWidth;
	bool m_bImageTexture;
	bool m_bFlatColors;
	TexrectDrawer m_texrectDrawer;
	OSDMessages m_osdMessages;
};
