/*
Copyright (C) 2003 Rice1964

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

#include <stdio.h>
#include <string.h>

#include "Texture.h"
#include "m64p_types.h"
#include "osal_opengl.h"

#define M64P_PLUGIN_PROTOTYPES 1
#include "Config.h"
#include "Debugger.h"
#include "m64p_plugin.h"
#ifndef USE_GLES
#include "OGLExtensions.h"
#endif
#include "OGLDebug.h"
#include "OGLGraphicsContext.h"
#include "TextureManager.h"
#include "Video.h"
#include "version.h"

COGLGraphicsContext::COGLGraphicsContext() :
    m_pExtensionStr(NULL)
{
}


COGLGraphicsContext::~COGLGraphicsContext()
{
}

bool COGLGraphicsContext::Initialize(uint32 dwWidth, uint32 dwHeight, BOOL bWindowed )
{
    DebugMessage(M64MSG_INFO, "Initializing OpenGL Device Context.");
    Lock();

    CGraphicsContext::Initialize(dwWidth, dwHeight, bWindowed );

    if( bWindowed )
    {
        windowSetting.statusBarHeightToUse = windowSetting.statusBarHeight;
        windowSetting.toolbarHeightToUse = windowSetting.toolbarHeight;
    }
    else
    {
        windowSetting.statusBarHeightToUse = 0;
        windowSetting.toolbarHeightToUse = 0;
    }

    int  depthBufferDepth = options.OpenglDepthBufferSetting;
    int  colorBufferDepth = 32;
    int bVerticalSync = windowSetting.bVerticalSync;
    if( options.colorQuality == TEXTURE_FMT_A4R4G4B4 ) colorBufferDepth = 16;

    // init sdl & gl
    DebugMessage(M64MSG_VERBOSE, "Initializing video subsystem...");
    if (CoreVideo_Init() != M64ERR_SUCCESS)   
        return false;

    /* hard-coded attribute values */
    const int iDOUBLEBUFFER = 1;

	// Provenance
#ifndef PROVENANCE
    /* set opengl attributes */
    CoreVideo_GL_SetAttribute(M64P_GL_DOUBLEBUFFER, iDOUBLEBUFFER);
    CoreVideo_GL_SetAttribute(M64P_GL_SWAP_CONTROL, bVerticalSync);
    CoreVideo_GL_SetAttribute(M64P_GL_BUFFER_SIZE, colorBufferDepth);
    CoreVideo_GL_SetAttribute(M64P_GL_DEPTH_SIZE, depthBufferDepth);
#endif

    /* set multisampling */
    if (options.multiSampling > 0)
    {
        CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLEBUFFERS, 1);
        if (options.multiSampling <= 2)
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 2);
        else if (options.multiSampling <= 4)
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 4);
        else if (options.multiSampling <= 8)
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 8);
        else
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 16);
    }

    /* Set the video mode */
    m64p_video_mode ScreenMode = bWindowed ? M64VIDEO_WINDOWED : M64VIDEO_FULLSCREEN;
    m64p_video_flags flags = M64VIDEOFLAG_SUPPORT_RESIZING;
    if (CoreVideo_SetVideoMode(windowSetting.uDisplayWidth, windowSetting.uDisplayHeight, colorBufferDepth, ScreenMode, flags) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_ERROR, "Failed to set %i-bit video mode: %ix%i", colorBufferDepth, (int)windowSetting.uDisplayWidth, (int)windowSetting.uDisplayHeight);
        CoreVideo_Quit();
        return false;
    }

	// Provenance
#ifndef PROVENANCE
    /* check that our opengl attributes were properly set */
    int iActual;
    if (CoreVideo_GL_GetAttribute(M64P_GL_DOUBLEBUFFER, &iActual) == M64ERR_SUCCESS)
        if (iActual != iDOUBLEBUFFER)
            DebugMessage(M64MSG_WARNING, "Failed to set GL_DOUBLEBUFFER to %i. (it's %i)", iDOUBLEBUFFER, iActual);
    if (CoreVideo_GL_GetAttribute(M64P_GL_SWAP_CONTROL, &iActual) == M64ERR_SUCCESS)
        if (iActual != bVerticalSync)
            DebugMessage(M64MSG_WARNING, "Failed to set GL_SWAP_CONTROL to %i. (it's %i)", bVerticalSync, iActual);
    if (CoreVideo_GL_GetAttribute(M64P_GL_BUFFER_SIZE, &iActual) == M64ERR_SUCCESS)
        if (iActual != colorBufferDepth)
            DebugMessage(M64MSG_WARNING, "Failed to set GL_BUFFER_SIZE to %i. (it's %i)", colorBufferDepth, iActual);
    if (CoreVideo_GL_GetAttribute(M64P_GL_DEPTH_SIZE, &iActual) == M64ERR_SUCCESS)
        if (iActual != depthBufferDepth)
            DebugMessage(M64MSG_WARNING, "Failed to set GL_DEPTH_SIZE to %i. (it's %i)", depthBufferDepth, iActual);
