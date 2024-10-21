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

#include "bspf.hxx"
#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "GuiObject.hxx"
#include "Widget.hxx"
#include "TabWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TabWidget::TabWidget(GuiObject* boss, const GUI::Font& font,
                     int x, int y, int w, int h)
  : Widget(boss, font, x, y, w, h),
    CommandSender(boss)
{
  _id = 0;  // For dialogs with multiple tab widgets, they should specifically
            // call ::setID to differentiate among them
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG;
  _bgcolor = kDlgColor;
  _bgcolorhi = kDlgColor;
  _textcolor = kTextColor;
  _textcolorhi = kTextColor;

  _tabHeight = font.getLineHeight() + 4;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TabWidget::~TabWidget()
{
  for(auto& tab: _tabs)
  {
    delete tab.firstWidget;
    tab.firstWidget = nullptr;
    // _tabs[i].parentWidget is deleted elsewhere
  }
  _tabs.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TabWidget::getChildY() const
{
  return getAbsY() + _tabHeight;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int TabWidget::addTab(string_view title, int tabWidth)
{
  // Add a new tab page
  const int newWidth = _font.getStringWidth(title) + 2 * kTabPadding;

  if(tabWidth == AUTO_WIDTH)
    _tabs.emplace_back(title, newWidth);
  else
    _tabs.emplace_back(title, tabWidth);
  const int numTabs = static_cast<int>(_tabs.size());

  // Determine the new tab width
  int fixedWidth = 0, fixedTabs = 0;
  for(const auto& tab: _tabs)
  {
    if(tab.tabWidth != NO_WIDTH)
    {
      fixedWidth += tab.tabWidth;
      fixedTabs++;
    }
  }

  if(tabWidth == NO_WIDTH)
    if(_tabWidth < newWidth)
      _tabWidth = newWidth;

  if(numTabs - fixedTabs)
  {
    const int maxWidth = (_w - kTabLeftOffset - fixedWidth) / (numTabs - fixedTabs) - kTabLeftOffset;
    if(_tabWidth > maxWidth)
      _tabWidth = maxWidth;
  }

  // Activate the new tab
  setActiveTab(numTabs - 1);

  return _activeTab;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::setActiveTab(int tabID, bool show)
{
  assert(0 <= tabID && tabID < int(_tabs.size()));

  if (_activeTab != -1)
  {
    // Exchange the widget lists, and switch to the new tab
    _tabs[_activeTab].firstWidget = _firstWidget;
  }

  if(_activeTab != tabID)
    setDirty();

  _activeTab = tabID;
  _firstWidget  = _tabs[tabID].firstWidget;

  // Let parent know about the tab change
  if(show)
    sendCommand(TabWidget::kTabChangedCmd, _activeTab, _id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::enableTab(int tabID, bool enable)
{
  assert(0 <= tabID && tabID < int(_tabs.size()));

  _tabs[tabID].enabled = enable;
  // Note: We do not have to disable the widgets because the tab is disabled
  //   and therefore cannot be selected.
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::updateActiveTab()
{
  if(_activeTab < 0)
    return;

  if(_tabs[_activeTab].parentWidget)
    _tabs[_activeTab].parentWidget->loadConfig();

  // Redraw focused areas
  _boss->redrawFocus(); // TJ: Does nothing!
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::activateTabs()
{
  for(uInt32 i = 0; i <_tabs.size(); ++i)
    sendCommand(TabWidget::kTabChangedCmd, i-1, _id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::cycleTab(int direction)
{
  int tabID = _activeTab;

  // Don't do anything if no tabs have been defined
  if(tabID == -1)
    return;

  if(direction == -1)  // Go to the previous tab, wrap around at beginning
  {
    do {
      tabID--;
      if(tabID == -1)
        tabID = static_cast<int>(_tabs.size()) - 1;
    } while(!_tabs[tabID].enabled);
  }
  else if(direction == 1)  // Go to the next tab, wrap around at end
  {
    do {
      tabID++;
      if(tabID == static_cast<int>(_tabs.size()))
        tabID = 0;
    } while(!_tabs[tabID].enabled);
  }

  // Finally, select the active tab
  setActiveTab(tabID, true);
  updateActiveTab();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::setParentWidget(int tabID, Widget* parent)
{
  assert(0 <= tabID && tabID < static_cast<int>(_tabs.size()));
  _tabs[tabID].parentWidget = parent;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Widget* TabWidget::parentWidget(int tabID)
{
  assert(0 <= tabID && tabID < int(_tabs.size()));

  if(!_tabs[tabID].parentWidget)
  {
    // Create dummy widget if not existing
    auto* w = new Widget(_boss, _font, 0, 0, 0, 0);

    setParentWidget(tabID, w);
  }
  return _tabs[tabID].parentWidget;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  assert(y < _tabHeight);

  // Determine which tab was clicked
  int tabID = -1;
  x -= kTabLeftOffset;

  for(int i = 0; i < static_cast<int>(_tabs.size()); ++i)
  {
    const int tabWidth = _tabs[i].tabWidth ? _tabs[i].tabWidth : _tabWidth;
    if(x >= 0 && x < tabWidth)
    {
      tabID = i;
      break;
    }
    x -= (tabWidth + kTabSpacing);
  }

  // If a tab was clicked, switch to that pane
  if (tabID >= 0 && _tabs[tabID].enabled)
  {
    setActiveTab(tabID, true);
    updateActiveTab();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  // Command is not inspected; simply forward it to the caller
  sendCommand(cmd, data, _id);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TabWidget::handleEvent(Event::Type event)
{
  bool handled = false;

  switch (event)
  {
    case Event::UIRight:
    case Event::UIPgDown:
      cycleTab(1);
      handled = true;
      break;
    case Event::UILeft:
    case Event::UIPgUp:
      cycleTab(-1);
      handled = true;
      break;
    default:
      break;
  }
  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::loadConfig()
{
  if(_firstTime)
  {
    setActiveTab(_activeTab, true);
    _firstTime = false;
  }

  updateActiveTab();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TabWidget::drawWidget(bool hilite)
{
  // The tab widget is strange in that it acts as both a widget (obviously)
  // and a dialog (it contains other widgets).  Because of the latter,
  // it must assume responsibility for refreshing all its children.

  if(isDirty())
  {
    FBSurface& s = dialog().surface();

    // Iterate over all tabs and draw them
    int x = _x + kTabLeftOffset;
    for(int i = 0; i < static_cast<int>(_tabs.size()); ++i)
    {
      const int tabWidth = _tabs[i].tabWidth ? _tabs[i].tabWidth : _tabWidth;
      const ColorId fontcolor = _tabs[i].enabled ? kTextColor : kColor;
      const int yOffset = (i == _activeTab) ? 0 : 1;
      s.fillRect(x, _y + 1, tabWidth, _tabHeight - 1,
                 (i == _activeTab)
                 ? kDlgColor : kBGColorHi); // ? kWidColor : kDlgColor
      s.drawString(_font, _tabs[i].title, x + kTabPadding + yOffset,
                   _y + yOffset + (_tabHeight - _lineHeight - 1),
                   tabWidth - 2 * kTabPadding, fontcolor, TextAlign::Center);
      if(i == _activeTab)
      {
        s.hLine(x, _y, x + tabWidth - 1, kWidColor);
        s.vLine(x + tabWidth, _y + 1, _y + _tabHeight - 1, kBGColorLo);
      }
      else
        s.hLine(x, _y + _tabHeight, x + tabWidth, kWidColor);

      x += tabWidth + kTabSpacing;
    }

    // fill empty right space
    s.hLine(x - kTabSpacing + 1, _y + _tabHeight, _x + _w - 1, kWidColor);
    s.hLine(_x, _y + _h - 1, _x + _w - 1, kBGColorLo);

    clearDirty();
    // Make all child widgets of currently active tab dirty
    Widget::setDirtyInChain(_tabs[_activeTab].firstWidget);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Widget* TabWidget::findWidget(int x, int y)
{
  if (y < _tabHeight)
  {
    // Click was in the tab area
    return this;
  }
  else
  {
    // Iterate over all child widgets and find the one which was clicked
    return Widget::findWidgetInChain(_firstWidget, x, y - _tabHeight);
  }
}
