#include <assert.h>
#include <math.h>
#include <algorithm>
#include <vector>
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "N64.h"
#include "RSP.h"
#include "RDP.h"
#include "gDP.h"
#include "VI.h"
#include "Textures.h"
#include "Combiner.h"
#include "Types.h"
#include "Config.h"
#include "Debugger.h"
#include "DebugDump.h"
#include "PostProcessor.h"
#include "FrameBufferInfo.h"
#include "Log.h"

#include "BufferCopy/ColorBufferToRDRAM.h"
#include "BufferCopy/DepthBufferToRDRAM.h"
#include "BufferCopy/RDRAMtoColorBuffer.h"

#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include "DisplayWindow.h"

using namespace std;
using namespace graphics;

FrameBuffer::FrameBuffer()
	: m_startAddress(0)
	, m_endAddress(0)
	, m_size(0)
	, m_width(0)
	, m_height(0)
	, m_originX(0)
	, m_originY(0)
	, m_swapCount(0)
	, m_scale(0)
	, m_copiedToRdram(false)
	, m_fingerprint(false)
	, m_cleared(false)
	, m_changed(false)
	, m_cfb(false)
	, m_isDepthBuffer(false)
	, m_isPauseScreen(false)
	, m_isOBScreen(false)
	, m_isMainBuffer(false)
	, m_readable(false)
	, m_loadType(LOADTYPE_BLOCK)
	, m_pDepthBuffer(nullptr)
	, m_pResolveTexture(nullptr)
	, m_resolved(false)
	, m_pSubTexture(nullptr)
	, m_copied(false)
	, m_pFrameBufferCopyTexture(nullptr)
	, m_copyFBO(ObjectHandle::defaultFramebuffer)
	, m_validityChecked(0)
{
	m_loadTileOrigin.uls = m_loadTileOrigin.ult = 0;
	m_pTexture = textureCache().addFrameBufferTexture(config.video.multisampling != 0);
	m_FBO = gfxContext.createFramebuffer();
}

FrameBuffer::~FrameBuffer()
{
	gfxContext.deleteFramebuffer(m_FBO);
	gfxContext.deleteFramebuffer(m_resolveFBO);
	gfxContext.deleteFramebuffer(m_SubFBO);
	gfxContext.deleteFramebuffer(m_copyFBO);

	textureCache().removeFrameBufferTexture(m_pTexture);
	textureCache().removeFrameBufferTexture(m_pResolveTexture);
	textureCache().removeFrameBufferTexture(m_pSubTexture);
	textureCache().removeFrameBufferTexture(m_pFrameBufferCopyTexture);
}

static
void _initFrameBufferTexture(u32 _address, u16 _width, u16 _height, f32 _scale, u16 _format, u16 _size, CachedTexture *_pTexture)
{
	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	_pTexture->width = (u16)(u32)(_width * _scale);
	_pTexture->height = (u16)(u32)(_height * _scale);
	_pTexture->format = _format;
	_pTexture->size = _size;
	_pTexture->clampS = 1;
	_pTexture->clampT = 1;
	_pTexture->address = _address;
	_pTexture->clampWidth = _width;
	_pTexture->clampHeight = _height;
	_pTexture->frameBufferTexture = CachedTexture::fbOneSample;
	_pTexture->maskS = 0;
	_pTexture->maskT = 0;
	_pTexture->mirrorS = 0;
	_pTexture->mirrorT = 0;
	_pTexture->realWidth = _pTexture->width;
	_pTexture->realHeight = _pTexture->height;
	_pTexture->textureBytes = _pTexture->realWidth * _pTexture->realHeight;
	if (_size > G_IM_SIZ_8b)
		_pTexture->textureBytes *= fbTexFormats.colorFormatBytes;
	else
		_pTexture->textureBytes *= fbTexFormats.monochromeFormatBytes;
}

void FrameBuffer::_initTexture(u16 _width, u16 _height, u16 _format, u16 _size, CachedTexture *_pTexture)
{
	_initFrameBufferTexture(m_startAddress, _width, _height, m_scale, _format, _size, _pTexture);
}

static
void _setAndAttachBufferTexture(ObjectHandle _fbo, CachedTexture *_pTexture, u32 _t, bool _multisampling)
{
	const FramebufferTextureFormats & fbTexFormat = gfxContext.getFramebufferTextureFormats();
	Context::InitTextureParams initParams;
	initParams.handle = _pTexture->name;
	initParams.textureUnitIndex = textureIndices::Tex[_t];
	if (_multisampling)
		initParams.msaaLevel = config.video.multisampling;
	initParams.width = _pTexture->realWidth;
	initParams.height = _pTexture->realHeight;
	if (_pTexture->size > G_IM_SIZ_8b) {
		initParams.internalFormat = fbTexFormat.colorInternalFormat;
		initParams.format = fbTexFormat.colorFormat;
		initParams.dataType = fbTexFormat.colorType;
	} else {
		initParams.internalFormat = fbTexFormat.monochromeInternalFormat;
		initParams.format = fbTexFormat.monochromeFormat;
		initParams.dataType = fbTexFormat.monochromeType;
	}
	gfxContext.init2DTexture(initParams);

	if (!_multisampling) {
		Context::TexParameters texParams;
		texParams.handle = _pTexture->name;
		texParams.target = textureTarget::TEXTURE_2D;
		texParams.textureUnitIndex = textureIndices::Tex[_t];
		texParams.minFilter = textureParameters::FILTER_NEAREST;
		texParams.magFilter = textureParameters::FILTER_NEAREST;
		gfxContext.setTextureParameters(texParams);
	}

	Context::FrameBufferRenderTarget bufTarget;
	bufTarget.bufferHandle = _fbo;
	bufTarget.bufferTarget = bufferTarget::FRAMEBUFFER;
	bufTarget.attachment = bufferAttachment::COLOR_ATTACHMENT0;
	bufTarget.textureTarget = _multisampling ? textureTarget::TEXTURE_2D_MULTISAMPLE : textureTarget::TEXTURE_2D;
	bufTarget.textureHandle = _pTexture->name;
	gfxContext.addFrameBufferRenderTarget(bufTarget);
	assert(!gfxContext.isFramebufferError());
}

void FrameBuffer::_setAndAttachTexture(ObjectHandle _fbo, CachedTexture *_pTexture, u32 _t, bool _multisampling)
{
	_setAndAttachBufferTexture(_fbo, _pTexture, _t, _multisampling);
}

bool FrameBuffer::isAuxiliary() const
{
	return m_width != VI.width;
}

void FrameBuffer::init(u32 _address, u16 _format, u16 _size, u16 _width, bool _cfb)
{
	m_startAddress = _address;
	m_width = _width;
	m_height = _cfb ? VI.height : 1;
//	m_height = VI.height;
	m_size = _size;
	updateEndAddress();
	if (isAuxiliary() && config.frameBufferEmulation.copyAuxToRDRAM != 0) {
		m_scale = 1.0f;
	} else if (config.frameBufferEmulation.nativeResFactor != 0 && config.frameBufferEmulation.enable != 0) {
		m_scale = static_cast<float>(config.frameBufferEmulation.nativeResFactor);
	} else {
		m_scale = dwnd().getScaleX();
	}
	m_cfb = _cfb;
	m_cleared = false;
	m_fingerprint = false;
	m_swapCount = dwnd().getBuffersSwapCount();

	const u16 maxHeight = VI_GetMaxBufferHeight(_width);
	_initTexture(_width, maxHeight, _format, _size, m_pTexture);

	if (config.video.multisampling != 0) {
		_setAndAttachTexture(m_FBO, m_pTexture, 0, true);
		m_pTexture->frameBufferTexture = CachedTexture::fbMultiSample;

		m_pResolveTexture = textureCache().addFrameBufferTexture(false);
		_initTexture(_width, maxHeight, _format, _size, m_pResolveTexture);
		m_resolveFBO = gfxContext.createFramebuffer();
		_setAndAttachTexture(m_resolveFBO, m_pResolveTexture, 0, false);
		assert(!gfxContext.isFramebufferError());

		gfxContext.bindFramebuffer(bufferTarget::FRAMEBUFFER, m_FBO);
	} else
		_setAndAttachTexture(m_FBO, m_pTexture, 0, false);

//	gfxContext.clearColorBuffer(0.0f, 0.0f, 0.0f, 0.0f);
}

