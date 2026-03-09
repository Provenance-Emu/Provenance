/*
 * Support for a few cart mappers and some protection.
 * (C) notaz, 2008-2011
 * (C) irixxxx, 2021-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "../pico_int.h"
#include "../memory.h"
#include "eeprom_spi.h"


static int have_bank(u32 base)
{
  // the loader allocs in 512K quantities
  if (base >= Pico.romsize) {
    elprintf(EL_ANOMALY|EL_STATUS, "carthw: missing bank @ %06x", base);
    return 0;
  }
  return 1;
}

/* standard/ssf2 mapper */
int carthw_ssf2_active;
unsigned char carthw_ssf2_banks[8];

static carthw_state_chunk carthw_ssf2_state[] =
{
  { CHUNK_CARTHW, sizeof(carthw_ssf2_banks), &carthw_ssf2_banks },
  { 0,            0,                         NULL }
};

void carthw_ssf2_write8(u32 a, u32 d)
{
  u32 target, base;

  if ((a & ~0x0e) != 0xa130f1 || a == 0xa130f1) {
    PicoWrite8_io(a, d);
    return;
  }

  a &= 0x0e;
  if (a == 0)
    return;
  if (carthw_ssf2_banks[a >> 1] == d)
    return;

  base = d << 19;
  target = a << 18;
  if (!have_bank(base))
    return;
  carthw_ssf2_banks[a >> 1] = d;

  cpu68k_map_set(m68k_read8_map,  target, target + 0x80000 - 1, Pico.rom + base, 0);
  cpu68k_map_set(m68k_read16_map, target, target + 0x80000 - 1, Pico.rom + base, 0);
}

void carthw_ssf2_write16(u32 a, u32 d)
{
  PicoWrite16_io(a, d);
  if ((a & ~0x0f) == 0xa130f0)
    carthw_ssf2_write8(a + 1, d);
}

static void carthw_ssf2_mem_setup(void)
{
  cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, carthw_ssf2_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, carthw_ssf2_write16, 1);
}

static void carthw_ssf2_statef(void)
{
  int i, reg;
  for (i = 1; i < 8; i++) {
    reg = carthw_ssf2_banks[i];
    carthw_ssf2_banks[i] = i;
    carthw_ssf2_write8(0xa130f1 | (i << 1), reg);
  }
}

static void carthw_ssf2_unload(void)
{
  memset(carthw_ssf2_banks, 0, sizeof(carthw_ssf2_banks));
  carthw_ssf2_active = 0;
}