#endif

#ifndef USE_GLES
    /* Get function pointers to OpenGL extensions (blame Microsoft Windows for this) */
    OGLExtensions_Init();
#endif

    char caption[500];
    sprintf(caption, "%s v%i.%i.%i", PLUGIN_NAME, VERSION_PRINTF_SPLIT(PLUGIN_VERSION));
    CoreVideo_SetCaption(caption);
    SetWindowMode();

    m_pExtensionStr = glGetString(GL_EXTENSIONS);
    OPENGL_CHECK_ERRORS

    const unsigned char* renderStr  = glGetString(GL_RENDERER);
    const unsigned char* versionStr = glGetString(GL_VERSION);
    const unsigned char* vendorStr  = glGetString(GL_VENDOR);

    if (renderStr == NULL || versionStr == NULL || vendorStr == NULL)
    {
        DebugMessage(M64MSG_ERROR, "Can't get OpenGL informations. It's maybe a problem with your driver.");
        CoreVideo_Quit();
        return false;
    }

    DebugMessage(M64MSG_INFO, "Using OpenGL: %.60s - %.128s : %.60s", renderStr, versionStr, vendorStr);

    InitLimits();
    InitState();
    InitOGLExtension();

    Unlock();

    Clear(CLEAR_COLOR_AND_DEPTH_BUFFER);    // Clear buffers
    UpdateFrame();
    Clear(CLEAR_COLOR_AND_DEPTH_BUFFER);
    UpdateFrame();

    m_bReady = true;

    return true;
}

bool COGLGraphicsContext::ResizeInitialize(uint32 dwWidth, uint32 dwHeight, BOOL bWindowed )
{
    Lock();

    CGraphicsContext::Initialize(dwWidth, dwHeight, bWindowed );

    int  depthBufferDepth = options.OpenglDepthBufferSetting;
    int  colorBufferDepth = 32;
    int bVerticalSync = windowSetting.bVerticalSync;
    if( options.colorQuality == TEXTURE_FMT_A4R4G4B4 ) colorBufferDepth = 16;

    /* hard-coded attribute values */
    const int iDOUBLEBUFFER = 1;

    /* set opengl attributes */
    CoreVideo_GL_SetAttribute(M64P_GL_DOUBLEBUFFER, iDOUBLEBUFFER);
    CoreVideo_GL_SetAttribute(M64P_GL_SWAP_CONTROL, bVerticalSync);
    CoreVideo_GL_SetAttribute(M64P_GL_BUFFER_SIZE, colorBufferDepth);
    CoreVideo_GL_SetAttribute(M64P_GL_DEPTH_SIZE, depthBufferDepth);

    /* set multisampling */
    if (options.multiSampling > 0)
    {
        CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLEBUFFERS, 1);
        if (options.multiSampling <= 2)
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 2);
        else if (options.multiSampling <= 4)
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 4);
        else if (options.multiSampling <= 8)
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 8);
        else
            CoreVideo_GL_SetAttribute(M64P_GL_MULTISAMPLESAMPLES, 16);
    }

    /* Call Mupen64plus core Video Extension to resize the window, which will create a new OpenGL Context under SDL */
    if (CoreVideo_ResizeWindow(windowSetting.uDisplayWidth, windowSetting.uDisplayHeight) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_ERROR, "Failed to set %i-bit video mode: %ix%i", colorBufferDepth, (int)windowSetting.uDisplayWidth, (int)windowSetting.uDisplayHeight);
        CoreVideo_Quit();
        return false;
    }

    InitState();
    Unlock();

    Clear(CLEAR_COLOR_AND_DEPTH_BUFFER);    // Clear buffers
    UpdateFrame();
    Clear(CLEAR_COLOR_AND_DEPTH_BUFFER);
    UpdateFrame();
    
    return true;
}

