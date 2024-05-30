/*
   basic, incomplete SSP160x (SSP1601?) interpreter
   with SVP memory controller emu

   (c) Copyright 2008, Grazvydas "notaz" Ignotas
   Free for non-commercial use.

   For commercial use, separate licencing terms must be obtained.

   Modified for Genesis Plus GX (Eke-Eke): added BIG ENDIAN support, fixed addr/code inversion
*/

#include "shared.h"

svp_t *svp;

static void svp_write_dram(uint32 address, uint32 data)
{
  *(uint16 *)(svp->dram + (address & 0x1fffe)) = data;
  if (data)
  {
    if (address == 0x30fe06) svp->ssp1601.emu_status &= ~SSP_WAIT_30FE06;
    else if (address == 0x30fe08) svp->ssp1601.emu_status &= ~SSP_WAIT_30FE08;
  }
}

static uint32 svp_read_cell_1(uint32 address)
{
  address = (address & 0xe002) | ((address & 0x7c) << 6) | ((address & 0x1f80) >> 5);
  return *(uint16 *)(svp->dram + address);
}

static uint32 svp_read_cell_2(uint32 address)
{
  address = (address & 0xf002) | ((address & 0x3c) << 6) | ((address & 0xfc0) >> 4);
  return *(uint16 *)(svp->dram + address);
}

static uint32 svp_read_cell_byte(uint32 address)
{
  uint16 data = m68k.memory_map[address >> 16].read16(address);

  if (address & 0x01)
  {
    return (data & 0xff);
  }

  return (data >> 8);
}

void svp_init(void)
{
  svp = (void *) ((char *)cart.rom + 0x200000);
  memset(svp, 0, sizeof(*svp));

  m68k.memory_map[0x30].base    = svp->dram;
  m68k.memory_map[0x30].read8   = NULL;
  m68k.memory_map[0x30].read16  = NULL;
  m68k.memory_map[0x30].write8  = NULL;
  m68k.memory_map[0x30].write16 = svp_write_dram;
  zbank_memory_map[0x30].read   = NULL;
  zbank_memory_map[0x30].write  = NULL;

  m68k.memory_map[0x31].base    = svp->dram + 0x10000;
  m68k.memory_map[0x31].read8   = NULL;
  m68k.memory_map[0x31].read16  = NULL;
  m68k.memory_map[0x31].write8  = NULL;
  m68k.memory_map[0x31].write16 = NULL;
  zbank_memory_map[0x31].read   = NULL;
  zbank_memory_map[0x31].write  = NULL;

  m68k.memory_map[0x39].read8   = svp_read_cell_byte;
  m68k.memory_map[0x39].read16  = svp_read_cell_1;
  zbank_memory_map[0x39].read   = svp_read_cell_byte;
  m68k.memory_map[0x3a].read8   = svp_read_cell_byte;
  m68k.memory_map[0x3a].read16  = svp_read_cell_2;
  zbank_memory_map[0x3a].read   = svp_read_cell_byte;
}

void svp_reset(void)
{
  memcpy(svp->iram_rom + 0x800, cart.rom + 0x800, 0x20000 - 0x800);
  ssp1601_reset(&svp->ssp1601);
}

