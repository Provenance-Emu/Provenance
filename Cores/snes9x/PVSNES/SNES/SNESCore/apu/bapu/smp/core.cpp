void SMP::tick() {
  timer0.tick();
  timer1.tick();
  timer2.tick();

  clock++;
  dsp.clock++;
}

void SMP::tick(unsigned clocks) {
  timer0.tick(clocks);
  timer1.tick(clocks);
  timer2.tick(clocks);

  clock += clocks;
  dsp.clock += clocks;
}

void SMP::op_io() {
  tick();
}

void SMP::op_io(unsigned clocks) {
  tick(clocks);
}

uint8 SMP::op_read(uint16 addr) {
  tick();
  if((addr & 0xfff0) == 0x00f0) return mmio_read(addr);
  if(addr >= 0xffc0 && status.iplrom_enable) return iplrom[addr & 0x3f];
  return apuram[addr];
}

void SMP::op_write(uint16 addr, uint8 data) {
  tick();
  if((addr & 0xfff0) == 0x00f0) mmio_write(addr, data);
  apuram[addr] = data;  //all writes go to RAM, even MMIO writes
}

uint8 SMP::op_readstack()
{
  tick();
  return apuram[0x0100 | ++regs.sp];
}

void SMP::op_writestack(uint8 data)
{
  tick();
  apuram[0x0100 | regs.sp--] = data;
}

void SMP::op_step() {
  #define op_readpc() op_read(regs.pc++)
  #define op_readdp(addr) op_read((regs.p.p << 8) + ((addr) & 0xff))
  #define op_writedp(addr, data) op_write((regs.p.p << 8) + ((addr) & 0xff), data)
  #define op_readaddr(addr) op_read(addr)
  #define op_writeaddr(addr, data) op_write(addr, data)

  if(opcode_cycle == 0)
  {
#ifdef DEBUGGER
    if (Settings.TraceSMP)
    {
      disassemble_opcode(tmp, regs.pc);
      S9xTraceMessage (tmp);
    }
#endif
    opcode_number = op_readpc();
  }

  switch(opcode_number) {
    #include "core/oppseudo_misc.cpp"
    #include "core/oppseudo_mov.cpp"
    #include "core/oppseudo_pc.cpp"
    #include "core/oppseudo_read.cpp"
    #include "core/oppseudo_rmw.cpp"
  }
}
