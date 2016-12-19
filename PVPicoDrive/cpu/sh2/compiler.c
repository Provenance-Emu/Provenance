/*
 * SH2 recompiler
 * (C) notaz, 2009,2010,2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * notes:
 * - tcache, block descriptor, link buffer overflows result in sh2_translate()
 *   failure, followed by full tcache invalidation for that region
 * - jumps between blocks are tracked for SMC handling (in block_entry->links),
 *   except jumps between different tcaches
 *
 * implemented:
 * - static register allocation
 * - remaining register caching and tracking in temporaries
 * - block-local branch linking
 * - block linking (except between tcaches)
 * - some constant propagation
 *
 * TODO:
 * - better constant propagation
 * - stack caching?
 * - bug fixing
 */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "../../pico/pico_int.h"
#include "sh2.h"
#include "compiler.h"
#include "../drc/cmn.h"
#include "../debug.h"

// features
#define PROPAGATE_CONSTANTS     1
#define LINK_BRANCHES           1

// limits (per block)
#define MAX_BLOCK_SIZE          (BLOCK_INSN_LIMIT * 6 * 6)

// max literal offset from the block end
#define MAX_LITERAL_OFFSET      32*2
#define MAX_LITERALS            (BLOCK_INSN_LIMIT / 4)
#define MAX_LOCAL_BRANCHES      32

// debug stuff
// 1 - warnings/errors
// 2 - block info/smc
// 4 - asm
// 8 - runtime block entry log
// {
#ifndef DRC_DEBUG
#define DRC_DEBUG 0
#endif

#if DRC_DEBUG
#define dbg(l,...) { \
  if ((l) & DRC_DEBUG) \
    elprintf(EL_STATUS, ##__VA_ARGS__); \
}
#include "mame/sh2dasm.h"
#include <platform/libpicofe/linux/host_dasm.h>
static int insns_compiled, hash_collisions, host_insn_count;
#define COUNT_OP \
	host_insn_count++
#else // !DRC_DEBUG
#define COUNT_OP
#define dbg(...)
#endif

///
#define FETCH_OP(pc) \
  dr_pc_base[(pc) / 2]

#define FETCH32(a) \
  ((dr_pc_base[(a) / 2] << 16) | dr_pc_base[(a) / 2 + 1])

#define CHECK_UNHANDLED_BITS(mask, label) { \
  if ((op & (mask)) != 0) \
    goto label; \
}

#define GET_Fx() \
  ((op >> 4) & 0x0f)

#define GET_Rm GET_Fx

#define GET_Rn() \
  ((op >> 8) & 0x0f)

#define BITMASK1(v0) (1 << (v0))
#define BITMASK2(v0,v1) ((1 << (v0)) | (1 << (v1)))
#define BITMASK3(v0,v1,v2) (BITMASK2(v0,v1) | (1 << (v2)))
#define BITMASK4(v0,v1,v2,v3) (BITMASK3(v0,v1,v2) | (1 << (v3)))
#define BITMASK5(v0,v1,v2,v3,v4) (BITMASK4(v0,v1,v2,v3) | (1 << (v4)))

#define SHR_T SHR_SR // might make them separate someday

static struct op_data {
  u8 op;
  u8 cycles;
  u8 size;     // 0, 1, 2 - byte, word, long
  s8 rm;       // branch or load/store data reg
  u32 source;  // bitmask of src regs
  u32 dest;    // bitmask of dest regs
  u32 imm;     // immediate/io address/branch target
               // (for literal - address, not value)
} ops[BLOCK_INSN_LIMIT];

enum op_types {
  OP_UNHANDLED = 0,
  OP_BRANCH,
  OP_BRANCH_CT, // conditional, branch if T set
  OP_BRANCH_CF, // conditional, branch if T clear
  OP_BRANCH_R,  // indirect
  OP_BRANCH_RF, // indirect far (PC + Rm)
  OP_SETCLRT,   // T flag set/clear
  OP_MOVE,      // register move
  OP_LOAD_POOL, // literal pool load, imm is address
  OP_MOVA,
  OP_SLEEP,
  OP_RTE,
};

#ifdef DRC_SH2

static int literal_disabled_frames;

#if (DRC_DEBUG & 4)
static u8 *tcache_dsm_ptrs[3];
static char sh2dasm_buff[64];
#define do_host_disasm(tcid) \
  host_dasm(tcache_dsm_ptrs[tcid], tcache_ptr - tcache_dsm_ptrs[tcid]); \
  tcache_dsm_ptrs[tcid] = tcache_ptr
#else
#define do_host_disasm(x)
#endif

#if (DRC_DEBUG & 8) || defined(PDB)
static void REGPARM(3) *sh2_drc_log_entry(void *block, SH2 *sh2, u32 sr)
{
  if (block != NULL) {
    dbg(8, "= %csh2 enter %08x %p, c=%d", sh2->is_slave ? 's' : 'm',
      sh2->pc, block, (signed int)sr >> 12);
    pdb_step(sh2, sh2->pc);
  }
  return block;
}
#endif
// } debug

#define TCACHE_BUFFERS 3

// we have 3 translation cache buffers, split from one drc/cmn buffer.
// BIOS shares tcache with data array because it's only used for init
// and can be discarded early
// XXX: need to tune sizes
static const int tcache_sizes[TCACHE_BUFFERS] = {
  DRC_TCACHE_SIZE * 6 / 8, // ROM (rarely used), DRAM
  DRC_TCACHE_SIZE / 8, // BIOS, data array in master sh2
  DRC_TCACHE_SIZE / 8, // ... slave
};

static u8 *tcache_bases[TCACHE_BUFFERS];
static u8 *tcache_ptrs[TCACHE_BUFFERS];

// ptr for code emiters
static u8 *tcache_ptr;

#define MAX_BLOCK_ENTRIES (BLOCK_INSN_LIMIT / 8)

struct block_link {
  u32 target_pc;
  void *jump;                // insn address
  struct block_link *next;   // either in block_entry->links or 
};

struct block_entry {
  u32 pc;
  void *tcache_ptr;          // translated block for above PC
  struct block_entry *next;  // next block in hash_table with same pc hash
  struct block_link *links;  // links to this entry
#if (DRC_DEBUG & 2)
  struct block_desc *block;
#endif
};

struct block_desc {
  u32 addr;                  // block start SH2 PC address
  u16 size;                  // ..of recompiled insns+lit. pool
  u16 size_nolit;            // same without literals
#if (DRC_DEBUG & 2)
  int refcount;
#endif
  int entry_count;
  struct block_entry entryp[MAX_BLOCK_ENTRIES];
};

static const int block_max_counts[TCACHE_BUFFERS] = {
  4*1024,
  256,
  256,
};
static struct block_desc *block_tables[TCACHE_BUFFERS];
static int block_counts[TCACHE_BUFFERS];

// we have block_link_pool to avoid using mallocs
static const int block_link_pool_max_counts[TCACHE_BUFFERS] = {
  4*1024,
  256,
  256,
};
static struct block_link *block_link_pool[TCACHE_BUFFERS]; 
static int block_link_pool_counts[TCACHE_BUFFERS];
static struct block_link *unresolved_links[TCACHE_BUFFERS];

// used for invalidation
static const int ram_sizes[TCACHE_BUFFERS] = {
  0x40000,
  0x1000,
  0x1000,
};
#define INVAL_PAGE_SIZE 0x100

struct block_list {
  struct block_desc *block;
  struct block_list *next;
};

// array of pointers to block_lists for RAM and 2 data arrays
// each array has len: sizeof(mem) / INVAL_PAGE_SIZE 
static struct block_list **inval_lookup[TCACHE_BUFFERS];

static const int hash_table_sizes[TCACHE_BUFFERS] = {
  0x1000,
  0x100,
  0x100,
};
static struct block_entry **hash_tables[TCACHE_BUFFERS];

#define HASH_FUNC(hash_tab, addr, mask) \
  (hash_tab)[(((addr) >> 20) ^ ((addr) >> 2)) & (mask)]

// host register tracking
enum {
  HR_FREE,
  HR_CACHED, // 'val' has sh2_reg_e
//  HR_CONST,  // 'val' has a constant
  HR_TEMP,   // reg used for temp storage
};

enum {
  HRF_DIRTY  = 1 << 0, // reg has "dirty" value to be written to ctx
  HRF_LOCKED = 1 << 1, // HR_CACHED can't be evicted
};

typedef struct {
  u32 hreg:5;   // "host" reg
  u32 greg:5;   // "guest" reg
  u32 type:3;
  u32 flags:3;
  u32 stamp:16; // kind of a timestamp
} temp_reg_t;

// note: reg_temp[] must have at least the amount of
// registers used by handlers in worst case (currently 4)
#if defined(__arm__) || defined(__arm64__)
#include "../drc/emit_arm.c"

#ifndef __MACH__

static const int reg_map_g2h[] = {
   4,  5,  6,  7,
   8, -1, -1, -1,
  -1, -1, -1, -1,
  -1, -1, -1,  9, // r12 .. sp
  -1, -1, -1, 10, // SHR_PC,  SHR_PPC, SHR_PR,   SHR_SR,
  -1, -1, -1, -1, // SHR_GBR, SHR_VBR, SHR_MACH, SHR_MACL,
};

#else

// no r9..
static const int reg_map_g2h[] = {
   4,  5,  6,  7,
  -1, -1, -1, -1,
  -1, -1, -1, -1,
  -1, -1, -1,  8, // r12 .. sp
  -1, -1, -1, 10, // SHR_PC,  SHR_PPC, SHR_PR,   SHR_SR,
  -1, -1, -1, -1, // SHR_GBR, SHR_VBR, SHR_MACH, SHR_MACL,
};

#endif

static temp_reg_t reg_temp[] = {
  {  0, },
  {  1, },
  { 12, },
  { 14, },
  {  2, },
  {  3, },
};

#elif defined(__i386__)
#include "../drc/emit_x86.c"

static const int reg_map_g2h[] = {
  xSI,-1, -1, -1,
  -1, -1, -1, -1,
  -1, -1, -1, -1,
  -1, -1, -1, -1,
  -1, -1, -1, xDI,
  -1, -1, -1, -1,
};

// ax, cx, dx are usually temporaries by convention
static temp_reg_t reg_temp[] = {
  { xAX, },
  { xBX, },
  { xCX, },
  { xDX, },
};

#else
#error unsupported arch
#endif

#define T	0x00000001
#define S	0x00000002
#define I	0x000000f0
#define Q	0x00000100
#define M	0x00000200
#define T_save	0x00000800

#define I_SHIFT 4
#define Q_SHIFT 8
#define M_SHIFT 9

static void REGPARM(1) (*sh2_drc_entry)(SH2 *sh2);
static void            (*sh2_drc_dispatcher)(void);
static void            (*sh2_drc_exit)(void);
static void            (*sh2_drc_test_irq)(void);

static u32  REGPARM(2) (*sh2_drc_read8)(u32 a, SH2 *sh2);
static u32  REGPARM(2) (*sh2_drc_read16)(u32 a, SH2 *sh2);
static u32  REGPARM(2) (*sh2_drc_read32)(u32 a, SH2 *sh2);
static void REGPARM(2) (*sh2_drc_write8)(u32 a, u32 d);
static void REGPARM(2) (*sh2_drc_write16)(u32 a, u32 d);
static void REGPARM(3) (*sh2_drc_write32)(u32 a, u32 d, SH2 *sh2);

// address space stuff
static int dr_ctx_get_mem_ptr(u32 a, u32 *mask)
{
  int poffs = -1;

  if ((a & ~0x7ff) == 0) {
    // BIOS
    poffs = offsetof(SH2, p_bios);
    *mask = 0x7ff;
  }
  else if ((a & 0xfffff000) == 0xc0000000) {
    // data array
    // FIXME: access sh2->data_array instead
    poffs = offsetof(SH2, p_da);
    *mask = 0xfff;
  }
  else if ((a & 0xc6000000) == 0x06000000) {
    // SDRAM
    poffs = offsetof(SH2, p_sdram);
    *mask = 0x03ffff;
  }
  else if ((a & 0xc6000000) == 0x02000000) {
    // ROM
    poffs = offsetof(SH2, p_rom);
    *mask = 0x3fffff;
  }

  return poffs;
}

static struct block_entry *dr_get_entry(u32 pc, int is_slave, int *tcache_id)
{
  struct block_entry *be;
  u32 tcid = 0, mask;

  // data arrays have their own caches
  if ((pc & 0xe0000000) == 0xc0000000 || (pc & ~0xfff) == 0)
    tcid = 1 + is_slave;

  *tcache_id = tcid;

  mask = hash_table_sizes[tcid] - 1;
  be = HASH_FUNC(hash_tables[tcid], pc, mask);
  for (; be != NULL; be = be->next)
    if (be->pc == pc)
      return be;

  return NULL;
}

// ---------------------------------------------------------------

// block management
static void add_to_block_list(struct block_list **blist, struct block_desc *block)
{
  struct block_list *added = malloc(sizeof(*added));
  if (!added) {
    elprintf(EL_ANOMALY, "drc OOM (1)");
    return;
  }
  added->block = block;
  added->next = *blist;
  *blist = added;
}

static void rm_from_block_list(struct block_list **blist, struct block_desc *block)
{
  struct block_list *prev = NULL, *current = *blist;
  for (; current != NULL; prev = current, current = current->next) {
    if (current->block == block) {
      if (prev == NULL)
        *blist = current->next;
      else
        prev->next = current->next;
      free(current);
      return;
    }
  }
  dbg(1, "can't rm block %p (%08x-%08x)",
    block, block->addr, block->addr + block->size);
}

static void rm_block_list(struct block_list **blist)
{
  struct block_list *tmp, *current = *blist;
  while (current != NULL) {
    tmp = current;
    current = current->next;
    free(tmp);
  }
  *blist = NULL;
}

static void REGPARM(1) flush_tcache(int tcid)
{
  int i;

  dbg(1, "tcache #%d flush! (%d/%d, bds %d/%d)", tcid,
    tcache_ptrs[tcid] - tcache_bases[tcid], tcache_sizes[tcid],
    block_counts[tcid], block_max_counts[tcid]);

  block_counts[tcid] = 0;
  block_link_pool_counts[tcid] = 0;
  unresolved_links[tcid] = NULL;
  memset(hash_tables[tcid], 0, sizeof(*hash_tables[0]) * hash_table_sizes[tcid]);
  tcache_ptrs[tcid] = tcache_bases[tcid];
  if (Pico32xMem != NULL) {
    if (tcid == 0) // ROM, RAM
      memset(Pico32xMem->drcblk_ram, 0,
             sizeof(Pico32xMem->drcblk_ram));
    else
      memset(Pico32xMem->drcblk_da[tcid - 1], 0,
             sizeof(Pico32xMem->drcblk_da[0]));
  }
#if (DRC_DEBUG & 4)
  tcache_dsm_ptrs[tcid] = tcache_bases[tcid];
#endif

  for (i = 0; i < ram_sizes[tcid] / INVAL_PAGE_SIZE; i++)
    rm_block_list(&inval_lookup[tcid][i]);
}

static void add_to_hashlist(struct block_entry *be, int tcache_id)
{
  u32 tcmask = hash_table_sizes[tcache_id] - 1;

  be->next = HASH_FUNC(hash_tables[tcache_id], be->pc, tcmask);
  HASH_FUNC(hash_tables[tcache_id], be->pc, tcmask) = be;

#if (DRC_DEBUG & 2)
  if (be->next != NULL) {
    printf(" %08x: hash collision with %08x\n",
      be->pc, be->next->pc);
    hash_collisions++;
  }
#endif
}

static void rm_from_hashlist(struct block_entry *be, int tcache_id)
{
  u32 tcmask = hash_table_sizes[tcache_id] - 1;
  struct block_entry *cur, *prev;
  
  cur = HASH_FUNC(hash_tables[tcache_id], be->pc, tcmask);
  if (cur == NULL)
    goto missing;

  if (be == cur) { // first
    HASH_FUNC(hash_tables[tcache_id], be->pc, tcmask) = be->next;
    return;
  }

  for (prev = cur, cur = cur->next; cur != NULL; cur = cur->next) {
    if (cur == be) {
      prev->next = cur->next;
      return;
    }
  }

missing:
  dbg(1, "rm_from_hashlist: be %p %08x missing?", be, be->pc);
}

static struct block_desc *dr_add_block(u32 addr, u16 size_lit,
  u16 size_nolit, int is_slave, int *blk_id)
{
  struct block_entry *be;
  struct block_desc *bd;
  int tcache_id;
  int *bcount;

  // do a lookup to get tcache_id and override check
  be = dr_get_entry(addr, is_slave, &tcache_id);
  if (be != NULL)
    dbg(1, "block override for %08x", addr);

  bcount = &block_counts[tcache_id];
  if (*bcount >= block_max_counts[tcache_id]) {
    dbg(1, "bd overflow for tcache %d", tcache_id);
    return NULL;
  }

  bd = &block_tables[tcache_id][*bcount];
  bd->addr = addr;
  bd->size = size_lit;
  bd->size_nolit = size_nolit;

  bd->entry_count = 1;
  bd->entryp[0].pc = addr;
  bd->entryp[0].tcache_ptr = tcache_ptr;
  bd->entryp[0].links = NULL;
#if (DRC_DEBUG & 2)
  bd->entryp[0].block = bd;
  bd->refcount = 0;
#endif
  add_to_hashlist(&bd->entryp[0], tcache_id);

  *blk_id = *bcount;
  (*bcount)++;

  return bd;
}

static void REGPARM(3) *dr_lookup_block(u32 pc, int is_slave, int *tcache_id)
{
  struct block_entry *be = NULL;
  void *block = NULL;

  be = dr_get_entry(pc, is_slave, tcache_id);
  if (be != NULL)
    block = be->tcache_ptr;

#if (DRC_DEBUG & 2)
  if (be != NULL)
    be->block->refcount++;
#endif
  return block;
}

static void *dr_failure(void)
{
  lprintf("recompilation failed\n");
  exit(1);
}

