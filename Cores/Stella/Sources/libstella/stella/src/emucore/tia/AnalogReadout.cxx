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

#include <cmath>

#include "AnalogReadout.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AnalogReadout::AnalogReadout()
{
  setConsoleTiming(ConsoleTiming::ntsc);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AnalogReadout::reset(uInt64 timestamp)
{
  myU = 0;
  myIsDumped = false;

  myConnection = disconnect();
  myTimestamp = timestamp;

  setConsoleTiming(ConsoleTiming::ntsc);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AnalogReadout::vblank(uInt8 value, uInt64 timestamp)
{
  updateCharge(timestamp);

  const bool oldIsDumped = myIsDumped;

  if (value & 0x80) {
    myIsDumped = true;
  } else if (oldIsDumped) {
    myIsDumped = false;
  }

  myTimestamp = timestamp;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 AnalogReadout::inpt(uInt64 timestamp)
{
  updateCharge(timestamp);

  const bool state = myIsDumped ? false : myU > myUThresh;

  return state ? 0x80 : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AnalogReadout::update(Connection connection, uInt64 timestamp,
                           ConsoleTiming consoleTiming)
{
  if (consoleTiming != myConsoleTiming) {
    setConsoleTiming(consoleTiming);
  }

  if (connection != myConnection) {
    updateCharge(timestamp);

    myConnection = connection;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AnalogReadout::setConsoleTiming(ConsoleTiming consoleTiming)
{
  myConsoleTiming = consoleTiming;

  myClockFreq = myConsoleTiming == ConsoleTiming::ntsc ? 60 * 228 * 262 : 50 * 228 * 312;
  myUThresh = U_SUPP * (1. - exp(-TRIPPOINT_LINES * 228 / myClockFreq  / (R_POT + R0) / C));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AnalogReadout::updateCharge(uInt64 timestamp)
{
  if (myIsDumped) {
    myU *= exp(-static_cast<double>(timestamp - myTimestamp) / R_DUMP / C / myClockFreq);
  } else {
    switch (myConnection.type) {
      case ConnectionType::vcc:
        myU = U_SUPP * (1 - (1 - myU / U_SUPP) *
          exp(-static_cast<double>(timestamp - myTimestamp) / (myConnection.resistance + R0) / C / myClockFreq));

        break;

      case ConnectionType::ground:
        myU *= exp(-static_cast<double>(timestamp - myTimestamp) / (myConnection.resistance + R0) / C / myClockFreq);

        break;

      case ConnectionType::disconnected:
        break;

      default:
        throw runtime_error("unreachable");
    }
  }

  myTimestamp = timestamp;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AnalogReadout::save(Serializer& out) const
{
  try
  {
    out.putDouble(myUThresh);
    out.putDouble(myU);

    myConnection.save(out);
    out.putLong(myTimestamp);

    out.putInt(static_cast<int>(myConsoleTiming));
    out.putDouble(myClockFreq);

    out.putBool(myIsDumped);
  }
  catch(...)
  {
    cerr << "ERROR: TIA_AnalogReadout::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AnalogReadout::load(Serializer& in)
{
  try
  {
    myUThresh = in.getDouble();
    myU = in.getDouble();

    myConnection.load(in);
    myTimestamp = in.getLong();

    myConsoleTiming = static_cast<ConsoleTiming>(in.getInt());
    myClockFreq = in.getDouble();

    myIsDumped = in.getBool();
  }
  catch(...)
  {
    cerr << "ERROR: TIA_AnalogReadout::load\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AnalogReadout::Connection::save(Serializer& out) const
{
  try
  {
    out.putInt(static_cast<uInt8>(type));
    out.putInt(resistance);
  }
  catch(...)
  {
    cerr << "ERROR: AnalogReadout::Connection::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AnalogReadout::Connection::load(const Serializer& in)
{
  try
  {
    type = static_cast<ConnectionType>(in.getInt());
    resistance = in.getInt();
  }
  catch(...)
  {
    cerr << "ERROR: AnalogReadout::Connection::load\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool operator==(const AnalogReadout::Connection& c1,
                const AnalogReadout::Connection& c2)
{
  if (c1.type == AnalogReadout::ConnectionType::disconnected)
    return c2.type == AnalogReadout::ConnectionType::disconnected;

  return c1.type == c2.type && c1.resistance == c2.resistance;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool operator!=(const AnalogReadout::Connection& c1,
                const AnalogReadout::Connection& c2)
{
  return !(c1 == c2);
}
