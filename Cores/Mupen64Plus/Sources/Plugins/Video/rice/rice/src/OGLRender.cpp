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

#include <stddef.h>

#include "Combiner.h"
#include "CombinerDefs.h"
#include "Config.h"
#include "Debugger.h"
#include "GraphicsContext.h"
#include "RSP_Parser.h"
#include "Texture.h"
#include "Video.h"
#include "m64p_plugin.h"
#include "osal_opengl.h"

#include "OGLExtensions.h"
#include "OGLDebug.h"
#include "OGLGraphicsContext.h"
#include "OGLRender.h"
#include "OGLTexture.h"
#include "TextureManager.h"

// FIXME: Use OGL internal L/T and matrix stack
// FIXME: Use OGL lookupAt function
// FIXME: Use OGL DisplayList

UVFlagMap OGLXUVFlagMaps[] =
{
    {TEXTURE_UV_FLAG_WRAP, GL_REPEAT},
    {TEXTURE_UV_FLAG_MIRROR, GL_MIRRORED_REPEAT_ARB},
    {TEXTURE_UV_FLAG_CLAMP, GL_CLAMP},
};

//===================================================================
OGLRender::OGLRender()
{
}

OGLRender::~OGLRender()
{
}

bool OGLRender::InitDeviceObjects()
{
    // enable Z-buffer by default
    ZBufferEnable(true);
    return true;
}

bool OGLRender::ClearDeviceObjects()
{
    return true;
}

void OGLRender::Initialize(void)
{

    glViewportWrapper(0, windowSetting.statusBarHeightToUse, windowSetting.uDisplayWidth, windowSetting.uDisplayHeight);
    OPENGL_CHECK_ERRORS;
    
    OGLXUVFlagMaps[TEXTURE_UV_FLAG_MIRROR].realFlag = GL_MIRRORED_REPEAT;
    OGLXUVFlagMaps[TEXTURE_UV_FLAG_CLAMP].realFlag = GL_CLAMP_TO_EDGE;

    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    OPENGL_CHECK_ERRORS;

    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[0].u));
    OPENGL_CHECK_ERRORS;
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[1].u));
    OPENGL_CHECK_ERRORS;

    glVertexAttribPointer(VS_FOG,1,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][4]));
    OPENGL_CHECK_ERRORS;

    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    OPENGL_CHECK_ERRORS;

    // Initialize multitexture
    m_maxTexUnits = COGLGraphicsContext::Get()->getMaxTextureImageUnits();

    /* limited by size 8 arrays like m_maxTexUnits, mtex... */
    if (m_maxTexUnits > 8)
        m_maxTexUnits = 8;

    for( int i=0; i<8; i++ )
    {
        m_textureUnitMap[i] = -1;
        m_curBoundTex[i]    = -1;
    }
    m_textureUnitMap[0] = 0;    // T0 is usually using texture unit 0
    m_textureUnitMap[1] = 1;    // T1 is usually using texture unit 1

#ifndef USE_GLES
    if( COGLGraphicsContext::Get()->IsSupportDepthClampNV() )
    {
        glEnable(GL_DEPTH_CLAMP_NV);
        OPENGL_CHECK_ERRORS;
    }
#endif
}
//===================================================================
TextureFilterMap OglTexFilterMap[2]=
{
    {FILTER_POINT, GL_NEAREST},
    {FILTER_LINEAR, GL_LINEAR},
};

void OGLRender::ApplyTextureFilter()
{

    static uint32 minflag[8], magflag[8];
    static uint32 mtex[8];

    int iMinFilter, iMagFilter;

    //Compute iMinFilter and iMagFilter
    if(m_dwMinFilter == FILTER_LINEAR) //Texture will use filtering
    {
        iMagFilter = GL_LINEAR;

        //Texture filtering method user want
        switch(options.mipmapping)
        {
        case TEXTURE_BILINEAR_FILTER:
            iMinFilter = GL_LINEAR_MIPMAP_NEAREST;
            break;
        case TEXTURE_TRILINEAR_FILTER:
            iMinFilter = GL_LINEAR_MIPMAP_LINEAR;
            break;
        case TEXTURE_NO_FILTER:
            iMinFilter = GL_NEAREST_MIPMAP_NEAREST;
            break;
        case TEXTURE_NO_MIPMAP:
        default:
            //Bilinear without mipmap
            iMinFilter = GL_LINEAR;
        }
    }
    else    //dont use filtering, all is nearest
    {
        iMagFilter = GL_NEAREST;

        if(options.mipmapping)
            iMinFilter = GL_NEAREST_MIPMAP_NEAREST;
        else
            iMinFilter = GL_NEAREST;
    }

    for( int i=0; i<m_maxTexUnits; i++ )
    {
        if( mtex[i] != m_curBoundTex[i] )
        {
            mtex[i] = m_curBoundTex[i];
            glActiveTexture(GL_TEXTURE0+i);
            OPENGL_CHECK_ERRORS;
            minflag[i] = m_dwMinFilter;
            magflag[i] = m_dwMagFilter;
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, iMinFilter);
            OPENGL_CHECK_ERRORS;
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, iMagFilter);
            OPENGL_CHECK_ERRORS;
        }
        else
        {
            if( minflag[i] != (unsigned int)m_dwMinFilter )
            {
                minflag[i] = m_dwMinFilter;
                glActiveTexture(GL_TEXTURE0+i);
                OPENGL_CHECK_ERRORS;
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, iMinFilter);
                OPENGL_CHECK_ERRORS;
            }
            if( magflag[i] != (unsigned int)m_dwMagFilter )
            {
                magflag[i] = m_dwMagFilter;
                glActiveTexture(GL_TEXTURE0+i);
                OPENGL_CHECK_ERRORS;
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, iMagFilter);
                OPENGL_CHECK_ERRORS;
            }
        }
    }
}

