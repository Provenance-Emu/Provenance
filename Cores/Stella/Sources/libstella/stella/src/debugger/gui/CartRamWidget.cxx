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
#include "GuiObject.hxx"
#include "CartDebug.hxx"
#include "StringParser.hxx"
#include "Widget.hxx"
#include "Font.hxx"
#include "StringListWidget.hxx"
#include "ScrollBarWidget.hxx"
#include "CartDebugWidget.hxx"
#include "CartRamWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartRamWidget::CartRamWidget(
      GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
      int x, int y, int w, int h, CartDebugWidget& cartDebug)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss),
    _nfont{nfont},
    myFontWidth{lfont.getMaxCharWidth()},
    myFontHeight{lfont.getFontHeight()},
    myLineHeight{lfont.getLineHeight()},
    myButtonHeight{myLineHeight + 4}
{
  const int lwidth = lfont.getStringWidth("Description "),
            fwidth = w - lwidth - 20;

  EditTextWidget* etw = nullptr;
  ostringstream buf;
  constexpr int xpos = 2;
  int ypos = 8;

  // Add RAM size
  new StaticTextWidget(_boss, _font, xpos, ypos + 1, "RAM size ");

  const uInt32 ramsize = cartDebug.internalRamSize();
  buf << ramsize << " bytes";
  if(ramsize >= 1024)
    buf << " / " << (ramsize/1024) << "KB";

  etw = new EditTextWidget(boss, nfont, xpos+lwidth, ypos - 1,
                         fwidth, myLineHeight, buf.str());
  etw->setEditable(false);
  ypos += myLineHeight + 4;

  // Add Description
  const string& desc = cartDebug.internalRamDescription();
  constexpr uInt16 maxlines = 6;
  const StringParser bs(desc, (fwidth - ScrollBarWidget::scrollBarWidth(_font)) / myFontWidth);
  const StringList& sl = bs.stringList();
  auto lines = static_cast<uInt32>(sl.size());
  bool useScrollbar = false;

  if(lines < 2) lines = 2;
  if(lines > maxlines)
  {
    lines = maxlines;
    useScrollbar = true;
  }

  new StaticTextWidget(_boss, _font, xpos, ypos + 1, "Description ");
  myDesc = new StringListWidget(boss, nfont, xpos+lwidth, ypos - 1,
                                fwidth, lines * myLineHeight, false, useScrollbar);
  myDesc->setEditable(false);
  myDesc->setEnabled(false);
  myDesc->setList(sl);

  ypos += myDesc->getHeight() + myFontHeight / 2;

  // Add RAM widget
  myRam = new InternalRamWidget(boss, lfont, nfont, 2, ypos, w, h-ypos, cartDebug);
  addToFocusList(myRam->getFocusList());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartRamWidget::loadConfig()
{
  myRam->loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartRamWidget::setOpsWidget(DataGridOpsWidget* w)
{
  myRam->setOpsWidget(w);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartRamWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  myRam->handleCommand(sender, cmd, data, id);
}

///////////////////////////////////
// Internal RAM implementation
///////////////////////////////////

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartRamWidget::InternalRamWidget::InternalRamWidget(GuiObject* boss,
        const GUI::Font& lfont, const GUI::Font& nfont,
        int x, int y, int w, int h,
        CartDebugWidget& dbg)
  : RamWidget(boss, lfont, nfont, x, y, w, h,
      dbg.internalRamSize(), std::min(dbg.internalRamSize() / 16, 16U),
      std::min(dbg.internalRamSize() / 16, 16U) * 16, "CartridgeRAMInformation"),
    myCart(dbg)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartRamWidget::InternalRamWidget::getValue(int addr) const
{
  return myCart.internalRamGetValue(addr);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartRamWidget::InternalRamWidget::setValue(int addr, uInt8 value)
{
  myCart.internalRamSetValue(addr, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string CartRamWidget::InternalRamWidget::getLabel(int addr) const
{
  return myCart.internalRamLabel(addr);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartRamWidget::InternalRamWidget::fillList(uInt32 start, uInt32 size,
          IntArray& alist, IntArray& vlist, BoolArray& changed) const
{
  const ByteArray& oldRam = myCart.internalRamOld(start, size);
  const ByteArray& currRam = myCart.internalRamCurrent(start, size);

  for(uInt32 i = 0; i < size; ++i)
  {
    alist.push_back(i+start);
    vlist.push_back(currRam[i]);
    changed.push_back(currRam[i] != oldRam[i]);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 CartRamWidget::InternalRamWidget::readPort(uInt32 start) const
{
  return myCart.internalRamRPort(start);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteArray& CartRamWidget::InternalRamWidget::currentRam(uInt32 start) const
{
  return myCart.internalRamCurrent(start, myCart.internalRamSize());
}
