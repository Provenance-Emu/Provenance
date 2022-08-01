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

#ifndef CARTRIDGE0840_WIDGET_HXX
#define CARTRIDGE0840_WIDGET_HXX

class Cartridge0840;

#include "CartEnhancedWidget.hxx"

class Cartridge0840Widget : public CartridgeEnhancedWidget
{
  public:
    Cartridge0840Widget(GuiObject* boss, const GUI::Font& lfont,
                        const GUI::Font& nfont,
                        int x, int y, int w, int h,
                        Cartridge0840& cart);
    ~Cartridge0840Widget() override = default;

  private:
    string manufacturer() override { return "Fred X. Quimby"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    Cartridge0840Widget() = delete;
    Cartridge0840Widget(const Cartridge0840Widget&) = delete;
    Cartridge0840Widget(Cartridge0840Widget&&) = delete;
    Cartridge0840Widget& operator=(const Cartridge0840Widget&) = delete;
    Cartridge0840Widget& operator=(Cartridge0840Widget&&) = delete;
};

#endif
