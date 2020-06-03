/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* debug.cpp:
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
#include "input.h"
#include "cart.h"
#include "apu.h"
#include "ppu.h"

#include "dis65816.h"

#include <trio/trio.h>

#include <bitset>

#ifdef SNES_DBG_ENABLE

namespace MDFN_IEN_SNES_FAUST
{
#include "Core65816.h"

bool DBG_InHLRead;
static Dis65816* dis;
static uint32 CurPC;

enum { NUMBT = 24 };

static struct
{
 uint32 from;
 uint32 to;
 uint32 branch_count;
 unsigned iseq; // ~0U for no interrupt
 bool valid;
} BTEntries[NUMBT];
//static bool BTEnabled;
static unsigned BTIndex;

static void (*CPUHook)(uint32, bool);
static bool CPUHookContinuous;

struct BPOINT
{
 uint32 A[2];
};

static std::vector<BPOINT> BreakPointsRead, BreakPointsWrite, BreakPointsPC;

static bool FoundBPoint;

enum
{
 ASPACE_PHYSICAL = 0,
 ASPACE_WRAM,
 ASPACE_VRAM,
 ASPACE_CGRAM,
 ASPACE_OAM,
 ASPACE_OAMHI,
 ASPACE_APURAM,

 ASPACE_CARTRAM
};

static uint8 HLCPUBusRead(uint32 A)
{
 const uint32 ts_save = CPUM.timestamp;
 uint8 ret;

 A &= 0xFFFFFF;

 DBG_InHLRead = true;
 ret = CPUM.ReadFuncsA[CPUM.RWIndex[A]](A);
 DBG_InHLRead = false;

 if(CPUM.timestamp != ts_save)
 {
  printf("0x%08x\n", A);
  assert(CPUM.timestamp == ts_save);
 }
 return ret;
}

template<unsigned id>
static MDFN_COLD void GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer)
{
 while(MDFN_LIKELY(Length--))
 {
  switch(id)
  {
   default:
	break;

   case ASPACE_PHYSICAL:
	//TODO:
	*Buffer = HLCPUBusRead(Address);
	break;

   case ASPACE_WRAM:
	Address &= 0x1FFFF;
	*Buffer = PeekWRAM(Address);
	break;

   case ASPACE_VRAM:
	Address &= 0xFFFF;
	*Buffer = PPU_PeekVRAM(Address >> 1) >> ((Address & 0x1) << 3);
	break;

   case ASPACE_CGRAM:
	Address &= 0x1FF;
	*Buffer = PPU_PeekCGRAM(Address >> 1) >> ((Address & 0x1) << 3);
	break;

   case ASPACE_OAM:
	Address &= 0x1FF;
	*Buffer = PPU_PeekOAM(Address);
	break;

   case ASPACE_OAMHI:
	Address &= 0x1F;
	*Buffer = PPU_PeekOAMHI(Address);
	break;

   case ASPACE_APURAM:
	Address &= 0xFFFF;
	*Buffer = APU_PeekRAM(Address);
	break;

   case ASPACE_CARTRAM:
	*Buffer = CART_PeekRAM(Address);
	break;
  }
  Address++;
  Buffer++;
 }
}

template<unsigned id>
static MDFN_COLD void PutAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint32 Granularity, bool hl, const uint8 *Buffer)
{
 while(MDFN_LIKELY(Length--))
 {
  switch(id)
  {
   default:
	break;

   case ASPACE_PHYSICAL:
	//TODO:
	break;

   case ASPACE_WRAM:
	Address &= 0x1FFFF;
	PokeWRAM(Address, *Buffer);
	break;

   case ASPACE_VRAM:
	{
	 const unsigned shift = ((Address & 0x1) << 3);
	 Address &= 0xFFFF;
	 PPU_PokeVRAM(Address >> 1, (PPU_PeekVRAM(Address >> 1) & (0xFF00 >> shift)) | (*Buffer << shift));
	}
	break;

   case ASPACE_CGRAM:
	{
	 const unsigned shift = ((Address & 0x1) << 3);
	 Address &= 0x1FF;
	 PPU_PokeCGRAM(Address >> 1, (PPU_PeekCGRAM(Address >> 1) & (0xFF00 >> shift)) | (*Buffer << shift));
	}
	break;

   case ASPACE_OAM:
	Address &= 0x1FF;
	PPU_PokeOAM(Address, *Buffer);
	break;

   case ASPACE_OAMHI:
	Address &= 0x1F;
	PPU_PokeOAMHI(Address, *Buffer);
	break;

   case ASPACE_APURAM:
	Address &= 0xFFFF;
	APU_PokeRAM(Address, *Buffer);
	break;

   case ASPACE_CARTRAM:
	CART_PokeRAM(Address, *Buffer);
	break;
  }
  Address++;
  Buffer++;
 }
}