void OGLRender::SetShadeMode(RenderShadeMode mode)
{
#ifndef USE_GLES
    if( mode == SHADE_SMOOTH )
        glShadeModel(GL_SMOOTH);
    else
        glShadeModel(GL_FLAT);
    OPENGL_CHECK_ERRORS;
#endif
}

void OGLRender::ZBufferEnable(BOOL bZBuffer)
{
    gRSP.bZBufferEnabled = bZBuffer;
    if( g_curRomInfo.bForceDepthBuffer )
        bZBuffer = TRUE;
    if( bZBuffer )
    {
        glDepthMask(GL_TRUE);
        OPENGL_CHECK_ERRORS;
        //glEnable(GL_DEPTH_TEST);
        glDepthFunc( GL_LEQUAL );
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        glDepthMask(GL_FALSE);
        OPENGL_CHECK_ERRORS;
        //glDisable(GL_DEPTH_TEST);
        glDepthFunc( GL_ALWAYS );
        OPENGL_CHECK_ERRORS;
    }
}

void OGLRender::ClearBuffer(bool cbuffer, bool zbuffer)
{
    uint32 flag=0;
    if( cbuffer )   flag |= GL_COLOR_BUFFER_BIT;
    if( zbuffer )   flag |= GL_DEPTH_BUFFER_BIT;
    float depth = ((gRDP.originalFillColor&0xFFFF)>>2)/(float)0x3FFF;
    glClearDepth(depth);
    OPENGL_CHECK_ERRORS;
    glClear(flag);
    OPENGL_CHECK_ERRORS;
}

void OGLRender::ClearZBuffer(float depth)
{
    uint32 flag=GL_DEPTH_BUFFER_BIT;
    glClearDepth(depth);
    OPENGL_CHECK_ERRORS;
    glClear(flag);
    OPENGL_CHECK_ERRORS;
}

void OGLRender::SetZCompare(BOOL bZCompare)
{
    if( g_curRomInfo.bForceDepthBuffer )
        bZCompare = TRUE;

    gRSP.bZBufferEnabled = bZCompare;
    if( bZCompare == TRUE )
    {
        //glEnable(GL_DEPTH_TEST);
        glDepthFunc( GL_LEQUAL );
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        //glDisable(GL_DEPTH_TEST);
        glDepthFunc( GL_ALWAYS );
        OPENGL_CHECK_ERRORS;
    }
}

void OGLRender::SetZUpdate(BOOL bZUpdate)
{
    if( g_curRomInfo.bForceDepthBuffer )
        bZUpdate = TRUE;

    if( bZUpdate )
    {
        //glEnable(GL_DEPTH_TEST);
        glDepthMask(GL_TRUE);
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        glDepthMask(GL_FALSE);
        OPENGL_CHECK_ERRORS;
    }
}

void OGLRender::ApplyZBias(int bias)
{
    float f1; // polygon offset factor
    float f2; // polygon offset units

    if (bias > 0)
    {
        if (options.bForcePolygonOffset)
        {
            f1 = options.polygonOffsetFactor;
            f2 = options.polygonOffsetUnits;
        }
        else
        {
            f1 = -3.0f;  // z offset = -3.0 * std::max(abs(dz/dx),abs(dz/dy)) per pixel delta z slope
            f2 = -3.0f;  // z offset += -3.0 * 1 bit
        }
        glEnable(GL_POLYGON_OFFSET_FILL);  // enable z offsets
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        f1 = 0.0f;
        f2 = 0.0f;
        glDisable(GL_POLYGON_OFFSET_FILL);  // disable z offsets
        OPENGL_CHECK_ERRORS;
    }
    glPolygonOffset(f1, f2);  // set bias functions
    OPENGL_CHECK_ERRORS;
}

void OGLRender::SetZBias(int bias)
{
#if defined(DEBUGGER)
    if( pauseAtNext == true )
      DebuggerAppendMsg("Set zbias = %d", bias);
#endif
    // set member variable and apply the setting in opengl
    m_dwZBias = bias;
    ApplyZBias(bias);
}

