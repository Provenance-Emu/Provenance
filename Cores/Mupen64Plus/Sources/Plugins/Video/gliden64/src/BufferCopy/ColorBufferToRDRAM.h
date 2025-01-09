#ifndef ColorBufferToRDRAM_H
#define ColorBufferToRDRAM_H

#include <memory>
#include <array>
#include <vector>
#include <Graphics/ObjectHandle.h>

namespace graphics {
	class ColorBufferReader;
}

struct CachedTexture;
struct FrameBuffer;

class ColorBufferToRDRAM
{
public:
	void init();
	void destroy();

	void copyToRDRAM(u32 _address, bool _sync);
	void copyChunkToRDRAM(u32 _startAddress);

	static ColorBufferToRDRAM & get();

private:
	ColorBufferToRDRAM();
	ColorBufferToRDRAM(const ColorBufferToRDRAM &) = delete;
	virtual ~ColorBufferToRDRAM();

	CachedTexture * m_pTexture;

	union RGBA {
		struct {
			u8 r, g, b, a;
		};
		u32 raw;
	};

	void _initFBTexture(void);

	void _destroyFBTexure(void);

	bool _prepareCopy(u32& _startAddress);

	void _copy(u32 _startAddress, u32 _endAddress, bool _sync);

	u32 _getRealWidth(u32 _viWidth);

	// Convert pixel from video memory to N64 buffer format.
	static u8 _RGBAtoR8(u8 _c);
	static u16 _RGBAtoRGBA16(u32 _c);
	static u32 _RGBAtoRGBA32(u32 _c);

	graphics::ObjectHandle m_FBO;
	FrameBuffer * m_pCurFrameBuffer;
	u32 m_frameCount;
	u32 m_startAddress;

	u32 m_lastBufferWidth;

	std::array<u32, 3> m_allowedRealWidths;
	std::unique_ptr<graphics::ColorBufferReader> m_bufferReader;
};

void copyWhiteToRDRAM(FrameBuffer * _pBuffer);

#endif // ColorBufferToRDRAM
