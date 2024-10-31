/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Core6502.inc - 6502 CPU Emulator Core
**  Copyright (C) 2018 Mednafen Team
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

// FIXME: NMI sampling granularity

/*
 TODO:
 6502 versions to support:
	NMOS Synertek SY6502A
	NMOS Ricoh 2A03
	CMOS NCR 65C02(no SMB, RMB, BBS, BBR, STP, WAI?)
*/

//static const unsigned Core6502_Model; (no template param!)
//static const bool Core6502_EnableDecimalOps = true;

static const bool cmos6502 = false;	// placeholder todo
Core6502::Core6502() : NMITaken(false)
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
  SFVAR(NMITaken),

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
 IFN = (NMIActive & !NMITaken) | (IRQActive & !(P & FLAG_I));
 NMITaken &= NMIActive;
}

INLINE void Core6502::CalcZN(uint8 v)
{
 P &= ~(FLAG_N | FLAG_Z);
 P |= v & FLAG_N;
 P |= v ? 0 : FLAG_Z;
}

INLINE uint16 Core6502::GetEA_AB(void)
{
 uint16 ea;

 ea = OpRead(PC);
 PC++;

 ea |= OpRead(PC) << 8;
 PC++;

 return ea;
}

template<bool UncondEC>	// false on LD, true with RMW and ST
INLINE uint16 Core6502::GetEA_ABi(uint8 index)
{
 uint16 ea, eai;

 ea = GetEA_AB();
 eai = ea + index;
 ea = (ea & 0xFF00) | (eai & 0x00FF);
 
 if(UncondEC || ea != eai)
 {
  if(cmos6502)
   OpRead(PC, true);	// FIXME?: or PC - 1?
  else
   MemRead(ea, true);
  ea = eai;
 }

 return ea;
}

INLINE uint8 Core6502::GetEA_ZP(void)
{
 uint8 ea;

 ea = OpRead(PC);
 PC++;

 return ea;
}

INLINE uint8 Core6502::GetEA_ZPi(uint8 index)
{
 uint8 ea;

 ea = OpRead(PC);
 PC++;

 MemRead(ea, true);
 ea += index;

 return ea;
}

INLINE uint16 Core6502::GetEA_IDIRX(void)
{
 uint8 pea;
 uint16 ea;

 pea = OpRead(PC);
 PC++;

 MemRead(pea, true);
 pea += X;

 ea = MemRead(pea);
 pea++;

 ea |= MemRead(pea) << 8;

 return ea;
}

template<bool UncondEC>	// false on LD, true with RMW and ST
INLINE uint16 Core6502::GetEA_IDIRY(void)
{
 uint8 pea;
 uint16 ea, eai;

 pea = OpRead(PC);
 PC++;

 ea = MemRead(pea);
 pea++;

 ea |= MemRead(pea) << 8;
 eai = ea + Y;
 ea = (ea & 0xFF00) | (eai & 0x00FF);

 if(UncondEC || ea != eai)
 {
  if(cmos6502)
   OpRead(PC, true);	// FIXME?: or PC - 1?
  else
   MemRead(ea, true);
  ea = eai;
 }
 //
 //
 //

 return ea;
}

//
// Load
//
INLINE void Core6502::Instr_LD_IMM(void (Core6502::*op)(uint8))
{
 uint8 v;

 UpdateIFN();
 v = OpRead(PC);
 PC++;

 (this->*op)(v);
}

INLINE void Core6502::Instr_LD_ZP(void (Core6502::*op)(uint8))
{
 uint8 ea;
 uint8 v;

 ea = GetEA_ZP();

 UpdateIFN();
 v = MemRead(ea);

 (this->*op)(v);
}

template<bool index_y>
INLINE void Core6502::Instr_LD_ZPi(void (Core6502::*op)(uint8))
{
 uint8 ea;
 uint8 v;

 ea = GetEA_ZPi(index_y ? Y : X);

 UpdateIFN();
 v = MemRead(ea);

 (this->*op)(v);
}

INLINE void Core6502::Instr_LD_ZPX(void (Core6502::*op)(uint8)) { Instr_LD_ZPi<false>(op); }
INLINE void Core6502::Instr_LD_ZPY(void (Core6502::*op)(uint8)) { Instr_LD_ZPi<true>(op); }

INLINE void Core6502::Instr_LD_AB(void (Core6502::*op)(uint8))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_AB();

 UpdateIFN();
 v = MemRead(ea);

 (this->*op)(v);
}

template<bool index_y>
INLINE void Core6502::Instr_LD_ABi(void (Core6502::*op)(uint8))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_ABi<false>(index_y ? Y : X);

 UpdateIFN();
 v = MemRead(ea);

 (this->*op)(v);
}

INLINE void Core6502::Instr_LD_ABX(void (Core6502::*op)(uint8)) { Instr_LD_ABi<false>(op); }
INLINE void Core6502::Instr_LD_ABY(void (Core6502::*op)(uint8)) { Instr_LD_ABi<true>(op); }

INLINE void Core6502::Instr_LD_IDIRX(void (Core6502::*op)(uint8))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRX();

 UpdateIFN();
 v = MemRead(ea); 

 (this->*op)(v);
}