// TODO: Remove this functions as alpha clip is done in Color Combiner 
void OGLRender::SetAlphaRef(uint32 dwAlpha)
{
    if (m_dwAlpha != dwAlpha)
    {
        m_dwAlpha = dwAlpha;
#ifndef USE_GLES
        //glAlphaFunc(GL_GEQUAL, (float)dwAlpha);
        OPENGL_CHECK_ERRORS;
#endif
    }
}

// TODO: Remove this functions as alpha clip is done in Color Combiner 
void OGLRender::ForceAlphaRef(uint32 dwAlpha)
{
#ifndef USE_GLES
    //float ref = dwAlpha/255.0f;
    //glAlphaFunc(GL_GEQUAL, ref);
    OPENGL_CHECK_ERRORS;
#else
    m_dwAlpha = dwAlpha;
#endif
}

void OGLRender::SetFillMode(FillMode mode)
{
#ifndef USE_GLES
    if( mode == RICE_FILLMODE_WINFRAME )
    {
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        OPENGL_CHECK_ERRORS;
    }
#endif
}

void OGLRender::SetCullMode(bool bCullFront, bool bCullBack)
{
    CRender::SetCullMode(bCullFront, bCullBack);
    if( bCullFront && bCullBack )
    {
        glCullFace(GL_FRONT_AND_BACK);
        OPENGL_CHECK_ERRORS;
        glEnable(GL_CULL_FACE);
        OPENGL_CHECK_ERRORS;
    }
    else if( bCullFront )
    {
        glCullFace(GL_FRONT);
        OPENGL_CHECK_ERRORS;
        glEnable(GL_CULL_FACE);
        OPENGL_CHECK_ERRORS;
    }
    else if( bCullBack )
    {
        glCullFace(GL_BACK);
        OPENGL_CHECK_ERRORS;
        glEnable(GL_CULL_FACE);
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        glDisable(GL_CULL_FACE);
        OPENGL_CHECK_ERRORS;
    }
}

bool OGLRender::SetCurrentTexture(int tile, CTexture *handler,uint32 dwTileWidth, uint32 dwTileHeight, TxtrCacheEntry *pTextureEntry)
{
    RenderTexture &texture = g_textures[tile];
    texture.pTextureEntry = pTextureEntry;

    if( handler!= NULL  && texture.m_lpsTexturePtr != handler->GetTexture() )
    {
        texture.m_pCTexture = handler;
        texture.m_lpsTexturePtr = handler->GetTexture();

        texture.m_dwTileWidth = dwTileWidth;
        texture.m_dwTileHeight = dwTileHeight;

        if( handler->m_bIsEnhancedTexture )
        {
            texture.m_fTexWidth = (float)pTextureEntry->pTexture->m_dwCreatedTextureWidth;
            texture.m_fTexHeight = (float)pTextureEntry->pTexture->m_dwCreatedTextureHeight;
        }
        else
        {
            texture.m_fTexWidth = (float)handler->m_dwCreatedTextureWidth;
            texture.m_fTexHeight = (float)handler->m_dwCreatedTextureHeight;
        }
    }
    
    return true;
}

bool OGLRender::SetCurrentTexture(int tile, TxtrCacheEntry *pEntry)
{
    if (pEntry != NULL && pEntry->pTexture != NULL)
    {   
        SetCurrentTexture( tile, pEntry->pTexture,  pEntry->ti.WidthToCreate, pEntry->ti.HeightToCreate, pEntry);
        return true;
    }
    else
    {
        SetCurrentTexture( tile, NULL, 64, 64, NULL );
        return false;
    }
    return true;
}

void OGLRender::SetAddressUAllStages(uint32 dwTile, TextureUVFlag dwFlag)
{
    SetTextureUFlag(dwFlag, dwTile);
}

void OGLRender::SetAddressVAllStages(uint32 dwTile, TextureUVFlag dwFlag)
{
    SetTextureVFlag(dwFlag, dwTile);
}

void OGLRender::SetTexWrapS(int unitno,GLuint flag)
{
    static GLuint mflag[8];
    static GLuint mtex[8];
    if( m_curBoundTex[unitno] != mtex[unitno] || mflag[unitno] != flag )
    {
        mtex[unitno] = m_curBoundTex[0];
        mflag[unitno] = flag;
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, flag);
        OPENGL_CHECK_ERRORS;
    }
}
void OGLRender::SetTexWrapT(int unitno,GLuint flag)
{
    static GLuint mflag[8];
    static GLuint mtex[8];
    if( m_curBoundTex[unitno] != mtex[unitno] || mflag[unitno] != flag )
    {
        mtex[unitno] = m_curBoundTex[0];
        mflag[unitno] = flag;
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, flag);
        OPENGL_CHECK_ERRORS;
    }
}

