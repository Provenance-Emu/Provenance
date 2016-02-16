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

#include "OGLDebug.h"
#include "OGLES2FragmentShaders.h"
#include "OGLGraphicsContext.h"
#include "OGLRender.h"
#include "OGLTexture.h"

#define ALPHA_TEST "    if(gl_FragColor.a < AlphaRef) discard;       \n"

GLuint vertexProgram = 9999;
const char *vertexShader =
"#version " GLSL_VERSION                                   "\n"\
"attribute mediump vec4 aPosition;                          \n"\
"attribute lowp vec4    aColor;                             \n"\
"attribute lowp vec2    aTexCoord0;                         \n"\
"attribute lowp vec2    aTexCoord1;                         \n"\
"attribute lowp vec2    aAtlasTransform;                    \n"\
"attribute mediump float aFogCoord;                         \n"\
"                                                           \n"\
"uniform vec2 FogMinMax;                                    \n"\
"                                                           \n"\
"varying lowp vec4  vShadeColor;                            \n"\
"varying mediump vec2 vTexCoord0;                           \n"\
"varying lowp vec2    vTexCoord1;                           \n"\
"varying lowp float   vFog;                                 \n"\
"                                                           \n"\
"void main()                                                \n"\
"{                                                          \n"\
"gl_Position = aPosition;                                   \n"\
"vShadeColor = aColor;                                      \n"\
"vTexCoord0 = aTexCoord0;                                   \n"\
"vTexCoord1 = aTexCoord1;                                   \n"\
"vFog = (FogMinMax[1] - aFogCoord) / (FogMinMax[1] - FogMinMax[0]);  \n"\
"vFog = clamp(vFog, 0.0, 1.0);                              \n"\
"}                                                          \n"\
"                                                           \n";

const char *fragmentHeader =
"#define saturate(x) clamp( x, 0.0, 1.0 )                   \n"\
"precision lowp float;                                      \n"\
"#ifdef NEED_TEX0                                           \n"\
"uniform sampler2D uTex0;                                   \n"\
"#endif                                                     \n"\
"                                                           \n"\
"#ifdef NEED_TEX1                                           \n"\
"uniform sampler2D uTex1;                                   \n"\
"#endif                                                     \n"\
"                                                           \n"\
"uniform vec4 EnvColor;                                     \n"\
"uniform vec4 PrimColor;                                    \n"\
"uniform vec4 EnvFrac;                                      \n"\
"uniform vec4 PrimFrac;                                     \n"\
"uniform float AlphaRef;                                    \n"\
"uniform vec4 FogColor;                                     \n"\
"                                                           \n"\
"varying lowp vec4  vShadeColor;                            \n"\
"varying mediump vec2  vTexCoord0;                          \n"\
"varying lowp vec2  vTexCoord1;                             \n"\
"varying lowp float vFog;                                   \n"\
"                                                           \n"\
"void main()                                                \n"\
"{                                                          \n"\
"vec4 comb,comb2;                                           \n"\
"                                                           \n"\
"#ifdef NEED_TEX0                                           \n"\
"vec4 t0 = texture2D(uTex0,vTexCoord0);                     \n"\
"#endif                                                     \n"\
"                                                           \n"\
"#ifdef NEED_TEX1                                           \n"\
"vec4 t1 = texture2D(uTex1,vTexCoord1);                     \n"\
"#endif                                                     \n";

const char *fragmentFooter =
"                                                           \n"\
"#ifdef FOG                                                 \n"\
"gl_FragColor.rgb = mix(FogColor.rgb,comb.rgb,vFog);        \n"\
"gl_FragColor.a = comb.a;                                   \n"\
"#else                                                      \n"\
"gl_FragColor = comb;                                       \n"\
"#endif                                                     \n"\
"                                                           \n"\
"#ifdef ALPHA_TEST                                          \n"\
ALPHA_TEST
"#endif                                                     \n"\
"}                                                          \n";

//Fragment shader for InitCycleCopy
const char *fragmentCopy =
"#version " GLSL_VERSION "\n"\
"precision lowp float;                                      \n"\
"uniform sampler2D uTex0;                                   \n"\
"uniform float AlphaRef;                                    \n"\
"varying lowp vec2 vTexCoord0;                              \n"\
"void main()                                                \n"\
"{                                                          \n"\
"   gl_FragColor = texture2D(uTex0,vTexCoord0).bgra;        \n"\
ALPHA_TEST
"}";

