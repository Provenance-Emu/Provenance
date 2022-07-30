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

#ifndef CARTRIDGE4K_WIDGET_HXX
#define CARTRIDGE4K_WIDGET_HXX

class Cartridge4K;

#include "CartEnhanced.hxx"

class Cartridge4KWidget : public CartridgeEnhancedWidget
{
  public:
    Cartridge4KWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      Cartridge4K& cart);
    ~Cartridge4KWidget() override = default;

  private:
    string manufacturer() override { return "Atari"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    Cartridge4KWidget() = delete;
    Cartridge4KWidget(const Cartridge4KWidget&) = delete;
    Cartridge4KWidget(Cartridge4KWidget&&) = delete;
    Cartridge4KWidget& operator=(const Cartridge4KWidget&) = delete;
    Cartridge4KWidget& operator=(Cartridge4KWidget&&) = delete;
};

#endif
