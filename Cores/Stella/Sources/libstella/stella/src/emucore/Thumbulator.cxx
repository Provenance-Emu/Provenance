//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

//============================================================================
// This class provides Thumb emulation code ("Thumbulator")
//    by David Welch (dwelch@dwelch.com)
// Modified by Fred Quimby
// Code is public domain and used with the author's consent
//============================================================================

#include "bspf.hxx"
#include "Base.hxx"
#include "Cart.hxx"
#include "Thumbulator.hxx"
using Common::Base;

// Uncomment the following to enable specific functionality
// WARNING!!! This slows the runtime to a crawl
// #define THUMB_DISS
// #define THUMB_DBUG

#if defined(THUMB_DISS)
  #define DO_DISS(statement) statement
#else
  #define DO_DISS(statement)
#endif
#if defined(THUMB_DBUG)
  #define DO_DBUG(statement) statement
#else
  #define DO_DBUG(statement)
#endif

#ifdef __BIG_ENDIAN__
  #define CONV_DATA(d)   ((((d) & 0xFFFF)>>8) | (((d) & 0xffff)<<8)) & 0xffff
  #define CONV_RAMROM(d) (((d)>>8) | ((d)<<8)) & 0xffff
#else
  #define CONV_DATA(d)   ((d) & 0xFFFF)
  #define CONV_RAMROM(d) (d)
#endif

#ifdef THUMB_CYCLE_COUNT
  #define MERGE_I_S
  #define INC_S_CYCLES(addr, accessType) \
    if(_countCycles)                     \
      incSCycles(addr, accessType)
  #define INC_N_CYCLES(addr, accessType) \
    if(_countCycles)                     \
      incNCycles(addr, accessType)
  #define INC_I_CYCLES                   \
    if(_countCycles)                     \
      incICycles()
  #define INC_I_CYCLES_M(m)              \
    if(_countCycles)                     \
      incICycles(m)

  #define INC_SHIFT_CYCLES               \
    INC_I_CYCLES                         \
    //FETCH_TYPE(CycleType::S, AccessType::data)

  #define INC_LDR_CYCLES                 \
    INC_N_CYCLES(rb, AccessType::data);  \
    INC_I_CYCLES                         \
    /*FETCH_TYPE(CycleType::N, AccessType::data); \
      FETCH_TYPE_N;*/
  #define INC_LDRB_CYCLES                       \
    INC_N_CYCLES(rb & (~1U), AccessType::data); \
    INC_I_CYCLES                                \
    /*FETCH_TYPE(CycleType::N, AccessType::data); \
      FETCH_TYPE_N;*/

  #define INC_STR_CYCLES                 \
    INC_N_CYCLES(rb, AccessType::data);  \
    FETCH_TYPE_N                         \
    //INC_N_CYCLES(rb, AccessType::data);
  #define INC_STRB_CYCLES                       \
    INC_N_CYCLES(rb & (~1U), AccessType::data); \
    FETCH_TYPE_N                                \
    //INC_N_CYCLES(rb & (~1U), AccessType::data);

#if 0 // unused for now
  #define FETCH_TYPE(cycleType, accessType) \
    _prefetchCycleType[_pipeIdx] = cycleType; \
    _prefetchAccessType[_pipeIdx] = accessType
#endif
  #define FETCH_TYPE_N                          \
    _prefetchCycleType[_pipeIdx] = CycleType::N

  // ARM cycles
  #define INC_ARM_CYCLES(m) \
    _totalCycles += m
#else
  #define INC_S_CYCLES(addr, accessType)
  #define INC_N_CYCLES(addr, accessType)
  #define INC_I_CYCLES
  #define INC_I_CYCLES_M(m)

  #define INC_SHIFT_CYCLES

  #define INC_LDR_CYCLES
  #define INC_LDRB_CYCLES

  #define INC_STR_CYCLES
  #define INC_STRB_CYCLES

  #define FETCH_TYPE(cycleType, accessType)
  #define FETCH_TYPE_N

  // ARM cycles
  #define INC_ARM_CYCLES(m)
#endif

#ifdef THUMB_STATS
  #define THUMB_STAT(statement) ++statement;
#else
  #define THUMB_STAT(statement)
#endif

