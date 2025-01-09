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

#include "CartBUS.hxx"
#include "DataGridWidget.hxx"
#include "PopUpWidget.hxx"
#include "CartBUSWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeBUSWidget::CartridgeBUSWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartridgeBUS& cart)
  : CartridgeARMWidget(boss, lfont, nfont, x, y, w, h, cart),
    myCart{cart}
{
  constexpr int VBORDER = 8,
                HBORDER = 2,
                INDENT = 20,
                VGAP = 4;

  int xpos = HBORDER, ypos = VBORDER;
  int ds2_rows = 0;

//  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS0)
//  {
//    int lwidth = _font.getStringWidth("Unsupported version of BUS"); // get width of the widest label
//    new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
//                         myFontHeight, "Unsupported version of BUS", TextAlign::Left);
//    return;
//  }

  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
  {
    ds2_rows = 2;
    myDatastreamCount = 18;
  }
  else
  {
    ds2_rows = 4;
    myDatastreamCount = 20;
  }

  VariantList items;
  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS0)
  {
    VarList::push_back(items, "0 ($FFF6)");
    VarList::push_back(items, "1 ($FFF7)");
    VarList::push_back(items, "2 ($FFF8)");
    VarList::push_back(items, "3 ($FFF9)");
    VarList::push_back(items, "4 ($FFFA)");
    VarList::push_back(items, "5 ($FFFB)");
  }
  else
  {
    VarList::push_back(items, "0 ($FFF5)");
    VarList::push_back(items, "1 ($FFF6)");
    VarList::push_back(items, "2 ($FFF7)");
    VarList::push_back(items, "3 ($FFF8)");
    VarList::push_back(items, "4 ($FFF9)");
    VarList::push_back(items, "5 ($FFFA)");
    VarList::push_back(items, "6 ($FFFB)");
  }
  myBank =
    new PopUpWidget(boss, _font, xpos, ypos-2, _font.getStringWidth("0 ($FFFx)"),
                    myLineHeight, items, "Set bank     ",
                    0, kBankChanged);
  myBank->setTarget(this);
  addFocusWidget(myBank);

  int lwidth = _font.getStringWidth("Datastream Increments "); // get width of the widest label

  // Datastream Pointers
