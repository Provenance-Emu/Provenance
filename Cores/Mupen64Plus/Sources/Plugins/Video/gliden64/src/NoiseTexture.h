#pragma once
#include <array>
#include <vector>
#include <memory>
#include "Types.h"

#define NOISE_TEX_NUM 30

struct CachedTexture;
typedef std::array<std::vector<u8>, NOISE_TEX_NUM> NoiseTexturesData;

class NoiseTexture
{
public:
	NoiseTexture();

	void init();
	void destroy();
	void update();

private:
	void _fillTextureData();

	CachedTexture * m_pTexture[NOISE_TEX_NUM];
	u32 m_DList;
	u32 m_currTex, m_prevTex;
	NoiseTexturesData m_texData;
};

extern NoiseTexture g_noiseTexture;
