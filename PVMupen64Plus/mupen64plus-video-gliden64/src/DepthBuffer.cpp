#if defined(OS_MAC_OS_X) || defined(OS_IOS)
#include <malloc/malloc.h>
#else
#include <malloc.h>
#endif
#include <assert.h>
#include "Combiner.h"
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "VI.h"
#include "Config.h"
#include "DebugDump.h"
#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include "DisplayWindow.h"

using namespace graphics;

DepthBuffer::DepthBuffer() : m_address(0), m_width(0), m_ulx(0), m_uly(0), m_lrx(0), m_lry(0),
	m_pDepthImageZTexture(nullptr), m_pDepthImageDeltaZTexture(nullptr), m_pDepthBufferTexture(nullptr),
	m_depthRenderbufferWidth(0), m_cleared(false), m_pResolveDepthBufferTexture(nullptr), m_resolved(false),
	m_pDepthBufferCopyTexture(nullptr), m_copied(false)
{
	m_copyFBO = gfxContext.createFramebuffer();
	if (config.frameBufferEmulation.N64DepthCompare != 0) {
	}
}

DepthBuffer::~DepthBuffer()
{
	gfxContext.deleteFramebuffer(m_depthRenderbuffer);
	gfxContext.deleteFramebuffer(m_copyFBO);

	textureCache().removeFrameBufferTexture(m_pDepthImageZTexture);
	textureCache().removeFrameBufferTexture(m_pDepthImageDeltaZTexture);
	textureCache().removeFrameBufferTexture(m_pDepthBufferTexture);
	textureCache().removeFrameBufferTexture(m_pResolveDepthBufferTexture);
	textureCache().removeFrameBufferTexture(m_pDepthBufferCopyTexture);
}

void DepthBuffer::_initDepthImageTexture(FrameBuffer * _pBuffer, CachedTexture& _cachedTexture)
{
	const FramebufferTextureFormats & fbTexFormat = gfxContext.getFramebufferTextureFormats();

	_cachedTexture.width = (u32)(_pBuffer->m_pTexture->width);
	_cachedTexture.height = (u32)(_pBuffer->m_pTexture->height);
	_cachedTexture.format = 0;
	_cachedTexture.size = 2;
	_cachedTexture.clampS = 1;
	_cachedTexture.clampT = 1;
	_cachedTexture.address = _pBuffer->m_startAddress;
	_cachedTexture.clampWidth = _pBuffer->m_width;
	_cachedTexture.clampHeight = _pBuffer->m_height;
	_cachedTexture.frameBufferTexture = CachedTexture::fbOneSample;
	_cachedTexture.maskS = 0;
	_cachedTexture.maskT = 0;
	_cachedTexture.mirrorS = 0;
	_cachedTexture.mirrorT = 0;
	_cachedTexture.realWidth = _cachedTexture.width;
	_cachedTexture.realHeight = _cachedTexture.height;
	_cachedTexture.textureBytes = _cachedTexture.realWidth * _cachedTexture.realHeight * fbTexFormat.depthImageFormatBytes;
	textureCache().addFrameBufferTextureSize(_cachedTexture.textureBytes);

	{
		Context::InitTextureParams params;
		params.handle = _cachedTexture.name;
		params.width = _cachedTexture.realWidth;
		params.height = _cachedTexture.realHeight;
		params.internalFormat = fbTexFormat.depthImageInternalFormat;
		params.format = fbTexFormat.depthImageFormat;
		params.dataType = fbTexFormat.depthImageType;
		gfxContext.init2DTexture(params);
	}
	{
		Context::TexParameters params;
		params.handle = _cachedTexture.name;
		params.target = textureTarget::TEXTURE_2D;
		params.textureUnitIndex = textureIndices::Tex[0];
		params.minFilter = textureParameters::FILTER_NEAREST;
		params.magFilter = textureParameters::FILTER_NEAREST;
		gfxContext.setTextureParameters(params);
	}
}

