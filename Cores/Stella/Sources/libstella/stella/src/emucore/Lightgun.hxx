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

#ifndef LIGHTGUN_HXX
#define LIGHTGUN_HXX

class FrameBuffer;

#include "bspf.hxx"
#include "Control.hxx"

/**
  This class handles the lightgun controller

  @author  Thomas Jentzsch
*/

class Lightgun : public Controller
{
  public:
    /**
      Create a new lightgun controller plugged into the specified jack

      @param jack        The jack the controller is plugged into
      @param event       The event object to use for events
      @param system      The system using this controller
      @param romMd5      The md5 of the ROM using this controller
      @param frameBuffer The frame buffer

    */
    Lightgun(Jack jack, const Event& event, const System& system,
             string_view romMd5, const FrameBuffer& frameBuffer);
    ~Lightgun() override = default;

  public:
    using Controller::read;

    /**
      Read the value of the specified digital pin for this controller.

      @param pin The pin of the controller jack to read
      @return The state of the pin
    */
    bool read(DigitalPin pin) override;

    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "Light Gun"; }

  private:
    const FrameBuffer& myFrameBuffer;

    // targetting compensation values
    Int32 myOfsX{0}, myOfsY{0};

  private:
    // Following constructors and assignment operators not supported
    Lightgun() = delete;
    Lightgun(const Lightgun&) = delete;
    Lightgun(Lightgun&&) = delete;
    Lightgun& operator=(const Lightgun&) = delete;
    Lightgun& operator=(Lightgun&&) = delete;
};

#endif
