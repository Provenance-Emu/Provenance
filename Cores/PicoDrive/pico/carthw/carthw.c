/*
 * Support for a few cart mappers and some protection.
 * (C) notaz, 2008-2011
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"
#include "../memory.h"


/* The SSFII mapper */
static unsigned char ssf2_banks[8];

static carthw_state_chunk carthw_ssf2_state[] =
{
	{ CHUNK_CARTHW, sizeof(ssf2_banks), &ssf2_banks },
	{ 0,            0,                  NULL }
};

static void carthw_ssf2_write8(u32 a, u32 d)
{
	u32 target, base;

	if ((a & 0xfffff0) != 0xa130f0) {
		PicoWrite8_io(a, d);
		return;
	}

	a &= 0x0e;
	if (a == 0)
		return;

	ssf2_banks[a >> 1] = d;
	base = d << 19;
	target = a << 18;
	if (base + 0x80000 > Pico.romsize) {
		elprintf(EL_ANOMALY|EL_STATUS, "ssf2: missing bank @ %06x", base);
		return;
	}

	cpu68k_map_set(m68k_read8_map,  target, target + 0x80000 - 1, Pico.rom + base, 0);
	cpu68k_map_set(m68k_read16_map, target, target + 0x80000 - 1, Pico.rom + base, 0);
}

static void carthw_ssf2_mem_setup(void)
{
	cpu68k_map_set(m68k_write8_map, 0xa10000, 0xa1ffff, carthw_ssf2_write8, 1);
}

static void carthw_ssf2_statef(void)
{
	int i;
	for (i = 1; i < 8; i++)
		carthw_ssf2_write8(0xa130f0 | (i << 1), ssf2_banks[i]);
}

void carthw_ssf2_startup(void)
{
	int i;

	elprintf(EL_STATUS, "SSF2 mapper startup");

	// default map
	for (i = 0; i < 8; i++)
		ssf2_banks[i] = i;

	PicoCartMemSetup  = carthw_ssf2_mem_setup;
	PicoLoadStateHook = carthw_ssf2_statef;
	carthw_chunks     = carthw_ssf2_state;
}


/* Common *-in-1 pirate mapper.
 * Switches banks based on addr lines when /TIME is set.
 * TODO: verify
 */
static unsigned int carthw_Xin1_baddr = 0;

static void carthw_Xin1_do(u32 a, int mask, int shift)
{
	int len;

	carthw_Xin1_baddr = a;
	a &= mask;
	a <<= shift;
	len = Pico.romsize - a;
	if (len <= 0) {
		elprintf(EL_ANOMALY|EL_STATUS, "X-in-1: missing bank @ %06x", a);
		return;
	}

	len = (len + M68K_BANK_MASK) & ~M68K_BANK_MASK;
	cpu68k_map_set(m68k_read8_map,  0x000000, len - 1, Pico.rom + a, 0);
	cpu68k_map_set(m68k_read16_map, 0x000000, len - 1, Pico.rom + a, 0);
}

static carthw_state_chunk carthw_Xin1_state[] =
{
	{ CHUNK_CARTHW, sizeof(carthw_Xin1_baddr), &carthw_Xin1_baddr },
	{ 0,            0,                         NULL }
};

// TODO: test a0, reads, w16
static void carthw_Xin1_write8(u32 a, u32 d)
{
	if ((a & 0xffff00) != 0xa13000) {
		PicoWrite8_io(a, d);
		return;
	}

	carthw_Xin1_do(a, 0x3f, 16);
}

static void carthw_Xin1_mem_setup(void)
{
	cpu68k_map_set(m68k_write8_map, 0xa10000, 0xa1ffff, carthw_Xin1_write8, 1);
}

static void carthw_Xin1_reset(void)
{
	carthw_Xin1_write8(0xa13000, 0);
}

static void carthw_Xin1_statef(void)
{
	carthw_Xin1_write8(carthw_Xin1_baddr, 0);
}

