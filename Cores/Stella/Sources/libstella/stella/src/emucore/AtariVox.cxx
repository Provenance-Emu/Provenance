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

#include "MediaFactory.hxx"
#include "System.hxx"
#include "AtariVox.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AtariVox::AtariVox(Jack jack, const Event& event, const System& system,
                   const string& portname, const FSNode& eepromfile,
                   const onMessageCallback& callback)
  : SaveKey(jack, event, system, eepromfile, callback, Controller::Type::AtariVox),
    mySerialPort{MediaFactory::createSerialPort()}
{
  if(mySerialPort->openPort(portname))
  {
    myCTSFlip = !mySerialPort->isCTS();
    if(myCTSFlip)
      myAboutString = " (serial port \'" + portname + "\', inverted CTS)";
    else
      myAboutString = " (serial port \'" + portname + "\')";
  }
  else
    myAboutString = " (invalid serial port \'" + portname + "\')";

  setPin(DigitalPin::Three, true);
  setPin(DigitalPin::Four, true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AtariVox::~AtariVox()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AtariVox::read(DigitalPin pin)
{
  // We need to override the Controller::read() method, since the timing
  // of the actual read is important for the EEPROM (we can't just read
  // 60 times per second in the ::update() method)
  switch(pin)
  {
    // Pin 2: SpeakJet READY
    //        READY signal is sent directly to pin 2
    case DigitalPin::Two:
    {
      // Some USB-serial adaptors support only CTS, others support only
      // software flow control
      // So we check the state of both then AND the results, on the
      // assumption that if a mode isn't supported, then it reads as TRUE
      // and doesn't change the boolean result
      // Thus the logic is:
      //   READY_SIGNAL = READY_STATE_CTS && READY_STATE_FLOW
      // Note that we also have to take inverted CTS into account

      // When using software flow control, only update on a state change
      uInt8 flowCtrl = 0;
      if(mySerialPort->readByte(flowCtrl))
        myReadyStateSoftFlow = flowCtrl == 0x11;  // XON

      // Now combine the results of CTS and'ed with flow control
      return setPin(pin,
          (mySerialPort->isCTS() ^ myCTSFlip) && myReadyStateSoftFlow);
    }

    default:
      return SaveKey::read(pin);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariVox::write(DigitalPin pin, bool value)
{
  // Change the pin state based on value
  switch(pin)
  {
    // Pin 1: SpeakJet DATA
    //        output serial data to the speakjet
    case DigitalPin::One:
      setPin(pin, value);
      clockDataIn(value);
      break;

    default:
      SaveKey::write(pin, value);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariVox::clockDataIn(bool value)
{
  if(value && (myShiftCount == 0))
    return;

  // If this is the first write this frame, or if it's been a long time
  // since the last write, start a new data byte.
  const uInt64 cycle = mySystem.cycles();
  if((cycle < myLastDataWriteCycle) || (cycle > myLastDataWriteCycle + 1000))
  {
    myShiftRegister = 0;
    myShiftCount = 0;
  }

  // If this is the first write this frame, or if it's been 62 cycles
  // since the last write, shift this bit into the current byte.
  if((cycle < myLastDataWriteCycle) || (cycle >= myLastDataWriteCycle + 62))
  {
    myShiftRegister >>= 1;
    myShiftRegister |= (value << 15);
    if(++myShiftCount == 10)
    {
      myShiftCount = 0;
      myShiftRegister >>= 6;
      if(!(myShiftRegister & (1<<9)))
        cerr << "AtariVox: bad start bit\n";
      else if((myShiftRegister & 1))
        cerr << "AtariVox: bad stop bit\n";
      else
      {
        const uInt8 data = ((myShiftRegister >> 1) & 0xff);
        mySerialPort->writeByte(data);
      }
      myShiftRegister = 0;
    }
  }

  myLastDataWriteCycle = cycle;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AtariVox::reset()
{
  myLastDataWriteCycle = 0;
  SaveKey::reset();
}
