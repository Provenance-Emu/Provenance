/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Core6502.inc - 6502 CPU Emulator Core
**  Copyright (C) 2018-2023 Mednafen Team
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

/*
 65C02 TODO:
	Decimal mode ADC and SBC read last instruction byte or
	byte of next instruction for extra cycle?

	See if handling of dummy reads with STA $xxxx, X/Y
	and STA ($zz), Y is consistent across different
	65C02 versions, and if not, make the behavior
	configurable(note that Apple Disk II hardware is
	sensitive and disk corruption may occur on writes
	if the behavior is not proper).
*/

// FIXME: NMI sampling granularity
// TODO: Proper half-cycle support WRT IRQ signal sampling.

/*
 TODO:
 6502 versions to support:
	NMOS Synertek SY6502A
	NMOS Ricoh 2A03
	CMOS NCR 65C02(no SMB, RMB, BBS, BBR, STP, WAI?)
*/

//static const bool Core6502_EnableDecimalOps = true;
//static const bool Core6502_EnableMidExit = true;
Core6502::Core6502()
{

}

Core6502::~Core6502()
{

}

void Core6502::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(PC),

  SFVAR(P),
  SFVAR(SP),
  SFVAR(A),
  SFVAR(X),
  SFVAR(Y),

  SFVAR(IFN),
  SFVAR(NMIPending),
  SFVAR(NMIPrev),
  //
  //
  SFVAR(resume_point),
  SFVAR(resume_ea),
  SFVAR(resume_eai),
  SFVAR(resume_v),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

 if(load)
 {

 }
}

INLINE void Core6502::UpdateIFN(void)
{
 const bool IRQActive = GetIRQ();
 const bool NMIActive = GetNMI();

 NMIPending |= (NMIPrev ^ NMIActive) & NMIActive;
 NMIPrev = NMIActive;
 IFN = NMIPending | (IRQActive & !(P & FLAG_I));
}

INLINE void Core6502::CalcZN(uint8 v)
{
 P &= ~(FLAG_N | FLAG_Z);
 P |= v & FLAG_N;
 P |= v ? 0 : FLAG_Z;
}

#define GetEA_AB()				\
{						\
 ea = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 ea |= OpRead(PC) << 8;				\
 PC++;						\
 CMX();						\
}

// UncondEC is false on LD, true with RMW and ST
#define GetEA_ABi(UncondEC_, index_)		\
{						\
 GetEA_AB();					\
 eai = ea + (index_);				\
 ea = (ea & 0xFF00) | (eai & 0x00FF); 		\
 						\
 if((UncondEC_) || ea != eai)			\
 {						\
  if(cmos)					\
  {						\
   if(ea != eai)				\
    OpRead(PC - 1, true);			\
   else						\
    MemRead(eai, true);				\
  }						\
  else						\
   MemRead(ea, true);				\
  ea = eai;					\
  CMX();					\
 }						\
}

#define GetEA_ZP()				\
{						\
 ea = OpRead(PC);				\
 PC++;						\
 CMX();						\
}

#define GetEA_ZPi(index_)			\
{						\
 ea = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 MemRead(ea, true);				\
 ea = (uint8)(ea + (index_));			\
 CMX();						\
}

// 65C02
#define GetEA_IDIR()				\
{						\
 eai = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 ea = MemRead(eai);				\
 eai = (uint8)(eai + 1);			\
 CMX();						\
						\
 ea |= MemRead(eai) << 8;			\
 CMX();						\
}

#define GetEA_IDIRX()				\
{						\
 eai = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 MemRead(eai, true);				\
 eai = (uint8)(eai + X);			\
 CMX();						\
						\
 ea = MemRead(eai);				\
 eai = (uint8)(eai + 1);			\
 CMX();						\
						\
 ea |= MemRead(eai) << 8;			\
 CMX();						\
}

