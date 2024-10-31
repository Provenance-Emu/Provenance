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

#include <cmath>

#include "OSystem.hxx"
#include "Console.hxx"
#include "Debugger.hxx"
#include "DebuggerParser.hxx"
#include "TIA.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Widget.hxx"
#include "GuiObject.hxx"
#include "Dialog.hxx"
#include "ToolTip.hxx"
#include "ContextMenu.hxx"
#include "FrameManager.hxx"
#include "TiaZoomWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TiaZoomWidget::TiaZoomWidget(GuiObject* boss, const GUI::Font& font,
                             int x, int y, int w, int h)
  : Widget(boss, font, x, y, 16, 16),
    CommandSender(boss)
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_CLEARBG |
           Widget::FLAG_RETAIN_FOCUS | Widget::FLAG_TRACK_MOUSE;
  _bgcolor = _bgcolorhi = kDlgColor;

  // Use all available space, up to the maximum bounds of the TIA image
  _w = std::min(w, 320);
  _h = std::min(h, static_cast<int>(FrameManager::Metrics::maxHeight));

  addFocusWidget(this);

  // Initialize positions
  myNumCols = (_w - 4) / myZoomLevel;
  myNumRows = (_h - 4) / myZoomLevel;

  // Create context menu for zoom levels
  VariantList l;
  VarList::push_back(l, "Fill to scanline", "scanline");
  VarList::push_back(l, "Toggle breakpoint", "bp");
  VarList::push_back(l, "2x zoom", "2");
  VarList::push_back(l, "4x zoom", "4");
  VarList::push_back(l, "8x zoom", "8");
  myMenu = make_unique<ContextMenu>(this, font, l);

  setHelpAnchor("TIAZoom", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::loadConfig()
{
  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::setPos(int x, int y)
{
  // Center on given x,y point
  myOffX = x - (myNumCols >> 1);
  myOffY = y - (myNumRows >> 1);

  recalc();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::zoom(int level)
{
  if(myZoomLevel == level)
    return;

  // zoom towards mouse position
  myOffX = round(myOffX + myClickX / myZoomLevel - myClickX / level);
  myOffY = round(myOffY + myClickY / myZoomLevel - myClickY / level);

  myZoomLevel = level;
  myNumCols = (_w - 4) / myZoomLevel & 0xfffe; // must be even!
  myNumRows = (_h - 4) / myZoomLevel;

  recalc();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::recalc()
{
  const int tw = instance().console().tia().width(),
            th = instance().console().tia().height();

  // Don't go past end of framebuffer
  myOffX = BSPF::clamp(myOffX, 0, (tw << 1) - myNumCols);
  myOffY = BSPF::clamp(myOffY, 0, th - myNumRows);

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  myClickX = x;
  myClickY = y - 1;

  // Button 1 is for 'drag'/movement of the image
  // Button 2 is for context menu
  if(b == MouseButton::LEFT)
  {
    // Indicate mouse drag started/in progress
    myMouseMoving = true;
    myOffXLo = myOffYLo = 0;
  }
  else if(b == MouseButton::RIGHT)
  {
    // Add menu at current x,y mouse location
    myMenu->show(x + getAbsX(), y + getAbsY(), dialog().surface().dstRect());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  myMouseMoving = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::handleMouseWheel(int x, int y, int direction)
{
  dialog().tooltip().hide();

  // zoom towards mouse position
  myClickX = x;
  myClickY = y - 1;

  if(direction > 0)
  {
    if (myZoomLevel > 1)
      zoom(myZoomLevel - 1);
  }
  else
  {
    if (myZoomLevel < 8)
      zoom(myZoomLevel + 1);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::handleMouseMoved(int x, int y)
{
  if(myMouseMoving)
  {
    y--;
    const int diffx = x + myOffXLo - myClickX;
    const int diffy = y + myOffYLo - myClickY;

    myClickX = x;
    myClickY = y;

    myOffX -= diffx / myZoomLevel;
    myOffY -= diffy / myZoomLevel;
    // handle remainder
    myOffXLo = diffx % myZoomLevel;
    myOffYLo = diffy % myZoomLevel;

    recalc();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::handleMouseLeft()
{
  myMouseMoving = false;
  Widget::handleMouseLeft();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TiaZoomWidget::handleEvent(Event::Type event)
{
  bool handled = true;

  switch(event)
  {
    case Event::UIUp:
      myOffY -= 4;
      break;

    case Event::UIDown:
      myOffY += 4;
      break;

    case Event::UILeft:
      myOffX -= 4;
      break;

    case Event::UIRight:
      myOffX += 4;
      break;

    case Event::UIPgUp:
      myOffY = 0;
      break;

    case Event::UIPgDown:
      myOffY = _h;
      break;

    case Event::UIHome:
      myOffX = 0;
      break;

    case Event::UIEnd:
      myOffX = _w;
      break;

    default:
      handled = false;
      break;
  }

  if(handled)
    recalc();

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  if(cmd == ContextMenu::kItemSelectedCmd)
  {
    const uInt32 startLine = instance().console().tia().startLine();
    const string& rmb = myMenu->getSelectedTag().toString();

    if(rmb == "scanline")
    {
      ostringstream command;
      int lines = myClickY / myZoomLevel + myOffY + startLine - instance().console().tia().scanlines();

      if (lines < 0)
        lines += instance().console().tia().scanlinesLastFrame();
      if(lines > 0)
      {
        command << "scanline #" << lines;
        const string& message = instance().debugger().parser().run(command.str());
        instance().frameBuffer().showTextMessage(message);
      }
    }
    else if(rmb == "bp")
    {
      ostringstream command;
      const int scanline = myClickY / myZoomLevel + myOffY + startLine;
      command << "breakif _scan==#" << scanline;
      const string& message = instance().debugger().parser().run(command.str());
      instance().frameBuffer().showTextMessage(message);
    }
    else
    {
      const int level = myMenu->getSelectedTag().toInt();
      if(level > 0)
        zoom(level);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Point TiaZoomWidget::getToolTipIndex(const Common::Point& pos) const
{
  const Int32 width = instance().console().tia().width() * 2;
  const Int32 height = instance().console().tia().height();
  const int col = (pos.x - 1 - getAbsX()) / (myZoomLevel << 1) + (myOffX >> 1);
  const int row = (pos.y - 1 - getAbsY()) / myZoomLevel + myOffY;

  if(col < 0 || col >= width || row < 0 || row >= height)
    return Common::Point(-1, -1);
  else
    return Common::Point(col, row);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TiaZoomWidget::getToolTip(const Common::Point& pos) const
{
  const Common::Point& idx = getToolTipIndex(pos);

  if(idx.x < 0)
    return EmptyString;

  const Int32 i = idx.x + idx.y * instance().console().tia().width();
  const uInt32 startLine = instance().console().tia().startLine();
  const uInt8* tiaOutputBuffer = instance().console().tia().outputBuffer();
  ostringstream buf;

  buf << _toolTipText
    << "X: #" << idx.x
    << "\nY: #" << idx.y + startLine
    << "\nC: $" << Common::Base::toString(tiaOutputBuffer[i], Common::Base::Fmt::_16);

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TiaZoomWidget::changedToolTip(const Common::Point& oldPos,
                                     const Common::Point& newPos) const
{
  return getToolTipIndex(oldPos) != getToolTipIndex(newPos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaZoomWidget::drawWidget(bool hilite)
{
//cerr << "TiaZoomWidget::drawWidget\n";
  FBSurface& s = dialog().surface();

  s.fillRect(_x+1, _y+1, _w-2, _h-2, kBGColor);
  s.frameRect(_x, _y, _w, _h, hilite ? kWidColorHi : kColor);

  // Draw the zoomed image
  // This probably isn't as efficient as it can be, but it's a small area
  // and I don't have time to make it faster :)
  const uInt8* currentFrame  = instance().console().tia().outputBuffer();
  const int width = instance().console().tia().width(),
            wzoom = myZoomLevel << 1,
            hzoom = myZoomLevel;

  // Get current scanline position
  // This determines where the frame greying should start
  uInt32 scanx = 0, scany = 0;
  instance().console().tia().electronBeamPos(scanx, scany);
  const uInt32 scanoffset = width * scany + scanx;

  for(int y = myOffY, row = 0; y < myNumRows+myOffY; ++y, row += hzoom)
  {
    for(int x = myOffX >> 1, col = 0; x < (myNumCols+myOffX) >> 1; ++x, col += wzoom)
    {
      const uInt32 idx = y*width + x;
      const auto color = static_cast<ColorId>(currentFrame[idx] | (idx > scanoffset ? 1 : 0));
      s.fillRect(_x + col + 1, _y + row + 1, wzoom, hzoom, color);
    }
  }
}
