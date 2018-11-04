/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Yabause - sh2_dynarec.c                                               *
 *   Copyright (C) 2009-2011 Ari64                                         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h> //include for uint64_t
#include <assert.h>
#include <string.h> //include for memset

#include <sys/mman.h>

#include "../memory.h"
#include "../sh2core.h"
#include "../yabause.h"
#include "sh2_dynarec.h"

#ifdef __i386__
#include "assem_x86.h"
#endif
#ifdef __x86_64__
#include "assem_x64.h"
#endif
#ifdef __arm__
#include "assem_arm.h"
#endif

#define MAXBLOCK 4096
#define MAX_OUTPUT_BLOCK_SIZE 262144
#define CLOCK_DIVIDER 1
#define SH2_REGS 23

struct regstat
{
  signed char regmap_entry[HOST_REGS];
  signed char regmap[HOST_REGS];
  u32 wasdirty;
  u32 dirty;
  u64 u;
  u32 wasdoingcp;
  u32 isdoingcp;
  u32 cpmap[HOST_REGS];
  u32 isconst;
  u32 constmap[SH2_REGS];
};

struct ll_entry
{
  u32 vaddr;
  u32 reg32;
  void *addr;
  struct ll_entry *next;
};

  u32 start;
  u16 *source;
  void *alignedsource;
  u32 pagelimit;
  char insn[MAXBLOCK][10];
  unsigned char itype[MAXBLOCK];
  unsigned char opcode[MAXBLOCK];
  unsigned char opcode2[MAXBLOCK];
  unsigned char opcode3[MAXBLOCK];
  unsigned char addrmode[MAXBLOCK];
  unsigned char bt[MAXBLOCK];
  signed char rs1[MAXBLOCK];
  signed char rs2[MAXBLOCK];
  signed char rs3[MAXBLOCK];
  signed char rt1[MAXBLOCK];
  signed char rt2[MAXBLOCK];
  unsigned char us1[MAXBLOCK];
  unsigned char us2[MAXBLOCK];
  unsigned char dep1[MAXBLOCK];
  unsigned char dep2[MAXBLOCK];
  signed char lt1[MAXBLOCK];
  int imm[MAXBLOCK];
  u32 ba[MAXBLOCK];
  char is_ds[MAXBLOCK];
  char ooo[MAXBLOCK];
  u64 unneeded_reg[MAXBLOCK];
  u64 branch_unneeded_reg[MAXBLOCK];
  signed char regmap_pre[MAXBLOCK][HOST_REGS];
  u32 cpmap[MAXBLOCK][HOST_REGS];
  struct regstat regs[MAXBLOCK];
  struct regstat branch_regs[MAXBLOCK];
  signed char minimum_free_regs[MAXBLOCK];
  u32 needed_reg[MAXBLOCK];
  u32 wont_dirty[MAXBLOCK];
  u32 will_dirty[MAXBLOCK];
  int cycles[MAXBLOCK];
  int ccadj[MAXBLOCK];
  int slen;
  pointer instr_addr[MAXBLOCK];
  u32 link_addr[MAXBLOCK][3];
  int linkcount;
  u32 stubs[MAXBLOCK*3][8];
  int stubcount;
  pointer ccstub_return[MAXBLOCK];
  u32 literals[1024][2];
  int literalcount;
  int is_delayslot;
  u8 *out;
  struct ll_entry *jump_in[2048];
  struct ll_entry *jump_out[2048];
  struct ll_entry *jump_dirty[2048];
  ALIGNED(16) u32 hash_table[65536][4];
  ALIGNED(16) char shadow[2097152];
  char *copy;
  int expirep;
  unsigned int stop_after_jal;
  //char invalid_code[0x100000];
  char cached_code[0x20000];
  char cached_code_words[2048*128];
  u32 recent_writes[8];
  u32 recent_write_index=0;
  unsigned int slave;
  u32 invalidate_count;
  extern int master_reg[22];
  extern int master_cc;
  extern int master_pc; // Virtual PC
  extern void * master_ip; // Translated PC
  extern int slave_reg[22];
  extern int slave_cc;
  extern int slave_pc; // Virtual PC
  extern void * slave_ip; // Translated PC
  extern u8 restore_candidate[512];

  /* registers that may be allocated */
  /* 0-15 gpr */
#define SR   16 // Status register, including T bit
#define GBR  17 // Global base register
#define VBR  18 // Vector base register
#define MACH 19 // MACH
#define MACL 20 // MACL
#define PR   21 // Return address
#define TBIT 22 // T bit, seperate from SR

#define CCREG 23 // Cycle count
#define MMREG 24 // Pointer to memory_map
#define TEMPREG 25
#define PTEMP 25 // Prefetch temporary register
#define MOREG 26 // offset from memory_map
#define RHASH 27 // Return address hash
#define RHTBL 28 // Return address hash table address
#define RTEMP 29 // BRAF/BSRF address register
#define MAXREG 29
#define AGEN1 30 // Address generation temporary register
#define AGEN2 31 // Address generation temporary register
#define MGEN1 32 // Maptable address generation temporary register
#define MGEN2 33 // Maptable address generation temporary register

  /* instruction types */
#define NOP 0     // No operation
#define LOAD 1    // Load
#define STORE 2   // Store
#define RMW 3     // Read-Modify-Write
#define PCREL 4   // PC-relative Load
#define MOV 5     // Move 
#define ALU 6     // Arithmetic/logic
#define MULTDIV 7 // Multiply/divide
#define SHIFTIMM 8// Shift by immediate
#define IMM8 9    // 8-bit immediate
#define EXT 10    // Sign/Zero Extension
#define FLAGS 11  // SETT/CLRT/MOVT
#define UJUMP 12  // Unconditional jump
#define RJUMP 13  // Unconditional jump to register
#define CJUMP 14  // Conditional branch (BT/BF)
#define SJUMP 15  // Conditional branch with delay slot
#define COMPLEX 16// Complex instructions (function call)
#define SYSTEM 17 // Halt/Trap/Exception
#define SYSCALL 18// SYSCALL (TRAPA)
#define NI 19     // Not implemented
#define DATA 20   // Constant pool data not decoded as instructions
#define BIOS 21   // Emulate BIOS function

  /* addressing modes */
#define REGIND 1  // @Rn
#define POSTINC 2 // @Rn+
#define PREDEC 3  // @-Rm
#define DUALIND 4 // @(R0,Rn)
#define GBRIND 5  // @(R0,GBR)
#define GBRDISP 6 // @(disp,GBR)
#define REGDISP 7 // @(disp,Rn)

  /* stubs */
#define CC_STUB 1
#define FP_STUB 2
#define LOADB_STUB 3
#define LOADW_STUB 4
#define LOADL_STUB 5
#define LOADS_STUB 6
#define STOREB_STUB 7
#define STOREW_STUB 8
#define STOREL_STUB 9
#define RMWT_STUB 10
#define RMWA_STUB 11
#define RMWX_STUB 12
#define RMWO_STUB 13

  /* branch codes */
#define TAKEN 1
#define NOTTAKEN 2
#define NODS 3

// asm linkage
int sh2_recompile_block(int addr);
void *get_addr_ht(u32 vaddr);
void get_bounds(pointer addr,u32 *start,u32 *end);
void invalidate_addr(u32 addr);
void remove_hash(int vaddr);
void dyna_linker();
void verify_code();
void cc_interrupt();
void cc_interrupt_master();
void slave_entry();
void div1();
void macl();
void macw();
void master_handle_bios();
void slave_handle_bios();

// Needed by assembler
void wb_register(signed char r,signed char regmap[],u32 dirty);
void wb_dirtys(signed char i_regmap[],u32 i_dirty);
void wb_needed_dirtys(signed char i_regmap[],u32 i_dirty,int addr);
void load_regs(signed char entry[],signed char regmap[],int rs1,int rs2,int rs3);
void load_all_regs(signed char i_regmap[]);
void load_needed_regs(signed char i_regmap[],signed char next_regmap[]);
void load_regs_entry(int t);
void load_all_consts(signed char regmap[],u32 dirty,int i);

int tracedebug=0;

//#define DEBUG_CYCLE_COUNT 1

void nullf(const char *format, ...) {}
//#define assem_debug printf
//#define inv_debug printf
#define assem_debug nullf
#define inv_debug nullf


// Get address from virtual address
// This is called from the recompiled BRAF/BSRF instructions
void *get_addr(u32 vaddr)
{
  struct ll_entry *head;
  u32 page=(vaddr&0xDFFFFFFF)>>12;
  if(page>1024) page=1024+(page&1023);
  //printf("TRACE: count=%d next=%d (get_addr %x,page %d)\n",Count,next_interupt,vaddr,page);
  head=jump_in[page];
  while(head!=NULL) {
  //printf("TRACE: (get_addr check %x: %x)\n",vaddr,(int)head->addr);
    if(head->vaddr==vaddr) {
  //printf("TRACE: count=%d next=%d (get_addr match %x: %x)\n",Count,next_interupt,vaddr,(int)head->addr);
  //printf("TRACE: (get_addr match %x: %x)\n",vaddr,(int)head->addr);
      int *ht_bin=hash_table[((vaddr>>16)^vaddr)&0xFFFF];
      ht_bin[3]=ht_bin[1];
      ht_bin[2]=ht_bin[0];
      ht_bin[1]=(int)head->addr;
      ht_bin[0]=vaddr;
      //printf("TRACE: get_addr clean (%x,%x)\n",vaddr,(int)head->addr);
      return head->addr;
    }
    head=head->next;
  }
  head=jump_dirty[page];
  while(head!=NULL) {
    if(head->vaddr==vaddr) {
      //printf("TRACE: count=%d next=%d (get_addr match dirty %x: %x)\n",Count,next_interupt,vaddr,(int)head->addr);
      // Don't restore blocks which are about to expire from the cache
      if((((u32)head->addr-(u32)out)<<(32-TARGET_SIZE_2))>0x60000000+(MAX_OUTPUT_BLOCK_SIZE<<(32-TARGET_SIZE_2)))
      if(verify_dirty(head->addr)) {
        u32 start,end;
        int *ht_bin;
        //printf("restore candidate: %x (%d) d=%d\n",vaddr,page,(cached_code[vaddr>>15]>>((vaddr>>12)&7))&1);
        //invalid_code[vaddr>>12]=0;
        cached_code[vaddr>>15]|=1<<((vaddr>>12)&7);
        cached_code[(vaddr^0x20000000)>>15]|=1<<((vaddr>>12)&7);
        #ifdef POINTERS_64BIT
        memory_map[vaddr>>12]|=0x4000000000000000LL;
        memory_map[(vaddr^0x20000000)>>12]|=0x4000000000000000LL;
        #else
        memory_map[vaddr>>12]|=0x40000000;
        memory_map[(vaddr^0x20000000)>>12]|=0x40000000;
        #endif
        restore_candidate[page>>3]|=1<<(page&7);
        get_bounds((pointer)head->addr,&start,&end);
        if(start-(u32)HighWram<0x100000) {
          u32 vstart=start-(u32)HighWram+0x6000000;
          u32 vend=end-(u32)HighWram+0x6000000;
          int i;
          //printf("write protect: start=%x, end=%x\n",vstart,vend);
          for(i=0;i<vend-vstart;i+=4) {
            cached_code_words[((vstart<4194304?vstart:((vstart|0x400000)&0x7fffff))+i)>>5]|=1<<(((vstart+i)>>2)&7);
          }
        }
        if(start-(u32)LowWram<0x100000) {
          u32 vstart=start-(u32)LowWram+0x200000;
          u32 vend=end-(u32)LowWram+0x200000;
          int i;
          //printf("write protect: start=%x, end=%x\n",vstart,vend);
          for(i=0;i<vend-vstart;i+=4) {
            cached_code_words[((vstart<4194304?vstart:((vstart|0x400000)&0x7fffff))+i)>>5]|=1<<(((vstart+i)>>2)&7);
          }
        }
        ht_bin=hash_table[((vaddr>>16)^vaddr)&0xFFFF];
        if(ht_bin[0]==vaddr) {
          ht_bin[1]=(int)head->addr; // Replace existing entry
        }
        else
        {
          ht_bin[3]=ht_bin[1];
          ht_bin[2]=ht_bin[0];
          ht_bin[1]=(int)head->addr;
          ht_bin[0]=vaddr;
        }
        //printf("TRACE: get_addr dirty (%x,%x)\n",vaddr,(int)head->addr);
        return head->addr;
      }
    }
    head=head->next;
  }
  sh2_recompile_block(vaddr);
  return get_addr(vaddr);
}
// Look up address in hash table first
void *get_addr_ht(u32 vaddr)
{
  //printf("TRACE: count=%d next=%d (get_addr_ht %x)\n",Count,next_interupt,vaddr);
  //if(vaddr>>12==0x60a0) printf("TRACE: (get_addr_ht %x)\n",vaddr);
  int *ht_bin=hash_table[((vaddr>>16)^vaddr)&0xFFFF];
  //if(vaddr>>12==0x60a0) printf("%x %x %x %x\n",ht_bin[0],ht_bin[1],ht_bin[2],ht_bin[3]);
  if(ht_bin[0]==vaddr) return (void *)ht_bin[1];
  if(ht_bin[2]==vaddr) return (void *)ht_bin[3];
  return get_addr(vaddr);
}

void clear_all_regs(signed char regmap[])
{
  int hr;
  for (hr=0;hr<HOST_REGS;hr++) regmap[hr]=-1;
}

signed char get_reg(signed char regmap[],int r)
{
  int hr;
  for (hr=0;hr<HOST_REGS;hr++) if(hr!=EXCLUDE_REG&&regmap[hr]==r) return hr;
  return -1;
}

// Get a second temporary register (hopefully different from the first)
signed char get_alt_reg(signed char regmap[],int r)
{
  int hr;
  for (hr=HOST_REGS-1;hr>=0;hr--) if(hr!=EXCLUDE_REG&&regmap[hr]==r) return hr;
  return -1;
}

// Find a register that is available for two consecutive cycles
signed char get_reg2(signed char regmap1[],signed char regmap2[],int r)
{
  int hr;
  for (hr=0;hr<HOST_REGS;hr++) if(hr!=EXCLUDE_REG&&regmap1[hr]==r&&regmap2[hr]==r) return hr;
  return -1;
}

int count_free_regs(signed char regmap[])
{
  int count=0;
  int hr;
  for(hr=0;hr<HOST_REGS;hr++)
  {
    if(hr!=EXCLUDE_REG) {
      if(regmap[hr]<0) count++;
    }
  }
  return count;
}

void dirty_reg(struct regstat *cur,signed char reg)
{
  int hr;
  if(reg<0) return;
  for (hr=0;hr<HOST_REGS;hr++) {
    if((cur->regmap[hr]&63)==reg) {
      cur->dirty|=1<<hr;
    }
  }
}

void set_const(struct regstat *cur,signed char reg,u64 value)
{
  int hr;
  if(reg<0) return;
  for (hr=0;hr<HOST_REGS;hr++) {
    if(cur->regmap[hr]==reg) {
      cur->isdoingcp|=1<<hr;
      cur->cpmap[hr]=value;
    }
    else if((cur->regmap[hr]^64)==reg) {
      cur->isdoingcp|=1<<hr;
      cur->cpmap[hr]=value>>32;
    }
  }
}

void clear_const(struct regstat *cur,signed char reg)
{
  int hr;
  if(reg<0) return;
  for (hr=0;hr<HOST_REGS;hr++) {
    if((cur->regmap[hr]&63)==reg) {
      cur->isdoingcp&=~(1<<hr);
    }
  }
}

int is_const(struct regstat *cur,signed char reg)
{
  int hr;
  if(reg<0) return 0;
  for (hr=0;hr<HOST_REGS;hr++) {
    if((cur->regmap[hr]&63)==reg) {
      return (cur->isdoingcp>>hr)&1;
    }
  }
  return 0;
}
u64 get_const(struct regstat *cur,signed char reg)
{
  int hr;
  if(reg<0) return 0;
  for (hr=0;hr<HOST_REGS;hr++) {
    if(cur->regmap[hr]==reg) {
      return cur->cpmap[hr];
    }
  }
  printf("Unknown constant in r%d\n",reg);
  exit(1);
}

void sh2_set_const(u32 *isconst,u32 *constmap,signed char reg,u64 value)
{
  *isconst|=1<<reg;
  constmap[reg]=value;
}

void sh2_clear_const(u32 *isconst,u32 *constmap,signed char reg)
{
  if(reg<0) return;
  *isconst&=~(1<<reg);
}


// Least soon needed registers
// Look at the next ten instructions and see which registers
// will be used.  Try not to reallocate these.
void lsn(unsigned char hsn[], int i, int *preferred_reg)
{
  int j;
  int b=-1;
  for(j=0;j<9;j++)
  {
    if(i+j>=slen) {
      j=slen-i-1;
      break;
    }
    if(itype[i+j]==UJUMP||itype[i+j]==RJUMP)
    {
      // Don't go past an unconditonal jump
      j++;
      break;
    }
  }
  for(;j>=0;j--)
  {
    if(rs1[i+j]>=0) hsn[rs1[i+j]]=j;
    if(rs2[i+j]>=0) hsn[rs2[i+j]]=j;
    if(rs3[i+j]>=0) hsn[rs3[i+j]]=j;
    if(rt1[i+j]>=0) hsn[rt1[i+j]]=j;
    if(rt2[i+j]>=0) hsn[rt2[i+j]]=j;
    if(rs1[i+j]==TBIT) hsn[SR]=j;
    if(rs2[i+j]==TBIT) hsn[SR]=j;
    if(rs3[i+j]==TBIT) hsn[SR]=j;
    if(rt1[i+j]==TBIT) hsn[SR]=j;
    if(rt2[i+j]==TBIT) hsn[SR]=j;
    if(i+j>=0&&(itype[i+j]==UJUMP||itype[i+j]==CJUMP||itype[i+j]==SJUMP))
    {
      hsn[CCREG]=j;
      b=j;
    }
  }
  if(b>=0)
  {
    if(ba[i+b]>=start && ba[i+b]<(start+slen*4))
    {
      // Follow first branch
      int t=(ba[i+b]-start)>>2;
      j=7-b;if(t+j>=slen) j=slen-t-1;
      for(;j>=0;j--)
      {
        if(rs1[t+j]>=0) if(hsn[rs1[t+j]]>j+b+2) hsn[rs1[t+j]]=j+b+2;
        if(rs2[t+j]>=0) if(hsn[rs2[t+j]]>j+b+2) hsn[rs2[t+j]]=j+b+2;
        if(rs3[t+j]>=0) if(hsn[rs2[t+j]]>j+b+2) hsn[rs2[t+j]]=j+b+2;
        //if(rt1[t+j]) if(hsn[rt1[t+j]]>j+b+2) hsn[rt1[t+j]]=j+b+2;
        //if(rt2[t+j]) if(hsn[rt2[t+j]]>j+b+2) hsn[rt2[t+j]]=j+b+2;
      }
    }
    // TODO: preferred register based on backward branch
  }
  // Delay slot should preferably not overwrite branch conditions or cycle count
  if(i>0&&(itype[i-1]==RJUMP||itype[i-1]==UJUMP||itype[i-1]==SJUMP)) {
    if(rs1[i-1]>=0) if(hsn[rs1[i-1]]>1) hsn[rs1[i-1]]=1;
    if(rs2[i-1]>=0) if(hsn[rs2[i-1]]>1) hsn[rs2[i-1]]=1;
    if(rs3[i-1]>=0) if(hsn[rs3[i-1]]>1) hsn[rs3[i-1]]=1;
    if(itype[i-1]==SJUMP) if(hsn[SR]>1) hsn[SR]=1;
    hsn[CCREG]=1;
    // ...or hash tables
    hsn[RHASH]=1;
    hsn[RHTBL]=1;
    // .. or branch target
    hsn[RTEMP]=1;
  }
  // If reading/writing T bit, need SR
  if(rs1[i]==TBIT||rs2[i]==TBIT||rt1[i]==TBIT||rt2[i]==TBIT) {
    hsn[SR]=0;
  }
  // Don't remove the memory_map registers either
  if(itype[i]==LOAD || itype[i]==STORE || itype[i]==RMW || itype[i]==PCREL) {
    hsn[MOREG]=0;
  }
  if(itype[i]==UJUMP || itype[i]==RJUMP || itype[i]==SJUMP)
  {  
    if(itype[i+1]==LOAD || itype[i+1]==STORE || itype[i+1]==RMW || itype[i+1]==PCREL) {
      hsn[MOREG]=0;
    }
  }
  if(itype[i]==SYSTEM && opcode[i]==12) { // TRAPA
    hsn[MOREG]=0;
  }
  // Don't remove the miniht registers
  if(itype[i]==UJUMP||itype[i]==RJUMP)
  {
    hsn[RHASH]=0;
    hsn[RHTBL]=0;
    // or branch target
    hsn[RTEMP]=0;
  }
}

// We only want to allocate registers if we're going to use them again soon
int needed_again(int r, int i)
{
  int j;
  int b=-1;
  int rn=10;
  
  if(i>0&&(itype[i-1]==UJUMP||itype[i-1]==RJUMP))
  {
    if(ba[i-1]<start || ba[i-1]>start+slen*4-4)
      return 0; // Don't need any registers if exiting the block
  }
  for(j=0;j<9;j++)
  {
    if(i+j>=slen) {
      j=slen-i-1;
      break;
    }
    if(itype[i+j]==UJUMP||itype[i+j]==RJUMP)
    {
      // Don't go past an unconditonal jump
      j++;
      break;
    }
    if(itype[i+j]==SYSCALL||itype[i+j]==SYSTEM) 
    {
      break;
    }
  }
  for(;j>=1;j--)
  {
    if(rs1[i+j]==r) rn=j;
    if(rs2[i+j]==r) rn=j;
    if((unneeded_reg[i+j]>>r)&1) rn=10;
    if(i+j>=0&&(itype[i+j]==UJUMP||itype[i+j]==CJUMP||itype[i+j]==SJUMP))
    {
      b=j;
    }
  }
  /*
  if(b>=0)
  {
    if(ba[i+b]>=start && ba[i+b]<(start+slen*4))
    {
      // Follow first branch
      int o=rn;
      int t=(ba[i+b]-start)>>2;
      j=7-b;if(t+j>=slen) j=slen-t-1;
      for(;j>=0;j--)
      {
        if(!((unneeded_reg[t+j]>>r)&1)) {
          if(rs1[t+j]==r) if(rn>j+b+2) rn=j+b+2;
          if(rs2[t+j]==r) if(rn>j+b+2) rn=j+b+2;
        }
        else rn=o;
      }
    }
  }*/
  if(rn<10) return 1;
  return 0;
}

// Try to match register allocations at the end of a loop with those
// at the beginning
int loop_reg(int i, int r, int hr)
{
  int j,k;
  for(j=0;j<9;j++)
  {
    if(i+j>=slen) {
      j=slen-i-1;
      break;
    }
    if(itype[i+j]==UJUMP||itype[i+j]==RJUMP)
    {
      // Don't go past an unconditonal jump
      j++;
      break;
    }
  }
  k=0;
  if(i>0){
    if(itype[i-1]==UJUMP||itype[i-1]==CJUMP||itype[i-1]==SJUMP)
      k--;
  }
  for(;k<j;k++)
  {
    if(r<64&&((unneeded_reg[i+k]>>r)&1)) return hr;
    if(i+k>=0&&(itype[i+k]==UJUMP||itype[i+k]==CJUMP||itype[i+k]==SJUMP))
    {
      if(ba[i+k]>=start && ba[i+k]<(start+i*2))
      {
        int t=(ba[i+k]-start)>>1;
        int reg=get_reg(regs[t].regmap_entry,r);
        if(reg>=0) return reg;
        //reg=get_reg(regs[t+1].regmap_entry,r);
        //if(reg>=0) return reg;
      }
    }
  }
  return hr;
}


// Allocate every register, preserving source/target regs
void alloc_all(struct regstat *cur,int i)
{
  int hr;
  
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(((cur->regmap[hr]&63)!=rs1[i])&&((cur->regmap[hr]&63)!=rs2[i])&&((cur->regmap[hr]&63)!=rs3[i])&&
         ((cur->regmap[hr]&63)!=rt1[i])&&((cur->regmap[hr]&63)!=rt2[i]))
      {
        cur->regmap[hr]=-1;
        cur->dirty&=~(1<<hr);
      }
    }
  }
}

int can_direct_read(int address)
{
  if((address&0xDFF00000)==0x200000) return 1;
  if((address&0xDE000000)==0x6000000) return 1;
  if((address&0xDFF00000)==0) return 1;
  return 0;
}

int can_direct_write(int address)
{
  if((address&0xDFF00000)==0x200000) return 1;
  if((address&0xDE000000)==0x6000000) return 1;
  return 0;
}

static pointer map_address(u32 address)
{
  if((address&0xDFF00000)==0x200000) return (pointer)LowWram+(address&0xFFFFF);
  if((address&0xDE000000)==0x6000000) return (pointer)HighWram+(address&0xFFFFF);
  assert((address&0xDFF00000)==0);
  return (pointer)BiosRom+(address&0x8FFFF);
}

#ifdef __i386__
#include "assem_x86.c"
#endif
#ifdef __x86_64__
#include "assem_x64.c"
#endif
#ifdef __arm__
#include "assem_arm.c"
#endif

// Add virtual address mapping to linked list
void ll_add(struct ll_entry **head,int vaddr,void *addr)
{
  struct ll_entry *new_entry;
  new_entry=malloc(sizeof(struct ll_entry));
  assert(new_entry!=NULL);
  new_entry->vaddr=vaddr;
  new_entry->reg32=0;
  new_entry->addr=addr;
  new_entry->next=*head;
  *head=new_entry;
}

// Add to linked list only if there is not an existing record
void ll_add_nodup(struct ll_entry **head,int vaddr,void *addr)
{
  struct ll_entry *ptr;
  ptr=*head;
  while(ptr!=NULL) {
    if(ptr->vaddr==vaddr) {
      return;
    }
    ptr=ptr->next;
  }
  ll_add(head,vaddr,addr);
}

// Check if an address is already compiled
// but don't return addresses which are about to expire from the cache
void *check_addr(u32 vaddr)
{
  struct ll_entry *head;
  u32 page;
  u32 *ht_bin=hash_table[((vaddr>>16)^vaddr)&0xFFFF];
  if(ht_bin[0]==vaddr) {
    if(((ht_bin[1]-MAX_OUTPUT_BLOCK_SIZE-(u32)out)<<(32-TARGET_SIZE_2))>0x60000000+(MAX_OUTPUT_BLOCK_SIZE<<(32-TARGET_SIZE_2)))
      if(isclean(ht_bin[1])) return (void *)ht_bin[1];
  }
  if(ht_bin[2]==vaddr) {
    if(((ht_bin[3]-MAX_OUTPUT_BLOCK_SIZE-(u32)out)<<(32-TARGET_SIZE_2))>0x60000000+(MAX_OUTPUT_BLOCK_SIZE<<(32-TARGET_SIZE_2)))
      if(isclean(ht_bin[3])) return (void *)ht_bin[3];
  }
  page=(vaddr&0xDFFFFFFF)>>12;
  if(page>1024) page=1024+(page&1023);
  head=jump_in[page];
  while(head!=NULL) {
    if(head->vaddr==vaddr) {
      if((((u32)head->addr-(u32)out)<<(32-TARGET_SIZE_2))>0x60000000+(MAX_OUTPUT_BLOCK_SIZE<<(32-TARGET_SIZE_2))) {
        // Update existing entry with current address
        if(ht_bin[0]==vaddr) {
          ht_bin[1]=(int)head->addr;
          return head->addr;
        }
        if(ht_bin[2]==vaddr) {
          ht_bin[3]=(int)head->addr;
          return head->addr;
        }
        // Insert into hash table with low priority.
        // Don't evict existing entries, as they are probably
        // addresses that are being accessed frequently.
        if(ht_bin[0]==-1) {
          ht_bin[1]=(int)head->addr;
          ht_bin[0]=vaddr;
        }else if(ht_bin[2]==-1) {
          ht_bin[3]=(int)head->addr;
          ht_bin[2]=vaddr;
        }
        return head->addr;
      }
    }
    head=head->next;
  }
  return 0;
}

void remove_hash(int vaddr)
{
  //printf("remove hash: %x\n",vaddr);
  int *ht_bin=hash_table[(((vaddr)>>16)^vaddr)&0xFFFF];
  if(ht_bin[2]==vaddr) {
    ht_bin[2]=ht_bin[3]=-1;
  }
  if(ht_bin[0]==vaddr) {
    ht_bin[0]=ht_bin[2];
    ht_bin[1]=ht_bin[3];
    ht_bin[2]=ht_bin[3]=-1;
  }
}

void ll_remove_matching_addrs(struct ll_entry **head,int addr,int shift)
{
  struct ll_entry *next;
  while(*head) {
    if(((u32)((*head)->addr)>>shift)==(addr>>shift) || 
       ((u32)(((char *)(*head)->addr)-MAX_OUTPUT_BLOCK_SIZE)>>shift)==(addr>>shift))
    {
      inv_debug("EXP: Remove pointer to %x (%x)\n",(int)(*head)->addr,(*head)->vaddr);
      remove_hash((*head)->vaddr);
      next=(*head)->next;
      free(*head);
      *head=next;
    }
    else
    {
      head=&((*head)->next);
    }
  }
}

// Remove all entries from linked list
void ll_clear(struct ll_entry **head)
{
  struct ll_entry *cur;
  struct ll_entry *next;
  if(cur=*head) {
    *head=0;
    while(cur) {
      next=cur->next;
      free(cur);
      cur=next;
    }
  }
}

// Dereference the pointers and remove if it matches
void ll_kill_pointers(struct ll_entry *head,int addr,int shift)
{
  while(head) {
    int ptr=get_pointer(head->addr);
    inv_debug("EXP: Lookup pointer to %x at %x (%x)\n",(int)ptr,(int)head->addr,head->vaddr);
    if(((ptr>>shift)==(addr>>shift)) ||
       (((ptr-MAX_OUTPUT_BLOCK_SIZE)>>shift)==(addr>>shift)))
    {
      u32 host_addr;
      inv_debug("EXP: Kill pointer at %x (%x)\n",(int)head->addr,head->vaddr);
      host_addr=(u32)kill_pointer(head->addr);
      #ifdef __arm__
        needs_clear_cache[(host_addr-(u32)BASE_ADDR)>>17]|=1<<(((host_addr-(u32)BASE_ADDR)>>12)&31);
      #endif
    }
    head=head->next;
  }
}

// This is called when we write to a compiled block
void invalidate_page(u32 page)
{
  struct ll_entry *head;
  struct ll_entry *next;
  head=jump_in[page];
  jump_in[page]=0;
  while(head!=NULL) {
    inv_debug("INVALIDATE: %x\n",head->vaddr);
    remove_hash(head->vaddr);
    next=head->next;
    free(head);
    head=next;
  }
  head=jump_out[page];
  jump_out[page]=0;
  while(head!=NULL) {
    u32 host_addr;
    inv_debug("INVALIDATE: kill pointer to %x (%x)\n",head->vaddr,(int)head->addr);
    host_addr=(u32)kill_pointer(head->addr);
    #ifdef __arm__
      needs_clear_cache[(host_addr-(u32)BASE_ADDR)>>17]|=1<<(((host_addr-(u32)BASE_ADDR)>>12)&31);
    #endif
    next=head->next;
    free(head);
    head=next;
  }
}

void invalidate_blocks(u32 firstblock,u32 lastblock)
{
  u32 page;
  int block;
  u32 first,last;
  first=firstblock<1024?firstblock:1024+(firstblock&1023);
  last=lastblock<1024?lastblock:1024+(lastblock&1023);
  // Invalidate the adjacent pages if a block crosses a 4K boundary
  for(block=firstblock;block<=lastblock;block++) {
    struct ll_entry *head;
    page=block&0xDFFFF;
    if(page>1024) page=1024+(page&1023);
    inv_debug("INVALIDATE: %x..%x (%d)\n",firstblock<<12,lastblock<<12,page);
    //inv_debug("invalid_code[block]=%d\n",invalid_code[block]);
    head=jump_dirty[page];
    //printf("page=%d vpage=%d\n",page,vpage);
    while(head!=NULL) {
      u32 start,end;
      if((head->vaddr>>12)==block) { // Ignore vaddr hash collision
        get_bounds((pointer)head->addr,&start,&end);
        //printf("start: %x end: %x\n",start,end);
        if(start>=(u32)LowWram&&end<(u32)LowWram+1048576) {
          if(((start-(u32)LowWram)>>12)<=page&&((end-1-(u32)LowWram)>>12)>=page) {
            if((((start-(u32)LowWram)>>12)+512)<first) first=((start-(u32)LowWram)>>12)&1023;
            if((((end-1-(u32)LowWram)>>12)+512)>last) last=((end-1-(u32)LowWram)>>12)&1023;
          }
        }
        // FIXME: Aliasing/mirroring is wrong here
        if(start>=(u32)HighWram&&end<(u32)HighWram+1048576) {
          if(((start-(u32)HighWram)>>12)<=page-1024&&((end-1-(u32)HighWram)>>12)>=page-1024) {
            if((((start-(u32)HighWram)>>12)&255)<first-1024) first=(((start-(u32)HighWram)>>12)&255)+1024;
            if((((end-1-(u32)HighWram)>>12)&255)>last-1024) last=(((end-1-(u32)HighWram)>>12)&255)+1024;
          }
        }
      }
      head=head->next;
    }
  }
  //printf("first=%d last=%d\n",first,last);
  while(first<=last) {
    invalidate_page(first);
    first++;
  }
  #ifdef __arm__
    do_clear_cache();
  #endif
  
  for(block=firstblock;block<=lastblock;block++) {
    // Don't trap writes
    cached_code[block>>3]&=~(1<<(block&7));
    cached_code[(block^0x20000)>>3]&=~(1<<(block&7));
    
    #ifdef POINTERS_64BIT
    if((block>=0x0200&&block<0x0300)||(block>=0x20200&&block<0x20300)) {
      memory_map[block]=((u64)LowWram-((block<<12)&0xFFF00000))>>2;
      memory_map[block^0x20000]=((u64)LowWram-(((block^0x20000)<<12)&0xFFF00000))>>2;
    }
    if((block>=0x6000&&block<0x8000)||(block>=0x26000&&block<0x28000)) {
      memory_map[block]=((u64)HighWram-((block<<12)&0xFFF00000))>>2;
      memory_map[block^0x20000]=((u64)HighWram-(((block^0x20000)<<12)&0xFFF00000))>>2;
    }
    #else
    if((block>=0x0200&&block<0x0300)||(block>=0x20200&&block<0x20300)) {
      memory_map[block]=((u32)LowWram-((block<<12)&0xFFF00000))>>2;
      memory_map[block^0x20000]=((u32)LowWram-(((block^0x20000)<<12)&0xFFF00000))>>2;
    }
    if((block>=0x6000&&block<0x8000)||(block>=0x26000&&block<0x28000)) {
      memory_map[block]=((u32)HighWram-((block<<12)&0xFFF00000))>>2;
      memory_map[block^0x20000]=((u32)HighWram-(((block^0x20000)<<12)&0xFFF00000))>>2;
    }
    #endif
    page=block&0xDFFFF;
    if(page>1024) page=1024+(page&1023);
    memset(cached_code_words+(page<<7),0,128);
  }
  #ifdef USE_MINI_HT
  memset(mini_ht_master,-1,sizeof(mini_ht_master));
  memset(mini_ht_slave,-1,sizeof(mini_ht_slave));
  #endif
}
void invalidate_addr(u32 addr)
{
  u32 index=addr&0xDFFFFFFF;
  if(index>4194304) index=(addr|0x400000)&0x7fffff;
  if(!((cached_code_words[index>>5]>>((index>>2)&7))&1)) {
    // If we get an excessive number of these,
    // then we probably do want to invalidate the page
    if(invalidate_count++<500) {
      if((restore_candidate[index>>15]>>((index>>12)&7))&1) {
        recent_writes[recent_write_index]=addr;
        recent_write_index=(recent_write_index+1)&7;
      }
      return;
    }
  }
  //printf("invalidate_count: %d\n",invalidate_count);
  //printf("invalidate_addr(%x)\n",addr);
  //invalidate_block(addr>>12);
  invalidate_blocks(addr>>12,addr>>12);
  assert(!((cached_code_words[index>>5]>>((index>>2)&7))&1));
  
  // Keep track of recent writes that invalidated the cache, so we don't
  // attempt constant propagation in areas that are frequently written
  recent_writes[recent_write_index]=addr;
  recent_write_index=(recent_write_index+1)&7;
}
// This is called when loading a save state.
// Anything could have changed, so invalidate everything.
void invalidate_all_pages()
{
  u32 page;
  for(page=0;page<2048;page++)
    invalidate_page(page);
  for(page=0;page<256;page++) {
    if(cached_code[page]) {
      restore_candidate[page]|=cached_code[page]; // LowWram/bios
    }
    if(cached_code[3072+page]) {
      restore_candidate[page+256]|=cached_code[3072+page]; // HighWram
    }
  }
  memset(cached_code_words,0,262144);
  #ifdef __arm__
  __clear_cache((void *)BASE_ADDR,(void *)BASE_ADDR+(1<<TARGET_SIZE_2));
  #endif
  #ifdef USE_MINI_HT
  memset(mini_ht_master,-1,sizeof(mini_ht_master));
  memset(mini_ht_slave,-1,sizeof(mini_ht_slave));
  #endif
}

// Add an entry to jump_out after making a link
void add_link(u32 vaddr,void *src)
{
  u32 page=(vaddr&0xDFFFFFFF)>>12;
  if(page>1024) page=1024+(page&1023);
  inv_debug("add_link: %x -> %x (%d)\n",(int)src,vaddr,page);
  ll_add(jump_out+page,vaddr,src);
  //int ptr=get_pointer(src);
  //inv_debug("add_link: Pointer is to %x\n",(int)ptr);
}

// If a code block was found to be unmodified (bit was set in
// restore_candidate) and it remains unmodified (bit is set
// in cached_code) then move the entries for that 4K page from
// the dirty list to the clean list.
void clean_blocks(u32 page)
{
  struct ll_entry *head;
  inv_debug("INV: clean_blocks page=%d\n",page);
  head=jump_dirty[page];
  while(head!=NULL) {
    if((cached_code[head->vaddr>>15]>>((head->vaddr>>12)&7))&1) {;
      // Don't restore blocks which are about to expire from the cache
      if((((u32)head->addr-(u32)out)<<(32-TARGET_SIZE_2))>0x60000000+(MAX_OUTPUT_BLOCK_SIZE<<(32-TARGET_SIZE_2))) {
        u32 start,end,vstart=0,vend;
        if(verify_dirty((int)head->addr)) {
          //printf("Possibly Restore %x (%x)\n",head->vaddr, (int)head->addr);
          u32 i;
          u32 inv=0;
          get_bounds((pointer)head->addr,&start,&end);
          if(start-(u32)HighWram<0x100000) {
            vstart=start-(u32)HighWram+0x6000000;
            vend=end-(u32)HighWram+0x6000000;
            for(i=(start-(u32)HighWram+0x6000000)>>12;i<=(end-1-(u32)HighWram+0x6000000)>>12;i++) {
              // Check that all the pages are write-protected
              if(!((cached_code[i>>3]>>(i&7))&1)) inv=1;
            }
          }
          if(start-(u32)LowWram<0x100000) {
            vstart=start-(u32)LowWram+0x200000;
            vend=end-(u32)LowWram+0x200000;
            for(i=(start-(u32)LowWram+0x200000)>>12;i<=(end-1-(u32)LowWram+0x200000)>>12;i++) {
              // Check that all the pages are write-protected
              if(!((cached_code[i>>3]>>(i&7))&1)) inv=1;
            }
          }
          // Don't restore stuff that recently got hit, it will probably get hit again
          if(vstart) for(i=0;i<8;i++) {
            if(recent_writes[i]>=vstart&&recent_writes[i]<vend) {
              //printf("recent write: %x\n",recent_writes[i]);
              inv=1;
            }
          }
          if(!inv) {
            void * clean_addr=(void *)get_clean_addr((int)head->addr);
            if((((u32)clean_addr-(u32)out)<<(32-TARGET_SIZE_2))>0x60000000+(MAX_OUTPUT_BLOCK_SIZE<<(32-TARGET_SIZE_2))) {
              int *ht_bin;
              inv_debug("INV: Restored %x (%x/%x)\n",head->vaddr, (int)head->addr, (int)clean_addr);
              //printf("page=%x, addr=%x\n",page,head->vaddr);
              //assert(head->vaddr>>12==(page|0x80000));
              ll_add_nodup(jump_in+page,head->vaddr,clean_addr);
              ht_bin=hash_table[((head->vaddr>>16)^head->vaddr)&0xFFFF];
              if(ht_bin[0]==head->vaddr) {
                ht_bin[1]=(int)clean_addr; // Replace existing entry
              }
              if(ht_bin[2]==head->vaddr) {
                ht_bin[3]=(int)clean_addr; // Replace existing entry
              }
            }
            if(vstart) {
              //printf("start=%x, end=%x\n",vstart,vend);
              for(i=0;i<vend-vstart;i+=4) {
                cached_code_words[((vstart<4194304?vstart:((vstart|0x400000)&0x7fffff))+i)>>5]|=1<<(((vstart+i)>>2)&7);
              }
            }
          }
        }
      }
    }
    head=head->next;
  }
}


do_consts(int i,u32 *isconst,u32 *constmap)
{
  switch(itype[i]) {
    case LOAD:
      sh2_clear_const(isconst,constmap,rt1[i]);
      if(addrmode[i]==POSTINC) {
        int size=(opcode[i]==4)?2:(opcode2[i]&3);
        constmap[rt2[i]]+=1<<size;
      }
      break;
    case STORE:
      if(addrmode[i]==PREDEC) {
        int size=(opcode[i]==4)?2:(opcode2[i]&3);
        constmap[rt1[i]]-=1<<size;
      }
      break;
    case RMW:
      break;
    case PCREL:
      if(opcode[i]==12) sh2_set_const(isconst,constmap,rt1[i],((start+i*2+4)&~3)+imm[i]); // MOVA
      else { // PC-relative load (constant pool)
        u32 addr=((start+i*2+4)&~3)+imm[i];
        if((u32)((addr-start)>>1)<slen) {
          int value;
          if(opcode[i]==9) value=(s16)source[((start+i*2+4)+imm[i]-start)>>1]; // MOV.W
          else value=(source[(((start+i*2+4)&~3)+imm[i]-start)>>1]<<16)+source[(((start+i*2+4)&~3)+imm[i]+2-start)>>1]; // MOV.L
          sh2_set_const(isconst,constmap,rt1[i],value);
        }
        else sh2_clear_const(isconst,constmap,rt1[i]);
      }
      break;
    case MOV:
      if(((*isconst)>>rs1[i])&1) {
        int v=constmap[rs1[i]];
        sh2_set_const(isconst,constmap,rt1[i],v);
      }
      else sh2_clear_const(isconst,constmap,rt1[i]);
      break;
    case IMM8:
      if(opcode[i]==0x7) { // ADD
        if(((*isconst)>>rs1[i])&1) {
          int v=constmap[rs1[i]];
          sh2_set_const(isconst,constmap,rt1[i],v+imm[i]);
        }
        else sh2_clear_const(isconst,constmap,rt1[i]);
      }
      else if(opcode[i]==0x8) { // CMP/EQ
      }
      else if(opcode[i]==12) {
        if(opcode2[i]==8) { // TST
        }else
        // AND/XOR/OR
        if(((*isconst)>>rs1[i])&1) {
          int v=constmap[rs1[i]];
          if(opcode2[i]==0x09) sh2_set_const(isconst,constmap,rt1[i],v&imm[i]);
          if(opcode2[i]==0x0a) sh2_set_const(isconst,constmap,rt1[i],v^imm[i]);
          if(opcode2[i]==0x0b) sh2_set_const(isconst,constmap,rt1[i],v|imm[i]);
        }
        else sh2_clear_const(isconst,constmap,rt1[i]);
      }
      else { // opcode[i]==0xE
        assert(opcode[i]==0xE);
        sh2_set_const(isconst,constmap,rt1[i],imm[i]); // MOV
      }
      break;
    case FLAGS:
      if(opcode2[i]==9) { // MOVT
        sh2_clear_const(isconst,constmap,rt1[i]);
      }
      break;
    case ALU:
      sh2_clear_const(isconst,constmap,rt1[i]);
      break;
    case EXT:
      sh2_clear_const(isconst,constmap,rt1[i]);
      break;
    case MULTDIV:
      if(opcode[i]==0) {
        if(opcode2[i]==7) // MUL.L
        {
          sh2_clear_const(isconst,constmap,MACL);
        }
        if(opcode2[i]==8) // CLRMAC
        {
          sh2_clear_const(isconst,constmap,MACH);
          sh2_clear_const(isconst,constmap,MACL);
        }
        if(opcode2[i]==9) // DIV0U
        {
        }
      }
      if(opcode[i]==2) {
        if(opcode2[i]==7) // DIV0S
        {
        }
        if(opcode2[i]==14||opcode2[i]==15) // MULU.W / MULS.W
        {
          sh2_clear_const(isconst,constmap,MACL);
        }
      }
      if(opcode[i]==3) {
        // DMULU.L / DMULS.L
        sh2_clear_const(isconst,constmap,MACH);
        sh2_clear_const(isconst,constmap,MACL);
      }
      break;
    case SHIFTIMM:
      sh2_clear_const(isconst,constmap,rt1[i]);
      break;
    case UJUMP:
    case RJUMP:
    case SJUMP:
    case CJUMP:
      break;
    case SYSTEM:
      *isconst=0;
      break;
    case COMPLEX:
      *isconst=0;
      break;
  }
}

void mov_alloc(struct regstat *current,int i)
{
  // Note: Don't need to actually alloc the source registers
  // TODO: Constant propagation
  //alloc_reg(current,i,rs1[i]);
  alloc_reg(current,i,rt1[i]);
  clear_const(current,rs1[i]);
  clear_const(current,rt1[i]);
  dirty_reg(current,rt1[i]);
}

void shiftimm_alloc(struct regstat *current,int i)
{
  clear_const(current,rs1[i]);
  clear_const(current,rt1[i]);
  alloc_reg(current,i,rs1[i]);
  alloc_reg(current,i,rt1[i]);
  dirty_reg(current,rt1[i]);
  if(opcode[i]==4) {
    if(opcode2[i]<6) { // SHLL/SHAL/SHLR/SHAR/ROTL/ROTCL/ROTR/ROTCR
      if(opcode2[i]<4||opcode3[i]<2) {
        // SHL/SHA/ROT don't need T bit as a source, only a destination
        if(!(current->u&(1LL<<TBIT))) {
          alloc_reg(current,i,SR);
          dirty_reg(current,SR);
        }
      }
      else {
        alloc_reg(current,i,SR); // ROTCL/ROTCR always need T bit
        dirty_reg(current,SR);
      }
    }
  }
  if(opcode[i]==2&opcode2[i]==13) { // XTRCT
    clear_const(current,rs2[i]);
    alloc_reg(current,i,rs2[i]);
  }
}

void alu_alloc(struct regstat *current,int i)
{
  if(opcode[i]==2) {
    alloc_reg(current,i,rs1[i]);
    alloc_reg(current,i,rs2[i]);
    clear_const(current,rs2[i]);
    if(opcode2[i]>8&&opcode2[i]<=11) { // AND/XOR/OR
      alloc_reg(current,i,rt1[i]);
    }
    else  // TST or CMP/STR
    {
      alloc_reg(current,i,SR); // Liveness analysis on TBIT?
      dirty_reg(current,SR);
      //#ifdef __x86__ ?
      //#ifdef NEEDS_TEMP
      if(opcode2[i]==8) { // TST
        alloc_reg_temp(current,i,-1);
        minimum_free_regs[i]=1;
      }
      if(opcode2[i]==12) { // CMP/STR
        alloc_reg_temp(current,i,-1);
        minimum_free_regs[i]=1;
      }
    }
  }
  if(opcode[i]==3) {
    alloc_reg(current,i,rs1[i]);
    alloc_reg(current,i,rs2[i]);
    clear_const(current,rs2[i]);
    if(opcode2[i]<8) { // CMP intructions
      alloc_reg(current,i,SR); // Liveness analysis on TBIT?
      dirty_reg(current,SR);
      alloc_reg_temp(current,i,-1);
      minimum_free_regs[i]=1;
    }else{ // ADD/SUB
      alloc_reg(current,i,rt1[i]);
      if(opcode2[i]&3) {
        alloc_reg(current,i,SR);
        dirty_reg(current,SR);
        //#ifdef NEEDS_TEMP
        if((opcode2[i]&3)==3) {
          // Need a temporary register for ADDV/SUBV on x86
          alloc_reg_temp(current,i,-1);
          minimum_free_regs[i]=1;
        }
      }
    }
  }
  if(opcode[i]==4) { // DT/CMPPZ/CMPPL
    // Single operand forms
    alloc_reg(current,i,rs1[i]);
    if(opcode2[i]==0) dirty_reg(current,rt1[i]); // DT
    alloc_reg(current,i,SR); // Liveness analysis on TBIT?
    dirty_reg(current,SR);
    if(opcode2[i]>0) {
      alloc_reg_temp(current,i,-1);
      minimum_free_regs[i]=1;
    }
  }
  if(opcode[i]==6) { // NOT/NEG/NEGC
    if(needed_again(rs1[i],i)) alloc_reg(current,i,rs1[i]);
    alloc_reg(current,i,rt1[i]);
    if(opcode2[i]==8||opcode2[i]==9) { // SWAP needs temp (?)
      alloc_reg_temp(current,i,-1);
      minimum_free_regs[i]=1;
    }
    if(opcode2[i]==10) {
      // NEGC sets T bit
      alloc_reg(current,i,SR); // Liveness analysis on TBIT?
      dirty_reg(current,SR);
    }
  }
  clear_const(current,rs1[i]);
  clear_const(current,rt1[i]);
  dirty_reg(current,rt1[i]);
}

void imm8_alloc(struct regstat *current,int i)
{
  //if(rs1[i]>=0&&needed_again(rs1[i],i)) alloc_reg(current,i,rs1[i]);
  //else lt1[i]=rs1[i];
  alloc_reg(current,i,rs1[i]);
  if(rt1[i]>=0&&rt1[i]!=TBIT) alloc_reg(current,i,rt1[i]);
  if(opcode[i]==0x7) { // ADD
    if(is_const(current,rs1[i])) {
      int v=get_const(current,rs1[i]);
      set_const(current,rt1[i],v+imm[i]);
    }
    else clear_const(current,rt1[i]);
  }
  else if(opcode[i]==0x8) { // CMP/EQ
    alloc_reg(current,i,SR); // Liveness analysis on TBIT?
    dirty_reg(current,SR);
    alloc_reg_temp(current,i,-1);
    minimum_free_regs[i]=1;
  }
  else if(opcode[i]==12) {
    if(opcode2[i]==8) { // TST
      alloc_reg(current,i,SR); // Liveness analysis on TBIT?
      dirty_reg(current,SR);
      alloc_reg_temp(current,i,-1);
      minimum_free_regs[i]=1;
    }else
    // AND/XOR/OR
    if(is_const(current,rs1[i])) {
      int v=get_const(current,rs1[i]);
      if(opcode2[i]==0x09) set_const(current,rt1[i],v&imm[i]);
      if(opcode2[i]==0x0a) set_const(current,rt1[i],v^imm[i]);
      if(opcode2[i]==0x0b) set_const(current,rt1[i],v|imm[i]);
    }
    else clear_const(current,rt1[i]);
  }
  else { // opcode[i]==0xE
    assert(opcode[i]==0xE);
    set_const(current,rt1[i],imm[i]); // MOV
  }
  if(rt1[i]>=0&&rt1[i]!=TBIT) dirty_reg(current,rt1[i]);
}

void ext_alloc(struct regstat *current,int i)
{
  // Note: Don't need to actually alloc the source registers
  // FIXME: Constant propagation
  //alloc_reg(current,i,rs1[i]);
  alloc_reg(current,i,rt1[i]);
  clear_const(current,rs1[i]);
  clear_const(current,rt1[i]);
  dirty_reg(current,rt1[i]);
}

void flags_alloc(struct regstat *current,int i)
{
  if(opcode2[i]==8) { // CLRT/SETT
    alloc_reg(current,i,SR);
    dirty_reg(current,SR);
  }else
  if(opcode2[i]==9) { // MOVT
    alloc_reg(current,i,SR);
    alloc_reg(current,i,rt1[i]);
    clear_const(current,rt1[i]);
    dirty_reg(current,rt1[i]);
  }
}

void load_alloc(struct regstat *current,int i)
{
  int hr;
  clear_const(current,rt1[i]);
  //if(rs1[i]!=rt1[i]&&needed_again(rs1[i],i)) clear_const(current,rs1[i]); // Does this help or hurt?
  if(needed_again(rs1[i],i)) alloc_reg(current,i,rs1[i]);
 // if(rs2[i]>=0) alloc_reg(current,i,rs2[i]);
  alloc_reg(current,i,rt1[i]==TBIT?SR:rt1[i]);
  if(addrmode[i]==DUALIND||addrmode[i]==GBRIND) {
    alloc_reg(current,i,rs1[i]);
    alloc_reg(current,i,rs2[i]);
    if(!is_const(current,rs1[i])||!is_const(current,rs2[i])) {
      // Both must be constants to propagate the sum
      clear_const(current,rs1[i]);
      clear_const(current,rs2[i]);
    }
  }
  else
  if(addrmode[i]==POSTINC) {
    if(is_const(current,rt2[i])) {
      int v=get_const(current,rt2[i]);
      set_const(current,rt2[i],v+(1<<((opcode[i]==4)?2:(opcode2[i]&3))));
      // Note: constant is preincremented, address_generation corrects the offset
    }
    else {
      alloc_reg(current,i,rt2[i]);
      dirty_reg(current,rt2[i]);
    }
  }

  // Need a register to load from memory_map
  alloc_reg(current,i,MOREG);
  if(rt1[i]==TBIT||get_reg(current->regmap,rt1[i])<0) {
    // dummy load, but we still need a register to calculate the address
    alloc_reg_temp(current,i,-1);
    minimum_free_regs[i]=1;
  }
  if(rt1[i]==TBIT) dirty_reg(current,SR);
  else dirty_reg(current,rt1[i]);
  
  // Make MOREG a temporary, give pass 5 another register to work with
  hr=get_reg(current->regmap,MOREG);
  assert(hr>=0);
  assert(current->regmap[hr]==MOREG);
  current->regmap[hr]=-1;
  minimum_free_regs[i]++;
}

void store_alloc(struct regstat *current,int i)
{
  int hr;
  //printf("%x: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",start+i*2,current->regmap[0],current->regmap[1],current->regmap[2],current->regmap[3],current->regmap[5],current->regmap[6],current->regmap[7]);
  if(addrmode[i]==DUALIND) {
    alloc_reg(current,i,rs2[i]);
    alloc_reg(current,i,0); // rs3[i]
    if(!is_const(current,rs2[i])||!is_const(current,rs3[i])) {
      // Both must be constants to propagate the sum
      clear_const(current,rs2[i]);
      clear_const(current,rs3[i]);
    }
  }
  if(addrmode[i]==PREDEC) {
    if(is_const(current,rt1[i])) {
      int v=get_const(current,rt1[i]);
      set_const(current,rt1[i],v-(1<<((opcode[i]==4)?2:(opcode2[i]&3))));
    }
    else {
      alloc_reg(current,i,rt1[i]);
      dirty_reg(current,rt1[i]);
    }
  }
  if(needed_again(rs2[i],i)) alloc_reg(current,i,rs2[i]);
  clear_const(current,rs1[i]);
  alloc_reg(current,i,rs1[i]);
  // Need a register to load from memory_map
  alloc_reg(current,i,MOREG);
  
  // We need a temporary register for address generation
  alloc_reg_temp(current,i,-1);
  minimum_free_regs[i]=1;

  // Make MOREG a temporary, give pass 5 another register to work with
  hr=get_reg(current->regmap,MOREG);
  assert(hr>=0);
  assert(current->regmap[hr]==MOREG);
  current->regmap[hr]=-1;
  minimum_free_regs[i]++;
}

void rmw_alloc(struct regstat *current,int i)
{
  //printf("%x: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",start+i*2,current->regmap[0],current->regmap[1],current->regmap[2],current->regmap[3],current->regmap[5],current->regmap[6],current->regmap[7]);
  if(addrmode[i]==GBRIND) {
    alloc_reg(current,i,GBR);
    alloc_reg(current,i,0);
    if(!is_const(current,rs2[i])||!is_const(current,rs3[i])) {
      // Both must be constants to propagate the sum
      clear_const(current,rs2[i]);
      clear_const(current,rs3[i]);
    }
  }
  if(addrmode[i]==REGIND&&needed_again(rs1[i],i)) alloc_reg(current,i,rs1[i]);
  if(rt1[i]==TBIT) {
    alloc_reg(current,i,SR);
    dirty_reg(current,SR);
  }

  // Need a register to load from memory_map
  alloc_reg(current,i,MOREG);
  
  // We need a temporary register for address generation
  alloc_reg_temp(current,i,-1);
  // And one for the read-modify-write
  //alloc_reg_temp(current,i,-2); // Can re-use mapping reg for this
  minimum_free_regs[i]=1;
}

void pcrel_alloc(struct regstat *current,int i)
{
  u32 addr;
  alloc_reg(current,i,rt1[i]);
  addr=((start+i*2+4)&~3)+imm[i];
  if(opcode[i]==12) { // MOVA, address generation only
    set_const(current,rt1[i],addr);
  }else if((unsigned)((addr-start)>>1)<slen) {
    if(opcode[i]==9) { // MOV.W
      addr=(start+i*2+4)+imm[i];
      set_const(current,rt1[i],(s16)source[(addr-start)>>1]);
    }
    else // MOV.L
      set_const(current,rt1[i],(source[(addr-start)>>1]<<16)+source[(addr+2-start)>>1]);
  }
  else {
    // Do actual load
    //alloc_reg(current,i,MOREG);
    clear_const(current,rt1[i]);
  }
  dirty_reg(current,rt1[i]);
}

#ifndef multdiv_alloc
void multdiv_alloc(struct regstat *current,int i)
{
  //printf("%x: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",start+i*2,current->regmap[0],current->regmap[1],current->regmap[2],current->regmap[3],current->regmap[5],current->regmap[6],current->regmap[7]);
  if(opcode[i]==0) {
    if(opcode2[i]==7) // MUL.L
    {
      clear_const(current,rs1[i]);
      clear_const(current,rs2[i]);
      clear_const(current,MACL);
      alloc_reg(current,i,rs1[i]);
      alloc_reg(current,i,rs2[i]);
      alloc_reg(current,i,MACL);
      dirty_reg(current,MACL);
    }
    if(opcode2[i]==8) // CLRMAC
    {
      clear_const(current,MACH);
      clear_const(current,MACL);
      alloc_reg(current,i,MACH);
      alloc_reg(current,i,MACL);
      dirty_reg(current,MACH);
      dirty_reg(current,MACL);
    }
    if(opcode2[i]==9) // DIV0U
    {
      alloc_reg(current,i,SR);
      dirty_reg(current,SR);
    }
  }
  if(opcode[i]==2) {
    if(opcode2[i]==7) // DIV0S
    {
      clear_const(current,rs1[i]); // Is this necessary?
      clear_const(current,rs2[i]); // Is this necessary?
      alloc_reg(current,i,rs1[i]);
      alloc_reg(current,i,rs2[i]);
      alloc_reg(current,i,SR);
      dirty_reg(current,SR);
      #if defined(__i386__) || defined(__x86_64__)
      //#ifdef NEEDS_TEMP
      alloc_reg_temp(current,i,-1);
      minimum_free_regs[i]=1;
      #endif
    }
    if(opcode2[i]==14||opcode2[i]==15) // MULU.W / MULS.W
    {
      clear_const(current,rs1[i]);
      clear_const(current,rs2[i]);
      clear_const(current,MACL);
      alloc_reg(current,i,rs1[i]);
      alloc_reg(current,i,rs2[i]);
      alloc_reg(current,i,MACL);
      dirty_reg(current,MACL);
      //#ifdef NEEDS_TEMP
      alloc_reg_temp(current,i,-1);
      minimum_free_regs[i]=1;
    }
  }
  if(opcode[i]==3) {
    // DMULU.L / DMULS.L
    #if defined(__i386__) || defined(__x86_64__)
    if(!(current->u&(1LL<<MACH))) {
      alloc_x86_reg(current,i,MACH,EDX); // Don't need to alloc MACH if it's unneeded
      current->u&=~(1LL<<MACL); // But if it is, then assume MACL is needed since it will be overwritten
    }
    alloc_x86_reg(current,i,MACL,EAX);
    #else
    if(!(current->u&(1LL<<MACH))) {
      alloc_reg(current,i,MACH);
      current->u&=~(1LL<<MACL);
    }
    alloc_reg(current,i,MACL);
    #endif
    clear_const(current,rs1[i]);
    clear_const(current,rs2[i]);
    clear_const(current,MACH);
    clear_const(current,MACL);
    alloc_reg(current,i,rs1[i]);
    alloc_reg(current,i,rs2[i]);
    dirty_reg(current,MACH);
    dirty_reg(current,MACL);
  }
}
#endif

void complex_alloc(struct regstat *current,int i)
{
  if(opcode[i]==3&&opcode2[i]==4) { // DIV1
    #if defined(__i386__) || defined(__x86_64__)
    alloc_x86_reg(current,i,rs1[i],ECX);
    alloc_x86_reg(current,i,rs2[i],EAX);
    alloc_x86_reg(current,i,SR,EDX);
    alloc_all(current,i);
    #else
    #if defined(__arm__)
    alloc_arm_reg(current,i,rs1[i],1);
    alloc_arm_reg(current,i,rs2[i],0);
    alloc_arm_reg(current,i,SR,2);
    alloc_all(current,i);
    #else
    // FIXME
    assert(0);
    #endif
    #endif
    dirty_reg(current,rs2[i]);
    dirty_reg(current,SR);
  }
  if(opcode[i]==0&&opcode2[i]==15) { // MAC.L
    #if defined(__i386__) || defined(__x86_64__)
    alloc_x86_reg(current,i,rs1[i],EBP);
    alloc_x86_reg(current,i,rs2[i],EDI);
    alloc_x86_reg(current,i,SR,EBX);
    alloc_all(current,i);
    alloc_x86_reg(current,i,MACL,EAX);
    alloc_x86_reg(current,i,MACH,EDX);
    #else
    #if defined(__arm__)
    alloc_arm_reg(current,i,rs1[i],5);
    alloc_arm_reg(current,i,rs2[i],6);
    alloc_arm_reg(current,i,SR,4);
    alloc_all(current,i);
    alloc_arm_reg(current,i,MACL,0);
    alloc_arm_reg(current,i,MACH,1);
    #else
    // FIXME
    assert(0);
    #endif
    #endif
    dirty_reg(current,rs1[i]);
    dirty_reg(current,rs2[i]);
    dirty_reg(current,MACH);
    dirty_reg(current,MACL);
    clear_const(current,MACH);
    clear_const(current,MACL);
  }
  if(opcode[i]==4&&opcode2[i]==15) { // MAC.W
    #if defined(__i386__) || defined(__x86_64__)
    alloc_x86_reg(current,i,rs1[i],EBP);
    alloc_x86_reg(current,i,rs2[i],EDI);
    alloc_x86_reg(current,i,SR,EBX);
    alloc_all(current,i);
    alloc_x86_reg(current,i,MACL,EAX);
    alloc_x86_reg(current,i,MACH,EDX);
    #else
    #if defined(__arm__)
    alloc_arm_reg(current,i,rs1[i],5);
    alloc_arm_reg(current,i,rs2[i],6);
    alloc_arm_reg(current,i,SR,4);
    alloc_all(current,i);
    alloc_arm_reg(current,i,MACL,0);
    alloc_arm_reg(current,i,MACH,1);
    #else
    // FIXME
    assert(0);
    #endif
    #endif
    dirty_reg(current,rs1[i]);
    dirty_reg(current,rs2[i]);
    dirty_reg(current,MACH);
    dirty_reg(current,MACL);
    clear_const(current,MACH);
    clear_const(current,MACL);
  }
  clear_const(current,rs1[i]);
  clear_const(current,rs2[i]);
  minimum_free_regs[i]=HOST_REGS;
}

void system_alloc(struct regstat *current,int i)
{
  alloc_cc(current,i);
  dirty_reg(current,CCREG);
  if(opcode[i]==12) { // TRAPA
    alloc_reg(current,i,15); // Stack reg
    dirty_reg(current,15);
    alloc_reg(current,i,SR); // Status/flags
    alloc_reg(current,i,VBR);
    alloc_reg(current,i,MOREG); // memory_map offset
    alloc_reg_temp(current,i,-1);
    minimum_free_regs[i]=1;
  }
  current->isdoingcp=0;
}

void delayslot_alloc(struct regstat *current,int i)
{
  switch(itype[i]) {
    case UJUMP:
    case CJUMP:
    case SJUMP:
    case RJUMP:
    case SYSCALL:
      assem_debug("jump in the delay slot.  this shouldn't happen.\n");//exit(1);
      printf("Disabled speculative precompilation\n");
      stop_after_jal=1;
      break;
    case IMM8:
      imm8_alloc(current,i);
      break;
    case LOAD:
      load_alloc(current,i);
      break;
    case STORE:
      store_alloc(current,i);
      break;
    case RMW:
      rmw_alloc(current,i);
      break;
    case PCREL:
      pcrel_alloc(current,i);
      break;
    case ALU:
      alu_alloc(current,i);
      break;
    case MULTDIV:
      multdiv_alloc(current,i);
      break;
    case SHIFTIMM:
      shiftimm_alloc(current,i);
      break;
    case MOV:
      mov_alloc(current,i);
      break;
    case EXT:
      ext_alloc(current,i);
      break;
    case FLAGS:
      flags_alloc(current,i);
      break;
    case COMPLEX:
      complex_alloc(current,i);
      break;
  }
}

add_stub(int type,int addr,int retaddr,int a,int b,int c,int d,int e)
{
  stubs[stubcount][0]=type;
  stubs[stubcount][1]=addr;
  stubs[stubcount][2]=retaddr;
  stubs[stubcount][3]=a;
  stubs[stubcount][4]=b;
  stubs[stubcount][5]=c;
  stubs[stubcount][6]=d;
  stubs[stubcount][7]=e;
  stubcount++;
}

// Write out a single register
void wb_register(signed char r,signed char regmap[],u32 dirty)
{
  int hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if((regmap[hr]&63)==r) {
        if((dirty>>hr)&1) {
          emit_storereg(r,hr);
        }
      }
    }
  }
}

/*int mchecksum()
{
  //if(!tracedebug) return 0;
  int i;
  int sum=0;
  for(i=0;i<2097152;i++) {
    unsigned int temp=sum;
    sum<<=1;
    sum|=(~temp)>>31;
    sum^=((u_int *)rdram)[i];
  }
  return sum;
}
/*int rchecksum()
{
  int i;
  int sum=0;
  for(i=0;i<64;i++)
    sum^=((u_int *)reg)[i];
  return sum;
}
/*int fchecksum()
{
  int i;
  int sum=0;
  for(i=0;i<64;i++)
    sum^=((u_int *)reg_cop1_fgr_64)[i];
  return sum;
}*/
/*void rlist()
{
  int i;
  printf("TRACE: ");
  for(i=0;i<32;i++)
    printf("r%d:%8x%8x ",i,((int *)(reg+i))[1],((int *)(reg+i))[0]);
  printf("\n");
  //printf("TRACE: ");
  //for(i=0;i<32;i++)
  //  printf("f%d:%8x%8x ",i,((int*)reg_cop1_simple[i])[1],*((int*)reg_cop1_simple[i]));
  //printf("\n");
}*/

void enabletrace()
{
  tracedebug=1;
}

#if 0
void memdebug(int i)
{
  //printf("TRACE: count=%d next=%d (checksum %x) lo=%8x%8x\n",Count,next_interupt,mchecksum(),(int)(reg[LOREG]>>32),(int)reg[LOREG]);
  //printf("TRACE: count=%d next=%d (rchecksum %x)\n",Count,next_interupt,rchecksum());
  //rlist();
  //if(tracedebug) {
  //if(Count>=-2084597794) {
  //if((signed int)Count>=-2084597794&&(signed int)Count<0) {
  //if(0) {
    printf("TRACE: (checksum %x)\n",mchecksum());
    //printf("TRACE: count=%d next=%d (checksum %x)\n",Count,next_interupt,mchecksum());
    //printf("TRACE: count=%d next=%d (checksum %x) Status=%x\n",Count,next_interupt,mchecksum(),Status);
    //printf("TRACE: count=%d next=%d (checksum %x) hi=%8x%8x\n",Count,next_interupt,mchecksum(),(int)(reg[HIREG]>>32),(int)reg[HIREG]);
    //rlist();
    #ifdef __i386__
    printf("TRACE: %x\n",(&i)[-1]);
    #endif
    #ifdef __arm__
    int j;
    printf("TRACE: %x \n",(&j)[10]);
    printf("TRACE: %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x\n",(&j)[1],(&j)[2],(&j)[3],(&j)[4],(&j)[5],(&j)[6],(&j)[7],(&j)[8],(&j)[9],(&j)[10],(&j)[11],(&j)[12],(&j)[13],(&j)[14],(&j)[15],(&j)[16],(&j)[17],(&j)[18],(&j)[19],(&j)[20]);
    #endif
    //fflush(stdout);
  //}
  //printf("TRACE: %x\n",(&i)[-1]);
}
#endif

void alu_assemble(int i,struct regstat *i_regs)
{
  if(opcode[i]==2) {
    if(opcode2[i]>=9&&opcode2[i]<=11) { // AND/XOR/OR
      signed char s,t;
      s=get_reg(i_regs->regmap,rs1[i]);
      t=get_reg(i_regs->regmap,rt1[i]);
      //assert(s>=0);
      if(t>=0) {
        if(opcode2[i]==9) emit_and(s,t,t);
        if(opcode2[i]==10) emit_xor(rs1[i]>=0?s:t,t,t);
        if(opcode2[i]==11) emit_or(s,t,t);
      }
    }
    else
    {
      signed char s1,s2,sr,temp;
      s1=get_reg(i_regs->regmap,rs1[i]);
      s2=get_reg(i_regs->regmap,rs2[i]);
      sr=get_reg(i_regs->regmap,SR);
      temp=get_reg(i_regs->regmap,-1);
      assert(s1>=0);
      assert(s2>=0);
      assert(sr>=0);
      assert(temp>=0); // Not needed for TST on ARM?
      if(opcode2[i]==8) { // TST
        emit_sh2tst(s1,s2,sr,temp);
      }
      else if(opcode2[i]==12) { // CMP/STR
        emit_cmpstr(s1,s2,sr,temp);
      }
    }
  }
  if(opcode[i]==3) { // ADD/SUB
    if(opcode2[i]<8) { // CMP
      signed char s1,s2,sr,temp;
      s1=get_reg(i_regs->regmap,rs1[i]);
      s2=get_reg(i_regs->regmap,rs2[i]);
      sr=get_reg(i_regs->regmap,SR);
      temp=get_reg(i_regs->regmap,-1);
      assert(s1>=0);
      assert(s2>=0);
      assert(temp>=0);
      if(opcode2[i]==0) emit_cmpeq(s1,s2,sr,temp);
      if(opcode2[i]==2) emit_cmphs(s1,s2,sr,temp);
      if(opcode2[i]==3) emit_cmpge(s1,s2,sr,temp);
      if(opcode2[i]==6) emit_cmphi(s1,s2,sr,temp);
      if(opcode2[i]==7) emit_cmpgt(s1,s2,sr,temp);
    }
    else
    {
      signed char s,t,sr,temp;
      t=get_reg(i_regs->regmap,rt1[i]);
      if(t>=0) {
        s=get_reg(i_regs->regmap,rs1[i]);
        sr=get_reg(i_regs->regmap,SR);
        temp=get_reg(i_regs->regmap,-1);
        assert(s>=0);
        //assert(s2==t);
        if(opcode2[i]==8) emit_sub(t,s,t);
        if(opcode2[i]==10) emit_subc(s,t,sr);
        //if(opcode2[i]==11) emit_subv(s,sr,temp);
        assert(opcode2[i]!=11);
        if(opcode2[i]==12) emit_add(s,t,t);
        if(opcode2[i]==14) emit_addc(s,t,sr);
        //if(opcode2[i]==15) emit_addv(s,sr,temp);
        assert(opcode2[i]!=15);
      }
    }
  }
  if(opcode[i]==4) { // DT/CMPPZ/CMPPL
    signed char s,t,sr,temp;
    s=get_reg(i_regs->regmap,rs1[i]);
    sr=get_reg(i_regs->regmap,SR);
    assert(s>=0);
    assert(sr>=0);
    if(opcode2[i]==0) {
      t=get_reg(i_regs->regmap,rt1[i]);
      assert(t>=0); // FIXME - Liveness analysis
      assert(s==t);
      emit_dt(s,sr);
    }
    else if(opcode2[i]==1) emit_cmppz(s,sr);
    else if(opcode2[i]==5) 
    {
      temp=get_reg(i_regs->regmap,-1);
      emit_cmppl(s,sr,temp);
    }
  }
  if(opcode[i]==6) { // NOT/SWAP/NEG
    int s=get_reg(i_regs->regmap,rs1[i]);
    int t=get_reg(i_regs->regmap,rt1[i]);
    if(s<0) {
      // FIXME: Preload?
      emit_loadreg(rs1[i],t);
      s=t;
    }
    if(t>=0) {
      if(opcode2[i]==7) emit_not(s,t);
      if(opcode2[i]==8) emit_swapb(s,t);
      if(opcode2[i]==9) emit_rorimm(s,16,t);
      if(opcode2[i]==11) emit_neg(s,t);
    }
    if(opcode2[i]==10) { // NEGC
      int sr=get_reg(i_regs->regmap,SR);
      if(i_regs->u&(1LL<<rt1[i])) t=-1;
      assert(sr>=0);
      emit_negc(s,t,sr);
    }
  }
}

void imm8_assemble(int i,struct regstat *i_regs)
{
  if(opcode[i]==0x7) { // ADD
    signed char s,t;
    t=get_reg(i_regs->regmap,rt1[i]);
    s=get_reg(i_regs->regmap,rs1[i]);
    //assert(t>=0);
    assert(s>=0);
    if(t>=0) {
      if(!((i_regs->isdoingcp>>t)&1)) {
        if(s<0) {
          if(i_regs->regmap_entry[t]!=rs1[i]) emit_loadreg(rs1[i],t);
          emit_addimm(t,imm[i],t);
        }else{
          if(!((i_regs->wasdoingcp>>s)&1))
            emit_addimm(s,imm[i],t);
          else
            emit_movimm(cpmap[i][s]+imm[i],t);
        }
      }
    }
  }
  else if(opcode[i]==0x8) { // CMP/EQ
    signed char s,sr,temp;
    s=get_reg(i_regs->regmap,rs1[i]);
    sr=get_reg(i_regs->regmap,SR);
    temp=get_reg(i_regs->regmap,-1);
    assert(s>=0);
    assert(sr>=0); // Liveness analysis?
    assert(temp>=0);
    emit_cmpeqimm(s,imm[i],sr,temp);
  }
  else if(opcode[i]==12) {
    if(opcode2[i]==8) { // TST
      signed char s,sr,temp;
      s=get_reg(i_regs->regmap,rs1[i]);
      sr=get_reg(i_regs->regmap,SR);
      temp=get_reg(i_regs->regmap,-1);
      assert(s>=0);
      assert(sr>=0); // Liveness analysis?
      assert(temp>=0);
      emit_sh2tstimm(s,imm[i],sr,temp);
    }else{
      signed char s,t;
      t=get_reg(i_regs->regmap,rt1[i]);
      s=get_reg(i_regs->regmap,rs1[i]);
      if(t>=0 && !((i_regs->isdoingcp>>t)&1)) {
        if(opcode2[i]==9) //AND
        {
          if(s<0) {
            if(i_regs->regmap_entry[t]!=rs1[i]) emit_loadreg(rs1[i],t);
            emit_andimm(t,imm[i],t);
          }else{
            if(!((i_regs->wasdoingcp>>s)&1))
              emit_andimm(s,imm[i],t);
            else
              emit_movimm(cpmap[i][s]&imm[i],t);
          }
        }
        else
        if(opcode2[i]==10) //XOR
        {
          if(s<0) {
            if(i_regs->regmap_entry[t]!=rs1[i]) emit_loadreg(rs1[i],t);
            emit_xorimm(t,imm[i],t);
          }else{
            if(!((i_regs->wasdoingcp>>s)&1))
              emit_xorimm(s,imm[i],t);
            else
              emit_movimm(cpmap[i][s]^imm[i],t);
          }
        }
        else
        if(opcode2[i]==11) //OR
        {
          if(s<0) {
            if(i_regs->regmap_entry[t]!=rs1[i]) emit_loadreg(rs1[i],t);
            emit_orimm(t,imm[i],t);
          }else{
            if(!((i_regs->wasdoingcp>>s)&1))
              emit_orimm(s,imm[i],t);
            else
              emit_movimm(cpmap[i][s]|imm[i],t);
          }
        }
      }
    }
  }
  else { // opcode[i]==0xE
    signed char t;
    assert(opcode[i]==0xE);
    t=get_reg(i_regs->regmap,rt1[i]);
    //assert(t>=0);
    if(t>=0) {
      if(!((i_regs->isdoingcp>>t)&1))
        emit_movimm(imm[i]<<16,t);
    }
  }
}

void shiftimm_assemble(int i,struct regstat *i_regs)
{
  if(opcode[i]==4) // SHL/SHR
  {
    if(opcode2[i]<8) {
      signed char s,t,sr;
      s=get_reg(i_regs->regmap,rs1[i]);
      t=get_reg(i_regs->regmap,rt1[i]);
      sr=get_reg(i_regs->regmap,SR);
      assert(s==t);
      if(opcode2[i]==0) // SHLL/SHAL
      {
        if(i_regs->u&(1LL<<TBIT)) emit_shlimm(s,1,s);
        else emit_shlsr(s,sr); // Is there any difference between SHLL and SHAL?
      }
      else if(opcode2[i]==1) // SHLR/SHAR
      {
        if(i_regs->u&(1LL<<TBIT)) {
          // Skip T bit if unneeded
          if(opcode3[i]==0) emit_shrimm(s,1,s);
          if(opcode3[i]==2) emit_sarimm(s,1,s);
        }else{
          // Set T bit
          if(opcode3[i]==0) emit_shrsr(s,sr);
          if(opcode3[i]==2) emit_sarsr(s,sr);
        }
      }
      else if(opcode2[i]==4) {// ROTL/ROTCL
        if(opcode3[i]==0) {
          if(i_regs->u&(1LL<<TBIT)) {
            emit_rotl(s); // Skip T bit if unneeded
          }else{
            emit_rotlsr(s,sr);
          }
        }
        if(opcode3[i]==2) emit_rotclsr(s,sr);
      }
      else {
        assert(opcode2[i]==5); // ROTR/ROTCR
        if(opcode3[i]==0) {
          if(i_regs->u&(1LL<<TBIT)) {
            emit_rotr(s); // Skip T bit if unneeded
          }else{
            emit_rotrsr(s,sr);
          }
        }
        if(opcode3[i]==2) emit_rotcrsr(s,sr);
      }
    }else{
      signed char s,t;
      s=get_reg(i_regs->regmap,rs1[i]);
      t=get_reg(i_regs->regmap,rt1[i]);
      //assert(t>=0);
      if(t>=0){
        if(opcode2[i]==8) // SHLL
        {
          if(opcode3[i]==0) emit_shlimm(s,2,t);
          if(opcode3[i]==1) emit_shlimm(s,8,t);
          if(opcode3[i]==2) emit_shlimm(s,16,t);
        }
        if(opcode2[i]==9) // SHLR
        {
          if(opcode3[i]==0) emit_shrimm(s,2,t);
          if(opcode3[i]==1) emit_shrimm(s,8,t);
          if(opcode3[i]==2) emit_shrimm(s,16,t);
        }
      }
    }
  }
  else if(opcode[i]==2) // XTRCT
  {
    signed char s,t,sr;
    s=get_reg(i_regs->regmap,rs1[i]);
    t=get_reg(i_regs->regmap,rt1[i]);
    assert(rs2[i]==rt1[i]);
    emit_shrdimm(t,s,16,t);
  }
}

void load_assemble(int i,struct regstat *i_regs)
{
  int dummy;
  int s,o,t,addr,map=-1,cache=-1;
  int offset;
  int jaddr=0;
  int memtarget,c=0;
  int dualindex=(addrmode[i]==DUALIND||addrmode[i]==GBRIND);
  int size=(opcode[i]==4)?2:(opcode2[i]&3);
  unsigned int hr;
  u32 reglist=0;
  pointer constaddr;
  t=get_reg(i_regs->regmap,rt1[i]==TBIT?-1:rt1[i]);
  s=get_reg(i_regs->regmap,rs1[i]);
  o=get_reg(i_regs->regmap,rs2[i]);
  offset=imm[i];
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }
  //if(i_regs->regmap[HOST_CCREG]==CCREG) reglist&=~(1<<HOST_CCREG);
  if(s>=0) {
    if(dualindex)
      c=(i_regs->wasdoingcp>>s)&(i_regs->wasdoingcp>>o)&1;
    else
      c=(i_regs->wasdoingcp>>s)&1;
    if(c) {
      if(dualindex)
        constaddr=cpmap[i][s]+cpmap[i][o];
      else
        constaddr=cpmap[i][s]+offset;
      //if(dualindex) {
      // if((i_regs->isconst>>rs1[i])&(i_regs->isconst>>rs2[i])&1)
      //  assert(constaddr==i_regs->constmap[rs1[i]]+i_regs->constmap[rs2[i]]);
      //}else
      // if((i_regs->isconst>>rs1[i])&1)
      //  assert(constaddr==i_regs->constmap[rs1[i]]+offset);
      if(addrmode[i]==POSTINC) constaddr-=1<<size;
      //printf("constaddr=%x offset=%x\n",constaddr,offset);
      memtarget=can_direct_read(constaddr);
    }
  }
  if(t<0) t=get_reg(i_regs->regmap,-1);
  if(!c) {
    if(dualindex) {
      c=(i_regs->isconst>>rs1[i])&(i_regs->isconst>>rs2[i])&1;
    } else {
      c=(i_regs->isconst>>rs1[i])&1;
    }
    if(c) {
      if(dualindex)
        constaddr=i_regs->constmap[rs1[i]]+i_regs->constmap[rs2[i]];
      else
        constaddr=i_regs->constmap[rs1[i]]+offset;
      if(addrmode[i]==POSTINC) constaddr-=1<<size;
      //printf("constaddr=%x offset=%x\n",constaddr,offset);
      memtarget=can_direct_read(constaddr);
      #ifndef HOST_IMM_ADDR32
      // In this case, the constant is not already loaded into a register
      if(can_direct_read(constaddr))
        emit_movimm(map_address(constaddr^(!size)),t);
      #endif
    }
  }
  if(offset||dualindex||s<0||c) addr=t;
  else addr=s;
  //printf("load_assemble: c=%d\n",c);
  //if(c) printf("load_assemble: const=%x\n",(int)constaddr);
  assert(t>=0); // Even if the load is a NOP, we must check for I/O
  reglist&=~(1<<t);
  if(!c)
  {
    int x=0;
    if (!c&&size==0) x=1; // MOV.B
    cache=get_reg(i_regs->regmap,MMREG);
    map=get_reg(i_regs->regmap,MOREG);
    if(map<0) map=get_alt_reg(i_regs->regmap,-1);
    assert(map>=0);
    assert(map!=s);
    assert(map!=t);
    reglist&=~(1<<map);
    map=do_map_r(addr,t,map,cache,x,-1,-1,c,constaddr);
    if (!c&&size==0) addr=t; // MOV.B
    do_map_r_branch(map,c,constaddr,&jaddr);
    //jaddr=(int)out;emit_jmp(0); // for debugging
  }
  else
  {
    if(can_direct_read(constaddr)) constaddr=map_address(constaddr);
  }
  dummy=(t!=get_reg(i_regs->regmap,rt1[i])); // ignore loads to unneeded reg
  if(opcode[i]==12&&opcode2[i]==12) // TST.B
    dummy=i_regs->u&(1LL<<TBIT);
  if (size==0) { // MOV.B
    if(!c||memtarget) {
      if(!dummy) {
        #ifdef HOST_IMM_ADDR32
        if(c)
          emit_movsbl(constaddr^1,t);
        else
        #endif
        {
          int x=0;
          emit_movsbl_indexed_map(x,t,map,t);
        }
      }
      if(jaddr)
        add_stub(LOADB_STUB,jaddr,(int)out,i,addr,(int)i_regs,ccadj[i],reglist);
    }
    else
      inline_readstub(LOADB_STUB,i,constaddr,i_regs->regmap,rt1[i],ccadj[i],reglist);
    if(rt1[i]==TBIT&&!dummy) { // TST.B
      signed char sr;
      sr=get_reg(i_regs->regmap,SR);
      assert(sr>=0); // Liveness analysis?
      emit_sh2tstimm(t,imm[i],sr,t);
    }
  }
  if (size==1) { // MOV.W
    if(!c||memtarget) {
      if(!dummy) {
        #ifdef HOST_IMM_ADDR32
        if(c)
          emit_movswl(constaddr,t);
        else
        #endif
        {
          int x=0;
          emit_movswl_indexed_map(0,addr,map,t);
        }
      }
      if(jaddr)
        add_stub(LOADW_STUB,jaddr,(int)out,i,addr,(int)i_regs,ccadj[i],reglist);
    }
    else
      inline_readstub(LOADW_STUB,i,constaddr,i_regs->regmap,rt1[i],ccadj[i],reglist);
  }
  if (size==2) { // MOV.L
    if(!c||memtarget) {
      if(!dummy) {
        #ifdef HOST_IMM_ADDR32
        if(c)
          emit_readword(constaddr,t);
        else
        #endif
        emit_readword_indexed_map(0,addr,map,t);
        emit_rorimm(t,16,t);
      }
      if(jaddr)
        add_stub(LOADL_STUB,jaddr,(int)out,i,addr,(int)i_regs,ccadj[i],reglist);
    }
    else
      inline_readstub(LOADL_STUB,i,constaddr,i_regs->regmap,rt1[i],ccadj[i],reglist);
  }
  if(addrmode[i]==POSTINC) {
    if(!((i_regs->wasdoingcp>>s)&1)) {
      if(!(i_regs->u&(1LL<<rt2[i]))&&rt1[i]!=rt2[i]) 
        emit_addimm(s,1<<size,s);
    }
  }
  //emit_storereg(rt1[i],tl); // DEBUG
  //if(opcode[i]==0x23)
  //if(opcode[i]==0x24)
  //if(opcode[i]==0x23||opcode[i]==0x24)
  /*if(opcode[i]==0x21||opcode[i]==0x23||opcode[i]==0x24)
  {
    //emit_pusha();
    save_regs(0x100f);
        emit_readword((int)&last_count,ECX);
        #ifdef __i386__
        if(get_reg(i_regs->regmap,CCREG)<0)
          emit_loadreg(CCREG,HOST_CCREG);
        emit_add(HOST_CCREG,ECX,HOST_CCREG);
        emit_addimm(HOST_CCREG,2*ccadj[i],HOST_CCREG);
        emit_writeword(HOST_CCREG,(int)&Count);
        #endif
        #ifdef __arm__
        if(get_reg(i_regs->regmap,CCREG)<0)
          emit_loadreg(CCREG,0);
        else
          emit_mov(HOST_CCREG,0);
        emit_add(0,ECX,0);
        emit_addimm(0,2*ccadj[i],0);
        emit_writeword(0,(int)&Count);
        #endif
    emit_call((int)memdebug);
    //emit_popa();
    restore_regs(0x100f);
  }/**/
}

void store_assemble(int i,struct regstat *i_regs)
{
  int s,t,o,map=-1,cache=-1;
  int addr,temp;
  int offset;
  int jaddr=0,jaddr2,type;
  int memtarget,c=0,constaddr;
  int dualindex=(addrmode[i]==DUALIND);
  int size=(opcode[i]==4)?2:(opcode2[i]&3);
  int agr=AGEN1+(i&1);
  unsigned int hr;
  u32 reglist=0;
  t=get_reg(i_regs->regmap,rs1[i]);
  s=get_reg(i_regs->regmap,rs2[i]);
  o=get_reg(i_regs->regmap,rs3[i]);
  temp=get_reg(i_regs->regmap,agr);
  if(temp<0) temp=get_reg(i_regs->regmap,-1);
  offset=imm[i];
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }
  //if(i_regs->regmap[HOST_CCREG]==CCREG) reglist&=~(1<<HOST_CCREG);
  if(s>=0) {
    if(dualindex)
      c=(i_regs->wasdoingcp>>s)&(i_regs->wasdoingcp>>o)&1;
    else
      c=(i_regs->wasdoingcp>>s)&1;
    if(c) {
      if(dualindex)
        constaddr=cpmap[i][s]+cpmap[i][o];
      else
        constaddr=cpmap[i][s]+offset;
    }
    //printf("constaddr=%x offset=%x\n",constaddr,offset);
    memtarget=can_direct_write(constaddr);
  }
  if(!c) {
    if(dualindex) {
      c=(i_regs->isconst>>rs2[i])&(i_regs->isconst>>rs3[i])&1;
    } else {
      c=(i_regs->isconst>>rs2[i])&1;
    }
    if(c) {
      if(dualindex)
        constaddr=i_regs->constmap[rs2[i]]+i_regs->constmap[rs3[i]];
      else
        constaddr=i_regs->constmap[rs2[i]]+offset;
      //printf("constaddr=%x offset=%x\n",constaddr,offset);
      memtarget=can_direct_write(constaddr);
      // In this case, the constant is not already loaded into a register
      if(can_direct_write(constaddr)) {
        emit_movimm(constaddr^(!size),temp);
        map=get_reg(i_regs->regmap,MOREG);
        if(map<0) map=get_alt_reg(i_regs->regmap,-1);
        generate_map_const(constaddr,map);
      }
    }
  }
  assert(t>=0);
  assert(temp>=0);
  if(offset||dualindex||s<0||c) addr=temp;
  else addr=s;
  //printf("store_assemble: c=%d\n",c);
  if(addrmode[i]==PREDEC&&!c&&rt1[i]==rs1[i]) addr=temp; // Old value is written, so decremented address is in a temporary register
  if(addrmode[i]==REGIND&&!c&&rs1[i]==rs2[i]) {// Swapped value is written, so unswapped value must be used as the address
    emit_mov(addr,temp);addr=temp;
  }
  if(!c||memtarget)
  {
    int x=0;
    if (!c&&size==0) x=1; // MOV.B
    cache=get_reg(i_regs->regmap,MMREG);
    map=get_reg(i_regs->regmap,MOREG);
    if(map<0) map=get_alt_reg(i_regs->regmap,-1);
    assert(map>=0);
    assert(map!=temp);
    assert(map!=s);
    reglist&=~(1<<map);
    //if(x) emit_xorimm(addr,x,temp); // for debugging
    map=do_map_w(addr,temp,map,cache,x,c,constaddr);
    if (!c&&size==0) addr=temp; // MOV.B
    do_map_w_branch(map,c,constaddr,&jaddr);
    //jaddr=(int)out;emit_jmp(0); // for debugging
  }

  if (size==0) { // MOV.B
    if(!c||memtarget) {
      int x=0;
      emit_writebyte_indexed_map(t,x,temp,map,temp);
    }
    type=STOREB_STUB;
  }
  if (size==1) { // MOV.W
    if(!c||memtarget) {
      emit_writehword_indexed_map(t,0,addr,map,temp);
    }
    type=STOREW_STUB;
  }
  if (size==2) { // MOV.L
    if(!c||memtarget) {
      emit_rorimm(t,16,t);
      emit_writeword_indexed_map(t,0,addr,map,temp);
      if(!(i_regs->u&(1LL<<rs1[i]))) 
        emit_rorimm(t,16,t);
    }
    type=STOREL_STUB;
  }
  if(jaddr) {
    add_stub(type,jaddr,(int)out,i,addr,(int)i_regs,ccadj[i],reglist);
  } else if(c&&!memtarget) {
    inline_writestub(type,i,constaddr,i_regs->regmap,rs1[i],ccadj[i],reglist);
  }
  if(addrmode[i]==PREDEC) {
    assert(s>=0);
    if(!((i_regs->wasdoingcp>>s)&1)&&rt1[i]==rs1[i]) emit_addimm(s,-(1<<size),s); // Old value is written, so this "pre-decrement" is really post-decrement
  }
  //if(opcode[i]==0x2B || opcode[i]==0x3F)
  //if(opcode[i]==0x2B || opcode[i]==0x28)
  //if(opcode[i]==0x2B || opcode[i]==0x29)
  //if(opcode[i]==0x2B)
  /*if(opcode[i]==0x2B || opcode[i]==0x28 || opcode[i]==0x29 || opcode[i]==0x3F)
  {
    //emit_pusha();
    save_regs(0x100f);
        emit_readword((int)&last_count,ECX);
        #ifdef __i386__
        if(get_reg(i_regs->regmap,CCREG)<0)
          emit_loadreg(CCREG,HOST_CCREG);
        emit_add(HOST_CCREG,ECX,HOST_CCREG);
        emit_addimm(HOST_CCREG,2*ccadj[i],HOST_CCREG);
        emit_writeword(HOST_CCREG,(int)&Count);
        #endif
        #ifdef __arm__
        if(get_reg(i_regs->regmap,CCREG)<0)
          emit_loadreg(CCREG,0);
        else
          emit_mov(HOST_CCREG,0);
        emit_add(0,ECX,0);
        emit_addimm(0,2*ccadj[i],0);
        emit_writeword(0,(int)&Count);
        #endif
    emit_call((int)memdebug);
    //emit_popa();
    restore_regs(0x100f);
  }/**/
}

void rmw_assemble(int i,struct regstat *i_regs)
{
  int s,o,t,addr,map=-1,cache=-1;
  int jaddr=0;
  int type;
  int memtarget,c=0,constaddr;
  int dualindex=(addrmode[i]==GBRIND);
  unsigned int hr;
  u32 reglist=0;
  t=get_reg(i_regs->regmap,-1);
  s=get_reg(i_regs->regmap,rs1[i]);
  o=get_reg(i_regs->regmap,rs2[i]);
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }
  if(s>=0) {
    if(dualindex)
      c=(i_regs->wasdoingcp>>s)&(i_regs->wasdoingcp>>o)&1;
    else
      c=(i_regs->wasdoingcp>>s)&1;
    if(c) {
      if(dualindex)
         constaddr=cpmap[i][s]+cpmap[i][o];
      else
         constaddr=cpmap[i][s];
    }
    //printf("constaddr=%x offset=%x\n",constaddr,offset);
    memtarget=1; // FIXME
  }
  if(dualindex||s<0||c) addr=t;
  else addr=s;
  assert(t>=0);
  reglist&=~(1<<t);
  {
    int x=0;
    if (!c) x=1; // MOV.B
    map=get_reg(i_regs->regmap,MOREG);
    cache=get_reg(i_regs->regmap,MMREG);
    assert(map>=0);
    reglist&=~(1<<map);
    map=do_map_w(addr,t,map,cache,x,c,constaddr);
    if (!c) addr=t; // MOV.B
    do_map_w_branch(map,c,constaddr,&jaddr);
  }
  if(opcode2[i]==11) type=RMWT_STUB; // TAS.B
  if(opcode2[i]==13) type=RMWA_STUB; // AND.B
  if(opcode2[i]==14) type=RMWX_STUB; // XOR.B
  if(opcode2[i]==15) type=RMWO_STUB; // OR.B
  if(!c||memtarget) {
    if(opcode2[i]==11) { // TAS.B
      signed char sr;
      sr=get_reg(i_regs->regmap,SR);
      assert(sr>=0); // Liveness analysis?
      assert(rt1[i]==TBIT);
      if(sr>=0&&!(i_regs->u&(1LL<<TBIT))) emit_sh2tas(addr,map,sr);
      else emit_rmw_orimm(addr,map,0x80); // T ignored, set only
    }
    if(opcode2[i]==13) emit_rmw_andimm(addr,map,imm[i]); // AND.B
    if(opcode2[i]==14) emit_rmw_xorimm(addr,map,imm[i]); // XOR.B
    if(opcode2[i]==15) emit_rmw_orimm(addr,map,imm[i]); // OR.B
  }
  if(jaddr)
    add_stub(type,jaddr,(int)out,i,addr,(int)i_regs,ccadj[i],reglist);
}

void pcrel_assemble(int i,struct regstat *i_regs)
{
  int t,addr,map=-1,cache=-1;
  int offset;
  int jaddr=0;
  int memtarget,c=0,constaddr;
  unsigned int hr;
  u32 reglist=0;
  t=get_reg(i_regs->regmap,rt1[i]);
  offset=imm[i];
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }
  if(i_regs->regmap[HOST_CCREG]==CCREG) reglist&=~(1<<HOST_CCREG);
  if(t>=0) {
    if(!((i_regs->isdoingcp>>t)&1)) {
      int jaddr=0;
      // This is to handle the exceptional case where we can not do constant propagation
      assert(opcode[i]!=12); // MOVA should always be able to do constant propagation
      constaddr=((start+i*2+4)&~3)+imm[i];
      if(opcode[i]==9) constaddr=(start+i*2+4)+imm[i]; // MOV.W
      assem_debug("Can't do constant propagation, doing PC-relatve load\n");
      //int map=get_reg(i_regs->regmap,MOREG);
      //int cache=get_reg(i_regs->regmap,MMREG);
      //assert(map>=0);
      reglist&=~(1<<t);
      //reglist&=~(1<<map);
      assert(can_direct_read(constaddr));
      #ifndef HOST_IMM_ADDR32
      emit_movimm(map_address(constaddr),t);
      #endif
      //map=do_map_r(t,-1,map,cache,0,-1,-1,0,0);
      //do_map_r_branch(map,0,0,&jaddr);
      //assert(jaddr);
      if(opcode[i]==9) { // MOV.W
        // direct load
        #ifdef HOST_IMM_ADDR32
        emit_movswl(map_address(constaddr),t);
        #else
        //emit_movswl_indexed_map(0,t,map,t);
        emit_movswl_indexed(0,t,t);
        #endif
        //add_stub(LOADW_STUB,jaddr,(int)out,i,t,(int)(i_regs),ccadj[i],reglist);
      }
      else { // MOV.L
        // direct load
        #ifdef HOST_IMM_ADDR32
        emit_readword(map_address(constaddr),t);
        #else
        //emit_readword_indexed_map(0,t,map,t);
        emit_readword_indexed(0,t,t);
        #endif
        emit_rorimm(t,16,t);
        //add_stub(LOADL_STUB,jaddr,(int)out,i,t,(int)(i_regs),ccadj[i],reglist);
      }
    }
  }
}

//extern void debug_multiplication(int m,int n,int h,int l);
#ifndef multdiv_assemble
void multdiv_assemble(int i,struct regstat *i_regs)
{
  if(opcode[i]==0) {
    if(opcode2[i]==7) // MUL.L
    {
      int s1=get_reg(i_regs->regmap,rs1[i]);
      int s2=get_reg(i_regs->regmap,rs2[i]);
      int t=get_reg(i_regs->regmap,MACL);
      if(t>=0) emit_multiply(s1,s2,t);
    }
    if(opcode2[i]==8) // CLRMAC
    {
      int t1=get_reg(i_regs->regmap,rt1[i]);
      int t2=get_reg(i_regs->regmap,rt2[i]);
      if(!(i_regs->u&(1LL<<MACH))) 
        emit_zeroreg(t1);
      if(!(i_regs->u&(1LL<<MACL))) 
        emit_zeroreg(t2);
    }
    if(opcode2[i]==9) // DIV0U
    {
      int sr=get_reg(i_regs->regmap,SR);
      emit_andimm(sr,0xfe,sr);
    }
  }
  if(opcode[i]==2) {
    if(opcode2[i]==7) // DIV0S
    {
      int s1=get_reg(i_regs->regmap,rs1[i]);
      int s2=get_reg(i_regs->regmap,rs2[i]);
      int sr=get_reg(i_regs->regmap,SR);
      int temp=get_reg(i_regs->regmap,-1);
      assert(s1>=0);
      assert(s2>=0);
      assert(sr>=0);
      emit_div0s(s1,s2,sr,temp);
    }
    if(opcode2[i]==14||opcode2[i]==15) // MULU.W / MULS.W
    {
      int s1=get_reg(i_regs->regmap,rs1[i]);
      int s2=get_reg(i_regs->regmap,rs2[i]);
      int t=get_reg(i_regs->regmap,MACL);
      #ifdef HOST_TEMPREG
      int temp=HOST_TEMPREG;
      #else
      int temp=get_reg(i_regs->regmap,-1);
      #endif
      if(t>=0) {
        assert(temp>=0);
        if(opcode2[i]==14) { // MULU.W
          emit_movzwl_reg(s1,t);
          emit_movzwl_reg(s2,temp);
        }else{ // MULS.W
          emit_movswl_reg(s1,t);
          emit_movswl_reg(s2,temp);
        }
        emit_multiply(t,temp,t);
      }
      /* DEBUG
      emit_pusha();
      emit_pushreg(t);
      emit_pushreg(t);
      emit_pushreg(s2);
      emit_pushreg(s1);
      emit_call((int)debug_multiplication);
      emit_addimm(ESP,16,ESP);
      emit_popa();*/
    }
  }
  if(opcode[i]==3) {
    int s1=get_reg(i_regs->regmap,rs1[i]);
    int s2=get_reg(i_regs->regmap,rs2[i]);
    int th=get_reg(i_regs->regmap,MACH);
    int tl=get_reg(i_regs->regmap,MACL);
    if(th>=0) {
      // DMULU.L / DMULS.L
      #if defined(__i386__) || defined(__x86_64__)
      assert(tl==EAX);
      assert(th==EDX);
      assert(s1!=EAX); // This would work only if s1 is clean or dead
      if(s1!=EAX) emit_mov(s1,EAX);
      if(opcode2[i]==5) emit_mul(s2); // DMULU.L
      if(opcode2[i]==13) emit_imul(s2); // DMULS.L
      #else
      if(opcode2[i]==5) emit_umull(s1,s2,th,tl); // DMULU.L
      if(opcode2[i]==13) emit_smull(s1,s2,th,tl); // DMULS.L
      #endif
    }else if(tl>=0) {
      // MACH is unneeded, 32-bit result only
      emit_multiply(s1,s2,tl);
    }
    /* DEBUG
    emit_pusha();
    emit_pushreg(tl);
    emit_pushreg(th);
    emit_pushreg(s2);
    emit_pushreg(s1);
    emit_call((int)debug_multiplication);
    emit_addimm(ESP,16,ESP);
    emit_popa();*/
  }
}
#endif

void mov_assemble(int i,struct regstat *i_regs)
{
  signed char s,t;
  t=get_reg(i_regs->regmap,rt1[i]);
  //assert(t>=0);
  if(t>=0) {
    s=get_reg(i_regs->regmap,rs1[i]);
    if(s>=0) {if(s!=t) emit_mov(s,t);}
    else emit_loadreg(rs1[i],t);
  }
}

void ext_assemble(int i,struct regstat *i_regs)
{
  signed char s,t;
  t=get_reg(i_regs->regmap,rt1[i]);
  //assert(t>=0);
  if(t>=0) {
    s=get_reg(i_regs->regmap,rs1[i]);
    if(s>=0) {
      if(opcode2[i]==12) emit_movzbl_reg(s,t);
      if(opcode2[i]==13) emit_movzwl_reg(s,t);
      if(opcode2[i]==14) emit_movsbl_reg(s,t);
      if(opcode2[i]==15) emit_movswl_reg(s,t);
    }
    else
    {
      emit_loadreg(rs1[i],t); // Fix - do byte/halfword loads?
      if(opcode2[i]==12) emit_movzbl_reg(t,t);
      if(opcode2[i]==13) emit_movzwl_reg(t,t);
      if(opcode2[i]==14) emit_movsbl_reg(t,t);
      if(opcode2[i]==15) emit_movswl_reg(t,t);
    }
  }
}

void flags_assemble(int i,struct regstat *i_regs)
{
  signed char sr,t;
  sr=get_reg(i_regs->regmap,SR);
  if(opcode2[i]==8) { // CLRT/SETT
    if(opcode3[i]==0) emit_andimm(sr,~1,sr);
    if(opcode3[i]==1) emit_orimm(sr,1,sr);
  }else
  if(opcode2[i]==9) { // MOVT
    t=get_reg(i_regs->regmap,rt1[i]);
    if(t>=0)
      emit_andimm(sr,1,t);
  }
}

void complex_assemble(int i,struct regstat *i_regs)
{
  if(opcode[i]==3&&opcode2[i]==4) { // DIV1
    emit_call((pointer)div1);
  }
  if(opcode[i]==0&&opcode2[i]==15) { // MAC.L
    load_regs(i_regs->regmap_entry,i_regs->regmap,MACL,MACH,MACH);
    // If both registers are the same, the register is incremented twice.
    // Pre-increment one of the function arguments.
    #if defined(__i386__) || defined(__x86_64__)
    if(rs1[i]==rs2[i]) {emit_mov(EDI,EBP);emit_addimm(EDI,4,EDI);}
    #else
    #if defined(__arm__)
    if(rs1[i]==rs2[i]) {emit_mov(6,5);emit_addimm(6,4,6);}
    #else
    // FIXME
    assert(0);
    #endif
    #endif
/* DEBUG
  //if(i_regmap[HOST_CCREG]!=CCREG) {
    emit_loadreg(CCREG,ECX);
    emit_addimm(ECX,CLOCK_DIVIDER*(ccadj[i]),ECX);
    output_byte(0x03);
    output_modrm(1,4,ECX);
    output_sib(0,4,4);
    output_byte(4);
    emit_writeword(ECX,slave?(int)&SSH2->cycles:(int)&MSH2->cycles);
//  }*/
    emit_call((pointer)macl);
  }
  if(opcode[i]==4&&opcode2[i]==15) { // MAC.W
    load_regs(i_regs->regmap_entry,i_regs->regmap,MACL,MACH,MACH);
    // If both registers are the same, the register is incremented twice.
    // Pre-increment one of the function arguments.
    #if defined(__i386__) || defined(__x86_64__)
    if(rs1[i]==rs2[i]) {emit_mov(EDI,EBP);emit_addimm(EDI,2,EDI);}
    #else
    #if defined(__arm__)
    if(rs1[i]==rs2[i]) {emit_mov(6,5);emit_addimm(6,2,6);}
    #else
    // FIXME
    assert(0);
    #endif
    #endif
/* DEBUG
  //if(i_regmap[HOST_CCREG]!=CCREG) {
    emit_loadreg(CCREG,ECX);
    emit_addimm(ECX,CLOCK_DIVIDER*(ccadj[i]),ECX);
    output_byte(0x03);
    output_modrm(1,4,ECX);
    output_sib(0,4,4);
    output_byte(4);
    emit_writeword(ECX,slave?(int)&SSH2->cycles:(int)&MSH2->cycles);
//  }*/
    emit_call((pointer)macw);
  }
}

void ds_assemble(int i,struct regstat *i_regs)
{
  is_delayslot=1;
  switch(itype[i]) {
    case ALU:
      alu_assemble(i,i_regs);break;
    case IMM8:
      imm8_assemble(i,i_regs);break;
    case SHIFTIMM:
      shiftimm_assemble(i,i_regs);break;
    case LOAD:
      load_assemble(i,i_regs);break;
    case STORE:
      store_assemble(i,i_regs);break;
    case RMW:
      rmw_assemble(i,i_regs);break;
    case PCREL:
      pcrel_assemble(i,i_regs);break;
    case MULTDIV:
      multdiv_assemble(i,i_regs);break;
    case MOV:
      mov_assemble(i,i_regs);break;
    case EXT:
      ext_assemble(i,i_regs);break;
    case FLAGS:
      flags_assemble(i,i_regs);break;
    case COMPLEX:
      complex_assemble(i,i_regs);break;
    case SYSTEM:
    case SYSCALL:
    case UJUMP:
    case RJUMP:
    case CJUMP:
    case SJUMP:
      printf("Jump in the delay slot.  This is probably a bug.\n");
  }
  is_delayslot=0;
}

// Is the branch target a valid internal jump?
int internal_branch(int addr)
{
  if(addr&1) return 0; // Indirect (register) jump
  if(addr>=start && addr<start+slen*2-2)
  {
    return 1;
  }
  return 0;
}

#ifndef wb_invalidate
void wb_invalidate(signed char pre[],signed char entry[],u32 dirty, u64 u)
{
  int hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(pre[hr]!=entry[hr]) {
        if(pre[hr]>=0) {
          if((dirty>>hr)&1) {
            if(!((u>>pre[hr])&1)) {
              int nr;
              if((nr=get_reg(entry,pre[hr]))<0) {
                emit_storereg(pre[hr],hr);
              }else{
                // Register move would overwrite another register, so write back
                if(pre[nr]>=0)
                  if(get_reg(entry,pre[nr])>=0)
                    emit_storereg(pre[hr],hr);
              }
            }
          }
        }
      }
    }
  }
  // Move from one register to another (no writeback)
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(pre[hr]!=entry[hr]) {
        if(pre[hr]>=0&&(pre[hr]&63)<TEMPREG) {
          int nr;
          if((nr=get_reg(entry,pre[hr]))>=0) {
            if(pre[nr]<0||get_reg(entry,pre[nr])<0) {
              emit_mov(hr,nr);
            }
          }
        }
      }
    }
  }
  // Reload registers that couldn't be directly moved
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(pre[hr]!=entry[hr]) {
        if(pre[hr]>=0&&(pre[hr]&63)<TEMPREG) {
          int nr;
          if((nr=get_reg(entry,pre[hr]))>=0) {
            if(pre[nr]>=0) {
              if(get_reg(entry,pre[nr])>=0) {
                emit_loadreg(pre[hr],nr);
              }
            }
          }
        }
      }
    }
  }
}
#endif

// Load the specified registers
// This only loads the registers given as arguments because
// we don't want to load things that will be overwritten
void load_regs(signed char entry[],signed char regmap[],int rs1,int rs2,int rs3)
{
  int hr;
  if(rs1==TBIT) rs1=SR;
  if(rs2==TBIT) rs2=SR;
  if(rs3==TBIT) rs3=SR;
  // Load 32-bit regs
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG&&regmap[hr]>=0) {
      if(entry[hr]!=regmap[hr]) {
        if(regmap[hr]==rs1||regmap[hr]==rs2||regmap[hr]==rs3)
        {
          emit_loadreg(regmap[hr],hr);
        }
      }
    }
  }
}

// Load registers prior to the start of a loop
// so that they are not loaded within the loop
static void loop_preload(signed char pre[],signed char entry[])
{
  int hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(pre[hr]!=entry[hr]) {
        if(entry[hr]>=0) {
          if(get_reg(pre,entry[hr])<0) {
            assem_debug("loop preload:\n");
            //printf("loop preload: %d\n",hr);
            if(entry[hr]<TEMPREG)
            {
              emit_loadreg(entry[hr],hr);
            }
          }
        }
      }
    }
  }
}

// Generate address for load/store instruction
void address_generation(int i,struct regstat *i_regs,signed char entry[])
{
  if(itype[i]==LOAD||itype[i]==STORE||itype[i]==RMW) {
    int rs,ri;
    int rm;
    int ra;
    int agr=AGEN1+(i&1);
    int mgr=MGEN1+(i&1);
    if(itype[i]==LOAD) {
      ra=get_reg(i_regs->regmap,rt1[i]);
      if(ra<0||rt1[i]==TBIT) ra=get_reg(i_regs->regmap,-1);
      assert(ra>=0);
    }
    if(itype[i]==STORE||itype[i]==RMW) {
      ra=get_reg(i_regs->regmap,agr);
      if(ra<0) ra=get_reg(i_regs->regmap,-1);
      assert(ra>=0);
    }
    if(itype[i]==STORE) {
      rs=get_reg(i_regs->regmap,rs2[i]);
      ri=get_reg(i_regs->regmap,rs3[i]);
    }else{
      rs=get_reg(i_regs->regmap,rs1[i]);
      ri=get_reg(i_regs->regmap,rs2[i]);
    }
    rm=get_reg(i_regs->regmap,MOREG);
    if(rm<0) rm=get_alt_reg(i_regs->regmap,-1);
    if(ra>=0) {
      int offset=imm[i];
      int c;
      u32 constaddr;
      if(addrmode[i]==DUALIND||addrmode[i]==GBRIND) {
        c=(i_regs->wasdoingcp>>rs)&(i_regs->wasdoingcp>>ri)&1;
        constaddr=cpmap[i][rs]+cpmap[i][ri];
      }else{
        c=(i_regs->wasdoingcp>>rs)&1;
        constaddr=cpmap[i][rs]+offset;
        if(addrmode[i]==POSTINC) constaddr-=1<<((opcode[i]==4)?2:(opcode2[i]&3));
      }
      if(addrmode[i]==PREDEC&&!c) {
        if(rt1[i]!=rs1[i]) emit_addimm(rs,-(1<<((opcode[i]==4)?2:(opcode2[i]&3))),rs);
        else offset=-(1<<((opcode[i]==4)?2:(opcode2[i]&3)));
      }
      if(rs<0) {
        if(itype[i]==LOAD) {
          if(!entry||entry[ra]!=rs1[i])
            emit_loadreg(rs1[i],ra);
        }
        if(itype[i]==STORE) {
          if(!entry||entry[ra]!=rs2[i])
            emit_loadreg(rs2[i],ra);
        }
        //if(!entry||entry[ra]!=rs1[i])
        //  printf("poor load scheduling!\n");
      }
      else if(c) {
        // Stores to memory go thru the mapper to detect self-modifying
        // code, loads don't.
        if(rm>=0) {
          if(!entry||entry[rm]!=mgr) {
            if(itype[i]==STORE) {
              if(can_direct_write(constaddr))
                generate_map_const(constaddr,rm);
            }
            if(itype[i]==RMW) {
              generate_map_const(constaddr,rm);
            }
          }
        }
        if((opcode2[i]&3)==0||itype[i]==RMW) constaddr^=1; // byteswap for little-endian
        if(rs1[i]!=rt1[i]||itype[i]!=LOAD||addrmode[i]==DUALIND||addrmode[i]==GBRIND) {
          if(!entry||entry[ra]!=agr) {
            #ifdef HOST_IMM_ADDR32
            if(itype[i]==RMW || (itype[i]==STORE && can_direct_write(constaddr)))
            #endif
            {
              if(itype[i]==LOAD&&can_direct_read(constaddr))
                emit_movimm(map_address(constaddr),ra);
              else
                emit_movimm(constaddr,ra);
            }
          } // else did it in the previous cycle
        } // else load_consts already did it
      }
      if(!c) {
        if(rs>=0) {
          if(addrmode[i]==DUALIND||addrmode[i]==GBRIND)
            emit_add(rs,ri,ra);
          else
            if(offset) emit_addimm(rs,offset,ra);
        }else{
          if(addrmode[i]==DUALIND||addrmode[i]==GBRIND)
            emit_add(ra,ri,ra);
          else
            if(offset) emit_addimm(ra,offset,ra);
        }
      }
    }
  }
  // Preload constants for next instruction
  if(itype[i+1]==LOAD||itype[i+1]==STORE||itype[i+1]==RMW) {
    int agr,ra,rm;
    #ifndef HOST_IMM_ADDR32
    // Mapper entry
    agr=MGEN1+((i+1)&1);
    rm=get_reg(i_regs->regmap,agr);
    if(rm>=0) {
      int rs,ri;
      if(itype[i+1]==STORE) {
        rs=get_reg(regs[i+1].regmap,rs2[i+1]);
        ri=get_reg(regs[i+1].regmap,rs3[i+1]);
      }else{
        rs=get_reg(regs[i+1].regmap,rs1[i+1]);
        ri=get_reg(regs[i+1].regmap,rs2[i+1]);
      }
      //int rm=get_reg(i_regs->regmap,MOREG);
      int offset=imm[i+1];
      int c;
      u32 constaddr;
      if(addrmode[i+1]==DUALIND||addrmode[i+1]==GBRIND) {
        c=(regs[i+1].wasdoingcp>>rs)&(regs[i+1].wasdoingcp>>ri)&1;
        constaddr=cpmap[i+1][rs]+cpmap[i+1][ri];
      }else{
        c=(regs[i+1].wasdoingcp>>rs)&1;
        constaddr=cpmap[i+1][rs]+offset;
        if(addrmode[i+1]==POSTINC) constaddr-=1<<((opcode[i+1]==4)?2:(opcode2[i+1]&3));
      }
      if((opcode2[i+1]&3)==0||itype[i+1]==RMW) constaddr^=1; // byteswap for little-endian
      if(c) {
        // Stores to memory go thru the mapper to detect self-modifying
        // code, loads don't.
        if(itype[i+1]==STORE) {
          if(can_direct_write(constaddr))
            generate_map_const(constaddr,rm);
        }
        if(itype[i+1]==RMW) {
          generate_map_const(constaddr,rm);
        }
      }
    }
    #endif
    // Actual address
    agr=AGEN1+((i+1)&1);
    ra=get_reg(i_regs->regmap,agr);
    if(ra>=0) {
      int c;
      int offset;
      int rs,ri;
      u32 constaddr;
      if(itype[i+1]==STORE) {
        rs=get_reg(regs[i+1].regmap,rs2[i+1]);
        ri=get_reg(regs[i+1].regmap,rs3[i+1]);
      }else{
        rs=get_reg(regs[i+1].regmap,rs1[i+1]);
        ri=get_reg(regs[i+1].regmap,rs2[i+1]);
      }
      offset=imm[i+1];
      if(addrmode[i+1]==DUALIND||addrmode[i+1]==GBRIND) {
        c=(regs[i+1].wasdoingcp>>rs)&(regs[i+1].wasdoingcp>>ri)&1;
        constaddr=cpmap[i+1][rs]+cpmap[i+1][ri];
      }else{
        c=(regs[i+1].wasdoingcp>>rs)&1;
        constaddr=cpmap[i+1][rs]+offset;
        if(addrmode[i+1]==POSTINC) constaddr-=1<<((opcode[i+1]==4)?2:(opcode2[i+1]&3));
      }
      if((opcode2[i+1]&3)==0||itype[i+1]==RMW) constaddr^=1; // byteswap for little-endian
      if(c&&(rs1[i+1]!=rt1[i+1]||itype[i+1]!=LOAD||addrmode[i+1]==DUALIND||addrmode[i+1]==GBRIND)) {
      //if(c&&(rs1[i+1]!=rt1[i+1]||itype[i+1]!=LOAD)) {
        #ifdef HOST_IMM_ADDR32
        if(itype[i+1]==RMW || (itype[i+1]==STORE && can_direct_write(constaddr)))
        #endif
        {
          if(itype[i+1]==LOAD&&can_direct_read(constaddr))
            emit_movimm(map_address(constaddr),ra);
          else
            emit_movimm(constaddr,ra);
        }
      }
    }
  }
}

int get_final_value(int hr, int i, int *value)
{
  int reg=regs[i].regmap[hr];
  while(i<slen-1) {
    if(regs[i+1].regmap[hr]!=reg) break;
    if(!((regs[i+1].isdoingcp>>hr)&1)) break;
    if(bt[i+1]) break;
    i++;
  }
  if(i<slen-1) {
    if(itype[i]==UJUMP||itype[i]==RJUMP||itype[i]==CJUMP||itype[i]==SJUMP) {
      *value=cpmap[i][hr];
      return 1;
    }
    if(!bt[i+1]) {
      if(itype[i+1]==UJUMP||itype[i+1]==RJUMP||itype[i+1]==SJUMP) {
        // Load in delay slot, out-of-order execution
        if(itype[i+2]==LOAD&&rs1[i+2]==reg&&rt1[i+2]==reg&&((regs[i+1].wasdoingcp>>hr)&1))
        {
          if(addrmode[i+2]==DUALIND||addrmode[i+2]==GBRIND) {
            *value=cpmap[i][hr];
            return 1;
          }
          // Don't load address if can_direct_read and HOST_IMM_ADDR32
          #ifdef HOST_IMM_ADDR32
          if(can_direct_read(cpmap[i][hr]+imm[i+2])) return 0;
          #endif
          // Precompute load address
          *value=cpmap[i][hr]+imm[i+2];
          if(can_direct_read(*value)) *value=map_address(*value);
          if((opcode2[i+2]&3)==0) *value^=1; // byteswap for little-endian
          return 1;
        }
      }
      if(itype[i+1]==LOAD&&rs1[i+1]==reg&&rt1[i+1]==reg)
      {
        if(addrmode[i+1]==DUALIND||addrmode[i+1]==GBRIND) {
          *value=cpmap[i][hr];
          return 1;
        }
        // Don't load address if can_direct_read and HOST_IMM_ADDR32
        #ifdef HOST_IMM_ADDR32
        if(can_direct_read(cpmap[i][hr]+imm[i+1])) return 0;
        #endif
        // Precompute load address
        *value=cpmap[i][hr]+imm[i+1];
        if(can_direct_read(*value)) *value=map_address(*value);
        if((opcode2[i+1]&3)==0) *value^=1; // byteswap for little-endian
        //printf("c=%x imm=%x\n",(int)cpmap[i][hr],imm[i+1]);
        return 1;
      }
    }
  }
  *value=cpmap[i][hr];
  //printf("c=%x\n",(int)cpmap[i][hr]);
  if(i==slen-1) return 1;
  return !((unneeded_reg[i+1]>>reg)&1);
}

// Load registers with known constants
void load_consts(signed char pre[],signed char regmap[],int i)
{
  int hr;
  // Load 32-bit regs
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG&&regmap[hr]>=0) {
      if(i==0||!((regs[i-1].isdoingcp>>hr)&1)||pre[hr]!=regmap[hr]||bt[i]) {
        if(((regs[i].isdoingcp>>hr)&1)&&regmap[hr]<64&&regmap[hr]>=0) {
          int value;
          if(get_final_value(hr,i,&value)) {
            emit_movimm(value,hr);
          }
        }
      }
    }
  }
}
void load_all_consts(signed char regmap[],u32 dirty,int i)
{
  int hr;
  // Load 32-bit regs
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG&&regmap[hr]>=0&&((dirty>>hr)&1)) {
      if(((regs[i].isdoingcp>>hr)&1)&&regmap[hr]<64&&regmap[hr]>=0) {
        int value=cpmap[i][hr];
        emit_movimm(value,hr);
      }
    }
  }
}

// Write out all dirty registers (except cycle count)
void wb_dirtys(signed char i_regmap[],u32 i_dirty)
{
  int hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(i_regmap[hr]>=0) {
        if(i_regmap[hr]!=CCREG) {
          if((i_dirty>>hr)&1) {
            emit_storereg(i_regmap[hr],hr);
          }
        }
      }
    }
  }
}
// Write out dirty registers that we need to reload (pair with load_needed_regs)
// This writes the registers not written by store_regs_bt
void wb_needed_dirtys(signed char i_regmap[],u32 i_dirty,int addr)
{
  int hr;
  int t=(addr-start)>>1;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(i_regmap[hr]>=0) {
        if(i_regmap[hr]!=CCREG) {
          if((i_regmap[hr]==regs[t].regmap_entry[hr] && ((regs[t].dirty>>hr)&1)) || i_regmap[hr]==SR || i_regmap[hr]==15) {
            if((i_dirty>>hr)&1) {
              emit_storereg(i_regmap[hr],hr);
            }
          }
        }
      }
    }
  }
}

// Load all registers (except cycle count)
void load_all_regs(signed char i_regmap[])
{
  int hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(i_regmap[hr]>=0 && i_regmap[hr]<TEMPREG && i_regmap[hr]!=CCREG)
      {
        emit_loadreg(i_regmap[hr],hr);
      }
    }
  }
}

// Load all current registers also needed by next instruction
void load_needed_regs(signed char i_regmap[],signed char next_regmap[])
{
  int hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      if(get_reg(next_regmap,i_regmap[hr])>=0) {
        if(i_regmap[hr]>=0 && i_regmap[hr]<TEMPREG && i_regmap[hr]!=CCREG)
        {
          emit_loadreg(i_regmap[hr],hr);
        }
      }
    }
  }
}

// Load all regs, storing cycle count if necessary
void load_regs_entry(int t)
{
  int hr;
  if(is_ds[t]) emit_addimm(HOST_CCREG,CLOCK_DIVIDER,HOST_CCREG);
  else if(ccadj[t]) emit_addimm(HOST_CCREG,-ccadj[t]*CLOCK_DIVIDER,HOST_CCREG);
  if(regs[t].regmap_entry[HOST_CCREG]!=CCREG) {
    emit_storereg(CCREG,HOST_CCREG);
  }
  // Load 32-bit regs
  for(hr=0;hr<HOST_REGS;hr++) {
    if(regs[t].regmap_entry[hr]>=0&&regs[t].regmap_entry[hr]<TEMPREG) {
      if(regs[t].regmap_entry[hr]!=CCREG)
      {
        emit_loadreg(regs[t].regmap_entry[hr],hr);
      }
    }
  }
}

// Store dirty registers prior to branch
void store_regs_bt(signed char i_regmap[],u32 i_dirty,int addr)
{
  if(internal_branch(addr))
  {
    int t=(addr-start)>>1;
    int hr;
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG) {
        if(i_regmap[hr]>=0 && i_regmap[hr]!=CCREG) {
          if(i_regmap[hr]!=regs[t].regmap_entry[hr] || !((regs[t].dirty>>hr)&1) ) {
            if((i_dirty>>hr)&1) {
              if(!((unneeded_reg[t]>>i_regmap[hr])&1)) {
                emit_storereg(i_regmap[hr],hr);
              }
            }
          }
        }
      }
    }
  }
  else
  {
    // Branch out of this block, write out all dirty regs
    wb_dirtys(i_regmap,i_dirty);
  }
}

// Load all needed registers for branch target
void load_regs_bt(signed char i_regmap[],u32 i_dirty,int addr)
{
  //if(addr>=start && addr<(start+slen*4))
  if(internal_branch(addr))
  {
    int t=(addr-start)>>1;
    int hr;
    // Store the cycle count before loading something else
    if(i_regmap[HOST_CCREG]!=CCREG) {
      assert(i_regmap[HOST_CCREG]==-1);
    }
    if(regs[t].regmap_entry[HOST_CCREG]!=CCREG) {
      emit_storereg(CCREG,HOST_CCREG);
    }
    // Load 32-bit regs
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG&&regs[t].regmap_entry[hr]>=0&&regs[t].regmap_entry[hr]<TEMPREG) {
        if(i_regmap[hr]!=regs[t].regmap_entry[hr] ) {
          if(regs[t].regmap_entry[hr]!=CCREG)
          {
            emit_loadreg(regs[t].regmap_entry[hr],hr);
          }
        }
      }
    }
  }
}

int match_bt(signed char i_regmap[],u32 i_dirty,int addr)
{
  if(addr>=start && addr<start+slen*2-2)
  {
    int t=(addr-start)>>1;
    int hr;
    if(regs[t].regmap_entry[HOST_CCREG]!=CCREG) return 0;
    for(hr=0;hr<HOST_REGS;hr++)
    {
      if(hr!=EXCLUDE_REG)
      {
        if(i_regmap[hr]!=regs[t].regmap_entry[hr])
        {
          if(regs[t].regmap_entry[hr]>=0&&regs[t].regmap_entry[hr]<TEMPREG)
          {
            return 0;
          }
          else 
          if((i_dirty>>hr)&1)
          {
            if(!((unneeded_reg[t]>>i_regmap[hr])&1))
              return 0;
          }
        }
        else // Same register but is it dirty?
        if(i_regmap[hr]>=0)
        {
          if(!((regs[t].dirty>>hr)&1))
          {
            if((i_dirty>>hr)&1)
            {
              if(!((unneeded_reg[t]>>i_regmap[hr])&1))
              {
                //printf("%x: dirty no match\n",addr);
                return 0;
              }
            }
          }
        }
      }
    }
    // Delay slots require additional processing, so do not match
    if(is_ds[t]) return 0;
  }
  else
  {
    int hr;
    for(hr=0;hr<HOST_REGS;hr++)
    {
      if(hr!=EXCLUDE_REG)
      {
        if(i_regmap[hr]>=0)
        {
          if(hr!=HOST_CCREG||i_regmap[hr]!=CCREG)
          {
            if((i_dirty>>hr)&1)
            {
              return 0;
            }
          }
        }
      }
    }
  }
  return 1;
}

// Used when a branch jumps into the delay slot of another branch
void ds_assemble_entry(int i)
{
  int t=(ba[i]-start)>>1;
  if(!instr_addr[t]) instr_addr[t]=(pointer)out;
  assem_debug("Assemble delay slot at %x\n",ba[i]);
  assem_debug("<->\n");
  if(regs[t].regmap_entry[HOST_CCREG]==CCREG&&regs[t].regmap[HOST_CCREG]!=CCREG)
    wb_register(CCREG,regs[t].regmap_entry,regs[t].wasdirty);
  load_regs(regs[t].regmap_entry,regs[t].regmap,rs1[t],rs2[t],rs3[t]);
  address_generation(t,&regs[t],regs[t].regmap_entry);
  if(itype[t]==LOAD||itype[t]==STORE)
    load_regs(regs[t].regmap_entry,regs[t].regmap,MMREG,MMREG,MMREG);
  is_delayslot=0;
  switch(itype[t]) {
    case ALU:
      alu_assemble(t,&regs[t]);break;
    case IMM8:
      imm8_assemble(t,&regs[t]);break;
    case SHIFTIMM:
      shiftimm_assemble(t,&regs[t]);break;
    case LOAD:
      load_assemble(t,&regs[t]);break;
    case STORE:
      store_assemble(t,&regs[t]);break;
    case RMW:
      rmw_assemble(t,&regs[t]);break;
    case PCREL:
      pcrel_assemble(t,&regs[t]);break;
    case MULTDIV:
      multdiv_assemble(t,&regs[t]);break;
    case MOV:
      mov_assemble(t,&regs[t]);break;
    case EXT:
      ext_assemble(i,&regs[t]);break;
    case FLAGS:
      flags_assemble(i,&regs[t]);break;
    case COMPLEX:
      complex_assemble(i,&regs[t]);break;
    case SYSTEM:
    case SYSCALL:
    case UJUMP:
    case RJUMP:
    case CJUMP:
    case SJUMP:
      printf("Jump in the delay slot.  This is probably a bug.\n");
  }
  store_regs_bt(regs[t].regmap,regs[t].dirty,ba[i]+2);
  load_regs_bt(regs[t].regmap,regs[t].dirty,ba[i]+2);
  if(internal_branch(ba[i]+2))
    assem_debug("branch: internal\n");
  else
    assem_debug("branch: external\n");
  assert(internal_branch(ba[i]+2));
  add_to_linker((int)out,ba[i]+2,internal_branch(ba[i]+2));
  emit_jmp(0);
}

void do_cc(int i,signed char i_regmap[],int *adj,int addr,int taken,int invert)
{
  int count;
  int jaddr;
  int idle=0;
  if(itype[i]==RJUMP)
  {
    *adj=0;
  }
  //if(ba[i]>=start && ba[i]<(start+slen*4))
  if(internal_branch(ba[i]))
  {
    int t=(ba[i]-start)>>1;
    if(is_ds[t]) *adj=ccadj[t+1]-cycles[t]; // Branch into delay slot adds an extra cycle
    else *adj=ccadj[t];
  }
  else
  {
    *adj=0;
  }
  if(itype[i]==CJUMP) *adj-=2+cycles[i]; // Two extra cycles for taken BT/BF
  if(itype[i]==SJUMP) *adj-=1+cycles[i]+cycles[i+1]; // One extra cycle for taken BT/BF with delay slot
  count=ccadj[i]+((taken==NODS)?0:cycles[i]+cycles[i+1]);
  if(taken==TAKEN && i==(ba[i]-start)>>1 && source[i+1]==0) {
    // Idle loop
    // FIXME
    //if(count&1) emit_addimm_and_set_flags(2*(count+2),HOST_CCREG);
    idle=(int)out;
    //emit_subfrommem(&idlecount,HOST_CCREG); // Count idle cycles
    emit_andimm(HOST_CCREG,3,HOST_CCREG);
    jaddr=(int)out;
    emit_jmp(0);
  }
  else if(*adj==0||invert) {
    emit_addimm_and_set_flags(CLOCK_DIVIDER*count,HOST_CCREG);
    jaddr=(int)out;
    emit_jns(0);
  }
  else
  {
    emit_cmpimm(HOST_CCREG,-CLOCK_DIVIDER*count);
    jaddr=(int)out;
    emit_jns(0);
  }
  add_stub(CC_STUB,jaddr,idle?idle:(int)out,(*adj==0||invert||idle)?0:count,i,addr,taken,0);
}

void do_ccstub(int n)
{
  int i;
  literal_pool(256);
  assem_debug("do_ccstub %x\n",start+stubs[n][4]*2);
  set_jump_target(stubs[n][1],(pointer)out);
  i=stubs[n][4];
  if(stubs[n][6]==NODS) {
    if(itype[i+1]==LOAD&&rs1[i+1]==rt1[i+1]&&addrmode[i+1]!=DUALIND&&addrmode[i+1]!=GBRIND) {
      int hr=get_reg(regs[i].regmap,rs1[i+1]);
      if(hr>=0&&((regs[i].wasdoingcp>>hr)&1))
      {
        emit_movimm(cpmap[i][hr],hr);
      }
    }
    wb_dirtys(regs[i].regmap_entry,regs[i].dirty);
  }
  else if(stubs[n][6]!=TAKEN) {
    wb_dirtys(branch_regs[i].regmap,branch_regs[i].dirty);
  }
  else {
    if(internal_branch(ba[i]))
      wb_needed_dirtys(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
  }
  if(stubs[n][5]!=-1)
  {
    // Save PC as return address
    emit_movimm(stubs[n][5],0);
    emit_writeword(0,slave?(int)&slave_pc:(int)&master_pc);
  }
  else
  {
    // Return address is branch target
    if(itype[i]==RJUMP)
    {
      int r=get_reg(branch_regs[i].regmap,rs1[i]);
      if(rs1[i]==rt1[i+1]||rs1[i]==rt2[i+1]) {
        r=get_reg(branch_regs[i].regmap,RTEMP);
      }
      else if(opcode[i]==0&&opcode2[i]==3) {  // BSRF/BRAF
        r=get_reg(branch_regs[i].regmap,RTEMP);
      }
      else if(opcode[i]==0&&opcode2[i]==11&&opcode3[i]==2) {  // RTE
        r=get_reg(branch_regs[i].regmap,RTEMP);
      }
      emit_writeword(r,slave?(int)&slave_pc:(int)&master_pc);
    }
    else {printf("Unknown branch type in do_ccstub\n");exit(1);}
  }
  // Update cycle count
  if(stubs[n][6]==NODS) assert(regs[i].regmap[HOST_CCREG]==CCREG||regs[i].regmap[HOST_CCREG]==-1);
  else assert(branch_regs[i].regmap[HOST_CCREG]==CCREG||branch_regs[i].regmap[HOST_CCREG]==-1);
  if(stubs[n][3]) emit_addimm(HOST_CCREG,CLOCK_DIVIDER*stubs[n][3],HOST_CCREG);
  if(slave) {
    emit_load_return_address(SLAVERA_REG);
    emit_jmp((pointer)cc_interrupt);
  }
  else {
    emit_call((pointer)slave_entry);
  }
  if(stubs[n][3]&&stubs[n][6]!=NODS) emit_addimm(HOST_CCREG,-CLOCK_DIVIDER*stubs[n][3],HOST_CCREG);
  if(stubs[n][6]==TAKEN) {
    if(internal_branch(ba[i]))
      load_needed_regs(branch_regs[i].regmap,regs[(ba[i]-start)>>1].regmap_entry);
    else if(itype[i]==RJUMP) {
      if(get_reg(branch_regs[i].regmap,RTEMP)>=0)
        emit_readword(slave?(int)&slave_pc:(int)&master_pc,get_reg(branch_regs[i].regmap,RTEMP));
      else
        emit_loadreg(rs1[i],get_reg(branch_regs[i].regmap,rs1[i]));
    }
  }else if(stubs[n][6]==NOTTAKEN) {
    if(i<slen-2) load_needed_regs(branch_regs[i].regmap,regmap_pre[i+2]);
    else load_all_regs(branch_regs[i].regmap);
  }else{
    if(stubs[n][6]==NODS) {
      if(bt[i]||i==0) ccstub_return[i]=(pointer)out;
      else {
        if(stubs[n][3]) emit_addimm(HOST_CCREG,-CLOCK_DIVIDER*stubs[n][3],HOST_CCREG);
        load_all_regs(regs[i].regmap);
        load_consts(regmap_pre[i],regs[i].regmap,i);
        if(itype[i+1]==LOAD&&rs1[i+1]==rt1[i+1]&&addrmode[i+1]!=DUALIND&&addrmode[i+1]!=GBRIND) {
          int hr=get_reg(regs[i].regmap,rs1[i+1]);
          if(hr>=0&&((regs[i].wasdoingcp>>hr)&1))
          {
            #ifdef HOST_IMM_ADDR32
            if(!can_direct_read(cpmap[i][hr]+imm[i+1]))
            #endif
            {
              int value=cpmap[i][hr]+imm[i+1];
              if(can_direct_read(value)) value=map_address(value);
              if((opcode2[i+1]&3)==0) value^=1; // byteswap for little-endian
              emit_movimm(value,hr);
            }
          }
        }
        ccstub_return[i]=0;
      }
    }
    else load_all_regs(branch_regs[i].regmap);
  }
  emit_jmp(stubs[n][2]); // return address
}

add_to_linker(int addr,int target,int ext)
{
  link_addr[linkcount][0]=addr;
  link_addr[linkcount][1]=target|slave;
  link_addr[linkcount][2]=ext;  
  linkcount++;
}

void ujump_assemble(int i,struct regstat *i_regs)
{
  u64 bc_unneeded;
  int cc,adj;
  signed char *i_regmap=i_regs->regmap;
  if(i==(ba[i]-start)>>1) assem_debug("idle loop\n");
  address_generation(i+1,i_regs,regs[i].regmap_entry);
  #ifdef REG_PREFETCH
  int temp=get_reg(branch_regs[i].regmap,PTEMP);
  if(rt1[i]==PR&&temp>=0) 
  {
    int return_address=start+i*2+4;
    if(get_reg(branch_regs[i].regmap,PR)>0) 
    if(i_regmap[temp]==PTEMP) emit_movimm((int)hash_table[((return_address>>16)^return_address)&0xFFFF],temp);
  }
  #endif
  if(rt1[i]==PR) {
    if(rt1[i+1]==PR||rt2[i+1]==PR) {
      // Delay slot abuse, set PR before executing delay slot
      int rt;
      unsigned int return_address;
      rt=get_reg(regs[i].regmap,PR);
      return_address=start+i*2+4;
      assert(rt>=0);
      if(rt>=0) {
        #ifdef REG_PREFETCH
        if(temp>=0) 
        {
          if(i_regmap[temp]!=PTEMP) emit_movimm((int)hash_table[((return_address>>16)^return_address)&0xFFFF],temp);
        }
        #endif
        emit_movimm(return_address,rt); // PC into link register
      }
    }
  }
  ds_assemble(i+1,i_regs);
  bc_unneeded=regs[i].u;
  bc_unneeded|=1LL<<rt1[i];
  wb_invalidate(regs[i].regmap,branch_regs[i].regmap,regs[i].dirty,
                bc_unneeded);
  load_regs(regs[i].regmap,branch_regs[i].regmap,CCREG,CCREG,CCREG);
  if(rt1[i]==PR) {
    int rt;
    unsigned int return_address;
    assert(rs1[i+1]!=PR);
    assert(rs2[i+1]!=PR);
    assert(rs3[i+1]!=PR);
    rt=get_reg(branch_regs[i].regmap,PR);
    assem_debug("branch(%d): eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7]);
    //assert(rt>=0);
    return_address=start+i*2+4;
    if(rt>=0&&rt1[i+1]!=PR&&rt2[i+1]!=PR) {
      #ifdef USE_MINI_HT
      if(internal_branch(return_address)) {
        int temp=rt+1;
        if(temp==EXCLUDE_REG||temp>=HOST_REGS||
           branch_regs[i].regmap[temp]>=0)
        {
          temp=get_reg(branch_regs[i].regmap,-1);
        }
        #ifdef HOST_TEMPREG
        if(temp<0) temp=HOST_TEMPREG;
        #endif
        if(temp>=0) do_miniht_insert(return_address,rt,temp);
        else emit_movimm(return_address,rt);
      }
      else
      #endif
      {
        #ifdef REG_PREFETCH
        if(temp>=0) 
        {
          if(i_regmap[temp]!=PTEMP) emit_movimm((int)hash_table[((return_address>>16)^return_address)&0xFFFF],temp);
        }
        #endif
        emit_movimm(return_address,rt); // PC into link register
        #ifdef IMM_PREFETCH
        emit_prefetch(hash_table[((return_address>>16)^return_address)&0xFFFF]);
        #endif
      }
    }
  }
  cc=get_reg(branch_regs[i].regmap,CCREG);
  assert(cc==HOST_CCREG);
  store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
  #ifdef REG_PREFETCH
  if(rt1[i]==PR&&temp>=0) emit_prefetchreg(temp);
  #endif
  do_cc(i,branch_regs[i].regmap,&adj,ba[i],TAKEN,0);
  if(adj) emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]+cycles[i]+cycles[i+1]-adj),cc);
  load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
  if(internal_branch(ba[i]))
    assem_debug("branch: internal\n");
  else
    assem_debug("branch: external\n");
  if(internal_branch(ba[i])&&is_ds[(ba[i]-start)>>1]) {
    ds_assemble_entry(i);
  }
  else {
    add_to_linker((int)out,ba[i],internal_branch(ba[i]));
    emit_jmp(0);
  }
}

void rjump_assemble(int i,struct regstat *i_regs)
{
  signed char *i_regmap=i_regs->regmap;
  int temp;
  int rs,cc,adj,rh,ht;
  u64 bc_unneeded;
  rs=get_reg(branch_regs[i].regmap,rs1[i]);
  assert(rs>=0);
  if(!((i_regs->wasdoingcp>>rs)&1)) {
    if(opcode[i]==0&&opcode2[i]==3) {
      // PC-relative branch, put PC in a temporary register
      temp=get_reg(branch_regs[i].regmap,RTEMP);
      assert(temp>=0);
      if(regs[i].regmap[temp]==RTEMP)
        emit_movimm(start+i*2+4,temp);
    }
    if(rs1[i]==rt1[i+1]||rs1[i]==rt2[i+1]) {
      // Delay slot abuse, make a copy of the branch address register
      temp=get_reg(branch_regs[i].regmap,RTEMP);
      assert(temp>=0);
      assert(regs[i].regmap[temp]==RTEMP);
      if(opcode[i]==0&&opcode2[i]==3) 
        emit_add(rs,temp,temp);
      else
        emit_mov(rs,temp);
      rs=temp;
    }
  }
  address_generation(i+1,i_regs,regs[i].regmap_entry);
  #ifdef REG_PREFETCH
  if(rt1[i]==PR) 
  {
    if((temp=get_reg(branch_regs[i].regmap,PTEMP))>=0) {
      int return_address=start+i*2+4;
      if(i_regmap[temp]==PTEMP) emit_movimm((int)hash_table[((return_address>>16)^return_address)&0xFFFF],temp);
    }
  }
  #endif
  #ifdef USE_MINI_HT
  if(rs1[i]==PR) {
    int rh=get_reg(regs[i].regmap,RHASH);
    if(rh>=0) do_preload_rhash(rh);
  }
  #endif
  if(rt1[i]==PR) {
    if(rt1[i+1]==PR||rt2[i+1]==PR) {
      // Delay slot abuse, set PR before executing delay slot
      int rt,return_address;
      rt=get_reg(regs[i].regmap,rt1[i]);
      assert(rt>=0);
      if(rt>=0) {
        return_address=start+i*2+4;
        #ifdef REG_PREFETCH
        if(temp>=0) 
        {
          if(i_regmap[temp]!=PTEMP) emit_movimm((int)hash_table[((return_address>>16)^return_address)&0xFFFF],temp);
        }
        #endif
        emit_movimm(return_address,rt); // PC into link register
      }
    }
  }
  ds_assemble(i+1,i_regs);
  bc_unneeded=regs[i].u;
  bc_unneeded|=1LL<<rt1[i];
  bc_unneeded&=~(1LL<<rs1[i]);
  wb_invalidate(regs[i].regmap,branch_regs[i].regmap,regs[i].dirty,
                bc_unneeded);
  load_regs(regs[i].regmap,branch_regs[i].regmap,rs1[i],CCREG,CCREG);
  if(rt1[i]==PR) {
    int rt,return_address;
    assert(rs1[i+1]!=PR);
    assert(rs2[i+1]!=PR);
    assert(rs3[i+1]!=PR);
    rt=get_reg(branch_regs[i].regmap,rt1[i]);
    assem_debug("branch(%d): eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7]);
    if(rt>=0&&rt1[i+1]!=PR&&rt2[i+1]!=PR) {
      return_address=start+i*2+4;
      #ifdef REG_PREFETCH
      if(temp>=0) 
      {
        if(i_regmap[temp]!=PTEMP) emit_movimm((int)hash_table[((return_address>>16)^return_address)&0xFFFF],temp);
      }
      #endif
      emit_movimm(return_address,rt); // PC into link register
      #ifdef IMM_PREFETCH
      emit_prefetch(hash_table[((return_address>>16)^return_address)&0xFFFF]);
      #endif
    }
  }
  cc=get_reg(branch_regs[i].regmap,CCREG);
  assert(cc==HOST_CCREG);
  #ifdef USE_MINI_HT
  rh=get_reg(branch_regs[i].regmap,RHASH);
  ht=get_reg(branch_regs[i].regmap,RHTBL);
  if(rs1[i]==PR) {
    if(regs[i].regmap[rh]!=RHASH) do_preload_rhash(rh);
    do_preload_rhtbl(ht);
    do_rhash(rs,rh);
  }
  #endif
  if(opcode[i]==0&&opcode2[i]==11&&opcode3[i]==2) {
    // Return From Exception (RTE) - pop PC and SR from stack
    //printf("RTE\n");
    int map=get_reg(branch_regs[i].regmap,MOREG);
    int cache=get_reg(branch_regs[i].regmap,MMREG);
    int sp=get_reg(branch_regs[i].regmap,15);
    int sr=get_reg(branch_regs[i].regmap,SR);
    int jaddr=0;
    unsigned int hr;
    u32 reglist=0;
    temp=get_reg(branch_regs[i].regmap,RTEMP);
    for(hr=0;hr<HOST_REGS;hr++) {
      if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
    }
    assert(sp>=0);
    assert(sr>=0);
    assert(temp>=0);
    assert(map>=0);
    reglist&=~(1<<sr);
    reglist&=~(1<<temp);
    reglist&=~(1<<map);
    map=do_map_r(sp,-1,map,cache,0,-1,-1,0,0);
    do_map_r_branch(map,0,0,&jaddr);
    // direct load
    emit_readword_indexed_map(0,sp,map,temp);
    emit_addimm(sp,4,sp);
    emit_rorimm(temp,16,temp);
    emit_readword_indexed_map(0,sp,map,sr);
    emit_addimm(sp,4,sp);
    emit_rorimm(sr,16,sr);
    assert(jaddr);
    add_stub(LOADS_STUB,jaddr,(int)out,i,sp,(int)(&branch_regs[i]),ccadj[i],reglist);
    store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,-1);
    emit_addimm_and_set_flags(CLOCK_DIVIDER*(ccadj[i]+cycles[i]+cycles[i+1]),HOST_CCREG);
    add_stub(CC_STUB,(int)out,jump_vaddr_reg[slave][temp],0,i,-1,TAKEN,0);
    emit_jns(0);
    emit_jmp(jump_vaddr_reg[slave][temp]);
  }
  else {
    if((((i_regs->wasdoingcp>>rs)&1)&&regs[i].regmap[rs]==branch_regs[i].regmap[rs])
       ||((i_regs->isconst>>rs1[i])&1)) {
      // Do constant propagation, branch to fixed address
      u32 constaddr;
      if(((i_regs->wasdoingcp>>rs)&1)&&regs[i].regmap[rs]==branch_regs[i].regmap[rs])
        constaddr=cpmap[i][rs];
      else
        constaddr=i_regs->constmap[rs1[i]];
      if(opcode[i]==0&&opcode2[i]==3) {
        // PC-relative branch, add PC+4
        constaddr+=start+i*2+4;
      }
      assert(ba[i]==constaddr);
      store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
      //emit_addimm_and_set_flags(CLOCK_DIVIDER*(ccadj[i]+cycles[i]+cycles[i+1]),HOST_CCREG);
      //add_stub(CC_STUB,(int)out,jump_vaddr_reg[rs],0,i,-1,TAKEN,0);
      //emit_jns(0);
      do_cc(i,branch_regs[i].regmap,&adj,constaddr,TAKEN,0);
      if(adj) emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]+cycles[i]+cycles[i+1]-adj),cc);
      load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);

      if(internal_branch(constaddr)) assert(bt[(constaddr-start)>>1]);
      if(internal_branch(constaddr)&&bt[(constaddr-start)>>1]) {
        assem_debug("branch: internal (constant address)\n");
        if(is_ds[(constaddr-start)>>1]) {
          ds_assemble_entry(i);
        }
        else {
          add_to_linker((int)out,constaddr,1/*internal_branch*/);
          emit_jmp(0);
        }
      }
      else
      {
        assem_debug("branch: external (constant address)\n");
        add_to_linker((int)out,constaddr,0/*internal_branch*/);
        emit_jmp(0);
      }
    }
    else {
      ba[i]=-1;
      store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,-1);
      #ifdef REG_PREFETCH
      if(rt1[i]==PR&&temp>=0) emit_prefetchreg(temp);
      #endif
      #ifdef USE_MINI_HT
      if(rs1[i]==PR) {
        do_miniht_load(ht,rh);
      }
      #endif
      //#ifdef HOST_IMM_ADDR32 alternative using lea?
      if(rs1[i]!=rt1[i+1]&&rs1[i]!=rt2[i+1]) {
        if(opcode[i]==0&&opcode2[i]==3) {
          // PC-relative branch, add offset to PC
          temp=get_reg(branch_regs[i].regmap,RTEMP);
          if(regs[i].regmap[temp]!=RTEMP) {
            // Load PC if necessary
            emit_movimm(start+i*2+4,temp);
          }
          emit_add(rs,temp,temp);
          rs=temp;
        }
      }
      //do_cc(i,branch_regs[i].regmap,&adj,-1,TAKEN);
      //if(adj) emit_addimm(cc,2*(ccadj[i]+2-adj),cc); // ??? - Shouldn't happen
      //assert(adj==0);
      emit_addimm_and_set_flags(CLOCK_DIVIDER*(ccadj[i]+cycles[i]+cycles[i+1]),HOST_CCREG);
      add_stub(CC_STUB,(int)out,jump_vaddr_reg[slave][rs],0,i,-1,TAKEN,0);
      emit_jns(0);
      //load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,-1);
      #ifdef USE_MINI_HT
      if(rs1[i]==PR) {
        do_miniht_jump(rs,rh,ht);
      }
      else
      #endif
      {
        emit_jmp(jump_vaddr_reg[slave][rs]);
      }
    }
  }
  #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
  if(rt1[i]!=PR&&i<slen-2&&(((u32)out)&7)) emit_mov(13,13);
  #endif
}

void cjump_assemble(int i,struct regstat *i_regs)
{
  signed char *i_regmap=i_regs->regmap;
  int cc;
  int match;
  int sr;
  int unconditional=0,nop=0;
  int adj;
  int invert=0;
  int internal;
  match=match_bt(regs[i].regmap,regs[i].dirty,ba[i]);
  assem_debug("match=%d\n",match);
  internal=internal_branch(ba[i]);
  if(i==(ba[i]-start)>>1) assem_debug("idle loop\n");
  if(!match) invert=1;
  #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
  if(i>(ba[i]-start)>>1) invert=1;
  #endif
  sr=get_reg(i_regmap,SR);
  assert(sr>=0);
  cc=get_reg(i_regmap,CCREG);
  assert(cc==HOST_CCREG);
  do_cc(i,regs[i].regmap,&adj,start+i*2,NODS,invert);
  if(unconditional) 
    store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
  if(unconditional) {
    do_cc(i,branch_regs[i].regmap,&adj,ba[i],TAKEN,0);
    if(i!=(ba[i]-start)>>1 || source[i+1]!=0) {
      if(adj) emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]+2-adj),cc);
      load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
      if(internal)
        assem_debug("branch: internal\n");
      else
        assem_debug("branch: external\n");
      if(internal&&is_ds[(ba[i]-start)>>1]) {
        ds_assemble_entry(i);
      }
      else {
        add_to_linker((int)out,ba[i],internal);
        emit_jmp(0);
      }
      #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
      if(((u32)out)&7) emit_addnop(0);
      #endif
    }
  }
  else if(nop) {
    int jaddr;
    emit_addimm_and_set_flags(CLOCK_DIVIDER*(ccadj[i]+2),cc);
    jaddr=(int)out;
    emit_jns(0);
    add_stub(CC_STUB,jaddr,(int)out,0,i,start+i*2+4,NOTTAKEN,0);
  }
  else {
    pointer taken=0,nottaken=0,nottaken1=0;
    //do_cc(i,regs[i].regmap,&adj,-1,0,invert);
    if(adj&&!invert) emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]-adj),cc);
    
    //printf("branch(%d): eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7]);
    emit_testimm(sr,1);
    if(opcode2[i]==9) // BT
    {
      if(invert){
        nottaken=(pointer)out;
        emit_jeq(1);
      }else{
        add_to_linker((int)out,ba[i],internal);
        emit_jne(0);
      }
    }
    if(opcode2[i]==11) // BF
    {
      if(invert){
        nottaken=(pointer)out;
        emit_jne(1);
      }else{
        add_to_linker((int)out,ba[i],internal);
        emit_jeq(0);
      }
    }
    if(invert) {
      if(taken) set_jump_target(taken,(pointer)out);
      #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
      if(match&&(!internal||!is_ds[(ba[i]-start)>>1])) {
        if(adj) {
          emit_addimm(cc,-CLOCK_DIVIDER*adj,cc);
          add_to_linker((int)out,ba[i],internal);
        }else{
          emit_addnop(13);
          add_to_linker((int)out,ba[i],internal*2);
        }
        emit_jmp(0);
      }else
      #endif
      {
        if(adj) emit_addimm(cc,-CLOCK_DIVIDER*adj,cc);
        store_regs_bt(regs[i].regmap,regs[i].dirty,ba[i]);
        load_regs_bt(regs[i].regmap,regs[i].dirty,ba[i]);
        if(internal)
          assem_debug("branch: internal\n");
        else
          assem_debug("branch: external\n");
        if(internal&&is_ds[(ba[i]-start)>>1]) {
          ds_assemble_entry(i);
        }
        else {
          add_to_linker((int)out,ba[i],internal);
          emit_jmp(0);
        }
      }
      set_jump_target(nottaken,(pointer)out);
    }

    //if(nottaken1) set_jump_target(nottaken1,(int)out);
    if(adj&&!invert) emit_addimm(cc,CLOCK_DIVIDER*adj,cc);
  } // (!unconditional)
}

void sjump_assemble(int i,struct regstat *i_regs)
{
  signed char *i_regmap=i_regs->regmap;
  int cc;
  int adj;
  int match;
  int sr;
  int unconditional=0,nop=0;
  int invert=0;
  int internal=internal_branch(ba[i]);
  match=match_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
  assem_debug("match=%d\n",match);
  internal=internal_branch(ba[i]);
  if(i==(ba[i]-start)>>1) assem_debug("idle loop\n");
  if(!match) invert=1;
  #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
  if(i>(ba[i]-start)>>1) invert=1;
  #endif
  
  if(ooo[i]) {
    sr=get_reg(branch_regs[i].regmap,SR);
  }
  else {
    sr=get_reg(i_regmap,SR);
  }

  cc=get_reg(i_regmap,CCREG);
  assert(cc==HOST_CCREG);

  if(ooo[i]) {
    u64 bc_unneeded;
    // Out of order execution (delay slot first)
    //printf("OOOE\n");
    do_cc(i,regs[i].regmap,&adj,start+i*2,NODS,invert);
    address_generation(i+1,i_regs,regs[i].regmap_entry);
    ds_assemble(i+1,i_regs);
    bc_unneeded=regs[i].u;
    bc_unneeded&=~((1LL<<rs1[i])|(1LL<<rs2[i]));
    wb_invalidate(regs[i].regmap,branch_regs[i].regmap,regs[i].dirty,
                  bc_unneeded);
    load_regs(regs[i].regmap,branch_regs[i].regmap,CCREG,SR,SR);
    cc=get_reg(branch_regs[i].regmap,CCREG);
    assert(cc==HOST_CCREG);
    if(unconditional) 
      store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
    if(unconditional) {
      do_cc(i,branch_regs[i].regmap,&adj,ba[i],TAKEN,0);
      if(i!=(ba[i]-start)>>1 || source[i+1]!=0) {
        if(adj) emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]+2-adj),cc);
        load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
        if(internal)
          assem_debug("branch: internal\n");
        else
          assem_debug("branch: external\n");
        if(internal&&is_ds[(ba[i]-start)>>1]) {
          ds_assemble_entry(i);
        }
        else {
          add_to_linker((int)out,ba[i],internal);
          emit_jmp(0);
        }
        #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
        if(((u32)out)&7) emit_addnop(0);
        #endif
      }
    }
    else if(nop) {
      int jaddr;
      emit_addimm_and_set_flags(CLOCK_DIVIDER*(ccadj[i]+2),cc);
      jaddr=(int)out;
      emit_jns(0);
      add_stub(CC_STUB,jaddr,(int)out,0,i,start+i*2+4,NOTTAKEN,0);
    }
    else {
      pointer taken=0,nottaken=0,nottaken1=0;
      //do_cc(i,branch_regs[i].regmap,&adj,-1,0,invert);
      if(adj&&!invert) emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]-adj),cc);
      
      //printf("branch(%d): eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7]);
      assert(sr>=0);
      emit_testimm(sr,1);
      if(opcode2[i]==13) // BT/S
      {
        if(invert){
          nottaken=(pointer)out;
          emit_jeq(1);
        }else{
          add_to_linker((int)out,ba[i],internal);
          emit_jne(0);
        }
      }
      if(opcode2[i]==15) // BF/S
      {
        if(invert){
          nottaken=(pointer)out;
          emit_jne(1);
        }else{
          add_to_linker((int)out,ba[i],internal);
          emit_jeq(0);
        }
      }
      if(invert) {
        if(taken) set_jump_target(taken,(pointer)out);
        #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
        if(match&&(!internal||!is_ds[(ba[i]-start)>>1])) {
          if(adj) {
            emit_addimm(cc,-CLOCK_DIVIDER*adj,cc);
            add_to_linker((int)out,ba[i],internal);
          }else{
            emit_addnop(13);
            add_to_linker((int)out,ba[i],internal*2);
          }
          emit_jmp(0);
        }else
        #endif
        {
          if(adj) emit_addimm(cc,-CLOCK_DIVIDER*adj,cc);
          store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
          load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
          if(internal)
            assem_debug("branch: internal\n");
          else
            assem_debug("branch: external\n");
          if(internal&&is_ds[(ba[i]-start)>>1]) {
            ds_assemble_entry(i);
          }
          else {
            add_to_linker((int)out,ba[i],internal);
            emit_jmp(0);
          }
        }
        set_jump_target(nottaken,(pointer)out);
      }

      if(nottaken1) set_jump_target(nottaken1,(pointer)out);
      if(adj&&!invert) emit_addimm(cc,CLOCK_DIVIDER*adj,cc);
    } // (!unconditional)
  } // if(ooo)
  else
  {
    // In-order execution (branch first)
    //printf("IOE\n");
    u64 ds_unneeded;
    pointer taken=0,nottaken=0,nottaken1=0;
    do_cc(i,regs[i].regmap,&adj,start+i*2,NODS,1);
    if(!unconditional&&!nop) {
      //printf("branch(%d): eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7]);
      assert(sr>=0);
      emit_testimm(sr,1);
      if(opcode2[i]==13) // BT/S
      {
        nottaken=(pointer)out;
        emit_jeq(2);
      }
      if(opcode2[i]==15) // BF/S
      {
        nottaken=(pointer)out;
        emit_jne(2);
      }
    } // if(!unconditional)
    ds_unneeded=regs[i].u;
    ds_unneeded&=~((1LL<<rs1[i+1])|(1LL<<rs2[i+1])|(1LL<<rs3[i+1]));
    // branch taken
    if(!nop) {
      if(taken) set_jump_target(taken,(int)out);
      assem_debug("1:\n");
      wb_invalidate(regs[i].regmap,branch_regs[i].regmap,regs[i].dirty,
                    ds_unneeded);
      // load regs
      load_regs(regs[i].regmap,branch_regs[i].regmap,rs1[i+1],rs2[i+1],rs3[i+1]);
      address_generation(i+1,&branch_regs[i],0);
      if(itype[i+1]==COMPLEX) {
        if((opcode[i+1]|4)==4&&opcode2[i+1]==15) { // MAC.W/MAC.L
          load_regs(regs[i].regmap,branch_regs[i].regmap,MACL,MACH,MACH);
        }
      }
      load_regs(regs[i].regmap,branch_regs[i].regmap,CCREG,CCREG,CCREG);
      ds_assemble(i+1,&branch_regs[i]);
      cc=get_reg(branch_regs[i].regmap,CCREG);
      if(cc==-1) {
        emit_loadreg(CCREG,cc=HOST_CCREG);
        // CHECK: Is the following instruction (fall thru) allocated ok?
      }
      assert(cc==HOST_CCREG);
      store_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
      //do_cc(i,i_regmap,&adj,ba[i],TAKEN,0);
      assem_debug("cycle count (adj)\n");
      /*if(adj)*/ //emit_addimm(cc,CLOCK_DIVIDER*(ccadj[i]+cycles[i]+cycles[i+1]-adj),cc);
      if(adj) emit_addimm(cc,-CLOCK_DIVIDER*adj,cc);
      load_regs_bt(branch_regs[i].regmap,branch_regs[i].dirty,ba[i]);
      if(internal)
        assem_debug("branch: internal\n");
      else
        assem_debug("branch: external\n");
      if(internal&&is_ds[(ba[i]-start)>>1]) {
        ds_assemble_entry(i);
      }
      else {
        add_to_linker((int)out,ba[i],internal);
        emit_jmp(0);
      }
    }
    // branch not taken
    if(!unconditional) {
      if(nottaken1) set_jump_target(nottaken1,(int)out);
      set_jump_target(nottaken,(int)out);
      assem_debug("2:\n");
      wb_invalidate(regs[i].regmap,branch_regs[i].regmap,regs[i].dirty,
                    ds_unneeded);
      load_regs(regs[i].regmap,branch_regs[i].regmap,rs1[i+1],rs2[i+1],rs3[i+1]);
      address_generation(i+1,&branch_regs[i],0);
      if(itype[i+1]==COMPLEX) {
        if((opcode[i+1]|4)==4&&opcode2[i+1]==15) { // MAC.W/MAC.L
          load_regs(regs[i].regmap,branch_regs[i].regmap,MACL,MACH,MACH);
        }
      }
      load_regs(regs[i].regmap,branch_regs[i].regmap,CCREG,CCREG,CCREG);
      ds_assemble(i+1,&branch_regs[i]);
    }
  }
}

void system_assemble(int i,struct regstat *i_regs)
{
  signed char ccreg=get_reg(i_regs->regmap,CCREG);
  assert(ccreg==HOST_CCREG);
  assert(!is_delayslot);
  if(opcode[i]==0&&opcode2[i]==11&&opcode3[i]==1) { // SLEEP
    pointer jaddr, return_address;
    emit_addimm(HOST_CCREG,CLOCK_DIVIDER*ccadj[i],HOST_CCREG);
    jaddr=(pointer)out;
    emit_jns(0);
    return_address=(pointer)out;
    emit_zeroreg(HOST_CCREG);
    set_jump_target(jaddr,(pointer)out);
    add_stub(CC_STUB,(int)out,return_address,0,i,start+i*2,TAKEN,0);
    emit_jmp(0);
    // DEBUG: Count in multiples of three to match interpreter
    //emit_addimm_and_set_flags(CLOCK_DIVIDER*3,HOST_CCREG);
    //add_stub(CC_STUB,(int)out,return_address,0,i,start+i*2,TAKEN,0);
    //emit_jns(0);
    emit_jmp(return_address);
  }
  else {
    int b,t,sr,st,map=-1,cache=-1;
    int jaddr=0;
    unsigned int hr;
    u32 reglist=0;
    assert(opcode[i]==12); // TRAPA
    t=get_reg(i_regs->regmap,-1);
    b=get_reg(i_regs->regmap,VBR);
    sr=get_reg(i_regs->regmap,SR);
    st=get_reg(i_regs->regmap,15); // STACK
    for(hr=0;hr<HOST_REGS;hr++) {
      if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
    }
    assert(t>=0);
    assert(b>=0);
    assert(sr>=0);
    assert(st>=0);
    emit_addimm(st,-4,st);
    map=get_reg(i_regs->regmap,MOREG);
    cache=get_reg(i_regs->regmap,MMREG);
    assert(map>=0);
    reglist&=~(1<<map);
    map=do_map_w(st,st,map,cache,0,0,0);
    do_map_w_branch(map,0,0,&jaddr);
    // Save SR
    emit_rorimm(sr,16,sr);
    emit_writeword_indexed_map(sr,0,st,map,map);
    emit_rorimm(sr,16,sr);
    if(jaddr) {
      add_stub(STOREL_STUB,jaddr,(int)out,i,st,(int)i_regs,ccadj[i],reglist);
    }
    emit_addimm(st,-4,st);
    store_regs_bt(i_regs->regmap,i_regs->dirty,-1);
    emit_movimm(start+i*2+2,sr);
    emit_addimm(b,imm[i]<<2,b);
    map=do_map_w(st,st,map,cache,0,0,0);
    do_map_w_branch(map,0,0,&jaddr);
    // Save PC
    emit_rorimm(sr,16,sr);
    emit_writeword_indexed_map(sr,0,st,map,map);
    if(jaddr) {
      add_stub(STOREL_STUB,jaddr,(int)out,i,st,(int)i_regs,ccadj[i],reglist);
    }
    // Load PC
    map=do_map_r(b,b,map,cache,0,-1,-1,0,0);
    do_map_r_branch(map,0,0,&jaddr);
    emit_readword_indexed_map(0,b,map,t);
    emit_rorimm(t,16,t);
    if(jaddr)
      add_stub(LOADL_STUB,jaddr,(int)out,i,t,(int)i_regs,ccadj[i],reglist);
    if(i_regs->regmap[HOST_CCREG]!=CCREG) {
      emit_loadreg(CCREG,HOST_CCREG);
    }
    emit_addimm_and_set_flags(CLOCK_DIVIDER*(ccadj[i]+cycles[i]),HOST_CCREG);
    //add_stub(CC_STUB,(int)out,jump_vaddr_reg[slave][t],0,i,-1,TAKEN,0); // FIXME
    //emit_jns(0);
    emit_jmp(jump_vaddr_reg[slave][t]);
  }
}

void bios_assemble(int i,struct regstat *i_regs)
{
  signed char ccreg=get_reg(i_regs->regmap,CCREG);
  assert(ccreg==HOST_CCREG);
  assert(!is_delayslot);
  emit_movimm(start+i*2,0);
  //emit_writeword(0,slave?(int)&slave_pc:(int)&master_pc);
  emit_addimm(HOST_CCREG,CLOCK_DIVIDER*ccadj[i],HOST_CCREG);
  if(slave)
    emit_call((pointer)slave_handle_bios); // Probably doesn't work
  else
    emit_call((pointer)master_handle_bios);
}

// Basic liveness analysis for SH2 registers
void unneeded_registers(int istart,int iend,int r)
{
  int i;
  u64 u,uu,b,bu;
  u64 temp_u,temp_uu;
  u64 tdep;
  if(iend==slen-1) {
    u=0;
  }else{
    u=unneeded_reg[iend+1];
    u=0;
  }
  for (i=iend;i>=istart;i--)
  {
    //printf("unneeded registers i=%d (%d,%d) r=%d\n",i,istart,iend,r);
    if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==CJUMP||itype[i]==SJUMP)
    {
      if(ba[i]<start || ba[i]>=(start+slen*2))
      {
        // Branch out of this block, flush all regs
        u=0;
        branch_unneeded_reg[i]=u;
        if(itype[i]!=CJUMP) {
          // Merge in delay slot
          if(rt1[i+1]>=0) u|=1LL<<rt1[i+1];
          if(rt2[i+1]>=0) u|=1LL<<rt2[i+1];
          if(rs1[i+1]>=0) u&=~(1LL<<rs1[i+1]);
          if(rs2[i+1]>=0) u&=~(1LL<<rs2[i+1]);
          if(rs3[i+1]>=0) u&=~(1LL<<rs3[i+1]);
        }
      }
      else
      {
        if(ba[i]<=start+i*2) {
          // Backward branch
          if(itype[i]==UJUMP||itype[i]==RJUMP)
          {
            // Unconditional branch
            temp_u=0;
          } else if(itype[i]==CJUMP) {
            // Conditional branch (not taken case)
            temp_u=unneeded_reg[i+1];
          } else {
            // Conditional branch (not taken case)
            temp_u=unneeded_reg[i+2];
          }
          if(itype[i]!=CJUMP) {
            // Merge in delay slot
            if(rt1[i+1]>=0) temp_u|=1LL<<rt1[i+1];
            if(rt2[i+1]>=0) temp_u|=1LL<<rt2[i+1];
            if(rs1[i+1]>=0) temp_u&=~(1LL<<rs1[i+1]);
            if(rs2[i+1]>=0) temp_u&=~(1LL<<rs2[i+1]);
            if(rs3[i+1]>=0) temp_u&=~(1LL<<rs3[i+1]);
          }
          if(rt1[i]>=0) temp_u|=1LL<<rt1[i];
          if(rt2[i]>=0) temp_u|=1LL<<rt2[i];
          if(rs1[i]>=0) temp_u&=~(1LL<<rs1[i]);
          if(rs2[i]>=0) temp_u&=~(1LL<<rs2[i]);
          if(rs3[i]>=0) temp_u&=~(1LL<<rs3[i]);
          unneeded_reg[i]=temp_u;
          // Only go three levels deep.  This recursion can take an
          // excessive amount of time if there are a lot of nested loops.
          if(r<2) {
            unneeded_registers((ba[i]-start)>>1,i-1,r+1);
          }else{
            unneeded_reg[(ba[i]-start)>>1]=0;
          }
        } /*else*/ if(1) {
          if(itype[i]==UJUMP||itype[i]==RJUMP)
          {
            // Unconditional branch
            u=unneeded_reg[(ba[i]-start)>>1];
            // Always need stack and status in case of interrupt
            u&=~((1LL<<15)|(1LL<<SR));
            branch_unneeded_reg[i]=u;
        //u=0; // for debugging
        //branch_unneeded_reg[i]=u; // for debugging
            // Merge in delay slot
            if(rt1[i+1]>=0) u|=1LL<<rt1[i+1];
            if(rt2[i+1]>=0) u|=1LL<<rt2[i+1];
            if(rs1[i+1]>=0) u&=~(1LL<<rs1[i+1]);
            if(rs2[i+1]>=0) u&=~(1LL<<rs2[i+1]);
            if(rs3[i+1]>=0) u&=~(1LL<<rs3[i+1]);
          } else {
            // Conditional branch
            b=unneeded_reg[(ba[i]-start)>>1];
            branch_unneeded_reg[i]=b;
        //b=0; // for debugging
        //branch_unneeded_reg[i]=b; // for debugging
            // Branch delay slot
            if(itype[i]!=CJUMP) {
              if(rt1[i+1]>=0) b|=1LL<<rt1[i+1];
              if(rt2[i+1]>=0) b|=1LL<<rt2[i+1];
              if(rs1[i+1]>=0) b&=~(1LL<<rs1[i+1]);
              if(rs2[i+1]>=0) b&=~(1LL<<rs2[i+1]);
              if(rs3[i+1]>=0) b&=~(1LL<<rs3[i+1]);
            }
            u&=b;
            // Always need stack and status in case of interrupt
            u&=~((1LL<<15)|(1LL<<SR));
        //u=0; // for debugging
            if(itype[i]!=CJUMP) {
              if(i<slen-1) {
                branch_unneeded_reg[i]&=unneeded_reg[i+2];
              } else {
                branch_unneeded_reg[i]=0;
              }
            }else{
              if(i<slen) {
                branch_unneeded_reg[i]&=unneeded_reg[i+1];
              } else {
                branch_unneeded_reg[i]=0;
              }
            }
        //branch_unneeded_reg[i]=0; // for debugging
          }
        }
      }
    }
    else if(itype[i]==RJUMP && source[i]==0x2b)
    {
      // RTE instruction (return from exception)
      u=(1<<SR);
    }
    else if(itype[i]==SYSTEM && opcode[i]==12)
    {
      // TRAPA instruction (syscall)
      u=0;
    }
    //u=uu=0; // DEBUG
    //tdep=(~uu>>rt1[i])&1;
    // Written registers are unneeded
    if(rt1[i]>=0) u|=1LL<<rt1[i];
    if(rt2[i]>=0) u|=1LL<<rt2[i];
    // Accessed registers are needed
    if(rs1[i]>=0) u&=~(1LL<<rs1[i]);
    if(rs2[i]>=0) u&=~(1LL<<rs2[i]);
    if(rs3[i]>=0) u&=~(1LL<<rs3[i]);
    // Source-target dependencies
    //uu&=~(tdep<<dep1[i]);
    //uu&=~(tdep<<dep2[i]);
    if(u&(1<<SR)) u|=(1<<TBIT);
    // Save it
    unneeded_reg[i]=u;
  }
}

// Write back dirty registers as soon as we will no longer modify them,
// so that we don't end up with lots of writes at the branches.
void clean_registers(int istart,int iend,int wr)
{
  int i;
  int r;
  u32 will_dirty_i,will_dirty_next,temp_will_dirty;
  u32 wont_dirty_i,wont_dirty_next,temp_wont_dirty;
  if(iend==slen-1) {
    will_dirty_i=will_dirty_next=0;
    wont_dirty_i=wont_dirty_next=0;
  }else{
    will_dirty_i=will_dirty_next=will_dirty[iend+1];
    wont_dirty_i=wont_dirty_next=wont_dirty[iend+1];
  }
  for (i=iend;i>=istart;i--)
  {
    if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==CJUMP||itype[i]==SJUMP)
    {
      if(ba[i]<start || ba[i]>=(start+slen*2))
      {
        // Branch out of this block, flush all regs
        if(itype[i]==RJUMP||itype[i]==UJUMP)
        {
          // Unconditional branch
          will_dirty_i=0;
          wont_dirty_i=0;
          // Merge in delay slot (will dirty)
          for(r=0;r<HOST_REGS;r++) {
            if(r!=EXCLUDE_REG) {
              if((branch_regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
              if(branch_regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
              if(branch_regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
              if(regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
              if(regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
              if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                if(regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                if(branch_regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
              }
            }
          }
        }
        else
        {
          // Conditional branch
          will_dirty_i=0;
          wont_dirty_i=wont_dirty_next;
          // Merge in delay slot (will dirty)
          for(r=0;r<HOST_REGS;r++) {
            if(r!=EXCLUDE_REG) {
              if(itype[i]==SJUMP) {
                // Only conditional branches with delay slots
                if((branch_regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
                if(branch_regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
                //if((regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
                //if((regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
                if(regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
                if(regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
                if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                  if(regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                  if(branch_regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                }
              }
            }
          }
        }
        // Merge in delay slot (wont dirty)
        for(r=0;r<HOST_REGS;r++) {
          if(r!=EXCLUDE_REG) {
            if((regs[i].regmap[r]&63)==rt1[i]) wont_dirty_i|=1<<r;
            if((regs[i].regmap[r]&63)==rt2[i]) wont_dirty_i|=1<<r;
            if((regs[i].regmap[r]&63)==rt1[i+1]) wont_dirty_i|=1<<r;
            if((regs[i].regmap[r]&63)==rt2[i+1]) wont_dirty_i|=1<<r;
            if(regs[i].regmap[r]==CCREG) wont_dirty_i|=1<<r;
            if((branch_regs[i].regmap[r]&63)==rt1[i]) wont_dirty_i|=1<<r;
            if((branch_regs[i].regmap[r]&63)==rt2[i]) wont_dirty_i|=1<<r;
            if((branch_regs[i].regmap[r]&63)==rt1[i+1]) wont_dirty_i|=1<<r;
            if((branch_regs[i].regmap[r]&63)==rt2[i+1]) wont_dirty_i|=1<<r;
            if(branch_regs[i].regmap[r]==CCREG) wont_dirty_i|=1<<r;
            if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
              if(regs[i].regmap[r]==SR) wont_dirty_i|=1<<r;
              if(branch_regs[i].regmap[r]==SR) wont_dirty_i|=1<<r;
            }
            if(opcode[i]==0&&opcode2[i]==11&&opcode3[i]==2)
            {
              // RTE instruction (return from interrupt)
              if(regs[i].regmap[r]==15||branch_regs[i].regmap[r]==15) {
                wont_dirty_i|=1<<r;
                will_dirty_i|=1<<r;
              }
              if(regs[i].regmap[r]==SR||branch_regs[i].regmap[r]==SR) {
                wont_dirty_i|=1<<r;
                will_dirty_i|=1<<r;
              }
            }
          }
        }
        if(wr) {
          //#ifndef DESTRUCTIVE_WRITEBACK
          branch_regs[i].dirty&=wont_dirty_i;
          //#endif
          branch_regs[i].dirty|=will_dirty_i;
        }
      }
      else
      {
        // Internal branch
        if(ba[i]<=start+i*2) {
          // Recursively evaluate backward branches
          if(itype[i]==RJUMP||itype[i]==UJUMP)
          {
            // Unconditional branch
            temp_will_dirty=0;
            temp_wont_dirty=0;
            // Merge in delay slot (will dirty)
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                if((branch_regs[i].regmap[r]&63)==rt1[i]) temp_will_dirty|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt2[i]) temp_will_dirty|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt1[i+1]) temp_will_dirty|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt2[i+1]) temp_will_dirty|=1<<r;
                if((branch_regs[i].regmap[r]&63)>TBIT) temp_will_dirty&=~(1<<r);
                if(branch_regs[i].regmap[r]<0) temp_will_dirty&=~(1<<r);
                if(branch_regs[i].regmap[r]==CCREG) temp_will_dirty|=1<<r;
                if((regs[i].regmap[r]&63)==rt1[i]) temp_will_dirty|=1<<r;
                if((regs[i].regmap[r]&63)==rt2[i]) temp_will_dirty|=1<<r;
                if((regs[i].regmap[r]&63)==rt1[i+1]) temp_will_dirty|=1<<r;
                if((regs[i].regmap[r]&63)==rt2[i+1]) temp_will_dirty|=1<<r;
                if((regs[i].regmap[r]&63)>TBIT) temp_will_dirty&=~(1<<r);
                if(regs[i].regmap[r]<0) temp_will_dirty&=~(1<<r);
                if(regs[i].regmap[r]==CCREG) temp_will_dirty|=1<<r;
                if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                  if(regs[i].regmap[r]==SR) temp_will_dirty|=1<<r;
                  if(branch_regs[i].regmap[r]==SR) temp_will_dirty|=1<<r;
                }
              }
            }
          } else {
            // Conditional branch (not taken case)
            temp_will_dirty=will_dirty_next;
            temp_wont_dirty=wont_dirty_next;
            // Merge in delay slot (will dirty)
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                if(itype[i]==SJUMP) {
                  // Only /S instructions have a delay slot
                  if((branch_regs[i].regmap[r]&63)==rt1[i]) temp_will_dirty|=1<<r;
                  if((branch_regs[i].regmap[r]&63)==rt2[i]) temp_will_dirty|=1<<r;
                  if((branch_regs[i].regmap[r]&63)==rt1[i+1]) temp_will_dirty|=1<<r;
                  if((branch_regs[i].regmap[r]&63)==rt2[i+1]) temp_will_dirty|=1<<r;
                  if((branch_regs[i].regmap[r]&63)>TBIT) temp_will_dirty&=~(1<<r);
                  if(branch_regs[i].regmap[r]==CCREG) temp_will_dirty|=1<<r;
                  //if((regs[i].regmap[r]&63)==rt1[i]) temp_will_dirty|=1<<r;
                  //if((regs[i].regmap[r]&63)==rt2[i]) temp_will_dirty|=1<<r;
                  if((regs[i].regmap[r]&63)==rt1[i+1]) temp_will_dirty|=1<<r;
                  if((regs[i].regmap[r]&63)==rt2[i+1]) temp_will_dirty|=1<<r;
                  if((regs[i].regmap[r]&63)>TBIT) temp_will_dirty&=~(1<<r);
                  if(regs[i].regmap[r]<0) temp_will_dirty&=~(1<<r);
                  if(regs[i].regmap[r]==CCREG) temp_will_dirty|=1<<r;
                  if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                    if(regs[i].regmap[r]==SR) temp_will_dirty|=1<<r;
                    if(branch_regs[i].regmap[r]==SR) temp_will_dirty|=1<<r;
                  }
                }
              }
            }
          }
          // Merge in delay slot (wont dirty)
          for(r=0;r<HOST_REGS;r++) {
            if(r!=EXCLUDE_REG) {
              if((regs[i].regmap[r]&63)==rt1[i]) temp_wont_dirty|=1<<r;
              if((regs[i].regmap[r]&63)==rt2[i]) temp_wont_dirty|=1<<r;
              if((regs[i].regmap[r]&63)==rt1[i+1]) temp_wont_dirty|=1<<r;
              if((regs[i].regmap[r]&63)==rt2[i+1]) temp_wont_dirty|=1<<r;
              if(regs[i].regmap[r]==CCREG) temp_wont_dirty|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt1[i]) temp_wont_dirty|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt2[i]) temp_wont_dirty|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt1[i+1]) temp_wont_dirty|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt2[i+1]) temp_wont_dirty|=1<<r;
              if(branch_regs[i].regmap[r]==CCREG) temp_wont_dirty|=1<<r;
              if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                if(regs[i].regmap[r]==SR) temp_wont_dirty|=1<<r;
                if(branch_regs[i].regmap[r]==SR) temp_wont_dirty|=1<<r;
              }
            }
          }
          // Deal with changed mappings
          if(i<iend) {
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                if(regs[i].regmap[r]!=regmap_pre[i][r]) {
                  temp_will_dirty&=~(1<<r);
                  temp_wont_dirty&=~(1<<r);
                  if((regmap_pre[i][r]&63)>=0 && (regmap_pre[i][r]&63)<TBIT) {
                    temp_will_dirty|=((unneeded_reg[i]>>(regmap_pre[i][r]&63))&1)<<r;
                    temp_wont_dirty|=((unneeded_reg[i]>>(regmap_pre[i][r]&63))&1)<<r;
                  } else {
                    temp_will_dirty|=1<<r;
                    temp_wont_dirty|=1<<r;
                  }
                }
              }
            }
          }
          if(wr) {
            will_dirty[i]=temp_will_dirty;
            wont_dirty[i]=temp_wont_dirty;
            clean_registers((ba[i]-start)>>1,i-1,0);
          }else{
            // Limit recursion.  It can take an excessive amount
            // of time if there are a lot of nested loops.
            will_dirty[(ba[i]-start)>>1]=0;
            wont_dirty[(ba[i]-start)>>1]=-1;
          }
        }
        /*else*/ if(1)
        {
          if(itype[i]==RJUMP||itype[i]==UJUMP)
          {
            // Unconditional branch
            will_dirty_i=0;
            wont_dirty_i=0;
          //if(ba[i]>start+i*4) { // Disable recursion (for debugging)
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                if(branch_regs[i].regmap[r]==regs[(ba[i]-start)>>1].regmap_entry[r]) {
                  will_dirty_i|=will_dirty[(ba[i]-start)>>1]&(1<<r);
                  wont_dirty_i|=wont_dirty[(ba[i]-start)>>1]&(1<<r);
                }
                if(branch_regs[i].regmap[r]>=0) {
                  will_dirty_i|=((unneeded_reg[(ba[i]-start)>>1]>>branch_regs[i].regmap[r])&1)<<r;
                  wont_dirty_i|=((unneeded_reg[(ba[i]-start)>>1]>>branch_regs[i].regmap[r])&1)<<r;
                }
              }
            }
          //}
            // Merge in delay slot
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                if((branch_regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
                if((branch_regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
                if(branch_regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
                if(branch_regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
                if((regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
                if(regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
                if(regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
                if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                  if(regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                  if(branch_regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                }
              }
            }
          } else {
            // Conditional branch
            will_dirty_i=will_dirty_next;
            wont_dirty_i=wont_dirty_next;
          //if(ba[i]>start+i*4) { // Disable recursion (for debugging)
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                signed char target_reg=(itype[i]==CJUMP)?regs[i].regmap[r]:branch_regs[i].regmap[r];
                if(target_reg==regs[(ba[i]-start)>>1].regmap_entry[r]) {
                  will_dirty_i&=will_dirty[(ba[i]-start)>>1]&(1<<r);
                  wont_dirty_i|=wont_dirty[(ba[i]-start)>>1]&(1<<r);
                }
                else if(target_reg>=0) {
                  will_dirty_i&=((unneeded_reg[(ba[i]-start)>>1]>>target_reg)&1)<<r;
                  wont_dirty_i|=((unneeded_reg[(ba[i]-start)>>1]>>target_reg)&1)<<r;
                }
              }
            }
          //}
            // Merge in delay slot
            for(r=0;r<HOST_REGS;r++) {
              if(r!=EXCLUDE_REG) {
                if(itype[i]==SJUMP) {
                  // Only /S branches have delay slots
                  if((branch_regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
                  if((branch_regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
                  if((branch_regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
                  if((branch_regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
                  if((branch_regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
                  if(branch_regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
                  if(branch_regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
                  //if((regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
                  //if((regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
                  if((regs[i].regmap[r]&63)==rt1[i+1]) will_dirty_i|=1<<r;
                  if((regs[i].regmap[r]&63)==rt2[i+1]) will_dirty_i|=1<<r;
                  if((regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
                  if(regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
                  if(regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
                  if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                    if(regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                    if(branch_regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
                  }
                }
              }
            }
          }
          // Merge in delay slot (won't dirty)
          for(r=0;r<HOST_REGS;r++) {
            if(r!=EXCLUDE_REG) {
              if((regs[i].regmap[r]&63)==rt1[i]) wont_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt2[i]) wont_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt1[i+1]) wont_dirty_i|=1<<r;
              if((regs[i].regmap[r]&63)==rt2[i+1]) wont_dirty_i|=1<<r;
              if(regs[i].regmap[r]==CCREG) wont_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt1[i]) wont_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt2[i]) wont_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt1[i+1]) wont_dirty_i|=1<<r;
              if((branch_regs[i].regmap[r]&63)==rt2[i+1]) wont_dirty_i|=1<<r;
              if(branch_regs[i].regmap[r]==CCREG) wont_dirty_i|=1<<r;
              if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
                if(regs[i].regmap[r]==SR) wont_dirty_i|=1<<r;
                if(branch_regs[i].regmap[r]==SR) wont_dirty_i|=1<<r;
              }
            }
          }
          if(wr) {
            //#ifndef DESTRUCTIVE_WRITEBACK
            branch_regs[i].dirty&=wont_dirty_i;
            //#endif
            branch_regs[i].dirty|=will_dirty_i;
          }
        }
      }
    }
    else if(itype[i]==SYSCALL) // FIXME
    {
      // SYSCALL instruction (software interrupt)
      will_dirty_i=0;
      wont_dirty_i=0;
    }
    will_dirty_next=will_dirty_i;
    wont_dirty_next=wont_dirty_i;
    for(r=0;r<HOST_REGS;r++) {
      if(r!=EXCLUDE_REG) {
        if((regs[i].regmap[r]&63)==rt1[i]) will_dirty_i|=1<<r;
        if((regs[i].regmap[r]&63)==rt2[i]) will_dirty_i|=1<<r;
        if(rt1[i]==TBIT||rt2[i]==TBIT)
          if(regs[i].regmap[r]==SR) will_dirty_i|=1<<r;
        if((regs[i].regmap[r]&63)>TBIT) will_dirty_i&=~(1<<r);
        if(regs[i].regmap[r]<0) will_dirty_i&=~(1<<r);
        if(regs[i].regmap[r]==CCREG) will_dirty_i|=1<<r;
        if((regs[i].regmap[r]&63)==rt1[i]) wont_dirty_i|=1<<r;
        if((regs[i].regmap[r]&63)==rt2[i]) wont_dirty_i|=1<<r;
        if(rt1[i]==TBIT||rt2[i]==TBIT)
          if(regs[i].regmap[r]==SR) wont_dirty_i|=1<<r;
        if(regs[i].regmap[r]==CCREG) wont_dirty_i|=1<<r;
        if(itype[i]==COMPLEX)
        {
          if((opcode[i]|4)==4&&opcode2[i]==15) { // MAC.L/MAC.W
            if(regs[i].regmap[r]==MACL||regs[i].regmap[r]==MACH) {
              wont_dirty_i|=1<<r;
              will_dirty_i|=1<<r;
            }
          }
        }
        if(i>istart) {
          if(itype[i]!=RJUMP&&itype[i]!=UJUMP&&itype[i]!=CJUMP&&itype[i]!=SJUMP) 
          {
            // Don't store a register immediately after writing it,
            // may prevent dual-issue.
            if((regs[i].regmap[r]&63)==rt1[i-1]) wont_dirty_i|=1<<r;
            if((regs[i].regmap[r]&63)==rt2[i-1]) wont_dirty_i|=1<<r;
          }
        }
      }
    }
    // Save it
    will_dirty[i]=will_dirty_i;
    wont_dirty[i]=wont_dirty_i;
    // Mark registers that won't be dirtied as not dirty
    if(wr) {
      /*printf("wr (%d,%d) %x will:",istart,iend,start+i*4);
      for(r=0;r<HOST_REGS;r++) {
        if((will_dirty_i>>r)&1) {
          printf(" r%d",r);
        }
      }
      printf("\n");*/

      regs[i].dirty|=will_dirty_i;
      //#ifndef DESTRUCTIVE_WRITEBACK
      regs[i].dirty&=wont_dirty_i;
      if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==SJUMP)
      {
        if(i<iend-1&&itype[i]!=RJUMP&&itype[i]!=UJUMP) {
          for(r=0;r<HOST_REGS;r++) {
            if(r!=EXCLUDE_REG) {
              if(regs[i].regmap[r]==regmap_pre[i+2][r]) {
                regs[i+2].wasdirty&=wont_dirty_i|~(1<<r);
              }else {/*printf("i: %x (%d) mismatch(+2): %d\n",start+i*4,i,r);/*assert(!((wont_dirty_i>>r)&1));*/}
            }
          }
        }
      }
      else
      {
        if(i<iend) {
          for(r=0;r<HOST_REGS;r++) {
            if(r!=EXCLUDE_REG) {
              if(regs[i].regmap[r]==regmap_pre[i+1][r]) {
                regs[i+1].wasdirty&=wont_dirty_i|~(1<<r);
              }else {/*printf("i: %x (%d) mismatch(+1): %d\n",start+i*4,i,r);/*assert(!((wont_dirty_i>>r)&1));*/}
            }
          }
        }
      }
      //#endif
    }
    // Deal with changed mappings
    temp_will_dirty=will_dirty_i;
    temp_wont_dirty=wont_dirty_i;
    for(r=0;r<HOST_REGS;r++) {
      if(r!=EXCLUDE_REG) {
        int nr;
        if(regs[i].regmap[r]==regmap_pre[i][r]) {
          if(wr) {
            //#ifndef DESTRUCTIVE_WRITEBACK
            regs[i].wasdirty&=wont_dirty_i|~(1<<r);
            //#endif
            regs[i].wasdirty|=will_dirty_i&(1<<r);
          }
        }
        else if(regmap_pre[i][r]>=0&&(nr=get_reg(regs[i].regmap,regmap_pre[i][r]))>=0) {
          // Register moved to a different register
          will_dirty_i&=~(1<<r);
          wont_dirty_i&=~(1<<r);
          will_dirty_i|=((temp_will_dirty>>nr)&1)<<r;
          wont_dirty_i|=((temp_wont_dirty>>nr)&1)<<r;
          if(wr) {
            //#ifndef DESTRUCTIVE_WRITEBACK
            regs[i].wasdirty&=wont_dirty_i|~(1<<r);
            //#endif
            regs[i].wasdirty|=will_dirty_i&(1<<r);
          }
        }
        else {
          will_dirty_i&=~(1<<r);
          wont_dirty_i&=~(1<<r);
          if((regmap_pre[i][r]&63)>=0 && (regmap_pre[i][r]&63)<TBIT) {
            will_dirty_i|=((unneeded_reg[i]>>(regmap_pre[i][r]&63))&1)<<r;
            wont_dirty_i|=((unneeded_reg[i]>>(regmap_pre[i][r]&63))&1)<<r;
          } else {
            wont_dirty_i|=1<<r;
            /*printf("i: %x (%d) mismatch: %d\n",start+i*4,i,r);/*assert(!((will_dirty>>r)&1));*/
          }
        }
      }
    }
  }
}

  /* disassembly */
void disassemble_inst(int i)
{
    if (bt[i]) printf("*"); else printf(" ");
    switch(itype[i]) {
      case UJUMP:
      case CJUMP:
      case SJUMP:
        printf (" %x: %s %8x\n",start+i*2,insn[i],ba[i]);break;
      case RJUMP:
        printf (" %x: %s r%d\n",start+i*2,insn[i],rs1[i]);break;
      case IMM8:
        printf (" %x: %s #%d,r%d\n",start+i*2,insn[i],imm[i],opcode[i]==14?rt1[i]:rs1[i]);
        break;
      case LOAD:
        switch(addrmode[i])
        {
          case REGIND:
            printf (" %x: %s @r%d,r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
            break;
          case POSTINC:
            printf (" %x: %s @r%d+,r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
            break;
          case PREDEC:
            printf (" %x: %s @-r%d,r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
            break;
          case DUALIND:
            printf (" %x: %s @(R0,r%d),r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
            break;
          case GBRIND:
            printf (" %x: %s #%d,@(R0,GBR)\n",start+i*2,insn[i],imm[i]);
            break;
          case GBRDISP:
            printf (" %x: %s @(%d,GBR),r%d\n",start+i*2,insn[i],imm[i],rt1[i]);
            break;
          case REGDISP:
            printf (" %x: %s @(%d,r%d),r%d\n",start+i*2,insn[i],imm[i],rs1[i],rt1[i]);
            break;
        }
        break;
      case STORE:
        switch(addrmode[i])
        {
          case REGIND:
            printf (" %x: %s r%d,@r%d\n",start+i*2,insn[i],rs1[i],rs2[i]);
            break;
          case POSTINC:
            printf (" %x: %s r%d,@r%d+\n",start+i*2,insn[i],rs1[i],rs2[i]);
            break;
          case PREDEC:
            printf (" %x: %s r%d,@-r%d\n",start+i*2,insn[i],rs1[i],rs2[i]);
            break;
          case DUALIND:
            printf (" %x: %s r%d,@(R0,r%d)\n",start+i*2,insn[i],rs1[i],rs2[i]);
            break;
          case GBRDISP:
            printf (" %x: %s r%d,@(%d,GBR)\n",start+i*2,insn[i],rs1[i],imm[i]);
            break;
          case REGDISP:
            printf (" %x: %s r%d,@(%d,r%d)\n",start+i*2,insn[i],rs1[i],imm[i],rs2[i]);
            break;
        }
        break;
      case RMW:
        switch(addrmode[i])
        {
          case REGIND:
            printf (" %x: %s @r%d\n",start+i*2,insn[i],rs1[i]);
            break;
          case GBRIND:
            printf (" %x: %s #%d,@(R0,GBR)\n",start+i*2,insn[i],imm[i]);
            break;
        }
        break;
      case PCREL:
        printf (" %x: %s @(%x,PC),r%d (PC+%d=%x)",start+i*2,insn[i],imm[i],rt1[i],imm[i],((start+i*2+4)&(opcode[i]==9?~1:~3))+imm[i]);
        if (opcode[i]==9 && (unsigned)(i+(imm[i]>>1))<slen)
          printf(" [%x]\n",(s16)source[((start+i*2+4)+imm[i]-start)>>1]); // MOV.W
        else if (opcode[i]==13 && (unsigned)(i+(imm[i]>>1))<slen)
          printf(" [%8x]\n",(source[(((start+i*2+4)&~3)+imm[i]-start)>>1]<<16)+source[(((start+i*2+4)&~3)+imm[i]+2-start)>>1]); // MOV.L
        else printf("\n");
        if (opcode[i]==13 && (unsigned)(i+(imm[i]>>1))<slen)
          if((source[(((start+i*2+4)&~3)+imm[i]-start)>>1]<<16)+source[(((start+i*2+4)&~3)+imm[i]+2-start)>>1]-(start+i*2)<(unsigned)1024)
            printf("Within 1024\n");
        break;
      case ALU:
        if(rs1[i]<0&&rs2[i]<0) // XOR reg,reg case
          printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rt1[i],rt1[i]);          
        else if(rs2[i]>=0&&rs2[i]!=TBIT)
          printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rs2[i]);
        else if(rt1[i]!=rs1[i])
          printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
        else
          printf (" %x: %s r%d\n",start+i*2,insn[i],rs1[i]);
        break;
      case MULTDIV:
        //printf (" %x: %s rt1=%d rt2=%d\n",start+i*2,insn[i],rt1[i],rt2[i]);
        printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rs2[i]);
        break;
      case SHIFTIMM:
        if(rs2[i]>=0) printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rs2[i],imm[i]);
        else printf (" %x: %s r%d\n",start+i*2,insn[i],rt1[i],imm[i]);
        break;
      case MOV:
        printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
        break;
      case EXT:
        printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rt1[i]);
        break;
      case FLAGS:
        if(opcode2[i]==9) printf (" %x: %s r%d\n",start+i*2,insn[i],rt1[i]);
        else printf (" %x: %s\n",start+i*2,insn[i]);
        break;
      case COMPLEX:
        printf (" %x: %s r%d,r%d\n",start+i*2,insn[i],rs1[i],rs2[i]);
        break;
      case DATA:
        printf (" %x: WORD %4x\n",start+i*2,source[i]&0xFFFF); // Constant data
        break;
      default:
        //printf (" %s %8x\n",insn[i],source[i]);
        printf (" %x: %s\n",start+i*2,insn[i]);
    }
}

void sh2_dynarec_init()
{
  int n;
  //printf("Init new dynarec\n");
  out=(u8 *)BASE_ADDR;
  if (mmap (out, 1<<TARGET_SIZE_2,
            PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_FIXED | MAP_PRIVATE | MAP_ANONYMOUS,
            -1, 0) <= 0) {printf("mmap() failed\n");}
  //for(n=0x80000;n<0x80800;n++)
  //  invalid_code[n]=1;
  for(n=0;n<131072;n++)
    cached_code[n]=0;
  for(n=0;n<262144;n++)
    cached_code_words[n]=0;
  for(n=0;n<65536;n++)
    hash_table[n][0]=hash_table[n][2]=-1;
  memset(mini_ht_master,-1,sizeof(mini_ht_master));
  memset(mini_ht_slave,-1,sizeof(mini_ht_slave));
  memset(restore_candidate,0,sizeof(restore_candidate));
  copy=shadow;
  expirep=16384; // Expiry pointer, +2 blocks
  literalcount=0;
  stop_after_jal=0;
  if (mmap ((void *)0x80000000, 4194304,
            PROT_READ | PROT_WRITE,
            MAP_FIXED | MAP_PRIVATE | MAP_ANONYMOUS,
            -1, 0) <= 0) {printf("mmap() failed\n");}

  // This has to be done after BiosRom etc are allocated
  for(n=0;n<1048576;n++) {
    if(n<0x100) {
      #ifdef POINTERS_64BIT
      memory_map[n]=(((u64)BiosRom-((n<<12)&0x80000))>>2)|0x4000000000000000LL;
      #else
      memory_map[n]=(((u32)BiosRom-((n<<12)&0x80000))>>2)|0x40000000;
      #endif
    }else
    if(n>=0x0200&&n<0x0300) {
      #ifdef POINTERS_64BIT
      memory_map[n]=((u64)LowWram-((n<<12)&0xFFF00000))>>2;
      #else
      memory_map[n]=((u32)LowWram-((n<<12)&0xFFF00000))>>2;
      #endif
    }else
    if(n>=0x6000&&n<0x8000) {
      #ifdef POINTERS_64BIT
      memory_map[n]=((u64)HighWram-((n<<12)&0xFFF00000))>>2;
      #else
      memory_map[n]=((u32)HighWram-((n<<12)&0xFFF00000))>>2;
      #endif
    }else
    if(n>=0x20200&&n<0x20300) {
      #ifdef POINTERS_64BIT
      memory_map[n]=((u64)LowWram-((n<<12)&0xFFF00000))>>2;
      #else
      memory_map[n]=((u32)LowWram-((n<<12)&0xFFF00000))>>2;
      #endif
    }else
    if(n>=0x26000&&n<0x28000) {
      #ifdef POINTERS_64BIT
      memory_map[n]=((u64)HighWram-((n<<12)&0xFFF00000))>>2;
      #else
      memory_map[n]=((u32)HighWram-((n<<12)&0xFFF00000))>>2;
      #endif
    }else
      memory_map[n]=-1LL;
  }

  master_cc=slave_cc=0;
  slave_ip=(void *)0; // Slave not running, go directly to interrupt handler

  arch_init();
}

void SH2DynarecReset(SH2_struct *context) {

  //printf("SH2DynarecReset\n");
  if(context==MSH2) master_cc=0;
  if(context==SSH2) { slave_ip=(void*)0; slave_cc=0; }
}

void sh2_dynarec_cleanup()
{
  int n;
  if (munmap ((void *)BASE_ADDR, 1<<TARGET_SIZE_2) < 0) {printf("munmap() failed\n");}
  for(n=0;n<2048;n++) ll_clear(jump_in+n);
  for(n=0;n<2048;n++) ll_clear(jump_out+n);
  for(n=0;n<2048;n++) ll_clear(jump_dirty+n);
}

int sh2_recompile_block(int addr)
{
  pointer beginning;
  int hr;
  int ds=0;
  int i,j;
  int done=0;
  unsigned int type,mode,op,op2,op3;
  unsigned int lastconst=0;
  unsigned int writelimit=0xFFFFFFFF;
  u32 p_constmap[SH2_REGS];
  u32 p_isconst=0;
  int cached_addr;

  //if(Count==365117028) tracedebug=1;
  assem_debug("NOTCOMPILED: addr = %x -> %x\n", (int)addr, (int)out);
  //printf("NOTCOMPILED: addr = %x -> %x\n", (int)addr, (int)out);
  //printf("TRACE: count=%d next=%d (compile %x)\n",Count,next_interupt,addr);
  //if(debug) 
  //printf("TRACE: count=%d next=%d (checksum %x)\n",Count,next_interupt,mchecksum());
  //printf("fpu mapping=%x enabled=%x\n",(Status & 0x04000000)>>26,(Status & 0x20000000)>>29);
  /*if(Count>=312978186) {
    rlist();
  }*/
  //rlist();
  start = (u32)addr&~1;
  slave = (u32)addr&1;
  cached_addr = start&~0x20000000;
  //assert(((u32)addr&1)==0);
  if (cached_addr >= 0x00000000 && cached_addr < 0x00100000) {
    source = (u16 *)((char *)BiosRom+(start & 0x7FFFF));
    pagelimit = (addr|0x7FFFF) + 1;
  }
  else if (cached_addr >= 0x00200000 && cached_addr < 0x00300000) {
    source = (u16 *)((char *)LowWram+(start & 0xFFFFF));
    pagelimit = (addr|0xFFFFF) + 1;
  }
  else if (cached_addr >= 0x06000000 && cached_addr < 0x08000000) {
    source = (u16 *)((char *)HighWram+(start & 0xFFFFF));
    pagelimit = (addr|0xFFFFF) + 1;
  }
  else {
    printf("Compile at bogus memory address: %x \n", (int)addr);
    exit(1);
  }
  //printf("source= %x\n",(int)source);
  
  alignedsource=(void *)(((pointer)source)&~3);

  /* Pass 1: disassemble */
  /* Pass 2: register dependencies, branch targets */
  /* Pass 3: register allocation */
  /* Pass 4: branch dependencies */
  /* Pass 5: pre-alloc */
  /* Pass 6: optimize clean/dirty state */
  /* Pass 7: identify interrupt return locations */
  /* Pass 8: assembly */
  /* Pass 9: linker */
  /* Pass 10: garbage collection / free memory */

  slen=MAXBLOCK;

  //printf("addr = %x source = %x %x\n", addr,source,source[0]);
  
  /* Pass 1 disassembly */

  for(i=0;i<8;i++) {
    //printf("recent write: %x\n",recent_writes[i]);
    if(recent_writes[i]<writelimit) {
      if(recent_writes[i]>start) writelimit=recent_writes[i];
    }
  }

  for(i=0;!done;i++) {
    bt[i]=0;ooo[i]=0;op2=0;op3=0;mode=0;
    minimum_free_regs[i]=0;
    opcode[i]=op=source[i]>>12;
    strcpy(insn[i],"???"); type=NI;
    switch(op)
    {
      case 0x00:
        op2=source[i]&0xf;
        op3=(source[i]>>4)&0xf;
        switch(op2)
        {
          case 0x02: strcpy(insn[i],"STC"); type=MOV; break;
          case 0x03:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"BSRF"); type=RJUMP; break;
              case 0x02: strcpy(insn[i],"BRAF"); type=RJUMP; break;
            }
            break;
          case 0x04: strcpy(insn[i],"MOV.B"); type=STORE;mode=DUALIND; break;
          case 0x05: strcpy(insn[i],"MOV.W"); type=STORE;mode=DUALIND; break;
          case 0x06: strcpy(insn[i],"MOV.L"); type=STORE;mode=DUALIND; break;
          case 0x07: strcpy(insn[i],"MUL.L"); type=MULTDIV; break;
          case 0x08:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"CLRT"); type=FLAGS; break;
              case 0x01: strcpy(insn[i],"SETT"); type=FLAGS; break;
              case 0x02: strcpy(insn[i],"CLRMAC"); type=MULTDIV; break;
            }
            break;
          case 0x09:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"NOP"); type=NOP; break;
              case 0x01: strcpy(insn[i],"DIV0U"); type=MULTDIV; break;
              case 0x02: strcpy(insn[i],"MOVT"); type=FLAGS; break;
            }
            break;
          case 0x0A: strcpy(insn[i],"STS"); type=MOV; break;
          case 0x0B:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"RTS"); type=RJUMP; break;
              case 0x01: strcpy(insn[i],"SLEEP"); type=SYSTEM; break;
              case 0x02: strcpy(insn[i],"RTE"); type=RJUMP; break;
            }
            break;
          case 0x0C: strcpy(insn[i],"MOV.B"); type=LOAD;mode=DUALIND; break;
          case 0x0D: strcpy(insn[i],"MOV.W"); type=LOAD;mode=DUALIND; break;
          case 0x0E: strcpy(insn[i],"MOV.L"); type=LOAD;mode=DUALIND; break;
          case 0x0F: strcpy(insn[i],"MAC.L"); type=COMPLEX; break;
        }
        break;
      case 0x01: strcpy(insn[i],"MOV.L"); type=STORE;mode=REGDISP;op2=2; break;
      case 0x02:
        op2=source[i]&0xf;
        switch(op2)
        {
          case 0x00: strcpy(insn[i],"MOV.B"); type=STORE;mode=REGIND; break;
          case 0x01: strcpy(insn[i],"MOV.W"); type=STORE;mode=REGIND; break;
          case 0x02: strcpy(insn[i],"MOV.L"); type=STORE;mode=REGIND; break;
          case 0x04: strcpy(insn[i],"MOV.B"); type=STORE;mode=PREDEC; break;
          case 0x05: strcpy(insn[i],"MOV.W"); type=STORE;mode=PREDEC; break;
          case 0x06: strcpy(insn[i],"MOV.L"); type=STORE;mode=PREDEC; break;
          case 0x07: strcpy(insn[i],"DIV0S"); type=MULTDIV; break;
          case 0x08: strcpy(insn[i],"TST"); type=ALU; break;
          case 0x09: strcpy(insn[i],"AND"); type=ALU; break;
          case 0x0A: strcpy(insn[i],"XOR"); type=ALU; break;
          case 0x0B: strcpy(insn[i],"OR"); type=ALU; break;
          case 0x0C: strcpy(insn[i],"CMP/ST"); type=ALU; break;
          case 0x0D: strcpy(insn[i],"XTRCT"); type=SHIFTIMM; break;
          case 0x0E: strcpy(insn[i],"MULU.W"); type=MULTDIV; break;
          case 0x0F: strcpy(insn[i],"MULS.W"); type=MULTDIV; break;
        }
        break;
      case 0x03:
        op2=source[i]&0xf;
        switch(op2)
        {
          case 0x00: strcpy(insn[i],"CMP/EQ"); type=ALU; break;
          case 0x02: strcpy(insn[i],"CMP/HS"); type=ALU; break;
          case 0x03: strcpy(insn[i],"CMP/GE"); type=ALU; break;
          case 0x04: strcpy(insn[i],"DIV1"); type=COMPLEX; break;
          case 0x05: strcpy(insn[i],"DMULU.L"); type=MULTDIV; break;
          case 0x06: strcpy(insn[i],"CMP/HI"); type=ALU; break;
          case 0x07: strcpy(insn[i],"CMP/GT"); type=ALU; break;
          case 0x08: strcpy(insn[i],"SUB"); type=ALU; break;
          case 0x0A: strcpy(insn[i],"SUBC"); type=ALU; break;
          case 0x0B: strcpy(insn[i],"SUBV"); type=ALU; break;
          case 0x0C: strcpy(insn[i],"ADD"); type=ALU; break;
          case 0x0D: strcpy(insn[i],"DMULS.L"); type=MULTDIV; break;
          case 0x0E: strcpy(insn[i],"ADDC"); type=ALU; break;
          case 0x0F: strcpy(insn[i],"ADDV"); type=ALU; break;
        }
        break;
      case 0x04:
        op2=source[i]&0xf;
        op3=(source[i]>>4)&0xf;
        switch(op2)
        {
          case 0x00:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"SHLL"); type=SHIFTIMM; break;
              case 0x01: strcpy(insn[i],"DT"); type=ALU; break;
              case 0x02: strcpy(insn[i],"SHAL"); type=SHIFTIMM; break;
            }
            break;
          case 0x01:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"SHLR"); type=SHIFTIMM; break;
              case 0x01: strcpy(insn[i],"CMP/PZ"); type=ALU; break;
              case 0x02: strcpy(insn[i],"SHAR"); type=SHIFTIMM; break;
            }
            break;
          case 0x02: strcpy(insn[i],"STS.L"); type=STORE;mode=PREDEC; break;
          case 0x03: strcpy(insn[i],"STC.L"); type=STORE;mode=PREDEC; break;
          case 0x04:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"ROTL"); type=SHIFTIMM; break;
              case 0x02: strcpy(insn[i],"ROTCL"); type=SHIFTIMM; break;
            }
            break;
          case 0x05:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"ROTR"); type=SHIFTIMM; break;
              case 0x01: strcpy(insn[i],"CMP/PL"); type=ALU; break;
              case 0x02: strcpy(insn[i],"ROTCR"); type=SHIFTIMM; break;
            }
            break;
          case 0x06: strcpy(insn[i],"LDS.L"); type=LOAD;mode=POSTINC; break;
          case 0x07: strcpy(insn[i],"LDC.L"); type=LOAD;mode=POSTINC; break;
          case 0x08:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"SHLL2"); type=SHIFTIMM; break;
              case 0x01: strcpy(insn[i],"SHLL8"); type=SHIFTIMM; break;
              case 0x02: strcpy(insn[i],"SHLL16"); type=SHIFTIMM; break;
            }
            break;
          case 0x09:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"SHLR2"); type=SHIFTIMM; break;
              case 0x01: strcpy(insn[i],"SHLR8"); type=SHIFTIMM; break;
              case 0x02: strcpy(insn[i],"SHLR16"); type=SHIFTIMM; break;
            }
            break;
          case 0x0A: strcpy(insn[i],"LDS"); type=MOV; break;
          case 0x0B:
            switch(op3)
            {
              case 0x00: strcpy(insn[i],"JSR"); type=RJUMP; break;
              case 0x01: strcpy(insn[i],"TAS.B"); type=RMW;mode=REGIND; break;
              case 0x02: strcpy(insn[i],"JMP"); type=RJUMP; break;
            }
            break;
          case 0x0E: strcpy(insn[i],"LDC"); type=MOV; break;
          case 0x0F: strcpy(insn[i],"MAC.W"); type=COMPLEX; break;
        }
        break;
      case 0x05: strcpy(insn[i],"MOV.L"); type=LOAD;mode=REGDISP;op2=2; break;
      case 0x06:
        op2=source[i]&0xf;
        switch(op2)
        {
          case 0x00: strcpy(insn[i],"MOV.B"); type=LOAD;mode=REGIND; break;
          case 0x01: strcpy(insn[i],"MOV.W"); type=LOAD;mode=REGIND; break;
          case 0x02: strcpy(insn[i],"MOV.L"); type=LOAD;mode=REGIND; break;
          case 0x03: strcpy(insn[i],"MOV"); type=MOV; break;
          case 0x04: strcpy(insn[i],"MOV.B"); type=LOAD;mode=POSTINC; break;
          case 0x05: strcpy(insn[i],"MOV.W"); type=LOAD;mode=POSTINC; break;
          case 0x06: strcpy(insn[i],"MOV.L"); type=LOAD;mode=POSTINC; break;
          case 0x07: strcpy(insn[i],"NOT"); type=ALU; break;
          case 0x08: strcpy(insn[i],"SWAP.B"); type=ALU; break;
          case 0x09: strcpy(insn[i],"SWAP.W"); type=ALU; break;
          case 0x0A: strcpy(insn[i],"NEGC"); type=ALU; break;
          case 0x0B: strcpy(insn[i],"NEG"); type=ALU; break;
          case 0x0C: strcpy(insn[i],"EXTU.B"); type=EXT; break;
          case 0x0D: strcpy(insn[i],"EXTU.W"); type=EXT; break;
          case 0x0E: strcpy(insn[i],"EXTS.B"); type=EXT; break;
          case 0x0F: strcpy(insn[i],"EXTS.W"); type=EXT; break;
        }
        break;
      case 0x07: strcpy(insn[i],"ADD"); type=IMM8; break;
      case 0x08:
        op2=(source[i]>>8)&0xf;
        switch(op2)
        {
          case 0x00: strcpy(insn[i],"MOV.B"); type=STORE;mode=REGDISP; break;
          case 0x01: strcpy(insn[i],"MOV.W"); type=STORE;mode=REGDISP; break;
          case 0x04: strcpy(insn[i],"MOV.B"); type=LOAD;mode=REGDISP; break;
          case 0x05: strcpy(insn[i],"MOV.W"); type=LOAD;mode=REGDISP; break;
          case 0x08: strcpy(insn[i],"CMP/EQ"); type=IMM8; break;
          case 0x09: strcpy(insn[i],"BT"); type=CJUMP; break;
          case 0x0B: strcpy(insn[i],"BF"); type=CJUMP; break;
          case 0x0D: strcpy(insn[i],"BT/S"); type=SJUMP; break;
          case 0x0F: strcpy(insn[i],"BF/S"); type=SJUMP; break;
        }
        break;
      case 0x09: strcpy(insn[i],"MOV.W"); type=PCREL; break;
      case 0x0A: strcpy(insn[i],"BRA"); type=UJUMP; break;
      case 0x0B: strcpy(insn[i],"BSR"); type=UJUMP; break;
      case 0x0C:
        op2=(source[i]>>8)&0xf;
        switch(op2)
        {
          case 0x00: strcpy(insn[i],"MOV.B"); type=STORE;mode=GBRDISP; break;
          case 0x01: strcpy(insn[i],"MOV.W"); type=STORE;mode=GBRDISP; break;
          case 0x02: strcpy(insn[i],"MOV.L"); type=STORE;mode=GBRDISP; break;
          case 0x03: strcpy(insn[i],"TRAPA"); type=SYSTEM; break;
          case 0x04: strcpy(insn[i],"MOV.B"); type=LOAD;mode=GBRDISP; break;
          case 0x05: strcpy(insn[i],"MOV.W"); type=LOAD;mode=GBRDISP; break;
          case 0x06: strcpy(insn[i],"MOV.L"); type=LOAD;mode=GBRDISP; break;
          case 0x07: strcpy(insn[i],"MOVA"); type=PCREL; break;
          case 0x08: strcpy(insn[i],"TST"); type=IMM8; break;
          case 0x09: strcpy(insn[i],"AND"); type=IMM8; break;
          case 0x0A: strcpy(insn[i],"XOR"); type=IMM8; break;
          case 0x0B: strcpy(insn[i],"OR"); type=IMM8; break;
          case 0x0C: strcpy(insn[i],"TST.B"); type=LOAD;mode=GBRIND; break;
          case 0x0D: strcpy(insn[i],"AND.B"); type=RMW;mode=GBRIND; break;
          case 0x0E: strcpy(insn[i],"XOR.B"); type=RMW;mode=GBRIND; break;
          case 0x0F: strcpy(insn[i],"OR.B"); type=RMW;mode=GBRIND; break;
        }
        break;
      case 0x0D: strcpy(insn[i],"MOV.L"); type=PCREL; break;
      case 0x0E: strcpy(insn[i],"MOV"); type=IMM8; break;
      default: strcpy(insn[i],"???"); type=NI; break;
    }
    itype[i]=type;
    addrmode[i]=mode;
    opcode2[i]=op2;
    opcode3[i]=op3;
    /* Get registers/immediates */
    rs1[i]=-1;
    rs2[i]=-1;
    rs3[i]=-1;
    rt1[i]=-1;
    rt2[i]=-1;
    lt1[i]=-1;
    cycles[i]=1;
    switch(type) {
      case LOAD:
        if(mode==GBRDISP||mode==GBRIND) rs1[i]=GBR;
        else rs1[i]=(source[i]>>4)&0xf;
        if(mode==DUALIND||mode==GBRIND) rs2[i]=0;
        if(op==4) {
          // LDS/LDC
          rs1[i]=(source[i]>>8)&0xf;
          if(op2==6) rt1[i]=((source[i]>>4)&0xf)+MACH;
          if(op2==7) {rt1[i]=((source[i]>>4)&0xf)+SR;cycles[i]=3;}
          if(rt1[i]==SR) rt2[i]=TBIT;
        }
        else if(op==8)
          rt1[i]=0; // (@disp,rm),r0
        else if(op==12) {
          if(op2!=12)
            rt1[i]=0; // (@disp,GBR),r0
          else {
            imm[i]=(unsigned int)((unsigned char)source[i]);
            rt1[i]=TBIT; // TST.B
            cycles[i]=3;
          }
        }
        else {
          rt1[i]=(source[i]>>8)&0xf;
        }
        if(mode==REGDISP) {
          imm[i]=(unsigned int)source[i]&0xF;
          if(op==5) imm[i]<<=2; // MOV.L
          if(op==8&&op2==5) imm[i]<<=1; // MOV.W
        }
        else if(mode==GBRDISP) {
          imm[i]=(unsigned int)((unsigned char)source[i])<<(op2&3);
        }
        else if(mode!=GBRIND) imm[i]=0;
        if(mode==POSTINC) rt2[i]=rs1[i];
        break;
      case STORE:
        if(op==4) {
          // STS/STC
          if(op2==2) rs1[i]=((source[i]>>4)&0xf)+MACH;
          if(op2==3) {rs1[i]=((source[i]>>4)&0xf)+SR;cycles[i]=2;}
          if(rs1[i]==SR) rs3[i]=TBIT;
        }
        else
        if(op==8) 
          rs1[i]=0; // r0,(@disp,rn)
        else if(op==12) 
          rs1[i]=0; // r0,(@disp,GBR)
        else
          rs1[i]=(source[i]>>4)&0xf;
        if(mode==GBRDISP) rs2[i]=GBR;
        else if(op==8) rs2[i]=(source[i]>>4)&0xf; // r0,(@disp,rn)
        else rs2[i]=(source[i]>>8)&0xf;
        if(mode==DUALIND) rs3[i]=0;
        if(mode==REGDISP) {
          imm[i]=(unsigned int)source[i]&0xF;
          if(op==1) imm[i]<<=2; // MOV.L
          if(op==8&&op2==1) imm[i]<<=1; // MOV.W
        }
        else if(mode==GBRDISP) {
          imm[i]=(unsigned int)((unsigned char)source[i])<<(op2&3);
        }
        else imm[i]=0;
        if(mode==PREDEC) rt1[i]=rs2[i];
        if( (mode==DUALIND&&((p_isconst>>rs2[i])&(p_isconst>>rs3[i])&1)) ||
            (mode!=DUALIND&&((p_isconst>>rs2[i])&1)) )
        {
          u32 addr;
          if(mode==DUALIND) addr=p_constmap[rs2[i]]+p_constmap[rs3[i]];
          if(mode==REGDISP||mode==GBRDISP) addr=p_constmap[rs2[i]]+imm[i];
          if(mode==PREDEC) addr=(p_constmap[rs2[i]]-=4);
          if(mode==REGIND) addr=p_constmap[rs2[i]];
          if(addr>start+i*2&&addr<writelimit) writelimit=addr;
          assem_debug("Instruction at %x possibly writes %x (limit=%x)\n",start+i*2,addr,writelimit);
        }
        break;
      case RMW:
        if(op==4) // TAS.B
        {
          rs1[i]=(source[i]>>8)&0xf;
          rt1[i]=TBIT;
          imm[i]=0;
          cycles[i]=4;
        }
        if(op==12) // AND.B/XOR.B/OR.B
        {
          rs1[i]=GBR;
          rs2[i]=0;
          imm[i]=(unsigned int)((unsigned char)source[i]);
          cycles[i]=3;
        }
        break;
      case PCREL:
        imm[i]=(signed int)((unsigned char)source[i]);
        if(op==12) rt1[i]=0; // MOVA
        else rt1[i]=(source[i]>>8)&0xf;
        if(op==9) imm[i]<<=1; // MOV.W
        else imm[i]<<=2;
        // Extend block to include consts
        // FIXME: Don't go past limit
        if (op==9 && lastconst < (start+i*2+4)+imm[i]) // MOV.W
          lastconst = (start+i*2+4)+imm[i];
        if (op==13 && lastconst < ((start+i*2+4)&~3)+imm[i]+2) // MOV.L
          lastconst = ((start+i*2+4)&~3)+imm[i]+2;
        //printf("lastconst=%x\n",lastconst);
        break;
      case MOV:
        if(op==6) {
          rs1[i]=(source[i]>>4)&0xf;
          rt1[i]=(source[i]>>8)&0xf;
        }
        if(op==0) { // STC/STS
          if(op2==2) rs1[i]=((source[i]>>4)&0xf)+SR; //STC
          if(op2==10) rs1[i]=((source[i]>>4)&0xf)+MACH; //STS
          rt1[i]=(source[i]>>8)&0xf;
          if(rs1[i]==SR) rs2[i]=TBIT; // For liveness analysis
        }
        if(op==4) { // LDC/LDS
          if(op2==14) rt1[i]=((source[i]>>4)&0xf)+SR; //LDC
          if(op2==10) rt1[i]=((source[i]>>4)&0xf)+MACH; //LDS
          rs1[i]=(source[i]>>8)&0xf;
          if(rt1[i]==SR) rt2[i]=TBIT; // For liveness analysis
        }
        break;
      case IMM8:
        if(op==8) { // CMP/EQ r0
          rs1[i]=0;
          rt1[i]=TBIT;
          imm[i]=(signed int)((signed char)source[i]);
        }else
        if(op==12) {
          rs1[i]=0;
          if(op2==8)
            rt1[i]=TBIT; // TST
          else
            rt1[i]=0; // AND/XOR/OR
          imm[i]=(unsigned int)((unsigned char)source[i]);
        }else{ // ADD/MOV
          if(op==7) rs1[i]=(source[i]>>8)&0xf; // ADD
          rt1[i]=(source[i]>>8)&0xf;
          imm[i]=(signed int)((signed char)source[i]);
        }
        break;
      case FLAGS:
        if(op2==8) rt1[i]=TBIT; // CLRT/SETT
        if(op2==9) {rs1[i]=TBIT;rt1[i]=(source[i]>>8)&0xf;} // MOVT
        break;
      case ALU:
        if(op==2) {
          if(op2==8||op2==12) { // TST or CMP/STR
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=TBIT;
          }
          else
          { // AND/OR/XOR
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=(source[i]>>8)&0xf;
            if(op2==10&&rs1[i]==rs2[i]) {
              rs1[i]=-1;rs2[i]=-1; // Optimize XOR reg,reg
            }
          }
        }
        if(op==3) {
          if(op2<8) { // CMP
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=TBIT;
          }
          else
          { // ADD/SUB
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=(source[i]>>8)&0xf;
            if(op2==10||op2==14) rs3[i]=TBIT; // ADDC/SUBC read T bit
            if(op2!=8&&op2!=12) // ADDC/ADDV/SUBC/SUBV set T bit
              rt2[i]=TBIT;
          }
        }
        if(op==4) { // DT and compare with zero
          rs1[i]=(source[i]>>8)&0xf;
          if(op2==0) rt1[i]=(source[i]>>8)&0xf; // DT
          rt2[i]=TBIT;
        }
        if(op==6) { // NOT/NEG/NEGC/SWAP
          rs1[i]=(source[i]>>4)&0xf;
          rt1[i]=(source[i]>>8)&0xf;
          if(op2==10)
            rs2[i]=rt2[i]=TBIT; // NEGC sets T bit
        }
        break;
      case EXT:
        rs1[i]=(source[i]>>4)&0xf;
        rt1[i]=(source[i]>>8)&0xf;
        break;
      case MULTDIV:
        if(op==0) {
          if(op2==7) // MUL.L
          {
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=MACL;
            cycles[i]=2;
          }
          if(op2==8) // CLRMAC
          {
            rt1[i]=MACH;
            rt2[i]=MACL;
          }
          if(op2==9) // DIV0U
          {
            rs1[i]=SR;
            rt1[i]=SR;
            rt2[i]=TBIT;
          }
        }
        if(op==2) {
          if(op2==7) // DIV0S
          {
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rs3[i]=SR;
            rt1[i]=SR;
            rt2[i]=TBIT;
          }
          if(op2==14) // MULU.W
          {
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=MACL;
          }
          if(op2==15) // MULS.W
          {
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=MACL;
          }
        }
        if(op==3) {
          if(op2==5) // DMULU.L
          {
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=MACH;
            rt2[i]=MACL;
            cycles[i]=2;
          }
          if(op2==13) // DMULS.L
          {
            rs1[i]=(source[i]>>4)&0xf;
            rs2[i]=(source[i]>>8)&0xf;
            rt1[i]=MACH;
            rt2[i]=MACL;
            cycles[i]=2;
          }
        }
        break;
      case SHIFTIMM:
        rs1[i]=(source[i]>>8)&0xf;
        rt1[i]=(source[i]>>8)&0xf;
        if(op==4) {
          if(op2<6) rt2[i]=TBIT;
          if(op2==4||op2==5) {if(op3==2) rs2[i]=TBIT;} // ROTCL/ROTCR
        }
        if(op==2&op2==13) { // XTRCT
          rs1[i]=(source[i]>>4)&0xf;
          rs2[i]=(source[i]>>8)&0xf;
        }
        break;
      case UJUMP:
        rs2[i]=CCREG;
        if(op==11) rt1[i]=PR; // BSR
        cycles[i]=2;
        break;
      case RJUMP:
        rs1[i]=(source[i]>>8)&0xf;
        if (op==0&&op2==11&&op3==0) rs1[i]=PR; // RTS
        if ((op==0&&op2==3)||(op==4&&op2==11)) { // BSRF/JSR
          if(op3==0) rt1[i]=PR;
        }
        rs2[i]=CCREG;
        cycles[i]=2;
        if(op==0&&op2==11&&op3==2) { // RTE
          rs1[i]=15; // Stack pointer
          rs2[i]=CCREG;
          rt1[i]=SR;
          rt2[i]=15;
          cycles[i]=4;
        }
        break;
      case CJUMP:
        rs1[i]=TBIT;
        rs2[i]=CCREG;
        //cycles[i]=3; // Will be adjusted if branch is taken
        break;
      case SJUMP:
        rs1[i]=TBIT;
        rs2[i]=CCREG;
        //cycles[i]=2; // Will be adjusted if branch is taken
        break;
      case SYSTEM:
        if(op2==11&&op3==2) { // RTE
          rs1[i]=15; // Stack pointer
          rs2[i]=CCREG;
          rt1[i]=SR;
          rt2[i]=TBIT;
          cycles[i]=4;
        }
        else if(op==12) { // TRAPA
          rs1[i]=SR; // Status/flags
          //rs2[i]=CCREG;
          rs2[i]=VBR;
          rs3[i]=15; // Stack pointer
          imm[i]=(unsigned int)((unsigned char)source[i]);
          cycles[i]=8;
        }
        else { // SLEEP
          rs2[i]=CCREG;
          cycles[i]=8;
        }
        break;
      case COMPLEX:
        if(op==3&&op2==4) { // DIV1
          rs1[i]=(source[i]>>4)&0xf;
          rs2[i]=(source[i]>>8)&0xf;
          rs3[i]=SR;
          rt1[i]=(source[i]>>8)&0xf;
          rt2[i]=SR;
        }
        if(op==0&&op2==15) { // MAC.L
          rs1[i]=(source[i]>>4)&0xf;
          rs2[i]=(source[i]>>8)&0xf;
          rs3[i]=SR;
          rt1[i]=(source[i]>>4)&0xf;
          rt2[i]=(source[i]>>8)&0xf;
          cycles[i]=3;
        }
        if(op==4&&op2==15) { // MAC.W
          rs1[i]=(source[i]>>4)&0xf;
          rs2[i]=(source[i]>>8)&0xf;
          rs3[i]=SR;
          rt1[i]=(source[i]>>4)&0xf;
          rt2[i]=(source[i]>>8)&0xf;
          cycles[i]=3;
        }
        break;
    }
    // Do preliminary constant propagation
    do_consts(i,&p_isconst,p_constmap);
    /* Calculate branch target addresses */
    if(type==UJUMP)
      ba[i]=start+i*2+4+((((signed int)source[i])<<20)>>19);
    else if(type==CJUMP||type==SJUMP)
      ba[i]=start+i*2+4+((((signed int)source[i])<<24)>>23);
    else 
    {
      ba[i]=-1;
      if(type==RJUMP) {
        if(op!=0||op2!=11||op3!=2) { // !RTE
          if((p_isconst>>rs1[i])&1)
          {
            u32 constaddr=p_constmap[rs1[i]];
            if(op==0&&op2==3) {
              // PC-relative branch, add PC+4
              constaddr+=start+i*2+4;
            }
            ba[i]=constaddr;
          }
        }
      }
    }

    // If the branch target was previously identified as data, back up
    if(ba[i]>start&&ba[i]<start+i*2) {
      //assert(itype[(ba[i]-start)>>1]!=DATA);
      if(itype[(ba[i]-start)>>1]==DATA||itype[(ba[i]+2-start)>>1]==DATA) {
        //printf("back up and redecode %x\n",ba[i]);
        i=(ba[i]-2-start)>>1;
        continue;
      }
    }
    /* Is this the end of the block? */
    if(i>0&&(itype[i-1]==UJUMP||itype[i-1]==RJUMP)) {
      if(rt1[i-1]!=PR) { // Continue past subroutine call (BSR/JSR)
        unsigned int firstbt=0xFFFFFFFF;
        done=1;
        // Find next branch target (if any)
        for(j=i-1;j>=0;j--)
        {
          if(ba[j]>start+i*2-2&&ba[j]<firstbt) firstbt=ba[j];
        }
        // See if there are any backward branches following that one
        //printf("firstbt=%x diff=%d\n",firstbt,firstbt-(start+i*2));
        if(firstbt-(start+i*2)<(unsigned)4096) {
          u32 branch_addr;
          for(j=(firstbt-start)>>1;j<MAXBLOCK;j++) {
            if((source[j]&0xF900)==0x8900) { //BT(S)/BF(S)
              branch_addr=start+j*2+4+((((signed int)source[j])<<24)>>23);
              if(branch_addr>start+i*2&&branch_addr<firstbt) firstbt=branch_addr;
              //printf("firstbt=%x\n",firstbt);
            }
            if((source[j]&0xE000)==0xA000) { //BRA/BSR
              branch_addr=start+j*2+4+((((signed int)source[j])<<20)>>19);
              if(branch_addr>start+i*2&&branch_addr<firstbt) firstbt=branch_addr;
              //printf("firstbt=%x\n",firstbt);
              if((source[j]&0xF000)==0xA000) break; //BRA (stop after unconditional branch)
            }
            if((source[j]&0xF007)==0x0003) break; //BRAF/BSRF/RTS/RTE (stop after unconditional branch)
          }
        }
        // Skip constant pool
        // FIXME: check pagelimit
        while(start+i*2+2<=lastconst&&start+i*2+2<firstbt&&start+i*2+1024<writelimit&&i<MAXBLOCK-1) {
          i++;
          rs1[i]=-1;
          rs2[i]=-1;
          rs3[i]=-1;
          rt1[i]=-1;
          rt2[i]=-1;
          lt1[i]=-1;
          itype[i]=DATA;
          bt[i]=0;ba[i]=-1;
          ooo[i]=0;cycles[i]=0;is_ds[i]=0;
        }
        // Does the block continue due to a branch?
        if(firstbt==start+i*2) done=j=0; // Branch into delay slot
        if(firstbt==start+i*2+2) done=j=0;
        if(firstbt==start+i*2+4) done=j=0; // CHECK: Is this useful?
      }
      else {
        if(stop_after_jal) done=1;
        // Stop on BREAK
        //if((source[i+1]&0xfc00003f)==0x0d) done=1;
      }
      // Don't recompile stuff that's already compiled
      if(check_addr(start+i*2+2+slave)) done=1;
      // Don't get too close to the limit
      if(i>MAXBLOCK/2) done=1;
    }
    if(yabsys.emulatebios) {
      if(start+i*2>=0x200&&start+i*2<0x600) {
        strcpy(insn[i],"(BIOS)");
        itype[i]=BIOS;
        done=1;
      }
    }
    //if(i>0&&itype[i-1]==SYSCALL&&stop_after_jal) done=1;
    //if(i>0&&itype[i-1]==SYSTEM&&source[i-1]==0x002B) done=1; // RTE
    //assert(i<MAXBLOCK-1);
    if(start+i*2==pagelimit-2) done=1;
    assert(start+i*2<pagelimit);
    if (i==MAXBLOCK-1) done=1;
    // Stop if we're compiling junk
    if(itype[i]==NI&&opcode[i]==0x11) {
      done=stop_after_jal=1;
      printf("Disabled speculative precompilation\n");
    }
    if(!done&&i<MAXBLOCK-1) {
      // Constant propagation
      //if(i>0&&(itype[i-1]==UJUMP||itype[i-1]==RJUMP)) isconst[i+1]=0;
      if(i>0&&(itype[i-1]==UJUMP||itype[i-1]==RJUMP)) p_isconst=0;
    }
  }
  slen=i;
  assert(slen>0);

  /* Pass 2 - Register dependencies and branch targets */

  // Flag branch targets
  for(i=0;i<slen;i++)
  {
    if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==CJUMP||itype[i]==SJUMP)
    {
      // If subroutine call, flag return address as a possible branch target
      if(rt1[i]==PR && i<slen-2) bt[i+2]=1;
      
      if(ba[i]>=start && ba[i]<(start+slen*2) ) {
        // Possibly internal branch, flag target
        bt[(ba[i]-start)>>1]=1;
      }
    }
  }

  // Do constant propagation
  p_isconst=0;
  for(i=0;i<slen;i++)
  {
    if(bt[i])
    {
      // Can't do constant propagation if a branch target intervenes
      p_isconst=0;
    }
    if(i>1&&(itype[i-2]==UJUMP||itype[i-2]==RJUMP)) p_isconst=0;
    if(i>0&&(itype[i-1]==UJUMP||itype[i-1]==RJUMP)) p_isconst=0;
    if(i>0&&(itype[i-1]==CJUMP||itype[i-1]==SJUMP)) p_isconst=0;
    do_consts(i,&p_isconst,p_constmap);
    if(itype[i]==RJUMP) {
      if(opcode[i]!=0||opcode2[i]!=11||opcode3[i]!=2) { // Not RTE
        if((p_isconst>>rs1[i])&1) {
          // Do constant propagation, branch to fixed address
          u32 constaddr=p_constmap[rs1[i]];
          if(opcode[i]==0&&opcode2[i]==3) {
            // PC-relative branch, add PC+4
            constaddr+=start+i*2+4;
          }
          ba[i]=constaddr;
          //if(internal_branch(constaddr))
          //  if(!bt[(constaddr-start)>>1]) printf("oops: %x\n",constaddr);
          //assert(bt[(constaddr-start)>>1]);
        }
      }
    }
    // No stack-based addressing modes in the delay slot,
    // to avoid incorrect constants due to pre-incrementing.
    // TODO: This really should only drop the address register
    if(itype[i]==UJUMP||itype[i]==RJUMP||itype[i]==SJUMP) {
      if((source[i+1]&0xF00A)==0x4002) p_isconst=0;
      if((source[i+1]&0xB00E)==0x2004) p_isconst=0;
      if((source[i+1]&0xB00F)==0x2006) p_isconst=0;
    }
    memcpy(regs[i].constmap,p_constmap,sizeof(u32)*SH2_REGS);
    regs[i].isconst=p_isconst;
  }
  unneeded_registers(0,slen-1,0);
  
  /* Pass 3 - Register allocation */

  {
  struct regstat current; // Current register allocations/status
  int cc=0;
  current.dirty=0;
  current.u=unneeded_reg[0];
  clear_all_regs(current.regmap);
  alloc_reg(&current,0,CCREG);
  dirty_reg(&current,CCREG);
  current.isdoingcp=0;
  current.wasdoingcp=0;
  
  for(i=0;i<slen;i++)
  {
    if(bt[i])
    {
      // Can't do constant propagation if a branch target intervenes
      current.isdoingcp=0;
    }
    memcpy(regmap_pre[i],current.regmap,sizeof(current.regmap));
    //printf("pre: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",regmap_pre[i][0],regmap_pre[i][1],regmap_pre[i][2],regmap_pre[i][3],regmap_pre[i][5],regmap_pre[i][6],regmap_pre[i][7]);
    regs[i].wasdoingcp=current.isdoingcp;
    regs[i].wasdirty=current.dirty;
    if(itype[i]==UJUMP||itype[i]==SJUMP||itype[i]==RJUMP) {
      if(i+1<slen) {
        //current.u=branch_unneeded_reg[i]&~((1LL<<rs1[i+1])|(1LL<<rs2[i+1]));
        current.u=branch_unneeded_reg[i];
        //if(rt1[i+1]>=0) current.u|=1LL<<rt1[i+1];
        //if(rt2[i+1]>=0) current.u|=1LL<<rt2[i+1];
        if(rs1[i+1]>=0) current.u&=~(1LL<<rs1[i+1]);
        if(rs2[i+1]>=0) current.u&=~(1LL<<rs2[i+1]);
        if(rs3[i+1]>=0) current.u&=~(1LL<<rs3[i+1]);
        if(rs1[i+1]==TBIT||rs2[i+1]==TBIT) current.u&=~(1LL<<SR);
        if(rt1[i+1]==TBIT||rt2[i+1]==TBIT) current.u&=~(1LL<<SR);
        //current.u&=~((1LL<<rs1[i])|(1LL<<rs2[i]));
        if(rs1[i]>=0) current.u&=~(1LL<<rs1[i]);
        if(rs2[i]>=0) current.u&=~(1LL<<rs2[i]); // CCREG
        if(rs1[i]==TBIT||rs2[i]==TBIT) current.u&=~(1LL<<SR); // BT/S BF/S
        regs[i].u=current.u;
      } else { printf("oops, branch at end of block with no delay slot\n");exit(1); }
    }else if(itype[i]==CJUMP) {
      current.u=branch_unneeded_reg[i];
      regs[i].u=current.u;
      if(rs1[i]>=0) current.u&=~(1LL<<rs1[i]);
      if(rs2[i]>=0) current.u&=~(1LL<<rs2[i]); // CCREG
      if(rs1[i]==TBIT||rs2[i]==TBIT) current.u&=~(1LL<<SR); // BT BF
    } else {
      if(i+1<slen) {
        regs[i].u=unneeded_reg[i+1];
        //current.u=unneeded_reg[i+1]&~((1LL<<rs1[i])|(1LL<<rs2[i]));
        //current.u=unneeded_reg[i+1]&~((1LL<<rs1[i])|(1LL<<rs2[i])|(1LL<<rs3[i]));
        current.u=unneeded_reg[i+1];
        if(rs1[i]>=0) current.u&=~(1LL<<rs1[i]);
        if(rs2[i]>=0) current.u&=~(1LL<<rs2[i]);
        if(rs3[i]>=0) current.u&=~(1LL<<rs3[i]);
        if(rs1[i]==TBIT||rs2[i]==TBIT) current.u&=~(1LL<<SR);
        if(rt1[i]==TBIT||rt2[i]==TBIT) current.u&=~(1LL<<SR);
      } else {
        current.u=0;
      }
    }
    is_ds[i]=ds;
    if(ds) {
      struct regstat temp;
      ds=0; // Skip delay slot, already allocated as part of branch
      // ...but we need to alloc it in case something jumps here
      if(i+1<slen) {
        current.u=branch_unneeded_reg[i-1]&unneeded_reg[i+1];
      }else{
        current.u=branch_unneeded_reg[i-1];
      }
      current.u&=~((1LL<<rs1[i])|(1LL<<rs2[i]));
      memcpy(&temp,&current,sizeof(current));
      temp.wasdirty=temp.dirty;
      // TODO: Take into account unconditional branches, as below
      delayslot_alloc(&temp,i);
      memcpy(regs[i].regmap,temp.regmap,sizeof(temp.regmap));
      regs[i].wasdirty=temp.wasdirty;
      regs[i].dirty=temp.dirty;
      regs[i].isdoingcp=0;
      regs[i].wasdoingcp=0;
      current.isdoingcp=0;
      // Create entry (branch target) regmap
      for(hr=0;hr<HOST_REGS;hr++)
      {
        int r=temp.regmap[hr];
        if(r>=0) {
          if(r!=regmap_pre[i][hr]) {
            regs[i].regmap_entry[hr]=-1;
          }
          else
          {
            if((current.u>>r)&1) {
              regs[i].regmap_entry[hr]=-1;
              regs[i].regmap[hr]=-1;
              //Don't clear regs in the delay slot as the branch might need them
              //current.regmap[hr]=-1;
            }else
              regs[i].regmap_entry[hr]=r;
          }
        } else {
          // First instruction expects CCREG to be allocated
          if(i==0&&hr==HOST_CCREG) 
            regs[i].regmap_entry[hr]=CCREG;
          else
            regs[i].regmap_entry[hr]=-1;
        }
      }
    }
    else { // Not delay slot
      switch(itype[i]) {
        case UJUMP:
          //current.isdoingcp=0; // DEBUG
          //current.wasdoingcp=0; // DEBUG
          //regs[i].wasdoingcp=0; // DEBUG
          clear_const(&current,rt1[i]);
          alloc_cc(&current,i);
          dirty_reg(&current,CCREG);
          if (rt1[i]==PR) {
            alloc_reg(&current,i,PR);
            dirty_reg(&current,PR);
            assert(rs1[i+1]!=PR&&rs2[i+1]!=PR);
            #ifdef REG_PREFETCH
            alloc_reg(&current,i,PTEMP);
            #endif
          }
          ooo[i]=1;
          delayslot_alloc(&current,i+1);
          //current.isdoingcp=0; // DEBUG
          ds=1;
          //printf("i=%d, isdoingcp=%x\n",i,current.isdoingcp);
          break;
        case RJUMP:
          //current.isdoingcp=0;
          //current.wasdoingcp=0;
          //regs[i].wasdoingcp=0;
          clear_const(&current,rs1[i]);
          clear_const(&current,rt1[i]);
          alloc_cc(&current,i);
          dirty_reg(&current,CCREG);
          if(opcode[i]==0&&opcode2[i]==11&&opcode3[i]==2) { // RTE
            alloc_reg(&current,i,15); // Stack reg
            dirty_reg(&current,15);
            alloc_reg(&current,i,SR); // SR will be loaded from stack
            dirty_reg(&current,SR);
            assert(rt1[i+1]!=15&&rt2[i+1]!=15);
            assert(rt1[i+1]!=SR&&rt2[i+1]!=SR);
            assert(rt1[i+1]!=TBIT&&rt2[i+1]!=TBIT);
            delayslot_alloc(&current,i+1);
          }
          else
          if(rs1[i]!=rt1[i+1]&&rs1[i]!=rt2[i+1]) {
            alloc_reg(&current,i,rs1[i]);
            if (rt1[i]==PR) {
              alloc_reg(&current,i,rt1[i]);
              dirty_reg(&current,rt1[i]);
              assert(rs1[i+1]!=PR&&rs2[i+1]!=PR);
              if(rs1[i+1]==PR||rs2[i+1]==PR) {printf("OOPS\n");}
              #ifdef REG_PREFETCH
              alloc_reg(&current,i,PTEMP);
              #endif
            }
            #ifdef USE_MINI_HT
            if(rs1[i]==PR) { // BSRF/JSR
              alloc_reg(&current,i,RHASH);
              #ifndef HOST_IMM_ADDR32
              alloc_reg(&current,i,RHTBL);
              #endif
            }
            #endif
            // PC-relative branch needs a temporary register to add PC
            if(opcode[i]==0&&opcode2[i]==3) alloc_reg(&current,i,RTEMP);
            delayslot_alloc(&current,i+1);
          } else {
            // The delay slot overwrites our source register,
            // allocate a temporary register to hold the old value.
            current.isdoingcp=0;
            current.wasdoingcp=0;
            regs[i].wasdoingcp=0;
            delayslot_alloc(&current,i+1);
            current.isdoingcp=0;
            alloc_reg(&current,i,RTEMP);
          }
          //current.isdoingcp=0; // DEBUG
          ooo[i]=1;
          ds=1;
          break;
        case CJUMP:
          //current.isdoingcp=0;
          //current.wasdoingcp=0;
          //regs[i].wasdoingcp=0;
          clear_const(&current,rs1[i]);
          clear_const(&current,rs2[i]);
          alloc_cc(&current,i);
          dirty_reg(&current,CCREG);
          alloc_reg(&current,i,SR);
          // No delay slot, don't do constant propagation
          current.isdoingcp=0;
          current.wasdoingcp=0;
          regs[i].wasdoingcp=0;
          //ds=1; // BT/BF don't have delay slots
          break;
        case SJUMP:
          //current.isdoingcp=0;
          //current.wasdoingcp=0;
          //regs[i].wasdoingcp=0;
          clear_const(&current,rs1[i]);
          clear_const(&current,rt1[i]);
          alloc_cc(&current,i);
          dirty_reg(&current,CCREG);
          alloc_reg(&current,i,SR);
          if(rt1[i+1]==TBIT||rt2[i+1]==TBIT||rt1[i+1]==SR||rt2[i+1]==SR) {
            // The delay slot overwrites the branch condition.
            // Allocate the branch condition registers instead.
            current.isdoingcp=0;
            current.wasdoingcp=0;
            regs[i].wasdoingcp=0;
          }
          else
          if(itype[i+1]==COMPLEX) {
            // The MAC and DIV instructions make function calls which
            // do not save registers.  Do the branch and update the
            // cycle count first.
            current.isdoingcp=0;
            current.wasdoingcp=0;
            regs[i].wasdoingcp=0;
          }
          else
          {
            ooo[i]=1;
            delayslot_alloc(&current,i+1);
          }
          ds=1;
          //current.isdoingcp=0;
          break;
        case IMM8:
          imm8_alloc(&current,i);
          break;
        case LOAD:
          load_alloc(&current,i);
          break;
        case STORE:
          store_alloc(&current,i);
          break;
        case RMW:
          rmw_alloc(&current,i);
          break;
        case PCREL:
          pcrel_alloc(&current,i);
          break;
        case ALU:
          alu_alloc(&current,i);
          break;
        case MULTDIV:
          multdiv_alloc(&current,i);
          break;
        case SHIFTIMM:
          shiftimm_alloc(&current,i);
          break;
        case MOV:
          mov_alloc(&current,i);
          break;
        case EXT:
          ext_alloc(&current,i);
          break;
        case FLAGS:
          flags_alloc(&current,i);
          break;
        case COMPLEX:
          complex_alloc(&current,i);
          break;
        case SYSTEM:
          system_alloc(&current,i);
          break;
      }
      
      //printf("xxx: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",current.regmap[0],current.regmap[1],current.regmap[2],current.regmap[3],current.regmap[5],current.regmap[6],current.regmap[7]);

      // Create entry (branch target) regmap
      for(hr=0;hr<HOST_REGS;hr++)
      {
        int r,or,er;
        r=current.regmap[hr];
        if(r>=0) {
          if(r!=regmap_pre[i][hr]) {
            // TODO: delay slot (?)
            or=get_reg(regmap_pre[i],r); // Get old mapping for this register
            if(or<0||(r&63)>=TEMPREG){
              regs[i].regmap_entry[hr]=-1;
            }
            else
            {
              // Just move it to a different register
              regs[i].regmap_entry[hr]=r;
              // If it was dirty before, it's still dirty
              if((regs[i].wasdirty>>or)&1) dirty_reg(&current,r&63);
            }
          }
          else
          {
            if(r<64){
              if((current.u>>r)&1) {
                regs[i].regmap_entry[hr]=-1;
                //regs[i].regmap[hr]=-1;
                current.regmap[hr]=-1;
              }else
                regs[i].regmap_entry[hr]=r;
            }
          }
        } else {
          // Branches expect CCREG to be allocated at the target
          if(regmap_pre[i][hr]==CCREG) 
            regs[i].regmap_entry[hr]=CCREG;
          else
            regs[i].regmap_entry[hr]=-1;
        }
      }
      memcpy(regs[i].regmap,current.regmap,sizeof(current.regmap));
    }
    /* Branch post-alloc */
    if(i>0)
    {
      current.wasdirty=current.dirty;
      switch(itype[i-1]) {
        case UJUMP:
          memcpy(&branch_regs[i-1],&current,sizeof(current));
          branch_regs[i-1].isdoingcp=0;
          branch_regs[i-1].wasdoingcp=0;
          branch_regs[i-1].isconst=0;
          branch_regs[i-1].u=branch_unneeded_reg[i-1]&~((1LL<<rs1[i-1])|(1LL<<rs2[i-1]));
          alloc_cc(&branch_regs[i-1],i-1);
          dirty_reg(&branch_regs[i-1],CCREG);
          if(rt1[i-1]==PR) { // BSR
            alloc_reg(&branch_regs[i-1],i-1,PR);
            dirty_reg(&branch_regs[i-1],PR);
          }
          memcpy(&branch_regs[i-1].regmap_entry,&branch_regs[i-1].regmap,sizeof(current.regmap));
          memcpy(cpmap[i],cpmap[i-1],sizeof(current.cpmap));
          break;
        case RJUMP:
          memcpy(&branch_regs[i-1],&current,sizeof(current));
          branch_regs[i-1].isdoingcp=0;
          branch_regs[i-1].wasdoingcp=0;
          branch_regs[i-1].isconst=0;
          branch_regs[i-1].u=branch_unneeded_reg[i-1]&~((1LL<<rs1[i-1])|(1LL<<rs2[i-1]));
          alloc_cc(&branch_regs[i-1],i-1);
          dirty_reg(&branch_regs[i-1],CCREG);
          alloc_reg(&branch_regs[i-1],i-1,rs1[i-1]);
          if(rt1[i-1]==PR) { // BSRF/JSR
            alloc_reg(&branch_regs[i-1],i-1,rt1[i-1]);
            dirty_reg(&branch_regs[i-1],rt1[i-1]);
          }
          #ifdef USE_MINI_HT
          if(rs1[i-1]==PR) { // RTS
            alloc_reg(&branch_regs[i-1],i-1,RHASH);
            #ifndef HOST_IMM_ADDR32
            alloc_reg(&branch_regs[i-1],i-1,RHTBL);
            #endif
          }
          #endif
          if(opcode[i-1]==0&&opcode2[i-1]==11&&opcode3[i-1]==2) { // RTE
            alloc_reg(&branch_regs[i-1],i-1,SR); // SR will be loaded from stack
            dirty_reg(&branch_regs[i-1],SR);
            alloc_reg(&branch_regs[i-1],i-1,RTEMP);
            alloc_reg(&branch_regs[i-1],i-1,MOREG);
          }
          memcpy(&branch_regs[i-1].regmap_entry,&branch_regs[i-1].regmap,sizeof(current.regmap));
          memcpy(cpmap[i],cpmap[i-1],sizeof(current.cpmap));
          break;
        case SJUMP:
          alloc_cc(&current,i-1);
          dirty_reg(&current,CCREG);
          if(rt1[i]==TBIT||rt2[i]==TBIT||rt1[i]==SR||rt2[i]==SR||itype[i]==COMPLEX) {
            // The delay slot overwrote the branch condition
            // Delay slot goes after the test (in order)
            current.u=branch_unneeded_reg[i-1]&~((1LL<<rs1[i])|(1LL<<rs2[i]));
            delayslot_alloc(&current,i);
            current.isdoingcp=0;
          }
          else
          {
            current.u=branch_unneeded_reg[i-1]&~(1LL<<rs1[i-1]);
            // Alloc the branch condition register
            alloc_reg(&current,i-1,SR);
          }
          memcpy(&branch_regs[i-1],&current,sizeof(current));
          branch_regs[i-1].isdoingcp=0;
          branch_regs[i-1].wasdoingcp=0;
          branch_regs[i-1].isconst=0;
          memcpy(&branch_regs[i-1].regmap_entry,&current.regmap,sizeof(current.regmap));
          memcpy(cpmap[i],cpmap[i-1],sizeof(current.cpmap));
          break;
      }

      if(itype[i-1]==UJUMP||itype[i-1]==RJUMP||itype[i]==DATA)
      {
        if(rt1[i-1]==PR&&itype[i]!=DATA) // BSR/JSR
        {
          // Subroutine call will return here, don't alloc any registers
          current.dirty=0;
          clear_all_regs(current.regmap);
          alloc_reg(&current,i,CCREG);
          dirty_reg(&current,CCREG);
        }
        else if(i+1<slen)
        {
          // Internal branch will jump here, match registers to caller
          current.dirty=0;
          clear_all_regs(current.regmap);
          alloc_reg(&current,i,CCREG);
          dirty_reg(&current,CCREG);
          for(j=i-1;j>=0;j--)
          {
            if(ba[j]==start+i*2+2) {
              if(itype[j]==CJUMP) {
                memcpy(current.regmap,regs[j].regmap,sizeof(current.regmap));
                current.dirty=regs[j].dirty;
              }else{
                memcpy(current.regmap,branch_regs[j].regmap,sizeof(current.regmap));
                current.dirty=branch_regs[j].dirty;
              }
              break;
            }
          }
          while(j>=0) {
            if(ba[j]==start+i*2+2) {
              for(hr=0;hr<HOST_REGS;hr++) {
                if(itype[j]==CJUMP) {
                  if(current.regmap[hr]!=regs[j].regmap[hr]) {
                    current.regmap[hr]=-1;
                  }
                  current.dirty&=regs[j].dirty;
                }else{
                  if(current.regmap[hr]!=branch_regs[j].regmap[hr]) {
                    current.regmap[hr]=-1;
                  }
                  current.dirty&=branch_regs[j].dirty;
                }
              }
            }
            j--;
          }
        }
      }
    }

    // Count cycles in between branches
    ccadj[i]=cc;
    if(i>0&&(itype[i-1]==RJUMP||itype[i-1]==UJUMP))
    {
      cc=0;
    }
    else
    if(itype[i]==CJUMP||itype[i]==SJUMP)
    {
      cc=1;
    }
    else
    {
      cc+=cycles[i];
    }

    if(!is_ds[i]) {
      regs[i].dirty=current.dirty;
      regs[i].isdoingcp=current.isdoingcp;
      memcpy(cpmap[i],current.cpmap,sizeof(current.cpmap));
    }
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG&&regs[i].regmap[hr]>=0) {
        if(regmap_pre[i][hr]!=regs[i].regmap[hr]) {
          regs[i].wasdoingcp&=~(1<<hr);
        }
      }
    }
  }
  }
  
  /* Pass 4 - Cull unused host registers */
  
  {
  u64 nr=0;
  
  for (i=slen-1;i>=0;i--)
  {
    int hr;
    if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==CJUMP||itype[i]==SJUMP)
    {
      if(ba[i]<start || ba[i]>=(start+slen*2))
      {
        // Branch out of this block, don't need anything
        nr=0;
      }
      else
      {
        // Internal branch
        // Need whatever matches the target
        int t=(ba[i]-start)>>1;
        nr=0;
        for(hr=0;hr<HOST_REGS;hr++)
        {
          if(regs[i].regmap_entry[hr]>=0) {
            if(regs[i].regmap_entry[hr]==regs[t].regmap_entry[hr]) nr|=1<<hr;
          }
        }
      }
      // Conditional branch may need registers for following instructions
      if(itype[i]==SJUMP)
      {
        if(i<slen-2) {
          nr|=needed_reg[i+2];
          for(hr=0;hr<HOST_REGS;hr++)
          {
            if(regmap_pre[i+2][hr]>=0&&get_reg(regs[i+2].regmap_entry,regmap_pre[i+2][hr])<0) nr&=~(1<<hr);
            //if((regmap_entry[i+2][hr])>=0) if(!((nr>>hr)&1)) printf("%x-bogus(%d=%d)\n",start+i*2,hr,regmap_entry[i+2][hr]);
          }
        }
      }
      else if(itype[i]==CJUMP)
      {
        if(i<slen-2) {
          nr|=needed_reg[i+1];
          for(hr=0;hr<HOST_REGS;hr++)
          {
            if(regmap_pre[i+1][hr]>=0&&get_reg(regs[i+1].regmap_entry,regmap_pre[i+1][hr])<0) nr&=~(1<<hr);
            //if((regmap_entry[i+2][hr])>=0) if(!((nr>>hr)&1)) printf("%x-bogus(%d=%d)\n",start+i*2,hr,regmap_entry[i+2][hr]);
          }
        }
      }
      // Don't need stuff which is overwritten
      for(hr=0;hr<HOST_REGS;hr++) {
        if(regs[i].regmap[hr]!=regmap_pre[i][hr]) nr&=~(1<<hr);
        if(regs[i].regmap[hr]<0) nr&=~(1<<hr);
      }
      // Merge in delay slot
      if(itype[i]!=CJUMP) 
      for(hr=0;hr<HOST_REGS;hr++)
      {
        // These are overwritten by the delay slot
        if(rt1[i+1]>=0&&rt1[i+1]==(regs[i].regmap[hr]&63)) nr&=~(1<<hr);
        if(rt2[i+1]>=0&&rt2[i+1]==(regs[i].regmap[hr]&63)) nr&=~(1<<hr);
        if(rs1[i+1]>=0&&rs1[i+1]==regmap_pre[i][hr]) nr|=1<<hr;
        if(rs2[i+1]>=0&&rs2[i+1]==regmap_pre[i][hr]) nr|=1<<hr;
        if(rs3[i+1]>=0&&rs3[i+1]==regmap_pre[i][hr]) nr|=1<<hr;
        if(rs1[i+1]>=0&&rs1[i+1]==regs[i].regmap_entry[hr]) nr|=1<<hr;
        if(rs2[i+1]>=0&&rs2[i+1]==regs[i].regmap_entry[hr]) nr|=1<<hr;
        if(rs3[i+1]>=0&&rs3[i+1]==regs[i].regmap_entry[hr]) nr|=1<<hr;
        //if(dep1[i+1]&&!((unneeded_reg_upper[i]>>dep1[i+1])&1)) {
        //  if(dep1[i+1]==(regmap_pre[i][hr]&63)) nr|=1<<hr;
        //  if(dep2[i+1]==(regmap_pre[i][hr]&63)) nr|=1<<hr;
        //}
        //if(dep2[i+1]&&!((unneeded_reg_upper[i]>>dep2[i+1])&1)) {
        //  if(dep1[i+1]==(regs[i].regmap_entry[hr]&63)) nr|=1<<hr;
        //  if(dep2[i+1]==(regs[i].regmap_entry[hr]&63)) nr|=1<<hr;
        //}
        if(regs[i].regmap_entry[hr]==SR) nr|=1<<hr;
        if(regs[i].regmap[hr]==SR) nr|=1<<hr;
        if(regmap_pre[i][hr]==SR) nr|=1<<hr;
      }
    }
    else if(itype[i]==SYSTEM)
    {
      // TRAPA instruction (software interrupt)
      nr=0;
      for(hr=0;hr<HOST_REGS;hr++)
      {
        // Source registers are needed
        if(regmap_pre[i][hr]==15) nr|=1<<hr;
        if(regmap_pre[i][hr]==SR) nr|=1<<hr;
        if(regmap_pre[i][hr]==VBR) nr|=1<<hr;
        if(regmap_pre[i][hr]==CCREG) nr|=1<<hr;
        if(regs[i].regmap_entry[hr]==15) nr|=1<<hr;
        if(regs[i].regmap_entry[hr]==SR) nr|=1<<hr;
        if(regs[i].regmap_entry[hr]==VBR) nr|=1<<hr;
        if(regs[i].regmap_entry[hr]==CCREG) nr|=1<<hr;
      }
    }
    else // Non-branch
    {
      if(i<slen-1) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(regmap_pre[i+1][hr]>=0&&get_reg(regs[i+1].regmap_entry,regmap_pre[i+1][hr])<0) nr&=~(1<<hr);
          if(regs[i].regmap[hr]!=regmap_pre[i+1][hr]) nr&=~(1<<hr);
          if(regs[i].regmap[hr]!=regmap_pre[i][hr]) nr&=~(1<<hr);
          if(regs[i].regmap[hr]<0) nr&=~(1<<hr);
        }
      }
    }
    for(hr=0;hr<HOST_REGS;hr++)
    {
      // Overwritten registers are not needed
      if(rt1[i]>=0&&rt1[i]==(regs[i].regmap[hr]&63)) nr&=~(1<<hr);
      if(rt2[i]>=0&&rt2[i]==(regs[i].regmap[hr]&63)) nr&=~(1<<hr);
      // Source registers are needed
      if(rs1[i]>=0&&rs1[i]==regmap_pre[i][hr]) nr|=1<<hr;
      if(rs2[i]>=0&&rs2[i]==regmap_pre[i][hr]) nr|=1<<hr;
      if(rs3[i]>=0&&rs3[i]==regmap_pre[i][hr]) nr|=1<<hr;
      if(rs1[i]>=0&&rs1[i]==regs[i].regmap_entry[hr]) nr|=1<<hr;
      if(rs2[i]>=0&&rs2[i]==regs[i].regmap_entry[hr]) nr|=1<<hr;
      if(rs3[i]>=0&&rs3[i]==regs[i].regmap_entry[hr]) nr|=1<<hr;
      //if(dep1[i]&&!((unneeded_reg_upper[i]>>dep1[i])&1)) {
      //  if(dep1[i]==(regmap_pre[i][hr]&63)) nr|=1<<hr;
      //  if(dep1[i]==(regs[i].regmap_entry[hr]&63)) nr|=1<<hr;
      //}
      //if(dep2[i]&&!((unneeded_reg_upper[i]>>dep2[i])&1)) {
      //  if(dep2[i]==(regmap_pre[i][hr]&63)) nr|=1<<hr;
      //  if(dep2[i]==(regs[i].regmap_entry[hr]&63)) nr|=1<<hr;
      //}
      if(regs[i].regmap_entry[hr]==SR) nr|=1<<hr;
      if(regs[i].regmap[hr]==SR) nr|=1<<hr;
      if(regmap_pre[i][hr]==SR) nr|=1<<hr;
      // Don't store a register immediately after writing it,
      // may prevent dual-issue.
      // But do so if this is a branch target, otherwise we
      // might have to load the register before the branch.
      if(i>0&&!bt[i]&&((regs[i].wasdirty>>hr)&1)) {
        if(regmap_pre[i][hr]>=0&&!((unneeded_reg[i]>>regmap_pre[i][hr])&1)) {
          if(rt1[i-1]==(regmap_pre[i][hr]&63)) nr|=1<<hr;
          if(rt2[i-1]==(regmap_pre[i][hr]&63)) nr|=1<<hr;
        }
        if(regs[i].regmap_entry[hr]>=0&&!((unneeded_reg[i]>>regs[i].regmap_entry[hr])&1)) {
          if(rt1[i-1]==(regs[i].regmap_entry[hr]&63)) nr|=1<<hr;
          if(rt2[i-1]==(regs[i].regmap_entry[hr]&63)) nr|=1<<hr;
        }
      }
    }
    // Cycle count is needed at branches.  Assume it is needed at the target too.
    if(i==0||bt[i]||itype[i]==CJUMP||itype[i]==SJUMP) {
      if(regmap_pre[i][HOST_CCREG]==CCREG) nr|=1<<HOST_CCREG;
      if(regs[i].regmap_entry[HOST_CCREG]==CCREG) nr|=1<<HOST_CCREG;
    }
    // Save it
    needed_reg[i]=nr;
    
    // Deallocate unneeded registers
    for(hr=0;hr<HOST_REGS;hr++)
    {
      if(!((nr>>hr)&1)) {
        if(regs[i].regmap_entry[hr]!=CCREG) regs[i].regmap_entry[hr]=-1;
        if((regs[i].regmap[hr]&63)!=rs1[i] && (regs[i].regmap[hr]&63)!=rs2[i] &&
           (regs[i].regmap[hr]&63)!=rt1[i] && (regs[i].regmap[hr]&63)!=rt2[i] &&
           (regs[i].regmap[hr]&63)!=PTEMP && (regs[i].regmap[hr]&63)!=CCREG)
        {
          if(itype[i]==CJUMP) {
            regs[i].regmap[hr]=-1;
            regs[i].isdoingcp&=~(1<<hr);
            if(i<slen-1) {
              regmap_pre[i+1][hr]=-1;
              regs[i+1].wasdoingcp&=~(1<<hr);
            }
          }
        }
        if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==SJUMP)
        {
          int temp1=-1,temp2=-1;
          //if(get_reg(regs[i].regmap,rt1[i+1]|64)>=0||get_reg(branch_regs[i].regmap,rt1[i+1]|64)>=0)
          //{
          //  d1=dep1[i+1];
          //  d2=dep2[i+1];
          //}
          if(itype[i+1]==LOAD || itype[i+1]==STORE || 
             itype[i+1]==RMW || itype[i+1]==PCREL ||
             itype[i+1]==SYSTEM || source[i]==0x002B /* RTE */ )
            temp1=MOREG;
          if(itype[i+1]==COMPLEX) {
            temp1=MACH;
            temp2=MACL;
          }
          if(regs[i].regmap[hr]!=rs1[i] && regs[i].regmap[hr]!=rs2[i] && regs[i].regmap[hr]!=rs3[i] && 
             regs[i].regmap[hr]!=rt1[i] && regs[i].regmap[hr]!=rt2[i] &&
             regs[i].regmap[hr]!=rs1[i+1] && regs[i].regmap[hr]!=rs2[i+1] && regs[i].regmap[hr]!=rs3[i+1] &&
             regs[i].regmap[hr]!=rt1[i+1] && regs[i].regmap[hr]!=rt2[i+1] &&
             regs[i].regmap[hr]!=RHASH && regs[i].regmap[hr]!=RHTBL &&
             regs[i].regmap[hr]!=RTEMP && regs[i].regmap[hr]!=PTEMP &&
             regs[i].regmap[hr]!=CCREG &&
             regs[i].regmap[hr]!=temp1 && regs[i].regmap[hr]!=temp2 )
          {
            regs[i].regmap[hr]=-1;
            regs[i].isdoingcp&=~(1<<hr);
            if(branch_regs[i].regmap[hr]!=rs1[i] && branch_regs[i].regmap[hr]!=rs2[i] && branch_regs[i].regmap[hr]!=rs3[i] &&
               branch_regs[i].regmap[hr]!=rt1[i] && branch_regs[i].regmap[hr]!=rt2[i] &&
               branch_regs[i].regmap[hr]!=rs1[i+1] && branch_regs[i].regmap[hr]!=rs2[i+1] && branch_regs[i].regmap[hr]!=rs3[i+1] &&
               branch_regs[i].regmap[hr]!=rt1[i+1] && branch_regs[i].regmap[hr]!=rt2[i+1] &&
               branch_regs[i].regmap[hr]!=RHASH && branch_regs[i].regmap[hr]!=RHTBL &&
               branch_regs[i].regmap[hr]!=RTEMP && branch_regs[i].regmap[hr]!=PTEMP &&
               branch_regs[i].regmap[hr]!=CCREG &&
               branch_regs[i].regmap[hr]!=temp1 && branch_regs[i].regmap[hr]!=temp2)
            {
              branch_regs[i].regmap[hr]=-1;
              branch_regs[i].regmap_entry[hr]=-1;
              if(itype[i]!=RJUMP&&itype[i]!=UJUMP)
              {
                if(i<slen-2) {
                  regmap_pre[i+2][hr]=-1;
                  regs[i+2].wasdoingcp&=~(1<<hr);
                }
              }
            }
          }
        }
        else
        {
          // Non-branch
          if(i>0)
          {
            int temp1=-1,temp2=-1;
            //if(get_reg(regs[i].regmap,rt1[i]|64)>=0)
            //{
            //  d1=dep1[i];
            //  d2=dep2[i];
            //}
            if(itype[i]==LOAD || itype[i]==STORE || itype[i]==RMW ||
               itype[i]==PCREL || itype[i]==SYSTEM )
              temp1=MOREG;
            if(itype[i]==COMPLEX) {
              temp1=MACH;
              temp2=MACL;
            }
            else if(itype[i]==SYSTEM) {
              temp2=CCREG;
            }
            if(regs[i].regmap[hr]!=rt1[i] && regs[i].regmap[hr]!=rt2[i] &&
               regs[i].regmap[hr]!=rs1[i] && regs[i].regmap[hr]!=rs2[i] &&
               regs[i].regmap[hr]!=rs3[i] &&
               regs[i].regmap[hr]!=temp1 && regs[i].regmap[hr]!=temp2 &&
               regs[i].regmap[hr]!=CCREG)
            {
              if(i<slen-1&&!is_ds[i]) {
                if(regmap_pre[i+1][hr]!=-1 || regs[i].regmap[hr]!=-1)
                if(regmap_pre[i+1][hr]!=regs[i].regmap[hr])
                {
                  printf("fail: %x (%d %d!=%d)\n",start+i*2,hr,regmap_pre[i+1][hr],regs[i].regmap[hr]);
                  assert(regmap_pre[i+1][hr]==regs[i].regmap[hr]);
                }
                regmap_pre[i+1][hr]=-1;
                if(regs[i+1].regmap_entry[hr]==CCREG) regs[i+1].regmap_entry[hr]=-1;
                regs[i+1].wasdoingcp&=~(1<<hr);
              }
              regs[i].regmap[hr]=-1;
              regs[i].isdoingcp&=~(1<<hr);
            }
          }
        }
      }
    }
  }
  }
  
  /* Pass 5 - Pre-allocate registers */
  
  // If a register is allocated during a loop, try to allocate it for the
  // entire loop, if possible.  This avoids loading/storing registers
  // inside of the loop.
  {
  signed char f_regmap[HOST_REGS];
  clear_all_regs(f_regmap);
  for(i=0;i<slen-1;i++)
  {
    if(itype[i]==UJUMP||itype[i]==SJUMP||itype[i]==CJUMP)
    {
      if(ba[i]>=start && ba[i]<(start+i*2)) 
      if(itype[i]==CJUMP||itype[i+1]==NOP||itype[i+1]==MOV||itype[i+1]==ALU
      ||itype[i+1]==SHIFTIMM||itype[i+1]==IMM8||itype[i+1]==LOAD
      ||itype[i+1]==STORE||itype[i+1]==RMW||itype[i+1]==PCREL||itype[i+1]==EXT||itype[i+1]==FLAGS)
      {
        // Track register allocation
        int t=(ba[i]-start)>>1;
        if(t>0&&(itype[t-1]!=UJUMP&&itype[t-1]!=RJUMP&&itype[t-1]!=SJUMP)) // loop_preload can't handle jumps into delay slots
        if(t<2||(itype[t-2]!=UJUMP&&itype[t-2]!=RJUMP)||rt1[t-2]!=PR) // call/ret assumes no registers allocated
        for(hr=0;hr<HOST_REGS;hr++)
        {
          if(regs[i].regmap[hr]>=0) {
            if(f_regmap[hr]!=regs[i].regmap[hr]) {
              // dealloc old register
              int n;
              for(n=0;n<HOST_REGS;n++)
              {
                if(f_regmap[n]==regs[i].regmap[hr]) {f_regmap[n]=-1;}
              }
              // and alloc new one
              f_regmap[hr]=regs[i].regmap[hr];
            }
          }
          if(branch_regs[i].regmap[hr]>=0) {
            if(f_regmap[hr]!=branch_regs[i].regmap[hr]) {
              // dealloc old register
              int n;
              for(n=0;n<HOST_REGS;n++)
              {
                if(f_regmap[n]==branch_regs[i].regmap[hr]) {f_regmap[n]=-1;}
              }
              // and alloc new one
              f_regmap[hr]=branch_regs[i].regmap[hr];
            }
          }
          if(ooo[i]) {
            if(count_free_regs(regs[i].regmap)<=minimum_free_regs[i+1]) 
              f_regmap[hr]=branch_regs[i].regmap[hr];
          }else{
            if(count_free_regs(branch_regs[i].regmap)<=minimum_free_regs[i+1]) 
              f_regmap[hr]=branch_regs[i].regmap[hr];
          }
          // Avoid dirty->clean transition
          //if(t>0) if(get_reg(regmap_pre[t],f_regmap[hr])>=0) if((regs[t].wasdirty>>get_reg(regmap_pre[t],f_regmap[hr]))&1) f_regmap[hr]=-1;
          // This check isn't required, but it's a good idea.  We can't hoist
          // the load if the register was already allocated, so there's no
          // point wasting time analyzing most of these cases.  It only
          // "succeeds" when the mapping was different and the load can be
          // replaced with a mov, which is of negligible benefit.  So such
          // cases are skipped below.
          if(f_regmap[hr]>=0) {
            if(regs[t].regmap[hr]==f_regmap[hr]||(regs[t].regmap_entry[hr]<0&&get_reg(regmap_pre[t],f_regmap[hr])<0)) {
              int r=f_regmap[hr];
              for(j=t;j<=i;j++)
              {
                //printf("Test %x -> %x, %x %d/%d\n",start+i*2,ba[i],start+j*2,hr,r);
                if(r<TBIT&&((unneeded_reg[j]>>r)&1)) break;
                if(regs[j].regmap[hr]==f_regmap[hr]&&(f_regmap[hr]&63)<TEMPREG) {
                  //printf("Hit %x -> %x, %x %d/%d\n",start+i*2,ba[i],start+j*2,hr,r);
                  int k;
                  if(regs[i].regmap[hr]==-1&&branch_regs[i].regmap[hr]==-1) {
                    if(get_reg(regs[i+2].regmap,f_regmap[hr])>=0) break;
                    k=i;
                    while(k>1&&regs[k-1].regmap[hr]==-1) {
                      if(count_free_regs(regs[k-1].regmap)<=minimum_free_regs[k-1]) {
                        //printf("no free regs for store %x\n",start+(k-1)*4);
                        break;
                      }
                      if(get_reg(regs[k-1].regmap,f_regmap[hr])>=0) {
                        //printf("no-match due to different register\n");
                        break;
                      }
                      if(itype[k-2]==UJUMP||itype[k-2]==RJUMP||itype[k-2]==CJUMP||itype[k-2]==SJUMP) {
                        //printf("no-match due to branch\n");
                        break;
                      }
                      // call/ret fast path assumes no registers allocated
                      if(k>2&&(itype[k-3]==UJUMP||itype[k-3]==RJUMP)&&rt1[k-3]==PR) {
                        break;
                      }
                      k--;
                    }
                    if(regs[k-1].regmap[hr]==f_regmap[hr]&&regmap_pre[k][hr]==f_regmap[hr]) {
                      //printf("Extend r%d, %x ->\n",hr,start+k*4);
                      while(k<i) {
                        regs[k].regmap_entry[hr]=f_regmap[hr];
                        regs[k].regmap[hr]=f_regmap[hr];
                        regmap_pre[k+1][hr]=f_regmap[hr];
                        regs[k].wasdirty&=~(1<<hr);
                        regs[k].dirty&=~(1<<hr);
                        regs[k].wasdirty|=(1<<hr)&regs[k-1].dirty;
                        regs[k].dirty|=(1<<hr)&regs[k].wasdirty;
                        regs[k].wasdoingcp&=~(1<<hr);
                        regs[k].isdoingcp&=~(1<<hr);
                        k++;
                      }
                    }
                    else {
                      //printf("Fail Extend r%d, %x ->\n",hr,start+k*4);
                      break;
                    }
                    assert(regs[i-1].regmap[hr]==f_regmap[hr]);
                    if(regs[i-1].regmap[hr]==f_regmap[hr]&&regmap_pre[i][hr]==f_regmap[hr]) {
                      //printf("OK fill %x (r%d)\n",start+i*4,hr);
                      regs[i].regmap_entry[hr]=f_regmap[hr];
                      regs[i].regmap[hr]=f_regmap[hr];
                      regs[i].wasdirty&=~(1<<hr);
                      regs[i].dirty&=~(1<<hr);
                      regs[i].wasdirty|=(1<<hr)&regs[i-1].dirty;
                      regs[i].dirty|=(1<<hr)&regs[i-1].dirty;
                      regs[i].wasdoingcp&=~(1<<hr);
                      regs[i].isdoingcp&=~(1<<hr);
                      branch_regs[i].regmap_entry[hr]=f_regmap[hr];
                      branch_regs[i].wasdirty&=~(1<<hr);
                      branch_regs[i].wasdirty|=(1<<hr)&regs[i].dirty;
                      branch_regs[i].regmap[hr]=f_regmap[hr];
                      branch_regs[i].dirty&=~(1<<hr);
                      branch_regs[i].dirty|=(1<<hr)&regs[i].dirty;
                      branch_regs[i].wasdoingcp&=~(1<<hr);
                      branch_regs[i].isdoingcp&=~(1<<hr);
                      if(itype[i]==CJUMP) {
                        regmap_pre[i+1][hr]=f_regmap[hr];
                        regs[i+1].wasdirty&=~(1<<hr);
                        regs[i+1].wasdirty|=(1<<hr)&regs[i].dirty;
                      }
                      else if(itype[i]!=RJUMP&&itype[i]!=UJUMP) {
                        regmap_pre[i+2][hr]=f_regmap[hr];
                        regs[i+2].wasdirty&=~(1<<hr);
                        regs[i+2].wasdirty|=(1<<hr)&regs[i].dirty;
                      }
                    }
                  }
                  for(k=t;k<j;k++) {
                    // Alloc register clean at beginning of loop,
                    // but may dirty it in pass 6
                    regs[k].regmap_entry[hr]=f_regmap[hr];
                    regs[k].regmap[hr]=f_regmap[hr];
                    regs[k].dirty&=~(1<<hr);
                    regs[k].wasdoingcp&=~(1<<hr);
                    regs[k].isdoingcp&=~(1<<hr);
                    if(itype[k]==UJUMP||itype[k]==RJUMP||itype[k]==SJUMP) {
                      branch_regs[k].regmap_entry[hr]=f_regmap[hr];
                      branch_regs[k].regmap[hr]=f_regmap[hr];
                      branch_regs[k].dirty&=~(1<<hr);
                      branch_regs[k].wasdoingcp&=~(1<<hr);
                      branch_regs[k].isdoingcp&=~(1<<hr);
                      if(itype[k]!=RJUMP&&itype[k]!=UJUMP) {
                        regmap_pre[k+2][hr]=f_regmap[hr];
                        regs[k+2].wasdirty&=~(1<<hr);
                      }
                    }
                    else
                    {
                      regmap_pre[k+1][hr]=f_regmap[hr];
                      regs[k+1].wasdirty&=~(1<<hr);
                    }
                  }
                  if(regs[j].regmap[hr]==f_regmap[hr])
                    regs[j].regmap_entry[hr]=f_regmap[hr];
                  break;
                }
                if(j==i) break;
                if(regs[j].regmap[hr]>=0)
                  break;
                if(get_reg(regs[j].regmap,f_regmap[hr])>=0) {
                  //printf("no-match due to different register\n");
                  break;
                }
                if(itype[j]==UJUMP||itype[j]==RJUMP)
                {
                  // Stop on unconditional branch
                  break;
                }
                if(itype[j]==SJUMP)
                {
                  if(ooo[j]) {
                    if(count_free_regs(regs[j].regmap)<=minimum_free_regs[j+1]) 
                      break;
                  }else{
                    if(count_free_regs(branch_regs[j].regmap)<=minimum_free_regs[j+1]) 
                      break;
                  }
                  if(get_reg(branch_regs[j].regmap,f_regmap[hr])>=0) {
                    //printf("no-match due to different register (branch)\n");
                    break;
                  }
                }
                if(count_free_regs(regs[j].regmap)<=minimum_free_regs[j]) {
                  //printf("No free regs for store %x\n",start+j*4);
                  break;
                }
              }
            }
          }
        }
      }
    }else{
      // Non branch or undetermined branch target
      for(hr=0;hr<HOST_REGS;hr++)
      {
        if(hr!=EXCLUDE_REG) {
          if(regs[i].regmap[hr]>=0) {
            if(f_regmap[hr]!=regs[i].regmap[hr]) {
              // dealloc old register
              int n;
              for(n=0;n<HOST_REGS;n++)
              {
                if(f_regmap[n]==regs[i].regmap[hr]) {f_regmap[n]=-1;}
              }
              // and alloc new one
              f_regmap[hr]=regs[i].regmap[hr];
            }
          }
        }
      }
      // Try to restore cycle count at branch targets
      if(bt[i]) {
        for(j=i;j<slen-1;j++) {
          if(regs[j].regmap[HOST_CCREG]!=-1) break;
          if(count_free_regs(regs[j].regmap)<=minimum_free_regs[j]) {
            //printf("no free regs for store %x\n",start+j*4);
            break;
          }
        }
        if(regs[j].regmap[HOST_CCREG]==CCREG) {
          int k=i;
          //printf("Extend CC, %x -> %x\n",start+k*4,start+j*4);
          while(k<j) {
            regs[k].regmap_entry[HOST_CCREG]=CCREG;
            regs[k].regmap[HOST_CCREG]=CCREG;
            regmap_pre[k+1][HOST_CCREG]=CCREG;
            regs[k+1].wasdirty|=1<<HOST_CCREG;
            regs[k].dirty|=1<<HOST_CCREG;
            regs[k].wasdoingcp&=~(1<<HOST_CCREG);
            regs[k].isdoingcp&=~(1<<HOST_CCREG);
            k++;
          }
          regs[j].regmap_entry[HOST_CCREG]=CCREG;          
        }
        // Work backwards from the branch target
        if(j>i&&f_regmap[HOST_CCREG]==CCREG)
        {
          //printf("Extend backwards\n");
          int k;
          k=i;
          while(regs[k-1].regmap[HOST_CCREG]==-1) {
            if(count_free_regs(regs[k-1].regmap)<=minimum_free_regs[k-1]) {
              //printf("no free regs for store %x\n",start+(k-1)*4);
              break;
            }
            k--;
          }
          if(regs[k-1].regmap[HOST_CCREG]==CCREG) {
            //printf("Extend CC, %x ->\n",start+k*4);
            while(k<=i) {
              regs[k].regmap_entry[HOST_CCREG]=CCREG;
              regs[k].regmap[HOST_CCREG]=CCREG;
              regmap_pre[k+1][HOST_CCREG]=CCREG;
              regs[k+1].wasdirty|=1<<HOST_CCREG;
              regs[k].dirty|=1<<HOST_CCREG;
              regs[k].wasdoingcp&=~(1<<HOST_CCREG);
              regs[k].isdoingcp&=~(1<<HOST_CCREG);
              k++;
            }
          }
          else {
            //printf("Fail Extend CC, %x ->\n",start+k*4);
          }
        }
      }
      // Don't try to add registers to complex instructions like MAC, division, etc.
      if(itype[i]!=STORE&&itype[i]!=RMW&&itype[i]!=PCREL&&
         itype[i]!=NOP&&itype[i]!=MOV&&itype[i]!=ALU&&itype[i]!=SHIFTIMM&&
         itype[i]!=IMM8&&itype[i]!=LOAD&&itype[i]!=EXT&&itype[i]!=FLAGS)
      {
        memcpy(f_regmap,regs[i].regmap,sizeof(f_regmap));
      }
    }
  }
  
  // Cache memory_map pointer if a register is available
  #ifndef HOST_IMM_ADDR32
  {
    int earliest_available[HOST_REGS];
    int loop_start[HOST_REGS];
    int score[HOST_REGS];
    int end[HOST_REGS];
    int reg=MMREG;

    // Init
    for(hr=0;hr<HOST_REGS;hr++) {
      score[hr]=0;earliest_available[hr]=0;
      loop_start[hr]=MAXBLOCK;
    }
    for(i=0;i<slen-1;i++)
    {
      // Can't do anything if no registers are available
      if(count_free_regs(regs[i].regmap)<=minimum_free_regs[i]) {
        for(hr=0;hr<HOST_REGS;hr++) {
          score[hr]=0;earliest_available[hr]=i+1;
          loop_start[hr]=MAXBLOCK;
        }
      }
      if(itype[i]==UJUMP||itype[i]==RJUMP||itype[i]==SJUMP) {
        if(!ooo[i]) {
          if(count_free_regs(branch_regs[i].regmap)<=minimum_free_regs[i+1]) {
            for(hr=0;hr<HOST_REGS;hr++) {
              score[hr]=0;earliest_available[hr]=i+1;
              loop_start[hr]=MAXBLOCK;
            }
          }
        }else{
          if(count_free_regs(regs[i].regmap)<=minimum_free_regs[i+1]) {
            for(hr=0;hr<HOST_REGS;hr++) {
              score[hr]=0;earliest_available[hr]=i+1;
              loop_start[hr]=MAXBLOCK;
            }
          }
        }
      }
      // Mark unavailable registers
      for(hr=0;hr<HOST_REGS;hr++) {
        if(regs[i].regmap[hr]>=0) {
          score[hr]=0;earliest_available[hr]=i+1;
          loop_start[hr]=MAXBLOCK;
        }
        if(itype[i]==UJUMP||itype[i]==RJUMP||itype[i]==SJUMP) {
          if(branch_regs[i].regmap[hr]>=0) {
            score[hr]=0;earliest_available[hr]=i+2;
            loop_start[hr]=MAXBLOCK;
          }
        }
      }
      // No register allocations after unconditional jumps
      if(itype[i]==UJUMP||itype[i]==RJUMP)
      {
        for(hr=0;hr<HOST_REGS;hr++) {
          score[hr]=0;earliest_available[hr]=i+2;
          loop_start[hr]=MAXBLOCK;
        }
        i++; // Skip delay slot too
        //printf("skip delay slot: %x\n",start+i*4);
      }
      else
      // Possible match
      if(itype[i]==LOAD||itype[i]==STORE||itype[i]==RMW) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(hr!=EXCLUDE_REG) {
            end[hr]=i-1;
            for(j=i;j<slen-1;j++) {
              if(regs[j].regmap[hr]>=0) break;
              if(itype[j]==UJUMP||itype[j]==RJUMP||itype[j]==SJUMP) {
                if(branch_regs[j].regmap[hr]>=0) break;
                if(ooo[j]) {
                  if(count_free_regs(regs[j].regmap)<=minimum_free_regs[j+1]) break;
                }else{
                  if(count_free_regs(branch_regs[j].regmap)<=minimum_free_regs[j+1]) break;
                }
              }
              else if(count_free_regs(regs[j].regmap)<=minimum_free_regs[j]) break;
              if(itype[j]==UJUMP||itype[j]==RJUMP||itype[j]==CJUMP||itype[j]==SJUMP) {
                int t=(ba[j]-start)>>1;
                if(t<j&&t>=earliest_available[hr]) {
                  if(t==1||(t>1&&itype[t-2]!=UJUMP&&itype[t-2]!=RJUMP)||(t>1&&rt1[t-2]!=PR)) { // call/ret assumes no registers allocated
                    // Score a point for hoisting loop invariant
                    if(t<loop_start[hr]) loop_start[hr]=t;
                    //printf("set loop_start: i=%x j=%x (%x)\n",start+i*2,start+j*2,start+t*2);
                    score[hr]++;
                    end[hr]=j;
                  }
                }
                else if(t<j) {
                  if(regs[t].regmap[hr]==reg) {
                    // Score a point if the branch target matches this register
                    score[hr]++;
                    end[hr]=j;
                  }
                }
                if(itype[j+1]==LOAD||itype[j+1]==STORE||itype[j+1]==RMW) {
                  score[hr]++;
                  end[hr]=j;
                }
              }
              if(itype[j]==UJUMP||itype[j]==RJUMP)
              {
                // Stop on unconditional branch
                break;
              }
              else
              if(itype[j]==LOAD||itype[j]==STORE||itype[j]==RMW) {
                score[hr]++;
                end[hr]=j;
              }
            }
          }
        }
        // Find highest score and allocate that register
        int maxscore=0;
        for(hr=0;hr<HOST_REGS;hr++) {
          if(hr!=EXCLUDE_REG) {
            if(score[hr]>score[maxscore]) {
              maxscore=hr;
              //printf("highest score: %d %d (%x->%x)\n",score[hr],hr,start+i*2,start+end[hr]*2);
            }
          }
        }
        if(score[maxscore]>1)
        {
          if(i<loop_start[maxscore]) loop_start[maxscore]=i;
          for(j=loop_start[maxscore];j<slen&&j<=end[maxscore];j++) {
            //if(regs[j].regmap[maxscore]>=0) {printf("oops: %x %x was %d=%d\n",loop_start[maxscore]*2+start,j*2+start,maxscore,regs[j].regmap[maxscore]);}
            assert(regs[j].regmap[maxscore]<0);
            if(j>loop_start[maxscore]) regs[j].regmap_entry[maxscore]=reg;
            regs[j].regmap[maxscore]=reg;
            regs[j].dirty&=~(1<<maxscore);
            regs[j].wasdoingcp&=~(1<<maxscore);
            regs[j].isdoingcp&=~(1<<maxscore);
            if(itype[j]==UJUMP||itype[j]==RJUMP||itype[j]==CJUMP||itype[j]==SJUMP) {
              if(itype[j]!=CJUMP) {
                branch_regs[j].regmap[maxscore]=reg;
                branch_regs[j].wasdirty&=~(1<<maxscore);
                branch_regs[j].dirty&=~(1<<maxscore);
                branch_regs[j].wasdoingcp&=~(1<<maxscore);
                branch_regs[j].isdoingcp&=~(1<<maxscore);
                if(itype[j]==SJUMP) {
                  regmap_pre[j+2][maxscore]=reg;
                  regs[j+2].wasdirty&=~(1<<maxscore);
                }
              }
              else { // if(itype[j]==CJUMP)
                regmap_pre[j+1][maxscore]=reg;
                regs[j+1].wasdirty&=~(1<<maxscore);
              }
              // loop optimization (loop_preload)
              int t=(ba[j]-start)>>1;
              if(t==loop_start[maxscore]) {
                if(t==1||(t>1&&itype[t-2]!=UJUMP&&itype[t-2]!=RJUMP)||(t>1&&rt1[t-2]!=PR)) // call/ret assumes no registers allocated
                  regs[t].regmap_entry[maxscore]=reg;
              }
            }
            else
            {
              if(j<1||(itype[j-1]!=RJUMP&&itype[j-1]!=UJUMP&&itype[j-1]!=SJUMP)) {
                regmap_pre[j+1][maxscore]=reg;
                regs[j+1].wasdirty&=~(1<<maxscore);
              }
            }
          }
          i=j-1;
          if(itype[j-1]==RJUMP||itype[j-1]==UJUMP||itype[j-1]==SJUMP) i++; // skip delay slot
          for(hr=0;hr<HOST_REGS;hr++) {
            score[hr]=0;earliest_available[hr]=i+i;
            loop_start[hr]=MAXBLOCK;
          }
        }
      }
    }
  }
  #endif
  
  // This allocates registers (if possible) one instruction prior
  // to use, which can avoid a load-use penalty on certain CPUs.
  for(i=0;i<slen-1;i++)
  {
    if(!i||(itype[i-1]!=UJUMP&&itype[i-1]!=CJUMP&&itype[i-1]!=SJUMP&&itype[i-1]!=RJUMP))
    {
      if(!bt[i+1])
      {
        if(itype[i]==LOAD||itype[i]==PCREL||itype[i]==MOV||itype[i]==ALU||itype[i]==SHIFTIMM||itype[i]==IMM8||itype[i]==EXT||itype[i]==FLAGS)
        {
          if(rs1[i+1]>=0) {
            if((hr=get_reg(regs[i+1].regmap,rs1[i+1]==TBIT?SR:rs1[i+1]))>=0)
            {
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=regs[i+1].regmap[hr];
                regmap_pre[i+1][hr]=regs[i+1].regmap[hr];
                regs[i+1].regmap_entry[hr]=regs[i+1].regmap[hr];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          if(rs2[i+1]>=0) {
            if((hr=get_reg(regs[i+1].regmap,rs2[i+1]==TBIT?SR:rs2[i+1]))>=0)
            {
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=regs[i+1].regmap[hr];
                regmap_pre[i+1][hr]=regs[i+1].regmap[hr];
                regs[i+1].regmap_entry[hr]=regs[i+1].regmap[hr];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          if(rs3[i+1]>=0) {
            if((hr=get_reg(regs[i+1].regmap,rs3[i+1]==TBIT?SR:rs3[i+1]))>=0)
            {
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=regs[i+1].regmap[hr];
                regmap_pre[i+1][hr]=regs[i+1].regmap[hr];
                regs[i+1].regmap_entry[hr]=regs[i+1].regmap[hr];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          if(rt1[i+1]==TBIT||rt2[i+1]==TBIT) {
            if(rt1[i+1]!=SR&&rt2[i+1]!=SR)
            if((hr=get_reg(regs[i+1].regmap,SR))>=0)
            {
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=regs[i+1].regmap[hr];
                regmap_pre[i+1][hr]=regs[i+1].regmap[hr];
                regs[i+1].regmap_entry[hr]=regs[i+1].regmap[hr];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          // Preload target address for load instruction (non-constant)
          if(itype[i+1]==LOAD&&rs1[i+1]>=0&&get_reg(regs[i+1].regmap,rs1[i+1])<0) {
            if((hr=get_reg(regs[i+1].regmap,rt1[i+1]))>=0)
            {
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=rs1[i+1];
                regmap_pre[i+1][hr]=rs1[i+1];
                regs[i+1].regmap_entry[hr]=rs1[i+1];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          #if 0
          // Load source into target register (not implemented)
          if(lt1[i+1]>=0&&get_reg(regs[i+1].regmap,rs1[i+1])<0) {
            if((hr=get_reg(regs[i+1].regmap,rt1[i+1]))>=0)
            {
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=rs1[i+1];
                regmap_pre[i+1][hr]=rs1[i+1];
                regs[i+1].regmap_entry[hr]=rs1[i+1];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          #endif
          #ifndef HOST_IMM_ADDR32
          // Preload map address
          if(itype[i+1]==LOAD||itype[i+1]==STORE) {
            hr=get_reg(regs[i+1].regmap,MOREG);
            if(hr>=0) {
              int sr=get_reg(regs[i+1].regmap,rs1[i+1]);
              if(sr>=0&&((regs[i+1].wasdoingcp>>sr)&1)
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) {
                int nr;
                if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0)
                {
                  regs[i].regmap[hr]=MGEN1+((i+1)&1);
                  regmap_pre[i+1][hr]=MGEN1+((i+1)&1);
                  regs[i+1].regmap_entry[hr]=MGEN1+((i+1)&1);
                  regs[i].isdoingcp&=~(1<<hr);
                  regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                  cpmap[i][hr]=cpmap[i+1][hr];
                  regs[i+1].wasdirty&=~(1<<hr);
                  regs[i].dirty&=~(1<<hr);
                }
                else if((nr=get_reg2(regs[i].regmap,regs[i+1].regmap,-1))>=0)
                {
                  // move it to another register
                  regs[i+1].regmap[hr]=-1;
                  regmap_pre[i+2][hr]=-1;
                  regs[i+1].regmap[nr]=MOREG;
                  regmap_pre[i+2][nr]=MOREG;
                  regs[i].regmap[nr]=MGEN1+((i+1)&1);
                  regmap_pre[i+1][nr]=MGEN1+((i+1)&1);
                  regs[i+1].regmap_entry[nr]=MGEN1+((i+1)&1);
                  regs[i].isdoingcp&=~(1<<nr);
                  regs[i+1].isdoingcp&=~(1<<nr);
                  regs[i].dirty&=~(1<<nr);
                  regs[i+1].wasdirty&=~(1<<nr);
                  regs[i+1].dirty&=~(1<<nr);
                  regs[i+2].wasdirty&=~(1<<nr);
                }
              }
            }
          }
          #endif
          // Address for store instruction (non-constant)
          if(itype[i+1]==STORE) {
            if(get_reg(regs[i+1].regmap,rs1[i+1])<0) {
              hr=get_reg2(regs[i].regmap,regs[i+1].regmap,-1);
              if(hr<0) hr=get_reg(regs[i+1].regmap,-1);
              else {regs[i+1].regmap[hr]=AGEN1+((i+1)&1);regs[i+1].isdoingcp&=~(1<<hr);}
              assert(hr>=0);
              if(regs[i].regmap[hr]<0&&regs[i+1].regmap_entry[hr]<0
                 &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
              {
                regs[i].regmap[hr]=rs1[i+1];
                regmap_pre[i+1][hr]=rs1[i+1];
                regs[i+1].regmap_entry[hr]=rs1[i+1];
                regs[i].isdoingcp&=~(1<<hr);
                regs[i].isdoingcp|=regs[i+1].isdoingcp&(1<<hr);
                cpmap[i][hr]=cpmap[i+1][hr];
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
          // Load/store address (constant)
          if(itype[i+1]==LOAD||itype[i+1]==STORE) {
            if(itype[i+1]==LOAD) 
              hr=get_reg(regs[i+1].regmap,rt1[i+1]);
            if(itype[i+1]==STORE) {
              hr=get_reg(regs[i+1].regmap,AGEN1+((i+1)&1));
              if(hr<0) hr=get_reg(regs[i+1].regmap,-1);
            }
            if(hr>=0&&regs[i].regmap[hr]<0
               &&count_free_regs(regs[i].regmap)>minimum_free_regs[i]) 
            {
              int rs=get_reg(regs[i+1].regmap,rs1[i+1]);
              if(rs>=0&&((regs[i+1].wasdoingcp>>rs)&1)) {
                regs[i].regmap[hr]=AGEN1+((i+1)&1);
                regmap_pre[i+1][hr]=AGEN1+((i+1)&1);
                regs[i+1].regmap_entry[hr]=AGEN1+((i+1)&1);
                regs[i].isdoingcp&=~(1<<hr);
                regs[i+1].wasdirty&=~(1<<hr);
                regs[i].dirty&=~(1<<hr);
              }
            }
          }
        }
      }
    }
  }
  }
  
  /* Pass 6 - Optimize clean/dirty state */
  clean_registers(0,slen-1,1);

  /* Pass 7 - Identify interrupt return locations */
  
  for (i=slen-1;i>=0;i--)
  {
    if(itype[i]==CJUMP||itype[i]==SJUMP)
    {
      // Avoid unnecessary constant propagation
      int hr;
      u32 sregs;
      for(hr=0;hr<HOST_REGS;hr++) {
        if(hr!=EXCLUDE_REG) {
          if(regs[i].regmap_entry[hr]>=0) {
            if(itype[i]==SJUMP) {
              if(regs[i].regmap_entry[hr]==rs1[i+1]) continue;
              if(regs[i].regmap_entry[hr]==rs2[i+1]) continue;
              if(regs[i].regmap_entry[hr]==rs3[i+1]) continue;
              if(regs[i].regmap_entry[hr]==rt1[i+1]) continue;
              if(regs[i].regmap_entry[hr]==rt2[i+1]) continue;
            }
            if(i>0) {
              if(regs[i].regmap_entry[hr]==rs1[i-1]) continue;
              if(regs[i].regmap_entry[hr]==rs2[i-1]) continue;
              if(regs[i].regmap_entry[hr]==rs3[i-1]) continue;
              if(regs[i].regmap_entry[hr]==rt1[i-1]) continue;
              if(regs[i].regmap_entry[hr]==rt2[i-1]) continue;
            }
            //if(regs[i].wasdoingcp&(1<<hr)) printf("drop wcp: %x\n",start+i*2);
            //if(regs[i].isdoingcp&(1<<hr)) printf("drop icp: %x\n",start+i*2);
            regs[i].wasdoingcp&=~(1<<hr);
            regs[i].isdoingcp&=~(1<<hr);
          }
        }
      }
      sregs=0;
      if(itype[i]==SJUMP)
      {
        // Don't intervene if constant propagation is being performed
        // on a register used by an instruction in the delay slot
        if(itype[i+1]==LOAD) {
          if(rs1[i+1]>=0) sregs|=1<<rs1[i+1];
          if(rs2[i+1]>=0) sregs|=1<<rs2[i+1];
        }
        if(itype[i+1]==STORE) {
          if(rs2[i+1]>=0) sregs|=1<<rs2[i+1];
          if(rs3[i+1]>=0) sregs|=1<<rs3[i+1];
        }
      }
      // If no constant propagation is being done, mark this address as a
      // branch target since it may be called upon return from interrupt
      if(!regs[i].wasdoingcp&&!(regs[i].isconst&sregs))
        bt[i]=1;
    }    
  }

  /* Debug/disassembly */
  if((void*)assem_debug==(void*)printf) 
  for(i=0;i<slen;i++)
  {
    int r;
    printf("U:");
    for(r=0;r<=CCREG;r++) {
      if((unneeded_reg[i]>>r)&1) {
        if(r==SR) printf(" SR(16)");
        else if(r==GBR) printf(" GBR(17)");
        else if(r==VBR) printf(" VBR(18)");
        else if(r==MACH) printf(" MACH(19)");
        else if(r==MACL) printf(" MACL(20)");
        else if(r==PR) printf(" PR(21)");
        else if(r==TBIT) printf(" T(22)");
        else printf(" r%d",r);
      }
    }
    printf("\n");
    #if defined(__i386__) || defined(__x86_64__)
    printf("pre: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",regmap_pre[i][0],regmap_pre[i][1],regmap_pre[i][2],regmap_pre[i][3],regmap_pre[i][5],regmap_pre[i][6],regmap_pre[i][7]);
    #endif
    #ifdef __arm__
    printf("pre: r0=%d r1=%d r2=%d r3=%d r4=%d r5=%d r6=%d r7=%d r8=%d r9=%d r10=%d r12=%d\n",regmap_pre[i][0],regmap_pre[i][1],regmap_pre[i][2],regmap_pre[i][3],regmap_pre[i][4],regmap_pre[i][5],regmap_pre[i][6],regmap_pre[i][7],regmap_pre[i][8],regmap_pre[i][9],regmap_pre[i][10],regmap_pre[i][12]);
    #endif
    printf("needs: ");
    if(needed_reg[i]&1) printf("eax ");
    if((needed_reg[i]>>1)&1) printf("ecx ");
    if((needed_reg[i]>>2)&1) printf("edx ");
    if((needed_reg[i]>>3)&1) printf("ebx ");
    if((needed_reg[i]>>5)&1) printf("ebp ");
    if((needed_reg[i]>>6)&1) printf("esi ");
    if((needed_reg[i]>>7)&1) printf("edi ");
    printf("\n");
    #if defined(__i386__) || defined(__x86_64__)
    printf("entry: eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d\n",regs[i].regmap_entry[0],regs[i].regmap_entry[1],regs[i].regmap_entry[2],regs[i].regmap_entry[3],regs[i].regmap_entry[5],regs[i].regmap_entry[6],regs[i].regmap_entry[7]);
    printf("dirty: ");
    if(regs[i].wasdirty&1) printf("eax ");
    if((regs[i].wasdirty>>1)&1) printf("ecx ");
    if((regs[i].wasdirty>>2)&1) printf("edx ");
    if((regs[i].wasdirty>>3)&1) printf("ebx ");
    if((regs[i].wasdirty>>5)&1) printf("ebp ");
    if((regs[i].wasdirty>>6)&1) printf("esi ");
    if((regs[i].wasdirty>>7)&1) printf("edi ");
    #endif
    #ifdef __arm__
    printf("entry: r0=%d r1=%d r2=%d r3=%d r4=%d r5=%d r6=%d r7=%d r8=%d r9=%d r10=%d r12=%d\n",regs[i].regmap_entry[0],regs[i].regmap_entry[1],regs[i].regmap_entry[2],regs[i].regmap_entry[3],regs[i].regmap_entry[4],regs[i].regmap_entry[5],regs[i].regmap_entry[6],regs[i].regmap_entry[7],regs[i].regmap_entry[8],regs[i].regmap_entry[9],regs[i].regmap_entry[10],regs[i].regmap_entry[12]);
    printf("dirty: ");
    if(regs[i].wasdirty&1) printf("r0 ");
    if((regs[i].wasdirty>>1)&1) printf("r1 ");
    if((regs[i].wasdirty>>2)&1) printf("r2 ");
    if((regs[i].wasdirty>>3)&1) printf("r3 ");
    if((regs[i].wasdirty>>4)&1) printf("r4 ");
    if((regs[i].wasdirty>>5)&1) printf("r5 ");
    if((regs[i].wasdirty>>6)&1) printf("r6 ");
    if((regs[i].wasdirty>>7)&1) printf("r7 ");
    if((regs[i].wasdirty>>8)&1) printf("r8 ");
    if((regs[i].wasdirty>>9)&1) printf("r9 ");
    if((regs[i].wasdirty>>10)&1) printf("r10 ");
    if((regs[i].wasdirty>>12)&1) printf("r12 ");
    #endif
    printf("ccadj=%d",ccadj[i]);
    printf("\n");
    disassemble_inst(i);
    //printf ("ccadj[%d] = %d\n",i,ccadj[i]);
    #if defined(__i386__) || defined(__x86_64__)
    printf("eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d dirty: ",regs[i].regmap[0],regs[i].regmap[1],regs[i].regmap[2],regs[i].regmap[3],regs[i].regmap[5],regs[i].regmap[6],regs[i].regmap[7]);
    if(regs[i].dirty&1) printf("eax ");
    if((regs[i].dirty>>1)&1) printf("ecx ");
    if((regs[i].dirty>>2)&1) printf("edx ");
    if((regs[i].dirty>>3)&1) printf("ebx ");
    if((regs[i].dirty>>5)&1) printf("ebp ");
    if((regs[i].dirty>>6)&1) printf("esi ");
    if((regs[i].dirty>>7)&1) printf("edi ");
    #endif
    #ifdef __arm__
    printf("r0=%d r1=%d r2=%d r3=%d r4=%d r5=%d r6=%d r7=%d r8=%d r9=%d r10=%d r12=%d dirty: ",regs[i].regmap[0],regs[i].regmap[1],regs[i].regmap[2],regs[i].regmap[3],regs[i].regmap[4],regs[i].regmap[5],regs[i].regmap[6],regs[i].regmap[7],regs[i].regmap[8],regs[i].regmap[9],regs[i].regmap[10],regs[i].regmap[12]);
    if(regs[i].dirty&1) printf("r0 ");
    if((regs[i].dirty>>1)&1) printf("r1 ");
    if((regs[i].dirty>>2)&1) printf("r2 ");
    if((regs[i].dirty>>3)&1) printf("r3 ");
    if((regs[i].dirty>>4)&1) printf("r4 ");
    if((regs[i].dirty>>5)&1) printf("r5 ");
    if((regs[i].dirty>>6)&1) printf("r6 ");
    if((regs[i].dirty>>7)&1) printf("r7 ");
    if((regs[i].dirty>>8)&1) printf("r8 ");
    if((regs[i].dirty>>9)&1) printf("r9 ");
    if((regs[i].dirty>>10)&1) printf("r10 ");
    if((regs[i].dirty>>12)&1) printf("r12 ");
    #endif
    printf("\n");
    if(regs[i].isdoingcp) {
      printf("constants: ");
      #if defined(__i386__) || defined(__x86_64__)
      if(regs[i].isdoingcp&1) printf("eax=%x ",(int)cpmap[i][0]);
      if((regs[i].isdoingcp>>1)&1) printf("ecx=%x ",(int)cpmap[i][1]);
      if((regs[i].isdoingcp>>2)&1) printf("edx=%x ",(int)cpmap[i][2]);
      if((regs[i].isdoingcp>>3)&1) printf("ebx=%x ",(int)cpmap[i][3]);
      if((regs[i].isdoingcp>>5)&1) printf("ebp=%x ",(int)cpmap[i][5]);
      if((regs[i].isdoingcp>>6)&1) printf("esi=%x ",(int)cpmap[i][6]);
      if((regs[i].isdoingcp>>7)&1) printf("edi=%x ",(int)cpmap[i][7]);
      #endif
      #ifdef __arm__
      if(regs[i].isdoingcp&1) printf("r0=%x ",(int)cpmap[i][0]);
      if((regs[i].isdoingcp>>1)&1) printf("r1=%x ",(int)cpmap[i][1]);
      if((regs[i].isdoingcp>>2)&1) printf("r2=%x ",(int)cpmap[i][2]);
      if((regs[i].isdoingcp>>3)&1) printf("r3=%x ",(int)cpmap[i][3]);
      if((regs[i].isdoingcp>>4)&1) printf("r4=%x ",(int)cpmap[i][4]);
      if((regs[i].isdoingcp>>5)&1) printf("r5=%x ",(int)cpmap[i][5]);
      if((regs[i].isdoingcp>>6)&1) printf("r6=%x ",(int)cpmap[i][6]);
      if((regs[i].isdoingcp>>7)&1) printf("r7=%x ",(int)cpmap[i][7]);
      if((regs[i].isdoingcp>>8)&1) printf("r8=%x ",(int)cpmap[i][8]);
      if((regs[i].isdoingcp>>9)&1) printf("r9=%x ",(int)cpmap[i][9]);
      if((regs[i].isdoingcp>>10)&1) printf("r10=%x ",(int)cpmap[i][10]);
      if((regs[i].isdoingcp>>12)&1) printf("r12=%x ",(int)cpmap[i][12]);
      #endif
      printf("\n");
    }
    if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==CJUMP||itype[i]==SJUMP) {
      #if defined(__i386__) || defined(__x86_64__)
      printf("branch(%d): eax=%d ecx=%d edx=%d ebx=%d ebp=%d esi=%d edi=%d dirty: ",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7]);
      if(branch_regs[i].dirty&1) printf("eax ");
      if((branch_regs[i].dirty>>1)&1) printf("ecx ");
      if((branch_regs[i].dirty>>2)&1) printf("edx ");
      if((branch_regs[i].dirty>>3)&1) printf("ebx ");
      if((branch_regs[i].dirty>>5)&1) printf("ebp ");
      if((branch_regs[i].dirty>>6)&1) printf("esi ");
      if((branch_regs[i].dirty>>7)&1) printf("edi ");
      #endif
      #ifdef __arm__
      printf("branch(%d): r0=%d r1=%d r2=%d r3=%d r4=%d r5=%d r6=%d r7=%d r8=%d r9=%d r10=%d r12=%d dirty: ",i,branch_regs[i].regmap[0],branch_regs[i].regmap[1],branch_regs[i].regmap[2],branch_regs[i].regmap[3],branch_regs[i].regmap[4],branch_regs[i].regmap[5],branch_regs[i].regmap[6],branch_regs[i].regmap[7],branch_regs[i].regmap[8],branch_regs[i].regmap[9],branch_regs[i].regmap[10],branch_regs[i].regmap[12]);
      if(branch_regs[i].dirty&1) printf("r0 ");
      if((branch_regs[i].dirty>>1)&1) printf("r1 ");
      if((branch_regs[i].dirty>>2)&1) printf("r2 ");
      if((branch_regs[i].dirty>>3)&1) printf("r3 ");
      if((branch_regs[i].dirty>>4)&1) printf("r4 ");
      if((branch_regs[i].dirty>>5)&1) printf("r5 ");
      if((branch_regs[i].dirty>>6)&1) printf("r6 ");
      if((branch_regs[i].dirty>>7)&1) printf("r7 ");
      if((branch_regs[i].dirty>>8)&1) printf("r8 ");
      if((branch_regs[i].dirty>>9)&1) printf("r9 ");
      if((branch_regs[i].dirty>>10)&1) printf("r10 ");
      if((branch_regs[i].dirty>>12)&1) printf("r12 ");
      #endif
      printf("\n");
    }
  }

  /* Pass 8 - Assembly */
  {
  u32 dirty_pre=0;
  linkcount=0;stubcount=0;
  ds=0;is_delayslot=0;
  beginning=(pointer)out;
  for(i=0;i<slen;i++)
  {
    //if(ds) printf("ds: ");
    if((void*)assem_debug==(void*)printf) disassemble_inst(i);
    if(ds) {
      ds=0; // Skip delay slot
      if(bt[i]) assem_debug("OOPS - branch into delay slot\n");
      instr_addr[i]=0;
    } else {
      int srloaded;

      if(i<2||(itype[i-2]!=UJUMP&&itype[i-2]!=RJUMP&&itype[i-1]!=DATA))
      {
        wb_valid(regmap_pre[i],regs[i].regmap_entry,dirty_pre,regs[i].wasdirty,
              unneeded_reg[i]);
      }
      if(itype[i]==SJUMP) dirty_pre=branch_regs[i].dirty;
      else dirty_pre=regs[i].dirty;
      // write back
      if(i<2||(itype[i-2]!=UJUMP&&itype[i-2]!=RJUMP&&itype[i-1]!=DATA))
      {
        wb_invalidate(regmap_pre[i],regs[i].regmap_entry,regs[i].wasdirty,
                      unneeded_reg[i]);
        loop_preload(regmap_pre[i],regs[i].regmap_entry);
      }
      // branch target entry point
      instr_addr[i]=(pointer)out;
      assem_debug("<->\n");
      // load regs
      if(regs[i].regmap_entry[HOST_CCREG]==CCREG&&regs[i].regmap[HOST_CCREG]!=CCREG)
        wb_register(CCREG,regs[i].regmap_entry,regs[i].wasdirty);
      load_regs(regs[i].regmap_entry,regs[i].regmap,rs1[i],rs2[i],rs3[i]);
      srloaded=(rs1[i]==TBIT||rs2[i]==TBIT||rs3[i]==TBIT||rs1[i]==SR||rs2[i]==SR||rs3[i]==SR);
      if(rt1[i]==TBIT||rt2[i]==TBIT)
        if(!srloaded&&rt1[i]!=SR&&rt2[i]!=SR)
          {srloaded=1;load_regs(regs[i].regmap_entry,regs[i].regmap,SR,SR,SR);}
      address_generation(i,&regs[i],regs[i].regmap_entry);
      load_consts(regmap_pre[i],regs[i].regmap,i);
      if(itype[i]==RJUMP||itype[i]==UJUMP||itype[i]==SJUMP)
      {
        // Load the delay slot registers if necessary
        if(!srloaded&&rt1[i+1]!=SR&&rt2[i+1]!=SR&&(rt1[i+1]==TBIT||rt2[i+1]==TBIT))
          {srloaded=1;load_regs(regs[i].regmap_entry,regs[i].regmap,SR,SR,SR);}

        if(rs1[i+1]!=rs1[i]&&rs1[i+1]!=rs2[i]&&rs1[i+1]!=rs3[i])
          if(!srloaded||(rs1[i+1]!=TBIT&&rs1[i+1]!=SR))
            load_regs(regs[i].regmap_entry,regs[i].regmap,rs1[i+1],rs1[i+1],rs1[i+1]);

        if(rs2[i+1]!=rs1[i+1]&&rs2[i+1]!=rs1[i]&&rs2[i+1]!=rs2[i]&&rs2[i+1]!=rs3[i])
          if(!srloaded||(rs2[i+1]!=TBIT&&rs2[i+1]!=SR))
            load_regs(regs[i].regmap_entry,regs[i].regmap,rs2[i+1],rs2[i+1],rs2[i+1]);

        if(rs3[i+1]!=rs1[i+1]&&rs3[i+1]!=rs2[i+1]&&rs3[i+1]!=rs1[i]&&rs3[i+1]!=rs2[i]&&rs3[i+1]!=rs3[i])
          if(!srloaded||(rs3[i+1]!=TBIT&&rs3[i+1]!=SR))
            load_regs(regs[i].regmap_entry,regs[i].regmap,rs3[i+1],rs3[i+1],rs3[i+1]);
      }
      else if(i+1<slen)
      {
        signed char preload1, preload2, preload3;
        // Preload registers for following instruction
        preload1=rs1[i+1];
        if(preload1==TBIT||preload1==SR) {
          if(!srloaded) {preload1=SR;srloaded=1;}
          else preload1=-1;
        }
        if(preload1!=rs1[i]&&preload1!=rs2[i]&&preload1!=rs3[i])
          if(preload1!=rt1[i]&&preload1!=rt2[i])
            load_regs(regs[i].regmap_entry,regs[i].regmap,preload1,preload1,preload1);
        preload2=rs2[i+1];
        if(preload2==TBIT||preload2==SR) {
          if(!srloaded) {preload2=SR;srloaded=1;}
          else preload2=-1;
        }
        if(preload2!=rs1[i+1]&&preload2!=rs1[i]&&preload2!=rs2[i]&&preload2!=rs3[i])
          if(preload2!=rt1[i]&&preload2!=rt2[i])
            load_regs(regs[i].regmap_entry,regs[i].regmap,preload2,preload2,preload2);
        preload3=rs3[i+1];
        if(preload3==TBIT||preload3==SR) {
          if(!srloaded) {preload3=SR;srloaded=1;}
          else preload3=-1;
        }
        if(preload3!=rs1[i+1]&&preload3!=rs2[i+1]&&preload3!=rs1[i]&&preload3!=rs2[i]&&preload3!=rs3[i])
          if(preload3!=rt1[i]&&preload3!=rt2[i])
            load_regs(regs[i].regmap_entry,regs[i].regmap,preload3,preload3,preload3);
        if(rt1[i+1]==TBIT||rt2[i+1]==TBIT)
          if(!srloaded&&rt1[i]!=SR&&rt2[i]!=SR&&rt1[i+1]!=SR&&rt2[i+1]!=SR)
            {srloaded=1;load_regs(regs[i].regmap_entry,regs[i].regmap,SR,SR,SR);}
      }
      // TODO: if(is_ooo(i)) address_generation(i+1);
      if(itype[i]==LOAD||itype[i]==STORE||itype[i]==RMW) 
        load_regs(regs[i].regmap_entry,regs[i].regmap,MMREG,MMREG,MMREG);
      // assemble
      switch(itype[i]) {
        case ALU:
          alu_assemble(i,&regs[i]);break;
        case IMM8:
          imm8_assemble(i,&regs[i]);break;
        case SHIFTIMM:
          shiftimm_assemble(i,&regs[i]);break;
        case LOAD:
          load_assemble(i,&regs[i]);break;
        case STORE:
          store_assemble(i,&regs[i]);break;
        case RMW:
          rmw_assemble(i,&regs[i]);break;
        case PCREL:
          pcrel_assemble(i,&regs[i]);break;
        case MULTDIV:
          multdiv_assemble(i,&regs[i]);break;
        case MOV:
          mov_assemble(i,&regs[i]);break;
        case EXT:
          ext_assemble(i,&regs[i]);break;
        case FLAGS:
          flags_assemble(i,&regs[i]);break;
        case COMPLEX:
          complex_assemble(i,&regs[i]);break;
        case SYSTEM:
          system_assemble(i,&regs[i]);break;
        case BIOS:
          bios_assemble(i,&regs[i]);break;
        case UJUMP:
          ujump_assemble(i,&regs[i]);ds=1;break;
        case RJUMP:
          rjump_assemble(i,&regs[i]);ds=1;break;
        case CJUMP:
          cjump_assemble(i,&regs[i]);break;
        case SJUMP:
          sjump_assemble(i,&regs[i]);ds=1;break;
      }
      if(itype[i]==UJUMP||itype[i]==RJUMP||(source[i]>>16)==0x1000)
        literal_pool(1024);
      else
        literal_pool_jumpover(256);
    }
  }
  // If the block did not end with an unconditional branch,
  // add a jump to the next instruction.
  if(i>1) {
    if(itype[i-2]!=UJUMP&&itype[i-2]!=RJUMP&&itype[i-1]!=DATA) {
      assert(i==slen);
      if(itype[i-2]!=SJUMP) {
        store_regs_bt(regs[i-1].regmap,regs[i-1].dirty,start+i*2);
        if(regs[i-1].regmap[HOST_CCREG]!=CCREG)
          emit_loadreg(CCREG,HOST_CCREG);
        emit_addimm(HOST_CCREG,CLOCK_DIVIDER*(ccadj[i-1]+1),HOST_CCREG);
      }
      else
      {
        store_regs_bt(regs[i-2].regmap,regs[i-2].dirty,start+i*2);
        assert(regs[i-2].regmap[HOST_CCREG]==CCREG);
      }
      add_to_linker((int)out,start+i*2,0);
      emit_jmp(0);
    }
  }
  else
  {
    assert(i>0);
    store_regs_bt(regs[i-1].regmap,regs[i-1].dirty,start+i*2);
    if(regs[i-1].regmap[HOST_CCREG]!=CCREG)
      emit_loadreg(CCREG,HOST_CCREG);
    emit_addimm(HOST_CCREG,CLOCK_DIVIDER*(ccadj[i-1]+1),HOST_CCREG);
    add_to_linker((int)out,start+i*2,0);
    emit_jmp(0);
  }

  // Stubs
  for(i=0;i<stubcount;i++)
  {
    switch(stubs[i][0])
    {
      case LOADB_STUB:
      case LOADW_STUB:
      case LOADL_STUB:
      case LOADS_STUB:
        do_readstub(i);break;
      case STOREB_STUB:
      case STOREW_STUB:
      case STOREL_STUB:
        do_writestub(i);break;
      case RMWT_STUB:
      case RMWA_STUB:
      case RMWX_STUB:
      case RMWO_STUB:
        do_rmwstub(i);break;
      case CC_STUB:
        do_ccstub(i);break;
    }
  }
  }

  /* Pass 9 - Linker */
  {
  int *ht_bin;
  int entry_point;
  u32 alignedlen;
  u32 alignedstart;
  u32 index;
  for(i=0;i<linkcount;i++)
  {
    assem_debug("%8x -> %8x\n",link_addr[i][0],link_addr[i][1]);
    literal_pool(64);
    if(!link_addr[i][2])
    {
      void *stub=out;
      void *addr=check_addr(link_addr[i][1]);
      emit_extjump(link_addr[i][0],link_addr[i][1]);
      if(addr) {
        set_jump_target(link_addr[i][0],(int)addr);
        add_link(link_addr[i][1],stub);
      }
      else set_jump_target(link_addr[i][0],(int)stub);
    }
    else
    {
      // Internal branch
      int target=(link_addr[i][1]-start)>>1;
      assert(target>=0&&target<slen);
      assert(instr_addr[target]);
      //#ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
      //set_jump_target_fillslot(link_addr[i][0],instr_addr[target],link_addr[i][2]>>1);
      //#else
      set_jump_target(link_addr[i][0],instr_addr[target]);
      //#endif
    }
  }
  // External Branch Targets (jump_in)
  if(copy+slen*2+4>shadow+sizeof(shadow)) copy=shadow;
  for(i=0;i<slen;i++)
  {
    if(bt[i]||i==0)
    {
      if(itype[i]==CJUMP||itype[i]==SJUMP) assert(instr_addr[i]);
      if(instr_addr[i]) // TODO - delay slots (=null)
      {
        u32 vaddr=start+i*2+slave;
        u32 page=(vaddr&0xDFFFFFFF)>>12;
        if(page>1024) page=1024+(page&1023);
        literal_pool(256);
        assem_debug("%8x (%d) <- %8x\n",instr_addr[i],i,start+i*2);
        assem_debug("jump_in: %x\n",start+i*2);
        ll_add(jump_dirty+page,vaddr,(void *)out);
        entry_point=do_dirty_stub(i);
        ll_add_nodup(jump_in+page,vaddr,(void *)entry_point);
        if((itype[i]==CJUMP||itype[i]==SJUMP)&&ccstub_return[i]) set_jump_target(ccstub_return[i],entry_point);

        // If there was an existing entry in the hash table,
        // replace it with the new address.
        // Don't add new entries.  We'll insert the
        // ones that actually get used in check_addr().
        ht_bin=hash_table[((vaddr>>16)^vaddr)&0xFFFF];
        if(ht_bin[0]==vaddr) {
          ht_bin[1]=entry_point;
        }
        if(ht_bin[2]==vaddr) {
          ht_bin[3]=entry_point;
        }
      }
    }
  }
  // Write out the literal pool if necessary
  literal_pool(0);
  #ifdef CORTEX_A8_BRANCH_PREDICTION_HACK
  // Align code
  if(((u32)out)&7) emit_addnop(13);
  #endif
  assert((pointer)out-beginning<MAX_OUTPUT_BLOCK_SIZE);
  //printf("shadow buffer: %x-%x\n",(int)copy,(int)copy+slen*4);
  alignedlen=((((u32)source)+slen*2+2)&~2)-(u32)alignedsource;
  memcpy(copy,alignedsource,alignedlen);
  copy+=alignedlen;
  
  #ifdef __arm__
  __clear_cache((void *)beginning,out);
  #endif
  
  // If we're within 256K of the end of the buffer,
  // start over from the beginning. (Is 256K enough?)
  if((int)out>BASE_ADDR+(1<<TARGET_SIZE_2)-MAX_OUTPUT_BLOCK_SIZE-JUMP_TABLE_SIZE) out=(u8 *)BASE_ADDR;
  
  // Trap writes to any of the pages we compiled
  for(i=start>>12;i<=(start+slen*2)>>12;i++) {
    //invalid_code[i]=0;
    cached_code[i>>3]|=1<<(i&7);
    cached_code[(i^0x20000)>>3]|=1<<(i&7);
    #ifdef POINTERS_64BIT
    memory_map[i]|=0x4000000000000000LL;
    memory_map[i^0x20000]|=0x4000000000000000LL;
    #else
    memory_map[i]|=0x40000000;
    memory_map[i^0x20000]|=0x40000000;
    #endif
  }
  alignedstart=start&~3;
  index=alignedstart&0xDFFFFFFF;
  if(index>4194304) index=(addr|0x400000)&0x7fffff;
  for(i=0;i<alignedlen;i+=4) {
    cached_code_words[(index+i)>>5]|=1<<(((index+i)>>2)&7);
  }
  }
  
  /* Pass 10 - Free memory by expiring oldest blocks */
  
  {
  int end=((((int)out-BASE_ADDR)>>(TARGET_SIZE_2-16))+16384)&65535;
  while(expirep!=end)
  {
    int shift=TARGET_SIZE_2-3; // Divide into 8 blocks
    int base=BASE_ADDR+((expirep>>13)<<shift); // Base address of this block
    inv_debug("EXP: Phase %d\n",expirep);
    switch((expirep>>11)&3)
    {
      case 0:
        // Clear jump_in and jump_dirty
        ll_remove_matching_addrs(jump_in+(expirep&2047),base,shift);
        ll_remove_matching_addrs(jump_dirty+(expirep&2047),base,shift);
        break;
      case 1:
        // Clear pointers
        ll_kill_pointers(jump_out[expirep&2047],base,shift);
        break;
      case 2:
        // Clear hash table
        for(i=0;i<32;i++) {
          int *ht_bin=hash_table[((expirep&2047)<<5)+i];
          if((ht_bin[3]>>shift)==(base>>shift) ||
             ((ht_bin[3]-MAX_OUTPUT_BLOCK_SIZE)>>shift)==(base>>shift)) {
            inv_debug("EXP: Remove hash %x -> %x\n",ht_bin[2],ht_bin[3]);
            ht_bin[2]=ht_bin[3]=-1;
          }
          if((ht_bin[1]>>shift)==(base>>shift) ||
             ((ht_bin[1]-MAX_OUTPUT_BLOCK_SIZE)>>shift)==(base>>shift)) {
            inv_debug("EXP: Remove hash %x -> %x\n",ht_bin[0],ht_bin[1]);
            ht_bin[0]=ht_bin[2];
            ht_bin[1]=ht_bin[3];
            ht_bin[2]=ht_bin[3]=-1;
          }
        }
        break;
      case 3:
        // Clear jump_out
        if((expirep&2047)==0) {
          #ifdef __arm__
          do_clear_cache();
          #endif
          #ifdef USE_MINI_HT
          memset(mini_ht_master,-1,sizeof(mini_ht_master));
          memset(mini_ht_slave,-1,sizeof(mini_ht_slave));
          #endif
        }
        ll_remove_matching_addrs(jump_out+(expirep&2047),base,shift);
        break;
    }
    expirep=(expirep+1)&65535;
  }
  }
  return 0;
}

#include "../sh2core.h"

extern int framecounter;
void DynarecMasterHandleInterrupts()
{
  if (MSH2->interrupts[MSH2->NumberOfInterrupts-1].level > ((master_reg[SR]>>4)&0xF))
  {
    master_reg[15] -= 4;
    MappedMemoryWriteLong(master_reg[15], master_reg[SR]);
    master_reg[15] -= 4;
    MappedMemoryWriteLong(master_reg[15], master_pc);
    master_reg[SR] &= 0xFFFFFF0F;
    master_reg[SR] |= (MSH2->interrupts[MSH2->NumberOfInterrupts-1].level)<<4;
    master_pc = MappedMemoryReadLong(master_reg[VBR] + (MSH2->interrupts[MSH2->NumberOfInterrupts-1].vector << 2));
    master_ip = get_addr_ht(master_pc);
    MSH2->NumberOfInterrupts--;
    MSH2->isIdle = 0;
    MSH2->isSleeping = 0;
  }
  //printf("DynarecMasterHandleInterrupts pc=%x ip=%x\n",master_pc,(int)master_ip);
  //printf("master_cc=%d slave_cc=%d\n",master_cc,slave_cc);
  //printf("frame=%d\n",framecounter);
}

void DynarecSlaveHandleInterrupts()
{
  if (SSH2->interrupts[SSH2->NumberOfInterrupts-1].level > ((slave_reg[SR]>>4)&0xF))
  {
    slave_reg[15] -= 4;
    MappedMemoryWriteLong(slave_reg[15], slave_reg[SR]);
    slave_reg[15] -= 4;
    MappedMemoryWriteLong(slave_reg[15], slave_pc);
    slave_reg[SR] &= 0xFFFFFF0F;
    slave_reg[SR] |= (SSH2->interrupts[SSH2->NumberOfInterrupts-1].level)<<4;
    slave_pc = MappedMemoryReadLong(slave_reg[VBR] + (SSH2->interrupts[SSH2->NumberOfInterrupts-1].vector << 2));
    slave_ip = get_addr_ht(slave_pc|1);
    SSH2->NumberOfInterrupts--;
    SSH2->isIdle = 0;
    SSH2->isSleeping = 0;
  }
  //printf("DynarecSlaveHandleInterrupts pc=%x ip=%x\n",slave_pc,(int)slave_ip);
  //printf("master_cc=%d slave_cc=%d\n",master_cc,slave_cc);
}

#define SH2CORE_DYNAREC 2

void SH2InterpreterSendInterrupt(SH2_struct *context, u8 level, u8 vector);
int SH2InterpreterGetInterrupts(SH2_struct *context,
                                interrupt_struct interrupts[MAX_INTERRUPTS]);
void SH2InterpreterSetInterrupts(SH2_struct *context, int num_interrupts,
                                 const interrupt_struct interrupts[MAX_INTERRUPTS]);

int SH2DynarecInit(void) {return 0;}

void SH2DynarecDeInit() {
  sh2_dynarec_cleanup();
}
   
void FASTCALL SH2DynarecExec(SH2_struct *context, u32 cycles) {
  printf("SH2DynarecExec called! oops\n");
  printf("master_ip=%x\n",(int)master_ip);
  exit(1);
}

u32 SH2DynarecGetSR(SH2_struct *context)
{
  if(context==MSH2) 
    return master_reg[SR];
  else
    return slave_reg[SR];
}
u32 SH2DynarecGetGBR(SH2_struct *context)
{
  if(context==MSH2) 
    return master_reg[GBR];
  else
    return slave_reg[GBR];
}
u32 SH2DynarecGetVBR(SH2_struct *context)
{
  if(context==MSH2) 
    return master_reg[VBR];
  else
    return slave_reg[VBR];
}
u32 SH2DynarecGetMACH(SH2_struct *context)
{
  if(context==MSH2) 
    return master_reg[MACH];
  else
    return slave_reg[MACH];
}
u32 SH2DynarecGetMACL(SH2_struct *context)
{
  if(context==MSH2) 
    return master_reg[MACL];
  else
    return slave_reg[MACL];
}
u32 SH2DynarecGetPR(SH2_struct *context)
{
  if(context==MSH2) 
    return master_reg[PR];
  else
    return slave_reg[PR];
}
u32 SH2DynarecGetGPR(SH2_struct *context, int num)
{
  if(context==MSH2) 
    return master_reg[num];
  else
    return slave_reg[num];
}

u32 SH2DynarecGetPC(SH2_struct *context)
{
  if(context==MSH2) 
    return master_pc;
  else
    return slave_pc;
}

void SH2DynarecSetSR(SH2_struct *context, u32 value) {
  if(context==MSH2) 
    master_reg[SR]=value;
  else 
    slave_reg[SR]=value;
}
void SH2DynarecSetGBR(SH2_struct *context, u32 value) {
  if(context==MSH2) 
    master_reg[GBR]=value;
  else 
    slave_reg[GBR]=value;
}
void SH2DynarecSetVBR(SH2_struct *context, u32 value) {
  if(context==MSH2) 
    master_reg[VBR]=value;
  else 
    slave_reg[VBR]=value;
}
void SH2DynarecSetMACH(SH2_struct *context, u32 value) {
  if(context==MSH2) 
    master_reg[MACH]=value;
  else 
    slave_reg[MACH]=value;
}
void SH2DynarecSetMACL(SH2_struct *context, u32 value) {
  if(context==MSH2) 
    master_reg[MACL]=value;
  else 
    slave_reg[MACL]=value;
}
void SH2DynarecSetPR(SH2_struct *context, u32 value) {
  if(context==MSH2) 
    master_reg[PR]=value;
  else 
    slave_reg[PR]=value;
}
void SH2DynarecSetGPR(SH2_struct *context, int num, u32 value) {
  if(context==MSH2) 
    master_reg[num]=value;
  else 
    slave_reg[num]=value;
}

void SH2DynarecSetPC(SH2_struct *context, u32 value) {
  //printf("SH2DynarecSetPC(%s,%x)\n",(context==MSH2)?"master":"slave",value);
  if(context==MSH2) {
    master_pc=value;
    master_ip=get_addr_ht(value);
  }
  else {
    slave_pc=value;
    slave_ip=get_addr_ht(value+1);
  }
}

#undef SR
#undef GBR
#undef VBR
#undef MACH
#undef MACL
#undef PR

void SH2DynarecGetRegisters(SH2_struct *context, sh2regs_struct *regs)
{
  if(context==MSH2) 
    memcpy(&(regs->R), master_reg, 16*sizeof(int));
  else 
    memcpy(&(regs->R), slave_reg, 16*sizeof(int));
  regs->SR.all=SH2DynarecGetSR(context);
  regs->GBR=SH2DynarecGetGBR(context);
  regs->VBR=SH2DynarecGetVBR(context);
  regs->MACH=SH2DynarecGetMACH(context);
  regs->MACL=SH2DynarecGetMACL(context);
  regs->PR=SH2DynarecGetPR(context);
  regs->PC=SH2DynarecGetPC(context);
}

void SH2DynarecSetRegisters(SH2_struct *context, const sh2regs_struct *regs)
{
  if(context==MSH2) 
    memcpy(master_reg, &(regs->R), 16*sizeof(int));
  else 
    memcpy(slave_reg, &(regs->R), 16*sizeof(int));
  SH2DynarecSetSR(context, regs->SR.all);
  SH2DynarecSetGBR(context, regs->GBR);
  SH2DynarecSetVBR(context, regs->VBR);
  SH2DynarecSetMACH(context, regs->MACH);
  SH2DynarecSetMACL(context, regs->MACL);
  SH2DynarecSetPR(context, regs->PR);
  SH2DynarecSetPC(context, regs->PC);
}

void SH2DynarecWriteNotify(u32 start, u32 length) {
  int block,wp=0;
  // Ignore non-RAM regions
  if((start&0xDFF00000)!=0x200000&&(start&0xDE000000)!=0x6000000) return;
  // Check if any pages contain compiled code
  for(block=start>>12;block<=(start+length-1)>>12;block++)
    wp|=((cached_code[block>>3]>>(block&7))&1);
  if(!wp) return;
  //printf("SH2DynarecWriteNotify(%x,%x)\n",start,length);
  invalidate_blocks(start>>12,(start+length-1)>>12);
}

SH2Interface_struct SH2Dynarec = {
   SH2CORE_DYNAREC,
   "SH2 Dynamic Recompiler",

   SH2DynarecInit,
   SH2DynarecDeInit,
   SH2DynarecReset,
   SH2DynarecExec,

   SH2DynarecGetRegisters,
   SH2DynarecGetGPR,
   SH2DynarecGetSR,
   SH2DynarecGetGBR,
   SH2DynarecGetVBR,
   SH2DynarecGetMACH,
   SH2DynarecGetMACL,
   SH2DynarecGetPR,
   SH2DynarecGetPC,

   SH2DynarecSetRegisters,
   SH2DynarecSetGPR,
   SH2DynarecSetSR,
   SH2DynarecSetGBR,
   SH2DynarecSetVBR,
   SH2DynarecSetMACH,
   SH2DynarecSetMACL,
   SH2DynarecSetPR,
   SH2DynarecSetPC,

   SH2InterpreterSendInterrupt,
   SH2InterpreterGetInterrupts,
   SH2InterpreterSetInterrupts,

   SH2DynarecWriteNotify
};

u32 * decilinestop_p = &yabsys.DecilineStop;
u32 * decilineusec_p = &yabsys.DecilineUsec;
u32 * SH2CycleFrac_p = &yabsys.SH2CycleFrac;
u32 * UsecFrac_p = &yabsys.UsecFrac;
//u32 decilinecycles = yabsys.DecilineStop >> YABSYS_TIMING_BITS;
u32 yabsys_timing_bits = YABSYS_TIMING_BITS;
u32 yabsys_timing_mask = YABSYS_TIMING_MASK;
int * linecount_p = &yabsys.LineCount;
int * vblanklinecount_p = &yabsys.VBlankLineCount;
int * maxlinecount_p = &yabsys.MaxLineCount;

void * NumberOfInterruptsOffset = &((SH2_struct *)0)->NumberOfInterrupts;
