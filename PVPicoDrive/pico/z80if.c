/*
 * PicoDrive
 * (C) notaz, 2007-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stddef.h>
#include "pico_int.h"
#include "memory.h"

uptr z80_read_map [0x10000 >> Z80_MEM_SHIFT];
uptr z80_write_map[0x10000 >> Z80_MEM_SHIFT];

#ifdef _USE_DRZ80
struct DrZ80 drZ80;

static u32 drz80_sp_base;

static void drz80_load_pcsp(u32 pc, u32 sp)
{
  drZ80.Z80PC_BASE = z80_read_map[pc >> Z80_MEM_SHIFT];
  if (drZ80.Z80PC_BASE & (1<<31)) {
    elprintf(EL_STATUS|EL_ANOMALY, "load_pcsp: bad PC: %04x", pc);
    drZ80.Z80PC_BASE = drZ80.Z80PC = z80_read_map[0];
  } else {
    drZ80.Z80PC_BASE <<= 1;
    drZ80.Z80PC = drZ80.Z80PC_BASE + pc;
  }
  drZ80.Z80SP_BASE = z80_read_map[sp >> Z80_MEM_SHIFT];
  if (drZ80.Z80SP_BASE & (1<<31)) {
    elprintf(EL_STATUS|EL_ANOMALY, "load_pcsp: bad SP: %04x", sp);
    drZ80.Z80SP_BASE = z80_read_map[0];
    drZ80.Z80SP = drZ80.Z80SP_BASE + (1 << Z80_MEM_SHIFT);
  } else {
    drZ80.Z80SP_BASE <<= 1;
    drZ80.Z80SP = drZ80.Z80SP_BASE + sp;
  }
}

// called only if internal xmap rebase fails
static unsigned int dz80_rebase_pc(unsigned short pc)
{
  elprintf(EL_STATUS|EL_ANOMALY, "dz80_rebase_pc: fail on %04x", pc);
  drZ80.Z80PC_BASE = z80_read_map[0] << 1;
  return drZ80.Z80PC_BASE;
}

static unsigned int dz80_rebase_sp(unsigned short sp)
{
  elprintf(EL_STATUS|EL_ANOMALY, "dz80_rebase_sp: fail on %04x", sp);
  drZ80.Z80SP_BASE = z80_read_map[drz80_sp_base >> Z80_MEM_SHIFT] << 1;
  return drZ80.Z80SP_BASE + (1 << Z80_MEM_SHIFT) - 0x100;
}
#endif


void z80_init(void)
{
#ifdef _USE_DRZ80
  memset(&drZ80, 0, sizeof(drZ80));
  drZ80.z80_rebasePC = dz80_rebase_pc;
  drZ80.z80_rebaseSP = dz80_rebase_sp;
  drZ80.z80_read8    = (void *)z80_read_map;
  drZ80.z80_read16   = NULL;
  drZ80.z80_write8   = (void *)z80_write_map;
  drZ80.z80_write16  = NULL;
  drZ80.z80_irq_callback = NULL;
#endif
#ifdef _USE_CZ80
  memset(&CZ80, 0, sizeof(CZ80));
  Cz80_Init(&CZ80);
  Cz80_Set_ReadB(&CZ80, NULL); // unused (hacked in)
  Cz80_Set_WriteB(&CZ80, NULL);
#endif
}

void z80_reset(void)
{
#ifdef _USE_DRZ80
  drZ80.Z80I = 0;
  drZ80.Z80IM = 0;
  drZ80.Z80IF = 0;
  drZ80.z80irqvector = 0xff0000; // RST 38h
  drZ80.Z80PC_BASE = drZ80.Z80PC = z80_read_map[0] << 1;
  // others not changed, undefined on cold boot
/*
  drZ80.Z80F  = (1<<2);  // set ZFlag
  drZ80.Z80F2 = (1<<2);  // set ZFlag
  drZ80.Z80IX = 0xFFFF << 16;
  drZ80.Z80IY = 0xFFFF << 16;
*/
  // drZ80 is locked in single bank
  drz80_sp_base = (PicoAHW & PAHW_SMS) ? 0xc000 : 0x0000;
  drZ80.Z80SP_BASE = z80_read_map[drz80_sp_base >> Z80_MEM_SHIFT] << 1;
  if (PicoAHW & PAHW_SMS)
    drZ80.Z80SP = drZ80.Z80SP_BASE + 0xdff0; // simulate BIOS
  // XXX: since we use direct SP pointer, it might make sense to force it to RAM,
  // but we'll rely on built-in stack protection for now
