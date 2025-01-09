#include <../base.hpp>

#define SUPERFX_CPP
namespace bSNES_v059 {

#include "serialization.cpp"
#include "bus/bus.cpp"
#include "core/core.cpp"
#include "memory/memory.cpp"
#include "mmio/mmio.cpp"
#include "timing/timing.cpp"
#include "disasm/disasm.cpp"

SuperFX superfx;

void SuperFX::enter() {
  while(true) {
    while(scheduler.sync == Scheduler::SyncAll) {
      scheduler.exit(Scheduler::SynchronizeEvent);
    }

    if(regs.sfr.g == 0) {
      add_clocks(6);
      scheduler.sync_copcpu();
      continue;
    }

    do_op((regs.sfr.alt & 1023) | peekpipe());
    regs.r[15].data += r15_NOT_modified;    

    if(++instruction_counter >= 128) {
      instruction_counter = 0;
      scheduler.sync_copcpu();
    }
  }
}

void SuperFX::init() {
  regs.r[14].on_modify = SuperFX_r14_modify;
  regs.r[15].on_modify = SuperFX_r15_modify;
}

void SuperFX::enable() {
  for(unsigned i = 0x3000; i <= 0x32ff; i++) memory::mmio.map(i, *this);
}

void SuperFX::power() {
  clockmode = config.superfx.speed;
  reset();
}

void SuperFX::reset() {
  //printf("%d, %d\n", (int)sizeof(reg16_t), (int)((uint8*)&regs.r[0] - (uint8*)this));

  superfxbus.init();
  instruction_counter = 0;

  for(unsigned n = 0; n < 16; n++) regs.r[n] = 0x0000;
  regs.sfr   = 0x0000;
  regs.pbr   = 0x00;
  regs.rombr = 0x00;
  regs.rambr = 0;
  regs.cbr   = 0x0000;
  regs.scbr  = 0x00;
  regs.scmr  = 0x00;
  regs.colr  = 0x00;
  regs.por   = 0x00;
  regs.bramr = 0;
  regs.vcr   = 0x04;
  regs.cfgr  = 0x00;
  regs.clsr  = 0;
  regs.pipeline = 0x01;  //nop
  regs.ramaddr = 0x0000;
  regs.reset();

  memory_reset();
  timing_reset();
}

}
