/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - assem_arm64.c                                           *
 *   Copyright (C) 2009-2018 Gillou68310                                   *
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

#define fp_cycle_count         (offsetof(struct new_dynarec_hot_state, cycle_count))
#define fp_invc_ptr            (offsetof(struct new_dynarec_hot_state, invc_ptr))
#define fp_fcr31               (offsetof(struct new_dynarec_hot_state, fcr31))
#define fp_regs                (offsetof(struct new_dynarec_hot_state, regs))
#define fp_hi                  (offsetof(struct new_dynarec_hot_state, hi))
#define fp_lo                  (offsetof(struct new_dynarec_hot_state, lo))
#define fp_cp0_regs(x)         ((offsetof(struct new_dynarec_hot_state, cp0_regs)) + (x)*sizeof(uint32_t))
#define fp_rounding_modes      (offsetof(struct new_dynarec_hot_state, rounding_modes))
#define fp_fake_pc             (offsetof(struct new_dynarec_hot_state, fake_pc))
#define fp_ram_offset          (offsetof(struct new_dynarec_hot_state, ram_offset))
#define fp_mini_ht             (offsetof(struct new_dynarec_hot_state, mini_ht))
#define fp_memory_map          (offsetof(struct new_dynarec_hot_state, memory_map))

typedef enum {
  COND_EQ,
  COND_NE,
  COND_CS,
  COND_CC,
  COND_MI,
  COND_PL,
  COND_VS,
  COND_VC,
  COND_HI,
  COND_LS,
  COND_GE,
  COND_LT,
  COND_GT,
  COND_LE,
  COND_AW,
  COND_NV
} eCond;

void jump_vaddr_x0(void);
void jump_vaddr_x1(void);
void jump_vaddr_x2(void);
void jump_vaddr_x3(void);
void jump_vaddr_x4(void);
void jump_vaddr_x5(void);
void jump_vaddr_x6(void);
void jump_vaddr_x7(void);
void jump_vaddr_x8(void);
void jump_vaddr_x9(void);
void jump_vaddr_x10(void);
void jump_vaddr_x11(void);
void jump_vaddr_x12(void);
void jump_vaddr_x13(void);
void jump_vaddr_x14(void);
void jump_vaddr_x15(void);
void jump_vaddr_x16(void);
void jump_vaddr_x17(void);
void jump_vaddr_x19(void);
void jump_vaddr_x21(void);
void jump_vaddr_x22(void);
void jump_vaddr_x23(void);
void jump_vaddr_x24(void);
void jump_vaddr_x25(void);
void jump_vaddr_x26(void);
void jump_vaddr_x27(void);
void jump_vaddr_x28(void);
void breakpoint(void);
static void invalidate_addr(u_int addr);

static uintptr_t literals[1024][2];
static unsigned int needs_clear_cache[1<<(TARGET_SIZE_2-17)];

static const uintptr_t jump_vaddr_reg[32] = {
  (intptr_t)jump_vaddr_x0,
  (intptr_t)jump_vaddr_x1,
  (intptr_t)jump_vaddr_x2,
  (intptr_t)jump_vaddr_x3,
  (intptr_t)jump_vaddr_x4,
  (intptr_t)jump_vaddr_x5,
  (intptr_t)jump_vaddr_x6,
  (intptr_t)jump_vaddr_x7,
  (intptr_t)jump_vaddr_x8,
  (intptr_t)jump_vaddr_x9,
  (intptr_t)jump_vaddr_x10,
  (intptr_t)jump_vaddr_x11,
  (intptr_t)jump_vaddr_x12,
  (intptr_t)jump_vaddr_x13,
  (intptr_t)jump_vaddr_x14,
  (intptr_t)jump_vaddr_x15,
  (intptr_t)jump_vaddr_x16,
  (intptr_t)jump_vaddr_x17,
  (intptr_t)breakpoint,     /*trampoline jumps uses x18*/
  (intptr_t)jump_vaddr_x19,
  (intptr_t)breakpoint,     /*cycle count*/
  (intptr_t)jump_vaddr_x21,
  (intptr_t)jump_vaddr_x22,
  (intptr_t)jump_vaddr_x23,
  (intptr_t)jump_vaddr_x24,
  (intptr_t)jump_vaddr_x25,
  (intptr_t)jump_vaddr_x26,
  (intptr_t)jump_vaddr_x27,
  (intptr_t)jump_vaddr_x28,
  (intptr_t)breakpoint,
  (intptr_t)breakpoint,
  (intptr_t)breakpoint};

static uintptr_t jump_table_symbols[] = {
  (intptr_t)NULL /*TLBR*/,
  (intptr_t)NULL /*TLBP*/,
  (intptr_t)NULL /*MULT*/,
  (intptr_t)NULL /*MULTU*/,
  (intptr_t)NULL /*DIV*/,
  (intptr_t)NULL /*DIVU*/,
  (intptr_t)NULL /*DMULT*/,
  (intptr_t)NULL /*DMULTU*/,
  (intptr_t)NULL /*DDIV*/,
  (intptr_t)NULL /*DDIVU*/,
  (intptr_t)invalidate_addr,
  (intptr_t)dyna_linker,
  (intptr_t)dyna_linker_ds,
  (intptr_t)verify_code,
  (intptr_t)cc_interrupt,
  (intptr_t)fp_exception,
  (intptr_t)jump_syscall,
  (intptr_t)jump_eret,
  (intptr_t)do_interrupt,
  (intptr_t)TLBWI_new,
  (intptr_t)TLBWR_new,
  (intptr_t)MFC0_new,
  (intptr_t)MTC0_new,
  (intptr_t)jump_vaddr_x0,
  (intptr_t)jump_vaddr_x1,
  (intptr_t)jump_vaddr_x2,
  (intptr_t)jump_vaddr_x3,
  (intptr_t)jump_vaddr_x4,
  (intptr_t)jump_vaddr_x5,
  (intptr_t)jump_vaddr_x6,
  (intptr_t)jump_vaddr_x7,
  (intptr_t)jump_vaddr_x8,
  (intptr_t)jump_vaddr_x9,
  (intptr_t)jump_vaddr_x10,
  (intptr_t)jump_vaddr_x11,
  (intptr_t)jump_vaddr_x12,
  (intptr_t)jump_vaddr_x13,
  (intptr_t)jump_vaddr_x14,
  (intptr_t)jump_vaddr_x15,
  (intptr_t)jump_vaddr_x16,
  (intptr_t)jump_vaddr_x17,
  (intptr_t)jump_vaddr_x19,
  (intptr_t)jump_vaddr_x21,
  (intptr_t)jump_vaddr_x22,
  (intptr_t)jump_vaddr_x23,
  (intptr_t)jump_vaddr_x24,
  (intptr_t)jump_vaddr_x25,
  (intptr_t)jump_vaddr_x26,
  (intptr_t)jump_vaddr_x27,
  (intptr_t)jump_vaddr_x28,
  (intptr_t)cvt_s_w,
  (intptr_t)cvt_d_w,
  (intptr_t)cvt_s_l,
  (intptr_t)cvt_d_l,
  (intptr_t)cvt_w_s,
  (intptr_t)cvt_w_d,
  (intptr_t)cvt_l_s,
  (intptr_t)cvt_l_d,
  (intptr_t)cvt_d_s,
  (intptr_t)cvt_s_d,
  (intptr_t)round_l_s,
  (intptr_t)round_w_s,
  (intptr_t)trunc_l_s,
  (intptr_t)trunc_w_s,
  (intptr_t)ceil_l_s,
  (intptr_t)ceil_w_s,
  (intptr_t)floor_l_s,
  (intptr_t)floor_w_s,
  (intptr_t)round_l_d,
  (intptr_t)round_w_d,
  (intptr_t)trunc_l_d,
  (intptr_t)trunc_w_d,
  (intptr_t)ceil_l_d,
  (intptr_t)ceil_w_d,
  (intptr_t)floor_l_d,
  (intptr_t)floor_w_d,
  (intptr_t)c_f_s,
  (intptr_t)c_un_s,
  (intptr_t)c_eq_s,
  (intptr_t)c_ueq_s,
  (intptr_t)c_olt_s,
  (intptr_t)c_ult_s,
  (intptr_t)c_ole_s,
  (intptr_t)c_ule_s,
  (intptr_t)c_sf_s,
  (intptr_t)c_ngle_s,
  (intptr_t)c_seq_s,
  (intptr_t)c_ngl_s,
  (intptr_t)c_lt_s,
  (intptr_t)c_nge_s,
  (intptr_t)c_le_s,
  (intptr_t)c_ngt_s,
  (intptr_t)c_f_d,
  (intptr_t)c_un_d,
  (intptr_t)c_eq_d,
  (intptr_t)c_ueq_d,
  (intptr_t)c_olt_d,
  (intptr_t)c_ult_d,
  (intptr_t)c_ole_d,
  (intptr_t)c_ule_d,
  (intptr_t)c_sf_d,
  (intptr_t)c_ngle_d,
  (intptr_t)c_seq_d,
  (intptr_t)c_ngl_d,
  (intptr_t)c_lt_d,
  (intptr_t)c_nge_d,
  (intptr_t)c_le_d,
  (intptr_t)c_ngt_d,
  (intptr_t)add_s,
  (intptr_t)sub_s,
  (intptr_t)mul_s,
  (intptr_t)div_s,
  (intptr_t)sqrt_s,
  (intptr_t)abs_s,
  (intptr_t)mov_s,
  (intptr_t)neg_s,
  (intptr_t)add_d,
  (intptr_t)sub_d,
  (intptr_t)mul_d,
  (intptr_t)div_d,
  (intptr_t)sqrt_d,
  (intptr_t)abs_d,
  (intptr_t)mov_d,
  (intptr_t)neg_d,
  (intptr_t)read_byte_new,
  (intptr_t)read_hword_new,
  (intptr_t)read_word_new,
  (intptr_t)read_dword_new,
  (intptr_t)write_byte_new,
  (intptr_t)write_hword_new,
  (intptr_t)write_word_new,
  (intptr_t)write_dword_new,
  (intptr_t)LWL_new,
  (intptr_t)LWR_new,
  (intptr_t)LDL_new,
  (intptr_t)LDR_new,
  (intptr_t)SWL_new,
  (intptr_t)SWR_new,
  (intptr_t)SDL_new,
  (intptr_t)SDR_new,
  (intptr_t)breakpoint
};

static void cache_flush(char* start, char* end)
{
#ifndef WIN32
    // Don't rely on GCC's __clear_cache implementation, as it caches
    // icache/dcache cache line sizes, that can vary between cores on
    // big.LITTLE architectures.
    uint64_t addr, ctr_el0;
    static size_t icache_line_size = 0xffff, dcache_line_size = 0xffff;
    size_t isize, dsize;

    __asm__ volatile("mrs %0, ctr_el0" : "=r"(ctr_el0));
    isize = 4 << ((ctr_el0 >> 0) & 0xf);
    dsize = 4 << ((ctr_el0 >> 16) & 0xf);

    // use the global minimum cache line size
    icache_line_size = isize = icache_line_size < isize ? icache_line_size : isize;
    dcache_line_size = dsize = dcache_line_size < dsize ? dcache_line_size : dsize;

    addr = (uint64_t)start & ~(uint64_t)(dsize - 1);
    for (; addr < (uint64_t)end; addr += dsize)
        // use "civac" instead of "cvau", as this is the suggested workaround for
        // Cortex-A53 errata 819472, 826319, 827319 and 824069.
            __asm__ volatile("dc civac, %0" : : "r"(addr) : "memory");
    __asm__ volatile("dsb ish" : : : "memory");

    addr = (uint64_t)start & ~(uint64_t)(isize - 1);
    for (; addr < (uint64_t)end; addr += isize)
            __asm__ volatile("ic ivau, %0" : : "r"(addr) : "memory");

    __asm__ volatile("dsb ish" : : : "memory");
    __asm__ volatile("isb" : : : "memory");
#endif
}

/* Linker */
static void set_jump_target(intptr_t addr,uintptr_t target)
{
  u_int *ptr=(u_int *)addr;
  intptr_t offset=target-(intptr_t)addr;

  if((*ptr&0xFC000000)==0x14000000) {
    assert(offset>=-134217728LL&&offset<134217728LL);
    *ptr=(*ptr&0xFC000000)|((offset>>2)&0x3ffffff);
  }
  else if((*ptr&0xff000000)==0x54000000) {
    //Conditional branch are limited to +/- 1MB
    //block max size is 256k so branching beyond the +/- 1MB limit
    //should only happen when jumping to an already compiled block (see add_link)
    //a workaround would be to do a trampoline jump via a stub at the end of the block
    assert(offset>=-1048576LL&&offset<1048576LL);
    *ptr=(*ptr&0xFF00000F)|(((offset>>2)&0x7ffff)<<5);
  }
  else if((*ptr&0x9f000000)==0x10000000) { //adr
    //generated by do_miniht_insert
    assert(offset>=-1048576LL&&offset<1048576LL);
    *ptr=(*ptr&0x9F00001F)|(offset&0x3)<<29|((offset>>2)&0x7ffff)<<5;
  }
  else
    assert(0); /*Should not happen*/
}

/* Literal pool */
static void add_literal(uintptr_t addr,uintptr_t val)
{
  literals[literalcount][0]=addr;
  literals[literalcount][1]=val;
  literalcount++;
}

static void *add_pointer(void *src, void* addr)
{
  int *ptr=(int*)src;
  assert((*ptr&0xFC000000)==0x14000000); //b
  int offset=((signed int)(*ptr<<6)>>6)<<2;
  int *ptr2=(int*)((intptr_t)ptr+offset);
  assert((ptr2[0]&0xFFE00000)==0x52A00000); //movz
  assert((ptr2[1]&0xFFE00000)==0x72800000); //movk
  assert((ptr2[2]&0x9f000000)==0x10000000); //adr
  set_jump_target((intptr_t)src,(intptr_t)addr);
  intptr_t ptr_rx=((intptr_t)ptr-(intptr_t)base_addr)+(intptr_t)base_addr_rx;
  cache_flush((void*)ptr_rx, (void*)(ptr_rx+4));
  return ptr2;
}

static void *kill_pointer(void *stub)
{
  int *ptr=(int *)((intptr_t)stub+8);
  assert((*ptr&0x9f000000)==0x10000000); //adr
  int offset=(((signed int)(*ptr<<8)>>13)<<2)|((*ptr>>29)&0x3);
  int *i_ptr=(int*)((intptr_t)ptr+offset);
  assert((*i_ptr&0xfc000000)==0x14000000); //b
  set_jump_target((intptr_t)i_ptr,(intptr_t)stub);
  return i_ptr;
}

static intptr_t get_pointer(void *stub)
{
  int *ptr=(int *)((intptr_t)stub+8);
  assert((*ptr&0x9f000000)==0x10000000); //adr
  int offset=(((signed int)(*ptr<<8)>>13)<<2)|((*ptr>>29)&0x3);
  int *i_ptr=(int*)((intptr_t)ptr+offset);
  assert((*i_ptr&0xfc000000)==0x14000000); //b
  return (intptr_t)i_ptr+(((signed int)(*i_ptr<<6)>>6)<<2);
}

/* Register allocation */

// Note: registers are allocated clean (unmodified state)
// if you intend to modify the register, you must call dirty_reg().
static void alloc_reg(struct regstat *cur,int i,signed char tr)
{
  int r,hr;
  int preferred_reg = (tr&7);
  if(tr==CCREG) preferred_reg=HOST_CCREG;
  if(tr==PTEMP||tr==FTEMP) preferred_reg=12;

  // Don't allocate unused registers
  if((cur->u>>tr)&1) return;

  // see if it's already allocated
  for(hr=0;hr<HOST_REGS;hr++)
  {
    if(cur->regmap[hr]==tr) return;
  }

  // Keep the same mapping if the register was already allocated in a loop
  preferred_reg = loop_reg(i,tr,preferred_reg);

  // Try to allocate the preferred register
  if(cur->regmap[preferred_reg]==-1) {
    cur->regmap[preferred_reg]=tr;
    cur->dirty&=~(1<<preferred_reg);
    cur->isconst&=~(1<<preferred_reg);
    return;
  }
  r=cur->regmap[preferred_reg];
  if(r<64&&((cur->u>>r)&1)) {
    cur->regmap[preferred_reg]=tr;
    cur->dirty&=~(1<<preferred_reg);
    cur->isconst&=~(1<<preferred_reg);
    return;
  }
  if(r>=64&&((cur->uu>>(r&63))&1)) {
    cur->regmap[preferred_reg]=tr;
    cur->dirty&=~(1<<preferred_reg);
    cur->isconst&=~(1<<preferred_reg);
    return;
  }

  // Clear any unneeded registers
  // We try to keep the mapping consistent, if possible, because it
  // makes branches easier (especially loops).  So we try to allocate
  // first (see above) before removing old mappings.  If this is not
  // possible then go ahead and clear out the registers that are no
  // longer needed.
  for(hr=0;hr<HOST_REGS;hr++)
  {
    r=cur->regmap[hr];
    if(r>=0) {
      if(r<64) {
        if((cur->u>>r)&1) {cur->regmap[hr]=-1;break;}
      }
      else
      {
        if((cur->uu>>(r&63))&1) {cur->regmap[hr]=-1;break;}
      }
    }
  }
  // Try to allocate any available register, but prefer
  // registers that have not been used recently.
  if(i>0) {
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
        if(regs[i-1].regmap[hr]!=rs1[i-1]&&regs[i-1].regmap[hr]!=rs2[i-1]&&regs[i-1].regmap[hr]!=rt1[i-1]&&regs[i-1].regmap[hr]!=rt2[i-1]) {
          cur->regmap[hr]=tr;
          cur->dirty&=~(1<<hr);
          cur->isconst&=~(1<<hr);
          return;
        }
      }
    }
  }
  // Try to allocate any available register
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
      cur->regmap[hr]=tr;
      cur->dirty&=~(1<<hr);
      cur->isconst&=~(1<<hr);
      return;
    }
  }

  // Ok, now we have to evict someone
  // Pick a register we hopefully won't need soon
  u_char hsn[MAXREG+1];
  memset(hsn,10,sizeof(hsn));
  int j;
  lsn(hsn,i,&preferred_reg);
  if(i>0) {
    // Don't evict the cycle count at entry points, otherwise the entry
    // stub will have to write it.
    if(bt[i]&&hsn[CCREG]>2) hsn[CCREG]=2;
    if(i>1&&hsn[CCREG]>2&&(itype[i-2]==RJUMP||itype[i-2]==UJUMP||itype[i-2]==CJUMP||itype[i-2]==SJUMP||itype[i-2]==FJUMP)) hsn[CCREG]=2;
    for(j=10;j>=3;j--)
    {
      // Alloc preferred register if available
      if(hsn[r=cur->regmap[preferred_reg]&63]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          // Evict both parts of a 64-bit register
          if((cur->regmap[hr]&63)==r) {
            cur->regmap[hr]=-1;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
          }
        }
        cur->regmap[preferred_reg]=tr;
        return;
      }
      for(r=1;r<=MAXREG;r++)
      {
        if(hsn[r]==j&&r!=rs1[i-1]&&r!=rs2[i-1]&&r!=rt1[i-1]&&r!=rt2[i-1]) {
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r+64) {
                cur->regmap[hr]=tr;
                cur->dirty&=~(1<<hr);
                cur->isconst&=~(1<<hr);
                return;
              }
            }
          }
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r) {
                cur->regmap[hr]=tr;
                cur->dirty&=~(1<<hr);
                cur->isconst&=~(1<<hr);
                return;
              }
            }
          }
        }
      }
    }
  }
  for(j=10;j>=0;j--)
  {
    for(r=1;r<=MAXREG;r++)
    {
      if(hsn[r]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r+64) {
            cur->regmap[hr]=tr;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r) {
            cur->regmap[hr]=tr;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
      }
    }
  }
  DebugMessage(M64MSG_ERROR, "This shouldn't happen (alloc_reg)");exit(1);
}

