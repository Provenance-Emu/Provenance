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

#include <sstream>

#include "Logger.hxx"

#include "Base.hxx"
#include "Console.hxx"
#include "PaletteHandler.hxx"
#include "FrameBuffer.hxx"
#include "OSystem.hxx"
#include "Paddles.hxx"
#include "Lightgun.hxx"
#include "PointingDevice.hxx"
#include "Driving.hxx"
#include "PropsSet.hxx"
#include "Settings.hxx"
#include "Sound.hxx"
#include "StateManager.hxx"
#include "RewindManager.hxx"
#include "TimerManager.hxx"
#include "GlobalKeyHandler.hxx"
#ifdef GUI_SUPPORT
#include "HighScoresManager.hxx"
#endif
#include "Switches.hxx"
#include "M6532.hxx"
#include "MouseControl.hxx"
#include "PNGLibrary.hxx"
#include "TIASurface.hxx"

#include "EventHandler.hxx"

#ifdef CHEATCODE_SUPPORT
  #include "Cheat.hxx"
  #include "CheatManager.hxx"
#endif
#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
  #include "DebuggerParser.hxx"
#endif
#ifdef GUI_SUPPORT
  #include "OptionsMenu.hxx"
  #include "CommandMenu.hxx"
  #include "HighScoresMenu.hxx"
  #include "MessageMenu.hxx"
  #include "PlusRomsMenu.hxx"
  #include "DialogContainer.hxx"
  #include "Launcher.hxx"
  #include "TimeMachine.hxx"
  #include "FileListWidget.hxx"
  #include "ScrollBarWidget.hxx"
#endif

