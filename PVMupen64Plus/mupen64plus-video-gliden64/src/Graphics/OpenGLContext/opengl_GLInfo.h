#pragma once
#include "GLFunctions.h"

namespace opengl {

enum class Renderer {
	Adreno530,
	Adreno_no_bugs,
	Adreno,
	VideoCore,
	Intel,
	Other
};

struct GLInfo {
	GLint majorVersion = 0;
	GLint minorVersion = 0;
	bool isGLES2 = false;
	bool isGLESX = false;
	bool imageTextures = false;
	bool bufferStorage = false;
	bool texStorage    = false;
	bool shaderStorage = false;
	bool msaa = false;
	Renderer renderer = Renderer::Other;

	void init();
};
}
