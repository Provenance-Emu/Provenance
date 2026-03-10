/*
 * SH2 recompiler
 * (C) notaz, 2009,2010,2013
 * (C) irixxxx, 2018-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * notes:
 * - tcache, block descriptor, block entry buffer overflows result in oldest
 *   blocks being deleted until enough space is available
 * - link and list element buffer overflows result in failure and exit
 * - jumps between blocks are tracked for SMC handling (in block_entry->links),
 *   except jumps from global to CPU-local tcaches
 *
 * implemented:
 * - static register allocation
 * - remaining register caching and tracking in temporaries
 * - block-local branch linking
 * - block linking
 * - some constant propagation
 * - call stack caching for host block entry address
 * - delay, poll, and idle loop detection and handling
 * - some T/M flag optimizations where the value is known or isn't used
 *
 * TODO:
 * - better constant propagation
 * - bug fixing
 */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include <pico/pico_int.h>
#include <pico/arm_features.h>
#include "sh2.h"
#include "compiler.h"
#include "../drc/cmn.h"
#include "../debug.h"

// features
#define PROPAGATE_CONSTANTS     1
#define LINK_BRANCHES           1
#define BRANCH_CACHE            1
#define CALL_STACK              1
#define ALIAS_REGISTERS         1
#define REMAP_REGISTER          1
#define LOOP_DETECTION          1
#define LOOP_OPTIMIZER          1
#define T_OPTIMIZER             1
#define DIV_OPTIMIZER           1

#define MAX_LITERAL_OFFSET      0x200	// max. MOVA, MOV @(PC) offset
#define MAX_LOCAL_TARGETS       (BLOCK_INSN_LIMIT / 4)
#define MAX_LOCAL_BRANCHES      (BLOCK_INSN_LIMIT / 2)

// debug stuff
// 01 - warnings/errors
// 02 - block info/smc
// 04 - asm
// 08 - runtime block entry log
// 10 - smc self-check
// 20 - runtime block entry counter
// 40 - rcache checking
// 80 - branch cache statistics
// 100 - write trace
// 200 - compare trace
// 400 - block entry backtrace on exit
// 800 - state dump on exit
#ifndef DRC_DEBUG
#define DRC_DEBUG 0//x847
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

#define T	0x00000001
#define S	0x00000002
#define I	0x000000f0
#define Q	0x00000100
#define M	0x00000200
#define T_save	0x00000800

#define I_SHIFT 4
#define Q_SHIFT 8
#define M_SHIFT 9
#define T_SHIFT 11

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
  OP_BRANCH_N,  // conditional known not to be taken
  OP_BRANCH_CT, // conditional, branch if T set
  OP_BRANCH_CF, // conditional, branch if T clear
  OP_BRANCH_R,  // indirect
  OP_BRANCH_RF, // indirect far (PC + Rm)
  OP_SETCLRT,   // T flag set/clear
  OP_MOVE,      // register move
  OP_LOAD_CONST,// load const to register
  OP_LOAD_POOL, // literal pool load, imm is address
  OP_MOVA,      // MOVA instruction
  OP_SLEEP,     // SLEEP instruction
  OP_RTE,       // RTE instruction
  OP_TRAPA,     // TRAPA instruction
  OP_LDC,       // LDC instruction
  OP_DIV0,      // DIV0[US] instruction
  OP_UNDEFINED,
};

struct div {
  u32 state:1;          // 0: expect DIV1/ROTCL, 1: expect DIV1
  u32 rn:5, rm:5, ro:5; // rn and rm for DIV1, ro for ROTCL
  u32 div1:8, rotcl:8;  // DIV1 count, ROTCL count
};
union _div { u32 imm; struct div div; };  // XXX tut-tut type punning...
#define div(opd)	((union _div *)&((opd)->imm))->div

// XXX consider trap insns: OP_TRAPA, OP_UNDEFINED?
#define OP_ISBRANCH(op) ((BITRANGE(OP_BRANCH, OP_BRANCH_RF)| BITMASK1(OP_RTE)) \
                                & BITMASK1(op))
#define OP_ISBRAUC(op) (BITMASK4(OP_BRANCH, OP_BRANCH_R, OP_BRANCH_RF, OP_RTE) \
                                & BITMASK1(op))
#define OP_ISBRACND(op) (BITMASK2(OP_BRANCH_CT, OP_BRANCH_CF) \
                                & BITMASK1(op))
#define OP_ISBRAIMM(op) (BITMASK3(OP_BRANCH, OP_BRANCH_CT, OP_BRANCH_CF) \
                                & BITMASK1(op))
#define OP_ISBRAIND(op) (BITMASK3(OP_BRANCH_R, OP_BRANCH_RF, OP_RTE) \
                                & BITMASK1(op))

#ifdef DRC_SH2

#if (DRC_DEBUG & 4)
static u8 *tcache_dsm_ptrs[3];
static char sh2dasm_buff[64];
#define do_host_disasm(tcid) \
  host_dasm(tcache_dsm_ptrs[tcid], emith_insn_ptr() - tcache_dsm_ptrs[tcid]); \
  tcache_dsm_ptrs[tcid] = emith_insn_ptr()
#else
#define do_host_disasm(x)
#endif

#define SH2_DUMP(sh2, reason) { \
	char ms = (sh2)->is_slave ? 's' : 'm'; \
	printf("%csh2 %s %08lx\n", ms, reason, (ulong)(sh2)->pc); \
	printf("%csh2 r0-7  %08lx %08lx %08lx %08lx %08lx %08lx %08lx %08lx\n", ms, \
		(ulong)(sh2)->r[0], (ulong)(sh2)->r[1], (ulong)(sh2)->r[2], (ulong)(sh2)->r[3], \
		(ulong)(sh2)->r[4], (ulong)(sh2)->r[5], (ulong)(sh2)->r[6], (ulong)(sh2)->r[7]); \
	printf("%csh2 r8-15 %08lx %08lx %08lx %08lx %08lx %08lx %08lx %08lx\n", ms, \
		(ulong)(sh2)->r[8], (ulong)(sh2)->r[9], (ulong)(sh2)->r[10], (ulong)(sh2)->r[11], \
		(ulong)(sh2)->r[12], (ulong)(sh2)->r[13], (ulong)(sh2)->r[14], (ulong)(sh2)->r[15]); \
	printf("%csh2 pc-ml %08lx %08lx %08lx %08lx %08lx %08lx %08lx %08lx\n", ms, \
		(ulong)(sh2)->pc, (ulong)(sh2)->ppc, (ulong)(sh2)->pr, (ulong)(sh2)->sr, \
		(ulong)(sh2)->gbr, (ulong)(sh2)->vbr, (ulong)(sh2)->mach, (ulong)(sh2)->macl); \
	printf("%csh2 tmp-p  %08x %08x %08x %08x %08x %08lx %08x %08x\n", ms, \
		(sh2)->drc_tmp, (sh2)->irq_cycles, \
		(sh2)->pdb_io_csum[0], (sh2)->pdb_io_csum[1], (sh2)->state, \
		(ulong)(sh2)->poll_addr, (sh2)->poll_cycles, (sh2)->poll_cnt); \
}

#if (DRC_DEBUG & (256|512|1024))
static SH2 csh2[2][8];
static FILE *trace[2];
static int topen[2];
#endif
#if (DRC_DEBUG & 8)
static u32 lastpc, lastcnt;
static void *lastblock;
#endif
#if (DRC_DEBUG & (8|256|512|1024)) || defined(PDB)
static void REGPARM(3) *sh2_drc_log_entry(void *block, SH2 *sh2, u32 sr)
{
  if (block != NULL) {
#if defined PDB
    dbg(8, "= %csh2 enter %08x %p, c=%d", sh2->is_slave?'s':'m',
      sh2->pc, block, ((signed int)sr >> 12)+1);
    pdb_step(sh2, sh2->pc);
#elif (DRC_DEBUG & 8)
    if (lastpc != sh2->pc) {
      if (lastcnt)
        dbg(8, "= %csh2 enter %08x %p (%d times), c=%d", sh2->is_slave?'s':'m',
          lastpc, lastblock, lastcnt, (signed int)sr >> 12);
      dbg(8, "= %csh2 enter %08x %p, c=%d", sh2->is_slave?'s':'m',
        sh2->pc, block, (signed int)sr >> 12);
      lastpc = sh2->pc;
      lastblock = block;
      lastcnt = 0;
    } else
      lastcnt++;
#elif (DRC_DEBUG & 256)
  {
    static SH2 fsh2;
    int idx = sh2->is_slave;
    if (!trace[0] && !topen[0]++) {
      trace[0] = fopen("pico.trace0", "wb");
      trace[1] = fopen("pico.trace1", "wb");
    }
    if (trace[idx] && csh2[idx][0].pc != sh2->pc) {
      fwrite(sh2, offsetof(SH2, read8_map), 1, trace[idx]);
      fwrite(&sh2->pdb_io_csum, sizeof(sh2->pdb_io_csum), 1, trace[idx]);
      memcpy(&csh2[idx][0], sh2, offsetof(SH2, poll_cnt)+4);
      csh2[idx][0].is_slave = idx;
    }
  }
#elif (DRC_DEBUG & 512)
  {
    static SH2 fsh2;
    int idx = sh2->is_slave;
    if (!trace[0] && !topen[0]++) {
      trace[0] = fopen("pico.trace0", "rb");
      trace[1] = fopen("pico.trace1", "rb");
    }
    if (trace[idx] && csh2[idx][0].pc != sh2->pc) {
      if (!fread(&fsh2, offsetof(SH2, read8_map), 1, trace[idx]) ||
          !fread(&fsh2.pdb_io_csum, sizeof(sh2->pdb_io_csum), 1, trace[idx])) {
        printf("trace eof at %08lx\n",ftell(trace[idx]));
        exit(1);
      }
      fsh2.sr = (fsh2.sr & 0x3ff) | (sh2->sr & ~0x3ff);
      fsh2.is_slave = idx;
      if (memcmp(&fsh2, sh2, offsetof(SH2, read8_map)) ||
          0)//memcmp(&fsh2.pdb_io_csum, &sh2->pdb_io_csum, sizeof(sh2->pdb_io_csum)))
      {
        printf("difference at %08lx!\n",ftell(trace[idx]));
        SH2_DUMP(&fsh2, "file");
        SH2_DUMP(sh2, "current");
        SH2_DUMP(&csh2[idx][0], "previous");
        SH2_DUMP(&csh2[idx][1], "previous");
	char *ps = (char *)sh2, *pf = (char *)&fsh2;
	for (idx = 0; idx < offsetof(SH2, read8_map); idx += sizeof(u32))
		if (*(u32 *)(ps+idx) != *(u32 *)(pf+idx))
			printf("diff reg %ld\n",(long)idx/sizeof(u32));
        exit(1);
      }
      memcpy(&csh2[idx][1], &csh2[idx][0], offsetof(SH2, poll_cnt)+4);
      csh2[idx][0] = fsh2;
    }
  }
#elif (DRC_DEBUG & 1024)
  {
    int x = sh2->is_slave, i;
    for (i = 0; i < ARRAY_SIZE(csh2[x])-1; i++)
      memcpy(&csh2[x][i], &csh2[x][i+1], offsetof(SH2, poll_cnt)+4);
    memcpy(&csh2[x][ARRAY_SIZE(csh2[x])-1], sh2, offsetof(SH2, poll_cnt)+4);
    csh2[x][0].is_slave = x;
  }
#endif
  }
  return block;
}
#endif


// we have 3 translation cache buffers, split from one drc/cmn buffer.
// BIOS shares tcache with data array because it's only used for init
// and can be discarded early
#define TCACHE_BUFFERS 3


struct ring_buffer {
  u8 *base;                  // ring buffer memory
  unsigned item_sz;          // size of one buffer item
  unsigned size;             // number of itmes in ring
  int first, next;           // read and write pointers
  int used;                  // number of used items in ring
};

enum { BL_JMP=1, BL_LDJMP, BL_JCCBLX };
struct block_link {
  short tcache_id;
  short type;                // BL_JMP et al
  u32 target_pc;
  void *jump;                // insn address
  void *blx;                 // block link/exit  area if any
  u8 jdisp[12];              // jump backup buffer
  struct block_link *next;   // either in block_entry->links or unresolved
  struct block_link *o_next; //     ...in block_entry->o_links
  struct block_link *prev;
  struct block_link *o_prev;
  struct block_entry *target;// target block this is linked in (be->links)
};

struct block_entry {
  u32 pc;
  u8 *tcache_ptr;            // translated block for above PC
  struct block_entry *next;  // chain in hash_table with same pc hash
  struct block_entry *prev;
  struct block_link *links;  // incoming links to this entry
  struct block_link *o_links;// outgoing links from this entry
#if (DRC_DEBUG & 2)
  struct block_desc *block;
#endif
#if (DRC_DEBUG & 32)
  int entry_count;
#endif
};

struct block_desc {
  u32 addr;                  // block start SH2 PC address
  u32 addr_lit;              // block start SH2 literal pool addr
  int size;                  // ..of recompiled insns
  int size_lit;              // ..of (insns+)literal pool
  u8 *tcache_ptr;            // start address of block in cache
  u16 crc;                   // crc of insns and literals
  u16 active;                // actively used or deactivated?
  struct block_list *list;
#if (DRC_DEBUG & 2)
  int refcount;
#endif
  int entry_count;
  struct block_entry *entryp;
};

struct block_list {
  struct block_desc *block;  // block reference
  struct block_list *next;   // pointers for doubly linked list
  struct block_list *prev;
  struct block_list **head;  // list head (for removing from list)
  struct block_list *l_next;
};

static u8 *tcache_ptr;       // ptr for code emitters

// XXX: need to tune sizes

static struct ring_buffer tcache_ring[TCACHE_BUFFERS];
static const int tcache_sizes[TCACHE_BUFFERS] = {
  DRC_TCACHE_SIZE * 30 / 32, // ROM (rarely used), DRAM
  DRC_TCACHE_SIZE / 32, // BIOS, data array in master sh2
  DRC_TCACHE_SIZE / 32, // ... slave
};

#define BLOCK_MAX_COUNT(tcid)		((tcid) ? 256 : 32*256)
static struct ring_buffer block_ring[TCACHE_BUFFERS];
static struct block_desc *block_tables[TCACHE_BUFFERS];

#define ENTRY_MAX_COUNT(tcid)		((tcid) ? 8*512 : 256*512)
static struct ring_buffer entry_ring[TCACHE_BUFFERS];
static struct block_entry *entry_tables[TCACHE_BUFFERS];

// we have block_link_pool to avoid using mallocs
#define BLOCK_LINK_MAX_COUNT(tcid)	((tcid) ? 512 : 32*512)
static struct block_link *block_link_pool[TCACHE_BUFFERS]; 
static int block_link_pool_counts[TCACHE_BUFFERS];
static struct block_link **unresolved_links[TCACHE_BUFFERS];
static struct block_link *blink_free[TCACHE_BUFFERS];

// used for invalidation
#define RAM_SIZE(tcid) 			((tcid) ? 0x1000 : 0x40000)
#define INVAL_PAGE_SIZE 0x100

static struct block_list *inactive_blocks[TCACHE_BUFFERS];

// array of pointers to block_lists for RAM and 2 data arrays
// each array has len: sizeof(mem) / INVAL_PAGE_SIZE 
static struct block_list **inval_lookup[TCACHE_BUFFERS];

#define HASH_TABLE_SIZE(tcid)		((tcid) ? 512 : 32*512)
static struct block_entry **hash_tables[TCACHE_BUFFERS];

#define HASH_FUNC(hash_tab, addr, mask) \
  (hash_tab)[((addr) >> 1) & (mask)]

#define BLOCK_LIST_MAX_COUNT		(64*1024)
static struct block_list *block_list_pool; 
static int block_list_pool_count;
static struct block_list *blist_free;

#if (DRC_DEBUG & 128)
#if BRANCH_CACHE
int bchit, bcmiss;
#endif
#if CALL_STACK
int rchit, rcmiss;
#endif
#endif

// host register tracking
enum cache_reg_htype {
  HRT_TEMP   = 1, // is for temps and args
  HRT_REG    = 2, // is for sh2 regs
};

enum cache_reg_flags {
  HRF_DIRTY  = 1 << 0, // has "dirty" value to be written to ctx
  HRF_PINNED = 1 << 1, // has a pinned mapping
  HRF_S16    = 1 << 2, // has a sign extended 16 bit value
  HRF_U16    = 1 << 3, // has a zero extended 16 bit value
};

enum cache_reg_type {
  HR_FREE,
  HR_CACHED, // vreg has sh2_reg_e
  HR_TEMP,   // reg used for temp storage
};

typedef struct {
  u8 hreg:6;    // "host" reg
  u8 htype:2;   // TEMP or REG?
  u8 flags:4;   // DIRTY, PINNED?
  u8 type:2;    // CACHED or TEMP?
  u8 locked:2;  // LOCKED reference counter
  u16 stamp;    // kind of a timestamp
  u32 gregs;    // "guest" reg mask
} cache_reg_t;

// guest register tracking
enum guest_reg_flags {
  GRF_DIRTY  = 1 << 0, // reg has "dirty" value to be written to ctx
  GRF_CONST  = 1 << 1, // reg has a constant
  GRF_CDIRTY = 1 << 2, // constant not yet written to ctx
  GRF_STATIC = 1 << 3, // reg has static mapping to vreg
  GRF_PINNED = 1 << 4, // reg has pinned mapping to vreg
};

typedef struct {
  u8 flags;     // guest flags: is constant, is dirty?
  s8 sreg;      // cache reg for static mapping
  s8 vreg;      // cache_reg this is currently mapped to, -1 if not mapped
  s8 cnst;      // const index if this is constant
} guest_reg_t;


// possibly needed in code emitter
static int rcache_get_tmp(void);
static void rcache_free_tmp(int hr);

// Note: Register assignment goes by ABI convention. Caller save registers are
// TEMPORARY, callee save registers are PRESERVED. Unusable regs are omitted.
// there must be at least the free (not context or statically mapped) amount of
// PRESERVED/TEMPORARY registers used by handlers in worst case (currently 4). 
// there must be at least 3 PARAM, and PARAM+TEMPORARY must be at least 4.
// SR must and R0 should by all means be statically mapped.
// XXX the static definition of SR MUST match that in compiler.h

#if defined(__arm__) || defined(_M_ARM)
#include "../drc/emit_arm.c"
#elif defined(__aarch64__) || defined(_M_ARM64)
#include "../drc/emit_arm64.c"
#elif defined(__mips__)
#include "../drc/emit_mips.c"
#elif defined(__riscv__) || defined(__riscv)
#include "../drc/emit_riscv.c"
#elif defined(__powerpc__) || defined(__PPC__) || defined(__ppc__) || defined(_M_PPC)
#include "../drc/emit_ppc.c"
#elif defined(__i386__) || defined(_M_X86)
#include "../drc/emit_x86.c"
#elif defined(__x86_64__) || defined(_M_X64)
#include "../drc/emit_x86.c"
#else
#error unsupported arch
#endif

static const signed char hregs_param[] = PARAM_REGS;
static const signed char hregs_temp [] = TEMPORARY_REGS;
static const signed char hregs_saved[] = PRESERVED_REGS;
static const signed char regs_static[] = STATIC_SH2_REGS;

#define CACHE_REGS \
    (ARRAY_SIZE(hregs_param)+ARRAY_SIZE(hregs_temp)+ARRAY_SIZE(hregs_saved)-1)
static cache_reg_t cache_regs[CACHE_REGS];

static signed char reg_map_host[HOST_REGS];

static guest_reg_t guest_regs[SH2_REGS];

// generated functions called from C, to be called only through host_call()
static void REGPARM(1) (*sh2_drc_entry)(SH2 *sh2);
#ifdef DRC_SR_REG
void REGPARM(1) (*sh2_drc_save_sr)(SH2 *sh2);
void REGPARM(1) (*sh2_drc_restore_sr)(SH2 *sh2);
#endif

// generated DRC helper functions, only called from generated code via emith_call*()
static void REGPARM(1) (*sh2_drc_dispatcher)(u32 pc);
#if CALL_STACK
static u32  REGPARM(2) (*sh2_drc_dispatcher_call)(u32 pc);
static void REGPARM(1) (*sh2_drc_dispatcher_return)(u32 pc);
#endif
static void REGPARM(1) (*sh2_drc_exit)(u32 pc);
static void            (*sh2_drc_test_irq)(void);

static u32  REGPARM(1) (*sh2_drc_read8)(u32 a);
static u32  REGPARM(1) (*sh2_drc_read16)(u32 a);
static u32  REGPARM(1) (*sh2_drc_read32)(u32 a);
static u32  REGPARM(1) (*sh2_drc_read8_poll)(u32 a);
static u32  REGPARM(1) (*sh2_drc_read16_poll)(u32 a);
static u32  REGPARM(1) (*sh2_drc_read32_poll)(u32 a);
static void REGPARM(2) (*sh2_drc_write8)(u32 a, u32 d);
static void REGPARM(2) (*sh2_drc_write16)(u32 a, u32 d);
static void REGPARM(2) (*sh2_drc_write32)(u32 a, u32 d);

// flags for memory access
#define MF_SIZEMASK 0x03        // size of access
#define MF_POSTINCR 0x10        // post increment (for read_rr)
#define MF_PREDECR  MF_POSTINCR // pre decrement (for write_rr)
#define MF_POLLING  0x20	// include polling check in read

// address space stuff
static int dr_ctx_get_mem_ptr(SH2 *sh2, u32 a, u32 *mask)
{
  void *memptr;
  int poffs = -1;

  // check if region is mapped memory
  memptr = p32x_sh2_get_mem_ptr(a, mask, sh2);
  if (memptr == NULL)
    return poffs;

  if (memptr == sh2->p_bios)        // BIOS
    poffs = offsetof(SH2, p_bios);
  else if (memptr == sh2->p_da)     // data array
    poffs = offsetof(SH2, p_da);
  else if (memptr == sh2->p_sdram)  // SDRAM
    poffs = offsetof(SH2, p_sdram);
  else if (memptr == sh2->p_rom)    // ROM
    poffs = offsetof(SH2, p_rom);

  return poffs;
}

static int dr_get_tcache_id(u32 pc, int is_slave)
{
  u32 tcid = 0;
 
  if ((pc & 0xe0000000) == 0xc0000000)
    tcid = 1 + is_slave; // data array
  if ((pc & ~0xfff) == 0)
    tcid = 1 + is_slave; // BIOS
  return tcid;
}

static struct block_entry *dr_get_entry(u32 pc, int is_slave, int *tcache_id)
{
  struct block_entry *be;
 
  *tcache_id = dr_get_tcache_id(pc, is_slave);

  be = HASH_FUNC(hash_tables[*tcache_id], pc, HASH_TABLE_SIZE(*tcache_id) - 1);
  if (be != NULL) // don't ask... gcc code generation hint
  for (; be != NULL; be = be->next)
    if (be->pc == pc)
      return be;

  return NULL;
}

// ---------------------------------------------------------------

// ring buffer management
#define RING_INIT(r,m,n)    *(r) = (struct ring_buffer) { .base = (u8 *)m, \
                                        .item_sz = sizeof(*(m)), .size = n };

static void *ring_alloc(struct ring_buffer *rb, int count)
{
  // allocate space in ring buffer
  void *p;

  p = rb->base + rb->next * rb->item_sz;
  if (rb->next+count > rb->size) {
    rb->used += rb->size - rb->next;
    p = rb->base; // wrap if overflow at end
    rb->next = count;
  } else {
    rb->next += count;
    if (rb->next == rb->size) rb->next = 0;
  }

  rb->used += count;
  return p;
}

static void ring_wrap(struct ring_buffer *rb)
{
  // insufficient space at end of buffer memory, wrap around
  rb->used += rb->size - rb->next;
  rb->next = 0;
}

static void ring_free(struct ring_buffer *rb, int count)
{
  // free oldest space in ring buffer
  rb->first += count;
  if (rb->first >= rb->size) rb->first -= rb->size;

  rb->used -= count;
}

static void ring_free_p(struct ring_buffer *rb, void *p)
{
  // free ring buffer space upto given pointer
  rb->first = ((u8 *)p - rb->base) / rb->item_sz;

  rb->used = rb->next - rb->first;
  if (rb->used < 0) rb->used += rb->size;
}

static void *ring_reset(struct ring_buffer *rb)
{
  // reset to initial state
  rb->first = rb->next = rb->used = 0;
  return rb->base + rb->next * rb->item_sz;
}

static void *ring_first(struct ring_buffer *rb)
{
  return rb->base + rb->first * rb->item_sz;
}

static void *ring_next(struct ring_buffer *rb)
{
  return rb->base + rb->next * rb->item_sz;
}


// block management
static void add_to_block_list(struct block_list **blist, struct block_desc *block)
{
  struct block_list *added;

  if (blist_free) {
    added = blist_free;
    blist_free = added->next;
  } else if (block_list_pool_count >= BLOCK_LIST_MAX_COUNT) {
    printf( "block list overflow\n");
    exit(1);
  } else {
    added = block_list_pool + block_list_pool_count;
    block_list_pool_count ++;
  }

  added->block = block;
  added->l_next = block->list;
  block->list = added;
  added->head = blist;

  added->prev = NULL;
  if (*blist)
    (*blist)->prev = added;
  added->next = *blist;
  *blist = added;
}

static void rm_from_block_lists(struct block_desc *block)
{
  struct block_list *entry;

  entry = block->list;
  while (entry != NULL) {
    if (entry->prev != NULL)
      entry->prev->next = entry->next;
    else
      *(entry->head) = entry->next;
    if (entry->next != NULL)
      entry->next->prev = entry->prev;

    entry->next = blist_free;
    blist_free = entry;

    entry = entry->l_next;
  }
  block->list = NULL;
}

static void discard_block_list(struct block_list **blist)
{
  struct block_list *next, *current = *blist;
  while (current != NULL) {
    next = current->next;
    current->next = blist_free;
    blist_free = current;
    current = next;
  }
  *blist = NULL;
}

static void add_to_hashlist(struct block_entry *be, int tcache_id)
{
  u32 tcmask = HASH_TABLE_SIZE(tcache_id) - 1;
  struct block_entry **head = &HASH_FUNC(hash_tables[tcache_id], be->pc, tcmask);

  be->prev = NULL;
  if (*head)
    (*head)->prev = be;
  be->next = *head;
  *head = be;

#if (DRC_DEBUG & 2)
  if (be->next != NULL) {
    printf(" %08lx@%p: entry hash collision with %08lx@%p\n",
      (ulong)be->pc, be->tcache_ptr, (ulong)be->next->pc, be->next->tcache_ptr);
    hash_collisions++;
  }
#endif
}

static void rm_from_hashlist(struct block_entry *be, int tcache_id)
{
  u32 tcmask = HASH_TABLE_SIZE(tcache_id) - 1;
  struct block_entry **head = &HASH_FUNC(hash_tables[tcache_id], be->pc, tcmask);

#if DRC_DEBUG & 1
  struct block_entry *current = be;
  while (current->prev != NULL)
    current = current->prev;
  if (current != *head)
    dbg(1, "rm_from_hashlist @%p: be %p %08x missing?", head, be, be->pc);
#endif

  if (be->prev != NULL)
    be->prev->next = be->next;
  else
    *head = be->next;
  if (be->next != NULL)
    be->next->prev = be->prev;
}


#if LINK_BRANCHES
static void add_to_hashlist_unresolved(struct block_link *bl, int tcache_id)
{
  u32 tcmask = HASH_TABLE_SIZE(tcache_id) - 1;
  struct block_link **head = &HASH_FUNC(unresolved_links[tcache_id], bl->target_pc, tcmask);

#if DRC_DEBUG & 1
  struct block_link *current = *head;
  while (current != NULL && current != bl)
    current = current->next;
  if (current == bl)
    dbg(1, "add_to_hashlist_unresolved @%p: bl %p %p %08x already in?", head, bl, bl->target, bl->target_pc);
#endif

  bl->target = NULL; // marker for not resolved
  bl->prev = NULL;
  if (*head)
    (*head)->prev = bl;
  bl->next = *head;
  *head = bl;
}

static void rm_from_hashlist_unresolved(struct block_link *bl, int tcache_id)
{
  u32 tcmask = HASH_TABLE_SIZE(tcache_id) - 1;
  struct block_link **head = &HASH_FUNC(unresolved_links[tcache_id], bl->target_pc, tcmask);

#if DRC_DEBUG & 1
  struct block_link *current = bl;
  while (current->prev != NULL)
    current = current->prev;
  if (current != *head)
    dbg(1, "rm_from_hashlist_unresolved @%p: bl %p %p %08x missing?", head, bl, bl->target, bl->target_pc);
#endif

  if (bl->prev != NULL)
    bl->prev->next = bl->next;
  else
    *head = bl->next;
  if (bl->next != NULL)
    bl->next->prev = bl->prev;
}

static void dr_block_link(struct block_entry *be, struct block_link *bl, int emit_jump)
{
  dbg(2, "- %slink from %p to pc %08x entry %p", emit_jump ? "":"early ",
    bl->jump, bl->target_pc, be->tcache_ptr);

  if (emit_jump) {
    u8 *jump = bl->jump;
    int jsz = emith_jump_patch_size();
    if (bl->type == BL_JMP) { // patch: jump @entry
      // inlined: @jump far jump to target
      emith_jump_patch(jump, be->tcache_ptr, &jump);
    } else if (bl->type == BL_LDJMP) { // write: jump @entry
      // inlined: @jump far jump to target
      emith_jump_at(jump, be->tcache_ptr);
      jsz = emith_jump_at_size();
    } else if (bl->type == BL_JCCBLX) { // patch: jump cond -> jump @entry
      if (emith_jump_patch_inrange(bl->jump, be->tcache_ptr)) {
        // inlined: @jump near jumpcc to target
        emith_jump_patch(jump, be->tcache_ptr, &jump);
      } else { // dispatcher cond immediate
        // via blx: @jump near jumpcc to blx; @blx far jump
        emith_jump_patch(jump, bl->blx, &jump);
        emith_jump_at(bl->blx, be->tcache_ptr);
        host_instructions_updated(bl->blx, (char *)bl->blx + emith_jump_at_size(),
            ((uintptr_t)bl->blx & 0x1f) + emith_jump_at_size()-1 > 0x1f);
      }
    } else {
      printf("unknown BL type %d\n", bl->type);
      exit(1);
    }
    host_instructions_updated(jump, jump + jsz, ((uintptr_t)jump & 0x1f) + jsz-1 > 0x1f);
  }

  // move bl to block_entry
  bl->target = be;
  bl->prev = NULL;
  if (be->links)
    be->links->prev = bl;
  bl->next = be->links;
  be->links = bl;
}

