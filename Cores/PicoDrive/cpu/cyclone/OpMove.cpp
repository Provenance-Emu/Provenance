
// This file is part of the Cyclone 68000 Emulator

// Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
// Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/


#include "app.h"

// Pack our flags into r1, in SR/CCR register format
// trashes r0,r2
void OpFlagsToReg(int high)
{
  ot("  ldr r0,[r7,#0x4c]   ;@ X bit\n");
  ot("  mov r1,r10,lsr #28  ;@ ____NZCV\n");
  ot("  eor r2,r1,r1,ror #1 ;@ Bit 0=C^V\n");
  ot("  tst r2,#1           ;@ 1 if C!=V\n");
  ot("  eorne r1,r1,#3      ;@ ____NZVC\n");
  ot("\n");
  if (high) ot("  ldrb r2,[r7,#0x44]  ;@ Include SR high\n");
  ot("  and r0,r0,#0x20000000\n");
  ot("  orr r1,r1,r0,lsr #25 ;@ ___XNZVC\n");
  if (high) ot("  orr r1,r1,r2,lsl #8\n");
  ot("\n");
}

// Convert SR/CRR register in r0 to our flags
// trashes r0,r1
void OpRegToFlags(int high, int srh_reg)
{
  ot("  eor r1,r0,r0,ror #1 ;@ Bit 0=C^V\n");
  ot("  mov r2,r0,lsl #25\n");
  ot("  tst r1,#1           ;@ 1 if C!=V\n");
  ot("  eorne r0,r0,#3      ;@ ___XNZCV\n");
  ot("  str r2,[r7,#0x4c]   ;@ Store X bit\n");
  ot("  mov r10,r0,lsl #28  ;@ r10=NZCV...\n");

  if (high)
  {
    int mask=EMULATE_TRACE?0xa7:0x27;
    ot("  mov r%i,r0,ror #8\n",srh_reg);
    ot("  and r%i,r%i,#0x%02x ;@ only take defined bits\n",srh_reg,srh_reg,mask);
    ot("  strb r%i,[r7,#0x44] ;@ Store SR high\n",srh_reg);
  }
  ot("\n");
}

void SuperEnd(void)
{
  ot(";@ ----------\n");
  ot(";@ tried execute privileged instruction in user mode\n");
  ot("WrongPrivilegeMode%s\n",ms?"":":");
#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO
  ot("  ldr r1,[r7,#0x58]\n");
  ot("  sub r4,r4,#2 ;@ last opcode wasn't executed - go back\n");
  ot("  orr r1,r1,#4 ;@ set activity bit: 'not processing instruction'\n");
  ot("  str r1,[r7,#0x58]\n");
#else
  ot("  sub r4,r4,#2 ;@ last opcode wasn't executed - go back\n");
#endif
  ot("  mov r0,#8 ;@ privilege violation\n");
  ot("  bl Exception\n");
  Cycles=34;
  OpEnd(0);
}

// does OSP and A7 swapping if needed
// new or old SR (not the one already in [r7,#0x44]) should be passed in r11
// uses srh from srh_reg (loads if < 0), trashes r0,r11
void SuperChange(int op,int srh_reg)
{
  ot(";@ A7 <-> OSP?\n");
  if (srh_reg < 0) {
    ot("  ldr r0,[r7,#0x44] ;@ Get other SR high\n");
    srh_reg=0;
  }
  ot("  eor r0,r%i,r11\n",srh_reg);
  ot("  tst r0,#0x20\n");
  ot("  beq no_sp_swap%.4x\n",op);
  ot(" ;@ swap OSP and A7:\n");
  ot("  ldr r11,[r7,#0x3C] ;@ Get A7\n");
  ot("  ldr r0, [r7,#0x48] ;@ Get OSP\n");
  ot("  str r11,[r7,#0x48]\n");
  ot("  str r0, [r7,#0x3C]\n");
  ot("no_sp_swap%.4x%s\n", op, ms?"":":");
}



