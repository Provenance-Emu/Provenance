
// This file is part of the Cyclone 68000 Emulator

// Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
// Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/


#include "app.h"

// --------------------- Opcodes 0x0000+ ---------------------
// Emit an Ori/And/Sub/Add/Eor/Cmp Immediate opcode, 0000ttt0 ssaaaaaa
int OpArith(int op)
{
  int type=0,size=0;
  int sea=0,tea=0;
  int use=0;
  const char *shiftstr="";

  // Get source and target EA
  type=(op>>9)&7; if (type==4 || type>=7) return 1;
  size=(op>>6)&3; if (size>=3) return 1;
  sea=   0x003c;
  tea=op&0x003f;

  // See if we can do this opcode:
  if (EaCanRead(tea,size)==0) return 1;
  if (EaCanWrite(tea)==0 || EaAn(tea)) return 1;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op, sea, tea); Cycles=4;

  // imm must be read first
  EaCalcReadNoSE(-1,10,sea,size,0);
  EaCalcReadNoSE((type!=6)?11:-1,0,tea,size,0x003f);

  if (size<2) shiftstr=(char *)(size?",asl #16":",asl #24");
  if (size<2) ot("  mov r10,r10,asl #%i\n",size?16:24);

  ot(";@ Do arithmetic:\n");

  if (type==0) ot("  orrs r1,r10,r0%s\n",shiftstr);
  if (type==1) ot("  ands r1,r10,r0%s\n",shiftstr);
  if (type==2||type==6)
               ot("  rsbs r1,r10,r0%s ;@ Defines NZCV\n",shiftstr);
  if (type==3) ot("  adds r1,r10,r0%s ;@ Defines NZCV\n",shiftstr);
  if (type==5) ot("  eors r1,r10,r0%s\n",shiftstr);

  if (type< 2) OpGetFlagsNZ(1); // Ori/And
  if (type==2) OpGetFlags(1,1); // Sub: Subtract/X-bit
  if (type==3) OpGetFlags(0,1); // Add: X-bit
  if (type==5) OpGetFlagsNZ(1); // Eor
  if (type==6) OpGetFlags(1,0); // Cmp: Subtract
  ot("\n");

  if (type!=6)
  {
    EaWrite(11, 1, tea,size,0x003f,1);
  }

  // Correct cycles:
  if (type==6)
  {
    if (size>=2 && tea<0x10) Cycles+=2;
  }
  else
  {
    if (size>=2) Cycles+=4;
    if (tea>=8)  Cycles+=4;
    if (type==1 && size>=2 && tea<8) Cycles-=2;
  }

  OpEnd(sea,tea);

  return 0;
}

// --------------------- Opcodes 0x5000+ ---------------------
int OpAddq(int op)
{
  // 0101nnnt xxeeeeee (nnn=#8,1-7 t=addq/subq xx=size, eeeeee=EA)
  int num=0,type=0,size=0,ea=0;
  int use=0;
  char count[16]="";
  int shift=0;

  num =(op>>9)&7; if (num==0) num=8;
  type=(op>>8)&1;
  size=(op>>6)&3; if (size>=3) return 1;
  ea  = op&0x3f;

  // See if we can do this opcode:
  if (EaCanRead (ea,size)==0) return 1;
  if (EaCanWrite(ea)     ==0) return 1;
  if (size == 0 && EaAn(ea) ) return 1;

  use=OpBase(op,size,1);

  if (num!=8) use|=0x0e00; // If num is not 8, use same handler
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea);
  Cycles=ea<8?4:8;
  if(type==0&&size==1) Cycles=ea<0x10?4:8;
  if(size>=2) Cycles=ea<0x10?8:12;

  if (size>0 && (ea&0x38)==0x08) size=2; // addq.w #n,An is also 32-bit

  EaCalcReadNoSE(11,0,ea,size,0x003f);

  shift=32-(8<<size);

  if (num!=8)
  {
    int lsr=9-shift;

    ot("  and r2,r8,#0x0e00 ;@ Get quick value\n");

    if (lsr>=0) sprintf(count,"r2,lsr #%d",  lsr);
    else        sprintf(count,"r2,lsl #%d", -lsr);

    ot("\n");
  }
  else
  {
    sprintf(count,"#0x%.4x",8<<shift);
  }

  if (size<2)  ot("  mov r0,r0,asl #%d\n\n",size?16:24);

  if (type==0) ot("  adds r1,r0,%s\n",count);
  if (type==1) ot("  subs r1,r0,%s\n",count);

  if ((ea&0x38)!=0x08) OpGetFlags(type,1);
  ot("\n");

  EaWrite(11,     1, ea,size,0x003f,1);

  OpEnd(ea);

  return 0;
}

