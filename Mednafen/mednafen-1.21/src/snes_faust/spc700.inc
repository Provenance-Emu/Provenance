/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* spc700.inc:
**  Copyright (C) 2015-2017 Mednafen Team
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

class SPC700 final
{
 public:

 SPC700() MDFN_COLD;
 ~SPC700() MDFN_COLD;

 void Reset(bool powering_up) MDFN_COLD;

 // count should be > 0.
 void Run(int32 count);

 void StateAction(StateMem* sm, const unsigned load, const bool data_only);

 //
 // GetRegister() and SetRegister() may not be called while in/under Run()
 //
 enum
 {
  GSREG_PC = 0,
  GSREG_A,
  GSREG_X,
  GSREG_Y,

  GSREG_PSW,
  GSREG_SP
 };
 INLINE unsigned GetRegister(unsigned which)
 {
  switch(which)
  {
   case GSREG_PC: return PC;
   case GSREG_A: return A;
   case GSREG_X: return X;
   case GSREG_Y: return Y;

   case GSREG_PSW: return PSW;
   case GSREG_SP: return SP;
  }
	return 0;
 }

 INLINE void SetRegister(unsigned which, unsigned value)
 {
  switch(which)
  {
   case GSREG_PC: PC = value; break;
   case GSREG_A: A = value; break;
   case GSREG_X: X = value; break;
   case GSREG_Y: Y = value; break;

   case GSREG_PSW: PSW = value; break;
   case GSREG_SP: SP = value; break;
  }
 }

 private:

 uint16 PC;
 uint8 PSW;
 uint8 A, X, Y;
 uint8 SP;
 uint8 Halted;

 int32 opcode_saver;
 int32 cycle_counter;

 enum { N_FLAG = 0x80 };
 enum { V_FLAG = 0x40 };
 enum { P_FLAG = 0x20 };
 enum { B_FLAG = 0x10 };
 enum { H_FLAG = 0x08 };
 enum { I_FLAG = 0x04 };
 enum { Z_FLAG = 0x02 };
 enum { C_FLAG = 0x01 };

 uint8 ReadMem(uint16);
 void WriteMem(uint16, uint8);
 uint8 ReadAtPC(void);
 void IO(void);

 void RunReal(void);


 //
 //
 //
 uint8 ReadDP(uint8 addr);
 void WriteDP(uint8 addr, uint8 val);

 void Push(uint8 val);
 uint8 Pop(void);

 void SetZN(uint8 val);
 void SetZN16(uint16 val);
 //
 //
 //
 uint8 GetEAD_Dir(void);
 uint8 GetEAD_DirIdx(const uint8 index);

 uint16 GetEA_IndirIdx(void);
 uint16 GetEA_IdxIndir(void);

 uint16 GetEA_Abs(void);
 uint16 GetEA_AbsIdx(const uint8 index); 
 //
 //
 //
 typedef void (SPC700::*gen_op)(uint8* dest, const uint8 src);

 void Op_ADC(uint8* dest, const uint8 src);
 void Op_AND(uint8* dest, const uint8 src);
 void Op_CMP(uint8* dest, const uint8 src);
 void Op_EOR(uint8* dest, const uint8 src);
 void Op_MOV(uint8* dest, const uint8 src);
 void Op_OR(uint8* dest, const uint8 src);
 void Op_SBC(uint8* dest, const uint8 src);

 void Instr_Indir_Indir(gen_op op);

 void Instr_IndirPI_A(gen_op op);
 void Instr_Indir_A  (gen_op op);

 void Instr_IndirIdx_A(gen_op op);
 void Instr_IdxIndir_A(gen_op op);

 void Instr_A_Indir  (gen_op op);
 void Instr_A_IndirPI(gen_op op);

 void Instr_A_IndirIdx (gen_op op);
 void Instr_A_IdxIndir (gen_op op);

 void Instr_Reg_Abs   (uint8* dest, gen_op op);
 void Instr_Reg_AbsIdx(uint8* dest, const uint8 index, gen_op op);

 void Instr_Reg_Imm   (uint8* dest, gen_op op);
 void Instr_Reg_Reg   (uint8* dest, const uint8 src, gen_op op);
 void Instr_Reg_Dir   (uint8* dest, gen_op op);
 void Instr_Reg_DirIdx(uint8* dest, const uint8 index, gen_op op);

 void Instr_Dir_Dir(gen_op const op);

 void Instr_DirIdx_Reg(const uint8 index, const uint8 src, gen_op op);

 void Instr_Dir_Imm(gen_op op);
 void Instr_Dir_Reg(const uint8 src, gen_op op);

 void Instr_AbsIdx_A(const uint8 index, gen_op op);

 void Instr_Abs_Reg(const uint8 src, gen_op op);
 //
 //
 //
 typedef void (SPC700::*gen_sarg_op)(uint8* arg);

 void Op_ASL(uint8* arg);
 void Op_LSR(uint8* arg);
 void Op_ROL(uint8* arg);
 void Op_ROR(uint8* arg);

 void Op_DEC(uint8* arg);
 void Op_INC(uint8* arg);

 template<unsigned wb> void Op_CLR1(uint8* arg);
 template<unsigned wb> void Op_SET1(uint8* arg);

 void Op_TCLR1(uint8* arg);
 void Op_TSET1(uint8* arg);

 void Instr_Reg(uint8* arg, gen_sarg_op op);
 void Instr_Dir(gen_sarg_op op);
 void Instr_DirIdx(gen_sarg_op op);
 template<bool dummy_read = false> void Instr_Abs(gen_sarg_op op);

 //
 //
 //
 typedef void (SPC700::*mb_op)(bool bv);

 void Op_AND1(bool bv);
 void Op_EOR1(bool bv);
 void Op_MOV1(bool bv);
 void Op_OR1(bool bv);

 uint16 GetEA_MB(unsigned* wb);

 template<bool bwn, bool dummy_io = false> void Instr_C_MB(mb_op op);

 void Instr_MB_C_MOV1(void);
 void Instr_MB_NOT1(void);
 //
 //
 //
 typedef void (SPC700::*word_op)(uint16* dest, const uint16 src);

 void Op_ADDW(uint16* dest, const uint16 src);
 void Op_CMPW(uint16* dest, const uint16 src);
 void Op_MOVW(uint16* dest, const uint16 src);
 void Op_SUBW(uint16* dest, const uint16 src);

 void Instr_YA_Dir(word_op op);
 void Instr_Dir_YA_MOVW(void);

 template<int delta> void Instr_DECWINCW(void);
 //
 //
 //
 void Instr_DirIdx_Rel_CBNE(void);
 void Instr_Dir_Rel_CBNE(void);
 void Instr_Y_Rel_DBNZ(void);
 void Instr_Dir_Rel_DBNZ(void);
 //
 //
 //
 void Instr_Bxx(bool cond);
 template<unsigned wb, bool tv> void Instr_BBx(void);

 void Instr_BRK(void);

 void Instr_JMP(void);
 void Instr_JMPII(void);

