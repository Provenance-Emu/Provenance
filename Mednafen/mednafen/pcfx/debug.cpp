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

#include "pcfx.h"

#include <string.h>
#include <trio/trio.h>
#include <stdarg.h>
#include <iconv.h>

#include "debug.h"
#include <mednafen/hw_cpu/v810/v810_cpuD.h>
#include "interrupt.h"
#include "timer.h"
#include "king.h"
#include "rainbow.h"
#include "input.h"
#include <mednafen/cdrom/scsicd.h>

static void (*CPUHook)(uint32, bool bpoint) = NULL;
static bool CPUHookContinuous = false;
static void (*LogFunc)(const char *, const char *);
static iconv_t sjis_ict = (iconv_t)-1;
bool PCFX_LoggingOn = FALSE;

typedef struct __PCFX_BPOINT {
        uint32 A[2];
        int type;
        bool logical;
} PCFX_BPOINT;

static std::vector<PCFX_BPOINT> BreakPointsPC, BreakPointsRead, BreakPointsWrite, BreakPointsIORead, BreakPointsIOWrite;
static std::vector<PCFX_BPOINT> BreakPointsAux0Read, BreakPointsAux0Write;
static bool FoundBPoint = 0;

struct BTEntry
{
 uint32 from;
 uint32 to;
 uint32 branch_count;
 uint32 ecode;
};

#define NUMBT 24
static bool BTEnabled = false;
static BTEntry BTEntries[NUMBT];
static int BTIndex = 0;

static void AddBranchTrace(uint32 from, uint32 to, uint32 ecode)
{
 BTEntry *prevbt = &BTEntries[(BTIndex + NUMBT - 1) % NUMBT];

 //if(BTEntries[(BTIndex - 1) & 0xF] == PC) return;

 if(prevbt->from == from && prevbt->to == to && prevbt->ecode == ecode && prevbt->branch_count < 0xFFFFFFFF)
  prevbt->branch_count++;
 else
 {
  BTEntries[BTIndex].from = from;
  BTEntries[BTIndex].to = to;
  BTEntries[BTIndex].ecode = ecode;
  BTEntries[BTIndex].branch_count = 1;

  BTIndex = (BTIndex + 1) % NUMBT;
 }
}

void PCFXDBG_EnableBranchTrace(bool enable)
{
 BTEnabled = enable;
 if(!enable)
 {
  BTIndex = 0;
  memset(BTEntries, 0, sizeof(BTEntries));
 }
}

std::vector<BranchTraceResult> PCFXDBG_GetBranchTrace(void)
{
 BranchTraceResult tmp;
 std::vector<BranchTraceResult> ret;

 for(int x = 0; x < NUMBT; x++)
 {
  const BTEntry *bt = &BTEntries[(x + BTIndex) % NUMBT];

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

   case 0xFFC0:	// Address trap
	trio_snprintf(tmp.code, sizeof(tmp.code), "ADTR");
	break;

   case 0xFF90:	// Illegal/invalid instruction code
	trio_snprintf(tmp.code, sizeof(tmp.code), "ILL");
	break;

   case 0xFF80:	// Zero division
	trio_snprintf(tmp.code, sizeof(tmp.code), "ZD");
	break;

   case 0xFF70:
	trio_snprintf(tmp.code, sizeof(tmp.code), "FIV");	// FIV
	break;

   case 0xFF68:
	trio_snprintf(tmp.code, sizeof(tmp.code), "FZD");	// FZD
	break;

   case 0xFF64:
	trio_snprintf(tmp.code, sizeof(tmp.code), "FOV");	// FOV
	break;

   case 0xFF62:
	trio_snprintf(tmp.code, sizeof(tmp.code), "FUD");	// FUD
	break;

   case 0xFF61:
	trio_snprintf(tmp.code, sizeof(tmp.code), "FPR");	// FPR
	break;

   case 0xFF60:
	trio_snprintf(tmp.code, sizeof(tmp.code), "FRO");	// FRO
	break;
  }

  ret.push_back(tmp);
 }
 return(ret);
}

template<bool write>
static void SimuVDC(bool which_vdc, bool addr, unsigned value = 0)
{
 VDC_SimulateResult result;

 if(write)
  fx_vdc_chips[which_vdc]->SimulateWrite16(addr, value, &result);
 else
  fx_vdc_chips[which_vdc]->SimulateRead16(addr, &result);

 if(result.ReadCount)
  PCFXDBG_CheckBP(BPOINT_AUX_READ, 0x80000 | (which_vdc << 16) | result.ReadStart, 0, result.ReadCount);

 if(result.WriteCount)
  PCFXDBG_CheckBP(BPOINT_AUX_WRITE, 0x80000 | (which_vdc << 16) | result.WriteStart, 0/*FIXME(HOW? :b)*/, result.WriteCount);

 if(result.RegReadDone)
  PCFXDBG_CheckBP(BPOINT_AUX_READ, 0xA0000 | (which_vdc << 16) | result.RegRWIndex, 0, 1);

 if(result.RegWriteDone)
  PCFXDBG_CheckBP(BPOINT_AUX_WRITE, 0xA0000 | (which_vdc << 16) | result.RegRWIndex, 0, 1);
}

