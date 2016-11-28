
// This file is part of the Cyclone 68000 Emulator

// Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
// Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/


#include "app.h"

// trashes r0
const char *TestCond(int m68k_cc, int invert)
{
  const char *cond="";
  const char *icond="";

  // ARM: NZCV
  switch (m68k_cc)
  {
    case 0x00: // T
    case 0x01: // F
      break;
    case 0x02: // hi
      ot("  tst r10,#0x60000000 ;@ hi: !C && !Z\n");
      cond="eq", icond="ne";
      break;
    case 0x03: // ls
      ot("  tst r10,#0x60000000 ;@ ls: C || Z\n");
      cond="ne", icond="eq";
      break;
    case 0x04: // cc
      ot("  tst r10,#0x20000000 ;@ cc: !C\n");
      cond="eq", icond="ne";
      break;
    case 0x05: // cs
      ot("  tst r10,#0x20000000 ;@ cs: C\n");
      cond="ne", icond="eq";
      break;
    case 0x06: // ne
      ot("  tst r10,#0x40000000 ;@ ne: !Z\n");
      cond="eq", icond="ne";
      break;
    case 0x07: // eq
      ot("  tst r10,#0x40000000 ;@ eq: Z\n");
      cond="ne", icond="eq";
      break;
    case 0x08: // vc
      ot("  tst r10,#0x10000000 ;@ vc: !V\n");
      cond="eq", icond="ne";
      break;
    case 0x09: // vs
      ot("  tst r10,#0x10000000 ;@ vs: V\n");
      cond="ne", icond="eq";
      break;
    case 0x0a: // pl
      ot("  tst r10,r10 ;@ pl: !N\n");
      cond="pl", icond="mi";
      break;
    case 0x0b: // mi
      ot("  tst r10,r10 ;@ mi: N\n");
      cond="mi", icond="pl";
      break;
    case 0x0c: // ge
      ot("  teq r10,r10,lsl #3 ;@ ge: N == V\n");
      cond="pl", icond="mi";
      break;
    case 0x0d: // lt
      ot("  teq r10,r10,lsl #3 ;@ lt: N != V\n");
      cond="mi", icond="pl";
      break;
    case 0x0e: // gt
      ot("  eor r0,r10,r10,lsl #3 ;@ gt: !Z && N == V\n");
      ot("  orrs r0,r10,lsl #1\n");
      cond="pl", icond="mi";
      break;
    case 0x0f: // le
      ot("  eor r0,r10,r10,lsl #3 ;@ le: Z || N != V\n");
      ot("  orrs r0,r10,lsl #1\n");
      cond="mi", icond="pl";
      break;
    default:
      printf("invalid m68k_cc: %x\n", m68k_cc);
      exit(1);
      break;
  }
  return invert?icond:cond;
}

// --------------------- Opcodes 0x0100+ ---------------------
// Emit a Btst (Register) opcode 0000nnn1 ttaaaaaa
int OpBtstReg(int op)
{
  int use=0;
  int type=0,sea=0,tea=0;
  int size=0;

  type=(op>>6)&3; // Btst/Bchg/Bclr/Bset
  // Get source and target EA
  sea=(op>>9)&7;
  tea=op&0x003f;
  if (tea<0x10) size=2; // For registers, 32-bits

  if ((tea&0x38)==0x08) return 1; // movep

  // See if we can do this opcode:
  if (EaCanRead(tea,0)==0) return 1;
  if (type>0)
  {
    if (EaCanWrite(tea)==0) return 1;
  }

  use=OpBase(op,size);
  use&=~0x0e00; // Use same handler for all registers
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,tea);

  if(type==1||type==3) {
    Cycles=8;
  } else {
    Cycles=type?8:4;
    if(size>=2) Cycles+=2;
  }

  EaCalcReadNoSE(-1,11,sea,0,0x0e00);

  EaCalcReadNoSE((type>0)?8:-1,0,tea,size,0x003f);

  if (tea>=0x10)
       ot("  and r11,r11,#7  ;@ mem - do mod 8\n");  // size always 0
  else ot("  and r11,r11,#31 ;@ reg - do mod 32\n"); // size always 2
  ot("\n");

  ot("  mov r1,#1\n");
  ot("  tst r0,r1,lsl r11 ;@ Do arithmetic\n");
  ot("  bicne r10,r10,#0x40000000\n");
  ot("  orreq r10,r10,#0x40000000 ;@ Get Z flag\n");
  ot("\n");

  if (type>0)
  {
    if (type==1) ot("  eor r1,r0,r1,lsl r11 ;@ Toggle bit\n");
    if (type==2) ot("  bic r1,r0,r1,lsl r11 ;@ Clear bit\n");
    if (type==3) ot("  orr r1,r0,r1,lsl r11 ;@ Set bit\n");
    ot("\n");
    EaWrite(8,1,tea,size,0x003f,0,0);
  }
  OpEnd(tea);

  return 0;
}

