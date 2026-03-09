// gcc drctest.c cpu/drc/cmn.c cpu/sh2/mame/sh2dasm.c platform/libpicofe/linux/host_dasm.c platform/libpicofe/linux/plat.c -I. -DDRC_SH2 -g -O -o drctest -lbfd-<ver>-multiarch -lopcodes-<ver>-multiarch -liberty -D<__platform__>

#include <stdarg.h>
#include <stdio.h>

#include <cpu/sh2/compiler.c>

struct Pico Pico;
SH2 sh2s[2];
struct Pico32xMem _Pico32xMem, *Pico32xMem = &_Pico32xMem;
struct Pico32x Pico32x;
char **g_argv;

void memset32(void *dest_in, int c, int count) { memset(dest_in, c, 4*count); } 

void cache_flush_d_inval_i(void *start_addr, void *end_addr) { }
void *plat_mem_get_for_drc(size_t size) { return NULL; }
void *p32x_sh2_get_mem_ptr(u32 a, u32 *mask, SH2 *sh2) { return NULL; }

void REGPARM(3) p32x_sh2_write8 (u32 a, u32 d, SH2 *s) { }
void REGPARM(3) p32x_sh2_write16(u32 a, u32 d, SH2 *s) { }
void REGPARM(3) p32x_sh2_write32(u32 a, u32 d, SH2 *s) { }

u32 REGPARM(2) p32x_sh2_read8 (u32 a, SH2 *s) { }
u32 REGPARM(2) p32x_sh2_read16(u32 a, SH2 *s) { }
u32 REGPARM(2) p32x_sh2_read32(u32 a, SH2 *s) { }

u32 REGPARM(3) p32x_sh2_poll_memory8 (u32 a, u32 d, SH2 *s) { }
u32 REGPARM(3) p32x_sh2_poll_memory16(u32 a, u32 d, SH2 *s) { }
u32 REGPARM(3) p32x_sh2_poll_memory32(u32 a, u32 d, SH2 *s) { }

