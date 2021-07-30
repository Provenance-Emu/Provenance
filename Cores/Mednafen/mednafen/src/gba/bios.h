// -*- C++ -*-
// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2004 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#ifndef VBA_BIOS_H
#define VBA_BIOS_H

namespace MDFN_IEN_GBA
{

void BIOS_ArcTan();
void BIOS_ArcTan2();
void BIOS_BitUnPack();
void BIOS_BgAffineSet();
void BIOS_CpuSet();
void BIOS_CpuFastSet();
void BIOS_Diff8bitUnFilterWram();
void BIOS_Diff8bitUnFilterVram();
void BIOS_Diff16bitUnFilter();
void BIOS_Div();
void BIOS_DivARM();
void BIOS_HuffUnComp();
void BIOS_LZ77UnCompVram();
void BIOS_LZ77UnCompWram();
void BIOS_ObjAffineSet();
void BIOS_RegisterRamReset();
void BIOS_RegisterRamReset(uint32);
void BIOS_RLUnCompVram();
void BIOS_RLUnCompWram();
void BIOS_SoftReset();
void BIOS_Sqrt();
void BIOS_MidiKey2Freq();
void BIOS_SndDriverJmpTableCopy();

}

#endif // VBA_BIOS_H
