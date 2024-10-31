#pragma once

struct CachedTexture;

class ZlutTexture
{
public:
	ZlutTexture();

	void init();
	void destroy();

private:
	CachedTexture * m_pTexture;
};

extern ZlutTexture g_zlutTexture;