#endif
#ifdef _USE_CZ80
  Cz80_Reset(&CZ80);
  if (PicoAHW & PAHW_SMS)
    Cz80_Set_Reg(&CZ80, CZ80_SP, 0xdff0);
#endif
}

/* save state stuff */
static int z80_unpack_legacy(const void *data)
{
#if defined(_USE_DRZ80)
  if (*(int *)data == 0x015A7244) { // "DrZ" v1 save?
    u32 pc, sp;
    memcpy(&drZ80, data+4, 0x54);
    pc = (drZ80.Z80PC - drZ80.Z80PC_BASE) & 0xffff;
    sp = (drZ80.Z80SP - drZ80.Z80SP_BASE) & 0xffff;
    // update bases
    drz80_load_pcsp(pc, sp);
    return 0;
  }
#elif defined(_USE_CZ80)
  if (*(int *)data == 0x00007a43) { // "Cz" save?
    memcpy(&CZ80, data+8, offsetof(cz80_struc, BasePC));
    Cz80_Set_Reg(&CZ80, CZ80_PC, *(int *)(data+4));
    return 0;
  }
#endif
  return -1;
}

struct z80sr_main {
  u8 a, f;
  u8 b, c;
  u8 d, e;
  u8 h, l;
};

struct z80_state {
  char magic[4];
  // regs
  struct z80sr_main m; // main regs
  struct z80sr_main a; // alt (') regs
  u8  i, r;
  u16 ix, iy;
  u16 sp;
  u16 pc;
  // other
  u8 halted;
  u8 iff1, iff2;
  u8 im;            // irq mode
  u8 irq_pending;   // irq line level, 1 if active
  u8 irq_vector[3]; // up to 3 byte vector for irq mode0 handling
  u8 reserved[8];
};

void z80_pack(void *data)
{
  struct z80_state *s = data;
  memset(data, 0, Z80_STATE_SIZE);
  strcpy(s->magic, "Z80");
#if defined(_USE_DRZ80)
  #define DRR8(n)   (drZ80.Z80##n >> 24)
  #define DRR16(n)  (drZ80.Z80##n >> 16)
  #define DRR16H(n) (drZ80.Z80##n >> 24)
  #define DRR16L(n) ((drZ80.Z80##n >> 16) & 0xff)
  s->m.a = DRR8(A);     s->m.f = drZ80.Z80F;
  s->m.b = DRR16H(BC);  s->m.c = DRR16L(BC);
  s->m.d = DRR16H(DE);  s->m.e = DRR16L(DE);
  s->m.h = DRR16H(HL);  s->m.l = DRR16L(HL);
  s->a.a = DRR8(A2);    s->a.f = drZ80.Z80F2;
  s->a.b = DRR16H(BC2); s->a.c = DRR16L(BC2);
  s->a.d = DRR16H(DE2); s->a.e = DRR16L(DE2);
  s->a.h = DRR16H(HL2); s->a.l = DRR16L(HL2);
  s->i = DRR8(I);       s->r = drZ80.spare;
  s->ix = DRR16(IX);    s->iy = DRR16(IY);
  s->sp = drZ80.Z80SP - drZ80.Z80SP_BASE;
  s->pc = drZ80.Z80PC - drZ80.Z80PC_BASE;
  s->halted = !!(drZ80.Z80IF & 4);
  s->iff1 = !!(drZ80.Z80IF & 1);
  s->iff2 = !!(drZ80.Z80IF & 2);
  s->im = drZ80.Z80IM;
  s->irq_pending = !!drZ80.Z80_IRQ;
  s->irq_vector[0] = drZ80.z80irqvector >> 16;
  s->irq_vector[1] = drZ80.z80irqvector >> 8;
  s->irq_vector[2] = drZ80.z80irqvector;
#elif defined(_USE_CZ80)
  {
    const cz80_struc *CPU = &CZ80;
    s->m.a = zA;  s->m.f = zF;
    s->m.b = zB;  s->m.c = zC;
    s->m.d = zD;  s->m.e = zE;
    s->m.h = zH;  s->m.l = zL;
    s->a.a = zA2; s->a.f = zF2;
    s->a.b = CZ80.BC2.B.H; s->a.c = CZ80.BC2.B.L;
    s->a.d = CZ80.DE2.B.H; s->a.e = CZ80.DE2.B.L;
    s->a.h = CZ80.HL2.B.H; s->a.l = CZ80.HL2.B.L;
    s->i  = zI;   s->r  = zR;
    s->ix = zIX;  s->iy = zIY;
    s->sp = Cz80_Get_Reg(&CZ80, CZ80_SP);
    s->pc = Cz80_Get_Reg(&CZ80, CZ80_PC);
    s->halted = !!Cz80_Get_Reg(&CZ80, CZ80_HALT);
    s->iff1 = !!zIFF1;
    s->iff2 = !!zIFF2;
    s->im = zIM;
    s->irq_pending = (Cz80_Get_Reg(&CZ80, CZ80_IRQ) == HOLD_LINE);
    s->irq_vector[0] = 0xff;
  }
#endif
}

