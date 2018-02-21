#ifndef RDRAMtoColorBuffer_H
#define RDRAMtoColorBuffer_H

#include <vector>
#include <memory>
#include <Graphics/ObjectHandle.h>
#include <FrameBuffer.h>

namespace graphics {
	class PixelWriteBuffer;
}

struct CachedTexture;
struct FrameBuffer;

class RDRAMtoColorBuffer
{
public:
	void init();
	void destroy();

	void addAddress(u32 _address, u32 _size);
	void copyFromRDRAM(u32 _address, bool _bCFB);

	static RDRAMtoColorBuffer & get();

private:
	RDRAMtoColorBuffer();
	RDRAMtoColorBuffer(const RDRAMtoColorBuffer &) = delete;

	void reset();

	class Cleaner
	{
	public:
		Cleaner(RDRAMtoColorBuffer * _p) : m_p(_p), m_pCureentBuffer(frameBufferList().getCurrent()) {}
		~Cleaner()
		{
			m_p->reset();
			frameBufferList().setCurrent(m_pCureentBuffer);
		}
	private:
		RDRAMtoColorBuffer * m_p;
		FrameBuffer * m_pCureentBuffer;
	};

	FrameBuffer * m_pCurBuffer;
	CachedTexture * m_pTexture;
	std::vector<u32> m_vecAddress;
	std::unique_ptr<graphics::PixelWriteBuffer> m_pbuf;
};

#endif // RDRAMtoColorBuffer_H
