/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Core65816.inc - 65816 CPU Emulator Core
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

Core65816::Core65816()
{
 PCPBRDummy = 0x00;
}

Core65816::~Core65816()
{


}

//
//
//
template<typename T>
INLINE void Core65816::SetZN(T arg)
{
 P &= ~(Z_FLAG | N_FLAG);

 if(!arg)
  P |= Z_FLAG;

 P |= (arg >> ((sizeof(T) - 1) * 8)) & N_FLAG;
}

template<typename T>
INLINE void Core65816::Push(T arg)
{
 if(sizeof(T) == 2)
 {
  MemWrite<uint8>(S, arg >> 8);
  S--;
 }

 MemWrite<uint8>(S, arg);
 S--;
}

template<typename T>
INLINE T Core65816::Pull(void)
{
 T ret = 0;

 S++;
 ret |= MemRead<uint8>(S);

 if(sizeof(T) == 2)
 {
  S++;
  ret |= MemRead<uint8>(S) << 8;
 }

 return ret;
}

// ABORT not fully implemented/tested.
INLINE void Core65816::ISequence(unsigned which)
{
 uint16 vecaddr;

 switch(which)
 {
  case ISEQ_COP: vecaddr = 0xFFE4; break;
  case ISEQ_BRK: vecaddr = 0xFFE6; break;
  case ISEQ_ABORT: vecaddr = 0xFFE8; break;
  case ISEQ_NMI: vecaddr = 0xFFEA; break;
  case ISEQ_IRQ: vecaddr = 0xFFEE; break;
 }

 Push<uint8>(PBR);
 Push<uint16>(PC);
 Push<uint8>(P);

 P = (P & ~D_FLAG) | I_FLAG;
 PBR = 0x00;
 PC = VecRead(vecaddr);
 BranchOccurred(which);

 SNES_DBG("[CPU] ISeq %u: %04x\n", which, PC);
}

//
//
//

INLINE void Core65816::Instr_BRK(void)
{
 OpRead(PCPBR);
 PC++;
 OpRead(PCPBR);

 ISequence(ISEQ_BRK);
 SampleIRQ();
}

INLINE void Core65816::Instr_COP(void)
{
 OpRead(PCPBR);
 PC++;
 OpRead(PCPBR);

 ISequence(ISEQ_COP);
 SampleIRQ();
}

INLINE void Core65816::Instr_NOP(void)
{
 IO();
}

INLINE void Core65816::Instr_WDM(void)
{
 OpRead(PCPBR);
 PC++;
}

//
//
//
template<typename T>
INLINE void Core65816::Op_ADC(T arg)
{
 T& AA = AC<T>();
 uint32 tmp;

 if(P & D_FLAG)
 {
  uint32 a, b, c, d;

  a = (AA & 0x000F) + (arg & 0x000F) + (P & 1);
  b = (AA & 0x00F0) + (arg & 0x00F0);

  P &= ~(C_FLAG | V_FLAG);

  if(sizeof(T) == 2)
  {
   c = (AA & 0x0F00) + (arg & 0x0F00);
   d = (AA & 0xF000) + (arg & 0xF000);

   if(a > 0x0009) { b +=  0x0010; a += 0x0006; }
   if(b > 0x0090) { c +=  0x0100; b += 0x0060; }
   if(c > 0x0900) { d +=  0x1000; c += 0x0600; }
   P |= ((~(AA ^ arg) & (AA ^ d)) >> (sizeof(T) * 8 - 7)) & 0x40;		// V flag
   if(d > 0x9000) { P |= C_FLAG;  d += 0x6000; }

   tmp = (a & 0x000F) | (b & 0x00F0) | (c & 0x0F00) | (d & 0xF000);
  }
  else
  {
   if(a > 0x0009) { b +=  0x0010; a += 0x0006; }
   P |= ((~(AA ^ arg) & (AA ^ b)) >> (sizeof(T) * 8 - 7)) & 0x40;		// V flag
   if(b > 0x0090) { P |= C_FLAG;  b += 0x0060; }

   tmp = (a & 0x000F) | (b & 0x00F0);
  }
 }
 else
 {
  tmp = AA + arg + (P & 1);

  P &= ~(C_FLAG | V_FLAG);
  P |= (tmp >> (sizeof(T) * 8)) & 1;	// C flag
  P |= ((~(AA ^ arg) & (AA ^ tmp)) >> (sizeof(T) * 8 - 7)) & 0x40;		// V flag
 }

 AA = tmp;
 SetZN<T>(AA);
}

template<typename T>
INLINE void Core65816::Op_AND(T arg)
{
 T& AA = AC<T>();

 AA &= arg;

 SetZN<T>(AA);
}

template<typename T, bool immediate>
INLINE void Core65816::Op_BIT(T arg)	// N and V flags are not modified in the immediate addressing form of BIT.
{
 T& AA = AC<T>();

 P &= ~Z_FLAG;

 if(!(AA & arg))
  P |= Z_FLAG;

 if(!immediate)
 {
  P &= ~(N_FLAG | V_FLAG);
  P |= (arg >> ((sizeof(T) - 1) * 8)) & (N_FLAG | V_FLAG);
 }
}

template<typename T>
INLINE void Core65816::Op_Compare(T rv, T arg)
{
 uint32 tmp = rv - arg;

 SetZN<T>(tmp);

 P &= ~C_FLAG;
 P |= ((tmp >> (sizeof(T) * 8)) & 1) ^ 1;
}

template<typename T>
INLINE void Core65816::Op_CMP(T arg)
{
 Op_Compare<T>(C, arg);
}

template<typename T>
INLINE void Core65816::Op_CPX(T arg)
{
 Op_Compare<T>(X, arg);
}

template<typename T>
INLINE void Core65816::Op_CPY(T arg)
{
 Op_Compare<T>(Y, arg);
}

template<typename T>
INLINE void Core65816::Op_EOR(T arg)
{
 T& AA = AC<T>();

 AA ^= arg;

 SetZN<T>(AA);
}

template<typename T>
INLINE void Core65816::Op_LDA(T arg)
{
 T& AA = AC<T>();

 AA = arg;

 SetZN<T>(AA);
}

template<typename T>
INLINE void Core65816::Op_LDX(T arg)
{
 X = arg;

 SetZN<T>(X);
}

template<typename T>
INLINE void Core65816::Op_LDY(T arg)
{
 Y = arg;

 SetZN<T>(Y);
}

template<typename T>
INLINE void Core65816::Op_ORA(T arg)
{
 T& AA = AC<T>();

 AA |= arg;

 SetZN<T>(AA);
}

