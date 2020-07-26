/*
 * memory handling
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"
#include "memory.h"

#include "sound/ym2612.h"
#include "sound/sn76496.h"

extern unsigned int lastSSRamWrite; // used by serial eeprom code

uptr m68k_read8_map  [0x1000000 >> M68K_MEM_SHIFT];
uptr m68k_read16_map [0x1000000 >> M68K_MEM_SHIFT];
uptr m68k_write8_map [0x1000000 >> M68K_MEM_SHIFT];
uptr m68k_write16_map[0x1000000 >> M68K_MEM_SHIFT];

static void xmap_set(uptr *map, int shift, int start_addr, int end_addr,
    const void *func_or_mh, int is_func)
{
#ifdef __clang__
  // workaround bug (segfault) in 
  // Apple LLVM version 4.2 (clang-425.0.27) (based on LLVM 3.2svn)
  volatile 
#endif
  uptr addr = (uptr)func_or_mh;
  int mask = (1 << shift) - 1;
  int i;

  if ((start_addr & mask) != 0 || (end_addr & mask) != mask) {
    elprintf(EL_STATUS|EL_ANOMALY, "xmap_set: tried to map bad range: %06x-%06x",
      start_addr, end_addr);
    return;
  }

  if (addr & 1) {
    elprintf(EL_STATUS|EL_ANOMALY, "xmap_set: ptr is not aligned: %08lx", addr);
    return;
  }

  if (!is_func)
    addr -= start_addr;

  for (i = start_addr >> shift; i <= end_addr >> shift; i++) {
    map[i] = addr >> 1;
    if (is_func)
      map[i] |= MAP_FLAG;
  }
}

void z80_map_set(uptr *map, int start_addr, int end_addr,
    const void *func_or_mh, int is_func)
{
  xmap_set(map, Z80_MEM_SHIFT, start_addr, end_addr, func_or_mh, is_func);
}

void cpu68k_map_set(uptr *map, int start_addr, int end_addr,
    const void *func_or_mh, int is_func)
{
  xmap_set(map, M68K_MEM_SHIFT, start_addr, end_addr, func_or_mh, is_func);
}

// more specialized/optimized function (does same as above)
void cpu68k_map_all_ram(int start_addr, int end_addr, void *ptr, int is_sub)
{
  uptr *r8map, *r16map, *w8map, *w16map;
  uptr addr = (uptr)ptr;
  int shift = M68K_MEM_SHIFT;
  int i;

  if (!is_sub) {
    r8map = m68k_read8_map;
    r16map = m68k_read16_map;
    w8map = m68k_write8_map;
    w16map = m68k_write16_map;
  } else {
    r8map = s68k_read8_map;
    r16map = s68k_read16_map;
    w8map = s68k_write8_map;
    w16map = s68k_write16_map;
  }

  addr -= start_addr;
  addr >>= 1;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    r8map[i] = r16map[i] = w8map[i] = w16map[i] = addr;
}

static u32 m68k_unmapped_read8(u32 a)
{
  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return 0; // assume pulldown, as if MegaCD2 was attached
}

static u32 m68k_unmapped_read16(u32 a)
{
  elprintf(EL_UIO, "m68k unmapped r16 [%06x] @%06x", a, SekPc);
  return 0;
}

static void m68k_unmapped_write8(u32 a, u32 d)
{
  elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
}

static void m68k_unmapped_write16(u32 a, u32 d)
{
  elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
}

void m68k_map_unmap(int start_addr, int end_addr)
{
#ifdef __clang__
  // workaround bug (segfault) in 
  // Apple LLVM version 4.2 (clang-425.0.27) (based on LLVM 3.2svn)
  volatile 
#endif
  uptr addr;
  int shift = M68K_MEM_SHIFT;
  int i;

  addr = (uptr)m68k_unmapped_read8;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    m68k_read8_map[i] = (addr >> 1) | MAP_FLAG;

  addr = (uptr)m68k_unmapped_read16;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    m68k_read16_map[i] = (addr >> 1) | MAP_FLAG;

  addr = (uptr)m68k_unmapped_write8;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    m68k_write8_map[i] = (addr >> 1) | MAP_FLAG;

  addr = (uptr)m68k_unmapped_write16;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    m68k_write16_map[i] = (addr >> 1) | MAP_FLAG;
}

MAKE_68K_READ8(m68k_read8, m68k_read8_map)
MAKE_68K_READ16(m68k_read16, m68k_read16_map)
MAKE_68K_READ32(m68k_read32, m68k_read16_map)
MAKE_68K_WRITE8(m68k_write8, m68k_write8_map)
MAKE_68K_WRITE16(m68k_write16, m68k_write16_map)
MAKE_68K_WRITE32(m68k_write32, m68k_write16_map)

// -----------------------------------------------------------------

static u32 ym2612_read_local_68k(void);
static int ym2612_write_local(u32 a, u32 d, int is_from_z80);
static void z80_mem_setup(void);

#ifdef _ASM_MEMORY_C
u32 PicoRead8_sram(u32 a);
u32 PicoRead16_sram(u32 a);
#endif

#ifdef EMU_CORE_DEBUG
u32 lastread_a, lastread_d[16]={0,}, lastwrite_cyc_d[16]={0,}, lastwrite_mus_d[16]={0,};
int lrp_cyc=0, lrp_mus=0, lwp_cyc=0, lwp_mus=0;
extern unsigned int ppop;
#endif

#ifdef IO_STATS
void log_io(unsigned int addr, int bits, int rw);
#elif defined(_MSC_VER)
#define log_io
#else
#define log_io(...)
#endif

#if defined(EMU_C68K)
void cyclone_crashed(u32 pc, struct Cyclone *context)
{
    elprintf(EL_STATUS|EL_ANOMALY, "%c68k crash detected @ %06x",
      context == &PicoCpuCM68k ? 'm' : 's', pc);
    context->membase = (u32)Pico.rom;
    context->pc = (u32)Pico.rom + Pico.romsize;
}
#endif

// -----------------------------------------------------------------
// memmap helpers

static u32 read_pad_3btn(int i, u32 out_bits)
{
  u32 pad = ~PicoPadInt[i]; // Get inverse of pad MXYZ SACB RLDU
  u32 value;

  if (out_bits & 0x40) // TH
    value = pad & 0x3f;                      // ?1CB RLDU
  else
    value = ((pad & 0xc0) >> 2) | (pad & 3); // ?0SA 00DU

  value |= out_bits & 0x40;
  return value;
}

static u32 read_pad_6btn(int i, u32 out_bits)
{
  u32 pad = ~PicoPadInt[i]; // Get inverse of pad MXYZ SACB RLDU
  int phase = Pico.m.padTHPhase[i];
  u32 value;

  if (phase == 2 && !(out_bits & 0x40)) {
    value = (pad & 0xc0) >> 2;                   // ?0SA 0000
    goto out;
  }
  else if(phase == 3) {
    if (out_bits & 0x40)
      return (pad & 0x30) | ((pad >> 8) & 0xf);  // ?1CB MXYZ
    else
      return ((pad & 0xc0) >> 2) | 0x0f;         // ?0SA 1111
    goto out;
  }

  if (out_bits & 0x40) // TH
    value = pad & 0x3f;                          // ?1CB RLDU
  else
    value = ((pad & 0xc0) >> 2) | (pad & 3);     // ?0SA 00DU

out:
  value |= out_bits & 0x40;
  return value;
}

static u32 read_nothing(int i, u32 out_bits)
{
  return 0xff;
}

typedef u32 (port_read_func)(int index, u32 out_bits);

static port_read_func *port_readers[3] = {
  read_pad_3btn,
  read_pad_3btn,
  read_nothing
};

static NOINLINE u32 port_read(int i)
{
  u32 data_reg = Pico.ioports[i + 1];
  u32 ctrl_reg = Pico.ioports[i + 4] | 0x80;
  u32 in, out;

  out = data_reg & ctrl_reg;
  out |= 0x7f & ~ctrl_reg; // pull-ups

  in = port_readers[i](i, out);

  return (in & ~ctrl_reg) | (data_reg & ctrl_reg);
}

void PicoSetInputDevice(int port, enum input_device device)
{
  port_read_func *func;

  if (port < 0 || port > 2)
    return;

  switch (device) {
  case PICO_INPUT_PAD_3BTN:
    func = read_pad_3btn;
    break;

  case PICO_INPUT_PAD_6BTN:
    func = read_pad_6btn;
    break;

  default:
    func = read_nothing;
    break;
  }

  port_readers[port] = func;
}

NOINLINE u32 io_ports_read(u32 a)
{
  u32 d;
  a = (a>>1) & 0xf;
  switch (a) {
    case 0:  d = Pico.m.hardware; break; // Hardware value (Version register)
    case 1:  d = port_read(0); break;
    case 2:  d = port_read(1); break;
    case 3:  d = port_read(2); break;
    default: d = Pico.ioports[a]; break; // IO ports can be used as RAM
  }
  return d;
}

NOINLINE void io_ports_write(u32 a, u32 d)
{
  a = (a>>1) & 0xf;

  // 6 button gamepad: if TH went from 0 to 1, gamepad changes state
  if (1 <= a && a <= 2)
  {
    Pico.m.padDelay[a - 1] = 0;
    if (!(Pico.ioports[a] & 0x40) && (d & 0x40))
      Pico.m.padTHPhase[a - 1]++;
  }

  // certain IO ports can be used as RAM
  Pico.ioports[a] = d;
}

// lame..
static int z80_cycles_from_68k(void)
{
  return z80_cycle_aim
    + cycles_68k_to_z80(SekCyclesDone() - last_z80_sync);
}

void NOINLINE ctl_write_z80busreq(u32 d)
{
  d&=1; d^=1;
  elprintf(EL_BUSREQ, "set_zrun: %i->%i [%i] @%06x", Pico.m.z80Run, d, SekCyclesDone(), SekPc);
  if (d ^ Pico.m.z80Run)
  {
    if (d)
    {
      z80_cycle_cnt = z80_cycles_from_68k();
    }
    else
    {
      if ((PicoOpt&POPT_EN_Z80) && !Pico.m.z80_reset) {
        pprof_start(m68k);
        PicoSyncZ80(SekCyclesDone());
        pprof_end_sub(m68k);
      }
    }
    Pico.m.z80Run = d;
  }
}

void NOINLINE ctl_write_z80reset(u32 d)
{
  d&=1; d^=1;
  elprintf(EL_BUSREQ, "set_zreset: %i->%i [%i] @%06x", Pico.m.z80_reset, d, SekCyclesDone(), SekPc);
  if (d ^ Pico.m.z80_reset)
  {
    if (d)
    {
      if ((PicoOpt&POPT_EN_Z80) && Pico.m.z80Run) {
        pprof_start(m68k);
        PicoSyncZ80(SekCyclesDone());
        pprof_end_sub(m68k);
      }
      YM2612ResetChip();
      timers_reset();
    }
    else
    {
      z80_cycle_cnt = z80_cycles_from_68k();
      z80_reset();
    }
    Pico.m.z80_reset = d;
  }
}

// -----------------------------------------------------------------

#ifndef _ASM_MEMORY_C

// cart (save) RAM area (usually 0x200000 - ...)
static u32 PicoRead8_sram(u32 a)
{
  u32 d;
  if (SRam.start <= a && a <= SRam.end && (Pico.m.sram_reg & SRR_MAPPED))
  {
    if (SRam.flags & SRF_EEPROM) {
      d = EEPROM_read();
      if (!(a & 1))
        d >>= 8;
    } else
      d = *(u8 *)(SRam.data - SRam.start + a);
    elprintf(EL_SRAMIO, "sram r8  [%06x]   %02x @ %06x", a, d, SekPc);
    return d;
  }

  // XXX: this is banking unfriendly
  if (a < Pico.romsize)
    return Pico.rom[a ^ 1];
  
  return m68k_unmapped_read8(a);
}

static u32 PicoRead16_sram(u32 a)
{
  u32 d;
  if (SRam.start <= a && a <= SRam.end && (Pico.m.sram_reg & SRR_MAPPED))
  {
    if (SRam.flags & SRF_EEPROM)
      d = EEPROM_read();
    else {
      u8 *pm = (u8 *)(SRam.data - SRam.start + a);
      d  = pm[0] << 8;
      d |= pm[1];
    }
    elprintf(EL_SRAMIO, "sram r16 [%06x] %04x @ %06x", a, d, SekPc);
    return d;
  }

  if (a < Pico.romsize)
    return *(u16 *)(Pico.rom + a);

  return m68k_unmapped_read16(a);
}

#endif // _ASM_MEMORY_C

static void PicoWrite8_sram(u32 a, u32 d)
{
  if (a > SRam.end || a < SRam.start || !(Pico.m.sram_reg & SRR_MAPPED)) {
    m68k_unmapped_write8(a, d);
    return;
  }

  elprintf(EL_SRAMIO, "sram w8  [%06x]   %02x @ %06x", a, d & 0xff, SekPc);
  if (SRam.flags & SRF_EEPROM)
  {
    EEPROM_write8(a, d);
  }
  else {
    u8 *pm = (u8 *)(SRam.data - SRam.start + a);
    if (*pm != (u8)d) {
      SRam.changed = 1;
      *pm = (u8)d;
    }
  }
}

static void PicoWrite16_sram(u32 a, u32 d)
{
  if (a > SRam.end || a < SRam.start || !(Pico.m.sram_reg & SRR_MAPPED)) {
    m68k_unmapped_write16(a, d);
    return;
  }

  elprintf(EL_SRAMIO, "sram w16 [%06x] %04x @ %06x", a, d & 0xffff, SekPc);
  if (SRam.flags & SRF_EEPROM)
  {
    EEPROM_write16(d);
  }
  else {
    // XXX: hardware could easily use MSB too..
    u8 *pm = (u8 *)(SRam.data - SRam.start + a);
    if (*pm != (u8)d) {
      SRam.changed = 1;
      *pm = (u8)d;
    }
  }
}

// z80 area (0xa00000 - 0xa0ffff)
// TODO: verify mirrors VDP and bank reg (bank area mirroring verified)
static u32 PicoRead8_z80(u32 a)
{
  u32 d = 0xff;
  if ((Pico.m.z80Run & 1) || Pico.m.z80_reset) {
    elprintf(EL_ANOMALY, "68k z80 read with no bus! [%06x] @ %06x", a, SekPc);
    // open bus. Pulled down if MegaCD2 is attached.
    return 0;
  }

  if ((a & 0x4000) == 0x0000)
    d = Pico.zram[a & 0x1fff];
  else if ((a & 0x6000) == 0x4000) // 0x4000-0x5fff
    d = ym2612_read_local_68k(); 
  else
    elprintf(EL_UIO|EL_ANOMALY, "68k bad read [%06x] @%06x", a, SekPc);
  return d;
}

static u32 PicoRead16_z80(u32 a)
{
  u32 d = PicoRead8_z80(a);
  return d | (d << 8);
}

static void PicoWrite8_z80(u32 a, u32 d)
{
  if ((Pico.m.z80Run & 1) || Pico.m.z80_reset) {
    // verified on real hw
    elprintf(EL_ANOMALY, "68k z80 write with no bus or reset! [%06x] %02x @ %06x", a, d&0xff, SekPc);
    return;
  }

  if ((a & 0x4000) == 0x0000) { // z80 RAM
    SekCyclesBurnRun(2); // FIXME hack
    Pico.zram[a & 0x1fff] = (u8)d;
    return;
  }
  if ((a & 0x6000) == 0x4000) { // FM Sound
    if (PicoOpt & POPT_EN_FM)
      emustatus |= ym2612_write_local(a&3, d&0xff, 0)&1;
    return;
  }
  // TODO: probably other VDP access too? Maybe more mirrors?
  if ((a & 0x7ff9) == 0x7f11) { // PSG Sound
    if (PicoOpt & POPT_EN_PSG)
      SN76496Write(d);
    return;
  }
  if ((a & 0x7f00) == 0x6000) // Z80 BANK register
  {
    Pico.m.z80_bank68k >>= 1;
    Pico.m.z80_bank68k |= d << 8;
    Pico.m.z80_bank68k &= 0x1ff; // 9 bits and filled in the new top one
    elprintf(EL_Z80BNK, "z80 bank=%06x", Pico.m.z80_bank68k << 15);
    return;
  }
  elprintf(EL_UIO|EL_ANOMALY, "68k bad write [%06x] %02x @ %06x", a, d&0xff, SekPc);
}

static void PicoWrite16_z80(u32 a, u32 d)
{
  // for RAM, only most significant byte is sent
  // TODO: verify remaining accesses
  PicoWrite8_z80(a, d >> 8);
}

#ifndef _ASM_MEMORY_C

// IO/control area (0xa10000 - 0xa1ffff)
u32 PicoRead8_io(u32 a)
{
  u32 d;

  if ((a & 0xffe0) == 0x0000) { // I/O ports
    d = io_ports_read(a);
    goto end;
  }

  // faking open bus (MegaCD pulldowns don't work here curiously)
  d = Pico.m.rotate++;
  d ^= d << 6;

  if ((a & 0xfc00) == 0x1000) {
    // bit8 seems to be readable in this range
    if (!(a & 1))
      d &= ~0x01;

    if ((a & 0xff01) == 0x1100) { // z80 busreq (verified)
      d |= (Pico.m.z80Run | Pico.m.z80_reset) & 1;
      elprintf(EL_BUSREQ, "get_zrun: %02x [%i] @%06x", d, SekCyclesDone(), SekPc);
    }
    goto end;
  }

  if (PicoOpt & POPT_EN_32X) {
    d = PicoRead8_32x(a);
    goto end;
  }

  d = m68k_unmapped_read8(a);
end:
  return d;
}

u32 PicoRead16_io(u32 a)
{
  u32 d;

  if ((a & 0xffe0) == 0x0000) { // I/O ports
    d = io_ports_read(a);
    d |= d << 8;
    goto end;
  }

  // faking open bus
  d = (Pico.m.rotate += 0x41);
  d ^= (d << 5) ^ (d << 8);

  // bit8 seems to be readable in this range
  if ((a & 0xfc00) == 0x1000) {
    d &= ~0x0100;

    if ((a & 0xff00) == 0x1100) { // z80 busreq
      d |= ((Pico.m.z80Run | Pico.m.z80_reset) & 1) << 8;
      elprintf(EL_BUSREQ, "get_zrun: %04x [%i] @%06x", d, SekCyclesDone(), SekPc);
    }
    goto end;
  }

  if (PicoOpt & POPT_EN_32X) {
    d = PicoRead16_32x(a);
    goto end;
  }

  d = m68k_unmapped_read16(a);
end:
  return d;
}

void PicoWrite8_io(u32 a, u32 d)
{
  if ((a & 0xffe1) == 0x0001) { // I/O ports (verified: only LSB!)
    io_ports_write(a, d);
    return;
  }
  if ((a & 0xff01) == 0x1100) { // z80 busreq
    ctl_write_z80busreq(d);
    return;
  }
  if ((a & 0xff01) == 0x1200) { // z80 reset
    ctl_write_z80reset(d);
    return;
  }
  if (a == 0xa130f1) { // sram access register
    elprintf(EL_SRAMIO, "sram reg=%02x", d);
    Pico.m.sram_reg &= ~(SRR_MAPPED|SRR_READONLY);
    Pico.m.sram_reg |= (u8)(d & 3);
    return;
  }
  if (PicoOpt & POPT_EN_32X) {
    PicoWrite8_32x(a, d);
    return;
  }

  m68k_unmapped_write8(a, d);
}

void PicoWrite16_io(u32 a, u32 d)
{
  if ((a & 0xffe0) == 0x0000) { // I/O ports (verified: only LSB!)
    io_ports_write(a, d);
    return;
  }
  if ((a & 0xff00) == 0x1100) { // z80 busreq
    ctl_write_z80busreq(d >> 8);
    return;
  }
  if ((a & 0xff00) == 0x1200) { // z80 reset
    ctl_write_z80reset(d >> 8);
    return;
  }
  if (a == 0xa130f0) { // sram access register
    elprintf(EL_SRAMIO, "sram reg=%02x", d);
    Pico.m.sram_reg &= ~(SRR_MAPPED|SRR_READONLY);
    Pico.m.sram_reg |= (u8)(d & 3);
    return;
  }
  if (PicoOpt & POPT_EN_32X) {
    PicoWrite16_32x(a, d);
    return;
  }
  m68k_unmapped_write16(a, d);
}

#endif // _ASM_MEMORY_C

// VDP area (0xc00000 - 0xdfffff)
// TODO: verify if lower byte goes to PSG on word writes
static u32 PicoRead8_vdp(u32 a)
{
  if ((a & 0x00e0) == 0x0000)
    return PicoVideoRead8(a);

  elprintf(EL_UIO|EL_ANOMALY, "68k bad read [%06x] @%06x", a, SekPc);
  return 0;
}

static u32 PicoRead16_vdp(u32 a)
{
  if ((a & 0x00e0) == 0x0000)
    return PicoVideoRead(a);

  elprintf(EL_UIO|EL_ANOMALY, "68k bad read [%06x] @%06x", a, SekPc);
  return 0;
}

static void PicoWrite8_vdp(u32 a, u32 d)
{
  if ((a & 0x00f9) == 0x0011) { // PSG Sound
    if (PicoOpt & POPT_EN_PSG)
      SN76496Write(d);
    return;
  }
  if ((a & 0x00e0) == 0x0000) {
    d &= 0xff;
    PicoVideoWrite(a, d | (d << 8));
    return;
  }

  elprintf(EL_UIO|EL_ANOMALY, "68k bad write [%06x] %02x @%06x", a, d & 0xff, SekPc);
}

static void PicoWrite16_vdp(u32 a, u32 d)
{
  if ((a & 0x00f9) == 0x0010) { // PSG Sound
    if (PicoOpt & POPT_EN_PSG)
      SN76496Write(d);
    return;
  }
  if ((a & 0x00e0) == 0x0000) {
    PicoVideoWrite(a, d);
    return;
  }

  elprintf(EL_UIO|EL_ANOMALY, "68k bad write [%06x] %04x @%06x", a, d & 0xffff, SekPc);
}

// -----------------------------------------------------------------

#ifdef EMU_M68K
static void m68k_mem_setup(void);
#endif

PICO_INTERNAL void PicoMemSetup(void)
{
  int mask, rs, a;

  // setup the memory map
  cpu68k_map_set(m68k_read8_map,   0x000000, 0xffffff, m68k_unmapped_read8, 1);
  cpu68k_map_set(m68k_read16_map,  0x000000, 0xffffff, m68k_unmapped_read16, 1);
  cpu68k_map_set(m68k_write8_map,  0x000000, 0xffffff, m68k_unmapped_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0x000000, 0xffffff, m68k_unmapped_write16, 1);

  // ROM
  // align to bank size. We know ROM loader allocated enough for this
  mask = (1 << M68K_MEM_SHIFT) - 1;
  rs = (Pico.romsize + mask) & ~mask;
  cpu68k_map_set(m68k_read8_map,  0x000000, rs - 1, Pico.rom, 0);
  cpu68k_map_set(m68k_read16_map, 0x000000, rs - 1, Pico.rom, 0);

  // Common case of on-cart (save) RAM, usually at 0x200000-...
  if ((SRam.flags & SRF_ENABLED) && SRam.data != NULL) {
    rs = SRam.end - SRam.start;
    rs = (rs + mask) & ~mask;
    if (SRam.start + rs >= 0x1000000)
      rs = 0x1000000 - SRam.start;
    cpu68k_map_set(m68k_read8_map,   SRam.start, SRam.start + rs - 1, PicoRead8_sram, 1);
    cpu68k_map_set(m68k_read16_map,  SRam.start, SRam.start + rs - 1, PicoRead16_sram, 1);
    cpu68k_map_set(m68k_write8_map,  SRam.start, SRam.start + rs - 1, PicoWrite8_sram, 1);
    cpu68k_map_set(m68k_write16_map, SRam.start, SRam.start + rs - 1, PicoWrite16_sram, 1);
  }

  // Z80 region
  cpu68k_map_set(m68k_read8_map,   0xa00000, 0xa0ffff, PicoRead8_z80, 1);
  cpu68k_map_set(m68k_read16_map,  0xa00000, 0xa0ffff, PicoRead16_z80, 1);
  cpu68k_map_set(m68k_write8_map,  0xa00000, 0xa0ffff, PicoWrite8_z80, 1);
  cpu68k_map_set(m68k_write16_map, 0xa00000, 0xa0ffff, PicoWrite16_z80, 1);

  // IO/control region
  cpu68k_map_set(m68k_read8_map,   0xa10000, 0xa1ffff, PicoRead8_io, 1);
  cpu68k_map_set(m68k_read16_map,  0xa10000, 0xa1ffff, PicoRead16_io, 1);
  cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, PicoWrite8_io, 1);
  cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, PicoWrite16_io, 1);

  // VDP region
  for (a = 0xc00000; a < 0xe00000; a += 0x010000) {
    if ((a & 0xe700e0) != 0xc00000)
      continue;
    cpu68k_map_set(m68k_read8_map,   a, a + 0xffff, PicoRead8_vdp, 1);
    cpu68k_map_set(m68k_read16_map,  a, a + 0xffff, PicoRead16_vdp, 1);
    cpu68k_map_set(m68k_write8_map,  a, a + 0xffff, PicoWrite8_vdp, 1);
    cpu68k_map_set(m68k_write16_map, a, a + 0xffff, PicoWrite16_vdp, 1);
  }

  // RAM and it's mirrors
  for (a = 0xe00000; a < 0x1000000; a += 0x010000) {
    cpu68k_map_set(m68k_read8_map,   a, a + 0xffff, Pico.ram, 0);
    cpu68k_map_set(m68k_read16_map,  a, a + 0xffff, Pico.ram, 0);
    cpu68k_map_set(m68k_write8_map,  a, a + 0xffff, Pico.ram, 0);
    cpu68k_map_set(m68k_write16_map, a, a + 0xffff, Pico.ram, 0);
  }

  // Setup memory callbacks:
#ifdef EMU_C68K
  PicoCpuCM68k.read8  = (void *)m68k_read8_map;
  PicoCpuCM68k.read16 = (void *)m68k_read16_map;
  PicoCpuCM68k.read32 = (void *)m68k_read16_map;
  PicoCpuCM68k.write8  = (void *)m68k_write8_map;
  PicoCpuCM68k.write16 = (void *)m68k_write16_map;
  PicoCpuCM68k.write32 = (void *)m68k_write16_map;
  PicoCpuCM68k.checkpc = NULL; /* unused */
  PicoCpuCM68k.fetch8  = NULL;
  PicoCpuCM68k.fetch16 = NULL;
  PicoCpuCM68k.fetch32 = NULL;
