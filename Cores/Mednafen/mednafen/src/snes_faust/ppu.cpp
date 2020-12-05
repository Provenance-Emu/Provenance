/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu.cpp:
**  Copyright (C) 2019 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "snes.h"
#include "ppu.h"

namespace MDFN_IEN_SNES_FAUST
{

static unsigned ppu_renderer = ~0U;
#define WHATEVER(s) assert(ppu_renderer == PPU_RENDERER_ST || ppu_renderer == PPU_RENDERER_MT); return ((ppu_renderer == PPU_RENDERER_MT) ? PPU_MT::s : PPU_ST::s)

void PPU_Init(const unsigned Renderer, const bool IsPAL, const bool IsPALPPUBit, const bool WantFrameBeginVBlank, const uint64 affinity)
{
 ppu_renderer = Renderer;
 assert(ppu_renderer == PPU_RENDERER_ST || ppu_renderer == PPU_RENDERER_MT);
 //
 MDFN_printf("Renderer: %s\n", (Renderer == PPU_RENDERER_MT) ? "Multi-threaded" : "Single-threaded");
 MDFN_printf("PAL: %d\n", IsPAL);
 MDFN_printf("PAL PPU Bit: %d\n", IsPALPPUBit);
 MDFN_printf("FrameBeginVBlank: %d\n", WantFrameBeginVBlank);
 if(ppu_renderer == PPU_RENDERER_MT)
 {
  MDFN_printf("PPUThreadAffinity: 0x%llx\n", (unsigned long long)affinity);
 }
 //
 WHATEVER(PPU_Init)(IsPAL, IsPALPPUBit, WantFrameBeginVBlank, affinity);
}

void PPU_Kill(void)
{
 if(ppu_renderer == PPU_RENDERER_ST)
  PPU_ST::PPU_Kill();
 else if(ppu_renderer == PPU_RENDERER_MT)
  PPU_MT::PPU_Kill();
 //
 ppu_renderer = ~0U;
}

void PPU_SetGetVideoParams(MDFNGI* gi, const unsigned caspect, const unsigned hfilter, const unsigned sls, const unsigned sle)
{
 WHATEVER(PPU_SetGetVideoParams)(gi, caspect, hfilter, sls, sle);
}

void PPU_Reset(bool powering_up)
{
 WHATEVER(PPU_Reset)(powering_up);
}

void PPU_ResetTS(void)
{
 WHATEVER(PPU_ResetTS)();
}

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 WHATEVER(PPU_StateAction)(sm, load, data_only);
}

void PPU_StartFrame(EmulateSpecStruct* espec)
{
 WHATEVER(PPU_StartFrame)(espec);
}

void PPU_SyncMT(void)
{
 if(ppu_renderer == PPU_RENDERER_MT)
  PPU_MT::PPU_SyncMT();
}

snes_event_handler PPU_GetEventHandler(void)
{
 WHATEVER(PPU_GetEventHandler)();
}

snes_event_handler PPU_GetLineIRQEventHandler(void)
{
 WHATEVER(PPU_GetLineIRQEventHandler)();
}
//
//
//
uint16 PPU_PeekVRAM(uint32 addr)
{
 WHATEVER(PPU_PeekVRAM)(addr);
}

uint16 PPU_PeekCGRAM(uint32 addr)
{
 WHATEVER(PPU_PeekCGRAM)(addr);
}

uint8 PPU_PeekOAM(uint32 addr)
{
 WHATEVER(PPU_PeekOAM)(addr);
}

uint8 PPU_PeekOAMHI(uint32 addr)
{
 WHATEVER(PPU_PeekOAMHI)(addr);
}

uint32 PPU_GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 WHATEVER(PPU_GetRegister)(id, special, special_len);
}
//
//
//
void PPU_PokeVRAM(uint32 addr, uint16 val)
{
 assert(ppu_renderer == PPU_RENDERER_ST);
 //
 PPU_ST::PPU_PokeVRAM(addr, val);
}

void PPU_PokeCGRAM(uint32 addr, uint16 val)
{
 assert(ppu_renderer == PPU_RENDERER_ST);
 //
 PPU_ST::PPU_PokeCGRAM(addr, val);
}

void PPU_PokeOAM(uint32 addr, uint8 val)
{
 assert(ppu_renderer == PPU_RENDERER_ST);
 //
 PPU_ST::PPU_PokeOAM(addr, val);
}

void PPU_PokeOAMHI(uint32 addr, uint8 val)
{
 assert(ppu_renderer == PPU_RENDERER_ST);
 //
 PPU_ST::PPU_PokeOAMHI(addr, val);
}

void PPU_SetRegister(const unsigned id, const uint32 value)
{
 assert(ppu_renderer == PPU_RENDERER_ST);
 //
 PPU_ST::PPU_SetRegister(id, value);
}

}
