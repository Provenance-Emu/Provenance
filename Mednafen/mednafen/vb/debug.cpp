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

#include "vb.h"
#include <mednafen/hw_cpu/v810/v810_cpuD.h>
#include <string.h>
#include <trio/trio.h>
#include <stdarg.h>
#include <iconv.h>

#include "debug.h"
#include "timer.h"
//#include "input.h"
#include "vip.h"
#include "vsu.h"
#include "timer.h"

namespace MDFN_IEN_VB
{

extern V810 *VB_V810;
extern VSU *VB_VSU;

static void RedoCPUHook(void);
static void (*CPUHook)(uint32, bool bpoint) = NULL;
static bool CPUHookContinuous = false;
static void (*LogFunc)(const char *, const char *);
bool VB_LoggingOn = FALSE;

typedef struct __VB_BPOINT {
        uint32 A[2];
        int type;
        bool logical;
} VB_BPOINT;

static std::vector<VB_BPOINT> BreakPointsPC, BreakPointsRead, BreakPointsWrite;
static bool FoundBPoint = 0;

struct BTEntry
{
 uint32 from;
 uint32 to;
 uint32 branch_count;
 uint32 ecode;
 bool valid;
};

#define NUMBT 24
static BTEntry BTEntries[NUMBT];
static int BTIndex;
static bool BTEnabled;

static void AddBranchTrace(uint32 from, uint32 to, uint32 ecode)
{
 BTEntry *prevbt = &BTEntries[(BTIndex + NUMBT - 1) % NUMBT];

 //if(BTEntries[(BTIndex - 1) & 0xF] == PC) return;

 if(prevbt->from == from && prevbt->to == to && prevbt->ecode == ecode && prevbt->branch_count < 0xFFFFFFFF && prevbt->valid)
  prevbt->branch_count++;
 else
 {
  BTEntries[BTIndex].from = from;
  BTEntries[BTIndex].to = to;
  BTEntries[BTIndex].ecode = ecode;
  BTEntries[BTIndex].branch_count = 1;
  BTEntries[BTIndex].valid = true;

  BTIndex = (BTIndex + 1) % NUMBT;
 }
}

void VBDBG_EnableBranchTrace(bool enable)
{
 BTEnabled = enable;
 if(!enable)
 {
  BTIndex = 0;
  memset(BTEntries, 0, sizeof(BTEntries));
 }

 RedoCPUHook();
}

std::vector<BranchTraceResult> VBDBG_GetBranchTrace(void)
{
 BranchTraceResult tmp;
 std::vector<BranchTraceResult> ret;

 for(int x = 0; x < NUMBT; x++)
 {
  const BTEntry *bt = &BTEntries[(x + BTIndex) % NUMBT];

  if(!bt->valid)
   continue;

  tmp.count = bt->branch_count;
  trio_snprintf(tmp.from, sizeof(tmp.from), "%08x", bt->from);
  trio_snprintf(tmp.to, sizeof(tmp.to), "%08x", bt->to);

  tmp.code[0] = 0;


  if(bt->ecode >= 0xFFA0 && bt->ecode <= 0xFFBF)      // TRAP
  {
	trio_snprintf(tmp.code, sizeof(tmp.code), "TRAP");
  }
  else if(bt->ecode >= 0xFE00 && bt->ecode <= 0xFEFF)
  {
	trio_snprintf(tmp.code, sizeof(tmp.code), "INT%d", (bt->ecode >> 4) & 0xF);
  }
  else switch(bt->ecode)
  {
   case 0: break;
   default: trio_snprintf(tmp.code, sizeof(tmp.code), "e");
            break;

   case 0xFFF0: // Reset
        trio_snprintf(tmp.code, sizeof(tmp.code), "R");
        break;

   case 0xFFD0: // NMI
        trio_snprintf(tmp.code, sizeof(tmp.code), "NMI");
        break;

   case 0xFFC0: // Address trap
        trio_snprintf(tmp.code, sizeof(tmp.code), "ADTR");
        break;

   case 0xFF90: // Illegal/invalid instruction code
        trio_snprintf(tmp.code, sizeof(tmp.code), "ILL");
        break;

   case 0xFF80: // Zero division
        trio_snprintf(tmp.code, sizeof(tmp.code), "ZD");
        break;

   case 0xFF70:
        trio_snprintf(tmp.code, sizeof(tmp.code), "FIV");       // FIV
        break;

   case 0xFF68:
        trio_snprintf(tmp.code, sizeof(tmp.code), "FZD");       // FZD
        break;

   case 0xFF64:
        trio_snprintf(tmp.code, sizeof(tmp.code), "FOV");       // FOV
        break;

   case 0xFF62:
        trio_snprintf(tmp.code, sizeof(tmp.code), "FUD");       // FUD
        break;

   case 0xFF61:
        trio_snprintf(tmp.code, sizeof(tmp.code), "FPR");       // FPR
        break;

   case 0xFF60:
        trio_snprintf(tmp.code, sizeof(tmp.code), "FRO");       // FRO
        break;
  }

  ret.push_back(tmp);
 }
 return(ret);
}


void VBDBG_CheckBP(int type, uint32 address, uint32 value, unsigned int len)
{
 std::vector<VB_BPOINT>::iterator bpit, bpit_end;

 if(type == BPOINT_READ || type == BPOINT_IO_READ)
 {
  bpit = BreakPointsRead.begin();
  bpit_end = BreakPointsRead.end();
 }
 else if(type == BPOINT_WRITE || type == BPOINT_IO_WRITE)
 {
  bpit = BreakPointsWrite.begin();
  bpit_end = BreakPointsWrite.end();
 }
 else
  return;

 for(; bpit != bpit_end; bpit++)
 {
  uint32 tmp_address = address;
  uint32 tmp_len = len;

  while(tmp_len--)
  {
   if(tmp_address >= bpit->A[0] && tmp_address <= bpit->A[1])
   {
    FoundBPoint = TRUE;
    break;
   }
   tmp_address++;
  }
 }
}

static uint16 MDFN_FASTCALL MemPeek8(v810_timestamp_t timestamp, uint32 A)
{
 uint8 ret;

 // TODO: VB_InDebugPeek(implement elsewhere)
 VB_InDebugPeek++;
 ret = MemRead8(timestamp, A);
 VB_InDebugPeek--;

 return(ret);
}

static uint16 MDFN_FASTCALL MemPeek16(v810_timestamp_t timestamp, uint32 A)
{
 uint16 ret;

 // TODO: VB_InDebugPeek(implement elsewhere)
 VB_InDebugPeek++;
 ret = MemRead16(timestamp, A);
 VB_InDebugPeek--;

 return(ret);
}

static void CPUHandler(const v810_timestamp_t timestamp, uint32 PC)
{
 std::vector<VB_BPOINT>::iterator bpit;

 for(bpit = BreakPointsPC.begin(); bpit != BreakPointsPC.end(); bpit++)
 {
  if(PC >= bpit->A[0] && PC <= bpit->A[1])
  {
   FoundBPoint = TRUE;
   break;
  }
 }
 VB_V810->CheckBreakpoints(VBDBG_CheckBP, MemPeek16, NULL);

 CPUHookContinuous |= FoundBPoint;

 if(CPUHook && CPUHookContinuous)
 {
  ForceEventUpdates(timestamp);
  CPUHook(PC, FoundBPoint);
 }

 FoundBPoint = false;
}

static void RedoCPUHook(void)
{
 VB_V810->SetCPUHook((CPUHook || VB_LoggingOn || BreakPointsPC.size() || BreakPointsRead.size() || BreakPointsWrite.size()) ? CPUHandler : NULL,
	BTEnabled ? AddBranchTrace : NULL);
}

void VBDBG_FlushBreakPoints(int type)
{
 std::vector<VB_BPOINT>::iterator bpit;

 if(type == BPOINT_READ)
  BreakPointsRead.clear();
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.clear();
 else if(type == BPOINT_PC)
  BreakPointsPC.clear();

 RedoCPUHook();
}

void VBDBG_AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical)
{
 VB_BPOINT tmp;

 tmp.A[0] = A1;
 tmp.A[1] = A2;
 tmp.type = type;

 if(type == BPOINT_READ)
  BreakPointsRead.push_back(tmp);
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.push_back(tmp);
 else if(type == BPOINT_PC)
  BreakPointsPC.push_back(tmp);

 RedoCPUHook();
}