#endif
#ifdef EMU_F68K
  PicoCpuFM68k.read_byte  = m68k_read8;
  PicoCpuFM68k.read_word  = m68k_read16;
  PicoCpuFM68k.read_long  = m68k_read32;
  PicoCpuFM68k.write_byte = m68k_write8;
  PicoCpuFM68k.write_word = m68k_write16;
  PicoCpuFM68k.write_long = m68k_write32;

  // setup FAME fetchmap
  {
    int i;
    // by default, point everything to first 64k of ROM
    for (i = 0; i < M68K_FETCHBANK1; i++)
      PicoCpuFM68k.Fetch[i] = (unsigned long)Pico.rom - (i<<(24-FAMEC_FETCHBITS));
    // now real ROM
    for (i = 0; i < M68K_FETCHBANK1 && (i<<(24-FAMEC_FETCHBITS)) < Pico.romsize; i++)
      PicoCpuFM68k.Fetch[i] = (unsigned long)Pico.rom;
    // .. and RAM
    for (i = M68K_FETCHBANK1*14/16; i < M68K_FETCHBANK1; i++)
      PicoCpuFM68k.Fetch[i] = (unsigned long)Pico.ram - (i<<(24-FAMEC_FETCHBITS));
  }
#endif
#ifdef EMU_M68K
  m68k_mem_setup();
