#pragma once
#include <vector>
#include <Types.h>
#include <Textures.h>

namespace graphics {

class ColorBufferReader
{
public:
	ColorBufferReader(CachedTexture * _pTexture);
	virtual ~ColorBufferReader() = default;

	virtual const u8 * readPixels(s32 _x0, s32 _y0, u32 _width, u32 _height, u32 _size, bool _sync);
	virtual void cleanUp() = 0;

protected:
	struct ReadColorBufferParams {
		s32 x0;
		s32 y0;
		u32 width;
		u32 height;
		bool sync;
		ColorFormatParam colorFormat;
		DatatypeParam colorType;
		u32 colorFormatBytes;
	};

	CachedTexture * m_pTexture;
	std::vector<u8> m_pixelData;
	std::vector<u8> m_tempPixelData;

private:
	const u8* _convertFloatTextureBuffer(const u8* _gpuData, u32 _width, u32 _height, u32 _heightOffset, u32 _stride);
	const u8* _convertIntegerTextureBuffer(const u8* _gpuData, u32 _width, u32 _height,u32 _heightOffset, u32 _stride, u32 _colorsPerPixel);
	virtual const u8 * _readPixels(const ReadColorBufferParams& _params, u32& _heightOffset, u32& _stride) = 0;
};

}
