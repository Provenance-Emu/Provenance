#pragma once
#include <memory>
#include <Graphics/ContextImpl.h>
#include "opengl_TextureManipulationObjectFactory.h"
#include "opengl_BufferManipulationObjectFactory.h"
#include "opengl_GLInfo.h"
#include "opengl_CachedFunctions.h"
#include "opengl_GraphicsDrawer.h"

namespace glsl {
	class CombinerProgramBuilder;
	class SpecialShadersFactory;
}

namespace opengl {

	class ContextImpl : public graphics::ContextImpl
	{
	public:
		ContextImpl();
		~ContextImpl();

		void init() override;

		void destroy() override;

		void setClampMode(graphics::ClampMode _mode) override;

		graphics::ClampMode getClampMode() override;

		void enable(graphics::EnableParam _parameter, bool _enable) override;

		u32 isEnabled(graphics::EnableParam _parameter) override;

		void cullFace(graphics::CullModeParam _mode) override;

		void enableDepthWrite(bool _enable) override;

		void setDepthCompare(graphics::CompareParam _mode) override;

		void setViewport(s32 _x, s32 _y, s32 _width, s32 _height) override;

		void setScissor(s32 _x, s32 _y, s32 _width, s32 _height) override;

		void setBlending(graphics::BlendParam _sfactor, graphics::BlendParam _dfactor) override;

		void setBlendColor(f32 _red, f32 _green, f32 _blue, f32 _alpha) override;

		void clearColorBuffer(f32 _red, f32 _green, f32 _blue, f32 _alpha) override;

		void clearDepthBuffer() override;

		void setPolygonOffset(f32 _factor, f32 _units) override;

		/*---------------Texture-------------*/

		graphics::ObjectHandle createTexture(graphics::Parameter _target) override;

		void deleteTexture(graphics::ObjectHandle _name) override;

		void init2DTexture(const graphics::Context::InitTextureParams & _params) override;

		void update2DTexture(const graphics::Context::UpdateTextureDataParams & _params) override;

		void setTextureParameters(const graphics::Context::TexParameters & _parameters) override;

		void bindTexture(const graphics::Context::BindTextureParameters & _params) override;

		void setTextureUnpackAlignment(s32 _param) override;

		s32 getTextureUnpackAlignment() const override;

		s32 getMaxTextureSize() const override;

		void bindImageTexture(const graphics::Context::BindImageTextureParameters & _params) override;

		u32 convertInternalTextureFormat(u32 _format) const override;

		void textureBarrier() override;

		/*---------------Framebuffer-------------*/

		graphics::FramebufferTextureFormats * getFramebufferTextureFormats() override;

		graphics::ObjectHandle createFramebuffer() override;

		void deleteFramebuffer(graphics::ObjectHandle _name) override;

		void bindFramebuffer(graphics::BufferTargetParam _target, graphics::ObjectHandle _name) override;

		graphics::ObjectHandle createRenderbuffer() override;

		void initRenderbuffer(const graphics::Context::InitRenderbufferParams & _params) override;

		void addFrameBufferRenderTarget(const graphics::Context::FrameBufferRenderTarget & _params) override;

		bool blitFramebuffers(const graphics::Context::BlitFramebuffersParams & _params) override;

		void setDrawBuffers(u32 _num) override;

		/*---------------Pixelbuffer-------------*/

		graphics::PixelReadBuffer * createPixelReadBuffer(size_t _sizeInBytes) override;

		graphics::ColorBufferReader * createColorBufferReader(CachedTexture * _pTexture) override;

		/*---------------Shaders-------------*/

		bool isCombinerProgramBuilderObsolete() override;

		void resetCombinerProgramBuilder() override;

		graphics::CombinerProgram * createCombinerProgram(Combiner & _color, Combiner & _alpha, const CombinerKey & _key) override;

		bool saveShadersStorage(const graphics::Combiners & _combiners) override;

		bool loadShadersStorage(graphics::Combiners & _combiners) override;

		graphics::ShaderProgram * createDepthFogShader() override;

		graphics::TexrectDrawerShaderProgram * createTexrectDrawerDrawShader() override;

		graphics::ShaderProgram * createTexrectDrawerClearShader() override;

		graphics::ShaderProgram * createTexrectCopyShader() override;

		graphics::ShaderProgram * createGammaCorrectionShader() override;

		graphics::ShaderProgram * createOrientationCorrectionShader() override;

		graphics::ShaderProgram * createFXAAShader() override;

		graphics::TextDrawerShaderProgram * createTextDrawerShader() override;

		void resetShaderProgram() override;

		void drawTriangles(const graphics::Context::DrawTriangleParameters & _params) override;

		void drawRects(const graphics::Context::DrawRectParameters & _params) override;

		void drawLine(f32 _width, SPVertex * _vertices) override;

		f32 getMaxLineWidth() override;

		bool isSupported(graphics::SpecialFeatures _feature) const override;

		bool isError() const override;

		bool isFramebufferError() const override;

	private:
		std::unique_ptr<CachedFunctions> m_cachedFunctions;
		std::unique_ptr<Create2DTexture> m_createTexture;
		std::unique_ptr<Init2DTexture> m_init2DTexture;
		std::unique_ptr<Update2DTexture> m_update2DTexture;
		std::unique_ptr<Set2DTextureParameters> m_set2DTextureParameters;

		std::unique_ptr<CreateFramebufferObject> m_createFramebuffer;
		std::unique_ptr<CreateRenderbuffer> m_createRenderbuffer;
		std::unique_ptr<InitRenderbuffer> m_initRenderbuffer;
		std::unique_ptr<AddFramebufferRenderTarget> m_addFramebufferRenderTarget;
		std::unique_ptr<CreatePixelReadBuffer> m_createPixelReadBuffer;
		std::unique_ptr<BlitFramebuffers> m_blitFramebuffers;
		std::unique_ptr<graphics::FramebufferTextureFormats> m_fbTexFormats;

		std::unique_ptr<GraphicsDrawer> m_graphicsDrawer;

		std::unique_ptr<glsl::CombinerProgramBuilder> m_combinerProgramBuilder;
		std::unique_ptr<glsl::SpecialShadersFactory> m_specialShadersFactory;
		GLInfo m_glInfo;
		graphics::ClampMode m_clampMode;
	};

}
