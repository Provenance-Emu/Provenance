/*
 * rarely used EEPROM code
 * (C) notaz, 2007-2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * (see Genesis Plus for Wii/GC code and docs for info,
 * full game list and better code).
 */

#include "pico_int.h"

static unsigned int last_write = 0xffff0000;

// eeprom_status: LA.. s.la (L=pending SCL, A=pending SDA,
//                           s=started, l=old SCL, a=old SDA)
static void EEPROM_write_do(unsigned int d) // ???? ??la (l=SCL, a=SDA)
{
  unsigned int sreg = Pico.m.eeprom_status, saddr = Pico.m.eeprom_addr;
  unsigned int scyc = Pico.m.eeprom_cycle, ssa = Pico.m.eeprom_slave;

  elprintf(EL_EEPROM, "eeprom: scl/sda: %i/%i -> %i/%i, newtime=%i", (sreg&2)>>1, sreg&1,
    (d&2)>>1, d&1, SekCyclesDone() - last_write);
  saddr &= 0x1fff;

  if(sreg & d & 2) {
    // SCL was and is still high..
    if((sreg & 1) && !(d&1)) {
      // ..and SDA went low, means it's a start command, so clear internal addr reg and clock counter
      elprintf(EL_EEPROM, "eeprom: -start-");
      //saddr = 0;
      scyc = 0;
      sreg |= 8;
    } else if(!(sreg & 1) && (d&1)) {
      // SDA went high == stop command
      elprintf(EL_EEPROM, "eeprom: -stop-");
      sreg &= ~8;
    }
  }
  else if((sreg & 8) && !(sreg & 2) && (d&2))
  {
    // we are started and SCL went high - next cycle
    scyc++; // pre-increment
    if(SRam.eeprom_type) {
      // X24C02+
      if((ssa&1) && scyc == 18) {
        scyc = 9;
        saddr++; // next address in read mode
        /*if(SRam.eeprom_type==2) saddr&=0xff; else*/ saddr&=0x1fff; // mask
      }
      else if(SRam.eeprom_type == 2 && scyc == 27) scyc = 18;
      else if(scyc == 36) scyc = 27;
    } else {
      // X24C01
      if(scyc == 18) {
        scyc = 9;  // wrap
        if(saddr&1) { saddr+=2; saddr&=0xff; } // next addr in read mode
      }
    }
    elprintf(EL_EEPROM, "eeprom: scyc: %i", scyc);
  }
  else if((sreg & 8) && (sreg & 2) && !(d&2))
  {
    // we are started and SCL went low (falling edge)
    if(SRam.eeprom_type) {
      // X24C02+
      if(scyc == 9 || scyc == 18 || scyc == 27); // ACK cycles
      else if( (SRam.eeprom_type == 3 && scyc > 27) || (SRam.eeprom_type == 2 && scyc > 18) ) {
        if(!(ssa&1)) {
          // data write
          unsigned char *pm=SRam.data+saddr;
          *pm <<= 1; *pm |= d&1;
          if(scyc == 26 || scyc == 35) {
            saddr=(saddr&~0xf)|((saddr+1)&0xf); // only 4 (?) lowest bits are incremented
            elprintf(EL_EEPROM, "eeprom: write done, addr inc to: %x, last byte=%02x", saddr, *pm);
          }
          SRam.changed = 1;
        }
      } else if(scyc > 9) {
        if(!(ssa&1)) {
          // we latch another addr bit
          saddr<<=1;
          if(SRam.eeprom_type == 2) saddr&=0xff; else saddr&=0x1fff; // mask
          saddr|=d&1;
          if(scyc==17||scyc==26) {
            elprintf(EL_EEPROM, "eeprom: addr reg done: %x", saddr);
            if(scyc==17&&SRam.eeprom_type==2) { saddr&=0xff; saddr|=(ssa<<7)&0x700; } // add device bits too
          }
        }
      } else {
        // slave address
        ssa<<=1; ssa|=d&1;
        if(scyc==8) elprintf(EL_EEPROM, "eeprom: slave done: %x", ssa);
      }
    } else {
      // X24C01
      if(scyc == 9); // ACK cycle, do nothing
      else if(scyc > 9) {
        if(!(saddr&1)) {
          // data write
          unsigned char *pm=SRam.data+(saddr>>1);
          *pm <<= 1; *pm |= d&1;
          if(scyc == 17) {
            saddr=(saddr&0xf9)|((saddr+2)&6); // only 2 lowest bits are incremented
            elprintf(EL_EEPROM, "eeprom: write done, addr inc to: %x, last byte=%02x", saddr>>1, *pm);
          }
          SRam.changed = 1;
        }
      } else {
        // we latch another addr bit
        saddr<<=1; saddr|=d&1; saddr&=0xff;
        if(scyc==8) elprintf(EL_EEPROM, "eeprom: addr done: %x", saddr>>1);
      }
    }
  }

  sreg &= ~3; sreg |= d&3; // remember SCL and SDA
  Pico.m.eeprom_status  = (unsigned char) sreg;
  Pico.m.eeprom_cycle = (unsigned char) scyc;
  Pico.m.eeprom_slave = (unsigned char) ssa;
  Pico.m.eeprom_addr  = (unsigned short)saddr;
}