// --------------------- Opcodes 0x0800+ ---------------------
// Emit a Btst/Bchg/Bclr/Bset (Immediate) opcode 00001000 ttaaaaaa nn
int OpBtstImm(int op)
{
  int type=0,sea=0,tea=0;
  int use=0;
  int size=0;

  type=(op>>6)&3;
  // Get source and target EA
  sea=   0x003c;
  tea=op&0x003f;
  if (tea<0x10) size=2; // For registers, 32-bits

  // See if we can do this opcode:
  if (EaCanRead(tea,0)==0||EaAn(tea)||tea==0x3c) return 1;
  if (type>0)
  {
    if (EaCanWrite(tea)==0) return 1;
  }

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea,tea);

  ot("\n");
  EaCalcReadNoSE(-1,0,sea,0,0);
  ot("  mov r11,#1\n");
  ot("  bic r10,r10,#0x40000000 ;@ Blank Z flag\n");
  if (tea>=0x10)
       ot("  and r0,r0,#7    ;@ mem - do mod 8\n");  // size always 0
  else ot("  and r0,r0,#0x1F ;@ reg - do mod 32\n"); // size always 2
  ot("  mov r11,r11,lsl r0 ;@ Make bit mask\n");
  ot("\n");

  if(type==1||type==3) {
    Cycles=12;
  } else {
    Cycles=type?12:8;
    if(size>=2) Cycles+=2;
  }

  EaCalcReadNoSE((type>0)?8:-1,0,tea,size,0x003f);
  ot("  tst r0,r11 ;@ Do arithmetic\n");
  ot("  orreq r10,r10,#0x40000000 ;@ Get Z flag\n");
  ot("\n");

  if (type>0)
  {
    if (type==1) ot("  eor r1,r0,r11 ;@ Toggle bit\n");
    if (type==2) ot("  bic r1,r0,r11 ;@ Clear bit\n");
    if (type==3) ot("  orr r1,r0,r11 ;@ Set bit\n");
    ot("\n");
    EaWrite(8,   1,tea,size,0x003f,0,0);
#if CYCLONE_FOR_GENESIS && !MEMHANDLERS_CHANGE_CYCLES
    // this is a bit hacky (device handlers might modify cycles)
    if (tea==0x38||tea==0x39)
      ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
#endif
  }

  OpEnd(sea,tea);

  return 0;
}

