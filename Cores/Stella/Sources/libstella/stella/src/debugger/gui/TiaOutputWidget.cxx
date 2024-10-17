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

#include <sstream>

#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "Widget.hxx"
#include "GuiObject.hxx"
#include "Dialog.hxx"
#include "ContextMenu.hxx"
#include "TiaZoomWidget.hxx"
#include "Debugger.hxx"
#include "DebuggerParser.hxx"
#include "PNGLibrary.hxx"
#include "TIADebug.hxx"
#include "TIASurface.hxx"
#include "TIA.hxx"
#include "TimerManager.hxx"
#include "FrameManager.hxx"

#include "TiaOutputWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TiaOutputWidget::TiaOutputWidget(GuiObject* boss, const GUI::Font& font,
                                 int x, int y, int w, int h)
  : Widget(boss, font, x, y, w, h),
    CommandSender(boss)
{
  // Create context menu for commands
  VariantList l;
  VarList::push_back(l, "Fill to scanline", "scanline");
  VarList::push_back(l, "Toggle breakpoint", "bp");
  VarList::push_back(l, "Set zoom position", "zoom");
#ifdef IMAGE_SUPPORT
  VarList::push_back(l, "Save snapshot", "snap");
#endif
  myMenu = make_unique<ContextMenu>(this, font, l);

  //setHelpAnchor("TIADisplay", true); // TODO: does not work due to missing focus
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaOutputWidget::loadConfig()
{
  setEnabled(true);
  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaOutputWidget::saveSnapshot(int execDepth, string_view execPrefix,
                                   bool mark)
{
#ifdef IMAGE_SUPPORT
  if(execDepth > 0)
    drawWidget(false);

  ostringstream sspath;
  sspath << instance().snapshotSaveDir()
         << instance().console().properties().get(PropType::Cart_Name);

  if(mark)
  {
    sspath << "_dbg_";
    if(execDepth > 0 && !execPrefix.empty()) {
      sspath << execPrefix << "_";
    }
    sspath << std::hex << std::setw(8) << std::setfill('0')
      << static_cast<uInt32>(TimerManager::getTicks() / 1000);
  }
  else
  {
    // Determine if the file already exists, checking each successive filename
    // until one doesn't exist
    const FSNode node(sspath.str() + ".png");
    if(node.exists())
    {
      ostringstream suffix;
      ostringstream buf;
      for(uInt32 i = 1; ; ++i)
      {
        buf.str("");
        suffix.str("");
        suffix << "_" << i;
        buf << sspath.str() << suffix.str() << ".png";
        const FSNode next(buf.str());
        if(!next.exists())
          break;
      }
      sspath << suffix.str();
    }
  }
  sspath << ".png";

  const uInt32 width  = instance().console().tia().width(),
               height = instance().console().tia().height();
  const FBSurface& s = dialog().surface();

  // to skip borders, add 1 to origin
  const int x = _x + 1, y = _y + 1;
  const Common::Rect rect(x, y, x + width*2, y + height);
  string message = "Snapshot saved";
  try
  {
    PNGLibrary::saveImage(sspath.str(), s, rect);
  }
  catch(const runtime_error& e)
  {
    message = e.what();
  }
  if (execDepth == 0) {
    instance().frameBuffer().showTextMessage(message);
  }
#else
  instance().frameBuffer().showTextMessage("PNG image saving not supported");
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaOutputWidget::handleMouseDown(int x, int y, MouseButton b, int clickCount)
{
  if(b == MouseButton::LEFT)
    myZoom->setPos(x, y);
  // Grab right mouse button for command context menu
  else if(b == MouseButton::RIGHT)
  {
    myClickX = x;
    myClickY = y - 1;

    // Add menu at current x,y mouse location
    myMenu->show(x + getAbsX(), y + getAbsY(), dialog().surface().dstRect());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaOutputWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  const uInt32 startLine = instance().console().tia().startLine();

  if(cmd == ContextMenu::kItemSelectedCmd)
  {
    const string& rmb = myMenu->getSelectedTag().toString();

    if(rmb == "scanline")
    {
      ostringstream command;
      int lines = myClickY + startLine - instance().console().tia().scanlines();

      if(lines < 0)
        lines += instance().console().tia().scanlinesLastFrame();
      if(lines > 0)
      {
        command << "scanLine #" << lines;
        const string message = instance().debugger().parser().run(command.str());
        instance().frameBuffer().showTextMessage(message);
      }
    }
    else if(rmb == "bp")
    {
      ostringstream command;
      const int scanline = myClickY + startLine;
      command << "breakIf _scan==#" << scanline;
      const string& message = instance().debugger().parser().run(command.str());
      instance().frameBuffer().showTextMessage(message);
    }
    else if(rmb == "zoom")
    {
      if(myZoom)
        myZoom->setPos(myClickX, myClickY);
    }
    else if(rmb == "snap")
    {
      instance().debugger().parser().run("saveSnap");
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Common::Point TiaOutputWidget::getToolTipIndex(const Common::Point& pos) const
{
  const Int32 width = instance().console().tia().width();
  const Int32 height = instance().console().tia().height();
  const int col = (pos.x - 1 - getAbsX()) >> 1;
  const int row = pos.y - 1 - getAbsY();

  if(col < 0 || col >= width || row < 0 || row >= height)
    return Common::Point(-1, -1);
  else
    return Common::Point(col, row);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TiaOutputWidget::getToolTip(const Common::Point& pos) const
{
  const Common::Point& idx = getToolTipIndex(pos);

  if(idx.x < 0)
    return EmptyString;

  const uInt32 startLine = instance().console().tia().startLine();
  const uInt32 height = instance().console().tia().height();
  // limit to 274 lines (PAL default without scaling)
  const uInt32 yStart = height <= FrameManager::Metrics::baseHeightPAL
    ? 0 : (height - FrameManager::Metrics::baseHeightPAL) >> 1;
  const Int32 i = idx.x + (yStart + idx.y) * instance().console().tia().width();
  const uInt8* tiaOutputBuffer = instance().console().tia().outputBuffer();
  ostringstream buf;

  buf << _toolTipText
    << "X: #" << idx.x
    << "\nY: #" << idx.y + startLine
    << "\nC: $" << Common::Base::toString(tiaOutputBuffer[i], Common::Base::Fmt::_16);

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TiaOutputWidget::changedToolTip(const Common::Point& oldPos,
                                     const Common::Point& newPos) const
{
  return getToolTipIndex(oldPos) != getToolTipIndex(newPos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TiaOutputWidget::drawWidget(bool hilite)
{
//cerr << "TiaOutputWidget::drawWidget\n";
  const uInt32 width = instance().console().tia().width();
  uInt32 height = instance().console().tia().height();
  // limit to 274 lines (PAL default without scaling)
  const uInt32 yStart = height <= FrameManager::Metrics::baseHeightPAL ? 0 :
      (height - FrameManager::Metrics::baseHeightPAL) / 2;
  height = std::min<uInt32>(height, FrameManager::Metrics::baseHeightPAL);
  FBSurface& s = dialog().surface();

  s.vLine(_x + _w + 1, _y, height, kColor);
  s.hLine(_x, _y + height + 1, _x +_w + 1, kColor);

  // Get current scanline position
  // This determines where the frame greying should start, and where a
  // scanline 'pointer' should be drawn
  uInt32 scanx = 0, scany = 0;
  const bool visible = instance().console().tia().electronBeamPos(scanx, scany);
  const uInt32 scanoffset = width * scany + scanx;
  const uInt8* tiaOutputBuffer = instance().console().tia().outputBuffer();
  const TIASurface& tiaSurface = instance().frameBuffer().tiaSurface();

  for(uInt32 y = 0, i = yStart * width; y < height; ++y)
  {
    uInt32* line_ptr = myLineBuffer.data();
    for(uInt32 x = 0; x < width; ++x, ++i)
    {
      const uInt8 shift = i >= scanoffset ? 1 : 0;
      const uInt32 pixel = tiaSurface.mapIndexedPixel(tiaOutputBuffer[i], shift);
      *line_ptr++ = pixel;
      *line_ptr++ = pixel;
    }
    s.drawPixels(myLineBuffer.data(), _x + 1, _y + 1 + y, width << 1);
  }

  // Show electron beam position
  if(visible && scanx < width && scany+2U < height)
    s.fillRect(_x + 1 + (scanx<<1), _y + 1 + scany, 3, 3, kColorInfo);
}
