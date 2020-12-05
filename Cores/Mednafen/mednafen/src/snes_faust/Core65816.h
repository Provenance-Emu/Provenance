/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Core65816.h - 65816 CPU Emulator Core
**  Copyright (C) 2015-2019 Mednafen Team
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

struct CPU_Misc;

class Core65816
{
 public:
 Core65816() MDFN_COLD;
 ~Core65816() MDFN_COLD;

 void Power(void) MDFN_COLD;
 void Reset(void) MDFN_COLD;

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname);

 //private:

 enum
 {
  N_FLAG = 0x80,
  V_FLAG = 0x40,

  M_FLAG = 0x20,	// Memory/Accumulator(0=16-bit)
  X_FLAG = 0x10,	// Index(0=16-bit)

  D_FLAG = 0x08,
  I_FLAG = 0x04,
  Z_FLAG = 0x02,
  C_FLAG = 0x01,
 };

 union
 {
  struct
  {
#ifdef MSB_FIRST
   uint8 PCPBRDummy;
   uint8 PBR;
   uint16 PC;
#else
   uint16 PC;
   uint8 PBR;
   uint8 PCPBRDummy;
#endif
  };
  uint32 PCPBR;
 };
 uint32 DBRSL16;

 uint16 S;
 uint16 D;

 union
 {
  uint16 C;
  struct
  {
#ifdef MSB_FIRST
   uint8 B;
   uint8 A;
#else
   uint8 A;
   uint8 B;
#endif
  };
 };

 template<typename T>
 INLINE T& AC(void)	// Clever and/or horrible.
 {
/*
  if(sizeof(T) == 2)
   return (T&)C;
  else
   return (T&)A;
*/
  return *(T*)((sizeof(T) == 2) ? (void*)&C : (void*)&A);
 }

 uint16 X, Y;
 uint8 P;
 bool E;

#ifdef ARCH_X86
 struct
 {
  INLINE void operator=(CPU_Misc* arg)
  {
   MDFN_HIDE extern CPU_Misc CPUM;
   assert(arg == &CPUM);
  }

  INLINE operator CPU_Misc*()
  {
   MDFN_HIDE extern CPU_Misc CPUM;
   return &CPUM;
  }

  INLINE CPU_Misc* operator->()
  {
   MDFN_HIDE extern CPU_Misc CPUM;
   return &CPUM;
  }
 } cpum;
#else
 CPU_Misc* cpum;
