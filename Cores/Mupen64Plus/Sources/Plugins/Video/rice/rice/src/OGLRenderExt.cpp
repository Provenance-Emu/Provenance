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

#include "osal_opengl.h"

#include "OGLExtensions.h"
#include "OGLRender.h"
#include "RSP_Parser.h"
#include "RSP_S2DEX.h"
#include "Render.h"
#include "RenderBase.h"
#include "Video.h"
#include "m64p_types.h"
#include "osal_preproc.h"
#include "typedefs.h"

extern Matrix g_MtxReal;
extern uObjMtxReal gObjMtxReal;

//========================================================================

void OGLRender::DrawText(const char* str, RECT *rect)
{
    return;
}

void OGLRender::DrawSpriteR_Render()    // With Rotation
{
    glViewportWrapper(0, windowSetting.statusBarHeightToUse, windowSetting.uDisplayWidth, windowSetting.uDisplayHeight);

    GLboolean cullface = glIsEnabled(GL_CULL_FACE);
    glDisable(GL_CULL_FACE);

    GLfloat colour[] = {
            gRDP.fvPrimitiveColor[0], gRDP.fvPrimitiveColor[1], gRDP.fvPrimitiveColor[2], gRDP.fvPrimitiveColor[3],
            gRDP.fvPrimitiveColor[0], gRDP.fvPrimitiveColor[1], gRDP.fvPrimitiveColor[2], gRDP.fvPrimitiveColor[3],
            gRDP.fvPrimitiveColor[0], gRDP.fvPrimitiveColor[1], gRDP.fvPrimitiveColor[2], gRDP.fvPrimitiveColor[3],

            gRDP.fvPrimitiveColor[0], gRDP.fvPrimitiveColor[1], gRDP.fvPrimitiveColor[2], gRDP.fvPrimitiveColor[3],
            gRDP.fvPrimitiveColor[0], gRDP.fvPrimitiveColor[1], gRDP.fvPrimitiveColor[2], gRDP.fvPrimitiveColor[3],
            gRDP.fvPrimitiveColor[0], gRDP.fvPrimitiveColor[1], gRDP.fvPrimitiveColor[2], gRDP.fvPrimitiveColor[3],
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


    glVertexAttribPointer(VS_COLOR, 4, GL_FLOAT,GL_FALSE, 0, &colour );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,0,&vertices);
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, 0, &tex);
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, 0, &tex2);
    //OPENGL_CHECK_ERRORS;
    glDrawArrays(GL_TRIANGLES,0,6);
    //OPENGL_CHECK_ERRORS;

    //Restore old pointers
    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[0].u));
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[1].u));

    if( cullface ) glEnable(GL_CULL_FACE);
}


void OGLRender::DrawObjBGCopy(uObjBg &info)
{
    if( IsUsedAsDI(g_CI.dwAddr) )
    {
        DebugMessage(M64MSG_WARNING, "Unimplemented: write into Z buffer.  Was mostly commented out in Rice Video 6.1.0");
        return;
    }
    else
    {
        CRender::LoadObjBGCopy(info);
        CRender::DrawObjBGCopy(info);
    }
}


