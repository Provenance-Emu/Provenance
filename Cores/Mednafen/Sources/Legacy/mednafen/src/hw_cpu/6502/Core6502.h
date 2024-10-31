/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* Core6502.h:
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

//template<unsigned Version>
struct Core6502
{
 Core6502();
 ~Core6502();

 void Power(void);

 void RESETStep(void);
 void Step(void);

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname);
 //
 //
 //
 uint8 MemRead(uint16, bool junk = false);
 uint8 OpRead(uint16, bool junk = false);	// Can be used for certain optimizations, otherwise map it to MemRead()
 void MemWrite(uint16, uint8);

 bool GetIRQ(void);
 bool GetNMI(void);

 void JamHandler(uint8 opcode);
 void BranchTrace(uint16 vector = 0);
 //
 //
 //
 //
 uint16 PC;

 enum
 {
  FLAG_C = 0x01,	// Carry
  FLAG_Z = 0x02,	// Zero
  FLAG_I = 0x04,	// Interrupt (Disable)
  FLAG_D = 0x08,	// Decimal Mode
  FLAG_B = 0x10,	// Break
  FLAG_U = 0x20,	// (Unused)
  FLAG_V = 0x40,	// Overflow
  FLAG_N = 0x80,	// Negative

  FLAG_BITPOS_C = 0,
  FLAG_BITPOS_Z = 1,
  FLAG_BITPOS_I = 2,
  FLAG_BITPOS_D = 3,
  FLAG_BITPOS_B = 4,
  FLAG_BITPOS_U = 5,
  FLAG_BITPOS_V = 6,
  FLAG_BITPOS_N = 7
 };
 uint8 P;
 uint8 SP;
 uint8 A;
 uint8 X;
 uint8 Y;

 unsigned IFN;
 bool NMITaken;
 private:

 void UpdateIFN(void);
 void CalcZN(uint8);

 void ISequence(bool hw);

 //void Push(uint8);
 //uint8 Pop(void);

 void Op_ASL(uint8&);
 void Op_LSR(uint8&);
 void Op_INC(uint8&);
 void Op_DEC(uint8&);
 void Op_ROL(uint8&);
 void Op_ROR(uint8&);

 void Op_ADC(uint8);
 void Op_SBC(uint8);

 void Op_CMPx(uint8, uint8);
 void Op_CMP(uint8);
 void Op_CPX(uint8);
 void Op_CPY(uint8);

 void Op_BIT(uint8);

 void Op_AND(uint8);
 void Op_EOR(uint8);
 void Op_ORA(uint8);

 void Op_LDA(uint8);
 void Op_LDX(uint8);
 void Op_LDY(uint8);

 uint8 Op_STA(void);
 uint8 Op_STX(void);
 uint8 Op_STY(void);

 uint16 GetEA_AB(void);
 template<bool UncondEC> uint16 GetEA_ABi(uint8 index);
 uint8 GetEA_ZP(void);
 uint8 GetEA_ZPi(uint8 index);
 uint16 GetEA_IDIRX(void);
 template<bool UncondEC> uint16 GetEA_IDIRY(void);

 template<bool index_y> void Instr_RMW_ABi(void (Core6502::*op)(uint8&));
 void Instr_RMW_A(void (Core6502::*op)(uint8&));
 void Instr_RMW_ZP(void (Core6502::*op)(uint8&));
 void Instr_RMW_ZPX(void (Core6502::*op)(uint8&));
 void Instr_RMW_AB(void (Core6502::*op)(uint8&));
 void Instr_RMW_ABX(void (Core6502::*op)(uint8&));
 void Instr_RMW_ABY(void (Core6502::*op)(uint8&));
 void Instr_RMW_IDIRX(void (Core6502::*op)(uint8&));
 void Instr_RMW_IDIRY(void (Core6502::*op)(uint8&));

 template<bool index_y> void Instr_LD_ZPi(void (Core6502::*op)(uint8));
 template<bool index_y> void Instr_LD_ABi(void (Core6502::*op)(uint8));
 void Instr_LD_IMM(void (Core6502::*op)(uint8));
 void Instr_LD_ZP(void (Core6502::*op)(uint8));
 void Instr_LD_ZPX(void (Core6502::*op)(uint8));
 void Instr_LD_ZPY(void (Core6502::*op)(uint8));
 void Instr_LD_AB(void (Core6502::*op)(uint8));
 void Instr_LD_ABX(void (Core6502::*op)(uint8));
 void Instr_LD_ABY(void (Core6502::*op)(uint8));
 void Instr_LD_IDIRX(void (Core6502::*op)(uint8));
 void Instr_LD_IDIRY(void (Core6502::*op)(uint8));

 template<bool index_y> void Instr_ST_ZPi(uint8 (Core6502::*op)(void));
 template<bool index_y> void Instr_ST_ABi(uint8 (Core6502::*op)(void));
 void Instr_ST_ZP(uint8 (Core6502::*op)(void));
 void Instr_ST_ZPX(uint8 (Core6502::*op)(void));
 void Instr_ST_ZPY(uint8 (Core6502::*op)(void));
 void Instr_ST_AB(uint8 (Core6502::*op)(void));
 void Instr_ST_ABX(uint8 (Core6502::*op)(void));
 void Instr_ST_ABY(uint8 (Core6502::*op)(void));
 void Instr_ST_IDIRX(uint8 (Core6502::*op)(void));
 void Instr_ST_IDIRY(uint8 (Core6502::*op)(void));

 void Instr_DEX(void);
 void Instr_DEY(void);
 void Instr_INX(void);
 void Instr_INY(void);

 void Instr_TAY(void);
 void Instr_TAX(void);
 void Instr_TXA(void);
 void Instr_TYA(void);
 void Instr_TXS(void);

 void Op_NOP(uint8 v);
 void Op_NOP(void);
 void Op_DEX(void);
 void Op_DEY(void);
 void Op_INX(void);
 void Op_INY(void);
 template<uint8 flag> void Op_CLx(void);
 template<uint8 flag> void Op_SEx(void);
 void Op_TAX(void);
 void Op_TAY(void);
 void Op_TYA(void);
 void Op_TXA(void);
 void Op_TSX(void);
 void Op_TXS(void);

 void Instr_IMP(void (Core6502::*op)(void));

 // Undocumented:
 void Op_AAC(uint8 v);
 void Op_ARR(uint8 v);
 void Op_ASR(uint8 v);
 void Op_ATX(uint8 v);
 void Op_AXS(uint8 v);
 void Op_LAS(uint8 v);
 void Op_LAX(uint8 v);
 void Op_XAA(uint8 v);

 void Op_DCP(uint8& v);
 void Op_ISC(uint8& v);
 void Op_RLA(uint8& v);
 void Op_RRA(uint8& v);
 void Op_SLO(uint8& v);
 void Op_SRE(uint8& v);

 uint8 Op_AAX(void);
 //
 void Instr_ST_H_ILL_ABX(uint8 (Core6502::*op)(uint8));
 void Instr_ST_H_ILL_ABY(uint8 (Core6502::*op)(uint8));
 void Instr_ST_H_ILL_IDIRY(uint8 (Core6502::*op)(uint8));
 uint8 Op_AXA(uint8);
 uint8 Op_SXA(uint8);
 uint8 Op_SYA(uint8);
 uint8 Op_XAS(uint8);
 // End undocumented

 void Instr_PHA(void);
 void Instr_PHP(void);
 void Instr_PLA(void);
 void Instr_PLP(void);

 void Instr_BRK(void);
 void Instr_JMP_ABS(void);
 void Instr_JMP_IDIR(void);
 void Instr_JSR(void);

 void Instr_Bxx(bool cond);

 void Instr_RTI(void);
 void Instr_RTS(void);
};

