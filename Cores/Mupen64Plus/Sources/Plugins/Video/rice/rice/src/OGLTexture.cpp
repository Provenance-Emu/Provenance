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

#include <stdlib.h>

#include "Config.h"
#include "Debugger.h"
#include "GraphicsContext.h"
#include "OGLDebug.h"
#include "OGLGraphicsContext.h"
#include "OGLTexture.h"
#include "TextureManager.h"
#include "osal_opengl.h"

COGLTexture::COGLTexture(uint32 dwWidth, uint32 dwHeight, TextureUsage usage) :
    CTexture(dwWidth,dwHeight,usage),
    m_glInternalFmt(GL_RGBA)
{
    // FIXME: If usage is AS_RENDER_TARGET, we need to create pbuffer instead of regular texture

    m_dwTextureFmt = TEXTURE_FMT_A8R8G8B8;  // Always use 32bit to load texture
    glGenTextures( 1, &m_dwTextureName );
    OPENGL_CHECK_ERRORS;

    // Make the width and height be the power of 2
    uint32 w;
    for (w = 1; w < dwWidth; w <<= 1);
    m_dwCreatedTextureWidth = w;
    for (w = 1; w < dwHeight; w <<= 1);
    m_dwCreatedTextureHeight = w;
    
    if (dwWidth*dwHeight > 256*256)
        TRACE4("Large texture: (%d x %d), created as (%d x %d)", 
            dwWidth, dwHeight,m_dwCreatedTextureWidth,m_dwCreatedTextureHeight);
    
    m_fYScale = (float)m_dwCreatedTextureHeight/(float)m_dwHeight;
    m_fXScale = (float)m_dwCreatedTextureWidth/(float)m_dwWidth;

    m_pTexture = malloc(m_dwCreatedTextureWidth * m_dwCreatedTextureHeight * GetPixelSize());

#ifndef USE_GLES
    switch( options.textureQuality )
    {
    case TXT_QUALITY_DEFAULT:
        if( options.colorQuality == TEXTURE_FMT_A4R4G4B4 ) 
            m_glInternalFmt = GL_RGBA4;
        break;
    case TXT_QUALITY_32BIT:
        break;
    case TXT_QUALITY_16BIT:
            m_glInternalFmt = GL_RGBA4;
        break;
    };
#endif
    
    m_glFmt = GL_RGBA;
    m_glType = GL_UNSIGNED_BYTE;

    LOG_TEXTURE(TRACE2("New texture: (%d, %d)", dwWidth, dwHeight));
    
    // We create the OGL texture here and will use glTexSubImage2D to increase performance.
    glBindTexture(GL_TEXTURE_2D, m_dwTextureName);
    OPENGL_CHECK_ERRORS;
    glTexImage2D(GL_TEXTURE_2D, 0, m_glInternalFmt, m_dwCreatedTextureWidth, m_dwCreatedTextureHeight, 0, m_glFmt, m_glType, NULL);
    OPENGL_CHECK_ERRORS;
}

COGLTexture::~COGLTexture()
{
    // FIXME: If usage is AS_RENDER_TARGET, we need to destroy the pbuffer

    glDeleteTextures(1, &m_dwTextureName);
    OPENGL_CHECK_ERRORS;
    free(m_pTexture);
    m_pTexture = NULL;
    m_dwWidth = 0;
    m_dwHeight = 0;
}

bool COGLTexture::StartUpdate(DrawInfo *di)
{
    if (m_pTexture == NULL)
        return false;

    di->dwHeight = (uint16)m_dwHeight;
    di->dwWidth = (uint16)m_dwWidth;
    di->dwCreatedHeight = m_dwCreatedTextureHeight;
    di->dwCreatedWidth = m_dwCreatedTextureWidth;
    di->lpSurface = m_pTexture;
    di->lPitch = GetPixelSize()*m_dwCreatedTextureWidth;

    return true;
}

void COGLTexture::EndUpdate(DrawInfo *di)
{
    glBindTexture(GL_TEXTURE_2D, m_dwTextureName);
    OPENGL_CHECK_ERRORS;

    // mipmap support
    if(options.mipmapping)
    {
        int maximumAnistropy = COGLGraphicsContext::Get()->getMaxAnisotropicFiltering(); //if getMaxAnisotropicFiltering() return more than 0, so aniso is supported and maxAnisotropicFiltering is set

        // Set Anisotropic filtering (mipmapping have to be activated, aniso filtering is not effective without)
        if( maximumAnistropy )
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, maximumAnistropy);
            OPENGL_CHECK_ERRORS;
        }

#ifndef USE_GLES
        // Tell to hardware to generate mipmap (himself) when glTexImage2D is called
        glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
        OPENGL_CHECK_ERRORS;
#endif
    }

    // Copy the image data from main memory to video card texture memory
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, m_dwCreatedTextureWidth, m_dwCreatedTextureHeight, m_glFmt, m_glType, m_pTexture);
    OPENGL_CHECK_ERRORS;

#ifdef USE_GLES
    if(options.mipmapping)
        glGenerateMipmap(GL_TEXTURE_2D);
        OPENGL_CHECK_ERRORS;
#endif
}