GLuint copyProgram,copyAlphaLocation;

//Fragment shader for InitCycleFill
const char *fragmentFill =
"#version " GLSL_VERSION "\n"\
"precision lowp float;                                      \n"
"uniform vec4 uColor;                                       \n"
"void main()                                                \n"
"{                                                          \n"
"   gl_FragColor = uColor;                                  \n"
"}";

GLuint fillProgram,fillColorLocation;

COGL_FragmentProgramCombiner::COGL_FragmentProgramCombiner(CRender *pRender)
: COGLColorCombiner4(pRender)
{
    delete m_pDecodedMux;
    m_pDecodedMux = new DecodedMuxForPixelShader;
    m_bFragmentProgramIsSupported = true;
    m_AlphaRef = 0.0f;
    bAlphaTestState = false;
    bAlphaTestPreviousState = false;
    bFogState = false;
    bFogPreviousState = false;

    //Create shaders for fill and copy
    GLint success;
    GLuint vs,fs;
    copyProgram = glCreateProgram();
    vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs,1,&vertexShader,NULL);
    glCompileShader(vs);

    glGetShaderiv(vs,GL_COMPILE_STATUS,&success);
    if(!success)
    {
        char log[1024];
        glGetShaderInfoLog(vs,1024,NULL,log);
        printf("%s\n",log);
    }

    fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs,1,&fragmentCopy,NULL);
    glCompileShader(fs);

    glGetShaderiv(fs,GL_COMPILE_STATUS,&success);
    if(!success)
    {
        char log[1024];
        glGetShaderInfoLog(fs,1024,NULL,log);
        printf("%s\n",log);
    }

    glAttachShader(copyProgram,vs);
    glAttachShader(copyProgram,fs);

    glBindAttribLocation(copyProgram,VS_TEXCOORD0,"aTexCoord0");
    OPENGL_CHECK_ERRORS;
    glBindAttribLocation(copyProgram,VS_POSITION,"aPosition");
    OPENGL_CHECK_ERRORS;

    glLinkProgram(copyProgram);
    copyAlphaLocation = glGetUniformLocation(copyProgram,"AlphaRef");
    glGetProgramiv(copyProgram,GL_LINK_STATUS,&success);
    if(!success)
    {
        char log[1024];
        glGetProgramInfoLog(copyProgram,1024,NULL,log);
        printf("%s\n",log);
    }

    glDeleteShader(fs);

    //Fill shader
    fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs,1,&fragmentFill,NULL);
    glCompileShader(fs);

    glGetShaderiv(fs,GL_COMPILE_STATUS,&success);
    if(!success)
    {
        char log[1024];
        glGetShaderInfoLog(fs,1024,NULL,log);
        printf("%s\n",log);
    }

    fillProgram = glCreateProgram();
    glAttachShader(fillProgram,vs);
    glAttachShader(fillProgram,fs);

    glBindAttribLocation(fillProgram,VS_POSITION,"aPosition");
    OPENGL_CHECK_ERRORS;

    glLinkProgram(fillProgram);


    fillColorLocation = glGetUniformLocation(fillProgram,"uColor");

    glDeleteShader(fs);
    glDeleteShader(vs);
}
COGL_FragmentProgramCombiner::~COGL_FragmentProgramCombiner()
{
    int size = m_vCompiledShaders.size();
    for (int i=0; i<size; i++)
    {
        GLuint ID = m_vCompiledShaders[i].programID;
        glDeleteProgram(ID);

        OPENGL_CHECK_ERRORS;
        m_vCompiledShaders[i].programID = 0;
    }

    m_vCompiledShaders.clear();
}

bool COGL_FragmentProgramCombiner::Initialize(void)
{
    if( !COGLColorCombiner4::Initialize() )
        return false;

    COGLGraphicsContext *pcontext = (COGLGraphicsContext *)(CGraphicsContext::g_pGraphicsContext);
//    if( pcontext->IsExtensionSupported("GL_fragment_program") )
//    {
        m_bFragmentProgramIsSupported = true;
//    }

    return true;
}



