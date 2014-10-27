#ifdef DEBUGGER
  #define debugvirtual virtual
#else
  #define debugvirtual
#endif

namespace bSNES_v059 {
  struct ChipDebugger {
    virtual bool property(unsigned id, string &name, string &value) = 0;
  };

  #include "cheat/cheat.hpp"
  #include "memory/memory.hpp"
  #include "memory/smemory/smemory.hpp"

  #include "ppu/ppu.hpp"

  #include "cpu/cpu.hpp"
  #include "cpu/core/core.hpp"
  #include "cpu/scpu/scpu.hpp"

  #include "smp/smp.hpp"

  #include "dsp/dsp.hpp"
  #include "dsp/sdsp/sdsp.hpp"

  #include "system/system.hpp"
  #include "chip/chip.hpp"
  #include "cartridge/cartridge.hpp"
  //#include "cheat/cheat.hpp"

  #include "memory/memory-inline.hpp"
  #include "ppu/ppu-inline.hpp"
  #include "cheat/cheat-inline.hpp"
};

#undef debugvirtual
