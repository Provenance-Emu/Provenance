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

#include "Command.hxx"
#include "Dialog.hxx"
#include "EditTextWidget.hxx"
#include "FBSurface.hxx"
#include "FileListWidget.hxx"
#include "Icons.hxx"
#include "OSystem.hxx"

#include "NavigationWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
NavigationWidget::NavigationWidget(GuiObject* boss, const GUI::Font& font,
    int xpos, int ypos, int w, int h)
  : Widget(boss, font, xpos, ypos, w, h)
{
  // Add some buttons and textfield to show current directory
  const int lineHeight = _font.getLineHeight();
  myUseMinimalUI = instance().settings().getBool("minimal_ui");

  if(!myUseMinimalUI)
  {
    const int
      fontWidth    = _font.getMaxCharWidth(),
      BTN_GAP      = fontWidth / 4;
    const bool smallIcon = lineHeight < 26;
    const GUI::Icon& homeIcon = smallIcon ? GUI::icon_home_small : GUI::icon_home_large;
    const GUI::Icon& prevIcon = smallIcon ? GUI::icon_prev_small : GUI::icon_prev_large;
    const GUI::Icon& nextIcon = smallIcon ? GUI::icon_next_small : GUI::icon_next_large;
    const GUI::Icon& upIcon = smallIcon ? GUI::icon_up_small : GUI::icon_up_large;
    const int iconWidth = homeIcon.width();
    const int buttonWidth = iconWidth + ((fontWidth + 1) & ~0b1) + 1; // round up to next odd
    const int buttonHeight = h;
#ifndef BSPF_MACOS
    const string altKey = "Alt";
#else
    const string altKey = "Cmd";
#endif


    myHomeButton = new ButtonWidget(boss, _font, xpos, ypos,
      buttonWidth, buttonHeight, homeIcon, FileListWidget::kHomeDirCmd);
    myHomeButton->setToolTip("Go back to initial directory. (" + altKey + "+Pos1)");
    boss->addFocusWidget(myHomeButton);
    xpos = myHomeButton->getRight() + BTN_GAP;

    myPrevButton = new ButtonWidget(boss, _font, xpos, ypos,
      buttonWidth, buttonHeight, prevIcon, FileListWidget::kPrevDirCmd);
    myPrevButton->setToolTip("Go back in directory history. (" + altKey + "+Left)");
    boss->addFocusWidget(myPrevButton);
    xpos = myPrevButton->getRight() + BTN_GAP;

    myNextButton = new ButtonWidget(boss, _font, xpos, ypos,
      buttonWidth, buttonHeight, nextIcon, FileListWidget::kNextDirCmd);
    myNextButton->setToolTip("Go forward in directory history. (" + altKey + "+Right)");
    boss->addFocusWidget(myNextButton);
    xpos = myNextButton->getRight() + BTN_GAP;

    myUpButton = new ButtonWidget(boss, _font, xpos, ypos,
      buttonWidth, buttonHeight, upIcon, ListWidget::kParentDirCmd);
    myUpButton->setToolTip("Go Up.", Event::UIPrevDir, EventMode::kMenuMode);
    boss->addFocusWidget(myUpButton);
    xpos = myUpButton->getRight() + BTN_GAP;

    myPath = new PathWidget(boss, this, _font, xpos, ypos, _w + _x - xpos, h);
  }
  else
  {
    myDir = new EditTextWidget(boss, _font, xpos, ypos, _w + _x - xpos, lineHeight, "");
    myDir->setEditable(false, true);
    myDir->clearFlags(Widget::FLAG_RETAIN_FOCUS);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::setList(FileListWidget* list)
{
  myList = list;

  // Let the FileListWidget handle the button commands
  if(!myUseMinimalUI)
  {
    myHomeButton->setTarget(myList);
    myPrevButton->setTarget(myList);
    myNextButton->setTarget(myList);
    myUpButton->setTarget(myList);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::setWidth(int w)
{
  // Adjust path display accordingly too
  if(myUseMinimalUI)
    myDir->setWidth(w - (myDir->getLeft() - _x));
  else
    myPath->setWidth(w - (myPath->getLeft() - _x));
  Widget::setWidth(w);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::setVisible(bool isVisible)
{
  if(isVisible)
  {
    this->clearFlags(FLAG_INVISIBLE);
    this->setEnabled(true);
    myHomeButton->clearFlags(FLAG_INVISIBLE);
    myHomeButton->setEnabled(true);
    myPrevButton->clearFlags(FLAG_INVISIBLE);
    myHomeButton->setEnabled(true);
    myNextButton->clearFlags(FLAG_INVISIBLE);
    myHomeButton->setEnabled(true);
    myUpButton->clearFlags(FLAG_INVISIBLE);
    myHomeButton->setEnabled(true);
    myPath->clearFlags(FLAG_INVISIBLE);
    myPath->setEnabled(true);
  }
  else
  {
    this->setFlags(FLAG_INVISIBLE);
    this->setEnabled(false);
    myHomeButton->setFlags(FLAG_INVISIBLE);
    myHomeButton->setEnabled(false);
    myPrevButton->setFlags(FLAG_INVISIBLE);
    myPrevButton->setEnabled(false);
    myNextButton->setFlags(FLAG_INVISIBLE);
    myNextButton->setEnabled(false);
    myUpButton->setFlags(FLAG_INVISIBLE);
    myUpButton->setEnabled(false);

    myPath->setFlags(FLAG_INVISIBLE);
    myPath->setEnabled(false);
    myPath->setPath("");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::updateUI()
{
  if(isVisible())
  {
    // Only enable the navigation buttons if function is available
    if(myUseMinimalUI)
    {
      myDir->setText(myList->currentDir().getShortPath());
    }
    else
    {
      myHomeButton->setEnabled(myList->hasPrevHistory());
      myPrevButton->setEnabled(myList->hasPrevHistory());
      myNextButton->setEnabled(myList->hasNextHistory());
      myUpButton->setEnabled(myList->currentDir().hasParent());
      myPath->setPath(myList->currentDir().getShortPath());
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::handleCommand(CommandSender* sender, int cmd, int data,
                                     int id)
{
  switch(cmd)  // NOLINT (could be written as IF/ELSE)
  {
    case kFolderClicked:
    {
      const FSNode node(myPath->getPath(id));
      myList->selectDirectory(node);
      break;
    }

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
NavigationWidget::PathWidget::PathWidget(GuiObject* boss, CommandReceiver* target,
    const GUI::Font& font, int xpos, int ypos, int w, int h)
  : Widget(boss, font, xpos, ypos, w, h),
    myTarget{target}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::PathWidget::setPath(string_view path)
{
  if(path == myLastPath)
    return;

  myLastPath = path;

  const int fontWidth = _font.getMaxCharWidth();
  int x = _x + fontWidth, w = _w;
  FSNode node(path);

  // Calculate how many path parts can be displayed
  StringList paths;
  bool cutFirst = false;
  while(node.hasParent() && w >= fontWidth * 1)
  {
    const string& name = node.getName();
    int l = static_cast<int>(name.length() + 2);

    if(name.back() == FSNode::PATH_SEPARATOR)
      l--;
    if(node.getParent().hasParent())
      l++;

    w -= l * fontWidth;
    paths.push_back(node.getPath());
    node = node.getParent();
  }
  if(w < 0 || node.hasParent())
    cutFirst = true;

  // Update/add widgets for path parts display
  size_t idx = 0;
  for(auto it = paths.rbegin(); it != paths.rend(); ++it, ++idx)
  {
    const string& curPath = *it;
    node = FSNode(curPath);
    string name = node.getName();

    if(it == paths.rbegin() && cutFirst)
      name = ">";
    else
    {
      if(name.back() == FSNode::PATH_SEPARATOR)
        name.pop_back();
      if(it + 1 != paths.rend())
        name += " >";
    }
    const int width = static_cast<int>(name.length() + 1) * fontWidth;

    if(myFolderList.size() > idx)
    {
      myFolderList[idx]->setPath(curPath);
      myFolderList[idx]->setPosX(x);
      myFolderList[idx]->setWidth(width);
      myFolderList[idx]->setLabel(name);
    }
    else
    {
      // Add new widget to list
      auto* s = new FolderLinkWidget(_boss, _font, x, _y,
                                     width, _h, name, curPath);
      s->setID(static_cast<uInt32>(idx));
      s->setTarget(myTarget);
      myFolderList.push_back(s);
      //_boss->addFocusWidget(s); // TODO: allow adding/inserting focus dynamically
    }
    x += width;
  }
  // Hide any remaining widgets
  while(idx < size(myFolderList))
  {
    myFolderList[idx]->setWidth(0);
    ++idx;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& NavigationWidget::PathWidget::getPath(int idx) const
{
  assert(size_t(idx) < myFolderList.size());
  return myFolderList[idx]->getPath();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
NavigationWidget::PathWidget::FolderLinkWidget::FolderLinkWidget(
    GuiObject* boss, const GUI::Font& font,
    int x, int y, int w, int h, string_view text, string_view path)
  : ButtonWidget(boss, font, x, y, w, h, text, kFolderClicked),
    myPath{path}
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG;

  _bgcolor = kDlgColor;
  _bgcolorhi = kBtnColorHi;
  _textcolor = kTextColor;
  _align = TextAlign::Center;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void NavigationWidget::PathWidget::FolderLinkWidget::drawWidget(bool hilite)
{
  FBSurface& s = _boss->dialog().surface();

  if(hilite)
    s.frameRect(_x, _y, _w, _h, kBtnBorderColorHi);
  s.drawString(_font, _label, _x + 1, _y + (_h - _font.getFontHeight()) / 2 , _w,
    hilite ? _textcolorhi : _textcolor, _align);
}
