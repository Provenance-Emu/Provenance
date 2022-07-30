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

#ifndef CART_ENHANCED_WIDGET_HXX
#define CART_ENHANCED_WIDGET_HXX

class CartridgeEnhanced;
class EditTextWidget;
class StringListWidget;
class PopUpWidget;

namespace GUI {
  class Font;
}

#include "Variant.hxx"
#include "CartDebugWidget.hxx"

class CartridgeEnhancedWidget : public CartDebugWidget
{
  public:
    CartridgeEnhancedWidget(GuiObject* boss, const GUI::Font& lfont,
                            const GUI::Font& nfont,
                            int x, int y, int w, int h,
                            CartridgeEnhanced& cart);
    ~CartridgeEnhancedWidget() override = default;

  protected:
    int initialize();

    virtual size_t size();

    virtual string manufacturer() = 0;

    virtual string description();

    virtual int descriptionLines();

    virtual string ramDescription();

    virtual string romDescription();

    virtual void plusROMInfo(int& ypos);

    virtual void bankList(uInt16 bankCount, int seg, VariantList& items, int& width);

    virtual void bankSelect(int& ypos);

    virtual string hotspotStr(int bank = 0, int segment = 0, bool prefix = false);

    virtual uInt16 bankSegs(); // { return myCart.myBankSegs; }

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

  protected:
    enum { kBankChanged = 'bkCH' };

    struct CartState {
      ByteArray internalRam;
      ByteArray banks;
      ByteArray send;
      ByteArray receive;
    };
    CartState myOldState;

    CartridgeEnhanced& myCart;

    // Distance between two hotspots
    int myHotspotDelta{1};

    EditTextWidget* myPlusROMHostWidget{nullptr};
    EditTextWidget* myPlusROMPathWidget{nullptr};
    EditTextWidget* myPlusROMSendWidget{nullptr};
    EditTextWidget* myPlusROMReceiveWidget{nullptr};

    std::unique_ptr<PopUpWidget* []> myBankWidgets{nullptr};


    // Display all addresses based on this
    static constexpr uInt16 ADDR_BASE = 0xF000;

  private:
    // Following constructors and assignment operators not supported
    CartridgeEnhancedWidget() = delete;
    CartridgeEnhancedWidget(const CartridgeEnhancedWidget&) = delete;
    CartridgeEnhancedWidget(CartridgeEnhancedWidget&&) = delete;
    CartridgeEnhancedWidget& operator=(const CartridgeEnhancedWidget&) = delete;
    CartridgeEnhancedWidget& operator=(CartridgeEnhancedWidget&&) = delete;
};

#endif

