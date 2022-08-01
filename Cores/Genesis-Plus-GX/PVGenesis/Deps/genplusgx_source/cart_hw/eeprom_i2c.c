/****************************************************************************
 *  Genesis Plus
 *  I2C serial EEPROM (24Cxx) boards
 *
 *  Copyright (C) 2007-2016  Eke-Eke (Genesis Plus GX)
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
#include "gamepad.h"

/* Some notes from 8BitWizard (http://gendev.spritesmind.net/forum/viewtopic.php?t=206):
 *
 * Mode 1 (7-bit) - the chip takes a single byte with a 7-bit memory address and a R/W bit (X24C01)
 * Mode 2 (8-bit) - the chip takes a 7-bit device address and R/W bit followed by an 8-bit memory address;
 * the device address may contain up to three more memory address bits (24C01 - 24C16).
 * You can also string eight 24C01, four 24C02, two 24C08, or various combinations, set their address config lines correctly,
 * and the result appears exactly the same as a 24C16
 * Mode 3 (16-bit) - the chip takes a 7-bit device address and R/W bit followed by a 16-bit memory address (24C32 and larger)
 *
 */

typedef enum
{
  STAND_BY = 0,
  WAIT_STOP,
  GET_DEVICE_ADR,
  GET_WORD_ADR_7BITS,
  GET_WORD_ADR_HIGH,
  GET_WORD_ADR_LOW,
  WRITE_DATA,
  READ_DATA
} T_I2C_STATE;

typedef enum
{
  NO_EEPROM = -1,
  EEPROM_X24C01,
  EEPROM_X24C02,
  EEPROM_24C01,
  EEPROM_24C02,
  EEPROM_24C04,
  EEPROM_24C08,
  EEPROM_24C16,
  EEPROM_24C32,
  EEPROM_24C64,
  EEPROM_24C65,
  EEPROM_24C128,
  EEPROM_24C256,
  EEPROM_24C512
} T_I2C_TYPE;

typedef struct
{
  uint8 address_bits;
  uint16 size_mask;
  uint16 pagewrite_mask;
} T_I2C_SPEC;

static const T_I2C_SPEC i2c_specs[] =
{
  { 7 , 0x7F   , 0x03},
  { 8 , 0xFF   , 0x03},
  { 8 , 0x7F   , 0x07},
  { 8 , 0xFF   , 0x07},
  { 8 , 0x1FF  , 0x0F},
  { 8 , 0x3FF  , 0x0F},
  { 8 , 0x7FF  , 0x0F},
  {16 , 0xFFF  , 0x1F},
  {16 , 0x1FFF , 0x1F},
  {16 , 0x1FFF , 0x3F},
  {16 , 0x3FFF , 0x3F},
  {16 , 0x7FFF , 0x3F},
  {16 , 0xFFFF , 0x7F}
};

typedef struct
{
  char id[16];
  uint32 sp;
  uint16 chk;
  void (*mapper_init)(void);
  T_I2C_TYPE eeprom_type;
} T_I2C_GAME;

static void mapper_i2c_ea_init(void);
static void mapper_i2c_sega_init(void);
static void mapper_i2c_acclaim_16M_init(void);
static void mapper_i2c_acclaim_32M_init(void);
static void mapper_i2c_jcart_init(void);

