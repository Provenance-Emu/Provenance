//#include <../base.hpp>

#define SSMP_CPP
namespace bSNES_v059 {

#if defined(DEBUGGER)
  #include "debugger/debugger.cpp"
  sSMPDebugger smp;
#else
  SMP smp;
#endif

#include "serialization.cpp"
#include "memory/memory.cpp"
#include "timing/timing.cpp"

alwaysinline void SMP::op_step() {
  do_op(op_readpc());
}

void SMP::enter() {
  while(true) {
    while(scheduler.sync == Scheduler::SyncAll) {
      scheduler.exit(Scheduler::SynchronizeEvent);
      //if(scheduler.clock.cpusmp >= 0 && scheduler.sync != Scheduler::SyncAll) {
      //	puts("BLAHBLAH");
      //}
    }

    op_step();
  }
}

void SMP::power() {
  //targets not initialized/changed upon reset
  t0.target = 0;
  t1.target = 0;
  t2.target = 0;

  reset();
}

void SMP::reset() {
  regs.pc = 0xffc0;
  regs.a  = 0x00;
  regs.x  = 0x00;
  regs.y  = 0x00;
  regs.sp = 0xef;
  regs.p  = 0x02;

  for(unsigned i = 0; i < memory::apuram.size(); i++) {
    memory::apuram.write(i, 0x00);
  }

  status.clock_counter = 0;
  status.dsp_counter   = 0;

  //$00f0
  status.clock_speed   = 24 * 3 / 3;
  status.mmio_disabled = false;
  status.ram_writable  = true;

  //$00f1
  status.iplrom_enabled = true;

  //$00f2
  status.dsp_addr = 0x00;

  //$00f8,$00f9
  status.smp_f8 = 0x00;
  status.smp_f9 = 0x00;

  t0.enabled = false;
  t1.enabled = false;
  t2.enabled = false;

  t0.stage1_ticks = 0;
  t1.stage1_ticks = 0;
  t2.stage1_ticks = 0;

  t0.stage2_ticks = 0;
  t1.stage2_ticks = 0;
  t2.stage2_ticks = 0;

  t0.stage3_ticks = 0;
  t1.stage3_ticks = 0;
  t2.stage3_ticks = 0;
}

};
