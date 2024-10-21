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
#include "TIA.hxx"
#include "FrameBuffer.hxx"

#include "Lightgun.hxx"

// |              | Left port   | Right port  |
// | Fire button  | SWCHA bit 4 | SWCHA bit 0 | DP:1
// | Detect light | INPT4 bit 7 | INPT5 bit 7 | DP:6

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Lightgun::Lightgun(Jack jack, const Event& event, const System& system,
                   string_view romMd5, const FrameBuffer& frameBuffer)
  : Controller(jack, event, system, Controller::Type::Lightgun),
    myFrameBuffer{frameBuffer}
{
  // Right now, there are only three games and a test ROM that use the light gun
  if (romMd5 == "8da51e0c4b6b46f7619425119c7d018e" ||
      romMd5 == "7e5ee26bc31ae8e4aa61388c935b9332")
  {
    // Sentinel
    myOfsX = -24;
    myOfsY = -5;
  }
  else if (romMd5 == "10c47acca2ecd212b900ad3cf6942dbb" ||
           romMd5 == "15c11ab6e4502b2010b18366133fc322" ||
           romMd5 == "557e893616648c37a27aab5a47acbf10" ||
           romMd5 == "5d7293f1892b66c014e8d222e06f6165" ||
           romMd5 == "b2ab209976354ad4a0e1676fc1fe5a82" ||
           romMd5 == "b5a1a189601a785bdb2f02a424080412" ||
           romMd5 == "c5bf03028b2e8f4950ec8835c6811d47" ||
           romMd5 == "f0ef9a1e5d4027a157636d7f19952bb5")
  {
    // Shooting Arcade
    myOfsX = -21;
    myOfsY = 5;
  }
  else if (romMd5 == "2559948f39b91682934ea99d90ede631" ||
           romMd5 == "e75ab446017448045b152eea78bf7910")
  {
    // Bobby is Hungry
    myOfsX = -21;
    myOfsY = 5;
  }
  else if (romMd5 == "d65900fefa7dc18ac3ad99c213e2fa4e")
  {
    // Guntest
    myOfsX = -25;
    myOfsY = 1;
  }
  else
  {
    // unknown game, use average values
    myOfsX = -23;
    myOfsY = 1;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Lightgun::read(DigitalPin pin)
{
  // We need to override the Controller::read() method, since the lightgun
  // checks this multiple times per frame
  // (we can't just read 60 times per second in the ::update() method)
  switch (pin)
  {
    case DigitalPin::Six: // INPT4/5
    {
      const Common::Rect& rect = myFrameBuffer.imageRect();

      // abort when no valid framebuffer exists
      if (rect.w() == 0 || rect.h() == 0)
        return false;

      const TIA& tia = mySystem.tia();
      // scale mouse coordinates into TIA coordinates
      const Int32 xMouse = (myEvent.get(Event::MouseAxisXValue) - rect.x())
          * tia.width() / rect.w();
      const Int32 yMouse = (myEvent.get(Event::MouseAxisYValue) - rect.y())
          * tia.height() / rect.h();

      // get adjusted TIA coordinates
      Int32 xTia = tia.clocksThisLine() - TIAConstants::H_BLANK_CLOCKS + myOfsX;
      const Int32 yTia = tia.scanlines() - tia.startLine() + myOfsY;

      if (xTia < 0)
        xTia += TIAConstants::H_CLOCKS;

      return (xTia - xMouse) < 0 || (xTia - xMouse) >= 15 ||
             (yTia - yMouse) < 0;
    }
    default:
      return Controller::read(pin);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Lightgun::update()
{
  // Digital events (from keyboard or joystick hats & buttons)
  bool firePressed = myEvent.get(Event::LeftJoystickFire) != 0;

  // We allow left and right mouse buttons for fire button
  firePressed = firePressed
    || myEvent.get(Event::MouseButtonLeftValue)
    || myEvent.get(Event::MouseButtonRightValue);

  setPin(DigitalPin::One, !getAutoFireState(firePressed));
}
