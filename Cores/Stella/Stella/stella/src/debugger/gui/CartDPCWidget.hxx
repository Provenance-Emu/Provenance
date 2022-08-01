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

#ifndef CARTRIDGEDPC_WIDGET_HXX
#define CARTRIDGEDPC_WIDGET_HXX

class CartridgeDPC;
class PopUpWidget;
class DataGridWidget;

#include "CartDebugWidget.hxx"

class CartridgeDPCWidget : public CartDebugWidget
{
  public:
    CartridgeDPCWidget(GuiObject* boss, const GUI::Font& lfont,
                       const GUI::Font& nfont,
                       int x, int y, int w, int h,
                       CartridgeDPC& cart);
    ~CartridgeDPCWidget() override = default;

  private:
    struct CartState {
      ByteArray tops;
      ByteArray bottoms;
      IntArray counters;
      ByteArray flags;
      BoolArray music;
      uInt8 random{0};
      ByteArray internalram;
      uInt16 bank{0};
    };

    CartridgeDPC& myCart;
    PopUpWidget* myBank{nullptr};

    DataGridWidget* myTops{nullptr};
    DataGridWidget* myBottoms{nullptr};
    DataGridWidget* myCounters{nullptr};
    DataGridWidget* myFlags{nullptr};
    DataGridWidget* myMusicMode{nullptr};
    DataGridWidget* myRandom{nullptr};

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
    string tabLabel() override { return " DPC Display Data "; }
    // end of functions for Cartridge RAM tab

    // Following constructors and assignment operators not supported
    CartridgeDPCWidget() = delete;
    CartridgeDPCWidget(const CartridgeDPCWidget&) = delete;
    CartridgeDPCWidget(CartridgeDPCWidget&&) = delete;
    CartridgeDPCWidget& operator=(const CartridgeDPCWidget&) = delete;
    CartridgeDPCWidget& operator=(CartridgeDPCWidget&&) = delete;
};

#endif
