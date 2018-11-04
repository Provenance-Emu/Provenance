/*  Copyright 2005-2006 Fabien Coulon

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

/*! \file sh2idle.c
    \brief SH2 interpreter interface with idle detection.
*/

#include "sh2core.h"
#include "sh2idle.h"
#include "sh2int.h"
#include "sh2d.h"
#include "memory.h"

#define MAX_CYCLE_CHECK 14
// idle loops greater than MAX_CYCLE_CHECK instructions will not be detected. 

/* Detection of idle loops: ie loops in which no write to memory is
done, ending with a conditional jump, at the point of which all registers are
"deterministic" in the sense they don't depend on the number of
executed loops */

/* bDet : Bitwise register markers. 1: register is deterministic
   bChg : Bitwise register markers. 1: register has been changed, not in a deterministic way */

u32 bDet, bChg;

/* Macro <implies(dest,src)> : makes changes resulting from the
   execution of an instruction in which the content of <dest> register
   only depends on <src> register(s) (and potentially constant values,
   including memory content which is constant in an idle loop) */

#define delayCheck(PC) SH2idleCheckIterate( fetchlist[((PC) >> 20) & 0x0FF](PC), PC )

#define implies(dest,src) if ( src ) bDet |= dest; else bChg |= dest;
#define implies2(dest,dest2,src) if ( src ) bDet |= dest|dest2; else bChg |= dest|dest2;
#define implies3(dest,dest2,dest3,src) if ( src ) bDet |= dest|dest2|dest3; else bChg |= dest|dest2|dest3;

#define destRB (1<<INSTRUCTION_B(instruction))
#define destRC (1<<INSTRUCTION_C(instruction))
#define destMACL 0x10000
#define destMACH 0x20000
#define destMAC 0x30000
#define destSRT 0x40000
#define destSRQ 0x80000
#define destSRS 0x100000
#define destSRI 0x200000
#define destSRM 0x400000
#define destSR 0x7C0000
#define destPR 0x800000
#define destGBR 0x1000000
#define destVBR 0x2000000
#define destCONST 0x4000000
#define destR0 1
#define destR15 (1<<15)

#define srcSRT (bDet & destSRT )
#define srcSRS (bDet & destSRS)
#define srcSRQ (bDet & destSRQ)
#define srcSRM (bDet & destSRM)
#define srcGBR (bDet & destGBR)
#define srcVBR (bDet & destVBR)
#define srcSR (!(destSR & ~bDet))
#define srcRC (bDet & destRC)
#define srcRB (bDet & destRB)
#define srcR0 (bDet & destR0)
#define srcR15 (bDet & destR15)
#define srcMACL (bDet & destMACL)
#define srcMACH (bDet & destMACH)
#define srcMAC (!(destMAC & ~bDet))
#define srcPR (bDet & destPR)
#define isConst(src) if ( (bDet & destCONST) && !src ) return 0; 

