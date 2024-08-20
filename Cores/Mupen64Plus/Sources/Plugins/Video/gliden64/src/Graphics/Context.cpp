#include "Context.h"
#include "OpenGLContext/opengl_ContextImpl.h"

using namespace graphics;

Context gfxContext;

bool Context::Multisampling = false;
bool Context::BlitFramebuffer = false;
bool Context::WeakBlitFramebuffer = false;
bool Context::DepthFramebufferTextures = false;
bool Context::ShaderProgramBinary = false;
bool Context::ImageTextures = false;
bool Context::IntegerTextures = false;
bool Context::ClipControl = false;
bool Context::FramebufferFetch = false;
bool Context::TextureBarrier = false;

Context::Context() {}

Context::~Context() {
	m_impl.reset();
}


void Context::init()
{
	m_impl.reset(new opengl::ContextImpl);
	m_impl->init();
	m_fbTexFormats.reset(m_impl->getFramebufferTextureFormats());
	Multisampling = m_impl->isSupported(SpecialFeatures::Multisampling);
	BlitFramebuffer = m_impl->isSupported(SpecialFeatures::BlitFramebuffer);
	WeakBlitFramebuffer = m_impl->isSupported(SpecialFeatures::WeakBlitFramebuffer);
	DepthFramebufferTextures = m_impl->isSupported(SpecialFeatures::DepthFramebufferTextures);
	ShaderProgramBinary = m_impl->isSupported(SpecialFeatures::ShaderProgramBinary);
	ImageTextures = m_impl->isSupported(SpecialFeatures::ImageTextures);
	IntegerTextures = m_impl->isSupported(SpecialFeatures::IntegerTextures);
	ClipControl = m_impl->isSupported(SpecialFeatures::ClipControl);
	FramebufferFetch = m_impl->isSupported(SpecialFeatures::FramebufferFetch);
	TextureBarrier = m_impl->isSupported(SpecialFeatures::TextureBarrier);
}

void Context::destroy()
{
	m_impl->destroy();
	m_impl.reset();
}

void Context::setClampMode(ClampMode _mode)
{
	m_impl->setClampMode(_mode);
}

ClampMode Context::getClampMode()
{
	return m_impl->getClampMode();
}

void Context::enable(EnableParam _parameter, bool _enable)
{
	m_impl->enable(_parameter, _enable);
}

u32 Context::isEnabled(EnableParam _parameter)
{
	return m_impl->isEnabled(_parameter);
}

void Context::cullFace(CullModeParam _parameter)
{
	m_impl->cullFace(_parameter);
}

void Context::enableDepthWrite(bool _enable)
{
	m_impl->enableDepthWrite(_enable);
}

void Context::setDepthCompare(CompareParam _mode)
{
	m_impl->setDepthCompare(_mode);
}

void Context::setViewport(s32 _x, s32 _y, s32 _width, s32 _height)
{
	m_impl->setViewport(_x, _y, _width, _height);
}

void Context::setScissor(s32 _x, s32 _y, s32 _width, s32 _height)
{
	m_impl->setScissor(_x, _y, _width, _height);
}

void Context::setBlending(BlendParam _sfactor, BlendParam _dfactor)
{
	m_impl->setBlending(_sfactor, _dfactor);
}

void Context::setBlendColor(f32 _red, f32 _green, f32 _blue, f32 _alpha)
{
	m_impl->setBlendColor(_red, _green, _blue, _alpha);
}

void Context::clearColorBuffer(f32 _red, f32 _green, f32 _blue, f32 _alpha)
{
	m_impl->clearColorBuffer(_red, _green, _blue, _alpha);
}

void Context::clearDepthBuffer()
{
	m_impl->clearDepthBuffer();
}

void Context::setPolygonOffset(f32 _factor, f32 _units)
{
	m_impl->setPolygonOffset(_factor, _units);
}

ObjectHandle Context::createTexture(Parameter _target)
{
	return m_impl->createTexture(_target);
}

void Context::deleteTexture(ObjectHandle _name)
{
	m_impl->deleteTexture(_name);
}

void Context::init2DTexture(const InitTextureParams & _params)
{
	m_impl->init2DTexture(_params);
}

void Context::update2DTexture(const UpdateTextureDataParams & _params)
{
	m_impl->update2DTexture(_params);
}

void Context::setTextureParameters(const TexParameters & _parameters)
{
	m_impl->setTextureParameters(_parameters);
}

void Context::bindTexture(const BindTextureParameters & _params)
{
	m_impl->bindTexture(_params);
}