static const T_I2C_GAME i2c_database[] = 
{
  {"T-50176"  , 0          , 0      , mapper_i2c_ea_init          , EEPROM_X24C01 }, /* Rings of Power */
  {"T-50396"  , 0          , 0      , mapper_i2c_ea_init          , EEPROM_X24C01 }, /* NHLPA Hockey 93 */
  {"T-50446"  , 0          , 0      , mapper_i2c_ea_init          , EEPROM_X24C01 }, /* John Madden Football 93 */
  {"T-50516"  , 0          , 0      , mapper_i2c_ea_init          , EEPROM_X24C01 }, /* John Madden Football 93 (Championship Ed.) */
  {"T-50606"  , 0          , 0      , mapper_i2c_ea_init          , EEPROM_X24C01 }, /* Bill Walsh College Football (warning: invalid SRAM header !) */
  {" T-12046" , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Megaman - The Wily Wars (warning: SRAM hack exists !) */
  {" T-12053" , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Rockman Mega World (warning: SRAM hack exists !) */
  {"MK-1215"  , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Evander 'Real Deal' Holyfield's Boxing */
  {"MK-1228"  , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Greatest Heavyweights of the Ring (U)(E) */
  {"G-5538"   , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Greatest Heavyweights of the Ring (J) */
  {"PR-1993"  , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Greatest Heavyweights of the Ring (Prototype) */
  {" G-4060"  , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Wonderboy in Monster World (warning: SRAM hack exists !) */
  {"00001211" , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Sports Talk Baseball */
  {"00004076" , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Honoo no Toukyuuji Dodge Danpei */
  {"G-4524"   , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Ninja Burai Densetsu */
  {"00054503" , 0          , 0      , mapper_i2c_sega_init        , EEPROM_X24C01 }, /* Game Toshokan  */
  {"T-81033"  , 0          , 0      , mapper_i2c_acclaim_16M_init , EEPROM_X24C02 }, /* NBA Jam (J) */
  {"T-081326" , 0          , 0      , mapper_i2c_acclaim_16M_init , EEPROM_X24C02 }, /* NBA Jam (UE) */
  {"T-081276" , 0          , 0      , mapper_i2c_acclaim_32M_init , EEPROM_24C02  }, /* NFL Quarterback Club */
  {"T-81406"  , 0          , 0      , mapper_i2c_acclaim_32M_init , EEPROM_24C04  }, /* NBA Jam TE */
  {"T-081586" , 0          , 0      , mapper_i2c_acclaim_32M_init , EEPROM_24C16  }, /* NFL Quarterback Club '96 */
  {"T-81476"  , 0          , 0      , mapper_i2c_acclaim_32M_init , EEPROM_24C65  }, /* Frank Thomas Big Hurt Baseball */
  {"T-81576"  , 0          , 0      , mapper_i2c_acclaim_32M_init , EEPROM_24C65  }, /* College Slam */
  {"T-120106" , 0          , 0      , mapper_i2c_jcart_init       , EEPROM_24C08  }, /* Brian Lara Cricket */
  {"00000000" , 0x444e4c44 , 0x168B , mapper_i2c_jcart_init       , EEPROM_24C08  }, /* Micro Machines Military */
  {"00000000" , 0x444e4c44 , 0x165E , mapper_i2c_jcart_init       , EEPROM_24C16  }, /* Micro Machines Turbo Tournament 96 */
  {"T-120096" , 0          , 0      , mapper_i2c_jcart_init       , EEPROM_24C16  }, /* Micro Machines 2 - Turbo Tournament */
  {"T-120146" , 0          , 0      , mapper_i2c_jcart_init       , EEPROM_24C65  }, /* Brian Lara Cricket 96 / Shane Warne Cricket */
  {"00000000" , 0xfffffffc , 0x168B , mapper_i2c_jcart_init       , NO_EEPROM     }, /* Super Skidmarks */
  {"00000000" , 0xfffffffc , 0x165E , mapper_i2c_jcart_init       , NO_EEPROM     }, /* Pete Sampras Tennis (Prototype) */
  {"T-120066" , 0          , 0      , mapper_i2c_jcart_init       , NO_EEPROM     }, /* Pete Sampras Tennis */
  {"T-123456" , 0          , 0      , mapper_i2c_jcart_init       , NO_EEPROM     }, /* Pete Sampras Tennis 96 */
  {"XXXXXXXX" , 0          , 0xDF39 , mapper_i2c_jcart_init       , NO_EEPROM     }, /* Pete Sampras Tennis 96 (Prototype ?) */
};

static struct
{
  uint8 sda;              /* current SDA line state */
  uint8 scl;              /* current SCL line state */
  uint8 old_sda;          /* previous SDA line state */
  uint8 old_scl;          /* previous SCL line state */
  uint8 cycles;           /* operation internal cycle (0-9) */
  uint8 rw;               /* operation type (1:READ, 0:WRITE) */
  uint16 device_address;  /* device address */
  uint16 word_address;    /* memory address */
  uint8 buffer;           /* write buffer */
  T_I2C_STATE state;      /* current operation state */
  T_I2C_SPEC spec;        /* EEPROM characteristics */
  uint8 scl_in_bit;       /* SCL (write) bit position */
  uint8 sda_in_bit;       /* SDA (write) bit position */
  uint8 sda_out_bit;      /* SDA (read) bit position */
} eeprom_i2c;


/********************************************************************/
/* I2C EEPROM mapper initialization                                 */
/********************************************************************/

void eeprom_i2c_init()
{
  int i = sizeof(i2c_database) / sizeof(T_I2C_GAME) - 1;

  /* no serial EEPROM found by default */
  sram.custom = 0;

  /* initialize I2C EEPROM state */
  memset(&eeprom_i2c, 0, sizeof(eeprom_i2c));
  eeprom_i2c.sda = eeprom_i2c.old_sda = 1;
  eeprom_i2c.scl = eeprom_i2c.old_scl = 1;
  eeprom_i2c.state = STAND_BY;

  /* auto-detect games listed in database */
  do
  {
    /* check game internal id code */
    if (strstr(rominfo.product, i2c_database[i].id))
    {
      /* additional check for known SRAM-patched hacks */
      if ((i2c_database[i].id[0] == ' ') && ((sram.end - sram.start) > 2))
      {
        break;
      }

      /* additional check for Codemasters games */
      if (((i2c_database[i].chk == 0) || (i2c_database[i].chk == rominfo.checksum)) &&
          ((i2c_database[i].sp == 0) || (i2c_database[i].sp == READ_WORD_LONG(cart.rom, 0))))
      {
        /* additional check for J-CART games without serial EEPROM */
        if (i2c_database[i].eeprom_type > NO_EEPROM)
        {
          /* get EEPROM characteristics */
          memcpy(&eeprom_i2c.spec, &i2c_specs[i2c_database[i].eeprom_type], sizeof(T_I2C_SPEC));

          /* serial EEPROM game found */
          sram.on = sram.custom = 1;
        }

        /* initialize memory mapping */
        i2c_database[i].mapper_init();
        break;
      }
    }
  }
  while (i--);

  /* for games not present in database, check if ROM header indicates serial EEPROM is used */
  if (!sram.custom && sram.detected)
  {
    if ((READ_BYTE(cart.rom,0x1b2) == 0xe8) || ((sram.end - sram.start) < 2))
    {
      /* serial EEPROM game found */
      sram.custom = 1;

      /* assume SEGA mapper as default */
      memcpy(&eeprom_i2c.spec, &i2c_specs[EEPROM_X24C01], sizeof(T_I2C_SPEC));
      mapper_i2c_sega_init();
    }
  }
}


/********************************************************************/
/* I2C EEPROM internal                                   			*/
/********************************************************************/

INLINE void Detect_START()
{
  /* detect SDA HIGH to LOW transition while SCL is held HIGH */
  if (eeprom_i2c.old_scl && eeprom_i2c.scl)
  {
    if (eeprom_i2c.old_sda && !eeprom_i2c.sda)
    {
      /* initialize cycle counter */
      eeprom_i2c.cycles = 0;

      /* initialize sequence */
      if (eeprom_i2c.spec.address_bits == 7)
      {
        /* get Word Address */
        eeprom_i2c.word_address = 0;
        eeprom_i2c.state = GET_WORD_ADR_7BITS;
      }
      else
      {
        /* get Device Address */
        eeprom_i2c.device_address = 0;
        eeprom_i2c.state = GET_DEVICE_ADR;
      }
    }
  }
}

INLINE void Detect_STOP()
{
  /* detect SDA LOW to HIGH transition while SCL is held HIGH */
  if (eeprom_i2c.old_scl && eeprom_i2c.scl)
  {
    if (!eeprom_i2c.old_sda && eeprom_i2c.sda)
    {
      eeprom_i2c.state = STAND_BY;
    }
  }
}

static void eeprom_i2c_update(void)
{
  /* EEPROM current state */
  switch (eeprom_i2c.state)
  {
    /* Standby Mode */
    case STAND_BY:
    {
      Detect_START();
      break;
    }

    /* Suspended Mode */
    case WAIT_STOP:
    {
      Detect_STOP();
      break;
    }

    /* Get Word Address (7-bit): Mode 1 (X24C01) only
     * and R/W bit
     */
    case GET_WORD_ADR_7BITS:
    {
      Detect_START();
      Detect_STOP();

      /* look for SCL HIGH to LOW transition */
      if (eeprom_i2c.old_scl && !eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* increment cycle counter */
          eeprom_i2c.cycles++;
        }
        else
        {
          /* next sequence */
          eeprom_i2c.cycles = 1;
          eeprom_i2c.state = eeprom_i2c.rw ? READ_DATA : WRITE_DATA;

          /* clear write buffer */
          eeprom_i2c.buffer = 0x00;
        }
      }

      /* look for SCL LOW to HIGH transition */
      else if (!eeprom_i2c.old_scl && eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 8)
        {
          /* latch Word Address bits 6-0 */
          eeprom_i2c.word_address |= (eeprom_i2c.sda << (7 - eeprom_i2c.cycles));
        }
        else if (eeprom_i2c.cycles == 8)
        {
          /* latch R/W bit */
          eeprom_i2c.rw = eeprom_i2c.sda;
        }
      }

      break;
    }

    /* Get Device Address (0-3 bits, depending on the array size) : Mode 2 & Mode 3 (24C01 - 24C512) only
     * or/and Word Address MSB: Mode 2 only (24C04 - 24C16) (0-3 bits, depending on the array size)
     * and R/W bit
     */
    case GET_DEVICE_ADR:
    {
      Detect_START();
      Detect_STOP();

      /* look for SCL HIGH to LOW transition */
      if (eeprom_i2c.old_scl && !eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* increment cycle counter */
          eeprom_i2c.cycles++;
        }
        else
        {
          /* shift Device Address bits */
          eeprom_i2c.device_address <<= eeprom_i2c.spec.address_bits;

          /* next sequence */
          eeprom_i2c.cycles = 1;
          if (eeprom_i2c.rw)
          {
            eeprom_i2c.state = READ_DATA;
          }
          else
          {
            eeprom_i2c.word_address = 0;
            eeprom_i2c.state = (eeprom_i2c.spec.address_bits == 16) ? GET_WORD_ADR_HIGH : GET_WORD_ADR_LOW;
          }
        }
      }

      /* look for SCL LOW to HIGH transition */
      else if (!eeprom_i2c.old_scl && eeprom_i2c.scl)
      {
        if ((eeprom_i2c.cycles > 4) && (eeprom_i2c.cycles < 8))
        {
          /* latch Device Address bits */
          eeprom_i2c.device_address |= (eeprom_i2c.sda << (7 - eeprom_i2c.cycles));
        }
        else if (eeprom_i2c.cycles == 8)
        {
          /* latch R/W bit */
          eeprom_i2c.rw = eeprom_i2c.sda;
        }
      }

      break;
    }

    /* Get Word Address MSB (4-8 bits depending on the array size)
     * Mode 3 only (24C32 - 24C512)
     */
    case GET_WORD_ADR_HIGH:
    {
      Detect_START();
      Detect_STOP();

      /* look for SCL HIGH to LOW transition */
      if (eeprom_i2c.old_scl && !eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* increment cycle counter */
          eeprom_i2c.cycles++;
        }
        else
        {
          /* next sequence */
          eeprom_i2c.cycles = 1;
          eeprom_i2c.state = GET_WORD_ADR_LOW;
        }
      }

      /* look for SCL LOW to HIGH transition */
      else if (!eeprom_i2c.old_scl && eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          if (eeprom_i2c.spec.size_mask  < (1 << (16 - eeprom_i2c.cycles)))
          {
            /* ignored bit: Device Address bits should be right-shifted */
            eeprom_i2c.device_address >>= 1;
          }
          else
          {
            /* latch Word Address high bits */
            eeprom_i2c.word_address |= (eeprom_i2c.sda << (16 - eeprom_i2c.cycles));
          }
        }
      }  

      break;
    }

    /* Get Word Address LSB: 7bits (24C01) or 8bits (24C02-24C512)
     * MODE-2 and MODE-3 only (24C01 - 24C512)
     */
    case GET_WORD_ADR_LOW: 
    {
      Detect_START();
      Detect_STOP();

      /* look for SCL HIGH to LOW transition */
      if (eeprom_i2c.old_scl && !eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* increment cycle counter */
          eeprom_i2c.cycles++;
        }
        else
        {
          /* next sequence */
          eeprom_i2c.cycles = 1;
          eeprom_i2c.state = WRITE_DATA;

          /* clear write buffer */
          eeprom_i2c.buffer = 0x00;
        }
      }

      /* look for SCL LOW to HIGH transition */
      else if (!eeprom_i2c.old_scl && eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          if (eeprom_i2c.spec.size_mask < (1 << (8 - eeprom_i2c.cycles)))
          {
            /* ignored bit (24C01): Device Address bits should be right-shifted */
            eeprom_i2c.device_address >>= 1;
          }
          else
          {
            /* latch Word Address low bits */
            eeprom_i2c.word_address |= (eeprom_i2c.sda << (8 - eeprom_i2c.cycles));
          }
        }
      }

      break;
    }

    /*
     * Read Sequence
     */
    case READ_DATA:
    {
      Detect_START();
      Detect_STOP();

      /* look for SCL HIGH to LOW transition */
      if (eeprom_i2c.old_scl && !eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* increment cycle counter */
          eeprom_i2c.cycles++;
        }
        else
        {
          /* next read sequence */
          eeprom_i2c.cycles = 1;
        }
      }

      /* look for SCL LOW to HIGH transition */
      else if (!eeprom_i2c.old_scl && eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles == 9)
        {
          /* check if ACK is received */
          if (eeprom_i2c.sda)
          {
            /* end of read sequence */
            eeprom_i2c.state = WAIT_STOP;
          }
          else
          {
            /* increment Word Address (roll up at maximum array size) */
            eeprom_i2c.word_address = (eeprom_i2c.word_address + 1) & eeprom_i2c.spec.size_mask;
          }
        }
      }

      break;
    }

    /*
     * Write Sequence
     */
    case WRITE_DATA:
    {
      Detect_START();
      Detect_STOP();

      /* look for SCL HIGH to LOW transition */
      if (eeprom_i2c.old_scl && !eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* increment cycle counter */
          eeprom_i2c.cycles++;
        }
        else
        {
          /* next write sequence */
          eeprom_i2c.cycles = 1;
        }
      }

      /* look for SCL LOW to HIGH transition */
      else if (!eeprom_i2c.old_scl && eeprom_i2c.scl)
      {
        if (eeprom_i2c.cycles < 9)
        {
          /* latch DATA bits 7-0 to write buffer */
          eeprom_i2c.buffer |= (eeprom_i2c.sda << (8 - eeprom_i2c.cycles));
        }
        else
        {
          /* write back to memory array (max 64kB) */
          sram.sram[(eeprom_i2c.device_address | eeprom_i2c.word_address) & 0xffff] = eeprom_i2c.buffer;
          
          /* clear write buffer */
          eeprom_i2c.buffer = 0;

          /* increment Word Address (roll over at maximum page size) */
          eeprom_i2c.word_address = (eeprom_i2c.word_address & ~eeprom_i2c.spec.pagewrite_mask) | 
                                    ((eeprom_i2c.word_address + 1) & eeprom_i2c.spec.pagewrite_mask);
        }
      }

      break;
    }
  }

  /* save SCL & SDA previous state */
  eeprom_i2c.old_scl = eeprom_i2c.scl;
  eeprom_i2c.old_sda = eeprom_i2c.sda;
}

