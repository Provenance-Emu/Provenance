/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* m68k.cpp - Motorola 68000 CPU Emulator
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

// TODO: Check CHK
//
// TODO: Address errors(or just cheap out and mask off the lower bit on 16-bit memory accesses).
//
// TODO: Predec, postinc order for same address register.
//
// TODO: Fix instruction timings(currently execute too fast).
//
// TODO: Fix multiplication and division timing, and make sure flags are ok for divide by zero.
//
// FIXME: Handle NMI differently; how to test?  Maybe MOVEM to interrupt control registers...
//
// TODO: Test MOVEM
//
/*
 Be sure to test the following thoroughly:
	SUBA -(a0), a0
	SUBX -(a0),-(a0)
	CMPM (a0)+,(a0)+

	SUBA -(a7), a7
	SUBX -(a7),-(a7)
	CMPM (a7)+,(a7)+
*/

#include <mednafen/mednafen.h>
#include "m68k.h"

#include <tuple>

#pragma GCC optimize ("no-crossjumping,no-gcse")

static MDFN_FASTCALL void Dummy_BusRESET(bool state)
{

}

static void DummyDBG(const char* format, ...) noexcept
{

}

M68K::M68K(const bool rev_e) : Revision_E(rev_e),
	       BusReadInstr(nullptr), BusRead8(nullptr), BusRead16(nullptr),
	       BusWrite8(nullptr), BusWrite16(nullptr),
	       BusRMW(nullptr),
	       BusIntAck(nullptr),
	       BusRESET(Dummy_BusRESET),
	       DBG_Warning(DummyDBG),
	       DBG_Verbose(DummyDBG)
{
 timestamp = 0;
 XPending = 0;
 IPL = 0;
 Reset(true);
}

M68K::~M68K()
{

}

void M68K::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(DA),
  SFVAR(PC),
  SFVAR(SRHB),
  SFVAR(IPL),

  SFVAR(Flag_Z),
  SFVAR(Flag_N),
  SFVAR(Flag_X),
  SFVAR(Flag_C),
  SFVAR(Flag_V),

  SFVAR(SP_Inactive),

  SFVAR(XPending),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);
}

void M68K::LoadOldState(const uint8* osm)
{
 uint32 old_C, old_V, old_notZ, old_N, old_X, old_I, old_S;
 uint32 old_USP, old_Status, old_IRQLine;

 osm += 4;

 for(unsigned i = 0; i < 16; i++)
 {
  DA[i] = MDFN_de32lsb(osm);
  osm += 4;
 }

 old_C = MDFN_de32lsb(osm); osm += 4;
 old_V = MDFN_de32lsb(osm); osm += 4;
 old_notZ = MDFN_de32lsb(osm); osm += 4;
 old_N = MDFN_de32lsb(osm); osm += 4;
 old_X = MDFN_de32lsb(osm); osm += 4;
 old_I = MDFN_de32lsb(osm); osm += 4;
 old_S = MDFN_de32lsb(osm); osm += 4;
 old_USP = MDFN_de32lsb(osm); osm += 4;
 PC = MDFN_de32lsb(osm); osm += 4;
 old_Status = MDFN_de32lsb(osm); osm += 4;
 old_IRQLine = MDFN_de32lsb(osm); osm += 4;

 if(MDFN_de32lsb(osm) != 0xDEADBEEF)
  throw MDFN_Error(0, _("Malformed old 68K save state."));
 //
 //
 Flag_C = (old_C >> 8) & 1;
 Flag_V = (old_V >> 7) & 1;
 Flag_Z = !old_notZ;
 Flag_N = (old_N >> 7) & 1;
 Flag_X = (old_X >> 8) & 1;
 SRHB = ((old_S >> 8) & 0x20) | (old_I & 0x7);
 SP_Inactive = old_USP;

 XPending = ((old_Status & 0x02) ? XPENDING_MASK_STOPPED : 0);
 IPL = old_IRQLine & 0x7;

 RecalcInt();
}

INLINE void M68K::RecalcInt(void)
{
 XPending &= ~XPENDING_MASK_INT;

 if(IPL > (SRHB & 0x7))
  XPending |= XPENDING_MASK_INT;
}

void M68K::SetIPL(uint8 ipl_new)
{
 if(IPL < 0x7 && ipl_new == 0x7)
  XPending |= XPENDING_MASK_NMI;
 else if(ipl_new < 0x7)
  XPending &= ~XPENDING_MASK_NMI;

 IPL = ipl_new;
 RecalcInt();
}

void M68K::SetExtHalted(bool state)
{
 XPending &= ~XPENDING_MASK_EXTHALTED;
 if(state)
  XPending |= XPENDING_MASK_EXTHALTED;
}

template<typename T>
INLINE T M68K::Read(uint32 addr)
{
 if(sizeof(T) == 4)
 {
  uint32 ret;

  ret = BusRead16(addr) << 16;
  ret |= BusRead16(addr + 2);

  return ret;
 }
 else if(sizeof(T) == 2)
  return BusRead16(addr);
 else
  return BusRead8(addr);
}

INLINE uint16 M68K::ReadOp(void)
{
 uint16 ret;

 ret = BusReadInstr(PC);
 PC += 2;

 return ret;
}

template<typename T, bool long_dec>
INLINE void M68K::Write(uint32 addr, const T val)
{
 if(sizeof(T) == 4)
 {
  if(long_dec)
  {
   BusWrite16(addr + 2, val);
   BusWrite16(addr, val >> 16);
  }
  else
  {
   BusWrite16(addr, val >> 16);
   BusWrite16(addr + 2, val);
  }
 }
 else if(sizeof(T) == 2)
  BusWrite16(addr, val);
 else
  BusWrite8(addr, val);
}

template<typename T>
INLINE void M68K::Push(const T value)
{
 static_assert(sizeof(T) != 1, "Wrong type.");
 A[7] -= sizeof(T);
 Write<T, true>(A[7], value);
}

template<typename T>
INLINE T M68K::Pull(void)
{
 static_assert(sizeof(T) != 1, "Wrong type.");

 T ret;

 ret = Read<T>(A[7]);

 A[7] += sizeof(T);

 return ret;
}

//
// MOVE byte and word: instructions, 2 cycle penalty for source predecrement only
//  	2 cycle penalty for (d8, An, Xn) for both source and dest ams
//  	2 cycle penalty for (d8, PC, Xn) for dest am
//

