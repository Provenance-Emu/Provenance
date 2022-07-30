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

#include "Console.hxx"
#include "Event.hxx"
#include "System.hxx"
#include "CompuMate.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CompuMate::CompuMate(const Console& console, const Event& event,
                     const System& system)
  : myConsole{console},
    myEvent{event}
{
  // These controller pointers will be retrieved by the Console, which will
  // also take ownership of them
  myLeftController  = make_unique<CMControl>(*this, Controller::Jack::Left, event, system);
  myRightController = make_unique<CMControl>(*this, Controller::Jack::Right, event, system);

  myLeftController->setPin(Controller::AnalogPin::Nine, AnalogReadout::connectToGround());
  myLeftController->setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
  myRightController->setPin(Controller::AnalogPin::Nine, AnalogReadout::connectToVcc());
  myRightController->setPin(Controller::AnalogPin::Five, AnalogReadout::connectToGround());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CompuMate::update()
{
  // Handle SWCHA changes - the following comes almost directly from z26
  Controller& lp = myConsole.leftController();
  Controller& rp = myConsole.rightController();

  lp.setPin(Controller::AnalogPin::Nine, AnalogReadout::connectToGround());
  lp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
  lp.setPin(Controller::DigitalPin::Six, true);
  rp.setPin(Controller::AnalogPin::Nine, AnalogReadout::connectToVcc());
  rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToGround());
  rp.setPin(Controller::DigitalPin::Six, true);

  if (myEvent.get(Event::CompuMateShift))
    rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
  if (myEvent.get(Event::CompuMateFunc))
    lp.setPin(Controller::AnalogPin::Nine, AnalogReadout::connectToVcc());

  rp.setPin(Controller::DigitalPin::Three, true);
  rp.setPin(Controller::DigitalPin::Four, true);

  switch(myColumn)  // This is updated inside CartCM class
  {
    case 0:
      if (myEvent.get(Event::CompuMate7)) lp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateU)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateJ)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateM)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 1:
      if (myEvent.get(Event::CompuMate6)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the '?' character (Shift-6) with the actual question key
      if (myEvent.get(Event::CompuMateQuestion))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateY)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateH)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateN)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 2:
      if (myEvent.get(Event::CompuMate8)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the '[' character (Shift-8) with the actual key
      if (myEvent.get(Event::CompuMateLeftBracket))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateI)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateK)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateComma)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 3:
      if (myEvent.get(Event::CompuMate2)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the '-' character (Shift-2) with the actual minus key
      if (myEvent.get(Event::CompuMateMinus))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateW)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateS)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateX)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 4:
      if (myEvent.get(Event::CompuMate3)) lp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateE)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateD)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateC)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 5:
      if (myEvent.get(Event::CompuMate0)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the quote character (Shift-0) with the actual quote key
      if (myEvent.get(Event::CompuMateQuote))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateP)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateEnter)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateSpace)) rp.setPin(Controller::DigitalPin::Four, false);
      // Emulate Ctrl-space (aka backspace) with the actual Backspace key
      if (myEvent.get(Event::CompuMateBackspace))
      {
        lp.setPin(Controller::AnalogPin::Nine, AnalogReadout::connectToVcc());
        rp.setPin(Controller::DigitalPin::Four, false);
      }
      break;
    case 6:
      if (myEvent.get(Event::CompuMate9)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the ']' character (Shift-9) with the actual key
      if (myEvent.get(Event::CompuMateRightBracket))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateO)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateL)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMatePeriod)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 7:
      if (myEvent.get(Event::CompuMate5)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the '=' character (Shift-5) with the actual equals key
      if (myEvent.get(Event::CompuMateEquals))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateT)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateG)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateB)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 8:
      if (myEvent.get(Event::CompuMate1)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the '+' character (Shift-1) with the actual plus key (Shift-=)
      if (myEvent.get(Event::CompuMatePlus))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateQ)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateA)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateZ)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    case 9:
      if (myEvent.get(Event::CompuMate4)) lp.setPin(Controller::DigitalPin::Six, false);
      // Emulate the '/' character (Shift-4) with the actual slash key
      if (myEvent.get(Event::CompuMateSlash))
      {
        rp.setPin(Controller::AnalogPin::Five, AnalogReadout::connectToVcc());
        lp.setPin(Controller::DigitalPin::Six, false);
      }
      if (myEvent.get(Event::CompuMateR)) rp.setPin(Controller::DigitalPin::Three, false);
      if (myEvent.get(Event::CompuMateF)) rp.setPin(Controller::DigitalPin::Six, false);
      if (myEvent.get(Event::CompuMateV)) rp.setPin(Controller::DigitalPin::Four, false);
      break;
    default:
      break;
  }
}