void carthw_Xin1_startup(void)
{
	elprintf(EL_STATUS, "X-in-1 mapper startup");

	PicoCartMemSetup  = carthw_Xin1_mem_setup;
	PicoResetHook     = carthw_Xin1_reset;
	PicoLoadStateHook = carthw_Xin1_statef;
	carthw_chunks     = carthw_Xin1_state;
}


/* Realtec, based on TascoDLX doc
 * http://www.sharemation.com/TascoDLX/REALTEC%20Cart%20Mapper%20-%20description%20v1.txt
 */
static int realtec_bank = 0x80000000, realtec_size = 0x80000000;

static void carthw_realtec_write8(u32 a, u32 d)
{
	int i, bank_old = realtec_bank, size_old = realtec_size;

	if (a == 0x400000)
	{
		realtec_bank &= 0x0e0000;
		realtec_bank |= 0x300000 & (d << 19);
		if (realtec_bank != bank_old)
			elprintf(EL_ANOMALY, "write [%06x] %02x @ %06x", a, d, SekPc);
	}
	else if (a == 0x402000)
	{
		realtec_size = (d << 17) & 0x3e0000;
		if (realtec_size != size_old)
			elprintf(EL_ANOMALY, "write [%06x] %02x @ %06x", a, d, SekPc);
	}
	else if (a == 0x404000)
	{
		realtec_bank &= 0x300000;
		realtec_bank |= 0x0e0000 & (d << 17);
		if (realtec_bank != bank_old)
			elprintf(EL_ANOMALY, "write [%06x] %02x @ %06x", a, d, SekPc);
	}
	else
		elprintf(EL_ANOMALY, "realtec: unexpected write [%06x] %02x @ %06x", a, d, SekPc);

	if (realtec_bank >= 0 && realtec_size >= 0 &&
		(realtec_bank != bank_old || realtec_size != size_old))
	{
		elprintf(EL_ANOMALY, "realtec: new bank %06x, size %06x", realtec_bank, realtec_size, SekPc);
		if (realtec_size > Pico.romsize - realtec_bank)
		{
			elprintf(EL_ANOMALY, "realtec: bank too large / out of range?");
			return;
		}

		for (i = 0; i < 0x400000; i += realtec_size) {
			cpu68k_map_set(m68k_read8_map,  i, realtec_size - 1, Pico.rom + realtec_bank, 0);
			cpu68k_map_set(m68k_read16_map, i, realtec_size - 1, Pico.rom + realtec_bank, 0);
		}
	}
}

static void carthw_realtec_reset(void)
{
	int i;

	/* map boot code */
	for (i = 0; i < 0x400000; i += M68K_BANK_SIZE) {
		cpu68k_map_set(m68k_read8_map,  i, i + M68K_BANK_SIZE - 1, Pico.rom + Pico.romsize, 0);
		cpu68k_map_set(m68k_read16_map, i, i + M68K_BANK_SIZE - 1, Pico.rom + Pico.romsize, 0);
	}
	cpu68k_map_set(m68k_write8_map, 0x400000, 0x400000 + M68K_BANK_SIZE - 1, carthw_realtec_write8, 1);
	realtec_bank = realtec_size = 0x80000000;
}

void carthw_realtec_startup(void)
{
	int i;

	elprintf(EL_STATUS, "Realtec mapper startup");

	// allocate additional bank for boot code
	// (we know those ROMs have aligned size)
	i = PicoCartResize(Pico.romsize + M68K_BANK_SIZE);
	if (i != 0) {
		elprintf(EL_STATUS, "OOM");
		return;
	}

	// create bank for boot code
	for (i = 0; i < M68K_BANK_SIZE; i += 0x2000)
		memcpy(Pico.rom + Pico.romsize + i, Pico.rom + Pico.romsize - 0x2000, 0x2000);

	PicoResetHook = carthw_realtec_reset;
}

