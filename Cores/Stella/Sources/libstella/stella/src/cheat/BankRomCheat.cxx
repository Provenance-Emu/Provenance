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

#include "Console.hxx"
#include "Cart.hxx"
#include "OSystem.hxx"
#include "BankRomCheat.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BankRomCheat::BankRomCheat(OSystem& os, string_view name, string_view code)
  : Cheat(os, name, code)
{
  if(myCode.length() == 7)
    myCode = "0" + string{code};

  bank = BSPF::stoi<16>(myCode.substr(0, 2));
  address = 0xf000 + BSPF::stoi<16>(myCode.substr(2, 3));
  value = static_cast<uInt8>(BSPF::stoi<16>(myCode.substr(5, 2)));
  count = static_cast<uInt8>(BSPF::stoi<16>(myCode.substr(7, 1)) + 1);

  // Back up original data; we need this if the cheat is ever disabled
  for(int i = 0; i < count; ++i)
    savedRom[i] = myOSystem.console().cartridge().peek(address + i);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool BankRomCheat::enable()
{
  evaluate();
  return myEnabled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool BankRomCheat::disable()
{
  const int oldBank = myOSystem.console().cartridge().getBank(address);
  myOSystem.console().cartridge().bank(bank);

  for(int i = 0; i < count; ++i)
    myOSystem.console().cartridge().patch(address + i, savedRom[i]);

  myOSystem.console().cartridge().bank(oldBank);

  return myEnabled = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void BankRomCheat::evaluate()
{
  if(!myEnabled)
  {
    const int oldBank = myOSystem.console().cartridge().getBank(address);
    myOSystem.console().cartridge().bank(bank);

    for(int i = 0; i < count; ++i)
      myOSystem.console().cartridge().patch(address + i, value);

    myOSystem.console().cartridge().bank(oldBank);

    myEnabled = true;
  }
}