static void dr_block_unlink(struct block_link *bl, int emit_jump)
{
  dbg(2,"- unlink from %p to pc %08x", bl->jump, bl->target_pc);

  if (bl->target) {
    if (emit_jump) {
      u8 *jump = bl->jump;
      int jsz = emith_jump_patch_size();
      if (bl->type == BL_JMP) { // jump_patch @dispatcher
        // inlined: @jump far jump to dispatcher
        emith_jump_patch(jump, sh2_drc_dispatcher, &jump);
      } else if (bl->type == BL_LDJMP) { // restore: load pc, jump @dispatcher
        // inlined: @jump load target_pc, far jump to dispatcher
        memcpy(jump, bl->jdisp, emith_jump_at_size());
        jsz = emith_jump_at_size();
      } else if (bl->type == BL_JCCBLX) { // jump cond @blx; @blx: load pc, jump
        // via blx: @jump near jumpcc to blx; @blx load target_pc, far jump
        emith_jump_patch(bl->jump, bl->blx, &jump);
        memcpy(bl->blx, bl->jdisp, emith_jump_at_size());
        host_instructions_updated(bl->blx, (char *)bl->blx + emith_jump_at_size(), 1);
      } else {
        printf("unknown BL type %d\n", bl->type);
        exit(1);
      }
      // update cpu caches since the previous jump target doesn't exist anymore
      host_instructions_updated(jump, jump + jsz, 1);
    }

    if (bl->prev)
      bl->prev->next = bl->next;
    else
      bl->target->links = bl->next;
    if (bl->next)
      bl->next->prev = bl->prev;
    bl->target = NULL;
  }
}
#endif

static struct block_link *dr_prepare_ext_branch(struct block_entry *owner, u32 pc, int is_slave, int tcache_id)
{
#if LINK_BRANCHES
  struct block_link *bl = block_link_pool[tcache_id];
  int cnt = block_link_pool_counts[tcache_id];
  int target_tcache_id;

  // get the target block entry
  target_tcache_id = dr_get_tcache_id(pc, is_slave);
  if (target_tcache_id && target_tcache_id != tcache_id)
    return NULL;

  // get a block link
  if (blink_free[tcache_id] != NULL) {
    bl = blink_free[tcache_id];
    blink_free[tcache_id] = bl->next;
  } else if (cnt >= BLOCK_LINK_MAX_COUNT(tcache_id)) {
    dbg(1, "bl overflow for tcache %d", tcache_id);
    return NULL;
  } else {
    bl += cnt;
    block_link_pool_counts[tcache_id] = cnt+1;
  }

  // prepare link and add to outgoing list of owner
  bl->tcache_id = tcache_id;
  bl->target_pc = pc;
  bl->jump = tcache_ptr;
  bl->blx = NULL;
  bl->o_next = owner->o_links;
  owner->o_links = bl;

  add_to_hashlist_unresolved(bl, tcache_id);
  return bl;
#else
  return NULL;
#endif
}

static void dr_mark_memory(int mark, struct block_desc *block, int tcache_id, u32 nolit)
{
  u8 *drc_ram_blk = NULL, *lit_ram_blk = NULL;
  u32 addr, end, mask = 0, shift = 0, idx;

  // mark memory blocks as containing compiled code
  if ((block->addr & 0xc7fc0000) == 0x06000000
      || (block->addr & 0xfffff000) == 0xc0000000)
  {
    if (tcache_id != 0) {
      // data array
      drc_ram_blk = Pico32xMem->drcblk_da[tcache_id-1];
      lit_ram_blk = Pico32xMem->drclit_da[tcache_id-1];
      shift = SH2_DRCBLK_DA_SHIFT;
    }
    else {
      // SDRAM
      drc_ram_blk = Pico32xMem->drcblk_ram;
      lit_ram_blk = Pico32xMem->drclit_ram;
      shift = SH2_DRCBLK_RAM_SHIFT;
    }
    mask = RAM_SIZE(tcache_id) - 1;

    // mark recompiled insns
    addr = block->addr & ~((1 << shift) - 1);
    end = block->addr + block->size;
    for (idx = (addr & mask) >> shift; addr < end; addr += (1 << shift))
      drc_ram_blk[idx++] += mark;

    // mark literal pool
    if (addr < (block->addr_lit & ~((1 << shift) - 1)))
      addr = block->addr_lit & ~((1 << shift) - 1);
    end = block->addr_lit + block->size_lit;
    for (idx = (addr & mask) >> shift; addr < end; addr += (1 << shift))
      drc_ram_blk[idx++] += mark;

    // mark for literals disabled
    if (nolit) {
      addr = nolit & ~((1 << shift) - 1);
      end = block->addr_lit + block->size_lit;
      for (idx = (addr & mask) >> shift; addr < end; addr += (1 << shift))
        lit_ram_blk[idx++] = 1;
    }

    if (mark < 0)
      rm_from_block_lists(block);
    else {
      // add to invalidation lookup lists
      addr = block->addr & ~(INVAL_PAGE_SIZE - 1);
      end = block->addr + block->size;
      for (idx = (addr & mask) / INVAL_PAGE_SIZE; addr < end; addr += INVAL_PAGE_SIZE)
        add_to_block_list(&inval_lookup[tcache_id][idx++], block);

      if (addr < (block->addr_lit & ~(INVAL_PAGE_SIZE - 1)))
        addr = block->addr_lit & ~(INVAL_PAGE_SIZE - 1);
      end = block->addr_lit + block->size_lit;
      for (idx = (addr & mask) / INVAL_PAGE_SIZE; addr < end; addr += INVAL_PAGE_SIZE)
        add_to_block_list(&inval_lookup[tcache_id][idx++], block);
    }
  }
}

static u32 dr_check_nolit(u32 start, u32 end, int tcache_id)
{
  u8 *lit_ram_blk = NULL;
  u32 mask = 0, shift = 0, addr, idx;

  if ((start & 0xc7fc0000) == 0x06000000
      || (start & 0xfffff000) == 0xc0000000)
  {
    if (tcache_id != 0) {
      // data array
      lit_ram_blk = Pico32xMem->drclit_da[tcache_id-1];
      shift = SH2_DRCBLK_DA_SHIFT;
    }
    else {
      // SDRAM
      lit_ram_blk = Pico32xMem->drclit_ram;
      shift = SH2_DRCBLK_RAM_SHIFT;
    }
    mask = RAM_SIZE(tcache_id) - 1;

    addr = start & ~((1 << shift) - 1);
    for (idx = (addr & mask) >> shift; addr < end; addr += (1 << shift))
      if (lit_ram_blk[idx++])
        break;

    return (addr < start ? start : addr > end ? end : addr);
  }

  return end;
}

static void dr_rm_block_entry(struct block_desc *bd, int tcache_id, u32 nolit, int free)
{
  struct block_link *bl;
  u32 i;

  free = free || nolit; // block is invalid if literals are overwritten
  dbg(2,"  %sing block %08x-%08x,%08x-%08x, blkid %d,%d", free?"delet":"disabl",
    bd->addr, bd->addr + bd->size, bd->addr_lit, bd->addr_lit + bd->size_lit,
    tcache_id, bd - block_tables[tcache_id]);
  if (bd->addr == 0 || bd->entry_count == 0) {
    dbg(1, "  killing dead block!? %08x", bd->addr);
    return;
  }

  // remove from hash table, make incoming links unresolved
  if (bd->active) {
    for (i = 0; i < bd->entry_count; i++) {
      rm_from_hashlist(&bd->entryp[i], tcache_id);

#if LINK_BRANCHES
      while ((bl = bd->entryp[i].links) != NULL) {
        dr_block_unlink(bl, 1);
        add_to_hashlist_unresolved(bl, tcache_id);
      }
#endif
    }

    dr_mark_memory(-1, bd, tcache_id, nolit);
    add_to_block_list(&inactive_blocks[tcache_id], bd);
  }
  bd->active = 0;

  if (free) {
#if LINK_BRANCHES
    // revoke outgoing links
    for (bl = bd->entryp[0].o_links; bl != NULL; bl = bl->o_next) {
      if (bl->target)
        dr_block_unlink(bl, 0);
      else
        rm_from_hashlist_unresolved(bl, tcache_id);
      bl->jump = NULL;
      bl->next = blink_free[bl->tcache_id];
      blink_free[bl->tcache_id] = bl;
    }
    bd->entryp[0].o_links = NULL;
#endif
    // invalidate block
    rm_from_block_lists(bd);
    bd->addr = bd->size = bd->addr_lit = bd->size_lit = 0;
    bd->entry_count = 0;
  }
  emith_update_cache();
}

static struct block_desc *dr_find_inactive_block(int tcache_id, u16 crc,
  u32 addr, int size, u32 addr_lit, int size_lit)
{
  struct block_list **head = &inactive_blocks[tcache_id];
  struct block_list *current;

  for (current = *head; current != NULL; current = current->next) {
    struct block_desc *block = current->block;
    if (block->crc == crc && block->addr == addr && block->size == size &&
        block->addr_lit == addr_lit && block->size_lit == size_lit)
    {
      rm_from_block_lists(block);
      return block;
    }
  }
  return NULL;
}

static struct block_desc *dr_add_block(int entries, u32 addr, int size,
  u32 addr_lit, int size_lit, u16 crc, int is_slave, int *blk_id)
{
  struct block_entry *be;
  struct block_desc *bd;
  int tcache_id;

  // do a lookup to get tcache_id and override check
  be = dr_get_entry(addr, is_slave, &tcache_id);
  if (be != NULL)
    dbg(1, "block override for %08x", addr);

  if (block_ring[tcache_id].used + 1 > block_ring[tcache_id].size ||
      entry_ring[tcache_id].used + entries > entry_ring[tcache_id].size) {
    dbg(1, "bd overflow for tcache %d", tcache_id);
    return NULL;
  }

  *blk_id = block_ring[tcache_id].next;
  bd = ring_alloc(&block_ring[tcache_id], 1);
  bd->entryp = ring_alloc(&entry_ring[tcache_id], entries);

  bd->addr = addr;
  bd->size = size;
  bd->addr_lit = addr_lit;
  bd->size_lit = size_lit;
  bd->tcache_ptr = tcache_ptr;
  bd->crc = crc;
  bd->active = 0;
  bd->list = NULL;
  bd->entry_count = 0;
#if (DRC_DEBUG & 2)
  bd->refcount = 0;
#endif

  return bd;
}

static void dr_link_blocks(struct block_entry *be, int tcache_id)
{
#if LINK_BRANCHES
  u32 tcmask = HASH_TABLE_SIZE(tcache_id) - 1;
  u32 pc = be->pc;
  struct block_link **head = &HASH_FUNC(unresolved_links[tcache_id], pc, tcmask);
  struct block_link *bl = *head, *next;

  while (bl != NULL) {
    next = bl->next;
    if (bl->target_pc == pc && (!bl->tcache_id || bl->tcache_id == tcache_id)) {
      rm_from_hashlist_unresolved(bl, bl->tcache_id);
      dr_block_link(be, bl, 1);
    }
    bl = next;
  }
#endif
}

static void dr_link_outgoing(struct block_entry *be, int tcache_id, int is_slave)
{
#if LINK_BRANCHES
  struct block_link *bl;
  int target_tcache_id;

  for (bl = be->o_links; bl; bl = bl->o_next) {
    if (bl->target == NULL) {
      be = dr_get_entry(bl->target_pc, is_slave, &target_tcache_id);
      if (be != NULL && (!target_tcache_id || target_tcache_id == tcache_id)) {
        // remove bl from unresolved_links (must've been since target was NULL)
        rm_from_hashlist_unresolved(bl, bl->tcache_id);
        dr_block_link(be, bl, 1);
      }
    }
  }
#endif
}

static void dr_activate_block(struct block_desc *bd, int tcache_id, int is_slave)
{
  int i;

  // connect branches
  for (i = 0; i < bd->entry_count; i++) {
    struct block_entry *entry = &bd->entryp[i];
    add_to_hashlist(entry, tcache_id);
    // incoming branches
    dr_link_blocks(entry, tcache_id);
    if (!tcache_id)
      dr_link_blocks(entry, is_slave?2:1);
    // outgoing branches
    dr_link_outgoing(entry, tcache_id, is_slave);
  }

  // mark memory for overwrite detection
  dr_mark_memory(1, bd, tcache_id, 0);
  bd->active = 1;
}

static void REGPARM(3) *dr_lookup_block(u32 pc, SH2 *sh2, int *tcache_id)
{
  struct block_entry *be = NULL;
  void *block = NULL;

  be = dr_get_entry(pc, sh2->is_slave, tcache_id);
  if (be != NULL)
    block = be->tcache_ptr;

#if (DRC_DEBUG & 2)
  if (be != NULL)
    be->block->refcount++;
#endif
  return block;
}

static void dr_free_oldest_block(int tcache_id)
{
  struct block_desc *bf;

  bf = ring_first(&block_ring[tcache_id]);
  if (bf->addr && bf->entry_count)
    dr_rm_block_entry(bf, tcache_id, 0, 1);
  ring_free(&block_ring[tcache_id], 1);

  if (block_ring[tcache_id].used) {
    bf = ring_first(&block_ring[tcache_id]);
    ring_free_p(&entry_ring[tcache_id], bf->entryp);
    ring_free_p(&tcache_ring[tcache_id], bf->tcache_ptr);
  } else {
    // reset since size of code block isn't known if no successor block exists
    ring_reset(&block_ring[tcache_id]);
    ring_reset(&entry_ring[tcache_id]);
    ring_reset(&tcache_ring[tcache_id]);
  }
}

static inline void dr_reserve_cache(int tcache_id, struct ring_buffer *rb, int count)
{
  // while not enough space available
  if (rb->next + count >= rb->size){
    // not enough space in rest of buffer -> wrap around
    while (rb->first >= rb->next && rb->used)
      dr_free_oldest_block(tcache_id);
    if (rb->first == 0 && rb->used)
      dr_free_oldest_block(tcache_id);
    ring_wrap(rb);
  }
  while (rb->first >= rb->next && rb->next + count > rb->first && rb->used)
    dr_free_oldest_block(tcache_id);
}

static u8 *dr_prepare_cache(int tcache_id, int insn_count, int entry_count)
{
  int bf = block_ring[tcache_id].first;

  // reserve one block desc
  if (block_ring[tcache_id].used >= block_ring[tcache_id].size)
    dr_free_oldest_block(tcache_id);
  // reserve block entries
  dr_reserve_cache(tcache_id, &entry_ring[tcache_id], entry_count);
  // reserve cache space
  dr_reserve_cache(tcache_id, &tcache_ring[tcache_id], insn_count*128);

  if (bf != block_ring[tcache_id].first) {
    // deleted some block(s), clear branch cache and return stack
#if BRANCH_CACHE
    if (tcache_id)
      memset32(sh2s[tcache_id-1].branch_cache, -1, sizeof(sh2s[0].branch_cache)/4);
    else {
      memset32(sh2s[0].branch_cache, -1, sizeof(sh2s[0].branch_cache)/4);
      memset32(sh2s[1].branch_cache, -1, sizeof(sh2s[1].branch_cache)/4);
    }
#endif
#if CALL_STACK
    if (tcache_id) {
      memset32(sh2s[tcache_id-1].rts_cache, -1, sizeof(sh2s[0].rts_cache)/4);
      sh2s[tcache_id-1].rts_cache_idx = 0;
    } else {
      memset32(sh2s[0].rts_cache, -1, sizeof(sh2s[0].rts_cache)/4);
      memset32(sh2s[1].rts_cache, -1, sizeof(sh2s[1].rts_cache)/4);
      sh2s[0].rts_cache_idx = sh2s[1].rts_cache_idx = 0;
    }
#endif
  }

  return ring_next(&tcache_ring[tcache_id]);
}

static void dr_flush_tcache(int tcid)
{
  int i;
#if (DRC_DEBUG & 1)
  elprintf(EL_STATUS, "tcache #%d flush! (%d/%d, bds %d/%d bes %d/%d)", tcid,
    tcache_ring[tcid].used, tcache_ring[tcid].size, block_ring[tcid].used,
    block_ring[tcid].size, entry_ring[tcid].used, entry_ring[tcid].size);
#endif

  ring_reset(&tcache_ring[tcid]);
  ring_reset(&block_ring[tcid]);
  ring_reset(&entry_ring[tcid]);

  block_link_pool_counts[tcid] = 0;
  blink_free[tcid] = NULL;
  memset(unresolved_links[tcid], 0, sizeof(*unresolved_links[0]) * HASH_TABLE_SIZE(tcid));
  memset(hash_tables[tcid], 0, sizeof(*hash_tables[0]) * HASH_TABLE_SIZE(tcid));

  if (tcid == 0) { // ROM, RAM
    memset(Pico32xMem->drcblk_ram, 0, sizeof(Pico32xMem->drcblk_ram));
    memset(Pico32xMem->drclit_ram, 0, sizeof(Pico32xMem->drclit_ram));
    memset(sh2s[0].branch_cache, -1, sizeof(sh2s[0].branch_cache));
    memset(sh2s[1].branch_cache, -1, sizeof(sh2s[1].branch_cache));
    memset(sh2s[0].rts_cache, -1, sizeof(sh2s[0].rts_cache));
    memset(sh2s[1].rts_cache, -1, sizeof(sh2s[1].rts_cache));
    sh2s[0].rts_cache_idx = sh2s[1].rts_cache_idx = 0;
  } else {
    memset(Pico32xMem->drcblk_ram, 0, sizeof(Pico32xMem->drcblk_ram));
    memset(Pico32xMem->drclit_ram, 0, sizeof(Pico32xMem->drclit_ram));
    memset(Pico32xMem->drcblk_da[tcid - 1], 0, sizeof(Pico32xMem->drcblk_da[tcid - 1]));
    memset(Pico32xMem->drclit_da[tcid - 1], 0, sizeof(Pico32xMem->drclit_da[tcid - 1]));
    memset(sh2s[tcid - 1].branch_cache, -1, sizeof(sh2s[0].branch_cache));
    memset(sh2s[tcid - 1].rts_cache, -1, sizeof(sh2s[0].rts_cache));
    sh2s[tcid - 1].rts_cache_idx = 0;
  }
#if (DRC_DEBUG & 4)
  tcache_dsm_ptrs[tcid] = tcache_ring[tcid].base;
#endif

  for (i = 0; i < RAM_SIZE(tcid) / INVAL_PAGE_SIZE; i++)
    discard_block_list(&inval_lookup[tcid][i]);
  discard_block_list(&inactive_blocks[tcid]);
}

static void *dr_failure(void)
{
  printf("recompilation failed\n");
  exit(1);
}

// ---------------------------------------------------------------

// NB rcache allocation dependencies:
// - get_reg_arg/get_tmp_arg first (might evict other regs just allocated)
// - get_reg(..., NULL) before get_reg(..., &hr) if it might get the same reg
// - get_reg(..., RC_GR_READ/RMW, ...) before WRITE (might evict needed reg)

// register cache / constant propagation stuff
typedef enum {
  RC_GR_READ,
  RC_GR_WRITE,
  RC_GR_RMW,
} rc_gr_mode;

typedef struct {
  u32 gregs;
  u32 val;
} gconst_t;

gconst_t gconsts[ARRAY_SIZE(guest_regs)];

static int rcache_get_reg_(sh2_reg_e r, rc_gr_mode mode, int do_locking, int *hr);
static inline int rcache_is_cached(sh2_reg_e r);
static void rcache_add_vreg_alias(int x, sh2_reg_e r);
static void rcache_remove_vreg_alias(int x, sh2_reg_e r);
static void rcache_evict_vreg(int x);
static void rcache_remap_vreg(int x);
static int rcache_get_reg(sh2_reg_e r, rc_gr_mode mode, int *hr);

static void rcache_set_x16(int hr, int s16_, int u16_)
{
  int x = reg_map_host[hr];
  if (x >= 0) {
    cache_regs[x].flags &= ~(HRF_S16|HRF_U16);
    if (s16_) cache_regs[x].flags |= HRF_S16;
    if (u16_) cache_regs[x].flags |= HRF_U16;
  }
}

static void rcache_copy_x16(int hr, int hr2)
{
  int x = reg_map_host[hr], y = reg_map_host[hr2];
  if (x >= 0 && y >= 0) {
    cache_regs[x].flags = (cache_regs[x].flags & ~(HRF_S16|HRF_U16)) |
                          (cache_regs[y].flags &  (HRF_S16|HRF_U16));
  }
}

static int rcache_is_s16(int hr)
{
  int x = reg_map_host[hr];
  return (x >= 0 ? cache_regs[x].flags & HRF_S16 : 0);
}

static int rcache_is_u16(int hr)
{
  int x = reg_map_host[hr];
  return (x >= 0 ? cache_regs[x].flags & HRF_U16 : 0);
}

#define RCACHE_DUMP(msg) { \
  cache_reg_t *cp; \
  guest_reg_t *gp; \
  int i; \
  printf("cache dump %s:\n",msg); \
  printf(" cache_regs:\n"); \
  for (i = 0; i < ARRAY_SIZE(cache_regs); i++) { \
    cp = &cache_regs[i]; \
    if (cp->type != HR_FREE || cp->gregs || cp->locked || cp->flags) \
      printf("  %d: hr=%d t=%d f=%x c=%d m=%lx\n", i, cp->hreg, cp->type, cp->flags, cp->locked, (ulong)cp->gregs); \
  } \
  printf(" guest_regs:\n"); \
  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) { \
    gp = &guest_regs[i]; \
    if (gp->vreg != -1 || gp->sreg >= 0 || gp->flags) \
      printf("  %d: v=%d f=%x s=%d c=%d\n", i, gp->vreg, gp->flags, gp->sreg, gp->cnst); \
  } \
  printf(" gconsts:\n"); \
  for (i = 0; i < ARRAY_SIZE(gconsts); i++) { \
    if (gconsts[i].gregs) \
      printf("  %d: m=%lx v=%lx\n", i, (ulong)gconsts[i].gregs, (ulong)gconsts[i].val); \
  } \
}

#define RCACHE_CHECK(msg) { \
  cache_reg_t *cp; \
  guest_reg_t *gp; \
  int i, x, m = 0, d = 0; \
  for (i = 0; i < ARRAY_SIZE(cache_regs); i++) { \
    cp = &cache_regs[i]; \
    if (cp->flags & HRF_PINNED) m |= (1 << i); \
    if (cp->type == HR_FREE || cp->type == HR_TEMP) continue; \
    /* check connectivity greg->vreg */ \
    FOR_ALL_BITS_SET_DO(cp->gregs, x, \
      if (guest_regs[x].vreg != i) \
        { d = 1; printf("cache check v=%d r=%d not connected?\n",i,x); } \
    ) \
  } \
  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) { \
    gp = &guest_regs[i]; \
    if (gp->vreg != -1 && !(cache_regs[gp->vreg].gregs & (1 << i))) \
      { d = 1; printf("cache check r=%d v=%d not connected?\n", i, gp->vreg); }\
    if (gp->vreg != -1 && cache_regs[gp->vreg].type != HR_CACHED) \
      { d = 1; printf("cache check r=%d v=%d wrong type?\n", i, gp->vreg); }\
    if ((gp->flags & GRF_CONST) && !(gconsts[gp->cnst].gregs & (1 << i))) \
      { d = 1; printf("cache check r=%d c=%d not connected?\n", i, gp->cnst); }\
    if ((gp->flags & GRF_CDIRTY) && (gp->vreg != -1 || !(gp->flags & GRF_CONST)))\
      { d = 1; printf("cache check r=%d CDIRTY?\n", i); } \
    if (gp->flags & (GRF_STATIC|GRF_PINNED)) { \
      if (gp->sreg == -1 || !(cache_regs[gp->sreg].flags & HRF_PINNED))\
        { d = 1; printf("cache check r=%d v=%d not pinned?\n", i, gp->vreg); } \
      else m &= ~(1 << gp->sreg); \
    } \
  } \
  for (i = 0; i < ARRAY_SIZE(gconsts); i++) { \
    FOR_ALL_BITS_SET_DO(gconsts[i].gregs, x, \
      if (guest_regs[x].cnst != i || !(guest_regs[x].flags & GRF_CONST)) \
        { d = 1; printf("cache check c=%d v=%d not connected?\n",i,x); } \
    ) \
  } \
  if (m) \
    { d = 1; printf("cache check m=%x pinning wrong?\n",m); } \
  if (d) RCACHE_DUMP(msg) \
/*  else { \
    printf("locked regs %s:\n",msg); \
    for (i = 0; i < ARRAY_SIZE(cache_regs); i++) { \
      cp = &cache_regs[i]; \
      if (cp->locked) \
        printf("  %d: hr=%d t=%d f=%x c=%d m=%x\n", i, cp->hreg, cp->type, cp->flags, cp->locked, cp->gregs); \
    } \
  } */ \
}

static inline int gconst_alloc(sh2_reg_e r)
{
  int i, n = -1;

  for (i = 0; i < ARRAY_SIZE(gconsts); i++) {
    gconsts[i].gregs &= ~(1 << r);
    if (gconsts[i].gregs == 0 && n < 0)
      n = i;
  }
  if (n >= 0)
    gconsts[n].gregs = (1 << r);
  else {
    printf("all gconst buffers in use, aborting\n");
    exit(1); // cannot happen - more constants than guest regs?
  }
  return n;
}

static void gconst_set(sh2_reg_e r, u32 val)
{
  int i = gconst_alloc(r);

  guest_regs[r].flags |= GRF_CONST;
  guest_regs[r].cnst = i;
  gconsts[i].val = val;
}

static void gconst_new(sh2_reg_e r, u32 val)
{
  gconst_set(r, val);
  guest_regs[r].flags |= GRF_CDIRTY;

  // throw away old r that we might have cached
  if (guest_regs[r].vreg >= 0)
    rcache_remove_vreg_alias(guest_regs[r].vreg, r);
}

static int gconst_get(sh2_reg_e r, u32 *val)
{
  if (guest_regs[r].flags & GRF_CONST) {
    *val = gconsts[guest_regs[r].cnst].val;
    return 1;
  }
  *val = 0;
  return 0;
}

static int gconst_check(sh2_reg_e r)
{
  if (guest_regs[r].flags & (GRF_CONST|GRF_CDIRTY))
    return 1;
  return 0;
}

// update hr if dirty, else do nothing
static int gconst_try_read(int vreg, sh2_reg_e r)
{
  int i, x;
  u32 v;

  if (guest_regs[r].flags & GRF_CDIRTY) {
    x = guest_regs[r].cnst;
    v = gconsts[x].val;
    emith_move_r_imm(cache_regs[vreg].hreg, v);
    rcache_set_x16(cache_regs[vreg].hreg, v == (s16)v, v == (u16)v);
    FOR_ALL_BITS_SET_DO(gconsts[x].gregs, i,
      {
        if (guest_regs[i].vreg >= 0 && guest_regs[i].vreg != vreg)
          rcache_remove_vreg_alias(guest_regs[i].vreg, i);
        if (guest_regs[i].vreg < 0)
          rcache_add_vreg_alias(vreg, i);
        guest_regs[i].flags &= ~GRF_CDIRTY;
        guest_regs[i].flags |= GRF_DIRTY;
      });
    cache_regs[vreg].type = HR_CACHED;
    cache_regs[vreg].flags |= HRF_DIRTY;
    return 1;
  }
  return 0;
}

static u32 gconst_dirty_mask(void)
{
  u32 mask = 0;
  int i;

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++)
    if (guest_regs[i].flags & GRF_CDIRTY)
      mask |= (1 << i);
  return mask;
}

static void gconst_kill(sh2_reg_e r)
{
  if (guest_regs[r].flags & (GRF_CONST|GRF_CDIRTY))
    gconsts[guest_regs[r].cnst].gregs &= ~(1 << r);
  guest_regs[r].flags &= ~(GRF_CONST|GRF_CDIRTY);
}

static void gconst_copy(sh2_reg_e rd, sh2_reg_e rs)
{
  gconst_kill(rd);
  if (guest_regs[rs].flags & GRF_CONST) {
    guest_regs[rd].flags |= GRF_CONST;
    if (guest_regs[rd].vreg < 0)
      guest_regs[rd].flags |= GRF_CDIRTY;
    guest_regs[rd].cnst = guest_regs[rs].cnst;
    gconsts[guest_regs[rd].cnst].gregs |= (1 << rd);
  }
}

static void gconst_clean(void)
{
  int i;

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++)
    if (guest_regs[i].flags & GRF_CDIRTY) {
      // using RC_GR_READ here: it will call gconst_try_read,
      // cache the reg and mark it dirty.
      rcache_get_reg_(i, RC_GR_READ, 0, NULL);
    }
}

static void gconst_invalidate(void)
{
  int i;

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) {
    if (guest_regs[i].flags & (GRF_CONST|GRF_CDIRTY))
      gconsts[guest_regs[i].cnst].gregs &= ~(1 << i);
    guest_regs[i].flags &= ~(GRF_CONST|GRF_CDIRTY);
  }
}


static u16 rcache_counter;
// SH2 register usage bitmasks
static u32 rcache_vregs_reg;     // regs of type HRT_REG (for pinning)
static u32 rcache_regs_static;   // statically allocated regs
static u32 rcache_regs_pinned;   // pinned regs
static u32 rcache_regs_now;      // regs used in current insn
static u32 rcache_regs_soon;     // regs used in the next few insns
static u32 rcache_regs_late;     // regs used in later insns
static u32 rcache_regs_discard;  // regs overwritten without being used
static u32 rcache_regs_clean;    // regs needing cleaning

static void rcache_lock_vreg(int x)
{
  if (x >= 0) {
    cache_regs[x].locked ++;
#if DRC_DEBUG & 64
    if (cache_regs[x].type == HR_FREE) {
      printf("locking free vreg %x, aborting\n", x);
      exit(1);
    }
    if (!cache_regs[x].locked) {
      printf("locking overflow vreg %x, aborting\n", x);
      exit(1);
    }
#endif
  }
}

static void rcache_unlock_vreg(int x)
{
  if (x >= 0) {
#if DRC_DEBUG & 64
    if (cache_regs[x].type == HR_FREE) {
      printf("unlocking free vreg %x, aborting\n", x);
      exit(1);
    }
#endif
    if (cache_regs[x].locked)
      cache_regs[x].locked --;
  }
}

static void rcache_free_vreg(int x)
{
  cache_regs[x].type = cache_regs[x].locked ? HR_TEMP : HR_FREE;
  cache_regs[x].flags &= HRF_PINNED;
  cache_regs[x].gregs = 0;
}

static void rcache_unmap_vreg(int x)
{
  int i;

  FOR_ALL_BITS_SET_DO(cache_regs[x].gregs, i,
      if (guest_regs[i].flags & GRF_DIRTY) {
        // if a dirty reg is unmapped save its value to context
        if ((~rcache_regs_discard | rcache_regs_now) & (1 << i))
          emith_ctx_write(cache_regs[x].hreg, i * 4);
        guest_regs[i].flags &= ~GRF_DIRTY;
      }
      guest_regs[i].vreg = -1);
  rcache_free_vreg(x);
}

static void rcache_move_vreg(int d, int x)
{
  int i;

  cache_regs[d].type = HR_CACHED;
  cache_regs[d].gregs = cache_regs[x].gregs;
  cache_regs[d].flags &= HRF_PINNED;
  cache_regs[d].flags |= cache_regs[x].flags & ~HRF_PINNED;
  cache_regs[d].locked = 0;
  cache_regs[d].stamp = cache_regs[x].stamp;
  emith_move_r_r(cache_regs[d].hreg, cache_regs[x].hreg);
  for (i = 0; i < ARRAY_SIZE(guest_regs); i++)
    if (guest_regs[i].vreg == x)
      guest_regs[i].vreg = d;
  rcache_free_vreg(x);
}

