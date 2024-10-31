#pragma once
#include "glsl_ShaderPart.h"
#include <Graphics/OpenGLContext/opengl_GLInfo.h>

namespace glsl {

	class FXAAVertexShader : public ShaderPart
	{
	public:
		FXAAVertexShader(const opengl::GLInfo & _glinfo);
	};

	class FXAAFragmentShader : public ShaderPart
	{
	public:
		FXAAFragmentShader(const opengl::GLInfo & _glinfo);
	};
}