void COGL_FragmentProgramCombiner::DisableCombiner(void)
{
    //glDisable(GL_FRAGMENT_PROGRAM);
    //OPENGL_CHECK_ERRORS;
    COGLColorCombiner4::DisableCombiner();
}

void COGL_FragmentProgramCombiner::InitCombinerCycleCopy(void)
{
    m_pOGLRender->DisableMultiTexture();
    m_pOGLRender->EnableTexUnit(0,TRUE);
    glUseProgram(copyProgram);
    glUniform1f(copyAlphaLocation,m_AlphaRef);
    OPENGL_CHECK_ERRORS;
    glEnableVertexAttribArray(VS_POSITION);
    OPENGL_CHECK_ERRORS;
    glEnableVertexAttribArray(VS_TEXCOORD0);
    OPENGL_CHECK_ERRORS;
    glDisableVertexAttribArray(VS_COLOR);
    OPENGL_CHECK_ERRORS;
    glDisableVertexAttribArray(VS_TEXCOORD1);
    OPENGL_CHECK_ERRORS;
    glDisableVertexAttribArray(VS_FOG);
    OPENGL_CHECK_ERRORS;
    COGLTexture* pTexture = g_textures[gRSP.curTile].m_pCOGLTexture;
    if( pTexture )
    {
        m_pOGLRender->BindTexture(pTexture->m_dwTextureName, 0);
        m_pOGLRender->SetTexelRepeatFlags(gRSP.curTile);
    }
}

void COGL_FragmentProgramCombiner::InitCombinerCycleFill(void)
{
    glUseProgram(fillProgram);
    glUniform4f(fillColorLocation,((gRDP.fillColor>>16)&0xFF)/255.0f,((gRDP.fillColor>>8)&0xFF)/255.0f,((gRDP.fillColor)&0xFF)/255.0f,((gRDP.fillColor>>24)&0xFF)/255.0f);
    OPENGL_CHECK_ERRORS;
}

#ifdef BGR_SHADER
const char *muxToFP_Maps[][2] = {
//color -- alpha
{"vec3(0.0)", "0.0"},                      //MUX_0 = 0,
{"vec3(1.0)", "1.0"},                      //MUX_1,
{"comb.rgb", "comb.a"},                    //MUX_COMBINED,
{"t0.rgb", "t0.a"},                        //MUX_TEXEL0,
{"t1.rgb", "t1.a"},                        //MUX_TEXEL1,
{"PrimColor.rgb", "PrimColor.a"},          //MUX_PRIM,
{"vShadeColor.rgb", "vShadeColor.a"},      //MUX_SHADE,
{"EnvColor.rgb", "EnvColor.a"},            //MUX_ENV,
{"comb.rgb", "comb.a"},                    //MUX_COMBALPHA,
{"t0.rgb", "t0.a"},                        //MUX_T0_ALPHA,
{"t1.rgb", "t1.a"},                        //MUX_T1_ALPHA,
{"PrimColor.rgb", "PrimColor.a"},          //MUX_PRIM_ALPHA,
{"vShadeColor.rgb", "vShadeColor.a"},      //MUX_SHADE_ALPHA,
{"EnvColor.rgb", "EnvColor.a"},            //MUX_ENV_ALPHA,
{"EnvFrac.a", "EnvFrac.a"},                //MUX_LODFRAC,
{"PrimFrac.a", "PrimFrac.a"},              //MUX_PRIMLODFRAC,
{"vec3(1.0)", "1.0"},                      //MUX_K5,
{"vec3(1.0)", "1.0"},                      //MUX_UNK,  // Should not be used
};
#else
const char *muxToFP_Maps[][2] = {
//color -- alpha
{"vec3(0.0)", "0.0"}, //MUX_0 = 0,
{"vec3(1.0)", "1.0"}, //MUX_1,
{"comb.rgb", "comb.a"}, //MUX_COMBINED,
{"t0.bgr", "t0.a"}, //MUX_TEXEL0,
{"t1.bgr", "t1.a"}, //MUX_TEXEL1,
{"PrimColor.rgb", "PrimColor.a"}, //MUX_PRIM,
{"vShadeColor.rgb", "vShadeColor.a"}, //MUX_SHADE,
{"EnvColor.rgb", "EnvColor.a"}, //MUX_ENV,
{"comb.rgb", "comb.a"}, //MUX_COMBALPHA,
{"t0.bgr", "t0.a"}, //MUX_T0_ALPHA,
{"t1.bgr", "t1.a"}, //MUX_T1_ALPHA,
{"PrimColor.rgb", "PrimColor.a"}, //MUX_PRIM_ALPHA,
{"vShadeColor.rgb", "vShadeColor.a"}, //MUX_SHADE_ALPHA,
{"EnvColor.rgb", "EnvColor.a"}, //MUX_ENV_ALPHA,
{"EnvFrac.a", "EnvFrac.a"}, //MUX_LODFRAC,
{"PrimFrac.a", "PrimFrac.a"}, //MUX_PRIMLODFRAC,
{"vec3(1.0)", "1.0"}, //MUX_K5,
{"vec3(1.0)", "1.0"}, //MUX_UNK,  // Should not be used
};
#endif


