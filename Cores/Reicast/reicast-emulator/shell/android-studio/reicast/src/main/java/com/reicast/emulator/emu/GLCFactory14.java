package com.reicast.emulator.emu;

import android.annotation.TargetApi;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLExt;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import android.os.Build;
import android.util.Log;
import android.view.Window;

import java.util.Locale;

import javax.microedition.khronos.egl.EGL10;

@TargetApi(Build.VERSION_CODES.JELLY_BEAN_MR2)
public class GLCFactory14 {

	private static void LOGI(String S) { Log.i("GL2JNIView-v6",S); }
	private static void LOGW(String S) { Log.w("GL2JNIView-v6",S); }
	private static void LOGE(String S) { Log.e("GL2JNIView-v6",S); }

	private int DEPTH_COMPONENT16_NONLINEAR_NV = 0x8E2C;
	private int EGL_DEPTH_ENCODING_NV = 0x30E2;
	private int EGL_DEPTH_ENCODING_NONLINEAR_NV = 0x30E3;

	private static final int EGL_CONTEXT_CLIENT_VERSION = 0x3098;

	private void configureWindow() {
		GLES20.glEnable(GLES20.GL_DEPTH_TEST);
	}

	public EGLDisplay getDisplay() {
		EGLDisplay eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);

		if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
			throw new RuntimeException("eglGetDisplay failed");
		}

		int[] major = new int[1];
		int[] minor = new int[1];
		if (!EGL14.eglInitialize(eglDisplay, major, 0, minor, 0)) {
			throw new RuntimeException("eglInitialize failed");
		}
		if (minor[0] < 4) {
			throw new RuntimeException("EGL 1.4 required");
		}
		return eglDisplay;
	}

	public void terminate(EGLDisplay display) {
		EGL14.eglTerminate(display);
	}

	public EGLContext createContext(EGLDisplay display, EGLConfig eglConfig)
	{
		EGLContext context = EGL14.EGL_NO_CONTEXT;
		for ( int clientVersion = 3; clientVersion >= 2; clientVersion-- ) {
			int[] attrList = { EGL_CONTEXT_CLIENT_VERSION, clientVersion, EGL14.EGL_NONE };

			LOGI("Creating OpenGL ES " + clientVersion + " context");

			context = EGL14.eglCreateContext(display, eglConfig, EGL14.EGL_NO_CONTEXT, attrList, 0);
			if (context != EGL14.EGL_NO_CONTEXT) {
				break;
			}
		}
		return(context);
	}

	public void destroyContext(EGLDisplay display, EGLContext context) {
		EGL14.eglDestroyContext(display, context);
	}

	private static void checkEglError(String prompt,EGL10 egl)
	{
		int error;

		while((error=egl.eglGetError()) != EGL14.EGL_SUCCESS)
			LOGE(String.format(Locale.getDefault(), "%s: EGL error: 0x%x",prompt,error));
	}

	// Subclasses can adjust these values:
	protected int mRedSize;
	protected int mGreenSize;
	protected int mBlueSize;
	protected int mAlphaSize;
	protected int mDepthSize;
	protected int mStencilSize;
	private int[] mValue = new int[1];

	public EGLConfig chooseConfig(EGLDisplay display) {
		mValue = new int[1];

		int glAPIToTry = EGLExt.EGL_OPENGL_ES3_BIT_KHR;
		int[] configSpec = null;

		do {
			EGL14.eglBindAPI(glAPIToTry);

			int renderableType;
			if (glAPIToTry == EGLExt.EGL_OPENGL_ES3_BIT_KHR) {
				renderableType = EGLExt.EGL_OPENGL_ES3_BIT_KHR;
				// If this API does not work, try ES2 next.
				glAPIToTry = EGL14.EGL_OPENGL_ES2_BIT;
			} else {
				renderableType = EGL14.EGL_OPENGL_ES2_BIT;
				// If this API does not work, is a potato.
				glAPIToTry = EGL10.EGL_NONE;
			}

			// This EGL config specification is used to specify 3.0 rendering.
			// We use a minimum size of 8 bits for red/green/blue, but will
			// perform actual matching in chooseConfig() below.
			configSpec = new int[] {
					EGL14.EGL_RED_SIZE, 8,
					EGL14.EGL_GREEN_SIZE, 8,
					EGL14.EGL_BLUE_SIZE, 8,
					EGL14.EGL_RENDERABLE_TYPE, renderableType,
					EGL14.EGL_DEPTH_SIZE, 16,
					EGL14.EGL_NONE
			};

			if (!EGL14.eglChooseConfig(display, configSpec, 0,null, 0, 0, mValue, 0)) {
				configSpec[9] = 16;
				if (!EGL14.eglChooseConfig(display, configSpec, 0,null, 0, 0, mValue, 0)) {
					throw new IllegalArgumentException("Could not get context count");
				}
			}

		} while (glAPIToTry != EGL10.EGL_NONE && mValue[0]<=0);

		if (mValue[0]<=0) {
			throw new IllegalArgumentException("No configs match configSpec");
		}

		// Get all matching configurations.
		EGLConfig[] configs = new EGLConfig[mValue[0]];
		if (GL2JNIView.DEBUG)
			LOGW(String.format(Locale.getDefault(), "%d configurations", configs.length));
		if (!EGL14.eglChooseConfig(display, configSpec, 0, configs,0, mValue[0], mValue, 0)) {
			throw new IllegalArgumentException("Could not get config data");
		}

		for (int i = 0; i < configs.length; ++i) {
			EGLConfig config = configs[i];
			int d = findConfigAttrib(display, config, EGL14.EGL_DEPTH_SIZE, 0);
			int s = findConfigAttrib(display, config, EGL14.EGL_STENCIL_SIZE, 0);

			// We need at least mDepthSize and mStencilSize bits
			if (d >= mDepthSize || s >= mStencilSize) {
				// We want an *exact* match for red/green/blue/alpha
				int r = findConfigAttrib(display, config, EGL14.EGL_RED_SIZE, 0);
				int g = findConfigAttrib(display, config, EGL14.EGL_GREEN_SIZE, 0);
				int b = findConfigAttrib(display, config, EGL14.EGL_BLUE_SIZE, 0);
				int a = findConfigAttrib(display, config, EGL14.EGL_ALPHA_SIZE, 0);

				if (r == mRedSize && g == mGreenSize && b == mBlueSize
						&& a == mAlphaSize)
					if (GL2JNIView.DEBUG) {
						LOGW(String.format(Locale.ENGLISH, "Configuration %d:", i));
						printConfig(display, configs[i]);
					}
				return config;
			}
		}

		throw new IllegalArgumentException("Could not find suitable EGL config");
	}

	private int findConfigAttrib(EGLDisplay display, EGLConfig config, int defaultValue, int attribute) {
		int[] value = new int[1];
		if (EGL14.eglGetConfigAttrib(display, config, attribute, value, 0)) {
			return value[0];
		}
		return defaultValue;
	}

	private void printConfig(EGLDisplay display, EGLConfig config)
	{
		final int[] attributes =
				{
						EGL14.EGL_BUFFER_SIZE,
						EGL14.EGL_ALPHA_SIZE,
						EGL14.EGL_BLUE_SIZE,
						EGL14.EGL_GREEN_SIZE,
						EGL14.EGL_RED_SIZE,
						EGL14.EGL_DEPTH_SIZE,
						EGL14.EGL_STENCIL_SIZE,
						EGL14.EGL_CONFIG_CAVEAT,
						EGL14.EGL_CONFIG_ID,
						EGL14.EGL_LEVEL,
						EGL14.EGL_MAX_PBUFFER_HEIGHT,
						EGL14.EGL_MAX_PBUFFER_PIXELS,
						EGL14.EGL_MAX_PBUFFER_WIDTH,
						EGL14.EGL_NATIVE_RENDERABLE,
						EGL14.EGL_NATIVE_VISUAL_ID,
						EGL14.EGL_NATIVE_VISUAL_TYPE,
						0x3030, // EGL14.EGL_PRESERVED_RESOURCES,
						EGL14.EGL_SAMPLES,
						EGL14.EGL_SAMPLE_BUFFERS,
						EGL14.EGL_SURFACE_TYPE,
						EGL14.EGL_TRANSPARENT_TYPE,
						EGL14.EGL_TRANSPARENT_RED_VALUE,
						EGL14.EGL_TRANSPARENT_GREEN_VALUE,
						EGL14.EGL_TRANSPARENT_BLUE_VALUE,
						EGL14.EGL_BIND_TO_TEXTURE_RGB,
						EGL14.EGL_BIND_TO_TEXTURE_RGBA,
						EGL14.EGL_MIN_SWAP_INTERVAL,
						EGL14.EGL_MAX_SWAP_INTERVAL,
						EGL14.EGL_LUMINANCE_SIZE,
						EGL14.EGL_ALPHA_MASK_SIZE,
						EGL14.EGL_COLOR_BUFFER_TYPE,
						EGL14.EGL_RENDERABLE_TYPE,
						EGL14.EGL_CONFORMANT
				};

		final String[] names =
				{
						"EGL_BUFFER_SIZE",
						"EGL_ALPHA_SIZE",
						"EGL_BLUE_SIZE",
						"EGL_GREEN_SIZE",
						"EGL_RED_SIZE",
						"EGL_DEPTH_SIZE",
						"EGL_STENCIL_SIZE",
						"EGL_CONFIG_CAVEAT",
						"EGL_CONFIG_ID",
						"EGL_LEVEL",
						"EGL_MAX_PBUFFER_HEIGHT",
						"EGL_MAX_PBUFFER_PIXELS",
						"EGL_MAX_PBUFFER_WIDTH",
						"EGL_NATIVE_RENDERABLE",
						"EGL_NATIVE_VISUAL_ID",
						"EGL_NATIVE_VISUAL_TYPE",
						"EGL_PRESERVED_RESOURCES",
						"EGL_SAMPLES",
						"EGL_SAMPLE_BUFFERS",
						"EGL_SURFACE_TYPE",
						"EGL_TRANSPARENT_TYPE",
						"EGL_TRANSPARENT_RED_VALUE",
						"EGL_TRANSPARENT_GREEN_VALUE",
						"EGL_TRANSPARENT_BLUE_VALUE",
						"EGL_BIND_TO_TEXTURE_RGB",
						"EGL_BIND_TO_TEXTURE_RGBA",
						"EGL_MIN_SWAP_INTERVAL",
						"EGL_MAX_SWAP_INTERVAL",
						"EGL_LUMINANCE_SIZE",
						"EGL_ALPHA_MASK_SIZE",
						"EGL_COLOR_BUFFER_TYPE",
						"EGL_RENDERABLE_TYPE",
						"EGL_CONFORMANT"
				};

		int[] value = new int[1];

		for(int i=0 ; i<attributes.length ; i++)
			if(EGL14.eglGetConfigAttrib(display, config, attributes[i], value,0))
				LOGI(String.format(Locale.getDefault(), "  %s: %d\n",names[i],value[0]));
			else
				while(EGL14.eglGetError() != EGL14.EGL_SUCCESS);
	}

	public EGLSurface createWindowSurface(EGLDisplay display, EGLConfig config, Window window) {
		EGLSurface eglSurface = EGL14.eglCreateWindowSurface(display, config, window, null, 0);
		return eglSurface;
	}

	public void destroySurface(EGLDisplay display, EGLSurface window) {
		EGL14.eglDestroySurface(display, window);
	}
}
