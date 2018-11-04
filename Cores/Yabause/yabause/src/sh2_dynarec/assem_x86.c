/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Yabause - assem_x86.c                                                 *
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

u32 memory_map[1048576];
ALIGNED(8) u32 mini_ht_master[32][2];
ALIGNED(8) u32 mini_ht_slave[32][2];
ALIGNED(4) u8 restore_candidate[512];
int rccount;
int master_reg[22];
int master_cc; // Cycle count
int master_pc; // Virtual PC
void * master_ip; // Translated PC
int slave_reg[22];
int slave_cc; // Cycle count
int slave_pc; // Virtual PC
void * slave_ip; // Translated PC

void FASTCALL WriteInvalidateLong(u32 addr, u32 val);
void FASTCALL WriteInvalidateWord(u32 addr, u32 val);
void FASTCALL WriteInvalidateByte(u32 addr, u32 val);
void FASTCALL WriteInvalidateByteSwapped(u32 addr, u32 val);

u32 rmw_temp; // Temporary storage for TAS.B instruction

void jump_vaddr_eax_master();
void jump_vaddr_ecx_master();
void jump_vaddr_edx_master();
void jump_vaddr_ebx_master();
void jump_vaddr_ebp_master();
void jump_vaddr_edi_master();
void jump_vaddr_eax_slave();
void jump_vaddr_ecx_slave();
void jump_vaddr_edx_slave();
void jump_vaddr_ebx_slave();
void jump_vaddr_ebp_slave();
void jump_vaddr_edi_slave();

const pointer jump_vaddr_reg[2][8] = {
  {
    (pointer)jump_vaddr_eax_master,
    (pointer)jump_vaddr_ecx_master,
    (pointer)jump_vaddr_edx_master,
    (pointer)jump_vaddr_ebx_master,
    0,
    (pointer)jump_vaddr_ebp_master,
    0,
    (pointer)jump_vaddr_edi_master
  },{
    (pointer)jump_vaddr_eax_slave,
    (pointer)jump_vaddr_ecx_slave,
    (pointer)jump_vaddr_edx_slave,
    (pointer)jump_vaddr_ebx_slave,
    0,
    (pointer)jump_vaddr_ebp_slave,
    0,
    (pointer)jump_vaddr_edi_slave
  }
};

// We need these for cmovcc instructions on x86
u32 const_zero=0;
u32 const_one=1;

/* Linker */

void set_jump_target(pointer addr,pointer target)
{
  u8 *ptr=(u8 *)addr;
  if(*ptr==0x0f)
  {
    assert(ptr[1]>=0x80&&ptr[1]<=0x8f);
    u32 *ptr2=(u32 *)(ptr+2);
    *ptr2=target-(u32)ptr2-4;
  }
  else if(*ptr==0xe8||*ptr==0xe9) {
    u32 *ptr2=(u32 *)(ptr+1);
    *ptr2=target-(u32)ptr2-4;
  }
  else
  {
    assert(*ptr==0xc7); /* mov immediate (store address) */
    u32 *ptr2=(u32 *)(ptr+6);
    *ptr2=target;
  }
}

void *kill_pointer(void *stub)
{
  u32 *i_ptr=*((u32 **)(stub+6));
  *i_ptr=(u32)stub-(u32)i_ptr-4;
  return i_ptr;
}
pointer get_pointer(void *stub)
{
  s32 *i_ptr=*((u32 **)(stub+6));
  return *i_ptr+(pointer)i_ptr+4;
}

// Find the "clean" entry point from a "dirty" entry point
// by skipping past the call to verify_code
pointer get_clean_addr(pointer addr)
{
  u8 *ptr=(u8 *)addr;
  assert(ptr[20]==0xE8); // call instruction
  assert(ptr[25]==0x83); // pop (add esp,4) instruction
  if(ptr[28]==0xE9) return *(s32 *)(ptr+29)+addr+33; // follow jmp
  else return(addr+28);
}

int verify_dirty(pointer addr)
{
  u8 *ptr=(u8 *)addr;
  assert(ptr[5]==0xB8);
  u32 source=*(u32 *)(ptr+6);
  u32 copy=*(u32 *)(ptr+11);
  u32 len=*(u32 *)(ptr+16);
  assert(ptr[20]==0xE8); // call instruction
  return !memcmp((void *)source,(void *)copy,len);
}

// This doesn't necessarily find all clean entry points, just
// guarantees that it's not dirty
int isclean(pointer addr)
{
  u8 *ptr=(u8 *)addr;
  if(ptr[5]!=0xB8) return 1; // mov imm,%eax
  if(ptr[10]!=0xBB) return 1; // mov imm,%ebx
  if(ptr[15]!=0xB9) return 1; // mov imm,%ecx
  if(ptr[20]!=0xE8) return 1; // call instruction
  if(ptr[25]!=0x83) return 1; // pop (add esp,4) instruction
  return 0;
}

void get_bounds(pointer addr,u32 *start,u32 *end)
{
  u8 *ptr=(u8 *)addr;
  assert(ptr[5]==0xB8);
  u32 source=*(u32 *)(ptr+6);
  //u32 copy=*(u32 *)(ptr+11);
  u32 len=*(u32 *)(ptr+16);
  assert(ptr[20]==0xE8); // call instruction
  if(start) *start=source;
  if(end) *end=source+len;
}

/* Register allocation */

// Note: registers are allocated clean (unmodified state)
// if you intend to modify the register, you must call dirty_reg().
void alloc_reg(struct regstat *cur,int i,signed char reg)
{
  int r,hr;
  int preferred_reg = (reg&3)+(reg>21)*4+(reg==24)+(reg==28)+(reg==32);
  if(reg==CCREG) preferred_reg=HOST_CCREG;
  
  // Don't allocate unused registers
  if((cur->u>>reg)&1) return;
  
  // see if it's already allocated
  for(hr=0;hr<HOST_REGS;hr++)
  {
    if(cur->regmap[hr]==reg) return;
  }
  
  // Keep the same mapping if the register was already allocated in a loop
  preferred_reg = loop_reg(i,reg,preferred_reg);
  
  // Try to allocate the preferred register
  if(cur->regmap[preferred_reg]==-1) {
    cur->regmap[preferred_reg]=reg;
    cur->dirty&=~(1<<preferred_reg);
    cur->isdoingcp&=~(1<<preferred_reg);
    return;
  }
  r=cur->regmap[preferred_reg];
  if(r<64&&((cur->u>>r)&1)) {
    cur->regmap[preferred_reg]=reg;
    cur->dirty&=~(1<<preferred_reg);
    cur->isdoingcp&=~(1<<preferred_reg);
    return;
  }
  
  // Try to allocate EAX, EBX, ECX, or EDX
  // We prefer these because they can do byte and halfword loads
  for(hr=0;hr<4;hr++) {
    if(cur->regmap[hr]==-1) {
      cur->regmap[hr]=reg;
      cur->dirty&=~(1<<hr);
      cur->isdoingcp&=~(1<<hr);
      return;
    }
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
      if((cur->u>>r)&1)
        if(i==0||(unneeded_reg[i-1]>>r)&1) {cur->regmap[hr]=-1;break;}
    }
  }
  // Try to allocate any available register, but prefer
  // registers that have not been used recently.
  if(i>0) {
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
        if(regs[i-1].regmap[hr]!=rs1[i-1]&&regs[i-1].regmap[hr]!=rs2[i-1]&&regs[i-1].regmap[hr]!=rt1[i-1]&&regs[i-1].regmap[hr]!=rt2[i-1]) {
          cur->regmap[hr]=reg;
          cur->dirty&=~(1<<hr);
          cur->isdoingcp&=~(1<<hr);
          return;
        }
      }
    }
  }
  // Try to allocate any available register
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
      cur->regmap[hr]=reg;
      cur->dirty&=~(1<<hr);
      cur->isdoingcp&=~(1<<hr);
      return;
    }
  }
  
  // Ok, now we have to evict someone
  // Pick a register we hopefully won't need soon
  unsigned char hsn[MAXREG+1];
  memset(hsn,10,sizeof(hsn));
  int j;
  lsn(hsn,i,&preferred_reg);
  //printf("hsn(%x): %d %d %d %d %d %d %d\n",start+i*4,hsn[cur->regmap[0]&63],hsn[cur->regmap[1]&63],hsn[cur->regmap[2]&63],hsn[cur->regmap[3]&63],hsn[cur->regmap[5]&63],hsn[cur->regmap[6]&63],hsn[cur->regmap[7]&63]);
  if(i>0) {
    // Don't evict the cycle count at entry points, otherwise the entry
    // stub will have to write it.
    if(bt[i]&&hsn[CCREG]>2) hsn[CCREG]=2;
    if(i>1&&hsn[CCREG]>2&&(itype[i-2]==RJUMP||itype[i-2]==UJUMP||itype[i-2]==CJUMP||itype[i-2]==SJUMP)) hsn[CCREG]=2;
    for(j=10;j>=3;j--)
    {
      // Alloc preferred register if available
      if(hsn[r=cur->regmap[preferred_reg]&63]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          // Evict both parts of a 64-bit register
          if((cur->regmap[hr]&63)==r) {
            cur->regmap[hr]=-1;
            cur->dirty&=~(1<<hr);
            cur->isdoingcp&=~(1<<hr);
          }
        }
        cur->regmap[preferred_reg]=reg;
        return;
      }
      for(r=0;r<=MAXREG;r++)
      {
        if(hsn[r]==j&&r!=rs1[i-1]&&r!=rs2[i-1]&&r!=rt1[i-1]&&r!=rt2[i-1]) {
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r+64) {
                cur->regmap[hr]=reg;
                cur->dirty&=~(1<<hr);
                cur->isdoingcp&=~(1<<hr);
                return;
              }
            }
          }
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r) {
                cur->regmap[hr]=reg;
                cur->dirty&=~(1<<hr);
                cur->isdoingcp&=~(1<<hr);
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
    for(r=0;r<=MAXREG;r++)
    {
      if(hsn[r]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r+64) {
            cur->regmap[hr]=reg;
            cur->dirty&=~(1<<hr);
            cur->isdoingcp&=~(1<<hr);
            return;
          }
        }
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r) {
            cur->regmap[hr]=reg;
            cur->dirty&=~(1<<hr);
            cur->isdoingcp&=~(1<<hr);
            return;
          }
        }
      }
    }
  }
  printf("This shouldn't happen (alloc_reg)");exit(1);
}

// Allocate a temporary register.  This is done without regard to
// dirty status or whether the register we request is on the unneeded list
// Note: This will only allocate one register, even if called multiple times
void alloc_reg_temp(struct regstat *cur,int i,signed char reg)
{
  int r,hr;
  int preferred_reg = -1;
  
  // see if it's already allocated
  for(hr=0;hr<HOST_REGS;hr++)
  {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==reg) return;
  }
  
  // Try to allocate any available register, starting with EDI, ESI, EBP...
  // We prefer EDI, ESI, EBP since the others are used for byte/halfword stores
  for(hr=HOST_REGS-1;hr>=0;hr--) {
    if(hr!=EXCLUDE_REG&&cur->regmap[hr]==-1) {
      cur->regmap[hr]=reg;
      cur->dirty&=~(1<<hr);
      cur->isdoingcp&=~(1<<hr);
      return;
    }
  }
  
  // Find an unneeded register
  for(hr=HOST_REGS-1;hr>=0;hr--)
  {
    r=cur->regmap[hr];
    if(r>=0) {
      if((cur->u>>r)&1) {
        if(i==0||((unneeded_reg[i-1]>>r)&1)) {
          cur->regmap[hr]=reg;
          cur->dirty&=~(1<<hr);
          cur->isdoingcp&=~(1<<hr);
          return;
        }
      }
    }
  }
  
  // Ok, now we have to evict someone
  // Pick a register we hopefully won't need soon
  // TODO: we might want to follow unconditional jumps here
  // TODO: get rid of dupe code and make this into a function
  unsigned char hsn[MAXREG+1];
  memset(hsn,10,sizeof(hsn));
  int j;
  lsn(hsn,i,&preferred_reg);
  //printf("hsn: %d %d %d %d %d %d %d\n",hsn[cur->regmap[0]&63],hsn[cur->regmap[1]&63],hsn[cur->regmap[2]&63],hsn[cur->regmap[3]&63],hsn[cur->regmap[5]&63],hsn[cur->regmap[6]&63],hsn[cur->regmap[7]&63]);
  if(i>0) {
    // Don't evict the cycle count at entry points, otherwise the entry
    // stub will have to write it.
    if(bt[i]&&hsn[CCREG]>2) hsn[CCREG]=2;
    if(i>1&&hsn[CCREG]>2&&(itype[i-2]==RJUMP||itype[i-2]==UJUMP||itype[i-2]==CJUMP||itype[i-2]==SJUMP)) hsn[CCREG]=2;
    for(j=10;j>=3;j--)
    {
      for(r=0;r<=MAXREG;r++)
      {
        if(hsn[r]==j&&r!=rs1[i-1]&&r!=rs2[i-1]&&r!=rt1[i-1]&&r!=rt2[i-1]) {
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r+64) {
                cur->regmap[hr]=reg;
                cur->dirty&=~(1<<hr);
                cur->isdoingcp&=~(1<<hr);
                return;
              }
            }
          }
          for(hr=0;hr<HOST_REGS;hr++) {
            if(hr!=HOST_CCREG||j<hsn[CCREG]) {
              if(cur->regmap[hr]==r) {
                cur->regmap[hr]=reg;
                cur->dirty&=~(1<<hr);
                cur->isdoingcp&=~(1<<hr);
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
    for(r=0;r<=MAXREG;r++)
    {
      if(hsn[r]==j) {
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r+64) {
            cur->regmap[hr]=reg;
            cur->dirty&=~(1<<hr);
            cur->isdoingcp&=~(1<<hr);
            return;
          }
        }
        for(hr=0;hr<HOST_REGS;hr++) {
          if(cur->regmap[hr]==r) {
            cur->regmap[hr]=reg;
            cur->dirty&=~(1<<hr);
            cur->isdoingcp&=~(1<<hr);
            return;
          }
        }
      }
    }
  }
  printf("This shouldn't happen");exit(1);
}
// Allocate a specific x86 register.
void alloc_x86_reg(struct regstat *cur,int i,signed char reg,char hr)
{
  int n;
  u32 dirty=0;
  
  // see if it's already allocated (and dealloc it)
  for(n=0;n<HOST_REGS;n++)
  {
    if(n!=ESP&&cur->regmap[n]==reg) {
      dirty=(cur->dirty>>n)&1;
      cur->regmap[n]=-1;
    }
  }
  
  cur->regmap[hr]=reg;
  cur->dirty&=~(1<<hr);
  cur->dirty|=dirty<<hr;
  cur->isdoingcp&=~(1<<hr);
}

