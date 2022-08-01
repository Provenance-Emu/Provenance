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

#ifndef CARTRIDGEF0_WIDGET_HXX
#define CARTRIDGEF0_WIDGET_HXX

class CartridgeF0;

#include "CartEnhancedWidget.hxx"

class CartridgeF0Widget : public CartridgeEnhancedWidget
{
  public:
    CartridgeF0Widget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeF0& cart);
    ~CartridgeF0Widget() override = default;

  private:
    string manufacturer() override { return "Dynacom Megaboy"; }

    string description() override;

    string bankState() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeF0Widget() = delete;
    CartridgeF0Widget(const CartridgeF0Widget&) = delete;
    CartridgeF0Widget(CartridgeF0Widget&&) = delete;
    CartridgeF0Widget& operator=(const CartridgeF0Widget&) = delete;
    CartridgeF0Widget& operator=(CartridgeF0Widget&&) = delete;
};

#endif
