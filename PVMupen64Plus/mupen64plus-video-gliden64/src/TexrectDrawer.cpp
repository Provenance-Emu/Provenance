#include <assert.h>
#include <algorithm>
#include <cstring>
#include <cmath>
#include <Graphics/Context.h>
#include <Graphics/Parameters.h>
#include "DisplayWindow.h"
#include "Textures.h"
#include "VI.h"
#include "FrameBuffer.h"
#include "TexrectDrawer.h"

using namespace graphics;

TexrectDrawer::TexrectDrawer()
: m_numRects(0)
, m_otherMode(0)
, m_mux(0)
, m_ulx(0)
, m_lrx(0)
, m_uly(0)
, m_lry(0)
, m_Z(0)
, m_max_lrx(0)
, m_max_lry(0)
, m_scissor(gDPScissor())
, m_pTexture(nullptr)
, m_pBuffer(nullptr)
{}

void TexrectDrawer::init()
{
	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	m_FBO = gfxContext.createFramebuffer();

	m_pTexture = textureCache().addFrameBufferTexture(false);
	m_pTexture->format = G_IM_FMT_RGBA;
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
	m_stepX = 2.0f / 640.0f;
	m_stepY = 2.0f / 580.0f;

	Context::InitTextureParams initParams;
	initParams.handle = m_pTexture->name;
	initParams.textureUnitIndex = textureIndices::Tex[0];
	initParams.width = m_pTexture->realWidth;
	initParams.height = m_pTexture->realHeight;
	initParams.internalFormat = fbTexFormats.colorInternalFormat;
	initParams.format = fbTexFormats.colorFormat;
	initParams.dataType = fbTexFormats.colorType;
	gfxContext.init2DTexture(initParams);

	Context::TexParameters texParams;
	texParams.handle = m_pTexture->name;
	texParams.target = textureTarget::TEXTURE_2D;
	texParams.textureUnitIndex = textureIndices::Tex[0];
	texParams.minFilter = textureParameters::FILTER_LINEAR;
	texParams.magFilter = textureParameters::FILTER_LINEAR;
	gfxContext.setTextureParameters(texParams);


	Context::FrameBufferRenderTarget bufTarget;
	bufTarget.bufferHandle = m_FBO;
	bufTarget.bufferTarget = bufferTarget::DRAW_FRAMEBUFFER;
	bufTarget.attachment = bufferAttachment::COLOR_ATTACHMENT0;
	bufTarget.textureTarget = textureTarget::TEXTURE_2D;
	bufTarget.textureHandle = m_pTexture->name;
	gfxContext.addFrameBufferRenderTarget(bufTarget);

	// check if everything is OK
	assert(!gfxContext.isFramebufferError());
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, ObjectHandle::null);

	m_programTex.reset(gfxContext.createTexrectDrawerDrawShader());
	m_programClear.reset(gfxContext.createTexrectDrawerClearShader());
	m_programTex->setTextureSize(m_pTexture->realWidth, m_pTexture->realHeight);

	m_vecRectCoords.reserve(256);
}

void TexrectDrawer::destroy()
{
	gfxContext.deleteFramebuffer(m_FBO);
	if (m_pTexture != nullptr) {
		textureCache().removeFrameBufferTexture(m_pTexture);
		m_pTexture = nullptr;
	}
	m_programTex.reset();
	m_programClear.reset();
}

void TexrectDrawer::_setViewport() const
{
	const u32 bufferWidth = m_pBuffer == nullptr ? VI.width : m_pBuffer->m_width;
	gfxContext.setViewport(0, 0, bufferWidth, VI_GetMaxBufferHeight(bufferWidth));
}