void DepthBuffer::initDepthImageTexture(FrameBuffer * _pBuffer)
{
	if (config.frameBufferEmulation.N64DepthCompare == 0 || m_pDepthImageZTexture != nullptr)
		return;

	m_pDepthImageZTexture = textureCache().addFrameBufferTexture(false);
	m_pDepthImageDeltaZTexture = textureCache().addFrameBufferTexture(false);

	_initDepthImageTexture(_pBuffer, *m_pDepthImageZTexture);
	_initDepthImageTexture(_pBuffer, *m_pDepthImageDeltaZTexture);

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, _pBuffer->m_FBO);

	depthBufferList().clearBuffer(0, 0, _pBuffer->m_width, _pBuffer->m_height);
}

void DepthBuffer::_initDepthBufferTexture(FrameBuffer * _pBuffer, CachedTexture * _pTexture, bool _multisample)
{
	const FramebufferTextureFormats & fbTexFormat = gfxContext.getFramebufferTextureFormats();

	if (_pBuffer != nullptr) {
		_pTexture->width = (u32)(_pBuffer->m_pTexture->width);
		_pTexture->height = (u32)(_pBuffer->m_pTexture->height);
		_pTexture->address = _pBuffer->m_startAddress;
		_pTexture->clampWidth = _pBuffer->m_width;
		_pTexture->clampHeight = VI_GetMaxBufferHeight(_pBuffer->m_width);
	} else {
		const u16 maxHeight = VI_GetMaxBufferHeight(VI.width);
		if (config.frameBufferEmulation.nativeResFactor == 0) {
			_pTexture->width = dwnd().getWidth();
			_pTexture->height = (u16)(u32)(maxHeight * dwnd().getScaleX());
		} else {
			_pTexture->width = VI.width * config.frameBufferEmulation.nativeResFactor;
			_pTexture->height = maxHeight * config.frameBufferEmulation.nativeResFactor;
		}
		_pTexture->address = gDP.depthImageAddress;
		_pTexture->clampWidth = VI.width;
		_pTexture->clampHeight = maxHeight;
	}
	_pTexture->format = 0;
	_pTexture->size = 2;
	_pTexture->clampS = 1;
	_pTexture->clampT = 1;
	_pTexture->frameBufferTexture = CachedTexture::fbOneSample;
	_pTexture->maskS = 0;
	_pTexture->maskT = 0;
	_pTexture->mirrorS = 0;
	_pTexture->mirrorT = 0;
	_pTexture->realWidth = _pTexture->width;
	_pTexture->realHeight = _pTexture->height;
	_pTexture->textureBytes = _pTexture->realWidth * _pTexture->realHeight * fbTexFormat.depthFormatBytes;
	textureCache().addFrameBufferTextureSize(_pTexture->textureBytes);

	Context::InitTextureParams initParams;
	initParams.handle = _pTexture->name;
	initParams.msaaLevel = _multisample ? config.video.multisampling : 0U;
	initParams.width = _pTexture->realWidth;
	initParams.height = _pTexture->realHeight;
	initParams.internalFormat = fbTexFormat.depthInternalFormat;
	initParams.format = fbTexFormat.depthFormat;
	initParams.dataType = fbTexFormat.depthType;
	gfxContext.init2DTexture(initParams);

	if (!_multisample) {
		_pTexture->frameBufferTexture = CachedTexture::fbOneSample;
		Context::TexParameters texParams;
		texParams.handle = _pTexture->name;
		texParams.target = textureTarget::TEXTURE_2D;
		texParams.textureUnitIndex = textureIndices::Tex[0];
		texParams.minFilter = textureParameters::FILTER_NEAREST;
		texParams.magFilter = textureParameters::FILTER_NEAREST;
		gfxContext.setTextureParameters(texParams);
	} else {
		_pTexture->frameBufferTexture = CachedTexture::fbMultiSample;
	}
}

