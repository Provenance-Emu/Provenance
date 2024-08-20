#include "Graphics/Context.h"
#include "Graphics/Parameters.h"
#include "DepthBuffer.h"
#include "Config.h"
#include "Textures.h"
#include "ZlutTexture.h"

using namespace graphics;

ZlutTexture g_zlutTexture;

ZlutTexture::ZlutTexture()
: m_pTexture(nullptr)
{
}

void ZlutTexture::init()
{
	if (!Context::IntegerTextures)
		return;

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	std::vector<u32> vecZLUT(0x40000);
	const u16 * const zLUT16 = depthBufferList().getZLUT();
	for (u32 i = 0; i < 0x40000; ++i)
		vecZLUT[i] = zLUT16[i];

	m_pTexture = textureCache().addFrameBufferTexture(false);
	m_pTexture->format = G_IM_FMT_IA;
	m_pTexture->clampS = 1;
	m_pTexture->clampT = 1;
	m_pTexture->frameBufferTexture = CachedTexture::fbOneSample;
	m_pTexture->maskS = 0;
	m_pTexture->maskT = 0;
	m_pTexture->mirrorS = 0;
	m_pTexture->mirrorT = 0;
	m_pTexture->realWidth = 512;
	m_pTexture->realHeight = 512;
	m_pTexture->textureBytes = m_pTexture->realWidth * m_pTexture->realHeight * fbTexFormats.lutFormatBytes;

	Context::InitTextureParams initParams;
	initParams.handle = m_pTexture->name;
	initParams.width = m_pTexture->realWidth;
	initParams.height = m_pTexture->realHeight;
	initParams.internalFormat = fbTexFormats.lutInternalFormat;
	initParams.format = fbTexFormats.lutFormat;
	initParams.dataType = fbTexFormats.lutType;
	initParams.data = vecZLUT.data();
	gfxContext.init2DTexture(initParams);

	Context::TexParameters setParams;
	setParams.handle = m_pTexture->name;
	setParams.target = textureTarget::TEXTURE_2D;
	setParams.textureUnitIndex = textureIndices::ZLUTTex;
	setParams.minFilter = textureParameters::FILTER_NEAREST;
	setParams.magFilter = textureParameters::FILTER_NEAREST;
	setParams.wrapS = textureParameters::WRAP_CLAMP_TO_EDGE;
	setParams.wrapT = textureParameters::WRAP_CLAMP_TO_EDGE;
	gfxContext.setTextureParameters(setParams);
}

void ZlutTexture::destroy()
{
	if (!Context::IntegerTextures)
		return;

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	textureCache().removeFrameBufferTexture(m_pTexture);
	m_pTexture = nullptr;
}
