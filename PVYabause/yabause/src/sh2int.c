/*  Copyright 2003-2005 Guillaume Duhamel
    Copyright 2004-2007, 2013 Theo Berkau
    Copyright 2005 Fabien Coulon

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/*! \file sh2int.c
    \brief SH2 interpreter interface
*/

#include "sh2core.h"
#include "sh2int.h"
#include "sh2idle.h"
#include "cs0.h"
#include "debug.h"
#include "error.h"
#include "memory.h"
#include "bios.h"
#include "yabause.h"

// #define SH2_TRACE  // Uncomment to enable tracing

#ifdef SH2_TRACE
# include "sh2trace.h"
# define MappedMemoryWriteByte(a,v)  do { \
    uint32_t __a = (a), __v = (v);        \
    sh2_trace_writeb(__a, __v);           \
    MappedMemoryWriteByte(__a, __v);      \
} while (0)
# define MappedMemoryWriteWord(a,v)  do { \
    uint32_t __a = (a), __v = (v);        \
    sh2_trace_writew(__a, __v);           \
    MappedMemoryWriteWord(__a, __v);      \
} while (0)
# define MappedMemoryWriteLong(a,v)  do { \
    uint32_t __a = (a), __v = (v);        \
    sh2_trace_writel(__a, __v);           \
    MappedMemoryWriteLong(__a, __v);      \
} while (0)
#endif


opcodefunc opcodes[0x10000];

SH2Interface_struct SH2Interpreter = {
   SH2CORE_INTERPRETER,
   "SH2 Interpreter",

   SH2InterpreterInit,
   SH2InterpreterDeInit,
   SH2InterpreterReset,
   SH2InterpreterExec,

   SH2InterpreterGetRegisters,
   SH2InterpreterGetGPR,
   SH2InterpreterGetSR,
   SH2InterpreterGetGBR,
   SH2InterpreterGetVBR,
   SH2InterpreterGetMACH,
   SH2InterpreterGetMACL,
   SH2InterpreterGetPR,
   SH2InterpreterGetPC,

   SH2InterpreterSetRegisters,
   SH2InterpreterSetGPR,
   SH2InterpreterSetSR,
   SH2InterpreterSetGBR,
   SH2InterpreterSetVBR,
   SH2InterpreterSetMACH,
   SH2InterpreterSetMACL,
   SH2InterpreterSetPR,
   SH2InterpreterSetPC,

   SH2InterpreterSendInterrupt,
   SH2InterpreterGetInterrupts,
   SH2InterpreterSetInterrupts,

   NULL  // SH2WriteNotify not used
};

SH2Interface_struct SH2DebugInterpreter = {
   SH2CORE_DEBUGINTERPRETER,
   "SH2 Debugger Interpreter",

   SH2DebugInterpreterInit,
   SH2InterpreterDeInit,
   SH2InterpreterReset,
   SH2DebugInterpreterExec,

   SH2InterpreterGetRegisters,
   SH2InterpreterGetGPR,
   SH2InterpreterGetSR,
   SH2InterpreterGetGBR,
   SH2InterpreterGetVBR,
   SH2InterpreterGetMACH,
   SH2InterpreterGetMACL,
   SH2InterpreterGetPR,
   SH2InterpreterGetPC,

   SH2InterpreterSetRegisters,
   SH2InterpreterSetGPR,
   SH2InterpreterSetSR,
   SH2InterpreterSetGBR,
   SH2InterpreterSetVBR,
   SH2InterpreterSetMACH,
   SH2InterpreterSetMACL,
   SH2InterpreterSetPR,
   SH2InterpreterSetPC,

   SH2InterpreterSendInterrupt,
   SH2InterpreterGetInterrupts,
   SH2InterpreterSetInterrupts,

   NULL  // SH2WriteNotify not used
};

