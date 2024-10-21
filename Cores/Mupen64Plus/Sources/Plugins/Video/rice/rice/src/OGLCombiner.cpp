/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - OGLCombiner.cpp                                         *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2003 Rice1964                                           *
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

#include <stddef.h>

#include "CombinerDefs.h"
#include "GraphicsContext.h"
#include "OGLCombiner.h"
#include "OGLDebug.h"
#include "OGLRender.h"
#include "OGLGraphicsContext.h"
#include "OGLTexture.h"
#include "RenderBase.h"
#include "osal_opengl.h"
#include "osal_preproc.h"

class CRender;

//========================================================================
static uint32 DirectX_OGL_BlendFuncMaps [] =
{
    GL_SRC_ALPHA,               //Nothing
    GL_ZERO,                    //BLEND_ZERO               = 1,
    GL_ONE,                     //BLEND_ONE                = 2,
    GL_SRC_COLOR,               //BLEND_SRCCOLOR           = 3,
    GL_ONE_MINUS_SRC_COLOR,     //BLEND_INVSRCCOLOR        = 4,
    GL_SRC_ALPHA,               //BLEND_SRCALPHA           = 5,
    GL_ONE_MINUS_SRC_ALPHA,     //BLEND_INVSRCALPHA        = 6,
    GL_DST_ALPHA,               //BLEND_DESTALPHA          = 7,
    GL_ONE_MINUS_DST_ALPHA,     //BLEND_INVDESTALPHA       = 8,
    GL_DST_COLOR,               //BLEND_DESTCOLOR          = 9,
    GL_ONE_MINUS_DST_COLOR,     //BLEND_INVDESTCOLOR       = 10,
    GL_SRC_ALPHA_SATURATE,      //BLEND_SRCALPHASAT        = 11,
    GL_SRC_ALPHA_SATURATE,      //BLEND_BOTHSRCALPHA       = 12,    
    GL_SRC_ALPHA_SATURATE,      //BLEND_BOTHINVSRCALPHA    = 13,
};

//========================================================================

#include "OGLExtensions.h"
#include <assert.h>

static char newFrgStr[4092]; // The main buffer for store fragment shader string

static const char *vertexShaderStr =
"#version " GLSL_VERSION "\n"
"uniform vec2 uFogMinMax;\n"
"\n"
"attribute vec4 inPosition;\n"
"attribute vec2 inTexCoord0;\n"
"attribute vec2 inTexCoord1;\n"
"attribute float inFog;\n"
"attribute vec4 inShadeColor;\n"
"\n"
"varying vec2 vertexTexCoord0;\n"
"varying vec2 vertexTexCoord1;\n"
"varying float vertexFog;\n"
"varying vec4 vertexShadeColor;\n"
"\n"
"void main()\n"
"{\n"
"gl_Position = inPosition;\n"
"vertexTexCoord0 = inTexCoord0;\n"
"vertexTexCoord1 = inTexCoord1;\n"
"vertexFog = clamp((uFogMinMax[1] - inFog) / (uFogMinMax[1] - uFogMinMax[0]), 0.0, 1.0);\n"
"vertexShadeColor = inShadeColor;\n"
"}\n";

static const char *fragmentShaderHeader =
"#version " GLSL_VERSION "\n"
"#ifdef GL_ES\n"
"precision lowp float;\n"
"#else\n"
"#define lowp\n"
"#define mediump\n"
"#define highp\n"
"#endif\n"
"\n";

static const char *fragmentShaderBigEndianHeader =
"#define SAMPLE_TEXTURE(samp, uv) (texture2D(samp, uv).gbar)\n"
"\n";

static const char *fragmentShaderLittleEndianHeader =
"#define SAMPLE_TEXTURE(samp, uv) (texture2D(samp, uv).bgra)\n"
"\n";

static const char *fragmentCycle12Header =
"uniform vec4 uBlendColor;\n"
"uniform vec4 uPrimColor;\n"
"uniform vec4 uEnvColor;\n"
"uniform vec3 uChromaKeyCenter;\n"
"uniform vec3 uChromaKeyScale;\n"
"uniform vec3 uChromaKeyWidth;\n"
"uniform float uLodFrac;\n"
"uniform float uPrimLodFrac;\n"
"uniform float uK5;\n"
"uniform float uK4;\n"
"uniform sampler2D uTex0;\n"
"uniform sampler2D uTex1;\n"
"uniform vec4 uFogColor;\n"
"\n"
"varying vec2 vertexTexCoord0;\n"
"varying vec2 vertexTexCoord1;\n"
"varying float vertexFog;\n"
"varying vec4 vertexShadeColor;\n"
"\n"
"void main()\n"
"{\n"
"vec4 outColor;\n";

//Fragment shader for InitCycleCopy
static const char *fragmentCopyHeader =
"uniform vec4 uBlendColor;\n"
"uniform sampler2D uTex0;\n"
"varying vec2 vertexTexCoord0;\n"
"void main()\n"
"{\n"
"vec4 outColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0);\n";

//Fragment shader for InitCycleFill (the only self contain fragment shader)
static const char *fragmentFill =
"#version " GLSL_VERSION "\n"
"#ifdef GL_ES\n"
"precision lowp float;\n"
"#else\n"
"#define lowp\n"
"#define mediump\n"
"#define highp\n"
"#endif\n"
"\n"
"uniform vec4 uFillColor;\n"
"void main()\n"
"{\n"
"gl_FragColor = uFillColor;\n"
"}\n";

static const char *fragmentShaderFooter =
"gl_FragColor = outColor;\n"
"}\n";

static bool isBigEndian()
{
    int number = 1;
    return ((char*)&number)[0] == 0;
}

static void writeFragmentShaderHeader()
{
    newFrgStr[0] = 0;
    strcat(newFrgStr, fragmentShaderHeader);
    strcat(newFrgStr, isBigEndian() ? fragmentShaderBigEndianHeader : fragmentShaderLittleEndianHeader);
}

static GLuint createShader( GLenum shaderType, const char* shaderSrc )
{
    assert( shaderSrc != NULL );

    GLuint shader = glCreateShader( shaderType ); OPENGL_CHECK_ERRORS // GL_VERTEX_SHADER, GL_FRAGMENT_SHADER

    glShaderSource(shader, 1, &shaderSrc, NULL); OPENGL_CHECK_ERRORS
    glCompileShader(shader); OPENGL_CHECK_ERRORS

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status); OPENGL_CHECK_ERRORS
    if (status == GL_FALSE)
    {
        printf("Compile shader failed:\n");
        printf("Shader type: ");

        switch(shaderType)
        {
            case GL_VERTEX_SHADER :
                printf("Vertex\n");
                break;
            case GL_FRAGMENT_SHADER :
                printf("Fragment\n");
                break;
            default:
                printf("Unknown?\n");
                break;
        }

        GLint param = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &param); OPENGL_CHECK_ERRORS

        GLsizei infoLogLength = (GLsizei) param;
        assert( infoLogLength >= 0 );
        GLchar *pInfoLog = new GLchar[ infoLogLength+1 ];
        glGetShaderInfoLog(shader, infoLogLength, NULL, pInfoLog); OPENGL_CHECK_ERRORS

        printf("Info log:\n%s\n", pInfoLog);
        printf("GLSL code:\n%s\n", shaderSrc);

        glDeleteShader(shader); OPENGL_CHECK_ERRORS
        delete[] pInfoLog;
    }

    return shader;
};

