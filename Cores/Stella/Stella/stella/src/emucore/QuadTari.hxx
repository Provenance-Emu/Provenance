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

#ifndef QUADTARI_HXX
#define QUADTARI_HXX

class Controller;
class Event;

/**
  The QuadTari controller.

  Supported controllers:
  - Joystick
  - Driving
  - Paddles (buttons only)
  - AtariVox
  - SaveKey

  @author  Thomas Jentzsch
*/
class QuadTari : public Controller
{
  friend class QuadTariWidget;
  public:
    /**
      Create a QuadTari controller plugged into the specified jack

      @param jack       The jack the controller is plugged into
      @param osystem    The OSystem object to use
      @param system     The system using this controller
      @param properties The properties to use for the current ROM
    */
    QuadTari(Jack jack, const OSystem& osystem, const System& system, const Properties& properties);
    ~QuadTari() override = default;

  public:
     using Controller::read;

    /**
      Read the value of the specified digital pin for this controller.

      @param pin The pin of the controller jack to read
      @return The state of the pin
    */
    bool read(DigitalPin pin) override;

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
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override;

    /**
      Returns the first attached controller.
    */
    const Controller& firstController() const { return *myFirstController; }

    /**
      Returns the second attached controller.
    */
    const Controller& secondController() const { return *mySecondController; }

    /**
      Answers whether the controller is intrinsically an analog controller.
      Depends on the attached controllers.
    */
    bool isAnalog() const override;

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
    // determine which controller is active
    bool isFirst() const;

    unique_ptr<Controller> addController(const Controller::Type type, bool second);

    const OSystem& myOSystem;
    const Properties& myProperties;
    unique_ptr<Controller> myFirstController;
    unique_ptr<Controller> mySecondController;

  private:
    // Following constructors and assignment operators not supported
    QuadTari() = delete;
    QuadTari(const QuadTari&) = delete;
    QuadTari(QuadTari&&) = delete;
    QuadTari& operator=(const QuadTari&) = delete;
    QuadTari& operator=(QuadTari&&) = delete;
  };

#endif
