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

#ifndef CARTRIDGEBF_WIDGET_HXX
#define CARTRIDGEBF_WIDGET_HXX

class CartridgeBF;

#include "CartEnhancedWidget.hxx"

class CartridgeBFWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeBFWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeBF& cart);
    ~CartridgeBFWidget() override = default;

  private:
    string manufacturer() override { return "CPUWIZ"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeBFWidget() = delete;
    CartridgeBFWidget(const CartridgeBFWidget&) = delete;
    CartridgeBFWidget(CartridgeBFWidget&&) = delete;
    CartridgeBFWidget& operator=(const CartridgeBFWidget&) = delete;
    CartridgeBFWidget& operator=(CartridgeBFWidget&&) = delete;
};

#endif