static uint8 eeprom_i2c_out(void)
{
  /* check EEPROM state */
  if (eeprom_i2c.state == READ_DATA)
  {
    /* READ cycle */
    if (eeprom_i2c.cycles < 9)
    {
      /* return memory array (max 64kB) DATA bits */
      return ((sram.sram[(eeprom_i2c.device_address | eeprom_i2c.word_address) & 0xffff] >> (8 - eeprom_i2c.cycles)) & 1);
    }
  }
  else if (eeprom_i2c.cycles == 9)
  {
    /* ACK cycle */
    return 0;
  }

  /* return latched /SDA input by default */
  return eeprom_i2c.sda;
}


/********************************************************************/
/* Common I2C board memory mapping		                            */
/********************************************************************/

static uint32 mapper_i2c_generic_read8(uint32 address)
{
  /* only use D0-D7 */
  if (address & 0x01)
  {
    return eeprom_i2c_out() << eeprom_i2c.sda_out_bit;
  }

  return m68k_read_bus_8(address);
}

static uint32 mapper_i2c_generic_read16(uint32 address)
{
  return eeprom_i2c_out() << eeprom_i2c.sda_out_bit;
}

static void mapper_i2c_generic_write8(uint32 address, uint32 data)
{
  /* only use /LWR */
  if (address & 0x01)
  {
    eeprom_i2c.sda = (data >> eeprom_i2c.sda_in_bit) & 1;
    eeprom_i2c.scl = (data >> eeprom_i2c.scl_in_bit) & 1;
    eeprom_i2c_update();
  }
  else
  {
    m68k_unused_8_w(address, data);
  }
}