static void *dr_prepare_ext_branch(u32 pc, int is_slave, int tcache_id)
{
#if LINK_BRANCHES
  struct block_link *bl = block_link_pool[tcache_id];
  int cnt = block_link_pool_counts[tcache_id];
  struct block_entry *be = NULL;
  int target_tcache_id;
  int i;

  be = dr_get_entry(pc, is_slave, &target_tcache_id);
  if (target_tcache_id != tcache_id)
    return sh2_drc_dispatcher;

  // if pool has been freed, reuse
  for (i = cnt - 1; i >= 0; i--)
    if (bl[i].target_pc != 0)
      break;
  cnt = i + 1;
  if (cnt >= block_link_pool_max_counts[tcache_id]) {
    dbg(1, "bl overflow for tcache %d", tcache_id);
    return NULL;
  }
  bl += cnt;
  block_link_pool_counts[tcache_id]++;

  bl->target_pc = pc;
  bl->jump = tcache_ptr;

  if (be != NULL) {
    dbg(2, "- early link from %p to pc %08x", bl->jump, pc);
    bl->next = be->links;
    be->links = bl;
    return be->tcache_ptr;
  }
  else {
    bl->next = unresolved_links[tcache_id];
    unresolved_links[tcache_id] = bl;
    return sh2_drc_dispatcher;
  }
#else
  return sh2_drc_dispatcher;
#endif
}

static void dr_link_blocks(struct block_entry *be, int tcache_id)
{
#if LINK_BRANCHES
  struct block_link *first = unresolved_links[tcache_id];
  struct block_link *bl, *prev, *tmp;
  u32 pc = be->pc;

  for (bl = prev = first; bl != NULL; ) {
    if (bl->target_pc == pc) {
      dbg(2, "- link from %p to pc %08x", bl->jump, pc);
      emith_jump_patch(bl->jump, tcache_ptr);

      // move bl from unresolved_links to block_entry
      tmp = bl->next;
      bl->next = be->links;
      be->links = bl;

      if (bl == first)
        first = prev = bl = tmp;
      else
        prev->next = bl = tmp;
      continue;
    }
    prev = bl;
    bl = bl->next;
  }
  unresolved_links[tcache_id] = first;

  // could sync arm caches here, but that's unnecessary
#endif
}

#define ADD_TO_ARRAY(array, count, item, failcode) \
  if (count >= ARRAY_SIZE(array)) { \
    dbg(1, "warning: " #array " overflow"); \
    failcode; \
  } \
  array[count++] = item;

static int find_in_array(u32 *array, size_t size, u32 what)
{
  size_t i;
  for (i = 0; i < size; i++)
    if (what == array[i])
      return i;

  return -1;
}

// ---------------------------------------------------------------

// register cache / constant propagation stuff
typedef enum {
  RC_GR_READ,
  RC_GR_WRITE,
  RC_GR_RMW,
} rc_gr_mode;

static int rcache_get_reg_(sh2_reg_e r, rc_gr_mode mode, int do_locking);

// guest regs with constants
static u32 dr_gcregs[24];
// a mask of constant/dirty regs
static u32 dr_gcregs_mask;
static u32 dr_gcregs_dirty;

#if PROPAGATE_CONSTANTS
static void gconst_new(sh2_reg_e r, u32 val)
{
  int i;

  dr_gcregs_mask  |= 1 << r;
  dr_gcregs_dirty |= 1 << r;
  dr_gcregs[r] = val;

  // throw away old r that we might have cached
  for (i = ARRAY_SIZE(reg_temp) - 1; i >= 0; i--) {
    if ((reg_temp[i].type == HR_CACHED) &&
         reg_temp[i].greg == r) {
      reg_temp[i].type = HR_FREE;
      reg_temp[i].flags = 0;
    }
  }
}
#endif

static int gconst_get(sh2_reg_e r, u32 *val)
{
  if (dr_gcregs_mask & (1 << r)) {
    *val = dr_gcregs[r];
    return 1;
  }
  return 0;
}

static int gconst_check(sh2_reg_e r)
{
  if ((dr_gcregs_mask | dr_gcregs_dirty) & (1 << r))
    return 1;
  return 0;
}

// update hr if dirty, else do nothing
static int gconst_try_read(int hr, sh2_reg_e r)
{
  if (dr_gcregs_dirty & (1 << r)) {
    emith_move_r_imm(hr, dr_gcregs[r]);
    dr_gcregs_dirty &= ~(1 << r);
    return 1;
  }
  return 0;
}

static void gconst_check_evict(sh2_reg_e r)
{
  if (dr_gcregs_mask & (1 << r))
    // no longer cached in reg, make dirty again
    dr_gcregs_dirty |= 1 << r;
}

static void gconst_kill(sh2_reg_e r)
{
  dr_gcregs_mask &= ~(1 << r);
  dr_gcregs_dirty &= ~(1 << r);
}

static void gconst_clean(void)
{
  int i;

  for (i = 0; i < ARRAY_SIZE(dr_gcregs); i++)
    if (dr_gcregs_dirty & (1 << i)) {
      // using RC_GR_READ here: it will call gconst_try_read,
      // cache the reg and mark it dirty.
      rcache_get_reg_(i, RC_GR_READ, 0);
    }
}

static void gconst_invalidate(void)
{
  dr_gcregs_mask = dr_gcregs_dirty = 0;
}

static u16 rcache_counter;

static temp_reg_t *rcache_evict(void)
{
  // evict reg with oldest stamp
  int i, oldest = -1;
  u16 min_stamp = (u16)-1;

  for (i = 0; i < ARRAY_SIZE(reg_temp); i++) {
    if (reg_temp[i].type == HR_CACHED && !(reg_temp[i].flags & HRF_LOCKED) &&
        reg_temp[i].stamp <= min_stamp) {
      min_stamp = reg_temp[i].stamp;
      oldest = i;
    }
  }

  if (oldest == -1) {
    printf("no registers to evict, aborting\n");
    exit(1);
  }

  i = oldest;
  if (reg_temp[i].type == HR_CACHED) {
    if (reg_temp[i].flags & HRF_DIRTY)
      // writeback
      emith_ctx_write(reg_temp[i].hreg, reg_temp[i].greg * 4);
    gconst_check_evict(reg_temp[i].greg);
  }

  reg_temp[i].type = HR_FREE;
  reg_temp[i].flags = 0;
  return &reg_temp[i];
}

static int get_reg_static(sh2_reg_e r, rc_gr_mode mode)
{
  int i = reg_map_g2h[r];
  if (i != -1) {
    if (mode != RC_GR_WRITE)
      gconst_try_read(i, r);
  }
  return i;
}

// note: must not be called when doing conditional code
static int rcache_get_reg_(sh2_reg_e r, rc_gr_mode mode, int do_locking)
{
  temp_reg_t *tr;
  int i, ret;

  // maybe statically mapped?
  ret = get_reg_static(r, mode);
  if (ret != -1)
    goto end;

  rcache_counter++;

  // maybe already cached?
  // if so, prefer against gconst (they must be in sync)
  for (i = ARRAY_SIZE(reg_temp) - 1; i >= 0; i--) {
    if (reg_temp[i].type == HR_CACHED && reg_temp[i].greg == r) {
      reg_temp[i].stamp = rcache_counter;
      if (mode != RC_GR_READ)
        reg_temp[i].flags |= HRF_DIRTY;
      ret = reg_temp[i].hreg;
      goto end;
    }
  }

  // use any free reg
  for (i = ARRAY_SIZE(reg_temp) - 1; i >= 0; i--) {
    if (reg_temp[i].type == HR_FREE) {
      tr = &reg_temp[i];
      goto do_alloc;
    }
  }

  tr = rcache_evict();

do_alloc:
  tr->type = HR_CACHED;
  if (do_locking)
    tr->flags |= HRF_LOCKED;
  if (mode != RC_GR_READ)
    tr->flags |= HRF_DIRTY;
  tr->greg = r;
  tr->stamp = rcache_counter;
  ret = tr->hreg;

  if (mode != RC_GR_WRITE) {
    if (gconst_check(r)) {
      if (gconst_try_read(ret, r))
        tr->flags |= HRF_DIRTY;
    }
    else
      emith_ctx_read(tr->hreg, r * 4);
  }

end:
  if (mode != RC_GR_READ)
    gconst_kill(r);

  return ret;
}

static int rcache_get_reg(sh2_reg_e r, rc_gr_mode mode)
{
  return rcache_get_reg_(r, mode, 1);
}

static int rcache_get_tmp(void)
{
  temp_reg_t *tr;
  int i;

  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    if (reg_temp[i].type == HR_FREE) {
      tr = &reg_temp[i];
      goto do_alloc;
    }

  tr = rcache_evict();

do_alloc:
  tr->type = HR_TEMP;
  return tr->hreg;
}

static int rcache_get_arg_id(int arg)
{
  int i, r = 0;
  host_arg2reg(r, arg);

  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    if (reg_temp[i].hreg == r)
      break;

  if (i == ARRAY_SIZE(reg_temp)) // can't happen
    exit(1);

  if (reg_temp[i].type == HR_CACHED) {
    // writeback
    if (reg_temp[i].flags & HRF_DIRTY)
      emith_ctx_write(reg_temp[i].hreg, reg_temp[i].greg * 4);
    gconst_check_evict(reg_temp[i].greg);
  }
  else if (reg_temp[i].type == HR_TEMP) {
    printf("arg %d reg %d already used, aborting\n", arg, r);
    exit(1);
  }

  reg_temp[i].type = HR_FREE;
  reg_temp[i].flags = 0;

  return i;
}

// get a reg to be used as function arg
static int rcache_get_tmp_arg(int arg)
{
  int id = rcache_get_arg_id(arg);
  reg_temp[id].type = HR_TEMP;

  return reg_temp[id].hreg;
}

// same but caches a reg. RC_GR_READ only.
static int rcache_get_reg_arg(int arg, sh2_reg_e r)
{
  int i, srcr, dstr, dstid;
  int dirty = 0, src_dirty = 0;

  dstid = rcache_get_arg_id(arg);
  dstr = reg_temp[dstid].hreg;

  // maybe already statically mapped?
  srcr = get_reg_static(r, RC_GR_READ);
  if (srcr != -1)
    goto do_cache;

  // maybe already cached?
  for (i = ARRAY_SIZE(reg_temp) - 1; i >= 0; i--) {
    if ((reg_temp[i].type == HR_CACHED) &&
         reg_temp[i].greg == r)
    {
      srcr = reg_temp[i].hreg;
      if (reg_temp[i].flags & HRF_DIRTY)
        src_dirty = 1;
      goto do_cache;
    }
  }

  // must read
  srcr = dstr;
  if (gconst_check(r)) {
    if (gconst_try_read(srcr, r))
      dirty = 1;
  }
  else
    emith_ctx_read(srcr, r * 4);

do_cache:
  if (dstr != srcr)
    emith_move_r_r(dstr, srcr);
#if 1
  else
    dirty |= src_dirty;

  if (dirty)
    // must clean, callers might want to modify the arg before call
    emith_ctx_write(dstr, r * 4);
#else
  if (dirty)
    reg_temp[dstid].flags |= HRF_DIRTY;
#endif

  reg_temp[dstid].stamp = ++rcache_counter;
  reg_temp[dstid].type = HR_CACHED;
  reg_temp[dstid].greg = r;
  reg_temp[dstid].flags |= HRF_LOCKED;
  return dstr;
}

static void rcache_free_tmp(int hr)
{
  int i;
  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    if (reg_temp[i].hreg == hr)
      break;

  if (i == ARRAY_SIZE(reg_temp) || reg_temp[i].type != HR_TEMP) {
    printf("rcache_free_tmp fail: #%i hr %d, type %d\n", i, hr, reg_temp[i].type);
    return;
  }

  reg_temp[i].type = HR_FREE;
  reg_temp[i].flags = 0;
}

static void rcache_unlock(int hr)
{
  int i;
  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    if (reg_temp[i].type == HR_CACHED && reg_temp[i].hreg == hr)
      reg_temp[i].flags &= ~HRF_LOCKED;
}

static void rcache_unlock_all(void)
{
  int i;
  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    reg_temp[i].flags &= ~HRF_LOCKED;
}

static inline u32 rcache_used_hreg_mask(void)
{
  u32 mask = 0;
  int i;

  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    if (reg_temp[i].type != HR_FREE)
      mask |= 1 << reg_temp[i].hreg;

  return mask;
}

static void rcache_clean(void)
{
  int i;
  gconst_clean();

  for (i = 0; i < ARRAY_SIZE(reg_temp); i++)
    if (reg_temp[i].type == HR_CACHED && (reg_temp[i].flags & HRF_DIRTY)) {
      // writeback
      emith_ctx_write(reg_temp[i].hreg, reg_temp[i].greg * 4);
      reg_temp[i].flags &= ~HRF_DIRTY;
    }
}

static void rcache_invalidate(void)
{
  int i;
  for (i = 0; i < ARRAY_SIZE(reg_temp); i++) {
    reg_temp[i].type = HR_FREE;
    reg_temp[i].flags = 0;
  }
  rcache_counter = 0;

  gconst_invalidate();
}

static void rcache_flush(void)
{
  rcache_clean();
  rcache_invalidate();
}

// ---------------------------------------------------------------

static int emit_get_rbase_and_offs(u32 a, u32 *offs)
{
  u32 mask = 0;
  int poffs;
  int hr;

  poffs = dr_ctx_get_mem_ptr(a, &mask);
  if (poffs == -1)
    return -1;

  // XXX: could use some related reg
  hr = rcache_get_tmp();
  emith_ctx_read(hr, poffs);
  emith_add_r_imm(hr, a & mask & ~0xff);
  *offs = a & 0xff; // XXX: ARM oriented..
  return hr;
}

static void emit_move_r_imm32(sh2_reg_e dst, u32 imm)
{
#if PROPAGATE_CONSTANTS
  gconst_new(dst, imm);
#else
  int hr = rcache_get_reg(dst, RC_GR_WRITE);
  emith_move_r_imm(hr, imm);
#endif
}

static void emit_move_r_r(sh2_reg_e dst, sh2_reg_e src)
{
  int hr_d = rcache_get_reg(dst, RC_GR_WRITE);
  int hr_s = rcache_get_reg(src, RC_GR_READ);

  emith_move_r_r(hr_d, hr_s);
}

// T must be clear, and comparison done just before this
static void emit_or_t_if_eq(int srr)
{
  EMITH_SJMP_START(DCOND_NE);
  emith_or_r_imm_c(DCOND_EQ, srr, T);
  EMITH_SJMP_END(DCOND_NE);
}

// arguments must be ready
// reg cache must be clean before call
static int emit_memhandler_read_(int size, int ram_check)
{
  int arg1;
#if 0
  int arg0;
  host_arg2reg(arg0, 0);
#endif

  rcache_clean();

  // must writeback cycles for poll detection stuff
  // FIXME: rm
  if (reg_map_g2h[SHR_SR] != -1)
    emith_ctx_write(reg_map_g2h[SHR_SR], SHR_SR * 4);

  arg1 = rcache_get_tmp_arg(1);
  emith_move_r_r(arg1, CONTEXT_REG);

#if 0 // can't do this because of unmapped reads
 // ndef PDB_NET
  if (ram_check && Pico.rom == (void *)0x02000000 && Pico32xMem->sdram == (void *)0x06000000) {
    int tmp = rcache_get_tmp();
    emith_and_r_r_imm(tmp, arg0, 0xfb000000);
    emith_cmp_r_imm(tmp, 0x02000000);
    switch (size) {
    case 0: // 8
      EMITH_SJMP3_START(DCOND_NE);
      emith_eor_r_imm_c(DCOND_EQ, arg0, 1);
      emith_read8_r_r_offs_c(DCOND_EQ, arg0, arg0, 0);
      EMITH_SJMP3_MID(DCOND_NE);
      emith_call_cond(DCOND_NE, sh2_drc_read8);
      EMITH_SJMP3_END();
      break;
    case 1: // 16
      EMITH_SJMP3_START(DCOND_NE);
      emith_read16_r_r_offs_c(DCOND_EQ, arg0, arg0, 0);
      EMITH_SJMP3_MID(DCOND_NE);
      emith_call_cond(DCOND_NE, sh2_drc_read16);
      EMITH_SJMP3_END();
      break;
    case 2: // 32
      EMITH_SJMP3_START(DCOND_NE);
      emith_read_r_r_offs_c(DCOND_EQ, arg0, arg0, 0);
      emith_ror_c(DCOND_EQ, arg0, arg0, 16);
      EMITH_SJMP3_MID(DCOND_NE);
      emith_call_cond(DCOND_NE, sh2_drc_read32);
      EMITH_SJMP3_END();
      break;
    }
  }
  else
#endif
  {
    switch (size) {
    case 0: // 8
      emith_call(sh2_drc_read8);
      break;
    case 1: // 16
      emith_call(sh2_drc_read16);
      break;
    case 2: // 32
      emith_call(sh2_drc_read32);
      break;
    }
  }
  rcache_invalidate();

  if (reg_map_g2h[SHR_SR] != -1)
    emith_ctx_read(reg_map_g2h[SHR_SR], SHR_SR * 4);

  // assuming arg0 and retval reg matches
  return rcache_get_tmp_arg(0);
}

static int emit_memhandler_read(int size)
{
  return emit_memhandler_read_(size, 1);
}

static int emit_memhandler_read_rr(sh2_reg_e rd, sh2_reg_e rs, u32 offs, int size)
{
  int hr, hr2, ram_check = 1;
  u32 val, offs2;

  if (gconst_get(rs, &val)) {
    hr = emit_get_rbase_and_offs(val + offs, &offs2);
    if (hr != -1) {
      hr2 = rcache_get_reg(rd, RC_GR_WRITE);
      switch (size) {
      case 0: // 8
        emith_read8_r_r_offs(hr2, hr, offs2 ^ 1);
        emith_sext(hr2, hr2, 8);
        break;
      case 1: // 16
        emith_read16_r_r_offs(hr2, hr, offs2);
        emith_sext(hr2, hr2, 16);
        break;
      case 2: // 32
        emith_read_r_r_offs(hr2, hr, offs2);
        emith_ror(hr2, hr2, 16);
        break;
      }
      rcache_free_tmp(hr);
      return hr2;
    }

    ram_check = 0;
  }

  hr = rcache_get_reg_arg(0, rs);
  if (offs != 0)
    emith_add_r_imm(hr, offs);
  hr  = emit_memhandler_read_(size, ram_check);
  hr2 = rcache_get_reg(rd, RC_GR_WRITE);
  if (size != 2) {
    emith_sext(hr2, hr, (size == 1) ? 16 : 8);
  } else
    emith_move_r_r(hr2, hr);
  rcache_free_tmp(hr);

  return hr2;
}

static void emit_memhandler_write(int size)
{
  int ctxr;
  host_arg2reg(ctxr, 2);
  if (reg_map_g2h[SHR_SR] != -1)
    emith_ctx_write(reg_map_g2h[SHR_SR], SHR_SR * 4);

  rcache_clean();

  switch (size) {
  case 0: // 8
    // XXX: consider inlining sh2_drc_write8
    emith_call(sh2_drc_write8);
    break;
  case 1: // 16
    emith_call(sh2_drc_write16);
    break;
  case 2: // 32
    emith_move_r_r(ctxr, CONTEXT_REG);
    emith_call(sh2_drc_write32);
    break;
  }

  rcache_invalidate();
  if (reg_map_g2h[SHR_SR] != -1)
    emith_ctx_read(reg_map_g2h[SHR_SR], SHR_SR * 4);
}

// @(Rx,Ry)
static int emit_indirect_indexed_read(int rx, int ry, int size)
{
  int a0, t;
  a0 = rcache_get_reg_arg(0, rx);
  t  = rcache_get_reg(ry, RC_GR_READ);
  emith_add_r_r(a0, t);
  return emit_memhandler_read(size);
}

// read @Rn, @rm
static void emit_indirect_read_double(u32 *rnr, u32 *rmr, int rn, int rm, int size)
{
  int tmp;

  rcache_get_reg_arg(0, rn);
  tmp = emit_memhandler_read(size);
  emith_ctx_write(tmp, offsetof(SH2, drc_tmp));
  rcache_free_tmp(tmp);
  tmp = rcache_get_reg(rn, RC_GR_RMW);
  emith_add_r_imm(tmp, 1 << size);
  rcache_unlock(tmp);

  rcache_get_reg_arg(0, rm);
  *rmr = emit_memhandler_read(size);
  *rnr = rcache_get_tmp();
  emith_ctx_read(*rnr, offsetof(SH2, drc_tmp));
  tmp = rcache_get_reg(rm, RC_GR_RMW);
  emith_add_r_imm(tmp, 1 << size);
  rcache_unlock(tmp);
}
 
static void emit_do_static_regs(int is_write, int tmpr)
{
  int i, r, count;

  for (i = 0; i < ARRAY_SIZE(reg_map_g2h); i++) {
    r = reg_map_g2h[i];
    if (r == -1)
      continue;

    for (count = 1; i < ARRAY_SIZE(reg_map_g2h) - 1; i++, r++) {
      if (reg_map_g2h[i + 1] != r + 1)
        break;
      count++;
    }

    if (count > 1) {
      // i, r point to last item
      if (is_write)
        emith_ctx_write_multiple(r - count + 1, (i - count + 1) * 4, count, tmpr);
      else
        emith_ctx_read_multiple(r - count + 1, (i - count + 1) * 4, count, tmpr);
    } else {
      if (is_write)
        emith_ctx_write(r, i * 4);
      else
        emith_ctx_read(r, i * 4);
    }
  }
}

static void emit_block_entry(void)
{
  int arg0;

  host_arg2reg(arg0, 0);

#if (DRC_DEBUG & 8) || defined(PDB)
  int arg1, arg2;
  host_arg2reg(arg1, 1);
  host_arg2reg(arg2, 2);

  emit_do_static_regs(1, arg2);
  emith_move_r_r(arg1, CONTEXT_REG);
  emith_move_r_r(arg2, rcache_get_reg(SHR_SR, RC_GR_READ));
  emith_call(sh2_drc_log_entry);
  rcache_invalidate();
#endif
  emith_tst_r_r(arg0, arg0);
  EMITH_SJMP_START(DCOND_EQ);
  emith_jump_reg_c(DCOND_NE, arg0);
  EMITH_SJMP_END(DCOND_EQ);
}

#define DELAY_SAVE_T(sr) { \
  emith_bic_r_imm(sr, T_save); \
  emith_tst_r_imm(sr, T);      \
  EMITH_SJMP_START(DCOND_EQ);  \
  emith_or_r_imm_c(DCOND_NE, sr, T_save); \
  EMITH_SJMP_END(DCOND_EQ);    \
}