 void Instr_CALL(void);
 void Instr_PCALL(void);
 template<unsigned which> void Instr_TCALL(void);

 void Instr_RET(void);
 void Instr_RETI(void);

 void Instr_Pop(uint8* reg);
 void Instr_Push(const uint8* reg);
 //
 //
 //
 void Instr_NOP(void);
 void Instr_NOTC(void);

 template<unsigned mask> void Instr_CLRx(void);
 template<unsigned mask> void Instr_SETx(void);
 void Instr_EI(void);
 void Instr_DI(void);

 void Instr_XCN(void);

 void Instr_DAA(void);
 void Instr_DAS(void);

 void Instr_DIV(void);
 void Instr_MUL(void);

 void Instr_SLEEP(void) MDFN_COLD;
 void Instr_STOP(void) MDFN_COLD;
};

static void (* MDFN_FASTCALL *SPC700_WriteMap[256])(uint16, uint8);
static uint8 (* MDFN_FASTCALL *SPC700_ReadMap[256])(uint16);
static void (*SPC700_IOHandler)(void);

//static uint8 bazoom;

INLINE uint8 SPC700::ReadMem(uint16 addr)
{
 //if(addr >= 0xF4 && addr <= 0xF7)
 // fprintf(stderr, "%02x\n", bazoom);

 cycle_counter--;
 return SPC700_ReadMap[addr >> 8][(uint8)addr](addr);
}

INLINE void SPC700::WriteMem(uint16 addr, uint8 value)
{
 cycle_counter--;
 SPC700_WriteMap[addr >> 8][(uint8)addr](addr, value);
}

INLINE uint8 SPC700::ReadAtPC(void)
{
 cycle_counter--;
 return SPC700_ReadMap[PC >> 8][(uint8)PC](PC);
}

INLINE void SPC700::IO(void)
{
 cycle_counter--;
 SPC700_IOHandler();
}

//
//
//

INLINE uint8 SPC700::ReadDP(uint8 addr)
{
 return ReadMem(((PSW & P_FLAG) << 3) | addr);
}

INLINE void SPC700::WriteDP(uint8 addr, uint8 val)
{
 WriteMem(((PSW & P_FLAG) << 3) | addr, val);
}

INLINE void SPC700::Push(uint8 val)
{
 WriteMem((0x01 << 8) | SP, val);
 SP--;
}

INLINE uint8 SPC700::Pop(void)
{
 SP++;
 return ReadMem((0x01 << 8) | SP);
}

INLINE void SPC700::SetZN(uint8 val)
{
 PSW &= ~(Z_FLAG | N_FLAG);
 PSW |= val & N_FLAG;
 PSW |= ((val - 1) >> 8) & Z_FLAG;
}

INLINE void SPC700::SetZN16(uint16 val)
{
 PSW &= ~(Z_FLAG | N_FLAG);
 PSW |= (val >> 8) & N_FLAG;
 PSW |= ((val - 1) >> 16) & Z_FLAG;
}

//
//
//

INLINE uint8 SPC700::GetEAD_Dir(void)
{
 uint8 d;

 d = ReadAtPC();
 PC++;

 return d;
}

INLINE uint8 SPC700::GetEAD_DirIdx(const uint8 index)
{
 uint8 d;

 d = ReadAtPC();
 PC++;

 d += index;
 IO();

 return d;
}

INLINE uint16 SPC700::GetEA_IndirIdx(void)
{
 uint8 ead = GetEAD_Dir();
 uint16 ea;

 ea = ReadDP(ead);
 ead++;
 ea |= ReadDP(ead) << 8;

 ea += Y;
 IO();

 return ea;
}

INLINE uint16 SPC700::GetEA_IdxIndir(void)
{
 uint8 ead = GetEAD_Dir();
 uint16 ea;

 ead += X;
 IO();

 ea = ReadDP(ead);
 ead++;
 ea |= ReadDP(ead) << 8;

 return ea;
}


INLINE uint16 SPC700::GetEA_Abs(void)
{
 uint16 ea;

 ea = ReadAtPC();
 PC++;

 ea |= ReadAtPC() << 8;
 PC++;

 return ea;
}

INLINE uint16 SPC700::GetEA_AbsIdx(uint8 index)
{
 uint16 ea = GetEA_Abs();

 ea += index;
 IO();

 return ea;
}

//
//
//
INLINE void SPC700::Op_ADC(uint8* dest, const uint8 src)
{
 unsigned tmp = *dest + src + (PSW & C_FLAG);

 PSW &= ~(C_FLAG | V_FLAG | H_FLAG);
 PSW |= (tmp >> 8) & C_FLAG;
 PSW |= ((~(*dest ^ src) & (*dest ^ tmp)) >> 1) & V_FLAG;
 PSW |= (((*dest ^ src) ^ tmp) >> 1) & H_FLAG;

 *dest = tmp;
 SetZN(*dest);
}

INLINE void SPC700::Op_AND(uint8* dest, const uint8 src)
{
 *dest &= src;

 SetZN(*dest);
}

INLINE void SPC700::Op_CMP(uint8* dest, const uint8 src)
{
 unsigned tmp = *dest - src;

 PSW &= ~C_FLAG;
 PSW |= (~tmp >> 8) & C_FLAG;

 SetZN((uint8)tmp);
}

INLINE void SPC700::Op_EOR(uint8* dest, const uint8 src)
{
 *dest ^= src;

 SetZN(*dest);
}

INLINE void SPC700::Op_MOV(uint8* dest, const uint8 src)
{
 *dest = src;

 if(dest == &A || dest == &X || dest == &Y)
  SetZN(*dest);
}

INLINE void SPC700::Op_OR(uint8* dest, const uint8 src)
{
 *dest |= src;

 SetZN(*dest);
}

INLINE void SPC700::Op_SBC(uint8* dest, const uint8 src)
{
 unsigned tmp = *dest - src - (~PSW & C_FLAG);

 PSW &= ~(C_FLAG | V_FLAG | H_FLAG);
 PSW |= (~tmp >> 8) & C_FLAG;
 PSW |= (((*dest ^ src) & (*dest ^ tmp)) >> 1) & V_FLAG;
 PSW |= (~((*dest ^ src) ^ tmp) >> 1) & H_FLAG;

 *dest = tmp;
 SetZN(*dest);
}

//
//
INLINE void SPC700::Instr_Indir_Indir(gen_op op)
{
 IO();

 const uint8 src = ReadDP(Y);
 uint8 tmp = ReadDP(X);

 (this->*op)(&tmp, src);

 if(op == &SPC700::Op_CMP)
  IO();
 else
  WriteDP(X, tmp);
}

INLINE void SPC700::Instr_A_IndirPI(gen_op op)
{
 IO();

 const uint8 src = ReadDP(X);
 (this->*op)(&A, src);

 IO();
 X++;
}

INLINE void SPC700::Instr_IndirPI_A(gen_op op)
{
 // No RMW.
 uint8 tmp;

 IO();
 IO();

 (this->*op)(&tmp, A);
 WriteDP(X, tmp);
 X++;
}

