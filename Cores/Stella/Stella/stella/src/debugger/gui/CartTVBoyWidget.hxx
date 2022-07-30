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

#ifndef CARTRIDGETVBOY_WIDGET_HXX
#define CARTRIDGETVBOY_WIDGET_HXX

class CartridgeTVBoy;
class CheckboxWidget;

#include "CartEnhancedWidget.hxx"

class CartridgeTVBoyWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeTVBoyWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeTVBoy& cart);
    ~CartridgeTVBoyWidget() override = default;

  private:
    string manufacturer() override { return "Akor"; }

    string description() override;

    void bankSelect(int& ypos) override;

    CartridgeTVBoy& myCartTVBoy;
    CheckboxWidget* myBankLocked{nullptr};

    enum {
      kBankLocked = 'bkLO'
    };

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeTVBoyWidget() = delete;
    CartridgeTVBoyWidget(const CartridgeTVBoyWidget&) = delete;
    CartridgeTVBoyWidget(CartridgeTVBoyWidget&&) = delete;
    CartridgeTVBoyWidget& operator=(const CartridgeTVBoyWidget&) = delete;
    CartridgeTVBoyWidget& operator=(CartridgeTVBoyWidget&&) = delete;
};

#endif