// --------------------- Opcodes 0x4000+ ---------------------
int OpNeg(int op)
{
  // 01000tt0 xxeeeeee (tt=negx/clr/neg/not, xx=size, eeeeee=EA)
  int type=0,size=0,ea=0,use=0;

  type=(op>>9)&3;
  ea  =op&0x003f;
  size=(op>>6)&3; if (size>=3) return 1;

  // See if we can do this opcode:
  if (EaCanRead (ea,size)==0||EaAn(ea)) return 1;
  if (EaCanWrite(ea     )==0) return 1;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea); Cycles=size<2?4:6;
  if(ea >= 0x10)  Cycles*=2;

  EaCalc (11,0x003f,ea,size,0,0);

  if (type!=1) EaRead (11,0,ea,size,0x003f,0,0); // Don't need to read for 'clr' (or do we, for a dummy read?)
  if (type==1) ot("\n");

  if (type==0)
  {
    ot(";@ Negx:\n");
    GetXBit(1);
    if(size!=2) ot("  mov r0,r0,asl #%i\n",size?16:24);
    ot("  rscs r1,r0,#0 ;@ do arithmetic\n");
    ot("  orr r3,r10,#0xb0000000 ;@ for old Z\n");
    OpGetFlags(1,1,0);
    if(size!=2) {
      ot("  movs r1,r1,asr #%i\n",size?16:24);
      ot("  orreq r10,r10,#0x40000000 ;@ possily missed Z\n");
    }
    ot("  andeq r10,r10,r3 ;@ fix Z\n");
    ot("\n");
  }

  if (type==1)
  {
    ot(";@ Clear:\n");
    ot("  mov r1,#0\n");
    ot("  mov r10,#0x40000000 ;@ NZCV=0100\n");
    ot("\n");
  }

  if (type==2)
  {
    ot(";@ Neg:\n");
    if(size!=2) ot("  mov r0,r0,asl #%i\n",size?16:24);
    ot("  rsbs r1,r0,#0\n");
    OpGetFlags(1,1);
    if(size!=2) ot("  mov r1,r1,asr #%i\n",size?16:24);
    ot("\n");
  }

  if (type==3)
  {
    ot(";@ Not:\n");
    if(size!=2) {
      ot("  mov r0,r0,asl #%i\n",size?16:24);
      ot("  mvns r1,r0,asr #%i\n",size?16:24);
    }
    else
      ot("  mvns r1,r0\n");
    OpGetFlagsNZ(1);
    ot("\n");
  }

  if (type==1) eawrite_check_addrerr=1;
  EaWrite(11,     1,ea,size,0x003f,0,0);

  OpEnd(ea);

  return 0;
}

// --------------------- Opcodes 0x4840+ ---------------------
// Swap, 01001000 01000nnn swap Dn
int OpSwap(int op)
{
  int ea=0,use=0;

  ea=op&7;
  use=op&~0x0007; // Use same opcode for all An

  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op); Cycles=4;

  EaCalc (11,0x0007,ea,2,1);
  EaRead (11,     0,ea,2,0x0007,1);

  ot("  movs r1,r0,ror #16\n");
  OpGetFlagsNZ(1);

  EaWrite(11,     1,8,2,0x0007,1);

  OpEnd();

  return 0;
}

// --------------------- Opcodes 0x4a00+ ---------------------
// Emit a Tst opcode, 01001010 xxeeeeee
int OpTst(int op)
{
  int sea=0;
  int size=0,use=0;

  sea=op&0x003f;
  size=(op>>6)&3; if (size>=3) return 1;

  // See if we can do this opcode:
  if (EaCanWrite(sea)==0||EaAn(sea)) return 1;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea); Cycles=4;

  EaCalc (0,0x003f,sea,size,1);
  EaRead (0,     0,sea,size,0x003f,1,0,1);

  OpGetFlagsNZ(0);
  ot("\n");

  OpEnd(sea);
  return 0;
}

// --------------------- Opcodes 0x4880+ ---------------------
// Emit an Ext opcode, 01001000 1x000nnn
int OpExt(int op)
{
  int ea=0;
  int size=0,use=0;
  int shift=0;

  ea=op&0x0007;
  size=(op>>6)&1;
  shift=32-(8<<size);

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op); Cycles=4;

  EaCalc (11,0x0007,ea,size+1,0,0);
  EaRead (11,     0,ea,size+1,0x0007,0,0);

  ot("  movs r0,r0,asl #%d\n",shift);
  OpGetFlagsNZ(0);
  ot("  mov r1,r0,asr #%d\n",shift);
  ot("\n");

  EaWrite(11,     1,ea,size+1,0x0007,0,0);

  OpEnd();
  return 0;
}