void TexrectDrawer::add()
{
	DisplayWindow & wnd = dwnd();
	GraphicsDrawer &  drawer = wnd.getDrawer();
	RectVertex * pRect = drawer.m_rect;

	bool bDownUp = false;
	if (m_numRects != 0) {
		bool bContinue = false;
		if (m_otherMode == gDP.otherMode._u64 && m_mux == gDP.combine.mux) {
			const float scaleY = (m_pBuffer != nullptr ? m_pBuffer->m_height : VI.height) / 2.0f;
			if (m_ulx == pRect[0].x) {
				//			bContinue = m_lry == pRect[0].y;
				bContinue = fabs((m_lry - pRect[0].y) * scaleY) < 1.1f; // Fix for Mario Kart
				bDownUp = m_uly == pRect[3].y;
				bContinue |= bDownUp;
			}
			else {
				for (auto iter = m_vecRectCoords.crbegin(); iter != m_vecRectCoords.crend(); ++iter) {
					if (iter->x == pRect[0].x && iter->y == pRect[0].y) {
						bContinue = true;
						break;
					}
				}
			}
		}
		if (!bContinue) {
			draw();
			drawer._updateTextures();
			CombinerInfo::get().updateParameters();
		}
	}

	if (m_numRects == 0) {
		m_pBuffer = frameBufferList().getCurrent();
		m_otherMode = gDP.otherMode._u64;
		m_mux = gDP.combine.mux;
		m_Z = (gDP.otherMode.depthSource == G_ZS_PRIM) ? gDP.primDepth.z : gSP.viewport.nearz;
		m_scissor = gDP.scissor;

		m_ulx = pRect[0].x;
		m_uly = pRect[0].y;
		m_lrx = m_max_lrx = pRect[3].x;
		m_lry = m_max_lry = pRect[3].y;

		CombinerInfo::get().update();
		gfxContext.enableDepthWrite(false);
		gfxContext.enable(enable::DEPTH_TEST, false);
		gfxContext.enable(enable::BLEND, false);

		_setViewport();

		gfxContext.setScissor((s32)gDP.scissor.ulx, (s32)gDP.scissor.uly, (s32)(gDP.scissor.lrx - gDP.scissor.ulx), (s32)(gDP.scissor.lry - gDP.scissor.uly));

		gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_FBO);
	}

	if (bDownUp) {
		m_ulx = pRect[0].x;
		m_uly = pRect[0].y;
	}
	else {
		m_lrx = pRect[3].x;
		m_lry = pRect[3].y;
		m_max_lrx = std::max(m_max_lrx, m_lrx);
		m_max_lry = std::max(m_max_lry, m_lry);
	}

	RectCoords coords;
	coords.x = pRect[1].x;
	coords.y = pRect[1].y;
	m_vecRectCoords.push_back(coords);
	coords.x = pRect[3].x;
	coords.y = pRect[3].y;
	m_vecRectCoords.push_back(coords);
	++m_numRects;

	Context::DrawRectParameters rectParams;
	rectParams.mode = drawmode::TRIANGLE_STRIP;
	rectParams.verticesCount = 4;
	rectParams.vertices = pRect;
	rectParams.combiner = currentCombiner();
	gfxContext.drawRects(rectParams);
}

