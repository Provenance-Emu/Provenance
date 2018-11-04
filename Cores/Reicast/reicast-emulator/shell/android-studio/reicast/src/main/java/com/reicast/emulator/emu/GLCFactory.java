package com.reicast.emulator.emu;

import android.opengl.GLSurfaceView;
import android.util.Log;

import java.util.Locale;

import javax.microedition.khronos.egl.EGL10;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.egl.EGLContext;
import javax.microedition.khronos.egl.EGLDisplay;

public class GLCFactory {

    private static void LOGI(String S) { Log.i("GL2JNIView",S); }
    private static void LOGW(String S) { Log.w("GL2JNIView",S); }
    private static void LOGE(String S) { Log.e("GL2JNIView",S); }

    private int DEPTH_COMPONENT16_NONLINEAR_NV = 0x8E2C;
    private int EGL_DEPTH_ENCODING_NV = 0x30E2;
    private int EGL_DEPTH_ENCODING_NONLINEAR_NV = 0x30E3;

    public static class ContextFactory implements GLSurfaceView.EGLContextFactory
    {
        private static final int EGL_CONTEXT_CLIENT_VERSION = 0x3098;

        public EGLContext createContext(EGL10 egl,EGLDisplay display,EGLConfig eglConfig)
        {
            int[] attrList = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL10.EGL_NONE };

            LOGI("Creating OpenGL ES 2.0 context");

            checkEglError("Before eglCreateContext",egl);
            EGLContext context = egl.eglCreateContext(display,eglConfig,EGL10.EGL_NO_CONTEXT,attrList);
            checkEglError("After eglCreateContext",egl);
            return(context);
        }