static void rcache_clean_vreg(int x)
{
  u32 rns = rcache_regs_now | rcache_regs_soon;
  int r;

  if (cache_regs[x].flags & HRF_DIRTY) { // writeback
    cache_regs[x].flags &= ~HRF_DIRTY;
    rcache_lock_vreg(x);
    FOR_ALL_BITS_SET_DO(cache_regs[x].gregs, r,
        if (guest_regs[r].flags & GRF_DIRTY) {
          if (guest_regs[r].flags & (GRF_STATIC|GRF_PINNED)) {
            if (guest_regs[r].vreg != guest_regs[r].sreg &&
                !cache_regs[guest_regs[r].sreg].locked &&
                ((~rcache_regs_discard | rcache_regs_now) & (1 << r)) &&
                !(rns & cache_regs[guest_regs[r].sreg].gregs)) {
              // statically mapped reg not in its sreg. move back to sreg
              rcache_evict_vreg(guest_regs[r].sreg);
              emith_move_r_r(cache_regs[guest_regs[r].sreg].hreg,
                             cache_regs[guest_regs[r].vreg].hreg);
              rcache_copy_x16(cache_regs[guest_regs[r].sreg].hreg,
                             cache_regs[guest_regs[r].vreg].hreg);
              rcache_remove_vreg_alias(x, r);
              rcache_add_vreg_alias(guest_regs[r].sreg, r);
              cache_regs[guest_regs[r].sreg].flags |= HRF_DIRTY;
            } else
              // cannot remap. keep dirty for writeback in unmap
              cache_regs[x].flags |= HRF_DIRTY;
          } else {
            if ((~rcache_regs_discard | rcache_regs_now) & (1 << r))
              emith_ctx_write(cache_regs[x].hreg, r * 4);
            guest_regs[r].flags &= ~GRF_DIRTY;
          }
          rcache_regs_clean &= ~(1 << r);
        })
    rcache_unlock_vreg(x);
  }

#if DRC_DEBUG & 64
  RCACHE_CHECK("after clean");
#endif
}

static void rcache_add_vreg_alias(int x, sh2_reg_e r)
{
  cache_regs[x].gregs |= (1 << r);
  guest_regs[r].vreg = x;
  cache_regs[x].type = HR_CACHED;
}

static void rcache_remove_vreg_alias(int x, sh2_reg_e r)
{
  cache_regs[x].gregs &= ~(1 << r);
  if (!cache_regs[x].gregs) {
    // no reg mapped -> free vreg
    if (cache_regs[x].locked)
      cache_regs[x].type = HR_TEMP;
    else
      rcache_free_vreg(x);
  }
  guest_regs[r].vreg = -1;
}

static void rcache_evict_vreg(int x)
{
  rcache_remap_vreg(x);
  rcache_unmap_vreg(x);
}

static void rcache_evict_vreg_aliases(int x, sh2_reg_e r)
{
  rcache_remove_vreg_alias(x, r);
  rcache_evict_vreg(x);
  rcache_add_vreg_alias(x, r);
}

static int rcache_allocate(int what, int minprio)
{
  // evict reg with oldest stamp (only for HRT_REG, no temps)
  int i, i_prio, oldest = -1, prio = 0;
  u16 min_stamp = (u16)-1;

  for (i = ARRAY_SIZE(cache_regs)-1; i >= 0; i--) {
    // consider only non-static, unpinned, unlocked REG or TEMP
    if ((cache_regs[i].flags & HRF_PINNED) || cache_regs[i].locked)
      continue;
    if ((what > 0 && !(cache_regs[i].htype & HRT_REG)) ||   // get a REG
        (what == 0 && (cache_regs[i].htype & HRT_TEMP)) ||  // get a non-TEMP
        (what < 0 && !(cache_regs[i].htype & HRT_TEMP)))    // get a TEMP
      continue;
    if (cache_regs[i].type == HR_FREE || cache_regs[i].type == HR_TEMP) {
      // REG is free
      prio = 10;
      oldest = i;
      break;
    }
    if (cache_regs[i].type == HR_CACHED) {
      if (rcache_regs_now & cache_regs[i].gregs)
        // REGs needed for the current insn
        i_prio = 0;
      else if (rcache_regs_soon & cache_regs[i].gregs)
        // REGs needed in the next insns
        i_prio = 2;
      else if (rcache_regs_late & cache_regs[i].gregs)
        // REGs needed in some future insn
        i_prio = 4;
      else if (~rcache_regs_discard & cache_regs[i].gregs)
        // REGs not needed in the foreseeable future
        i_prio = 6;
      else
        // REGs soon overwritten anyway
        i_prio = 8;
      if (!(cache_regs[i].flags & HRF_DIRTY)) i_prio ++;

      if (prio < i_prio || (prio == i_prio && cache_regs[i].stamp < min_stamp)) {
        min_stamp = cache_regs[i].stamp;
        oldest = i;
        prio = i_prio;
      }
    }
  }


  if (prio < minprio || oldest == -1)
    return -1;

  if (cache_regs[oldest].type == HR_CACHED)
    rcache_evict_vreg(oldest);
  else
    rcache_free_vreg(oldest);

  return oldest;
}

static int rcache_allocate_vreg(int needed)
{
  int x;
  
  x = rcache_allocate(1, needed ? 0 : 4);
  if (x < 0)
    x = rcache_allocate(-1, 0);
  return x;
}

static int rcache_allocate_nontemp(void)
{
  int x = rcache_allocate(0, 4);
  return x;
}

static int rcache_allocate_temp(void)
{
  int x = rcache_allocate(-1, 0);
  if (x < 0)
    x = rcache_allocate(0, 0);
  return x;
}

// maps a host register to a REG
static int rcache_map_reg(sh2_reg_e r, int hr)
{
#if REMAP_REGISTER
  int i;

  gconst_kill(r);

  // lookup the TEMP hr maps to
  i = reg_map_host[hr];
  if (i < 0) {
    // must not happen
    printf("invalid host register %d\n", hr);
    exit(1);
  }

  // remove old mappings of r and i if one exists
  if (guest_regs[r].vreg >= 0)
    rcache_remove_vreg_alias(guest_regs[r].vreg, r);
  if (cache_regs[i].type == HR_CACHED)
    rcache_evict_vreg(i);
  // set new mappping
  cache_regs[i].type = HR_CACHED;
  cache_regs[i].gregs = 1 << r;
  cache_regs[i].locked = 0;
  cache_regs[i].stamp = ++rcache_counter;
  cache_regs[i].flags |= HRF_DIRTY;
  rcache_lock_vreg(i);
  guest_regs[r].flags |= GRF_DIRTY;
  guest_regs[r].vreg = i;
#if DRC_DEBUG & 64
  RCACHE_CHECK("after map");
#endif
  return cache_regs[i].hreg;
#else
  return rcache_get_reg(r, RC_GR_WRITE, NULL);
#endif
}

// remap vreg from a TEMP to a REG if it will be used (upcoming TEMP invalidation)
static void rcache_remap_vreg(int x)
{
#if REMAP_REGISTER
  u32 rsl_d = rcache_regs_soon | rcache_regs_late;
  int d;

  // x must be a cached vreg
  if (cache_regs[x].type != HR_CACHED || cache_regs[x].locked)
    return;
  // don't do it if x isn't used
  if (!(rsl_d & cache_regs[x].gregs)) {
    // clean here to avoid data loss on invalidation
    rcache_clean_vreg(x);
    return;
  }

  FOR_ALL_BITS_SET_DO(cache_regs[x].gregs, d,
    if ((guest_regs[d].flags & (GRF_STATIC|GRF_PINNED)) &&
        !cache_regs[guest_regs[d].sreg].locked &&
        !((rsl_d|rcache_regs_now) & cache_regs[guest_regs[d].sreg].gregs)) {
      // STATIC not in its sreg and sreg is available
      rcache_evict_vreg(guest_regs[d].sreg);
      rcache_move_vreg(guest_regs[d].sreg, x);
      return;
    }
  )

  // allocate a non-TEMP vreg
  rcache_lock_vreg(x); // lock to avoid evicting x
  d = rcache_allocate_nontemp();
  rcache_unlock_vreg(x);
  if (d < 0) {
    rcache_clean_vreg(x);
    return;
  }

  // move vreg to new location
  rcache_move_vreg(d, x);
#if DRC_DEBUG & 64
  RCACHE_CHECK("after remap");
#endif
#else
  rcache_clean_vreg(x);
#endif
}

static void rcache_alias_vreg(sh2_reg_e rd, sh2_reg_e rs)
{
#if ALIAS_REGISTERS
  int x;

  // if s isn't constant, it must be in cache for aliasing
  if (!gconst_check(rs))
    rcache_get_reg_(rs, RC_GR_READ, 0, NULL);

  // if d and s are not already aliased
  x = guest_regs[rs].vreg;
  if (guest_regs[rd].vreg != x) {
    // remove possible old mapping of dst
    if (guest_regs[rd].vreg >= 0)
      rcache_remove_vreg_alias(guest_regs[rd].vreg, rd);
    // make dst an alias of src
    if (x >= 0)
      rcache_add_vreg_alias(x, rd);
    // if d is now in cache, it must be dirty
    if (guest_regs[rd].vreg >= 0) {
      x = guest_regs[rd].vreg;
      cache_regs[x].flags |= HRF_DIRTY;
      guest_regs[rd].flags |= GRF_DIRTY;
    }
  }

  gconst_copy(rd, rs);
#if DRC_DEBUG & 64
  RCACHE_CHECK("after alias");
#endif
#else
  int hr_s = rcache_get_reg(rs, RC_GR_READ, NULL);
  int hr_d = rcache_get_reg(rd, RC_GR_WRITE, NULL);

  emith_move_r_r(hr_d, hr_s);
  gconst_copy(rd, rs);
#endif
}

// note: must not be called when doing conditional code
static int rcache_get_reg_(sh2_reg_e r, rc_gr_mode mode, int do_locking, int *hr)
{
  int src, dst, ali;
  cache_reg_t *tr;
  u32 rsp_d = (rcache_regs_soon | rcache_regs_static | rcache_regs_pinned) &
               ~rcache_regs_discard;

  dst = src = guest_regs[r].vreg;

  rcache_lock_vreg(src); // lock to avoid evicting src
  // good opportunity to relocate a remapped STATIC?
  if ((guest_regs[r].flags & (GRF_STATIC|GRF_PINNED)) &&
      src != guest_regs[r].sreg && (src < 0 || mode != RC_GR_READ) &&
      !cache_regs[guest_regs[r].sreg].locked &&
      !((rsp_d|rcache_regs_now) & cache_regs[guest_regs[r].sreg].gregs)) {
    dst = guest_regs[r].sreg;
    rcache_evict_vreg(dst);
  } else if (dst < 0) {
    // allocate a cache register
    if ((dst = rcache_allocate_vreg(rsp_d & (1 << r))) < 0) {
      printf("no registers to evict, aborting\n");
      exit(1);
    }
  }
  tr = &cache_regs[dst];
  tr->stamp = rcache_counter;
  // remove r from src
  if (src >= 0 && src != dst)
    rcache_remove_vreg_alias(src, r);
  rcache_unlock_vreg(src);

  // if r has a constant it may have aliases
  if (mode != RC_GR_WRITE && gconst_try_read(dst, r))
    src = dst;

  // if r will be modified, check for aliases being needed rsn
  ali = tr->gregs & ~(1 << r);
  if (mode != RC_GR_READ && src == dst && ali) {
    int x = -1;
    if ((rsp_d|rcache_regs_now) & ali) {
      if ((guest_regs[r].flags & (GRF_STATIC|GRF_PINNED)) &&
          guest_regs[r].sreg == dst && !tr->locked) {
        // split aliases if r is STATIC in sreg and dst isn't already locked
        int t;
        FOR_ALL_BITS_SET_DO(ali, t,
          if ((guest_regs[t].flags & (GRF_STATIC|GRF_PINNED)) &&
              !(ali & ~(1 << t)) &&
              !cache_regs[guest_regs[t].sreg].locked &&
              !((rsp_d|rcache_regs_now) & cache_regs[guest_regs[t].sreg].gregs)) {
            // alias is a single STATIC and its sreg is available
            x = guest_regs[t].sreg;
            rcache_evict_vreg(x);
          } else {
            rcache_lock_vreg(dst); // lock to avoid evicting dst
            x = rcache_allocate_vreg(rsp_d & ali);
            rcache_unlock_vreg(dst);
          }
          break;
        )
        if (x >= 0) {
          rcache_remove_vreg_alias(src, r);
          src = dst;
          rcache_move_vreg(x, dst);
        }
      } else {
        // split r
        rcache_lock_vreg(src); // lock to avoid evicting src
        x = rcache_allocate_vreg(rsp_d & (1 << r));
        rcache_unlock_vreg(src);
        if (x >= 0) {
          rcache_remove_vreg_alias(src, r);
          dst = x;
          tr = &cache_regs[dst];
          tr->stamp = rcache_counter;
        }
      }
    }
    if (x < 0)
      // aliases not needed or no vreg available, remove them
      rcache_evict_vreg_aliases(dst, r);
  }

  // assign r to dst
  rcache_add_vreg_alias(dst, r);

  // handle dst register transfer
  if (src < 0 && mode != RC_GR_WRITE)
    emith_ctx_read(tr->hreg, r * 4);
  if (hr) {
    *hr = (src >= 0 ? cache_regs[src].hreg : tr->hreg);
    rcache_lock_vreg(src >= 0 ? src : dst);
  } else if (src >= 0 && mode != RC_GR_WRITE && cache_regs[src].hreg != tr->hreg)
    emith_move_r_r(tr->hreg, cache_regs[src].hreg);

  // housekeeping
  if (do_locking)
    rcache_lock_vreg(dst);
  if (mode != RC_GR_READ) {
    tr->flags |= HRF_DIRTY;
    guest_regs[r].flags |= GRF_DIRTY;
    gconst_kill(r);
    rcache_set_x16(tr->hreg, 0, 0);
  } else if (src >= 0 && cache_regs[src].hreg != tr->hreg)
    rcache_copy_x16(tr->hreg, cache_regs[src].hreg);
#if DRC_DEBUG & 64
  RCACHE_CHECK("after getreg");
#endif
  return tr->hreg;
}

static int rcache_get_reg(sh2_reg_e r, rc_gr_mode mode, int *hr)
{
  return rcache_get_reg_(r, mode, 1, hr);
}

static void rcache_pin_reg(sh2_reg_e r)
{
  int hr, x;

  // don't pin if static or already pinned
  if (guest_regs[r].flags & (GRF_STATIC|GRF_PINNED))
    return;

  rcache_regs_soon |= (1 << r); // kludge to prevent allocation of a temp
  hr = rcache_get_reg_(r, RC_GR_RMW, 0, NULL);
  x = reg_map_host[hr];

  // can only pin non-TEMPs
  if (!(cache_regs[x].htype & HRT_TEMP)) {
    guest_regs[r].flags |= GRF_PINNED;
    cache_regs[x].flags |= HRF_PINNED;
    guest_regs[r].sreg = x;
    rcache_regs_pinned |= (1 << r);
  }
#if DRC_DEBUG & 64
  RCACHE_CHECK("after pin");
#endif
}

static int rcache_get_tmp(void)
{
  int i;

  i = rcache_allocate_temp();
  if (i < 0) {
    printf("cannot allocate temp\n");
    exit(1);
  }

  cache_regs[i].type = HR_TEMP;
  rcache_lock_vreg(i);

  return cache_regs[i].hreg;
}

static int rcache_get_vreg_hr(int hr)
{
  int i;

  i = reg_map_host[hr];
  if (i < 0 || cache_regs[i].locked) {
    printf("host register %d is locked\n", hr);
    exit(1);
  }

  if (cache_regs[i].type == HR_CACHED)
    rcache_evict_vreg(i);
  else if (cache_regs[i].type == HR_TEMP && cache_regs[i].locked) {
    printf("host reg %d already used, aborting\n", hr);
    exit(1);
  }

  return i;
}

static int rcache_get_vreg_arg(int arg)
{
  int hr = 0;

  host_arg2reg(hr, arg);
  return rcache_get_vreg_hr(hr);
}

// get a reg to be used as function arg
static int rcache_get_tmp_arg(int arg)
{
  int x = rcache_get_vreg_arg(arg);
  cache_regs[x].type = HR_TEMP;
  rcache_lock_vreg(x);

  return cache_regs[x].hreg;
}

// ... as return value after a call
static int rcache_get_tmp_ret(void)
{
  int x = rcache_get_vreg_hr(RET_REG);
  cache_regs[x].type = HR_TEMP;
  rcache_lock_vreg(x);

  return cache_regs[x].hreg;
}

// same but caches a reg if access is readonly (announced by hr being NULL)
static int rcache_get_reg_arg(int arg, sh2_reg_e r, int *hr)
{
  int i, srcr, dstr, dstid, keep;
  u32 val;
  host_arg2reg(dstr, arg);

  i = guest_regs[r].vreg;
  if (i >= 0 && cache_regs[i].type == HR_CACHED && cache_regs[i].hreg == dstr)
    // r is already in arg, avoid evicting
    dstid = i;
  else
    dstid = rcache_get_vreg_arg(arg);
  dstr = cache_regs[dstid].hreg;

  if (rcache_is_cached(r)) {
    // r is needed later on anyway
    srcr = rcache_get_reg_(r, RC_GR_READ, 0, NULL);
    keep = 1;
  } else if ((guest_regs[r].flags & GRF_CDIRTY) && gconst_get(r, &val)) {
    // r has an uncomitted const - load into arg, but keep constant uncomitted
    srcr = dstr;
    emith_move_r_imm(srcr, val);
    keep = 0;
  } else {
    // must read from ctx
    srcr = dstr;
    emith_ctx_read(srcr, r * 4);
    keep = 1;
  }

  if (cache_regs[dstid].type == HR_CACHED)
    rcache_evict_vreg(dstid);

  cache_regs[dstid].type = HR_TEMP;
  if (hr == NULL) {
    if (dstr != srcr)
      // arg is a copy of cached r
      emith_move_r_r(dstr, srcr);
    else if (keep && guest_regs[r].vreg < 0)
      // keep arg as vreg for r
      rcache_add_vreg_alias(dstid, r);
  } else {
    *hr = srcr;
    if (dstr != srcr) // must lock srcr if not copied here
      rcache_lock_vreg(reg_map_host[srcr]);
  }

  cache_regs[dstid].stamp = ++rcache_counter;
  rcache_lock_vreg(dstid);
#if DRC_DEBUG & 64
  RCACHE_CHECK("after getarg");
#endif
  return dstr;
}

static void rcache_free_tmp(int hr)
{
  int i = reg_map_host[hr];

  if (i < 0 || cache_regs[i].type != HR_TEMP) {
    printf("rcache_free_tmp fail: #%i hr %d, type %d\n", i, hr, cache_regs[i].type);
    exit(1);
  }

  rcache_unlock_vreg(i);
}

// saves temporary result either in REG or in drctmp
static int rcache_save_tmp(int hr)
{
  int i;

  // find REG, either free or unlocked temp or oldest non-hinted cached
  i = rcache_allocate_nontemp();
  if (i < 0) {
    // if none is available, store in drctmp
    emith_ctx_write(hr, offsetof(SH2, drc_tmp));
    rcache_free_tmp(hr);
    return -1;
  }

  cache_regs[i].type = HR_CACHED;
  cache_regs[i].gregs = 0; // not storing any guest register
  cache_regs[i].flags &= HRF_PINNED;
  cache_regs[i].locked = 0;
  cache_regs[i].stamp = ++rcache_counter;
  rcache_lock_vreg(i);
  emith_move_r_r(cache_regs[i].hreg, hr);
  rcache_free_tmp(hr);
  return i;
}

static int rcache_restore_tmp(int x)
{
  int hr;

  // find REG with tmp store: cached but with no gregs
  if (x >= 0) {
    if (cache_regs[x].type != HR_CACHED || cache_regs[x].gregs) {
      printf("invalid tmp storage %d\n", x);
      exit(1);
    }
    // found, transform to a TEMP
    cache_regs[x].type = HR_TEMP;
    return cache_regs[x].hreg;
  }
 
  // if not available, create a TEMP store and fetch from drctmp
  hr = rcache_get_tmp();
  emith_ctx_read(hr, offsetof(SH2, drc_tmp));

  return hr;
}

static void rcache_free(int hr)
{
  int x = reg_map_host[hr];
  rcache_unlock_vreg(x);
}

static void rcache_unlock(int x)
{
  if (x >= 0)
    cache_regs[x].locked = 0;
}

static void rcache_unlock_all(void)
{
  int i;
  for (i = 0; i < ARRAY_SIZE(cache_regs); i++)
    cache_regs[i].locked = 0;
}

static void rcache_unpin_all(void)
{
  int i;

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) {
    if (guest_regs[i].flags & GRF_PINNED) {
      guest_regs[i].flags &= ~GRF_PINNED;
      cache_regs[guest_regs[i].sreg].flags &= ~HRF_PINNED;
      guest_regs[i].sreg = -1;
      rcache_regs_pinned &= ~(1 << i);
    }
  }
#if DRC_DEBUG & 64
  RCACHE_CHECK("after unpin");
#endif
}

static void rcache_save_pinned(void)
{
  int i;

  // save pinned regs to context
  for (i = 0; i < ARRAY_SIZE(guest_regs); i++)
    if ((guest_regs[i].flags & GRF_PINNED) && guest_regs[i].vreg >= 0)
      emith_ctx_write(cache_regs[guest_regs[i].vreg].hreg, i * 4);
}

static inline void rcache_set_usage_now(u32 mask)
{
  rcache_regs_now = mask;
}

static inline void rcache_set_usage_soon(u32 mask)
{
  rcache_regs_soon = mask;
}

static inline void rcache_set_usage_late(u32 mask)
{
  rcache_regs_late = mask;
}

static inline void rcache_set_usage_discard(u32 mask)
{
  rcache_regs_discard = mask;
}

static inline int rcache_is_cached(sh2_reg_e r)
{
  // is r in cache or needed RSN?
  u32 rsc = rcache_regs_soon | rcache_regs_clean;
  return (guest_regs[r].vreg >= 0 || (rsc & (1 << r)));
}

static inline int rcache_is_hreg_used(int hr)
{
  int x = reg_map_host[hr];
  // is hr in use?
  return cache_regs[x].type != HR_FREE &&
        (cache_regs[x].type != HR_TEMP || cache_regs[x].locked);
}

static inline u32 rcache_used_hregs_mask(void)
{
  u32 mask = 0;
  int i;

  for (i = 0; i < ARRAY_SIZE(cache_regs); i++)
    if ((cache_regs[i].htype & HRT_TEMP) && cache_regs[i].type != HR_FREE &&
        (cache_regs[i].type != HR_TEMP || cache_regs[i].locked))
      mask |= 1 << cache_regs[i].hreg;

  return mask;
}

static inline u32 rcache_dirty_mask(void)
{
  u32 mask = 0;
  int i;

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++)
    if (guest_regs[i].flags & GRF_DIRTY)
      mask |= 1 << i;
  mask |= gconst_dirty_mask();

  return mask;
}

static inline u32 rcache_cached_mask(void)
{
  u32 mask = 0;
  int i;

  for (i = 0; i < ARRAY_SIZE(cache_regs); i++)
    if (cache_regs[i].type == HR_CACHED)
      mask |= cache_regs[i].gregs;

  return mask;
}

static void rcache_clean_tmp(void)
{
  int i;

  rcache_regs_clean = (1 << ARRAY_SIZE(guest_regs)) - 1;
  for (i = 0; i < ARRAY_SIZE(cache_regs); i++)
    if (cache_regs[i].type == HR_CACHED && (cache_regs[i].htype & HRT_TEMP)) {
      rcache_unlock(i);
      rcache_remap_vreg(i);
    }
  rcache_regs_clean = 0;
}

static void rcache_clean_masked(u32 mask)
{
  int i, r, hr;
  u32 m;

  rcache_regs_clean |= mask;
  mask = rcache_regs_clean;

  // clean constants where all aliases are covered by the mask, exempt statics
  // to avoid flushing them to context if sreg isn't available
  m = mask & ~(rcache_regs_static | rcache_regs_pinned);
  for (i = 0; i < ARRAY_SIZE(gconsts); i++)
    if ((gconsts[i].gregs & m) && !(gconsts[i].gregs & ~mask)) {
      FOR_ALL_BITS_SET_DO(gconsts[i].gregs, r,
          if (guest_regs[r].flags & GRF_CDIRTY) {
            hr = rcache_get_reg_(r, RC_GR_READ, 0, NULL);
            rcache_clean_vreg(reg_map_host[hr]);
            break;
          });
    }
  // clean vregs where all aliases are covered by the mask
  for (i = 0; i < ARRAY_SIZE(cache_regs); i++)
    if (cache_regs[i].type == HR_CACHED &&
        (cache_regs[i].gregs & mask) && !(cache_regs[i].gregs & ~mask))
      rcache_clean_vreg(i);
}

static void rcache_clean(void)
{
  int i;
  gconst_clean();

  rcache_regs_clean = (1 << ARRAY_SIZE(guest_regs)) - 1;
  for (i = ARRAY_SIZE(cache_regs)-1; i >= 0; i--)
    if (cache_regs[i].type == HR_CACHED)
      rcache_clean_vreg(i);

  // relocate statics to their sregs (necessary before conditional jumps)
  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) {
    if ((guest_regs[i].flags & (GRF_STATIC|GRF_PINNED)) &&
          guest_regs[i].vreg != guest_regs[i].sreg) {
      rcache_lock_vreg(guest_regs[i].vreg);
      rcache_evict_vreg(guest_regs[i].sreg);
      rcache_unlock_vreg(guest_regs[i].vreg);
      if (guest_regs[i].vreg < 0)
        emith_ctx_read(cache_regs[guest_regs[i].sreg].hreg, i*4);
      else {
        emith_move_r_r(cache_regs[guest_regs[i].sreg].hreg,
                        cache_regs[guest_regs[i].vreg].hreg);
        rcache_copy_x16(cache_regs[guest_regs[i].sreg].hreg,
                        cache_regs[guest_regs[i].vreg].hreg);
        rcache_remove_vreg_alias(guest_regs[i].vreg, i);
      }
      cache_regs[guest_regs[i].sreg].gregs = 1 << i;
      cache_regs[guest_regs[i].sreg].type = HR_CACHED;
      cache_regs[guest_regs[i].sreg].flags |= HRF_DIRTY|HRF_PINNED;
      guest_regs[i].flags |= GRF_DIRTY;
      guest_regs[i].vreg = guest_regs[i].sreg;
    }
  }
  rcache_regs_clean = 0;
}

static void rcache_invalidate_tmp(void)
{
  int i;

  for (i = 0; i < ARRAY_SIZE(cache_regs); i++) {
    if (cache_regs[i].htype & HRT_TEMP) {
      rcache_unlock(i);
      if (cache_regs[i].type == HR_CACHED)
        rcache_evict_vreg(i);
      else
        rcache_free_vreg(i);
    }
  }
}

static void rcache_invalidate(void)
{
  int i;
  gconst_invalidate();
  rcache_unlock_all();

  for (i = 0; i < ARRAY_SIZE(cache_regs); i++)
    rcache_free_vreg(i);

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) {
    guest_regs[i].flags &= GRF_STATIC;
    if (!(guest_regs[i].flags & GRF_STATIC))
      guest_regs[i].vreg = -1;
    else {
      cache_regs[guest_regs[i].sreg].gregs = 1 << i;
      cache_regs[guest_regs[i].sreg].type = HR_CACHED;
      cache_regs[guest_regs[i].sreg].flags |= HRF_DIRTY|HRF_PINNED;
      guest_regs[i].flags |= GRF_DIRTY;
      guest_regs[i].vreg = guest_regs[i].sreg;
    }
  }

  rcache_counter = 0;
  rcache_regs_now = rcache_regs_soon = rcache_regs_late = 0;
  rcache_regs_discard = rcache_regs_clean = 0;
}

static void rcache_flush(void)
{
  rcache_clean();
  rcache_invalidate();
}

static void rcache_create(void)
{
  int x = 0, i;

  // create cache_regs as host register representation
  // RET_REG/params should be first TEMPs to avoid allocation conflicts in calls
  cache_regs[x++] = (cache_reg_t) {.hreg = RET_REG, .htype = HRT_TEMP};
  for (i = 0; i < ARRAY_SIZE(hregs_param); i++)
    if (hregs_param[i] != RET_REG)
      cache_regs[x++] = (cache_reg_t){.hreg = hregs_param[i],.htype = HRT_TEMP};

  for (i = 0; i < ARRAY_SIZE(hregs_temp); i++)
    if (hregs_temp[i] != RET_REG)
      cache_regs[x++] = (cache_reg_t){.hreg = hregs_temp[i], .htype = HRT_TEMP};

  for (i = ARRAY_SIZE(hregs_saved)-1; i >= 0; i--)
    if (hregs_saved[i] != CONTEXT_REG)
      cache_regs[x++] = (cache_reg_t){.hreg = hregs_saved[i], .htype = HRT_REG};

  if (x != ARRAY_SIZE(cache_regs)) {
    printf("rcache_create failed (conflicting register count)\n");
    exit(1);
  }

  // mapping from host_register to cache regs index
  memset(reg_map_host, -1, sizeof(reg_map_host));
  for (i = 0; i < ARRAY_SIZE(cache_regs); i++) {
    if (cache_regs[i].htype)
      reg_map_host[cache_regs[i].hreg] = i;
    if (cache_regs[i].htype == HRT_REG)
      rcache_vregs_reg |= (1 << i);
  }

  // create static host register mapping for SH2 regs
  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) {
    guest_regs[i] = (guest_reg_t){.sreg = -1};
  }
  for (i = 0; i < ARRAY_SIZE(regs_static); i += 2) {
    for (x = ARRAY_SIZE(cache_regs)-1; x >= 0; x--)
      if (cache_regs[x].hreg == regs_static[i+1])	break;
    if (x >= 0) {
      guest_regs[regs_static[i]] = (guest_reg_t){.flags = GRF_STATIC,.sreg = x};
      rcache_regs_static |= (1 << regs_static[i]);
      rcache_vregs_reg &= ~(1 << x);
    }
  }

  printf("DRC registers created, %ld host regs (%d REG, %d STATIC, 1 CTX)\n",
    CACHE_REGS+1L, count_bits(rcache_vregs_reg),count_bits(rcache_regs_static));
}

static void rcache_init(void)
{
  // create DRC data structures
  rcache_create();

  rcache_invalidate();
#if DRC_DEBUG & 64
  RCACHE_CHECK("after init");
#endif
}

// ---------------------------------------------------------------

// swap 32 bit value read from mem in generated code (same as CPU_BE2)
static void emit_le_swap(int cond, int r)
{
#if CPU_IS_LE
  if (cond == -1)
    emith_ror(r, r, 16);
  else
    emith_ror_c(cond, r, r, 16);
#endif
}

// fix memory byte ptr in generated code (same as MEM_BE2)
static void emit_le_ptr8(int cond, int r)
{
#if CPU_IS_LE
  if (cond == -1)
    emith_eor_r_imm_ptr(r, 1);
  else
    emith_eor_r_imm_ptr_c(cond, r, 1);
#endif
}

// split address by mask, in base part (upper) and offset (lower, signed!)
static uptr split_address(uptr la, uptr mask, s32 *offs)
{
  uptr sign = (mask>>1) + 1; // sign bit in offset
  *offs = (la & mask) | (la & sign ? ~mask : 0); // offset part, sign extended
  la = (la & ~mask) + ((la & sign) << 1); // base part, corrected for offs sign
#ifdef __arm__
  // arm32 offset has an add/sub flag and an unsigned 8 bit value, which only
  // allows values of [-255...255]. the value -256 thus can't be used.
  if (*offs < 0) {  // TODO not working at all with negative offsets on ARM?
  //if (*offs == -sign) {
    la -= sign;
    *offs += sign;
  }
#endif
  return la;
}