template<typename T>
INLINE void Core65816::Op_SBC(T arg)
{
 T& AA = AC<T>();
 uint32 tmp;

 arg = ~arg;

 if(P & D_FLAG)
 {
  uint32 a, b, c, d;

  a = (AA & 0x000F) + (arg & 0x000F) + (P & 1);
  b = (AA & 0x00F0) + (arg & 0x00F0) + (a & 0x0010);

  P &= ~(C_FLAG | V_FLAG);

  if(sizeof(T) == 2)
  {
   c = (AA & 0x0F00) + (arg & 0x0F00) + (b & 0x0100);
   d = (AA & 0xF000) + (arg & 0xF000) + (c & 0x1000);

   P |= ((d >> (sizeof(T) * 8)) & 1);	// C flag   

   if(a < 0x00010) { a -= 0x0006; }
   if(b < 0x00100) { b -= 0x0060; }
   if(c < 0x01000) { c -= 0x0600; }
   P |= ((~(AA ^ arg) & (AA ^ d)) >> (sizeof(T) * 8 - 7)) & 0x40;		// V flag
   if(d < 0x10000) { d -= 0x6000; }

   tmp = (a & 0x000F) | (b & 0x00F0) | (c & 0x0F00) | (d & 0xF000);
  }
  else
  {
   P |= ((b >> (sizeof(T) * 8)) & 1);	// C flag   

   if(a < 0x0010) { a -= 0x0006; }
   P |= ((~(AA ^ arg) & (AA ^ b)) >> (sizeof(T) * 8 - 7)) & 0x40;		// V flag
   if(b < 0x0100) { b -= 0x0060; }

   tmp = (a & 0x000F) | (b & 0x00F0);
  }
 }
 else
 {
  tmp = AA + arg + (P & 1);

  P &= ~(C_FLAG | V_FLAG);
  P |= ((tmp >> (sizeof(T) * 8)) & 1);	// C flag
  P |= ((~(AA ^ arg) & (AA ^ tmp)) >> (sizeof(T) * 8 - 7)) & 0x40;		// V flag
 }

 AA = tmp;
 SetZN<T>(AA);
}


//
//
//
template<typename T>
INLINE void Core65816::Op_ASL(T& arg)
{
 P &= ~C_FLAG;
 P |= arg >> (8 * sizeof(T) - 1);

 arg <<= 1;

 SetZN<T>(arg);
}

template<typename T>
INLINE void Core65816::Op_DEC(T& arg)
{
 arg--;

 SetZN<T>(arg);
}

template<typename T>
INLINE void Core65816::Op_INC(T& arg)
{
 arg++;

 SetZN<T>(arg);
}

template<typename T>
INLINE void Core65816::Op_LSR(T& arg)
{
 P &= ~C_FLAG;
 P |= arg & 1;

 arg >>= 1;

 SetZN<T>(arg);
}

template<typename T>
INLINE void Core65816::Op_ROL(T& arg)
{
 const bool new_CF = arg >> (sizeof(T) * 8 - 1);

 arg <<= 1;

 arg |= (P & 1);
 P &= ~C_FLAG;
 P |= new_CF;

 SetZN<T>(arg);
}

template<typename T>
INLINE void Core65816::Op_ROR(T& arg)
{
 const bool new_CF = arg & 1;

 arg >>= 1;

 arg |= (P & 1) << (sizeof(T) * 8 - 1);
 P &= ~C_FLAG;
 P |= new_CF;

 SetZN<T>(arg);
}

template<typename T>
INLINE void Core65816::Op_TRB(T& arg)
{
 T& AA = AC<T>();

 P &= ~Z_FLAG;
 if(!(arg & AA))
  P |= Z_FLAG;

 arg &= ~AA;
}

template<typename T>
INLINE void Core65816::Op_TSB(T& arg)
{
 T& AA = AC<T>();

 P &= ~Z_FLAG;
 if(!(arg & AA))
  P |= Z_FLAG;

 arg |= AA;
}

//
//
//
// NOTE: Since we're hardcoding in DBR in GetEA_AB(), don't use it
// to implement JSR/JMP/whatever(at least not without modification).
INLINE uint32 Core65816::GetEA_AB(void)
{
 uint32 ea = DBRSL16;

 ea |= OpRead(PCPBR);
 PC++;

 ea |= OpRead(PCPBR) << 8;
 PC++;

 return ea;
}

template<bool UncondEC>
INLINE uint32 Core65816::GetEA_ABI(uint16 index)
{
 uint32 ea;

 ea = GetEA_AB();

 if(UncondEC || (((ea + index) ^ ea) & 0x100))
  IO();

 ea = (ea + index) & 0xFFFFFF;

 return ea;
}

template<bool UncondEC>
INLINE uint32 Core65816::GetEA_ABX(void)
{
 return GetEA_ABI<UncondEC>(X);
}

template<bool UncondEC>
INLINE uint32 Core65816::GetEA_ABY(void)
{
 return GetEA_ABI<UncondEC>(Y);
}

INLINE uint32 Core65816::GetEA_ABL(void)
{
 uint32 ea;

 ea = OpRead(PCPBR);
 PC++;

 ea |= OpRead(PCPBR) << 8;
 PC++;

 ea |= OpRead(PCPBR) << 16;
 PC++;

 return ea;
}

INLINE uint32 Core65816::GetEA_ABLX(void)
{
 uint32 ea;

 ea = GetEA_ABL();
 ea = (ea + X) & 0xFFFFFF;

 return ea;
}

INLINE uint16 Core65816::GetEA_DP(void)	// d
{
 uint16 ea;

 ea = OpRead(PCPBR);
 PC++;

 if(D & 0xFF)
  IO();

 ea = (ea + D);

 return ea;
}

INLINE uint16 Core65816::GetEA_DPI(uint16 index)
{
 uint16 ea;

 ea = GetEA_DP();

 IO();
 ea = (ea + index);

 return ea;
}

INLINE uint16 Core65816::GetEA_DPX(void)	// d, X
{
 return GetEA_DPI(X);
}

INLINE uint16 Core65816::GetEA_DPY(void)	// d, Y
{
 return GetEA_DPI(Y);
}

INLINE uint32 Core65816::GetEA_IND(void)	// (d)
{
 uint16 eadp;
 uint32 ea = DBRSL16;

 eadp = GetEA_DP();

 ea |= MemRead<uint8>(eadp);
 eadp++;

 ea |= MemRead<uint8>(eadp) << 8;

 return ea;
}