void DepthBuffer::_initDepthBufferRenderbuffer(FrameBuffer * _pBuffer)
{
	if (m_depthRenderbuffer.isNotNull())
		return;
	u32 height;
	if (_pBuffer != NULL) {
		m_depthRenderbufferWidth = (u32)(_pBuffer->m_pTexture->width);
		height = (u32)(_pBuffer->m_pTexture->height);
	} else {
		if (config.frameBufferEmulation.nativeResFactor == 0) {
			m_depthRenderbufferWidth = dwnd().getWidth();
			height = (u32)(VI_GetMaxBufferHeight(VI.width) * dwnd().getScaleX());
		} else {
			m_depthRenderbufferWidth = VI.width * config.frameBufferEmulation.nativeResFactor;
			height = VI_GetMaxBufferHeight(VI.width) * config.frameBufferEmulation.nativeResFactor;
		}
	}

	m_depthRenderbuffer = gfxContext.createRenderbuffer();
	Context::InitRenderbufferParams params;
	params.handle = m_depthRenderbuffer;
	params.target = textureTarget::RENDERBUFFER;
	params.format = gfxContext.getFramebufferTextureFormats().depthInternalFormat;
	params.width = m_depthRenderbufferWidth;
	params.height = height;
	gfxContext.initRenderbuffer(params);
}

void DepthBuffer::setDepthAttachment(ObjectHandle _fbo, BufferTargetParam _target)
{
	Context::FrameBufferRenderTarget params;
	params.attachment = bufferAttachment::DEPTH_ATTACHMENT;
	params.bufferHandle = _fbo;
	params.bufferTarget = _target;
	if (gfxContext.isSupported(SpecialFeatures::DepthFramebufferTextures)) {
		params.textureHandle = m_pDepthBufferTexture->name;
		params.textureTarget = config.video.multisampling != 0 ? textureTarget::TEXTURE_2D_MULTISAMPLE : textureTarget::TEXTURE_2D;
	} else {
		params.textureHandle = m_depthRenderbuffer;
		params.textureTarget = textureTarget::RENDERBUFFER;
	}
	gfxContext.addFrameBufferRenderTarget(params);

	m_copied = false;
	m_resolved = false;
}

void DepthBuffer::initDepthBufferTexture(FrameBuffer * _pBuffer)
{
	if (gfxContext.isSupported(SpecialFeatures::DepthFramebufferTextures)) {
		if (m_pDepthBufferTexture == nullptr) {
			m_pDepthBufferTexture = textureCache().addFrameBufferTexture(config.video.multisampling != 0);
			_initDepthBufferTexture(_pBuffer, m_pDepthBufferTexture, config.video.multisampling != 0);
		}
	} else {
		_initDepthBufferRenderbuffer(_pBuffer);
	}

	if (config.video.multisampling != 0 && m_pResolveDepthBufferTexture == nullptr) {
		m_pResolveDepthBufferTexture = textureCache().addFrameBufferTexture(false);
		_initDepthBufferTexture(_pBuffer, m_pResolveDepthBufferTexture, false);
	}
}

CachedTexture * DepthBuffer::resolveDepthBufferTexture(FrameBuffer * _pBuffer)
{
	if (config.video.multisampling == 0)
		return m_pDepthBufferTexture;

	if (m_resolved)
		return m_pResolveDepthBufferTexture;

	Context::FrameBufferRenderTarget targetParams;
	targetParams.attachment = bufferAttachment::DEPTH_ATTACHMENT;
	targetParams.bufferHandle = _pBuffer->m_resolveFBO;
	targetParams.bufferTarget = bufferTarget::DRAW_FRAMEBUFFER;
	targetParams.textureHandle = m_pResolveDepthBufferTexture->name;
	targetParams.textureTarget = textureTarget::TEXTURE_2D;
	gfxContext.addFrameBufferRenderTarget(targetParams);

	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = _pBuffer->m_FBO;
	blitParams.drawBuffer = _pBuffer->m_resolveFBO;
	blitParams.srcX0 = 0;
	blitParams.srcY0 = 0;
	blitParams.srcX1 = m_pDepthBufferTexture->realWidth;
	blitParams.srcY1 = m_pDepthBufferTexture->realHeight;
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = m_pResolveDepthBufferTexture->realWidth;
	blitParams.dstY1 = m_pResolveDepthBufferTexture->realHeight;
	blitParams.mask = blitMask::DEPTH_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::null);
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, _pBuffer->m_FBO);

	m_resolved = true;
	return m_pResolveDepthBufferTexture;
}

