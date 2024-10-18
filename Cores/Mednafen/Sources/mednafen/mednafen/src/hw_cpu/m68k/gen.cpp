/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* gen.cpp - Table Generator for Motorola 68000 CPU Emulator
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

// g++ -std=gnu++14 -Wall -O2 -o gen gen.cpp && ./gen > m68k_instr.inc
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <assert.h>

#include <string>
#include <map>
#include <list>
#include <vector>

static std::string s(const char* format, ...)
{
 static char buf[65536];
 va_list ap;
 
 va_start(ap, format);
 vsnprintf(buf, sizeof(buf), format, ap);
 va_end(ap);

 return std::string(buf);
}

/*
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
*/
enum
{
 AMA_DATA	= 0x0001,
 AMA_MEMORY	= 0x0002,
 AMA_CONTROL    = 0x0004,
 AMA_ALTERABLE	= 0x0008,
};

static const char* bsize_to_type(unsigned size)
{
 if(size == 0)
  return "std::tuple<>";

 if(size == 1)
  return "uint8";
  
 if(size == 2)
  return "uint16"; 
  
 if(size == 4)
  return "uint32";

 return NULL;
}

template<bool move_dest = false>
bool decode_ea(unsigned allowed, int size, unsigned instr, const char* ham_name, std::string* ham_out)
{
 const unsigned mode = (instr >> (move_dest ? 6 : 3)) & 0x7;
 const unsigned reg =  (instr >> (move_dest ? 9 : 0)) & 0x7;
 
 if(size == -1)
 {
  if(mode == 0)
   size = 4;
  else
   size = 1;
 }

 if((size != 0 && size != 1 && size != 2 && size != 4) || (size == 0 && allowed != AMA_CONTROL))
  return false;

 static const struct
 {
  const char* name;
  unsigned flags;
 } ams[2][0x8] =
 {
  {
   { "DATA_REG_DIR",		AMA_DATA | AMA_ALTERABLE },
   { "ADDR_REG_DIR", 		AMA_ALTERABLE },
   { "ADDR_REG_INDIR",		AMA_DATA | AMA_MEMORY | AMA_ALTERABLE | AMA_CONTROL  },
   { "ADDR_REG_INDIR_POST",	AMA_DATA | AMA_MEMORY | AMA_ALTERABLE },
   { "ADDR_REG_INDIR_PRE",	AMA_DATA | AMA_MEMORY | AMA_ALTERABLE },
   { "ADDR_REG_INDIR_DISP",	AMA_DATA | AMA_MEMORY | AMA_ALTERABLE | AMA_CONTROL  },
   { "ADDR_REG_INDIR_INDX",	AMA_DATA | AMA_MEMORY | AMA_ALTERABLE | AMA_CONTROL  },
   { NULL, 0 },
  },
  {
   { "ABS_SHORT",	AMA_DATA | AMA_MEMORY | AMA_ALTERABLE | AMA_CONTROL  },
   { "ABS_LONG",	AMA_DATA | AMA_MEMORY | AMA_ALTERABLE | AMA_CONTROL  },
   { "PC_DISP",		AMA_DATA | AMA_MEMORY | AMA_CONTROL },
   { "PC_INDEX",	AMA_DATA | AMA_MEMORY | AMA_CONTROL },
   { "IMMEDIATE",	AMA_DATA | AMA_MEMORY },
   { NULL, 0 },
   { NULL, 0 },
   { NULL, 0 },
  }
 };

 auto const* const am = &ams[mode == 0x7][(mode == 0x7) ? reg : mode];
 
 if((am->flags & allowed) != allowed)
  return false;

 if(mode == 0x1 && size == 1)
  return false;

 if(mode < 0x7)
 {
  *ham_out += s("HAM<%s, %s> %s(this, %s)", bsize_to_type(size), am->name, ham_name, (move_dest ? "instr_b11_b9" : "instr_b2_b0"));

  return true;
 }
 else if(am->name)
 {
  *ham_out += s("HAM<%s, %s> %s(this)", bsize_to_type(size), am->name, ham_name);

  return true;
 }

 return false;
}