INLINE uint32 Core65816::GetEA_INDL(void)	// [d]
{
 uint16 eadp;
 uint32 ea;

 eadp = GetEA_DP();

 ea = MemRead<uint8>(eadp);
 eadp++;

 ea |= MemRead<uint8>(eadp) << 8;
 eadp++;

 ea |= MemRead<uint8>(eadp) << 16;

 return ea;
}

INLINE uint32 Core65816::GetEA_IX(void)	// (d, X)
{
 uint16 eadp;
 uint32 ea = DBRSL16;

 eadp = GetEA_DPX();

 ea |= MemRead<uint8>(eadp);
 eadp++;

 ea |= MemRead<uint8>(eadp) << 8;

 return ea;
}

template<bool UncondEC>
INLINE uint32 Core65816::GetEA_IY(void)	// (d), Y
{
 uint32 ea;

 ea = GetEA_IND();

 if(UncondEC || (((ea + Y) ^ ea) & 0x100))
  IO();

 ea = (ea + Y) & 0xFFFFFF;

 return ea;
}

INLINE uint32 Core65816::GetEA_ILY(void)	// [d], Y
{
 uint32 ea;

 ea = GetEA_INDL();

 ea = (ea + Y) & 0xFFFFFF;

 return ea;
}

INLINE uint16 Core65816::GetEA_SR(void)
{
 uint16 ea;

 ea = OpRead(PCPBR);
 PC++;

 IO();
 ea = (ea + S);

 return ea;
}

INLINE uint32 Core65816::GetEA_SRIY(void)	// (whatever, S), Y
{
 uint16 easp;
 uint32 ea = DBRSL16;

 easp = GetEA_SR();

 ea |= MemRead<uint8>(easp);
 easp++;

 ea |= MemRead<uint8>(easp) << 8;

 IO();
 ea = (ea + Y) & 0xFFFFFF;

 return ea;
}

//
//
//
template<typename T>
INLINE void Core65816::Instr_LD_IM(void (Core65816::*op)(T))
{
 T tmp;

 tmp = OpRead(PCPBR);
 PC++;

 if(sizeof(T) == 2)
 {
  tmp |= OpRead(PCPBR) << 8;
  PC++;
 }

 (this->*op)(tmp);
}

template<typename T, typename EAT>
INLINE void Core65816::Instr_LD(EAT (Core65816::*eafn)(void), void (Core65816::*op)(T))
{
 EAT ea = (this->*eafn)();
 T tmp = MemRead<T>(ea);

 (this->*op)(tmp);
}

template<typename T>
INLINE void Core65816::Instr_RMW_A(void (Core65816::*op)(T&))
{
 IO();
 (this->*op)(AC<T>());
}

template<typename T, typename EAT>
INLINE void Core65816::Instr_RMW(EAT (Core65816::*eafn)(void), void (Core65816::*op)(T&))
{
 // For 16-bit: L, H, H, L
 EAT ea = (this->*eafn)();
 T tmp = MemRead<T>(ea);

 IO();
 (this->*op)(tmp);

 if(sizeof(T) == 2)
  MemWrite<uint8>(ea + 1, tmp >> 8);

 MemWrite<uint8>(ea, tmp);
}

template<typename T, typename EAT>
INLINE void Core65816::Instr_ST(EAT (Core65816::*eafn)(void), T (Core65816::*op)(void))
{
 EAT ea = (this->*eafn)();
 T tmp = (this->*op)();

 MemWrite<T>(ea, tmp);
}

//
//
//

//
//
//

INLINE void Core65816::Instr_Bxx(bool cond)
{
 int8 disp;

 disp = OpRead(PCPBR);
 PC++;

 if(cond)
 {
  IO();
  PC += disp;
  BranchOccurred();
 }
}

INLINE void Core65816::Instr_BRL(void)
{
 uint16 disp;

 disp = OpRead(PCPBR);
 PC++;

 disp |= OpRead(PCPBR) << 8;
 PC++;

 IO();
 PC += disp;
 BranchOccurred();
}

INLINE void Core65816::Instr_JML(void)
{
 uint16 npc;

 npc = OpRead(PCPBR);
 PC++;

 npc |= OpRead(PCPBR) << 8;
 PC++;

 PBR = OpRead(PCPBR);

 PC = npc;
 BranchOccurred();
}

INLINE void Core65816::Instr_JML_I(void)
{
 uint32 ea = 0;	// Bank 0, not DBR!

 ea |= OpRead(PCPBR);
 PC++;

 ea |= OpRead(PCPBR) << 8;

 PC = MemRead<uint16>(ea);
 PBR = MemRead<uint8>((ea + 2) & 0xFFFFFF);
 BranchOccurred();
}

INLINE void Core65816::Instr_JMP(void)
{
 uint16 npc;

 npc = OpRead(PCPBR);
 PC++;

 npc |= OpRead(PCPBR) << 8;

 PC = npc;
 BranchOccurred();
}

INLINE void Core65816::Instr_JMP_I(void)
{
 uint32 ea = 0;	// Bank 0, not DBR!

 ea |= OpRead(PCPBR);
 PC++;

 ea |= OpRead(PCPBR) << 8;

 PC = MemRead<uint16>(ea);
 BranchOccurred();
}

//
// PBR not DBR, and wrap within bank for both + X and reading high byte of PC.
//
INLINE void Core65816::Instr_JMP_II(void)
{
 uint16 ea;

 ea = OpRead(PCPBR);
 PC++;

 ea |= OpRead(PCPBR) << 8;
 IO();
 ea += X;

 PC  = MemRead<uint8>((PBR << 16) | ea);
 ea++;
 PC |= MemRead<uint8>((PBR << 16) | ea) << 8;
 BranchOccurred();
}

INLINE void Core65816::Instr_JSL(void)
{
 uint16 npc;

 npc = OpRead(PCPBR);
 PC++;
 npc |= OpRead(PCPBR) << 8;
 PC++;

 Push<uint8>(PBR);

 IO();

 PBR = OpRead(PCPBR);

 Push<uint16>(PC);

 PC = npc;
 BranchOccurred();
}

INLINE void Core65816::Instr_JSR(void)	// Different memory access order from 6502...
{
 uint16 npc;

 npc = OpRead(PCPBR);
 PC++;
 npc |= OpRead(PCPBR) << 8;

 IO();

 Push<uint16>(PC);
 PC = npc;
 BranchOccurred();
}