// UncondEC is false on LD, true with RMW and ST
#define GetEA_IDIRY(UncondEC_)		\
{						\
 eai = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 ea = MemRead(eai);				\
 eai = (uint8)(eai + 1);			\
 CMX();						\
						\
 ea |= MemRead(eai) << 8;			\
 eai = ea + Y;					\
 ea = (ea & 0xFF00) | (eai & 0x00FF);		\
 CMX();						\
						\
 if((UncondEC_) || ea != eai)			\
 {						\
  if(cmos)					\
  {						\
   if(ea != eai)				\
    OpRead(PC - 1, true);			\
   else						\
    MemRead(eai, true);				\
  }						\
  else						\
   MemRead(ea, true);				\
  ea = eai;					\
  CMX();					\
 }						\
}

//
// Load
//
#define Instr_LD_IMM(op_)			\
{						\
 UpdateIFN();					\
 v = OpRead(PC);				\
 PC++;						\
						\
 (op_)(v);					\
}

#define Instr_LD_ZP(op_)			\
{						\
 GetEA_ZP();					\
						\
 UpdateIFN();					\
 v = MemRead(ea);				\
						\
 (op_)(v);					\
}


#define Instr_LD_ZPi(index_y_, op_)		\
{						\
 GetEA_ZPi((index_y_) ? Y : X);			\
						\
 UpdateIFN();					\
 v = MemRead(ea);				\
						\
 (op_)(v);					\
}

#define Instr_LD_ZPX(op_) Instr_LD_ZPi(false, op_)
#define Instr_LD_ZPY(op_) Instr_LD_ZPi(true, op_)

#define Instr_LD_AB(op_)			\
{						\
 GetEA_AB();					\
						\
 UpdateIFN();					\
 v = MemRead(ea);				\
						\
 (op_)(v);					\
}

#define Instr_LD_ABi(index_y_, op_)		\
{						\
 GetEA_ABi(false, (index_y_) ? Y : X);		\
						\
 UpdateIFN();					\
 v = MemRead(ea);				\
						\
 (op_)(v);					\
}

#define Instr_LD_ABX(op_) Instr_LD_ABi(false, op_)
#define Instr_LD_ABY(op_) Instr_LD_ABi(true, op_)

// 65C02
#define Instr_LD_IDIR(op_)			\
{						\
 GetEA_IDIR();					\
						\
 UpdateIFN();					\
 v = MemRead(ea); 				\
						\
 (op_)(v);					\
}

#define Instr_LD_IDIRX(op_)			\
{						\
 GetEA_IDIRX();					\
						\
 UpdateIFN();					\
 v = MemRead(ea); 				\
						\
 (op_)(v);					\
}

#define Instr_LD_IDIRY(op_)			\
{						\
 GetEA_IDIRY(false);				\
						\
 UpdateIFN();					\
 v = MemRead(ea);				\
						\
 (op_)(v);					\
}


//
// RMW
//
#define Instr_RMW_A(op_)			\
{						\
 UpdateIFN();					\
 OpRead(PC, true);				\
 (op_)(A);					\
}

