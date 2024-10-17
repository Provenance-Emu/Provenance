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

#include "Cart3E.hxx"
#include "PopUpWidget.hxx"
#include "Cart3EWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge3EWidget::Cartridge3EWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, Cartridge3E& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart)
{
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge3EWidget::description()
{
  ostringstream info;
  size_t size{0};
  const ByteBuffer& image = myCart.getImage(size);
  const uInt16 numRomBanks = myCart.romBankCount();
  const uInt16 numRamBanks = myCart.ramBankCount();

  info << "3E cartridge (3F + RAM),\n"
       << "  " << numRomBanks << " 2K ROM banks, " << numRamBanks << " 1K RAM banks\n"
       << "First 2K (ROM) selected by writing to $3F\n"
          "First 2K (RAM) selected by writing to $3E\n";
  info << CartridgeEnhancedWidget::ramDescription();
  info << "Last 2K always points to last 2K of ROM\n";

  if(myCart.startBank() < numRomBanks)
    info << "Startup bank = " << myCart.startBank() << " (ROM)\n";
  else
    info << "Startup bank = " << (myCart.startBank() - numRomBanks) << " (RAM)\n";

  // Eventually, we should query this from the debugger/disassembler
  uInt16 start = (image[size-3] << 8) | image[size-4];
  start -= start % 0x1000;
  info << "Bank RORG" << " = $" << Common::Base::HEX4 << start << "\n";

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EWidget::bankList(uInt16 bankCount, int seg, VariantList& items, int& width)
{
  CartridgeEnhancedWidget::bankList(bankCount, seg, items, width);

  VarList::push_back(items, "Inactive", "");
  width = _font.getStringWidth("Inactive");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EWidget::bankSelect(int& ypos)
{
  int xpos{2};
  VariantList items;
  int pw{0};

  myBankWidgets = make_unique<PopUpWidget* []>(2);

  bankList(myCart.romBankCount(), 0, items, pw);
  myBankWidgets[0] =
    new PopUpWidget(_boss, _font, xpos, ypos - 2, pw,
                    myLineHeight, items, "Set bank     ",
                    _font.getStringWidth("Set bank     "), kBankChanged);
  myBankWidgets[0]->setTarget(this);
  myBankWidgets[0]->setID(0);
  addFocusWidget(myBankWidgets[0]);

  auto* t = new StaticTextWidget(_boss, _font,
      myBankWidgets[0]->getRight(), ypos - 1, " (ROM)");

  xpos = t->getRight() + 20;
  items.clear();
  bankList(myCart.ramBankCount(), 0, items, pw);
  myBankWidgets[1] =
    new PopUpWidget(_boss, _font, xpos, ypos - 2, pw,
                    myLineHeight, items, "", 0, kRAMBankChanged);
  myBankWidgets[1]->setTarget(this);
  myBankWidgets[1]->setID(1);
  addFocusWidget(myBankWidgets[1]);

  new StaticTextWidget(_boss, _font, myBankWidgets[1]->getRight(), ypos - 1, " (RAM)");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EWidget::loadConfig()
{
  const uInt16 oldBank = myOldState.banks[0];
  const uInt16 bank = myCart.getBank();

  if(myCart.getBank() < myCart.romBankCount())
  {
    myBankWidgets[0]->setSelectedIndex(bank, oldBank != bank);
    myBankWidgets[1]->setSelectedMax(oldBank >= myCart.romBankCount());
  }
  else
  {
    myBankWidgets[0]->setSelectedMax(oldBank < myCart.romBankCount());
    myBankWidgets[1]->setSelectedIndex(bank - myCart.romBankCount(), oldBank != bank);
  }

  CartDebugWidget::loadConfig();  // NOLINT : Intentionally calling grand-parent method
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  uInt16 bank = 0;

  if(cmd == kBankChanged)
  {
    if(myBankWidgets[0]->getSelected() < myCart.romBankCount())
    {
      bank = myBankWidgets[0]->getSelected();
      myBankWidgets[1]->setSelectedMax();
    }
    else
    {
      bank = myCart.romBankCount();  // default to first RAM bank
      myBankWidgets[1]->setSelectedIndex(0);
    }
  }
  else if(cmd == kRAMBankChanged)
  {
    if(myBankWidgets[1]->getSelected() < myCart.ramBankCount())
    {
      myBankWidgets[0]->setSelectedMax();
      bank = myBankWidgets[1]->getSelected() + myCart.romBankCount();
    }
    else
    {
      bank = 0;  // default to first ROM bank
      myBankWidgets[0]->setSelectedIndex(0);
    }
  }
  myCart.unlockHotspots();
  myCart.bank(bank);
  myCart.lockHotspots();
  invalidate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge3EWidget::bankState()
{
  ostringstream& buf = buffer();
  const uInt16 bank = myCart.getBank();

  if(bank < myCart.romBankCount())
    buf << "ROM bank #" << std::dec << bank % myCart.romBankCount() << ", RAM inactive";
  else
    buf << "ROM inactive, RAM bank #"
        << std::dec << (bank - myCart.romBankCount()) % myCart.ramBankCount();

  return buf.str();
}
