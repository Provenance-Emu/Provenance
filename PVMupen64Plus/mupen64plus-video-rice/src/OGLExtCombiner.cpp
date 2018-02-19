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
#include <algorithm>

#include "CombinerDefs.h"
#include "Debugger.h"
#include "DecodedMux.h"
#include "GeneralCombiner.h"
#include "GraphicsContext.h"
#include "OGLRender.h"
#include "RSP_Parser.h"
#include "RenderBase.h"
#include "osal_opengl.h"
#include "osal_preproc.h"

#ifndef USE_GLES
#include "OGLExtensions.h"
#endif
#include "OGLDebug.h"
#include "OGLDecodedMux.h"
#include "OGLExtCombiner.h"
#include "OGLExtRender.h"
#include "OGLGraphicsContext.h"
#include "OGLTexture.h"

class CRender;

#define GL_MODULATE_ADD_ATI        0x8744
#define GL_MODULATE_SUBTRACT_ATI   0x8746

//========================================================================
COGLColorCombiner4::COGLColorCombiner4(CRender *pRender)
        :COGLColorCombiner(pRender), m_maxTexUnits(0), m_lastIndex(-1),
        m_dwLastMux0(0), m_dwLastMux1(0)
{
    m_bSupportModAdd_ATI = false;
    m_bSupportModSub_ATI = false;
    delete m_pDecodedMux;
    m_pDecodedMux = new COGLExtDecodedMux;
}

//////////////////////////////////////////////////////////////////////////
bool COGLColorCombiner4::Initialize(void)
{
    m_bSupportModAdd_ATI = false;
    m_bSupportModSub_ATI = false;
    m_maxTexUnits = 1;

#ifndef USE_GLES
    if( COGLColorCombiner::Initialize() )
    {
        COGLGraphicsContext *pcontext = (COGLGraphicsContext *)(CGraphicsContext::g_pGraphicsContext);

        glGetIntegerv(GL_MAX_TEXTURE_UNITS,&m_maxTexUnits);
        OPENGL_CHECK_ERRORS;
        if( m_maxTexUnits > 8 ) m_maxTexUnits = 8;

        TRACE0("Starting Ogl 1.4 multitexture combiner" );
        TRACE1("m_maxTexUnits = %d", m_maxTexUnits);
        if( pcontext->IsExtensionSupported("ATI_texture_env_combine3") )
        {
            m_bSupportModAdd_ATI = true;
            m_bSupportModSub_ATI = true;
        }
        m_supportedStages = m_maxTexUnits;
        return true;
    }
    return false;

#else
    return true;
#endif
}

//========================================================================
void COGLColorCombiner4::InitCombinerCycleFill(void)
{
    for( int i=0; i<m_supportedStages; i++ )
    {
        pglActiveTexture(GL_TEXTURE0+i);
        OPENGL_CHECK_ERRORS;
        m_pOGLRender->EnableTexUnit(i,FALSE);
    }

    //pglActiveTexture(GL_TEXTURE0);
    //m_pOGLRender->EnableTexUnit(0,FALSE);
    //pglActiveTexture(GL_TEXTURE1);
    //m_pOGLRender->EnableTexUnit(1,FALSE);
}

//////////////////////////////////////////////////////////////////////////
void COGLColorCombiner4::InitCombinerCycle12(void)
{

#ifdef DEBUGGER
    if( debuggerDropCombiners )
    {
        UpdateCombiner(m_pDecodedMux->m_dwMux0,m_pDecodedMux->m_dwMux1);
        m_vCompiledSettings.clear();
        m_dwLastMux0 = m_dwLastMux1 = 0;
        debuggerDropCombiners = false;
    }
#endif

    m_pOGLRender->EnableMultiTexture();

    bool combinerIsChanged = false;

    if( m_pDecodedMux->m_dwMux0 != m_dwLastMux0 || m_pDecodedMux->m_dwMux1 != m_dwLastMux1 || m_lastIndex < 0 )
    {
        combinerIsChanged = true;
        m_lastIndex = FindCompiledMux();
        if( m_lastIndex < 0 )       // Can not found
        {
            m_lastIndex = ParseDecodedMux();
#ifdef DEBUGGER
            DisplaySimpleMuxString();
#endif
        }

        m_dwLastMux0 = m_pDecodedMux->m_dwMux0;
        m_dwLastMux1 = m_pDecodedMux->m_dwMux1;
    }
    

    if( m_bCycleChanged || combinerIsChanged || gRDP.texturesAreReloaded || gRDP.colorsAreReloaded )
    {
        if( m_bCycleChanged || combinerIsChanged )
        {
            GenerateCombinerSettingConstants(m_lastIndex);
            GenerateCombinerSetting(m_lastIndex);
        }
        else if( gRDP.colorsAreReloaded )
        {
            GenerateCombinerSettingConstants(m_lastIndex);
        }

        m_pOGLRender->SetAllTexelRepeatFlag();

        gRDP.colorsAreReloaded = false;
        gRDP.texturesAreReloaded = false;
    }
    else
    {
        m_pOGLRender->SetAllTexelRepeatFlag();
    }
}

