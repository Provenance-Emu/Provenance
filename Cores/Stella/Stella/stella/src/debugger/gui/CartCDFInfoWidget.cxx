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

#include "CartCDFInfoWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeCDFInfoWidget::CartridgeCDFInfoWidget(
    GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
    int x, int y, int w, int h, CartridgeCDF& cart)
  : CartDebugWidget(boss, lfont, nfont, x, y, w, h)
{
  ostringstream info;

  info << describeCDFVersion(cart.myCDFSubtype) << " cartridge\n"
       << (cart.romSize() / 1024) << "K ROM\n"
       << (cart.ramSize() / 1024) << "K RAM\n"
       << "Seven 4K banks are available to 2600\n"
       << "Functions accessible @ $FFF0 - $FFF3\n"
       << (cart.isCDFJplus() ? "Banks accessible @ $FFF4 to $FFFA\n" : "Banks accessible @ $FFF5 to $FFFB\n")
       << "Startup bank = " << cart.startBank() << "\n"
       << "Fast Fetcher(s): LDA #";

  if (cart.myLDXenabled)
    info << ", LDX #";

  if (cart.myLDYenabled)
    info << ", LDY #";

  info << "\n";

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

  addBaseInformation(cart.romSize(), "AtariAge", info.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeCDFInfoWidget::describeCDFVersion(CartridgeCDF::CDFSubtype subtype)
{
  switch(subtype)
  {
    case CartridgeCDF::CDFSubtype::CDF0:
      return "CDF (v0)";

    case CartridgeCDF::CDFSubtype::CDF1:
      return "CDF (v1)";

    case CartridgeCDF::CDFSubtype::CDFJ:
      return "CDFJ";

    case CartridgeCDF::CDFSubtype::CDFJplus:
      return "CDFJ+";

    default:
      throw runtime_error("unreachable");
  }
}