// --------------------- Opcodes 0x8000+ ---------------------
// 1t0tnnnd xxeeeeee (tt=type:or/sub/and/add xx=size, eeeeee=EA)
int OpArithReg(int op)
{
  int use=0;
  int type=0,size=0,dir=0,rea=0,ea=0;
  const char *asl="";
  const char *strop=0;

  type=(op>>12)&5;
  rea =(op>> 9)&7;
  dir =(op>> 8)&1; // er,re
  size=(op>> 6)&3; if (size>=3) return 1;
  ea  = op&0x3f;

  if (dir && ea<0x10) return 1; // addx/subx opcode

  // See if we can do this opcode:
  if (dir==0 && EaCanRead (ea,size)==0) return 1;
  if (dir    && EaCanWrite(ea)==0)      return 1;
  if ((size==0||!(type&1))&&EaAn(ea))   return 1;

  use=OpBase(op,size);
  use&=~0x0e00; // Use same opcode for Dn
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea); Cycles=4;

  EaCalcReadNoSE(dir?11:-1,0,ea,size,0x003f);

  EaCalcReadNoSE(dir?-1:11,1,rea,size,0x0e00);

  ot(";@ Do arithmetic:\n");
  if (type==0) strop = "orrs";
  if (type==1) strop = (char *) (dir ? "subs" : "rsbs");
  if (type==4) strop = "ands";
  if (type==5) strop = "adds";

  if (size==0) asl=",asl #24";
  if (size==1) asl=",asl #16";

  if (size<2) ot("  mov r0,r0%s\n",asl);
  ot("  %s r1,r0,r1%s\n",strop,asl);

  if (type&1) OpGetFlags(type==1,type&1); // add/subtract
  else        OpGetFlagsNZ(1);
  ot("\n");

  ot(";@ Save result:\n");
  if (size<2) ot("  mov r1,r1,asr #%d\n",size?16:24);
  if (dir) EaWrite(11, 1, ea,size,0x003f,0,0);
  else     EaWrite(11, 1,rea,size,0x0e00,0,0);

  if(rea==ea) {
    if(ea<8) Cycles=(size>=2)?8:4; else Cycles+=(size>=2)?26:14;
  } else if(dir) {
    Cycles+=4;
    if(size>=2) Cycles+=4;
  } else {
    if(size>=2) {
      Cycles+=2;
      if(ea<0x10||ea==0x3c) Cycles+=2;
    }
  }

  OpEnd(ea);

  return 0;
}