#define do_znflags(x) znFlags=(x)
#define do_cflag_bit(x) cFlag = (x)
#define do_vflag_bit(x) vFlag = (x)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Thumbulator::Thumbulator(const uInt16* rom_ptr, uInt16* ram_ptr, uInt32 rom_size,
                         const uInt32 c_base, const uInt32 c_start, const uInt32 c_stack,
                         bool traponfatal, double cyclefactor,
                         Thumbulator::ConfigureFor configurefor,
                         Cartridge* cartridge)
  : rom{rom_ptr},
    romSize{rom_size},
    cBase{c_base},
    cStart{c_start},
    cStack{c_stack},
    decodedRom{make_unique<Op[]>(romSize / 2)},  // NOLINT
    decodedParam{make_unique<uInt32[]>(romSize / 2)},  // NOLINT
    ram{ram_ptr},
    configuration{configurefor},
    myCartridge{cartridge}
{
  for(uInt32 i = 0; i < romSize / 2; ++i)
    decodedRom[i] = decodeInstructionWord(CONV_RAMROM(rom[i]), i * 2);

  setConsoleTiming(ConsoleTiming::ntsc);
#ifndef UNSAFE_OPTIMIZATIONS
  trapFatalErrors(traponfatal);
#endif
#ifdef DEBUGGER_SUPPORT
  cycleFactor(cyclefactor);
#endif
  reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Thumbulator::doRun(uInt32& cycles, bool irqDrivenAudio)
{
  _irqDrivenAudio = irqDrivenAudio;
  reset();
  for(;;)
  {
    if(execute()) break;
#ifndef UNSAFE_OPTIMIZATIONS
    if(_stats.instructions > 500000) // way more than would otherwise be possible
      throw runtime_error("instructions > 500000");
#endif
  }
#ifdef THUMB_CYCLE_COUNT
  _totalCycles *= _armCyclesFactor;

  // assuming 10% per scanline is spend for audio updates
  // (equals 5 cycles 6507 code + ~130-155 cycles ARM code)
  if(_irqDrivenAudio)
    _totalCycles *= 1.10;

  //_totalCycles = 127148; // VB during Turbo start sequence
  cycles = _totalCycles / timing_factor;
#else
  cycles = 0;
#endif
#if defined(THUMB_DISS) || defined(THUMB_DBUG)
  dump_counters();
  cout << statusMsg.str() << '\n';
  return statusMsg.str();
#else
  return "";
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::setConsoleTiming(ConsoleTiming timing)
{
  // this sets how many ticks of the Harmony/Melody clock
  // will occur per tick of the 6507 clock
  constexpr double NTSC   = 1.19318166666667;  // NTSC  6507 clock rate
  constexpr double PAL    = 1.182298;          // PAL   6507 clock rate
  constexpr double SECAM  = 1.187500;          // SECAM 6507 clock rate

  _consoleTiming = timing;
  switch(timing)
  {
    case ConsoleTiming::ntsc:   timing_factor = _MHz / NTSC;   break;
    case ConsoleTiming::pal:    timing_factor = _MHz / PAL;    break;
    case ConsoleTiming::secam:  timing_factor = _MHz / SECAM;  break;
    default:  break;  // satisfy compiler
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::updateTimer(uInt32 cycles)
{
#ifdef TIMER_0
  if(T0TCR & 1) // bit 0 controls timer on/off
  {
    T0TC += static_cast<uInt32>(cycles * timing_factor);
    tim0Total = tim0Start = 0;
  }
#endif
  if(T1TCR & 1) // bit 0 controls timer on/off
  {
    T1TC += static_cast<uInt32>(cycles * timing_factor);
    tim1Total = tim1Start = 0;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Thumbulator::run(uInt32& cycles, bool irqDrivenAudio)
{
  updateTimer(cycles);
  return doRun(cycles, irqDrivenAudio);
}

#ifndef UNSAFE_OPTIMIZATIONS
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Thumbulator::fatalError(string_view opcode, uInt32 v1, string_view msg)
{
  statusMsg << "Thumb ARM emulation fatal error:\n"
            << opcode << "(" << Base::HEX8 << v1 << "), " << msg << '\n';
  dump_regs();
  if(trapOnFatal)
    throw runtime_error(statusMsg.str());
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Thumbulator::fatalError(string_view opcode, uInt32 v1, uInt32 v2,
                            string_view msg)
{
  statusMsg << "Thumb ARM emulation fatal error:\n"
            << opcode << "(" << Base::HEX8 << v1 << "," << v2 << "), " << msg
            << '\n';
  dump_regs();
  if(trapOnFatal)
    throw runtime_error(statusMsg.str());
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::dump_counters() const
{
  cout << "\n\ninstructions " << _stats.instructions << '\n';
#ifdef THUMB_STATS
  cout << "reads        " << _stats.reads << '\n'
       << "writes       " << _stats.writes << '\n'
       << "memcycles    " << (_stats.instructions + _stats.reads + _stats.writes) << '\n';
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::dump_regs()
{
  for(int cnt = 0; cnt <= 12; ++cnt)
  {
    statusMsg << "R" << std::dec << std::setfill(' ') << std::setw(2) << std::left << cnt
      << "= " << Base::HEX8 << reg_norm[cnt];
    if((cnt + 1) % 4 == 0)
      statusMsg << '\n';
    else
      statusMsg << "  ";
  }
  statusMsg << "\nSP = " << Base::HEX8 << reg_norm[13] << "  "
            << "LR = " << Base::HEX8 << reg_norm[14] << "  "
            << "PC = " << Base::HEX8 << reg_norm[15] << '\n';
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE uInt32 Thumbulator::fetch16(uInt32 addr)
{
#ifndef UNSAFE_OPTIMIZATIONS
  uInt32 data = 0;

#ifdef THUMB_CYCLE_COUNT
  _pipeIdx = (_pipeIdx+1) % 3;

#ifdef MERGE_I_S
  if(_lastCycleType[2] == CycleType::I)
  //if(_lastCycleType[_pipeIdx] == CycleType::I)
    --_totalCycles;
#endif

  if(_prefetchCycleType[_pipeIdx] == CycleType::S)
  {
  //#ifdef MERGE_I_S
  //  //if(_lastCycleType[2] == CycleType::I)
  //  if(_lastCycleType[_pipeIdx] == CycleType::I)
  //  {
  //    --_totalCycles;
  //    INC_S_CYCLES(addr, AccessType::prefetch); // N?
  //  }
  //  else
  //#endif
      INC_S_CYCLES(addr, AccessType::prefetch);
      //INC_S_CYCLES(addr, _prefetchAccessType[_pipeIdx]);
  }
  else
  {
    INC_N_CYCLES(addr, AccessType::prefetch); // or ::data ?
    //INC_N_CYCLES(addr, _prefetchAccessType[_pipeIdx]);
  }
  _prefetchCycleType[_pipeIdx] = CycleType::S; // default
  //_prefetchAccessType[_pipeIdx] = AccessType::prefetch; // default
#endif

  switch(addr & 0xF0000000)
  {
    case 0x00000000: //ROM
      addr &= ROMADDMASK;
      if(addr < 0x50)
        fatalError("fetch16", addr, "abort");
      addr >>= 1;
      data = CONV_RAMROM(rom[addr]);
      DO_DBUG(statusMsg << "fetch16(" << Base::HEX8 << addr << ")=" << Base::HEX4 << data << '\n');
      return data;

    case 0x40000000: //RAM
      addr &= RAMADDMASK;
      addr >>= 1;
      data = CONV_RAMROM(ram[addr]);
      DO_DBUG(statusMsg << "fetch16(" << Base::HEX8 << addr << ")=" << Base::HEX4 << data << '\n');
      return data;

    default:  // reserved
      break;
  }
  return fatalError("fetch16", addr, "abort");
#else
  addr &= ROMADDMASK;
  addr >>= 1;
  return CONV_RAMROM(rom[addr]);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::write16(uInt32 addr, uInt32 data)
{
#ifndef UNSAFE_OPTIMIZATIONS
  if(addr & 1)
    fatalError("write16", addr, "abort - misaligned");
#endif
  THUMB_STAT(_stats.writes)
  DO_DBUG(statusMsg << "write16(" << Base::HEX8 << addr << "," << Base::HEX8 << data << ")\n");

  switch(addr & 0xF0000000) // NOLINT (missing default for UNSAFE_OPTIMIZATIONS)
  {
    case 0x40000000: //RAM
#ifndef UNSAFE_OPTIMIZATIONS
      if(isInvalidRAM(addr))
        fatalError("write16", addr, "abort - out of range");
      if(isProtectedRAM(addr))
        fatalError("write16", addr, "to driver area");
#endif
      addr &= RAMADDMASK;
      addr >>= 1;
      ram[addr] = CONV_DATA(data);
      return;

#ifndef UNSAFE_OPTIMIZATIONS
    case 0xE0000000: //MAMCR
#else
    default:
#endif
      if(addr == 0xE01FC000)
      {
        DO_DBUG(statusMsg << "write16(" << Base::HEX8 << "MAMCR" << "," << Base::HEX8 << data << ") *\n");
        if(!_lockMamcr)
          mamcr = static_cast<MamModeType>(data);
        return;
      }
  }
#ifndef UNSAFE_OPTIMIZATIONS
  fatalError("write16", addr, data, "abort");
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::write32(uInt32 addr, uInt32 data)
{
#ifndef UNSAFE_OPTIMIZATIONS
  if(addr & 3)
    fatalError("write32", addr, "abort - misaligned");
#endif
  DO_DBUG(statusMsg << "write32(" << Base::HEX8 << addr << "," << Base::HEX8 << data << ")\n");

  switch(addr & 0xF0000000) // NOLINT (missing default for UNSAFE_OPTIMIZATIONS)
  {
#ifndef UNSAFE_OPTIMIZATIONS
    case 0xF0000000: //halt
      dump_counters();
      throw runtime_error("HALT");
#endif

    case 0xE0000000: //periph
      switch(addr)
      {
#ifndef UNSAFE_OPTIMIZATIONS
        case 0xE0000000:
          DO_DISS(statusMsg << "uart: [" << char(data&0xFF) << "]\n");
          break;
#endif
#ifdef TIMER_0
        case 0xE0004004:  // T0TCR - Timer 0 Control Register
        #ifdef THUMB_CYCLE_COUNT
          if((T0TCR ^ data) & 1)
          {
            // timer changed counter state
            if(data & 1)
              // timer switched to counting
              tim0Start = _totalCycles;
            else
              // timer switched to disabled
              tim0Total += _totalCycles - tim0Start;
          }
        #endif
          T0TCR = data;
          break;

        case 0xE0004008:  // T0TC - Timer 0 Counter
        #ifdef THUMB_CYCLE_COUNT
          tim0Start = _totalCycles;
          tim0Total = data / _armCyclesFactor;
        #endif
          T0TC = data;
          break;
#endif
        case 0xE0008004:  // T1TCR - Timer 1 Control Register
        #ifdef THUMB_CYCLE_COUNT
          if((T1TCR ^ data) & 1)
          {
            // timer changed counter state
            if(data & 1)
              // timer switched to counting
              tim1Start = _totalCycles;
            else
              // timer switched to disabled
              tim1Total += _totalCycles - tim1Start;
          }
        #endif
          T1TCR = data;
          break;

        case 0xE0008008:  // T1TC - Timer 1 Counter
        #ifdef THUMB_CYCLE_COUNT
          tim1Start = _totalCycles;
          tim1Total = data / _armCyclesFactor;
        #endif
          T1TC = data;
          break;

        case 0xE000E010:
        {
          const uInt32 old = systick_ctrl;
          systick_ctrl = data & 0x00010007;
          if(((old & 1) == 0) && (systick_ctrl & 1))
          {
            // timer started, load count
            systick_count = systick_reload;
          }
          break;
        }

        case 0xE000E014:
          systick_reload = data & 0x00FFFFFF;
          break;

        case 0xE000E018:
          systick_count = data & 0x00FFFFFF;
          break;

        case 0xE000E01C:
          systick_calibrate = data & 0x00FFFFFF;
          break;

      #ifdef THUMB_CYCLE_COUNT
        case 0xE01FC000: //MAMCR
          DO_DBUG(statusMsg << "write32(" << Base::HEX8 << "MAMCR" << ","
                  << Base::HEX8 << data << ") *\n");
          if(!_lockMamcr)
            mamcr = static_cast<MamModeType>(data);
          break;
      #endif

        default:
          break;
      }
      return;

    case 0xD0000000: //debug
#ifndef UNSAFE_OPTIMIZATIONS
      switch(addr & 0xFF)
      {
        case 0x00:
          statusMsg << "[" << Base::HEX8 << read_register(14) << "]["
                    << addr << "] " << data << '\n';
          return;

        case 0x10:
          statusMsg << Base::HEX8 << data << '\n';
          return;

        case 0x20:
          statusMsg << Base::HEX8 << data << '\n';
          return;

        default:
          break;
      }
#endif
      return;

#ifndef UNSAFE_OPTIMIZATIONS
    case 0x40000000: //RAM
#else
    default:
#endif
      write16(addr+0, (data >>  0) & 0xFFFF);
      write16(addr+2, (data >> 16) & 0xFFFF);
      return;
  }
#ifndef UNSAFE_OPTIMIZATIONS
  fatalError("write32", addr, data, "abort");
#endif
}

#ifndef UNSAFE_OPTIMIZATIONS
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE bool Thumbulator::isInvalidROM(uInt32 addr) const
{
  const uInt32 romStart = configuration == ConfigureFor::DPCplus ? 0xc00 : 0x750; // was 0x800

  return addr < romStart || addr >= romSize; // CDFJ+ allows ROM sizes larger than 32 KB
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE bool Thumbulator::isInvalidRAM(uInt32 addr) const
{
  // Note: addr is already checked for RAM (0x4xxxxxxx)
  switch(romSize) // CDFJ+ allows more than 8 KB RAM depending on ROM sizes
  {
    case 64_KB:
    case 128_KB:
      return addr > 0x40003fff; // 16 KB

    case 256_KB:
    case 512_KB:
      return addr > 0x40007fff; // 32 KB

    default: // assuming 32 KB
      return addr > 0x40001fff; // 8 KB
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE bool Thumbulator::isProtectedRAM(uInt32 addr)
{
  // Protected is within the driver RAM.
  // For CDF variations parts of the driver RAM are reused to hold the
  // datastream information, so are not write protected.
  // Additionally for CDFJ+ the Fast Fetcher offset is not write protected.

  if (addr < 0x40000000) return false;
  addr -= 0x40000000;

  switch(configuration) {
    case ConfigureFor::DPCplus:
      return (addr < 0x0c00) && (addr > 0x0028);

    case ConfigureFor::CDF:
      return (addr < 0x0800) && (addr > 0x0028) && !((addr >= 0x06e0) && (addr < (0x0e60 + 284)));

    case ConfigureFor::CDF1:
      return (addr < 0x0800) && (addr > 0x0028) && !((addr >= 0x00a0) && (addr < (0x00a0 + 284)));

    case ConfigureFor::CDFJ:
      return (addr < 0x0800) && (addr > 0x0028) && !((addr >= 0x0098) && (addr < (0x0098 + 292)));

    case ConfigureFor::CDFJplus:
      return (addr < 0x0800) && (addr > 0x0028) && !((addr >= 0x0098) && (addr < (0x0098 + 292))) && addr != 0x3E0;

    case ConfigureFor::BUS:
      return (addr < 0x06d8) && (addr > 0x0028);
  }

  return false;
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 Thumbulator::read16(uInt32 addr)
{
  uInt32 data = 0;
#ifndef UNSAFE_OPTIMIZATIONS
  if(addr & 1)
    fatalError("read16", addr, "abort - misaligned");
#endif
  THUMB_STAT(_stats.reads)

  switch(addr & 0xF0000000) // NOLINT (missing default for UNSAFE_OPTIMIZATIONS)
  {
    case 0x00000000: //ROM
#ifndef UNSAFE_OPTIMIZATIONS
      if(isInvalidROM(addr))
        fatalError("read16", addr, "abort - out of range");
#endif
      addr &= ROMADDMASK;
      addr >>= 1;
      data = CONV_RAMROM(rom[addr]);
      DO_DBUG(statusMsg << "read16(" << Base::HEX8 << addr << ")=" << Base::HEX4 << data << '\n');
      return data;

    case 0x40000000: //RAM
#ifndef UNSAFE_OPTIMIZATIONS
      if(isInvalidRAM(addr))
        fatalError("read16", addr, "abort - out of range");
#endif
      addr &= RAMADDMASK;
      addr >>= 1;
      data = CONV_RAMROM(ram[addr]);
      DO_DBUG(statusMsg << "read16(" << Base::HEX8 << addr << ")=" << Base::HEX4 << data << '\n');
      return data;

    case 0xe0000000: //peripherals
    #ifdef THUMB_CYCLE_COUNT
      if(addr == 0xE01FC000) //MAMCR
    #else
    default:
    #endif
      {
        DO_DBUG(statusMsg << "read32(" << "MAMCR" << addr << ")=" << mamcr << " *");
        data = static_cast<uInt32>(mamcr);
        return data;
      }
  }
#ifndef UNSAFE_OPTIMIZATIONS
  return fatalError("read16", addr, "abort");
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 Thumbulator::read32(uInt32 addr)
{
#ifndef UNSAFE_OPTIMIZATIONS
  if(addr & 3)
    fatalError("read32", addr, "abort - misaligned");
#endif

  uInt32 data = 0;
  switch(addr & 0xF0000000) // NOLINT (missing default for UNSAFE_OPTIMIZATIONS)
  {
    case 0x00000000: //ROM
#ifndef UNSAFE_OPTIMIZATIONS
      if(isInvalidROM(addr))
        fatalError("read32", addr, "abort - out of range");
#endif
      data = read16(addr+0);
      data |= read16(addr+2) << 16;
      DO_DBUG(statusMsg << "read32(" << Base::HEX8 << addr << ")=" << Base::HEX8 << data << '\n');
      return data;

    case 0x40000000: //RAM
#ifndef UNSAFE_OPTIMIZATIONS
      if(isInvalidRAM(addr))
        fatalError("read32", addr, "abort - out of range");
#endif
      data = read16(addr+0);
      data |= read16(addr+2) << 16;
      DO_DBUG(statusMsg << "read32(" << Base::HEX8 << addr << ")=" << Base::HEX8 << data << '\n');
      return data;

#ifndef UNSAFE_OPTIMIZATIONS
    case 0xE0000000:
#else
    default:
#endif
    {
      switch(addr)  // NOLINT  (FIXME: missing default)
      {
      #ifdef THUMB_CYCLE_COUNT
        case 0xE01FC000: //MAMCR
          DO_DBUG(statusMsg << "read32(" << "MAMCR" << addr << ")=" << mamcr << " *");
          data = static_cast<uInt32>(mamcr);
          return data;
      #endif

      #ifdef TIMER_0
        case 0xE0004004:  // T0TCR - Timer 0 Control Register
          data = T0TCR;
          return data;

        case 0xE0004008:  // T0TC - Timer 0 Counter
        #ifdef THUMB_CYCLE_COUNT
          if(T0TCR & 1)
            // timer is counting
            data = T0TC + (tim0Total + (_totalCycles - tim0Start)) * _armCyclesFactor;  // NOLINT
          else
            // timer is disabled
            data = T0TC + tim0Total * _armCyclesFactor;  // NOLINT
        #else
          data = T0TC;  // NOLINT
        #endif
          break;
      #endif
        case 0xE0008004:  // T1TCR - Timer 1 Control Register
          data = T1TCR;
          return data;

        case 0xE0008008:  // T1TC - Timer 1 Counter
        #ifdef THUMB_CYCLE_COUNT
          if(T1TCR & 1)
            // timer is counting
            data = T1TC + (tim1Total + (_totalCycles - tim1Start)) * _armCyclesFactor;
          else
            // timer is disabled
            data = T1TC + tim1Total * _armCyclesFactor;
        #else
          data = T1TC;
        #endif
          return data;

        case 0xE000E010:
          data = systick_ctrl;
          systick_ctrl &= (~0x00010000);
          return data;

        case 0xE000E014:
          data = systick_reload;
          return data;

        case 0xE000E018:
          data = systick_count;
          return data;

#ifndef UNSAFE_OPTIMIZATIONS
        case 0xE000E01C:
#else
        default:
#endif
          data = systick_calibrate;
          return data;
      }
    }
  }
#ifndef UNSAFE_OPTIMIZATIONS
  return fatalError("read32", addr, "abort");
#endif
}

#ifndef UNSAFE_OPTIMIZATIONS
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE uInt32 Thumbulator::read_register(uInt32 reg)
{
  reg &= 0xF;
  uInt32 data = reg_norm[reg];
  DO_DBUG(statusMsg << "read_register(" << dec << reg << ")=" << Base::HEX8 << data << '\n');
  if(reg == 15)
  {
    if(data & 1)
    {
      DO_DBUG(statusMsg << "pc has lsbit set 0x" << Base::HEX8 << data << '\n');
      data &= ~1;
    }
  }
  return data;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void Thumbulator::write_register(uInt32 reg, uInt32 data, bool isFlowBreak)
{
  reg &= 0xF;
  DO_DBUG(statusMsg << "write_register(" << dec << reg << "," << Base::HEX8 << data << ")\n");
  if(reg == 15)
  {
    data &= ~1;
    if(isFlowBreak)
    {
      THUMB_STAT(_stats.taken)
      // dummy fetch + fill the pipeline
      //INC_N_CYCLES(reg_norm[15] - 2, AccessType::prefetch);
      //INC_S_CYCLES(data - 2, AccessType::branch);
      INC_N_CYCLES(reg_norm[15] + 4, AccessType::prefetch);
      INC_S_CYCLES(data, AccessType::branch);
    }
  }
  reg_norm[reg] = data;
}
#else
  #define read_register(reg)        reg_norm[reg]
  #define write_register(reg, data) reg_norm[reg]=(data)
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::do_cvflag(uInt32 a, uInt32 b, uInt32 c)
{
  uInt32 rc = (a & 0x7FFFFFFF) + (b & 0x7FFFFFFF) + c; //carry in
  rc >>= 31; //carry in in lsbit
  a >>= 31;
  b >>= 31;
  uInt32 rd = (rc & 1) + (a & 1) + (b & 1); //carry out
  rd >>= 1; //carry out in lsbit

  vFlag = (rc ^ rd) & 1; //if carry in != carry out then signed overflow

  rc += a + b;             //carry out
  cFlag = rc & 2;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Thumbulator::Op Thumbulator::decodeInstructionWord(uint16_t inst, uInt32 pc) {
  //ADC add with carry
  if((inst & 0xFFC0) == 0x4140) return Op::adc;

  //ADD(1) small immediate two registers
  if((inst & 0xFE00) == 0x1C00 && (inst >> 6) & 0x7) return Op::add1;

  //ADD(2) big immediate one register
  if((inst & 0xF800) == 0x3000) return Op::add2;

  //ADD(3) three registers
  if((inst & 0xFE00) == 0x1800) return Op::add3;

  //ADD(4) two registers one or both high no flags
  if((inst & 0xFF00) == 0x4400) return Op::add4;

  //ADD(5) rd = pc plus immediate
  if((inst & 0xF800) == 0xA000) return Op::add5;

  //ADD(6) rd = sp plus immediate
  if((inst & 0xF800) == 0xA800) return Op::add6;

  //ADD(7) sp plus immediate
  if((inst & 0xFF80) == 0xB000) return Op::add7;

  //AND
  if((inst & 0xFFC0) == 0x4000) return Op::and_;

  //ASR(1) two register immediate
  if((inst & 0xF800) == 0x1000) return Op::asr1;

  //ASR(2) two register
  if((inst & 0xFFC0) == 0x4100) return Op::asr2;

  //B(1) conditional branch, decoded into its variants
  if((inst & 0xF000) == 0xD000)
  {
    const uInt32 op = (inst >> 8) & 0xF;
    uInt32 rb = inst & 0xFF;

    if(rb & 0x80)
      rb |= (~0U) << 8;
    rb <<= 1;
    rb += pc;
    rb += 2;
    decodedParam[pc / 2] = rb + 4;

    switch(op)
    {
      case 0x0: //b eq  z set
        return Op::beq;

      case 0x1: //b ne  z clear
        return Op::bne;

      case 0x2: //b cs c set
        return Op::bcs;

      case 0x3: //b cc c clear
        return Op::bcc;

      case 0x4: //b mi n set
        return Op::bmi;

      case 0x5: //b pl n clear
        return Op::bpl;

      case 0x6: //b vs v set
        return Op::bvs;

      case 0x7: //b vc v clear
        return Op::bvc;

      case 0x8: //b hi c set z clear
        return Op::bhi;

      case 0x9: //b ls c clear or z set
        return Op::bls;

      case 0xA: //b ge N == V
        return Op::bge;

      case 0xB: //b lt N != V
        return Op::blt;

      case 0xC: //b gt Z==0 and N == V
        return Op::bgt;

      case 0xD: //b le Z==1 or N != V
        return Op::ble;

      default:
        return Op::invalid;
    }
  }

  //B(2) unconditional branch
  if((inst & 0xF800) == 0xE000)
  {
    uInt32 rb = (inst >> 0) & 0x7FF;

    if(rb & (1 << 10))
      rb |= (~0U) << 11;
    rb <<= 1;
    rb += pc;
    rb += 2;
    decodedParam[pc / 2] = rb + 4;

    return Op::b2;
  }

  //BIC
  if((inst & 0xFFC0) == 0x4380) return Op::bic;

  //BKPT
  if((inst & 0xFF00) == 0xBE00) return Op::bkpt;

  //BL/BLX(1) decoded into its variants
  if((inst & 0xE000) == 0xE000)
  {
    if((inst & 0x1800) == 0x1000) return Op::bl;
    else if((inst & 0x1800) == 0x1800) return Op::blx_thumb;
    else if((inst & 0x1800) == 0x0800) return Op::blx_arm;
    return Op::invalid;
  }

  //BLX(2)
  if((inst & 0xFF87) == 0x4780) return Op::blx2;

  //BX
  if((inst & 0xFF87) == 0x4700) return Op::bx;

  //CMN
  if((inst & 0xFFC0) == 0x42C0) return Op::cmn;

  //CMP(1) compare immediate
  if((inst & 0xF800) == 0x2800) return Op::cmp1;

  //CMP(2) compare register
  if((inst & 0xFFC0) == 0x4280) return Op::cmp2;

  //CMP(3) compare high register
  if((inst & 0xFF00) == 0x4500) return Op::cmp3;

  //CPS
  if((inst & 0xFFE8) == 0xB660) return Op::cps;

  //CPY copy high register
  if((inst & 0xFFC0) == 0x4600) return Op::cpy;

  //EOR
  if((inst & 0xFFC0) == 0x4040) return Op::eor;

  //LDMIA
  if((inst & 0xF800) == 0xC800) return Op::ldmia;

  //LDR(1) two register immediate
  if((inst & 0xF800) == 0x6800) return Op::ldr1;

  //LDR(2) three register
  if((inst & 0xFE00) == 0x5800) return Op::ldr2;

  //LDR(3)
  if((inst & 0xF800) == 0x4800) return Op::ldr3;

  //LDR(4)
  if((inst & 0xF800) == 0x9800) return Op::ldr4;

  //LDRB(1)
  if((inst & 0xF800) == 0x7800) return Op::ldrb1;

  //LDRB(2)
  if((inst & 0xFE00) == 0x5C00) return Op::ldrb2;

  //LDRH(1)
  if((inst & 0xF800) == 0x8800) return Op::ldrh1;

  //LDRH(2)
  if((inst & 0xFE00) == 0x5A00) return Op::ldrh2;

  //LDRSB
  if((inst & 0xFE00) == 0x5600) return Op::ldrsb;

  //LDRSH
  if((inst & 0xFE00) == 0x5E00) return Op::ldrsh;

  //LSL(1)
  if((inst & 0xF800) == 0x0000) return Op::lsl1;

  //LSL(2) two register
  if((inst & 0xFFC0) == 0x4080) return Op::lsl2;

  //LSR(1) two register immediate
  if((inst & 0xF800) == 0x0800) return Op::lsr1;

  //LSR(2) two register
  if((inst & 0xFFC0) == 0x40C0) return Op::lsr2;

  //MOV(1) immediate
  if((inst & 0xF800) == 0x2000) return Op::mov1;

  //MOV(2) two low registers
  if((inst & 0xFFC0) == 0x1C00) return Op::mov2;

  //MOV(3)
  if((inst & 0xFF00) == 0x4600) return Op::mov3;

  //MUL
  if((inst & 0xFFC0) == 0x4340) return Op::mul;

  //MVN
  if((inst & 0xFFC0) == 0x43C0) return Op::mvn;

  //NEG
  if((inst & 0xFFC0) == 0x4240) return Op::neg;

  //ORR
  if((inst & 0xFFC0) == 0x4300) return Op::orr;

  //POP
  if((inst & 0xFE00) == 0xBC00) return Op::pop;

  //PUSH
  if((inst & 0xFE00) == 0xB400) return Op::push;

  //REV
  if((inst & 0xFFC0) == 0xBA00) return Op::rev;

  //REV16
  if((inst & 0xFFC0) == 0xBA40) return Op::rev16;

  //REVSH
  if((inst & 0xFFC0) == 0xBAC0) return Op::revsh;

  //ROR
  if((inst & 0xFFC0) == 0x41C0) return Op::ror;

  //SBC
  if((inst & 0xFFC0) == 0x4180) return Op::sbc;

  //SETEND
  if((inst & 0xFFF7) == 0xB650) return Op::setend;

  //STMIA
  if((inst & 0xF800) == 0xC000) return Op::stmia;

  //STR(1)
  if((inst & 0xF800) == 0x6000) return Op::str1;

  //STR(2)
  if((inst & 0xFE00) == 0x5000) return Op::str2;

  //STR(3)
  if((inst & 0xF800) == 0x9000) return Op::str3;

  //STRB(1)
  if((inst & 0xF800) == 0x7000) return Op::strb1;

  //STRB(2)
  if((inst & 0xFE00) == 0x5400) return Op::strb2;

  //STRH(1)
  if((inst & 0xF800) == 0x8000) return Op::strh1;

  //STRH(2)
  if((inst & 0xFE00) == 0x5200) return Op::strh2;

  //SUB(1)
  if((inst & 0xFE00) == 0x1E00) return Op::sub1;

  //SUB(2)
  if((inst & 0xF800) == 0x3800) return Op::sub2;

  //SUB(3)
  if((inst & 0xFE00) == 0x1A00) return Op::sub3;

  //SUB(4)
  if((inst & 0xFF80) == 0xB080) return Op::sub4;

  //SWI SoftWare Interupt
  if((inst & 0xFF00) == 0xDF00) return Op::swi;

  //SXTB
  if((inst & 0xFFC0) == 0xB240) return Op::sxtb;

  //SXTH
  if((inst & 0xFFC0) == 0xB200) return Op::sxth;

  //TST
  if((inst & 0xFFC0) == 0x4200) return Op::tst;

  //UXTB
  if((inst & 0xFFC0) == 0xB2C0) return Op::uxtb;

  //UXTH Zero extend Halfword
  if((inst & 0xFFC0) == 0xB280) return Op::uxth;

  return Op::invalid;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE int Thumbulator::execute()  // NOLINT (readability-function-size)
{
  uInt32 sp, inst, ra, rb, rc, rm, rd, rn, rs;  // NOLINT

#ifndef UNSAFE_OPTIMIZATIONS
  uInt32 pc = read_register(15);
#else
  uInt32 pc = read_register(15) & ~1; // not checked and corrected in read_register
#endif

  const uInt32 instructionPtr = pc - 2;
  const uInt32 instructionPtr2 = instructionPtr >> 1;
  inst = fetch16(instructionPtr);

  pc += 2;
#ifndef UNSAFE_OPTIMIZATIONS
  write_register(15, pc, false);
#else
  write_register(15, pc);
#endif
  DO_DISS(statusMsg << Base::HEX8 << (pc-5) << ": " << Base::HEX4 << inst << " ");

#ifndef UNSAFE_OPTIMIZATIONS
  ++_stats.instructions;
#endif

  Op decodedOp{};
#ifndef UNSAFE_OPTIMIZATIONS
  if ((instructionPtr & 0xF0000000) == 0 && instructionPtr < romSize)
    decodedOp = decodedRom[instructionPtr2];
  else
    decodedOp = decodeInstructionWord(CONV_RAMROM(rom[instructionPtr2]), instructionPtr);
#else
  decodedOp = decodedRom[(instructionPtr & ROMADDMASK) >> 1];
#endif

#ifdef COUNT_OPS
  ++opCount[static_cast<int>(decodedOp)];
#endif
  switch (decodedOp) {
    //ADC
    case Op::adc: {
      rd = (inst >> 0) & 0x07;
      rm = (inst >> 3) & 0x07;
      DO_DISS(statusMsg << "adc r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra + rb;
      if(cFlag)
        ++rc;
      write_register(rd, rc);
      do_znflags(rc);
      if(cFlag) do_cvflag(ra, rb, 1);
      else      do_cvflag(ra, rb, 0);
      return 0;
    }

    //ADD(1) small immediate two registers
    case Op::add1: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rb = (inst >> 6) & 0x7;
      if(rb)
      {
        DO_DISS(statusMsg << "adds r" << dec << rd << ",r" << dec << rn << ","
                          << "#0x" << Base::HEX2 << rb << '\n');
        ra = read_register(rn);
        rc = ra + rb;
        //fprintf(stderr,"0x%08X = 0x%08X + 0x%08X\n",rc,ra,rb);
        write_register(rd, rc);
        do_znflags(rc);
        do_cvflag(ra, rb, 0);
        return 0;
      }
      else
      {
        //this is a mov
      }
      break;
    }

    //ADD(2) big immediate one register
    case Op::add2: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x7;
      DO_DISS(statusMsg << "adds r" << dec << rd << ",#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(rd);
      rc = ra + rb;
      write_register(rd, rc);
      do_znflags(rc);
      do_cvflag(ra, rb, 0);
      return 0;
    }

    //ADD(3) three registers
    case Op::add3: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "adds r" << dec << rd << ",r" << dec << rn << ",r" << rm << '\n');
      ra = read_register(rn);
      rb = read_register(rm);
      rc = ra + rb;
      write_register(rd, rc);
      do_znflags(rc);
      do_cvflag(ra, rb, 0);
      return 0;
    }

    //ADD(4) two registers one or both high no flags
    case Op::add4: {
      if((inst >> 6) & 3)
      {
        //UNPREDICTABLE
      }
      rd  = (inst >> 0) & 0x7;
      rd |= (inst >> 4) & 0x8;
      rm  = (inst >> 3) & 0xF;
      DO_DISS(statusMsg << "add r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra + rb;
      if(rd == 15)
      {
#ifndef UNSAFE_OPTIMIZATIONS
        if((rc & 1) == 0)
          fatalError("add pc", pc, rc, " produced an arm address");
#endif
        //rc &= ~1; //write_register may f this as well
        rc += 2;  //The program counter is special
      }
      //fprintf(stderr,"0x%08X = 0x%08X + 0x%08X\n",rc,ra,rb);
      write_register(rd, rc);
      return 0;
    }

    //ADD(5) rd = pc plus immediate
    case Op::add5: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x7;
      rb <<= 2;
      DO_DISS(statusMsg << "add r" << dec << rd << ",PC,#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(15);
      rc = (ra & (~3U)) + rb;
      write_register(rd, rc);
      return 0;
    }

    //ADD(6) rd = sp plus immediate
    case Op::add6: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x7;
      rb <<= 2;
      DO_DISS(statusMsg << "add r" << dec << rd << ",SP,#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(13);
      rc = ra + rb;
      write_register(rd, rc);
      return 0;
    }

    //ADD(7) sp plus immediate
    case Op::add7: {
      rb = (inst >> 0) & 0x7F;
      rb <<= 2;
      DO_DISS(statusMsg << "add SP,#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(13);
      rc = ra + rb;
      write_register(13, rc);
      return 0;
    }

    //AND
    case Op::and_: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "ands r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra & rb;
      write_register(rd, rc);
      do_znflags(rc);
      return 0;
    }

    //ASR(1) two register immediate
    case Op::asr1: {
      rd = (inst >> 0) & 0x07;
      rm = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      DO_DISS(statusMsg << "asrs r" << dec << rd << ",r" << dec << rm << ",#0x" << Base::HEX2 << rb << '\n');
      rc = read_register(rm);
      if(rb == 0)
      {
        if(rc & 0x80000000)
        {
          do_cflag_bit(1);
          rc = ~0U;
        }
        else
        {
          do_cflag_bit(0);
          rc = 0;
        }
      }
      else
      {
        do_cflag_bit(rc & (1 << (rb-1)));
        ra = rc & 0x80000000;
        rc >>= rb;
        if(ra) //asr, sign is shifted in
          rc |= (~0U) << (32-rb);
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //ASR(2) two register
    case Op::asr2: {
      rd = (inst >> 0) & 0x07;
      rs = (inst >> 3) & 0x07;
      DO_DISS(statusMsg << "asrs r" << dec << rd << ",r" << dec << rs << '\n');
      rc = read_register(rd);
      rb = read_register(rs);
      rb &= 0xFF;
      if(rb == 0)
      {
      }
      else if(rb < 32)
      {
        do_cflag_bit(rc & (1 << (rb-1)));
        ra = rc & 0x80000000;
        rc >>= rb;
        if(ra) //asr, sign is shifted in
        {
          rc |= (~0U) << (32-rb);
        }
      }
      else
      {
        if(rc & 0x80000000)
        {
          do_cflag_bit(1);
          rc = (~0U);
        }
        else
        {
          do_cflag_bit(0);
          rc = 0;
        }
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //B(1) conditional branch variants:
    // (beq, bne, bcs, bcc, bmi, bpl, bvs, bvc, bhi, bls, bge, blt, bgt, ble)
    case Op::beq: {
      THUMB_STAT(_stats.branches)
      if(!znFlags)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bne: {
      THUMB_STAT(_stats.branches)
      if(znFlags)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bcs: {
      THUMB_STAT(_stats.branches)
      if(cFlag)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bcc: {
      THUMB_STAT(_stats.branches)
      if(!cFlag)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bmi: {
      THUMB_STAT(_stats.branches)
      if(znFlags & 0x80000000)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bpl: {
      THUMB_STAT(_stats.branches)
      if(!(znFlags & 0x80000000))
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bvs: {
      THUMB_STAT(_stats.branches)
      if(vFlag)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bvc: {
      THUMB_STAT(_stats.branches)
      if(!vFlag)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bhi: {
      THUMB_STAT(_stats.branches)
      if(cFlag && znFlags)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bls: {
      THUMB_STAT(_stats.branches)
      if(!znFlags || !cFlag)
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bge: {
      THUMB_STAT(_stats.branches)
      if(((znFlags & 0x80000000) && vFlag) ||
         ((!(znFlags & 0x80000000)) && !vFlag))
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::blt: {
      THUMB_STAT(_stats.branches)
      if((!(znFlags & 0x80000000) && vFlag) ||
         (((znFlags & 0x80000000)) && !vFlag))
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    case Op::bgt: {
      THUMB_STAT(_stats.branches)
      if(znFlags)
      {
        if(((znFlags & 0x80000000) && vFlag) ||
           ((!(znFlags & 0x80000000)) && !vFlag))
          write_register(15, decodedParam[instructionPtr2]);      }
      return 0;
    }

    case Op::ble: {
      THUMB_STAT(_stats.branches)
      if(!znFlags ||
         (!(znFlags & 0x80000000) && vFlag) ||
         (((znFlags & 0x80000000)) && !vFlag))
        write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    //B(2) unconditional branch
    case Op::b2: {
      THUMB_STAT(_stats.branches)
      write_register(15, decodedParam[instructionPtr2]);
      return 0;
    }

    //BIC
    case Op::bic: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "bics r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra & (~rb);
      write_register(rd, rc);
      do_znflags(rc);
      return 0;
    }

#ifndef UNSAFE_OPTIMIZATIONS
    //BKPT
    case Op::bkpt: {
      rb = (inst >> 0) & 0xFF;
      statusMsg << "bkpt 0x" << Base::HEX2 << rb << '\n';
      return 1;
    }
#endif

    //BL/BLX(1) variants
    // (bl, blx_thumb, blx_arm)
    case Op::bl: {
      // branch to label
      DO_DISS(statusMsg << '\n');
      rb = inst & ((1 << 11) - 1);
      if(rb & 1 << 10) rb |= (~((1 << 11) - 1)); //sign extend
      rb <<= 12;
      rb += pc;
      write_register(14, rb);
      return 0;
    }

    case Op::blx_thumb: {
      // branch to label, switch to thumb
      rb = read_register(14);
      rb += (inst & ((1 << 11) - 1)) << 1;
      rb += 2;
      DO_DISS(statusMsg << "bl 0x" << Base::HEX8 << (rb-3) << '\n');
      write_register(14, (pc-2) | 1);
      write_register(15, rb);
      return 0;
    }

    case Op::blx_arm: {
      // branch to label, switch to arm
      //fprintf(stderr,"cannot branch to arm 0x%08X 0x%04X\n",pc,inst);
      // fxq: this should exit the code without having to detect it
      // TJ: seems to be not used
      rb = read_register(14);
      rb += (inst & ((1 << 11) - 1)) << 1;
      rb &= 0xFFFFFFFC;
      rb += 2;
      DO_DISS(statusMsg << "bl 0x" << Base::HEX8 << (rb-3) << '\n');
      write_register(14, (pc-2) | 1);
      write_register(15, rb);
      return 0;
    }

    //BLX(2)
    case Op::blx2: {
      rm = (inst >> 3) & 0xF;
      DO_DISS(statusMsg << "blx r" << dec << rm << '\n');
      rc = read_register(rm);
      //fprintf(stderr,"blx r%u 0x%X 0x%X\n",rm,rc,pc);
      rc += 2;
      if(rc & 1)
      {
        write_register(14, (pc-2) | 1);
#ifdef UNSAFE_OPTIMIZATIONS
        rc &= ~1; // not checked and corrected in write_register
#endif
        write_register(15, rc);
        return 0;
      }
      else
      {
        //fprintf(stderr,"cannot branch to arm 0x%08X 0x%04X\n",pc,inst);
        // fxq: this could serve as exit code
        return 1;
      }
    }

    //BX
    case Op::bx: {
      rm = (inst >> 3) & 0xF;
      DO_DISS(statusMsg << "bx r" << dec << rm << '\n');
      rc = read_register(rm);
      rc += 2;
      //fprintf(stderr,"bx r%u 0x%X 0x%X\n",rm,rc,pc);
      if(rc & 1)
      {
        // branch to odd address denotes 16 bit ARM code
        rc &= ~1;
        write_register(15, rc);
        return 0;
      }
      else
      {
        // branch to even address denotes 32 bit ARM code, which the Thumbulator
        // class does not support. So capture relevant information and hand it
        // off to the Cartridge class for it to handle.

        bool handled = false;

        switch(configuration)
        {
          case ConfigureFor::BUS: {
            // this subroutine interface is used in the BUS driver,
            // it starts at address 0x000006d8
            // _SetNote:
            //   ldr     r4, =NoteStore
            //   bx      r4   // bx instruction at 0x000006da
            // _ResetWave:
            //   ldr     r4, =ResetWaveStore
            //   bx      r4   // bx instruction at 0x000006de
            // _GetWavePtr:
            //   ldr     r4, =WavePtrFetch
            //   bx      r4   // bx instruction at 0x000006e2
            // _SetWaveSize:
            //   ldr     r4, =WaveSizeStore
            //   bx      r4   // bx instruction at 0x000006e6

            // address to test for is + 4 due to pipelining
            static constexpr uInt32
                BUS_SetNote     = (0x000006da + 4),
                BUS_ResetWave   = (0x000006de + 4),
                BUS_GetWavePtr  = (0x000006e2 + 4),
                BUS_SetWaveSize = (0x000006e6 + 4);

            if      (pc == BUS_SetNote)
            {
              myCartridge->thumbCallback(0, read_register(2), read_register(3));
              handled = true;
            }
            else if (pc == BUS_ResetWave)
            {
              myCartridge->thumbCallback(1, read_register(2), 0);
              handled = true;
            }
            else if (pc == BUS_GetWavePtr)
            {
              write_register(2, myCartridge->thumbCallback(2, read_register(2), 0));
              handled = true;
            }
            else if (pc == BUS_SetWaveSize)
            {
              myCartridge->thumbCallback(3, read_register(2), read_register(3));
              handled = true;
            }
            else if (pc == 0x0000083a)
            {
              // exiting Custom ARM code, returning to BUS Driver control
            }
            else
            {
  #if 0  // uncomment this for testing
              uInt32 r0 = read_register(0);
              uInt32 r1 = read_register(1);
              uInt32 r2 = read_register(2);
              uInt32 r3 = read_register(3);
              uInt32 r4 = read_register(4);
  #endif
              myCartridge->thumbCallback(255, 0, 0);
            }

            break;
          }

          case ConfigureFor::CDF: {
            // this subroutine interface is used in the CDF driver,
            // it starts at address 0x000006e0
            // _SetNote:
            //   ldr     r4, =NoteStore
            //   bx      r4   // bx instruction at 0x000006e2
            // _ResetWave:
            //   ldr     r4, =ResetWaveStore
            //   bx      r4   // bx instruction at 0x000006e6
            // _GetWavePtr:
            //   ldr     r4, =WavePtrFetch
            //   bx      r4   // bx instruction at 0x000006ea
            // _SetWaveSize:
            //   ldr     r4, =WaveSizeStore
            //   bx      r4   // bx instruction at 0x000006ee

            // address to test for is + 4 due to pipelining
            static constexpr uInt32
                CDF_SetNote      = (0x000006e2 + 4),
                CDF_ResetWave    = (0x000006e6 + 4),
                CDF_GetWavePtr   = (0x000006ea + 4),
                CDF_SetWaveSize  = (0x000006ee + 4);

            if      (pc == CDF_SetNote)
            {
              myCartridge->thumbCallback(0, read_register(2), read_register(3));
              handled = true;
            }
            else if (pc == CDF_ResetWave)
            {
              myCartridge->thumbCallback(1, read_register(2), 0);
              handled = true;
            }
            else if (pc == CDF_GetWavePtr)
            {
              write_register(2, myCartridge->thumbCallback(2, read_register(2), 0));
              handled = true;
            }
            else if (pc == CDF_SetWaveSize)
            {
              myCartridge->thumbCallback(3, read_register(2), read_register(3));
              handled = true;
            }
            else if (pc == 0x0000083a)
            {
              // exiting Custom ARM code, returning to CDF Driver control
            }
            else
            {
            #if 0  // uncomment this for testing
              uInt32 r0 = read_register(0);
              uInt32 r1 = read_register(1);
              uInt32 r2 = read_register(2);
              uInt32 r3 = read_register(3);
              uInt32 r4 = read_register(4);
            #endif
              myCartridge->thumbCallback(255, 0, 0);
            }

            break;
          }

          case ConfigureFor::CDF1:
          case ConfigureFor::CDFJ:
          case ConfigureFor::CDFJplus: {
            // this subroutine interface is used in the CDF driver,
            // it starts at address 0x00000750
            // _SetNote:
            //   ldr     r4, =NoteStore
            //   bx      r4   // bx instruction at 0x000006e2
            // _ResetWave:
            //   ldr     r4, =ResetWaveStore
            //   bx      r4   // bx instruction at 0x000006e6
            // _GetWavePtr:
            //   ldr     r4, =WavePtrFetch
            //   bx      r4   // bx instruction at 0x000006ea
            // _SetWaveSize:
            //   ldr     r4, =WaveSizeStore
            //   bx      r4   // bx instruction at 0x000006ee

            // address to test for is + 4 due to pipelining
            static constexpr uInt32
                CDF1_SetNote     = (0x00000752 + 4),
                CDF1_ResetWave   = (0x00000756 + 4),
                CDF1_GetWavePtr  = (0x0000075a + 4),
                CDF1_SetWaveSize = (0x0000075e + 4);

            if      (pc == CDF1_SetNote)
            {
              myCartridge->thumbCallback(0, read_register(2), read_register(3));
              // approximated cycles
              INC_ARM_CYCLES(_flashCycles + 1);     // this instruction
              INC_ARM_CYCLES(6);                    // ARM code NoteStore
              INC_ARM_CYCLES(2 + _flashCycles + 2); // ARM code ReturnC
              handled = true;
            }
            else if (pc == CDF1_ResetWave)
            {
              myCartridge->thumbCallback(1, read_register(2), 0);
              // approximated cycles
              INC_ARM_CYCLES(_flashCycles + 1);     // this instruction
              INC_ARM_CYCLES(6 + _flashCycles + 2); // ARM code ResetWaveStore
              INC_ARM_CYCLES(2 + _flashCycles + 2); // ARM code ReturnC
              handled = true;
            }
            else if (pc == CDF1_GetWavePtr)
            {
              write_register(2, myCartridge->thumbCallback(2, read_register(2), 0));
              // approximated cycles
              INC_ARM_CYCLES(_flashCycles + 1);     // this instruction
              INC_ARM_CYCLES(6 + _flashCycles + 2); // ARM code WavePtrFetch
              INC_ARM_CYCLES(2 + _flashCycles + 2); // ARM code ReturnC
              handled = true;
            }
            else if (pc == CDF1_SetWaveSize)
            {
              myCartridge->thumbCallback(3, read_register(2), read_register(3));
              // approximated cycles
              INC_ARM_CYCLES(_flashCycles + 1);           // this instruction
              INC_ARM_CYCLES(18 + _flashCycles * 3 + 2);  // ARM code WaveSizeStore
              INC_ARM_CYCLES(2 + _flashCycles + 2);       // ARM code ReturnC
              handled = true;
            }
            else if (pc == 0x0000083a)
            {
              // exiting Custom ARM code, returning to CDFJ Driver control
            }
            else
            {
  #if 0  // uncomment this for testing
              uInt32 r0 = read_register(0);
              uInt32 r1 = read_register(1);
              uInt32 r2 = read_register(2);
              uInt32 r3 = read_register(3);
              uInt32 r4 = read_register(4);
  #endif
              myCartridge->thumbCallback(255, 0, 0);
            }

            break;
          }

          case ConfigureFor::DPCplus:
            // no 32-bit subroutines in DPC+
            break;
        }

        if (handled)
        {
          rc = read_register(14); // lr
          rc += 2;
          //rc &= ~1;
          write_register(15, rc);
          //_totalCycles += 100; // just a wild guess
          return 0;
        }
        return 1;
      }
    }

    //CMN
    case Op::cmn: {
      rn = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "cmns r" << dec << rn << ",r" << dec << rm << '\n');
      ra = read_register(rn);
      rb = read_register(rm);
      rc = ra + rb;
      do_znflags(rc);
      do_cvflag(ra, rb, 0);
      return 0;
    }

    //CMP(1) compare immediate
    case Op::cmp1: {
      rb = (inst >> 0) & 0xFF;
      rn = (inst >> 8) & 0x07;
      DO_DISS(statusMsg << "cmp r" << dec << rn << ",#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(rn);
      rc = ra - rb;
      //fprintf(stderr,"0x%08X 0x%08X\n",ra,rb);
      do_znflags(rc);
      do_cvflag(ra, ~rb, 1);
      return 0;
    }

    //CMP(2) compare register
    case Op::cmp2: {
      rn = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "cmps r" << dec << rn << ",r" << dec << rm << '\n');
      ra = read_register(rn);
      rb = read_register(rm);
      rc = ra - rb;
      //fprintf(stderr,"0x%08X 0x%08X\n",ra,rb);
      do_znflags(rc);
      do_cvflag(ra, ~rb, 1);
      return 0;
    }

    //CMP(3) compare high register
    case Op::cmp3: {
      if(((inst >> 6) & 3) == 0x0)
      {
        //UNPREDICTABLE
      }
      rn = (inst >> 0) & 0x7;
      rn |= (inst >> 4) & 0x8;
      if(rn == 0xF)
      {
        //UNPREDICTABLE
      }
      rm = (inst >> 3) & 0xF;
      DO_DISS(statusMsg << "cmps r" << dec << rn << ",r" << dec << rm << '\n');
      ra = read_register(rn);
      rb = read_register(rm);
      rc = ra - rb;
      do_znflags(rc);
      do_cvflag(ra, ~rb, 1);
      return 0;
    }

#ifndef UNSAFE_OPTIMIZATIONS
    //CPS
    case Op::cps: {
      DO_DISS(statusMsg << "cps TODO\n");
      return 1;
    }
#endif

    //CPY copy high register
    case Op::cpy: {
      //same as mov except you can use both low registers
      //going to let mov handle high registers
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "cpy r" << dec << rd << ",r" << dec << rm << '\n');
      rc = read_register(rm);
      write_register(rd, rc);
      return 0;
    }

    //EOR
    case Op::eor: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "eors r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra ^ rb;
      write_register(rd, rc);
      do_znflags(rc);
      return 0;
    }

    //LDMIA
    case Op::ldmia: {
      rn = (inst >> 8) & 0x7;
    #if defined(THUMB_DISS)
      statusMsg << "ldmia r" << dec << rn << "!,{";
      for(ra=0,rb=0x01,rc=0;rb;rb=(rb<<1)&0xFF,++ra)
      {
        if(inst&rb)
        {
          if(rc) statusMsg << ",";
          statusMsg << "r" << dec << ra;
          rc++;
        }
      }
      statusMsg << "}\n";
    #endif
      bool first = true;

      sp = read_register(rn);
      for(ra = 0, rb = 0x01; rb; rb = (rb << 1) & 0xFF, ++ra)
      {
        if(inst & rb)
        {
          write_register(ra, read32(sp));
          if(first)
          {
            INC_N_CYCLES(sp, AccessType::data);
            first = false;
          }
          else
          {
            INC_S_CYCLES(sp, AccessType::data);
          }
          sp += 4;
        }
      }
      INC_I_CYCLES; // Note: destination PC not possible, see pop instead
      //there is a write back exception.
      if((inst & (1 << rn)) == 0)
        write_register(rn, sp);
      return 0;
    }

    //LDR(1) two register immediate
    case Op::ldr1: {
      rd = (inst >> 0) & 0x07;
      rn = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      rb <<= 2;
      DO_DISS(statusMsg << "ldr r" << dec << rd << ",[r" << dec << rn << ",#0x" << Base::HEX2 << rb << "]\n");
      rb = read_register(rn) + rb;
      rc = read32(rb);
      write_register(rd, rc);
      INC_LDR_CYCLES;
      return 0;
    }

    //LDR(2) three register
    case Op::ldr2: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "ldr r" << dec << rd << ",[r" << dec << rn << ",r" << dec << "]\n");
      rb = read_register(rn) + read_register(rm);
      rc = read32(rb);
      write_register(rd, rc);
      INC_LDR_CYCLES;
      return 0;
    }

    //LDR(3)
    case Op::ldr3: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x07;
      rb <<= 2;
      DO_DISS(statusMsg << "ldr r" << dec << rd << ",[PC+#0x" << Base::HEX2 << rb << "] ");
      ra = read_register(15);
      ra &= ~3;
      rb += ra;
      DO_DISS(statusMsg << ";@ 0x" << Base::HEX2 << rb << '\n');
      rc = read32(rb);
      write_register(rd, rc);
      INC_LDR_CYCLES;
      return 0;
    }

    //LDR(4)
    case Op::ldr4: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x07;
      rb <<= 2;
      DO_DISS(statusMsg << "ldr r" << dec << rd << ",[SP+#0x" << Base::HEX2 << rb << "]\n");
      ra = read_register(13);
      //ra&=~3;
      rb += ra;
      rc = read32(rb);
      write_register(rd, rc);
      INC_LDR_CYCLES;
      return 0;
    }

    //LDRB(1)
    case Op::ldrb1: {
      rd = (inst >> 0) & 0x07;
      rn = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      DO_DISS(statusMsg << "ldrb r" << dec << rd << ",[r" << dec << rn << ",#0x" << Base::HEX2 << rb << "]\n");
      rb = read_register(rn) + rb;
#ifndef UNSAFE_OPTIMIZATIONS
      rc = read16(rb & (~1U));
#else
      rc = read16(rb);
#endif
      if(rb & 1)
      {
        rc >>= 8;
      }
      else
      {
      }
      write_register(rd, rc & 0xFF);
      INC_LDRB_CYCLES;
      return 0;
    }

    //LDRB(2)
    case Op::ldrb2: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "ldrb r" << dec << rd << ",[r" << dec << rn << ",r" << dec << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
#ifndef UNSAFE_OPTIMIZATIONS
      rc = read16(rb & (~1U));
#else
      rc = read16(rb);
#endif
      if(rb & 1)
      {
        rc >>= 8;
      }
      write_register(rd, rc & 0xFF);
      INC_LDRB_CYCLES;
      return 0;
    }

    //LDRH(1)
    case Op::ldrh1: {
      rd = (inst >> 0) & 0x07;
      rn = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      rb <<= 1;
      DO_DISS(statusMsg << "ldrh r" << dec << rd << ",[r" << dec << rn << ",#0x" << Base::HEX2 << rb << "]\n");
      rb = read_register(rn) + rb;
      rc = read16(rb);
      write_register(rd, rc & 0xFFFF);
      INC_LDR_CYCLES;
      return 0;
    }

    //LDRH(2)
    case Op::ldrh2: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "ldrh r" << dec << rd << ",[r" << dec << rn << ",r" << dec << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
      rc = read16(rb);
      write_register(rd, rc & 0xFFFF);
      INC_LDR_CYCLES;
      return 0;
    }

    //LDRSB
    case Op::ldrsb: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "ldrsb r" << dec << rd << ",[r" << dec << rn << ",r" << dec << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
#ifndef UNSAFE_OPTIMIZATIONS
      rc = read16(rb & (~1U));
#else
      rc = read16(rb);
#endif
      if(rb & 1)
      {
        rc >>= 8;
      }
      rc &= 0xFF;
      if(rc & 0x80)
        rc |= ((~0U) << 8);
      write_register(rd, rc);
      INC_LDRB_CYCLES;
      return 0;
    }

    //LDRSH
    case Op::ldrsh: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "ldrsh r" << dec << rd << ",[r" << dec << rn << ",r" << dec << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
      rc = read16(rb);
      rc &= 0xFFFF;
      if(rc & 0x8000)
        rc |= ((~0U) << 16);
      write_register(rd, rc);
      INC_LDR_CYCLES;
      return 0;
    }

    //LSL(1)
    case Op::lsl1: {
      rd = (inst >> 0) & 0x07;
      rm = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      DO_DISS(statusMsg << "lsls r" << dec << rd << ",r" << dec << rm << ",#0x" << Base::HEX2 << rb << '\n');
      rc = read_register(rm);
      if(rb == 0)
      {
        //if immed_5 == 0
        //C unaffected
        //result not shifted
      }
      else
      {
        //else immed_5 > 0
        do_cflag_bit(rc & (1 << (32-rb)));
        rc <<= rb;
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //LSL(2) two register
    case Op::lsl2: {
      rd = (inst >> 0) & 0x07;
      rs = (inst >> 3) & 0x07;
      DO_DISS(statusMsg << "lsls r" << dec << rd << ",r" << dec << rs << '\n');
      rc = read_register(rd);
      rb = read_register(rs);
      rb &= 0xFF;
      if(rb == 0)
      {
      }
      else if(rb < 32)
      {
        do_cflag_bit(rc & (1 << (32-rb)));
        rc <<= rb;
      }
      else if(rb == 32)
      {
        do_cflag_bit(rc & 1);
        rc = 0;
      }
      else
      {
        do_cflag_bit(0);
        rc = 0;
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //LSR(1) two register immediate
    case Op::lsr1: {
      rd = (inst >> 0) & 0x07;
      rm = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      DO_DISS(statusMsg << "lsrs r" << dec << rd << ",r" << dec << rm << ",#0x" << Base::HEX2 << rb << '\n');
      rc = read_register(rm);
      if(rb == 0)
      {
        do_cflag_bit(rc & 0x80000000);
        rc = 0;
      }
      else
      {
        do_cflag_bit(rc & (1 << (rb-1)));
        rc >>= rb;
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //LSR(2) two register
    case Op::lsr2: {
      rd = (inst >> 0) & 0x07;
      rs = (inst >> 3) & 0x07;
      DO_DISS(statusMsg << "lsrs r" << dec << rd << ",r" << dec << rs << '\n');
      rc = read_register(rd);
      rb = read_register(rs);
      rb &= 0xFF;
      if(rb == 0)
      {
      }
      else if(rb < 32)
      {
        do_cflag_bit(rc & (1 << (rb-1)));
        rc >>= rb;
      }
      else if(rb == 32)
      {
        do_cflag_bit(rc & 0x80000000);
        rc = 0;
      }
      else
      {
        do_cflag_bit(0);
        rc = 0;
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //MOV(1) immediate
    case Op::mov1: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x07;
      DO_DISS(statusMsg << "movs r" << dec << rd << ",#0x" << Base::HEX2 << rb << '\n');
      write_register(rd, rb);
      do_znflags(rb);
      return 0;
    }

    //MOV(2) two low registers
    case Op::mov2: {
      rd = (inst >> 0) & 7;
      rn = (inst >> 3) & 7;
      DO_DISS(statusMsg << "movs r" << dec << rd << ",r" << dec << rn << '\n');
      rc = read_register(rn);
      //fprintf(stderr,"0x%08X\n",rc);
      write_register(rd, rc);
      do_znflags(rc);
      do_cflag_bit(0);
      do_vflag_bit(0);
      return 0;
    }

    //MOV(3)
    case Op::mov3: {
      rd  = (inst >> 0) & 0x7;
      rd |= (inst >> 4) & 0x8;
      rm  = (inst >> 3) & 0xF;
      DO_DISS(statusMsg << "mov r" << dec << rd << ",r" << dec << rm << '\n');
      rc = read_register(rm);
      if((rd == 14) && (rm == 15))
      {
        //printf("mov lr,pc warning 0x%08X\n",pc-2);
        //rc|=1;
      }
      if(rd == 15)
      {
        //rc &= ~1; //write_register may do this as well
        rc += 2;  //The program counter is special
      }
      write_register(rd, rc);
      return 0;
    }

    //MUL
    case Op::mul: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "muls r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
    #ifdef DEBUGGER_SUPPORT
      if((rb & 0xffffff00) == 0 || (rb & 0xffffff00) == 0xffffff00)       // -2^8 <= rb < 2^8
      {
        INC_I_CYCLES;
      }
      else if((rb & 0xffff0000) == 0 || (rb & 0xffff0000) == 0xffff0000)  // -2^16 <= rb < 2^16
      {
        INC_I_CYCLES_M(2);
      }
      else if((rb & 0xff000000) == 0 || (rb & 0xff000000) == 0xff000000)  // -2^24 <= rb < 2^24
      {
        INC_I_CYCLES_M(3);
      }
      else
      {
        INC_I_CYCLES_M(4);
      }
    #endif
      rc = ra * rb;
      write_register(rd, rc);
      do_znflags(rc);
      return 0;
    }

    //MVN
    case Op::mvn: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "mvns r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rm);
      rc = (~ra);
      write_register(rd, rc);
      do_znflags(rc);
      return 0;
    }

    //NEG
    case Op::neg: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "negs r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rm);
      rc = 0 - ra;
      write_register(rd, rc);
      do_znflags(rc);
      do_cvflag(0, ~ra, 1);
      return 0;
    }

    //ORR
    case Op::orr: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "orrs r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra | rb;
      write_register(rd, rc);
      do_znflags(rc);
      return 0;
    }

    //POP
    case Op::pop: {
    #if defined(THUMB_DISS)
      statusMsg << "pop {";
      for(ra=0,rb=0x01,rc=0;rb;rb=(rb<<1)&0xFF,++ra)
      {
        if(inst&rb)
        {
          if(rc) statusMsg << ",";
          statusMsg << "r" << dec << ra;
          rc++;
        }
      }
      if(inst&0x100)
      {
        if(rc) statusMsg << ",";
        statusMsg << "pc";
      }
      statusMsg << "}\n";
    #endif
      bool first = true;

      sp = read_register(13);
      for(ra = 0, rb = 0x01; rb; rb = (rb << 1) & 0xFF, ++ra)
      {
        if(inst & rb)
        {
          write_register(ra, read32(sp));
          if(first)
          {
            INC_N_CYCLES(sp, AccessType::data);
            first = false;
          }
          else
          {
            INC_S_CYCLES(sp, AccessType::data);
          }
          sp += 4;
        }
      }
      INC_I_CYCLES; // ??? (copied from ldmia)
      if(inst & 0x100)
      {
        rc = read32(sp);
        if(first)
        {
          INC_N_CYCLES(sp, AccessType::data);
        }
        else
        {
          INC_S_CYCLES(sp, AccessType::data);
        }
        rc += 2;
        write_register(15, rc);
        sp += 4;
      }
      write_register(13, sp);
      return 0;
    }

    //PUSH
    case Op::push: {
    #if defined(THUMB_DISS)
      statusMsg << "push {";
      for(ra=0,rb=0x01,rc=0;rb;rb=(rb<<1)&0xFF,++ra)
      {
        if(inst&rb)
        {
          if(rc) statusMsg << ",";
          statusMsg << "r" << dec << ra;
          rc++;
        }
      }
      if(inst&0x100)
      {
        if(rc) statusMsg << ",";
        statusMsg << "lr";
      }
      statusMsg << "}\n";
    #endif

      sp = read_register(13);
      //fprintf(stderr,"sp 0x%08X\n",sp);
      for(ra = 0, rb = 0x01, rc = 0; rb; rb = (rb << 1) & 0xFF, ++ra)
      {
        if(inst & rb)
        {
          ++rc;
        }
      }
      if(inst & 0x100) ++rc;
      rc <<= 2;
      sp -= rc;
      bool first = true;

      rd = sp;
      for(ra = 0, rb = 0x01; rb; rb = (rb << 1) & 0xFF, ++ra)
      {
        if(inst & rb)
        {
          write32(rd, read_register(ra));
          if(first)
          {
            INC_N_CYCLES(rd, AccessType::data);
            first = false;
          }
          else
          {
            INC_S_CYCLES(rd, AccessType::data);
          }
          rd += 4;
        }
      }
      if(inst & 0x100)
      {
        rc = read_register(14);
        write32(rd, rc);
        if(first)
        {
          INC_N_CYCLES(rd, AccessType::data);
        }
        else
        {
          INC_S_CYCLES(rd, AccessType::data);
        }
        if((rc & 1) == 0)
        {
          // FIXME fprintf(stderr,"push {lr} with an ARM address pc 0x%08X popped 0x%08X\n",pc,rc);
        }
      }
      write_register(13, sp);
      FETCH_TYPE_N; // ??? (copied from stmia)
      return 0;
    }

    //REV
    case Op::rev: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "rev r" << dec << rd << ",r" << dec << rn << '\n');
      ra = read_register(rn);
      rc  = ((ra >>  0) & 0xFF) << 24;
      rc |= ((ra >>  8) & 0xFF) << 16;
      rc |= ((ra >> 16) & 0xFF) <<  8;
      rc |= ((ra >> 24) & 0xFF) <<  0;
      write_register(rd, rc);
      return 0;
    }

    //REV16
    case Op::rev16: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "rev16 r" << dec << rd << ",r" << dec << rn << '\n');
      ra = read_register(rn);
      rc  = ((ra >>  0) & 0xFF) <<  8;
      rc |= ((ra >>  8) & 0xFF) <<  0;
      rc |= ((ra >> 16) & 0xFF) << 24;
      rc |= ((ra >> 24) & 0xFF) << 16;
      write_register(rd, rc);
      return 0;
    }

    //REVSH
    case Op::revsh: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "revsh r" << dec << rd << ",r" << dec << rn << '\n');
      ra = read_register(rn);
      rc  = ((ra >> 0) & 0xFF) << 8;
      rc |= ((ra >> 8) & 0xFF) << 0;
      if(rc & 0x8000) rc |= 0xFFFF0000;
      else            rc &= 0x0000FFFF;
      write_register(rd, rc);
      return 0;
    }

    //ROR
    case Op::ror: {
      rd = (inst >> 0) & 0x7;
      rs = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "rors r" << dec << rd << ",r" << dec << rs << '\n');
      rc = read_register(rd);
      ra = read_register(rs);
      ra &= 0xFF;
      if(ra == 0)
      {
      }
      else
      {
        ra &= 0x1F;
        if(ra == 0)
        {
          do_cflag_bit(rc & 0x80000000);
        }
        else
        {
          do_cflag_bit(rc & (1 << (ra-1)));
          rb = rc << (32-ra);
          rc >>= ra;
          rc |= rb;
        }
      }
      write_register(rd, rc);
      do_znflags(rc);
      INC_SHIFT_CYCLES;
      return 0;
    }

    //SBC
    case Op::sbc: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "sbc r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rd);
      rb = read_register(rm);
      rc = ra - rb;
      if(!cFlag) --rc;
      write_register(rd, rc);
      do_znflags(rc);
      if(cFlag) do_cvflag(ra, ~rb, 1);
      else      do_cvflag(ra, ~rb, 0);
      return 0;
    }

#ifndef UNSAFE_OPTIMIZATIONS
    //SETEND
    case Op::setend: {
      statusMsg << "setend not implemented\n";
      return 1;
    }
#endif

    //STMIA
    case Op::stmia: {
      rn = (inst >> 8) & 0x7;
    #if defined(THUMB_DISS)
      statusMsg << "stmia r" << dec << rn << "!,{";
      for(ra=0,rb=0x01,rc=0;rb;rb=(rb<<1)&0xFF,++ra)
      {
        if(inst & rb)
        {
          if(rc) statusMsg << ",";
          statusMsg << "r" << dec << ra;
          rc++;
        }
      }
      statusMsg << "}\n";
    #endif
      bool first = true;

      sp = read_register(rn);
      for(ra = 0, rb = 0x01; rb; rb = (rb << 1) & 0xFF, ++ra)
      {
        if(inst & rb)
        {
          write32(sp, read_register(ra));
          if(first)
          {
            INC_N_CYCLES(sp, AccessType::data);
            first = false;
          }
          else
          {
            INC_S_CYCLES(sp, AccessType::data);
          }
          sp += 4;
        }
      }
      write_register(rn, sp);
      FETCH_TYPE_N;
      return 0;
    }

    //STR(1)
    case Op::str1: {
      rd = (inst >> 0) & 0x07;
      rn = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      rb <<= 2;
      DO_DISS(statusMsg << "str r" << dec << rd << ",[r" << dec << rn << ",#0x" << Base::HEX2 << rb << "]\n");
      rb = read_register(rn) + rb;
      rc = read_register(rd);
      write32(rb, rc);
      INC_STR_CYCLES;
      return 0;
    }

    //STR(2)
    case Op::str2: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "str r" << dec << rd << ",[r" << dec << rn << ",r" << dec << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
      rc = read_register(rd);
      write32(rb, rc);
      INC_STR_CYCLES;
      return 0;
    }

    //STR(3)
    case Op::str3: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x07;
      rb <<= 2;
      DO_DISS(statusMsg << "str r" << dec << rd << ",[SP,#0x" << Base::HEX2 << rb << "]\n");
      rb = read_register(13) + rb;
      //fprintf(stderr,"0x%08X\n",rb);
      rc = read_register(rd);
      write32(rb, rc);
      INC_STR_CYCLES;
      return 0;
    }

    //STRB(1)
    case Op::strb1: {
      rd = (inst >> 0) & 0x07;
      rn = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      DO_DISS(statusMsg << "strb r" << dec << rd << ",[r" << dec << rn << ",#0x" << Base::HEX8 << rb << "]\n");
      rb = read_register(rn) + rb;
      rc = read_register(rd);
#ifndef UNSAFE_OPTIMIZATIONS
      ra = read16(rb & (~1U));
#else
      ra = read16(rb);
#endif
      if(rb & 1)
      {
        ra &= 0x00FF;
        ra |= rc << 8;
      }
      else
      {
        ra &= 0xFF00;
        ra |= rc & 0x00FF;
      }
      write16(rb & (~1U), ra & 0xFFFF);
      INC_STRB_CYCLES;
      return 0;
    }

    //STRB(2)
    case Op::strb2: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "strb r" << dec << rd << ",[r" << dec << rn << ",r" << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
      rc = read_register(rd);
#ifndef UNSAFE_OPTIMIZATIONS
      ra = read16(rb & (~1U));
#else
      ra = read16(rb);
#endif
      if(rb & 1)
      {
        ra &= 0x00FF;
        ra |= rc << 8;
      }
      else
      {
        ra &= 0xFF00;
        ra |= rc & 0x00FF;
      }
      write16(rb & (~1U), ra & 0xFFFF);
      INC_STRB_CYCLES;
      return 0;
    }

    //STRH(1)
    case Op::strh1: {
      rd = (inst >> 0) & 0x07;
      rn = (inst >> 3) & 0x07;
      rb = (inst >> 6) & 0x1F;
      rb <<= 1;
      DO_DISS(statusMsg << "strh r" << dec << rd << ",[r" << dec << rn << ",#0x" << Base::HEX2 << rb << "]\n");
      rb = read_register(rn) + rb;
      rc=  read_register(rd);
      write16(rb, rc & 0xFFFF);
      INC_STR_CYCLES;
      return 0;
    }

    //STRH(2)
    case Op::strh2: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "strh r" << dec << rd << ",[r" << dec << rn << ",r" << dec << rm << "]\n");
      rb = read_register(rn) + read_register(rm);
      rc = read_register(rd);
      write16(rb, rc & 0xFFFF);
      INC_STR_CYCLES;
      return 0;
    }

    //SUB(1)
    case Op::sub1: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rb = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "subs r" << dec << rd << ",r" << dec << rn << ",#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(rn);
      rc = ra - rb;
      write_register(rd, rc);
      do_znflags(rc);
      do_cvflag(ra, ~rb, 1);
      return 0;
    }

    //SUB(2)
    case Op::sub2: {
      rb = (inst >> 0) & 0xFF;
      rd = (inst >> 8) & 0x07;
      DO_DISS(statusMsg << "subs r" << dec << rd << ",#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(rd);
      rc = ra - rb;
      write_register(rd, rc);
      do_znflags(rc);
      do_cvflag(ra, ~rb, 1);
      return 0;
    }

    //SUB(3)
    case Op::sub3: {
      rd = (inst >> 0) & 0x7;
      rn = (inst >> 3) & 0x7;
      rm = (inst >> 6) & 0x7;
      DO_DISS(statusMsg << "subs r" << dec << rd << ",r" << dec << rn << ",r" << dec << rm << '\n');
      ra = read_register(rn);
      rb = read_register(rm);
      rc = ra - rb;
      write_register(rd, rc);
      do_znflags(rc);
      do_cvflag(ra, ~rb, 1);
      return 0;
    }

    //SUB(4)
    case Op::sub4: {
      rb = inst & 0x7F;
      rb <<= 2;
      DO_DISS(statusMsg << "sub SP,#0x" << Base::HEX2 << rb << '\n');
      ra = read_register(13);
      ra -= rb;
      write_register(13, ra);
      return 0;
    }

    //SWI
    case Op::swi: { // never used
//      rb = inst & 0xFF;  // NOLINT: clang-analyzer-deadcode.DeadStores
//      DO_DISS(statusMsg << "swi 0x" << Base::HEX2 << rb << '\n');
//
//      if(rb == 0xCC)
//      {
//        write_register(0, cpsr);
//        return 0;
//      }
//      else
//      {
//#if defined(THUMB_DISS)
//        statusMsg << "\n\nswi 0x" << Base::HEX2 << rb << '\n';
//#endif
          return 1;
//      }
    }

    //SXTB
    case Op::sxtb: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "sxtb r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rm);
      rc = ra & 0xFF;
      if(rc & 0x80)
        rc |= (~0U) << 8;
      write_register(rd, rc);
      return 0;
    }

    //SXTH
    case Op::sxth: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "sxth r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rm);
      rc = ra & 0xFFFF;
      if(rc & 0x8000)
        rc |= (~0U) << 16;
      write_register(rd, rc);
      return 0;
    }

    //TST
    case Op::tst: {
      rn = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "tst r" << dec << rn << ",r" << dec << rm << '\n');
      ra = read_register(rn);
      rb = read_register(rm);
      rc = ra & rb;
      do_znflags(rc);
      return 0;
    }

    //UXTB
    case Op::uxtb: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "uxtb r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rm);
      rc = ra & 0xFF;
      write_register(rd, rc);
      return 0;
    }

    //UXTH
    case Op::uxth: {
      rd = (inst >> 0) & 0x7;
      rm = (inst >> 3) & 0x7;
      DO_DISS(statusMsg << "uxth r" << dec << rd << ",r" << dec << rm << '\n');
      ra = read_register(rm);
      rc = ra & 0xFFFF;
      write_register(rd, rc);
      return 0;
    }

    // Silence compiler
    case Op::numOps:
      break;

#ifndef UNSAFE_OPTIMIZATIONS
    case Op::invalid:
      break;
#else
    default:
      break;
#endif
  }

#ifndef UNSAFE_OPTIMIZATIONS
  statusMsg << "invalid instruction " << Base::HEX8 << pc << " "
            << Base::HEX4 << inst << '\n';
#endif
  return 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Thumbulator::reset()
{
  reg_norm.fill(0);

  reg_norm[13] = cStack;              // SP
  reg_norm[14] = cBase;               // LR
  reg_norm[15] = (cStart + 2) | 1;    // PC (+2 for pipeline, lower bit for THUMB)

  znFlags = cFlag = vFlag = 0;
  handler_mode = false;

  systick_ctrl = 0x00000004;
  systick_reload = 0x00000000;
  systick_count = 0x00000000;
  systick_calibrate = 0x00ABCDEF;

  // fxq: don't care about below so much (maybe to guess timing???)
#ifndef UNSAFE_OPTIMIZATIONS
  _stats.instructions = 0;
  statusMsg.str("");
#endif
#ifdef THUMB_STATS
  _stats.reads = _stats.writes
    = _stats.nCylces = _stats.sCylces = _stats.iCylces
    = _stats.branches = _stats.taken
    = _stats.mamPrefetchHits = _stats.mamPrefetchMisses
    = _stats.mamBranchHits = _stats.mamBranchMisses
    = _stats.mamDataHits = _stats.mamDataMisses = 0;
#endif
#ifdef THUMB_CYCLE_COUNT
  _totalCycles = 0;
 #ifdef EMULATE_PIPELINE
  _fetchPipeline = _memory0Pipeline = _memory1Pipeline = 0;
 #endif
#endif
#ifdef COUNT_OPS
  //memset(opCount, 0, sizeof(opCount));
#endif
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Thumbulator::ChipPropsType Thumbulator::setChipType(ChipType type)
{
  if(type == ChipType::AUTO)
  {
    if(_chipType != ChipType::AUTO)
      type = _chipType;
    else if(searchPattern(0x3016E5C0, 3)) // alternate bus location (standard = 0x3015E5C0)
      type = ChipType::LPC213x;
    else if(romSize <= 0x8000)            // LPC2104.. is always > 32K
      type = ChipType::LPC2101;
    else if(searchPattern(0x1026E3A0))    // 70 MHz pattern (60 MHZ = 0x1025E3A0)
      type = ChipType::LPC2104_OC;
    else
      type = ChipType::LPC2104;
  }

  ChipPropsType props = ChipProps[static_cast<uInt32>(type)];

  _chipType = type;
  _MHz = props.MHz;
#ifdef THUMB_CYCLE_COUNT
  _flashCycles = props.flashCycles;
  _flashBanks = props.flashBanks;
#endif

  setConsoleTiming(_consoleTiming);

  return props;
}

#ifdef THUMB_CYCLE_COUNT
// Notes:
// For exact cylce counting we have to
// - emulate the LPC21xx prefetch, branch and data buffers
// - differentiate between S and N cycles
// - simulation the pipeline (including stalls)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
/*
  This simulates the MAM of the LPC2101_02_03. It has three 128-bits buffers:
  - prefetch buffer
  - branch trail buffer
  - data buffer

  Instruction prefetches are checking the prefetch and the branch trail buffer.
  - If a prefetch cannot be found in the two buffers a new line of 128 bits is read from memory
    and put into the prefetch buffer. This causes wait states.
  - If a branch target cannot be found in the two buffers a new line of 128 bits is read from
    memory and put into the branch trail buffer. This causes wait states.

  Data access is only checking and updating the data buffer.

  The function returns true in case of a buffer hit.
*/
bool Thumbulator::isMamBuffered(uInt32 addr, AccessType accessType)
{
  if(_flashBanks == 1) // e.g. LPC2101_02_03
  {
    // single Flash bank
    addr &= ~0x7F; // 128-bit address line

    switch(accessType)
    {
      case AccessType::prefetch:
        if(addr != _prefetchBufferAddr[0] && addr != _branchBufferAddr[0])
        {
          THUMB_STAT(_stats.mamPrefetchMisses)
          _prefetchBufferAddr[0] = addr;
          return false;
        }
        THUMB_STAT(_stats.mamPrefetchHits)
        break;

      case AccessType::branch:
        if(addr != _prefetchBufferAddr[0] && addr != _branchBufferAddr[0])
        {
          THUMB_STAT(_stats.mamBranchMisses)
          _branchBufferAddr[0] = addr;
          return false;
        }
        THUMB_STAT(_stats.mamBranchHits)
        break;

      default: // AccessType::data
        if(addr != _dataBufferAddr)
        {
          THUMB_STAT(_stats.mamDataMisses)
          _dataBufferAddr = addr;
          return false;
        }
        THUMB_STAT(_stats.mamDataHits)
        break;
    }
  }
  else // e.g. LPC2104_05_06
  {
    // dual Flash bank
    const uInt32 bank = (addr & 0x80) ? 1 : 0;

    addr &= ~0x7F; // 128-bit address line

    switch(accessType)
    {
      case AccessType::prefetch:
        // speculative load, executed after last instrucution has been executed
        _prefetchBufferAddr[bank ^ 1] = addr + 0x80;
        if(addr != _prefetchBufferAddr[bank] && addr != _branchBufferAddr[bank])
        {
          THUMB_STAT(_stats.mamPrefetchMisses)
          _prefetchBufferAddr[bank] = addr;
          return false;
        }
        THUMB_STAT(_stats.mamPrefetchHits)
        break;

      case AccessType::branch:
        if(addr != _prefetchBufferAddr[bank] && addr != _branchBufferAddr[bank])
        {
          THUMB_STAT(_stats.mamBranchMisses)
          // load both branch trail buffers at once
          _branchBufferAddr[bank] = addr;
          _branchBufferAddr[bank ^ 1] = addr + 0x80;
          return false;
        }
        THUMB_STAT(_stats.mamBranchHits)
        break;

      default: // AccessType::data
        if(addr != _dataBufferAddr)
        {
          THUMB_STAT(_stats.mamDataMisses)
          _dataBufferAddr = addr;
          return false;
        }
        THUMB_STAT(_stats.mamDataHits)
        break;
    }
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::incCycles(AccessType accessType, uInt32 cycles)
{
#ifdef EMULATE_PIPELINE
  // simulate the pipeline effects
  //if(_memory0Pipeline)
  //{
  //  --_memory0Pipeline; // == 0
  //  ++_fetchPipeline;
  //}
  if(_memory1Pipeline)
  {
    --_memory1Pipeline;
    ++_memory0Pipeline; // == 1
  }

  switch(accessType)
  {
    case AccessType::branch:
      _fetchPipeline = _memory0Pipeline = _memory1Pipeline = 0; // flush pipeline
      break;

    case AccessType::data:
      if(cycles == 1) // no Flash access
        ++_fetchPipeline;
      else
        _memory1Pipeline += cycles;
      break;

    default: // AccessType::prefetch
    {
      // Reduce cycles by pipelined cycles
      // Cart (Turbo start sequence): 1F0AC
      // None:      1FF2E @ 90% (22989 @ 100%)
    #if 1
      // Version 1: 1ECFC @ 90% (223C3 @ 100%)
      if(cycles == _flashCycles)
      {
        if(!_memory1Pipeline) // there must be no pending memory access
        {
          uInt32 newCycles = std::max(1, Int32(cycles - _fetchPipeline));

          _fetchPipeline -= (cycles - newCycles);
          cycles = newCycles;
        }
      }
    #endif
    #if 0
      // Version 2: 1ED23 @ 90% (223EF @ 100%)
      //   considers that partial fetches are not allowed
      if(cycles == _flashCycles)
      {
        //_memory0Pipeline = _memory1Pipeline = 0;
        if(!_memory1Pipeline && _fetchPipeline >= _flashCycles)
        {
          _fetchPipeline -= (_flashCycles - 1);
          cycles = 1;
        }
        //else
        // _fetchPipeline = 0; // Flash prefetch abort (makes 0 difference!)
      }
    #endif
      break;
    }
  };
#endif

//#ifdef MERGE_I_S
//   TODO
//  if(accessType == AccessType::branch)
//    _lastCycleType[2] = _lastCycleType[1] = _lastCycleType[0] = CycleType::S;
//#endif

  _totalCycles += cycles;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::incSCycles(uInt32 addr, AccessType accessType)
{
  THUMB_STAT(_stats.sCylces)
  uInt32 cycles = 0;

  if(addr & 0xC0000000) // RAM, peripherals
    cycles = 1;
  else // Flash
  {
    if(mamcr == MamModeType::mode0 ||
       (mamcr == MamModeType::mode1 && accessType == AccessType::data))
    {
      cycles = _flashCycles; // 3|4
    }
    else
    {
      if(isMamBuffered(addr, accessType) || mamcr == MamModeType::modeX)
        cycles = 1;
      else
        cycles = _flashCycles;
    }
  }

#ifdef MERGE_I_S
  //if(accessType != AccessType::prefetch)
  //{
  //  if(_lastCycleType[0] == CycleType::I)
  //  {
  //    _lastCycleType[0] = CycleType::S; // merge cannot be used twice!
  //    --cycles;
  //  }
  //}
  //else if(_lastCycleType[2] == CycleType::I)
  //  --cycles;

  //if(accessType == AccessType::prefetch &&
  //  _lastCycleType[_pipeIdx] == CycleType::I)
  //  --cycles;


  _lastCycleType[2] = _lastCycleType[1];
  _lastCycleType[1] = _lastCycleType[0];
  _lastCycleType[0] = CycleType::S;
  //_lastCycleType[_pipeIdx] = CycleType::S;
#endif
  incCycles(accessType, cycles);


#ifdef MERGE_I_S
  if(accessType == AccessType::branch)
  {
    if(_lastCycleType[1] == CycleType::I || _lastCycleType[2] == CycleType::I)
    _lastCycleType[1] = _lastCycleType[2] = CycleType::S;
    //if(_lastCycleType[_pipeIdx ^ 1] == CycleType::I || _lastCycleType[_pipeIdx ^ 2] == CycleType::I)
    //  _lastCycleType[_pipeIdx ^ 1] = _lastCycleType[_pipeIdx ^ 2] = CycleType::S;
  }
#endif // MERGE_I_S
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::incNCycles(uInt32 addr, AccessType accessType)
{
  THUMB_STAT(_stats.nCylces)
  uInt32 cycles = 0;

  if(addr & 0xC0000000) // RAM, peripherals
    cycles = 1;
  else // Flash
  {
    if(mamcr < MamModeType::mode2)
      cycles = _flashCycles; // 3|4
    else
      if(isMamBuffered(addr, accessType) || mamcr == MamModeType::modeX)
        cycles = 1;
      else
        cycles = _flashCycles;
  }
#ifdef MERGE_I_S
  _lastCycleType[2] = _lastCycleType[1];
  _lastCycleType[1] = _lastCycleType[0];
  _lastCycleType[0] = CycleType::N;
  //_lastCycleType[_pipeIdx] = CycleType::N;
#endif
  incCycles(accessType, cycles);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Thumbulator::incICycles(uInt32 m)
{
  THUMB_STAT(_stats.iCylces)

 #ifdef EMULATE_PIPELINE
  _fetchPipeline += m;
  //if(_memory0Pipeline)
  //{
  //  --_memory0Pipeline; // == 0
  //  ++_fetchPipeline;
  //}

  // TODO: m!
  if(_memory1Pipeline)
  {
    --_memory1Pipeline;
    ++_memory0Pipeline; // == 1
  }
 #endif
#ifdef MERGE_I_S
  _lastCycleType[2] = _lastCycleType[1];
  _lastCycleType[1] = _lastCycleType[0];
  _lastCycleType[0] = CycleType::I;
  //_lastCycleType[_pipeIdx] = CycleType::I;
#endif
  _totalCycles += m;
}

#endif // THUMB_CYCLE_COUNT

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Thumbulator::searchPattern(uInt32 pattern, uInt32 repeats) const
{
  // Note: The pattern is defined in 1-0-3-2 byte order!
  const uInt16 patternLo = pattern >> 16;
  const uInt16 patternHi = pattern & 0xffff;
  uInt32 count = 0;

  // The pattern is always aligned to 4
  for(uInt32 i = 0; i < romSize/2 - 2; i += 2)
  {
    if(rom[i] == patternLo && rom[i + 1] == patternHi)
      if(++count == repeats)
        return true;
  }
  return false;
}
