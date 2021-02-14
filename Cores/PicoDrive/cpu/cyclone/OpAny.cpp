
// This file is part of the Cyclone 68000 Emulator

// Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
// Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/


#include "app.h"

int opend_op_changes_cycles, opend_check_interrupt, opend_check_trace;

static unsigned char OpData[16]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

static unsigned short OpRead16(unsigned int a)
{
  return (unsigned short)( (OpData[a&15]<<8) | OpData[(a+1)&15] );
}

// For opcode 'op' use handler 'use'
void OpUse(int op,int use)
{
  char text[64]="";
  CyJump[op]=use;

  if (op!=use) return;

  // Disassemble opcode
  DisaPc=0;
  DisaText=text;
  DisaWord=OpRead16;

  DisaGet();
  ot(";@ ---------- [%.4x] %s uses Op%.4x ----------\n",op,text,use);
}

void OpStart(int op, int sea, int tea, int op_changes_cycles, int supervisor_check)
{
  int last_op_count=arm_op_count;

  Cycles=0;
  OpUse(op,op); // This opcode obviously uses this handler
  ot("Op%.4x%s\n", op, ms?"":":");

  if (supervisor_check)
  {
    // checks for supervisor bit, if not set, jumps to SuperEnd()
    // also sets r11 to SR high value, SuperChange() uses this
    ot("  ldr r11,[r7,#0x44] ;@ Get SR high\n");
  }
  if ((sea >= 0x10 && sea != 0x3c) || (tea >= 0x10 && tea != 0x3c))
  {
#if MEMHANDLERS_NEED_PREV_PC
    ot("  str r4,[r7,#0x50] ;@ Save prev PC + 2\n");
#endif
#if MEMHANDLERS_NEED_CYCLES
    ot("  str r5,[r7,#0x5c] ;@ Save Cycles\n");
#endif
  }
  if (supervisor_check)
  {
    ot("  tst r11,#0x20 ;@ Check we are in supervisor mode\n");
    ot("  beq WrongPrivilegeMode ;@ No\n");
  }
  if ((sea >= 0x10 && sea != 0x3c) || (tea >= 0x10 && tea != 0x3c)) {
#if MEMHANDLERS_CHANGE_CYCLES
    if (op_changes_cycles)
      ot("  mov r5,#0\n");
#endif
  }
  if (last_op_count!=arm_op_count)
    ot("\n");
  pc_dirty = 1;
  opend_op_changes_cycles = opend_check_interrupt = opend_check_trace = 0;
}

