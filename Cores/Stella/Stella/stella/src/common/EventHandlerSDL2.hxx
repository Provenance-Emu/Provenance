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

#ifndef EVENTHANDLER_SDL2_HXX
#define EVENTHANDLER_SDL2_HXX

#include "SDL_lib.hxx"
#include "EventHandler.hxx"
#include "PhysicalJoystick.hxx"

/**
  This class handles event collection from the point of view of the specific
  backend toolkit (SDL2).  It converts from SDL2-specific events into events
  that the Stella core can understand.

  @author  Stephen Anthony
*/
class EventHandlerSDL2 : public EventHandler
{
  public:
    /**
      Create a new SDL2 event handler object
    */
    explicit EventHandlerSDL2(OSystem& osystem);
    ~EventHandlerSDL2() override;

  private:
    /**
      Enable/disable text events (distinct from single-key events).
    */
    void enableTextEvents(bool enable) override;

    /**
      Clipboard methods.
    */
    void copyText(const string& text) const override;
    string pasteText(string& text) const override;

    /**
      Collects and dispatches any pending SDL2 events.
    */
    void pollEvent() override;

  private:
    SDL_Event myEvent{0};

    // A thin wrapper around a basic PhysicalJoystick, holding the pointer to
    // the underlying SDL joystick device.
    class JoystickSDL2 : public PhysicalJoystick
    {
      public:
        explicit JoystickSDL2(int idx);
        virtual ~JoystickSDL2();

      private:
        SDL_Joystick* myStick{nullptr};

      private:
        // Following constructors and assignment operators not supported
        JoystickSDL2() = delete;
        JoystickSDL2(const JoystickSDL2&) = delete;
        JoystickSDL2(JoystickSDL2&&) = delete;
        JoystickSDL2& operator=(const JoystickSDL2&) = delete;
        JoystickSDL2& operator=(JoystickSDL2&&) = delete;
    };

  private:
    // Following constructors and assignment operators not supported
    EventHandlerSDL2() = delete;
    EventHandlerSDL2(const EventHandlerSDL2&) = delete;
    EventHandlerSDL2(EventHandlerSDL2&&) = delete;
    EventHandlerSDL2& operator=(const EventHandlerSDL2&) = delete;
    EventHandlerSDL2& operator=(EventHandlerSDL2&&) = delete;
};

#endif
