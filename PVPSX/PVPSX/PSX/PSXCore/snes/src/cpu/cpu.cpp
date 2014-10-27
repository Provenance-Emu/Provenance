#include <../base.hpp>

#define CPU_CPP
namespace bSNES_v059 {

#if defined(DEBUGGER)
  #include "cpu-debugger.cpp"
#endif

void CPU::power() {
  cpu_version = config.cpu.version;
}

void CPU::reset() {
  PPUcounter::reset();
}

void CPU::serialize(serializer &s) {
  PPUcounter::serialize(s);
  s.integer(cpu_version);
}

CPU::CPU() {
}

CPU::~CPU() {
}

};