void FrameBuffer::updateEndAddress()
{
	const u32 height = max(1U, m_height);
	m_endAddress = min(RDRAMSize, m_startAddress + (((m_width * height) << m_size >> 1) - 1));
}

inline
u32 _cutHeight(u32 _address, u32 _height, u32 _stride)
{
	if (_address > RDRAMSize)
		return 0;
	if (_address + _stride * _height > (RDRAMSize + 1))
		return (RDRAMSize + 1 - _address) / _stride;
	return _height;
}

void FrameBuffer::setBufferClearParams(u32 _fillcolor, s32 _ulx, s32 _uly, s32 _lrx, s32 _lry)
{
	m_cleared = true;
	m_clearParams.fillcolor = _fillcolor;
	m_clearParams.ulx = _ulx;
	m_clearParams.lrx = _lrx;
	m_clearParams.uly = _uly;
	m_clearParams.lry = _lry;
}

void FrameBuffer::copyRdram()
{
	const u32 stride = m_width << m_size >> 1;
	const u32 height = _cutHeight(m_startAddress, m_height, stride);
	if (height == 0)
		return;
	const u32 dataSize = stride * height;

	// Auxiliary frame buffer
	if (isAuxiliary() && config.frameBufferEmulation.copyAuxToRDRAM == 0) {
		// Write small amount of data to the start of the buffer.
		// This is necessary for auxilary buffers: game can restore content of RDRAM when buffer is not needed anymore
		// Thus content of RDRAM on moment of buffer creation will be the same as when buffer becomes obsolete.
		// Validity check will see that the RDRAM is the same and thus the buffer is valid, which is false.
		const u32 twoPercent = max(4U, dataSize / 200);
		u32 start = m_startAddress >> 2;
		u32 * pData = (u32*)RDRAM;
		for (u32 i = 0; i < twoPercent; ++i) {
			if (i < 4)
				pData[start++] = fingerprint[i];
			else
				pData[start++] = 0;
		}
		m_cleared = false;
		m_fingerprint = true;
		return;
	}
	m_RdramCopy.resize(dataSize);
	memcpy(m_RdramCopy.data(), RDRAM + m_startAddress, dataSize);
}

void FrameBuffer::setDirty()
{
	m_cleared = false;
	m_RdramCopy.clear();
}

bool FrameBuffer::isValid(bool _forceCheck) const
{
	if (!_forceCheck) {
		if (m_validityChecked == dwnd().getBuffersSwapCount())
			return true; // Already checked
		m_validityChecked = dwnd().getBuffersSwapCount();
	}

	const u32 * const pData = (const u32*)RDRAM;

	if (m_cleared) {
		const u32 testColor = m_clearParams.fillcolor & 0xFFFEFFFE;
		const u32 stride = m_width << m_size >> 1;
		const s32 lry = (s32)_cutHeight(m_startAddress, m_clearParams.lry, stride);
		if (lry == 0)
			return false;

		const u32 ci_width_in_dwords = m_width >> (3 - m_size);
		const u32 start = (m_startAddress >> 2) + m_clearParams.uly * ci_width_in_dwords;
		const u32 * dst = pData + start;
		u32 wrongPixels = 0;
		for (s32 y = m_clearParams.uly; y < lry; ++y) {
			for (s32 x = m_clearParams.ulx; x < m_clearParams.lrx; ++x) {
				if ((dst[x] & 0xFFFEFFFE) != testColor)
					++wrongPixels;
			}
			dst += ci_width_in_dwords;
		}
		return wrongPixels < (m_endAddress - m_startAddress) / 400; // threshold level 1% of dwords
	} else if (m_fingerprint) {
			//check if our fingerprint is still there
			u32 start = m_startAddress >> 2;
			for (u32 i = 0; i < 4; ++i)
				if ((pData[start++] & 0xFFFEFFFE) != (fingerprint[i] & 0xFFFEFFFE))
					return false;
			return true;
	} else if (!m_RdramCopy.empty()) {
		const u32 * const pCopy = reinterpret_cast<const u32* >(m_RdramCopy.data());
		const u32 size = static_cast<u32>(m_RdramCopy.size());
		const u32 size_dwords = size >> 2;
		u32 start = m_startAddress >> 2;
		u32 wrongPixels = 0;
		for (u32 i = 0; i < size_dwords; ++i) {
			if ((pData[start++] & 0xFFFEFFFE) != (pCopy[i] & 0xFFFEFFFE))
				++wrongPixels;
		}
		return wrongPixels < size / 400; // threshold level 1% of dwords
	}
	return true; // No data to decide
}

void FrameBuffer::resolveMultisampledTexture(bool _bForce)
{
	if (!Context::Multisampling)
		return;

	if (m_resolved && !_bForce)
		return;

	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = m_FBO;
	blitParams.drawBuffer = m_resolveFBO;
	blitParams.srcX0 = 0;
	blitParams.srcY0 = 0;
	blitParams.srcX1 = m_pTexture->realWidth;
	blitParams.srcY1 = m_pTexture->realHeight;
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = m_pResolveTexture->realWidth;
	blitParams.dstY1 = m_pResolveTexture->realHeight;
	blitParams.mask = blitMask::COLOR_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);

	frameBufferList().setCurrentDrawBuffer();
	m_resolved = true;
}

bool FrameBuffer::_initSubTexture(u32 _t)
{
	if (!m_SubFBO.isNotNull())
		m_SubFBO = gfxContext.createFramebuffer();

	gDPTile * pTile = gSP.textureTile[_t];
	if (pTile->lrs < pTile->uls || pTile->lrt < pTile->ult)
		return false;
	const u32 width = pTile->lrs - pTile->uls + 1;
	const u32 height = pTile->lrt - pTile->ult + 1;

	if (m_pSubTexture != nullptr) {
		if (m_pSubTexture->size == m_pTexture->size &&
			m_pSubTexture->clampWidth == width &&
			m_pSubTexture->clampHeight == height)
			return true;
		textureCache().removeFrameBufferTexture(m_pSubTexture);
	}

	m_pSubTexture = textureCache().addFrameBufferTexture(false);
	_initTexture(width, height, m_pTexture->format, m_pTexture->size, m_pSubTexture);

	m_pSubTexture->clampS = pTile->clamps;
	m_pSubTexture->clampT = pTile->clampt;
	m_pSubTexture->offsetS = 0.0f;
	m_pSubTexture->offsetT = 0.0f;


	_setAndAttachTexture(m_SubFBO, m_pSubTexture, _t, false);

	return true;
}

CachedTexture * FrameBuffer::_getSubTexture(u32 _t)
{
	if (!Context::BlitFramebuffer)
		return m_pTexture;

	if (!_initSubTexture(_t))
		return m_pTexture;

	s32 x0 = (s32)(m_pTexture->offsetS * m_scale);
	s32 y0 = (s32)(m_pTexture->offsetT * m_scale);
	s32 copyWidth = m_pSubTexture->realWidth;
	if (x0 + copyWidth > m_pTexture->realWidth)
		copyWidth = m_pTexture->realWidth - x0;
	s32 copyHeight = m_pSubTexture->realHeight;
	if (y0 + copyHeight > m_pTexture->realHeight)
		copyHeight = m_pTexture->realHeight - y0;

	ObjectHandle readFBO = m_FBO;
	if (Context::WeakBlitFramebuffer &&
			m_pTexture->frameBufferTexture == CachedTexture::fbMultiSample) {
		resolveMultisampledTexture(true);
		readFBO = m_resolveFBO;
	}

	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = readFBO;
	blitParams.drawBuffer = m_SubFBO;
	blitParams.srcX0 = x0;
	blitParams.srcY0 = y0;
	blitParams.srcX1 = x0 + copyWidth;
	blitParams.srcY1 = y0 + copyHeight;
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = copyWidth;
	blitParams.dstY1 = copyHeight;
	blitParams.mask = blitMask::COLOR_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);

	frameBufferList().setCurrentDrawBuffer();

	return m_pSubTexture;
}