#define FLUSH_CYCLES(sr) \
  if (cycles > 0) { \
    emith_sub_r_imm(sr, cycles << 12); \
    cycles = 0; \
  }

static void *dr_get_pc_base(u32 pc, int is_slave);

static void REGPARM(2) *sh2_translate(SH2 *sh2, int tcache_id)
{
  u32 branch_target_pc[MAX_LOCAL_BRANCHES];
  void *branch_target_ptr[MAX_LOCAL_BRANCHES];
  int branch_target_count = 0;
  void *branch_patch_ptr[MAX_LOCAL_BRANCHES];
  u32 branch_patch_pc[MAX_LOCAL_BRANCHES];
  int branch_patch_count = 0;
  u32 literal_addr[MAX_LITERALS];
  int literal_addr_count = 0;
  u8 op_flags[BLOCK_INSN_LIMIT];
  struct {
    u32 test_irq:1;
    u32 pending_branch_direct:1;
    u32 pending_branch_indirect:1;
    u32 literals_disabled:1;
  } drcf = { 0, };

  // PC of current, first, last SH2 insn
  u32 pc, base_pc, end_pc;
  u32 end_literals;
  void *block_entry_ptr;
  struct block_desc *block;
  u16 *dr_pc_base;
  struct op_data *opd;
  int blkid_main = 0;
  int skip_op = 0;
  u32 tmp, tmp2;
  int cycles;
  int i, v;
  int op;

  base_pc = sh2->pc;
  drcf.literals_disabled = literal_disabled_frames != 0;

  // get base/validate PC
  dr_pc_base = dr_get_pc_base(base_pc, sh2->is_slave);
  if (dr_pc_base == (void *)-1) {
    printf("invalid PC, aborting: %08x\n", base_pc);
    // FIXME: be less destructive
    exit(1);
  }

  tcache_ptr = tcache_ptrs[tcache_id];

  // predict tcache overflow
  tmp = tcache_ptr - tcache_bases[tcache_id];
  if (tmp > tcache_sizes[tcache_id] - MAX_BLOCK_SIZE) {
    dbg(1, "tcache %d overflow", tcache_id);
    return NULL;
  }

  // initial passes to disassemble and analyze the block
  scan_block(base_pc, sh2->is_slave, op_flags, &end_pc, &end_literals);

  if (drcf.literals_disabled)
    end_literals = end_pc;

  block = dr_add_block(base_pc, end_literals - base_pc,
    end_pc - base_pc, sh2->is_slave, &blkid_main);
  if (block == NULL)
    return NULL;

  block_entry_ptr = tcache_ptr;
  dbg(2, "== %csh2 block #%d,%d %08x-%08x -> %p", sh2->is_slave ? 's' : 'm',
    tcache_id, blkid_main, base_pc, end_pc, block_entry_ptr);

  dr_link_blocks(&block->entryp[0], tcache_id);

  // collect branch_targets that don't land on delay slots
  for (pc = base_pc, i = 0; pc < end_pc; i++, pc += 2) {
    if (!(op_flags[i] & OF_BTARGET))
      continue;
    if (op_flags[i] & OF_DELAY_OP) {
      op_flags[i] &= ~OF_BTARGET;
      continue;
    }
    ADD_TO_ARRAY(branch_target_pc, branch_target_count, pc, break);
  }

  if (branch_target_count > 0) {
    memset(branch_target_ptr, 0, sizeof(branch_target_ptr[0]) * branch_target_count);
  }

  // clear stale state after compile errors
  rcache_invalidate();

  // -------------------------------------------------
  // 3rd pass: actual compilation
  pc = base_pc;
  cycles = 0;
  for (i = 0; pc < end_pc; i++)
  {
    u32 delay_dep_fw = 0, delay_dep_bk = 0;
    u32 tmp3, tmp4, sr;

    opd = &ops[i];
    op = FETCH_OP(pc);

#if (DRC_DEBUG & 2)
    insns_compiled++;
#endif
#if (DRC_DEBUG & 4)
    DasmSH2(sh2dasm_buff, pc, op);
    printf("%c%08x %04x %s\n", (op_flags[i] & OF_BTARGET) ? '*' : ' ',
      pc, op, sh2dasm_buff);
#endif

    if ((op_flags[i] & OF_BTARGET) || pc == base_pc)
    {
      if (pc != base_pc)
      {
        sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
        FLUSH_CYCLES(sr);
        rcache_flush();

        // make block entry
        v = block->entry_count;
        if (v < ARRAY_SIZE(block->entryp)) {
          block->entryp[v].pc = pc;
          block->entryp[v].tcache_ptr = tcache_ptr;
          block->entryp[v].links = NULL;
#if (DRC_DEBUG & 2)
          block->entryp[v].block = block;
#endif
          add_to_hashlist(&block->entryp[v], tcache_id);
          block->entry_count++;

          dbg(2, "-- %csh2 block #%d,%d entry %08x -> %p",
            sh2->is_slave ? 's' : 'm', tcache_id, blkid_main,
            pc, tcache_ptr);

          // since we made a block entry, link any other blocks
          // that jump to current pc
          dr_link_blocks(&block->entryp[v], tcache_id);
        }
        else {
          dbg(1, "too many entryp for block #%d,%d pc=%08x",
            tcache_id, blkid_main, pc);
        }

        do_host_disasm(tcache_id);
      }

      v = find_in_array(branch_target_pc, branch_target_count, pc);
      if (v >= 0)
        branch_target_ptr[v] = tcache_ptr;

      // must update PC
      emit_move_r_imm32(SHR_PC, pc);
      rcache_clean();

      // check cycles
      sr = rcache_get_reg(SHR_SR, RC_GR_READ);
      emith_cmp_r_imm(sr, 0);
      emith_jump_cond(DCOND_LE, sh2_drc_exit);
      do_host_disasm(tcache_id);
      rcache_unlock_all();
    }

#ifdef DRC_CMP
    if (!(op_flags[i] & OF_DELAY_OP)) {
      emit_move_r_imm32(SHR_PC, pc);
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
      FLUSH_CYCLES(sr);
      rcache_clean();

      tmp = rcache_used_hreg_mask();
      emith_save_caller_regs(tmp);
      emit_do_static_regs(1, 0);
      emith_pass_arg_r(0, CONTEXT_REG);
      emith_call(do_sh2_cmp);
      emith_restore_caller_regs(tmp);
    }
#endif

    pc += 2;

    if (skip_op > 0) {
      skip_op--;
      continue;
    }

    if (op_flags[i] & OF_DELAY_OP)
    {
      // handle delay slot dependencies
      delay_dep_fw = opd->dest & ops[i-1].source;
      delay_dep_bk = opd->source & ops[i-1].dest;
      if (delay_dep_fw & BITMASK1(SHR_T)) {
        sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
        DELAY_SAVE_T(sr);
      }
      if (delay_dep_bk & BITMASK1(SHR_PC)) {
        if (opd->op != OP_LOAD_POOL && opd->op != OP_MOVA) {
          // can only be those 2 really..
          elprintf_sh2(sh2, EL_ANOMALY,
            "drc: illegal slot insn %04x @ %08x?", op, pc - 2);
        }
        if (opd->imm != 0)
          ; // addr already resolved somehow
        else {
          switch (ops[i-1].op) {
          case OP_BRANCH:
            emit_move_r_imm32(SHR_PC, ops[i-1].imm);
            break;
          case OP_BRANCH_CT:
          case OP_BRANCH_CF:
            tmp = rcache_get_reg(SHR_PC, RC_GR_WRITE);
            sr = rcache_get_reg(SHR_SR, RC_GR_READ);
            emith_move_r_imm(tmp, pc);
            emith_tst_r_imm(sr, T);
            tmp2 = ops[i-1].op == OP_BRANCH_CT ? DCOND_NE : DCOND_EQ;
            emith_move_r_imm_c(tmp2, tmp, ops[i-1].imm);
            break;
          // case OP_BRANCH_R OP_BRANCH_RF - PC already loaded
          }
        }
      }
      //if (delay_dep_fw & ~BITMASK1(SHR_T))
      //  dbg(1, "unhandled delay_dep_fw: %x", delay_dep_fw & ~BITMASK1(SHR_T));
      if (delay_dep_bk & ~BITMASK2(SHR_PC, SHR_PR))
        dbg(1, "unhandled delay_dep_bk: %x", delay_dep_bk);
    }

    switch (opd->op)
    {
    case OP_BRANCH:
    case OP_BRANCH_CT:
    case OP_BRANCH_CF:
      if (opd->dest & BITMASK1(SHR_PR))
        emit_move_r_imm32(SHR_PR, pc + 2);
      drcf.pending_branch_direct = 1;
      goto end_op;

    case OP_BRANCH_R:
      if (opd->dest & BITMASK1(SHR_PR))
        emit_move_r_imm32(SHR_PR, pc + 2);
      emit_move_r_r(SHR_PC, opd->rm);
      drcf.pending_branch_indirect = 1;
      goto end_op;

    case OP_BRANCH_RF:
      tmp  = rcache_get_reg(SHR_PC, RC_GR_WRITE);
      tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ);
      if (opd->dest & BITMASK1(SHR_PR)) {
        tmp3 = rcache_get_reg(SHR_PR, RC_GR_WRITE);
        emith_move_r_imm(tmp3, pc + 2);
        emith_add_r_r_r(tmp, tmp2, tmp3);
      }
      else {
        emith_move_r_r(tmp, tmp2);
        emith_add_r_imm(tmp, pc + 2);
      }
      drcf.pending_branch_indirect = 1;
      goto end_op;

    case OP_SLEEP:
      printf("TODO sleep\n");
      goto end_op;

    case OP_RTE:
      // pop PC
      emit_memhandler_read_rr(SHR_PC, SHR_SP, 0, 2);
      // pop SR
      tmp = rcache_get_reg_arg(0, SHR_SP);
      emith_add_r_imm(tmp, 4);
      tmp = emit_memhandler_read(2);
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
      emith_write_sr(sr, tmp);
      rcache_free_tmp(tmp);
      tmp = rcache_get_reg(SHR_SP, RC_GR_RMW);
      emith_add_r_imm(tmp, 4*2);
      drcf.test_irq = 1;
      drcf.pending_branch_indirect = 1;
      goto end_op;

    case OP_LOAD_POOL:
#if PROPAGATE_CONSTANTS
      if (opd->imm != 0 && opd->imm < end_literals
          && literal_addr_count < MAX_LITERALS)
      {
        ADD_TO_ARRAY(literal_addr, literal_addr_count, opd->imm,);
        if (opd->size == 2)
          tmp = FETCH32(opd->imm);
        else
          tmp = (u32)(int)(signed short)FETCH_OP(opd->imm);
        gconst_new(GET_Rn(), tmp);
      }
      else
#endif
      {
        tmp = rcache_get_tmp_arg(0);
        if (opd->imm != 0)
          emith_move_r_imm(tmp, opd->imm);
        else {
          // have to calculate read addr from PC
          tmp2 = rcache_get_reg(SHR_PC, RC_GR_READ);
          if (opd->size == 2) {
            emith_add_r_r_imm(tmp, tmp2, 2 + (op & 0xff) * 4);
            emith_bic_r_imm(tmp, 3);
          }
          else
            emith_add_r_r_imm(tmp, tmp2, 2 + (op & 0xff) * 2);
        }
        tmp2 = emit_memhandler_read(opd->size);
        tmp3 = rcache_get_reg(GET_Rn(), RC_GR_WRITE);
        if (opd->size == 2)
          emith_move_r_r(tmp3, tmp2);
        else
          emith_sext(tmp3, tmp2, 16);
        rcache_free_tmp(tmp2);
      }
      goto end_op;

    case OP_MOVA:
      if (opd->imm != 0)
        emit_move_r_imm32(SHR_R0, opd->imm);
      else {
        tmp = rcache_get_reg(SHR_R0, RC_GR_WRITE);
        tmp2 = rcache_get_reg(SHR_PC, RC_GR_READ);
        emith_add_r_r_imm(tmp, tmp2, 2 + (op & 0xff) * 4);
        emith_bic_r_imm(tmp, 3);
      }
      goto end_op;
    }

    switch ((op >> 12) & 0x0f)
    {
    /////////////////////////////////////////////
    case 0x00:
      switch (op & 0x0f)
      {
      case 0x02:
        tmp = rcache_get_reg(GET_Rn(), RC_GR_WRITE);
        switch (GET_Fx())
        {
        case 0: // STC SR,Rn  0000nnnn00000010
          tmp2 = SHR_SR;
          break;
        case 1: // STC GBR,Rn 0000nnnn00010010
          tmp2 = SHR_GBR;
          break;
        case 2: // STC VBR,Rn 0000nnnn00100010
          tmp2 = SHR_VBR;
          break;
        default:
          goto default_;
        }
        tmp3 = rcache_get_reg(tmp2, RC_GR_READ);
        emith_move_r_r(tmp, tmp3);
        if (tmp2 == SHR_SR)
          emith_clear_msb(tmp, tmp, 22); // reserved bits defined by ISA as 0
        goto end_op;
      case 0x04: // MOV.B Rm,@(R0,Rn)   0000nnnnmmmm0100
      case 0x05: // MOV.W Rm,@(R0,Rn)   0000nnnnmmmm0101
      case 0x06: // MOV.L Rm,@(R0,Rn)   0000nnnnmmmm0110
        rcache_clean();
        tmp  = rcache_get_reg_arg(1, GET_Rm());
        tmp2 = rcache_get_reg_arg(0, SHR_R0);
        tmp3 = rcache_get_reg(GET_Rn(), RC_GR_READ);
        emith_add_r_r(tmp2, tmp3);
        emit_memhandler_write(op & 3);
        goto end_op;
      case 0x07:
        // MUL.L     Rm,Rn      0000nnnnmmmm0111
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_WRITE);
        emith_mul(tmp3, tmp2, tmp);
        goto end_op;
      case 0x08:
        switch (GET_Fx())
        {
        case 0: // CLRT               0000000000001000
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_bic_r_imm(sr, T);
          break;
        case 1: // SETT               0000000000011000
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_or_r_imm(sr, T);
          break;
        case 2: // CLRMAC             0000000000101000
          emit_move_r_imm32(SHR_MACL, 0);
          emit_move_r_imm32(SHR_MACH, 0);
          break;
        default:
          goto default_;
        }
        goto end_op;
      case 0x09:
        switch (GET_Fx())
        {
        case 0: // NOP        0000000000001001
          break;
        case 1: // DIV0U      0000000000011001
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_bic_r_imm(sr, M|Q|T);
          break;
        case 2: // MOVT Rn    0000nnnn00101001
          sr   = rcache_get_reg(SHR_SR, RC_GR_READ);
          tmp2 = rcache_get_reg(GET_Rn(), RC_GR_WRITE);
          emith_clear_msb(tmp2, sr, 31);
          break;
        default:
          goto default_;
        }
        goto end_op;
      case 0x0a:
        tmp = rcache_get_reg(GET_Rn(), RC_GR_WRITE);
        switch (GET_Fx())
        {
        case 0: // STS      MACH,Rn   0000nnnn00001010
          tmp2 = SHR_MACH;
          break;
        case 1: // STS      MACL,Rn   0000nnnn00011010
          tmp2 = SHR_MACL;
          break;
        case 2: // STS      PR,Rn     0000nnnn00101010
          tmp2 = SHR_PR;
          break;
        default:
          goto default_;
        }
        tmp2 = rcache_get_reg(tmp2, RC_GR_READ);
        emith_move_r_r(tmp, tmp2);
        goto end_op;
      case 0x0c: // MOV.B    @(R0,Rm),Rn      0000nnnnmmmm1100
      case 0x0d: // MOV.W    @(R0,Rm),Rn      0000nnnnmmmm1101
      case 0x0e: // MOV.L    @(R0,Rm),Rn      0000nnnnmmmm1110
        tmp = emit_indirect_indexed_read(SHR_R0, GET_Rm(), op & 3);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_WRITE);
        if ((op & 3) != 2) {
          emith_sext(tmp2, tmp, (op & 1) ? 16 : 8);
        } else
          emith_move_r_r(tmp2, tmp);
        rcache_free_tmp(tmp);
        goto end_op;
      case 0x0f: // MAC.L   @Rm+,@Rn+  0000nnnnmmmm1111
        emit_indirect_read_double(&tmp, &tmp2, GET_Rn(), GET_Rm(), 2);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_RMW);
        /* MS 16 MAC bits unused if saturated */
        sr = rcache_get_reg(SHR_SR, RC_GR_READ);
        emith_tst_r_imm(sr, S);
        EMITH_SJMP_START(DCOND_EQ);
        emith_clear_msb_c(DCOND_NE, tmp4, tmp4, 16);
        EMITH_SJMP_END(DCOND_EQ);
        rcache_unlock(sr);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_RMW); // might evict SR
        emith_mula_s64(tmp3, tmp4, tmp, tmp2);
        rcache_free_tmp(tmp2);
        sr = rcache_get_reg(SHR_SR, RC_GR_READ); // reget just in case
        emith_tst_r_imm(sr, S);

        EMITH_JMP_START(DCOND_EQ);
        emith_asr(tmp, tmp4, 15);
        emith_cmp_r_imm(tmp, -1); // negative overflow (0x80000000..0xffff7fff)
        EMITH_SJMP_START(DCOND_GE);
        emith_move_r_imm_c(DCOND_LT, tmp4, 0x8000);
        emith_move_r_imm_c(DCOND_LT, tmp3, 0x0000);
        EMITH_SJMP_END(DCOND_GE);
        emith_cmp_r_imm(tmp, 0); // positive overflow (0x00008000..0x7fffffff)
        EMITH_SJMP_START(DCOND_LE);
        emith_move_r_imm_c(DCOND_GT, tmp4, 0x00007fff);
        emith_move_r_imm_c(DCOND_GT, tmp3, 0xffffffff);
        EMITH_SJMP_END(DCOND_LE);
        EMITH_JMP_END(DCOND_EQ);

        rcache_free_tmp(tmp);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x01:
      // MOV.L Rm,@(disp,Rn) 0001nnnnmmmmdddd
      rcache_clean();
      tmp  = rcache_get_reg_arg(0, GET_Rn());
      tmp2 = rcache_get_reg_arg(1, GET_Rm());
      if (op & 0x0f)
        emith_add_r_imm(tmp, (op & 0x0f) * 4);
      emit_memhandler_write(2);
      goto end_op;

    case 0x02:
      switch (op & 0x0f)
      {
      case 0x00: // MOV.B Rm,@Rn        0010nnnnmmmm0000
      case 0x01: // MOV.W Rm,@Rn        0010nnnnmmmm0001
      case 0x02: // MOV.L Rm,@Rn        0010nnnnmmmm0010
        rcache_clean();
        rcache_get_reg_arg(0, GET_Rn());
        rcache_get_reg_arg(1, GET_Rm());
        emit_memhandler_write(op & 3);
        goto end_op;
      case 0x04: // MOV.B Rm,@-Rn       0010nnnnmmmm0100
      case 0x05: // MOV.W Rm,@-Rn       0010nnnnmmmm0101
      case 0x06: // MOV.L Rm,@-Rn       0010nnnnmmmm0110
        rcache_get_reg_arg(1, GET_Rm()); // for Rm == Rn
        tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        emith_sub_r_imm(tmp, (1 << (op & 3)));
        rcache_clean();
        rcache_get_reg_arg(0, GET_Rn());
        emit_memhandler_write(op & 3);
        goto end_op;
      case 0x07: // DIV0S Rm,Rn         0010nnnnmmmm0111
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_bic_r_imm(sr, M|Q|T);
        emith_tst_r_imm(tmp2, (1<<31));
        EMITH_SJMP_START(DCOND_EQ);
        emith_or_r_imm_c(DCOND_NE, sr, Q);
        EMITH_SJMP_END(DCOND_EQ);
        emith_tst_r_imm(tmp3, (1<<31));
        EMITH_SJMP_START(DCOND_EQ);
        emith_or_r_imm_c(DCOND_NE, sr, M);
        EMITH_SJMP_END(DCOND_EQ);
        emith_teq_r_r(tmp2, tmp3);
        EMITH_SJMP_START(DCOND_PL);
        emith_or_r_imm_c(DCOND_MI, sr, T);
        EMITH_SJMP_END(DCOND_PL);
        goto end_op;
      case 0x08: // TST Rm,Rn           0010nnnnmmmm1000
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_bic_r_imm(sr, T);
        emith_tst_r_r(tmp2, tmp3);
        emit_or_t_if_eq(sr);
        goto end_op;
      case 0x09: // AND Rm,Rn           0010nnnnmmmm1001
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_and_r_r(tmp, tmp2);
        goto end_op;
      case 0x0a: // XOR Rm,Rn           0010nnnnmmmm1010
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_eor_r_r(tmp, tmp2);
        goto end_op;
      case 0x0b: // OR  Rm,Rn           0010nnnnmmmm1011
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_or_r_r(tmp, tmp2);
        goto end_op;
      case 0x0c: // CMP/STR Rm,Rn       0010nnnnmmmm1100
        tmp  = rcache_get_tmp();
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_eor_r_r_r(tmp, tmp2, tmp3);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        emith_bic_r_imm(sr, T);
        emith_tst_r_imm(tmp, 0x000000ff);
        emit_or_t_if_eq(sr);
        emith_tst_r_imm(tmp, 0x0000ff00);
        emit_or_t_if_eq(sr);
        emith_tst_r_imm(tmp, 0x00ff0000);
        emit_or_t_if_eq(sr);
        emith_tst_r_imm(tmp, 0xff000000);
        emit_or_t_if_eq(sr);
        rcache_free_tmp(tmp);
        goto end_op;
      case 0x0d: // XTRCT  Rm,Rn        0010nnnnmmmm1101
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_lsr(tmp, tmp, 16);
        emith_or_r_r_lsl(tmp, tmp2, 16);
        goto end_op;
      case 0x0e: // MULU.W Rm,Rn        0010nnnnmmmm1110
      case 0x0f: // MULS.W Rm,Rn        0010nnnnmmmm1111
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp  = rcache_get_reg(SHR_MACL, RC_GR_WRITE);
        if (op & 1) {
          emith_sext(tmp, tmp2, 16);
        } else
          emith_clear_msb(tmp, tmp2, 16);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        tmp2 = rcache_get_tmp();
        if (op & 1) {
          emith_sext(tmp2, tmp3, 16);
        } else
          emith_clear_msb(tmp2, tmp3, 16);
        emith_mul(tmp, tmp, tmp2);
        rcache_free_tmp(tmp2);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x03:
      switch (op & 0x0f)
      {
      case 0x00: // CMP/EQ Rm,Rn        0011nnnnmmmm0000
      case 0x02: // CMP/HS Rm,Rn        0011nnnnmmmm0010
      case 0x03: // CMP/GE Rm,Rn        0011nnnnmmmm0011
      case 0x06: // CMP/HI Rm,Rn        0011nnnnmmmm0110
      case 0x07: // CMP/GT Rm,Rn        0011nnnnmmmm0111
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        emith_bic_r_imm(sr, T);
        emith_cmp_r_r(tmp2, tmp3);
        switch (op & 0x07)
        {
        case 0x00: // CMP/EQ
          emit_or_t_if_eq(sr);
          break;
        case 0x02: // CMP/HS
          EMITH_SJMP_START(DCOND_LO);
          emith_or_r_imm_c(DCOND_HS, sr, T);
          EMITH_SJMP_END(DCOND_LO);
          break;
        case 0x03: // CMP/GE
          EMITH_SJMP_START(DCOND_LT);
          emith_or_r_imm_c(DCOND_GE, sr, T);
          EMITH_SJMP_END(DCOND_LT);
          break;
        case 0x06: // CMP/HI
          EMITH_SJMP_START(DCOND_LS);
          emith_or_r_imm_c(DCOND_HI, sr, T);
          EMITH_SJMP_END(DCOND_LS);
          break;
        case 0x07: // CMP/GT
          EMITH_SJMP_START(DCOND_LE);
          emith_or_r_imm_c(DCOND_GT, sr, T);
          EMITH_SJMP_END(DCOND_LE);
          break;
        }
        goto end_op;
      case 0x04: // DIV1    Rm,Rn       0011nnnnmmmm0100
        // Q1 = carry(Rn = (Rn << 1) | T)
        // if Q ^ M
        //   Q2 = carry(Rn += Rm)
        // else
        //   Q2 = carry(Rn -= Rm)
        // Q = M ^ Q1 ^ Q2
        // T = (Q == M) = !(Q ^ M) = !(Q1 ^ Q2)
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        emith_tpop_carry(sr, 0);
        emith_adcf_r_r(tmp2, tmp2);
        emith_tpush_carry(sr, 0);            // keep Q1 in T for now
        tmp4 = rcache_get_tmp();
        emith_and_r_r_imm(tmp4, sr, M);
        emith_eor_r_r_lsr(sr, tmp4, M_SHIFT - Q_SHIFT); // Q ^= M
        rcache_free_tmp(tmp4);
        // add or sub, invert T if carry to get Q1 ^ Q2
        // in: (Q ^ M) passed in Q, Q1 in T
        emith_sh2_div1_step(tmp2, tmp3, sr);
        emith_bic_r_imm(sr, Q);
        emith_tst_r_imm(sr, M);
        EMITH_SJMP_START(DCOND_EQ);
        emith_or_r_imm_c(DCOND_NE, sr, Q);  // Q = M
        EMITH_SJMP_END(DCOND_EQ);
        emith_tst_r_imm(sr, T);
        EMITH_SJMP_START(DCOND_EQ);
        emith_eor_r_imm_c(DCOND_NE, sr, Q); // Q = M ^ Q1 ^ Q2
        EMITH_SJMP_END(DCOND_EQ);
        emith_eor_r_imm(sr, T);             // T = !(Q1 ^ Q2)
        goto end_op;
      case 0x05: // DMULU.L Rm,Rn       0011nnnnmmmm0101
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_WRITE);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_WRITE);
        emith_mul_u64(tmp3, tmp4, tmp, tmp2);
        goto end_op;
      case 0x08: // SUB     Rm,Rn       0011nnnnmmmm1000
      case 0x0c: // ADD     Rm,Rn       0011nnnnmmmm1100
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        if (op & 4) {
          emith_add_r_r(tmp, tmp2);
        } else
          emith_sub_r_r(tmp, tmp2);
        goto end_op;
      case 0x0a: // SUBC    Rm,Rn       0011nnnnmmmm1010
      case 0x0e: // ADDC    Rm,Rn       0011nnnnmmmm1110
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        if (op & 4) { // adc
          emith_tpop_carry(sr, 0);
          emith_adcf_r_r(tmp, tmp2);
          emith_tpush_carry(sr, 0);
        } else {
          emith_tpop_carry(sr, 1);
          emith_sbcf_r_r(tmp, tmp2);
          emith_tpush_carry(sr, 1);
        }
        goto end_op;
      case 0x0b: // SUBV    Rm,Rn       0011nnnnmmmm1011
      case 0x0f: // ADDV    Rm,Rn       0011nnnnmmmm1111
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        emith_bic_r_imm(sr, T);
        if (op & 4) {
          emith_addf_r_r(tmp, tmp2);
        } else
          emith_subf_r_r(tmp, tmp2);
        EMITH_SJMP_START(DCOND_VC);
        emith_or_r_imm_c(DCOND_VS, sr, T);
        EMITH_SJMP_END(DCOND_VC);
        goto end_op;
      case 0x0d: // DMULS.L Rm,Rn       0011nnnnmmmm1101
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_READ);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_WRITE);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_WRITE);
        emith_mul_s64(tmp3, tmp4, tmp, tmp2);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x04:
      switch (op & 0x0f)
      {
      case 0x00:
        switch (GET_Fx())
        {
        case 0: // SHLL Rn    0100nnnn00000000
        case 2: // SHAL Rn    0100nnnn00100000
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_tpop_carry(sr, 0); // dummy
          emith_lslf(tmp, tmp, 1);
          emith_tpush_carry(sr, 0);
          goto end_op;
        case 1: // DT Rn      0100nnnn00010000
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
#if 0 // scheduling needs tuning
          if (FETCH_OP(pc) == 0x8bfd) { // BF #-2
            if (gconst_get(GET_Rn(), &tmp)) {
              // XXX: limit burned cycles
              emit_move_r_imm32(GET_Rn(), 0);
              emith_or_r_imm(sr, T);
              cycles += tmp * 4 + 1; // +1 syncs with noconst version, not sure why
              skip_op = 1;
            }
            else
              emith_sh2_dtbf_loop();
            goto end_op;
          }
#endif
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
          emith_bic_r_imm(sr, T);
          emith_subf_r_imm(tmp, 1);
          emit_or_t_if_eq(sr);
          goto end_op;
        }
        goto default_;
      case 0x01:
        switch (GET_Fx())
        {
        case 0: // SHLR Rn    0100nnnn00000001
        case 2: // SHAR Rn    0100nnnn00100001
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_tpop_carry(sr, 0); // dummy
          if (op & 0x20) {
            emith_asrf(tmp, tmp, 1);
          } else
            emith_lsrf(tmp, tmp, 1);
          emith_tpush_carry(sr, 0);
          goto end_op;
        case 1: // CMP/PZ Rn  0100nnnn00010001
          tmp = rcache_get_reg(GET_Rn(), RC_GR_READ);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_bic_r_imm(sr, T);
          emith_cmp_r_imm(tmp, 0);
          EMITH_SJMP_START(DCOND_LT);
          emith_or_r_imm_c(DCOND_GE, sr, T);
          EMITH_SJMP_END(DCOND_LT);
          goto end_op;
        }
        goto default_;
      case 0x02:
      case 0x03:
        switch (op & 0x3f)
        {
        case 0x02: // STS.L    MACH,@-Rn 0100nnnn00000010
          tmp = SHR_MACH;
          break;
        case 0x12: // STS.L    MACL,@-Rn 0100nnnn00010010
          tmp = SHR_MACL;
          break;
        case 0x22: // STS.L    PR,@-Rn   0100nnnn00100010
          tmp = SHR_PR;
          break;
        case 0x03: // STC.L    SR,@-Rn   0100nnnn00000011
          tmp = SHR_SR;
          break;
        case 0x13: // STC.L    GBR,@-Rn  0100nnnn00010011
          tmp = SHR_GBR;
          break;
        case 0x23: // STC.L    VBR,@-Rn  0100nnnn00100011
          tmp = SHR_VBR;
          break;
        default:
          goto default_;
        }
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        emith_sub_r_imm(tmp2, 4);
        rcache_clean();
        rcache_get_reg_arg(0, GET_Rn());
        tmp3 = rcache_get_reg_arg(1, tmp);
        if (tmp == SHR_SR)
          emith_clear_msb(tmp3, tmp3, 22); // reserved bits defined by ISA as 0
        emit_memhandler_write(2);
        goto end_op;
      case 0x04:
      case 0x05:
        switch (op & 0x3f)
        {
        case 0x04: // ROTL   Rn          0100nnnn00000100
        case 0x05: // ROTR   Rn          0100nnnn00000101
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_tpop_carry(sr, 0); // dummy
          if (op & 1) {
            emith_rorf(tmp, tmp, 1);
          } else
            emith_rolf(tmp, tmp, 1);
          emith_tpush_carry(sr, 0);
          goto end_op;
        case 0x24: // ROTCL  Rn          0100nnnn00100100
        case 0x25: // ROTCR  Rn          0100nnnn00100101
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_tpop_carry(sr, 0);
          if (op & 1) {
            emith_rorcf(tmp);
          } else
            emith_rolcf(tmp);
          emith_tpush_carry(sr, 0);
          goto end_op;
        case 0x15: // CMP/PL Rn          0100nnnn00010101
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_bic_r_imm(sr, T);
          emith_cmp_r_imm(tmp, 0);
          EMITH_SJMP_START(DCOND_LE);
          emith_or_r_imm_c(DCOND_GT, sr, T);
          EMITH_SJMP_END(DCOND_LE);
          goto end_op;
        }
        goto default_;
      case 0x06:
      case 0x07:
        switch (op & 0x3f)
        {
        case 0x06: // LDS.L @Rm+,MACH 0100mmmm00000110
          tmp = SHR_MACH;
          break;
        case 0x16: // LDS.L @Rm+,MACL 0100mmmm00010110
          tmp = SHR_MACL;
          break;
        case 0x26: // LDS.L @Rm+,PR   0100mmmm00100110
          tmp = SHR_PR;
          break;
        case 0x07: // LDC.L @Rm+,SR   0100mmmm00000111
          tmp = SHR_SR;
          break;
        case 0x17: // LDC.L @Rm+,GBR  0100mmmm00010111
          tmp = SHR_GBR;
          break;
        case 0x27: // LDC.L @Rm+,VBR  0100mmmm00100111
          tmp = SHR_VBR;
          break;
        default:
          goto default_;
        }
        rcache_get_reg_arg(0, GET_Rn());
        tmp2 = emit_memhandler_read(2);
        if (tmp == SHR_SR) {
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_write_sr(sr, tmp2);
          drcf.test_irq = 1;
        } else {
          tmp = rcache_get_reg(tmp, RC_GR_WRITE);
          emith_move_r_r(tmp, tmp2);
        }
        rcache_free_tmp(tmp2);
        tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        emith_add_r_imm(tmp, 4);
        goto end_op;
      case 0x08:
      case 0x09:
        switch (GET_Fx())
        {
        case 0:
          // SHLL2 Rn        0100nnnn00001000
          // SHLR2 Rn        0100nnnn00001001
          tmp = 2;
          break;
        case 1:
          // SHLL8 Rn        0100nnnn00011000
          // SHLR8 Rn        0100nnnn00011001
          tmp = 8;
          break;
        case 2:
          // SHLL16 Rn       0100nnnn00101000
          // SHLR16 Rn       0100nnnn00101001
          tmp = 16;
          break;
        default:
          goto default_;
        }
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_RMW);
        if (op & 1) {
          emith_lsr(tmp2, tmp2, tmp);
        } else
          emith_lsl(tmp2, tmp2, tmp);
        goto end_op;
      case 0x0a:
        switch (GET_Fx())
        {
        case 0: // LDS      Rm,MACH   0100mmmm00001010
          tmp2 = SHR_MACH;
          break;
        case 1: // LDS      Rm,MACL   0100mmmm00011010
          tmp2 = SHR_MACL;
          break;
        case 2: // LDS      Rm,PR     0100mmmm00101010
          tmp2 = SHR_PR;
          break;
        default:
          goto default_;
        }
        emit_move_r_r(tmp2, GET_Rn());
        goto end_op;
      case 0x0b:
        switch (GET_Fx())
        {
        case 1: // TAS.B @Rn  0100nnnn00011011
          // XXX: is TAS working on 32X?
          rcache_get_reg_arg(0, GET_Rn());
          tmp = emit_memhandler_read(0);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_bic_r_imm(sr, T);
          emith_cmp_r_imm(tmp, 0);
          emit_or_t_if_eq(sr);
          rcache_clean();
          emith_or_r_imm(tmp, 0x80);
          tmp2 = rcache_get_tmp_arg(1); // assuming it differs to tmp
          emith_move_r_r(tmp2, tmp);
          rcache_free_tmp(tmp);
          rcache_get_reg_arg(0, GET_Rn());
          emit_memhandler_write(0);
          break;
        default:
          goto default_;
        }
        goto end_op;
      case 0x0e:
        tmp = rcache_get_reg(GET_Rn(), RC_GR_READ);
        switch (GET_Fx())
        {
        case 0: // LDC Rm,SR   0100mmmm00001110
          tmp2 = SHR_SR;
          break;
        case 1: // LDC Rm,GBR  0100mmmm00011110
          tmp2 = SHR_GBR;
          break;
        case 2: // LDC Rm,VBR  0100mmmm00101110
          tmp2 = SHR_VBR;
          break;
        default:
          goto default_;
        }
        if (tmp2 == SHR_SR) {
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_write_sr(sr, tmp);
          drcf.test_irq = 1;
        } else {
          tmp2 = rcache_get_reg(tmp2, RC_GR_WRITE);
          emith_move_r_r(tmp2, tmp);
        }
        goto end_op;
      case 0x0f:
        // MAC.W @Rm+,@Rn+  0100nnnnmmmm1111
        emit_indirect_read_double(&tmp, &tmp2, GET_Rn(), GET_Rm(), 1);
        emith_sext(tmp, tmp, 16);
        emith_sext(tmp2, tmp2, 16);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_RMW);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_RMW);
        emith_mula_s64(tmp3, tmp4, tmp, tmp2);
        rcache_free_tmp(tmp2);
        // XXX: MACH should be untouched when S is set?
        sr = rcache_get_reg(SHR_SR, RC_GR_READ);
        emith_tst_r_imm(sr, S);
        EMITH_JMP_START(DCOND_EQ);

        emith_asr(tmp, tmp3, 31);
        emith_eorf_r_r(tmp, tmp4); // tmp = ((signed)macl >> 31) ^ mach
        EMITH_JMP_START(DCOND_EQ);
        emith_move_r_imm(tmp3, 0x80000000);
        emith_tst_r_r(tmp4, tmp4);
        EMITH_SJMP_START(DCOND_MI);
        emith_sub_r_imm_c(DCOND_PL, tmp3, 1); // positive
        EMITH_SJMP_END(DCOND_MI);
        EMITH_JMP_END(DCOND_EQ);

        EMITH_JMP_END(DCOND_EQ);
        rcache_free_tmp(tmp);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x05:
      // MOV.L @(disp,Rm),Rn 0101nnnnmmmmdddd
      emit_memhandler_read_rr(GET_Rn(), GET_Rm(), (op & 0x0f) * 4, 2);
      goto end_op;

    /////////////////////////////////////////////
    case 0x06:
      switch (op & 0x0f)
      {
      case 0x00: // MOV.B @Rm,Rn        0110nnnnmmmm0000
      case 0x01: // MOV.W @Rm,Rn        0110nnnnmmmm0001
      case 0x02: // MOV.L @Rm,Rn        0110nnnnmmmm0010
      case 0x04: // MOV.B @Rm+,Rn       0110nnnnmmmm0100
      case 0x05: // MOV.W @Rm+,Rn       0110nnnnmmmm0101
      case 0x06: // MOV.L @Rm+,Rn       0110nnnnmmmm0110
        emit_memhandler_read_rr(GET_Rn(), GET_Rm(), 0, op & 3);
        if ((op & 7) >= 4 && GET_Rn() != GET_Rm()) {
          tmp = rcache_get_reg(GET_Rm(), RC_GR_RMW);
          emith_add_r_imm(tmp, (1 << (op & 3)));
        }
        goto end_op;
      case 0x03:
      case 0x07 ... 0x0f:
        tmp  = rcache_get_reg(GET_Rm(), RC_GR_READ);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_WRITE);
        switch (op & 0x0f)
        {
        case 0x03: // MOV    Rm,Rn        0110nnnnmmmm0011
          emith_move_r_r(tmp2, tmp);
          break;
        case 0x07: // NOT    Rm,Rn        0110nnnnmmmm0111
          emith_mvn_r_r(tmp2, tmp);
          break;
        case 0x08: // SWAP.B Rm,Rn        0110nnnnmmmm1000
          tmp3 = tmp2;
          if (tmp == tmp2)
            tmp3 = rcache_get_tmp();
          tmp4 = rcache_get_tmp();
          emith_lsr(tmp3, tmp, 16);
          emith_or_r_r_lsl(tmp3, tmp, 24);
          emith_and_r_r_imm(tmp4, tmp, 0xff00);
          emith_or_r_r_lsl(tmp3, tmp4, 8);
          emith_rol(tmp2, tmp3, 16);
          rcache_free_tmp(tmp4);
          if (tmp == tmp2)
            rcache_free_tmp(tmp3);
          break;
        case 0x09: // SWAP.W Rm,Rn        0110nnnnmmmm1001
          emith_rol(tmp2, tmp, 16);
          break;
        case 0x0a: // NEGC   Rm,Rn        0110nnnnmmmm1010
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
          emith_tpop_carry(sr, 1);
          emith_negcf_r_r(tmp2, tmp);
          emith_tpush_carry(sr, 1);
          break;
        case 0x0b: // NEG    Rm,Rn        0110nnnnmmmm1011
          emith_neg_r_r(tmp2, tmp);
          break;
        case 0x0c: // EXTU.B Rm,Rn        0110nnnnmmmm1100
          emith_clear_msb(tmp2, tmp, 24);
          break;
        case 0x0d: // EXTU.W Rm,Rn        0110nnnnmmmm1101
          emith_clear_msb(tmp2, tmp, 16);
          break;
        case 0x0e: // EXTS.B Rm,Rn        0110nnnnmmmm1110
          emith_sext(tmp2, tmp, 8);
          break;
        case 0x0f: // EXTS.W Rm,Rn        0110nnnnmmmm1111
          emith_sext(tmp2, tmp, 16);
          break;
        }
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x07:
      // ADD #imm,Rn  0111nnnniiiiiiii
      tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW);
      if (op & 0x80) { // adding negative
        emith_sub_r_imm(tmp, -op & 0xff);
      } else
        emith_add_r_imm(tmp, op & 0xff);
      goto end_op;

    /////////////////////////////////////////////
    case 0x08:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,Rn)  10000000nnnndddd
      case 0x0100: // MOV.W R0,@(disp,Rn)  10000001nnnndddd
        rcache_clean();
        tmp  = rcache_get_reg_arg(0, GET_Rm());
        tmp2 = rcache_get_reg_arg(1, SHR_R0);
        tmp3 = (op & 0x100) >> 8;
        if (op & 0x0f)
          emith_add_r_imm(tmp, (op & 0x0f) << tmp3);
        emit_memhandler_write(tmp3);
        goto end_op;
      case 0x0400: // MOV.B @(disp,Rm),R0  10000100mmmmdddd
      case 0x0500: // MOV.W @(disp,Rm),R0  10000101mmmmdddd
        tmp = (op & 0x100) >> 8;
        emit_memhandler_read_rr(SHR_R0, GET_Rm(), (op & 0x0f) << tmp, tmp);
        goto end_op;
      case 0x0800: // CMP/EQ #imm,R0       10001000iiiiiiii
        // XXX: could use cmn
        tmp  = rcache_get_tmp();
        tmp2 = rcache_get_reg(0, RC_GR_READ);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW);
        emith_move_r_imm_s8(tmp, op & 0xff);
        emith_bic_r_imm(sr, T);
        emith_cmp_r_r(tmp2, tmp);
        emit_or_t_if_eq(sr);
        rcache_free_tmp(tmp);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x0c:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,GBR)   11000000dddddddd
      case 0x0100: // MOV.W R0,@(disp,GBR)   11000001dddddddd
      case 0x0200: // MOV.L R0,@(disp,GBR)   11000010dddddddd
        rcache_clean();
        tmp  = rcache_get_reg_arg(0, SHR_GBR);
        tmp2 = rcache_get_reg_arg(1, SHR_R0);
        tmp3 = (op & 0x300) >> 8;
        emith_add_r_imm(tmp, (op & 0xff) << tmp3);
        emit_memhandler_write(tmp3);
        goto end_op;
      case 0x0400: // MOV.B @(disp,GBR),R0   11000100dddddddd
      case 0x0500: // MOV.W @(disp,GBR),R0   11000101dddddddd
      case 0x0600: // MOV.L @(disp,GBR),R0   11000110dddddddd
        tmp = (op & 0x300) >> 8;
        emit_memhandler_read_rr(SHR_R0, SHR_GBR, (op & 0xff) << tmp, tmp);
        goto end_op;
      case 0x0300: // TRAPA #imm      11000011iiiiiiii
        tmp = rcache_get_reg(SHR_SP, RC_GR_RMW);
        emith_sub_r_imm(tmp, 4*2);
        // push SR
        tmp = rcache_get_reg_arg(0, SHR_SP);
        emith_add_r_imm(tmp, 4);
        tmp = rcache_get_reg_arg(1, SHR_SR);
        emith_clear_msb(tmp, tmp, 22);
        emit_memhandler_write(2);
        // push PC
        rcache_get_reg_arg(0, SHR_SP);
        tmp = rcache_get_tmp_arg(1);
        emith_move_r_imm(tmp, pc);
        emit_memhandler_write(2);
        // obtain new PC
        emit_memhandler_read_rr(SHR_PC, SHR_VBR, (op & 0xff) * 4, 2);
        // indirect jump -> back to dispatcher
        rcache_flush();
        emith_jump(sh2_drc_dispatcher);
        goto end_op;
      case 0x0800: // TST #imm,R0           11001000iiiiiiii
        tmp = rcache_get_reg(SHR_R0, RC_GR_READ);
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
        emith_bic_r_imm(sr, T);
        emith_tst_r_imm(tmp, op & 0xff);
        emit_or_t_if_eq(sr);
        goto end_op;
      case 0x0900: // AND #imm,R0           11001001iiiiiiii
        tmp = rcache_get_reg(SHR_R0, RC_GR_RMW);
        emith_and_r_imm(tmp, op & 0xff);
        goto end_op;
      case 0x0a00: // XOR #imm,R0           11001010iiiiiiii
        tmp = rcache_get_reg(SHR_R0, RC_GR_RMW);
        emith_eor_r_imm(tmp, op & 0xff);
        goto end_op;
      case 0x0b00: // OR  #imm,R0           11001011iiiiiiii
        tmp = rcache_get_reg(SHR_R0, RC_GR_RMW);
        emith_or_r_imm(tmp, op & 0xff);
        goto end_op;
      case 0x0c00: // TST.B #imm,@(R0,GBR)  11001100iiiiiiii
        tmp = emit_indirect_indexed_read(SHR_R0, SHR_GBR, 0);
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW);
        emith_bic_r_imm(sr, T);
        emith_tst_r_imm(tmp, op & 0xff);
        emit_or_t_if_eq(sr);
        rcache_free_tmp(tmp);
        goto end_op;
      case 0x0d00: // AND.B #imm,@(R0,GBR)  11001101iiiiiiii
        tmp = emit_indirect_indexed_read(SHR_R0, SHR_GBR, 0);
        emith_and_r_imm(tmp, op & 0xff);
        goto end_rmw_op;
      case 0x0e00: // XOR.B #imm,@(R0,GBR)  11001110iiiiiiii
        tmp = emit_indirect_indexed_read(SHR_R0, SHR_GBR, 0);
        emith_eor_r_imm(tmp, op & 0xff);
        goto end_rmw_op;
      case 0x0f00: // OR.B  #imm,@(R0,GBR)  11001111iiiiiiii
        tmp = emit_indirect_indexed_read(SHR_R0, SHR_GBR, 0);
        emith_or_r_imm(tmp, op & 0xff);
      end_rmw_op:
        tmp2 = rcache_get_tmp_arg(1);
        emith_move_r_r(tmp2, tmp);
        rcache_free_tmp(tmp);
        tmp3 = rcache_get_reg_arg(0, SHR_GBR);
        tmp4 = rcache_get_reg(SHR_R0, RC_GR_READ);
        emith_add_r_r(tmp3, tmp4);
        emit_memhandler_write(0);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x0e:
      // MOV #imm,Rn   1110nnnniiiiiiii
      emit_move_r_imm32(GET_Rn(), (u32)(signed int)(signed char)op);
      goto end_op;

    default:
    default_:
      elprintf_sh2(sh2, EL_ANOMALY,
        "drc: illegal op %04x @ %08x", op, pc - 2);

      tmp = rcache_get_reg(SHR_SP, RC_GR_RMW);
      emith_sub_r_imm(tmp, 4*2);
      // push SR
      tmp = rcache_get_reg_arg(0, SHR_SP);
      emith_add_r_imm(tmp, 4);
      tmp = rcache_get_reg_arg(1, SHR_SR);
      emith_clear_msb(tmp, tmp, 22);
      emit_memhandler_write(2);
      // push PC
      rcache_get_reg_arg(0, SHR_SP);
      tmp = rcache_get_tmp_arg(1);
      emith_move_r_imm(tmp, pc - 2);
      emit_memhandler_write(2);
      // obtain new PC
      emit_memhandler_read_rr(SHR_PC, SHR_VBR, 4 * 4, 2);
      // indirect jump -> back to dispatcher
      rcache_flush();
      emith_jump(sh2_drc_dispatcher);
      break;
    }

