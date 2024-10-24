#pragma once
#include <Graphics/OpenGLContext/opengl_GLInfo.h>
#include "glsl_CombinerProgramImpl.h"

namespace glsl {

	class CombinerProgramUniformFactory
	{
	public:
		CombinerProgramUniformFactory(const opengl::GLInfo & _glInfo);

		void buildUniforms(GLuint _program,
							const CombinerInputs & _inputs,
							const CombinerKey & _key,
							UniformGroups & _uniforms);

	private:
		const opengl::GLInfo & m_glInfo;
	};

}
