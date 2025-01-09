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

#include "Logger.hxx"
#include "OSystem.hxx"
#include "EventHandlerSDL2.hxx"

#include "ThreadDebugging.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandlerSDL2::EventHandlerSDL2(OSystem& osystem)
  : EventHandler{osystem}
{
  ASSERT_MAIN_THREAD;

#ifdef GUI_SUPPORT
  {
    ostringstream buf;
    myQwertz = int{'y'} == static_cast<int>
      (SDL_GetKeyFromScancode(static_cast<SDL_Scancode>(KBDK_Z)));
    buf << "Keyboard: " << (myQwertz ? "QWERTZ" : "QWERTY");
    Logger::debug(buf.str());
  }
#endif

#ifdef JOYSTICK_SUPPORT
  if(SDL_InitSubSystem(SDL_INIT_JOYSTICK) < 0)
  {
    ostringstream buf;
    buf << "ERROR: Couldn't initialize SDL joystick support: "
        << SDL_GetError() << '\n';
    Logger::error(buf.str());
  }
  Logger::debug("EventHandlerSDL2::EventHandlerSDL2 SDL_INIT_JOYSTICK");
#endif

  SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, "1");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandlerSDL2::~EventHandlerSDL2()
{
  ASSERT_MAIN_THREAD;

  if(SDL_WasInit(SDL_INIT_JOYSTICK))
    SDL_QuitSubSystem(SDL_INIT_JOYSTICK);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandlerSDL2::enableTextEvents(bool enable)
{
  ASSERT_MAIN_THREAD;

  if(enable)
    SDL_StartTextInput();
  else
    SDL_StopTextInput();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandlerSDL2::copyText(const string& text) const
{
  SDL_SetClipboardText(text.c_str());
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string EventHandlerSDL2::pasteText(string& text) const
{
  if(SDL_HasClipboardText())
    text = SDL_GetClipboardText();
  else
    text = "";

  return text;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EventHandlerSDL2::pollEvent()
{
  ASSERT_MAIN_THREAD;

  while(SDL_PollEvent(&myEvent))
  {
    switch(myEvent.type)
    {
      // keyboard events
      case SDL_KEYUP:
      case SDL_KEYDOWN:
      {
        handleKeyEvent(static_cast<StellaKey>(myEvent.key.keysym.scancode),
                       static_cast<StellaMod>(myEvent.key.keysym.mod),
                       myEvent.key.type == SDL_KEYDOWN,
                       myEvent.key.repeat);
        break;
      }

      case SDL_TEXTINPUT:
      {
        handleTextEvent(*(myEvent.text.text));
        break;
      }

      case SDL_MOUSEMOTION:
      {
        handleMouseMotionEvent(myEvent.motion.x, myEvent.motion.y,
                               myEvent.motion.xrel, myEvent.motion.yrel);
        break;
      }

      case SDL_MOUSEBUTTONDOWN:
      case SDL_MOUSEBUTTONUP:
      {
        // ToDo: check support of more buttons and double-click
        MouseButton b{MouseButton::NONE};
        switch(myEvent.button.button)
        {
          case SDL_BUTTON_LEFT:
            b = MouseButton::LEFT;
            break;
          case SDL_BUTTON_RIGHT:
            b = MouseButton::RIGHT;
            break;
          case SDL_BUTTON_MIDDLE:
            b = MouseButton::MIDDLE;
            break;
          default:
            break;
        }
        handleMouseButtonEvent(b, myEvent.button.type == SDL_MOUSEBUTTONDOWN,
                               myEvent.button.x, myEvent.button.y);
        break;
      }

      case SDL_MOUSEWHEEL:
      {
        int x{0}, y{0};
        SDL_GetMouseState(&x, &y);  // we need mouse position too
        if(myEvent.wheel.y < 0)
          handleMouseButtonEvent(MouseButton::WHEELDOWN, true, x, y);
        else if(myEvent.wheel.y > 0)
          handleMouseButtonEvent(MouseButton::WHEELUP, true, x, y);
        break;
      }

  #ifdef JOYSTICK_SUPPORT
      case SDL_JOYBUTTONUP:
      case SDL_JOYBUTTONDOWN:
      {
        handleJoyBtnEvent(myEvent.jbutton.which, myEvent.jbutton.button,
                          myEvent.jbutton.state == SDL_PRESSED);
        break;
      }

      case SDL_JOYAXISMOTION:
      {
        handleJoyAxisEvent(myEvent.jaxis.which, myEvent.jaxis.axis,
                           myEvent.jaxis.value);
        break;
      }

      case SDL_JOYHATMOTION:
      {
        int value = 0;
        const int v = myEvent.jhat.value;
        if(v == SDL_HAT_CENTERED)
          value  = EVENT_HATCENTER_M;
        else
        {
          if(v & SDL_HAT_UP)    value |= EVENT_HATUP_M;
          if(v & SDL_HAT_DOWN)  value |= EVENT_HATDOWN_M;
          if(v & SDL_HAT_LEFT)  value |= EVENT_HATLEFT_M;
          if(v & SDL_HAT_RIGHT) value |= EVENT_HATRIGHT_M;
        }

        handleJoyHatEvent(myEvent.jhat.which, myEvent.jhat.hat, value);
        break;  // SDL_JOYHATMOTION
      }

      case SDL_JOYDEVICEADDED:
      {
        addPhysicalJoystick(make_shared<JoystickSDL2>(myEvent.jdevice.which));
        break;  // SDL_JOYDEVICEADDED
      }
      case SDL_JOYDEVICEREMOVED:
      {
        removePhysicalJoystick(myEvent.jdevice.which);
        break;  // SDL_JOYDEVICEREMOVED
      }
  #endif

      case SDL_QUIT:
      {
        handleEvent(Event::Quit);
        break;  // SDL_QUIT
      }

      case SDL_WINDOWEVENT:
        switch(myEvent.window.event)
        {
          case SDL_WINDOWEVENT_SHOWN:
            handleSystemEvent(SystemEvent::WINDOW_SHOWN);
            break;
          case SDL_WINDOWEVENT_HIDDEN:
            handleSystemEvent(SystemEvent::WINDOW_HIDDEN);
            break;
          case SDL_WINDOWEVENT_EXPOSED:
            handleSystemEvent(SystemEvent::WINDOW_EXPOSED);
            break;
          case SDL_WINDOWEVENT_MOVED:
            handleSystemEvent(SystemEvent::WINDOW_MOVED,
                              myEvent.window.data1, myEvent.window.data1);
            break;
          case SDL_WINDOWEVENT_RESIZED:
            handleSystemEvent(SystemEvent::WINDOW_RESIZED,
                              myEvent.window.data1, myEvent.window.data1);
            break;
          case SDL_WINDOWEVENT_MINIMIZED:
            handleSystemEvent(SystemEvent::WINDOW_MINIMIZED);
            break;
          case SDL_WINDOWEVENT_MAXIMIZED:
            handleSystemEvent(SystemEvent::WINDOW_MAXIMIZED);
            break;
          case SDL_WINDOWEVENT_RESTORED:
            handleSystemEvent(SystemEvent::WINDOW_RESTORED);
            break;
          case SDL_WINDOWEVENT_ENTER:
            handleSystemEvent(SystemEvent::WINDOW_ENTER);
            break;
          case SDL_WINDOWEVENT_LEAVE:
            handleSystemEvent(SystemEvent::WINDOW_LEAVE);
            break;
          case SDL_WINDOWEVENT_FOCUS_GAINED:
            handleSystemEvent(SystemEvent::WINDOW_FOCUS_GAINED);
            break;
          case SDL_WINDOWEVENT_FOCUS_LOST:
            handleSystemEvent(SystemEvent::WINDOW_FOCUS_LOST);
            break;
          default:
            break;
        }
        break;  // SDL_WINDOWEVENT

      default:
        break;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandlerSDL2::JoystickSDL2::JoystickSDL2(int idx)
{
  ASSERT_MAIN_THREAD;

  myStick = SDL_JoystickOpen(idx);
  if(myStick)
  {
    // In Windows, all XBox controllers using the XInput API seem to name
    // the controller as "XInput Controller".  This would be fine, except
    // it also appends " #x", where x seems to vary. Obviously this wreaks
    // havoc with the idea that a joystick will always have the same name.
    // So we truncate the number.
    const char* const sdlname = SDL_JoystickName(myStick);
    const string& desc = BSPF::startsWithIgnoreCase(sdlname, "XInput Controller")
                         ? "XInput Controller" : sdlname;

    initialize(SDL_JoystickInstanceID(myStick), desc,
        SDL_JoystickNumAxes(myStick), SDL_JoystickNumButtons(myStick),
        SDL_JoystickNumHats(myStick), SDL_JoystickNumBalls(myStick));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EventHandlerSDL2::JoystickSDL2::~JoystickSDL2()
{
  ASSERT_MAIN_THREAD;

  if(SDL_WasInit(SDL_INIT_JOYSTICK) && myStick)
    SDL_JoystickClose(myStick);
}
