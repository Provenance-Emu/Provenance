/***************************************************************************************
 *  Genesis Plus
 *  Backup RAM support
 *
 *  Copyright (C) 2007-2020  Eke-Eke (Genesis Plus GX)
 *
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************************/

#include "shared.h"

T_SRAM sram;

/****************************************************************************
 * A quick guide to external RAM on the Genesis
 *
 * The external RAM definition is held at offset 0x1b0 of the ROM header.
 *
 *  1B0h:   dc.b   'RA', %1x1yz000, %abc00000
 *  1B4h:   dc.l   RAM start address
 *  1B8h:   dc.l   RAM end address
 *   x 1 for BACKUP (not volatile), 0 for volatile RAM
 *   yz 10 if even address only 
 *      11 if odd address only 
 *      00 if both even and odd address
 *      01 others (serial EEPROM, RAM with 4-bit data bus, etc)
 *   abc 001 if SRAM
 *       010 if EEPROM (serial or parallel)
 *       other values unused
 *
 * Assuming max. 64k backup RAM throughout
 ****************************************************************************/
void sram_init()
{
  memset(&sram, 0, sizeof (T_SRAM));

  /* backup RAM data is stored above cartridge ROM area, at $800000-$80FFFF (max. 64K) */
  if (cart.romsize > 0x800000) return;
  sram.sram = cart.rom + 0x800000;

  /* initialize Backup RAM */
  if (strstr(rominfo.international,"Sonic 1 Remastered"))
  {
    /* Sonic 1 Remastered hack crashes if backup RAM is not initialized to zero */
    memset(sram.sram, 0x00, 0x10000);
  }
  else
  {
    /* by default, assume backup RAM is initialized to 0xFF (Micro Machines 2, Dino Dini Soccer)  */
    memset(sram.sram, 0xFF, 0x10000);
  }

  sram.crc = crc32(0, sram.sram, 0x10000);

  /* retrieve informations from header */
  if ((READ_BYTE(cart.rom,0x1b0) == 0x52) && (READ_BYTE(cart.rom,0x1b1) == 0x41))
  {
    /* backup RAM detected */
    sram.detected = 1;

    /* enable backup RAM */
    sram.on = 1;

    /* retrieve backup RAM start & end addresses */
    sram.start = READ_WORD_LONG(cart.rom, 0x1b4);
    sram.end   = READ_WORD_LONG(cart.rom, 0x1b8);

    /* autodetect games with wrong header infos */
    if (strstr(rominfo.product,"T-26013") != NULL)
    {
      /* Psy-O-Blade (wrong header) */
      sram.start = 0x200001;
      sram.end = 0x203fff;
    }

    /* fixe games indicating internal RAM as volatile external RAM (Feng Kuang Tao Hua Yuan) */
    else if (sram.start == 0xff0000)
    {
      /* backup RAM should be disabled */
      sram.on = 0;
    }

    /* fixe other bad header informations */
    else if ((sram.start > sram.end) || ((sram.end - sram.start) >= 0x10000))
    {
      sram.end = sram.start + 0xffff;
    }
  }
  else
  {
    /* autodetect games with missing header infos */
    if (strstr(rominfo.product,"T-50086") != NULL)
    {
      /* PGA Tour Golf */
      sram.on = 1;
      sram.start = 0x200001;
      sram.end = 0x203fff;
    }
    else if (strstr(rominfo.product,"ACLD007") != NULL)
    {
      /* Winter Challenge */
      sram.on = 1;
      sram.start = 0x200001;
      sram.end = 0x200fff;
    }
    else if (strstr(rominfo.product,"T-50286") != NULL)
    {
      /* Buck Rogers - Countdown to Doomsday */
      sram.on = 1;
      sram.start = 0x200001;
      sram.end = 0x203fff;
    }
    else if (((rominfo.realchecksum == 0xaeaa) || (rominfo.realchecksum == 0x8dba)) && 
             (rominfo.checksum ==  0x8104))
    {
      /* Xin Qigai Wangzi (use uncommon area) */
      sram.on = 1;
      sram.start = 0x400001;
      sram.end = 0x40ffff;
    }
    else if ((rominfo.checksum == 0x0000) && (rominfo.realchecksum == 0x1f7f) && (READ_BYTE(cart.rom + 0x80000,0x1b0) == 0x52) && (READ_BYTE(cart.rom + 0x80000,0x1b1) == 0x41))
    {
      /* Radica - Sensible Soccer Plus edition (use bankswitching) */
      sram.on = 1;
      sram.start = 0x200001;
      sram.end = 0x203fff;
    }
    else if ((strstr(rominfo.ROMType,"SF") != NULL) && (strstr(rominfo.product,"001") != NULL))
    {
      /* SF-001 */
      sram.on = 1;
      if (rominfo.checksum == 0x3e08)
      {
        /* last revision (use bankswitching) */
        sram.start = 0x3c0001;
        sram.end = 0x3cffff;
      }
      else
      {
        /* older revisions (use uncommon area) */
        sram.start = 0x400001;
        sram.end = 0x40ffff;
      }
    }
    else if ((strstr(rominfo.ROMType,"SF") != NULL) && (strstr(rominfo.product,"004") != NULL))
    {
      /* SF-004 (use bankswitching) */
      sram.on = 1;
      sram.start = 0x200001;
      sram.end = 0x203fff;
    }
    else if (strstr(rominfo.international,"SONIC & KNUCKLES") != NULL)
    {
      /* Sonic 3 & Knuckles combined ROM */
      if (cart.romsize == 0x400000)
      {
        /* Sonic & Knuckle does not have backup RAM but can access FRAM from Sonic 3 cartridge */
        sram.on = 1;
        sram.start = 0x200001;
        sram.end = 0x203fff;
      }
    }

    /* auto-detect games which need disabled backup RAM */
    else if (strstr(rominfo.product,"T-113016") != NULL)
    {
      /* Pugsy (does not have backup RAM but tries writing outside ROM area as copy protection) */
      sram.on = 0;
    }
    else if (strstr(rominfo.international,"SONIC THE HEDGEHOG 2") != NULL)
    {
      /* Sonic the Hedgehog 2 (does not have backup RAM) */
      /* this prevents backup RAM from being mapped in place of mirrored ROM when using S&K LOCK-ON feature */
      sram.on = 0;
    }

    /* by default, enable backup RAM for ROM smaller than 2MB */
    else if (cart.romsize <= 0x200000)
    {
      /* 64KB static RAM mapped to $200000-$20ffff */
      sram.start = 0x200000;
      sram.end = 0x20ffff;
      sram.on = 1;
    }
  }
}

unsigned int sram_read_byte(unsigned int address)
{
  return sram.sram[address & 0xffff];
}

unsigned int sram_read_word(unsigned int address)
{
  return READ_WORD(sram.sram, address & 0xfffe);
}

void sram_write_byte(unsigned int address, unsigned int data)
{
  sram.sram[address & 0xffff] = data;
}

void sram_write_word(unsigned int address, unsigned int data)
{
  WRITE_WORD(sram.sram, address & 0xfffe, data);
}
