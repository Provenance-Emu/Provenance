#include "test.h"
#include <stdint.h>
#include <sys/mman.h>

namespace Thread {
  cothread_t host;
  cothread_t cpu;
  cothread_t apu;
}

namespace Buffer {
  uint8_t cpu[65536];
  uint8_t apu[65536];
}

namespace Memory {
  uint8_t* buffer;
}

struct CPU {
  static auto Enter() -> void;
  auto main() -> void;
  auto sub() -> void;
  auto leaf() -> void;
} cpu;

struct APU {
  static auto Enter() -> void;
  auto main() -> void;
  auto sub() -> void;
  auto leaf() -> void;
} apu;

auto CPU::Enter() -> void {
  while(true) cpu.main();
}

auto CPU::main() -> void {
  printf("2\n");
  sub();
}

auto CPU::sub() -> void {
  co_switch(Thread::apu);
  printf("4\n");
  leaf();
}

auto CPU::leaf() -> void {
  int x = 42;
  co_switch(Thread::host);
  printf("6\n");
  co_switch(Thread::apu);
  printf("8 (%d)\n", x);
  co_switch(Thread::host);
}

auto APU::Enter() -> void {
  while(true) apu.main();
}

auto APU::main() -> void {
  printf("3\n");
  sub();
}

auto APU::sub() -> void {
  co_switch(Thread::cpu);
  printf("7\n");
  leaf();
}

auto APU::leaf() -> void {
  co_switch(Thread::cpu);
}

auto main() -> int {
  if(!co_serializable()) {
    printf("This implementation does not support serialization\n");
    return 1;
  }

  Memory::buffer = (uint8_t*)mmap(
    (void*)0x10'0000'0000, 2 * 65536,
    PROT_READ | PROT_WRITE | PROT_EXEC,
    MAP_FIXED | MAP_PRIVATE | MAP_ANONYMOUS, -1, 0
  );
  Memory::buffer[0] = 42;
  printf("%p (%u)\n", Memory::buffer, Memory::buffer[0]);

  Thread::host = co_active();
  Thread::cpu = co_derive((void*)(Memory::buffer + 0 * 65536), 65536, CPU::Enter);
  Thread::apu = co_derive((void*)(Memory::buffer + 1 * 65536), 65536, APU::Enter);

  printf("1\n");
  co_switch(Thread::cpu);

  printf("5\n");
  memcpy(Buffer::cpu, Thread::cpu, 65536);
  memcpy(Buffer::apu, Thread::apu, 65536);
  co_switch(Thread::cpu);

  Thread::cpu = nullptr;
  Thread::apu = nullptr;
  Thread::cpu = co_derive((void*)(Memory::buffer + 0 * 65536), 65536, CPU::Enter);
  Thread::apu = co_derive((void*)(Memory::buffer + 1 * 65536), 65536, APU::Enter);

  printf("9\n");
  memcpy(Thread::cpu, Buffer::cpu, 65536);
  memcpy(Thread::apu, Buffer::apu, 65536);
  co_switch(Thread::cpu);

  Thread::cpu = nullptr;
  Thread::apu = nullptr;
  munmap((void*)0x900000000, 2 * 65536);
  return 0;
}