//////////////////////////////////////////////////////////////////////////
int COGLColorCombiner4::ParseDecodedMux()
{
#define nextUnit()  {unitNo++;}
#ifndef USE_GLES
    if( m_maxTexUnits<3) 
        return  ParseDecodedMux2Units();

    OGLExtCombinerSaveType res;
    for( int k=0; k<8; k++ )
        res.units[k].tex = -1;
    
    COGLDecodedMux &mux = *(COGLDecodedMux*)m_pDecodedMux;

    int unitNos[2];
    for( int rgbalpha = 0; rgbalpha<2; rgbalpha++ )
    {
        unitNos[rgbalpha] = 0;
        for( int cycle = 0; cycle<2; cycle++ )
        {
            int &unitNo = unitNos[rgbalpha];
            OGLExtCombinerType &unit = res.units[unitNo];
            OGLExt1CombType &comb = unit.Combs[rgbalpha];
            CombinerFormatType type = m_pDecodedMux->splitType[cycle*2+rgbalpha];
            N64CombinerType &m = m_pDecodedMux->m_n64Combiners[cycle*2+rgbalpha];
            comb.arg0 = comb.arg1 = comb.arg2 = CM_IGNORE_BYTE;

            switch( type )
            {
            case CM_FMT_TYPE_NOT_USED:
                comb.arg0 = MUX_COMBINED;
                unit.ops[rgbalpha] = GL_REPLACE;
                nextUnit();
                break;
            case CM_FMT_TYPE_D:                 // = A
                comb.arg0 = m.d;
                unit.ops[rgbalpha] = GL_REPLACE;
                nextUnit();
                break;
            case CM_FMT_TYPE_A_ADD_D:           // = A+D
                comb.arg0 = m.a;
                comb.arg1 = m.d;
                unit.ops[rgbalpha] = GL_ADD;
                nextUnit();
                break;
            case CM_FMT_TYPE_A_SUB_B:           // = A-B
                comb.arg0 = m.a;
                comb.arg1 = m.b;
                unit.ops[rgbalpha] = GL_SUBTRACT;
                nextUnit();
                break;
            case CM_FMT_TYPE_A_MOD_C:           // = A*C
                comb.arg0 = m.a;
                comb.arg1 = m.c;
                unit.ops[rgbalpha] = GL_MODULATE;
                nextUnit();
                break;
            case CM_FMT_TYPE_A_MOD_C_ADD_D:     // = A*C+D
                if( m_bSupportModAdd_ATI )
                {
                    comb.arg0 = m.a;
                    comb.arg2 = m.c;
                    comb.arg1 = m.d;
                    unit.ops[rgbalpha] = GL_MODULATE_ADD_ATI;
                    nextUnit();
                }
                else
                {
                    if( unitNo < m_maxTexUnits-1 )
                    {
                        comb.arg0 = m.a;
                        comb.arg1 = m.c;
                        unit.ops[rgbalpha] = GL_MODULATE;
                        nextUnit();
                        res.units[unitNo].Combs[rgbalpha].arg0 = MUX_COMBINED;
                        res.units[unitNo].Combs[rgbalpha].arg1 = m.d;
                        res.units[unitNo].ops[rgbalpha] = GL_ADD;
                        nextUnit();
                    }
                    else
                    {
                        comb.arg0 = m.a;
                        comb.arg1 = m.c;
                        comb.arg2 = m.d;
                        unit.ops[rgbalpha] = GL_INTERPOLATE;
                        nextUnit();
                    }
                }
                break;
            case CM_FMT_TYPE_A_LERP_B_C:        // = (A-B)*C+B
                comb.arg0 = m.a;
                comb.arg1 = m.b;
                comb.arg2 = m.c;
                unit.ops[rgbalpha] = GL_INTERPOLATE;
                nextUnit();
                break;
            case CM_FMT_TYPE_A_SUB_B_ADD_D:     // = A-B+D
                if( unitNo < m_maxTexUnits-1 )
                {
                    comb.arg0 = m.a;
                    comb.arg1 = m.b;
                    unit.ops[rgbalpha] = GL_SUBTRACT;
                    nextUnit();
                    res.units[unitNo].Combs[rgbalpha].arg0 = MUX_COMBINED;
                    res.units[unitNo].Combs[rgbalpha].arg1 = m.d;
                    res.units[unitNo].ops[rgbalpha] = GL_ADD;
                    nextUnit();
                }
                else
                {
                    comb.arg0 = m.a;
                    comb.arg1 = m.c;
                    comb.arg2 = m.d;
                    unit.ops[rgbalpha] = GL_INTERPOLATE;
                    nextUnit();
                }
                break;
            case CM_FMT_TYPE_A_SUB_B_MOD_C:     // = (A-B)*C
                if( unitNo < m_maxTexUnits-1 )
                {
                    comb.arg0 = m.a;
                    comb.arg1 = m.b;
                    unit.ops[rgbalpha] = GL_SUBTRACT;
                    nextUnit();
                    res.units[unitNo].Combs[rgbalpha].arg0 = MUX_COMBINED;
                    res.units[unitNo].Combs[rgbalpha].arg1 = m.c;
                    res.units[unitNo].ops[rgbalpha] = GL_MODULATE;
                    nextUnit();
                }
                else
                {
                    comb.arg0 = m.a;
                    comb.arg1 = m.c;
                    comb.arg2 = m.d;
                    unit.ops[rgbalpha] = GL_INTERPOLATE;
                    nextUnit();
                }
                break;
            case CM_FMT_TYPE_A_B_C_D:           // = (A-B)*C+D
            default:
                if( unitNo < m_maxTexUnits-1 )
                {
                    comb.arg0 = m.a;
                    comb.arg1 = m.b;
                    unit.ops[rgbalpha] = GL_SUBTRACT;
                    nextUnit();
                    if( m_bSupportModAdd_ATI )
                    {
                        res.units[unitNo].Combs[rgbalpha].arg0 = MUX_COMBINED;
                        res.units[unitNo].Combs[rgbalpha].arg2 = m.c;
                        res.units[unitNo].Combs[rgbalpha].arg1 = m.d;
                        res.units[unitNo].ops[rgbalpha] = GL_MODULATE_ADD_ATI;
                        nextUnit();
                    }
                    else
                    {
                        res.units[unitNo].Combs[rgbalpha].arg0 = m.a;
                        res.units[unitNo].Combs[rgbalpha].arg1 = m.b;
                        res.units[unitNo].Combs[rgbalpha].arg2 = m.c;
                        res.units[unitNo].ops[rgbalpha] = GL_INTERPOLATE;
                        nextUnit();
                    }
                }
                else
                {
                    comb.arg0 = m.a;
                    comb.arg1 = m.c;
                    comb.arg2 = m.d;
                    unit.ops[rgbalpha] = GL_INTERPOLATE;
                    nextUnit();
                }
                break;
            }
        }
    }
        
    res.numOfUnits = std::min(m_maxTexUnits, std::max(unitNos[0],unitNos[1]));

    if( unitNos[0]>m_maxTexUnits || unitNos[1]>m_maxTexUnits ) 
    {
        TRACE0("Unit overflows");
    }

    for( int j=0; j<2; j++ )
    {
        if( unitNos[j]<res.numOfUnits )
        {
            for( int i=unitNos[j]; i<res.numOfUnits; i++ )
            {
                res.units[i].Combs[j].arg0 = MUX_COMBINED;
                res.units[i].ops[j] = GL_REPLACE;
            }
        }
    }

    res.units[0].tex = 0;
    res.units[1].tex = 1;

    res.primIsUsed = mux.isUsed(MUX_PRIM);
    res.envIsUsed = mux.isUsed(MUX_ENV);
    res.lodFracIsUsed = mux.isUsed(MUX_LODFRAC) || mux.isUsed(MUX_PRIMLODFRAC);

    return SaveParsedResult(res);

#else
    return 0;
#endif
}

