#pragma once
#include "GLFunctions.h"

namespace opengl {

	// Triangle attributes
	namespace triangleAttrib {
		extern const GLuint position;
		extern const GLuint color;
		extern const GLuint texcoord;
		extern const GLuint numlights;
		extern const GLuint modify;
	}

	// Rect attributes
	namespace rectAttrib {
		extern const GLuint position;
		extern const GLuint texcoord0;
		extern const GLuint texcoord1;
	}

#define MaxAttribIndex 8
}