// Init limiting OpenGL values
void COGLGraphicsContext::InitLimits(void)
{
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS,&m_maxTextureImageUnits);
    OPENGL_CHECK_ERRORS;
}

void COGLGraphicsContext::InitState(void)
{
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    OPENGL_CHECK_ERRORS;
    glClearDepth(1.0f);
    OPENGL_CHECK_ERRORS;

#ifndef USE_GLES
    glShadeModel(GL_SMOOTH);
    OPENGL_CHECK_ERRORS;

    glDisable(GL_ALPHA_TEST);
    OPENGL_CHECK_ERRORS;
#endif

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    OPENGL_CHECK_ERRORS;
    glDisable(GL_BLEND);
    OPENGL_CHECK_ERRORS;

    glFrontFace(GL_CCW);
    OPENGL_CHECK_ERRORS;
    glDisable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;
#ifndef USE_GLES
    glDisable(GL_NORMALIZE);
    OPENGL_CHECK_ERRORS;
#endif
    glDepthFunc(GL_LEQUAL);
    OPENGL_CHECK_ERRORS;
    glEnable(GL_DEPTH_TEST);
    OPENGL_CHECK_ERRORS;

#ifndef USE_GLES
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    OPENGL_CHECK_ERRORS;
#endif

    glEnable(GL_BLEND);
    OPENGL_CHECK_ERRORS;
#ifndef USE_GLES
    glEnable(GL_ALPHA_TEST);
    OPENGL_CHECK_ERRORS;
#endif

    glDepthRange(0.0f, 1.0f);
    OPENGL_CHECK_ERRORS;
}

void COGLGraphicsContext::InitOGLExtension(void)
{
    // Optional extension features
    m_bSupportAnisotropicFiltering = IsExtensionSupported("GL_EXT_texture_filter_anisotropic");

    // Compute maxAnisotropicFiltering
    m_maxAnisotropicFiltering = 0;

    if( m_bSupportAnisotropicFiltering
    && (options.anisotropicFiltering == 2
        || options.anisotropicFiltering == 4
        || options.anisotropicFiltering == 8
        || options.anisotropicFiltering == 16))
    {
        //Get the max value of aniso that the graphic card support
        glGetIntegerv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &m_maxAnisotropicFiltering);
        OPENGL_CHECK_ERRORS;

        // If user want more aniso than hardware can do
        if(options.anisotropicFiltering > (uint32) m_maxAnisotropicFiltering)
        {
            DebugMessage(M64MSG_INFO, "A value of '%i' is set for AnisotropicFiltering option but the hardware has a maximum value of '%i' so this will be used", options.anisotropicFiltering, m_maxAnisotropicFiltering);
        }

        //check if user want less anisotropy than hardware can do
        if((uint32) m_maxAnisotropicFiltering > options.anisotropicFiltering)
        m_maxAnisotropicFiltering = options.anisotropicFiltering;
    }

    m_bSupportTextureFormatBGRA = IsExtensionSupported("GL_EXT_texture_format_BGRA8888");
    m_bSupportDepthClampNV      = IsExtensionSupported("GL_NV_depth_clamp");
}

bool COGLGraphicsContext::IsExtensionSupported(const char* pExtName)
{
    if (strstr((const char*)m_pExtensionStr, pExtName) != NULL)
    {
        DebugMessage(M64MSG_VERBOSE, "OpenGL Extension '%s' is supported.", pExtName);
        return true;
    }
    else
    {
        DebugMessage(M64MSG_VERBOSE, "OpenGL Extension '%s' is NOT supported.", pExtName);
        return false;
    }
}

void COGLGraphicsContext::CleanUp()
{
    CoreVideo_Quit();
    m_bReady = false;
}


void COGLGraphicsContext::Clear(ClearFlag dwFlags, uint32 color, float depth)
{
    uint32 flag=0;
    if( dwFlags&CLEAR_COLOR_BUFFER )    flag |= GL_COLOR_BUFFER_BIT;
    if( dwFlags&CLEAR_DEPTH_BUFFER )    flag |= GL_DEPTH_BUFFER_BIT;

    float r = ((color>>16)&0xFF)/255.0f;
    float g = ((color>> 8)&0xFF)/255.0f;
    float b = ((color    )&0xFF)/255.0f;
    float a = ((color>>24)&0xFF)/255.0f;
    glClearColor(r, g, b, a);
    OPENGL_CHECK_ERRORS;
    glClearDepth(depth);
    OPENGL_CHECK_ERRORS;
    glClear(flag);  //Clear color buffer and depth buffer
    OPENGL_CHECK_ERRORS;
}