end_op:
    rcache_unlock_all();

    cycles += opd->cycles;

    if (op_flags[i+1] & OF_DELAY_OP) {
      do_host_disasm(tcache_id);
      continue;
    }

    // test irq?
    if (drcf.test_irq && !drcf.pending_branch_direct) {
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
      FLUSH_CYCLES(sr);
      if (!drcf.pending_branch_indirect)
        emit_move_r_imm32(SHR_PC, pc);
      rcache_flush();
      emith_call(sh2_drc_test_irq);
      drcf.test_irq = 0;
    }

    // branch handling (with/without delay)
    if (drcf.pending_branch_direct)
    {
      struct op_data *opd_b =
        (op_flags[i] & OF_DELAY_OP) ? &ops[i-1] : opd;
      u32 target_pc = opd_b->imm;
      int cond = -1;
      void *target = NULL;

      sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
      FLUSH_CYCLES(sr);

      if (opd_b->op != OP_BRANCH)
        cond = (opd_b->op == OP_BRANCH_CF) ? DCOND_EQ : DCOND_NE;
      if (cond != -1) {
        int ctaken = (op_flags[i] & OF_DELAY_OP) ? 1 : 2;

        if (delay_dep_fw & BITMASK1(SHR_T))
          emith_tst_r_imm(sr, T_save);
        else
          emith_tst_r_imm(sr, T);

        emith_sub_r_imm_c(cond, sr, ctaken<<12);
      }
      rcache_clean();

#if LINK_BRANCHES
      if (find_in_array(branch_target_pc, branch_target_count, target_pc) >= 0)
      {
        // local branch
        // XXX: jumps back can be linked already
        if (branch_patch_count < MAX_LOCAL_BRANCHES) {
          target = tcache_ptr;
          branch_patch_pc[branch_patch_count] = target_pc;
          branch_patch_ptr[branch_patch_count] = target;
          branch_patch_count++;
        }
        else
          dbg(1, "warning: too many local branches");
      }

      if (target == NULL)
#endif
      {
        // can't resolve branch locally, make a block exit
        emit_move_r_imm32(SHR_PC, target_pc);
        rcache_clean();

        target = dr_prepare_ext_branch(target_pc, sh2->is_slave, tcache_id);
        if (target == NULL)
          return NULL;
      }

      if (cond != -1)
        emith_jump_cond_patchable(cond, target);
      else {
        emith_jump_patchable(target);
        rcache_invalidate();
      }

      drcf.pending_branch_direct = 0;
    }
    else if (drcf.pending_branch_indirect) {
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
      FLUSH_CYCLES(sr);
      rcache_flush();
      emith_jump(sh2_drc_dispatcher);
      drcf.pending_branch_indirect = 0;
    }

    do_host_disasm(tcache_id);
  }

  tmp = rcache_get_reg(SHR_SR, RC_GR_RMW);
  FLUSH_CYCLES(tmp);
  rcache_flush();

  // check the last op
  if (op_flags[i-1] & OF_DELAY_OP)
    opd = &ops[i-2];
  else
    opd = &ops[i-1];

  if (opd->op != OP_BRANCH && opd->op != OP_BRANCH_R
      && opd->op != OP_BRANCH_RF && opd->op != OP_RTE)
  {
    void *target;

    emit_move_r_imm32(SHR_PC, pc);
    rcache_flush();

    target = dr_prepare_ext_branch(pc, sh2->is_slave, tcache_id);
    if (target == NULL)
      return NULL;
    emith_jump_patchable(target);
  }

  // link local branches
  for (i = 0; i < branch_patch_count; i++) {
    void *target;
    int t;
    t = find_in_array(branch_target_pc, branch_target_count, branch_patch_pc[i]);
    target = branch_target_ptr[t];
    if (target == NULL) {
      // flush pc and go back to dispatcher (this should no longer happen)
      dbg(1, "stray branch to %08x %p", branch_patch_pc[i], tcache_ptr);
      target = tcache_ptr;
      emit_move_r_imm32(SHR_PC, branch_patch_pc[i]);
      rcache_flush();
      emith_jump(sh2_drc_dispatcher);
    }
    emith_jump_patch(branch_patch_ptr[i], target);
  }

  // mark memory blocks as containing compiled code
  // override any overlay blocks as they become unreachable anyway
  if ((block->addr & 0xc7fc0000) == 0x06000000
      || (block->addr & 0xfffff000) == 0xc0000000)
  {
    u16 *drc_ram_blk = NULL;
    u32 addr, mask = 0, shift = 0;

    if (tcache_id != 0) {
      // data array, BIOS
      drc_ram_blk = Pico32xMem->drcblk_da[sh2->is_slave];
      shift = SH2_DRCBLK_DA_SHIFT;
      mask = 0xfff;
    }
    else {
      // SDRAM
      drc_ram_blk = Pico32xMem->drcblk_ram;
      shift = SH2_DRCBLK_RAM_SHIFT;
      mask = 0x3ffff;
    }

    // mark recompiled insns
    drc_ram_blk[(base_pc & mask) >> shift] = 1;
    for (pc = base_pc; pc < end_pc; pc += 2)
      drc_ram_blk[(pc & mask) >> shift] = 1;

    // mark literals
    for (i = 0; i < literal_addr_count; i++) {
      tmp = literal_addr[i];
      drc_ram_blk[(tmp & mask) >> shift] = 1;
    }

    // add to invalidation lookup lists
    addr = base_pc & ~(INVAL_PAGE_SIZE - 1);
    for (; addr < end_literals; addr += INVAL_PAGE_SIZE) {
      i = (addr & mask) / INVAL_PAGE_SIZE;
      add_to_block_list(&inval_lookup[tcache_id][i], block);
    }
  }

  tcache_ptrs[tcache_id] = tcache_ptr;

  host_instructions_updated(block_entry_ptr, tcache_ptr);

  do_host_disasm(tcache_id);

  if (drcf.literals_disabled && literal_addr_count)
    dbg(1, "literals_disabled && literal_addr_count?");
  dbg(2, " block #%d,%d tcache %d/%d, insns %d -> %d %.3f",
    tcache_id, blkid_main,
    tcache_ptr - tcache_bases[tcache_id], tcache_sizes[tcache_id],
    insns_compiled, host_insn_count, (float)host_insn_count / insns_compiled);
  if ((sh2->pc & 0xc6000000) == 0x02000000) // ROM
    dbg(2, "  hash collisions %d/%d", hash_collisions, block_counts[tcache_id]);
