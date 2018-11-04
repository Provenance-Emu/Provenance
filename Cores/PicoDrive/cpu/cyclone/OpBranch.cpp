
// This file is part of the Cyclone 68000 Emulator

// Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
// Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/


#include "app.h"

// in/out address in r0, trashes all temp regs
static void CheckPc(void)
{
#if USE_CHECKPC_CALLBACK
 #ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bl %scheckpc ;@ Call checkpc()\n", MEMHANDLERS_DIRECT_PREFIX);
 #else
  ot(";@ Check Memory Base+pc\n");
  ot("  mov lr,pc\n");
  ot("  ldr pc,[r7,#0x64] ;@ Call checkpc()\n");
  ot("\n");
 #endif
#endif
}

// Push 32-bit value in r1 - trashes r0-r3,r12,lr
void OpPush32()
{
  ot(";@ Push r1 onto stack\n");
  ot("  ldr r0,[r7,#0x3c]\n");
  ot("  sub r0,r0,#4 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,2);
  ot("\n");
}

// Push SR - trashes r0-r3,r12,lr
void OpPushSr(int high)
{
  ot(";@ Push SR:\n");
  OpFlagsToReg(high);
  ot("  ldr r0,[r7,#0x3c]\n");
  ot("  sub r0,r0,#2 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,1);
  ot("\n");
}

// Pop SR - trashes r0-r3
static void PopSr(int high)
{
  ot(";@ Pop SR:\n");
  ot("  ldr r0,[r7,#0x3c]\n");
  ot("  add r1,r0,#2 ;@ Postincrement A7\n");
  ot("  str r1,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(0,1);
  ot("\n");
  OpRegToFlags(high);
}

// Pop PC - trashes r0-r3
static void PopPc()
{
  ot(";@ Pop PC:\n");
  ot("  ldr r0,[r7,#0x3c]\n");
  ot("  add r1,r0,#4 ;@ Postincrement A7\n");
  ot("  str r1,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(0,2);
  ot("  ldr r1,[r7,#0x60] ;@ Get Memory base\n");
  ot("  add r0,r0,r1 ;@ Memory Base+PC\n");
  ot("\n");
  CheckPc();
#if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  mov r4,r0\n");
#else
  ot("  bic r4,r0,#1\n");
#endif
}

int OpTrap(int op)
{
  int use=0;

  use=op&~0xf;
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,0x10);
  ot("  and r0,r8,#0xf ;@ Get trap number\n");
  ot("  orr r0,r0,#0x20 ;@ 32+n\n");
  ot("  bl Exception\n");
  ot("\n");

  Cycles=38; OpEnd(0x10);

  return 0;
}

// --------------------- Opcodes 0x4e50+ ---------------------
int OpLink(int op)
{
  int use=0,reg;

  use=op&~7;
  reg=op&7;
  if (reg==7) use=op;
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,0x10);

  if(reg!=7) {
    ot(";@ Get An\n");
    EaCalc(11, 7, 8, 2, 1);
    EaRead(11, 1, 8, 2, 7, 1);
  }

  ot("  ldr r0,[r7,#0x3c] ;@ Get A7\n");
  ot("  sub r0,r0,#4 ;@ A7-=4\n");
  ot("  mov r8,r0 ;@ abuse r8\n");
  if(reg==7) ot("  mov r1,r0\n");
  ot("\n");
  
  ot(";@ Write An to Stack\n");
  MemHandler(1,2);

  ot(";@ Save to An\n");
  if(reg!=7)
    EaWrite(11,8, 8, 2, 7, 1);

  ot(";@ Get offset:\n");
  EaCalc(0,0,0x3c,1);    // abused r8 is ok because of imm EA
  EaRead(0,0,0x3c,1,0);

  ot("  add r8,r8,r0 ;@ Add offset to A7\n");
  ot("  str r8,[r7,#0x3c]\n");
  ot("\n");

  Cycles=16;
  OpEnd(0x10);
  return 0;
}

// --------------------- Opcodes 0x4e58+ ---------------------
int OpUnlk(int op)
{
  int use=0;

  use=op&~7;
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,0x10);

  ot(";@ Get An\n");
  EaCalc(11, 0xf, 8, 2,   1);
  EaRead(11,   0, 8, 2, 0xf, 1);

  ot("  add r8,r0,#4 ;@ A7+=4, abuse r8\n");
  ot("\n");
  ot(";@ Pop An from stack:\n");
  MemHandler(0,2);
  ot("\n");
  ot("  str r8,[r7,#0x3c] ;@ Save A7\n");
  ot("\n");
  ot(";@ An = value from stack:\n");
  EaWrite(11, 0, 8, 2, 7, 1);

  Cycles=12;
  OpEnd(0x10);
  return 0;
}

// --------------------- Opcodes 0x4e70+ ---------------------
// 01001110 01110ttt
int Op4E70(int op)
{
  int type=0;

  type=op&7; // reset/nop/stop/rte/rtd/rts/trapv/rtr

  switch (type)
  {
    case 1:  // nop
    OpStart(op);
    Cycles=4;
    OpEnd();
    return 0;

    case 3: // rte
    OpStart(op,0x10,0,0,1); Cycles=20;
    PopSr(1);
    PopPc();
    ot("  ldr r1,[r7,#0x44] ;@ reload SR high\n");
    SuperChange(op,1);
#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO || EMULATE_HALT
    ot("  ldr r1,[r7,#0x58]\n");
    ot("  bic r1,r1,#0x0c ;@ clear 'not processing instruction' and 'doing addr error' bits\n");
    ot("  str r1,[r7,#0x58]\n");
#endif
#if EMULATE_ADDRESS_ERRORS_JUMP
    ot("  tst r4,#1 ;@ address error?\n");
    ot("  bne ExceptionAddressError_r_prg_r4\n");
#endif
    opend_check_interrupt = 1;
    opend_check_trace = 1;
    OpEnd(0x10,0);
    return 0;

    case 5: // rts
    OpStart(op,0x10); Cycles=16;
    PopPc();
#if EMULATE_ADDRESS_ERRORS_JUMP
    ot("  tst r4,#1 ;@ address error?\n");
    ot("  bne ExceptionAddressError_r_prg_r4\n");
#endif
    OpEnd(0x10);
    return 0;

    case 6: // trapv
    OpStart(op,0x10,0,1); Cycles=4;
    ot("  tst r10,#0x10000000\n");
    ot("  subne r5,r5,#%i\n",34);
    ot("  movne r0,#7 ;@ TRAPV exception\n");
    ot("  blne Exception\n");
    opend_op_changes_cycles = 1;
    OpEnd(0x10,0);
    return 0;

    case 7: // rtr
    OpStart(op,0x10); Cycles=20;
    PopSr(0);
    PopPc();
#if EMULATE_ADDRESS_ERRORS_JUMP
    ot("  tst r4,#1 ;@ address error?\n");
    ot("  bne ExceptionAddressError_r_prg_r4\n");
#endif
    OpEnd(0x10);
    return 0;

    default:
    return 1;
  }
}

// --------------------- Opcodes 0x4e80+ ---------------------
// Emit a Jsr/Jmp opcode, 01001110 1meeeeee
int OpJsr(int op)
{
  int use=0;
  int sea=0;

  sea=op&0x003f;

  // See if we can do this opcode:
  if (EaCanRead(sea,-1)==0) return 1;

  use=OpBase(op,0);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,(op&0x40)?0:0x10);

  ot("  ldr r11,[r7,#0x60] ;@ Get Memory base\n");
  ot("\n");
  EaCalc(12,0x003f,sea,0);

  ot(";@ Jump - Get new PC from r12\n");
  ot("  add r0,r12,r11 ;@ Memory Base + New PC\n");
  ot("\n");
  CheckPc();
  if (!(op&0x40))
  {
    ot("  ldr r2,[r7,#0x3c]\n");
    ot("  sub r1,r4,r11 ;@ r1 = Old PC\n");
  }
#if EMULATE_ADDRESS_ERRORS_JUMP
  // jsr prefetches next instruction before pushing old PC,
  // according to http://pasti.fxatari.com/68kdocs/68kPrefetch.html
  ot("  mov r4,r0\n");
  ot("  tst r4,#1 ;@ address error?\n");
  ot("  bne ExceptionAddressError_r_prg_r4\n");
#else
  ot("  bic r4,r0,#1\n");
#endif

  if (!(op&0x40))
  {
    ot(";@ Push old PC onto stack\n");
    ot("  sub r0,r2,#4 ;@ Predecrement A7\n");
    ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
    MemHandler(1,2);
  }

  Cycles=(op&0x40) ? 4 : 12;
  Cycles+=Ea_add_ns((op&0x40) ? g_jmp_cycle_table : g_jsr_cycle_table, sea);

  OpEnd((op&0x40)?0:0x10);

  return 0;
}