static GLuint createProgram(const GLuint vShader, GLuint fShader)
{
    assert( vShader > CC_NULL_SHADER );
    assert( fShader > CC_NULL_SHADER );

    GLuint program = glCreateProgram(); OPENGL_CHECK_ERRORS

    glAttachShader(program, vShader); OPENGL_CHECK_ERRORS
    glAttachShader(program, fShader); OPENGL_CHECK_ERRORS

    glBindAttribLocation(program,VS_POSITION,"inPosition"); OPENGL_CHECK_ERRORS
    glBindAttribLocation(program,VS_TEXCOORD0,"inTexCoord0"); OPENGL_CHECK_ERRORS
    glBindAttribLocation(program,VS_TEXCOORD1,"inTexCoord1"); OPENGL_CHECK_ERRORS
    glBindAttribLocation(program,VS_FOG,"inFog"); OPENGL_CHECK_ERRORS
    glBindAttribLocation(program,VS_COLOR,"inShadeColor"); OPENGL_CHECK_ERRORS

    glLinkProgram(program);

    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status); OPENGL_CHECK_ERRORS
    if (status == GL_FALSE)
    {
        printf("Program link failed.\n");

        GLint param = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &param); OPENGL_CHECK_ERRORS

        GLsizei infoLogLength = (GLsizei) param;
        assert( infoLogLength >= 0 );
        GLchar *pInfoLog = new GLchar[ infoLogLength+1 ];

        glGetProgramInfoLog(program, infoLogLength, NULL, pInfoLog); OPENGL_CHECK_ERRORS
        printf("Info log:\n%s\n", pInfoLog);

        glDeleteProgram(program); OPENGL_CHECK_ERRORS
        delete[] pInfoLog;
    }

    glDetachShader(program, vShader); OPENGL_CHECK_ERRORS
    glDetachShader(program, fShader); OPENGL_CHECK_ERRORS

    return program;
}

COGLColorCombiner::COGLColorCombiner(CRender *pRender) :
    CColorCombiner(pRender),
    m_pOGLRender((OGLRender*)pRender),
    m_currentProgram(CC_NULL_PROGRAM)
{
    m_vtxShader = createShader( GL_VERTEX_SHADER, vertexShaderStr );

    // Generate Fill program
    GLuint frgShaderFill = createShader( GL_FRAGMENT_SHADER, fragmentFill );
    m_fillProgram  = createProgram(m_vtxShader, frgShaderFill);
    m_fillColorLoc = glGetUniformLocation(m_fillProgram,"uFillColor"); OPENGL_CHECK_ERRORS
    glDeleteShader( frgShaderFill ); OPENGL_CHECK_ERRORS
}

COGLColorCombiner::~COGLColorCombiner()
{
    if( glIsShader( m_vtxShader ) == GL_TRUE )
        glDeleteShader(m_vtxShader); OPENGL_CHECK_ERRORS

    if ( glIsProgram( m_fillProgram ) == GL_TRUE )
        glDeleteProgram( m_fillProgram ); OPENGL_CHECK_ERRORS

    // Remove every created OpenGL programs
    ShaderSaveType* saveType = NULL;
    for( size_t i=0; i<m_generatedPrograms.size(); i++ )
    {
        saveType = &m_generatedPrograms[i];

        if ( glIsProgram( saveType->program ) == GL_TRUE )
            glDeleteProgram( saveType->program ); OPENGL_CHECK_ERRORS
    }
}

bool COGLColorCombiner::Initialize(void)
{
    return true;
}

void COGLColorCombiner::DisableCombiner(void)
{
    useProgram( CC_NULL_PROGRAM );
    OPENGL_CHECK_ERRORS
}

void COGLColorCombiner::InitCombinerCycleCopy(void)
{
    // Look if we already have a compiled program for the current state.
    int shaderId = FindCompiledShaderId();

    if( shaderId == -1 ) {
        shaderId = GenerateCopyProgram();
    }

    const GLuint &program = m_generatedPrograms[shaderId].program;
    useProgram( program );

    m_pOGLRender->EnableTexUnit(0,TRUE);

    GenerateCombinerSetting();
    GenerateCombinerSettingConstants( shaderId );

    glEnableVertexAttribArray(VS_POSITION);
    OPENGL_CHECK_ERRORS
    glEnableVertexAttribArray(VS_TEXCOORD0);
    OPENGL_CHECK_ERRORS
    glDisableVertexAttribArray(VS_COLOR);
    OPENGL_CHECK_ERRORS
    glDisableVertexAttribArray(VS_TEXCOORD1);
    OPENGL_CHECK_ERRORS
    glDisableVertexAttribArray(VS_FOG);
    OPENGL_CHECK_ERRORS
    COGLTexture* pTexture = g_textures[gRSP.curTile].m_pCOGLTexture;
    if( pTexture )
    {
        m_pOGLRender->BindTexture(pTexture->m_dwTextureName, 0);
        m_pOGLRender->SetTexelRepeatFlags(gRSP.curTile);
    }
}

void COGLColorCombiner::InitCombinerCycleFill(void)
{
    useProgram( m_fillProgram );

    glUniform4f( m_fillColorLoc, ((gRDP.fillColor>>16)&0xFF)/255.0f,
                                  ((gRDP.fillColor>>8) &0xFF)/255.0f,
                                  ((gRDP.fillColor)    &0xFF)/255.0f,
                                  ((gRDP.fillColor>>24)&0xFF)/255.0f);
    OPENGL_CHECK_ERRORS
}