/*
 printf("~~~\n");
 tcache_dsm_ptrs[tcache_id] = block_entry_ptr;
 do_host_disasm(tcache_id);
 printf("~~~\n");
*/

#if (DRC_DEBUG & 4)
  fflush(stdout);
#endif

  return block_entry_ptr;
}

static void sh2_generate_utils(void)
{
  int arg0, arg1, arg2, sr, tmp;

  sh2_drc_write32 = p32x_sh2_write32;
  sh2_drc_read8  = p32x_sh2_read8;
  sh2_drc_read16 = p32x_sh2_read16;
  sh2_drc_read32 = p32x_sh2_read32;

  host_arg2reg(arg0, 0);
  host_arg2reg(arg1, 1);
  host_arg2reg(arg2, 2);
  emith_move_r_r(arg0, arg0); // nop

  // sh2_drc_exit(void)
  sh2_drc_exit = (void *)tcache_ptr;
  emit_do_static_regs(1, arg2);
  emith_sh2_drc_exit();

  // sh2_drc_dispatcher(void)
  sh2_drc_dispatcher = (void *)tcache_ptr;
  sr = rcache_get_reg(SHR_SR, RC_GR_READ);
  emith_cmp_r_imm(sr, 0);
  emith_jump_cond(DCOND_LT, sh2_drc_exit);
  rcache_invalidate();
  emith_ctx_read(arg0, SHR_PC * 4);
  emith_ctx_read(arg1, offsetof(SH2, is_slave));
  emith_add_r_r_imm(arg2, CONTEXT_REG, offsetof(SH2, drc_tmp));
  emith_call(dr_lookup_block);
  emit_block_entry();
  // lookup failed, call sh2_translate()
  emith_move_r_r(arg0, CONTEXT_REG);
  emith_ctx_read(arg1, offsetof(SH2, drc_tmp)); // tcache_id
  emith_call(sh2_translate);
  emit_block_entry();
  // sh2_translate() failed, flush cache and retry
  emith_ctx_read(arg0, offsetof(SH2, drc_tmp));
  emith_call(flush_tcache);
  emith_move_r_r(arg0, CONTEXT_REG);
  emith_ctx_read(arg1, offsetof(SH2, drc_tmp));
  emith_call(sh2_translate);
  emit_block_entry();
  // XXX: can't translate, fail
  emith_call(dr_failure);

  // sh2_drc_test_irq(void)
  // assumes it's called from main function (may jump to dispatcher)
  sh2_drc_test_irq = (void *)tcache_ptr;
  emith_ctx_read(arg1, offsetof(SH2, pending_level));
  sr = rcache_get_reg(SHR_SR, RC_GR_READ);
  emith_lsr(arg0, sr, I_SHIFT);
  emith_and_r_imm(arg0, 0x0f);
  emith_cmp_r_r(arg1, arg0); // pending_level > ((sr >> 4) & 0x0f)?
  EMITH_SJMP_START(DCOND_GT);
  emith_ret_c(DCOND_LE);     // nope, return
  EMITH_SJMP_END(DCOND_GT);
  // adjust SP
  tmp = rcache_get_reg(SHR_SP, RC_GR_RMW);
  emith_sub_r_imm(tmp, 4*2);
  rcache_clean();
  // push SR
  tmp = rcache_get_reg_arg(0, SHR_SP);
  emith_add_r_imm(tmp, 4);
  tmp = rcache_get_reg_arg(1, SHR_SR);
  emith_clear_msb(tmp, tmp, 22);
  emith_move_r_r(arg2, CONTEXT_REG);
  emith_call(p32x_sh2_write32); // XXX: use sh2_drc_write32?
  rcache_invalidate();
  // push PC
  rcache_get_reg_arg(0, SHR_SP);
  emith_ctx_read(arg1, SHR_PC * 4);
  emith_move_r_r(arg2, CONTEXT_REG);
  emith_call(p32x_sh2_write32);
  rcache_invalidate();
  // update I, cycles, do callback
  emith_ctx_read(arg1, offsetof(SH2, pending_level));
  sr = rcache_get_reg(SHR_SR, RC_GR_RMW);
  emith_bic_r_imm(sr, I);
  emith_or_r_r_lsl(sr, arg1, I_SHIFT);
  emith_sub_r_imm(sr, 13 << 12); // at least 13 cycles
  rcache_flush();
  emith_move_r_r(arg0, CONTEXT_REG);
  emith_call_ctx(offsetof(SH2, irq_callback)); // vector = sh2->irq_callback(sh2, level);
  // obtain new PC
  emith_lsl(arg0, arg0, 2);
  emith_ctx_read(arg1, SHR_VBR * 4);
  emith_add_r_r(arg0, arg1);
  emit_memhandler_read(2);
  emith_ctx_write(arg0, SHR_PC * 4);
#ifdef __i386__
  emith_add_r_imm(xSP, 4); // fix stack
#endif
  emith_jump(sh2_drc_dispatcher);
  rcache_invalidate();

  // sh2_drc_entry(SH2 *sh2)
  sh2_drc_entry = (void *)tcache_ptr;
  emith_sh2_drc_entry();
  emith_move_r_r(CONTEXT_REG, arg0); // move ctx, arg0
  emit_do_static_regs(0, arg2);
  emith_call(sh2_drc_test_irq);
  emith_jump(sh2_drc_dispatcher);

  // sh2_drc_write8(u32 a, u32 d)
  sh2_drc_write8 = (void *)tcache_ptr;
  emith_ctx_read(arg2, offsetof(SH2, write8_tab));
  emith_sh2_wcall(arg0, arg2);

  // sh2_drc_write16(u32 a, u32 d)
  sh2_drc_write16 = (void *)tcache_ptr;
  emith_ctx_read(arg2, offsetof(SH2, write16_tab));
  emith_sh2_wcall(arg0, arg2);

#ifdef PDB_NET
  // debug
  #define MAKE_READ_WRAPPER(func) { \
    void *tmp = (void *)tcache_ptr; \
    emith_push_ret(); \
    emith_call(func); \
    emith_ctx_read(arg2, offsetof(SH2, pdb_io_csum[0]));  \
    emith_addf_r_r(arg2, arg0);                           \
    emith_ctx_write(arg2, offsetof(SH2, pdb_io_csum[0])); \
    emith_ctx_read(arg2, offsetof(SH2, pdb_io_csum[1]));  \
    emith_adc_r_imm(arg2, 0x01000000);                    \
    emith_ctx_write(arg2, offsetof(SH2, pdb_io_csum[1])); \
    emith_pop_and_ret(); \
    func = tmp; \
  }
  #define MAKE_WRITE_WRAPPER(func) { \
    void *tmp = (void *)tcache_ptr; \
    emith_ctx_read(arg2, offsetof(SH2, pdb_io_csum[0]));  \
    emith_addf_r_r(arg2, arg1);                           \
    emith_ctx_write(arg2, offsetof(SH2, pdb_io_csum[0])); \
    emith_ctx_read(arg2, offsetof(SH2, pdb_io_csum[1]));  \
    emith_adc_r_imm(arg2, 0x01000000);                    \
    emith_ctx_write(arg2, offsetof(SH2, pdb_io_csum[1])); \
    emith_move_r_r(arg2, CONTEXT_REG);                    \
    emith_jump(func); \
    func = tmp; \
  }

  MAKE_READ_WRAPPER(sh2_drc_read8);
  MAKE_READ_WRAPPER(sh2_drc_read16);
  MAKE_READ_WRAPPER(sh2_drc_read32);
  MAKE_WRITE_WRAPPER(sh2_drc_write8);
  MAKE_WRITE_WRAPPER(sh2_drc_write16);
  MAKE_WRITE_WRAPPER(sh2_drc_write32);
