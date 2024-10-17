#pragma once

#include <memory>
#include <Combiner.h>
#include "ObjectHandle.h"
#include "Parameter.h"
#include "CombinerProgram.h"
#include "ShaderProgram.h"
#include "PixelBuffer.h"
#include "FramebufferTextureFormats.h"

#define GRAPHICS_CONTEXT

struct CachedTexture;

namespace graphics {

	enum class SpecialFeatures {
		Multisampling,
		BlitFramebuffer,
		WeakBlitFramebuffer,
		DepthFramebufferTextures,
		ShaderProgramBinary,
		ImageTextures,
		IntegerTextures,
		ClipControl,
		FramebufferFetch,
		TextureBarrier
	};

	enum class ClampMode {
		ClippingEnabled,
		NoNearPlaneClipping,
		NoClipping
	};

	class ContextImpl;
	class ColorBufferReader;

	class Context
	{
	public:
		Context();
		~Context();

		void init();

		void destroy();

		void setClampMode(ClampMode _mode);

		ClampMode getClampMode();

		void enable(EnableParam _parameter, bool _enable);

		u32 isEnabled(EnableParam _parameter);

		void cullFace(CullModeParam _mode);

		void enableDepthWrite(bool _enable);

		void setDepthCompare(CompareParam _mode);

		void setViewport(s32 _x, s32 _y, s32 _width, s32 _height);

		void setScissor(s32 _x, s32 _y, s32 _width, s32 _height);

		void setBlending(BlendParam _sfactor, BlendParam _dfactor);

		void setBlendColor(f32 _red, f32 _green, f32 _blue, f32 _alpha);

		void clearColorBuffer(f32 _red, f32 _green, f32 _blue, f32 _alpha);

		void clearDepthBuffer();

		void setPolygonOffset(f32 _factor, f32 _units);

		/*---------------Texture-------------*/

		ObjectHandle createTexture(Parameter _target);

		void deleteTexture(ObjectHandle _name);

		struct InitTextureParams {
			ObjectHandle handle;
			TextureUnitParam textureUnitIndex{0};
			u32 msaaLevel = 0;
			u32 width = 0;
			u32 height = 0;
			u32 mipMapLevel = 0;
			u32 mipMapLevels = 1;
			ColorFormatParam format;
			InternalColorFormatParam internalFormat;
			DatatypeParam dataType;
			const void * data = nullptr;
		};

		void init2DTexture(const InitTextureParams & _params);

		struct UpdateTextureDataParams {
			ObjectHandle handle;
			TextureUnitParam textureUnitIndex{0};
			u32 x = 0;
			u32 y = 0;
			u32 width = 0;
			u32 height = 0;
			u32 mipMapLevel = 0;
			ColorFormatParam format;
			InternalColorFormatParam internalFormat;
			DatatypeParam dataType;
			const void * data = nullptr;
		};

		void update2DTexture(const UpdateTextureDataParams & _params);

		struct TexParameters {
			ObjectHandle handle;
			TextureUnitParam textureUnitIndex{0};
			TextureTargetParam target;
			TextureParam magFilter;
			TextureParam minFilter;
			TextureParam wrapS;
			TextureParam wrapT;
			Parameter maxMipmapLevel;
			Parameter maxAnisotropy;
		};

		void setTextureParameters(const TexParameters & _parameters);

		struct BindTextureParameters {
			ObjectHandle texture;
			TextureUnitParam textureUnitIndex;
			TextureTargetParam target;
		};

		void bindTexture(const BindTextureParameters & _params);

		void setTextureUnpackAlignment(s32 _param);

		s32 getTextureUnpackAlignment() const;

		s32 getMaxTextureSize() const;

		struct BindImageTextureParameters {
			ImageUnitParam imageUnit;
			ObjectHandle texture;
			ImageAccessModeParam accessMode;
			InternalColorFormatParam textureFormat;
		};

		void bindImageTexture(const BindImageTextureParameters & _params);

		u32 convertInternalTextureFormat(u32 _format) const;