static void PrivilegeWrap(std::string *str, bool mfsr = false)
{
 if(mfsr)
  *str = s("if(!Revision_E || CheckPrivilege()) { %s }", str->c_str());
 else
  *str = s("if(CheckPrivilege()) { %s }", str->c_str());
}

static const char* size_names[4] = { "uint8", "uint16", "uint32", NULL };

//
// Bit manipulation, MOVEP, immediate
//
static std::string Instr0(const unsigned i)
{
 std::string ret;

 if(i & 0x100)
 {
  // MOVEP
  if((i & 0x38) == 0x08)
  {
   assert(ret.size() == 0);
   const char* sn = (i & 0x40) ? "uint32" : "uint16";

   ret += s("MOVEP<%s, %s>(instr_b2_b0, instr_b11_b9);", sn, (i & 0x80) ? "true" : "false");
  } 
 }
 else
 {
  static const char* op_names[8] = { "OR", "AND", "SUB", "ADD", NULL, "EOR", "CMP", NULL };
  const unsigned opi = (i >> 9) & 0x7;
  const unsigned szi = (i >> 6) & 0x3;

  std::string tmp;

  if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1 << szi, i, "dst", &tmp))
  {   
   if(op_names[opi] && size_names[szi])
   {
    assert(ret.size() == 0);
    ret += s("HAM<%s, IMMEDIATE> src(this); %s; %s(src, dst);", size_names[szi], tmp.c_str(), op_names[opi]); //, size_names[szi]);
   }
  }
  //        FEDCBA9876543210       FEDCBA9876543210
  if((i & 0b1111111110111111) == 0b0000000000111100)
  {
   assert(ret.size() == 0);
   ret += s("ORI_%s();", (i & 0x40) ? "SR" : "CCR" );
   if(i & 0x40)
    PrivilegeWrap(&ret);
  }

  //        FEDCBA9876543210       FEDCBA9876543210
  if((i & 0b1111111110111111) == 0b0000001000111100)
  {
   assert(ret.size() == 0);
   ret += s("ANDI_%s();", (i & 0x40) ? "SR" : "CCR" );
   if(i & 0x40)
    PrivilegeWrap(&ret);
  }

  //        FEDCBA9876543210       FEDCBA9876543210
  if((i & 0b1111111110111111) == 0b0000101000111100)
  {
   assert(ret.size() == 0);
   ret += s("EORI_%s();", (i & 0x40) ? "SR" : "CCR" );
   if(i & 0x40)
    PrivilegeWrap(&ret);
  }
 }


 // bit
 {
  static const char* op_names[4] = { "BTST", "BCHG", "BCLR", "BSET" };
  const unsigned type = (i >> 6) & 0x3;
  const unsigned allowed = AMA_DATA | ((type == 0) ? 0 : AMA_ALTERABLE);
  std::string tmp;

  if(decode_ea(allowed, -1, i, "targ", &tmp))
  {
   if(i & 0x100)	// Dynamic
   {
    assert(ret.size() == 0);
    ret += s("%s; %s(targ, D[instr_b11_b9]);", tmp.c_str(), op_names[type]);
   }
   else if(((i >> 9) & 0x7) == 0x4 && ((i & 0x3F) != 0x3C))	// Static
   {
    //printf("%04x -- %s\n", i, ret.c_str());
    assert(ret.size() == 0);
    ret += s("unsigned wb = ReadOp(); %s; %s(targ, wb);", tmp.c_str(), op_names[type]);
   }
  }
 }

 return ret;
}


//
// MOVEB
//
static std::string Instr1(const unsigned i)
{
 std::string ret;
 std::string src_tmp;
 std::string dst_tmp;

 if(decode_ea(AMA_DATA, 1, i, "src", &src_tmp) && decode_ea<true>(AMA_DATA | AMA_ALTERABLE, 1, i, "dst", &dst_tmp))
 {
  ret += s("%s; %s; MOVE(src, dst);", src_tmp.c_str(), dst_tmp.c_str());
 }

 return ret;
}

