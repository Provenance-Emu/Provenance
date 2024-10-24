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

#ifndef EVENTHANDLER_HXX
#define EVENTHANDLER_HXX

#include <map>

class Console;
class OSystem;
class MouseControl;
class DialogContainer;
class PhysicalJoystick;
class Variant;
class GlobalKeyHandler;

namespace GUI {
  class Font;
}

#include "Event.hxx"
#include "EventHandlerConstants.hxx"
#include "Control.hxx"
#include "PKeyboardHandler.hxx"
#include "PJoystickHandler.hxx"
#include "bspf.hxx"

/**
  This class takes care of event remapping and dispatching for the
  Stella core, as well as keeping track of the current 'mode'.

  The frontend will send translated events here, and the handler will
  check to see what the current 'mode' is.

  If in emulation mode, events received from the frontend are remapped and
  sent to the emulation core.  If in menu mode, the events are sent
  unchanged to the menu class, where (among other things) changing key
  mapping can take place.

  @author  Stephen Anthony, Thomas Jentzsch
*/
class EventHandler
{
  public:
    /**
      Create a new event handler object
    */
    EventHandler(OSystem& osystem);
    virtual ~EventHandler();

    /**
      Returns the event object associated with this handler class.

      @return The event object
    */
    const Event& event() const { return myEvent; }

    /**
      Initialize state of this eventhandler.
    */
    void initialize();

    /**
      Maps the given Stelladaptor/2600-daptor(s) to specified ports on a real 2600.

      @param saport  How to map the ports ('lr' or 'rl')
    */
    void mapStelladaptors(string_view saport);

    /**
      Toggles if all four joystick directions are allowed at once
    */
    void toggleAllow4JoyDirections(bool toggle = true);

    /**
      Swaps the ordering of Stelladaptor/2600-daptor(s) devices.
    */
    void toggleSAPortOrder(bool toggle = true);

    /**
      Toggle whether the console is in 2600 or 7800 mode.
      Note that for now, this only affects whether the 7800 pause button is
      supported; there is no further emulation of the 7800 itself.
    */
    void set7800Mode();

    /**
      Toggle between UI theme #1 and #2.
    */
    void toggleUIPalette();

    /**
      Collects and dispatches any pending events.  This method should be
      called regularly (at X times per second, where X is the game framerate).

      @param time  The current time in microseconds.
    */
    void poll(uInt64 time);

    /**
      Get/set the current state of the EventHandler.

      @return The EventHandlerState type
    */
    EventHandlerState state() const { return myState; }
    void setState(EventHandlerState state);

    /**
      Convenience method that checks if we're in TIA mode.

      @return Whether TIA mode is active
    */
    bool inTIAMode() const {
      return !(myState == EventHandlerState::DEBUGGER ||
               myState == EventHandlerState::LAUNCHER ||
               myState == EventHandlerState::NONE);
    }

    /**
      Resets the state machine of the EventHandler to the defaults.

      @param state  The current state to set
    */
    void reset(EventHandlerState state);

    /**
      This method indicates that the system should terminate.
    */
    void quit() { handleEvent(Event::Quit); }

    /**
      Sets the mouse axes and buttons to act as the controller specified in
      the ROM properties, otherwise disable mouse control completely

      @param enable  Whether to use the mouse to emulate controllers
                     Currently, this will be one of the following values:
                     'always', 'analog', 'never'
    */
    void setMouseControllerMode(string_view enable);
    void changeMouseControllerMode(int direction = +1);
    void changeMouseCursor(int direction = +1);

    void enterMenuMode(EventHandlerState state);
    void leaveMenuMode();
    bool enterDebugMode();
    void leaveDebugMode();
    void enterTimeMachineMenuMode(uInt32 numWinds, bool unwind);
    void enterPlayBackMode();

    /**
      Send an event directly to the event handler.
      These events cannot be remapped.

      @param event     The event
      @param value     The value to use for the event
      @param repeated  Repeated key (true) or first press/release (false)
    */
    void handleEvent(Event::Type event, Int32 value = 1, bool repeated = false);

    /**
      Handle events that must be processed each time a new console is
      created.  Typically, these are events set by commandline arguments.
    */
    void handleConsoleStartupEvents();

    bool frying() const { return myFryingFlag; }

    static StringList getActionList(Event::Group group);
    static VariantList getComboList();

