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

#ifndef CARTRIDGEBUS_INFO_WIDGET_HXX
#define CARTRIDGEBUS_INFO_WIDGET_HXX

#include "CartBUS.hxx"
#include "CartDebugWidget.hxx"

class CartridgeBUSInfoWidget : public CartDebugWidget
{
  public:
    CartridgeBUSInfoWidget(GuiObject* boss, const GUI::Font& lfont,
                            const GUI::Font& nfont,
                            int x, int y, int w, int h,
                            CartridgeBUS& cart);
    ~CartridgeBUSInfoWidget() override = default;

  private:
    static string describeBUSVersion(CartridgeBUS::BUSSubtype subtype);

    // Following constructors and assignment operators not supported
    CartridgeBUSInfoWidget() = delete;
    CartridgeBUSInfoWidget(const CartridgeBUSInfoWidget&) = delete;
    CartridgeBUSInfoWidget(CartridgeBUSInfoWidget&&) = delete;
    CartridgeBUSInfoWidget& operator=(const CartridgeBUSInfoWidget&) = delete;
    CartridgeBUSInfoWidget& operator=(CartridgeBUSInfoWidget&&) = delete;
};
#endif
