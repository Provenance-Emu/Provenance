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

#ifndef CARTRIDGEF8_WIDGET_HXX
#define CARTRIDGEF8_WIDGET_HXX

class CartridgeF8;
class PopUpWidget;

#include "CartEnhancedWidget.hxx"

class CartridgeF8Widget : public CartridgeEnhancedWidget
{
  public:
    CartridgeF8Widget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeF8& cart);
    ~CartridgeF8Widget() override = default;

  private:
    string manufacturer() override { return "Atari"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeF8Widget() = delete;
    CartridgeF8Widget(const CartridgeF8Widget&) = delete;
    CartridgeF8Widget(CartridgeF8Widget&&) = delete;
    CartridgeF8Widget& operator=(const CartridgeF8Widget&) = delete;
    CartridgeF8Widget& operator=(CartridgeF8Widget&&) = delete;
};

#endif
