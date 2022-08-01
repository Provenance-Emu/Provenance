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

#ifndef CONSOLE_IO_HXX
#define CONSOLE_IO_HXX

class Controller;
class Switches;

class ConsoleIO
{
  public:
    /**
      Get the controller plugged into the specified jack

      @return The specified controller
    */
    virtual Controller& leftController() const = 0;
    virtual Controller& rightController() const = 0;

    /**
      Get the console switches

      @return The console switches
    */
    virtual Switches& switches() const = 0;

    ConsoleIO() = default;
    virtual ~ConsoleIO() = default;

  private:
    // Following constructors and assignment operators not supported
    ConsoleIO(const ConsoleIO&) = delete;
    ConsoleIO(ConsoleIO&&) = delete;
    ConsoleIO& operator=(const ConsoleIO&) = delete;
    ConsoleIO& operator=(ConsoleIO&&) = delete;
};

#endif // CONSOLE_IO_HXX
