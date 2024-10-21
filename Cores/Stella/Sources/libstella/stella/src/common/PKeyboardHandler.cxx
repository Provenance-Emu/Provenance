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

#include "OSystem.hxx"
#include "Console.hxx"
#include "PropsSet.hxx"
#include "EventHandler.hxx"
#include "PKeyboardHandler.hxx"
#include "json_lib.hxx"

using json = nlohmann::json;

#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
#endif
#ifdef GUI_SUPPORT
  #include "DialogContainer.hxx"
#endif

#if defined(BSPF_MACOS) || defined(MACOS_KEYS)
static constexpr int MOD3 = KBDM_GUI;
static constexpr int CMD = KBDM_GUI;
static constexpr int OPTION = KBDM_ALT;
#else
static constexpr int MOD3 = KBDM_ALT;
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::PhysicalKeyboardHandler(OSystem& system, EventHandler& handler)
  : myOSystem{system},
    myHandler{handler}
{
  const Int32 version = myOSystem.settings().getInt("event_ver");
  bool updateDefaults = false;

  // Compare if event list version has changed so that key maps became invalid
  if (version == Event::VERSION)
  {
    loadSerializedMappings(myOSystem.settings().getString("keymap_emu"), EventMode::kCommonMode);
    loadSerializedMappings(myOSystem.settings().getString("keymap_joy"), EventMode::kJoystickMode);
    loadSerializedMappings(myOSystem.settings().getString("keymap_pad"), EventMode::kPaddlesMode);
    loadSerializedMappings(myOSystem.settings().getString("keymap_drv"), EventMode::kDrivingMode);
    loadSerializedMappings(myOSystem.settings().getString("keymap_key"), EventMode::kKeyboardMode);
    loadSerializedMappings(myOSystem.settings().getString("keymap_ui"), EventMode::kMenuMode);

    updateDefaults = true;
  }

  myKeyMap.enableMod() = myOSystem.settings().getBool("modcombo");

  setDefaultMapping(Event::NoType, EventMode::kEmulationMode, updateDefaults);
  setDefaultMapping(Event::NoType, EventMode::kMenuMode, updateDefaults);
#ifdef GUI_SUPPORT
  setDefaultMapping(Event::NoType, EventMode::kEditMode, updateDefaults);
#endif
#ifdef DEBUGGER_SUPPORT
  setDefaultMapping(Event::NoType, EventMode::kPromptMode, updateDefaults);
#endif
#ifdef DEBUG_BUILD
  verifyDefaultMapping(DefaultCommonMapping, EventMode::kEmulationMode, "EmulationMode");
  verifyDefaultMapping(DefaultMenuMapping, EventMode::kMenuMode, "MenuMode");
#endif
}

