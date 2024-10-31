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

#ifndef CHEAT_HXX
#define CHEAT_HXX

class OSystem;

#include "bspf.hxx"

class Cheat
{
  public:
    Cheat(OSystem& osystem, string_view name, string_view code)
      : myOSystem{osystem},
        myName{name == "" ? code : name},
        myCode{code} { }
    virtual ~Cheat() = default;

    bool enabled() const { return myEnabled; }
    const string& name() const { return myName; }
    const string& code() const { return myCode; }

    virtual bool enable() = 0;
    virtual bool disable() = 0;

    virtual void evaluate() = 0;

  protected:
    OSystem& myOSystem;

    string myName;
    string myCode;

    bool myEnabled{false};

  private:
    // Following constructors and assignment operators not supported
    Cheat() = delete;
    Cheat(const Cheat&) = delete;
    Cheat(Cheat&&) = delete;
    Cheat& operator=(const Cheat&) = delete;
    Cheat& operator=(Cheat&&) = delete;
};

#endif