using namespace std::placeholders;
using json = nlohmann::json;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandler::EventHandler(OSystem& osystem)
  : myOSystem{osystem}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandler::~EventHandler()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::initialize()
{
  // Create global key handler (handles all global hot keys)
  myGlobalKeyHandler = make_unique<GlobalKeyHandler>(myOSystem);

  // Create keyboard handler (to handle all physical keyboard functionality)
  myPKeyHandler = make_unique<PhysicalKeyboardHandler>(myOSystem, *this);

  // Create joystick handler (to handle all physical joystick functionality)
  myPJoyHandler = make_unique<PhysicalJoystickHandler>(myOSystem, *this, myEvent);

  // Make sure the event/action mappings are correctly set,
  // and fill the ActionList structure with valid values
  setComboMap();
  setActionMappings(EventMode::kEmulationMode);
  setActionMappings(EventMode::kMenuMode);

  Controller::setDigitalDeadZone(myOSystem.settings().getInt("joydeadzone"));
  Controller::setAnalogDeadZone(myOSystem.settings().getInt("adeadzone"));
  Paddles::setAnalogLinearity(myOSystem.settings().getInt("plinear"));
  Paddles::setDejitterDiff(myOSystem.settings().getInt("dejitter.diff"));
  Paddles::setDejitterBase(myOSystem.settings().getInt("dejitter.base"));
  Paddles::setDejitterDiff(myOSystem.settings().getInt("dejitter.diff"));
  Paddles::setDigitalSensitivity(myOSystem.settings().getInt("dsense"));
  Controller::setMouseSensitivity(myOSystem.settings().getInt("msense"));
  PointingDevice::setSensitivity(myOSystem.settings().getInt("tsense"));
  Driving::setSensitivity(myOSystem.settings().getInt("dcsense"));
  Controller::setAutoFire(myOSystem.settings().getBool("autofire"));
  Controller::setAutoFireRate(myOSystem.settings().getInt("autofirerate"));

#ifdef GUI_SUPPORT
  // Set quick select delay when typing characters in listwidgets
  FileListWidget::setQuickSelectDelay(myOSystem.settings().getInt("listdelay"));

  // Set number of lines a mousewheel will scroll
  ScrollBarWidget::setWheelLines(myOSystem.settings().getInt("mwheel"));

  // Mouse double click
  DialogContainer::setDoubleClickDelay(myOSystem.settings().getInt("mdouble"));

  // Input delay
  DialogContainer::setControllerDelay(myOSystem.settings().getInt("inpDelay"));

  // Input rate
  DialogContainer::setControllerRate(myOSystem.settings().getInt("inpRate"));
#endif

  // Integer to string conversions (for HEX) use upper or lower-case
  Common::Base::setHexUppercase(myOSystem.settings().getBool("dbg.uhex"));

  // Default phosphor blend
  Properties::setDefault(PropType::Display_PPBlend,
                         myOSystem.settings().getString(PhosphorHandler::SETTING_BLEND));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::reset(EventHandlerState state)
{
  setState(state);
  myOSystem.state().reset();
#ifdef IMAGE_SUPPORT
  myOSystem.png().setContinuousSnapInterval(0);
#endif
  myFryingFlag = false;

  // Reset events almost immediately after starting emulation mode
  // We wait a little while (0.5s), since 'hold' events may be present,
  // and we want time for the ROM to process them
  if(state == EventHandlerState::EMULATION)
    myOSystem.timer().setTimeout([&ev = myEvent]() { ev.clear(); }, 500);
  // Toggle 7800 mode
  set7800Mode();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::addPhysicalJoystick(const PhysicalJoystickPtr& joy)
{
#ifdef JOYSTICK_SUPPORT
  if(myPJoyHandler->add(joy) < 0)
    return;

  setActionMappings(EventMode::kEmulationMode);
  setActionMappings(EventMode::kMenuMode);
#ifdef GUI_SUPPORT
  if(myOverlay)
    myOverlay->handleEvent(Event::UIReload);
#endif
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::removePhysicalJoystick(int id)
{
#ifdef JOYSTICK_SUPPORT
  myPJoyHandler->remove(id);

#ifdef GUI_SUPPORT
  if(myOverlay)
    myOverlay->handleEvent(Event::UIReload);
#endif
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::mapStelladaptors(string_view saport)
{
#ifdef JOYSTICK_SUPPORT
  myPJoyHandler->mapStelladaptors(saport);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::toggleAllow4JoyDirections(bool toggle)
{
  bool joyAllow4 = myOSystem.settings().getBool("joyallow4");

  if(toggle)
  {
    joyAllow4 = !joyAllow4;
    allowAllDirections(joyAllow4);
    myOSystem.settings().setValue("joyallow4", joyAllow4);
  }

  ostringstream ss;
  ss << "Allow all 4 joystick directions ";
  ss << (joyAllow4 ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(ss.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::toggleSAPortOrder(bool toggle)
{
#ifdef JOYSTICK_SUPPORT
  string saport = myOSystem.settings().getString("saport");

  if(toggle)
  {
    if(saport == "lr")
      saport = "rl";
    else
      saport = "lr";
    mapStelladaptors(saport);
  }

  if(saport == "lr")
    myOSystem.frameBuffer().showTextMessage("Stelladaptor ports left/right");
  else
    myOSystem.frameBuffer().showTextMessage("Stelladaptor ports right/left");
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::set7800Mode()
{
  if(myOSystem.hasConsole())
    myIs7800 = myOSystem.console().switches().check7800Mode(myOSystem.settings());
  else
    myIs7800 = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::toggleUIPalette()
{
  myOSystem.settings().setValue("altuipalette", !myOSystem.settings().getBool("altuipalette"));
  myOSystem.frameBuffer().setUIPalette();
  myOSystem.frameBuffer().update(FrameBuffer::UpdateMode::REDRAW);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::changeMouseControl(int direction)
{
  if(myMouseControl)
    myOSystem.frameBuffer().showTextMessage(myMouseControl->change(direction));
  else
    myOSystem.frameBuffer().showTextMessage("Mouse input is disabled");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventHandler::hasMouseControl() const
{
  return myMouseControl && myMouseControl->hasMouseControl();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::poll(uInt64 time)
{
  // Process events from the underlying hardware
  pollEvent();

  // Update controllers and console switches, and in general all other things
  // related to emulation
  if(myState == EventHandlerState::EMULATION)
  {
    myOSystem.console().riot().update();

    // Now check if the StateManager should be saving or loading state
    // (for rewind and/or movies
    if(myOSystem.state().mode() != StateManager::Mode::Off)
      myOSystem.state().update();

  #ifdef CHEATCODE_SUPPORT
    for(const auto& cheat: myOSystem.cheat().perFrame())
      cheat->evaluate();
  #endif

  #ifdef IMAGE_SUPPORT
    // Handle continuous snapshots
    if(myOSystem.png().continuousSnapEnabled())
      myOSystem.png().updateTime(time);
  #endif
  }
#ifdef GUI_SUPPORT
  else if(myOverlay)
  {
    // Update the current dialog container at regular intervals
    // Used to implement continuous events
    myOverlay->updateTime(time);
  }
#endif

  // Turn off all mouse-related items; if they haven't been taken care of
  // in the previous ::update() methods, they're now invalid
  myEvent.set(Event::MouseAxisXMove, 0);
  myEvent.set(Event::MouseAxisYMove, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::handleTextEvent(char text)
{
#ifdef GUI_SUPPORT
  // Text events are only used in GUI mode
  if(myOverlay)
    myOverlay->handleTextEvent(text);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::handleMouseMotionEvent(int x, int y, int xrel, int yrel)
{
  // Determine which mode we're in, then send the event to the appropriate place
  if(myState == EventHandlerState::EMULATION)
  {
    if(!mySkipMouseMotion)
    {
      myEvent.set(Event::MouseAxisXValue, x); // required for Lightgun controller
      myEvent.set(Event::MouseAxisYValue, y); // required for Lightgun controller
      myEvent.set(Event::MouseAxisXMove, xrel);
      myEvent.set(Event::MouseAxisYMove, yrel);
    }
    mySkipMouseMotion = false;
  }
#ifdef GUI_SUPPORT
  else if(myOverlay)
    myOverlay->handleMouseMotionEvent(x, y);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::handleMouseButtonEvent(MouseButton b, bool pressed,
                                          int x, int y)
{
  // Determine which mode we're in, then send the event to the appropriate place
  if(myState == EventHandlerState::EMULATION)
  {
    switch(b)
    {
      case MouseButton::LEFT:
        myEvent.set(Event::MouseButtonLeftValue, static_cast<int>(pressed));
        break;
      case MouseButton::RIGHT:
        myEvent.set(Event::MouseButtonRightValue, static_cast<int>(pressed));
        break;
      default:
        return;
    }
  }
#ifdef GUI_SUPPORT
  else if(myOverlay)
    myOverlay->handleMouseButtonEvent(b, pressed, x, y);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::handleSystemEvent(SystemEvent e, int, int)
{
  switch(e)
  {
    case SystemEvent::WINDOW_EXPOSED:
    case SystemEvent::WINDOW_RESIZED:
      // Force full render update
      myOSystem.frameBuffer().update(FrameBuffer::UpdateMode::RERENDER);
      break;
#if 0
    case SystemEvent::WINDOW_MINIMIZED:
      if(myState == EventHandlerState::EMULATION)
        enterMenuMode(EventHandlerState::OPTIONSMENU);
      break;
#endif

    case SystemEvent::WINDOW_FOCUS_GAINED:
  #ifdef BSPF_UNIX
      // Used to handle Alt-x key combos; sometimes the key associated with
      // Alt gets 'stuck'  and is passed to the core for processing
      if(myPKeyHandler->altKeyCount() > 0)
        myPKeyHandler->altKeyCount() = 2;
  #endif
      if(myOSystem.settings().getBool("autopause") && myState == EventHandlerState::PAUSE)
        setState(EventHandlerState::EMULATION);
      break;

    case SystemEvent::WINDOW_FOCUS_LOST:
      if(myOSystem.settings().getBool("autopause") && myState == EventHandlerState::EMULATION
          && myOSystem.launcherLostFocus())
        setState(EventHandlerState::PAUSE);
      break;

    default:  // handle other events as testing requires
      // cerr << "handleSystemEvent: " << e << '\n';
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// NOLINTNEXTLINE (readability-function-size)
void EventHandler::handleEvent(Event::Type event, Int32 value, bool repeated)
{
  // Take care of special events that aren't part of the emulation core
  // or need to be preprocessed before passing them on
  const bool pressed = (value != 0);

  // Abort if global keys are pressed
  if(myGlobalKeyHandler->handleEvent(event, pressed, repeated))
    return;

  switch(event)
  {
    ////////////////////////////////////////////////////////////////////////
    // If enabled, make sure 'impossible' joystick directions aren't allowed
    case Event::LeftJoystickUp:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::LeftJoystickDown, 0);
      break;

    case Event::LeftJoystickDown:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::LeftJoystickUp, 0);
      break;

    case Event::LeftJoystickLeft:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::LeftJoystickRight, 0);
      break;

    case Event::LeftJoystickRight:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::LeftJoystickLeft, 0);
      break;

    case Event::RightJoystickUp:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::RightJoystickDown, 0);
      break;

    case Event::RightJoystickDown:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::RightJoystickUp, 0);
      break;

    case Event::RightJoystickLeft:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::RightJoystickRight, 0);
      break;

    case Event::RightJoystickRight:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::RightJoystickLeft, 0);
      break;

    case Event::QTJoystickThreeUp:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickThreeDown, 0);
      break;

    case Event::QTJoystickThreeDown:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickThreeUp, 0);
      break;

    case Event::QTJoystickThreeLeft:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickThreeRight, 0);
      break;

    case Event::QTJoystickThreeRight:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickThreeLeft, 0);
      break;

    case Event::QTJoystickFourUp:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickFourDown, 0);
      break;

    case Event::QTJoystickFourDown:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickFourUp, 0);
      break;

    case Event::QTJoystickFourLeft:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickFourRight, 0);
      break;

    case Event::QTJoystickFourRight:
      if(!myAllowAllDirectionsFlag && pressed)
        myEvent.set(Event::QTJoystickFourLeft, 0);
      break;

    ///////////////////////////////////////////////////////////////////////////
    // Audio & Video events (with global hotkeys)
    case Event::VolumeDecrease:
      if(pressed)
      {
        myOSystem.sound().adjustVolume(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VOLUME);
      }
      return;

    case Event::VolumeIncrease:
      if(pressed)
      {
        myOSystem.sound().adjustVolume(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VOLUME);
      }
      return;

    case Event::SoundToggle:
      if(pressed && !repeated)
      {
        myOSystem.sound().toggleMute();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VOLUME);
      }
      return;

    case Event::VidmodeDecrease:
      if(pressed)
      {
        myOSystem.frameBuffer().switchVideoMode(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ZOOM);
      }
      return;

    case Event::VidmodeIncrease:
      if(pressed)
      {
        myOSystem.frameBuffer().switchVideoMode(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ZOOM);
      }
      return;

    case Event::ToggleUIPalette:
      if(pressed && !repeated)
      {
        toggleUIPalette();
      }
      break;

    case Event::ToggleFullScreen:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().toggleFullscreen();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::FULLSCREEN);
      }
      return;

    #ifdef ADAPTABLE_REFRESH_SUPPORT
    case Event::ToggleAdaptRefresh:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().toggleAdaptRefresh();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ADAPT_REFRESH);
      }
      return;
    #endif

    case Event::OverscanDecrease:
      if(pressed)
      {
        myOSystem.frameBuffer().changeOverscan(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::OVERSCAN);
      }
      return;

    case Event::OverscanIncrease:
      if(pressed)
      {
        myOSystem.frameBuffer().changeOverscan(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::OVERSCAN);
      }
      return;

    case Event::FormatDecrease:
      if(pressed && !repeated)
      {
        myOSystem.console().selectFormat(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::TVFORMAT);
      }
      return;

    case Event::FormatIncrease:
      if(pressed && !repeated)
      {
        myOSystem.console().selectFormat(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::TVFORMAT);
      }
      return;

    case Event::VCenterDecrease:
      if(pressed)
      {
        myOSystem.console().changeVerticalCenter(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VCENTER);
      }
      return;

    case Event::VCenterIncrease:
      if(pressed)
      {
        myOSystem.console().changeVerticalCenter(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VCENTER);
      }
      return;
    case Event::VSizeAdjustDecrease:
      if(pressed)
      {
        myOSystem.console().changeVSizeAdjust(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VSIZE);
      }
      return;

    case Event::VSizeAdjustIncrease:
      if(pressed)
      {
        myOSystem.console().changeVSizeAdjust(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::VSIZE);
      }
      return;

    case Event::ToggleCorrectAspectRatio:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleCorrectAspectRatio();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ASPECT_RATIO);
      }
      break;

    case Event::PaletteDecrease:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().paletteHandler().cyclePalette(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PALETTE);
      }
      return;

    case Event::PaletteIncrease:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().paletteHandler().cyclePalette(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PALETTE);
      }
      return;

    case Event::PreviousVideoMode:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().changeNTSC(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::NextVideoMode:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().changeNTSC(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::VidmodeStd:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSC(NTSCFilter::Preset::OFF);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::VidmodeRGB:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSC(NTSCFilter::Preset::RGB);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::VidmodeSVideo:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSC(NTSCFilter::Preset::SVIDEO);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::VidModeComposite:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSC(NTSCFilter::Preset::COMPOSITE);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::VidModeBad:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSC(NTSCFilter::Preset::BAD);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;

    case Event::VidModeCustom:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSC(NTSCFilter::Preset::CUSTOM);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::NTSC_PRESET);
      }
      return;
    case Event::PhosphorDecrease:
      if(pressed)
      {
        myOSystem.console().changePhosphor(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PHOSPHOR);
      }
      return;

    case Event::PhosphorIncrease:
      if(pressed)
      {
        myOSystem.console().changePhosphor(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PHOSPHOR);
      }
      return;

    case Event::TogglePhosphor:
      if(pressed && !repeated)
      {
        myOSystem.console().togglePhosphor();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PHOSPHOR);
      }
      return;

    case Event::PhosphorModeDecrease:
      if(pressed && !repeated)
      {
        myOSystem.console().cyclePhosphorMode(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PHOSPHOR_MODE);
      }
      return;

    case Event::PhosphorModeIncrease:
      if(pressed && !repeated)
      {
        myOSystem.console().cyclePhosphorMode(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PHOSPHOR_MODE);
      }
      return;

    case Event::ScanlinesDecrease:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().changeScanlineIntensity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SCANLINES);
      }
      return;

    case Event::ScanlinesIncrease:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().changeScanlineIntensity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SCANLINES);
      }
      return;

    case Event::PreviousScanlineMask:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().cycleScanlineMask(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SCANLINE_MASK);
      }
      return;

    case Event::NextScanlineMask:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().tiaSurface().cycleScanlineMask(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SCANLINE_MASK);
      }
      return;

    case Event::ToggleInter:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleInter();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::INTERPOLATION);
      }
      return;

      ///////////////////////////////////////////////////////////////////////////
      // Direct key Audio & Video events
    case Event::PreviousPaletteAttribute:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().paletteHandler().cycleAdjustable(-1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::PALETTE_ATTRIBUTE);
      }
      return;

    case Event::NextPaletteAttribute:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().paletteHandler().cycleAdjustable(+1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::PALETTE_ATTRIBUTE);
      }
      return;

    case Event::PaletteAttributeDecrease:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().paletteHandler().changeCurrentAdjustable(-1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::PALETTE_ATTRIBUTE);
      }
      return;

    case Event::PaletteAttributeIncrease:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().paletteHandler().changeCurrentAdjustable(+1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::PALETTE_ATTRIBUTE);
      }
      return;

    case Event::PreviousAttribute:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSCAdjustable(-1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::NTSC_ATTRIBUTE);
      }
      return;

    case Event::NextAttribute:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().setNTSCAdjustable(+1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::NTSC_ATTRIBUTE);
      }
      return;

    case Event::DecreaseAttribute:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().changeCurrentNTSCAdjustable(-1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::NTSC_ATTRIBUTE);
      }
      return;

    case Event::IncreaseAttribute:
      if(pressed)
      {
        myOSystem.frameBuffer().tiaSurface().changeCurrentNTSCAdjustable(+1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::NTSC_ATTRIBUTE);
      }
      return;

    ///////////////////////////////////////////////////////////////////////////
    // Debug events (with global hotkeys)
    case Event::ToggleFrameStats:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().toggleFrameStats();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::STATS);
      }
      return;

    case Event::ToggleP0Collision:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleP0Collision();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::P0_CX);
      }
      return;

    case Event::ToggleP0Bit:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleP0Bit();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::P0_ENAM);
      }
      return;

    case Event::ToggleP1Collision:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleP1Collision();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::P1_CX);
      }
      return;

    case Event::ToggleP1Bit:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleP1Bit();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::P1_ENAM);
      }
      return;

    case Event::ToggleM0Collision:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleM0Collision();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::M0_CX);
      }
      return;

    case Event::ToggleM0Bit:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleM0Bit();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::M0_ENAM);
      }
      return;

    case Event::ToggleM1Collision:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleM1Collision();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::M1_CX);
      }
      return;

    case Event::ToggleM1Bit:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleM1Bit();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::M1_ENAM);
      }
      return;

    case Event::ToggleBLCollision:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleBLCollision();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::BL_CX);
      }
      return;

    case Event::ToggleBLBit:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleBLBit();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::BL_ENAM);
      }
      return;

    case Event::TogglePFCollision:
      if(pressed && !repeated)
      {
        myOSystem.console().togglePFCollision();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PF_CX);
      }
      return;

    case Event::TogglePFBit:
      if(pressed && !repeated)
      {
        myOSystem.console().togglePFBit();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PF_ENAM);
      }
      return;

    case Event::ToggleCollisions:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleCollisions();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ALL_CX);
      }
      return;

    case Event::ToggleBits:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleBits();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ALL_ENAM);
      }
      return;

    case Event::ToggleFixedColors:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleFixedColors();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::FIXED_COL);
      }
      return;

    case Event::ToggleColorLoss:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleColorLoss();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::COLOR_LOSS);
      }
      return;

    case Event::ToggleDeveloperSet:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleDeveloperSet();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DEVELOPER);
      }
      break;

    case Event::ToggleJitter:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleJitter();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::JITTER_SENSE);
      }
      return;

    case Event::JitterSenseDecrease:
      if(pressed)
      {
        myOSystem.console().changeJitterSense(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::JITTER_SENSE);
      }
      return;

    case Event::JitterSenseIncrease:
      if(pressed)
      {
        myOSystem.console().changeJitterSense(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::JITTER_SENSE);
      }
      return;

    case Event::JitterRecDecrease:
      if(pressed)
      {
        myOSystem.console().changeJitterRecovery(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::JITTER_REC);
      }
      return;

    case Event::JitterRecIncrease:
      if(pressed)
      {
        myOSystem.console().changeJitterRecovery(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::JITTER_REC);
      }
      return;

    ///////////////////////////////////////////////////////////////////////////
    // Input events
    case Event::DecreaseDeadzone:
      if(pressed)
      {
        myPJoyHandler->changeDigitalDeadZone(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DIGITAL_DEADZONE);
      }
      return;

    case Event::IncreaseDeadzone:
      if(pressed)
      {
        myPJoyHandler->changeDigitalDeadZone(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DIGITAL_DEADZONE);
      }
      return;

    case Event::DecAnalogDeadzone:
      if(pressed)
      {
        myPJoyHandler->changeAnalogPaddleDeadZone(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ANALOG_DEADZONE);
      }
      return;

    case Event::IncAnalogDeadzone:
      if(pressed)
      {
        myPJoyHandler->changeAnalogPaddleDeadZone(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ANALOG_DEADZONE);
      }
      return;

    case Event::DecAnalogSense:
      if(pressed)
      {
        myPJoyHandler->changeAnalogPaddleSensitivity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ANALOG_SENSITIVITY);
      }
      return;

    case Event::IncAnalogSense:
      if(pressed)
      {
        myPJoyHandler->changeAnalogPaddleSensitivity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ANALOG_SENSITIVITY);
      }
      return;

    case Event::DecAnalogLinear:
      if(pressed)
      {
        myPJoyHandler->changeAnalogPaddleLinearity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ANALOG_LINEARITY);
      }
      return;

    case Event::IncAnalogLinear:
      if(pressed)
      {
        myPJoyHandler->changeAnalogPaddleLinearity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::ANALOG_LINEARITY);
      }
      return;

    case Event::DecDejtterAveraging:
      if(pressed)
      {
        myPJoyHandler->changePaddleDejitterAveraging(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DEJITTER_AVERAGING);
      }
      return;

    case Event::IncDejtterAveraging:
      if(pressed)
      {
        myPJoyHandler->changePaddleDejitterAveraging(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DEJITTER_AVERAGING);
      }
      return;

    case Event::DecDejtterReaction:
      if(pressed)
      {
        myPJoyHandler->changePaddleDejitterReaction(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DEJITTER_REACTION);
      }
      return;

    case Event::IncDejtterReaction:
      if(pressed)
      {
        myPJoyHandler->changePaddleDejitterReaction(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DEJITTER_REACTION);
      }
      return;

    case Event::DecDigitalSense:
      if(pressed)
      {
        myPJoyHandler->changeDigitalPaddleSensitivity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DIGITAL_SENSITIVITY);
      }
      return;

    case Event::IncDigitalSense:
      if(pressed)
      {
        myPJoyHandler->changeDigitalPaddleSensitivity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DIGITAL_SENSITIVITY);
      }
      return;

    case Event::ToggleAutoFire:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleAutoFire();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::AUTO_FIRE);
      }
      return;

    case Event::DecreaseAutoFire:
      if(pressed)
      {
        myOSystem.console().changeAutoFireRate(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::AUTO_FIRE);
      }
      return;

    case Event::IncreaseAutoFire:
      if(pressed)
      {
        myOSystem.console().changeAutoFireRate(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::AUTO_FIRE);
      }
      return;

    case Event::ToggleFourDirections:
      if(pressed && !repeated)
      {
        toggleAllow4JoyDirections();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::FOUR_DIRECTIONS);
      }
      return;

    case Event::ToggleKeyCombos:
      if(pressed && !repeated)
      {
        myPKeyHandler->toggleModKeys();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::MOD_KEY_COMBOS);
      }
      return;

    case Event::ToggleSAPortOrder:
      if(pressed && !repeated)
      {
        toggleSAPortOrder();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SA_PORT_ORDER);
      }
      return;

    case Event::PrevMouseAsController:
      if(pressed && !repeated)
      {
        changeMouseControllerMode(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::USE_MOUSE);
      }
      return;

    case Event::NextMouseAsController:
      if(pressed && !repeated)
      {
        changeMouseControllerMode(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::USE_MOUSE);
      }
      return;

    case Event::DecMousePaddleSense:
      if(pressed)
      {
        myPJoyHandler->changeMousePaddleSensitivity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PADDLE_SENSITIVITY);
      }
      return;

    case Event::IncMousePaddleSense:
      if(pressed)
      {
        myPJoyHandler->changeMousePaddleSensitivity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PADDLE_SENSITIVITY);
      }
      return;

    case Event::DecMouseTrackballSense:
      if(pressed)
      {
        myPJoyHandler->changeMouseTrackballSensitivity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::TRACKBALL_SENSITIVITY);
      }
      return;

    case Event::IncMouseTrackballSense:
      if(pressed)
      {
        myPJoyHandler->changeMouseTrackballSensitivity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::TRACKBALL_SENSITIVITY);
      }
      return;

    case Event::DecreaseDrivingSense:
      if(pressed)
      {
        myPJoyHandler->changeDrivingSensitivity(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DRIVING_SENSITIVITY);
      }
      return;

    case Event::IncreaseDrivingSense:
      if(pressed)
      {
        myPJoyHandler->changeDrivingSensitivity(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::DRIVING_SENSITIVITY);
      }
      return;

    case Event::PreviousCursorVisbility:
      if(pressed && !repeated)
      {
        changeMouseCursor(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::MOUSE_CURSOR);
      }
      return;

    case Event::NextCursorVisbility:
      if(pressed && !repeated)
      {
        changeMouseCursor(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::MOUSE_CURSOR);
      }
      return;

    case Event::ToggleGrabMouse:
      if(pressed && !repeated && !myOSystem.frameBuffer().fullScreen())
      {
        myOSystem.frameBuffer().toggleGrabMouse();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::GRAB_MOUSE);
      }
      return;

    case Event::PreviousLeftPort:
      if(pressed && !repeated)
      {
        myOSystem.console().changeLeftController(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::LEFT_PORT);
      }
      return;

    case Event::NextLeftPort:
      if(pressed && !repeated)
      {
        myOSystem.console().changeLeftController(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::LEFT_PORT);
      }

      return;

    case Event::PreviousRightPort:
      if(pressed && !repeated)
      {
        myOSystem.console().changeRightController(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::RIGHT_PORT);
      }
      return;

    case Event::NextRightPort:
      if(pressed && !repeated)
      {
        myOSystem.console().changeRightController(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::RIGHT_PORT);
      }
      return;

    case Event::ToggleSwapPorts:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleSwapPorts();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SWAP_PORTS);
      }
      return;

    case Event::ToggleSwapPaddles:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleSwapPaddles();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::SWAP_PADDLES);
      }
      return;

    case Event::DecreasePaddleCenterX:
      if(pressed)
      {
        myOSystem.console().changePaddleCenterX(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PADDLE_CENTER_X);
      }
      return;

    case Event::IncreasePaddleCenterX:
      if(pressed)
      {
        myOSystem.console().changePaddleCenterX(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PADDLE_CENTER_X);
      }
      return;

    case Event::DecreasePaddleCenterY:
      if(pressed)
      {
        myOSystem.console().changePaddleCenterY(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PADDLE_CENTER_Y);
      }
      return;

    case Event::IncreasePaddleCenterY:
      if(pressed)
      {
        myOSystem.console().changePaddleCenterY(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::PADDLE_CENTER_Y);
      }
      return;

    case Event::PreviousMouseControl:
      if(pressed && !repeated)
      {
        changeMouseControl(-1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::MOUSE_CONTROL);
      }
      return;

    case Event::NextMouseControl:
      if(pressed && !repeated)
      {
        changeMouseControl(+1);
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::MOUSE_CONTROL);
      }
      return;

    ///////////////////////////////////////////////////////////////////////////
    // State events
    case Event::SaveState:
      if(pressed && !repeated)
      {
        myOSystem.state().saveState();
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::SaveAllStates:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().showTextMessage(myOSystem.state().rewindManager().saveAllStates());
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::PreviousState:
      if(pressed)
      {
        myOSystem.state().changeState(-1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::NextState:
      if(pressed)
      {
        myOSystem.state().changeState(+1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::ToggleAutoSlot:
      if(pressed && !repeated)
      {
        myOSystem.state().toggleAutoSlot();
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::LoadState:
      if(pressed && !repeated)
      {
        myOSystem.state().loadState();
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::LoadAllStates:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().showTextMessage(myOSystem.state().rewindManager().loadAllStates());
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::STATE);
      }
      return;

    case Event::RewindPause:
      if(pressed) myOSystem.state().rewindStates();
      if (myState == EventHandlerState::EMULATION)
        setState(EventHandlerState::PAUSE);
      return;

    case Event::UnwindPause:
      if(pressed) myOSystem.state().unwindStates();
      if (myState == EventHandlerState::EMULATION)
        setState(EventHandlerState::PAUSE);
      return;

    case Event::Rewind1Menu:
      if(pressed) enterTimeMachineMenuMode(1, false);
      return;

    case Event::Rewind10Menu:
      if(pressed) enterTimeMachineMenuMode(10, false);
      return;

    case Event::RewindAllMenu:
      if(pressed) enterTimeMachineMenuMode(1000, false);
      return;

    case Event::Unwind1Menu:
      if(pressed) enterTimeMachineMenuMode(1, true);
      return;

    case Event::Unwind10Menu:
      if(pressed) enterTimeMachineMenuMode(10, true);
      return;

    case Event::UnwindAllMenu:
      if(pressed) enterTimeMachineMenuMode(1000, true);
      return;

    ///////////////////////////////////////////////////////////////////////////
    // Misc events
    case Event::DecreaseSpeed:
      if(pressed)
      {
        myOSystem.console().changeSpeed(-1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::CHANGE_SPEED);
      }
      return;

    case Event::IncreaseSpeed:
      if(pressed)
      {
        myOSystem.console().changeSpeed(+1);
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::CHANGE_SPEED);
      }
      return;

    case Event::ToggleTurbo:
      if(pressed && !repeated)
      {
        myOSystem.console().toggleTurbo();
        myGlobalKeyHandler->setDirectSetting(GlobalKeyHandler::Setting::CHANGE_SPEED);
      }
      return;

    case Event::Fry:
      if(!repeated) myFryingFlag = pressed;
      return;

    case Event::ReloadConsole:
      if(pressed && !repeated) myOSystem.reloadConsole(true);
      return;

    case Event::PreviousMultiCartRom:
      if(pressed && !repeated) myOSystem.reloadConsole(false);
      return;

    case Event::ToggleTimeMachine:
      if(pressed && !repeated) myOSystem.toggleTimeMachine();
      return;

    case Event::ToggleBezel:
      if(pressed && !repeated)
      {
        myOSystem.frameBuffer().toggleBezel();
        myGlobalKeyHandler->setSetting(GlobalKeyHandler::Setting::BEZEL);
      }
      return;

  #ifdef IMAGE_SUPPORT
    case Event::ToggleContSnapshots:
      if(pressed && !repeated) myOSystem.png().toggleContinuousSnapshots(false);
      return;

    case Event::ToggleContSnapshotsFrame:
      if(pressed && !repeated) myOSystem.png().toggleContinuousSnapshots(true);
      return;
  #endif

    case Event::TakeSnapshot:
      if(pressed && !repeated) myOSystem.frameBuffer().tiaSurface().saveSnapShot();
      return;

    case Event::ExitMode:
      // Special handling for Escape key
      // Basically, exit whichever mode we're currently in
      switch(myState)
      {
        case EventHandlerState::PAUSE:
          if(pressed && !repeated) changeStateByEvent(Event::TogglePauseMode);
          return;

        case EventHandlerState::CMDMENU:
          if(pressed && !repeated) changeStateByEvent(Event::CmdMenuMode);
          return;

        case EventHandlerState::TIMEMACHINE:
          if(pressed && !repeated) changeStateByEvent(Event::TimeMachineMode);
          return;

        case EventHandlerState::PLAYBACK:
          if(pressed && !repeated) changeStateByEvent(Event::TogglePlayBackMode);
          return;

        case EventHandlerState::EMULATION:
          if(pressed && !repeated)
          {
#ifdef GUI_SUPPORT
            if (myOSystem.settings().getBool("confirmexit"))
            {
              StringList msg;
              const string saveOnExit = myOSystem.settings().getString("saveonexit");
              const bool activeTM = myOSystem.settings().getBool(
                myOSystem.settings().getBool("dev.settings") ? "dev.timemachine" : "plr.timemachine");


              msg.emplace_back("Do you really want to exit emulation?");
              if (saveOnExit != "all" || !activeTM)
              {
                msg.emplace_back("");
                msg.emplace_back("You will lose all your progress.");
              }
              MessageMenu::setMessage("Exit Emulation", msg, true);
              enterMenuMode(EventHandlerState::MESSAGEMENU);
            }
            else
#endif
              exitEmulation(true);

          }
          return;

#ifdef GUI_SUPPORT
        case EventHandlerState::MESSAGEMENU:
          if(pressed && !repeated)
          {
            leaveMenuMode();
            if (myOSystem.messageMenu().confirmed())
              exitEmulation(true);
          }
          return;
#endif
        default:
          return;
      }

    case Event::ExitGame:
      exitEmulation(true);
      return;

    case Event::Quit:
      if(pressed && !repeated)
      {
        saveKeyMapping();
        saveJoyMapping();
        if (myState != EventHandlerState::LAUNCHER)
          exitEmulation();
        else
          exitLauncher();
        myOSystem.quit();
      }
      return;

    case Event::StartPauseMode:
      if(pressed && !repeated && myState == EventHandlerState::EMULATION)
        setState(EventHandlerState::PAUSE);
      return;

    ////////////////////////////////////////////////////////////////////////
    // A combo event is simply multiple calls to handleEvent, once for
    // each event it contains
    case Event::Combo1:
    case Event::Combo2:
    case Event::Combo3:
    case Event::Combo4:
    case Event::Combo5:
    case Event::Combo6:
    case Event::Combo7:
    case Event::Combo8:
    case Event::Combo9:
    case Event::Combo10:
    case Event::Combo11:
    case Event::Combo12:
    case Event::Combo13:
    case Event::Combo14:
    case Event::Combo15:
    case Event::Combo16:
    {
      const int combo = event - Event::Combo1;
      for(int i = 0; i < EVENTS_PER_COMBO; ++i)
        if(myComboTable[combo][i] != Event::NoType)
          handleEvent(myComboTable[combo][i], pressed, repeated);
      return;
    }

    ////////////////////////////////////////////////////////////////////////
    // Events which relate to switches()
    case Event::ConsoleColor:
      if(pressed && !repeated)
      {
        myEvent.set(Event::ConsoleBlackWhite, 0);
        myEvent.set(Event::ConsoleColor, 1);
        myOSystem.frameBuffer().showTextMessage(myIs7800 ? "Pause released" : "Color Mode");
        myOSystem.console().switches().update();
      }
      return;
    case Event::ConsoleBlackWhite:
      if(pressed && !repeated)
      {
        myEvent.set(Event::ConsoleBlackWhite, 1);
        myEvent.set(Event::ConsoleColor, 0);
        myOSystem.frameBuffer().showTextMessage(myIs7800 ? "Pause pushed" : "B/W Mode");
        myOSystem.console().switches().update();
      }
      return;
    case Event::ConsoleColorToggle:
      if(pressed && !repeated)
      {
        if(myOSystem.console().switches().tvColor())
        {
          myEvent.set(Event::ConsoleBlackWhite, 1);
          myEvent.set(Event::ConsoleColor, 0);
          myOSystem.frameBuffer().showTextMessage(myIs7800 ? "Pause pushed" : "B/W Mode");
        }
        else
        {
          myEvent.set(Event::ConsoleBlackWhite, 0);
          myEvent.set(Event::ConsoleColor, 1);
          myOSystem.frameBuffer().showTextMessage(myIs7800 ? "Pause released" : "Color Mode");
        }
        myOSystem.console().switches().update();
      }
      return;
    case Event::Console7800Pause: // only works in 7800 mode
      if(myIs7800 && !repeated)
      {
        // Press and release pause button
        if(pressed)
          myOSystem.frameBuffer().showTextMessage("Pause pressed");
        myEvent.set(Event::Console7800Pause, pressed);
        myOSystem.console().switches().update();
      }
      return;

    case Event::ConsoleLeftDiffA:
      if(pressed && !repeated)
      {
        myEvent.set(Event::ConsoleLeftDiffA, 1);
        myEvent.set(Event::ConsoleLeftDiffB, 0);
        myOSystem.frameBuffer().showTextMessage(GUI::LEFT_DIFFICULTY + " A");
        myOSystem.console().switches().update();
      }
      return;
    case Event::ConsoleLeftDiffB:
      if(pressed && !repeated)
      {
        myEvent.set(Event::ConsoleLeftDiffA, 0);
        myEvent.set(Event::ConsoleLeftDiffB, 1);
        myOSystem.frameBuffer().showTextMessage(GUI::LEFT_DIFFICULTY + " B");
        myOSystem.console().switches().update();
      }
      return;
    case Event::ConsoleLeftDiffToggle:
      if(pressed && !repeated)
      {
        if(myOSystem.console().switches().leftDifficultyA())
        {
          myEvent.set(Event::ConsoleLeftDiffA, 0);
          myEvent.set(Event::ConsoleLeftDiffB, 1);
          myOSystem.frameBuffer().showTextMessage(GUI::LEFT_DIFFICULTY + " B");
        }
        else
        {
          myEvent.set(Event::ConsoleLeftDiffA, 1);
          myEvent.set(Event::ConsoleLeftDiffB, 0);
          myOSystem.frameBuffer().showTextMessage(GUI::LEFT_DIFFICULTY + " A");
        }
        myOSystem.console().switches().update();
      }
      return;

    case Event::ConsoleRightDiffA:
      if(pressed && !repeated)
      {
        myEvent.set(Event::ConsoleRightDiffA, 1);
        myEvent.set(Event::ConsoleRightDiffB, 0);
        myOSystem.frameBuffer().showTextMessage(GUI::RIGHT_DIFFICULTY + " A");
        myOSystem.console().switches().update();
      }
      return;
    case Event::ConsoleRightDiffB:
      if(pressed && !repeated)
      {
        myEvent.set(Event::ConsoleRightDiffA, 0);
        myEvent.set(Event::ConsoleRightDiffB, 1);
        myOSystem.frameBuffer().showTextMessage(GUI::RIGHT_DIFFICULTY + " B");
        myOSystem.console().switches().update();
      }
      return;
    case Event::ConsoleRightDiffToggle:
      if(pressed && !repeated)
      {
        if(myOSystem.console().switches().rightDifficultyA())
        {
          myEvent.set(Event::ConsoleRightDiffA, 0);
          myEvent.set(Event::ConsoleRightDiffB, 1);
          myOSystem.frameBuffer().showTextMessage(GUI::RIGHT_DIFFICULTY + " B");
        }
        else
        {
          myEvent.set(Event::ConsoleRightDiffA, 1);
          myEvent.set(Event::ConsoleRightDiffB, 0);
          myOSystem.frameBuffer().showTextMessage(GUI::RIGHT_DIFFICULTY + " A");
        }
        myOSystem.console().switches().update();
      }
      return;

    ////////////////////////////////////////////////////////////////////////
    case Event::NoType:  // Ignore unmapped events
      return;

    default:
      break;
  }

  // Otherwise, pass it to the emulation core
  if(!repeated)
    myEvent.set(event, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::handleConsoleStartupEvents()
{
  if(myOSystem.settings().getBool("holdreset"))
    handleEvent(Event::ConsoleReset);

  if(myOSystem.settings().getBool("holdselect"))
    handleEvent(Event::ConsoleSelect);

  const string_view holdjoy0 = myOSystem.settings().getString("holdjoy0");

  if(BSPF::containsIgnoreCase(holdjoy0, "U"))
    handleEvent(Event::LeftJoystickUp);
  if(BSPF::containsIgnoreCase(holdjoy0, "D"))
    handleEvent(Event::LeftJoystickDown);
  if(BSPF::containsIgnoreCase(holdjoy0, "L"))
    handleEvent(Event::LeftJoystickLeft);
  if(BSPF::containsIgnoreCase(holdjoy0, "R"))
    handleEvent(Event::LeftJoystickRight);
  if(BSPF::containsIgnoreCase(holdjoy0, "F"))
    handleEvent(Event::LeftJoystickFire);

  const string_view holdjoy1 = myOSystem.settings().getString("holdjoy1");
  if(BSPF::containsIgnoreCase(holdjoy1, "U"))
    handleEvent(Event::RightJoystickUp);
  if(BSPF::containsIgnoreCase(holdjoy1, "D"))
    handleEvent(Event::RightJoystickDown);
  if(BSPF::containsIgnoreCase(holdjoy1, "L"))
    handleEvent(Event::RightJoystickLeft);
  if(BSPF::containsIgnoreCase(holdjoy1, "R"))
    handleEvent(Event::RightJoystickRight);
  if(BSPF::containsIgnoreCase(holdjoy1, "F"))
    handleEvent(Event::RightJoystickFire);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventHandler::changeStateByEvent(Event::Type type)
{
  bool handled = true;

  switch(type)
  {
    case Event::TogglePauseMode:
      if(myState == EventHandlerState::EMULATION || myState == EventHandlerState::PLAYBACK)
        setState(EventHandlerState::PAUSE);
      else if(myState == EventHandlerState::PAUSE)
        setState(EventHandlerState::EMULATION);
      else
        handled = false;
      break;

    case Event::OptionsMenuMode:
      if (myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
          || myState == EventHandlerState::TIMEMACHINE || myState == EventHandlerState::PLAYBACK)
        enterMenuMode(EventHandlerState::OPTIONSMENU);
      else
        handled = false;
      break;

    case Event::CmdMenuMode:
      if(myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
         || myState == EventHandlerState::TIMEMACHINE || myState == EventHandlerState::PLAYBACK)
        enterMenuMode(EventHandlerState::CMDMENU);
      else if(myState == EventHandlerState::CMDMENU && !myOSystem.settings().getBool("minimal_ui"))
        // The extra check for "minimal_ui" allows mapping e.g. right joystick fire
        //  to open the command dialog and navigate there using that fire button
        leaveMenuMode();
      else
        handled = false;
      break;

#ifdef GUI_SUPPORT
    case Event::HighScoresMenuMode:
      if (myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
          || myState == EventHandlerState::TIMEMACHINE)
      {
        if (myOSystem.highScores().enabled())
          enterMenuMode(EventHandlerState::HIGHSCORESMENU);
        else
          myOSystem.frameBuffer().showTextMessage("No high scores data defined");
      }
      else if(myState == EventHandlerState::HIGHSCORESMENU)
        leaveMenuMode();
      else
        handled = false;
      break;

    case Event::PlusRomsSetupMode:
      if(myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
          || myState == EventHandlerState::TIMEMACHINE || myState == EventHandlerState::PLAYBACK)
        enterMenuMode(EventHandlerState::PLUSROMSMENU);
      else if(myState == EventHandlerState::PLUSROMSMENU)
        leaveMenuMode();
      else
        handled = false;
      break;

#endif // GUI_SUPPORT

    case Event::TimeMachineMode:
      if(myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
         || myState == EventHandlerState::PLAYBACK)
        enterTimeMachineMenuMode(0, false);
      else if(myState == EventHandlerState::TIMEMACHINE)
        leaveMenuMode();
      else
        handled = false;
      break;

    case Event::TogglePlayBackMode:
      if (myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
          || myState == EventHandlerState::TIMEMACHINE)
        enterPlayBackMode();
      else if (myState == EventHandlerState::PLAYBACK)
    #ifdef GUI_SUPPORT
        enterMenuMode(EventHandlerState::TIMEMACHINE);
    #else
        setState(EventHandlerState::PAUSE);
    #endif
      else
        handled = false;
      break;

    case Event::DebuggerMode:
  #ifdef DEBUGGER_SUPPORT
      if(myState == EventHandlerState::EMULATION || myState == EventHandlerState::PAUSE
         || myState == EventHandlerState::TIMEMACHINE || myState == EventHandlerState::PLAYBACK)
        enterDebugMode();
      else if(myState == EventHandlerState::DEBUGGER && myOSystem.debugger().canExit())
        leaveDebugMode();
      else
        handled = false;
  #endif
      break;

    default:
      handled = false;
  }

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setActionMappings(EventMode mode)
{
  switch(mode)
  {
    case EventMode::kEmulationMode:
      // Fill the EmulActionList with the current key and joystick mappings
      for(auto& item: ourEmulActionList)
      {
        const Event::Type event = item.event;
        item.key = "None";
        string key = myPKeyHandler->getMappingDesc(event, mode);

    #ifdef JOYSTICK_SUPPORT
        const string joydesc = myPJoyHandler->getMappingDesc(event, mode);
        if(!joydesc.empty())
        {
          if(!key.empty())
            key += ", ";
          key += joydesc;
        }
    #endif

        if(!key.empty())
          item.key = key;
      }
      break;
    case EventMode::kMenuMode:
      // Fill the MenuActionList with the current key and joystick mappings
      for(auto& item: ourMenuActionList)
      {
        const Event::Type event = item.event;
        item.key = "None";
        string key = myPKeyHandler->getMappingDesc(event, mode);

    #ifdef JOYSTICK_SUPPORT
        const string joydesc = myPJoyHandler->getMappingDesc(event, mode);
        if(!joydesc.empty())
        {
          if(!key.empty())
            key += ", ";
          key += joydesc;
        }
    #endif

        if(!key.empty())
          item.key = key;
      }
      break;
    default:
      return;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setComboMap()
{
  const Int32 version = myOSystem.settings().getInt("event_ver");
  const string serializedMapping = myOSystem.settings().getString("combomap");
  json mapping;

  try
  {
    mapping = json::parse(serializedMapping);
  }
  catch(const json::exception&)
  {
    Logger::info("converting legacy combo mapping");
    mapping = convertLegacyComboMapping(serializedMapping);
  }

  // Erase the 'combo' array
  const auto ERASE_ALL = [&]() {
    for(int i = 0; i < COMBO_SIZE; ++i)
      for(int j = 0; j < EVENTS_PER_COMBO; ++j)
        myComboTable[i][j] = Event::NoType;
  };

  ERASE_ALL();

  // Compare if event list version has changed so that combo maps became invalid
  if(version == Event::VERSION)
  {
    try
    {
      for(const json& combo : mapping)
      {
        const int i = combo.at("combo").get<Event::Type>() - Event::Combo1;
        int j = 0;
        const json events = combo.at("events");

        for(const json& event: events)
          myComboTable[i][j++] = event;
      }
    }
    catch(const json::exception&)
    {
      Logger::error("ignoring bad combo mapping");
      ERASE_ALL();
    }
  }
  saveComboMapping();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
json EventHandler::convertLegacyComboMapping(string list)
{
  json convertedMapping = json::array();

  // Since istringstream swallows whitespace, we have to make the
  // delimiters be spaces
  std::replace(list.begin(), list.end(), ':', ' ');
  std::replace(list.begin(), list.end(), ',', ' ');
  istringstream buf(list);

  try
  {
    int numCombos{0};
    // Get combo count, which should be the first int in the list
    // If it isn't, then we treat the entire list as invalid
    buf >> numCombos;

    if(numCombos == COMBO_SIZE)
    {
      for(int i = 0; i < COMBO_SIZE; ++i)
      {
        json events = json::array();

        for(int j = 0; j < EVENTS_PER_COMBO; ++j)
        {
          int event{0};
          buf >> event;
          // skip all NoType events
          if(event != Event::NoType)
            events.push_back(static_cast<Event::Type>(event));
        }
        // only store if there are any NoType events
        if(!events.empty())
        {
          json combo;

          combo["combo"] = static_cast<Event::Type>(Event::Combo1 + i);
          combo["events"] = events;
          convertedMapping.push_back(combo);
        }
      }
    }
  }
  catch(...)
  {
    Logger::error("Legacy combo map conversion failed!");
  }
  return convertedMapping;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::removePhysicalJoystickFromDatabase(string_view name)
{
#ifdef JOYSTICK_SUPPORT
  myPJoyHandler->remove(name);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setPhysicalJoystickPortInDatabase(string_view name,
                                                     PhysicalJoystick::Port port)
{
#ifdef JOYSTICK_SUPPORT
  myPJoyHandler->setPort(name, port);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventHandler::addKeyMapping(Event::Type event, EventMode mode, StellaKey key, StellaMod mod)
{
  const bool mapped = myPKeyHandler->addMapping(event, mode, key, mod);
  if(mapped)
    setActionMappings(mode);

  return mapped;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventHandler::addJoyMapping(Event::Type event, EventMode mode,
                                 int stick, int button, JoyAxis axis, JoyDir adir,
                                 bool updateMenus)
{
#ifdef JOYSTICK_SUPPORT
  const bool mapped = myPJoyHandler->addJoyMapping(event, mode, stick, button, axis, adir);
  if (mapped && updateMenus)
    setActionMappings(mode);

  return mapped;
#else
  return false;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventHandler::addJoyHatMapping(Event::Type event, EventMode mode,
                                    int stick, int button, int hat, JoyHatDir dir,
                                    bool updateMenus)
{
#ifdef JOYSTICK_SUPPORT
  const bool mapped = myPJoyHandler->addJoyHatMapping(event, mode, stick, button, hat, dir);
  if (mapped && updateMenus)
    setActionMappings(mode);

  return mapped;
#else
  return false;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::eraseMapping(Event::Type event, EventMode mode)
{
  // Erase the KeyEvent array
  myPKeyHandler->eraseMapping(event, mode);

#ifdef JOYSTICK_SUPPORT
  // Erase the joystick mapping arrays
  myPJoyHandler->eraseMapping(event, mode);
#endif

  setActionMappings(mode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setDefaultMapping(Event::Type event, EventMode mode)
{
  setDefaultKeymap(event, mode);
  setDefaultJoymap(event, mode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setDefaultKeymap(Event::Type event, EventMode mode)
{
  myPKeyHandler->setDefaultMapping(event, mode);
  setActionMappings(mode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setDefaultJoymap(Event::Type event, EventMode mode)
{
#ifdef JOYSTICK_SUPPORT
  myPJoyHandler->setDefaultMapping(event, mode);
  setActionMappings(mode);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::saveKeyMapping()
{
  myPKeyHandler->saveMapping();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::saveJoyMapping()
{
#ifdef JOYSTICK_SUPPORT
  myPJoyHandler->saveMapping();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::saveComboMapping()
{
  json mapping = json::array();

  // Iterate through the combomap table and convert into json format
  for(int i = 0; i < COMBO_SIZE; ++i)
  {
    json events = json::array();

    for(int j = 0; j < EVENTS_PER_COMBO; ++j)
    {
      const int event = myComboTable[i][j];

      // skip all NoType events
      if(event != Event::NoType)
        events.push_back(static_cast<Event::Type>(event));
    }
    // only store if there are any NoType events
    if(!events.empty())
    {
      json combo;

      combo["combo"] = static_cast<Event::Type>(Event::Combo1 + i);
      combo["events"] = events;
      mapping.push_back(combo);
    }
  }
  myOSystem.settings().setValue("combomap", mapping.dump(2));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StringList EventHandler::getActionList(EventMode mode)
{
  StringList l;
  switch(mode)
  {
    case EventMode::kEmulationMode:
      for(const auto& item: ourEmulActionList)
        l.push_back(item.action);
      break;
    case EventMode::kMenuMode:
      for(const auto& item: ourMenuActionList)
        l.push_back(item.action);
      break;
    default:
      break;
  }
  return l;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StringList EventHandler::getActionList(Event::Group group)
{
  switch(group)
  {
    case Event::Group::Menu:
      return getActionList(EventMode::kMenuMode);

    case Event::Group::Emulation:
      return getActionList(EventMode::kEmulationMode);

    case Event::Group::Misc:
      return getActionList(MiscEvents);

    case Event::Group::AudioVideo:
      return getActionList(AudioVideoEvents);

    case Event::Group::States:
      return getActionList(StateEvents);

    case Event::Group::Console:
      return getActionList(ConsoleEvents);

    case Event::Group::Joystick:
      return getActionList(JoystickEvents);

    case Event::Group::Paddles:
      return getActionList(PaddlesEvents);

    case Event::Group::Keyboard:
      return getActionList(KeyboardEvents);

    case Event::Group::Driving:
      return getActionList(DrivingEvents);

    case Event::Group::Devices:
      return getActionList(DevicesEvents);

    case Event::Group::Debug:
      return getActionList(DebugEvents);

    case Event::Group::Combo:
      return getActionList(ComboEvents);

    default:
      return {}; // ToDo
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StringList EventHandler::getActionList(const Event::EventSet& events,
                                       EventMode mode)
{
  StringList l;

  switch(mode)
  {
    case EventMode::kMenuMode:
      for(const auto& item: ourMenuActionList)
        for(const auto& event : events)
          if(item.event == event)
          {
            l.push_back(item.action);
            break;
          }
      break;

    default:
      for(const auto& item: ourEmulActionList)
        for(const auto& event : events)
          if(item.event == event)
          {
            l.push_back(item.action);
            break;
          }
  }
  return l;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VariantList EventHandler::getComboList()
{
  // For now, this only works in emulation mode
  VariantList l;
  ostringstream buf;

  VarList::push_back(l, "None", "-1");
  for(uInt32 i = 0; i < ourEmulActionList.size(); ++i)
  {
    const Event::Type event = EventHandler::ourEmulActionList[i].event;
    // exclude combos events
    if(event < Event::Combo1 || event > Event::Combo16)
    {
      buf << i;
      VarList::push_back(l, EventHandler::ourEmulActionList[i].action, buf.str());
      buf.str("");
    }
  }
  return l;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StringList EventHandler::getComboListForEvent(Event::Type event) const
{
  StringList l;
  ostringstream buf;
  if(event >= Event::Combo1 && event <= Event::Combo16)
  {
    const int combo = event - Event::Combo1;
    for(uInt32 i = 0; i < EVENTS_PER_COMBO; ++i)
    {
      const Event::Type e = myComboTable[combo][i];
      for(uInt32 j = 0; j < ourEmulActionList.size(); ++j)
      {
        if(EventHandler::ourEmulActionList[j].event == e)
        {
          buf << j;
          l.push_back(buf.str());
          buf.str("");
        }
      }
      // Make sure entries are 1-to-1, using '-1' to indicate Event::NoType
      if(i == l.size())
        l.emplace_back("-1");
    }
  }
  return l;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setComboListForEvent(Event::Type event, const StringList& events)
{
  if(event >= Event::Combo1 && event <= Event::Combo16)
  {
    assert(events.size() == EVENTS_PER_COMBO);
    const int combo = event - Event::Combo1;
    for(uInt32 i = 0; i < EVENTS_PER_COMBO; ++i)
    {
      const uInt32 idx = BSPF::stoi(events[i]);
      if(idx < ourEmulActionList.size())
        myComboTable[combo][i] = EventHandler::ourEmulActionList[idx].event;
      else
        myComboTable[combo][i] = Event::NoType;
    }
    saveComboMapping();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EventHandler::getEmulActionListIndex(int idx, const Event::EventSet& events)
{
  // idx = index into intersection set of 'events' and 'ourEmulActionList'
  //   ordered by 'ourEmulActionList'!
  Event::Type event = Event::NoType;

  for(auto& alist: ourEmulActionList)
  {
    for(const auto& item : events)
      if(alist.event == item)
      {
        idx--;
        if(idx < 0)
          event = item;
        break;
      }
    if(idx < 0)
      break;
  }

  for(uInt32 i = 0; i < ourEmulActionList.size(); ++i)
    if(EventHandler::ourEmulActionList[i].event == event)
      return i;

  return -1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int EventHandler::getActionListIndex(int idx, Event::Group group)
{
  switch(group)
  {
    case Event::Group::Menu:
      return idx;

    case Event::Group::Emulation:
      return idx;

    case Event::Group::Misc:
      return getEmulActionListIndex(idx, MiscEvents);

    case Event::Group::AudioVideo:
      return getEmulActionListIndex(idx, AudioVideoEvents);

    case Event::Group::States:
      return getEmulActionListIndex(idx, StateEvents);

    case Event::Group::Console:
      return getEmulActionListIndex(idx, ConsoleEvents);

    case Event::Group::Joystick:
      return getEmulActionListIndex(idx, JoystickEvents);

    case Event::Group::Paddles:
      return getEmulActionListIndex(idx, PaddlesEvents);

    case Event::Group::Keyboard:
      return getEmulActionListIndex(idx, KeyboardEvents);

    case Event::Group::Driving:
      return getEmulActionListIndex(idx, DrivingEvents);

    case Event::Group::Devices:
      return getEmulActionListIndex(idx, DevicesEvents);

    case Event::Group::Debug:
      return getEmulActionListIndex(idx, DebugEvents);

    case Event::Group::Combo:
      return getEmulActionListIndex(idx, ComboEvents);

    default:
      return -1;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Event::Type EventHandler::eventAtIndex(int idx, Event::Group group)
{
  const int index = getActionListIndex(idx, group);

  if(group == Event::Group::Menu)
  {
    if(index < 0 || index >= static_cast<int>(ourMenuActionList.size()))
      return Event::NoType;
    else
      return ourMenuActionList[index].event;
  }
  else
  {
    if(index < 0 || index >= static_cast<int>(ourEmulActionList.size()))
      return Event::NoType;
    else
      return ourEmulActionList[index].event;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string EventHandler::actionAtIndex(int idx, Event::Group group)
{
  const int index = getActionListIndex(idx, group);

  if(group == Event::Group::Menu)
  {
    if(index < 0 || index >= static_cast<int>(ourMenuActionList.size()))
      return EmptyString;
    else
      return ourMenuActionList[index].action;
  }
  else
  {
    if(index < 0 || index >= static_cast<int>(ourEmulActionList.size()))
      return EmptyString;
    else
      return ourEmulActionList[index].action;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string EventHandler::keyAtIndex(int idx, Event::Group group)
{
  const int index = getActionListIndex(idx, group);

  if(group == Event::Group::Menu)
  {
    if(index < 0 || index >= static_cast<int>(ourMenuActionList.size()))
      return EmptyString;
    else
      return ourMenuActionList[index].key;
  }
  else
  {
    if(index < 0 || index >= static_cast<int>(ourEmulActionList.size()))
      return EmptyString;
    else
      return ourEmulActionList[index].key;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setMouseControllerMode(string_view enable)
{
  if(myOSystem.hasConsole())
  {
    bool usemouse = false;
    if(BSPF::equalsIgnoreCase(enable, "always"))
      usemouse = true;
    else if(BSPF::equalsIgnoreCase(enable, "never"))
      usemouse = false;
    else  // 'analog'
    {
      usemouse = myOSystem.console().leftController().isAnalog() ||
                 myOSystem.console().rightController().isAnalog();
    }

    const string& control = usemouse ?
      myOSystem.console().properties().get(PropType::Controller_MouseAxis) : "none";

    myMouseControl = make_unique<MouseControl>(myOSystem.console(), control);
    myMouseControl->change(0);  // set first available mode
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::changeMouseControllerMode(int direction)
{
  constexpr int NUM_MODES = 3;
  const string MODES[NUM_MODES] = {"always", "analog", "never"};
  const string MSG[NUM_MODES] = {"all", "analog", "no"};
  string usemouse = myOSystem.settings().getString("usemouse");

  int i = 0;
  for(const auto& mode : MODES)
  {
    if(mode == usemouse)
    {
      i = BSPF::clampw(i + direction, 0, NUM_MODES - 1);
      usemouse = MODES[i];
      break;
    }
    ++i;
  }
  myOSystem.settings().setValue("usemouse", usemouse);
  setMouseControllerMode(usemouse);
  myOSystem.frameBuffer().setCursorState(); // if necessary change grab mouse

  ostringstream ss;
  ss << "Mouse controls " << MSG[i] << " devices";
  myOSystem.frameBuffer().showTextMessage(ss.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::changeMouseCursor(int direction)
{
  const int cursor = BSPF::clampw(myOSystem.settings().getInt("cursor") + direction, 0, 3);

  myOSystem.settings().setValue("cursor", cursor);
  myOSystem.frameBuffer().setCursorState();

  ostringstream ss;
  ss << "Mouse cursor visibilility: "
    << ((cursor & 2) ? "+" : "-") << "UI, "
    << ((cursor & 1) ? "+" : "-") << "Emulation";
  myOSystem.frameBuffer().showTextMessage(ss.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::enterMenuMode(EventHandlerState state)
{
#ifdef GUI_SUPPORT
  setState(state);
  myOverlay->reStack();
  myOSystem.sound().pause(true);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::leaveMenuMode()
{
#ifdef GUI_SUPPORT
  myOverlay->removeDialog(); // remove the base dialog from dialog stack
  setState(EventHandlerState::EMULATION);
  myOSystem.sound().pause(false);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool EventHandler::enterDebugMode()
{
#ifdef DEBUGGER_SUPPORT
  if(myState == EventHandlerState::DEBUGGER || !myOSystem.hasConsole())
    return false;

  // Make sure debugger starts in a consistent state
  // This absolutely *has* to come before we actually change to debugger
  // mode, since it takes care of locking the debugger state, which will
  // probably be modified below
  myOSystem.debugger().setStartState();
  setState(EventHandlerState::DEBUGGER);

  const FBInitStatus fbstatus = myOSystem.createFrameBuffer();
  if(fbstatus != FBInitStatus::Success)
  {
    myOSystem.debugger().setQuitState();
    setState(EventHandlerState::EMULATION);
    if(fbstatus == FBInitStatus::FailTooLarge)
      myOSystem.frameBuffer().showTextMessage("Debugger window too large for screen",
                                              MessagePosition::BottomCenter, true);
    return false;
  }
  myOverlay->reStack();
  myOSystem.sound().mute(true);

#else
  myOSystem.frameBuffer().showTextMessage("Debugger support not included",
                                          MessagePosition::BottomCenter, true);
#endif

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::leaveDebugMode()
{
#ifdef DEBUGGER_SUPPORT
  // paranoia: this should never happen:
  if(myState != EventHandlerState::DEBUGGER)
    return;

  // Make sure debugger quits in a consistent state
  myOSystem.debugger().setQuitState();

  setState(EventHandlerState::EMULATION);
  myOSystem.createFrameBuffer();
  myOSystem.sound().mute(false);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::enterTimeMachineMenuMode(uInt32 numWinds, bool unwind)
{
#ifdef GUI_SUPPORT
  // add one extra state if we are in Time Machine mode
  // TODO: maybe remove this state if we leave the menu at this new state
  myOSystem.state().addExtraState("enter Time Machine dialog"); // force new state

  if(numWinds)
    // hande winds and display wind message (numWinds != 0) in time machine dialog
    myOSystem.timeMachine().setEnterWinds(unwind ? numWinds : -numWinds);

  enterMenuMode(EventHandlerState::TIMEMACHINE);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::enterPlayBackMode()
{
#ifdef GUI_SUPPORT
  setState(EventHandlerState::PLAYBACK);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::setState(EventHandlerState state)
{
  myState = state;

  // Normally, the usage of modifier keys is determined by 'modcombo'
  // For certain ROMs it may be forced off, whatever the setting
  myPKeyHandler->useModKeys() = myOSystem.settings().getBool("modcombo");

  // Only enable text input in GUI modes, since in emulation mode the
  // keyboard acts as one large joystick with many (single) buttons
  myOverlay = nullptr;
  switch(myState)
  {
    case EventHandlerState::EMULATION:
    case EventHandlerState::PLAYBACK:
      myOSystem.sound().pause(false);
      enableTextEvents(false);
      break;

    case EventHandlerState::PAUSE:
      myOSystem.sound().pause(true);
      enableTextEvents(false);
      break;

  #ifdef GUI_SUPPORT
    case EventHandlerState::OPTIONSMENU:
      myOverlay = &myOSystem.optionsMenu();
      enableTextEvents(true);
      break;

    case EventHandlerState::CMDMENU:
      myOverlay = &myOSystem.commandMenu();
      enableTextEvents(true);
      break;

    case EventHandlerState::HIGHSCORESMENU:
      myOverlay = &myOSystem.highscoresMenu();
      enableTextEvents(true);
      break;

    case EventHandlerState::MESSAGEMENU:
      myOverlay = &myOSystem.messageMenu();
      enableTextEvents(true);
      break;

    case EventHandlerState::PLUSROMSMENU:
      myOverlay = &myOSystem.plusRomsMenu();
      enableTextEvents(true);
      break;

    case EventHandlerState::TIMEMACHINE:
      myOSystem.timeMachine().requestResize();
      myOverlay = &myOSystem.timeMachine();
      enableTextEvents(true);
      break;

    case EventHandlerState::LAUNCHER:
      myOverlay = &myOSystem.launcher();
      enableTextEvents(true);
      break;
  #endif

  #ifdef DEBUGGER_SUPPORT
    case EventHandlerState::DEBUGGER:
      myOverlay = &myOSystem.debugger();
      enableTextEvents(true);
      break;
  #endif

    case EventHandlerState::NONE:
    default:
      break;
  }

  // Inform various subsystems about the new state
  myOSystem.stateChanged(myState); // does nothing
  myOSystem.frameBuffer().stateChanged(myState); // ignores state
  myOSystem.frameBuffer().setCursorState(); // en/disables cursor for UI and emulation states
  if(myOSystem.hasConsole())
    myOSystem.console().stateChanged(myState); // does nothing

  // Sometimes an extraneous mouse motion event is generated
  // after a state change, which should be supressed
  mySkipMouseMotion = true;

  // Erase any previously set events, since a state change implies
  // that old events are now invalid
  myEvent.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::exitLauncher()
{
#ifdef GUI_SUPPORT
  myOSystem.launcher().quit();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandler::exitEmulation(bool checkLauncher)
{
  const string saveOnExit = myOSystem.settings().getString("saveonexit");
  const bool activeTM = myOSystem.settings().getBool(
    myOSystem.settings().getBool("dev.settings") ? "dev.timemachine" : "plr.timemachine");

  if (saveOnExit == "all" && activeTM)
    handleEvent(Event::SaveAllStates);
  else if (saveOnExit == "current")
    handleEvent(Event::SaveState);

#if DEBUGGER_SUPPORT
  myOSystem.debugger().quit();
#endif

  if (checkLauncher)
  {
    // Go back to the launcher, or immediately quit
    if (myOSystem.settings().getBool("exitlauncher") ||
        myOSystem.launcherUsed())
      myOSystem.createLauncher();
    else
      handleEvent(Event::Quit);
  }
}

#if defined(__clang__)
  #pragma clang diagnostic ignored "-Wmissing-field-initializers"
#elif defined(__GNUC__) || defined(__GNUG__)
  #pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#endif
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandler::EmulActionList EventHandler::ourEmulActionList = { {
  { Event::Quit,                    "Quit"                                  },
  { Event::ReloadConsole,           "Reload current ROM/load next game"     },
  { Event::PreviousMultiCartRom,    "Load previous multicart game"          },
  { Event::ExitMode,                "Exit current Stella menu/mode"         },
  { Event::OptionsMenuMode,         "Enter Options menu UI"                 },
  { Event::CmdMenuMode,             "Toggle Commands menu UI"               },
#ifdef IMAGE_SUPPORT
  { Event::ToggleBezel,             "Toggle bezel display"                  },
#endif
  { Event::HighScoresMenuMode,      "Toggle High Scores UI"                 },
  { Event::PlusRomsSetupMode,       "Toggle PlusROMs setup UI"              },
  { Event::TogglePauseMode,         "Toggle Pause mode"                     },
  { Event::StartPauseMode,          "Start Pause mode"                      },
  { Event::Fry,                     "Fry cartridge"                         },
  { Event::DecreaseSpeed,           "Decrease emulation speed"              },
  { Event::IncreaseSpeed,           "Increase emulation speed"              },
  { Event::ToggleTurbo,             "Toggle 'Turbo' mode"                   },
  { Event::DebuggerMode,            "Toggle Debugger mode"                  },

  { Event::ConsoleSelect,           "Select"                                },
  { Event::ConsoleReset,            "Reset"                                 },
  { Event::ConsoleColor,            "Color TV"                              },
  { Event::ConsoleBlackWhite,       "Black & White TV"                      },
  { Event::ConsoleColorToggle,      "Toggle Color / B&W TV"                 },
  { Event::Console7800Pause,        "7800 Pause Key"                        },
  { Event::ConsoleLeftDiffA,        "Left Difficulty A"                     },
  { Event::ConsoleLeftDiffB,        "Left Difficulty B"                     },
  { Event::ConsoleLeftDiffToggle,   "Toggle Left Difficulty"                },
  { Event::ConsoleRightDiffA,       "Right Difficulty A"                    },
  { Event::ConsoleRightDiffB,       "Right Difficulty B"                    },
  { Event::ConsoleRightDiffToggle,  "Toggle Right Difficulty"               },
  { Event::SaveState,               "Save state"                            },
  { Event::SaveAllStates,           "Save all TM states of current game"    },
  { Event::PreviousState,           "Change to previous state slot"         },
  { Event::NextState,               "Change to next state slot"             },
  { Event::ToggleAutoSlot,          "Toggle automatic state slot change"    },
  { Event::LoadState,               "Load state"                            },
  { Event::LoadAllStates,           "Load saved TM states for current game" },

#ifdef IMAGE_SUPPORT
  { Event::TakeSnapshot,            "Snapshot"                              },
  { Event::ToggleContSnapshots,     "Save continuous snapsh. (as defined)"  },
  { Event::ToggleContSnapshotsFrame,"Save continuous snapsh. (every frame)" },
#endif
  // Global keys:
  { Event::PreviousSettingGroup,    "Select previous setting group"         },
  { Event::NextSettingGroup,        "Select next setting group"             },
  { Event::PreviousSetting,         "Select previous setting"               },
  { Event::NextSetting,             "Select next setting"                   },
  { Event::SettingDecrease,         "Decrease current setting"              },
  { Event::SettingIncrease,         "Increase current setting"              },

  // Controllers:
  { Event::LeftJoystickUp,          "Left Joystick Up"                      },
  { Event::LeftJoystickDown,        "Left Joystick Down"                    },
  { Event::LeftJoystickLeft,        "Left Joystick Left"                    },
  { Event::LeftJoystickRight,       "Left Joystick Right"                   },
  { Event::LeftJoystickFire,        "Left Joystick Fire"                    },
  { Event::LeftJoystickFire5,       "Left Top Booster Button, Button 'C'"   },
  { Event::LeftJoystickFire9,       "Left Handle Grip Trigger, Button '3'"  },

  { Event::RightJoystickUp,         "Right Joystick Up"                     },
  { Event::RightJoystickDown,       "Right Joystick Down"                   },
  { Event::RightJoystickLeft,       "Right Joystick Left"                   },
  { Event::RightJoystickRight,      "Right Joystick Right"                  },
  { Event::RightJoystickFire,       "Right Joystick Fire"                   },
  { Event::RightJoystickFire5,      "Right Top Booster Button, Button 'C'"  },
  { Event::RightJoystickFire9,      "Right Handle Grip Trigger, Button '3'" },

  { Event::QTJoystickThreeUp,       "QuadTari Joystick 3 Up"                },
  { Event::QTJoystickThreeDown,     "QuadTari Joystick 3 Down"              },
  { Event::QTJoystickThreeLeft,     "QuadTari Joystick 3 Left"              },
  { Event::QTJoystickThreeRight,    "QuadTari Joystick 3 Right"             },
  { Event::QTJoystickThreeFire,     "QuadTari Joystick 3 Fire"              },

  { Event::QTJoystickFourUp,        "QuadTari Joystick 4 Up"                },
  { Event::QTJoystickFourDown,      "QuadTari Joystick 4 Down"              },
  { Event::QTJoystickFourLeft,      "QuadTari Joystick 4 Left"              },
  { Event::QTJoystickFourRight,     "QuadTari Joystick 4 Right"             },
  { Event::QTJoystickFourFire,      "QuadTari Joystick 4 Fire"              },

  { Event::LeftPaddleAAnalog,       "Left Paddle A Analog"                  },
  { Event::LeftPaddleAIncrease,     "Left Paddle A Turn Left"               },
  { Event::LeftPaddleADecrease,     "Left Paddle A Turn Right"              },
  { Event::LeftPaddleAFire,         "Left Paddle A Fire"                    },

  { Event::LeftPaddleBAnalog,       "Left Paddle B Analog"                  },
  { Event::LeftPaddleBIncrease,     "Left Paddle B Turn Left"               },
  { Event::LeftPaddleBDecrease,     "Left Paddle B Turn Right"              },
  { Event::LeftPaddleBFire,         "Left Paddle B Fire"                    },

  { Event::RightPaddleAAnalog,      "Right Paddle A Analog"                 },
  { Event::RightPaddleAIncrease,    "Right Paddle A Turn Left"              },
  { Event::RightPaddleADecrease,    "Right Paddle A Turn Right"             },
  { Event::RightPaddleAFire,        "Right Paddle A Fire"                   },

  { Event::RightPaddleBAnalog,      "Right Paddle B Analog"                 },
  { Event::RightPaddleBIncrease,    "Right Paddle B Turn Left"              },
  { Event::RightPaddleBDecrease,    "Right Paddle B Turn Right"             },
  { Event::RightPaddleBFire,        "Right Paddle B Fire"                   },

  { Event::QTPaddle3AFire,          "QuadTari Paddle 3A Fire"               },
  { Event::QTPaddle3BFire,          "QuadTari Paddle 3B Fire"               },
  { Event::QTPaddle4AFire,          "QuadTari Paddle 4A Fire"               },
  { Event::QTPaddle4BFire,          "QuadTari Paddle 4B Fire"               },

  { Event::LeftKeyboard1,           "Left Keyboard 1"                       },
  { Event::LeftKeyboard2,           "Left Keyboard 2"                       },
  { Event::LeftKeyboard3,           "Left Keyboard 3"                       },
  { Event::LeftKeyboard4,           "Left Keyboard 4"                       },
  { Event::LeftKeyboard5,           "Left Keyboard 5"                       },
  { Event::LeftKeyboard6,           "Left Keyboard 6"                       },
  { Event::LeftKeyboard7,           "Left Keyboard 7"                       },
  { Event::LeftKeyboard8,           "Left Keyboard 8"                       },
  { Event::LeftKeyboard9,           "Left Keyboard 9"                       },
  { Event::LeftKeyboardStar,        "Left Keyboard *"                       },
  { Event::LeftKeyboard0,           "Left Keyboard 0"                       },
  { Event::LeftKeyboardPound,       "Left Keyboard #"                       },

  { Event::RightKeyboard1,          "Right Keyboard 1"                      },
  { Event::RightKeyboard2,          "Right Keyboard 2"                      },
  { Event::RightKeyboard3,          "Right Keyboard 3"                      },
  { Event::RightKeyboard4,          "Right Keyboard 4"                      },
  { Event::RightKeyboard5,          "Right Keyboard 5"                      },
  { Event::RightKeyboard6,          "Right Keyboard 6"                      },
  { Event::RightKeyboard7,          "Right Keyboard 7"                      },
  { Event::RightKeyboard8,          "Right Keyboard 8"                      },
  { Event::RightKeyboard9,          "Right Keyboard 9"                      },
  { Event::RightKeyboardStar,       "Right Keyboard *"                      },
  { Event::RightKeyboard0,          "Right Keyboard 0"                      },
  { Event::RightKeyboardPound,      "Right Keyboard #"                      },

  { Event::LeftDrivingAnalog,       "Left Driving Analog"                   },
  { Event::LeftDrivingCCW,          "Left Driving Turn Left"                },
  { Event::LeftDrivingCW,           "Left Driving Turn Right"               },
  { Event::LeftDrivingFire,         "Left Driving Fire"                     },

  { Event::RightDrivingAnalog,      "Right Driving Analog"                  },
  { Event::RightDrivingCCW,         "Right Driving Turn Left"               },
  { Event::RightDrivingCW,          "Right Driving Turn Right"              },
  { Event::RightDrivingFire,        "Right Driving Fire"                    },

  // Video
  { Event::ToggleInter,             "Toggle display interpolation"          },
  { Event::VidmodeDecrease,         "Previous zoom level"                   },
  { Event::VidmodeIncrease,         "Next zoom level"                       },
  { Event::ToggleFullScreen,        "Toggle fullscreen"                     },
#ifdef ADAPTABLE_REFRESH_SUPPORT
  { Event::ToggleAdaptRefresh,      "Toggle fullscreen refresh rate adapt"  },
#endif
  { Event::OverscanDecrease,        "Decrease overscan in fullscreen mode"  },
  { Event::OverscanIncrease,        "Increase overscan in fullscreen mode"  },
  { Event::ToggleCorrectAspectRatio,"Toggle aspect ratio correct scaling"   },
  { Event::VSizeAdjustDecrease,     "Decrease vertical display size"        },
  { Event::VSizeAdjustIncrease,     "Increase vertical display size"        },
  { Event::VCenterDecrease,         "Move display up"                       },
  { Event::VCenterIncrease,         "Move display down"                     },
  { Event::FormatDecrease,          "Decrease TV format"                    },
  { Event::FormatIncrease,          "Increase TV format"                    },
    // Palette settings
  { Event::PaletteDecrease,         "Switch to previous palette"            },
  { Event::PaletteIncrease,         "Switch to next palette"                },
  { Event::PreviousPaletteAttribute,"Select previous palette attribute"     },
  { Event::NextPaletteAttribute,    "Select next palette attribute"         },
  { Event::PaletteAttributeDecrease,"Decrease selected palette attribute"   },
  { Event::PaletteAttributeIncrease,"Increase selected palette attribute"   },
  // Blargg TV effects:
  { Event::VidmodeStd,              "Disable TV effects"                    },
  { Event::VidmodeRGB,              "Select 'RGB' preset"                   },
  { Event::VidmodeSVideo,           "Select 'S-Video' preset"               },
  { Event::VidModeComposite,        "Select 'Composite' preset"             },
  { Event::VidModeBad,              "Select 'Badly adjusted' preset"        },
  { Event::VidModeCustom,           "Select 'Custom' preset"                },
  { Event::PreviousVideoMode,       "Select previous TV effect mode preset" },
  { Event::NextVideoMode,           "Select next TV effect mode preset"     },
  { Event::PreviousAttribute,       "Select previous 'Custom' attribute"    },
  { Event::NextAttribute,           "Select next 'Custom' attribute"        },
  { Event::DecreaseAttribute,       "Decrease selected 'Custom' attribute"  },
  { Event::IncreaseAttribute,       "Increase selected 'Custom' attribute"  },
  // Other TV effects
  { Event::TogglePhosphor,          "Toggle 'phosphor' effect"              },
  { Event::PhosphorModeDecrease,    "Decrease 'phosphor' enabling mode"     },
  { Event::PhosphorModeIncrease,    "Increase 'phosphor' enabling mode"     },
  { Event::PhosphorDecrease,        "Decrease 'phosphor' blend"             },
  { Event::PhosphorIncrease,        "Increase 'phosphor' blend"             },
  { Event::ScanlinesDecrease,       "Decrease scanlines"                    },
  { Event::ScanlinesIncrease,       "Increase scanlines"                    },
  { Event::PreviousScanlineMask,    "Switch to previous scanline mask"      },
  { Event::NextScanlineMask,        "Switch to next scanline mask"          },
  // Audio
  { Event::SoundToggle,             "Toggle sound"                          },
  { Event::VolumeDecrease,          "Decrease volume"                       },
  { Event::VolumeIncrease,          "Increase volume"                       },

  // Devices & Ports:
  { Event::DecreaseDeadzone,        "Decrease digital dead zone"            },
  { Event::IncreaseDeadzone,        "Increase digital dead zone"            },
  { Event::DecAnalogDeadzone,       "Decrease analog dead zone"             },
  { Event::IncAnalogDeadzone,       "Increase analog dead zone"             },
  { Event::DecAnalogSense,          "Decrease analog paddle sensitivity"    },
  { Event::IncAnalogSense,          "Increase analog paddle sensitivity"    },
  { Event::DecAnalogLinear,         "Decrease analog paddle linearity"      },
  { Event::IncAnalogLinear,         "Increase analog paddle linearity"      },
  { Event::DecDejtterAveraging,     "Decrease paddle dejitter averaging"    },
  { Event::IncDejtterAveraging,     "Increase paddle dejitter averaging"    },
  { Event::DecDejtterReaction,      "Decrease paddle dejitter reaction"     },
  { Event::IncDejtterReaction,      "Increase paddle dejitter reaction"     },
  { Event::DecDigitalSense,         "Decrease digital paddle sensitivity"   },
  { Event::IncDigitalSense,         "Increase digital paddle sensitivity"   },
  { Event::ToggleAutoFire,          "Toggle auto fire"                      },
  { Event::DecreaseAutoFire,        "Decrease auto fire speed"              },
  { Event::IncreaseAutoFire,        "Increase auto fire speed"              },
  { Event::ToggleFourDirections,    "Toggle allow four joystick directions" },
  { Event::ToggleKeyCombos,         "Toggle use of modifier key combos"     },
  { Event::ToggleSAPortOrder,       "Swap Stelladaptor port ordering"       },
  // Devices & Ports related properties
  { Event::PreviousLeftPort,        "Select previous left controller"       },
  { Event::NextLeftPort,            "Select next left controller"           },
  { Event::PreviousRightPort,       "Select previous right controller"      },
  { Event::NextRightPort,           "Select next right controller"          },
  { Event::ToggleSwapPorts,         "Toggle swap ports"                     },
  { Event::ToggleSwapPaddles,       "Toggle swap paddles"                   },

  // Mouse
  { Event::PrevMouseAsController,   "Select previous mouse controls"        },
  { Event::NextMouseAsController,   "Select next mouse controls"            },
  { Event::DecMousePaddleSense,     "Decrease mouse paddle sensitivity"     },
  { Event::IncMousePaddleSense,     "Increase mouse paddle sensitivity"     },
  { Event::DecMouseTrackballSense,  "Decrease mouse trackball sensitivity"  },
  { Event::IncMouseTrackballSense,  "Increase mouse trackball sensitivity"  },
  { Event::DecreaseDrivingSense,    "Decrease driving sensitivity"          },
  { Event::IncreaseDrivingSense,    "Increase driving sensitivity"          },
  { Event::PreviousCursorVisbility, "Select prev. cursor visibility mode"   },
  { Event::NextCursorVisbility,     "Select next cursor visibility mode"    },
  { Event::ToggleGrabMouse,         "Toggle grab mouse"                     },
  // Mouse related properties
  { Event::PreviousMouseControl,    "Select previous mouse emulation mode"  },
  { Event::NextMouseControl,        "Select next mouse emulation mode"      },
  { Event::DecreaseMouseAxesRange,  "Decrease mouse axes range"             },
  { Event::IncreaseMouseAxesRange,  "Increase mouse axes range"             },

  // Time Machine
  { Event::ToggleTimeMachine,       "Toggle 'Time Machine' mode"            },
  { Event::TimeMachineMode,         "Toggle 'Time Machine' UI"              },
  { Event::RewindPause,             "Rewind one state & enter Pause mode"   },
  { Event::Rewind1Menu,             "Rewind one state & enter TM UI"        },
  { Event::Rewind10Menu,            "Rewind 10 states & enter TM UI"        },
  { Event::RewindAllMenu,           "Rewind all states & enter TM UI"       },
  { Event::UnwindPause,             "Unwind one state & enter Pause mode"   },
  { Event::Unwind1Menu,             "Unwind one state & enter TM UI"        },
  { Event::Unwind10Menu,            "Unwind 10 states & enter TM UI"        },
  { Event::UnwindAllMenu,           "Unwind all states & enter TM UI"       },
  { Event::TogglePlayBackMode,      "Toggle 'Time Machine' playback mode"   },

  // Developer:
  { Event::ToggleDeveloperSet,      "Toggle developer settings sets"        },
  { Event::ToggleFrameStats,        "Toggle frame stats"                    },
  { Event::ToggleP0Bit,             "Toggle TIA Player0 object"             },
  { Event::ToggleP0Collision,       "Toggle TIA Player0 collisions"         },
  { Event::ToggleP1Bit,             "Toggle TIA Player1 object"             },
  { Event::ToggleP1Collision,       "Toggle TIA Player1 collisions"         },
  { Event::ToggleM0Bit,             "Toggle TIA Missile0 object"            },
  { Event::ToggleM0Collision,       "Toggle TIA Missile0 collisions"        },
  { Event::ToggleM1Bit,             "Toggle TIA Missile1 object"            },
  { Event::ToggleM1Collision,       "Toggle TIA Missile1 collisions"        },
  { Event::ToggleBLBit,             "Toggle TIA Ball object"                },
  { Event::ToggleBLCollision,       "Toggle TIA Ball collisions"            },
  { Event::TogglePFBit,             "Toggle TIA Playfield object"           },
  { Event::TogglePFCollision,       "Toggle TIA Playfield collisions"       },
  { Event::ToggleBits,              "Toggle all TIA objects"                },
  { Event::ToggleCollisions,        "Toggle all TIA collisions"             },
  { Event::ToggleFixedColors,       "Toggle TIA 'Fixed Debug Colors' mode"  },
  { Event::ToggleColorLoss,         "Toggle PAL color-loss effect"          },
  { Event::ToggleJitter,            "Toggle TV scanline 'Jitter' effect"    },
  { Event::JitterSenseDecrease,     "Decrease TV 'Jitter' sensitivity"      },
  { Event::JitterSenseIncrease,     "Increase TV 'Jitter' sensitivity"      },
  { Event::JitterRecDecrease,       "Decrease TV 'Jitter' roll"             },
  { Event::JitterRecIncrease,       "Increase TV 'Jitter' roll"             },

  // Combo
  { Event::Combo1,                  "Combo 1"                               },
  { Event::Combo2,                  "Combo 2"                               },
  { Event::Combo3,                  "Combo 3"                               },
  { Event::Combo4,                  "Combo 4"                               },
  { Event::Combo5,                  "Combo 5"                               },
  { Event::Combo6,                  "Combo 6"                               },
  { Event::Combo7,                  "Combo 7"                               },
  { Event::Combo8,                  "Combo 8"                               },
  { Event::Combo9,                  "Combo 9"                               },
  { Event::Combo10,                 "Combo 10"                              },
  { Event::Combo11,                 "Combo 11"                              },
  { Event::Combo12,                 "Combo 12"                              },
  { Event::Combo13,                 "Combo 13"                              },
  { Event::Combo14,                 "Combo 14"                              },
  { Event::Combo15,                 "Combo 15"                              },
  { Event::Combo16,                 "Combo 16"                              },
} };

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandler::MenuActionList EventHandler::ourMenuActionList = { {
  { Event::UIHelp,                  "Open context-sensitive help"           },

  { Event::UIUp,                    "Move Up"                               },
  { Event::UIDown,                  "Move Down"                             },
  { Event::UILeft,                  "Move Left"                             },
  { Event::UIRight,                 "Move Right"                            },

  { Event::UIHome,                  "Home"                                  },
  { Event::UIEnd,                   "End"                                   },
  { Event::UIPgUp,                  "Page Up"                               },
  { Event::UIPgDown,                "Page Down"                             },

  { Event::UIOK,                    "OK"                                    },
  { Event::UICancel,                "Cancel"                                },
  { Event::UISelect,                "Select item"                           },

  { Event::UINavPrev,               "Previous object"                       },
  { Event::UINavNext,               "Next object"                           },
  { Event::UITabPrev,               "Previous tab"                          },
  { Event::UITabNext,               "Next tab"                              },

  { Event::UIPrevDir,               "Parent directory"                      },
  { Event::ToggleFullScreen,        "Toggle fullscreen"                     },
  { Event::ToggleUIPalette,         "Toggle UI theme"                       },
  { Event::Quit,                    "Quit"                                  }
} };

// Event groups
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::MiscEvents = {
  Event::Quit, Event::ReloadConsole, Event::Fry, Event::StartPauseMode,
  Event::TogglePauseMode, Event::OptionsMenuMode, Event::CmdMenuMode,
  Event::ToggleBezel, Event::PlusRomsSetupMode, Event::ExitMode,
  Event::ToggleTurbo, Event::DecreaseSpeed, Event::IncreaseSpeed,
  Event::TakeSnapshot, Event::ToggleContSnapshots, Event::ToggleContSnapshotsFrame,
  // Event::MouseAxisXMove, Event::MouseAxisYMove,
  // Event::MouseButtonLeftValue, Event::MouseButtonRightValue,
  Event::HighScoresMenuMode,
  Event::PreviousMultiCartRom,
  Event::PreviousSettingGroup, Event::NextSettingGroup,
  Event::PreviousSetting, Event::NextSetting,
  Event::SettingDecrease, Event::SettingIncrease,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::AudioVideoEvents = {
  Event::VolumeDecrease, Event::VolumeIncrease, Event::SoundToggle,
  Event::VidmodeDecrease, Event::VidmodeIncrease,
  Event::ToggleFullScreen, Event::ToggleAdaptRefresh,
  Event::OverscanDecrease, Event::OverscanIncrease,
  Event::FormatDecrease, Event::FormatIncrease,
  Event::VCenterDecrease, Event::VCenterIncrease,
  Event::VSizeAdjustDecrease, Event::VSizeAdjustIncrease, Event::ToggleCorrectAspectRatio,
  Event::PaletteDecrease, Event::PaletteIncrease,
  Event::PreviousPaletteAttribute, Event::NextPaletteAttribute,
  Event::PaletteAttributeDecrease, Event::PaletteAttributeIncrease,
  Event::VidmodeStd, Event::VidmodeRGB, Event::VidmodeSVideo, Event::VidModeComposite, Event::VidModeBad, Event::VidModeCustom,
  Event::PreviousVideoMode, Event::NextVideoMode,
  Event::PreviousAttribute, Event::NextAttribute, Event::DecreaseAttribute, Event::IncreaseAttribute,
  Event::PhosphorDecrease, Event::PhosphorIncrease, Event::TogglePhosphor,
  Event::PhosphorModeDecrease, Event::PhosphorModeIncrease,
  Event::ScanlinesDecrease, Event::ScanlinesIncrease,
  Event::PreviousScanlineMask, Event::NextScanlineMask,
  Event::ToggleInter,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::StateEvents = {
  Event::NextState, Event::PreviousState, Event::LoadState, Event::SaveState,
  Event::TimeMachineMode, Event::RewindPause, Event::UnwindPause, Event::ToggleTimeMachine,
  Event::Rewind1Menu, Event::Rewind10Menu, Event::RewindAllMenu,
  Event::Unwind1Menu, Event::Unwind10Menu, Event::UnwindAllMenu,
  Event::TogglePlayBackMode,
  Event::SaveAllStates, Event::LoadAllStates, Event::ToggleAutoSlot,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::ConsoleEvents = {
  Event::ConsoleColor, Event::ConsoleBlackWhite,
  Event::ConsoleLeftDiffA, Event::ConsoleLeftDiffB,
  Event::ConsoleRightDiffA, Event::ConsoleRightDiffB,
  Event::ConsoleSelect, Event::ConsoleReset,
  Event::ConsoleLeftDiffToggle, Event::ConsoleRightDiffToggle, Event::ConsoleColorToggle,
  Event::Console7800Pause,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::JoystickEvents = {
  Event::LeftJoystickUp, Event::LeftJoystickDown, Event::LeftJoystickLeft, Event::LeftJoystickRight,
  Event::LeftJoystickFire, Event::LeftJoystickFire5, Event::LeftJoystickFire9,
  Event::RightJoystickUp, Event::RightJoystickDown, Event::RightJoystickLeft, Event::RightJoystickRight,
  Event::RightJoystickFire, Event::RightJoystickFire5, Event::RightJoystickFire9,
  Event::QTJoystickThreeUp, Event::QTJoystickThreeDown, Event::QTJoystickThreeLeft, Event::QTJoystickThreeRight,
  Event::QTJoystickThreeFire,
  Event::QTJoystickFourUp, Event::QTJoystickFourDown, Event::QTJoystickFourLeft, Event::QTJoystickFourRight,
  Event::QTJoystickFourFire,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::PaddlesEvents = {
  Event::LeftPaddleADecrease, Event::LeftPaddleAIncrease, Event::LeftPaddleAAnalog, Event::LeftPaddleAFire,
  Event::LeftPaddleBDecrease, Event::LeftPaddleBIncrease, Event::LeftPaddleBAnalog, Event::LeftPaddleBFire,
  Event::RightPaddleADecrease, Event::RightPaddleAIncrease, Event::RightPaddleAAnalog, Event::RightPaddleAFire,
  Event::RightPaddleBDecrease, Event::RightPaddleBIncrease, Event::RightPaddleBAnalog, Event::RightPaddleBFire,
  Event::QTPaddle3AFire, Event::QTPaddle3BFire,Event::QTPaddle4AFire,Event::QTPaddle4BFire,
};

const Event::EventSet EventHandler::KeyboardEvents = {
  Event::LeftKeyboard1, Event::LeftKeyboard2, Event::LeftKeyboard3,
  Event::LeftKeyboard4, Event::LeftKeyboard5, Event::LeftKeyboard6,
  Event::LeftKeyboard7, Event::LeftKeyboard8, Event::LeftKeyboard9,
  Event::LeftKeyboardStar, Event::LeftKeyboard0, Event::LeftKeyboardPound,

  Event::RightKeyboard1, Event::RightKeyboard2, Event::RightKeyboard3,
  Event::RightKeyboard4, Event::RightKeyboard5, Event::RightKeyboard6,
  Event::RightKeyboard7, Event::RightKeyboard8, Event::RightKeyboard9,
  Event::RightKeyboardStar, Event::RightKeyboard0, Event::RightKeyboardPound,
};

const Event::EventSet EventHandler::DrivingEvents = {
  Event::LeftDrivingAnalog, Event::LeftDrivingCCW, Event::LeftDrivingCW,
  Event::LeftDrivingFire, Event::RightDrivingAnalog, Event::RightDrivingCCW,
  Event::RightDrivingCW, Event::RightDrivingFire,
};

const Event::EventSet EventHandler::DevicesEvents = {
  Event::DecreaseDeadzone, Event::IncreaseDeadzone,
  Event::DecAnalogDeadzone, Event::IncAnalogDeadzone,
  Event::DecAnalogSense, Event::IncAnalogSense,
  Event::DecAnalogLinear, Event::IncAnalogLinear,
  Event::DecDejtterAveraging, Event::IncDejtterAveraging,
  Event::DecDejtterReaction, Event::IncDejtterReaction,
  Event::DecDigitalSense, Event::IncDigitalSense,
  Event::ToggleAutoFire, Event::DecreaseAutoFire, Event::IncreaseAutoFire,
  Event::ToggleFourDirections, Event::ToggleKeyCombos, Event::ToggleSAPortOrder,
  Event::PrevMouseAsController, Event::NextMouseAsController,
  Event::DecMousePaddleSense, Event::IncMousePaddleSense,
  Event::DecMouseTrackballSense, Event::IncMouseTrackballSense,
  Event::DecreaseDrivingSense, Event::IncreaseDrivingSense,
  Event::PreviousCursorVisbility, Event::NextCursorVisbility,
  Event::ToggleGrabMouse,
  Event::PreviousLeftPort, Event::NextLeftPort,
  Event::PreviousRightPort, Event::NextRightPort,
  Event::ToggleSwapPorts, Event::ToggleSwapPaddles,
  Event::DecreasePaddleCenterX, Event::IncreasePaddleCenterX,
  Event::DecreasePaddleCenterY, Event::IncreasePaddleCenterY,
  Event::PreviousMouseControl, Event::NextMouseControl,
  Event::DecreaseMouseAxesRange, Event::IncreaseMouseAxesRange,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::ComboEvents = {
  Event::Combo1, Event::Combo2, Event::Combo3, Event::Combo4,
  Event::Combo5, Event::Combo6, Event::Combo7, Event::Combo8,
  Event::Combo9, Event::Combo10, Event::Combo11, Event::Combo12,
  Event::Combo13, Event::Combo14, Event::Combo15, Event::Combo16,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const Event::EventSet EventHandler::DebugEvents = {
  Event::DebuggerMode, Event::ToggleDeveloperSet,
  Event::ToggleFrameStats,
  Event::ToggleP0Collision, Event::ToggleP0Bit, Event::ToggleP1Collision, Event::ToggleP1Bit,
  Event::ToggleM0Collision, Event::ToggleM0Bit, Event::ToggleM1Collision, Event::ToggleM1Bit,
  Event::ToggleBLCollision, Event::ToggleBLBit, Event::TogglePFCollision, Event::TogglePFBit,
  Event::ToggleCollisions, Event::ToggleBits, Event::ToggleFixedColors,
  Event::ToggleColorLoss,
  Event::ToggleJitter, Event::JitterSenseDecrease,Event::JitterSenseIncrease,
  Event::JitterRecDecrease,Event::JitterRecIncrease,
};
