#include <Graphics/Context.h>
#include "opengl_ColorBufferReaderWithReadPixels.h"
#include <algorithm>

using namespace graphics;
using namespace opengl;

ColorBufferReaderWithReadPixels::ColorBufferReaderWithReadPixels(CachedTexture *_pTexture)
	: ColorBufferReader(_pTexture)
{

}

const u8 * ColorBufferReaderWithReadPixels::_readPixels(const ReadColorBufferParams& _params, u32& _heightOffset,
	u32& _stride)
{
	GLenum format = GLenum(_params.colorFormat);
	GLenum type = GLenum(_params.colorType);

	// No async pixel buffer copies are supported in this class, this is a last resort fallback
	u8* gpuData = m_pixelData.data();
	glReadPixels(_params.x0, _params.y0, m_pTexture->realWidth, _params.height, format, type, gpuData);

	_heightOffset = 0;
	_stride = m_pTexture->realWidth;

	return gpuData;
}

void ColorBufferReaderWithReadPixels::cleanUp()
{
}
