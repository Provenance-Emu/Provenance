#pragma once
#include <Types.h>

namespace graphics {

	class ObjectHandle
	{
	public:
		ObjectHandle() : m_name(0) {}
		explicit ObjectHandle(u32 _name) : m_name(_name) {}
		explicit operator u32() const { return m_name; }
		bool operator==(const ObjectHandle & _other) const { return m_name == _other.m_name; }
		bool operator!=(const ObjectHandle & _other) const { return m_name != _other.m_name; }
		bool operator<(const ObjectHandle & _other) const { return m_name < _other.m_name; }

		bool isNotNull() const { return m_name != 0; }

		void reset() { m_name = 0; }

		static ObjectHandle null;
		static ObjectHandle defaultFramebuffer;
	private:
		u32 m_name;
	};

}
