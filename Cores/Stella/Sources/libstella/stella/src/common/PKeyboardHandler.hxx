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

#ifndef PHYSICAL_KEYBOARD_HANDLER_HXX
#define PHYSICAL_KEYBOARD_HANDLER_HXX

#include <map>

class OSystem;
class EventHandler;

#include "bspf.hxx"
#include "Event.hxx"
#include "EventHandlerConstants.hxx"
#include "Props.hxx"
#include "KeyMap.hxx"

/**
  This class handles all physical keyboard-related operations in Stella.

  It is responsible for getting/setting events associated with keyboard
  actions.

  Essentially, this class is an extension of the EventHandler class, but
  handling only keyboard-specific functionality.

  @author  Stephen Anthony, Thomas Jentzsch
*/
class PhysicalKeyboardHandler
{
  public:

    PhysicalKeyboardHandler(OSystem& system, EventHandler& handler);

    void loadSerializedMappings(string_view serializedMappings, EventMode mode);

    void setDefaultMapping(Event::Type event, EventMode mode,
                           bool updateDefaults = false);

    /** define mappings for current controllers */
    void defineControllerMappings(const Controller::Type type,
                                  Controller::Jack port,
                                  const Properties& properties,
                                  Controller::Type qtType1 = Controller::Type::Unknown,
                                  Controller::Type qtType2 = Controller::Type::Unknown);
    /** enable mappings for emulation mode */
    void enableEmulationMappings();

    void eraseMapping(Event::Type event, EventMode mode);
    void saveMapping();

    string getMappingDesc(Event::Type event, EventMode mode) const {
      return myKeyMap.getEventMappingDesc(event, getEventMode(event, mode));
    }

    /** Bind a physical keyboard event to a virtual event/action. */
    bool addMapping(Event::Type event, EventMode mode, StellaKey key, StellaMod mod);

    /** Handle a physical keyboard event. */
    void handleEvent(StellaKey key, StellaMod mod, bool pressed, bool repeated);

    Event::Type eventForKey(EventMode mode, StellaKey key, StellaMod mod) const {
      return myKeyMap.get(mode, key, mod);
    }

    bool checkEventForKey(EventMode mode, StellaKey key, StellaMod mod) const {
      return myKeyMap.check(mode, key, mod);
    }

  #ifdef BSPF_UNIX
    /** See comments on 'myAltKeyCounter' for more information. */
    uInt8& altKeyCount() { return myAltKeyCounter; }
  #endif

    /** See comments on KeyMap.myModEnabled for more information. */
    bool& useModKeys() { return myKeyMap.enableMod(); }

    void toggleModKeys(bool toggle = true);

  private:

    // Structure used for action menu items
    struct EventMapping {
      Event::Type event{Event::NoType};
      StellaKey key{StellaKey(0)};
      int mod{KBDM_NONE};
    };
    using EventMappingArray = std::vector<EventMapping>;

    // Checks if the given mapping is used by any event mode
    bool isMappingUsed(EventMode mode, const EventMapping& map) const;

    void setDefaultKey(EventMapping map, Event::Type event = Event::NoType,
      EventMode mode = EventMode::kEmulationMode, bool updateDefaults = false);

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

    /** return event mode for given property */
    static EventMode getMode(const Properties& properties, const PropType propType);
    /** return event mode for given controller type */
    static EventMode getMode(const Controller::Type type);

#ifdef DEBUG_BUILD
    void verifyDefaultMapping(PhysicalKeyboardHandler::EventMappingArray mapping,
      EventMode mode, string_view name);
#endif

  private:
    OSystem& myOSystem;
    EventHandler& myHandler;

    // Hashmap of key events
    KeyMap myKeyMap;

    EventMode myLeftMode{EventMode::kEmulationMode};
    EventMode myRightMode{EventMode::kEmulationMode};
    // Additional modes for QuadTari controller
    EventMode myLeft2ndMode{EventMode::kEmulationMode};
    EventMode myRight2ndMode{EventMode::kEmulationMode};

  #ifdef BSPF_UNIX
    // Sometimes key combos with the Alt key become 'stuck' after the
    // window changes state, and we want to ignore that event
    // For example, press Alt-Tab and then upon re-entering the window,
    // the app receives 'tab'; obviously the 'tab' shouldn't be happening
    // So we keep track of the cases that matter (for now, Alt-Tab)
    // and swallow the event afterwards
    // Basically, the initial event sets the variable to 1, and upon
    // returning to the app (ie, receiving EVENT_WINDOW_FOCUS_GAINED),
    // the count is updated to 2, but only if it was already updated to 1
    // TODO - This may be a bug in SDL, and might be removed in the future
    //        It only seems to be an issue in Linux
    uInt8 myAltKeyCounter{0};
  #endif

    // Controller menu and common emulation mappings
    static EventMappingArray DefaultMenuMapping;
  #ifdef GUI_SUPPORT
    static EventMappingArray FixedEditMapping;
  #endif
  #ifdef DEBUGGER_SUPPORT
    static EventMappingArray FixedPromptMapping;
  #endif
    static EventMappingArray DefaultCommonMapping;
    // Controller specific mappings
    static EventMappingArray DefaultJoystickMapping;
    static EventMappingArray DefaultPaddleMapping;
    static EventMappingArray DefaultKeyboardMapping;
    static EventMappingArray DefaultDrivingMapping;
    static EventMappingArray CompuMateMapping;
};

#endif
