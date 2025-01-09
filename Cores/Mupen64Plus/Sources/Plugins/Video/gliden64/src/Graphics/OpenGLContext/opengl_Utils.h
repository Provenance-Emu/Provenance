#pragma once

#include "opengl_GLInfo.h"

namespace opengl {

	struct Utils
	{
		static bool isExtensionSupported(const opengl::GLInfo & _glinfo, const char * extension);
		static bool isGLError();
		static bool isFramebufferError();
	};

}
