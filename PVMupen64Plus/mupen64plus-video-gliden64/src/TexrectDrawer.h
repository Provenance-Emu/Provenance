#ifndef TEXRECTDRAWER_H
#define TEXRECTDRAWER_H

#include <memory>
#include <vector>
#include "gDP.h"
#include "Graphics/ObjectHandle.h"
#include "Graphics/ShaderProgram.h"

struct CachedTexture;
struct FrameBuffer;

class TexrectDrawer
{
public:
	TexrectDrawer();

	void init();
	void destroy();
	void add();
	bool draw();
	bool isEmpty();
private:
	void _setViewport() const;

	u32 m_numRects;
	u64 m_otherMode;
	u64 m_mux;
	f32 m_ulx, m_lrx, m_uly, m_lry, m_Z;
	f32 m_max_lrx, m_max_lry;
	f32 m_stepY;
	f32 m_stepX;
	graphics::ObjectHandle m_FBO;
	gDPScissor m_scissor;
	CachedTexture * m_pTexture;
	FrameBuffer * m_pBuffer;
	std::unique_ptr<graphics::TexrectDrawerShaderProgram> m_programTex;
	std::unique_ptr<graphics::ShaderProgram> m_programClear;

	struct RectCoords {
		f32 x, y;
	};
	std::vector<RectCoords> m_vecRectCoords;
};

#endif // TEXRECTDRAWER_H