//
// MOVEL MOVEW
//
static std::string Instr23(const unsigned i)
{
 std::string ret;
 std::string src_tmp;
 std::string dst_tmp;
 const unsigned size = ((i >> 12) == 0x2) ? 4 : 2;

 if(decode_ea(0, size, i, "src", &src_tmp))
 {
  if(decode_ea<true>(AMA_DATA | AMA_ALTERABLE, size, i, "dst", &dst_tmp))
  {
   ret += s("%s; %s; MOVE(src, dst);", src_tmp.c_str(), dst_tmp.c_str());
  }
  else if(((i >> 6) & 0x7) == 0x1)
  {
   ret += s("%s; MOVEA(src, instr_b11_b9);", src_tmp.c_str());
  }
 }
 return ret;
}

template<bool AllowA = false, bool AllowX = false, bool AllowASource = true, bool AllowToDR = false>
static std::string form_dar_opm_ea(const unsigned i, const char* name)
{
 std::string ret;
 const unsigned opm = (i >> 6) & 0x7;
 unsigned szi;
 bool to_mem;
 bool is_a = false;

 if(opm == 0x3 || opm == 0x7)
 {
  to_mem = false;
  szi = (opm & 0x4) ? 2 : 1;
  is_a = true;

  if(!AllowA)
   return "";
 }
 else
 {
  to_mem = (bool)(opm & 0x4);
  szi = opm & 0x3;
 }

 std::string tmp_ea, tmp_reg;
 unsigned allowed;

 if(to_mem)
 {
  if(AllowToDR)
   allowed = AMA_DATA | AMA_ALTERABLE;
  else
   allowed = AMA_MEMORY | AMA_ALTERABLE;
 }
 else
 {
  if(AllowASource)
   allowed = 0;
  else
   allowed = AMA_DATA;
 }

 if(decode_ea(allowed, 1U << szi, i, to_mem ? "dst" : "src", &tmp_ea))
 {
  tmp_ea += "; ";
  tmp_reg = s("HAM<%s, %s> %s\(this, instr_b11_b9); ", is_a ? "uint32" : size_names[szi], is_a ? "ADDR_REG_DIR" : "DATA_REG_DIR", to_mem ? "src" : "dst");

  if(to_mem)
   ret += tmp_reg + tmp_ea;
  else
   ret += tmp_ea + tmp_reg;

  ret += s("%s(src, dst);", name);
 }
 else if(AllowX && ((i >> 8) & 0x1) == 0x1 && ((i >> 4) & 0x3) == 0x0)
 {
  const bool rm = (i >> 3) & 1;
  const unsigned szi = (i >> 6) & 0x3;

  if(szi != 0x3)
  {
   if(rm) // address register, predecrement addressing mode
   {
    ret += s("HAM<%s, ADDR_REG_INDIR_PRE> src(this, instr_b2_b0); HAM<%s, ADDR_REG_INDIR_PRE> dst(this, instr_b11_b9); %sX(src, dst);", size_names[szi], size_names[szi], name);
   }
   else
   {
    ret += s("HAM<%s, DATA_REG_DIR> src(this, instr_b2_b0); HAM<%s, DATA_REG_DIR> dst(this, instr_b11_b9); %sX(src, dst);", size_names[szi], size_names[szi], name);
   }
  }
 }
 return ret;
}

static std::string form_destr_rm_srcr(const unsigned i, const char* name, const unsigned szi, const char* mem_am = "ADDR_REG_INDIR_PRE")
{
 const bool rm = (i >> 3) & 1;
 std::string ret;

 if(rm) // address register, predecrement addressing mode
  ret = s("HAM<%s, %s> src(this, instr_b2_b0); HAM<%s, %s> dst(this, instr_b11_b9); %s(src, dst);", size_names[szi], mem_am, size_names[szi], mem_am, name);
 else
  ret = s("HAM<%s, DATA_REG_DIR> src(this, instr_b2_b0); HAM<%s, DATA_REG_DIR> dst(this, instr_b11_b9); %s(src, dst);", size_names[szi], size_names[szi], name);

 return ret;
}

