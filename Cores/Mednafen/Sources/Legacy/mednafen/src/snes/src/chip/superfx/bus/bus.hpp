struct SuperFXBus
{
  void init();
  void power();
  void reset();
  uint8 read(uint32 addr);
  void write(uint32 addr, uint8 val);
  uint8* rom_ptr;
  uint8* ram_ptr;
  uint32 ram_mask;
};

struct SuperFXCPUROM : Memory {
  unsigned size() const;
  uint8 read(unsigned);
  void write(unsigned, uint8);
};

struct SuperFXCPURAM : Memory {
  unsigned size() const;
  uint8 read(unsigned);
  void write(unsigned, uint8);
};

namespace memory {
  extern SuperFXCPUROM fxrom;
  extern SuperFXCPURAM fxram;
}