void FrameBuffer::_initCopyTexture()
{
	m_copyFBO = gfxContext.createFramebuffer();
	m_pFrameBufferCopyTexture = textureCache().addFrameBufferTexture(config.video.multisampling != 0);
	_initTexture(m_width, VI_GetMaxBufferHeight(m_width), m_pTexture->format, m_pTexture->size, m_pFrameBufferCopyTexture);
	_setAndAttachTexture(m_copyFBO, m_pFrameBufferCopyTexture, 0, config.video.multisampling != 0);
	if (config.video.multisampling != 0)
		m_pFrameBufferCopyTexture->frameBufferTexture = CachedTexture::fbMultiSample;
}

CachedTexture * FrameBuffer::_copyFrameBufferTexture()
{
	if (m_copied)
		return m_pFrameBufferCopyTexture;

	if (m_pFrameBufferCopyTexture == nullptr)
		_initCopyTexture();

	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = m_FBO;
	blitParams.drawBuffer = m_copyFBO;
	blitParams.srcX0 = 0;
	blitParams.srcY0 = 0;
	blitParams.srcX1 = m_pTexture->realWidth;
	blitParams.srcY1 = m_pTexture->realHeight;
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = m_pTexture->realWidth;
	blitParams.dstY1 = m_pTexture->realHeight;
	blitParams.mask = blitMask::COLOR_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
	frameBufferList().setCurrentDrawBuffer();

	m_copied = true;
	return m_pFrameBufferCopyTexture;
}

CachedTexture * FrameBuffer::getTexture(u32 _t)
{
	const bool getDepthTexture = m_isDepthBuffer &&
								 gDP.colorImage.address == gDP.depthImageAddress &&
								 m_pDepthBuffer != nullptr &&
								 (config.generalEmulation.hacks & hack_ZeldaMM) == 0;
	CachedTexture *pTexture = getDepthTexture ? m_pDepthBuffer->m_pDepthBufferTexture : m_pTexture;

	if (this == frameBufferList().getCurrent()) {
		if (Context::TextureBarrier)
			gfxContext.textureBarrier();
		else if (Context::BlitFramebuffer)
			pTexture = getDepthTexture ? m_pDepthBuffer->copyDepthBufferTexture(this) : _copyFrameBufferTexture();
	}

	const u32 shift = (gSP.textureTile[_t]->imageAddress - m_startAddress) >> (m_size - 1);
	const u32 factor = m_width;
	if (m_loadType == LOADTYPE_TILE) {
		pTexture->offsetS = (float)(m_loadTileOrigin.uls + (shift % factor));
		pTexture->offsetT = (float)(m_loadTileOrigin.ult + shift / factor);
	} else {
		pTexture->offsetS = (float)(shift % factor);
		pTexture->offsetT = (float)(shift / factor);
	}

	if (!getDepthTexture && (gSP.textureTile[_t]->clamps == 0 || gSP.textureTile[_t]->clampt == 0))
		pTexture = _getSubTexture(_t);

	pTexture->scaleS = m_scale / (float)pTexture->realWidth;
	pTexture->scaleT = m_scale / (float)pTexture->realHeight;

	if (gSP.textureTile[_t]->shifts > 10)
		pTexture->shiftScaleS = (float)(1 << (16 - gSP.textureTile[_t]->shifts));
	else if (gSP.textureTile[_t]->shifts > 0)
		pTexture->shiftScaleS = 1.0f / (float)(1 << gSP.textureTile[_t]->shifts);
	else
		pTexture->shiftScaleS = 1.0f;

	if (gSP.textureTile[_t]->shiftt > 10)
		pTexture->shiftScaleT = (float)(1 << (16 - gSP.textureTile[_t]->shiftt));
	else if (gSP.textureTile[_t]->shiftt > 0)
		pTexture->shiftScaleT = 1.0f / (float)(1 << gSP.textureTile[_t]->shiftt);
	else
		pTexture->shiftScaleT = 1.0f;

	return pTexture;
}

CachedTexture * FrameBuffer::getTextureBG(u32 _t)
{
	CachedTexture *pTexture = m_pTexture;

	if (this == frameBufferList().getCurrent()) {
		if (Context::TextureBarrier)
			gfxContext.textureBarrier();
		else if (Context::BlitFramebuffer)
			pTexture = _copyFrameBufferTexture();
	}

	pTexture->scaleS = m_scale / (float)pTexture->realWidth;
	pTexture->scaleT = m_scale / (float)pTexture->realHeight;

	pTexture->shiftScaleS = 1.0f;
	pTexture->shiftScaleT = 1.0f;

	pTexture->offsetS = gSP.bgImage.imageX;
	pTexture->offsetT = gSP.bgImage.imageY;
	return pTexture;
}

FrameBufferList & FrameBufferList::get()
{
	static FrameBufferList frameBufferList;
	return frameBufferList;
}

void FrameBufferList::init()
{
	 m_pCurrent = nullptr;
	 m_pCopy = nullptr;
	 gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
	 m_prevColorImageHeight = 0;
	 m_overscan.init();
}

void FrameBufferList::destroy() {
	gfxContext.bindFramebuffer(bufferTarget::FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
	m_list.clear();
	m_pCurrent = nullptr;
	m_pCopy = nullptr;
	m_overscan.destroy();
}

void FrameBufferList::setBufferChanged(f32 _maxY)
{
	gDP.colorImage.changed = TRUE;
	gDP.colorImage.height = max(gDP.colorImage.height, (u32)_maxY);
	gDP.colorImage.height = min(gDP.colorImage.height, (u32)gDP.scissor.lry);
	if (m_pCurrent != nullptr) {
		m_pCurrent->m_height = max(m_pCurrent->m_height, gDP.colorImage.height);
		m_pCurrent->m_cfb = false;
		m_pCurrent->m_changed = true;
		m_pCurrent->m_copiedToRdram = false;
	}
}

void FrameBufferList::clearBuffersChanged()
{
	gDP.colorImage.changed = FALSE;
	FrameBuffer * pBuffer = frameBufferList().findBuffer(*REG.VI_ORIGIN);
	if (pBuffer != nullptr)
		pBuffer->m_changed = false;
}

void FrameBufferList::setCurrentDrawBuffer() const
{
	if (m_pCurrent != nullptr)
		gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_pCurrent->m_FBO);
	else if (!m_list.empty())
		gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_list.back().m_FBO);
}

FrameBuffer * FrameBufferList::findBuffer(u32 _startAddress)
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		if (iter->m_startAddress <= _startAddress && iter->m_endAddress >= _startAddress) // [  {  ]
			return &(*iter);
	}
	return nullptr;
}

FrameBuffer * FrameBufferList::getBuffer(u32 _startAddress)
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		if (iter->m_startAddress == _startAddress)
			return &(*iter);
	}
	return nullptr;
}

inline
bool isOverlapping(const FrameBuffer * _buf1, const FrameBuffer * _buf2)
{
	if (_buf1->m_endAddress < _buf2->m_endAddress && _buf1->m_width == _buf2->m_width && _buf1->m_size == _buf2->m_size) {
		const u32 diff = _buf1->m_endAddress - _buf2->m_startAddress + 1;
		const u32 stride = _buf1->m_width << _buf1->m_size >> 1;
		if ((diff % stride == 0) && (diff / stride < 5))
			return true;
		else
			return false;
	}
	return false;
}

