#pragma once
#include "Parameter.h"

namespace graphics {

	class PixelReadBuffer
	{
	public:
		virtual ~PixelReadBuffer() {}
		virtual void readPixels(s32 _x,s32 _y, u32 _width, u32 _height, Parameter _format, Parameter _type) = 0;
		virtual void * getDataRange(u32 _offset, u32 _range) = 0;
		virtual void closeReadBuffer() = 0;
		virtual void bind() = 0;
		virtual void unbind() = 0;
	};

	template<class T>
	class PixelBufferBinder
	{
	public:
		PixelBufferBinder(T * _buffer)
			: m_buffer(_buffer) {
			m_buffer->bind();
		}

		~PixelBufferBinder() {
			m_buffer->unbind();
			m_buffer = nullptr;
		}
	private:
		T * m_buffer;
	};
}