#if (DRC_DEBUG & 4)
  host_dasm_new_symbol(sh2_drc_read8);
  host_dasm_new_symbol(sh2_drc_read16);
  host_dasm_new_symbol(sh2_drc_read32);
  host_dasm_new_symbol(sh2_drc_write32);
#endif
#endif

  rcache_invalidate();
#if (DRC_DEBUG & 4)
  host_dasm_new_symbol(sh2_drc_entry);
  host_dasm_new_symbol(sh2_drc_dispatcher);
  host_dasm_new_symbol(sh2_drc_exit);
  host_dasm_new_symbol(sh2_drc_test_irq);
  host_dasm_new_symbol(sh2_drc_write8);
  host_dasm_new_symbol(sh2_drc_write16);
#endif
}

static void sh2_smc_rm_block_entry(struct block_desc *bd, int tcache_id, u32 ram_mask)
{
  struct block_link *bl, *bl_next, *bl_unresolved;
  u32 i, addr, end_addr;
  void *tmp;

  dbg(2, "  killing entry %08x-%08x-%08x, blkid %d,%d",
    bd->addr, bd->addr + bd->size_nolit, bd->addr + bd->size,
    tcache_id, bd - block_tables[tcache_id]);
  if (bd->addr == 0 || bd->entry_count == 0) {
    dbg(1, "  killing dead block!? %08x", bd->addr);
    return;
  }

  // remove from inval_lookup
  addr = bd->addr & ~(INVAL_PAGE_SIZE - 1);
  end_addr = bd->addr + bd->size;
  for (; addr < end_addr; addr += INVAL_PAGE_SIZE) {
    i = (addr & ram_mask) / INVAL_PAGE_SIZE;
    rm_from_block_list(&inval_lookup[tcache_id][i], bd);
  }

  tmp = tcache_ptr;
  bl_unresolved = unresolved_links[tcache_id];

  // remove from hash table, make incoming links unresolved
  // XXX: maybe patch branches w/flush instead?
  for (i = 0; i < bd->entry_count; i++) {
    rm_from_hashlist(&bd->entryp[i], tcache_id);

    // since we never reuse tcache space of dead blocks,
    // insert jump to dispatcher for blocks that are linked to this
    tcache_ptr = bd->entryp[i].tcache_ptr;
    emit_move_r_imm32(SHR_PC, bd->entryp[i].pc);
    rcache_flush();
    emith_jump(sh2_drc_dispatcher);

    host_instructions_updated(bd->entryp[i].tcache_ptr, tcache_ptr);

    for (bl = bd->entryp[i].links; bl != NULL; ) {
      bl_next = bl->next;
      bl->next = bl_unresolved;
      bl_unresolved = bl;
      bl = bl_next;
    }
  }

  tcache_ptr = tmp;
  unresolved_links[tcache_id] = bl_unresolved;

  bd->addr = bd->size = bd->size_nolit = 0;
  bd->entry_count = 0;
}

static void sh2_smc_rm_block(u32 a, u16 *drc_ram_blk, int tcache_id, u32 shift, u32 mask)
{
  struct block_list **blist = NULL, *entry;
  u32 from = ~0, to = 0, end_addr, taddr, i;
  struct block_desc *block;

  blist = &inval_lookup[tcache_id][(a & mask) / INVAL_PAGE_SIZE];
  entry = *blist;
  while (entry != NULL) {
    block = entry->block;
    end_addr = block->addr + block->size;
    if (block->addr <= a && a < end_addr) {
      // get addr range that includes all removed blocks
      if (from > block->addr)
        from = block->addr;
      if (to < end_addr)
        to = end_addr;

      sh2_smc_rm_block_entry(block, tcache_id, mask);
      if (a >= block->addr + block->size_nolit)
        literal_disabled_frames = 3;

      // entry lost, restart search
      entry = *blist;
      continue;
    }
    entry = entry->next;
  }

  if (from >= to)
    return;

  // update range around a to match latest state
  from &= ~(INVAL_PAGE_SIZE - 1);
  to |= (INVAL_PAGE_SIZE - 1);
  for (taddr = from; taddr < to; taddr += INVAL_PAGE_SIZE) {
    i = (taddr & mask) / INVAL_PAGE_SIZE;
    entry = inval_lookup[tcache_id][i];

    for (; entry != NULL; entry = entry->next) {
      block = entry->block;

      if (block->addr > a) {
        if (to > block->addr)
          to = block->addr;
      }
      else {
        end_addr = block->addr + block->size;
        if (from < end_addr)
          from = end_addr;
      }
    }
  }

  // clear code marks
  if (from < to) {
    u16 *p = drc_ram_blk + ((from & mask) >> shift);
    memset(p, 0, (to - from) >> (shift - 1));
  }
}

void sh2_drc_wcheck_ram(unsigned int a, int val, int cpuid)
{
  dbg(2, "%csh2 smc check @%08x", cpuid ? 's' : 'm', a);
  sh2_smc_rm_block(a, Pico32xMem->drcblk_ram, 0, SH2_DRCBLK_RAM_SHIFT, 0x3ffff);
}