// --------------------- Opcodes 0x50c0+ ---------------------
// Emit a Set cc opcode, 0101cccc 11eeeeee
int OpSet(int op)
{
  int cc=0,ea=0;
  int size=0,use=0,changed_cycles=0;
  const char *cond;

  cc=(op>>8)&15;
  ea=op&0x003f;

  if ((ea&0x38)==0x08) return 1; // dbra, not scc
  
  // See if we can do this opcode:
  if (EaCanWrite(ea)==0) return 1;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  changed_cycles=ea<8 && cc>=2;
  OpStart(op,ea,0,changed_cycles); Cycles=8;
  if (ea<8) Cycles=4;

  switch (cc)
  {
    case 0x00: // T
      ot("  mvn r1,#0\n");
      if (ea<8) Cycles+=2;
      break;
    case 0x01: // F
      ot("  mov r1,#0\n");
      break;
    default:
      ot("  mov r1,#0\n");
      cond=TestCond(cc);
      ot("  mvn%s r1,#0\n",cond);
      if (ea<8) ot("  sub%s r5,r5,#2 ;@ Extra cycles\n",cond);
      break;
  }

  ot("\n");

  eawrite_check_addrerr=1;
  EaCalc (0,0x003f, ea,size,0,0);
  EaWrite(0,     1, ea,size,0x003f,0,0);

  opend_op_changes_cycles=changed_cycles;
  OpEnd(ea,0);
  return 0;
}