char oglNewFP[4092];

char* MuxToOC(uint8 val)
{
// For color channel
if( val&MUX_ALPHAREPLICATE )
    return (char*)muxToFP_Maps[val&0x1F][1];
else
    return (char*)muxToFP_Maps[val&0x1F][0];
}

char* MuxToOA(uint8 val)
{
// For alpha channel
return (char*)muxToFP_Maps[val&0x1F][1];
}

static void CheckFpVars(uint8 MuxVar, bool &bNeedT0, bool &bNeedT1)
{
    MuxVar &= 0x1f;
    if (MuxVar == MUX_TEXEL0 || MuxVar == MUX_T0_ALPHA)
        bNeedT0 = true;
    if (MuxVar == MUX_TEXEL1 || MuxVar == MUX_T1_ALPHA)
        bNeedT1 = true;
}

void COGL_FragmentProgramCombiner::GenerateProgramStr()
{
    DecodedMuxForPixelShader &mux = *(DecodedMuxForPixelShader*)m_pDecodedMux;

    mux.splitType[0] = mux.splitType[1] = mux.splitType[2] = mux.splitType[3] = CM_FMT_TYPE_NOT_CHECKED;
    m_pDecodedMux->Reformat(false);

    char tempstr[500], newFPBody[4092];
    bool bNeedT0 = false, bNeedT1 = false, bNeedComb2 = false;
    newFPBody[0] = 0;

    for( int cycle=0; cycle<2; cycle++ )
    {
        for( int channel=0; channel<2; channel++)
        {
            char* (*func)(uint8) = channel==0?MuxToOC:MuxToOA;
            char *dst = channel==0?(char*)"rgb":(char*)"a";
            N64CombinerType &m = mux.m_n64Combiners[cycle*2+channel];
            switch( mux.splitType[cycle*2+channel] )
            {
            case CM_FMT_TYPE_NOT_USED:
                tempstr[0] = 0;
                break;
            case CM_FMT_TYPE_D:
                sprintf(tempstr, "comb.%s = %s;\n", dst, func(m.d));
                CheckFpVars(m.d, bNeedT0, bNeedT1);
                break;
            case CM_FMT_TYPE_A_MOD_C:
                sprintf(tempstr, "comb.%s = %s * %s;\n", dst, func(m.a), func(m.c));
                CheckFpVars(m.a, bNeedT0, bNeedT1);
                CheckFpVars(m.c, bNeedT0, bNeedT1);
                break;
            case CM_FMT_TYPE_A_ADD_D:
                sprintf(tempstr, "comb.%s = saturate(%s + %s);\n", dst, func(m.a), func(m.d));
                CheckFpVars(m.a, bNeedT0, bNeedT1);
                CheckFpVars(m.d, bNeedT0, bNeedT1);
                break;
            case CM_FMT_TYPE_A_SUB_B:
                sprintf(tempstr, "comb.%s = %s - %s;\n", dst, func(m.a), func(m.b));
                CheckFpVars(m.a, bNeedT0, bNeedT1);
                CheckFpVars(m.b, bNeedT0, bNeedT1);
                break;
            case CM_FMT_TYPE_A_MOD_C_ADD_D:
                sprintf(tempstr, "comb.%s = saturate(%s * %s + %s);\n", dst, func(m.a), func(m.c),func(m.d));
                CheckFpVars(m.a, bNeedT0, bNeedT1);
                CheckFpVars(m.c, bNeedT0, bNeedT1);
                CheckFpVars(m.d, bNeedT0, bNeedT1);
                break;
            case CM_FMT_TYPE_A_LERP_B_C:
                //ARB ASM LERP and mix have different parameter ordering.
                //sprintf(tempstr, "comb.%s = saturate(mix(%s, %s, %s));\n", dst,func(m.a),func(m.b), func(m.c));
                sprintf(tempstr, "comb.%s = (%s - %s) * %s + %s;\n", dst,func(m.a),func(m.b), func(m.c),func(m.b));
                CheckFpVars(m.a, bNeedT0, bNeedT1);
                CheckFpVars(m.b, bNeedT0, bNeedT1);
                CheckFpVars(m.c, bNeedT0, bNeedT1);
                //sprintf(tempstr, "SUB comb.%s, %s, %s;\nMAD_SAT comb.%s, comb, %s, %s;\n", dst, func(m.a), func(m.b), dst, func(m.c), func(m.b));
                break;
            default:
                sprintf(tempstr, "comb2.%s = %s - %s;\ncomb.%s = saturate(comb2.%s * %s + %s);\n", dst, func(m.a), func(m.b),  dst,dst, func(m.c),func(m.d));
                CheckFpVars(m.a, bNeedT0, bNeedT1);
                CheckFpVars(m.b, bNeedT0, bNeedT1);
                CheckFpVars(m.c, bNeedT0, bNeedT1);
                CheckFpVars(m.d, bNeedT0, bNeedT1);
                bNeedComb2 = true;
                break;
            }
            strcat(newFPBody, tempstr);
        }
    }

    oglNewFP[0] = 0;
    if (bNeedT0)
        strcat(oglNewFP, "#define NEED_TEX0\n");
    if (bNeedT1)
        strcat(oglNewFP, "#define NEED_TEX1\n");
    strcat(oglNewFP, fragmentHeader);
    strcat(oglNewFP, newFPBody);
    strcat(oglNewFP, fragmentFooter);

}