static uint16 dis_readhw(uint32 A)
{
 int32 timestamp = 0;
 return(MemPeek16(timestamp, A));
}

void VBDBG_Disassemble(uint32 &a, uint32 SpecialA, char *TextBuf)
{
 return(v810_dis(a, 1, TextBuf, dis_readhw, true));
}

uint32 VBDBG_MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical)
{
 uint32 ret = 0;
 int32 ws = 0;

 for(unsigned int i = 0; i < bsize; i++)
 {
  A &= 0xFFFFFFFF;
  //ret |= mem_peekbyte(A, ws) << (i * 8);
  ret |= MemRead8(ws, A) << (i * 8);
  A++;
 }

 return(ret);
}

static void GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer)
{
 if(!strcmp(name, "cpu"))
 {
  while(Length--)
  {
   *Buffer = MemPeek8(0, Address);

   Address++;
   Buffer++;
  }
 }
 else if(!strncmp(name, "vsuwd", 5))
 {
  const unsigned int which = name[5] - '0';

  while(Length--)
  {
   *Buffer = VB_VSU->PeekWave(which, Address);

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
   int32 dummy_ts = 0;

   MemWrite8(dummy_ts, Address, *Buffer);

   Address++;
   Buffer++;
  }
 }
 else if(!strncmp(name, "vsuwd", 5))
 {
  const unsigned int which = name[5] - '0';

  while(Length--)
  {
   VB_VSU->PokeWave(which, Address, *Buffer);

   Address++;
   Buffer++;
  }
 }
}