// --------------------- Opcodes 0x50c8+ ---------------------

// ARM version of 68000 condition codes:
static const char * const Cond[16]=
{
  "",  "",  "hi","ls","cc","cs","ne","eq",
  "vc","vs","pl","mi","ge","lt","gt","le"
};

// Emit a Dbra opcode, 0101cccc 11001nnn vv
int OpDbra(int op)
{
  const char *cond;
  int use=0;
  int cc=0;

  use=op&~7; // Use same handler
  cc=(op>>8)&15;
  
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler
  OpStart(op);

  if (cc>=2)
  {
    ot(";@ Is the condition true?\n");
    cond=TestCond(cc);
    ot(";@ If so, don't dbra\n");
    ot("  b%s DbraTrue\n\n",cond);
  }

  if (cc!=0)
  {
    ot(";@ Decrement Dn.w\n");
    ot("  and r1,r8,#0x0007\n");
    ot("  mov r1,r1,lsl #2\n");
    ot("  ldrsh r0,[r7,r1]\n");
    ot("  strb r8,[r7,#0x45] ;@ not polling\n");
    ot("  sub r0,r0,#1\n");
    ot("  strh r0,[r7,r1]\n");
    ot("\n");

    ot(";@ Check if Dn.w is -1\n");
    ot("  cmn r0,#1\n");

#if (USE_CHECKPC_CALLBACK && USE_CHECKPC_DBRA) || EMULATE_ADDRESS_ERRORS_JUMP
    ot("  beq DbraMin1\n");
    ot("\n");

    ot(";@ Get Branch offset:\n");
    ot("  ldrsh r0,[r4]\n");
    ot("  add r0,r4,r0 ;@ r0 = New PC\n");
    CheckPc();
#if EMULATE_ADDRESS_ERRORS_JUMP
    ot("  mov r4,r0\n");
    ot("  tst r4,#1 ;@ address error?\n");
    ot("  bne ExceptionAddressError_r_prg_r4\n");
#else
    ot("  bic r4,r0,#1\n");
#endif
#else
    ot("\n");
    ot(";@ Get Branch offset:\n");
    ot("  ldrnesh r0,[r4]\n");
    ot("  addeq r4,r4,#2 ;@ Skip branch offset\n");
    ot("  subeq r5,r5,#4 ;@ additional cycles\n");
    ot("  addne r4,r4,r0 ;@ r4 = New PC\n");
    ot("  bic r4,r4,#1\n"); // we do not emulate address errors
    ot("\n");
#endif
    Cycles=12-2;
    OpEnd();
  }
  
  //if (cc==0||cc>=2)
  if (op==0x50c8)
  {
    ot(";@ condition true:\n");
    ot("DbraTrue%s\n", ms?"":":");
    ot("  add r4,r4,#2 ;@ Skip branch offset\n");
    ot("\n");
    Cycles=12;
    OpEnd();
  }

#if (USE_CHECKPC_CALLBACK && USE_CHECKPC_DBRA) || EMULATE_ADDRESS_ERRORS_JUMP
  if (op==0x51c8)
  {
    ot(";@ Dn.w is -1:\n");
    ot("DbraMin1%s\n", ms?"":":");
    ot("  add r4,r4,#2 ;@ Skip branch offset\n");
    ot("\n");
    Cycles=12+2;
    OpEnd();
  }
#endif

  return 0;
}