void OGLRender::SetTextureUFlag(TextureUVFlag dwFlag, uint32 dwTile)
{

    TileUFlags[dwTile] = dwFlag;

    int tex;
    if( dwTile == gRSP.curTile )
        tex=0;
    else if( dwTile == ((gRSP.curTile+1)&7) )
        tex=1;
    else
    {
        if( dwTile == ((gRSP.curTile+2)&7) )
            tex=2;
        else if( dwTile == ((gRSP.curTile+3)&7) )
            tex=3;
        else
        {
            TRACE2("Incorrect tile number for OGL SetTextureUFlag: cur=%d, tile=%d", gRSP.curTile, dwTile);
            return;
        }
    }

    for( int textureNo=0; textureNo<8; textureNo++)
    {
        if( m_textureUnitMap[textureNo] == tex )
        {
            glActiveTexture(GL_TEXTURE0+textureNo);
            OPENGL_CHECK_ERRORS;
            COGLTexture* pTexture = g_textures[(gRSP.curTile+tex)&7].m_pCOGLTexture;
            if( pTexture ) 
            {
                EnableTexUnit(textureNo,TRUE);
                BindTexture(pTexture->m_dwTextureName, textureNo);
            }
            SetTexWrapS(textureNo, OGLXUVFlagMaps[dwFlag].realFlag);
        }
    }
}
void OGLRender::SetTextureVFlag(TextureUVFlag dwFlag, uint32 dwTile)
{

    TileVFlags[dwTile] = dwFlag;

    int tex;
    if( dwTile == gRSP.curTile )
        tex=0;
    else if( dwTile == ((gRSP.curTile+1)&7) )
        tex=1;
    else
    {
        if( dwTile == ((gRSP.curTile+2)&7) )
            tex=2;
        else if( dwTile == ((gRSP.curTile+3)&7) )
            tex=3;
        else
        {
            TRACE2("Incorrect tile number for OGL SetTextureVFlag: cur=%d, tile=%d", gRSP.curTile, dwTile);
            return;
        }
    }
    
    for( int textureNo=0; textureNo<8; textureNo++)
    {
        if( m_textureUnitMap[textureNo] == tex )
        {
            COGLTexture* pTexture = g_textures[(gRSP.curTile+tex)&7].m_pCOGLTexture;
            if( pTexture )
            {
                EnableTexUnit(textureNo,TRUE);
                BindTexture(pTexture->m_dwTextureName, textureNo);
            }
            SetTexWrapT(textureNo, OGLXUVFlagMaps[dwFlag].realFlag);
        }
    }
}

// Basic render drawing functions
bool OGLRender::RenderTexRect()
{
    glViewportWrapper(0, windowSetting.statusBarHeightToUse, windowSetting.uDisplayWidth, windowSetting.uDisplayHeight);
    OPENGL_CHECK_ERRORS;

    GLboolean cullface = glIsEnabled(GL_CULL_FACE);
    glDisable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;

    GLubyte colour[] = {
            g_texRectTVtx[3].r, g_texRectTVtx[3].g, g_texRectTVtx[3].b, g_texRectTVtx[3].a,
            g_texRectTVtx[2].r, g_texRectTVtx[2].g, g_texRectTVtx[2].b, g_texRectTVtx[2].a,
            g_texRectTVtx[1].r, g_texRectTVtx[1].g, g_texRectTVtx[1].b, g_texRectTVtx[1].a,
            g_texRectTVtx[0].r, g_texRectTVtx[0].g, g_texRectTVtx[0].b, g_texRectTVtx[0].a
    };

    GLfloat tex[] = {
            g_texRectTVtx[3].tcord[0].u,g_texRectTVtx[3].tcord[0].v,
            g_texRectTVtx[2].tcord[0].u,g_texRectTVtx[2].tcord[0].v,
            g_texRectTVtx[1].tcord[0].u,g_texRectTVtx[1].tcord[0].v,
            g_texRectTVtx[0].tcord[0].u,g_texRectTVtx[0].tcord[0].v
    };

    GLfloat tex2[] = {
            g_texRectTVtx[3].tcord[1].u,g_texRectTVtx[3].tcord[1].v,
            g_texRectTVtx[2].tcord[1].u,g_texRectTVtx[2].tcord[1].v,
            g_texRectTVtx[1].tcord[1].u,g_texRectTVtx[1].tcord[1].v,
            g_texRectTVtx[0].tcord[1].u,g_texRectTVtx[0].tcord[1].v
    };

    float w = windowSetting.uDisplayWidth / 2.0f, h = windowSetting.uDisplayHeight / 2.0f, inv = 1.0f;

    GLfloat vertices[] = {
            -inv + g_texRectTVtx[3].x / w, inv - g_texRectTVtx[3].y / h, g_texRectTVtx[3].z, 1, 
            -inv + g_texRectTVtx[2].x / w, inv - g_texRectTVtx[2].y / h, g_texRectTVtx[3].z, 1,
            -inv + g_texRectTVtx[1].x / w, inv - g_texRectTVtx[1].y / h, g_texRectTVtx[3].z, 1,
            -inv + g_texRectTVtx[0].x / w, inv - g_texRectTVtx[0].y / h, g_texRectTVtx[3].z, 1
    };

    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE, GL_TRUE, 0, &colour );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,0,&vertices);
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, 0, &tex);
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, 0, &tex2);
    OPENGL_CHECK_ERRORS;
    glDrawArrays(GL_TRIANGLE_FAN,0,4);
    OPENGL_CHECK_ERRORS;

    //Restore old pointers
    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[0].u));
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[1].u));

    if( cullface ) glEnable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;

    return true;
}