static uint32 VBDBG_GetRegister(const unsigned int id, char* special, const uint32 special_len)
{
 return VB_V810->GetRegister(id, special, special_len);
}

static void VBDBG_SetRegister(const unsigned int id, uint32 value)
{
 VB_V810->SetRegister(id, value);
}

void VBDBG_SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous)
{
 CPUHook = callb;
 CPUHookContinuous = continuous;
 RedoCPUHook();
}

void VBDBG_DoLog(const char *type, const char *format, ...)
{
 if(LogFunc)
 {
  char *temp;

  va_list ap;
  va_start(ap, format);

  temp = trio_vaprintf(format, ap);
  LogFunc(type, temp);
  free(temp);

  va_end(ap);
 }
}

void VBDBG_SetLogFunc(void (*func)(const char *, const char *))
{
 LogFunc = func;

 VB_LoggingOn = func ? TRUE : FALSE;

 if(VB_LoggingOn)
 {

 }
 else
 {

 }
 RedoCPUHook();
}

static RegType V810Regs[] =
{
        { V810::GSREG_PC, "PC", "Program Counter", 4 },
	{ V810::GSREG_PR + 1, "PR1", "Program Register 1", 4 },
	{ V810::GSREG_PR + 2, "HSP", "Program Register 2(Handler Stack Pointer)", 4 },
	{ V810::GSREG_PR + 3, "SP", "Program Register 3(Stack Pointer)", 4 },
	{ V810::GSREG_PR + 4, "GP", "Program Register 4(Global Pointer)", 4 },
	{ V810::GSREG_PR + 5, "TP", "Program Register 5(Text Pointer)", 4 },
	{ V810::GSREG_PR + 6, "PR6", "Program Register 6", 4 },
	{ V810::GSREG_PR + 7, "PR7", "Program Register 7", 4 },
	{ V810::GSREG_PR + 8, "PR8", "Program Register 8", 4 },
	{ V810::GSREG_PR + 9, "PR9", "Program Register 9", 4 },
	{ V810::GSREG_PR + 10, "PR10", "Program Register 10", 4 },
	{ V810::GSREG_PR + 11, "PR11", "Program Register 11", 4 },
	{ V810::GSREG_PR + 12, "PR12", "Program Register 12", 4 },
	{ V810::GSREG_PR + 13, "PR13", "Program Register 13", 4 },
	{ V810::GSREG_PR + 14, "PR14", "Program Register 14", 4 },
	{ V810::GSREG_PR + 15, "PR15", "Program Register 15", 4 },
        { V810::GSREG_PR + 16, "PR16", "Program Register 16", 4 },
        { V810::GSREG_PR + 17, "PR17", "Program Register 17", 4 },
        { V810::GSREG_PR + 18, "PR18", "Program Register 18", 4 },
        { V810::GSREG_PR + 19, "PR19", "Program Register 19", 4 },
        { V810::GSREG_PR + 20, "PR20", "Program Register 20", 4 },
        { V810::GSREG_PR + 21, "PR21", "Program Register 21", 4 },
        { V810::GSREG_PR + 22, "PR22", "Program Register 22", 4 },
        { V810::GSREG_PR + 23, "PR23", "Program Register 23", 4 },
        { V810::GSREG_PR + 24, "PR24", "Program Register 24", 4 },
        { V810::GSREG_PR + 25, "PR25", "Program Register 25", 4 },
        { V810::GSREG_PR + 26, "PR26", "Program Register 26(String Dest Bit Offset)", 4 },
        { V810::GSREG_PR + 27, "PR27", "Program Register 27(String Source Bit Offset)", 4 },
        { V810::GSREG_PR + 28, "PR28", "Program Register 28(String Length)", 4 },
        { V810::GSREG_PR + 29, "PR29", "Program Register 29(String Dest)", 4 },
        { V810::GSREG_PR + 30, "PR30", "Program Register 30(String Source)", 4 },
        { V810::GSREG_PR + 31, "LP", "Program Register 31(Link Pointer)", 4 },

        { V810::GSREG_SR + 0, "SR0", "Exception/Interrupt PC", 4 },
        { V810::GSREG_SR + 1, "SR1", "Exception/Interrupt PSW", 4 },
        { V810::GSREG_SR + 2, "SR2", "Fatal Error PC", 4 },
        { V810::GSREG_SR + 3, "SR3", "Fatal Error PSW", 4 },
        { V810::GSREG_SR + 4, "SR4", "Exception Cause Register", 4 },
        { V810::GSREG_SR + 5, "SR5", "Program Status Word", 4 },
        { V810::GSREG_SR + 6, "SR6", "Processor ID Register", 4 },
        { V810::GSREG_SR + 7, "SR7", "Task Control Word", 4 },
        { V810::GSREG_SR + 24, "SR24", "Cache Control Word", 4 },
        { V810::GSREG_SR + 25, "SR25", "Address Trap Register", 4 },

	{ V810::GSREG_TIMESTAMP, "TStamp", "Timestamp", 3 },

        { 0, "", "", 0 },
};