int COGLColorCombiner4::ParseDecodedMux2Units()
{
    OGLExtCombinerSaveType res;
    for( int k=0; k<8; k++ )
        res.units[k].tex = -1;

    res.numOfUnits = 2;

    for( int i=0; i<res.numOfUnits*2; i++ ) // Set combiner for each texture unit
    {
        // For each texture unit, set both RGB and Alpha channel
        // Keep in mind that the m_pDecodeMux has been reformated and simplified very well

        OGLExtCombinerType &unit = res.units[i/2];
        OGLExt1CombType &comb = unit.Combs[i%2];

        CombinerFormatType type = m_pDecodedMux->splitType[i];
        N64CombinerType &m = m_pDecodedMux->m_n64Combiners[i];

        comb.arg0 = comb.arg1 = comb.arg2 = MUX_0;

        switch( type )
        {
        case CM_FMT_TYPE_NOT_USED:
            comb.arg0 = MUX_COMBINED;
            unit.ops[i%2] = GL_REPLACE;
            break;
        case CM_FMT_TYPE_D:                 // = A
            comb.arg0 = m.d;
            unit.ops[i%2] = GL_REPLACE;
            break;
#ifndef USE_GLES
        case CM_FMT_TYPE_A_ADD_D:           // = A+D
            comb.arg0 = m.a;
            comb.arg1 = m.d;
            unit.ops[i%2] = GL_ADD;
            break;
        case CM_FMT_TYPE_A_SUB_B:           // = A-B
            comb.arg0 = m.a;
            comb.arg1 = m.b;
            unit.ops[i%2] = GL_SUBTRACT;
            break;
        case CM_FMT_TYPE_A_MOD_C:           // = A*C
            comb.arg0 = m.a;
            comb.arg1 = m.c;
            unit.ops[i%2] = GL_MODULATE;
            break;
        case CM_FMT_TYPE_A_MOD_C_ADD_D:     // = A*C+D
            comb.arg0 = m.a;
            comb.arg1 = m.c;
            comb.arg2 = m.d;
            unit.ops[i%2] = GL_INTERPOLATE;
            break;
        case CM_FMT_TYPE_A_LERP_B_C:        // = (A-B)*C+B
            comb.arg0 = m.a;
            comb.arg1 = m.b;
            comb.arg2 = m.c;
            unit.ops[i%2] = GL_INTERPOLATE;
            break;
        case CM_FMT_TYPE_A_SUB_B_ADD_D:     // = A-B+D
            // fix me, to use 2 texture units
            comb.arg0 = m.a;
            comb.arg1 = m.b;
            unit.ops[i%2] = GL_SUBTRACT;
            break;
        case CM_FMT_TYPE_A_SUB_B_MOD_C:     // = (A-B)*C
            // fix me, to use 2 texture units
            comb.arg0 = m.a;
            comb.arg1 = m.c;
            unit.ops[i%2] = GL_MODULATE;
            break;
            break;
        case CM_FMT_TYPE_A_B_C_D:           // = (A-B)*C+D
#endif
        default:
            comb.arg0 = m.a;
            comb.arg1 = m.b;
            comb.arg2 = m.c;
            unit.ops[i%2] = GL_INTERPOLATE;
            break;
        }
    }

    if( m_pDecodedMux->splitType[2] == CM_FMT_TYPE_NOT_USED && m_pDecodedMux->splitType[3] == CM_FMT_TYPE_NOT_USED && !m_bTex1Enabled )
    {
        res.numOfUnits = 1;
    }

    res.units[0].tex = 0;
    res.units[1].tex = 1;

    return SaveParsedResult(res);
}

