#pragma once
#include "Types.h"
#include "GraphicsDrawer.h"

class DisplayWindow
{
public:
	virtual ~DisplayWindow() {}

	void start();
	void stop();
	void restart();
	void swapBuffers();
	void saveScreenshot();
	void saveBufferContent(FrameBuffer * _pBuffer);
	void saveBufferContent(graphics::ObjectHandle _fbo, CachedTexture *_pTexture);
	bool changeWindow();
	bool resizeWindow();
	void closeWindow();
	void setWindowSize(u32 _width, u32 _height);
	void setCaptureScreen(const char * const _strDirectory);
	void setToggleFullscreen() { m_bToggleFullscreen = true; }
	void readScreen(void **_pDest, long *_pWidth, long *_pHeight);
	void readScreen2(void * _dest, int * _width, int * _height, int _front);

	void updateScale();
	f32 getScaleX() const { return m_scaleX; }
	f32 getScaleY() const { return m_scaleY; }
	f32 getAdjustScale() const { return m_adjustScale; }
	u32 getBuffersSwapCount() const { return m_buffersSwapCount; }
	u32 getWidth() const { return m_width; }
	u32 getHeight() const { return m_height; }
	u32 getScreenWidth() const { return m_screenWidth; }
	u32 getScreenHeight() const { return m_screenHeight; }
	u32 getHeightOffset() const { return m_heightOffset; }
	bool isFullscreen() const { return m_bFullscreen; }
	bool isAdjustScreen() const { return m_bAdjustScreen; }
	bool isResizeWindow() const { return m_bResizeWindow; }

	GraphicsDrawer & getDrawer() { return m_drawer; }

	static DisplayWindow & get();

protected:
	DisplayWindow() = default;

	void _setBufferSize();

	bool m_bCaptureScreen = false;
	bool m_bToggleFullscreen = false;
	bool m_bResizeWindow = false;
	bool m_bFullscreen = false;
	bool m_bAdjustScreen = false;

	u32 m_buffersSwapCount = 0;
	u32 m_width = 0;
	u32 m_height = 0;
	u32 m_heightOffset = 0;
	u32 m_screenWidth = 0;
	u32 m_screenHeight = 0;
	u32 m_resizeWidth = 0;
	u32 m_resizeHeight = 0;
	f32 m_scaleX = 0;
	f32 m_scaleY = 0;
	f32 m_adjustScale = 0;

	wchar_t m_strScreenDirectory[PLUGIN_PATH_SIZE];

private:
	GraphicsDrawer m_drawer;

	virtual bool _start() = 0;
	virtual void _stop() = 0;
	virtual void _swapBuffers() = 0;
	virtual void _saveScreenshot() = 0;
	virtual void _saveBufferContent(graphics::ObjectHandle _fbo, CachedTexture *_pTexture) = 0;
	virtual void _changeWindow() = 0;
	virtual bool _resizeWindow() = 0;
	virtual void _readScreen(void **_pDest, long *_pWidth, long *_pHeight) = 0;
	virtual void _readScreen2(void * _dest, int * _width, int * _height, int _front) = 0;
	virtual graphics::ObjectHandle _getDefaultFramebuffer() = 0;
};

inline
DisplayWindow & dwnd()
{
	return DisplayWindow::get();
}
