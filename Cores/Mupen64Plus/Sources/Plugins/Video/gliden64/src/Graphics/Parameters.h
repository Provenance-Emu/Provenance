#pragma once
#include "Parameter.h"

namespace graphics {

	namespace colorFormat {
		extern ColorFormatParam RED_GREEN_BLUE; //Windows has a macro called RGB
		extern ColorFormatParam RGBA;
		extern ColorFormatParam RG;
		extern ColorFormatParam RED;
		extern ColorFormatParam DEPTH;
		extern ColorFormatParam LUMINANCE;
	}

	namespace internalcolorFormat {
	        extern InternalColorFormatParam NOCOLOR;
		extern InternalColorFormatParam RGB8;
		extern InternalColorFormatParam RGBA8;
		extern InternalColorFormatParam RGBA4;
		extern InternalColorFormatParam RGB5_A1;
		extern InternalColorFormatParam RG;
		extern InternalColorFormatParam R16F;
		extern InternalColorFormatParam DEPTH;
		extern InternalColorFormatParam RG32F;
		extern InternalColorFormatParam LUMINANCE;
		extern InternalColorFormatParam COLOR_INDEX8;
	}

	namespace datatype {
		extern DatatypeParam UNSIGNED_BYTE;
		extern DatatypeParam UNSIGNED_SHORT;
		extern DatatypeParam UNSIGNED_INT;
		extern DatatypeParam FLOAT;
		extern DatatypeParam UNSIGNED_SHORT_5_6_5;
		extern DatatypeParam UNSIGNED_SHORT_5_5_5_1;
		extern DatatypeParam UNSIGNED_SHORT_4_4_4_4;
	}

	namespace textureTarget {
		extern TextureTargetParam TEXTURE_2D;
		extern TextureTargetParam TEXTURE_2D_MULTISAMPLE;
		extern TextureTargetParam RENDERBUFFER;
	}

	namespace bufferTarget {
		extern BufferTargetParam FRAMEBUFFER;
		extern BufferTargetParam DRAW_FRAMEBUFFER;
		extern BufferTargetParam READ_FRAMEBUFFER;
	}

	namespace bufferAttachment {
		extern BufferAttachmentParam COLOR_ATTACHMENT0;
		extern BufferAttachmentParam COLOR_ATTACHMENT1;
		extern BufferAttachmentParam COLOR_ATTACHMENT2;
		extern BufferAttachmentParam DEPTH_ATTACHMENT;
	}

	namespace enable {
		extern EnableParam BLEND;
		extern EnableParam CULL_FACE;
		extern EnableParam DEPTH_TEST;
		extern EnableParam DEPTH_CLAMP;
		extern EnableParam CLIP_DISTANCE0;
		extern EnableParam DITHER;
		extern EnableParam POLYGON_OFFSET_FILL;
		extern EnableParam SCISSOR_TEST;
	}

	namespace textureIndices {
		extern TextureUnitParam Tex[2];
		extern TextureUnitParam NoiseTex;
		extern TextureUnitParam DepthTex;
		extern TextureUnitParam ZLUTTex;
		extern TextureUnitParam PaletteTex;
		extern TextureUnitParam MSTex[2];
	}

	namespace textureImageUnits {
		extern ImageUnitParam DepthZ;
		extern ImageUnitParam DepthDeltaZ;
	}

	namespace textureImageAccessMode {
		extern ImageAccessModeParam READ_ONLY;
		extern ImageAccessModeParam WRITE_ONLY;
		extern ImageAccessModeParam READ_WRITE;
	}

	namespace textureParameters {
		extern TextureParam FILTER_NEAREST;
		extern TextureParam FILTER_LINEAR;
		extern TextureParam FILTER_NEAREST_MIPMAP_NEAREST;
		extern TextureParam FILTER_LINEAR_MIPMAP_NEAREST;
		extern TextureParam WRAP_CLAMP_TO_EDGE;
		extern TextureParam WRAP_REPEAT;
		extern TextureParam WRAP_MIRRORED_REPEAT;
	}

	namespace cullMode {
		extern CullModeParam FRONT;
		extern CullModeParam BACK;
		extern CullModeParam FRONT_AND_BACK;
	}

	namespace compare {
		extern CompareParam LEQUAL;
		extern CompareParam LESS;
		extern CompareParam ALWAYS;
	}

	namespace blend {
		extern BlendParam ZERO;
		extern BlendParam ONE;
		extern BlendParam SRC_ALPHA;
		extern BlendParam DST_ALPHA;
		extern BlendParam ONE_MINUS_SRC_ALPHA;
		extern BlendParam CONSTANT_ALPHA;
		extern BlendParam ONE_MINUS_CONSTANT_ALPHA;
	}

	namespace drawmode {
		extern DrawModeParam TRIANGLES;
		extern DrawModeParam TRIANGLE_STRIP;
		extern DrawModeParam LINES;
	}

	namespace blitMask {
		extern BlitMaskParam COLOR_BUFFER;
		extern BlitMaskParam DEPTH_BUFFER;
		extern BlitMaskParam STENCIL_BUFFER;
	}
}