static void mapper_i2c_generic_write16(uint32 address, uint32 data)
{
  eeprom_i2c.sda = (data >> eeprom_i2c.sda_in_bit) & 1;
  eeprom_i2c.scl = (data >> eeprom_i2c.scl_in_bit) & 1;
  eeprom_i2c_update();
}


/********************************************************************/
/* EA mapper (PWA P10003 & P10004 boards)                           */
/********************************************************************/

static void mapper_i2c_ea_init(void)
{
  int i;

  /* serial EEPROM (read/write) mapped to $200000-$3fffff */
  for (i=0x20; i<0x40; i++)
  {
    m68k.memory_map[i].read8   = mapper_i2c_generic_read8;
    m68k.memory_map[i].read16  = mapper_i2c_generic_read16;
    m68k.memory_map[i].write8  = mapper_i2c_generic_write8;
    m68k.memory_map[i].write16 = mapper_i2c_generic_write16;
    zbank_memory_map[i].read   = mapper_i2c_generic_read8;
    zbank_memory_map[i].write  = mapper_i2c_generic_write8;
  }

  /* SCL (in) -> D6 */
  /* SDA (in/out) -> D7 */
  eeprom_i2c.scl_in_bit  = 6;
  eeprom_i2c.sda_in_bit  = 7;
  eeprom_i2c.sda_out_bit = 7;
}


