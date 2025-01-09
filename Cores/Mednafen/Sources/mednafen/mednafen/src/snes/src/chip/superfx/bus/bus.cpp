#ifdef SUPERFX_CPP

SuperFXBus superfxbus;

namespace memory {
  SuperFXCPUROM fxrom;
  SuperFXCPURAM fxram;
}

uint8 SuperFXBus::read(uint32 addr)
{
 static const void* cat_table[8] =
 {
  &&case_0,
  &&case_1,
  &&case_2,
  &&case_3,
  &&case_default, &&case_default, &&case_default, &&case_default
 };

 goto *cat_table[addr >> 21];

  case_0:			// 0x00-0x1F
  case_1:			// 0x20-0x3F
  	while(!superfx.regs.scmr.ron && scheduler.sync != Scheduler::SyncAll)
	{
	 superfx.add_clocks(6);
	 scheduler.sync_copcpu();
	}
	return rom_ptr[((addr & 0x3F0000) >> 1) | (addr & 0x7FFF)];

  case_2:			// 0x40-0x5F
  	while(!superfx.regs.scmr.ron && scheduler.sync != Scheduler::SyncAll)
	{
	 superfx.add_clocks(6);
	 scheduler.sync_copcpu();
	}
	return rom_ptr[addr & 0x1FFFFF];

  case_3:			// 0x60-0x7F
	while(!superfx.regs.scmr.ran && scheduler.sync != Scheduler::SyncAll)
	{
         superfx.add_clocks(6);
         scheduler.sync_copcpu();
        }

	if(ram_ptr)
	 return ram_ptr[addr & ram_mask];

	//puts("ZOO");

	return(0xFF);

  case_default:
	//puts("MOO");
  	return 0xFF;
}

void SuperFXBus::write(uint32 addr, uint8 val)
{
 static const void* cat_table[8] =
 {
  &&case_0,
  &&case_1,
  &&case_2,
  &&case_3,
  &&case_default, &&case_default, &&case_default, &&case_default
 };

 goto *cat_table[addr >> 21];

  case_0:			// 0x00-0x1F
  case_1:			// 0x20-0x3F
	while(!superfx.regs.scmr.ron && scheduler.sync != Scheduler::SyncAll)
	{
    	 superfx.add_clocks(6);
	 scheduler.sync_copcpu();
	}
	return;

  case_2:			// 0x40-0x5F
	while(!superfx.regs.scmr.ron && scheduler.sync != Scheduler::SyncAll)
	{
	 superfx.add_clocks(6);
   	 scheduler.sync_copcpu();
	}
	return;

  case_3:			// 0x60-0x7F
	while(!superfx.regs.scmr.ran && scheduler.sync != Scheduler::SyncAll)
	{
    	 superfx.add_clocks(6);
	 scheduler.sync_copcpu();
	}

	if(ram_ptr)
	 ram_ptr[addr & ram_mask] = val;

	return;

  case_default:
	//puts("MOOW");
	return;
}

void SuperFXBus::init()
{
  rom_ptr = memory::cartrom.data();

  if((int)memory::cartram.size() > 0)
  {
   ram_ptr = memory::cartram.data();
   ram_mask = memory::cartram.size() - 1;
  }
  else
  {
   ram_ptr = NULL;
   ram_mask = 0;
  }

#if 0
  map(MapDirect, 0x00, 0xff, 0x0000, 0xffff, memory::memory_unmapped);

  map(MapLinear, 0x00, 0x3f, 0x0000, 0x7fff, memory::gsurom);
  map(MapLinear, 0x00, 0x3f, 0x8000, 0xffff, memory::gsurom);
  map(MapLinear, 0x40, 0x5f, 0x0000, 0xffff, memory::gsurom);
  map(MapLinear, 0x60, 0x7f, 0x0000, 0xffff, memory::gsuram);
#endif

  bus.map(Bus::MapLinear, 0x00, 0x3f, 0x6000, 0x7fff, memory::fxram, 0x0000, 0x2000);
  bus.map(Bus::MapLinear, 0x00, 0x3f, 0x8000, 0xffff, memory::fxrom);
  bus.map(Bus::MapLinear, 0x40, 0x5f, 0x0000, 0xffff, memory::fxrom);
  bus.map(Bus::MapLinear, 0x60, 0x7d, 0x0000, 0xffff, memory::fxram);
  bus.map(Bus::MapLinear, 0x80, 0xbf, 0x6000, 0x7fff, memory::fxram, 0x0000, 0x2000);
  bus.map(Bus::MapLinear, 0x80, 0xbf, 0x8000, 0xffff, memory::fxrom);
  bus.map(Bus::MapLinear, 0xc0, 0xdf, 0x0000, 0xffff, memory::fxrom);
  bus.map(Bus::MapLinear, 0xe0, 0xff, 0x0000, 0xffff, memory::fxram);
}

//ROM / RAM access from the S-CPU

unsigned SuperFXCPUROM::size() const {
  return memory::cartrom.size();
}

uint8 SuperFXCPUROM::read(unsigned addr) {
  if(superfx.regs.sfr.g && superfx.regs.scmr.ron) {
    static const uint8_t data[16] = {
      0x00, 0x01, 0x00, 0x01, 0x04, 0x01, 0x00, 0x01,
      0x00, 0x01, 0x08, 0x01, 0x00, 0x01, 0x0c, 0x01,
    };
    return data[addr & 15];
  }
  return memory::cartrom.read(addr);
}

void SuperFXCPUROM::write(unsigned addr, uint8 data) {
  memory::cartrom.write(addr, data);
}

unsigned SuperFXCPURAM::size() const {
  return memory::cartram.size();
}

uint8 SuperFXCPURAM::read(unsigned addr) {
  if(superfx.regs.sfr.g && superfx.regs.scmr.ran) return cpu.regs.mdr;
  return memory::cartram.read(addr);
}

void SuperFXCPURAM::write(unsigned addr, uint8 data) {
  memory::cartram.write(addr, data);
}

#endif
