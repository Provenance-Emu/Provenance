#pragma once
#include <Types.h>

namespace graphics {

#define INVALID_PARAMETER 0xFFFFFFFF

	class Parameter
	{
	public:
		Parameter() : m_iparameter(INVALID_PARAMETER) {}
		Parameter(u32 _parameter) : m_iparameter(_parameter) {}
		Parameter(s32 _parameter) : m_iparameter(static_cast<u32>(_parameter)) {}
		Parameter(f32 _parameter) : m_fparameter(_parameter) {}

		explicit operator u32() const { return m_iparameter; }
		explicit operator s32() const { return static_cast<s32>(m_iparameter); }
		explicit operator f32() const { return m_fparameter; }

		bool isValid() const { return m_iparameter != INVALID_PARAMETER; }

		void reset() { m_iparameter = INVALID_PARAMETER; }

		bool operator==(const Parameter & _other) const { return m_iparameter == _other.m_iparameter; }
		bool operator!=(const Parameter & _other) const { return m_iparameter != _other.m_iparameter; }

	private:
		union {
			u32 m_iparameter;
			f32 m_fparameter;
		};
	};

#define SpecialParameterClass(A)						\
	class A : public Parameter							\
	{													\
	public:												\
		A() : Parameter() {}							\
		A(u32 _parameter) : Parameter(_parameter) {}	\
	}

	SpecialParameterClass(ImageUnitParam);
	SpecialParameterClass(TextureUnitParam);
	SpecialParameterClass(ColorFormatParam);
	SpecialParameterClass(InternalColorFormatParam);
	SpecialParameterClass(DatatypeParam);
	SpecialParameterClass(TextureTargetParam);
	SpecialParameterClass(BufferTargetParam);
	SpecialParameterClass(TextureParam);
	SpecialParameterClass(BufferAttachmentParam);
	SpecialParameterClass(EnableParam);
	SpecialParameterClass(ImageAccessModeParam);
	SpecialParameterClass(CullModeParam);
	SpecialParameterClass(CompareParam);
	SpecialParameterClass(BlendParam);
	SpecialParameterClass(DrawModeParam);
	SpecialParameterClass(BlitMaskParam);
}
