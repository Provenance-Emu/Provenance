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

#ifndef DRIVING_HXX
#define DRIVING_HXX

#include "Control.hxx"
#include "Event.hxx"

/**
  The standard Atari 2600 Indy 500 driving controller.

  @author  Bradford W. Mott
*/
class Driving : public Controller
{
  public:
    /**
      Create a new Indy 500 driving controller plugged into
      the specified jack

      @param jack    The jack the controller is plugged into
      @param event   The event object to use for events
      @param system  The system using this controller
      @param altmap  If true, use alternative mapping
    */
    Driving(Jack jack, const Event& event, const System& system, bool altmap = false);
    ~Driving() override = default;

  public:
    static constexpr int MIN_SENSE = 1;
    static constexpr int MAX_SENSE = 20;

  public:
    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Driving"; }

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

    /**
      Sets the sensitivity for digital emulation of driving controlle movement
      using a keyboard.

      @param sensitivity  Value from 1 to 20, with larger values causing
                          more movement (10 represents the baseline)
    */
    static void setSensitivity(int sensitivity);

  private:
    // Counter to iterate through the gray codes
    Int32 myCounter{0};

    // Higher resolution counter for analog (non-Stelladaptor) inputs
    uInt32 myCounterHires{0};

    // Index into the gray code table
    uInt32 myGrayIndex{0};

    // Y axis value from last yaxis event that was used to generate a new
    // gray code
    int myLastYaxis{0};

    // Pre-compute the events we care about based on given port
    // This will eliminate test for left or right port in update()
    Event::Type myCWEvent{}, myCCWEvent{}, myFireEvent{}, myAnalogEvent{},
                myXAxisValue{}, myYAxisValue{};

    // Controller to emulate in normal mouse axis mode
    int myControlID{-1};

    // Controllers to emulate in 'specific' mouse axis mode
    int myControlIDX{-1}, myControlIDY{-1};

    // User-defined sensitivity; adjustable since end-users may prefer different
    // speeds
    static float SENSITIVITY;

  private:
    /**
      Update the button pin states.
    */
    void updateButtons();

    /**
      Update the button states from the mouse button events currently set.
    */
    void updateMouseButtons(bool& firePressed);

    /**
      Update the axes pin states according to the keyboard
      or joystick events currently set.
    */
    void updateControllerAxes();

    /**
      Update the axes pin states according to the Stelladaptor axes value
      events currently set.
    */
    void updateStelladaptorAxes();

    /**
      Update the axes pin states according to mouse events currently set.
    */
    void updateMouseAxes();


  private:
    // Following constructors and assignment operators not supported
    Driving() = delete;
    Driving(const Driving&) = delete;
    Driving(Driving&&) = delete;
    Driving& operator=(const Driving&) = delete;
    Driving& operator=(Driving&&) = delete;
};

#endif