// --------------------- Opcodes 0x1000+ ---------------------
// Emit a Move opcode, 00xxdddd ddssssss
int OpMove(int op)
{
  int sea=0,tea=0;
  int size=0,use=0;
  int movea=0;

  // Get source and target EA
  sea = op&0x003f;
  tea =(op&0x01c0)>>3;
  tea|=(op&0x0e00)>>9;

  if (tea>=8 && tea<0x10) movea=1;

  // Find size extension
  switch (op&0x3000)
  {
    default: return 1;
    case 0x1000: size=0; break;
    case 0x3000: size=1; break;
    case 0x2000: size=2; break;
  }

  if (size<1 && (movea || EaAn(sea))) return 1; // move.b An,* and movea.b * are invalid

  // See if we can do this opcode:
  if (EaCanRead (sea,size)==0) return 1;
  if (EaCanWrite(tea     )==0) return 1;

  use=OpBase(op,size);
  if (tea<0x38) use&=~0x0e00; // Use same handler for register ?0-7
  
  if (tea==0x1f || tea==0x27) use|=0x0e00; // Specific handler for (a7)+ and -(a7)

  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea,tea); Cycles=4;

  if (movea==0)
  {
    EaCalcRead(-1,1,sea,size,0x003f,1,1);
    OpGetFlagsNZ(1);
    ot("\n");
  }
  else
  {
    EaCalcRead(-1,1,sea,size,0x003f);
    size=2; // movea always expands to 32-bits
  }

  eawrite_check_addrerr=1;
#if SPLIT_MOVEL_PD
  if ((tea&0x38)==0x20 && size==2) { // -(An)
    EaCalc (8,0x0e00,tea,size,0,0);
    ot("  mov r11,r1\n");
    ot("  add r0,r8,#2\n");
    EaWrite(0,     1,tea,1,0x0e00,0,0);
    EaWrite(8,    11,tea,1,0x0e00,1);
  }
  else
#endif
  {
    EaCalc (0,0x0e00,tea,size,0,0);
    EaWrite(0,     1,tea,size,0x0e00,0,0);
  }

#if CYCLONE_FOR_GENESIS && !MEMHANDLERS_CHANGE_CYCLES
  // this is a bit hacky (device handlers might modify cycles)
  if (tea==0x39||((0x10<=tea&&tea<0x30)&&size>=1))
    ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
#endif

  if((tea&0x38)==0x20) Cycles-=2; // less cycles when dest is -(An)

  OpEnd(sea,tea);
  return 0;
}

// --------------------- Opcodes 0x41c0+ ---------------------
// Emit an Lea opcode, 0100nnn1 11aaaaaa
int OpLea(int op)
{
  int use=0;
  int sea=0,tea=0;

  sea= op&0x003f;
  tea=(op&0x0e00)>>9; tea|=8;

  if (EaCanRead(sea,-1)==0) return 1; // See if we can do this opcode

  use=OpBase(op,0);
  use&=~0x0e00; // Also use 1 handler for target ?0-7
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,sea,tea);

  eawrite_check_addrerr=1;
  EaCalc (1,0x003f,sea,0); // Lea
  EaCalc (0,0x0e00,tea,2);
  EaWrite(0,     1,tea,2,0x0e00);

  Cycles=Ea_add_ns(g_lea_cycle_table,sea);

  OpEnd(sea,tea);

  return 0;
}