INLINE void SPC700::Instr_A_Indir(gen_op op)
{
 IO();

 const uint8 src = ReadDP(X);
 (this->*op)(&A, src);
}

INLINE void SPC700::Instr_Indir_A(gen_op op)
{
 IO();

 uint8 tmp = ReadDP(X);
 (this->*op)(&tmp, A);
 WriteDP(X, tmp);
}
//
//

INLINE void SPC700::Instr_IndirIdx_A(gen_op op)
{
 const uint16 ea = GetEA_IndirIdx();
 uint8 tmp;

 tmp = ReadMem(ea);
 (this->*op)(&tmp, A);
 WriteMem(ea, tmp);
}

INLINE void SPC700::Instr_IdxIndir_A(gen_op op)
{
 const uint16 ea = GetEA_IdxIndir();
 uint8 tmp;

 tmp = ReadMem(ea);
 (this->*op)(&tmp, A);
 WriteMem(ea, tmp);
}

INLINE void SPC700::Instr_A_IndirIdx(gen_op op)
{
 const uint16 ea = GetEA_IndirIdx();
 const uint8 src = ReadMem(ea);

 (this->*op)(&A, src);
}

INLINE void SPC700::Instr_A_IdxIndir(gen_op op)
{
 const uint16 ea = GetEA_IdxIndir();
 const uint8 src = ReadMem(ea);

 (this->*op)(&A, src);
}

INLINE void SPC700::Instr_Reg_Abs(uint8* dest, gen_op op)
{
 const uint16 ea = GetEA_Abs();
 const uint8 src = ReadMem(ea);

 (this->*op)(dest, src);
}

INLINE void SPC700::Instr_Reg_AbsIdx(uint8* dest, const uint8 index, gen_op op)
{
 const uint16 ea = GetEA_AbsIdx(index);
 const uint8 src = ReadMem(ea);

 (this->*op)(dest, src);
}

INLINE void SPC700::Instr_Reg_Imm(uint8* dest, gen_op op)
{
 const uint8 src = ReadAtPC();
 PC++;

 (this->*op)(dest, src);
}

INLINE void SPC700::Instr_Reg_Reg(uint8* dest, const uint8 src, gen_op op)
{
 IO();
 (this->*op)(dest, src);
}

INLINE void SPC700::Instr_Reg_Dir(uint8* dest, gen_op op)
{
 const uint8 ead = GetEAD_Dir();
 const uint8 src = ReadDP(ead);

 (this->*op)(dest, src);
}

INLINE void SPC700::Instr_Reg_DirIdx(uint8* dest, const uint8 index, gen_op op)
{
 const uint8 ead = GetEAD_DirIdx(index);
 const uint8 src = ReadDP(ead);

 (this->*op)(dest, src);
}

INLINE void SPC700::Instr_Dir_Dir(gen_op const op)
{
 uint8 ead;
 uint8 tmp;

 ead = GetEAD_Dir();
 const uint8 src = ReadDP(ead);

 ead = GetEAD_Dir();

 if(op != &SPC700::Op_MOV)
  tmp = ReadDP(ead);

 (this->*op)(&tmp, src);

 if(op == &SPC700::Op_CMP)
  IO();
 else
  WriteDP(ead, tmp);
}

INLINE void SPC700::Instr_DirIdx_Reg(const uint8 index, const uint8 src, gen_op op)
{
 const uint8 ead = GetEAD_DirIdx(index);
 uint8 tmp;

 tmp = ReadDP(ead);
 (this->*op)(&tmp, src);
 WriteDP(ead, tmp);
}

INLINE void SPC700::Instr_Dir_Imm(gen_op op)
{
 const uint8 src = ReadAtPC();
 PC++;

 const uint8 ead = GetEAD_Dir();
 uint8 tmp;

 tmp = ReadDP(ead);
 (this->*op)(&tmp, src);

 if(op == &SPC700::Op_CMP)
  IO();
 else
  WriteDP(ead, tmp);
}

INLINE void SPC700::Instr_Dir_Reg(const uint8 src, gen_op op)
{
 uint8 ead = GetEAD_Dir();
 uint8 tmp;

 tmp = ReadDP(ead);
 (this->*op)(&tmp, src);
 WriteDP(ead, tmp);
}

INLINE void SPC700::Instr_AbsIdx_A(const uint8 index, gen_op op)
{
 uint16 ea = GetEA_AbsIdx(index);
 uint8 tmp;

 tmp = ReadMem(ea);
 (this->*op)(&tmp, A);
 WriteMem(ea, tmp);
}

INLINE void SPC700::Instr_Abs_Reg(const uint8 src, gen_op op)
{
 uint16 ea = GetEA_Abs();
 uint8 tmp;

 tmp = ReadMem(ea);
 (this->*op)(&tmp, src);
 WriteMem(ea, tmp);
}
//
//
//
INLINE void SPC700::Op_ASL(uint8* arg)
{
 PSW &= ~C_FLAG;
 PSW |= *arg >> 7;

 *arg <<= 1;

 SetZN(*arg);
}

INLINE void SPC700::Op_LSR(uint8* arg)
{
 PSW &= ~C_FLAG;
 PSW |= *arg & C_FLAG;

 *arg >>= 1;

 SetZN(*arg);
}

INLINE void SPC700::Op_ROL(uint8* arg)
{
 uint8 tmp = (*arg << 1) | (PSW & C_FLAG);

 PSW &= ~C_FLAG;
 PSW |= *arg >> 7;

 *arg = tmp;

 SetZN(*arg);
}

INLINE void SPC700::Op_ROR(uint8* arg)
{
 uint8 tmp = (*arg >> 1) | (PSW << 7);

 PSW &= ~C_FLAG;
 PSW |= *arg & C_FLAG;

 *arg = tmp;

 SetZN(*arg);
}

INLINE void SPC700::Op_DEC(uint8* arg)
{
 *arg -= 1;

 SetZN(*arg);
}

INLINE void SPC700::Op_INC(uint8* arg)
{
 *arg += 1;

 SetZN(*arg);
}


template<unsigned wb>
INLINE void SPC700::Op_CLR1(uint8* arg)
{
 *arg &= ~(1U << wb);
}

template<unsigned wb>
INLINE void SPC700::Op_SET1(uint8* arg)
{
 *arg |= 1U << wb;
}

INLINE void SPC700::Op_TCLR1(uint8* arg)
{
 SetZN(A - *arg);
 *arg &= ~A;
}

INLINE void SPC700::Op_TSET1(uint8* arg)
{
 SetZN(A - *arg);
 *arg |= A;
}



INLINE void SPC700::Instr_Reg(uint8* arg, gen_sarg_op op)
{
 (this->*op)(arg);
 IO();
}

INLINE void SPC700::Instr_Dir(gen_sarg_op op)
{
 uint8 ead = GetEAD_Dir();
 uint8 tmp;

 tmp = ReadDP(ead);
 (this->*op)(&tmp);
 WriteDP(ead, tmp);
}