static int FASTCALL SH2idleCheckIterate(u16 instruction, u32 PC) {
  // update bDet after execution of <instruction>
  // return 0 : cannot continue idle check, probably because of a memory write

  switch (INSTRUCTION_A(instruction))
    {
    case 0:
      switch (INSTRUCTION_D(instruction))
	{
	case 2:
	  switch (INSTRUCTION_C(instruction))
	    {
	    case 0: implies(destRB, srcSR); //stcsr
	      break;
	    case 1: implies(destRB, srcGBR); //stcgbr;
	      break;
	    case 2: implies(destRB, srcVBR); //stcvbr;
	      break;
	    }
	  break;
	case 3:
	  switch (INSTRUCTION_C(instruction))
	    {
	    case 0: implies( destPR, 1 ); //bsrf;
	    case 2: isConst( srcRB );
	      return delayCheck(PC+2); //braf;
	    }
	  break;
	case 4: //movbs0;
	case 5: //movws0;
	case 6: return 0;  //movls0;
	case 7: implies(destMACL, srcRC && srcRB );  // mull
	  break;
	case 8:
	  switch (INSTRUCTION_C(instruction))
	    {
	    case 0:  //clrt;
	    case 1: implies( destSRT, 1 );  //sett;
	      break;
	    case 2: implies( destMAC, 1 );  //clrmac;
	      break;
	    }     
	  break;
	case 9:
	  switch (INSTRUCTION_C(instruction))
	    {
	    case 0:  //nop;
	      break;
	    case 1: implies3( destSRM, destSRQ, destSRT, 1 );  //div0u;
	      break;
	    case 2: implies(destRB, srcSRT );   //movt;
	      break;
	    }     
	  break;
	case 10:
	  switch (INSTRUCTION_C(instruction))
	    {
	    case 0: implies(destRB, srcMACH);   //stsmach;
	      break;
	    case 1: implies(destRB, srcMACL);   //stsmacl;
	      break;
	    case 2: implies(destRB, srcPR);   //stspr;
	      break;
	    }     
	  break;
	case 11:
	  switch (INSTRUCTION_C(instruction))
	    {
	    case 1: //sleep;
	      break;
	    case 0: isConst(srcPR); //rts;
	      return delayCheck(PC+2);
	    case 2: 
	      isConst(srcR15);
	      implies(destSR, srcR15);
	      return delayCheck(PC+2);  //rte;
	    }     
	  break;
	case 12: //movbl0;
	case 13:  //movwl0;
	case 14:  implies(destRB, srcRC && srcR0);  //movll0;
	  break;
	case 15:  implies(destMAC, srcRC && srcRB && srcSRS && srcMACL && srcMACH); //macl
	  break;
	}
      break;
    case 1: return 0; //movls4;
    case 2:
      switch (INSTRUCTION_D(instruction))
	{
	case 0:  //movbs;
	case 1:  //movws;
	case 2: return 0; //movls;
	case 4:  //movbm;
	case 5:  //movwm;
	case 6:  return 0;//movlm;
	case 7: implies(destSR, srcRC && srcRB ); //div0s
	  break;
	case 8: implies(destSRT, srcRC && srcRB ); //tst
	  break;
	case 9:  //y_and;
	case 10:  //y_xor;
	case 11: implies( destRB, srcRB && srcRC ); //y_or
	  break;
	case 12: implies( destSRT, srcRC && srcRB ); //cmpstr;
	  break;
	case 13: implies( destRB, srcRB && srcRC ); //xtrct
	  break;
	case 14: implies( destMAC, srcRB && srcRC ); //mulu
	  break;
	case 15: implies( destMACL, srcRB && srcRC ); //muls
	  break;
	}
      break;
    case 3:
      switch(INSTRUCTION_D(instruction))
	{
	case 0:  //cmpeq;
	case 2:   //cmphs;
	case 6:   //cmphi;
	case 7:   //cmpgt;
	case 3: implies( destSRT, srcRB && srcRC );
	  break;
	case 4: implies3( destSRQ, destSRT, destRB, srcRB && srcRC && srcSRQ && srcSRM );  //div1; /* CHECK ME */
	  break;
	case 13:   //dmuls;
	case 5: implies( destMAC, srcRB && srcRC ); // dmulu
	  break;
	case 8: implies( destRB, srcRB && srcRC ); //sub
	  break;
	case 15:  //addv;
	case 11: implies( destSRT, srcRB && srcRC ); //subv
	  break;
	case 12: implies( destRB, srcRB && srcRC ); //add
	  break;
	case 10:   //subc;
	case 14: implies2( destRB, destSRT, srcRB && srcRC && srcSRT ); //addc
	  break;
	}
      break;
    case 4:
      switch(INSTRUCTION_D(instruction))
	{
	case 0:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 1: //dt;
	    case 0: //shll;
	    case 2: implies2( destSRT, destRB, srcRB ); //shal
	      break;
	    }
	  break;
	case 1:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 2:
	    case 0:  implies2( destSRT, destRB, srcRB ); //shlr;
	      break;
	    case 1: implies( destSRT, srcRB ); //cmppz
	      break;
	    }     
	  break;
	case 2:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0:  //stsmmach;
	    case 1:  //stsmmacl;
	    case 2:  return 0;//stsmpr;
	    }
	  break;
	case 3:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0:  //stcmsr;
	    case 1:  //stcmgbr;
	    case 2: return 0; //stcmvbr;
	    }
	  break;
	case 4:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0:  //rotl;
	    case 2: implies2( destRB, destSRT, srcRB ); //rotcl
	    }     
	  break;
	case 5:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0: implies2( destRB, destSRT, srcRB ); //rotr;
	      break;
	    case 1: implies( destSRT, srcRB ); //cmppl;
	      break;
	    case 2: implies2( destSRT, destRB, srcSRT && srcRB ); //rotcr
	      break;
	    }       
          break;
	case 6:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0: implies( destMACH, srcRB ); //ldsmmach
	      break;
	    case 1: implies( destMACL, srcRB ); //lsdmmacl
	      break;
	    case 2: implies( destPR, srcRB ); //ldsmpr
	      break;
	    }     
	  break;
	case 7:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0: implies( destSR, srcRB ); //ldcmsr
	      break;
	    case 1: implies( destGBR, srcRB ); //ldcmgbr
	      break;
	    case 2: implies( destVBR, srcRB ); //lscmvbr
	      break;
	    }     
	  break;
	case 8:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0:  //shll2;
	    case 1:  //shll8;
	    case 2: implies( destRB, srcRB ); //shll16
	    }     
	  break;
	case 9:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0:  //shlr2;
	    case 1:  //shlr8;
	    case 2: implies( destRB, srcRB ); //shlr16
	    }     
	  break;
	case 10:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0: implies( destMACH, srcRB ); //ldsmach
	      break;
	    case 1: implies( destMACL, srcRB ); //ldsmacl
	      break;
	    case 2: implies( destPR, srcRB ); //ldspr
	      break;
	    }     
	  break;
	case 11:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0: isConst( srcRB );
	      implies( destPR, 1 );
	      break; //jsr
	    case 1:  return 0; //tas;
	    case 2: isConst( srcRB );
	      return delayCheck(PC+2); //jmp
	    }     
	  break;
	case 14:
	  switch(INSTRUCTION_C(instruction))
	    {
	    case 0:  implies( destSR, srcRB ); //ldcsr
	      break;
	    case 1: implies( destGBR, srcRB ); //ldcgbr
	      break;
	    case 2: implies( destVBR, srcRB ); //ldcvrb
	      break;
	    }
	  break;
	case 15: implies( destMAC, srcRB && srcRC && srcMAC ); //macw
	  break;
	}
    case 5: implies( destRB, srcRC ); //movll4
      break;
    case 6:
      switch (INSTRUCTION_D(instruction))
	{
	case 6:   //movlp;
	case 5:   //movwp;
	case 4: return 0;  //movbp;
	case 0:  //movbl;
	case 1:   //movwl;
	case 2:   //movll;
	case 3:   //mov;
	case 7:   //y_not;
	case 8:   //swapb;
	case 11:  //neg;
	case 12:  //extub;
	case 13:  //extuw;
	case 14:  //extsb;
	case 15:  //extsw;
	case 9:  implies( destRB, srcRC ); //swapw;
	  break;
	case 10:  implies2( destRB, destSRT, srcRB && srcSRT ); //negc
	  break;
	}
      break;
    case 7: implies( destRB, srcRB ); //addi;
      break;
    case 8:
      switch (INSTRUCTION_B(instruction))
	{
	case 0:   //movbs4;
	case 1:  return 0;  //movws4;
	case 4:   //movbl4;
	case 5: implies( destR0, srcRC );   //movwl4;
	  break;
	case 8: implies( destSRT, srcR0 ); //cmpim;
	  break;
	case 9:   //bt;
	case 11:  //bf;
	case 13:  //bts;
	case 15: return 0; //bfs;
	}   
      break;
    case 9: implies( destRB, 1 );  //movwi;
      break;
    case 10: return delayCheck(PC+2); //bra;
    case 11: implies( destPR, 1 ); return delayCheck(PC+2); //bsr;
    case 12:
      switch(INSTRUCTION_B(instruction))
	{
	case 0:   //movbsg;
	case 1:   //movwsg;
	case 2:   //movlsg;
	case 3: return 0;  //trapa;
	case 4:   //movblg;
	case 5:   //movwlg;
	case 6: implies( destR0, srcGBR ); //movllg
	  break;
	case 7: implies( destR0, 1 );   //mova;
	  break;
	case 8: implies( destSRT, srcR0 );  //tsti;
	  break;
	case 9:   //andi;
	case 10:  //xori;
	case 11: implies( destR0, srcR0 ); //ori;
	  break;
	case 12: implies( destSRT, srcGBR && srcR0 );   //tstm;
	  break;
	case 13:  //andm;
	case 14:  //xorm;
	case 15:  return 0;//orm;
	}
      break;
    case 13: //movli;
    case 14: implies( destRB, 1 );  //movi;
      break;
    }
  return 1;
}