const char* COGLColorCombiner4::GetOpStr(GLenum op)
{
    switch( op )
    {
    case GL_REPLACE:
        return "REPLACE";
#ifndef USE_GLES
    case GL_MODULATE:
        return "MOD";
    case GL_ADD:
        return "ADD";
    case GL_ADD_SIGNED:
        return "ADD_SIGNED";
    case GL_INTERPOLATE:
        return "INTERPOLATE";
    case GL_SUBTRACT:
        return "SUB";
#endif
    case GL_MODULATE_ADD_ATI:
        return "MULADD";
    default:
        return "SUB";
    }
}

int COGLColorCombiner4::SaveParsedResult(OGLExtCombinerSaveType &result)
{
    result.dwMux0 = m_pDecodedMux->m_dwMux0;
    result.dwMux1 = m_pDecodedMux->m_dwMux1;

    for( int n=0; n<result.numOfUnits; n++ )
    {
        for( int i=0; i<3; i++ )
        {
            result.units[n].glRGBArgs[i] = 0;
            result.units[n].glRGBFlags[i] = 0;
            result.units[n].glAlphaArgs[i] = 0;
            result.units[n].glAlphaFlags[i] = 0;
            if( result.units[n].rgbComb.args[i] != CM_IGNORE_BYTE )
            {
                result.units[n].glRGBArgs[i] = MapRGBArgs(result.units[n].rgbComb.args[i]);
                result.units[n].glRGBFlags[i] = MapRGBArgFlags(result.units[n].rgbComb.args[i]);
            }
            if( result.units[n].alphaComb.args[i] != CM_IGNORE_BYTE )
            {
                result.units[n].glAlphaArgs[i] = MapAlphaArgs(result.units[n].alphaComb.args[i]);
                result.units[n].glAlphaFlags[i] = MapAlphaArgFlags(result.units[n].alphaComb.args[i]);
            }
        }
    }

    m_vCompiledSettings.push_back(result);
    m_lastIndex = m_vCompiledSettings.size()-1;

#ifdef DEBUGGER
    if( logCombiners )
    {
        DisplaySimpleMuxString();
    }
#endif

    return m_lastIndex;
}

