#pragma once
#include "ObjectHandle.h"
#include "Parameter.h"

#include "Context.h"

namespace graphics {

	class ContextImpl
	{
	public:
		virtual ~ContextImpl() {}
		virtual void init() = 0;
		virtual void destroy() = 0;
		virtual void setClampMode(ClampMode _mode) = 0;
		virtual ClampMode getClampMode() = 0;
		virtual void enable(EnableParam _parameter, bool _enable) = 0;
		virtual u32 isEnabled(EnableParam _parameter) = 0;
		virtual void cullFace(CullModeParam _mode) = 0;
		virtual void enableDepthWrite(bool _enable) = 0;
		virtual void setDepthCompare(CompareParam _mode) = 0;
		virtual void setViewport(s32 _x, s32 _y, s32 _width, s32 _height) = 0;
		virtual void setScissor(s32 _x, s32 _y, s32 _width, s32 _height) = 0;
		virtual void setBlending(BlendParam _sfactor, BlendParam _dfactor) = 0;
		virtual void setBlendColor(f32 _red, f32 _green, f32 _blue, f32 _alpha) = 0;
		virtual void clearColorBuffer(f32 _red, f32 _green, f32 _blue, f32 _alpha) = 0;
		virtual void clearDepthBuffer() = 0;
		virtual void setPolygonOffset(f32 _factor, f32 _units) = 0;
		virtual ObjectHandle createTexture(Parameter _target) = 0;
		virtual void deleteTexture(ObjectHandle _name) = 0;
		virtual void init2DTexture(const Context::InitTextureParams & _params) = 0;
		virtual void update2DTexture(const Context::UpdateTextureDataParams & _params) = 0;
		virtual void setTextureParameters(const Context::TexParameters & _parameters) = 0;
		virtual void bindTexture(const Context::BindTextureParameters & _params) = 0;
		virtual void setTextureUnpackAlignment(s32 _param) = 0;
		virtual s32 getTextureUnpackAlignment() const = 0;
		virtual s32 getMaxTextureSize() const = 0;
		virtual void bindImageTexture(const Context::BindImageTextureParameters & _params) = 0;
		virtual u32 convertInternalTextureFormat(u32 _format) const = 0;
		virtual void textureBarrier() = 0;
		virtual FramebufferTextureFormats * getFramebufferTextureFormats() = 0;
		virtual ObjectHandle createFramebuffer() = 0;
		virtual void deleteFramebuffer(ObjectHandle _name) = 0;
		virtual void bindFramebuffer(BufferTargetParam _target, ObjectHandle _name) = 0;
		virtual void addFrameBufferRenderTarget(const Context::FrameBufferRenderTarget & _params) = 0;
		virtual ObjectHandle createRenderbuffer() = 0;
		virtual void initRenderbuffer(const Context::InitRenderbufferParams & _params) = 0;
		virtual bool blitFramebuffers(const Context::BlitFramebuffersParams & _params) = 0;
		virtual void setDrawBuffers(u32 _num) = 0;
		virtual PixelReadBuffer * createPixelReadBuffer(size_t _sizeInBytes) = 0;
		virtual ColorBufferReader * createColorBufferReader(CachedTexture * _pTexture) = 0;
		virtual bool isCombinerProgramBuilderObsolete() = 0;
		virtual void resetCombinerProgramBuilder() = 0;
		virtual CombinerProgram * createCombinerProgram(Combiner & _color, Combiner & _alpha, const CombinerKey & _key) = 0;
		virtual bool saveShadersStorage(const Combiners & _combiners) = 0;
		virtual bool loadShadersStorage(Combiners & _combiners) = 0;
		virtual ShaderProgram * createDepthFogShader() = 0;
		virtual TexrectDrawerShaderProgram * createTexrectDrawerDrawShader() = 0;
		virtual ShaderProgram * createTexrectDrawerClearShader() = 0;
		virtual ShaderProgram * createTexrectCopyShader() = 0;
		virtual ShaderProgram * createGammaCorrectionShader() = 0;
		virtual ShaderProgram * createOrientationCorrectionShader() = 0;
		virtual ShaderProgram * createFXAAShader() = 0;
		virtual TextDrawerShaderProgram * createTextDrawerShader() = 0;
		virtual void resetShaderProgram() = 0;
		virtual void drawTriangles(const Context::DrawTriangleParameters & _params) = 0;
		virtual void drawRects(const Context::DrawRectParameters & _params) = 0;
		virtual void drawLine(f32 _width, SPVertex * _vertices) = 0;
		virtual f32 getMaxLineWidth() = 0;
		virtual bool isSupported(SpecialFeatures _feature) const = 0;
		virtual bool isError() const = 0;
		virtual bool isFramebufferError() const = 0;
	};

}
