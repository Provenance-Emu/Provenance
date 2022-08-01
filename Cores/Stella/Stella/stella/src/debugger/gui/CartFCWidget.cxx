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

#include "CartFC.hxx"
#include "CartFCWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeFCWidget::CartridgeFCWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeFC& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart)
{
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeFCWidget::description()
{
  ostringstream info;
  const uInt16 hotspot = myCart.hotspot() | ADDR_BASE;

  info << "FC cartridge, up to eight 4K banks\n"
       << "Bank selected by hotspots\n"
       << "  $" << Common::Base::HEX4 << hotspot << " (defines low 2 bits)\n"
       << "  $" << Common::Base::HEX4 << (hotspot + 1) << " (defines high bits)\n"
       << "  $" << Common::Base::HEX4 << (hotspot + 4) << " (triggers bank switch)\n"
       << CartridgeEnhancedWidget::description();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeFCWidget::hotspotStr(int bank, int, bool prefix)
{
  ostringstream info;
  const uInt16 hotspot = myCart.hotspot() | ADDR_BASE;

  info << "(" << (prefix ? "hotspots " : "")
       << "$" << Common::Base::HEX4 << hotspot << " = " << (bank & 0b11)
       << ", $" << Common::Base::HEX4 << (hotspot + 1) << " = " << (bank >> 2)
       << ")";

  return info.str();
}
