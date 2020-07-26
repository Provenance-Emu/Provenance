#include <stdio.h>
#include <stdlib.h>

#include <EGL/egl.h>
#include <GLES/gl.h>
#include "gl_platform.h"
#include "gl.h"

static EGLDisplay edpy;
static EGLSurface esfc;
static EGLContext ectxt;

/* for external flips */
void *gl_es_display;
void *gl_es_surface;

static int gl_have_error(const char *name)
{
	GLenum e = glGetError();
	if (e != GL_NO_ERROR) {
		fprintf(stderr, "GL error: %s %x\n", name, e);
		return 1;
	}
	return 0;
}

static int gles_have_error(const char *name)
{
	EGLint e = eglGetError();
	if (e != EGL_SUCCESS) {
		fprintf(stderr, "%s %x\n", name, e);
		return 1;
	}
	return 0;
}

int gl_init(void *display, void *window, int *quirks)
{
	EGLConfig ecfg = NULL;
	GLuint texture_name = 0;
	void *tmp_texture_mem = NULL;
	EGLint num_config;
	int retval = -1;
	int ret;
	EGLint attr[] =
	{
		EGL_NONE
	};

	ret = gl_platform_init(&display, &window, quirks);
	if (ret != 0) {
		fprintf(stderr, "gl_platform_init failed with %d\n", ret);
		goto out;
	}

	tmp_texture_mem = calloc(1, 1024 * 512 * 2);
	if (tmp_texture_mem == NULL) {
		fprintf(stderr, "OOM\n");
		goto out;
	}

	edpy = eglGetDisplay((EGLNativeDisplayType)display);
	if (edpy == EGL_NO_DISPLAY) {
		fprintf(stderr, "Failed to get EGL display\n");
		goto out;
	}

	if (!eglInitialize(edpy, NULL, NULL)) {
		fprintf(stderr, "Failed to initialize EGL\n");
		goto out;
	}

	if (!eglChooseConfig(edpy, attr, &ecfg, 1, &num_config)) {
		fprintf(stderr, "Failed to choose config (%x)\n", eglGetError());
		goto out;
	}

	if (ecfg == NULL || num_config == 0) {
		fprintf(stderr, "No EGL configs available\n");
		goto out;
	}

	esfc = eglCreateWindowSurface(edpy, ecfg,
		(EGLNativeWindowType)window, NULL);
	if (esfc == EGL_NO_SURFACE) {
		fprintf(stderr, "Unable to create EGL surface (%x)\n",
			eglGetError());
		goto out;
	}

	ectxt = eglCreateContext(edpy, ecfg, EGL_NO_CONTEXT, NULL);
	if (ectxt == EGL_NO_CONTEXT) {
		fprintf(stderr, "Unable to create EGL context (%x)\n",
			eglGetError());
		goto out;
	}

	eglMakeCurrent(edpy, esfc, esfc, ectxt);

	glEnable(GL_TEXTURE_2D);

	glGenTextures(1, &texture_name);

	glBindTexture(GL_TEXTURE_2D, texture_name);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 1024, 512, 0, GL_RGB,
		GL_UNSIGNED_SHORT_5_6_5, tmp_texture_mem);
	if (gl_have_error("glTexImage2D"))
		goto out;

	// no mipmaps
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

	//glViewport(0, 0, 512, 512);
	glLoadIdentity();
	glFrontFace(GL_CW);
	glEnable(GL_CULL_FACE);

	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);

	if (gl_have_error("init"))
		goto out;

	gl_es_display = (void *)edpy;
	gl_es_surface = (void *)esfc;
	retval = 0;
out:
	free(tmp_texture_mem);
	return retval;
}

static float vertices[] = {
	-1.0f,  1.0f,  0.0f, // 0    0  1
	 1.0f,  1.0f,  0.0f, // 1  ^
	-1.0f, -1.0f,  0.0f, // 2  | 2  3
	 1.0f, -1.0f,  0.0f, // 3  +-->
};

static float texture[] = {
	0.0f, 0.0f, // we flip this:
	1.0f, 0.0f, // v^
	0.0f, 1.0f, //  |  u
	1.0f, 1.0f, //  +-->
};

int gl_flip(const void *fb, int w, int h)
{
	static int old_w, old_h;

	if (fb != NULL) {
		if (w != old_w || h != old_h) {
			float f_w = (float)w / 1024.0f;
			float f_h = (float)h / 512.0f;
			texture[1*2 + 0] = f_w;
			texture[2*2 + 1] = f_h;
			texture[3*2 + 0] = f_w;
			texture[3*2 + 1] = f_h;
			old_w = w;
			old_h = h;
		}

		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h,
			GL_RGB, GL_UNSIGNED_SHORT_5_6_5, fb);
		if (gl_have_error("glTexSubImage2D"))
			return -1;
	}

	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, texture);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

	if (gl_have_error("glDrawArrays"))
		return -1;

	eglSwapBuffers(edpy, esfc);
	if (gles_have_error("eglSwapBuffers"))
		return -1;

	return 0;
}

void gl_finish(void)
{
	eglMakeCurrent(edpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
	eglDestroyContext(edpy, ectxt);
	ectxt = EGL_NO_CONTEXT;
	eglDestroySurface(edpy, esfc);
	esfc = EGL_NO_SURFACE;
	eglTerminate(edpy);
	edpy = EGL_NO_DISPLAY;

	gl_es_display = (void *)edpy;
	gl_es_surface = (void *)esfc;

	gl_platform_finish();
}