// NB may return either REG or TEMP
static int emit_get_rbase_and_offs(SH2 *sh2, sh2_reg_e r, int rmode, s32 *offs)
{
  uptr omask = emith_rw_offs_max(); // offset mask
  u32 mask = 0;
  u32 a;
  int poffs;
  int hr, hr2;
  uptr la;

  // is r constant and points to a memory region?
  if (! gconst_get(r, &a))
    return -1;
  poffs = dr_ctx_get_mem_ptr(sh2, a + *offs, &mask);
  if (poffs == -1)
    return -1;

  if (mask < 0x20000) {
    // data array, BIOS, DRAM, can't safely access directly since host addr may
    // change (BIOS,da code may run on either core, DRAM may be switched)
    hr = rcache_get_tmp();
    a = (a + *offs) & mask;
    if (poffs == offsetof(SH2, p_da)) {
      // access sh2->data_array directly
      a = split_address(a + offsetof(SH2, data_array), omask, offs);
      emith_add_r_r_ptr_imm(hr, CONTEXT_REG, a);
    } else {
      a = split_address(a, omask, offs);
      emith_ctx_read_ptr(hr, poffs);
      if (a)
        emith_add_r_r_ptr_imm(hr, hr, a);
    }
    return hr;
  }

  // ROM, SDRAM. Host address should be mmapped to be equal to SH2 address.
  la = (uptr)*(void **)((char *)sh2 + poffs);

  // if r is in rcache or needed soon anyway, and offs is relative to region,
  // and address translation fits in add_ptr_imm (s32), then use rcached const 
  if (la == (s32)la && !(((a & mask) + *offs) & ~mask) && rcache_is_cached(r)) {
#if CPU_IS_LE // need to fix odd address for correct byte addressing
    if (a & 1) *offs += (*offs&1) ? 2 : -2;
#endif
    la -= (s32)((a & ~mask) - *offs); // diff between reg and memory
    hr = hr2 = rcache_get_reg(r, rmode, NULL);
    if ((s32)a < 0) emith_uext_ptr(hr2);
    la = split_address(la, omask, offs);
    if (la) {
      hr = rcache_get_tmp();
      emith_add_r_r_ptr_imm(hr, hr2, la);
      rcache_free(hr2);
    }
  } else {
    // known fixed host address
    la = split_address(la + ((a + *offs) & mask), omask, offs);
    if (la == 0) {
      // offset only. optimize for hosts having short indexed addressing
      la = *offs & ~0x7f;  // keep the lower bits for endianess handling
      *offs &= 0x7f;
    }
    hr = rcache_get_tmp();
    emith_move_r_ptr_imm(hr, la);
  }
  return hr;
}

// read const data from const ROM address
static int emit_get_rom_data(SH2 *sh2, sh2_reg_e r, s32 offs, int size, u32 *val)
{
  u32 a, mask;

  *val = 0;
  if (gconst_get(r, &a)) {
    a += offs;
    // check if rom is memory mapped (not bank switched), and address is in rom
    if (p32x_sh2_mem_is_rom(a, sh2) && p32x_sh2_get_mem_ptr(a, &mask, sh2) == sh2->p_rom) {
      switch (size & MF_SIZEMASK) {
      case 0:   *val = (s8)p32x_sh2_read8(a, sh2s);   break;  // 8
      case 1:   *val = (s16)p32x_sh2_read16(a, sh2s); break;  // 16
      case 2:   *val = p32x_sh2_read32(a, sh2s);      break;  // 32
      }
      return 1;
    }
  }
  return 0;
}

static void emit_move_r_imm32(sh2_reg_e dst, u32 imm)
{
#if PROPAGATE_CONSTANTS
  gconst_new(dst, imm);
#else
  int hr = rcache_get_reg(dst, RC_GR_WRITE, NULL);
  emith_move_r_imm(hr, imm);
#endif
}

static void emit_move_r_r(sh2_reg_e dst, sh2_reg_e src)
{
  if (gconst_check(src) || rcache_is_cached(src))
    rcache_alias_vreg(dst, src);
  else {
    int hr_d = rcache_get_reg(dst, RC_GR_WRITE, NULL);
    emith_ctx_read(hr_d, src * 4);
  }
}

static void emit_add_r_imm(sh2_reg_e r, u32 imm)
{
  u32 val;
  int isgc = gconst_get(r, &val);
  int hr, hr2;

  if (!isgc || rcache_is_cached(r)) {
    // not constant, or r is already in cache
    hr = rcache_get_reg(r, RC_GR_RMW, &hr2);
    emith_add_r_r_imm(hr, hr2, imm);
    rcache_free(hr2);
    if (isgc)
      gconst_set(r, val + imm);
  } else
    gconst_new(r, val + imm);
}

static void emit_sub_r_imm(sh2_reg_e r, u32 imm)
{
  u32 val;
  int isgc = gconst_get(r, &val);
  int hr, hr2;

  if (!isgc || rcache_is_cached(r)) {
    // not constant, or r is already in cache
    hr = rcache_get_reg(r, RC_GR_RMW, &hr2);
    emith_sub_r_r_imm(hr, hr2, imm);
    rcache_free(hr2);
    if (isgc)
      gconst_set(r, val - imm);
  } else
    gconst_new(r, val - imm);
}

static void emit_sync_t_to_sr(void)
{
  // avoid reloading SR from context if there's nothing to do
  if (emith_get_t_cond() >= 0) {
    int sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
    emith_sync_t(sr);
  }
}

// rd = @(arg0)
static int emit_memhandler_read(int size)
{
  int hr;

  emit_sync_t_to_sr();
  rcache_clean_tmp();
#ifndef DRC_SR_REG
  // must writeback cycles for poll detection stuff
  if (guest_regs[SHR_SR].vreg != -1)
    rcache_unmap_vreg(guest_regs[SHR_SR].vreg);
#endif
  rcache_invalidate_tmp();

  if (size & MF_POLLING)
    switch (size & MF_SIZEMASK) {
    case 0:   emith_call(sh2_drc_read8_poll);   break; // 8
    case 1:   emith_call(sh2_drc_read16_poll);  break; // 16
    case 2:   emith_call(sh2_drc_read32_poll);  break; // 32
    }
  else
    switch (size & MF_SIZEMASK) {
    case 0:   emith_call(sh2_drc_read8);        break; // 8
    case 1:   emith_call(sh2_drc_read16);       break; // 16
    case 2:   emith_call(sh2_drc_read32);       break; // 32
    }

  hr = rcache_get_tmp_ret();
  rcache_set_x16(hr, (size & MF_SIZEMASK) < 2, 0);
  return hr;
}

// @(arg0) = arg1
static void emit_memhandler_write(int size)
{
  emit_sync_t_to_sr();
  rcache_clean_tmp();
#ifndef DRC_SR_REG
  if (guest_regs[SHR_SR].vreg != -1)
    rcache_unmap_vreg(guest_regs[SHR_SR].vreg);
#endif
  rcache_invalidate_tmp();

  switch (size & MF_SIZEMASK) {
  case 0:   emith_call(sh2_drc_write8);     break;  // 8
  case 1:   emith_call(sh2_drc_write16);    break;  // 16
  case 2:   emith_call(sh2_drc_write32);    break;  // 32
  }
}

// rd = @(Rs,#offs); rd < 0 -> return a temp
static int emit_memhandler_read_rr(SH2 *sh2, sh2_reg_e rd, sh2_reg_e rs, s32 offs, int size)
{
  int hr, hr2;
  u32 val;

#if PROPAGATE_CONSTANTS
  if (emit_get_rom_data(sh2, rs, offs, size, &val)) {
    if (rd == SHR_TMP) {
      hr2 = rcache_get_tmp();
      emith_move_r_imm(hr2, val);
    } else {
      emit_move_r_imm32(rd, val);
      hr2 = rcache_get_reg(rd, RC_GR_RMW, NULL);
    }
    rcache_set_x16(hr2, val == (s16)val, val == (u16)val);
    if (size & MF_POSTINCR)
      emit_add_r_imm(rs, 1 << (size & MF_SIZEMASK));
    return hr2;
  }

  val = size & MF_POSTINCR;
  hr = emit_get_rbase_and_offs(sh2, rs, val ? RC_GR_RMW : RC_GR_READ, &offs);
  if (hr != -1) {
    if (rd == SHR_TMP)
      hr2 = rcache_get_tmp();
    else
      hr2 = rcache_get_reg(rd, RC_GR_WRITE, NULL);
    switch (size & MF_SIZEMASK) {
    case 0: emith_read8s_r_r_offs(hr2, hr, MEM_BE2(offs));  break; // 8
    case 1: emith_read16s_r_r_offs(hr2, hr, offs);          break; // 16
    case 2: emith_read_r_r_offs(hr2, hr, offs); emit_le_swap(-1, hr2); break;
    }
    rcache_free(hr);
    if (size & MF_POSTINCR)
      emit_add_r_imm(rs, 1 << (size & MF_SIZEMASK));
    return hr2;
  }
#endif

  if (gconst_get(rs, &val) && !rcache_is_cached(rs)) {
    hr = rcache_get_tmp_arg(0);
    emith_move_r_imm(hr, val + offs);
    if (size & MF_POSTINCR)
      gconst_new(rs, val + (1 << (size & MF_SIZEMASK)));
  } else if (size & MF_POSTINCR) {
    hr = rcache_get_tmp_arg(0);
    hr2 = rcache_get_reg(rs, RC_GR_RMW, NULL);
    emith_add_r_r_imm(hr, hr2, offs);
    emith_add_r_imm(hr2, 1 << (size & MF_SIZEMASK));
    if (gconst_get(rs, &val))
      gconst_set(rs, val + (1 << (size & MF_SIZEMASK)));
  } else {
    hr = rcache_get_reg_arg(0, rs, &hr2);
    if (offs || hr != hr2)
      emith_add_r_r_imm(hr, hr2, offs);
  }
  hr = emit_memhandler_read(size);

  if (rd == SHR_TMP)
    hr2 = hr;
  else
    hr2 = rcache_map_reg(rd, hr);

  if (hr != hr2) {
    emith_move_r_r(hr2, hr);
    rcache_free_tmp(hr);
  }
  return hr2;
}

// @(Rs,#offs) = rd; rd < 0 -> write arg1
static void emit_memhandler_write_rr(SH2 *sh2, sh2_reg_e rd, sh2_reg_e rs, s32 offs, int size)
{
  int hr, hr2;
  u32 val;

  if (rd == SHR_TMP) {
    host_arg2reg(hr2, 1); // already locked and prepared by caller
  } else if ((size & MF_PREDECR) && rd == rs) { // must avoid caching rd in arg1
    hr2 = rcache_get_reg_arg(1, rd, &hr);
    if (hr != hr2) {
      emith_move_r_r(hr2, hr);
      rcache_free(hr2);
    }
  } else
    hr2 = rcache_get_reg_arg(1, rd, NULL);
  if (rd != SHR_TMP)
    rcache_unlock(guest_regs[rd].vreg); // unlock in case rd is in arg0

  if (gconst_get(rs, &val) && !rcache_is_cached(rs)) {
    hr = rcache_get_tmp_arg(0);
    if (size & MF_PREDECR) {
      val -= 1 << (size & MF_SIZEMASK);
      gconst_new(rs, val);
    }
    emith_move_r_imm(hr, val + offs);
  } else if (offs || (size & MF_PREDECR)) {
    if (size & MF_PREDECR)
      emit_sub_r_imm(rs, 1 << (size & MF_SIZEMASK));
    rcache_unlock(guest_regs[rs].vreg); // unlock in case rs is in arg0
    hr = rcache_get_reg_arg(0, rs, &hr2);
    if (offs || hr != hr2)
      emith_add_r_r_imm(hr, hr2, offs);
  } else
    hr = rcache_get_reg_arg(0, rs, NULL);

  emit_memhandler_write(size);
}

// rd = @(Rx,Ry); rd < 0 -> return a temp
static int emit_indirect_indexed_read(SH2 *sh2, sh2_reg_e rd, sh2_reg_e rx, sh2_reg_e ry, int size)
{
  int hr, hr2;
  int tx, ty;
#if PROPAGATE_CONSTANTS
  u32 offs;

  // if offs is larger than 0x01000000, it's most probably the base address part
  if (gconst_get(ry, &offs) && offs < 0x01000000)
    return emit_memhandler_read_rr(sh2, rd, rx, offs, size);
  if (gconst_get(rx, &offs) && offs < 0x01000000)
    return emit_memhandler_read_rr(sh2, rd, ry, offs, size);
#endif
  hr = rcache_get_reg_arg(0, rx, &tx);
  ty = rcache_get_reg(ry, RC_GR_READ, NULL);
  emith_add_r_r_r(hr, tx, ty);
  hr = emit_memhandler_read(size);

  if (rd == SHR_TMP)
    hr2 = hr;
  else
    hr2 = rcache_map_reg(rd, hr);

  if (hr != hr2) {
    emith_move_r_r(hr2, hr);
    rcache_free_tmp(hr);
  }
  return hr2;
}

// @(Rx,Ry) = rd; rd < 0 -> write arg1
static void emit_indirect_indexed_write(SH2 *sh2, sh2_reg_e rd, sh2_reg_e rx, sh2_reg_e ry, int size)
{
  int hr, tx, ty;
#if PROPAGATE_CONSTANTS
  u32 offs;

  // if offs is larger than 0x01000000, it's most probably the base address part
  if (gconst_get(ry, &offs) && offs < 0x01000000)
    return emit_memhandler_write_rr(sh2, rd, rx, offs, size);
  if (gconst_get(rx, &offs) && offs < 0x01000000)
    return emit_memhandler_write_rr(sh2, rd, ry, offs, size);
#endif
  if (rd != SHR_TMP)
    rcache_get_reg_arg(1, rd, NULL);
  hr = rcache_get_reg_arg(0, rx, &tx);
  ty = rcache_get_reg(ry, RC_GR_READ, NULL);
  emith_add_r_r_r(hr, tx, ty);
  emit_memhandler_write(size);
}

// @Rn+,@Rm+
static void emit_indirect_read_double(SH2 *sh2, int *rnr, int *rmr, sh2_reg_e rn, sh2_reg_e rm, int size)
{
  int tmp;

  // unlock rn, rm here to avoid REG shortage in MAC operation
  tmp = emit_memhandler_read_rr(sh2, SHR_TMP, rn, 0, size | MF_POSTINCR);
  rcache_unlock(guest_regs[rn].vreg);
  tmp = rcache_save_tmp(tmp);
  *rmr = emit_memhandler_read_rr(sh2, SHR_TMP, rm, 0, size | MF_POSTINCR);
  rcache_unlock(guest_regs[rm].vreg);
  *rnr = rcache_restore_tmp(tmp);
}
 
