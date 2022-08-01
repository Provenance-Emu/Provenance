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

#include "Joystick.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Joystick::Joystick(Jack jack, const Event& event, const System& system, bool altmap)
  : Joystick(jack, event, system, Controller::Type::Joystick, altmap)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Joystick::Joystick(Jack jack, const Event& event, const System& system,
                   Controller::Type type, bool altmap)
  : Controller(jack, event, system, type)
{
  if(myJack == Jack::Left)
  {
    if(!altmap)
    {
      myUpEvent    = Event::LeftJoystickUp;
      myDownEvent  = Event::LeftJoystickDown;
      myLeftEvent  = Event::LeftJoystickLeft;
      myRightEvent = Event::LeftJoystickRight;
      myFireEvent  = Event::LeftJoystickFire;
    }
    else
    {
      myUpEvent    = Event::QTJoystickThreeUp;
      myDownEvent  = Event::QTJoystickThreeDown;
      myLeftEvent  = Event::QTJoystickThreeLeft;
      myRightEvent = Event::QTJoystickThreeRight;
      myFireEvent  = Event::QTJoystickThreeFire;
    }
  }
  else
  {
    if(!altmap)
    {
      myUpEvent    = Event::RightJoystickUp;
      myDownEvent  = Event::RightJoystickDown;
      myLeftEvent  = Event::RightJoystickLeft;
      myRightEvent = Event::RightJoystickRight;
      myFireEvent  = Event::RightJoystickFire;
    }
    else
    {
      myUpEvent    = Event::QTJoystickFourUp;
      myDownEvent  = Event::QTJoystickFourDown;
      myLeftEvent  = Event::QTJoystickFourLeft;
      myRightEvent = Event::QTJoystickFourRight;
      myFireEvent  = Event::QTJoystickFourFire;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joystick::update()
{
  updateButtons();

  updateDigitalAxes();
  updateMouseAxes();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joystick::updateButtons()
{
  bool firePressed = myEvent.get(myFireEvent) != 0;

  // The joystick uses both mouse buttons for the single joystick button
  updateMouseButtons(firePressed, firePressed);

  setPin(DigitalPin::Six, !getAutoFireState(firePressed));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joystick::updateMouseButtons(bool& pressedLeft, bool& pressedRight)
{
  if(myControlID > -1)
  {
    pressedLeft |= (myEvent.get(Event::MouseButtonLeftValue) != 0);
    pressedRight |= (pressedRight || myEvent.get(Event::MouseButtonRightValue) != 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joystick::updateDigitalAxes()
{
  // Digital events (from keyboard or joystick hats & buttons)
  setPin(DigitalPin::One, myEvent.get(myUpEvent) == 0);
  setPin(DigitalPin::Two, myEvent.get(myDownEvent) == 0);
  setPin(DigitalPin::Three, myEvent.get(myLeftEvent) == 0);
  setPin(DigitalPin::Four, myEvent.get(myRightEvent) == 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Joystick::updateMouseAxes()
{
  // Mouse motion and button events
  if(myControlID > -1)
  {
    // The following code was taken from z26
    static constexpr int MJ_Threshold = 2;
    const int mousex = myEvent.get(Event::MouseAxisXMove),
              mousey = myEvent.get(Event::MouseAxisYMove);

    if(mousex || mousey)
    {
      if((!(abs(mousey) > abs(mousex) << 1)) && (abs(mousex) >= MJ_Threshold))
      {
        if(mousex < 0)
          setPin(DigitalPin::Three, false);
        else if(mousex > 0)
          setPin(DigitalPin::Four, false);
      }

      if((!(abs(mousex) > abs(mousey) << 1)) && (abs(mousey) >= MJ_Threshold))
      {
        if(mousey < 0)
          setPin(DigitalPin::One, false);
        else if(mousey > 0)
          setPin(DigitalPin::Two, false);
      }
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Joystick::setMouseControl(
    Controller::Type xtype, int xid, Controller::Type ytype, int yid)
{
  // Currently, the joystick takes full control of the mouse, using both
  // axes for its two degrees of movement
  if(xtype == myType && ytype == myType && xid == yid)
  {
    myControlID = ((myJack == Jack::Left && xid == 0) ||
                   (myJack == Jack::Right && xid == 1)
                  ) ? xid : -1;
  }
  else
    myControlID = -1;

  return true;
}
