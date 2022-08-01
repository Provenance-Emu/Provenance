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

#ifndef TIA_ANALOG_READOUT
#define TIA_ANALOG_READOUT

#include "bspf.hxx"
#include "Serializable.hxx"
#include "ConsoleTiming.hxx"

class AnalogReadout : public Serializable
{
  public:

    enum class ConnectionType : uInt8 {
      ground = 0, vcc = 1, disconnected = 2
    };

    struct Connection {
      ConnectionType type{ConnectionType::ground};
      uInt32 resistance{0};

      bool save(Serializer& out) const;
      bool load(const Serializer& in);

      friend bool operator==(const AnalogReadout::Connection& c1, const AnalogReadout::Connection& c2);
    };

  public:

    AnalogReadout();

    void reset(uInt64 timestamp);

    void vblank(uInt8 value, uInt64 timestamp);
    bool vblankDumped() const { return myIsDumped; }

    uInt8 inpt(uInt64 timestamp);

    void update(Connection connection, uInt64 timestamp, ConsoleTiming consoleTiming);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

  public:

    static constexpr Connection connectToGround(uInt32 resistance = 0) {
      return Connection{ConnectionType::ground, resistance};
    }

    static constexpr Connection connectToVcc(uInt32 resistance = 0) {
      return Connection{ConnectionType::vcc, resistance};
    }

    static constexpr Connection disconnect() {
      return Connection{ConnectionType::disconnected, 0};
    }

  private:

    void setConsoleTiming(ConsoleTiming timing);

    void updateCharge(uInt64 timestamp);

  private:

    double myUThresh{0.0};
    double myU{0.0};

    Connection myConnection{ConnectionType::disconnected, 0};
    uInt64 myTimestamp{0};

    ConsoleTiming myConsoleTiming;
    double myClockFreq{0.0};

    bool myIsDumped{false};

    static constexpr double
      R0 = 1.8e3,
      C = 68e-9,
      R_POT = 1e6,
      R_DUMP = 50,
      U_SUPP = 5;

    static constexpr double TRIPPOINT_LINES = 379;

  private:
    AnalogReadout(const AnalogReadout&) = delete;
    AnalogReadout(AnalogReadout&&) = delete;
    AnalogReadout& operator=(const AnalogReadout&) = delete;
    AnalogReadout& operator=(AnalogReadout&&) = delete;
};

bool operator==(const AnalogReadout::Connection& c1, const AnalogReadout::Connection& c2);
bool operator!=(const AnalogReadout::Connection& c1, const AnalogReadout::Connection& c2);

#endif // TIA_ANALOG_READOUT
