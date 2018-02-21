#include <stdio.h>
#include <cstdlib>
#include <Graphics/Context.h>
#include <Graphics/OpenGLContext/GLFunctions.h>
#include <Graphics/OpenGLContext/opengl_Utils.h>
#include <mupenplus/GLideN64_mupenplus.h>
#include <GLideN64.h>
#include <Config.h>
#include <N64.h>
#include <gSP.h>
#include <Log.h>
#include <Revision.h>
#include <FrameBuffer.h>
#include <GLideNUI/GLideNUI.h>
#include <DisplayWindow.h>

#ifdef VC
#include <bcm_host.h>
#endif

class DisplayWindowMupen64plus : public DisplayWindow
{
public:
	DisplayWindowMupen64plus() {}

private:
	void _setAttributes();
	void _getDisplaySize();

	bool _start() override;
	void _stop() override;
	void _swapBuffers() override;
	void _saveScreenshot() override;
	bool _resizeWindow() override;
	void _changeWindow() override;
	void _readScreen(void **_pDest, long *_pWidth, long *_pHeight) override {}
	void _readScreen2(void * _dest, int * _width, int * _height, int _front) override;
};

DisplayWindow & DisplayWindow::get()
{
	static DisplayWindowMupen64plus video;
	return video;
}

void DisplayWindowMupen64plus::_setAttributes()
{
	LOG(LOG_VERBOSE, "[gles2GlideN64]: _setAttributes\n");

	CoreVideo_GL_SetAttribute(M64P_GL_CONTEXT_PROFILE_MASK, M64P_GL_CONTEXT_PROFILE_CORE);
	CoreVideo_GL_SetAttribute(M64P_GL_CONTEXT_MAJOR_VERSION, 3);
	CoreVideo_GL_SetAttribute(M64P_GL_CONTEXT_MINOR_VERSION, 3);

	CoreVideo_GL_SetAttribute(M64P_GL_DOUBLEBUFFER, 1);
	CoreVideo_GL_SetAttribute(M64P_GL_SWAP_CONTROL, config.video.verticalSync);
	CoreVideo_GL_SetAttribute(M64P_GL_BUFFER_SIZE, 32);
	CoreVideo_GL_SetAttribute(M64P_GL_DEPTH_SIZE, 16);
	if (config.video.multisampling > 0 && config.frameBufferEmulation.enable == 0) {
		CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLEBUFFERS, 1);
		if (config.video.multisampling <= 2)
			CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 2);
		else if (config.video.multisampling <= 4)
			CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 4);
		else if (config.video.multisampling <= 8)
			CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 8);
		else
			CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 16);
	}
}

bool DisplayWindowMupen64plus::_start()
{
	CoreVideo_Init();
	_setAttributes();

	m_bFullscreen = config.video.fullscreen > 0;
	m_screenWidth = config.video.windowedWidth;
	m_screenHeight = config.video.windowedHeight;
	_getDisplaySize();
	_setBufferSize();

	printf("(II) Setting video mode %dx%d...\n", m_screenWidth, m_screenHeight);
	const m64p_video_flags flags = M64VIDEOFLAG_SUPPORT_RESIZING;
	if (CoreVideo_SetVideoMode(m_screenWidth, m_screenHeight, 0, m_bFullscreen ? M64VIDEO_FULLSCREEN : M64VIDEO_WINDOWED, flags) != M64ERR_SUCCESS) {
		//printf("(EE) Error setting videomode %dx%d\n", m_screenWidth, m_screenHeight);
		LOG(LOG_ERROR, "[gles2GlideN64]: Error setting videomode %dx%d\n", m_screenWidth, m_screenHeight);
		CoreVideo_Quit();
		return false;
	}
	LOG(LOG_VERBOSE, "[gles2GlideN64]: Create setting videomode %dx%d\n", m_screenWidth, m_screenHeight);

	char caption[128];
# ifdef _DEBUG
	sprintf(caption, "%s debug. Revision %s", pluginName, PLUGIN_REVISION);
# else // _DEBUG
	sprintf(caption, "%s. Revision %s", pluginName, PLUGIN_REVISION);
# endif // _DEBUG
	CoreVideo_SetCaption(caption);

	return true;
}

