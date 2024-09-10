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

#ifndef _OGL_TEXTURE_H_
#define _OGL_TEXTURE_H_

#include "Texture.h"
#include "TextureManager.h"
#include "osal_opengl.h"
#include "typedefs.h"

class COGLTexture : public CTexture
{
    friend class COGLRenderTexture;
public:
    ~COGLTexture();

    bool StartUpdate(DrawInfo *di);
    void EndUpdate(DrawInfo *di);

    GLuint m_dwTextureName;

protected:
    friend class OGLDeviceBuilder;
    COGLTexture(uint32 dwWidth, uint32 dwHeight, TextureUsage usage = AS_NORMAL);

private:
    /* Note for the futur, the implmentation dependant values can be
     * retrieved using (OGL 4.3 et OGLES 3):
     * GLenum format, type;
     * glGetInternalformativ(GL_TEXTURE_2D, GL_RGBA, GL_TEXTURE_IMAGE_FORMAT, 1, &format);
     * glGetInternalformativ(GL_TEXTURE_2D, GL_RGBA, GL_TEXTURE_IMAGE_TYPE, 1, &type); */
    GLuint m_glInternalFmt;
    GLuint m_glFmt;
    GLuint m_glType;
};


#endif



