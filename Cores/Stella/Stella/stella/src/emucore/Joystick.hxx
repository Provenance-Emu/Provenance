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

#ifndef JOYSTICK_HXX
#define JOYSTICK_HXX

#include "Control.hxx"
#include "Event.hxx"

/**
  The standard Atari 2600 joystick controller.

  @author  Bradford W. Mott
*/
class Joystick : public Controller
{
  public:
    /**
      Create a new joystick controller plugged into the specified jack

      @param jack    The jack the controller is plugged into
      @param event   The event object to use for events
      @param system  The system using this controller
      @param altmap  If true, use alternative mapping
    */
    Joystick(Jack jack, const Event& event, const System& system,
             bool altmap = false);

    ~Joystick() override = default;

  protected:
    /**
      Create a new controller plugged into the specified jack

      @param jack    The jack the controller is plugged into
      @param event   The event object to use for events
      @param system  The system using this controller
      @param type    The controller type
    */
    Joystick(Jack jack, const Event& event, const System& system,
             Controller::Type type, bool altmap = false);

  public:
    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Joystick"; }

    /**
      Determines how this controller will treat values received from the
      X/Y axis and left/right buttons of the mouse.  Since not all controllers
      use the mouse the same way (or at all), it's up to the specific class to
      decide how to use this data.

      In the current implementation, the left button is tied to the X axis,
      and the right one tied to the Y axis.

      @param xtype  The controller to use for x-axis data
      @param xid    The controller ID to use for x-axis data (-1 for no id)
      @param ytype  The controller to use for y-axis data
      @param yid    The controller ID to use for y-axis data (-1 for no id)

      @return  Whether the controller supports using the mouse
    */
    bool setMouseControl(
      Controller::Type xtype, int xid, Controller::Type ytype, int yid) override;

  protected:
    /**
      Update the button pin states.
    */
    virtual void updateButtons();

    /**
      Update the button states from the mouse button events currently set.
    */
    void updateMouseButtons(bool& pressedLeft, bool& pressedRight);

  protected:
    Event::Type myFireEvent;

  private:
    // Pre-compute the events we care about based on given port
    // This will eliminate test for left or right port in update()
    Event::Type myUpEvent, myDownEvent, myLeftEvent, myRightEvent;

    // Controller to emulate in normal mouse axis mode
    int myControlID{-1};

  private:
    /**
      Update the axes pin states according to the keyboard
      or joystick hats & buttons events currently set.
    */
    void updateDigitalAxes();

    /**
      Update the axes pin states according to mouse events currently set.
    */
    void updateMouseAxes();

  private:
    // Following constructors and assignment operators not supported
    Joystick() = delete;
    Joystick(const Joystick&) = delete;
    Joystick(Joystick&&) = delete;
    Joystick& operator=(const Joystick&) = delete;
    Joystick& operator=(Joystick&&) = delete;
};

#endif
