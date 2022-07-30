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

#ifndef CARTRIDGEUA_WIDGET_HXX
#define CARTRIDGEUA_WIDGET_HXX

class CartridgeUA;

#include "CartEnhancedWidget.hxx"

class CartridgeUAWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeUAWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeUA& cart, bool swapHotspots);
    ~CartridgeUAWidget() override = default;

  private:
    string manufacturer() override { return "UA Limited"; }

    string description() override;

    string hotspotStr(int bank, int seg, bool prefix = false) override;

  private:
    const bool mySwappedHotspots;

  private:
    // Following constructors and assignment operators not supported
    CartridgeUAWidget() = delete;
    CartridgeUAWidget(const CartridgeUAWidget&) = delete;
    CartridgeUAWidget(CartridgeUAWidget&&) = delete;
    CartridgeUAWidget& operator=(const CartridgeUAWidget&) = delete;
    CartridgeUAWidget& operator=(CartridgeUAWidget&&) = delete;
};

#endif