static std::string Instr4(const unsigned instr)
{
 std::string ret;
 std::string tmp;

 if(((instr >> 7) & 0x1F) == 0x1D && decode_ea(AMA_CONTROL, 0, instr, "targ", &tmp))
 {
  assert(ret.size() == 0);

  ret = s("%s; %s(targ);", tmp.c_str(), (instr & 0x40) ? "JMP" : "JSR");
 }

 if(((instr >> 7) & 0x7) == 0x1 && ((instr >> 11) & 0x1) == 0x1)
 {
  const bool dr = (instr >> 10) & 1;	// 0 = reg->mem, 1 = mem->reg
  const bool sz = (instr >> 6) & 1;	// 0 = word, 1 = long
  std::string rls = "const uint16 reglist = ReadOp()";
  unsigned instr_adj = instr;

  if(!dr)
  {
   bool pseudo_predec = false;
   if(((instr_adj >> 3) & 0x7) == 4)
   {
    instr_adj = (instr_adj &~ (0x7 << 3)) | (0x2 << 3);
    pseudo_predec = true;
   }

   if(decode_ea(AMA_CONTROL | AMA_ALTERABLE, 2 << sz, instr_adj, "dst", &tmp))
   {
    assert(ret.size() == 0);
    ret += s("%s; %s; MOVEM_to_MEM<%s>(reglist, dst);", rls.c_str(), tmp.c_str(), pseudo_predec ? "true" : "false");
   }
  }
  else
  {
   bool pseudo_postinc = false;

   if(((instr_adj >> 3) & 0x7) == 3)
   {
    instr_adj = (instr_adj &~ (0x7 << 3)) | (0x2 << 3);
    pseudo_postinc = true;
   }

   if(decode_ea(AMA_CONTROL, 2 << sz, instr_adj, "src", &tmp))
   {
    assert(ret.size() == 0);
    ret += s("%s; %s; MOVEM_to_REGS<%s>(src, reglist);", rls.c_str(), tmp.c_str(), pseudo_postinc ? "true" : "false");
   }
  }
 }


 if((instr & 0xF00) == 0x000)
 {
  const unsigned szi = (instr >> 6) & 0x3;

  if(szi == 0x3)
  {
   // MOVE from SR
   if(decode_ea(AMA_DATA | AMA_ALTERABLE, 2, instr, "dst", &tmp))
   {
    assert(ret.size() == 0);

    ret += s("%s; MOVE_from_SR(dst);", tmp.c_str());
    PrivilegeWrap(&ret, true);
   }
  }
  else
  {
   // NEGX
   if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1U << szi, instr, "dst", &tmp))
   {
    assert(ret.size() == 0);
 
    ret += s("%s; NEGX(dst);", tmp.c_str());
   }
  }
 }



 //
 //
 //
 {
  const unsigned type = (instr >> 6) & 0x7;

  if(type == 0x6)
  {
   // CHK
   if(decode_ea(AMA_DATA, 2, instr, "src", &tmp))
   {
    assert(ret.size() == 0);
    
    ret += s("%s; HAM<uint16, DATA_REG_DIR> dst(this, instr_b11_b9); CHK(src, dst);", tmp.c_str());
   }
  }
  else if(type == 0x7)
  {
   // LEA
   if(decode_ea(AMA_CONTROL, 0, instr, "src", &tmp))
   {
    assert(ret.size() == 0);

    ret += s("%s; LEA(src, instr_b11_b9);", tmp.c_str());
   }
  }
 }


 if((instr & 0xF00) == 0x200)
 {
  const unsigned szi = (instr >> 6) & 0x3;

  if(szi == 0x3)
  {

  }
  else
  {
   // CLR
   if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1U << szi, instr, "dst", &tmp))
   {
    assert(ret.size() == 0);
 
    ret += s("%s; CLR(dst);", tmp.c_str());
   }   
  }
 }

 if((instr & 0xD00) == 0x400)
 {
  const unsigned szi = (instr >> 6) & 0x3;

  if(szi == 0x3)
  {
   if(decode_ea(AMA_DATA, 2, instr, "src", &tmp))
   {
    assert(ret.size() == 0);

    if(instr & 0x200) // MOVE to SR
    {
     ret += s("%s; MOVE_to_SR(src);", tmp.c_str());
     PrivilegeWrap(&ret);
    }
    else // MOVE to CCR
     ret += s("%s; MOVE_to_CCR(src);", tmp.c_str());
   }
  }
  else
  {
   // NOT
   if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1U << szi, instr, "dst", &tmp))
   {
    assert(ret.size() == 0);
 
    if(instr & 0x200) // NOT
     ret += s("%s; NOT(dst);", tmp.c_str());
    else	// NEG
     ret += s("%s; NEG(dst);", tmp.c_str());
   }
  }
 }

 // NBCD
 if((instr & 0xFC0) == 0x800 && decode_ea(AMA_DATA | AMA_ALTERABLE, 1, instr, "dst", &tmp))
 {
  assert(ret.size() == 0);

  ret += s("%s; NBCD(dst);", tmp.c_str());
 }

 // SWAP
 if((instr & 0xFF8) == 0x840)
 {
  assert(ret.size() == 0);

  ret += s("SWAP(instr_b2_b0);");
 }

 // PEA
 if((instr & 0xFC0) == 0x840 && decode_ea(AMA_CONTROL, 0, instr, "src", &tmp))
 {
  assert(ret.size() == 0);

  ret += s("%s; PEA(src);", tmp.c_str());
 }

 // EXT
 if(((instr >> 9) & 0x7) == 0x4 && ((instr >> 3) & 0x7) == 0x0)
 {
  const unsigned type = (instr >> 6) & 0x7;

  if(type == 0x2 || type == 0x3)
  {
   assert(ret.size() == 0);

   ret = s("HAM<%s, DATA_REG_DIR> dst(this, instr_b2_b0); EXT(dst);", (type & 0x1) ? "uint32" : "uint16");
  }
 }


 // MOVEM EA to Regs
 // TODO!
 if((instr & 0xF80) == 0xC80)
 {
  //assert(ret.size() == 0);
 }

 // MOVEM regs to EA
 // TODO!
 if((instr & 0xF80) == 0x880)
 {
  //assert(ret.size() == 0);
 }

 if((instr & 0xF00) == 0xA00)
 {
  const unsigned szi = (instr >> 6) & 0x3;

  if(szi == 0x3)
  {
   // TAS
   if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1, instr, "dst", &tmp))
   {
    assert(ret.size() == 0);
    ret += s("%s; TAS(dst);", tmp.c_str());
   }
  }
  else
  {
   // TST
   if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1U << szi, instr, "dst", &tmp))
   {
    assert(ret.size() == 0);
    ret += s("%s; TST(dst);", tmp.c_str());
   }
  }
 }


 // TRAP
 if((instr & 0xFF0) == 0xE40)
 {
  assert(ret.size() == 0);
  ret += s("TRAP(instr & 0xF);");
 }

 // MOVE to/from USP
 if((instr & 0xFF0) == 0xE60)
 {
  assert(ret.size() == 0);
  ret += s("MOVE_USP<%d>(instr_b2_b0);", (bool)(instr & 0x8));
  PrivilegeWrap(&ret);
 }

 // LINK
 if((instr & 0xFF8) == 0xE50)
 {
  assert(ret.size() == 0);
  ret += s("LINK(instr_b2_b0);");
 }

 // UNLK
 if((instr & 0xFF8) == 0xE58)
 {
  assert(ret.size() == 0);
  ret += s("UNLK(instr_b2_b0);");
 }

 // RTR
 //              FEDCBA9876543210
 if(instr == 0b0100111001110111)
 {
  assert(ret.size() == 0);
  ret += s("RTR();");
 }


 // TRAPV
 //            FEDCBA9876543210
 if(instr == 0b0100111001110110)
 {
  assert(ret.size() == 0);
  ret += s("TRAPV();");
 }

 // RTS
 //            FEDCBA9876543210
 if(instr == 0b0100111001110101)
 {
  assert(ret.size() == 0);
  ret += s("RTS();");
 }

 // RTE
 //            FEDCBA9876543210
 if(instr == 0b0100111001110011)
 {
  assert(ret.size() == 0);
  ret += s("RTE();");
  PrivilegeWrap(&ret);
 }

 // STOP
 //            FEDCBA9876543210
 if(instr == 0b0100111001110010)
 {
  assert(ret.size() == 0);
  ret += s("STOP();");
  PrivilegeWrap(&ret);
 }

 // NOP
 //            FEDCBA9876543210
 if(instr == 0b0100111001110001)
 {
  assert(ret.size() == 0);
  ret += s("NOP();");
 }

 // RESET
 //            FEDCBA9876543210
 if(instr == 0b0100111001110000)
 {
  assert(ret.size() == 0);
  ret += s("RESET();");
  PrivilegeWrap(&ret);
 }


 return ret;
}

