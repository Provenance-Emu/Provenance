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

#ifndef CARTRIDGEBR_WIDGET_HXX
#define CARTRIDGEBR_WIDGET_HXX

class Cartridge0FA0;

#include "CartEnhancedWidget.hxx"

class Cartridge0FA0Widget : public CartridgeEnhancedWidget
{
  public:
    Cartridge0FA0Widget(GuiObject* boss, const GUI::Font& lfont,
                        const GUI::Font& nfont,
                        int x, int y, int w, int h,
                        Cartridge0FA0& cart);
    ~Cartridge0FA0Widget() override = default;

  private:
    string manufacturer() override { return "Fotomania"; }

    string description() override;

    string hotspotStr(int bank, int seg, bool prefix = false) override;

  private:
    // Following constructors and assignment operators not supported
    Cartridge0FA0Widget() = delete;
    Cartridge0FA0Widget(const Cartridge0FA0Widget&) = delete;
    Cartridge0FA0Widget(Cartridge0FA0Widget&&) = delete;
    Cartridge0FA0Widget& operator=(const Cartridge0FA0Widget&) = delete;
    Cartridge0FA0Widget& operator=(Cartridge0FA0Widget&&) = delete;
};

#endif
