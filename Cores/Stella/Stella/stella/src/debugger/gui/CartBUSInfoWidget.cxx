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

#include "CartBUSInfoWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeBUSInfoWidget::CartridgeBUSInfoWidget(
    GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
    int x, int y, int w, int h, CartridgeBUS& cart)
  : CartDebugWidget(boss, lfont, nfont, x, y, w, h)
{
  constexpr uInt16 size = 8 * 4096;
  ostringstream info;

  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS0)
  {
    info << "BUS Stuffing cartridge (EXPERIMENTAL)\n"
         << "32K ROM, six 4K banks are accessible to 2600\n"
         << "8K BUS RAM\n"
         << "BUS registers accessible @ $F000 - $F03F\n"
         << "Banks accessible at hotspots $FFF6 to $FFFB\n"
         << "Startup bank = " << cart.startBank() << "\n";
  }
  else
  {
    info << "BUS Stuffing cartridge (EXPERIMENTAL)\n"
         << "32K ROM, seven 4K banks are accessible to 2600\n"
         << "8K BUS RAM\n"
         <<  (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3 ?
             "BUS registers accessible @ $FFEE - $FFF3\n" : // BUS3
             "BUS registers accessible @ $F000 - $F01A\n")  // BUS1, BUS2
         << "Banks accessible at hotspots $FFF5 to $FFFB\n"
         << "Startup bank = " << cart.startBank() << "\n";
  }
#if 0
  // Eventually, we should query this from the debugger/disassembler
  for(uInt32 i = 0, offset = 0xFFC, spot = 0xFF5; i < 7; ++i, offset += 0x1000)
  {
    uInt16 start = (cart.myImage[offset+1] << 8) | cart.myImage[offset];
    start -= start % 0x1000;
    info << "Bank " << i << " @ $" << HEX4 << (start + 0x80) << " - "
    << "$" << (start + 0xFFF) << " (hotspot = $" << (spot+i) << ")\n";
  }
#endif

  addBaseInformation(size, "AtariAge", info.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeBUSInfoWidget::describeBUSVersion(CartridgeBUS::BUSSubtype subtype)
{
  switch(subtype)
  {
    case CartridgeBUS::BUSSubtype::BUS0:
      return "BUS (v0)";

    case CartridgeBUS::BUSSubtype::BUS1:
      return "BUS (v1)";

    case CartridgeBUS::BUSSubtype::BUS2:
      return "BUS (v2)";

    case CartridgeBUS::BUSSubtype::BUS3:
      return "BUS (v3)";
    default:
      throw runtime_error("unreachable");
  }
}
