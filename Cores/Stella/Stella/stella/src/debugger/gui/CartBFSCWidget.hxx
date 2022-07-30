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

#ifndef CARTRIDGEBFSC_WIDGET_HXX
#define CARTRIDGEBFSC_WIDGET_HXX

class CartridgeBFSC;

#include "CartEnhancedWidget.hxx"

class CartridgeBFSCWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeBFSCWidget(GuiObject* boss, const GUI::Font& lfont,
                        const GUI::Font& nfont,
                        int x, int y, int w, int h,
                        CartridgeBFSC& cart);
    ~CartridgeBFSCWidget() override = default;

  private:
    string manufacturer() override { return "CPUWIZ"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeBFSCWidget() = delete;
    CartridgeBFSCWidget(const CartridgeBFSCWidget&) = delete;
    CartridgeBFSCWidget(CartridgeBFSCWidget&&) = delete;
    CartridgeBFSCWidget& operator=(const CartridgeBFSCWidget&) = delete;
    CartridgeBFSCWidget& operator=(CartridgeBFSCWidget&&) = delete;
};

#endif
