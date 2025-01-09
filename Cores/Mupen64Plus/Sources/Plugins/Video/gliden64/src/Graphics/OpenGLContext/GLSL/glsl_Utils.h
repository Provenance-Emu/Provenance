#pragma once
#include <string>
#include <sstream>
#include <Graphics/OpenGLContext/GLFunctions.h>

namespace glsl {

	struct Utils {
		static void locateAttributes(GLuint _program, bool _rect, bool _textures);
		static bool checkShaderCompileStatus(GLuint obj);
		static bool checkProgramLinkStatus(GLuint obj);
		static void logErrorShader(GLenum _shaderType, const std::string & _strShader);
		static GLuint createRectShaderProgram(const char * _strVertex, const char * _strFragment);

		template <typename T>
		static std::string to_string(T value)
		{
#ifdef OS_ANDROID
			std::ostringstream os ;
			os << value ;
			return os.str() ;
#else
			return std::to_string(value);
#endif
		}
	};
}