bool TexrectDrawer::draw()
{
	if (m_numRects == 0)
		return false;

	const u64 otherMode = gDP.otherMode._u64;
	const gDPScissor scissor = gDP.scissor;
	gDP.scissor = m_scissor;
	gDP.otherMode._u64 = m_otherMode;
	DisplayWindow & wnd = dwnd();
	GraphicsDrawer &  drawer = wnd.getDrawer();
	drawer._setBlendMode();
	gDP.changed |= CHANGED_RENDERMODE;  // Force update of depth compare parameters
	drawer._updateDepthCompare();

	int enableAlphaTest = 0;
	switch (gDP.otherMode.cycleType) {
	case G_CYC_COPY:
		if (gDP.otherMode.alphaCompare & G_AC_THRESHOLD)
			enableAlphaTest = 1;
		break;
	case G_CYC_1CYCLE:
	case G_CYC_2CYCLE:
		if (((gDP.otherMode.alphaCompare & G_AC_THRESHOLD) != 0) && (gDP.otherMode.alphaCvgSel == 0) && (gDP.otherMode.forceBlender == 0 || gDP.blendColor.a > 0))
			enableAlphaTest = 1;
		else if ((gDP.otherMode.alphaCompare == G_AC_DITHER) && (gDP.otherMode.alphaCvgSel == 0))
			enableAlphaTest = 1;
		else if (gDP.otherMode.cvgXAlpha != 0)
			enableAlphaTest = 1;
		break;
	}

	m_lrx = m_max_lrx;
	m_lry = m_max_lry;

	RectVertex rect[4];

	f32 scaleX, scaleY;
	calcCoordsScales(m_pBuffer, scaleX, scaleY);
	scaleX *= 2.0f;
	scaleY *= 2.0f;

	const float s0 = (m_ulx + 1.0f) / scaleX / (float)m_pTexture->realWidth;
	const float t1 = (m_uly + 1.0f) / scaleY / (float)m_pTexture->realHeight;
	const float s1 = (m_lrx + 1.0f) / scaleX / (float)m_pTexture->realWidth;
	const float t0 = (m_lry + 1.0f) / scaleY / (float)m_pTexture->realHeight;
	const float W = 1.0f;

	drawer._updateScreenCoordsViewport();

	textureCache().activateTexture(0, m_pTexture);
	// Disable filtering to avoid black outlines
	Context::TexParameters texParams;
	texParams.handle = m_pTexture->name;
	texParams.target = textureTarget::TEXTURE_2D;
	texParams.textureUnitIndex = textureIndices::Tex[0];
	texParams.minFilter = textureParameters::FILTER_NEAREST;
	texParams.magFilter = textureParameters::FILTER_NEAREST;
	gfxContext.setTextureParameters(texParams);

	m_programTex->activate();
	m_programTex->setEnableAlphaTest(enableAlphaTest);

	rect[0].x = m_ulx;
	rect[0].y = m_lry;
	rect[0].z = m_Z;
	rect[0].w = W;
	rect[0].s0 = s0;
	rect[0].t0 = t0;
	rect[1].x = m_lrx;
	rect[1].y = m_lry;
	rect[1].z = m_Z;
	rect[1].w = W;
	rect[1].s0 = s1;
	rect[1].t0 = t0;
	rect[2].x = m_ulx;
	rect[2].y = m_uly;
	rect[2].z = m_Z;
	rect[2].w = W;
	rect[2].s0 = s0;
	rect[2].t0 = t1;
	rect[3].x = m_lrx;
	rect[3].y = m_uly;
	rect[3].z = m_Z;
	rect[3].w = W;
	rect[3].s0 = s1;
	rect[3].t0 = t1;

	drawer.updateScissor(m_pBuffer);
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_pBuffer != nullptr ? m_pBuffer->m_FBO : ObjectHandle::null);

	Context::DrawRectParameters rectParams;
	rectParams.mode = drawmode::TRIANGLE_STRIP;
	rectParams.verticesCount = 4;
	rectParams.vertices = rect;
	rectParams.combiner = m_programTex.get();
	gfxContext.drawRects(rectParams);

	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_FBO);
	m_programClear->activate();

	const f32 ulx = std::max(-1.0f, m_ulx - m_stepX);
	const f32 lrx = std::min( 1.0f, m_lrx + m_stepX);
	rect[0].x = ulx;
	rect[1].x = lrx;
	rect[2].x = ulx;
	rect[3].x = lrx;

	const f32 uly = std::max(-1.0f, m_uly - m_stepY);
	const f32 lry = std::min( 1.0f, m_lry + m_stepY);
	rect[0].y = uly;
	rect[1].y = uly;
	rect[2].y = lry;
	rect[3].y = lry;

	_setViewport();

	gfxContext.enable(enable::BLEND, false);
	gfxContext.enable(enable::SCISSOR_TEST, false);
	rectParams.combiner = m_programClear.get();
	gfxContext.drawRects(rectParams);
	gfxContext.enable(enable::SCISSOR_TEST, true);

	m_pBuffer = frameBufferList().getCurrent();
	gfxContext.bindFramebuffer(bufferTarget::DRAW_FRAMEBUFFER, m_pBuffer != nullptr ? m_pBuffer->m_FBO : ObjectHandle::null);

	m_numRects = 0;
	m_vecRectCoords.clear();
	gDP.otherMode._u64 = otherMode;
	gDP.scissor = scissor;
	gDP.changed |= CHANGED_COMBINE | CHANGED_SCISSOR | CHANGED_RENDERMODE;
	gSP.changed |= CHANGED_VIEWPORT | CHANGED_TEXTURE;

	return true;
}

bool TexrectDrawer::isEmpty() {
	return m_numRects == 0;
}
