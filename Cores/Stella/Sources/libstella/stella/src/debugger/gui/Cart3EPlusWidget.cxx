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

#include "Cart3EPlus.hxx"
#include "EditTextWidget.hxx"
#include "PopUpWidget.hxx"
#include "CartEnhancedWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge3EPlusWidget::Cartridge3EPlusWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, Cartridge3EPlus& cart)
  : CartridgeEnhancedWidget(boss, lfont, nfont, x, y, w, h, cart),
    myCart3EP{cart}
{
  initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge3EPlusWidget::description()
{
  ostringstream info;
  size_t size{0};
  const ByteBuffer& image = myCart.getImage(size);
  const uInt16 numRomBanks = myCart.romBankCount();
  const uInt16 numRamBanks = myCart.ramBankCount();

  info << "3E+ cartridge - (1" << ELLIPSIS << "64K ROM + RAM)\n"
    << "  " << numRomBanks << " 1K ROM banks + " << numRamBanks << " 512b RAM banks\n"
    << "  mapped into four segments\n"
       "ROM bank & segment selected by writing to $3F\n"
       "RAM bank & segment selected by writing to $3E\n"
       "  Lower 512b of segment for read access\n"
       "  Upper 512b of segment for write access\n"
       "Startup bank = -1/-1/-1/0 (ROM)\n";

  // Eventually, we should query this from the debugger/disassembler
  uInt16 start = (image[0x400 - 3] << 8) | image[0x400 - 4];
  start -= start % 0x1000;
  info << "Bank RORG" << " = $" << Common::Base::HEX4 << start << "\n";

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EPlusWidget::bankSelect(int& ypos)
{
  size_t size{0};
  const ByteBuffer& image = myCart.getImage(size);
  const int VGAP = myFontHeight / 4;
  VariantList banktype;

  VarList::push_back(banktype, "ROM", "ROM");
  VarList::push_back(banktype, "RAM", "RAM");

  myBankWidgets = make_unique<PopUpWidget* []>(bankSegs());

  ypos -= VGAP * 2;

  for(uInt32 seg = 0; seg < bankSegs(); ++seg)
  {
    int xpos = 2, ypos_s = ypos + 1, width = 0;
    ostringstream label;
    VariantList items;

    label << "Set segment " << seg << " as ";

    new StaticTextWidget(_boss, _font, xpos, ypos, label.str());
    ypos += myLineHeight + VGAP * 2;

    xpos += _font.getMaxCharWidth() * 2;

    CartridgeEnhancedWidget::bankList(std::max(myCart.romBankCount(), myCart.ramBankCount()),
                                      seg, items, width);
    myBankWidgets[seg] =
      new PopUpWidget(_boss, _font, xpos, ypos - 2, width,
                      myLineHeight, items, "Bank ", 0, kBankChanged);
    myBankWidgets[seg]->setID(seg);
    myBankWidgets[seg]->setTarget(this);
    addFocusWidget(myBankWidgets[seg]);

    xpos += myBankWidgets[seg]->getWidth();
    myBankType[seg] =
      new PopUpWidget(_boss, _font, xpos, ypos - 2, 3 * _font.getMaxCharWidth(),
                      myLineHeight, banktype, " of ", 0, kRomRamChanged);
    myBankType[seg]->setID(seg);
    myBankType[seg]->setTarget(this);
    addFocusWidget(myBankType[seg]);

    xpos = myBankType[seg]->getRight() + _font.getMaxCharWidth();

    // add "Commit" button (why required?)
    myBankCommit[seg] = new ButtonWidget(_boss, _font, xpos, ypos - 4,
                                         _font.getStringWidth(" Commit "), myButtonHeight,
                                         "Commit", kChangeBank);
    myBankCommit[seg]->setID(seg);
    myBankCommit[seg]->setTarget(this);
    addFocusWidget(myBankCommit[seg]);

    const int xpos_s = myBankCommit[seg]->getRight() + _font.getMaxCharWidth() * 2;

    uInt16 start = (image[0x400 - 3] << 8) | image[0x400 - 4];
    start -= start % 0x1000;
    const int addr1 = start + (seg * 0x400), addr2 = addr1 + 0x200;

    label.str("");
    label << "$" << Common::Base::HEX4 << addr1 << "-$"
          << Common::Base::HEX4 << (addr1 + 0x1FF);
    auto* t = new StaticTextWidget(_boss, _font, xpos_s, ypos_s + 2, label.str());

    const int xoffset = t->getRight() + _font.getMaxCharWidth();
    const size_t bank_off = static_cast<size_t>(seg) * 2;
    myBankState[bank_off] = new EditTextWidget(_boss, _font, xoffset, ypos_s,
                                               _w - xoffset - 10, myLineHeight, "");
    myBankState[bank_off]->setEditable(false, true);
    ypos_s += myLineHeight + VGAP;

    label.str("");
    label << "$" << Common::Base::HEX4 << addr2 << "-$" << Common::Base::HEX4 << (addr2 + 0x1FF);
    new StaticTextWidget(_boss, _font, xpos_s, ypos_s + 2, label.str());

    myBankState[bank_off + 1] = new EditTextWidget(_boss, _font,
        xoffset, ypos_s, _w - xoffset - 10, myLineHeight, "");
    myBankState[bank_off + 1]->setEditable(false, true);

    ypos += myLineHeight + VGAP * 4;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EPlusWidget::loadConfig()
{
  CartridgeEnhancedWidget::loadConfig();
  updateUIState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EPlusWidget::handleCommand(CommandSender* sender,
                                          int cmd, int data, int id)
{
  const uInt16 segment = id;

  switch(cmd)
  {
    case kBankChanged:
    case kRomRamChanged:
    {
      const bool isROM = myBankType[segment]->getSelectedTag() == "ROM";
      const int bank = myBankWidgets[segment]->getSelected();

      myBankCommit[segment]->setEnabled((isROM && bank < myCart.romBankCount())
        || (!isROM && bank < myCart.ramBankCount()));
      break;
    }
    case kChangeBank:
    {
      // Ignore bank if either number or type hasn't been selected
      if(myBankWidgets[segment]->getSelected() < 0 ||
         myBankType[segment]->getSelected() < 0)
        return;

      const uInt8 bank = myBankWidgets[segment]->getSelected();

      myCart.unlockHotspots();

      if(myBankType[segment]->getSelectedTag() == "ROM")
        myCart.bank(bank, segment);
      else
        myCart.bank(bank + myCart.romBankCount(), segment);

      myCart.lockHotspots();
      invalidate();
      updateUIState();
      break;
    }
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EPlusWidget::updateUIState()
{
  // Set description for each 1K segment state (@ each index)
  // Set contents for actual banks number and type (@ each even index)
  for(int seg = 0; seg < myCart3EP.myBankSegs; ++seg)
  {
    const uInt16 bank = myCart.getSegmentBank(seg);
    const size_t bank_off = static_cast<size_t>(seg) * 2;
    ostringstream buf;

    if(bank >= myCart.romBankCount()) // was RAM mapped here?
    {
      const uInt16 ramBank = bank - myCart.romBankCount();

      buf << "RAM @ $" << Common::Base::HEX4
          << (ramBank << myCart3EP.myBankShift) << " (R)";
      myBankState[bank_off]->setText(buf.str());

      buf.str("");
      buf << "RAM @ $" << Common::Base::HEX4
        << ((ramBank << myCart3EP.myBankShift) + myCart3EP.myBankSize) << " (W)";
      myBankState[bank_off + 1]->setText(buf.str());

      myBankWidgets[seg]->setSelectedIndex(ramBank);
      myBankType[seg]->setSelected("RAM");
    }
    else
    {
      buf << "ROM @ $" << Common::Base::HEX4
        << ((bank << myCart3EP.myBankShift));
      myBankState[bank_off]->setText(buf.str());

      buf.str("");
      buf << "ROM @ $" << Common::Base::HEX4
        << ((bank << myCart3EP.myBankShift) + myCart3EP.myBankSize);
      myBankState[bank_off + 1]->setText(buf.str());

      myBankWidgets[seg]->setSelectedIndex(bank);
      myBankType[seg]->setSelected("ROM");
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Cartridge3EPlusWidget::internalRamDescription()
{
  ostringstream desc;

  desc << "Accessible 512b at a time via:\n"
       << "  $f000/$f400/$f800/$fc00 for read access\n"
       << "  $f200/$f600/$fa00/$fe00 for write access";

  return desc.str();
}
