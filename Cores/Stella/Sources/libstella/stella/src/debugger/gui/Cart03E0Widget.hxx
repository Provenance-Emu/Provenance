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

#ifndef CARTRIDGE03E0_WIDGET_HXX
#define CARTRIDGE03E0_WIDGET_HXX

class Cartridge03E0;

#include "CartEnhancedWidget.hxx"

class Cartridge03E0Widget : public CartridgeEnhancedWidget
{
  public:
    Cartridge03E0Widget(GuiObject* boss, const GUI::Font& lfont,
      const GUI::Font& nfont,
      int x, int y, int w, int h,
      Cartridge03E0& cart);
    ~Cartridge03E0Widget() override = default;

  private:
    string manufacturer() override { return "Parker Brothers (Brazil Pirate)"; }

    string description() override;

    string romDescription() override;

    string hotspotStr(int bank, int segment, bool noBrackets = false) override;

    uInt16 bankSegs() override { return 3; }

  private:
    // Following constructors and assignment operators not supported
    Cartridge03E0Widget() = delete;
    Cartridge03E0Widget(const Cartridge03E0Widget&) = delete;
    Cartridge03E0Widget(Cartridge03E0Widget&&) = delete;
    Cartridge03E0Widget& operator=(const Cartridge03E0Widget&) = delete;
    Cartridge03E0Widget& operator=(Cartridge03E0Widget&&) = delete;
};

#endif
