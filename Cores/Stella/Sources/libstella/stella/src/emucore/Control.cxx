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

#include "System.hxx"
#include "Control.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Controller::Controller(Jack jack, const Event& event, const System& system,
                       Type type)
  : myJack{jack},
    myEvent{event},
    mySystem{system},
    myType{type}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Controller::read()
{
  uInt8 ioport = 0b0000;
  if(read(DigitalPin::One))   ioport |= 0b0001;
  if(read(DigitalPin::Two))   ioport |= 0b0010;
  if(read(DigitalPin::Three)) ioport |= 0b0100;
  if(read(DigitalPin::Four))  ioport |= 0b1000;
  return ioport;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Controller::read(DigitalPin pin)
{
  return getPin(pin);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AnalogReadout::Connection Controller::read(AnalogPin pin)
{
  return getPin(pin);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Controller::save(Serializer& out) const
{
  try
  {
    // Output the digital pins
    out.putBool(getPin(DigitalPin::One));
    out.putBool(getPin(DigitalPin::Two));
    out.putBool(getPin(DigitalPin::Three));
    out.putBool(getPin(DigitalPin::Four));
    out.putBool(getPin(DigitalPin::Six));

    // Output the analog pins
    getPin(AnalogPin::Five).save(out);
    getPin(AnalogPin::Nine).save(out);
  }
  catch(...)
  {
    cerr << "ERROR: Controller::save() exception\n";
    return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Controller::load(Serializer& in)
{
  try
  {
    // Input the digital pins
    setPin(DigitalPin::One,   in.getBool());
    setPin(DigitalPin::Two,   in.getBool());
    setPin(DigitalPin::Three, in.getBool());
    setPin(DigitalPin::Four,  in.getBool());
    setPin(DigitalPin::Six,   in.getBool());

    // Input the analog pins
    getPin(AnalogPin::Five).load(in);
    getPin(AnalogPin::Nine).load(in);
  }
  catch(...)
  {
    cerr << "ERROR: Controller::load() exception\n";
    return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Controller::getName(const Type type)
{
  static constexpr std::array<string_view,
    static_cast<int>(Controller::Type::LastType)> NAMES =
  {
    "Unknown",
    "Amiga mouse", "Atari mouse", "AtariVox", "Booster Grip", "CompuMate",
    "Driving", "Sega Genesis", "Joystick", "Keyboard", "Kid Vid", "MindLink",
    "Paddles", "Paddles_IAxis", "Paddles_IAxDr", "SaveKey", "Trak-Ball",
    "Light Gun", "QuadTari", "Joy 2B+"
  };

  return string{NAMES[static_cast<int>(type)]};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Controller::getPropName(const Type type)
{
  static constexpr std::array<string_view,
    static_cast<int>(Controller::Type::LastType)> PROP_NAMES =
  {
    "AUTO",
    "AMIGAMOUSE", "ATARIMOUSE", "ATARIVOX", "BOOSTERGRIP", "COMPUMATE",
    "DRIVING", "GENESIS", "JOYSTICK", "KEYBOARD", "KIDVID", "MINDLINK",
    "PADDLES", "PADDLES_IAXIS", "PADDLES_IAXDR", "SAVEKEY", "TRAKBALL",
    "LIGHTGUN", "QUADTARI", "JOY_2B+"
  };

  return string{PROP_NAMES[static_cast<int>(type)]};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Controller::Type Controller::getType(string_view propName)
{
  for(int i = 0; i < static_cast<int>(Type::LastType); ++i)
    if (BSPF::equalsIgnoreCase(propName, getPropName(Type{i})))
      return Type{i};

  // special case
  if(BSPF::equalsIgnoreCase(propName, "KEYPAD"))
    return Type::Keyboard;

  return Type::Unknown;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Controller::setDigitalDeadZone(int deadZone)
{
  DIGITAL_DEAD_ZONE = digitalDeadZoneValue(deadZone);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Controller::digitalDeadZoneValue(int deadZone)
{
  deadZone = BSPF::clamp(deadZone, MIN_DIGITAL_DEADZONE, MAX_DIGITAL_DEADZONE);

  return 3200 + deadZone * 1000;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Controller::setAnalogDeadZone(int deadZone)
{
  ANALOG_DEAD_ZONE = analogDeadZoneValue(deadZone);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Controller::analogDeadZoneValue(int deadZone)
{
  deadZone = BSPF::clamp(deadZone, MIN_ANALOG_DEADZONE, MAX_ANALOG_DEADZONE);

  return deadZone * std::round(32768 / 2. / MAX_DIGITAL_DEADZONE);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Controller::setMouseSensitivity(int sensitivity)
{
  MOUSE_SENSITIVITY = BSPF::clamp(sensitivity, MIN_MOUSE_SENSE, MAX_MOUSE_SENSE);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Controller::setAutoFire(bool enable)
{
  AUTO_FIRE = enable;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Controller::setAutoFireRate(int rate, bool isNTSC)
{
  rate = BSPF::clamp(rate, 0, isNTSC ? 30 : 25);
  AUTO_FIRE_RATE = 32 * 1024 * rate / (isNTSC ? 60 : 50);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Controller::DIGITAL_DEAD_ZONE = 3200;
int Controller::ANALOG_DEAD_ZONE = 0;
int Controller::MOUSE_SENSITIVITY = -1;
bool Controller::AUTO_FIRE = false;
int Controller::AUTO_FIRE_RATE = 0;
