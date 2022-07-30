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

#ifndef CARTRIDGECTY_WIDGET_HXX
#define CARTRIDGECTY_WIDGET_HXX

class CartridgeCTY;
class PopUpWidget;

#include "CartDebugWidget.hxx"

class CartridgeCTYWidget : public CartDebugWidget
{
  public:
    CartridgeCTYWidget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeCTY& cart);
    ~CartridgeCTYWidget() override = default;

  private:
    CartridgeCTY& myCart;
    PopUpWidget* myBank{nullptr};

    struct CartState {
      ByteArray internalram;
      uInt16 bank{0};
    };
    CartState myOldState;

    enum { kBankChanged = 'bkCH' };

  private:
    void saveOldState() override;
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    string bankState() override;

    // start of functions for Cartridge RAM tab
    uInt32 internalRamSize() override;
    uInt32 internalRamRPort(int start) override;
    string internalRamDescription() override;
    const ByteArray& internalRamOld(int start, int count) override;
    const ByteArray& internalRamCurrent(int start, int count) override;
    void internalRamSetValue(int addr, uInt8 value) override;
    uInt8 internalRamGetValue(int addr) override;
    string internalRamLabel(int addr) override;
    // end of functions for Cartridge RAM tab

    // Following constructors and assignment operators not supported
    CartridgeCTYWidget() = delete;
    CartridgeCTYWidget(const CartridgeCTYWidget&) = delete;
    CartridgeCTYWidget(CartridgeCTYWidget&&) = delete;
    CartridgeCTYWidget& operator=(const CartridgeCTYWidget&) = delete;
    CartridgeCTYWidget& operator=(CartridgeCTYWidget&&) = delete;
};

#endif
