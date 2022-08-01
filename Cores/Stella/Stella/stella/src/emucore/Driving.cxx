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

#include "Driving.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Driving::Driving(Jack jack, const Event& event, const System& system, bool altmap)
  : Controller(jack, event, system, Controller::Type::Driving)
{
  if(myJack == Jack::Left)
  {
    if(!altmap)
    {
      myCCWEvent    = Event::LeftDrivingCCW;
      myCWEvent     = Event::LeftDrivingCW;
      myFireEvent   = Event::LeftDrivingFire;
      myAnalogEvent = Event::LeftDrivingAnalog;
    }
    else
    {
      myCCWEvent  = Event::QTJoystickThreeLeft;
      myCWEvent   = Event::QTJoystickThreeRight;
      myFireEvent = Event::QTJoystickThreeFire;
    }
    myXAxisValue = Event::SALeftAxis0Value; // joystick input
    myYAxisValue = Event::SALeftAxis1Value; // driving controller input
  }
  else
  {
    if(!altmap)
    {
      myCCWEvent    = Event::RightDrivingCCW;
      myCWEvent     = Event::RightDrivingCW;
      myFireEvent   = Event::RightDrivingFire;
      myAnalogEvent = Event::RightDrivingAnalog;
    }
    else
    {
      myCCWEvent  = Event::QTJoystickFourLeft;
      myCWEvent   = Event::QTJoystickFourRight;
      myFireEvent = Event::QTJoystickFourFire;
    }
    myXAxisValue = Event::SARightAxis0Value; // joystick input
    myYAxisValue = Event::SARightAxis1Value; // driving controller input
  }

  // Digital pins 3 and 4 are not connected
  setPin(DigitalPin::Three, true);
  setPin(DigitalPin::Four, true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::update()
{
  updateButtons();

  updateControllerAxes();
  updateMouseAxes();
  updateStelladaptorAxes();

  // Gray codes for rotation
  static constexpr std::array<uInt8, 4> graytable = { 0x03, 0x01, 0x00, 0x02 };

  // Determine which bits are set
  const uInt8 gray = graytable[myGrayIndex];
  setPin(DigitalPin::One, (gray & 0x1) != 0);
  setPin(DigitalPin::Two, (gray & 0x2) != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::updateButtons()
{
  bool firePressed = myEvent.get(myFireEvent) != 0;

  // The joystick uses both mouse buttons for the single joystick button
  updateMouseButtons(firePressed);

  setPin(DigitalPin::Six, !getAutoFireState(firePressed));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::updateMouseButtons(bool& firePressed)
{
  if(myControlID > -1)
    firePressed |= (myEvent.get(Event::MouseButtonLeftValue) != 0
      || myEvent.get(Event::MouseButtonRightValue) != 0);
  else
  {
    // Test for 'untied' mouse axis mode, where each axis is potentially
    // mapped to a separate driving controller
    if(myControlIDX > -1)
      firePressed |= (myEvent.get(Event::MouseButtonLeftValue) != 0);
    if(myControlIDY > -1)
      firePressed |= (myEvent.get(Event::MouseButtonRightValue) != 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::updateControllerAxes()
{
  // Digital events (from keyboard or joystick hats & buttons)
  const int d_axis = myEvent.get(myXAxisValue);

  if(myEvent.get(myCCWEvent) != 0 || d_axis < -16384)
    myCounterHires -= 64;
  else if(myEvent.get(myCWEvent) != 0 || d_axis > 16384)
    myCounterHires += 64;

  // Analog events (from joystick axes)
  const int a_axis = myEvent.get(myAnalogEvent);

  if( abs(a_axis) > Controller::analogDeadZone())
  {
    /* a_axis is in -2^15 to +2^15-1; adding 1 when non-negative and
       dividing by 2^9 gives us -2^6 to +2^6, which gives us the same
       range as digital inputs.
    */
    myCounterHires += (a_axis/512) + (a_axis >= 0);
  }

  // Only consider the lower-most bits (corresponding to pins 1 & 2)
  myGrayIndex = static_cast<Int32>((myCounterHires / 256.0F) * SENSITIVITY) & 0b11;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::updateMouseAxes()
{
  static constexpr int MJ_Threshold = 2;

  // Mouse motion and button events
  if(myControlID > -1)
  {
    const int m_axis = myEvent.get(Event::MouseAxisXMove);
    if(m_axis < -MJ_Threshold)
      --myCounter;
    else if(m_axis > MJ_Threshold)
      ++myCounter;
  }
  else
  {
    // Test for 'untied' mouse axis mode, where each axis is potentially
    // mapped to a separate driving controller
    if(myControlIDX > -1)
    {
      const int m_axis = myEvent.get(Event::MouseAxisXMove);
      if(m_axis < -MJ_Threshold)
        --myCounter;
      else if(m_axis > MJ_Threshold)
        ++myCounter;
    }
    if(myControlIDY > -1)
    {
      const int m_axis = myEvent.get(Event::MouseAxisYMove);
      if(m_axis < -MJ_Threshold)
        --myCounter;
      else if(m_axis > MJ_Threshold)
        ++myCounter;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::updateStelladaptorAxes()
{
  static constexpr int SA_Threshold = 4096;

  // Stelladaptor is the only controller that should set this
  const int yaxis = myEvent.get(myYAxisValue);

  // Only overwrite gray code when Stelladaptor input has changed
  // (that means real changes, not just analog signal jitter)
  if((yaxis < (myLastYaxis - 1024)) || (yaxis > (myLastYaxis + 1024)))
  {
    myLastYaxis = yaxis;
    if(yaxis <= -16384 - SA_Threshold)
      myGrayIndex = 3; // up
    else if(yaxis > 16384 + SA_Threshold)
      myGrayIndex = 1; // down
    else if(yaxis >= 16384 - SA_Threshold)
      myGrayIndex = 2; // up + down
    else /* if(yaxis < 16384 - SA_Threshold) */
      myGrayIndex = 0; // no movement

    // Make sure direct gray codes from Stelladaptor stay in sync with
    // simulated gray codes generated by PC keyboard or PC joystick
    // Must be rounded into the middle of the myCounter interval!
    myCounter = (myGrayIndex + 0.5F) * 4.0F / SENSITIVITY;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Driving::setMouseControl(
    Controller::Type xtype, int xid, Controller::Type ytype, int yid)
{
  // When the mouse emulates a single driving controller, only the X-axis is
  // used, and both mouse buttons map to the same 'fire' event
  if(xtype == Controller::Type::Driving && ytype == Controller::Type::Driving && xid == yid)
  {
    myControlID = ((myJack == Jack::Left && xid == 0) ||
                   (myJack == Jack::Right && xid == 1)
                  ) ? xid : -1;
    myControlIDX = myControlIDY = -1;
  }
  else
  {
    // Otherwise, each axis can be mapped to a separate driving controller,
    // and the buttons map to separate (corresponding) controllers
    myControlID = -1;
    if(myJack == Jack::Left)
    {
      myControlIDX = (xtype == Controller::Type::Driving && xid == 0) ? 0 : -1;
      myControlIDY = (ytype == Controller::Type::Driving && yid == 0) ? 0 : -1;
    }
    else  // myJack == Right
    {
      myControlIDX = (xtype == Controller::Type::Driving && xid == 1) ? 1 : -1;
      myControlIDY = (ytype == Controller::Type::Driving && yid == 1) ? 1 : -1;
    }
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Driving::setSensitivity(int sensitivity)
{
  BSPF::clamp(sensitivity, MIN_SENSE, MAX_SENSE, (MIN_SENSE + MAX_SENSE) / 2);
  SENSITIVITY = sensitivity / 10.0F;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float Driving::SENSITIVITY = 1.0F;