    /** Used to access the list of events assigned to a specific combo event. */
    StringList getComboListForEvent(Event::Type event) const;
    void setComboListForEvent(Event::Type event, const StringList& events);

    /** Provide the joystick handler for the global hotkey handler */
    PhysicalJoystickHandler& joyHandler() const { return *myPJoyHandler; }
    /** Provide the keyboard handler for the global hotkey handler */
    PhysicalKeyboardHandler& keyHandler() const { return *myPKeyHandler; }

    /** Convert keys and physical joystick events into Stella events. */
    Event::Type eventForKey(EventMode mode, StellaKey key, StellaMod mod) const {
      return myPKeyHandler->eventForKey(mode, key, mod);
    }
    bool checkEventForKey(EventMode mode, StellaKey key, StellaMod mod) const {
      return myPKeyHandler->checkEventForKey(mode, key, mod);
    }
    Event::Type eventForJoyAxis(EventMode mode, int stick, JoyAxis axis, JoyDir adir, int button) const {
      return myPJoyHandler->eventForAxis(mode, stick, axis, adir, button);
    }
    Event::Type eventForJoyButton(EventMode mode, int stick, int button) const {
      return myPJoyHandler->eventForButton(mode, stick, button);
    }
    Event::Type eventForJoyHat(EventMode mode, int stick, int hat, JoyHatDir hdir, int button) const {
      return myPJoyHandler->eventForHat(mode, stick, hat, hdir, button);
    }

    /** Get description of given event and mode. */
    string getMappingDesc(Event::Type event, EventMode mode) const {
      return myPKeyHandler->getMappingDesc(event, mode);
    }

    static Event::Type eventAtIndex(int idx, Event::Group group);
    static string actionAtIndex(int idx, Event::Group group);
    static string keyAtIndex(int idx, Event::Group group);

    /**
      Bind a key to an event/action and regenerate the mapping array(s).

      @param event  The event we are remapping
      @param mode   The mode where this event is active
      @param key    The key to bind to this event
      @param mod    The modifier to bind to this event
    */
    bool addKeyMapping(Event::Type event, EventMode mode, StellaKey key, StellaMod mod);

    /**
      Enable controller specific keyboard event mappings.
    */
    void defineKeyControllerMappings(const Controller::Type type, Controller::Jack port,
                                     const Properties& properties,
                                     Controller::Type qtType1 = Controller::Type::Unknown,
                                     Controller::Type qtType2 = Controller::Type::Unknown) {
      myPKeyHandler->defineControllerMappings(type, port, properties, qtType1, qtType2);
    }

    /**
      Enable emulation keyboard event mappings.
    */
    void enableEmulationKeyMappings() {
      myPKeyHandler->enableEmulationMappings();
    }

    /**
      Bind a physical joystick axis direction to an event/action and regenerate
      the mapping array(s). The axis can be combined with a button. The button
      can also be mapped without an axis.

      @param event  The event we are remapping
      @param mode   The mode where this event is active
      @param stick  The joystick number
      @param button The joystick button
      @param axis   The joystick axis
      @param adir   The given axis
      @param updateMenus  Whether to update the action mappings (normally
                          we want to do this, unless there are a batch of
                          'adds', in which case it's delayed until the end
    */
    bool addJoyMapping(Event::Type event, EventMode mode, int stick,
                       int button, JoyAxis axis = JoyAxis::NONE, JoyDir adir = JoyDir::NONE,
                       bool updateMenus = true);

    /**
      Bind a physical joystick hat direction to an event/action and regenerate
      the mapping array(s). The hat can be combined with a button.

      @param event  The event we are remapping
      @param mode   The mode where this event is active
      @param stick  The joystick number
      @param button The joystick button
      @param hat    The joystick hat
      @param dir    The value on the given hat
      @param updateMenus  Whether to update the action mappings (normally
                          we want to do this, unless there are a batch of
                          'adds', in which case it's delayed until the end
    */
    bool addJoyHatMapping(Event::Type event, EventMode mode, int stick,
                          int button, int hat, JoyHatDir dir,
                          bool updateMenus = true);

    /**
      Enable controller specific keyboard event mappings.
    */
    void defineJoyControllerMappings(const Controller::Type type, Controller::Jack port,
                                     const Properties& properties,
                                     Controller::Type qtType1 = Controller::Type::Unknown,
                                     Controller::Type qtType2 = Controller::Type::Unknown) {
      myPJoyHandler->defineControllerMappings(type, port, properties, qtType1, qtType2);
    }