static void EEPROM_upd_pending(unsigned int d)
{
  unsigned int d1, sreg = Pico.m.eeprom_status;

  sreg &= ~0xc0;

  // SCL
  d1 = (d >> SRam.eeprom_bit_cl) & 1;
  sreg |= d1 << 7;

  // SDA in
  d1 = (d >> SRam.eeprom_bit_in) & 1;
  sreg |= d1 << 6;

  Pico.m.eeprom_status = (unsigned char) sreg;
}

void EEPROM_write16(unsigned int d)
{
  // this diff must be at most 16 for NBA Jam to work
  if (SekCyclesDone() - last_write < 16) {
    // just update pending state
    elprintf(EL_EEPROM, "eeprom: skip because cycles=%i",
        SekCyclesDone() - last_write);
    EEPROM_upd_pending(d);
  } else {
    int srs = Pico.m.eeprom_status;
    EEPROM_write_do(srs >> 6); // execute pending
    EEPROM_upd_pending(d);
    if ((srs ^ Pico.m.eeprom_status) & 0xc0) // update time only if SDA/SCL changed
      last_write = SekCyclesDone();
  }
}

void EEPROM_write8(unsigned int a, unsigned int d)
{
  unsigned char *wb = Pico.m.eeprom_wb;
  wb[a & 1] = d;
  EEPROM_write16((wb[0] << 8) | wb[1]);
}

unsigned int EEPROM_read(void)
{
  unsigned int shift, d;
  unsigned int sreg, saddr, scyc, ssa, interval;

  // flush last pending write
  EEPROM_write_do(Pico.m.eeprom_status>>6);

  sreg = Pico.m.eeprom_status; saddr = Pico.m.eeprom_addr&0x1fff; scyc = Pico.m.eeprom_cycle; ssa = Pico.m.eeprom_slave;
  interval = SekCyclesDone() - last_write;
  d = (sreg>>6)&1; // use SDA as "open bus"

  // NBA Jam is nasty enough to read <before> raising the SCL and starting the new cycle.
  // this is probably valid because data changes occur while SCL is low and data can be read
  // before it's actual cycle begins.
  if (!(sreg&0x80) && interval >= 24) {
    elprintf(EL_EEPROM, "eeprom: early read, cycles=%i", interval);
    scyc++;
  }

  if (!(sreg & 8)); // not started, use open bus
  else if (scyc == 9 || scyc == 18 || scyc == 27) {
    elprintf(EL_EEPROM, "eeprom: r ack");
    d = 0;
  } else if (scyc > 9 && scyc < 18) {
    // started and first command word received
    shift = 17-scyc;
    if (SRam.eeprom_type) {
      // X24C02+
      if (ssa&1) {
        elprintf(EL_EEPROM, "eeprom: read: addr %02x, cycle %i, reg %02x", saddr, scyc, sreg);
	if (shift==0) elprintf(EL_EEPROM, "eeprom: read done, byte %02x", SRam.data[saddr]);
        d = (SRam.data[saddr]>>shift)&1;
      }
    } else {
      // X24C01
      if (saddr&1) {
        elprintf(EL_EEPROM, "eeprom: read: addr %02x, cycle %i, reg %02x", saddr>>1, scyc, sreg);
	if (shift==0) elprintf(EL_EEPROM, "eeprom: read done, byte %02x", SRam.data[saddr>>1]);
        d = (SRam.data[saddr>>1]>>shift)&1;
      }
    }
  }

  return (d << SRam.eeprom_bit_out);
}

