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

#ifndef BANK_ROM_CHEAT_HXX
#define BANK_ROM_CHEAT_HXX

#include "Cheat.hxx"

class BankRomCheat : public Cheat
{
  public:
    BankRomCheat(OSystem& os, string_view name, string_view code);
    ~BankRomCheat() override = default;

    bool enable() override;
    bool disable() override;
    void evaluate() override;

  private:
    std::array<uInt8, 16> savedRom;
    uInt16 address{0};
    uInt8  value{0};
    uInt8  count{0};
    int    bank{0};

  private:
    // Following constructors and assignment operators not supported
    BankRomCheat() = delete;
    BankRomCheat(const BankRomCheat&) = delete;
    BankRomCheat(BankRomCheat&&) = delete;
    BankRomCheat& operator=(const BankRomCheat&) = delete;
    BankRomCheat& operator=(BankRomCheat&&) = delete;
};

#endif
