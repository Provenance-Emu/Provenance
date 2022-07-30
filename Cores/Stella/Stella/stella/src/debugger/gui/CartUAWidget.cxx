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

#include "CartUA.hxx"
#include "CartUAWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeUAWidget::CartridgeUAWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeUA& cart, bool swapHotspots)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart),
    mySwappedHotspots{swapHotspots}
{
  myHotspotDelta = 0x20;
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeUAWidget::description()
{
  ostringstream info;

  info << "8K UA cartridge" << (mySwappedHotspots ? " (swapped banks)" : "")
       << ", two 4K banks\n"
       << CartridgeEnhancedWidget::description();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeUAWidget::hotspotStr(int bank, int, bool prefix)
{
  ostringstream info;
  const uInt16 hotspot = myCart.hotspot() + (bank ^ (mySwappedHotspots ? 1 : 0)) * myHotspotDelta;

  info << "(" << (prefix ? "hotspot " : "")
       << "$" << Common::Base::HEX1 << hotspot << ", $" << (hotspot | 0x80) << ")";

  return info.str();
}