#ifdef IDLE_DETECT_VERBOSE
static u32 idleCheckCount = 0;
static u32 sh2cycleCount = 0;
static u32 sh2oldCycleCount = 0;
static u32 oldCheckCount = 0;

#define DROP_IDLE {\
    idleCheckCount += cycles - context->cycles; \
    context->cycles = cycles;}
#define IDLE_VERBOSE_SH2_COUNT {\
   sh2cycleCount += cycles; \
    if ( sh2cycleCount-sh2oldCycleCount > 0x4ffffff ) { \
      fprintf( stderr, "%lu idle instructions dropped / %lu sh2 instructions parsed : %g %%\n", \
	       idleCheckCount-oldCheckCount, sh2cycleCount-sh2oldCycleCount, \
	       (float)(idleCheckCount-oldCheckCount)/(sh2cycleCount-sh2oldCycleCount)*100 ); \
      oldCheckCount = idleCheckCount; \
      sh2oldCycleCount = sh2cycleCount; \
    }}
#else
#define DROP_IDLE context->cycles = cycles;
#define IDLE_VERBOSE_SH2_COUNT
#endif

void FASTCALL SH2idleCheck(SH2_struct *context, u32 cycles) {
  // try to find an idle loop while interpreting

  u8 isDelayed = 0;
  u32 loopEnd;
  u32 loopBegin;
  s32 disp;
  u32 cyclesCheckEnd;
  u32 PC1, PC2, PC3;

  IDLE_VERBOSE_SH2_COUNT;

  // run until conditional branching - delayed instruction excluded

  for (;;) {
      // Fetch Instruction
       context->instruction = fetchlist[(context->regs.PC >> 20) & 0x0FF](context->regs.PC);

      if ( INSTRUCTION_A(context->instruction)==8 ) {

	switch( INSTRUCTION_B(context->instruction) ) {
 	case 13: //SH2bts
 	  isDelayed = 1; 
	case 9:  //SH2bt
	  if (context->regs.SR.part.T != 1) {
	    context->regs.PC += 2;
	    context->cycles++;
	    return;
	  }
	  loopEnd = context->regs.PC;
	  disp = (s32)(s8)context->instruction;
	  loopBegin = context->regs.PC = context->regs.PC+(disp<<1)+4;
	  context->cycles += 3;
	  goto branching_reached;
	  break;
 	case 15: //SH2bfs
 	  isDelayed = 1; 
	case 11: //SH2bf
	  if (context->regs.SR.part.T == 1) {
	    context->regs.PC += 2;
	    context->cycles++;
	    return;
	  }
	  loopEnd = context->regs.PC;
	  disp = (s32)(s8)context->instruction;
	  loopBegin = context->regs.PC = context->regs.PC+(disp<<1)+4;
	  context->cycles += 3;
	  goto branching_reached;
	  break;
	default: opcodes[context->instruction](context);
	}
	} else opcodes[context->instruction](context);
      if ( context->cycles >= cycles ) return;
    }
 branching_reached:

  // if branching, execute (delayed included) until getting back to the conditional instruction  

  bDet = bChg = 0; // initialize markers
  cyclesCheckEnd = context->cycles + MAX_CYCLE_CHECK;

  if ( isDelayed ) {
    context->instruction = fetchlist[((loopEnd+2) >> 20) & 0x0FF](loopEnd+2);
    opcodes[context->instruction](context);
    context->regs.PC -= 2;
    if ( !SH2idleCheckIterate(context->instruction,0) ) return;
  }
  
  // First pass

  while ( context->regs.PC != loopEnd ) {

    PC1 = context->regs.PC;
    context->instruction = fetchlist[(PC1 >> 20) & 0x0FF](PC1);
    if ( !SH2idleCheckIterate(context->instruction,PC1) ) return;    
    opcodes[context->instruction](context);
    if ( context->cycles >= cyclesCheckEnd ) return;
  }

  // conditional jump 

  PC2 = context->regs.PC;
  context->instruction = fetchlist[(PC2 >> 20) & 0x0FF](PC2);
  opcodes[context->instruction](context);
  if ( context->regs.PC != loopBegin ) return; // We are not in a single loop... forget it

  // Mark unchanged registers as deterministic registers

  bDet = ~bChg;
  bDet |= destCONST; // some values need to be constant. From now, changing them is forbidden.

  // Second pass

  if ( isDelayed )
    if ( !SH2idleCheckIterate(fetchlist[((loopEnd+2) >> 20) & 0x0FF](loopEnd+2),0) ) return;

  while ( context->regs.PC != loopEnd ) {
    
    PC3 = context->regs.PC;
    context->instruction = fetchlist[(PC3 >> 20) & 0x0FF](PC3);
    if ( !SH2idleCheckIterate(context->instruction,PC3) ) return;    
    opcodes[context->instruction](context);
  }
  context->instruction = fetchlist[(PC2 >> 20) & 0x0FF](PC2);
  opcodes[context->instruction](context);  
  
  if ( context->regs.PC != loopBegin ) return;

#ifdef IDLE_DETECT_VERBOSE
  {
    static u32 oldLoopBegin[2][2] = {{0,0},{0,0}};

    if (( !~bDet )&&(loopBegin!=oldLoopBegin[context==MSH2][0])&&(loopBegin!=oldLoopBegin[context==MSH2][1])) {
      char lineBuf[64];
      u32 offset,end;
      printf( "New %s idle loop at %X -- %X\n", (context==MSH2)?"master":"slave", (int)loopBegin, (int)loopEnd );
      if ( loopEnd > loopBegin ) { offset = loopBegin; end = loopEnd; }
      else { offset = loopEnd; end = loopBegin; }
      for ( ; offset <= end ; offset+=2 ) {
        SH2Disasm(offset, MappedMemoryReadWord(offset), 0, lineBuf);
        printf( "%s\n", lineBuf );
      }
      oldLoopBegin[context==MSH2][1] = oldLoopBegin[context==MSH2][0];
      oldLoopBegin[context==MSH2][0] = loopBegin;
    }
  }
#endif
  if ( !~bDet ) {
    DROP_IDLE;
    context->isIdle = 1;
  }
}

