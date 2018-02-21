#pragma once
#include <memory>

namespace graphics {
	class PixelWriteBuffer;
}

struct CachedTexture;

class PaletteTexture
{
public:
	PaletteTexture();

	void init();
	void destroy();
	void update();

private:
	CachedTexture * m_pTexture;
	std::unique_ptr<graphics::PixelWriteBuffer> m_pbuf;
	u32 m_paletteCRC256;
};

extern PaletteTexture g_paletteTexture;
