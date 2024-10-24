/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Core6502.h:
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

//template<unsigned Version>
struct Core6502
{
 Core6502();
 ~Core6502();

 void Power(void);

 template<bool cmos = false>
 void RESETStep(void);

 template<bool cmos = false>
 void Step(void);

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname);
 //
 //
 //
 uint8 MemRead(uint16, bool junk = false);
 uint8 OpRead(uint16, bool junk = false);	// Can be used for certain optimizations, otherwise map it to MemRead()
 void MemWrite(uint16, uint8);

 bool NeedMidExit(void);

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
 bool NMIPending;
 bool NMIPrev;

 //
 //
 uint32 resume_point;
 uint16 resume_ea, resume_eai;
 uint8 resume_v;
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
 void Op_TRB(uint8&); // 65C02
 void Op_TSB(uint8&); // 65C02

 template<bool cmos> void Op_ADC(uint8);
 template<bool cmos> void Op_SBC(uint8);

 void Op_CMPx(uint8, uint8);
 void Op_CMP(uint8);
 void Op_CPX(uint8);
 void Op_CPY(uint8);

 void Op_BIT(uint8);
 void Op_BIT_IMM(uint8); // 65C02

 void Op_AND(uint8);
 void Op_EOR(uint8);
 void Op_ORA(uint8);

 void Op_LDA(uint8);
 void Op_LDX(uint8);
 void Op_LDY(uint8);

 uint8 Op_STA(void);
 uint8 Op_STX(void);
 uint8 Op_STY(void);
 uint8 Op_STZ(void); // 65C02

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
 uint8 Op_AXA(uint8);
 uint8 Op_SXA(uint8);
 uint8 Op_SYA(uint8);
 uint8 Op_XAS(uint8);
 // End undocumented
};