INLINE void SPC700::Instr_DirIdx(gen_sarg_op op)
{
 uint8 ead = GetEAD_DirIdx(X);
 uint8 tmp;

 tmp = ReadDP(ead);
 (this->*op)(&tmp);
 WriteDP(ead, tmp);
}

template<bool dummy_read>
INLINE void SPC700::Instr_Abs(gen_sarg_op op)
{
 uint16 ea = GetEA_Abs();
 uint8 tmp;

 tmp = ReadMem(ea);

 if(dummy_read)
  ReadMem(ea);	// Discarded dummy read?

 (this->*op)(&tmp);
 WriteMem(ea, tmp);
}
//
//
//

INLINE void SPC700::Op_AND1(bool bv)
{
 PSW &= 0xFE | bv;
}

INLINE void SPC700::Op_EOR1(bool bv)
{
 PSW ^= bv;
}

INLINE void SPC700::Op_MOV1(bool bv)
{
 PSW &= ~C_FLAG;
 PSW |= bv;
}

INLINE void SPC700::Op_OR1(bool bv)
{
 PSW |= bv;
}

INLINE uint16 SPC700::GetEA_MB(unsigned* wb)
{
 uint16 ea;

 ea = ReadAtPC();
 PC++;

 ea |= ReadAtPC() << 8;
 PC++;

 *wb = ea >> 13;
 ea &= 0x1FFF;

 return ea;
}

template<bool bwn, bool dummy_io>
INLINE void SPC700::Instr_C_MB(mb_op op)
{
 unsigned wb;
 const uint16 ea = GetEA_MB(&wb);
 uint8 data = ReadMem(ea);

 if(bwn)
  data = ~data;

 (this->*op)((data >> wb) & 1);

 if(dummy_io)
  IO();
}

INLINE void SPC700::Instr_MB_C_MOV1(void)
{
 unsigned wb;
 const uint16 ea = GetEA_MB(&wb);
 uint8 data = ReadMem(ea);

 data &= ~(1U << wb);
 data |= (PSW & C_FLAG) << wb;

 IO();

 WriteMem(ea, data);
}

INLINE void SPC700::Instr_MB_NOT1(void)
{
 unsigned wb;
 const uint16 ea = GetEA_MB(&wb);
 uint8 data = ReadMem(ea);

 data ^= 1U << wb;

 WriteMem(ea, data);
}
//
//
//

INLINE void SPC700::Op_ADDW(uint16* dest, const uint16 src)
{
 uint32 tmp = *dest + src;

 PSW &= ~(C_FLAG | V_FLAG | H_FLAG);
 PSW |= (tmp >> 16) & C_FLAG;
 PSW |= ((~(*dest ^ src) & (*dest ^ tmp)) >> 9) & V_FLAG;
 PSW |= (((*dest ^ src) ^ tmp) >> 9) & H_FLAG;

 *dest = tmp;
 SetZN16(*dest);
}

INLINE void SPC700::Op_CMPW(uint16* dest, const uint16 src)
{
 uint32 tmp = *dest - src;

 PSW &= ~C_FLAG;
 PSW |= (~tmp >> 16) & C_FLAG;

 SetZN16(tmp);
}

INLINE void SPC700::Op_MOVW(uint16* dest, const uint16 src)
{
 *dest = src;
 SetZN16(*dest);
}

INLINE void SPC700::Op_SUBW(uint16* dest, const uint16 src)
{
 uint32 tmp = *dest - src;

 PSW &= ~(C_FLAG | V_FLAG | H_FLAG);
 PSW |= (~tmp >> 16) & C_FLAG;
 PSW |= (((*dest ^ src) & (*dest ^ tmp)) >> 9) & V_FLAG;
 PSW |= (~((*dest ^ src) ^ tmp) >> 9) & H_FLAG;

 *dest = tmp;
 SetZN16(*dest);
}

INLINE void SPC700::Instr_YA_Dir(word_op op)
{
 uint8 ead = GetEAD_Dir();
 uint16 src;
 uint16 ya;

 src = ReadDP(ead);
 ead++;

 if(op != &SPC700::Op_CMPW)
  IO();

 src |= ReadDP(ead) << 8;

 ya = (Y << 8) | A;
 (this->*op)(&ya, src);

 if(op != &SPC700::Op_CMPW)
 {
  A = ya;
  Y = ya >> 8;
 }
}

INLINE void SPC700::Instr_Dir_YA_MOVW(void)
{
 uint8 ead = GetEAD_Dir();

 ReadDP(ead);
 WriteDP(ead, A);
 ead++;
 WriteDP(ead, Y); 
}

template<int delta>
INLINE void SPC700::Instr_DECWINCW(void)
{
 uint8 ead = GetEAD_Dir();
 uint16 tmp;

 tmp = ReadDP(ead);
 tmp += delta;
 WriteDP(ead, tmp);
 ead++;

 tmp += ReadDP(ead) << 8;
 WriteDP(ead, tmp >> 8);

 SetZN16(tmp);
}
//
//
//

INLINE void SPC700::Instr_DirIdx_Rel_CBNE(void)
{
 uint8 ead = GetEAD_DirIdx(X);
 uint8 tmp = ReadDP(ead);
 int8 r;

 r = ReadAtPC();
 PC++;

 IO();

 if(A != tmp)
 {
  IO();
  IO();

  PC += r;
 }
}

INLINE void SPC700::Instr_Dir_Rel_CBNE(void)
{
 uint8 ead = GetEAD_Dir();
 uint8 tmp = ReadDP(ead);
 int8 r;

 r = ReadAtPC();
 PC++;

 IO();

 if(A != tmp)
 {
  IO();
  IO();

  PC += r;
 }
}

INLINE void SPC700::Instr_Y_Rel_DBNZ(void)
{
 int8 r;

 r = ReadAtPC();
 PC++;

 IO();
 IO();

 Y--;

 if(Y)
 {
  IO();
  IO();

  PC += r;
 }
}

INLINE void SPC700::Instr_Dir_Rel_DBNZ(void)
{
 const uint8 ead = GetEAD_Dir();
 uint8 tmp;
 int8 r;

 tmp = ReadDP(ead);
 tmp--;
 WriteDP(ead, tmp);

 r = ReadAtPC();
 PC++;

 if(tmp)
 {
  IO();
  IO();

  PC += r;
 }
}

//
//
//
INLINE void SPC700::Instr_Bxx(bool cond)
{
 int8 r;

 r = ReadAtPC();
 PC++;

 if(cond)
 {
  IO();
  IO();

  PC += r; 
 }
}

template<unsigned wb, bool tv>
INLINE void SPC700::Instr_BBx(void)
{
 int8 r;
 uint8 d;
 uint8 tmp;

 d = ReadAtPC();
 PC++;

 tmp = ReadDP(d);

 r = ReadAtPC();
 PC++;

 IO();

 if((tmp & (1U << wb)) == (tv << wb))
 {
  IO();
  IO();

  PC += r;
 }
}


INLINE void SPC700::Instr_BRK(void)
{
 Push(PC >> 8);
 Push(PC >> 0);
 Push(PSW);

 PC = ReadMem(0xFFDE);
 PC |= ReadMem(0xFFDF) << 8;
 PSW = (PSW | B_FLAG) & ~I_FLAG;

 IO();
 IO();
}

