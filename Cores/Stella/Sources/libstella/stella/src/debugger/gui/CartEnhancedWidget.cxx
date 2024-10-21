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

#include "EditTextWidget.hxx"
#include "PopUpWidget.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "CartDebug.hxx"
#include "CartEnhanced.hxx"
#include "CartEnhancedWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeEnhancedWidget::CartridgeEnhancedWidget(GuiObject* boss, const GUI::Font& lfont,
                                       const GUI::Font& nfont,
                                       int x, int y, int w, int h,
                                       CartridgeEnhanced& cart)
  : CartDebugWidget(boss, lfont, nfont, x, y, w, h),
    myCart{cart}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartridgeEnhancedWidget::initialize()
{
  int ypos = addBaseInformation(size(), manufacturer(), description(), descriptionLines());

  plusROMInfo(ypos);
  ypos += myLineHeight;

  bankSelect(ypos);

  return ypos;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t CartridgeEnhancedWidget::size()
{
  size_t size{0};

  myCart.getImage(size);

  return size;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::description()
{
  ostringstream info;

  if (myCart.myRamSize > 0)
    info << ramDescription();
  info << romDescription();

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartridgeEnhancedWidget::descriptionLines()
{
  return 18; // should be enough for almost all types
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::ramDescription()
{
  ostringstream info;

  if(myCart.ramBankCount() == 0)
    info << myCart.myRamSize << " bytes RAM @ "
      << "$" << Common::Base::HEX4 << ADDR_BASE << " - "
      << "$" << (ADDR_BASE | (myCart.myRamSize * 2 - 1)) << "\n";

  info << "  $" << Common::Base::HEX4 << (ADDR_BASE | myCart.myReadOffset)
    << " - $" << (ADDR_BASE | (myCart.myReadOffset + myCart.myRamMask)) << " (R)"
    << ", $" << (ADDR_BASE | myCart.myWriteOffset)
    << " - $" << (ADDR_BASE | (myCart.myWriteOffset + myCart.myRamMask)) << " (W)\n";

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::romDescription()
{
  ostringstream info;
  size_t size{0};
  const ByteBuffer& image = myCart.getImage(size);

  if(myCart.romBankCount() > 1)
  {
    for(int bank = 0, offset = 0xFFC; bank < myCart.romBankCount(); ++bank, offset += 0x1000)
    {
      uInt16 start = (image[offset + 1] << 8) | image[offset];
      start -= start % 0x1000;
      const string hash = myCart.romBankCount() > 10 && bank < 10 ? " #" : "#";

      info << "Bank " << hash << std::dec << bank << " @ $"
        << Common::Base::HEX4 << (start + myCart.myRomOffset) << " - $" << (start + 0xFFF);
      if(myCart.hotspot() != 0)
      {
        const string hs = hotspotStr(bank, 0, true);
        if(hs.length() > 22)
          info << "\n ";
        info << " " << hs;
      }
      info << "\n";
    }
    info << "Startup bank = #" << std::dec << myCart.startBank() << " or undetermined\n";
  }
  else
  {
    uInt16 start = (image[myCart.mySize - 3] << 8) | image[myCart.mySize - 4];
    start -= start % std::min(static_cast<int>(size), 0x1000);
    const uInt16 end = start + static_cast<uInt16>(myCart.mySize) - 1;
    // special check for ROMs where the extra RAM is not included in the image (e.g. CV).
    if((start & 0xFFFU) < size)
    {
      start += myCart.myRomOffset;
    }
    info << "ROM accessible @ $"
         << Common::Base::HEX4 << start << " - $"
         << Common::Base::HEX4 << end;
  }

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::plusROMInfo(int& ypos)
{
  if(myCart.isPlusROM())
  {
    constexpr int xpos = 2;
    const int lwidth = _font.getStringWidth("Manufacturer "),
              fwidth = _w - lwidth - 12;

    new StaticTextWidget(_boss, _font, xpos, ypos + 1, "PlusROM:");
    ypos += myLineHeight + 4;

    new StaticTextWidget(_boss, _font, xpos + _fontWidth * 2, ypos + 1, "Host");
    myPlusROMHostWidget = new EditTextWidget(_boss, _font, xpos + lwidth, ypos - 1,
      fwidth, myLineHeight, myCart.myPlusROM->getHost());
    myPlusROMHostWidget->setEditable(false);
    ypos += myLineHeight + 4;

    new StaticTextWidget(_boss, _font, xpos + _fontWidth * 2, ypos + 1, "Path");
    myPlusROMPathWidget = new EditTextWidget(_boss, _font, xpos + lwidth, ypos - 1,
      fwidth, myLineHeight, myCart.myPlusROM->getPath());
    myPlusROMPathWidget->setEditable(false);
    ypos += myLineHeight + 4;

    new StaticTextWidget(_boss, _font, xpos + _fontWidth * 2, ypos + 1, "Send");
    myPlusROMSendWidget = new EditTextWidget(_boss, _nfont, xpos + lwidth, ypos - 1,
      fwidth, myLineHeight);
    myPlusROMSendWidget->setEditable(false);
    ypos += myLineHeight + 4;

    new StaticTextWidget(_boss, _font, xpos + _fontWidth * 2, ypos + 1, "Receive");
    myPlusROMReceiveWidget = new EditTextWidget(_boss, _nfont, xpos + lwidth, ypos - 1,
      fwidth, myLineHeight);
    myPlusROMReceiveWidget->setEditable(false);
    ypos += myLineHeight + 4;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::bankList(uInt16 bankCount, int seg, VariantList& items, int& width)
{
  width = 0;

  const bool hasRamBanks = myCart.myRamBankCount > 0;

  for(int bank = 0; bank < bankCount; ++bank)
  {
    ostringstream buf;
    const bool isRamBank = (bank >= myCart.romBankCount());
    const int bankNum = (bank - (isRamBank ? myCart.romBankCount() : 0));

    buf << std::setw(bankNum < 10 ? 2 : 1) << "#" << std::dec << bankNum;
    if(isRamBank) // was RAM mapped here?
      buf << " RAM";
    else if (hasRamBanks)
      buf << " ROM";

    if(myCart.hotspot() != 0 && myHotspotDelta > 0)
      buf << " " << hotspotStr(bank, seg);
    VarList::push_back(items, buf.str());
    width = std::max(width, _font.getStringWidth(buf.str()));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::bankSelect(int& ypos)
{
  if(myCart.romBankCount() + myCart.ramBankCount() > 1)
  {
    constexpr int xpos = 2;

    myBankWidgets = make_unique<PopUpWidget* []>(bankSegs());

    for(int seg = 0; seg < bankSegs(); ++seg)
    {
      // fill bank and hotspot list
      VariantList items;
      int pw = 0;

      bankList(myCart.romBankCount() + myCart.ramBankCount(), seg, items, pw);

      // create widgets
      ostringstream buf;

      buf << "Set bank";
      if(bankSegs() > 1)
        buf << " for segment #" << seg << " ";
      else
        buf << "     "; // align with info

      myBankWidgets[seg] = new PopUpWidget(_boss, _font, xpos, ypos - 2,
                                           pw, myLineHeight, items, buf.str(),
                                           0, kBankChanged);
      myBankWidgets[seg]->setTarget(this);
      myBankWidgets[seg]->setID(seg);
      addFocusWidget(myBankWidgets[seg]);

      ypos += myBankWidgets[seg]->getHeight() + 4;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::bankState()
{
  if(myCart.romBankCount() > 1)
  {
    ostringstream& buf = buffer();
    const uInt16 hotspot = myCart.hotspot();
    const bool hasRamBanks = myCart.myRamBankCount > 0;

    if(bankSegs() > 1)
    {
      buf << "Segments: ";

      for(int seg = 0; seg < bankSegs(); ++seg)
      {
        const int bank = myCart.getSegmentBank(seg);
        const bool isRamBank = (bank >= myCart.romBankCount());

        if(seg > 0)
          buf << " / ";

        buf << "#" << std::dec << (bank - (isRamBank ? myCart.romBankCount() : 0));

        if(isRamBank) // was RAM mapped here?
          buf << " RAM";
        else if (hasRamBanks)
          buf << " ROM";

        //if(hotspot >= 0x100)
        if(hotspot != 0 && myHotspotDelta > 0)
          buf << " " << hotspotStr(bank, seg, bankSegs() < 3);
      }
    }
    else
    {
      buf << "Bank #" << std::dec << myCart.getBank();

      if(hotspot != 0 && myHotspotDelta > 0)
        buf << " " << hotspotStr(myCart.getBank(), 0, true);
    }
    return buf.str();
  }
  return "non-bankswitched";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::hotspotStr(int bank, int segment, bool prefix)
{
  ostringstream info;
  uInt16 hotspot = myCart.hotspot();

  if(hotspot & 0x1000)
    hotspot |= ADDR_BASE;

  info << "(" << (prefix ? "hotspot " : "");
  info << "$" << Common::Base::HEX1 << (hotspot + bank * myHotspotDelta);
  info << ")";

  return info.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeEnhancedWidget::bankSegs()
{
  return myCart.myBankSegs;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::saveOldState()
{
  myOldState.internalRam.clear();
  for(uInt32 i = 0; i < myCart.myRamSize; ++i)
    myOldState.internalRam.push_back(myCart.myRAM[i]);

  if(myCart.isPlusROM())
  {
    myOldState.send = myCart.myPlusROM->getSend();
    myOldState.receive = myCart.myPlusROM->getReceive();
  }

  myOldState.banks.clear();
  if (bankSegs() > 1)
    for(int seg = 0; seg < bankSegs(); ++seg)
      myOldState.banks.push_back(myCart.getSegmentBank(seg));
  else
    myOldState.banks.push_back(myCart.getBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::loadConfig()
{
  if(myCart.isPlusROM())
  {
    ostringstream buf;
    ByteArray arr = myCart.myPlusROM->getSend();

    for(auto i: arr)
      buf << Common::Base::HEX2 << static_cast<int>(i) << " ";
    myPlusROMSendWidget->setText(buf.str(), arr != myOldState.send);

    buf.str("");
    arr = myCart.myPlusROM->getReceive();

    for(auto i: arr)
      buf << Common::Base::HEX2 << static_cast<int>(i) << " ";
    myPlusROMReceiveWidget->setText(buf.str(), arr != myOldState.receive);
  }
  if(myBankWidgets != nullptr)
  {
    if(bankSegs() > 1)
      for(int seg = 0; seg < bankSegs(); ++seg)
        myBankWidgets[seg]->setSelectedIndex(myCart.getSegmentBank(seg),
                                             myCart.getSegmentBank(seg) != myOldState.banks[seg]);
    else
      myBankWidgets[0]->setSelectedIndex(myCart.getBank(),
                                         myCart.getBank() != myOldState.banks[0]);
  }
  CartDebugWidget::loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::handleCommand(CommandSender* sender,
                                            int cmd, int data, int id)
{
  if(cmd == kBankChanged)
  {
    myCart.unlockHotspots();
    myCart.bank(myBankWidgets[id]->getSelected(), id);
    myCart.lockHotspots();
    invalidate();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeEnhancedWidget::internalRamSize()
{
  return static_cast<uInt32>(myCart.myRamSize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeEnhancedWidget::internalRamRPort(int start)
{
  if(myCart.ramBankCount() == 0)
    return ADDR_BASE + myCart.myReadOffset + start;
  else
    return start;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::internalRamDescription()
{
  ostringstream desc;
  string indent;

  if(myCart.ramBankCount())
  {
    desc << "Accessible ";
    if (myCart.bankSize() >> 1 >= 1024)
      desc << ((myCart.bankSize() >> 1) / 1024) << "K";
    else
      desc << (myCart.bankSize() >> 1) << " bytes";
    desc << " at a time via:\n";
    indent = "  ";
  }

  // order RW by addresses
  if(myCart.myReadOffset <= myCart.myWriteOffset)
  {
    desc << indent << "$" << Common::Base::HEX4 << (ADDR_BASE | myCart.myReadOffset)
      << " - $" << (ADDR_BASE | (myCart.myReadOffset + myCart.myRamMask))
      << " used for read access\n";
  }

  desc << indent << "$" << Common::Base::HEX4 << (ADDR_BASE | myCart.myWriteOffset)
    << " - $" << (ADDR_BASE | (myCart.myWriteOffset + myCart.myRamMask))
    << " used for write access";

  if(myCart.myReadOffset > myCart.myWriteOffset)
  {
    desc << indent << "\n$" << Common::Base::HEX4 << (ADDR_BASE | myCart.myReadOffset)
      << " - $" << (ADDR_BASE | (myCart.myReadOffset + myCart.myRamMask))
      << " used for read access";
  }

  return desc.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteArray& CartridgeEnhancedWidget::internalRamOld(int start, int count)
{
  myRamOld.clear();
  for(int i = 0; i < count; i++)
    myRamOld.push_back(myOldState.internalRam[start + i]);
  return myRamOld;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteArray& CartridgeEnhancedWidget::internalRamCurrent(int start, int count)
{
  myRamCurrent.clear();
  for(int i = 0; i < count; i++)
    myRamCurrent.push_back(myCart.myRAM[start + i]);
  return myRamCurrent;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeEnhancedWidget::internalRamSetValue(int addr, uInt8 value)
{
  myCart.myRAM[addr] = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeEnhancedWidget::internalRamGetValue(int addr)
{
  return myCart.myRAM[addr];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeEnhancedWidget::internalRamLabel(int addr)
{
  const CartDebug& dbg = instance().debugger().cartDebug();
  return dbg.getLabel(addr + ADDR_BASE + myCart.myReadOffset, false, -1, true);
}
