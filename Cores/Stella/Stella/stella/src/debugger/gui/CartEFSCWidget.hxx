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

#ifndef CARTRIDGEEFSC_WIDGET_HXX
#define CARTRIDGEEFSC_WIDGET_HXX

class CartridgeEFSC;

#include "CartEnhancedWidget.hxx"

class CartridgeEFSCWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeEFSCWidget(GuiObject* boss, const GUI::Font& lfont,
                        const GUI::Font& nfont,
                        int x, int y, int w, int h,
                        CartridgeEFSC& cart);
    ~CartridgeEFSCWidget() override = default;

  private:
    string manufacturer() override { return "Paul Slocum / Homestar Runner"; }

    string description() override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeEFSCWidget() = delete;
    CartridgeEFSCWidget(const CartridgeEFSCWidget&) = delete;
    CartridgeEFSCWidget(CartridgeEFSCWidget&&) = delete;
    CartridgeEFSCWidget& operator=(const CartridgeEFSCWidget&) = delete;
    CartridgeEFSCWidget& operator=(CartridgeEFSCWidget&&) = delete;
};

#endif
