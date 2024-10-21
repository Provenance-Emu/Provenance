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
//
//   Based on code from ScummVM - Scumm Interpreter
//   Copyright (C) 2002-2004 The ScummVM project
//============================================================================

#include "OSystem.hxx"
#include "EventHandler.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "OptionsMenu.hxx"
#include "Dialog.hxx"
#include "Widget.hxx"
#include "TabWidget.hxx"
#include "ToolTip.hxx"

#include "Settings.hxx"
#include "Console.hxx"

#include "Vec.hxx"
#include "MediaFactory.hxx"

/*
 * TODO list
 * - add some sense of the window being "active" (i.e. in front) or not. If it
 *   was inactive and just became active, reset certain vars (like who is focused).
 *   Maybe we should just add lostFocus and receivedFocus methods to Dialog, just
 *   like we have for class Widget?
 * ...
 */
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog::Dialog(OSystem& instance, DialogContainer& parent, const GUI::Font& font,
               string_view title, int x, int y, int w, int h)
  : GuiObject(instance, parent, *this, x, y, w, h),
    _font{font},
    _title{title},
    _renderCallback{[]() { return; }}
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_BORDER | Widget::FLAG_CLEARBG;
  setTitle(title);

  _toolTip = make_unique<ToolTip>(*this, font);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog::Dialog(OSystem& instance, DialogContainer& parent,
               int x, int y, int w, int h)
  : Dialog(instance, parent, instance.frameBuffer().font(), "", x, y, w, h)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog::~Dialog()
{
  if(instance().hasFrameBuffer())
  {
    instance().frameBuffer().deallocateSurface(_surface);
    instance().frameBuffer().deallocateSurface(_shadeSurface);
  }
  else
    cerr << "!!! framebuffer not available\n";

  clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::clear()
{
  _myFocus.list.clear();
  _myTabList.clear();

  delete _firstWidget;
  _firstWidget = nullptr;

  _buttonGroup.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::open()
{
  // Make sure we have a valid surface to draw into
  // Technically, this shouldn't be needed until drawDialog(), but some
  // dialogs cause drawing to occur within loadConfig()
  if (_surface == nullptr)
    _surface = instance().frameBuffer().allocateSurface(_w, _h);
  else if (static_cast<uInt32>(_w) > _surface->width() || static_cast<uInt32>(_h) > _surface->height())
    _surface->resize(_w, _h);
  _surface->setSrcSize(_w, _h);
  _layer = parent().addDialog(this);

  // Take hidpi scaling into account
  const uInt32 scale = instance().frameBuffer().hidpiScaleFactor();
  _surface->setDstSize(_w * scale, _h * scale);

  setPosition();

  if(!_myTabList.empty())
    // (Re)-build the focus list to use for all widgets of all tabs
    for(auto& tabfocus : _myTabList)
      buildCurrentFocusList(tabfocus.widget->getID());
  else
    buildCurrentFocusList();

  /*if (!_surface->attributes().blending)
  {
    _surface->attributes().blending = true;
    _surface->attributes().blendalpha = 90;
    _surface->applyAttributes();
  }*/

  loadConfig(); // has to be done AFTER (re)building the focus list

  _visible = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::close()
{
  if(_mouseWidget)
  {
    _mouseWidget->handleMouseLeft();
    _mouseWidget = nullptr;
  }

  releaseFocus();

  _visible = false;

  parent().removeDialog();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setTitle(string_view title)
{
  _title = title;
  _h -= _th;
  if(title.empty())
    _th = 0;
  else
    _th = _font.getLineHeight() * 1.25;
  _h += _th;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::initHelp()
{
#ifndef RETRON77
  if(hasTitle())
  {
    if(_helpWidget == nullptr)
    {
      const string key = instance().eventHandler().getMappingDesc(
        Event::UIHelp, EventMode::kMenuMode);

      _helpWidget = new ButtonWidget(this, _font,
          _w - _font.getMaxCharWidth() * 3.5, 0,
          _font.getMaxCharWidth() * 3.5 + 0.5, buttonHeight(), "?",  // NOLINT
          kHelpCmd);
      _helpWidget->setBGColor(kColorTitleBar);
      _helpWidget->setTextColor(kColorTitleText);
      _helpWidget->setToolTip("Click or press " + key + " for help.");
    }

    if(hasHelp() && MediaFactory::supportsURL())
      _helpWidget->clearFlags(Widget::FLAG_INVISIBLE);
    else
      _helpWidget->setFlags(Widget::FLAG_INVISIBLE);
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setHelpAnchor(string_view helpAnchor, bool debugger)
{
  _helpAnchor = helpAnchor;
  _debuggerHelp = debugger;

  initHelp();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setHelpURL(string_view helpURL)
{
  _helpURL = helpURL;

  initHelp();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Dialog::getHelpURL() const
{
  // 1. check individual widget
  if(_focusedWidget && _focusedWidget->hasHelp())
    return _focusedWidget->getHelpURL();

  if(_tabID < static_cast<int>(_myTabList.size()))
  {
    TabWidget* activeTabGroup = _myTabList[_tabID].widget;

    // 2. check active tab
    const int activeTab = activeTabGroup->getActiveTab();
    const Widget* parentTab = activeTabGroup->parentWidget(activeTab);

    if(parentTab->hasHelp())
      return parentTab->getHelpURL();

    // 3. check active tab group
    if(activeTabGroup && activeTabGroup->hasHelp())
      return activeTabGroup->getHelpURL();
  }

  // 4. check dialog
  if(!_helpURL.empty())
    return _helpURL;

  if(!_helpAnchor.empty())
  {
    if(_debuggerHelp)
      return "https://stella-emu.github.io/docs/debugger.html#" + _helpAnchor;
    else
      return "https://stella-emu.github.io/docs/index.html#" + _helpAnchor;
  }
  // no help found
  return EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::openHelp()
{
  if(hasHelp() && !MediaFactory::openURL(getHelpURL()))
    cerr << "error opening URL " << getHelpURL() << '\n';
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setPosition()
{
  positionAt(instance().settings().getInt("dialogpos"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setDirty()
{
  _dirty = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setDirtyChain()
{
  _dirtyChain = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::tick()
{
  // Recursively tick dialog and all child dialogs and widgets
  Widget* w = _firstWidget;

  while(w)
  {
    w->tick();
    w = w->_next;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::positionAt(uInt32 pos)
{
  const bool fullscreen = instance().settings().getBool("fullscreen");
  const double overscan = fullscreen ? instance().settings().getInt("tia.fs_overscan") / 200.0 : 0.0;
  const Common::Size& screen = instance().frameBuffer().screenSize();
  const Common::Rect& dst = _surface->dstRect();
  // shift stacked dialogs
  const Int32 hgap = (screen.w >> 6) * _layer + screen.w * overscan;
  const Int32 vgap = (screen.w >> 6) * _layer + screen.h * overscan;
  const int top = std::min(std::max(0, static_cast<Int32>(screen.h - dst.h())), vgap);
  const int btm = std::max(0, static_cast<Int32>(screen.h - dst.h() - vgap));
  const int left = std::min(std::max(0, static_cast<Int32>(screen.w - dst.w())), hgap);
  const int right = std::max(0, static_cast<Int32>(screen.w - dst.w() - hgap));

  switch (pos)
  {
    case 1:
      _surface->setDstPos(left, top);
      break;

    case 2:
      _surface->setDstPos(right, top);
      break;

    case 3:
      _surface->setDstPos(right, btm);
      break;

    case 4:
      _surface->setDstPos(left, btm);
      break;

    default:
      // center
      _surface->setDstPos((screen.w - dst.w()) >> 1, (screen.h - dst.h()) >> 1);
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::redraw(bool force)
{
  if(!isVisible())
    return;

  if(force)
    setDirty();

  // Draw this dialog
  setPosition();
  drawDialog();
  // full rendering is caused in dialog container
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::render()
{
#ifdef DEBUG_BUILD
  //cerr << "  render " << typeid(*this).name() << '\n';
#endif

  // Update dialog surface; also render any extra surfaces
  // Extra surfaces must be rendered afterwards, so they are drawn on top
  if(_surface->render())
    _renderCallback();

  // A dialog is still on top if a non-shading dialog (e.g. ContextMenu)
  // is opened above it.
  const bool onTop = parent().myDialogStack.top() == this
    || (parent().myDialogStack.get(parent().myDialogStack.size() - 2) == this
        && !parent().myDialogStack.top()->isShading());

  if(!onTop)
  {
    if(_shadeSurface == nullptr)
    {
      // Create shading surface
      constexpr uInt32 data = 0xff000000;

      _shadeSurface = instance().frameBuffer().allocateSurface(
        1, 1, ScalingInterpolation::sharp, &data);

      FBSurface::Attributes& attr = _shadeSurface->attributes();

      attr.blending = true;
      attr.blendalpha = 25; // darken background dialogs by 25%
      _shadeSurface->applyAttributes();
    }
    _shadeSurface->setDstRect(_surface->dstRect());
    _shadeSurface->render();
  }

  _toolTip->render();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::releaseFocus()
{
  if(_focusedWidget)
  {
    // remember focus of all tabs for when dialog is reopened again
    for(auto& tabfocus : _myTabList)
      tabfocus.saveCurrentFocus(_focusedWidget);

    //_focusedWidget->lostFocus();
    //_focusedWidget = nullptr;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addFocusWidget(Widget* w)
{
  if(!w)
    return;

  // All focusable widgets should retain focus
  w->setFlags(Widget::FLAG_RETAIN_FOCUS);

  _myFocus.widget = w;
  _myFocus.list.push_back(w);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Dialog::addToFocusList(const WidgetArray& list)
{
  // All focusable widgets should retain focus
  for(const auto& w: list)
    w->setFlags(Widget::FLAG_RETAIN_FOCUS);

  Vec::append(_myFocus.list, list);
  _focusList = _myFocus.list;

  if(!list.empty())
    _myFocus.widget = list[0];

  return static_cast<int>(_focusList.size());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Dialog::addToFocusList(const WidgetArray& list, const TabWidget* w, int tabId)
{
  // Only add the list if the tab actually exists
  if(!w || w->getID() >= _myTabList.size())
    return 0;

  assert(w == _myTabList[w->getID()].widget);

  // All focusable widgets should retain focus
  for(const auto& fw: list)
    fw->setFlags(Widget::FLAG_RETAIN_FOCUS);

  // First get the appropriate focus list
  FocusList& focus = _myTabList[w->getID()].focus;

  // Now insert in the correct place in that focus list
  const uInt32 id = tabId;
  if(id < focus.size())
    Vec::append(focus[id].list, list);
  else
  {
    // Make sure the array is large enough
    while(focus.size() <= id)
      focus.emplace_back();

    Vec::append(focus[id].list, list);
  }

  if(!list.empty())
    focus[id].widget = list[0];

  return static_cast<int>(focus.size());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addTabWidget(TabWidget* w)
{
  if(!w)
    return;

  // Make sure the array is large enough
  const uInt32 id = w->getID();
  while(_myTabList.size() < id)
    _myTabList.emplace_back();

  _myTabList.emplace_back(w);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setFocus(const Widget* w)
{
  // If the click occured inside a widget which is not the currently
  // focused one, change the focus to that widget.
  if(w && w != _focusedWidget && w->wantsFocus() && w->isEnabled())
  {
    // Redraw widgets for new focus
    _focusedWidget = Widget::setFocusForChain(this, getFocusList(), w, 0);

    // Update current tab based on new focused widget
    getTabIdForWidget(_focusedWidget);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::buildCurrentFocusList(int tabID)
{
  // Yes, this is hideously complex.  That's the price we pay for
  // tab navigation ...
  _focusList.clear();

  // Remember which tab item previously had focus, if applicable
  // This only applies if this method was called for a tab change
  Widget* tabFocusWidget = nullptr;
  if(tabID >= 0 && tabID < static_cast<int>(_myTabList.size()))
  {
    // Save focus in previously selected tab column,
    // and get focus for new tab column
    TabFocus& tabfocus = _myTabList[tabID];
    tabfocus.saveCurrentFocus(_focusedWidget);
    tabFocusWidget = tabfocus.getNewFocus();

    _tabID = tabID;
  }

  // Add appropriate items from tablist (if present)
  for(auto& tabfocus: _myTabList)
    tabfocus.appendFocusList(_focusList);

  // Add remaining items from main focus list
  Vec::append(_focusList, _myFocus.list);

  // Add button group at end of current focus list
  // We do it this way for TabWidget, so that buttons are scanned
  // *after* the widgets in the current tab
  if(!_buttonGroup.empty())
    Vec::append(_focusList, _buttonGroup);

  // Finally, the moment we've all been waiting for :)
  // Set the actual focus widget
  if(tabFocusWidget)
    _focusedWidget = tabFocusWidget;
  else if(!_focusedWidget && !_focusList.empty())
    _focusedWidget = _focusList[0];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addRenderCallback(const RenderCallback& callback)
{
  _renderCallback = callback;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::drawDialog()
{
  if(!isVisible())
    return;

  FBSurface& s = surface();

  if(isDirty())
  {
  #ifdef DEBUG_BUILD
    //cerr << "*** draw dialog " << typeid(*this).name() << " ***\n";
    cerr << "\nd";
  #endif

    if(clearsBackground())
    {
      //    cerr << "Dialog::drawDialog(): w = " << _w << ", h = " << _h << " @ " << &s << "\n\n";

      if(hasBackground())
        s.fillRect(_x, _y + _th, _w, _h - _th, kDlgColor);
      else
        s.invalidateRect(_x, _y + _th, _w, _h - _th);
      if(_th)
      {
        s.fillRect(_x, _y, _w, _th, kColorTitleBar);
        s.drawString(_font, _title, _x + hBorder(), _y + _font.getFontHeight() / 6,
                     _font.getStringWidth(_title), kColorTitleText);
      }
    }
    else {
      s.invalidate();
    #ifdef DEBUG_BUILD
      //cerr << "invalidate " << typeid(*this).name() << '\n';
    #endif
    }
    if(hasBorder()) // currently only used by Dialog itself
      s.frameRect(_x, _y, _w, _h, kColor);

    // Make all child widgets dirty
    Widget::setDirtyInChain(_firstWidget);

    clearDirty();
  }
#ifdef DEBUG_BUILD
  else
    cerr << '\n';
#endif

  // Draw all children
  drawChain();

  // Draw outlines for focused widgets
  // Don't change focus, since this will trigger lost and received
  // focus events
  if(_focusedWidget)
  {
    _focusedWidget = Widget::setFocusForChain(this, getFocusList(),
                                              _focusedWidget, 0, false);
    //if(_focusedWidget)
    //  _focusedWidget->draw(); // make sure the highlight color is drawn initially
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::drawChain()
{
  // Clear chain *before* drawing, because some widgets may set it again when
  //   being drawn (e.g. RomListWidget)
  clearDirtyChain();

  Widget* w = _firstWidget;

  while(w)
  {
    if(w->needsRedraw())
      w->draw();
    w = w->_next;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleText(char text)
{
  // Focused widget receives text events
  if(_focusedWidget)
    _focusedWidget->handleText(text);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  Event::Type e = Event::NoType;

  tooltip().hide();

// FIXME - I don't think this will compile!
#if defined(RETRON77)
  // special keys used for R77
  if (key == KBDK_F13)
    e = Event::UITabPrev;
  else if (key == KBDK_BACKSPACE)
    e = Event::UITabNext;
#endif

  // Check the keytable now, since we might get one of the above events,
  // which must always be processed before any widget sees it.
  if(e == Event::NoType)
    e = instance().eventHandler().eventForKey(EventMode::kMenuMode, key, mod);

  // Widget events are handled *before* the dialog events
  bool handled = false;

  if(_focusedWidget)
  {
    // Unless a widget has claimed all responsibility for data, we assume
    // that if an event exists for the given data, it should have priority.
    if(_focusedWidget->wantsRaw() || e == Event::NoType)
      handled = _focusedWidget->handleKeyDown(key, mod);
    else
      handled = _focusedWidget->handleEvent(e);
  }
  if(!handled)
    handleNavEvent(e, repeated);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleKeyUp(StellaKey key, StellaMod mod)
{
  // Focused widget receives keyup events
  if(_focusedWidget)
    _focusedWidget->handleKeyUp(key, mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  Widget* w = findWidget(x, y);

  _dragWidget = w;
  setFocus(w);

  if(w)
    w->handleMouseDown(x - (w->getAbsX() - _x), y - (w->getAbsY() - _y),
                       b, clickCount);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  if(_focusedWidget)
  {
    // Lose focus on mouseup unless the widget requested to retain the focus
    if(! (_focusedWidget->getFlags() & Widget::FLAG_RETAIN_FOCUS ))
      releaseFocus();
  }

  Widget* w = _dragWidget;
  if(w)
    w->handleMouseUp(x - (w->getAbsX() - _x), y - (w->getAbsY() - _y),
                     b, clickCount);

  _dragWidget = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleMouseWheel(int x, int y, int direction)
{
  // This may look a bit backwards, but I think it makes more sense for
  // the mouse wheel to primarily affect the widget the mouse is at than
  // the widget that happens to be focused.

  Widget* w = findWidget(x, y);
  if(!w)
    w = _focusedWidget;
  if(w)
    w->handleMouseWheel(x - (w->getAbsX() - _x), y - (w->getAbsY() - _y), direction);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleMouseMoved(int x, int y)
{
  Widget* w = nullptr;

  if(_focusedWidget && !_dragWidget)
  {
    w = _focusedWidget;
    const int wx = w->getAbsX() - _x;
    const int wy = w->getAbsY() - _y;

    // We still send mouseEntered/Left messages to the focused item
    // (but to no other items).
    const bool mouseInFocusedWidget = (x >= wx && x < wx + w->_w && y >= wy && y < wy + w->_h);
    if(mouseInFocusedWidget && _mouseWidget != w)
    {
      if(_mouseWidget)
        _mouseWidget->handleMouseLeft();
      _mouseWidget = w;
      w->handleMouseEntered();
    }
    else if (!mouseInFocusedWidget && _mouseWidget == w)
    {
      _mouseWidget = nullptr;
      w->handleMouseLeft();
    }

    w->handleMouseMoved(x - wx, y - wy);
  }

  // While a "drag" is in process (i.e. mouse is moved while a button is pressed),
  // only deal with the widget in which the click originated.
  if (_dragWidget)
    w = _dragWidget;
  else
    w = findWidget(x, y);

  if (_mouseWidget != w)
  {
    if (_mouseWidget)
      _mouseWidget->handleMouseLeft();
    if (w)
      w->handleMouseEntered();
    _mouseWidget = w;
  }

  if (w && (w->getFlags() & Widget::FLAG_TRACK_MOUSE))
    w->handleMouseMoved(x - (w->getAbsX() - _x), y - (w->getAbsY() - _y));

#ifndef RETRON77
  // Update mouse coordinates for tooltips
  _toolTip->update(_mouseWidget, Common::Point(x, y));
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Dialog::handleMouseClicks(int x, int y, MouseButton b)
{
  Widget* w = findWidget(x, y);

  if(w)
    return w->handleMouseClicks(x - (w->getAbsX() - _x),
                                y - (w->getAbsY() - _y), b);
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleJoyDown(int stick, int button, bool longPress)
{
  // Focused widget receives joystick events
  if(_focusedWidget)
  {
    const Event::Type e =
      instance().eventHandler().eventForJoyButton(EventMode::kMenuMode, stick, button);

    if(_focusedWidget->wantsRaw() || e == Event::NoType)
      _focusedWidget->handleJoyDown(stick, button, longPress);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleJoyUp(int stick, int button)
{
  const Event::Type e =
    instance().eventHandler().eventForJoyButton(EventMode::kMenuMode, stick, button);

  // Unless a widget has claimed all responsibility for data, we assume
  // that if an event exists for the given data, it should have priority.
  if (!handleNavEvent(e) && _focusedWidget)
  {
    if (_focusedWidget->wantsRaw() || e == Event::NoType)
      _focusedWidget->handleJoyUp(stick, button);
    else
      _focusedWidget->handleEvent(e);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Event::Type Dialog::getJoyAxisEvent(int stick, JoyAxis axis, JoyDir adir, int button)
{
  return instance().eventHandler().eventForJoyAxis(EventMode::kMenuMode, stick, axis, adir, button);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button)
{
  const Event::Type e = getJoyAxisEvent(stick, axis, adir, button);

  // Unless a widget has claimed all responsibility for data, we assume
  // that if an event exists for the given data, it should have priority.
  if(!handleNavEvent(e) && _focusedWidget)
  {
    if(_focusedWidget->wantsRaw() || e == Event::NoType)
      _focusedWidget->handleJoyAxis(stick, axis, adir, button);
    else if(adir != JoyDir::NONE)
      _focusedWidget->handleEvent(e);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Dialog::handleJoyHat(int stick, int hat, JoyHatDir hdir, int button)
{
  const Event::Type e =
    instance().eventHandler().eventForJoyHat(EventMode::kMenuMode, stick, hat, hdir, button);

  // Unless a widget has claimed all responsibility for data, we assume
  // that if an event exists for the given data, it should have priority.
  if(!handleNavEvent(e) && _focusedWidget)
  {
    if(_focusedWidget->wantsRaw() || e == Event::NoType)
      return _focusedWidget->handleJoyHat(stick, hat, hdir, button);
    else
      return _focusedWidget->handleEvent(e);
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Dialog::handleNavEvent(Event::Type e, bool repeated)
{
  switch(e)
  {
    case Event::UITabPrev:
      if (cycleTab(-1))
        return true;
      break;

    case Event::UITabNext:
      if (cycleTab(1))
        return true;
      break;

    case Event::UINavPrev:
      if(_focusedWidget && !_focusedWidget->wantsTab())
      {
        _focusedWidget = Widget::setFocusForChain(this, getFocusList(),
                                                  _focusedWidget, -1);
        // Update current tab based on new focused widget
        getTabIdForWidget(_focusedWidget);

        return true;
      }
      break;

    case Event::UINavNext:
      if(_focusedWidget && !_focusedWidget->wantsTab())
      {
        _focusedWidget = Widget::setFocusForChain(this, getFocusList(),
                                                  _focusedWidget, +1);
        // Update current tab based on new focused widget
        getTabIdForWidget(_focusedWidget);

        return true;
      }
      break;

    case Event::UIOK:
      if(_okWidget && _okWidget->isEnabled() && !repeated)
      {
        // Receiving 'OK' is the same as getting the 'Select' event
        _okWidget->handleEvent(Event::UISelect);
        return true;
      }
      break;

    case Event::UICancel:
      if(_cancelWidget && _cancelWidget->isEnabled() && !repeated)
      {
        // Receiving 'Cancel' is the same as getting the 'Select' event
        _cancelWidget->handleEvent(Event::UISelect);
        return true;
      }
      else if(_processCancel)
      {
        // Some dialogs want the ability to cancel without actually having
        // a corresponding cancel button
        processCancel();
        return true;
      }
      break;
    case Event::UIHelp:
      openHelp();
      return true;

    default:
      return false;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::getTabIdForWidget(const Widget* w)
{
  if(_myTabList.empty() || !w)
    return;

  for(uInt32 id = 0; id < _myTabList.size(); ++id)
  {
    if(w->_boss == _myTabList[id].widget)
    {
      _tabID = id;
      return;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Dialog::cycleTab(int direction)
{
  if(_tabID >= 0 && _tabID < static_cast<int>(_myTabList.size()))
  {
    _myTabList[_tabID].widget->cycleTab(direction);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch(cmd)
  {
    case TabWidget::kTabChangedCmd:
      if(_visible)
        buildCurrentFocusList(id);
      break;

    case GuiObject::kCloseCmd:
      close();
      break;

    case kHelpCmd:
      openHelp();
      break;

    default:
      break;
  }
}

/*
 * Determine the widget at location (x,y) if any. Assumes the coordinates are
 * in the local coordinate system, i.e. relative to the top left of the dialog.
 */
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Widget* Dialog::findWidget(int x, int y) const
{
  return Widget::findWidgetInChain(_firstWidget, x, y);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addOKBGroup(WidgetArray& wid, const GUI::Font& font,
                         string_view okText, int buttonWidth)
{
  const int buttonHeight = Dialog::buttonHeight(),
            BUTTON_GAP   = Dialog::buttonGap(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();

  buttonWidth = std::max(buttonWidth,
                         std::max(Dialog::buttonWidth(okText),
                         Dialog::buttonWidth("Cancel")));
  _w = std::max(HBORDER * 2 + buttonWidth * 2 + BUTTON_GAP, _w);

  addOKWidget(new ButtonWidget(this, font, (_w - buttonWidth) / 2,
              _h - buttonHeight - VBORDER, buttonWidth, buttonHeight, okText, GuiObject::kCloseCmd));
  wid.push_back(_okWidget);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addOKCancelBGroup(WidgetArray& wid, const GUI::Font& font,
                               string_view okText, string_view cancelText,
                               bool focusOKButton, int buttonWidth)
{
  const int buttonHeight = Dialog::buttonHeight(),
            BUTTON_GAP   = Dialog::buttonGap(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();

  buttonWidth = std::max(buttonWidth,
                         std::max(Dialog::buttonWidth("Defaults"),
                         std::max(Dialog::buttonWidth(okText),
                         Dialog::buttonWidth(cancelText))));

  _w = std::max(HBORDER * 2 + buttonWidth * 2 + BUTTON_GAP, _w);

#ifndef BSPF_MACOS
  addOKWidget(new ButtonWidget(this, font, _w - 2 * buttonWidth - HBORDER - BUTTON_GAP,
      _h - buttonHeight - VBORDER, buttonWidth, buttonHeight, okText, GuiObject::kOKCmd));
  addCancelWidget(new ButtonWidget(this, font, _w - (buttonWidth + HBORDER),
      _h - buttonHeight - VBORDER, buttonWidth, buttonHeight, cancelText, GuiObject::kCloseCmd));
#else
  addCancelWidget(new ButtonWidget(this, font, _w - 2 * buttonWidth - HBORDER - BUTTON_GAP,
      _h - buttonHeight - VBORDER, buttonWidth, buttonHeight, cancelText, GuiObject::kCloseCmd));
  addOKWidget(new ButtonWidget(this, font, _w - (buttonWidth + HBORDER),
      _h - buttonHeight - VBORDER, buttonWidth, buttonHeight, okText, GuiObject::kOKCmd));
#endif

  // Note that 'focusOKButton' only takes effect when there are no other UI
  // elements in the dialog; otherwise, the first widget of the dialog is always
  // automatically focused first
  // Changing this behaviour would require a fairly major refactoring of the UI code
  if(focusOKButton)
  {
    wid.push_back(_okWidget);
    wid.push_back(_cancelWidget);
  }
  else
  {
    wid.push_back(_cancelWidget);
    wid.push_back(_okWidget);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addDefaultsOKCancelBGroup(WidgetArray& wid, const GUI::Font& font,
                                       string_view okText, string_view cancelText,
                                       string_view defaultsText,
                                       bool focusOKButton)
{
  const int buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth(defaultsText),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();

  addDefaultWidget(new ButtonWidget(this, font, HBORDER, _h - buttonHeight - VBORDER,
                   buttonWidth, buttonHeight, defaultsText, GuiObject::kDefaultsCmd));
  wid.push_back(_defaultWidget);

  addOKCancelBGroup(wid, font, okText, cancelText, focusOKButton, buttonWidth);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::addDefaultsExtraOKCancelBGroup(
      WidgetArray& wid, const GUI::Font& font,
      string_view extraText, int extraCmd,
      string_view okText, string_view cancelText, string_view defaultsText,
      bool focusOKButton)
{
  const int buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = std::max(Dialog::buttonWidth(defaultsText),
                                    Dialog::buttonWidth(extraText)),
            BUTTON_GAP   = Dialog::buttonGap(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder();

  addDefaultWidget(new ButtonWidget(this, font, HBORDER, _h - buttonHeight - VBORDER,
                   buttonWidth, buttonHeight, defaultsText, GuiObject::kDefaultsCmd));
  wid.push_back(_defaultWidget);

  addExtraWidget(new ButtonWidget(this, font, HBORDER + buttonWidth + BUTTON_GAP,
                 _h - buttonHeight - VBORDER,
                 buttonWidth, buttonHeight, extraText, extraCmd));
  wid.push_back(_extraWidget);

  addOKCancelBGroup(wid, font, okText, cancelText, focusOKButton, buttonWidth);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::TabFocus::appendFocusList(WidgetArray& list)
{
  const int active = widget->getActiveTab();

  if(active >= 0 && active < static_cast<int>(focus.size()))
    Vec::append(list, focus[active].list);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::TabFocus::saveCurrentFocus(Widget* w)
{
  if(currentTab < focus.size() &&
      Widget::isWidgetInChain(focus[currentTab].list, w))
    focus[currentTab].widget = w;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Widget* Dialog::TabFocus::getNewFocus()
{
  currentTab = widget->getActiveTab();

  return (currentTab < focus.size()) ? focus[currentTab].widget : nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Dialog::getDynamicBounds(uInt32& w, uInt32& h) const
{
  const Common::Rect& r = instance().frameBuffer().imageRect();
  const uInt32 scale = instance().frameBuffer().hidpiScaleFactor();

  if(r.w() <= FBMinimum::Width || r.h() <= FBMinimum::Height)
  {
    w = r.w() / scale;
    h = r.h() / scale;
    return false;
  }
  else
  {
    w = static_cast<uInt32>(0.95 * r.w() / scale);
    h = static_cast<uInt32>(0.95 * r.h() / scale);
    return true;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Dialog::setSize(uInt32 w, uInt32 h, uInt32 max_w, uInt32 max_h)
{
  _w = std::min(w, max_w);
  _max_w = w;
  _h = std::min(h, max_h);
  _max_h = h;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Dialog::shouldResize(uInt32& w, uInt32& h) const
{
  getDynamicBounds(w, h);

  // returns true if the current size is larger than the allowed size or
  //  if the current size is smaller than the allowed and wanted size
  return (static_cast<uInt32>(_w) > w || static_cast<uInt32>(_h) > h ||
         (static_cast<uInt32>(_w) < w && static_cast<uInt32>(_w) < _max_w) ||
         (static_cast<uInt32>(_h) < h && static_cast<uInt32>(_h) < _max_h));
}