void PCFXDBG_CheckBP(int type, uint32 address, uint32 value, unsigned int len)
{
 std::vector<PCFX_BPOINT>::iterator bpit, bpit_end;

 if(type == BPOINT_READ)
 {
  bpit = BreakPointsRead.begin();
  bpit_end = BreakPointsRead.end();

  if(MDFN_UNLIKELY(address >= 0xA4000000 && address <= 0xABFFFFFF))
  {
   SimuVDC<false>((bool)(address & 0x8000000), 1);
  }
 }
 else if(type == BPOINT_WRITE)
 {
  bpit = BreakPointsWrite.begin();
  bpit_end = BreakPointsWrite.end();

  if(MDFN_UNLIKELY(address >= 0xB4000000 && address <= 0xBBFFFFFF))
  {
   SimuVDC<true>((bool)(address & 0x8000000), 1, value);
  }
 }
 else if(type == BPOINT_IO_READ)
 {
  bpit = BreakPointsIORead.begin();
  bpit_end = BreakPointsIORead.end();

  if(address >= 0x400 && address <= 0x5FF)
  {
   SimuVDC<false>((bool)(address & 0x100), (bool)(address & 4));
  }
 }
 else if(type == BPOINT_IO_WRITE)
 {
  bpit = BreakPointsIOWrite.begin();
  bpit_end = BreakPointsIOWrite.end();

  if(address >= 0x400 && address <= 0x5FF)
  {
   SimuVDC<true>((bool)(address & 0x100), (bool)(address & 4), value);
  }
 }
 else if(type == BPOINT_AUX_READ)
 {
  bpit = BreakPointsAux0Read.begin();
  bpit_end = BreakPointsAux0Read.end();
 }
 else if(type == BPOINT_AUX_WRITE)
 {
  bpit = BreakPointsAux0Write.begin();
  bpit_end = BreakPointsAux0Write.end();
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

enum
{
 SVT_NONE = 0,
 SVT_PTR,
 SVT_STRINGPTR,
 SVT_INT,
 SVT_UCHAR,
 SVT_LONG,
 SVT_ULONG,
};

typedef struct
{
 unsigned int number;
 const char *name;
 int arguments;
 int argument_types[16];
} syscall_t;

static const syscall_t SysDefs[] =
{
 {  0, "fsys_init", 3, { SVT_PTR, SVT_PTR, SVT_PTR} },
 {  1, "fsys_mount", 2, { SVT_PTR, SVT_PTR } },
 {  2, "fsys_ctrl", 4, { SVT_STRINGPTR, SVT_INT, SVT_PTR, SVT_INT } },
 {  3, "fsys_getfsys", 1, { SVT_PTR } },
 {  4, "fsys_format", 2, { SVT_PTR, SVT_PTR } },
 {  5, "fsys_diskfree", 1, { SVT_STRINGPTR } },
 {  6, "fsys_getblocks", 1, { SVT_PTR } },
 {  7, "fsys_open", 2, { SVT_STRINGPTR, SVT_INT } },
 {  8, "fsys_read", 3, { SVT_INT, SVT_PTR, SVT_INT } },
 {  9, "fsys_write", 3, { SVT_INT, SVT_PTR, SVT_INT } },
 { 10, "fsys_seek", 3, { SVT_INT, SVT_LONG, SVT_INT } },
 { 11, "fsys_htime", 2, { SVT_INT, SVT_LONG} },
 { 12, "fsys_close", 1, { SVT_INT } },
 { 13, "fsys_delete", 1, { SVT_STRINGPTR } },
 { 14, "fsys_rename", 2, { SVT_STRINGPTR } },
 { 15, "fsys_mkdir", 1, { SVT_STRINGPTR } },
 { 16, "fsys_rmdir", 1, { SVT_STRINGPTR } },
 { 17, "fsys_chdir", 1, { SVT_STRINGPTR } },
 { 18, "fsys_curdir", 1, { SVT_PTR } },
 { 19, "fsys_ffiles", 2, { SVT_PTR, SVT_PTR } },
 { 20, "fsys_nfiles", 1, { SVT_PTR } },
 { 21, "fsys_efiles", 1, { SVT_PTR } },
 { 22, "fsys_datetime", 1, { SVT_ULONG } },
 { 23, "fsys_m_init", 2, { SVT_PTR, SVT_PTR } },
 { 24, "fsys_malloc", 1, { SVT_INT } },
 { 25, "fsys_free", 1, { SVT_INT } },
 { 26, "fsys_setblock", 2, { SVT_PTR, SVT_INT } },
};

static void DoSyscallLog(void)
{
 uint32 ws = 0;
 unsigned int which = 0;
 unsigned int nargs = 0;
 const char *func_name = "<unknown>";
 char argsbuffer[2048];

 for(unsigned int i = 0; i < sizeof(SysDefs) / sizeof(syscall_t); i++)
 {
  if(SysDefs[i].number == PCFX_V810.GetPR(10))
  {
   nargs = SysDefs[i].arguments;
   func_name = SysDefs[i].name;
   which = i;
   break;
  }
 }

 {
  char *pos = argsbuffer;

  argsbuffer[0] = 0;

  pos += trio_sprintf(pos, "(");
  for(unsigned int i = 0; i < nargs; i++)
  {
   if(SysDefs[which].argument_types[i] == SVT_STRINGPTR)
   {
    uint8 quickiebuf[64 + 1];
    int qbuf_index = 0;
    bool error_thing = FALSE;

    do
    {
     uint32 A = PCFX_V810.GetPR(6 + i) + qbuf_index;

     quickiebuf[qbuf_index] = 0;

     if(A >= 0x80000000 && A < 0xF0000000)
     {
      error_thing = TRUE;
      break;
     }

     quickiebuf[qbuf_index] = mem_peekbyte(ws, A);
    } while(quickiebuf[qbuf_index] && ++qbuf_index < 64);

    if(qbuf_index == 64) 
     error_thing = TRUE;

    quickiebuf[64] = 0;

    if(error_thing)
     pos += trio_sprintf(pos, "0x%08x, ", PCFX_V810.GetPR(6 + i));
    else
    {
	uint8 quickiebuf_utf8[64 * 6 + 1];
	char *in_ptr, *out_ptr;
	size_t ibl, obl;

	ibl = qbuf_index;
	obl = sizeof(quickiebuf_utf8) - 1;

	in_ptr = (char *)quickiebuf;
	out_ptr = (char *)quickiebuf_utf8;

	if(iconv(sjis_ict, (ICONV_CONST char **)&in_ptr, &ibl, &out_ptr, &obl) == (size_t) -1)
	{
	 pos += trio_sprintf(pos, "0x%08x, ", PCFX_V810.GetPR(6 + i));
	}
	else
	{
	 *out_ptr = 0;
	 pos += trio_sprintf(pos, "@0x%08x=\"%s\", ", PCFX_V810.GetPR(6 + i), quickiebuf_utf8);
	}
    }
   }
   else
    pos += trio_sprintf(pos, "0x%08x, ", PCFX_V810.GetPR(6 + i));
  }

  // Get rid of the trailing comma and space
  if(nargs)
   pos-=2;

  trio_sprintf(pos, ");");
 }

 PCFXDBG_DoLog("SYSCALL", "0x%02x, %s: %s", PCFX_V810.GetPR(10), func_name, argsbuffer);
}

static void CPUHandler(const v810_timestamp_t timestamp, uint32 PC)
{
 std::vector<PCFX_BPOINT>::iterator bpit;

 for(bpit = BreakPointsPC.begin(); bpit != BreakPointsPC.end(); bpit++)
 {
  if(PC >= bpit->A[0] && PC <= bpit->A[1])
  {
   FoundBPoint = TRUE;
   break;
  }
 }

 fx_vdc_chips[0]->ResetSimulate();
 fx_vdc_chips[1]->ResetSimulate();

 PCFX_V810.CheckBreakpoints(PCFXDBG_CheckBP, mem_peekhword, NULL);	// FIXME: mem_peekword

 if(PCFX_LoggingOn)
 {
  // FIXME:  There is a little race condition if a user turns on logging right between jump instruction and the first
  // instruction at 0xFFF0000C, in which case the call-from address will be wrong.
  static uint32 lastPC = ~0;

  if(PC == 0xFFF0000C)
  {
   static const char *font_sizes[6] =
   {
    "KANJI16x16", "KANJI12x12", "ANK8x16", "ANK6x12", "ANK8x8", "ANK8x12"
   };

   // FIXME, overflow possible and speed
   PCFXDBG_DoLog("ROMFONT", "0x%08x->0xFFF0000C, PR7=0x%08x=%s, PR6=0x%04x = %s", lastPC, PCFX_V810.GetPR(7), (PCFX_V810.GetPR(7) > 5) ? "?" : font_sizes[PCFX_V810.GetPR(7)], PCFX_V810.GetPR(6) & 0xFFFF, PCFXDBG_ShiftJIS_to_UTF8(PCFX_V810.GetPR(6) & 0xFFFF));
   setvbuf(stdout, NULL, _IONBF, 0);
   printf("%s", PCFXDBG_ShiftJIS_to_UTF8(PCFX_V810.GetPR(6) & 0xFFFF));
  }
  else if(PC == 0xFFF00008)
   DoSyscallLog();

  lastPC = PC;
 }

 CPUHookContinuous |= FoundBPoint;

 if(CPUHookContinuous && CPUHook)
 {
  ForceEventUpdates(timestamp);
  CPUHook(PC, FoundBPoint);
 }

 FoundBPoint = false;
}

static void RedoCPUHook(void)
{
 bool HappyTest;

 HappyTest = CPUHook || PCFX_LoggingOn || BreakPointsPC.size() || BreakPointsRead.size() || BreakPointsWrite.size() ||
		BreakPointsIOWrite.size() || BreakPointsIORead.size() || BreakPointsAux0Read.size() || BreakPointsAux0Write.size();

 PCFX_V810.SetCPUHook(HappyTest ? CPUHandler : NULL, BTEnabled ? AddBranchTrace : NULL);
}

static void PCFXDBG_FlushBreakPoints(int type)
{
 std::vector<PCFX_BPOINT>::iterator bpit;

 if(type == BPOINT_READ)
  BreakPointsRead.clear();
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.clear();
 else if(type == BPOINT_IO_READ)
  BreakPointsIORead.clear();
 else if(type == BPOINT_IO_WRITE)
  BreakPointsIOWrite.clear();
 else if(type == BPOINT_AUX_READ)
  BreakPointsAux0Read.clear();
 else if(type == BPOINT_AUX_WRITE)
  BreakPointsAux0Write.clear();
 else if(type == BPOINT_PC)
  BreakPointsPC.clear();

 RedoCPUHook();
 KING_NotifyOfBPE(BreakPointsAux0Read.size(), BreakPointsAux0Write.size());
}

static void PCFXDBG_AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical)
{
 PCFX_BPOINT tmp;

 tmp.A[0] = A1;
 tmp.A[1] = A2;
 tmp.type = type;

 if(type == BPOINT_READ)
  BreakPointsRead.push_back(tmp);
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.push_back(tmp);
 else if(type == BPOINT_IO_READ)
  BreakPointsIORead.push_back(tmp);
 else if(type == BPOINT_IO_WRITE)
  BreakPointsIOWrite.push_back(tmp);
 else if(type == BPOINT_AUX_READ)
  BreakPointsAux0Read.push_back(tmp);
 else if(type == BPOINT_AUX_WRITE)
  BreakPointsAux0Write.push_back(tmp);
 else if(type == BPOINT_PC)
  BreakPointsPC.push_back(tmp);

 RedoCPUHook();
 KING_NotifyOfBPE(BreakPointsAux0Read.size(), BreakPointsAux0Write.size());
}

static uint16 dis_readhw(uint32 A)
{
 return(mem_peekhword(0, A));
}

static void PCFXDBG_Disassemble(uint32 &a, uint32 SpecialA, char *TextBuf)
{
 return(v810_dis(a, 1, TextBuf, dis_readhw));
}

static uint32 PCFXDBG_MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical)
{
 uint32 ret = 0;
 uint32 ws = 0;

 for(unsigned int i = 0; i < bsize; i++)
 {
  A &= 0xFFFFFFFF;
  ret |= mem_peekbyte(ws, A) << (i * 8);
  A++;
 }

 return(ret);
}