// --------------------- Opcodes 0x80c0+ ---------------------
int OpMul(int op)
{
  // Div/Mul: 1m00nnns 11eeeeee (m=Mul, nnn=Register Dn, s=signed, eeeeee=EA)
  int type=0,rea=0,sign=0,ea=0;
  int use=0;

  type=(op>>14)&1; // div/mul
  rea =(op>> 9)&7;
  sign=(op>> 8)&1;
  ea  = op&0x3f;

  // See if we can do this opcode:
  if (EaCanRead(ea,1)==0||EaAn(ea)) return 1;

  use=OpBase(op,1);
  use&=~0x0e00; // Use same for all registers
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea);
  if(type) Cycles=54;
  else     Cycles=sign?158:140;

  EaCalcReadNoSE(-1,0,ea,1,0x003f);

  EaCalc(11,0x0e00,rea, 2);
  EaRead(11,     2,rea, 2,0x0e00);

  ot("  movs r1,r0,asl #16\n");

  if (type==0) // div
  {
    // the manual says C is always cleared, but neither Musashi nor FAME do that
    //ot("  bic r10,r10,#0x20000000 ;@ always clear C\n");
    ot("  beq divzero%.4x ;@ division by zero\n",op);
    ot("\n");
    
    if (sign)
    {
      ot("  mov r12,#0 ;@ r12 = 1 or 2 if the result is negative\n");
      ot("  tst r2,r2\n");
      ot("  orrmi r12,r12,#2\n");
      ot("  rsbmi r2,r2,#0 ;@ Make r2 positive\n");
      ot("\n");
      ot("  movs r0,r1,asr #16\n");
      ot("  orrmi r12,r12,#1\n");
      ot("  rsbmi r0,r0,#0 ;@ Make r0 positive\n");
      ot("\n");
      ot(";@ detect the nasty 0x80000000 / -1 situation\n");
      ot("  mov r3,r2,asr #31\n");
      ot("  eors r3,r3,r1,asr #16\n");
      ot("  beq wrendofop%.4x\n",op);
    }
    else
    {
      ot("  mov r0,r1,lsr #16 ;@ use only 16 bits of divisor\n");
    }

    ot("\n");
    ot(";@ Divide r2 by r0\n");
    ot("  mov r3,#0\n");
    ot("  mov r1,r0\n");
    ot("\n");
    ot(";@ Shift up divisor till it's just less than numerator\n");
    ot("Shift%.4x%s\n",op,ms?"":":");
    ot("  cmp r1,r2,lsr #1\n");
    ot("  movls r1,r1,lsl #1\n");
    ot("  bcc Shift%.4x\n",op);
    ot("\n");

    ot("Divide%.4x%s\n",op,ms?"":":");
    ot("  cmp r2,r1\n");
    ot("  adc r3,r3,r3 ;@ Double r3 and add 1 if carry set\n");
    ot("  subcs r2,r2,r1\n");
    ot("  teq r1,r0\n");
    ot("  movne r1,r1,lsr #1\n");
    ot("  bne Divide%.4x\n",op);
    ot("\n");
    ot(";@r3==quotient,r2==remainder\n");

    if (sign)
    {
      // sign correction
      ot("  and r1,r12,#1\n");
      ot("  teq r1,r12,lsr #1\n");
      ot("  rsbne r3,r3,#0 ;@ negate if quotient is negative\n");
      ot("  tst r12,#2\n");
      ot("  rsbne r2,r2,#0 ;@ negate the remainder if divident was negative\n");
      ot("\n");

      // signed overflow check
      ot("  mov r1,r3,asl #16\n");
      ot("  cmp r3,r1,asr #16 ;@ signed overflow?\n");
      ot("  orrne r10,r10,#0x10000000 ;@ set overflow flag\n");
      ot("  bne endofop%.4x ;@ overflow!\n",op);
      ot("\n");
      ot("wrendofop%.4x%s\n",op,ms?"":":");
    }
    else
    {
      // overflow check
      ot("  movs r1,r3,lsr #16 ;@ check for overflow condition\n");
      ot("  orrne r10,r10,#0x10000000 ;@ set overflow flag\n");
      ot("  bne endofop%.4x ;@ overflow!\n",op);
      ot("\n");
    }

    ot("  movs r1,r3,lsl #16 ;@ Clip to 16-bits\n");
    OpGetFlagsNZ(1);

    ot("  mov r1,r1,lsr #16\n");
    ot("  orr r1,r1,r2,lsl #16 ;@ Insert remainder\n");
  }

  if (type==1)
  {
    ot(";@ Get 16-bit signs right:\n");
    ot("  mov r0,r1,%s #16\n",sign?"asr":"lsr");
    ot("  mov r2,r2,lsl #16\n");
    ot("  mov r2,r2,%s #16\n",sign?"asr":"lsr");
    ot("\n");

    ot("  muls r1,r2,r0\n");
    OpGetFlagsNZ(1);
  }
  ot("\n");

  EaWrite(11,    1,rea, 2,0x0e00,1);

  if (type==0) ot("endofop%.4x%s\n",op,ms?"":":");
  OpEnd(ea);

  if (type==0) // div
  {
    ot("divzero%.4x%s\n",op,ms?"":":");
    ot("  mov r0,#5 ;@ Divide by zero\n");
    ot("  bl Exception\n");
    Cycles+=38;
    OpEnd(ea);
    ot("\n");
  }

  return 0;
}

// Get X Bit into carry - trashes r2
int GetXBit(int subtract)
{
  ot(";@ Get X bit:\n");
  ot("  ldr r2,[r7,#0x4c]\n");
  if (subtract) ot("  mvn r2,r2 ;@ Invert it\n");
  ot("  tst r2,r2,lsl #3 ;@ Get into Carry\n");
  ot("\n");
  return 0;
}