// Generate the Blender (BL) part of the fragment shader
void COGLColorCombiner::genFragmentBlenderStr( char *newFrgStr )
{
    ////////////////////////////////////////////////////////////////////////////
    // BL (Blender). Equation: (A*P+B*M)/(A+B)
    ////////////////////////////////////////////////////////////////////////////

    /*uint16 tmpblender = gRDP.otherMode.blender;
    //RDP_BlenderSetting &bl = *(RDP_BlenderSetting*)(&(blender));
    RDP_BlenderSetting* blender = (RDP_BlenderSetting*)(&tmpblender);

    switch( blender->c1_m1a ) // A cycle 1
    {
        case 0 : // CC output alpha
            strcat(newFrgStr, "float BL_A = outColor.a;\n");
            break;
        case 1 : // fog alpha (register)
            strcat(newFrgStr, "float BL_A = vertexFog;\n");
            break;
        case 2 : // shade alpha
            strcat(newFrgStr, "float BL_A = vertexShadeColor.a;\n");
            break;
        case 3 : // 0.0
            strcat(newFrgStr, "float BL_A = 0.0;\n");
            break;
    }
    switch( blender->c1_m1b ) // P cycle 1 (Same as M)
    {
        case 0 : // pixel rgb
            strcat(newFrgStr, "vec3 BL_P = outColor.rgb;\n");
            break;
        case 1 :
            // TODO: 1 memory RGB (what is that?)
            //strcat(newFrgStr, "vec3 BL_P = vec3(1.0, 0.0, 1.0);\n"); //purple...
            strcat(newFrgStr, "vec3 BL_P = uPrimColor.rgb;\n");
            break;
        case 2 : // blend rgb (register)
            strcat(newFrgStr, "vec3 BL_P = uBlendColor.rgb;\n");
            break;
        case 3 : // fog rgb (register)
            //strcat(newFrgStr, "vec3 BL_P = uFogColor.rgb;\n");
            strcat(newFrgStr, "vec3 BL_P = vec3(1.0, 0.0, 1.0);\n"); //purple...
            break;
    }
    switch( blender->c1_m2a ) // B cycle 1
    {
        case 0 : // 1.0 - ‘a mux’ output
            strcat(newFrgStr, "float BL_B = 1.0 - BL_A;\n");
            break;
        case 1 : // memory alpha
            // TODO: memory alpha (what is that?)
            strcat(newFrgStr, "float BL_B = 1.0;\n");
            break;
        case 2 : // 1.0
            strcat(newFrgStr, "float BL_B = 1.0;\n");
            break;
        case 3 : // 0.0
            strcat(newFrgStr, "float BL_B = 0.0;\n");
            break;
    }
    switch( blender->c1_m2b ) // M cycle 1 (Same as P)
    {
        case 0 : // pixel rgb
            strcat(newFrgStr, "vec3 BL_M = outColor.rgb;\n");
            break;
        case 1 :
            // TODO: 1 memory RGB (what is that?)
            //strcat(newFrgStr, "vec3 BL_M = vec3(1.0, 0.0, 1.0);\n"); //purple...
            strcat(newFrgStr, "vec3 BL_M = uPrimColor.rgb;\n");
            break;
        case 2 : // blend rgb (register)
            strcat(newFrgStr, "vec3 BL_M = uBlendColor.rgb;\n");
            break;
        case 3 : // fog rgb (register)
            //strcat(newFrgStr, "vec3 BL_M = uFogColor.rgb;\n");
            strcat(newFrgStr, "vec3 BL_M = vec3(1.0, 0.0, 1.0);\n"); //purple...
            break;
    }
    strcat(newFrgStr, "outColor = ( vec4(BL_P.rgb, BL_A) + vec4(BL_M.rgb, BL_B) ) / vec4( BL_A + BL_B );\n");*/

    // When aa_en and alpha_cvg_sel are enabled, N64 do a nice and smoother clamp (aka coverage is smooth).
    // This try to simulate the "smooth" clamp increasing the value to avoid pixelized clamp
    /*if( gRDP.otherMode.aa_en )
    {
        strcat(newFrgStr, "float clamp_value = 0.5;\n");
    } else {
        strcat(newFrgStr, "float clamp_value = 0.004;\n"); // default value 1/255 = 0.004
    }*/
    /*    // As we don't have coverage in GLSL, we consider coverage = alpha
        if( gRDP.otherMode.alpha_cvg_sel ) // Use coverage bits for alpha calculation
        {
            if( gRDP.otherMode.cvg_x_alpha )
            {
                // texture cutout mode (Mario Kart 64 kart sprites/Mario 64 trees/some 1080SB  face to cam border trees)
                strcat(newFrgStr, "if( outColor.a < clamp_value ) discard;\n");
            }
            else
            {
                //strcat(newFrgStr, "outColor.a = 1.0;\n");
            }
        } else if( gRDP.otherMode.cvg_x_alpha )
        {
            // strict texture cutout mode (Mario Kart 64 items sprites /1080SB border trees)
            strcat(newFrgStr, "if( outColor.a < 0.004 ) discard;\n");
        }*/
    //}

    strcat(newFrgStr, "float coverage = 1.0;\n");
    if( gRDP.otherMode.cvg_x_alpha )
    {
        /*strcat(newFrgStr, "if( outColor.a > 0.004 ) {\n");
        strcat(newFrgStr, "    coverage = 1.0;\n");
        strcat(newFrgStr, "} else {\n");
        strcat(newFrgStr, "    coverage = 0.0;\n");
        strcat(newFrgStr, "}\n");*/
        strcat(newFrgStr, "coverage = coverage * outColor.a;\n");
    }
    if( gRDP.otherMode.alpha_cvg_sel ) // Use coverage bits for alpha calculation
    {
        // texture cutof (MK64 kart sprites/Mario 64 trees/1080SB "face to cam" border trees)
        strcat(newFrgStr, "coverage = step( 0.5, coverage );\n");
        strcat(newFrgStr, "outColor.a = coverage;\n");
    }
    /*if( gRDP.otherMode.clr_on_cvg ) // SSB64 first ground sprites
    {
        strcat(newFrgStr, "if( coverage < 0.004 ) discard;\n");
    }*/

    /*switch( gRDP.otherMode.cvg_dst ) {
        case CVG_DST_CLAMP :
            strcat(newFrgStr, "if( coverage < 0.99 ) coverage = 0.0 ;\n");
            break;
        case CVG_DST_WRAP :
            strcat(newFrgStr, "if( coverage > 0.004 ) coverage = 1.0 ;\n");
            break;
        case CVG_DST_FULL :
            strcat(newFrgStr, "coverage = 1.0 ;\n");
            break;
        case CVG_DST_SAVE :
            strcat(newFrgStr, "coverage = 0.0 ;\n");
            break;
        default :
            break;
    }*/

    strcat(newFrgStr, "if( coverage < 0.1 ) discard;\n");

    switch( gRDP.otherMode.alpha_compare )
    {
        case RDP_ALPHA_COMPARE_THRESHOLD :
            // keep value if outColor.a >= uBlendColor.a
            //strcat(newFrgStr, "if( abs( uBlendColor.a - outColor.a ) < 0.00000001 ) discard;\n"); // Top Gear Rally use this mode for opacity
            strcat(newFrgStr, "if( outColor.a < uBlendColor.a ) discard;\n");
            break;
        case RDP_ALPHA_COMPARE_DITHER :
            strcat(newFrgStr, "if( outColor.a < fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233)))* 43758.5453) ) discard;\n");
            break;
        case RDP_ALPHA_COMPARE_NONE :
        default :
            break;
    }

    if( gRDP.bFogEnableInBlender && gRSP.bFogEnabled ) {
        strcat(newFrgStr, "outColor.rgb = mix(uFogColor.rgb, outColor.rgb, vertexFog);\n");
        //strcat(newFrgStr, "outColor.rgb = vec3(vertexFog,vertexFog,vertexFog);\n");
    }
}

