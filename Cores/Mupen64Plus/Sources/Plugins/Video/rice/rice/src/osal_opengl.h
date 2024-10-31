/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - osal_opengl.h                                           *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2013 Richard Goedeken                                   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#if !defined(OSAL_OPENGL_H)
#define OSAL_OPENGL_H

#include <SDL_config.h>

// Vertex shader params
#define VS_POSITION             0
#define VS_COLOR                1
#define VS_TEXCOORD0            2
#define VS_TEXCOORD1            3
#define VS_FOG                  4

#ifdef USE_GLES

#ifndef SDL_VIDEO_OPENGL_ES2
#error SDL is not build with OpenGL ES2 support. Try USE_GLES=0
#endif

#include <SDL_opengles2.h>

#define GLSL_VERSION "100"

// SDL_opengles2.h define GL_APIENTRYP instead of APIENTRYP
#define APIENTRYP GL_APIENTRYP

// Constant substitutions
#define GL_CLAMP                GL_CLAMP_TO_EDGE
#define GL_MIRRORED_REPEAT_ARB  GL_MIRRORED_REPEAT

#define GL_ADD                  0x0104
#define GL_MODULATE             0x2100
#define GL_INTERPOLATE          0x8575
#define GL_CONSTANT             0x8576
#define GL_PREVIOUS             0x8578

// Function substitutions
#define glClearDepth            glClearDepthf
#define glDepthRange            glDepthRangef

// No-op substitutions (unavailable in GLES2)
#define glLoadIdentity()
#define glReadBuffer(x)
#define glTexEnvi(x,y,z)

#else // !USE_GLES

#ifndef SDL_VIDEO_OPENGL
#error SDL is not build with OpenGL support. Try USE_GLES=1
#endif

#if defined(__APPLE__)
    #include <OpenGL/gl.h>
    #include <OpenGL/glext.h>
    #define APIENTRY
#endif

#if defined(WIN32)
#include <windows.h>
#include <GL/gl.h>
#include <GL/glext.h>
#else
#include <SDL_opengl.h>
#endif

#define GLSL_VERSION "120"

#endif // !USE_GLES

#endif // OSAL_OPENGL_H
