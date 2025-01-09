#ifndef DepthBufferToRDRAM_H
#define DepthBufferToRDRAM_H

#include <memory>
#include <Graphics/ObjectHandle.h>

namespace graphics {
	class PixelReadBuffer;
}

struct CachedTexture;
struct FrameBuffer;

class DepthBufferToRDRAM
{
public:
	void init();
	void destroy();

	bool copyToRDRAM(u32 _address);
	bool copyChunkToRDRAM(u32 _startAddress);

	static DepthBufferToRDRAM & get();

private:
	DepthBufferToRDRAM();
	~DepthBufferToRDRAM();

	bool _prepareCopy(u32& _startAddress, bool _copyChunk);
	bool _copy(u32 _startAddress, u32 _endAddress);

	// Convert pixel from video memory to N64 depth buffer format.
	static u16 _FloatToUInt16(f32 _z);

	graphics::ObjectHandle m_FBO;
	std::unique_ptr<graphics::PixelReadBuffer> m_pbuf;
	u32 m_frameCount;
	CachedTexture * m_pColorTexture;
	CachedTexture * m_pDepthTexture;
	FrameBuffer * m_pCurFrameBuffer;
};

#endif // DepthBufferToRDRAM_H