// Emit a Asr/Lsr/Roxr/Ror opcode
static int EmitAsr(int op,int type,int dir,int count,int size,int usereg)
{
  char pct[8]=""; // count
  int shift=32-(8<<size);

  if (count>=1) sprintf(pct,"#%d",count); // Fixed count

  if (usereg)
  {
    ot(";@ Use Dn for count:\n");
    ot("  and r2,r8,#0x0e00\n");
    ot("  ldr r2,[r7,r2,lsr #7]\n");
    ot("  and r2,r2,#63\n");
    ot("\n");
    strcpy(pct,"r2");
  }
  else if (count<0)
  {
    ot("  mov r2,r8,lsr #9 ;@ Get 'n'\n");
    ot("  and r2,r2,#7\n\n"); strcpy(pct,"r2");
  }

  // Take 2*n cycles:
  if (count<0) ot("  sub r5,r5,r2,asl #1 ;@ Take 2*n cycles\n\n");
  else Cycles+=count<<1;

  if (type<2)
  {
    // Asr/Lsr
    if (dir==0 && size<2)
    {
      ot(";@ For shift right, use loworder bits for the operation:\n");
      ot("  mov r0,r0,%s #%d\n",type?"lsr":"asr",32-(8<<size));
      ot("\n");
    }

    if (type==0 && dir) ot("  adds r3,r0,#0 ;@ save old value for V flag calculation, also clear V\n");

    ot(";@ Shift register:\n");
    if (type==0) ot("  movs r0,r0,%s %s\n",dir?"asl":"asr",pct);
    if (type==1) ot("  movs r0,r0,%s %s\n",dir?"lsl":"lsr",pct);

    OpGetFlags(0,0);
    if (usereg) { // store X only if count is not 0
      ot("  cmp %s,#0 ;@ shifting by 0?\n",pct);
      ot("  biceq r10,r10,#0x20000000 ;@ if so, clear carry\n");
      ot("  strne r10,[r7,#0x4c] ;@ else Save X bit\n");
    } else {
      // count will never be 0 if we use immediate
      ot("  str r10,[r7,#0x4c] ;@ Save X bit\n");
    }
    ot("\n");

    if (dir==0 && size<2)
    {
      ot(";@ restore after right shift:\n");
      ot("  movs r0,r0,lsl #%d\n",32-(8<<size));
      if (type)
        ot("  orrmi r10,r10,#0x80000000 ;@ Potentially missed N flag\n");
      ot("\n");
    }

    if (type==0 && dir) {
      ot(";@ calculate V flag (set if sign bit changes at anytime):\n");
      ot("  mov r1,#0x80000000\n");
      ot("  ands r3,r3,r1,asr %s\n", pct);
      ot("  cmpne r3,r1,asr %s\n", pct);
      ot("  eoreq r1,r0,r3\n"); // above check doesn't catch (-1)<<(32+), so we need this
      ot("  tsteq r1,#0x80000000\n");
      ot("  orrne r10,r10,#0x10000000\n");
      ot("\n");
    }
  }

  // --------------------------------------
  if (type==2)
  {
    int wide=8<<size;

    // Roxr
    if(count == 1)
    {
      if(dir==0) {
        if(size!=2) {
          ot("  orr r0,r0,r0,lsr #%i\n", size?16:24);
          ot("  bic r0,r0,#0x%x\n", 1<<(32-wide));
        }
        GetXBit(0);
        ot("  movs r0,r0,rrx\n");
        OpGetFlags(0,1);
      } else {
        ot("  ldr r3,[r7,#0x4c]\n");
        ot("  movs r0,r0,lsl #1\n");
        OpGetFlags(0,1);
        ot("  tst r3,#0x20000000\n");
        ot("  orrne r0,r0,#0x%x\n", 1<<(32-wide));
        ot("  bicne r10,r10,#0x40000000 ;@ clear Z in case it got there\n");
      }
      ot("  bic r10,r10,#0x10000000 ;@ make suve V is clear\n");
      return 0;
    }

    if (usereg)
    {
      if (size==2)
      {
        ot("  subs r2,r2,#33\n");
        ot("  addmis r2,r2,#33 ;@ Now r2=0-%d\n",wide);
      }
      else
      {
        ot(";@ Reduce r2 until <0:\n");
        ot("Reduce_%.4x%s\n",op,ms?"":":");
        ot("  subs r2,r2,#%d\n",wide+1);
        ot("  bpl Reduce_%.4x\n",op);
        ot("  adds r2,r2,#%d ;@ Now r2=0-%d\n",wide+1,wide);
      }
      ot("  beq norotx_%.4x\n",op);
      ot("\n");
    }

    if (usereg||count < 0)
    {
      if (dir) ot("  rsb r2,r2,#%d ;@ Reverse direction\n",wide+1);
    }
    else
    {
      if (dir) ot("  mov r2,#%d ;@ Reversed\n",wide+1-count);
      else     ot("  mov r2,#%d\n",count);
    }

    if (shift) ot("  mov r0,r0,lsr #%d ;@ Shift down\n",shift);

    ot("\n");
    ot(";@ First get X bit (middle):\n");
    ot("  ldr r3,[r7,#0x4c]\n");
    ot("  rsb r1,r2,#%d\n",wide);
    ot("  and r3,r3,#0x20000000\n");
    ot("  mov r3,r3,lsr #29\n");
    ot("  mov r3,r3,lsl r1\n");

    ot(";@ Rotate bits:\n");
    ot("  orr r3,r3,r0,lsr r2 ;@ Orr right part\n");
    ot("  rsbs r2,r2,#%d ;@ should also clear ARM V\n",wide+1);
    ot("  orrs r0,r3,r0,lsl r2 ;@ Orr left part, set flags\n");
    ot("\n");

    if (shift) ot("  movs r0,r0,lsl #%d ;@ Shift up and get correct NC flags\n",shift);
    OpGetFlags(0,!usereg);
    if (usereg) { // store X only if count is not 0
      ot("  str r10,[r7,#0x4c] ;@ if not 0, Save X bit\n");
      ot("  b nozerox%.4x\n",op);
      ot("norotx_%.4x%s\n",op,ms?"":":");
      ot("  ldr r2,[r7,#0x4c]\n");
      ot("  adds r0,r0,#0 ;@ Define flags\n");
      OpGetFlagsNZ(0);
      ot("  and r2,r2,#0x20000000\n");
      ot("  orr r10,r10,r2 ;@ C = old_X\n");
      ot("nozerox%.4x%s\n",op,ms?"":":");
    }

    ot("\n");
  }

  // --------------------------------------
  if (type==3)
  {
    // Ror
    if (size<2)
    {
      ot(";@ Mirror value in whole 32 bits:\n");
      if (size<=0) ot("  orr r0,r0,r0,lsr #8\n");
      if (size<=1) ot("  orr r0,r0,r0,lsr #16\n");
      ot("\n");
    }

    ot(";@ Rotate register:\n");
    if (!dir) ot("  adds r0,r0,#0 ;@ first clear V and C\n"); // ARM does not clear C if rot count is 0
    if (count<0)
    {
      if (dir) ot("  rsb %s,%s,#32\n",pct,pct);
      ot("  movs r0,r0,ror %s\n",pct);
    }
    else
    {
      int ror=count;
      if (dir) ror=32-ror;
      if (ror&31) ot("  movs r0,r0,ror #%d\n",ror);
    }

    OpGetFlags(0,0);
    if (dir)
    {
      ot("  bic r10,r10,#0x30000000 ;@ clear CV\n");
      ot(";@ Get carry bit from bit 0:\n");
      if (usereg)
      {
        ot("  cmp %s,#32 ;@ rotating by 0?\n",pct);
        ot("  tstne r0,#1 ;@ no, check bit 0\n");
      }
      else
        ot("  tst r0,#1\n");
      ot("  orrne r10,r10,#0x20000000\n");
    }
    ot("\n");

  }
  // --------------------------------------
  
  return 0;
}

