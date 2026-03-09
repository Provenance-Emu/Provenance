/*
 * memory handling
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 * (C) irixxxx, 2019-2024
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

static void xmap_set(uptr *map, int shift, u32 start_addr, u32 end_addr,
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

void z80_map_set(uptr *map, u16 start_addr, u16 end_addr,
    const void *func_or_mh, int is_func)
{
  xmap_set(map, Z80_MEM_SHIFT, start_addr, end_addr, func_or_mh, is_func);
#ifdef _USE_CZ80
  if (!is_func)
    Cz80_Set_Fetch(&CZ80, start_addr, end_addr, (FPTR)func_or_mh);
#endif
}

void cpu68k_map_set(uptr *map, u32 start_addr, u32 end_addr,
    const void *func_or_mh, int is_func)
{
  xmap_set(map, M68K_MEM_SHIFT, start_addr, end_addr, func_or_mh, is_func & 1);
#ifdef EMU_F68K
  // setup FAME fetchmap
  if (!(is_func & 1))
  {
    M68K_CONTEXT *ctx = is_func & 2 ? &PicoCpuFS68k : &PicoCpuFM68k;
    int shiftout = 24 - FAMEC_FETCHBITS;
    int i = start_addr >> shiftout;
    uptr base = (uptr)func_or_mh - (i << shiftout);
    for (; i <= (end_addr >> shiftout); i++)
      ctx->Fetch[i] = base;
  }
#endif
}

// more specialized/optimized function (does same as above)
void cpu68k_map_read_mem(u32 start_addr, u32 end_addr, void *ptr, int is_sub)
{
  uptr *r8map, *r16map;
  uptr addr = (uptr)ptr;
  int shift = M68K_MEM_SHIFT;
  int i;

  if (!is_sub) {
    r8map = m68k_read8_map;
    r16map = m68k_read16_map;
  } else {
    r8map = s68k_read8_map;
    r16map = s68k_read16_map;
  }

  addr -= start_addr;
  addr >>= 1;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    r8map[i] = r16map[i] = addr;
#ifdef EMU_F68K
  // setup FAME fetchmap
  {
    M68K_CONTEXT *ctx = is_sub ? &PicoCpuFS68k : &PicoCpuFM68k;
    int shiftout = 24 - FAMEC_FETCHBITS;
    i = start_addr >> shiftout;
    addr = (uptr)ptr - (i << shiftout);
    for (; i <= (end_addr >> shiftout); i++)
      ctx->Fetch[i] = addr;
  }
#endif
}

void cpu68k_map_all_ram(u32 start_addr, u32 end_addr, void *ptr, int is_sub)
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
#ifdef EMU_F68K
  // setup FAME fetchmap
  {
    M68K_CONTEXT *ctx = is_sub ? &PicoCpuFS68k : &PicoCpuFM68k;
    int shiftout = 24 - FAMEC_FETCHBITS;
    i = start_addr >> shiftout;
    addr = (uptr)ptr - (i << shiftout);
    for (; i <= (end_addr >> shiftout); i++)
      ctx->Fetch[i] = addr;
  }
#endif
}

void cpu68k_map_read_funcs(u32 start_addr, u32 end_addr, u32 (*r8)(u32), u32 (*r16)(u32), int is_sub)
{
  uptr *r8map, *r16map;
  uptr ar8 = (uptr)r8, ar16 = (uptr)r16;
  int shift = M68K_MEM_SHIFT;
  int i;

  if (!is_sub) {
    r8map = m68k_read8_map;
    r16map = m68k_read16_map;
  } else {
    r8map = s68k_read8_map;
    r16map = s68k_read16_map;
  }

  ar8 = (ar8 >> 1 ) | MAP_FLAG;
  ar16 = (ar16 >> 1 ) | MAP_FLAG;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    r8map[i] = ar8, r16map[i] = ar16;
}

void cpu68k_map_all_funcs(u32 start_addr, u32 end_addr, u32 (*r8)(u32), u32 (*r16)(u32), void (*w8)(u32, u32), void (*w16)(u32, u32), int is_sub)
{
  uptr *r8map, *r16map, *w8map, *w16map;
  uptr ar8 = (uptr)r8, ar16 = (uptr)r16;
  uptr aw8 = (uptr)w8, aw16 = (uptr)w16;
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

  ar8 = (ar8 >> 1 ) | MAP_FLAG;
  ar16 = (ar16 >> 1 ) | MAP_FLAG;
  aw8 = (aw8 >> 1 ) | MAP_FLAG;
  aw16 = (aw16 >> 1 ) | MAP_FLAG;
  for (i = start_addr >> shift; i <= end_addr >> shift; i++)
    r8map[i] = ar8, r16map[i] = ar16, w8map[i] = aw8, w16map[i] = aw16;
}

u32 PicoRead16_floating(u32 a)
{
  // faking open bus
  u16 d = (Pico.m.rotate += 0x41);
  d ^= (d << 5) ^ (d << 8);
  if ((a & 0xff0000) == 0xa10000) return d; // MegaCD pulldowns don't work here curiously
  return (PicoIn.AHW & PAHW_MCD) ? 0x00 : d; // pulldown if MegaCD2 attached
}

static u32 m68k_unmapped_read8(u32 a)
{
  elprintf(EL_UIO, "m68k unmapped r8  [%06x] @%06x", a, SekPc);
  return a < 0x400000 ? 0 : (u8)PicoRead16_floating(a);
}

static u32 m68k_unmapped_read16(u32 a)
{
  elprintf(EL_UIO, "m68k unmapped r16 [%06x] @%06x", a, SekPc);
  return a < 0x400000 ? 0 : PicoRead16_floating(a);
}

static void m68k_unmapped_write8(u32 a, u32 d)
{
  elprintf(EL_UIO, "m68k unmapped w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
}

static void m68k_unmapped_write16(u32 a, u32 d)
{
  elprintf(EL_UIO, "m68k unmapped w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
}

void m68k_map_unmap(u32 start_addr, u32 end_addr)
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

#ifndef _ASM_MEMORY_C
MAKE_68K_READ8(m68k_read8, m68k_read8_map)
MAKE_68K_READ16(m68k_read16, m68k_read16_map)
MAKE_68K_READ32(m68k_read32, m68k_read16_map)
MAKE_68K_WRITE8(m68k_write8, m68k_write8_map)
MAKE_68K_WRITE16(m68k_write16, m68k_write16_map)
MAKE_68K_WRITE32(m68k_write32, m68k_write16_map)
#endif

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
u32 cyclone_crashed(u32 pc, struct Cyclone *context)
{
    // check for underlying ROM, in case of on-cart hw overlaying part of ROM
    // NB assumes code isn't executed from the overlay, but I've never seen this
    u32 pc24 = pc & 0xffffff;
    if (pc24 >= Pico.romsize) {
      // no ROM, so it's probably an illegal access
      pc24 = Pico.romsize;
      elprintf(EL_STATUS|EL_ANOMALY, "%c68k crash detected @ %06x",
        context == &PicoCpuCM68k ? 'm' : 's', pc);
    }

    context->membase = (u32)Pico.rom;
    context->pc = (u32)Pico.rom + pc24;

    return context->pc;
}
#endif

// -----------------------------------------------------------------
// memmap helpers

static u32 read_pad_3btn(int i, u32 out_bits)
{
  u32 pad = ~PicoIn.padInt[i]; // Get inverse of pad MXYZ SACB RLDU
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
  u32 pad = ~PicoIn.padInt[i]; // Get inverse of pad MXYZ SACB RLDU
  int phase = Pico.m.padTHPhase[i];
  u32 value;

  if (phase == 2 && !(out_bits & 0x40)) {
    value = (pad & 0xc0) >> 2;                   // ?0SA 0000
    goto out;
  }
  else if(phase == 3) {
    if (out_bits & 0x40)
      value = (pad & 0x30) | ((pad >> 8) & 0xf); // ?1CB MXYZ
    else
      value = ((pad & 0xc0) >> 2) | 0x0f;        // ?0SA 1111
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

static u32 read_pad_team(int i, u32 out_bits)
{
  u32 pad;
  int phase = Pico.m.padTHPhase[i];
  u32 value;

  switch (phase) {
  case 0:
    value = 0x03;
    break;
  case 1:
    value = 0x0f;
    break;
  case 4: case 5: case 6: case 7: // controller IDs, all 3 btn for now
    value = 0x00;
    break;
  case 8: case 10: case 12: case 14:
    pad = ~PicoIn.padInt[(phase-8) >> 1];
    value = pad & 0x0f;                          // ?x?x RLDU
    break;
  case 9: case 11: case 13: case 15:
    pad = ~PicoIn.padInt[(phase-8) >> 1];
    value = (pad & 0xf0) >>  4;                  // ?x?x SACB
    break;
  default:
    value = 0;
    break;
  }

  value |= (out_bits & 0x40) | ((out_bits & 0x20)>>1);
  return value;
}

static u32 read_pad_4way(int i, u32 out_bits)
{
  u32 pad = (PicoMem.ioports[2] & 0x70) >> 4;
  u32 value = 0;

  if (i == 0 && pad <= 3)
    value = read_pad_3btn(pad, out_bits);

  value |= (out_bits & 0x40);
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

static int padTHLatency[3]; // TODO this should be in the save file structures

static NOINLINE u32 port_read(int i)
{
  u32 data_reg = PicoMem.ioports[i + 1];
  u32 ctrl_reg = PicoMem.ioports[i + 4] | 0x80;
  u32 in, out;

  out = data_reg & ctrl_reg;

  // pull-ups: should be 0x7f, but Decap Attack has a bug where it temp.
  // disables output before doing TH-low read, so emulate RC filter for TH.
  // Decap Attack reportedly doesn't work on Nomad but works on must
  // other MD revisions (different pull-up strength?).
  u32 mask = 0x3f;
  if (CYCLES_GE(SekCyclesDone(), padTHLatency[i])) {
    mask |= 0x40;
    padTHLatency[i] = SekCyclesDone();
  }
  out |= mask & ~ctrl_reg;

  in = port_readers[i](i, out);

  return (in & ~ctrl_reg) | (data_reg & ctrl_reg);
}

// pad export for J-Cart
u32 PicoReadPad(int i, u32 out_bits)
{
  return read_pad_3btn(i, out_bits);
}

void PicoSetInputDevice(int port, enum input_device device)
{
  port_read_func *func;

  if (port < 0 || port > 2)
    return;

  if (port == 1 && port_readers[0] == read_pad_team)
    func = read_nothing;

  else switch (device) {
  case PICO_INPUT_PAD_3BTN:
    func = read_pad_3btn;
    break;

  case PICO_INPUT_PAD_6BTN:
    func = read_pad_6btn;
    break;

  case PICO_INPUT_PAD_TEAM:
    func = read_pad_team;
    break;

  case PICO_INPUT_PAD_4WAY:
    func = read_pad_4way;
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
    default: d = PicoMem.ioports[a]; break; // IO ports can be used as RAM
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
    if (port_readers[a - 1] == read_pad_team) {
      if (d & 0x40)
        Pico.m.padTHPhase[a - 1] = 0;
      else if ((d^PicoMem.ioports[a]) & 0x60)
        Pico.m.padTHPhase[a - 1]++;
    } else if (port_readers[0] == read_pad_4way) {
      if (a == 2 && ((PicoMem.ioports[a] ^ d) & 0x70))
        Pico.m.padTHPhase[0] = 0;
      if (a == 1 && !(PicoMem.ioports[a] & 0x40) && (d & 0x40))
        Pico.m.padTHPhase[0]++;
    } else if (!(PicoMem.ioports[a] & 0x40) && (d & 0x40))
      Pico.m.padTHPhase[a - 1]++;
  }

  // after switching TH to input there's a latency before the pullup value is 
  // read back as input (see Decap Attack, not in Samurai Showdown, 32x WWF Raw)
  if (4 <= a && a <= 5) {
    if ((PicoMem.ioports[a] & 0x40) && !(d & 0x40) && !(PicoMem.ioports[a - 3] & 0x40))
      // latency after switching to input and output was low
      padTHLatency[a - 4] = SekCyclesDone() + 25;
  }

  // certain IO ports can be used as RAM
  PicoMem.ioports[a] = d;
}

static int z80_cycles_from_68k(void)
{
  int m68k_cnt = SekCyclesDone() - Pico.t.m68c_frame_start;
  return cycles_68k_to_z80(m68k_cnt);
}

void NOINLINE ctl_write_z80busreq(u32 d)
{
  d&=1; d^=1;
  elprintf(EL_BUSREQ, "set_zrun: %i->%i [%u] @%06x", Pico.m.z80Run, d, SekCyclesDone(), SekPc);
  if (d ^ Pico.m.z80Run)
  {
    if (d)
    {
      Pico.t.z80c_aim = Pico.t.z80c_cnt = z80_cycles_from_68k() + 2;
      Pico.t.z80c_cnt += Pico.t.z80_busdelay >> 8;
      Pico.t.z80_busdelay &= 0xff;
    }
    else
    {
      if ((PicoIn.opt & POPT_EN_Z80) && !Pico.m.z80_reset) {
        // Z80 grants bus after the current M cycle, even within an insn
        // simulate this by accumulating the last insn overhang in busdelay
        unsigned granted;
        pprof_start(m68k);
        PicoSyncZ80(SekCyclesDone());
        pprof_end_sub(m68k);
        granted = Pico.t.z80c_aim + 6; // M cycle is 3-6 cycles 
        Pico.t.z80_busdelay += (Pico.t.z80c_cnt - granted) << 8;
        Pico.t.z80c_cnt = granted;
      }
    }
    Pico.m.z80Run = d;
  }
}

void NOINLINE ctl_write_z80reset(u32 d)
{
  d&=1; d^=1;
  elprintf(EL_BUSREQ, "set_zreset: %i->%i [%u] @%06x", Pico.m.z80_reset, d, SekCyclesDone(), SekPc);
  if (d ^ Pico.m.z80_reset)
  {
    if (d)
    {
      if ((PicoIn.opt & POPT_EN_Z80) && Pico.m.z80Run) {
        pprof_start(m68k);
        PicoSyncZ80(SekCyclesDone());
        pprof_end_sub(m68k);
      }
      Pico.t.z80_busdelay &= 0xff; // also resets bus request
      YM2612ResetChip();
      timers_reset();
    }
    else
    {
      Pico.t.z80c_aim = Pico.t.z80c_cnt = z80_cycles_from_68k() + 2;
      z80_reset();
    }
    Pico.m.z80_reset = d;
  }
}

static void psg_write_68k(u32 d)
{
  PsndDoPSG(z80_cycles_from_68k());
  SN76496Write(d);
}

static void psg_write_z80(u32 d)
{
  PsndDoPSG(z80_cyclesDone());
  SN76496Write(d);
}

// -----------------------------------------------------------------

#ifndef _ASM_MEMORY_C

// cart (save) RAM area (usually 0x200000 - ...)
static u32 PicoRead8_sram(u32 a)
{
  u32 d;
  if (Pico.sv.start <= a && a <= Pico.sv.end && (Pico.m.sram_reg & SRR_MAPPED))
  {
    if (Pico.sv.flags & SRF_EEPROM) {
      d = EEPROM_read();
      if (!(a & 1))
        d >>= 8;
      d &= 0xff;
    } else
      d = *(u8 *)(Pico.sv.data - Pico.sv.start + a);
    elprintf(EL_SRAMIO, "sram r8  [%06x]   %02x @ %06x", a, d, SekPc);
    return d;
  }

  // XXX: this is banking unfriendly
  if (a < Pico.romsize)
    return Pico.rom[MEM_BE2(a)];
  
  return m68k_unmapped_read8(a);
}

static u32 PicoRead16_sram(u32 a)
{
  u32 d;
  if (Pico.sv.start <= a && a <= Pico.sv.end && (Pico.m.sram_reg & SRR_MAPPED))
  {
    if (Pico.sv.flags & SRF_EEPROM)
      d = EEPROM_read();
    else {
      u8 *pm = (u8 *)(Pico.sv.data - Pico.sv.start + a);
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
  if (a > Pico.sv.end || a < Pico.sv.start || !(Pico.m.sram_reg & SRR_MAPPED)) {
    m68k_unmapped_write8(a, d);
    return;
  }

  elprintf(EL_SRAMIO, "sram w8  [%06x]   %02x @ %06x", a, d & 0xff, SekPc);
  if (Pico.sv.flags & SRF_EEPROM)
  {
    EEPROM_write8(a, d);
  }
  else {
    u8 *pm = (u8 *)(Pico.sv.data - Pico.sv.start + a);
    if (*pm != (u8)d) {
      Pico.sv.changed = 1;
      *pm = (u8)d;
    }
  }
}

static void PicoWrite16_sram(u32 a, u32 d)
{
  if (a > Pico.sv.end || a < Pico.sv.start || !(Pico.m.sram_reg & SRR_MAPPED)) {
    m68k_unmapped_write16(a, d);
    return;
  }

  elprintf(EL_SRAMIO, "sram w16 [%06x] %04x @ %06x", a, d & 0xffff, SekPc);
  if (Pico.sv.flags & SRF_EEPROM)
  {
    EEPROM_write16(d);
  }
  else {
    u8 *pm = (u8 *)(Pico.sv.data - Pico.sv.start + a);
    if (pm[0] != (u8)(d >> 8)) {
      Pico.sv.changed = 1;
      pm[0] = (u8)(d >> 8);
    }
    if (pm[1] != (u8)d) {
      Pico.sv.changed = 1;
      pm[1] = (u8)d;
    }
  }
}

// z80 area (0xa00000 - 0xa0ffff)
// TODO: verify mirrors VDP and bank reg (bank area mirroring verified)
static u32 PicoRead8_z80(u32 a)
{
  u32 d;
  if ((Pico.m.z80Run | Pico.m.z80_reset | (z80_cycles_from_68k() < Pico.t.z80c_cnt)) &&
      !(PicoIn.quirks & PQUIRK_NO_Z80_BUS_LOCK)) {
    elprintf(EL_ANOMALY, "68k z80 read with no bus! [%06x] @ %06x", a, SekPc);
    return (u8)PicoRead16_floating(a);
  }
  SekCyclesBurnRun(1);

  if ((a & 0x4000) == 0x0000) {
    d = PicoMem.zram[a & 0x1fff];
  } else if ((a & 0x6000) == 0x4000) // 0x4000-0x5fff
    d = ym2612_read_local_68k(); 
  else {
    elprintf(EL_UIO|EL_ANOMALY, "68k bad read [%06x] @%06x", a, SekPc);
    d = (u8)PicoRead16_floating(a);
  }
  return d;
}

static u32 PicoRead16_z80(u32 a)
{
  u32 d = PicoRead8_z80(a);
  return d | (d << 8);
}

static void PicoWrite8_z80(u32 a, u32 d)
{
  if ((Pico.m.z80Run | Pico.m.z80_reset) && !(PicoIn.quirks & PQUIRK_NO_Z80_BUS_LOCK)) {
    // verified on real hw
    elprintf(EL_ANOMALY, "68k z80 write with no bus or reset! [%06x] %02x @ %06x", a, d&0xff, SekPc);
    return;
  }
  SekCyclesBurnRun(1);

  if ((a & 0x4000) == 0x0000) { // z80 RAM
    PicoMem.zram[a & 0x1fff] = (u8)d;
    return;
  }
  if ((a & 0x6000) == 0x4000) { // FM Sound
    if (PicoIn.opt & POPT_EN_FM)
      ym2612_write_local(a & 3, d & 0xff, 0);
    return;
  }
  // TODO: probably other VDP access too? Maybe more mirrors?
  if ((a & 0x7ff9) == 0x7f11) { // PSG Sound
    psg_write_68k(d);
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

  if ((a & 0xfc00) == 0x1000) {
    d = (u8)PicoRead16_floating(a);

    if ((a & 0xff01) == 0x1100) { // z80 busreq (verified)
      // bit8 seems to be readable in this range
      if (!(a & 1)) {
        d &= ~0x01;
        // Z80 ahead of 68K only if in BUSREQ, BUSACK only after 68K reached Z80
        d |= (z80_cycles_from_68k() < Pico.t.z80c_cnt);
        d |= (Pico.m.z80Run | Pico.m.z80_reset) & 1;
        elprintf(EL_BUSREQ, "get_zrun: %02x [%u] @%06x", d, SekCyclesDone(), SekPc);
      }
    }
    goto end;
  }

  d = PicoRead8_32x(a);

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

  // bit8 seems to be readable in this range
  if ((a & 0xfc00) == 0x1000) {
    d = PicoRead16_floating(a);

    if ((a & 0xff00) == 0x1100) { // z80 busreq
      d &= ~0x0100;
      d |= (z80_cycles_from_68k() < Pico.t.z80c_cnt) << 8;
      d |= ((Pico.m.z80Run | Pico.m.z80_reset) & 1) << 8;
      elprintf(EL_BUSREQ, "get_zrun: %04x [%u] @%06x", d, SekCyclesDone(), SekPc);
    }
    goto end;
  }

  d = PicoRead16_32x(a);

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
  PicoWrite8_32x(a, d);
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
  PicoWrite16_32x(a, d);
}

#endif // _ASM_MEMORY_C

// VDP area (0xc00000 - 0xdfffff)
// TODO: verify if lower byte goes to PSG on word writes
u32 PicoRead8_vdp(u32 a)
{
  u32 d;
  if ((a & 0x00f0) == 0x0000) {
    switch (a & 0x0d)
    {
      case 0x00: d = PicoVideoRead8DataH(0); break;
      case 0x01: d = PicoVideoRead8DataL(0); break;
      case 0x04: d = PicoVideoRead8CtlH(0); break;
      case 0x05: d = PicoVideoRead8CtlL(0); break;
      case 0x08:
      case 0x0c: d = PicoVideoRead8HV_H(0); break;
      case 0x09:
      case 0x0d: d = PicoVideoRead8HV_L(0); break;
      default:   d = (u8)PicoRead16_floating(a); break;
    }
  } else {
    elprintf(EL_UIO|EL_ANOMALY, "68k bad read [%06x] @%06x", a, SekPc);
    d = (u8)PicoRead16_floating(a);
  }
  return d;
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
    psg_write_68k(d);
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
    psg_write_68k(d);
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
  int mask, rs, sstart, a;

  // setup the memory map
  cpu68k_map_set(m68k_read8_map,   0x000000, 0xffffff, m68k_unmapped_read8, 1);
  cpu68k_map_set(m68k_read16_map,  0x000000, 0xffffff, m68k_unmapped_read16, 1);
  cpu68k_map_set(m68k_write8_map,  0x000000, 0xffffff, m68k_unmapped_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0x000000, 0xffffff, m68k_unmapped_write16, 1);

  // ROM
  // align to bank size. We know ROM loader allocated enough for this
  mask = (1 << M68K_MEM_SHIFT) - 1;
  rs = (Pico.romsize + mask) & ~mask;
  if (rs > 0xa00000) rs = 0xa00000; // max cartridge area
  if (rs) {
    cpu68k_map_set(m68k_read8_map,  0x000000, rs - 1, Pico.rom, 0);
    cpu68k_map_set(m68k_read16_map, 0x000000, rs - 1, Pico.rom, 0);
  }

  // Common case of on-cart (save) RAM, usually at 0x200000-...
  if ((Pico.sv.flags & SRF_ENABLED) && Pico.sv.data != NULL) {
    sstart = Pico.sv.start & ~mask;
    rs = Pico.sv.end - sstart;
    rs = (rs + mask) & ~mask;
    if (sstart + rs >= 0x1000000)
      rs = 0x1000000 - sstart;
    cpu68k_map_set(m68k_read8_map,   sstart, sstart + rs - 1, PicoRead8_sram, 1);
    cpu68k_map_set(m68k_read16_map,  sstart, sstart + rs - 1, PicoRead16_sram, 1);
    cpu68k_map_set(m68k_write8_map,  sstart, sstart + rs - 1, PicoWrite8_sram, 1);
    cpu68k_map_set(m68k_write16_map, sstart, sstart + rs - 1, PicoWrite16_sram, 1);
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
    cpu68k_map_set(m68k_read8_map,   a, a + 0xffff, PicoMem.ram, 0);
    cpu68k_map_set(m68k_read16_map,  a, a + 0xffff, PicoMem.ram, 0);
    cpu68k_map_set(m68k_write8_map,  a, a + 0xffff, PicoMem.ram, 0);
    cpu68k_map_set(m68k_write16_map, a, a + 0xffff, PicoMem.ram, 0);
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
  PicoCpuFM68k.read_byte  = (void *)m68k_read8;
  PicoCpuFM68k.read_word  = (void *)m68k_read16;
  PicoCpuFM68k.read_long  = (void *)m68k_read32;
  PicoCpuFM68k.write_byte = (void *)m68k_write8;
  PicoCpuFM68k.write_word = (void *)m68k_write16;
  PicoCpuFM68k.write_long = (void *)m68k_write32;
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
    // ugh... compute by dividing cycles since frame start by cycles per line
    // need some fractional resolution here, else there may be an extra line
    int cycles_line = cycles_68k_to_z80((unsigned)(488.5*256))+1; // cycles per line, Q8
    int cycles_z80 = (z80_cyclesLeft<0 ? Pico.t.z80c_aim:z80_cyclesDone())<<8;
    int cycles = cycles_line * Pico.t.z80_scanline;
    // approximation by multiplying with inverse
    if (cycles_z80 - cycles >= 4*cycles_line) {
      // compute 1/cycles_line, storing the result to avoid future dividing
      static int cycles_line_o, cycles_line_i;
      if (cycles_line_o != cycles_line)
        { cycles_line_o = cycles_line, cycles_line_i = (1<<22) / cycles_line; }
      // compute lines = diff/cycles_line = diff*(1/cycles_line)
      int lines = ((cycles_z80 - cycles) * cycles_line_i) >> 22;
      Pico.t.z80_scanline += lines, cycles += cycles_line * lines;
    }
    // handle any rounding leftover
    while (cycles_z80 - cycles >= cycles_line)
      Pico.t.z80_scanline ++, cycles += cycles_line;
    return Pico.t.z80_scanline;
  }

  return Pico.m.scanline;
}

#define ym2612_update_status(xcycles) \
  ym2612.OPN.ST.status &= ~0x80; \
  ym2612.OPN.ST.status |= (xcycles < Pico.t.ym2612_busy) * 0x80; \
  if (xcycles >= Pico.t.timer_a_next_oflow) \
    ym2612.OPN.ST.status |= (ym2612.OPN.ST.mode >> 2) & 1; \
  if (xcycles >= Pico.t.timer_b_next_oflow) \
    ym2612.OPN.ST.status |= (ym2612.OPN.ST.mode >> 2) & 2

/* probably should not be in this file, but it's near related code here */
void ym2612_sync_timers(int z80_cycles, int mode_old, int mode_new)
{
  int xcycles = z80_cycles << 8;

  // update timer status
  ym2612_update_status(xcycles);

  // update timer a
  if (mode_old & 1)
    while (xcycles >= Pico.t.timer_a_next_oflow)
      Pico.t.timer_a_next_oflow += Pico.t.timer_a_step;

  // turning on/off
  if ((mode_old ^ mode_new) & 1)
  {
    if (mode_old & 1)
      Pico.t.timer_a_next_oflow = TIMER_NO_OFLOW;
    else {
      /* The internal tick of the YM2612 takes 144 clock cycles (with clock
       * being OSC/7), or 67.2 z80 cycles. Timers are run once each tick.
       * Starting a timer takes place at the next tick, so xcycles needs to be
       * rounded up to that: t = next tick# = (xcycles / TICK_ZCYCLES) + 1
       */
      unsigned t = ((xcycles * (((1LL<<32)/TIMER_A_TICK_ZCYCLES)+1))>>32) + 1;
      Pico.t.timer_a_next_oflow = t*TIMER_A_TICK_ZCYCLES + Pico.t.timer_a_step;
    }
  }

  if (mode_new & 1)
    elprintf(EL_YMTIMER, "timer a upd to %i @ %i", Pico.t.timer_a_next_oflow>>8, z80_cycles);

  // update timer b
  if (mode_old & 2)
    while (xcycles >= Pico.t.timer_b_next_oflow)
      Pico.t.timer_b_next_oflow += Pico.t.timer_b_step;

  // turning on/off
  if ((mode_old ^ mode_new) & 2)
  {
    if (mode_old & 2)
      Pico.t.timer_b_next_oflow = TIMER_NO_OFLOW;
    else {
      /* timer b has a divider of 16 which runs in its own counter. It is not
       * reset by loading timer b. The first run of timer b after loading is
       * therefore shorter by up to 15 ticks.
       */
      unsigned t = ((xcycles * (((1LL<<32)/TIMER_A_TICK_ZCYCLES)+1))>>32) + 1;
      int step = Pico.t.timer_b_step - TIMER_A_TICK_ZCYCLES*(t&15);
      Pico.t.timer_b_next_oflow = t*TIMER_A_TICK_ZCYCLES + step;
    }
  }

  if (mode_new & 2)
    elprintf(EL_YMTIMER, "timer b upd to %i @ %i", Pico.t.timer_b_next_oflow>>8, z80_cycles);
}

