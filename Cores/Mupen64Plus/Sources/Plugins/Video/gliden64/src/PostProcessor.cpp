#include <assert.h>

#include "N64.h"
#include "gSP.h"
#include "PostProcessor.h"
#include "FrameBuffer.h"
#include "Config.h"

#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include "DisplayWindow.h"

using namespace graphics;

PostProcessor::PostProcessor()
	: m_pTextureOriginal(nullptr)
{}

void PostProcessor::_createResultBuffer(const FrameBuffer * _pMainBuffer)
{
	m_pResultBuffer.reset(new FrameBuffer());
	m_pResultBuffer->m_width = _pMainBuffer->m_width;
	m_pResultBuffer->m_height = _pMainBuffer->m_height;
	m_pResultBuffer->m_scale = _pMainBuffer->m_scale;

	const CachedTexture * pMainTexture = _pMainBuffer->m_pTexture;
	CachedTexture * pTexture = m_pResultBuffer->m_pTexture;
	pTexture->format = G_IM_FMT_RGBA;
	pTexture->clampS = 1;
	pTexture->clampT = 1;
	pTexture->frameBufferTexture = CachedTexture::fbOneSample;
	pTexture->maskS = 0;
	pTexture->maskT = 0;
	pTexture->mirrorS = 0;
	pTexture->mirrorT = 0;
	pTexture->realWidth = pMainTexture->realWidth;
	pTexture->realHeight = pMainTexture->realHeight;
	pTexture->textureBytes = pTexture->realWidth * pTexture->realHeight * 4;

	Context::InitTextureParams initParams;
	initParams.handle = pTexture->name;
	initParams.width = pTexture->realWidth;
	initParams.height = pTexture->realHeight;
	initParams.internalFormat = gfxContext.convertInternalTextureFormat(u32(internalcolorFormat::RGBA8));
	initParams.format = colorFormat::RGBA;
	initParams.dataType = datatype::UNSIGNED_BYTE;
	gfxContext.init2DTexture(initParams);

	Context::TexParameters setParams;
	setParams.handle = pTexture->name;
	setParams.target = textureTarget::TEXTURE_2D;
	setParams.minFilter = textureParameters::FILTER_NEAREST;
	setParams.magFilter = textureParameters::FILTER_NEAREST;
	gfxContext.setTextureParameters(setParams);

	Context::FrameBufferRenderTarget bufTarget;
	bufTarget.bufferHandle = m_pResultBuffer->m_FBO;
	bufTarget.bufferTarget = bufferTarget::DRAW_FRAMEBUFFER;
	bufTarget.attachment = bufferAttachment::COLOR_ATTACHMENT0;
	bufTarget.textureTarget = textureTarget::TEXTURE_2D;
	bufTarget.textureHandle = pTexture->name;
	gfxContext.addFrameBufferRenderTarget(bufTarget);
	assert(!gfxContext.isFramebufferError());
}

void PostProcessor::init()
{
	m_gammaCorrectionProgram.reset(gfxContext.createGammaCorrectionShader());
	m_postprocessingList.emplace_front(std::mem_fn(&PostProcessor::_doGammaCorrection)); // std::mem_fn to fix compilation with VS 2013
	if (config.video.fxaa != 0) {
		m_FXAAProgram.reset(gfxContext.createFXAAShader());
		m_postprocessingList.emplace_front(std::mem_fn(&PostProcessor::_doFXAA));
	}
	if (config.generalEmulation.enableBlitScreenWorkaround != 0) {
		m_orientationCorrectionProgram.reset(gfxContext.createOrientationCorrectionShader());
		m_postprocessingList.emplace_front(std::mem_fn(&PostProcessor::_doOrientationCorrection));
	}
}

void PostProcessor::destroy()
{
	m_postprocessingList.clear();
	m_gammaCorrectionProgram.reset();
	m_FXAAProgram.reset();
	m_orientationCorrectionProgram.reset();
	m_pResultBuffer.reset();
}

const PostProcessor::PostprocessingList & PostProcessor::getPostprocessingList() const
{
	return m_postprocessingList;
}

PostProcessor & PostProcessor::get()
{
	static PostProcessor processor;
	return processor;
}

void PostProcessor::_preDraw(FrameBuffer * _pBuffer)
{
	if (!m_pResultBuffer || m_pResultBuffer->m_width != _pBuffer->m_width)
		_createResultBuffer(_pBuffer);

	if (_pBuffer->m_pTexture->frameBufferTexture == CachedTexture::fbMultiSample) {
		_pBuffer->resolveMultisampledTexture(true);
		m_pTextureOriginal = _pBuffer->m_pResolveTexture;
	} else
		m_pTextureOriginal = _pBuffer->m_pTexture;

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER,
		ObjectHandle::defaultFramebuffer);
}

void PostProcessor::_postDraw()
{
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER,
		ObjectHandle::defaultFramebuffer);

	gfxContext.resetShaderProgram();
}

FrameBuffer * PostProcessor::_doPostProcessing(FrameBuffer * _pBuffer, graphics::ShaderProgram * _pShader)
{
	_preDraw(_pBuffer);

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER,
		ObjectHandle(m_pResultBuffer->m_FBO));

	CachedTexture * pDstTex = m_pResultBuffer->m_pTexture;
	GraphicsDrawer::CopyRectParams copyParams;
	copyParams.srcX0 = 0;
	copyParams.srcY0 = 0;
	copyParams.srcX1 = m_pTextureOriginal->realWidth;
	copyParams.srcY1 = m_pTextureOriginal->realHeight;
	copyParams.srcWidth = m_pTextureOriginal->realWidth;
	copyParams.srcHeight = m_pTextureOriginal->realHeight;
	copyParams.dstX0 = 0;
	copyParams.dstY0 = 0;
	copyParams.dstX1 = pDstTex->realWidth;
	copyParams.dstY1 = pDstTex->realHeight;
	copyParams.dstWidth = pDstTex->realWidth;
	copyParams.dstHeight = pDstTex->realHeight;
	copyParams.tex[0] = m_pTextureOriginal;
	copyParams.filter = textureParameters::FILTER_NEAREST;
	copyParams.combiner = _pShader;

	dwnd().getDrawer().copyTexturedRect(copyParams);

	_postDraw();
	return m_pResultBuffer.get();
}

FrameBuffer * PostProcessor::_doGammaCorrection(FrameBuffer * _pBuffer)
{
	if (_pBuffer == nullptr)
		return nullptr;

	if (((*REG.VI_STATUS & 8) | config.gammaCorrection.force) == 0)
		return _pBuffer;

	return _doPostProcessing(_pBuffer, m_gammaCorrectionProgram.get());
}

FrameBuffer * PostProcessor::_doOrientationCorrection(FrameBuffer * _pBuffer)
{
	if (_pBuffer == nullptr)
		return nullptr;

	if (config.generalEmulation.enableBlitScreenWorkaround == 0)
		return _pBuffer;

	return _doPostProcessing(_pBuffer, m_orientationCorrectionProgram.get());
}

FrameBuffer * PostProcessor::_doFXAA(FrameBuffer * _pBuffer)
{
	if (_pBuffer == nullptr)
		return nullptr;

	if (config.video.fxaa == 0)
		return _pBuffer;

	return _doPostProcessing(_pBuffer, m_FXAAProgram.get());
}