static void alloc_reg64(struct regstat *cur,int i,signed char tr)
{
  int preferred_reg = 8+(tr&1);
  int r,hr;

  // allocate the lower 32 bits
  alloc_reg(cur,i,tr);

  // Don't allocate unused registers
  if((cur->uu>>tr)&1) return;

  // see if the upper half is already allocated
  for(hr=0;hr<HOST_REGS;hr++)
  {
    if(cur->regmap[hr]==tr+64) return;
  }

  // Keep the same mapping if the register was already allocated in a loop
  preferred_reg = loop_reg(i,tr,preferred_reg);

  // Try to allocate the preferred register
  if(cur->regmap[preferred_reg]==-1) {
    cur->regmap[preferred_reg]=tr|64;
    cur->dirty&=~(1<<preferred_reg);
    cur->isconst&=~(1<<preferred_reg);
    return;
  }
  r=cur->regmap[preferred_reg];
  if(r<64&&((cur->u>>r)&1)) {
    cur->regmap[preferred_reg]=tr|64;
    cur->dirty&=~(1<<preferred_reg);
    cur->isconst&=~(1<<preferred_reg);
    return;
  }
  if(r>=64&&((cur->uu>>(r&63))&1)) {
    cur->regmap[preferred_reg]=tr|64;
    cur->dirty&=~(1<<preferred_reg);
    cur->isconst&=~(1<<preferred_reg);
    return;
  }

  // Clear any unneeded registers
  // We try to keep the mapping consistent, if possible, because it
  // makes branches easier (especially loops).  So we try to allocate
  // first (see above) before removing old mappings.  If this is not
  // possible then go ahead and clear out the registers that are no
  // longer needed.
  for(hr=HOST_REGS-1;hr>=0;hr--)
  {
    r=cur->regmap[hr];
    if(r>=0) {
      if(r<64) {
        if((cur->u>>r)&1) {cur->regmap[hr]=-1;break;}
      }
      else
      {
        if((cur->uu>>(r&63))&1) {cur->regmap[hr]=-1;break;}
      }
    }
  }
  // Try to allocate any available register, but prefer
  // registers that have not been used recently.
  if(i>0) {
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
        if(regs[i-1].regmap[hr]!=rs1[i-1]&&regs[i-1].regmap[hr]!=rs2[i-1]&&regs[i-1].regmap[hr]!=rt1[i-1]&&regs[i-1].regmap[hr]!=rt2[i-1]) {
          cur->regmap[hr]=tr|64;
          cur->dirty&=~(1<<hr);
          cur->isconst&=~(1<<hr);
          return;
        }
      }
    }
  }
  // Try to allocate any available register
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
      cur->regmap[hr]=tr|64;
      cur->dirty&=~(1<<hr);
      cur->isconst&=~(1<<hr);
      return;
    }
  }

  // Ok, now we have to evict someone
  // Pick a register we hopefully won't need soon
  u_char hsn[MAXREG+1];
  memset(hsn,10,sizeof(hsn));
  int j;
  lsn(hsn,i,&preferred_reg);
  if(i>0) {
    // Don't evict the cycle count at entry points, otherwise the entry
    // stub will have to write it.
    if(bt[i]&&hsn[CCREG]>2) hsn[CCREG]=2;
    if(i>1&&hsn[CCREG]>2&&(itype[i-2]==RJUMP||itype[i-2]==UJUMP||itype[i-2]==CJUMP||itype[i-2]==SJUMP||itype[i-2]==FJUMP)) hsn[CCREG]=2;
    for(j=10;j>=3;j--)
    {
      // Alloc preferred register if available
      if(hsn[r=cur->regmap[preferred_reg]&63]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          // Evict both parts of a 64-bit register
          if((cur->regmap[hr]&63)==r) {
            cur->regmap[hr]=-1;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
          }
        }
        cur->regmap[preferred_reg]=tr|64;
        return;
      }
      for(r=1;r<=MAXREG;r++)
      {
        if(hsn[r]==j&&r!=rs1[i-1]&&r!=rs2[i-1]&&r!=rt1[i-1]&&r!=rt2[i-1]) {
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r+64) {
                cur->regmap[hr]=tr|64;
                cur->dirty&=~(1<<hr);
                cur->isconst&=~(1<<hr);
                return;
              }
            }
          }
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r) {
                cur->regmap[hr]=tr|64;
                cur->dirty&=~(1<<hr);
                cur->isconst&=~(1<<hr);
                return;
              }
            }
          }
        }
      }
    }
  }
  for(j=10;j>=0;j--)
  {
    for(r=1;r<=MAXREG;r++)
    {
      if(hsn[r]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r+64) {
            cur->regmap[hr]=tr|64;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r) {
            cur->regmap[hr]=tr|64;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
      }
    }
  }
  DebugMessage(M64MSG_ERROR, "This shouldn't happen");exit(1);
}

// Allocate a temporary register.  This is done without regard to
// dirty status or whether the register we request is on the unneeded list
// Note: This will only allocate one register, even if called multiple times
static void alloc_reg_temp(struct regstat *cur,int i,signed char tr)
{
  int r,hr;
  int preferred_reg = -1;

  // see if it's already allocated
  for(hr=0;hr<HOST_REGS;hr++)
  {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==tr) return;
  }

  // Try to allocate any available register
  for(hr=HOST_REGS-1;hr>=0;hr--) {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
      cur->regmap[hr]=tr;
      cur->dirty&=~(1<<hr);
      cur->isconst&=~(1<<hr);
      return;
    }
  }

  // Find an unneeded register
  for(hr=HOST_REGS-1;hr>=0;hr--)
  {
    r=cur->regmap[hr];
    if(r>=0) {
      if(r<64) {
        if((cur->u>>r)&1) {
          if(i==0||((unneeded_reg[i-1]>>r)&1)) {
            cur->regmap[hr]=tr;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
      }
      else
      {
        if((cur->uu>>(r&63))&1) {
          if(i==0||((unneeded_reg_upper[i-1]>>(r&63))&1)) {
            cur->regmap[hr]=tr;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
      }
    }
  }

  // Ok, now we have to evict someone
  // Pick a register we hopefully won't need soon
  // TODO: we might want to follow unconditional jumps here
  // TODO: get rid of dupe code and make this into a function
  u_char hsn[MAXREG+1];
  memset(hsn,10,sizeof(hsn));
  int j;
  lsn(hsn,i,&preferred_reg);
  if(i>0) {
    // Don't evict the cycle count at entry points, otherwise the entry
    // stub will have to write it.
    if(bt[i]&&hsn[CCREG]>2) hsn[CCREG]=2;
    if(i>1&&hsn[CCREG]>2&&(itype[i-2]==RJUMP||itype[i-2]==UJUMP||itype[i-2]==CJUMP||itype[i-2]==SJUMP||itype[i-2]==FJUMP)) hsn[CCREG]=2;
    for(j=10;j>=3;j--)
    {
      for(r=1;r<=MAXREG;r++)
      {
        if(hsn[r]==j&&r!=rs1[i-1]&&r!=rs2[i-1]&&r!=rt1[i-1]&&r!=rt2[i-1]) {
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||hsn[CCREG]>2) {
              if(cur->regmap[hr]==r+64) {
                cur->regmap[hr]=tr;
                cur->dirty&=~(1<<hr);
                cur->isconst&=~(1<<hr);
                return;
              }
            }
          }
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||hsn[CCREG]>2) {
              if(cur->regmap[hr]==r) {
                cur->regmap[hr]=tr;
                cur->dirty&=~(1<<hr);
                cur->isconst&=~(1<<hr);
                return;
              }
            }
          }
        }
      }
    }
  }
  for(j=10;j>=0;j--)
  {
    for(r=1;r<=MAXREG;r++)
    {
      if(hsn[r]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r+64) {
            cur->regmap[hr]=tr;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r) {
            cur->regmap[hr]=tr;
            cur->dirty&=~(1<<hr);
            cur->isconst&=~(1<<hr);
            return;
          }
        }
      }
    }
  }
  DebugMessage(M64MSG_ERROR, "This shouldn't happen");exit(1);
}
// Allocate a specific ARM64 register.
static void alloc_arm64_reg(struct regstat *cur,int i,signed char tr,int hr)
{
  int n;
  int dirty=0;

  // see if it's already allocated (and dealloc it)
  for(n=0;n<HOST_REGS;n++)
  {
    if(n!=EXCLUDE_REG&&cur->regmap[n]==tr) {
      dirty=(cur->dirty>>n)&1;
      cur->regmap[n]=-1;
    }
  }

  cur->regmap[hr]=tr;
  cur->dirty&=~(1<<hr);
  cur->dirty|=dirty<<hr;
  cur->isconst&=~(1<<hr);
}

// Alloc cycle count into dedicated register
static void alloc_cc(struct regstat *cur,int i)
{
  alloc_arm64_reg(cur,i,CCREG,HOST_CCREG);
}

/* Assembler */

static char regname[32][4] = {
 "w0",
 "w1",
 "w2",
 "w3",
 "w4",
 "w5",
 "w6",
 "w7",
 "w8",
 "w9",
 "w10",
 "w11",
 "w12",
 "w13",
 "w14",
 "w15",
 "w16",
 "w17",
 "w18",
 "w19",
 "w20",
 "w21",
 "w22",
 "w23",
 "w24",
 "w25",
 "w26",
 "w27",
 "w28",
 "w29",
 "w30",
 "wzr"};

static char regname64[32][4] = {
 "x0",
 "x1",
 "x2",
 "x3",
 "x4",
 "x5",
 "x6",
 "x7",
 "x8",
 "x9",
 "x10",
 "x11",
 "x12",
 "x13",
 "x14",
 "x15",
 "x16",
 "x17",
 "x18",
 "x19",
 "x20",
 "x21",
 "x22",
 "x23",
 "x24",
 "x25",
 "x26",
 "x27",
 "x28",
 "fp",
 "lr",
 "sp"};

static void output_byte(u_char byte)
{
  *(out++)=byte;
}

static void output_w32(u_int word)
{
  *((u_int *)out)=word;
  out+=4;
}

static void output_w64(uint64_t dword)
{
  *((uint64_t *)out)=dword;
  out+=8;
}

static u_int genjmp(intptr_t addr)
{
  if(addr<4) return 0;
  intptr_t out_rx=(intptr_t)out;

  if(addr<(intptr_t)base_addr||addr>=(intptr_t)base_addr+(1<<TARGET_SIZE_2))
    out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;

  intptr_t offset=addr-out_rx;
  if(offset<-134217728LL||offset>=134217728LL)
  {
    int n;
    for(n=0;n<sizeof(jump_table_symbols)/4;n++)
    {
      if(addr==jump_table_symbols[n])
      {
        offset=(intptr_t)base_addr_rx+(1<<TARGET_SIZE_2)-JUMP_TABLE_SIZE+n*16-out_rx;
        break;
      }
    }
  }
  assert(offset>=-134217728LL&&offset<134217728LL);
  return (offset>>2)&0x3ffffff;
}

static u_int gencondjmp(intptr_t addr)
{
  if(addr<4) return 0;
  intptr_t out_rx=(intptr_t)out;

  if(addr<(intptr_t)base_addr||addr>=(intptr_t)base_addr+(1<<TARGET_SIZE_2))
    out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;

  intptr_t offset=addr-out_rx;
  assert(offset>=-1048576LL&&offset<1048576LL);
  return (offset>>2)&0x7ffff;
}

uint32_t count_trailing_zeros(uint64_t value)
{
#ifdef _MSC_VER
  uint32_t trailing_zero_low = 0;
  uint32_t trailing_zero_high = 0;
  if(!_BitScanForward(&trailing_zero_low, (uint32_t)value))
    trailing_zero_low = 32;

  if(!_BitScanForward(&trailing_zero_high, (uint32_t)(value>>32)))
    trailing_zero_high = 32;

  if(trailing_zero_low == 32)
    return trailing_zero_low + trailing_zero_high;
  else
    return trailing_zero_low;
#else /* ARM64 */
  return __builtin_ctzll(value);
#endif
}

uint32_t count_leading_zeros(uint64_t value)
{
#ifdef _MSC_VER
  uint32_t leading_zero_low = 0;
  uint32_t leading_zero_high = 0;
  if(!_BitScanReverse(&leading_zero_low, (uint32_t)value))
    leading_zero_low = 32;
  else
    leading_zero_low = 31 - leading_zero_low;

  if(!_BitScanReverse(&leading_zero_high, (uint32_t)(value>>32)))
    leading_zero_high = 32;
  else
    leading_zero_high = 31 - leading_zero_high;

  if(leading_zero_high == 32)
    return leading_zero_low + leading_zero_high;
  else
    return leading_zero_high;
#else /* ARM64 */
  return __builtin_clzll(value);
#endif
}

// This function returns true if the argument is a non-empty
// sequence of ones starting at the least significant bit with the remainder
// zero.
static uint32_t is_mask(uint64_t value) {
  return value && ((value + 1) & value) == 0;
}

// This function returns true if the argument contains a
// non-empty sequence of ones with the remainder zero.
static uint32_t is_shifted_mask(uint64_t Value) {
  return Value && is_mask((Value - 1) | Value);
}

// Determine if an immediate value can be encoded
// as the immediate operand of a logical instruction for the given register
// size. If so, return 1 with "encoding" set to the encoded value in
// the form N:immr:imms.
static uint32_t genimm(uint64_t imm, uint32_t regsize, uint32_t * encoded) {
  // First, determine the element size.
  uint32_t size = regsize;
  do {
    size /= 2;
    uint64_t mask = (1ULL << size) - 1;

    if ((imm & mask) != ((imm >> size) & mask)) {
      size *= 2;
      break;
    }
  } while (size > 2);

  // Second, determine the rotation to make the element be: 0^m 1^n.
  uint32_t trailing_one, trailing_zero;
  uint64_t mask = ((uint64_t)-1LL) >> (64 - size);
  imm &= mask;

  if (is_shifted_mask(imm)) {
    trailing_zero = count_trailing_zeros(imm);
    assert(trailing_zero < 64);
    trailing_one = count_trailing_zeros(~(imm >> trailing_zero));
  } else {
    imm |= ~mask;
    if (!is_shifted_mask(~imm))
      return 0;

    uint32_t leading_one = count_leading_zeros(~imm);
    trailing_zero = 64 - leading_one;
    trailing_one = leading_one + count_trailing_zeros(~imm) - (64 - size);
  }

  // Encode in immr the number of RORs it would take to get *from* 0^m 1^n
  // to our target value, where trailing_zero is the number of RORs to go the opposite
  // direction.
  assert(size > trailing_zero);
  uint32_t immr = (size - trailing_zero) & (size - 1);

  // If size has a 1 in the n'th bit, create a value that has zeroes in
  // bits [0, n] and ones above that.
  uint64_t Nimms = ~(size-1) << 1;

  // Or the trailing_one value into the low bits, which must be below the Nth bit
  // bit mentioned above.
  Nimms |= (trailing_one-1);

  // Extract the seventh bit and toggle it to create the N field.
  uint32_t N = ((Nimms >> 6) & 1) ^ 1;

  *encoded = (N << 12) | (immr << 6) | (Nimms & 0x3f);
  return 1;
}

static void emit_loadlp(uintptr_t addr,u_int rt)
{
  add_literal((uintptr_t)out,addr);
  output_w32(0x58000000|rt);
}

static void emit_mov(int rs,int rt)
{
  assem_debug("mov %s,%s",regname[rt],regname[rs]);
  output_w32(0x2a000000|rs<<16|WZR<<5|rt);
}

static void emit_mov64(int rs,int rt)
{
  assem_debug("mov %s,%s",regname64[rt],regname64[rs]);
  output_w32(0xaa000000|rs<<16|WZR<<5|rt);
}