static void emit_do_static_regs(int is_write, int tmpr)
{
  int i, r, count;

  for (i = 0; i < ARRAY_SIZE(guest_regs); i++) {
    if (guest_regs[i].flags & (GRF_STATIC|GRF_PINNED))
      r = cache_regs[guest_regs[i].vreg].hreg;
    else
      continue;

    for (count = 1; i < ARRAY_SIZE(guest_regs) - 1; i++, r++) {
      if ((guest_regs[i + 1].flags & (GRF_STATIC|GRF_PINNED)) &&
          cache_regs[guest_regs[i + 1].vreg].hreg == r + 1)
        count++;
      else
        break;
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

#if DIV_OPTIMIZER
// divide operation replacement functions, called by compiled code. Only the
// 32:16 cases and the 64:32 cases described in the SH2 prog man are replaced.

// This is surprisingly difficult since the SH2 division operation is generating
// the result in the dividend during the operation, leaving some remainder-like
// stuff in the bits unused for the result, and leaving the T and Q status bits
// in a state depending on the operands and the result. Q always reflects the
// last result bit generated (i.e. bit 0 of the result). For T:
//	32:16	T = top bit of the 16 bit remainder-like
//	64:32	T = resulting T of the DIV0U/S operation
// The remainder-like depends on outcome of the last generated result bit.

static uint32_t REGPARM(3) sh2_drc_divu32(uint32_t dv, uint32_t *dt, uint32_t ds)
{
  if (likely(ds > dv && (uint16_t)ds == 0)) {
    // good case: no overflow, divisor not 0, lower 16 bits 0
    uint32_t quot = dv / (ds>>16), rem = dv - (quot * (ds>>16));
    if (~quot&1) rem -= ds>>16;
    *dt = (rem>>15) & 1;
    return (uint16_t)quot | ((2*rem + (quot>>31)) << 16);
  } else {
    // bad case: use the sh2 algo to get the right result
    int q = 0, t = 0, s = 16;
    while (s--) {
      uint32_t v = dv>>31;
      dv = (dv<<1) | t;
      t = v;
      v = dv;
      if (q)  dv += ds, q = dv < v;
      else    dv -= ds, q = dv > v;
      q ^= t, t = !q;
    }
    *dt = dv>>31;
    return (dv<<1) | t;
  }
}

static uint32_t REGPARM(3) sh2_drc_divu64(uint32_t dh, uint32_t *dl, uint32_t ds)
{
  uint64_t dv = *dl | ((uint64_t)dh << 32);
  if (likely(ds > dh)) {
    // good case: no overflow, divisor not 0
    uint32_t quot = dv / ds, rem = dv - ((uint64_t)quot * ds);
    if (~quot&1) rem -= ds;
    *dl = quot;
    return rem;
  } else {
    // bad case: use the sh2 algo to get the right result
    int q = 0, t = 0, s = 32;
    while (s--) {
      uint64_t v = dv>>63;
      dv = (dv<<1) | t;
      t = v;
      v = dv;
      if (q)  dv += ((uint64_t)ds << 32), q = dv < v;
      else    dv -= ((uint64_t)ds << 32), q = dv > v;
      q ^= t, t = !q;
    }
    *dl = (dv<<1) | t;
    return (dv>>32);
  }
}

static uint32_t REGPARM(3) sh2_drc_divs32(int32_t dv, uint32_t *dt, int32_t ds)
{
  uint32_t adv = abs(dv), ads = abs(ds)>>16;
  if (likely(ads > adv>>16 && ds != 0x80000000 && (int16_t)ds == 0)) {
    // good case: no overflow, divisor not 0 and not MIN_INT, lower 16 bits 0
    uint32_t quot = adv / ads, rem = adv - (quot * ads);
    int m1 = (rem ? dv^ds : ds) < 0;
    if (rem && dv < 0)  rem = (quot&1 ? -rem : +ads-rem);
    else                rem = (quot&1 ? +rem : -ads+rem);
    quot = ((dv^ds)<0 ? -quot : +quot) - m1;
    *dt = (rem>>15) & 1;
    return (uint16_t)quot | ((2*rem + (quot>>31)) << 16);
  } else {
    // bad case: use the sh2 algo to get the right result
    int m = (uint32_t)ds>>31, q = (uint32_t)dv>>31, t = m^q, s = 16;
    while (s--) {
      uint32_t v = (uint32_t)dv>>31;
      dv = (dv<<1) | t;
      t = v;
      v = dv;
      if (m^q)  dv += ds, q = (uint32_t)dv < v;
      else      dv -= ds, q = (uint32_t)dv > v;
      q ^= m^t, t = !(m^q);
    }
    *dt = (uint32_t)dv>>31;
    return (dv<<1) | t;
  }
}

static uint32_t REGPARM(3) sh2_drc_divs64(int32_t dh, uint32_t *dl, int32_t ds)
{
  int64_t _dv = *dl | ((int64_t)dh << 32);
  uint32_t ads = abs(ds);
  if (likely(_dv >= 0 && ads > _dv>>32 && ds != 0x80000000) ||
      likely(_dv < 0 && ads > -_dv>>32 && ds != 0x80000000)) {
    uint64_t adv = (_dv < 0 ? -_dv : _dv); // no llabs in older toolchains
    // good case: no overflow, divisor not 0 and not MIN_INT
    uint32_t quot = adv / ads, rem = adv - ((uint64_t)quot * ads);
    int m1 = (rem ? dh^ds : ds) < 0;
    if (rem && dh < 0) rem = (quot&1 ? -rem : +ads-rem);
    else               rem = (quot&1 ? +rem : -ads+rem);
    quot = ((dh^ds)<0 ? -quot : +quot) - m1;
    *dl = quot;
    return rem;
  } else {
    // bad case: use the sh2 algo to get the right result
    uint64_t dv = (uint64_t)_dv;
    int m = (uint32_t)ds>>31, q = (uint64_t)dv>>63, t = m^q, s = 32;
    while (s--) {
      uint64_t v = (uint64_t)dv>>63;
      dv = (dv<<1) | t;
      t = v;
      v = dv;
      if (m^q)  dv += ((uint64_t)ds << 32), q = dv < v;
      else      dv -= ((uint64_t)ds << 32), q = dv > v;
      q ^= m^t, t = !(m^q);
    }
    *dl = (dv<<1) | t;
    return (dv>>32);
  }
}
#endif

// block local link stuff
struct linkage {
  u32 pc;
  void *ptr;
  struct block_link *bl;
  u32 mask;
};

static inline int find_in_linkage(const struct linkage *array, int size, u32 pc)
{
  size_t i;
  for (i = 0; i < size; i++)
    if (pc == array[i].pc)
      return i;

  return -1;
}

static int find_in_sorted_linkage(const struct linkage *array, int size, u32 pc)
{
  // binary search in sorted array
  int left = 0, right = size-1;
  while (left <= right)
  {
    int middle = (left + right) / 2;
    if (array[middle].pc == pc)
      return middle;
    else if (array[middle].pc < pc)
      left = middle + 1;
    else
      right = middle - 1;
  }
  return -1;
}

static void emit_branch_linkage_code(SH2 *sh2, struct block_desc *block, int tcache_id,
                                const struct linkage *targets, int target_count,
                                const struct linkage *links, int link_count)
{
  struct block_link *bl;
  int u, v, tmp;

  emith_flush();
  for (u = 0; u < link_count; u++) {
    emith_pool_check();
    // look up local branch targets
    if (links[u].mask & 0x2) {
      v = find_in_sorted_linkage(targets, target_count, links[u].pc);
      if (v < 0 || ! targets[v].ptr) {
        // forward branch not yet resolved, prepare external linking
        emith_jump_patch(links[u].ptr, tcache_ptr, NULL);
        bl = dr_prepare_ext_branch(block->entryp, links[u].pc, sh2->is_slave, tcache_id);
        if (bl)
          bl->type = BL_LDJMP;
        tmp = rcache_get_tmp_arg(0);
        emith_move_r_imm(tmp, links[u].pc);
        rcache_free_tmp(tmp);
        emith_jump_patchable(sh2_drc_dispatcher);
      } else if (emith_jump_patch_inrange(links[u].ptr, targets[v].ptr)) {
        // inrange local branch
        emith_jump_patch(links[u].ptr, targets[v].ptr, NULL);
      } else {
        // far local branch
        emith_jump_patch(links[u].ptr, tcache_ptr, NULL);
        emith_jump(targets[v].ptr);
      }
    } else {
      // external or exit, emit blx area entry
      void *target = (links[u].mask & 0x1 ? sh2_drc_exit : sh2_drc_dispatcher);
      if (links[u].bl)
        links[u].bl->blx = tcache_ptr;
      emith_jump_patch(links[u].ptr, tcache_ptr, NULL);
      tmp = rcache_get_tmp_arg(0);
      emith_move_r_imm(tmp, links[u].pc & ~1);
      rcache_free_tmp(tmp);
      emith_jump(target);
    }
  }
}

#define DELAY_SAVE_T(sr) { \
  int t_ = rcache_get_tmp(); \
  emith_bic_r_imm(sr, T_save); \
  emith_and_r_r_imm(t_, sr, 1); \
  emith_or_r_r_lsl(sr, t_, T_SHIFT); \
  rcache_free_tmp(t_); \
}

#define FLUSH_CYCLES(sr) \
  if (cycles > 0) \
    emith_sub_r_imm(sr, cycles << 12); \
  else if (cycles < 0) /* may happen after a branch not taken */ \
    emith_add_r_imm(sr, -cycles << 12); \
  cycles = 0; \

static void *dr_get_pc_base(u32 pc, SH2 *sh2);
static void sh2_smc_rm_blocks(u32 a, int len, int tcache_id, int free);

static void REGPARM(2) *sh2_translate(SH2 *sh2, int tcache_id)
{
  // branch targets in current block
  static struct linkage branch_targets[MAX_LOCAL_TARGETS];
  int branch_target_count = 0;
  // unresolved local or external targets with block link/exit area if needed
  static struct linkage blx_targets[MAX_LOCAL_BRANCHES];
  int blx_target_count = 0;

  static u8 op_flags[BLOCK_INSN_LIMIT];

  enum flg_states { FLG_UNKNOWN, FLG_UNUSED, FLG_0, FLG_1 };
  struct drcf {
    int delay_reg:8;
    u32 loop_type:8;
    u32 polling:8;
    u32 pinning:1;
    u32 test_irq:1;
    u32 pending_branch_direct:1;
    u32 pending_branch_indirect:1;
    u32 Tflag:2, Mflag:2;
  } drcf = { 0, };

#if LOOP_OPTIMIZER
  // loops with pinned registers for optimzation
  // pinned regs are like statics and don't need saving/restoring inside a loop
  static struct linkage pinned_loops[MAX_LOCAL_TARGETS/16];
  int pinned_loop_count = 0;
#endif

  // PC of current, first, last SH2 insn
  u32 pc, base_pc, end_pc;
  u32 base_literals, end_literals;
  u8 *block_entry_ptr;
  struct block_desc *block;
  struct block_entry *entry;
  struct block_link *bl;
  u16 *dr_pc_base;
  struct op_data *opd;
  int blkid_main = 0;
  int skip_op = 0;
  int tmp, tmp2;
  int cycles;
  int i, v;
  u32 u, m1, m2, m3, m4;
  int op;
  u16 crc;

  base_pc = sh2->pc;

  // get base/validate PC
  dr_pc_base = dr_get_pc_base(base_pc, sh2);
  if (dr_pc_base == (void *)-1) {
    printf("invalid PC, aborting: %08lx\n", (long)base_pc);
    // FIXME: be less destructive
    exit(1);
  }

  // initial passes to disassemble and analyze the block
  crc = scan_block(base_pc, sh2->is_slave, op_flags, &end_pc, &base_literals, &end_literals);
  end_literals = dr_check_nolit(base_literals, end_literals, tcache_id);
  if (base_literals == end_literals) // map empty lit section to end of code
    base_literals = end_literals = end_pc;

  // if there is already a translated but inactive block, reuse it
  block = dr_find_inactive_block(tcache_id, crc, base_pc, end_pc - base_pc,
    base_literals, end_literals - base_literals);

#if (DRC_DEBUG & (256|512))
  // remove any (partial) old blocks which might get in the way, to make sure
  // the same branch targets are used in the recording/playback code. Not needed
  // normally since the SH2 code wasn't overwritten and should be the same.
  sh2_smc_rm_blocks(base_pc, end_pc - base_pc, tcache_id, 0);
#endif

  if (block) {
    dbg(2, "== %csh2 reuse block %08x-%08x,%08x-%08x -> %p", sh2->is_slave ? 's' : 'm',
      base_pc, end_pc, base_literals, end_literals, block->entryp->tcache_ptr);
    dr_activate_block(block, tcache_id, sh2->is_slave);
    emith_update_cache();
    return block->entryp[0].tcache_ptr;
  }

  // collect branch_targets that don't land on delay slots
  m1 = m2 = m3 = m4 = v = op = 0;
  for (pc = base_pc, i = 0; pc < end_pc; i++, pc += 2) {
    if (op_flags[i] & OF_DELAY_OP)
      op_flags[i] &= ~OF_BTARGET;
    if (op_flags[i] & OF_BTARGET) {
      if (branch_target_count < ARRAY_SIZE(branch_targets))
        branch_targets[branch_target_count++] = (struct linkage) { .pc = pc };
      else {
        printf("warning: linkage overflow\n");
        end_pc = pc;
        break;
      }
    }
    if (ops[i].op == OP_LDC && (ops[i].dest & BITMASK1(SHR_SR)) && pc+2 < end_pc)
      op_flags[i+1] |= OF_BTARGET; // RTE entrypoint in case of SR.IMASK change
    // unify T and SR since rcache doesn't know about "virtual" guest regs
    if (ops[i].source & BITMASK1(SHR_T))  ops[i].source |= BITMASK1(SHR_SR);
    if (ops[i].dest   & BITMASK1(SHR_T))  ops[i].source |= BITMASK1(SHR_SR);
    if (ops[i].dest   & BITMASK1(SHR_T))  ops[i].dest   |= BITMASK1(SHR_SR);
#if LOOP_DETECTION
    // loop types detected:
    // 1. target: ... BRA target -> idle loop
    // 2. target: ... delay insn ... BF target -> delay loop
    // 3. target: ... poll  insn ... BF/BT target -> poll loop
    // 4. target: ... poll  insn ... BF/BT exit ... BRA target, exit: -> poll
    // conditions:
    // a. no further branch targets between target and back jump.
    // b. no unconditional branch insn inside the loop.
    // c. exactly one poll or delay insn is allowed inside a delay/poll loop
    // (scan_block marks loops only if they meet conditions a through c)
    // d. idle loops do not modify anything but PC,SR and contain no branches
    // e. delay/poll loops do not modify anything but the concerned reg,PC,SR
    // f. loading constants into registers inside the loop is allowed
    // g. a delay/poll loop must have a conditional branch somewhere
    // h. an idle loop must not have a conditional branch
    if (op_flags[i] & OF_BTARGET) {
      // possible loop entry point
      drcf.loop_type = op_flags[i] & OF_LOOP;
      drcf.pending_branch_direct = drcf.pending_branch_indirect = 0;
      op = OF_IDLE_LOOP; // loop type
      v = i;
      m1 = m2 = m3 = m4 = 0;
      if (!drcf.loop_type)   // reset basic loop it it isn't recognized as loop
        op_flags[i] &= ~OF_BASIC_LOOP;
    }
    if (drcf.loop_type) {
      // calculate reg masks for loop pinning
      m4 |= ops[i].source & ~m3;
      m3 |= ops[i].dest;
      // detect loop type, and store poll/delay register
      if (op_flags[i] & OF_POLL_INSN) {
        op = OF_POLL_LOOP;
        m1 |= ops[i].dest;   // loop poll/delay regs
      } else if (op_flags[i] & OF_DELAY_INSN) {
        op = OF_DELAY_LOOP;
        m1 |= ops[i].dest;
      } else if (ops[i].op != OP_LOAD_POOL && ops[i].op != OP_LOAD_CONST
              && (ops[i].op != OP_MOVE || op != OF_POLL_LOOP)) {
        // not (MOV @(PC) or MOV # or (MOV reg and poll)),   condition f
        m2 |= ops[i].dest;   // regs modified by other insns
      }
      // branch detector
      if (OP_ISBRAIMM(ops[i].op)) {
        if (ops[i].imm == base_pc + 2*v)
          drcf.pending_branch_direct = 1;       // backward branch detected
        else
          op_flags[v] &= ~OF_BASIC_LOOP;        // no basic loop
      }
      if (OP_ISBRACND(ops[i].op))
        drcf.pending_branch_indirect = 1;       // conditions g,h - cond.branch
      // poll/idle loops terminate with their backwards branch to the loop start
      if (drcf.pending_branch_direct && !(op_flags[i+1] & OF_DELAY_OP)) {
        m2 &= ~(m1 | BITMASK3(SHR_PC, SHR_SR, SHR_T)); // conditions d,e + g,h
        if (m2 || ((op == OF_IDLE_LOOP) == (drcf.pending_branch_indirect)))
          op = 0;                               // conditions not met
        op_flags[v] = (op_flags[v] & ~OF_LOOP) | op; // set loop type
        drcf.loop_type = 0;
#if LOOP_OPTIMIZER
        if (op_flags[v] & OF_BASIC_LOOP) {
          m3 &= ~rcache_regs_static & ~BITMASK5(SHR_PC, SHR_PR, SHR_SR, SHR_T, SHR_MEM);
          if (m3 && count_bits(m3) < count_bits(rcache_vregs_reg) &&
              pinned_loop_count < ARRAY_SIZE(pinned_loops)-1) {
            pinned_loops[pinned_loop_count++] =
                (struct linkage) { .pc = base_pc + 2*v, .mask = m3 };
          } else
            op_flags[v] &= ~OF_BASIC_LOOP;
        }
#endif
      }
    }
#endif
  }

  tcache_ptr = dr_prepare_cache(tcache_id, (end_pc - base_pc) / 2, branch_target_count);
#if (DRC_DEBUG & 4)
  tcache_dsm_ptrs[tcache_id] = tcache_ptr;
#endif

  block = dr_add_block(branch_target_count, base_pc, end_pc - base_pc,
    base_literals, end_literals-base_literals, crc, sh2->is_slave, &blkid_main);
  if (block == NULL)
    return NULL;

  block_entry_ptr = tcache_ptr;
  dbg(2, "== %csh2 block #%d,%d %08x-%08x,%08x-%08x -> %p", sh2->is_slave ? 's' : 'm',
    tcache_id, blkid_main, base_pc, end_pc, base_literals, end_literals, block_entry_ptr);


  // clear stale state after compile errors
  rcache_invalidate();
  emith_invalidate_t();
  drcf = (struct drcf) { 0 };
#if LOOP_OPTIMIZER
  pinned_loops[pinned_loop_count].pc = -1;
  pinned_loop_count = 0;
#endif

  // -------------------------------------------------
  // 3rd pass: actual compilation
  pc = base_pc;
  cycles = 0;
  for (i = 0; pc < end_pc; i++)
  {
    u32 delay_dep_fw = 0, delay_dep_bk = 0;
    int tmp3, tmp4;
    int sr;

    if (op_flags[i] & OF_BTARGET)
    {
      if (pc != base_pc)
      {
        sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        emith_sync_t(sr);
        drcf.Mflag = FLG_UNKNOWN;
        rcache_flush();
        emith_flush();
      }

      // make block entry
      v = block->entry_count;
      entry = &block->entryp[v];
      if (v < branch_target_count)
      {
        entry = &block->entryp[v];
        entry->pc = pc;
        entry->tcache_ptr = tcache_ptr;
        entry->links = entry->o_links = NULL;
#if (DRC_DEBUG & 2)
        entry->block = block;
#endif
        block->entry_count++;

        dbg(2, "-- %csh2 block #%d,%d entry %08x -> %p",
          sh2->is_slave ? 's' : 'm', tcache_id, blkid_main,
          pc, tcache_ptr);
      }
      else {
        dbg(1, "too many entryp for block #%d,%d pc=%08x",
          tcache_id, blkid_main, pc);
        break;
      }

      v = find_in_sorted_linkage(branch_targets, branch_target_count, pc);
      if (v >= 0)
        branch_targets[v].ptr = tcache_ptr;
#if LOOP_DETECTION
      drcf.loop_type = op_flags[i] & OF_LOOP;
      drcf.delay_reg = -1;
      drcf.polling = (drcf.loop_type == OF_POLL_LOOP ? MF_POLLING : 0);
#endif

      rcache_clean();

#if (DRC_DEBUG & 0x10)
      tmp = rcache_get_tmp_arg(0);
      emith_move_r_imm(tmp, pc);
      tmp = emit_memhandler_read(1);
      tmp2 = rcache_get_tmp();
      tmp3 = rcache_get_tmp();
      emith_move_r_imm(tmp2, (s16)FETCH_OP(pc));
      emith_move_r_imm(tmp3, 0);
      emith_cmp_r_r(tmp, tmp2);
      EMITH_SJMP_START(DCOND_EQ);
      emith_read_r_r_offs_c(DCOND_NE, tmp3, tmp3, 0); // crash
      EMITH_SJMP_END(DCOND_EQ);
      rcache_free_tmp(tmp);
      rcache_free_tmp(tmp2);
      rcache_free_tmp(tmp3);
#endif

      // check cycles
      sr = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);

#if LOOP_OPTIMIZER
      if (op_flags[i] & OF_BASIC_LOOP) {
        if (pinned_loops[pinned_loop_count].pc == pc) {
          // pin needed regs on loop entry 
          FOR_ALL_BITS_SET_DO(pinned_loops[pinned_loop_count].mask, v, rcache_pin_reg(v));
          emith_flush();
          // store current PC as loop target
          pinned_loops[pinned_loop_count].ptr = tcache_ptr;
          drcf.pinning = 1;
        } else
          op_flags[i] &= ~OF_BASIC_LOOP;
      }

      if (op_flags[i] & OF_BASIC_LOOP) {
        // if exiting a pinned loop pinned regs must be written back to ctx
        // since they are reloaded in the loop entry code
        emith_cmp_r_imm(sr, 0);
        EMITH_JMP_START(DCOND_GE);
        rcache_save_pinned();

        if (blx_target_count < ARRAY_SIZE(blx_targets)) {
          // exit via stub in blx table (saves some 1-3 insns in the main flow)
          blx_targets[blx_target_count++] =
              (struct linkage) { .pc = pc, .ptr = tcache_ptr, .mask = 0x1 };
          emith_jump_patchable(tcache_ptr);
        } else {
          // blx table full, must inline exit code
          tmp = rcache_get_tmp_arg(0);
          emith_move_r_imm(tmp, pc);
          emith_jump(sh2_drc_exit);
          rcache_free_tmp(tmp);
        }
        EMITH_JMP_END(DCOND_GE);
      } else
#endif
      {
        if (blx_target_count < ARRAY_SIZE(blx_targets)) {
          // exit via stub in blx table (saves some 1-3 insns in the main flow)
          emith_cmp_r_imm(sr, 0);
          blx_targets[blx_target_count++] =
              (struct linkage) { .pc = pc, .ptr = tcache_ptr, .mask = 0x1 };
          emith_jump_cond_patchable(DCOND_LT, tcache_ptr);
        } else {
          // blx table full, must inline exit code
          tmp = rcache_get_tmp_arg(0);
          emith_cmp_r_imm(sr, 0);
          EMITH_SJMP_START(DCOND_GE);
          emith_move_r_imm_c(DCOND_LT, tmp, pc);
          emith_jump_cond(DCOND_LT, sh2_drc_exit);
          EMITH_SJMP_END(DCOND_GE);
          rcache_free_tmp(tmp);
        }
      }

#if (DRC_DEBUG & 32)
      // block hit counter
      tmp  = rcache_get_tmp_arg(0);
      tmp2 = rcache_get_tmp_arg(1);
      emith_move_r_ptr_imm(tmp, (uptr)entry);
      emith_read_r_r_offs(tmp2, tmp, offsetof(struct block_entry, entry_count));
      emith_add_r_imm(tmp2, 1);
      emith_write_r_r_offs(tmp2, tmp, offsetof(struct block_entry, entry_count));
      rcache_free_tmp(tmp);
      rcache_free_tmp(tmp2);
#endif

#if (DRC_DEBUG & (8|256|512|1024))
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      emith_sync_t(sr);
      rcache_clean();
      tmp = rcache_used_hregs_mask();
      emith_save_caller_regs(tmp);
      emit_do_static_regs(1, 0);
      rcache_get_reg_arg(2, SHR_SR, NULL);
      tmp2 = rcache_get_tmp_arg(0);
      tmp3 = rcache_get_tmp_arg(1);
      tmp4 = rcache_get_tmp();
      emith_move_r_ptr_imm(tmp2, tcache_ptr);
      emith_move_r_r_ptr(tmp3, CONTEXT_REG);
      emith_move_r_imm(tmp4, pc);
      emith_ctx_write(tmp4, SHR_PC * 4);
      rcache_invalidate_tmp();
      emith_abicall(sh2_drc_log_entry);
      emith_restore_caller_regs(tmp);
#endif

      do_host_disasm(tcache_id);
      rcache_unlock_all();
    }

#ifdef DRC_CMP
    if (!(op_flags[i] & OF_DELAY_OP)) {
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      FLUSH_CYCLES(sr);
      emith_sync_t(sr);
      emit_move_r_imm32(SHR_PC, pc);
      rcache_clean();

      tmp = rcache_used_hregs_mask();
      emith_save_caller_regs(tmp);
      emit_do_static_regs(1, 0);
      emith_pass_arg_r(0, CONTEXT_REG);
      emith_abicall(do_sh2_cmp);
      emith_restore_caller_regs(tmp);
    }
#endif

    // emit blx area if limits are approached
    if (blx_target_count && (blx_target_count > ARRAY_SIZE(blx_targets)-4 || 
        !emith_jump_patch_inrange(blx_targets[0].ptr, tcache_ptr+0x100))) {
      u8 *jp;
      rcache_invalidate_tmp();
      jp = tcache_ptr;
      emith_jump_patchable(tcache_ptr);
      emit_branch_linkage_code(sh2, block, tcache_id, branch_targets,
                          branch_target_count, blx_targets, blx_target_count);
      blx_target_count = 0;
      do_host_disasm(tcache_id);
      emith_jump_patch(jp, tcache_ptr, NULL);
    }

    emith_pool_check();

    opd = &ops[i];
    op = FETCH_OP(pc);
#if (DRC_DEBUG & 4)
    DasmSH2(sh2dasm_buff, pc, op);
    if (op_flags[i] & OF_BTARGET) {
      if ((op_flags[i] & OF_LOOP) == OF_DELAY_LOOP)     tmp3 = '+';
      else if ((op_flags[i] & OF_LOOP) == OF_POLL_LOOP) tmp3 = '=';
      else if ((op_flags[i] & OF_LOOP) == OF_IDLE_LOOP) tmp3 = '~';
      else                                              tmp3 = '*';
    } else if (drcf.loop_type)                          tmp3 = '.';
    else                                                tmp3 = ' ';
    printf("%c%08lx %04x %s\n", tmp3, (ulong)pc, op, sh2dasm_buff);
#endif

    pc += 2;
#if (DRC_DEBUG & 2)
    insns_compiled++;
#endif
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
        sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_sync_t(sr);
        DELAY_SAVE_T(sr);
      }
      if (delay_dep_bk & BITMASK1(SHR_PC)) {
        if (opd->op != OP_LOAD_POOL && opd->op != OP_MOVA) {
          // can only be those 2 really..
          elprintf_sh2(sh2, EL_ANOMALY,
            "drc: illegal slot insn %04x @ %08x?", op, pc - 2);
        }
        // store PC for MOVA/MOV @PC address calculation
        if (opd->imm != 0)
          ; // case OP_BRANCH - addr already resolved in scan_block
        else {
          switch (ops[i-1].op) {
          case OP_BRANCH:
            emit_move_r_imm32(SHR_PC, ops[i-1].imm);
            break;
          case OP_BRANCH_CT:
          case OP_BRANCH_CF:
            sr = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
            tmp = rcache_get_reg(SHR_PC, RC_GR_WRITE, NULL);
            emith_move_r_imm(tmp, pc);
            tmp2 = emith_tst_t(sr, (ops[i-1].op == OP_BRANCH_CT));
            tmp3 = emith_invert_cond(tmp2);
            EMITH_SJMP_START(tmp3);
            emith_move_r_imm_c(tmp2, tmp, ops[i-1].imm);
            EMITH_SJMP_END(tmp3);
            break;
          case OP_BRANCH_N: // BT/BF known not to be taken
            // XXX could modify opd->imm instead?
            emit_move_r_imm32(SHR_PC, pc);
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

    // inform cache about future register usage
    u32 late = 0;             // regs read by future ops
    u32 write = 0;            // regs written to (to detect write before read)
    u32 soon = 0;             // regs read soon
    for (v = 1; v <= 9; v++) {
      // no sense in looking any further than the next rcache flush
      tmp = ((op_flags[i+v] & OF_BTARGET) || (op_flags[i+v-1] & OF_DELAY_OP) ||
                (OP_ISBRACND(opd[v-1].op) && !(op_flags[i+v] & OF_DELAY_OP)));
      // XXX looking behind cond branch to avoid evicting regs used later?
      if (pc + 2*v <= end_pc && !tmp) { // (pc already incremented above)
        late |= opd[v].source & ~write;
        // ignore source regs after they have been written to
        write |= opd[v].dest;
        // regs needed in the next few instructions
        if (v <= 4)
          soon = late;
      } else
        break;
    }
    rcache_set_usage_now(opd[0].source);   // current insn
    rcache_set_usage_soon(soon);           // insns 1-4
    rcache_set_usage_late(late & ~soon);   // insns 5-9
    rcache_set_usage_discard(write & ~(late|soon));
    if (v <= 9)
      // upcoming rcache_flush, start writing back unused dirty stuff
      rcache_clean_masked(rcache_dirty_mask() & ~(write|opd[0].dest));

    switch (opd->op)
    {
    case OP_BRANCH_N:
      // never taken, just use up cycles
      goto end_op;
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
      tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
      tmp  = rcache_get_reg(SHR_PC, RC_GR_WRITE, NULL);
      emith_move_r_imm(tmp, pc + 2);
      if (opd->dest & BITMASK1(SHR_PR)) {
        tmp3 = rcache_get_reg(SHR_PR, RC_GR_WRITE, NULL);
        emith_move_r_r(tmp3, tmp);
      }
      emith_add_r_r(tmp, tmp2);
      if (gconst_get(GET_Rn(), &u))
        gconst_set(SHR_PC, pc + 2 + u);
      drcf.pending_branch_indirect = 1;
      goto end_op;

    case OP_SLEEP: // SLEEP      0000000000011011
      printf("TODO sleep\n");
      goto end_op;

    case OP_RTE: // RTE        0000000000101011
      emith_invalidate_t();
      // pop PC
      tmp = emit_memhandler_read_rr(sh2, SHR_PC, SHR_SP, 0, 2 | MF_POSTINCR);
      rcache_free(tmp);
      // pop SR
      tmp = emit_memhandler_read_rr(sh2, SHR_TMP, SHR_SP, 0, 2 | MF_POSTINCR);
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      emith_write_sr(sr, tmp);
      rcache_free_tmp(tmp);
      drcf.test_irq = 1;
      drcf.pending_branch_indirect = 1;
      goto end_op;

    case OP_UNDEFINED:
      elprintf_sh2(sh2, EL_ANOMALY, "drc: unhandled op %04x @ %08x", op, pc-2);
      opd->imm = (op_flags[i] & OF_B_IN_DS) ? 6 : 4;
      // fallthrough
    case OP_TRAPA: // TRAPA #imm      11000011iiiiiiii
      // push SR
      tmp  = rcache_get_reg_arg(1, SHR_SR, &tmp2);
      emith_sync_t(tmp2);
      emith_clear_msb(tmp, tmp2, 22);
      emit_memhandler_write_rr(sh2, SHR_TMP, SHR_SP, 0, 2 | MF_PREDECR);
      // push PC
      if (opd->op == OP_TRAPA) {
        tmp = rcache_get_tmp_arg(1);
        emith_move_r_imm(tmp, pc);
      } else if (drcf.pending_branch_indirect) {
        tmp = rcache_get_reg_arg(1, SHR_PC, NULL);
      } else {
        tmp = rcache_get_tmp_arg(1);
        emith_move_r_imm(tmp, pc - 2);
      }
      emit_memhandler_write_rr(sh2, SHR_TMP, SHR_SP, 0, 2 | MF_PREDECR);
      // obtain new PC
      emit_memhandler_read_rr(sh2, SHR_PC, SHR_VBR, opd->imm * 4, 2);
      // indirect jump -> back to dispatcher
      drcf.pending_branch_indirect = 1;
      goto end_op;

    case OP_LOAD_POOL:
#if PROPAGATE_CONSTANTS
      if ((opd->imm && opd->imm >= base_pc && opd->imm < end_literals) ||
          p32x_sh2_mem_is_rom(opd->imm, sh2))
      {
        if (opd->size == 2)
          u = FETCH32(opd->imm);
        else
          u = (s16)FETCH_OP(opd->imm);
        gconst_new(GET_Rn(), u);
      }
      else
#endif
      {
        if (opd->imm != 0) {
          tmp = rcache_get_tmp_arg(0);
          emith_move_r_imm(tmp, opd->imm);
        } else {
          // have to calculate read addr from PC for delay slot
          tmp = rcache_get_reg_arg(0, SHR_PC, &tmp2);
          if (opd->size == 2) {
            emith_add_r_r_imm(tmp, tmp2, 2 + (op & 0xff) * 4);
            emith_bic_r_imm(tmp, 3);
          }
          else
            emith_add_r_r_imm(tmp, tmp2, 2 + (op & 0xff) * 2);
        }
        tmp2 = emit_memhandler_read(opd->size);
        tmp3 = rcache_map_reg(GET_Rn(), tmp2);
        if (tmp3 != tmp2) {
          emith_move_r_r(tmp3, tmp2);
          rcache_free_tmp(tmp2);
        }
      }
      goto end_op;

    case OP_MOVA: // MOVA @(disp,PC),R0    11000111dddddddd
      if (opd->imm != 0)
        emit_move_r_imm32(SHR_R0, opd->imm);
      else {
        // have to calculate addr from PC for delay slot
        tmp2 = rcache_get_reg(SHR_PC, RC_GR_READ, NULL);
        tmp = rcache_get_reg(SHR_R0, RC_GR_WRITE, NULL);
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
        if (tmp2 == SHR_SR) {
          sr = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
          emith_sync_t(sr);
          tmp = rcache_get_reg(GET_Rn(), RC_GR_WRITE, NULL);
          emith_clear_msb(tmp, sr, 22); // reserved bits defined by ISA as 0
        } else
          emit_move_r_r(GET_Rn(), tmp2);
        goto end_op;
      case 0x04: // MOV.B Rm,@(R0,Rn)   0000nnnnmmmm0100
      case 0x05: // MOV.W Rm,@(R0,Rn)   0000nnnnmmmm0101
      case 0x06: // MOV.L Rm,@(R0,Rn)   0000nnnnmmmm0110
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        emit_indirect_indexed_write(sh2, GET_Rm(), SHR_R0, GET_Rn(), op & 3);
        goto end_op;
      case 0x07: // MUL.L     Rm,Rn      0000nnnnmmmm0111
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_WRITE, NULL);
        emith_mul(tmp3, tmp2, tmp);
        goto end_op;
      case 0x08:
        switch (GET_Fx())
        {
        case 0: // CLRT               0000000000001000
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if T_OPTIMIZER
          if (~rcache_regs_discard & BITMASK1(SHR_T))
#endif
            emith_set_t(sr, 0);
          break;
        case 1: // SETT               0000000000011000
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if T_OPTIMIZER
          if (~rcache_regs_discard & BITMASK1(SHR_T))
#endif
            emith_set_t(sr, 1);
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
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_invalidate_t();
          emith_bic_r_imm(sr, M|Q|T);
          drcf.Mflag = FLG_0;
#if DIV_OPTIMIZER
          if (div(opd).div1 == 16 && div(opd).ro == div(opd).rn) {
            // divide 32/16
            rcache_get_reg_arg(0, div(opd).rn, NULL);
            rcache_get_reg_arg(2, div(opd).rm, NULL);
            tmp = rcache_get_tmp_arg(1);
            emith_add_r_r_ptr_imm(tmp, CONTEXT_REG, offsetof(SH2, drc_tmp));
            rcache_invalidate_tmp();
            emith_abicall(sh2_drc_divu32);
            tmp = rcache_get_tmp_ret();
            tmp2 = rcache_map_reg(div(opd).rn, tmp);
            if (tmp != tmp2)
              emith_move_r_r(tmp2, tmp);

            tmp3  = rcache_get_tmp();
            emith_and_r_r_imm(tmp3, tmp2, 1);     // Q = !Rn[0]
            emith_eor_r_r_imm(tmp3, tmp3, 1);
            emith_or_r_r_lsl(sr, tmp3, Q_SHIFT);
            emith_ctx_read(tmp3, offsetof(SH2, drc_tmp));
            emith_or_r_r_r(sr, sr, tmp3);         // T
            rcache_free_tmp(tmp3);
            skip_op = div(opd).div1 + div(opd).rotcl;
            cycles += skip_op;
          }
          else if (div(opd).div1 == 32 && div(opd).ro != div(opd).rn) {
            // divide 64/32
            tmp4 = rcache_get_reg(div(opd).ro, RC_GR_READ, NULL);
            emith_ctx_write(tmp4, offsetof(SH2, drc_tmp));
            rcache_free(tmp4);
            rcache_get_reg_arg(0, div(opd).rn, NULL);
            rcache_get_reg_arg(2, div(opd).rm, NULL);
            tmp = rcache_get_tmp_arg(1);
            emith_add_r_r_ptr_imm(tmp, CONTEXT_REG, offsetof(SH2, drc_tmp));
            rcache_invalidate_tmp();
            emith_abicall(sh2_drc_divu64);
            tmp = rcache_get_tmp_ret();
            tmp2 = rcache_map_reg(div(opd).rn, tmp);
            tmp4 = rcache_get_reg(div(opd).ro, RC_GR_WRITE, NULL);
            if (tmp != tmp2)
              emith_move_r_r(tmp2, tmp);
            emith_ctx_read(tmp4, offsetof(SH2, drc_tmp));

            tmp3  = rcache_get_tmp();
            emith_and_r_r_imm(tmp3, tmp4, 1);     // Q = !Ro[0]
            emith_eor_r_r_imm(tmp3, tmp3, 1);
            emith_or_r_r_lsl(sr, tmp3, Q_SHIFT);
            rcache_free_tmp(tmp3);
            skip_op = div(opd).div1 + div(opd).rotcl;
            cycles += skip_op;
          }
#endif
          break;
        case 2: // MOVT Rn    0000nnnn00101001
          sr   = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
          emith_sync_t(sr);
          tmp2 = rcache_get_reg(GET_Rn(), RC_GR_WRITE, NULL);
          emith_clear_msb(tmp2, sr, 31);
          break;
        default:
          goto default_;
        }
        goto end_op;
      case 0x0a:
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
        emit_move_r_r(GET_Rn(), tmp2);
        goto end_op;
      case 0x0c: // MOV.B    @(R0,Rm),Rn      0000nnnnmmmm1100
      case 0x0d: // MOV.W    @(R0,Rm),Rn      0000nnnnmmmm1101
      case 0x0e: // MOV.L    @(R0,Rm),Rn      0000nnnnmmmm1110
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        emit_indirect_indexed_read(sh2, GET_Rn(), SHR_R0, GET_Rm(), (op & 3) | drcf.polling);
        goto end_op;
      case 0x0f: // MAC.L   @Rm+,@Rn+  0000nnnnmmmm1111
        emit_indirect_read_double(sh2, &tmp, &tmp2, GET_Rn(), GET_Rm(), 2);
        sr = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_RMW, NULL);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_RMW, NULL);
        emith_sh2_macl(tmp3, tmp4, tmp, tmp2, sr);
        rcache_free_tmp(tmp2);
        rcache_free_tmp(tmp);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x01: // MOV.L Rm,@(disp,Rn) 0001nnnnmmmmdddd
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      FLUSH_CYCLES(sr);
      emit_memhandler_write_rr(sh2, GET_Rm(), GET_Rn(), (op & 0x0f) * 4, 2);
      goto end_op;

    case 0x02:
      switch (op & 0x0f)
      {
      case 0x00: // MOV.B Rm,@Rn        0010nnnnmmmm0000
      case 0x01: // MOV.W Rm,@Rn        0010nnnnmmmm0001
      case 0x02: // MOV.L Rm,@Rn        0010nnnnmmmm0010
        sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        emit_memhandler_write_rr(sh2, GET_Rm(), GET_Rn(), 0, op & 3);
        goto end_op;
      case 0x04: // MOV.B Rm,@-Rn       0010nnnnmmmm0100
      case 0x05: // MOV.W Rm,@-Rn       0010nnnnmmmm0101
      case 0x06: // MOV.L Rm,@-Rn       0010nnnnmmmm0110
        sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        emit_memhandler_write_rr(sh2, GET_Rm(), GET_Rn(), 0, (op & 3) | MF_PREDECR);
        goto end_op;
      case 0x07: // DIV0S Rm,Rn         0010nnnnmmmm0111
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_invalidate_t();
        emith_bic_r_imm(sr, M|Q|T);
        drcf.Mflag = FLG_UNKNOWN;
#if DIV_OPTIMIZER
        if (div(opd).div1 == 16 && div(opd).ro == div(opd).rn) {
          // divide 32/16
          tmp = rcache_get_reg_arg(0, div(opd).rn, NULL);
          tmp2 = rcache_get_reg_arg(2, div(opd).rm, NULL);
          tmp3 = rcache_get_tmp_arg(1);
          emith_lsr(tmp3, tmp2, 31);
          emith_or_r_r_lsl(sr, tmp3, M_SHIFT);        // M = Rm[31]
          emith_add_r_r_ptr_imm(tmp3, CONTEXT_REG, offsetof(SH2, drc_tmp));
          rcache_invalidate_tmp();
          emith_abicall(sh2_drc_divs32);
          tmp = rcache_get_tmp_ret();
          tmp2 = rcache_map_reg(div(opd).rn, tmp);
          if (tmp != tmp2)
            emith_move_r_r(tmp2, tmp);
          tmp3  = rcache_get_tmp();

          emith_eor_r_r_r_lsr(tmp3, tmp2, sr, M_SHIFT);
          emith_and_r_r_imm(tmp3, tmp3, 1);
          emith_eor_r_r_imm(tmp3, tmp3, 1);
          emith_or_r_r_lsl(sr, tmp3, Q_SHIFT);        // Q = !Rn[0]^M
          emith_ctx_read(tmp3, offsetof(SH2, drc_tmp));
          emith_or_r_r_r(sr, sr, tmp3);               // T
          rcache_free_tmp(tmp3);
          skip_op = div(opd).div1 + div(opd).rotcl;
          cycles += skip_op;
        }
        else if (div(opd).div1 == 32 && div(opd).ro != div(opd).rn) {
          // divide 64/32
          tmp4 = rcache_get_reg(div(opd).ro, RC_GR_READ, NULL);
          emith_ctx_write(tmp4, offsetof(SH2, drc_tmp));
          rcache_free(tmp4);
          tmp  = rcache_get_reg_arg(0, div(opd).rn, NULL);
          tmp2 = rcache_get_reg_arg(2, div(opd).rm, NULL);
          tmp3 = rcache_get_tmp_arg(1);
          emith_lsr(tmp3, tmp2, 31);
          emith_or_r_r_lsl(sr, tmp3, M_SHIFT);        // M = Rm[31]
          emith_eor_r_r_lsr(tmp3, tmp, 31);
          emith_or_r_r(sr, tmp3);                     // T = Rn[31]^M
          emith_add_r_r_ptr_imm(tmp3, CONTEXT_REG, offsetof(SH2, drc_tmp));
          rcache_invalidate_tmp();
          emith_abicall(sh2_drc_divs64);
          tmp = rcache_get_tmp_ret();
          tmp2 = rcache_map_reg(div(opd).rn, tmp);
          tmp4 = rcache_get_reg(div(opd).ro, RC_GR_WRITE, NULL);
          if (tmp != tmp2)
            emith_move_r_r(tmp2, tmp);
          emith_ctx_read(tmp4, offsetof(SH2, drc_tmp));

          tmp3  = rcache_get_tmp();
          emith_eor_r_r_r_lsr(tmp3, tmp4, sr, M_SHIFT);
          emith_and_r_r_imm(tmp3, tmp3, 1);
          emith_eor_r_r_imm(tmp3, tmp3, 1);
          emith_or_r_r_lsl(sr, tmp3, Q_SHIFT);        // Q = !Ro[0]^M
          rcache_free_tmp(tmp3);
          skip_op = div(opd).div1 + div(opd).rotcl;
          cycles += skip_op;
        } else
#endif
        {
          tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
          tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
          tmp  = rcache_get_tmp();
          emith_lsr(tmp, tmp2, 31);       // Q = Nn
          emith_or_r_r_lsl(sr, tmp, Q_SHIFT);
          emith_lsr(tmp, tmp3, 31);       // M = Nm
          emith_or_r_r_lsl(sr, tmp, M_SHIFT);
          emith_eor_r_r_lsr(tmp, tmp2, 31);
          emith_or_r_r(sr, tmp);          // T = Q^M
          rcache_free(tmp);
        }
        goto end_op;
      case 0x08: // TST Rm,Rn           0010nnnnmmmm1000
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        emith_clr_t_cond(sr);
        emith_tst_r_r(tmp2, tmp3);
        emith_set_t_cond(sr, DCOND_EQ);
        goto end_op;
      case 0x09: // AND Rm,Rn           0010nnnnmmmm1001
        if (GET_Rm() != GET_Rn()) {
          tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
          tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
          emith_and_r_r_r(tmp, tmp3, tmp2);
        }
        goto end_op;
      case 0x0a: // XOR Rm,Rn           0010nnnnmmmm1010
#if PROPAGATE_CONSTANTS
        if (GET_Rn() == GET_Rm()) {
          gconst_new(GET_Rn(), 0);
          goto end_op;
        }
#endif
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
        emith_eor_r_r_r(tmp, tmp3, tmp2);
        goto end_op;
      case 0x0b: // OR  Rm,Rn           0010nnnnmmmm1011
        if (GET_Rm() != GET_Rn()) {
          tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
          tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
          emith_or_r_r_r(tmp, tmp3, tmp2);
        }
        goto end_op;
      case 0x0c: // CMP/STR Rm,Rn       0010nnnnmmmm1100
        tmp  = rcache_get_tmp();
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        emith_eor_r_r_r(tmp, tmp2, tmp3);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_clr_t_cond(sr);
        emith_tst_r_imm(tmp, 0x000000ff);
        EMITH_SJMP_START(DCOND_EQ);
        emith_tst_r_imm_c(DCOND_NE, tmp, 0x0000ff00);
        EMITH_SJMP_START(DCOND_EQ);
        emith_tst_r_imm_c(DCOND_NE, tmp, 0x00ff0000);
        EMITH_SJMP_START(DCOND_EQ);
        emith_tst_r_imm_c(DCOND_NE, tmp, 0xff000000);
        EMITH_SJMP_END(DCOND_EQ);
        EMITH_SJMP_END(DCOND_EQ);
        EMITH_SJMP_END(DCOND_EQ);
        emith_set_t_cond(sr, DCOND_EQ);
        rcache_free_tmp(tmp);
        goto end_op;
      case 0x0d: // XTRCT  Rm,Rn        0010nnnnmmmm1101
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
        emith_lsr(tmp, tmp3, 16);
        emith_or_r_r_lsl(tmp, tmp2, 16);
        goto end_op;
      case 0x0e: // MULU.W Rm,Rn        0010nnnnmmmm1110
      case 0x0f: // MULS.W Rm,Rn        0010nnnnmmmm1111
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp  = rcache_get_reg(SHR_MACL, RC_GR_WRITE, NULL);
        tmp4 = tmp3;
        if (op & 1) {
          if (! rcache_is_s16(tmp2)) {
            emith_sext(tmp, tmp2, 16);
            tmp2 = tmp;
          }
          if (! rcache_is_s16(tmp3)) {
            tmp4 = rcache_get_tmp();
            emith_sext(tmp4, tmp3, 16);
          }
        } else {
          if (! rcache_is_u16(tmp2)) {
            emith_clear_msb(tmp, tmp2, 16);
            tmp2 = tmp;
          }
          if (! rcache_is_u16(tmp3)) {
            tmp4 = rcache_get_tmp();
            emith_clear_msb(tmp4, tmp3, 16);
          }
        }
        emith_mul(tmp, tmp2, tmp4);
        if (tmp4 != tmp3)
          rcache_free_tmp(tmp4);
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
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        switch (op & 0x07)
        {
        case 0x00: // CMP/EQ
          tmp = DCOND_EQ;
          break;
        case 0x02: // CMP/HS
          tmp = DCOND_HS;
          break;
        case 0x03: // CMP/GE
          tmp = DCOND_GE;
          break;
        case 0x06: // CMP/HI
          tmp = DCOND_HI;
          break;
        case 0x07: // CMP/GT
          tmp = DCOND_GT;
          break;
        }
        emith_clr_t_cond(sr);
        emith_cmp_r_r(tmp2, tmp3);
        emith_set_t_cond(sr, tmp);
        goto end_op;
      case 0x04: // DIV1    Rm,Rn       0011nnnnmmmm0100
        // Q1 = carry(Rn = (Rn << 1) | T)
        // if Q ^ M
        //   Q2 = carry(Rn += Rm)
        // else
        //   Q2 = carry(Rn -= Rm)
        // Q = M ^ Q1 ^ Q2
        // T = (Q == M) = !(Q ^ M) = !(Q1 ^ Q2)
        tmp3 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_RMW, NULL);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_sync_t(sr);
        tmp = rcache_get_tmp();
        if (drcf.Mflag != FLG_0) {
          emith_and_r_r_imm(tmp, sr, M);
          emith_eor_r_r_lsr(sr, tmp, M_SHIFT - Q_SHIFT); // Q ^= M
        }
        rcache_free_tmp(tmp);
        // shift Rn, add T, add or sub Rm, set T = !(Q1 ^ Q2)
        // in: (Q ^ M) passed in Q
        emith_sh2_div1_step(tmp2, tmp3, sr);
        tmp = rcache_get_tmp();
        emith_or_r_imm(sr, Q);              // Q = !T
        emith_and_r_r_imm(tmp, sr, T);
        emith_eor_r_r_lsl(sr, tmp, Q_SHIFT);
        if (drcf.Mflag != FLG_0) {          // Q = M ^ !T = M ^ Q1 ^ Q2
          emith_and_r_r_imm(tmp, sr, M);
          emith_eor_r_r_lsr(sr, tmp, M_SHIFT - Q_SHIFT);
        }
        rcache_free_tmp(tmp);
        goto end_op;
      case 0x05: // DMULU.L Rm,Rn       0011nnnnmmmm0101
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_WRITE, NULL);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_WRITE, NULL);
        emith_mul_u64(tmp3, tmp4, tmp, tmp2);
        goto end_op;
      case 0x08: // SUB     Rm,Rn       0011nnnnmmmm1000
#if PROPAGATE_CONSTANTS
        if (GET_Rn() == GET_Rm()) {
          gconst_new(GET_Rn(), 0);
          goto end_op;
        }
#endif
      case 0x0c: // ADD     Rm,Rn       0011nnnnmmmm1100
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
        if (op & 4) {
          emith_add_r_r_r(tmp, tmp3, tmp2);
        } else
          emith_sub_r_r_r(tmp, tmp3, tmp2);
        goto end_op;
      case 0x0a: // SUBC    Rm,Rn       0011nnnnmmmm1010
      case 0x0e: // ADDC    Rm,Rn       0011nnnnmmmm1110
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_sync_t(sr);
#if T_OPTIMIZER
        if (rcache_regs_discard & BITMASK1(SHR_T)) {
          if (op & 4) {
            emith_t_to_carry(sr, 0);
            emith_adc_r_r_r(tmp, tmp3, tmp2);
          } else {
            emith_t_to_carry(sr, 1);
            emith_sbc_r_r_r(tmp, tmp3, tmp2);
          }
        } else
#endif
        {
          EMITH_HINT_COND(DCOND_CS);
          if (op & 4) { // adc
            emith_tpop_carry(sr, 0);
            emith_adcf_r_r_r(tmp, tmp3, tmp2);
            emith_tpush_carry(sr, 0);
          } else {
            emith_tpop_carry(sr, 1);
            emith_sbcf_r_r_r(tmp, tmp3, tmp2);
            emith_tpush_carry(sr, 1);
          }
        }
        goto end_op;
      case 0x0b: // SUBV    Rm,Rn       0011nnnnmmmm1011
      case 0x0f: // ADDV    Rm,Rn       0011nnnnmmmm1111
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if T_OPTIMIZER
        if (rcache_regs_discard & BITMASK1(SHR_T)) {
          if (op & 4)
            emith_add_r_r_r(tmp,tmp3,tmp2);
          else
            emith_sub_r_r_r(tmp,tmp3,tmp2);
        } else
#endif
        {
          emith_clr_t_cond(sr);
          EMITH_HINT_COND(DCOND_VS);
          if (op & 4)
            emith_addf_r_r_r(tmp, tmp3, tmp2);
          else
            emith_subf_r_r_r(tmp, tmp3, tmp2);
          emith_set_t_cond(sr, DCOND_VS);
        }
        goto end_op;
      case 0x0d: // DMULS.L Rm,Rn       0011nnnnmmmm1101
        tmp  = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
        tmp2 = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_WRITE, NULL);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_WRITE, NULL);
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
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp2);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if T_OPTIMIZER
          if (rcache_regs_discard & BITMASK1(SHR_T))
            emith_lsl(tmp, tmp2, 1);
          else
