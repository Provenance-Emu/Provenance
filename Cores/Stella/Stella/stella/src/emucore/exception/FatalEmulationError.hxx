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

#ifndef FATAL_EMULATION_ERROR_HXX
#define FATAL_EMULATION_ERROR_HXX

#include "bspf.hxx"

class FatalEmulationError : public std::exception
{
  public:
    explicit FatalEmulationError(const string& message) : myMessage{message} { }

    const char* what() const noexcept override { return myMessage.c_str(); }

    [[noreturn]] static void raise(const string& message) {
      throw FatalEmulationError(message);
    }

  private:
    const string myMessage;
};

#endif // FATAL_EMULATION_ERROR_HXX