static uint32 PCFXDBG_GetRegister(const unsigned int id, char *special, const uint32 special_len)
{
 switch(id >> 16)
 {
  case 0: return PCFX_V810.GetRegister(id & 0xFFFF, special, special_len);
  case 1: return PCFXIRQ_GetRegister(id & 0xFFFF, special, special_len);
  case 2: return FXTIMER_GetRegister(id & 0xFFFF, special, special_len);
  case 3: return FXINPUT_GetRegister(id & 0xFFFF, special, special_len);
 }

 return 0xDEADBEEF;
}

static void PCFXDBG_SetRegister(const unsigned int id, uint32 value)
{
 switch(id >> 16)
 {
  case 0: PCFX_V810.SetRegister(id & 0xFFFF, value); break;
  case 1: PCFXIRQ_SetRegister(id & 0xFFFF, value); break;
  case 2: FXTIMER_SetRegister(id & 0xFFFF, value); break;
  case 3: FXINPUT_SetRegister(id & 0xFFFF, value); break;
 }
}

static void PCFXDBG_SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous)
{
 CPUHook = callb;
 CPUHookContinuous = continuous;
 RedoCPUHook();
}

void PCFXDBG_DoLog(const char *type, const char *format, ...)
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

void PCFXDBG_SetLogFunc(void (*func)(const char *, const char *))
{
 LogFunc = func;

 PCFX_LoggingOn = func ? TRUE : FALSE;
 SCSICD_SetLog(func ? PCFXDBG_DoLog : NULL);
 KING_SetLogFunc(func ? PCFXDBG_DoLog : NULL);

 if(PCFX_LoggingOn)
 {
  if(sjis_ict == (iconv_t)-1)
   sjis_ict = iconv_open("UTF-8", "shift_jis");
 }
 else
 {
  if(sjis_ict != (iconv_t)-1)
  {
   iconv_close(sjis_ict);
   sjis_ict = (iconv_t)-1;
  }
 }
 RedoCPUHook();
}

