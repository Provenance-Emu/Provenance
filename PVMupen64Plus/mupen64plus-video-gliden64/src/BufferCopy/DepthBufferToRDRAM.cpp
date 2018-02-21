#include <assert.h>
#include <math.h>
#include <algorithm>
#include <cstring>

#include "DepthBufferToRDRAM.h"
#include "WriteToRDRAM.h"

#include <FrameBuffer.h>
#include <DepthBuffer.h>
#include <Textures.h>
#include <Config.h>
#include <N64.h>
#include <VI.h>

#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include <Graphics/PixelBuffer.h>
#include <DisplayWindow.h>

using namespace graphics;

#define DEPTH_TEX_WIDTH 640
#define DEPTH_TEX_HEIGHT 580

DepthBufferToRDRAM::DepthBufferToRDRAM()
	: m_frameCount(-1)
	, m_pColorTexture(nullptr)
	, m_pDepthTexture(nullptr)
	, m_pCurFrameBuffer(nullptr)
{
}

DepthBufferToRDRAM::~DepthBufferToRDRAM()
{
}

DepthBufferToRDRAM & DepthBufferToRDRAM::get()
{
	static DepthBufferToRDRAM dbCopy;
	return dbCopy;
}

void DepthBufferToRDRAM::init()
{
	// Generate and initialize Pixel Buffer Objects
	m_pbuf.reset(gfxContext.createPixelReadBuffer(DEPTH_TEX_WIDTH * DEPTH_TEX_HEIGHT * sizeof(float)));
	if (!m_pbuf)
		return;

	m_pColorTexture = textureCache().addFrameBufferTexture(false);
	m_pColorTexture->format = G_IM_FMT_I;
	m_pColorTexture->size = 2;
	m_pColorTexture->clampS = 1;
	m_pColorTexture->clampT = 1;
	m_pColorTexture->frameBufferTexture = CachedTexture::fbOneSample;
	m_pColorTexture->maskS = 0;
	m_pColorTexture->maskT = 0;
	m_pColorTexture->mirrorS = 0;
	m_pColorTexture->mirrorT = 0;
	m_pColorTexture->realWidth = DEPTH_TEX_WIDTH;
	m_pColorTexture->realHeight = DEPTH_TEX_HEIGHT;
	m_pColorTexture->textureBytes = m_pColorTexture->realWidth * m_pColorTexture->realHeight;
	textureCache().addFrameBufferTextureSize(m_pColorTexture->textureBytes);

	m_pDepthTexture = textureCache().addFrameBufferTexture(false);
	m_pDepthTexture->format = G_IM_FMT_I;
	m_pColorTexture->size = 2;
	m_pDepthTexture->clampS = 1;
	m_pDepthTexture->clampT = 1;
	m_pDepthTexture->frameBufferTexture = CachedTexture::fbOneSample;
	m_pDepthTexture->maskS = 0;
	m_pDepthTexture->maskT = 0;
	m_pDepthTexture->mirrorS = 0;
	m_pDepthTexture->mirrorT = 0;
	m_pDepthTexture->realWidth = DEPTH_TEX_WIDTH;
	m_pDepthTexture->realHeight = DEPTH_TEX_HEIGHT;
	m_pDepthTexture->textureBytes = m_pDepthTexture->realWidth * m_pDepthTexture->realHeight * sizeof(float);
	textureCache().addFrameBufferTextureSize(m_pDepthTexture->textureBytes);

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();
	Context::InitTextureParams initParams;
	initParams.handle = m_pColorTexture->name;
	initParams.textureUnitIndex = textureIndices::Tex[0];
	initParams.width = m_pColorTexture->realWidth;
	initParams.height = m_pColorTexture->realHeight;
	initParams.internalFormat = fbTexFormats.monochromeInternalFormat;
	initParams.format = fbTexFormats.monochromeFormat;
	initParams.dataType = fbTexFormats.monochromeType;
	gfxContext.init2DTexture(initParams);

	Context::TexParameters setParams;
	setParams.handle = m_pColorTexture->name;
	setParams.target = textureTarget::TEXTURE_2D;
	setParams.textureUnitIndex = textureIndices::Tex[0];
	setParams.minFilter = textureParameters::FILTER_NEAREST;
	setParams.magFilter = textureParameters::FILTER_NEAREST;
	gfxContext.setTextureParameters(setParams);

	initParams.handle = m_pDepthTexture->name;
	initParams.width = m_pDepthTexture->realWidth;
	initParams.height = m_pDepthTexture->realHeight;
	initParams.internalFormat = fbTexFormats.depthInternalFormat;
	initParams.format = fbTexFormats.depthFormat;
	initParams.dataType = fbTexFormats.depthType;
	gfxContext.init2DTexture(initParams);

	setParams.handle = m_pDepthTexture->name;
	gfxContext.setTextureParameters(setParams);

	m_FBO = gfxContext.createFramebuffer();
	Context::FrameBufferRenderTarget bufTarget;
	bufTarget.bufferHandle = m_FBO;
	bufTarget.bufferTarget = bufferTarget::DRAW_FRAMEBUFFER;
	bufTarget.attachment = bufferAttachment::COLOR_ATTACHMENT0;
	bufTarget.textureTarget = textureTarget::TEXTURE_2D;
	bufTarget.textureHandle = m_pColorTexture->name;
	gfxContext.addFrameBufferRenderTarget(bufTarget);

	bufTarget.attachment = bufferAttachment::DEPTH_ATTACHMENT;
	bufTarget.textureHandle = m_pDepthTexture->name;
	gfxContext.addFrameBufferRenderTarget(bufTarget);

	// check if everything is OK
	assert(!gfxContext.isFramebufferError());
	assert(!gfxContext.isError());
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::null);
}

