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

#ifdef MDFN_ENABLE_DEV_BUILD
namespace DBG
{
static void RedoHooks(void) { }

enum { NUMBT = 64 };

struct BTEntry
{
 uint32 from;
 uint32 to;
 uint32 vector;
 uint32 branch_count;
 bool valid;
};

static BTEntry BTEntries[NUMBT];
static int BTIndex;
static bool BTEnabled;
static uint16 PrevPC;

static void AddBranchTrace(uint16 to, uint16 vector)
{
 BTEntry *prevbt = &BTEntries[(BTIndex + NUMBT - 1) % NUMBT];
 const uint16 from = PrevPC;

 //if(BTEntries[(BTIndex - 1) & 0xF] == PC) return;

 if(prevbt->from == from && prevbt->to == to && prevbt->vector == vector && prevbt->branch_count < 0xFFFFFFFF && prevbt->valid)
  prevbt->branch_count++;
 else
 {
  BTEntries[BTIndex].from = from;
  BTEntries[BTIndex].to = to;
  BTEntries[BTIndex].vector = vector;
  BTEntries[BTIndex].branch_count = 1;
  BTEntries[BTIndex].valid = true;

  BTIndex = (BTIndex + 1) % NUMBT;
 }
}

static void EnableBranchTrace(bool enable)
{
 BTEnabled = enable;
 if(!enable)
 {
  BTIndex = 0;
  memset(BTEntries, 0, sizeof(BTEntries));
 }
 RedoHooks();
}

static std::vector<BranchTraceResult> GetBranchTrace(void)
{
 BranchTraceResult tmp;
 std::vector<BranchTraceResult> ret;

 for(int x = 0; x < NUMBT; x++)
 {
  const BTEntry *bt = &BTEntries[(x + BTIndex) % NUMBT];

  if(!bt->valid)
   continue;

  tmp.count = bt->branch_count;
  trio_snprintf(tmp.from, sizeof(tmp.from), "%04X", bt->from);
  trio_snprintf(tmp.to, sizeof(tmp.to), "%04X", bt->to);

  tmp.code[1] = 0;
  switch(bt->vector)
  {
   default: tmp.code[0] = 0;
            break;

   case 0xFFFC:
        tmp.code[0] = 'R';      // RESET
        break;

   case 0xFFFA:
        tmp.code[0] = 'N';      // NMI
        break;

   case 0xFFFE:
        tmp.code[0] = 'I';      // IRQ
        break;

   case 0xFFFF:
        tmp.code[0] = 'B';      // BRK
        break;
  }

  ret.push_back(tmp);
 }
 return(ret);
}

static uint32 MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical)
{
 uint32 ret = 0;

 for(unsigned int i = 0; i < bsize; i++)
 {
  ret |= PeekMem(A) << (i * 8);
  A++;
 }

 return ret;
}

static void MemPoke(uint32 A, uint32 V, unsigned int bsize, bool hl, bool logical)
{
/*
 MDFN_HIDE extern uint8 *Page[32];

 for(unsigned int i = 0; i < bsize; i++)
 {
  A &= 0xFFFF;
  if(hl)
  {
   if(Page[A/2048])
    Page[A/2048][A] = V & 0xFF;
  }
  else
   BWrite[A](A,V & 0xFF);

  V >>= 8;
  A++;
 }
*/
}

static void GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer)
{
 if(!strcmp(name, "cpu"))
 {
  while(Length--)
  {
   *Buffer = PeekMem(Address);

   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "ram"))
 {
  while(Length--)
  {
   Address %= RAMSize;
   *Buffer = RAM[Address];

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
   // FIXME
/*
   Address &= 0xFFFF;
   if(Address < 0xC000)
   {
    size_t offs = GetRAMOffs_IIE(
    const bool aux = (bool)(SoftSwitch & ((Address < 0x200) ? SOFTSWITCH_ALTZP : SOFTSWITCH_RAMWRT));
    size_t offs = WriteSelectAuxBank_IIE
    RAM[(aux << 16) + Address] = *Buffer;
   }
*/
   Address++;
   Buffer++;
  }
 }
 else if(!strcmp(name, "ram"))
 {
  while(Length--)
  {
   Address %= RAMSize;
   RAM[Address] = *Buffer;

   Address++;
   Buffer++;
  }
 }
}


