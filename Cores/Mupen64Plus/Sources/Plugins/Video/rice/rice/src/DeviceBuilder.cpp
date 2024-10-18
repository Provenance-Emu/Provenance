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

#include "Blender.h"
#include "Combiner.h"
#include "Debugger.h"
#include "DeviceBuilder.h"
#include "FrameBuffer.h"
#include "GraphicsContext.h"
#include "OGLCombiner.h"
#include "OGLDebug.h"
#include "OGLRender.h"
#include "OGLGraphicsContext.h"
#include "OGLTexture.h"
#include "OGLExtensions.h"

//========================================================================
CDeviceBuilder*     CDeviceBuilder::m_pInstance         = NULL;
SupportedDeviceType CDeviceBuilder::m_deviceType        = OGL_DEVICE;
SupportedDeviceType CDeviceBuilder::m_deviceGeneralType = OGL_DEVICE;

CDeviceBuilder* CDeviceBuilder::GetBuilder(void)
{
    if( m_pInstance == NULL )
        CreateBuilder(m_deviceType);
    
    return m_pInstance;
}

void CDeviceBuilder::SelectDeviceType(SupportedDeviceType type)
{
    if( type != m_deviceType && m_pInstance != NULL )
    {
        DeleteBuilder();
    }

    CDeviceBuilder::m_deviceType = type;
    switch(type)
    {
    case OGL_DEVICE:
    case OGL_FRAGMENT_PROGRAM:
        CDeviceBuilder::m_deviceGeneralType = OGL_DEVICE;
        break;
    default:
       break;
    }
}

SupportedDeviceType CDeviceBuilder::GetDeviceType(void)
{
    return CDeviceBuilder::m_deviceType;
}

SupportedDeviceType CDeviceBuilder::GetGeneralDeviceType(void)
{
    return CDeviceBuilder::m_deviceGeneralType;
}

CDeviceBuilder* CDeviceBuilder::CreateBuilder(SupportedDeviceType type)
{
    if( m_pInstance == NULL )
    {
        switch( type )
        {
        case    OGL_DEVICE:
        case OGL_FRAGMENT_PROGRAM:
            m_pInstance = new OGLDeviceBuilder();
            break;
        default:
            DebugMessage(M64MSG_ERROR, "CreateBuilder: unknown OGL device type");
            exit(1);
        }

        SAFE_CHECK(m_pInstance);
    }

    return m_pInstance;
}

void CDeviceBuilder::DeleteBuilder(void)
{
    delete m_pInstance;
    m_pInstance = NULL;
}

CDeviceBuilder::CDeviceBuilder() :
    m_pRender(NULL),
    m_pColorCombiner(NULL),
    m_pAlphaBlender(NULL)
{
}

CDeviceBuilder::~CDeviceBuilder()
{
    DeleteGraphicsContext();
    DeleteRender();
    DeleteColorCombiner();
    DeleteAlphaBlender();
}

void CDeviceBuilder::DeleteGraphicsContext(void)
{
    if( !CGraphicsContext::IsNull() )
    {
        delete CGraphicsContext::m_pGraphicsContext;
        CGraphicsContext::m_pGraphicsContext = NULL;
    }

    SAFE_DELETE(g_pFrameBufferManager);
}

void CDeviceBuilder::DeleteRender(void)
{
    if( m_pRender != NULL )
    {
        delete m_pRender;
        CRender::g_pRender = m_pRender = NULL;
        CRender::gRenderReferenceCount = 0;
    }
}

void CDeviceBuilder::DeleteColorCombiner(void)
{
    if( m_pColorCombiner != NULL )
    {
        delete m_pColorCombiner;
        m_pColorCombiner = NULL;
    }
}

void CDeviceBuilder::DeleteAlphaBlender(void)
{
    if( m_pAlphaBlender != NULL )
    {
        delete m_pAlphaBlender;
        m_pAlphaBlender = NULL;
    }
}


//========================================================================

CGraphicsContext * OGLDeviceBuilder::CreateGraphicsContext(void)
{
    if( CGraphicsContext::IsNull() )
    {
        CGraphicsContext::m_pGraphicsContext = new COGLGraphicsContext();
        SAFE_CHECK(CGraphicsContext::m_pGraphicsContext);
    }

    g_pFrameBufferManager = new FrameBufferManager;

    return CGraphicsContext::m_pGraphicsContext;
}

CRender * OGLDeviceBuilder::CreateRender(void)
{
    if( m_pRender == NULL )
    {
        if( CGraphicsContext::IsNull() || !CGraphicsContext::Get()->IsReady() )
        {
            DebugMessage(M64MSG_ERROR, "Can not create ColorCombiner before creating and initializing GraphicsContext");
            m_pRender = NULL;
            SAFE_CHECK(m_pRender);
        }

        m_pRender = new OGLRender();

        SAFE_CHECK(m_pRender);
        CRender::g_pRender = m_pRender;
    }

    return m_pRender;
}

CTexture * OGLDeviceBuilder::CreateTexture(uint32 dwWidth, uint32 dwHeight, TextureUsage usage)
{
    COGLTexture *txtr = new COGLTexture(dwWidth, dwHeight, usage);
    if( txtr->m_pTexture == NULL )
    {
        delete txtr;
        TRACE0("Cannot create new texture, out of video memory");
        return NULL;
    }
    else
        return txtr;
}

CColorCombiner * OGLDeviceBuilder::CreateColorCombiner(CRender *pRender)
{
    bool bColorCombinerFound = false;

    if( m_pColorCombiner == NULL )
    {
        if(    CGraphicsContext::Get() == NULL
            && CGraphicsContext::Get()->IsReady() )
        {
            DebugMessage(M64MSG_ERROR, "Can not create ColorCombiner before creating and initializing GraphicsContext");
        }
        else
        {
            m_deviceType = (SupportedDeviceType)options.OpenglRenderSetting;

            if( m_deviceType == OGL_DEVICE )    // Best fit
            {
                m_pColorCombiner = new COGLColorCombiner(pRender);
                bColorCombinerFound = true;
                DebugMessage(M64MSG_VERBOSE, "OpenGL Combiner: 2.1");
            }
            else
            {
                switch(m_deviceType)
                {
                case OGL_FRAGMENT_PROGRAM:
                    m_pColorCombiner = new COGLColorCombiner(pRender);
                    bColorCombinerFound = true;
                    DebugMessage(M64MSG_VERBOSE, "OpenGL Combiner: 2.1");
                    break;
                 default:
                    break;
                }
            }
        }

        if (!bColorCombinerFound)
        {
            DebugMessage(M64MSG_ERROR, "OpenGL Combiner: Can't find a valid OpenGL Combiner");
            exit(1);
        }

        SAFE_CHECK(m_pColorCombiner);
    }

    return m_pColorCombiner;
}

CBlender * OGLDeviceBuilder::CreateAlphaBlender(CRender *pRender)
{
    if( m_pAlphaBlender == NULL )
    {
        m_pAlphaBlender = new COGLBlender(pRender);
        SAFE_CHECK(m_pAlphaBlender);
    }

    return m_pAlphaBlender;
}

