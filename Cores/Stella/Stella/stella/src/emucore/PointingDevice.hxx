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

#ifndef POINTING_DEVICE_HXX
#define POINTING_DEVICE_HXX

class Event;

#include "Control.hxx"
#include "bspf.hxx"

/**
  Common controller class for pointing devices (Atari Mouse, Amiga Mouse, Trak-Ball)
  This code was heavily borrowed from z26.

  @author  Stephen Anthony, Thomas Jentzsch & z26 team
*/
class PointingDevice : public Controller
{
  friend class PointingDeviceWidget;

  public:
    PointingDevice(Jack jack, const Event& event,
                   const System& system, Controller::Type type,
                   float sensitivity);
    ~PointingDevice() override = default;

  public:
    static constexpr int MIN_SENSE = 1;
    static constexpr int MAX_SENSE = 20;

  public:
    using Controller::read;

    /**
      Read the entire state of all digital pins for this controller.
      Note that this method must use the lower 4 bits, and zero the upper bits.

      @return The state of all digital pins
    */
    uInt8 read() override;

    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

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
      Sets the sensitivity for analog emulation of trackball movement
      using a mouse.

      @param sensitivity  Value from 1 to 20, with larger values causing
                          more movement (10 represents the baseline)
    */
    static void setSensitivity(int sensitivity);

  protected:
    // Each derived class must implement this, to determine how its
    // IOPortA values are calculated
    virtual uInt8 ioPortA(uInt8 countH, uInt8 countV, uInt8 left, uInt8 down) = 0;

  private:
    void updateDirection(int counter, float& counterRemainder,
                         bool& trackBallDir, int& trackBallLines,
                         int& scanCount, int& firstScanOffset);

  private:
    // Mouse input to sensitivity emulation
    float mySensitivity{0.F}, myHCounterRemainder{0.F}, myVCounterRemainder{0.F};

    // How many lines to wait between sending new horz and vert values
    int myTrackBallLinesH{1}, myTrackBallLinesV{1};

    // Was TrackBall moved left or moved right instead
    bool myTrackBallLeft{false};

    // Was TrackBall moved down or moved up instead
    bool myTrackBallDown{false};

    // Counter to iterate through the gray codes
    uInt8 myCountH{0}, myCountV{0};

    // Next scanline for change
    int myScanCountH{0}, myScanCountV{0};

    // Offset factor for first scanline, 0..(1 << 12 - 1)
    int myFirstScanOffsetH{0}, myFirstScanOffsetV{0};

    // Whether to use the mouse to emulate this controller
    bool myMouseEnabled{false};

    // User-defined sensitivity; adjustable since end-users may have different
    // mouse speeds
    static float TB_SENSITIVITY;

private:
    // Following constructors and assignment operators not supported
    PointingDevice() = delete;
    PointingDevice(const PointingDevice&) = delete;
    PointingDevice(PointingDevice&&) = delete;
    PointingDevice& operator=(const PointingDevice&) = delete;
    PointingDevice& operator=(PointingDevice&&) = delete;
};

#endif // POINTING_DEVICE_HXX
