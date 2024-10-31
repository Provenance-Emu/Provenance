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

#include "DataGridRamWidget.hxx"
#include "EditTextWidget.hxx"
#include "GuiObject.hxx"
#include "InputTextDialog.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "Font.hxx"
#include "FBSurface.hxx"
#include "Widget.hxx"
#include "RamWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RamWidget::RamWidget(GuiObject* boss, const GUI::Font& lfont, const GUI::Font& nfont,
                     int x, int y, int w, int h,
                     uInt32 ramsize, uInt32 numrows, uInt32 pagesize,
                     string_view helpAnchor)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss),
    _nfont{nfont},
    myFontWidth{lfont.getMaxCharWidth()},
    myFontHeight{lfont.getFontHeight()},
    myLineHeight{lfont.getLineHeight()},
    myButtonHeight{static_cast<int>(myLineHeight * 1.25)},
    myRamSize{ramsize},
    myNumRows{numrows},
    myPageSize{pagesize}
{
  const int bwidth  = lfont.getStringWidth("Compare " + ELLIPSIS),
            bheight = myLineHeight + 2;
  //const int VGAP = 4;
  const int VGAP = myFontHeight / 4;
  StaticTextWidget* s = nullptr;
  WidgetArray wid;

  int ypos = y + myLineHeight;

  // Add RAM grid (with scrollbar)
  int xpos = x + _font.getStringWidth("xxxx");
  const bool useScrollbar = ramsize / numrows > 16;
  myRamGrid = new DataGridRamWidget(_boss, *this, _nfont, xpos, ypos,
                                    16, myNumRows, 2, 8, Common::Base::Fmt::_16, useScrollbar);
  myRamGrid->setHelpAnchor(helpAnchor, true);
  myRamGrid->setTarget(this);
  myRamGrid->setID(kRamGridID);
  addFocusWidget(myRamGrid);

  // Create actions buttons to the left of the RAM grid
  const int bx = xpos + myRamGrid->getWidth() + 4;
  int by = ypos;

  myUndoButton = new ButtonWidget(boss, lfont, bx, by, bwidth, bheight,
                                  "Undo", kUndoCmd);
  myUndoButton->setHelpAnchor("M6532Search", true);
  wid.push_back(myUndoButton);
  myUndoButton->setTarget(this);

  by += bheight + VGAP;
  myRevertButton = new ButtonWidget(boss, lfont, bx, by, bwidth, bheight,
                                    "Revert", kRevertCmd);
  myRevertButton->setHelpAnchor("M6532Search", true);
  wid.push_back(myRevertButton);
  myRevertButton->setTarget(this);

  by += bheight + VGAP * 6;
  mySearchButton = new ButtonWidget(boss, lfont, bx, by, bwidth, bheight,
                                    "Search" + ELLIPSIS, kSearchCmd);
  mySearchButton->setHelpAnchor("M6532Search", true);
  mySearchButton->setToolTip("Search and highlight found values.");
  wid.push_back(mySearchButton);
  mySearchButton->setTarget(this);

  by += bheight + VGAP;
  myCompareButton = new ButtonWidget(boss, lfont, bx, by, bwidth, bheight,
                                     "Compare" + ELLIPSIS, kCmpCmd);
  myCompareButton->setHelpAnchor("M6532Search", true);
  myCompareButton->setToolTip("Compare highlighted values.");
  wid.push_back(myCompareButton);
  myCompareButton->setTarget(this);

  by += bheight + VGAP;
  myRestartButton = new ButtonWidget(boss, lfont, bx, by, bwidth, bheight,
                                     "Reset", kRestartCmd);
  myRestartButton->setHelpAnchor("M6532Search", true);
  myRestartButton->setToolTip("Reset search/compare mode.");
  wid.push_back(myRestartButton);
  myRestartButton->setTarget(this);

  addToFocusList(wid);

  // Labels for RAM grid
  myRamStart =
    new StaticTextWidget(_boss, lfont, xpos - _font.getStringWidth("xxxx"),
                         ypos - myLineHeight,
                         lfont.getStringWidth("xxxx"), myFontHeight,
                        "00xx", TextAlign::Left);

  for(int col = 0; col < 16; ++col)
  {
    new StaticTextWidget(_boss, lfont, xpos + col*myRamGrid->colWidth() + 8,
                         ypos - myLineHeight,
                         myFontWidth, myFontHeight,
                         Common::Base::toString(col, Common::Base::Fmt::_16_1),
                         TextAlign::Left);
  }

  uInt32 row{0};
  for(row = 0; row < myNumRows; ++row)
  {
    myRamLabels[row] =
      new StaticTextWidget(_boss, _font, xpos - _font.getStringWidth("x "),
                           ypos + row*myLineHeight + 2,
                           myFontWidth, myFontHeight, "", TextAlign::Left);
  }

  // For smaller grids, make sure RAM cell detail fields are below the RESET button
  row = myNumRows < 8 ? 9 : myNumRows + 1;
  ypos += (row - 1) * myLineHeight + VGAP * 2;

  // We need to define these widgets from right to left since the leftmost
  // one resizes as much as possible

  // Add Binary display of selected RAM cell
  xpos = x + w - 9.6 * myFontWidth - 9;
  s = new StaticTextWidget(boss, lfont, xpos, ypos, "%");
  myBinValue = new DataGridWidget(boss, nfont, s->getRight() + myFontWidth * 0.1, ypos-2,
                                  1, 1, 8, 8, Common::Base::Fmt::_2);
  myBinValue->setHelpAnchor(helpAnchor, true);
  myBinValue->setTarget(this);
  myBinValue->setID(kRamBinID);

  // Add Decimal display of selected RAM cell
  xpos -= 6.5 * myFontWidth;
  s = new StaticTextWidget(boss, lfont, xpos, ypos, "#");
  myDecValue = new DataGridWidget(boss, nfont, s->getRight(), ypos-2,
                                  1, 1, 3, 8, Common::Base::Fmt::_10);
  myDecValue->setHelpAnchor(helpAnchor, true);
  myDecValue->setTarget(this);
  myDecValue->setID(kRamDecID);

  // Add Hex display of selected RAM cell
  xpos -= 4.5 * myFontWidth;
  myHexValue = new DataGridWidget(boss, nfont, xpos, ypos - 2,
                                  1, 1, 2, 8, Common::Base::Fmt::_16);
  myHexValue->setHelpAnchor(helpAnchor, true);
  myHexValue->setTarget(this);
  myHexValue->setID(kRamHexID);

  addFocusWidget(myHexValue);
  addFocusWidget(myDecValue);
  addFocusWidget(myBinValue);

  // Add Label of selected RAM cell
  const int xpos_r = xpos - myFontWidth * 1.5;
  xpos = x;
  s = new StaticTextWidget(boss, lfont, xpos, ypos, "Label");
  xpos = s->getRight() + myFontWidth / 2;
  myLabel = new EditTextWidget(boss, nfont, xpos, ypos-2, xpos_r-xpos,
                               myLineHeight);
  myLabel->setEditable(false, true);

  // Inputbox which will pop up when searching RAM
  const StringList labels = { "Value" };
  myInputBox = make_unique<InputTextDialog>(boss, lfont, nfont, labels, " ");
  myInputBox->setTextFilter([](char c) {
      return (c >= 'a' && c <= 'f') || (c >= '0' && c <= '9');
    }
  );
  myInputBox->setTarget(this);

  // Start with these buttons disabled
  myCompareButton->clearFlags(Widget::FLAG_ENABLED);
  myRestartButton->clearFlags(Widget::FLAG_ENABLED);

  // Calculate final height
  if(_h == 0)  _h = ypos + myLineHeight - y;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RamWidget::~RamWidget()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  // We simply change the values in the DataGridWidget
  // It will then send the 'kDGItemDataChangedCmd' signal to change the actual
  // memory location
  int addr = 0, value = 0;

  switch(cmd)
  {
    case DataGridWidget::kItemDataChangedCmd:
    {
      switch(id)
      {
        case kRamGridID:
          addr  = myRamGrid->getSelectedAddr();
          value = myRamGrid->getSelectedValue();
          break;

        case kRamHexID:
          addr  = myRamGrid->getSelectedAddr();
          value = myHexValue->getSelectedValue();
          break;

        case kRamDecID:
          addr  = myRamGrid->getSelectedAddr();
          value = myDecValue->getSelectedValue();
          break;

        case kRamBinID:
          addr  = myRamGrid->getSelectedAddr();
          value = myBinValue->getSelectedValue();
          break;

        default:
          break;
      }

      const uInt8 oldval = getValue(addr);
      setValue(addr, value);

      myUndoAddress = addr;
      myUndoValue = oldval;

      myRamGrid->setValueInternal(addr - myCurrentRamBank*myPageSize, value, true);
      myHexValue->setValueInternal(0, value, true);
      myDecValue->setValueInternal(0, value, true);
      myBinValue->setValueInternal(0, value, true);

      myRevertButton->setEnabled(true);
      myUndoButton->setEnabled(true);
      break;
    }

    case DataGridWidget::kSelectionChangedCmd:
    {
      addr  = myRamGrid->getSelectedAddr();
      value = myRamGrid->getSelectedValue();
      const bool changed = myRamGrid->getSelectedChanged();

      myLabel->setText(getLabel(addr));
      myHexValue->setValueInternal(0, value, changed);
      myDecValue->setValueInternal(0, value, changed);
      myBinValue->setValueInternal(0, value, changed);
      break;
    }

    case kRevertCmd:
      for(uInt32 i = 0; i < myOldValueList.size(); ++i)
        setValue(i, myOldValueList[i]);
      fillGrid(true);
      break;

    case kUndoCmd:
      setValue(myUndoAddress, myUndoValue);
      myUndoButton->setEnabled(false);
      fillGrid(false);
      break;

    case kSearchCmd:
      showInputBox(kSValEntered);
      break;

    case kCmpCmd:
      showInputBox(kCValEntered);
      break;

    case kRestartCmd:
      doRestart();
      break;

    case kSValEntered:
    {
      const string& result = doSearch(myInputBox->getResult());
      if(!result.empty())
        myInputBox->setMessage(result);
      else
        myInputBox->close();
      break;
    }

    case kCValEntered:
    {
      const string& result = doCompare(myInputBox->getResult());
      if(!result.empty())
        myInputBox->setMessage(result);
      else
        myInputBox->close();
      break;
    }

    case GuiObject::kSetPositionCmd:
      myCurrentRamBank = data;
      showSearchResults();
      fillGrid(false);
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::setOpsWidget(DataGridOpsWidget* w)
{
  myRamGrid->setOpsWidget(w);
  myHexValue->setOpsWidget(w);
  myBinValue->setOpsWidget(w);
  myDecValue->setOpsWidget(w);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::loadConfig()
{
  fillGrid(true);

  const int value = myRamGrid->getSelectedValue();
  const bool changed = myRamGrid->getSelectedChanged();

  myHexValue->setValueInternal(0, value, changed);
  myDecValue->setValueInternal(0, value, changed);
  myBinValue->setValueInternal(0, value, changed);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::fillGrid(bool updateOld)
{
  IntArray alist;
  IntArray vlist;
  BoolArray changed;

  const uInt32 start = myCurrentRamBank * myPageSize;
  fillList(start, myPageSize, alist, vlist, changed);

  if(updateOld)
    myOldValueList = currentRam(start);

  myRamGrid->setNumRows(myRamSize / myPageSize);
  myRamGrid->setList(alist, vlist, changed);
  if(updateOld)
  {
    myRevertButton->setEnabled(false);
    myUndoButton->setEnabled(false);
  }

  // Update RAM labels
  const uInt32 rport = readPort(start);
  int page = rport & 0xf0;
  string label = Common::Base::toString(rport, Common::Base::Fmt::_16_4);

  label[2] = label[3] = 'x';
  myRamStart->setLabel(label);
  for(uInt32 row = 0; row < myNumRows; ++row, page += 0x10)
    myRamLabels[row]->setLabel(Common::Base::toString(page>>4, Common::Base::Fmt::_16_1));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::showInputBox(int cmd)
{
  // Add inputbox in the middle of the RAM widget
  const uInt32 x = getAbsX() + ((getWidth() - myInputBox->getWidth()) >> 1);
  const uInt32 y = getAbsY() + ((getHeight() - myInputBox->getHeight()) >> 1);

  myInputBox->show(x, y, dialog().surface().dstRect());
  myInputBox->setText("");
  myInputBox->setMessage("");
  myInputBox->setToolTip(cmd == kSValEntered
                         ? "Enter search value (leave blank for all)."
                         : "Enter relative or absolute value\nto compare with searched values.");
  myInputBox->setFocus(0);
  myInputBox->setEmitSignal(cmd);
  myInputBox->setTitle(cmd == kSValEntered ? "Search" : "Compare");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string RamWidget::doSearch(string_view str)
{
  bool comparisonSearch = true;

  if(str.empty())
  {
    // An empty field means return all memory locations
    comparisonSearch = false;
  }
  else if(str.find_first_of("+-", 0) != string::npos)
  {
    // Don't accept these characters here, only in compare
    return "Invalid input +|-";
  }

  const int searchVal = instance().debugger().stringToValue(str);

  // Clear the search array of previous items
  mySearchAddr.clear();
  mySearchValue.clear();
  mySearchState.clear();

  // Now, search all memory locations for this value, and add it to the
  // search array
  const ByteArray& ram = currentRam(0);
  bool hitfound = false;
  for(uInt32 addr = 0; addr < ram.size(); ++addr)
  {
    const int value = ram[addr];
    if(comparisonSearch && searchVal != value)
    {
      mySearchState.push_back(false);
    }
    else
    {
      mySearchAddr.push_back(addr);
      mySearchValue.push_back(value);
      mySearchState.push_back(true);
      hitfound = true;
    }
  }

  // If we have some hits, enable the comparison methods
  if(hitfound)
  {
    mySearchButton->setEnabled(false);
    myCompareButton->setEnabled(true);
    myRestartButton->setEnabled(true);
  }

  // Finally, show the search results in the list
  showSearchResults();

  return EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string RamWidget::doCompare(string_view str)
{
  bool comparativeSearch = false;
  int searchVal = 0, offset = 0;

  if(str.empty())
    return "Enter an absolute or comparative value";

  // Do some pre-processing on the string
  const string::size_type pos = str.find_first_of("+-", 0);
  if(pos > 0 && pos != string::npos)
  {
    // Only accept '+' or '-' at the start of the string
    return "Input must be [+|-]NUM";
  }

  // A comparative search searches memory for locations that have changed by
  // the specified amount, vs. for exact values
  if(str[0] == '+' || str[0] == '-')
  {
    comparativeSearch = true;
    bool negative = false;
    if(str[0] == '-')
      negative = true;

    string tmp{str};
    tmp.erase(0, 1);  // remove the operator
    offset = instance().debugger().stringToValue(tmp);
    if(negative)
      offset = -offset;
  }
  else
    searchVal = instance().debugger().stringToValue(str);

  // Now, search all memory locations previously 'found' for this value
  const ByteArray& ram = currentRam(0);
  bool hitfound = false;
  IntArray tempAddrList, tempValueList;
  mySearchState.clear();
  for(uInt32 i = 0; i < ram.size(); ++i)
    mySearchState.push_back(false);

  for(uInt32 i = 0; i < mySearchAddr.size(); ++i)
  {
    if(comparativeSearch)
    {
      searchVal = mySearchValue[i] + offset;
      if(searchVal < 0 || searchVal > 255)
        continue;
    }

    const int addr = mySearchAddr[i];
    if(ram[addr] == searchVal)
    {
      tempAddrList.push_back(addr);
      tempValueList.push_back(searchVal);
      mySearchState[addr] = hitfound = true;
    }
  }

  // Update the searchArray for the new addresses and data
  mySearchAddr = tempAddrList;
  mySearchValue = tempValueList;

  // If we have some hits, enable the comparison methods
  if(hitfound)
  {
    myCompareButton->setEnabled(true);
    myRestartButton->setEnabled(true);
  }

  // Finally, show the search results in the list
  showSearchResults();

  return EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::doRestart()
{
  // Erase all search buffers, reset to start mode
  mySearchAddr.clear();
  mySearchValue.clear();
  mySearchState.clear();
  showSearchResults();

  mySearchButton->setEnabled(true);
  myCompareButton->setEnabled(false);
  myRestartButton->setEnabled(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RamWidget::showSearchResults()
{
  // Only update the search results for the bank currently being shown
  BoolArray temp;
  const uInt32 start = myCurrentRamBank * myPageSize;
  if(mySearchState.empty() || start > mySearchState.size())
  {
    for(uInt32 i = 0; i < myPageSize; ++i)
      temp.push_back(false);
  }
  else
  {
    for(uInt32 i = start; i < start + myPageSize; ++i)
      temp.push_back(mySearchState[i]);
  }
  myRamGrid->setHiliteList(temp);
}