int main(int argc, char *argv[])
{
  FILE *f;
  u32 (*testfunc)(u32), ret;
  int arg0, arg1, arg2, arg3, sr;
  host_arg2reg(arg0, 0);
  host_arg2reg(arg1, 1);
  host_arg2reg(arg2, 2);
  host_arg2reg(arg3, 3);

  g_argv = argv;
  sh2_drc_init(sh2s);
  f = fopen("utils.bin", "w");
  fwrite(tcache, 1, 4096, f);
  fclose(f);

  tcache_ptr = tcache_ring[0].base;
  u8 *p1 = tcache_ptr;
  emith_jump_patchable(0);
  u8 *p2 = tcache_ptr;
  emith_jump_cond_patchable(DCOND_GE, 0);
  emith_move_r_r(0, 1);
  emith_move_r_r(0, 2);
  u8 *p3 = tcache_ptr;
  emith_move_r_r(0, 3);
  emith_move_r_r(0, 4);
  emith_move_r_r(0, 5);

  u8 *p4 = tcache_ptr;
  emith_move_r_imm_s8_patchable(arg0, 0);
  emith_move_r_r(0, 6);
  emith_flush();

  emith_jump_patch(p1, tcache_ptr, NULL);
  emith_jump_patch(p2, tcache_ptr, NULL);
  emith_jump_at(p3, tcache_ptr);

  emith_move_r_imm_s8_patch(p4, 42);

  emith_read8_r_r_offs(arg0, arg1, 100);
  emith_read8_r_r_offs(arg0, arg1, 1000);
  emith_read8_r_r_offs(arg0, arg1, 10000);
  emith_read8_r_r_offs(arg0, arg1, -100);
  emith_read8_r_r_offs(arg0, arg1, -1000);
  emith_read8_r_r_offs(arg0, arg1, -10000);

  emith_read16_r_r_offs(arg0, arg1, 4);
  emith_read_r_r_offs(arg0, arg1, 4);
  emith_read8s_r_r_offs(arg0, arg1, 4);
  emith_read16s_r_r_offs(arg0, arg1, 4);

  emith_write_r_r_offs(arg0, arg1, 4);

  emith_add_r_r_r_lsl(arg0, arg1, arg2, 2);
  emith_move_r_r(0, 0);

  emith_mula_s64(arg0, arg1, arg2, arg3);
  emith_move_r_r(0, 0);

  emith_clear_msb(arg0, arg1, 8);
  emith_clear_msb(arg0, arg1, 16);
  emith_clear_msb(arg0, arg1, 24);

  emith_sext(arg0, arg1, 8);
  emith_sext(arg0, arg1, 16);
  emith_sext(arg0, arg1, 24);
  emith_move_r_r(0, 0);

  emith_lsl(arg0, arg1, 24);
  emith_lsr(arg0, arg1, 24);
  emith_asr(arg0, arg1, 24);
  emith_rol(arg0, arg1, 24);
  emith_move_r_r(0, 0);

  emith_lslf(arg0, arg1, 24);
  emith_lsrf(arg0, arg1, 24);
  emith_asrf(arg0, arg1, 24);
  emith_rolf(arg0, arg1, 24);
  emith_rorf(arg0, arg1, 24);
  emith_move_r_r(0, 0);
  emith_rolcf(arg0);
  emith_rorcf(arg0);

  emith_negcf_r_r(arg0, arg1);
  emith_move_r_r(0, 0);

  emith_eor_r_r_imm(arg0, arg1, 100);
  emith_eor_r_r_imm(arg0, arg1, 10000);
  emith_eor_r_r_imm(arg0, arg1, -100);
  emith_eor_r_r_imm(arg0, arg1, -10000);
  emith_move_r_r(0, 0);

  emith_move_r_imm(arg0, 100);
  emith_move_r_imm(arg0, 1000);
  emith_move_r_imm(arg0, 10000);
  emith_move_r_imm(arg0, -100);
  emith_move_r_imm(arg0, -1000);
  emith_move_r_imm(arg0, -10000);
  emith_move_r_r(0, 0);

  emith_move_r_ptr_imm(arg0, 0x1234567887654321ULL);
  emith_move_r_ptr_imm(arg1, 0x8765432112345678ULL);
  emith_move_r_ptr_imm(arg2, 0x0011223344556677ULL);
  emith_move_r_ptr_imm(arg3, 0x7766554433221100ULL);
  emith_move_r_r(0, 0);

  emith_tpop_carry(29, 0);
  emith_tpush_carry(29, 0);
  emith_move_r_r(0, 0);

  emith_carry_to_t(29, 0);
  emith_t_to_carry(29, 0);
  emith_move_r_r(0, 0);

  emith_write_sr(29, arg0);
  emith_move_r_r(0, 0);

  emith_sh2_delay_loop(11, arg0);
  emith_move_r_r(0, 0);
  emith_sh2_delay_loop(11, -1);
  emith_move_r_r(0, 0);

  emith_sh2_div1_step(arg0, arg1, 29);
  emith_move_r_r(0, 0);

  emith_sh2_macl(arg0, arg1, arg2, arg3, 29);
  emith_move_r_r(0, 0);
  emith_sh2_macw(arg0, arg1, arg2, arg3, 29);
  emith_move_r_r(0, 0);

  emith_flush();
  emith_pool_commit(1);

  emith_ret();

  f = fopen("test.bin", "w");
  fwrite(tcache_ring[0].base, 1, tcache_ptr - tcache_ring[0].base, f);
  fclose(f);

  do_host_disasm(0);

#if  0
  testfunc = (void *)tcache_next[0];
  tcache_ptr = tcache_next[0];
  emith_move_r_r(RET_REG, arg0);
  emith_ret();
  host_instructions_updated(tcache_next[0], tcache_ptr);
  ret = testfunc(0x00000001);
  printf("ret %x\n",ret);
#endif
}

