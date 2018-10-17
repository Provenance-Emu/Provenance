#include "SPC_DSP.h"
#include <stdio.h>

class DSP : public Processor {
public:
  inline uint8 read(uint8 addr) {
    synchronize ();
    return spc_dsp.read(addr);
  }

  inline void synchronize (void) {
    if (clock) {
      spc_dsp.run (clock);
      clock = 0;
    }
  }

  inline void write(uint8 addr, uint8 data) {
    synchronize ();
    spc_dsp.write(addr, data);
  }

  void save_state(uint8 **);
  void load_state(uint8 **);

  void power();
  void reset();

  DSP();

  SPC_DSP spc_dsp;
};

extern DSP dsp;
