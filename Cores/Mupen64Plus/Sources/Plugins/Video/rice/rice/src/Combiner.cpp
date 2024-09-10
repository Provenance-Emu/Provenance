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

#include "Combiner.h"

#include "Config.h"
#include "RSP_Parser.h"
#include "RenderBase.h"

//static BOOL g_bHiliteRGBAHack = FALSE;


#ifdef DEBUGGER
const char *constStrs[] = {
    "MUX_0",
    "MUX_1",
    "MUX_COMBINED",
    "MUX_TEXEL0",
    "MUX_TEXEL1",
    "MUX_PRIM",
    "MUX_SHADE",
    "MUX_ENV",
    "MUX_COMBALPHA",
    "MUX_T0_ALPHA",
    "MUX_T1_ALPHA",
    "MUX_PRIM_ALPHA",
    "MUX_SHADE_ALPHA",
    "MUX_ENV_ALPHA",
    "MUX_LODFRAC",
    "MUX_PRIMLODFRAC",
    "MUX_K5",
    "MUX_UNK",
};

const char *cycleTypeStrs[] = {
    "1 Cycle",
    "2 Cycle",
    "Copy Mode",
    "Fill Mode"
};

const char* constStr(uint32 op)
{
if(op<=MUX_UNK)
    return constStrs[op];
else
   return "Invalid-Const";
}
#endif

void swap(uint8 &a, uint8 &b)
{
    uint8 c=a;
    a=b;
    b=c;
}

//========================================================================

const CColorCombiner::SourceIndex CColorCombiner::color_indices[8] = {
                                                    CS_COLOR_A0 ,
                                                    CS_COLOR_B0 ,
                                                    CS_COLOR_C0 ,
                                                    CS_COLOR_D0 ,
                                                    CS_COLOR_A1 ,
                                                    CS_COLOR_B1 ,
                                                    CS_COLOR_C1 ,
                                                    CS_COLOR_D1 };
const CColorCombiner::SourceIndex CColorCombiner::alpha_indices[8] = {
                                                    CS_ALPHA_A0 ,
                                                    CS_ALPHA_B0 ,
                                                    CS_ALPHA_C0 ,
                                                    CS_ALPHA_D0 ,
                                                    CS_ALPHA_A1 ,
                                                    CS_ALPHA_B1 ,
                                                    CS_ALPHA_C1 ,
                                                    CS_ALPHA_D1 };

void CColorCombiner::InitCombinerMode(void)
{
    if( currentRomOptions.bNormalCombiner )
    {
        DisableCombiner();
    }
    else if( gRDP.otherMode.cycle_type  == CYCLE_TYPE_COPY )
    {
        InitCombinerCycleCopy();
        m_bCycleChanged = true;
    }
    else if ( gRDP.otherMode.cycle_type == CYCLE_TYPE_FILL )
    //else if ( gRDP.otherMode.cycle_type == CYCLE_TYPE_FILL && gRSP.ucode != 5 )   //hack
    {
        InitCombinerCycleFill();
        m_bCycleChanged = true;
    }
    else
    {
        InitCombinerCycle12();
        m_bCycleChanged = false;
    }
}