// --------------------- Opcodes 0x8100+ ---------------------
// 1t00ddd1 0000asss - sbcd/abcd Ds,Dd or -(As),-(Ad)
int OpAbcd(int op)
{
  int use=0;
  int type=0,sea=0,mem=0,dea=0;
  
  type=(op>>14)&1; // sbcd/abcd
  dea =(op>> 9)&7;
  mem =(op>> 3)&1;
  sea = op     &7;

  if (mem) { sea|=0x20; dea|=0x20; }

  use=op&~0x0e07; // Use same opcode for all registers..
  if (sea==0x27) use|=0x0007; // ___x.b -(a7)
  if (dea==0x27) use|=0x0e00; // ___x.b -(a7)
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea,dea); Cycles=6;

  if (mem)
  {
    ot(";@ Get src/dest EA vals\n");
    EaCalc (0,0x000f, sea,0,1);
    EaRead (0,     6, sea,0,0x000f,1);
    EaCalcReadNoSE(11,0,dea,0,0x0e00);
  }
  else
  {
    ot(";@ Get src/dest reg vals\n");
    EaCalcReadNoSE(-1,6,sea,0,0x0007);
    EaCalcReadNoSE(11,0,dea,0,0x0e00);
    ot("  mov r6,r6,asl #24\n");
  }
  ot("  mov r1,r0,asl #24\n\n");

  ot("  bic r10,r10,#0xb1000000 ;@ clear all flags except old Z\n");

  if (type)
  {
    ot("  ldr r0,[r7,#0x4c] ;@ Get X bit\n");
    ot("  mov r3,#0x00f00000\n");
    ot("  and r2,r3,r1,lsr #4\n");
    ot("  tst r0,#0x20000000\n");
    ot("  and r0,r3,r6,lsr #4\n");
    ot("  add r0,r0,r2\n");
    ot("  addne r0,r0,#0x00100000\n");
//    ot("  tst r0,#0x00800000\n");
//    ot("  orreq r10,r10,#0x01000000 ;@ Undefined V behavior\n");
    ot("  cmp r0,#0x00900000\n");
    ot("  addhi r0,r0,#0x00600000 ;@ Decimal adjust units\n");

    ot("  mov r2,r1,lsr #28\n");
    ot("  add r0,r0,r2,lsl #24\n");
    ot("  mov r2,r6,lsr #28\n");
    ot("  add r0,r0,r2,lsl #24\n");
    ot("  cmp r0,#0x09900000\n");
    ot("  orrhi r10,r10,#0x20000000 ;@ C\n");
    ot("  subhi r0,r0,#0x0a000000\n");
//    ot("  and r3,r10,r0,lsr #3 ;@ Undefined V behavior part II\n");
//    ot("  orr r10,r10,r3,lsl #4 ;@ V\n");
    ot("  movs r0,r0,lsl #4\n");
    ot("  orrmi r10,r10,#0x90000000 ;@ Undefined N+V behavior\n"); // this is what Musashi really does
    ot("  bicne r10,r10,#0x40000000 ;@ Z flag\n");
  }
  else
  {
    ot("  ldr r0,[r7,#0x4c] ;@ Get X bit\n");
    ot("  mov r3,#0x00f00000\n");
    ot("  and r2,r3,r6,lsr #4\n");
    ot("  tst r0,#0x20000000\n");
    ot("  and r0,r3,r1,lsr #4\n");
    ot("  sub r0,r0,r2\n");
    ot("  subne r0,r0,#0x00100000\n");
//    ot("  tst r0,#0x00800000\n");
//    ot("  orreq r10,r10,#0x01000000 ;@ Undefined V behavior\n");
    ot("  cmp r0,#0x00900000\n");
    ot("  subhi r0,r0,#0x00600000 ;@ Decimal adjust units\n");

    ot("  mov r2,r1,lsr #28\n");
    ot("  add r0,r0,r2,lsl #24\n");
    ot("  mov r2,r6,lsr #28\n");
    ot("  sub r0,r0,r2,lsl #24\n");
    ot("  cmp r0,#0x09900000\n");
    ot("  orrhi r10,r10,#0xa0000000 ;@ N and C\n");
    ot("  addhi r0,r0,#0x0a000000\n");
//    ot("  and r3,r10,r0,lsr #3 ;@ Undefined V behavior part II\n");
//    ot("  orr r10,r10,r3,lsl #4 ;@ V\n");
    ot("  movs r0,r0,lsl #4\n");
//    ot("  orrmi r10,r10,#0x80000000 ;@ Undefined N behavior\n");
    ot("  bicne r10,r10,#0x40000000 ;@ Z flag\n");
  }

  ot("  str r10,[r7,#0x4c] ;@ Save X bit\n");
  ot("\n");

  EaWrite(11,     0, dea,0,0x0e00,1);

  ot("  ldr r6,[r7,#0x54]\n");
  OpEnd(sea,dea);

  return 0;
}