void FASTCALL SH2idleParse( SH2_struct *context, u32 cycles ) {
  // called when <context> is in idle state : check whether we are still idle

  IDLE_VERBOSE_SH2_COUNT;
  for(;;) {
    
    u32 PC = context->regs.PC;
    context->instruction = fetchlist[(PC >> 20) & 0x0FF](PC);
    if ( INSTRUCTION_A(context->instruction)==8 ) {
      switch( INSTRUCTION_B(context->instruction) ) {
      case 13: //SH2bts
      case 9:  //SH2bt
	if ( !context->regs.SR.part.T ) context->isIdle = 0;
	else DROP_IDLE;
	opcodes[context->instruction](context);
	return;
      case 15: //SH2bfs
      case 11: //SH2bf
	if ( context->regs.SR.part.T ) context->isIdle = 0;
	else DROP_IDLE;
	opcodes[context->instruction](context);
	return;
      }   
    }
    opcodes[context->instruction](context);
  }
}

/* ------------------------------------------------------ */
/* Code markers                                           */
/*
typedef struct {

  u32 begin, end;
  u16 instruction;
} idlemarker;

idlemarker idleMark[1024];
int topMark = 0;

void addMarker( u32 begin, u32 end ) {
 
  if ( topMark < 1024 ) {
    idleMark[topMark].instruction = MappedMemoryReadWord(begin);
    if ( (idleMark[topMark].instruction & 0xff0000ff) == OPCODE_HC ) return;
    idleMark[topMark].begin = begin;
    idleMark[topMark].end = end;
    idleMark[topMark].instruction = MappedMemoryReadWord(begin);
    MappedMemoryWriteWord( begin, OPCODE_HC | (topMark<<8) );  
    topMark++;
  } else printf( stderr, "Code Marker overflow !\n" );
}

void markerExec( SH2_struct *sh, u16 nMark ) {

  opcodes[sh->instruction = idleMark[instruction]](sh); // execute the hidden instruction

  for{;;} {
    
    u32 PC = sh->regs.PC;
    sh->instruction = fetchlist[(PC >> 20) & 0x0FF](PC);
    if ( INSTRUCTION_A(context->instruction)==8 ) {
      switch( INSTRUCTION_B(context->instruction) ) {
      case 13: //SH2bts
      case 9:  //SH2bt
	if ( sh->regs.SR.T )
	  cycles = 0xffffffff;
	return;
      case 15: //SH2bfs
      case 11: //SH2bf
	if ( ! sh->regs.SR.T )
	  cycles = 0xffffffff;
	return;
      }   
    opcodes[context->instruction](context);
  }
}
*/