//
// PBR not DBR, and wrap within bank for both + X and reading high byte of PC.
//
INLINE void Core65816::Instr_JSR_II(void)
{
 uint16 ea;

 ea = OpRead(PCPBR);
 PC++;

 Push<uint16>(PC);

 ea |= OpRead(PCPBR) << 8;
 IO();
 ea += X;

 PC  = MemRead<uint8>((PBR << 16) | ea);
 ea++;
 PC |= MemRead<uint8>((PBR << 16) | ea) << 8;
}


INLINE void Core65816::Instr_RTI(void)
{
 IO();
 IO();

 P = Pull<uint8>();
 PC = Pull<uint16>();
 // TODO: SampleIRQ();
 PBR = Pull<uint8>();
 BranchOccurred();

 if(P & X_FLAG)
 {
  X = (uint8)X;
  Y = (uint8)Y;
 }

 SampleIRQ();
}

INLINE void Core65816::Instr_RTL(void)
{
 IO();
 IO();

 PC = Pull<uint16>() + 1;
 PBR = Pull<uint8>();
 BranchOccurred();
}

INLINE void Core65816::Instr_RTS(void)
{
 IO();
 IO();

 PC = Pull<uint16>() + 1;
 BranchOccurred();

 IO();
}

//
//
//

template<typename T>
INLINE void Core65816::Instr_INX(void)
{
 IO();
 X = (T)(X + 1);
 SetZN<T>(X);
}

template<typename T>
INLINE void Core65816::Instr_INY(void)
{
 IO();
 Y = (T)(Y + 1);
 SetZN<T>(Y);
}

template<typename T>
INLINE void Core65816::Instr_DEX(void)
{
 IO();
 X = (T)(X - 1);
 SetZN<T>(X);
}

template<typename T>
INLINE void Core65816::Instr_DEY(void)
{
 IO();
 Y = (T)(Y - 1);
 SetZN<T>(Y);
}

//
//
//

template<typename T>
INLINE void Core65816::Instr_TAX(void)
{
 IO();

 X = (T)C;

 SetZN<T>(X);
}

template<typename T>
INLINE void Core65816::Instr_TAY(void)
{
 IO();

 Y = (T)C;

 SetZN<T>(Y);
}

INLINE void Core65816::Instr_TCD(void)
{
 IO();

 D = C;

 SetZN<uint16>(D);
}

INLINE void Core65816::Instr_TCS(void)
{
 IO();
 if(MDFN_UNLIKELY(E))
  S = 0x100 | (uint8)C;
 else
  S = C;
}

INLINE void Core65816::Instr_TDC(void)
{
 IO();
 C = D;

 SetZN<uint16>(C);
}

INLINE void Core65816::Instr_TSC(void)
{
 IO();
 C = S;

 SetZN<uint16>(C);
}

template<typename T>
INLINE void Core65816::Instr_TSX(void)
{
 IO();
 X = (T)S;

 SetZN<T>(X);
}

template<typename T>
INLINE void Core65816::Instr_TXA(void)
{
 IO();
 AC<T>() = X;

 SetZN<T>(C);
}

INLINE void Core65816::Instr_TXS(void)
{
 IO();
 if(MDFN_UNLIKELY(E)) // SNES "Metal Marines" definitely needs this.
  S = 0x100 | (uint8)X;
 else
  S = X;
}

template<typename T>
INLINE void Core65816::Instr_TXY(void)
{
 IO();
 Y = X;

 SetZN<T>(Y);
}

template<typename T>
INLINE void Core65816::Instr_TYA(void)
{
 IO();
 AC<T>() = Y;

 SetZN<T>(C);
}

template<typename T>
INLINE void Core65816::Instr_TYX(void)
{
 IO();
 X = Y;

 SetZN<T>(X);
}

INLINE void Core65816::Instr_XBA(void)
{
 uint8 tmp = B;

 IO();
 IO();

 B = A;
 A = tmp;

 SetZN<uint8>(A);
}

INLINE void Core65816::Instr_XCE(void)
{
 bool new_E = P & C_FLAG;

 P &= ~C_FLAG;
 P |= E;

 E = new_E;

 IO();
 SNES_DBG("[CPU] XCE: %u\n", E);
}

//
//
//

template<unsigned TA_Mask>
INLINE void Core65816::Instr_CLx(void)
{
 IO();
 P &= ~TA_Mask;
}

template<unsigned TA_Mask>
INLINE void Core65816::Instr_SEx(void)
{
 IO();
 P |= TA_Mask;
}

//
//
//

template<typename X_type, int increment>
INLINE void Core65816::Instr_MVx(void)
{
 // opcode, dstbank, srcbank
 //
 // dstbank is loaded into DBR.
 //
 // source addr: srcbank, X reg
 // dest addr, dstbank, Y reg
 //
 // Respects X flag, seems to ignore M flag.
 uint8 SB;
 uint8 tmp;

 DBRSL16 = OpRead(PCPBR) << 16;
 PC++;

 SB = OpRead(PCPBR);
 PC++;

 //
 //
 tmp = MemRead<uint8>((SB << 16) | X);
 MemWrite<uint8>((DBRSL16) | Y, tmp);
 //
 //

 X = (X_type)(X + increment);
 Y = (X_type)(Y + increment);

 IO();
 IO();

 C--;
 if(C != 0xFFFF)
  PC -= 3;
}

INLINE void Core65816::Instr_PEA(void)	// Push Effective Absolute Address
{
 uint16 ea = GetEA_AB();

 Push<uint16>(ea);
}

INLINE void Core65816::Instr_PEI(void)	// Push Effective Indirect Address
{
 uint16 ea = GetEA_IND();

 Push<uint16>(ea);
}

INLINE void Core65816::Instr_PER(void)	// Push Effective PC Relative Address
{
 uint16 ea = GetEA_AB();

 IO();
 ea += PC;

 Push<uint16>(ea);
}

template<typename T>
INLINE void Core65816::Instr_PHA(void)
{
 IO();
 Push<T>(AC<T>());
}

INLINE void Core65816::Instr_PHB(void)
{
 IO();
 Push<uint8>(DBRSL16 >> 16);
}

INLINE void Core65816::Instr_PHD(void)
{
 IO();
 Push<uint16>(D);
}

INLINE void Core65816::Instr_PHK(void)
{
 IO();
 Push<uint8>(PBR);
}

INLINE void Core65816::Instr_PHP(void)
{
 IO();
 Push<uint8>(P);
}

template<typename T>
INLINE void Core65816::Instr_PHX(void)
{
 IO();
 Push<T>(X);
}

template<typename T>
INLINE void Core65816::Instr_PHY(void)
{
 IO();
 Push<T>(Y);
}

template<typename T>
INLINE void Core65816::Instr_PLA(void)
{
 IO();
 IO();

 AC<T>() = Pull<T>();
 SetZN<T>(AC<T>());
}