// ym2612 DAC and timer I/O handlers for z80
static int ym2612_write_local(u32 a, u32 d, int is_from_z80)
{
  int cycles = is_from_z80 ? z80_cyclesDone() : z80_cycles_from_68k();
  int addr;

  a &= 3;
  switch (a)
  {
    case 0: /* address port 0 */
    case 2: /* address port 1 */
      ym2612.OPN.ST.address = d;
      ym2612.addr_A1 = (a & 2) >> 1;
#ifdef __GP2X__
      if (PicoIn.opt & POPT_EXT_FM) YM2612Write_940(a, d, -1);
#endif
      return 0;

    case 1: /* data port 0    */
    case 3: /* data port 1    */
      addr = ym2612.OPN.ST.address | ((int)ym2612.addr_A1 << 8);
      ym2612.REGS[addr] = d;

      // the busy flag in the YM2612 status is actually a 32 cycle timer
      // (89.6 Z80 cycles), triggered by any write to the data port.
      Pico.t.ym2612_busy = (cycles << 8) + YMBUSY_ZCYCLES; // Q8 for convenience

      switch (addr)
      {
        case 0x24: // timer A High 8
        case 0x25: { // timer A Low 2
          int TAnew = (addr == 0x24) ? ((ym2612.OPN.ST.TA & 0x03)|(((int)d)<<2))
                                     : ((ym2612.OPN.ST.TA & 0x3fc)|(d&3));
          if (ym2612.OPN.ST.TA != TAnew)
          {
            ym2612_sync_timers(cycles, ym2612.OPN.ST.mode, ym2612.OPN.ST.mode);
            //elprintf(EL_STATUS, "timer a set %i", TAnew);
            ym2612.OPN.ST.TA = TAnew;
            //ym2612.OPN.ST.TAC = (1024-TAnew)*18;
            //ym2612.OPN.ST.TAT = 0;
            Pico.t.timer_a_step = TIMER_A_TICK_ZCYCLES * (1024 - TAnew);
            elprintf(EL_YMTIMER, "timer a set to %i, %i", 1024 - TAnew, Pico.t.timer_a_next_oflow>>8);
          }
          return 0;
        }
        case 0x26: // timer B
          if (ym2612.OPN.ST.TB != d) {
            ym2612_sync_timers(cycles, ym2612.OPN.ST.mode, ym2612.OPN.ST.mode);
            //elprintf(EL_STATUS, "timer b set %i", d);
            ym2612.OPN.ST.TB = d;
            //ym2612.OPN.ST.TBC = (256-d) * 288;
            //ym2612.OPN.ST.TBT  = 0;
            Pico.t.timer_b_step = TIMER_B_TICK_ZCYCLES * (256 - d);
            elprintf(EL_YMTIMER, "timer b set to %i, %i", 256 - d, Pico.t.timer_b_next_oflow>>8);
          }
          return 0;
        case 0x27: { /* mode, timer control */
          int old_mode = ym2612.OPN.ST.mode;

          elprintf(EL_YMTIMER, "st mode %02x", d);
          ym2612_sync_timers(cycles, old_mode, d);

          ym2612.OPN.ST.mode = d;

          /* reset Timer a flag */
          if (d & 0x10)
            ym2612.OPN.ST.status &= ~1;

          /* reset Timer b flag */
          if (d & 0x20)
            ym2612.OPN.ST.status &= ~2;

          if ((d ^ old_mode) & 0xc0) {
#ifdef __GP2X__
            if (PicoIn.opt & POPT_EXT_FM) return YM2612Write_940(a, d, get_scanline(is_from_z80));
#endif
            PsndDoFM(cycles);
            return 1;
          }
          return 0;
        }
        case 0x2a: { /* DAC data */
          //elprintf(EL_STATUS, "%03i dac w %08x z80 %i", cycles, d, is_from_z80);
          if (ym2612.dacen)
            PsndDoDAC(cycles);
          ym2612.dacout = ((int)d - 0x80) << 6;
          return 0;
        }
        case 0x2b: { /* DAC Sel  (YM2612) */
          ym2612.dacen = d & 0x80;
#ifdef __GP2X__
          if (PicoIn.opt & POPT_EXT_FM) YM2612Write_940(a, d, get_scanline(is_from_z80));
#endif
          return 0;
        }
      }
      break;
  }

#ifdef __GP2X__
  if (PicoIn.opt & POPT_EXT_FM)
    return YM2612Write_940(a, d, get_scanline(is_from_z80));
#endif
  PsndDoFM(cycles);
  return YM2612Write_(a, d);
}


