#pragma once
#include <Graphics/ColorBufferReader.h>
#include "opengl_CachedFunctions.h"

namespace opengl {

class ColorBufferReaderWithReadPixels :
		public graphics::ColorBufferReader
{
public:
	ColorBufferReaderWithReadPixels(CachedTexture * _pTexture);
	~ColorBufferReaderWithReadPixels() = default;

	const u8 * _readPixels(const ReadColorBufferParams& _params, u32& _heightOffset, u32& _stride) override;
	void cleanUp() override;
};

}