INLINE void Core65816::Instr_PLB(void)
{
 IO();
 IO();

 uint8 tmp = Pull<uint8>();

 SetZN<uint8>(tmp);
 DBRSL16 = tmp << 16;
}

INLINE void Core65816::Instr_PLD(void)
{
 IO();
 IO();

 D = Pull<uint16>();
 SetZN<uint16>(D);
}

INLINE void Core65816::Instr_PLP(void)
{
 IO();
 IO();

 P = Pull<uint8>();

 if(P & X_FLAG)
 {
  X = (uint8)X;
  Y = (uint8)Y;
 }
}

template<typename T>
INLINE void Core65816::Instr_PLX(void)
{
 IO();
 IO();

 X = Pull<T>();
 SetZN<T>(X);
}

template<typename T>
INLINE void Core65816::Instr_PLY(void)
{
 IO();
 IO();

 Y = Pull<T>();
 SetZN<T>(Y);
}

INLINE void Core65816::Instr_REP(void)
{
 uint8 tmp;

 tmp = OpRead(PCPBR);
 PC++;

 IO();
 P &= ~tmp;
}

INLINE void Core65816::Instr_SEP(void)
{
 uint8 tmp;

 tmp = OpRead(PCPBR);
 PC++;

 IO();
 P |= tmp;

 if(P & X_FLAG)
 {
  X = (uint8)X;
  Y = (uint8)Y;
 }
}


