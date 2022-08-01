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

#include "Cart0FA0.hxx"
#include "Cart0FA0Widget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge0FA0Widget::Cartridge0FA0Widget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, Cartridge0FA0& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart)
{
  myHotspotDelta = 0x20;
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge0FA0Widget::description()
{
  ostringstream info;

  info << "8K BR cartridge, two 4K banks\n"
    << CartridgeEnhancedWidget::description();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge0FA0Widget::hotspotStr(int bank, int, bool prefix)
{
  ostringstream info;
  const uInt16 hotspot = myCart.hotspot() + bank * myHotspotDelta;

  info << "(" << (prefix ? "hotspot " : "")
    << "$" << Common::Base::HEX1 << hotspot
    << ", $" << (hotspot | 0xf80) << ")";

  return info.str();
}