// --------------------- Opcodes 0x40c0+ ---------------------
// Move SR opcode, 01000tt0 11aaaaaa move SR
int OpMoveSr(int op)
{
  int type=0,ea=0;
  int use=0,size=1;

  type=(op>>9)&3; // from SR, from CCR, to CCR, to SR
  ea=op&0x3f;

  if(EaAn(ea)) return 1; // can't use An regs

  switch(type)
  {
    case 0:
      if (EaCanWrite(ea)==0) return 1; // See if we can do this opcode:
      break;

    case 1:
      return 1; // no such op in 68000

    case 2: case 3:
      if (EaCanRead(ea,size)==0) return 1; // See if we can do this opcode:
      break;
  }

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  // 68000 model allows reading whole SR in user mode (but newer models don't)
  OpStart(op,ea,0,0,type==3);
  Cycles=12;
  if (type==0) Cycles=(ea>=8)?8:6;

  if (type==0 || type==1)
  {
    eawrite_check_addrerr=1;
    OpFlagsToReg(type==0);
    EaCalc (0,0x003f,ea,size,0,0);
    EaWrite(0,     1,ea,size,0x003f,0,0);
  }

  if (type==2 || type==3)
  {
    EaCalcReadNoSE(-1,0,ea,size,0x003f);
    OpRegToFlags(type==3,1);
    if (type==3) {
      SuperChange(op,1);
      opend_check_interrupt = 1;
      opend_check_trace = 1;
      OpEnd(ea);
      return 0;
    }
  }

  OpEnd(ea);

  return 0;
}


// Ori/Andi/Eori $nnnn,sr 0000t0t0 01111100
int OpArithSr(int op)
{
  int type=0,ea=0;
  int use=0,size=0;
  int sr_mask=EMULATE_TRACE?0xa7:0x27;

  type=(op>>9)&5; if (type==4) return 1;
  size=(op>>6)&1; // ccr or sr?
  ea=0x3c;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea,0,0,size!=0); Cycles=16;

  EaCalcRead(-1,0,ea,size,0x003f);

  ot("  eor r1,r0,r0,ror #1 ;@ Bit 0=C^V\n");
  ot("  tst r1,#1           ;@ 1 if C!=V\n");
  ot("  eorne r0,r0,#3      ;@ ___XNZCV\n");
  ot("  ldr r2,[r7,#0x4c]   ;@ Load old X bit\n");

  // note: old srh is already in r11 (done by OpStart)
  if (type==0) {
    ot("  orr r10,r10,r0,lsl #28\n");
    ot("  orr r2,r2,r0,lsl #25 ;@ X bit\n");
    if (size!=0) {
      ot("  orr r1,r11,r0,lsr #8\n");
      ot("  and r1,r1,#0x%02x ;@ mask-out unused bits\n",sr_mask);
    }
  }
  if (type==1) {
    ot("  and r10,r10,r0,lsl #28\n");
    ot("  and r2,r2,r0,lsl #25 ;@ X bit\n");
    if (size!=0)
      ot("  and r1,r11,r0,lsr #8\n");
  }
  if (type==5) {
    ot("  eor r10,r10,r0,lsl #28\n");
    ot("  eor r2,r2,r0,lsl #25 ;@ X bit\n");
    if (size!=0) {
      ot("  eor r1,r11,r0,lsr #8\n");
      ot("  and r1,r1,#0x%02x ;@ mask-out unused bits\n",sr_mask);
    }
  }

  ot("  str r2,[r7,#0x4c]   ;@ Save X bit\n");
  if (size!=0)
    ot("  strb r1,[r7,#0x44]\n");
  ot("\n");

  // we can't enter supervisor mode, nor unmask irqs just by using OR
  if (size!=0 && type!=0) {
    SuperChange(op,1);
    ot("\n");
    opend_check_interrupt = 1;
  }
  // also can't set trace bit with AND
  if (size!=0 && type!=1)
    opend_check_trace = 1;

  OpEnd(ea);

  return 0;
}

// --------------------- Opcodes 0x4850+ ---------------------
// Emit an Pea opcode, 01001000 01aaaaaa
int OpPea(int op)
{
  int use=0;
  int ea=0;

  ea=op&0x003f; if (ea<0x10) return 1; // Swap opcode
  if (EaCanRead(ea,-1)==0) return 1; // See if we can do this opcode:

  use=OpBase(op,0);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea);

  ot("  ldr r11,[r7,#0x3c]\n");
  EaCalc (1,0x003f, ea,0);
  ot("\n");
  ot("  sub r0,r11,#4 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  ot("\n");
  MemHandler(1,2); // Write 32-bit
  ot("\n");

  Cycles=6+Ea_add_ns(g_pea_cycle_table,ea);

  OpEnd(ea);

  return 0;
}

