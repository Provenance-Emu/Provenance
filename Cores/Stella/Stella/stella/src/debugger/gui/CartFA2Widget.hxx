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

#ifndef CARTRIDGEFA2_WIDGET_HXX
#define CARTRIDGEFA2_WIDGET_HXX

class CartridgeFA2;
class ButtonWidget;

#include "CartEnhancedWidget.hxx"

class CartridgeFA2Widget : public CartridgeEnhancedWidget
{
  public:
    CartridgeFA2Widget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeFA2& cart);
    ~CartridgeFA2Widget() override = default;

  private:
    CartridgeFA2& myCartFA2;

    ButtonWidget *myFlashErase{nullptr}, *myFlashLoad{nullptr}, *myFlashSave{nullptr};

    enum {
      kFlashErase  = 'flER',
      kFlashLoad   = 'flLD',
      kFlashSave   = 'flSV'
    };

  private:
    string manufacturer() override { return "Chris D. Walton (Star Castle 2600 Arcade)"; }

    string description() override;

  private:
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

  private:
    // Following constructors and assignment operators not supported
    CartridgeFA2Widget() = delete;
    CartridgeFA2Widget(const CartridgeFA2Widget&) = delete;
    CartridgeFA2Widget(CartridgeFA2Widget&&) = delete;
    CartridgeFA2Widget& operator=(const CartridgeFA2Widget&) = delete;
    CartridgeFA2Widget& operator=(CartridgeFA2Widget&&) = delete;
};

#endif