static std::string Instr5(const unsigned i)
{
 std::string ret;
 std::string tmp;
 const unsigned szi = (i >> 6) & 0x3;

 if(szi == 0x3)
 {
  if(((i >> 3) & 0x7) == 0x1) // DBcc
  {
   ret = s("DBcc<0x%02x>(instr_b2_b0);", (i >> 8) & 0xF);
  }
  else if(decode_ea(AMA_DATA | AMA_ALTERABLE, 1, i, "dst", &tmp))	// Scc
  {
   ret = s("%s; Scc<0x%02x>(dst);", tmp.c_str(), (i >> 8) & 0xF);
  }
 }
 else if(decode_ea(AMA_ALTERABLE, (((i >> 3) & 0x7) == 1) ? 4 : (1U << szi), i, "dst", &tmp))	// ADDQ and SUBQ
 {
  ret = s("HAM<%s, IMMEDIATE> src(this, instr_b11_b9 ? instr_b11_b9 : 8); ", size_names[szi]);
  ret += s("%s; %s(src, dst);", tmp.c_str(), (i & 0x100) ? "SUB" : "ADD");
 }


 return ret;
}

static std::string Instr6(const unsigned i)
{
 return s("Bxx<0x%02x>((int8)instr);", (i >> 8) & 0xF);
}

