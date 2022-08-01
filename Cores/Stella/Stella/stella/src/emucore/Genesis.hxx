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

#ifndef GENESIS_HXX
#define GENESIS_HXX

#include "Joystick.hxx"

/**
  The standard Sega Genesis controller works with the 2600 console for
  joystick directions and some of the buttons.  Button 'B' corresponds to
  the normal fire button (joy0fire), while button 'C' is read through
  INPT1 (analog pin 5).

  @author  Stephen Anthony
*/
class Genesis : public Joystick
{
  public:
    /**
      Create a new Genesis gamepad plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller
    */
    Genesis(Jack jack, const Event& event, const System& system);
    ~Genesis() override = default;

  public:
    /**
      Returns the name of this controller.
    */
    string name() const override { return "Sega Genesis"; }

  private:
    /**
      Update the button pin states.
    */
    void updateButtons() override;

  private:
    // Pre-compute the events we care about based on given port
    // This will eliminate test for left or right port in update()
    Event::Type myButtonCEvent;

  private:
    // Following constructors and assignment operators not supported
    Genesis() = delete;
    Genesis(const Genesis&) = delete;
    Genesis(Genesis&&) = delete;
    Genesis& operator=(const Genesis&) = delete;
    Genesis& operator=(Genesis&&) = delete;
};

#endif