static void emit_add(int rs1,int rs2,int rt)
{
  assem_debug("add %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x0b000000|rs2<<16|rs1<<5|rt);
}

static void emit_adds(int rs1,int rs2,int rt)
{
  assem_debug("adds %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x2b000000|rs2<<16|rs1<<5|rt);
}

static void emit_adc(int rs1,int rs2,int rt)
{
  assem_debug("adc %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1a000000|rs2<<16|rs1<<5|rt);
}

static void emit_sub(int rs1,int rs2,int rt)
{
  assem_debug("sub %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x4b000000|rs2<<16|rs1<<5|rt);
}

static void emit_subs(int rs1,int rs2,int rt)
{
  assem_debug("subs %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x6b000000|rs2<<16|rs1<<5|rt);
}

static void emit_sbc(int rs1,int rs2,int rt)
{
  assem_debug("sbc %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x5a000000|rs2<<16|rs1<<5|rt);
}

static void emit_sbcs(int rs1,int rs2,int rt)
{
  assem_debug("sbcs %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x7a000000|rs2<<16|rs1<<5|rt);
}

static void emit_neg(int rs, int rt)
{
  assem_debug("neg %s,%s",regname[rt],regname[rs]);
  output_w32(0x4b000000|rs<<16|WZR<<5|rt);
}

static void emit_negs(int rs, int rt)
{
  assem_debug("negs %s,%s",regname[rt],regname[rs]);
  output_w32(0x6b000000|rs<<16|WZR<<5|rt);
}

static void emit_rscimm(int rs,int imm,u_int rt)
{
  assert(imm==0);
  assem_debug("ngc %s,%s",regname[rt],regname[rs]);
  output_w32(0x5a000000|rs<<16|WZR<<5|rt);
}

static void emit_zeroreg(int rt)
{
  assem_debug("movz %s,#0",regname[rt]);
  output_w32(0x52800000|rt);
}

static void emit_zeroreg64(int rt)
{
  assem_debug("movz %s,#0",regname64[rt]);
  output_w32(0xd2800000|rt);
}

static void emit_movz(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movz %s,#%d",regname[rt],imm);
  output_w32(0x52800000|imm<<5|rt);
}

static void emit_movz_lsl16(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movz %s, #%d, lsl #%d",regname[rt],imm,16);
  output_w32(0x52a00000|imm<<5|rt);
}

static void emit_movn(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movn %s,#%d",regname[rt],imm);
  output_w32(0x12800000|imm<<5|rt);
}

static void emit_movn_lsl16(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movn %s, #%d, lsl #%d",regname[rt],imm,16);
  output_w32(0x12a00000|imm<<5|rt);
}

static void emit_movk(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movk %s,#%d",regname[rt],imm);
  output_w32(0x72800000|imm<<5|rt);
}

static void emit_movk_lsl16(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movk %s, #%d, lsl #%d",regname[rt],imm,16);
  output_w32(0x72a00000|imm<<5|rt);
}

static void emit_movz64(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movz %s,#%d",regname64[rt],imm);
  output_w32(0xd2800000|imm<<5|rt);
}

static void emit_movz64_lsl16(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movz %s, #%d, lsl #%d",regname64[rt],imm,16);
  output_w32(0xd2a00000|imm<<5|rt);
}

static void emit_movz64_lsl32(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movz %s, #%d, lsl #%d",regname64[rt],imm,32);
  output_w32(0xd2c00000|imm<<5|rt);
}

static void emit_movz64_lsl48(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movz %s, #%d, lsl #%d",regname64[rt],imm,48);
  output_w32(0xd2e00000|imm<<5|rt);
}

static void emit_movn64(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movn %s,#%d",regname64[rt],imm);
  output_w32(0x92800000|imm<<5|rt);
}

static void emit_movn64_lsl16(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movn %s, #%d, lsl #%d",regname64[rt],imm,16);
  output_w32(0x92a00000|imm<<5|rt);
}

static void emit_movn64_lsl32(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movn %s, #%d, lsl #%d",regname64[rt],imm,32);
  output_w32(0x92c00000|imm<<5|rt);
}

static void emit_movn64_lsl48(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movn %s, #%d, lsl #%d",regname64[rt],imm,48);
  output_w32(0x92e00000|imm<<5|rt);
}

static void emit_movk64(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movk %s,#%d",regname64[rt],imm);
  output_w32(0xf2800000|imm<<5|rt);
}

static void emit_movk64_lsl16(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movk %s, #%d, lsl #%d",regname64[rt],imm,16);
  output_w32(0xf2a00000|imm<<5|rt);
}

static void emit_movk64_lsl32(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movk %s, #%d, lsl #%d",regname64[rt],imm,32);
  output_w32(0xf2c00000|imm<<5|rt);
}

static void emit_movk64_lsl48(u_int imm,u_int rt)
{
  assert(imm<65536);
  assem_debug("movk %s, #%d, lsl #%d",regname64[rt],imm,48);
  output_w32(0xf2e00000|imm<<5|rt);
}

static void emit_movimm(u_int imm,u_int rt)
{
  uint32_t armval=0;
  if(imm<65536) {
    emit_movz(imm,rt);
  }else if((~imm)<65536) {
    emit_movn(~imm,rt);
  }else if((imm&0xffff)==0) {
    emit_movz_lsl16((imm>>16)&0xffff,rt);
  }else if(((~imm)&0xffff)==0) {
    emit_movn_lsl16((~imm>>16)&0xffff,rt);
  }else if(genimm((uint64_t)imm,32,&armval)) {
    assem_debug("orr %s, wzr, #%d (0x%x)",regname[rt],imm,imm);
    output_w32(0x32000000|armval<<10|WZR<<5|rt);
  }else{
    emit_movz_lsl16((imm>>16)&0xffff,rt);
    emit_movk(imm&0xffff,rt);
  }
}

static void emit_loadreg(int r, int hr)
{
  if((r&63)==0)
    emit_zeroreg(hr);
  else if(r==MMREG)
    emit_movimm(fp_memory_map>>3,hr);
  else if(r==INVCP||r==ROREG){
    u_int offset=0;
    if(r==INVCP) offset=fp_invc_ptr;
    if(r==ROREG) offset=fp_ram_offset;
    assert(offset<4096);
    assert(offset%8 == 0); /* 8 bytes aligned */
    assem_debug("ldr %s,fp+%d",regname[hr],offset);
    output_w32(0xf9400000|((offset>>3)<<10)|(FP<<5)|hr);
  }
  else {
    u_int offset = fp_regs+((r&63)<<3)+((r&64)>>4);
    if((r&63)==HIREG) offset=fp_hi+((r&64)>>4);
    if((r&63)==LOREG) offset=fp_lo+((r&64)>>4);
    if(r==CCREG) offset=fp_cycle_count;
    if(r==CSREG) offset=fp_cp0_regs(CP0_STATUS_REG);
    if(r==FSREG) offset=fp_fcr31;
    assert(offset<4096);
    assert(offset%4 == 0); /* 4 bytes aligned */
    assem_debug("ldr %s,fp+%d",regname[hr],offset);
    output_w32(0xb9400000|((offset>>2)<<10)|(FP<<5)|hr);
  }
}

static void emit_storereg(int r, int hr)
{
  u_int offset = fp_regs+((r&63)<<3)+((r&64)>>4);
  if((r&63)==HIREG) offset=fp_hi+((r&64)>>4);
  if((r&63)==LOREG) offset=fp_lo+((r&64)>>4);
  if(r==CCREG) offset=fp_cycle_count;
  if(r==FSREG) offset=fp_fcr31;
  assert((r&63)!=CSREG);
  assert((r&63)!=0);
  assert((r&63)<=CCREG);
  assert(offset<4096);
  assert(offset%4 == 0); /* 4 bytes aligned */
  assem_debug("str %s,fp+%d",regname[hr],offset);
  output_w32(0xb9000000|((offset>>2)<<10)|(FP<<5)|hr);
}

static void emit_test(int rs, int rt)
{
  assem_debug("tst %s,%s",regname[rs],regname[rt]);
  output_w32(0x6a000000|rt<<16|rs<<5|WZR);
}

static void emit_test64(int rs, int rt)
{
  assem_debug("tst %s,%s",regname64[rs],regname64[rt]);
  output_w32(0xea000000|rt<<16|rs<<5|WZR);
}

static void emit_testimm(int rs,int imm)
{
  u_int armval, ret;
  assem_debug("tst %s,#%d",regname[rs],imm);
  ret=genimm(imm,32,&armval);
  assert(ret);
  output_w32(0x72000000|armval<<10|rs<<5|WZR);
}

static void emit_testimm64(int rs,int64_t imm)
{
  u_int armval, ret;
  assem_debug("tst %s,#%d",regname64[rs],imm);
  ret=genimm(imm,64,&armval);
  assert(ret);
  output_w32(0xf2000000|armval<<10|rs<<5|WZR);
}

static void emit_not(int rs,int rt)
{
  assem_debug("mvn %s,%s",regname[rt],regname[rs]);
  output_w32(0x2a200000|rs<<16|WZR<<5|rt);
}

static void emit_and(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("and %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x0a000000|rs2<<16|rs1<<5|rt);
}

static void emit_or(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("orr %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x2a000000|rs2<<16|rs1<<5|rt);
}

static void emit_orr64(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("orr %s,%s,%s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0xaa000000|rs2<<16|rs1<<5|rt);
}

static void emit_xor(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("eor %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x4a000000|rs2<<16|rs1<<5|rt);
}

static void emit_addimm64(u_int rs,int imm,u_int rt)
{
  assert(imm>=0&&imm<4096);
  assem_debug("add %s, %s, #%d",regname64[rt],regname64[rs],imm);
  output_w32(0x91000000|imm<<10|rs<<5|rt);
}

static void emit_addimm(u_int rs,int imm,u_int rt)
{
  if(imm!=0) {
    assert(imm>-65536&&imm<65536);
    //assert(imm>-16777216&&imm<16777216);
    if(imm<0&&imm>-4096) {
      assem_debug("sub %s, %s, #%d",regname[rt],regname[rs],-imm&0xfff);
      output_w32(0x51000000|((-imm)&0xfff)<<10|rs<<5|rt);
    }else if(imm>0&&imm<4096) {
      assem_debug("add %s, %s, #%d",regname[rt],regname[rs],imm&0xfff);
      output_w32(0x11000000|(imm&0xfff)<<10|rs<<5|rt);
    }else if(imm<0) {
      assem_debug("sub %s, %s, #%d lsl #%d",regname[rt],regname[rt],((-imm)>>12)&0xfff,12);
      output_w32(0x51400000|(((-imm)>>12)&0xfff)<<10|rs<<5|rt);
      if((-imm&0xfff)!=0) {
        assem_debug("sub %s, %s, #%d",regname[rt],regname[rs],(-imm&0xfff));
        output_w32(0x51000000|((-imm)&0xfff)<<10|rt<<5|rt);
      }
    }else {
      assem_debug("add %s, %s, #%d lsl #%d",regname[rt],regname[rt],(imm>>12)&0xfff,12);
      output_w32(0x11400000|((imm>>12)&0xfff)<<10|rs<<5|rt);
      if((imm&0xfff)!=0) {
        assem_debug("add %s, %s, #%d",regname[rt],regname[rs],imm&0xfff);
        output_w32(0x11000000|(imm&0xfff)<<10|rt<<5|rt);
      }
    }
  }
  else if(rs!=rt) emit_mov(rs,rt);
}

static void emit_addimm_and_set_flags(int imm,int rt)
{
  assert(imm>-65536&&imm<65536);
  //assert(imm>-16777216&&imm<16777216);
  if(imm<0&&imm>-4096) {
    assem_debug("subs %s, %s, #%d",regname[rt],regname[rt],-imm&0xfff);
    output_w32(0x71000000|((-imm)&0xfff)<<10|rt<<5|rt);
  }else if(imm>0&&imm<4096) {
    assem_debug("adds %s, %s, #%d",regname[rt],regname[rt],imm&0xfff);
    output_w32(0x31000000|(imm&0xfff)<<10|rt<<5|rt);
  }else if(imm<0) {
    if((-imm&0xfff)!=0) {
      assem_debug("sub %s, %s, #%d lsl #%d",regname[rt],regname[rt],((-imm)>>12)&0xfff,12);
      output_w32(0x51400000|(((-imm)>>12)&0xfff)<<10|rt<<5|rt);
      assem_debug("subs %s, %s, #%d",regname[rt],regname[rt],(-imm&0xfff));
      output_w32(0x71000000|((-imm)&0xfff)<<10|rt<<5|rt);
    }else{
      assem_debug("subs %s, %s, #%d lsl #%d",regname[rt],regname[rt],((-imm)>>12)&0xfff,12);
      output_w32(0x71400000|(((-imm)>>12)&0xfff)<<10|rt<<5|rt);
    }
  }else {
    if((imm&0xfff)!=0) {
      assem_debug("add %s, %s, #%d lsl #%d",regname[rt],regname[rt],(imm>>12)&0xfff,12);
      output_w32(0x11400000|((imm>>12)&0xfff)<<10|rt<<5|rt);
      assem_debug("adds %s, %s, #%d",regname[rt],regname[rt],imm&0xfff);
      output_w32(0x31000000|(imm&0xfff)<<10|rt<<5|rt);
    }else{
      assem_debug("adds %s, %s, #%d lsl #%d",regname[rt],regname[rt],(imm>>12)&0xfff,12);
      output_w32(0x31400000|((imm>>12)&0xfff)<<10|rt<<5|rt);
    }
  }
}

#ifndef RAM_OFFSET
static void emit_addimm_no_flags(u_int imm,u_int rt)
{
  assert(0);
}
#endif

static void emit_addnop(u_int r)
{
  assem_debug("nop");
  output_w32(0xd503201f);
  /*assem_debug("add %s,%s,#0 (nop)",regname[r],regname[r]);
  output_w32(0x11000000|r<<5|r);*/
}

static void emit_addimm64_32(int rsh,int rsl,int imm,int rth,int rtl)
{
  if(imm<0&&imm>-4096) {
    assem_debug("subs %s, %s, #%d",regname[rtl],regname[rsl],-imm&0xfff);
    output_w32(0x71000000|((-imm)&0xfff)<<10|rsl<<5|rtl);
    emit_sbc(rsh,WZR,rth);
  }else if(imm>0&&imm<4096) {
    assem_debug("adds %s, %s, #%d",regname[rtl],regname[rsl],imm&0xfff);
    output_w32(0x31000000|(imm&0xfff)<<10|rsl<<5|rtl);
    emit_adc(rsh,WZR,rth);
  }else if(imm<0) {
    assert(rsl!=HOST_TEMPREG);
    emit_movimm(-imm,HOST_TEMPREG);
    emit_subs(rsl,HOST_TEMPREG,rtl);
    emit_sbc(rsh,WZR,rth);
  }else if(imm>0) {
    assert(rsl!=HOST_TEMPREG);
    emit_movimm(imm,HOST_TEMPREG);
    emit_adds(rsl,HOST_TEMPREG,rtl);
    emit_adc(rsh,WZR,rth);
  }
  else {
    assert(imm==0);
    if(rsl!=rtl) {
      assert(rsh!=rth);
      emit_mov(rsl,rtl);
      emit_mov(rsh,rth);
    }
  }
}

#ifdef INVERTED_CARRY
static void emit_sbb(int rs1,int rs2)
{
  assert(0);
}
static void emit_adcimm(u_int rs,int imm,u_int rt)
{
  assert(0);
}
#endif

static void emit_andimm(int rs,int imm,int rt)
{
  u_int armval;
  if(imm==0) {
    emit_zeroreg(rt);
  }else if(genimm((uint64_t)imm,32,&armval)) {
    assem_debug("and %s,%s,#%d",regname[rt],regname[rs],imm);
    output_w32(0x12000000|armval<<10|rs<<5|rt);
  }else{
    assert(rs!=HOST_TEMPREG);
    assert(imm>0&&imm<65535);
    emit_movz(imm,HOST_TEMPREG);
    assem_debug("and %s,%s,%s",regname[rt],regname[rs],regname[HOST_TEMPREG]);
    output_w32(0x0a000000|HOST_TEMPREG<<16|rs<<5|rt);
  }
}

static void emit_andimm64(int rs,int64_t imm,int rt)
{
  u_int armval;
  uint32_t ret=genimm((uint64_t)imm,64,&armval);
  assert(ret);
  assem_debug("and %s,%s,#%d",regname64[rt],regname64[rs],imm);
  output_w32(0x92000000|armval<<10|rs<<5|rt);
}

static void emit_orimm(int rs,int imm,int rt)
{
  u_int armval;
  if(imm==0) {
    if(rs!=rt) emit_mov(rs,rt);
  }else if(genimm(imm,32,&armval)) {
    assem_debug("orr %s,%s,#%d",regname[rt],regname[rs],imm);
    output_w32(0x32000000|armval<<10|rs<<5|rt);
  }else{
    assert(rs!=HOST_TEMPREG);
    assert(imm>0&&imm<65536);
    emit_movz(imm,HOST_TEMPREG);
    assem_debug("orr %s,%s,%s",regname[rt],regname[rs],regname[HOST_TEMPREG]);
    output_w32(0x2a000000|HOST_TEMPREG<<16|rs<<5|rt);
  }
}

static void emit_xorimm(int rs,int imm,int rt)
{
  u_int armval;
  if(imm==0) {
    if(rs!=rt) emit_mov(rs,rt);
  }else if(genimm((uint64_t)imm,32,&armval)) {
    assem_debug("eor %s,%s,#%d",regname[rt],regname[rs],imm);
    output_w32(0x52000000|armval<<10|rs<<5|rt);
  }else{
    assert(rs!=HOST_TEMPREG);
    assert(imm>0&&imm<65536);
    emit_movz(imm,HOST_TEMPREG);
    assem_debug("eor %s,%s,%s",regname[rt],regname[rs],regname[HOST_TEMPREG]);
    output_w32(0x4a000000|HOST_TEMPREG<<16|rs<<5|rt);
  }
}

static void emit_shlimm(int rs,u_int imm,int rt)
{
  assert(imm>0);
  assert(imm<32);
  //if(imm==1) ...
  assem_debug("lsl %s,%s,#%d",regname[rt],regname[rs],imm);
  output_w32(0x53000000|((31-imm)+1)<<16|(31-imm)<<10|rs<<5|rt);
}

static void emit_shlimm64(int rs,u_int imm,int rt)
{
  assert(imm>0);
  assert(imm<64);
  assem_debug("lsl %s,%s,#%d",regname64[rt],regname64[rs],imm);
  output_w32(0xd3400000|((63-imm)+1)<<16|(63-imm)<<10|rs<<5|rt);
}

static void emit_shrimm(int rs,u_int imm,int rt)
{
  assert(imm>0);
  assert(imm<32);
  assem_debug("lsr %s,%s,#%d",regname[rt],regname[rs],imm);
  output_w32(0x53000000|imm<<16|0x1f<<10|rs<<5|rt);
}

static void emit_shrimm64(int rs,u_int imm,int rt)
{
  assert(imm>0);
  assert(imm<64);
  assem_debug("lsr %s,%s,#%d",regname64[rt],regname64[rs],imm);
  output_w32(0xd3400000|imm<<16|0x3f<<10|rs<<5|rt);
}

static void emit_sarimm(int rs,u_int imm,int rt)
{
  assert(imm>0);
  assert(imm<32);
  assem_debug("asr %s,%s,#%d",regname[rt],regname[rs],imm);
  output_w32(0x13000000|imm<<16|0x1f<<10|rs<<5|rt);
}

static void emit_rorimm(int rs,u_int imm,int rt)
{
  assert(imm>0);
  assert(imm<32);
  assem_debug("ror %s,%s,#%d",regname[rt],regname[rs],imm);
  output_w32(0x13800000|rs<<16|imm<<10|rs<<5|rt);
}

static void emit_shl(u_int rs,u_int shift,u_int rt)
{
  //if(imm==1) ...
  assem_debug("lsl %s,%s,%s",regname[rt],regname[rs],regname[shift]);
  output_w32(0x1ac02000|shift<<16|rs<<5|rt);
}

static void emit_shl64(u_int rs,u_int shift,u_int rt)
{
  //if(imm==1) ...
  assem_debug("lsl %s,%s,%s",regname64[rt],regname64[rs],regname64[shift]);
  output_w32(0x9ac02000|shift<<16|rs<<5|rt);
}

static void emit_shr(u_int rs,u_int shift,u_int rt)
{
  assem_debug("lsr %s,%s,%s",regname[rt],regname[rs],regname[shift]);
  output_w32(0x1ac02400|shift<<16|rs<<5|rt);
}

static void emit_shr64(u_int rs,u_int shift,u_int rt)
{
  assem_debug("lsr %s,%s,%s",regname64[rt],regname64[rs],regname64[shift]);
  output_w32(0x9ac02400|shift<<16|rs<<5|rt);
}

static void emit_sar(u_int rs,u_int shift,u_int rt)
{
  assem_debug("asr %s,%s,%s",regname[rt],regname[rs],regname[shift]);
  output_w32(0x1ac02800|shift<<16|rs<<5|rt);
}

static void emit_sar64(u_int rs,u_int shift,u_int rt)
{
  assem_debug("asr %s,%s,%s",regname64[rt],regname64[rs],regname64[shift]);
  output_w32(0x9ac02800|shift<<16|rs<<5|rt);
}

static void emit_orrshlimm(u_int rs,int imm,u_int rt)
{
  assert(imm<32);
  assem_debug("orr %s,%s,%s,lsl #%d",regname[rt],regname[rt],regname[rs],imm);
  output_w32(0x2a000000|rs<<16|imm<<10|rt<<5|rt);
}

static void emit_orrshlimm64(u_int rs,int imm,u_int rt)
{
  assert(imm<64);
  assem_debug("orr %s,%s,%s,lsl #%d",regname64[rt],regname64[rt],regname64[rs],imm);
  output_w32(0xaa000000|rs<<16|imm<<10|rt<<5|rt);
}

static void emit_orrshrimm(u_int rs,int imm,u_int rt)
{
  assert(imm<32);
  assem_debug("orr %s,%s,%s,lsr #%d",regname[rt],regname[rt],regname[rs],imm);
  output_w32(0x2a400000|rs<<16|imm<<10|rt<<5|rt);
}

static void emit_shldimm(int rs,int rs2,u_int imm,int rt)
{
  assem_debug("shld %%%s,%%%s,%d",regname[rt],regname[rs2],imm);
  assert(imm>0);
  assert(imm<32);
  //if(imm==1) ...
  emit_shlimm(rs,imm,rt);
  emit_orrshrimm(rs2,32-imm,rt);
}

static void emit_shrdimm(int rs,int rs2,u_int imm,int rt)
{
  assem_debug("shrd %%%s,%%%s,%d",regname[rt],regname[rs2],imm);
  assert(imm>0);
  assert(imm<32);
  //if(imm==1) ...
  emit_shrimm(rs,imm,rt);
  emit_orrshlimm(rs2,32-imm,rt);
}

static void emit_cmpimm(int rs,int imm)
{
  if(imm<0&&imm>-4096) {
    assem_debug("cmn %s,#%d",regname[rs],-imm&0xfff);
    output_w32(0x31000000|((-imm)&0xfff)<<10|rs<<5|WZR);
  }else if(imm>0&&imm<4096) {
    assem_debug("cmp %s,#%d",regname[rs],imm&0xfff);
    output_w32(0x71000000|(imm&0xfff)<<10|rs<<5|WZR);
  }else if(imm<0) {
    if((-imm&0xfff)==0) {
      assem_debug("cmn %s,#%d,lsl #12",regname[rs],-imm&0xfff);
      output_w32(0x31400000|((-imm>>12)&0xfff)<<10|rs<<5|WZR);
    }else{
      assert(rs!=HOST_TEMPREG);
      assert(imm>-65536);
      emit_movz(-imm,HOST_TEMPREG);
      assem_debug("cmn %s,%s",regname[rs],regname[HOST_TEMPREG]);
      output_w32(0x2b000000|HOST_TEMPREG<<16|rs<<5|WZR);
    }
  }else {
    if((imm&0xfff)==0) {
      assem_debug("cmp %s,#%d,lsl #12",regname[rs],imm&0xfff);
      output_w32(0x71400000|((imm>>12)&0xfff)<<10|rs<<5|WZR);
    }else{
      assert(rs!=HOST_TEMPREG);
      assert(imm<65536);
      emit_movz(imm,HOST_TEMPREG);
      assem_debug("cmp %s,%s",regname[rs],regname[HOST_TEMPREG]);
      output_w32(0x6b000000|HOST_TEMPREG<<16|rs<<5|WZR);
    }
  }
}

static void emit_cmovne_imm(int imm,int rt)
{
  assert(imm==0||imm==1);
  if(imm){
    assem_debug("csinc %s,%s,%s,eq",regname[rt],regname[rt],regname[WZR]);
    output_w32(0x1a800400|WZR<<16|COND_EQ<<12|rt<<5|rt);
  }else{
    assem_debug("csel %s,%s,%s,ne",regname[rt],regname[WZR],regname[rt]);
    output_w32(0x1a800000|rt<<16|COND_NE<<12|WZR<<5|rt);
  }
}

static void emit_cmovl_imm(int imm,int rt)
{
  assert(imm==0||imm==1);
  if(imm){
    assem_debug("csinc %s,%s,%s,ge",regname[rt],regname[rt],regname[WZR]);
    output_w32(0x1a800400|WZR<<16|COND_GE<<12|rt<<5|rt);
  }else{
    assem_debug("csel %s,%s,%s,lt",regname[rt],regname[WZR],regname[rt]);
    output_w32(0x1a800000|rt<<16|COND_LT<<12|WZR<<5|rt);
  }
}

static void emit_cmovb_imm(int imm,int rt)
{
  assert(imm==0||imm==1);
  if(imm){
    assem_debug("csinc %s,%s,%s,cs",regname[rt],regname[rt],regname[WZR]);
    output_w32(0x1a800400|WZR<<16|COND_CS<<12|rt<<5|rt);
  }else{
    assem_debug("csel %s,%s,%s,cc",regname[rt],regname[WZR],regname[rt]);
    output_w32(0x1a800000|rt<<16|COND_CC<<12|WZR<<5|rt);
  }
}

static void emit_cmovs_imm(int imm,int rt)
{
  assert(imm==0||imm==1);
  if(imm){
    assem_debug("csinc %s,%s,%s,pl",regname[rt],regname[rt],regname[WZR]);
    output_w32(0x1a800400|WZR<<16|COND_PL<<12|rt<<5|rt);
  }else{
    assem_debug("csel %s,%s,%s,mi",regname[rt],regname[WZR],regname[rt]);
    output_w32(0x1a800000|rt<<16|COND_MI<<12|WZR<<5|rt);
  }
}

static void emit_cmove_reg(int rs,int rt)
{
  assem_debug("csel %s,%s,%s,eq",regname[rt],regname[rs],regname[rt]);
  output_w32(0x1a800000|rt<<16|COND_EQ<<12|rs<<5|rt);
}

static void emit_cmovne_reg(int rs,int rt)
{
  assem_debug("csel %s,%s,%s,ne",regname[rt],regname[rs],regname[rt]);
  output_w32(0x1a800000|rt<<16|COND_NE<<12|rs<<5|rt);
}

static void emit_cmovl_reg(int rs,int rt)
{
  assem_debug("csel %s,%s,%s,lt",regname[rt],regname[rs],regname[rt]);
  output_w32(0x1a800000|rt<<16|COND_LT<<12|rs<<5|rt);
}

static void emit_cmovs_reg(int rs,int rt)
{
  assem_debug("csel %s,%s,%s,mi",regname[rt],regname[rs],regname[rt]);
  output_w32(0x1a800000|rt<<16|COND_MI<<12|rs<<5|rt);
}

static void emit_csel_vs(int rs1,int rs2,int rt)
{
  assem_debug("csel %s,%s,%s,vs",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1a800000|rs2<<16|COND_VS<<12|rs1<<5|rt);
}

static void emit_csel_eq(int rs1,int rs2,int rt)
{
  assem_debug("csel %s,%s,%s,eq",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1a800000|rs2<<16|COND_EQ<<12|rs1<<5|rt);
}

static void emit_csel_cc(int rs1,int rs2,int rt)
{
  assem_debug("csel %s,%s,%s,cc",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1a800000|rs2<<16|COND_CC<<12|rs1<<5|rt);
}

static void emit_csel_ls(int rs1,int rs2,int rt)
{
  assem_debug("csel %s,%s,%s,ls",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1a800000|rs2<<16|COND_LS<<12|rs1<<5|rt);
}

static void emit_slti32(int rs,int imm,int rt)
{
  if(rs!=rt) emit_zeroreg(rt);
  emit_cmpimm(rs,imm);
  if(rs==rt) emit_movimm(0,rt);
  emit_cmovl_imm(1,rt);
}

static void emit_sltiu32(int rs,int imm,int rt)
{
  if(rs!=rt) emit_zeroreg(rt);
  emit_cmpimm(rs,imm);
  if(rs==rt) emit_movimm(0,rt);
  emit_cmovb_imm(1,rt);
}

static void emit_slti64_32(int rsh,int rsl,int imm,int rt)
{
  assert(rsh!=rt);
  emit_slti32(rsl,imm,rt);
  if(imm>=0)
  {
    emit_test(rsh,rsh);
    emit_cmovne_imm(0,rt);
    emit_cmovs_imm(1,rt);
  }
  else
  {
    emit_cmpimm(rsh,-1);
    emit_cmovne_imm(0,rt);
    emit_cmovl_imm(1,rt);
  }
}

static void emit_sltiu64_32(int rsh,int rsl,int imm,int rt)
{
  assert(rsh!=rt);
  emit_sltiu32(rsl,imm,rt);
  if(imm>=0)
  {
    emit_test(rsh,rsh);
    emit_cmovne_imm(0,rt);
  }
  else
  {
    emit_cmpimm(rsh,-1);
    emit_cmovne_imm(1,rt);
  }
}

static void emit_cmp(int rs,int rt)
{
  assem_debug("cmp %s,%s",regname[rs],regname[rt]);
  output_w32(0x6b000000|rt<<16|rs<<5|WZR);
}

static void emit_set_gz32(int rs, int rt)
{
  //assem_debug("set_gz32");
  emit_cmpimm(rs,1);
  emit_movimm(1,rt);
  emit_cmovl_imm(0,rt);
}

static void emit_set_nz32(int rs, int rt)
{
  //assem_debug("set_nz32");
  if(rs!=rt) emit_mov(rs,rt);
  emit_test(rs,rs);
  emit_cmovne_imm(1,rt);
}

static void emit_set_gz64_32(int rsh, int rsl, int rt)
{
  //assem_debug("set_gz64");
  emit_set_gz32(rsl,rt);
  emit_test(rsh,rsh);
  emit_cmovne_imm(1,rt);
  emit_cmovs_imm(0,rt);
}

static void emit_set_nz64_32(int rsh, int rsl, int rt)
{
  //assem_debug("set_nz64");
  emit_or(rsh,rsl,rt);
  emit_test(rt,rt);
  emit_cmovne_imm(1,rt);
}

static void emit_set_if_less32(int rs1, int rs2, int rt)
{
  //assem_debug("set if less (%%%s,%%%s),%%%s",regname[rs1],regname[rs2],regname[rt]);
  if(rs1!=rt&&rs2!=rt) emit_zeroreg(rt);
  emit_cmp(rs1,rs2);
  if(rs1==rt||rs2==rt) emit_movimm(0,rt);
  emit_cmovl_imm(1,rt);
}

static void emit_set_if_carry32(int rs1, int rs2, int rt)
{
  //assem_debug("set if carry (%%%s,%%%s),%%%s",regname[rs1],regname[rs2],regname[rt]);
  if(rs1!=rt&&rs2!=rt) emit_zeroreg(rt);
  emit_cmp(rs1,rs2);
  if(rs1==rt||rs2==rt) emit_movimm(0,rt);
  emit_cmovb_imm(1,rt);
}

static void emit_set_if_less64_32(int u1, int l1, int u2, int l2, int rt)
{
  //assem_debug("set if less64 (%%%s,%%%s,%%%s,%%%s),%%%s",regname[u1],regname[l1],regname[u2],regname[l2],regname[rt]);
  assert(u1!=rt);
  assert(u2!=rt);
  emit_cmp(l1,l2);
  emit_movimm(0,rt);
  emit_sbcs(u1,u2,HOST_TEMPREG);
  emit_cmovl_imm(1,rt);
}

static void emit_set_if_carry64_32(int u1, int l1, int u2, int l2, int rt)
{
  //assem_debug("set if carry64 (%%%s,%%%s,%%%s,%%%s),%%%s",regname[u1],regname[l1],regname[u2],regname[l2],regname[rt]);
  assert(u1!=rt);
  assert(u2!=rt);
  emit_cmp(l1,l2);
  emit_movimm(0,rt);
  emit_sbcs(u1,u2,HOST_TEMPREG);
  emit_cmovb_imm(1,rt);
}

static void emit_call(intptr_t a)
{
  assem_debug("bl %x (%x+%x)",a,(intptr_t)out,a-(intptr_t)out);
  u_int offset=genjmp(a);
  output_w32(0x94000000|offset);
}

static void emit_jmp(intptr_t a)
{
  assem_debug("b %x (%x+%x)",a,(intptr_t)out,a-(intptr_t)out);
  u_int offset=genjmp(a);
  output_w32(0x14000000|offset);
}

static void emit_jne(intptr_t a)
{
  assem_debug("bne %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_NE);
}

static void emit_jeq(intptr_t a)
{
  assem_debug("beq %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_EQ);
}

static void emit_js(intptr_t a)
{
  assem_debug("bmi %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_MI);
}

static void emit_jns(intptr_t a)
{
  assem_debug("bpl %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_PL);
}

static void emit_jl(intptr_t a)
{
  assem_debug("blt %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_LT);
}

static void emit_jge(intptr_t a)
{
  assem_debug("bge %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_GE);
}

static void emit_jno(intptr_t a)
{
  assem_debug("bvc %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_VC);
}

static void emit_jcc(intptr_t a)
{
  assem_debug("bcc %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_CC);
}

static void emit_jae(intptr_t a)
{
  assem_debug("bcs %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_CS);
}

static void emit_jb(intptr_t a)
{
  assem_debug("bcc %x",a);
  u_int offset=gencondjmp(a);
  output_w32(0x54000000|offset<<5|COND_CC);
}

static void emit_pushreg(u_int r)
{
  assert(0);
}

static void emit_popreg(u_int r)
{
  assert(0);
}

static void emit_jmpreg(u_int r)
{
  assem_debug("br %s",regname64[r]);
  output_w32(0xd61f0000|r<<5);
}

static void emit_readword_indexed(int offset, int rs, int rt)
{
  assert(offset>-256&&offset<256);
  assem_debug("ldur %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0xb8400000|((u_int)offset&0x1ff)<<12|rs<<5|rt);
}

static void emit_readdword_indexed(int offset, int rs, int rt)
{
  assert(offset>-256&&offset<256);
  assem_debug("ldur %s,%s+%d",regname64[rt],regname64[rs],offset);
  output_w32(0xf8400000|((u_int)offset&0x1ff)<<12|rs<<5|rt);
}

static void emit_readword_dualindexedx4(int rs1, int rs2, int rt)
{
  assem_debug("ldr %s, [%s,%s lsl #2]",regname[rt],regname64[rs1],regname64[rs2]);
  output_w32(0xb8607800|rs2<<16|rs1<<5|rt);
}

static void emit_readdword_dualindexedx8(int rs1, int rs2, int rt)
{
  assem_debug("ldr %s, [%s,%s lsl #3]",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0xf8607800|rs2<<16|rs1<<5|rt);
}

static void emit_readword_indexed_tlb(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_readword_indexed(addr, rs, rt);
  else {
    assert(addr==0);
    emit_readword_dualindexedx4(rs, map, rt);
  }
}

static void emit_readdword_indexed_tlb(int addr, int rs, int map, int rh, int rl)
{
  assert(map>=0);
  if(map<0) {
    if(rh>=0) emit_readword_indexed(addr, rs, rh);
    emit_readword_indexed(addr+4, rs, rl);
  }else{
    assert(rh!=rs);
    if(rh>=0) emit_readword_indexed_tlb(addr, rs, map, rh);
    emit_addimm64(map,1,HOST_TEMPREG);
    emit_readword_indexed_tlb(addr, rs, HOST_TEMPREG, rl);
  }
}

static void emit_movsbl_indexed(int offset, int rs, int rt)
{
  assert(offset>-256&&offset<256);
  assem_debug("ldursb %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0x38c00000|((u_int)offset&0x1ff)<<12|rs<<5|rt);
}

static void emit_movsbl_indexed_tlb(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_movsbl_indexed(addr, rs, rt);
  else {
    if(addr==0) {
      emit_shlimm64(map,2,HOST_TEMPREG);
      assem_debug("ldrsb %s,[%s,%s]",regname[rt],regname64[rs],regname64[HOST_TEMPREG]);
      output_w32(0x38e06800|HOST_TEMPREG<<16|rs<<5|rt);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[rt],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|rt);
      emit_movsbl_indexed(addr, rt, rt);
    }
  }
}

static void emit_movswl_indexed(int offset, int rs, int rt)
{
  assert(offset>-256&&offset<256);
  assem_debug("ldursh %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0x78c00000|((u_int)offset&0x1ff)<<12|rs<<5|rt);
}

static void emit_movswl_indexed_tlb(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_movswl_indexed(addr, rs, rt);
  else {
    if(addr==0) {
      emit_shlimm64(map,2,HOST_TEMPREG);
      assem_debug("ldrsh %s,[%s,%s]",regname[rt],regname64[rs],regname64[HOST_TEMPREG]);
      output_w32(0x78e06800|HOST_TEMPREG<<16|rs<<5|rt);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[rt],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|rt);
      emit_movswl_indexed(addr, rt, rt);
    }
  }
}

static void emit_movzbl_indexed(int offset, int rs, int rt)
{
  assert(offset>-256&&offset<256);
  assem_debug("ldurb %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0x38400000|((u_int)offset&0x1ff)<<12|rs<<5|rt);
}

static void emit_movzbl_indexed_tlb(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_movzbl_indexed(addr, rs, rt);
  else {
    if(addr==0) {
      emit_shlimm64(map,2,HOST_TEMPREG);
      assem_debug("ldrb %s,[%s,%s]",regname[rt],regname64[rs],regname64[HOST_TEMPREG]);
      output_w32(0x38606800|HOST_TEMPREG<<16|rs<<5|rt);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[rt],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|rt);
      emit_movzbl_indexed(addr, rt, rt);
    }
  }
}

static void emit_movzwl_indexed(int offset, int rs, int rt)
{
  assert(offset>-256&&offset<256);
  assem_debug("ldurh %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0x78400000|((u_int)offset&0x1ff)<<12|rs<<5|rt);
}

static void emit_movzwl_indexed_tlb(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_movzwl_indexed(addr, rs, rt);
  else {
    if(addr==0) {
      emit_shlimm64(map,2,HOST_TEMPREG);
      assem_debug("ldrh %s,[%s,%s]",regname[rt],regname64[rs],regname64[HOST_TEMPREG]);
      output_w32(0x78606800|HOST_TEMPREG<<16|rs<<5|rt);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[rt],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|rt);
      emit_movzwl_indexed(addr, rt, rt);
    }
  }
}

static void emit_readword(intptr_t addr, int rt)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<16380LL);
  assert(offset%4 == 0); /* 4 bytes aligned */
  assem_debug("ldr %s,fp+%d",regname[rt],offset);
  output_w32(0xb9400000|((offset>>2)<<10)|(FP<<5)|rt);
}
static void emit_readdword(intptr_t addr, int rt)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<32760LL);
  assert(offset%8 == 0); /* 8 bytes aligned */
  assem_debug("ldr %s,fp+%d",regname64[rt],offset);
  output_w32(0xf9400000|((offset>>3)<<10)|(FP<<5)|rt);
}
static void emit_readptr(intptr_t addr, int rt)
{
  emit_readdword(addr,rt);
}

static void emit_movsbl(int addr, int rt)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<4096LL);
  assem_debug("ldrsb %s,fp+%d",regname[rt],offset);
  output_w32(0x39800000|offset<<10|FP<<5|rt);
}

static void emit_movswl(int addr, int rt)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<8190LL);
  assert(offset%2 == 0); /* 2 bytes aligned */
  assem_debug("ldrsh %s,fp+%d",regname[rt],offset);
  output_w32(0x79800000|((offset>>1)<<10)|(FP<<5)|rt);
}

static void emit_movzbl(intptr_t addr, int rt)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<4096LL);
  assem_debug("ldrb %s,fp+%d",regname[rt],offset);
  output_w32(0x39400000|offset<<10|FP<<5|rt);
}

static void emit_movzwl(int addr, int rt)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<8190LL);
  assert(offset%2 == 0); /* 2 bytes aligned */
  assem_debug("ldrh %s,fp+%d",regname[rt],offset);
  output_w32(0x79400000|((offset>>1)<<10)|(FP<<5)|rt);
}

static void emit_writeword_indexed(int rt, int offset, int rs)
{
  assert(offset>-256&&offset<256);
  assem_debug("stur %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0xb8000000|(((u_int)offset)&0x1ff)<<12|rs<<5|rt);
}

static void emit_writedword_indexed(int rt, int offset, int rs)
{
  assert(offset>-256&&offset<256);
  assem_debug("stur %s,%s+%d",regname64[rt],regname64[rs],offset);
  output_w32(0xf8000000|(((u_int)offset)&0x1ff)<<12|rs<<5|rt);
}

static void emit_writeword_dualindexedx4(int rt, int rs1, int rs2)
{
  assem_debug("str %s,[%s,%s lsl #2]",regname[rt],regname64[rs1],regname64[rs2]);
  output_w32(0xb8207800|rs2<<16|rs1<<5|rt);
}

static void emit_writeword_indexed_tlb(int rt, int addr, int rs, int map)
{
  if(map<0) emit_writeword_indexed(rt, addr, rs);
  else {
    if(addr==0) {
      emit_writeword_dualindexedx4(rt, rs, map);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[HOST_TEMPREG],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|HOST_TEMPREG);
      emit_writeword_indexed(rt,addr,HOST_TEMPREG);
    }
  }
}

static void emit_writedword_indexed_tlb(int rh, int rl, int addr, int rs, int map)
{
  //emit_writeword_indexed_tlb modifies HOST_TEMPREG when addr!=0
  if(map==HOST_TEMPREG) assert(addr==0);
  assert(map>=0);
  assert(rh>=0);
  emit_writeword_indexed_tlb(rh, addr, rs, map);
  emit_writeword_indexed_tlb(rl, addr+4, rs, map);
}

static void emit_writehword_indexed(int rt, int offset, int rs)
{
  assert(offset>-256&&offset<256);
  assem_debug("sturh %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0x78000000|(((u_int)offset)&0x1ff)<<12|rs<<5|rt);
}

static void emit_writehword_indexed_tlb(int rt, int addr, int rs, int map)
{
  if(map<0) emit_writehword_indexed(rt, addr, rs);
  else {
    if(addr==0) {
      emit_shlimm64(map,2,HOST_TEMPREG);
      assem_debug("strh %s,[%s,%s]",regname[rt],regname64[rs],regname64[HOST_TEMPREG]);
      output_w32(0x78206800|HOST_TEMPREG<<16|rs<<5|rt);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[HOST_TEMPREG],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|HOST_TEMPREG);
      emit_writehword_indexed(rt,addr,HOST_TEMPREG);
    }
  }
}

static void emit_writebyte_indexed(int rt, int offset, int rs)
{
  assert(offset>-256&&offset<256);
  assem_debug("sturb %s,%s+%d",regname[rt],regname64[rs],offset);
  output_w32(0x38000000|(((u_int)offset)&0x1ff)<<12|rs<<5|rt);
}

static void emit_writebyte_indexed_tlb(int rt, int addr, int rs, int map)
{
  if(map<0) emit_writebyte_indexed(rt, addr, rs);
  else {
    if(addr==0) {
      emit_shlimm64(map,2,HOST_TEMPREG);
      assem_debug("strb %s,[%s,%s]",regname[rt],regname64[rs],regname64[HOST_TEMPREG]);
      output_w32(0x38206800|HOST_TEMPREG<<16|rs<<5|rt);
    }else{
      assem_debug("add %s,%s,%s,lsl #2",regname64[HOST_TEMPREG],regname64[rs],regname64[map]);
      output_w32(0x8b000000|map<<16|2<<10|rs<<5|HOST_TEMPREG);
      emit_writebyte_indexed(rt,addr,HOST_TEMPREG);
    }
  }
}

static void emit_writeword(int rt, intptr_t addr)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<16380LL);
  assert(offset%4 == 0); /* 4 bytes aligned */
  assem_debug("str %s,fp+%d",regname[rt],offset);
  output_w32(0xb9000000|((offset>>2)<<10)|(FP<<5)|rt);
}

static void emit_writedword(int rt, intptr_t addr)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<32760LL);
  assert(offset%8 == 0); /* 8 bytes aligned */
  assem_debug("str %s,fp+%d",regname64[rt],offset);
  output_w32(0xf9000000|((offset>>3)<<10)|(FP<<5)|rt);
}

static void emit_writehword(int rt, int addr)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<8190LL);
  assert(offset%2 == 0); /* 2 bytes aligned */
  assem_debug("strh %s,fp+%d",regname[rt],offset);
  output_w32(0x79000000|((offset>>1)<<10)|(FP<<5)|rt);
}

static void emit_writebyte(int rt, intptr_t addr)
{
  intptr_t offset = addr-(intptr_t)&g_dev.r4300.new_dynarec_hot_state;
  assert(offset<4096LL);
  assem_debug("strb %s,fp+%d",regname[rt],offset);
  output_w32(0x39000000|offset<<10|(FP<<5)|rt);
}

static void emit_msub(u_int rs1,u_int rs2,u_int rs3,u_int rt)
{
  assem_debug("msub %s,%s,%s,%s",regname[rt],regname[rs1],regname[rs2],regname[rs3]);
  output_w32(0x1b008000|(rs2<<16)|(rs3<<10)|(rs1<<5)|rt);
}

static void emit_mul64(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("mul %s,%s,%s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x9b000000|(rs2<<16)|(WZR<<10)|(rs1<<5)|rt);
}

static void emit_msub64(u_int rs1,u_int rs2,u_int rs3,u_int rt)
{
  assem_debug("msub %s,%s,%s,%s",regname64[rt],regname64[rs1],regname64[rs2],regname64[rs3]);
  output_w32(0x9b008000|(rs2<<16)|(rs3<<10)|(rs1<<5)|rt);
}

static void emit_umull(u_int rs1, u_int rs2, u_int rt)
{
  assem_debug("umull %s, %s, %s",regname64[rt],regname[rs1],regname[rs2]);
  output_w32(0x9ba00000|(rs2<<16)|(WZR<<10)|(rs1<<5)|rt);
}

static void emit_umulh(u_int rs1, u_int rs2, u_int rt)
{
  assem_debug("umulh %s, %s, %s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x9bc00000|(rs2<<16)|(WZR<<10)|(rs1<<5)|rt);
}

static void emit_smull(u_int rs1, u_int rs2, u_int rt)
{
  assem_debug("smull %s, %s, %s",regname64[rt],regname[rs1],regname[rs2]);
  output_w32(0x9b200000|(rs2<<16)|(WZR<<10)|(rs1<<5)|rt);
}

static void emit_smulh(u_int rs1, u_int rs2, u_int rt)
{
  assem_debug("smulh %s, %s, %s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x9b400000|(rs2<<16)|(WZR<<10)|(rs1<<5)|rt);
}

static void emit_sdiv(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("sdiv %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1ac00c00|(rs2<<16)|(rs1<<5)|rt);
}

static void emit_udiv(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("udiv %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x1ac00800|(rs2<<16)|(rs1<<5)|rt);
}

static void emit_sdiv64(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("sdiv %s,%s,%s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x9ac00c00|(rs2<<16)|(rs1<<5)|rt);
}

static void emit_udiv64(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("udiv %s,%s,%s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x9ac00800|(rs2<<16)|(rs1<<5)|rt);
}

static void emit_bic(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("bic %s,%s,%s",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x0a200000|rs2<<16|rs1<<5|rt);
}

static void emit_bic64(u_int rs1,u_int rs2,u_int rt)
{
  assem_debug("bic %s,%s,%s",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x8a200000|rs2<<16|rs1<<5|rt);
}

// Load 2 immediates optimizing for small code size
static void emit_mov2imm_compact(int imm1,u_int rt1,int imm2,u_int rt2)
{
  emit_movimm(imm1,rt1);
  int imm=imm2-imm1;
  if(imm<0&&imm>-4096) {
    assem_debug("sub %s, %s, #%d",regname[rt2],regname[rt1],-imm&0xfff);
    output_w32(0x51000000|((-imm)&0xfff)<<10|rt1<<5|rt2);
  }else if(imm>=0&&imm<4096) {
    assem_debug("add %s, %s, #%d",regname[rt2],regname[rt1],imm&0xfff);
    output_w32(0x11000000|(imm&0xfff)<<10|rt1<<5|rt2);
  }else if(imm<0&&(-imm&0xfff)==0) {
    assem_debug("sub %s, %s, #%d lsl #%d",regname[rt2],regname[rt1],((-imm)>>12)&0xfff,12);
    output_w32(0x51400000|(((-imm)>>12)&0xfff)<<10|rt1<<5|rt2);
  }else if(imm>=0&&(imm&0xfff)==0) {
    assem_debug("add %s, %s, #%d lsl #%d",regname[rt2],regname[rt1],(imm>>12)&0xfff,12);
    output_w32(0x11400000|((imm>>12)&0xfff)<<10|rt1<<5|rt2);
  }
  else emit_movimm(imm2,rt2);
}

#ifdef HAVE_CMOV_IMM
// Conditionally select one of two immediates, optimizing for small code size
// This will only be called if HAVE_CMOV_IMM is defined
static void emit_cmov2imm_e_ne_compact(int imm1,int imm2,u_int rt)
{
  assert(0);
}
#endif

// special case for checking pending_exception
static void emit_cmpmem_imm(intptr_t addr, int imm)
{
  assert(imm==0);
  emit_readword(addr,HOST_TEMPREG);
  emit_test(HOST_TEMPREG,HOST_TEMPREG);
}

#ifndef HOST_IMM8
// special case for checking invalid_code
static void emit_cmpmem_indexedsr12_imm(int addr,int r,int imm)
{
  assert(0);
}
#endif

// special case for checking invalid_code
static void emit_cmpmem_indexedsr12_reg(int base,int r,int imm)
{
  assert(imm<128&&imm>=0);
  assert(r>=0&&r<29);
  emit_shrimm(r,12,HOST_TEMPREG);
  assem_debug("ldrb %s,[%s,%s]",regname[HOST_TEMPREG],regname64[base],regname64[HOST_TEMPREG]);
  output_w32(0x38606800|HOST_TEMPREG<<16|base<<5|HOST_TEMPREG);
  emit_cmpimm(HOST_TEMPREG,imm);
}

// special case for tlb mapping
static void emit_addsr12(int rs1,int rs2,int rt)
{
  assem_debug("add %s,%s,%s lsr #12",regname[rt],regname[rs1],regname[rs2]);
  output_w32(0x0b400000|rs2<<16|12<<10|rs1<<5|rt);
}

static void emit_addsl2(int rs1,int rs2,int rt)
{
  assem_debug("add %s,%s,%s lsl #2",regname64[rt],regname64[rs1],regname64[rs2]);
  output_w32(0x8b000000|rs2<<16|2<<10|rs1<<5|rt);
}

#ifdef HAVE_CONDITIONAL_CALL
static void emit_callne(intptr_t a)
{
  assert(0);
}
#endif

#ifdef IMM_PREFETCH
// Used to preload hash table entries
static void emit_prefetch(void *addr)
{
  assert(0);
}
#endif

#ifdef REG_PREFETCH
static void emit_prefetchreg(int r)
{
  assert(0);
}
#endif

static void emit_flds(int r,int sr)
{
  assert((sr==30)||(sr==31));
  assem_debug("ldr s%d,[%s]",sr,regname[r]);
  output_w32(0xbd400000|r<<5|sr);
}

static void emit_fldd(int r,int dr)
{
  assert((dr==30)||(dr==31));
  assem_debug("ldr d%d,[%s]",dr,regname[r]);
  output_w32(0xfd400000|r<<5|dr);
}

static void emit_fsts(int sr,int r)
{
  assert((sr==30)||(sr==31));
  assem_debug("str s%d,[%s]",sr,regname[r]);
  output_w32(0xbd000000|r<<5|sr);
}

static void emit_fstd(int dr,int r)
{
  assert((dr==30)||(dr==31));
  assem_debug("str d%d,[%s]",dr,regname[r]);
  output_w32(0xfd000000|r<<5|dr);
}

static void emit_fsqrts(int s,int d)
{
  assert(s==31);
  assert(d==31);
  assem_debug("fsqrts s%d,s%d",d,s);
  output_w32(0x1e21c000|s<<5|d);
}

static void emit_fsqrtd(int s,int d)
{
  assert(s==31);
  assert(d==31);
  assem_debug("fsqrtd d%d,d%d",d,s);
  output_w32(0x1e61c000|s<<5|d);
}

static void emit_fabss(int s,int d)
{
  assert(s==31);
  assert(d==31);
  assem_debug("fabss s%d,s%d",d,s);
  output_w32(0x1e20c000|s<<5|d);
}

static void emit_fabsd(int s,int d)
{
  assert(s==31);
  assert(d==31);
  assem_debug("fabsd d%d,d%d",d,s);
  output_w32(0x1e60c000|s<<5|d);
}

static void emit_fnegs(int s,int d)
{
  assert(s==31);
  assert(d==31);
  assem_debug("fnegs s%d,s%d",d,s);
  output_w32(0x1e214000|s<<5|d);
}

static void emit_fnegd(int s,int d)
{
  assert(s==31);
  assert(d==31);
  assem_debug("fnegd d%d,d%d",d,s);
  output_w32(0x1e614000|s<<5|d);
}

static void emit_fadds(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fadds s%d,s%d,s%d",d,s1,s2);
  output_w32(0x1e202800|s2<<16|s1<<5|d);
}

static void emit_faddd(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("faddd d%d,d%d,d%d",d,s1,s2);
  output_w32(0x1e602800|s2<<16|s1<<5|d);
}

static void emit_fsubs(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fsubs s%d,s%d,s%d",d,s1,s2);
  output_w32(0x1e203800|s2<<16|s1<<5|d);
}

static void emit_fsubd(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fsubd d%d,d%d,d%d",d,s1,s2);
  output_w32(0x1e603800|s2<<16|s1<<5|d);
}

static void emit_fmuls(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fmuls s%d,s%d,s%d",d,s1,s2);
  output_w32(0x1e200800|s2<<16|s1<<5|d);
}

static void emit_fmuld(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fmuld d%d,d%d,d%d",d,s1,s2);
  output_w32(0x1e600800|s2<<16|s1<<5|d);
}

static void emit_fdivs(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fdivs s%d,s%d,s%d",d,s1,s2);
  output_w32(0x1e201800|s2<<16|s1<<5|d);
}

static void emit_fdivd(int s1,int s2,int d)
{
  assert(s1==31);
  assert((s2==30)||(s2==31));
  assert(d==31);
  assem_debug("fdivd d%d,d%d,d%d",d,s1,s2);
  output_w32(0x1e601800|s2<<16|s1<<5|d);
}

static void emit_scvtf_s_w(int rs,int rd)
{
  //int32_t -> float
  assert(rd==31);
  assem_debug("scvtf s%d,%s",rd,regname[rs]);
  output_w32(0x1e220000|rs<<5|rd);
}

static void emit_scvtf_d_w(int rs,int rd)
{
  //int32_t -> double
  assert(rd==31);
  assem_debug("scvtf d%d,%s",rd,regname[rs]);
  output_w32(0x1e620000|rs<<5|rd);
}

static void emit_scvtf_s_l(int rs,int rd)
{
  //int64_t -> float
  assert(rd==31);
  assem_debug("scvtf s%d,%s",rd,regname64[rs]);
  output_w32(0x9e220000|rs<<5|rd);
}

static void emit_scvtf_d_l(int rs,int rd)
{
  //int64_t -> double
  assert(rd==31);
  assem_debug("scvtf d%d,%s",rd,regname64[rs]);
  output_w32(0x9e620000|rs<<5|rd);
}

static void emit_fcvt_d_s(int rs,int rd)
{
  //float -> double
  assert(rs==31);
  assert(rd==31);
  assem_debug("fcvt d%d,s%d",rd,rs);
  output_w32(0x1e22c000|rs<<5|rd);
}

static void emit_fcvt_s_d(int rs,int rd)
{
  //double -> float
  assert(rs==31);
  assert(rd==31);
  assem_debug("fcvt s%d,d%d",rd,rs);
  output_w32(0x1e624000|rs<<5|rd);
}

static void emit_fcvtns_l_s(int rs,int rd)
{
  //float -> int64_t round toward nearest
  assert(rs==31);
  assem_debug("fcvtns %s,s%d,",regname64[rd],rs);
  output_w32(0x9e200000|rs<<5|rd);
}

static void emit_fcvtns_w_s(int rs,int rd)
{
  //float -> int32_t round toward nearest
  assert(rs==31);
  assem_debug("fcvtns %s,s%d,",regname[rd],rs);
  output_w32(0x1e200000|rs<<5|rd);
}

static void emit_fcvtns_l_d(int rs,int rd)
{
  //double -> int64_t round toward nearest
  assert(rs==31);
  assem_debug("fcvtns %s,d%d,",regname64[rd],rs);
  output_w32(0x9e600000|rs<<5|rd);
}

static void emit_fcvtns_w_d(int rs,int rd)
{
  //double -> int32_t round toward nearest
  assert(rs==31);
  assem_debug("fcvtns %s,d%d,",regname[rd],rs);
  output_w32(0x1e600000|rs<<5|rd);
}

static void emit_fcvtzs_l_s(int rs,int rd)
{
  //float -> int64_t round toward zero
  assert(rs==31);
  assem_debug("fcvtzs %s,s%d,",regname64[rd],rs);
  output_w32(0x9e380000|rs<<5|rd);
}

static void emit_fcvtzs_w_s(int rs,int rd)
{
  //float -> int32_t round toward zero
  assert(rs==31);
  assem_debug("fcvtzs %s,s%d,",regname[rd],rs);
  output_w32(0x1e380000|rs<<5|rd);
}

static void emit_fcvtzs_l_d(int rs,int rd)
{
  //double -> int64_t round toward zero
  assert(rs==31);
  assem_debug("fcvtzs %s,d%d,",regname64[rd],rs);
  output_w32(0x9e780000|rs<<5|rd);
}

static void emit_fcvtzs_w_d(int rs,int rd)
{
  //double -> int32_t round toward zero
  assert(rs==31);
  assem_debug("fcvtzs %s,d%d,",regname[rd],rs);
  output_w32(0x1e780000|rs<<5|rd);
}

static void emit_fcvtps_l_s(int rs,int rd)
{
  //float -> int64_t round toward +inf
  assert(rs==31);
  assem_debug("fcvtps %s,s%d,",regname64[rd],rs);
  output_w32(0x9e280000|rs<<5|rd);
}

static void emit_fcvtps_w_s(int rs,int rd)
{
  //float -> int32_t round toward +inf
  assert(rs==31);
  assem_debug("fcvtps %s,s%d,",regname[rd],rs);
  output_w32(0x1e280000|rs<<5|rd);
}

static void emit_fcvtps_l_d(int rs,int rd)
{
  //double -> int64_t round toward +inf
  assert(rs==31);
  assem_debug("fcvtps %s,d%d,",regname64[rd],rs);
  output_w32(0x9e680000|rs<<5|rd);
}

static void emit_fcvtps_w_d(int rs,int rd)
{
  //double -> int32_t round toward +inf
  assert(rs==31);
  assem_debug("fcvtps %s,d%d,",regname[rd],rs);
  output_w32(0x1e680000|rs<<5|rd);
}

static void emit_fcvtms_l_s(int rs,int rd)
{
  //float -> int64_t round toward -inf
  assert(rs==31);
  assem_debug("fcvtms %s,s%d,",regname64[rd],rs);
  output_w32(0x9e300000|rs<<5|rd);
}

static void emit_fcvtms_w_s(int rs,int rd)
{
  //float -> int32_t round toward -inf
  assert(rs==31);
  assem_debug("fcvtms %s,s%d,",regname[rd],rs);
  output_w32(0x1e300000|rs<<5|rd);
}

static void emit_fcvtms_l_d(int rs,int rd)
{
  //double -> int64_t round toward -inf
  assert(rs==31);
  assem_debug("fcvtms %s,d%d,",regname64[rd],rs);
  output_w32(0x9e700000|rs<<5|rd);
}

static void emit_fcvtms_w_d(int rs,int rd)
{
  //double -> int32_t round toward -inf
  assert(rs==31);
  assem_debug("fcvtms %s,d%d,",regname[rd],rs);
  output_w32(0x1e700000|rs<<5|rd);
}

static void emit_fcmps(int x,int y)
{
  assert(x==30);
  assert(y==31);
  assem_debug("fcmp s%d, s%d",x,y);
  output_w32(0x1e202000|y<<16|x<<5);
}

static void emit_fcmpd(int x,int y)
{
  assert(x==30);
  assert(y==31);
  assem_debug("fcmp d%d, d%d",x,y);
  output_w32(0x1e602000|y<<16|x<<5);
}

static void emit_jno_unlikely(intptr_t a)
{
  emit_jno(a);
}

static void emit_breakpoint(u_int imm)
{
  assem_debug("brk #%d",imm);
  output_w32(0xd4200000|imm<<5);
}

static void emit_adr(intptr_t addr, int rt)
{
  intptr_t out_rx=(intptr_t)out;
  if(addr<(intptr_t)base_addr||addr>=(intptr_t)base_addr+(1<<TARGET_SIZE_2))
    out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;

  intptr_t offset=addr-(intptr_t)out_rx;
  assert(offset>=-1048576LL&&offset<1048576LL);
  assem_debug("adr %d,#%d",regname64[rt],offset);
  output_w32(0x10000000|(offset&0x3)<<29|((offset>>2)&0x7ffff)<<5|rt);
}
static void emit_adrp(intptr_t addr, int rt)
{
  intptr_t out_rx=(intptr_t)out;
  if(addr<(intptr_t)base_addr||addr>=(intptr_t)base_addr+(1<<TARGET_SIZE_2))
    out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;

  intptr_t offset=((addr&~0xfffLL)-((intptr_t)out_rx&~0xfffLL));
  assert(offset>=-4294967296LL&&offset<4294967296LL);
  offset>>=12;
  assert((((intptr_t)out_rx&~0xfffLL)+(offset<<12))==(addr&~0xfffLL));
  assem_debug("adrp %d,#%d",regname64[rt],offset);
  output_w32(0x90000000|(offset&0x3)<<29|((offset>>2)&0x7ffff)<<5|rt);
}
static void emit_pc_relative_addr(intptr_t addr, int rt)
{
  intptr_t out_rx=(intptr_t)out;
  if(addr<(intptr_t)base_addr||addr>=(intptr_t)base_addr+(1<<TARGET_SIZE_2))
    out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;

  intptr_t offset=addr-(intptr_t)out_rx;
  if(offset>=-1048576LL&&offset<1048576LL){
    emit_adr(addr,rt);
  }
  else{
    emit_adrp(addr,rt);
    if((addr&0xfffLL)!=0){
      emit_addimm64(rt,(addr&0xfffLL),rt);
    }
  }
}

// Save registers before function call
static void save_regs(u_int reglist)
{
  signed char rt[2];
  int index=0;
  int offset=0;

  reglist&=CALLER_SAVED_REGS; // only save the caller-save registers, x0-x18
  if(!reglist) return;

  int i;
  for(i=0; reglist!=0; i++){
    if(reglist&1){
      rt[index]=i;
      index++;
    }
    if(index>1){
      assert(offset>=0&&offset<=136);
      assem_debug("stp %s,%s,[fp+#%d]",regname64[rt[0]],regname64[rt[1]],offset);
      output_w32(0xa9000000|(offset>>3)<<15|rt[1]<<10|FP<<5|rt[0]);
      offset+=16;
      index=0;
    }
    reglist>>=1;
  }

  if(index!=0) {
    assert(index==1);
    assert(offset>=0&&offset<=144);
    assem_debug("str %s,[fp+#%d]",regname64[rt[0]],offset);
    output_w32(0xf9000000|(offset>>3)<<10|FP<<5|rt[0]);
  }
}
// Restore registers after function call
static void restore_regs(u_int reglist)
{
  signed char rt[2];
  int index=0;
  int offset=0;

  reglist&=CALLER_SAVED_REGS; // only restore the caller-save registers, x0-x18
  if(!reglist) return;

  int i;
  for(i=0; reglist!=0; i++){
    if(reglist&1){
      rt[index]=i;
      index++;
    }
    if(index>1){
      assert(offset>=0&&offset<=136);
      assem_debug("ldp %s,%s,[fp+#%d]",regname[rt[0]],regname[rt[1]],offset);
      output_w32(0xa9400000|(offset>>3)<<15|rt[1]<<10|FP<<5|rt[0]);
      offset+=16;
      index=0;
    }
    reglist>>=1;
  }

  if(index!=0) {
    assert(index==1);
    assert(offset>=0&&offset<=144);
    assem_debug("ldr %s,[fp+#%d]",regname[rt[0]],offset);
    output_w32(0xf9400000|(offset>>3)<<10|FP<<5|rt[0]);
  }
}

/* Stubs/epilogue */

static void literal_pool(int n)
{
  if((!literalcount)||(n!=0)) return;
  u_int *ptr;
  int i;
  for(i=0;i<literalcount;i++)
  {
    ptr=(u_int *)literals[i][0];
    intptr_t offset=(intptr_t)out-(intptr_t)ptr;
    assert(offset>=-1048576LL&&offset<1048576LL);
    assert((offset&3)==0);
    *ptr|=((offset>>2)<<5);
    output_w64(literals[i][1]);
  }
  literalcount=0;
}

static void literal_pool_jumpover(int n)
{
  (void)n;
}

static void emit_extjump2(intptr_t addr, int target, intptr_t linker)
{
  u_char *ptr=(u_char *)addr;
  assert(((ptr[3]&0xfc)==0x14)||((ptr[3]&0xff)==0x54)); //b or b.cond

  emit_movz_lsl16(((u_int)target>>16)&0xffff,1);
  emit_movk((u_int)target&0xffff,1);

  //addr is in the current recompiled block (max 256k)
  //offset shouldn't exceed +/-1MB
  emit_adr(addr,0);
  emit_jmp(linker);
}

static void do_invstub(int n)
{
  literal_pool(20);
  u_int reglist=stubs[n][3];
  set_jump_target(stubs[n][1],(intptr_t)out);
  save_regs(reglist);
  if(stubs[n][4]!=0) emit_mov(stubs[n][4],0);
  emit_call((intptr_t)&invalidate_addr);
  restore_regs(reglist);
  emit_jmp(stubs[n][2]); // return address
}

static intptr_t do_dirty_stub(int i, struct ll_entry * head)
{
  assem_debug("do_dirty_stub %x",head->vaddr);
  intptr_t out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;
  intptr_t offset=(((intptr_t)head&~0xfffLL)-((intptr_t)out_rx&~0xfffLL));

  if((uintptr_t)head<4294967296LL){
    emit_movz_lsl16(((uintptr_t)head>>16)&0xffff,ARG1_REG);
    emit_movk(((uintptr_t)head)&0xffff,ARG1_REG);
  	}else if(offset>=-4294967296LL&&offset<4294967296LL){
    emit_adrp((intptr_t)head,ARG1_REG);
    emit_addimm64(ARG1_REG,((intptr_t)head&0xfffLL),ARG1_REG);
    }else{
      emit_loadlp((intptr_t)head,ARG1_REG);
  }

  emit_call((intptr_t)verify_code);

  intptr_t entry=(intptr_t)out;
  load_regs_entry(i);
  if(entry==(intptr_t)out) entry=instr_addr[i];
  emit_jmp(instr_addr[i]);
  return entry;
}

static void do_dirty_stub_ds(struct ll_entry *head)
{
  assem_debug("do_dirty_stub_ds %x",head->vaddr);
  intptr_t out_rx=((intptr_t)out-(intptr_t)base_addr)+(intptr_t)base_addr_rx;
  intptr_t offset=(((intptr_t)head&~0xfffLL)-((intptr_t)out_rx&~0xfffLL));

  if((uintptr_t)head<4294967296LL){
    emit_movz_lsl16(((uintptr_t)head>>16)&0xffff,ARG1_REG);
    emit_movk(((uintptr_t)head)&0xffff,ARG1_REG);
    }else if(offset>=-4294967296LL&&offset<4294967296LL){
    emit_adrp((intptr_t)head,ARG1_REG);
    emit_addimm64(ARG1_REG,((intptr_t)head&0xfffLL),ARG1_REG);
    }else{
      emit_loadlp((intptr_t)head,ARG1_REG);
  }

  emit_call((intptr_t)verify_code);
}

/* TLB */

static int do_tlb_r(int s,int ar,int map,int cache,int x,int c,u_int addr)
{
  if(c) {
    if((signed int)addr>=(signed int)0xC0000000) {
      // address_generation already loaded the const
      emit_readdword_dualindexedx8(FP,map,map);
    }
    else if((signed int)addr<(signed int)0x80800000){
      emit_loadreg(ROREG,HOST_TEMPREG); // On 64bit ROREG is needed to load from RDRAM
      return HOST_TEMPREG;
    }
    else
      return -1; // No mapping
  }
  else {
    assert(s!=map);
    if(cache>=0) {
      // Use cached offset to memory map
      emit_addsr12(cache,s,map);
    }else{
      emit_loadreg(MMREG,map);
      emit_addsr12(map,s,map);
    }
    // Schedule this while we wait on the load
    //if(x) emit_xorimm(s,x,ar);
    emit_readdword_dualindexedx8(FP,map,map);
  }
  return map;
}

static int do_tlb_r_branch(int map, int c, u_int addr, intptr_t *jaddr)
{
  if(!c||(signed int)addr>=(signed int)0xC0000000) {
    emit_test64(map,map);
    *jaddr=(intptr_t)out;
    emit_js(0);
  }
  return map;
}

static int do_tlb_w(int s,int ar,int map,int cache,int x,int c,u_int addr)
{
  if(c) {
    if(addr<0x80800000||addr>=0xC0000000) {
      // address_generation already loaded the const
      emit_readdword_dualindexedx8(FP,map,map);
    }
    else
      return -1; // No mapping
  }
  else {
    assert(s!=map);
    if(cache>=0) {
      // Use cached offset to memory map
      emit_addsr12(cache,s,map);
    }else{
      emit_loadreg(MMREG,map);
      emit_addsr12(map,s,map);
    }
    // Schedule this while we wait on the load
    //if(x) emit_xorimm(s,x,ar);
    emit_readdword_dualindexedx8(FP,map,map);
  }
  return map;
}

static void do_tlb_w_branch(int map, int c, u_int addr, intptr_t *jaddr)
{
  if(!c||addr<0x80800000||addr>=0xC0000000) {
    emit_testimm64(map,WRITE_PROTECT);
    *jaddr=(intptr_t)out;
    emit_jne(0);
  }
}

// Generate the address of the memory_map entry, relative to dynarec_local
static void generate_map_const(u_int addr,int tr) {
  //DebugMessage(M64MSG_VERBOSE, "generate_map_const(%x,%s)",addr,regname[tr]);
  emit_movimm((addr>>12)+(fp_memory_map>>3),tr);
}

static void set_rounding_mode(int s,int temp)
{
  assert(temp>=0);
  emit_andimm(s,3,temp);
  emit_addimm64(FP,fp_rounding_modes,HOST_TEMPREG);
  emit_readword_dualindexedx4(HOST_TEMPREG,temp,temp);
  output_w32(0xd53b4400|HOST_TEMPREG); /*Read FPCR*/
  emit_andimm(HOST_TEMPREG,~0xc00000,HOST_TEMPREG); /*Clear RMode*/
  emit_or(temp,HOST_TEMPREG,HOST_TEMPREG); /*Set RMode*/
  output_w32(0xd51b4400|HOST_TEMPREG); /*Write FPCR*/
}

/* Special assem */
static void shift_assemble_arm64(int i,struct regstat *i_regs)
{
  if(rt1[i]) {
    if(opcode2[i]<=0x07) // SLLV/SRLV/SRAV
    {
      signed char s,t,shift;
      t=get_reg(i_regs->regmap,rt1[i]);
      s=get_reg(i_regs->regmap,rs1[i]);
      shift=get_reg(i_regs->regmap,rs2[i]);
      if(t>=0){
        if(rs1[i]==0)
        {
          emit_zeroreg(t);
        }
        else if(rs2[i]==0)
        {
          assert(s>=0);
          if(s!=t) emit_mov(s,t);
        }
        else
        {
          emit_andimm(shift,31,HOST_TEMPREG);
          if(opcode2[i]==4) // SLLV
          {
            emit_shl(s,HOST_TEMPREG,t);
          }
          if(opcode2[i]==6) // SRLV
          {
            emit_shr(s,HOST_TEMPREG,t);
          }
          if(opcode2[i]==7) // SRAV
          {
            emit_sar(s,HOST_TEMPREG,t);
          }
        }
      }
    } else { // DSLLV/DSRLV/DSRAV
      signed char sh,sl,th,tl,shift;
      th=get_reg(i_regs->regmap,rt1[i]|64);
      tl=get_reg(i_regs->regmap,rt1[i]);
      sh=get_reg(i_regs->regmap,rs1[i]|64);
      sl=get_reg(i_regs->regmap,rs1[i]);
      shift=get_reg(i_regs->regmap,rs2[i]);
      if(tl>=0){
        if(rs1[i]==0)
        {
          emit_zeroreg(tl);
          if(th>=0) emit_zeroreg(th);
        }
        else if(rs2[i]==0)
        {
          assert(sl>=0);
          if(sl!=tl) emit_mov(sl,tl);
          if(th>=0&&sh!=th) emit_mov(sh,th);
        }
        else
        {
          assert(sl>=0);
          assert(sh>=0);
          if(opcode2[i]==0x14) // DSLLV
          {
            emit_mov(sl,HOST_TEMPREG);
            emit_orrshlimm64(sh,32,HOST_TEMPREG);
            emit_shl64(HOST_TEMPREG,shift,HOST_TEMPREG);
            emit_mov(HOST_TEMPREG,tl);
            if(th>=0) emit_shrimm64(HOST_TEMPREG,32,th);
          }
          if(opcode2[i]==0x16) // DSRLV
          {
            emit_mov(sl,HOST_TEMPREG);
            emit_orrshlimm64(sh,32,HOST_TEMPREG);
            emit_shr64(HOST_TEMPREG,shift,HOST_TEMPREG);
            emit_mov(HOST_TEMPREG,tl);
            if(th>=0) emit_shrimm64(HOST_TEMPREG,32,th);
          }
          if(opcode2[i]==0x17) // DSRAV
          {
            emit_mov(sl,HOST_TEMPREG);
            emit_orrshlimm64(sh,32,HOST_TEMPREG);
            emit_sar64(HOST_TEMPREG,shift,HOST_TEMPREG);
            emit_mov(HOST_TEMPREG,tl);
            if(th>=0) emit_shrimm64(HOST_TEMPREG,32,th);
          }
        }
      }
    }
  }
}
#define shift_assemble shift_assemble_arm64

static void loadlr_assemble_arm64(int i,struct regstat *i_regs)
{
  signed char s,th,tl,temp,temp2,temp2h,addr,map=-1,cache=-1;
  int offset,type=0,memtarget=0,c=0;
  intptr_t jaddr=0;
  u_int hr,reglist=0;
  th=get_reg(i_regs->regmap,rt1[i]|64);
  tl=get_reg(i_regs->regmap,rt1[i]);
  s=get_reg(i_regs->regmap,rs1[i]);
  temp=get_reg(i_regs->regmap,-1);
  temp2=get_reg(i_regs->regmap,FTEMP);
  temp2h=get_reg(i_regs->regmap,FTEMP|64);
  addr=get_reg(i_regs->regmap,AGEN1+(i&1));
  assert(addr<0);
  assert(temp>=0);
  assert(temp2>=0);
  offset=imm[i];

  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }
  reglist|=1<<temp;
  if(s>=0) {
    c=(i_regs->wasconst>>s)&1;
    memtarget=c&&((signed int)(constmap[i][s]+offset))<(signed int)0x80800000;
    if(c&&using_tlb&&((signed int)(constmap[i][s]+offset))>=(signed int)0xC0000000) memtarget=1;
  }
  if(offset||s<0||c) addr=temp2;
  else addr=s;
  int dummy=(rt1[i]==0)||(tl!=get_reg(i_regs->regmap,rt1[i])); // ignore loads to r0 and unneeded reg

  switch(opcode[i]) {
    case 0x22: type=LOADWL_STUB; break;
    case 0x26: type=LOADWR_STUB; break;
    case 0x1A: type=LOADDL_STUB; break;
    case 0x1B: type=LOADDR_STUB; break;
  }

#ifndef INTERPRET_LOADLR
  int ldlr=(opcode[i]==0x1A||opcode[i]==0x1B); // LDL/LDR always do inline_readstub if non constant
  if(!using_tlb) {
    if(!c&&!ldlr) {
      emit_cmpimm(addr,0x800000);
      jaddr=(intptr_t)out;
      emit_jno(0);
    }
    #ifdef RAM_OFFSET
    if(((!c&&!ldlr)||memtarget)&&!dummy) {
      map=get_reg(i_regs->regmap,ROREG);
      if(map<0) emit_loadreg(ROREG,map=HOST_TEMPREG);
    }
    #endif
  }else{ // using tlb
    map=get_reg(i_regs->regmap,TLREG);
    cache=get_reg(i_regs->regmap,MMREG);
    assert(map>=0);
    reglist&=~(1<<map);
    if((!c&&!ldlr)||memtarget) {
      map=do_tlb_r(addr,temp2,map,cache,0,c,constmap[i][s]+offset);
      do_tlb_r_branch(map,c,constmap[i][s]+offset,&jaddr);
    }
  }
  if((!c||memtarget)&&!dummy) {
    if(opcode[i]==0x22||opcode[i]==0x26) { // LWL/LWR
      assert(tl>=0);
      if(!c) {
        emit_shlimm(addr,3,temp);
        emit_andimm(addr,~3,temp2);
        emit_readword_indexed_tlb(0,temp2,map,temp2);
        emit_andimm(temp,24,temp);
        if (opcode[i]==0x26) emit_xorimm(temp,24,temp); // LWR
        emit_movimm(-1,HOST_TEMPREG);
        if (opcode[i]==0x26) {
          emit_shr(temp2,temp,temp2);
          emit_shr(HOST_TEMPREG,temp,HOST_TEMPREG);
        }else{
          emit_shl(temp2,temp,temp2);
          emit_shl(HOST_TEMPREG,temp,HOST_TEMPREG);
        }
        emit_bic(tl,HOST_TEMPREG,tl);
        emit_or(temp2,tl,tl);
      }
      else
      {
        int shift=((constmap[i][s]+offset)&3)<<3;
        uint32_t mask=~UINT32_C(0);
        if (opcode[i]==0x26) { //LWR
          shift^=24;
          mask>>=shift;
        } else { //LWL
          mask<<=shift;
        }

        if((constmap[i][s]+offset)&3)
          emit_andimm(addr,~3,temp2);

        if(shift) {
          emit_readword_indexed_tlb(0,temp2,map,temp2);
          if (opcode[i]==0x26) emit_shrimm(temp2,shift,temp2);
          else emit_shlimm(temp2,shift,temp2);
          emit_andimm(tl,~mask,tl);
          emit_or(temp2,tl,tl);
        }
        else
          emit_readword_indexed_tlb(0,temp2,map,tl);
      }
    }
    if(opcode[i]==0x1A||opcode[i]==0x1B) { // LDL/LDR
      assert(tl>=0);
      assert(th>=0);
      assert(temp2h>=0);
      if(!c) {
        //TODO: implement recompiled code
        inline_readstub(type,i,0,addr,i_regs,rt1[i],ccadj[i],reglist);
      }
      else
      {
        int shift=((constmap[i][s]+offset)&7)<<3;
        uint64_t mask=~UINT64_C(0);
        if (opcode[i]==0x1B) { //LDR
          shift^=56;
          mask>>=shift;
        } else { //LDL
          mask<<=shift;
        }

        if((constmap[i][s]+offset)&7)
          emit_andimm(addr,~7,temp2);

        if(shift) {
          emit_readdword_indexed_tlb(0,temp2,map,temp2h,temp2);
          if (opcode[i]==0x1B) {
            emit_shrdimm(temp2h,temp2,shift,temp2h);
            emit_shrimm(temp2,shift,temp2);
          } else {
            emit_shldimm(temp2h,temp2,shift,temp2h);
            emit_shlimm(temp2,shift,temp2);
          }
          emit_andimm(tl,~mask,tl);
          emit_andimm(th,~mask>>32,th);
          emit_or(temp2,tl,tl);
          emit_or(temp2h,th,th);
        }
        else
          emit_readdword_indexed_tlb(0,temp2,map,th,tl);
      }
    }
  }
  if(jaddr) {
    add_stub(type,jaddr,(intptr_t)out,i,addr,(intptr_t)i_regs,ccadj[i],reglist);
  } else if(c&&!memtarget) {
    inline_readstub(type,i,(constmap[i][s]+offset),addr,i_regs,rt1[i],ccadj[i],reglist);
  }
#else
  inline_readstub(type,i,c?(constmap[i][s]+offset):0,addr,i_regs,rt1[i],ccadj[i],reglist);
#endif
}
#define loadlr_assemble loadlr_assemble_arm64

static void fconv_assemble_arm64(int i,struct regstat *i_regs)
{
  signed char temp=get_reg(i_regs->regmap,-1);
  assert(temp>=0);
  // Check cop1 unusable
  if(!cop1_usable) {
    signed char rs=get_reg(i_regs->regmap,CSREG);
    assert(rs>=0);
    emit_testimm(rs,CP0_STATUS_CU1);
    intptr_t jaddr=(intptr_t)out;
    emit_jeq(0);
    add_stub(FP_STUB,jaddr,(intptr_t)out,i,rs,(intptr_t)i_regs,is_delayslot,0);
    cop1_usable=1;
  }

#ifndef INTERPRET_FCONV
  /*Single-precision to Integer*/

  //TOBEDONE
  //if(opcode2[i]==0x10&&(source[i]&0x3f)==0x24) { //cvt_w_s
  //}

  //if(opcode2[i]==0x10&&(source[i]&0x3f)==0x25) { //cvt_l_s
  //}

  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x08) { //round_l_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtns_l_s(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x09) { //trunc_l_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtzs_l_s(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0a) { //ceil_l_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtps_l_s(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0b) { //floor_l_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtms_l_s(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0c) { //round_w_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtns_w_s(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0d) { //trunc_w_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtzs_w_s(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0e) { //ceil_w_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtps_w_s(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0f) { //floor_w_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_fcvtms_w_s(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }

  /*Double-precision to Integer*/

  //TOBEDONE
  //if(opcode2[i]==0x11&&(source[i]&0x3f)==0x24) { //cvt_w_d
  //}

  //if(opcode2[i]==0x11&&(source[i]&0x3f)==0x25) { //cvt_l_d
  //}

  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x08) { //round_l_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtns_l_d(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x09) { //trunc_l_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtzs_l_d(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0a) { //ceil_l_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtps_l_d(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0b) { //floor_l_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtms_l_d(31,HOST_TEMPREG);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_writedword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0c) { //round_w_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtns_w_d(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0d) { //trunc_w_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtzs_w_d(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0e) { //ceil_w_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtps_w_d(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0f) { //floor_w_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvtms_w_d(31,HOST_TEMPREG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_writeword_indexed(HOST_TEMPREG,0,temp);
    return;
  }

  /*Single-precision to Double-precision*/
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x21) { //cvt_d_s
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_flds(temp,31);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_fcvt_d_s(31,31);
    emit_fstd(31,temp);
    return;
  }

  /*Double-precision to Single-precision*/
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x20) { //cvt_s_d
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_fldd(temp,31);
    emit_fcvt_s_d(31,31);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_fsts(31,temp);
    return;
  }

  /*Integer to Single-precision*/
  if(opcode2[i]==0x14&&(source[i]&0x3f)==0x20) { //cvt_s_w
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_readword_indexed(0,temp,HOST_TEMPREG);
    emit_scvtf_s_w(HOST_TEMPREG,31);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_fsts(31,temp);
    return;
  }

  if(opcode2[i]==0x15&&(source[i]&0x3f)==0x20) { //cvt_s_l
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_readdword_indexed(0,temp,HOST_TEMPREG);
    emit_scvtf_s_l(HOST_TEMPREG,31);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
    emit_fsts(31,temp);
    return;
  }

  /*Integer Double-precision*/
  if(opcode2[i]==0x14&&(source[i]&0x3f)==0x21) { //cvt_d_w
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_readword_indexed(0,temp,HOST_TEMPREG);
    emit_scvtf_d_w(HOST_TEMPREG,31);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_fstd(31,temp);
    return;
  }

  if(opcode2[i]==0x15&&(source[i]&0x3f)==0x21) { //cvt_d_l
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_readdword_indexed(0,temp,HOST_TEMPREG);
    emit_scvtf_d_l(HOST_TEMPREG,31);
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f))
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
    emit_fstd(31,temp);
    return;
  }
#endif

  // C emulation code

  u_int hr,reglist=0;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }

  signed char fs=get_reg(i_regs->regmap,FSREG);
  save_regs(reglist);

  if(opcode2[i]==0x14&&(source[i]&0x3f)==0x20) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_s_w);
  }
  if(opcode2[i]==0x14&&(source[i]&0x3f)==0x21) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)cvt_d_w);
  }
  if(opcode2[i]==0x15&&(source[i]&0x3f)==0x20) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_s_l);
  }
  if(opcode2[i]==0x15&&(source[i]&0x3f)==0x21) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_d_l);
  }

  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x21) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)cvt_d_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x24) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_w_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x25) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_l_s);
  }

  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x20) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_s_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x24) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_w_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x25) {
    if(fs>=0) emit_mov(fs,ARG1_REG);
    else emit_loadreg(FSREG,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG3_REG);
    emit_call((intptr_t)cvt_l_d);
  }

  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x08) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)round_l_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x09) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)trunc_l_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0a) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)ceil_l_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0b) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)floor_l_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0c) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)round_w_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0d) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)trunc_w_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0e) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)ceil_w_s);
  }
  if(opcode2[i]==0x10&&(source[i]&0x3f)==0x0f) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)floor_w_s);
  }

  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x08) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)round_l_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x09) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)trunc_l_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0a) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)ceil_l_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0b) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)floor_l_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0c) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)round_w_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0d) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)trunc_w_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0e) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)ceil_w_d);
  }
  if(opcode2[i]==0x11&&(source[i]&0x3f)==0x0f) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
    emit_call((intptr_t)floor_w_d);
  }

  restore_regs(reglist);
}
#define fconv_assemble fconv_assemble_arm64

