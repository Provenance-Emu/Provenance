#include "snes/snes.hpp"
#include <stdio.h>

typedef struct spc_file {
  uint8 header[33];
  uint8 idtag[3];
  uint8 version_minor;

  uint8 pc_low;
  uint8 pc_high;
  uint8 a;
  uint8 x;
  uint8 y;
  uint8 psw;
  uint8 sp;
  uint8 unused_a[2];

  uint8 id666[210];

  uint8 apuram[65536];
  uint8 dsp_registers[128];
  uint8 unused_b[64];
  uint8 iplrom[64];
} spc_file;

namespace SNES {

#include "dsp/blargg_endian.h"

void SMP::save_spc (uint8 *block) {
  spc_file out;

  const char *header = "SNES-SPC700 Sound File Data v0.30";
  memcpy (out.header, header, 33);
  out.idtag[0] = out.idtag[1] = 26;
  out.idtag[2] = 27;
  out.version_minor = 30;

  out.pc_low = regs.pc & 0xff;
  out.pc_high = (regs.pc >> 8) & 0xff;
  out.a = regs.B.a;
  out.x = regs.x;
  out.y = regs.B.y;
  out.psw = (uint8) ((unsigned) regs.p);
  out.sp = regs.sp;
  out.unused_a[0] = out.unused_a[1] = 0;

  memset (out.id666, 0, 210);
  memcpy (out.apuram, apuram, 65536);

  for (int i = 0xf2; i <= 0xf9; i++)
  {
      out.apuram[i] = mmio_read (i);
  }

  for (int i = 0xfd; i <= 0xff; i++)
  {
      out.apuram[i] = mmio_read (i);
  }

  for (int i = 0; i < 128; i++)
  {
      out.dsp_registers[i] = dsp.read (i);
  }

  memset (out.unused_b, 0, 64);
  memcpy (out.iplrom, iplrom, 64);

  memcpy (block, &out, 66048);
}


void SMP::save_state(uint8 **block) {
  uint8 *ptr = *block;
  memcpy(ptr, apuram, 64 * 1024);
  ptr += 64 * 1024;

#undef INT32
#define INT32(i) set_le32(ptr, (i)); ptr += sizeof(int32)
  INT32(clock);

  INT32(opcode_number);
  INT32(opcode_cycle);

  INT32(regs.pc);
  INT32(regs.sp);
  INT32(regs.B.a);
  INT32(regs.x);
  INT32(regs.B.y);

  INT32(regs.p.n);
  INT32(regs.p.v);
  INT32(regs.p.p);
  INT32(regs.p.b);
  INT32(regs.p.h);
  INT32(regs.p.i);
  INT32(regs.p.z);
  INT32(regs.p.c);

  INT32(status.iplrom_enable);

  INT32(status.dsp_addr);

  INT32(status.ram00f8);
  INT32(status.ram00f9);

  INT32(timer0.enable);
  INT32(timer0.target);
  INT32(timer0.stage1_ticks);
  INT32(timer0.stage2_ticks);
  INT32(timer0.stage3_ticks);

  INT32(timer1.enable);
  INT32(timer1.target);
  INT32(timer1.stage1_ticks);
  INT32(timer1.stage2_ticks);
  INT32(timer1.stage3_ticks);

  INT32(timer2.enable);
  INT32(timer2.target);
  INT32(timer2.stage1_ticks);
  INT32(timer2.stage2_ticks);
  INT32(timer2.stage3_ticks);

  INT32(rd);
  INT32(wr);
  INT32(dp);
  INT32(sp);
  INT32(ya);
  INT32(bit);

  *block = ptr;
}

void SMP::load_state(uint8 **block) {
  uint8 *ptr = *block;
  memcpy(apuram, ptr, 64 * 1024);
  ptr += 64 * 1024;

#undef INT32
#define INT32(i) i = get_le32(ptr); ptr += sizeof(int32)
  INT32(clock);

  INT32(opcode_number);
  INT32(opcode_cycle);

  INT32(regs.pc);
  INT32(regs.sp);
  INT32(regs.B.a);
  INT32(regs.x);
  INT32(regs.B.y);

  INT32(regs.p.n);
  INT32(regs.p.v);
  INT32(regs.p.p);
  INT32(regs.p.b);
  INT32(regs.p.h);
  INT32(regs.p.i);
  INT32(regs.p.z);
  INT32(regs.p.c);

  INT32(status.iplrom_enable);

  INT32(status.dsp_addr);

  INT32(status.ram00f8);
  INT32(status.ram00f9);

  INT32(timer0.enable);
  INT32(timer0.target);
  INT32(timer0.stage1_ticks);
  INT32(timer0.stage2_ticks);
  INT32(timer0.stage3_ticks);

  INT32(timer1.enable);
  INT32(timer1.target);
  INT32(timer1.stage1_ticks);
  INT32(timer1.stage2_ticks);
  INT32(timer1.stage3_ticks);

  INT32(timer2.enable);
  INT32(timer2.target);
  INT32(timer2.stage1_ticks);
  INT32(timer2.stage2_ticks);
  INT32(timer2.stage3_ticks);

  INT32(rd);
  INT32(wr);
  INT32(dp);
  INT32(sp);
  INT32(ya);
  INT32(bit);

  *block = ptr;
}

} /* namespace SNES */
