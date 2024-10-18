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

#ifndef EVENTHANDLER_LIBRETRO_HXX
#define EVENTHANDLER_LIBRETRO_HXX

#include "EventHandler.hxx"

/**
  This class handles event collection from the point of view of the specific
  backend toolkit (LIBRETRO).  It converts from LIBRETRO-specific events into events
  that the Stella core can understand.

  @author  Stephen Anthony
*/
class EventHandlerLIBRETRO : public EventHandler
{
  public:
    /**
      Create a new LIBRETRO event handler object
    */
    explicit EventHandlerLIBRETRO(OSystem& osystem) : EventHandler(osystem) { }
    ~EventHandlerLIBRETRO() override = default;

  private:
    /**
      Enable/disable text events (distinct from single-key events).
    */
    void enableTextEvents(bool enable) override { }

    /**
      Collects and dispatches any pending SDL2 events.
    */
    void pollEvent() override { }

  private:
    // Following constructors and assignment operators not supported
    EventHandlerLIBRETRO() = delete;
    EventHandlerLIBRETRO(const EventHandlerLIBRETRO&) = delete;
    EventHandlerLIBRETRO(EventHandlerLIBRETRO&&) = delete;
    EventHandlerLIBRETRO& operator=(const EventHandlerLIBRETRO&) = delete;
    EventHandlerLIBRETRO& operator=(EventHandlerLIBRETRO&&) = delete;
};

#endif