/********************************************************************/
/* SEGA mapper (171-5878, 171-6111, 171-6304 & 171-6584 boards)     */
/********************************************************************/

static void mapper_i2c_sega_init(void)
{
  int i;

  /* serial EEPROM (read/write) mapped to $200000-$3fffff */
  for (i=0x20; i<0x40; i++)
  {
    m68k.memory_map[i].read8   = mapper_i2c_generic_read8;
    m68k.memory_map[i].read16  = mapper_i2c_generic_read16;
    m68k.memory_map[i].write8  = mapper_i2c_generic_write8;
    m68k.memory_map[i].write16 = mapper_i2c_generic_write16;
    zbank_memory_map[i].read   = mapper_i2c_generic_read8;
    zbank_memory_map[i].write  = mapper_i2c_generic_write8;
  }

  /* SCL (in) -> D1 */
  /* SDA (in/out) -> D0 */
  eeprom_i2c.scl_in_bit  = 1;
  eeprom_i2c.sda_in_bit  = 0;
  eeprom_i2c.sda_out_bit = 0;
}


/********************************************************************/
/* ACCLAIM 16M mapper (P/N 670120 board)                            */
/********************************************************************/

static void mapper_i2c_acclaim_16M_init(void)
{
  int i;

  /* serial EEPROM (read/write) mapped to $200000-$3fffff */
  for (i=0x20; i<0x40; i++)
  {
    /* /LWR & /UWR are unused */
    m68k.memory_map[i].read8   = mapper_i2c_generic_read8;
    m68k.memory_map[i].read16  = mapper_i2c_generic_read16;
    m68k.memory_map[i].write8  = mapper_i2c_generic_write16;
    m68k.memory_map[i].write16 = mapper_i2c_generic_write16;
    zbank_memory_map[i].read   = mapper_i2c_generic_read8;
    zbank_memory_map[i].write  = mapper_i2c_generic_write16;
  }

  /* SCL (in) & SDA (out) -> D1 */
  /* SDA (in) -> D0 */
  eeprom_i2c.scl_in_bit  = 1;
  eeprom_i2c.sda_in_bit  = 0;
  eeprom_i2c.sda_out_bit = 1;
}


