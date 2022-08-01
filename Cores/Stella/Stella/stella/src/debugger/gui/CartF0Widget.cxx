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

#include "CartF0.hxx"
#include "CartF0Widget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeF0Widget::CartridgeF0Widget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeF0& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart)
{
  myHotspotDelta = 0;
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeF0Widget::description()
{
  ostringstream info;

  info << "Megaboy F0 cartridge, 16 4K banks\n"
       << "Startup bank = #" << myCart.startBank() << " or undetermined\n"
       << "Bankswitch triggered by accessing $" << Common::Base::HEX4 << 0xFFF0 << "\n";

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeF0Widget::bankState()
{
  ostringstream& buf = buffer();

  buf << "Bank #" << std::dec << myCart.getBank()
      << " (hotspot $" << Common::Base::HEX4 << 0xFFF0 << ")";

  return buf.str();
}
