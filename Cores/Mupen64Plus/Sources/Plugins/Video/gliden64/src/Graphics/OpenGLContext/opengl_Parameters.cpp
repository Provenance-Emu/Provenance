#include <Graphics/Parameters.h>
#include "GLFunctions.h"

namespace graphics {

	namespace colorFormat {
		ColorFormatParam RED_GREEN_BLUE(GL_RGB);
		ColorFormatParam RGBA(GL_RGBA);
		ColorFormatParam RG(GL_RG);
		ColorFormatParam RED(GL_RED);
		ColorFormatParam DEPTH(GL_DEPTH_COMPONENT);
		ColorFormatParam LUMINANCE(0x1909);
	}

	namespace internalcolorFormat {
		InternalColorFormatParam NOCOLOR(0U);
		InternalColorFormatParam RGB8(GL_RGB8);
		InternalColorFormatParam RGBA8(GL_RGBA8);
		InternalColorFormatParam RGBA4(GL_RGBA4);
		InternalColorFormatParam RGB5_A1(GL_RGB5_A1);
		InternalColorFormatParam RG(GL_RG8);
		InternalColorFormatParam R16F(GL_R16F);
		InternalColorFormatParam DEPTH(GL_DEPTH_COMPONENT24);
		InternalColorFormatParam RG32F(GL_RG32F);
		InternalColorFormatParam LUMINANCE(0x1909);
		InternalColorFormatParam COLOR_INDEX8(0x80E5);
	}

	namespace datatype {
		DatatypeParam UNSIGNED_BYTE(GL_UNSIGNED_BYTE);
		DatatypeParam UNSIGNED_SHORT(GL_UNSIGNED_SHORT);
		DatatypeParam UNSIGNED_INT(GL_UNSIGNED_INT);
		DatatypeParam FLOAT(GL_FLOAT);
		DatatypeParam UNSIGNED_SHORT_5_6_5(GL_UNSIGNED_SHORT_5_6_5);
		DatatypeParam UNSIGNED_SHORT_5_5_5_1(GL_UNSIGNED_SHORT_5_5_5_1);
		DatatypeParam UNSIGNED_SHORT_4_4_4_4(GL_UNSIGNED_SHORT_4_4_4_4);
	}

	namespace textureTarget {
		TextureTargetParam TEXTURE_2D(GL_TEXTURE_2D);
		TextureTargetParam TEXTURE_2D_MULTISAMPLE(GL_TEXTURE_2D_MULTISAMPLE);
		TextureTargetParam RENDERBUFFER(GL_RENDERBUFFER);
	}

	namespace bufferTarget {
		BufferTargetParam FRAMEBUFFER(GL_FRAMEBUFFER);
		BufferTargetParam DRAW_FRAMEBUFFER(GL_DRAW_FRAMEBUFFER);
		BufferTargetParam READ_FRAMEBUFFER(GL_READ_FRAMEBUFFER);
	}

	namespace bufferAttachment {
		BufferAttachmentParam COLOR_ATTACHMENT0(GL_COLOR_ATTACHMENT0);
		BufferAttachmentParam COLOR_ATTACHMENT1(GL_COLOR_ATTACHMENT1);
		BufferAttachmentParam COLOR_ATTACHMENT2(GL_COLOR_ATTACHMENT2);
		BufferAttachmentParam DEPTH_ATTACHMENT(GL_DEPTH_ATTACHMENT);
	}

	namespace enable {
		EnableParam BLEND(GL_BLEND);
		EnableParam CULL_FACE(GL_CULL_FACE);
		EnableParam DEPTH_TEST(GL_DEPTH_TEST);
		EnableParam DEPTH_CLAMP(GL_DEPTH_CLAMP);
		EnableParam CLIP_DISTANCE0(GL_CLIP_DISTANCE0);
		EnableParam DITHER(GL_DITHER);
		EnableParam POLYGON_OFFSET_FILL(GL_POLYGON_OFFSET_FILL);
		EnableParam SCISSOR_TEST(GL_SCISSOR_TEST);
	}

	namespace textureIndices {
		TextureUnitParam Tex[2] = { 0U, 1U };
		TextureUnitParam NoiseTex(2U);
		TextureUnitParam DepthTex(3U);
		TextureUnitParam ZLUTTex(4U);
		TextureUnitParam PaletteTex(5U);
		TextureUnitParam MSTex[2] = { 6U, 7U };
	}

	namespace textureImageUnits {
		ImageUnitParam DepthZ(2U);
		ImageUnitParam DepthDeltaZ(3U);
	}

	namespace textureImageAccessMode {
		ImageAccessModeParam READ_ONLY(GL_READ_ONLY);
		ImageAccessModeParam WRITE_ONLY(GL_WRITE_ONLY);
		ImageAccessModeParam READ_WRITE(GL_READ_WRITE);
	}

	namespace textureParameters {
		TextureParam FILTER_NEAREST(GL_NEAREST);
		TextureParam FILTER_LINEAR(GL_LINEAR);
		TextureParam FILTER_NEAREST_MIPMAP_NEAREST(GL_NEAREST_MIPMAP_NEAREST);
		TextureParam FILTER_LINEAR_MIPMAP_NEAREST(GL_LINEAR_MIPMAP_NEAREST);
		TextureParam WRAP_CLAMP_TO_EDGE(GL_CLAMP_TO_EDGE);
		TextureParam WRAP_REPEAT(GL_REPEAT);
		TextureParam WRAP_MIRRORED_REPEAT(GL_MIRRORED_REPEAT);
	}

	namespace cullMode {
		CullModeParam FRONT(GL_BACK);
		CullModeParam BACK(GL_FRONT);
		CullModeParam FRONT_AND_BACK(GL_FRONT_AND_BACK);
	}

	namespace compare {
		CompareParam LEQUAL(GL_LEQUAL);
		CompareParam LESS(GL_LESS);
		CompareParam ALWAYS(GL_ALWAYS);
	}

	namespace blend {
		BlendParam ZERO(GL_ZERO);
		BlendParam ONE(GL_ONE);
		BlendParam SRC_ALPHA(GL_SRC_ALPHA);
		BlendParam DST_ALPHA(GL_DST_ALPHA);
		BlendParam ONE_MINUS_SRC_ALPHA(GL_ONE_MINUS_SRC_ALPHA);
		BlendParam CONSTANT_ALPHA(GL_CONSTANT_ALPHA);
		BlendParam ONE_MINUS_CONSTANT_ALPHA(GL_ONE_MINUS_CONSTANT_ALPHA);
	}

	namespace drawmode {
		DrawModeParam TRIANGLES(GL_TRIANGLES);
		DrawModeParam TRIANGLE_STRIP(GL_TRIANGLE_STRIP);
		DrawModeParam LINES(GL_LINES);
	}

	namespace blitMask {
		BlitMaskParam COLOR_BUFFER(GL_COLOR_BUFFER_BIT);
		BlitMaskParam DEPTH_BUFFER(GL_DEPTH_BUFFER_BIT);
		BlitMaskParam STENCIL_BUFFER(GL_STENCIL_BUFFER_BIT);
	}
}
