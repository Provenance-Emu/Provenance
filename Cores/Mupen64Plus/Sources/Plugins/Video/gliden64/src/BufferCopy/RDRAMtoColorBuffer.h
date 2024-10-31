#ifndef RDRAMtoColorBuffer_H
#define RDRAMtoColorBuffer_H

#include <vector>
#include <memory>
#include <Graphics/ObjectHandle.h>
#include <FrameBuffer.h>

struct CachedTexture;
struct FrameBuffer;

class RDRAMtoColorBuffer
{
public:
	void init();
	void destroy();

	void addAddress(u32 _address, u32 _size);

	void copyFromRDRAM(u32 _address, bool _bCFB);
	void copyFromRDRAM(FrameBuffer * _pBuffer);

	static RDRAMtoColorBuffer & get();

private:
	RDRAMtoColorBuffer();
	RDRAMtoColorBuffer(const RDRAMtoColorBuffer &) = delete;

	void _copyFromRDRAM(u32 _height, bool _fullAlpha);
	void reset();

	class Cleaner
	{
	public:
		Cleaner(RDRAMtoColorBuffer * _p) : m_p(_p), m_pCurrentBuffer(frameBufferList().getCurrent()) {}
		~Cleaner()
		{
			m_p->reset();
			frameBufferList().setCurrent(m_pCurrentBuffer);
		}
	private:
		RDRAMtoColorBuffer * m_p;
		FrameBuffer * m_pCurrentBuffer;
	};

	FrameBuffer * m_pCurBuffer;
	CachedTexture * m_pTexture;
	std::vector<u32> m_vecAddress;
	u8* m_pbuf;
};

#endif // RDRAMtoColorBuffer_H
