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

#ifndef CARTRIDGEE0_WIDGET_HXX
#define CARTRIDGEE0_WIDGET_HXX

class CartridgeE0;

#include "CartEnhancedWidget.hxx"

class CartridgeE0Widget : public CartridgeEnhancedWidget
{
  public:
    CartridgeE0Widget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeE0& cart);
    ~CartridgeE0Widget() override = default;

  private:
    string manufacturer() override { return "Parker Brothers"; }

    string description() override;

    string romDescription() override;

    string hotspotStr(int bank, int segment, bool noBrackets = false) override;

    uInt16 bankSegs() override { return 3; }

  private:
    // Following constructors and assignment operators not supported
    CartridgeE0Widget() = delete;
    CartridgeE0Widget(const CartridgeE0Widget&) = delete;
    CartridgeE0Widget(CartridgeE0Widget&&) = delete;
    CartridgeE0Widget& operator=(const CartridgeE0Widget&) = delete;
    CartridgeE0Widget& operator=(CartridgeE0Widget&&) = delete;
};

#endif