static void fcomp_assemble(int i,struct regstat *i_regs)
{
  signed char fs=get_reg(i_regs->regmap,FSREG);
  signed char temp=get_reg(i_regs->regmap,-1);
  assert(temp>=0);
  // Check cop1 unusable
  if(!cop1_usable) {
    signed char cs=get_reg(i_regs->regmap,CSREG);
    assert(cs>=0);
    emit_testimm(cs,CP0_STATUS_CU1);
    intptr_t jaddr=(intptr_t)out;
    emit_jeq(0);
    add_stub(FP_STUB,jaddr,(intptr_t)out,i,cs,(intptr_t)i_regs,is_delayslot,0);
    cop1_usable=1;
  }

#ifndef INTERPRET_FCOMP
  if((source[i]&0x3f)==0x30) {
    emit_andimm(fs,~0x800000,fs);
    return;
  }

  if((source[i]&0x3e)==0x38) {
    // sf/ngle - these should throw exceptions for NaNs
    emit_andimm(fs,~0x800000,fs);
    return;
  }

  if(opcode2[i]==0x10) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>16)&0x1f],HOST_TEMPREG);
    emit_flds(temp,30);
    emit_flds(HOST_TEMPREG,31);
    emit_andimm(fs,~0x800000,fs);
    emit_orimm(fs,0x800000,temp);
    emit_fcmps(30,31);
    if((source[i]&0x3f)==0x31) emit_csel_vs(temp,fs,fs); // c_un_s
    if((source[i]&0x3f)==0x32) emit_csel_eq(temp,fs,fs); // c_eq_s
    if((source[i]&0x3f)==0x33) {emit_csel_eq(temp,fs,fs);emit_csel_vs(temp,fs,fs);} // c_ueq_s
    if((source[i]&0x3f)==0x34) emit_csel_cc(temp,fs,fs); // c_olt_s
    if((source[i]&0x3f)==0x35) {emit_csel_cc(temp,fs,fs);emit_csel_vs(temp,fs,fs);} // c_ult_s
    if((source[i]&0x3f)==0x36) emit_csel_ls(temp,fs,fs); // c_ole_s
    if((source[i]&0x3f)==0x37) {emit_csel_ls(temp,fs,fs);emit_csel_vs(temp,fs,fs);} // c_ule_s
    if((source[i]&0x3f)==0x3a) emit_csel_eq(temp,fs,fs); // c_seq_s
    if((source[i]&0x3f)==0x3b) emit_csel_eq(temp,fs,fs); // c_ngl_s
    if((source[i]&0x3f)==0x3c) emit_csel_cc(temp,fs,fs); // c_lt_s
    if((source[i]&0x3f)==0x3d) emit_csel_cc(temp,fs,fs); // c_nge_s
    if((source[i]&0x3f)==0x3e) emit_csel_ls(temp,fs,fs); // c_le_s
    if((source[i]&0x3f)==0x3f) emit_csel_ls(temp,fs,fs); // c_ngt_s
    return;
  }
  if(opcode2[i]==0x11) {
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>16)&0x1f],HOST_TEMPREG);
    emit_fldd(temp,30);
    emit_fldd(HOST_TEMPREG,31);
    emit_andimm(fs,~0x800000,fs);
    emit_orimm(fs,0x800000,temp);
    emit_fcmpd(30,31);
    if((source[i]&0x3f)==0x31) emit_csel_vs(temp,fs,fs); // c_un_d
    if((source[i]&0x3f)==0x32) emit_csel_eq(temp,fs,fs); // c_eq_d
    if((source[i]&0x3f)==0x33) {emit_csel_eq(temp,fs,fs);emit_csel_vs(temp,fs,fs);} // c_ueq_d
    if((source[i]&0x3f)==0x34) emit_csel_cc(temp,fs,fs); // c_olt_d
    if((source[i]&0x3f)==0x35) {emit_csel_cc(temp,fs,fs);emit_csel_vs(temp,fs,fs);} // c_ult_d
    if((source[i]&0x3f)==0x36) emit_csel_ls(temp,fs,fs); // c_ole_d
    if((source[i]&0x3f)==0x37) {emit_csel_ls(temp,fs,fs);emit_csel_vs(temp,fs,fs);} // c_ule_d
    if((source[i]&0x3f)==0x3a) emit_csel_eq(temp,fs,fs); // c_seq_d
    if((source[i]&0x3f)==0x3b) emit_csel_eq(temp,fs,fs); // c_ngl_d
    if((source[i]&0x3f)==0x3c) emit_csel_cc(temp,fs,fs); // c_lt_d
    if((source[i]&0x3f)==0x3d) emit_csel_cc(temp,fs,fs); // c_nge_d
    if((source[i]&0x3f)==0x3e) emit_csel_ls(temp,fs,fs); // c_le_d
    if((source[i]&0x3f)==0x3f) emit_csel_ls(temp,fs,fs); // c_ngt_d
    return;
  }
