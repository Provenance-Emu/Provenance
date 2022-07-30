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

#include "Joy2BPlus.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Joy2BPlus::Joy2BPlus(Jack jack, const Event& event, const System& system)
  : Joystick(jack, event, system, Controller::Type::Joy2BPlus)
{
  if(myJack == Jack::Left)
  {
    myButtonCEvent = Event::LeftJoystickFire5;
    myButton3Event = Event::LeftJoystickFire9;
  }
  else
  {
    myButtonCEvent = Event::RightJoystickFire5;
    myButton3Event = Event::RightJoystickFire9;
  }

  setPin(AnalogPin::Five, AnalogReadout::connectToVcc());
  setPin(AnalogPin::Nine, AnalogReadout::connectToVcc());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joy2BPlus::updateButtons()
{
  bool firePressed = myEvent.get(myFireEvent) != 0;
  // The Joy 2B+ has two more buttons on it.  These buttons are
  // connected to the inputs usually used by paddles.
  bool buttonCPressed = myEvent.get(myButtonCEvent) != 0;
  const bool button3Pressed = myEvent.get(myButton3Event) != 0;

  updateMouseButtons(firePressed, buttonCPressed);

  setPin(DigitalPin::Six, !getAutoFireState(firePressed));
  setPin(AnalogPin::Five, buttonCPressed ? AnalogReadout::connectToGround() : AnalogReadout::connectToVcc());
  setPin(AnalogPin::Nine, button3Pressed ? AnalogReadout::connectToGround() : AnalogReadout::connectToVcc());
}
