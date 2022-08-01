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

#ifndef CARTRIDGEFC_WIDGET_HXX
#define CARTRIDGEFC_WIDGET_HXX

class CartridgeFC;

#include "CartEnhancedWidget.hxx"

class CartridgeFCWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeFCWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeFC& cart);
    ~CartridgeFCWidget() override = default;

  private:
    string manufacturer() override { return "Amiga Corp."; }

    string description() override;

    string hotspotStr(int bank, int seg = 0, bool prefix = false) override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeFCWidget() = delete;
    CartridgeFCWidget(const CartridgeFCWidget&) = delete;
    CartridgeFCWidget(CartridgeFCWidget&&) = delete;
    CartridgeFCWidget& operator=(const CartridgeFCWidget&) = delete;
    CartridgeFCWidget& operator=(CartridgeFCWidget&&) = delete;
};

#endif