void DepthBufferToRDRAM::destroy() {
	if (!m_pbuf)
		return;

	gfxContext.deleteFramebuffer(m_FBO);
	m_FBO.reset();
	if (m_pColorTexture != nullptr) {
		textureCache().removeFrameBufferTexture(m_pColorTexture);
		m_pColorTexture = nullptr;
	}
	if (m_pDepthTexture != nullptr) {
		textureCache().removeFrameBufferTexture(m_pDepthTexture);
		m_pDepthTexture = nullptr;
	}
	m_pbuf.reset();
}

bool DepthBufferToRDRAM::_prepareCopy(u32& _startAddress, bool _copyChunk)
{
	const u32 curFrame = dwnd().getBuffersSwapCount();
	if (_copyChunk && m_frameCount == curFrame)
		return true;

	if ((VI.width | VI.height) == 0) // Incorrect buffer size. Don't copy
		return false;

	FrameBuffer *pBuffer = frameBufferList().findBuffer(_startAddress);
	if (pBuffer == nullptr || pBuffer->isAuxiliary() || pBuffer->m_pDepthBuffer == nullptr || !pBuffer->m_pDepthBuffer->m_cleared)
		return false;

	FrameBuffer * pDepthFrameBuffer = frameBufferList().findBuffer(pBuffer->m_pDepthBuffer->m_address);
	if (pDepthFrameBuffer != nullptr)
		m_pCurFrameBuffer = pDepthFrameBuffer;
	else
		m_pCurFrameBuffer = pBuffer;

	if (m_pCurFrameBuffer->m_width != pBuffer->m_pDepthBuffer->m_width)
		return false;

	const u32 numPixels = m_pCurFrameBuffer->m_width * m_pCurFrameBuffer->m_height;
	const u32 bufferOrigin = m_pCurFrameBuffer->m_pDepthBuffer->m_address;
	if (bufferOrigin + numPixels * 2 > RDRAMSize)
		return false;

	const u32 height = cutHeight(bufferOrigin, m_pCurFrameBuffer->m_height, m_pCurFrameBuffer->m_width * 2);
	if (height == 0)
		return false;

	_startAddress &= ~0xfff;
	if (_startAddress < bufferOrigin)
		_startAddress = bufferOrigin;

	ObjectHandle readBuffer = pBuffer->m_FBO;
	if (config.video.multisampling != 0) {
		m_pCurFrameBuffer->m_pDepthBuffer->resolveDepthBufferTexture(m_pCurFrameBuffer);
		readBuffer = m_pCurFrameBuffer->m_resolveFBO;
	}

	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = readBuffer;
	blitParams.drawBuffer = m_FBO;
	blitParams.srcX0 = 0;
	blitParams.srcY0 = 0;
	blitParams.srcX1 = m_pCurFrameBuffer->m_pTexture->realWidth;
	blitParams.srcY1 = s32(m_pCurFrameBuffer->m_height * m_pCurFrameBuffer->m_scale);
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = m_pCurFrameBuffer->m_width;
	blitParams.dstY1 = m_pCurFrameBuffer->m_height;
	blitParams.mask = blitMask::DEPTH_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	frameBufferList().setCurrentDrawBuffer();
	m_frameCount = curFrame;
	return true;
}

