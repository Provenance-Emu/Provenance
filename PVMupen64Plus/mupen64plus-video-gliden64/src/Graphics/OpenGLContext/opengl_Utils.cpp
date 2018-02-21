#include <assert.h>
#include <Types.h>
#include <Log.h>
#include "opengl_Utils.h"
#include "GLFunctions.h"
#include <cstring>

using namespace opengl;

bool Utils::isExtensionSupported(const opengl::GLInfo & _glinfo, const char *extension) {
	if (_glinfo.majorVersion >= 3) {
		GLint count = 0;
		glGetIntegerv(GL_NUM_EXTENSIONS, &count);
		assert(count >= 0);
		for (GLuint i = 0; i < (GLuint)count; ++i) {
			const char* name = (const char*)glGetStringi(GL_EXTENSIONS, i);
			if (name == nullptr)
				continue;
			if (strcmp(extension, name) == 0)
				return true;
		}
		return false;
	}

	GLubyte *where = (GLubyte *)strchr(extension, ' ');
	if (where || *extension == '\0')
		return false;

	const GLubyte *extensions = glGetString(GL_EXTENSIONS);

	const GLubyte *start = extensions;
	for (;;) {
		where = (GLubyte *)strstr((const char *)start, extension);
		if (where == nullptr)
			break;

		GLubyte *terminator = where + strlen(extension);
		if (where == start || *(where - 1) == ' ') if (*terminator == ' ' || *terminator == '\0')
			return true;

		start = terminator;
	}

	return false;
}


static
const char* GLErrorString(GLenum errorCode)
{
	static const struct {
		GLenum code;
		const char *string;
	} errors[] =
	{
		/* GL */
		{ GL_NO_ERROR, "no error" },
		{ GL_INVALID_ENUM, "invalid enumerant" },
		{ GL_INVALID_VALUE, "invalid value" },
		{ GL_INVALID_OPERATION, "invalid operation" },
#if !defined(GLESX) && !defined(OS_MAC_OS_X)
		{ GL_STACK_OVERFLOW, "stack overflow" },
		{ GL_STACK_UNDERFLOW, "stack underflow" },
#endif
		{ GL_OUT_OF_MEMORY, "out of memory" },

		{ 0, nullptr }
	};

	int i;

	for (i = 0; errors[i].string; i++)
	{
		if (errors[i].code == errorCode)
		{
			return errors[i].string;
		}
	}

	return nullptr;
}

bool Utils::isGLError()
{
	GLenum errCode;
	const char* errString;

	if ((errCode = glGetError()) != GL_NO_ERROR) {
		errString = GLErrorString(errCode);
		if (errString != nullptr) {
			LOG(LOG_ERROR, "OpenGL Error: %s (%x)", errString, errCode);
		} else {
			LOG(LOG_ERROR, "OpenGL Error: %x", errCode);
		}

		return true;
	}
	return false;
}

bool Utils::isFramebufferError()
{
	GLenum e = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	switch (e) {
		//		case GL_FRAMEBUFFER_UNDEFINED:
		//			printf("FBO Undefined\n");
		//			break;
	case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
		LOG(LOG_ERROR, "[GlideN64]: FBO Incomplete Attachment\n");
		break;
	case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
		LOG(LOG_ERROR, "[GlideN64]: FBO Missing Attachment\n");
		break;
		//		case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER :
		//			printf("FBO Incomplete Draw Buffer\n");
		//			break;
	case GL_FRAMEBUFFER_UNSUPPORTED:
		LOG(LOG_ERROR, "[GlideN64]: FBO Unsupported\n");
		break;
	case GL_FRAMEBUFFER_COMPLETE:
		//LOG(LOG_VERBOSE, "[GlideN64]: FBO OK\n");
		break;
		//		case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT:
		//			printf("framebuffer FRAMEBUFFER_DIMENSIONS\n");
		//			break;
		//		case GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT:
		//			printf("framebuffer INCOMPLETE_FORMATS\n");
		//			break;
	default:
		LOG(LOG_ERROR, "[GlideN64]: FBO Problem?\n");
	}

	return e != GL_FRAMEBUFFER_COMPLETE;
}