/********************************************************************/
/* ACCLAIM 32M mapper (P/N 670125 & 670127 boards with LZ95A53 PAL) */
/********************************************************************/

static void mapper_acclaim_32M_write8(uint32 address, uint32 data)
{
  if (address & 0x01)
  {
    /* D0 goes to /SDA when only /LWR is asserted */
    eeprom_i2c.sda = data & 1;
  }
  else
  {
    /* D0 goes to /SCL when only /UWR is asserted */
    eeprom_i2c.scl = data & 1;
  }

  eeprom_i2c_update();
} 

static void mapper_acclaim_32M_write16(uint32 address, uint32 data)
{
  int i;
  
  /* custom bankshifting when both /LWR and /UWR are asserted */
  if (data & 0x01)
  {
    /* cartridge ROM (read) mapped to $200000-$2fffff */
    for (i=0x20; i<0x30; i++)
    {
      m68k.memory_map[i].read8   = NULL;
      m68k.memory_map[i].read16  = NULL;
      zbank_memory_map[i].read   = NULL;
    }
  }
  else
  {
    /* serial EEPROM (read) mapped to $200000-$2fffff */
    for (i=0x20; i<0x30; i++)
    {
      m68k.memory_map[i].read8   = mapper_i2c_generic_read8;
      m68k.memory_map[i].read16  = mapper_i2c_generic_read16;
      zbank_memory_map[i].read   = mapper_i2c_generic_read8;
    }
  }
}

