#include <stdarg.h>
#include <string.h>
#include <cstdlib>
#include "GLideNHQ/Ext_TxFilter.h"
#include <Graphics/Context.h>
#include <Graphics/Parameters.h>

#include "FrameBuffer.h"
#include "DisplayWindow.h"
#include "DisplayLoadProgress.h"

void displayLoadProgress(const wchar_t *format, ...)
{
	va_list args;
	wchar_t wbuf[INFO_BUF];
	char buf[INFO_BUF];

	// process input
#ifdef OS_ANDROID
	const u32 bufSize = 2048;
	char cbuf[bufSize];
	char fmt[bufSize];
	wcstombs(fmt, format, bufSize);
	va_start(args, format);
	vsprintf(cbuf, fmt, args);
	va_end(args);
	mbstowcs(wbuf, cbuf, INFO_BUF);
#else
	va_start(args, format);
	vswprintf(wbuf, INFO_BUF, format, args);
	va_end(args);
#endif

	// XXX: convert to multibyte
	wcstombs(buf, wbuf, INFO_BUF);

	FrameBuffer* pBuffer = frameBufferList().getCurrent();
	if (pBuffer != nullptr)
		gfxContext.bindFramebuffer(graphics::bufferTarget::DRAW_FRAMEBUFFER, graphics::ObjectHandle::defaultFramebuffer);

	GraphicsDrawer & drawer = dwnd().getDrawer();
	drawer.clearColorBuffer(nullptr);
	if (strlen(buf) > 0)
		drawer.drawText(buf, -0.9f, 0);
	dwnd().swapBuffers();

	if (pBuffer != nullptr)
		gfxContext.bindFramebuffer(graphics::bufferTarget::DRAW_FRAMEBUFFER, pBuffer->m_FBO);
}