static std::string Instr7(const unsigned i)
{
 std::string ret;

 // MOVEQ
 if(((i >> 8) & 0x1) == 0x0)
 {
  ret = s("HAM<uint32, IMMEDIATE> src(this, (int8)instr); HAM<uint32, DATA_REG_DIR> dst(this, instr_b11_b9); MOVE(src, dst);");
 }

 return ret;
}

static std::string Instr8(const unsigned i)
{
 std::string ret;

 ret = form_dar_opm_ea<false, false, false>(i, "OR");

 // DIVU/DIVS
 if(((i >> 6) & 0x3) == 0x3)
 {
  std::string tmp;

  if(decode_ea(AMA_DATA, 2, i, "src", &tmp))
  {
   assert(ret.size() == 0);

   ret = s("%s; DIV%s(src, instr_b11_b9);", tmp.c_str(), ((i >> 8) & 1) ? "S" : "U");
  }
 }
 else if(((i >> 4) & 0x1F) == 0x10)	// SBCD
 {
  assert(ret.size() == 0);

  ret = form_destr_rm_srcr(i, "SBCD", 0);
 }
 return ret;
}

static std::string Instr9(const unsigned i)
{
 return form_dar_opm_ea<true, true>(i, "SUB");
}

static std::string InstrB(const unsigned i)
{
 std::string ret;

 switch((i >> 6) & 0x7)
 {
  case 0x4: case 0x5: case 0x6:
	ret = form_dar_opm_ea<false, false, false, true>(i, "EOR");
	break;

  case 0x0: case 0x1: case 0x2: case 0x3: case 0x7:
	ret = form_dar_opm_ea<true, false>(i, "CMP");
	break;
 }

 // CMPM
 if(((i >> 8) & 0x1) == 0x1 && ((i >> 3) & 0x7) == 0x1)
 {
  const unsigned szi = (i >> 6) & 0x3;

  if(szi != 0x3)
  {
   assert(ret.size() == 0);
   ret = form_destr_rm_srcr(i, "CMP", szi, "ADDR_REG_INDIR_POST");
  }
 }

 return ret;
}