INLINE void SPC700::Instr_JMP(void)
{
 uint16 new_PC;

 new_PC = ReadAtPC();
 PC++;

 new_PC |= ReadAtPC() << 8;
 PC++;

 PC = new_PC;
}

INLINE void SPC700::Instr_JMPII(void)
{
 uint16 addr;

 addr = ReadAtPC();
 PC++;

 addr |= ReadAtPC() << 8;
 PC++;

 IO();
 addr += X;

 PC = ReadMem(addr);
 addr++;
 PC |= ReadMem(addr) << 8;
}

INLINE void SPC700::Instr_CALL(void)
{
 uint16 new_PC;

 new_PC = ReadAtPC();
 PC++;

 new_PC |= ReadAtPC() << 8;
 PC++;

 IO();

 Push(PC >> 8);
 Push(PC >> 0);

 IO();
 IO();
 PC = new_PC;
}

INLINE void SPC700::Instr_PCALL(void)
{
 uint16 new_PC = 0xFF00;

 new_PC |= ReadAtPC();
 PC++;

 IO();
 IO();

 Push(PC >> 8);
 Push(PC >> 0);

 PC = new_PC;
}

template<unsigned which>
INLINE void SPC700::Instr_TCALL(void)
{
 unsigned vec = 0xFFDE - (which * 2);

 Push(PC >> 8);
 Push(PC >> 0);

 IO();

 PC = ReadMem(vec);
 PC |= ReadMem(vec + 1) << 8;

 IO();
 IO();
}

INLINE void SPC700::Instr_RET(void)
{
 PC = Pop();
 PC |= Pop() << 8;
 IO();
 IO();
}

INLINE void SPC700::Instr_RETI(void)
{
 PSW = Pop();
 PC = Pop();
 PC |= Pop() << 8;
 IO();
 IO();
}

INLINE void SPC700::Instr_Pop(uint8* reg)
{
 IO();
 *reg = Pop();
 IO();
}

INLINE void SPC700::Instr_Push(const uint8* reg)
{
 IO();
 Push(*reg);
 IO();
}

//
//
//
INLINE void SPC700::Instr_XCN(void)
{
 A = (A >> 4) | (A << 4);
 SetZN(A);

 IO();
 IO();
 IO();
 IO();
}

INLINE void SPC700::Instr_DAA(void)
{
 if(A > 0x99 || (PSW & C_FLAG))
 {
  A += 0x60;
  PSW |= C_FLAG;
 }

 if((A & 0x0F) > 0x09 || (PSW & H_FLAG))
  A += 0x06;

 SetZN(A);

 IO();
 IO();
}

INLINE void SPC700::Instr_DAS(void)
{
 if(A > 0x99 || !(PSW & C_FLAG))
 {
  A -= 0x60;
  PSW &= ~C_FLAG;
 }

 if((A & 0x0F) > 0x09 || !(PSW & H_FLAG))
  A -= 0x06;

 SetZN(A);

 IO();
 IO();
}

INLINE void SPC700::Instr_DIV(void)
{
 // A = YA / X, Y = YA % X
 unsigned divisor_adj = X << 24;
 unsigned result = ((Y << 8) | A) << 15;

 PSW &= ~H_FLAG;
 PSW |= (~((Y & 0xF) - (X & 0xF)) >> 1) & H_FLAG;

 for(unsigned i = 9; i; i--)
 {
  bool c = result >> 31;

  result <<= 1;

  if((result >= divisor_adj) ^ c)
   result -= divisor_adj - 1;
 }

 A = result;
 Y = result >> 24;

 SetZN(A);

 PSW &= ~V_FLAG;
 PSW |= (result >> 2) & V_FLAG;

 for(unsigned i = 11; i; i--)
  IO();
}

INLINE void SPC700::Instr_MUL(void)
{
 uint16 result = Y * A;

 A = result;
 Y = result >> 8;

 SetZN(Y);

 for(unsigned i = 8; i; i--)
  IO();
}

INLINE void SPC700::Instr_NOP(void)
{
 IO();
}

INLINE void SPC700::Instr_SLEEP(void)
{
 fprintf(stderr, "[SPC700] SLEEP\n");
 Halted = true;
}

INLINE void SPC700::Instr_STOP(void)
{
 fprintf(stderr, "[SPC700] STOP\n");
 Halted = true;
}

//
//
//
template<unsigned mask>
INLINE void SPC700::Instr_CLRx(void)
{
 IO();
 PSW &= ~mask;
}

template<unsigned mask>
INLINE void SPC700::Instr_SETx(void)
{
 IO();
 PSW |= mask;
}

INLINE void SPC700::Instr_NOTC(void)
{
 IO();
 PSW ^= C_FLAG;
 IO();
}

INLINE void SPC700::Instr_EI(void)
{
 IO();
 PSW |= I_FLAG;
 IO();
}

INLINE void SPC700::Instr_DI(void)
{
 IO();
 PSW &= ~I_FLAG;
 IO();
}

#if 0
static const uint8 CycleCheckTable[256] =
{
 0x02, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x06, 0x05, 0x04, 0x05, 0x04, 0x06, 0x08, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x05, 0x05, 0x06, 0x05, 0x02, 0x02, 0x04, 0x06, 
 0x02, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x06, 0x05, 0x04, 0x05, 0x04, 0x85, 0x04, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x05, 0x05, 0x06, 0x05, 0x02, 0x02, 0x03, 0x08, 
 0x02, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x06, 0x04, 0x04, 0x05, 0x04, 0x06, 0x06, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x05, 0x05, 0x04, 0x05, 0x02, 0x02, 0x04, 0x03, 
 0x02, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x06, 0x04, 0x04, 0x05, 0x04, 0x85, 0x05, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x05, 0x05, 0x05, 0x05, 0x02, 0x02, 0x03, 0x06, 
 0x02, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x06, 0x05, 0x04, 0x05, 0x02, 0x04, 0x05, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x05, 0x05, 0x05, 0x05, 0x02, 0x02, 0x0c, 0x05, 
 0x03, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x06, 0x04, 0x04, 0x05, 0x02, 0x04, 0x04, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x05, 0x05, 0x05, 0x05, 0x02, 0x02, 0x03, 0x04, 
 0x03, 0x08, 0x04, 0x85, 0x04, 0x05, 0x04, 0x07, 0x02, 0x05, 0x06, 0x04, 0x05, 0x02, 0x04, 0x09, 
 0x82, 0x08, 0x04, 0x85, 0x05, 0x06, 0x06, 0x07, 0x04, 0x05, 0x05, 0x05, 0x02, 0x02, 0x86, 0x03, 
 0x02, 0x08, 0x04, 0x85, 0x03, 0x04, 0x03, 0x06, 0x02, 0x04, 0x05, 0x03, 0x04, 0x03, 0x04, 0x00, 
 0x82, 0x08, 0x04, 0x85, 0x04, 0x05, 0x05, 0x06, 0x03, 0x04, 0x05, 0x04, 0x02, 0x02, 0x84, 0x00, 
};
#endif