/* Radica mapper, based on DevSter's info
 * http://devster.monkeeh.com/sega/radica/
 * XXX: mostly the same as X-in-1, merge?
 */
static u32 carthw_radica_read16(u32 a)
{
	if ((a & 0xffff00) != 0xa13000)
		return PicoRead16_io(a);

	carthw_Xin1_do(a, 0x7e, 15);

	return 0;
}

static void carthw_radica_mem_setup(void)
{
	cpu68k_map_set(m68k_read16_map, 0xa10000, 0xa1ffff, carthw_radica_read16, 1);
}

static void carthw_radica_statef(void)
{
	carthw_radica_read16(carthw_Xin1_baddr);
}

static void carthw_radica_reset(void)
{
	carthw_radica_read16(0xa13000);
}

void carthw_radica_startup(void)
{
	elprintf(EL_STATUS, "Radica mapper startup");

	PicoCartMemSetup  = carthw_radica_mem_setup;
	PicoResetHook     = carthw_radica_reset;
	PicoLoadStateHook = carthw_radica_statef;
	carthw_chunks     = carthw_Xin1_state;
}


/* Pier Solar. Based on my own research */
static unsigned char pier_regs[8];
static unsigned char pier_dump_prot;

static carthw_state_chunk carthw_pier_state[] =
{
  { CHUNK_CARTHW,     sizeof(pier_regs),      pier_regs },
  { CHUNK_CARTHW + 1, sizeof(pier_dump_prot), &pier_dump_prot },
  { 0,                0,                      NULL }
};

static void carthw_pier_write8(u32 a, u32 d)
{
  u32 a8, target, base;

  if ((a & 0xffff00) != 0xa13000) {
    PicoWrite8_io(a, d);
    return;
  }

  a8 = a & 0x0f;
  pier_regs[a8 / 2] = d;

      elprintf(EL_UIO, "pier w8  [%06x] %02x @%06x", a, d & 0xffff, SekPc);
  switch (a8) {
    case 0x01:
      break;
    case 0x03:
      if (!(pier_regs[0] & 2))
        goto unmapped;
      target = 0x280000;
      base = d << 19;
      goto do_map;
    case 0x05:
      if (!(pier_regs[0] & 2))
        goto unmapped;
      target = 0x300000;
      base = d << 19;
      goto do_map;
    case 0x07:
      if (!(pier_regs[0] & 2))
        goto unmapped;
      target = 0x380000;
      base = d << 19;
      goto do_map;
    case 0x09:
      // TODO
      break;
    case 0x0b:
      // eeprom read
    default:
    unmapped:
      //elprintf(EL_UIO, "pier w8  [%06x] %02x @%06x", a, d & 0xffff, SekPc);
      elprintf(EL_STATUS, "-- unmapped w8 [%06x] %02x @%06x", a, d & 0xffff, SekPc);
      break;
  }
  return;

do_map:
  if (base + 0x80000 > Pico.romsize) {
    elprintf(EL_ANOMALY|EL_STATUS, "pier: missing bank @ %06x", base);
    return;
  }
  cpu68k_map_set(m68k_read8_map,  target, target + 0x80000 - 1, Pico.rom + base, 0);
  cpu68k_map_set(m68k_read16_map, target, target + 0x80000 - 1, Pico.rom + base, 0);
}