static uint32 MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical)
{
 uint32 ret = 0;

 while(bsize)
 {
  ret <<= 8;
  ret |= HLCPUBusRead(A);
  bsize--;
 }

 return ret;
}

static MDFN_COLD void FlushBreakPoints(int type)
{
 if(type == BPOINT_READ)
  BreakPointsRead.clear();
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.clear();
 else if(type == BPOINT_PC)
  BreakPointsPC.clear();
}

static MDFN_COLD void AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical)
{
 BPOINT tmp;

 tmp.A[0] = A1;
 tmp.A[1] = A2;

 if(type == BPOINT_READ)
  BreakPointsRead.push_back(tmp);
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.push_back(tmp);
 else if(type == BPOINT_PC)
  BreakPointsPC.push_back(tmp);
}

static MDFN_COLD void SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous)
{
 CPUHook = callb;
 CPUHookContinuous = continuous;
}

static MDFN_COLD void EnableBranchTrace(bool enable)
{

}

static MDFN_COLD std::vector<BranchTraceResult> GetBranchTrace(void)
{
 std::vector<BranchTraceResult> ret;
 BranchTraceResult tmp;

 for(unsigned x = 0; x < NUMBT; x++)
 {
  const char* estr = "";
  const auto* bt = &BTEntries[(x + BTIndex) % NUMBT];

  if(!bt->valid)
   continue;

  tmp.count = bt->branch_count;
  trio_snprintf(tmp.from, sizeof(tmp.from), "%06x", bt->from);
  trio_snprintf(tmp.to, sizeof(tmp.to), "%06x", bt->to);

  switch(bt->iseq)
  {
   case Core65816::ISEQ_COP:
	estr = "COP";
	break;

   case Core65816::ISEQ_BRK:
	estr = "BRK";
	break;

   case Core65816::ISEQ_ABORT:
	estr = "ABORT";
	break;

   case Core65816::ISEQ_NMI:
	estr = "NMI";
	break;

   case Core65816::ISEQ_IRQ:
	estr = "IRQ";
	break;
  }

  trio_snprintf(tmp.code, sizeof(tmp.code), "%s", estr);

  ret.push_back(tmp);
 }
 return ret;
}

void DBG_AddBranchTrace(uint32 to, unsigned iseq)
{
 const uint32 from = CurPC;
 auto *prevbt = &BTEntries[(BTIndex + NUMBT - 1) % NUMBT];

 //if(BTEntries[(BTIndex - 1) & 0xF] == PC) return;

 if(prevbt->from == from && prevbt->to == to && prevbt->iseq == iseq && prevbt->branch_count < 0xFFFFFFFF && prevbt->valid)
  prevbt->branch_count++;
 else
 {
  auto& bte = BTEntries[BTIndex];
  bte.from = from;
  bte.to = to;
  bte.iseq = iseq;
  bte.branch_count = 1;
  bte.valid = true;

  BTIndex = (BTIndex + 1) % NUMBT;
 }
}

void DBG_CPUHook(uint32 PCPBR, uint8 P)
{
 CurPC = PCPBR;
 //
 if(!dis)
  dis = new Dis65816();

 dis->SetMXHint(PCPBR, (bool)(P & Core65816::M_FLAG), (bool)(P & Core65816::X_FLAG));
 //
 for(auto& bp : BreakPointsPC)
 {
  if(PCPBR >= bp.A[0] && PCPBR <= bp.A[1])
  {
   FoundBPoint = true;
   break;
  }
 }

 //CPU[which].CheckRWBreakpoints(DBG_CheckReadBP, DBG_CheckWriteBP);
 //CPU->CheckBreakpoints(CheckCPUBPCallB, CPU->PeekMem32(PC));

 CPUHookContinuous |= FoundBPoint;

 if(CPUHookContinuous && CPUHook)
 {
  //ForceEventUpdates(timestamp);
  CPUHook(PCPBR, FoundBPoint);
  //
  CurPC = CPU_GetRegister(Core65816::GSREG_PCPBR);
  //P = CPU_GetRegister(Core65816::GSREG_P);
  //dis->SetMXHint(CurPC, (bool)(P & Core65816::M_FLAG), (bool)(P & Core65816::X_FLAG));
 }

 FoundBPoint = false;
}