#endif

  z80_mem_setup();
}

#ifdef EMU_M68K
unsigned int (*pm68k_read_memory_8) (unsigned int address) = NULL;
unsigned int (*pm68k_read_memory_16)(unsigned int address) = NULL;
unsigned int (*pm68k_read_memory_32)(unsigned int address) = NULL;
void (*pm68k_write_memory_8) (unsigned int address, unsigned char  value) = NULL;
void (*pm68k_write_memory_16)(unsigned int address, unsigned short value) = NULL;
void (*pm68k_write_memory_32)(unsigned int address, unsigned int   value) = NULL;

/* it appears that Musashi doesn't always mask the unused bits */
unsigned int m68k_read_memory_8 (unsigned int address) { return pm68k_read_memory_8 (address) & 0xff; }
unsigned int m68k_read_memory_16(unsigned int address) { return pm68k_read_memory_16(address) & 0xffff; }
unsigned int m68k_read_memory_32(unsigned int address) { return pm68k_read_memory_32(address); }
void m68k_write_memory_8 (unsigned int address, unsigned int value) { pm68k_write_memory_8 (address, (u8)value); }
void m68k_write_memory_16(unsigned int address, unsigned int value) { pm68k_write_memory_16(address,(u16)value); }
void m68k_write_memory_32(unsigned int address, unsigned int value) { pm68k_write_memory_32(address, value); }

