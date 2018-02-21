#ifndef TEXTURES_H
#define TEXTURES_H

#include <map>
#include <unordered_map>
#include <list>

#include "CRC.h"
#include "convert.h"
#include "Graphics/ObjectHandle.h"
#include "Graphics/Parameter.h"

typedef u32 (*GetTexelFunc)( u64 *src, u16 x, u16 i, u8 palette );

struct CachedTexture
{
	CachedTexture(graphics::ObjectHandle _name) : name(_name), max_level(0), frameBufferTexture(fbNone), bHDTexture(false) {}

	graphics::ObjectHandle name;
	u32		crc = 0;
//	float	fulS, fulT;
//	WORD	ulS, ulT, lrS, lrT;
	float	offsetS, offsetT;
	u8		maskS, maskT;
	u8		clampS, clampT;
	u8		mirrorS, mirrorT;
	u16		line;
	u16		size;
	u16		format;
	u32		tMem;
	u32		palette;
	u16		width, height;			  // N64 width and height
	u16		clampWidth, clampHeight;  // Size to clamp to
	u16		realWidth, realHeight;	  // Actual texture size
	f32		scaleS, scaleT;			  // Scale to map to 0.0-1.0
	f32		shiftScaleS, shiftScaleT; // Scale to shift
	u32		textureBytes;

	u32		address;
	u8		max_level;
	enum {
		fbNone = 0,
		fbOneSample = 1,
		fbMultiSample = 2
	} frameBufferTexture;
	bool bHDTexture;
};


struct TextureCache
{
	CachedTexture * current[2];

	void init();
	void destroy();
	CachedTexture * addFrameBufferTexture(bool _multisample);
	void addFrameBufferTextureSize(u32 _size) {m_cachedBytes += _size;}
	void removeFrameBufferTexture(CachedTexture * _pTexture);
	void activateTexture(u32 _t, CachedTexture *_pTexture);
	void activateDummy(u32 _t);
	void activateMSDummy(u32 _t);
	void update(u32 _t);

	static TextureCache & get();

private:
	TextureCache()
		: m_pDummy(nullptr)
		, m_pMSDummy(nullptr)
		, m_hits(0)
		, m_misses(0)
		, m_cachedBytes(0)
		, m_curUnpackAlignment(4)
		, m_toggleDumpTex(false)
	{
		current[0] = nullptr;
		current[1] = nullptr;
		CRC_Init();
	}
	TextureCache(const TextureCache &) = delete;

	void _checkCacheSize();
	CachedTexture * _addTexture(u32 _crc32);
	void _load(u32 _tile, CachedTexture *_pTexture);
	bool _loadHiresTexture(u32 _tile, CachedTexture *_pTexture, u64 & _ricecrc);
	void _loadBackground(CachedTexture *pTexture);
	bool _loadHiresBackground(CachedTexture *_pTexture);
	void _loadDepthTexture(CachedTexture * _pTexture, u16* _pDest);
	void _updateBackground();
	void _clear();
	void _initDummyTexture(CachedTexture * _pDummy);
	void _getTextureDestData(CachedTexture& tmptex, u32* pDest, graphics::Parameter glInternalFormat, GetTexelFunc GetTexel, u16* pLine);

	typedef std::list<CachedTexture> Textures;
	typedef std::unordered_map<u32, Textures::iterator> Texture_Locations;
	typedef std::map<graphics::ObjectHandle, CachedTexture> FBTextures;
	Textures m_textures;
	Texture_Locations m_lruTextureLocations;
	FBTextures m_fbTextures;
	CachedTexture * m_pDummy;
	CachedTexture * m_pMSDummy;
	u32 m_hits, m_misses;
	u32 m_cachedBytes;
	s32 m_curUnpackAlignment;
	bool m_toggleDumpTex;
	const size_t m_maxCacheSize = 8000;
};

void getTextureShiftScale(u32 tile, const TextureCache & cache, f32 & shiftScaleS, f32 & shiftScaleT);

inline TextureCache & textureCache()
{
	return TextureCache::get();
}

inline u32 pow2( u32 dim )
{
	u32 i = 1;

	while (i < dim) i <<= 1;

	return i;
}

inline u32 powof( u32 dim )
{
	u32 num = 1;
	u32 i = 0;

	while (num < dim)
	{
		num <<= 1;
		i++;
	}

	return i;
}
#endif