// --------------------- Opcodes 0x4880+ ---------------------
// Emit a Movem opcode, 01001d00 1xeeeeee regmask
int OpMovem(int op)
{
  int size=0,ea=0,cea=0,dir=0;
  int use=0,decr=0,change=0;

  size=((op>>6)&1)+1; // word, long
  ea=op&0x003f;
  dir=(op>>10)&1; // Direction (1==ea2reg)

  if (dir) {
    if (ea<0x10 || ea>0x3b || (ea&0x38)==0x20) return 1; // Invalid EA
  } else {
    if (ea<0x10 || ea>0x39 || (ea&0x38)==0x18) return 1;
  }

  if ((ea&0x38)==0x18 || (ea&0x38)==0x20) change=1;
  if ((ea&0x38)==0x20) decr=1; // -(An), bitfield is decr

  cea=ea; if (change) cea=0x10;

  use=OpBase(op,size);
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,ea,0,1);

  ot("  ldrh r11,[r4],#2 ;@ r11=register mask\n");
  ot("\n");
  ot(";@ Get the address into r6:\n");
  EaCalc(6,0x003f,cea,size);

#if !MEMHANDLERS_NEED_PREV_PC
  // must save PC, need a spare register
  ot("  str r4,[r7,#0x40] ;@ Save PC\n");
#endif

  ot(";@ r4=Register Index*4:\n");
  if (decr) ot("  mov r4,#0x40 ;@ order reversed for -(An)\n");
  else      ot("  mov r4,#-4\n");
  
  ot("\n");
  ot("  tst r11,r11\n");        // sanity check
  ot("  beq NoRegs%.4x\n",op);

#if EMULATE_ADDRESS_ERRORS_IO
  ot("\n");
  ot("  tst r6,#1 ;@ address error?\n");
  ot("  movne r0,r6\n");
  ot("  bne ExceptionAddressError_%c_data\n",dir?'r':'w');
#endif

  ot("\n");
  ot("Movemloop%.4x%s\n",op, ms?"":":");
  ot("  add r4,r4,#%d ;@ r4=Next Register\n",decr?-4:4);
  ot("  movs r11,r11,lsr #1\n");
  ot("  bcc Movemloop%.4x\n",op);
  ot("\n");

  if (decr) ot("  sub r6,r6,#%d ;@ Pre-decrement address\n",1<<size);

  if (dir)
  {
    ot("  ;@ Copy memory to register:\n",1<<size);
    earead_check_addrerr=0; // already checked
    EaRead (6,0,ea,size,0x003f);
    ot("  str r0,[r7,r4] ;@ Save value into Dn/An\n");
  }
  else
  {
    ot("  ;@ Copy register to memory:\n",1<<size);
    ot("  ldr r1,[r7,r4] ;@ Load value from Dn/An\n");
#if SPLIT_MOVEL_PD
    if (decr && size==2) { // -(An)
      ot("  add r0,r6,#2\n");
      EaWrite(0,1,ea,1,0x003f,0,0);
      ot("  ldr r1,[r7,r4] ;@ Load value from Dn/An\n");
      ot("  mov r0,r6\n");
      EaWrite(0,1,ea,1,0x003f,1);
    }
    else
#endif
    {
      EaWrite(6,1,ea,size,0x003f);
    }
  }

  if (decr==0) ot("  add r6,r6,#%d ;@ Post-increment address\n",1<<size);

  ot("  sub r5,r5,#%d ;@ Take some cycles\n",2<<size);
  ot("  tst r11,r11\n");
  ot("  bne Movemloop%.4x\n",op);
  ot("\n");

  if (change)
  {
    ot(";@ Write back address:\n");
    EaCalc (0,0x0007,8|(ea&7),2);
    EaWrite(0,     6,8|(ea&7),2,0x0007);
  }

  ot("NoRegs%.4x%s\n",op, ms?"":":");
  ot("  ldr r4,[r7,#0x40]\n");
  ot("  ldr r6,[r7,#0x54] ;@ restore Opcode Jump table\n");
  ot("\n");

  if(dir) { // er
         if (ea==0x3a) Cycles=16; // ($nn,PC)
    else if (ea==0x3b) Cycles=18; // ($nn,pc,Rn)
    else Cycles=12;
  } else {
    Cycles=8;
  }

  Cycles+=Ea_add_ns(g_movem_cycle_table,ea);

  opend_op_changes_cycles = 1;
  OpEnd(ea);
  ot("\n");

  return 0;
}