static u32 ym2612_read_local_z80(void)
{
  int xcycles = z80_cyclesDone() << 8;

  ym2612_update_status(xcycles);

  elprintf(EL_YMTIMER, "timer z80 read %i, sched %i, %i @ %i|%i",
    ym2612.OPN.ST.status, Pico.t.timer_a_next_oflow >> 8,
    Pico.t.timer_b_next_oflow >> 8, xcycles >> 8, (xcycles >> 8) / 228);
  return ym2612.OPN.ST.status;
}

static u32 ym2612_read_local_68k(void)
{
  int xcycles = z80_cycles_from_68k() << 8;

  ym2612_update_status(xcycles);

  elprintf(EL_YMTIMER, "timer 68k read %i, sched %i, %i @ %i|%i",
    ym2612.OPN.ST.status, Pico.t.timer_a_next_oflow >> 8,
    Pico.t.timer_b_next_oflow >> 8, xcycles >> 8, (xcycles >> 8) / 228);
  return ym2612.OPN.ST.status;
}

void ym2612_pack_state(void)
{
  // timers are saved as tick counts, in 16.16 int format
  int tac, tat = 0, tbc, tbt = 0, busy = 0;
  tac = 1024 - ym2612.OPN.ST.TA;
  tbc = 256  - ym2612.OPN.ST.TB;
  if (Pico.t.ym2612_busy > 0)
    busy = cycles_z80_to_68k(Pico.t.ym2612_busy);
  if (Pico.t.timer_a_next_oflow != TIMER_NO_OFLOW)
    tat = (int)((double)(Pico.t.timer_a_step - Pico.t.timer_a_next_oflow)
          / (double)Pico.t.timer_a_step * tac * 65536);
  if (Pico.t.timer_b_next_oflow != TIMER_NO_OFLOW)
    tbt = (int)((double)(Pico.t.timer_b_step - Pico.t.timer_b_next_oflow)
          / (double)Pico.t.timer_b_step * tbc * 65536);
  elprintf(EL_YMTIMER, "save: timer a %i/%i", tat >> 16, tac);
  elprintf(EL_YMTIMER, "save: timer b %i/%i", tbt >> 16, tbc);

#ifdef __GP2X__
  if (PicoIn.opt & POPT_EXT_FM)
    YM2612PicoStateSave2_940(tat, tbt);
  else
#endif
    YM2612PicoStateSave2(tat, tbt, busy);
}