// Generate a program for the current combiner state
// The main part of the function add one line for each part of the combiner.
// A, B, C, D (colors) and a, b, c, d (alpha). So if you modify the part of one of them
// don't forget to modify the part for the other (A and a, B and b, etc...)
GLuint COGLColorCombiner::GenerateCycle12Program()
{
    writeFragmentShaderHeader();

    strcat(newFrgStr, fragmentCycle12Header);

    ////////////////////////////////////////////////////////////////////////////
    // Colors (rgb) Cycle 1
    ////////////////////////////////////////////////////////////////////////////

    // A0 (Cycle 1)
    switch( m_sources[CS_COLOR_A0] )
    {
        case CCMUX_COMBINED : // 0 (this commented numbers are related to the Color Combiner schema)
            printf("CCMUX_COMBINED for AColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 AColor = vec3(1.0, 1.0, 1.0);\n"); // set "something".
            break;
        case CCMUX_TEXEL0 : // 1
            strcat(newFrgStr, "vec3 AColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
            break;
        case CCMUX_TEXEL1 : // 2
            strcat(newFrgStr, "vec3 AColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
            break;
        case CCMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "vec3 AColor = uPrimColor.rgb;\n");
            break;
        case CCMUX_SHADE : // 4
            strcat(newFrgStr, "vec3 AColor = vertexShadeColor.rgb;\n");
            break;
        case CCMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "vec3 AColor = uEnvColor.rgb;\n");
            break;
        case CCMUX_1 : // 6
            strcat(newFrgStr, "vec3 AColor = vec3(1.0);\n");
            break;
        case CCMUX_NOISE : // 7
            strcat(newFrgStr, "vec3 AColor = noise3(0.0);\n");
            break;
        case CCMUX_0 : // 8
        default: // everything > CCMUX_0 (8) is 0
            strcat(newFrgStr, "vec3 AColor = vec3(0.0);\n");
            break;
    }

    // B0 (Cycle 1)
    switch( m_sources[CS_COLOR_B0] )
    {
        case CCMUX_COMBINED : // 0
            printf("CCMUX_COMBINED for BColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 BColor = vec3(1.0, 1.0, 1.0);\n"); // set "something".
            break;
        case CCMUX_TEXEL0 : // 1
            strcat(newFrgStr, "vec3 BColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
            break;
        case CCMUX_TEXEL1 :// 2
            strcat(newFrgStr, "vec3 BColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
            break;
        case CCMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "vec3 BColor = uPrimColor.rgb;\n");
            break;
        case CCMUX_SHADE : // 4
            strcat(newFrgStr, "vec3 BColor = vertexShadeColor.rgb;\n");
            break;
        case CCMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "vec3 BColor = uEnvColor.rgb;\n");
            break;
        case CCMUX_CENTER : // 6
            printf("CCMUX_CENTER for BColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 BColor = uChromaKeyCenter;\n");
            break;
        case CCMUX_K4 : // 7
            strcat(newFrgStr, "vec3 BColor = vec3(uK4);\n");
            break;
        case CCMUX_0 : // 8
        default: // everything > CCMUX_0 (8) is 0
            strcat(newFrgStr, "vec3 BColor = vec3(0.0);\n");
            break;
    }

    // C0 (Cycle 1)
    switch( m_sources[CS_COLOR_C0] )
    {
        case CCMUX_COMBINED : // 0
            printf("CCMUX_COMBINED for CColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 CColor = vec3(1.0, 1.0, 1.0);\n"); // set "something".
            break;
        case CCMUX_TEXEL0 : // 1
            strcat(newFrgStr, "vec3 CColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
            break;
        case CCMUX_TEXEL1 :// 2
            strcat(newFrgStr, "vec3 CColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
            break;
        case CCMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "vec3 CColor = uPrimColor.rgb;\n");
            break;
        case CCMUX_SHADE : // 4
            strcat(newFrgStr, "vec3 CColor = vertexShadeColor.rgb;\n");
            break;
        case CCMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "vec3 CColor = uEnvColor.rgb;\n");
            break;
        case CCMUX_SCALE : // 6
            printf("CCMUX_SCALE for CColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 CColor = uChromaKeyScale;\n");
            break;
        case CCMUX_COMBINED_ALPHA : // 7
            printf("CCMUX_COMBINED_ALPHA for CColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 CColor = uEnvColor;\n");
            break;
        case CCMUX_TEXEL0_ALPHA : // 8
            strcat(newFrgStr, "vec3 CColor = vec3(SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a);\n");
            break;
        case CCMUX_TEXEL1_ALPHA : // 9
            strcat(newFrgStr, "vec3 CColor = vec3(SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a);\n");
            break;
        case CCMUX_PRIMITIVE_ALPHA : // 10
            strcat(newFrgStr, "vec3 CColor = vec3(uPrimColor.a);\n");
            break;
        case CCMUX_SHADE_ALPHA : // 11
            strcat(newFrgStr, "vec3 CColor = vec3(vertexShadeColor.a);\n");
            break;
        case CCMUX_ENV_ALPHA : // 12
            strcat(newFrgStr, "vec3 CColor = vec3(uEnvColor.a);\n");
            break;
        case CCMUX_LOD_FRACTION : // 13
            strcat(newFrgStr, "vec3 CColor = vec3(uLodFrac);\n"); // Used by Goldeneye64
            break;
        case CCMUX_PRIM_LOD_FRAC : // 14
            strcat(newFrgStr, "vec3 CColor = vec3(uPrimLodFrac);\n"); // Used by Doom64
            break;
        case CCMUX_K5 : // 15
            strcat(newFrgStr, "vec3 CColor = vec3(uK5);\n");
            break;
        case CCMUX_0 : // 16
        default: // everything > CCMUX_0 (16) is 0
            strcat(newFrgStr, "vec3 CColor = vec3(0.0);\n");
            break;
    }

    // D0 (Cycle 1)
    switch( m_sources[CS_COLOR_D0] )
    {
        case CCMUX_COMBINED : // 0
            printf("CCMUX_COMBINED for DColor. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "vec3 DColor = vec3(1.0, 1.0, 1.0);\n"); // set "something".
            break;
        case CCMUX_TEXEL0 : // 1
            strcat(newFrgStr, "vec3 DColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
            break;
        case CCMUX_TEXEL1 :// 2
            strcat(newFrgStr, "vec3 DColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
            break;
        case CCMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "vec3 DColor = uPrimColor.rgb;\n");
            break;
        case CCMUX_SHADE : // 4
            strcat(newFrgStr, "vec3 DColor = vertexShadeColor.rgb;\n");
            break;
        case CCMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "vec3 DColor = uEnvColor.rgb;\n");
            break;
        case CCMUX_1 : // 6
            strcat(newFrgStr, "vec3 DColor = vec3(1.0);\n");
            break;
        case CCMUX_0 : // 7
        default: // everything > CCMUX_0 (7) is 0
            strcat(newFrgStr, "vec3 DColor = vec3(0.0);\n");
            break;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Alphas (float) Cycle 1
    ////////////////////////////////////////////////////////////////////////////

    // a0 (Cycle 1) (same than b0 and c0 actually)
    switch( m_sources[CS_ALPHA_A0] )
    {
        case ACMUX_COMBINED : // 0
            printf("ACMUX_COMBINED for AAlpha. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "float AAlpha = 1.0;\n"); // set "something".
            break;
        case ACMUX_TEXEL0 : // 1
            strcat(newFrgStr, "float AAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
            break;
        case ACMUX_TEXEL1 : // 2
            strcat(newFrgStr, "float AAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
            break;
        case ACMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "float AAlpha = uPrimColor.a;\n");
            break;
        case ACMUX_SHADE : // 4
            strcat(newFrgStr, "float AAlpha = vertexShadeColor.a;\n");
            break;
        case ACMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "float AAlpha = uEnvColor.a;\n");
            break;
        case ACMUX_1 : // 6
            strcat(newFrgStr, "float AAlpha = 1.0;\n");
            break;
        case ACMUX_0 : // 7
        default: // everything > CCMUX_0 (7) is 0
            strcat(newFrgStr, "float AAlpha = 0.0;\n");
            break;
    }

    // b0 (Cycle 1) (same than a0 and c0 actually)
    switch( m_sources[CS_ALPHA_B0] )
    {
        case ACMUX_COMBINED : // 0
            printf("ACMUX_COMBINED for BAlpha. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "float BAlpha = 1.0;\n"); // set "something".
            break;
        case ACMUX_TEXEL0 : // 1
            strcat(newFrgStr, "float BAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
            break;
        case ACMUX_TEXEL1 : // 2
            strcat(newFrgStr, "float BAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
            break;
        case ACMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "float BAlpha = uPrimColor.a;\n");
            break;
        case ACMUX_SHADE : // 4
            strcat(newFrgStr, "float BAlpha = vertexShadeColor.a;\n");
            break;
        case ACMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "float BAlpha = uEnvColor.a;\n");
            break;
        case ACMUX_1 : // 6
            strcat(newFrgStr, "float BAlpha = 1.0;\n");
            break;
        case ACMUX_0 : // 7
        default: // everything > CCMUX_0 (7) is 0
            strcat(newFrgStr, "float BAlpha = 0.0;\n");
            break;
    }

    // c0 (Cycle 1) kind of "exotic"
    switch( m_sources[CS_ALPHA_C0] )
    {
        case ACMUX_LOD_FRACTION : // 0
            strcat(newFrgStr, "float CAlpha = uLodFrac;\n");
            break;
        case ACMUX_TEXEL0 : // 1
            strcat(newFrgStr, "float CAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
            break;
        case ACMUX_TEXEL1 : // 2
            strcat(newFrgStr, "float CAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
            break;
        case ACMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "float CAlpha = uPrimColor.a;\n");
            break;
        case ACMUX_SHADE : // 4
            strcat(newFrgStr, "float CAlpha = vertexShadeColor.a;\n");
            break;
        case ACMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "float CAlpha = uEnvColor.a;\n");
            break;
        case ACMUX_PRIM_LOD_FRAC : // 6
            strcat(newFrgStr, "float CAlpha = uPrimLodFrac;\n");
            break;
        case ACMUX_0 : // 7
        default: // everything > CCMUX_0 (7) is 0
            strcat(newFrgStr, "float CAlpha = 0.0;\n");
            break;
    }

    // d0 (Cycle 1) (same than a0 and b0 actually)
    switch( m_sources[CS_ALPHA_D0] )
    {
        case ACMUX_COMBINED : // 0
            printf("ACMUX_COMBINED for DAlpha. This should never happen in cycle 1.\n");
            //strcat(newFrgStr, "float DAlpha = 1.0;\n"); // set "something".
            break;
        case ACMUX_TEXEL0 : // 1
            strcat(newFrgStr, "float DAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
            break;
        case ACMUX_TEXEL1 : // 2
            strcat(newFrgStr, "float DAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
            break;
        case ACMUX_PRIMITIVE : // 3
            strcat(newFrgStr, "float DAlpha = uPrimColor.a;\n");
            break;
        case ACMUX_SHADE : // 4
            strcat(newFrgStr, "float DAlpha = vertexShadeColor.a;\n");
            break;
        case ACMUX_ENVIRONMENT : // 5
            strcat(newFrgStr, "float DAlpha = uEnvColor.a;\n");
            break;
        case ACMUX_1 : // 6
            strcat(newFrgStr, "float DAlpha = 1.0;\n");
            break;
        case ACMUX_0 : // 7
        default: // everything > CCMUX_0 (7) is 0
            strcat(newFrgStr, "float DAlpha = 0.0;\n");
            break;
    }

    strcat(newFrgStr, "vec3 cycle1Color = (AColor - BColor) * CColor + DColor;\n");
    //strcat(newFrgStr, "vec3 cycle1Color = vec3(float(AColor), float(CColor), float(DColor));\n");
    strcat(newFrgStr, "float cycle1Alpha = (AAlpha - BAlpha) * CAlpha + DAlpha;\n");
    //strcat(newFrgStr, "float cycle1Alpha = AAlpha;\n");

    //strcat(newFrgStr, "outColor.rgb = vec3(greaterThan(cycle1Color, vec3(1.0)));\n");
    //strcat(newFrgStr, "outColor.rgb = cycle1Color;\n");
    //strcat(newFrgStr, "outColor.a = cycle1Alpha;\n");

    switch( gRDP.otherMode.cycle_type )
    {
        case CYCLE_TYPE_1 : // 1 cycle mode? compute the fragment color
            strcat(newFrgStr, "outColor.rgb = cycle1Color;\n");
            strcat(newFrgStr, "outColor.a = cycle1Alpha;\n");
            break;
        case CYCLE_TYPE_2 : { // 2 cycle mode? add another color computation
            // Chroma key
            if( gRDP.otherMode.key_en )
            {
                strcat(newFrgStr, "float resultChromaKeyR = clamp( 0.0, (-abs( (cycle1Color.r - uChromaKeyCenter.r) * uChromaKeyScale.r) + uChromaKeyWidth.r), 1.0);\n");
                strcat(newFrgStr, "float resultChromaKeyG = clamp( 0.0, (-abs( (cycle1Color.g - uChromaKeyCenter.g) * uChromaKeyScale.g) + uChromaKeyWidth.g), 1.0);\n");
                strcat(newFrgStr, "float resultChromaKeyB = clamp( 0.0, (-abs( (cycle1Color.b - uChromaKeyCenter.b) * uChromaKeyScale.b) + uChromaKeyWidth.b), 1.0);\n");
                strcat(newFrgStr, "float resultChromaKeyA = min( resultChromaKeyR, resultChromaKeyG, resultChromaKeyB );\n");
                strcat(newFrgStr, "outColor = vec4( resultChromaKeyR, resultChromaKeyG, resultChromaKeyB, resultChromaKeyA );\n");
            } else { // Color combiner
                ////////////////////////////////////////////////////////////////////////////
                // Colors (rgb) Cycle 2
                ////////////////////////////////////////////////////////////////////////////

                // A0 (Cycle 2)
                switch( m_sources[CS_COLOR_A1] )
                {
                    case CCMUX_COMBINED : // 0
                        strcat(newFrgStr, "AColor = cycle1Color;\n");
                        break;
                    case CCMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "AColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
                        break;
                    case CCMUX_TEXEL1 : // 2
                        strcat(newFrgStr, "AColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
                        break;
                    case CCMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "AColor = uPrimColor.rgb;\n");
                        break;
                    case CCMUX_SHADE : // 4
                        strcat(newFrgStr, "AColor = vertexShadeColor.rgb;\n");
                        break;
                    case CCMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "AColor = uEnvColor.rgb;\n");
                        break;
                    case CCMUX_1 : // 6
                        strcat(newFrgStr, "AColor = vec3(1.0, 1.0, 1.0);\n");
                        break;
                    case CCMUX_NOISE : // 7
                        strcat(newFrgStr, "AColor = noise3(0.0);\n");
                        break;
                    case CCMUX_0 : // 8
                    default: // everything > CCMUX_0 (8) is 0
                        strcat(newFrgStr, "AColor = vec3(0.0, 0.0, 0.0);\n");
                        break;
                }

                // B0 (Cycle 2)
                switch( m_sources[CS_COLOR_B1] )
                {
                    case CCMUX_COMBINED : // 0
                        strcat(newFrgStr, "BColor = cycle1Color;\n");
                        break;
                    case CCMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "BColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
                        break;
                    case CCMUX_TEXEL1 :// 2
                        strcat(newFrgStr, "BColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
                        break;
                    case CCMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "BColor = uPrimColor.rgb;\n");
                        break;
                    case CCMUX_SHADE : // 4
                        strcat(newFrgStr, "BColor = vertexShadeColor.rgb;\n");
                        break;
                    case CCMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "BColor = uEnvColor.rgb;\n");
                        break;
                    case CCMUX_CENTER : // 6
                        strcat(newFrgStr, "BColor = uChromaKeyCenter;\n");
                        break;
                    case CCMUX_K4 : // 7
                        strcat(newFrgStr, "BColor = vec3(uK4);\n");
                        break;
                    case CCMUX_0 : // 8
                    default: // everything > CCMUX_0 (8) is 0
                        strcat(newFrgStr, "BColor = vec3(0.0, 0.0, 0.0);\n");
                        break;
                }

                // C0 (Cycle 2)
                switch( m_sources[CS_COLOR_C1] )
                {
                    case CCMUX_COMBINED : // 0
                        strcat(newFrgStr, "CColor = cycle1Color;\n");
                        break;
                    case CCMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "CColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
                        break;
                    case CCMUX_TEXEL1 :// 2
                        strcat(newFrgStr, "CColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
                        break;
                    case CCMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "CColor = uPrimColor.rgb;\n");
                        break;
                    case CCMUX_SHADE : // 4
                        strcat(newFrgStr, "CColor = vertexShadeColor.rgb;\n");
                        break;
                    case CCMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "CColor = uEnvColor.rgb;\n");
                        break;
                    case CCMUX_SCALE : // 6
                        strcat(newFrgStr, "CColor = uChromaKeyScale;\n");
                        break;
                    case CCMUX_COMBINED_ALPHA : // 7
                        strcat(newFrgStr, "CColor = vec3(cycle1Alpha);\n");
                        break;
                    case CCMUX_TEXEL0_ALPHA : // 8
                        strcat(newFrgStr, "CColor = vec3(SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a);\n");
                        break;
                    case CCMUX_TEXEL1_ALPHA : // 9
                        strcat(newFrgStr, "CColor = vec3(SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a);\n");
                        break;
                    case CCMUX_PRIMITIVE_ALPHA : // 10
                        strcat(newFrgStr, "CColor = vec3(uPrimColor.a);\n");
                        break;
                    case CCMUX_SHADE_ALPHA : // 11
                        strcat(newFrgStr, "CColor = vec3(vertexShadeColor.a);\n");
                        break;
                    case CCMUX_ENV_ALPHA : // 12
                        strcat(newFrgStr, "CColor = vec3(uEnvColor.a);\n");
                        break;
                    case CCMUX_LOD_FRACTION : // 13
                        strcat(newFrgStr, "CColor = vec3(uLodFrac);\n");
                        break;
                    case CCMUX_PRIM_LOD_FRAC : // 14
                        strcat(newFrgStr, "CColor = vec3(uPrimLodFrac);\n");
                        break;
                    case CCMUX_K5 : // 15
                        strcat(newFrgStr, "CColor = vec3(uK5);\n");
                        break;
                    case CCMUX_0 : // 16
                    default: // everything > CCMUX_0 (16) is 0
                        strcat(newFrgStr, "CColor = vec3(0.0, 0.0, 0.0);\n");
                        break;
                }

                // D0 (Cycle 2)
                switch( m_sources[CS_COLOR_D1] )
                {
                    case CCMUX_COMBINED : // 0
                        strcat(newFrgStr, "DColor = cycle1Color;\n");
                        break;
                    case CCMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "DColor = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).rgb;\n");
                        break;
                    case CCMUX_TEXEL1 :// 2
                        strcat(newFrgStr, "DColor = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).rgb;\n");
                        break;
                    case CCMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "DColor = uPrimColor.rgb;\n");
                        break;
                    case CCMUX_SHADE : // 4
                        strcat(newFrgStr, "DColor = vertexShadeColor.rgb;\n");
                        break;
                    case CCMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "DColor = uEnvColor.rgb;\n");
                        break;
                    case CCMUX_1 : // 6
                        strcat(newFrgStr, "DColor = vec3(1.0, 1.0, 1.0);\n");
                        break;
                    case CCMUX_0 : // 7
                    default: // everything > CCMUX_0 (7) is 0
                        strcat(newFrgStr, "DColor = vec3(0.0, 0.0, 0.0);\n");
                        break;
                }

                ////////////////////////////////////////////////////////////////////////////
                // Alphas (float) Cycle 2
                ////////////////////////////////////////////////////////////////////////////

                // a0 (Cycle 2) (same than b0 and c0 actually)
                switch( m_sources[CS_ALPHA_A1] )
                {
                    case ACMUX_COMBINED : // 0
                        strcat(newFrgStr, "AAlpha = cycle1Alpha;\n");
                        break;
                    case ACMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "AAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
                        break;
                    case ACMUX_TEXEL1 : // 2
                        strcat(newFrgStr, "AAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
                        break;
                    case ACMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "AAlpha = uPrimColor.a;\n");
                        break;
                    case ACMUX_SHADE : // 4
                        strcat(newFrgStr, "AAlpha = vertexShadeColor.a;\n");
                        break;
                    case ACMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "AAlpha = uEnvColor.a;\n");
                        break;
                    case ACMUX_1 : // 6
                        strcat(newFrgStr, "AAlpha = 1.0;\n");
                        break;
                    case ACMUX_0 : // 7
                    default: // everything > CCMUX_0 (7) is 0
                        strcat(newFrgStr, "AAlpha = 0.0;\n");
                        break;
                }

                // b0 (Cycle 2) (same than a0 and c0 actually)
                switch( m_sources[CS_ALPHA_B1] )
                {
                    case ACMUX_COMBINED : // 0
                        strcat(newFrgStr, "BAlpha = cycle1Alpha;\n");
                        break;
                    case ACMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "BAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
                        break;
                    case ACMUX_TEXEL1 : // 2
                        strcat(newFrgStr, "BAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
                        break;
                    case ACMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "BAlpha = uPrimColor.a;\n");
                        break;
                    case ACMUX_SHADE : // 4
                        strcat(newFrgStr, "BAlpha = vertexShadeColor.a;\n");
                        break;
                    case ACMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "BAlpha = uEnvColor.a;\n");
                        break;
                    case ACMUX_1 : // 6
                        strcat(newFrgStr, "BAlpha = 1.0;\n");
                        break;
                    case ACMUX_0 : // 7
                    default: // everything > CCMUX_0 (7) is 0
                        strcat(newFrgStr, "BAlpha = 0.0;\n");
                        break;
                }

                // c0 (Cycle 2) kind of "exotic"
                switch( m_sources[CS_ALPHA_C1] )
                {
                    case ACMUX_LOD_FRACTION : // 0
                        strcat(newFrgStr, "CAlpha = uLodFrac;\n");
                        break;
                    case ACMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "CAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
                        break;
                    case ACMUX_TEXEL1 : // 2
                        strcat(newFrgStr, "CAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
                        break;
                    case ACMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "CAlpha = uPrimColor.a;\n");
                        break;
                    case ACMUX_SHADE : // 4
                        strcat(newFrgStr, "CAlpha = vertexShadeColor.a;\n");
                        break;
                    case ACMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "CAlpha = uEnvColor.a;\n");
                        break;
                    case ACMUX_PRIM_LOD_FRAC : // 6
                        strcat(newFrgStr, "CAlpha = uPrimLodFrac;\n");
                        break;
                    case ACMUX_0 : // 7
                    default: // everything > CCMUX_0 (7) is 0
                        strcat(newFrgStr, "CAlpha = 0.0;\n");
                        break;
                }

                // d0 (Cycle 2) (same than a0 and b0 actually)
                switch( m_sources[CS_ALPHA_D1] )
                {
                    case ACMUX_COMBINED : // 0
                        strcat(newFrgStr, "DAlpha = cycle1Alpha;\n");
                        break;
                    case ACMUX_TEXEL0 : // 1
                        strcat(newFrgStr, "DAlpha = SAMPLE_TEXTURE(uTex0,vertexTexCoord0).a;\n");
                        break;
                    case ACMUX_TEXEL1 : // 2
                        strcat(newFrgStr, "DAlpha = SAMPLE_TEXTURE(uTex1,vertexTexCoord1).a;\n");
                        break;
                    case ACMUX_PRIMITIVE : // 3
                        strcat(newFrgStr, "DAlpha = uPrimColor.a;\n");
                        break;
                    case ACMUX_SHADE : // 4
                        strcat(newFrgStr, "DAlpha = vertexShadeColor.a;\n");
                        break;
                    case ACMUX_ENVIRONMENT : // 5
                        strcat(newFrgStr, "DAlpha = uEnvColor.a;\n");
                        break;
                    case ACMUX_1 : // 6
                        strcat(newFrgStr, "DAlpha = 1.0;\n");
                        break;
                    case ACMUX_0 : // 7
                    default: // everything > CCMUX_0 (7) is 0
                        strcat(newFrgStr, "DAlpha = 0.0;\n");
                        break;
                }
                strcat(newFrgStr, "outColor.rgb = (AColor - BColor) * CColor + DColor;\n");
                strcat(newFrgStr, "outColor.a = (AAlpha - BAlpha) * CAlpha + DAlpha;\n");
                //strcat(newFrgStr, "outColor.rgb = cycle1Color;\n");
                //strcat(newFrgStr, "outColor.a = cycle1Alpha;\n");
                break;
            }
        } // end case CYCLE_TYPE_2
        case CYCLE_TYPE_COPY :
        case CYCLE_TYPE_FILL :
        default :
            // TODO?
            break;
    } // end switch cycle type

    //strcat(newFrgStr, "outColor.rgb = vec3(greaterThan(outColor.rgb, vec3(1.0)));\n");

    genFragmentBlenderStr( newFrgStr );
    strcat( newFrgStr, fragmentShaderFooter ); // (always the same)

    ////////////////////////////////////////////////////////////////////////////
    // Create the program
    ////////////////////////////////////////////////////////////////////////////
    GLuint frgShader = createShader( GL_FRAGMENT_SHADER, newFrgStr );

    GLuint program = createProgram( m_vtxShader, frgShader );

    glDeleteShader(frgShader); OPENGL_CHECK_ERRORS

    ////////////////////////////////////////////////////////////////////////////
    // Generate and store the save ype
    ////////////////////////////////////////////////////////////////////////////
    ShaderSaveType saveType;

    saveType.combineMode1  = m_combineMode1;
    saveType.combineMode2  = m_combineMode2;
    saveType.cycle_type    = gRDP.otherMode.cycle_type;
    saveType.key_enabled   = gRDP.otherMode.key_en;
    //saveType.blender       = gRDP.otherMode.blender;
    saveType.alpha_compare = gRDP.otherMode.alpha_compare;
    saveType.aa_en         = gRDP.otherMode.aa_en;
    //saveType.z_cmp         = gRDP.otherMode.z_cmp;
    //saveType.z_upd         = gRDP.otherMode.z_upd;
    saveType.alpha_cvg_sel = gRDP.otherMode.alpha_cvg_sel;
    saveType.cvg_x_alpha   = gRDP.otherMode.cvg_x_alpha;
    //saveType.clr_on_cvg    = gRDP.otherMode.clr_on_cvg;
    //saveType.cvg_dst       = gRDP.otherMode.cvg_dst;
    saveType.fog_enabled   = gRSP.bFogEnabled;
    saveType.fog_in_blender = gRDP.bFogEnableInBlender;
    saveType.program       = program;

    StoreUniformLocations( saveType );

    m_generatedPrograms.push_back( saveType );

    return m_generatedPrograms.size()-1; // id of the shader save type
}