// --------------------- Opcodes 0x4e60+ ---------------------
// Emit a Move USP opcode, 01001110 0110dnnn move An to/from USP
int OpMoveUsp(int op)
{
  int use=0,dir=0;

  dir=(op>>3)&1; // Direction
  use=op&~0x0007; // Use same opcode for all An

  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op,0,0,0,1); Cycles=4;

  if (dir)
  {
    eawrite_check_addrerr=1;
    ot("  ldr r1,[r7,#0x48] ;@ Get from USP\n\n");
    EaCalc (0,0x000f,8,2,1);
    EaWrite(0,     1,8,2,0x000f,1);
  }
  else
  {
    EaCalc (0,0x000f,8,2,1);
    EaRead (0,     0,8,2,0x000f,1);
    ot("  str r0,[r7,#0x48] ;@ Put in USP\n\n");
  }
    
  OpEnd();

  return 0;
}

// --------------------- Opcodes 0x7000+ ---------------------
// Emit a Move Quick opcode, 0111nnn0 dddddddd  moveq #dd,Dn
int OpMoveq(int op)
{
  int use=0;

  use=op&0xf100; // Use same opcode for all values
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op); Cycles=4;

  ot("  movs r0,r8,asl #24\n");
  ot("  and r1,r8,#0x0e00\n");
  ot("  mov r0,r0,asr #24 ;@ Sign extended Quick value\n");
  OpGetFlagsNZ(0);
  ot("  str r0,[r7,r1,lsr #7] ;@ Store into Dn\n");
  ot("\n");

  OpEnd();

  return 0;
}

// --------------------- Opcodes 0xc140+ ---------------------
// Emit a Exchange opcode:
// 1100ttt1 01000sss  exg ds,dt
// 1100ttt1 01001sss  exg as,at
// 1100ttt1 10001sss  exg as,dt
int OpExg(int op)
{
  int use=0,type=0;

  type=op&0xf8;

  if (type!=0x40 && type!=0x48 && type!=0x88) return 1; // Not an exg opcode

  use=op&0xf1f8; // Use same opcode for all values
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler

  OpStart(op); Cycles=6;

  ot("  and r2,r8,#0x0e00 ;@ Find T register\n");
  ot("  and r3,r8,#0x000f ;@ Find S register\n");
  if (type==0x48) ot("  orr r2,r2,#0x1000 ;@ T is an address register\n");
  ot("\n");
  ot("  ldr r0,[r7,r2,lsr #7] ;@ Get T\n");
  ot("  ldr r1,[r7,r3,lsl #2] ;@ Get S\n");
  ot("\n");
  ot("  str r0,[r7,r3,lsl #2] ;@ T->S\n");
  ot("  str r1,[r7,r2,lsr #7] ;@ S->T\n");  
  ot("\n");

  OpEnd();
  
  return 0;
}