fetchfunc fetchlist[0x100];

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL FetchBios(u32 addr)
{
   return T2ReadWord(BiosRom, addr & 0x7FFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL FetchCs0(u32 addr)
{
   return CartridgeArea->Cs0ReadWord(addr);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL FetchLWram(u32 addr)
{
   return T2ReadWord(LowWram, addr & 0xFFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL FetchHWram(u32 addr)
{
   return T2ReadWord(HighWram, addr & 0xFFFFF);
}

//////////////////////////////////////////////////////////////////////////////

static u32 FASTCALL FetchInvalid(UNUSED u32 addr)
{
   return 0xFFFF;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2delay(SH2_struct * sh, u32 addr)
{
#ifdef SH2_TRACE
   sh2_trace(sh, addr);
#endif

   // Fetch Instruction
#ifdef EXEC_FROM_CACHE
   if ((addr & 0xC0000000) == 0xC0000000) sh->instruction = DataArrayReadWord(addr);
   else
#endif
   sh->instruction = fetchlist[(addr >> 20) & 0x0FF](addr);

   // Execute it
   opcodes[sh->instruction](sh);
   sh->regs.PC -= 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2undecoded(SH2_struct * sh)
{
   int vectnum;

   if (yabsys.emulatebios)
   {
      if (BiosHandleFunc(sh))
         return;
   }

   YabSetError(YAB_ERR_SH2INVALIDOPCODE, sh);      

   // Save regs.SR on stack
   sh->regs.R[15]-=4;
   MappedMemoryWriteLong(sh->regs.R[15],sh->regs.SR.all);

   // Save regs.PC on stack
   sh->regs.R[15]-=4;
   MappedMemoryWriteLong(sh->regs.R[15],sh->regs.PC + 2);

   // What caused the exception? The delay slot or a general instruction?
   // 4 for General Instructions, 6 for delay slot
   vectnum = 4; //  Fix me

   // Jump to Exception service routine
   sh->regs.PC = MappedMemoryReadLong(sh->regs.VBR+(vectnum<<2));
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2add(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] += sh->regs.R[INSTRUCTION_C(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2addi(SH2_struct * sh)
{
   s32 cd = (s32)(s8)INSTRUCTION_CD(sh->instruction);
   s32 b = INSTRUCTION_B(sh->instruction);

   sh->regs.R[b] += cd;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2addc(SH2_struct * sh)
{
   u32 tmp0, tmp1;
   s32 source = INSTRUCTION_C(sh->instruction);
   s32 dest = INSTRUCTION_B(sh->instruction);

   tmp1 = sh->regs.R[source] + sh->regs.R[dest];
   tmp0 = sh->regs.R[dest];

   sh->regs.R[dest] = tmp1 + sh->regs.SR.part.T;
   if (tmp0 > tmp1)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   if (tmp1 > sh->regs.R[dest])
      sh->regs.SR.part.T = 1;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2addv(SH2_struct * sh)
{
   s32 dest,src,ans;
   s32 n = INSTRUCTION_B(sh->instruction);
   s32 m = INSTRUCTION_C(sh->instruction);

   if ((s32) sh->regs.R[n] >= 0)
      dest = 0;
   else
      dest = 1;
  
   if ((s32) sh->regs.R[m] >= 0)
      src = 0;
   else
      src = 1;
  
   src += dest;
   sh->regs.R[n] += sh->regs.R[m];

   if ((s32) sh->regs.R[n] >= 0)
      ans = 0;
   else
      ans = 1;

   ans += dest;
  
   if (src == 0 || src == 2)
      if (ans == 1)
         sh->regs.SR.part.T = 1;
      else
         sh->regs.SR.part.T = 0;
   else
      sh->regs.SR.part.T = 0;

   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2y_and(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] &= sh->regs.R[INSTRUCTION_C(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2andi(SH2_struct * sh)
{
   sh->regs.R[0] &= INSTRUCTION_CD(sh->instruction);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2andm(SH2_struct * sh)
{
   s32 temp;
   s32 source = INSTRUCTION_CD(sh->instruction);

   temp = (s32) MappedMemoryReadByte(sh->regs.GBR + sh->regs.R[0]);
   temp &= source;
   MappedMemoryWriteByte((sh->regs.GBR + sh->regs.R[0]),temp);
   sh->regs.PC += 2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bf(SH2_struct * sh)
{
   if (sh->regs.SR.part.T == 0)
   {
      s32 disp = (s32)(s8)sh->instruction;

      sh->regs.PC = sh->regs.PC+(disp<<1)+4;
      sh->cycles += 3;
   }
   else
   {
      sh->regs.PC+=2;
      sh->cycles++;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bfs(SH2_struct * sh)
{
   if (sh->regs.SR.part.T == 0)
   {
      s32 disp = (s32)(s8)sh->instruction;
      u32 temp = sh->regs.PC;

      sh->regs.PC = sh->regs.PC + (disp << 1) + 4;

      sh->cycles += 2;
      SH2delay(sh, temp + 2);
   }
   else
   {
      sh->regs.PC += 2;
      sh->cycles++;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bra(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_BCD(sh->instruction);
   u32 temp = sh->regs.PC;

   if ((disp&0x800) != 0)
      disp |= 0xFFFFF000;

   sh->regs.PC = sh->regs.PC + (disp<<1) + 4;

   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2braf(SH2_struct * sh)
{
   u32 temp;
   s32 m = INSTRUCTION_B(sh->instruction);

   temp = sh->regs.PC;
   sh->regs.PC += sh->regs.R[m] + 4; 

   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bsr(SH2_struct * sh)
{
   u32 temp;
   s32 disp = INSTRUCTION_BCD(sh->instruction);

   temp = sh->regs.PC;
   if ((disp&0x800) != 0) disp |= 0xFFFFF000;
   sh->regs.PR = sh->regs.PC + 4;
   sh->regs.PC = sh->regs.PC+(disp<<1) + 4;

   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bsrf(SH2_struct * sh)
{
   u32 temp = sh->regs.PC;
   sh->regs.PR = sh->regs.PC + 4;
   sh->regs.PC += sh->regs.R[INSTRUCTION_B(sh->instruction)] + 4;
   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bt(SH2_struct * sh)
{
   if (sh->regs.SR.part.T == 1)
   {
      s32 disp = (s32)(s8)sh->instruction;

      sh->regs.PC = sh->regs.PC+(disp<<1)+4;
      sh->cycles += 3;
   }
   else
   {
      sh->regs.PC += 2;
      sh->cycles++;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2bts(SH2_struct * sh)
{
   if (sh->regs.SR.part.T)
   {
      s32 disp = (s32)(s8)sh->instruction;
      u32 temp = sh->regs.PC;

      sh->regs.PC += (disp << 1) + 4;
      sh->cycles += 2;
      SH2delay(sh, temp + 2);
   }
   else
   {
      sh->regs.PC+=2;
      sh->cycles++;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2clrmac(SH2_struct * sh)
{
   sh->regs.MACH = 0;
   sh->regs.MACL = 0;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2clrt(SH2_struct * sh)
{
   sh->regs.SR.part.T = 0;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmpeq(SH2_struct * sh)
{
   if (sh->regs.R[INSTRUCTION_B(sh->instruction)] == sh->regs.R[INSTRUCTION_C(sh->instruction)])
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmpge(SH2_struct * sh)
{
   if ((s32)sh->regs.R[INSTRUCTION_B(sh->instruction)] >=
       (s32)sh->regs.R[INSTRUCTION_C(sh->instruction)])
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmpgt(SH2_struct * sh)
{
   if ((s32)sh->regs.R[INSTRUCTION_B(sh->instruction)]>(s32)sh->regs.R[INSTRUCTION_C(sh->instruction)])
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmphi(SH2_struct * sh)
{
   if ((u32)sh->regs.R[INSTRUCTION_B(sh->instruction)] >
       (u32)sh->regs.R[INSTRUCTION_C(sh->instruction)])
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmphs(SH2_struct * sh)
{
   if ((u32)sh->regs.R[INSTRUCTION_B(sh->instruction)] >=
       (u32)sh->regs.R[INSTRUCTION_C(sh->instruction)])
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmpim(SH2_struct * sh)
{
   s32 imm;
   s32 i = INSTRUCTION_CD(sh->instruction);

   imm = (s32)(s8)i;

   if (sh->regs.R[0] == (u32) imm) // FIXME: ouais � doit �re bon...
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmppl(SH2_struct * sh)
{
   if ((s32)sh->regs.R[INSTRUCTION_B(sh->instruction)]>0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmppz(SH2_struct * sh)
{
   if ((s32)sh->regs.R[INSTRUCTION_B(sh->instruction)]>=0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2cmpstr(SH2_struct * sh)
{
   u32 temp;
   s32 HH,HL,LH,LL;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
   temp=sh->regs.R[n]^sh->regs.R[m];
   HH = (temp>>24) & 0x000000FF;
   HL = (temp>>16) & 0x000000FF;
   LH = (temp>>8) & 0x000000FF;
   LL = temp & 0x000000FF;
   HH = HH && HL && LH && LL;
   if (HH == 0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2div0s(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
   if ((sh->regs.R[n]&0x80000000)==0)
     sh->regs.SR.part.Q = 0;
   else
     sh->regs.SR.part.Q = 1;
   if ((sh->regs.R[m]&0x80000000)==0)
     sh->regs.SR.part.M = 0;
   else
     sh->regs.SR.part.M = 1;
   sh->regs.SR.part.T = !(sh->regs.SR.part.M == sh->regs.SR.part.Q);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2div0u(SH2_struct * sh)
{
   sh->regs.SR.part.M = sh->regs.SR.part.Q = sh->regs.SR.part.T = 0;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2div1(SH2_struct * sh)
{
   u32 tmp0;
   u8 old_q, tmp1;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
  
   old_q = sh->regs.SR.part.Q;
   sh->regs.SR.part.Q = (u8)((0x80000000 & sh->regs.R[n])!=0);
   sh->regs.R[n] <<= 1;
   sh->regs.R[n]|=(u32) sh->regs.SR.part.T;

   switch(old_q)
   {
      case 0:
         switch(sh->regs.SR.part.M)
         {
            case 0:
               tmp0 = sh->regs.R[n];
               sh->regs.R[n] -= sh->regs.R[m];
               tmp1 = (sh->regs.R[n] > tmp0);
               switch(sh->regs.SR.part.Q)
               {
                  case 0:
                     sh->regs.SR.part.Q = tmp1;
                     break;
                  case 1:
                     sh->regs.SR.part.Q = (u8) (tmp1 == 0);
                     break;
               }
               break;
            case 1:
               tmp0 = sh->regs.R[n];
               sh->regs.R[n] += sh->regs.R[m];
               tmp1 = (sh->regs.R[n] < tmp0);
               switch(sh->regs.SR.part.Q)
               {
                  case 0:
                     sh->regs.SR.part.Q = (u8) (tmp1 == 0);
                     break;
                  case 1:
                     sh->regs.SR.part.Q = tmp1;
                     break;
               }
               break;
         }
         break;
      case 1:
         switch(sh->regs.SR.part.M)
         {
            case 0:
               tmp0 = sh->regs.R[n];
               sh->regs.R[n] += sh->regs.R[m];
               tmp1 = (sh->regs.R[n] < tmp0);
               switch(sh->regs.SR.part.Q)
               {
                  case 0:
                     sh->regs.SR.part.Q = tmp1;
                     break;
                  case 1:
                     sh->regs.SR.part.Q = (u8) (tmp1 == 0);
                     break;
               }
               break;
            case 1:
               tmp0 = sh->regs.R[n];
               sh->regs.R[n] -= sh->regs.R[m];
               tmp1 = (sh->regs.R[n] > tmp0);
               switch(sh->regs.SR.part.Q)
               {
                  case 0:
                     sh->regs.SR.part.Q = (u8) (tmp1 == 0);
                     break;
                  case 1:
                     sh->regs.SR.part.Q = tmp1;
                     break;
               }
               break;
         }
         break;
   }
   sh->regs.SR.part.T = (sh->regs.SR.part.Q == sh->regs.SR.part.M);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2dmuls(SH2_struct * sh)
{
   u32 RnL,RnH,RmL,RmH,Res0,Res1,Res2;
   u32 temp0,temp1,temp2,temp3;
   s32 tempm,tempn,fnLmL;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
  
   tempn = (s32)sh->regs.R[n];
   tempm = (s32)sh->regs.R[m];
   if (tempn < 0)
      tempn = 0 - tempn;
   if (tempm < 0)
      tempm = 0 - tempm;
   if ((s32) (sh->regs.R[n] ^ sh->regs.R[m]) < 0)
      fnLmL = -1;
   else
      fnLmL = 0;
  
   temp1 = (u32) tempn;
   temp2 = (u32) tempm;

   RnL = temp1 & 0x0000FFFF;
   RnH = (temp1 >> 16) & 0x0000FFFF;
   RmL = temp2 & 0x0000FFFF;
   RmH = (temp2 >> 16) & 0x0000FFFF;
  
   temp0 = RmL * RnL;
   temp1 = RmH * RnL;
   temp2 = RmL * RnH;
   temp3 = RmH * RnH;

   Res2 = 0;
   Res1 = temp1 + temp2;
   if (Res1 < temp1)
      Res2 += 0x00010000;

   temp1 = (Res1 << 16) & 0xFFFF0000;
   Res0 = temp0 + temp1;
   if (Res0 < temp0)
      Res2++;
  
   Res2 = Res2 + ((Res1 >> 16) & 0x0000FFFF) + temp3;

   if (fnLmL < 0)
   {
      Res2 = ~Res2;
      if (Res0 == 0)
         Res2++;
      else
         Res0 =(~Res0) + 1;
   }
   sh->regs.MACH = Res2;
   sh->regs.MACL = Res0;
   sh->regs.PC += 2;
   sh->cycles += 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2dmulu(SH2_struct * sh)
{
   u32 RnL,RnH,RmL,RmH,Res0,Res1,Res2;
   u32 temp0,temp1,temp2,temp3;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   RnL = sh->regs.R[n] & 0x0000FFFF;
   RnH = (sh->regs.R[n] >> 16) & 0x0000FFFF;
   RmL = sh->regs.R[m] & 0x0000FFFF;
   RmH = (sh->regs.R[m] >> 16) & 0x0000FFFF;

   temp0 = RmL * RnL;
   temp1 = RmH * RnL;
   temp2 = RmL * RnH;
   temp3 = RmH * RnH;
  
   Res2 = 0;
   Res1 = temp1 + temp2;
   if (Res1 < temp1)
      Res2 += 0x00010000;
  
   temp1 = (Res1 << 16) & 0xFFFF0000;
   Res0 = temp0 + temp1;
   if (Res0 < temp0)
      Res2++;
  
   Res2 = Res2 + ((Res1 >> 16) & 0x0000FFFF) + temp3;
 
   sh->regs.MACH = Res2;
   sh->regs.MACL = Res0;
   sh->regs.PC += 2;
   sh->cycles += 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2dt(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n]--;
   if (sh->regs.R[n] == 0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2extsb(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (u32)(s8)sh->regs.R[m];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2extsw(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (u32)(s16)sh->regs.R[m];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2extub(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (u32)(u8)sh->regs.R[m];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2extuw(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (u32)(u16)sh->regs.R[m];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2jmp(SH2_struct * sh)
{
   u32 temp;
   s32 m = INSTRUCTION_B(sh->instruction);

   temp=sh->regs.PC;
   sh->regs.PC = sh->regs.R[m];
   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2jsr(SH2_struct * sh)
{
   u32 temp;
   s32 m = INSTRUCTION_B(sh->instruction);

   temp = sh->regs.PC;
   sh->regs.PR = sh->regs.PC + 4;
   sh->regs.PC = sh->regs.R[m];
   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldcgbr(SH2_struct * sh)
{
   sh->regs.GBR = sh->regs.R[INSTRUCTION_B(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldcmgbr(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);

   sh->regs.GBR = MappedMemoryReadLong(sh->regs.R[m]);
   sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldcmsr(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);

   sh->regs.SR.all = MappedMemoryReadLong(sh->regs.R[m]) & 0x000003F3;
   sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldcmvbr(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);

   sh->regs.VBR = MappedMemoryReadLong(sh->regs.R[m]);
   sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldcsr(SH2_struct * sh)
{
   sh->regs.SR.all = sh->regs.R[INSTRUCTION_B(sh->instruction)]&0x000003F3;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldcvbr(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);

   sh->regs.VBR = sh->regs.R[m];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldsmach(SH2_struct * sh)
{
   sh->regs.MACH = sh->regs.R[INSTRUCTION_B(sh->instruction)];
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldsmacl(SH2_struct * sh)
{
   sh->regs.MACL = sh->regs.R[INSTRUCTION_B(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldsmmach(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);
   sh->regs.MACH = MappedMemoryReadLong(sh->regs.R[m]);
   sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldsmmacl(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);
   sh->regs.MACL = MappedMemoryReadLong(sh->regs.R[m]);
   sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldsmpr(SH2_struct * sh)
{
   s32 m = INSTRUCTION_B(sh->instruction);
   sh->regs.PR = MappedMemoryReadLong(sh->regs.R[m]);
   sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ldspr(SH2_struct * sh)
{
   sh->regs.PR = sh->regs.R[INSTRUCTION_B(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2macl(SH2_struct * sh)
{
   u32 RnL,RnH,RmL,RmH,Res0,Res1,Res2;
   u32 temp0,temp1,temp2,temp3;
   s32 tempm,tempn,fnLmL;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   tempn = (s32) MappedMemoryReadLong(sh->regs.R[n]);
   sh->regs.R[n] += 4;
   tempm = (s32) MappedMemoryReadLong(sh->regs.R[m]);
   sh->regs.R[m] += 4;

   if ((s32) (tempn^tempm) < 0)
      fnLmL = -1;
   else
      fnLmL = 0;
   if (tempn < 0)
      tempn = 0 - tempn;
   if (tempm < 0)
      tempm = 0 - tempm;

   temp1 = (u32) tempn;
   temp2 = (u32) tempm;

   RnL = temp1 & 0x0000FFFF;
   RnH = (temp1 >> 16) & 0x0000FFFF;
   RmL = temp2 & 0x0000FFFF;
   RmH = (temp2 >> 16) & 0x0000FFFF;

   temp0 = RmL * RnL;
   temp1 = RmH * RnL;
   temp2 = RmL * RnH;
   temp3 = RmH * RnH;

   Res2 = 0;
   Res1 = temp1 + temp2;
   if (Res1 < temp1)
      Res2 += 0x00010000;

   temp1 = (Res1 << 16) & 0xFFFF0000;
   Res0 = temp0 + temp1;
   if (Res0 < temp0)
      Res2++;

   Res2=Res2+((Res1>>16)&0x0000FFFF)+temp3;

   if(fnLmL < 0)
   {
      Res2=~Res2;
      if (Res0==0)
         Res2++;
      else
         Res0=(~Res0)+1;
   }
   if(sh->regs.SR.part.S == 1)
   {
      Res0=sh->regs.MACL+Res0;
      if (sh->regs.MACL>Res0)
         Res2++;
      if (sh->regs.MACH & 0x00008000);
      else Res2 += sh->regs.MACH | 0xFFFF0000;
      Res2+=(sh->regs.MACH&0x0000FFFF);
      if(((s32)Res2<0)&&(Res2<0xFFFF8000))
      {
         Res2=0x00008000;
         Res0=0x00000000;
      }
      if(((s32)Res2>0)&&(Res2>0x00007FFF))
      {
         Res2=0x00007FFF;
         Res0=0xFFFFFFFF;
      };

      sh->regs.MACH=Res2;
      sh->regs.MACL=Res0;
   }
   else
   {
      Res0=sh->regs.MACL+Res0;
      if (sh->regs.MACL>Res0)
         Res2++;
      Res2+=sh->regs.MACH;

      sh->regs.MACH=Res2;
      sh->regs.MACL=Res0;
   }

   sh->regs.PC+=2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2macw(SH2_struct * sh)
{
   s32 tempm,tempn,dest,src,ans;
   u32 templ;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   tempn=(s32) MappedMemoryReadWord(sh->regs.R[n]);
   sh->regs.R[n]+=2;
   tempm=(s32) MappedMemoryReadWord(sh->regs.R[m]);
   sh->regs.R[m]+=2;
   templ=sh->regs.MACL;
   tempm=((s32)(s16)tempn*(s32)(s16)tempm);

   if ((s32)sh->regs.MACL>=0)
      dest=0;
   else
      dest=1;
   if ((s32)tempm>=0)
   {
      src=0;
      tempn=0;
   }
   else
   {
      src=1;
      tempn=0xFFFFFFFF;
   }
   src+=dest;
   sh->regs.MACL+=tempm;
   if ((s32)sh->regs.MACL>=0)
      ans=0;
   else
      ans=1;
   ans+=dest;
   if (sh->regs.SR.part.S == 1)
   {
      if (ans==1)
      {
         if (src==0)
            sh->regs.MACL=0x7FFFFFFF;
         if (src==2)
            sh->regs.MACL=0x80000000;
      }
   }
   else
   {
      sh->regs.MACH+=tempn;
      if (templ>sh->regs.MACL)
         sh->regs.MACH+=1;
   }
   sh->regs.PC+=2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2mov(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)]=sh->regs.R[INSTRUCTION_C(sh->instruction)];
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2mova(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);

   sh->regs.R[0]=((sh->regs.PC+4)&0xFFFFFFFC)+(disp<<2);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbl(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s8)MappedMemoryReadByte(sh->regs.R[m]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbl0(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s8)MappedMemoryReadByte(sh->regs.R[m] + sh->regs.R[0]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbl4(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 disp = INSTRUCTION_D(sh->instruction);

   sh->regs.R[0] = (s32)(s8)MappedMemoryReadByte(sh->regs.R[m] + disp);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movblg(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);
  
   sh->regs.R[0] = (s32)(s8)MappedMemoryReadByte(sh->regs.GBR + disp);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbm(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   MappedMemoryWriteByte((sh->regs.R[n] - 1),sh->regs.R[m]);
   sh->regs.R[n] -= 1;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbp(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s8)MappedMemoryReadByte(sh->regs.R[m]);
   if (n != m)
     sh->regs.R[m] += 1;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbs(SH2_struct * sh)
{
   int b = INSTRUCTION_B(sh->instruction);
   int c = INSTRUCTION_C(sh->instruction);

   MappedMemoryWriteByte(sh->regs.R[b], sh->regs.R[c]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbs0(SH2_struct * sh)
{
   MappedMemoryWriteByte(sh->regs.R[INSTRUCTION_B(sh->instruction)] + sh->regs.R[0],
                         sh->regs.R[INSTRUCTION_C(sh->instruction)]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbs4(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_D(sh->instruction);
   s32 n = INSTRUCTION_C(sh->instruction);

   MappedMemoryWriteByte(sh->regs.R[n]+disp,sh->regs.R[0]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movbsg(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);

   MappedMemoryWriteByte(sh->regs.GBR + disp,sh->regs.R[0]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movi(SH2_struct * sh)
{
   s32 i = INSTRUCTION_CD(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s8)i;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movli(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = MappedMemoryReadLong(((sh->regs.PC + 4) & 0xFFFFFFFC) + (disp << 2));
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movll(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] = MappedMemoryReadLong(sh->regs.R[INSTRUCTION_C(sh->instruction)]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movll0(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] = MappedMemoryReadLong(sh->regs.R[INSTRUCTION_C(sh->instruction)] + sh->regs.R[0]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movll4(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 disp = INSTRUCTION_D(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = MappedMemoryReadLong(sh->regs.R[m] + (disp << 2));
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movllg(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);

   sh->regs.R[0] = MappedMemoryReadLong(sh->regs.GBR + (disp << 2));
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movlm(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   MappedMemoryWriteLong(sh->regs.R[n] - 4,sh->regs.R[m]);
   sh->regs.R[n] -= 4;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movlp(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = MappedMemoryReadLong(sh->regs.R[m]);
   if (n != m) sh->regs.R[m] += 4;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movls(SH2_struct * sh)
{
   int b = INSTRUCTION_B(sh->instruction);
   int c = INSTRUCTION_C(sh->instruction);

   MappedMemoryWriteLong(sh->regs.R[b], sh->regs.R[c]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movls0(SH2_struct * sh)
{
   MappedMemoryWriteLong(sh->regs.R[INSTRUCTION_B(sh->instruction)] + sh->regs.R[0],
                         sh->regs.R[INSTRUCTION_C(sh->instruction)]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movls4(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 disp = INSTRUCTION_D(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   MappedMemoryWriteLong(sh->regs.R[n]+(disp<<2),sh->regs.R[m]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movlsg(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);

   MappedMemoryWriteLong(sh->regs.GBR+(disp<<2),sh->regs.R[0]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movt(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] = (0x00000001 & sh->regs.SR.all);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwi(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s16)MappedMemoryReadWord(sh->regs.PC + (disp<<1) + 4);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwl(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s16)MappedMemoryReadWord(sh->regs.R[m]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwl0(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s16)MappedMemoryReadWord(sh->regs.R[m]+sh->regs.R[0]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwl4(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 disp = INSTRUCTION_D(sh->instruction);

   sh->regs.R[0] = (s32)(s16)MappedMemoryReadWord(sh->regs.R[m]+(disp<<1));
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwlg(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);

   sh->regs.R[0] = (s32)(s16)MappedMemoryReadWord(sh->regs.GBR+(disp<<1));
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwm(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   MappedMemoryWriteWord(sh->regs.R[n] - 2,sh->regs.R[m]);
   sh->regs.R[n] -= 2;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwp(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.R[n] = (s32)(s16)MappedMemoryReadWord(sh->regs.R[m]);
   if (n != m)
      sh->regs.R[m] += 2;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movws(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   MappedMemoryWriteWord(sh->regs.R[n],sh->regs.R[m]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movws0(SH2_struct * sh)
{
   MappedMemoryWriteWord(sh->regs.R[INSTRUCTION_B(sh->instruction)] + sh->regs.R[0],
                         sh->regs.R[INSTRUCTION_C(sh->instruction)]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movws4(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_D(sh->instruction);
   s32 n = INSTRUCTION_C(sh->instruction);

   MappedMemoryWriteWord(sh->regs.R[n]+(disp<<1),sh->regs.R[0]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2movwsg(SH2_struct * sh)
{
   s32 disp = INSTRUCTION_CD(sh->instruction);

   MappedMemoryWriteWord(sh->regs.GBR+(disp<<1),sh->regs.R[0]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2mull(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.MACL = sh->regs.R[n] * sh->regs.R[m];
   sh->regs.PC+=2;
   sh->cycles += 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2muls(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.MACL = ((s32)(s16)sh->regs.R[n]*(s32)(s16)sh->regs.R[m]);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2mulu(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   sh->regs.MACL = ((u32)(u16)sh->regs.R[n] * (u32)(u16)sh->regs.R[m]);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2neg(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)]=0-sh->regs.R[INSTRUCTION_C(sh->instruction)];
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2negc(SH2_struct * sh)
{
   u32 temp;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
  
   temp=0-sh->regs.R[m];
   sh->regs.R[n] = temp - sh->regs.SR.part.T;
   if (0 < temp)
      sh->regs.SR.part.T=1;
   else
      sh->regs.SR.part.T=0;
   if (temp < sh->regs.R[n])
      sh->regs.SR.part.T=1;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2nop(SH2_struct * sh)
{
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2y_not(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] = ~sh->regs.R[INSTRUCTION_C(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2y_or(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] |= sh->regs.R[INSTRUCTION_C(sh->instruction)];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2ori(SH2_struct * sh)
{
   sh->regs.R[0] |= INSTRUCTION_CD(sh->instruction);
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2orm(SH2_struct * sh)
{
   s32 temp;
   s32 source = INSTRUCTION_CD(sh->instruction);

   temp = (s32) MappedMemoryReadByte(sh->regs.GBR + sh->regs.R[0]);
   temp |= source;
   MappedMemoryWriteByte(sh->regs.GBR + sh->regs.R[0],temp);
   sh->regs.PC += 2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2rotcl(SH2_struct * sh)
{
   s32 temp;
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x80000000)==0)
      temp=0;
   else
      temp=1;

   sh->regs.R[n]<<=1;

   if (sh->regs.SR.part.T == 1)
      sh->regs.R[n]|=0x00000001;
   else
      sh->regs.R[n]&=0xFFFFFFFE;

   if (temp==1)
      sh->regs.SR.part.T=1;
   else
      sh->regs.SR.part.T=0;

   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2rotcr(SH2_struct * sh)
{
   s32 temp;
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x00000001)==0)
      temp=0;
   else
      temp=1;

   sh->regs.R[n]>>=1;

   if (sh->regs.SR.part.T == 1)
      sh->regs.R[n]|=0x80000000;
   else
      sh->regs.R[n]&=0x7FFFFFFF;

   if (temp==1)
      sh->regs.SR.part.T=1;
   else
      sh->regs.SR.part.T=0;

   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2rotl(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x80000000)==0)
      sh->regs.SR.part.T=0;
   else
      sh->regs.SR.part.T=1;

   sh->regs.R[n]<<=1;

   if (sh->regs.SR.part.T==1)
      sh->regs.R[n]|=0x00000001;
   else
      sh->regs.R[n]&=0xFFFFFFFE;

   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2rotr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x00000001)==0)
      sh->regs.SR.part.T = 0;
   else
      sh->regs.SR.part.T = 1;

   sh->regs.R[n]>>=1;

   if (sh->regs.SR.part.T == 1)
      sh->regs.R[n]|=0x80000000;
   else
      sh->regs.R[n]&=0x7FFFFFFF;

   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2rte(SH2_struct * sh)
{
   u32 temp;
   temp=sh->regs.PC;
   sh->regs.PC = MappedMemoryReadLong(sh->regs.R[15]);
   sh->regs.R[15] += 4;
   sh->regs.SR.all = MappedMemoryReadLong(sh->regs.R[15]) & 0x000003F3;
   sh->regs.R[15] += 4;
   sh->cycles += 4;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2rts(SH2_struct * sh)
{
   u32 temp;

   temp = sh->regs.PC;
   sh->regs.PC = sh->regs.PR;

   sh->cycles += 2;
   SH2delay(sh, temp + 2);
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2sett(SH2_struct * sh)
{
   sh->regs.SR.part.T = 1;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shal(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   if ((sh->regs.R[n] & 0x80000000) == 0)
      sh->regs.SR.part.T = 0;
   else
      sh->regs.SR.part.T = 1;
   sh->regs.R[n] <<= 1;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shar(SH2_struct * sh)
{
   s32 temp;
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x00000001)==0)
      sh->regs.SR.part.T = 0;
   else
      sh->regs.SR.part.T = 1;

   if ((sh->regs.R[n]&0x80000000)==0)
      temp = 0;
   else
      temp = 1;

   sh->regs.R[n] >>= 1;

   if (temp == 1)
      sh->regs.R[n] |= 0x80000000;
   else
      sh->regs.R[n] &= 0x7FFFFFFF;

   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shll(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x80000000)==0)
      sh->regs.SR.part.T=0;
   else
      sh->regs.SR.part.T=1;
 
   sh->regs.R[n]<<=1;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shll2(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)] <<= 2;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shll8(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)]<<=8;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shll16(SH2_struct * sh)
{
   sh->regs.R[INSTRUCTION_B(sh->instruction)]<<=16;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shlr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&0x00000001)==0)
      sh->regs.SR.part.T=0;
   else
      sh->regs.SR.part.T=1;

   sh->regs.R[n]>>=1;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shlr2(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]>>=2;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shlr8(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]>>=8;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2shlr16(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]>>=16;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stcgbr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]=sh->regs.GBR;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stcmgbr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]-=4;
   MappedMemoryWriteLong(sh->regs.R[n],sh->regs.GBR);
   sh->regs.PC+=2;
   sh->cycles += 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stcmsr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]-=4;
   MappedMemoryWriteLong(sh->regs.R[n],sh->regs.SR.all);
   sh->regs.PC+=2;
   sh->cycles += 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stcmvbr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]-=4;
   MappedMemoryWriteLong(sh->regs.R[n],sh->regs.VBR);
   sh->regs.PC+=2;
   sh->cycles += 2;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stcsr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n] = sh->regs.SR.all;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stcvbr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]=sh->regs.VBR;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stsmach(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]=sh->regs.MACH;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stsmacl(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]=sh->regs.MACL;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stsmmach(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n] -= 4;
   MappedMemoryWriteLong(sh->regs.R[n],sh->regs.MACH); 
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stsmmacl(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n] -= 4;
   MappedMemoryWriteLong(sh->regs.R[n],sh->regs.MACL);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stsmpr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n] -= 4;
   MappedMemoryWriteLong(sh->regs.R[n],sh->regs.PR);
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2stspr(SH2_struct * sh)
{
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n] = sh->regs.PR;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2sub(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
   sh->regs.R[n]-=sh->regs.R[m];
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2subc(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
   u32 tmp0,tmp1;
  
   tmp1 = sh->regs.R[n] - sh->regs.R[m];
   tmp0 = sh->regs.R[n];
   sh->regs.R[n] = tmp1 - sh->regs.SR.part.T;

   if (tmp0 < tmp1)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;

   if (tmp1 < sh->regs.R[n])
      sh->regs.SR.part.T = 1;

   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2subv(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
   s32 dest,src,ans;

   if ((s32)sh->regs.R[n]>=0)
      dest=0;
   else
      dest=1;

   if ((s32)sh->regs.R[m]>=0)
      src=0;
   else
      src=1;

   src+=dest;
   sh->regs.R[n]-=sh->regs.R[m];

   if ((s32)sh->regs.R[n]>=0)
      ans=0;
   else
      ans=1;

   ans+=dest;

   if (src==1)
   {
     if (ans==1)
        sh->regs.SR.part.T=1;
     else
        sh->regs.SR.part.T=0;
   }
   else
      sh->regs.SR.part.T=0;

   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2swapb(SH2_struct * sh)
{
   u32 temp0,temp1;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   temp0=sh->regs.R[m]&0xffff0000;
   temp1=(sh->regs.R[m]&0x000000ff)<<8;
   sh->regs.R[n]=(sh->regs.R[m]>>8)&0x000000ff;
   sh->regs.R[n]=sh->regs.R[n]|temp1|temp0;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2swapw(SH2_struct * sh)
{
   u32 temp;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);
   temp=(sh->regs.R[m]>>16)&0x0000FFFF;
   sh->regs.R[n]=sh->regs.R[m]<<16;
   sh->regs.R[n]|=temp;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2tas(SH2_struct * sh)
{
   s32 temp;
   s32 n = INSTRUCTION_B(sh->instruction);

   temp=(s32) MappedMemoryReadByte(sh->regs.R[n]);

   if (temp==0)
      sh->regs.SR.part.T=1;
   else
      sh->regs.SR.part.T=0;

   temp|=0x00000080;
   MappedMemoryWriteByte(sh->regs.R[n],temp);
   sh->regs.PC+=2;
   sh->cycles += 4;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2trapa(SH2_struct * sh)
{
   s32 imm = INSTRUCTION_CD(sh->instruction);

   sh->regs.R[15]-=4;
   MappedMemoryWriteLong(sh->regs.R[15],sh->regs.SR.all);
   sh->regs.R[15]-=4;
   MappedMemoryWriteLong(sh->regs.R[15],sh->regs.PC + 2);
   sh->regs.PC = MappedMemoryReadLong(sh->regs.VBR+(imm<<2));
   sh->cycles += 8;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2tst(SH2_struct * sh)
{
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   if ((sh->regs.R[n]&sh->regs.R[m])==0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;

   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2tsti(SH2_struct * sh)
{
   s32 temp;
   s32 i = INSTRUCTION_CD(sh->instruction);

   temp=sh->regs.R[0]&i;

   if (temp==0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;

   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2tstm(SH2_struct * sh)
{
   s32 temp;
   s32 i = INSTRUCTION_CD(sh->instruction);

   temp=(s32) MappedMemoryReadByte(sh->regs.GBR+sh->regs.R[0]);
   temp&=i;

   if (temp==0)
      sh->regs.SR.part.T = 1;
   else
      sh->regs.SR.part.T = 0;

   sh->regs.PC+=2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2y_xor(SH2_struct * sh)
{
   int b = INSTRUCTION_B(sh->instruction);
   int c = INSTRUCTION_C(sh->instruction);

   sh->regs.R[b] ^= sh->regs.R[c];
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2xori(SH2_struct * sh)
{
   s32 source = INSTRUCTION_CD(sh->instruction);
   sh->regs.R[0] ^= source;
   sh->regs.PC += 2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2xorm(SH2_struct * sh)
{
   s32 source = INSTRUCTION_CD(sh->instruction);
   s32 temp;

   temp = (s32) MappedMemoryReadByte(sh->regs.GBR + sh->regs.R[0]);
   temp ^= source;
   MappedMemoryWriteByte(sh->regs.GBR + sh->regs.R[0],temp);
   sh->regs.PC += 2;
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2xtrct(SH2_struct * sh)
{
   u32 temp;
   s32 m = INSTRUCTION_C(sh->instruction);
   s32 n = INSTRUCTION_B(sh->instruction);

   temp=(sh->regs.R[m]<<16)&0xFFFF0000;
   sh->regs.R[n]=(sh->regs.R[n]>>16)&0x0000FFFF;
   sh->regs.R[n]|=temp;
   sh->regs.PC+=2;
   sh->cycles++;
}

//////////////////////////////////////////////////////////////////////////////

static void FASTCALL SH2sleep(SH2_struct * sh)
{
   sh->cycles += 3;
}

//////////////////////////////////////////////////////////////////////////////

static opcodefunc decode(u16 instruction)
{
   switch (INSTRUCTION_A(instruction))
   {
      case 0:
         switch (INSTRUCTION_D(instruction))
         {
            case 2:
               switch (INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2stcsr;
                  case 1: return &SH2stcgbr;
                  case 2: return &SH2stcvbr;
                  default: return &SH2undecoded;
               }
     
            case 3:
               switch (INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2bsrf;
                  case 2: return &SH2braf;
                  default: return &SH2undecoded;
               }
     
            case 4: return &SH2movbs0;
            case 5: return &SH2movws0;
            case 6: return &SH2movls0;
            case 7: return &SH2mull;
            case 8:
               switch (INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2clrt;
                  case 1: return &SH2sett;
                  case 2: return &SH2clrmac;
                  default: return &SH2undecoded;
               }     
            case 9:
               switch (INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2nop;
                  case 1: return &SH2div0u;
                  case 2: return &SH2movt;
                  default: return &SH2undecoded;
               }     
            case 10:
               switch (INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2stsmach;
                  case 1: return &SH2stsmacl;
                  case 2: return &SH2stspr;
                  default: return &SH2undecoded;
               }     
            case 11:
               switch (INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2rts;
                  case 1: return &SH2sleep;
                  case 2: return &SH2rte;
                  default: return &SH2undecoded;
               }     
            case 12: return &SH2movbl0;
            case 13: return &SH2movwl0;
            case 14: return &SH2movll0;
            case 15: return &SH2macl;
            default: return &SH2undecoded;
         }
   
      case 1: return &SH2movls4;
      case 2:
         switch (INSTRUCTION_D(instruction))
         {
            case 0: return &SH2movbs;
            case 1: return &SH2movws;
            case 2: return &SH2movls;
            case 4: return &SH2movbm;
            case 5: return &SH2movwm;
            case 6: return &SH2movlm;
            case 7: return &SH2div0s;
            case 8: return &SH2tst;
            case 9: return &SH2y_and;
            case 10: return &SH2y_xor;
            case 11: return &SH2y_or;
            case 12: return &SH2cmpstr;
            case 13: return &SH2xtrct;
            case 14: return &SH2mulu;
            case 15: return &SH2muls;
            default: return &SH2undecoded;
         }
   
      case 3:
         switch(INSTRUCTION_D(instruction))
         {
            case 0:  return &SH2cmpeq;
            case 2:  return &SH2cmphs;
            case 3:  return &SH2cmpge;
            case 4:  return &SH2div1;
            case 5:  return &SH2dmulu;
            case 6:  return &SH2cmphi;
            case 7:  return &SH2cmpgt;
            case 8:  return &SH2sub;
            case 10: return &SH2subc;
            case 11: return &SH2subv;
            case 12: return &SH2add;
            case 13: return &SH2dmuls;
            case 14: return &SH2addc;
            case 15: return &SH2addv;
            default: return &SH2undecoded;
         }
   
      case 4:
         switch(INSTRUCTION_D(instruction))
         {
            case 0:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2shll;
                  case 1: return &SH2dt;
                  case 2: return &SH2shal;
                  default: return &SH2undecoded;
               }
            case 1:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2shlr;
                  case 1: return &SH2cmppz;
                  case 2: return &SH2shar;
                  default: return &SH2undecoded;
               }     
            case 2:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2stsmmach;
                  case 1: return &SH2stsmmacl;
                  case 2: return &SH2stsmpr;
                  default: return &SH2undecoded;
               }
            case 3:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2stcmsr;
                  case 1: return &SH2stcmgbr;
                  case 2: return &SH2stcmvbr;
                  default: return &SH2undecoded;
               }
            case 4:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2rotl;
                  case 2: return &SH2rotcl;
                  default: return &SH2undecoded;
               }     
            case 5:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2rotr;
                  case 1: return &SH2cmppl;
                  case 2: return &SH2rotcr;
                  default: return &SH2undecoded;
               }                 
            case 6:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2ldsmmach;
                  case 1: return &SH2ldsmmacl;
                  case 2: return &SH2ldsmpr;
                  default: return &SH2undecoded;
               }     
            case 7:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2ldcmsr;
                  case 1: return &SH2ldcmgbr;
                  case 2: return &SH2ldcmvbr;
                  default: return &SH2undecoded;
               }     
            case 8:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2shll2;
                  case 1: return &SH2shll8;
                  case 2: return &SH2shll16;
                  default: return &SH2undecoded;
               }     
            case 9:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2shlr2;
                  case 1: return &SH2shlr8;
                  case 2: return &SH2shlr16;
                  default: return &SH2undecoded;
               }     
            case 10:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2ldsmach;
                  case 1: return &SH2ldsmacl;
                  case 2: return &SH2ldspr;
                  default: return &SH2undecoded;
               }     
            case 11:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2jsr;
                  case 1: return &SH2tas;
                  case 2: return &SH2jmp;
                  default: return &SH2undecoded;
               }     
            case 14:
               switch(INSTRUCTION_C(instruction))
               {
                  case 0: return &SH2ldcsr;
                  case 1: return &SH2ldcgbr;
                  case 2: return &SH2ldcvbr;
                  default: return &SH2undecoded;
               }
            case 15: return &SH2macw;
            default: return &SH2undecoded;
         }
      case 5: return &SH2movll4;
      case 6:
         switch (INSTRUCTION_D(instruction))
         {
            case 0:  return &SH2movbl;
            case 1:  return &SH2movwl;
            case 2:  return &SH2movll;
            case 3:  return &SH2mov;
            case 4:  return &SH2movbp;
            case 5:  return &SH2movwp;
            case 6:  return &SH2movlp;
            case 7:  return &SH2y_not;
            case 8:  return &SH2swapb;
            case 9:  return &SH2swapw;
            case 10: return &SH2negc;
            case 11: return &SH2neg;
            case 12: return &SH2extub;
            case 13: return &SH2extuw;
            case 14: return &SH2extsb;
            case 15: return &SH2extsw;
         }
   
      case 7: return &SH2addi;
      case 8:
         switch (INSTRUCTION_B(instruction))
         {
            case 0:  return &SH2movbs4;
            case 1:  return &SH2movws4;
            case 4:  return &SH2movbl4;
            case 5:  return &SH2movwl4;
            case 8:  return &SH2cmpim;
            case 9:  return &SH2bt;
            case 11: return &SH2bf;
            case 13: return &SH2bts;
            case 15: return &SH2bfs;
            default: return &SH2undecoded;
         }   
      case 9: return &SH2movwi;
      case 10: return &SH2bra;
      case 11: return &SH2bsr;
      case 12:
         switch(INSTRUCTION_B(instruction))
         {
            case 0:  return &SH2movbsg;
            case 1:  return &SH2movwsg;
            case 2:  return &SH2movlsg;
            case 3:  return &SH2trapa;
            case 4:  return &SH2movblg;
            case 5:  return &SH2movwlg;
            case 6:  return &SH2movllg;
            case 7:  return &SH2mova;
            case 8:  return &SH2tsti;
            case 9:  return &SH2andi;
            case 10: return &SH2xori;
            case 11: return &SH2ori;
            case 12: return &SH2tstm;
            case 13: return &SH2andm;
            case 14: return &SH2xorm;
            case 15: return &SH2orm;
         }
   
      case 13: return &SH2movli;
      case 14: return &SH2movi;
      default: return &SH2undecoded;
   }
}

//////////////////////////////////////////////////////////////////////////////

int SH2InterpreterInit()
{
   int i;

   // Initialize any internal variables
   for(i = 0;i < 0x10000;i++)
      opcodes[i] = decode(i);

   for (i = 0; i < 0x100; i++)
   {
      switch (i)
      {
         case 0x000: // Bios              
            fetchlist[i] = FetchBios;
            break;
         case 0x002: // Low Work Ram
            fetchlist[i] = FetchLWram;
            break;
         case 0x020: // CS0
            fetchlist[i] = FetchCs0;
            break;
         case 0x060: // High Work Ram
         case 0x061: 
         case 0x062: 
         case 0x063: 
         case 0x064: 
         case 0x065: 
         case 0x066: 
         case 0x067: 
         case 0x068: 
         case 0x069: 
         case 0x06A: 
         case 0x06B: 
         case 0x06C: 
         case 0x06D: 
         case 0x06E: 
         case 0x06F:
            fetchlist[i] = FetchHWram;
            break;
         default:
            fetchlist[i] = FetchInvalid;
            break;
      }
   }
   
   SH2ClearCodeBreakpoints(MSH2);
   SH2ClearCodeBreakpoints(SSH2);
   SH2ClearMemoryBreakpoints(MSH2);
   SH2ClearMemoryBreakpoints(SSH2);
   MSH2->breakpointEnabled = 0;
   SSH2->breakpointEnabled = 0;  
   MSH2->backtraceEnabled = 0;
   SSH2->backtraceEnabled = 0;
   MSH2->stepOverOut.enabled = 0;
   SSH2->stepOverOut.enabled = 0;
   
   return 0;
}

int SH2DebugInterpreterInit() {

  SH2InterpreterInit();
  MSH2->breakpointEnabled = 1;
  SSH2->breakpointEnabled = 1;  
  MSH2->backtraceEnabled = 1;
  SSH2->backtraceEnabled = 1;
  return 0;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterDeInit()
{
   // DeInitialize any internal variables here
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterReset(UNUSED SH2_struct *context)
{
   // Reset any internal variables here
   context->stepOverOut.enabled = 0;
   context->stepOverOut.enabled = 0;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void SH2UBCInterrupt(SH2_struct *context, u32 flag)
{
   if (15 > context->regs.SR.part.I) // Since UBC's interrupt are always level 15
   {
      context->regs.R[15] -= 4;
      MappedMemoryWriteLong(context->regs.R[15], context->regs.SR.all);
      context->regs.R[15] -= 4;
      MappedMemoryWriteLong(context->regs.R[15], context->regs.PC);
      context->regs.SR.part.I = 15;
      context->regs.PC = MappedMemoryReadLong(context->regs.VBR + (12 << 2));
      LOG("interrupt successfully handled\n");
   }
   context->onchip.BRCR |= flag;
}

//////////////////////////////////////////////////////////////////////////////

static INLINE void SH2HandleInterrupts(SH2_struct *context)
{
   if (context->NumberOfInterrupts != 0)
   {
      if (context->interrupts[context->NumberOfInterrupts-1].level > context->regs.SR.part.I)
      {
         context->regs.R[15] -= 4;
         MappedMemoryWriteLong(context->regs.R[15], context->regs.SR.all);
         context->regs.R[15] -= 4;
         MappedMemoryWriteLong(context->regs.R[15], context->regs.PC);
         context->regs.SR.part.I = context->interrupts[context->NumberOfInterrupts-1].level;
         context->regs.PC = MappedMemoryReadLong(context->regs.VBR + (context->interrupts[context->NumberOfInterrupts-1].vector << 2));
         context->NumberOfInterrupts--;
         context->isIdle = 0;
         context->isSleeping = 0;
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

FASTCALL void SH2DebugInterpreterExec(SH2_struct *context, u32 cycles)
{
#ifdef SH2_TRACE
   /* Avoid accumulating leftover cycles multiple times, since the trace
    * code automatically adds state->cycles to the cycle accumulator when
    * printing a trace line */
   sh2_trace_add_cycles(-(context->cycles));
#endif

   SH2HandleInterrupts(context);

   while(context->cycles < cycles)
   {
#ifdef SH2_UBC   	   
      int ubcinterrupt=0, ubcflag=0;
#endif
	
      SH2HandleBreakpoints(context);

#ifdef SH2_TRACE
      sh2_trace(context, context->regs.PC);
#endif

#ifdef SH2_UBC
      if (context->onchip.BBRA & (BBR_CPA_CPU | BBR_IDA_INST | BBR_RWA_READ)) // Break on cpu, instruction, read cycles
      {
         if (context->onchip.BARA.all == (context->regs.PC & (~context->onchip.BAMRA.all)))
         {
            LOG("Trigger UBC A interrupt: PC = %08X\n", context->regs.PC);
            if (!(context->onchip.BRCR & BRCR_PCBA))
            {
               // Break before instruction fetch
	           SH2UBCInterrupt(context, BRCR_CMFCA);
            }
            else
            {
            	// Break after instruction fetch
               ubcinterrupt=1;
               ubcflag = BRCR_CMFCA;
            }
         }
      }
      else if(context->onchip.BBRB & (BBR_CPA_CPU | BBR_IDA_INST | BBR_RWA_READ)) // Break on cpu, instruction, read cycles
      {
         if (context->onchip.BARB.all == (context->regs.PC & (~context->onchip.BAMRB.all)))
         {
            LOG("Trigger UBC B interrupt: PC = %08X\n", context->regs.PC);
            if (!(context->onchip.BRCR & BRCR_PCBB))
            {
          	   // Break before instruction fetch
       	       SH2UBCInterrupt(context, BRCR_CMFCB);
            }
            else
            {
               // Break after instruction fetch
               ubcinterrupt=1;
               ubcflag = BRCR_CMFCB;
            }
         }
      }
#endif

      // Fetch Instruction
#ifdef EXEC_FROM_CACHE
      if ((context->regs.PC & 0xC0000000) == 0xC0000000) context->instruction = DataArrayReadWord(context->regs.PC);
      else
#endif
      context->instruction = fetchlist[(context->regs.PC >> 20) & 0x0FF](context->regs.PC);

      SH2HandleBackTrace(context);
      SH2HandleStepOverOut(context);
      SH2HandleTrackInfLoop(context);

      // Execute it
      opcodes[context->instruction](context);

		//if (MappedMemoryReadLong(0x06000930) == 0x00000009)
		if (context->regs.PC == 0x060273AA)
		{
			int test=0;
			test = 1;
		}

#ifdef SH2_UBC
	  if (ubcinterrupt)
	     SH2UBCInterrupt(context, ubcflag);
#endif
   }

#ifdef SH2_TRACE
   sh2_trace_add_cycles(context->cycles);
#endif
}

//////////////////////////////////////////////////////////////////////////////

FASTCALL void SH2InterpreterExec(SH2_struct *context, u32 cycles)
{
   SH2HandleInterrupts(context);

   if (context->isIdle)
      SH2idleParse(context, cycles);
   else
      SH2idleCheck(context, cycles);

   while(context->cycles < cycles)
   {
      // Fetch Instruction
      context->instruction = fetchlist[(context->regs.PC >> 20) & 0x0FF](context->regs.PC);

      // Execute it
      opcodes[context->instruction](context);
   }
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterGetRegisters(SH2_struct *context, sh2regs_struct *regs)
{
   memcpy(regs, &context->regs, sizeof(sh2regs_struct));
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetGPR(SH2_struct *context, int num)
{
    return context->regs.R[num];
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetSR(SH2_struct *context)
{
    return context->regs.SR.all;
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetGBR(SH2_struct *context)
{
    return context->regs.GBR;
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetVBR(SH2_struct *context)
{
    return context->regs.VBR;
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetMACH(SH2_struct *context)
{
    return context->regs.MACH;
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetMACL(SH2_struct *context)
{
    return context->regs.MACL;
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetPR(SH2_struct *context)
{
    return context->regs.PR;
}

//////////////////////////////////////////////////////////////////////////////

u32 SH2InterpreterGetPC(SH2_struct *context)
{
    return context->regs.PC;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetRegisters(SH2_struct *context, const sh2regs_struct *regs)
{
   memcpy(&context->regs, regs, sizeof(sh2regs_struct));
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetGPR(SH2_struct *context, int num, u32 value)
{
    context->regs.R[num] = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetSR(SH2_struct *context, u32 value)
{
    context->regs.SR.all = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetGBR(SH2_struct *context, u32 value)
{
    context->regs.GBR = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetVBR(SH2_struct *context, u32 value)
{
    context->regs.VBR = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetMACH(SH2_struct *context, u32 value)
{
    context->regs.MACH = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetMACL(SH2_struct *context, u32 value)
{
    context->regs.MACL = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetPR(SH2_struct *context, u32 value)
{
    context->regs.PR = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetPC(SH2_struct *context, u32 value)
{
    context->regs.PC = value;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSendInterrupt(SH2_struct *context, u8 vector, u8 level)
{
   u32 i, i2;
   interrupt_struct tmp;

   // Make sure interrupt doesn't already exist
   for (i = 0; i < context->NumberOfInterrupts; i++)
   {
      if (context->interrupts[i].vector == vector)
         return;
   }

   context->interrupts[context->NumberOfInterrupts].level = level;
   context->interrupts[context->NumberOfInterrupts].vector = vector;
   context->NumberOfInterrupts++;

   // Sort interrupts
   for (i = 0; i < (context->NumberOfInterrupts-1); i++)
   {
      for (i2 = i+1; i2 < context->NumberOfInterrupts; i2++)
      {
         if (context->interrupts[i].level > context->interrupts[i2].level)
         {
            tmp.level = context->interrupts[i].level;
            tmp.vector = context->interrupts[i].vector;
            context->interrupts[i].level = context->interrupts[i2].level;
            context->interrupts[i].vector = context->interrupts[i2].vector;
            context->interrupts[i2].level = tmp.level;
            context->interrupts[i2].vector = tmp.vector;
         }
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

int SH2InterpreterGetInterrupts(SH2_struct *context,
                                interrupt_struct interrupts[MAX_INTERRUPTS])
{
   memcpy(interrupts, context->interrupts, sizeof(interrupt_struct) * MAX_INTERRUPTS);
   return context->NumberOfInterrupts;
}

//////////////////////////////////////////////////////////////////////////////

void SH2InterpreterSetInterrupts(SH2_struct *context, int num_interrupts,
                                 const interrupt_struct interrupts[MAX_INTERRUPTS])
{
   memcpy(context->interrupts, interrupts, sizeof(interrupt_struct) * MAX_INTERRUPTS);
   context->NumberOfInterrupts = num_interrupts;
}

//////////////////////////////////////////////////////////////////////////////
