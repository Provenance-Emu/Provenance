#include "ColorBufferToRDRAM.h"

class ColorBufferToRDRAMStub : public ColorBufferToRDRAM
{
public:
	ColorBufferToRDRAMStub() : ColorBufferToRDRAM() {}
	~ColorBufferToRDRAMStub() {};

private:
	void _init() override {}
	void _initBuffers() override {}
	void _destroyBuffers(void) override {}
	bool _readPixels(GLint _x0, GLint _y0, GLsizei _width, GLsizei _height, u32 _size, bool _sync)  override {}
	void _cleanUp()  override {}
};