static RegGroupType V810RegsGroup =
{
 NULL,
 V810Regs,
 VBDBG_GetRegister,
 VBDBG_SetRegister,
};

static uint32 MISC_GetRegister(const unsigned int id, char *special, const uint32 special_len)
{
 return(TIMER_GetRegister(id, special, special_len));
}

static void MISC_SetRegister(const unsigned int id, const uint32 value)
{
 TIMER_SetRegister(id, value);
}


static RegType Regs_Misc[] =
{
	{ TIMER_GSREG_TCR,	"TCR", "Timer Control Register", 1 },
	{ TIMER_GSREG_DIVCOUNTER, "DivCounter", "Timer Clock Divider Counter", 2 },
	{ TIMER_GSREG_RELOAD_VALUE, "ReloadValue", "Timer Reload Value", 2 },
	{ TIMER_GSREG_COUNTER, "Counter", "Timer Counter Value", 2 },
        { 0, "", "", 0 },
};

static RegGroupType RegsGroup_Misc =
{
        "Misc",
        Regs_Misc,
        MISC_GetRegister,
        MISC_SetRegister
};


static RegType Regs_VIP[] =
{
	{ VIP_GSREG_IPENDING,	"IPending", "Interrupts Pending", 2 },
	{ VIP_GSREG_IENABLE,	"IEnable", "Interrupts Enabled", 2 },

	{ VIP_GSREG_DPCTRL,	"DPCTRL", "DPCTRL", 2 },

	{ VIP_GSREG_BRTA,	"BRTA", "BRTA", 1 },
	{ VIP_GSREG_BRTB,	"BRTB", "BRTB", 1 },
	{ VIP_GSREG_BRTC,	"BRTC", "BRTC", 1 },
	{ VIP_GSREG_REST,	"REST", "REST", 1 },
	{ VIP_GSREG_FRMCYC,	"FRMCYC", "FRMCYC", 1 },
	{ VIP_GSREG_XPCTRL,	"XPCTRL", "XPCTRL", 2 },

	{ VIP_GSREG_SPT0,	"SPT0", "SPT0", 2 },
	{ VIP_GSREG_SPT1,	"SPT1", "SPT1", 2 },
	{ VIP_GSREG_SPT2,	"SPT2", "SPT2", 2 },
	{ VIP_GSREG_SPT3,	"SPT3", "SPT3", 2 },

	{ VIP_GSREG_GPLT0,	"GPLT0", "GPLT0", 1 },
	{ VIP_GSREG_GPLT1,	"GPLT1", "GPLT1", 1 },
	{ VIP_GSREG_GPLT2,	"GPLT2", "GPLT2", 1 },
	{ VIP_GSREG_GPLT3,	"GPLT3", "GPLT3", 1 },

	{ VIP_GSREG_JPLT0,	"JPLT0", "JPLT0", 1 },
	{ VIP_GSREG_JPLT1,	"JPLT1", "JPLT1", 1 },
	{ VIP_GSREG_JPLT2,	"JPLT2", "JPLT2", 1 },
	{ VIP_GSREG_JPLT3,	"JPLT3", "JPLT3", 1 },

	{ VIP_GSREG_BKCOL,	"BKCOL", "BKCOL", 1 },

        { 0, "", "", 0 },
};