//
// Careful on declaration order of HAM objects(needs to be source then dest).
//
template<typename T, M68K::AddressMode am>
struct M68K::HAM
{
 INLINE HAM(M68K* z) : zptr(z), reg(0), have_ea(false)
 {
  static_assert(am == PC_DISP || am == PC_INDEX || am == ABS_SHORT || am == ABS_LONG || am == IMMEDIATE, "Wrong arg count.");

  switch(am)
  {
   case PC_DISP:   // (d16, PC)
   case PC_INDEX:  // PC with index
	ea = zptr->PC;
	ext = zptr->ReadOp();
	break;

   case ABS_SHORT: // (xxxx).W
	ext = zptr->ReadOp();
	break;

   case ABS_LONG: // (xxxx).L
	ext = zptr->ReadOp() << 16;
	ext |= zptr->ReadOp();
	break;

   case IMMEDIATE: // Immediate
	if(sizeof(T) == 4)
	{
	 ext = zptr->ReadOp() << 16;
	 ext |= zptr->ReadOp();
	}
	else
	{
	 ext = zptr->ReadOp();
	}
	break;
  }
 }

 INLINE HAM(M68K* z, uint32 arg) : zptr(z), reg(arg), have_ea(false)
 {
  static_assert(am != PC_DISP && am != PC_INDEX && am != ABS_SHORT && am != ABS_LONG, "Wrong arg count.");

  static_assert(am != ADDR_REG_DIR || sizeof(T) != 1, "Wrong size for address reg direct read");

  switch(am)
  {
   case DATA_REG_DIR:
   case ADDR_REG_DIR:
   case ADDR_REG_INDIR:
   case ADDR_REG_INDIR_POST:
   case ADDR_REG_INDIR_PRE:
   	break;
  
   case ADDR_REG_INDIR_DISP:	// (d16, An)
   case ADDR_REG_INDIR_INDX: 	// (d8, An, Xn)
	ext = zptr->ReadOp();
	break;

   case IMMEDIATE: 	// Immediate (quick)
	ext = arg;
	break;
  }
 }

 private:
 INLINE void calcea(const int predec_penalty)
 {
  if(have_ea)
   return;

  have_ea = true;

  switch(am)
  {
   default:
	break;

   case ADDR_REG_INDIR:
	ea = zptr->A[reg];
	break;

   case ADDR_REG_INDIR_POST:
	ea = zptr->A[reg];
	zptr->A[reg] += (sizeof(T) == 1 && reg == 0x7) ? 2 : sizeof(T);
	break;

   case ADDR_REG_INDIR_PRE:
	zptr->timestamp += predec_penalty;
	zptr->A[reg] -= (sizeof(T) == 1 && reg == 0x7) ? 2 : sizeof(T);
	ea = zptr->A[reg];
	break;

   case ADDR_REG_INDIR_DISP:
	ea = zptr->A[reg] + (int16)ext;
	break;

   case ADDR_REG_INDIR_INDX:
	zptr->timestamp += 2;
	ea = zptr->A[reg] + (int8)ext + ((ext & 0x800) ? zptr->DA[ext >> 12] : (int16)zptr->DA[ext >> 12]);
	break;	

   case ABS_SHORT:
	ea = (int16)ext;
	break;

   case ABS_LONG:
	ea = ext;
	break;

   case PC_DISP:
	ea = ea + (int16)ext;
	break;

   case PC_INDEX:
	zptr->timestamp += 2;
	ea = ea + (int8)ext + ((ext & 0x800) ? zptr->DA[ext >> 12] : (int16)zptr->DA[ext >> 12]);
	break;
  }
 }
 public:

 //
 // TODO: check pre-decrement 32-bit->2x 16-bit write order
 //

 INLINE void write(const T val, const int predec_penalty = 2)
 {
  static_assert(am != PC_DISP && am != PC_INDEX && am != IMMEDIATE, "What");

  static_assert(am != ADDR_REG_DIR || sizeof(T) == 4, "Wrong size for address reg direct write");

  switch(am)
  {
   case ADDR_REG_DIR:
	zptr->A[reg] = val;
	break;

   case DATA_REG_DIR:
	#ifdef MSB_FIRST
	memcpy((uint8*)&zptr->D[reg] + (4 - sizeof(T)), &val, sizeof(T));
	#else
	memcpy((uint8*)&zptr->D[reg] + 0, &val, sizeof(T));
	#endif
	break;

   case ADDR_REG_INDIR:
   case ADDR_REG_INDIR_POST:
   case ADDR_REG_INDIR_PRE:
   case ADDR_REG_INDIR_DISP:
   case ADDR_REG_INDIR_INDX:
   case ABS_SHORT:
   case ABS_LONG:
	calcea(predec_penalty);
	zptr->Write<T, am == ADDR_REG_INDIR_PRE>(ea, val);
	break;
  }
 }

 INLINE T read(void)
 {
  switch(am)
  {
   case DATA_REG_DIR:
	return zptr->D[reg];

   case ADDR_REG_DIR:
	return zptr->A[reg];

   case IMMEDIATE:
	return ext;

   case ADDR_REG_INDIR:
   case ADDR_REG_INDIR_POST:
   case ADDR_REG_INDIR_PRE:
   case ADDR_REG_INDIR_DISP:
   case ADDR_REG_INDIR_INDX:
   case ABS_SHORT:
   case ABS_LONG:
   case PC_DISP:
   case PC_INDEX:
	calcea(2);
	return zptr->Read<T>(ea);
  }
 }

 INLINE void rmw(T (MDFN_FASTCALL *cb)(M68K*, T))
 {
  static_assert(am != PC_DISP && am != PC_INDEX && am != IMMEDIATE, "What");

  switch(am)
  {
   case DATA_REG_DIR:
	{
	 T tmp = cb(zptr, zptr->D[reg]);
	 #ifdef MSB_FIRST
	 memcpy((uint8*)&zptr->D[reg] + (4 - sizeof(T)), &tmp, sizeof(T));
	 #else
	 memcpy((uint8*)&zptr->D[reg] + 0, &tmp, sizeof(T));
	 #endif
	}
	break;

   case ADDR_REG_INDIR:
   case ADDR_REG_INDIR_POST:
   case ADDR_REG_INDIR_PRE:
   case ADDR_REG_INDIR_DISP:
   case ADDR_REG_INDIR_INDX:
   case ABS_SHORT:
   case ABS_LONG:
	calcea(2);

	zptr->BusRMW(ea, cb);
	break;
  }
 }


 INLINE void jump(void)
 {
  calcea(0);
  zptr->PC = ea;
 }

 INLINE uint32 getea(void)
 {
  static_assert(am == ADDR_REG_INDIR || am == ADDR_REG_INDIR_DISP || am == ADDR_REG_INDIR_INDX || am == ABS_SHORT || am == ABS_LONG || am == PC_DISP || am == PC_INDEX, "Wrong addressing mode");
  calcea(0);
  return ea;
 }

 M68K* zptr;

 uint32 ea;
 uint32 ext;
 const unsigned reg;

 private:
 bool have_ea;
};



INLINE void M68K::SetC(bool val) { Flag_C = val; }
INLINE void M68K::SetV(bool val) { Flag_V = val; }
INLINE void M68K::SetZ(bool val) { Flag_Z = val; }
INLINE void M68K::SetN(bool val) { Flag_N = val; }
INLINE void M68K::SetX(bool val) { Flag_X = val; }