bool OGLRender::RenderFillRect(uint32 dwColor, float depth)
{
    uint8 a = (dwColor>>24);
    uint8 r = ((dwColor>>16)&0xFF);
    uint8 g = ((dwColor>>8)&0xFF);
    uint8 b = (dwColor&0xFF);
    glViewportWrapper(0, windowSetting.statusBarHeightToUse, windowSetting.uDisplayWidth, windowSetting.uDisplayHeight);
    OPENGL_CHECK_ERRORS;

    GLboolean cullface = glIsEnabled(GL_CULL_FACE);
    glDisable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;

    GLubyte colour[] = {
            r,g,b,a,
            r,g,b,a,
            r,g,b,a,
            r,g,b,a};

    float w = windowSetting.uDisplayWidth / 2.0f, h = windowSetting.uDisplayHeight / 2.0f, inv = 1.0f;

    GLfloat vertices[] = {
            -inv + m_fillRectVtx[0].x / w, inv - m_fillRectVtx[1].y / h, depth, 1,
            -inv + m_fillRectVtx[1].x / w, inv - m_fillRectVtx[1].y / h, depth, 1,
            -inv + m_fillRectVtx[1].x / w, inv - m_fillRectVtx[0].y / h, depth, 1,
            -inv + m_fillRectVtx[0].x / w, inv - m_fillRectVtx[0].y / h, depth, 1
    };

    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_FALSE, 0, &colour );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,0,&vertices);
    glDisableVertexAttribArray(VS_TEXCOORD0);
    glDisableVertexAttribArray(VS_TEXCOORD1);
    OPENGL_CHECK_ERRORS;
    glDrawArrays(GL_TRIANGLE_FAN,0,4);
    OPENGL_CHECK_ERRORS;

    //Restore old pointers
    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    glEnableVertexAttribArray(VS_TEXCOORD0);
    glEnableVertexAttribArray(VS_TEXCOORD1);

    if( cullface ) glEnable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;

    return true;
}

bool OGLRender::RenderLine3D()
{
#ifndef USE_GLES
    ApplyZBias(0);  // disable z offsets

    glBegin(GL_TRIANGLE_FAN);

    glColor4f(m_line3DVtx[1].r, m_line3DVtx[1].g, m_line3DVtx[1].b, m_line3DVtx[1].a);
    glVertex3f(m_line3DVector[3].x, m_line3DVector[3].y, -m_line3DVtx[1].z);
    glVertex3f(m_line3DVector[2].x, m_line3DVector[2].y, -m_line3DVtx[0].z);
    
    glColor4ub(m_line3DVtx[0].r, m_line3DVtx[0].g, m_line3DVtx[0].b, m_line3DVtx[0].a);
    glVertex3f(m_line3DVector[1].x, m_line3DVector[1].y, -m_line3DVtx[1].z);
    glVertex3f(m_line3DVector[0].x, m_line3DVector[0].y, -m_line3DVtx[0].z);

    glEnd();
    OPENGL_CHECK_ERRORS;

    ApplyZBias(m_dwZBias);  // set Z offset back to previous value
#endif

    return true;
}

extern FiddledVtx * g_pVtxBase;

