/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - OGLCombiner.h                                           *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2002 Rice1964                                           *
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

#ifndef _OGL_COMBINER_H_
#define _OGL_COMBINER_H_

#include <vector>

#include "osal_opengl.h"

#include "Blender.h"
#include "Combiner.h"
#include "typedefs.h"

class CRender;
class OGLRender;

class COGLColorCombiner : public CColorCombiner
{
public:
    bool Initialize(void);
    void InitCombinerBlenderForSimpleTextureDraw(uint32 tile=0);
protected:
    friend class OGLDeviceBuilder;

    void DisableCombiner(void);
    void InitCombinerCycleCopy(void);
    void InitCombinerCycleFill(void);
    void InitCombinerCycle12(void);

    COGLColorCombiner(CRender *pRender);
    ~COGLColorCombiner();
    OGLRender *m_pOGLRender;

private:

    #define CC_NULL_PROGRAM      0 // Invalid OpenGL program
    #define CC_NULL_SHADER       0 // Invalid OpenGL shader
    #define CC_INACTIVE_UNIFORM -1 // Invalid program uniform

    typedef struct {
        uint32 combineMode1;
        uint32 combineMode2;
        unsigned int cycle_type;    // 1/2/fill/copy
        unsigned int key_enabled:1;   // Chroma key
        //uint16       blender;
        unsigned int alpha_compare; // None/Threshold/Dither
        unsigned int aa_en:1;
        //unsigned int z_cmp:1;
        //unsigned int z_upd:1;
        unsigned int alpha_cvg_sel:1;
        unsigned int cvg_x_alpha:1;
        unsigned int fog_enabled:1;
        unsigned int fog_in_blender:1;
        //unsigned int clr_on_cvg;
        //unsigned int cvg_dst;
        GLuint program;
        // Progam uniform locations
        GLint fogMaxMinLoc;
        GLint blendColorLoc;
        GLint primColorLoc;
        GLint envColorLoc;
        GLint chromaKeyCenterLoc;
        GLint chromaKeyScaleLoc;
        GLint chromaKeyWidthLoc;
        GLint lodFracLoc;
        GLint primLodFracLoc;
        GLint k5Loc;
        GLint k4Loc;
        GLint tex0Loc;
        GLint tex1Loc;
        GLint fogColorLoc;
    } ShaderSaveType;

    void   genFragmentBlenderStr( char *newFrgStr );
    GLuint GenerateCycle12Program();
    GLuint GenerateCopyProgram();
    void   GenerateCombinerSetting();
    void   GenerateCombinerSettingConstants( int shaderId );
    void   StoreUniformLocations( ShaderSaveType &saveType );
    int    FindCompiledShaderId();
    void   useProgram( const GLuint &program );

    GLuint m_vtxShader;    // Generate vertex shader once as it never change
    GLuint m_fillProgram;  // Generate fill program once as it never change
    GLint  m_fillColorLoc; // fill color uniform's program location

    std::vector<ShaderSaveType> m_generatedPrograms;
    GLuint m_currentProgram; // Used to avoid multiple glUseProgram calls
};

class COGLBlender : public CBlender
{
public:
    void NormalAlphaBlender(void);
    void DisableAlphaBlender(void);
    void BlendFunc(uint32 srcFunc, uint32 desFunc);
    void Enable();
    void Disable();

protected:
    friend class OGLDeviceBuilder;
    COGLBlender(CRender *pRender) : CBlender(pRender), m_pOGLRender((OGLRender*)pRender) {};
    ~COGLBlender() {};

    OGLRender *m_pOGLRender;
};

#endif