bool isGLtex(GLint val)
{
    if( val >= GL_TEXTURE0 && val <= GL_TEXTURE7 )
        return true;
    else
        return false;
}


#ifdef DEBUGGER
extern const char *translatedCombTypes[];
void COGLColorCombiner4::DisplaySimpleMuxString(void)
{
    char buf0[30], buf1[30], buf2[30];
    OGLExtCombinerSaveType &result = m_vCompiledSettings[m_lastIndex];

    COGLColorCombiner::DisplaySimpleMuxString();
    DebuggerAppendMsg("OpenGL 1.2: %d Stages", result.numOfUnits);      
    for( int i=0; i<result.numOfUnits; i++ )
    {
        DebuggerAppendMsg("//aRGB%d:\t%s: %s, %s, %s\n", i,GetOpStr(result.units[i].rgbOp), DecodedMux::FormatStr(result.units[i].rgbArg0,buf0), DecodedMux::FormatStr(result.units[i].rgbArg1,buf1), DecodedMux::FormatStr(result.units[i].rgbArg2,buf2));     
        DebuggerAppendMsg("//aAlpha%d:\t%s: %s, %s, %s\n", i,GetOpStr(result.units[i].alphaOp), DecodedMux::FormatStr(result.units[i].alphaArg0,buf0), DecodedMux::FormatStr(result.units[i].alphaArg1,buf1), DecodedMux::FormatStr(result.units[i].alphaArg2,buf2));       
    }
    TRACE0("\n\n");
}
#endif


//////////////////////////////////////////////////////////////////////////
int COGLColorCombiner4::FindCompiledMux()
{
#ifdef DEBUGGER
    if( debuggerDropCombiners )
    {
        m_vCompiledSettings.clear();
        //m_dwLastMux0 = m_dwLastMux1 = 0;
        debuggerDropCombiners = false;
    }
#endif
    for( uint32 i=0; i<m_vCompiledSettings.size(); i++ )
    {
        if( m_vCompiledSettings[i].dwMux0 == m_pDecodedMux->m_dwMux0 && m_vCompiledSettings[i].dwMux1 == m_pDecodedMux->m_dwMux1 )
            return (int)i;
    }

    return -1;
}