void FrameBufferList::removeIntersections()
{
	assert(!m_list.empty());

	FrameBuffers::iterator iter = m_list.end();
	do {
		--iter;
		if (&(*iter) == m_pCurrent)
			continue;
		if (iter->m_startAddress <= m_pCurrent->m_startAddress && iter->m_endAddress >= m_pCurrent->m_startAddress) { // [  {  ]
			if (isOverlapping(&(*iter), m_pCurrent)) {
				iter->m_endAddress = m_pCurrent->m_startAddress - 1;
				continue;
			}
			iter = m_list.erase(iter);
		} else if (m_pCurrent->m_startAddress <= iter->m_startAddress && m_pCurrent->m_endAddress >= iter->m_startAddress) { // {  [  }
			if (isOverlapping(m_pCurrent, &(*iter))) {
				m_pCurrent->m_endAddress = iter->m_startAddress - 1;
				continue;
			}
			iter = m_list.erase(iter);
		}
	} while (iter != m_list.begin());
}

FrameBuffer * FrameBufferList::findTmpBuffer(u32 _address)
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter)
		if (iter->m_startAddress > _address || iter->m_endAddress < _address)
				return &(*iter);
	return nullptr;
}


void FrameBufferList::_createScreenSizeBuffer()
{
	if (VI.height == 0)
		return;
	m_list.emplace_front();
	FrameBuffer & buffer = m_list.front();
	buffer.init(VI.width * 2, G_IM_FMT_RGBA, G_IM_SIZ_16b, VI.width, false);
}

void FrameBufferList::saveBuffer(u32 _address, u16 _format, u16 _size, u16 _width, bool _cfb)
{
	if (_width > 640)
		return;

	if (_width == 512 && (config.generalEmulation.hacks & hack_RE2) != 0)
		_width = *REG.VI_WIDTH;

	if (config.frameBufferEmulation.enable == 0) {
		if (m_list.empty())
			_createScreenSizeBuffer();
		return;
	}

	if (m_pCurrent != nullptr &&
		config.frameBufferEmulation.copyAuxToRDRAM != 0 &&
		(config.generalEmulation.hacks & hack_Snap) == 0) {
		if (m_pCurrent->isAuxiliary()) {
			FrameBuffer_CopyToRDRAM(m_pCurrent->m_startAddress, true);
			removeBuffer(m_pCurrent->m_startAddress);
		}
	}

	DisplayWindow & wnd = dwnd();
	bool bPrevIsDepth = false;

	if (m_pCurrent != nullptr) {
		bPrevIsDepth = m_pCurrent->m_isDepthBuffer;
		m_pCurrent->m_readable = true;
		m_pCurrent->updateEndAddress();

		if (!m_pCurrent->m_isDepthBuffer &&
			!m_pCurrent->m_copiedToRdram &&
			!m_pCurrent->m_cfb &&
			!m_pCurrent->m_cleared &&
			m_pCurrent->m_RdramCopy.empty() &&
			m_pCurrent->m_height > 1) {
			m_pCurrent->copyRdram();
		}

		removeIntersections();
	}

	const float scaleX = config.frameBufferEmulation.nativeResFactor == 0 ?
		wnd.getScaleX() :
		static_cast<float>(config.frameBufferEmulation.nativeResFactor);

	if (m_pCurrent == nullptr || m_pCurrent->m_startAddress != _address || m_pCurrent->m_width != _width)
		m_pCurrent = findBuffer(_address);

	auto isSubBuffer = [_address, _width, _size, &wnd](const FrameBuffer * _pBuffer) -> bool
	{
		if (_pBuffer->m_swapCount == wnd.getBuffersSwapCount() &&
			!_pBuffer->m_cfb &&
			_pBuffer->m_width == _width &&
			_pBuffer->m_size == _size)
		{
			const u32 stride = _width << _size >> 1;
			const u32 diffFromStart = _address - _pBuffer->m_startAddress;
			if (diffFromStart % stride != 0)
				return true;
			const u32 diffFromEnd = _pBuffer->m_endAddress - _address + 1;
			if ((diffFromEnd / stride > 5))
				return true;
		}
		return false;
	};

	auto isOverlappingBuffer = [_address, _width, _size](const FrameBuffer * _pBuffer) -> bool
	{
		if (_pBuffer->m_width == _width && _pBuffer->m_size == _size) {
			const u32 stride = _width << _size >> 1;
			const u32 diffEnd = _pBuffer->m_endAddress - _address + 1;
			if ((diffEnd / stride < 5))
				return true;
		}
		return false;
	};

	if (m_pCurrent != nullptr) {
		m_pCurrent->m_originX = m_pCurrent->m_originY = 0;
		if ((m_pCurrent->m_startAddress != _address)) {
			if (isSubBuffer(m_pCurrent)) {
				const u32 stride = _width << _size >> 1;
				const u32 addrOffset = _address - m_pCurrent->m_startAddress;
				m_pCurrent->m_originX = (addrOffset % stride) >> (_size - 1);
				m_pCurrent->m_originY = addrOffset / stride;
				gSP.changed |= CHANGED_VIEWPORT;
				gDP.changed |= CHANGED_SCISSOR;
				return;
			} else if (isOverlappingBuffer(m_pCurrent)) {
				m_pCurrent->m_endAddress = _address - 1;
				m_pCurrent = nullptr;
			} else {
				removeBuffer(m_pCurrent->m_startAddress);
				m_pCurrent = nullptr;
			}
		} else if ((m_pCurrent->m_width != _width) ||
					(m_pCurrent->m_size < _size) ||
					(m_pCurrent->m_scale != scaleX)) {
			removeBuffer(m_pCurrent->m_startAddress);
			m_pCurrent = nullptr;
		} else {
			m_pCurrent->m_resolved = false;
			gfxContext.bindFramebuffer(bufferTarget::FRAMEBUFFER, m_pCurrent->m_FBO);
			if (m_pCurrent->m_size != _size) {
				f32 fillColor[4];
				gDPGetFillColor(fillColor);
				wnd.getDrawer().clearColorBuffer(fillColor);
				m_pCurrent->m_size = _size;
				m_pCurrent->m_pTexture->format = _format;
				m_pCurrent->m_pTexture->size = _size;
				if (m_pCurrent->m_pResolveTexture != nullptr) {
					m_pCurrent->m_pResolveTexture->format = _format;
					m_pCurrent->m_pResolveTexture->size = _size;
				}
				if (m_pCurrent->m_copiedToRdram)
					m_pCurrent->copyRdram();
			}
		}
	}
	const bool bNew = m_pCurrent == nullptr;
	if  (bNew) {
		// Wasn't found or removed, create a new one
		m_list.emplace_front();
		FrameBuffer & buffer = m_list.front();
		buffer.init(_address, _format, _size, _width, _cfb);
		m_pCurrent = &buffer;
		RDRAMtoColorBuffer::get().copyFromRDRAM(m_pCurrent);
	}

	if (_address == gDP.depthImageAddress)
		depthBufferList().saveBuffer(_address);
	else
		attachDepthBuffer();

	DebugMsg( DEBUG_NORMAL, "FrameBuffer_SaveBuffer( 0x%08X )\n", _address);

	if (m_pCurrent->isAuxiliary() &&
		m_pCurrent->m_pDepthBuffer != nullptr &&
		bPrevIsDepth &&
		(config.generalEmulation.hacks&hack_LoadDepthTextures) == 0) {
		// N64 games may use partial depth buffer clear for aux buffers
		// It will not work for GL, so we have to force clear depth buffer for aux buffer
		wnd.getDrawer().clearDepthBuffer();
	}

	m_pCurrent->m_isDepthBuffer = _address == gDP.depthImageAddress;
	m_pCurrent->m_isPauseScreen = m_pCurrent->m_isOBScreen = false;
	m_pCurrent->m_copied = false;
	m_pCurrent->m_swapCount = wnd.getBuffersSwapCount();
}

void FrameBufferList::copyAux()
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		if (iter->isAuxiliary())
			FrameBuffer_CopyToRDRAM(iter->m_startAddress, true);
	}
}

void FrameBufferList::removeAux()
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		while (iter->isAuxiliary()) {
			if (&(*iter) == m_pCurrent) {
				m_pCurrent = nullptr;
				gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
			}
			iter = m_list.erase(iter);
			if (iter == m_list.end())
				return;
		}
	}
}

