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

#include "CartSB.hxx"
#include "CartSBWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeSBWidget::CartridgeSBWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeSB& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart)
{
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeSBWidget::description()
{
  ostringstream info;

  info << "SB SUPERbanking, " << myCart.romBankCount() << " 4K banks\n"
       << "Hotspots are from $800 to $"
       << Common::Base::HEX2 << (0x800 + myCart.romBankCount() - 1) << ", including\n"
       << "mirrors ($900, $" << 0xA00 << ", $" << 0xB00 << ", ...)\n"
       << CartridgeEnhancedWidget::description();

  return info.str();
}