#endif
          {
            emith_invalidate_t();
            emith_lslf(tmp, tmp2, 1);
            emith_carry_to_t(sr, 0);
          }
          goto end_op;
        case 1: // DT Rn      0100nnnn00010000
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if LOOP_DETECTION
          if (drcf.loop_type == OF_DELAY_LOOP) {
            if (drcf.delay_reg == -1)
              drcf.delay_reg = GET_Rn();
            else
              drcf.polling = drcf.loop_type = 0;
          }
#endif
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp2);
          emith_clr_t_cond(sr);
          EMITH_HINT_COND(DCOND_EQ);
          emith_subf_r_r_imm(tmp, tmp2, 1);
          emith_set_t_cond(sr, DCOND_EQ);
          emith_or_r_imm(sr, SH2_NO_POLLING);
          goto end_op;
        }
        goto default_;
      case 0x01:
        switch (GET_Fx())
        {
        case 0: // SHLR Rn    0100nnnn00000001
        case 2: // SHAR Rn    0100nnnn00100001
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp2);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if T_OPTIMIZER
          if (rcache_regs_discard & BITMASK1(SHR_T)) {
            if (op & 0x20)
              emith_asr(tmp,tmp2,1);
            else
              emith_lsr(tmp,tmp2,1);
          } else
#endif
          {
            emith_invalidate_t();
            if (op & 0x20) {
              emith_asrf(tmp, tmp2, 1);
            } else
              emith_lsrf(tmp, tmp2, 1);
            emith_carry_to_t(sr, 0);
          }
          goto end_op;
        case 1: // CMP/PZ Rn  0100nnnn00010001
          tmp = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_clr_t_cond(sr);
          emith_cmp_r_imm(tmp, 0);
          emith_set_t_cond(sr, DCOND_GE);
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
        if (tmp == SHR_SR) {
          tmp3 = rcache_get_reg_arg(1, tmp, &tmp4);
          emith_sync_t(tmp4);
          emith_clear_msb(tmp3, tmp4, 22); // reserved bits defined by ISA as 0
        } else
          tmp3 = rcache_get_reg_arg(1, tmp, NULL);
        emit_memhandler_write_rr(sh2, SHR_TMP, GET_Rn(), 0, 2 | MF_PREDECR);
        goto end_op;
      case 0x04:
      case 0x05:
        switch (op & 0x3f)
        {
        case 0x04: // ROTL   Rn          0100nnnn00000100
        case 0x05: // ROTR   Rn          0100nnnn00000101
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp2);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
#if T_OPTIMIZER
          if (rcache_regs_discard & BITMASK1(SHR_T)) {
            if (op & 1)
              emith_ror(tmp, tmp2, 1);
            else
              emith_rol(tmp, tmp2, 1);
          } else
#endif
          {
            emith_invalidate_t();
            if (op & 1)
              emith_rorf(tmp, tmp2, 1);
            else
              emith_rolf(tmp, tmp2, 1);
            emith_carry_to_t(sr, 0);
          }
          goto end_op;
        case 0x24: // ROTCL  Rn          0100nnnn00100100
        case 0x25: // ROTCR  Rn          0100nnnn00100101
          tmp = rcache_get_reg(GET_Rn(), RC_GR_RMW, NULL);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_sync_t(sr);
#if T_OPTIMIZER
          if (rcache_regs_discard & BITMASK1(SHR_T)) {
            emith_t_to_carry(sr, 0);
            if (op & 1)
              emith_rorc(tmp);
            else
              emith_rolc(tmp);
          } else
#endif
          {
            emith_tpop_carry(sr, 0);
            if (op & 1)
              emith_rorcf(tmp);
            else
              emith_rolcf(tmp);
            emith_tpush_carry(sr, 0);
          }
          goto end_op;
        case 0x15: // CMP/PL Rn          0100nnnn00010101
          tmp = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_clr_t_cond(sr);
          emith_cmp_r_imm(tmp, 0);
          emith_set_t_cond(sr, DCOND_GT);
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
        if (tmp == SHR_SR) {
          emith_invalidate_t();
          tmp2 = emit_memhandler_read_rr(sh2, SHR_TMP, GET_Rn(), 0, 2 | MF_POSTINCR);
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_write_sr(sr, tmp2);
          rcache_free_tmp(tmp2);
          drcf.test_irq = 1;
        } else
          emit_memhandler_read_rr(sh2, tmp, GET_Rn(), 0, 2 | MF_POSTINCR);
        goto end_op;
      case 0x08:
      case 0x09:
        switch (GET_Fx())
        {
        case 0: // SHLL2 Rn        0100nnnn00001000
                // SHLR2 Rn        0100nnnn00001001
          tmp = 2;
          break;
        case 1: // SHLL8 Rn        0100nnnn00011000
                // SHLR8 Rn        0100nnnn00011001
          tmp = 8;
          break;
        case 2: // SHLL16 Rn       0100nnnn00101000
                // SHLR16 Rn       0100nnnn00101001
          tmp = 16;
          break;
        default:
          goto default_;
        }
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_RMW, &tmp3);
        if (op & 1) {
          emith_lsr(tmp2, tmp3, tmp);
        } else
          emith_lsl(tmp2, tmp3, tmp);
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
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          FLUSH_CYCLES(sr);
          rcache_get_reg_arg(0, GET_Rn(), NULL);
          tmp = emit_memhandler_read(0);
          sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_clr_t_cond(sr);
          emith_cmp_r_imm(tmp, 0);
          emith_set_t_cond(sr, DCOND_EQ);
          emith_or_r_imm(tmp, 0x80);
          tmp2 = rcache_get_tmp_arg(1); // assuming it differs to tmp
          emith_move_r_r(tmp2, tmp);
          rcache_free_tmp(tmp);
          rcache_get_reg_arg(0, GET_Rn(), NULL);
          emit_memhandler_write(0);
          break;
        default:
          goto default_;
        }
        goto end_op;
      case 0x0e:
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
          emith_invalidate_t();
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          tmp = rcache_get_reg(GET_Rn(), RC_GR_READ, NULL);
          emith_write_sr(sr, tmp);
          drcf.test_irq = 1;
        } else
          emit_move_r_r(tmp2, GET_Rn());
        goto end_op;
      case 0x0f: // MAC.W @Rm+,@Rn+  0100nnnnmmmm1111
        emit_indirect_read_double(sh2, &tmp, &tmp2, GET_Rn(), GET_Rm(), 1);
        sr = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
        tmp3 = rcache_get_reg(SHR_MACL, RC_GR_RMW, NULL);
        tmp4 = rcache_get_reg(SHR_MACH, RC_GR_RMW, NULL);
        emith_sh2_macw(tmp3, tmp4, tmp, tmp2, sr);
        rcache_free_tmp(tmp2);
        rcache_free_tmp(tmp);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x05: // MOV.L @(disp,Rm),Rn 0101nnnnmmmmdddd
      sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      FLUSH_CYCLES(sr);
      emit_memhandler_read_rr(sh2, GET_Rn(), GET_Rm(), (op & 0x0f) * 4, 2 | drcf.polling);
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
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = ((op & 7) >= 4 && GET_Rn() != GET_Rm()) ? MF_POSTINCR : drcf.polling;
        emit_memhandler_read_rr(sh2, GET_Rn(), GET_Rm(), 0, (op & 3) | tmp);
        goto end_op;
      case 0x03: // MOV    Rm,Rn        0110nnnnmmmm0011
        emit_move_r_r(GET_Rn(), GET_Rm());
        goto end_op;
      default: // 0x07 ... 0x0f
        tmp  = rcache_get_reg(GET_Rm(), RC_GR_READ, NULL);
        tmp2 = rcache_get_reg(GET_Rn(), RC_GR_WRITE, NULL);
        switch (op & 0x0f)
        {
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
          sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
          emith_sync_t(sr);
#if T_OPTIMIZER
          if (rcache_regs_discard & BITMASK1(SHR_T)) {
            emith_t_to_carry(sr, 1);
            emith_negc_r_r(tmp2, tmp);
          } else
#endif
          {
            EMITH_HINT_COND(DCOND_CS);
            emith_tpop_carry(sr, 1);
            emith_negcf_r_r(tmp2, tmp);
            emith_tpush_carry(sr, 1);
          }
          break;
        case 0x0b: // NEG    Rm,Rn        0110nnnnmmmm1011
          emith_neg_r_r(tmp2, tmp);
          break;
        case 0x0c: // EXTU.B Rm,Rn        0110nnnnmmmm1100
          emith_clear_msb(tmp2, tmp, 24);
          rcache_set_x16(tmp2, 1, 1);
          break;
        case 0x0d: // EXTU.W Rm,Rn        0110nnnnmmmm1101
          emith_clear_msb(tmp2, tmp, 16);
          rcache_set_x16(tmp2, 0, 1);
          break;
        case 0x0e: // EXTS.B Rm,Rn        0110nnnnmmmm1110
          emith_sext(tmp2, tmp, 8);
          rcache_set_x16(tmp2, 1, 0);
          break;
        case 0x0f: // EXTS.W Rm,Rn        0110nnnnmmmm1111
          emith_sext(tmp2, tmp, 16);
          rcache_set_x16(tmp2, 1, 0);
          break;
        }
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x07: // ADD #imm,Rn  0111nnnniiiiiiii
      if (op & 0x80) // adding negative
        emit_sub_r_imm(GET_Rn(), (u8)-op);
      else
        emit_add_r_imm(GET_Rn(), (u8)op);
      goto end_op;

    /////////////////////////////////////////////
    case 0x08:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,Rn)  10000000nnnndddd
      case 0x0100: // MOV.W R0,@(disp,Rn)  10000001nnnndddd
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = (op & 0x100) >> 8;
        emit_memhandler_write_rr(sh2, SHR_R0, GET_Rm(), (op & 0x0f) << tmp, tmp);
        goto end_op;
      case 0x0400: // MOV.B @(disp,Rm),R0  10000100mmmmdddd
      case 0x0500: // MOV.W @(disp,Rm),R0  10000101mmmmdddd
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = (op & 0x100) >> 8;
        emit_memhandler_read_rr(sh2, SHR_R0, GET_Rm(), (op & 0x0f) << tmp, tmp | drcf.polling);
        goto end_op;
      case 0x0800: // CMP/EQ #imm,R0       10001000iiiiiiii
        tmp2 = rcache_get_reg(SHR_R0, RC_GR_READ, NULL);
        sr   = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_clr_t_cond(sr);
        emith_cmp_r_imm(tmp2, (s8)(op & 0xff));
        emith_set_t_cond(sr, DCOND_EQ);
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
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = (op & 0x300) >> 8;
        emit_memhandler_write_rr(sh2, SHR_R0, SHR_GBR, (op & 0xff) << tmp, tmp);
        goto end_op;
      case 0x0400: // MOV.B @(disp,GBR),R0   11000100dddddddd
      case 0x0500: // MOV.W @(disp,GBR),R0   11000101dddddddd
      case 0x0600: // MOV.L @(disp,GBR),R0   11000110dddddddd
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = (op & 0x300) >> 8;
        emit_memhandler_read_rr(sh2, SHR_R0, SHR_GBR, (op & 0xff) << tmp, tmp | drcf.polling);
        goto end_op;
      case 0x0800: // TST #imm,R0           11001000iiiiiiii
        tmp = rcache_get_reg(SHR_R0, RC_GR_READ, NULL);
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_clr_t_cond(sr);
        emith_tst_r_imm(tmp, op & 0xff);
        emith_set_t_cond(sr, DCOND_EQ);
        goto end_op;
      case 0x0900: // AND #imm,R0           11001001iiiiiiii
        tmp = rcache_get_reg(SHR_R0, RC_GR_RMW, &tmp2);
        emith_and_r_r_imm(tmp, tmp2, (op & 0xff));
        goto end_op;
      case 0x0a00: // XOR #imm,R0           11001010iiiiiiii
        if (op & 0xff) {
          tmp = rcache_get_reg(SHR_R0, RC_GR_RMW, &tmp2);
          emith_eor_r_r_imm(tmp, tmp2, (op & 0xff));
        }
        goto end_op;
      case 0x0b00: // OR  #imm,R0           11001011iiiiiiii
        if (op & 0xff) {
          tmp = rcache_get_reg(SHR_R0, RC_GR_RMW, &tmp2);
          emith_or_r_r_imm(tmp, tmp2, (op & 0xff));
        }
        goto end_op;
      case 0x0c00: // TST.B #imm,@(R0,GBR)  11001100iiiiiiii
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = emit_indirect_indexed_read(sh2, SHR_TMP, SHR_R0, SHR_GBR, 0 | drcf.polling);
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        emith_clr_t_cond(sr);
        emith_tst_r_imm(tmp, op & 0xff);
        emith_set_t_cond(sr, DCOND_EQ);
        rcache_free_tmp(tmp);
        goto end_op;
      case 0x0d00: // AND.B #imm,@(R0,GBR)  11001101iiiiiiii
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = emit_indirect_indexed_read(sh2, SHR_TMP, SHR_R0, SHR_GBR, 0);
        tmp2 = rcache_get_tmp_arg(1);
        emith_and_r_r_imm(tmp2, tmp, (op & 0xff));
        goto end_rmw_op;
      case 0x0e00: // XOR.B #imm,@(R0,GBR)  11001110iiiiiiii
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = emit_indirect_indexed_read(sh2, SHR_TMP, SHR_R0, SHR_GBR, 0);
        tmp2 = rcache_get_tmp_arg(1);
        emith_eor_r_r_imm(tmp2, tmp, (op & 0xff));
        goto end_rmw_op;
      case 0x0f00: // OR.B  #imm,@(R0,GBR)  11001111iiiiiiii
        sr  = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
        FLUSH_CYCLES(sr);
        tmp = emit_indirect_indexed_read(sh2, SHR_TMP, SHR_R0, SHR_GBR, 0);
        tmp2 = rcache_get_tmp_arg(1);
        emith_or_r_r_imm(tmp2, tmp, (op & 0xff));
      end_rmw_op:
        rcache_free_tmp(tmp);
        emit_indirect_indexed_write(sh2, SHR_TMP, SHR_R0, SHR_GBR, 0);
        goto end_op;
      }
      goto default_;

    /////////////////////////////////////////////
    case 0x0e: // MOV #imm,Rn   1110nnnniiiiiiii
      emit_move_r_imm32(GET_Rn(), (s8)op);
      goto end_op;

    default:
    default_:
      if (!(op_flags[i] & OF_B_IN_DS)) {
        elprintf_sh2(sh2, EL_ANOMALY,
          "drc: illegal op %04x @ %08x", op, pc - 2);
        exit(1);
      }
    }

end_op:
    rcache_unlock_all();
    rcache_set_usage_now(0);
#if DRC_DEBUG & 64
    RCACHE_CHECK("after insn");
#endif

    cycles += opd->cycles;

    if (op_flags[i+1] & OF_DELAY_OP) {
      do_host_disasm(tcache_id);
      continue;
    }

    // test irq?
    if (drcf.test_irq && !drcf.pending_branch_direct) {
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      FLUSH_CYCLES(sr);
      emith_sync_t(sr);
      if (!drcf.pending_branch_indirect)
        emit_move_r_imm32(SHR_PC, pc);
      rcache_flush();
      emith_call(sh2_drc_test_irq);
      drcf.test_irq = 0;
    }

    // branch handling
    if (drcf.pending_branch_direct)
    {
      struct op_data *opd_b = (op_flags[i] & OF_DELAY_OP) ? opd-1 : opd;
      u32 target_pc = opd_b->imm;
      int cond = -1;
      int ctaken = 0;
      void *target = NULL;

      if (OP_ISBRACND(opd_b->op))
        ctaken = (op_flags[i] & OF_DELAY_OP) ? 1 : 2;
      cycles += ctaken; // assume branch taken

#if LOOP_OPTIMIZER
      if ((drcf.loop_type == OF_IDLE_LOOP ||
          (drcf.loop_type == OF_DELAY_LOOP && drcf.delay_reg >= 0)))
      {
        // idle or delay loop
        emit_sync_t_to_sr();
        emith_sh2_delay_loop(cycles, drcf.delay_reg);
        rcache_unlock_all(); // may lock delay_reg
        drcf.polling = drcf.loop_type = drcf.pinning = 0;
      }
#endif

#if CALL_STACK
      void *rtsadd = NULL, *rtsret = NULL;
      if ((opd_b->dest & BITMASK1(SHR_PR)) && pc+2 < end_pc) {
        // BSR - save rts data
        tmp = rcache_get_tmp_arg(1);
        rtsadd = tcache_ptr;
        emith_move_r_imm_s8_patchable(tmp, 0);
        rcache_clean_tmp();
        rcache_invalidate_tmp();
        emith_call(sh2_drc_dispatcher_call);
        rtsret = tcache_ptr;
      }
#endif

      // XXX move below cond test if not changing host cond (MIPS delay slot)?
      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      FLUSH_CYCLES(sr);
      rcache_clean();

      if (OP_ISBRACND(opd_b->op)) {
        // BT[S], BF[S] - emit condition test
        cond = (opd_b->op == OP_BRANCH_CF) ? DCOND_EQ : DCOND_NE;
        if (delay_dep_fw & BITMASK1(SHR_T)) {
          emith_sync_t(sr);
          emith_tst_r_imm(sr, T_save);
        } else {
          cond = emith_tst_t(sr, (opd_b->op == OP_BRANCH_CT));
          if (emith_get_t_cond() >= 0) {
            if (opd_b->op == OP_BRANCH_CT)
              emith_or_r_imm_c(cond, sr, T);
            else
              emith_bic_r_imm_c(cond, sr, T);
          }
        }
      } else
        emith_sync_t(sr);
      // no modification of host status/flags between here and branching!

      v = find_in_sorted_linkage(branch_targets, branch_target_count, target_pc);
      if (v >= 0)
      {
        // local branch
        if (branch_targets[v].ptr) {
          // local backward jump, link here now since host PC is already known
          target = branch_targets[v].ptr;
#if LOOP_OPTIMIZER
          if (pinned_loops[pinned_loop_count].pc == target_pc) {
            // backward jump at end of optimized loop
            rcache_unpin_all();
            target = pinned_loops[pinned_loop_count].ptr;
            pinned_loop_count ++;
          }
#endif
          if (cond != -1) {
            if (emith_jump_patch_inrange(tcache_ptr, target)) {
              emith_jump_cond(cond, target);
            } else {
              // not reachable directly, must use far branch
              EMITH_JMP_START(emith_invert_cond(cond));
              emith_jump(target);
              EMITH_JMP_END(emith_invert_cond(cond));
            }
          } else {
            emith_jump(target);
            rcache_invalidate();
          }
        } else if (blx_target_count < MAX_LOCAL_BRANCHES) {
          // local forward jump
          target = tcache_ptr;
          blx_targets[blx_target_count++] =
              (struct linkage) { .pc = target_pc, .ptr = target, .mask = 0x2 };
          if (cond != -1)
            emith_jump_cond_patchable(cond, target);
          else {
            emith_jump_patchable(target);
            rcache_invalidate();
          }
        } else
          // no space for resolving forward branch, handle it as external
          dbg(1, "warning: too many unresolved branches");
      }

      if (target == NULL)
      {
        // can't resolve branch locally, make a block exit
        bl = dr_prepare_ext_branch(block->entryp, target_pc, sh2->is_slave, tcache_id);
        if (cond != -1) {
#ifndef __arm__
          if (bl && blx_target_count < ARRAY_SIZE(blx_targets)) {
            // conditional jumps get a blx stub for the far jump
            bl->type = BL_JCCBLX;
            target = tcache_ptr;
            blx_targets[blx_target_count++] =
                (struct linkage) { .pc = target_pc, .ptr = target, .bl = bl };
            emith_jump_cond_patchable(cond, target);
          } else {
            // not linkable, or blx table full; inline jump @dispatcher
            EMITH_JMP_START(emith_invert_cond(cond));
            if (bl) {
              bl->jump = tcache_ptr;
              emith_flush(); // flush to inhibit insn swapping
              bl->type = BL_LDJMP;
            }
            tmp = rcache_get_tmp_arg(0);
            emith_move_r_imm(tmp, target_pc);
            rcache_free_tmp(tmp);
            target = sh2_drc_dispatcher;

            emith_jump_patchable(target);
            EMITH_JMP_END(emith_invert_cond(cond));
          }
#else
          // jump @dispatcher - ARM 32bit version with conditional execution
          EMITH_SJMP_START(emith_invert_cond(cond));
          tmp = rcache_get_tmp_arg(0);
          emith_move_r_imm_c(cond, tmp, target_pc);
          rcache_free_tmp(tmp);
          target = sh2_drc_dispatcher;

          if (bl) {
            bl->jump = tcache_ptr;
            bl->type = BL_JMP;
          }
          emith_jump_cond_patchable(cond, target);
          EMITH_SJMP_END(emith_invert_cond(cond));
#endif
        } else {
          // unconditional, has the far jump inlined
          if (bl) {
            emith_flush(); // flush to inhibit insn swapping
            bl->type = BL_LDJMP;
          }

          tmp = rcache_get_tmp_arg(0);
          emith_move_r_imm(tmp, target_pc);
          rcache_free_tmp(tmp);
          target = sh2_drc_dispatcher;

          emith_jump_patchable(target);
          rcache_invalidate();
        }
      }

#if CALL_STACK
      if (rtsadd)
        emith_move_r_imm_s8_patch(rtsadd, tcache_ptr - (u8 *)rtsret);
#endif

      // branch not taken, correct cycle count (now, cycles < 0)
      if (ctaken)
        cycles -= ctaken;
      // set T bit to reflect branch not taken for OP_BRANCH_CT/CF
      if (emith_get_t_cond() >= 0) // T is synced for all other cases
        emith_set_t(sr, opd_b->op == OP_BRANCH_CF);

      drcf.pending_branch_direct = 0;
      if (target_pc >= base_pc && target_pc < pc)
        drcf.polling = drcf.loop_type = 0;
    }
    else if (drcf.pending_branch_indirect) {
      u32 target_pc;

      tmp = rcache_get_reg_arg(0, SHR_PC, NULL);

#if CALL_STACK
      struct op_data *opd_b = (op_flags[i] & OF_DELAY_OP) ? opd-1 : opd;
      void *rtsadd = NULL, *rtsret = NULL;

      if ((opd_b->dest & BITMASK1(SHR_PR)) && pc+2 < end_pc) {
        // JSR, BSRF - save rts data
        tmp = rcache_get_tmp_arg(1);
        rtsadd = tcache_ptr;
        emith_move_r_imm_s8_patchable(tmp, 0);
        rcache_clean_tmp();
        rcache_invalidate_tmp();
        emith_call(sh2_drc_dispatcher_call);
        rtsret = tcache_ptr;
      }
#endif

      sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
      FLUSH_CYCLES(sr);
      emith_sync_t(sr);
      rcache_clean();

#if CALL_STACK
      if (opd_b->rm == SHR_PR) {
        // RTS - restore rts data, else jump to dispatcher
        emith_jump(sh2_drc_dispatcher_return);
      } else
#endif
      if (gconst_get(SHR_PC, &target_pc)) {
        // JMP, JSR, BRAF, BSRF const - treat like unconditional direct branch
        bl = dr_prepare_ext_branch(block->entryp, target_pc, sh2->is_slave, tcache_id);
        if (bl) // pc already loaded somewhere else, can patch jump only
          bl->type = BL_JMP;
        emith_jump_patchable(sh2_drc_dispatcher);
      } else {
        // JMP, JSR, BRAF, BSRF not const
        emith_jump(sh2_drc_dispatcher);
      }
      rcache_invalidate();

#if CALL_STACK
      if (rtsadd)
        emith_move_r_imm_s8_patch(rtsadd, tcache_ptr - (u8 *)rtsret);
#endif

      drcf.pending_branch_indirect = 0;
      drcf.polling = drcf.loop_type = 0;
    }
    rcache_unlock_all();

    do_host_disasm(tcache_id);
  }

  // check the last op
  if (op_flags[i-1] & OF_DELAY_OP)
    opd = &ops[i-2];
  else
    opd = &ops[i-1];

  if (! OP_ISBRAUC(opd->op) || (opd->dest & BITMASK1(SHR_PR)))
  {
    tmp = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
    FLUSH_CYCLES(tmp);
    emith_sync_t(tmp);

    rcache_clean();
    bl = dr_prepare_ext_branch(block->entryp, pc, sh2->is_slave, tcache_id);
    if (bl) {
      emith_flush(); // flush to inhibit insn swapping
      bl->type = BL_LDJMP;
    }
    tmp = rcache_get_tmp_arg(0);
    emith_move_r_imm(tmp, pc);
    emith_jump_patchable(sh2_drc_dispatcher);
    rcache_invalidate();
  } else
    rcache_flush();

  // link unresolved branches, emitting blx area entries as needed
  emit_branch_linkage_code(sh2, block, tcache_id, branch_targets,
                      branch_target_count, blx_targets, blx_target_count);

  emith_flush();
  do_host_disasm(tcache_id);

  emith_pool_commit(0);

  // fill blx backup; do this last to backup final patched code
  for (i = 0; i < block->entry_count; i++)
    for (bl = block->entryp[i].o_links; bl; bl = bl->o_next)
      memcpy(bl->jdisp, bl->blx ? bl->blx : bl->jump, emith_jump_at_size());

  ring_alloc(&tcache_ring[tcache_id], tcache_ptr - block_entry_ptr);
  host_instructions_updated(block_entry_ptr, tcache_ptr, 1);

  dr_activate_block(block, tcache_id, sh2->is_slave);
  emith_update_cache();

  do_host_disasm(tcache_id);

  dbg(2, " block #%d,%d -> %p tcache %d/%d, insns %d -> %d %.3f",
    tcache_id, blkid_main, tcache_ptr,
    tcache_ring[tcache_id].used, tcache_ring[tcache_id].size,
    insns_compiled, host_insn_count, (float)host_insn_count / insns_compiled);
  if ((sh2->pc & 0xc6000000) == 0x02000000) { // ROM
    dbg(2, "  hash collisions %d/%d", hash_collisions, block_ring[tcache_id].used);
    Pico32x.emu_flags |= P32XF_DRC_ROM_C;
  }
