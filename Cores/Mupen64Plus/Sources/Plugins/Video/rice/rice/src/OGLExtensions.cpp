/* OGLExtensions.cpp
Copyright (C) 2009 Richard Goedeken

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

/* This source file contains code for assigning function pointers to some OpenGL functions.
*/

#include "osal_opengl.h"
#include "OGLExtensions.h"
#include "Video.h"
#include "m64p_types.h"

#if !defined(__APPLE__)
    static void APIENTRY EmptyFunc(void) { return; }
    #define INIT_EMPTY_FUNC(type, funcname) type funcname = (type) EmptyFunc;
    #define INIT_GL_FUNC(type, funcname) \
      funcname = (type) CoreVideo_GL_GetProcAddress(#funcname); \
      if (funcname == NULL) { DebugMessage(M64MSG_WARNING, \
      "Couldn't get address of OpenGL function: '%s'", #funcname); funcname = (type) EmptyFunc; }
#endif


#ifdef USE_GLES
    // OpenGL ES headers already load every functions so this place is reserved
    // for maybe future ES extensions.
#else
// Desktop OpenGL
#if defined(WIN32)
    // Windows is OpenGL 1.1
    INIT_EMPTY_FUNC(PFNGLACTIVETEXTUREPROC,            glActiveTexture) // Added in OpenGL 1.3
    INIT_EMPTY_FUNC(PFNGLCREATESHADERPROC,             glCreateShader)
    INIT_EMPTY_FUNC(PFNGLSHADERSOURCEPROC,             glShaderSource)
    INIT_EMPTY_FUNC(PFNGLCOMPILESHADERPROC,            glCompileShader)
    INIT_EMPTY_FUNC(PFNGLGETSHADERIVPROC,              glGetShaderiv)
    INIT_EMPTY_FUNC(PFNGLGETSHADERINFOLOGPROC,         glGetShaderInfoLog)
    INIT_EMPTY_FUNC(PFNGLCREATEPROGRAMPROC,            glCreateProgram)
    INIT_EMPTY_FUNC(PFNGLATTACHSHADERPROC,             glAttachShader)
    INIT_EMPTY_FUNC(PFNGLBINDATTRIBLOCATIONPROC,       glBindAttribLocation)
    INIT_EMPTY_FUNC(PFNGLLINKPROGRAMPROC,              glLinkProgram)
    INIT_EMPTY_FUNC(PFNGLGETPROGRAMIVPROC,             glGetProgramiv)
    INIT_EMPTY_FUNC(PFNGLGETPROGRAMINFOLOGPROC,        glGetProgramInfoLog)
    INIT_EMPTY_FUNC(PFNGLDETACHSHADERPROC,             glDetachShader)
    INIT_EMPTY_FUNC(PFNGLGETUNIFORMLOCATIONPROC,       glGetUniformLocation)
    INIT_EMPTY_FUNC(PFNGLDELETESHADERPROC,             glDeleteShader)
    INIT_EMPTY_FUNC(PFNGLDELETEPROGRAMPROC,            glDeleteProgram)
    INIT_EMPTY_FUNC(PFNGLISSHADERPROC,                 glIsShader)
    INIT_EMPTY_FUNC(PFNGLISPROGRAMPROC,                glIsProgram)
    INIT_EMPTY_FUNC(PFNGLENABLEVERTEXATTRIBARRAYPROC,  glEnableVertexAttribArray)
    INIT_EMPTY_FUNC(PFNGLDISABLEVERTEXATTRIBARRAYPROC, glDisableVertexAttribArray)
    INIT_EMPTY_FUNC(PFNGLVERTEXATTRIBPOINTERPROC,      glVertexAttribPointer)
    INIT_EMPTY_FUNC(PFNGLUNIFORM4FPROC,                glUniform4f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM3FPROC,                glUniform3f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM2FPROC,                glUniform2f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM1FPROC,                glUniform1f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM1IPROC,                glUniform1i)
    INIT_EMPTY_FUNC(PFNGLUSEPROGRAMPROC,               glUseProgram)
#elif defined(__APPLE__)
    // OSX already support OpenGL 2.1 functions.
#else
    // Linux (OpenGL 1.3) and others
    INIT_EMPTY_FUNC(PFNGLCREATESHADERPROC,             glCreateShader)
    INIT_EMPTY_FUNC(PFNGLSHADERSOURCEPROC,             glShaderSource)
    INIT_EMPTY_FUNC(PFNGLCOMPILESHADERPROC,            glCompileShader)
    INIT_EMPTY_FUNC(PFNGLGETSHADERIVPROC,              glGetShaderiv)
    INIT_EMPTY_FUNC(PFNGLGETSHADERINFOLOGPROC,         glGetShaderInfoLog)
    INIT_EMPTY_FUNC(PFNGLCREATEPROGRAMPROC,            glCreateProgram)
    INIT_EMPTY_FUNC(PFNGLATTACHSHADERPROC,             glAttachShader)
    INIT_EMPTY_FUNC(PFNGLBINDATTRIBLOCATIONPROC,       glBindAttribLocation)
    INIT_EMPTY_FUNC(PFNGLLINKPROGRAMPROC,              glLinkProgram)
    INIT_EMPTY_FUNC(PFNGLGETPROGRAMIVPROC,             glGetProgramiv)
    INIT_EMPTY_FUNC(PFNGLGETPROGRAMINFOLOGPROC,        glGetProgramInfoLog)
    INIT_EMPTY_FUNC(PFNGLDETACHSHADERPROC,             glDetachShader)
    INIT_EMPTY_FUNC(PFNGLGETUNIFORMLOCATIONPROC,       glGetUniformLocation)
    INIT_EMPTY_FUNC(PFNGLDELETESHADERPROC,             glDeleteShader)
    INIT_EMPTY_FUNC(PFNGLDELETEPROGRAMPROC,            glDeleteProgram)
    INIT_EMPTY_FUNC(PFNGLISSHADERPROC,                 glIsShader)
    INIT_EMPTY_FUNC(PFNGLISPROGRAMPROC,                glIsProgram)
    INIT_EMPTY_FUNC(PFNGLENABLEVERTEXATTRIBARRAYPROC,  glEnableVertexAttribArray)
    INIT_EMPTY_FUNC(PFNGLDISABLEVERTEXATTRIBARRAYPROC, glDisableVertexAttribArray)
    INIT_EMPTY_FUNC(PFNGLVERTEXATTRIBPOINTERPROC,      glVertexAttribPointer)
    INIT_EMPTY_FUNC(PFNGLUNIFORM4FPROC,                glUniform4f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM3FPROC,                glUniform3f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM2FPROC,                glUniform2f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM1FPROC,                glUniform1f)
    INIT_EMPTY_FUNC(PFNGLUNIFORM1IPROC,                glUniform1i)
    INIT_EMPTY_FUNC(PFNGLUSEPROGRAMPROC,               glUseProgram)
#endif // OS specific
#endif // USE_GLES

void OGLExtensions_Init(void)
{
// See above for #ifdef #else documentation
#ifdef USE_GLES
    // empty
#else
#if defined(WIN32)
    INIT_GL_FUNC(PFNGLACTIVETEXTUREPROC,            glActiveTexture)
    INIT_GL_FUNC(PFNGLCREATESHADERPROC,             glCreateShader)
    INIT_GL_FUNC(PFNGLSHADERSOURCEPROC,             glShaderSource)
    INIT_GL_FUNC(PFNGLCOMPILESHADERPROC,            glCompileShader)
    INIT_GL_FUNC(PFNGLGETSHADERIVPROC,              glGetShaderiv)
    INIT_GL_FUNC(PFNGLGETSHADERINFOLOGPROC,         glGetShaderInfoLog)
    INIT_GL_FUNC(PFNGLCREATEPROGRAMPROC,            glCreateProgram)
    INIT_GL_FUNC(PFNGLATTACHSHADERPROC,             glAttachShader)
    INIT_GL_FUNC(PFNGLBINDATTRIBLOCATIONPROC,       glBindAttribLocation)
    INIT_GL_FUNC(PFNGLLINKPROGRAMPROC,              glLinkProgram)
    INIT_GL_FUNC(PFNGLGETPROGRAMIVPROC,             glGetProgramiv)
    INIT_GL_FUNC(PFNGLGETPROGRAMINFOLOGPROC,        glGetProgramInfoLog)
    INIT_GL_FUNC(PFNGLGETUNIFORMLOCATIONPROC,       glGetUniformLocation)
    INIT_GL_FUNC(PFNGLDETACHSHADERPROC,             glDetachShader)
    INIT_GL_FUNC(PFNGLDELETESHADERPROC,             glDeleteShader)
    INIT_GL_FUNC(PFNGLDELETEPROGRAMPROC,            glDeleteProgram)
    INIT_GL_FUNC(PFNGLISSHADERPROC,                 glIsShader)
    INIT_GL_FUNC(PFNGLISPROGRAMPROC,                glIsProgram)
    INIT_GL_FUNC(PFNGLENABLEVERTEXATTRIBARRAYPROC,  glEnableVertexAttribArray)
    INIT_GL_FUNC(PFNGLDISABLEVERTEXATTRIBARRAYPROC, glDisableVertexAttribArray)
    INIT_GL_FUNC(PFNGLVERTEXATTRIBPOINTERPROC,      glVertexAttribPointer)
    INIT_GL_FUNC(PFNGLUNIFORM4FPROC,                glUniform4f)
    INIT_GL_FUNC(PFNGLUNIFORM3FPROC,                glUniform3f)
    INIT_GL_FUNC(PFNGLUNIFORM2FPROC,                glUniform2f)
    INIT_GL_FUNC(PFNGLUNIFORM1FPROC,                glUniform1f)
    INIT_GL_FUNC(PFNGLUNIFORM1IPROC,                glUniform1i)
    INIT_GL_FUNC(PFNGLUSEPROGRAMPROC,               glUseProgram)
#elif defined(__APPLE__)
    // empty
#else
    INIT_GL_FUNC(PFNGLCREATESHADERPROC,             glCreateShader)
    INIT_GL_FUNC(PFNGLSHADERSOURCEPROC,             glShaderSource)
    INIT_GL_FUNC(PFNGLCOMPILESHADERPROC,            glCompileShader)
    INIT_GL_FUNC(PFNGLGETSHADERIVPROC,              glGetShaderiv)
    INIT_GL_FUNC(PFNGLGETSHADERINFOLOGPROC,         glGetShaderInfoLog)
    INIT_GL_FUNC(PFNGLCREATEPROGRAMPROC,            glCreateProgram)
    INIT_GL_FUNC(PFNGLATTACHSHADERPROC,             glAttachShader)
    INIT_GL_FUNC(PFNGLBINDATTRIBLOCATIONPROC,       glBindAttribLocation)
    INIT_GL_FUNC(PFNGLLINKPROGRAMPROC,              glLinkProgram)
    INIT_GL_FUNC(PFNGLGETPROGRAMIVPROC,             glGetProgramiv)
    INIT_GL_FUNC(PFNGLGETPROGRAMINFOLOGPROC,        glGetProgramInfoLog)
    INIT_GL_FUNC(PFNGLGETUNIFORMLOCATIONPROC,       glGetUniformLocation)
    INIT_GL_FUNC(PFNGLDETACHSHADERPROC,             glDetachShader)
    INIT_GL_FUNC(PFNGLDELETESHADERPROC,             glDeleteShader)
    INIT_GL_FUNC(PFNGLDELETEPROGRAMPROC,            glDeleteProgram)
    INIT_GL_FUNC(PFNGLISSHADERPROC,                 glIsShader)
    INIT_GL_FUNC(PFNGLISPROGRAMPROC,                glIsProgram)
    INIT_GL_FUNC(PFNGLENABLEVERTEXATTRIBARRAYPROC,  glEnableVertexAttribArray)
    INIT_GL_FUNC(PFNGLDISABLEVERTEXATTRIBARRAYPROC, glDisableVertexAttribArray)
    INIT_GL_FUNC(PFNGLVERTEXATTRIBPOINTERPROC,      glVertexAttribPointer)
    INIT_GL_FUNC(PFNGLUNIFORM4FPROC,                glUniform4f)
    INIT_GL_FUNC(PFNGLUNIFORM3FPROC,                glUniform3f)
    INIT_GL_FUNC(PFNGLUNIFORM2FPROC,                glUniform2f)
    INIT_GL_FUNC(PFNGLUNIFORM1FPROC,                glUniform1f)
    INIT_GL_FUNC(PFNGLUNIFORM1IPROC,                glUniform1i)
    INIT_GL_FUNC(PFNGLUSEPROGRAMPROC,               glUseProgram)
#endif // OS specific
#endif // USE_GLES
}