char *PCFXDBG_ShiftJIS_to_UTF8(const uint16 sjc)
{
 static char ret[16];
 char inbuf[3];
 char *in_ptr, *out_ptr;
 size_t ibl, obl;

 if(sjc < 256)
 {
  inbuf[0] = sjc;
  inbuf[1] = 0;
  ibl = 1;
 }
 else
 {
  inbuf[0] = sjc >> 8;
  inbuf[1] = sjc >> 0;
  inbuf[2] = 0;
  ibl = 2;
 }

 in_ptr = inbuf;
 out_ptr = ret;  
 obl = 16;

 iconv(sjis_ict, (ICONV_CONST char **)&in_ptr, &ibl, &out_ptr, &obl);

 *out_ptr = 0;

 return(ret);
}

static RegType PCFXRegs0[] =
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

	{ (1 << 16) | PCFXIRQ_GSREG_IPEND, "IPEND", "Interrupts Pending", 2 },
        { (1 << 16) | PCFXIRQ_GSREG_IMASK, "IMASK", "Interrupt Mask", 2 },
        { (1 << 16) | PCFXIRQ_GSREG_IPRIO0, "IPRIO0", "Interrupt Priority Register 0", 2 },
        { (1 << 16) | PCFXIRQ_GSREG_IPRIO1, "IPRIO1", "Interrupt Priority Register 1", 2 },

        { (2 << 16) | FXTIMER_GSREG_TCTRL, "TCTRL", "Timer Control", 2 },
        { (2 << 16) | FXTIMER_GSREG_TPRD, "TPRD", "Timer Period", 2 },
        { (2 << 16) | FXTIMER_GSREG_TCNTR, "TCNTR", "Timer Counter", 3 },

	{ (3 << 16) | FXINPUT_GSREG_KPCTRL0, "KPCTRL0", "Keyport 0 Control", 1 },
	{ (3 << 16) | FXINPUT_GSREG_KPCTRL1, "KPCTRL1", "Keyport 1 Control", 1 },

	{ V810::GSREG_TIMESTAMP, "TStamp", "Timestamp", 3 },
        { 0, "", "", 0 },
};

