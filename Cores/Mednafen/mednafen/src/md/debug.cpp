/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "shared.h"
#include "debug.h"
#include <mednafen/desa68/desa68.h>

namespace MDFN_IEN_MD
{
bool MD_DebugMode = false;

#if 0
enum { NUMBT = 16 };
static struct
{
 uint32 from;
 uint32 to;
 uint32 branch_count;
 uint32 

} BTEntries[NUMBT];
#endif

static void (*DriverCPUHook)(uint32, bool) = NULL;
static bool DriverCPUHookContinuous = false;

static M68K Main68K_BP;
static bool BPActive = false; // Any breakpoints on?
static bool BPNonPCActive = false;	// Any breakpoints other than PC on?
static bool FoundBPoint;

typedef struct
{
 uint32 A[2];
 int type;
} MD_BPOINT;

static std::vector<MD_BPOINT> BreakPointsPC, BreakPointsRead, BreakPointsWrite;
static std::vector<MD_BPOINT> BreakPointsAux0Read, BreakPointsAux0Write;

static uint32 M68K_GetRegister(const unsigned int id, char *special, const uint32 special_len)
{
 return Main68K.GetRegister(id, special, special_len);
}

void M68K_SetRegister(const unsigned int id, uint32 value)
{
 Main68K.SetRegister(id, value);
}


static RegType M68K_Regs[] =
{
        { M68K::GSREG_PC, "PC", "Program Counter", 4 },

        { 0, "------", "", 0xFFFF },

	{ M68K::GSREG_D0 + 0, "D0", "D0(Data Register 0)", 4 },
        { M68K::GSREG_D0 + 1, "D1", "D1(Data Register 1)", 4 },
        { M68K::GSREG_D0 + 2, "D2", "D2(Data Register 2)", 4 },
        { M68K::GSREG_D0 + 3, "D3", "D3(Data Register 3)", 4 },
        { M68K::GSREG_D0 + 4, "D4", "D4(Data Register 4)", 4 },
        { M68K::GSREG_D0 + 5, "D5", "D5(Data Register 5)", 4 },
        { M68K::GSREG_D0 + 6, "D6", "D6(Data Register 6)", 4 },
        { M68K::GSREG_D0 + 7, "D7", "D7(Data Register 7)", 4 },

        { 0, "------", "", 0xFFFF },

        { M68K::GSREG_A0 + 0, "A0", "A0(Address Register 0)", 4 },
        { M68K::GSREG_A0 + 1, "A1", "A1(Address Register 1)", 4 },
        { M68K::GSREG_A0 + 2, "A2", "A2(Address Register 2)", 4 },
        { M68K::GSREG_A0 + 3, "A3", "A3(Address Register 3)", 4 },
        { M68K::GSREG_A0 + 4, "A4", "A4(Address Register 4)", 4 },
        { M68K::GSREG_A0 + 5, "A5", "A5(Address Register 5)", 4 },
        { M68K::GSREG_A0 + 6, "A6", "A6(Address Register 6)", 4 },
        { M68K::GSREG_A0 + 7, "A7", "A7/USP(Address Register 7 / User Stack Pointer)", 4 },

        { 0, "------", "", 0xFFFF },
	{ M68K::GSREG_SR, "SR", "Status Register", 2 },

        { 0, "", "", 0 },
};

static const RegGroupType M68K_RegsGroup =
{
	"M68K",
        M68K_Regs,
        M68K_GetRegister,
        M68K_SetRegister
};


uint32 MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical)
{
 uint32 ret = 0;

 for(unsigned int i = 0; i < bsize; i++)
 {
  A &= 0xFFFFFF;
  ret |= Main68K_BusPeek8(A) << ((bsize - 1 - i) * 8);

  A++;
 }

 return(ret);
}

static uint16_t dis_callb(uint32_t A, void *private_data)
{
 return Main68K_BusPeek16(A & 0xFFFFFF);
}

