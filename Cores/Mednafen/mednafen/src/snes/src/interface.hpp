#ifdef DEBUGGER
  #define debugvirtual virtual
#else
  #define debugvirtual
#endif

namespace bSNES_v059 {
  #include "system/scheduler/scheduler.hpp"
  #include "cheat/cheat.hpp"
  #include "memory/memory.hpp"
  #include "memory/smemory/smemory.hpp"

  #include "ppu/ppu.hpp"

  #include "cpu/cpu.hpp"
  #include "cpu/core/core.hpp"
  #include "cpu/scpu/scpu.hpp"

  #include "smp/smp.hpp"

  #include "sdsp/sdsp.hpp"

  #include "system/system.hpp"
  #include "chip/chip.hpp"
  #include "cartridge/cartridge.hpp"
  //#include "cheat/cheat.hpp"

  #include "memory/memory-inline.hpp"
  #include "ppu/ppu-inline.hpp"
  #include "cheat/cheat-inline.hpp"
};

#undef debugvirtual