static void m68k_mem_setup(void)
{
  pm68k_read_memory_8  = m68k_read8;
  pm68k_read_memory_16 = m68k_read16;
  pm68k_read_memory_32 = m68k_read32;
  pm68k_write_memory_8  = m68k_write8;
  pm68k_write_memory_16 = m68k_write16;
  pm68k_write_memory_32 = m68k_write32;
}
#endif // EMU_M68K


// -----------------------------------------------------------------

static int get_scanline(int is_from_z80)
{
  if (is_from_z80) {
    int cycles = z80_cyclesDone();
    while (cycles - z80_scanline_cycles >= 228)
      z80_scanline++, z80_scanline_cycles += 228;
    return z80_scanline;
  }

  return Pico.m.scanline;
}

/* probably should not be in this file, but it's near related code here */
void ym2612_sync_timers(int z80_cycles, int mode_old, int mode_new)
{
  int xcycles = z80_cycles << 8;

  /* check for overflows */
  if ((mode_old & 4) && xcycles > timer_a_next_oflow)
    ym2612.OPN.ST.status |= 1;

  if ((mode_old & 8) && xcycles > timer_b_next_oflow)
    ym2612.OPN.ST.status |= 2;

  /* update timer a */
  if (mode_old & 1)
    while (xcycles > timer_a_next_oflow)
      timer_a_next_oflow += timer_a_step;

  if ((mode_old ^ mode_new) & 1) // turning on/off
  {
    if (mode_old & 1)
      timer_a_next_oflow = TIMER_NO_OFLOW;
    else
      timer_a_next_oflow = xcycles + timer_a_step;
  }
  if (mode_new & 1)
    elprintf(EL_YMTIMER, "timer a upd to %i @ %i", timer_a_next_oflow>>8, z80_cycles);

  /* update timer b */
  if (mode_old & 2)
    while (xcycles > timer_b_next_oflow)
      timer_b_next_oflow += timer_b_step;

  if ((mode_old ^ mode_new) & 2)
  {
    if (mode_old & 2)
      timer_b_next_oflow = TIMER_NO_OFLOW;
    else
      timer_b_next_oflow = xcycles + timer_b_step;
  }
  if (mode_new & 2)
    elprintf(EL_YMTIMER, "timer b upd to %i @ %i", timer_b_next_oflow>>8, z80_cycles);
}