void ym2612_unpack_state(void)
{
  int i, ret, tac, tat, tbc, tbt, busy = 0;
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
  if (PicoIn.opt & POPT_EXT_FM)
    ret = YM2612PicoStateLoad2_940(&tat, &tbt);
  else
#endif
    ret = YM2612PicoStateLoad2(&tat, &tbt, &busy);
  if (ret != 0) {
    elprintf(EL_STATUS, "old ym2612 state");
    return; // no saved timers
  }

  Pico.t.ym2612_busy = cycles_68k_to_z80(busy);
  tac = (1024 - ym2612.OPN.ST.TA) << 16;
  tbc = (256  - ym2612.OPN.ST.TB) << 16;
  if (ym2612.OPN.ST.mode & 1)
    Pico.t.timer_a_next_oflow = (int)((double)(tac - tat) / (double)tac * Pico.t.timer_a_step);
  else
    Pico.t.timer_a_next_oflow = TIMER_NO_OFLOW;
  if (ym2612.OPN.ST.mode & 2)
    Pico.t.timer_b_next_oflow = (int)((double)(tbc - tbt) / (double)tbc * Pico.t.timer_b_step);
  else
    Pico.t.timer_b_next_oflow = TIMER_NO_OFLOW;
  elprintf(EL_YMTIMER, "load: %i/%i, timer_a_next_oflow %i", tat>>16, tac>>16, Pico.t.timer_a_next_oflow >> 8);
  elprintf(EL_YMTIMER, "load: %i/%i, timer_b_next_oflow %i", tbt>>16, tbc>>16, Pico.t.timer_b_next_oflow >> 8);
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

static void access_68k_bus(int delay) // bus delay as Q8
{
  // TODO: if the 68K is in DMA wait, Z80 has to wait until DMA ends

  // 68k bus access delay for z80. The fractional part needs to be accumulated
  // until an additional cycle is full. That is then added to the integer part.
  Pico.t.z80_busdelay += (delay&0xff); // accumulate
  z80_subCLeft((delay>>8) + (Pico.t.z80_busdelay>>8));
  Pico.t.z80_busdelay &= 0xff; // leftover cycle fraction
  // don't use SekCyclesBurn() here since the Z80 doesn't run in cycle lock to
  // the 68K. Count the stolen cycles to be accounted later in the 68k CPU runs
  Pico.t.z80_buscycles += 8; // TODO <=8.4 for Rick 2, but >=8.9 for misc_test
}

static unsigned char z80_md_vdp_read(unsigned short a)
{
  if ((a & 0xff00) == 0x7f00) {
    // 68k bus access delay=3.3 per kabuto, for notaz picotest 2.42<delay<2.57?
    access_68k_bus(0x280); // Q8, picotest: 0x26d(>2.42) - 0x292(<2.57)

    switch (a & 0x0d)
    {
      case 0x00: return PicoVideoRead8DataH(1);
      case 0x01: return PicoVideoRead8DataL(1);
      case 0x04: return PicoVideoRead8CtlH(1);
      case 0x05: return PicoVideoRead8CtlL(1);
      case 0x08:
      case 0x0c: return PicoVideoGetV(get_scanline(1), 1);
      case 0x09:
      case 0x0d: return Pico.m.rotate++;
    }
  }

  elprintf(EL_ANOMALY, "z80 invalid r8 [%06x] %02x", a, 0xff);
  return 0xff;
}

static unsigned char z80_md_bank_read(unsigned short a)
{
  unsigned int addr68k;
  unsigned char ret = 0xff;

  // 68k bus access delay=3.3 per kabuto, but for notaz picotest 3.02<delay<3.32
  access_68k_bus(0x340); // Q8, picotest: 0x306(>3.02)-0x351(<3.32)

  addr68k = Pico.m.z80_bank68k << 15;
  addr68k |= a & 0x7fff;

  if (addr68k < 0xe00000) // can't read from 68K RAM
    ret = m68k_read8(addr68k);

  elprintf(EL_Z80BNK, "z80->68k r8 [%06x] %02x", addr68k, ret);
  return ret;
}

static void z80_md_ym2612_write(unsigned int a, unsigned char data)
{
  if (PicoIn.opt & POPT_EN_FM)
    ym2612_write_local(a, data, 1);
}

static void z80_md_vdp_br_write(unsigned int a, unsigned char data)
{
  if ((a&0xfff9) == 0x7f11) // 7f11 7f13 7f15 7f17
  {
    psg_write_z80(data);
    return;
  }
  // at least VDP data writes hang my machine

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

  // 68k bus access delay=3.3 per kabuto, but for notaz picotest 3.02<delay<3.32
  access_68k_bus(0x340); // Q8, picotest: 0x306(>3.02)-0x351(<3.32)

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
  z80_map_set(z80_read_map, 0x0000, 0x1fff, PicoMem.zram, 0);
  z80_map_set(z80_read_map, 0x2000, 0x3fff, PicoMem.zram, 0);
  z80_map_set(z80_read_map, 0x4000, 0x5fff, ym2612_read_local_z80, 1);
  z80_map_set(z80_read_map, 0x6000, 0x7fff, z80_md_vdp_read, 1);
  z80_map_set(z80_read_map, 0x8000, 0xffff, z80_md_bank_read, 1);

  z80_map_set(z80_write_map, 0x0000, 0x1fff, PicoMem.zram, 0);
  z80_map_set(z80_write_map, 0x2000, 0x3fff, PicoMem.zram, 0);
  z80_map_set(z80_write_map, 0x4000, 0x5fff, z80_md_ym2612_write, 1);
  z80_map_set(z80_write_map, 0x6000, 0x7fff, z80_md_vdp_br_write, 1);
  z80_map_set(z80_write_map, 0x8000, 0xffff, z80_md_bank_write, 1);

#ifdef _USE_DRZ80
  drZ80.z80_in = z80_md_in;
  drZ80.z80_out = z80_md_out;
#endif
#ifdef _USE_CZ80
  Cz80_Set_INPort(&CZ80, z80_md_in);
  Cz80_Set_OUTPort(&CZ80, z80_md_out);
#endif
}

// vim:shiftwidth=2:ts=2:expandtab
