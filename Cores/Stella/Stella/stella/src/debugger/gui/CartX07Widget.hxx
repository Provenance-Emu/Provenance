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

#ifndef CARTRIDGEX07_WIDGET_HXX
#define CARTRIDGEX07_WIDGET_HXX

class CartridgeX07;

#include "CartEnhancedWidget.hxx"

class CartridgeX07Widget : public CartridgeEnhancedWidget
{
  public:
    CartridgeX07Widget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeX07& cart);
    ~CartridgeX07Widget() override = default;

  private:
    string manufacturer() override { return "AtariAge / John Payson / Fred Quimby"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeX07Widget() = delete;
    CartridgeX07Widget(const CartridgeX07Widget&) = delete;
    CartridgeX07Widget(CartridgeX07Widget&&) = delete;
    CartridgeX07Widget& operator=(const CartridgeX07Widget&) = delete;
    CartridgeX07Widget& operator=(CartridgeX07Widget&&) = delete;
};

#endif
