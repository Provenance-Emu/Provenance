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

#include "RamWidget.hxx"
#include "DataGridRamWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DataGridRamWidget::DataGridRamWidget(GuiObject* boss, const RamWidget& ram,
                                     const GUI::Font& font,
                                     int x, int y, int cols, int rows,
                                     int colchars, int bits,
                                     Common::Base::Fmt base,
                                     bool useScrollbar)
  : DataGridWidget(boss, font, x, y, cols, rows, colchars,
                   bits, base, useScrollbar),
    _ram{ram}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DataGridRamWidget::getToolTip(const Common::Point& pos) const
{
  const int idx = getToolTipIndex(pos);

  if(idx < 0)
    return EmptyString;

  const Int32 addr = _addrList[idx];
  const string label = _ram.getLabel(addr);
  string tip = DataGridWidget::getToolTip(pos);

  if(label.empty())
    return tip;

  ostringstream buf;

  buf << label << '\n' << tip;

  return buf.str();
}