GLuint COGLColorCombiner::GenerateCopyProgram()
{
    assert( gRDP.otherMode.cycle_type == CYCLE_TYPE_COPY );
    assert( m_vtxShader != CC_NULL_SHADER );

    writeFragmentShaderHeader();
    strcat(newFrgStr, fragmentCopyHeader);   // (always the same)
    genFragmentBlenderStr(newFrgStr);
    strcat(newFrgStr, fragmentShaderFooter); // (always the same)

    ////////////////////////////////////////////////////////////////////////////
    // Create the program
    ////////////////////////////////////////////////////////////////////////////
    GLuint frgShader = createShader( GL_FRAGMENT_SHADER, newFrgStr );

    GLuint program = createProgram( m_vtxShader, frgShader );

    glDeleteShader(frgShader); OPENGL_CHECK_ERRORS

    ////////////////////////////////////////////////////////////////////////////
    // Generate and store the save type
    ////////////////////////////////////////////////////////////////////////////
    ShaderSaveType saveType;

    // (as it a copy shader, only blender values are saved)
    saveType.cycle_type    = gRDP.otherMode.cycle_type;
    saveType.alpha_compare = gRDP.otherMode.alpha_compare;
    saveType.aa_en         = gRDP.otherMode.aa_en;
    //saveType.z_cmp         = gRDP.otherMode.z_cmp;
    //saveType.z_upd         = gRDP.otherMode.z_upd;
    saveType.alpha_cvg_sel = gRDP.otherMode.alpha_cvg_sel;
    saveType.cvg_x_alpha   = gRDP.otherMode.cvg_x_alpha;
    saveType.fog_enabled   = gRSP.bFogEnabled;
    saveType.fog_in_blender = gRDP.bFogEnableInBlender;
    saveType.program       = program;

    StoreUniformLocations( saveType );

    m_generatedPrograms.push_back( saveType );

    return m_generatedPrograms.size()-1;
}