#ifdef DEBUG_BUILD
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::verifyDefaultMapping(
  PhysicalKeyboardHandler::EventMappingArray mapping, EventMode mode, string_view name)
{
  for(const auto& item1 : mapping)
    for(const auto& item2 : mapping)
      if(item1.event != item2.event && item1.key == item2.key && item1.mod == item2.mod)
        cerr << "ERROR! Duplicate hotkey mapping found: " << name << ", "
          << myKeyMap.getDesc(KeyMap::Mapping(mode, item1.key, item1.mod)) << "\n";
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::loadSerializedMappings(
    string_view serializedMapping, EventMode mode)
{
  json mapping;

  try {
    mapping = json::parse(serializedMapping);
  } catch (const json::exception&) {
    Logger::info("converting legacy keyboard mappings");

    mapping = KeyMap::convertLegacyMapping(serializedMapping);
  }

  try {
    myKeyMap.loadMapping(mapping, mode);
  } catch (const json::exception&) {
    Logger::error("ignoring bad keyboard mappings");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::isMappingUsed(EventMode mode, const EventMapping& map) const
{
  // Menu events can only interfere with
  //   - other menu events
  if(mode == EventMode::kMenuMode)
    return myKeyMap.check(EventMode::kMenuMode, map.key, map.mod);

  // Controller events can interfere with
  //   - other events of the same controller
  //   - and common emulation events
  if(mode != EventMode::kCommonMode)
    return myKeyMap.check(mode, map.key, map.mod)
      || myKeyMap.check(EventMode::kCommonMode, map.key, map.mod);

  // Common emulation events can interfere with
  //   - other common emulation events
  //   - and all controller events
  return myKeyMap.check(EventMode::kCommonMode, map.key, map.mod)
    || myKeyMap.check(EventMode::kJoystickMode, map.key, map.mod)
    || myKeyMap.check(EventMode::kPaddlesMode, map.key, map.mod)
    || myKeyMap.check(EventMode::kKeyboardMode, map.key, map.mod)
    || myKeyMap.check(EventMode::kDrivingMode, map.key, map.mod)
    || myKeyMap.check(EventMode::kCompuMateMode, map.key, map.mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Depending on parameters, this method does the following:
// 1. update all events with default (event == Event::NoType, updateDefault == true)
// 2. reset all events to default    (event == Event::NoType, updateDefault == false)
// 3. reset one event to default     (event != Event::NoType)
void PhysicalKeyboardHandler::setDefaultKey(EventMapping map, Event::Type event,
                                            EventMode mode, bool updateDefaults)
{
  // If event is 'NoType', erase and reset all mappings
  // Otherwise, only reset the given event
  const bool eraseAll = !updateDefaults && (event == Event::NoType);

#ifdef GUI_SUPPORT
  // Swap Y and Z for QWERTZ keyboards
  if(mode == EventMode::kEditMode && myHandler.isQwertz())
  {
    if(map.key == KBDK_Z)
      map.key = KBDK_Y;
    else if(map.key == KBDK_Y)
      map.key = KBDK_Z;
  }
#endif

  if (updateDefaults)
  {
    // if there is no existing mapping for the event and
    //  the default mapping for the event is unused, set default key for event
    if (myKeyMap.getEventMapping(map.event, mode).empty() &&
        !isMappingUsed(mode, map))
    {
      addMapping(map.event, mode, map.key, static_cast<StellaMod>(map.mod));
    }
  }
  else if (eraseAll || map.event == event)
  {
    //myKeyMap.eraseEvent(map.event, mode);
    addMapping(map.event, mode, map.key, static_cast<StellaMod>(map.mod));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Depending on parameters, this method does the following:
// 1. update all events with default (event == Event::NoType, updateDefault == true)
// 2. reset all events to default    (event == Event::NoType, updateDefault == false)
// 3. reset one event to default     (event != Event::NoType)
void PhysicalKeyboardHandler::setDefaultMapping(Event::Type event, EventMode mode,
                                                bool updateDefaults)
{
  if (!updateDefaults)
  {
    myKeyMap.eraseEvent(event, mode);
    myKeyMap.eraseEvent(event, getEventMode(event, mode));
  }

  switch(mode)
  {
    case EventMode::kEmulationMode:
      for (const auto& item: DefaultCommonMapping)
        setDefaultKey(item, event, EventMode::kCommonMode, updateDefaults);
      // put all controller events into their own mode's mappings
      for (const auto& item: DefaultJoystickMapping)
        setDefaultKey(item, event, EventMode::kJoystickMode, updateDefaults);
      for (const auto& item: DefaultPaddleMapping)
        setDefaultKey(item, event, EventMode::kPaddlesMode, updateDefaults);
      for (const auto& item: DefaultKeyboardMapping)
        setDefaultKey(item, event, EventMode::kKeyboardMode, updateDefaults);
      for (const auto& item: DefaultDrivingMapping )
        setDefaultKey(item, event, EventMode::kDrivingMode, updateDefaults);
      for (const auto& item : CompuMateMapping)
        setDefaultKey(item, event, EventMode::kCompuMateMode, updateDefaults);
      break;

    case EventMode::kMenuMode:
      for (const auto& item: DefaultMenuMapping)
        setDefaultKey(item, event, EventMode::kMenuMode, updateDefaults);
      break;

  #ifdef GUI_SUPPORT
    case EventMode::kEditMode:
      // Edit mode events are always set because they are not saved
      for(const auto& item: FixedEditMapping)
        setDefaultKey(item, event, EventMode::kEditMode);
      break;
  #endif
  #ifdef DEBUGGER_SUPPORT
    case EventMode::kPromptMode:
      // Edit mode events are always set because they are not saved
      for(const auto& item : FixedPromptMapping)
        setDefaultKey(item, event, EventMode::kPromptMode);
      break;
  #endif

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::defineControllerMappings(
    const Controller::Type type, Controller::Jack port, const Properties& properties,
    Controller::Type qtType1, Controller::Type qtType2)
{
  // Determine controller events to use
  if(type == Controller::Type::QuadTari)
  {
    if(port == Controller::Jack::Left)
    {
      myLeftMode = getMode(qtType1);
      myLeft2ndMode = getMode(qtType2);
    }
    else
    {
      myRightMode = getMode(qtType1);
      myRight2ndMode = getMode(qtType2);
    }
  }
  else
  {
    const EventMode mode = getMode(type);

    if(port == Controller::Jack::Left)
      myLeftMode = mode;
    else
      myRightMode = mode;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventMode PhysicalKeyboardHandler::getMode(const Properties& properties,
                                           const PropType propType)
{
  const string& propName = properties.get(propType);

  if(!propName.empty())
    return getMode(Controller::getType(propName));

  return EventMode::kJoystickMode;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventMode PhysicalKeyboardHandler::getMode(const Controller::Type type)
{
  switch(type)
  {
    case Controller::Type::Keyboard:
    case Controller::Type::KidVid:
      return EventMode::kKeyboardMode;

    case Controller::Type::Paddles:
    case Controller::Type::PaddlesIAxDr:
    case Controller::Type::PaddlesIAxis:
      return EventMode::kPaddlesMode;

    case Controller::Type::CompuMate:
      return EventMode::kCompuMateMode;

    case Controller::Type::Driving:
      return EventMode::kDrivingMode;

    default:
      // let's use joystick then
      return EventMode::kJoystickMode;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::enableEmulationMappings()
{
  // start from scratch and enable common mappings
  myKeyMap.eraseMode(EventMode::kEmulationMode);
  enableCommonMappings();

  // Process in increasing priority order, so that in case of mapping clashes
  //  the higher priority controller has preference
  switch(myRight2ndMode)
  {
    case EventMode::kPaddlesMode:
      enableMappings(QTPaddles4Events, EventMode::kPaddlesMode);
      break;

    case EventMode::kEmulationMode: // no QuadTari
      break;

    default:
      enableMappings(QTJoystick4Events, EventMode::kJoystickMode);
      break;
  }

  switch(myLeft2ndMode)
  {
    case EventMode::kPaddlesMode:
      enableMappings(QTPaddles3Events, EventMode::kPaddlesMode);
      break;

    case EventMode::kEmulationMode: // no QuadTari
      break;

    default:
      enableMappings(QTJoystick3Events, EventMode::kJoystickMode);
      break;
  }

  switch(myRightMode)
  {
    case EventMode::kPaddlesMode:
      enableMappings(RightPaddlesEvents, EventMode::kPaddlesMode);
      break;

    case EventMode::kKeyboardMode:
      enableMappings(RightKeyboardEvents, EventMode::kKeyboardMode);
      break;

    case EventMode::kCompuMateMode:
      // see below
      break;

    case EventMode::kDrivingMode:
      enableMappings(RightDrivingEvents, EventMode::kDrivingMode);
      break;

    default:
      enableMappings(RightJoystickEvents, EventMode::kJoystickMode);
      break;
  }

  switch(myLeftMode)
  {
    case EventMode::kPaddlesMode:
      enableMappings(LeftPaddlesEvents, EventMode::kPaddlesMode);
      break;

    case EventMode::kKeyboardMode:
      enableMappings(LeftKeyboardEvents, EventMode::kKeyboardMode);
      break;

    case EventMode::kCompuMateMode:
      for(const auto& item : CompuMateMapping)
        enableMapping(item.event, EventMode::kCompuMateMode);
      break;

    case EventMode::kDrivingMode:
      enableMappings(LeftDrivingEvents, EventMode::kDrivingMode);
      break;

    default:
      enableMappings(LeftJoystickEvents, EventMode::kJoystickMode);
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::enableCommonMappings()
{
  for (int i = Event::NoType + 1; i < Event::LastType; i++)
  {
    const auto event = static_cast<Event::Type>(i);

    if (isCommonEvent(event))
      enableMapping(event, EventMode::kCommonMode);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::enableMappings(const Event::EventSet& events,
                                             EventMode mode)
{
  for (const auto& event : events)
    enableMapping(event, mode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::enableMapping(const Event::Type event,
                                            EventMode mode)
{
  // copy from controller mode into emulation mode
  const KeyMap::MappingArray mappings = myKeyMap.getEventMapping(event, mode);

  for (const auto& mapping : mappings)
    myKeyMap.add(event, EventMode::kEmulationMode, mapping.key, mapping.mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventMode PhysicalKeyboardHandler::getEventMode(const Event::Type event,
                                                const EventMode mode)
{
  if (mode == EventMode::kEmulationMode)
  {
    if (isJoystickEvent(event))
      return EventMode::kJoystickMode;

    if (isPaddleEvent(event))
      return EventMode::kPaddlesMode;

    if (isKeyboardEvent(event))
      return EventMode::kKeyboardMode;

    if (isDrivingEvent(event))
      return EventMode::kDrivingMode;

    if (isCommonEvent(event))
      return EventMode::kCommonMode;
  }

  return mode;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::isJoystickEvent(const Event::Type event)
{
  return LeftJoystickEvents.find(event) != LeftJoystickEvents.end()
    || QTJoystick3Events.find(event) != QTJoystick3Events.end()
    || RightJoystickEvents.find(event) != RightJoystickEvents.end()
    || QTJoystick4Events.find(event) != QTJoystick4Events.end();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::isPaddleEvent(const Event::Type event)
{
  return LeftPaddlesEvents.find(event) != LeftPaddlesEvents.end()
    || QTPaddles3Events.find(event) != QTPaddles3Events.end()
    || RightPaddlesEvents.find(event) != RightPaddlesEvents.end()
    || QTPaddles4Events.find(event) != QTPaddles4Events.end();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::isKeyboardEvent(const Event::Type event)
{
  return LeftKeyboardEvents.find(event) != LeftKeyboardEvents.end()
    || RightKeyboardEvents.find(event) != RightKeyboardEvents.end();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::isDrivingEvent(const Event::Type event)
{
  return LeftDrivingEvents.find(event) != LeftDrivingEvents.end()
    || RightDrivingEvents.find(event) != RightDrivingEvents.end();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::isCommonEvent(const Event::Type event)
{
  return !(isJoystickEvent(event) || isPaddleEvent(event)
    || isKeyboardEvent(event) || isDrivingEvent(event));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::eraseMapping(Event::Type event, EventMode mode)
{
  myKeyMap.eraseEvent(event, mode);
  myKeyMap.eraseEvent(event, getEventMode(event, mode));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::saveMapping()
{
  myOSystem.settings().setValue("event_ver", Event::VERSION);
  myOSystem.settings().setValue("keymap_emu", myKeyMap.saveMapping(EventMode::kCommonMode).dump(2));
  myOSystem.settings().setValue("keymap_joy", myKeyMap.saveMapping(EventMode::kJoystickMode).dump(2));
  myOSystem.settings().setValue("keymap_pad", myKeyMap.saveMapping(EventMode::kPaddlesMode).dump(2));
  myOSystem.settings().setValue("keymap_drv", myKeyMap.saveMapping(EventMode::kDrivingMode).dump(2));
  myOSystem.settings().setValue("keymap_key", myKeyMap.saveMapping(EventMode::kKeyboardMode).dump(2));
  myOSystem.settings().setValue("keymap_ui", myKeyMap.saveMapping(EventMode::kMenuMode).dump(2));
  enableEmulationMappings();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PhysicalKeyboardHandler::addMapping(Event::Type event, EventMode mode,
                                         StellaKey key, StellaMod mod)
{
  // These events cannot be remapped to keys
  if(Event::isAnalog(event))
    return false;
  else
  {
    const EventMode evMode = getEventMode(event, mode);

    // avoid double mapping in common and controller modes
    if (evMode == EventMode::kCommonMode)
    {
      // erase identical mappings for all controller modes
      myKeyMap.erase(EventMode::kJoystickMode, key, mod);
      myKeyMap.erase(EventMode::kPaddlesMode, key, mod);
      myKeyMap.erase(EventMode::kKeyboardMode, key, mod);
      myKeyMap.erase(EventMode::kCompuMateMode, key, mod);
    }
    else if(evMode != EventMode::kMenuMode
            && evMode != EventMode::kEditMode
            && evMode != EventMode::kPromptMode)
    {
      // erase identical mapping for kCommonMode
      myKeyMap.erase(EventMode::kCommonMode, key, mod);
    }

    myKeyMap.add(event, evMode, key, mod);
    if (evMode == myLeftMode || evMode == myRightMode ||
        evMode == myLeft2ndMode || evMode == myRight2ndMode)
      myKeyMap.add(event, mode, key, mod);
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::handleEvent(StellaKey key, StellaMod mod,
                                          bool pressed, bool repeated)
{
#ifdef BSPF_UNIX
  // Swallow KBDK_TAB under certain conditions
  // See comments on 'myAltKeyCounter' for more information
  if(myAltKeyCounter > 1 && key == KBDK_TAB)
  {
    myAltKeyCounter = 0;
    return;
  }
  if (key == KBDK_TAB && pressed && StellaModTest::isAlt(mod))
  {
    // Swallow Alt-Tab, but remember that it happened
    myAltKeyCounter = 1;
    return;
  }
#endif

  const EventHandlerState estate = myHandler.state();

  // special handling for CompuMate in emulation modes
  if ((estate == EventHandlerState::EMULATION || estate == EventHandlerState::PAUSE) &&
      myOSystem.console().leftController().type() == Controller::Type::CompuMate)
  {
    const Event::Type event = myKeyMap.get(EventMode::kCompuMateMode, key, mod);

    // (potential) CompuMate events are handled directly.
    if (myKeyMap.get(EventMode::kEmulationMode, key, mod) != Event::ExitMode &&
      !StellaModTest::isAlt(mod) && event != Event::NoType)
    {
      myHandler.handleEvent(event, pressed, repeated);
      return;
    }
  }

  // Arrange the logic to take advantage of short-circuit evaluation
  // Handle keys which switch eventhandler state
  if (!pressed && myHandler.changeStateByEvent(myKeyMap.get(EventMode::kEmulationMode, key, mod)))
    return;

  // Otherwise, let the event handler deal with it
  switch(estate)
  {
    case EventHandlerState::EMULATION:
    case EventHandlerState::PAUSE:
    case EventHandlerState::PLAYBACK:
      myHandler.handleEvent(myKeyMap.get(EventMode::kEmulationMode, key, mod), pressed, repeated);
      break;

    default:
    #ifdef GUI_SUPPORT
      if (myHandler.hasOverlay())
        myHandler.overlay().handleKeyEvent(key, mod, pressed, repeated);
    #endif
      myHandler.handleEvent(myKeyMap.get(EventMode::kMenuMode, key, mod), pressed, repeated);
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PhysicalKeyboardHandler::toggleModKeys(bool toggle)
{
  bool modCombo = myOSystem.settings().getBool("modcombo");

  if(toggle)
  {
    modCombo = !modCombo;
    myKeyMap.enableMod() = modCombo;
    myOSystem.settings().setValue("modcombo", modCombo);
  }

  ostringstream ss;
  ss << "Modifier key combos ";
  ss << (modCombo ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(ss.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::DefaultCommonMapping = {
  { Event::ConsoleSelect,            KBDK_F1 },
  { Event::ConsoleReset,             KBDK_F2 },
  { Event::ConsoleColor,             KBDK_F3 },
  { Event::Console7800Pause,         KBDK_F3, MOD3 },
  { Event::ConsoleLeftDiffA,         KBDK_F5 },
  { Event::ConsoleRightDiffA,        KBDK_F7 },
  { Event::SaveState,                KBDK_F9 },
  { Event::SaveAllStates,            KBDK_F9, MOD3 },
  { Event::PreviousState,            KBDK_F10, KBDM_SHIFT },
  { Event::NextState,                KBDK_F10 },
  { Event::ToggleAutoSlot,           KBDK_F10, MOD3 },
  { Event::LoadState,                KBDK_F11 },
  { Event::LoadAllStates,            KBDK_F11, MOD3 },
  { Event::TakeSnapshot,             KBDK_F12 },
  #ifdef BSPF_MACOS
  { Event::TogglePauseMode,          KBDK_P, KBDM_SHIFT | MOD3 },
  #else
  { Event::TogglePauseMode,          KBDK_PAUSE },
  #endif
  { Event::OptionsMenuMode,          KBDK_TAB },
  { Event::CmdMenuMode,              KBDK_BACKSLASH },
  { Event::ToggleBezel,              KBDK_B, KBDM_CTRL },
  { Event::TimeMachineMode,          KBDK_T, KBDM_SHIFT },
  { Event::DebuggerMode,             KBDK_GRAVE },
  { Event::PlusRomsSetupMode,        KBDK_P, KBDM_SHIFT | KBDM_CTRL | MOD3 },
  { Event::ExitMode,                 KBDK_ESCAPE },
  #ifdef BSPF_MACOS
  { Event::Quit,                     KBDK_Q, MOD3 },
  #else
  { Event::Quit,                     KBDK_Q, KBDM_CTRL },
  #endif
  { Event::ReloadConsole,            KBDK_R, KBDM_CTRL },
  { Event::PreviousMultiCartRom,     KBDK_R, KBDM_SHIFT | KBDM_CTRL },

  { Event::VidmodeDecrease,          KBDK_MINUS, MOD3 },
  { Event::VidmodeIncrease,          KBDK_EQUALS, MOD3 },
  { Event::VCenterDecrease,          KBDK_PAGEUP, MOD3 },
  { Event::VCenterIncrease,          KBDK_PAGEDOWN, MOD3 },
  { Event::VSizeAdjustDecrease,      KBDK_PAGEDOWN, KBDM_SHIFT | MOD3 },
  { Event::VSizeAdjustIncrease,      KBDK_PAGEUP, KBDM_SHIFT | MOD3 },
  { Event::ToggleCorrectAspectRatio, KBDK_C, KBDM_SHIFT | KBDM_CTRL },
  { Event::VolumeDecrease,           KBDK_LEFTBRACKET, MOD3 },
  { Event::VolumeIncrease,           KBDK_RIGHTBRACKET, MOD3 },
  { Event::SoundToggle,              KBDK_RIGHTBRACKET, KBDM_CTRL },

  { Event::ToggleFullScreen,         KBDK_RETURN, MOD3 },
  { Event::ToggleAdaptRefresh,       KBDK_R, MOD3 },
  { Event::OverscanDecrease,         KBDK_PAGEDOWN, KBDM_SHIFT },
  { Event::OverscanIncrease,         KBDK_PAGEUP, KBDM_SHIFT },
  { Event::PreviousVideoMode,        KBDK_1, KBDM_SHIFT | MOD3 },
  { Event::NextVideoMode,            KBDK_1, MOD3 },
  { Event::PreviousAttribute,        KBDK_2, KBDM_SHIFT | MOD3 },
  { Event::NextAttribute,            KBDK_2, MOD3 },
  { Event::DecreaseAttribute,        KBDK_3, KBDM_SHIFT | MOD3 },
  { Event::IncreaseAttribute,        KBDK_3, MOD3 },
  { Event::PhosphorDecrease,         KBDK_4, KBDM_SHIFT | MOD3 },
  { Event::PhosphorIncrease,         KBDK_4, MOD3 },
  { Event::TogglePhosphor,           KBDK_P, MOD3 },
  //{ Event::PhosphorModeDecrease,     KBDK_P, KBDM_SHIFT | KBDM_CTRL | MOD3 },
  { Event::PhosphorModeIncrease,     KBDK_P, KBDM_CTRL | MOD3 },
  { Event::ScanlinesDecrease,        KBDK_5, KBDM_SHIFT | MOD3 },
  { Event::ScanlinesIncrease,        KBDK_5, MOD3 },
  { Event::PreviousScanlineMask,     KBDK_6, KBDM_SHIFT | MOD3 },
  { Event::NextScanlineMask,         KBDK_6, MOD3 },
  { Event::PreviousPaletteAttribute, KBDK_9, KBDM_SHIFT | MOD3 },
  { Event::NextPaletteAttribute,     KBDK_9, MOD3 },
  { Event::PaletteAttributeDecrease, KBDK_0, KBDM_SHIFT | MOD3 },
  { Event::PaletteAttributeIncrease, KBDK_0, MOD3 },
  { Event::ToggleColorLoss,          KBDK_L, KBDM_CTRL },
  { Event::PaletteDecrease,          KBDK_P, KBDM_SHIFT | KBDM_CTRL },
  { Event::PaletteIncrease,          KBDK_P, KBDM_CTRL },
  { Event::FormatDecrease,           KBDK_F, KBDM_SHIFT | KBDM_CTRL },
  { Event::FormatIncrease,           KBDK_F, KBDM_CTRL },
  #ifndef BSPF_MACOS
  { Event::PreviousSetting,          KBDK_END },
  { Event::NextSetting,              KBDK_HOME },
  { Event::PreviousSettingGroup,     KBDK_END, KBDM_CTRL },
  { Event::NextSettingGroup,         KBDK_HOME, KBDM_CTRL },
  #else
    // HOME & END keys are swapped on Mac keyboards
  { Event::PreviousSetting,          KBDK_HOME },
  { Event::NextSetting,              KBDK_END },
  { Event::PreviousSettingGroup,     KBDK_HOME, KBDM_CTRL },
  { Event::NextSettingGroup,         KBDK_END, KBDM_CTRL },
  #endif
  { Event::PreviousSetting,          KBDK_KP_1 },
  { Event::NextSetting,              KBDK_KP_7 },
  { Event::PreviousSettingGroup,     KBDK_KP_1, KBDM_CTRL },
  { Event::NextSettingGroup,         KBDK_KP_7, KBDM_CTRL },
  { Event::SettingDecrease,          KBDK_PAGEDOWN },
  { Event::SettingDecrease,          KBDK_KP_3, KBDM_CTRL },
  { Event::SettingIncrease,          KBDK_PAGEUP },
  { Event::SettingIncrease,          KBDK_KP_9, KBDM_CTRL },

  { Event::ToggleInter,              KBDK_I, KBDM_CTRL },
  { Event::DecreaseSpeed,            KBDK_S, KBDM_SHIFT | KBDM_CTRL },
  { Event::IncreaseSpeed,            KBDK_S, KBDM_CTRL },
  { Event::ToggleTurbo,              KBDK_T, KBDM_CTRL },
  { Event::JitterSenseDecrease,      KBDK_J, KBDM_SHIFT | MOD3 | KBDM_CTRL },
  { Event::JitterSenseIncrease,      KBDK_J, MOD3 | KBDM_CTRL },
  { Event::JitterRecDecrease,        KBDK_J, KBDM_SHIFT | KBDM_CTRL },
  { Event::JitterRecIncrease,        KBDK_J, KBDM_CTRL },
  { Event::ToggleDeveloperSet,       KBDK_D, MOD3 },
  { Event::ToggleJitter,             KBDK_J, MOD3 },
  { Event::ToggleFrameStats,         KBDK_L, MOD3 },
  { Event::ToggleTimeMachine,        KBDK_T, MOD3 },

  #ifdef IMAGE_SUPPORT
  { Event::ToggleContSnapshots,      KBDK_S, MOD3 | KBDM_CTRL },
  { Event::ToggleContSnapshotsFrame, KBDK_S, KBDM_SHIFT | MOD3 | KBDM_CTRL },
  #endif

  { Event::DecreaseDeadzone,         KBDK_F1, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncreaseDeadzone,         KBDK_F1, KBDM_CTRL },
  { Event::DecAnalogDeadzone,        KBDK_F1, KBDM_CTRL | MOD3 | KBDM_SHIFT},
  { Event::IncAnalogDeadzone,        KBDK_F1, KBDM_CTRL | MOD3},
  { Event::DecAnalogSense,           KBDK_F2, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncAnalogSense,           KBDK_F2, KBDM_CTRL },
  { Event::DecAnalogLinear,          KBDK_F2, KBDM_CTRL | MOD3 | KBDM_SHIFT},
  { Event::IncAnalogLinear,          KBDK_F2, KBDM_CTRL | MOD3},
  { Event::DecDejtterAveraging,      KBDK_F3, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncDejtterAveraging,      KBDK_F3, KBDM_CTRL },
  { Event::DecDejtterReaction,       KBDK_F4, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncDejtterReaction,       KBDK_F4, KBDM_CTRL },
  { Event::DecDigitalSense,          KBDK_F5, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncDigitalSense,          KBDK_F5, KBDM_CTRL },
  { Event::ToggleAutoFire,           KBDK_A, MOD3 },
  { Event::DecreaseAutoFire,         KBDK_A, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncreaseAutoFire,         KBDK_A, KBDM_CTRL },
  { Event::ToggleFourDirections,     KBDK_F6, KBDM_CTRL },
  { Event::ToggleKeyCombos,          KBDK_F7, KBDM_CTRL },
  { Event::ToggleSAPortOrder,        KBDK_1, KBDM_CTRL },

  { Event::PrevMouseAsController,    KBDK_F8, KBDM_CTRL | KBDM_SHIFT },
  { Event::NextMouseAsController,    KBDK_F8, KBDM_CTRL },
  { Event::DecMousePaddleSense,      KBDK_F9, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncMousePaddleSense,      KBDK_F9, KBDM_CTRL },
  { Event::DecMouseTrackballSense,   KBDK_F10, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncMouseTrackballSense,   KBDK_F10, KBDM_CTRL },
  { Event::DecreaseDrivingSense,     KBDK_F11, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncreaseDrivingSense,     KBDK_F11, KBDM_CTRL },
  { Event::PreviousCursorVisbility,  KBDK_F12, KBDM_CTRL | KBDM_SHIFT },
  { Event::NextCursorVisbility,      KBDK_F12, KBDM_CTRL },
  { Event::ToggleGrabMouse,          KBDK_G, KBDM_CTRL },

  { Event::PreviousLeftPort,         KBDK_2, KBDM_CTRL | KBDM_SHIFT },
  { Event::NextLeftPort,             KBDK_2, KBDM_CTRL },
  { Event::PreviousRightPort,        KBDK_3, KBDM_CTRL | KBDM_SHIFT },
  { Event::NextRightPort,            KBDK_3, KBDM_CTRL },
  { Event::ToggleSwapPorts,          KBDK_4, KBDM_CTRL },
  { Event::ToggleSwapPaddles,        KBDK_5, KBDM_CTRL },
  { Event::DecreasePaddleCenterX,    KBDK_6, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncreasePaddleCenterX,    KBDK_6, KBDM_CTRL },
  { Event::DecreasePaddleCenterY,    KBDK_7, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncreasePaddleCenterY,    KBDK_7, KBDM_CTRL },
  { Event::PreviousMouseControl,     KBDK_0, KBDM_CTRL | KBDM_SHIFT },
  { Event::NextMouseControl,         KBDK_0, KBDM_CTRL },
  { Event::DecreaseMouseAxesRange,   KBDK_8, KBDM_CTRL | KBDM_SHIFT },
  { Event::IncreaseMouseAxesRange,   KBDK_8, KBDM_CTRL },

  { Event::ToggleP0Collision,        KBDK_Z, KBDM_SHIFT | MOD3 },
  { Event::ToggleP0Bit,              KBDK_Z, MOD3 },
  { Event::ToggleP1Collision,        KBDK_X, KBDM_SHIFT | MOD3 },
  { Event::ToggleP1Bit,              KBDK_X, MOD3 },
  { Event::ToggleM0Collision,        KBDK_C, KBDM_SHIFT | MOD3 },
  { Event::ToggleM0Bit,              KBDK_C, MOD3 },
  { Event::ToggleM1Collision,        KBDK_V, KBDM_SHIFT | MOD3 },
  { Event::ToggleM1Bit,              KBDK_V, MOD3 },
  { Event::ToggleBLCollision,        KBDK_B, KBDM_SHIFT | MOD3 },
  { Event::ToggleBLBit,              KBDK_B, MOD3 },
  { Event::TogglePFCollision,        KBDK_N, KBDM_SHIFT | MOD3 },
  { Event::TogglePFBit,              KBDK_N, MOD3 },
  { Event::ToggleCollisions,         KBDK_COMMA, KBDM_SHIFT | MOD3 },
  { Event::ToggleBits,               KBDK_COMMA, MOD3 },
  { Event::ToggleFixedColors,        KBDK_PERIOD, MOD3 },

  { Event::RewindPause,              KBDK_LEFT, KBDM_CTRL | MOD3},
  { Event::Rewind1Menu,              KBDK_LEFT, MOD3 },
  { Event::Rewind10Menu,             KBDK_LEFT, KBDM_SHIFT | MOD3 },
  { Event::RewindAllMenu,            KBDK_DOWN, MOD3 },
  { Event::UnwindPause,              KBDK_RIGHT, KBDM_CTRL | MOD3},
  { Event::Unwind1Menu,              KBDK_RIGHT, MOD3 },
  { Event::Unwind10Menu,             KBDK_RIGHT, KBDM_SHIFT | MOD3 },
  { Event::UnwindAllMenu,            KBDK_UP, MOD3 },
  { Event::HighScoresMenuMode,       KBDK_INSERT },
  { Event::TogglePlayBackMode,       KBDK_SPACE, KBDM_SHIFT },

  #if defined(RETRON77)
  { Event::ConsoleColorToggle,       KBDK_F4 },         // back ("COLOR","B/W")
  { Event::ConsoleLeftDiffToggle,    KBDK_F6 },         // front ("SKILL P1")
  { Event::ConsoleRightDiffToggle,   KBDK_F8 },         // front ("SKILL P2")
  { Event::CmdMenuMode,              KBDK_F13 },        // back ("4:3","16:9")
  { Event::ExitMode,                 KBDK_BACKSPACE },  // back ("FRY")
  #else // defining duplicate keys must be avoided!
  { Event::ConsoleBlackWhite,        KBDK_F4 },
  { Event::ConsoleLeftDiffB,         KBDK_F6 },
  { Event::ConsoleRightDiffB,        KBDK_F8 },
  { Event::Fry,                      KBDK_BACKSPACE, KBDM_SHIFT },
#endif
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::DefaultMenuMapping = {
  {Event::UIUp,                     KBDK_UP},
  {Event::UIDown,                   KBDK_DOWN},
  {Event::UILeft,                   KBDK_LEFT},
  {Event::UIRight,                  KBDK_RIGHT},
  {Event::UISelect,                 KBDK_RETURN},
  {Event::UISelect,                 KBDK_SPACE},

  {Event::UIHome,                   KBDK_HOME},
  {Event::UIEnd,                    KBDK_END},
  {Event::UIPgUp,                   KBDK_PAGEUP},
  {Event::UIPgDown,                 KBDK_PAGEDOWN},
  // same with keypad
  {Event::UIUp,                     KBDK_KP_8},
  {Event::UIDown,                   KBDK_KP_2},
  {Event::UILeft,                   KBDK_KP_4},
  {Event::UIRight,                  KBDK_KP_6},
  {Event::UISelect,                 KBDK_KP_ENTER},

  {Event::UIHome,                   KBDK_KP_7},
  {Event::UIEnd,                    KBDK_KP_1},
  {Event::UIPgUp,                   KBDK_KP_9},
  {Event::UIPgDown,                 KBDK_KP_3},

  {Event::UICancel,                 KBDK_ESCAPE},

  {Event::UINavPrev,                KBDK_TAB, KBDM_SHIFT},
  {Event::UINavNext,                KBDK_TAB},
  {Event::UITabPrev,                KBDK_TAB, KBDM_SHIFT | KBDM_CTRL},
  {Event::UITabNext,                KBDK_TAB, KBDM_CTRL},

  {Event::ToggleUIPalette,          KBDK_T, MOD3},
  {Event::ToggleFullScreen,         KBDK_RETURN, MOD3},

#ifdef BSPF_MACOS
  {Event::Quit,                     KBDK_Q, MOD3},
#else
  {Event::Quit,                     KBDK_Q, KBDM_CTRL},
#endif

#if defined(RETRON77)
  {Event::UIUp,                     KBDK_F9},         // front ("SAVE")
  {Event::UIDown,                   KBDK_F2},         // front ("RESET")
  {Event::UINavPrev,                KBDK_F11},        // front ("LOAD")
  {Event::UINavNext,                KBDK_F1},         // front ("MODE")
  {Event::UISelect,                 KBDK_F6},         // front ("SKILL P1")
  {Event::UICancel,                 KBDK_F8},         // front ("SKILL P2")
  //{Event::NoType,                   KBDK_F4},         // back ("COLOR","B/W")
  {Event::UITabPrev,                KBDK_F13},        // back ("4:3","16:9")
  {Event::UITabNext,                KBDK_BACKSPACE},  // back (FRY)
#else // defining duplicate keys must be avoided!
  {Event::UIPrevDir,                KBDK_BACKSPACE},
#ifdef BSPF_MACOS
  {Event::UIHelp,                   KBDK_SLASH, KBDM_SHIFT | CMD},
#else
  {Event::UIHelp,                   KBDK_F1},
#endif
#endif
};

#ifdef GUI_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::FixedEditMapping = {
  {Event::MoveLeftChar,             KBDK_LEFT},
  {Event::MoveRightChar,            KBDK_RIGHT},
  {Event::SelectLeftChar,           KBDK_LEFT, KBDM_SHIFT},
  {Event::SelectRightChar,          KBDK_RIGHT, KBDM_SHIFT},
#if defined(BSPF_MACOS) || defined(MACOS_KEYS)
  {Event::MoveLeftWord,             KBDK_LEFT, OPTION},
  {Event::MoveRightWord,            KBDK_RIGHT, OPTION},
  {Event::MoveHome,                 KBDK_HOME},
  {Event::MoveHome,                 KBDK_A, KBDM_CTRL},
  {Event::MoveHome,                 KBDK_LEFT, CMD},
  {Event::MoveEnd,                  KBDK_END},
  {Event::MoveEnd,                  KBDK_E, KBDM_CTRL},
  {Event::MoveEnd,                  KBDK_RIGHT, CMD},
  {Event::SelectLeftWord,           KBDK_LEFT, KBDM_SHIFT | OPTION},
  {Event::SelectRightWord,          KBDK_RIGHT, KBDM_SHIFT | OPTION},
  {Event::SelectHome,               KBDK_HOME, KBDM_SHIFT},
  {Event::SelectHome,               KBDK_LEFT, KBDM_SHIFT | CMD},
  {Event::SelectHome,               KBDK_A, KBDM_CTRL | KBDM_SHIFT},
  {Event::SelectEnd,                KBDK_E, KBDM_SHIFT | KBDM_CTRL},
  {Event::SelectEnd,                KBDK_RIGHT, KBDM_SHIFT | CMD},
  {Event::SelectEnd,                KBDK_END, KBDM_SHIFT},
  {Event::SelectAll,                KBDK_A, CMD},
  {Event::Delete,                   KBDK_DELETE},
  {Event::Delete,                   KBDK_D, KBDM_CTRL},
  {Event::DeleteLeftWord,           KBDK_W, KBDM_CTRL},
  {Event::DeleteLeftWord,           KBDK_BACKSPACE, OPTION},
  {Event::DeleteRightWord,          KBDK_DELETE, OPTION},
  {Event::DeleteHome,               KBDK_U, KBDM_CTRL},
  {Event::DeleteHome,               KBDK_BACKSPACE, CMD},
  {Event::DeleteEnd,                KBDK_K, KBDM_CTRL},
  {Event::Backspace,                KBDK_BACKSPACE},
  {Event::Undo,                     KBDK_Z, CMD},
  {Event::Redo,                     KBDK_Y, CMD},
  {Event::Redo,                     KBDK_Z, KBDM_SHIFT | CMD},
  {Event::Cut,                      KBDK_X, CMD},
  {Event::Copy,                     KBDK_C, CMD},
  {Event::Paste,                    KBDK_V, CMD},
#else
  {Event::MoveLeftWord,             KBDK_LEFT, KBDM_CTRL},
  {Event::MoveRightWord,            KBDK_RIGHT, KBDM_CTRL},
  {Event::MoveHome,                 KBDK_HOME},
  {Event::MoveEnd,                  KBDK_END},
  {Event::SelectLeftWord,           KBDK_LEFT, KBDM_SHIFT | KBDM_CTRL},
  {Event::SelectRightWord,          KBDK_RIGHT, KBDM_SHIFT | KBDM_CTRL},
  {Event::SelectHome,               KBDK_HOME, KBDM_SHIFT},
  {Event::SelectEnd,                KBDK_END, KBDM_SHIFT},
  {Event::SelectAll,                KBDK_A, KBDM_CTRL},
  {Event::Delete,                   KBDK_DELETE},
  {Event::Delete,                   KBDK_KP_PERIOD},
  {Event::Delete,                   KBDK_D, KBDM_CTRL},
  {Event::DeleteLeftWord,           KBDK_BACKSPACE, KBDM_CTRL},
  {Event::DeleteLeftWord,           KBDK_W, KBDM_CTRL},
  {Event::DeleteRightWord,          KBDK_DELETE, KBDM_CTRL},
  {Event::DeleteRightWord,          KBDK_D, KBDM_ALT},
  {Event::DeleteHome,               KBDK_HOME, KBDM_CTRL},
  {Event::DeleteHome,               KBDK_U, KBDM_CTRL},
  {Event::DeleteEnd,                KBDK_END, KBDM_CTRL},
  {Event::DeleteEnd,                KBDK_K, KBDM_CTRL},
  {Event::Backspace,                KBDK_BACKSPACE},
  {Event::Undo,                     KBDK_Z, KBDM_CTRL},
  {Event::Undo,                     KBDK_BACKSPACE, KBDM_ALT},
  {Event::Redo,                     KBDK_Y, KBDM_CTRL},
  {Event::Redo,                     KBDK_Z, KBDM_SHIFT | KBDM_CTRL},
  {Event::Redo,                     KBDK_BACKSPACE, KBDM_SHIFT | KBDM_ALT},
  {Event::Cut,                      KBDK_X, KBDM_CTRL},
  {Event::Cut,                      KBDK_DELETE, KBDM_SHIFT},
  {Event::Cut,                      KBDK_KP_PERIOD, KBDM_SHIFT},
  {Event::Copy,                     KBDK_C, KBDM_CTRL},
  {Event::Copy,                     KBDK_INSERT, KBDM_CTRL},
  {Event::Paste,                    KBDK_V, KBDM_CTRL},
  {Event::Paste,                    KBDK_INSERT, KBDM_SHIFT},
#endif
  {Event::EndEdit,                  KBDK_RETURN},
  {Event::EndEdit,                  KBDK_KP_ENTER},
  {Event::AbortEdit,                KBDK_ESCAPE},
};
#endif  // GUI_SUPPORT

#ifdef DEBUGGER_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::FixedPromptMapping = {
  {Event::UINavNext,                KBDK_TAB},
  {Event::UINavPrev,                KBDK_TAB, KBDM_SHIFT},
  {Event::UIPgUp,                   KBDK_PAGEUP},
  {Event::UIPgUp,                   KBDK_PAGEUP, KBDM_SHIFT},
  {Event::UIPgDown,                 KBDK_PAGEDOWN},
  {Event::UIPgDown,                 KBDK_PAGEDOWN, KBDM_SHIFT},
  {Event::UIHome,                   KBDK_HOME, KBDM_SHIFT},
  {Event::UIEnd,                    KBDK_END, KBDM_SHIFT},
  {Event::UIUp,                     KBDK_UP, KBDM_SHIFT},
  {Event::UIDown,                   KBDK_DOWN, KBDM_SHIFT},
  {Event::UILeft,                   KBDK_DOWN},
  {Event::UIRight,                  KBDK_UP},
};
#endif // DEBUGGER_SUPPORT

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray PhysicalKeyboardHandler::DefaultJoystickMapping = {
  {Event::LeftJoystickUp,           KBDK_UP},
  {Event::LeftJoystickDown,         KBDK_DOWN},
  {Event::LeftJoystickLeft,         KBDK_LEFT},
  {Event::LeftJoystickRight,        KBDK_RIGHT},
  {Event::LeftJoystickUp,           KBDK_KP_8},
  {Event::LeftJoystickDown,         KBDK_KP_2},
  {Event::LeftJoystickLeft,         KBDK_KP_4},
  {Event::LeftJoystickRight,        KBDK_KP_6},
  {Event::LeftJoystickFire,         KBDK_SPACE},
  {Event::LeftJoystickFire,         KBDK_LCTRL},
  {Event::LeftJoystickFire,         KBDK_KP_5},
  {Event::LeftJoystickFire5,        KBDK_4},
  {Event::LeftJoystickFire5,        KBDK_RSHIFT},
  {Event::LeftJoystickFire5,        KBDK_KP_9},
  {Event::LeftJoystickFire9,        KBDK_5},
  {Event::LeftJoystickFire9,        KBDK_RCTRL},
  {Event::LeftJoystickFire9,        KBDK_KP_3},

  {Event::RightJoystickUp,          KBDK_Y},
  {Event::RightJoystickDown,        KBDK_H},
  {Event::RightJoystickLeft,        KBDK_G},
  {Event::RightJoystickRight,       KBDK_J},
  {Event::RightJoystickFire,        KBDK_F},
  {Event::RightJoystickFire5,       KBDK_6},
  {Event::RightJoystickFire9,       KBDK_7},

  // Same as Joysticks Zero & One + SHIFT
  {Event::QTJoystickThreeUp,        KBDK_UP, KBDM_SHIFT},
  {Event::QTJoystickThreeDown,      KBDK_DOWN, KBDM_SHIFT},
  {Event::QTJoystickThreeLeft,      KBDK_LEFT, KBDM_SHIFT},
  {Event::QTJoystickThreeRight,     KBDK_RIGHT, KBDM_SHIFT},
  {Event::QTJoystickThreeUp,        KBDK_KP_8, KBDM_SHIFT},
  {Event::QTJoystickThreeDown,      KBDK_KP_2, KBDM_SHIFT},
  {Event::QTJoystickThreeLeft,      KBDK_KP_4, KBDM_SHIFT},
  {Event::QTJoystickThreeRight,     KBDK_KP_6, KBDM_SHIFT},
  {Event::QTJoystickThreeFire,      KBDK_SPACE, KBDM_SHIFT},

  {Event::QTJoystickFourUp,         KBDK_Y, KBDM_SHIFT},
  {Event::QTJoystickFourDown,       KBDK_H, KBDM_SHIFT},
  {Event::QTJoystickFourLeft,       KBDK_G, KBDM_SHIFT},
  {Event::QTJoystickFourRight,      KBDK_J, KBDM_SHIFT},
  {Event::QTJoystickFourFire,       KBDK_F, KBDM_SHIFT},
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::DefaultPaddleMapping = {
  {Event::LeftPaddleADecrease,      KBDK_RIGHT},
  {Event::LeftPaddleAIncrease,      KBDK_LEFT},
  {Event::LeftPaddleAFire,          KBDK_SPACE},
  {Event::LeftPaddleAFire,          KBDK_LCTRL},
  {Event::LeftPaddleAFire,          KBDK_KP_5},

  {Event::LeftPaddleBDecrease,      KBDK_DOWN},
  {Event::LeftPaddleBIncrease,      KBDK_UP},
  {Event::LeftPaddleBFire,          KBDK_4},
  {Event::LeftPaddleBFire,          KBDK_RCTRL},

  {Event::RightPaddleADecrease,     KBDK_J},
  {Event::RightPaddleAIncrease,     KBDK_G},
  {Event::RightPaddleAFire,         KBDK_F},

  {Event::RightPaddleBDecrease,     KBDK_H},
  {Event::RightPaddleBIncrease,     KBDK_Y},
  {Event::RightPaddleBFire,         KBDK_6},

  // Same as Paddles Zero..Three Fire + SHIFT
  {Event::QTPaddle3AFire,           KBDK_SPACE, KBDM_SHIFT},
  {Event::QTPaddle3BFire,           KBDK_4, KBDM_SHIFT},
  {Event::QTPaddle4AFire,           KBDK_F, KBDM_SHIFT},
  {Event::QTPaddle4BFire,           KBDK_6, KBDM_SHIFT},
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::DefaultKeyboardMapping = {
  {Event::LeftKeyboard1,            KBDK_1},
  {Event::LeftKeyboard2,            KBDK_2},
  {Event::LeftKeyboard3,            KBDK_3},
  {Event::LeftKeyboard4,            KBDK_Q},
  {Event::LeftKeyboard5,            KBDK_W},
  {Event::LeftKeyboard6,            KBDK_E},
  {Event::LeftKeyboard7,            KBDK_A},
  {Event::LeftKeyboard8,            KBDK_S},
  {Event::LeftKeyboard9,            KBDK_D},
  {Event::LeftKeyboardStar,         KBDK_Z},
  {Event::LeftKeyboard0,            KBDK_X},
  {Event::LeftKeyboardPound,        KBDK_C},

  {Event::RightKeyboard1,           KBDK_8},
  {Event::RightKeyboard2,           KBDK_9},
  {Event::RightKeyboard3,           KBDK_0},
  {Event::RightKeyboard4,           KBDK_I},
  {Event::RightKeyboard5,           KBDK_O},
  {Event::RightKeyboard6,           KBDK_P},
  {Event::RightKeyboard7,           KBDK_K},
  {Event::RightKeyboard8,           KBDK_L},
  {Event::RightKeyboard9,           KBDK_SEMICOLON},
  {Event::RightKeyboardStar,        KBDK_COMMA},
  {Event::RightKeyboard0,           KBDK_PERIOD},
  {Event::RightKeyboardPound,       KBDK_SLASH},
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray PhysicalKeyboardHandler::DefaultDrivingMapping = {
  {Event::LeftDrivingCCW,          KBDK_LEFT},
  {Event::LeftDrivingCW,           KBDK_RIGHT},
  {Event::LeftDrivingCCW,          KBDK_KP_4},
  {Event::LeftDrivingCW,           KBDK_KP_6},
  {Event::LeftDrivingFire,         KBDK_SPACE},
  {Event::LeftDrivingFire,         KBDK_LCTRL},
  {Event::LeftDrivingFire,         KBDK_KP_5},

  {Event::RightDrivingCCW,         KBDK_G},
  {Event::RightDrivingCW,          KBDK_J},
  {Event::RightDrivingFire,        KBDK_F},
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PhysicalKeyboardHandler::EventMappingArray
PhysicalKeyboardHandler::CompuMateMapping = {
  {Event::CompuMateShift,         KBDK_LSHIFT},
  {Event::CompuMateShift,         KBDK_RSHIFT},
  {Event::CompuMateFunc,          KBDK_LCTRL},
  {Event::CompuMateFunc,          KBDK_RCTRL},
  {Event::CompuMate0,             KBDK_0},
  {Event::CompuMate1,             KBDK_1},
  {Event::CompuMate2,             KBDK_2},
  {Event::CompuMate3,             KBDK_3},
  {Event::CompuMate4,             KBDK_4},
  {Event::CompuMate5,             KBDK_5},
  {Event::CompuMate6,             KBDK_6},
  {Event::CompuMate7,             KBDK_7},
  {Event::CompuMate8,             KBDK_8},
  {Event::CompuMate9,             KBDK_9},
  {Event::CompuMateA,             KBDK_A},
  {Event::CompuMateB,             KBDK_B},
  {Event::CompuMateC,             KBDK_C},
  {Event::CompuMateD,             KBDK_D},
  {Event::CompuMateE,             KBDK_E},
  {Event::CompuMateF,             KBDK_F},
  {Event::CompuMateG,             KBDK_G},
  {Event::CompuMateH,             KBDK_H},
  {Event::CompuMateI,             KBDK_I},
  {Event::CompuMateJ,             KBDK_J},
  {Event::CompuMateK,             KBDK_K},
  {Event::CompuMateL,             KBDK_L},
  {Event::CompuMateM,             KBDK_M},
  {Event::CompuMateN,             KBDK_N},
  {Event::CompuMateO,             KBDK_O},
  {Event::CompuMateP,             KBDK_P},
  {Event::CompuMateQ,             KBDK_Q},
  {Event::CompuMateR,             KBDK_R},
  {Event::CompuMateS,             KBDK_S},
  {Event::CompuMateT,             KBDK_T},
  {Event::CompuMateU,             KBDK_U},
  {Event::CompuMateV,             KBDK_V},
  {Event::CompuMateW,             KBDK_W},
  {Event::CompuMateX,             KBDK_X},
  {Event::CompuMateY,             KBDK_Y},
  {Event::CompuMateZ,             KBDK_Z},
  {Event::CompuMateComma,         KBDK_COMMA},
  {Event::CompuMatePeriod,        KBDK_PERIOD},
  {Event::CompuMateEnter,         KBDK_RETURN},
  {Event::CompuMateEnter,         KBDK_KP_ENTER},
  {Event::CompuMateSpace,         KBDK_SPACE},
  // extra emulated keys
  {Event::CompuMateQuestion,      KBDK_SLASH, KBDM_SHIFT},
  {Event::CompuMateLeftBracket,   KBDK_LEFTBRACKET},
  {Event::CompuMateRightBracket,  KBDK_RIGHTBRACKET},
  {Event::CompuMateMinus,         KBDK_MINUS},
  {Event::CompuMateQuote,         KBDK_APOSTROPHE, KBDM_SHIFT},
#ifndef RETRON77
  {Event::CompuMateBackspace,     KBDK_BACKSPACE},
#endif
  {Event::CompuMateEquals,        KBDK_EQUALS},
  {Event::CompuMatePlus,          KBDK_EQUALS, KBDM_SHIFT},
  {Event::CompuMateSlash,         KBDK_SLASH}
};
