#pragma once
#include <Graphics/ObjectHandle.h>
#include <Graphics/Parameter.h>
#include <Graphics/Context.h>
#include <Graphics/PixelBuffer.h>
#include "opengl_GLInfo.h"

namespace opengl {

	struct GLInfo;
	class CachedFunctions;

	class CreateFramebufferObject
	{
	public:
		virtual ~CreateFramebufferObject() {}
		virtual graphics::ObjectHandle createFramebuffer() = 0;
	};

	class CreateRenderbuffer
	{
	public:
		virtual ~CreateRenderbuffer() {}
		virtual graphics::ObjectHandle createRenderbuffer() = 0;
	};

	class InitRenderbuffer
	{
	public:
		virtual ~InitRenderbuffer() {}
		virtual void initRenderbuffer(const graphics::Context::InitRenderbufferParams & _params) = 0;
	};

	class AddFramebufferRenderTarget
	{
	public:
		virtual ~AddFramebufferRenderTarget() {}
		virtual void addFrameBufferRenderTarget(const graphics::Context::FrameBufferRenderTarget & _params) = 0;
	};

	class CreatePixelReadBuffer
	{
	public:
		virtual ~CreatePixelReadBuffer() {}
		virtual graphics::PixelReadBuffer * createPixelReadBuffer(size_t _sizeInBytes) = 0;
	};

	class BlitFramebuffers
	{
	public:
		virtual ~BlitFramebuffers() {}
		virtual bool blitFramebuffers(const graphics::Context::BlitFramebuffersParams & _params) = 0;
	};

	class BufferManipulationObjectFactory
	{
	public:
		BufferManipulationObjectFactory(const GLInfo & _info, CachedFunctions & _cachedFunctions);
		~BufferManipulationObjectFactory();

		CreateFramebufferObject * getCreateFramebufferObject() const;

		CreateRenderbuffer * getCreateRenderbuffer() const;

		InitRenderbuffer * getInitRenderbuffer() const;

		AddFramebufferRenderTarget * getAddFramebufferRenderTarget() const;

		CreatePixelReadBuffer * createPixelReadBuffer() const;

		BlitFramebuffers * getBlitFramebuffers() const;

		graphics::FramebufferTextureFormats * getFramebufferTextureFormats() const;

	private:
		const GLInfo & m_glInfo;
		CachedFunctions & m_cachedFunctions;
	};

}