int COGL_FragmentProgramCombiner::ParseDecodedMux()
{
    if( !m_bFragmentProgramIsSupported )
        return COGLColorCombiner4::ParseDecodedMux();

    OGLShaderCombinerSaveType res;
    GLint success;

    if(vertexProgram == 9999)
    {
        vertexProgram = res.vertexShaderID = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(res.vertexShaderID, 1, &vertexShader,NULL);
        OPENGL_CHECK_ERRORS;
        glCompileShader(res.vertexShaderID);
        OPENGL_CHECK_ERRORS;
    }
    else
    {
        res.vertexShaderID = vertexProgram;
    }


    //Create 4 shaders, with and without alphatest + with and without fog
    GenerateProgramStr();

    for(int alphaTest = 0;alphaTest < 2;alphaTest++)
    {
        for(int fog = 0;fog < 2;fog++)
        {
        res.fragmentShaderID = glCreateShader(GL_FRAGMENT_SHADER);

        char* tmpShader = (char*)malloc(sizeof(char) * 4096);
        strcpy(tmpShader,"#version " GLSL_VERSION "\n");

        if(alphaTest == 1)
        {
            strcat(tmpShader,"#define ALPHA_TEST\n");
        }

        if (fog == 1)
        {
            strcat(tmpShader,"#define FOG\n");
        }

        res.fogIsUsed = fog == 1;
        res.alphaTest = alphaTest == 1;
        strcat(tmpShader,oglNewFP);

        glShaderSource(res.fragmentShaderID, 1,(const char**) &tmpShader,NULL);
        free(tmpShader);


        OPENGL_CHECK_ERRORS;
        glCompileShader(res.fragmentShaderID);

        glGetShaderiv(res.fragmentShaderID, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            char Log[1024];
            GLint nLength;
            glGetShaderInfoLog(res.fragmentShaderID, 1024, &nLength, Log);
            printf("Error compiling shader!\n %s",oglNewFP);
            printf("%s", Log);
        }

        res.programID = glCreateProgram();
        glAttachShader(res.programID,res.vertexShaderID);
        glAttachShader(res.programID,res.fragmentShaderID);

        //Bind Attributes
        glBindAttribLocation(res.programID,VS_COLOR,"aColor");
        OPENGL_CHECK_ERRORS;
        glBindAttribLocation(res.programID,VS_TEXCOORD0,"aTexCoord0");
        OPENGL_CHECK_ERRORS;
        glBindAttribLocation(res.programID,VS_TEXCOORD1,"aTexCoord1");
        OPENGL_CHECK_ERRORS;
        glBindAttribLocation(res.programID,VS_POSITION,"aPosition");
        OPENGL_CHECK_ERRORS;
        glBindAttribLocation(res.programID,VS_FOG,"aFogCoord");
        OPENGL_CHECK_ERRORS;

        glLinkProgram(res.programID);
        OPENGL_CHECK_ERRORS;

        glGetProgramiv(res.programID, GL_LINK_STATUS, &success);
        if (!success)
        {
            char Log[1024];
            GLint nLength;
            glGetShaderInfoLog(res.fragmentShaderID, 1024, &nLength, Log);
            printf("Error linking program!\n");
            printf("%s\n",Log);
        }

        glUseProgram(res.programID);
        OPENGL_CHECK_ERRORS;

        //Bind texture samplers
        GLint tex0 = glGetUniformLocation(res.programID,"uTex0");
        GLint tex1 = glGetUniformLocation(res.programID,"uTex1");

        if(tex0 != -1)
            glUniform1i(tex0,0);
        if(tex1 != -1)
            glUniform1i(tex1,1);

        //Bind Uniforms
        res.PrimColorLocation = glGetUniformLocation(res.programID,"PrimColor");
        OPENGL_CHECK_ERRORS;
        res.EnvColorLocation = glGetUniformLocation(res.programID,"EnvColor");
        OPENGL_CHECK_ERRORS;
        res.PrimFracLocation = glGetUniformLocation(res.programID,"PrimFrac");
        OPENGL_CHECK_ERRORS;
        res.EnvFracLocation = glGetUniformLocation(res.programID,"EnvFrac");
        OPENGL_CHECK_ERRORS;
        res.AlphaRefLocation = glGetUniformLocation(res.programID,"AlphaRef");
        OPENGL_CHECK_ERRORS;
        res.FogColorLocation = glGetUniformLocation(res.programID,"FogColor");
        OPENGL_CHECK_ERRORS;
        res.FogMinMaxLocation = glGetUniformLocation(res.programID,"FogMinMax");
        OPENGL_CHECK_ERRORS;

        res.dwMux0 = m_pDecodedMux->m_dwMux0;
        res.dwMux1 = m_pDecodedMux->m_dwMux1;

        m_vCompiledShaders.push_back(res);
    }
    }
    m_lastIndex = m_vCompiledShaders.size()-4;

    return m_lastIndex;
}

