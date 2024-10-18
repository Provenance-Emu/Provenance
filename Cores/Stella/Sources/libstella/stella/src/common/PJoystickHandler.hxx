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

#ifndef PHYSICAL_JOYSTICK_HANDLER_HXX
#define PHYSICAL_JOYSTICK_HANDLER_HXX

#include <map>

class OSystem;
class EventHandler;
class Event;

#include "bspf.hxx"
#include "EventHandlerConstants.hxx"
#include "PhysicalJoystick.hxx"
#include "Variant.hxx"
#include "json_lib.hxx"

using PhysicalJoystickPtr = shared_ptr<PhysicalJoystick>;

/**
  This class handles all physical joystick-related operations in Stella.

  It is responsible for adding/accessing/removing PhysicalJoystick objects,
  and getting/setting events associated with joystick actions (button presses,
  axis/hat actions, etc).

  Essentially, this class is an extension of the EventHandler class, but
  handling only joystick-specific functionality.

  @author  Stephen Anthony, Thomas Jentzsch
*/
class PhysicalJoystickHandler
{
  public:
    struct MinStrickInfo
    {
      string                    name;
      int                       ID;
      PhysicalJoystick::Port    port;

      explicit MinStrickInfo(string _name, int _id, PhysicalJoystick::Port _port)
        : name{_name}, ID{_id}, port{_port} {}
    };
    using MinStrickInfoList = std::vector<MinStrickInfo>;

  private:
    struct StickInfo
    {
      // NOTE: For all future linting exercises
      //       Make sure to *NEVER* use brace initialization or std::move
      //       on the 'mapping' instance variable; there lay dragons ...
      // https://json.nlohmann.me/home/faq/#brace-initialization-yields-arrays
      explicit StickInfo(nlohmann::json map, PhysicalJoystickPtr stick = nullptr)
        : mapping(map), joy{std::move(stick)} {}

      nlohmann::json mapping;
      PhysicalJoystickPtr joy;

      friend ostream& operator<<(ostream& os, const StickInfo& si) {
        os << "  joy: " << si.joy << "\n  map: " << si.mapping;
        return os;
      }
    };

  public:
    PhysicalJoystickHandler(OSystem& system, EventHandler& handler, Event& event);

    static nlohmann::json convertLegacyMapping(string_view mapping);

    /** Return stick ID on success, -1 on failure. */
    int add(const PhysicalJoystickPtr& stick);
    bool remove(int id);
    bool remove(string_view name);
    void setPort(string_view name, PhysicalJoystick::Port port);
    bool mapStelladaptors(string_view saport, int ID = -1);
    bool hasStelladaptors() const;
    void setDefaultMapping(Event::Type event, EventMode mode);

    /** define mappings for current controllers */
    void defineControllerMappings(const Controller::Type type, Controller::Jack port,
                                  const Properties& properties,
                                  Controller::Type qtType1 = Controller::Type::Unknown,
                                  Controller::Type qtType2 = Controller::Type::Unknown);
    /** enable mappings for emulation mode */
    void enableEmulationMappings();

    void eraseMapping(Event::Type event, EventMode mode);
    void saveMapping();
    string getMappingDesc(Event::Type, EventMode mode) const;

    /** Bind a physical joystick event to a virtual event/action. */
    bool addJoyMapping(Event::Type event, EventMode mode, int stick,
                       int button, JoyAxis axis, JoyDir adir);
    bool addJoyHatMapping(Event::Type event, EventMode mode, int stick,
                          int button, int hat, JoyHatDir hdir);

    /** Handle a physical joystick event. */
    void handleAxisEvent(int stick, int axis, int value);
    void handleBtnEvent(int stick, int button, bool pressed);
    void handleHatEvent(int stick, int hat, int value);

    Event::Type eventForAxis(EventMode mode, int stick, JoyAxis axis, JoyDir adir, int button) const {
      const PhysicalJoystickPtr& j = joy(stick);
      return j->joyMap.get(mode, button, axis, adir);
    }
    Event::Type eventForButton(EventMode mode, int stick, int button) const {
      const PhysicalJoystickPtr& j = joy(stick);
      return j->joyMap.get(mode, button);
    }
    Event::Type eventForHat(EventMode mode, int stick, int hat, JoyHatDir hatDir, int button) const {
      const PhysicalJoystickPtr& j = joy(stick);
      return j->joyMap.get(mode, button, hat, hatDir);
    }

    /** Returns a list containing minimal controller info (name, ID, port). */
    MinStrickInfoList minStickList() const;