void FrameBufferList::removeBuffer(u32 _address )
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter)
		if (iter->m_startAddress == _address) {
			if (&(*iter) == m_pCurrent) {
				m_pCurrent = nullptr;
				gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
			}
			m_list.erase(iter);
			return;
		}
}

void FrameBufferList::removeBuffers(u32 _width)
{
	m_pCurrent = nullptr;
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		while (iter->m_width == _width) {
			if (&(*iter) == m_pCurrent) {
				m_pCurrent = nullptr;
				gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
			}
			iter = m_list.erase(iter);
			if (iter == m_list.end())
				return;
		}
	}
}

void FrameBufferList::depthBufferCopyRdram()
{
	FrameBuffer * pCurrentDepthBuffer = findBuffer(gDP.depthImageAddress);
	if (pCurrentDepthBuffer != nullptr)
		pCurrentDepthBuffer->copyRdram();
}

void FrameBufferList::fillBufferInfo(void * _pinfo, u32 _size)
{
	FBInfo::FrameBufferInfo* pInfo = reinterpret_cast<FBInfo::FrameBufferInfo*>(_pinfo);

	u32 idx = 0;
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		if (iter->m_width == VI.width && !iter->m_cfb && !iter->m_isDepthBuffer) {
			pInfo[idx].addr = iter->m_startAddress;
			pInfo[idx].width = iter->m_width;
			pInfo[idx].height = iter->m_height;
			pInfo[idx++].size = iter->m_size;
			if (idx >= _size)
				return;
		}
	}
}

void FrameBufferList::attachDepthBuffer()
{
	FrameBuffer * pCurrent = config.frameBufferEmulation.enable == 0 ? &m_list.back() : m_pCurrent;
	if (pCurrent == nullptr)
		return;

	DepthBuffer * pDepthBuffer = depthBufferList().getCurrent();

	if (pCurrent->m_FBO.isNotNull() && pDepthBuffer != nullptr) {
		pDepthBuffer->initDepthImageTexture(pCurrent);
		pDepthBuffer->initDepthBufferTexture(pCurrent);

		bool goodDepthBufferTexture = false;
		if (Context::DepthFramebufferTextures) {
			goodDepthBufferTexture = Context::WeakBlitFramebuffer ?
				pDepthBuffer->m_pDepthBufferTexture->realWidth == pCurrent->m_pTexture->realWidth :
				pDepthBuffer->m_pDepthBufferTexture->realWidth >= pCurrent->m_pTexture->realWidth;
		} else {
			goodDepthBufferTexture = pDepthBuffer->m_depthRenderbufferWidth == pCurrent->m_pTexture->realWidth;
		}

		if (goodDepthBufferTexture) {
			pCurrent->m_pDepthBuffer = pDepthBuffer;
			pDepthBuffer->setDepthAttachment(pCurrent->m_FBO, bufferTarget::DRAW_FRAMEBUFFER);
			if (config.frameBufferEmulation.N64DepthCompare != 0)
				pDepthBuffer->bindDepthImageTexture(pCurrent->m_FBO);
		} else
			pCurrent->m_pDepthBuffer = nullptr;
	} else
		pCurrent->m_pDepthBuffer = nullptr;

	assert(!gfxContext.isFramebufferError());
}

void FrameBufferList::clearDepthBuffer(DepthBuffer * _pDepthBuffer)
{
	for (auto iter = m_list.begin(); iter != m_list.end(); ++iter) {
		if (iter->m_pDepthBuffer == _pDepthBuffer) {
			iter->m_pDepthBuffer = nullptr;
		}
	}
}

void FrameBuffer_Init()
{
	frameBufferList().init();
	if (config.frameBufferEmulation.enable != 0) {
	ColorBufferToRDRAM::get().init();
	DepthBufferToRDRAM::get().init();
	RDRAMtoColorBuffer::get().init();
	}
}

void FrameBuffer_Destroy()
{
	RDRAMtoColorBuffer::get().destroy();
	DepthBufferToRDRAM::get().destroy();
	ColorBufferToRDRAM::get().destroy();
	frameBufferList().destroy();
}

void FrameBufferList::_renderScreenSizeBuffer()
{
	if (m_list.empty())
		return;

	DisplayWindow & wnd = dwnd();
	GraphicsDrawer & drawer = wnd.getDrawer();
	FrameBuffer *pBuffer = &m_list.back();
	PostProcessor & postProcessor = PostProcessor::get();
	FrameBuffer * pFilteredBuffer = pBuffer;
	for (const auto & f : postProcessor.getPostprocessingList())
		pFilteredBuffer = f(postProcessor, pFilteredBuffer);
	CachedTexture * pBufferTexture = pFilteredBuffer->m_pTexture;

	const u32 wndWidth = wnd.getWidth();
	const u32 wndHeight = wnd.getHeight();
	s32 srcCoord[4] = { 0, 0, static_cast<s32>(wndWidth), static_cast<s32>(wndHeight) };

	const u32 screenWidth = wnd.getScreenWidth();
	const u32 screenHeight = wnd.getScreenHeight();
	const u32 wndHeightOffset = wnd.getHeightOffset();
	const s32 hOffset = (screenWidth - wndWidth) / 2;
	const s32 vOffset = (screenHeight - wndHeight) / 2 + wndHeightOffset;
	s32 dstCoord[4] = { hOffset, vOffset, hOffset + static_cast<s32>(wndWidth), vOffset + static_cast<s32>(wndHeight) };

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);

	gfxContext.clearColorBuffer(0.0f, 0.0f, 0.0f, 0.0f);

	TextureParam filter = textureParameters::FILTER_LINEAR;

	GraphicsDrawer::BlitOrCopyRectParams blitParams;
	blitParams.srcX0 = srcCoord[0];
	blitParams.srcY0 = srcCoord[3];
	blitParams.srcX1 = srcCoord[2];
	blitParams.srcY1 = srcCoord[1];
	blitParams.srcWidth = wndWidth;
	blitParams.srcHeight = wndHeight;
	blitParams.dstX0 = dstCoord[0];
	blitParams.dstY0 = dstCoord[1];
	blitParams.dstX1 = dstCoord[2];
	blitParams.dstY1 = dstCoord[3];
	blitParams.dstWidth = screenWidth;
	blitParams.dstHeight = screenHeight + wndHeightOffset;
	blitParams.filter = filter;
	blitParams.mask = blitMask::COLOR_BUFFER;
	blitParams.tex[0] = pBufferTexture;
	blitParams.combiner = CombinerInfo::get().getTexrectCopyProgram();
	blitParams.readBuffer = pFilteredBuffer->m_FBO;

	drawer.blitOrCopyTexturedRect(blitParams);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);

	wnd.swapBuffers();
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, pBuffer->m_FBO);
	if (config.frameBufferEmulation.forceDepthBufferClear != 0) {
		drawer.clearDepthBuffer();
	}
	gDP.changed |= CHANGED_SCISSOR;
}

struct RdpUpdateResult {
	u32 vi_vres;
	u32 vi_hres;
	u32 vi_v_start;
	u32 vi_h_start;
	u32 vi_x_start;
	u32 vi_y_start;
	u32 vi_x_add;
	u32 vi_y_add;
	u32 vi_width;
	u32 vi_origin;
	bool vi_lowerfield;
	bool vi_fsaa;
	bool vi_divot;
	bool vi_ispal;
};