void carthw_ssf2_startup(void)
{
  int i;

  elprintf(EL_STATUS, "SSF2 mapper startup");

  // default map
  for (i = 0; i < 8; i++)
    carthw_ssf2_banks[i] = i;

  PicoCartMemSetup   = carthw_ssf2_mem_setup;
  PicoLoadStateHook  = carthw_ssf2_statef;
  PicoCartUnloadHook = carthw_ssf2_unload;
  carthw_chunks      = carthw_ssf2_state;
  carthw_ssf2_active = 1;
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

// TODO: reads should also work, but then we need to handle open bus
static void carthw_Xin1_write8(u32 a, u32 d)
{
	if ((a & 0xffff00) != 0xa13000) {
		PicoWrite8_io(a, d);
		return;
	}

	carthw_Xin1_do(a, 0x3e, 16);
}

static void carthw_Xin1_write16(u32 a, u32 d)
{
  if ((a & 0xffff00) != 0xa13000) {
    PicoWrite16_io(a, d);
    return;
  }

  carthw_Xin1_write8(a + 1, d);
}

static void carthw_Xin1_mem_setup(void)
{
	cpu68k_map_set(m68k_write8_map,  0xa10000, 0xa1ffff, carthw_Xin1_write8, 1);
	cpu68k_map_set(m68k_write16_map, 0xa10000, 0xa1ffff, carthw_Xin1_write16, 1);
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
  { CHUNK_CARTHW + 2, 0,                      NULL }, // filled later
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
      Pico.sv.changed = 1;
      eeprom_spi_write(d);
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
  if (!have_bank(base))
    return;

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
    return eeprom_spi_read(a);

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

  return Pico.rom[MEM_BE2(a & 0x7fff)];
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
  carthw_pier_statef();
  eeprom_spi_init(NULL);
}

void carthw_pier_startup(void)
{
  void *eeprom_state;
  int eeprom_size = 0;
  int i;

  elprintf(EL_STATUS, "Pier Solar mapper startup");

  // mostly same as for realtec..
  i = PicoCartResize(Pico.romsize + M68K_BANK_SIZE);
  if (i != 0) {
    elprintf(EL_STATUS, "OOM");
    return;
  }

  pier_dump_prot = 3;

  // create dump protection bank
  for (i = 0; i < M68K_BANK_SIZE; i += 0x8000)
    memcpy(Pico.rom + Pico.romsize + i, Pico.rom, 0x8000);

  // save EEPROM
  eeprom_state = eeprom_spi_init(&eeprom_size);
  Pico.sv.flags = 0;
  Pico.sv.size = 0x10000;
  Pico.sv.data = calloc(1, Pico.sv.size);
  if (!Pico.sv.data)
    Pico.sv.size = 0;
  carthw_pier_state[2].ptr = eeprom_state;
  carthw_pier_state[2].size = eeprom_size;

  PicoCartMemSetup  = carthw_pier_mem_setup;
  PicoResetHook     = carthw_pier_reset;
  PicoLoadStateHook = carthw_pier_statef;
  carthw_chunks     = carthw_pier_state;
}

/* superfighter mappers, see mame: mame/src/devices/bus/megadrive/rom.cpp */
unsigned int carthw_sf00x_reg;

static carthw_state_chunk carthw_sf00x_state[] =
{
	{ CHUNK_CARTHW, sizeof(carthw_sf00x_reg), &carthw_sf00x_reg },
	{ 0,            0,                         NULL }
};

// SF-001

// additionally map SRAM at 0x3c0000 for the newer version of sf001
static u32 carthw_sf001_read8_sram(u32 a)
{
  return m68k_read8((a & 0xffff) + Pico.sv.start);
}

static u32 carthw_sf001_read16_sram(u32 a)
{
  return m68k_read16((a & 0xffff) + Pico.sv.start);
}

static void carthw_sf001_write8_sram(u32 a, u32 d)
{
  m68k_write8((a & 0xffff) + Pico.sv.start, d);
}

static void carthw_sf001_write16_sram(u32 a, u32 d)
{
  m68k_write16((a & 0xffff) + Pico.sv.start, d);
}

static void carthw_sf001_write8(u32 a, u32 d)
{
  if ((a & 0xf00) != 0xe00 || (carthw_sf00x_reg & 0x20)) // wrong addr / locked
    return;

  if (d & 0x80) {
    // bank 0xe at addr 0x000000
    cpu68k_map_set(m68k_read8_map,  0x000000, 0x040000-1, Pico.rom+0x380000, 0);
    cpu68k_map_set(m68k_read16_map, 0x000000, 0x040000-1, Pico.rom+0x380000, 0);
    // SRAM also at 0x3c0000 for newer mapper version
    cpu68k_map_set(m68k_read8_map,  0x3c0000, 0x400000-1, carthw_sf001_read8_sram, 1);
    cpu68k_map_set(m68k_read16_map, 0x3c0000, 0x400000-1, carthw_sf001_read16_sram, 1);
    cpu68k_map_set(m68k_write8_map, 0x3c0000, 0x400000-1, carthw_sf001_write8_sram, 1);
    cpu68k_map_set(m68k_write16_map,0x3c0000, 0x400000-1, carthw_sf001_write16_sram, 1);
  } else {
    // bank 0x0 at addr 0x000000
    cpu68k_map_set(m68k_read8_map,  0x000000, 0x040000-1, Pico.rom, 0);
    cpu68k_map_set(m68k_read16_map, 0x000000, 0x040000-1, Pico.rom, 0);
    // SRAM off, bank 0xf at addr 0x3c0000
    cpu68k_map_set(m68k_read8_map,  0x3c0000, 0x400000-1, Pico.rom+0x3c0000, 0);
    cpu68k_map_set(m68k_read16_map, 0x3c0000, 0x400000-1, Pico.rom+0x3c0000, 0);
    cpu68k_map_set(m68k_write8_map, 0x3c0000, 0x400000-1, Pico.rom+0x3c0000, 0);
    cpu68k_map_set(m68k_write16_map,0x3c0000, 0x400000-1, Pico.rom+0x3c0000, 0);
  }
  carthw_sf00x_reg = d;
}

static void carthw_sf001_write16(u32 a, u32 d)
{
  carthw_sf001_write8(a + 1, d);
}

static void carthw_sf001_mem_setup(void)
{
  // writing to low cartridge addresses
  cpu68k_map_set(m68k_write8_map,  0x000000, 0x00ffff, carthw_sf001_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0x000000, 0x00ffff, carthw_sf001_write16, 1);
}

static void carthw_sf001_reset(void)
{
  carthw_sf00x_reg = 0;
  carthw_sf001_write8(0x0e01, 0);
}

static void carthw_sf001_statef(void)
{
  int reg = carthw_sf00x_reg;
  carthw_sf00x_reg = 0;
  carthw_sf001_write8(0x0e01, reg);
}

void carthw_sf001_startup(void)
{
  PicoCartMemSetup  = carthw_sf001_mem_setup;
  PicoResetHook     = carthw_sf001_reset;
  PicoLoadStateHook = carthw_sf001_statef;
  carthw_chunks     = carthw_sf00x_state;
}

// SF-002

static void carthw_sf002_write8(u32 a, u32 d)
{
  if ((a & 0xf00) != 0xe00)
    return;

  if (d & 0x80) {
    // bank 0x00-0x0e on addr 0x20000
    cpu68k_map_set(m68k_read8_map,  0x200000, 0x3c0000-1, Pico.rom, 0);
    cpu68k_map_set(m68k_read16_map, 0x200000, 0x3c0000-1, Pico.rom, 0);
  } else {
    // bank 0x10-0x1e on addr 0x20000
    cpu68k_map_set(m68k_read8_map,  0x200000, 0x3c0000-1, Pico.rom+0x200000, 0);
    cpu68k_map_set(m68k_read16_map, 0x200000, 0x3c0000-1, Pico.rom+0x200000, 0);
  }
  carthw_sf00x_reg = d;
}

static void carthw_sf002_write16(u32 a, u32 d)
{
  carthw_sf002_write8(a + 1, d);
}

static void carthw_sf002_mem_setup(void)
{
  // writing to low cartridge addresses
  cpu68k_map_set(m68k_write8_map,  0x000000, 0x00ffff, carthw_sf002_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0x000000, 0x00ffff, carthw_sf002_write16, 1);
}

static void carthw_sf002_reset(void)
{
  carthw_sf002_write8(0x0e01, 0);
}

static void carthw_sf002_statef(void)
{
  carthw_sf002_write8(0x0e01, carthw_sf00x_reg);
}

void carthw_sf002_startup(void)
{
  PicoCartMemSetup  = carthw_sf002_mem_setup;
  PicoResetHook     = carthw_sf002_reset;
  PicoLoadStateHook = carthw_sf002_statef;
  carthw_chunks     = carthw_sf00x_state;
}

// SF-004

// reading from cartridge I/O region returns the current bank index
static u32 carthw_sf004_read8(u32 a)
{
  if ((a & ~0xff) == 0xa13000)
    return carthw_sf00x_reg & 0xf0; // bank index
  return PicoRead8_io(a);
}

static u32 carthw_sf004_read16(u32 a)
{
  if ((a & ~0xff) == 0xa13000)
    return carthw_sf00x_reg & 0xf0;
  return PicoRead16_io(a);
}

// writing to low cartridge adresses changes mappings
static void carthw_sf004_write8(u32 a, u32 d)
{
  int idx, i;
  unsigned bs = 0x40000; // bank size

  // there are 3 byte-sized regs, stored together in carthw_sf00x_reg
  if (!(carthw_sf00x_reg & 0x8000))
    return; // locked

  switch (a & 0xf00) {
  case 0xd00:
    carthw_sf00x_reg = (carthw_sf00x_reg & ~0xff0000) | ((d & 0xff) << 16);
    return PicoWrite8_io(0xa130f1, (d & 0x80) ? SRR_MAPPED : 0); // SRAM mapping
  case 0xe00:
    carthw_sf00x_reg = (carthw_sf00x_reg & ~0x00ff00) | ((d & 0xff) << 8);
    break;
  case 0xf00:
    carthw_sf00x_reg = (carthw_sf00x_reg & ~0x0000ff) | ((d & 0xff) << 0);
    break;
  default:
    return; // wrong addr
  }

  // bank mapping changed
  idx = ((carthw_sf00x_reg>>4) & 0x7); // bank index
  if ((carthw_sf00x_reg>>8) & 0x40) {
    // linear bank mapping, starting at idx
    for (i = 0; i < 8; i++, idx = (idx+1) & 0x7) {
      cpu68k_map_set(m68k_read8_map,  i*bs, (i+1)*bs-1, Pico.rom + idx*bs, 0);
      cpu68k_map_set(m68k_read16_map, i*bs, (i+1)*bs-1, Pico.rom + idx*bs, 0);
    }
  } else {
    // single bank mapping
    for (i = 0; i < 8; i++) {
      cpu68k_map_set(m68k_read8_map,  i*bs, (i+1)*bs-1, Pico.rom + idx*bs, 0);
      cpu68k_map_set(m68k_read16_map, i*bs, (i+1)*bs-1, Pico.rom + idx*bs, 0);
    }
  }
}

static void carthw_sf004_write16(u32 a, u32 d)
{
  carthw_sf004_write8(a + 1, d);
}

static void carthw_sf004_mem_setup(void)
{
  // writing to low cartridge addresses
  cpu68k_map_set(m68k_write8_map,  0x000000, 0x00ffff, carthw_sf004_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0x000000, 0x00ffff, carthw_sf004_write16, 1);
  // reading from the cartridge I/O region
  cpu68k_map_set(m68k_read8_map,   0xa10000, 0xa1ffff, carthw_sf004_read8, 1);
  cpu68k_map_set(m68k_read16_map,  0xa10000, 0xa1ffff, carthw_sf004_read16, 1);
}

static void carthw_sf004_reset(void)
{
  carthw_sf00x_reg = -1;
  carthw_sf004_write8(0x0d01, 0);
  carthw_sf004_write8(0x0f01, 0);
  carthw_sf004_write8(0x0e01, 0x80);
}

static void carthw_sf004_statef(void)
{
  int reg = carthw_sf00x_reg;
  carthw_sf00x_reg = -1;
  carthw_sf004_write8(0x0d01, reg >> 16);
  carthw_sf004_write8(0x0f01, reg >> 0);
  carthw_sf004_write8(0x0e01, reg >> 8);
}

void carthw_sf004_startup(void)
{
  PicoCartMemSetup  = carthw_sf004_mem_setup;
  PicoResetHook     = carthw_sf004_reset;
  PicoLoadStateHook = carthw_sf004_statef;
  carthw_chunks     = carthw_sf00x_state;
}

/* Simple protection through reading flash ID */
static int flash_writecount;

static carthw_state_chunk carthw_flash_state[] =
{
  { CHUNK_CARTHW, sizeof(flash_writecount), &flash_writecount },
  { 0,            0,                        NULL }
};

static u32 PicoRead16_flash(u32 a) { return (a&6) ? 0x2257 : 0x0020; }

static void PicoWrite16_flash(u32 a, u32 d)
{
  int banksz = (1<<M68K_MEM_SHIFT)-1;
  switch (++flash_writecount) {
    case 3: cpu68k_map_set(m68k_read16_map, 0, banksz, PicoRead16_flash, 1);
            break;
    case 4: cpu68k_map_read_mem(0, banksz, Pico.rom, 0);
            flash_writecount = 0;
            break;
  }
}

static void carthw_flash_mem_setup(void)
{
  cpu68k_map_set(m68k_write16_map, 0, 0x7fffff, PicoWrite16_flash, 1);
}

void carthw_flash_startup(void)
{
  elprintf(EL_STATUS, "Flash prot emu startup");

  PicoCartMemSetup   = carthw_flash_mem_setup;
  carthw_chunks      = carthw_flash_state;
}

/* Simple unlicensed ROM protection emulation */
static struct {
  u32 addr;
  u32 mask;
  u16 val;
  u16 readonly;
} sprot_items[8];
static int sprot_item_count;

static carthw_state_chunk carthw_sprot_state[] =
{
  { CHUNK_CARTHW, sizeof(sprot_items), &sprot_items },
  { 0,            0,                         NULL }
};

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

  val = carthw_sprot_get_val(a, 0);
  if (val != NULL) {
    d = *val;
    if (!(a & 1))
      d >>= 8;
    elprintf(EL_UIO, "prot r8  [%06x]   %02x @%06x", a, d, SekPc);
    return d;
  }
  else if (0xa10000 <= a && a <= 0xa1ffff)
    return PicoRead8_io(a);

  elprintf(EL_UIO, "prot r8  [%06x] MISS @%06x", a, SekPc);
  return 0;
}