INLINE bool M68K::GetC(void) { return Flag_C; }
INLINE bool M68K::GetV(void) { return Flag_V; }
INLINE bool M68K::GetZ(void) { return Flag_Z; }
INLINE bool M68K::GetN(void) { return Flag_N; }
INLINE bool M68K::GetX(void) { return Flag_X; }


INLINE void M68K::SetCX(bool val)
{
 SetC(val);
 SetX(val);
}

//
// Z_OnlyClear should be true for ADDX, SUBX, NEGX, ABCD, SBCD, NBCD.
//
template<typename T, bool Z_OnlyClear>
INLINE void M68K::CalcZN(const T val)
{
 if(Z_OnlyClear)
 {
  if(val != 0)
   SetZ(false);
 }
 else
  SetZ(val == 0);

 SetN(static_cast<typename std::make_signed<T>::type>(val) < 0);
}

template<typename T>
INLINE void M68K::CalcCX(const uint64& val)
{
 SetCX((val >> (sizeof(T) * 8)) & 1);
}

INLINE uint8 M68K::GetCCR(void)
{
 return (GetC() << 0) | (GetV() << 1) | (GetZ() << 2) | (GetN() << 3) | (GetX() << 4);
}

INLINE void M68K::SetCCR(uint8 val)
{
 SetC((val >> 0) & 1);
 SetV((val >> 1) & 1);
 SetZ((val >> 2) & 1);
 SetN((val >> 3) & 1);
 SetX((val >> 4) & 1);
}

INLINE uint16 M68K::GetSR(void)
{
 return GetCCR() | (SRHB << 8);
}

INLINE void M68K::SetSR(uint16 val)
{
 const uint8 new_srhb = (val >> 8) & 0xA7;

 SetCCR(val);

 if((SRHB ^ new_srhb) & 0x20)	// Supervisor mode change
 {
  std::swap(A[7], SP_Inactive);
 }

 SRHB = new_srhb;
 RecalcInt();
}

INLINE uint8 M68K::GetIMask(void)
{
 return (GetSR() >> 8) & 0x7;
}

INLINE void M68K::SetIMask(uint8 val)
{
 SetSR((GetSR() & ~0x0700) | ((val & 0x7) << 8));
}

INLINE bool M68K::GetSVisor(void)
{
 return (bool)(GetSR() & 0x2000);
}

INLINE void M68K::SetSVisor(bool value)
{
 SetSR((GetSR() & ~0x2000) | (value << 13));
}

INLINE bool M68K::GetTrace(void)
{
 return (bool)(GetSR() & 0x8000);
}

INLINE void M68K::SetTrace(bool value)
{
 SetSR((GetSR() & ~0x8000) | (value << 15));
}

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

//
// Instruction traps(TRAP, TRAPV, CHK, DIVS, DIVU):
//	Saved PC points to the instruction after the instruction that triggered the exception.
//
// Illegal instructions:
//
//
// Privilege violation:
// 	Saved PC points to the instruction that generated the privilege violation.
//
// Base exception timing is 34 cycles?
void NO_INLINE M68K::Exception(unsigned which, unsigned vecnum)
{
 const uint32 PC_save = PC;
 const uint16 SR_save = GetSR();

 SetSVisor(true);
 SetTrace(false);
 
 if(which == EXCEPTION_INT)
 {
  unsigned evn;

  timestamp += 4;

  SetIMask(IPL);

  evn = BusIntAck(IPL);

  if(evn > 255)
   vecnum = vecnum + IPL;
  else
   vecnum = evn;

  timestamp += 2;
 }

 Push<uint32>(PC_save);
 Push<uint16>(SR_save);
 PC = Read<uint32>(vecnum << 2);

 //
 {
  auto dbgw = DBG_Verbose;

  if(which != EXCEPTION_INT || vecnum == VECNUM_UNINI_INT || vecnum == VECNUM_SPURIOUS_INT)
   dbgw = DBG_Warning;

  dbgw("[M68K] Exception %u(vec=%u) @PC=0x%08x SR=0x%04x ---> PC=0x%08x, SR=0x%04x\n", which, vecnum, PC_save, SR_save, PC, GetSR());
 }
 //

 // TODO: Prefetch
 ReadOp();
 ReadOp();
 PC -= 4;
}

//
//
//

//
// ADD
//
template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::ADD(HAM<T, SAM> &src, HAM<DT, DAM> &dst)
{
 static_assert(DAM == ADDR_REG_DIR || std::is_same<T, DT>::value, "Type mismatch");

 uint32 const src_data = (DT)static_cast<typename std::make_signed<T>::type>(src.read());
 uint32 const dst_data = dst.read();
 uint64 const result = (uint64)dst_data + src_data;

 if(DAM == ADDR_REG_DIR)
 {
  if(sizeof(T) != 4 || SAM == DATA_REG_DIR || SAM == ADDR_REG_DIR || SAM == IMMEDIATE)
   timestamp += 4;
  else
   timestamp += 2;
 }
 else if(DAM == DATA_REG_DIR && sizeof(DT) == 4)
 {
  if(SAM == DATA_REG_DIR || SAM == IMMEDIATE)
   timestamp += 4;
  else
   timestamp += 2;
 }

 if(DAM != ADDR_REG_DIR)
 {
  CalcZN<DT>(result);
  SetCX((result >> (sizeof(DT) * 8)) & 1);
  SetV((((~(dst_data ^ src_data)) & (dst_data ^ result)) >> (sizeof(DT) * 8 - 1)) & 1);
 }

 dst.write(result);
}


//
// ADDX
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::ADDX(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 uint32 const src_data = src.read();
 uint32 const dst_data = dst.read();
 uint64 const result = (uint64)dst_data + src_data + GetX();

 if(DAM != DATA_REG_DIR)
 {
  timestamp += 2;
 }
 else
 {
  if(sizeof(T) == 4)
   timestamp += 4;
 }

 CalcZN<T, true>(result);
 SetCX((result >> (sizeof(T) * 8)) & 1);
 SetV((((~(dst_data ^ src_data)) & (dst_data ^ result)) >> (sizeof(T) * 8 - 1)) & 1);

 dst.write(result);
}


