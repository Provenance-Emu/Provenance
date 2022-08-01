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

#ifndef CARTRIDGEF6_WIDGET_HXX
#define CARTRIDGEF6_WIDGET_HXX

class CartridgeF6;

#include "CartEnhancedWidget.hxx"

class CartridgeF6Widget : public CartridgeEnhancedWidget
{
  public:
    CartridgeF6Widget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeF6& cart);
    ~CartridgeF6Widget() override = default;

  private:
    string manufacturer() override { return "Atari"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeF6Widget() = delete;
    CartridgeF6Widget(const CartridgeF6Widget&) = delete;
    CartridgeF6Widget(CartridgeF6Widget&&) = delete;
    CartridgeF6Widget& operator=(const CartridgeF6Widget&) = delete;
    CartridgeF6Widget& operator=(CartridgeF6Widget&&) = delete;
};

#endif
