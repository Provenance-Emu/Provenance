/* OGLExtensions.h
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

/* This header file contains function pointers to some OpenGL functions */
/* This is only necessary because Windows does not contain development support for OpenGL versions beyond 1.1 */

#ifndef OGL_EXTENSIONS_H
#define OGL_EXTENSIONS_H

#include "osal_opengl.h"

/* Just call this one function to load up the function pointers. */
void OGLExtensions_Init(void);

// See OGLExtensions.cpp for #ifdef #else documentation
#ifdef USE_GLES
    // nothing
#else
#if defined(WIN32)
    extern PFNGLACTIVETEXTUREPROC             glActiveTexture;
    extern PFNGLCREATESHADERPROC              glCreateShader;
    extern PFNGLSHADERSOURCEPROC              glShaderSource;
    extern PFNGLCOMPILESHADERPROC             glCompileShader;
    extern PFNGLGETSHADERIVPROC               glGetShaderiv;
    extern PFNGLGETSHADERINFOLOGPROC          glGetShaderInfoLog;
    extern PFNGLCREATEPROGRAMPROC             glCreateProgram;
    extern PFNGLATTACHSHADERPROC              glAttachShader;
    extern PFNGLBINDATTRIBLOCATIONPROC        glBindAttribLocation;
    extern PFNGLLINKPROGRAMPROC               glLinkProgram;
    extern PFNGLGETPROGRAMIVPROC              glGetProgramiv;
    extern PFNGLGETPROGRAMINFOLOGPROC         glGetProgramInfoLog;
    extern PFNGLDETACHSHADERPROC              glDetachShader;
    extern PFNGLGETUNIFORMLOCATIONPROC        glGetUniformLocation;
    extern PFNGLDELETESHADERPROC              glDeleteShader;
    extern PFNGLDELETEPROGRAMPROC             glDeleteProgram;
    extern PFNGLISSHADERPROC                  glIsShader;
    extern PFNGLISPROGRAMPROC                 glIsProgram;
    extern PFNGLENABLEVERTEXATTRIBARRAYPROC   glEnableVertexAttribArray;
    extern PFNGLDISABLEVERTEXATTRIBARRAYPROC  glDisableVertexAttribArray;
    extern PFNGLVERTEXATTRIBPOINTERPROC       glVertexAttribPointer;
    extern PFNGLUNIFORM4FPROC                 glUniform4f;
    extern PFNGLUNIFORM3FPROC                 glUniform3f;
    extern PFNGLUNIFORM2FPROC                 glUniform2f;
    extern PFNGLUNIFORM1FPROC                 glUniform1f;
    extern PFNGLUNIFORM1IPROC                 glUniform1i;
    extern PFNGLUSEPROGRAMPROC                glUseProgram;
#elif defined(__APPLE__)
    // nothing
#else
    extern PFNGLCREATESHADERPROC              glCreateShader;
    extern PFNGLSHADERSOURCEPROC              glShaderSource;
    extern PFNGLCOMPILESHADERPROC             glCompileShader;
    extern PFNGLGETSHADERIVPROC               glGetShaderiv;
    extern PFNGLGETSHADERINFOLOGPROC          glGetShaderInfoLog;
    extern PFNGLCREATEPROGRAMPROC             glCreateProgram;
    extern PFNGLATTACHSHADERPROC              glAttachShader;
    extern PFNGLBINDATTRIBLOCATIONPROC        glBindAttribLocation;
    extern PFNGLLINKPROGRAMPROC               glLinkProgram;
    extern PFNGLGETPROGRAMIVPROC              glGetProgramiv;
    extern PFNGLGETPROGRAMINFOLOGPROC         glGetProgramInfoLog;
    extern PFNGLDETACHSHADERPROC              glDetachShader;
    extern PFNGLGETUNIFORMLOCATIONPROC        glGetUniformLocation;
    extern PFNGLDELETESHADERPROC              glDeleteShader;
    extern PFNGLDELETEPROGRAMPROC             glDeleteProgram;
    extern PFNGLISSHADERPROC                  glIsShader;
    extern PFNGLISPROGRAMPROC                 glIsProgram;
    extern PFNGLENABLEVERTEXATTRIBARRAYPROC   glEnableVertexAttribArray;
    extern PFNGLDISABLEVERTEXATTRIBARRAYPROC  glDisableVertexAttribArray;
    extern PFNGLVERTEXATTRIBPOINTERPROC       glVertexAttribPointer;
    extern PFNGLUNIFORM4FPROC                 glUniform4f;
    extern PFNGLUNIFORM3FPROC                 glUniform3f;
    extern PFNGLUNIFORM2FPROC                 glUniform2f;
    extern PFNGLUNIFORM1FPROC                 glUniform1f;
    extern PFNGLUNIFORM1IPROC                 glUniform1i;
    extern PFNGLUSEPROGRAMPROC                glUseProgram;
#endif // OS specific
#endif // USE_GLES

#endif  // OGL_EXTENSIONS_H