void Context::setTextureUnpackAlignment(s32 _param)
{
	m_impl->setTextureUnpackAlignment(_param);
}

s32 Context::getTextureUnpackAlignment() const
{
	return m_impl->getTextureUnpackAlignment();
}

s32 Context::getMaxTextureSize() const
{
	return m_impl->getMaxTextureSize();
}

void Context::bindImageTexture(const BindImageTextureParameters & _params)
{
	m_impl->bindImageTexture(_params);
}

u32 Context::convertInternalTextureFormat(u32 _format) const
{
	return m_impl->convertInternalTextureFormat(_format);
}

void Context::textureBarrier()
{
	m_impl->textureBarrier();
}

/*---------------Framebuffer-------------*/

const FramebufferTextureFormats & Context::getFramebufferTextureFormats()
{
	return *m_fbTexFormats.get();
}

ObjectHandle Context::createFramebuffer()
{
	return m_impl->createFramebuffer();
}

void Context::deleteFramebuffer(ObjectHandle _name)
{
	m_impl->deleteFramebuffer(_name);
}

void Context::bindFramebuffer(BufferTargetParam _target, ObjectHandle _name)
{
	m_impl->bindFramebuffer(_target, _name);
}

ObjectHandle Context::createRenderbuffer()
{
	return m_impl->createRenderbuffer();
}

void Context::initRenderbuffer(const InitRenderbufferParams & _params)
{
	m_impl->initRenderbuffer(_params);
}

void Context::addFrameBufferRenderTarget(const FrameBufferRenderTarget & _params)
{
	m_impl->addFrameBufferRenderTarget(_params);
}

bool Context::blitFramebuffers(const BlitFramebuffersParams & _params)
{
	return m_impl->blitFramebuffers(_params);
}

void Context::setDrawBuffers(u32 _num)
{
	m_impl->setDrawBuffers(_num);
}

PixelReadBuffer * Context::createPixelReadBuffer(size_t _sizeInBytes)
{
	return m_impl->createPixelReadBuffer(_sizeInBytes);
}

ColorBufferReader * Context::createColorBufferReader(CachedTexture * _pTexture)
{
	return m_impl->createColorBufferReader(_pTexture);
}

/*---------------Shaders-------------*/

bool Context::isCombinerProgramBuilderObsolete()
{
	return m_impl->isCombinerProgramBuilderObsolete();

}

void Context::resetCombinerProgramBuilder()
{
	m_impl->resetCombinerProgramBuilder();
}

CombinerProgram * Context::createCombinerProgram(Combiner & _color, Combiner & _alpha, const CombinerKey & _key)
{
	return m_impl->createCombinerProgram(_color, _alpha, _key);
}

bool Context::saveShadersStorage(const Combiners & _combiners)
{
	return m_impl->saveShadersStorage(_combiners);
}

bool Context::loadShadersStorage(Combiners & _combiners)
{
	return m_impl->loadShadersStorage(_combiners);
}

ShaderProgram * Context::createDepthFogShader()
{
	return m_impl->createDepthFogShader();
}

TexrectDrawerShaderProgram * Context::createTexrectDrawerDrawShader()
{
	return m_impl->createTexrectDrawerDrawShader();
}

ShaderProgram * Context::createTexrectDrawerClearShader()
{
	return m_impl->createTexrectDrawerClearShader();
}

ShaderProgram * Context::createTexrectCopyShader()
{
	return m_impl->createTexrectCopyShader();
}

ShaderProgram * Context::createGammaCorrectionShader()
{
	return m_impl->createGammaCorrectionShader();
}

ShaderProgram * Context::createOrientationCorrectionShader()
{
	return m_impl->createOrientationCorrectionShader();
}

ShaderProgram * Context::createFXAAShader()
{
	return m_impl->createFXAAShader();
}

TextDrawerShaderProgram * Context::createTextDrawerShader()
{
	return m_impl->createTextDrawerShader();
}

void Context::resetShaderProgram()
{
	m_impl->resetShaderProgram();
}

void Context::drawTriangles(const DrawTriangleParameters & _params)
{
	m_impl->drawTriangles(_params);
}

void Context::drawRects(const DrawRectParameters & _params)
{
	m_impl->drawRects(_params);
}

void Context::drawLine(f32 _width, SPVertex * _vertices)
{
	m_impl->drawLine(_width, _vertices);
}

f32 Context::getMaxLineWidth()
{
	return m_impl->getMaxLineWidth();
}

bool Context::isError() const
{
	return m_impl->isError();
}

bool Context::isFramebufferError() const
{
	return m_impl->isFramebufferError();
}