// ym2612 DAC and timer I/O handlers for z80
static int ym2612_write_local(u32 a, u32 d, int is_from_z80)
{
  int addr;

  a &= 3;
  if (a == 1 && ym2612.OPN.ST.address == 0x2a) /* DAC data */
  {
    int scanline = get_scanline(is_from_z80);
    //elprintf(EL_STATUS, "%03i -> %03i dac w %08x z80 %i", PsndDacLine, scanline, d, is_from_z80);
    ym2612.dacout = ((int)d - 0x80) << 6;
    if (PsndOut && ym2612.dacen && scanline >= PsndDacLine)
      PsndDoDAC(scanline);
    return 0;
  }

  switch (a)
  {
    case 0: /* address port 0 */
      ym2612.OPN.ST.address = d;
      ym2612.addr_A1 = 0;
#ifdef __GP2X__
      if (PicoOpt & POPT_EXT_FM) YM2612Write_940(a, d, -1);
#endif
      return 0;

    case 1: /* data port 0    */
      if (ym2612.addr_A1 != 0)
        return 0;

      addr = ym2612.OPN.ST.address;
      ym2612.REGS[addr] = d;

      switch (addr)
      {
        case 0x24: // timer A High 8
        case 0x25: { // timer A Low 2
          int TAnew = (addr == 0x24) ? ((ym2612.OPN.ST.TA & 0x03)|(((int)d)<<2))
                                     : ((ym2612.OPN.ST.TA & 0x3fc)|(d&3));
          if (ym2612.OPN.ST.TA != TAnew)
          {
            //elprintf(EL_STATUS, "timer a set %i", TAnew);
            ym2612.OPN.ST.TA = TAnew;
            //ym2612.OPN.ST.TAC = (1024-TAnew)*18;
            //ym2612.OPN.ST.TAT = 0;
            timer_a_step = TIMER_A_TICK_ZCYCLES * (1024 - TAnew);
            if (ym2612.OPN.ST.mode & 1) {
              // this is not right, should really be done on overflow only
              int cycles = is_from_z80 ? z80_cyclesDone() : z80_cycles_from_68k();
              timer_a_next_oflow = (cycles << 8) + timer_a_step;
            }
            elprintf(EL_YMTIMER, "timer a set to %i, %i", 1024 - TAnew, timer_a_next_oflow>>8);
          }
          return 0;
        }
        case 0x26: // timer B
          if (ym2612.OPN.ST.TB != d) {
            //elprintf(EL_STATUS, "timer b set %i", d);
            ym2612.OPN.ST.TB = d;
            //ym2612.OPN.ST.TBC = (256-d) * 288;
            //ym2612.OPN.ST.TBT  = 0;
            timer_b_step = TIMER_B_TICK_ZCYCLES * (256 - d); // 262800
            if (ym2612.OPN.ST.mode & 2) {
              int cycles = is_from_z80 ? z80_cyclesDone() : z80_cycles_from_68k();
              timer_b_next_oflow = (cycles << 8) + timer_b_step;
            }
            elprintf(EL_YMTIMER, "timer b set to %i, %i", 256 - d, timer_b_next_oflow>>8);
          }
          return 0;
        case 0x27: { /* mode, timer control */
          int old_mode = ym2612.OPN.ST.mode;
          int cycles = is_from_z80 ? z80_cyclesDone() : z80_cycles_from_68k();
          ym2612.OPN.ST.mode = d;

          elprintf(EL_YMTIMER, "st mode %02x", d);
          ym2612_sync_timers(cycles, old_mode, d);

          /* reset Timer a flag */
          if (d & 0x10)
            ym2612.OPN.ST.status &= ~1;

          /* reset Timer b flag */
          if (d & 0x20)
            ym2612.OPN.ST.status &= ~2;

          if ((d ^ old_mode) & 0xc0) {
#ifdef __GP2X__
            if (PicoOpt & POPT_EXT_FM) return YM2612Write_940(a, d, get_scanline(is_from_z80));
#endif
            return 1;
          }
          return 0;
        }
        case 0x2b: { /* DAC Sel  (YM2612) */
          int scanline = get_scanline(is_from_z80);
          ym2612.dacen = d & 0x80;
          if (d & 0x80) PsndDacLine = scanline;
#ifdef __GP2X__
          if (PicoOpt & POPT_EXT_FM) YM2612Write_940(a, d, scanline);
#endif
          return 0;
        }
      }
      break;

    case 2: /* address port 1 */
      ym2612.OPN.ST.address = d;
      ym2612.addr_A1 = 1;
#ifdef __GP2X__
      if (PicoOpt & POPT_EXT_FM) YM2612Write_940(a, d, -1);
#endif
      return 0;

    case 3: /* data port 1    */
      if (ym2612.addr_A1 != 1)
        return 0;

      addr = ym2612.OPN.ST.address | 0x100;
      ym2612.REGS[addr] = d;
      break;
  }

#ifdef __GP2X__
  if (PicoOpt & POPT_EXT_FM)
    return YM2612Write_940(a, d, get_scanline(is_from_z80));
#endif
  return YM2612Write_(a, d);
}