static RegType KINGRegs0[] =
{
	{ KING_GSREG_AR, "AR", "Active Register", 1 },
	{ KING_GSREG_MPROGADDR, "MPROGADDR", "Micro-program Address", 2 },
        { KING_GSREG_MPROGCTRL, "MPROGCTRL", "Micro-program Control", 2 },

	{ KING_GSREG_PAGESET, "PAGESET", "KRAM Page Settings", 2 },
        { KING_GSREG_RTCTRL, "RTCTRL", "Rainbow Transfer Control", 2 },
        { KING_GSREG_RKRAMA, "RKRAMA", "Rainbow Transfer K-RAM Address", 3},
        { KING_GSREG_RSTART, "RSTART", "Rainbow Transfer Start Position", 2},
        { KING_GSREG_RCOUNT, "RCOUNT", "Rainbow Transfer Block Count", 2 },
        { KING_GSREG_RIRQLINE, "RIRQLINE", "Raster IRQ Line", 2 },
	{ KING_GSREG_KRAMWA, "KRAMWA", "K-RAM Write Address", 4 },
	{ KING_GSREG_KRAMRA, "KRAMRA", "K-RAM Read Address", 4 },
        { KING_GSREG_DMATA, "DMATA", "DMA Transfer Address", 3 },
        { KING_GSREG_DMATS, "DMATS", "DMA Transfer Size", 4 },
        { KING_GSREG_DMASTT, "DMASTT", "DMA Status", 2 },
        { KING_GSREG_ADPCMCTRL, "ADPCMCTRL", "ADPCM Control", 2 },
        { KING_GSREG_ADPCMBM0, "ADPCMBM0", "ADPCM Buffer Mode Ch0", 2 },
        { KING_GSREG_ADPCMBM1, "ADPCMBM1", "ADPCM Buffer Mode Ch1", 2 },
        { KING_GSREG_ADPCMPA0, "ADPCMPA0", "ADPCM PlayAddress Ch0", 0x100 | 18 },
        { KING_GSREG_ADPCMPA1, "ADPCMPA1", "ADPCM PlayAddress Ch1", 0x100 | 18 },
        { KING_GSREG_ADPCMSA0, "ADPCMSA0", "ADPCM Start Address Ch0", 2 },
        { KING_GSREG_ADPCMSA1, "ADPCMSA1", "ADPCM Start Address Ch1", 2 },
        { KING_GSREG_ADPCMIA0, "ADPCMIA0", "ADPCM Intermediate Address Ch0", 2 },
        { KING_GSREG_ADPCMIA1, "ADPCMIA1", "ADPCM Intermediate Address Ch1", 2 },
        { KING_GSREG_ADPCMEA0, "ADPCMEA0", "ADPCM End Address Ch0", 0x100 | 18 },
        { KING_GSREG_ADPCMEA1, "ADPCMEA1", "ADPCM End Address Ch1", 0x100 | 18 },
	{ KING_GSREG_ADPCMStat, "ADPCMStat", "ADPCM Status Register", 1 },
	{ KING_GSREG_Reg01, "Reg01", "KING Register 0x01", 1 },
	{ KING_GSREG_Reg02, "Reg02", "KING Register 0x02", 1 },
	{ KING_GSREG_Reg03, "Reg03", "KING Register 0x03", 1 },
	{ KING_GSREG_SUBCC, "SUBCC", "Sub-channel Control", 1 },
	{ 0, "------", "", 0xFFFF },
	{ KING_GSREG_DB, "DB", "SCSI Data Bus", 0x100 | 8 },
	{ KING_GSREG_BSY, "BSY", "SCSI BSY", 0x100 | 1 },
	{ KING_GSREG_REQ, "REQ", "SCSI REQ", 0x100 | 1 },
	{ KING_GSREG_ACK, "ACK", "SCSI ACK", 0x100 | 1 },
	{ KING_GSREG_MSG, "MSG", "SCSI MSG", 0x100 | 1 },
	{ KING_GSREG_IO, "IO", "SCSI IO", 0x100 | 1 },
	{ KING_GSREG_CD, "CD", "SCSI CD", 0x100 | 1 },
	{ KING_GSREG_SEL, "SEL", "SCSI SEL", 0x100 | 1 },

        { 0, "", "", 0 },
};

