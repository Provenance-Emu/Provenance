#ifndef __SNES_HPP
#define __SNES_HPP

#include "snes9x.h"

#define SNES9X

#if defined(__GNUC__)
  #define inline        inline
  #define alwaysinline  inline __attribute__((always_inline))
#elif defined(_MSC_VER)
  #define inline        inline
  #define alwaysinline  inline __forceinline
#else
  #define inline        inline
  #define alwaysinline  inline
#endif

#define debugvirtual

namespace SNES
{

struct Processor
{
    unsigned frequency;
    int32 clock;
};

#include "../smp/smp.hpp"
#include "../dsp/sdsp.hpp"

class CPU
{
public:
    enum { Threaded = false };
    int frequency;
    uint8 registers[4];

    inline void reset ()
    {
        registers[0] = registers[1] = registers[2] = registers[3] = 0;
    }

    alwaysinline void port_write (uint8 port, uint8 data)
    {
        registers[port & 3] = data;
    }

    alwaysinline uint8 port_read (uint8 port)
    {
        return registers[port & 3];
    }
};

extern CPU cpu;

} /* namespace SNES */

#endif
