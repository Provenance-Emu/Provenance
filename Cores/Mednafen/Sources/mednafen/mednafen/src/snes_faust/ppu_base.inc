/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* ppu_base.inc:
**  Copyright (C) 2015-2022 Mednafen Team
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

struct PPU_BASE_S
{
 uint32 lastts;

 uint32 LinePhase;
 uint32 LineCounter;
 uint32 LinesPerFrame;
 uint32 LineTarget;
 uint32 scanline;
 //
 bool PAL;
 bool FrameBeginVBlank;
 bool VBlank;
 bool InterlaceOnSample;
 //
 uint32 LineStartTS;
 uint32 HLatch;
 uint32 VLatch;
 uint32 HLatchReadShift;
 uint32 VLatchReadShift;

 //
 // Cheaty registers and state:
 uint32 InHDMA;
 uint16 HTime;
 uint16 VTime;
 bool IRQThing;

 uint8 NMITIMEEN;

 uint8 HVBJOY;
 uint8 NMIFlag;	// 0x00 or 0x80
 uint8 IRQFlag;	// 0x00 or 0x80
 uint8 JPReadCounter;
 //
 //
 //
 //
 uint8 BusLatch[2];
 uint8 Status[2];	// $3E and $3F.

 uint8 ScreenMode;	// $33
 uint8 INIDisp;
 uint8 BGMode;
 uint8 Mosaic;
 uint8 MosaicYOffset;

 uint8 BGSC[4];

 uint8 BGNBA[2];

 uint8 BGOFSPrev;
 uint16 BGHOFS[4];
 uint16 BGVOFS[4];

 bool CGRAM_Toggle;
 uint8 CGRAM_Buffer;
 uint8 CGRAM_Addr;

 bool VMAIN_IncMode;
 uint16 VRAM_Addr;
 unsigned VMAIN_AddrInc;
 unsigned VMAIN_AddrTransMaskA;
 unsigned VMAIN_AddrTransShiftB;
 unsigned VMAIN_AddrTransMaskC;
 uint16 VRAM_ReadBuffer;
 bool AllowVRAMAccess;

 uint8 M7SEL;
 int16 M7Matrix[4];
 int16 M7Center[2];
 int16 M7HOFS;
 int16 M7VOFS;
 uint8 M7Prev;

 uint8 OAM_AllowFBReset;	// 0x00 or 0x80
 uint8 OAMADDL;
 uint8 OAMADDH;
 uint32 OAM_Addr;
 uint8 OAM_Buffer;
 uint8 OBSEL;

 uint8 MSEnable;
 uint8 SSEnable;

 uint8 CGWSEL;
 uint8 CGADSUB;
 uint16 FixedColor;

 uint8 WMSettings[3];
 uint8 WMMainEnable;
 uint8 WMSubEnable;
 uint16 WMLogic;
 uint8 WindowPos[2][2];
};