/* This function taken from angrylion's code and adopted for my needs */
static
bool rdp_update(RdpUpdateResult & _result)
{
	static const u32 PRESCALE_WIDTH = 640;
	static const u32 PRESCALE_HEIGHT = 625;
	static u32 oldvstart = 0;
	static bool prevwasblank = false;

	const u32 x_add = _SHIFTR(*REG.VI_X_SCALE, 0, 12);
	const u32 y_add = _SHIFTR(*REG.VI_Y_SCALE, 0, 12);
	const u32 v_sync = _SHIFTR(*REG.VI_V_SYNC, 0, 10);
	const bool ispal = (v_sync > 550);
	const u32 x1 = _SHIFTR( *REG.VI_H_START, 16, 10 );
	const u32 y1 = _SHIFTR( *REG.VI_V_START, 16, 10 );
	const u32 x2 = _SHIFTR( *REG.VI_H_START, 0, 10 );
	const u32 y2 = _SHIFTR( *REG.VI_V_START, 0, 10 );

	const u32 delta_x = x2 - x1;
	const u32 delta_y = y2 - y1;
	const u32 vitype = _SHIFTR( *REG.VI_STATUS, 0, 2 );

	const bool interlaced = (*REG.VI_STATUS & 0x40) != 0;
	const bool lowerfield = interlaced ? y1 > oldvstart : false;
	oldvstart = y1;

	u32 hres = delta_x;
	u32 vres = delta_y;
	s32 h_start = x1 - (ispal ? 128 : 108);
	s32 v_start = y1 - (ispal ? 47 : 37);
	u32 x_start = _SHIFTR(*REG.VI_X_SCALE, 16, 12);
	u32 y_start = _SHIFTR(*REG.VI_Y_SCALE, 16, 12);

	if (h_start < 0) {
		x_start -= x_add * h_start;
		h_start = 0;
	}
	v_start >>= 1;
	v_start &= -int(v_start >= 0);
	vres >>= 1;

	if (hres > PRESCALE_WIDTH - h_start)
		hres = PRESCALE_WIDTH - h_start;
	if (vres > PRESCALE_HEIGHT - v_start)
		vres = PRESCALE_HEIGHT - v_start;

	s32 vactivelines = v_sync - (ispal ? 47 : 37);
	if (vactivelines > PRESCALE_HEIGHT) {
		LOG(LOG_MINIMAL, "VI_V_SYNC_REG too big\n");
		return false;
	}

	if (vactivelines < 0) {
		LOG(LOG_MINIMAL, "vactivelines lesser than 0\n");
		return false;
	}

	if (hres <= 0 || vres <= 0 || ((vitype & 2) == 0 && prevwasblank)) /* early return. */
		return false;

	if (vitype >> 1 == 0) {
		prevwasblank = true;
		return false;
	}

	prevwasblank = false;

	_result.vi_hres = hres;
	_result.vi_vres = vres;
	_result.vi_ispal = ispal;
	_result.vi_h_start = h_start;
	_result.vi_v_start = v_start;
	_result.vi_x_start = x_start;
	_result.vi_y_start = y_start;
	_result.vi_x_add = x_add;
	_result.vi_y_add = y_add;
	_result.vi_width = _SHIFTR(*REG.VI_WIDTH, 0, 12);
	_result.vi_lowerfield = lowerfield;
	_result.vi_origin = _SHIFTR(*REG.VI_ORIGIN, 0, 24);
	_result.vi_fsaa = (*REG.VI_STATUS & 512) == 0;
	_result.vi_divot = (*REG.VI_STATUS & 16) != 0;
	return true;

#if 0
	{
		int pixels;
		int prevy, y_start;
		int cur_x, line_x;
		register int i;
		const int VI_width = *GET_GFX_INFO(VI_WIDTH) & 0x00000FFF;
		const int x_add = *GET_GFX_INFO(VI_X_SCALE) & 0x00000FFF;
		const int y_add = *GET_GFX_INFO(VI_Y_SCALE) & 0x00000FFF;

		y_start = *GET_GFX_INFO(VI_Y_SCALE) >> 16 & 0x0FFF;

		//while (--vres >= 0)
		{
			x_start = *GET_GFX_INFO(VI_X_SCALE) >> 16 & 0x0FFF;
			prescale_ptr += line_count;

			prevy = y_start >> 10;
			pixels = VI_width * prevy;

			//for (i = 0; i < hres; i++)
			{
				unsigned long pix;
				unsigned long addr;

				line_x = x_start >> 10;
				cur_x = pixels + line_x;

				x_start += x_add;
				addr = frame_buffer + 4 * cur_x;
				pix = *(int32_t *)(RDRAM + addr);
			}
			y_start += y_add;
		}
	}
#endif
}

s32 FrameBufferList::OverscanBuffer::getHOffset() const
{
	if (m_enabled)
		return 0;

	return m_hOffset;
}

s32 FrameBufferList::OverscanBuffer::getVOffset() const
{
	if (m_enabled)
		return 0;

	return m_vOffset;
}

f32 FrameBufferList::OverscanBuffer::getScaleX() const
{
	if (m_enabled)
		return m_scale;
	return dwnd().getScaleX();
}

f32 FrameBufferList::OverscanBuffer::getScaleY(u32 _fullHeight) const
{
	if (m_enabled)
		return m_scale;

	return (float)dwnd().getHeight() / float(_fullHeight);
}

void FrameBufferList::OverscanBuffer::init()
{
	m_enabled = config.frameBufferEmulation.enableOverscan != 0;
	if (m_enabled)
		m_FBO = gfxContext.createFramebuffer();

	DisplayWindow & wnd = dwnd();
	m_hOffset = (wnd.getScreenWidth() - wnd.getWidth()) / 2;
	m_vOffset = (wnd.getScreenHeight() - wnd.getHeight()) / 2;
	m_scale = wnd.getScaleX();
	m_drawingWidth = wnd.getWidth();
	m_bufferWidth = wnd.getScreenWidth();
	m_bufferHeight = wnd.getScreenHeight() + wnd.getHeightOffset();
}

void FrameBufferList::OverscanBuffer::destroy()
{
	gfxContext.deleteFramebuffer(m_FBO);
	m_FBO = graphics::ObjectHandle::null;
	textureCache().removeFrameBufferTexture(m_pTexture);
	m_pTexture = nullptr;
}

void FrameBufferList::OverscanBuffer::setInputBuffer(const FrameBuffer *  _pBuffer)
{
	if (!m_enabled) {
		return;
	}

	if (m_pTexture != nullptr &&
		m_pTexture->width == _pBuffer->m_pTexture->width &&
		m_pTexture->height == _pBuffer->m_pTexture->height &&
		m_scale == _pBuffer->m_scale) {
		return;
	}

	textureCache().removeFrameBufferTexture(m_pTexture);
	m_pTexture = textureCache().addFrameBufferTexture(false);
	const CachedTexture * pSrcTexture = _pBuffer->m_pTexture;
	_initFrameBufferTexture(0,
		_pBuffer->m_width,
		VI_GetMaxBufferHeight(_pBuffer->m_width),
		_pBuffer->m_scale,
		pSrcTexture->format,
		pSrcTexture->size,
		m_pTexture);
	_setAndAttachBufferTexture(m_FBO, m_pTexture, 0, false);
	m_scale = _pBuffer->m_scale;
	m_drawingWidth = m_bufferWidth = m_pTexture->width;
	m_bufferHeight = m_pTexture->height;
}

void FrameBufferList::OverscanBuffer::activate()
{
	if (!m_enabled) {
		gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
		return;
	}

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_FBO);
}

void FrameBufferList::OverscanBuffer::draw(u32 _fullHeight, bool _PAL)
{
	if (!m_enabled)
		return;

	DisplayWindow & wnd = dwnd();
	GraphicsDrawer & drawer = wnd.getDrawer();

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
	GraphicsDrawer::BlitOrCopyRectParams blitParams;
	const auto & overscan = _PAL ? config.frameBufferEmulation.overscanPAL : config.frameBufferEmulation.overscanNTSC;
	const s32 left = static_cast<s32>(overscan.left * m_scale);
	const s32 right = static_cast<s32>(overscan.right * m_scale);
	const s32 top = static_cast<s32>(overscan.top * m_scale);
	const s32 bottom = static_cast<s32>(overscan.bottom * m_scale);
	blitParams.srcX0 = left;
	blitParams.srcY0 = top;
	blitParams.srcX1 = m_bufferWidth - right;
	blitParams.srcY1 = static_cast<s32>(_fullHeight * m_scale) - bottom;
	blitParams.srcWidth = m_pTexture->realWidth;
	blitParams.srcHeight = m_pTexture->realHeight;
	blitParams.dstX0 = m_hOffset;
	blitParams.dstY0 = m_vOffset + wnd.getHeightOffset();
	blitParams.dstX1 = m_hOffset + wnd.getWidth();
	blitParams.dstY1 = m_vOffset + wnd.getHeight() + wnd.getHeightOffset();
	blitParams.dstWidth = wnd.getScreenWidth();
	blitParams.dstHeight = wnd.getScreenHeight() + wnd.getHeightOffset();
	blitParams.filter = textureParameters::FILTER_LINEAR;
	blitParams.mask = blitMask::COLOR_BUFFER;
	blitParams.tex[0] = m_pTexture;
	blitParams.combiner = CombinerInfo::get().getTexrectCopyProgram();
	blitParams.readBuffer = m_FBO;
	blitParams.invertY = true;

	gfxContext.clearColorBuffer(0.0f, 0.0f, 0.0f, 0.0f);
//	drawer.blitOrCopyTexturedRect(blitParams);
	drawer.copyTexturedRect(blitParams);
}