//
// Used to implement SUB, SUBA, SUBX, NEG, NEGX
//
template<bool X_form, typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE DT M68K::Subtract(HAM<T, SAM> &src, HAM<DT, DAM> &dst)
{
 static_assert(DAM == ADDR_REG_DIR || std::is_same<T, DT>::value, "Type mismatch");
 static_assert(DAM == ADDR_REG_DIR || DAM == DATA_REG_DIR || DAM == IMMEDIATE || SAM == ADDR_REG_DIR || SAM == DATA_REG_DIR || SAM == IMMEDIATE || X_form, "Wrong addressing modes.");

 uint32 const src_data = (DT)static_cast<typename std::make_signed<T>::type>(src.read());
 uint32 const dst_data = dst.read();
 const uint64 result = (uint64)dst_data - src_data - (X_form ? GetX() : 0);

 if(DAM == ADDR_REG_DIR)	// SUBA, SUBQ(A) only.
 {
  if(sizeof(T) != 4 || SAM == DATA_REG_DIR || SAM == ADDR_REG_DIR || SAM == IMMEDIATE)
   timestamp += 4;
  else
   timestamp += 2;
 }
 else if(DAM == DATA_REG_DIR)	// SUB, SUBQ, SUBX only.
 {
  if(sizeof(DT) == 4)
  {
   if(SAM == DATA_REG_DIR || SAM == IMMEDIATE)
    timestamp += 4;
   else
    timestamp += 2;
  }
 }
 else if(DAM == IMMEDIATE)	// NEG, NEGX only and always.
 {
  if(sizeof(T) == 4)
  {
   timestamp += 2;
  }
 }
 else if(SAM != IMMEDIATE && SAM != ADDR_REG_DIR && SAM != DATA_REG_DIR) // SUBX m,m
 {
  timestamp += 2;
 }


 if(DAM != ADDR_REG_DIR)
 {
  CalcZN<DT, X_form>(result);
  SetCX((result >> (sizeof(DT) * 8)) & 1);
  SetV(((((dst_data ^ src_data)) & (dst_data ^ result)) >> (sizeof(DT) * 8 - 1)) & 1);
 }

 return result;
}


//
// SUB
//
template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::SUB(HAM<T, SAM> &src, HAM<DT, DAM> &dst)
{
 dst.write(Subtract<false>(src, dst));
}


//
// SUBX
//
template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::SUBX(HAM<T, SAM> &src, HAM<DT, DAM> &dst)
{
 dst.write(Subtract<true>(src, dst));
}


//
// NEG
//
template<typename DT, M68K::AddressMode DAM>
INLINE void M68K::NEG(HAM<DT, DAM> &dst)
{
 HAM<DT, IMMEDIATE> dummy_zero(this, 0);

 dst.write(Subtract<false>(dst, dummy_zero));
}


//
// NEGX
//
template<typename DT, M68K::AddressMode DAM>
INLINE void M68K::NEGX(HAM<DT, DAM> &dst)
{
 HAM<DT, IMMEDIATE> dummy_zero(this, 0);

 dst.write(Subtract<true>(dst, dummy_zero));
}


//
// CMP
//
template<typename T, typename DT, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::CMP(HAM<T, SAM> &src, HAM<DT, DAM> &dst)
{
 static_assert(DAM == ADDR_REG_DIR || std::is_same<T, DT>::value, "Type mismatch");

 // Doesn't affect X flag
 uint32 const src_data = (DT)static_cast<typename std::make_signed<T>::type>(src.read());
 uint32 const dst_data = dst.read();
 uint64 const result = (uint64)dst_data - src_data;

 CalcZN<DT>(result);
 SetC((result >> (sizeof(DT) * 8)) & 1);
 SetV(((((dst_data ^ src_data)) & (dst_data ^ result)) >> (sizeof(DT) * 8 - 1)) & 1);
}


//
// CHK
//
// Exception on dst < 0 || dst > src
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::CHK(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 uint32 const src_data = src.read();
 uint32 const dst_data = dst.read();
 
 timestamp += 6;

 CalcZN<T>(dst_data);
 if(GetN())
 {
  Exception(EXCEPTION_CHK, VECNUM_CHK);
 }
 else
 {
  // 7 - 1
  uint64 const result = (uint64)dst_data - src_data;

  CalcZN<T>(result);
  SetC((result >> (sizeof(T) * 8)) & 1);
  SetV(((((dst_data ^ src_data)) & (dst_data ^ result)) >> (sizeof(T) * 8 - 1)) & 1);

  if(GetN() == GetV() && !GetZ())
  {
   Exception(EXCEPTION_CHK, VECNUM_CHK);
  }
 }
}


//
// OR
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::OR(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 T const src_data = src.read();
 T const dst_data = dst.read();
 T const result = dst_data | src_data;

 if(sizeof(T) == 4 && DAM == DATA_REG_DIR)
 {
  if(SAM == IMMEDIATE || SAM == DATA_REG_DIR)
   timestamp += 4;
  else
   timestamp += 2;
 }

 CalcZN<T>(result);
 SetC(false);
 SetV(false);

 dst.write(result);
}


//
// EOR
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::EOR(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 T const src_data = src.read();
 T const dst_data = dst.read();
 T const result = dst_data ^ src_data;

 if(sizeof(T) == 4 && DAM == DATA_REG_DIR)
 {
  if(SAM == IMMEDIATE || SAM == DATA_REG_DIR)
   timestamp += 4;
  else
   timestamp += 2;
 }

 CalcZN<T>(result);
 SetC(false);
 SetV(false);

 dst.write(result);
}


//
// AND
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::AND(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 T const src_data = src.read();
 T const dst_data = dst.read();
 T const result = dst_data & src_data;

 if(sizeof(T) == 4 && DAM == DATA_REG_DIR)
 {
  if(SAM == IMMEDIATE || SAM == DATA_REG_DIR)
   timestamp += 4;
  else
   timestamp += 2;
 }

 CalcZN<T>(result);
 SetC(false);
 SetV(false);

 dst.write(result);
}


//
// ORI CCR
//
INLINE void M68K::ORI_CCR(void)
{
 const uint8 imm = ReadOp();

 SetCCR(GetCCR() | imm);

 //
 //
 timestamp += 8;
 ReadOp();
 PC -= 2;
}


//
// ORI SR
//
INLINE void M68K::ORI_SR(void)
{
 const uint16 imm = ReadOp();

 SetSR(GetSR() | imm);

 //
 //
 timestamp += 8;
 ReadOp();
 PC -= 2;
}


//
// ANDI CCR
//
INLINE void M68K::ANDI_CCR(void)
{
 const uint8 imm = ReadOp();

 SetCCR(GetCCR() & imm);

 //
 //
 timestamp += 8;
 ReadOp();
 PC -= 2;
}


//
// ANDI SR
//
INLINE void M68K::ANDI_SR(void)
{
 const uint16 imm = ReadOp();

 SetSR(GetSR() & imm);

 //
 //
 timestamp += 8;
 ReadOp();
 PC -= 2;
}


//
// EORI CCR
//
INLINE void M68K::EORI_CCR(void)
{
 const uint8 imm = ReadOp();

 SetCCR(GetCCR() ^ imm);

 //
 //
 timestamp += 8;
 ReadOp();
 PC -= 2;
}


//
// EORI SR
//
INLINE void M68K::EORI_SR(void)
{
 const uint16 imm = ReadOp();

 SetSR(GetSR() ^ imm);

 //
 //
 timestamp += 8;
 ReadOp();
 PC -= 2;
}


//
// MULU
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::MULU(HAM<T, SAM> &src, const unsigned dr)
{
 // Doesn't affect X flag
 static_assert(sizeof(T) == 2, "Wrong type.");

 T const src_data = src.read();
 uint32 const result = (uint32)(uint16)D[dr] * (uint32)src_data;

 CalcZN<uint32>(result);
 SetC(false);
 SetV(false);

 D[dr] = result;
}


