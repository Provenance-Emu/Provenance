#include "RDRAMtoColorBuffer.h"

#include <FrameBufferInfo.h>
#include <FrameBuffer.h>
#include <Combiner.h>
#include <Textures.h>
#include <Config.h>
#include <N64.h>
#include <VI.h>

#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include <DisplayWindow.h>
#include <algorithm>

using namespace graphics;

RDRAMtoColorBuffer::RDRAMtoColorBuffer()
	: m_pCurBuffer(nullptr)
	, m_pTexture(nullptr) {
}

RDRAMtoColorBuffer & RDRAMtoColorBuffer::get()
{
	static RDRAMtoColorBuffer toCB;
	return toCB;
}

void RDRAMtoColorBuffer::init()
{
	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	m_pTexture = textureCache().addFrameBufferTexture(false);
	m_pTexture->format = G_IM_FMT_RGBA;
	m_pTexture->size = 2;
	m_pTexture->clampS = 1;
	m_pTexture->clampT = 1;
	m_pTexture->frameBufferTexture = CachedTexture::fbOneSample;
	m_pTexture->maskS = 0;
	m_pTexture->maskT = 0;
	m_pTexture->mirrorS = 0;
	m_pTexture->mirrorT = 0;
	m_pTexture->realWidth = 640;
	m_pTexture->realHeight = 580;
	m_pTexture->textureBytes = m_pTexture->realWidth * m_pTexture->realHeight * fbTexFormats.colorFormatBytes;
	textureCache().addFrameBufferTextureSize(m_pTexture->textureBytes);

	Context::InitTextureParams initParams;
	initParams.handle = m_pTexture->name;
	initParams.width = m_pTexture->realWidth;
	initParams.height = m_pTexture->realHeight;
	initParams.internalFormat = fbTexFormats.colorInternalFormat;
	initParams.format = fbTexFormats.colorFormat;
	initParams.dataType = fbTexFormats.colorType;
	gfxContext.init2DTexture(initParams);

	Context::TexParameters setParams;
	setParams.handle = m_pTexture->name;
	setParams.target = textureTarget::TEXTURE_2D;
	setParams.textureUnitIndex = textureIndices::Tex[0];
	setParams.minFilter = textureParameters::FILTER_LINEAR;
	setParams.magFilter = textureParameters::FILTER_LINEAR;
	gfxContext.setTextureParameters(setParams);

	m_pbuf.reset(gfxContext.createPixelWriteBuffer(m_pTexture->textureBytes));
}

void RDRAMtoColorBuffer::destroy()
{
	if (m_pTexture != nullptr) {
		textureCache().removeFrameBufferTexture(m_pTexture);
		m_pTexture = nullptr;
	}
	m_pbuf.reset();
}

void RDRAMtoColorBuffer::addAddress(u32 _address, u32 _size)
{
	if (m_pCurBuffer == nullptr) {
		m_pCurBuffer = frameBufferList().findBuffer(_address);
		if (m_pCurBuffer == nullptr)
			return;
	}

	const u32 pixelSize = 1 << m_pCurBuffer->m_size >> 1;
	if (_size != pixelSize && (_address%pixelSize) > 0)
		return;
	m_vecAddress.push_back(_address);
	gDP.colorImage.changed = TRUE;
}

// Write the whole buffer
template <typename TSrc>
bool _copyBufferFromRdram(u32 _address, u32* _dst, u32(*converter)(TSrc _c, bool _bCFB), u32 _xor, u32 _x0, u32 _y0, u32 _width, u32 _height, bool _bCFB)
{
	TSrc * src = reinterpret_cast<TSrc*>(RDRAM + _address);
	const u32 bound = (RDRAMSize + 1 - _address) >> (sizeof(TSrc) / 2);
	TSrc col;
	u32 idx;
	u32 summ = 0;
	u32 dsty = 0;
	const u32 y1 = _y0 + _height;
	for (u32 y = _y0; y < y1; ++y) {
		for (u32 x = _x0; x < _width; ++x) {
			idx = (x + y *_width) ^ _xor;
			if (idx >= bound)
				break;
			col = src[idx];
			summ += col;
			_dst[x + dsty*_width] = converter(col, _bCFB);
		}
		++dsty;
	}

	return summ != 0;
}