void Disassemble(uint32 &a, uint32 SpecialA, char *TextBuf)
{
 DESA68parm_t d;

 a &= 0xFFFFFE;

 //printf("Disassemble %06x: ", a);

 strcpy(TextBuf, "Invalid");
 memset(&d, 0, sizeof(DESA68parm_t));

 d.mem_callb = dis_callb;
 d.memmsk = 0xFFFFFF;
 d.pc = a;
 d.str = TextBuf;
 d.strmax = 255;	// FIXME, MDFN API change

 MD_HackyHackyMode++;
 desa68(&d);
 MD_HackyHackyMode--;

 a = d.pc & 0xFFFFFF;

 if(d.pc & 1)
  puts("Oops");

 if(!d.status)
  strcpy(TextBuf, "Invalid");
 //printf("%d\n", d.status);
// puts(TextBuf);
}

void MDDBG_CPUHook(void)	//uint32 PC, uint16 op)
{
 uint32 PC = Main68K.GetRegister(M68K::GSREG_PC);
 std::vector<MD_BPOINT>::iterator bpit;

 FoundBPoint = 0;

 for(bpit = BreakPointsPC.begin(); bpit != BreakPointsPC.end(); bpit++)
 {
  if(PC >= bpit->A[0] && PC <= bpit->A[1])
  {
   FoundBPoint = true;
   break;
  }
 }

 if(BPNonPCActive)
 {
  Main68K_BP.DupeState(&Main68K);
  Main68K_BP.Step();
 }

 DriverCPUHookContinuous |= FoundBPoint;

 if(DriverCPUHookContinuous && DriverCPUHook)
  DriverCPUHook(PC, FoundBPoint);
}

static void RedoCPUHook(void)
{
 BPNonPCActive = BreakPointsRead.size() || BreakPointsWrite.size() || BreakPointsAux0Read.size() || BreakPointsAux0Write.size();
 BPActive = BPNonPCActive || BreakPointsPC.size();

 MD_DebugMode = (DriverCPUHook || BPActive);
}

static void AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical)
{
 MD_BPOINT tmp;

 if(type == BPOINT_READ || type == BPOINT_WRITE)
 {
  A1 &= 0xFFFFFF;
  A2 &= 0xFFFFFF;
 }

 tmp.A[0] = A1;
 tmp.A[1] = A2;
 tmp.type = type;

 if(type == BPOINT_READ)
  BreakPointsRead.push_back(tmp);
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.push_back(tmp);
 else if(type == BPOINT_IO_READ)
  BreakPointsAux0Read.push_back(tmp);
 else if(type == BPOINT_AUX_WRITE)
  BreakPointsAux0Write.push_back(tmp);
 else if(type == BPOINT_PC)
  BreakPointsPC.push_back(tmp);

 RedoCPUHook();
}


void FlushBreakPoints(int type)
{
 std::vector<MD_BPOINT>::iterator bpit;

 if(type == BPOINT_READ)
  BreakPointsRead.clear();
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.clear();
 else if(type == BPOINT_AUX_READ)
  BreakPointsAux0Read.clear();
 else if(type == BPOINT_AUX_WRITE)
  BreakPointsAux0Write.clear();
 else if(type == BPOINT_PC)
  BreakPointsPC.clear();

 RedoCPUHook();
}

void SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous)
{
 DriverCPUHook = callb;
 DriverCPUHookContinuous = continuous;
 RedoCPUHook();
}

static void EnableBranchTrace(bool enable)
{

}

std::vector<BranchTraceResult> GetBranchTrace(void)
{
 std::vector<BranchTraceResult> ret;

 return(ret);
}

static void GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer)
{
 if(!strcmp(name, "cpu"))
 {
  while(Length--)
  {
   Address &= 0xFFFFFF;
   *Buffer = Main68K_BusPeek8(Address);
   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "ram"))
 {
  while(Length--)
  {
   *Buffer = Main68K_BusPeek8((Address & 0xFFFF) | 0xFF0000);
   Address++;
   Buffer++;
  }
 }
}

