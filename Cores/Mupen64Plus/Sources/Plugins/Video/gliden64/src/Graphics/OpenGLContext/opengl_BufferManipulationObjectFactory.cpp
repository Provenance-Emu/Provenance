#include <assert.h>
#include <Graphics/Parameters.h>
#include "opengl_GLInfo.h"
#include "opengl_CachedFunctions.h"
#include "opengl_Utils.h"
#include "opengl_BufferManipulationObjectFactory.h"

//#define ENABLE_GL_4_5

using namespace opengl;

/*---------------CreateFramebufferObject-------------*/

class GenFramebuffer : public CreateFramebufferObject
{
public:
	graphics::ObjectHandle createFramebuffer() override
	{
		GLuint fbo;
		glGenFramebuffers(1, &fbo);
		return graphics::ObjectHandle(fbo);
	}
};

class CreateFramebuffer : public CreateFramebufferObject
{
public:
	static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_5
		return (_glinfo.majorVersion > 4) || (_glinfo.majorVersion == 4 && _glinfo.minorVersion >= 5);
#else
		return false;
#endif
	}

	graphics::ObjectHandle createFramebuffer() override
	{
		GLuint fbo;
		glCreateFramebuffers(1, &fbo);
		return graphics::ObjectHandle(fbo);
	}
};

/*---------------CreateRenderbuffer-------------*/

class GenRenderbuffer : public CreateRenderbuffer
{
public:
	graphics::ObjectHandle createRenderbuffer() override
	{
		GLuint renderbuffer;
		glGenRenderbuffers(1, &renderbuffer);
		return graphics::ObjectHandle(renderbuffer);
	}
};


/*---------------InitRenderbuffer-------------*/

class RenderbufferStorage : public InitRenderbuffer
{
public:
	RenderbufferStorage(CachedBindRenderbuffer * _bind) : m_bind(_bind) {}
	void initRenderbuffer(const graphics::Context::InitRenderbufferParams & _params) override
	{
		m_bind->bind(_params.target, _params.handle);
		glRenderbufferStorage(GLenum(_params.target), GLenum(_params.format), _params.width, _params.height);
	}

private:
	CachedBindRenderbuffer * m_bind;
};


/*---------------AddFramebufferTarget-------------*/

class AddFramebufferTexture2D : public AddFramebufferRenderTarget
{
public:
	AddFramebufferTexture2D(CachedBindFramebuffer * _bind) : m_bind(_bind) {}

	void addFrameBufferRenderTarget(const graphics::Context::FrameBufferRenderTarget & _params) override
	{
		m_bind->bind(_params.bufferTarget, _params.bufferHandle);
		if (_params.textureTarget == graphics::textureTarget::RENDERBUFFER) {
			glFramebufferRenderbuffer(GLenum(_params.bufferTarget),
				GLenum(_params.attachment),
				GLenum(_params.textureTarget),
				GLuint(_params.textureHandle));
		} else {
			glFramebufferTexture2D(GLenum(_params.bufferTarget),
				GLenum(_params.attachment),
				GLenum(_params.textureTarget),
				GLuint(_params.textureHandle),
				0);
		}
	}

private:
	CachedBindFramebuffer * m_bind;
};

class AddNamedFramebufferTexture : public AddFramebufferRenderTarget
{
public:
	static bool Check(const GLInfo & _glinfo) {
#ifdef ENABLE_GL_4_5
		return (_glinfo.majorVersion > 4) || (_glinfo.majorVersion == 4 && _glinfo.minorVersion >= 5);
#else
		return false;
#endif
	}

	void addFrameBufferRenderTarget(const graphics::Context::FrameBufferRenderTarget & _params) override
	{
		glNamedFramebufferTexture(GLuint(_params.bufferHandle),
			GLenum(_params.attachment),
			GLuint(_params.textureHandle),
			0);
	}
};

/*---------------CreatePixelReadBuffer-------------*/

