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

#ifndef TRAKBALL_HXX
#define TRAKBALL_HXX

#include "PointingDevice.hxx"

class TrakBall : public PointingDevice
{
  public:
    /**
      Create a new trakball controller plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller
    */
    TrakBall(Jack jack, const Event& event, const System& system)
      : PointingDevice(jack, event, system, Controller::Type::TrakBall,
        trackballSensitivity) { }
    ~TrakBall() override = default;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Trak-Ball"; }

  protected:
    uInt8 ioPortA(uInt8 countH, uInt8 countV, uInt8 left, uInt8 down) override
    {
      static constexpr BSPF::array2D<uInt32, 2, 2> ourTableH = {{
        { 0b00, 0b01 }, { 0b10, 0b11 }
      }};
      static constexpr BSPF::array2D<uInt32, 2, 2> ourTableV = {{
        { 0b0100, 0b0000 }, { 0b1100, 0b1000 }
      }};

      return ourTableH[countH & 0b1][left] | ourTableV[countV & 0b1][down];
    }

    // 50% of Atari and Amiga mouse
    static constexpr float trackballSensitivity = 0.4F;

  private:
    // Following constructors and assignment operators not supported
    TrakBall(const TrakBall&) = delete;
    TrakBall(TrakBall&&) = delete;
    TrakBall& operator=(const TrakBall&) = delete;
    TrakBall& operator=(TrakBall&&) = delete;
};

#endif // TRAKBALL_HXX
