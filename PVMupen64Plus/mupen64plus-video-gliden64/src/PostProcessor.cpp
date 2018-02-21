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
	textureCache().addFrameBufferTextureSize(pTexture->textureBytes);

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

void PostProcessor::_initGammaCorrection()
{
	m_gammaCorrectionProgram.reset(gfxContext.createGammaCorrectionShader());
}

void PostProcessor::_initOrientationCorrection()
{
	m_orientationCorrectionProgram.reset(gfxContext.createOrientationCorrectionShader());
}

void PostProcessor::init()
{
	_initGammaCorrection();
	if (config.generalEmulation.enableBlitScreenWorkaround != 0)
		_initOrientationCorrection();
}

void PostProcessor::_destroyGammaCorrection()
{
	m_gammaCorrectionProgram.reset();
}

void PostProcessor::_destroyOrientationCorrection()
{
	m_orientationCorrectionProgram.reset();
}

void PostProcessor::destroy()
{
	_destroyGammaCorrection();
	_destroyOrientationCorrection();
	m_pResultBuffer.reset();
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
		ObjectHandle::null);
}

void PostProcessor::_postDraw()
{
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER,
		ObjectHandle::null);

	gfxContext.resetShaderProgram();
}

FrameBuffer * PostProcessor::doGammaCorrection(FrameBuffer * _pBuffer)
{
	if (_pBuffer == nullptr)
		return nullptr;

	if (((*REG.VI_STATUS & 8) | config.gammaCorrection.force) == 0)
		return _pBuffer;

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
	copyParams.combiner = m_gammaCorrectionProgram.get();

	dwnd().getDrawer().copyTexturedRect(copyParams);

	_postDraw();
	return m_pResultBuffer.get();
}

FrameBuffer * PostProcessor::doOrientationCorrection(FrameBuffer * _pBuffer)
{
	if (_pBuffer == nullptr)
		return nullptr;

	if (config.generalEmulation.enableBlitScreenWorkaround == 0)
		return _pBuffer;

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
	copyParams.combiner = m_orientationCorrectionProgram.get();

	dwnd().getDrawer().copyTexturedRect(copyParams);

	_postDraw();
	return m_pResultBuffer.get();
}
