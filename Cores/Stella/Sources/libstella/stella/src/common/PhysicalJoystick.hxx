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

#ifndef PHYSICAL_JOYSTICK_HXX
#define PHYSICAL_JOYSTICK_HXX

#include "Event.hxx"
#include "EventHandlerConstants.hxx"
#include "JoyMap.hxx"
#include "json_lib.hxx"

/**
  An abstraction of a physical (real) joystick in Stella.

  A PhysicalJoystick holds its own event mapping information, space for
  which is dynamically allocated based on the actual number of buttons,
  axes, etc that the device contains.

  Specific backend class(es) will inherit from this class, and implement
  functionality specific to the device.

  @author  Stephen Anthony, Thomas Jentzsch
*/

class PhysicalJoystick
{
  friend class PhysicalJoystickHandler;

  static constexpr char MODE_DELIM = '>'; // must not be '^', '|' or '#'

  public:
    enum class Port {
      AUTO,
      LEFT,
      RIGHT,
      NUM_PORTS
    };

    PhysicalJoystick() = default;

    nlohmann::json getMap() const;
    bool setMap(const nlohmann::json& map);
    void setPort(const Port _port) { port = _port; }

    static nlohmann::json convertLegacyMapping(string_view mapping,
                                               string_view name);

    void eraseMap(EventMode mode);
    void eraseEvent(Event::Type event, EventMode mode);
    string about() const;

  protected:
    void initialize(int index, string_view desc,
                    int axes, int buttons, int hats, int balls);

  private:
    enum class Type {
      REGULAR,
      LEFT_STELLADAPTOR, RIGHT_STELLADAPTOR,
      LEFT_2600DAPTOR, RIGHT_2600DAPTOR
    };

    Type type{Type::REGULAR};
    int ID{-1};
    string name{"None"};
    Port port{Port::AUTO};
    int numAxes{0}, numButtons{0}, numHats{0};
    IntArray axisLastValue;
    IntArray buttonLast;

    // Hashmaps of controller events
    JoyMap joyMap;

  private:
    // Convert from string to Port type and vice versa
    static string getName(const Port _port) {
      static constexpr std::array<string_view,
      static_cast<int>(PhysicalJoystick::Port::NUM_PORTS)> NAMES = {
        "Auto", "Left", "Right"
      };

      return string{NAMES[static_cast<int>(_port)]};
    }

    static Port getPort(string_view portName) {
      static constexpr std::array<string_view,
      static_cast<int>(PhysicalJoystick::Port::NUM_PORTS)> NAMES = {
        "Auto", "Left", "Right"
      };

      for(int i = 0; i < static_cast<int>(PhysicalJoystick::Port::NUM_PORTS); ++i)
        if (BSPF::equalsIgnoreCase(portName, NAMES[i]))
          return PhysicalJoystick::Port{i};

      return PhysicalJoystick::Port::AUTO;
    }

    friend ostream& operator<<(ostream& os, const PhysicalJoystick& s) {
      os << "  ID: " << s.ID << ", name: " << s.name << ", numaxis: " << s.numAxes
         << ", numbtns: " << s.numButtons << ", numhats: " << s.numHats;
      return os;
    }

    // Following constructors and assignment operators not supported
    PhysicalJoystick(const PhysicalJoystick&) = delete;
    PhysicalJoystick(PhysicalJoystick&&) = delete;
    PhysicalJoystick& operator=(const PhysicalJoystick&) = delete;
    PhysicalJoystick& operator=(PhysicalJoystick&&) = delete;
};

#endif
