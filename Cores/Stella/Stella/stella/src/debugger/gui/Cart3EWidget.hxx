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

#ifndef CARTRIDGE3E_WIDGET_HXX
#define CARTRIDGE3E_WIDGET_HXX

class Cartridge3E;

#include "CartEnhancedWidget.hxx"

// Note: This class supports 3EX too

class Cartridge3EWidget : public CartridgeEnhancedWidget
{
  public:
    Cartridge3EWidget(GuiObject* boss, const GUI::Font& lfont,
                      const GUI::Font& nfont,
                      int x, int y, int w, int h,
                      Cartridge3E& cart);
    ~Cartridge3EWidget() override = default;

  private:
    enum {
      kRAMBankChanged = 'raCH'
    };

  private:
    string manufacturer() override { return "Andrew Davie & Thomas Jentzsch"; }

    string description() override;

    void bankList(uInt16 bankCount, int seg, VariantList& items, int& width) override;

    void bankSelect(int& ypos) override;

    uInt16 bankSegs() override { return 1; }

    void loadConfig() override;

    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    string bankState() override;

  private:
    // Following constructors and assignment operators not supported
    Cartridge3EWidget() = delete;
    Cartridge3EWidget(const Cartridge3EWidget&) = delete;
    Cartridge3EWidget(Cartridge3EWidget&&) = delete;
    Cartridge3EWidget& operator=(const Cartridge3EWidget&) = delete;
    Cartridge3EWidget& operator=(Cartridge3EWidget&&) = delete;
};

#endif