// Write only pixels provided with FBWrite
template <typename TSrc>
bool _copyPixelsFromRdram(u32 _address, const std::vector<u32> & _vecAddress, u32* _dst, u32(*converter)(TSrc _c, bool _bCFB), u32 _xor, u32 _width, u32 _height, bool _bCFB)
{
	memset(_dst, 0, _width*_height*sizeof(u32));
	TSrc * src = reinterpret_cast<TSrc*>(RDRAM + _address);
	const u32 szPixel = sizeof(TSrc);
	const size_t numPixels = _vecAddress.size();
	TSrc col;
	u32 summ = 0;
	u32 idx, w, h;
	for (size_t i = 0; i < numPixels; ++i) {
		if (_vecAddress[i] < _address)
			return false;
		idx = (_vecAddress[i] - _address) / szPixel;
		w = idx % _width;
		h = idx / _width;
		if (h > _height)
			return false;
		col = src[idx];
		summ += col;
		_dst[(w + h * _width) ^ _xor] = converter(col, _bCFB);
	}

	return summ != 0;
}

static
u32 RGBA16ToABGR32(u16 col, bool _bCFB)
{
	u32 r, g, b, a;
	r = ((col >> 11) & 31) << 3;
	g = ((col >> 6) & 31) << 3;
	b = ((col >> 1) & 31) << 3;
	if (_bCFB)
		a = 0xFF;
	else
		a = (col & 1) > 0 ? 0xFF : 0U;
	return ((a << 24) | (b << 16) | (g << 8) | r);
}

static
u32 RGBA32ToABGR32(u32 col, bool _bCFB)
{
	u32 r, g, b, a;
	r = (col >> 24) & 0xff;
	g = (col >> 16) & 0xff;
	b = (col >> 8) & 0xff;
	if (_bCFB)
		a = 0xFF;
	else
		a = col & 0xFF;
	return ((a << 24) | (b << 16) | (g << 8) | r);
}