#endif

  // C only

  u_int hr,reglist=0;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }
  reglist&=~(1<<fs);
  emit_storereg(FSREG, fs);
  save_regs(reglist);
  if(opcode2[i]==0x10) {
    emit_addimm64(FP,fp_fcr31,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>16)&0x1f],ARG3_REG);
    if((source[i]&0x3f)==0x30) emit_call((intptr_t)c_f_s);
    if((source[i]&0x3f)==0x31) emit_call((intptr_t)c_un_s);
    if((source[i]&0x3f)==0x32) emit_call((intptr_t)c_eq_s);
    if((source[i]&0x3f)==0x33) emit_call((intptr_t)c_ueq_s);
    if((source[i]&0x3f)==0x34) emit_call((intptr_t)c_olt_s);
    if((source[i]&0x3f)==0x35) emit_call((intptr_t)c_ult_s);
    if((source[i]&0x3f)==0x36) emit_call((intptr_t)c_ole_s);
    if((source[i]&0x3f)==0x37) emit_call((intptr_t)c_ule_s);
    if((source[i]&0x3f)==0x38) emit_call((intptr_t)c_sf_s);
    if((source[i]&0x3f)==0x39) emit_call((intptr_t)c_ngle_s);
    if((source[i]&0x3f)==0x3a) emit_call((intptr_t)c_seq_s);
    if((source[i]&0x3f)==0x3b) emit_call((intptr_t)c_ngl_s);
    if((source[i]&0x3f)==0x3c) emit_call((intptr_t)c_lt_s);
    if((source[i]&0x3f)==0x3d) emit_call((intptr_t)c_nge_s);
    if((source[i]&0x3f)==0x3e) emit_call((intptr_t)c_le_s);
    if((source[i]&0x3f)==0x3f) emit_call((intptr_t)c_ngt_s);
  }
  if(opcode2[i]==0x11) {
    emit_addimm64(FP,fp_fcr31,ARG1_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
    emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>16)&0x1f],ARG3_REG);
    if((source[i]&0x3f)==0x30) emit_call((intptr_t)c_f_d);
    if((source[i]&0x3f)==0x31) emit_call((intptr_t)c_un_d);
    if((source[i]&0x3f)==0x32) emit_call((intptr_t)c_eq_d);
    if((source[i]&0x3f)==0x33) emit_call((intptr_t)c_ueq_d);
    if((source[i]&0x3f)==0x34) emit_call((intptr_t)c_olt_d);
    if((source[i]&0x3f)==0x35) emit_call((intptr_t)c_ult_d);
    if((source[i]&0x3f)==0x36) emit_call((intptr_t)c_ole_d);
    if((source[i]&0x3f)==0x37) emit_call((intptr_t)c_ule_d);
    if((source[i]&0x3f)==0x38) emit_call((intptr_t)c_sf_d);
    if((source[i]&0x3f)==0x39) emit_call((intptr_t)c_ngle_d);
    if((source[i]&0x3f)==0x3a) emit_call((intptr_t)c_seq_d);
    if((source[i]&0x3f)==0x3b) emit_call((intptr_t)c_ngl_d);
    if((source[i]&0x3f)==0x3c) emit_call((intptr_t)c_lt_d);
    if((source[i]&0x3f)==0x3d) emit_call((intptr_t)c_nge_d);
    if((source[i]&0x3f)==0x3e) emit_call((intptr_t)c_le_d);
    if((source[i]&0x3f)==0x3f) emit_call((intptr_t)c_ngt_d);
  }
  restore_regs(reglist);
  emit_loadreg(FSREG,fs);
}

