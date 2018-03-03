#include "Graphics/Context.h"
#include "Graphics/Parameters.h"
#include "N64.h"
#include "gDP.h"
#include "VI.h"
#include "Textures.h"
#include "PaletteTexture.h"
#include "DepthBuffer.h"


PaletteTexture g_paletteTexture;
using namespace graphics;

PaletteTexture::PaletteTexture()
: m_pTexture(nullptr)
, m_paletteCRC256(0)
{
}

void PaletteTexture::init()
{
	if (!Context::imageTextures)
		return;

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	m_paletteCRC256 = 0;
	m_pTexture = textureCache().addFrameBufferTexture(false);
	m_pTexture->format = G_IM_FMT_IA;
	m_pTexture->clampS = 1;
	m_pTexture->clampT = 1;
	m_pTexture->frameBufferTexture = CachedTexture::fbOneSample;
	m_pTexture->maskS = 0;
	m_pTexture->maskT = 0;
	m_pTexture->mirrorS = 0;
	m_pTexture->mirrorT = 0;
	m_pTexture->realWidth = 256;
	m_pTexture->realHeight = 1;
	m_pTexture->textureBytes = m_pTexture->realWidth * m_pTexture->realHeight * fbTexFormats.lutFormatBytes;
	textureCache().addFrameBufferTextureSize(m_pTexture->textureBytes);

	Context::InitTextureParams initParams;
	initParams.handle = m_pTexture->name;
	initParams.ImageUnit = textureImageUnits::Tlut;
	initParams.width = m_pTexture->realWidth;
	initParams.height = m_pTexture->realHeight;
	initParams.internalFormat = fbTexFormats.lutInternalFormat;
	initParams.format = fbTexFormats.lutFormat;
	initParams.dataType = fbTexFormats.lutType;
	gfxContext.init2DTexture(initParams);

	Context::TexParameters setParams;
	setParams.handle = m_pTexture->name;
	setParams.target = textureTarget::TEXTURE_2D;
	setParams.textureUnitIndex = textureIndices::PaletteTex;
	setParams.minFilter = textureParameters::FILTER_NEAREST;
	setParams.magFilter = textureParameters::FILTER_NEAREST;
	setParams.wrapS = textureParameters::WRAP_CLAMP_TO_EDGE;
	setParams.wrapT = textureParameters::WRAP_CLAMP_TO_EDGE;
	gfxContext.setTextureParameters(setParams);

	// Generate Pixel Buffer Object. Initialize it with max buffer size.
	m_pbuf.reset(gfxContext.createPixelWriteBuffer(m_pTexture->textureBytes));
}

void PaletteTexture::destroy()
{
	if (!Context::imageTextures)
		return;

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();

	Context::BindImageTextureParameters bindParams;
	bindParams.imageUnit = textureImageUnits::Tlut;
	bindParams.texture = ObjectHandle::null;
	bindParams.accessMode = textureImageAccessMode::READ_ONLY;
	bindParams.textureFormat = fbTexFormats.lutInternalFormat;

	gfxContext.bindImageTexture(bindParams);

	textureCache().removeFrameBufferTexture(m_pTexture);
	m_pTexture = nullptr;
	m_pbuf.reset();
}

void PaletteTexture::update()
{
	if (!Context::imageTextures)
		return;

	if (m_paletteCRC256 == gDP.paletteCRC256)
		return;
	
	m_paletteCRC256 = gDP.paletteCRC256;

	PixelBufferBinder<PixelWriteBuffer> binder(m_pbuf.get());
	u8* ptr = (u8*)m_pbuf->getWriteBuffer(m_pTexture->textureBytes);
	u32 * palette = (u32*)ptr;
	u16 *src = (u16*)&TMEM[256];
	for (int i = 0; i < 256; ++i)
		palette[i] = swapword(src[i * 4]);
	m_pbuf->closeWriteBuffer();

	const FramebufferTextureFormats & fbTexFormats = gfxContext.getFramebufferTextureFormats();
	Context::UpdateTextureDataParams params;
	params.handle = m_pTexture->name;
	params.ImageUnit = textureImageUnits::Tlut;
	params.textureUnitIndex = textureIndices::PaletteTex;
	params.width = m_pTexture->realWidth;
	params.height = m_pTexture->realHeight;
	params.format = fbTexFormats.lutFormat;
	params.internalFormat = fbTexFormats.lutInternalFormat;
	params.dataType = fbTexFormats.lutType;
	params.data = m_pbuf->getData();
	gfxContext.update2DTexture(params);
}