		void textureBarrier();

		/*---------------Framebuffer-------------*/

		const FramebufferTextureFormats & getFramebufferTextureFormats();

		ObjectHandle createFramebuffer();

		void deleteFramebuffer(ObjectHandle _name);

		void bindFramebuffer(BufferTargetParam _target, ObjectHandle _name);

		ObjectHandle createRenderbuffer();

		struct InitRenderbufferParams {
			ObjectHandle handle;
			TextureTargetParam target;
			InternalColorFormatParam format;
			u32 width = 0;
			u32 height = 0;
		};

		void initRenderbuffer(const InitRenderbufferParams & _params);

		struct FrameBufferRenderTarget {
			ObjectHandle bufferHandle;
			BufferTargetParam bufferTarget;
			BufferAttachmentParam attachment;
			Parameter textureTarget;
			ObjectHandle textureHandle;
		};

		void addFrameBufferRenderTarget(const FrameBufferRenderTarget & _params);

		struct BlitFramebuffersParams
		{
			ObjectHandle readBuffer;
			ObjectHandle drawBuffer;
			s32 srcX0;
			s32 srcY0;
			s32 srcX1;
			s32 srcY1;
			s32 dstX0;
			s32 dstY0;
			s32 dstX1;
			s32 dstY1;
			Parameter mask;
			Parameter filter;
		};

		bool blitFramebuffers(const BlitFramebuffersParams & _params);

		void setDrawBuffers(u32 _num);

		/*---------------Pixelbuffer-------------*/

		PixelReadBuffer * createPixelReadBuffer(size_t _sizeInBytes);

		ColorBufferReader * createColorBufferReader(CachedTexture * _pTexture);

		/*---------------Shaders-------------*/

		bool isCombinerProgramBuilderObsolete();

		void resetCombinerProgramBuilder();

		CombinerProgram * createCombinerProgram(Combiner & _color, Combiner & _alpha, const CombinerKey & _key);

		bool saveShadersStorage(const Combiners & _combiners);

		bool loadShadersStorage(Combiners & _combiners);

		ShaderProgram * createDepthFogShader();

		TexrectDrawerShaderProgram * createTexrectDrawerDrawShader();

		ShaderProgram * createTexrectDrawerClearShader();

		ShaderProgram * createTexrectCopyShader();

		ShaderProgram * createGammaCorrectionShader();

		ShaderProgram * createOrientationCorrectionShader();

		ShaderProgram * createFXAAShader();

		TextDrawerShaderProgram * createTextDrawerShader();

		void resetShaderProgram();

		/*---------------Draw-------------*/

		struct DrawTriangleParameters
		{
			DrawModeParam mode;
			Parameter elementsType;
			u32 verticesCount = 0;
			u32 elementsCount = 0;
			bool flatColors = false;
			SPVertex * vertices = nullptr;
			void * elements = nullptr;
			const CombinerProgram * combiner = nullptr;
		};

		void drawTriangles(const DrawTriangleParameters & _params);

		struct DrawRectParameters
		{
			DrawModeParam mode;
			bool texrect = true;
			u32 verticesCount = 0;
			RectVertex * vertices = nullptr;
			const CombinerProgram * combiner = nullptr;
		};

		void drawRects(const DrawRectParameters & _params);

		void drawLine(f32 _width, SPVertex * _vertices);

		f32 getMaxLineWidth();

		/*---------------Misc-------------*/

		bool isError() const;

		bool isFramebufferError() const;

		static bool Multisampling;
		static bool BlitFramebuffer;
		static bool WeakBlitFramebuffer;
		static bool DepthFramebufferTextures;
		static bool ShaderProgramBinary;
		static bool ImageTextures;
		static bool IntegerTextures;
		static bool ClipControl;
		static bool FramebufferFetch;
		static bool TextureBarrier;

	private:
		std::unique_ptr<ContextImpl> m_impl;
		std::unique_ptr<FramebufferTextureFormats> m_fbTexFormats;
	};

}

extern graphics::Context gfxContext;