void COGL_FragmentProgramCombiner::GenerateCombinerSetting(int index)
{
    GLuint ID = m_vCompiledShaders[index].programID;

    glUseProgram(ID);
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

void COGL_FragmentProgramCombiner::GenerateCombinerSettingConstants(int index)
{
    OGLShaderCombinerSaveType prog = m_vCompiledShaders[index];

    glUseProgram(prog.programID);
    float *pf;
    if(prog.EnvColorLocation != -1)
    {
        pf = GetEnvColorfv();
        glUniform4fv(prog.EnvColorLocation,1, pf);
        OPENGL_CHECK_ERRORS;
    }

    if(prog.PrimColorLocation != -1)
    {
        pf = GetPrimitiveColorfv();
        glUniform4fv(prog.PrimColorLocation,1, pf);
        OPENGL_CHECK_ERRORS;
    }

    if(prog.EnvFracLocation != -1)
    {
        float frac = gRDP.LODFrac / 255.0f;
        float tempf[4] = {frac,frac,frac,frac};
        glUniform4fv(prog.EnvFracLocation,1, tempf);
        OPENGL_CHECK_ERRORS;
    }

    if(prog.PrimFracLocation != -1)
    {
        float frac2 = gRDP.primLODFrac / 255.0f;
        float tempf2[4] = {frac2,frac2,frac2,frac2};
        glUniform4fv(prog.PrimFracLocation,1, tempf2);
        OPENGL_CHECK_ERRORS;
    }

    if(prog.FogColorLocation != -1)
    {
        glUniform4f(prog.FogColorLocation, gRDP.fvFogColor[0],gRDP.fvFogColor[1],gRDP.fvFogColor[2], gRDP.fvFogColor[3]);
        OPENGL_CHECK_ERRORS;
    }

    if(prog.FogMinMaxLocation != -1)
    {
        glUniform2f(prog.FogMinMaxLocation,gRSPfFogMin,gRSPfFogMax);
        OPENGL_CHECK_ERRORS;
    }

    if(prog.AlphaRefLocation != -1)
    {
        glUniform1f(prog.AlphaRefLocation,m_AlphaRef);
        OPENGL_CHECK_ERRORS;
    }
}

int COGL_FragmentProgramCombiner::FindCompiledMux()
{
#ifdef DEBUGGER
    if( debuggerDropCombiners )
    {
        m_vCompiledShaders.clear();
        //m_dwLastMux0 = m_dwLastMux1 = 0;
        debuggerDropCombiners = false;
    }
#endif
    for( uint32 i=0; i<m_vCompiledShaders.size(); i++ )
    {
        if( m_vCompiledShaders[i].dwMux0 == m_pDecodedMux->m_dwMux0 
            && m_vCompiledShaders[i].dwMux1 == m_pDecodedMux->m_dwMux1 
            && m_vCompiledShaders[i].fogIsUsed == bFogState
            && m_vCompiledShaders[i].alphaTest == bAlphaTestState)
        {
            return (int)i;
        }
    }

    return -1;
}

//////////////////////////////////////////////////////////////////////////
void COGL_FragmentProgramCombiner::InitCombinerCycle12(void)
{
    if( !m_bFragmentProgramIsSupported )    
    {
        COGLColorCombiner4::InitCombinerCycle12();
        return;
    }

#ifdef DEBUGGER
    if( debuggerDropCombiners )
    {
        UpdateCombiner(m_pDecodedMux->m_dwMux0,m_pDecodedMux->m_dwMux1);
        m_vCompiledShaders.clear();
        m_dwLastMux0 = m_dwLastMux1 = 0;
        debuggerDropCombiners = false;
    }
#endif

    m_pOGLRender->EnableMultiTexture();

    bool combinerIsChanged = false;

    if( m_pDecodedMux->m_dwMux0 != m_dwLastMux0 || m_pDecodedMux->m_dwMux1 != m_dwLastMux1 || bAlphaTestState != bAlphaTestPreviousState || bFogState != bFogPreviousState || m_lastIndex < 0 )
    {
        combinerIsChanged = true;
        m_lastIndex = FindCompiledMux();
        if( m_lastIndex < 0 )       // Can not found
        {
            m_lastIndex = ParseDecodedMux();
        }

        m_dwLastMux0 = m_pDecodedMux->m_dwMux0;
        m_dwLastMux1 = m_pDecodedMux->m_dwMux1;
        bAlphaTestPreviousState = bAlphaTestState;
        bFogPreviousState = bFogState;
        m_AlphaRef = (float)(m_pOGLRender->m_dwAlpha)/255.0f;
    }


    GenerateCombinerSettingConstants(m_lastIndex);
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

#ifdef DEBUGGER
void COGL_FragmentProgramCombiner::DisplaySimpleMuxString(void)
{
    COGLColorCombiner::DisplaySimpleMuxString();
    DecodedMuxForPixelShader &mux = *(DecodedMuxForPixelShader*)m_pDecodedMux;
    mux.Reformat(false);
    GenerateProgramStr();
    //sprintf(oglNewFP, oglFP, 
    //  MuxToOC(mux.aRGB0), MuxToOC(mux.bRGB0), MuxToOC(mux.cRGB0), MuxToOC(mux.dRGB0),
    //  MuxToOA(mux.aA0), MuxToOA(mux.bA0), MuxToOA(mux.cA0), MuxToOA(mux.dA0),
    //  MuxToOC(mux.aRGB1), MuxToOC(mux.bRGB1), MuxToOC(mux.cRGB1), MuxToOC(mux.dRGB1),
    //  MuxToOA(mux.aA1), MuxToOA(mux.bA1), MuxToOA(mux.cA1), MuxToOA(mux.dA1)
    //  );

    TRACE0("OGL Fragment Program:");
    TRACE0(oglNewFP);
}
#endif