static void PutAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint32 Granularity, bool hl, const uint8 *Buffer)
{
 if(!strcmp(name, "cpu"))
 {
  while(Length--)
  {
   Address &= 0xFFFFFF;
  }
 }
 else if(!strcmp(name, "ram"))
 {
  while(Length--)
  {
   Main68K_BusPoke8((Address & 0xFFFF) | 0xFF0000, *Buffer);
   Address++;
   Buffer++;
  }
 }
}

static MDFN_FASTCALL unsigned DBG_BusIntAck(uint8 level)
{
 return M68K::BUS_INT_ACK_AUTO;
}

static MDFN_FASTCALL uint8 DBG_BusRead8(uint32 address)
{
 std::vector<MD_BPOINT>::iterator bpit;
 address &= 0xFFFFFF;

 for(bpit = BreakPointsRead.begin(); bpit != BreakPointsRead.end(); bpit++)
 {
  if(address >= bpit->A[0] && address <= bpit->A[1])
  {
   FoundBPoint = true;
   break;
  }
 }

 return Main68K_BusPeek8(address);
}

static MDFN_FASTCALL void DBG_BusRMW(uint32 address, uint8 (MDFN_FASTCALL *cb)(M68K*, uint8))
{
 uint8 tmp = DBG_BusRead8(address);

 cb(&Main68K_BP, tmp);
}

static MDFN_FASTCALL uint16 DBG_BusRead16(uint32 address)
{
 std::vector<MD_BPOINT>::iterator bpit;

 address &= 0xFFFFFF;

 for(bpit = BreakPointsRead.begin(); bpit != BreakPointsRead.end(); bpit++)
 {
  if((address | 1) >= bpit->A[0] && address <= bpit->A[1])
  {
   FoundBPoint = true;
   break;
  }
 }

 //printf("Read: %08x\n", address);

 return Main68K_BusPeek16(address);
}

static MDFN_FASTCALL void DBG_BusWrite8(uint32 address, uint8 value)
{
 std::vector<MD_BPOINT>::iterator bpit;

 address &= 0xFFFFFF;

 for(bpit = BreakPointsWrite.begin(); bpit != BreakPointsWrite.end(); bpit++)
 {
  if(address >= bpit->A[0] && address <= bpit->A[1])
  {
   FoundBPoint = true;
   break;
  }
 }
}

static MDFN_FASTCALL void DBG_BusWrite16(uint32 address, uint16 value)
{
 std::vector<MD_BPOINT>::iterator bpit;

 address &= 0xFFFFFF;

 for(bpit = BreakPointsWrite.begin(); bpit != BreakPointsWrite.end(); bpit++)
 {
  if((address | 1) >= bpit->A[0] && address <= bpit->A[1])
  {
   FoundBPoint = true;
   break;
  }
 }
}



void MDDBG_Init(void)
{
 MDFNDBG_AddRegGroup(&M68K_RegsGroup);

 ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "cpu", "CPU Physical", 24);
 ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "ram", "Work RAM", 16);

 //
 Main68K_BP.BusIntAck = DBG_BusIntAck;
 Main68K_BP.BusReadInstr = DBG_BusRead16;

 Main68K_BP.BusRead8 = DBG_BusRead8;
 Main68K_BP.BusRead16 = DBG_BusRead16;

 Main68K_BP.BusWrite8 = DBG_BusWrite8;
 Main68K_BP.BusWrite16 = DBG_BusWrite16;

 Main68K_BP.BusRMW = DBG_BusRMW;
 //

 MD_DebugMode = false;
}

DebuggerInfoStruct DBGInfo =
{
 "shift_jis",
 10,		// Max instruction size(bytes)
 2,		// Instruction alignment(bytes)
 24,		// Logical address bits
 24,		// Physical address bits
 0xFF0000,	// Default watch address
 ~0U,		// ZP

 MemPeek,
 Disassemble,
 NULL,
 NULL, // IRQ,
 NULL, // NESDBG_GetVector,
 FlushBreakPoints,
 AddBreakPoint,
 SetCPUCallback,
 EnableBranchTrace,
 GetBranchTrace,
 NULL, //SetGraphicsDecode,
 NULL, //GetGraphicsDecodeBuffer,
 NULL, //SetLogFunc,
};



};