INLINE void Core6502::Instr_LD_IDIRY(void (Core6502::*op)(uint8))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRY<false>();

 UpdateIFN();
 v = MemRead(ea);

 (this->*op)(v);
}


//
// RMW
//
INLINE void Core6502::Instr_RMW_A(void (Core6502::*op)(uint8&))
{
 UpdateIFN();
 OpRead(PC, true);
 (this->*op)(A);
}

INLINE void Core6502::Instr_RMW_ZP(void (Core6502::*op)(uint8&))
{
 uint8 ea;
 uint8 v;

 ea = GetEA_ZP();

 v = MemRead(ea);
 if(cmos6502)
  MemRead(ea, true);
 else
  MemWrite(ea, v);
 (this->*op)(v);
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_RMW_ZPX(void (Core6502::*op)(uint8&))
{
 uint8 ea;
 uint8 v;

 ea = OpRead(PC);
 PC++;

 MemRead(ea, true);
 ea += X;

 v = MemRead(ea);
 if(cmos6502)
  MemRead(ea, true);
 else
  MemWrite(ea, v);
 (this->*op)(v);
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_RMW_AB(void (Core6502::*op)(uint8&))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_AB();

 v = MemRead(ea);
 if(cmos6502)
  MemRead(ea, true);
 else
  MemWrite(ea, v);
 (this->*op)(v);
 UpdateIFN();
 MemWrite(ea, v);
}

template<bool index_y>
INLINE void Core6502::Instr_RMW_ABi(void (Core6502::*op)(uint8&))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_ABi<true>(index_y ? Y : X);

 v = MemRead(ea);
 if(cmos6502)
  MemRead(ea, true);
 else
  MemWrite(ea, v);
 (this->*op)(v);
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_RMW_ABX(void (Core6502::*op)(uint8&)) { Instr_RMW_ABi<false>(op); }
INLINE void Core6502::Instr_RMW_ABY(void (Core6502::*op)(uint8&)) { Instr_RMW_ABi<true>(op); }

INLINE void Core6502::Instr_RMW_IDIRX(void (Core6502::*op)(uint8&))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRX();

 v = MemRead(ea);
 if(cmos6502)
  MemRead(ea, true);
 else
  MemWrite(ea, v);
 (this->*op)(v);
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_RMW_IDIRY(void (Core6502::*op)(uint8&))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRY<true>();

 v = MemRead(ea);
 if(cmos6502)
  MemRead(ea, true);
 else
  MemWrite(ea, v);
 (this->*op)(v);
 UpdateIFN();
 MemWrite(ea, v);
}


//
// Store
//
INLINE void Core6502::Instr_ST_ZP(uint8 (Core6502::*op)(void))
{
 uint8 ea;
 uint8 v;

 ea = GetEA_ZP();

 v = (this->*op)();
 UpdateIFN();
 MemWrite(ea, v);
}

template<bool index_y>
INLINE void Core6502::Instr_ST_ZPi(uint8 (Core6502::*op)(void))
{
 uint8 ea;
 uint8 v;

 ea = GetEA_ZPi(index_y ? Y : X);

 v = (this->*op)();
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_ST_ZPX(uint8 (Core6502::*op)(void)) { Instr_ST_ZPi<false>(op); }
INLINE void Core6502::Instr_ST_ZPY(uint8 (Core6502::*op)(void)) { Instr_ST_ZPi<true>(op); }

INLINE void Core6502::Instr_ST_AB(uint8 (Core6502::*op)(void))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_AB();

 v = (this->*op)();
 UpdateIFN();
 MemWrite(ea, v);
}

template<bool index_y>
INLINE void Core6502::Instr_ST_ABi(uint8 (Core6502::*op)(void))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_ABi<true>(index_y ? Y : X);

 v = (this->*op)();
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_ST_ABX(uint8 (Core6502::*op)(void)) { Instr_ST_ABi<false>(op); }
INLINE void Core6502::Instr_ST_ABY(uint8 (Core6502::*op)(void)) { Instr_ST_ABi<true>(op); }

INLINE void Core6502::Instr_ST_IDIRX(uint8 (Core6502::*op)(void))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRX();

 v = (this->*op)();
 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_ST_IDIRY(uint8 (Core6502::*op)(void))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRY<true>();

 v = (this->*op)();
 UpdateIFN();
 MemWrite(ea, v);
}

//
// Store (NMOS illegal special)
//
INLINE void Core6502::Instr_ST_H_ILL_ABX(uint8 (Core6502::*op)(uint8))
{
 uint16 ea, eai;
 uint8 v;

 ea = GetEA_AB();
 eai = ea + X;
 ea = (ea & 0xFF00) | (eai & 0x00FF);
 
 MemRead(ea, true);
 v = (this->*op)((ea >> 8) + 1);
 if(ea != eai)
  ea = (ea & 0xFF) | (v << 8);

 UpdateIFN();
 MemWrite(ea, v);
}