static void IRQ(int level)
{


}

static uint32 GetVector(int level)
{
 return 0;
}

class Dis2A03 : public MDFN_IEN_NES::Dis6502
{
	public:
	Dis2A03(void)
	{

	}

	uint8 GetX(void)
	{
	 return CPU.X;
	}

	uint8 GetY(void)
	{
	 return CPU.Y;
	}

	uint8 Read(uint16 A)
	{
	 return PeekMem(A);
	}
};

static Dis2A03 DisObj;

static void Disassemble(uint32 &a, uint32 SpecialA, char *TextBuf)
{
	uint16 tmpa = a;
	std::string ret;

	DisObj.Disassemble(tmpa, SpecialA, TextBuf);

	a = tmpa;
}

struct BPOINT
{
	unsigned int A[2];
	int type;
};

static std::vector<BPOINT> BreakPointsPC, BreakPointsRead, BreakPointsWrite;

static void (*CPUHook)(uint32 PC, bool) = NULL;
static bool CPUHookContinuous = false;
static bool FoundBPoint = 0;

static void CPUHandler(void)
{
 const uint32 PC = CPU.PC;
 std::vector<BPOINT>::iterator bpit;

 for(bpit = BreakPointsPC.begin(); bpit != BreakPointsPC.end(); bpit++)
 {
  if(PC >= bpit->A[0] && PC <= bpit->A[1])
  {
   FoundBPoint = true;
   break;
  }
 }

 CPUHookContinuous |= FoundBPoint;
 if(CPUHookContinuous && CPUHook)
  CPUHook(PC, FoundBPoint);

 FoundBPoint = false;
 //
 PrevPC = PC;
}

#if 0
static uint8 ReadHandler(X6502 *cur_X, unsigned int A)
{
 if(cur_X->preexec)
 {
  std::vector<NES_BPOINT>::iterator bpit;

  for(bpit = BreakPointsRead.begin(); bpit != BreakPointsRead.end(); bpit++)
  {
   if(A >= bpit->A[0] && A <= bpit->A[1])
   {
    FoundBPoint = 1;
    break;
   }
  }
 }
 return(ARead[A](A));
}

static void WriteHandler(X6502 *cur_X, unsigned int A, uint8 V)
{
 if(cur_X->preexec)
 {
  std::vector<NES_BPOINT>::iterator bpit;

  for(bpit = BreakPointsWrite.begin(); bpit != BreakPointsWrite.end(); bpit++)
  {
   if(A >= bpit->A[0] && A <= bpit->A[1])
   {
    FoundBPoint = 1;
    break;
   }
  }
 }
 else
  BWrite[A](A,V);
}

static void RedoHooks(void)
{
 X6502_Debug((CPUHook || BTEnabled) ? CPUHandler : NULL, (CPUHook && BreakPointsRead.size()) ? ReadHandler : NULL, (CPUHook && BreakPointsWrite.size()) ? WriteHandler : 0);
}
#endif

static void AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical)
{
 BPOINT tmp;

 tmp.A[0] = A1;
 tmp.A[1] = A2;
 tmp.type =type;


 if(type == BPOINT_READ)
  BreakPointsRead.push_back(tmp);
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.push_back(tmp);
 else if(type == BPOINT_PC)
  BreakPointsPC.push_back(tmp);

 RedoHooks();
}

static void FlushBreakPoints(int type)
{
 std::vector<BPOINT>::iterator bpit;

 if(type == BPOINT_READ)
  BreakPointsRead.clear();
 else if(type == BPOINT_WRITE)
  BreakPointsWrite.clear();
 else if(type == BPOINT_PC)
  BreakPointsPC.clear();

 RedoHooks();
}

static void SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous)
{
 CPUHook = callb;
 CPUHookContinuous = continuous;

 RedoHooks();
}

enum
{
 CPU_GSREG_PC = 0,
 CPU_GSREG_A,
 CPU_GSREG_X,
 CPU_GSREG_Y,
 CPU_GSREG_SP,
 CPU_GSREG_P,
 CPU_GSREG_TIMESTAMP
};