u16 DepthBufferToRDRAM::_FloatToUInt16(f32 _z)
{
	static const u16 * const zLUT = depthBufferList().getZLUT();
	u32 idx = 0x3FFFF;

	if (_z < 0.0f) {
		idx = 0;
	} else if (_z < 1.0f) {
		_z *= 262144.0f;
		idx = std::min(0x3FFFFU, u32(floorf(_z + 0.5f)));
	}

	return zLUT[idx];
}

bool DepthBufferToRDRAM::_copy(u32 _startAddress, u32 _endAddress)
{
	DepthBuffer * pDepthBuffer = m_pCurFrameBuffer->m_pDepthBuffer;
	const u32 stride = m_pCurFrameBuffer->m_width << 1;
	const u32 max_height = cutHeight(_startAddress, m_pCurFrameBuffer->m_height, stride);

	u32 numPixels = (_endAddress - _startAddress) >> 1;
	if (numPixels / m_pCurFrameBuffer->m_width > max_height) {
		_endAddress = _startAddress + (max_height * stride);
		numPixels = (_endAddress - _startAddress) >> 1;
	}

	const u32 width = m_pCurFrameBuffer->m_width;
	const s32 x0 = 0;
	const s32 y0 = (_startAddress - pDepthBuffer->m_address) / stride;
	const u32 y1 = (_endAddress - pDepthBuffer->m_address) / stride;
	const u32 height = std::min(max_height, 1u + y1 - y0);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, m_FBO);

	PixelBufferBinder<PixelReadBuffer> binder(m_pbuf.get());
	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();
	m_pbuf->readPixels(x0, y0, width, height, fbTexFormats.depthFormat, fbTexFormats.depthType);
	u8 * pixelData = (u8*)m_pbuf->getDataRange(0, width * height * fbTexFormats.depthFormatBytes);
	if (pixelData == nullptr)
		return false;

	f32 * ptr_src = (f32*)pixelData;
	u16 *ptr_dst = (u16*)(RDRAM + _startAddress);

	std::vector<f32> srcBuf(width * height);
	memcpy(srcBuf.data(), ptr_src, width * height * sizeof(f32));
	writeToRdram<f32, u16>(srcBuf.data(),
						   ptr_dst,
						   &DepthBufferToRDRAM::_FloatToUInt16,
						   2.0f,
						   1,
						   width,
						   height,
						   numPixels,
						   _startAddress,
						   pDepthBuffer->m_address,
						   G_IM_SIZ_16b);

	pDepthBuffer->m_cleared = false;
	FrameBuffer * pBuffer = frameBufferList().findBuffer(pDepthBuffer->m_address);
	if (pBuffer != nullptr)
		pBuffer->m_cleared = false;

	m_pbuf->closeReadBuffer();

	gDP.changed |= CHANGED_SCISSOR;
	return true;
}

bool DepthBufferToRDRAM::copyToRDRAM(u32 _address)
{
	if (config.frameBufferEmulation.copyDepthToRDRAM == Config::cdSoftwareRender)
		return true;

	if (!m_pbuf)
		return false;

	if (!_prepareCopy(_address, false))
		return false;

	const u32 endAddress = m_pCurFrameBuffer->m_pDepthBuffer->m_address +
			m_pCurFrameBuffer->m_width * m_pCurFrameBuffer->m_height * 2;
	return _copy(m_pCurFrameBuffer->m_pDepthBuffer->m_address, endAddress);
}

bool DepthBufferToRDRAM::copyChunkToRDRAM(u32 _startAddress)
{
	if (config.frameBufferEmulation.copyDepthToRDRAM == Config::cdSoftwareRender)
		return true;

	if (!m_pbuf)
		return false;

	const u32 endAddress = (_startAddress & ~0xfff) + 0x1000;

	if (!_prepareCopy(_startAddress, true))
		return false;

	return _copy(_startAddress, endAddress);
}
