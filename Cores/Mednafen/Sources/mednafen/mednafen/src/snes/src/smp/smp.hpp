class SMP {
public:
  static const uint8_t iplrom[64];

  #include "core/core.hpp"
  #include "ssmp/ssmp.hpp"

  SMP() {}
  ~SMP() {}
};

#if defined(DEBUGGER)
  #include "debugger/debugger.hpp"
  extern sSMPDebugger smp;
#else
  extern SMP smp;
#endif