#define Instr_RMW_ZP(op_)			\
{						\
 GetEA_ZP();					\
						\
 v = MemRead(ea);				\
 CMX();						\
 if(cmos)					\
  MemRead(ea, true);				\
 else						\
  MemWrite(ea, v);				\
 (op_)(v);					\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_RMW_ZPX(op_)			\
{						\
 GetEA_ZPi(X);					\
						\
 v = MemRead(ea);				\
 CMX();						\
 if(cmos)					\
  MemRead(ea, true);				\
 else						\
  MemWrite(ea, v);				\
 (op_)(v);					\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_RMW_AB(op_)			\
{						\
 GetEA_AB();					\
						\
 v = MemRead(ea);				\
 CMX();						\
 if(cmos)					\
  MemRead(ea, true);				\
 else						\
  MemWrite(ea, v);				\
 (op_)(v);					\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_RMW_ABi(UncondEC_, index_y_, op_)	\
{						\
 GetEA_ABi((UncondEC_), (index_y_) ? Y : X);	\
						\
 v = MemRead(ea);				\
 CMX();						\
 if(cmos)					\
  MemRead(ea, true);				\
 else						\
  MemWrite(ea, v);				\
 (op_)(v);					\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_RMW_ABX(op_)	Instr_RMW_ABi(!cmos, false, op_)
#define Instr_RMW_ABX_DIC(op_)	Instr_RMW_ABi( true, false, op_)
#define Instr_RMW_ABY(op_)	Instr_RMW_ABi(!cmos,  true, op_)


#define Instr_RMW_IDIRX(op_)			\
{						\
 GetEA_IDIRX();					\
						\
 v = MemRead(ea);				\
 CMX();						\
 if(cmos)					\
  MemRead(ea, true);				\
 else						\
  MemWrite(ea, v);				\
 (op_)(v);					\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_RMW_IDIRY(op_)			\
{						\
 GetEA_IDIRY(true);				\
						\
 v = MemRead(ea);				\
 CMX();						\
 if(cmos)					\
  MemRead(ea, true);				\
 else						\
  MemWrite(ea, v);				\
 (op_)(v);					\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}


//
// Store
//
#define Instr_ST_ZP(op_)			\
{						\
 GetEA_ZP();					\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_ZPi(index_y_, op_)		\
{						\
 GetEA_ZPi((index_y_) ? Y : X);			\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_ZPX(op_) Instr_ST_ZPi(false, op_)
#define Instr_ST_ZPY(op_) Instr_ST_ZPi(true, op_)

#define Instr_ST_AB(op_)			\
{						\
 GetEA_AB();					\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_ABi(index_y_, op_)		\
{						\
 GetEA_ABi(true, (index_y_) ? Y : X);		\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_ABX(op_) Instr_ST_ABi(false, op_)
#define Instr_ST_ABY(op_) Instr_ST_ABi(true, op_)

// 65C02
#define Instr_ST_IDIR(op_)			\
{						\
 GetEA_IDIR();					\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_IDIRX(op_)			\
{						\
 GetEA_IDIRX();					\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_IDIRY(op_)			\
{						\
 GetEA_IDIRY(true);				\
						\
 v = (op_)();					\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

//
// Store (NMOS illegal special)
//
#define Instr_ST_H_ILL_ABX(op_)			\
{						\
 GetEA_AB();					\
 eai = ea + X;					\
 ea = (ea & 0xFF00) | (eai & 0x00FF);		\
 						\
 MemRead(ea, true);				\
 v = (op_)((ea >> 8) + 1);			\
 if(ea != eai)					\
  ea = (ea & 0xFF) | (v << 8);			\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

#define Instr_ST_H_ILL_ABY(op_)			\
{						\
 GetEA_AB();					\
 eai = ea + Y;					\
 ea = (ea & 0xFF00) | (eai & 0x00FF);		\
 						\
 MemRead(ea, true);				\
 v = (op_)((ea >> 8) + 1);			\
 if(ea != eai)					\
  ea = (ea & 0xFF) | (v << 8);			\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}

// TODO/FIXME: For AXA; probably not right.
#define Instr_ST_H_ILL_IDIRY(op_)		\
{						\
 GetEA_IDIRY(true);				\
						\
 v = (op_)(ea >> 8);				\
 UpdateIFN();					\
 MemWrite(ea, v);				\
}


//
//
//

INLINE void Core6502::Op_ASL(uint8& v)
{
 const uint8 result = v << 1;

 P &= ~FLAG_C;
 P |= (v >> 7) & FLAG_C;
 CalcZN(result);
 v = result;
}

INLINE void Core6502::Op_LSR(uint8& v)
{
 const uint8 result = v >> 1;

 P &= ~FLAG_C;
 P |= v & FLAG_C;
 CalcZN(result);
 v = result;
}

INLINE void Core6502::Op_ROL(uint8& v)
{
 const uint8 result = (v << 1) | (P & FLAG_C);

 P &= ~FLAG_C;
 P |= (v >> 7) & FLAG_C;
 CalcZN(result);
 v = result;
}

INLINE void Core6502::Op_ROR(uint8& v)
{
 const uint8 result = (v >> 1) | ((P & FLAG_C) << 7);

 P &= ~FLAG_C;
 P |= v & FLAG_C;
 CalcZN(result);
 v = result;
}

INLINE void Core6502::Op_DEC(uint8& v)
{
 const uint8 result = v - 1;

 CalcZN(result);
 v = result;
}

INLINE void Core6502::Op_INC(uint8& v)
{
 const uint8 result = v + 1;

 CalcZN(result);
 v = result;
}

// 65C02
INLINE void Core6502::Op_TRB(uint8& v)
{
 P &= ~FLAG_Z;
 if(!(v & A))
  P |= FLAG_Z;

 v &= ~A;
}

// 65C02
INLINE void Core6502::Op_TSB(uint8& v)
{
 P &= ~FLAG_Z;
 if(!(v & A))
  P |= FLAG_Z;

 v |= A;
}
//
//
//
INLINE void Core6502::Op_LDA(uint8 v)
{
 CalcZN(v);
 A = v;
}

INLINE void Core6502::Op_LDX(uint8 v)
{
 CalcZN(v);
 X = v;
}

INLINE void Core6502::Op_LDY(uint8 v)
{
 CalcZN(v);
 Y = v;
}
//
//
//
INLINE uint8 Core6502::Op_STA(void)
{
 return A;
}

INLINE uint8 Core6502::Op_STX(void)
{
 return X;
}

INLINE uint8 Core6502::Op_STY(void)
{
 return Y;
}

// 65C02
INLINE uint8 Core6502::Op_STZ(void)
{
 return 0;
}

//
//
//
template<bool cmos>
INLINE void Core6502::Op_ADC(uint8 v)
{
 // A + M + C -> A
 //
 unsigned result = A + v + (P & FLAG_C);

 P &= ~(FLAG_C | FLAG_V | FLAG_Z | FLAG_N);
 P |= (uint8)result ? 0 : FLAG_Z;

 if(Core6502_EnableDecimalOps && (P & FLAG_D))
 {
  const unsigned l = (result & 0x1F) ^ ((A ^ v) & 0x10);

  if(l >= 0x0A)
   result = (result + 0x06) - ((l + 0x16) & 0x10);
  //
  //
  // Set overflow if A and v have same sign bits, and result has a different sign bit.
  P |= (~(A ^ v) & 0x80 & (A ^ result)) >> (7 - FLAG_BITPOS_V);
  P |= result & FLAG_N;

  if(result >= 0xA0)
  {
   result += 0x60;
   P |= FLAG_C;
  }
  //
  //
  if(cmos)
  {
   OpRead(PC - 1, true);	// FIXME: PC - 1 or PC?
   CalcZN(result);
  }
 }
 else
 {
  // Set overflow if A and v have same sign bits, and result has a different sign bit.
  P |= (~(A ^ v) & 0x80 & (A ^ result)) >> (7 - FLAG_BITPOS_V);
  P |= result & FLAG_N;
  P |= (result >> 8) & FLAG_C;
 }
 //
 //
 A = result;
}

template<bool cmos>
void Core6502::Op_SBC(uint8 v)
{
 // A - M - !C -> A
 //
 v = ~v;
 //
 unsigned result = A + v + (P & FLAG_C);

 P &= ~(FLAG_C | FLAG_V);
 P |= (result >> 8) & FLAG_C;
 // Set overflow if A and v have same sign bits, and result has a different sign bit.
 P |= ((~(A ^ v)) & 0x80 & (A ^ result)) >> (7 - FLAG_BITPOS_V);
 CalcZN(result);
 //
 //
 if(Core6502_EnableDecimalOps && (P & FLAG_D))
 {
  const unsigned l = (result & 0x1F) ^ ((A ^ v) & 0x10);

  if(result < 0x100)
   result -= 0x60;

  if(l < 0x10)
  {
   if(cmos)
    result -= 0x06;
   else
    result = (result & 0xF0) + ((result - 0x06) & 0x0F);
  }

  if(cmos)
  {
   OpRead(PC - 1, true);	// FIXME: PC - 1 or PC?
   CalcZN(result);
  }
 }
 //
 //
 A = result;
}

INLINE void Core6502::Op_CMPx(uint8 s, uint8 v)
{
 const unsigned result = s - v;

 P &= ~FLAG_C;
 P |= (~result >> 8) & FLAG_C;
 CalcZN(result);
}

INLINE void Core6502::Op_CMP(uint8 v) { Op_CMPx(A, v); }
INLINE void Core6502::Op_CPX(uint8 v) { Op_CMPx(X, v); }
INLINE void Core6502::Op_CPY(uint8 v) { Op_CMPx(Y, v); }

INLINE void Core6502::Op_BIT(uint8 v)
{
 P &= ~(FLAG_N | FLAG_V | FLAG_Z);
 P |= v & (FLAG_N | FLAG_V);
 P |= (A & v) ? 0 : FLAG_Z;
}

// 65C02
INLINE void Core6502::Op_BIT_IMM(uint8 v)
{
 P &= ~FLAG_Z;
 P |= (A & v) ? 0 : FLAG_Z;
}

INLINE void Core6502::Op_AND(uint8 v)
{
 const uint8 result = A & v;

 CalcZN(result);
 A = result;
}

INLINE void Core6502::Op_EOR(uint8 v)
{
 const uint8 result = A ^ v;

 CalcZN(result);
 A = result;
}

INLINE void Core6502::Op_ORA(uint8 v)
{
 const uint8 result = A | v;

 CalcZN(result);
 A = result;
}
//
//
//

INLINE void Core6502::Op_AAC(uint8 v)
{
 Op_AND(v);
 P = (P & ~FLAG_C) | ((P >> 7) & FLAG_C);
}

INLINE void Core6502::Op_ARR(uint8 v)
{
 Op_AND(v);
 Op_ROR(A);

 P &= ~(FLAG_C | FLAG_V);
 P |= ((A >> 6) & FLAG_C) | ((A ^ (A << 1)) & FLAG_V); 
}

INLINE void Core6502::Op_ASR(uint8 v)
{
 Op_AND(v);
 Op_LSR(A);
}

// 0xAB
INLINE void Core6502::Op_ATX(uint8 v)
{
 /* TODO: Unstable */
 const uint8 cm = 0x00;
 const uint8 result = (A | cm) & v;
 
 A = result;
 X = result;
 CalcZN(result);
}

INLINE void Core6502::Op_AXS(uint8 v)
{
 unsigned result = (A & X) - v;

 CalcZN(result);
 P = (P & ~FLAG_C) | ((~result >> 8) & FLAG_C);

 X = result;
}

INLINE void Core6502::Op_LAS(uint8 v)
{
 CalcZN(v);
 A = v;
 X = v;
 SP = v;
}

INLINE void Core6502::Op_LAX(uint8 v)
{
 CalcZN(v);
 A = v;
 X = v;
}

// 0x8B
INLINE void Core6502::Op_XAA(uint8 v)
{
 /* TODO: Unstable */
 const uint8 cm = 0xFF;
 const uint8 result = (A | cm) & X & v;

 A = result;
 CalcZN(result);
}
//
//
//
INLINE void Core6502::Op_DCP(uint8& v)
{
 Op_DEC(v);
 Op_CMP(v);
}

INLINE void Core6502::Op_ISC(uint8& v)
{
 Op_INC(v);
 Op_SBC<false>(v);
}

INLINE void Core6502::Op_RLA(uint8& v)
{
 Op_ROL(v);
 Op_AND(v);
}

INLINE void Core6502::Op_RRA(uint8& v)
{
 Op_ROR(v);
 Op_ADC<false>(v);
}

INLINE void Core6502::Op_SLO(uint8& v)
{
 Op_ASL(v);
 Op_ORA(v);
}

INLINE void Core6502::Op_SRE(uint8& v)
{
 Op_LSR(v);
 Op_EOR(v);
}
//
//
//
INLINE uint8 Core6502::Op_AAX(void)
{
 return A & X;
}

INLINE uint8 Core6502::Op_AXA(uint8 v)
{
 //puts("Unknown: AXA");
 return X & A & v;
}

INLINE uint8 Core6502::Op_SXA(uint8 v)
{
 //puts("Unknown: SXA");

 return X & v;
}

INLINE uint8 Core6502::Op_SYA(uint8 v)
{
 //puts("Unknown: SYA");

 return Y & v;
}

INLINE uint8 Core6502::Op_XAS(uint8 v)
{
 //puts("Unknown: XAS");

 SP = A & X;

 return SP & v;
}

//
//
//
INLINE void Core6502::Op_NOP(uint8 v)
{

}

INLINE void Core6502::Op_NOP(void)
{

}

INLINE void Core6502::Op_DEX(void)
{
 X--;
 CalcZN(X);
}

INLINE void Core6502::Op_DEY(void)
{
 Y--;
 CalcZN(Y);
}

INLINE void Core6502::Op_INX(void)
{
 X++;
 CalcZN(X);
}

INLINE void Core6502::Op_INY(void)
{
 Y++;
 CalcZN(Y);
}

template<uint8 flag>
INLINE void Core6502::Op_CLx(void)
{
 P &= ~flag;
}

template<uint8 flag>
INLINE void Core6502::Op_SEx(void)
{
 P |= flag;
}

INLINE void Core6502::Op_TAX(void)
{
 X = A;
 CalcZN(X);
}

INLINE void Core6502::Op_TAY(void)
{
 Y = A;
 CalcZN(Y);
}

INLINE void Core6502::Op_TYA(void)
{
 A = Y;
 CalcZN(A);
}

INLINE void Core6502::Op_TXA(void)
{
 A = X;
 CalcZN(A);
}

INLINE void Core6502::Op_TSX(void)
{
 X = SP;
 CalcZN(X);
}

INLINE void Core6502::Op_TXS(void)
{
 SP = X;
}

#define Instr_IMP(op_)				\
{						\
 UpdateIFN();					\
 OpRead(PC, true);				\
 /**/						\
 (op_)();					\
}

#define Instr_PHA()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(0x100 + SP, A);			\
 SP--;						\
}

// 65C02
#define Instr_PHX()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(0x100 + SP, X);			\
 SP--;						\
}

// 65C02
#define Instr_PHY()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 UpdateIFN();					\
 MemWrite(0x100 + SP, Y);			\
 SP--;						\
}


#define Instr_PHP()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
 						\
 UpdateIFN();					\
 MemWrite(0x100 + SP, P | FLAG_B | FLAG_U);	\
 SP--;						\
}

#define Instr_PLA()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 SP++;						\
 CMX();						\
						\
 UpdateIFN();					\
 A = MemRead(0x100 + SP);			\
 CalcZN(A);					\
}

// 65C02
#define Instr_PLX()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 SP++;						\
 CMX();						\
						\
 UpdateIFN();					\
 X = MemRead(0x100 + SP);			\
 CalcZN(X);					\
}

// 65C02
#define Instr_PLY()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 SP++;						\
 CMX();						\
						\
 UpdateIFN();					\
 Y = MemRead(0x100 + SP);			\
 CalcZN(Y);					\
}

#define Instr_PLP()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 SP++;						\
 CMX();						\
						\
 UpdateIFN();					\
 P = MemRead(0x100 + SP) & ~(FLAG_B | FLAG_U);	\
}

#define ISequence(hw_)				\
{						\
 OpRead(PC, true);				\
 PC += !(hw_);					\
 CMX();						\
						\
 MemWrite(0x100 + SP, PC >> 8);			\
 SP--;						\
 CMX();						\
						\
 MemWrite(0x100 + SP, PC);			\
 SP--;						\
 CMX();						\
						\
 MemWrite(0x100 + SP, P | ((hw_) ? 0 : FLAG_B) | FLAG_U);	\
 SP--;						\
 CMX();						\
						\
 P |= FLAG_I;					\
						\
 if(cmos)					\
  P &= ~FLAG_D;					\
						\
 if(NMIPending && (hw_)) /*(!cmos || (hw_)))*/\
 {						\
  v = 0xFA;					\
  NMIPending = false;				\
 }						\
 else						\
  v = 0xFE;					\
						\
 ea = MemRead(0xFF00 | v);			\
 CMX();						\
 /**/						\
 UpdateIFN();					\
 ea |= MemRead(0xFF01 | v) << 8;		\
 PC = ea;					\
 BranchTrace((hw_) ? (0xFF00 | v) : 0xFFFF);	\
}

#define Instr_BRK()				\
{						\
 /*abort();*/					\
 ISequence(false);				\
}

#define Instr_JMP_ABS()				\
{						\
 ea = OpRead(PC);				\
 PC++;						\
 CMX();						\
 /**/						\
 UpdateIFN();					\
 ea |= OpRead(PC) << 8;				\
 PC = ea;					\
 BranchTrace();					\
}

#define Instr_JMP_IDIR()			\
{						\
 eai = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 eai |= OpRead(PC) << 8;			\
 PC++;						\
 CMX();						\
						\
 if(cmos)					\
 {						\
  OpRead(PC - 1, true);				\
  CMX();					\
						\
  ea = MemRead(eai);				\
  eai++;					\
  CMX();					\
 }						\
 else						\
 {						\
  ea = MemRead(eai);				\
  eai = ((eai + 1) & 0xFF) | (eai & 0xFF00);	\
  CMX();					\
 }						\
						\
 UpdateIFN();					\
 ea |= MemRead(eai) << 8;			\
 PC = ea;					\
 BranchTrace();					\
}

// 65C02
#define Instr_JMP_IDIRX()			\
{						\
 eai = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 eai |= OpRead(PC) << 8;			\
 PC++;						\
 CMX();						\
						\
 eai += X;					\
 OpRead(PC - 1, true);				\
 CMX();						\
						\
 ea = MemRead(eai);				\
 eai++;						\
 CMX();						\
						\
 UpdateIFN();					\
 ea |= MemRead(eai) << 8;			\
 PC = ea;					\
 BranchTrace();					\
}

#define Instr_JSR()				\
{						\
 ea = OpRead(PC);				\
 PC++;						\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 CMX();						\
						\
 MemWrite(0x100 + SP, PC >> 8);			\
 SP--;						\
 CMX();						\
						\
 MemWrite(0x100 + SP, PC);			\
 SP--;						\
 CMX();						\
 /**/						\
 UpdateIFN();					\
 ea |= OpRead(PC) << 8;				\
 PC = ea;					\
 BranchTrace();					\
}

#define Instr_Bxx(cond_)			\
{						\
 UpdateIFN();					\
 v = OpRead(PC);				\
 PC++;						\
						\
 if((cond_))					\
 {						\
  CMX();					\
  OpRead(PC, true);				\
  /**/						\
  /**/						\
  /**/						\
  ea = PC + (int8)v;				\
						\
  if((ea ^ PC) & 0x100)				\
  {						\
   CMX();					\
   UpdateIFN();					\
   /* FIXME: PC, or (PC & 0xFF00) | (ea & 0x00FF) ?*/	\
   OpRead(PC, true);				\
  }						\
						\
  PC = ea;					\
  BranchTrace();				\
 }						\
}


#define Instr_RTI()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 SP++;						\
 CMX();						\
						\
 P = MemRead(0x100 + SP) & ~(FLAG_B | FLAG_U);	\
 SP++;						\
 CMX();						\
						\
 ea = MemRead(0x100 + SP);			\
 SP++;						\
 CMX();						\
 /**/						\
 UpdateIFN();					\
 ea |= MemRead(0x100 + SP) << 8;		\
 PC = ea;					\
 BranchTrace();					\
}

#define Instr_RTS()				\
{						\
 OpRead(PC, true);				\
 CMX();						\
						\
 MemRead(0x100 + SP, true);			\
 SP++;						\
 CMX();						\
						\
 ea = MemRead(0x100 + SP);			\
 SP++;						\
 CMX();						\
						\
 ea |= MemRead(0x100 + SP) << 8;		\
 PC = ea;					\
 CMX();						\
 /**/						\
 UpdateIFN();					\
 OpRead(PC, true);				\
 PC++;						\
 BranchTrace();					\
}

void Core6502::Power(void)
{
 PC = 0;
 P = 0;
 SP = 0;
 A = 0;
 X = 0;
 Y = 0;

 IFN = 0;
 NMIPending = false;
 NMIPrev = false;
 //
 resume_ea = 0;
 resume_eai = 0;
 resume_v = 0;
 resume_point = 0;
}

template<bool cmos>
void Core6502::RESETStep(void)
{
 uint16 new_PC;

 OpRead(PC, true);

 MemRead(0x100 + SP, true);
 SP--;

 MemRead(0x100 + SP, true);
 SP--;

 MemRead(0x100 + SP, true);
 SP--;

 P |= FLAG_I;
 if(cmos)
  P &= ~FLAG_D;

 new_PC = MemRead(0xFFFC);
 UpdateIFN();
 new_PC |= MemRead(0xFFFD) << 8;
 PC = new_PC;
 BranchTrace(0xFFFC);
}

#define CMX()					\
{						\
 if(Core6502_EnableMidExit && MDFN_UNLIKELY(NeedMidExit()))		\
 {						\
  enum : uint32 { resuc = __COUNTER__ - resume_bias };	\
  resume_ea = ea;				\
  resume_eai = eai;				\
  resume_v = v;					\
  resume_point = resuc;				\
  return;					\
  /**/						\
  case resuc:;					\
 }						\
}

template<bool cmos>
INLINE void Core6502::Step(void)
{
 uint16 ea;
 uint16 eai;
 uint8 v;
 uint32 rptemp;

 if(Core6502_EnableMidExit)
 {
  ea = resume_ea;
  eai = resume_eai;
  v = resume_v;
  rptemp = resume_point;
  resume_point = 0;
 }
 //
 //
 enum : uint32 { resume_bias = __COUNTER__ };
 switch(Core6502_EnableMidExit ? rptemp : 0)
 {
 case 0:
 //
 //
 #include "Core6502_step.inc"
 //
 //
 }
 static_assert((__COUNTER__ - resume_bias) <= 0x400, "boop");
}
#undef CMX

#undef GetEA_AB
#undef GetEA_ABi
#undef GetEA_ZP
#undef GetEA_ZPi
#undef GetEA_IDIR
#undef GetEA_IDIRX
#undef GetEA_IDIRY

#undef Instr_LD_IMM
#undef Instr_LD_ZP
#undef Instr_LD_ZPi
#undef Instr_LD_ZPX
#undef Instr_LD_ZPY
#undef Instr_LD_AB
#undef Instr_LD_ABi
#undef Instr_LD_ABX
#undef Instr_LD_ABY
#undef Instr_LD_IDIR
#undef Instr_LD_IDIRX
#undef Instr_LD_IDIRY
#undef Instr_RMW_A
#undef Instr_RMW_ZP
#undef Instr_RMW_ZPX
#undef Instr_RMW_AB
#undef Instr_RMW_ABi
#undef Instr_RMW_ABX
#undef Instr_RMW_ABY
#undef Instr_RMW_IDIRX
#undef Instr_RMW_IDIRY
#undef Instr_ST_ZP
#undef Instr_ST_ZPi
#undef Instr_ST_ZPX
#undef Instr_ST_ZPY
#undef Instr_ST_AB
#undef Instr_ST_ABi
#undef Instr_ST_ABX
#undef Instr_ST_ABY
#undef Instr_ST_IDIR
#undef Instr_ST_IDIRX
#undef Instr_ST_IDIRY
#undef Instr_ST_H_ILL_ABX
#undef Instr_ST_H_ILL_ABY
#undef Instr_ST_H_ILL_IDIRY
#undef Instr_IMP
#undef Instr_PHA
#undef Instr_PHX
#undef Instr_PHY
#undef Instr_PHP
#undef Instr_PLA
#undef Instr_PLX
#undef Instr_PLY
#undef Instr_PLP
#undef Instr_BRK
#undef Instr_JMP_ABS
#undef Instr_JMP_IDIR
#undef Instr_JMP_IDIRX
#undef Instr_JSR
#undef Instr_Bxx
#undef Instr_RTI
#undef Instr_RTS