template<uint8 opcode, typename M_type, typename X_type>
INLINE void Core65816::RunInstruction(void)
{
 switch(opcode)
 {
  case 0x00: Instr_BRK(); break;	// BRK
  case 0x02: Instr_COP(); break;	// COP
  case 0xEA: Instr_NOP(); break;	// NOP
  case 0xDB: Instr_STP(); break;	// STP
  case 0xCB: Instr_WAI(); break;	// WAI
  case 0x42: Instr_WDM(); break;	// WDM (effectively 2-byte NOP).

  //
  // Block transfer
  //
  case 0x44: Instr_MVx<X_type, -1>(); break;	// MVP
  case 0x54: Instr_MVx<X_type,  1>(); break;	// MVN

  //
  // Stack pushing...
  //
  case 0xF4: Instr_PEA(); break;	// PEA
  case 0xD4: Instr_PEI(); break;	// PEI
  case 0x62: Instr_PER(); break;	// PER
  case 0x48: Instr_PHA<M_type>(); break;	// PHA
  case 0x8B: Instr_PHB(); break;		// PHB
  case 0x0B: Instr_PHD(); break;		// PHD
  case 0x4B: Instr_PHK(); break;		// PHK
  case 0x08: Instr_PHP(); break;		// PHP
  case 0xDA: Instr_PHX<X_type>(); break;	// PHX
  case 0x5A: Instr_PHY<X_type>(); break;	// PHY

  //
  // ...and pulling.
  //
  case 0x68: Instr_PLA<M_type>(); break;	// PLA
  case 0xAB: Instr_PLB(); break;		// PLB
  case 0x2B: Instr_PLD(); break;		// PLD
  case 0x28: Instr_PLP(); break;		// PLP
  case 0xFA: Instr_PLX<X_type>(); break;	// PLX
  case 0x7A: Instr_PLY<X_type>(); break;	// PLY

  case 0x4C: Instr_JMP(); break;	// JMP $addr
  case 0x6C: Instr_JMP_I(); break;	// JMP ($addr)
  case 0x7C: Instr_JMP_II(); break;	// JMP ($addr, X)
  case 0x5C: Instr_JML(); break;	// JMP long(aka JML).
  case 0xDC: Instr_JML_I(); break;	// JMP [long] (aka JML)

  case 0x22: Instr_JSL(); break;	// JSR long(aka JSL)
  case 0x20: Instr_JSR(); break;	// JSR $addr
  case 0xFC: Instr_JSR_II(); break;	// JSR ($addr, X)

  case 0x40: Instr_RTI(); break;	// RTI
  case 0x6B: Instr_RTL(); break;	// RTL
  case 0x60: Instr_RTS(); break;	// RTS

  #define INSTR(J, K, L) Instr_##J(&Core65816::GetEA_##K, &Core65816::Op_##L)
  //
  // ADC
  //
  case 0x69: Instr_LD_IM  (&Core65816::Op_ADC<M_type>); break;
  case 0x65: INSTR(LD, DP,	ADC<M_type>); break;
  case 0x75: INSTR(LD, DPX,	ADC<M_type>); break;
  case 0x6D: INSTR(LD, AB,	ADC<M_type>); break;
  case 0x6F: INSTR(LD, ABL,	ADC<M_type>); break;
  case 0x7D: INSTR(LD, ABX<sizeof(X_type) == 2>,	ADC<M_type>); break;
  case 0x7F: INSTR(LD, ABLX,	ADC<M_type>); break;
  case 0x79: INSTR(LD, ABY<sizeof(X_type) == 2>,	ADC<M_type>); break;
  case 0x72: INSTR(LD, IND,	ADC<M_type>); break;
  case 0x67: INSTR(LD, INDL,	ADC<M_type>); break;
  case 0x61: INSTR(LD, IX,	ADC<M_type>); break;
  case 0x71: INSTR(LD, IY<sizeof(X_type) == 2>,	ADC<M_type>); break;
  case 0x77: INSTR(LD, ILY,	ADC<M_type>); break;
  case 0x63: INSTR(LD, SR,	ADC<M_type>); break;
  case 0x73: INSTR(LD, SRIY,	ADC<M_type>); break;

  //
  // AND
  //
  case 0x29: Instr_LD_IM  (&Core65816::Op_AND<M_type>); break;
  case 0x25: INSTR(LD, DP,	AND<M_type>); break;
  case 0x35: INSTR(LD, DPX,	AND<M_type>); break;
  case 0x2D: INSTR(LD, AB,	AND<M_type>); break;
  case 0x2F: INSTR(LD, ABL,	AND<M_type>); break;
  case 0x3D: INSTR(LD, ABX<sizeof(X_type) == 2>,	AND<M_type>); break;
  case 0x3F: INSTR(LD, ABLX,	AND<M_type>); break;
  case 0x39: INSTR(LD, ABY<sizeof(X_type) == 2>,	AND<M_type>); break;
  case 0x32: INSTR(LD, IND,	AND<M_type>); break;
  case 0x27: INSTR(LD, INDL,	AND<M_type>); break;
  case 0x21: INSTR(LD, IX,	AND<M_type>); break;
  case 0x31: INSTR(LD, IY<sizeof(X_type) == 2>,	AND<M_type>); break;
  case 0x37: INSTR(LD, ILY,	AND<M_type>); break;
  case 0x23: INSTR(LD, SR,	AND<M_type>); break;
  case 0x33: INSTR(LD, SRIY,	AND<M_type>); break;

  //
  // CMP
  //
  case 0xC9: Instr_LD_IM  (&Core65816::Op_CMP<M_type>); break;
  case 0xC5: INSTR(LD, DP,	CMP<M_type>); break;
  case 0xD5: INSTR(LD, DPX,	CMP<M_type>); break;
  case 0xCD: INSTR(LD, AB,	CMP<M_type>); break;
  case 0xCF: INSTR(LD, ABL,	CMP<M_type>); break;
  case 0xDD: INSTR(LD, ABX<sizeof(X_type) == 2>,	CMP<M_type>); break;
  case 0xDF: INSTR(LD, ABLX,	CMP<M_type>); break;
  case 0xD9: INSTR(LD, ABY<sizeof(X_type) == 2>,	CMP<M_type>); break;
  case 0xD2: INSTR(LD, IND,	CMP<M_type>); break;
  case 0xC7: INSTR(LD, INDL,	CMP<M_type>); break;
  case 0xC1: INSTR(LD, IX,	CMP<M_type>); break;
  case 0xD1: INSTR(LD, IY<sizeof(X_type) == 2>,	CMP<M_type>); break;
  case 0xD7: INSTR(LD, ILY,	CMP<M_type>); break;
  case 0xC3: INSTR(LD, SR,	CMP<M_type>); break;
  case 0xD3: INSTR(LD, SRIY,	CMP<M_type>); break;

  //
  // EOR
  //
  case 0x49: Instr_LD_IM  (&Core65816::Op_EOR<M_type>); break;
  case 0x45: INSTR(LD, DP,	EOR<M_type>); break;
  case 0x55: INSTR(LD, DPX,	EOR<M_type>); break;
  case 0x4D: INSTR(LD, AB,	EOR<M_type>); break;
  case 0x4F: INSTR(LD, ABL,	EOR<M_type>); break;
  case 0x5D: INSTR(LD, ABX<sizeof(X_type) == 2>,	EOR<M_type>); break;
  case 0x5F: INSTR(LD, ABLX,	EOR<M_type>); break;
  case 0x59: INSTR(LD, ABY<sizeof(X_type) == 2>,	EOR<M_type>); break;
  case 0x52: INSTR(LD, IND,	EOR<M_type>); break;
  case 0x47: INSTR(LD, INDL,	EOR<M_type>); break;
  case 0x41: INSTR(LD, IX,	EOR<M_type>); break;
  case 0x51: INSTR(LD, IY<sizeof(X_type) == 2>,	EOR<M_type>); break;
  case 0x57: INSTR(LD, ILY,	EOR<M_type>); break;
  case 0x43: INSTR(LD, SR,	EOR<M_type>); break;
  case 0x53: INSTR(LD, SRIY,	EOR<M_type>); break;

  //
  // LDA
  //
  case 0xA9: Instr_LD_IM  (&Core65816::Op_LDA<M_type>); break;
  case 0xA5: INSTR(LD, DP,	LDA<M_type>); break;
  case 0xB5: INSTR(LD, DPX,	LDA<M_type>); break;
  case 0xAD: INSTR(LD, AB,	LDA<M_type>); break;
  case 0xAF: INSTR(LD, ABL,	LDA<M_type>); break;
  case 0xBD: INSTR(LD, ABX<sizeof(X_type) == 2>,	LDA<M_type>); break;
  case 0xBF: INSTR(LD, ABLX,	LDA<M_type>); break;
  case 0xB9: INSTR(LD, ABY<sizeof(X_type) == 2>,	LDA<M_type>); break;
  case 0xB2: INSTR(LD, IND,	LDA<M_type>); break;
  case 0xA7: INSTR(LD, INDL,	LDA<M_type>); break;
  case 0xA1: INSTR(LD, IX,	LDA<M_type>); break;
  case 0xB1: INSTR(LD, IY<sizeof(X_type) == 2>,	LDA<M_type>); break;
  case 0xB7: INSTR(LD, ILY,	LDA<M_type>); break;
  case 0xA3: INSTR(LD, SR,	LDA<M_type>); break;
  case 0xB3: INSTR(LD, SRIY,	LDA<M_type>); break;

  //
  // ORA
  //
  case 0x09: Instr_LD_IM  (&Core65816::Op_ORA<M_type>); break;
  case 0x05: INSTR(LD, DP,	ORA<M_type>); break;
  case 0x15: INSTR(LD, DPX,	ORA<M_type>); break;
  case 0x0D: INSTR(LD, AB,	ORA<M_type>); break;
  case 0x0F: INSTR(LD, ABL,	ORA<M_type>); break;
  case 0x1D: INSTR(LD, ABX<sizeof(X_type) == 2>,	ORA<M_type>); break;
  case 0x1F: INSTR(LD, ABLX,	ORA<M_type>); break;
  case 0x19: INSTR(LD, ABY<sizeof(X_type) == 2>,	ORA<M_type>); break;
  case 0x12: INSTR(LD, IND,	ORA<M_type>); break;
  case 0x07: INSTR(LD, INDL,	ORA<M_type>); break;
  case 0x01: INSTR(LD, IX,	ORA<M_type>); break;
  case 0x11: INSTR(LD, IY<sizeof(X_type) == 2>,	ORA<M_type>); break;
  case 0x17: INSTR(LD, ILY,	ORA<M_type>); break;
  case 0x03: INSTR(LD, SR,	ORA<M_type>); break;
  case 0x13: INSTR(LD, SRIY,	ORA<M_type>); break;

  //
  // SBC
  //
  case 0xE9: Instr_LD_IM  (&Core65816::Op_SBC<M_type>); break;
  case 0xE5: INSTR(LD, DP,	SBC<M_type>); break;
  case 0xF5: INSTR(LD, DPX,	SBC<M_type>); break;
  case 0xED: INSTR(LD, AB,	SBC<M_type>); break;
  case 0xEF: INSTR(LD, ABL,	SBC<M_type>); break;
  case 0xFD: INSTR(LD, ABX<sizeof(X_type) == 2>,	SBC<M_type>); break;
  case 0xFF: INSTR(LD, ABLX,	SBC<M_type>); break;
  case 0xF9: INSTR(LD, ABY<sizeof(X_type) == 2>,	SBC<M_type>); break;
  case 0xF2: INSTR(LD, IND,	SBC<M_type>); break;
  case 0xE7: INSTR(LD, INDL,	SBC<M_type>); break;
  case 0xE1: INSTR(LD, IX,	SBC<M_type>); break;
  case 0xF1: INSTR(LD, IY<sizeof(X_type) == 2>,	SBC<M_type>); break;
  case 0xF7: INSTR(LD, ILY,	SBC<M_type>); break;
  case 0xE3: INSTR(LD, SR,	SBC<M_type>); break;
  case 0xF3: INSTR(LD, SRIY,	SBC<M_type>); break;

  //
  // STA
  //
  case 0x85: INSTR(ST, DP,	STA<M_type>); break;
  case 0x95: INSTR(ST, DPX,	STA<M_type>); break;
  case 0x8D: INSTR(ST, AB,	STA<M_type>); break;
  case 0x8F: INSTR(ST, ABL,	STA<M_type>); break;
  case 0x9D: INSTR(ST, ABX<true>,	STA<M_type>); break;
  case 0x9F: INSTR(ST, ABLX,	STA<M_type>); break;
  case 0x99: INSTR(ST, ABY<true>,	STA<M_type>); break;
  case 0x92: INSTR(ST, IND,	STA<M_type>); break;
  case 0x87: INSTR(ST, INDL,	STA<M_type>); break;
  case 0x81: INSTR(ST, IX,	STA<M_type>); break;
  case 0x91: INSTR(ST, IY<true>,	STA<M_type>); break;
  case 0x97: INSTR(ST, ILY,	STA<M_type>); break;
  case 0x83: INSTR(ST, SR,	STA<M_type>); break;
  case 0x93: INSTR(ST, SRIY,	STA<M_type>); break;

  //
  // BIT
  //
  case 0x89: Instr_LD_IM(&Core65816::Op_BIT<M_type, true>); break;
  case 0x24: INSTR(LD, DP,	BIT<M_type>); break;
  case 0x34: INSTR(LD, DPX,	BIT<M_type>); break;
  case 0x2C: INSTR(LD, AB,	BIT<M_type>); break;
  case 0x3C: INSTR(LD, ABX<sizeof(X_type) == 2>,	BIT<M_type>); break;

  //
  // CPX
  //
  case 0xE0: Instr_LD_IM (&Core65816::Op_CPX<X_type>); break;
  case 0xE4: INSTR(LD, DP,	CPX<X_type>); break;
  case 0xEC: INSTR(LD, AB,	CPX<X_type>); break;

  //
  // CPY
  //
  case 0xC0: Instr_LD_IM (&Core65816::Op_CPY<X_type>); break;
  case 0xC4: INSTR(LD, DP,	CPY<X_type>); break;
  case 0xCC: INSTR(LD, AB,	CPY<X_type>); break;

  //
  // LDX
  //
  case 0xA2: Instr_LD_IM (&Core65816::Op_LDX<X_type>); break;
  case 0xA6: INSTR(LD, DP,	LDX<X_type>); break;
  case 0xB6: INSTR(LD, DPY,	LDX<X_type>); break;
  case 0xAE: INSTR(LD, AB,	LDX<X_type>); break;
  case 0xBE: INSTR(LD, ABY<sizeof(X_type) == 2>,	LDX<X_type>); break;

  //
  // LDY
  //
  case 0xA0: Instr_LD_IM (&Core65816::Op_LDY<X_type>); break;
  case 0xA4: INSTR(LD, DP,	LDY<X_type>); break;
  case 0xB4: INSTR(LD, DPX,	LDY<X_type>); break;
  case 0xAC: INSTR(LD, AB,	LDY<X_type>); break;
  case 0xBC: INSTR(LD, ABX<sizeof(X_type) == 2>,	LDY<X_type>); break;

  //
  // STX
  //
  case 0x86: INSTR(ST, DP,	STX<X_type>); break;
  case 0x96: INSTR(ST, DPY,	STX<X_type>); break;
  case 0x8E: INSTR(ST, AB,	STX<X_type>); break;

  //
  // STY
  //
  case 0x84: INSTR(ST, DP,	STY<X_type>); break;
  case 0x94: INSTR(ST, DPX,	STY<X_type>); break;
  case 0x8C: INSTR(ST, AB,	STY<X_type>); break;

  //
  // STZ
  //
  case 0x64: INSTR(ST, DP,	STZ<M_type>); break;
  case 0x74: INSTR(ST, DPX,	STZ<M_type>); break;
  case 0x9C: INSTR(ST, AB,	STZ<M_type>); break;
  case 0x9E: INSTR(ST, ABX<true>,	STZ<M_type>); break;

  //
  //
  // ASL
  //
  case 0x0A: Instr_RMW_A(&Core65816::Op_ASL<M_type>); break;
  case 0x06: INSTR(RMW, DP,	ASL<M_type>); break;
  case 0x16: INSTR(RMW, DPX,	ASL<M_type>); break;
  case 0x0E: INSTR(RMW, AB,	ASL<M_type>); break;
  case 0x1E: INSTR(RMW, ABX<true>,	ASL<M_type>); break;

  //
  // DEC
  //
  case 0x3A: Instr_RMW_A(&Core65816::Op_DEC<M_type>); break;
  case 0xC6: INSTR(RMW, DP,	DEC<M_type>); break;
  case 0xD6: INSTR(RMW, DPX,	DEC<M_type>); break;
  case 0xCE: INSTR(RMW, AB,	DEC<M_type>); break;
  case 0xDE: INSTR(RMW, ABX<true>,	DEC<M_type>); break;

  //
  // INC
  //
  case 0x1A: Instr_RMW_A(&Core65816::Op_INC<M_type>); break;
  case 0xE6: INSTR(RMW, DP,	INC<M_type>); break;
  case 0xF6: INSTR(RMW, DPX,	INC<M_type>); break;
  case 0xEE: INSTR(RMW, AB,	INC<M_type>); break;
  case 0xFE: INSTR(RMW, ABX<true>,	INC<M_type>); break;

  //
  // LSR
  //
  case 0x4A: Instr_RMW_A(&Core65816::Op_LSR<M_type>); break;
  case 0x46: INSTR(RMW, DP,	LSR<M_type>); break;
  case 0x56: INSTR(RMW, DPX,	LSR<M_type>); break;
  case 0x4E: INSTR(RMW, AB,	LSR<M_type>); break;
  case 0x5E: INSTR(RMW, ABX<true>,	LSR<M_type>); break;

  //
  // ROL
  //
  case 0x2A: Instr_RMW_A(&Core65816::Op_ROL<M_type>); break;
  case 0x26: INSTR(RMW, DP,	ROL<M_type>); break;
  case 0x36: INSTR(RMW, DPX,	ROL<M_type>); break;
  case 0x2E: INSTR(RMW, AB,	ROL<M_type>); break;
  case 0x3E: INSTR(RMW, ABX<true>,	ROL<M_type>); break;

  //
  // ROR
  //
  case 0x6A: Instr_RMW_A(&Core65816::Op_ROR<M_type>); break;
  case 0x66: INSTR(RMW, DP,	ROR<M_type>); break;
  case 0x76: INSTR(RMW, DPX,	ROR<M_type>); break;
  case 0x6E: INSTR(RMW, AB,	ROR<M_type>); break;
  case 0x7E: INSTR(RMW, ABX<true>,	ROR<M_type>); break;

  //
  // TRB
  //
  case 0x14: INSTR(RMW, DP,	TRB<M_type>); break;
  case 0x1C: INSTR(RMW, AB,	TRB<M_type>); break;

  //
  // TSB
  //
  case 0x04: INSTR(RMW, DP,	TSB<M_type>); break;
  case 0x0C: INSTR(RMW, AB,	TSB<M_type>); break;

  #undef INSTR

  case 0xE8: Instr_INX<X_type>(); break;
  case 0xC8: Instr_INY<X_type>(); break;

  case 0xCA: Instr_DEX<X_type>(); break;
  case 0x88: Instr_DEY<X_type>(); break;

  //
  // Branch Instructions
  //
  case 0x90: Instr_Bxx(!(P & C_FLAG)); break; // BCC
  case 0xB0: Instr_Bxx( (P & C_FLAG)); break; // BCS
  case 0xF0: Instr_Bxx( (P & Z_FLAG)); break; // BEQ
  case 0x30: Instr_Bxx( (P & N_FLAG)); break; // BMI
  case 0xD0: Instr_Bxx(!(P & Z_FLAG)); break; // BNE
  case 0x10: Instr_Bxx(!(P & N_FLAG)); break; // BPL
  case 0x80: Instr_Bxx(     true    ); break; // BRA
  case 0x50: Instr_Bxx(!(P & V_FLAG)); break; // BVC
  case 0x70: Instr_Bxx( (P & V_FLAG)); break; // BVS
  case 0x82: Instr_BRL(); 	       break; // BRL

  //
  // Exchange/Transfer instructions
  //
  case 0xAA: Instr_TAX<X_type>(); break;	// TAX
  case 0xA8: Instr_TAY<X_type>(); break;	// TAY
  case 0x5B: Instr_TCD(); break;	// TCD
  case 0x1B: Instr_TCS(); break;	// TCS
  case 0x7B: Instr_TDC(); break;	// TDC
  case 0x3B: Instr_TSC(); break;	// TSC
  case 0xBA: Instr_TSX<X_type>(); break;	// TSX
  case 0x8A: Instr_TXA<M_type>(); break;	// TXA
  case 0x9A: Instr_TXS(); break;	// TXS
  case 0x9B: Instr_TXY<X_type>(); break;	// TXY
  case 0x98: Instr_TYA<M_type>(); break;	// TYA
  case 0xBB: Instr_TYX<X_type>(); break;	// TYX
  case 0xEB: Instr_XBA(); break;	// XBA
  case 0xFB: Instr_XCE(); break;	// XCE

  //
  // Simple flag setting and clearing instructions.
  //
  case 0x18: Instr_CLx<C_FLAG>(); break;	// CLC
  case 0xD8: Instr_CLx<D_FLAG>(); break;	// CLD
  case 0x58: Instr_CLx<I_FLAG>(); break;	// CLI
  case 0xB8: Instr_CLx<V_FLAG>(); break;	// CLV

  case 0x38: Instr_SEx<C_FLAG>(); break;	// SEC
  case 0xF8: Instr_SEx<D_FLAG>(); break;	// SED
  case 0x78: Instr_SEx<I_FLAG>(); break;	// SEI

  case 0xC2: Instr_REP(); break;	// REP (Reset Status Bits)
  case 0xE2: Instr_SEP(); break;	// SEP (Set Processor Status Bits)
 }
}