// Set vertex attribute pointers.
// The program must be bind before use this.
void COGLColorCombiner::GenerateCombinerSetting()
{
    glEnableVertexAttribArray(VS_POSITION);
    OPENGL_CHECK_ERRORS;
    glVertexAttribPointer(VS_POSITION,4,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][0]));
    OPENGL_CHECK_ERRORS;

    glEnableVertexAttribArray(VS_TEXCOORD0);
    OPENGL_CHECK_ERRORS;
    glVertexAttribPointer(VS_TEXCOORD0,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[0].u));
    OPENGL_CHECK_ERRORS;

    glEnableVertexAttribArray(VS_TEXCOORD1);
    OPENGL_CHECK_ERRORS;
    glVertexAttribPointer(VS_TEXCOORD1,2,GL_FLOAT,GL_FALSE, sizeof( TLITVERTEX ), &(g_vtxBuffer[0].tcord[1].u));
    OPENGL_CHECK_ERRORS;

    glEnableVertexAttribArray(VS_COLOR);
    OPENGL_CHECK_ERRORS;
    glVertexAttribPointer(VS_COLOR, 4, GL_UNSIGNED_BYTE,GL_TRUE, sizeof(uint8)*4, &(g_oglVtxColors[0][0]) );
    OPENGL_CHECK_ERRORS;

    glEnableVertexAttribArray(VS_FOG);
    OPENGL_CHECK_ERRORS;
    glVertexAttribPointer(VS_FOG,1,GL_FLOAT,GL_FALSE,sizeof(float)*5,&(g_vtxProjected5[0][4]));
    OPENGL_CHECK_ERRORS;
}