static RegType KINGRegs1[] =
{
	{ 0, "-KING BG-", "", 0xFFFF },

        { KING_GSREG_BGMODE, "Mode", "Background Mode", 2 },
        { KING_GSREG_BGPRIO, "Prio", "Background Priority", 2 },
        { KING_GSREG_BGSCRM, "ScrM", "Background Scroll Mode", 2 },

	{ 0, "--KBG0:--", "", 0xFFFF },
        { KING_GSREG_BGSIZ0, "Size", "Background 0 Size", 2 },
        { KING_GSREG_BGBAT0, "BAT", "Background 0 BAT Address", 1 },
        { KING_GSREG_BGCG0, "CG", "Background 0 CG Address", 1 },
        { KING_GSREG_BGBATS, "SubBAT", "Background 0 SUB BAT Address", 1 },
        { KING_GSREG_BGCGS, "SubCG", "Background 0 SUB CG Address", 1 },
        { KING_GSREG_BGXSC0, "XScr", "Background 0 X Scroll", 0x100 | 11 },
        { KING_GSREG_BGYSC0, "YScr", "Background 0 Y Scroll", 0x100 | 11 },

	{ 0, "--KBG1:--", "", 0xFFFF },
        { KING_GSREG_BGSIZ1, "Size", "Background 1 Size", 1 },
        { KING_GSREG_BGBAT1, "BAT", "Background 1 BAT Address", 1 },
        { KING_GSREG_BGCG1, "CG", "Background 1 CG Address", 1 },
        { KING_GSREG_BGXSC1, "XScr", "Background 1 X Scroll", 0x100 | 10 },
        { KING_GSREG_BGYSC1, "YScr", "Background 1 Y Scroll", 0x100 | 10 },

	{ 0, "--KBG2:--", "", 0xFFFF },
        { KING_GSREG_BGSIZ2, "Size", "Background 2 Size", 1 },
        { KING_GSREG_BGBAT2, "BAT", "Background 2 BAT Address", 1 },
        { KING_GSREG_BGCG2, "CG", "Background 2 CG Address", 1 },
        { KING_GSREG_BGXSC2, "XScr", "Background 2 X Scroll", 0x100 | 10 },
        { KING_GSREG_BGYSC2, "YScr", "Background 2 Y Scroll", 0x100 | 10 },

	{ 0, "--KBG3:--", "", 0xFFFF },
        { KING_GSREG_BGSIZ3, "Size", "Background 3 Size", 1 },
        { KING_GSREG_BGBAT3, "BAT", "Background 3 BAT Address", 1 },
        { KING_GSREG_BGCG3, "CG", "Background 3 CG Address", 1 },
        { KING_GSREG_BGXSC3, "XScr", "Background 3 X Scroll", 0x100 | 10 },
        { KING_GSREG_BGYSC3, "YScr", "Background 3 Y Scroll", 0x100 | 10 },


	{ 0, "--AFFIN:--", "", 0xFFFF },
	{ KING_GSREG_AFFINA, "A", "Background Affin Coefficient A", 2 },
	{ KING_GSREG_AFFINB, "B", "Background Affin Coefficient B", 2 },
	{ KING_GSREG_AFFINC, "C", "Background Affin Coefficient C", 2 },
	{ KING_GSREG_AFFIND, "D", "Background Affin Coefficient D", 2 },
	{ KING_GSREG_AFFINX, "X", "Background Affin Center X", 2 },
	{ KING_GSREG_AFFINY, "Y", "Background Affin Center Y", 2 },

	{ 0, "--MPROG:--", "", 0xFFFF },
	{ KING_GSREG_MPROG0, "0", "Micro-program", 2},
	{ KING_GSREG_MPROG1, "1", "Micro-program", 2},
	{ KING_GSREG_MPROG2, "2", "Micro-program", 2},
	{ KING_GSREG_MPROG3, "3", "Micro-program", 2},
	{ KING_GSREG_MPROG4, "4", "Micro-program", 2},
	{ KING_GSREG_MPROG5, "5", "Micro-program", 2},
	{ KING_GSREG_MPROG6, "6", "Micro-program", 2},
	{ KING_GSREG_MPROG7, "7", "Micro-program", 2},
	{ KING_GSREG_MPROG8, "8", "Micro-program", 2},
	{ KING_GSREG_MPROG9, "9", "Micro-program", 2},
	{ KING_GSREG_MPROGA, "A", "Micro-program", 2},
	{ KING_GSREG_MPROGB, "B", "Micro-program", 2},
	{ KING_GSREG_MPROGC, "C", "Micro-program", 2},
	{ KING_GSREG_MPROGD, "D", "Micro-program", 2},
	{ KING_GSREG_MPROGE, "E", "Micro-program", 2},
	{ KING_GSREG_MPROGF, "F", "Micro-program", 2},

	{ 0, "", "", 0 },
};

