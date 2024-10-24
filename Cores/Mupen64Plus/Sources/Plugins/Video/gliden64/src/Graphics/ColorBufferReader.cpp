
#include "ColorBufferReader.h"
#include "FramebufferTextureFormats.h"
#include "Context.h"
#include "Parameters.h"
#include <algorithm>
#include <cstring>

namespace graphics {

	ColorBufferReader::ColorBufferReader(CachedTexture * _pTexture)
		: m_pTexture(_pTexture)
	{
		m_pixelData.resize(m_pTexture->textureBytes);
		m_tempPixelData.resize(m_pTexture->textureBytes);
	}

	const u8* ColorBufferReader::_convertFloatTextureBuffer(const u8* _gpuData, u32 _width, u32 _height,
		u32 _heightOffset, u32 _stride)
	{
		int bytesToCopy = m_pTexture->realWidth * _height * 16;
		std::copy_n(_gpuData, bytesToCopy, m_tempPixelData.data());
		u8* pixelDataAlloc = m_pixelData.data();
		float* pixelData = reinterpret_cast<float*>(m_tempPixelData.data());
		const u32 colorsPerPixel = 4;
		const u32 widthPixels = _width * colorsPerPixel;
		const u32 stridePixels = _stride * colorsPerPixel;
		
		if (_height * widthPixels  > m_pixelData.size())
			_height = static_cast<u32>(m_pixelData.size()) / widthPixels;

		for (u32 heightIndex = 0; heightIndex < _height; ++heightIndex) {
			for (u32 widthIndex = 0; widthIndex < widthPixels; ++widthIndex) {
				u8& dest = *(pixelDataAlloc + heightIndex*widthPixels + widthIndex);
				float& src = *(pixelData + (heightIndex+_heightOffset)*stridePixels + widthIndex);
				dest = static_cast<u8>(src*255.0);
			}
		}

		return pixelDataAlloc;
	}

	const u8* ColorBufferReader::_convertIntegerTextureBuffer(const u8* _gpuData, u32 _width, u32 _height,
		u32 _heightOffset, u32 _stride, u32 _colorsPerPixel)
	{
		const u32 widthBytes = _width * _colorsPerPixel;
		const u32 strideBytes = _stride * _colorsPerPixel;

		u8* pixelDataAlloc = m_pixelData.data();
		
		if (_height * widthBytes  > m_pixelData.size())
			_height = static_cast<u32>(m_pixelData.size()) / widthBytes;

		for (u32 index = 0; index < _height; ++index) {
			memcpy(pixelDataAlloc + index * widthBytes, _gpuData + ((index + _heightOffset) * strideBytes), widthBytes);
		}

		return pixelDataAlloc;
	}


	const u8 * ColorBufferReader::readPixels(s32 _x0, s32 _y0, u32 _width, u32 _height, u32 _size, bool _sync)
	{
		const FramebufferTextureFormats & fbTexFormat = gfxContext.getFramebufferTextureFormats();

		ReadColorBufferParams params;
		params.x0 = _x0;
		params.y0 = _y0;
		params.width = _width;
		params.height = _height;
		params.sync = _sync;

		if (_size > G_IM_SIZ_8b) {
			params.colorFormat = fbTexFormat.colorFormat;
			params.colorType = fbTexFormat.colorType;
			params.colorFormatBytes = fbTexFormat.colorFormatBytes;
		} else {
			params.colorFormat = fbTexFormat.monochromeFormat;
			params.colorType = fbTexFormat.monochromeType;
			params.colorFormatBytes = fbTexFormat.monochromeFormatBytes;
		}

		u32 heightOffset = 0;
		u32 stride = 0;
		const u8* pixelData = _readPixels(params, heightOffset, stride);

		if (pixelData == nullptr)
			return nullptr;

		if(params.colorType == datatype::FLOAT && _size > G_IM_SIZ_8b) {
			return _convertFloatTextureBuffer(pixelData, params.width, params.height, heightOffset, stride);
		} else {
			return _convertIntegerTextureBuffer(pixelData, params.width, params.height, heightOffset, stride,
												params.colorFormatBytes);
		}
	}
}