void sh2_drc_wcheck_da(unsigned int a, int val, int cpuid)
{
  dbg(2, "%csh2 smc check @%08x", cpuid ? 's' : 'm', a);
  sh2_smc_rm_block(a, Pico32xMem->drcblk_da[cpuid],
    1 + cpuid, SH2_DRCBLK_DA_SHIFT, 0xfff);
}

int sh2_execute_drc(SH2 *sh2c, int cycles)
{
  int ret_cycles;

  // cycles are kept in SHR_SR unused bits (upper 20)
  // bit11 contains T saved for delay slot
  // others are usual SH2 flags
  sh2c->sr &= 0x3f3;
  sh2c->sr |= cycles << 12;
  sh2_drc_entry(sh2c);

  // TODO: irq cycles
  ret_cycles = (signed int)sh2c->sr >> 12;
  if (ret_cycles > 0)
    dbg(1, "warning: drc returned with cycles: %d", ret_cycles);

  sh2c->sr &= 0x3f3;
  return ret_cycles;
}

#if (DRC_DEBUG & 2)
void block_stats(void)
{
  int c, b, i, total = 0;

  printf("block stats:\n");
  for (b = 0; b < ARRAY_SIZE(block_tables); b++)
    for (i = 0; i < block_counts[b]; i++)
      if (block_tables[b][i].addr != 0)
        total += block_tables[b][i].refcount;

  for (c = 0; c < 10; c++) {
    struct block_desc *blk, *maxb = NULL;
    int max = 0;
    for (b = 0; b < ARRAY_SIZE(block_tables); b++) {
      for (i = 0; i < block_counts[b]; i++) {
        blk = &block_tables[b][i];
        if (blk->addr != 0 && blk->refcount > max) {
          max = blk->refcount;
          maxb = blk;
        }
      }
    }
    if (maxb == NULL)
      break;
    printf("%08x %9d %2.3f%%\n", maxb->addr, maxb->refcount,
      (double)maxb->refcount / total * 100.0);
    maxb->refcount = 0;
  }

  for (b = 0; b < ARRAY_SIZE(block_tables); b++)
    for (i = 0; i < block_counts[b]; i++)
      block_tables[b][i].refcount = 0;
}
#else
#define block_stats()
#endif

void sh2_drc_flush_all(void)
{
  block_stats();
  flush_tcache(0);
  flush_tcache(1);
  flush_tcache(2);
}

void sh2_drc_mem_setup(SH2 *sh2)
{
  // fill the convenience pointers
  sh2->p_bios = sh2->is_slave ? Pico32xMem->sh2_rom_s.w : Pico32xMem->sh2_rom_m.w;
  sh2->p_da = sh2->data_array;
  sh2->p_sdram = Pico32xMem->sdram;
  sh2->p_rom = Pico.rom;
}

void sh2_drc_frame(void)
{
  if (literal_disabled_frames > 0)
    literal_disabled_frames--;
}

int sh2_drc_init(SH2 *sh2)
{
  int i;

  if (block_tables[0] == NULL)
  {
    for (i = 0; i < TCACHE_BUFFERS; i++) {
      block_tables[i] = calloc(block_max_counts[i], sizeof(*block_tables[0]));
      if (block_tables[i] == NULL)
        goto fail;
      // max 2 block links (exits) per block
      block_link_pool[i] = calloc(block_link_pool_max_counts[i],
                          sizeof(*block_link_pool[0]));
      if (block_link_pool[i] == NULL)
        goto fail;

      inval_lookup[i] = calloc(ram_sizes[i] / INVAL_PAGE_SIZE,
                               sizeof(inval_lookup[0]));
      if (inval_lookup[i] == NULL)
        goto fail;

      hash_tables[i] = calloc(hash_table_sizes[i], sizeof(*hash_tables[0]));
      if (hash_tables[i] == NULL)
        goto fail;
    }
    memset(block_counts, 0, sizeof(block_counts));
    memset(block_link_pool_counts, 0, sizeof(block_link_pool_counts));

    drc_cmn_init();
    tcache_ptr = tcache;
    sh2_generate_utils();
    host_instructions_updated(tcache, tcache_ptr);

    tcache_bases[0] = tcache_ptrs[0] = tcache_ptr;
    for (i = 1; i < ARRAY_SIZE(tcache_bases); i++)
      tcache_bases[i] = tcache_ptrs[i] = tcache_bases[i - 1] + tcache_sizes[i - 1];

#if (DRC_DEBUG & 4)
    for (i = 0; i < ARRAY_SIZE(block_tables); i++)
      tcache_dsm_ptrs[i] = tcache_bases[i];
    // disasm the utils
    tcache_dsm_ptrs[0] = tcache;
    do_host_disasm(0);
#endif
#if (DRC_DEBUG & 1)
    hash_collisions = 0;
#endif
  }

  return 0;

fail:
  sh2_drc_finish(sh2);
  return -1;
}

void sh2_drc_finish(SH2 *sh2)
{
  int i;

  if (block_tables[0] == NULL)
    return;

  sh2_drc_flush_all();

  for (i = 0; i < TCACHE_BUFFERS; i++) {
#if (DRC_DEBUG & 4)
    printf("~~~ tcache %d\n", i);
    tcache_dsm_ptrs[i] = tcache_bases[i];
    tcache_ptr = tcache_ptrs[i];
    do_host_disasm(i);
#endif

    if (block_tables[i] != NULL)
      free(block_tables[i]);
    block_tables[i] = NULL;
    if (block_link_pool[i] == NULL)
      free(block_link_pool[i]);
    block_link_pool[i] = NULL;

    if (inval_lookup[i] == NULL)
      free(inval_lookup[i]);
    inval_lookup[i] = NULL;

    if (hash_tables[i] != NULL) {
      free(hash_tables[i]);
      hash_tables[i] = NULL;
    }
  }

  drc_cmn_cleanup();
}

#endif /* DRC_SH2 */

static void *dr_get_pc_base(u32 pc, int is_slave)
{
  void *ret = NULL;
  u32 mask = 0;

  if ((pc & ~0x7ff) == 0) {
    // BIOS
    ret = is_slave ? Pico32xMem->sh2_rom_s.w : Pico32xMem->sh2_rom_m.w;
    mask = 0x7ff;
  }
  else if ((pc & 0xfffff000) == 0xc0000000) {
    // data array
    ret = sh2s[is_slave].data_array;
    mask = 0xfff;
  }
  else if ((pc & 0xc6000000) == 0x06000000) {
    // SDRAM
    ret = Pico32xMem->sdram;
    mask = 0x03ffff;
  }
  else if ((pc & 0xc6000000) == 0x02000000) {
    // ROM
    if ((pc & 0x3fffff) < Pico.romsize)
      ret = Pico.rom;
    mask = 0x3fffff;
  }

  if (ret == NULL)
    return (void *)-1; // NULL is valid value

  return (char *)ret - (pc & ~mask);
}