    /**
      Enable emulation keyboard event mappings.
    */
    void enableEmulationJoyMappings() {
      myPJoyHandler->enableEmulationMappings();
    }

    /**
      Erase the specified mapping.

      @param event  The event for which we erase all mappings
      @param mode   The mode where this event is active
    */
    void eraseMapping(Event::Type event, EventMode mode);

    /**
      Resets the event mappings to default values.

      @param event  The event which to (re)set (Event::NoType resets all)
      @param mode   The mode for which the defaults are set
    */
    void setDefaultMapping(Event::Type event, EventMode mode);

    /**
      Joystick emulates 'impossible' directions (ie, left & right
      at the same time).

      @param allow  Whether or not to allow impossible directions
    */
    void allowAllDirections(bool allow) { myAllowAllDirectionsFlag = allow; }

    /**
      Changes to a new state based on the current state and the given event.

      @param type  The event
      @return      True if the state changed, else false
    */
    bool changeStateByEvent(Event::Type type);

    /**
      Get the current overlay in use.  The overlay won't always exist,
      so we should test if it's available.

      @return The overlay object
    */
    DialogContainer& overlay() const  { return *myOverlay; }
    bool hasOverlay() const { return myOverlay != nullptr; }

    /**
      Return a simple list of all physical joysticks currently in the internal database
    */
    PhysicalJoystickHandler::MinStrickInfoList physicalJoystickList() const {
      return myPJoyHandler->minStickList();
    }

    /**
      Remove the physical joystick identified by 'name' from the joystick
      database, only if it is not currently active.
    */
    void removePhysicalJoystickFromDatabase(string_view name);

    /**
      Change the port of the physical joystick identified by 'name' in
      the joystick database, only if it is not currently active.
    */
    void setPhysicalJoystickPortInDatabase(string_view name, PhysicalJoystick::Port port);

    /**
      Enable/disable text events (distinct from single-key events).
    */
    virtual void enableTextEvents(bool enable) = 0;

  #ifdef GUI_SUPPORT
    /**
      Check for QWERTZ keyboard layout
    */
    bool isQwertz() const { return myQwertz; }

    /**
      Clipboard methods.
    */
    virtual void copyText(const string& text) const = 0;
    virtual string pasteText(string& text) const = 0;
  #endif

    /**
      Handle changing mouse modes.
    */
    void changeMouseControl(int direction = +1);
    bool hasMouseControl() const;

    void saveKeyMapping();
    void saveJoyMapping();

    void exitLauncher();
    void exitEmulation(bool checkLauncher = false);

  protected:
    // Global OSystem object
    OSystem& myOSystem;

  #ifdef GUI_SUPPORT
    // Keyboard layout
    bool myQwertz{false};
  #endif

    /**
      Sets the combo event mappings to those in the 'combomap' setting
    */
    void setComboMap();

    /**
      Methods which are called by derived classes to handle specific types
      of input.
    */
    void handleTextEvent(char text);
    void handleMouseMotionEvent(int x, int y, int xrel, int yrel);
    void handleMouseButtonEvent(MouseButton b, bool pressed, int x, int y);
    void handleKeyEvent(StellaKey key, StellaMod mod, bool pressed, bool repeated) {
      myPKeyHandler->handleEvent(key, mod, pressed, repeated);
    }
    void handleJoyBtnEvent(int stick, int button, bool pressed) {
      myPJoyHandler->handleBtnEvent(stick, button, pressed);
    }
    void handleJoyAxisEvent(int stick, int axis, int value) {
      myPJoyHandler->handleAxisEvent(stick, axis, value);
    }
    void handleJoyHatEvent(int stick, int hat, int value) {
      myPJoyHandler->handleHatEvent(stick, hat, value);
    }

    /**
      Collects and dispatches any pending events.
    */
    virtual void pollEvent() = 0;

    // Other events that can be received from the underlying event handler
    enum class SystemEvent {
      WINDOW_SHOWN,
      WINDOW_HIDDEN,
      WINDOW_EXPOSED,
      WINDOW_MOVED,
      WINDOW_RESIZED,
      WINDOW_MINIMIZED,
      WINDOW_MAXIMIZED,
      WINDOW_RESTORED,
      WINDOW_ENTER,
      WINDOW_LEAVE,
      WINDOW_FOCUS_GAINED,
      WINDOW_FOCUS_LOST
    };
    void handleSystemEvent(SystemEvent e, int data1 = 0, int data2 = 0);