//========================================================================

GLint COGLColorCombiner4::RGBArgsMap4[] =
{
#ifndef USE_GLES
    GL_PRIMARY_COLOR,               //MUX_0
    GL_PRIMARY_COLOR,               //MUX_1
    GL_PREVIOUS,                    //MUX_COMBINED,
#endif
    GL_TEXTURE0,                    //MUX_TEXEL0,
#ifndef USE_GLES
    GL_TEXTURE1,                    //MUX_TEXEL1,
    GL_CONSTANT,                    //MUX_PRIM,
    GL_PRIMARY_COLOR,               //MUX_SHADE,
    GL_CONSTANT,                    //MUX_ENV,
    GL_PREVIOUS,                    //MUX_COMBALPHA,
#endif
    GL_TEXTURE0,                    //MUX_T0_ALPHA,
#ifndef USE_GLES
    GL_TEXTURE1,                    //MUX_T1_ALPHA,
    GL_CONSTANT,                    //MUX_PRIM_ALPHA,
    GL_PRIMARY_COLOR,               //MUX_SHADE_ALPHA,
    GL_CONSTANT,                    //MUX_ENV_ALPHA,
    GL_CONSTANT,                    //MUX_LODFRAC,
    GL_CONSTANT,                    //MUX_PRIMLODFRAC,
    GL_PRIMARY_COLOR,               //MUX_K5
    GL_PRIMARY_COLOR                //MUX_UNK
#endif
};

//========================================================================

GLint COGLColorCombiner4::MapRGBArgs(uint8 arg)
{
    return RGBArgsMap4[arg&MUX_MASK];
}

GLint COGLColorCombiner4::MapRGBArgFlags(uint8 arg)
{
    if( (arg & MUX_ALPHAREPLICATE) && (arg & MUX_COMPLEMENT) )
    {
        return GL_ONE_MINUS_SRC_ALPHA;
    }
    else if( (arg & MUX_ALPHAREPLICATE) )
    {
        return GL_SRC_ALPHA;
    }
    else if(arg & MUX_COMPLEMENT) 
    {
        return GL_ONE_MINUS_SRC_COLOR;
    }
    else
        return GL_SRC_COLOR;
}

GLint COGLColorCombiner4::MapAlphaArgs(uint8 arg)
{
    return RGBArgsMap4[arg&MUX_MASK];
}

GLint COGLColorCombiner4::MapAlphaArgFlags(uint8 arg)
{
    if(arg & MUX_COMPLEMENT) 
    {
        return GL_ONE_MINUS_SRC_ALPHA;
    }
    else
        return GL_SRC_ALPHA;
}

//========================================================================

void ApplyFor1Unit(OGLExtCombinerType &unit)
{
#ifndef USE_GLES
    glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, unit.rgbOp);
    OPENGL_CHECK_ERRORS;

    if( unit.rgbArg0 != CM_IGNORE_BYTE )
    {
        glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, (unit.rgbArg0gl));
        OPENGL_CHECK_ERRORS;
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, (unit.rgbFlag0gl));
        OPENGL_CHECK_ERRORS;
    }

    if( unit.rgbArg1 != CM_IGNORE_BYTE )
    {
        glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, (unit.rgbArg1gl));
        OPENGL_CHECK_ERRORS;
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, (unit.rgbFlag1gl));
        OPENGL_CHECK_ERRORS;
    }

    if( unit.rgbArg2 != CM_IGNORE_BYTE )
    {
        glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB, (unit.rgbArg2gl));
        OPENGL_CHECK_ERRORS;
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_RGB, (unit.rgbFlag2gl));
        OPENGL_CHECK_ERRORS;
    }

    if( unit.alphaArg0 != CM_IGNORE_BYTE )
    {
        glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_ALPHA, (unit.alphaArg0gl));
        OPENGL_CHECK_ERRORS;
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA, (unit.alphaFlag0gl));
        OPENGL_CHECK_ERRORS;
    }

    if( unit.alphaArg1 != CM_IGNORE_BYTE )
    {
        glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_ALPHA, (unit.alphaArg1gl));
        OPENGL_CHECK_ERRORS;
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA, (unit.alphaFlag1gl));
        OPENGL_CHECK_ERRORS;
    }

    if( unit.alphaArg2 != CM_IGNORE_BYTE )
    {
        glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA, (unit.alphaArg2gl));
        OPENGL_CHECK_ERRORS;
        glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_ALPHA, (unit.alphaFlag2gl));
        OPENGL_CHECK_ERRORS;
    }