INLINE void Core6502::Instr_ST_H_ILL_ABY(uint8 (Core6502::*op)(uint8))
{
 uint16 ea, eai;
 uint8 v;

 ea = GetEA_AB();
 eai = ea + Y;
 ea = (ea & 0xFF00) | (eai & 0x00FF);
 
 MemRead(ea, true);
 v = (this->*op)((ea >> 8) + 1);
 if(ea != eai)
  ea = (ea & 0xFF) | (v << 8);

 UpdateIFN();
 MemWrite(ea, v);
}

// TODO/FIXME: For AXA; probably not right.
INLINE void Core6502::Instr_ST_H_ILL_IDIRY(uint8 (Core6502::*op)(uint8))
{
 uint16 ea;
 uint8 v;

 ea = GetEA_IDIRY<true>();

 v = (this->*op)(ea >> 8);
 UpdateIFN();
 MemWrite(ea, v);
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

//
//
//
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
  if(cmos6502)
  {
   OpRead(PC, true);	// FIXME?: or PC - 1?
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
  if(cmos6502)
  {
   abort(); // TODO/FIXME

   OpRead(PC, true);	// FIXME?: or PC - 1?
   CalcZN(result);
  }
  else
  {
   const unsigned l = (result & 0x1F) ^ ((A ^ v) & 0x10);

   if(result < 0x100)
    result -= 0x60;

   if(l < 0x10)
    result = (result & 0xF0) + ((result - 0x06) & 0x0F);
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

INLINE void Core6502::Op_ATX(uint8 v)
{
 /* TODO: Unstable */
 const uint8 result = A & v;
 
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

INLINE void Core6502::Op_XAA(uint8 v)
{
 /* TODO: Unstable */
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
 Op_SBC(v);
}

INLINE void Core6502::Op_RLA(uint8& v)
{
 Op_ROL(v);
 Op_AND(v);
}

INLINE void Core6502::Op_RRA(uint8& v)
{
 Op_ROR(v);
 Op_ADC(v);
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

INLINE void Core6502::Instr_IMP(void (Core6502::*op)(void))
{
 UpdateIFN();
 OpRead(PC, true);
 //
 (this->*op)();
}

INLINE void Core6502::Instr_PHA(void)
{
 OpRead(PC, true);

 UpdateIFN();
 MemWrite(0x100 + SP, A);
 SP--;
}

INLINE void Core6502::Instr_PHP(void)
{
 OpRead(PC, true);
 
 UpdateIFN();
 MemWrite(0x100 + SP, P | FLAG_B | FLAG_U);
 SP--;
}

INLINE void Core6502::Instr_PLA(void)
{
 OpRead(PC, true);

 MemRead(0x100 + SP, true);
 SP++;

 UpdateIFN();
 A = MemRead(0x100 + SP);
 CalcZN(A);
}

INLINE void Core6502::Instr_PLP(void)
{
 OpRead(PC, true);

 MemRead(0x100 + SP, true);
 SP++;

 UpdateIFN();
 P = MemRead(0x100 + SP);
}

INLINE void Core6502::ISequence(bool hw)
{
 uint16 new_PC;
 uint8 vlb;

 OpRead(PC, true);
 PC += !hw;

 MemWrite(0x100 + SP, PC >> 8);
 SP--;

 MemWrite(0x100 + SP, PC);
 SP--;

 MemWrite(0x100 + SP, P | (hw ? 0 : FLAG_B) | FLAG_U);
 SP--;

 P |= FLAG_I;

 if(cmos6502)
  P &= ~FLAG_D;

 if(GetNMI() && hw) //(!cmos6502 || hw))
 {
  vlb = 0xFA;
  NMITaken = true;
 }
 else
  vlb = 0xFE;

 new_PC = MemRead(0xFF00 | vlb);
 //
 UpdateIFN();
 new_PC |= MemRead(0xFF01 | vlb) << 8;
 PC = new_PC;
 BranchTrace(0xFF00 | vlb);
}

INLINE void Core6502::Instr_BRK(void)
{
 //abort();
 ISequence(false);
}

INLINE void Core6502::Instr_JMP_ABS(void)
{
 uint16 new_PC;

 new_PC = OpRead(PC);
 PC++;
 //
 UpdateIFN();
 new_PC |= OpRead(PC) << 8;
 PC = new_PC;
 BranchTrace();
}

INLINE void Core6502::Instr_JMP_IDIR(void)
{
 uint16 new_PC;
 uint16 pea;

 pea = OpRead(PC);
 PC++;

 pea |= OpRead(PC) << 8;
 PC++;

 new_PC = MemRead(pea);
 pea = ((pea + 1) & 0xFF) | (pea & 0xFF00);
 if(cmos6502)
 {
  // TODO
 }

 new_PC |= MemRead(pea) << 8;
 PC = new_PC;
 BranchTrace();
}

INLINE void Core6502::Instr_JSR(void)
{
 uint16 new_PC;

 new_PC = OpRead(PC);
 PC++;

 MemRead(0x100 + SP, true);

 MemWrite(0x100 + SP, PC >> 8);
 SP--;

 MemWrite(0x100 + SP, PC);
 SP--;
 //
 UpdateIFN();
 new_PC |= OpRead(PC) << 8;
 PC = new_PC;
 BranchTrace();
}

INLINE void Core6502::Instr_Bxx(bool cond)
{
 uint8 disp;

 UpdateIFN();
 disp = OpRead(PC);
 PC++;

 if(cond)
 {
  OpRead(PC, true);
  //
  //
  //
  const uint16 new_PC = PC + (int8)disp;

  if((new_PC ^ PC) & 0x100)
  {
   UpdateIFN();
   OpRead(PC, true);	// FIXME: PC, or (PC & 0xFF00) | (new_PC & 0x00FF) ?
  }

  PC = new_PC;
  BranchTrace();
 }
}


INLINE void Core6502::Instr_RTI(void)
{
 uint16 new_PC;

 OpRead(PC, true);

 MemRead(0x100 + SP, true);
 SP++;

 P = MemRead(0x100 + SP);
 SP++;

 new_PC = MemRead(0x100 + SP);
 SP++;
 //
 UpdateIFN();
 new_PC |= MemRead(0x100 + SP) << 8;
 PC = new_PC;
 BranchTrace();
}

INLINE void Core6502::Instr_RTS(void)
{
 uint16 new_PC;

 OpRead(PC, true);

 MemRead(0x100 + SP, true);
 SP++;

 new_PC = MemRead(0x100 + SP);
 SP++;

 new_PC |= MemRead(0x100 + SP) << 8;
 PC = new_PC;
 //
 UpdateIFN();
 OpRead(PC, true);
 PC++;
 BranchTrace();
}

void Core6502::Power(void)
{
 PC = 0;
 P = 0;
 SP = 0;
 A = 0;
 X = 0;
 Y = 0;
}

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
 if(cmos6502)
  P &= ~FLAG_D;

 new_PC = MemRead(0xFFFC);
 UpdateIFN();
 new_PC |= MemRead(0xFFFD) << 8;
 PC = new_PC;
 BranchTrace(0xFFFC);
}

INLINE void Core6502::Step(void)
{
 uint8 opcode;

 if(MDFN_UNLIKELY(IFN))
 {
  OpRead(PC, true);
  ISequence(true);
  return;
 }

 opcode = OpRead(PC);
 //printf("%04x %02x\n", PC, opcode);
 PC++;

 #define NMOS_CASE(x) case (x)

/*
 #define NMOS_CASE(x) case ((x) - (version == NMOS_6502) ? 0 : -1000)
 #define CMOS_CASE(x) case ((x) - (version == CMOS_6502) ? 0 : -2000)

 #define CMOS_WDC_CASE(x) case ((x) - (version == CMOS_6502_WDC) ? 0 : -3000)
 #define CMOS_WDCRW_CASE(x) case ((x) - (version == CMOS_6502_WDC || version == CMOS_6502_ROCKWELL) ? 0 : -4000)
*/
 switch(opcode)
 {
  #define INSTR(memop, amode, subop) Instr_ ## memop ## _ ##amode(&Core6502::Op_ ## subop);

  default:
	//printf("Unknown opcode @ PC=0x%04x: 0x%02x\n", PC - 1, opcode);
	break;

  //
  // Load
  //

  // ADC
  case 0x69: INSTR(LD, IMM,   ADC); break;
  case 0x65: INSTR(LD, ZP,    ADC); break;
  case 0x75: INSTR(LD, ZPX,   ADC); break;
  case 0x6D: INSTR(LD, AB,    ADC); break;
  case 0x7D: INSTR(LD, ABX,   ADC); break;
  case 0x79: INSTR(LD, ABY,   ADC); break;
  case 0x61: INSTR(LD, IDIRX, ADC); break;
  case 0x71: INSTR(LD, IDIRY, ADC); break;

  // AND
  case 0x29: INSTR(LD, IMM,   AND); break;
  case 0x25: INSTR(LD, ZP,    AND); break;
  case 0x35: INSTR(LD, ZPX,   AND); break;
  case 0x2D: INSTR(LD, AB,    AND); break;
  case 0x3D: INSTR(LD, ABX,   AND); break;
  case 0x39: INSTR(LD, ABY,   AND); break;
  case 0x21: INSTR(LD, IDIRX, AND); break;
  case 0x31: INSTR(LD, IDIRY, AND); break;

  // CMP
  case 0xC9: INSTR(LD, IMM,   CMP); break;
  case 0xC5: INSTR(LD, ZP,    CMP); break;
  case 0xD5: INSTR(LD, ZPX,   CMP); break;
  case 0xCD: INSTR(LD, AB,    CMP); break;
  case 0xDD: INSTR(LD, ABX,   CMP); break;
  case 0xD9: INSTR(LD, ABY,   CMP); break;
  case 0xC1: INSTR(LD, IDIRX, CMP); break;
  case 0xD1: INSTR(LD, IDIRY, CMP); break;

  // EOR
  case 0x49: INSTR(LD, IMM,   EOR); break;
  case 0x45: INSTR(LD, ZP,    EOR); break;
  case 0x55: INSTR(LD, ZPX,   EOR); break;
  case 0x4D: INSTR(LD, AB,    EOR); break;
  case 0x5D: INSTR(LD, ABX,   EOR); break;
  case 0x59: INSTR(LD, ABY,   EOR); break;
  case 0x41: INSTR(LD, IDIRX, EOR); break;
  case 0x51: INSTR(LD, IDIRY, EOR); break;

  // LDA
  case 0xA9: INSTR(LD, IMM,   LDA); break;
  case 0xA5: INSTR(LD, ZP,    LDA); break;
  case 0xB5: INSTR(LD, ZPX,   LDA); break;
  case 0xAD: INSTR(LD, AB,    LDA); break;
  case 0xBD: INSTR(LD, ABX,   LDA); break;
  case 0xB9: INSTR(LD, ABY,   LDA); break;
  case 0xA1: INSTR(LD, IDIRX, LDA); break;
  case 0xB1: INSTR(LD, IDIRY, LDA); break;

  // LDX
  case 0xA2: INSTR(LD, IMM,   LDX); break;
  case 0xA6: INSTR(LD, ZP,    LDX); break;
  case 0xB6: INSTR(LD, ZPY,   LDX); break;
  case 0xAE: INSTR(LD, AB,    LDX); break;
  case 0xBE: INSTR(LD, ABY,   LDX); break;

  // LDY
  case 0xA0: INSTR(LD, IMM,   LDY); break;
  case 0xA4: INSTR(LD, ZP,    LDY); break;
  case 0xB4: INSTR(LD, ZPX,   LDY); break;
  case 0xAC: INSTR(LD, AB,    LDY); break;
  case 0xBC: INSTR(LD, ABX,   LDY); break;

  // ORA
  case 0x09: INSTR(LD, IMM,   ORA); break;
  case 0x05: INSTR(LD, ZP,    ORA); break;
  case 0x15: INSTR(LD, ZPX,   ORA); break;
  case 0x0D: INSTR(LD, AB,    ORA); break;
  case 0x1D: INSTR(LD, ABX,   ORA); break;
  case 0x19: INSTR(LD, ABY,   ORA); break;
  case 0x01: INSTR(LD, IDIRX, ORA); break;
  case 0x11: INSTR(LD, IDIRY, ORA); break;

  // SBC
  NMOS_CASE(0xEB): //
  case 0xE9: INSTR(LD, IMM,   SBC); break;
  case 0xE5: INSTR(LD, ZP,    SBC); break;
  case 0xF5: INSTR(LD, ZPX,   SBC); break;
  case 0xED: INSTR(LD, AB,    SBC); break;
  case 0xFD: INSTR(LD, ABX,   SBC); break;
  case 0xF9: INSTR(LD, ABY,   SBC); break;
  case 0xE1: INSTR(LD, IDIRX, SBC); break;
  case 0xF1: INSTR(LD, IDIRY, SBC); break;

  // BIT
  case 0x24: INSTR(LD, ZP, BIT); break;
  case 0x2C: INSTR(LD, AB, BIT); break;

  // CPX
  case 0xE0: INSTR(LD, IMM, CPX); break;
  case 0xE4: INSTR(LD, ZP,  CPX); break;
  case 0xEC: INSTR(LD, AB,  CPX); break;

  // CPY
  case 0xC0: INSTR(LD, IMM, CPY); break;
  case 0xC4: INSTR(LD, ZP,  CPY); break;
  case 0xCC: INSTR(LD, AB,  CPY); break;


  //
  // Read-Modify-Write
  //

  // ASL
  case 0x0A: INSTR(RMW, A,   ASL); break;
  case 0x06: INSTR(RMW, ZP,  ASL); break;
  case 0x16: INSTR(RMW, ZPX, ASL); break;
  case 0x0E: INSTR(RMW, AB,  ASL); break;
  case 0x1E: INSTR(RMW, ABX, ASL); break;

  // DEC
  case 0xC6: INSTR(RMW, ZP,  DEC); break;
  case 0xD6: INSTR(RMW, ZPX, DEC); break;
  case 0xCE: INSTR(RMW, AB,  DEC); break;
  case 0xDE: INSTR(RMW, ABX, DEC); break;

  // INC
  case 0xE6: INSTR(RMW, ZP,  INC); break;
  case 0xF6: INSTR(RMW, ZPX, INC); break;
  case 0xEE: INSTR(RMW, AB,  INC); break;
  case 0xFE: INSTR(RMW, ABX, INC); break;

  // LSR
  case 0x4A: INSTR(RMW, A,   LSR); break;
  case 0x46: INSTR(RMW, ZP,  LSR); break;
  case 0x56: INSTR(RMW, ZPX, LSR); break;
  case 0x4E: INSTR(RMW, AB,  LSR); break;
  case 0x5E: INSTR(RMW, ABX, LSR); break;

  // ROL
  case 0x2A: INSTR(RMW, A,   ROL); break;
  case 0x26: INSTR(RMW, ZP,  ROL); break;
  case 0x36: INSTR(RMW, ZPX, ROL); break;
  case 0x2E: INSTR(RMW, AB,  ROL); break;
  case 0x3E: INSTR(RMW, ABX, ROL); break;

  // ROR
  case 0x6A: INSTR(RMW, A,   ROR); break;
  case 0x66: INSTR(RMW, ZP,  ROR); break;
  case 0x76: INSTR(RMW, ZPX, ROR); break;
  case 0x6E: INSTR(RMW, AB,  ROR); break;
  case 0x7E: INSTR(RMW, ABX, ROR); break;


  //
  // Store
  //

  // STA
  case 0x85: INSTR(ST, ZP,    STA); break;
  case 0x95: INSTR(ST, ZPX,   STA); break;
  case 0x8D: INSTR(ST, AB,    STA); break;
  case 0x9D: INSTR(ST, ABX,   STA); break;
  case 0x99: INSTR(ST, ABY,   STA); break;
  case 0x81: INSTR(ST, IDIRX, STA); break;
  case 0x91: INSTR(ST, IDIRY, STA); break;

  // STX
  case 0x86: INSTR(ST, ZP,    STX); break;
  case 0x96: INSTR(ST, ZPY,   STX); break;
  case 0x8E: INSTR(ST, AB,    STX); break;

  // STY
  case 0x84: INSTR(ST, ZP,    STY); break;
  case 0x94: INSTR(ST, ZPX,   STY); break;
  case 0x8C: INSTR(ST, AB,    STY); break;


  //
  // Branch
  //
  case 0x90: Instr_Bxx(!(P & FLAG_C)); break; // BCC
  case 0xB0: Instr_Bxx(P & FLAG_C); break; // BCS

  case 0xD0: Instr_Bxx(!(P & FLAG_Z)); break; // BNE
  case 0xF0: Instr_Bxx(P & FLAG_Z); break; // BEQ

  case 0x10: Instr_Bxx(!(P & FLAG_N)); break; // BPL
  case 0x30: Instr_Bxx(P & FLAG_N); break; // BMI

  case 0x50: Instr_Bxx(!(P & FLAG_V)); break; // BVC
  case 0x70: Instr_Bxx(P & FLAG_V); break; // BVS

  case 0x4C: Instr_JMP_ABS(); break;
  case 0x6C: Instr_JMP_IDIR(); break;

  case 0x20: Instr_JSR(); break;

  case 0x40: Instr_RTI(); break;
  case 0x60: Instr_RTS(); break;

  case 0x00: Instr_BRK(); break;

  //
  // Stack Manipulation
  //
  case 0x48: Instr_PHA(); break;
  case 0x08: Instr_PHP(); break;
  case 0x68: Instr_PLA(); break;
  case 0x28: Instr_PLP(); break;

#define INSTR_IMP(subop) Instr_IMP(&Core6502::Op_ ## subop);
  //
  // Implied
  //
  NMOS_CASE(0x1A): //
  NMOS_CASE(0x3A): //
  NMOS_CASE(0x5A): //
  NMOS_CASE(0x7A): //
  NMOS_CASE(0xDA): //
  NMOS_CASE(0xFA): //
  case 0xEA: INSTR_IMP(NOP); break;

  case 0xCA: INSTR_IMP(DEX); break;
  case 0x88: INSTR_IMP(DEY); break;
  case 0xE8: INSTR_IMP(INX); break;
  case 0xC8: INSTR_IMP(INY); break;

  case 0x18: INSTR_IMP(CLx<FLAG_C>); break; // CLC
  case 0xD8: INSTR_IMP(CLx<FLAG_D>); break; // CLD
  case 0x58: INSTR_IMP(CLx<FLAG_I>); break; // CLI
  case 0xB8: INSTR_IMP(CLx<FLAG_V>); break; // CLV

  case 0x38: INSTR_IMP(SEx<FLAG_C>); break; // SEC
  case 0xF8: INSTR_IMP(SEx<FLAG_D>); break; // SED
  case 0x78: INSTR_IMP(SEx<FLAG_I>); break; // SEI

  case 0xAA: INSTR_IMP(TAX); break;
  case 0xA8: INSTR_IMP(TAY); break;
  case 0x98: INSTR_IMP(TYA); break;
  case 0xBA: INSTR_IMP(TSX); break;
  case 0x8A: INSTR_IMP(TXA); break;
  case 0x9A: INSTR_IMP(TXS); break;

  //
  // Undocumented(TODO)
  //

  //
  // DCP
  //
  NMOS_CASE(0xC7): INSTR(RMW, ZP,    DCP); break;
  NMOS_CASE(0xD7): INSTR(RMW, ZPX,   DCP); break;
  NMOS_CASE(0xCF): INSTR(RMW, AB,    DCP); break;
  NMOS_CASE(0xDF): INSTR(RMW, ABX,   DCP); break;
  NMOS_CASE(0xDB): INSTR(RMW, ABY,   DCP); break;
  NMOS_CASE(0xC3): INSTR(RMW, IDIRX, DCP); break;
  NMOS_CASE(0xD3): INSTR(RMW, IDIRY, DCP); break;

  //
  // ISC
  //
  NMOS_CASE(0xE7): INSTR(RMW, ZP,    ISC); break;
  NMOS_CASE(0xF7): INSTR(RMW, ZPX,   ISC); break;
  NMOS_CASE(0xEF): INSTR(RMW, AB,    ISC); break;
  NMOS_CASE(0xFF): INSTR(RMW, ABX,   ISC); break;
  NMOS_CASE(0xFB): INSTR(RMW, ABY,   ISC); break;
  NMOS_CASE(0xE3): INSTR(RMW, IDIRX, ISC); break;
  NMOS_CASE(0xF3): INSTR(RMW, IDIRY, ISC); break;

  //
  // RLA
  //
  NMOS_CASE(0x27): INSTR(RMW, ZP,    RLA); break;
  NMOS_CASE(0x37): INSTR(RMW, ZPX,   RLA); break;
  NMOS_CASE(0x2F): INSTR(RMW, AB,    RLA); break;
  NMOS_CASE(0x3F): INSTR(RMW, ABX,   RLA); break;
  NMOS_CASE(0x3B): INSTR(RMW, ABY,   RLA); break;
  NMOS_CASE(0x23): INSTR(RMW, IDIRX, RLA); break;
  NMOS_CASE(0x33): INSTR(RMW, IDIRY, RLA); break;

  //
  // RRA
  //
  NMOS_CASE(0x67): INSTR(RMW, ZP,    RRA); break;
  NMOS_CASE(0x77): INSTR(RMW, ZPX,   RRA); break;
  NMOS_CASE(0x6F): INSTR(RMW, AB,    RRA); break;
  NMOS_CASE(0x7F): INSTR(RMW, ABX,   RRA); break;
  NMOS_CASE(0x7B): INSTR(RMW, ABY,   RRA); break;
  NMOS_CASE(0x63): INSTR(RMW, IDIRX, RRA); break;
  NMOS_CASE(0x73): INSTR(RMW, IDIRY, RRA); break;

  //
  // SLO / ASO
  //
  NMOS_CASE(0x07): INSTR(RMW, ZP,    SLO); break;
  NMOS_CASE(0x17): INSTR(RMW, ZPX,   SLO); break;
  NMOS_CASE(0x0F): INSTR(RMW, AB,    SLO); break;
  NMOS_CASE(0x1F): INSTR(RMW, ABX,   SLO); break;
  NMOS_CASE(0x1B): INSTR(RMW, ABY,   SLO); break;
  NMOS_CASE(0x03): INSTR(RMW, IDIRX, SLO); break;
  NMOS_CASE(0x13): INSTR(RMW, IDIRY, SLO); break;

  //
  // SRE
  //
  NMOS_CASE(0x47): INSTR(RMW, ZP,    SRE); break;
  NMOS_CASE(0x57): INSTR(RMW, ZPX,   SRE); break;
  NMOS_CASE(0x4F): INSTR(RMW, AB,    SRE); break;
  NMOS_CASE(0x5F): INSTR(RMW, ABX,   SRE); break;
  NMOS_CASE(0x5B): INSTR(RMW, ABY,   SRE); break;
  NMOS_CASE(0x43): INSTR(RMW, IDIRX, SRE); break;
  NMOS_CASE(0x53): INSTR(RMW, IDIRY, SRE); break;

  //
  // ARR
  //
  NMOS_CASE(0x6B): INSTR(LD, IMM, ARR); break;

  //
  // ASR
  //
  NMOS_CASE(0x4B): INSTR(LD, IMM, ASR); break;

  //
  // AAC
  //
  NMOS_CASE(0x0B):
  NMOS_CASE(0x2B): INSTR(LD, IMM, AAC); break;

  //
  // AXS
  //
  NMOS_CASE(0xCB): INSTR(LD, IMM, AXS); break;

  //
  // ATX ***
  //
  NMOS_CASE(0xAB): INSTR(LD, IMM, ATX); break;

  //
  // XAA ***
  //
  NMOS_CASE(0x8B): INSTR(LD, IMM, XAA); break;


  //
  // LAS ***?
  //
  NMOS_CASE(0xBB): INSTR(LD, ABY,   LAS); break;

  //
  // LAX ***?
  //
  NMOS_CASE(0xA7): INSTR(LD, ZP,    LAX); break;
  NMOS_CASE(0xB7): INSTR(LD, ZPY,   LAX); break;
  NMOS_CASE(0xAF): INSTR(LD, AB,    LAX); break;
  NMOS_CASE(0xBF): INSTR(LD, ABY,   LAX); break;
  NMOS_CASE(0xA3): INSTR(LD, IDIRX, LAX); break;
  NMOS_CASE(0xB3): INSTR(LD, IDIRY, LAX); break;

  //
  // DOP
  //
  NMOS_CASE(0x04): //
  NMOS_CASE(0x44): //
  NMOS_CASE(0x64): INSTR(LD, ZP, NOP); break;
  NMOS_CASE(0x14): //
  NMOS_CASE(0x34): //
  NMOS_CASE(0x54): //
  NMOS_CASE(0x74): //
  NMOS_CASE(0xD4): //
  NMOS_CASE(0xF4): INSTR(LD, ZPX, NOP); break;
  NMOS_CASE(0x80): //
  NMOS_CASE(0x82): //
  NMOS_CASE(0x89): //
  NMOS_CASE(0xC2): //
  NMOS_CASE(0xE2): INSTR(LD, IMM, NOP); break;

  //
  // TOP
  //
  NMOS_CASE(0x0C): INSTR(LD, AB,    NOP); break;
  NMOS_CASE(0x1C):
  NMOS_CASE(0x3C):
  NMOS_CASE(0x5C):
  NMOS_CASE(0x7C):
  NMOS_CASE(0xDC):
  NMOS_CASE(0xFC): INSTR(LD, ABX,   NOP); break;

  //
  // AAX
  //
  NMOS_CASE(0x87): INSTR(ST, ZP,    AAX); break;
  NMOS_CASE(0x97): INSTR(ST, ZPY,   AAX); break;
  NMOS_CASE(0x8F): INSTR(ST, AB,    AAX); break;
  NMOS_CASE(0x83): INSTR(ST, IDIRX, AAX); break;

  //
  // AXA ***
  //
  NMOS_CASE(0x9F): INSTR(ST_H_ILL, ABY,   AXA); break;
  NMOS_CASE(0x93): INSTR(ST_H_ILL, IDIRY, AXA); break;

  //
  // SXA ***
  //
  NMOS_CASE(0x9E): INSTR(ST_H_ILL, ABY,   SXA); break;

  //
  // SYA ***
  //
  NMOS_CASE(0x9C): INSTR(ST_H_ILL, ABX,   SYA); break;

  //
  // XAS ***
  //
  NMOS_CASE(0x9B): INSTR(ST_H_ILL, ABY,   XAS); break;

  //
  // KIL / JAM
  //
  NMOS_CASE(0x02):
  NMOS_CASE(0x12):
  NMOS_CASE(0x22):
  NMOS_CASE(0x32):
  NMOS_CASE(0x42):
  NMOS_CASE(0x52):
  NMOS_CASE(0x62):
  NMOS_CASE(0x72):
  NMOS_CASE(0x92):
  NMOS_CASE(0xB2):
  NMOS_CASE(0xD2):
  NMOS_CASE(0xF2): JamHandler(opcode); break;

  #undef INSTR_IMP
  #undef INSTR

#if 0
 // CMOS TODO
  case 0x72: INSTR(LD, ABIDIR, ADC); break;
  case 0x32: INSTR(LD, ABIDIR, AND); break;
  case 0xD2: INSTR(LD, ABIDIR, CMP); break;
  case 0x52: INSTR(LD, ABIDIR, EOR); break;
  case 0xB2: INSTR(LD, ABIDIR, LDA); break;
  case 0x12: INSTR(LD, ABIDIR, ORA); break;
  case 0xF2: INSTR(LD, ABIDIR, SBC); break;
  case 0x92: INSTR(ST, ABIDIR, STA); break;

  case 0x3C: INSTR(LD, ABX, BIT); break;
  case 0x34: INSTR(LD, ZPX, BIT); break;
  case 0x89: INSTR(LD, IMM, BIT); break;

  case 0x3A: INSTR(RMW, A, DEC); break;
  case 0x1A: INSTR(RMW, A, INC); break;

  case 0x7C: Instr_JMP_IDIRX(); break;

  case 0x80: Instr_Bxx(true); break; // BRA

  case 0xDA: Instr_PHX(); break;
  case 0xFA: Instr_PLX(); break;
  case 0x5A: Instr_PHY(); break;
  case 0x7A: Instr_PLY(); break;

  case 0x64: INSTR(ST, ZP,    STZ); break;
  case 0x74: INSTR(ST, ZPX,   STZ); break;
  case 0x9C: INSTR(ST, AB,    STZ); break;
  case 0x9E: INSTR(ST, ABX,   STZ); break;

  case 0x1C: INSTR(RMW, AB, TRB); break;
  case 0x14: INSTR(RMW, ZP, TRB); break;

  case 0x0C: INSTR(RMW, AB, TSB); break;
  case 0x04: INSTR(RMW, ZP, TSB); break;

  case 0x0F: Instr_BBR<0>(); break;
  case 0x1F: Instr_BBR<1>(); break;
  case 0x2F: Instr_BBR<2>(); break;
  case 0x3F: Instr_BBR<3>(); break;
  case 0x4F: Instr_BBR<4>(); break;
  case 0x5F: Instr_BBR<5>(); break;
  case 0x6F: Instr_BBR<6>(); break;
  case 0x7F: Instr_BBR<7>(); break;

  case 0x8F: Instr_BBS<0>(); break;
  case 0x9F: Instr_BBS<1>(); break;
  case 0xAF: Instr_BBS<2>(); break;
  case 0xBF: Instr_BBS<3>(); break;
  case 0xCF: Instr_BBS<4>(); break;
  case 0xDF: Instr_BBS<5>(); break;
  case 0xEF: Instr_BBS<6>(); break;
  case 0xFF: Instr_BBS<7>(); break;

  // STP (WDC only?)
  case 0xDB: break;

  // WAI (WDC only?)
  case 0xCB: break;
#endif

 }
}