void FrameBufferList::renderBuffer()
{
	if (g_debugger.isDebugMode()) {
		g_debugger.draw();
		return;
	}

	if (config.frameBufferEmulation.enable == 0) {
		_renderScreenSizeBuffer();
		return;
	}

	RdpUpdateResult rdpRes;
	if (!rdp_update(rdpRes)) {
		gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
		gfxContext.clearColorBuffer(0.0f, 0.0f, 0.0f, 0.0f);
		dwnd().swapBuffers();
		if (m_pCurrent != nullptr)
			gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_pCurrent->m_FBO);
		return;
	}

	FrameBuffer *pBuffer = findBuffer(rdpRes.vi_origin);
	if (pBuffer == nullptr)
		return;
	pBuffer->m_isMainBuffer = true;
	m_overscan.setInputBuffer(pBuffer);

	DisplayWindow & wnd = dwnd();
	GraphicsDrawer & drawer = wnd.getDrawer();
	s32 srcY0, srcY1;
	s32 dstX0, dstX1, dstY0, dstY1;
	s32 srcWidth, srcHeight;
	s32 XoffsetLeft = 0, XoffsetRight = 0;
	s32 Xdivot = 0;
	s32 srcPartHeight = 0;
	s32 dstPartHeight = 0;

	dstY0 = rdpRes.vi_v_start;

	const u32 vFullHeight = rdpRes.vi_ispal ? 288 : 240;
	const f32 dstScaleY = m_overscan.getScaleY(vFullHeight);

	const u32 addrOffset = ((rdpRes.vi_origin - pBuffer->m_startAddress) << 1 >> pBuffer->m_size);
	srcY0 = addrOffset / pBuffer->m_width;
	if ((addrOffset != 0) && (pBuffer->m_width == addrOffset * 2))
		srcY0 = 1;

	if ((rdpRes.vi_width != addrOffset * 2) && (addrOffset % rdpRes.vi_width != 0))
		XoffsetRight = rdpRes.vi_width - addrOffset % rdpRes.vi_width;
	if (XoffsetRight == pBuffer->m_width) {
		XoffsetRight = 0;
	} else if (XoffsetRight > static_cast<s32>(pBuffer->m_width / 2)) {
		XoffsetRight = 0;
		XoffsetLeft = addrOffset % rdpRes.vi_width;
	}

	if (rdpRes.vi_lowerfield) {
		if (srcY0 > 0)
			--srcY0;
		if (dstY0 > 0)
			--dstY0;
	}

	srcWidth = min(rdpRes.vi_width, (rdpRes.vi_hres * rdpRes.vi_x_add) >> 10);
	srcHeight = rdpRes.vi_width * ((rdpRes.vi_vres*rdpRes.vi_y_add + rdpRes.vi_y_start) >> 10) / pBuffer->m_width;

	const u32 stride = pBuffer->m_width << pBuffer->m_size >> 1;
	FrameBuffer *pNextBuffer = findBuffer(rdpRes.vi_origin + stride * min(u32(srcHeight) - 1, pBuffer->m_height - 1) - 1);
	if (pNextBuffer == pBuffer)
		pNextBuffer = nullptr;

	if (pNextBuffer != nullptr) {
		dstPartHeight = srcY0;
		srcPartHeight = srcY0;
		srcY1 = srcHeight;
		dstY1 = dstY0 + rdpRes.vi_vres - dstPartHeight;
	} else {
		dstY1 = dstY0 + rdpRes.vi_vres;
		srcY1 = srcY0 + srcHeight;
	}
	PostProcessor & postProcessor = PostProcessor::get();
	FrameBuffer * pFilteredBuffer = pBuffer;
	for (const auto & f : postProcessor.getPostprocessingList())
		pFilteredBuffer = f(postProcessor, pFilteredBuffer);

	if (rdpRes.vi_fsaa && rdpRes.vi_divot)
		Xdivot = 1;

	const f32 viScaleX = _FIXED2FLOAT(_SHIFTR(*REG.VI_X_SCALE, 0, 12), 10);
	const f32 srcScaleX = pFilteredBuffer->m_scale;
	const f32 dstScaleX = m_overscan.getScaleX();
	const s32 hx0 = rdpRes.vi_h_start;
	const s32 h0 = (rdpRes.vi_ispal ? 128 : 108);
	const s32 hEnd = _SHIFTR(*REG.VI_H_START, 0, 10);
	const s32 hx1 = max(0, h0 + 640 - hEnd);
	//const s32 hx1 = hx0 + rdpRes.vi_hres;
	dstX0 = (s32)((hx0 * viScaleX + XoffsetRight) * dstScaleX);
	dstX1 = m_overscan.getDrawingWidth() - (s32)((hx1 * viScaleX + Xdivot) * dstScaleX);

	const f32 srcScaleY = pFilteredBuffer->m_scale;
	CachedTexture * pBufferTexture = pFilteredBuffer->m_pTexture;
	s32 srcCoord[4] = { (s32)(XoffsetLeft * srcScaleX),
						(s32)(srcY0*srcScaleY),
						(s32)((srcWidth + XoffsetLeft - XoffsetRight - Xdivot) * srcScaleX),
						min((s32)(srcY1*srcScaleY), (s32)pBufferTexture->realHeight) };
	if (srcCoord[2] > pBufferTexture->realWidth || srcCoord[3] > pBufferTexture->realHeight) {
		removeBuffer(pBuffer->m_startAddress);
		return;
	}

	const s32 hOffset = m_overscan.getHOffset();
	const s32 vOffset = m_overscan.getVOffset();
	s32 dstCoord[4] = { dstX0 + hOffset,
						vOffset + (s32)(dstY0*dstScaleY),
						hOffset + dstX1,
						vOffset + (s32)(dstY1*dstScaleY) };

	TextureParam filter = textureParameters::FILTER_LINEAR;
	ObjectHandle readBuffer;

	if (pFilteredBuffer->m_pTexture->frameBufferTexture == CachedTexture::fbMultiSample) {
		pFilteredBuffer->resolveMultisampledTexture(true);
		readBuffer = pFilteredBuffer->m_resolveFBO;
		pBufferTexture = pFilteredBuffer->m_pResolveTexture;
	} else {
		readBuffer = pFilteredBuffer->m_FBO;
	}

	m_overscan.activate();
	gfxContext.clearColorBuffer(0.0f, 0.0f, 0.0f, 0.0f);

	GraphicsDrawer::BlitOrCopyRectParams blitParams;
	blitParams.srcX0 = srcCoord[0];
	blitParams.srcY0 = srcCoord[1];
	blitParams.srcX1 = srcCoord[2];
	blitParams.srcY1 = srcCoord[3];
	blitParams.srcWidth = pBufferTexture->realWidth;
	blitParams.srcHeight = pBufferTexture->realHeight;
	blitParams.dstX0 = dstCoord[0];
	blitParams.dstY0 = dstCoord[1];
	blitParams.dstX1 = dstCoord[2];
	blitParams.dstY1 = dstCoord[3];
	blitParams.dstWidth = m_overscan.getBufferWidth();
	blitParams.dstHeight = m_overscan.getBufferHeight();
	blitParams.filter = filter;
	blitParams.mask = blitMask::COLOR_BUFFER;
	blitParams.tex[0] = pBufferTexture;
	blitParams.combiner = CombinerInfo::get().getTexrectCopyProgram();
	blitParams.readBuffer = readBuffer;
	blitParams.invertY = config.frameBufferEmulation.enableOverscan == 0;

	drawer.copyTexturedRect(blitParams);

	if (pNextBuffer != nullptr) {
		pNextBuffer->m_isMainBuffer = true;
		pFilteredBuffer = pNextBuffer;
		for (const auto & f : postProcessor.getPostprocessingList())
			pFilteredBuffer = f(postProcessor, pFilteredBuffer);
		srcY1 = srcPartHeight;
		dstY0 = dstY1;
		dstY1 = dstY0 + dstPartHeight;
		if (pFilteredBuffer->m_pTexture->frameBufferTexture == CachedTexture::fbMultiSample) {
			pFilteredBuffer->resolveMultisampledTexture();
			readBuffer = pFilteredBuffer->m_resolveFBO;
			pBufferTexture = pFilteredBuffer->m_pResolveTexture;
		}
		else {
			readBuffer = pFilteredBuffer->m_FBO;
			pBufferTexture = pFilteredBuffer->m_pTexture;
		}

		blitParams.srcY0 = 0;
		blitParams.srcY1 = min((s32)(srcY1*srcScaleY), (s32)pFilteredBuffer->m_pTexture->realHeight);
		blitParams.srcWidth = pBufferTexture->realWidth;
		blitParams.srcHeight = pBufferTexture->realHeight;
		blitParams.dstX0 = hOffset;
		blitParams.dstY0 = vOffset + (s32)(dstY0*dstScaleY);
		blitParams.dstX1 = hOffset + dstX1;
		blitParams.dstY1 = vOffset + (s32)(dstY1*dstScaleY);
		blitParams.dstWidth = m_overscan.getBufferWidth();
		blitParams.dstHeight = m_overscan.getBufferHeight();
		blitParams.tex[0] = pBufferTexture;
		blitParams.readBuffer = readBuffer;

		drawer.copyTexturedRect(blitParams);
	}

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::defaultFramebuffer);
	m_overscan.draw(vFullHeight, rdpRes.vi_ispal);

	wnd.swapBuffers();
	if (m_pCurrent != nullptr) {
		gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_pCurrent->m_FBO);
	}
	if (config.frameBufferEmulation.forceDepthBufferClear != 0) {
		drawer.clearDepthBuffer();
	}

	const s32 X = hOffset;
	const s32 Y = wnd.getHeightOffset();
	const s32 W = wnd.getWidth();
	const s32 H = wnd.getHeight();

	gfxContext.setScissor(X, Y, W, H);
	gDP.changed |= CHANGED_SCISSOR;
}

