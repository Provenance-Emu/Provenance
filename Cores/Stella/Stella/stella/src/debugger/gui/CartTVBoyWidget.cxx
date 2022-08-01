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

#include "CartTVBoy.hxx"
#include "PopUpWidget.hxx"
#include "CartTVBoyWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeTVBoyWidget::CartridgeTVBoyWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeTVBoy& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart),
    myCartTVBoy{cart}
{
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeTVBoyWidget::description()
{
  ostringstream info;

  info << "TV Boy, " << myCart.romBankCount() << " 4K banks\n"
       << "Hotspots are from $" << Common::Base::HEX2 << 0xf800 << " to $"
       << Common::Base::HEX2 << (0xf800 + myCart.romBankCount() - 1) << "\n"
       << CartridgeEnhancedWidget::description();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeTVBoyWidget::bankSelect(int& ypos)
{
  CartridgeEnhancedWidget::bankSelect(ypos);
  if(myCart.romBankCount() > 1)
  {
    const int xpos = myBankWidgets[0]->getRight() + _font.getMaxCharWidth() * 4;
    ypos = myBankWidgets[0]->getTop();

    myBankLocked = new CheckboxWidget(_boss, _font, xpos, ypos + 1,
                                      "Bankswitching is locked",
                                      kBankLocked);
    myBankLocked->setTarget(this);
    addFocusWidget(myBankLocked);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeTVBoyWidget::loadConfig()
{
  if(myBankWidgets != nullptr)
  {
    myBankWidgets[0]->setEnabled(!myCartTVBoy.myBankingDisabled);
    myBankLocked->setState(myCartTVBoy.myBankingDisabled);
  }
  CartridgeEnhancedWidget::loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeTVBoyWidget::handleCommand(CommandSender* sender,
                                         int cmd, int data, int id)
{
  if(cmd == kBankLocked)
  {
    myCartTVBoy.myBankingDisabled = myBankLocked->getState();
    myBankWidgets[0]->setEnabled(!myCartTVBoy.myBankingDisabled);
  }
  else
    CartridgeEnhancedWidget::handleCommand(sender, cmd, data, id);
}