static void float_assemble(int i,struct regstat *i_regs)
{
  signed char temp=get_reg(i_regs->regmap,-1);
  assert(temp>=0);
  // Check cop1 unusable
  if(!cop1_usable) {
    signed char cs=get_reg(i_regs->regmap,CSREG);
    assert(cs>=0);
    emit_testimm(cs,CP0_STATUS_CU1);
    intptr_t jaddr=(intptr_t)out;
    emit_jeq(0);
    add_stub(FP_STUB,jaddr,(intptr_t)out,i,cs,(intptr_t)i_regs,is_delayslot,0);
    cop1_usable=1;
  }

#ifndef INTERPRET_FLOAT
  if((source[i]&0x3f)==6) // mov
  {
    if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
      if(opcode2[i]==0x10) {
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],HOST_TEMPREG);
        emit_flds(temp,31);
        emit_fsts(31,HOST_TEMPREG);
      }
      if(opcode2[i]==0x11) {
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],HOST_TEMPREG);
        emit_fldd(temp,31);
        emit_fstd(31,HOST_TEMPREG);
      }
    }
    return;
  }

  if((source[i]&0x3f)>3)
  {
    if(opcode2[i]==0x10) {
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
      emit_flds(temp,31);
      if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
      }
      if((source[i]&0x3f)==4) // sqrt
        emit_fsqrts(31,31);
      if((source[i]&0x3f)==5) // abs
        emit_fabss(31,31);
      if((source[i]&0x3f)==7) // neg
        emit_fnegs(31,31);
      emit_fsts(31,temp);
    }
    if(opcode2[i]==0x11) {
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
      emit_fldd(temp,31);
      if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
      }
      if((source[i]&0x3f)==4) // sqrt
        emit_fsqrtd(31,31);
      if((source[i]&0x3f)==5) // abs
        emit_fabsd(31,31);
      if((source[i]&0x3f)==7) // neg
        emit_fnegd(31,31);
      emit_fstd(31,temp);
    }
    return;
  }
  if((source[i]&0x3f)<4)
  {
    if(opcode2[i]==0x10) {
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],temp);
    }
    if(opcode2[i]==0x11) {
      emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],temp);
    }
    if(((source[i]>>11)&0x1f)!=((source[i]>>16)&0x1f)) {
      if(opcode2[i]==0x10) {
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>16)&0x1f],HOST_TEMPREG);
        emit_flds(temp,31);
        emit_flds(HOST_TEMPREG,30);
        if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
          if(((source[i]>>16)&0x1f)!=((source[i]>>6)&0x1f)) {
            emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
          }
        }
        if((source[i]&0x3f)==0) emit_fadds(31,30,31);
        if((source[i]&0x3f)==1) emit_fsubs(31,30,31);
        if((source[i]&0x3f)==2) emit_fmuls(31,30,31);
        if((source[i]&0x3f)==3) emit_fdivs(31,30,31);
        if(((source[i]>>16)&0x1f)==((source[i]>>6)&0x1f)) {
          emit_fsts(31,HOST_TEMPREG);
        }else{
          emit_fsts(31,temp);
        }
      }
      else if(opcode2[i]==0x11) {
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>16)&0x1f],HOST_TEMPREG);
        emit_fldd(temp,31);
        emit_fldd(HOST_TEMPREG,30);
        if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
          if(((source[i]>>16)&0x1f)!=((source[i]>>6)&0x1f)) {
            emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
          }
        }
        if((source[i]&0x3f)==0) emit_faddd(31,30,31);
        if((source[i]&0x3f)==1) emit_fsubd(31,30,31);
        if((source[i]&0x3f)==2) emit_fmuld(31,30,31);
        if((source[i]&0x3f)==3) emit_fdivd(31,30,31);
        if(((source[i]>>16)&0x1f)==((source[i]>>6)&0x1f)) {
          emit_fstd(31,HOST_TEMPREG);
        }else{
          emit_fstd(31,temp);
        }
      }
    }
    else {
      if(opcode2[i]==0x10) {
        emit_flds(temp,31);
        if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
          emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>6)&0x1f],temp);
        }
        if((source[i]&0x3f)==0) emit_fadds(31,31,31);
        if((source[i]&0x3f)==1) emit_fsubs(31,31,31);
        if((source[i]&0x3f)==2) emit_fmuls(31,31,31);
        if((source[i]&0x3f)==3) emit_fdivs(31,31,31);
        emit_fsts(31,temp);
      }
      else if(opcode2[i]==0x11) {
        emit_fldd(temp,31);
        if(((source[i]>>11)&0x1f)!=((source[i]>>6)&0x1f)) {
          emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>6)&0x1f],temp);
        }
        if((source[i]&0x3f)==0) emit_faddd(31,31,31);
        if((source[i]&0x3f)==1) emit_fsubd(31,31,31);
        if((source[i]&0x3f)==2) emit_fmuld(31,31,31);
        if((source[i]&0x3f)==3) emit_fdivd(31,31,31);
        emit_fstd(31,temp);
      }
    }
    return;
  }
