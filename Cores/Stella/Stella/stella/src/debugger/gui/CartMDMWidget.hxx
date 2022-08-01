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

#ifndef CARTRIDGEMDM_WIDGET_HXX
#define CARTRIDGEMDM_WIDGET_HXX

class CartridgeMDM;
class CheckboxWidget;

#include "CartEnhancedWidget.hxx"

class CartridgeMDMWidget : public CartridgeEnhancedWidget
{
  public:
    CartridgeMDMWidget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeMDM& cart);
    ~CartridgeMDMWidget() override = default;

  private:
    string manufacturer() override { return "Edwin Blink"; }

    string description() override;

    void bankSelect(int& ypos) override;

    CartridgeMDM& myCartMDM;
    CheckboxWidget* myBankDisabled{nullptr};

    enum {
      kBankDisabled = 'bkDI'
    };

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeMDMWidget() = delete;
    CartridgeMDMWidget(const CartridgeMDMWidget&) = delete;
    CartridgeMDMWidget(CartridgeMDMWidget&&) = delete;
    CartridgeMDMWidget& operator=(const CartridgeMDMWidget&) = delete;
    CartridgeMDMWidget& operator=(CartridgeMDMWidget&&) = delete;
};

#endif