// Emit a Asr/Lsr/Roxr/Ror opcode - 1110cccd xxuttnnn
// (ccc=count, d=direction(r,l) xx=size extension, u=use reg for count, tt=type, nnn=register Dn)
int OpAsr(int op)
{
  int ea=0,use=0;
  int count=0,dir=0;
  int size=0,usereg=0,type=0;

  count =(op>>9)&7;
  dir   =(op>>8)&1;
  size  =(op>>6)&3;
  if (size>=3) return 1; // use OpAsrEa()
  usereg=(op>>5)&1;
  type  =(op>>3)&3;

  if (usereg==0) count=((count-1)&7)+1; // because ccc=000 means 8

  // Use the same opcode for target registers:
  use=op&~0x0007;

  // As long as count is not 8, use the same opcode for all shift counts:
  if (usereg==0 && count!=8 && !(count==1&&type==2)) { use|=0x0e00; count=-1; }
  if (usereg) { use&=~0x0e00; count=-1; } // Use same opcode for all Dn

  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea,0,count<0); Cycles=size<2?6:8;

  EaCalc(11,0x0007, ea,size,1);
  EaRead(11,     0, ea,size,0x0007,1);

  EmitAsr(op,type,dir,count, size,usereg);

  EaWrite(11,    0, ea,size,0x0007,1);

  opend_op_changes_cycles = (count<0);
  OpEnd(ea,0);

  return 0;
}

// Asr/Lsr/Roxr/Ror etc EA - 11100ttd 11eeeeee 
int OpAsrEa(int op)
{
  int use=0,type=0,dir=0,ea=0,size=1;

  type=(op>>9)&3;
  dir =(op>>8)&1;
  ea  = op&0x3f;

  if (ea<0x10) return 1;
  // See if we can do this opcode:
  if (EaCanRead(ea,0)==0) return 1;
  if (EaCanWrite(ea)==0) return 1;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea); Cycles=6; // EmitAsr() will add 2

  EaCalc (11,0x003f,ea,size,1);
  EaRead (11,     0,ea,size,0x003f,1);

  EmitAsr(op,type,dir,1,size,0);

  EaWrite(11,     0,ea,size,0x003f,1);

  OpEnd(ea);
  return 0;
}

int OpTas(int op, int gen_special)
{
  int ea=0;
  int use=0;

  ea=op&0x003f;

  // See if we can do this opcode:
  if (EaCanWrite(ea)==0 || EaAn(ea)) return 1;

  use=OpBase(op,0);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  if (!gen_special) OpStart(op,ea);
  else
    ot("Op%.4x_%s\n", op, ms?"":":");

  Cycles=4;
  if(ea>=8) Cycles+=10;

  EaCalc (11,0x003f,ea,0,1);
  EaRead (11,     1,ea,0,0x003f,1,0,1);

  OpGetFlagsNZ(1);
  ot("\n");

#if CYCLONE_FOR_GENESIS
  // the original Sega hardware ignores write-back phase (to memory only)
  if (ea < 0x10 || gen_special) {
#endif
    ot("  orr r1,r1,#0x80000000 ;@ set bit7\n");

    EaWrite(11,     1,ea,0,0x003f,1);
#if CYCLONE_FOR_GENESIS
  }
#endif

  OpEnd(ea);

#if (CYCLONE_FOR_GENESIS == 2)
  if (!gen_special && ea >= 0x10) {
    OpTas(op, 1);
  }
#endif

  return 0;
}

