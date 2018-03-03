/*
 * Texture Filtering
 * Version:  1.0
 *
 * Copyright (C) 2007  Hiroshi Morii   All Rights Reserved.
 * Email koolsmoky(at)users.sourceforge.net
 * Web   http://www.3dfxzone.it/koolsmoky
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * this is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNU Make; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef __INTERNAL_H__
#define __INTERNAL_H__

#include "Ext_TxFilter.h"
#include "txWidestringWrapper.h"


#ifdef WIN32
#define KBHIT(key) ((GetAsyncKeyState(key) & 0x8001) == 0x8001)
#else
#define KBHIT(key) (0)
#endif

#ifdef OS_WINDOWS
#include <GL/gl.h>
#include <GL/glext.h>
#elif defined(GLES2)
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#ifndef GL_RGBA8
#define GL_RGBA8 0x8058
#endif
#define GL_COLOR_INDEX8_EXT  0x80E5
#elif defined(GLES3)
#include <GLES3/gl3.h>
#include <GLES3/gl3ext.h>
#define GL_COLOR_INDEX8_EXT  0x80E5
#elif defined(GLES3_1)
#include <GLES3/gl31.h>
#include <GLES3/gl3ext.h>
#define GL_COLOR_INDEX8_EXT  0x80E5
#elif defined(OS_MAC_OS_X)
#include <OpenGL/gl3.h>
#include <OpenGL/glext.h>
#ifndef GL_COLOR_INDEX8_EXT
#define GL_COLOR_INDEX8_EXT  0x80E5
#endif
#elif defined(OS_LINUX)
#include <GL/gl.h>
#include <GL/glext.h>
#elif defined(OS_ANDROID)
#include <GL/gl.h>
#include <GL/glext.h>
#endif // OS_WINDOWS

/* in-memory zlib texture compression */
#define GL_TEXFMT_GZ 0x80000000

#endif /* __INTERNAL_H__ */
