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

#include "CartMDM.hxx"
#include "PopUpWidget.hxx"
#include "CartMDMWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeMDMWidget::CartridgeMDMWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeMDM& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart),
    myCartMDM{cart}
{
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeMDMWidget::description()
{
  ostringstream info;

  info << "Menu Driven Megacart, " << myCart.romBankCount() << " 4K banks\n"
       << "Banks are selected by reading from $800 - $" << Common::Base::HEX1 << 0xBFF
       << ", where the lower byte determines the 4K bank to use.\n"
       << CartridgeEnhancedWidget::description();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeMDMWidget::bankSelect(int& ypos)
{
  CartridgeEnhancedWidget::bankSelect(ypos);
  if(myCart.romBankCount() > 1)
  {
    const int xpos = myBankWidgets[0]->getRight() + 20;
    ypos = myBankWidgets[0]->getTop();

    myBankDisabled = new CheckboxWidget(_boss, _font, xpos, ypos + 1,
                                        "Bankswitching is locked/disabled",
                                        kBankDisabled);
    myBankDisabled->setTarget(this);
    addFocusWidget(myBankDisabled);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeMDMWidget::loadConfig()
{
  if(myBankWidgets != nullptr)
  {
    myBankWidgets[0]->setEnabled(!myCartMDM.myBankingDisabled);
    myBankDisabled->setState(myCartMDM.myBankingDisabled);
  }
  CartridgeEnhancedWidget::loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeMDMWidget::handleCommand(CommandSender* sender,
                                       int cmd, int data, int id)
{
  if(cmd == kBankDisabled)
  {
    myCartMDM.myBankingDisabled = myBankDisabled->getState();
    myBankWidgets[0]->setEnabled(!myCartMDM.myBankingDisabled);
  }
  else
    CartridgeEnhancedWidget::handleCommand(sender, cmd, data, id);
}