/*
 printf("~~~\n");
 tcache_dsm_ptrs[tcache_id] = block_entry_ptr;
 do_host_disasm(tcache_id);
 printf("~~~\n");
*/

  return block_entry_ptr;
}

static void sh2_generate_utils(void)
{
  int arg0, arg1, arg2, arg3, sr, tmp, tmp2;
#if DRC_DEBUG
  int hic = host_insn_count; // don't count utils for insn statistics
#endif

  host_arg2reg(arg0, 0);
  host_arg2reg(arg1, 1);
  host_arg2reg(arg2, 2);
  host_arg2reg(arg3, 3);

  // sh2_drc_write8(u32 a, u32 d)
  sh2_drc_write8 = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg2, offsetof(SH2, write8_tab));
  emith_sh2_wcall(arg0, arg1, arg2, arg3);
  emith_flush();

  // sh2_drc_write16(u32 a, u32 d)
  sh2_drc_write16 = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg2, offsetof(SH2, write16_tab));
  emith_sh2_wcall(arg0, arg1, arg2, arg3);
  emith_flush();

  // sh2_drc_write32(u32 a, u32 d)
  sh2_drc_write32 = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg2, offsetof(SH2, write32_tab));
  emith_sh2_wcall(arg0, arg1, arg2, arg3);
  emith_flush();

  // d = sh2_drc_read8(u32 a)
  sh2_drc_read8 = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg1, offsetof(SH2, read8_map));
  EMITH_HINT_COND(DCOND_CS);
  emith_sh2_rcall(arg0, arg1, arg2, arg3);
  EMITH_SJMP_START(DCOND_CS);
  emith_and_r_r_c(DCOND_CC, arg0, arg3);
  emit_le_ptr8(DCOND_CC, arg0);
  emith_read8s_r_r_r_c(DCOND_CC, RET_REG, arg2, arg0);
  emith_ret_c(DCOND_CC);
  EMITH_SJMP_END(DCOND_CS);
  emith_move_r_r_ptr(arg1, CONTEXT_REG);
  emith_abijump_reg(arg2);
  emith_flush();

  // d = sh2_drc_read16(u32 a)
  sh2_drc_read16 = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg1, offsetof(SH2, read16_map));
  EMITH_HINT_COND(DCOND_CS);
  emith_sh2_rcall(arg0, arg1, arg2, arg3);
  EMITH_SJMP_START(DCOND_CS);
  emith_and_r_r_c(DCOND_CC, arg0, arg3);
  emith_read16s_r_r_r_c(DCOND_CC, RET_REG, arg2, arg0);
  emith_ret_c(DCOND_CC);
  EMITH_SJMP_END(DCOND_CS);
  emith_move_r_r_ptr(arg1, CONTEXT_REG);
  emith_abijump_reg(arg2);
  emith_flush();

  // d = sh2_drc_read32(u32 a)
  sh2_drc_read32 = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg1, offsetof(SH2, read32_map));
  EMITH_HINT_COND(DCOND_CS);
  emith_sh2_rcall(arg0, arg1, arg2, arg3);
  EMITH_SJMP_START(DCOND_CS);
  emith_and_r_r_c(DCOND_CC, arg0, arg3);
  emith_read_r_r_r_c(DCOND_CC, RET_REG, arg2, arg0);
  emit_le_swap(DCOND_CC, RET_REG);
  emith_ret_c(DCOND_CC);
  EMITH_SJMP_END(DCOND_CS);
  emith_move_r_r_ptr(arg1, CONTEXT_REG);
  emith_abijump_reg(arg2);
  emith_flush();

  // d = sh2_drc_read8_poll(u32 a)
  sh2_drc_read8_poll = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg1, offsetof(SH2, read8_map));
  EMITH_HINT_COND(DCOND_CS);
  emith_sh2_rcall(arg0, arg1, arg2, arg3);
  EMITH_SJMP_START(DCOND_CC);
  emith_move_r_r_ptr_c(DCOND_CS, arg1, CONTEXT_REG);
  emith_abijump_reg_c(DCOND_CS, arg2);
  EMITH_SJMP_END(DCOND_CC);
  emith_and_r_r_r(arg1, arg0, arg3);
  emit_le_ptr8(-1, arg1);
  emith_read8s_r_r_r(arg1, arg2, arg1);
  emith_push_ret(arg1);
  emith_move_r_r_ptr(arg2, CONTEXT_REG);
  emith_abicall(p32x_sh2_poll_memory8);
  emith_pop_and_ret(arg1);
  emith_flush();

  // d = sh2_drc_read16_poll(u32 a)
  sh2_drc_read16_poll = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg1, offsetof(SH2, read16_map));
  EMITH_HINT_COND(DCOND_CS);
  emith_sh2_rcall(arg0, arg1, arg2, arg3);
  EMITH_SJMP_START(DCOND_CC);
  emith_move_r_r_ptr_c(DCOND_CS, arg1, CONTEXT_REG);
  emith_abijump_reg_c(DCOND_CS, arg2);
  EMITH_SJMP_END(DCOND_CC);
  emith_and_r_r_r(arg1, arg0, arg3);
  emith_read16s_r_r_r(arg1, arg2, arg1);
  emith_push_ret(arg1);
  emith_move_r_r_ptr(arg2, CONTEXT_REG);
  emith_abicall(p32x_sh2_poll_memory16);
  emith_pop_and_ret(arg1);
  emith_flush();

  // d = sh2_drc_read32_poll(u32 a)
  sh2_drc_read32_poll = (void *)tcache_ptr;
  emith_ctx_read_ptr(arg1, offsetof(SH2, read32_map));
  EMITH_HINT_COND(DCOND_CS);
  emith_sh2_rcall(arg0, arg1, arg2, arg3);
  EMITH_SJMP_START(DCOND_CC);
  emith_move_r_r_ptr_c(DCOND_CS, arg1, CONTEXT_REG);
  emith_abijump_reg_c(DCOND_CS, arg2);
  EMITH_SJMP_END(DCOND_CC);
  emith_and_r_r_r(arg1, arg0, arg3);
  emith_read_r_r_r(arg1, arg2, arg1);
  emit_le_swap(-1, arg1);
  emith_push_ret(arg1);
  emith_move_r_r_ptr(arg2, CONTEXT_REG);
  emith_abicall(p32x_sh2_poll_memory32);
  emith_pop_and_ret(arg1);
  emith_flush();

  // sh2_drc_exit(u32 pc)
  sh2_drc_exit = (void *)tcache_ptr;
  emith_ctx_write(arg0, SHR_PC * 4);
  emit_do_static_regs(1, arg2);
  emith_sh2_drc_exit();
  emith_flush();

  // sh2_drc_dispatcher(u32 pc)
  sh2_drc_dispatcher = (void *)tcache_ptr;
  emith_ctx_write(arg0, SHR_PC * 4);
#if BRANCH_CACHE
  // check if PC is in branch target cache
  emith_and_r_r_imm(arg1, arg0, (ARRAY_SIZE(sh2s->branch_cache)-1)*8);
  emith_add_r_r_r_lsl_ptr(arg1, CONTEXT_REG, arg1, sizeof(void *) == 8 ? 1 : 0);
  emith_read_r_r_offs(arg2, arg1, offsetof(SH2, branch_cache));
  emith_cmp_r_r(arg2, arg0);
  EMITH_SJMP_START(DCOND_NE);
#if (DRC_DEBUG & 128)
  emith_move_r_ptr_imm(arg2, (uptr)&bchit);
  emith_read_r_r_offs_c(DCOND_EQ, arg3, arg2, 0);
  emith_add_r_imm_c(DCOND_EQ, arg3, 1);
  emith_write_r_r_offs_c(DCOND_EQ, arg3, arg2, 0);
#endif
  emith_read_r_r_offs_ptr_c(DCOND_EQ, RET_REG, arg1, offsetof(SH2, branch_cache) + sizeof(void *));
  emith_jump_reg_c(DCOND_EQ, RET_REG);
  EMITH_SJMP_END(DCOND_NE);
#endif
  emith_move_r_r_ptr(arg1, CONTEXT_REG);
  emith_add_r_r_ptr_imm(arg2, CONTEXT_REG, offsetof(SH2, drc_tmp));
  emith_abicall(dr_lookup_block);
  // store PC and block entry ptr (in arg0) in branch target cache
  emith_tst_r_r_ptr(RET_REG, RET_REG);
  EMITH_SJMP_START(DCOND_EQ);
#if BRANCH_CACHE
#if (DRC_DEBUG & 128)
  emith_move_r_ptr_imm(arg2, (uptr)&bcmiss);
  emith_read_r_r_offs_c(DCOND_NE, arg3, arg2, 0);
  emith_add_r_imm_c(DCOND_NE, arg3, 1);
  emith_write_r_r_offs_c(DCOND_NE, arg3, arg2, 0);
#endif
  emith_ctx_read_c(DCOND_NE, arg2, SHR_PC * 4);
  emith_and_r_r_imm(arg1, arg2, (ARRAY_SIZE(sh2s->branch_cache)-1)*8);
  emith_add_r_r_r_lsl_ptr(arg1, CONTEXT_REG, arg1, sizeof(void *) == 8 ? 1 : 0);
  emith_write_r_r_offs_c(DCOND_NE, arg2, arg1, offsetof(SH2, branch_cache));
  emith_write_r_r_offs_ptr_c(DCOND_NE, RET_REG, arg1, offsetof(SH2, branch_cache) + sizeof(void *));
#endif
  emith_jump_reg_c(DCOND_NE, RET_REG);
  EMITH_SJMP_END(DCOND_EQ);
  // lookup failed, call sh2_translate()
  emith_move_r_r_ptr(arg0, CONTEXT_REG);
  emith_ctx_read(arg1, offsetof(SH2, drc_tmp)); // tcache_id
  emith_abicall(sh2_translate);
  emith_tst_r_r_ptr(RET_REG, RET_REG);
  EMITH_SJMP_START(DCOND_EQ);
  emith_jump_reg_c(DCOND_NE, RET_REG);
  EMITH_SJMP_END(DCOND_EQ);
  // XXX: can't translate, fail
  emith_abicall(dr_failure);
  emith_flush();

#if CALL_STACK
  // pc = sh2_drc_dispatcher_call(u32 pc)
  sh2_drc_dispatcher_call = (void *)tcache_ptr;
  emith_ctx_read(arg2, offsetof(SH2, rts_cache_idx));
  emith_add_r_imm(arg2, (u32)(2*sizeof(void *)));
  emith_and_r_imm(arg2, (ARRAY_SIZE(sh2s->rts_cache)-1) * 2*sizeof(void *));
  emith_ctx_write(arg2, offsetof(SH2, rts_cache_idx));
  emith_add_r_r_r_lsl_ptr(arg3, CONTEXT_REG, arg2, 0);
  rcache_get_reg_arg(2, SHR_PR, NULL);
  emith_add_r_ret(arg1);
  emith_write_r_r_offs_ptr(arg1, arg3, offsetof(SH2, rts_cache)+sizeof(void *));
  emith_write_r_r_offs(arg2, arg3, offsetof(SH2, rts_cache));
  rcache_flush();
  emith_ret();
  emith_flush();

  // sh2_drc_dispatcher_return(u32 pc)
  sh2_drc_dispatcher_return = (void *)tcache_ptr;
  emith_ctx_read(arg2, offsetof(SH2, rts_cache_idx));
  emith_add_r_r_r_lsl_ptr(arg1, CONTEXT_REG, arg2, 0);
  emith_read_r_r_offs(arg3, arg1, offsetof(SH2, rts_cache));
  emith_cmp_r_r(arg0, arg3);
#if (DRC_DEBUG & 128)
  EMITH_SJMP_START(DCOND_EQ);
  emith_move_r_ptr_imm(arg3, (uptr)&rcmiss);
  emith_read_r_r_offs_c(DCOND_NE, arg1, arg3, 0);
  emith_add_r_imm_c(DCOND_NE, arg1, 1);
  emith_write_r_r_offs_c(DCOND_NE, arg1, arg3, 0);
  emith_jump_cond(DCOND_NE, sh2_drc_dispatcher);
  EMITH_SJMP_END(DCOND_EQ);
#else
  emith_jump_cond(DCOND_NE, sh2_drc_dispatcher);
#endif
  emith_read_r_r_offs_ptr(arg0, arg1, offsetof(SH2, rts_cache) + sizeof(void *));
  emith_sub_r_imm(arg2, (u32)(2*sizeof(void *)));
  emith_and_r_imm(arg2, (ARRAY_SIZE(sh2s->rts_cache)-1) * 2*sizeof(void *));
  emith_ctx_write(arg2, offsetof(SH2, rts_cache_idx));
#if (DRC_DEBUG & 128)
  emith_move_r_ptr_imm(arg3, (uptr)&rchit);
  emith_read_r_r_offs(arg1, arg3, 0);
  emith_add_r_imm(arg1, 1);
  emith_write_r_r_offs(arg1, arg3, 0);
#endif
  emith_jump_reg(arg0);
  emith_flush();
#endif

  // sh2_drc_test_irq(void)
  // assumes it's called from main function (may jump to dispatcher)
  sh2_drc_test_irq = (void *)tcache_ptr;
  emith_ctx_read(arg1, offsetof(SH2, pending_level));
  sr = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
  emith_lsr(arg0, sr, I_SHIFT);
  emith_and_r_imm(arg0, 0x0f);
  emith_cmp_r_r(arg1, arg0); // pending_level > ((sr >> 4) & 0x0f)?
  EMITH_SJMP_START(DCOND_GT);
  emith_ret_c(DCOND_LE);     // nope, return
  EMITH_SJMP_END(DCOND_GT);
  // adjust SP
  tmp = rcache_get_reg(SHR_SP, RC_GR_RMW, NULL);
  emith_sub_r_imm(tmp, 4*2);
  rcache_clean();
  // push SR
  tmp = rcache_get_reg_arg(0, SHR_SP, &tmp2);
  emith_add_r_r_imm(tmp, tmp2, 4);
  tmp = rcache_get_reg_arg(1, SHR_SR, NULL);
  emith_clear_msb(tmp, tmp, 22);
  emith_move_r_r_ptr(arg2, CONTEXT_REG);
  rcache_invalidate_tmp();
  emith_abicall(p32x_sh2_write32); // XXX: use sh2_drc_write32?
  // push PC
  rcache_get_reg_arg(0, SHR_SP, NULL);
  rcache_get_reg_arg(1, SHR_PC, NULL);
  emith_move_r_r_ptr(arg2, CONTEXT_REG);
  rcache_invalidate_tmp();
  emith_abicall(p32x_sh2_write32);
  // update I, cycles, do callback
  emith_ctx_read(arg1, offsetof(SH2, pending_level));
  sr = rcache_get_reg(SHR_SR, RC_GR_RMW, NULL);
  emith_bic_r_imm(sr, I);
  emith_or_r_r_lsl(sr, arg1, I_SHIFT);
  emith_sub_r_imm(sr, 13 << 12); // at least 13 cycles
  rcache_flush();
  emith_move_r_r_ptr(arg0, CONTEXT_REG);
  emith_abicall_ctx(offsetof(SH2, irq_callback)); // vector = sh2->irq_callback(sh2, level);
  // obtain new PC
  tmp = rcache_get_reg_arg(1, SHR_VBR, &tmp2);
  emith_add_r_r_r_lsl(arg0, tmp2, RET_REG, 2);
  emith_call(sh2_drc_read32);
  if (arg0 != RET_REG)
    emith_move_r_r(arg0, RET_REG);
  emith_call_cleanup();
  rcache_invalidate();
  emith_jump(sh2_drc_dispatcher);
  emith_flush();

  // sh2_drc_entry(SH2 *sh2)
  sh2_drc_entry = (void *)tcache_ptr;
  emith_sh2_drc_entry();
  emith_move_r_r_ptr(CONTEXT_REG, arg0); // move ctx, arg0
  emit_do_static_regs(0, arg2);
  emith_call(sh2_drc_test_irq);
  emith_ctx_read(arg0, SHR_PC * 4);
  emith_jump(sh2_drc_dispatcher);
  emith_flush();

#ifdef DRC_SR_REG
  // sh2_drc_save_sr(SH2 *sh2)
  sh2_drc_save_sr = (void *)tcache_ptr;
  tmp = rcache_get_reg(SHR_SR, RC_GR_READ, NULL);
  emith_write_r_r_offs(tmp, arg0, SHR_SR * 4);
  rcache_invalidate();
  emith_ret();
  emith_flush();

  // sh2_drc_restore_sr(SH2 *sh2)
  sh2_drc_restore_sr = (void *)tcache_ptr;
  tmp = rcache_get_reg(SHR_SR, RC_GR_WRITE, NULL);
  emith_read_r_r_offs(tmp, arg0, SHR_SR * 4);
  rcache_flush();
  emith_ret();
  emith_flush();
#endif

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
    emith_flush(); \
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
    emith_move_r_r_ptr(arg2, CONTEXT_REG);                \
    emith_jump(func); \
    emith_flush(); \
    func = tmp; \
  }

  MAKE_READ_WRAPPER(sh2_drc_read8);
  MAKE_READ_WRAPPER(sh2_drc_read16);
  MAKE_READ_WRAPPER(sh2_drc_read32);
  MAKE_WRITE_WRAPPER(sh2_drc_write8);
  MAKE_WRITE_WRAPPER(sh2_drc_write16);
  MAKE_WRITE_WRAPPER(sh2_drc_write32);
  MAKE_READ_WRAPPER(sh2_drc_read8_poll);
  MAKE_READ_WRAPPER(sh2_drc_read16_poll);
  MAKE_READ_WRAPPER(sh2_drc_read32_poll);
#endif

  emith_pool_commit(0);
  rcache_invalidate();
#if (DRC_DEBUG & 4)
  host_dasm_new_symbol(sh2_drc_entry);
  host_dasm_new_symbol(sh2_drc_dispatcher);
#if CALL_STACK
  host_dasm_new_symbol(sh2_drc_dispatcher_call);
  host_dasm_new_symbol(sh2_drc_dispatcher_return);
#endif
  host_dasm_new_symbol(sh2_drc_exit);
  host_dasm_new_symbol(sh2_drc_test_irq);
  host_dasm_new_symbol(sh2_drc_write8);
  host_dasm_new_symbol(sh2_drc_write16);
  host_dasm_new_symbol(sh2_drc_write32);
  host_dasm_new_symbol(sh2_drc_read8);
  host_dasm_new_symbol(sh2_drc_read16);
  host_dasm_new_symbol(sh2_drc_read32);
  host_dasm_new_symbol(sh2_drc_read8_poll);
  host_dasm_new_symbol(sh2_drc_read16_poll);
  host_dasm_new_symbol(sh2_drc_read32_poll);
#ifdef DRC_SR_REG
  host_dasm_new_symbol(sh2_drc_save_sr);
  host_dasm_new_symbol(sh2_drc_restore_sr);
#endif
#endif

#if DRC_DEBUG
  host_insn_count = hic;
#endif
}

static void sh2_smc_rm_blocks(u32 a, int len, int tcache_id, int free)
{
  struct block_list **blist, *entry, *next;
  u32 mask = RAM_SIZE(tcache_id) - 1;
  u32 wtmask = ~0x20000000; // writethrough area mask
  u32 start_addr, end_addr;
  u32 start_lit, end_lit;
  struct block_desc *block;
  int removed = 0, rest;

  // ignore cache-through
  a &= wtmask;

  do {
    blist = &inval_lookup[tcache_id][(a & mask) / INVAL_PAGE_SIZE];
    entry = *blist;
    // go through the block list for this range
    while (entry != NULL) {
      next = entry->next;
      block = entry->block;
      start_addr = block->addr & wtmask;
      end_addr = start_addr + block->size;
      start_lit = block->addr_lit & wtmask;
      end_lit = start_lit + block->size_lit;
      // disable/delete block if it covers the modified address
      if ((start_addr < a+len && a < end_addr) ||
          (start_lit < a+len && a < end_lit))
      {
        dbg(2, "smc remove @%08x", a);
        end_addr = (start_lit < a+len && block->size_lit ? a : 0);
        dr_rm_block_entry(block, tcache_id, end_addr, free);
        removed = 1;
      }
      entry = next;
    }
    rest = INVAL_PAGE_SIZE - (a & (INVAL_PAGE_SIZE-1));
    a += rest, len -= rest;
  } while (len > 0);

  if (!removed) {
    if (len <= 4)
      dbg(2, "rm_blocks called @%08x, no work?", _a);
    return;
  }

#if BRANCH_CACHE
  if (tcache_id)
    memset32(sh2s[tcache_id-1].branch_cache, -1, sizeof(sh2s[0].branch_cache)/4);
  else {
    memset32(sh2s[0].branch_cache, -1, sizeof(sh2s[0].branch_cache)/4);
    memset32(sh2s[1].branch_cache, -1, sizeof(sh2s[1].branch_cache)/4);
  }
#endif
#if CALL_STACK
  if (tcache_id) {
    memset32(sh2s[tcache_id-1].rts_cache, -1, sizeof(sh2s[0].rts_cache)/4);
    sh2s[tcache_id-1].rts_cache_idx = 0;
  } else {
    memset32(sh2s[0].rts_cache, -1, sizeof(sh2s[0].rts_cache)/4);
    memset32(sh2s[1].rts_cache, -1, sizeof(sh2s[1].rts_cache)/4);
    sh2s[0].rts_cache_idx = sh2s[1].rts_cache_idx = 0;
  }
#endif
}

void sh2_drc_wcheck_ram(u32 a, unsigned len, SH2 *sh2)
{
  sh2_smc_rm_blocks(a, len, 0, 0);
}

void sh2_drc_wcheck_da(u32 a, unsigned len, SH2 *sh2)
{
  sh2_smc_rm_blocks(a, len, 1 + sh2->is_slave, 0);
}

int sh2_execute_drc(SH2 *sh2c, int cycles)
{
  int ret_cycles;

  // cycles are kept in SHR_SR unused bits (upper 20)
  // bit11 contains T saved for delay slot
  // others are usual SH2 flags
  sh2c->sr &= 0x3f3;
  sh2c->sr |= (cycles-1) << 12;
#if (DRC_DEBUG & 8)
  lastpc = lastcnt = 0;
#endif

  sh2c->state |= SH2_IN_DRC;
  host_call(sh2_drc_entry, (SH2 *))(sh2c);
  sh2c->state &= ~SH2_IN_DRC;

  // TODO: irq cycles
  ret_cycles = (int32_t)sh2c->sr >> 12;
  if (ret_cycles >= 0)
    dbg(1, "warning: drc returned with cycles: %d, pc %08x", ret_cycles, sh2c->pc);
#if (DRC_DEBUG & 8)
  if (lastcnt)
    dbg(8, "= %csh2 enter %08x %p (%d times), c=%d", sh2c->is_slave?'s':'m',
      lastpc, lastblock, lastcnt, (signed int)sh2c->sr >> 12);
#endif

  sh2c->sr &= 0x3f3;
  return ret_cycles+1;
}

static void block_stats(void)
{
#if (DRC_DEBUG & 2)
  int c, b, i;
  long total = 0;

  printf("block stats:\n");
  for (b = 0; b < ARRAY_SIZE(block_tables); b++) {
    for (i = block_ring[b].first; i != block_ring[b].next; i = (i+1)%block_ring[b].size)
      if (block_tables[b][i].addr != 0)
        total += block_tables[b][i].refcount;
  }
  printf("total: %ld\n",total);

  for (c = 0; c < 20; c++) {
    struct block_desc *blk, *maxb = NULL;
    int max = 0;
    for (b = 0; b < ARRAY_SIZE(block_tables); b++) {
      for (i = block_ring[b].first; i != block_ring[b].next; i = (i+1)%block_ring[b].size)
        if ((blk = &block_tables[b][i])->addr != 0 && blk->refcount > max) {
          max = blk->refcount;
          maxb = blk;
        }
    }
    if (maxb == NULL)
      break;
    printf("%08lx %p %9d %2.3f%%\n", (ulong)maxb->addr, maxb->tcache_ptr, maxb->refcount,
      (double)maxb->refcount / total * 100.0);
    maxb->refcount = 0;
  }

  for (b = 0; b < ARRAY_SIZE(block_tables); b++) 
    for (i = block_ring[b].first; i != block_ring[b].next; i = (i+1)%block_ring[b].size)
      block_tables[b][i].refcount = 0;
#endif
}

void entry_stats(void)
{
#if (DRC_DEBUG & 32)
  int c, b, i, j;
  long total = 0;

  printf("block entry stats:\n");
  for (b = 0; b < ARRAY_SIZE(block_tables); b++) {
    for (i = block_ring[b].first; i != block_ring[b].next; i = (i+1)%block_ring[b].size)
      for (j = 0; j < block_tables[b][i].entry_count; j++)
        total += block_tables[b][i].entryp[j].entry_count;
  }
  printf("total: %ld\n",total);

  for (c = 0; c < 20; c++) {
    struct block_desc *blk;
    struct block_entry *maxb = NULL;
    int max = 0;
    for (b = 0; b < ARRAY_SIZE(block_tables); b++) {
      for (i = block_ring[b].first; i != block_ring[b].next; i = (i+1)%block_ring[b].size) {
        blk = &block_tables[b][i];
        for (j = 0; j < blk->entry_count; j++)
          if (blk->entryp[j].entry_count > max) {
            max = blk->entryp[j].entry_count;
            maxb = &blk->entryp[j];
          }
      }
    }
    if (maxb == NULL)
      break;
    printf("%08lx %p %9d %2.3f%%\n", (ulong)maxb->pc, maxb->tcache_ptr, maxb->entry_count,
      (double)100 * maxb->entry_count / total);
    maxb->entry_count = 0;
  }

  for (b = 0; b < ARRAY_SIZE(block_tables); b++) {
    for (i = block_ring[b].first; i != block_ring[b].next; i = (i+1)%block_ring[b].size)
      for (j = 0; j < block_tables[b][i].entry_count; j++)
        block_tables[b][i].entryp[j].entry_count = 0;
  }
#endif
}

static void backtrace(void)
{
#if (DRC_DEBUG & 1024)
  int i;
  printf("backtrace master:\n");
  for (i = 0; i < ARRAY_SIZE(csh2[0]); i++)
    SH2_DUMP(&csh2[0][i], "bt msh2");
  printf("backtrace slave:\n");
  for (i = 0; i < ARRAY_SIZE(csh2[1]); i++)
    SH2_DUMP(&csh2[1][i], "bt ssh2");
#endif
}

static void state_dump(void)
{
#if (DRC_DEBUG & 2048)
  int i;

  SH2_DUMP(&sh2s[0], "master");
  printf("VBR msh2: %lx\n", (ulong)sh2s[0].vbr);
  for (i = 0; i < 0x60; i++) {
    printf("%08lx ",(ulong)p32x_sh2_read32(sh2s[0].vbr + i*4, &sh2s[0]));
    if ((i+1) % 8 == 0) printf("\n");
  }
  printf("stack msh2: %lx\n", (ulong)sh2s[0].r[15]);
  for (i = -0x30; i < 0x30; i++) {
    printf("%08lx ",(ulong)p32x_sh2_read32(sh2s[0].r[15] + i*4, &sh2s[0]));
    if ((i+1) % 8 == 0) printf("\n");
  }
  SH2_DUMP(&sh2s[1], "slave");
  printf("VBR ssh2: %lx\n", (ulong)sh2s[1].vbr);
  for (i = 0; i < 0x60; i++) {
    printf("%08lx ",(ulong)p32x_sh2_read32(sh2s[1].vbr + i*4, &sh2s[1]));
    if ((i+1) % 8 == 0) printf("\n");
  }
  printf("stack ssh2: %lx\n", (ulong)sh2s[1].r[15]);
  for (i = -0x30; i < 0x30; i++) {
    printf("%08lx ",(ulong)p32x_sh2_read32(sh2s[1].r[15] + i*4, &sh2s[1]));
    if ((i+1) % 8 == 0) printf("\n");
  }
#endif
}

static void bcache_stats(void)
{
#if (DRC_DEBUG & 128)
  int i;
#if CALL_STACK
  for (i = 1; i < ARRAY_SIZE(sh2s->rts_cache); i++)
    if (sh2s[0].rts_cache[i].pc == -1 && sh2s[1].rts_cache[i].pc == -1) break;

  printf("return cache hits:%d misses:%d depth: %d index: %d/%d\n", rchit, rcmiss, i,sh2s[0].rts_cache_idx,sh2s[1].rts_cache_idx);
  for (i = 0; i < ARRAY_SIZE(sh2s[0].rts_cache); i++) {
    printf("%08lx ",(ulong)sh2s[0].rts_cache[i].pc);
    if ((i+1) % 8 == 0) printf("\n");
  }
  for (i = 0; i < ARRAY_SIZE(sh2s[1].rts_cache); i++) {
    printf("%08lx ",(ulong)sh2s[1].rts_cache[i].pc);
    if ((i+1) % 8 == 0) printf("\n");
  }
#endif
#if BRANCH_CACHE
  printf("branch cache hits:%d misses:%d\n", bchit, bcmiss);
  printf("branch cache master:\n");
  for (i = 0; i < ARRAY_SIZE(sh2s[0].branch_cache); i++) {
    printf("%08lx ",(ulong)sh2s[0].branch_cache[i].pc);
    if ((i+1) % 8 == 0) printf("\n");
  }
  printf("branch cache slave:\n");
  for (i = 0; i < ARRAY_SIZE(sh2s[1].branch_cache); i++) {
    printf("%08lx ",(ulong)sh2s[1].branch_cache[i].pc);
    if ((i+1) % 8 == 0) printf("\n");
  }
#endif
#endif
}

void sh2_drc_flush_all(void)
{
  backtrace();
  state_dump();
  block_stats();
  entry_stats();
  bcache_stats();
  dr_flush_tcache(0);
  dr_flush_tcache(1);
  dr_flush_tcache(2);
  Pico32x.emu_flags &= ~P32XF_DRC_ROM_C;
}

void sh2_drc_mem_setup(SH2 *sh2)
{
  // fill the DRC-only convenience pointers
  sh2->p_drcblk_da = Pico32xMem->drcblk_da[!!sh2->is_slave];
  sh2->p_drcblk_ram = Pico32xMem->drcblk_ram;
}