    void changeDigitalDeadZone(int direction = +1);
    void changeAnalogPaddleDeadZone(int direction = +1);
    void changeAnalogPaddleSensitivity(int direction = +1);
    void changeAnalogPaddleLinearity(int direction = +1);
    void changePaddleDejitterAveraging(int direction = +1);
    void changePaddleDejitterReaction(int direction = +1);
    void changeDigitalPaddleSensitivity(int direction = +1);
    void changeMousePaddleSensitivity(int direction = +1);
    void changeMouseTrackballSensitivity(int direction = +1);
    void changeDrivingSensitivity(int direction = +1);

  private:
    using StickDatabase = std::map<string, StickInfo, std::less<>>;
    using StickList = std::map<int, PhysicalJoystickPtr>;

    OSystem& myOSystem;
    EventHandler& myHandler;
    Event& myEvent;

    // Contains all joysticks that Stella knows about, indexed by name
    StickDatabase myDatabase;

    // Contains only joysticks that are currently available, indexed by id
    StickList mySticks;

    // Get joystick corresponding to given id (or nullptr if it doesn't exist)
    // Make this inline so it's as fast as possible
    const PhysicalJoystickPtr joy(int id) const {
      const auto& i = mySticks.find(id);
      return i != mySticks.cend() ? i->second : nullptr;
    }

    // Add stick to stick database
    void addToDatabase(const PhysicalJoystickPtr& stick);

    // Set default mapping for given joystick when no mappings already exist
    void setStickDefaultMapping(int stick, Event::Type event, EventMode mode,
                                bool updateDefaults = false);

    friend ostream& operator<<(ostream& os, const PhysicalJoystickHandler& jh);

    JoyDir convertAxisValue(int value) const {
      return value == int(JoyDir::NONE) ? JoyDir::NONE : value > 0 ? JoyDir::POS : JoyDir::NEG;
    }

    // Handle regular axis events (besides special Stelladaptor handling)
    void handleRegularAxisEvent(const PhysicalJoystickPtr& j,
                                int stick, int axis, int value);

    // Structures used for action menu items
    struct EventMapping {
      Event::Type event{Event::NoType};
      int button{0};
      JoyAxis axis{JoyAxis::NONE};
      JoyDir adir{JoyDir::NONE};
      int hat{JOY_CTRL_NONE};
      JoyHatDir hdir{JoyHatDir::CENTER};
    };
    using EventMappingArray = std::vector<EventMapping>;

    void setDefaultAction(int stick,
                          EventMapping map, Event::Type event = Event::NoType,
                          EventMode mode = EventMode::kEmulationMode,
                          bool updateDefaults = false);

    /** return event mode for given property */
    static EventMode getMode(const Properties& properties, const PropType propType);
    /** return event mode for given controller type */
    static EventMode getMode(const Controller::Type type);

    /** returns the event's controller mode */
    static EventMode getEventMode(const Event::Type event, const EventMode mode);
    /** Checks event type. */
    static bool isJoystickEvent(const Event::Type event);
    static bool isPaddleEvent(const Event::Type event);
    static bool isKeyboardEvent(const Event::Type event);
    static bool isDrivingEvent(const Event::Type event);
    static bool isCommonEvent(const Event::Type event);

    void enableCommonMappings();

    void enableMappings(const Event::EventSet& events, EventMode mode);
    void enableMapping(const Event::Type event, EventMode mode);

  private:
    EventMode myLeftMode{EventMode::kEmulationMode};
    EventMode myRightMode{EventMode::kEmulationMode};
    // Additional modes for QuadTari controller
    EventMode myLeft2ndMode{EventMode::kEmulationMode};
    EventMode myRight2ndMode{EventMode::kEmulationMode};

    // Controller menu and common emulation mappings
    static EventMappingArray DefaultMenuMapping;
    static EventMappingArray DefaultCommonMapping;
    // Controller specific mappings
    static EventMappingArray DefaultLeftJoystickMapping;
    static EventMappingArray DefaultRightJoystickMapping;
    static EventMappingArray DefaultLeftPaddlesMapping;
    static EventMappingArray DefaultRightPaddlesMapping;
    static EventMappingArray DefaultLeftAPaddlesMapping;
    static EventMappingArray DefaultLeftBPaddlesMapping;
    static EventMappingArray DefaultRightAPaddlesMapping;
    static EventMappingArray DefaultRightBPaddlesMapping;
    static EventMappingArray DefaultLeftKeyboardMapping;
    static EventMappingArray DefaultRightKeyboardMapping;
    static EventMappingArray DefaultLeftDrivingMapping;
    static EventMappingArray DefaultRightDrivingMapping;

    static constexpr int NUM_PORTS = 2;
    static constexpr int NUM_SA_AXIS = 2;
    static const Event::Type SA_Axis[NUM_PORTS][NUM_SA_AXIS];
};

#endif