static RegGroupType RegsGroup_VIP =
{
        "VIP",
        Regs_VIP,
        VIP_GetRegister,
        VIP_SetRegister
};


bool VBDBG_Init(void)
{
 BTEnabled = false;
 BTIndex = 0;
 memset(BTEntries, 0, sizeof(BTEntries));

 MDFNDBG_AddRegGroup(&V810RegsGroup);
 MDFNDBG_AddRegGroup(&RegsGroup_Misc);
 MDFNDBG_AddRegGroup(&RegsGroup_VIP);

 ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "cpu", "CPU Physical", 32);
// ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "ram", "RAM", 21);


 for(int x = 0; x < 5; x++)
 {
     AddressSpaceType newt;
     char tmpname[128], tmpinfo[128];

     trio_snprintf(tmpname, 128, "vsuwd%d", x);
     trio_snprintf(tmpinfo, 128, "VSU Wave Data %d", x);

     newt.GetAddressSpaceBytes = GetAddressSpaceBytes;
     newt.PutAddressSpaceBytes = PutAddressSpaceBytes;

     newt.name = std::string(tmpname);
     newt.long_name = std::string(tmpinfo);
     newt.TotalBits = 5;
     newt.NP2Size = 0;

     newt.IsWave = TRUE;
     newt.WaveFormat = ASPACE_WFMT_UNSIGNED;
     newt.WaveBits = 6;
     ASpace_Add(newt); //PSG_GetAddressSpaceBytes, PSG_PutAddressSpaceBytes, tmpname, tmpinfo, 5);
 }



 return(true);
}

}