// This is so weired that I can not do vertex transform by myself. I have to use
// OpenGL internal transform
bool OGLRender::RenderFlushTris()
{
    ApplyZBias(m_dwZBias);  // set the bias factors

    glViewportWrapper(windowSetting.vpLeftW, windowSetting.uDisplayHeight-windowSetting.vpTopW-windowSetting.vpHeightW+windowSetting.statusBarHeightToUse, windowSetting.vpWidthW, windowSetting.vpHeightW, false);
    OPENGL_CHECK_ERRORS;

    //if options.bOGLVertexClipper == FALSE )
    {
        glDrawElements( GL_TRIANGLES, gRSP.numVertices, GL_UNSIGNED_SHORT, g_vtxIndex );
        OPENGL_CHECK_ERRORS;
    }
/*  else
    {
        //ClipVertexesOpenGL();
        // Redo the index
        // Set the array
        glVertexPointer( 4, GL_FLOAT, sizeof(float)*5, &(g_vtxProjected5Clipped[0][0]) );
        glEnableClientState( GL_VERTEX_ARRAY );

        glActiveTexture( GL_TEXTURE0 );
        glTexCoordPointer( 2, GL_FLOAT, sizeof( TLITVERTEX ), &(g_clippedVtxBuffer[0].tcord[0].u) );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );

        glActiveTexture( GL_TEXTURE1 );
        glTexCoordPointer( 2, GL_FLOAT, sizeof( TLITVERTEX ), &(g_clippedVtxBuffer[0].tcord[1].u) );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );

        glDrawElements( GL_TRIANGLES, gRSP.numVertices, GL_UNSIGNED_INT, g_vtxIndex );

        // Reset the array
        glActiveTexture( GL_TEXTURE0 );
        glTexCoordPointer( 2, GL_FLOAT, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[0].u) );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );

        glActiveTexture( GL_TEXTURE1 );
        glTexCoordPointer( 2, GL_FLOAT, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[1].u) );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );

        glVertexPointer( 4, GL_FLOAT, sizeof(float)*5, &(g_vtxProjected5[0][0]) );
        glEnableClientState( GL_VERTEX_ARRAY );
    }
*/
    return true;
}

void OGLRender::DrawSimple2DTexture(float x0, float y0, float x1, float y1, float u0, float v0, float u1, float v1, COLOR dif, float z, float rhw)
{
    if( status.bVIOriginIsUpdated == true && currentRomOptions.screenUpdateSetting==SCREEN_UPDATE_AT_1ST_PRIMITIVE )
    {
        status.bVIOriginIsUpdated=false;
        CGraphicsContext::Get()->UpdateFrame();
        DEBUGGER_PAUSE_AND_DUMP_NO_UPDATE(NEXT_SET_CIMG,{DebuggerAppendMsg("Screen Update at 1st Simple2DTexture");});
    }

    StartDrawSimple2DTexture(x0, y0, x1, y1, u0, v0, u1, v1, dif, z, rhw);

    GLboolean cullface = glIsEnabled(GL_CULL_FACE);
    glDisable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;

    glViewportWrapper(0, windowSetting.statusBarHeightToUse, windowSetting.uDisplayWidth, windowSetting.uDisplayHeight);
    OPENGL_CHECK_ERRORS;

    GLubyte colour[] = {
        g_texRectTVtx[0].r, g_texRectTVtx[0].g, g_texRectTVtx[0].b, g_texRectTVtx[0].a,
        g_texRectTVtx[1].r, g_texRectTVtx[1].g, g_texRectTVtx[1].b, g_texRectTVtx[1].a,
        g_texRectTVtx[2].r, g_texRectTVtx[2].g, g_texRectTVtx[2].b, g_texRectTVtx[2].a,

        g_texRectTVtx[0].r, g_texRectTVtx[0].g, g_texRectTVtx[0].b, g_texRectTVtx[0].a,
        g_texRectTVtx[2].r, g_texRectTVtx[2].g, g_texRectTVtx[2].b, g_texRectTVtx[2].a,
        g_texRectTVtx[3].r, g_texRectTVtx[3].g, g_texRectTVtx[3].b, g_texRectTVtx[3].a,
    };

    GLfloat tex[] = {
            g_texRectTVtx[0].tcord[0].u,g_texRectTVtx[0].tcord[0].v,
            g_texRectTVtx[1].tcord[0].u,g_texRectTVtx[1].tcord[0].v,
            g_texRectTVtx[2].tcord[0].u,g_texRectTVtx[2].tcord[0].v,

            g_texRectTVtx[0].tcord[0].u,g_texRectTVtx[0].tcord[0].v,
            g_texRectTVtx[2].tcord[0].u,g_texRectTVtx[2].tcord[0].v,
            g_texRectTVtx[3].tcord[0].u,g_texRectTVtx[3].tcord[0].v,
    };

    GLfloat tex2[] = {
            g_texRectTVtx[0].tcord[1].u,g_texRectTVtx[0].tcord[1].v,
            g_texRectTVtx[1].tcord[1].u,g_texRectTVtx[1].tcord[1].v,
            g_texRectTVtx[2].tcord[1].u,g_texRectTVtx[2].tcord[1].v,

            g_texRectTVtx[0].tcord[1].u,g_texRectTVtx[0].tcord[1].v,
            g_texRectTVtx[2].tcord[1].u,g_texRectTVtx[2].tcord[1].v,
            g_texRectTVtx[3].tcord[1].u,g_texRectTVtx[3].tcord[1].v,
    };

     float w = windowSetting.uDisplayWidth / 2.0f, h = windowSetting.uDisplayHeight / 2.0f, inv = 1.0f;

    GLfloat vertices[] = {
            -inv + g_texRectTVtx[0].x/ w, inv - g_texRectTVtx[0].y/ h, -g_texRectTVtx[0].z,1,
            -inv + g_texRectTVtx[1].x/ w, inv - g_texRectTVtx[1].y/ h, -g_texRectTVtx[1].z,1,
            -inv + g_texRectTVtx[2].x/ w, inv - g_texRectTVtx[2].y/ h, -g_texRectTVtx[2].z,1,

            -inv + g_texRectTVtx[0].x/ w, inv - g_texRectTVtx[0].y/ h, -g_texRectTVtx[0].z,1,
            -inv + g_texRectTVtx[2].x/ w, inv - g_texRectTVtx[2].y/ h, -g_texRectTVtx[2].z,1,
            -inv + g_texRectTVtx[3].x/ w, inv - g_texRectTVtx[3].y/ h, -g_texRectTVtx[3].z,1
    };

    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_FALSE, 0, &colour );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,0,&vertices);
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, 0, &tex);
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, 0, &tex2);
    OPENGL_CHECK_ERRORS;
    glDrawArrays(GL_TRIANGLES,0,6);
    OPENGL_CHECK_ERRORS;

    //Restore old pointers
    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[0].u));
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[1].u));

    if( cullface ) glEnable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;
}