// --------------------- Opcodes 0x6000+ ---------------------
// Emit a Branch opcode 0110cccc nn  (cccc=condition)
int OpBranch(int op)
{
  int size=0,use=0,checkpc=0;
  int offset=0;
  int cc=0;
  const char *asr_r11="";
  const char *cond;
  int pc_reg=0;

  offset=(char)(op&0xff);
  cc=(op>>8)&15;

  // Special offsets:
  if (offset==0)  size=1;
  if (offset==-1) size=2;

  if (size==2) size=0; // 000 model does not support long displacement
  if (size) use=op; // 16-bit or 32-bit
  else use=(op&0xff01)+2; // Use same opcode for all 8-bit branches

  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler
  OpStart(op,size?0x10:0);
  Cycles=10; // Assume branch taken

  if (cc>=2)
  {
    cond=TestCond(cc,1);
    ot("  b%s BccDontBranch%i\n\n",cond,8<<size);
  }

  if (size) 
  {
    if (size<2)
    {
      ot("  ldrsh r11,[r4] ;@ Fetch Branch offset\n");
    }
    else
    {
      ot("  ldrh r2,[r4] ;@ Fetch Branch offset\n");
      ot("  ldrh r11,[r4,#2]\n");
      ot("  orr r11,r11,r2,lsl #16\n");
    }
  }
  else
  {
    ot("  mov r11,r8,asl #24 ;@ Shift 8-bit signed offset up...\n\n");
    asr_r11=",asr #24";
  }

  ot(";@ Branch taken - Add on r0 to PC\n");

  if (cc==1)
  {
    ot(";@ Bsr - remember old PC\n");
    ot("  ldr r12,[r7,#0x60] ;@ Get Memory base\n");
    ot("  ldr r2,[r7,#0x3c]\n");
    ot("  sub r1,r4,r12 ;@ r1 = Old PC\n");
    if (size) ot("  add r1,r1,#%d\n",1<<size);
    ot("\n");
    ot(";@ Push r1 onto stack\n");
    ot("  sub r0,r2,#4 ;@ Predecrement A7\n");
    ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
    MemHandler(1,2);
    ot("\n");
    Cycles=18; // always 18
  }

#if USE_CHECKPC_CALLBACK && USE_CHECKPC_OFFSETBITS_8
  if (offset!=0 && offset!=-1) checkpc=1;
#endif
#if USE_CHECKPC_CALLBACK && USE_CHECKPC_OFFSETBITS_16
  if (offset==0)  checkpc=1;
#endif
#if USE_CHECKPC_CALLBACK
  if (offset==-1) checkpc=1;
#endif
  if (checkpc)
  {
    ot("  add r0,r4,r11%s ;@ New PC\n",asr_r11);
    CheckPc();
    pc_reg=0;
  }
  else
  {
    ot("  add r4,r4,r11%s ;@ r4 = New PC\n",asr_r11);
    pc_reg=4;
  }

  if ((op & 1) || size != 0)
  {
#if EMULATE_ADDRESS_ERRORS_JUMP
    if (pc_reg!=4)
    {
      ot("  mov r4,r%d\n",pc_reg);
      pc_reg=4;
    }
    if (size)
    {
      ot("  tst r4,#1 ;@ address error?\n");
      ot("  bne ExceptionAddressError_r_prg_r4\n");
    }
    else
    {
      ot("  b ExceptionAddressError_r_prg_r4\n");
    }
#else
    ot("  bic r4,r%d,#1\n",pc_reg);
    pc_reg=4;
#endif
  }
  if (pc_reg!=4)
    ot("  mov r4,r%d\n",pc_reg);
  ot("\n");

  OpEnd(size?0x10:0);

  // since all "DontBranch" code is same for every size, output only once
  if (cc>=2&&(op&0xff01)==0x6700)
  {
    ot("BccDontBranch%i%s\n", 8<<size, ms?"":":");
    if (size) ot("  add r4,r4,#%d\n",1<<size);
    Cycles+=(size==1) ? 2 : -2; // Branch not taken
    OpEnd(0);
  }

  return 0;
}