// 01001000 00eeeeee - nbcd <ea>
int OpNbcd(int op)
{
  int use=0;
  int ea=0;
  
  ea=op&0x3f;

  if(EaCanWrite(ea)==0||EaAn(ea)) return 1;

  use=OpBase(op,0);
  if(op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea); Cycles=6;
  if(ea >= 8)  Cycles+=2;

  EaCalcReadNoSE(6,0,ea,0,0x003f);

  // this is rewrite of Musashi's code
  ot("  ldr r2,[r7,#0x4c]\n");
  ot("  bic r10,r10,#0xb0000000 ;@ clear all flags, except Z\n");
  ot("  mov r0,r0,asl #24\n");
  ot("  and r2,r2,#0x20000000\n");
  ot("  add r2,r0,r2,lsr #5 ;@ add X\n");
  ot("  rsb r11,r2,#0x9a000000 ;@ do arithmetic\n");

  ot("  cmp r11,#0x9a000000\n");
  ot("  beq finish%.4x\n",op);
  ot("\n");

  ot("  mvn r3,r11,lsr #31 ;@ Undefined V behavior\n",op);
  ot("  and r2,r11,#0x0f000000\n");
  ot("  cmp r2,#0x0a000000\n");
  ot("  andeq r11,r11,#0xf0000000\n");
  ot("  addeq r11,r11,#0x10000000\n");
  ot("  and r3,r3,r11,lsr #31 ;@ Undefined V behavior part II\n",op);
  ot("  movs r1,r11,asr #24\n");
  ot("  bicne r10,r10,#0x40000000 ;@ Z\n");
  ot("  orr r10,r10,r3,lsl #28 ;@ save V\n",op);
  ot("  orr r10,r10,#0x20000000 ;@ C\n");
  ot("\n");

  EaWrite(6, 1, ea,0,0x3f,0,0);

  ot("finish%.4x%s\n",op,ms?"":":");
  ot("  tst r11,r11\n");
  ot("  orrmi r10,r10,#0x80000000 ;@ N\n");
  ot("  str r10,[r7,#0x4c] ;@ Save X\n");
  ot("\n");

  ot("  ldr r6,[r7,#0x54]\n");
  OpEnd(ea);

  return 0;
}

// --------------------- Opcodes 0x90c0+ ---------------------
// Suba/Cmpa/Adda 1tt1nnnx 11eeeeee (tt=type, x=size, eeeeee=Source EA)
int OpAritha(int op)
{
  int use=0;
  int type=0,size=0,sea=0,dea=0;
  const char *asr="";

  // Suba/Cmpa/Adda/(invalid):
  type=(op>>13)&3; if (type>=3) return 1;

  size=(op>>8)&1; size++;
  dea=(op>>9)&7; dea|=8; // Dest=An
  sea=op&0x003f; // Source

  // See if we can do this opcode:
  if (EaCanRead(sea,size)==0) return 1;

  use=OpBase(op,size);
  use&=~0x0e00; // Use same opcode for An
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea); Cycles=(size==2)?6:8;
  if(size==2&&(sea<0x10||sea==0x3c)) Cycles+=2;
  if(type==1) Cycles=6;

  // EA calculation order defines how situations like  suba.w (A0)+, A0 get handled.
  // different emus act differently in this situation, I couldn't fugure which is right behaviour.
  //if (type == 1)
  {
    EaCalcReadNoSE(-1,0,sea,size,0x003f);
    EaCalcReadNoSE(type!=1?11:-1,1,dea,2,0x0e00);
  }
#if 0
  else
  {
    EaCalcReadNoSE(type!=1?11:-1,1,dea,2,0x0e00);
    EaCalcReadNoSE(-1,0,sea,size,0x003f);
  }