static MDFN_COLD void Disassemble(uint32& A, uint32 SpecialA, char* TextBuf)
{
 if(!dis)
  dis = new Dis65816();

 const uint8 P = CPU_GetRegister(Core65816::GSREG_P);

 dis->Disassemble(A, SpecialA, TextBuf, (bool)(P & Core65816::M_FLAG), (bool)(P & Core65816::X_FLAG), HLCPUBusRead);
}

static const RegType DBG_Regs_CPU[] =
{
 { (0 << 16) | Core65816::GSREG_PCPBR, "PC", "PC", 3 },
 { (0 << 16) | Core65816::GSREG_P, "P", "P", 1 },

 { (0 << 16) | Core65816::GSREG_A, "A", "A", 2 },
 { (0 << 16) | Core65816::GSREG_X, "X", "X", 2 },
 { (0 << 16) | Core65816::GSREG_Y, "Y", "Y", 2 },

 { (0 << 16) | Core65816::GSREG_S, "S", "S", 2 },
 { (0 << 16) | Core65816::GSREG_D, "D", "D", 2 },
 { (0 << 16) | Core65816::GSREG_DBR, "DBR", "DBR", 1 },
 //
 { 0, "------", "", 0xFFFF },
 { (3 << 16) | SNES_GSREG_MEMSEL, "MemSel", "MemSel", 0x100 | 1 },
 { 0, "------", "", 0xFFFF },
 { (3 << 16) | SNES_GSREG_TS, "TS", "TS", 4 },
 //
 //
 //
 { 0, "", "", 0 }
};