static void carthw_pier_write16(u32 a, u32 d)
{
  if ((a & 0xffff00) != 0xa13000) {
    PicoWrite16_io(a, d);
    return;
  }

  elprintf(EL_UIO, "pier w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
  carthw_pier_write8(a + 1, d);
}

static u32 carthw_pier_read8(u32 a)
{
  if ((a & 0xffff00) != 0xa13000)
    return PicoRead8_io(a);

  if (a == 0xa1300b)
    return 0; // TODO

  elprintf(EL_UIO, "pier r8  [%06x] @%06x", a, SekPc);
  return 0;
}

static void carthw_pier_statef(void);

static u32 carthw_pier_prot_read8(u32 a)
{
  /* it takes more than just these reads here to disable ROM protection,
   * but for game emulation purposes this is enough. */
  if (pier_dump_prot > 0)
    pier_dump_prot--;
  if (pier_dump_prot == 0) {
    carthw_pier_statef();
    elprintf(EL_STATUS, "prot off on r8 @%06x", SekPc);
  }
  elprintf(EL_UIO, "pier r8  [%06x] @%06x", a, SekPc);

  return Pico.rom[(a & 0x7fff) ^ 1];
}

static void carthw_pier_mem_setup(void)
{
  cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, carthw_pier_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, carthw_pier_write16, 1);
  cpu68k_map_set(m68k_read8_map,   0xa10000, 0xa1ffff, carthw_pier_read8, 1);
}

static void carthw_pier_prot_mem_setup(int prot_enable)
{
  if (prot_enable) {
    /* the dump protection.. */
    int a;
    for (a = 0x000000; a < 0x400000; a += M68K_BANK_SIZE) {
      cpu68k_map_set(m68k_read8_map,  a, a + 0xffff, Pico.rom + Pico.romsize, 0);
      cpu68k_map_set(m68k_read16_map, a, a + 0xffff, Pico.rom + Pico.romsize, 0);
    }
    cpu68k_map_set(m68k_read8_map, M68K_BANK_SIZE, M68K_BANK_SIZE * 2 - 1,
      carthw_pier_prot_read8, 1);
  }
  else {
    cpu68k_map_set(m68k_read8_map,  0, 0x27ffff, Pico.rom, 0);
    cpu68k_map_set(m68k_read16_map, 0, 0x27ffff, Pico.rom, 0);
  }
}

static void carthw_pier_statef(void)
{
  carthw_pier_prot_mem_setup(pier_dump_prot);

  if (!pier_dump_prot) {
    /* setup all banks */
    u32 r0 = pier_regs[0];
    carthw_pier_write8(0xa13001, 3);
    carthw_pier_write8(0xa13003, pier_regs[1]);
    carthw_pier_write8(0xa13005, pier_regs[2]);
    carthw_pier_write8(0xa13007, pier_regs[3]);
    carthw_pier_write8(0xa13001, r0);
  }
}

static void carthw_pier_reset(void)
{
  pier_regs[0] = 1;
  pier_regs[1] = pier_regs[2] = pier_regs[3] = 0;
  pier_dump_prot = 3;
  carthw_pier_statef();
}

void carthw_pier_startup(void)
{
  int i;

  elprintf(EL_STATUS, "Pier Solar mapper startup");

  // mostly same as for realtec..
  i = PicoCartResize(Pico.romsize + M68K_BANK_SIZE);
  if (i != 0) {
    elprintf(EL_STATUS, "OOM");
    return;
  }

  // create dump protection bank
  for (i = 0; i < M68K_BANK_SIZE; i += 0x8000)
    memcpy(Pico.rom + Pico.romsize + i, Pico.rom, 0x8000);

  PicoCartMemSetup  = carthw_pier_mem_setup;
  PicoResetHook     = carthw_pier_reset;
  PicoLoadStateHook = carthw_pier_statef;
  carthw_chunks     = carthw_pier_state;
}

/* Simple unlicensed ROM protection emulation */
static struct {
  u32 addr;
  u32 mask;
  u16 val;
  u16 readonly;
} *sprot_items;
static int sprot_item_alloc;
static int sprot_item_count;

static u16 *carthw_sprot_get_val(u32 a, int rw_only)
{
  int i;

  for (i = 0; i < sprot_item_count; i++)
    if ((a & sprot_items[i].mask) == sprot_items[i].addr)
      if (!rw_only || !sprot_items[i].readonly)
        return &sprot_items[i].val;

  return NULL;
}

