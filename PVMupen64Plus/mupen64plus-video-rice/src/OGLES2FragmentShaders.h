/*
Copyright (C) 2005 Rice1964

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

#ifndef _OGL_FRAGMENT_SHADER_H_
#define _OGL_FRAGMENT_SHADER_H_

#include <vector>

#include "GeneralCombiner.h"
#include "OGLCombiner.h"
#include "OGLExtCombiner.h"
#include "osal_opengl.h"

typedef struct {
    uint32  dwMux0;
    uint32  dwMux1;

    bool    fogIsUsed;
    bool    alphaTest;
    GLuint  fragmentShaderID;
    GLuint  vertexShaderID;
    GLuint  programID;

    GLint  PrimColorLocation;
    GLint  EnvColorLocation;
    GLint  PrimFracLocation;
    GLint  EnvFracLocation;
    GLint  AlphaRefLocation;
    GLint FogColorLocation;
    GLint FogMinMaxLocation;

} OGLShaderCombinerSaveType;


class COGL_FragmentProgramCombiner : public COGLColorCombiner4
{
public:
    bool Initialize(void);

    void SetFogState(bool bEnable)
    {
        bFogState = bEnable;
    }
    void SetAlphaTestState(bool bEnable)
    {
        bAlphaTestState = bEnable;
    }

protected:
    friend class OGLDeviceBuilder;

    void DisableCombiner(void);
    void InitCombinerCycleCopy(void);
    void InitCombinerCycleFill(void);
    void InitCombinerCycle12(void);

    COGL_FragmentProgramCombiner(CRender *pRender);
    ~COGL_FragmentProgramCombiner();

    bool m_bFragmentProgramIsSupported;
    std::vector<OGLShaderCombinerSaveType>      m_vCompiledShaders;

private:
    virtual int ParseDecodedMux();
    virtual void GenerateProgramStr();
    int FindCompiledMux();
    virtual void GenerateCombinerSetting(int index);
    virtual void GenerateCombinerSettingConstants(int index);
    float m_AlphaRef;
    bool bAlphaTestState;
    bool bAlphaTestPreviousState;
    bool bFogState;
    bool bFogPreviousState;

#ifdef DEBUGGER
    void DisplaySimpleMuxString(void);
#endif

};

#endif

