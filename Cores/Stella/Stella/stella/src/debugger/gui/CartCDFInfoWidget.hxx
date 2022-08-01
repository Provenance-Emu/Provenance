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

#ifndef CARTRIDGECDF_INFO_WIDGET_HXX
#define CARTRIDGECDF_INFO_WIDGET_HXX

#include "CartCDF.hxx"
#include "CartDebugWidget.hxx"

class CartridgeCDFInfoWidget : public CartDebugWidget
{
  public:
    CartridgeCDFInfoWidget(GuiObject* boss, const GUI::Font& lfont,
                            const GUI::Font& nfont,
                            int x, int y, int w, int h,
                            CartridgeCDF& cart);
    ~CartridgeCDFInfoWidget() override = default;

  private:
    static string describeCDFVersion(CartridgeCDF::CDFSubtype subtype);

    // Following constructors and assignment operators not supported
    CartridgeCDFInfoWidget() = delete;
    CartridgeCDFInfoWidget(const CartridgeCDFInfoWidget&) = delete;
    CartridgeCDFInfoWidget(CartridgeCDFInfoWidget&&) = delete;
    CartridgeCDFInfoWidget& operator=(const CartridgeCDFInfoWidget&) = delete;
    CartridgeCDFInfoWidget& operator=(CartridgeCDFInfoWidget&&) = delete;
};
#endif