void DisplayWindowMupen64plus::_stop()
{
	CoreVideo_Quit();
}

void DisplayWindowMupen64plus::_swapBuffers()
{
	// if emulator defined a render callback function, call it before buffer swap
	if (renderCallback != nullptr) {
		gfxContext.resetShaderProgram();
		if (config.frameBufferEmulation.N64DepthCompare == 0) {
			gfxContext.setViewport(0, getHeightOffset(), getScreenWidth(), getScreenHeight());
			gSP.changed |= CHANGED_VIEWPORT;
		}
		gDP.changed |= CHANGED_COMBINE;
		(*renderCallback)((gDP.changed&CHANGED_CPU_FB_WRITE) == 0 ? 1 : 0);
	}
	CoreVideo_GL_SwapBuffers();
}

void DisplayWindowMupen64plus::_saveScreenshot()
{
}

bool DisplayWindowMupen64plus::_resizeWindow()
{
	_setAttributes();

	m_bFullscreen = false;
	m_width = m_screenWidth = m_resizeWidth;
	m_height = m_screenHeight = m_resizeHeight;
	switch (CoreVideo_ResizeWindow(m_screenWidth, m_screenHeight)) 
	{
		case M64ERR_INVALID_STATE: 
			printf("(EE) Error setting videomode %dx%d in fullscreen mode\n", m_screenWidth, m_screenHeight);
			m_width = m_screenWidth = config.video.windowedWidth;
			m_height = m_screenHeight = config.video.windowedHeight;
			break;
		case M64ERR_SUCCESS:
			break;
		default:
			printf("(EE) Error setting videomode %dx%d\n", m_screenWidth, m_screenHeight);
			m_width = m_screenWidth = config.video.windowedWidth;
			m_height = m_screenHeight = config.video.windowedHeight;
			CoreVideo_Quit();
			return false;
	}
	_setBufferSize();
	opengl::Utils::isGLError(); // reset GL error.
	return true;
}

void DisplayWindowMupen64plus::_changeWindow()
{
	CoreVideo_ToggleFullScreen();
}

void DisplayWindowMupen64plus::_getDisplaySize()
{
#ifdef VC
	if( m_bFullscreen ) {
		// Use VC get_display_size function to get the current screen resolution
		u32 fb_width;
		u32 fb_height;
		if (graphics_get_display_size(0 /* LCD */, &fb_width, &fb_height) < 0)
			printf("ERROR: Failed to get display size\n");
		else {
			m_screenWidth = fb_width;
			m_screenHeight = fb_height;
		}
	}
#endif
}

void DisplayWindowMupen64plus::_readScreen2(void * _dest, int * _width, int * _height, int _front)
{
	if (_width == nullptr || _height == nullptr)
		return;

	*_width = m_screenWidth;
	*_height = m_screenHeight;

	if (_dest == nullptr)
		return;

	u8 *pBufferData = (u8*)malloc((*_width)*(*_height) * 4);
	u8 *pDest = (u8*)_dest;

#if !defined(OS_ANDROID) && !defined(OS_IOS)
	GLint oldMode;
	glGetIntegerv(GL_READ_BUFFER, &oldMode);
	if (_front != 0)
		glReadBuffer(GL_FRONT);
	else
		glReadBuffer(GL_BACK);
	glReadPixels(0, m_heightOffset, m_screenWidth, m_screenHeight, GL_RGBA, GL_UNSIGNED_BYTE, pBufferData);
	glReadBuffer(oldMode);
#else
	glReadPixels(0, m_heightOffset, m_screenWidth, m_screenHeight, GL_RGBA, GL_UNSIGNED_BYTE, pBufferData);
#endif

	//Convert RGBA to RGB
	for (s32 y = 0; y < *_height; ++y) {
		u8 *ptr = pBufferData + ((*_width) * 4 * y);
		for (s32 x = 0; x < *_width; ++x) {
			pDest[x * 3] = ptr[0]; // red
			pDest[x * 3 + 1] = ptr[1]; // green
			pDest[x * 3 + 2] = ptr[2]; // blue
			ptr += 4;
		}
		pDest += (*_width) * 3;
	}

	free(pBufferData);
}
