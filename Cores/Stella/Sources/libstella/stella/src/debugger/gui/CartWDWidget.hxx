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
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef CARTRIDGEWD_WIDGET_HXX
#define CARTRIDGEWD_WIDGET_HXX

class CartridgeWD;

#include "CartEnhancedWidget.hxx"

class CartridgeWDWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeWDWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeWD& cart);
    ~CartridgeWDWidget() override = default;

  private:
    string manufacturer() override { return "Wickstead Design"; }

    string description() override;

    string hotspotStr(int bank, int seg = 0, bool prefix = false) override;

    uInt16 bankSegs() override { return 1; }

  private:
    // Following constructors and assignment operators not supported
    CartridgeWDWidget() = delete;
    CartridgeWDWidget(const CartridgeWDWidget&) = delete;
    CartridgeWDWidget(CartridgeWDWidget&&) = delete;
    CartridgeWDWidget& operator=(const CartridgeWDWidget&) = delete;
    CartridgeWDWidget& operator=(CartridgeWDWidget&&) = delete;
};

#endif
