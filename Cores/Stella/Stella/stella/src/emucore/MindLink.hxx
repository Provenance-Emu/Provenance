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

#ifndef MINDLINK_HXX
#define MINDLINK_HXX

#include "bspf.hxx"
#include "Control.hxx"

/**
  The Atari Mindlink was an unreleased video game controller intended for
  release in 1984.  The Mindlink was unique in that one had to move the
  muscles in one's head to control the game. These movements would be read by
  infrared sensors and transferred as movement in the game.  For more
  information, see the following link:

    http://www.atarimuseum.com/videogames/consoles/2600/mindlink.html

  This code was heavily borrowed from z26, and uses conventions defined
  there.  Specifically, IOPortA is treated as a complete uInt8, whereas
  the Stella core actually stores this information in boolean arrays
  addressable by DigitalPin number.

  @author  Stephen Anthony, Thomas Jentzsch & z26 team
*/
class MindLink : public Controller
{
  public:
    /**
      Create a new MindLink controller plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller
    */
    MindLink(Jack jack, const Event& event, const System& system);
    ~MindLink() override = default;

  public:
    /**
      Write the given value to the specified digital pin for this
      controller.  Writing is only allowed to the pins associated
      with the PIA.  Therefore you cannot write to pin six.

      @param pin The pin of the controller jack to write to
      @param value The value to write to the pin
    */
    void write(DigitalPin pin, bool value) override { setPin(pin, value); }

    /**
      Called after *all* digital pins have been written on Port A.
    */
    void controlWrite(uInt8) override { nextMindlinkBit(); }

    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "MindLink"; }

    /**
      Answers whether the controller is intrinsically an analog controller.
    */
    bool isAnalog() const override { return true; }

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

  private:
    void nextMindlinkBit();

    // Range of valid values:
    // Telepathy:           >= 0x6500 for trigger
    // Bionic Breakthrough:
    //   06-22-84: >= 0x6100 & < 0x0c00 trigger calibration)
    //   other:  : >= 0x4e00 triggers calibration
    static constexpr int MIN_POS = 0x0b00;
    static constexpr int MAX_POS = 0x6500;
    static constexpr int TRIGGER_VALUE = 0x8000; // mouse button support

  private:
    // Position value in Mindlink controller
    // Gets transferred bitwise (16 bits)
    int myMindlinkPos{0x2a00};

    // Which bit to transfer next
    int myMindlinkShift{1};

    // Whether to use the mouse to emulate this controller
    int myMouseEnabled{false};

  private:
    // Following constructors and assignment operators not supported
    MindLink() = delete;
    MindLink(const MindLink&) = delete;
    MindLink(MindLink&&) = delete;
    MindLink& operator=(const MindLink&) = delete;
    MindLink& operator=(MindLink&&) = delete;
};

#endif
