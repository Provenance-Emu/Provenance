
// This file is part of the Cyclone 68000 Emulator

// Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
// Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/


#include "app.h"

static FILE *AsmFile=NULL;

static int CycloneVer=0x0099; // Version number of library
int *CyJump=NULL; // Jump table
int ms=USE_MS_SYNTAX; // If non-zero, output in Microsoft ARMASM format
const char * const Narm[4]={ "b", "h","",""}; // Normal ARM Extensions for operand sizes 0,1,2
const char * const Sarm[4]={"sb","sh","",""}; // Sign-extend ARM Extensions for operand sizes 0,1,2
int Cycles; // Current cycles for opcode
int pc_dirty; // something changed PC during processing
int arm_op_count;

// opcodes often used by games
static const unsigned short hot_opcodes[] = {
  0x6702, // beq     $3
  0x6602, // bne     $3
  0x51c8, // dbra    Dn, $2
  0x4a38, // tst.b   $0.w
  0xd040, // add.w   Dn, Dn
  0x4a79, // tst.w   $0.l
  0x0240, // andi.w  #$0, D0
  0x2038, // move.l  $0.w, D0
  0xb0b8, // cmp.l   $0.w, D0
  0x6002, // bra     $3
  0x30c0, // move.w  D0, (A0)+
  0x3028, // move.w  ($0,A0), D0
  0x0c40, // cmpi.w  #$0, D0
  0x0c79, // cmpi.w  #$0, $0.l
  0x4e75, // rts
  0x4e71, // nop
  0x3000, // move.w  D0, D0
  0x0839, // btst    #$0, $0.l
  0x7000, // moveq   #$0, D0
  0x3040, // movea.w D0, A0
  0x0838, // btst    #$0, $0.w
  0x4a39, // tst.b   $0.l
  0x33d8, // move.w  (A0)+, $0.l
  0x6700, // beq     $2
  0xb038, // cmp.b   $0.w, D0
  0x3039, // move.w  $0.l, D0
  0x4840, // swap    D0
  0x6102, // bsr     $3
  0x6100, // bsr     $2
  0x5e40, // addq.w  #7, D0
  0x1039, // move.b  $0.l, D0
  0x20c0, // move.l  D0, (A0)+
  0x1018, // move.b  (A0)+, D0
  0x30d0, // move.w  (A0), (A0)+
  0x3080, // move.w  D0, (A0)
  0x3018, // move.w  (A0)+, D0
  0xc040, // and.w   D0, D0
  0x3180, // move.w  D0, (A0,D0.w)
  0x1198, // move.b  (A0)+, (A0,D0.w)
  0x6502, // bcs     $3
  0x6500, // bcs     $2
  0x6402, // bcc     $3
  0x6a02, // bpl     $3
  0x41f0, // lea     (A0,D0.w), A0
  0x4a28, // tst.b   ($0,A0)
  0x0828, // btst    #$0, ($0,A0)
  0x0640, // addi.w  #$0, D0
  0x10c0, // move.b  D0, (A0)+
  0x10d8, // move.b  (A0)+, (A0)+
};
#define hot_opcode_count (int)(sizeof(hot_opcodes) / sizeof(hot_opcodes[0]))

static int is_op_hot(int op)
{
  int i;
  for (i = 0; i < hot_opcode_count; i++)
    if (op == hot_opcodes[i])
      return 1;
  return 0;
}

void ot(const char *format, ...)
{
  va_list valist;
  int i, len;

  // notaz: stop me from leaving newlines in the middle of format string
  // and generating bad code
  for(i=0, len=strlen(format); i < len && format[i] != '\n'; i++);
  if(i < len-1 && format[len-1] != '\n') printf("\nWARNING: possible improper newline placement:\n%s\n", format);

  if (format[0] == ' ' && format[1] == ' ' && format[2] != ' ' && format[2] != '.')
    arm_op_count++;

  va_start(valist,format);
  if (AsmFile) vfprintf(AsmFile,format,valist);
  va_end(valist);
}

void ltorg()
{
  if (ms) ot("  LTORG\n");
  else    ot("  .ltorg\n");
}

#if (CYCLONE_FOR_GENESIS == 2)
// r12=ptr to tas in table, trashes r0,r1
static void ChangeTAS(int norm)
{
  ot("  ldr r0,=Op4ad0%s\n",norm?"_":"");
  ot("  mov r1,#8\n");
  ot("setrtas_loop%i0%s ;@ 4ad0-4ad7\n",norm,ms?"":":");
  ot("  subs r1,r1,#1\n");
  ot("  str r0,[r12],#4\n");
  ot("  bne setrtas_loop%i0\n",norm);
  ot("  ldr r0,=Op4ad8%s\n",norm?"_":"");
  ot("  mov r1,#7\n");
  ot("setrtas_loop%i1%s ;@ 4ad8-4ade\n",norm,ms?"":":");
  ot("  subs r1,r1,#1\n");
  ot("  str r0,[r12],#4\n");
  ot("  bne setrtas_loop%i1\n",norm);
  ot("  ldr r0,=Op4adf%s\n",norm?"_":"");
  ot("  str r0,[r12],#4\n");
  ot("  ldr r0,=Op4ae0%s\n",norm?"_":"");
  ot("  mov r1,#7\n");
  ot("setrtas_loop%i2%s ;@ 4ae0-4ae6\n",norm,ms?"":":");
  ot("  subs r1,r1,#1\n");
  ot("  str r0,[r12],#4\n");
  ot("  bne setrtas_loop%i2\n",norm);
  ot("  ldr r0,=Op4ae7%s\n",norm?"_":"");
  ot("  str r0,[r12],#4\n");
  ot("  ldr r0,=Op4ae8%s\n",norm?"_":"");
  ot("  mov r1,#8\n");
  ot("setrtas_loop%i3%s ;@ 4ae8-4aef\n",norm,ms?"":":");
  ot("  subs r1,r1,#1\n");
  ot("  str r0,[r12],#4\n");
  ot("  bne setrtas_loop%i3\n",norm);
  ot("  ldr r0,=Op4af0%s\n",norm?"_":"");
  ot("  mov r1,#8\n");
  ot("setrtas_loop%i4%s ;@ 4af0-4af7\n",norm,ms?"":":");
  ot("  subs r1,r1,#1\n");
  ot("  str r0,[r12],#4\n");
  ot("  bne setrtas_loop%i4\n",norm);
  ot("  ldr r0,=Op4af8%s\n",norm?"_":"");
  ot("  str r0,[r12],#4\n");
  ot("  ldr r0,=Op4af9%s\n",norm?"_":"");
  ot("  str r0,[r12],#4\n");
}
#endif

#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO
static void AddressErrorWrapper(char rw, const char *dataprg, int iw)
{
  ot("ExceptionAddressError_%c_%s%s\n", rw, dataprg, ms?"":":");
  ot("  ldr r1,[r7,#0x44]\n");
  ot("  mov r6,#0x%02x\n", iw);
  ot("  mov r11,r0\n");
  ot("  tst r1,#0x20\n");
  ot("  orrne r6,r6,#4\n");
  ot("  b ExceptionAddressError\n");
  ot("\n");
}
#endif

void FlushPC(void)
{
#if MEMHANDLERS_NEED_PC
  if (pc_dirty)
    ot("  str r4,[r7,#0x40] ;@ Save PC\n");
#endif
  pc_dirty = 0;
}