// Bind various uniforms
void COGLColorCombiner::GenerateCombinerSettingConstants( int shaderId )
{
    assert( shaderId >= 0 );

    const ShaderSaveType &saveType = m_generatedPrograms[ shaderId ];

    // Vertex shader
    if( saveType.fogMaxMinLoc != CC_INACTIVE_UNIFORM ) {
        glUniform2f( saveType.fogMaxMinLoc, gRSPfFogMin ,
                                             gRSPfFogMax );
        OPENGL_CHECK_ERRORS;
    }

    // Fragment shader
    if(    saveType.blendColorLoc != CC_INACTIVE_UNIFORM ) {
        glUniform4f( saveType.blendColorLoc, gRDP.fvBlendColor[0],
                                              gRDP.fvBlendColor[1],
                                              gRDP.fvBlendColor[2],
                                              gRDP.fvBlendColor[3]);
        OPENGL_CHECK_ERRORS
    }
    if(    saveType.primColorLoc != CC_INACTIVE_UNIFORM ) {
        glUniform4f( saveType.primColorLoc, gRDP.fvPrimitiveColor[0],
                                             gRDP.fvPrimitiveColor[1],
                                             gRDP.fvPrimitiveColor[2],
                                             gRDP.fvPrimitiveColor[3]);
        OPENGL_CHECK_ERRORS
    }

    if( saveType.envColorLoc != CC_INACTIVE_UNIFORM ) {
        glUniform4f( saveType.envColorLoc, gRDP.fvEnvColor[0],
                                            gRDP.fvEnvColor[1],
                                            gRDP.fvEnvColor[2],
                                            gRDP.fvEnvColor[3]);
        OPENGL_CHECK_ERRORS
    }

    if( saveType.chromaKeyCenterLoc != CC_INACTIVE_UNIFORM ) {
        glUniform3f( saveType.chromaKeyCenterLoc, gRDP.keyCenterR/255.0f,
                                                   gRDP.keyCenterG/255.0f,
                                                   gRDP.keyCenterB/255.0f);
        OPENGL_CHECK_ERRORS
    }

    if( saveType.chromaKeyScaleLoc != CC_INACTIVE_UNIFORM ) {
        glUniform3f( saveType.chromaKeyScaleLoc, gRDP.keyScaleR/255.0f,
                                                  gRDP.keyScaleG/255.0f,
                                                  gRDP.keyScaleB/255.0f);
        OPENGL_CHECK_ERRORS
    }

    if( saveType.chromaKeyWidthLoc != CC_INACTIVE_UNIFORM ) {
        glUniform3f( saveType.chromaKeyWidthLoc, gRDP.keyWidthR/255.0f,
                                                  gRDP.keyWidthG/255.0f,
                                                  gRDP.keyWidthB/255.0f);
        OPENGL_CHECK_ERRORS
    }

    if( saveType.lodFracLoc != CC_INACTIVE_UNIFORM ) {
        glUniform1f( saveType.lodFracLoc, gRDP.LODFrac/255.0f );
        OPENGL_CHECK_ERRORS
    }

    if( saveType.primLodFracLoc != CC_INACTIVE_UNIFORM ) {
        glUniform1f( saveType.primLodFracLoc, gRDP.primLODFrac/255.0f );
        OPENGL_CHECK_ERRORS
    }

    if( saveType.k5Loc != CC_INACTIVE_UNIFORM ) {
        glUniform1f( saveType.k5Loc, gRDP.K5/255.0f );
        OPENGL_CHECK_ERRORS
    }

    if( saveType.k4Loc != CC_INACTIVE_UNIFORM ) {
        glUniform1f( saveType.k4Loc, gRDP.K4/255.0f );
        OPENGL_CHECK_ERRORS
    }

    if( saveType.tex0Loc != CC_INACTIVE_UNIFORM ) {
        glUniform1i( saveType.tex0Loc,0 );
        OPENGL_CHECK_ERRORS
    }

    if( saveType.tex1Loc != CC_INACTIVE_UNIFORM ) {
        glUniform1i( saveType.tex1Loc,1 );
        OPENGL_CHECK_ERRORS
    }

    if( saveType.fogColorLoc != CC_INACTIVE_UNIFORM ) {
        glUniform4f( saveType.fogColorLoc, gRDP.fvFogColor[0],
                                            gRDP.fvFogColor[1],
                                            gRDP.fvFogColor[2],
                                            gRDP.fvFogColor[3]);
        OPENGL_CHECK_ERRORS;
    }
}