// ------------------------- movep -------------------------------
// 0000ddd1 0z001sss
// 0000sss1 1z001ddd (to mem)
int OpMovep(int op)
{
  int ea=0,rea=0;
  int size=1,use=0,dir,aadd=0;

  use=op&0xf1f8;
  if (op!=use) { OpUse(op,use); return 0; } // Use existing handler (for all dests, srcs)

  // Get EA
  ea = (op&0x0007)|0x28;
  rea= (op&0x0e00)>>9;
  dir = (op>>7)&1;

  // Find size extension
  if(op&0x0040) size=2;

  OpStart(op,ea);
  
  if(dir) // reg to mem
  {
    EaCalcReadNoSE(-1,11,rea,size,0x0e00);

    EaCalc(8,0x000f,ea,size);
    if(size==2) { // if operand is long
      ot("  mov r1,r11,lsr #24 ;@ first byte\n");
      EaWrite(8,1,ea,0,0x000f); // store first byte
      ot("  add r0,r8,#%i\n",(aadd+=2));
      ot("  mov r1,r11,lsr #16 ;@ second byte\n");
      EaWrite(0,1,ea,0,0x000f); // store second byte
      ot("  add r0,r8,#%i\n",(aadd+=2));
    } else {
      ot("  mov r0,r8\n");
    }
    ot("  mov r1,r11,lsr #8 ;@ first or third byte\n");
    EaWrite(0,1,ea,0,0x000f);
    ot("  add r0,r8,#%i\n",(aadd+=2));
    ot("  and r1,r11,#0xff\n");
    EaWrite(0,1,ea,0,0x000f);
  }
  else // mem to reg
  {
    EaCalc(6,0x000f,ea,size,1);
    EaRead(6,11,ea,0,0x000f,1); // read first byte
    ot("  add r0,r6,#2\n");
    EaRead(0,1,ea,0,0x000f,1); // read second byte
    if(size==2) { // if operand is long
      ot("  orr r11,r11,r1,lsr #8 ;@ second byte\n");
      ot("  add r0,r6,#4\n");
      EaRead(0,1,ea,0,0x000f,1);
      ot("  orr r11,r11,r1,lsr #16 ;@ third byte\n");
      ot("  add r0,r6,#6\n");
      EaRead(0,1,ea,0,0x000f,1);
      ot("  orr r1,r11,r1,lsr #24 ;@ fourth byte\n");
    } else {
      ot("  orr r1,r11,r1,lsr #8 ;@ second byte\n");
    }
    // store the result
    EaCalc(0,0x0e00,rea,size,1);
    EaWrite(0,1,rea,size,0x0e00,1);
    ot("  ldr r6,[r7,#0x54]\n");
  }

  Cycles=(size==2)?24:16;
  OpEnd(ea);

  return 0;
}

// Emit a Stop/Reset opcodes, 01001110 011100t0 imm
int OpStopReset(int op)
{
  int type=(op>>1)&1; // stop/reset

  OpStart(op,0,0,0,1);

  if(type) {
    // copy immediate to SR, stop the CPU and eat all remaining cycles.
    ot("  ldrh r0,[r4],#2 ;@ Fetch the immediate\n");
    OpRegToFlags(1);
    SuperChange(op,0);

    ot("\n");

    ot("  ldr r0,[r7,#0x58]\n");
    ot("  mov r5,#0 ;@ eat cycles\n");
    ot("  orr r0,r0,#1 ;@ stopped\n");
    ot("  str r0,[r7,#0x58]\n");
    ot("\n");

    Cycles = 4;
    ot("\n");
  }
  else
  {
    Cycles = 132;
#if USE_RESET_CALLBACK
    ot("  str r4,[r7,#0x40] ;@ Save PC\n");
    ot("  mov r1,r10,lsr #28\n");
    ot("  strb r1,[r7,#0x46] ;@ Save Flags (NZCV)\n");
    ot("  str r5,[r7,#0x5c] ;@ Save Cycles\n");
    ot("  ldr r11,[r7,#0x90] ;@ ResetCallback\n");
    ot("  tst r11,r11\n");
    ot("  movne lr,pc\n");
    ot("  bxne r11 ;@ call ResetCallback if it is defined\n");
    ot("  ldrb r10,[r7,#0x46] ;@ r10 = Load Flags (NZCV)\n");
    ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
    ot("  ldr r4,[r7,#0x40] ;@ Load PC\n");
    ot("  mov r10,r10,lsl #28\n");
    ot("\n");
#endif
  }

  OpEnd();

  return 0;
}