class PBOReadBuffer : public graphics::PixelReadBuffer
{
public:
	PBOReadBuffer(CachedBindBuffer * _bind, size_t _size)
		: m_bind(_bind)
		, m_size(_size)
	{
		glGenBuffers(1, &m_PBO);
		m_bind->bind(graphics::Parameter(GL_PIXEL_PACK_BUFFER), graphics::ObjectHandle(m_PBO));
		glBufferData(GL_PIXEL_PACK_BUFFER, m_size, nullptr, GL_DYNAMIC_READ);
		m_bind->bind(graphics::Parameter(GL_PIXEL_PACK_BUFFER), graphics::ObjectHandle::null);
	}

	~PBOReadBuffer() {
		glDeleteBuffers(1, &m_PBO);
		m_PBO = 0;
	}

	void readPixels(s32 _x,s32 _y, u32 _width, u32 _height, graphics::Parameter _format, graphics::Parameter _type) override
	{
		glReadPixels(_x, _y, _width, _height, GLenum(_format), GLenum(_type), 0);
	}

	void * getDataRange(u32 _offset, u32 _range) override
	{
		if (_range > m_size)
			_range = static_cast<u32>(m_size);
		return glMapBufferRange(GL_PIXEL_PACK_BUFFER, _offset, _range, GL_MAP_READ_BIT);
	}

	void closeReadBuffer() override
	{
		glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
	}

	void bind() override {
		m_bind->bind(graphics::Parameter(GL_PIXEL_PACK_BUFFER), graphics::ObjectHandle(m_PBO));
	}

	void unbind() override {
		m_bind->bind(graphics::Parameter(GL_PIXEL_PACK_BUFFER), graphics::ObjectHandle::null);
	}

private:
	CachedBindBuffer * m_bind;
	size_t m_size;
	GLuint m_PBO;
};

template<typename T>
class CreatePixelReadBufferT : public CreatePixelReadBuffer
{
public:
	CreatePixelReadBufferT(CachedBindBuffer * _bind)
		: m_bind(_bind) {
	}

	graphics::PixelReadBuffer * createPixelReadBuffer(size_t _sizeInBytes) override
	{
		return new T(m_bind, _sizeInBytes);
	}

private:
	CachedBindBuffer * m_bind;
};

/*---------------BlitFramebuffers-------------*/

class BlitFramebuffersImpl : public BlitFramebuffers
{
public:
	static bool Check(const GLInfo & _glinfo) {
		return !_glinfo.isGLES2;
	}

	BlitFramebuffersImpl(CachedBindFramebuffer * _bind,
		CachedEnable * _enableScissor,
		Renderer _renderer)
		: m_bind(_bind)
		, m_enableScissor(_enableScissor)
		, m_renderer(_renderer) {
	}

	bool blitFramebuffers(const graphics::Context::BlitFramebuffersParams & _params) override
	{
		m_bind->bind(graphics::bufferTarget::READ_FRAMEBUFFER, _params.readBuffer);
		m_bind->bind(graphics::bufferTarget::DRAW_FRAMEBUFFER, _params.drawBuffer);

		const s32 adrenoCoordFix = (m_renderer == Renderer::Adreno) ? 1 : 0;

		m_enableScissor->enable(false);

		glBlitFramebuffer(
			adrenoCoordFix + _params.srcX0, _params.srcY0, _params.srcX1, _params.srcY1,
			adrenoCoordFix + _params.dstX0, _params.dstY0, _params.dstX1, _params.dstY1,
			GLbitfield(_params.mask), GLenum(_params.filter)
		);
		m_enableScissor->enable(true);

		return !Utils::isGLError();
	}

private:
	CachedBindFramebuffer * m_bind;
	CachedEnable * m_enableScissor;
	Renderer m_renderer;
};

class DummyBlitFramebuffers: public BlitFramebuffers
{
public:
	bool blitFramebuffers(const graphics::Context::BlitFramebuffersParams & _params) override
	{
		return false;
	}
};