#endif

 void SampleIRQ(void);

 template<uint8 opcode, typename M_type, typename X_type>
 void RunInstruction(void);

 template<typename T>
 void MemWrite(uint32 addr, T val);

 template<typename T>
 T MemRead(uint32 addr);

 void IO(void);

 void BranchOccurred(unsigned iseq = ~0U);

 enum
 {
  GSREG_PCPBR,
  GSREG_DBR,
  GSREG_S,
  GSREG_D,
  GSREG_A,
  GSREG_X,
  GSREG_Y,
  GSREG_P,
  GSREG_E,
  GSREG__BOUND
 };

 void SetRegister(const unsigned id, const uint32 value) MDFN_COLD;
 uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;

 //private:

 uint16 VecRead(uint32 addr);
 uint8 OpRead(uint32 addr);

 template<typename T> void SetZN(const T arg);
 template<typename T> void Push(T arg);
 template<typename T> T Pull(void);

 enum
 {
  ISEQ_COP,
  ISEQ_BRK,
  ISEQ_ABORT,
  ISEQ_NMI,
  ISEQ_IRQ
 };

 void ISequence(unsigned which);

 template<typename T> void Op_ADC(T arg);
 template<typename T> void Op_AND(T arg);
 template<typename T, bool immediate = false> void Op_BIT(T arg);
 template<typename T> void Op_Compare(T rv, T arg);
 template<typename T> void Op_CMP(T arg);
 template<typename T> void Op_CPX(T arg);
 template<typename T> void Op_CPY(T arg);
 template<typename T> void Op_EOR(T arg);
 template<typename T> void Op_LDA(T arg);
 template<typename T> void Op_LDX(T arg);
 template<typename T> void Op_LDY(T arg);
 template<typename T> void Op_ORA(T arg);
 template<typename T> void Op_SBC(T arg);

 template<typename T> void Op_ASL(T& arg);
 template<typename T> void Op_DEC(T& arg);
 template<typename T> void Op_INC(T& arg);
 template<typename T> void Op_LSR(T& arg);
 template<typename T> void Op_ROL(T& arg);
 template<typename T> void Op_ROR(T& arg);
 template<typename T> void Op_TRB(T& arg);
 template<typename T> void Op_TSB(T& arg);

 template<typename T> INLINE T Op_STA(void) { return C; }
 template<typename T> INLINE T Op_STX(void) { return X; }
 template<typename T> INLINE T Op_STY(void) { return Y; }
 template<typename T> INLINE T Op_STZ(void) { return 0; }

 uint32 GetEA_AB(void);
 template<bool UncondEC> uint32 GetEA_ABI(uint16 index);
 template<bool UncondEC> uint32 GetEA_ABX(void);
 template<bool UncondEC> uint32 GetEA_ABY(void);
 uint32 GetEA_ABL(void);
 uint32 GetEA_ABLX(void);

 uint16 GetEA_DP(void);
 uint16 GetEA_DPI(uint16 index);
 uint16 GetEA_DPX(void);
 uint16 GetEA_DPY(void);
 uint32 GetEA_IND(void);
 uint32 GetEA_INDL(void);
 uint32 GetEA_IX(void);
 template<bool UncondEC> uint32 GetEA_IY(void);
 uint32 GetEA_ILY(void);

 uint16 GetEA_SR(void);
 uint32 GetEA_SRIY(void);

 template<typename T> void Instr_LD_IM(void (Core65816::*op)(T));
 template<typename T, typename EAT> void Instr_LD(EAT (Core65816::*eafn)(void), void (Core65816::*op)(T));

 template<typename T> void Instr_RMW_A  (void (Core65816::*op)(T&));
 template<typename T, typename EAT> void Instr_RMW(EAT (Core65816::*eafn)(void), void (Core65816::*op)(T&));

 template<typename T, typename EAT> void Instr_ST(EAT (Core65816::*eafn)(void), T (Core65816::*op)(void));

 void Instr_BRK(void);
 void Instr_COP(void);
 void Instr_NOP(void);
 void Instr_STP(void);
 void Instr_WAI(void);
 void Instr_WDM(void);

 void Instr_Bxx(bool cond);
 void Instr_BRL(void);

 void Instr_PEA(void);
 void Instr_PEI(void);
 void Instr_PER(void);
 template<typename T> void Instr_PHA(void);
 void Instr_PHB(void);
 void Instr_PHD(void);
 void Instr_PHK(void);
 void Instr_PHP(void);
 template<typename T> void Instr_PHX(void);
 template<typename T> void Instr_PHY(void);

 template<typename T> void Instr_PLA(void);
 void Instr_PLB(void);
 void Instr_PLD(void);
 void Instr_PLP(void);
 template<typename T> void Instr_PLX(void);
 template<typename T> void Instr_PLY(void);

 void Instr_REP(void);
 void Instr_SEP(void);

 void Instr_JMP(void);
 void Instr_JMP_I(void);
 void Instr_JMP_II(void);
 void Instr_JML(void);
 void Instr_JML_I(void);

 void Instr_JSL(void);
 void Instr_JSR(void);
 void Instr_JSR_II(void);

 void Instr_RTI(void);
 void Instr_RTL(void);
 void Instr_RTS(void);

 template<typename T> void Instr_INX(void);
 template<typename T> void Instr_INY(void);

 template<typename T> void Instr_DEX(void);
 template<typename T> void Instr_DEY(void);

 template<typename T> void Instr_TAX(void);
 template<typename T> void Instr_TAY(void);
 void Instr_TCD(void);
 void Instr_TCS(void);
 void Instr_TDC(void);
 void Instr_TSC(void);
 template<typename T> void Instr_TSX(void);
 template<typename T> void Instr_TXA(void);
 void Instr_TXS(void);
 template<typename T> void Instr_TXY(void);
 template<typename T> void Instr_TYA(void);
 template<typename T> void Instr_TYX(void);
 void Instr_XBA(void);
 void Instr_XCE(void);
 template<unsigned TA_Mask> void Instr_CLx(void);
 template<unsigned TA_Mask> void Instr_SEx(void);
 template<typename X_type, int increment> void Instr_MVx(void);
};

