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

#include "Font.hxx"
#include "RomWidget.hxx"
#include "EditTextWidget.hxx"
#include "StringListWidget.hxx"
#include "ScrollBarWidget.hxx"
#include "StringParser.hxx"
#include "CartDebugWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartDebugWidget::CartDebugWidget(GuiObject* boss, const GUI::Font& lfont,
                                 const GUI::Font& nfont,
                                 int x, int y, int w, int h)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss),
    _nfont{nfont},
    myFontWidth{lfont.getMaxCharWidth()},
    myFontHeight{lfont.getFontHeight()},
    myLineHeight{lfont.getLineHeight()},
    myButtonHeight{myLineHeight + 4}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int CartDebugWidget::addBaseInformation(size_t bytes, string_view manufacturer,
        string_view desc, const uInt16 maxlines)
{
  const int lwidth = _font.getStringWidth("Manufacturer "),
            fwidth = _w - lwidth - 12;
  EditTextWidget* w = nullptr;
  ostringstream buf;

  constexpr int x = 2;
  int y = 8;

  // Add ROM size, manufacturer and bankswitch info
  new StaticTextWidget(_boss, _font, x, y + 1, "ROM size ");
  buf << bytes << " bytes";
  if(bytes >= 1024)
    buf << " / " << (bytes/1024) << "KB";

  w = new EditTextWidget(_boss, _nfont, x+lwidth, y - 1,
                         fwidth, myLineHeight, buf.str());
  w->setEditable(false);
  y += myLineHeight + 4;

  new StaticTextWidget(_boss, _font, x, y + 1, "Manufacturer ");
  w = new EditTextWidget(_boss, _nfont, x+lwidth, y - 1,
                         fwidth, myLineHeight, manufacturer);
  w->setEditable(false);
  y += myLineHeight + 4;

  const StringParser bs(desc, (fwidth - ScrollBarWidget::scrollBarWidth(_font)) /
    myFontWidth);
  const StringList& sl = bs.stringList();
  size_t lines = sl.size();
  if(lines < 3) lines = 3;
  bool useScrollbar = false;
  if(lines > maxlines)
  {
    lines = maxlines;
    useScrollbar = true;
  }

  new StaticTextWidget(_boss, _font, x, y + 1, "Description ");
  myDesc = new StringListWidget(_boss, _nfont, x+lwidth, y - 1,
                                fwidth, static_cast<int>(lines) * myLineHeight,
                                false, useScrollbar);
  myDesc->setEditable(false);
  myDesc->setEnabled(false);
  myDesc->setList(sl);

  y += myDesc->getHeight() + 4;

  return y;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebugWidget::invalidate()
{
  sendCommand(RomWidget::kInvalidateListing, -1, -1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartDebugWidget::loadConfig()
{
  //myDesc->setSelected(0);
}