#define DMACH(ch)										\
 { 0, "--CH" #ch ":--", "", 0xFFFF },								\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_CONTROL, "Control", "Control", 1 },			\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_BBUSADDR, "BBusAddr", "B-Bus Address", 1 },		\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_ABUSADDR, "ABusAddr", "A-Bus Address", 2 },		\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_ABUSBANK, "ABusBank", "A-Bus Bank", 1 },			\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_INDIRBANK, "IndirBank", "Indirect Bank", 1 },		\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_COUNT_INDIRADDR, "Count/IA", "Count/Indirect Address", 2 },\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_TABLEADDR, "TableAddr", "Table Address", 2 },		\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_LINECOUNTER, "LineCounter", "Line Counter", 1 },		\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_UNKNOWN, "Unknown", "Unknown", 1 },			\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_OFFSET, "Offset", "Offset", 1 },				\
 { (2 << 16) | (ch << 8) | DMA_GSREG_CHN_DOTRANSFER, "DoTransfer", "DoTransfer", 1 },

static const RegType DBG_Regs_DMA03[] =
{
 { (2 << 16) | DMA_GSREG_DMAENABLE, "DMAEnable", "DMA Enable", 1 },
 { (2 << 16) | DMA_GSREG_HDMAENABLE, "HDMAEnable", "HDMA Enable", 1 },
 { (2 << 16) | DMA_GSREG_HDMAENABLEM, "HDMAEnableM", "HDMA Enable Mask", 1 },

 DMACH(0)
 DMACH(1)
 DMACH(2)
 DMACH(3)
 //
 //
 //
 { 0, "", "", 0 }
};

static const RegType DBG_Regs_DMA47[] =
{
 DMACH(4)
 DMACH(5)
 DMACH(6)
 DMACH(7)
 //
 //
 //
 { 0, "", "", 0 }
};

#undef DMACH

static const RegType DBG_Regs_PPU[] =
{
 { (1 << 16) | PPU_GSREG_NMITIMEEN, "NMITIMEEN", "NMITIMEEN", 1 },
 { (1 << 16) | PPU_GSREG_HTIME, "HTIME", "HTIME", 0x100 | 9 },
 { (1 << 16) | PPU_GSREG_VTIME, "VTIME", "VTIME", 0x100 | 9 },
 { (1 << 16) | PPU_GSREG_NMIFLAG, "NMIFlag", "NMIFlag", 1 },
 { (1 << 16) | PPU_GSREG_IRQFLAG, "IRQFlag", "IRQFlag", 1 },
 { (1 << 16) | PPU_GSREG_HVBJOY, "HVBJOY", "HVBJOY", 1 },

 { (1 << 16) | PPU_GSREG_SCANLINE, "scanline", "scanline", 2 },

 { 0, "------", "", 0xFFFF },
 { (1 << 16) | PPU_GSREG_BGMODE, "BGMode", "BGMode", 1 },
 { (1 << 16) | PPU_GSREG_SCREENMODE, "ScreenMode", "ScreenMode", 1 },
 { (1 << 16) | PPU_GSREG_MOSAIC, "Mosaic", "Mosaic Control", 1 },
 { 0, "------", "", 0xFFFF },
 { (1 << 16) | PPU_GSREG_W12SEL, "W12SEL", "W12SEL", 1 },
 { (1 << 16) | PPU_GSREG_W34SEL, "W34SEL", "W34SEL", 1 },
 { (1 << 16) | PPU_GSREG_WOBJSEL, "WOBJSEL", "WOBJSEL", 1 },
 { (1 << 16) | PPU_GSREG_WH0, "WH0", "WH0", 1 },  
 { (1 << 16) | PPU_GSREG_WH1, "WH1", "WH1", 1 },
 { (1 << 16) | PPU_GSREG_WH2, "WH2", "WH2", 1 },
 { (1 << 16) | PPU_GSREG_WH3, "WH3", "WH3", 1 },
 { (1 << 16) | PPU_GSREG_WBGLOG, "WBGLOG", "WBGLOG", 1 },
 { (1 << 16) | PPU_GSREG_WOBJLOG, "WOBJLOG", "WOBJLOG", 1 },
 { (1 << 16) | PPU_GSREG_TM, "TM", "TM", 1 },
 { (1 << 16) | PPU_GSREG_TS, "TS", "TS", 1 },
 { (1 << 16) | PPU_GSREG_CGWSEL, "CGWSEL", "CGWSEL", 1 },
 { (1 << 16) | PPU_GSREG_CGADSUB, "CGADSUB", "CGADSUB", 1 },
 { 0, "------", "", 0xFFFF },
 { (1 << 16) | PPU_GSREG_BG1HOFS, "BG1HOFS", "BG1 H Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG1VOFS, "BG1VOFS", "BG1 V Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG2HOFS, "BG2HOFS", "BG2 H Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG2VOFS, "BG2VOFS", "BG2 V Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG3HOFS, "BG3HOFS", "BG3 H Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG3VOFS, "BG3VOFS", "BG3 V Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG4HOFS, "BG4HOFS", "BG4 H Scroll", 2 },
 { (1 << 16) | PPU_GSREG_BG4VOFS, "BG4VOFS", "BG4 V Scroll", 2 },
 { 0, "------", "", 0xFFFF },
 { (1 << 16) | PPU_GSREG_M7SEL, "M7SEL", "Mode 7 Settings", 1 },
 { (1 << 16) | PPU_GSREG_M7A, "M7A", "Mode 7 Matrix A", 2 },
 { (1 << 16) | PPU_GSREG_M7B, "M7B", "Mode 7 Matrix B", 2 },
 { (1 << 16) | PPU_GSREG_M7C, "M7C", "Mode 7 Matrix C", 2 },
 { (1 << 16) | PPU_GSREG_M7D, "M7D", "Mode 7 Matrix D", 2 },
 { (1 << 16) | PPU_GSREG_M7X, "M7X", "Mode 7 Center X", 0x100 | 13 },
 { (1 << 16) | PPU_GSREG_M7Y, "M7Y", "Mode 7 Center Y", 0x100 | 13 },
 { (1 << 16) | PPU_GSREG_M7HOFS, "M7HOFS", "Mode 7 H Scroll", 0x100 | 13 },
 { (1 << 16) | PPU_GSREG_M7VOFS, "M7VOFS", "Mode 7 V Scroll", 0x100 | 13 },

 //
 //
 //
 { 0, "", "", 0 }
};

static MDFN_COLD uint32 GetRegister(const unsigned int id, char* special, const uint32 special_len)
{
 switch(id >> 16)
 {
  case 0: return CPU_GetRegister((uint16)id, special, special_len);
  case 1: return PPU_GetRegister((uint16)id, special, special_len);
  case 2: return DMA_GetRegister((uint16)id, special, special_len);
  case 3: return SNES_GetRegister((uint16)id, special, special_len);
 }

 return 0xCAFEBABE;
}

static MDFN_COLD void SetRegister(const unsigned int id, uint32 value)
{
 switch(id >> 16)
 {
  case 0: CPU_SetRegister((uint16)id, value); break;
  case 1: PPU_SetRegister((uint16)id, value); break;
  case 2: DMA_SetRegister((uint16)id, value); break;
  case 3: SNES_SetRegister((uint16)id, value); break;
 }
}

static const RegGroupType DBG_RegGroup_CPU =
{
 NULL,
 DBG_Regs_CPU,
 GetRegister,
 SetRegister
};

static const RegGroupType DBG_RegGroup_DMA03 =
{
 NULL,
 DBG_Regs_DMA03,
 GetRegister,
 SetRegister
};

static const RegGroupType DBG_RegGroup_DMA47 =
{
 NULL,
 DBG_Regs_DMA47,
 GetRegister,
 SetRegister
};

static const RegGroupType DBG_RegGroup_PPU =
{
 NULL,
 DBG_Regs_PPU,
 GetRegister,
 SetRegister
};

void DBG_Init(void)
{
 ASpace_Add(GetAddressSpaceBytes<ASPACE_PHYSICAL>, PutAddressSpaceBytes<ASPACE_PHYSICAL>, "cpu24", "CPU (24-bit address)", 24);
 ASpace_Add(GetAddressSpaceBytes<ASPACE_WRAM>, PutAddressSpaceBytes<ASPACE_WRAM>, "wram", "Work RAM", 17);
 ASpace_Add(GetAddressSpaceBytes<ASPACE_VRAM>, PutAddressSpaceBytes<ASPACE_VRAM>, "vram", "PPU VRAM", 16);
 ASpace_Add(GetAddressSpaceBytes<ASPACE_CGRAM>, PutAddressSpaceBytes<ASPACE_CGRAM>, "vram", "PPU CGRAM", 9);
 ASpace_Add(GetAddressSpaceBytes<ASPACE_OAM>, PutAddressSpaceBytes<ASPACE_OAM>, "oam", "PPU OAM", 9);
 ASpace_Add(GetAddressSpaceBytes<ASPACE_OAMHI>, PutAddressSpaceBytes<ASPACE_OAMHI>, "oamhi", "PPU OAM High", 5);
 ASpace_Add(GetAddressSpaceBytes<ASPACE_APURAM>, PutAddressSpaceBytes<ASPACE_APURAM>, "apuram", "APU RAM", 16);

/*
 const size_t cart_ram_size = 32768; //CART_GetRAMSize();
 if(cart_ram_size)
  ASpace_Add(GetAddressSpaceBytes<ASPACE_CARTRAM>, PutAddressSpaceBytes<ASPACE_CARTRAM>, "cartram", "Cart RAM", MDFN_log2(round_up_pow2(cart_ram_size)));
*/
 //
 //
 MDFNDBG_AddRegGroup(&DBG_RegGroup_CPU);
 MDFNDBG_AddRegGroup(&DBG_RegGroup_DMA03);
 MDFNDBG_AddRegGroup(&DBG_RegGroup_DMA47);
 MDFNDBG_AddRegGroup(&DBG_RegGroup_PPU);

 DBG_InHLRead = false;
}

void DBG_Kill(void)
{
 // TODO, call
 if(dis)
 {
  delete dis;
  dis = nullptr;
 }
}

DebuggerInfoStruct DBG_DBGInfo
{
 "cp437",

 4,
 1,

 24,
 24,

 0x0000,
 ~0U,

 MemPeek,

 Disassemble,
 NULL,

 NULL,
 NULL,

 FlushBreakPoints,
 AddBreakPoint,
 SetCPUCallback,

 EnableBranchTrace,
 GetBranchTrace,

 NULL,
 NULL,

 NULL,
 NULL,
};


}

#endif