void OGLRender::DrawSimpleRect(int nX0, int nY0, int nX1, int nY1, uint32 dwColor, float depth, float rhw)
{
    StartDrawSimpleRect(nX0, nY0, nX1, nY1, dwColor, depth, rhw);

    GLboolean cullface = glIsEnabled(GL_CULL_FACE);
    glDisable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;

    uint8 a = (dwColor>>24);
    uint8 r = ((dwColor>>16)&0xFF);
    uint8 g = ((dwColor>>8)&0xFF);
    uint8 b = (dwColor&0xFF);
    
    GLubyte colour[] = {
            r,g,b,a,
            r,g,b,a,
            r,g,b,a,
            r,g,b,a};
    float w = windowSetting.uDisplayWidth / 2.0f, h = windowSetting.uDisplayHeight / 2.0f, inv = 1.0f;

    GLfloat vertices[] = {
            -inv + m_simpleRectVtx[1].x / w, inv - m_simpleRectVtx[0].y / h, -depth, 1,
            -inv + m_simpleRectVtx[1].x / w, inv - m_simpleRectVtx[1].y / h, -depth, 1,
            -inv + m_simpleRectVtx[0].x / w, inv - m_simpleRectVtx[1].y / h, -depth, 1,
            -inv + m_simpleRectVtx[0].x / w, inv - m_simpleRectVtx[0].y / h, -depth, 1
    };

    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_FALSE, 0, &colour );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,0,&vertices);
    glDisableVertexAttribArray(VS_TEXCOORD0);
    glDisableVertexAttribArray(VS_TEXCOORD1);
    OPENGL_CHECK_ERRORS;
    glDrawArrays(GL_TRIANGLE_FAN,0,4);
    OPENGL_CHECK_ERRORS;

    //Restore old pointers
    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    glEnableVertexAttribArray(VS_TEXCOORD0);
    glEnableVertexAttribArray(VS_TEXCOORD1);

    if( cullface ) glEnable(GL_CULL_FACE);
    OPENGL_CHECK_ERRORS;
}

void OGLRender::SetViewportRender()
{
    glViewportWrapper(windowSetting.vpLeftW, windowSetting.uDisplayHeight-windowSetting.vpTopW-windowSetting.vpHeightW+windowSetting.statusBarHeightToUse, windowSetting.vpWidthW, windowSetting.vpHeightW);
    OPENGL_CHECK_ERRORS;
}

void OGLRender::RenderReset()
{
    CRender::RenderReset();
}

// TODO: Remove this functions as it's now handled by the Color Combiner
void OGLRender::SetAlphaTestEnable(BOOL bAlphaTestEnable)
{
  /*#ifdef DEBUGGER
    if( bAlphaTestEnable && debuggerEnableAlphaTest )
  #else
    if( bAlphaTestEnable )
  #endif
        glEnable(GL_ALPHA_TEST);
    else
        glDisable(GL_ALPHA_TEST);
    OPENGL_CHECK_ERRORS;*/
}

void OGLRender::BindTexture(GLuint texture, int unitno)
{
    if( unitno < m_maxTexUnits )
    {
        if( m_curBoundTex[unitno] != texture )
        {
            glActiveTexture(GL_TEXTURE0+unitno);
            OPENGL_CHECK_ERRORS;
            glBindTexture(GL_TEXTURE_2D,texture);
            OPENGL_CHECK_ERRORS;
            m_curBoundTex[unitno] = texture;
        }
    }
}

void OGLRender::DisBindTexture(GLuint texture, int unitno)
{
    glActiveTexture(GL_TEXTURE0+unitno);
    OPENGL_CHECK_ERRORS;
    glBindTexture(GL_TEXTURE_2D, 0);    //Not to bind any texture
    OPENGL_CHECK_ERRORS;
    m_curBoundTex[unitno] = 0;
}