#endif

  if (size<2) ot("  mov r0,r0,asl #%d\n\n",size?16:24);
  if (size<2) asr=(char *)(size?",asr #16":",asr #24");

  if (type==0) ot("  sub r1,r1,r0%s\n",asr);
  if (type==1) ot("  cmp r1,r0%s ;@ Defines NZCV\n",asr);
  if (type==1) OpGetFlags(1,0); // Get Cmp flags
  if (type==2) ot("  add r1,r1,r0%s\n",asr);
  ot("\n");

  if (type!=1) EaWrite(11, 1, dea,2,0x0e00);

  OpEnd(sea);

  return 0;
}

// --------------------- Opcodes 0x9100+ ---------------------
// Emit a Subx/Addx opcode, 1t01ddd1 zz00rsss addx.z Ds,Dd
int OpAddx(int op)
{
  int use=0;
  int type=0,size=0,dea=0,sea=0,mem=0;
  const char *asl="";

  type=(op>>14)&1;
  dea =(op>> 9)&7;
  size=(op>> 6)&3; if (size>=3) return 1;
  sea = op&7;
  mem =(op>> 3)&1;

  // See if we can do this opcode:
  if (EaCanRead(sea,size)==0) return 1;
  if (EaCanWrite(dea)==0) return 1;

  if (mem) { sea+=0x20; dea+=0x20; }

  use=op&~0x0e07; // Use same opcode for Dn
  if (size==0&&sea==0x27) use|=0x0007; // ___x.b -(a7)
  if (size==0&&dea==0x27) use|=0x0e00; // ___x.b -(a7)
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea,dea); Cycles=4;
  if(size>=2)   Cycles+=4;
  if(sea>=0x10) Cycles+=2;

  if (mem)
  {
    ot(";@ Get src/dest EA vals\n");
    EaCalc (0,0x000f, sea,size,1);
    EaRead (0,     6, sea,size,0x000f,1);
    EaCalcReadNoSE(11,0,dea,size,0x0e00);
  }
  else
  {
    ot(";@ Get src/dest reg vals\n");
    EaCalcReadNoSE(-1,6,sea,size,0x0007);
    EaCalcReadNoSE(11,0,dea,size,0x0e00);
    if (size<2) ot("  mov r6,r6,asl #%d\n\n",size?16:24);
  }

  if (size<2) asl=(char *)(size?",asl #16":",asl #24");

  ot(";@ Do arithmetic:\n");
  GetXBit(type==0);

  if (type==1 && size<2)
  {
    ot(";@ Make sure the carry bit will tip the balance:\n");
    ot("  mvn r2,#0\n");
    ot("  orr r6,r6,r2,lsr #%i\n",(size==0)?8:16);
    ot("\n");
  }

  if (type==0) ot("  rscs r1,r6,r0%s\n",asl);
  if (type==1) ot("  adcs r1,r6,r0%s\n",asl);
  ot("  orr r3,r10,#0xb0000000 ;@ for old Z\n");
  OpGetFlags(type==0,1,0); // subtract
  if (size<2) {
    ot("  movs r2,r1,lsr #%i\n", size?16:24);
    ot("  orreq r10,r10,#0x40000000 ;@ add potentially missed Z\n");
  }
  ot("  andeq r10,r10,r3 ;@ fix Z\n");
  ot("\n");

  ot(";@ Save result:\n");
  EaWrite(11, 1, dea,size,0x0e00,1);

  ot("  ldr r6,[r7,#0x54]\n");
  OpEnd(sea,dea);

  return 0;
}