#define ym2612_read_local() \
  if (xcycles >= timer_a_next_oflow) \
    ym2612.OPN.ST.status |= (ym2612.OPN.ST.mode >> 2) & 1; \
  if (xcycles >= timer_b_next_oflow) \
    ym2612.OPN.ST.status |= (ym2612.OPN.ST.mode >> 2) & 2

static u32 ym2612_read_local_z80(void)
{
  int xcycles = z80_cyclesDone() << 8;

  ym2612_read_local();

  elprintf(EL_YMTIMER, "timer z80 read %i, sched %i, %i @ %i|%i", ym2612.OPN.ST.status,
      timer_a_next_oflow>>8, timer_b_next_oflow>>8, xcycles >> 8, (xcycles >> 8) / 228);
  return ym2612.OPN.ST.status;
}

static u32 ym2612_read_local_68k(void)
{
  int xcycles = z80_cycles_from_68k() << 8;

  ym2612_read_local();

  elprintf(EL_YMTIMER, "timer 68k read %i, sched %i, %i @ %i|%i", ym2612.OPN.ST.status,
      timer_a_next_oflow>>8, timer_b_next_oflow>>8, xcycles >> 8, (xcycles >> 8) / 228);
  return ym2612.OPN.ST.status;
}

void ym2612_pack_state(void)
{
  // timers are saved as tick counts, in 16.16 int format
  int tac, tat = 0, tbc, tbt = 0;
  tac = 1024 - ym2612.OPN.ST.TA;
  tbc = 256  - ym2612.OPN.ST.TB;
  if (timer_a_next_oflow != TIMER_NO_OFLOW)
    tat = (int)((double)(timer_a_step - timer_a_next_oflow) / (double)timer_a_step * tac * 65536);
  if (timer_b_next_oflow != TIMER_NO_OFLOW)
    tbt = (int)((double)(timer_b_step - timer_b_next_oflow) / (double)timer_b_step * tbc * 65536);
  elprintf(EL_YMTIMER, "save: timer a %i/%i", tat >> 16, tac);
  elprintf(EL_YMTIMER, "save: timer b %i/%i", tbt >> 16, tbc);

#ifdef __GP2X__
  if (PicoOpt & POPT_EXT_FM)
    YM2612PicoStateSave2_940(tat, tbt);
  else
#endif
    YM2612PicoStateSave2(tat, tbt);
}