CachedTexture * DepthBuffer::copyDepthBufferTexture(FrameBuffer * _pBuffer)
{
	if (m_copied)
		return m_pDepthBufferCopyTexture;

	if (m_pDepthBufferCopyTexture == nullptr) {
		m_pDepthBufferCopyTexture = textureCache().addFrameBufferTexture(false);
		_initDepthBufferTexture(_pBuffer, m_pDepthBufferCopyTexture, false);
	}


	Context::FrameBufferRenderTarget targetParams;
	targetParams.bufferHandle = m_copyFBO;
	targetParams.bufferTarget = bufferTarget::DRAW_FRAMEBUFFER;
	targetParams.attachment = bufferAttachment::COLOR_ATTACHMENT0;
	targetParams.textureHandle = _pBuffer->m_pTexture->frameBufferTexture == CachedTexture::fbMultiSample ?
		_pBuffer->m_pResolveTexture->name :
		_pBuffer->m_pTexture->name;
	targetParams.textureTarget = textureTarget::TEXTURE_2D;

	gfxContext.addFrameBufferRenderTarget(targetParams);

	targetParams.attachment = bufferAttachment::DEPTH_ATTACHMENT;
	targetParams.textureHandle = m_pDepthBufferCopyTexture->name;

	gfxContext.addFrameBufferRenderTarget(targetParams);


	Context::BlitFramebuffersParams blitParams;
	blitParams.readBuffer = _pBuffer->m_FBO;
	blitParams.drawBuffer = m_copyFBO;
	blitParams.srcX0 = 0;
	blitParams.srcY0 = 0;
	blitParams.srcX1 = m_pDepthBufferTexture->realWidth;
	blitParams.srcY1 = m_pDepthBufferTexture->realHeight;
	blitParams.dstX0 = 0;
	blitParams.dstY0 = 0;
	blitParams.dstX1 = m_pDepthBufferTexture->realWidth;
	blitParams.dstY1 = m_pDepthBufferTexture->realHeight;
	blitParams.mask = blitMask::DEPTH_BUFFER;
	blitParams.filter = textureParameters::FILTER_NEAREST;

	gfxContext.blitFramebuffers(blitParams);

	gfxContext.bindFramebuffer(bufferTarget::READ_FRAMEBUFFER, ObjectHandle::null);
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, _pBuffer->m_FBO);

	m_copied = true;
	return m_pDepthBufferCopyTexture;
}

void DepthBuffer::activateDepthBufferTexture(FrameBuffer * _pBuffer)
{
	textureCache().activateTexture(0, resolveDepthBufferTexture(_pBuffer));
}

void DepthBuffer::bindDepthImageTexture()
{
	if (!Context::imageTextures)
		return;

	Context::BindImageTextureParameters bindParams;
	bindParams.imageUnit = textureImageUnits::DepthZ;
	bindParams.texture = m_pDepthImageZTexture->name;
	bindParams.accessMode = textureImageAccessMode::READ_WRITE;
	bindParams.textureFormat = gfxContext.getFramebufferTextureFormats().depthImageInternalFormat;
	gfxContext.bindImageTexture(bindParams);

	bindParams.imageUnit = textureImageUnits::DepthDeltaZ;
	bindParams.texture = m_pDepthImageDeltaZTexture->name;
	gfxContext.bindImageTexture(bindParams);
}

DepthBufferList::DepthBufferList() : m_pCurrent(nullptr), m_pzLUT(nullptr)
{
	m_pzLUT = new u16[0x40000];
	for (int i = 0; i<0x40000; i++) {
		u32 exponent = 0;
		u32 testbit = 1 << 17;
		while ((i & testbit) && (exponent < 7)) {
			exponent++;
			testbit = 1 << (17 - exponent);
		}

		const u32 mantissa = (i >> (6 - (6 < exponent ? 6 : exponent))) & 0x7ff;
		m_pzLUT[i] = (u16)(((exponent << 11) | mantissa) << 2);
	}
}