//
// MULS
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::MULS(HAM<T, SAM> &src, const unsigned dr)
{
 // Doesn't affect X flag
 static_assert(sizeof(T) == 2, "Wrong type.");

 T const src_data = src.read();
 uint32 const result = (int16)D[dr] * (int16)src_data;

 CalcZN<uint32>(result);
 SetC(false);
 SetV(false);

 D[dr] = result;
}


template<bool sdiv>
INLINE void M68K::Divide(uint16 divisor, const unsigned dr)
{
 uint32 dividend = D[dr];
 uint32 tmp;
 bool neg_quotient = false;
 bool neg_remainder = false;
 bool oflow = false;

 if(!divisor)
 {
  Exception(EXCEPTION_ZERO_DIVIDE, VECNUM_ZERO_DIVIDE);
  return;
 }

 if(sdiv)
 {
  neg_quotient = (dividend >> 31) ^ (divisor >> 15);
  if(dividend & 0x80000000)
  {
   dividend = -dividend;
   neg_remainder = true;
  }

  if(divisor & 0x8000)
   divisor = -divisor;
 }

 tmp = dividend;

 for(int i = 0; i < 16; i++)
 {
  bool lb = false;
  bool ob;

  if(tmp >= ((uint32)divisor << 15))
  {
   tmp -= divisor << 15;
   lb = true;
  }

  ob = tmp >> 31;
  tmp = (tmp << 1) | lb;

  if(ob)
  {
   oflow = true;
   //puts("OVERFLOW");
   //break;
  }
 }

 if(sdiv)
 {
  if((tmp & 0xFFFF) > (uint32)(0x7FFF + neg_quotient))
   oflow = true;
 }

 if((uint32)(tmp >> 16) >= divisor)
  oflow = true;

 if(sdiv && !oflow)
 {
  if(neg_quotient)
   tmp = ((-tmp) & 0xFFFF) | (tmp & 0xFFFF0000);

  if(neg_remainder)
   tmp = (((-(tmp >> 16)) << 16) & 0xFFFF0000) | (tmp & 0xFFFF);
 }

 //
 // Doesn't affect X flag
 //
 CalcZN<uint16>(tmp);
 SetC(false);
 SetV(oflow);

 if(!oflow)
  D[dr] = tmp;
}


//
// DIVU
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::DIVU(HAM<T, SAM> &src, const unsigned dr)
{
 static_assert(sizeof(T) == 2, "Wrong type.");

 T const src_data = src.read();

 Divide<false>(src_data, dr);
}


//
// DIVS
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::DIVS(HAM<T, SAM> &src, const unsigned dr)
{
 // Doesn't affect X flag
 static_assert(sizeof(T) == 2, "Wrong type.");

 T const src_data = src.read();

 Divide<true>(src_data, dr);
}


//
// ABCD
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::ABCD(HAM<T, SAM> &src, HAM<T, DAM> &dst)	// ...XYZ, now I know my ABCs~
{
 static_assert(sizeof(T) == 1, "Wrong size.");

 bool V = false;
 uint8 const src_data = src.read();
 uint8 const dst_data = dst.read();
 uint32 tmp;

 tmp = dst_data + src_data + GetX();

 if(((dst_data ^ src_data ^ tmp) & 0x10) || (tmp & 0xF) >= 0x0A)
 {
  uint8 prev_tmp = tmp;
  tmp += 0x06;
  V |= ((~prev_tmp & 0x80) & (tmp & 0x80));
 }

 if(tmp >= 0xA0)
 {
  uint8 prev_tmp = tmp;
  tmp += 0x60;
  V |= ((~prev_tmp & 0x80) & (tmp & 0x80));
 }

 CalcZN<uint8, true>(tmp);
 SetCX((bool)(tmp >> 8));
 SetV(V);

 if(DAM == DATA_REG_DIR)
  timestamp += 2;
 else
  timestamp += 4;

 dst.write(tmp);
}


INLINE uint8 M68K::DecimalSubtractX(const uint8 src_data, const uint8 dst_data)
{
 bool V = false;
 uint32 tmp;

 tmp = dst_data - src_data - GetX();

 const bool adj0 = ((dst_data ^ src_data ^ tmp) & 0x10);
 const bool adj1 = (tmp & 0x100);

 if(adj0)
 {
  uint8 prev_tmp = tmp;
  tmp -= 0x06;
  V |= (prev_tmp & 0x80) & (~tmp & 0x80);
 }

 if(adj1)
 {
  uint8 prev_tmp = tmp;
  tmp -= 0x60;
  V |= (prev_tmp & 0x80) & (~tmp & 0x80);
 }

 SetV(V);
 CalcZN<uint8, true>(tmp);
 SetCX((bool)(tmp >> 8));

 return tmp;
}

//
// SBCD
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::SBCD(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 static_assert(sizeof(T) == 1, "Wrong size.");
 uint8 const src_data = src.read();
 uint8 const dst_data = dst.read();

 if(DAM == DATA_REG_DIR)
  timestamp += 2;
 else
  timestamp += 4;

 dst.write(DecimalSubtractX(src_data, dst_data));
}


//
// NBCD
//
template<typename T, M68K::AddressMode DAM>
INLINE void M68K::NBCD(HAM<T, DAM> &dst)
{
 static_assert(sizeof(T) == 1, "Wrong size.");
 uint8 const dst_data = dst.read();

 timestamp += 2;

 dst.write(DecimalSubtractX(dst_data, 0));
}

//
// MOVEP
//
template<typename T, bool reg_to_mem>
INLINE void M68K::MOVEP(const unsigned ar, const unsigned dr)
{
 const int16 ext = ReadOp();
 uint32 ea = A[ar] + (int16)ext;
 unsigned shift = (sizeof(T) - 1) << 3;

 for(unsigned i = 0; i < sizeof(T); i++)
 {
  if(reg_to_mem)
   Write<uint8>(ea, D[dr] >> shift);
  else
  {
   D[dr] &= ~(0xFF << shift);
   D[dr] |= Read<uint8>(ea) << shift;
  }
  ea += 2;
  shift -= 8;
 }
}