#endif

  u_int hr,reglist=0;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
  }

  signed char fs=get_reg(i_regs->regmap,FSREG);
  if(opcode2[i]==0x10) { // Single precision
    save_regs(reglist);
    switch(source[i]&0x3f)
    {
      case 0x00: case 0x01: case 0x02: case 0x03:
        if(fs>=0) emit_mov(fs,ARG1_REG);
        else emit_loadreg(FSREG,ARG1_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG2_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>16)&0x1f],ARG3_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG4_REG);
        break;
     case 0x04:
        if(fs>=0) emit_mov(fs,ARG1_REG);
        else emit_loadreg(FSREG,ARG1_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG2_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG3_REG);
        break;
     case 0x05: case 0x06: case 0x07:
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>>11)&0x1f],ARG1_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_simple[(source[i]>> 6)&0x1f],ARG2_REG);
        break;
    }
    switch(source[i]&0x3f)
    {
      case 0x00: emit_call((intptr_t)add_s);break;
      case 0x01: emit_call((intptr_t)sub_s);break;
      case 0x02: emit_call((intptr_t)mul_s);break;
      case 0x03: emit_call((intptr_t)div_s);break;
      case 0x04: emit_call((intptr_t)sqrt_s);break;
      case 0x05: emit_call((intptr_t)abs_s);break;
      case 0x06: emit_call((intptr_t)mov_s);break;
      case 0x07: emit_call((intptr_t)neg_s);break;
    }
    restore_regs(reglist);
  }
  if(opcode2[i]==0x11) { // Double precision
    save_regs(reglist);
    switch(source[i]&0x3f)
    {
      case 0x00: case 0x01: case 0x02: case 0x03:
        if(fs>=0) emit_mov(fs,ARG1_REG);
        else emit_loadreg(FSREG,ARG1_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>16)&0x1f],ARG3_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG4_REG);
        break;
     case 0x04:
        if(fs>=0) emit_mov(fs,ARG1_REG);
        else emit_loadreg(FSREG,ARG1_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG2_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG3_REG);
        break;
     case 0x05: case 0x06: case 0x07:
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>>11)&0x1f],ARG1_REG);
        emit_readptr((intptr_t)&g_dev.r4300.new_dynarec_hot_state.cp1_regs_double[(source[i]>> 6)&0x1f],ARG2_REG);
        break;
    }
    switch(source[i]&0x3f)
    {
      case 0x00: emit_call((intptr_t)add_d);break;
      case 0x01: emit_call((intptr_t)sub_d);break;
      case 0x02: emit_call((intptr_t)mul_d);break;
      case 0x03: emit_call((intptr_t)div_d);break;
      case 0x04: emit_call((intptr_t)sqrt_d);break;
      case 0x05: emit_call((intptr_t)abs_d);break;
      case 0x06: emit_call((intptr_t)mov_d);break;
      case 0x07: emit_call((intptr_t)neg_d);break;
    }
    restore_regs(reglist);
  }
}