#define DS_X 30
  xpos = DS_X;
  ypos += myLineHeight + VGAP;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
                       myFontHeight, "Datastream Pointers", TextAlign::Left);

  myDatastreamPointers = new DataGridWidget(boss, _nfont, DS_X, ypos+myLineHeight-2, 4, 4, 6, 32, Common::Base::Fmt::_16_3_2);
  myDatastreamPointers->setTarget(this);
  myDatastreamPointers->setEditable(false);

  myDatastreamPointers2 = new DataGridWidget(boss, _nfont, DS_X + myDatastreamPointers->getWidth() * 3 / 4, ypos+myLineHeight-2 + 4*myLineHeight, 1, ds2_rows, 6, 32, Common::Base::Fmt::_16_3_2);
  myDatastreamPointers2->setTarget(this);
  myDatastreamPointers2->setEditable(false);

  for(uInt32 row = 0; row < 4; ++row)
  {
    myDatastreamLabels[row] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + row*myLineHeight + 2,
                         myFontWidth*2, myFontHeight, "", TextAlign::Left);
    myDatastreamLabels[row]->setLabel(Common::Base::toString(row * 4, Common::Base::Fmt::_16_2));
  }

  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
  {
    lwidth = _font.getStringWidth("Write Data (stream 16)");
    myDatastreamLabels[4] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + 4*myLineHeight + 2,
                         lwidth, myFontHeight, "Write Data (stream 16)", TextAlign::Left);
    myDatastreamLabels[5] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + 5*myLineHeight + 2,
                         lwidth, myFontHeight, "Jump Data (stream 17)", TextAlign::Left);
  }
  else
  {
    lwidth = _font.getStringWidth("Write Data 0 (stream 16)");
    myDatastreamLabels[4] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + 4*myLineHeight + 2,
                         lwidth, myFontHeight, "Write Data 0(stream 16)", TextAlign::Left);
    myDatastreamLabels[5] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + 5*myLineHeight + 2,
                         lwidth, myFontHeight, "Write Data 1(stream 17)", TextAlign::Left);
    myDatastreamLabels[6] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + 6*myLineHeight + 2,
                         lwidth, myFontHeight, "Write Data 2(stream 18)", TextAlign::Left);
    myDatastreamLabels[7] =
    new StaticTextWidget(_boss, _font, DS_X - _font.getStringWidth("xx "),
                         ypos+myLineHeight-2 + 7*myLineHeight + 2,
                         lwidth, myFontHeight, "Write Data 3(stream 19)", TextAlign::Left);
  }

  // Datastream Increments
  xpos = DS_X + myDatastreamPointers->getWidth() + INDENT;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
                       myFontHeight, "Datastream Increments", TextAlign::Left);

  myDatastreamIncrements = new DataGridWidget(boss, _nfont, xpos, ypos+myLineHeight-2, 4, 4, 5, 32, Common::Base::Fmt::_16_2_2);
  myDatastreamIncrements->setTarget(this);
  myDatastreamIncrements->setEditable(false);

  myDatastreamIncrements2 = new DataGridWidget(boss, _nfont, xpos, ypos+myLineHeight-2 + 4*myLineHeight, 1, ds2_rows, 5, 32, Common::Base::Fmt::_16_2_2);
  myDatastreamIncrements2->setTarget(this);
  myDatastreamIncrements2->setEditable(false);

  // Datastream Maps
  xpos = 0;  ypos += myLineHeight*(5 + ds2_rows) + VGAP;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
                       myFontHeight, "Address Maps", TextAlign::Left);

  myAddressMaps = new DataGridWidget(boss, _nfont, 0, ypos+myLineHeight-2, 8, 5, 8, 32, Common::Base::Fmt::_16_8);
  myAddressMaps->setTarget(this);
  myAddressMaps->setEditable(false);

  // Music counters
  xpos = 10;  ypos += myLineHeight*6 + VGAP;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
        myFontHeight, "Music Counters", TextAlign::Left);
  xpos += lwidth;

  myMusicCounters = new DataGridWidget(boss, _nfont, xpos, ypos-2, 3, 1, 8, 32, Common::Base::Fmt::_16_8);
  myMusicCounters->setTarget(this);
  myMusicCounters->setEditable(false);

  // Music frequencies
  xpos = 10;  ypos += myLineHeight + VGAP;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
        myFontHeight, "Music Frequencies", TextAlign::Left);
  xpos += lwidth;

  myMusicFrequencies = new DataGridWidget(boss, _nfont, xpos, ypos-2, 3, 1, 8, 32, Common::Base::Fmt::_16_8);
  myMusicFrequencies->setTarget(this);
  myMusicFrequencies->setEditable(false);

  // Music waveforms
  xpos = 10;  ypos += myLineHeight + VGAP;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
        myFontHeight, "Music Waveforms", TextAlign::Left);
  xpos += lwidth;

  myMusicWaveforms = new DataGridWidget(boss, _nfont, xpos, ypos-2, 3, 1, 4, 16, Common::Base::Fmt::_16_2);
  myMusicWaveforms->setTarget(this);
  myMusicWaveforms->setEditable(false);

  const int xpossp = xpos + myMusicWaveforms->getWidth() + INDENT;
  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
  {
    const int lwidth2 = _font.getStringWidth("Sample Pointer ");
    new StaticTextWidget(boss, _font, xpossp, ypos, lwidth2,
                         myFontHeight, "Sample Pointer ", TextAlign::Left);

    mySamplePointer = new DataGridWidget(boss, _nfont, xpossp + lwidth2, ypos-2, 1, 1, 8, 32, Common::Base::Fmt::_16_8);
    mySamplePointer->setTarget(this);
    mySamplePointer->setEditable(false);
  }

  // Music waveform sizes
  xpos = 10;  ypos += myLineHeight + VGAP;
  new StaticTextWidget(boss, _font, xpos, ypos, lwidth,
                       myFontHeight, "Music Waveform Sizes", TextAlign::Left);
  xpos += lwidth;

  myMusicWaveformSizes = new DataGridWidget(boss, _nfont, xpos, ypos-2, 3, 1, 4, 16, Common::Base::Fmt::_16_2);
  myMusicWaveformSizes->setTarget(this);
  myMusicWaveformSizes->setEditable(false);


  // BUS stuff and Digital Audio flags
  xpos = 10;  ypos += myLineHeight + VGAP;
  myBusOverdrive = new CheckboxWidget(boss, _font, xpos, ypos, "BUS Overdrive enabled");
  myBusOverdrive->setTarget(this);
  myBusOverdrive->setEditable(false);

  if (cart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
  {
    myDigitalSample = new CheckboxWidget(boss, _font, xpossp, ypos, "Digital Sample mode");
    myDigitalSample->setTarget(this);
    myDigitalSample->setEditable(false);
  }
  xpos = 10;  ypos += myLineHeight + VGAP * 2;
  addCycleWidgets(xpos, ypos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUSWidget::saveOldState()
{
  myOldState.tops.clear();
  myOldState.bottoms.clear();
  myOldState.datastreampointers.clear();
  myOldState.datastreamincrements.clear();
  myOldState.addressmaps.clear();
  myOldState.mcounters.clear();
  myOldState.mfreqs.clear();
  myOldState.mwaves.clear();
  myOldState.mwavesizes.clear();
  myOldState.internalram.clear();
  myOldState.samplepointer.clear();

  for(int i = 0; i < myDatastreamCount; ++i)
  {
    // Pointers are stored as:
    // PPPFF---
    //
    // Increments are stored as
    // ----IIFF
    //
    // P = Pointer
    // I = Increment
    // F = Fractional

    myOldState.datastreampointers.push_back(myCart.getDatastreamPointer(i)>>12);
    if (i < 16)
      myOldState.datastreamincrements.push_back(myCart.getDatastreamIncrement(i));
    else
      myOldState.datastreamincrements.push_back(0x100);
  }

  for(uInt32 i = 0; i < 37; ++i) // only 37 map values
    myOldState.addressmaps.push_back(myCart.getAddressMap(i));

  for(uInt32 i = 37; i < 40; ++i) // but need 40 for the grid
    myOldState.addressmaps.push_back(0);

  for(uInt32 i = 0; i < 3; ++i)
    myOldState.mcounters.push_back(myCart.myMusicCounters[i]);

  for(uInt32 i = 0; i < 3; ++i)
  {
    myOldState.mfreqs.push_back(myCart.myMusicFrequencies[i]);
    myOldState.mwaves.push_back(myCart.getWaveform(i) >> 5);
    myOldState.mwavesizes.push_back(myCart.getWaveformSize((i)));
  }

  for(uInt32 i = 0; i < internalRamSize(); ++i)
    myOldState.internalram.push_back(myCart.myRAM[i]);

  myOldState.samplepointer.push_back(myCart.getSample());

  CartridgeARMWidget::saveOldState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUSWidget::loadConfig()
{
//  if (myCart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS0)
//    return;

  myBank->setSelectedIndex(myCart.getBank());

  // Get registers, using change tracking
  IntArray alist;
  IntArray vlist;
  BoolArray changed;

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 16; ++i)
  {
    // Pointers are stored as:
    // PPPFF---
    //
    // Increments are stored as
    // ----IIFF
    //
    // P = Pointer
    // I = Increment
    // F = Fractional

    const Int32 pointervalue = myCart.getDatastreamPointer(i) >> 12;
    alist.push_back(0);  vlist.push_back(pointervalue);
    changed.push_back(pointervalue != myOldState.datastreampointers[i]);
  }
  myDatastreamPointers->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 16; i < myDatastreamCount; ++i)
  {
    const Int32 pointervalue = myCart.getDatastreamPointer(i) >> 12;
    alist.push_back(0);  vlist.push_back(pointervalue);
    changed.push_back(pointervalue != myOldState.datastreampointers[i]);
  }
  myDatastreamPointers2->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 16; ++i)
  {
    const Int32 incrementvalue = myCart.getDatastreamIncrement(i);
    alist.push_back(0);  vlist.push_back(incrementvalue);
    changed.push_back(incrementvalue != myOldState.datastreamincrements[i]);
  }
  myDatastreamIncrements->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 16; i < myDatastreamCount; ++i)
  {
    constexpr Int32 incrementvalue = 0x100;
    alist.push_back(0);  vlist.push_back(incrementvalue);
    changed.push_back(incrementvalue != myOldState.datastreamincrements[i]);
  }
  myDatastreamIncrements2->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 37; ++i) // only 37 map values
  {
    const Int32 mapvalue = myCart.getAddressMap(i);
    alist.push_back(0);  vlist.push_back(mapvalue);
    changed.push_back(mapvalue != myOldState.addressmaps[i]);
  }
  for(int i = 37; i < 40; ++i) // but need 40 for the grid
  {
    constexpr Int32 mapvalue = 0;
    alist.push_back(0);  vlist.push_back(mapvalue);
    changed.push_back(mapvalue != myOldState.addressmaps[i]);
  }
  myAddressMaps->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 3; ++i)
  {
    alist.push_back(0);  vlist.push_back(myCart.myMusicCounters[i]);
    changed.push_back(myCart.myMusicCounters[i] !=
      static_cast<uInt32>(myOldState.mcounters[i]));
  }
  myMusicCounters->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 3; ++i)
  {
    alist.push_back(0);  vlist.push_back(myCart.myMusicFrequencies[i]);
    changed.push_back(myCart.myMusicFrequencies[i] !=
      static_cast<uInt32>(myOldState.mfreqs[i]));
  }
  myMusicFrequencies->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 3; ++i)
  {
    alist.push_back(0);  vlist.push_back(myCart.getWaveform(i) >> 5);
    changed.push_back((myCart.getWaveform(i) >> 5) !=
      static_cast<uInt32>(myOldState.mwaves[i]));
  }
  myMusicWaveforms->setList(alist, vlist, changed);

  alist.clear();  vlist.clear();  changed.clear();
  for(int i = 0; i < 3; ++i)
  {
    alist.push_back(0);  vlist.push_back(myCart.getWaveformSize(i));
    changed.push_back((myCart.getWaveformSize(i)) !=
      static_cast<uInt32>(myOldState.mwavesizes[i]));
  }
  myMusicWaveformSizes->setList(alist, vlist, changed);

  if (myCart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
  {
    alist.clear();  vlist.clear();  changed.clear();
    alist.push_back(0);  vlist.push_back(myCart.getSample());
    changed.push_back((myCart.getSample()) !=
      static_cast<uInt32>(myOldState.samplepointer[0]));
    mySamplePointer->setList(alist, vlist, changed);
  }

  myBusOverdrive->setState((myCart.myMode & 0x0f) == 0);
  if (myCart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
    myDigitalSample->setState((myCart.myMode & 0xf0) == 0);

  if ((myCart.myMode & 0xf0) == 0)
  {
    myMusicWaveforms->setCrossed(true);
    myMusicWaveformSizes->setCrossed(true);
    if (myCart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
      mySamplePointer->setCrossed(false);
  }
  else
  {
    myMusicWaveforms->setCrossed(false);
    myMusicWaveformSizes->setCrossed(false);
    if (myCart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS3)
      mySamplePointer->setCrossed(true);
  }

  CartridgeARMWidget::loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUSWidget::handleCommand(CommandSender* sender,
                                       int cmd, int data, int id)
{
  if(cmd == kBankChanged)
  {
    myCart.unlockHotspots();
    myCart.bank(myBank->getSelected());
    myCart.lockHotspots();
    invalidate();
  }
  else
    CartridgeARMWidget::handleCommand(sender, cmd, data, id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeBUSWidget::bankState()
{
  ostringstream& buf = buffer();

  if (myCart.myBUSSubtype == CartridgeBUS::BUSSubtype::BUS0)
  {
    static constexpr std::array<string_view, 6> spot = {
      "$FFF6", "$FFF7", "$FFF8", "$FFF9", "$FFFA", "$FFFB"
    };
    buf << "Bank = " << std::dec << myCart.getBank()
        << ", hotspot = " << spot[myCart.getBank()];
  }
  else
  {
    static constexpr std::array<string_view, 7> spot = {
      "$FFF5", "$FFF6", "$FFF7", "$FFF8", "$FFF9", "$FFFA", "$FFFB"
    };
    buf << "Bank = " << std::dec << myCart.getBank()
        << ", hotspot = " << spot[myCart.getBank()];
  }

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUSWidget::internalRamSize()
{
  return 8*1024;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartridgeBUSWidget::internalRamRPort(int start)
{
  return 0x0000 + start;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartridgeBUSWidget::internalRamDescription()
{
  ostringstream desc;
  desc << "$0000 - $07FF - BUS driver\n"
       << "                not accessible to 6507\n"
       << "$0800 - $17FF - 4K Data Stream storage\n"
       << "                indirectly accessible to 6507\n"
       << "                via BUS's Data Stream registers\n"
       << "$1800 - $1FFF - 2K C variable storage and stack\n"
       << "                not accessible to 6507";

  return desc.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteArray& CartridgeBUSWidget::internalRamOld(int start, int count)
{
  myRamOld.clear();
  for(int i = 0; i < count; i++)
    myRamOld.push_back(myOldState.internalram[start + i]);
  return myRamOld;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteArray& CartridgeBUSWidget::internalRamCurrent(int start, int count)
{
  myRamCurrent.clear();
  for(int i = 0; i < count; i++)
    myRamCurrent.push_back(myCart.myRAM[start + i]);
  return myRamCurrent;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeBUSWidget::internalRamSetValue(int addr, uInt8 value)
{
  myCart.myRAM[addr] = value;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeBUSWidget::internalRamGetValue(int addr)
{
  return myCart.myRAM[addr];
}
