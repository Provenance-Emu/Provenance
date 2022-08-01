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

#ifndef AMIGAMOUSE_HXX
#define AMIGAMOUSE_HXX

#include "PointingDevice.hxx"

class AmigaMouse : public PointingDevice
{
  public:
    /**
      Create a new Amiga Mouse controller plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller
    */
    AmigaMouse(Jack jack, const Event& event, const System& system)
      : PointingDevice(jack, event, system, Controller::Type::AmigaMouse,
        trackballSensitivity) { }
    ~AmigaMouse() override = default;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Amiga mouse"; }

  protected:
    uInt8 ioPortA(uInt8 countH, uInt8 countV, uInt8, uInt8) override
    {
      static constexpr std::array<uInt32, 4> ourTableH = {
        0b0000, 0b1000, 0b1010, 0b0010
      };
      static constexpr std::array<uInt32, 4> ourTableV = {
        0b0000, 0b0100, 0b0101, 0b0001
      };

      return ourTableH[countH] | ourTableV[countV];
    }

    static constexpr float trackballSensitivity = 0.8F;

  private:
    // Following constructors and assignment operators not supported
    AmigaMouse(const AmigaMouse&) = delete;
    AmigaMouse(AmigaMouse&&) = delete;
    AmigaMouse& operator=(const AmigaMouse&) = delete;
    AmigaMouse& operator=(AmigaMouse&&) = delete;
};

#endif // AMIGAMOUSE_HXX