static u32 PicoRead16_sprot(u32 a)
{
  u16 *val;

  val = carthw_sprot_get_val(a, 0);
  if (val != NULL) {
    elprintf(EL_UIO, "prot r16 [%06x] %04x @%06x", a, *val, SekPc);
    return *val;
  }
  else if (0xa10000 <= a && a <= 0xa1ffff)
    return PicoRead16_io(a);

  elprintf(EL_UIO, "prot r16 [%06x] MISS @%06x", a, SekPc);
  return 0;
}

static void PicoWrite8_sprot(u32 a, u32 d)
{
  u16 *val;

  val = carthw_sprot_get_val(a, 1);
  if (val != NULL) {
    if (a & 1)
      *val = (*val & 0xff00) | (d | 0xff);
    else
      *val = (*val & 0x00ff) | (d << 8);
    elprintf(EL_UIO, "prot w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
  }
  else if (0xa10000 <= a && a <= 0xa1ffff)
    return PicoWrite8_io(a, d);

  elprintf(EL_UIO, "prot w8  [%06x]   %02x MISS @%06x", a, d & 0xff, SekPc);
}

static void PicoWrite16_sprot(u32 a, u32 d)
{
  u16 *val;

  val = carthw_sprot_get_val(a, 1);
  if (val != NULL) {
    *val = d;
    elprintf(EL_UIO, "prot w16 [%06x] %04x @%06x", a, d & 0xffff, SekPc);
  }
  else if (0xa10000 <= a && a <= 0xa1ffff)
    return PicoWrite16_io(a, d);

  elprintf(EL_UIO, "prot w16 [%06x] %04x MISS @%06x", a, d & 0xffff, SekPc);
}

void carthw_sprot_new_location(unsigned int a, unsigned int mask, unsigned short val, int is_ro)
{
  int sprot_elems = sizeof(sprot_items)/sizeof(sprot_items[0]);
  if (sprot_item_count == sprot_elems) {
    elprintf(EL_STATUS, "too many sprot items");
    return;
  }

  sprot_items[sprot_item_count].addr = a;
  sprot_items[sprot_item_count].mask = mask;
  sprot_items[sprot_item_count].val = val;
  sprot_items[sprot_item_count].readonly = is_ro;
  sprot_item_count++;
}

static void carthw_sprot_unload(void)
{
  sprot_item_count = 0;
}

static void carthw_sprot_mem_setup(void)
{
  int start;

  // map 0x400000 - 0x7fffff, /TIME areas (which are tipically used)
  start = (Pico.romsize + M68K_BANK_MASK) & ~M68K_BANK_MASK;
  if (start < 0x400000) start = 0x400000;

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
  carthw_chunks      = carthw_sprot_state;
}

/* Protection emulation for Lion King 3. Credits go to Haze */
static struct {
  u32 bank;
  u8 cmd, data;
} carthw_lk3_regs;

static carthw_state_chunk carthw_lk3_state[] =
{
  { CHUNK_CARTHW, sizeof(carthw_lk3_regs), &carthw_lk3_regs },
  { 0,            0,                         NULL }
};

static u8 *carthw_lk3_mem; // shadow copy memory
static u32 carthw_lk3_madr[0x100000/M68K_BANK_SIZE];

static u32 PicoRead8_plk3(u32 a)
{
  u32 d = 0;
  switch (carthw_lk3_regs.cmd) {
    case 0: d = carthw_lk3_regs.data << 1; break;
    case 1: d = carthw_lk3_regs.data >> 1; break;
    case 2: // nibble rotate
      d = ((carthw_lk3_regs.data >> 4) | (carthw_lk3_regs.data << 4)) & 0xff;
      break;
    case 3: // bit rotate
      d = carthw_lk3_regs.data;
      d = (d >> 4) | (d << 4);
      d = ((d & 0xcc) >> 2) | ((d & 0x33) << 2);
      d = ((d & 0xaa) >> 1) | ((d & 0x55) << 1);
      break;
    default:
      elprintf(EL_UIO, "unhandled prot cmd %02x @%06x", carthw_lk3_regs.cmd, SekPc);
      break;
  }

  elprintf(EL_UIO, "prot r8  [%06x]   %02x @%06x", a, d, SekPc);
  return d;
}

static void PicoWrite8_plk3p(u32 a, u32 d)
{
  elprintf(EL_UIO, "prot w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
  if (a & 2)
    carthw_lk3_regs.cmd = d & 0x3;
  else
    carthw_lk3_regs.data = d;
}

static void PicoWrite8_plk3b(u32 a, u32 d)
{
  u32 addr;

  elprintf(EL_UIO, "prot w8  [%06x]   %02x @%06x", a, d & 0xff, SekPc);
  addr = d << 15;
  if (addr+0x10000 >= Pico.romsize) {
    elprintf(EL_UIO|EL_ANOMALY, "lk3_mapper: bank too large: %02x", d);
    return;
  }

  if (addr != carthw_lk3_regs.bank) {
    // banking is by or'ing the bank address in the 1st megabyte, not adding.
    // only do linear mapping if map addresses aren't overlapping bank address
    u32 len = M68K_BANK_SIZE;
    u32 a, b;
    for (b = 0x000000; b < 0x0100000; b += len) {
      if (!((b + (len-1)) & addr)) {
        cpu68k_map_set(m68k_read8_map,  b, b + (len-1), Pico.rom+addr + b, 0);
        cpu68k_map_set(m68k_read16_map, b, b + (len-1), Pico.rom+addr + b, 0);
      } else {
        // overlap. ugh, need a shadow copy since banks can contain code and
        // 68K cpu emulator cores need mapped access to code memory
        if (carthw_lk3_madr[b/len] != addr) // only if shadow isn't the same
          for (a = b; a < b+M68K_BANK_SIZE; a += 0x8000)
            memcpy(carthw_lk3_mem + a, Pico.rom + (addr|a), 0x8000);
        carthw_lk3_madr[b/len] = addr;
        cpu68k_map_set(m68k_read8_map,  b, b + (len-1), carthw_lk3_mem + b, 0);
        cpu68k_map_set(m68k_read16_map, b, b + (len-1), carthw_lk3_mem + b, 0);
      }
    }
  }
  carthw_lk3_regs.bank = addr;
}

static void carthw_lk3_mem_setup(void)
{
  cpu68k_map_set(m68k_read8_map,   0x600000, 0x7fffff, PicoRead8_plk3, 1);
  cpu68k_map_set(m68k_write8_map,  0x600000, 0x6fffff, PicoWrite8_plk3p, 1);
  cpu68k_map_set(m68k_write8_map,  0x700000, 0x7fffff, PicoWrite8_plk3b, 1);
  carthw_lk3_regs.bank = 0;
}

static void carthw_lk3_statef(void)
{
  PicoWrite8_plk3b(0x700000, carthw_lk3_regs.bank >> 15);
}

static void carthw_lk3_unload(void)
{
  free(carthw_lk3_mem);
  carthw_lk3_mem = NULL;
  memset(carthw_lk3_madr, 0, sizeof(carthw_lk3_madr));
}

void carthw_lk3_startup(void)
{
  elprintf(EL_STATUS, "lk3 prot emu startup");

  // allocate space for shadow copy
  if (carthw_lk3_mem == NULL)
    carthw_lk3_mem = malloc(0x100000);
  if (carthw_lk3_mem == NULL) {
    elprintf(EL_STATUS, "OOM");
    return;
  }

  PicoCartMemSetup   = carthw_lk3_mem_setup;
  PicoLoadStateHook  = carthw_lk3_statef;
  PicoCartUnloadHook = carthw_lk3_unload;
  carthw_chunks      = carthw_lk3_state;
}

/* SMW64 mapper, based on mame source */
static struct {
  u32 bank60, bank61;
  u16 data[8], ctrl[4];
} carthw_smw64_regs;

static carthw_state_chunk carthw_smw64_state[] =
{
  { CHUNK_CARTHW, sizeof(carthw_smw64_regs), &carthw_smw64_regs },
  { 0,            0,                         NULL }
};

static u32 PicoRead8_smw64(u32 a)
{
  u16 *data = carthw_smw64_regs.data, *ctrl = carthw_smw64_regs.ctrl;
  u32 d = 0;

  if (a & 1) {
    if (a>>16 == 0x66) switch ((a>>1) & 7) {
      case 0: d = carthw_smw64_regs.data[0]  ; break;
      case 1: d = carthw_smw64_regs.data[0]+1; break;
      case 2: d = carthw_smw64_regs.data[1]  ; break;
      case 3: d = carthw_smw64_regs.data[1]+1; break;
      case 4: d = carthw_smw64_regs.data[2]  ; break;
      case 5: d = carthw_smw64_regs.data[2]+1; break;
      case 6: d = carthw_smw64_regs.data[2]+2; break;
      case 7: d = carthw_smw64_regs.data[2]+3; break;
    } else /*0x67*/ { // :-O
      if (ctrl[1] & 0x80)
        d = ctrl[2] & 0x40 ? data[4]&data[5] : data[4]^0xff;
      if (a & 2)
        d &= 0x7f;
      else if (ctrl[2] & 0x80) {
        if (ctrl[2] & 0x20)
          data[2] = (data[5] << 2) & 0xfc;
        else
          data[0] = ((data[4] << 1) ^ data[3]) & 0xfe;
      }
    }
  }

  elprintf(EL_UIO, "prot r8  [%06x]   %02x @%06x", a, d, SekPc);
  return d;
}

static u32 PicoRead16_smw64(u32 a)
{
  return PicoRead8_smw64(a+1);
}

static void PicoWrite8_smw64(u32 a, u32 d)
{
  u16 *data = carthw_smw64_regs.data, *ctrl = carthw_smw64_regs.ctrl;

  if ((a & 3) == 1) {
    switch (a >> 16) {
    case 0x60: ctrl[0] = d; break;
    case 0x64: data[4] = d; break;
    case 0x67:
      if (ctrl[1] & 0x80) {
        carthw_smw64_regs.bank60 = 0x80000 + ((d<<14) & 0x70000);
        cpu68k_map_set(m68k_read8_map,  0x600000, 0x60ffff, Pico.rom + carthw_smw64_regs.bank60, 0);
        cpu68k_map_set(m68k_read16_map, 0x600000, 0x60ffff, Pico.rom + carthw_smw64_regs.bank60, 0);
      }
      ctrl[2] = d;
    }
  } else if ((a & 3) == 3) {
    switch (a >> 16) {
    case 0x61: ctrl[1] = d; break;
    case 0x64: data[5] = d; break;
    case 0x60:
      switch (ctrl[0] & 7) { // :-O
      case 0: data[0] = (data[0]^data[3] ^ d) & 0xfe; break;
      case 1: data[1] = (                  d) & 0xfe; break;
      case 7:
        carthw_smw64_regs.bank61 = 0x80000 + ((d<<14) & 0x70000);
        cpu68k_map_set(m68k_read8_map,  0x610000, 0x61ffff, Pico.rom + carthw_smw64_regs.bank61, 0);
        cpu68k_map_set(m68k_read16_map, 0x610000, 0x61ffff, Pico.rom + carthw_smw64_regs.bank61, 0);
        break;
      }
      data[3] = d;
    }
  }
}

static void PicoWrite16_smw64(u32 a, u32 d)
{
  PicoWrite8_smw64(a+1, d);
}

static void carthw_smw64_mem_setup(void)
{
  // 1st 512 KB mirrored
  cpu68k_map_set(m68k_read8_map,   0x080000, 0x0fffff, Pico.rom, 0);
  cpu68k_map_set(m68k_read16_map,  0x080000, 0x0fffff, Pico.rom, 0);

  cpu68k_map_set(m68k_read8_map,   0x660000, 0x67ffff, PicoRead8_smw64, 1);
  cpu68k_map_set(m68k_read16_map,  0x660000, 0x67ffff, PicoRead16_smw64, 1);
  cpu68k_map_set(m68k_write8_map,  0x600000, 0x67ffff, PicoWrite8_smw64, 1);
  cpu68k_map_set(m68k_write16_map, 0x600000, 0x67ffff, PicoWrite16_smw64, 1);
}

static void carthw_smw64_statef(void)
{
  cpu68k_map_set(m68k_read8_map,   0x600000, 0x60ffff, Pico.rom + carthw_smw64_regs.bank60, 0);
  cpu68k_map_set(m68k_read16_map,  0x600000, 0x60ffff, Pico.rom + carthw_smw64_regs.bank60, 0);
  cpu68k_map_set(m68k_read8_map,   0x610000, 0x61ffff, Pico.rom + carthw_smw64_regs.bank61, 0);
  cpu68k_map_set(m68k_read16_map,  0x610000, 0x61ffff, Pico.rom + carthw_smw64_regs.bank61, 0);
}

static void carthw_smw64_reset(void)
{
  memset(&carthw_smw64_regs, 0, sizeof(carthw_smw64_regs));
}

void carthw_smw64_startup(void)
{
  elprintf(EL_STATUS, "SMW64 mapper startup");

  PicoCartMemSetup  = carthw_smw64_mem_setup;
  PicoResetHook     = carthw_smw64_reset;
  PicoLoadStateHook = carthw_smw64_statef;
  carthw_chunks     = carthw_smw64_state;
}

/* J-Cart */
unsigned char carthw_jcart_th;

static carthw_state_chunk carthw_jcart_state[] =
{
  { CHUNK_CARTHW, sizeof(carthw_jcart_th), &carthw_jcart_th },
  { 0,            0,                       NULL }
};

static void carthw_jcart_write8(u32 a, u32 d)
{
  carthw_jcart_th = (d&1) << 6;
}

static void carthw_jcart_write16(u32 a, u32 d)
{
  carthw_jcart_write8(a+1, d);
}

static u32 carthw_jcart_read8(u32 a)
{
  u32 v = PicoReadPad(2 + (a&1), 0x3f | carthw_jcart_th);
  // some carts additionally have an EEPROM; SDA is also readable in this range
  if (Pico.m.sram_reg & SRR_MAPPED)
    v |= EEPROM_read() & 0x80; // SDA is always on bit 7 for J-Carts
  return v;
}

static u32 carthw_jcart_read16(u32 a)
{
  return carthw_jcart_read8(a) | (carthw_jcart_read8(a+1) << 8);
}

static void carthw_jcart_mem_setup(void)
{
  cpu68k_map_set(m68k_write8_map,  0x380000, 0x3fffff, carthw_jcart_write8, 1);
  cpu68k_map_set(m68k_write16_map, 0x380000, 0x3fffff, carthw_jcart_write16, 1);
  cpu68k_map_set(m68k_read8_map,  0x380000, 0x3fffff, carthw_jcart_read8, 1);
  cpu68k_map_set(m68k_read16_map, 0x380000, 0x3fffff, carthw_jcart_read16, 1);
}

void carthw_jcart_startup(void)
{
  elprintf(EL_STATUS, "J-Cart startup");

  PicoCartMemSetup  = carthw_jcart_mem_setup;
  carthw_chunks     = carthw_jcart_state;
}

// vim:ts=2:sw=2:expandtab