static const uint8 CycleHackyTable_Init[256] =
{
 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x05, 0x04, 0x03, 0x04, 0x01, 0x05, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x04, 0x04, 0x05, 0x04, 0x01, 0x01, 0x03, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x05, 0x04, 0x03, 0x04, 0x01, 0x04, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x04, 0x04, 0x05, 0x04, 0x01, 0x01, 0x02, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x05, 0x03, 0x03, 0x04, 0x01, 0x05, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x04, 0x04, 0x03, 0x04, 0x01, 0x01, 0x03, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x05, 0x03, 0x03, 0x04, 0x01, 0x04, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x04, 0x04, 0x04, 0x04, 0x01, 0x01, 0x02, 0x01, 

 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x05, 0x04, 0x03, 0x04, 0x01, 0x01, 0x04, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x04, 0x04, 0x04, 0x04, 0x01, 0x01, 0x01, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x05, 0x03, 0x03, 0x04, 0x01, 0x01, 0x03, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x04, 0x04, 0x04, 0x04, 0x01, 0x01, 0x01, 0x03, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x03, 0x06,  0x01, 0x04, 0x05, 0x03, 0x04, 0x01, 0x01, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x04, 0x05, 0x05, 0x06,  0x03, 0x04, 0x04, 0x04, 0x01, 0x01, 0x05, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x02, 0x03, 0x02, 0x05,  0x01, 0x03, 0x04, 0x02, 0x03, 0x01, 0x01, 0x01, 
 0x01, 0x01, 0x03, 0x04, 0x03, 0x04, 0x04, 0x05,  0x02, 0x03, 0x04, 0x03, 0x01, 0x01, 0x01, 0x01, 
};
static uint8 CycleHackyTable[256];

