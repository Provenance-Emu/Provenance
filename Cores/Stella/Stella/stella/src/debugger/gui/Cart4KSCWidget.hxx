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

#ifndef CARTRIDGE4KSC_WIDGET_HXX
#define CARTRIDGE4KSC_WIDGET_HXX

class Cartridge4KSC;

#include "CartEnhancedWidget.hxx"

class Cartridge4KSCWidget : public CartridgeEnhancedWidget
{
  public:
    Cartridge4KSCWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      Cartridge4KSC& cart);
    ~Cartridge4KSCWidget() override = default;

  private:
    string manufacturer() override { return "homebrew intermediate format"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    Cartridge4KSCWidget() = delete;
    Cartridge4KSCWidget(const Cartridge4KSCWidget&) = delete;
    Cartridge4KSCWidget(Cartridge4KSCWidget&&) = delete;
    Cartridge4KSCWidget& operator=(const Cartridge4KSCWidget&) = delete;
    Cartridge4KSCWidget& operator=(Cartridge4KSCWidget&&) = delete;
};

#endif
