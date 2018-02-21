#pragma once
#include <Graphics/ColorBufferReader.h>
#include "opengl_CachedFunctions.h"

namespace opengl {

class ColorBufferReaderWithPixelBuffer :
		public graphics::ColorBufferReader
{
public:
	ColorBufferReaderWithPixelBuffer(CachedTexture * _pTexture,
			CachedBindBuffer * _bindBuffer);
	~ColorBufferReaderWithPixelBuffer();

	const u8 * _readPixels(const ReadColorBufferParams& _params, u32& _heightOffset, u32& _stride) override;
	void cleanUp() override;

private:
	void _initBuffers();
	void _destroyBuffers();

	CachedBindBuffer * m_bindBuffer;

	static const int _numPBO = 3;
	GLuint m_PBO[_numPBO];
	u32 m_curIndex;
};

}