static void PrintFramework()
{
  int state_flags_to_check = 1; // stopped
#if EMULATE_TRACE
  state_flags_to_check |= 2; // tracing
#endif
#if EMULATE_HALT
  state_flags_to_check |= 0x10; // halted
#endif

  ot(";@ --------------------------- Framework --------------------------\n");
  if (ms) ot("CycloneRun\n");
  else    ot("CycloneRun:\n");

  ot("  stmdb sp!,{r4-r8,r10,r11,lr}\n");

  ot("  mov r7,r0          ;@ r7 = Pointer to Cpu Context\n");
  ot("                     ;@ r0-3 = Temporary registers\n");
  ot("  ldrb r10,[r7,#0x46]    ;@ r10 = Flags (NZCV)\n");
  ot("  ldr r6,=CycloneJumpTab ;@ r6 = Opcode Jump table\n");
  ot("  ldr r5,[r7,#0x5c]  ;@ r5 = Cycles\n");
  ot("  ldr r4,[r7,#0x40]  ;@ r4 = Current PC + Memory Base\n");
  ot("                     ;@ r8 = Current Opcode\n");
  ot("  ldr r1,[r7,#0x44]  ;@ Get SR high T_S__III and irq level\n");
  ot("  mov r10,r10,lsl #28;@ r10 = Flags 0xf0000000, cpsr format\n");
  ot("                     ;@ r11 = Source value / Memory Base\n");
  ot("  str r6,[r7,#0x54]  ;@ make a copy to avoid literal pools\n");
  ot("\n");
#if (CYCLONE_FOR_GENESIS == 2) || EMULATE_TRACE
  ot("  mov r2,#0\n");
  ot("  str r2,[r7,#0x98]  ;@ clear custom CycloneEnd\n");
#endif
  ot(";@ CheckInterrupt:\n");
  ot("  movs r0,r1,lsr #24 ;@ Get IRQ level\n"); // same as  ldrb r0,[r7,#0x47]
  ot("  beq NoInts0\n");
  ot("  cmp r0,#6 ;@ irq>6 ?\n");
  ot("  andle r1,r1,#7 ;@ Get interrupt mask\n");
  ot("  cmple r0,r1 ;@ irq<=6: Is irq<=mask ?\n");
  ot("  bgt CycloneDoInterrupt\n");
  ot("NoInts0%s\n", ms?"":":");
  ot("\n");
  ot(";@ Check if our processor is in special state\n");
  ot(";@ and jump to opcode handler if not\n");
  ot("  ldr r0,[r7,#0x58] ;@ state_flags\n");
  ot("  ldrh r8,[r4],#2 ;@ Fetch first opcode\n");
  ot("  tst r0,#0x%02x ;@ special state?\n", state_flags_to_check);
  ot("  ldreq pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
  ot("\n");
  ot("CycloneSpecial%s\n", ms?"":":");
#if EMULATE_TRACE
  ot("  tst r0,#2 ;@ tracing?\n");
  ot("  bne CycloneDoTrace\n");
#endif
  ot(";@ stopped or halted\n");
  ot("  mov r5,#0\n");
  ot("  str r5,[r7,#0x5C]  ;@ eat all cycles\n");
  ot("  ldmia sp!,{r4-r8,r10,r11,pc} ;@ we are stopped, do nothing!\n");
  ot("\n");
  ot("\n");

  ot(";@ We come back here after execution\n");
  ot("CycloneEnd%s\n", ms?"":":");
  ot("  sub r4,r4,#2\n");
  ot("CycloneEndNoBack%s\n", ms?"":":");
#if (CYCLONE_FOR_GENESIS == 2) || EMULATE_TRACE
  ot("  ldr r1,[r7,#0x98]\n");
  ot("  mov r10,r10,lsr #28\n");
  ot("  tst r1,r1\n");
  ot("  bxne r1            ;@ jump to alternative CycloneEnd\n");
#else
  ot("  mov r10,r10,lsr #28\n");
#endif
  ot("  str r4,[r7,#0x40]  ;@ Save Current PC + Memory Base\n");
  ot("  str r5,[r7,#0x5c]  ;@ Save Cycles\n");
  ot("  strb r10,[r7,#0x46] ;@ Save Flags (NZCV)\n");
  ot("  ldmia sp!,{r4-r8,r10,r11,pc}\n");
  ltorg();
  ot("\n");
  ot("\n");

  ot("CycloneInit%s\n", ms?"":":");
#if COMPRESS_JUMPTABLE
  ot(";@ decompress jump table\n");
  ot("  ldr r12,=CycloneJumpTab\n");
  ot("  add r0,r12,#0xe000*4 ;@ ctrl code pointer\n");
  ot("  ldr r1,[r0,#-4]\n");
  ot("  tst r1,r1\n");
  ot("  movne pc,lr ;@ already uncompressed\n");
  ot("  add r3,r12,#0xa000*4 ;@ handler table pointer, r12=dest\n");
  ot("unc_loop%s\n", ms?"":":");
  ot("  ldrh r1,[r0],#2\n");
  ot("  and r2,r1,#0xf\n");
  ot("  bic r1,r1,#0xf\n");
  ot("  ldr r1,[r3,r1,lsr #2] ;@ r1=handler\n");
  ot("  cmp r2,#0xf\n");
  ot("  addeq r2,r2,#1 ;@ 0xf is really 0x10\n");
  ot("  tst r2,r2\n");
  ot("  ldreqh r2,[r0],#2 ;@ counter is in next word\n");
  ot("  tst r2,r2\n");
  ot("  beq unc_finish ;@ done decompressing\n");
  ot("  tst r1,r1\n");
  ot("  addeq r12,r12,r2,lsl #2 ;@ 0 handler means we should skip those bytes\n");
  ot("  beq unc_loop\n");
  ot("unc_loop_in%s\n", ms?"":":");
  ot("  subs r2,r2,#1\n");
  ot("  str r1,[r12],#4\n");
  ot("  bgt unc_loop_in\n");
  ot("  b unc_loop\n");
  ot("unc_finish%s\n", ms?"":":");
  ot("  ldr r12,=CycloneJumpTab\n");
  ot("  ;@ set a-line and f-line handlers\n");
  ot("  add r0,r12,#0xa000*4\n");
  ot("  ldr r1,[r0,#4] ;@ a-line handler\n");
  ot("  ldr r3,[r0,#8] ;@ f-line handler\n");
  ot("  mov r2,#0x1000\n");
  ot("unc_fill3%s\n", ms?"":":");
  ot("  subs r2,r2,#1\n");
  ot("  str r1,[r0],#4\n");
  ot("  bgt unc_fill3\n");
  ot("  add r0,r12,#0xf000*4\n");
  ot("  mov r2,#0x1000\n");
  ot("unc_fill4%s\n", ms?"":":");
  ot("  subs r2,r2,#1\n");
  ot("  str r3,[r0],#4\n");
  ot("  bgt unc_fill4\n");
  ot("  bx lr\n");
  ltorg();
#else
  ot(";@ fix final jumptable entries\n");
  ot("  ldr r12,=CycloneJumpTab\n");
  ot("  add r12,r12,#0x10000*4\n");
  ot("  ldr r0,[r12,#-3*4]\n");
  ot("  str r0,[r12,#-2*4]\n");
  ot("  str r0,[r12,#-1*4]\n");
  ot("  bx lr\n");
#endif
  ot("\n");

  // --------------
  ot("CycloneReset%s\n", ms?"":":");
  ot("  stmfd sp!,{r7,lr}\n");
  ot("  mov r7,r0\n");
  ot("  mov r0,#0\n");
  ot("  str r0,[r7,#0x58] ;@ state_flags\n");
  ot("  str r0,[r7,#0x48] ;@ OSP\n");
  ot("  mov r1,#0x27 ;@ Supervisor mode\n");
  ot("  strb r1,[r7,#0x44] ;@ set SR high\n");
  ot("  strb r0,[r7,#0x47] ;@ IRQ\n");
  MemHandler(0,2);
  ot("  str r0,[r7,#0x3c] ;@ Stack pointer\n");
  ot("  mov r0,#0\n");
  ot("  str r0,[r7,#0x60] ;@ Membase\n");
  ot("  mov r0,#4\n");
  MemHandler(0,2);
#ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bl %scheckpc ;@ Call checkpc()\n", MEMHANDLERS_DIRECT_PREFIX);
#else
  ot("  mov lr,pc\n");
  ot("  ldr pc,[r7,#0x64] ;@ Call checkpc()\n");
#endif
  ot("  str r0,[r7,#0x40] ;@ PC + base\n");
  ot("  ldmfd sp!,{r7,pc}\n");
  ot("\n");

  // --------------
  // 68k: XNZVC, ARM: NZCV
  ot("CycloneSetSr%s\n", ms?"":":");
  ot("  mov r2,r1,lsr #8\n");
//  ot("  ldrb r3,[r0,#0x44] ;@ get SR high\n");
//  ot("  eor r3,r3,r2\n");
//  ot("  tst r3,#0x20\n");
#if EMULATE_TRACE
  ot("  and r2,r2,#0xa7 ;@ only defined bits\n");
#else
  ot("  and r2,r2,#0x27 ;@ only defined bits\n");
#endif
  ot("  strb r2,[r0,#0x44] ;@ set SR high\n");
  ot("  mov r2,r1,lsl #25\n");
  ot("  str r2,[r0,#0x4c] ;@ the X flag\n");
  ot("  bic r2,r1,#0xf3\n");
  ot("  tst r1,#1\n");
  ot("  orrne r2,r2,#2\n");
  ot("  tst r1,#2\n");
  ot("  orrne r2,r2,#1\n");
  ot("  strb r2,[r0,#0x46] ;@ flags\n");
  ot("  bx lr\n");
  ot("\n");

  // --------------
  ot("CycloneGetSr%s\n", ms?"":":");
  ot("  ldrb r1,[r0,#0x46] ;@ flags\n");
  ot("  bic r2,r1,#0xf3\n");
  ot("  tst r1,#1\n");
  ot("  orrne r2,r2,#2\n");
  ot("  tst r1,#2\n");
  ot("  orrne r2,r2,#1\n");
  ot("  ldr r1,[r0,#0x4c] ;@ the X flag\n");
  ot("  tst r1,#0x20000000\n");
  ot("  orrne r2,r2,#0x10\n");
  ot("  ldrb r1,[r0,#0x44] ;@ the SR high\n");
  ot("  orr r0,r2,r1,lsl #8\n");
  ot("  bx lr\n");
  ot("\n");

  // --------------
  ot("CyclonePack%s\n", ms?"":":");
  ot("  stmfd sp!,{r4,r5,lr}\n");
  ot("  mov r4,r0\n");
  ot("  mov r5,r1\n");
  ot("  mov r3,#16\n");
  ot(";@ 0x00-0x3f: DA registers\n");
  ot("c_pack_loop%s\n",ms?"":":");
  ot("  ldr r1,[r0],#4\n");
  ot("  subs r3,r3,#1\n");
  ot("  str r1,[r5],#4\n");
  ot("  bne c_pack_loop\n");
  ot(";@ 0x40: PC\n");
  ot("  ldr r0,[r4,#0x40] ;@ PC + Memory Base\n");
  ot("  ldr r1,[r4,#0x60] ;@ Memory base\n");
  ot("  sub r0,r0,r1\n");
  ot("  str r0,[r5],#4\n");
  ot(";@ 0x44: SR\n");
  ot("  mov r0,r4\n");
  ot("  bl CycloneGetSr\n");
  ot("  strh r0,[r5],#2\n");
  ot(";@ 0x46: IRQ level\n");
  ot("  ldrb r0,[r4,#0x47]\n");
  ot("  strb r0,[r5],#2\n");
  ot(";@ 0x48: other SP\n");
  ot("  ldr r0,[r4,#0x48]\n");
  ot("  str r0,[r5],#4\n");
  ot(";@ 0x4c: CPU state flags\n");
  ot("  ldr r0,[r4,#0x58]\n");
  ot("  str r0,[r5],#4\n");
  ot("  ldmfd sp!,{r4,r5,pc}\n");
  ot("\n");

  // --------------
  ot("CycloneUnpack%s\n", ms?"":":");
  ot("  stmfd sp!,{r5,r7,lr}\n");
  ot("  mov r7,r0\n");
  ot("  movs r5,r1\n");
  ot("  beq c_unpack_do_pc\n");
  ot("  mov r3,#16\n");
  ot(";@ 0x00-0x3f: DA registers\n");
  ot("c_unpack_loop%s\n",ms?"":":");
  ot("  ldr r1,[r5],#4\n");
  ot("  subs r3,r3,#1\n");
  ot("  str r1,[r0],#4\n");
  ot("  bne c_unpack_loop\n");
  ot(";@ 0x40: PC\n");
  ot("  ldr r0,[r5],#4 ;@ PC\n");
  ot("  str r0,[r7,#0x40] ;@ handle later\n");
  ot(";@ 0x44: SR\n");
  ot("  ldrh r1,[r5],#2\n");
  ot("  mov r0,r7\n");
  ot("  bl CycloneSetSr\n");
  ot(";@ 0x46: IRQ level\n");
  ot("  ldrb r0,[r5],#2\n");
  ot("  strb r0,[r7,#0x47]\n");
  ot(";@ 0x48: other SP\n");
  ot("  ldr r0,[r5],#4\n");
  ot("  str r0,[r7,#0x48]\n");
  ot(";@ 0x4c: CPU state flags\n");
  ot("  ldr r0,[r5],#4\n");
  ot("  str r0,[r7,#0x58]\n");
  ot("c_unpack_do_pc%s\n",ms?"":":");
  ot("  ldr r0,[r7,#0x40] ;@ unbased PC\n");
#if USE_CHECKPC_CALLBACK
  ot("  mov r1,#0\n");
  ot("  str r1,[r7,#0x60] ;@ Memory base\n");
 #ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bl %scheckpc ;@ Call checkpc()\n", MEMHANDLERS_DIRECT_PREFIX);
 #else
  ot("  mov lr,pc\n");
  ot("  ldr pc,[r7,#0x64] ;@ Call checkpc()\n");
 #endif
#else
  ot("  ldr r1,[r7,#0x60] ;@ Memory base\n");
  ot("  add r0,r0,r1 ;@ r0 = Memory Base + New PC\n");
#endif
  ot("  str r0,[r7,#0x40] ;@ PC + Memory Base\n");
  ot("  ldmfd sp!,{r5,r7,pc}\n");
  ot("\n");

  // --------------
  ot("CycloneFlushIrq%s\n", ms?"":":");
  ot("  ldr r1,[r0,#0x44]  ;@ Get SR high T_S__III and irq level\n");
  ot("  mov r2,r1,lsr #24 ;@ Get IRQ level\n"); // same as  ldrb r0,[r7,#0x47]
  ot("  cmp r2,#6 ;@ irq>6 ?\n");
  ot("  andle r1,r1,#7 ;@ Get interrupt mask\n");
  ot("  cmple r2,r1 ;@ irq<=6: Is irq<=mask ?\n");
  ot("  movle r0,#0\n");
  ot("  bxle lr ;@ no ints\n");
  ot("\n");
  ot("  stmdb sp!,{r4,r5,r7,r8,r10,r11,lr}\n");
  ot("  mov r7,r0\n");
  ot("  mov r0,r2\n");
  ot("  ldrb r10,[r7,#0x46]  ;@ r10 = Flags (NZCV)\n");
  ot("  mov r5,#0\n");
  ot("  ldr r4,[r7,#0x40]    ;@ r4 = Current PC + Memory Base\n");
  ot("  mov r10,r10,lsl #28  ;@ r10 = Flags 0xf0000000, cpsr format\n");
  ot("  adr r2,CycloneFlushIrqEnd\n");
  ot("  str r2,[r7,#0x98]  ;@ set custom CycloneEnd\n");
  ot("  b CycloneDoInterrupt\n");
  ot("\n");
  ot("CycloneFlushIrqEnd%s\n", ms?"":":");
  ot("  rsb r0,r5,#0\n");
  ot("  str r4,[r7,#0x40]   ;@ Save Current PC + Memory Base\n");
  ot("  strb r10,[r7,#0x46] ;@ Save Flags (NZCV)\n");
  ot("  ldmia sp!,{r4,r5,r7,r8,r10,r11,lr}\n");
  ot("  bx lr\n");
  ot("\n");
  ot("\n");

  // --------------
  ot("CycloneSetRealTAS%s\n", ms?"":":");
#if (CYCLONE_FOR_GENESIS == 2)
  ot("  ldr r12,=CycloneJumpTab\n");
  ot("  tst r0,r0\n");
  ot("  add r12,r12,#0x4a00*4\n");
  ot("  add r12,r12,#0x00d0*4\n");
  ot("  beq setrtas_off\n");
  ChangeTAS(1);
  ot("  bx lr\n");
  ot("setrtas_off%s\n",ms?"":":");
  ChangeTAS(0);
  ot("  bx lr\n");
  ltorg();
#else
  ot("  bx lr\n");
#endif
  ot("\n");

  // --------------
  ot(";@ DoInterrupt - r0=IRQ level\n");
  ot("CycloneDoInterruptGoBack%s\n", ms?"":":");
  ot("  sub r4,r4,#2\n");
  ot("CycloneDoInterrupt%s\n", ms?"":":");
  ot("  bic r8,r8,#0xff000000\n");
  ot("  orr r8,r8,r0,lsl #29 ;@ abuse r8\n");

  // Steps are from "M68000 8-/16-/32-BIT MICROPROCESSORS USER'S MANUAL", p. 6-4
  // but their order is based on http://pasti.fxatari.com/68kdocs/68kPrefetch.html
  // 1. Make a temporary copy of the status register and set the status register for exception processing.
  ot("  ldr r2,[r7,#0x58] ;@ state flags\n");
  ot("  and r0,r0,#7\n");
  ot("  orr r3,r0,#0x20 ;@ Supervisor mode + IRQ level\n");
  ot("  bic r2,r2,#3 ;@ clear stopped and trace states\n");
#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO
  ot("  orr r2,r2,#4 ;@ set activity bit: 'not processing instruction'\n");
#endif
  ot("  str r2,[r7,#0x58]\n");
  ot("  ldrb r6,[r7,#0x44] ;@ Get old SR high, abuse r6\n");
  ot("  strb r3,[r7,#0x44] ;@ Put new SR high\n");
  ot("\n");

  // 3. Save the current processor context.
  ot("  ldr r1,[r7,#0x60] ;@ Get Memory base\n");
  ot("  ldr r11,[r7,#0x3c] ;@ Get A7\n");
  ot("  tst r6,#0x20\n");
  ot(";@ get our SP:\n");
  ot("  ldreq r2,[r7,#0x48] ;@ ...or OSP as our stack pointer\n");
  ot("  streq r11,[r7,#0x48]\n");
  ot("  moveq r11,r2\n");
  ot(";@ Push old PC onto stack\n");
  ot("  sub r0,r11,#4 ;@ Predecremented A7\n");
  ot("  sub r1,r4,r1 ;@ r1 = Old PC\n");
  MemHandler(1,2);
  ot(";@ Push old SR:\n");
  ot("  ldr r0,[r7,#0x4c]   ;@ X bit\n");
  ot("  mov r1,r10,lsr #28  ;@ ____NZCV\n");
  ot("  eor r2,r1,r1,ror #1 ;@ Bit 0=C^V\n");
  ot("  tst r2,#1           ;@ 1 if C!=V\n");
  ot("  eorne r1,r1,#3      ;@ ____NZVC\n");
  ot("  and r0,r0,#0x20000000\n");
  ot("  orr r1,r1,r0,lsr #25 ;@ ___XNZVC\n");
  ot("  orr r1,r1,r6,lsl #8 ;@ Include old SR high\n");
  ot("  sub r0,r11,#6 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,1,0,0); // already checked for address error by prev MemHandler
  ot("\n");

  // 2. Obtain the exception vector.
  ot("  mov r11,r8,lsr #29\n");
  ot("  mov r0,r11\n");
#if USE_INT_ACK_CALLBACK
  ot(";@ call IrqCallback if it is defined\n");
#if INT_ACK_NEEDS_STUFF
  ot("  str r4,[r7,#0x40] ;@ Save PC\n");
  ot("  mov r1,r10,lsr #28\n");
  ot("  strb r1,[r7,#0x46] ;@ Save Flags (NZCV)\n");
  ot("  str r5,[r7,#0x5c] ;@ Save Cycles\n");
#endif
  ot("  ldr r3,[r7,#0x8c] ;@ IrqCallback\n");
  ot("  add lr,pc,#4*3\n");
  ot("  tst r3,r3\n");
  ot("  streqb r3,[r7,#0x47] ;@ just clear IRQ if there is no callback\n");
  ot("  mvneq r0,#0 ;@ and simulate -1 return\n");
  ot("  bxne r3\n");
#if INT_ACK_CHANGES_CYCLES
  ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
#endif
  ot(";@ get IRQ vector address:\n");
  ot("  cmn r0,#1 ;@ returned -1?\n");
  ot("  addeq r0,r11,#0x18 ;@ use autovector then\n");
  ot("  cmn r0,#2 ;@ returned -2?\n"); // should be safe as above add should never result in -2
  ot("  moveq r0,#0x18 ;@ use spurious interrupt then\n");
#else // !USE_INT_ACK_CALLBACK
  ot(";@ Clear irq:\n");
  ot("  mov r2,#0\n");
  ot("  strb r2,[r7,#0x47]\n");
  ot("  add r0,r0,#0x18 ;@ use autovector\n");
#endif
  ot("  mov r0,r0,lsl #2 ;@ get vector address\n");
  ot("\n");
  ot("  ldr r11,[r7,#0x60] ;@ Get Memory base\n");
  ot(";@ Read IRQ Vector:\n");
  MemHandler(0,2,0,0);
  ot("  tst r0,r0 ;@ uninitialized int vector?\n");
  ot("  moveq r0,#0x3c\n");
 #ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bleq %sread32 ;@ Call read32(r0) handler\n", MEMHANDLERS_DIRECT_PREFIX);
 #else
  ot("  moveq lr,pc\n");
  ot("  ldreq pc,[r7,#0x70] ;@ Call read32(r0) handler\n");
 #endif
#if USE_CHECKPC_CALLBACK
  ot("  add lr,pc,#4\n");
  ot("  add r0,r0,r11 ;@ r0 = Memory Base + New PC\n");
 #ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bl %scheckpc ;@ Call checkpc()\n", MEMHANDLERS_DIRECT_PREFIX);
 #else
  ot("  ldr pc,[r7,#0x64] ;@ Call checkpc()\n");
 #endif
 #if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  mov r4,r0\n");
 #else
  ot("  bic r4,r0,#1\n");
 #endif
#else
  ot("  add r4,r0,r11 ;@ r4 = Memory Base + New PC\n");
 #if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  bic r4,r4,#1\n");
 #endif
#endif
  ot("\n");

  // 4. Obtain a new context and resume instruction processing.
  // note: the obtain part was already done in previous steps
#if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  tst r4,#1\n");
  ot("  bne ExceptionAddressError_r_prg_r4\n");
#endif
  ot("  ldr r6,[r7,#0x54]\n");
  ot("  ldrh r8,[r4],#2 ;@ Fetch next opcode\n");
  ot("  subs r5,r5,#44 ;@ Subtract cycles\n");
  ot("  ldrgt pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
  ot("  b CycloneEnd\n");
  ot("\n");

  // --------------
  // trashes all temp regs
  ot("Exception%s\n", ms?"":":");
  ot("  ;@ Cause an Exception - Vector number in r0\n");
  ot("  mov r11,lr ;@ Preserve ARM return address\n");
  ot("  bic r8,r8,#0xff000000\n");
  ot("  orr r8,r8,r0,lsl #24 ;@ abuse r8\n");

  // 1. Make a temporary copy of the status register and set the status register for exception processing.
  ot("  ldr r6,[r7,#0x44] ;@ Get old SR high, abuse r6\n");
  ot("  ldr r2,[r7,#0x58] ;@ state flags\n");
  ot("  and r3,r6,#0x27 ;@ clear trace and unused flags\n");
  ot("  orr r3,r3,#0x20 ;@ set supervisor mode\n");
  ot("  bic r2,r2,#3 ;@ clear stopped and trace states\n");
  ot("  str r2,[r7,#0x58]\n");
  ot("  strb r3,[r7,#0x44] ;@ Put new SR high\n");
  ot("\n");

  // 3. Save the current processor context.
  ot("  ldr r0,[r7,#0x3c] ;@ Get A7\n");
  ot("  tst r6,#0x20\n");
  ot(";@ get our SP:\n");
  ot("  ldreq r2,[r7,#0x48] ;@ ...or OSP as our stack pointer\n");
  ot("  streq r0,[r7,#0x48]\n");
  ot("  moveq r0,r2\n");
  ot(";@ Push old PC onto stack\n");
  ot("  ldr r1,[r7,#0x60] ;@ Get Memory base\n");
  ot("  sub r0,r0,#4 ;@ Predecremented A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  ot("  sub r1,r4,r1 ;@ r1 = Old PC\n");
  MemHandler(1,2);
  ot(";@ Push old SR:\n");
  ot("  ldr r0,[r7,#0x4c]   ;@ X bit\n");
  ot("  mov r1,r10,lsr #28  ;@ ____NZCV\n");
  ot("  eor r2,r1,r1,ror #1 ;@ Bit 0=C^V\n");
  ot("  tst r2,#1           ;@ 1 if C!=V\n");
  ot("  eorne r1,r1,#3      ;@ ____NZVC\n");
  ot("  and r0,r0,#0x20000000\n");
  ot("  orr r1,r1,r0,lsr #25 ;@ ___XNZVC\n");
  ot("  ldr r0,[r7,#0x3c] ;@ A7\n");
  ot("  orr r1,r1,r6,lsl #8 ;@ Include SR high\n");
  ot("  sub r0,r0,#2 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,1,0,0);
  ot("\n");

  // 2. Obtain the exception vector
  ot(";@ Read Exception Vector:\n");
  ot("  mov r0,r8,lsr #24\n");
  ot("  mov r0,r0,lsl #2\n");
  MemHandler(0,2,0,0);
  ot("  ldr r3,[r7,#0x60] ;@ Get Memory base\n");
#if USE_CHECKPC_CALLBACK
  ot("  add lr,pc,#4\n");
  ot("  add r0,r0,r3 ;@ r0 = Memory Base + New PC\n");
 #ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bl %scheckpc ;@ Call checkpc()\n", MEMHANDLERS_DIRECT_PREFIX);
 #else
  ot("  ldr pc,[r7,#0x64] ;@ Call checkpc()\n");
 #endif
 #if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  mov r4,r0\n");
 #else
  ot("  bic r4,r0,#1\n");
 #endif
#else
  ot("  add r4,r0,r3 ;@ r4 = Memory Base + New PC\n");
 #if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  bic r4,r4,#1\n");
 #endif
#endif
  ot("\n");

  // 4. Resume execution.
#if EMULATE_ADDRESS_ERRORS_JUMP
  ot("  tst r4,#1\n");
  ot("  bne ExceptionAddressError_r_prg_r4\n");
#endif
  ot("  ldr r6,[r7,#0x54]\n");
  ot("  bx r11 ;@ Return\n");
  ot("\n");

  // --------------
#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO
  // first some wrappers: I see no point inlining this code,
  // as it will be executed in really rare cases.
  AddressErrorWrapper('r', "data", 0x11);
  AddressErrorWrapper('r', "prg",  0x12);
  AddressErrorWrapper('w', "data", 0x01);
  // there are no program writes
  // cpu space is only for bus errors?
  ot("ExceptionAddressError_r_prg_r4%s\n", ms?"":":");
  ot("  ldr r1,[r7,#0x44]\n");
  ot("  ldr r3,[r7,#0x60] ;@ Get Memory base\n");
  ot("  mov r6,#0x12\n");
  ot("  sub r11,r4,r3\n");
  ot("  tst r1,#0x20\n");
  ot("  orrne r6,r6,#4\n");
  ot("\n");

  ot("ExceptionAddressError%s\n", ms?"":":");
  ot(";@ r6 - info word (without instruction/not bit), r11 - faulting address\n");

  // 1. Make a temporary copy of the status register and set the status register for exception processing.
  ot("  ldrb r0,[r7,#0x44] ;@ Get old SR high\n");
  ot("  ldr r2,[r7,#0x58] ;@ state flags\n");
  ot("  and r3,r0,#0x27 ;@ clear trace and unused flags\n");
  ot("  orr r3,r3,#0x20 ;@ set supervisor mode\n");
  ot("  strb r3,[r7,#0x44] ;@ Put new SR high\n");
  ot("  bic r2,r2,#3 ;@ clear stopped and trace states\n");
  ot("  tst r2,#4\n");
  ot("  orrne r6,r6,#8 ;@ complete info word\n");
  ot("  orr r2,r2,#4 ;@ set activity bit: 'not processing instruction'\n");
#if EMULATE_HALT
  ot("  tst r2,#8\n");
  ot("  orrne r2,r2,#0x10 ;@ HALT\n");
  ot("  orr r2,r2,#8 ;@ processing address error\n");
  ot("  str r2,[r7,#0x58]\n");
  ot("  movne r5,#0\n");
  ot("  bne CycloneEndNoBack ;@ bye bye\n");
#else
  ot("  str r2,[r7,#0x58]\n");
#endif
  ot("  and r10,r10,#0xf0000000\n");
  ot("  orr r10,r10,r0,lsl #4 ;@ some preparations for SR push\n");
  ot("\n");

  // 3. Save the current processor context + additional information.
  ot("  ldr r0,[r7,#0x3c] ;@ Get A7\n");
  ot("  tst r10,#0x200\n");
  ot(";@ get our SP:\n");
  ot("  ldreq r2,[r7,#0x48] ;@ ...or OSP as our stack pointer\n");
  ot("  streq r0,[r7,#0x48]\n");
  ot("  moveq r0,r2\n");
  // PC
  ot(";@ Push old PC onto stack\n");
  ot("  ldr r1,[r7,#0x60] ;@ Get Memory base\n");
  ot("  sub r0,r0,#4 ;@ Predecremented A7\n");
  ot("  sub r1,r4,r1 ;@ r1 = Old PC\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,2,0,EMULATE_HALT);
  // SR
  ot(";@ Push old SR:\n");
  ot("  ldr r0,[r7,#0x4c]   ;@ X bit\n");
  ot("  mov r1,r10,ror #28  ;@ ____NZCV\n");
  ot("  eor r2,r1,r1,ror #1 ;@ Bit 0=C^V\n");
  ot("  tst r2,#1           ;@ 1 if C!=V\n");
  ot("  eorne r1,r1,#3      ;@ ____NZVC\n");
  ot("  and r0,r0,#0x20000000\n");
  ot("  orr r1,r1,r0,lsr #25 ;@ ___XNZVC\n");
  ot("  ldr r0,[r7,#0x3c] ;@ A7\n");
  ot("  and r10,r10,#0xf0000000\n");
  ot("  sub r0,r0,#2 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,1,0,0);
  // IR (instruction register)
  ot(";@ Push IR:\n");
  ot("  ldr r0,[r7,#0x3c] ;@ A7\n");
  ot("  mov r1,r8\n");
  ot("  sub r0,r0,#2 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,1,0,0);
  // access address
  ot(";@ Push address:\n");
  ot("  ldr r0,[r7,#0x3c] ;@ A7\n");
  ot("  mov r1,r11\n");
  ot("  sub r0,r0,#4 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,2,0,0);
  // information word
  ot(";@ Push info word:\n");
  ot("  ldr r0,[r7,#0x3c] ;@ A7\n");
  ot("  mov r1,r6\n");
  ot("  sub r0,r0,#2 ;@ Predecrement A7\n");
  ot("  str r0,[r7,#0x3c] ;@ Save A7\n");
  MemHandler(1,1,0,0);
  ot("\n");

  // 2. Obtain the exception vector
  ot(";@ Read Exception Vector:\n");
  ot("  mov r0,#0x0c\n");
  MemHandler(0,2,0,0);
  ot("  ldr r3,[r7,#0x60] ;@ Get Memory base\n");
#if USE_CHECKPC_CALLBACK
  ot("  add lr,pc,#4\n");
  ot("  add r0,r0,r3 ;@ r0 = Memory Base + New PC\n");
 #ifdef MEMHANDLERS_DIRECT_PREFIX
  ot("  bl %scheckpc ;@ Call checkpc()\n", MEMHANDLERS_DIRECT_PREFIX);
 #else
  ot("  ldr pc,[r7,#0x64] ;@ Call checkpc()\n");
 #endif
  ot("  mov r4,r0\n");
#else
  ot("  add r4,r0,r3 ;@ r4 = Memory Base + New PC\n");
#endif
  ot("\n");

#if EMULATE_ADDRESS_ERRORS_JUMP && EMULATE_HALT
  ot("  tst r4,#1\n");
  ot("  bne ExceptionAddressError_r_prg_r4\n");
#else
  ot("  bic r4,r4,#1\n");
#endif

  // 4. Resume execution.
  ot("  ldr r6,[r7,#0x54]\n");
  ot("  ldrh r8,[r4],#2 ;@ Fetch next opcode\n");
  ot("  subs r5,r5,#50 ;@ Subtract cycles\n");
  ot("  ldrgt pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
  ot("  b CycloneEnd\n");
  ot("\n");
#endif

  // --------------
#if EMULATE_TRACE
  // expects srh and irq level in r1, next opcode already fetched to r8
  ot("CycloneDoTraceWithChecks%s\n", ms?"":":");
  ot("  ldr r0,[r7,#0x58]\n");
  ot("  cmp r5,#0\n");
  ot("  orr r0,r0,#2 ;@ go to trace mode\n");
  ot("  str r0,[r7,#0x58]\n");
  ot("  ble CycloneEnd\n"); // should take care of situation where we come here when already tracing
  ot(";@ CheckInterrupt:\n");
  ot("  movs r0,r1,lsr #24 ;@ Get IRQ level\n");
  ot("  beq CycloneDoTrace\n");
  ot("  cmp r0,#6 ;@ irq>6 ?\n");
  ot("  andle r1,r1,#7 ;@ Get interrupt mask\n");
  ot("  cmple r0,r1 ;@ irq<=6: Is irq<=mask ?\n");
  ot("  bgt CycloneDoInterruptGoBack\n");
  ot("\n");

  // expects next opcode to be already fetched to r8
  ot("CycloneDoTrace%s\n", ms?"":":");
  ot("  str r5,[r7,#0x9c] ;@ save cycles\n");
  ot("  ldr r1,[r7,#0x98]\n");
  ot("  mov r5,#0\n");
  ot("  str r1,[r7,#0xa0]\n");
  ot("  adr r0,TraceEnd\n");
  ot("  str r0,[r7,#0x98] ;@ store TraceEnd as CycloneEnd hadler\n");
  ot("  ldr pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
  ot("\n");

  ot("TraceEnd%s\n", ms?"":":");
  ot("  ldr r2,[r7,#0x58]\n");
  ot("  ldr r0,[r7,#0x9c] ;@ restore cycles\n");
  ot("  ldr r1,[r7,#0xa0] ;@ old CycloneEnd handler\n");
  ot("  mov r10,r10,lsl #28\n");
  ot("  add r5,r0,r5\n");
  ot("  str r1,[r7,#0x98]\n");
  ot(";@ still tracing?\n"); // exception might have happend
  ot("  tst r2,#2\n");
  ot("  beq TraceDisabled\n");
  ot(";@ trace exception\n");
#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO
  ot("  ldr r1,[r7,#0x58]\n");
  ot("  mov r0,#9\n");
  ot("  orr r1,r1,#4 ;@ set activity bit: 'not processing instruction'\n");
  ot("  str r1,[r7,#0x58]\n");
#else
  ot("  mov r0,#9\n");
#endif
  ot("  bl Exception\n");
  ot("  ldrh r8,[r4],#2 ;@ Fetch next opcode\n");
  ot("  subs r5,r5,#34 ;@ Subtract cycles\n");
  ot("  ldrgt pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
  ot("  b CycloneEnd\n");
  ot("\n");
  ot("TraceDisabled%s\n", ms?"":":");
  ot("  ldrh r8,[r4],#2 ;@ Fetch next opcode\n");
  ot("  cmp r5,#0\n");
  ot("  ldrgt pc,[r6,r8,asl #2] ;@ Jump to opcode handler\n");
  ot("  b CycloneEnd\n");
  ot("\n");
#endif
}

// ---------------------------------------------------------------------------
// Call Read(r0), Write(r0,r1) or Fetch(r0)
// Trashes r0-r3,r12,lr
int MemHandler(int type,int size,int addrreg,int need_addrerr_check)
{
  int func=0x68+type*0xc+(size<<2); // Find correct offset
  char what[32];

#if MEMHANDLERS_NEED_FLAGS
  ot("  mov r3,r10,lsr #28\n");
  ot("  strb r3,[r7,#0x46] ;@ Save Flags (NZCV)\n");
#endif
  FlushPC();

#if (MEMHANDLERS_ADDR_MASK & 0xff000000)
  ot("  bic r0,r%i,#0x%08x\n", addrreg, MEMHANDLERS_ADDR_MASK & 0xff000000);
  addrreg=0;
#endif
#if (MEMHANDLERS_ADDR_MASK & 0x00ff0000)
  ot("  bic r0,r%i,#0x%08x\n", addrreg, MEMHANDLERS_ADDR_MASK & 0x00ff0000);
  addrreg=0;
#endif
#if (MEMHANDLERS_ADDR_MASK & 0x0000ff00)
  ot("  bic r0,r%i,#0x%08x\n", addrreg, MEMHANDLERS_ADDR_MASK & 0x0000ff00);
  addrreg=0;
#endif
#if (MEMHANDLERS_ADDR_MASK & 0x000000ff)
  ot("  bic r0,r%i,#0x%08x\n", addrreg, MEMHANDLERS_ADDR_MASK & 0x000000ff);
  addrreg=0;
#endif

#if EMULATE_ADDRESS_ERRORS_IO
  if (size > 0 && need_addrerr_check)
  {
    ot("  add lr,pc,#4*%i\n", addrreg==0?2:3); // helps to prevent interlocks
    if (addrreg != 0) ot("  mov r0,r%i\n", addrreg);
    ot("  tst r0,#1 ;@ address error?\n");
    switch (type) {
      case 0: ot("  bne ExceptionAddressError_r_data\n"); break;
      case 1: ot("  bne ExceptionAddressError_w_data\n"); break;
      case 2: ot("  bne ExceptionAddressError_r_prg\n"); break;
    }
  }
  else
#endif

  sprintf(what, "%s%d", type==0 ? "read" : (type==1 ? "write" : "fetch"), 8<<size);
#ifdef MEMHANDLERS_DIRECT_PREFIX
  if (addrreg != 0)
    ot("  mov r0,r%i\n", addrreg);
  ot("  bl %s%s ;@ Call ", MEMHANDLERS_DIRECT_PREFIX, what);
  (void)func; // avoid warning
#else
  if (addrreg != 0)
  {
    ot("  add lr,pc,#4\n");
    ot("  mov r0,r%i\n", addrreg);
  }
  else
    ot("  mov lr,pc\n");
  ot("  ldr pc,[r7,#0x%x] ;@ Call ",func);
#endif

  // Document what we are calling:
  if (type==1) ot("%s(r0,r1)",what);
  else         ot("%s(r0)",   what);
  ot(" handler\n");

#if MEMHANDLERS_CHANGE_FLAGS
  ot("  ldrb r10,[r7,#0x46] ;@ r10 = Load Flags (NZCV)\n");
  ot("  mov r10,r10,lsl #28\n");
#endif
#if MEMHANDLERS_CHANGE_PC
  ot("  ldr r4,[r7,#0x40] ;@ Load PC\n");
#endif

  return 0;
}

static void PrintOpcodes()
{
  int op=0;

  printf("Creating Opcodes: [");

  ot(";@ ---------------------------- Opcodes ---------------------------\n");

  // Emit null opcode:
  ot("Op____%s ;@ Called if an opcode is not recognised\n", ms?"":":");
#if EMULATE_ADDRESS_ERRORS_JUMP || EMULATE_ADDRESS_ERRORS_IO
  ot("  ldr r1,[r7,#0x58]\n");
  ot("  sub r4,r4,#2\n");
  ot("  orr r1,r1,#4 ;@ set activity bit: 'not processing instruction'\n");
  ot("  str r1,[r7,#0x58]\n");
#else
  ot("  sub r4,r4,#2\n");
#endif
#if USE_UNRECOGNIZED_CALLBACK
  ot("  str r4,[r7,#0x40] ;@ Save PC\n");
  ot("  mov r1,r10,lsr #28\n");
  ot("  strb r1,[r7,#0x46] ;@ Save Flags (NZCV)\n");
  ot("  str r5,[r7,#0x5c] ;@ Save Cycles\n");
  ot("  ldr r11,[r7,#0x94] ;@ UnrecognizedCallback\n");
  ot("  tst r11,r11\n");
  ot("  movne lr,pc\n");
  ot("  movne pc,r11 ;@ call UnrecognizedCallback if it is defined\n");
  ot("  ldrb r10,[r7,#0x46] ;@ r10 = Load Flags (NZCV)\n");
  ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
  ot("  ldr r4,[r7,#0x40] ;@ Load PC\n");
  ot("  mov r10,r10,lsl #28\n");
  ot("  tst r0,r0\n");
  ot("  moveq r0,#4\n");
  ot("  bleq Exception\n");
#else
  ot("  mov r0,#4\n");
  ot("  bl Exception\n");
#endif
  ot("\n");
  Cycles=34;
  OpEnd();

  // Unrecognised a-line and f-line opcodes throw an exception:
  ot("Op__al%s ;@ Unrecognised a-line opcode\n", ms?"":":");
  ot("  sub r4,r4,#2\n");
#if USE_AFLINE_CALLBACK
  ot("  str r4,[r7,#0x40] ;@ Save PC\n");
  ot("  mov r1,r10,lsr #28\n");
  ot("  strb r1,[r7,#0x46] ;@ Save Flags (NZCV)\n");
  ot("  str r5,[r7,#0x5c] ;@ Save Cycles\n");
  ot("  ldr r11,[r7,#0x94] ;@ UnrecognizedCallback\n");
  ot("  tst r11,r11\n");
  ot("  movne lr,pc\n");
  ot("  movne pc,r11 ;@ call UnrecognizedCallback if it is defined\n");
  ot("  ldrb r10,[r7,#0x46] ;@ r10 = Load Flags (NZCV)\n");
  ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
  ot("  ldr r4,[r7,#0x40] ;@ Load PC\n");
  ot("  mov r10,r10,lsl #28\n");
  ot("  tst r0,r0\n");
  ot("  moveq r0,#0x0a\n");
  ot("  bleq Exception\n");
#else
  ot("  mov r0,#0x0a\n");
  ot("  bl Exception\n");
#endif
  ot("\n");
  Cycles=4;
  OpEnd();

  ot("Op__fl%s ;@ Unrecognised f-line opcode\n", ms?"":":");
  ot("  sub r4,r4,#2\n");
#if USE_AFLINE_CALLBACK
  ot("  str r4,[r7,#0x40] ;@ Save PC\n");
  ot("  mov r1,r10,lsr #28\n");
  ot("  strb r1,[r7,#0x46] ;@ Save Flags (NZCV)\n");
  ot("  str r5,[r7,#0x5c] ;@ Save Cycles\n");
  ot("  ldr r11,[r7,#0x94] ;@ UnrecognizedCallback\n");
  ot("  tst r11,r11\n");
  ot("  movne lr,pc\n");
  ot("  movne pc,r11 ;@ call UnrecognizedCallback if it is defined\n");
  ot("  ldrb r10,[r7,#0x46] ;@ r10 = Load Flags (NZCV)\n");
  ot("  ldr r5,[r7,#0x5c] ;@ Load Cycles\n");
  ot("  ldr r4,[r7,#0x40] ;@ Load PC\n");
  ot("  mov r10,r10,lsl #28\n");
  ot("  tst r0,r0\n");
  ot("  moveq r0,#0x0b\n");
  ot("  bleq Exception\n");
#else
  ot("  mov r0,#0x0b\n");
  ot("  bl Exception\n");
#endif
  ot("\n");
  Cycles=4;
  OpEnd();


  for (op=0;op<hot_opcode_count;op++)
    OpAny(hot_opcodes[op]);

  for (op=0;op<0x10000;op++)
  {
    if ((op&0xfff)==0) { printf("%x",op>>12); fflush(stdout); } // Update progress

    if (!is_op_hot(op))
      OpAny(op);
  }

  ot("\n");

  printf("]\n");
}

// helper
static void ott(const char *str, int par, const char *nl, int nlp, int counter, int size)
{
  switch(size) {
    case 0: if((counter&7)==0) ot(ms?"  dcb ":"  .byte ");  break;
    case 1: if((counter&7)==0) ot(ms?"  dcw ":"  .hword "); break;
    case 2: if((counter&7)==0) ot(ms?"  dcd ":"  .long ");  break;
  }
  ot(str, par);
  if((counter&7)==7) ot(nl,nlp); else ot(",");
}

static void PrintJumpTable()
{
  int i=0,op=0,len=0;

  ot(";@ -------------------------- Jump Table --------------------------\n");

  // space for decompressed table
  ot(ms?"  area |.data|, data\n":"  .data\n  .align 4\n\n");

#if COMPRESS_JUMPTABLE
    int handlers=0,reps=0,*indexes,ip,u,out;
    // use some weird compression on the jump table
    indexes=(int *)malloc(0x10000*4);
    if(!indexes) { printf("ERROR: out of memory\n"); exit(1); }
    len=0x10000;

    ot("CycloneJumpTab%s\n", ms?"":":");
    if(ms) {
      for(i = 0; i < 0xa000/8; i++)
        ot("  dcd 0,0,0,0,0,0,0,0\n");
    } else
      ot("  .rept 0x%x\n  .long 0,0,0,0,0,0,0,0\n  .endr\n", 0xa000/8);

    // hanlers live in "a-line" part of the table
    // first output nop,a-line,f-line handlers
    ot(ms?"  dcd Op____,Op__al,Op__fl,":"  .long Op____,Op__al,Op__fl,");
    handlers=3;

    for(i=0;i<len;i++)
    {
      op=CyJump[i];

      for(u=i-1; u>=0; u--) if(op == CyJump[u]) break; // already done with this op?
      if(u==-1 && op >= 0) {
        ott("Op%.4x",op," ;@ %.4x\n",i,handlers,2);
        indexes[op] = handlers;
        handlers++;
      }
    }
    if(handlers&7) {
      fseek(AsmFile, -1, SEEK_CUR); // remove last comma
      for(i = 8-(handlers&7); i > 0; i--)
        ot(",000000");
      ot("\n");
    }
    if(ms) {
      for(i = (0x4000-handlers)/8; i > 0; i--)
        ot("  dcd 0,0,0,0,0,0,0,0\n");
    } else {
      ot(ms?"":"  .rept 0x%x\n  .long 0,0,0,0,0,0,0,0\n  .endr\n", (0x4000-handlers)/8);
    }
    printf("total distinct hanlers: %i\n",handlers);
    // output data
    for(i=0,ip=0; i < 0xf000; i++, ip++) {
      op=CyJump[i];
      if(op == -2) {
        // it must skip a-line area, because we keep our data there
        ott("0x%.4x", handlers<<4, "\n",0,ip++,1);
        ott("0x%.4x", 0x1000, "\n",0,ip,1);
        i+=0xfff;
        continue;
      }
      for(reps=1; i < 0xf000; i++, reps++) if(op != CyJump[i+1]) break;
      if(op>=0) out=indexes[op]<<4; else out=0; // unrecognised
      if(reps <= 0xe || reps==0x10) {
        if(reps!=0x10) out|=reps; else out|=0xf; // 0xf means 0x10 (0xf appeared to be unused anyway)
        ott("0x%.4x", out, "\n",0,ip,1);
      } else {
        ott("0x%.4x", out, "\n",0,ip++,1);
        ott("0x%.4x", reps,"\n",0,ip,1);
      }
    }
    if(ip&1) ott("0x%.4x", 0, "\n",0,ip++,1);
    if(ip&7) fseek(AsmFile, -1, SEEK_CUR); // remove last comma
    if(ip&7) {
      for(i = 8-(ip&7); i > 0; i--)
        ot(",0x0000");
    }
    ot("\n");
    if(ms) {
      for(i = (0x2000-ip/2)/8+1; i > 0; i--)
        ot("  dcd 0,0,0,0,0,0,0,0\n");
    } else {
      ot("  .rept 0x%x\n  .long 0,0,0,0,0,0,0,0\n  .endr\n", (0x2000-ip/2)/8+1);
    }
    ot("\n");
    free(indexes);
#else
    ot("CycloneJumpTab%s\n", ms?"":":");
    len=0xfffe; // Hmmm, armasm 2.50.8684 messes up with a 0x10000 long jump table
                // notaz: same thing with GNU as 2.9-psion-98r2 (reloc overflow)
                // this is due to COFF objects using only 2 bytes for reloc count

    for (i=0;i<len;i++)
    {
      op=CyJump[i];

           if(op>=0)  ott("Op%.4x",op," ;@ %.4x\n",i-7,i,2);
      else if(op==-2) ott("Op__al",0, " ;@ %.4x\n",i-7,i,2);
      else if(op==-3) ott("Op__fl",0, " ;@ %.4x\n",i-7,i,2);
      else            ott("Op____",0, " ;@ %.4x\n",i-7,i,2);
    }
    if(i&7) fseek(AsmFile, -1, SEEK_CUR); // remove last comma

    ot("\n");
    ot(";@ notaz: we don't want to crash if we run into those 2 missing opcodes\n");
    ot(";@ so we leave this pattern to patch it later\n");
    ot("%s 0x78563412\n", ms?"  dcd":"  .long");
    ot("%s 0x56341290\n", ms?"  dcd":"  .long");
#endif
}

static int CycloneMake()
{
  int i;
  const char *name="Cyclone.s";
  const char *globl=ms?"export":".global";

  // Open the assembly file
  if (ms) name="Cyclone.asm";
  AsmFile=fopen(name,"wt"); if (AsmFile==NULL) return 1;

  printf("Making %s...\n",name);

  ot("\n;@ Cyclone 68000 Emulator v%x.%.3x - Assembler Output\n\n",CycloneVer>>12,CycloneVer&0xfff);

  ot(";@ Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)\n");
  ot(";@ Copyright (c) 2005-2011 Gražvydas \"notaz\" Ignotas (notasas (at) gmail.com)\n\n");

  ot(";@ This code is licensed under the GNU General Public License version 2.0 and the MAME License.\n");
  ot(";@ You can choose the license that has the most advantages for you.\n\n");
  ot(";@ SVN repository can be found at http://code.google.com/p/cyclone68000/\n\n");

  CyJump=(int *)malloc(0x40000); if (CyJump==NULL) return 1;
  memset(CyJump,0xff,0x40000); // Init to -1
  for(i=0xa000; i<0xb000;  i++) CyJump[i] = -2; // a-line emulation
  for(i=0xf000; i<0x10000; i++) CyJump[i] = -3; // f-line emulation

  ot(ms?"  area |.text|, code\n":"  .text\n  .align 4\n\n");
  ot("  %s CycloneInit\n",globl);
  ot("  %s CycloneReset\n",globl);
  ot("  %s CycloneRun\n",globl);
  ot("  %s CycloneSetSr\n",globl);
  ot("  %s CycloneGetSr\n",globl);
  ot("  %s CycloneFlushIrq\n",globl);
  ot("  %s CyclonePack\n",globl);
  ot("  %s CycloneUnpack\n",globl);
  ot("  %s CycloneVer\n",globl);
#if (CYCLONE_FOR_GENESIS == 2)
  ot("  %s CycloneSetRealTAS\n",globl);
  ot("  %s CycloneDoInterrupt\n",globl);
  ot("  %s CycloneDoTrace\n",globl);
  ot("  %s CycloneJumpTab\n",globl);
  ot("  %s Op____\n",globl);
  ot("  %s Op6002\n",globl);
  ot("  %s Op6602\n",globl);
  ot("  %s Op6702\n",globl);
#endif
  ot("\n");
  ot(ms?"CycloneVer dcd 0x":"CycloneVer: .long 0x");
  ot("%.4x\n",CycloneVer);
  ot("\n");

  PrintFramework();
  arm_op_count = 0;
  PrintOpcodes();
  printf("~%i ARM instructions used for opcode handlers\n", arm_op_count);
  PrintJumpTable();

  if (ms) ot("  END\n");

  ot("\n\n;@ vim:filetype=armasm\n");

  fclose(AsmFile); AsmFile=NULL;

#if 0
  printf("Assembling...\n");
  // Assemble the file
  if (ms) system("armasm Cyclone.asm");
  else    system("as -o Cyclone.o Cyclone.s");
  printf("Done!\n\n");
#endif

  free(CyJump);
  return 0;
}

int main()
{
  printf("\n  Cyclone 68000 Emulator v%x.%.3x - Core Creator\n\n",CycloneVer>>12,CycloneVer&0xfff);

  // Make GAS or ARMASM version
  CycloneMake();
  return 0;
}

