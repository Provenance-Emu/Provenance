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

#include "Event.hxx"
#include "Keyboard.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Keyboard::Keyboard(Jack jack, const Event& event, const System& system)
  : Controller(jack, event, system, Controller::Type::Keyboard)
{
  if(myJack == Jack::Left)
  {
    myOneEvent   = Event::LeftKeyboard1;
    myTwoEvent   = Event::LeftKeyboard2;
    myThreeEvent = Event::LeftKeyboard3;
    myFourEvent  = Event::LeftKeyboard4;
    myFiveEvent  = Event::LeftKeyboard5;
    mySixEvent   = Event::LeftKeyboard6;
    mySevenEvent = Event::LeftKeyboard7;
    myEightEvent = Event::LeftKeyboard8;
    myNineEvent  = Event::LeftKeyboard9;
    myStarEvent  = Event::LeftKeyboardStar;
    myZeroEvent  = Event::LeftKeyboard0;
    myPoundEvent = Event::LeftKeyboardPound;
  }
  else
  {
    myOneEvent   = Event::RightKeyboard1;
    myTwoEvent   = Event::RightKeyboard2;
    myThreeEvent = Event::RightKeyboard3;
    myFourEvent  = Event::RightKeyboard4;
    myFiveEvent  = Event::RightKeyboard5;
    mySixEvent   = Event::RightKeyboard6;
    mySevenEvent = Event::RightKeyboard7;
    myEightEvent = Event::RightKeyboard8;
    myNineEvent  = Event::RightKeyboard9;
    myStarEvent  = Event::RightKeyboardStar;
    myZeroEvent  = Event::RightKeyboard0;
    myPoundEvent = Event::RightKeyboardPound;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Keyboard::ColumnState Keyboard::processColumn(const Event::Type buttons[])
{
  static constexpr DigitalPin signals[] =
    {DigitalPin::One, DigitalPin::Two, DigitalPin::Three, DigitalPin::Four};

  for (uInt8 i = 0; i < 4; i++)
    if (myEvent.get(buttons[i]) && !getPin(signals[i])) return ColumnState::gnd;

  for (uInt8 i = 0; i < 4; i++)
    if (myEvent.get(buttons[i]) && getPin(signals[i])) return ColumnState::vcc;

  return ColumnState::notConnected;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AnalogReadout::Connection
Keyboard::columnStateToAnalogSignal(ColumnState state)
{
  switch (state)
  {
    case ColumnState::gnd:
      return AnalogReadout::connectToGround();

    case ColumnState::vcc:
       return AnalogReadout::connectToVcc();

    case ColumnState::notConnected:
      return AnalogReadout::connectToVcc(INTERNAL_RESISTANCE);

    default:
      throw runtime_error("unreachable");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Keyboard::write(DigitalPin pin, bool value)
{
  setPin(pin, value);

  const Event::Type col0[] = {myOneEvent, myFourEvent, mySevenEvent, myStarEvent};
  const Event::Type col1[] = {myTwoEvent, myFiveEvent, myEightEvent, myZeroEvent};
  const Event::Type col2[] = {myThreeEvent, mySixEvent, myNineEvent, myPoundEvent};

  const ColumnState stateCol0 = processColumn(col0);
  const ColumnState stateCol1 = processColumn(col1);
  const ColumnState stateCol2 = processColumn(col2);

  setPin(DigitalPin::Six, stateCol2 != ColumnState::gnd);
  setPin(AnalogPin::Five, columnStateToAnalogSignal(stateCol1));
  setPin(AnalogPin::Nine, columnStateToAnalogSignal(stateCol0));
}
