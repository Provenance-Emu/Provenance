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

#include <string.h>

#include "Texture.h"
#include "TextureManager.h"
#include "typedefs.h"


//////////////////////////////////////////
// Constructors / Deconstructors

// Probably shouldn't need more than 4096 * 4096

CTexture::CTexture(uint32 dwWidth, uint32 dwHeight, TextureUsage usage) :
    m_dwWidth(dwWidth),
    m_dwHeight(dwHeight),
    m_dwCreatedTextureWidth(dwWidth),
    m_dwCreatedTextureHeight(dwHeight),
    m_fXScale(1.0f),
    m_fYScale(1.0f),
    m_bIsEnhancedTexture(false),
    m_Usage(usage),
        m_pTexture(NULL),
        m_dwTextureFmt(TEXTURE_FMT_A8R8G8B8)
{
    // fix me, do something here
}


CTexture::~CTexture(void)
{
}

TextureFmt CTexture::GetSurfaceFormat(void)
{
    if (m_pTexture == NULL)
        return TEXTURE_FMT_UNKNOWN;
    else
        return m_dwTextureFmt;
}

uint32 CTexture::GetPixelSize()
{
    if( m_dwTextureFmt == TEXTURE_FMT_A8R8G8B8 )
        return 4;
    else
        return 2;
}

void CTexture::RestoreAlphaChannel(void)
{
    DrawInfo di;

    if ( StartUpdate(&di) )
    {
        uint32 *pSrc = (uint32 *)di.lpSurface;
        int lPitch = di.lPitch;

        for (uint32 y = 0; y < m_dwHeight; y++)
        {
            uint32 * dwSrc = (uint32 *)((uint8 *)pSrc + y*lPitch);
            for (uint32 x = 0; x < m_dwWidth; x++)
            {
                uint32 dw = dwSrc[x];
                uint32 dwRed   = (uint8)((dw & 0x00FF0000)>>16);
                uint32 dwGreen = (uint8)((dw & 0x0000FF00)>>8 );
                uint32 dwBlue  = (uint8)((dw & 0x000000FF)    );
                uint32 dwAlpha = (dwRed+dwGreen+dwBlue)/3;
                dw &= 0x00FFFFFF;
                dw |= (dwAlpha<<24);

                /*
                uint32 dw = dwSrc[x];
                if( (dw&0x00FFFFFF) > 0 )
                    dw |= 0xFF000000;
                else
                    dw &= 0x00FFFFFF;
                    */
            }
        }
        EndUpdate(&di);
    }
    else
    {
        //TRACE0("Cannot lock texture");
    }
}