    /**
      Add the given joystick to the list of physical joysticks available to
      the handler.
    */
    void addPhysicalJoystick(const PhysicalJoystickPtr& joy);

    /**
      Remove physical joystick with the givem id.
    */
    void removePhysicalJoystick(int id);

  private:
    // Define event groups
    static const Event::EventSet MiscEvents;
    static const Event::EventSet AudioVideoEvents;
    static const Event::EventSet StateEvents;
    static const Event::EventSet ConsoleEvents;
    static const Event::EventSet JoystickEvents;
    static const Event::EventSet PaddlesEvents;
    static const Event::EventSet KeyboardEvents;
    static const Event::EventSet DrivingEvents;
    static const Event::EventSet DevicesEvents;
    static const Event::EventSet ComboEvents;
    static const Event::EventSet DebugEvents;

    /**
      The following methods take care of assigning action mappings.
    */
    void setActionMappings(EventMode mode);
    void setDefaultKeymap(Event::Type, EventMode mode);
    void setDefaultJoymap(Event::Type, EventMode mode);
    static nlohmann::json convertLegacyComboMapping(string list);
    void saveComboMapping();

    static StringList getActionList(EventMode mode);
    static StringList getActionList(const Event::EventSet& events,
        EventMode mode = EventMode::kEmulationMode);
    // returns the action array index of the index in the provided group
    static int getEmulActionListIndex(int idx, const Event::EventSet& events);
    static int getActionListIndex(int idx, Event::Group group);

  private:
    // Structure used for action menu items
    struct ActionList {
      Event::Type event{Event::NoType};
      string action;
      string key;
    };

    // Global Event object
    Event myEvent;

    // Indicates current overlay object
    DialogContainer* myOverlay{nullptr};

    // Handler for all global key events
    unique_ptr<GlobalKeyHandler> myGlobalKeyHandler;

    // Handler for all keyboard-related events
    unique_ptr<PhysicalKeyboardHandler> myPKeyHandler;

    // Handler for all joystick addition/removal/mapping
    unique_ptr<PhysicalJoystickHandler> myPJoyHandler;

    // MouseControl object, which takes care of switching the mouse between
    // all possible controller modes
    unique_ptr<MouseControl> myMouseControl;

    // Indicates the current state of the system (ie, which mode is current)
    EventHandlerState myState{EventHandlerState::NONE};

    // Indicates whether the virtual joystick emulates 'impossible' directions
    bool myAllowAllDirectionsFlag{false};

    // Indicates whether or not we're in frying mode
    bool myFryingFlag{false};

    // Sometimes an extraneous mouse motion event occurs after a video
    // state change; we detect when this happens and discard the event
    bool mySkipMouseMotion{true};

    // Whether the currently enabled console is emulating certain aspects
    // of the 7800 (for now, only the switches are notified)
    bool myIs7800{false};

    // These constants are not meant to be used elsewhere; they are only used
    // here to make it easier for the reader to correctly size the list(s)
    static constexpr Int32
      COMBO_SIZE           = 16,
      EVENTS_PER_COMBO     = 8,
    #ifdef IMAGE_SUPPORT
      PNG_SIZE             = 4,
    #else
      PNG_SIZE             = 0,
    #endif
    #ifdef ADAPTABLE_REFRESH_SUPPORT
      REFRESH_SIZE         = 1,
    #else
      REFRESH_SIZE         = 0,
    #endif
      EMUL_ACTIONLIST_SIZE = 234 + PNG_SIZE + COMBO_SIZE + REFRESH_SIZE,
      MENU_ACTIONLIST_SIZE = 20
    ;

    // The event(s) assigned to each combination event
    BSPF::array2D<Event::Type, COMBO_SIZE, EVENTS_PER_COMBO> myComboTable;

    // Holds static strings for the remap menu (emulation and menu events)
    using EmulActionList = std::array<ActionList, EMUL_ACTIONLIST_SIZE>;
    static EmulActionList ourEmulActionList;
    using MenuActionList = std::array<ActionList, MENU_ACTIONLIST_SIZE>;
    static MenuActionList ourMenuActionList;

    // Following constructors and assignment operators not supported
    EventHandler() = delete;
    EventHandler(const EventHandler&) = delete;
    EventHandler(EventHandler&&) = delete;
    EventHandler& operator=(const EventHandler&) = delete;
    EventHandler& operator=(EventHandler&&) = delete;
};

#endif