bool bConkerHideShadow=false;
// rgb0   = (A0 - B0) * C0 + D0
// rgb1   = (A1 - B1) * C1 + D1
// alpha0 = (a0 - b0) * c0 + d0
// alpha1 = (a1 - b1) * c1 + d1
void CColorCombiner::SetCombineMode(uint32 dwMux0, uint32 dwMux1)
{
    // Cycle 1
    m_sources[CS_COLOR_A0] = (uint8)((dwMux0 >> 20) & 0xF);
    m_sources[CS_COLOR_B0] = (uint8)((dwMux1 >> 28) & 0xF);
    m_sources[CS_COLOR_C0] = (uint8)((dwMux0 >> 15) & 0x1F);
    m_sources[CS_COLOR_D0] = (uint8)((dwMux1 >> 15) & 0x7);
    m_sources[CS_ALPHA_A0] = (uint8)((dwMux0 >> 12) & 0x7);
    m_sources[CS_ALPHA_B0] = (uint8)((dwMux1 >> 12) & 0x7);
    m_sources[CS_ALPHA_C0] = (uint8)((dwMux0 >> 9)  & 0x7);
    m_sources[CS_ALPHA_D0] = (uint8)((dwMux1 >> 9)  & 0x7);
    //Cycle 2
    m_sources[CS_COLOR_A1] = (uint8)((dwMux0 >> 5)  & 0xF);
    m_sources[CS_COLOR_B1] = (uint8)((dwMux1 >> 24) & 0xF);
    m_sources[CS_COLOR_C1] = (uint8)((dwMux0 >> 0)  & 0x1F);
    m_sources[CS_COLOR_D1] = (uint8)((dwMux1 >> 6)  & 0x7);
    m_sources[CS_ALPHA_A1] = (uint8)((dwMux1 >> 21) & 0x7);
    m_sources[CS_ALPHA_B1] = (uint8)((dwMux1 >> 3)  & 0x7);
    m_sources[CS_ALPHA_C1] = (uint8)((dwMux1 >> 18) & 0x7);
    m_sources[CS_ALPHA_D1] = (uint8)((dwMux1 >> 0)  & 0x7);

    m_combineMode1 = dwMux0;
    m_combineMode2 = dwMux1;

    // Look what is used in this combine mode.
    // TODO: We should be able to remove this part in the futur and let the
    // plugin reproduce the N64 behavior to keep the code clean and avoid
    // unnecessary optimizations.
    m_bTex0Enabled    = false;
    m_bTex1Enabled    = false;
    m_bLODFracEnabled = false;

    for( int i = 0; i < 8; i++ ) {
        switch( color_indices[i] ) {
            case CCMUX_TEXEL0:
            case CCMUX_TEXEL0_ALPHA:
                m_bTex0Enabled = true;
                break;
            case CCMUX_TEXEL1:
            case CCMUX_TEXEL1_ALPHA:
                m_bTex1Enabled = true;
                break;
            case CCMUX_LOD_FRACTION:
                m_bLODFracEnabled = true;
                break;
            default:
                break;
        }
        switch( alpha_indices[i] ) {
            case ACMUX_TEXEL0:
                m_bTex0Enabled = true;
                break;
            case ACMUX_TEXEL1:
                m_bTex1Enabled = true;
                break;
            case ACMUX_LOD_FRACTION:
                m_bLODFracEnabled = true;
                break;
            default:
                break;
        }
    }
    m_bTexelsEnable = m_bTex0Enabled || m_bTex1Enabled;

    // Hacks
    if( options.enableHackForGames == HACK_FOR_TOPGEARRALLY )
    {
        //Mux=0x00317e025ffef3fa    Used in TOP GEAR RALLY
        //Color0: (PRIM - ENV) * TEXEL1 + ENV
        //Color1: (COMBINED - 0) * TEXEL1 + 0
        //Alpha0: (0 - 0) * 0 + TEXEL0
        //Alpha1: (0 - 0) * 0 + TEXEL1
        if( dwMux1 == 0x5ffef3fa || dwMux0 == 0x00317e02 )
        {
            // The texts
            m_sources[CS_ALPHA_D1] = ACMUX_COMBINED;
            m_sources[CS_COLOR_C1] = CCMUX_TEXEL0;
        }
    }

    if( options.enableHackForGames == HACK_FOR_CONKER )
    {
        // Conker's shadow, to disable the shadow
        //Mux=0x00ffe9ff    Used in CONKER BFD
        //Color0: (0 - 0) * 0 + SHADE
        //Color1: (0 - 0) * 0 + SHADE
        //Alpha0: (1 - TEXEL0) * SHADE + 0
        //Alpha1: (1 - TEXEL0) * SHADE + 0              
        if( dwMux1 == 0xffd21f0f && dwMux0 == 0x00ffe9ff )
        {
            bConkerHideShadow = true;
        }
        else
        {
            bConkerHideShadow = false;
        }
    }
}