void COGLGraphicsContext::UpdateFrame(bool swaponly)
{
    status.gFrameCount++;

	// Provenance
#ifndef PROVENANCE
	glFlush();
    OPENGL_CHECK_ERRORS;
#endif
	//glFinish();
    //wglSwapIntervalEXT(0);

    /*
    if (debuggerPauseCount == countToPause)
    {
        static int iShotNum = 0;
        // get width, height, allocate buffer to store image
        int width = windowSetting.uDisplayWidth;
        int height = windowSetting.uDisplayHeight;
        printf("Saving debug images: width=%i  height=%i\n", width, height);
        short *buffer = (short *) malloc(((width+3)&~3)*(height+1)*4);
        glReadBuffer( GL_FRONT );
        // set up a BMGImage struct
        struct BMGImageStruct img;
        memset(&img, 0, sizeof(BMGImageStruct));
        InitBMGImage(&img);
        img.bits = (unsigned char *) buffer;
        img.bits_per_pixel = 32;
        img.height = height;
        img.width = width;
        img.scan_width = width * 4;
        // store the RGB color image
        char chFilename[64];
        sprintf(chFilename, "dbg_rgb_%03i.png", iShotNum);
        glReadPixels(0,0,width,height, GL_BGRA, GL_UNSIGNED_BYTE, buffer);
        WritePNG(chFilename, img);
        // store the Z buffer
        sprintf(chFilename, "dbg_Z_%03i.png", iShotNum);
        glReadPixels(0,0,width,height, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, buffer);
        //img.bits_per_pixel = 16;
        //img.scan_width = width * 2;
        WritePNG(chFilename, img);
        // dump a subset of the Z data
        for (int y = 0; y < 480; y += 16)
        {
            for (int x = 0; x < 640; x+= 16)
                printf("%4hx ", buffer[y*640 + x]);
            printf("\n");
        }
        printf("\n");
        // free memory and get out of here
        free(buffer);
        iShotNum++;
        }
    */

   
   // if emulator defined a render callback function, call it before buffer swap
   if(renderCallback)
   {
       // For OGLFT (used by OSD) to work, we need to disable shaders
       // (which implicitly passe OpenGL in fixed pipeline mode)
       GLint program;
       glGetIntegerv(GL_CURRENT_PROGRAM ,&program);
       glUseProgram(0);

       (*renderCallback)(status.bScreenIsDrawn);

       glUseProgram(program);
   }

   CoreVideo_GL_SwapBuffers();
   
   /*if(options.bShowFPS)
     {
    static unsigned int lastTick=0;
    static int frames=0;
    unsigned int nowTick = SDL_GetTicks();
    frames++;
    if(lastTick + 5000 <= nowTick)
      {
         char caption[200];
         sprintf(caption, "%s v%i.%i.%i - %.3f VI/S", PLUGIN_NAME, VERSION_PRINTF_SPLIT(PLUGIN_VERSION), frames/5.0);
         CoreVideo_SetCaption(caption);
         frames = 0;
         lastTick = nowTick;
      }
     }*/

    glDepthMask(GL_TRUE);
    OPENGL_CHECK_ERRORS;
    glClearDepth(1.0f);
    OPENGL_CHECK_ERRORS;
    if( !g_curRomInfo.bForceScreenClear )
    {
        glClear(GL_DEPTH_BUFFER_BIT);
        OPENGL_CHECK_ERRORS;
    }
    else
        needCleanScene = true;

    status.bScreenIsDrawn = false;
}

bool COGLGraphicsContext::SetFullscreenMode()
{
    windowSetting.statusBarHeightToUse = 0;
    windowSetting.toolbarHeightToUse = 0;
    return true;
}

bool COGLGraphicsContext::SetWindowMode()
{
    windowSetting.statusBarHeightToUse = windowSetting.statusBarHeight;
    windowSetting.toolbarHeightToUse = windowSetting.toolbarHeight;
    return true;
}
int COGLGraphicsContext::ToggleFullscreen()
{
    if (CoreVideo_ToggleFullScreen() == M64ERR_SUCCESS)
    {
        m_bWindowed = !m_bWindowed;
        if(m_bWindowed)
            SetWindowMode();
        else
            SetFullscreenMode();
    }

    return m_bWindowed?0:1;
}