static u32 PicoRead8_sprot(u32 a)
{
  u16 *val;
  u32 d;

  if (0xa10000 <= a && a < 0xa12000)
    return PicoRead8_io(a);

  val = carthw_sprot_get_val(a, 0);
  if (val != NULL) {
    d = *val;
    if (!(a & 1))
      d >>= 8;
    elprintf(EL_UIO, "prot r8  [%06x]   %02x @%06x", a, d, SekPc);
    return d;
  }
  else {
    elprintf(EL_UIO, "prot r8  [%06x] MISS @%06x", a, SekPc);
    return 0;
  }
}

static u32 PicoRead16_sprot(u32 a)
{
  u16 *val;

  if (0xa10000 <= a && a < 0xa12000)
    return PicoRead16_io(a);

  val = carthw_sprot_get_val(a, 0);
  if (val != NULL) {
    elprintf(EL_UIO, "prot r16 [%06x] %04x @%06x", a, *val, SekPc);
    return *val;
  }
  else {
    elprintf(EL_UIO, "prot r16 [%06x] MISS @%06x", a, SekPc);
    return 0;
  }
}

static void PicoWrite8_sprot(u32 a, u32 d)
{
  u16 *val;

  if (0xa10000 <= a && a < 0xa12000) {
    PicoWrite8_io(a, d);
    return;
  }

  val = carthw_sprot_get_val(a, 1);
  if (val != NULL) {
    if (a & 1)
      *val = (*val & 0xff00) | (d | 0xff);
    else
      *val = (*val & 0x00ff) | (d << 8);
    elprintf(EL_UIO, "prot w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
  }
  else
    elprintf(EL_UIO, "prot w8  [%06x]   %02x MISS @%06x", a, d & 0xff, SekPc);
}

static void PicoWrite16_sprot(u32 a, u32 d)
{
  u16 *val;

  if (0xa10000 <= a && a < 0xa12000) {
    PicoWrite16_io(a, d);
    return;
  }

  val = carthw_sprot_get_val(a, 1);
  if (val != NULL) {
    *val = d;
    elprintf(EL_UIO, "prot w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
  }
  else
    elprintf(EL_UIO, "prot w16 [%06x] %04x MISS @%06x", a, d & 0xffff, SekPc);
}

void carthw_sprot_new_location(unsigned int a, unsigned int mask, unsigned short val, int is_ro)
{
  if (sprot_items == NULL) {
    sprot_items = calloc(8, sizeof(sprot_items[0]));
    sprot_item_alloc = 8;
    sprot_item_count = 0;
  }

  if (sprot_item_count == sprot_item_alloc) {
    void *tmp;
    sprot_item_alloc *= 2;
    tmp = realloc(sprot_items, sprot_item_alloc);
    if (tmp == NULL) {
      elprintf(EL_STATUS, "OOM");
      return;
    }
    sprot_items = tmp;
  }

  sprot_items[sprot_item_count].addr = a;
  sprot_items[sprot_item_count].mask = mask;
  sprot_items[sprot_item_count].val = val;
  sprot_items[sprot_item_count].readonly = is_ro;
  sprot_item_count++;
}

static void carthw_sprot_unload(void)
{
  free(sprot_items);
  sprot_items = NULL;
  sprot_item_count = sprot_item_alloc = 0;
}

static void carthw_sprot_mem_setup(void)
{
  int start;

  // map ROM - 0x7fffff, /TIME areas (which are tipically used)
  start = (Pico.romsize + M68K_BANK_MASK) & ~M68K_BANK_MASK;
  cpu68k_map_set(m68k_read8_map,   start, 0x7fffff, PicoRead8_sprot, 1);
  cpu68k_map_set(m68k_read16_map,  start, 0x7fffff, PicoRead16_sprot, 1);
  cpu68k_map_set(m68k_write8_map,  start, 0x7fffff, PicoWrite8_sprot, 1);
  cpu68k_map_set(m68k_write16_map, start, 0x7fffff, PicoWrite16_sprot, 1);

  cpu68k_map_set(m68k_read8_map,   0xa10000, 0xa1ffff, PicoRead8_sprot, 1);
  cpu68k_map_set(m68k_read16_map,  0xa10000, 0xa1ffff, PicoRead16_sprot, 1);
  cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, PicoWrite8_sprot, 1);
  cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, PicoWrite16_sprot, 1);
}

