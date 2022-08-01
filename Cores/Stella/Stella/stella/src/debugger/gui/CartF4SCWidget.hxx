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

#ifndef CARTRIDGEF4SC_WIDGET_HXX
#define CARTRIDGEF4SC_WIDGET_HXX

class CartridgeF4SC;

#include "CartEnhancedWidget.hxx"

class CartridgeF4SCWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeF4SCWidget(GuiObject* boss, const GUI::Font& lfont,
                        const GUI::Font& nfont,
                        int x, int y, int w, int h,
                        CartridgeF4SC& cart);
    ~CartridgeF4SCWidget() override = default;

  private:
    string manufacturer() override { return "Atari"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeF4SCWidget() = delete;
    CartridgeF4SCWidget(const CartridgeF4SCWidget&) = delete;
    CartridgeF4SCWidget(CartridgeF4SCWidget&&) = delete;
    CartridgeF4SCWidget& operator=(const CartridgeF4SCWidget&) = delete;
    CartridgeF4SCWidget& operator=(CartridgeF4SCWidget&&) = delete;
};

#endif
