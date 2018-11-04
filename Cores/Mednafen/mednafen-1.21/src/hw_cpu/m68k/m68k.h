/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* m68k.h - Motorola 68000 CPU Emulator
**  Copyright (C) 2015-2016 Mednafen Team
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

#ifndef __MDFN_M68K_H
#define __MDFN_M68K_H

#include <mednafen/mednafen.h>

class M68K
{
 public:

 M68K(const bool rev_e = false) MDFN_COLD;
 ~M68K() MDFN_COLD;

 void Run(int32 run_until_time);
 void Step(void);

 void Reset(bool powering_up) MDFN_COLD;

 void SetIPL(uint8 ipl_new);
 void SetExtHalted(bool state);

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname);

 void LoadOldState(const uint8* osm);
 enum { OldStateLen = 512 };
 //
 //
 //
 //
 //
 //
 //
 //
 union
 {
  uint32 DA[16];
  struct
  {
   uint32 D[8];
   uint32 A[8];
  };
 };
 int32 timestamp;

 uint32 PC;
 uint8 SRHB;
 uint8 IPL;

 bool Flag_Z, Flag_N;
 bool Flag_X, Flag_C, Flag_V;

 uint32 SP_Inactive;
 uint32 XPending;
 enum
 {
  XPENDING_MASK_INT 	= 0x0001,
  XPENDING_MASK_NMI	= 0x0002,
  XPENDING_MASK_RESET	= 0x0010,
  XPENDING_MASK_STOPPED	= 0x0100,	// via STOP instruction
  XPENDING_MASK_EXTHALTED= 0x1000
 };

 const bool Revision_E;

 //private:
 void RecalcInt(void);

 template<typename T>
 T Read(uint32 addr);

 uint16 ReadOp(void);

 template<typename T, bool long_dec = false>
 void Write(uint32 addr, const T val);

 template<typename T>
 void Push(const T value);

 template<typename T>
 T Pull(void);

 enum AddressMode
 {
  DATA_REG_DIR,
  ADDR_REG_DIR,

  ADDR_REG_INDIR,
  ADDR_REG_INDIR_POST,
  ADDR_REG_INDIR_PRE,

  ADDR_REG_INDIR_DISP,

  ADDR_REG_INDIR_INDX,

  ABS_SHORT,
  ABS_LONG,

  PC_DISP,
  PC_INDEX,

  IMMEDIATE
 };

 //
 // MOVE byte and word: instructions, 2 cycle penalty for source predecrement only
 //  	2 cycle penalty for (d8, An, Xn) for both source and dest ams
 //  	2 cycle penalty for (d8, PC, Xn) for dest am
 //

 //
 // Careful on declaration order of HAM objects(needs to be source then dest).
 //
 template<typename T, M68K::AddressMode am>
 struct HAM;

 void SetC(bool val);
 void SetV(bool val);
 void SetZ(bool val);
 void SetN(bool val);
 void SetX(bool val);

 bool GetC(void);
 bool GetV(void);
 bool GetZ(void);
 bool GetN(void);
 bool GetX(void);

 void SetCX(bool val);

 template<typename T, bool Z_OnlyClear = false>
 void CalcZN(const T val);

 template<typename T>
 void CalcCX(const uint64& val);

 uint8 GetCCR(void);
 void SetCCR(uint8 val);
 uint16 GetSR(void);
 void SetSR(uint16 val);

 uint8 GetIMask(void);
 void SetIMask(uint8 val);

 bool GetSVisor(void);
 void SetSVisor(bool value);
 bool GetTrace(void);
 void SetTrace(bool value);

 //
 //
 //
 enum
 {
  VECNUM_RESET_SSP = 0,
  VECNUM_RESET_PC  = 1,
  VECNUM_BUS_ERROR = 2,
  VECNUM_ADDRESS_ERROR = 3,
  VECNUM_ILLEGAL = 4,
  VECNUM_ZERO_DIVIDE = 5,
  VECNUM_CHK = 6,
  VECNUM_TRAPV = 7,
  VECNUM_PRIVILEGE = 8,
  VECNUM_TRACE = 9,
  VECNUM_LINEA = 10,
  VECNUM_LINEF = 11,

  VECNUM_UNINI_INT = 15,

  VECNUM_SPURIOUS_INT = 24,
  VECNUM_INT_BASE = 24,

  VECNUM_TRAP_BASE = 32
 };

 enum
 {
  EXCEPTION_RESET = 0,
  EXCEPTION_BUS_ERROR,
  EXCEPTION_ADDRESS_ERROR,
  EXCEPTION_ILLEGAL,
  EXCEPTION_ZERO_DIVIDE,
  EXCEPTION_CHK,
  EXCEPTION_TRAPV,
  EXCEPTION_PRIVILEGE,
  EXCEPTION_TRACE,

  EXCEPTION_INT,
  EXCEPTION_TRAP
 };

 void NO_INLINE Exception(unsigned which, unsigned vecnum);

 template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void ADD(HAM<T, SAM> &src, HAM<DT, DAM> &dst);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void ADDX(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 template<bool X_form, typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
 DT Subtract(HAM<T, SAM> &src, HAM<DT, DAM> &dst);

 template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void SUB(HAM<T, SAM> &src, HAM<DT, DAM> &dst);

 template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void SUBX(HAM<T, SAM> &src, HAM<DT, DAM> &dst);

 template<typename DT, M68K::AddressMode DAM>
 void NEG(HAM<DT, DAM> &dst);

 template<typename DT, M68K::AddressMode DAM>
 void NEGX(HAM<DT, DAM> &dst);

 template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void CMP(HAM<T, SAM> &src, HAM<DT, DAM> &dst);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void CHK(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void OR(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void EOR(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void AND(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 void ORI_CCR(void);
 void ORI_SR(void);
 void ANDI_CCR(void);
 void ANDI_SR(void);
 void EORI_CCR(void);
 void EORI_SR(void);

 template<typename T, M68K::AddressMode SAM>
 void MULU(HAM<T, SAM> &src, const unsigned dr);

 template<typename T, M68K::AddressMode SAM>
 void MULS(HAM<T, SAM> &src, const unsigned dr);

 template<bool sdiv>
 void Divide(uint16 divisor, const unsigned dr);

 template<typename T, M68K::AddressMode SAM>
 void DIVU(HAM<T, SAM> &src, const unsigned dr);

 template<typename T, M68K::AddressMode SAM>
 void DIVS(HAM<T, SAM> &src, const unsigned dr);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void ABCD(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 uint8 DecimalSubtractX(const uint8 src_data, const uint8 dst_data);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void SBCD(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode DAM>
 void NBCD(HAM<T, DAM> &dst);

 template<typename T, bool reg_to_mem>
 void MOVEP(const unsigned ar, const unsigned dr);

 template<typename T, M68K::AddressMode TAM>
 void BTST(HAM<T, TAM> &targ, unsigned wb);

 template<typename T, M68K::AddressMode TAM>
 void BCHG(HAM<T, TAM> &targ, unsigned wb);

 template<typename T, M68K::AddressMode TAM>
 void BCLR(HAM<T, TAM> &targ, unsigned wb);

 template<typename T, M68K::AddressMode TAM>
 void BSET(HAM<T, TAM> &targ, unsigned wb);

 template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
 void MOVE(HAM<T, SAM> &src, HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode SAM>
 void MOVEA(HAM<T, SAM> &src, const unsigned ar);

 template<bool pseudo_predec, typename T, M68K::AddressMode DAM>
 void MOVEM_to_MEM(const uint16 reglist, HAM<T, DAM> &dst);

 template<bool pseudo_postinc, typename T, M68K::AddressMode SAM>
 void MOVEM_to_REGS(HAM<T, SAM> &src, const uint16 reglist);

 template<typename T, M68K::AddressMode TAM, bool Arithmetic, bool ShiftLeft>
 void ShiftBase(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void ASL(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void ASR(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void LSL(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void LSR(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM, bool X_Form, bool ShiftLeft>
 void RotateBase(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void ROL(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void ROR(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void ROXL(HAM<T, TAM> &targ, unsigned count);

 template<typename T, M68K::AddressMode TAM>
 void ROXR(HAM<T, TAM> &targ, unsigned count);

#if 0
static uint8 TAS_Callback(uint8 data)
{
 CalcZN<uint8>(data);
 SetC(false);
 SetV(false);

 data |= 0x80;
 return data;
}
#endif

 template<typename T, M68K::AddressMode DAM>
 void TAS(HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode DAM>
 void TST(HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode DAM>
 void CLR(HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode DAM>
 void NOT(HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode DAM>
 void EXT(HAM<T, DAM> &dst);

 void SWAP(const unsigned dr);

 void EXG(uint32* a, uint32* b);

 template<unsigned cc>
 bool TestCond(void);

 template<unsigned cc>
 void Bxx(uint32 disp);

 template<unsigned cc>
 void DBcc(const unsigned dr);

 template<unsigned cc, typename T, M68K::AddressMode DAM>
 void Scc(HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode TAM>
 void JSR(HAM<T, TAM> &targ);

 template<typename T, M68K::AddressMode TAM>
 void JMP(HAM<T, TAM> &targ);

 template <typename T, M68K::AddressMode DAM>
 void MOVE_from_SR(HAM<T, DAM> &dst);

 template<typename T, M68K::AddressMode SAM>
 void MOVE_to_CCR(HAM<T, SAM> &src);

 template<typename T, M68K::AddressMode SAM>
 void MOVE_to_SR(HAM<T, SAM> &src);

 template<bool direction>
 void MOVE_USP(const unsigned ar);

 template<typename T, M68K::AddressMode SAM>
 void LEA(HAM<T, SAM> &src, const unsigned ar);

 template<typename T, M68K::AddressMode SAM>
 void PEA(HAM<T, SAM> &src);
 void UNLK(const unsigned ar);
 void LINK(const unsigned ar);
 void RTE(void);
 void RTR(void);
 void RTS(void);
 void TRAP(const unsigned vf);
 void TRAPV(void);
 void ILLEGAL(const uint16 instr);
 void LINEA(void);
 void LINEF(void);
 void NOP(void);
 void RESET(void);
 void STOP(void);

 bool CheckPrivilege(void);

 void InternalStep(void);

 //
 //
 //
 //
 //
 // These externally-provided functions should add >= 4 to M68K::timestamp per call:
 enum { BUS_INT_ACK_AUTO = -1 };

 uint16 (MDFN_FASTCALL *BusReadInstr)(uint32 A);
 uint8 (MDFN_FASTCALL *BusRead8)(uint32 A);
 uint16 (MDFN_FASTCALL *BusRead16)(uint32 A);
 void (MDFN_FASTCALL *BusWrite8)(uint32 A, uint8 V);
 void (MDFN_FASTCALL *BusWrite16)(uint32 A, uint16 V);
 //
 //
 void (MDFN_FASTCALL *BusRMW)(uint32 A, uint8 (MDFN_FASTCALL *cb)(M68K*, uint8));
 unsigned (MDFN_FASTCALL *BusIntAck)(uint8 level);
 void (MDFN_FASTCALL *BusRESET)(bool state);	// Optional; Calling Reset(false) from this callback *is* permitted.

 //
 //
 //
 void (*DBG_Warning)(const char* format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);
 void (*DBG_Verbose)(const char* format, ...) noexcept MDFN_FORMATSTR(gnu_printf, 1, 2);
 //
 //
 //
 public:
 enum
 {
  GSREG_D0 = 0,
  GSREG_D1,
  GSREG_D2,
  GSREG_D3,
  GSREG_D4,
  GSREG_D5,
  GSREG_D6,
  GSREG_D7,

  GSREG_A0 = 8,
  GSREG_A1,
  GSREG_A2,
  GSREG_A3,
  GSREG_A4,
  GSREG_A5,
  GSREG_A6,
  GSREG_A7,

  GSREG_PC = 16,
  GSREG_SR,
  GSREG_SSP,
  GSREG_USP
 };

 uint32 GetRegister(unsigned which, char* special = nullptr, const uint32 special_len = 0);
 void SetRegister(unsigned which, uint32 value);
 INLINE void DupeState(const M68K* const src)
 {
  memcpy(DA, src->DA, 16 * sizeof(uint32));
  timestamp = src->timestamp;
  PC = src->PC;
  SRHB = src->SRHB;
  IPL = src->IPL;
  Flag_Z = src->Flag_Z;
  Flag_N = src->Flag_N;
  Flag_X = src->Flag_X;
  Flag_C = src->Flag_C;
  Flag_V = src->Flag_V;
  SP_Inactive = src->SP_Inactive;
  XPending = src->XPending;
 }
};

#endif
