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

#include "System.hxx"
#include "Settings.hxx"
#include "CartARM.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeARM::CartridgeARM(const Settings& settings, string_view md5)
  : Cartridge(settings, md5)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARM::reset()
{
  if(myPlusROM->isValid())
    myPlusROM->reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARM::setInitialState()
{
  const bool devSettings = mySettings.getBool("dev.settings");

  if(devSettings)
  {
    myIncCycles = mySettings.getBool("dev.thumb.inccycles");
    myThumbEmulator->setChipType(static_cast<Thumbulator::ChipType>(mySettings.getInt("dev.thumb.chiptype")));
    myThumbEmulator->setMamMode(static_cast<Thumbulator::MamModeType>(mySettings.getInt("dev.thumb.mammode")));
  }
  else
  {
    myIncCycles = false;
    myThumbEmulator->setChipType();
  }
  enableCycleCount(devSettings);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARM::consoleChanged(ConsoleTiming timing)
{
  myThumbEmulator->setConsoleTiming(timing);

  constexpr double NTSC  = 1193191.66666667;  // NTSC  6507 clock rate
  constexpr double PAL   = 1182298;           // PAL   6507 clock rate
  constexpr double SECAM = 1187500;           // SECAM 6507 clock rate

  switch(timing)
  {
    case ConsoleTiming::ntsc:   myClockRate = NTSC;   break;
    case ConsoleTiming::pal:    myClockRate = PAL;    break;
    case ConsoleTiming::secam:  myClockRate = SECAM;  break;
    default:  break;  // satisfy compiler
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARM::updateCycles(int cycles)
{
  if(myIncCycles)
    mySystem->incrementCycles(cycles);
#ifdef DEBUGGER_SUPPORT
  myPrevStats = myStats;
  myStats = myThumbEmulator->stats();
  myPrevCycles = myCycles;
  myCycles = myThumbEmulator->cycles();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARM::incCycles(bool enable)
{
  myIncCycles = enable;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARM::cycleFactor(double factor)
{
  myThumbEmulator->cycleFactor(factor);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeARM::save(Serializer& out) const
{
#ifdef DEBUGGER_SUPPORT
  try
  {
    out.putInt(myPrevCycles);
    out.putInt(myPrevStats.instructions);
    out.putInt(myCycles);
    out.putInt(myStats.instructions);

    if(myPlusROM->isValid() && !myPlusROM->save(out))
      return false;
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeARM::save\n";
    return false;
  }
#endif
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeARM::load(Serializer& in)
{
#ifdef DEBUGGER_SUPPORT
  try
  {
    myPrevCycles = in.getInt();
    myPrevStats.instructions = in.getInt();
    myCycles = in.getInt();
    myStats.instructions = in.getInt();

    if(myPlusROM->isValid() && !myPlusROM->load(in))
      return false;
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeARM::load\n";
    return false;
  }
#endif
  return true;
}
