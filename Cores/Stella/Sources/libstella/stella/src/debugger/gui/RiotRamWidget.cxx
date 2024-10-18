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

#include "OSystem.hxx"
#include "Debugger.hxx"
#include "CartDebug.hxx"

#include "RiotRamWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RiotRamWidget::RiotRamWidget(GuiObject* boss, const GUI::Font& lfont,
        const GUI::Font& nfont, int x, int y, int w)
  : RamWidget(boss, lfont, nfont, x, y, w, 0, 128, 8, 128, "M6532"),
    myDbg{instance().debugger().cartDebug()}
{
  // setHelpAnchor("M6532"); TODO: does not work due to use of "boss" insted of "this"
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 RiotRamWidget::getValue(int addr) const
{
  const auto& state = static_cast<const CartState&>(myDbg.getState());
  return instance().debugger().peek(state.rport[addr]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RiotRamWidget::setValue(int addr, uInt8 value)
{
  const auto& state = static_cast<const CartState&>(myDbg.getState());
  instance().debugger().poke(state.wport[addr], value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string RiotRamWidget::getLabel(int addr) const
{
  const auto& state = static_cast<const CartState&>(myDbg.getState());
  return myDbg.getLabel(state.rport[addr], true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RiotRamWidget::fillList(uInt32 start, uInt32 size, IntArray& alist,
                             IntArray& vlist, BoolArray& changed) const
{
  const auto& state    = static_cast<const CartState&>(myDbg.getState());
  const auto& oldstate = static_cast<const CartState&>(myDbg.getOldState());

  for(uInt32 i = 0; i < size; ++i)
  {
    alist.push_back(i+start);
    vlist.push_back(state.ram[i]);
    changed.push_back(state.ram[i] != oldstate.ram[i]);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 RiotRamWidget::readPort(uInt32 start) const
{
  const auto& state = static_cast<const CartState&>(myDbg.getState());
  return state.rport[start];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteArray& RiotRamWidget::currentRam(uInt32) const
{
  const auto& state = static_cast<const CartState&>(myDbg.getState());
  return state.ram;
}