void RDRAMtoColorBuffer::copyFromRDRAM(u32 _address, bool _bCFB)
{
	Cleaner cleaner(this);

	if (m_pCurBuffer == nullptr) {
		if (_bCFB || (config.frameBufferEmulation.copyFromRDRAM != 0 && !FBInfo::fbInfo.isSupported()))
			m_pCurBuffer = frameBufferList().findBuffer(_address);
	} else {
		if (m_vecAddress.empty())
			return;
		frameBufferList().setCurrent(m_pCurBuffer);
	}

	if (m_pCurBuffer == nullptr || m_pCurBuffer->m_size < G_IM_SIZ_16b)
		return;

	if (m_pCurBuffer->m_startAddress == _address && gDP.colorImage.changed != 0)
		return;

	const u32 address = m_pCurBuffer->m_startAddress;

	const u32 height = cutHeight(address, m_pCurBuffer->m_startAddress == _address ? VI.real_height : VI_GetMaxBufferHeight(m_pCurBuffer->m_width), m_pCurBuffer->m_width << m_pCurBuffer->m_size >> 1);
	if (height == 0)
		return;

	const u32 width = m_pCurBuffer->m_width;

	const u32 x0 = 0;
	const u32 y0 = 0;
	const u32 y1 = y0 + height;

	const bool bUseAlpha = !_bCFB && m_pCurBuffer->m_changed;

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	m_pTexture->width = width;
	m_pTexture->height = height;
	const u32 gpuDataSize = width*height * fbTexFormats.colorFormatBytes;

	PixelBufferBinder<PixelWriteBuffer> binder(m_pbuf.get());
	u8* ptr = (u8*)m_pbuf->getWriteBuffer(gpuDataSize);
	if (ptr == nullptr)
		return;

	u32 * dst = nullptr;
	std::unique_ptr<u8[]> dstData;

	//If not using float, the initial coversion will already be correct
	if (fbTexFormats.colorType == datatype::FLOAT) {
		const u32 initialDataSize = width*height * 4;
		dstData = std::unique_ptr<u8[]>(new u8[initialDataSize]);
		dst = reinterpret_cast<u32*>(dstData.get());
	} else {
		dst = reinterpret_cast<u32*>(ptr);
	}

	bool bCopy;
	if (m_vecAddress.empty()) {
		if (m_pCurBuffer->m_size == G_IM_SIZ_16b)
			bCopy = _copyBufferFromRdram<u16>(address, dst, RGBA16ToABGR32, 1, x0, y0, width, height, _bCFB);
		else
			bCopy = _copyBufferFromRdram<u32>(address, dst, RGBA32ToABGR32, 0, x0, y0, width, height, _bCFB);
	}
	else {
		if (m_pCurBuffer->m_size == G_IM_SIZ_16b)
			bCopy = _copyPixelsFromRdram<u16>(address, m_vecAddress, dst, RGBA16ToABGR32, 1, width, height, _bCFB);
		else
			bCopy = _copyPixelsFromRdram<u32>(address, m_vecAddress, dst, RGBA32ToABGR32, 0, width, height, _bCFB);
	}

	//Convert integer format to float
	if (fbTexFormats.colorType == datatype::FLOAT) {
		f32* floatData = reinterpret_cast<f32*>(ptr);
		u8* byteData = dstData.get();
		const u32 widthPixels = width*4;
		for (unsigned int heightIndex = 0; heightIndex < height; ++heightIndex) {
			for (unsigned int widthIndex = 0; widthIndex < widthPixels; ++widthIndex) {
				u8& src = *(byteData + heightIndex*widthPixels + widthIndex);
				float& dst = *(floatData + heightIndex*widthPixels + widthIndex);
				dst = src/255.0f;
			}
		}
	}

	if (!FBInfo::fbInfo.isSupported()) {
		if (bUseAlpha && config.frameBufferEmulation.copyToRDRAM == Config::ctDisable) {
			u32 totalBytes = (width * height) << m_pCurBuffer->m_size >> 1;
			if (address + totalBytes > RDRAMSize + 1)
				totalBytes = RDRAMSize + 1 - address;
			memset(RDRAM + address, 0, totalBytes);
		}
	}

	m_pbuf->closeWriteBuffer();

	if (!bCopy)
		return;

	const u32 cycleType = gDP.otherMode.cycleType;
	gDP.otherMode.cycleType = G_CYC_COPY;
	CombinerInfo::get().setPolygonMode(DrawingState::TexRect);
	CombinerInfo::get().update();
	gDP.otherMode.cycleType = cycleType;

	Context::UpdateTextureDataParams updateParams;
	updateParams.handle = m_pTexture->name;
	updateParams.textureUnitIndex = textureIndices::Tex[0];
	updateParams.width = width;
	updateParams.height = height;
	updateParams.format = fbTexFormats.colorFormat;
	updateParams.dataType = fbTexFormats.colorType;
	updateParams.data = m_pbuf->getData();
	gfxContext.update2DTexture(updateParams);

	m_pTexture->scaleS = 1.0f / (float)m_pTexture->realWidth;
	m_pTexture->scaleT = 1.0f / (float)m_pTexture->realHeight;
	m_pTexture->shiftScaleS = 1.0f;
	m_pTexture->shiftScaleT = 1.0f;
	m_pTexture->offsetS = 0.0f;
	m_pTexture->offsetT = 0.0f;
	textureCache().activateTexture(0, m_pTexture);

	gDPTile tile0 = {0};
	gDPTile * pTile0 = gSP.textureTile[0];
	gSP.textureTile[0] = &tile0;

	gfxContext.enable(enable::BLEND, true);
	gfxContext.setBlending(blend::SRC_ALPHA, blend::ONE_MINUS_SRC_ALPHA);
	gfxContext.enable(enable::DEPTH_TEST, false);
	gfxContext.enable(enable::SCISSOR_TEST, false);

	CombinerInfo::get().updateParameters();

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_pCurBuffer->m_FBO);

	GraphicsDrawer::TexturedRectParams texRectParams((float)x0, (float)y0, (float)width, (float)height,
										 1.0f, 1.0f, 0, 0,
										 false, true, false, m_pCurBuffer);
	dwnd().getDrawer().drawTexturedRect(texRectParams);

	frameBufferList().setCurrentDrawBuffer();

	gSP.textureTile[0] = pTile0;

	gDP.changed |= CHANGED_RENDERMODE | CHANGED_COMBINE | CHANGED_SCISSOR;
}

void RDRAMtoColorBuffer::reset()
{
	m_pCurBuffer = nullptr;
	m_vecAddress.clear();
}
