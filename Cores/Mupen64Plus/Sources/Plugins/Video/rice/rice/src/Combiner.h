/*
Copyright (C) 2002 Rice1964

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

#ifndef _COMBINER_H_
#define _COMBINER_H_

#include "typedefs.h"
#include "CombinerDefs.h"
#include "CSortedList.h"

class CRender;

extern const char* cycleTypeStrs[];

class CColorCombiner
{
    friend class CRender;
public:
    virtual ~CColorCombiner() {};
    virtual void InitCombinerMode(void);

    virtual bool Initialize(void)=0;
    virtual void CleanUp(void) {};
    virtual void SetCombineMode(uint32 dwMux0, uint32 dwMux1);
    virtual void InitCombinerBlenderForSimpleTextureDraw(uint32 tile=0)=0;
    virtual void DisableCombiner(void)=0;
    bool    m_bLODFracEnabled; // TODO: Find a way to remove that.

protected:
    CColorCombiner(CRender *pRender) : 
        m_combineMode1(0),m_combineMode2(0),m_bTex0Enabled(false),m_bTex1Enabled(false),m_bTexelsEnable(false),
        m_bCycleChanged(false),m_pRender(pRender)
    {
            for(int i=0; i<16; i++)
            {
                m_sources[i] = -1;
            }
    }

    virtual void InitCombinerCycleCopy(void)=0;
    virtual void InitCombinerCycleFill(void)=0;
    virtual void InitCombinerCycle12(void)=0;

    enum SourceIndex {
        CS_COLOR_A0 = 0, // index for Color A, cycle 1
        CS_COLOR_B0,
        CS_COLOR_C0,
        CS_COLOR_D0,
        CS_ALPHA_A0,     // index for Alpha A,cycle 1
        CS_ALPHA_B0,
        CS_ALPHA_C0,
        CS_ALPHA_D0,
        CS_COLOR_A1,     // index for Color A, cycle 2
        CS_COLOR_B1,
        CS_COLOR_C1,
        CS_COLOR_D1,
        CS_ALPHA_A1,     // index for Alpha A, cycle 2
        CS_ALPHA_B1,
        CS_ALPHA_C1,
        CS_ALPHA_D1
    };

    uint8  m_sources[16];
    uint32 m_combineMode1;
    uint32 m_combineMode2;

    bool   m_bTex0Enabled;
    bool   m_bTex1Enabled;
    bool   m_bTexelsEnable;

    bool   m_bCycleChanged;    // A flag will be set if cycle is changed to FILL or COPY

    CRender *m_pRender;

private:
    static const SourceIndex color_indices[8];
    static const SourceIndex alpha_indices[8];
};

void swap(uint8 &a, uint8 &b);

#endif