        public void destroyContext(EGL10 egl,EGLDisplay display,EGLContext context)
        {
            LOGI("Destroying OpenGL ES 2.0 context");
            egl.eglDestroyContext(display,context);
        }
    }

    private static void checkEglError(String prompt,EGL10 egl)
    {
        int error;

        while((error=egl.eglGetError()) != EGL10.EGL_SUCCESS)
            LOGE(String.format("%s: EGL error: 0x%x",prompt,error));
    }

    public static class ConfigChooser implements GLSurfaceView.EGLConfigChooser
    {
        // Subclasses can adjust these values:
        protected int mRedSize;
        protected int mGreenSize;
        protected int mBlueSize;
        protected int mAlphaSize;
        protected int mDepthSize;
        protected int mStencilSize;
        private int[] mValue = new int[1];

        public ConfigChooser(int r,int g,int b,int a,int depth,int stencil)
        {
            mRedSize     = r;
            mGreenSize   = g;
            mBlueSize    = b;
            mAlphaSize   = a;
            mDepthSize   = depth;
            mStencilSize = stencil;
        }

        // This EGL config specification is used to specify 2.0 rendering.
        // We use a minimum size of 4 bits for red/green/blue, but will
        // perform actual matching in chooseConfig() below.
        private static final int EGL_OPENGL_ES2_BIT = 4;
        private static final int[] cfgAttrs =
                {
                        EGL10.EGL_RED_SIZE,        4,
                        EGL10.EGL_GREEN_SIZE,      4,
                        EGL10.EGL_BLUE_SIZE,       4,
                        EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                        EGL10.EGL_DEPTH_SIZE,      24,
                        EGL10.EGL_NONE
                };

        public EGLConfig chooseConfig(EGL10 egl,EGLDisplay display)
        {
            // Get the number of minimally matching EGL configurations
            int[] cfgCount = new int[1];
            egl.eglChooseConfig(display,cfgAttrs,null,0,cfgCount);

            if (cfgCount[0]<=0)
            {
                cfgAttrs[9]=16;
                egl.eglChooseConfig(display,cfgAttrs,null,0,cfgCount);
            }


            if (cfgCount[0]<=0)
                throw new IllegalArgumentException("No configs match configSpec");

            // Allocate then read the array of minimally matching EGL configs
            EGLConfig[] configs = new EGLConfig[cfgCount[0]];
            egl.eglChooseConfig(display,cfgAttrs,configs,cfgCount[0],cfgCount);

            if (GL2JNIView.DEBUG)
                printConfigs(egl,display,configs);

            // Now return the "best" one
            return(chooseConfig(egl,display,configs));
        }

        public EGLConfig chooseConfig(EGL10 egl,EGLDisplay display,EGLConfig[] configs)
        {
            for (EGLConfig config : configs)
            {
                int d = findConfigAttrib(egl,display,config,EGL10.EGL_DEPTH_SIZE,0);
                int s = findConfigAttrib(egl,display,config,EGL10.EGL_STENCIL_SIZE,0);

                // We need at least mDepthSize and mStencilSize bits
                if (d>=mDepthSize || s>=mStencilSize)
                {
                    // We want an *exact* match for red/green/blue/alpha
                    int r = findConfigAttrib(egl,display,config,EGL10.EGL_RED_SIZE,  0);
                    int g = findConfigAttrib(egl,display,config,EGL10.EGL_GREEN_SIZE,0);
                    int b = findConfigAttrib(egl,display,config,EGL10.EGL_BLUE_SIZE, 0);
                    int a = findConfigAttrib(egl,display,config,EGL10.EGL_ALPHA_SIZE,0);

                    if(r==mRedSize && g==mGreenSize && b==mBlueSize && a==mAlphaSize)
                        return(config);
                }
            }

            return(null);
        }

        private int findConfigAttrib(EGL10 egl,EGLDisplay display,EGLConfig config,int attribute,int defaultValue)
        {
            return(egl.eglGetConfigAttrib(display,config,attribute,mValue)? mValue[0] : defaultValue);
        }

        private void printConfigs(EGL10 egl,EGLDisplay display,EGLConfig[] configs)
        {
            LOGW(String.format(Locale.getDefault(), "%d configurations", configs.length));

            for(int i=0 ; i<configs.length ; i++)
            {
                LOGW(String.format(Locale.getDefault(), "Configuration %d:", i));
                printConfig(egl,display,configs[i]);
            }
        }

        private void printConfig(EGL10 egl,EGLDisplay display,EGLConfig config)
        {
            final int[] attributes =
                    {
                            EGL10.EGL_BUFFER_SIZE,
                            EGL10.EGL_ALPHA_SIZE,
                            EGL10.EGL_BLUE_SIZE,
                            EGL10.EGL_GREEN_SIZE,
                            EGL10.EGL_RED_SIZE,
                            EGL10.EGL_DEPTH_SIZE,
                            EGL10.EGL_STENCIL_SIZE,
                            EGL10.EGL_CONFIG_CAVEAT,
                            EGL10.EGL_CONFIG_ID,
                            EGL10.EGL_LEVEL,
                            EGL10.EGL_MAX_PBUFFER_HEIGHT,
                            EGL10.EGL_MAX_PBUFFER_PIXELS,
                            EGL10.EGL_MAX_PBUFFER_WIDTH,
                            EGL10.EGL_NATIVE_RENDERABLE,
                            EGL10.EGL_NATIVE_VISUAL_ID,
                            EGL10.EGL_NATIVE_VISUAL_TYPE,
                            0x3030, // EGL10.EGL_PRESERVED_RESOURCES,
                            EGL10.EGL_SAMPLES,
                            EGL10.EGL_SAMPLE_BUFFERS,
                            EGL10.EGL_SURFACE_TYPE,
                            EGL10.EGL_TRANSPARENT_TYPE,
                            EGL10.EGL_TRANSPARENT_RED_VALUE,
                            EGL10.EGL_TRANSPARENT_GREEN_VALUE,
                            EGL10.EGL_TRANSPARENT_BLUE_VALUE,
                            0x3039, // EGL10.EGL_BIND_TO_TEXTURE_RGB,
                            0x303A, // EGL10.EGL_BIND_TO_TEXTURE_RGBA,
                            0x303B, // EGL10.EGL_MIN_SWAP_INTERVAL,
                            0x303C, // EGL10.EGL_MAX_SWAP_INTERVAL,
                            EGL10.EGL_LUMINANCE_SIZE,
                            EGL10.EGL_ALPHA_MASK_SIZE,
                            EGL10.EGL_COLOR_BUFFER_TYPE,
                            EGL10.EGL_RENDERABLE_TYPE,
                            0x3042 // EGL10.EGL_CONFORMANT
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

            for (int i=0 ; i<attributes.length ; i++)
                if (egl.eglGetConfigAttrib(display,config,attributes[i],value))
                    LOGI(String.format(Locale.getDefault(), "  %s: %d\n",names[i],value[0]));
                else
                    while(egl.eglGetError()!=EGL10.EGL_SUCCESS);
        }
    }
}
