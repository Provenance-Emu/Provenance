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
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef CARTRIDGE_E7_WIDGET_HXX
#define CARTRIDGE_E7_WIDGET_HXX

class CartridgeE7;
class PopUpWidget;

#include "CartDebugWidget.hxx"

class CartridgeE7Widget : public CartDebugWidget
{
  public:
    CartridgeE7Widget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      CartridgeE7& cart);
    ~CartridgeE7Widget() override = default;

  protected:
    CartridgeE7& myCart;

    PopUpWidget *myLower2K{nullptr}, *myUpper256B{nullptr};

    struct CartState
    {
      ByteArray internalram;
      uInt16 lowerBank{0};
      uInt16 upperBank{0};
    };
    CartState myOldState;

    enum
    {
      kLowerChanged = 'lwCH',
      kUpperChanged = 'upCH'
    };

  protected:
    void initialize(GuiObject* boss, const CartridgeE7& cart,
                    const ostringstream& info);

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
    // end of functions for Cartridge RAM tab

    static string_view getSpotLower(int idx, int bankcount);
    static string_view getSpotUpper(int idx);

  private:
    // Following constructors and assignment operators not supported
    CartridgeE7Widget() = delete;
    CartridgeE7Widget(const CartridgeE7Widget&) = delete;
    CartridgeE7Widget(CartridgeE7Widget&&) = delete;
    CartridgeE7Widget& operator=(const CartridgeE7Widget&) = delete;
    CartridgeE7Widget& operator=(CartridgeE7Widget&&) = delete;
};

#endif