static void mapper_i2c_acclaim_32M_init(void)
{
  int i;

  /* custom LZ95A53 PAL (write) mapped to $200000-$2fffff */
  for (i=0x20; i<0x30; i++)
  {
    m68k.memory_map[i].write8  = mapper_acclaim_32M_write8;
    m68k.memory_map[i].write16 = mapper_acclaim_32M_write16;
    zbank_memory_map[i].write  = mapper_acclaim_32M_write8;
  }

  /* SCL (in) & SDA (in/out) -> D0 */
  eeprom_i2c.scl_in_bit  = 0;
  eeprom_i2c.sda_in_bit  = 0;
  eeprom_i2c.sda_out_bit = 0;

  /* cartridge ROM mapping is reinitialized on reset */
  cart.hw.bankshift = 1;
}


/********************************************************************/
/* CODEMASTERS mapper (SRJCV2-1 & SRJCV2-2 boards with 16R4 PAL)    */
/********************************************************************/

static uint32 mapper_i2c_jcart_read8(uint32 address)
{
  /* only D7 used for /SDA */
  if (address & 0x01)
  {
    return ((eeprom_i2c_out() << 7) | (jcart_read(address) & 0x7f));
  }
  
  return (jcart_read(address) >> 8);
}

static uint32 mapper_i2c_jcart_read16(uint32 address)
{
  return ((eeprom_i2c_out() << 7) | jcart_read(address));
}

static void mapper_i2c_jcart_init(void)
{
  int i;

 /* check if serial EEPROM is used (support for SRJCV1-1 & SRJCV1-2 boards with only J-CART) */
  if (sram.custom)
  {
    /* serial EEPROM (write) mapped to $300000-$37ffff */
    for (i=0x30; i<0x38; i++)
    {
      /* /LWR & /UWR are unused */
      m68k.memory_map[i].write8  = mapper_i2c_generic_write16;
      m68k.memory_map[i].write16 = mapper_i2c_generic_write16;
      zbank_memory_map[i].write  = mapper_i2c_generic_write16;
    }
  }

  /* check if J-CART is used (support for Brian Lara Cricket games without J-CART) */
  if (strstr(rominfo.product,"T-120106") || strstr(rominfo.product,"T-120146"))
  {
    /* only serial EEPROM (read) mapped to $380000-$3fffff */
    for (i=0x38; i<0x40; i++)
    {
      m68k.memory_map[i].read8   = mapper_i2c_generic_read8;
      m68k.memory_map[i].read16  = mapper_i2c_generic_read16;
      m68k.memory_map[i].write8  = m68k_unused_8_w;
      m68k.memory_map[i].write16 = m68k_unused_16_w;
      zbank_memory_map[i].read   = mapper_i2c_generic_read8;
      zbank_memory_map[i].write  = m68k_unused_8_w;
    }
  }
  else
  {
    /* enable J-CART controllers */
    cart.special |= HW_J_CART;

    /* serial EEPROM (read) & J-CART (read/write) mapped to $380000-$3fffff */
    for (i=0x38; i<0x40; i++)
    {
      /* /LWR & /UWR are unused */
      m68k.memory_map[i].read8   = mapper_i2c_jcart_read8;
      m68k.memory_map[i].read16  = mapper_i2c_jcart_read16;
      m68k.memory_map[i].write8  = jcart_write;
      m68k.memory_map[i].write16 = jcart_write;
      zbank_memory_map[i].read   = mapper_i2c_jcart_read8;
      zbank_memory_map[i].write  = jcart_write;
    }
  }

  /* SCL (in)  -> D1 */
  /* SDA (in)  -> D0 */
  /* SDA (out) -> D7 */
  eeprom_i2c.scl_in_bit  = 1;
  eeprom_i2c.sda_in_bit  = 0;
  eeprom_i2c.sda_out_bit = 7;
}