void ym2612_unpack_state(void)
{
  int i, ret, tac, tat, tbc, tbt;
  YM2612PicoStateLoad();

  // feed all the registers and update internal state
  for (i = 0x20; i < 0xA0; i++) {
    ym2612_write_local(0, i, 0);
    ym2612_write_local(1, ym2612.REGS[i], 0);
  }
  for (i = 0x30; i < 0xA0; i++) {
    ym2612_write_local(2, i, 0);
    ym2612_write_local(3, ym2612.REGS[i|0x100], 0);
  }
  for (i = 0xAF; i >= 0xA0; i--) { // must apply backwards
    ym2612_write_local(2, i, 0);
    ym2612_write_local(3, ym2612.REGS[i|0x100], 0);
    ym2612_write_local(0, i, 0);
    ym2612_write_local(1, ym2612.REGS[i], 0);
  }
  for (i = 0xB0; i < 0xB8; i++) {
    ym2612_write_local(0, i, 0);
    ym2612_write_local(1, ym2612.REGS[i], 0);
    ym2612_write_local(2, i, 0);
    ym2612_write_local(3, ym2612.REGS[i|0x100], 0);
  }

#ifdef __GP2X__
  if (PicoOpt & POPT_EXT_FM)
    ret = YM2612PicoStateLoad2_940(&tat, &tbt);
  else
#endif
    ret = YM2612PicoStateLoad2(&tat, &tbt);
  if (ret != 0) {
    elprintf(EL_STATUS, "old ym2612 state");
    return; // no saved timers
  }

  tac = (1024 - ym2612.OPN.ST.TA) << 16;
  tbc = (256  - ym2612.OPN.ST.TB) << 16;
  if (ym2612.OPN.ST.mode & 1)
    timer_a_next_oflow = (int)((double)(tac - tat) / (double)tac * timer_a_step);
  else
    timer_a_next_oflow = TIMER_NO_OFLOW;
  if (ym2612.OPN.ST.mode & 2)
    timer_b_next_oflow = (int)((double)(tbc - tbt) / (double)tbc * timer_b_step);
  else
    timer_b_next_oflow = TIMER_NO_OFLOW;
  elprintf(EL_YMTIMER, "load: %i/%i, timer_a_next_oflow %i", tat>>16, tac>>16, timer_a_next_oflow >> 8);
  elprintf(EL_YMTIMER, "load: %i/%i, timer_b_next_oflow %i", tbt>>16, tbc>>16, timer_b_next_oflow >> 8);
}