//////////////////////////////////////////////////////////////////////////
void COGLColorCombiner::InitCombinerCycle12(void)
{
    // Look if we already have a compiled program for the current state.
    int shaderId = FindCompiledShaderId();

    if( shaderId == -1 ) {
        shaderId = GenerateCycle12Program();
    }

    const GLuint &program = m_generatedPrograms[shaderId].program;
    useProgram( program );

    GenerateCombinerSettingConstants( shaderId );
    GenerateCombinerSetting();
    
    m_pOGLRender->SetAllTexelRepeatFlag();
}

// Store every uniform locations on the given shader
// We don't know if every of them are used in the program so some of them will return -1 but we don't care
// Note: glGetUniformLocation doesn't need glUseProgram to work.
void COGLColorCombiner::StoreUniformLocations( ShaderSaveType &saveType )
{
    assert( saveType.program != CC_NULL_PROGRAM );

    saveType.fogMaxMinLoc       = glGetUniformLocation( saveType.program, "uFogMinMax"       );
    saveType.blendColorLoc      = glGetUniformLocation( saveType.program, "uBlendColor"      );
    saveType.primColorLoc       = glGetUniformLocation( saveType.program, "uPrimColor"       );
    saveType.envColorLoc        = glGetUniformLocation( saveType.program, "uEnvColor"        );
    saveType.chromaKeyCenterLoc = glGetUniformLocation( saveType.program, "uChromaKeyCenter" );
    saveType.chromaKeyScaleLoc  = glGetUniformLocation( saveType.program, "uChromaKeyScale"  );
    saveType.chromaKeyWidthLoc  = glGetUniformLocation( saveType.program, "uChromaKeyWidth"  );
    saveType.lodFracLoc         = glGetUniformLocation( saveType.program, "uLodFrac"         );
    saveType.primLodFracLoc     = glGetUniformLocation( saveType.program, "uPrimLodFrac"     );
    saveType.k5Loc              = glGetUniformLocation( saveType.program, "uK5"              );
    saveType.k4Loc              = glGetUniformLocation( saveType.program, "uK4"              );
    saveType.tex0Loc            = glGetUniformLocation( saveType.program, "uTex0"            );
    saveType.tex1Loc            = glGetUniformLocation( saveType.program, "uTex1"            );
    saveType.fogColorLoc        = glGetUniformLocation( saveType.program, "uFogColor"        );
}

// Return a shader id that match the current state in the current compiled shader "database".
// Return -1 if no shader is found
int COGLColorCombiner::FindCompiledShaderId()
{
    int shaderId = -1;
    ShaderSaveType* saveType = NULL;
    for( size_t i=0; i<m_generatedPrograms.size(); i++ )
    {
        saveType = &m_generatedPrograms[i];
        switch( gRDP.otherMode.cycle_type ) {
            case CYCLE_TYPE_1 :
            case CYCLE_TYPE_2 :
                if(    saveType->combineMode1  == m_combineMode1
                    && saveType->combineMode2  == m_combineMode2
                    && saveType->cycle_type    == gRDP.otherMode.cycle_type // 1 or 2?
                    && saveType->key_enabled   == gRDP.otherMode.key_en
                    // Blender
                    && saveType->alpha_compare == gRDP.otherMode.alpha_compare
                    && saveType->aa_en         == gRDP.otherMode.aa_en
                    //&& saveType->z_cmp         == gRDP.otherMode.z_cmp
                    //&& saveType->z_upd         == gRDP.otherMode.z_upd
                    && saveType->alpha_cvg_sel == gRDP.otherMode.alpha_cvg_sel
                    && saveType->cvg_x_alpha   == gRDP.otherMode.cvg_x_alpha
                    && saveType->fog_enabled   == gRSP.bFogEnabled
                    && saveType->fog_in_blender == gRDP.bFogEnableInBlender
                    ) shaderId = i;
                break;
            case CYCLE_TYPE_COPY : // don't care about Color Combiner stuff, just Blender
                 if(   saveType->cycle_type    == CYCLE_TYPE_COPY
                    && saveType->alpha_compare == gRDP.otherMode.alpha_compare
                    && saveType->aa_en         == gRDP.otherMode.aa_en
                    //&& saveType->z_cmp         == gRDP.otherMode.z_cmp
                    //&& saveType->z_upd         == gRDP.otherMode.z_upd
                    && saveType->alpha_cvg_sel == gRDP.otherMode.alpha_cvg_sel
                    && saveType->cvg_x_alpha   == gRDP.otherMode.cvg_x_alpha
                    && saveType->fog_enabled   == gRSP.bFogEnabled
                    && saveType->fog_in_blender == gRDP.bFogEnableInBlender
                    ) shaderId = i;
                break;
            case CYCLE_TYPE_FILL :
                DebugMessage(M64MSG_WARNING, "Lookup for a cycle type Fill shader. It should never happend.");
                break;
            default :
                DebugMessage(M64MSG_WARNING, "Lookup for a unknown cycle type. It should never happend.");
                break;
        } // end switch cycle type
    } // end loop

    return shaderId;
}

// Can save a useless OpenGL program switch.
void COGLColorCombiner::useProgram( const GLuint &program )
{
    if( program != m_currentProgram ) {
        glUseProgram( program );
        OPENGL_CHECK_ERRORS
        m_currentProgram = program;
    }
}

// COGLBlender

void COGLBlender::NormalAlphaBlender(void)
{
    glEnable(GL_BLEND);
    OPENGL_CHECK_ERRORS;
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    OPENGL_CHECK_ERRORS;
}

void COGLBlender::DisableAlphaBlender(void)
{
    glEnable(GL_BLEND);
    OPENGL_CHECK_ERRORS;
    glBlendFunc(GL_ONE, GL_ZERO);
    OPENGL_CHECK_ERRORS;
}


void COGLBlender::BlendFunc(uint32 srcFunc, uint32 desFunc)
{
    glBlendFunc(DirectX_OGL_BlendFuncMaps[srcFunc], DirectX_OGL_BlendFuncMaps[desFunc]);
    OPENGL_CHECK_ERRORS;
}

void COGLBlender::Enable()
{
    glEnable(GL_BLEND);
    OPENGL_CHECK_ERRORS;
}

void COGLBlender::Disable()
{
    glDisable(GL_BLEND);
    OPENGL_CHECK_ERRORS;
}

void COGLColorCombiner::InitCombinerBlenderForSimpleTextureDraw(uint32 tile)
{
    if( g_textures[tile].m_pCTexture )
    {
        m_pOGLRender->EnableTexUnit(0,TRUE);
        glBindTexture(GL_TEXTURE_2D, ((COGLTexture*)(g_textures[tile].m_pCTexture))->m_dwTextureName);
        OPENGL_CHECK_ERRORS;
    }
    m_pOGLRender->SetAllTexelRepeatFlag();

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    OPENGL_CHECK_ERRORS;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    OPENGL_CHECK_ERRORS;
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR); // Linear Filtering
    OPENGL_CHECK_ERRORS;
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR); // Linear Filtering
    OPENGL_CHECK_ERRORS;

    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    OPENGL_CHECK_ERRORS;
    m_pOGLRender->SetAlphaTestEnable(FALSE);
}

