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

#include "Console.hxx"
#include "Settings.hxx"
#include "Switches.hxx"
#include "System.hxx"
#include "Base.hxx"

#include "M6532.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
M6532::M6532(const ConsoleIO& console, const Settings& settings)
  : myConsole{console},
    mySettings{settings}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::reset()
{
  static constexpr std::array<uInt8, 128> RAM_7800 = {
    0xA9, 0x00, 0xAA, 0x85, 0x01, 0x95, 0x03, 0xE8, 0xE0, 0x2A, 0xD0, 0xF9, 0x85, 0x02, 0xA9, 0x04,
    0xEA, 0x30, 0x23, 0xA2, 0x04, 0xCA, 0x10, 0xFD, 0x9A, 0x8D, 0x10, 0x01, 0x20, 0xCB, 0x04, 0x20,
    0xCB, 0x04, 0x85, 0x11, 0x85, 0x1B, 0x85, 0x1C, 0x85, 0x0F, 0xEA, 0x85, 0x02, 0xA9, 0x00, 0xEA,
    0x30, 0x04, 0x24, 0x03, 0x30, 0x09, 0xA9, 0x02, 0x85, 0x09, 0x8D, 0x12, 0xF1, 0xD0, 0x1E, 0x24,
    0x02, 0x30, 0x0C, 0xA9, 0x02, 0x85, 0x06, 0x8D, 0x18, 0xF1, 0x8D, 0x60, 0xF4, 0xD0, 0x0E, 0x85,
    0x2C, 0xA9, 0x08, 0x85, 0x1B, 0x20, 0xCB, 0x04, 0xEA, 0x24, 0x02, 0x30, 0xD9, 0xA9, 0xFD, 0x85,
    0x08, 0x6C, 0xFC, 0xFF, 0xEA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  };

  // Initialize the 128 bytes of memory
  const bool devSettings = mySettings.getBool("dev.settings");
  if(mySettings.getString(devSettings ? "dev.console" : "plr.console") == "7800")
    std::copy_n(RAM_7800.begin(), RAM_7800.size(), myRAM.begin());
  else if(mySettings.getBool(devSettings ? "dev.ramrandom" : "plr.ramrandom"))
    for(auto& ram: myRAM)
      ram = mySystem->randGenerator().next();
  else
    myRAM.fill(0);

  myTimer = mySystem->randGenerator().next() & 0xff;
  myDivider = 1024;
  mySubTimer = 0;
  myWrappedThisCycle = false;

  mySetTimerCycle = myLastCycle = 0;

  // Zero the I/O registers
  myDDRA = myDDRB = myOutA = myOutB = 0x00;

  // Zero the timer registers
  myOutTimer.fill(0x00);

  // Zero the interrupt flag register and mark D7 as invalid
  myInterruptFlag = 0x00;

  // Edge-detect set to negative (high to low)
  myEdgeDetectPositive = false;

  // Let the controllers know about the reset
  myConsole.leftController().reset();
  myConsole.rightController().reset();

#ifdef DEBUGGER_SUPPORT
  createAccessBases();
#endif // DEBUGGER_SUPPORT
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::update()
{
  Controller& lport = myConsole.leftController();
  Controller& rport = myConsole.rightController();

  // Get current PA7 state
  const bool prevPA7 = lport.getPin(Controller::DigitalPin::Four);

  // Update entire port state
  lport.update();
  rport.update();
  myConsole.switches().update();

  // Get new PA7 state
  const bool currPA7 = lport.getPin(Controller::DigitalPin::Four);

  // PA7 Flag is set on active transition in appropriate direction
  if((!myEdgeDetectPositive && prevPA7 && !currPA7) ||
     (myEdgeDetectPositive && !prevPA7 && currPA7))
    myInterruptFlag |= PA7Bit;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::updateEmulation()
{
  auto cycles = static_cast<uInt32>(mySystem->cycles() - myLastCycle);
  const uInt32 subTimer = mySubTimer;

  // Guard against further state changes if the debugger alread forwarded emulation
  // state (in particular myWrappedThisCycle)
  if (cycles == 0) return;

  myWrappedThisCycle = false;
  mySubTimer = (cycles + mySubTimer) % myDivider;

  if ((myInterruptFlag & TimerBit) == 0)
  {
    const uInt32 timerTicks = (cycles + subTimer) / myDivider;

    if(timerTicks > myTimer)
    {
      cycles -= ((myTimer + 1) * myDivider - subTimer);

      myWrappedThisCycle = cycles == 0;
      myTimer = 0xFF;
      myInterruptFlag |= TimerBit;
    }
    else
    {
      myTimer -= timerTicks;
      cycles = 0;
    }
  }

  if((myInterruptFlag & TimerBit) != 0) {
    myTimer = (myTimer - cycles) & 0xFF;
    myWrappedThisCycle = myTimer == 0xFF;
  }

  myLastCycle = mySystem->cycles();

#ifdef DEBUGGER_SUPPORT
  myTimWrappedOnRead = myTimWrappedOnWrite = false;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::install(System& system)
{
  installDelegate(system, *this);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::installDelegate(System& system, Device& device)
{
  // Remember which system I'm installed in
  mySystem = &system;

  // All accesses are to the given device
  const System::PageAccess access(&device, System::PageAccessType::READWRITE);

  // Map all peek/poke to mirrors of RIOT address space to this class
  // That is, all mirrors of ZP RAM ($80 - $FF) and IO ($280 - $29F) in the
  // lower 4K of the 2600 address space are mapped here
  // The two types of addresses are differentiated in peek/poke as follows:
  //    (addr & 0x0200) == 0x0200 is IO     (A9 is 1)
  //    (addr & 0x0300) == 0x0100 is Stack  (A8 is 1, A9 is 0)
  //    (addr & 0x0300) == 0x0000 is ZP RAM (A8 is 0, A9 is 0)
  for (uInt16 addr = 0; addr < 0x1000; addr += System::PAGE_SIZE)
    if ((addr & 0x0080) == 0x0080) {
      mySystem->setPageAccess(addr, access);
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 M6532::peek(uInt16 addr)
{
  updateEmulation();

  // A9 distinguishes I/O registers from ZP RAM
  // A9 = 1 is read from I/O
  // A9 = 0 is read from RAM
  if((addr & 0x0200) == 0x0000)
    return myRAM[addr & 0x007f];

  switch(addr & 0x07)
  {
    case 0x00:    // SWCHA - Port A I/O Register (Joystick)
    {
      const uInt8 value = (myConsole.leftController().read() << 4) |
                           myConsole.rightController().read();

      // Each pin is high (1) by default and will only go low (0) if either
      //  (a) External device drives the pin low
      //  (b) Corresponding bit in SWACNT = 1 and SWCHA = 0
      // Thanks to A. Herbert for this info
      return (myOutA | ~myDDRA) & value;
    }

    case 0x01:    // SWACNT - Port A Data Direction Register
    {
      return myDDRA;
    }

    case 0x02:    // SWCHB - Port B I/O Register (Console switches)
    {
      return (myOutB | ~myDDRB) & (myConsole.switches().read() | myDDRB);
    }

    case 0x03:    // SWBCNT - Port B Data Direction Register
    {
      return myDDRB;
    }

    case 0x04:    // INTIM - Timer Output
    case 0x06:
    {
      // Timer Flag is always cleared when accessing INTIM
      if (!myWrappedThisCycle) myInterruptFlag &= ~TimerBit;
  #ifdef DEBUGGER_SUPPORT
      myTimWrappedOnRead = myWrappedThisCycle;
      myTimReadCycles += 7;
  #endif
      return myTimer;
    }

    case 0x05:    // TIMINT/INSTAT - Interrupt Flag
    case 0x07:
    {
      // PA7 Flag is always cleared after accessing TIMINT
      const uInt8 result = myInterruptFlag;
      myInterruptFlag &= ~PA7Bit;
    #ifdef DEBUGGER_SUPPORT
      myTimReadCycles += 7;
    #endif
      return result;
    }

    default:
    {
#ifdef DEBUG_ACCESSES
      cerr << "BAD M6532 Peek: " << hex << addr << '\n';
#endif
      return 0;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool M6532::poke(uInt16 addr, uInt8 value)
{
  updateEmulation();

  // A9 distinguishes I/O registers from ZP RAM
  // A9 = 1 is write to I/O
  // A9 = 0 is write to RAM
  if((addr & 0x0200) == 0x0000)
  {
    myRAM[addr & 0x007f] = value;
    return true;
  }

  // A2 distinguishes I/O registers from the timer
  // A2 = 1 is write to timer
  // A2 = 0 is write to I/O
  if((addr & 0x04) != 0)
  {
    // A4 = 1 is write to TIMxT (x = 1, 8, 64, 1024)
    // A4 = 0 is write to edge detect control
    if((addr & 0x10) != 0)
      setTimerRegister(value, addr & 0x03);  // A1A0 determines interval
    else
      myEdgeDetectPositive = addr & 0x01;    // A0 determines direction
  }
  else
  {
    switch(addr & 0x03)
    {
      case 0:     // SWCHA - Port A I/O Register (Joystick)
      {
        myOutA = value;
        setPinState(true);
        break;
      }

      case 1:     // SWACNT - Port A Data Direction Register
      {
        myDDRA = value;
        setPinState(false);
        break;
      }

      case 2:     // SWCHB - Port B I/O Register (Console switches)
      {
        myOutB = value;
        break;
      }

      case 3:     // SWBCNT - Port B Data Direction Register
      {
        myDDRB = value;
        break;
      }

      default:  // satisfy compiler
        break;
    }
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::setTimerRegister(uInt8 value, uInt8 interval)
{
  static constexpr std::array<uInt32, 4> divider = { 1, 8, 64, 1024 };

  myDivider = divider[interval];
  myOutTimer[interval] = value;

  myTimer = value;
  mySubTimer = myDivider - 1;

  // Interrupt timer flag is cleared (and invalid) when writing to the timer
  if (!myWrappedThisCycle) myInterruptFlag &= ~TimerBit;
#ifdef DEBUGGER_SUPPORT
  myTimWrappedOnWrite = myWrappedThisCycle;
#endif

  mySetTimerCycle = mySystem->cycles();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::setPinState(bool swcha)
{
  /*
    When a bit in the DDR is set as input, +5V is placed on its output
    pin.  When it's set as output, either +5V or 0V (depending on the
    contents of SWCHA) will be placed on the output pin.
    The standard macros for the AtariVox and SaveKey use this fact to
    send data to the port.  This is represented by the following algorithm:

      if(DDR bit is input)       set output as 1
      else if(DDR bit is output) set output as bit in ORA
  */
  Controller& lport = myConsole.leftController();
  Controller& rport = myConsole.rightController();

  const uInt8 ioport = myOutA | ~myDDRA;

  lport.write(Controller::DigitalPin::One,   ioport & 0b00010000);
  lport.write(Controller::DigitalPin::Two,   ioport & 0b00100000);
  lport.write(Controller::DigitalPin::Three, ioport & 0b01000000);
  lport.write(Controller::DigitalPin::Four,  ioport & 0b10000000);
  rport.write(Controller::DigitalPin::One,   ioport & 0b00000001);
  rport.write(Controller::DigitalPin::Two,   ioport & 0b00000010);
  rport.write(Controller::DigitalPin::Three, ioport & 0b00000100);
  rport.write(Controller::DigitalPin::Four,  ioport & 0b00001000);

  if(swcha)
  {
    lport.controlWrite(ioport);
    rport.controlWrite(ioport);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool M6532::save(Serializer& out) const
{
  try
  {
    out.putByteArray(myRAM.data(), myRAM.size());

    out.putInt(myTimer);
    out.putInt(mySubTimer);
    out.putInt(myDivider);
    out.putBool(myWrappedThisCycle);
    out.putLong(myLastCycle);
    out.putLong(mySetTimerCycle);
  #ifdef DEBUGGER_SUPPORT
    out.putInt(myTimReadCycles);
  #endif

    out.putByte(myDDRA);
    out.putByte(myDDRB);
    out.putByte(myOutA);
    out.putByte(myOutB);

    out.putByte(myInterruptFlag);
    out.putBool(myEdgeDetectPositive);
    out.putByteArray(myOutTimer.data(), myOutTimer.size());
  }
  catch(...)
  {
    cerr << "ERROR: M6532::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool M6532::load(Serializer& in)
{
  try
  {
    in.getByteArray(myRAM.data(), myRAM.size());

    myTimer = in.getInt();
    mySubTimer = in.getInt();
    myDivider = in.getInt();
    myWrappedThisCycle = in.getBool();
    myLastCycle = in.getLong();
    mySetTimerCycle = in.getLong();
  #ifdef DEBUGGER_SUPPORT
    myTimReadCycles = in.getInt();
  #endif

    myDDRA = in.getByte();
    myDDRB = in.getByte();
    myOutA = in.getByte();
    myOutB = in.getByte();

    myInterruptFlag = in.getByte();
    myEdgeDetectPositive = in.getBool();
    in.getByteArray(myOutTimer.data(), myOutTimer.size());
  }
  catch(...)
  {
    cerr << "ERROR: M6532::load\n";
    return false;
  }

  return true;
}

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 M6532::intim()
{
  updateEmulation();

  return myTimer;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 M6532::timint()
{
  updateEmulation();

  return myInterruptFlag;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Int32 M6532::intimClocks()
{
  updateEmulation();

  // This method is similar to intim(), except instead of giving the actual
  // INTIM value, it will give the current number of CPU clocks since the last
  // TIMxxT write

  return ((myInterruptFlag & TimerBit) != 0) ? 1 : (myDivider - mySubTimer);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 M6532::timerClocks() const
{
  return static_cast<uInt32>(mySystem->cycles() - mySetTimerCycle);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::createAccessBases()
{
  myRAMAccessBase.fill(Device::NONE);
  myStackAccessBase.fill(Device::NONE);
  myIOAccessBase.fill(Device::NONE);
  myRAMAccessCounter.fill(0);
  myStackAccessCounter.fill(0);
  myIOAccessCounter.fill(0);
  myZPAccessDelay.fill(ZP_DELAY);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Device::AccessFlags M6532::getAccessFlags(uInt16 address) const
{
  if (address & IO_BIT)
    return myIOAccessBase[address & IO_MASK];
  else if (address & STACK_BIT)
    return myStackAccessBase[address & STACK_MASK];
  else
    return myRAMAccessBase[address & RAM_MASK];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::setAccessFlags(uInt16 address, Device::AccessFlags flags)
{
  // ignore none flag
  if (flags != Device::NONE) {
    if (address & IO_BIT)
      myIOAccessBase[address & IO_MASK] |= flags;
    else {
      // the first access, either by direct RAM or stack access is assumed as initialization
      if (myZPAccessDelay[address & RAM_MASK])
        myZPAccessDelay[address & RAM_MASK]--;
      else if (address & STACK_BIT)
        myStackAccessBase[address & STACK_MASK] |= flags;
      else
        myRAMAccessBase[address & RAM_MASK] |= flags;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void M6532::increaseAccessCounter(uInt16 address, bool isWrite)
{
  if (address & IO_BIT)
    myIOAccessCounter[(isWrite ? IO_SIZE : 0) + (address & IO_MASK)]++;
  else {
    // the first access, either by direct RAM or stack access is assumed as initialization
    if (myZPAccessDelay[address & RAM_MASK])
      myZPAccessDelay[address & RAM_MASK]--;
    else if (address & STACK_BIT)
      myStackAccessCounter[(isWrite ? STACK_SIZE : 0) + (address & STACK_MASK)]++;
    else
      myRAMAccessCounter[(isWrite ? RAM_SIZE : 0) + (address & RAM_MASK)]++;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string M6532::getAccessCounters() const
{
  ostringstream out;

  out << "RAM reads:\n";
  for(uInt16 addr = 0x00; addr < RAM_SIZE; ++addr)
    out << Common::Base::HEX4 << (addr | 0x80) << ","
    << Common::Base::toString(myRAMAccessCounter[addr], Common::Base::Fmt::_10_8) << ", ";
  out << "\n";
  out << "RAM writes:\n";
  for(uInt16 addr = 0x00; addr < RAM_SIZE; ++addr)
    out << Common::Base::HEX4 << (addr | 0x80) << ","
    << Common::Base::toString(myRAMAccessCounter[RAM_SIZE + addr], Common::Base::Fmt::_10_8) << ", ";
  out << "\n";


  out << "Stack reads:\n";
  for(uInt16 addr = 0x00; addr < STACK_SIZE; ++addr)
    out << Common::Base::HEX4 << (addr | 0x180) << ","
    << Common::Base::toString(myStackAccessCounter[addr], Common::Base::Fmt::_10_8) << ", ";
  out << "\n";
  out << "Stack writes:\n";
  for(uInt16 addr = 0x00; addr < STACK_SIZE; ++addr)
    out << Common::Base::HEX4 << (addr | 0x180) << ","
    << Common::Base::toString(myStackAccessCounter[STACK_SIZE + addr], Common::Base::Fmt::_10_8) << ", ";
  out << "\n";

  out << "IO reads:\n";
  for(uInt16 addr = 0x00; addr < IO_SIZE; ++addr)
    out << Common::Base::HEX4 << (addr | 0x280) << ","
    << Common::Base::toString(myIOAccessCounter[addr], Common::Base::Fmt::_10_8) << ", ";
  out << "\n";
  out << "IO writes:\n";
  for(uInt16 addr = 0x00; addr < IO_SIZE; ++addr)
    out << Common::Base::HEX4 << (addr | 0x280) << ","
    << Common::Base::toString(myIOAccessCounter[IO_SIZE + addr], Common::Base::Fmt::_10_8) << ", ";
  out << "\n";

  return out.str();
}

#endif // DEBUGGER_SUPPORT
