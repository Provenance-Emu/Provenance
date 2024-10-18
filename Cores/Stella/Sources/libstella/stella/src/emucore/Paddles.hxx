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

#ifndef PADDLES_HXX
#define PADDLES_HXX

#include "bspf.hxx"
#include "Control.hxx"
#include "Event.hxx"

/**
  The standard Atari 2600 pair of paddle controllers.

  @author  Bradford W. Mott
*/
class Paddles : public Controller
{
  public:
    /**
      Create a new pair of paddle controllers plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller

      @param swappaddle Whether to swap the paddles plugged into this jack
      @param swapaxis   Whether to swap the axis on the paddle (x <-> y)
      @param swapdir    Whether to swap the direction for which an axis
                        causes movement (lesser axis values cause paddle
                        resistance to decrease instead of increase)
    */
    Paddles(Jack jack, const Event& event, const System& system,
            bool swappaddle, bool swapaxis, bool swapdir, bool altmap = false);
    ~Paddles() override = default;

  public:
    static constexpr int ANALOG_MIN_VALUE = -32768;
    static constexpr int ANALOG_MAX_VALUE = 32767;
    static constexpr int ANALOG_RANGE = ANALOG_MAX_VALUE - ANALOG_MIN_VALUE + 1;
    static constexpr float BASE_ANALOG_SENSE = 0.148643628F;
    static constexpr int MIN_ANALOG_SENSE = 0;
    static constexpr int MAX_ANALOG_SENSE = 30;
    static constexpr int MIN_ANALOG_LINEARITY = 25;
    static constexpr int MAX_ANALOG_LINEARITY = 100;
    static constexpr int MIN_ANALOG_CENTER = -10;
    static constexpr int MAX_ANALOG_CENTER = 30;
    static constexpr int MIN_DIGITAL_SENSE = 1;
    static constexpr int MAX_DIGITAL_SENSE = 20;
    static constexpr int MIN_DEJITTER = 0;
    static constexpr int MAX_DEJITTER = 10;
    static constexpr int MIN_MOUSE_RANGE = 1;
    static constexpr int MAX_MOUSE_RANGE = 100;

    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Paddles"; }

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
    bool setMouseControl(Controller::Type xtype, int xid,
                         Controller::Type ytype, int yid) override;

    /**
      Sets the x-center for analog paddles.

      @param xcenter  Value from -10 to 30, representing the center offset/860
    */
    static void setAnalogXCenter(int xcenter);

    /**
      Sets the y-center for analog paddles.

      @param ycenter  Value from -10 to 30, representing the center offset/860
    */
    static void setAnalogYCenter(int ycenter);

    /**
      Sets the linearity of analog paddles.

      @param linearity Value from 25 to 100
    */
    static void setAnalogLinearity(int linearity);

    /**
      Sets the sensitivity for analog paddles.

      @param sensitivity  Value from 0 to 30, where 20 equals 1
      @return  Resulting sensitivity
    */
    static float setAnalogSensitivity(int sensitivity);

    static float analogSensitivityValue(int sensitivity);


    /**
      @param strength  Value from 0 to 10
    */
    static void setDejitterBase(int strength);

    /**
      @param strength  Value from 0 to 10
    */
    static void setDejitterDiff(int strength);

    /**
      Sets the sensitivity for digital emulation of paddle movement.
      This is only used for *digital* events (ie, buttons or keys,
      or digital joystick axis events); Stelladaptors or the mouse are
      not modified.

      @param sensitivity  Value from 1 to MAX_DIGITAL_SENSE, with larger
                          values causing more movement
    */
    static void setDigitalSensitivity(int sensitivity);

    /**
      Sets the maximum upper range for digital/mouse emulation of paddle
      movement (ie, a value of 50 means to only use 50% of the possible
      range of movement).  Note that this specfically does not apply to
      Stelladaptor-like devices, which uses an absolute value range.

      @param range  Value from 1 to 100, representing the percentage
                    of the range to use
    */
    static void setDigitalPaddleRange(int range);

    // The maximum value of the paddle pot = 1MOhm
    static constexpr uInt32 MAX_RESISTANCE = 1000000;

  private:
    // Range of values over which digital and mouse movement is scaled
    // to paddle resistance
    static constexpr int TRIGMIN = 1;
    static constexpr int TRIGMAX = 4096;
    static int TRIGRANGE;  // This one is variable for the upper range

    // Pre-compute the events we care about based on given port
    // This will eliminate test for left or right port in update()
    Event::Type myAAxisValue, myBAxisValue,
                myLeftADecEvent, myLeftAIncEvent,
                myLeftBDecEvent, myLeftBIncEvent,
                myLeftAFireEvent, myLeftBFireEvent,
                myAxisMouseMotion;

    // The following are used for the various mouse-axis modes
    int myMPaddleID{-1};                    // paddle to emulate in 'automatic' mode
    int myMPaddleIDX{-1}, myMPaddleIDY{-1}; // paddles to emulate in 'specific axis' mode

    bool myKeyRepeatA{false}, myKeyRepeatB{false};
    int myPaddleRepeatA{0}, myPaddleRepeatB{0};
    std::array<int, 2> myCharge{TRIGRANGE/2, TRIGRANGE/2}, myLastCharge{0};
    int myLastAxisX{0}, myLastAxisY{0};
    int myAxisDigitalZero{0}, myAxisDigitalOne{0};

    static int XCENTER;
    static int YCENTER;
    static float SENSITIVITY, LINEARITY;

    static int DIGITAL_SENSITIVITY, DIGITAL_DISTANCE;
    static int DEJITTER_BASE, DEJITTER_DIFF;

    static AnalogReadout::Connection getReadOut(int lastAxis,
                                                int& newAxis, int center);

    void updateA();
    void updateB();

    /**
      Update the axes pin state according to the events currently set.
    */
    bool updateAnalogAxesA();
    bool updateAnalogAxesB();

    /**
      Update the entire state according to mouse events currently set.
    */
    void updateMouseA(bool& firePressedA);
    void updateMouseB(bool& firePressedB);

    /**
      Update the axes pin state according to the keyboard events currently set.
    */
    void updateDigitalAxesA();
    void updateDigitalAxesB();

  private:
    // Following constructors and assignment operators not supported
    Paddles() = delete;
    Paddles(const Paddles&) = delete;
    Paddles(Paddles&&) = delete;
    Paddles& operator=(const Paddles&) = delete;
    Paddles& operator=(Paddles&&) = delete;
};

#endif