static std::string InstrC(const unsigned i)
{
 std::string ret;

 ret = form_dar_opm_ea<false, false, false>(i, "AND");

 if(((i >> 4) & 0x1F) == 0x10)	// ABCD
 {
  assert(ret.size() == 0);

  ret = form_destr_rm_srcr(i, "ABCD", 0);
 }

 // MULU/MULS
 if(((i >> 6) & 0x3) == 0x3)
 {
  std::string tmp;

  if(decode_ea(AMA_DATA, 2, i, "src", &tmp))
  {
   assert(ret.size() == 0);

   ret = s("%s; MUL%s(src, instr_b11_b9);", tmp.c_str(), ((i >> 8) & 1) ? "S" : "U");
  }
 }

 {
  const unsigned exgm = (i >> 3) & 0x3F;
  switch(exgm)
  {
   case 0x28:
	assert(ret.size() == 0);
	ret = s("EXG(&D[instr_b11_b9], &D[instr_b2_b0]); /* EXG Dx, Dy */");
	break;

   case 0x29:
	assert(ret.size() == 0);
	ret = s("EXG(&A[instr_b11_b9], &A[instr_b2_b0]); /* EXG Ax, Ay */");
	break;

   case 0x31:
	assert(ret.size() == 0);
	ret = s("EXG(&D[instr_b11_b9], &A[instr_b2_b0]); /* EXG Dx, Ay */");
	break;
  }
 }

 return ret;
}

static std::string InstrD(const unsigned i)
{
 return form_dar_opm_ea<true, true>(i, "ADD");
}

static std::string InstrE(const unsigned i)
{
 std::string ret;

 const unsigned szi = (i >> 6) & 0x3;
 static const char* op_bases[4] = { "AS", "LS", "ROX", "RO" };
 static const char* op_suffixes[2] = { "R", "L" };
 const bool dr = (i >> 8) & 1;	// Direction, 0=right, 1=left

 if(szi == 0x3)
 {
  if(((i >> 11) & 1) == 0)
  {
   std::string tmp;

   if(decode_ea(AMA_MEMORY | AMA_ALTERABLE, 2, i, "targ", &tmp))
   {
    const unsigned type = (i >> 9) & 0x3;

    ret += s("%s; %s%s(targ, 1);", tmp.c_str(), op_bases[type], op_suffixes[dr]);
   }
  }
 }
 else
 {
  const unsigned type = (i >> 3) & 0x3;
  const bool lr = (i >> 5) & 1;
  std::string cnt;

  if(lr)
   cnt = s("D[instr_b11_b9]");
  else
   cnt = s("instr_b11_b9 ? instr_b11_b9 : 8");

  ret += s("HAM<%s, DATA_REG_DIR> targ(this, instr_b2_b0); %s%s(targ, %s);", size_names[szi], op_bases[type], op_suffixes[dr], cnt.c_str());
 }

 return ret;
}

static std::string InstrA(const unsigned instr)
{
 return "LINEA();";
}

static std::string InstrF(const unsigned instr)
{
 return "LINEF();";
}


int main()
{
 std::map<std::string, std::vector<unsigned>> bm;
 
 for(unsigned i = 0; i < 65536; i++)
 {
  std::string body;
  
  switch(i >> 12)
  {
   case 0x0: body += Instr0(i); break;
   case 0x1: body += Instr1(i); break;
   case 0x2:
   case 0x3: body += Instr23(i); break;
   case 0x4: body += Instr4(i); break;
   case 0x5: body += Instr5(i); break;
   case 0x6: body += Instr6(i); break;
   case 0x7: body += Instr7(i); break;
   case 0x8: body += Instr8(i); break;
   case 0x9: body += Instr9(i); break;
   case 0xA: body += InstrA(i); break;
   case 0xB: body += InstrB(i); break;
   case 0xC: body += InstrC(i); break;
   case 0xD: body += InstrD(i); break;
   case 0xE: body += InstrE(i); break;
   case 0xF: body += InstrF(i); break;
  }
  if(body.size() > 0)
   bm[body].push_back(i);
 }

 for(auto const& bme : bm)
 {
  for(auto const& ve : bme.second)
  {
   printf("case 0x%04x:\n", ve);
  }
  
  printf("\t{\n\t %s\n\t}\n\tbreak;\n\n", bme.first.c_str());
 }
}
