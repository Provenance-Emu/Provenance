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

/*---------------CreatePixelWriteBuffer-------------*/

class PBOWriteBuffer : public graphics::PixelWriteBuffer
{
public:
	PBOWriteBuffer(CachedBindBuffer * _bind, size_t _size)
		: m_bind(_bind)
		, m_size(_size)
	{
		glGenBuffers(1, &m_PBO);
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle(m_PBO));
		glBufferData(GL_PIXEL_UNPACK_BUFFER, m_size, nullptr, GL_DYNAMIC_DRAW);
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle::null);
	}

	~PBOWriteBuffer() {
		glDeleteBuffers(1, &m_PBO);
		m_PBO = 0;
	}

	void * getWriteBuffer(size_t _size) override
	{
		if (_size > m_size)
			_size = m_size;
		return glMapBufferRange(GL_PIXEL_UNPACK_BUFFER, 0, _size, GL_MAP_WRITE_BIT | GL_MAP_UNSYNCHRONIZED_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
	}

	void closeWriteBuffer() override
	{
		glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);
	}

	void * getData() override {
		return nullptr;
	}

	void bind() override {
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle(m_PBO));
	}

	void unbind() override {
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle::null);
	}

private:
	CachedBindBuffer * m_bind;
	size_t m_size;
	GLuint m_PBO;
};

class PersistentWriteBuffer : public graphics::PixelWriteBuffer
{
public:
	PersistentWriteBuffer(CachedBindBuffer * _bind, size_t _size)
		: m_bind(_bind)
		, m_size(_size)
	{
		glGenBuffers(1, &m_PBO);
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle(m_PBO));
		glBufferStorage(GL_PIXEL_UNPACK_BUFFER, m_size * 32, nullptr, m_bufAccessBits);
		m_bufferData = glMapBufferRange(GL_PIXEL_UNPACK_BUFFER, 0, m_size * 32, m_bufMapBits);
		m_bufferOffset = 0;
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle::null);
	}

	~PersistentWriteBuffer() {
		glDeleteBuffers(1, &m_PBO);
		m_PBO = 0;
	}

	void * getWriteBuffer(size_t _size) override
	{
		if (_size > m_size)
			_size = m_size;
		if (m_bufferOffset + _size > m_size * 32)
			m_bufferOffset = 0;
		return (char*)m_bufferData + m_bufferOffset;
	}

	void closeWriteBuffer() override
	{
#ifdef GL_DEBUG
		glFlushMappedBufferRange(GL_PIXEL_UNPACK_BUFFER, m_bufferOffset, m_size);
#endif
		m_bufferOffset += m_size;
	}

	void * getData() override {
		return (char*)nullptr + m_bufferOffset - m_size;
	}

	void bind() override {
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle(m_PBO));
	}

	void unbind() override {
		m_bind->bind(graphics::Parameter(GL_PIXEL_UNPACK_BUFFER), graphics::ObjectHandle::null);
	}

private:
	CachedBindBuffer * m_bind;
	size_t m_size;
	void* m_bufferData;
	u32 m_bufferOffset;
	GLuint m_PBO;
#ifndef GL_DEBUG
	GLbitfield m_bufAccessBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
	GLbitfield m_bufMapBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
#else
	GLbitfield m_bufAccessBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT;
	GLbitfield m_bufMapBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_FLUSH_EXPLICIT_BIT;
#endif
};

class MemoryWriteBuffer : public graphics::PixelWriteBuffer
{
public:
	MemoryWriteBuffer(CachedBindBuffer * _bind, size_t _size)
		: m_size(_size)
		, m_pData(new GLubyte[_size])
	{
	}

	~MemoryWriteBuffer() {
	}

	void * getWriteBuffer(size_t _size) override
	{
		return m_pData.get();
	}

	void closeWriteBuffer() override
	{
	}

	void * getData() override {
		return m_pData.get();
	}

	void bind() override {
	}

	void unbind() override {
	}

private:
	size_t m_size;
	std::unique_ptr<GLubyte[]> m_pData;
};

template<typename T>
class CreatePixelWriteBufferT : public CreatePixelWriteBuffer
{
public:
	CreatePixelWriteBufferT(CachedBindBuffer * _bind)
		: m_bind(_bind) {
	}

	graphics::PixelWriteBuffer * createPixelWriteBuffer(size_t _sizeInBytes) override
	{
		return new T(m_bind, _sizeInBytes);
	}

private:
	CachedBindBuffer * m_bind;
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
			_range = m_size;
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

CreatePixelWriteBuffer * BufferManipulationObjectFactory::createPixelWriteBuffer() const
{
	if (m_glInfo.isGLES2)
		return new CreatePixelWriteBufferT<MemoryWriteBuffer>(nullptr);
	if (m_glInfo.bufferStorage)
		return new CreatePixelWriteBufferT<PersistentWriteBuffer>(m_cachedFunctions.getCachedBindBuffer());

	return new CreatePixelWriteBufferT<PBOWriteBuffer>(m_cachedFunctions.getCachedBindBuffer());
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