void FrameBufferList::fillRDRAM(s32 ulx, s32 uly, s32 lrx, s32 lry)
{
	if (m_pCurrent == nullptr)
		return;

	if (config.frameBufferEmulation.copyFromRDRAM !=0 && !m_pCurrent->m_isDepthBuffer)
		// Do not write to RDRAM color buffer if copyFromRDRAM enabled.
		return;

	ulx = (s32)min(max((float)ulx, gDP.scissor.ulx), gDP.scissor.lrx);
	lrx = (s32)min(max((float)lrx, gDP.scissor.ulx), gDP.scissor.lrx);
	uly = (s32)min(max((float)uly, gDP.scissor.uly), gDP.scissor.lry);
	lry = (s32)min(max((float)lry, gDP.scissor.uly), gDP.scissor.lry);

	const u32 stride = gDP.colorImage.width << gDP.colorImage.size >> 1;
	const u32 lowerBound = gDP.colorImage.address + lry*stride;
	if (lowerBound > RDRAMSize)
		lry -= (lowerBound - RDRAMSize) / stride;
	u32 ci_width_in_dwords = gDP.colorImage.width >> (3 - gDP.colorImage.size);
	ulx >>= (3 - gDP.colorImage.size);
	lrx >>= (3 - gDP.colorImage.size);
	u32 * dst = (u32*)(RDRAM + gDP.colorImage.address);
	dst += uly * ci_width_in_dwords;
	for (s32 y = uly; y < lry; ++y) {
		for (s32 x = ulx; x < lrx; ++x) {
			dst[x] = gDP.fillColor.color;
		}
		dst += ci_width_in_dwords;
	}

	m_pCurrent->setBufferClearParams(gDP.fillColor.color, ulx, uly, lrx, lry);
}

void FrameBuffer_ActivateBufferTexture(u32 t, u32 _frameBufferAddress)
{
	FrameBuffer * pBuffer = frameBufferList().getBuffer(_frameBufferAddress);
	if (pBuffer == nullptr)
		return;

	CachedTexture *pTexture = pBuffer->getTexture(t);
	if (pTexture == nullptr)
		return;

//	frameBufferList().renderBuffer(pBuffer->m_startAddress);
	textureCache().activateTexture(t, pTexture);
	gDP.changed |= CHANGED_FB_TEXTURE;
}

void FrameBuffer_ActivateBufferTextureBG(u32 t, u32 _frameBufferAddress)
{
	FrameBuffer * pBuffer = frameBufferList().getBuffer(_frameBufferAddress);
	if (pBuffer == nullptr)
		return;

	CachedTexture *pTexture = pBuffer->getTextureBG(t);
	if (pTexture == nullptr)
		return;

//	frameBufferList().renderBuffer(pBuffer->m_startAddress);
	textureCache().activateTexture(t, pTexture);
	gDP.changed |= CHANGED_FB_TEXTURE;
}

void FrameBuffer_CopyToRDRAM(u32 _address, bool _sync)
{
	ColorBufferToRDRAM::get().copyToRDRAM(_address, _sync);
}

void FrameBuffer_CopyChunkToRDRAM(u32 _address)
{
	ColorBufferToRDRAM::get().copyChunkToRDRAM(_address);
}

bool FrameBuffer_CopyDepthBuffer( u32 address )
{
	FrameBufferList & fblist = frameBufferList();
	FrameBuffer * pCopyBuffer = fblist.getCopyBuffer();
	if (pCopyBuffer != nullptr) {
		// This code is mainly to emulate Zelda MM camera.
		ColorBufferToRDRAM::get().copyToRDRAM(pCopyBuffer->m_startAddress, true);
		pCopyBuffer->m_RdramCopy.resize(0); // To disable validity check by RDRAM content. CPU may change content of the buffer for some unknown reason.
		fblist.setCopyBuffer(nullptr);
		return true;
	}

	if (DepthBufferToRDRAM::get().copyToRDRAM(address)) {
		fblist.depthBufferCopyRdram();
		return true;
	}

	return false;
}

bool FrameBuffer_CopyDepthBufferChunk(u32 address)
{
	return DepthBufferToRDRAM::get().copyChunkToRDRAM(address);
}

void FrameBuffer_CopyFromRDRAM(u32 _address, bool _bCFB)
{
	RDRAMtoColorBuffer::get().copyFromRDRAM(_address, _bCFB);
}

void FrameBuffer_AddAddress(u32 address, u32 _size)
{
	RDRAMtoColorBuffer::get().addAddress(address, _size);
}

u32 cutHeight(u32 _address, u32 _height, u32 _stride)
{
	return _cutHeight(_address, _height, _stride);
}

void calcCoordsScales(const FrameBuffer * _pBuffer, f32 & _scaleX, f32 & _scaleY)
{
	const u32 bufferWidth = _pBuffer != nullptr ? _pBuffer->m_width : VI.width;
	const u32 bufferHeight = VI_GetMaxBufferHeight(bufferWidth);
	_scaleX = 1.0f / f32(bufferWidth);
	_scaleY = 1.0f / f32(bufferHeight);
}
