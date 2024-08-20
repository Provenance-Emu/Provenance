#pragma once
#include <memory>

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
	u8* m_pbuf;
	u32 m_paletteCRC256;
};

extern PaletteTexture g_paletteTexture;