#endif
}

//////////////////////////////////////////////////////////////////////////

void COGLColorCombiner4::GenerateCombinerSetting(int index)
{
    OGLExtCombinerSaveType &res = m_vCompiledSettings[index];

    // Texture unit 0
    COGLTexture* pTexture = NULL;
    COGLTexture* pTexture1 = NULL;

    if( m_bTex0Enabled || m_bTex1Enabled || gRDP.otherMode.cycle_type  == CYCLE_TYPE_COPY )
    {
        if( m_bTex0Enabled || gRDP.otherMode.cycle_type  == CYCLE_TYPE_COPY )
        {
            pTexture = g_textures[gRSP.curTile].m_pCOGLTexture;
            if( pTexture )  m_pOGLRender->BindTexture(pTexture->m_dwTextureName, 0);
        }
        if( m_bTex1Enabled )
        {
            pTexture1 = g_textures[(gRSP.curTile+1)&7].m_pCOGLTexture;
            if( pTexture1 ) m_pOGLRender->BindTexture(pTexture1->m_dwTextureName, 1);
        }
    }



    for( int i=0; i<res.numOfUnits; i++ )
    {
        pglActiveTexture(GL_TEXTURE0+i);
        OPENGL_CHECK_ERRORS;
        m_pOGLRender->EnableTexUnit(i,TRUE);
        glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
        OPENGL_CHECK_ERRORS;
        ApplyFor1Unit(res.units[i]);
    }

    if( res.numOfUnits < m_maxTexUnits )
    {
        for( int i=res.numOfUnits; i<m_maxTexUnits; i++ )
        {
            pglActiveTexture(GL_TEXTURE0+i);
            OPENGL_CHECK_ERRORS;
            m_pOGLRender->DisBindTexture(0, i);
            m_pOGLRender->EnableTexUnit(i,FALSE);
        }
    }
}


void COGLColorCombiner4::GenerateCombinerSettingConstants(int index)
{
    OGLExtCombinerSaveType &res = m_vCompiledSettings[index];

    float *fv;
    float tempf[4];

    bool isused = true;

    if( res.primIsUsed )
    {
        fv = GetPrimitiveColorfv(); // CONSTANT COLOR
    }
    else if( res.envIsUsed )
    {
        fv = GetEnvColorfv();   // CONSTANT COLOR
    }
    else if( res.lodFracIsUsed )
    {
        float frac = gRDP.LODFrac / 255.0f;
        tempf[0] = tempf[1] = tempf[2] = tempf[3] = frac;
        fv = &tempf[0];
    }
    else
    {
        isused = false;
    }

    if( isused )
    {
        for( int i=0; i<res.numOfUnits; i++ )
        {
            pglActiveTexture(GL_TEXTURE0+i);
            OPENGL_CHECK_ERRORS;
            glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR,fv);
            OPENGL_CHECK_ERRORS;
        }
    }
}

GLenum GeneralToGLMaps[]=
{
    GL_REPLACE,             //CM_REPLACE,
#ifndef USE_GLES
    GL_MODULATE,            //CM_MODULATE,
    GL_ADD,                 //CM_ADD,
    GL_SUBTRACT,            //CM_SUBTRACT,
    GL_INTERPOLATE,         //CM_INTERPOLATE,
    GL_INTERPOLATE,         //CM_ADDSMOOTH,     
    GL_INTERPOLATE,         //CM_BLENDCURRENTALPHA
    GL_INTERPOLATE,         //CM_BLENDDIFFUSEALPHA
    GL_INTERPOLATE,         //CM_BLENDFACTORALPHA,
    GL_INTERPOLATE,         //CM_BLENDTEXTUREALPHA
#endif
    GL_MODULATE_ADD_ATI,    //CM_MULTIPLYADD,       
};