/*---------------FramebufferTextureFormats-------------*/

struct FramebufferTextureFormatsGLES2 : public graphics::FramebufferTextureFormats
{
	static bool Check(const GLInfo & _glinfo) {
		return _glinfo.isGLES2;
	}

	FramebufferTextureFormatsGLES2(const GLInfo & _glinfo):
		m_glinfo(_glinfo)
	{
		init();
	}

protected:
	void init() override
	{
		monochromeInternalFormat = GL_RGB;
		monochromeFormat = GL_RGB;
		monochromeType = GL_UNSIGNED_SHORT_5_6_5;
		monochromeFormatBytes = 2;

		if (Utils::isExtensionSupported(m_glinfo, "GL_OES_depth_texture")) {
			depthInternalFormat = GL_DEPTH_COMPONENT;
			depthFormatBytes = 4;
		} else {
			depthInternalFormat = GL_DEPTH_COMPONENT16;
			depthFormatBytes = 2;
		}

		depthFormat = GL_DEPTH_COMPONENT;
		depthType = GL_UNSIGNED_INT;

		if (Utils::isExtensionSupported(m_glinfo, "GL_OES_rgb8_rgba8")) {
			colorInternalFormat = GL_RGBA;
			colorFormat = GL_RGBA;
			colorType = GL_UNSIGNED_BYTE;
			colorFormatBytes = 4;
		}
		else {
			colorInternalFormat = GL_RGB;
			colorFormat = GL_RGB;
			colorType = GL_UNSIGNED_SHORT_5_6_5;
			colorFormatBytes = 2;
		}

		noiseInternalFormat = graphics::internalcolorFormat::LUMINANCE;
		noiseFormat = graphics::colorFormat::LUMINANCE;
		noiseType = GL_UNSIGNED_BYTE;
		noiseFormatBytes = 1;
	}

private:
	const GLInfo & m_glinfo;
};

struct FramebufferTextureFormatsGLES3 : public graphics::FramebufferTextureFormats
{
	static bool Check(const GLInfo & _glinfo) {
		return _glinfo.isGLESX && !_glinfo.isGLES2;
	}

	FramebufferTextureFormatsGLES3(const GLInfo & _glinfo):
		m_glinfo(_glinfo)
	{
		init();
	}

protected:
	void init() override
	{
		if (m_glinfo.renderer == Renderer::Adreno530) {
			colorInternalFormat = GL_RGBA32F;
			colorFormat = GL_RGBA;
			colorType = GL_FLOAT;
			colorFormatBytes = 16;
		} else {
			colorInternalFormat = GL_RGBA8;
			colorFormat = GL_RGBA;
			colorType = GL_UNSIGNED_BYTE;
			colorFormatBytes = 4;
		}

		monochromeInternalFormat = GL_R8;
		monochromeFormat = GL_RED;
		monochromeType = GL_UNSIGNED_BYTE;
		monochromeFormatBytes = 1;

		depthInternalFormat = GL_DEPTH_COMPONENT24;
		depthFormat = GL_DEPTH_COMPONENT;
		depthType = GL_UNSIGNED_INT;
		depthFormatBytes = 4;

		depthImageInternalFormat = GL_R32F;
		depthImageFormat = GL_RED;
		depthImageType = GL_FLOAT;
		depthImageFormatBytes = 4;

		lutInternalFormat = GL_R32UI;
		lutFormat = GL_RED_INTEGER;
		lutType = GL_UNSIGNED_INT;
		lutFormatBytes = 4;

		noiseInternalFormat = GL_R8;
		noiseFormat = GL_RED;
		noiseType = GL_UNSIGNED_BYTE;
		noiseFormatBytes = 1;
	}

	const GLInfo & m_glinfo;
};

struct FramebufferTextureFormatsOpenGL : public graphics::FramebufferTextureFormats
{
	static bool Check(const GLInfo & _glinfo) {
		return !_glinfo.isGLESX;
	}