DepthBufferList::~DepthBufferList()
{
	delete[] m_pzLUT;
	m_pzLUT = nullptr;
	m_list.clear();
}

DepthBufferList & DepthBufferList::get()
{
	static DepthBufferList depthBufferList;
	return depthBufferList;
}

void DepthBufferList::init()
{
	m_pCurrent = nullptr;
}

void DepthBufferList::destroy()
{
	m_pCurrent = nullptr;
	m_list.clear();
}

void DepthBufferList::setNotCleared()
{
	for (DepthBuffers::iterator iter = m_list.begin(); iter != m_list.end(); ++iter)
		iter->m_cleared = false;
}

DepthBuffer * DepthBufferList::findBuffer(u32 _address)
{
	for (DepthBuffers::iterator iter = m_list.begin(); iter != m_list.end(); ++iter)
		if (iter->m_address == _address)
				return &(*iter);
	return nullptr;
}

void DepthBufferList::removeBuffer(u32 _address )
{
	for (DepthBuffers::iterator iter = m_list.begin(); iter != m_list.end(); ++iter)
		if (iter->m_address == _address) {
			frameBufferList().clearDepthBuffer(&(*iter));
			m_list.erase(iter);
			return;
		}
}

void DepthBufferList::_createScreenSizeBuffer(u32 _address)
{
	FrameBuffer * pFrameBuffer = frameBufferList().findBuffer(VI.width*2);
	if (pFrameBuffer == nullptr)
		return;

	m_list.emplace_front();
	DepthBuffer & buffer = m_list.front();

	buffer.m_address = _address;
	buffer.m_width = pFrameBuffer->m_width;

	buffer.initDepthBufferTexture(pFrameBuffer);

	m_pCurrent = &buffer;
	frameBufferList().attachDepthBuffer();
	m_pCurrent = nullptr;
}

void DepthBufferList::saveBuffer(u32 _address)
{
	if (config.frameBufferEmulation.enable == 0) {
		if (m_list.empty())
			_createScreenSizeBuffer(_address);
		return;
	}

	FrameBuffer * pFrameBuffer = frameBufferList().findBuffer(_address);
	if (pFrameBuffer != nullptr)
		pFrameBuffer->m_isDepthBuffer = true;

	DepthBuffer * pDepthBuffer = findBuffer(_address);

	if (pDepthBuffer != nullptr && pFrameBuffer != nullptr && pDepthBuffer->m_width != pFrameBuffer->m_width) {
		removeBuffer(_address);
		pDepthBuffer = nullptr;
	}

	if (pDepthBuffer == nullptr) {
		m_list.emplace_front();
		DepthBuffer & buffer = m_list.front();

		buffer.m_address = _address;
		buffer.m_width = pFrameBuffer != nullptr ? pFrameBuffer->m_width : VI.width;

		buffer.initDepthBufferTexture(pFrameBuffer);

		pDepthBuffer = &buffer;
	}

	DepthBuffer * pCurrent = m_pCurrent;
	m_pCurrent = pDepthBuffer;
	frameBufferList().attachDepthBuffer();
	if (pDepthBuffer->m_address != gDP.depthImageAddress)
		m_pCurrent = pCurrent;
}

void DepthBufferList::clearBuffer(u32 _ulx, u32 _uly, u32 _lrx, u32 _lry)
{
	if (m_pCurrent == nullptr)
		return;

	m_pCurrent->m_cleared = true;
	m_pCurrent->m_ulx = _ulx;
	m_pCurrent->m_uly = _uly;
	m_pCurrent->m_lrx = _lrx;
	m_pCurrent->m_lry = _lry;
}

void DepthBuffer_Init()
{
	depthBufferList().init();
}

void DepthBuffer_Destroy()
{
	depthBufferList().destroy();
}