static const RegType CPURegs[] =
{
        { CPU_GSREG_PC, "PC", "Program Counter", 2 },
        { CPU_GSREG_A, "A", "Accumulator", 1 },
        { CPU_GSREG_X, "X", "X Index", 1 },
        { CPU_GSREG_Y, "Y", "Y Index", 1 },
        { CPU_GSREG_SP, "SP", "Stack Pointer", 1 },
        { CPU_GSREG_P, "P", "Status", 1 },
	//{ CPU_GSREG_TIMESTAMP, "TiSt", "Timestamp", 4 },
        { 0, "", "", 0 },
};

static uint32 GetRegister_CPU(const unsigned int id, char *special, const uint32 special_len)
{
 uint32 value = 0xDEADBEEF;

 switch(id)
 {
  case CPU_GSREG_PC:
        value = CPU.PC;
        break;

  case CPU_GSREG_A:
        value = CPU.A;
        break;

  case CPU_GSREG_X:
        value = CPU.X;
        break;

  case CPU_GSREG_Y:
        value = CPU.Y;
        break;

  case CPU_GSREG_SP:
        value = CPU.SP;
        break;

  case CPU_GSREG_P:
        value = CPU.P;
        if(special)
        {
         trio_snprintf(special, special_len, "N: %d, V: %d, D: %d, I: %d, Z: %d, C: %d", (int)(bool)(value & Core6502::FLAG_N),
                (int)(bool)(value & Core6502::FLAG_V),
                (int)(bool)(value & Core6502::FLAG_D),
                (int)(bool)(value & Core6502::FLAG_I),
                (int)(bool)(value & Core6502::FLAG_Z),
                (int)(bool)(value & Core6502::FLAG_C));
        }
        break;

/*
  case CPU_GSREG_TIMESTAMP:
	value = timestamp;
	break;
*/
 }

 return value;
}

static void SetRegister_CPU(const unsigned int id, uint32 value)
{
 switch(id)
 {
  case CPU_GSREG_PC:
        CPU.PC = value & 0xFFFF;
        break;

  case CPU_GSREG_A:
        CPU.A = value & 0xFF;
        break;

  case CPU_GSREG_X:
        CPU.X = value & 0xFF;
        break;

  case CPU_GSREG_Y:
        CPU.Y = value & 0xFF;
        break;

  case CPU_GSREG_SP:
        CPU.SP = value & 0xFF;
        break;

  case CPU_GSREG_P:
        CPU.P = (value & 0xFF) & ~(Core6502::FLAG_B | Core6502::FLAG_U);
        break;

  //case CPU_GSREG_TIMESTAMP:
  //	break;
 }
}

static const RegGroupType CPURegsGroup =
{
        "6502",
        CPURegs,
        GetRegister_CPU,
        SetRegister_CPU
};

enum
{
 MISC_GSREG_TEXT = 0x0,
 MISC_GSREG_MIXED,
 MISC_GSREG_PAGE2,
 MISC_GSREG_HIRES,
 MISC_GSREG_AN0,
 MISC_GSREG_AN1,
 MISC_GSREG_AN2,
 MISC_GSREG_AN3 = 0x7,
 //
 MISC_GSREG_80STORE = 0x8,
 MISC_GSREG_RAMRD,
 MISC_GSREG_RAMWRT,
 MISC_GSREG_INTCXROM,
 MISC_GSREG_ALTZP,
 MISC_GSREG_SLOTC3ROM,
 MISC_GSREG_80COL,
 MISC_GSREG_ALTCHARSET = 0xF
};

static const RegType MiscRegs[] =
{
	{ MISC_GSREG_TEXT, "TEXT", "TEXT", 0x100 | 1 },
	{ MISC_GSREG_MIXED, "MIXED", "MIXED", 0x100 | 1 },
	{ MISC_GSREG_PAGE2, "PAGE2", "PAGE2", 0x100 | 1 },
	{ MISC_GSREG_HIRES, "HIRES", "HIRES", 0x100 | 1 },
        { 0, "---------", "", 0xFFFF },
	{ MISC_GSREG_AN0, "AN0", "AN0", 0x100 | 1 },
	{ MISC_GSREG_AN1, "AN1", "AN1", 0x100 | 1 },
	{ MISC_GSREG_AN2, "AN2", "AN2", 0x100 | 1 },
	{ MISC_GSREG_AN3, "AN3", "AN3", 0x100 | 1 },

        { 0, "", "", 0 },
};

