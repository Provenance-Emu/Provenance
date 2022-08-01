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

#include "Cart3F.hxx"
#include "Cart3FWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge3FWidget::Cartridge3FWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, Cartridge3F& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart)
{
  myHotspotDelta = 0;
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge3FWidget::description()
{
  ostringstream info;
  size_t size = 0;
  const ByteBuffer& image = myCart.getImage(size);

  info << "Tigervision 3F cartridge, 2 - 256 2K banks\n"
       << "First 2K bank selected by writing to " << hotspotStr() << "\n"
       << "Last 2K always points to last 2K of ROM\n"
       << "Startup bank = " << myCart.startBank() << " or undetermined\n";
  // Eventually, we should query this from the debugger/disassembler
  uInt16 start = (image[size-3] << 8) | image[size-4];
  start -= start % 0x1000;
  info << "Bank RORG $" << Common::Base::HEX4 << start << "\n";

  return info.str();
}