void OpEnd(int sea, int tea)
{
  int did_fetch=0;
  opend_check_trace = opend_check_trace && EMULATE_TRACE;
#if MEMHANDLERS_CHANGE_CYCLES
  if ((sea >= 0x10 && sea != 0x3c) || (tea >= 0x10 && tea != 0x3c))
  {
    if (opend_op_changes_cycles)
    {
      ot("  ldr r0,[r7,#0x5c] ;@ Load Cycles\n");
      ot("  ldrh r8,[r4],#2 ;@ Fetch next opcode\n");
      ot("  add r5,r0,r5\n");
      did_fetch=1;
    }
    else
    {
      ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
    }
  }
#endif
  if (!did_fetch)
    ot("  ldrh r8,[r4],#2 ;@ Fetch next opcode\n");
  if (opend_check_trace)
    ot("  ldr r1,[r7,#0x44]\n");
  ot("  subs r5,r5,#%d ;@ Subtract cycles\n",Cycles);
  if (opend_check_trace)
  {
    ot(";@ CheckTrace:\n");
    ot("  tst r1,#0x80\n");
    ot("  bne CycloneDoTraceWithChecks\n");
    ot("  cmp r5,#0\n");
  }
  if (opend_check_interrupt)
  {
    ot("  ble CycloneEnd\n");
    ot(";@ CheckInterrupt:\n");
    if (!opend_check_trace)
      ot("  ldr r1,[r7,#0x44]\n");
    ot("  movs r0,r1,lsr #24 ;@ Get IRQ level\n"); // same as  ldrb r0,[r7,#0x47]
    ot("  ldreq pc,[r6,r8,asl #2] ;@ Jump to next opcode handler\n");
    ot("  cmp r0,#6 ;@ irq>6 ?\n");
    ot("  andle r1,r1,#7 ;@ Get interrupt mask\n");
    ot("  cmple r0,r1 ;@ irq<=6: Is irq<=mask ?\n");
    ot("  ldrle pc,[r6,r8,asl #2] ;@ Jump to next opcode handler\n");
    ot("  b CycloneDoInterruptGoBack\n");
  }
  else
  {
    ot("  ldrgt pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
    ot("  b CycloneEnd\n");
  }
  ot("\n");
}

int OpBase(int op,int size,int sepa)
{
  int ea=op&0x3f; // Get Effective Address
  if (ea<0x10) return sepa?(op&~0x7):(op&~0xf); // Use 1 handler for d0-d7 and a0-a7
  if (size==0&&(ea==0x1f || ea==0x27)) return op; // Specific handler for (a7)+ and -(a7)
  if (ea<0x38) return op&~7;   // Use 1 handler for (a0)-(a7), etc...
  return op;
}

// Get flags, trashes r2
int OpGetFlags(int subtract,int xbit,int specialz)
{
  if (specialz) ot("  orr r2,r10,#0xb0000000 ;@ for old Z\n");

  ot("  mrs r10,cpsr ;@ r10=flags\n");

  if (specialz) ot("  andeq r10,r10,r2 ;@ fix Z\n");

  if (subtract) ot("  eor r10,r10,#0x20000000 ;@ Invert carry\n");

  if (xbit)
  {
    ot("  str r10,[r7,#0x4c] ;@ Save X bit\n");
  }
  return 0;
}

void OpGetFlagsNZ(int rd)
{
  ot("  and r10,r%d,#0x80000000 ;@ r10=N_flag\n",rd);
  ot("  orreq r10,r10,#0x40000000 ;@ get NZ, clear CV\n");
}

// -----------------------------------------------------------------

int g_op;

void OpAny(int op)
{
  memset(OpData,0x33,sizeof(OpData));
  OpData[0]=(unsigned char)(op>>8);
  OpData[1]=(unsigned char)op;
  g_op=op;

  if ((op&0xf100)==0x0000) OpArith(op);    // +
  if ((op&0xc000)==0x0000) OpMove(op);     // +
  if ((op&0xf5bf)==0x003c) OpArithSr(op);  // + Ori/Andi/Eori $nnnn,sr
  if ((op&0xf100)==0x0100) OpBtstReg(op);  // +
  if ((op&0xf138)==0x0108) OpMovep(op);    // +
  if ((op&0xff00)==0x0800) OpBtstImm(op);  // +
  if ((op&0xf900)==0x4000) OpNeg(op);      // +
  if ((op&0xf140)==0x4100) OpChk(op);      // +
  if ((op&0xf1c0)==0x41c0) OpLea(op);      // +
  if ((op&0xf9c0)==0x40c0) OpMoveSr(op);   // +
  if ((op&0xffc0)==0x4800) OpNbcd(op);     // +
  if ((op&0xfff8)==0x4840) OpSwap(op);     // +
  if ((op&0xffc0)==0x4840) OpPea(op);      // +
  if ((op&0xffb8)==0x4880) OpExt(op);      // +
  if ((op&0xfb80)==0x4880) OpMovem(op);    // +
  if ((op&0xff00)==0x4a00) OpTst(op);      // +
  if ((op&0xffc0)==0x4ac0) OpTas(op);      // +
  if ((op&0xfff0)==0x4e40) OpTrap(op);     // +
  if ((op&0xfff8)==0x4e50) OpLink(op);     // +
  if ((op&0xfff8)==0x4e58) OpUnlk(op);     // +
  if ((op&0xfff0)==0x4e60) OpMoveUsp(op);  // +
  if ((op&0xfff8)==0x4e70) Op4E70(op);     // + Reset/Rts etc
  if ((op&0xfffd)==0x4e70) OpStopReset(op);// +
  if ((op&0xff80)==0x4e80) OpJsr(op);      // +
  if ((op&0xf000)==0x5000) OpAddq(op);     // +
  if ((op&0xf0c0)==0x50c0) OpSet(op);      // +
  if ((op&0xf0f8)==0x50c8) OpDbra(op);     // +
  if ((op&0xf000)==0x6000) OpBranch(op);   // +
  if ((op&0xf100)==0x7000) OpMoveq(op);    // +
  if ((op&0xa000)==0x8000) OpArithReg(op); // + Or/Sub/And/Add
  if ((op&0xb1f0)==0x8100) OpAbcd(op);     // +
  if ((op&0xb0c0)==0x80c0) OpMul(op);      // +
  if ((op&0x90c0)==0x90c0) OpAritha(op);   // +
  if ((op&0xb130)==0x9100) OpAddx(op);     // +
  if ((op&0xf000)==0xb000) OpCmpEor(op);   // +
  if ((op&0xf138)==0xb108) OpCmpm(op);     // +
  if ((op&0xf130)==0xc100) OpExg(op);      // +
  if ((op&0xf000)==0xe000) OpAsr(op);      // + Asr/l/Ror/l etc
  if ((op&0xf8c0)==0xe0c0) OpAsrEa(op);    // +

  if (op==0xffff)
  {
    SuperEnd();
  }
}