// --------------------- Opcodes 0xb000+ ---------------------
// Emit a Cmp/Eor opcode, 1011rrrt xxeeeeee (rrr=Dn, t=cmp/eor, xx=size extension, eeeeee=ea)
int OpCmpEor(int op)
{
  int rea=0,eor=0;
  int size=0,ea=0,use=0;
  const char *asl="";

  // Get EA and register EA
  rea=(op>>9)&7;
  eor=(op>>8)&1;
  size=(op>>6)&3; if (size>=3) return 1;
  ea=op&0x3f;

  if (eor && (ea>>3) == 1) return 1; // not a valid mode for eor

  // See if we can do this opcode:
  if (EaCanRead(ea,size)==0) return 1;
  if (eor && EaCanWrite(ea)==0) return 1;
  if (EaAn(ea)&&(eor||size==0)) return 1;

  use=OpBase(op,size);
  use&=~0x0e00; // Use 1 handler for register d0-7
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea); Cycles=4;
  if(eor) {
    if(ea>8)     Cycles+=4;
    if(size>=2)  Cycles+=4;
  } else {
    if(size>=2)  Cycles+=2;
  }

  ot(";@ Get EA into r11 and value into r0:\n");
  EaCalcReadNoSE(eor?11:-1,0,ea,size,0x003f);

  ot(";@ Get register operand into r1:\n");
  EaCalcReadNoSE(-1,1,rea,size,0x0e00);

  if (size<2) ot("  mov r0,r0,asl #%d\n\n",size?16:24);
  if (size<2) asl=(char *)(size?",asl #16":",asl #24");

  ot(";@ Do arithmetic:\n");
  if (eor)
  {
    ot("  eors r1,r0,r1%s\n",asl);
    OpGetFlagsNZ(1);
  }
  else
  {
    ot("  rsbs r1,r0,r1%s\n",asl);
    OpGetFlags(1,0); // Cmp like subtract
  }
  ot("\n");

  if (eor) EaWrite(11, 1,ea,size,0x003f,1);

  OpEnd(ea);
  return 0;
}

// Emit a Cmpm opcode, 1011ddd1 xx001sss (rrr=Adst, xx=size extension, sss=Asrc)
int OpCmpm(int op)
{
  int size=0,sea=0,dea=0,use=0;
  const char *asl="";

  // get size, get EAs
  size=(op>>6)&3; if (size>=3) return 1;
  sea=(op&7)|0x18;
  dea=(op>>9)&0x3f;

  use=op&~0x0e07; // Use 1 handler for all registers..
  if (size==0&&sea==0x1f) use|=0x0007; // ..except (a7)+
  if (size==0&&dea==0x1f) use|=0x0e00;
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea); Cycles=4;

  ot(";@ Get src operand into r11:\n");
  EaCalc (0,0x0007, sea,size,1);
  EaRead (0,    11, sea,size,0x0007,1);

  ot(";@ Get dst operand into r0:\n");
  EaCalcReadNoSE(-1,0,dea,size,0x0e00);

  if (size<2) asl=(char *)(size?",asl #16":",asl #24");

  ot("  rsbs r0,r11,r0%s\n",asl);
  OpGetFlags(1,0); // Cmp like subtract
  ot("\n");

  OpEnd(sea);
  return 0;
}


// Emit a Chk opcode, 0100ddd1 x0eeeeee (rrr=Dn, x=size extension, eeeeee=ea)
int OpChk(int op)
{
  int rea=0;
  int size=0,ea=0,use=0;

  // Get EA and register EA
  rea=(op>>9)&7;
  if((op>>7)&1)
       size=1; // word operation
  else size=2; // long
  ea=op&0x3f;

  if (EaAn(ea)) return 1; // not a valid mode
  if (size!=1)  return 1; // 000 variant only supports word

  // See if we can do this opcode:
  if (EaCanRead(ea,size)==0) return 1;

  use=OpBase(op,size);
  use&=~0x0e00; // Use 1 handler for register d0-7
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea); Cycles=10;

  ot(";@ Get value into r0:\n");
  EaCalcReadNoSE(-1,0,ea,size,0x003f);

  ot(";@ Get register operand into r1:\n");
  EaCalcReadNoSE(-1,1,rea,size,0x0e00);

  if (size<2) ot("  mov r0,r0,asl #%d\n",size?16:24);

  if (size<2) ot("  movs r1,r1,asl #%d\n\n",size?16:24);
  else        ot("  adds r1,r1,#0 ;@ Define flags\n");

  ot(";@ get flags, including undocumented ones\n");
  ot("  and r3,r10,#0x80000000\n");
  OpGetFlagsNZ(1);

  ot(";@ is reg negative?\n");
  ot("  bmi chktrap%.4x\n",op);

  ot(";@ Do arithmetic:\n");
  ot("  cmp r1,r0\n");
  ot("  bgt chktrap%.4x\n",op);

  ot(";@ old N remains\n");
  ot("  orr r10,r10,r3\n");
  OpEnd(ea);

  ot("chktrap%.4x%s ;@ CHK exception:\n",op,ms?"":":");
  ot("  mov r0,#6\n");
  ot("  bl Exception\n");
  Cycles+=40;
  OpEnd(ea);

  return 0;
}

