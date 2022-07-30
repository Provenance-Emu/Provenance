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

#ifndef CARTRIDGESB_WIDGET_HXX
#define CARTRIDGESB_WIDGET_HXX

class CartridgeSB;

#include "CartEnhancedWidget.hxx"

class CartridgeSBWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeSBWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeSB& cart);
    ~CartridgeSBWidget() override = default;

  private:
    string manufacturer() override { return "Fred X. Quimby"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeSBWidget() = delete;
    CartridgeSBWidget(const CartridgeSBWidget&) = delete;
    CartridgeSBWidget(CartridgeSBWidget&&) = delete;
    CartridgeSBWidget& operator=(const CartridgeSBWidget&) = delete;
    CartridgeSBWidget& operator=(CartridgeSBWidget&&) = delete;
};

#endif