void carthw_sprot_startup(void)
{
  elprintf(EL_STATUS, "Prot emu startup");

  PicoCartMemSetup   = carthw_sprot_mem_setup;
  PicoCartUnloadHook = carthw_sprot_unload;
}

/* Protection emulation for Lion King 3. Credits go to Haze */
static u8 prot_lk3_cmd, prot_lk3_data;

static u32 PicoRead8_plk3(u32 a)
{
  u32 d = 0;
  switch (prot_lk3_cmd) {
    case 1: d = prot_lk3_data >> 1; break;
    case 2: // nibble rotate
      d = ((prot_lk3_data >> 4) | (prot_lk3_data << 4)) & 0xff;
      break;
    case 3: // bit rotate
      d = prot_lk3_data;
      d = (d >> 4) | (d << 4);
      d = ((d & 0xcc) >> 2) | ((d & 0x33) << 2);
      d = ((d & 0xaa) >> 1) | ((d & 0x55) << 1);
      break;
/* Top Fighter 2000 MK VIII (Unl)
      case 0x98: d = 0x50; break; // prot_lk3_data == a8 here
      case 0x67: d = 0xde; break; // prot_lk3_data == 7b here (rot!)
      case 0xb5: d = 0x9f; break; // prot_lk3_data == 4a
*/
    default:
      elprintf(EL_UIO, "unhandled prot cmd %02x @%06x", prot_lk3_cmd, SekPc);
      break;
  }

  elprintf(EL_UIO, "prot r8  [%06x]   %02x @%06x", a, d, SekPc);
  return d;
}

static void PicoWrite8_plk3p(u32 a, u32 d)
{
  elprintf(EL_UIO, "prot w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
  if (a & 2)
    prot_lk3_cmd = d;
  else
    prot_lk3_data = d;
}

static void PicoWrite8_plk3b(u32 a, u32 d)
{
  int addr;

  elprintf(EL_UIO, "prot w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
  addr = d << 15;
  if (addr + 0x8000 > Pico.romsize) {
    elprintf(EL_UIO|EL_ANOMALY, "prot_lk3: bank too large: %02x", d);
    return;
  }
  if (addr == 0)
    memcpy(Pico.rom, Pico.rom + Pico.romsize, 0x8000);
  else
    memcpy(Pico.rom, Pico.rom + addr, 0x8000);
}

static void carthw_prot_lk3_mem_setup(void)
{
  cpu68k_map_set(m68k_read8_map,   0x600000, 0x7fffff, PicoRead8_plk3, 1);
  cpu68k_map_set(m68k_write8_map,  0x600000, 0x6fffff, PicoWrite8_plk3p, 1);
  cpu68k_map_set(m68k_write8_map,  0x700000, 0x7fffff, PicoWrite8_plk3b, 1);
}

void carthw_prot_lk3_startup(void)
{
  int ret;

  elprintf(EL_STATUS, "lk3 prot emu startup");

  // allocate space for bank0 backup
  ret = PicoCartResize(Pico.romsize + 0x8000);
  if (ret != 0) {
    elprintf(EL_STATUS, "OOM");
    return;
  }
  memcpy(Pico.rom + Pico.romsize, Pico.rom, 0x8000);

  PicoCartMemSetup = carthw_prot_lk3_mem_setup;
}

