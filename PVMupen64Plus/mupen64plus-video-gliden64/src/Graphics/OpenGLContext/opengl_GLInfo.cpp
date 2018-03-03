#include <Log.h>
#include <Config.h>
#include "opengl_Utils.h"
#include "opengl_GLInfo.h"
#include <regex>
#ifdef EGL
#include <EGL/egl.h>
#endif

using namespace opengl;

void GLInfo::init() {
	const char * strVersion = reinterpret_cast<const char *>(glGetString(GL_VERSION));
	isGLESX = strstr(strVersion, "OpenGL ES") != nullptr;
	isGLES2 = strstr(strVersion, "OpenGL ES 2") != nullptr;
	if (isGLES2) {
		majorVersion = 2;
		minorVersion = 0;
	} else {
		glGetIntegerv(GL_MAJOR_VERSION, &majorVersion);
		glGetIntegerv(GL_MINOR_VERSION, &minorVersion);
	}
	LOG(LOG_VERBOSE, "%s major version: %d\n", isGLESX ? "OpenGL ES" : "OpenGL", majorVersion);
	LOG(LOG_VERBOSE, "%s minor version: %d\n", isGLESX ? "OpenGL ES" : "OpenGL", minorVersion);


	LOG(LOG_VERBOSE, "OpenGL vendor: %s\n", glGetString(GL_VENDOR));
	const GLubyte * strRenderer = glGetString(GL_RENDERER);

	if (std::regex_match(std::string((const char*)strRenderer), std::regex("Adreno.*530")))
		renderer = Renderer::Adreno530;
	else if (std::regex_match(std::string((const char*)strRenderer), std::regex("Adreno.*540")) ||
		std::regex_match(std::string((const char*)strRenderer), std::regex("Adreno.*6\\d\\d")))
		renderer = Renderer::Adreno_no_bugs;
	else if (strstr((const char*)strRenderer, "Adreno") != nullptr)
		renderer = Renderer::Adreno;
	else if (strstr((const char*)strRenderer, "VideoCore IV") != nullptr)
		renderer = Renderer::VideoCore;
	else if (strstr((const char*)strRenderer, "Intel") != nullptr)
		renderer = Renderer::Intel;
	LOG(LOG_VERBOSE, "OpenGL renderer: %s\n", strRenderer);

	int numericVersion = majorVersion * 10 + minorVersion;
	if (isGLES2) {
		imageTextures = false;
		msaa = false;
	} else if (isGLESX) {
		imageTextures = (numericVersion >= 31) && IS_GL_FUNCTION_VALID(glBindImageTexture);
		msaa = numericVersion >= 31;
	} else {
		imageTextures = ((numericVersion >= 43) || (Utils::isExtensionSupported(*this, "GL_ARB_shader_image_load_store") &&
				Utils::isExtensionSupported(*this, "GL_ARB_compute_shader"))) && IS_GL_FUNCTION_VALID(glBindImageTexture);
		msaa = true;
	}
	if (!imageTextures && config.frameBufferEmulation.N64DepthCompare != 0) {
		config.frameBufferEmulation.N64DepthCompare = 0;
		LOG(LOG_WARNING, "N64 depth compare and depth based fog will not work without Image Textures support provided in OpenGL >= 4.3 or GLES >= 3.1\n");
	}
	if (isGLES2)
		config.generalEmulation.enableFragmentDepthWrite = 0;
	bufferStorage = (!isGLESX && (numericVersion >= 44)) || Utils::isExtensionSupported(*this, "GL_ARB_buffer_storage") ||
			Utils::isExtensionSupported(*this, "GL_EXT_buffer_storage");
#ifdef EGL
	if (isGLESX && bufferStorage)
		g_glBufferStorage = (PFNGLBUFFERSTORAGEPROC) eglGetProcAddress("glBufferStorageEXT");
#endif
	texStorage = (isGLESX && (numericVersion >= 30)) || (!isGLESX && numericVersion >= 42) ||
			Utils::isExtensionSupported(*this, "GL_ARB_texture_storage");

	shaderStorage = false;
	if (config.generalEmulation.enableShadersStorage != 0) {
		const char * strGetProgramBinary = isGLESX
			? "GL_OES_get_program_binary"
			: "GL_ARB_get_program_binary";
		if (Utils::isExtensionSupported(*this, strGetProgramBinary)) {
			GLint numBinaryFormats = 0;
			glGetIntegerv(GL_NUM_PROGRAM_BINARY_FORMATS, &numBinaryFormats);
			shaderStorage = numBinaryFormats > 0;
		}
	}
#ifndef OS_ANDROID
	if (isGLES2 && config.frameBufferEmulation.copyToRDRAM == Config::ctAsync) {
		config.frameBufferEmulation.copyToRDRAM = Config::ctDisable;
		LOG(LOG_WARNING, "Async color buffer copies are not supported on GLES2\n");
	}
#endif
	if (isGLES2 && config.generalEmulation.enableLOD) {
		if (!Utils::isExtensionSupported(*this, "GL_EXT_shader_texture_lod") || !Utils::isExtensionSupported(*this, "GL_OES_standard_derivatives")) {
			config.generalEmulation.enableLOD = 0;
			LOG(LOG_WARNING, "LOD emulation not possible on this device\n");
		}
	}
}