template<typename T, M68K::AddressMode TAM>
INLINE void M68K::BTST(HAM<T, TAM> &targ, unsigned wb)
{
 T const src_data = targ.read();
 wb &= (sizeof(T) << 3) - 1;

 SetZ(((src_data >> wb) & 1) == 0);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::BCHG(HAM<T, TAM> &targ, unsigned wb)
{
 T const src_data = targ.read();
 wb &= (sizeof(T) << 3) - 1;

 SetZ(((src_data >> wb) & 1) == 0);

 targ.write(src_data ^ (1U << wb));
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::BCLR(HAM<T, TAM> &targ, unsigned wb)
{
 T const src_data = targ.read();
 wb &= (sizeof(T) << 3) - 1;

 SetZ(((src_data >> wb) & 1) == 0);

 targ.write(src_data & ~(1U << wb));
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::BSET(HAM<T, TAM> &targ, unsigned wb)
{
 T const src_data = targ.read();
 wb &= (sizeof(T) << 3) - 1;

 SetZ(((src_data >> wb) & 1) == 0);

 targ.write(src_data | (1U << wb));
}



//
// MOVE
//
template<typename T, M68K::AddressMode SAM, M68K::AddressMode DAM>
INLINE void M68K::MOVE(HAM<T, SAM> &src, HAM<T, DAM> &dst)
{
 T const tmp = src.read();

 if(DAM != ADDR_REG_DIR)
 {
  CalcZN<T>(tmp);
  SetV(false);
  SetC(false);
 }

 dst.write(tmp);
}

template<typename T, M68K::AddressMode SAM>
INLINE void M68K::MOVEA(HAM<T, SAM> &src, const unsigned ar)
{
 uint32 const src_data = static_cast<typename std::make_signed<T>::type>(src.read());

 A[ar] = src_data;
}


//
// MOVEM to memory
//
template<bool pseudo_predec, typename T, M68K::AddressMode DAM>
INLINE void M68K::MOVEM_to_MEM(const uint16 reglist, HAM<T, DAM> &dst)
{
 static_assert(DAM != ADDR_REG_INDIR_PRE && DAM != ADDR_REG_INDIR_POST, "Wrong address mode.");
 static_assert(!pseudo_predec || DAM == ADDR_REG_INDIR, "Wrong address mode.");

 uint32 ea = dst.getea();

 for(unsigned i = 0; i < 16; i++)
 {
  if(reglist & (1U << i))
  {
   if(pseudo_predec)
    ea -= sizeof(T);

   Write<T, pseudo_predec>(ea, DA[(pseudo_predec ? (15 - i) : i)]);

   if(!pseudo_predec)
    ea += sizeof(T);
  }
 }

 if(pseudo_predec)
  A[dst.reg] = ea;
}


//
// MOVEM to regs(from memory)
//
template<bool pseudo_postinc, typename T, M68K::AddressMode SAM>
INLINE void M68K::MOVEM_to_REGS(HAM<T, SAM> &src, const uint16 reglist)
{
 static_assert(SAM != ADDR_REG_INDIR_PRE && SAM != ADDR_REG_INDIR_POST, "Wrong address mode.");
 static_assert(!pseudo_postinc || SAM == ADDR_REG_INDIR, "Wrong address mode.");

 uint32 ea = src.getea();

 for(unsigned i = 0; i < 16; i++)
 {
  if(reglist & (1U << i))
  {
   T tmp = Read<T>(ea);

   DA[i] = static_cast<typename std::make_signed<T>::type>(tmp);

   ea += sizeof(T);
  }
 }

 Read<uint16>(ea);	// or should be <T> ?

 if(pseudo_postinc)
  A[src.reg] = ea;
}


template<typename T, M68K::AddressMode TAM, bool Arithmetic, bool ShiftLeft>
INLINE void M68K::ShiftBase(HAM<T, TAM> &targ, unsigned count)
{
 T vchange = 0;
 T result = targ.read();
 count &= 0x3F;

 if(TAM == DATA_REG_DIR)
  timestamp += (sizeof(T) == 4) ? 4 : 2;

 if(count == 0)
 {
  // X is unaffected with a shift count of 0!
  SetC(false);
 }
 else
 {
  bool shifted_out = false;

  do
  {
   if(TAM == DATA_REG_DIR)
    timestamp += 2;

   if(ShiftLeft)
    shifted_out = (result >> (sizeof(T) * 8 - 1)) & 1;
   else
    shifted_out = result & 1;

   if(Arithmetic)
   {
    const T prev = result;

    if(ShiftLeft)
     result = result << 1;
    else
     result = static_cast<typename std::make_signed<T>::type>(result) >> 1;

    vchange |= prev ^ result;
   }
   else
   {
    if(ShiftLeft)
     result = result << 1;
    else
     result = result >> 1;
   }
  } while(--count != 0);

  SetCX(shifted_out);
 }

 CalcZN<T>(result);

 if(Arithmetic)
  SetV((vchange >> (sizeof(T) * 8 - 1)) & 1);
 else
  SetV(false);

 targ.write(result);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::ASL(HAM<T, TAM> &targ, unsigned count)
{
 ShiftBase<T, TAM, true, true>(targ, count);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::ASR(HAM<T, TAM> &targ, unsigned count)
{
 ShiftBase<T, TAM, true, false>(targ, count);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::LSL(HAM<T, TAM> &targ, unsigned count)
{
 ShiftBase<T, TAM, false, true>(targ, count);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::LSR(HAM<T, TAM> &targ, unsigned count)
{
 ShiftBase<T, TAM, false, false>(targ, count);
}

template<typename T, M68K::AddressMode TAM, bool X_Form, bool ShiftLeft>
INLINE void M68K::RotateBase(HAM<T, TAM> &targ, unsigned count)
{
 T result = targ.read();
 count &= 0x3F;

 if(TAM == DATA_REG_DIR)
  timestamp += (sizeof(T) == 4) ? 4 : 2;

 if(count == 0)
 {
  if(X_Form)
   SetC(GetX());
  else
   SetC(false);
 }
 else
 {
  bool shifted_out = GetX();

  do
  {
   const bool shift_in = shifted_out;

   if(TAM == DATA_REG_DIR)
    timestamp += 2;

   if(ShiftLeft)
   {
    shifted_out = (result >> (sizeof(T) * 8 - 1)) & 1;
    result <<= 1;
    result |= (X_Form ? shift_in : shifted_out);
   }
   else
   {
    shifted_out = (result & 1);
    result >>= 1;
    result |= (T)(X_Form ? shift_in : shifted_out) << (sizeof(T) * 8 - 1);
   }
  } while(--count != 0);

  SetC(shifted_out);
  if(X_Form)
   SetX(shifted_out);
 }

 CalcZN<T>(result);
 SetV(false);

 targ.write(result);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::ROL(HAM<T, TAM> &targ, unsigned count)
{
 RotateBase<T, TAM, false, true>(targ, count);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::ROR(HAM<T, TAM> &targ, unsigned count)
{
 RotateBase<T, TAM, false, false>(targ, count);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::ROXL(HAM<T, TAM> &targ, unsigned count)
{
 RotateBase<T, TAM, true, true>(targ, count);
}

template<typename T, M68K::AddressMode TAM>
INLINE void M68K::ROXR(HAM<T, TAM> &targ, unsigned count)
{
 RotateBase<T, TAM, true, false>(targ, count);
}

//
// TAS
//
static MDFN_FASTCALL uint8 TAS_Callback(M68K* zptr, uint8 data)
{
 zptr->CalcZN<uint8>(data);
 zptr->SetC(false);
 zptr->SetV(false);

 data |= 0x80;
 return data;
}

template<typename T, M68K::AddressMode DAM>
INLINE void M68K::TAS(HAM<T, DAM> &dst)
{
 static_assert(std::is_same<T, uint8>::value, "Wrong type");

 dst.rmw(TAS_Callback);
}

//
// TST
//
template<typename T, M68K::AddressMode DAM>
INLINE void M68K::TST(HAM<T, DAM> &dst)
{
 T const dst_data = dst.read();

 CalcZN<T>(dst_data);

 SetC(false);
 SetV(false);
}


//
// CLR
//
template<typename T, M68K::AddressMode DAM>
INLINE void M68K::CLR(HAM<T, DAM> &dst)
{
 dst.read();

 if(sizeof(T) == 4 && DAM == DATA_REG_DIR)
  timestamp += 2;

 SetZ(true);
 SetN(false);

 SetC(false);
 SetV(false);

 dst.write(0);
}

//
// NOT
//
template<typename T, M68K::AddressMode DAM>
INLINE void M68K::NOT(HAM<T, DAM> &dst)
{
 T result = dst.read();

 if(sizeof(T) == 4 && DAM == DATA_REG_DIR)
  timestamp += 2;

 result = ~result;

 CalcZN<T>(result);
 SetC(false);
 SetV(false);

 dst.write(result);
}


//
// EXT
//
template<typename T, M68K::AddressMode DAM>
INLINE void M68K::EXT(HAM<T, DAM> &dst)
{
 static_assert(std::is_same<T, uint16>::value || std::is_same<T, uint32>::value, "Wrong type");
 T result = dst.read();

 if(std::is_same<T, uint16>::value)
  result = (int8)result;
 else
  result = (int16)result;

 CalcZN<T>(result);
 SetC(false);
 SetV(false);

 dst.write(result);
}

//
// SWAP
//
INLINE void M68K::SWAP(const unsigned dr)
{
 D[dr] = (D[dr] << 16) | (D[dr] >> 16);

 CalcZN<uint32>(D[dr]);
 SetC(false);
 SetV(false);
}


//
// EXG (doesn't affect flags)
//
INLINE void M68K::EXG(uint32* a, uint32* b)
{
 timestamp += 2;

 std::swap(*a, *b); 
}

//
//
//

template<unsigned cc>
INLINE bool M68K::TestCond(void)
{
 static_assert(cc < 0x10, "Invalid CC");

 switch(cc)
 {
  case 0x00:	// TRUE
	return true;

  case 0x01:	// FALSE
	return false;

  case 0x02:	// HI
	return !GetC() && !GetZ();

  case 0x03:	// LS
	return GetC() || GetZ();

  case 0x04:	// CC/HS
	return !GetC();

  case 0x05:	// CS/LO
	return GetC();

  case 0x06:	// NE
	return !GetZ();

  case 0x07:	// EQ
	return GetZ();

  case 0x08:	// VC
	return !GetV();

  case 0x09:	// VS
	return GetV();

  case 0x0A:	// PL
	return !GetN();

  case 0x0B:	// MI
	return GetN();

  case 0x0C:	// GE
	return GetN() == GetV();

  case 0x0D:	// LT
	return GetN() != GetV();

  case 0x0E:	// GT
	return GetN() == GetV() && !GetZ();

  case 0x0F:	// LE
	return GetN() != GetV() || GetZ();
 }
}

//
// Bcc, BRA, BSR
//
//  (caller of this function should sign-extend the 8-bit displacement)
//
template<unsigned cc>
INLINE void M68K::Bxx(uint32 disp)
{
 const uint32 BPC = PC;

 if(TestCond<(cc == 0x01) ? 0x00 : cc>())
 {
  const uint16 disp16 = (int16)ReadOp();

  if(!disp)
   disp = (int16)disp16;
  else
   PC -= 2;

  if(cc == 0x01)
   Push<uint32>(PC);

  timestamp += 2;
  PC = BPC + disp;
 }
 else
 {
  if(!disp)
   ReadOp();

  timestamp += 4;
 }
}

template<unsigned cc>
INLINE void M68K::DBcc(const unsigned dr)
{
 const uint32 BPC = PC;
 uint32 disp;

 disp = (int16)ReadOp();

 if(!TestCond<cc>())
 {
  const uint16 result = D[dr] - 1;

  timestamp += 2;
  D[dr] = (D[dr] & 0xFFFF0000) | result;

  if(result != 0xFFFF)
   PC = BPC + disp;
  else
   timestamp += 4;
 }
 else
  timestamp += 4;
}


//
// Scc
//
template<unsigned cc, typename T, M68K::AddressMode DAM>
INLINE void M68K::Scc(HAM<T, DAM> &dst)
{
 static_assert(std::is_same<T, uint8>::value, "Wrong type");

 T const result = TestCond<cc>() ? ~(T)0 : 0;

 if(DAM == DATA_REG_DIR && result)
  timestamp += 2;

 dst.write(result);
}


//
// JSR
//
template<typename T, M68K::AddressMode TAM>
INLINE void M68K::JSR(HAM<T, TAM> &targ)
{
 Push<uint32>(PC);
 targ.jump();
}


//
// JMP
//
template<typename T, M68K::AddressMode TAM>
INLINE void M68K::JMP(HAM<T, TAM> &targ)
{
 targ.jump();
}


//
// MOVE from SR
//
template <typename T, M68K::AddressMode DAM>
INLINE void M68K::MOVE_from_SR(HAM<T, DAM> &dst)
{
 static_assert(std::is_same<T, uint16>::value, "Wrong type");

 dst.read();

 if(DAM == DATA_REG_DIR)
  timestamp += 2;

 dst.write(GetSR());
}


//
// MOVE to CCR
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::MOVE_to_CCR(HAM<T, SAM> &src)
{
 static_assert(std::is_same<T, uint16>::value, "Wrong type");

 SetCCR(src.read());

 timestamp += 8;
}

//
// MOVE to SR
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::MOVE_to_SR(HAM<T, SAM> &src)
{
 static_assert(std::is_same<T, uint16>::value, "Wrong type");

 SetSR(src.read());

 timestamp += 8;
}


//
// MOVE to/from USP
//
template<bool direction>
INLINE void M68K::MOVE_USP(const unsigned ar)
{
 if(!direction)
  SP_Inactive = A[ar];
 else
  A[ar] = SP_Inactive;
}


//
// LEA
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::LEA(HAM<T, SAM> &src, const unsigned ar)
{
 const uint32 ea = src.getea();

 A[ar] = ea;
}


//
// PEA
//
template<typename T, M68K::AddressMode SAM>
INLINE void M68K::PEA(HAM<T, SAM> &src)
{
 const uint32 ea = src.getea();

 Push<uint32>(ea);
}

//
// UNLK
//
INLINE void M68K::UNLK(const unsigned ar)
{
 A[7] = A[ar];
 A[ar] = Pull<uint32>();
}


//
// LINK
//
INLINE void M68K::LINK(const unsigned ar)
{
 const uint32 disp = (int16)ReadOp();

 Push<uint32>(A[ar]);
 A[ar] = A[7];
 A[7] += disp;
}





//
// RTE
//
INLINE void M68K::RTE(void)
{
 uint16 new_SR;

 new_SR = Pull<uint16>();
 PC = Pull<uint32>();

 SetSR(new_SR);
}


//
// RTR
//
INLINE void M68K::RTR(void)
{
 SetCCR(Pull<uint16>());
 PC = Pull<uint32>();
}


//
// RTS
//
INLINE void M68K::RTS(void)
{
 PC = Pull<uint32>();
}


//
// TRAP
//
INLINE void M68K::TRAP(const unsigned vf)
{
 Exception(EXCEPTION_TRAP, VECNUM_TRAP_BASE + vf);
}


//
// TRAPV
//
INLINE void M68K::TRAPV(void)
{
 if(GetV())
  Exception(EXCEPTION_TRAPV, VECNUM_TRAPV);
}


//
// ILLEGAL
//
INLINE void M68K::ILLEGAL(const uint16 instr)
{
 //printf("ILLEGAL: %04x\n", instr);

 PC -= 2;
 Exception(EXCEPTION_ILLEGAL, VECNUM_ILLEGAL);
}


INLINE void M68K::LINEA(void)
{
 PC -= 2;
 Exception(EXCEPTION_ILLEGAL, VECNUM_LINEA);
}

INLINE void M68K::LINEF(void)
{
 PC -= 2;
 Exception(EXCEPTION_ILLEGAL, VECNUM_LINEF);
}


//
// NOP
//
INLINE void M68K::NOP(void)
{

}


//
// RESET
//
INLINE void M68K::RESET(void)
{
 timestamp += 2;
 //
 BusRESET(true);
 timestamp += 124;
 BusRESET(false);
 //
 timestamp += 2;
}


//
// STOP
//
INLINE void M68K::STOP(void)
{
 uint16 new_SR = ReadOp();

 SetSR(new_SR);
 XPending |= XPENDING_MASK_STOPPED;
}


INLINE bool M68K::CheckPrivilege(void)
{
 if(MDFN_UNLIKELY(!GetSVisor()))
 {
  PC -= 2;
  Exception(EXCEPTION_PRIVILEGE, VECNUM_PRIVILEGE);
  return false;
 }

 return true;
}

//
//
INLINE void M68K::InternalStep(void)
{
 if(MDFN_UNLIKELY(XPending))
 {
  if(MDFN_LIKELY(!(XPending & XPENDING_MASK_EXTHALTED)))
  {
   if(MDFN_UNLIKELY(XPending & XPENDING_MASK_RESET))
   {
    XPending &= ~XPENDING_MASK_RESET;

    SetSVisor(true);
    SetTrace(false);
    SetIMask(0x7);

    A[7] = Read<uint32>(VECNUM_RESET_SSP << 2);
    PC = Read<uint32>(VECNUM_RESET_PC << 2);

    return;
   }
   else if(XPending & (XPENDING_MASK_INT | XPENDING_MASK_NMI))
   {
    assert(IPL == 0x7 || IPL > ((GetSR() >> 8) & 0x7));
    XPending &= ~(XPENDING_MASK_STOPPED | XPENDING_MASK_INT | XPENDING_MASK_NMI);

    Exception(EXCEPTION_INT, VECNUM_INT_BASE);

    return;
   }
  }

  // STOP and ExtHalted fallthrough:
  timestamp += 4;
  return;
 }
 //
 //
 //
 uint16 instr = ReadOp();
 const unsigned instr_b11_b9 = (instr >> 9) & 0x7;
 const unsigned instr_b2_b0 = instr & 0x7;

#if 0
  printf("PC=%08x: %04x ---", PC - 2, instr);

  for(unsigned i = 0; i < 8; i++)
   printf(" A%u=0x%08x", i, A[i]);
 
  for(unsigned i = 0; i < 8; i++)
   printf(" D%u=0x%08x", i, D[i]);

  printf("\n");
#endif
 switch(instr)
 {
  default: ILLEGAL(instr); break;
  #include "m68k_instr.inc"
 }
}


void NO_INLINE M68K::Run(int32 run_until_time)
{
 while(MDFN_LIKELY(timestamp < run_until_time))
  InternalStep();
}

void NO_INLINE M68K::Step(void)
{
 //printf("%08x\n", PC);
 InternalStep();
}

//
// Reset() may be called from BusRESET, which is called from RESET, so ensure it continues working for that case.
//
void M68K::Reset(bool powering_up)
{
 if(powering_up)
 {
  for(unsigned i = 0; i < 8; i++)
   D[i] = 0;

  for(unsigned i = 0; i < 8; i++)
   A[i] = 0;

  SP_Inactive = 0;

  SetSR(0);
 }
 XPending = (XPending & ~XPENDING_MASK_STOPPED) | XPENDING_MASK_RESET;
}


//
//
//
uint32 M68K::GetRegister(unsigned which, char* special, const uint32 special_len)
{
 switch(which)
 {
  default:
	return 0xDEADBEEF;

  case GSREG_D0: case GSREG_D1: case GSREG_D2: case GSREG_D3:
  case GSREG_D4: case GSREG_D5: case GSREG_D6: case GSREG_D7:
	return D[which - GSREG_D0];

  case GSREG_A0: case GSREG_A1: case GSREG_A2: case GSREG_A3:
  case GSREG_A4: case GSREG_A5: case GSREG_A6: case GSREG_A7:
	return A[which - GSREG_A0];

  case GSREG_PC:
	return PC;

  case GSREG_SR:
	return GetSR();

  case GSREG_SSP:
	if(GetSVisor())
	 return A[7];
	else
	 return SP_Inactive;

  case GSREG_USP:
	if(!GetSVisor())
	 return A[7];
	else
	 return SP_Inactive;
 }
}

void M68K::SetRegister(unsigned which, uint32 value)
{
 switch(which)
 {
  case GSREG_D0: case GSREG_D1: case GSREG_D2: case GSREG_D3:
  case GSREG_D4: case GSREG_D5: case GSREG_D6: case GSREG_D7:
	D[which - GSREG_D0] = value;
	break;

  case GSREG_A0: case GSREG_A1: case GSREG_A2: case GSREG_A3:
  case GSREG_A4: case GSREG_A5: case GSREG_A6: case GSREG_A7:
	A[which - GSREG_A0] = value;
	break;

  case GSREG_PC:
	PC = value;
	break;

  case GSREG_SR:
	SetSR(value);
	break;

  case GSREG_SSP:
	if(GetSVisor())
	 A[7] = value;
	else
	 SP_Inactive = value;
	break;

  case GSREG_USP:
	if(!GetSVisor())
	 A[7] = value;
	else
	 SP_Inactive = value;
	break;
 }
}