static const RegType MiscRegs_IIE[] =
{
	{ MISC_GSREG_80STORE, "80STORE", "80STORE", 0x100 | 1 },
	{ MISC_GSREG_RAMRD, "RAMRD", "RAMRD", 0x100 | 1 },
	{ MISC_GSREG_RAMWRT, "RAMWRT", "RAMWRT", 0x100 | 1 },
	{ MISC_GSREG_INTCXROM, "INTCXROM", "INTCXROM", 0x100 | 1 },
	{ MISC_GSREG_ALTZP, "ALZP", "ALTZP", 0x100 | 1 },
	{ MISC_GSREG_SLOTC3ROM, "SLOTC3ROM", "SLOTC3ROM", 0x100 | 1 },
	{ MISC_GSREG_80COL, "80COL", "80COL", 0x100 | 1 },
	{ MISC_GSREG_ALTCHARSET, "ALTCHARSET", "ALTCHARSET", 0x100 | 1 },

        { 0, "", "", 0 },
};

static uint32 GetRegister_Misc(const unsigned int id, char *special, const uint32 special_len)
{
 uint32 value = 0xDEADBEEF;

 if(id < 0x10)
 {
  value = (SoftSwitch >> id) & 0x1;
 }

 return value;
}

static void SetRegister_Misc(const unsigned int id, uint32 value)
{
 if(id < 0x10)
 {
  SoftSwitch &= ~(1U << id);
  SoftSwitch |= (value & 0x1) << id;
 }
}

static const RegGroupType MiscRegsGroup =
{
        "Misc",
        MiscRegs,
        GetRegister_Misc,
        SetRegister_Misc
};

static const RegGroupType MiscRegsGroup_IIE =
{
        "Misc IIe",
        MiscRegs_IIE,
        GetRegister_Misc,
        SetRegister_Misc
};


static const RegType Disk2Regs[] =
{
	{ Disk2::GSREG_STEPPHASE, "STEPPH", "Stepper Phase Control", 0x100 | 4 },
	{ Disk2::GSREG_MOTORON, "MOTORON", "Motor On", 0x100 | 1 },
	{ Disk2::GSREG_DRIVESEL, "DRIVESEL", "Drive Select", 0x100 | 1 },
	{ Disk2::GSREG_MODE, "MODE", "Mode", 0x100 | 2 },

        { 0, "", "", 0 },
};

static const RegGroupType Disk2RegsGroup =
{
	"Disk II",
	Disk2Regs,
	Disk2::GetRegister,
	Disk2::SetRegister
};

static DebuggerInfoStruct DBGInfo =
{
 true,
 "cp437",
 3,
 1,             // Instruction alignment(bytes)
 16,
 16,
 0x0000, // Default watch addr
 0x0000, // ZP
 MemPeek,
 Disassemble,
 NULL,
 IRQ,
 GetVector,
 FlushBreakPoints,
 AddBreakPoint,
 SetCPUCallback,
 EnableBranchTrace,
 GetBranchTrace,
 NULL
};

static void Init(void)
{
 memset(BTEntries, 0, sizeof(BTEntries));
 BTIndex = 0;
 BTEnabled = false;

 MDFNDBG_AddRegGroup(&CPURegsGroup);
 MDFNDBG_AddRegGroup(&MiscRegsGroup);

 if(EnableIIE)
  MDFNDBG_AddRegGroup(&MiscRegsGroup_IIE);

 if(EnableDisk2)
  MDFNDBG_AddRegGroup(&Disk2RegsGroup);

 ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "cpu", "CPU", 16);
 ASpace_Add(GetAddressSpaceBytes, PutAddressSpaceBytes, "ram", "RAM", 0, RAMSize);
}

}
#else
namespace DBG
{
static INLINE void Init(void) { }
}
#endif


