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

#include "CartAR.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "CartDebug.hxx"
#include "PopUpWidget.hxx"
#include "CartARWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeARWidget::CartridgeARWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeAR& cart)
  : CartDebugWidget(boss, lfont, nfont, x, y, w, h),
    myCart{cart}
{
  const size_t size = myCart.mySize;

  const string info =
    "Supercharger cartridge, four 2K slices (3 RAM, 1 ROM)\n"
    "\nTHIS SCHEME IS NOT FULLY IMPLEMENTED OR TESTED\n";

  constexpr int xpos = 2;
  const int ypos = addBaseInformation(size, "Starpath", info) + myLineHeight;

  VariantList items;
  VarList::push_back(items, "  0");
  VarList::push_back(items, "  1");
  VarList::push_back(items, "  2");
  VarList::push_back(items, "  3");
  VarList::push_back(items, "  4");
  VarList::push_back(items, "  5");
  VarList::push_back(items, "  6");
  VarList::push_back(items, "  7");
  VarList::push_back(items, "  8");
  VarList::push_back(items, "  9");
  VarList::push_back(items, " 10");
  VarList::push_back(items, " 11");
  VarList::push_back(items, " 12");
  VarList::push_back(items, " 13");
  VarList::push_back(items, " 14");
  VarList::push_back(items, " 15");
  VarList::push_back(items, " 16");
  VarList::push_back(items, " 17");
  VarList::push_back(items, " 18");
  VarList::push_back(items, " 19");
  VarList::push_back(items, " 20");
  VarList::push_back(items, " 21");
  VarList::push_back(items, " 22");
  VarList::push_back(items, " 23");
  VarList::push_back(items, " 24");
  VarList::push_back(items, " 25");
  VarList::push_back(items, " 26");
  VarList::push_back(items, " 27");
  VarList::push_back(items, " 28");
  VarList::push_back(items, " 29");
  VarList::push_back(items, " 30");
  VarList::push_back(items, " 31");
  myBank =
    new PopUpWidget(boss, _font, xpos, ypos-2, _font.getStringWidth(" XX"),
                    myLineHeight, items, "Set bank     ",
                    0, kBankChanged);
  myBank->setTarget(this);
  addFocusWidget(myBank);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARWidget::loadConfig()
{
  CartDebug& cart = instance().debugger().cartDebug();
  const auto& state = static_cast<const CartState&>(cart.getState());
  const auto& oldstate = static_cast<const CartState&>(cart.getOldState());

  myBank->setSelectedIndex(myCart.getBank(), state.bank != oldstate.bank);

  CartDebugWidget::loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeARWidget::handleCommand(CommandSender* sender,
                                      int cmd, int data, int id)
{
  if(cmd == kBankChanged)
  {
    myCart.unlockHotspots();
    myCart.bank(myBank->getSelected());
    myCart.lockHotspots();
    invalidate();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeARWidget::bankState()
{
  ostringstream& buf = buffer();

  buf << "Bank = " << std::dec << myCart.myCurrentBank;

  return buf.str();
}
