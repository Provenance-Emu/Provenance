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

#ifndef CARTRIDGE4A50_WIDGET_HXX
#define CARTRIDGE4A50_WIDGET_HXX

class Cartridge4A50;
class PopUpWidget;

#include "CartDebugWidget.hxx"

class Cartridge4A50Widget : public CartDebugWidget
{
  public:
    Cartridge4A50Widget(GuiObject* boss, const GUI::Font& lfont,
                        const GUI::Font& nfont,
                        int x, int y, int w, int h,
                        Cartridge4A50& cart);
    ~Cartridge4A50Widget() override = default;

  private:
    Cartridge4A50& myCart;
    PopUpWidget *myROMLower{nullptr}, *myRAMLower{nullptr};
    PopUpWidget *myROMMiddle{nullptr}, *myRAMMiddle{nullptr};
    PopUpWidget *myROMHigh{nullptr}, *myRAMHigh{nullptr};

    enum {
      kROMLowerChanged  = 'rmLW',
      kRAMLowerChanged  = 'raLW',
      kROMMiddleChanged = 'rmMD',
      kRAMMiddleChanged = 'raMD',
      kROMHighChanged   = 'rmHI',
      kRAMHighChanged   = 'raHI'
    };

  private:
    void loadConfig() override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;

    string bankState() override;

    // Following constructors and assignment operators not supported
    Cartridge4A50Widget() = delete;
    Cartridge4A50Widget(const Cartridge4A50Widget&) = delete;
    Cartridge4A50Widget(Cartridge4A50Widget&&) = delete;
    Cartridge4A50Widget& operator=(const Cartridge4A50Widget&) = delete;
    Cartridge4A50Widget& operator=(Cartridge4A50Widget&&) = delete;
};

#endif