void scan_block(u32 base_pc, int is_slave, u8 *op_flags, u32 *end_pc_out,
  u32 *end_literals_out)
{
  u16 *dr_pc_base;
  u32 pc, op, tmp;
  u32 end_pc, end_literals = 0;
  u32 lowest_mova = 0;
  struct op_data *opd;
  int next_is_delay = 0;
  int end_block = 0;
  int i, i_end;

  memset(op_flags, 0, BLOCK_INSN_LIMIT);

  dr_pc_base = dr_get_pc_base(base_pc, is_slave);

  // 1st pass: disassemble
  for (i = 0, pc = base_pc; ; i++, pc += 2) {
    // we need an ops[] entry after the last one initialized,
    // so do it before end_block checks
    opd = &ops[i];
    opd->op = OP_UNHANDLED;
    opd->rm = -1;
    opd->source = opd->dest = 0;
    opd->cycles = 1;
    opd->imm = 0;

    if (next_is_delay) {
      op_flags[i] |= OF_DELAY_OP;
      next_is_delay = 0;
    }
    else if (end_block || i >= BLOCK_INSN_LIMIT - 2)
      break;

    op = FETCH_OP(pc);
    switch ((op & 0xf000) >> 12)
    {
    /////////////////////////////////////////////
    case 0x00:
      switch (op & 0x0f)
      {
      case 0x02:
        switch (GET_Fx())
        {
        case 0: // STC SR,Rn  0000nnnn00000010
          tmp = SHR_SR;
          break;
        case 1: // STC GBR,Rn 0000nnnn00010010
          tmp = SHR_GBR;
          break;
        case 2: // STC VBR,Rn 0000nnnn00100010
          tmp = SHR_VBR;
          break;
        default:
          goto undefined;
        }
        opd->op = OP_MOVE;
        opd->source = BITMASK1(tmp);
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x03:
        CHECK_UNHANDLED_BITS(0xd0, undefined);
        // BRAF Rm    0000mmmm00100011
        // BSRF Rm    0000mmmm00000011
        opd->op = OP_BRANCH_RF;
        opd->rm = GET_Rn();
        opd->source = BITMASK1(opd->rm);
        opd->dest = BITMASK1(SHR_PC);
        if (!(op & 0x20))
          opd->dest |= BITMASK1(SHR_PR);
        opd->cycles = 2;
        next_is_delay = 1;
        end_block = 1;
        break;
      case 0x04: // MOV.B Rm,@(R0,Rn)   0000nnnnmmmm0100
      case 0x05: // MOV.W Rm,@(R0,Rn)   0000nnnnmmmm0101
      case 0x06: // MOV.L Rm,@(R0,Rn)   0000nnnnmmmm0110
        opd->source = BITMASK3(GET_Rm(), SHR_R0, GET_Rn());
        break;
      case 0x07:
        // MUL.L     Rm,Rn      0000nnnnmmmm0111
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_MACL);
        opd->cycles = 2;
        break;
      case 0x08:
        CHECK_UNHANDLED_BITS(0xf00, undefined);
        switch (GET_Fx())
        {
        case 0: // CLRT               0000000000001000
          opd->op = OP_SETCLRT;
          opd->dest = BITMASK1(SHR_T);
          opd->imm = 0;
          break;
        case 1: // SETT               0000000000011000
          opd->op = OP_SETCLRT;
          opd->dest = BITMASK1(SHR_T);
          opd->imm = 1;
          break;
        case 2: // CLRMAC             0000000000101000
          opd->dest = BITMASK3(SHR_T, SHR_MACL, SHR_MACH);
          break;
        default:
          goto undefined;
        }
        break;
      case 0x09:
        switch (GET_Fx())
        {
        case 0: // NOP        0000000000001001
          CHECK_UNHANDLED_BITS(0xf00, undefined);
          break;
        case 1: // DIV0U      0000000000011001
          CHECK_UNHANDLED_BITS(0xf00, undefined);
          opd->dest = BITMASK2(SHR_SR, SHR_T);
          break;
        case 2: // MOVT Rn    0000nnnn00101001
          opd->source = BITMASK1(SHR_T);
          opd->dest = BITMASK1(GET_Rn());
          break;
        default:
          goto undefined;
        }
        break;
      case 0x0a:
        switch (GET_Fx())
        {
        case 0: // STS      MACH,Rn   0000nnnn00001010
          tmp = SHR_MACH;
          break;
        case 1: // STS      MACL,Rn   0000nnnn00011010
          tmp = SHR_MACL;
          break;
        case 2: // STS      PR,Rn     0000nnnn00101010
          tmp = SHR_PR;
          break;
        default:
          goto undefined;
        }
        opd->op = OP_MOVE;
        opd->source = BITMASK1(tmp);
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x0b:
        CHECK_UNHANDLED_BITS(0xf00, undefined);
        switch (GET_Fx())
        {
        case 0: // RTS        0000000000001011
          opd->op = OP_BRANCH_R;
          opd->rm = SHR_PR;
          opd->source = BITMASK1(opd->rm);
          opd->dest = BITMASK1(SHR_PC);
          opd->cycles = 2;
          next_is_delay = 1;
          end_block = 1;
          break;
        case 1: // SLEEP      0000000000011011
          opd->op = OP_SLEEP;
          end_block = 1;
          break;
        case 2: // RTE        0000000000101011
          opd->op = OP_RTE;
          opd->source = BITMASK1(SHR_SP);
          opd->dest = BITMASK2(SHR_SR, SHR_PC);
          opd->cycles = 4;
          next_is_delay = 1;
          end_block = 1;
          break;
        default:
          goto undefined;
        }
        break;
      case 0x0c: // MOV.B    @(R0,Rm),Rn      0000nnnnmmmm1100
      case 0x0d: // MOV.W    @(R0,Rm),Rn      0000nnnnmmmm1101
      case 0x0e: // MOV.L    @(R0,Rm),Rn      0000nnnnmmmm1110
        opd->source = BITMASK2(GET_Rm(), SHR_R0);
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x0f: // MAC.L   @Rm+,@Rn+  0000nnnnmmmm1111
        opd->source = BITMASK5(GET_Rm(), GET_Rn(), SHR_SR, SHR_MACL, SHR_MACH);
        opd->dest = BITMASK4(GET_Rm(), GET_Rn(), SHR_MACL, SHR_MACH);
        opd->cycles = 3;
        break;
      default:
        goto undefined;
      }
      break;

    /////////////////////////////////////////////
    case 0x01:
      // MOV.L Rm,@(disp,Rn) 0001nnnnmmmmdddd
      opd->source = BITMASK1(GET_Rm());
      opd->source = BITMASK1(GET_Rn());
      opd->imm = (op & 0x0f) * 4;
      break;

    /////////////////////////////////////////////
    case 0x02:
      switch (op & 0x0f)
      {
      case 0x00: // MOV.B Rm,@Rn        0010nnnnmmmm0000
      case 0x01: // MOV.W Rm,@Rn        0010nnnnmmmm0001
      case 0x02: // MOV.L Rm,@Rn        0010nnnnmmmm0010
        opd->source = BITMASK1(GET_Rm());
        opd->source = BITMASK1(GET_Rn());
        break;
      case 0x04: // MOV.B Rm,@-Rn       0010nnnnmmmm0100
      case 0x05: // MOV.W Rm,@-Rn       0010nnnnmmmm0101
      case 0x06: // MOV.L Rm,@-Rn       0010nnnnmmmm0110
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x07: // DIV0S Rm,Rn         0010nnnnmmmm0111
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_SR);
        break;
      case 0x08: // TST Rm,Rn           0010nnnnmmmm1000
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_T);
        break;
      case 0x09: // AND Rm,Rn           0010nnnnmmmm1001
      case 0x0a: // XOR Rm,Rn           0010nnnnmmmm1010
      case 0x0b: // OR  Rm,Rn           0010nnnnmmmm1011
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x0c: // CMP/STR Rm,Rn       0010nnnnmmmm1100
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_T);
        break;
      case 0x0d: // XTRCT  Rm,Rn        0010nnnnmmmm1101
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x0e: // MULU.W Rm,Rn        0010nnnnmmmm1110
      case 0x0f: // MULS.W Rm,Rn        0010nnnnmmmm1111
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_MACL);
        break;
      default:
        goto undefined;
      }
      break;

    /////////////////////////////////////////////
    case 0x03:
      switch (op & 0x0f)
      {
      case 0x00: // CMP/EQ Rm,Rn        0011nnnnmmmm0000
      case 0x02: // CMP/HS Rm,Rn        0011nnnnmmmm0010
      case 0x03: // CMP/GE Rm,Rn        0011nnnnmmmm0011
      case 0x06: // CMP/HI Rm,Rn        0011nnnnmmmm0110
      case 0x07: // CMP/GT Rm,Rn        0011nnnnmmmm0111
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_T);
        break;
      case 0x04: // DIV1    Rm,Rn       0011nnnnmmmm0100
        opd->source = BITMASK3(GET_Rm(), GET_Rn(), SHR_SR);
        opd->dest = BITMASK2(GET_Rn(), SHR_SR);
        break;
      case 0x05: // DMULU.L Rm,Rn       0011nnnnmmmm0101
      case 0x0d: // DMULS.L Rm,Rn       0011nnnnmmmm1101
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK2(SHR_MACL, SHR_MACH);
        opd->cycles = 2;
        break;
      case 0x08: // SUB     Rm,Rn       0011nnnnmmmm1000
      case 0x0c: // ADD     Rm,Rn       0011nnnnmmmm1100
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x0a: // SUBC    Rm,Rn       0011nnnnmmmm1010
      case 0x0e: // ADDC    Rm,Rn       0011nnnnmmmm1110
        opd->source = BITMASK3(GET_Rm(), GET_Rn(), SHR_T);
        opd->dest = BITMASK2(GET_Rn(), SHR_T);
        break;
      case 0x0b: // SUBV    Rm,Rn       0011nnnnmmmm1011
      case 0x0f: // ADDV    Rm,Rn       0011nnnnmmmm1111
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK2(GET_Rn(), SHR_T);
        break;
      default:
        goto undefined;
      }
      break;

    /////////////////////////////////////////////
    case 0x04:
      switch (op & 0x0f)
      {
      case 0x00:
        switch (GET_Fx())
        {
        case 0: // SHLL Rn    0100nnnn00000000
        case 2: // SHAL Rn    0100nnnn00100000
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK2(GET_Rn(), SHR_T);
          break;
        case 1: // DT Rn      0100nnnn00010000
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK2(GET_Rn(), SHR_T);
          break;
        default:
          goto undefined;
        }
        break;
      case 0x01:
        switch (GET_Fx())
        {
        case 0: // SHLR Rn    0100nnnn00000001
        case 2: // SHAR Rn    0100nnnn00100001
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK2(GET_Rn(), SHR_T);
          break;
        case 1: // CMP/PZ Rn  0100nnnn00010001
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK1(SHR_T);
          break;
        default:
          goto undefined;
        }
        break;
      case 0x02:
      case 0x03:
        switch (op & 0x3f)
        {
        case 0x02: // STS.L    MACH,@-Rn 0100nnnn00000010
          tmp = SHR_MACH;
          break;
        case 0x12: // STS.L    MACL,@-Rn 0100nnnn00010010
          tmp = SHR_MACL;
          break;
        case 0x22: // STS.L    PR,@-Rn   0100nnnn00100010
          tmp = SHR_PR;
          break;
        case 0x03: // STC.L    SR,@-Rn   0100nnnn00000011
          tmp = SHR_SR;
          opd->cycles = 2;
          break;
        case 0x13: // STC.L    GBR,@-Rn  0100nnnn00010011
          tmp = SHR_GBR;
          opd->cycles = 2;
          break;
        case 0x23: // STC.L    VBR,@-Rn  0100nnnn00100011
          tmp = SHR_VBR;
          opd->cycles = 2;
          break;
        default:
          goto undefined;
        }
        opd->source = BITMASK2(GET_Rn(), tmp);
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x04:
      case 0x05:
        switch (op & 0x3f)
        {
        case 0x04: // ROTL   Rn          0100nnnn00000100
        case 0x05: // ROTR   Rn          0100nnnn00000101
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK2(GET_Rn(), SHR_T);
          break;
        case 0x24: // ROTCL  Rn          0100nnnn00100100
        case 0x25: // ROTCR  Rn          0100nnnn00100101
          opd->source = BITMASK2(GET_Rn(), SHR_T);
          opd->dest = BITMASK2(GET_Rn(), SHR_T);
          break;
        case 0x15: // CMP/PL Rn          0100nnnn00010101
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK1(SHR_T);
          break;
        default:
          goto undefined;
        }
        break;
      case 0x06:
      case 0x07:
        switch (op & 0x3f)
        {
        case 0x06: // LDS.L @Rm+,MACH 0100mmmm00000110
          tmp = SHR_MACH;
          break;
        case 0x16: // LDS.L @Rm+,MACL 0100mmmm00010110
          tmp = SHR_MACL;
          break;
        case 0x26: // LDS.L @Rm+,PR   0100mmmm00100110
          tmp = SHR_PR;
          break;
        case 0x07: // LDC.L @Rm+,SR   0100mmmm00000111
          tmp = SHR_SR;
          opd->cycles = 3;
          break;
        case 0x17: // LDC.L @Rm+,GBR  0100mmmm00010111
          tmp = SHR_GBR;
          opd->cycles = 3;
          break;
        case 0x27: // LDC.L @Rm+,VBR  0100mmmm00100111
          tmp = SHR_VBR;
          opd->cycles = 3;
          break;
        default:
          goto undefined;
        }
        opd->source = BITMASK1(GET_Rn());
        opd->dest = BITMASK2(GET_Rn(), tmp);
        break;
      case 0x08:
      case 0x09:
        switch (GET_Fx())
        {
        case 0:
          // SHLL2 Rn        0100nnnn00001000
          // SHLR2 Rn        0100nnnn00001001
          break;
        case 1:
          // SHLL8 Rn        0100nnnn00011000
          // SHLR8 Rn        0100nnnn00011001
          break;
        case 2:
          // SHLL16 Rn       0100nnnn00101000
          // SHLR16 Rn       0100nnnn00101001
          break;
        default:
          goto undefined;
        }
        opd->source = BITMASK1(GET_Rn());
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x0a:
        switch (GET_Fx())
        {
        case 0: // LDS      Rm,MACH   0100mmmm00001010
          tmp = SHR_MACH;
          break;
        case 1: // LDS      Rm,MACL   0100mmmm00011010
          tmp = SHR_MACL;
          break;
        case 2: // LDS      Rm,PR     0100mmmm00101010
          tmp = SHR_PR;
          break;
        default:
          goto undefined;
        }
        opd->op = OP_MOVE;
        opd->source = BITMASK1(GET_Rn());
        opd->dest = BITMASK1(tmp);
        break;
      case 0x0b:
        switch (GET_Fx())
        {
        case 0: // JSR  @Rm   0100mmmm00001011
          opd->dest = BITMASK1(SHR_PR);
        case 2: // JMP  @Rm   0100mmmm00101011
          opd->op = OP_BRANCH_R;
          opd->rm = GET_Rn();
          opd->source = BITMASK1(opd->rm);
          opd->dest |= BITMASK1(SHR_PC);
          opd->cycles = 2;
          next_is_delay = 1;
          end_block = 1;
          break;
        case 1: // TAS.B @Rn  0100nnnn00011011
          opd->source = BITMASK1(GET_Rn());
          opd->dest = BITMASK1(SHR_T);
          opd->cycles = 4;
          break;
        default:
          goto undefined;
        }
        break;
      case 0x0e:
        switch (GET_Fx())
        {
        case 0: // LDC Rm,SR   0100mmmm00001110
          tmp = SHR_SR;
          break;
        case 1: // LDC Rm,GBR  0100mmmm00011110
          tmp = SHR_GBR;
          break;
        case 2: // LDC Rm,VBR  0100mmmm00101110
          tmp = SHR_VBR;
          break;
        default:
          goto undefined;
        }
        opd->op = OP_MOVE;
        opd->source = BITMASK1(GET_Rn());
        opd->dest = BITMASK1(tmp);
        break;
      case 0x0f:
        // MAC.W @Rm+,@Rn+  0100nnnnmmmm1111
        opd->source = BITMASK5(GET_Rm(), GET_Rn(), SHR_SR, SHR_MACL, SHR_MACH);
        opd->dest = BITMASK4(GET_Rm(), GET_Rn(), SHR_MACL, SHR_MACH);
        opd->cycles = 3;
        break;
      default:
        goto undefined;
      }
      break;

    /////////////////////////////////////////////
    case 0x05:
      // MOV.L @(disp,Rm),Rn 0101nnnnmmmmdddd
      opd->source = BITMASK1(GET_Rm());
      opd->dest = BITMASK1(GET_Rn());
      opd->imm = (op & 0x0f) * 4;
      break;

    /////////////////////////////////////////////
    case 0x06:
      switch (op & 0x0f)
      {
      case 0x04: // MOV.B @Rm+,Rn       0110nnnnmmmm0100
      case 0x05: // MOV.W @Rm+,Rn       0110nnnnmmmm0101
      case 0x06: // MOV.L @Rm+,Rn       0110nnnnmmmm0110
        opd->dest = BITMASK1(GET_Rm());
      case 0x00: // MOV.B @Rm,Rn        0110nnnnmmmm0000
      case 0x01: // MOV.W @Rm,Rn        0110nnnnmmmm0001
      case 0x02: // MOV.L @Rm,Rn        0110nnnnmmmm0010
        opd->source = BITMASK1(GET_Rm());
        opd->dest |= BITMASK1(GET_Rn());
        break;
      case 0x0a: // NEGC   Rm,Rn        0110nnnnmmmm1010
        opd->source = BITMASK2(GET_Rm(), SHR_T);
        opd->dest = BITMASK2(GET_Rn(), SHR_T);
        break;
      case 0x03: // MOV    Rm,Rn        0110nnnnmmmm0011
        opd->op = OP_MOVE;
        goto arith_rmrn;
      case 0x07: // NOT    Rm,Rn        0110nnnnmmmm0111
      case 0x08: // SWAP.B Rm,Rn        0110nnnnmmmm1000
      case 0x09: // SWAP.W Rm,Rn        0110nnnnmmmm1001
      case 0x0b: // NEG    Rm,Rn        0110nnnnmmmm1011
      case 0x0c: // EXTU.B Rm,Rn        0110nnnnmmmm1100
      case 0x0d: // EXTU.W Rm,Rn        0110nnnnmmmm1101
      case 0x0e: // EXTS.B Rm,Rn        0110nnnnmmmm1110
      case 0x0f: // EXTS.W Rm,Rn        0110nnnnmmmm1111
      arith_rmrn:
        opd->source = BITMASK1(GET_Rm());
        opd->dest = BITMASK1(GET_Rn());
        break;
      }
      break;

    /////////////////////////////////////////////
    case 0x07:
      // ADD #imm,Rn  0111nnnniiiiiiii
      opd->source = opd->dest = BITMASK1(GET_Rn());
      opd->imm = (int)(signed char)op;
      break;

    /////////////////////////////////////////////
    case 0x08:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,Rn)  10000000nnnndddd
        opd->source = BITMASK2(GET_Rm(), SHR_R0);
        opd->imm = (op & 0x0f);
        break;
      case 0x0100: // MOV.W R0,@(disp,Rn)  10000001nnnndddd
        opd->source = BITMASK2(GET_Rm(), SHR_R0);
        opd->imm = (op & 0x0f) * 2;
        break;
      case 0x0400: // MOV.B @(disp,Rm),R0  10000100mmmmdddd
        opd->source = BITMASK1(GET_Rm());
        opd->dest = BITMASK1(SHR_R0);
        opd->imm = (op & 0x0f);
        break;
      case 0x0500: // MOV.W @(disp,Rm),R0  10000101mmmmdddd
        opd->source = BITMASK1(GET_Rm());
        opd->dest = BITMASK1(SHR_R0);
        opd->imm = (op & 0x0f) * 2;
        break;
      case 0x0800: // CMP/EQ #imm,R0       10001000iiiiiiii
        opd->source = BITMASK1(SHR_R0);
        opd->dest = BITMASK1(SHR_T);
        opd->imm = (int)(signed char)op;
        break;
      case 0x0d00: // BT/S label 10001101dddddddd
      case 0x0f00: // BF/S label 10001111dddddddd
        next_is_delay = 1;
        // fallthrough
      case 0x0900: // BT   label 10001001dddddddd
      case 0x0b00: // BF   label 10001011dddddddd
        opd->op = (op & 0x0200) ? OP_BRANCH_CF : OP_BRANCH_CT;
        opd->source = BITMASK1(SHR_T);
        opd->dest = BITMASK1(SHR_PC);
        opd->imm = ((signed int)(op << 24) >> 23);
        opd->imm += pc + 4;
        if (base_pc <= opd->imm && opd->imm < base_pc + BLOCK_INSN_LIMIT * 2)
          op_flags[(opd->imm - base_pc) / 2] |= OF_BTARGET;
        break;
      default:
        goto undefined;
      }
      break;

    /////////////////////////////////////////////
    case 0x09:
      // MOV.W @(disp,PC),Rn  1001nnnndddddddd
      opd->op = OP_LOAD_POOL;
      tmp = pc + 2;
      if (op_flags[i] & OF_DELAY_OP) {
        if (ops[i-1].op == OP_BRANCH)
          tmp = ops[i-1].imm;
        else
          tmp = 0;
      }
      opd->source = BITMASK1(SHR_PC);
      opd->dest = BITMASK1(GET_Rn());
      if (tmp)
        opd->imm = tmp + 2 + (op & 0xff) * 2;
      opd->size = 1;
      break;

    /////////////////////////////////////////////
    case 0x0b:
      // BSR  label 1011dddddddddddd
      opd->dest = BITMASK1(SHR_PR);
    case 0x0a:
      // BRA  label 1010dddddddddddd
      opd->op = OP_BRANCH;
      opd->dest |= BITMASK1(SHR_PC);
      opd->imm = ((signed int)(op << 20) >> 19);
      opd->imm += pc + 4;
      opd->cycles = 2;
      next_is_delay = 1;
      end_block = 1;
      if (base_pc <= opd->imm && opd->imm < base_pc + BLOCK_INSN_LIMIT * 2)
        op_flags[(opd->imm - base_pc) / 2] |= OF_BTARGET;
      break;

    /////////////////////////////////////////////
    case 0x0c:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,GBR)   11000000dddddddd
      case 0x0100: // MOV.W R0,@(disp,GBR)   11000001dddddddd
      case 0x0200: // MOV.L R0,@(disp,GBR)   11000010dddddddd
        opd->source = BITMASK2(SHR_GBR, SHR_R0);
        opd->size = (op & 0x300) >> 8;
        opd->imm = (op & 0xff) << opd->size;
        break;
      case 0x0400: // MOV.B @(disp,GBR),R0   11000100dddddddd
      case 0x0500: // MOV.W @(disp,GBR),R0   11000101dddddddd
      case 0x0600: // MOV.L @(disp,GBR),R0   11000110dddddddd
        opd->source = BITMASK1(SHR_GBR);
        opd->dest = BITMASK1(SHR_R0);
        opd->size = (op & 0x300) >> 8;
        opd->imm = (op & 0xff) << opd->size;
        break;
      case 0x0300: // TRAPA #imm      11000011iiiiiiii
        opd->source = BITMASK2(SHR_PC, SHR_SR);
        opd->dest = BITMASK1(SHR_PC);
        opd->imm = (op & 0xff) * 4;
        opd->cycles = 8;
        end_block = 1; // FIXME
        break;
      case 0x0700: // MOVA @(disp,PC),R0    11000111dddddddd
        opd->op = OP_MOVA;
        tmp = pc + 2;
        if (op_flags[i] & OF_DELAY_OP) {
          if (ops[i-1].op == OP_BRANCH)
            tmp = ops[i-1].imm;
          else
            tmp = 0;
        }
        opd->dest = BITMASK1(SHR_R0);
        if (tmp) {
          opd->imm = (tmp + 2 + (op & 0xff) * 4) & ~3;
          if (opd->imm >= base_pc) {
            if (lowest_mova == 0 || opd->imm < lowest_mova)
              lowest_mova = opd->imm;
          }
        }
        break;
      case 0x0800: // TST #imm,R0           11001000iiiiiiii
        opd->source = BITMASK1(SHR_R0);
        opd->dest = BITMASK1(SHR_T);
        opd->imm = op & 0xff;
        break;
      case 0x0900: // AND #imm,R0           11001001iiiiiiii
        opd->source = opd->dest = BITMASK1(SHR_R0);
        opd->imm = op & 0xff;
        break;
      case 0x0a00: // XOR #imm,R0           11001010iiiiiiii
        opd->source = opd->dest = BITMASK1(SHR_R0);
        opd->imm = op & 0xff;
        break;
      case 0x0b00: // OR  #imm,R0           11001011iiiiiiii
        opd->source = opd->dest = BITMASK1(SHR_R0);
        opd->imm = op & 0xff;
        break;
      case 0x0c00: // TST.B #imm,@(R0,GBR)  11001100iiiiiiii
        opd->source = BITMASK2(SHR_GBR, SHR_R0);
        opd->dest = BITMASK1(SHR_T);
        opd->imm = op & 0xff;
        opd->cycles = 3;
        break;
      case 0x0d00: // AND.B #imm,@(R0,GBR)  11001101iiiiiiii
      case 0x0e00: // XOR.B #imm,@(R0,GBR)  11001110iiiiiiii
      case 0x0f00: // OR.B  #imm,@(R0,GBR)  11001111iiiiiiii
        opd->source = BITMASK2(SHR_GBR, SHR_R0);
        opd->imm = op & 0xff;
        opd->cycles = 3;
        break;
      default:
        goto undefined;
      }
      break;

    /////////////////////////////////////////////
    case 0x0d:
      // MOV.L @(disp,PC),Rn  1101nnnndddddddd
      opd->op = OP_LOAD_POOL;
      tmp = pc + 2;
      if (op_flags[i] & OF_DELAY_OP) {
        if (ops[i-1].op == OP_BRANCH)
          tmp = ops[i-1].imm;
        else
          tmp = 0;
      }
      opd->source = BITMASK1(SHR_PC);
      opd->dest = BITMASK1(GET_Rn());
      if (tmp)
        opd->imm = (tmp + 2 + (op & 0xff) * 4) & ~3;
      opd->size = 2;
      break;

    /////////////////////////////////////////////
    case 0x0e:
      // MOV #imm,Rn   1110nnnniiiiiiii
      opd->dest = BITMASK1(GET_Rn());
      opd->imm = (u32)(signed int)(signed char)op;
      break;

    default:
    undefined:
      elprintf(EL_ANOMALY, "%csh2 drc: unhandled op %04x @ %08x",
        is_slave ? 's' : 'm', op, pc);
      break;
    }
  }
  i_end = i;
  end_pc = pc;

  // 2nd pass: some analysis
  for (i = 0; i < i_end; i++) {
    opd = &ops[i];

    // propagate T (TODO: DIV0U)
    if ((opd->op == OP_SETCLRT && !opd->imm) || opd->op == OP_BRANCH_CT)
      op_flags[i + 1] |= OF_T_CLEAR;
    else if ((opd->op == OP_SETCLRT && opd->imm) || opd->op == OP_BRANCH_CF)
      op_flags[i + 1] |= OF_T_SET;

    if ((op_flags[i] & OF_BTARGET) || (opd->dest & BITMASK1(SHR_T)))
      op_flags[i] &= ~(OF_T_SET | OF_T_CLEAR);
    else
      op_flags[i + 1] |= op_flags[i] & (OF_T_SET | OF_T_CLEAR);

    if ((opd->op == OP_BRANCH_CT && (op_flags[i] & OF_T_SET))
        || (opd->op == OP_BRANCH_CF && (op_flags[i] & OF_T_CLEAR)))
    {
      opd->op = OP_BRANCH;
      opd->cycles = 3;
      i_end = i + 1;
      if (op_flags[i + 1] & OF_DELAY_OP) {
        opd->cycles = 2;
        i_end++;
      }
    }
    else if (opd->op == OP_LOAD_POOL)
    {
      if (opd->imm < end_pc + MAX_LITERAL_OFFSET) {
        if (end_literals < opd->imm + opd->size * 2)
          end_literals = opd->imm + opd->size * 2;
      }
    }
  }
  end_pc = base_pc + i_end * 2;
  if (end_literals < end_pc)
    end_literals = end_pc;

  // end_literals is used to decide to inline a literal or not
  // XXX: need better detection if this actually is used in write
  if (lowest_mova >= base_pc) {
    if (lowest_mova < end_literals) {
      dbg(1, "mova for %08x, block %08x", lowest_mova, base_pc);
      end_literals = end_pc;
    }
    if (lowest_mova < end_pc) {
      dbg(1, "warning: mova inside of blk for %08x, block %08x",
        lowest_mova, base_pc);
      end_literals = end_pc;
    }
  }

  *end_pc_out = end_pc;
  if (end_literals_out != NULL)
    *end_literals_out = end_literals;
}

// vim:shiftwidth=2:ts=2:expandtab