static void multdiv_assemble_arm64(int i,struct regstat *i_regs)
{
  //  case 0x18: MULT
  //  case 0x19: MULTU
  //  case 0x1A: DIV
  //  case 0x1B: DIVU
  //  case 0x1C: DMULT
  //  case 0x1D: DMULTU
  //  case 0x1E: DDIV
  //  case 0x1F: DDIVU
  if(rs1[i]&&rs2[i])
  {
    if((opcode2[i]&4)==0) // 32-bit
    {
#ifndef INTERPRET_MULT
      if((opcode2[i]==0x18) || (opcode2[i]==0x19))
      {
        signed char m1=get_reg(i_regs->regmap,rs1[i]);
        signed char m2=get_reg(i_regs->regmap,rs2[i]);
        signed char high=get_reg(i_regs->regmap,HIREG);
        signed char low=get_reg(i_regs->regmap,LOREG);
        assert(m1>=0);
        assert(m2>=0);
        assert(high>=0);
        assert(low>=0);

        if(opcode2[i]==0x18) //MULT
          emit_smull(m1,m2,high);
        else if(opcode2[i]==0x19) //MULTU
          emit_umull(m1,m2,high);

        emit_mov(high,low);
        emit_shrimm64(high,32,high);
      }
      else
#endif
#ifndef INTERPRET_DIV
      if((opcode2[i]==0x1A) || (opcode2[i]==0x1B))
      {
        signed char numerator=get_reg(i_regs->regmap,rs1[i]);
        signed char denominator=get_reg(i_regs->regmap,rs2[i]);
        assert(numerator>=0);
        assert(denominator>=0);
        signed char quotient=get_reg(i_regs->regmap,LOREG);
        signed char remainder=get_reg(i_regs->regmap,HIREG);
        assert(quotient>=0);
        assert(remainder>=0);
        emit_test(denominator,denominator);
        intptr_t jaddr=(intptr_t)out;
        emit_jeq(0); // Division by zero

        if(opcode2[i]==0x1A) //DIV
          emit_sdiv(numerator,denominator,quotient);
        else if(opcode2[i]==0x1B) //DIVU
          emit_udiv(numerator,denominator,quotient);

        emit_msub(quotient,denominator,numerator,remainder);
        set_jump_target(jaddr,(intptr_t)out);
      }
      else
#endif
      {
        u_int reglist=0;
        signed char r1=get_reg(i_regs->regmap,rs1[i]);
        signed char r2=get_reg(i_regs->regmap,rs2[i]);
        signed char hi=get_reg(i_regs->regmap,HIREG);
        signed char lo=get_reg(i_regs->regmap,LOREG);
        assert(r1>=0);
        assert(r2>=0);

        for(int hr=0;hr<HOST_REGS;hr++) {
          if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
        }

        //Don't save lo and hi regs are they will be overwritten anyway
        if(hi>=0) reglist&=~(1<<hi);
        if(lo>=0) reglist&=~(1<<lo);

        emit_writeword(r1,(intptr_t)&g_dev.r4300.new_dynarec_hot_state.rs);
        emit_writeword(r2,(intptr_t)&g_dev.r4300.new_dynarec_hot_state.rt);

        save_regs(reglist);

        if(opcode2[i]==0x18)
          emit_call((intptr_t)cached_interp_MULT);
        else if(opcode2[i]==0x19)
          emit_call((intptr_t)cached_interp_MULTU);
        else if(opcode2[i]==0x1A)
          emit_call((intptr_t)cached_interp_DIV);
        else if(opcode2[i]==0x1B)
          emit_call((intptr_t)cached_interp_DIVU);

        restore_regs(reglist);

        if(hi>=0) emit_loadreg(HIREG,hi);
        if(lo>=0) emit_loadreg(LOREG,lo);
      }
    }
    else // 64-bit
    {
#ifndef INTERPRET_MULT64
      if(opcode2[i]==0x1C||opcode2[i]==0x1D)
      {
        signed char m1h=get_reg(i_regs->regmap,rs1[i]|64);
        signed char m1l=get_reg(i_regs->regmap,rs1[i]);
        signed char m2h=get_reg(i_regs->regmap,rs2[i]|64);
        signed char m2l=get_reg(i_regs->regmap,rs2[i]);
        assert(m1h>=0);
        assert(m2h>=0);
        assert(m1l>=0);
        assert(m2l>=0);
        signed char hih=get_reg(i_regs->regmap,HIREG|64);
        signed char hil=get_reg(i_regs->regmap,HIREG);
        signed char loh=get_reg(i_regs->regmap,LOREG|64);
        signed char lol=get_reg(i_regs->regmap,LOREG);
        assert(hih>=0);
        assert(hil>=0);
        assert(loh>=0);
        assert(lol>=0);

        emit_mov(m1l,lol);
        emit_orrshlimm64(m1h,32,lol);
        emit_mov(m2l,loh);
        emit_orrshlimm64(m2h,32,loh);

        if(opcode2[i]==0x1C) // DMULT
        {
          emit_mul64(lol,loh,hil);
          emit_smulh(lol,loh,hih);
        }
        else if(opcode2[i]==0x1D) // DMULTU
        {
          emit_mul64(lol,loh,hil);
          emit_umulh(lol,loh,hih);
        }

        emit_mov(hil,lol);
        emit_shrimm64(hil,32,loh);
        emit_mov(hih,hil);
        emit_shrimm64(hih,32,hih);
      }
      else
#endif
#ifndef INTERPRET_DIV64
      if((opcode2[i]==0x1E)||(opcode2[i]==0x1F))
      {
        signed char numh=get_reg(i_regs->regmap,rs1[i]|64);
        signed char numl=get_reg(i_regs->regmap,rs1[i]);
        signed char denomh=get_reg(i_regs->regmap,rs2[i]|64);
        signed char denoml=get_reg(i_regs->regmap,rs2[i]);
        assert(numh>=0);
        assert(numl>=0);
        assert(denomh>=0);
        assert(denoml>=0);
        signed char remh=get_reg(i_regs->regmap,HIREG|64);
        signed char reml=get_reg(i_regs->regmap,HIREG);
        signed char quoh=get_reg(i_regs->regmap,LOREG|64);
        signed char quol=get_reg(i_regs->regmap,LOREG);
        assert(remh>=0);
        assert(reml>=0);
        assert(quoh>=0);
        assert(quol>=0);

        emit_mov(denoml,quoh);
        emit_orrshlimm64(denomh,32,quoh);
        emit_test64(quoh,quoh);
        intptr_t jaddr=(intptr_t)out;
        emit_jeq(0); // Division by zero
        emit_mov(numl,quol);
        emit_orrshlimm64(numh,32,quol);

        if(opcode2[i]==0x1E) // DDIV
        {
          emit_sdiv64(quol,quoh,reml);
          emit_msub64(reml,quoh,quol,remh);
        }
        else if(opcode2[i]==0x1F) // DDIVU
        {
          emit_udiv64(quol,quoh,reml);
          emit_msub64(reml,quoh,quol,remh);
        }

        emit_mov(reml,quol);
        emit_shrimm64(reml,32,quoh);
        emit_mov(remh,reml);
        emit_shrimm64(remh,32,remh);
        set_jump_target(jaddr,(intptr_t)out);
      }
      else
#endif
      {
        u_int reglist=0;
        signed char r1h=get_reg(i_regs->regmap,rs1[i]|64);
        signed char r1l=get_reg(i_regs->regmap,rs1[i]);
        signed char r2h=get_reg(i_regs->regmap,rs2[i]|64);
        signed char r2l=get_reg(i_regs->regmap,rs2[i]);
        signed char hih=get_reg(i_regs->regmap,HIREG|64);
        signed char hil=get_reg(i_regs->regmap,HIREG);
        signed char loh=get_reg(i_regs->regmap,LOREG|64);
        signed char lol=get_reg(i_regs->regmap,LOREG);
        assert(r1h>=0);
        assert(r2h>=0);
        assert(r1l>=0);
        assert(r2l>=0);

        for(int hr=0;hr<HOST_REGS;hr++) {
          if(i_regs->regmap[hr]>=0) reglist|=1<<hr;
        }

        //Don't save lo and hi regs are they will be overwritten anyway
        if(hih>=0) reglist&=~(1<<hih);
        if(hil>=0) reglist&=~(1<<hil);
        if(loh>=0) reglist&=~(1<<loh);
        if(lol>=0) reglist&=~(1<<lol);

        emit_writeword(r1l,(intptr_t)&g_dev.r4300.new_dynarec_hot_state.rs);
        emit_writeword(r1h,((intptr_t)&g_dev.r4300.new_dynarec_hot_state.rs)+4);
        emit_writeword(r2l,(intptr_t)&g_dev.r4300.new_dynarec_hot_state.rt);
        emit_writeword(r2h,((intptr_t)&g_dev.r4300.new_dynarec_hot_state.rt)+4);

        save_regs(reglist);

        if(opcode2[i]==0x1C) // DMULT
          emit_call((intptr_t)cached_interp_DMULT);
        else if(opcode2[i]==0x1D) // DMULTU
          emit_call((intptr_t)cached_interp_DMULTU);
        else if(opcode2[i]==0x1E) // DDIV
          emit_call((intptr_t)cached_interp_DDIV);
        else if(opcode2[i]==0x1F) // DDIVU
          emit_call((intptr_t)cached_interp_DDIVU);

        restore_regs(reglist);
        if(hih>=0) emit_loadreg(HIREG|64,hih);
        if(hil>=0) emit_loadreg(HIREG,hil);
        if(loh>=0) emit_loadreg(LOREG|64,loh);
        if(lol>=0) emit_loadreg(LOREG,lol);
      }
    }
  }
  else
  {
    // Multiply by zero is zero.
    // MIPS does not have a divide by zero exception.
    // The result is undefined, we return zero.
    signed char hr=get_reg(i_regs->regmap,HIREG);
    signed char lr=get_reg(i_regs->regmap,LOREG);
    if(hr>=0) emit_zeroreg(hr);
    if(lr>=0) emit_zeroreg(lr);
  }
}
#define multdiv_assemble multdiv_assemble_arm64

static void do_preload_rhash(int r) {
  // Don't need this for ARM64.  On x86, this puts the value 0xf8 into the
  // register. On ARM64 the hash can be done with a single instruction (below)
}

static void do_preload_rhtbl(int ht) {
  emit_addimm64(FP,fp_mini_ht,ht);
}

static void do_rhash(int rs,int rh) {
  emit_andimm(rs,0x1f0,rh);
}

static void do_miniht_load(int ht,int rh) {
  assem_debug("add %s,%s,%s",regname64[ht],regname64[ht],regname64[rh]);
  output_w32(0x8b000000|rh<<16|ht<<5|ht);
  assem_debug("ldr %s,[%s]",regname[rh],regname64[ht]);
  output_w32(0xb9400000|ht<<5|rh);
}

static void do_miniht_jump(int rs,int rh,int ht) {
  emit_cmp(rh,rs);
  intptr_t jaddr=(intptr_t)out;
  emit_jeq(0);
  if(rs==18) {
    // x18 is used for trampoline jumps, move it to another register (x0)
    emit_mov(rs,0);
    rs=0;
  }
  emit_jmp(jump_vaddr_reg[rs]);
  set_jump_target(jaddr,(intptr_t)out);
  assem_debug("ldr %s,[%s,#8]",regname64[ht],regname64[ht]);
  output_w32(0xf9400000|(8>>3)<<10|ht<<5|ht);
  emit_jmpreg(ht);
}

static void do_miniht_insert(u_int return_address,int rt,int temp) {
  emit_movz_lsl16((return_address>>16)&0xffff,rt);
  emit_movk(return_address&0xffff,rt);
  add_to_linker((intptr_t)out,return_address,1);
  emit_adr((intptr_t)out,temp);
  emit_writedword(temp,(intptr_t)&g_dev.r4300.new_dynarec_hot_state.mini_ht[(return_address&0x1FF)>>4][1]);
  emit_writeword(rt,(intptr_t)&g_dev.r4300.new_dynarec_hot_state.mini_ht[(return_address&0x1FF)>>4][0]);
}

// Clearing the cache is rather slow on ARM Linux, so mark the areas
// that need to be cleared, and then only clear these areas once.
static void do_clear_cache(void)
{
  int i,j;
  for (i=0;i<(1<<(TARGET_SIZE_2-17));i++)
  {
    u_int bitmap=needs_clear_cache[i];
    if(bitmap) {
      uintptr_t start,end;
      for(j=0;j<32;j++)
      {
        if(bitmap&(1<<j)) {
          start=(intptr_t)base_addr_rx+i*131072+j*4096;
          end=start+4095;
          j++;
          while(j<32) {
            if(bitmap&(1<<j)) {
              end+=4096;
              j++;
            }else{
              cache_flush((char *)start,(char *)end);
              break;
            }
          }
        }
      }
      needs_clear_cache[i]=0;
    }
  }
}

static void invalidate_addr(u_int addr)
{
  invalidate_block(addr>>12);
}

// CPU-architecture-specific initialization
static void arch_init(void) {

  assert((fp_memory_map&7)==0);
  g_dev.r4300.new_dynarec_hot_state.rounding_modes[0]=0x0<<22; // round
  g_dev.r4300.new_dynarec_hot_state.rounding_modes[1]=0x3<<22; // trunc
  g_dev.r4300.new_dynarec_hot_state.rounding_modes[2]=0x1<<22; // ceil
  g_dev.r4300.new_dynarec_hot_state.rounding_modes[3]=0x2<<22; // floor

  #ifdef RAM_OFFSET
  g_dev.r4300.new_dynarec_hot_state.ram_offset=((intptr_t)g_dev.rdram.dram-(intptr_t)0x80000000)>>2;
  #endif

  jump_table_symbols[0] = (intptr_t)cached_interp_TLBR;
  jump_table_symbols[1] = (intptr_t)cached_interp_TLBP;
  jump_table_symbols[2] = (intptr_t)cached_interp_MULT;
  jump_table_symbols[3] = (intptr_t)cached_interp_MULTU;
  jump_table_symbols[4] = (intptr_t)cached_interp_DIV;
  jump_table_symbols[5] = (intptr_t)cached_interp_DIVU;
  jump_table_symbols[6] = (intptr_t)cached_interp_DMULT;
  jump_table_symbols[7] = (intptr_t)cached_interp_DMULTU;
  jump_table_symbols[8] = (intptr_t)cached_interp_DDIV;
  jump_table_symbols[9] = (intptr_t)cached_interp_DDIVU;

  // Trampolines for jumps >128MB
  intptr_t *ptr,*ptr2,*ptr3;
  ptr=(intptr_t *)jump_table_symbols;
  ptr2=(intptr_t *)((char *)base_addr+(1<<TARGET_SIZE_2)-JUMP_TABLE_SIZE);
  ptr3=(intptr_t *)((char *)base_addr_rx+(1<<TARGET_SIZE_2)-JUMP_TABLE_SIZE);
  while((char *)ptr<(char *)jump_table_symbols+sizeof(jump_table_symbols))
  {
    int *ptr4=(int*)ptr2;
    intptr_t offset=*ptr-(intptr_t)ptr3;
    if(offset>=-134217728LL&&offset<134217728LL) {
      *ptr4=0x14000000|((offset>>2)&0x3ffffff); // direct branch
    }else{
      *ptr4=0x58000000|((8>>2)<<5)|18; // ldr x18,[pc,#8]
      *(ptr4+1)=0xd61f0000|(18<<5);
    }
    ptr2++;
    *ptr2=*ptr;
    ptr++;
    ptr2++;
    ptr3+=2;
  }
}