static uint32 GetRegister_VCERAINBOW(const unsigned int id, char *special, const uint32 special_len)
{
 if(id >> 16)
  return RAINBOW_GetRegister(id & 0xFFFF, special, special_len);
 else
  return FXVCE_GetRegister(id & 0xFFFF, special, special_len);
}

static void SetRegister_VCERAINBOW(const unsigned int id, uint32 value)
{
 if(id >> 16)
  RAINBOW_SetRegister(id & 0xFFFF, value);
 else
  FXVCE_SetRegister(id & 0xFFFF, value);
} 

static RegType VCERAINBOWRegs[] =
{
	{ 0, "--VCE--", "", 0xFFFF },
        { FXVCE_GSREG_Line, "Line", "VCE Frame Counter", 0x100 | 9 },
        { FXVCE_GSREG_PRIO0, "PRIO0", "VCE Priority 0", 0x100 | 12 },
        { FXVCE_GSREG_PRIO1, "PRIO1", "VCE Priority 1", 2 },
        { FXVCE_GSREG_PICMODE, "PICMODE", "VCE Picture Mode", 2},
        { FXVCE_GSREG_PALRWOF, "PALRWOF", "VCE Palette R/W Offset", 2 },
        { FXVCE_GSREG_PALRWLA, "PALRWLA", "VCE Palette R/W Latch", 2 },
        { FXVCE_GSREG_PALOFS0, "PALOFS0", "VCE Palette Offset 0", 2 } ,
        { FXVCE_GSREG_PALOFS1, "PALOFS1", "VCE Palette Offset 1", 2 },
        { FXVCE_GSREG_PALOFS2, "PALOFS2", "VCE Palette Offset 2", 2 },
        { FXVCE_GSREG_PALOFS3, "PALOFS3", "VCE Palette Offset 3", 1 },
        { FXVCE_GSREG_CCR, "CCR", "VCE Fixed Color Register", 2 },
        { FXVCE_GSREG_BLE, "BLE", "VCE Cellophane Setting Register", 2 },
        { FXVCE_GSREG_SPBL, "SPBL", "VCE Sprite Cellophane Setting Register", 2 },
        { FXVCE_GSREG_COEFF0, "COEFF0", "VCE Cellophane Coefficient 0(1A)", 0x100 | 12 },
        { FXVCE_GSREG_COEFF1, "COEFF1", "VCE Cellophane Coefficient 1(1B)", 0x100 | 12 },
        { FXVCE_GSREG_COEFF2, "COEFF2", "VCE Cellophane Coefficient 2(2A)", 0x100 | 12 },
        { FXVCE_GSREG_COEFF3, "COEFF3", "VCE Cellophane Coefficient 3(2B)", 0x100 | 12 },
        { FXVCE_GSREG_COEFF4, "COEFF4", "VCE Cellophane Coefficient 4(3A)", 0x100 | 12 },
        { FXVCE_GSREG_COEFF5, "COEFF5", "VCE Cellophane Coefficient 5(3B)", 0x100 | 12 },
        { FXVCE_GSREG_CKeyY, "CKeyY", "VCE Chroma Key Y", 2 },
        { FXVCE_GSREG_CKeyU, "CKeyU", "VCE Chroma Key U", 2 },
        { FXVCE_GSREG_CKeyV, "CKeyV", "VCE Chroma Key V", 2 },

	{ 0, "---------", "", 0xFFFF },
	{ 0, "-RAINBOW-", "", 0xFFFF },

	{ (1 << 16) | RAINBOW_GSREG_RSCRLL, "RSCRLL", "Rainbow Horizontal Scroll", 2 },
	{ (1 << 16) | RAINBOW_GSREG_RCTRL, "RCTRL", "Rainbow Control", 2 },
	{ (1 << 16) | RAINBOW_GSREG_RHSYNC, "RHSYNC", "Rainbow HSync?", 1 },
	{ (1 << 16) | RAINBOW_GSREG_RNRY, "RNRY", "Rainbow Null Run Y", 2 },
	{ (1 << 16) | RAINBOW_GSREG_RNRU, "RNRU", "Rainbow Null Run U", 2 },
	{ (1 << 16) | RAINBOW_GSREG_RNRV, "RNRV", "Rainbow Null Run V", 2 },

        { 0, "", "", 0 },
};

static uint32 GetRegister_VDC(const unsigned int id, char *special, const uint32 special_len)
{
 return(fx_vdc_chips[(id >> 15) & 1]->GetRegister(id &~0x8000, special, special_len));
}

static void SetRegister_VDC(const unsigned int id, uint32 value)
{
 fx_vdc_chips[(id >> 15) & 1]->SetRegister(id &~0x8000, value);
} 