// This function was intent to activate of disable texture of given OpenGL
// texture unit. This has no sense anymore as the combiner use GLSL to use a
// texture or not.
// Technically, we don't need this function anymore but a side effect of it was
// it activate a given texture unit and this side effect as some important
// scope at some places (in SetTextureUFlag for example) so we let it for now.
void OGLRender::EnableTexUnit(int unitno, BOOL flag)
{
    glActiveTexture(GL_TEXTURE0+unitno);
    OPENGL_CHECK_ERRORS;
}

void OGLRender::UpdateScissor()
{
    if( options.bEnableHacks && g_CI.dwWidth == 0x200 && gRDP.scissor.right == 0x200 && g_CI.dwWidth>(*g_GraphicsInfo.VI_WIDTH_REG & 0xFFF) )
    {
        // Hack for RE2
        uint32 width = *g_GraphicsInfo.VI_WIDTH_REG & 0xFFF;
        uint32 height = (gRDP.scissor.right*gRDP.scissor.bottom)/width;
        glEnable(GL_SCISSOR_TEST);
        OPENGL_CHECK_ERRORS;
        glScissor(0, int(height*windowSetting.fMultY+windowSetting.statusBarHeightToUse),
            int(width*windowSetting.fMultX), int(height*windowSetting.fMultY) );
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        UpdateScissorWithClipRatio();
    }
}

void OGLRender::ApplyRDPScissor(bool force)
{
    if( !force && status.curScissor == RDP_SCISSOR )    return;

    if( options.bEnableHacks && g_CI.dwWidth == 0x200 && gRDP.scissor.right == 0x200 && g_CI.dwWidth>(*g_GraphicsInfo.VI_WIDTH_REG & 0xFFF) )
    {
        // Hack for RE2
        uint32 width = *g_GraphicsInfo.VI_WIDTH_REG & 0xFFF;
        uint32 height = (gRDP.scissor.right*gRDP.scissor.bottom)/width;
        glEnable(GL_SCISSOR_TEST);
        OPENGL_CHECK_ERRORS;
        glScissor(0, int(height*windowSetting.fMultY+windowSetting.statusBarHeightToUse),
            int(width*windowSetting.fMultX), int(height*windowSetting.fMultY) );
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        glScissor(int(gRDP.scissor.left*windowSetting.fMultX), int((windowSetting.uViHeight-gRDP.scissor.bottom)*windowSetting.fMultY+windowSetting.statusBarHeightToUse),
            int((gRDP.scissor.right-gRDP.scissor.left)*windowSetting.fMultX), int((gRDP.scissor.bottom-gRDP.scissor.top)*windowSetting.fMultY ));
        OPENGL_CHECK_ERRORS;
    }

    status.curScissor = RDP_SCISSOR;
}

void OGLRender::ApplyScissorWithClipRatio(bool force)
{
    if( !force && status.curScissor == RSP_SCISSOR )    return;

    glEnable(GL_SCISSOR_TEST);
    OPENGL_CHECK_ERRORS;
    glScissor(windowSetting.clipping.left, int((windowSetting.uViHeight-gRSP.real_clip_scissor_bottom)*windowSetting.fMultY)+windowSetting.statusBarHeightToUse,
        windowSetting.clipping.width, windowSetting.clipping.height);
    OPENGL_CHECK_ERRORS;

    status.curScissor = RSP_SCISSOR;
}

void OGLRender::SetFogColor(uint32 r, uint32 g, uint32 b, uint32 a)
{
    gRDP.fogColor = COLOR_RGBA(r, g, b, a); 
    gRDP.fvFogColor[0] = r/255.0f;      //r
    gRDP.fvFogColor[1] = g/255.0f;      //g
    gRDP.fvFogColor[2] = b/255.0f;      //b
    gRDP.fvFogColor[3] = a/255.0f;      //a
}

void OGLRender::EndRendering(void)
{
#ifndef USE_GLES
    glFlush();
    OPENGL_CHECK_ERRORS;
#endif
    if( CRender::gRenderReferenceCount > 0 ) 
        CRender::gRenderReferenceCount--;
}

// TODO: Seems to be useless now.
void OGLRender::glViewportWrapper(GLint x, GLint y, GLsizei width, GLsizei height, bool flag)
{
    
    static GLint mx=0,my=0;
    static GLsizei m_width=0, m_height=0;
    static bool mflag=true;

    if( x!=mx || y!=my || width!=m_width || height!=m_height || mflag!=flag)
    {
        mx=x;
        my=y;
        m_width=width;
        m_height=height;
        mflag=flag;
        glLoadIdentity();
        OPENGL_CHECK_ERRORS;
        glViewport(x,y,width,height);
        OPENGL_CHECK_ERRORS;
    }
}