	FramebufferTextureFormatsOpenGL()
	{
		init();
	}

protected:
	void init() override
	{
		colorInternalFormat = GL_RGBA8;
		colorFormat = GL_RGBA;
		colorType = GL_UNSIGNED_BYTE;
		colorFormatBytes = 4;

		monochromeInternalFormat = GL_R8;
		monochromeFormat = GL_RED;
		monochromeType = GL_UNSIGNED_BYTE;
		monochromeFormatBytes = 1;

		depthInternalFormat = GL_DEPTH_COMPONENT24;
		depthFormat = GL_DEPTH_COMPONENT;
		depthType = GL_FLOAT;
		depthFormatBytes = 4;

		depthImageInternalFormat = GL_R32F;
		depthImageFormat = GL_RED;
		depthImageType = GL_FLOAT;
		depthImageFormatBytes = 4;

		lutInternalFormat = GL_R32UI;
		lutFormat = GL_RED_INTEGER;
		lutType = GL_UNSIGNED_INT;
		lutFormatBytes = 4;

		noiseInternalFormat = GL_R8;
		noiseFormat = GL_RED;
		noiseType = GL_UNSIGNED_BYTE;
		noiseFormatBytes = 1;
	}
};

/*---------------BufferManipulationObjectFactory-------------*/

BufferManipulationObjectFactory::BufferManipulationObjectFactory(const GLInfo & _info,
	CachedFunctions & _cachedFunctions)
	: m_glInfo(_info)
	, m_cachedFunctions(_cachedFunctions)
{
}


BufferManipulationObjectFactory::~BufferManipulationObjectFactory()
{
}

CreateFramebufferObject * BufferManipulationObjectFactory::getCreateFramebufferObject() const
{
	if (CreateFramebuffer::Check(m_glInfo))
		return new CreateFramebuffer;

	return new GenFramebuffer;
}

CreateRenderbuffer * BufferManipulationObjectFactory::getCreateRenderbuffer() const
{
	return new GenRenderbuffer;
}

InitRenderbuffer * BufferManipulationObjectFactory::getInitRenderbuffer() const
{
	return new RenderbufferStorage(m_cachedFunctions.getCachedBindRenderbuffer());
}

AddFramebufferRenderTarget * BufferManipulationObjectFactory::getAddFramebufferRenderTarget() const
{
	if (AddNamedFramebufferTexture::Check(m_glInfo))
		return new AddNamedFramebufferTexture;

	return new AddFramebufferTexture2D(m_cachedFunctions.getCachedBindFramebuffer());
}

BlitFramebuffers * BufferManipulationObjectFactory::getBlitFramebuffers() const
{
	if (BlitFramebuffersImpl::Check(m_glInfo))
		return new BlitFramebuffersImpl(m_cachedFunctions.getCachedBindFramebuffer(),
										m_cachedFunctions.getCachedEnable(graphics::enable::SCISSOR_TEST),
										m_glInfo.renderer);

	return new DummyBlitFramebuffers;
}

CreatePixelReadBuffer * BufferManipulationObjectFactory::createPixelReadBuffer() const
{
	if (m_glInfo.isGLES2)
		return nullptr;

	return new CreatePixelReadBufferT<PBOReadBuffer>(m_cachedFunctions.getCachedBindBuffer());
}

graphics::FramebufferTextureFormats * BufferManipulationObjectFactory::getFramebufferTextureFormats() const
{
	if (FramebufferTextureFormatsOpenGL::Check(m_glInfo))
		return new FramebufferTextureFormatsOpenGL;

	if (FramebufferTextureFormatsGLES3::Check(m_glInfo))
		return new FramebufferTextureFormatsGLES3(m_glInfo);

	if (FramebufferTextureFormatsGLES2::Check(m_glInfo))
		return new FramebufferTextureFormatsGLES2(m_glInfo);

	assert(false);
	return nullptr;
}