static RegType VDCRegs[] =
{
        { 0, "--VDC-A--", "", 0xFFFF },
	
        { VDC::GSREG_SELECT, "Select", "Register Select, VDC-A", 1 },
        { VDC::GSREG_STATUS, "Status", "Status, VDC-A", 1 },

        { VDC::GSREG_MAWR, "MAWR", "Memory Write Address, VDC-A", 2 },
        { VDC::GSREG_MARR, "MARR", "Memory Read Address, VDC-A", 2 },
        { VDC::GSREG_CR, "CR", "Control, VDC-A", 2 },
        { VDC::GSREG_RCR, "RCR", "Raster Counter, VDC-A", 2 },
        { VDC::GSREG_BXR, "BXR", "X Scroll, VDC-A", 2 },
        { VDC::GSREG_BYR, "BYR", "Y Scroll, VDC-A", 2 },
        { VDC::GSREG_MWR, "MWR", "Memory Width, VDC-A", 2 },

        { VDC::GSREG_HSR, "HSR", "HSR, VDC-A", 2 },
        { VDC::GSREG_HDR, "HDR", "HDR, VDC-A", 2 },
        { VDC::GSREG_VSR, "VSR", "VSR, VDC-A", 2 },
        { VDC::GSREG_VDR, "VDR", "VDR, VDC-A", 2 },

        { VDC::GSREG_VCR, "VCR", "VCR, VDC-A", 2 },
        { VDC::GSREG_DCR, "DCR", "DMA Control, VDC-A", 2 },
        { VDC::GSREG_SOUR, "SOUR", "VRAM DMA Source Address, VDC-A", 2 },
        { VDC::GSREG_DESR, "DESR", "VRAM DMA Dest Address, VDC-A", 2 },
        { VDC::GSREG_LENR, "LENR", "VRAM DMA Length, VDC-A", 2 },
        { VDC::GSREG_DVSSR, "DVSSR", "DVSSR Update Address, VDC-A", 2 },
        { 0, "------", "", 0xFFFF },

        { 0, "--VDC-B--", "", 0xFFFF },

        { 0x8000 | VDC::GSREG_SELECT, "Select", "Register Select, VDC-B", 1 },
        { 0x8000 | VDC::GSREG_STATUS, "Status", "Status, VDC-B", 1 },

        { 0x8000 | VDC::GSREG_MAWR, "MAWR", "Memory Write Address, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_MARR, "MARR", "Memory Read Address, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_CR, "CR", "Control, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_RCR, "RCR", "Raster Counter, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_BXR, "BXR", "X Scroll, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_BYR, "BYR", "Y Scroll, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_MWR, "MWR", "Memory Width, VDC-B", 2 },

        { 0x8000 | VDC::GSREG_HSR, "HSR", "HSR, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_HDR, "HDR", "HDR, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_VSR, "VSR", "VSR, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_VDR, "VDR", "VDR, VDC-B", 2 },

        { 0x8000 | VDC::GSREG_VCR, "VCR", "VCR, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_DCR, "DCR", "DMA Control, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_SOUR, "SOUR", "VRAM DMA Source Address, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_DESR, "DESR", "VRAM DMA Dest Address, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_LENR, "LENR", "VRAM DMA Length, VDC-B", 2 },
        { 0x8000 | VDC::GSREG_DVSSR, "DVSSR", "DVSSR Update Address, VDC-B", 2 },

        { 0, "", "", 0 },
};

static RegGroupType PCFXRegs0Group =
{
 NULL,
 PCFXRegs0,
 PCFXDBG_GetRegister,
 PCFXDBG_SetRegister,
};

static RegGroupType KINGRegs0Group =
{
 NULL,
 KINGRegs0,
 KING_GetRegister,
 KING_SetRegister
};

static RegGroupType KINGRegs1Group =
{
 NULL,
 KINGRegs1,
 KING_GetRegister,
 KING_SetRegister
};

static RegGroupType VCERAINBOWRegsGroup =
{
 NULL,
 VCERAINBOWRegs,
 GetRegister_VCERAINBOW,
 SetRegister_VCERAINBOW
};

static RegGroupType VDCRegsGroup =
{
 NULL,
 VDCRegs,
 GetRegister_VDC,
 SetRegister_VDC
};

void PCFXDBG_Init(void)
{
 MDFNDBG_AddRegGroup(&PCFXRegs0Group);
 MDFNDBG_AddRegGroup(&VCERAINBOWRegsGroup);
 MDFNDBG_AddRegGroup(&VDCRegsGroup);
 MDFNDBG_AddRegGroup(&KINGRegs1Group);
 MDFNDBG_AddRegGroup(&KINGRegs0Group);
}

static void ForceIRQ(int level)
{
 //v810_int(level);
}

DebuggerInfoStruct PCFXDBGInfo =
{
 "shift_jis",
 4,
 2,             // Instruction alignment(bytes)
 32,
 32,
 0x00000000,
 ~0U,

 PCFXDBG_MemPeek,
 PCFXDBG_Disassemble,
 NULL,
 ForceIRQ,
 NULL,
 PCFXDBG_FlushBreakPoints,
 PCFXDBG_AddBreakPoint,
 PCFXDBG_SetCPUCallback,
 PCFXDBG_EnableBranchTrace,
 PCFXDBG_GetBranchTrace,
 KING_SetGraphicsDecode,
 PCFXDBG_SetLogFunc,
};