INLINE void SPC700::RunReal(void)
{
 uint8 opcode;

 if(MDFN_UNLIKELY(Halted))
 {
  HaltedBalted:

  while(cycle_counter > 0)
   IO();

  return;
 }

 if(MDFN_UNLIKELY(opcode_saver >= 0))
 {
  opcode = opcode_saver;
  opcode_saver = -1;
  goto SkipOpcode;
 } 

 for(;;)
 {
  opcode = ReadAtPC();
  //bazoom = opcode;
  //fprintf(stderr, "Instr: %04x, %02x --- A=0x%02x, X=0x%02x, Y=0x%02x, PSW=0x%02x, SP=0x%02x\n", PC, opcode, A, X, Y, PSW, SP);
  PC++;

  SkipOpcode:;
  if(MDFN_UNLIKELY(cycle_counter < CycleHackyTable[opcode]))
  {
   opcode_saver = opcode;
   break;
  }

  switch(opcode)
  {
   case 0x00: Instr_NOP(); break;

   case 0x20: Instr_CLRx<P_FLAG>(); break;	// CLRP
   case 0x60: Instr_CLRx<C_FLAG>(); break;	// CLRC
   case 0xE0: Instr_CLRx<V_FLAG | H_FLAG>(); break; // CLRV

   case 0x40: Instr_SETx<P_FLAG>(); break;	// SETP
   case 0x80: Instr_SETx<C_FLAG>(); break;	// SETC

   case 0xED: Instr_NOTC(); break;

   case 0xA0: Instr_EI(); break;
   case 0xC0: Instr_DI(); break;

   case 0x2F: Instr_Bxx(     true      ); break;	// BRA
   case 0x10: Instr_Bxx(!(PSW & N_FLAG)); break;	// BPL
   case 0x30: Instr_Bxx( (PSW & N_FLAG)); break;	// BMI
   case 0x50: Instr_Bxx(!(PSW & V_FLAG)); break;	// BVC
   case 0x70: Instr_Bxx( (PSW & V_FLAG)); break;	// BVS
   case 0x90: Instr_Bxx(!(PSW & C_FLAG)); break;	// BCC
   case 0xB0: Instr_Bxx( (PSW & C_FLAG)); break;	// BCS
   case 0xD0: Instr_Bxx(!(PSW & Z_FLAG)); break;	// BNE
   case 0xF0: Instr_Bxx( (PSW & Z_FLAG)); break;	// BEQ

   // BBS
   case 0x03: Instr_BBx<0, true>(); break;
   case 0x23: Instr_BBx<1, true>(); break;
   case 0x43: Instr_BBx<2, true>(); break;
   case 0x63: Instr_BBx<3, true>(); break;
   case 0x83: Instr_BBx<4, true>(); break;
   case 0xA3: Instr_BBx<5, true>(); break;
   case 0xC3: Instr_BBx<6, true>(); break;
   case 0xE3: Instr_BBx<7, true>(); break;

   // BBC
   case 0x13: Instr_BBx<0, false>(); break;
   case 0x33: Instr_BBx<1, false>(); break;
   case 0x53: Instr_BBx<2, false>(); break;
   case 0x73: Instr_BBx<3, false>(); break;
   case 0x93: Instr_BBx<4, false>(); break;
   case 0xB3: Instr_BBx<5, false>(); break;
   case 0xD3: Instr_BBx<6, false>(); break;
   case 0xF3: Instr_BBx<7, false>(); break;

   case 0xDE: Instr_DirIdx_Rel_CBNE(); break;
   case 0x2E: Instr_Dir_Rel_CBNE(); break;

   case 0xFE: Instr_Y_Rel_DBNZ(); break;
   case 0x6E: Instr_Dir_Rel_DBNZ(); break;

   case 0x01: Instr_TCALL<0x0>(); break;
   case 0x11: Instr_TCALL<0x1>(); break;
   case 0x21: Instr_TCALL<0x2>(); break;
   case 0x31: Instr_TCALL<0x3>(); break;
   case 0x41: Instr_TCALL<0x4>(); break;
   case 0x51: Instr_TCALL<0x5>(); break;
   case 0x61: Instr_TCALL<0x6>(); break;
   case 0x71: Instr_TCALL<0x7>(); break;
   case 0x81: Instr_TCALL<0x8>(); break;
   case 0x91: Instr_TCALL<0x9>(); break;
   case 0xA1: Instr_TCALL<0xA>(); break;
   case 0xB1: Instr_TCALL<0xB>(); break;
   case 0xC1: Instr_TCALL<0xC>(); break;
   case 0xD1: Instr_TCALL<0xD>(); break;
   case 0xE1: Instr_TCALL<0xE>(); break;
   case 0xF1: Instr_TCALL<0xF>(); break;

   case 0x3F: Instr_CALL(); break;
   case 0x4F: Instr_PCALL(); break;

   case 0x6F: Instr_RET(); break;
   case 0x7F: Instr_RETI(); break;

   case 0x0F: Instr_BRK(); break;

   case 0x1F: Instr_JMPII(); break;
   case 0x5F: Instr_JMP(); break;


#define MATH_BLOCK(base, op)	\
   case (base + 0x19): Instr_Indir_Indir(&SPC700::Op_##op); 	break;	\
   case (base + 0x08): Instr_Reg_Imm    (&A, &SPC700::Op_##op); break;	\
   case (base + 0x06): Instr_A_Indir	(&SPC700::Op_##op); 	break;	\
   case (base + 0x17): Instr_A_IndirIdx	(&SPC700::Op_##op); 	break;	\
   case (base + 0x07): Instr_A_IdxIndir (&SPC700::Op_##op); 	break;	\
   case (base + 0x04): Instr_Reg_Dir	(&A, &SPC700::Op_##op); 	break;	\
   case (base + 0x14): Instr_Reg_DirIdx	(&A, X, &SPC700::Op_##op); 	break;	\
   case (base + 0x05): Instr_Reg_Abs	(&A, &SPC700::Op_##op); 	break;	\
   case (base + 0x15): Instr_Reg_AbsIdx	(&A, X, &SPC700::Op_##op); 	break;	\
   case (base + 0x16): Instr_Reg_AbsIdx	(&A, Y, &SPC700::Op_##op); 	break;	\
   case (base + 0x09): Instr_Dir_Dir	(&SPC700::Op_##op); 	break;	\
   case (base + 0x18): Instr_Dir_Imm	(&SPC700::Op_##op); 	break;

   MATH_BLOCK(0x00, OR)
   MATH_BLOCK(0x20, AND)
   MATH_BLOCK(0x40, EOR)
   MATH_BLOCK(0x60, CMP)
   MATH_BLOCK(0x80, ADC)
   MATH_BLOCK(0xA0, SBC)

   // CMP (extra)
   case 0xC8: Instr_Reg_Imm(&X, &SPC700::Op_CMP); break;
   case 0x3E: Instr_Reg_Dir(&X, &SPC700::Op_CMP); break;
   case 0x1E: Instr_Reg_Abs(&X, &SPC700::Op_CMP); break;

   case 0xAD: Instr_Reg_Imm(&Y, &SPC700::Op_CMP); break;
   case 0x7E: Instr_Reg_Dir(&Y, &SPC700::Op_CMP); break;
   case 0x5E: Instr_Reg_Abs(&Y, &SPC700::Op_CMP); break;


   //
   // MOV
   //
   case 0xAF: Instr_IndirPI_A(&SPC700::Op_MOV); break;
   case 0xC6: Instr_Indir_A  (&SPC700::Op_MOV);   break;

   case 0xD7: Instr_IndirIdx_A(&SPC700::Op_MOV); break;
   case 0xC7: Instr_IdxIndir_A(&SPC700::Op_MOV); break;

   case 0xE8: Instr_Reg_Imm  (&A, &SPC700::Op_MOV); break;
   case 0xE6: Instr_A_Indir  (&SPC700::Op_MOV);     break;
   case 0xBF: Instr_A_IndirPI(&SPC700::Op_MOV);     break;

   case 0xF7: Instr_A_IndirIdx (&SPC700::Op_MOV); break;
   case 0xE7: Instr_A_IdxIndir (&SPC700::Op_MOV); break;

   case 0x7D: Instr_Reg_Reg(&A, X, &SPC700::Op_MOV); break;
   case 0xDD: Instr_Reg_Reg(&A, Y, &SPC700::Op_MOV); break;

   case 0xE4: Instr_Reg_Dir   (&A, &SPC700::Op_MOV); 	break;
   case 0xF4: Instr_Reg_DirIdx(&A, X, &SPC700::Op_MOV); break;

   case 0xE5: Instr_Reg_Abs   (&A, &SPC700::Op_MOV);	break;
   case 0xF5: Instr_Reg_AbsIdx(&A, X, &SPC700::Op_MOV); break;
   case 0xF6: Instr_Reg_AbsIdx(&A, Y, &SPC700::Op_MOV); break;

   case 0xBD: Instr_Reg_Reg(&SP, X, &SPC700::Op_MOV); break;

   case 0xCD: Instr_Reg_Imm   (&X, &SPC700::Op_MOV); break;
   case 0x5D: Instr_Reg_Reg   (&X, A, &SPC700::Op_MOV); break;
   case 0x9D: Instr_Reg_Reg   (&X, SP, &SPC700::Op_MOV); break;
   case 0xF8: Instr_Reg_Dir   (&X, &SPC700::Op_MOV); break;
   case 0xF9: Instr_Reg_DirIdx(&X, Y, &SPC700::Op_MOV); break;
   case 0xE9: Instr_Reg_Abs   (&X, &SPC700::Op_MOV); break;

   case 0x8D: Instr_Reg_Imm   (&Y, &SPC700::Op_MOV); break;
   case 0xFD: Instr_Reg_Reg   (&Y, A, &SPC700::Op_MOV); break;
   case 0xEB: Instr_Reg_Dir   (&Y, &SPC700::Op_MOV); break;
   case 0xFB: Instr_Reg_DirIdx(&Y, X, &SPC700::Op_MOV); break;
   case 0xEC: Instr_Reg_Abs   (&Y, &SPC700::Op_MOV); break;

   case 0xFA: Instr_Dir_Dir(&SPC700::Op_MOV); break;

   case 0xD4: Instr_DirIdx_Reg(X, A, &SPC700::Op_MOV); break;
   case 0xDB: Instr_DirIdx_Reg(X, Y, &SPC700::Op_MOV); break;
   case 0xD9: Instr_DirIdx_Reg(Y, X, &SPC700::Op_MOV); break;

   case 0x8F: Instr_Dir_Imm(&SPC700::Op_MOV); break;
   case 0xC4: Instr_Dir_Reg(A, &SPC700::Op_MOV); break;
   case 0xD8: Instr_Dir_Reg(X, &SPC700::Op_MOV); break;
   case 0xCB: Instr_Dir_Reg(Y, &SPC700::Op_MOV); break;

   case 0xD5: Instr_AbsIdx_A(X, &SPC700::Op_MOV); break;
   case 0xD6: Instr_AbsIdx_A(Y, &SPC700::Op_MOV); break;

   case 0xC5: Instr_Abs_Reg(A, &SPC700::Op_MOV); break;
   case 0xC9: Instr_Abs_Reg(X, &SPC700::Op_MOV); break;
   case 0xCC: Instr_Abs_Reg(Y, &SPC700::Op_MOV); break;
   //
   //
   //
   case 0x7A: Instr_YA_Dir(&SPC700::Op_ADDW); break;
   case 0x5A: Instr_YA_Dir(&SPC700::Op_CMPW); break;
   case 0xBA: Instr_YA_Dir(&SPC700::Op_MOVW); break;
   case 0xDA: Instr_Dir_YA_MOVW(); break;
   case 0x9A: Instr_YA_Dir(&SPC700::Op_SUBW); break;

   case 0x1A: Instr_DECWINCW<-1>(); break;	// DECW
   case 0x3A: Instr_DECWINCW< 1>(); break;	// INCW
   //
   //
   //

   case 0xAE: Instr_Pop(&A); break;
   case 0x8E: Instr_Pop(&PSW); break;
   case 0xCE: Instr_Pop(&X); break;
   case 0xEE: Instr_Pop(&Y); break;

   case 0x2D: Instr_Push(&A); break;
   case 0x0D: Instr_Push(&PSW); break;
   case 0x4D: Instr_Push(&X); break;
   case 0x6D: Instr_Push(&Y); break;

   //
   //
   //
   case 0x0A: Instr_C_MB<false, true>(&SPC700::Op_OR1); break;
   case 0x2A: Instr_C_MB<true,  true> (&SPC700::Op_OR1); break;
   case 0x4A: Instr_C_MB<false>(&SPC700::Op_AND1); break;
   case 0x6A: Instr_C_MB<true> (&SPC700::Op_AND1); break;
   case 0x8A: Instr_C_MB<false, true>(&SPC700::Op_EOR1); break;
   case 0xAA: Instr_C_MB<false>(&SPC700::Op_MOV1); break;

   case 0xCA: Instr_MB_C_MOV1(); break;
   case 0xEA: Instr_MB_NOT1(); break;

   // ASL
   case 0x1C: Instr_Reg   (&A, &SPC700::Op_ASL); break;
   case 0x0B: Instr_Dir   (&SPC700::Op_ASL); break;
   case 0x1B: Instr_DirIdx(&SPC700::Op_ASL); break;
   case 0x0C: Instr_Abs   (&SPC700::Op_ASL); break;

   // ROL
   case 0x3C: Instr_Reg   (&A, &SPC700::Op_ROL); break;
   case 0x2B: Instr_Dir   (&SPC700::Op_ROL); break;
   case 0x3B: Instr_DirIdx(&SPC700::Op_ROL); break;
   case 0x2C: Instr_Abs	  (&SPC700::Op_ROL); break;

   // LSR
   case 0x5C: Instr_Reg   (&A, &SPC700::Op_LSR); break;
   case 0x4B: Instr_Dir   (&SPC700::Op_LSR); break;
   case 0x5B: Instr_DirIdx(&SPC700::Op_LSR); break;
   case 0x4C: Instr_Abs	  (&SPC700::Op_LSR); break;

   // ROR
   case 0x7C: Instr_Reg   (&A, &SPC700::Op_ROR); break;
   case 0x6B: Instr_Dir   (&SPC700::Op_ROR); break;
   case 0x7B: Instr_DirIdx(&SPC700::Op_ROR); break;
   case 0x6C: Instr_Abs	  (&SPC700::Op_ROR); break;

   // DEC
   case 0x9C: Instr_Reg   (&A, &SPC700::Op_DEC); break;
   case 0x1D: Instr_Reg   (&X, &SPC700::Op_DEC); break;
   case 0xDC: Instr_Reg   (&Y, &SPC700::Op_DEC); break;
   case 0x8B: Instr_Dir   (&SPC700::Op_DEC); break;
   case 0x9B: Instr_DirIdx(&SPC700::Op_DEC); break;
   case 0x8C: Instr_Abs	  (&SPC700::Op_DEC); break;

   // INC
   case 0xBC: Instr_Reg   (&A, &SPC700::Op_INC); break;
   case 0x3D: Instr_Reg   (&X, &SPC700::Op_INC); break;
   case 0xFC: Instr_Reg   (&Y, &SPC700::Op_INC); break;
   case 0xAB: Instr_Dir   (&SPC700::Op_INC); break;
   case 0xBB: Instr_DirIdx(&SPC700::Op_INC); break;
   case 0xAC: Instr_Abs	  (&SPC700::Op_INC); break;

   // CLR1
   case 0x12: Instr_Dir(&SPC700::Op_CLR1<0>); break;
   case 0x32: Instr_Dir(&SPC700::Op_CLR1<1>); break;
   case 0x52: Instr_Dir(&SPC700::Op_CLR1<2>); break;
   case 0x72: Instr_Dir(&SPC700::Op_CLR1<3>); break;
   case 0x92: Instr_Dir(&SPC700::Op_CLR1<4>); break;
   case 0xB2: Instr_Dir(&SPC700::Op_CLR1<5>); break;
   case 0xD2: Instr_Dir(&SPC700::Op_CLR1<6>); break;
   case 0xF2: Instr_Dir(&SPC700::Op_CLR1<7>); break;

   // SET1
   case 0x02: Instr_Dir(&SPC700::Op_SET1<0>); break;
   case 0x22: Instr_Dir(&SPC700::Op_SET1<1>); break;
   case 0x42: Instr_Dir(&SPC700::Op_SET1<2>); break;
   case 0x62: Instr_Dir(&SPC700::Op_SET1<3>); break;
   case 0x82: Instr_Dir(&SPC700::Op_SET1<4>); break;
   case 0xA2: Instr_Dir(&SPC700::Op_SET1<5>); break;
   case 0xC2: Instr_Dir(&SPC700::Op_SET1<6>); break;
   case 0xE2: Instr_Dir(&SPC700::Op_SET1<7>); break;

   case 0x4E: Instr_Abs<true>(&SPC700::Op_TCLR1); break;
   case 0x0E: Instr_Abs<true>(&SPC700::Op_TSET1); break;

   //
   //
   //
   case 0x9F: Instr_XCN(); break;

   case 0xDF: Instr_DAA(); break;
   case 0xBE: Instr_DAS(); break;

   case 0x9E: Instr_DIV(); break;
   case 0xCF: Instr_MUL(); break;

   case 0xEF: Instr_SLEEP(); goto HaltedBalted;
   case 0xFF: Instr_STOP(); goto HaltedBalted;
  }

#if 0
  {
   int elapsed = counter_before - cycle_counter;

   assert(
	   (elapsed == (CycleCheckTable[opcode] & 0x7F)) ||
	   ((CycleCheckTable[opcode] & 0x80) && (elapsed == (2 + (CycleCheckTable[opcode] & 0x7F))))
	 );
  }
#endif
 }
}

INLINE void SPC700::Run(int32 cycles)
{
 SPC700 l = *this;
 l.cycle_counter += cycles;
 l.RunReal();
 *this = l;
}


void SPC700::Reset(bool powering_up)
{
 memcpy(CycleHackyTable, CycleHackyTable_Init, sizeof(CycleHackyTable)); // Don't put it in the constructor, or else the compiler might try to be too smort.
 //
 PC = 0xFFC0;	// FIXME FIXME FIXME, read the vector properly!
 A = X = Y = 0;
 PSW = I_FLAG;
 SP = 0xFF;

 Halted = false;
 opcode_saver = -1;
 cycle_counter = 0;
}

void SPC700::StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(PC),
  SFVAR(PSW),
  SFVAR(A),
  SFVAR(X),
  SFVAR(Y),
  SFVAR(SP),
  SFVAR(Halted),

  SFVAR(opcode_saver),
  SFVAR(cycle_counter),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SPC700");

 if(load)
 {
  if(cycle_counter < -1000 || cycle_counter > 1000)	// Sanity check.
   cycle_counter = 0;
 }
}

SPC700::SPC700()
{
 
}

SPC700::~SPC700()
{

}

