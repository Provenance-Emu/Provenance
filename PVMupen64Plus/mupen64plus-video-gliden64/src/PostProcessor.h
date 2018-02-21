#ifndef POST_PROCESSOR_H
#define POST_PROCESSOR_H

#include <memory>
#include "Types.h"
#include "Textures.h"
#include "Graphics/ObjectHandle.h"

namespace graphics {
	class ShaderProgram;
}

struct FrameBuffer;

class PostProcessor {
public:
	void init();
	void destroy();

	FrameBuffer * doGammaCorrection(FrameBuffer * _pBuffer);
	FrameBuffer * doOrientationCorrection(FrameBuffer * _pBuffer);

	static PostProcessor & get();

private:
	PostProcessor();
	PostProcessor(const PostProcessor & _other) = delete;

	void _createResultBuffer(const FrameBuffer * _pMainBuffer);
	void _initGammaCorrection();
	void _destroyGammaCorrection();
	void _initOrientationCorrection();
	void _destroyOrientationCorrection();
	void _preDraw(FrameBuffer * _pBuffer);
	void _postDraw();

	std::unique_ptr<graphics::ShaderProgram> m_gammaCorrectionProgram;
	std::unique_ptr<graphics::ShaderProgram> m_orientationCorrectionProgram;
	std::unique_ptr<FrameBuffer> m_pResultBuffer;
	CachedTexture * m_pTextureOriginal;
};

#endif // POST_PROCESSOR_H
