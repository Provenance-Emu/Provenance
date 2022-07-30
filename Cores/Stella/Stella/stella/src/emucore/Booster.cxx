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

#include "Booster.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BoosterGrip::BoosterGrip(Jack jack, const Event& event, const System& system)
  : Joystick(jack, event, system, Controller::Type::BoosterGrip)
{
  if(myJack == Jack::Left)
  {
    myBoosterEvent = Event::LeftJoystickFire5;
    myTriggerEvent = Event::LeftJoystickFire9;
  }
  else
  {
    myBoosterEvent = Event::RightJoystickFire5;
    myTriggerEvent = Event::RightJoystickFire9;
  }

  setPin(AnalogPin::Five, AnalogReadout::disconnect());
  setPin(AnalogPin::Nine, AnalogReadout::disconnect());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void BoosterGrip::updateButtons()
{
  bool firePressed = myEvent.get(myFireEvent) != 0;
  // The CBS Booster-grip has two more buttons on it.  These buttons are
  // connected to the inputs usually used by paddles.
  const bool triggerPressed = myEvent.get(myTriggerEvent) != 0;
  bool boosterPressed = myEvent.get(myBoosterEvent) != 0;

  updateMouseButtons(firePressed, boosterPressed);

  setPin(DigitalPin::Six, !getAutoFireState(firePressed));
  setPin(AnalogPin::Five, boosterPressed ? AnalogReadout::connectToVcc() : AnalogReadout::disconnect());
  setPin(AnalogPin::Nine, triggerPressed ? AnalogReadout::connectToVcc() : AnalogReadout::disconnect());
}
