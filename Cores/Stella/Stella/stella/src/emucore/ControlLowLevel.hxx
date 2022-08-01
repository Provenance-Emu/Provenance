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

#ifndef CONTROLLER_LOW_LEVEL_HXX
#define CONTROLLER_LOW_LEVEL_HXX

#include "Control.hxx"

/**
  Some subsystems (ie, the debugger) need low-level access to the controller
  ports.  In particular, they need to be able to bypass the normal read/write
  methods and operate directly on the individual pins.  This class provides
  an abstraction for that functionality.

  Classes that inherit from this class will have low-level access to the
  Controller class, since it is a 'friend' of that class.

  @author  Stephen Anthony
*/
class ControllerLowLevel
{
  public:
    explicit ControllerLowLevel(Controller& controller)
      : myController(controller) { }
    virtual ~ControllerLowLevel() = default;

    inline bool setPin(Controller::DigitalPin pin, bool value) {
      return myController.setPin(pin, value);
    }
    inline bool togglePin(Controller::DigitalPin pin) { return false; }
    inline bool getPin(Controller::DigitalPin pin) const {
      return myController.getPin(pin);
    }
    inline void setPin(Controller::AnalogPin pin, AnalogReadout::Connection value) {
      myController.setPin(pin, value);
    }
    inline AnalogReadout::Connection getPin(Controller::AnalogPin pin) const {
      return myController.getPin(pin);
    }
    inline void resetDigitalPins() {
      myController.resetDigitalPins();
    }
    inline void resetAnalogPins() {
      myController.resetAnalogPins();
    }
    inline Controller& controller() const { return myController; }

  protected:
    Controller& myController;

  private:
    // Following constructors and assignment operators not supported
    ControllerLowLevel() = delete;
    ControllerLowLevel(const ControllerLowLevel&) = delete;
    ControllerLowLevel(ControllerLowLevel&&) = delete;
    ControllerLowLevel& operator=(const ControllerLowLevel&) = delete;
    ControllerLowLevel& operator=(ControllerLowLevel&&) = delete;
};

#endif