int sh2_drc_init(SH2 *sh2)
{
  int i;

  if (block_tables[0] == NULL)
  {
    for (i = 0; i < TCACHE_BUFFERS; i++) {
      block_tables[i] = calloc(BLOCK_MAX_COUNT(i), sizeof(*block_tables[0]));
      if (block_tables[i] == NULL)
        goto fail;
      entry_tables[i] = calloc(ENTRY_MAX_COUNT(i), sizeof(*entry_tables[0]));
      if (entry_tables[i] == NULL)
        goto fail;
      block_link_pool[i] = calloc(BLOCK_LINK_MAX_COUNT(i),
                          sizeof(*block_link_pool[0]));
      if (block_link_pool[i] == NULL)
        goto fail;

      inval_lookup[i] = calloc(RAM_SIZE(i) / INVAL_PAGE_SIZE,
                               sizeof(inval_lookup[0]));
      if (inval_lookup[i] == NULL)
        goto fail;

      hash_tables[i] = calloc(HASH_TABLE_SIZE(i), sizeof(*hash_tables[0]));
      if (hash_tables[i] == NULL)
        goto fail;

      unresolved_links[i] = calloc(HASH_TABLE_SIZE(i), sizeof(*unresolved_links[0]));
      if (unresolved_links[i] == NULL)
        goto fail;
//atexit(sh2_drc_finish);

      RING_INIT(&block_ring[i], block_tables[i], BLOCK_MAX_COUNT(i));
      RING_INIT(&entry_ring[i], entry_tables[i], ENTRY_MAX_COUNT(i));
    }

    block_list_pool = calloc(BLOCK_LIST_MAX_COUNT, sizeof(*block_list_pool));
    if (block_list_pool == NULL)
      goto fail;
    block_list_pool_count = 0;
    blist_free = NULL;

    memset(block_link_pool_counts, 0, sizeof(block_link_pool_counts));
    memset(blink_free, 0, sizeof(blink_free));

    drc_cmn_init();
    rcache_init();

    tcache_ptr = tcache;
    sh2_generate_utils();
    host_instructions_updated(tcache, tcache_ptr, 1);
    emith_update_cache();

    i = tcache_ptr - tcache;
    RING_INIT(&tcache_ring[0], tcache_ptr, tcache_sizes[0] - i);
    for (i = 1; i < ARRAY_SIZE(tcache_ring); i++) {
      RING_INIT(&tcache_ring[i], tcache_ring[i-1].base + tcache_ring[i-1].size,
                  tcache_sizes[i]);
    }

#if (DRC_DEBUG & 4)
    for (i = 0; i < ARRAY_SIZE(block_tables); i++)
      tcache_dsm_ptrs[i] = tcache_ring[i].base;
    // disasm the utils
    tcache_dsm_ptrs[0] = tcache;
    do_host_disasm(0);
#endif
#if (DRC_DEBUG & 1)
    hash_collisions = 0;
#endif
  }
  memset(sh2->branch_cache, -1, sizeof(sh2->branch_cache));
  memset(sh2->rts_cache, -1, sizeof(sh2->rts_cache));
  sh2->rts_cache_idx = 0;

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

#if (DRC_DEBUG & (256|512))
   if (trace[0]) fclose(trace[0]);
   if (trace[1]) fclose(trace[1]);
   trace[0] = trace[1] = NULL;
#endif

#if (DRC_DEBUG & 4)
  for (i = 0; i < TCACHE_BUFFERS; i++) {
    printf("~~~ tcache %d\n", i);
#if 0
    if (tcache_ring[i].first < tcache_ring[i].next) {
      tcache_dsm_ptrs[i] = tcache_ring[i].first;
      tcache_ptr = tcache_ring[i].next;
      do_host_disasm(i);
    } else if (tcache_ring[i].used) {
      tcache_dsm_ptrs[i] = tcache_ring[i].first;
      tcache_ptr = tcache_ring[i].base + tcache_ring[i].size;
      do_host_disasm(i);
      tcache_dsm_ptrs[i] = tcache_ring[i].base;
      tcache_ptr = tcache_ring[i].next;
      do_host_disasm(i);
    }
#endif
    printf("max links: %d\n", block_link_pool_counts[i]);
  }
  printf("max block list: %d\n", block_list_pool_count);
#endif

  sh2_drc_flush_all();

  for (i = 0; i < TCACHE_BUFFERS; i++) {
    if (block_tables[i] != NULL)
      free(block_tables[i]);
    block_tables[i] = NULL;
    if (entry_tables[i] != NULL)
      free(entry_tables[i]);
    entry_tables[i] = NULL;
    if (block_link_pool[i] != NULL)
      free(block_link_pool[i]);
    block_link_pool[i] = NULL;
    blink_free[i] = NULL;

    if (inval_lookup[i] != NULL)
      free(inval_lookup[i]);
    inval_lookup[i] = NULL;

    if (hash_tables[i] != NULL) {
      free(hash_tables[i]);
      hash_tables[i] = NULL;
    }

    if (unresolved_links[i] != NULL) {
      free(unresolved_links[i]);
      unresolved_links[i] = NULL;
    }
  }

  if (block_list_pool != NULL)
    free(block_list_pool);
  block_list_pool = NULL;
  blist_free = NULL;

  drc_cmn_cleanup();
}

#endif /* DRC_SH2 */

static void *dr_get_pc_base(u32 pc, SH2 *sh2)
{
  void *ret;
  u32 mask = 0;

  ret = p32x_sh2_get_mem_ptr(pc, &mask, sh2);
  if (ret == (void *)-1)
    return ret;

  return (char *)ret - (pc & ~mask);
}

u16 scan_block(u32 base_pc, int is_slave, u8 *op_flags, u32 *end_pc_out,
  u32 *base_literals_out, u32 *end_literals_out)
{
  u16 *dr_pc_base;
  u32 pc, op, tmp;
  u32 end_pc, end_literals = 0;
  u32 lowest_literal = 0;
  u32 lowest_mova = 0;
  struct op_data *opd;
  int next_is_delay = 0;
  int end_block = 0;
  int is_divop;
  int i, i_end, i_div = -1;
  u32 crc = 0;
  // 2nd pass stuff
  int last_btarget; // loop detector 
  enum { T_UNKNOWN, T_CLEAR, T_SET } t; // T propagation state

  memset(op_flags, 0, sizeof(*op_flags) * BLOCK_INSN_LIMIT);
  op_flags[0] |= OF_BTARGET; // block start is always a target

  dr_pc_base = dr_get_pc_base(base_pc, &sh2s[!!is_slave]);

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
    else if ((lowest_mova && lowest_mova <= pc) ||
              (lowest_literal && lowest_literal <= pc))
      break; // text area collides with data area

    is_divop = 0;
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
          tmp = BITMASK2(SHR_SR, SHR_T);
          break;
        case 1: // STC GBR,Rn 0000nnnn00010010
          tmp = BITMASK1(SHR_GBR);
          break;
        case 2: // STC VBR,Rn 0000nnnn00100010
          tmp = BITMASK1(SHR_VBR);
          break;
        default:
          goto undefined;
        }
        opd->op = OP_MOVE;
        opd->source = tmp;
        opd->dest = BITMASK1(GET_Rn());
        break;
      case 0x03:
        CHECK_UNHANDLED_BITS(0xd0, undefined);
        // BRAF Rm    0000mmmm00100011
        // BSRF Rm    0000mmmm00000011
        opd->op = OP_BRANCH_RF;
        opd->rm = GET_Rn();
        opd->source = BITMASK2(SHR_PC, opd->rm);
        opd->dest = BITMASK1(SHR_PC);
        if (!(op & 0x20))
          opd->dest |= BITMASK1(SHR_PR);
        opd->cycles = 2;
        next_is_delay = 1;
        if (!(opd->dest & BITMASK1(SHR_PR)))
          end_block = !(op_flags[i+1+next_is_delay] & OF_BTARGET);
        else
          op_flags[i+1+next_is_delay] |= OF_BTARGET;
        break;
      case 0x04: // MOV.B Rm,@(R0,Rn)   0000nnnnmmmm0100
      case 0x05: // MOV.W Rm,@(R0,Rn)   0000nnnnmmmm0101
      case 0x06: // MOV.L Rm,@(R0,Rn)   0000nnnnmmmm0110
        opd->source = BITMASK3(GET_Rm(), SHR_R0, GET_Rn());
        opd->dest = BITMASK1(SHR_MEM);
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
          opd->dest = BITMASK2(SHR_MACL, SHR_MACH);
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
          opd->op = OP_DIV0;
          opd->source = BITMASK1(SHR_SR);
          opd->dest = BITMASK2(SHR_SR, SHR_T);
          div(opd) = (struct div){ .rn=SHR_MEM, .rm=SHR_MEM, .ro=SHR_MEM };
          i_div = i;
          is_divop = 1;
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
          end_block = !(op_flags[i+1+next_is_delay] & OF_BTARGET);
          break;
        case 1: // SLEEP      0000000000011011
          opd->op = OP_SLEEP;
          opd->cycles = 3;
          end_block = 1;
          break;
        case 2: // RTE        0000000000101011
          opd->op = OP_RTE;
          opd->source = BITMASK1(SHR_SP);
          opd->dest = BITMASK4(SHR_SP, SHR_SR, SHR_T, SHR_PC);
          opd->cycles = 4;
          next_is_delay = 1;
          end_block = !(op_flags[i+1+next_is_delay] & OF_BTARGET);
          break;
        default:
          goto undefined;
        }
        break;
      case 0x0c: // MOV.B    @(R0,Rm),Rn      0000nnnnmmmm1100
      case 0x0d: // MOV.W    @(R0,Rm),Rn      0000nnnnmmmm1101
      case 0x0e: // MOV.L    @(R0,Rm),Rn      0000nnnnmmmm1110
        opd->source = BITMASK3(GET_Rm(), SHR_R0, SHR_MEM);
        opd->dest = BITMASK1(GET_Rn());
        op_flags[i] |= OF_POLL_INSN;
        break;
      case 0x0f: // MAC.L   @Rm+,@Rn+  0000nnnnmmmm1111
        opd->source = BITMASK6(GET_Rm(), GET_Rn(), SHR_SR, SHR_MACL, SHR_MACH, SHR_MEM);
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
      opd->source = BITMASK2(GET_Rm(), GET_Rn());
      opd->dest = BITMASK1(SHR_MEM);
      opd->imm = (op & 0x0f) * 4;
      break;

    /////////////////////////////////////////////
    case 0x02:
      switch (op & 0x0f)
      {
      case 0x00: // MOV.B Rm,@Rn        0010nnnnmmmm0000
      case 0x01: // MOV.W Rm,@Rn        0010nnnnmmmm0001
      case 0x02: // MOV.L Rm,@Rn        0010nnnnmmmm0010
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK1(SHR_MEM);
        break;
      case 0x04: // MOV.B Rm,@-Rn       0010nnnnmmmm0100
      case 0x05: // MOV.W Rm,@-Rn       0010nnnnmmmm0101
      case 0x06: // MOV.L Rm,@-Rn       0010nnnnmmmm0110
        opd->source = BITMASK2(GET_Rm(), GET_Rn());
        opd->dest = BITMASK2(GET_Rn(), SHR_MEM);
        break;
      case 0x07: // DIV0S Rm,Rn         0010nnnnmmmm0111
        opd->op = OP_DIV0;
        opd->source = BITMASK3(SHR_SR, GET_Rm(), GET_Rn());
        opd->dest = BITMASK2(SHR_SR, SHR_T);
        div(opd) = (struct div){ .rn=GET_Rn(), .rm=GET_Rm(), .ro=SHR_MEM };
        i_div = i;
        is_divop = 1;
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
        opd->source = BITMASK4(GET_Rm(), GET_Rn(), SHR_SR, SHR_T);
        opd->dest = BITMASK3(GET_Rn(), SHR_SR, SHR_T);
        if (i_div >= 0) {
          // divide operation: all DIV1 operations must use the same reg pair
          if (div(&ops[i_div]).rn == SHR_MEM)
            div(&ops[i_div]).rn=GET_Rn(), div(&ops[i_div]).rm=GET_Rm();
          if (div(&ops[i_div]).rn == GET_Rn() && div(&ops[i_div]).rm == GET_Rm()) {
            div(&ops[i_div]).div1 += 1;
            div(&ops[i_div]).state = 0;
            is_divop = 1;
          } else {
            ops[i_div].imm = 0;
            i_div = -1;
          }
        }
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
          op_flags[i] |= OF_DELAY_INSN;
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
          tmp = BITMASK1(SHR_MACH);
          break;
        case 0x12: // STS.L    MACL,@-Rn 0100nnnn00010010
          tmp = BITMASK1(SHR_MACL);
          break;
        case 0x22: // STS.L    PR,@-Rn   0100nnnn00100010
          tmp = BITMASK1(SHR_PR);
          break;
        case 0x03: // STC.L    SR,@-Rn   0100nnnn00000011
          tmp = BITMASK2(SHR_SR, SHR_T);
          opd->cycles = 2;
          break;
        case 0x13: // STC.L    GBR,@-Rn  0100nnnn00010011
          tmp = BITMASK1(SHR_GBR);
          opd->cycles = 2;
          break;
        case 0x23: // STC.L    VBR,@-Rn  0100nnnn00100011
          tmp = BITMASK1(SHR_VBR);
          opd->cycles = 2;
          break;
        default:
          goto undefined;
        }
        opd->source = BITMASK1(GET_Rn()) | tmp;
        opd->dest = BITMASK2(GET_Rn(), SHR_MEM);
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
          if (i_div >= 0) {
            // divide operation: all ROTCL operations must use the same register
            if (div(&ops[i_div]).ro == SHR_MEM)
              div(&ops[i_div]).ro = GET_Rn();
            if (div(&ops[i_div]).ro == GET_Rn() && !div(&ops[i_div]).state) {
              div(&ops[i_div]).rotcl += 1;
              div(&ops[i_div]).state = 1;
              is_divop = 1;
            } else {
              ops[i_div].imm = 0;
              i_div = -1;
            }
          }
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
          tmp = BITMASK1(SHR_MACH);
          break;
        case 0x16: // LDS.L @Rm+,MACL 0100mmmm00010110
          tmp = BITMASK1(SHR_MACL);
          break;
        case 0x26: // LDS.L @Rm+,PR   0100mmmm00100110
          tmp = BITMASK1(SHR_PR);
          break;
        case 0x07: // LDC.L @Rm+,SR   0100mmmm00000111
          tmp = BITMASK2(SHR_SR, SHR_T);
          opd->op = OP_LDC;
          opd->cycles = 3;
          break;
        case 0x17: // LDC.L @Rm+,GBR  0100mmmm00010111
          tmp = BITMASK1(SHR_GBR);
          opd->op = OP_LDC;
          opd->cycles = 3;
          break;
        case 0x27: // LDC.L @Rm+,VBR  0100mmmm00100111
          tmp = BITMASK1(SHR_VBR);
          opd->op = OP_LDC;
          opd->cycles = 3;
          break;
        default:
          goto undefined;
        }
        opd->source = BITMASK2(GET_Rn(), SHR_MEM);
        opd->dest = BITMASK1(GET_Rn()) | tmp;
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
          if (!(opd->dest & BITMASK1(SHR_PR)))
            end_block = !(op_flags[i+1+next_is_delay] & OF_BTARGET);
          else
            op_flags[i+1+next_is_delay] |= OF_BTARGET;
          break;
        case 1: // TAS.B @Rn  0100nnnn00011011
          opd->source = BITMASK2(GET_Rn(), SHR_MEM);
          opd->dest = BITMASK2(SHR_T, SHR_MEM);
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
          tmp = BITMASK2(SHR_SR, SHR_T);
          break;
        case 1: // LDC Rm,GBR  0100mmmm00011110
          tmp = BITMASK1(SHR_GBR);
          break;
        case 2: // LDC Rm,VBR  0100mmmm00101110
          tmp = BITMASK1(SHR_VBR);
          break;
        default:
          goto undefined;
        }
        opd->op = OP_LDC;
        opd->source = BITMASK1(GET_Rn());
        opd->dest = tmp;
        break;
      case 0x0f:
        // MAC.W @Rm+,@Rn+  0100nnnnmmmm1111
        opd->source = BITMASK6(GET_Rm(), GET_Rn(), SHR_SR, SHR_MACL, SHR_MACH, SHR_MEM);
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
      opd->source = BITMASK2(GET_Rm(), SHR_MEM);
      opd->dest = BITMASK1(GET_Rn());
      opd->imm = (op & 0x0f) * 4;
      op_flags[i] |= OF_POLL_INSN;
      break;

    /////////////////////////////////////////////
    case 0x06:
      switch (op & 0x0f)
      {
      case 0x04: // MOV.B @Rm+,Rn       0110nnnnmmmm0100
      case 0x05: // MOV.W @Rm+,Rn       0110nnnnmmmm0101
      case 0x06: // MOV.L @Rm+,Rn       0110nnnnmmmm0110
        opd->dest = BITMASK2(GET_Rm(), GET_Rn());
        opd->source = BITMASK2(GET_Rm(), SHR_MEM);
        break;
      case 0x00: // MOV.B @Rm,Rn        0110nnnnmmmm0000
      case 0x01: // MOV.W @Rm,Rn        0110nnnnmmmm0001
      case 0x02: // MOV.L @Rm,Rn        0110nnnnmmmm0010
        opd->dest = BITMASK1(GET_Rn());
        opd->source = BITMASK2(GET_Rm(), SHR_MEM);
        op_flags[i] |= OF_POLL_INSN;
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
      opd->imm = (s8)op;
      break;

    /////////////////////////////////////////////
    case 0x08:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,Rn)  10000000nnnndddd
        opd->source = BITMASK2(GET_Rm(), SHR_R0);
        opd->dest = BITMASK1(SHR_MEM);
        opd->imm = (op & 0x0f);
        break;
      case 0x0100: // MOV.W R0,@(disp,Rn)  10000001nnnndddd
        opd->source = BITMASK2(GET_Rm(), SHR_R0);
        opd->dest = BITMASK1(SHR_MEM);
        opd->imm = (op & 0x0f) * 2;
        break;
      case 0x0400: // MOV.B @(disp,Rm),R0  10000100mmmmdddd
        opd->source = BITMASK2(GET_Rm(), SHR_MEM);
        opd->dest = BITMASK1(SHR_R0);
        opd->imm = (op & 0x0f);
        op_flags[i] |= OF_POLL_INSN;
        break;
      case 0x0500: // MOV.W @(disp,Rm),R0  10000101mmmmdddd
        opd->source = BITMASK2(GET_Rm(), SHR_MEM);
        opd->dest = BITMASK1(SHR_R0);
        opd->imm = (op & 0x0f) * 2;
        op_flags[i] |= OF_POLL_INSN;
        break;
      case 0x0800: // CMP/EQ #imm,R0       10001000iiiiiiii
        opd->source = BITMASK1(SHR_R0);
        opd->dest = BITMASK1(SHR_T);
        opd->imm = (s8)op;
        break;
      case 0x0d00: // BT/S label 10001101dddddddd
      case 0x0f00: // BF/S label 10001111dddddddd
        next_is_delay = 1;
        // fallthrough
      case 0x0900: // BT   label 10001001dddddddd
      case 0x0b00: // BF   label 10001011dddddddd
        opd->op = (op & 0x0200) ? OP_BRANCH_CF : OP_BRANCH_CT;
        opd->source = BITMASK2(SHR_PC, SHR_T);
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
        else if (ops[i-1].op != OP_BRANCH_N)
          tmp = 0;
      }
      opd->source = BITMASK2(SHR_PC, SHR_MEM);
      opd->dest = BITMASK1(GET_Rn());
      if (tmp) {
        opd->imm = tmp + 2 + (op & 0xff) * 2;
        if (lowest_literal == 0 || opd->imm < lowest_literal)
          lowest_literal = opd->imm;
      }
      opd->size = 1;
      break;

    /////////////////////////////////////////////
    case 0x0b:
      // BSR  label 1011dddddddddddd
      opd->dest = BITMASK1(SHR_PR);
    case 0x0a:
      // BRA  label 1010dddddddddddd
      opd->op = OP_BRANCH;
      opd->source =  BITMASK1(SHR_PC);
      opd->dest |= BITMASK1(SHR_PC);
      opd->imm = ((signed int)(op << 20) >> 19);
      opd->imm += pc + 4;
      opd->cycles = 2;
      next_is_delay = 1;
      if (!(opd->dest & BITMASK1(SHR_PR))) {
        if (base_pc <= opd->imm && opd->imm < base_pc + BLOCK_INSN_LIMIT * 2) {
          op_flags[(opd->imm - base_pc) / 2] |= OF_BTARGET;
          if (opd->imm <= pc)
            end_block = !(op_flags[i+1+next_is_delay] & OF_BTARGET);
        } else
          end_block = !(op_flags[i+1+next_is_delay] & OF_BTARGET);
      } else
        op_flags[i+1+next_is_delay] |= OF_BTARGET;
      break;

    /////////////////////////////////////////////
    case 0x0c:
      switch (op & 0x0f00)
      {
      case 0x0000: // MOV.B R0,@(disp,GBR)   11000000dddddddd
      case 0x0100: // MOV.W R0,@(disp,GBR)   11000001dddddddd
      case 0x0200: // MOV.L R0,@(disp,GBR)   11000010dddddddd
        opd->source = BITMASK2(SHR_GBR, SHR_R0);
        opd->dest = BITMASK1(SHR_MEM);
        opd->size = (op & 0x300) >> 8;
        opd->imm = (op & 0xff) << opd->size;
        break;
      case 0x0400: // MOV.B @(disp,GBR),R0   11000100dddddddd
      case 0x0500: // MOV.W @(disp,GBR),R0   11000101dddddddd
      case 0x0600: // MOV.L @(disp,GBR),R0   11000110dddddddd
        opd->source = BITMASK2(SHR_GBR, SHR_MEM);
        opd->dest = BITMASK1(SHR_R0);
        opd->size = (op & 0x300) >> 8;
        opd->imm = (op & 0xff) << opd->size;
        op_flags[i] |= OF_POLL_INSN;
        break;
      case 0x0300: // TRAPA #imm      11000011iiiiiiii
        opd->op = OP_TRAPA;
        opd->source = BITMASK4(SHR_SP, SHR_PC, SHR_SR, SHR_T);
        opd->dest = BITMASK2(SHR_SP, SHR_PC);
        opd->imm = (op & 0xff);
        opd->cycles = 8;
        op_flags[i+1] |= OF_BTARGET;
        break;
      case 0x0700: // MOVA @(disp,PC),R0    11000111dddddddd
        opd->op = OP_MOVA;
        tmp = pc + 2;
        if (op_flags[i] & OF_DELAY_OP) {
          if (ops[i-1].op == OP_BRANCH)
            tmp = ops[i-1].imm;
          else if (ops[i-1].op != OP_BRANCH_N)
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
        opd->source = BITMASK3(SHR_GBR, SHR_R0, SHR_MEM);
        opd->dest = BITMASK1(SHR_T);
        opd->imm = op & 0xff;
        op_flags[i] |= OF_POLL_INSN;
        opd->cycles = 3;
        break;
      case 0x0d00: // AND.B #imm,@(R0,GBR)  11001101iiiiiiii
      case 0x0e00: // XOR.B #imm,@(R0,GBR)  11001110iiiiiiii
      case 0x0f00: // OR.B  #imm,@(R0,GBR)  11001111iiiiiiii
        opd->source = BITMASK3(SHR_GBR, SHR_R0, SHR_MEM);
        opd->dest = BITMASK1(SHR_MEM);
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
        else if (ops[i-1].op != OP_BRANCH_N)
          tmp = 0;
      }
      opd->source = BITMASK2(SHR_PC, SHR_MEM);
      opd->dest = BITMASK1(GET_Rn());
      if (tmp) {
        opd->imm = (tmp + 2 + (op & 0xff) * 4) & ~3;
        if (lowest_literal == 0 || opd->imm < lowest_literal)
          lowest_literal = opd->imm;
      }
      opd->size = 2;
      break;

    /////////////////////////////////////////////
    case 0x0e:
      // MOV #imm,Rn   1110nnnniiiiiiii
      opd->op = OP_LOAD_CONST;
      opd->dest = BITMASK1(GET_Rn());
      opd->imm = (s8)op;
      break;

    default:
    undefined:
      opd->op = OP_UNDEFINED;
      // an unhandled instruction is probably not code if it's not the 1st insn
      if (!(op_flags[i] & OF_DELAY_OP) && pc != base_pc)
        goto end; 
      break;
    }

    if (op_flags[i] & OF_DELAY_OP) {
      switch (opd->op) {
      case OP_BRANCH:
      case OP_BRANCH_N:
      case OP_BRANCH_CT:
      case OP_BRANCH_CF:
      case OP_BRANCH_R:
      case OP_BRANCH_RF:
        elprintf(EL_ANOMALY, "%csh2 drc: branch in DS @ %08x",
          is_slave ? 's' : 'm', pc);
        opd->op = OP_UNDEFINED;
        op_flags[i] |= OF_B_IN_DS;
        next_is_delay = 0;
        break;
      }
    } else if (!is_divop && i_div >= 0)
      i_div = -1;       // divide parser stop
  }
end:
  i_end = i;
  end_pc = pc;

  // 2nd pass: some analysis
  lowest_literal = end_literals = lowest_mova = 0;
  t = T_UNKNOWN; // T flag state
  last_btarget = 0;
  op = 0; // delay/poll insns counter
  is_divop = 0; // divide op insns counter
  i_div = -1; // index of current divide op
  for (i = 0, pc = base_pc; i < i_end; i++, pc += 2) {
    opd = &ops[i];
    crc += FETCH_OP(pc);

    // propagate T (TODO: DIV0U)
    if (op_flags[i] & OF_BTARGET)
      t = T_UNKNOWN;

    if ((opd->op == OP_BRANCH_CT && t == T_SET) ||
        (opd->op == OP_BRANCH_CF && t == T_CLEAR)) {
      opd->op = OP_BRANCH;
      opd->cycles = (op_flags[i + 1] & OF_DELAY_OP) ? 2 : 3;
    } else if ((opd->op == OP_BRANCH_CT && t == T_CLEAR) ||
               (opd->op == OP_BRANCH_CF && t == T_SET))
      opd->op = OP_BRANCH_N;
    else if (OP_ISBRACND(opd->op))
      t = (opd->op == OP_BRANCH_CF ? T_SET : T_CLEAR);
    else if (opd->op == OP_SETCLRT)
      t = (opd->imm ? T_SET : T_CLEAR);
    else if (opd->dest & BITMASK1(SHR_T))
      t = T_UNKNOWN;

    // "overscan" detection: unreachable code after unconditional branch
    // this can happen if the insn after a forward branch isn't a local target
    if (OP_ISBRAUC(opd->op)) {
      if (op_flags[i + 1] & OF_DELAY_OP) {
        if (i_end > i + 2 && !(op_flags[i + 2] & OF_BTARGET))
          i_end = i + 2;
      } else {
        if (i_end > i + 1 && !(op_flags[i + 1] & OF_BTARGET))
          i_end = i + 1;
      }
    }

    // divide operation verification:
    // 1. there must not be a branch target inside
    // 2. nothing is in a delay slot (could only be DIV0)
    // 2. DIV0/n*(ROTCL+DIV1)/ROTCL:
    //     div.div1 > 0 && div.rotcl == div.div1+1 && div.rn =! div.ro
    // 3. DIV0/n*DIV1/ROTCL:
    //     div.div1 > 0 && div.rotcl == 1 && div.ro == div.rn
    if (i_div >= 0) {
      if (op_flags[i] & OF_BTARGET) {   // condition 1
        ops[i_div].imm = 0;
        i_div = -1;
      } else if (--is_divop == 0)
        i_div = -1;
    } else if (opd->op == OP_DIV0) {
      struct div *div = &div(opd);
      is_divop = div->div1 + div->rotcl;
      if (op_flags[i] & OF_DELAY_OP)    // condition 2
        opd->imm = 0;
      else if (! div->div1 || ! ((div->ro == div->rn && div->rotcl == 1) ||
               (div->ro != div->rn && div->rotcl == div->div1+1)))
        opd->imm = 0;                   // condition 3+4
      else if (is_divop)
        i_div = i;
    }

    // literal pool size detection
    if (opd->op == OP_MOVA && opd->imm >= base_pc)
      if (lowest_mova == 0 || opd->imm < lowest_mova)
        lowest_mova = opd->imm;
    if (opd->op == OP_LOAD_POOL) {
      if (opd->imm >= base_pc && opd->imm < end_pc + MAX_LITERAL_OFFSET) {
        if (end_literals < opd->imm + opd->size * 2)
          end_literals = opd->imm + opd->size * 2;
        if (lowest_literal == 0 || lowest_literal > opd->imm)
          lowest_literal = opd->imm;
        if (opd->size == 2) {
          // tweak for NFL: treat a 32bit literal as an address and check if it
          // points to the literal space. In that case handle it like MOVA. 
          tmp = FETCH32(opd->imm) & ~0x20000000; // MUST ignore wt bit here
          if (tmp >= end_pc && tmp < end_pc + MAX_LITERAL_OFFSET)
            if (lowest_mova == 0 || tmp < lowest_mova)
              lowest_mova = tmp;
        }
      }
    }
#if LOOP_DETECTION
    // inner loop detection
    // 1. a loop always starts with a branch target (for the backwards jump)
    // 2. it doesn't contain more than one polling and/or delaying insn
    // 3. it doesn't contain unconditional jumps
    // 4. no overlapping of loops
    if (op_flags[i] & OF_BTARGET) {
      last_btarget = i;         // possible loop starting point
      op = 0;
    }
    // XXX let's hope nobody is putting a delay or poll insn in a delay slot :-/
    if (OP_ISBRAIMM(opd->op)) {
      // BSR, BRA, BT, BF with immediate target
      int i_tmp = (opd->imm - base_pc) / 2; // branch target, index in ops
      if (i_tmp == last_btarget) // candidate for basic loop optimizer
        op_flags[i_tmp] |= OF_BASIC_LOOP;
      if (i_tmp == last_btarget && op <= 1) {
        op_flags[i_tmp] |= OF_LOOP; // conditions met -> mark loop
        last_btarget = i+1;     // condition 4
      } else if (opd->op == OP_BRANCH)
        last_btarget = i+1;     // condition 3
    }
    else if (OP_ISBRAIND(opd->op))
      // BRAF, BSRF, JMP, JSR, register indirect. treat it as off-limits jump
      last_btarget = i+1;       // condition 3
    else if (op_flags[i] & (OF_POLL_INSN|OF_DELAY_INSN))
      op ++;                    // condition 2 
#endif
  }
  end_pc = pc;

  // end_literals is used to decide to inline a literal or not
  // XXX: need better detection if this actually is used in write
  if (lowest_literal >= base_pc) {
    if (lowest_literal < end_pc) {
      dbg(1, "warning: lowest_literal=%08x < end_pc=%08x", lowest_literal, end_pc);
      // TODO: does this always mean end_pc covers data?
    }
  }
  if (lowest_mova >= base_pc) {
    if (lowest_mova < end_literals) {
      dbg(1, "warning: mova=%08x < end_literals=%08x", lowest_mova, end_literals);
      end_literals = lowest_mova;
    }
    if (lowest_mova < end_pc) {
      dbg(1, "warning: mova=%08x < end_pc=%08x", lowest_mova, end_pc);
      end_literals = end_pc;
    }
  }
  if (lowest_literal >= end_literals)
    lowest_literal = end_literals;

  if (lowest_literal && end_literals)
    for (pc = lowest_literal; pc < end_literals; pc += 2)
      crc += FETCH_OP(pc);

  *end_pc_out = end_pc;
  if (base_literals_out != NULL)
    *base_literals_out = (lowest_literal ? lowest_literal : end_pc);
  if (end_literals_out != NULL)
    *end_literals_out = (end_literals ? end_literals : end_pc);

  // crc overflow handling, twice to collect all overflows
  crc = (crc & 0xffff) + (crc >> 16);
  crc = (crc & 0xffff) + (crc >> 16);
  return crc;
}

// vim:shiftwidth=2:ts=2:expandtab