// Alloc cycle count into dedicated register
alloc_cc(struct regstat *cur,int i)
{
  alloc_x86_reg(cur,i,CCREG,ESI);
}

/* Assembler */

char regname[8][4] = {
 "eax",
 "ecx",
 "edx",
 "ebx",
 "esp",
 "ebp",
 "esi",
 "edi"};

void output_byte(u8 byte)
{
  *(out++)=byte;
}
void output_modrm(u8 mod,u8 rm,u8 ext)
{
  assert(mod<4);
  assert(rm<8);
  assert(ext<8);
  u8 byte=(mod<<6)|(ext<<3)|rm;
  *(out++)=byte;
}
void output_sib(u8 scale,u8 index,u8 base)
{
  assert(scale<4);
  assert(index<8);
  assert(base<8);
  u8 byte=(scale<<6)|(index<<3)|base;
  *(out++)=byte;
}
void output_w32(u32 word)
{
  *((u32 *)out)=word;
  out+=4;
}

void emit_mov(int rs,int rt)
{
  assem_debug("mov %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x89);
  output_modrm(3,rt,rs);
}

void emit_add(int rs1,int rs2,int rt)
{
  if(rs1==rt) {
    assem_debug("add %%%s,%%%s\n",regname[rs2],regname[rs1]);
    output_byte(0x01);
    output_modrm(3,rs1,rs2);
  }else if(rs2==rt) {
    assem_debug("add %%%s,%%%s\n",regname[rs1],regname[rs2]);
    output_byte(0x01);
    output_modrm(3,rs2,rs1);
  }else {
    assem_debug("lea (%%%s,%%%s),%%%s\n",regname[rs1],regname[rs2],regname[rt]);
    output_byte(0x8D);
    if(rs1!=EBP) {
      output_modrm(0,4,rt);
      output_sib(0,rs2,rs1);
    }else if(rs2!=EBP) {
      output_modrm(0,4,rt);
      output_sib(0,rs1,rs2);
    }else /* lea 0(,%ebp,2) */{
      output_modrm(0,4,rt);
      output_sib(1,EBP,5);
      output_w32(0);
    }
  }
}

void emit_adds(int rs1,int rs2,int rt)
{
  emit_add(rs1,rs2,rt);
}

void emit_lea8(int rs1,int rt)
{
  assem_debug("lea 0(%%%s,8),%%%s\n",regname[rs1],regname[rt]);
  output_byte(0x8D);
  output_modrm(0,4,rt);
  output_sib(3,rs1,5);
  output_w32(0);
}
void emit_leairrx1(int imm,int rs1,int rs2,int rt)
{
  assem_debug("lea %x(%%%s,%%%s,1),%%%s\n",imm,regname[rs1],regname[rs2],regname[rt]);
  output_byte(0x8D);
  if(imm!=0||rs1==EBP) {
    output_modrm(2,4,rt);
    output_sib(0,rs2,rs1);
    output_w32(imm);
  }else{
    output_modrm(0,4,rt);
    output_sib(0,rs2,rs1);
  }
}
void emit_leairrx4(int imm,int rs1,int rs2,int rt)
{
  assem_debug("lea %x(%%%s,%%%s,4),%%%s\n",imm,regname[rs1],regname[rs2],regname[rt]);
  output_byte(0x8D);
  if(imm!=0||rs1==EBP) {
    output_modrm(2,4,rt);
    output_sib(2,rs2,rs1);
    output_w32(imm);
  }else{
    output_modrm(0,4,rt);
    output_sib(2,rs2,rs1);
  }
}

void emit_neg(int rs, int rt)
{
  if(rs!=rt) emit_mov(rs,rt);
  assem_debug("neg %%%s\n",regname[rt]);
  output_byte(0xF7);
  output_modrm(3,rt,3);
}

void emit_negs(int rs, int rt)
{
  emit_neg(rs,rt);
}

void emit_sub(int rs1,int rs2,int rt)
{
  if(rs1==rt) {
    assem_debug("sub %%%s,%%%s\n",regname[rs2],regname[rs1]);
    output_byte(0x29);
    output_modrm(3,rs1,rs2);
  } else if(rs2==rt) {
    emit_neg(rs2,rs2);
    emit_add(rs2,rs1,rs2);
  } else {
    emit_mov(rs1,rt);
    emit_sub(rt,rs2,rt);
  }
}

void emit_subs(int rs1,int rs2,int rt)
{
  emit_sub(rs1,rs2,rt);
}

void emit_zeroreg(int rt)
{
  output_byte(0x31);
  output_modrm(3,rt,rt);
  assem_debug("xor %%%s,%%%s\n",regname[rt],regname[rt]);
}

void emit_loadreg(int r, int hr)
{
  int addr=(slave?(int)slave_reg:(int)master_reg)+(r<<2);
  if(r==CCREG) addr=slave?(int)&slave_cc:(int)&master_cc;
  assem_debug("mov %x+%d,%%%s\n",addr,r,regname[hr]);
  output_byte(0x8B);
  output_modrm(0,5,hr);
  output_w32(addr);
}
void emit_storereg(int r, int hr)
{
  int addr=(slave?(int)slave_reg:(int)master_reg)+(r<<2);
  if(r==CCREG) addr=slave?(int)&slave_cc:(int)&master_cc;
  assem_debug("mov %%%s,%x+%d\n",regname[hr],addr,r);
  output_byte(0x89);
  output_modrm(0,5,hr);
  output_w32(addr);
}

void emit_test(int rs, int rt)
{
  assem_debug("test %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x85);
  output_modrm(3,rs,rt);
}

void emit_testimm(int rs,int imm)
{
  assem_debug("test $0x%x,%%%s\n",imm,regname[rs]);
  if(imm<128&&imm>=-128&&rs<4) {
    output_byte(0xF6);
    output_modrm(3,rs,0);
    output_byte(imm);
  }
  else
  {
    output_byte(0xF7);
    output_modrm(3,rs,0);
    output_w32(imm);
  }
}

void emit_not(int rs,int rt)
{
  if(rs!=rt) emit_mov(rs,rt);
  assem_debug("not %%%s\n",regname[rt]);
  output_byte(0xF7);
  output_modrm(3,rt,2);
}

void emit_and(unsigned int rs1,unsigned int rs2,unsigned int rt)
{
  assert(rs1<8);
  assert(rs2<8);
  assert(rt<8);
  if(rs1==rt) {
    assem_debug("and %%%s,%%%s\n",regname[rs2],regname[rt]);
    output_byte(0x21);
    output_modrm(3,rs1,rs2);
  }
  else
  if(rs2==rt) {
    assem_debug("and %%%s,%%%s\n",regname[rs1],regname[rt]);
    output_byte(0x21);
    output_modrm(3,rs2,rs1);
  }
  else {
    emit_mov(rs1,rt);
    emit_and(rt,rs2,rt);
  }
}

void emit_or(unsigned int rs1,unsigned int rs2,unsigned int rt)
{
  assert(rs1<8);
  assert(rs2<8);
  assert(rt<8);
  if(rs1==rt) {
    assem_debug("or %%%s,%%%s\n",regname[rs2],regname[rt]);
    output_byte(0x09);
    output_modrm(3,rs1,rs2);
  }
  else
  if(rs2==rt) {
    assem_debug("or %%%s,%%%s\n",regname[rs1],regname[rt]);
    output_byte(0x09);
    output_modrm(3,rs2,rs1);
  }
  else {
    emit_mov(rs1,rt);
    emit_or(rt,rs2,rt);
  }
}
void emit_or_and_set_flags(int rs1,int rs2,int rt)
{
  emit_or(rs1,rs2,rt);
}

void emit_xor(unsigned int rs1,unsigned int rs2,unsigned int rt)
{
  assert(rs1<8);
  assert(rs2<8);
  assert(rt<8);
  if(rs1==rt) {
    assem_debug("xor %%%s,%%%s\n",regname[rs2],regname[rt]);
    output_byte(0x31);
    output_modrm(3,rs1,rs2);
  }
  else
  if(rs2==rt) {
    assem_debug("xor %%%s,%%%s\n",regname[rs1],regname[rt]);
    output_byte(0x31);
    output_modrm(3,rs2,rs1);
  }
  else {
    emit_mov(rs1,rt);
    emit_xor(rt,rs2,rt);
  }
}

void emit_movimm(int imm,unsigned int rt)
{
  assem_debug("mov $%d,%%%s\n",imm,regname[rt]);
  assert(rt<8);
  output_byte(0xB8+rt);
  output_w32(imm);
}

void emit_addimm(int rs,int imm,int rt)
{
  if(rs==rt) {
    if(imm!=0) {
      assem_debug("add $%d,%%%s\n",imm,regname[rt]);
      if(imm<128&&imm>=-128) {
        output_byte(0x83);
        output_modrm(3,rt,0);
        output_byte(imm);
      }
      else
      {
        output_byte(0x81);
        output_modrm(3,rt,0);
        output_w32(imm);
      }
    }
  }
  else {
    if(imm!=0) {
      assem_debug("lea %d(%%%s),%%%s\n",imm,regname[rs],regname[rt]);
      output_byte(0x8D);
      if(imm<128&&imm>=-128) {
        output_modrm(1,rs,rt);
        output_byte(imm);
      }else{
        output_modrm(2,rs,rt);
        output_w32(imm);
      }
    }else{
      emit_mov(rs,rt);
    }
  }
}

void emit_addimm_and_set_flags(int imm,int rt)
{
  assem_debug("add $%d,%%%s\n",imm,regname[rt]);
  if(imm<128&&imm>=-128) {
    output_byte(0x83);
    output_modrm(3,rt,0);
    output_byte(imm);
  }
  else
  {
    output_byte(0x81);
    output_modrm(3,rt,0);
    output_w32(imm);
  }
}
void emit_addimm_no_flags(int imm,int rt)
{
  if(imm!=0) {
    assem_debug("lea %d(%%%s),%%%s\n",imm,regname[rt],regname[rt]);
    output_byte(0x8D);
    if(imm<128&&imm>=-128) {
      output_modrm(1,rt,rt);
      output_byte(imm);
    }else{
      output_modrm(2,rt,rt);
      output_w32(imm);
    }
  }
}

void emit_adcimm(int imm,unsigned int rt)
{
  assem_debug("adc $%d,%%%s\n",imm,regname[rt]);
  assert(rt<8);
  if(imm<128&&imm>=-128) {
    output_byte(0x83);
    output_modrm(3,rt,2);
    output_byte(imm);
  }
  else
  {
    output_byte(0x81);
    output_modrm(3,rt,2);
    output_w32(imm);
  }
}
void emit_sbbimm(int imm,unsigned int rt)
{
  assem_debug("sbb $%d,%%%s\n",imm,regname[rt]);
  assert(rt<8);
  if(imm<128&&imm>=-128) {
    output_byte(0x83);
    output_modrm(3,rt,3);
    output_byte(imm);
  }
  else
  {
    output_byte(0x81);
    output_modrm(3,rt,3);
    output_w32(imm);
  }
}

void emit_addimm64_32(int rsh,int rsl,int imm,int rth,int rtl)
{
  if(rsh==rth&&rsl==rtl) {
    assem_debug("add $%d,%%%s\n",imm,regname[rtl]);
    if(imm<128&&imm>=-128) {
      output_byte(0x83);
      output_modrm(3,rtl,0);
      output_byte(imm);
    }
    else
    {
      output_byte(0x81);
      output_modrm(3,rtl,0);
      output_w32(imm);
    }
    assem_debug("adc $%d,%%%s\n",imm>>31,regname[rth]);
    output_byte(0x83);
    output_modrm(3,rth,2);
    output_byte(imm>>31);
  }
  else {
    emit_mov(rsh,rth);
    emit_mov(rsl,rtl);
    emit_addimm64_32(rth,rtl,imm,rth,rtl);
  }
}

void emit_sbb(int rs1,int rs2)
{
  assem_debug("sbb %%%s,%%%s\n",regname[rs1],regname[rs2]);
  output_byte(0x19);
  output_modrm(3,rs2,rs1);
}

void emit_andimm(int rs,int imm,int rt)
{
  if(imm==0) {
    emit_zeroreg(rt);
  }
  else if(rs==rt) {
    assem_debug("and $%d,%%%s\n",imm,regname[rt]);
    if(imm<128&&imm>=-128) {
      output_byte(0x83);
      output_modrm(3,rt,4);
      output_byte(imm);
    }
    else
    {
      output_byte(0x81);
      output_modrm(3,rt,4);
      output_w32(imm);
    }
  }
  else {
    emit_mov(rs,rt);
    emit_andimm(rt,imm,rt);
  }
}

void emit_orimm(int rs,int imm,int rt)
{
  if(rs==rt) {
    if(imm!=0) {
      assem_debug("or $%d,%%%s\n",imm,regname[rt]);
      if(imm<128&&imm>=-128) {
        output_byte(0x83);
        output_modrm(3,rt,1);
        output_byte(imm);
      }
      else
      {
        output_byte(0x81);
        output_modrm(3,rt,1);
        output_w32(imm);
      }
    }
  }
  else {
    emit_mov(rs,rt);
    emit_orimm(rt,imm,rt);
  }
}

void emit_xorimm(int rs,int imm,int rt)
{
  if(rs==rt) {
    if(imm!=0) {
      assem_debug("xor $%d,%%%s\n",imm,regname[rt]);
      if(imm<128&&imm>=-128) {
        output_byte(0x83);
        output_modrm(3,rt,6);
        output_byte(imm);
      }
      else
      {
        output_byte(0x81);
        output_modrm(3,rt,6);
        output_w32(imm);
      }
    }
  }
  else {
    emit_mov(rs,rt);
    emit_xorimm(rt,imm,rt);
  }
}

void emit_shlimm(int rs,unsigned int imm,int rt)
{
  if(rs==rt) {
    assem_debug("shl %%%s,%d\n",regname[rt],imm);
    assert(imm>0);
    if(imm==1) output_byte(0xD1);
    else output_byte(0xC1);
    output_modrm(3,rt,4);
    if(imm>1) output_byte(imm);
  }
  else {
    emit_mov(rs,rt);
    emit_shlimm(rt,imm,rt);
  }
}

void emit_shrimm(int rs,unsigned int imm,int rt)
{
  if(rs==rt) {
    assem_debug("shr %%%s,%d\n",regname[rt],imm);
    assert(imm>0);
    if(imm==1) output_byte(0xD1);
    else output_byte(0xC1);
    output_modrm(3,rt,5);
    if(imm>1) output_byte(imm);
  }
  else {
    emit_mov(rs,rt);
    emit_shrimm(rt,imm,rt);
  }
}

void emit_sarimm(int rs,unsigned int imm,int rt)
{
  if(rs==rt) {
    assem_debug("sar %%%s,%d\n",regname[rt],imm);
    assert(imm>0);
    if(imm==1) output_byte(0xD1);
    else output_byte(0xC1);
    output_modrm(3,rt,7);
    if(imm>1) output_byte(imm);
  }
  else {
    emit_mov(rs,rt);
    emit_sarimm(rt,imm,rt);
  }
}

void emit_rorimm(int rs,unsigned int imm,int rt)
{
  if(rs==rt) {
    assem_debug("ror %%%s,%d\n",regname[rt],imm);
    assert(imm>0);
    if(imm==1) output_byte(0xD1);
    else output_byte(0xC1);
    output_modrm(3,rt,1);
    if(imm>1) output_byte(imm);
  }
  else {
    emit_mov(rs,rt);
    emit_rorimm(rt,imm,rt);
  }
}

void emit_swapb(int rs,int rt)
{
  if(rs==rt) {
    assem_debug("ror %%%s,8\n",regname[rt]+1);
    output_byte(0x66);
    output_byte(0xC1);
    output_modrm(3,rt,1);
    output_byte(8);
  }
  else {
    emit_mov(rs,rt);
    emit_swapb(rt,rt);
  }
}

void emit_shldimm(int rs,int rs2,unsigned int imm,int rt)
{
  if(rs==rt) {
    assem_debug("shld %%%s,%%%s,%d\n",regname[rt],regname[rs2],imm);
    assert(imm>0);
    output_byte(0x0F);
    output_byte(0xA4);
    output_modrm(3,rt,rs2);
    output_byte(imm);
  }
  else {
    emit_mov(rs,rt);
    emit_shldimm(rt,rs2,imm,rt);
  }
}

void emit_shrdimm(int rs,int rs2,unsigned int imm,int rt)
{
  if(rs==rt) {
    assem_debug("shrd %%%s,%%%s,%d\n",regname[rt],regname[rs2],imm);
    assert(imm>0);
    output_byte(0x0F);
    output_byte(0xAC);
    output_modrm(3,rt,rs2);
    output_byte(imm);
  }
  else {
    emit_mov(rs,rt);
    emit_shrdimm(rt,rs2,imm,rt);
  }
}

void emit_shlcl(int r)
{
  assem_debug("shl %%%s,%%cl\n",regname[r]);
  output_byte(0xD3);
  output_modrm(3,r,4);
}
void emit_shrcl(int r)
{
  assem_debug("shr %%%s,%%cl\n",regname[r]);
  output_byte(0xD3);
  output_modrm(3,r,5);
}
void emit_sarcl(int r)
{
  assem_debug("sar %%%s,%%cl\n",regname[r]);
  output_byte(0xD3);
  output_modrm(3,r,7);
}

void emit_shldcl(int r1,int r2)
{
  assem_debug("shld %%%s,%%%s,%%cl\n",regname[r1],regname[r2]);
  output_byte(0x0F);
  output_byte(0xA5);
  output_modrm(3,r1,r2);
}
void emit_shrdcl(int r1,int r2)
{
  assem_debug("shrd %%%s,%%%s,%%cl\n",regname[r1],regname[r2]);
  output_byte(0x0F);
  output_byte(0xAD);
  output_modrm(3,r1,r2);
}

void emit_cmpimm(int rs,int imm)
{
  assem_debug("cmp $%d,%%%s\n",imm,regname[rs]);
  if(imm<128&&imm>=-128) {
    output_byte(0x83);
    output_modrm(3,rs,7);
    output_byte(imm);
  }
  else
  {
    output_byte(0x81);
    output_modrm(3,rs,7);
    output_w32(imm);
  }
}

void emit_cmovne(u32 *addr,int rt)
{
  assem_debug("cmovne %x,%%%s",(int)addr,regname[rt]);
  if(addr==&const_zero) assem_debug(" [zero]\n");
  else if(addr==&const_one) assem_debug(" [one]\n");
  else assem_debug("\n");
  output_byte(0x0F);
  output_byte(0x45);
  output_modrm(0,5,rt);
  output_w32((int)addr);
}
void emit_cmovl(u32 *addr,int rt)
{
  assem_debug("cmovl %x,%%%s",(int)addr,regname[rt]);
  if(addr==&const_zero) assem_debug(" [zero]\n");
  else if(addr==&const_one) assem_debug(" [one]\n");
  else assem_debug("\n");
  output_byte(0x0F);
  output_byte(0x4C);
  output_modrm(0,5,rt);
  output_w32((int)addr);
}
void emit_cmovs(u32 *addr,int rt)
{
  assem_debug("cmovs %x,%%%s",(int)addr,regname[rt]);
  if(addr==&const_zero) assem_debug(" [zero]\n");
  else if(addr==&const_one) assem_debug(" [one]\n");
  else assem_debug("\n");
  output_byte(0x0F);
  output_byte(0x48);
  output_modrm(0,5,rt);
  output_w32((int)addr);
}
void emit_cmovne_reg(int rs,int rt)
{
  assem_debug("cmovne %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x45);
  output_modrm(3,rs,rt);
}
void emit_cmovl_reg(int rs,int rt)
{
  assem_debug("cmovl %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x4C);
  output_modrm(3,rs,rt);
}
void emit_cmovle_reg(int rs,int rt)
{
  assem_debug("cmovle %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x4E);
  output_modrm(3,rs,rt);
}
void emit_cmovs_reg(int rs,int rt)
{
  assem_debug("cmovs %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x48);
  output_modrm(3,rs,rt);
}
void emit_cmovnc_reg(int rs,int rt)
{
  assem_debug("cmovae %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x43);
  output_modrm(3,rs,rt);
}
void emit_cmova_reg(int rs,int rt)
{
  assem_debug("cmova %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x47);
  output_modrm(3,rs,rt);
}
void emit_cmovp_reg(int rs,int rt)
{
  assem_debug("cmovp %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x4A);
  output_modrm(3,rs,rt);
}
void emit_cmovnp_reg(int rs,int rt)
{
  assem_debug("cmovnp %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0x4B);
  output_modrm(3,rs,rt);
}
void emit_setl(int rt)
{
  assem_debug("setl %%%s\n",regname[rt]);
  output_byte(0x0F);
  output_byte(0x9C);
  output_modrm(3,rt,2);
}
void emit_movzbl_reg(int rs, int rt)
{
  if(rs<4) {
    assem_debug("movzbl %%%s,%%%s\n",regname[rs]+1,regname[rt]);
    output_byte(0x0F);
    output_byte(0xB6);
    output_modrm(3,rs,rt);
  }
  else if(rt<4) {
    emit_mov(rs,rt);
    emit_movzbl_reg(rt,rt);
  }
  else {
    emit_andimm(rs,0xFF,rt);
  }
}
void emit_movzwl_reg(int rs, int rt)
{
  assem_debug("movzwl %%%s,%%%s\n",regname[rs]+1,regname[rt]);
  output_byte(0x0F);
  output_byte(0xB7);
  output_modrm(3,rs,rt);
}
void emit_movsbl_reg(int rs, int rt)
{
  if(rs<4) {
    assem_debug("movsbl %%%s,%%%s\n",regname[rs]+1,regname[rt]);
    output_byte(0x0F);
    output_byte(0xBE);
    output_modrm(3,rs,rt);
  }
  else if(rt<4) {
    emit_mov(rs,rt);
    emit_movsbl_reg(rt,rt);
  }
  else {
    emit_shlimm(rs,24,rt);
    emit_sarimm(rt,24,rt);
  }
}
void emit_movswl_reg(int rs, int rt)
{
  assem_debug("movswl %%%s,%%%s\n",regname[rs]+1,regname[rt]);
  output_byte(0x0F);
  output_byte(0xBF);
  output_modrm(3,rs,rt);
}

void emit_slti32(int rs,int imm,int rt)
{
  if(rs!=rt) emit_zeroreg(rt);
  emit_cmpimm(rs,imm);
  if(rt<4) {
    emit_setl(rt);
    if(rs==rt) emit_movzbl_reg(rt,rt);
  }
  else
  {
    if(rs==rt) emit_movimm(0,rt);
    emit_cmovl(&const_one,rt);
  }
}
void emit_sltiu32(int rs,int imm,int rt)
{
  if(rs!=rt) emit_zeroreg(rt);
  emit_cmpimm(rs,imm);
  if(rs==rt) emit_movimm(0,rt);
  emit_adcimm(0,rt);
}
void emit_slti64_32(int rsh,int rsl,int imm,int rt)
{
  assert(rsh!=rt);
  emit_slti32(rsl,imm,rt);
  if(imm>=0)
  {
    emit_test(rsh,rsh);
    emit_cmovne(&const_zero,rt);
    emit_cmovs(&const_one,rt);
  }
  else
  {
    emit_cmpimm(rsh,-1);
    emit_cmovne(&const_zero,rt);
    emit_cmovl(&const_one,rt);
  }
}
void emit_sltiu64_32(int rsh,int rsl,int imm,int rt)
{
  assert(rsh!=rt);
  emit_sltiu32(rsl,imm,rt);
  if(imm>=0)
  {
    emit_test(rsh,rsh);
    emit_cmovne(&const_zero,rt);
  }
  else
  {
    emit_cmpimm(rsh,-1);
    emit_cmovne(&const_one,rt);
  }
}

void emit_cmp(int rs,int rt)
{
  assem_debug("cmp %%%s,%%%s\n",regname[rt],regname[rs]);
  output_byte(0x39);
  output_modrm(3,rs,rt);
}
void emit_set_gz32(int rs, int rt)
{
  //assem_debug("set_gz32\n");
  emit_cmpimm(rs,1);
  emit_movimm(1,rt);
  emit_cmovl(&const_zero,rt);
}
void emit_set_nz32(int rs, int rt)
{
  //assem_debug("set_nz32\n");
  emit_cmpimm(rs,1);
  emit_movimm(1,rt);
  emit_sbbimm(0,rt);
}
void emit_set_gz64_32(int rsh, int rsl, int rt)
{
  //assem_debug("set_gz64\n");
  emit_set_gz32(rsl,rt);
  emit_test(rsh,rsh);
  emit_cmovne(&const_one,rt);
  emit_cmovs(&const_zero,rt);
}
void emit_set_nz64_32(int rsh, int rsl, int rt)
{
  //assem_debug("set_nz64\n");
  emit_or_and_set_flags(rsh,rsl,rt);
  emit_cmovne(&const_one,rt);
}
void emit_set_if_less32(int rs1, int rs2, int rt)
{
  //assem_debug("set if less (%%%s,%%%s),%%%s\n",regname[rs1],regname[rs2],regname[rt]);
  if(rs1!=rt&&rs2!=rt) emit_zeroreg(rt);
  emit_cmp(rs1,rs2);
  if(rs1==rt||rs2==rt) emit_movimm(0,rt);
  emit_cmovl(&const_one,rt);
}
void emit_set_if_carry32(int rs1, int rs2, int rt)
{
  //assem_debug("set if carry (%%%s,%%%s),%%%s\n",regname[rs1],regname[rs2],regname[rt]);
  if(rs1!=rt&&rs2!=rt) emit_zeroreg(rt);
  emit_cmp(rs1,rs2);
  if(rs1==rt||rs2==rt) emit_movimm(0,rt);
  emit_adcimm(0,rt);
}
void emit_set_if_less64_32(int u1, int l1, int u2, int l2, int rt)
{
  //assem_debug("set if less64 (%%%s,%%%s,%%%s,%%%s),%%%s\n",regname[u1],regname[l1],regname[u2],regname[l2],regname[rt]);
  assert(u1!=rt);
  assert(u2!=rt);
  emit_cmp(l1,l2);
  emit_mov(u1,rt);
  emit_sbb(u2,rt);
  emit_movimm(0,rt);
  emit_cmovl(&const_one,rt);
}
void emit_set_if_carry64_32(int u1, int l1, int u2, int l2, int rt)
{
  //assem_debug("set if carry64 (%%%s,%%%s,%%%s,%%%s),%%%s\n",regname[u1],regname[l1],regname[u2],regname[l2],regname[rt]);
  assert(u1!=rt);
  assert(u2!=rt);
  emit_cmp(l1,l2);
  emit_mov(u1,rt);
  emit_sbb(u2,rt);
  emit_movimm(0,rt);
  emit_adcimm(0,rt);
}
void emit_adc(int rs,int rt)
{
  assem_debug("adc %%%s,%%%s\n",regname[rs],regname[rt]);
  output_byte(0x11);
  output_modrm(3,rt,rs);
}
void emit_sh2tst(int s1, int s2, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_addimm(sr,-1,temp);
  emit_test(s1,s2);
  emit_cmovne_reg(temp,sr);
}
void emit_sh2tstimm(int s, int imm, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_testimm(s,imm);
  //emit_addimm(sr,-1,temp);
  assem_debug("lea -1(%%%s),%%%s\n",regname[sr],regname[temp]);
  output_byte(0x8D);
  output_modrm(1,sr,temp);
  output_byte(0xFF);
  emit_cmovne_reg(temp,sr);
}
void emit_cmpeq(int s1, int s2, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_addimm(sr,-1,temp);
  emit_cmp(s1,s2);
  emit_cmovne_reg(temp,sr);
}
void emit_cmpeqimm(int s, int imm, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_addimm(sr,-1,temp);
  emit_cmpimm(s,imm);
  emit_cmovne_reg(temp,sr);
}
void emit_cmpge(int s1, int s2, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_addimm(sr,-1,temp);
  emit_cmp(s2,s1);
  emit_cmovl_reg(temp,sr);
}
void emit_cmpgt(int s1, int s2, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_addimm(sr,-1,temp);
  emit_cmp(s2,s1);
  emit_cmovle_reg(temp,sr);
}
void emit_cmphi(int s1, int s2, int sr, int temp)
{
  emit_andimm(sr,~1,sr);
  emit_cmp(s1,s2);
  emit_adcimm(0,sr);
}
void emit_cmphs(int s1, int s2, int sr, int temp)
{
  emit_orimm(sr,1,sr);
  emit_cmp(s2,s1);
  emit_sbbimm(0,sr);
}
void emit_dt(int t, int sr)
{
  emit_addimm(t,-2,t);
  emit_shrimm(sr,1,sr);
  emit_addimm(t,1,t);
  emit_adc(sr,sr);
}
void emit_cmppz(int s, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_cmpimm(s,0x80000000);
  emit_adc(sr,sr);
}
void emit_cmppl(int s, int sr, int temp)
{
  assert(temp>=0);
  emit_orimm(sr,1,sr);
  emit_addimm(sr,-1,temp);
  emit_test(s,s);
  emit_cmovle_reg(temp,sr);
}
void emit_addc(int s, int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_adc(s,t);
  emit_adc(sr,sr);
}
void emit_subc(int s, int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_sbb(s,t);
  emit_adc(sr,sr);
}
void emit_shrsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_shrimm(t,1,t);
  emit_adc(sr,sr);
}
void emit_sarsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_sarimm(t,1,t);
  emit_adc(sr,sr);
}
void emit_shlsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_shlimm(t,1,t);
  emit_adc(sr,sr);
}
void emit_rotl(int t)
{
  assem_debug("rol %%%s\n",regname[t]);
  output_byte(0xD1);
  output_modrm(3,t,0);
}
void emit_rotlsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_rotl(t);
  emit_adc(sr,sr);
}
void emit_rotr(int t)
{
  assem_debug("ror %%%s\n",regname[t]);
  output_byte(0xD1);
  output_modrm(3,t,1);
}
void emit_rotrsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  emit_rotr(t);
  emit_adc(sr,sr);
}
void emit_rotclsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  assem_debug("rcl %%%s\n",regname[t]);
  output_byte(0xD1);
  output_modrm(3,t,2);
  emit_adc(sr,sr);
}
void emit_rotcrsr(int t, int sr)
{
  emit_shrimm(sr,1,sr);
  assem_debug("rcr %%%s\n",regname[t]);
  output_byte(0xD1);
  output_modrm(3,t,3);
  emit_adc(sr,sr);
}

void emit_call(int a)
{
  assem_debug("call %x (%x+%x)\n",a,(int)out+5,a-(int)out-5);
  output_byte(0xe8);
  output_w32(a-(int)out-4);
}
void emit_jmp(int a)
{
  assem_debug("jmp %x (%x+%x)\n",a,(int)out+5,a-(int)out-5);
  output_byte(0xe9);
  output_w32(a-(int)out-4);
}
void emit_jne(int a)
{
  assem_debug("jne %x\n",a);
  output_byte(0x0f);
  output_byte(0x85);
  output_w32(a-(int)out-4);
}
void emit_jeq(int a)
{
  assem_debug("jeq %x\n",a);
  output_byte(0x0f);
  output_byte(0x84);
  output_w32(a-(int)out-4);
}
void emit_js(int a)
{
  assem_debug("js %x\n",a);
  output_byte(0x0f);
  output_byte(0x88);
  output_w32(a-(int)out-4);
}
void emit_jns(int a)
{
  assem_debug("jns %x\n",a);
  output_byte(0x0f);
  output_byte(0x89);
  output_w32(a-(int)out-4);
}
void emit_jl(int a)
{
  assem_debug("jl %x\n",a);
  output_byte(0x0f);
  output_byte(0x8c);
  output_w32(a-(int)out-4);
}
void emit_jge(int a)
{
  assem_debug("jge %x\n",a);
  output_byte(0x0f);
  output_byte(0x8d);
  output_w32(a-(int)out-4);
}
void emit_jno(int a)
{
  assem_debug("jno %x\n",a);
  output_byte(0x0f);
  output_byte(0x81);
  output_w32(a-(int)out-4);
}
void emit_jc(int a)
{
  assem_debug("jc %x\n",a);
  output_byte(0x0f);
  output_byte(0x82);
  output_w32(a-(int)out-4);
}

void emit_pushimm(int imm)
{
  assem_debug("push $%x\n",imm);
  output_byte(0x68);
  output_w32(imm);
}
void emit_pushmem(int addr)
{
  assem_debug("push *%x\n",addr);
  output_byte(0xFF);
  output_modrm(0,5,6);
  output_w32(addr);
}
void emit_pusha()
{
  assem_debug("pusha\n");
  output_byte(0x60);
}
void emit_popa()
{
  assem_debug("popa\n");
  output_byte(0x61);
}
void emit_pushreg(unsigned int r)
{
  assem_debug("push %%%s\n",regname[r]);
  assert(r<8);
  output_byte(0x50+r);
}
void emit_popreg(unsigned int r)
{
  assem_debug("pop %%%s\n",regname[r]);
  assert(r<8);
  output_byte(0x58+r);
}
void emit_callreg(unsigned int r)
{
  assem_debug("call *%%%s\n",regname[r]);
  assert(r<8);
  output_byte(0xFF);
  output_modrm(3,r,2);
}
void emit_jmpreg(unsigned int r)
{
  assem_debug("jmp *%%%s\n",regname[r]);
  assert(r<8);
  output_byte(0xFF);
  output_modrm(3,r,4);
}
void emit_jmpmem_indexed(u32 addr,unsigned int r)
{
  assem_debug("jmp *%x(%%%s)\n",addr,regname[r]);
  assert(r<8);
  output_byte(0xFF);
  output_modrm(2,r,4);
  output_w32(addr);
}
void emit_cmpstr(int s1, int s2, int sr, int temp)
{
  // Compare s1 and s2.  If any byte is equal, set T.
  // Calculates the xor of the strings, then checks if any byte is
  // zero by subtracting 1 from each byte.  If there is a carry/borrow
  // then a byte was zero.
  assert(temp>=0);
  emit_pushreg(s2);
  emit_xor(s1,s2,s2);
  emit_shrimm(sr,1,sr);
  emit_mov(s2,temp);
  emit_addimm_and_set_flags(0-0x01010101,temp);
  emit_adcimm(-1,temp);
  emit_not(s2,s2);
  emit_xor(temp,s2,temp);
  emit_andimm(temp,0x01010101,temp);
  emit_addimm_and_set_flags(-1,temp);
  emit_adc(sr,sr);
  emit_popreg(s2);
}
void emit_negc(int rs, int rt, int sr)
{
  assert(rs>=0&&rs<8);
  if(rt<0) {
    emit_shrimm(sr,1,sr); // Get C flag
    emit_jc((pointer)out+10); // 6
    emit_neg(rs,rs); // 2
    emit_neg(rs,rs); // 2
    emit_adc(sr,sr); // Save C flag
  }else{
    if(rs!=rt) emit_mov(rs,rt);
    emit_shrimm(sr,1,sr); // Get C flag
    emit_jc((pointer)out+9); // 6
    emit_addimm(rt,-1,rt); // 3
    emit_adc(sr,sr); // Save C flag
    emit_not(rt,rt);
  }
}

void emit_readword(int addr, int rt)
{
  assem_debug("mov %x,%%%s\n",addr,regname[rt]);
  output_byte(0x8B);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_readword_indexed(int addr, int rs, int rt)
{
  assem_debug("mov %x+%%%s,%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x8B);
  if(addr<128&&addr>=-128) {
    output_modrm(1,rs,rt);
    if(rs==ESP) output_sib(0,4,4);
    output_byte(addr);
  }
  else
  {
    output_modrm(2,rs,rt);
    if(rs==ESP) output_sib(0,4,4);
    output_w32(addr);
  }
}
void emit_readword_map(int addr, int map, int rt)
{
  if(map<0) emit_readword(addr, rt);
  else
  {
    assem_debug("mov (%x,%%%s,4),%%%s\n",addr,regname[map],regname[rt]);
    output_byte(0x8B);
    output_modrm(0,4,rt);
    output_sib(2,map,5);
    output_w32(addr);
  }
}
void emit_readword_indexed_map(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_readword_indexed(addr, rs, rt);
  else {
    assem_debug("mov %x(%%%s,%%%s,4),%%%s\n",addr,regname[rs],regname[map],regname[rt]);
    assert(rs!=ESP);
    output_byte(0x8B);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(2,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(2,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(2,map,rs);
      output_w32(addr);
    }
  }
}
void emit_movmem_indexedx4(int addr, int rs, int rt)
{
  assem_debug("mov (%x,%%%s,4),%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x8B);
  output_modrm(0,4,rt);
  output_sib(2,rs,5);
  output_w32(addr);
}
void emit_movsbl(int addr, int rt)
{
  assem_debug("movsbl %x,%%%s\n",addr,regname[rt]);
  output_byte(0x0F);
  output_byte(0xBE);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_movsbl_indexed(int addr, int rs, int rt)
{
  assem_debug("movsbl %x+%%%s,%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0xBE);
  output_modrm(2,rs,rt);
  output_w32(addr);
}
void emit_movsbl_map(int addr, int map, int rt)
{
  if(map<0) emit_movsbl(addr, rt);
  else
  {
    assem_debug("movsbl (%x,%%%s,4),%%%s\n",addr,regname[map],regname[rt]);
    output_byte(0x0F);
    output_byte(0xBE);
    output_modrm(0,4,rt);
    output_sib(2,map,5);
    output_w32(addr);
  }
}
void emit_movsbl_indexed_map(int addr, int rs, int map, int rt)
{
  if(map<0) emit_movsbl_indexed(addr, rs, rt);
  else {
    assem_debug("movsbl %x(%%%s,%%%s,4),%%%s\n",addr,regname[rs],regname[map],regname[rt]);
    assert(rs!=ESP);
    output_byte(0x0F);
    output_byte(0xBE);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(2,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(2,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(2,map,rs);
      output_w32(addr);
    }
  }
}
void emit_movswl(int addr, int rt)
{
  assem_debug("movswl %x,%%%s\n",addr,regname[rt]);
  output_byte(0x0F);
  output_byte(0xBF);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_movswl_indexed(int addr, int rs, int rt)
{
  assem_debug("movswl %x+%%%s,%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0xBF);
  output_modrm(2,rs,rt);
  output_w32(addr);
}
void emit_movswl_map(int addr, int map, int rt)
{
  if(map<0) emit_movswl(addr, rt);
  else
  {
    assem_debug("movswl (%x,%%%s,4),%%%s\n",addr,regname[map],regname[rt]);
    output_byte(0x0F);
    output_byte(0xBF);
    output_modrm(0,4,rt);
    output_sib(2,map,5);
    output_w32(addr);
  }
}
void emit_movswl_indexed_map(int addr, int rs, int map, int rt)
{
  assert(map>=0);
  if(map<0) emit_movswl_indexed(addr, rs, rt);
  else {
    assem_debug("movswl %x(%%%s,%%%s,4),%%%s\n",addr,regname[rs],regname[map],regname[rt]);
    assert(rs!=ESP);
    output_byte(0x0F);
    output_byte(0xBF);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(2,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(2,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(2,map,rs);
      output_w32(addr);
    }
  }
}
void emit_movzbl(int addr, int rt)
{
  assem_debug("movzbl %x,%%%s\n",addr,regname[rt]);
  output_byte(0x0F);
  output_byte(0xB6);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_movzbl_indexed(int addr, int rs, int rt)
{
  assem_debug("movzbl %x+%%%s,%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0xB6);
  output_modrm(2,rs,rt);
  output_w32(addr);
}
void emit_movzbl_map(int addr, int map, int rt)
{
  if(map<0) emit_movzbl(addr, rt);
  else
  {
    assem_debug("movzbl (%x,%%%s,4),%%%s\n",addr,regname[map],regname[rt]);
    output_byte(0x0F);
    output_byte(0xB6);
    output_modrm(0,4,rt);
    output_sib(2,map,5);
    output_w32(addr);
  }
}
void emit_movzbl_indexed_map(int addr, int rs, int map, int rt)
{
  if(map<0) emit_movzbl_indexed(addr, rs, rt);
  else {
    assem_debug("movzbl %x(%%%s,%%%s,4),%%%s\n",addr,regname[rs],regname[map],regname[rt]);
    assert(rs!=ESP);
    output_byte(0x0F);
    output_byte(0xB6);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(2,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(2,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(2,map,rs);
      output_w32(addr);
    }
  }
}
void emit_movzwl(int addr, int rt)
{
  assem_debug("movzwl %x,%%%s\n",addr,regname[rt]);
  output_byte(0x0F);
  output_byte(0xB7);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_movzwl_indexed(int addr, int rs, int rt)
{
  assem_debug("movzwl %x+%%%s,%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x0F);
  output_byte(0xB7);
  output_modrm(2,rs,rt);
  output_w32(addr);
}
void emit_movzwl_map(int addr, int map, int rt)
{
  if(map<0) emit_movzwl(addr, rt);
  else
  {
    assem_debug("movzwl (%x,%%%s,4),%%%s\n",addr,regname[map],regname[rt]);
    output_byte(0x0F);
    output_byte(0xB7);
    output_modrm(0,4,rt);
    output_sib(2,map,5);
    output_w32(addr);
  }
}

void emit_xchg(int rs, int rt)
{
  assem_debug("xchg %%%s,%%%s\n",regname[rs],regname[rt]);
  if(rs==EAX) {
    output_byte(0x90+rt);
  }
  else
  {
    output_byte(0x87);
    output_modrm(3,rs,rt);
  }
}
void emit_writeword(int rt, int addr)
{
  assem_debug("movl %%%s,%x\n",regname[rt],addr);
  output_byte(0x89);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_writeword_indexed(int rt, int addr, int rs)
{
  assem_debug("mov %%%s,%x+%%%s\n",regname[rt],addr,regname[rs]);
  output_byte(0x89);
  if(addr<128&&addr>=-128) {
    output_modrm(1,rs,rt);
    if(rs==ESP) output_sib(0,4,4);
    output_byte(addr);
  }
  else
  {
    output_modrm(2,rs,rt);
    if(rs==ESP) output_sib(0,4,4);
    output_w32(addr);
  }
}
#if 0
void emit_writeword_map(int rt, int addr, int map)
{
  if(map<0) {
    emit_writeword(rt, addr+(int)rdram-0x80000000);
  } else {
    emit_writeword_indexed(rt, addr+(int)rdram-0x80000000, map);
  }
}
#endif
void emit_writeword_indexed_map(int rt, int addr, int rs, int map, int temp)
{
  if(map<0) emit_writeword_indexed(rt, addr, rs);
  else {
    assem_debug("mov %%%s,%x(%%%s,%%%s,1)\n",regname[rt],addr,regname[rs],regname[map]);
    assert(rs!=ESP);
    output_byte(0x89);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(0,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(0,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(0,map,rs);
      output_w32(addr);
    }
  }
}
void emit_writehword(int rt, int addr)
{
  assem_debug("movw %%%s,%x\n",regname[rt]+1,addr);
  output_byte(0x66);
  output_byte(0x89);
  output_modrm(0,5,rt);
  output_w32(addr);
}
void emit_writehword_indexed(int rt, int addr, int rs)
{
  assem_debug("movw %%%s,%x+%%%s\n",regname[rt]+1,addr,regname[rs]);
  output_byte(0x66);
  output_byte(0x89);
  if(addr<128&&addr>=-128) {
    output_modrm(1,rs,rt);
    output_byte(addr);
  }
  else
  {
    output_modrm(2,rs,rt);
    output_w32(addr);
  }
}
#if 0
void emit_writehword_map(int rt, int addr, int map)
{
  if(map<0) {
    emit_writehword(rt, addr+(int)rdram-0x80000000);
  } else {
    emit_writehword_indexed(rt, addr+(int)rdram-0x80000000, map);
  }
}
#endif
void emit_writehword_indexed_map(int rt, int addr, int rs, int map, int temp)
{
  if(map<0) emit_writeword_indexed(rt, addr, rs);
  else {
    assem_debug("movw %%%s,%x(%%%s,%%%s,1)\n",regname[rt]+1,addr,regname[rs],regname[map]);
    assert(rs!=ESP);
    output_byte(0x66);
    output_byte(0x89);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(0,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(0,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(0,map,rs);
      output_w32(addr);
    }
  }
}
void emit_writebyte(int rt, int addr)
{
  if(rt<4) {
    assem_debug("movb %%%cl,%x\n",regname[rt][1],addr);
    output_byte(0x88);
    output_modrm(0,5,rt);
    output_w32(addr);
  }
  else
  {
    emit_xchg(EAX,rt);
    emit_writebyte(EAX,addr);
    emit_xchg(EAX,rt);
  }
}
void emit_writebyte_indexed(int rt, int addr, int rs)
{
  if(rt<4) {
    assem_debug("movb %%%cl,%x+%%%s\n",regname[rt][1],addr,regname[rs]);
    output_byte(0x88);
    if(addr<128&&addr>=-128) {
      output_modrm(1,rs,rt);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,rs,rt);
      output_w32(addr);
    }
  }
  else
  {
    emit_xchg(EAX,rt);
    emit_writebyte_indexed(EAX,addr,rs==EAX?rt:rs);
    emit_xchg(EAX,rt);
  }
}
#if 0
void emit_writebyte_map(int rt, int addr, int map)
{
  if(map<0) {
    emit_writebyte(rt, addr+(int)rdram-0x80000000);
  } else {
    emit_writebyte_indexed(rt, addr+(int)rdram-0x80000000, map);
  }
}
#endif
void emit_writebyte_indexed_map(int rt, int addr, int rs, int map, int temp)
{
  if(map<0) emit_writebyte_indexed(rt, addr, rs);
  else
  if(rt<4) {
    assem_debug("movb %%%cl,%x(%%%s,%%%s,1)\n",regname[rt][1],addr,regname[rs],regname[map]);
    assert(rs!=ESP);
    output_byte(0x88);
    if(addr==0&&rs!=EBP) {
      output_modrm(0,4,rt);
      output_sib(0,map,rs);
    }
    else if(addr<128&&addr>=-128) {
      output_modrm(1,4,rt);
      output_sib(0,map,rs);
      output_byte(addr);
    }
    else
    {
      output_modrm(2,4,rt);
      output_sib(0,map,rs);
      output_w32(addr);
    }
  }
  else
  {
    emit_xchg(EAX,rt);
    emit_writebyte_indexed_map(EAX,addr,rs==EAX?rt:rs,map==EAX?rt:map,temp);
    emit_xchg(EAX,rt);
  }
}
void emit_writeword_imm(int imm, int addr)
{
  assem_debug("movl $%x,%x\n",imm,addr);
  output_byte(0xC7);
  output_modrm(0,5,0);
  output_w32(addr);
  output_w32(imm);
}
void emit_writeword_imm_esp(int imm, int addr)
{
  assem_debug("mov $%x,%x(%%esp)\n",imm,addr);
  assert(addr>=-128&&addr<128);
  output_byte(0xC7);
  output_modrm(1,4,0);
  output_sib(0,4,4);
  output_byte(addr);
  output_w32(imm);
}
void emit_writebyte_imm(int imm, int addr)
{
  assem_debug("movb $%x,%x\n",imm,addr);
  assert(imm>=-128&&imm<128);
  output_byte(0xC6);
  output_modrm(0,5,0);
  output_w32(addr);
  output_byte(imm);
}
void emit_writebyte_imm_esp(int imm, int addr)
{
  assem_debug("movb $%x,%x(%%esp)\n",imm,addr);
  assert(addr>=-128&&addr<128);
  output_byte(0xC6);
  output_modrm(1,4,0);
  output_sib(0,4,4);
  output_byte(addr);
  output_byte(imm);
}

void emit_rmw_andimm(int addr, int map, int imm)
{
  if(map<0) {
    assem_debug("andb $0x%x,(%%%s)\n",imm,regname[addr]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,addr,4);
  }
  else
  {
    assem_debug("andb $0x%x,(%%%s,%%%s,1)\n",imm,regname[addr],regname[map]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,4,4);
    if(addr!=EBP) {
      output_sib(0,map,addr);
    }
    else {
      assert(addr!=map);
      output_sib(0,addr,map);
    }
  }
  output_byte(imm);
}
void emit_rmw_xorimm(int addr, int map, int imm)
{
  if(map<0) {
    assem_debug("xorb $0x%x,(%%%s)\n",imm,regname[addr]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,addr,6);
  }
  else
  {
    assem_debug("xorb $0x%x,(%%%s,%%%s,1)\n",imm,regname[addr],regname[map]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,4,6);
    if(addr!=EBP) {
      output_sib(0,map,addr);
    }
    else {
      assert(addr!=map);
      output_sib(0,addr,map);
    }
  }
  output_byte(imm);
}
void emit_rmw_orimm(int addr, int map, int imm)
{
  if(map<0) {
    assem_debug("orb $0x%x,(%%%s)\n",imm,regname[addr]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,addr,1);
  }
  else
  {
    assem_debug("orb $0x%x,(%%%s,%%%s,1)\n",imm,regname[addr],regname[map]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,4,1);
    if(addr!=EBP) {
      output_sib(0,map,addr);
    }
    else {
      assert(addr!=map);
      output_sib(0,addr,map);
    }
  }
  output_byte(imm);
}
void emit_sh2tas(int addr, int map, int sr)
{
  emit_shrimm(sr,1,sr);
  if(map<0) {
    assem_debug("cmpb $1,(%%%s)\n",regname[addr]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,addr,7);
  }
  else
  {
    assem_debug("cmpb $1,(%%%s,%%%s,1)\n",regname[addr],regname[map]);
    assert(addr!=ESP);
    output_byte(0x80);
    output_modrm(0,4,7);
    if(addr!=EBP) {
      output_sib(0,map,addr);
    }
    else {
      assert(addr!=map);
      output_sib(0,addr,map);
    }
  }
  output_byte(1);
  emit_adc(sr,sr);
  emit_rmw_orimm(addr,map,0x80);
}

void emit_mul(int rs)
{
  assem_debug("mul %%%s\n",regname[rs]);
  output_byte(0xF7);
  output_modrm(3,rs,4);
}
void emit_imul(int rs)
{
  assem_debug("imul %%%s\n",regname[rs]);
  output_byte(0xF7);
  output_modrm(3,rs,5);
}
void emit_multiply(int rs1,int rs2,int rt)
{
  if(rs1==rt) {
    assem_debug("imul %%%s,%%%s\n",regname[rs2],regname[rt]);
    output_byte(0x0F);
    output_byte(0xAF);
    output_modrm(3,rs2,rt);
  }
  else
  {
    emit_mov(rs1,rt);
    emit_multiply(rt,rs2,rt);
  }
}
void emit_div(int rs)
{
  assem_debug("div %%%s\n",regname[rs]);
  output_byte(0xF7);
  output_modrm(3,rs,6);
}
void emit_idiv(int rs)
{
  assem_debug("idiv %%%s\n",regname[rs]);
  output_byte(0xF7);
  output_modrm(3,rs,7);
}
void emit_cdq()
{
  assem_debug("cdq\n");
  output_byte(0x99);
}
void emit_div0s(int s1, int s2, int sr, int temp) {
  emit_shlimm(sr,24,sr);
  emit_mov(s2,temp);
  assem_debug("bt %%%s,31\n",regname[s2]);
  output_byte(0x0f);
  output_byte(0xba);
  output_modrm(3,s2,4);
  output_byte(0x1f);
  assem_debug("rcr %%%s\n",regname[sr]);
  output_byte(0xD1);
  output_modrm(3,sr,3);
  emit_xor(temp,s1,temp);
  assem_debug("bt %%%s,31\n",regname[s1]);
  output_byte(0x0f);
  output_byte(0xba);
  output_modrm(3,s1,4);
  output_byte(0x1f);
  assem_debug("rcr %%%s,24\n",regname[sr]);
  output_byte(0xc1);
  output_modrm(3,sr,3);
  output_byte(24);
  assem_debug("bt %%%s,31\n",regname[temp]);
  output_byte(0x0f);
  output_byte(0xba);
  output_modrm(3,temp,4);
  output_byte(0x1f);
  emit_adc(sr,sr);
}

// Load return address
void emit_load_return_address(unsigned int rt)
{
  // (assumes this instruction will be followed by a 5-byte jmp instruction)
  emit_movimm((pointer)out+10,rt);
}

// Load 2 immediates optimizing for small code size
void emit_mov2imm_compact(int imm1,unsigned int rt1,int imm2,unsigned int rt2)
{
  emit_movimm(imm1,rt1);
  if(imm2-imm1<128&&imm2-imm1>=-128) emit_addimm(rt1,imm2-imm1,rt2);
  else emit_movimm(imm2,rt2);
}

// compare byte in memory
void emit_cmpmem_imm_byte(pointer addr,int imm)
{
  assert(imm<128&&imm>=-127);
  assem_debug("cmpb $%d,%x\n",imm,addr);
  output_byte(0x80);
  output_modrm(0,5,7);
  output_w32(addr);
  output_byte(imm);
}

// special case for checking invalid_code
void emit_cmpmem_indexedsr12_imm(int addr,int r,int imm)
{
  assert(imm<128&&imm>=-127);
  assert(r>=0&&r<8);
  emit_shrimm(r,12,r);
  assem_debug("cmp $%d,%x+%%%s\n",imm,addr,regname[r]);
  output_byte(0x80);
  output_modrm(2,r,7);
  output_w32(addr);
  output_byte(imm);
}

// special case for checking hash_table
void emit_cmpmem_indexed(int addr,int rs,int rt)
{
  assert(rs>=0&&rs<8);
  assert(rt>=0&&rt<8);
  assem_debug("cmp %x+%%%s,%%%s\n",addr,regname[rs],regname[rt]);
  output_byte(0x39);
  output_modrm(2,rs,rt);
  output_w32(addr);
}

// special case for checking memory_map in verify_mapping
void emit_cmpmem(int addr,int rt)
{
  assert(rt>=0&&rt<8);
  assem_debug("cmp %x,%%%s\n",addr,regname[rt]);
  output_byte(0x39);
  output_modrm(0,5,rt);
  output_w32(addr);
}

// Used to preload hash table entries
void emit_prefetch(void *addr)
{
  assem_debug("prefetch %x\n",(int)addr);
  output_byte(0x0F);
  output_byte(0x18);
  output_modrm(0,5,1);
  output_w32((int)addr);
}

/*void emit_submem(int r,int addr)
{
  assert(r>=0&&r<8);
  assem_debug("sub %x,%%%s\n",addr,regname[r]);
  output_byte(0x2B);
  output_modrm(0,5,r);
  output_w32((int)addr);
}*/
void emit_subfrommem(int addr,int r)
{
  assert(r>=0&&r<8);
  assem_debug("sub %%%s,%x\n",regname[r],addr);
  output_byte(0x29);
  output_modrm(0,5,r);
  output_w32((int)addr);
}

void emit_flds(int r)
{
  assem_debug("flds (%%%s)\n",regname[r]);
  output_byte(0xd9);
  if(r!=EBP) output_modrm(0,r,0);
  else {output_modrm(1,EBP,0);output_byte(0);}
}
void emit_fldl(int r)
{
  assem_debug("fldl (%%%s)\n",regname[r]);
  output_byte(0xdd);
  if(r!=EBP) output_modrm(0,r,0);
  else {output_modrm(1,EBP,0);output_byte(0);}
}
void emit_fucomip(unsigned int r)
{
  assem_debug("fucomip %d\n",r);
  assert(r<8);
  output_byte(0xdf);
  output_byte(0xe8+r);
}
void emit_fchs()
{
  assem_debug("fchs\n");
  output_byte(0xd9);
  output_byte(0xe0);
}
void emit_fabs()
{
  assem_debug("fabs\n");
  output_byte(0xd9);
  output_byte(0xe1);
}
void emit_fsqrt()
{
  assem_debug("fsqrt\n");
  output_byte(0xd9);
  output_byte(0xfa);
}
void emit_fadds(int r)
{
  assem_debug("fadds (%%%s)\n",regname[r]);
  output_byte(0xd8);
  if(r!=EBP) output_modrm(0,r,0);
  else {output_modrm(1,EBP,0);output_byte(0);}
}
void emit_faddl(int r)
{
  assem_debug("faddl (%%%s)\n",regname[r]);
  output_byte(0xdc);
  if(r!=EBP) output_modrm(0,r,0);
  else {output_modrm(1,EBP,0);output_byte(0);}
}
void emit_fadd(int r)
{
  assem_debug("fadd st%d\n",r);
  output_byte(0xd8);
  output_byte(0xc0+r);
}
void emit_fsubs(int r)
{
  assem_debug("fsubs (%%%s)\n",regname[r]);
  output_byte(0xd8);
  if(r!=EBP) output_modrm(0,r,4);
  else {output_modrm(1,EBP,4);output_byte(0);}
}
void emit_fsubl(int r)
{
  assem_debug("fsubl (%%%s)\n",regname[r]);
  output_byte(0xdc);
  if(r!=EBP) output_modrm(0,r,4);
  else {output_modrm(1,EBP,4);output_byte(0);}
}
void emit_fsub(int r)
{
  assem_debug("fsub st%d\n",r);
  output_byte(0xd8);
  output_byte(0xe0+r);
}
void emit_fmuls(int r)
{
  assem_debug("fmuls (%%%s)\n",regname[r]);
  output_byte(0xd8);
  if(r!=EBP) output_modrm(0,r,1);
  else {output_modrm(1,EBP,1);output_byte(0);}
}
void emit_fmull(int r)
{
  assem_debug("fmull (%%%s)\n",regname[r]);
  output_byte(0xdc);
  if(r!=EBP) output_modrm(0,r,1);
  else {output_modrm(1,EBP,1);output_byte(0);}
}
void emit_fmul(int r)
{
  assem_debug("fmul st%d\n",r);
  output_byte(0xd8);
  output_byte(0xc8+r);
}
void emit_fdivs(int r)
{
  assem_debug("fdivs (%%%s)\n",regname[r]);
  output_byte(0xd8);
  if(r!=EBP) output_modrm(0,r,6);
  else {output_modrm(1,EBP,6);output_byte(0);}
}
void emit_fdivl(int r)
{
  assem_debug("fdivl (%%%s)\n",regname[r]);
  output_byte(0xdc);
  if(r!=EBP) output_modrm(0,r,6);
  else {output_modrm(1,EBP,6);output_byte(0);}
}
void emit_fdiv(int r)
{
  assem_debug("fdiv st%d\n",r);
  output_byte(0xd8);
  output_byte(0xf0+r);
}
void emit_fpop()
{
  // fstp st(0)
  assem_debug("fpop\n");
  output_byte(0xdd);
  output_byte(0xd8);
}
void emit_fildl(int r)
{
  assem_debug("fildl (%%%s)\n",regname[r]);
  output_byte(0xdb);
  if(r!=EBP) output_modrm(0,r,0);
  else {output_modrm(1,EBP,0);output_byte(0);}
}
void emit_fildll(int r)
{
  assem_debug("fildll (%%%s)\n",regname[r]);
  output_byte(0xdf);
  if(r!=EBP) output_modrm(0,r,5);
  else {output_modrm(1,EBP,5);output_byte(0);}
}
void emit_fistpl(int r)
{
  assem_debug("fistpl (%%%s)\n",regname[r]);
  output_byte(0xdb);
  if(r!=EBP) output_modrm(0,r,3);
  else {output_modrm(1,EBP,3);output_byte(0);}
}
void emit_fistpll(int r)
{
  assem_debug("fistpll (%%%s)\n",regname[r]);
  output_byte(0xdf);
  if(r!=EBP) output_modrm(0,r,7);
  else {output_modrm(1,EBP,7);output_byte(0);}
}
void emit_fstps(int r)
{
  assem_debug("fstps (%%%s)\n",regname[r]);
  output_byte(0xd9);
  if(r!=EBP) output_modrm(0,r,3);
  else {output_modrm(1,EBP,3);output_byte(0);}
}
void emit_fstpl(int r)
{
  assem_debug("fstpl (%%%s)\n",regname[r]);
  output_byte(0xdd);
  if(r!=EBP) output_modrm(0,r,3);
  else {output_modrm(1,EBP,3);output_byte(0);}
}
void emit_fnstcw_stack()
{
  assem_debug("fnstcw (%%esp)\n");
  output_byte(0xd9);
  output_modrm(0,4,7);
  output_sib(0,4,4);
}
void emit_fldcw_stack()
{
  assem_debug("fldcw (%%esp)\n");
  output_byte(0xd9);
  output_modrm(0,4,5);
  output_sib(0,4,4);
}
void emit_fldcw_indexed(int addr,int r)
{
  assem_debug("fldcw %x(%%%s)\n",addr,regname[r]);
  output_byte(0xd9);
  output_modrm(0,4,5);
  output_sib(1,r,5);
  output_w32(addr);
}
void emit_fldcw(int addr)
{
  assem_debug("fldcw %x\n",addr);
  output_byte(0xd9);
  output_modrm(0,5,5);
  output_w32(addr);
}
void emit_movss_load(unsigned int addr,unsigned int ssereg)
{
  assem_debug("movss (%%%s),xmm%d\n",regname[addr],ssereg);
  assert(ssereg<8);
  output_byte(0xf3);
  output_byte(0x0f);
  output_byte(0x10);
  if(addr!=EBP) output_modrm(0,addr,ssereg);
  else {output_modrm(1,EBP,ssereg);output_byte(0);}
}
void emit_movsd_load(unsigned int addr,unsigned int ssereg)
{
  assem_debug("movsd (%%%s),xmm%d\n",regname[addr],ssereg);
  assert(ssereg<8);
  output_byte(0xf2);
  output_byte(0x0f);
  output_byte(0x10);
  if(addr!=EBP) output_modrm(0,addr,ssereg);
  else {output_modrm(1,EBP,ssereg);output_byte(0);}
}
void emit_movd_store(unsigned int ssereg,unsigned int addr)
{
  assem_debug("movd xmm%d,(%%%s)\n",ssereg,regname[addr]);
  assert(ssereg<8);
  output_byte(0x66);
  output_byte(0x0f);
  output_byte(0x7e);
  if(addr!=EBP) output_modrm(0,addr,ssereg);
  else {output_modrm(1,EBP,ssereg);output_byte(0);}
}
void emit_cvttps2dq(unsigned int ssereg1,unsigned int ssereg2)
{
  assem_debug("cvttps2dq xmm%d,xmm%d\n",ssereg1,ssereg2);
  assert(ssereg1<8);
  assert(ssereg2<8);
  output_byte(0xf3);
  output_byte(0x0f);
  output_byte(0x5b);
  output_modrm(3,ssereg1,ssereg2);
}
void emit_cvttpd2dq(unsigned int ssereg1,unsigned int ssereg2)
{
  assem_debug("cvttpd2dq xmm%d,xmm%d\n",ssereg1,ssereg2);
  assert(ssereg1<8);
  assert(ssereg2<8);
  output_byte(0x66);
  output_byte(0x0f);
  output_byte(0xe6);
  output_modrm(3,ssereg1,ssereg2);
}

unsigned int count_bits(u32 reglist)
{
  int count=0;
  while(reglist)
  {
    count+=reglist&1;
    reglist>>=1;
  }
  return count;
}

// Save registers before function call
// This code is executed infrequently so we try to minimize code size
// by pushing registers onto the stack instead of writing them to their
// usual locations
void save_regs(u32 reglist)
{
  reglist&=0x7; // only save the caller-save registers, %eax, %ecx, %edx
  int hr;
  int count=count_bits(reglist);
  if(count) {
    for(hr=0;hr<HOST_REGS;hr++) {
      if(hr!=EXCLUDE_REG) {
        if((reglist>>hr)&1) {
          emit_pushreg(hr);
        }
      }
    }
  }
  if(slave) emit_addimm(ESP,-(4-count)*4,ESP); // slave has master's return address on stack
  else emit_addimm(ESP,-(5-count)*4,ESP);
}
// Restore registers after function call
void restore_regs(u32 reglist)
{
  int hr;
  reglist&=0x7; // only save the caller-save registers, %eax, %ecx, %edx
  int count=count_bits(reglist);
  if(slave) emit_addimm(ESP,(4-count)*4,ESP);
  else emit_addimm(ESP,(5-count)*4,ESP);
  if(count) {
    for(hr=HOST_REGS-1;hr>=0;hr--) {
      if(hr!=EXCLUDE_REG) {
        if((reglist>>hr)&1) {
          emit_popreg(hr);
        }
      }
    }
  }
}

/* Stubs/epilogue */

emit_extjump(pointer addr, int target)
{
  u8 *ptr=(u8 *)addr;
  if(*ptr==0x0f)
  {
    assert(ptr[1]>=0x80&&ptr[1]<=0x8f);
    addr+=2;
  }
  else
  {
    assert(*ptr==0xe8||*ptr==0xe9);
    addr++;
  }
  emit_movimm(target,EAX);
  //emit_movimm(target|slave,EAX);
  emit_movimm(addr,EBX);
  //assert(addr>=0x7000000&&addr<0x7FFFFFF);
//DEBUG >
#ifdef DEBUG_CYCLE_COUNT
  emit_readword((int)&last_count,ECX);
  emit_add(HOST_CCREG,ECX,HOST_CCREG);
  emit_readword((int)&next_interupt,ECX);
  emit_writeword(HOST_CCREG,(int)&Count);
  emit_sub(HOST_CCREG,ECX,HOST_CCREG);
  emit_writeword(ECX,(int)&last_count);
#endif
//DEBUG <
  emit_jmp((pointer)dyna_linker);
}

do_readstub(int n)
{
  assem_debug("do_readstub %x\n",start+stubs[n][3]*2);
  set_jump_target(stubs[n][1],(int)out);
  int type=stubs[n][0];
  int i=stubs[n][3];
  int rs=stubs[n][4];
  struct regstat *i_regs=(struct regstat *)stubs[n][5];
  u32 reglist=stubs[n][7];
  signed char *i_regmap=i_regs->regmap;
  int addr=get_reg(i_regmap,AGEN1+(i&1));
  int rt;
  
  rt=get_reg(i_regmap,rt1[i]==TBIT?-1:rt1[i]);
  assert(rs>=0);
  if(addr<0) addr=rt;
  if(addr<0) addr=get_reg(i_regmap,-1);
  assert(addr>=0);
  save_regs(reglist);
  if(rs!=EAX) emit_mov(rs,EAX);
  if(type==LOADB_STUB) emit_xorimm(EAX,1,EAX);

  //if(i_regmap[HOST_CCREG]==CCREG) emit_storereg(CCREG,HOST_CCREG);//DEBUG
  /*if(i_regmap[HOST_CCREG]==CCREG) {
    emit_addimm(HOST_CCREG,CLOCK_DIVIDER*(stubs[n][6]),HOST_CCREG);
    output_byte(0x03);
    output_modrm(1,4,HOST_CCREG);
    output_sib(0,4,4);
    output_byte(12+16);
    //emit_writeword(HOST_CCREG,(int)&MSH2->cycles);
    emit_writeword(HOST_CCREG,slave?(int)&SSH2->cycles:(int)&MSH2->cycles);
    output_byte(0x2B);
    output_modrm(1,4,HOST_CCREG);
    output_sib(0,4,4);
    output_byte(12+16);
    emit_addimm(HOST_CCREG,-CLOCK_DIVIDER*(stubs[n][6]),HOST_CCREG);
  }
  if(i_regmap[HOST_CCREG]!=CCREG) {
    emit_loadreg(CCREG,ECX);
    emit_addimm(ECX,CLOCK_DIVIDER*(stubs[n][6]),ECX);
    output_byte(0x03);
    output_modrm(1,4,ECX);
    output_sib(0,4,4);
    output_byte(12+16);
    //emit_writeword(ECX,(int)&MSH2->cycles);
    emit_writeword(ECX,slave?(int)&SSH2->cycles:(int)&MSH2->cycles);
  }
  /*
  int temp;
  int cc=get_reg(i_regmap,CCREG);
  if(cc<0) {
    if(addr==HOST_CCREG)
    {
      cc=0;temp=1;
      assert(cc!=HOST_CCREG);
      assert(temp!=HOST_CCREG);
      emit_loadreg(CCREG,cc);
    }
    else
    {
      cc=HOST_CCREG;
      emit_loadreg(CCREG,cc);
      temp=!addr;
    }
  }
  else
  {
    temp=!addr;
  }*/
  if(type==LOADB_STUB)
    emit_call((int)MappedMemoryReadByte);
  if(type==LOADW_STUB)
    emit_call((int)MappedMemoryReadWord);
  if(type==LOADL_STUB)
    emit_call((int)MappedMemoryReadLong);
  if(type==LOADS_STUB)
  {
    // RTE instruction, pop PC and SR from stack
    int pc=get_reg(i_regmap,RTEMP);
    assert(pc>=0);
    if(rs==EAX||rs==ECX||rs==EDX)
      emit_writeword_indexed(rs,0,ESP);
    emit_call((int)MappedMemoryReadLong);
    if(rs==ECX||rs==EDX)
      emit_readword_indexed(0,ESP,rs);
    if(pc==EAX) {
      emit_writeword_indexed(EAX,0,ESP);
    }
    else
    {
      if(pc==ECX||pc==EDX)
        emit_writeword_indexed(EAX,0,ESP);
      else
        emit_mov(EAX,pc);
      if(rs==EAX) {
        emit_readword_indexed(0,ESP,EAX);
        emit_addimm(EAX,4,EAX);
      }else
        emit_addimm(rs,4,EAX);
    }
    emit_call((int)MappedMemoryReadLong);
    assert(rt>=0);
    if(rt!=EAX) emit_mov(EAX,rt);
    if(pc==EAX||pc==ECX||pc==EDX)
      emit_readword_indexed(0,ESP,pc);
  }
  else if(type==LOADB_STUB)
  {
    if(rt>=0) emit_movsbl_reg(EAX,rt);
  }
  else if(type==LOADW_STUB)
  {
    if(rt>=0) emit_movswl_reg(EAX,rt);
  }
  else
  {
    if(rt!=EAX&&rt>=0) emit_mov(EAX,rt);
  }
  restore_regs(reglist);
  if(type==LOADS_STUB) emit_addimm(rs,8,rs);
  emit_jmp(stubs[n][2]); // return address
}

inline_readstub(int type, int i, u32 addr, signed char regmap[], int target, int adj, u32 reglist)
{
  assem_debug("inline_readstub\n");
  //int rs=get_reg(regmap,target);
  int rt=get_reg(regmap,target);
  //if(rs<0) rs=get_reg(regmap,-1);
  if(rt<0) rt=get_reg(regmap,-1);
  //rt=get_reg(i_regmap,rt1[i]==TBIT?-1:rt1[i]);
  assert(rt>=0);
  //if(addr<0) addr=rt;
  //if(addr<0) addr=get_reg(i_regmap,-1);
  //assert(addr>=0);
  save_regs(reglist);
  emit_movimm(addr,EAX);
  if(type==LOADB_STUB)
    emit_call((int)MappedMemoryReadByte);
  if(type==LOADW_STUB)
    emit_call((int)MappedMemoryReadWord);
  if(type==LOADL_STUB)
    emit_call((int)MappedMemoryReadLong);
  assert(type!=LOADS_STUB);
  if(type==LOADB_STUB)
  {
    if(rt>=0) emit_movsbl_reg(EAX,rt);
  }
  else if(type==LOADW_STUB)
  {
    if(rt>=0) emit_movswl_reg(EAX,rt);
  }
  else
  {
    if(rt!=EAX&&rt>=0) emit_mov(EAX,rt);
  }
  restore_regs(reglist);
}

do_writestub(int n)
{
  assem_debug("do_writestub %x\n",start+stubs[n][3]*2);
  set_jump_target(stubs[n][1],(int)out);
  int type=stubs[n][0];
  int i=stubs[n][3];
  int rs=stubs[n][4];
  struct regstat *i_regs=(struct regstat *)stubs[n][5];
  u32 reglist=stubs[n][7];
  signed char *i_regmap=i_regs->regmap;
  int addr=get_reg(i_regmap,AGEN1+(i&1));
  int rt=get_reg(i_regmap,rs1[i]);
  assert(rs>=0);
  assert(rt>=0);
  if(addr<0) addr=get_reg(i_regmap,-1);
  assert(addr>=0);
  save_regs(reglist);
  // "FASTCALL" api: address in eax, data in edx
  if(rs!=EAX) {
    if(rt==EAX) {
      if(rs==EDX) emit_xchg(EAX,EDX);
      else {
        emit_mov(rt,EDX);
        emit_mov(rs,EAX);
      }
    }
    else {
      emit_mov(rs,EAX);
      if(rt!=EDX) emit_mov(rt,EDX);
    }
  }
  else if(rt!=EDX) emit_mov(rt,EDX);
  //if(type==STOREB_STUB) emit_xorimm(EAX,1,EAX); // WriteInvalidateByteSwapped does this
  
  //if(i_regmap[HOST_CCREG]==CCREG) emit_storereg(CCREG,HOST_CCREG);//DEBUG
  /*if(i_regmap[HOST_CCREG]==CCREG) {
    emit_addimm(HOST_CCREG,CLOCK_DIVIDER*(stubs[n][6]),HOST_CCREG);
    output_byte(0x03);
    output_modrm(1,4,HOST_CCREG);
    output_sib(0,4,4);
    output_byte(12+16);
    //emit_writeword(HOST_CCREG,(int)&MSH2->cycles);
    emit_writeword(HOST_CCREG,slave?(int)&SSH2->cycles:(int)&MSH2->cycles);
    output_byte(0x2B);
    output_modrm(1,4,HOST_CCREG);
    output_sib(0,4,4);
    output_byte(12+16);
    emit_addimm(HOST_CCREG,-CLOCK_DIVIDER*(stubs[n][6]),HOST_CCREG);
  }
  if(i_regmap[HOST_CCREG]!=CCREG) {
    emit_loadreg(CCREG,ECX);
    emit_addimm(ECX,CLOCK_DIVIDER*(stubs[n][6]),ECX);
    output_byte(0x03);
    output_modrm(1,4,ECX);
    output_sib(0,4,4);
    output_byte(12+16);
    //emit_writeword(ECX,(int)&MSH2->cycles);
    emit_writeword(ECX,slave?(int)&SSH2->cycles:(int)&MSH2->cycles);
  }
  //ds=i_regs!=&regs[i];
  //int real_rs=get_reg(i_regmap,rs2[i]);
  //if(!ds) load_all_consts(regs[i].regmap_entry,regs[i].was32,regs[i].wasdirty&~(1<<addr)&(real_rs<0?-1:~(1<<real_rs)),i);
  //wb_dirtys(i_regs->regmap_entry,i_regs->was32,i_regs->wasdirty&~(1<<addr)&(real_rs<0?-1:~(1<<real_rs)));
  
  /*int temp;
  int cc=get_reg(i_regmap,CCREG);
  if(cc<0) {
    if(addr==HOST_CCREG)
    {
      cc=0;temp=1;
      assert(cc!=HOST_CCREG);
      assert(temp!=HOST_CCREG);
      emit_loadreg(CCREG,cc);
    }
    else
    {
      cc=HOST_CCREG;
      emit_loadreg(CCREG,cc);
      temp=!addr;
    }
  }
  else
  {
    temp=!addr;
  }*/
  if(type==STOREB_STUB)
    emit_call((int)WriteInvalidateByteSwapped);
  if(type==STOREW_STUB)
    emit_call((int)WriteInvalidateWord);
  if(type==STOREL_STUB)
    emit_call((int)WriteInvalidateLong);
  
  restore_regs(reglist);
  emit_jmp(stubs[n][2]); // return address
}

inline_writestub(int type, int i, u32 addr, signed char regmap[], int target, int adj, u32 reglist)
{
  assem_debug("inline_writestub\n");
  //int rs=get_reg(regmap,-1);
  int rt=get_reg(regmap,target);
  //assert(rs>=0);
  assert(rt>=0);
  save_regs(reglist);
  // "FASTCALL" api: address in eax, data in edx
  if(rt!=EDX) emit_mov(rt,EDX);
  emit_movimm(addr,EAX); // FIXME - should be able to move the existing value
  if(type==STOREB_STUB)
    emit_call((int)WriteInvalidateByte);
  if(type==STOREW_STUB)
    emit_call((int)WriteInvalidateWord);
  if(type==STOREL_STUB)
    emit_call((int)WriteInvalidateLong);
  restore_regs(reglist);
}

do_rmwstub(int n)
{
  assem_debug("do_rmwstub %x\n",start+stubs[n][3]*2);
  set_jump_target(stubs[n][1],(int)out);
  int type=stubs[n][0];
  int i=stubs[n][3];
  int rs=stubs[n][4];
  struct regstat *i_regs=(struct regstat *)stubs[n][5];
  u32 reglist=stubs[n][7];
  signed char *i_regmap=i_regs->regmap;
  int addr=get_reg(i_regmap,AGEN1+(i&1));
  //int rt=get_reg(i_regmap,rs1[i]);
  assert(rs>=0);
  //assert(rt>=0);
  if(addr<0) addr=get_reg(i_regmap,-1);
  assert(addr>=0);
  save_regs(reglist);
  // "FASTCALL" api: address in eax, data in edx
  emit_xorimm(rs,1,rs);
  if(rs!=EAX) emit_mov(rs,EAX);
  if(rs==EAX||rs==ECX||rs==EDX)
    emit_writeword_indexed(rs,0,ESP);
  
  //if(i_regmap[HOST_CCREG]==CCREG) emit_storereg(CCREG,HOST_CCREG);//DEBUG
  /*if(i_regmap[HOST_CCREG]==CCREG) {
    emit_addimm(HOST_CCREG,CLOCK_DIVIDER*(stubs[n][6]),HOST_CCREG);
    output_byte(0x03);
    output_modrm(1,4,HOST_CCREG);
    output_sib(0,4,4);
    output_byte(12+16);
    emit_writeword(HOST_CCREG,(int)&MSH2->cycles);
    output_byte(0x2B);
    output_modrm(1,4,HOST_CCREG);
    output_sib(0,4,4);
    output_byte(12+16);
    emit_addimm(HOST_CCREG,-CLOCK_DIVIDER*(stubs[n][6]),HOST_CCREG);
  }
  if(i_regmap[HOST_CCREG]!=CCREG) {
    emit_loadreg(CCREG,ECX);
    emit_addimm(ECX,CLOCK_DIVIDER*(stubs[n][6]),ECX);
    output_byte(0x03);
    output_modrm(1,4,ECX);
    output_sib(0,4,4);
    output_byte(12+16);
    emit_writeword(ECX,(int)&MSH2->cycles);
  }*/
  emit_call((int)MappedMemoryReadByte);
  emit_mov(EAX,EDX);
  if(rs==EAX||rs==ECX||rs==EDX)
    emit_readword_indexed(0,ESP,EAX);
  else
    emit_mov(rs,EAX);
  if(type==RMWA_STUB)
    emit_andimm(EDX,imm[i],EDX);
  if(type==RMWX_STUB)
    emit_xorimm(EDX,imm[i],EDX);
  if(type==RMWO_STUB)
    emit_orimm(EDX,imm[i],EDX);
  if(type==RMWT_STUB) { // TAS.B
    //emit_writeword_indexed(EDX,0,ESP);
    emit_writeword(EDX,(pointer)&rmw_temp);
    emit_orimm(EDX,0x80,EDX);
  }
  //emit_call((int)MappedMemoryWriteByte);
  emit_call((int)WriteInvalidateByte);
  
  restore_regs(reglist);

  if(opcode2[i]==11) { // TAS.B
    signed char sr;
    sr=get_reg(i_regs->regmap,SR);
    assert(sr>=0); // Liveness analysis?
    emit_andimm(sr,~1,sr);
    //assem_debug("cmp $%d,%d+%%%s\n",1,-16,regname[ESP]);
    //output_byte(0x80);
    //output_modrm(1,4,7);
    //output_sib(0,4,4);
    //output_byte(-16);
    //output_byte(1);
    emit_cmpmem_imm_byte((pointer)&rmw_temp,1);
    emit_adcimm(0,sr);
  }
  emit_jmp(stubs[n][2]); // return address
}

do_unalignedwritestub(int n)
{
  set_jump_target(stubs[n][1],(int)out);
  output_byte(0xCC);
  emit_jmp(stubs[n][2]); // return address
}

void printregs(int edi,int esi,int ebp,int esp,int b,int d,int c,int a)
{
  printf("regs: %x %x %x %x %x %x %x (%x)\n",a,b,c,d,ebp,esi,edi,(&edi)[-1]);
}

int do_dirty_stub(int i)
{
  assem_debug("do_dirty_stub %x\n",start+i*2);
  u32 alignedlen=((((u32)source)+slen*2+2)&~2)-(u32)alignedsource;
  emit_pushimm(start+i*2+slave);
  emit_movimm(((u32)source)&~3,EAX); //alignedsource
  emit_movimm((u32)copy,EBX);
  emit_movimm((((u32)source+slen*2+2)&~3)-((u32)source&~3),ECX);
  emit_call((int)&verify_code);
  emit_addimm(ESP,4,ESP);
  int entry=(int)out;
  load_regs_entry(i);
  if(entry==(int)out) entry=instr_addr[i];
  emit_jmp(instr_addr[i]);
  return entry;
}

/* Memory Map */

int do_map_r(int s,int ar,int map,int cache,int x,int a,int shift,int c,u32 addr)
{
  if(c) {
    /*if(can_direct_read(addr)) {
      emit_readword((int)(memory_map+(addr>>12)),map);
    }
    else*/
      return -1; // No mapping
  }
  else {
    if(s!=map) emit_mov(s,map);
    emit_shrimm(map,12,map);
    // Schedule this while we wait on the load
    if(x) emit_xorimm(s,x,ar);
    //if(shift>=0) emit_lea8(s,shift);
    //if(~a) emit_andimm(s,a,ar);
    emit_movmem_indexedx4((int)memory_map,map,map);
  }
  return map;
}
int do_map_r_branch(int map, int c, u32 addr, int *jaddr)
{
  if(!c) {
    emit_test(map,map);
    *jaddr=(int)out;
    emit_js(0);
  }
  return map;
}

int gen_tlb_addr_r(int ar, int map) {
  if(map>=0) {
    emit_leairrx4(0,ar,map,ar);
  }
}

int do_map_w(int s,int ar,int map,int cache,int x,int c,u32 addr)
{
  if(c) {
    if(can_direct_write(addr)) {
      emit_readword((int)(memory_map+(addr>>12)),map);
    }
    else
      return -1; // No mapping
  }
  else {
    if(s!=map) emit_mov(s,map);
    //if(s!=ar) emit_mov(s,ar);
    emit_shrimm(map,12,map);
    // Schedule this while we wait on the load
    if(x) emit_xorimm(s,x,ar);
    emit_movmem_indexedx4((int)memory_map,map,map);
  }
  emit_shlimm(map,2,map);
  return map;
}
int do_map_w_branch(int map, int c, u32 addr, int *jaddr)
{
  if(!c||can_direct_write(addr)) {
    *jaddr=(int)out;
    emit_jc(0);
  }
}

int gen_tlb_addr_w(int ar, int map) {
  if(map>=0) {
    emit_leairrx1(0,ar,map,ar);
  }
}

// We don't need this for x86
generate_map_const(u32 addr,int reg) {
  // void *mapaddr=memory_map+(addr>>12);
}

/* Special assem */

void do_preload_rhash(int r) {
  emit_movimm(0xf8,r);
}

void do_preload_rhtbl(int r) {
  // Don't need this for x86
}

void do_rhash(int rs,int rh) {
  emit_and(rs,rh,rh);
}

void do_miniht_load(int ht,int rh) {
  // Don't need this for x86.  The load and compare can be combined into
  // a single instruction (below)
}

void do_miniht_jump(int rs,int rh,int ht) {
  emit_cmpmem_indexed(slave?(u32)mini_ht_slave:(u32)mini_ht_master,rh,rs);
  emit_jne(jump_vaddr_reg[slave][rs]);
  emit_jmpmem_indexed(slave?(u32)mini_ht_slave+4:(u32)mini_ht_master+4,rh);
}

void do_miniht_insert(int return_address,int rt,int temp) {
  emit_movimm(return_address,rt); // PC into link register
  //emit_writeword_imm(return_address,(int)&mini_ht[(return_address&0xFF)>>8][0]);
  if(slave) emit_writeword(rt,(int)&mini_ht_slave[(return_address&0xFF)>>3][0]);
  else emit_writeword(rt,(int)&mini_ht_master[(return_address&0xFF)>>3][0]);
  add_to_linker((int)out,return_address,1);
  if(slave) emit_writeword_imm(0,(int)&mini_ht_slave[(return_address&0xFF)>>3][1]);
  else emit_writeword_imm(0,(int)&mini_ht_master[(return_address&0xFF)>>3][1]);
}

void wb_valid(signed char pre[],signed char entry[],u32 dirty_pre,u32 dirty,u64 u)
{
  //if(dirty_pre==dirty) return;
  int hr,reg,new_hr;
  for(hr=0;hr<HOST_REGS;hr++) {
    if(hr!=EXCLUDE_REG) {
      reg=pre[hr];
      if(((~u)>>(reg&63))&1) {
        if(reg>=0) {
          if(((dirty_pre&~dirty)>>hr)&1) {
            if(reg>=0&&reg<TBIT) {
              emit_storereg(reg,hr);
            }
          }
        }
      }
    }
  }
}

// We don't need this for x86
void literal_pool(int n) {}
void literal_pool_jumpover(int n) {}

// CPU-architecture-specific initialization, not needed for x86
void arch_init() {}
