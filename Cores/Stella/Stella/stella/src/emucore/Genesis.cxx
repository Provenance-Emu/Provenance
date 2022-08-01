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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "Genesis.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Genesis::Genesis(Jack jack, const Event& event, const System& system)
  : Joystick(jack, event, system, Controller::Type::Genesis)
{
  if(myJack == Jack::Left)
    myButtonCEvent = Event::LeftJoystickFire5;
  else
    myButtonCEvent = Event::RightJoystickFire5;

  setPin(AnalogPin::Five, AnalogReadout::connectToVcc());
  setPin(AnalogPin::Nine, AnalogReadout::connectToVcc());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Genesis::updateButtons()
{
  bool firePressed = myEvent.get(myFireEvent) != 0;
  // The Genesis has one more button (C) that can be read by the 2600
  // However, it seems to work opposite to the BoosterGrip controller,
  // in that the logic is inverted
  bool buttonCPressed = myEvent.get(myButtonCEvent) != 0;

  updateMouseButtons(firePressed, buttonCPressed);

  setPin(DigitalPin::Six, !getAutoFireState(firePressed));
  setPin(AnalogPin::Five, buttonCPressed ? AnalogReadout::connectToGround() : AnalogReadout::connectToVcc());
}