void Core65816::Power(void)
{
 E = true;
 D = 0;
 DBRSL16 = 0;
 PC = 0;
 PBR = 0;
 S = 0;
 P = 0;
 X = 0;
 Y = 0;
 C = 0;
}

void Core65816::Reset(void)
{
 E = true; // Oh Tetris Attack, you're so crazy~
 D = 0x0000;
 DBRSL16 = 0x00 << 16;
 PBR = 0x00;
 S = 0x01FD;
 P = M_FLAG | X_FLAG | I_FLAG;

 PC = VecRead(0xFFFC);
 BranchOccurred();
}

void Core65816::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(PC),
  SFVAR(PBR),
  SFVAR(DBRSL16),
  SFVAR(S),
  SFVAR(D),
  SFVAR(C),
  SFVAR(X),
  SFVAR(Y),
  SFVAR(P),
  SFVAR(E),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);
};
//
//
//
uint32 Core65816::GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_PCPBR:
	ret = PCPBR;
	break;

  case GSREG_DBR:
	ret = DBRSL16 >> 16;
	break;

  case GSREG_S:
	ret = S;
	break;

  case GSREG_D:
	ret = D;
	break;

  case GSREG_A:
	ret = C;
	break;

  case GSREG_X:
	ret = X;
	break;

  case GSREG_Y:
	ret = Y;
	break;

  case GSREG_P:
	ret = P;
	break;

  case GSREG_E:
	ret = E;
	break;
 }

 return ret;
}

void Core65816::SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  case GSREG_PCPBR:
	PCPBR = value & 0xFFFFFF;
	break;

  case GSREG_DBR:
	DBRSL16 = (value & 0xFF) << 16;
	break;

  case GSREG_S:
	S = value;
	break;

  case GSREG_D:
	D = value;
	break;

  case GSREG_A:
	C = value;
	break;

  case GSREG_X:
	X = value;
	if(P & X_FLAG)
	{
	 X = (uint8)X;
	}
	break;

  case GSREG_Y:
	Y = value;
	if(P & X_FLAG)
	{
	 Y = (uint8)Y;
	}
	break;

  case GSREG_P:
	P = value;
	if(P & X_FLAG)
	{
	 X = (uint8)X;
	 Y = (uint8)Y;
	}
	break;

  case GSREG_E:
	//TODO E = value;
	break;
 }
}

