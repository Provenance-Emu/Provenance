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

#ifndef KEYBOARD_HXX
#define KEYBOARD_HXX

#include "bspf.hxx"
#include "Event.hxx"
#include "Control.hxx"

/**
  The standard Atari 2600 keyboard controller

  @author  Bradford W. Mott
*/
class Keyboard : public Controller
{
  public:
    /**
      Create a new keyboard controller plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller
    */
    Keyboard(Jack jack, const Event& event, const System& system);
    ~Keyboard() override = default;

  public:
    /**
      Write the given value to the specified digital pin for this
      controller.  Writing is only allowed to the pins associated
      with the PIA.  Therefore you cannot write to pin six.

      @param pin The pin of the controller jack to write to
      @param value The value to write to the pin
    */
    void write(DigitalPin pin, bool value) override;

    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override { }

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Keyboard"; }

  private:
    enum class ColumnState {
      vcc, gnd, notConnected
    };

  private:
    ColumnState processColumn(const Event::Type buttons[]);

    static AnalogReadout::Connection columnStateToAnalogSignal(ColumnState state);

  private:
    // Pre-compute the events we care about based on given port
    // This will eliminate test for left or right port in update()
    Event::Type myOneEvent, myTwoEvent, myThreeEvent,
                myFourEvent, myFiveEvent, mySixEvent,
                mySevenEvent, myEightEvent, myNineEvent,
                myStarEvent, myZeroEvent, myPoundEvent;

    static constexpr Int32 INTERNAL_RESISTANCE = 4700;

  private:
    // Following constructors and assignment operators not supported
    Keyboard() = delete;
    Keyboard(const Keyboard&) = delete;
    Keyboard(Keyboard&&) = delete;
    Keyboard& operator=(const Keyboard&) = delete;
    Keyboard& operator=(Keyboard&&) = delete;
};

#endif
