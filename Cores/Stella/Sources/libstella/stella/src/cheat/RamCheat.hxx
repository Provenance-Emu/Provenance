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

#ifndef RAM_CHEAT_HXX
#define RAM_CHEAT_HXX

#include "Cheat.hxx"

class RamCheat : public Cheat
{
  public:
    RamCheat(OSystem& os, string_view name, string_view code);
    ~RamCheat() override = default;

    bool enable() override;
    bool disable() override;
    void evaluate() override;

  private:
    uInt16 address{0};
    uInt8  value{0};

  private:
    // Following constructors and assignment operators not supported
    RamCheat() = delete;
    RamCheat(const RamCheat&) = delete;
    RamCheat(RamCheat&&) = delete;
    RamCheat& operator=(const RamCheat&) = delete;
    RamCheat& operator=(RamCheat&&) = delete;
};

#endif