int z80_unpack(const void *data)
{
  const struct z80_state *s = data;
  if (strcmp(s->magic, "Z80") != 0) {
    if (z80_unpack_legacy(data) != 0)
      goto fail;
    elprintf(EL_STATUS, "legacy z80 state");
    return 0;
  }

#if defined(_USE_DRZ80)
  #define DRW8(n, v)       drZ80.Z80##n = (u32)(v) << 24
  #define DRW16(n, v)      drZ80.Z80##n = (u32)(v) << 16
  #define DRW16HL(n, h, l) drZ80.Z80##n = ((u32)(h) << 24) | ((u32)(l) << 16)
  DRW8(A, s->m.a);  drZ80.Z80F = s->m.f;
  DRW16HL(BC, s->m.b, s->m.c);
  DRW16HL(DE, s->m.d, s->m.e);
  DRW16HL(HL, s->m.h, s->m.l);
  DRW8(A2, s->a.a); drZ80.Z80F2 = s->a.f;
  DRW16HL(BC2, s->a.b, s->a.c);
  DRW16HL(DE2, s->a.d, s->a.e);
  DRW16HL(HL2, s->a.h, s->a.l);
  DRW8(I, s->i);    drZ80.spare = s->r;
  DRW16(IX, s->ix); DRW16(IY, s->iy);
  drz80_load_pcsp(s->pc, s->sp);
  drZ80.Z80IF = 0;
  if (s->halted) drZ80.Z80IF |= 4;
  if (s->iff1)   drZ80.Z80IF |= 1;
  if (s->iff2)   drZ80.Z80IF |= 2;
  drZ80.Z80IM = s->im;
  drZ80.Z80_IRQ = s->irq_pending;
  drZ80.z80irqvector = ((u32)s->irq_vector[0] << 16) |
    ((u32)s->irq_vector[1] << 8) | s->irq_vector[2];
  return 0;
#elif defined(_USE_CZ80)
  {
    cz80_struc *CPU = &CZ80;
    zA  = s->m.a; zF  = s->m.f;
    zB  = s->m.b; zC  = s->m.c;
    zD  = s->m.d; zE  = s->m.e;
    zH  = s->m.h; zL  = s->m.l;
    zA2 = s->a.a; zF2 = s->a.f;
    CZ80.BC2.B.H = s->a.b; CZ80.BC2.B.L = s->a.c;
    CZ80.DE2.B.H = s->a.d; CZ80.DE2.B.L = s->a.e;
    CZ80.HL2.B.H = s->a.h; CZ80.HL2.B.L = s->a.l;
    zI  = s->i;   zR  = s->r;
    zIX = s->ix;  zIY = s->iy;
    Cz80_Set_Reg(&CZ80, CZ80_SP, s->sp);
    Cz80_Set_Reg(&CZ80, CZ80_PC, s->pc);
    Cz80_Set_Reg(&CZ80, CZ80_HALT, s->halted);
    Cz80_Set_Reg(&CZ80, CZ80_IFF1, s->iff1);
    Cz80_Set_Reg(&CZ80, CZ80_IFF2, s->iff2);
    zIM = s->im;
    Cz80_Set_Reg(&CZ80, CZ80_IRQ, s->irq_pending ? HOLD_LINE : CLEAR_LINE);
    return 0;
  }
#endif

fail:
  elprintf(EL_STATUS|EL_ANOMALY, "z80_unpack failed");
  z80_reset();
  z80_int();
  return -1;
}

void z80_exit(void)
{
}

void z80_debug(char *dstr)
{
#if defined(_USE_DRZ80)
  sprintf(dstr, "Z80 state: PC: %04x SP: %04x\n", drZ80.Z80PC-drZ80.Z80PC_BASE, drZ80.Z80SP-drZ80.Z80SP_BASE);
#elif defined(_USE_CZ80)
  sprintf(dstr, "Z80 state: PC: %04x SP: %04x\n", (unsigned int)(CZ80.PC - CZ80.BasePC), CZ80.SP.W);
#endif
}