#if defined(NO_32X) && defined(_ASM_MEMORY_C)
// referenced by asm code
u32 PicoRead8_32x(u32 a) { return 0; }
u32 PicoRead16_32x(u32 a) { return 0; }
void PicoWrite8_32x(u32 a, u32 d) {}
void PicoWrite16_32x(u32 a, u32 d) {}
#endif

// -----------------------------------------------------------------
//                        z80 memhandlers

static unsigned char z80_md_vdp_read(unsigned short a)
{
  // TODO?
  elprintf(EL_ANOMALY, "z80 invalid r8 [%06x] %02x", a, 0xff);
  return 0xff;
}

static unsigned char z80_md_bank_read(unsigned short a)
{
  unsigned int addr68k;
  unsigned char ret;

  addr68k = Pico.m.z80_bank68k<<15;
  addr68k += a & 0x7fff;

  ret = m68k_read8(addr68k);

  elprintf(EL_Z80BNK, "z80->68k r8 [%06x] %02x", addr68k, ret);
  return ret;
}

static void z80_md_ym2612_write(unsigned int a, unsigned char data)
{
  if (PicoOpt & POPT_EN_FM)
    emustatus |= ym2612_write_local(a, data, 1) & 1;
}

static void z80_md_vdp_br_write(unsigned int a, unsigned char data)
{
  // TODO: allow full VDP access
  if ((a&0xfff9) == 0x7f11) // 7f11 7f13 7f15 7f17
  {
    if (PicoOpt & POPT_EN_PSG)
      SN76496Write(data);
    return;
  }

  if ((a>>8) == 0x60)
  {
    Pico.m.z80_bank68k >>= 1;
    Pico.m.z80_bank68k |= data << 8;
    Pico.m.z80_bank68k &= 0x1ff; // 9 bits and filled in the new top one
    return;
  }

  elprintf(EL_ANOMALY, "z80 invalid w8 [%06x] %02x", a, data);
}

static void z80_md_bank_write(unsigned int a, unsigned char data)
{
  unsigned int addr68k;

  addr68k = Pico.m.z80_bank68k << 15;
  addr68k += a & 0x7fff;

  elprintf(EL_Z80BNK, "z80->68k w8 [%06x] %02x", addr68k, data);
  m68k_write8(addr68k, data);
}

// -----------------------------------------------------------------

static unsigned char z80_md_in(unsigned short p)
{
  elprintf(EL_ANOMALY, "Z80 port %04x read", p);
  return 0xff;
}

static void z80_md_out(unsigned short p, unsigned char d)
{
  elprintf(EL_ANOMALY, "Z80 port %04x write %02x", p, d);
}

static void z80_mem_setup(void)
{
  z80_map_set(z80_read_map, 0x0000, 0x1fff, Pico.zram, 0);
  z80_map_set(z80_read_map, 0x2000, 0x3fff, Pico.zram, 0);
  z80_map_set(z80_read_map, 0x4000, 0x5fff, ym2612_read_local_z80, 1);
  z80_map_set(z80_read_map, 0x6000, 0x7fff, z80_md_vdp_read, 1);
  z80_map_set(z80_read_map, 0x8000, 0xffff, z80_md_bank_read, 1);

  z80_map_set(z80_write_map, 0x0000, 0x1fff, Pico.zram, 0);
  z80_map_set(z80_write_map, 0x2000, 0x3fff, Pico.zram, 0);
  z80_map_set(z80_write_map, 0x4000, 0x5fff, z80_md_ym2612_write, 1);
  z80_map_set(z80_write_map, 0x6000, 0x7fff, z80_md_vdp_br_write, 1);
  z80_map_set(z80_write_map, 0x8000, 0xffff, z80_md_bank_write, 1);

#ifdef _USE_DRZ80
  drZ80.z80_in = z80_md_in;
  drZ80.z80_out = z80_md_out;
#endif
#ifdef _USE_CZ80
  Cz80_Set_Fetch(&CZ80, 0x0000, 0x1fff, (FPTR)Pico.zram); // main RAM
  Cz80_Set_Fetch(&CZ80, 0x2000, 0x3fff, (FPTR)Pico.zram); // mirror
  Cz80_Set_INPort(&CZ80, z80_md_in);
  Cz80_Set_OUTPort(&CZ80, z80_md_out);
#endif
}

// vim:shiftwidth=2:ts=2:expandtab
