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

#include <regex>
#include "EventHandler.hxx"
#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "JPGLibrary.hxx"
#include "OSystem.hxx"
#include "PNGLibrary.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "TimerManager.hxx"

#include "RomImageWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomImageWidget::RomImageWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, int w, int h)
  : Widget(boss, font, x, y, w, h)
{
  _flags = Widget::FLAG_ENABLED | Widget::FLAG_TRACK_MOUSE; // | FLAG_WANTS_RAWDATA;
  _bgcolor = kDlgColor;
  _bgcolorlo = kBGColorLo;
  myImageHeight = _h - labelHeight(font) - font.getFontHeight() / 4 - 1;

  myZoomRect = Common::Rect(_w * 7 / 16, myImageHeight * 7 / 16,
                            _w * 9 / 16, myImageHeight * 9 / 16);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::setProperties(const FSNode& node,
                                   const Properties& properties, bool full)
{
  myHaveProperties = true;
  myProperties = properties;

  // Decide whether the information should be shown immediately
  if(instance().eventHandler().state() == EventHandlerState::LAUNCHER)
    parseProperties(node, full);
#ifdef DEBUGGER_SUPPORT
  else
  {
    cerr << "RomImageWidget::setProperties: else!\n";
    Logger::debug("RomImageWidget::setProperties: else!");
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::clearProperties()
{
  myHaveProperties = mySurfaceIsValid = false;
  if(mySurface)
    mySurface->setVisible(false);

  // Decide whether the information should be shown immediately
  if(instance().eventHandler().state() == EventHandlerState::LAUNCHER)
    setDirty();
#ifdef DEBUGGER_SUPPORT
  else
  {
    cerr << "RomImageWidget::clearProperties: else!\n";
    Logger::debug("RomImageWidget::clearProperties: else!");
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::reloadProperties(const FSNode& node)
{
  // The ROM may have changed since we were last in the browser, either
  // by saving a different image or through a change in video renderer,
  // so we reload the properties
  if(myHaveProperties)
    parseProperties(node);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::parseProperties(const FSNode& node, bool full)
{
  FrameBuffer& fb = instance().frameBuffer();
  const uInt64 startTime = TimerManager::getTicks() / 1000;

  if(myNavSurface == nullptr)
  {
    // Create navigation surface
    const uInt32 scale = fb.hidpiScaleFactor();

    myNavSurface = fb.allocateSurface(_w, myImageHeight);
    myNavSurface->setDstSize(_w * scale, myImageHeight * scale);

    FBSurface::Attributes& attr = myNavSurface->attributes();

    attr.blending = true;
    attr.blendalpha = 60;
    myNavSurface->applyAttributes();
  }

  // Check if a surface has ever been created; if so, we use it
  // The surface will always be the maximum size, but sometimes we'll
  // only draw certain parts of it
  if(mySurface == nullptr)
  {
    mySurface = fb.allocateSurface(_w, myImageHeight, ScalingInterpolation::blur);
    mySurface->applyAttributes();
    myFrameSurface = fb.allocateSurface(1, 1, ScalingInterpolation::sharp);
    myFrameSurface->applyAttributes();
    myFrameSurface->setVisible(true);

    dialog().addRenderCallback([this]() {
      if(mySurfaceIsValid)
      {
        if(myIsZoomed)
          myFrameSurface->render();
        mySurface->render();
      }

      if(isHighlighted() && !myIsZoomed)
        myNavSurface->render();
    });
  }

  myZoomMode = false;
#ifdef IMAGE_SUPPORT
  if(!full)
  {
    myImageIdx = 0;
    myImageList.clear();
    myLabel.clear();

    // Get a valid filename representing a snapshot file for this rom and load the snapshot
    const string& path = instance().snapshotLoadDir().getPath();

    // 1. Try to load first snapshot by property name
    string fileName = path + myProperties.get(PropType::Cart_Name);
    tryImageFormats(fileName);
    if(!mySurfaceIsValid)
    {
      // 2. If none exists, try to load first snapshot by ROM file name
      fileName = path + node.getName();
      tryImageFormats(fileName);
    }
    if(mySurfaceIsValid)
      myImageList.emplace_back(fileName);
    else
    {
      // 3. If no ROM snapshots exist, try to load a default snapshot
      fileName = path + "default_snapshot";
      tryImageFormats(fileName);
    }
  }
  else
  {
    const string oldFileName = !myImageList.empty()
        ? myImageList[0].getPath() : EmptyString;

    // Try to find all snapshots by property and ROM file name
    myImageList.clear();
    getImageList(myProperties.get(PropType::Cart_Name), node.getNameWithExt(),
      oldFileName);

    // The first file found before must not be the first file now, if files by
    // property *and* ROM name are found (TODO: fix that!)
    if(!myImageList.empty() && myImageList[0].getPath() != oldFileName)
      loadImage(myImageList[0].getPath());
    else
      setDirty(); // update the counter display
  }
#else
  mySurfaceIsValid = false;
  mySurfaceErrorMsg = "Image loading not supported";
  setDirty();
#endif
  if(mySurface)
  {
    mySurface->setVisible(mySurfaceIsValid);
    myFrameSurface->setVisible(mySurfaceIsValid);
  }

  // Update maximum load time
  myMaxLoadTime = std::min(
    static_cast<uInt64>(500ULL / timeFactor),
    std::max(myMaxLoadTime, TimerManager::getTicks() / 1000 - startTime));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::changeImage(int direction)
{
#ifdef IMAGE_SUPPORT
  if(direction == -1 && myImageIdx)
    return loadImage(myImageList[--myImageIdx].getPath());
  else if(direction == 1 && myImageIdx + 1 < myImageList.size())
    return loadImage(myImageList[++myImageIdx].getPath());
#endif
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::toggleImageZoom()
{
#ifdef IMAGE_SUPPORT
  myMousePos = Common::Point(_w >> 1, myImageHeight >> 1);
  myZoomMode = !myIsZoomed;
  myZoomTimer = myZoomMode ? DELAY_TIME * REQUEST_SPEED : 0;
  zoomSurfaces(!myIsZoomed);
#endif
}

#ifdef IMAGE_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::getImageList(const string& propName, const string& romName,
                                  const string& oldFileName)
{
  const std::regex symbols{R"([-[\]{}()*+?.,\^$|#])"}; // \s
  const string rgxPropName = std::regex_replace(propName, symbols, R"(\$&)");
  const string rgxRomName  = std::regex_replace(romName,  symbols, R"(\$&)");
  // Look for <name.png|jpg> or <name_#.png|jpg> (# is a number)
  const std::regex rgx("^(" + rgxPropName + "|" + rgxRomName + ")(_\\d+)?\\.(png|jpg)$");

  const FSNode::NameFilter filter = ([&](const FSNode& node) {
      return std::regex_match(node.getName(), rgx);
    }
  );

  // Find all images matching the given names and the extension
  const FSNode node(instance().snapshotLoadDir().getPath());
  node.getChildren(myImageList, FSNode::ListMode::FilesOnly, filter, false, false);

  // Sort again, not considering extensions, else <filename.png|jpg> would be at
  // the end of the list
  std::sort(myImageList.begin(), myImageList.end(),
            [oldFileName](const FSNode& node1, const FSNode& node2)
    {
      const int compare = BSPF::compareIgnoreCase(
        node1.getNameWithExt(), node2.getNameWithExt());
      return
        compare < 0 ||
        // PNGs first!
        (compare == 0 &&
          node1.getName().substr(node1.getName().find_last_of('.') + 1) >
          node2.getName().substr(node2.getName().find_last_of('.') + 1)) ||
        // Make sure that first image found in initial load is first image now too
        node1.getName() == oldFileName;
    }
  );
  return !myImageList.empty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::tryImageFormats(string& fileName)
{
  if(loadImage(fileName + ".png"))
  {
    fileName += ".png";
    return true;
  }
  if(loadImage(fileName + ".jpg"))
  {
    fileName += ".jpg";
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::loadImage(const string& fileName)
{
  mySurfaceErrorMsg.clear();

  const string::size_type idx = fileName.find_last_of('.');

  if(idx != string::npos && fileName.substr(idx + 1) == "png")
    mySurfaceIsValid = loadPng(fileName);
  else
    mySurfaceIsValid = loadJpg(fileName);

  if(mySurfaceIsValid)
  {
    mySrcRect = mySurface->srcRect();
    zoomSurfaces(false, true);
  }

  if(mySurface)
    mySurface->setVisible(mySurfaceIsValid);

  if (!myZoomMode)
    myZoomTimer = 0;
  setDirty();
  return mySurfaceIsValid;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::loadPng(const string& fileName)
{
  try
  {
    VariantList metaData;
    instance().png().loadImage(fileName, *mySurface, metaData);

    // Retrieve label for loaded image
    myLabel.clear();
    for(const auto& data: metaData)
    {
      if(data.first == "Title")
      {
        myLabel = data.second.toString();
        break;
      }
      if(data.first == "Software"
          && data.second.toString().find("Stella") == 0)
        myLabel = "Snapshot"; // default for Stella snapshots with missing "Title" meta data
    }
    return true;
  }
  catch(const runtime_error& e)
  {
    mySurfaceErrorMsg = e.what();
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::loadJpg(const string& fileName)
{
  try
  {
    VariantList metaData;
    instance().jpg().loadImage(fileName, *mySurface, metaData);

    // Retrieve label for loaded image
    myLabel.clear();
    for(const auto& data: metaData)
    {
      if(data.first == "ImageDescription")
      {
        myLabel = data.second.toString();
        break;
      }
    }
    return true;
  }
  catch(const runtime_error& e)
  {
    mySurfaceErrorMsg = e.what();
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::zoomSurfaces(bool zoomed, bool force)
{
  if(zoomed != myIsZoomed || force)
  {
    const uInt32 scaleDpi = instance().frameBuffer().hidpiScaleFactor();

    myIsZoomed = zoomed;

    if(!zoomed)
    {
      // Scale surface to available widget area
      const float scale = std::min(
        static_cast<float>(_w - 2) / mySrcRect.w(),
        static_cast<float>(myImageHeight - 1) / mySrcRect.h()) * scaleDpi;
      const uInt32 w = mySrcRect.w() * scale;
      const uInt32 h = mySrcRect.h() * scale;

      mySurface->setDstSize(w, h);
    }
    else
    {
      // Scale surface to available launcher area
      myZoomPos = myMousePos; // remember initial zoom position

      const Int32 b = 3 * scaleDpi;
      const Common::Size maxSize = instance().frameBuffer().fullScreen()
        ? instance().frameBuffer().screenSize()
        : dialog().surface().dstRect().size();
      const Int32 lw = maxSize.w - b * 2;
      const Int32 lh = maxSize.h - b * 2;
      const Int32 iw = mySrcRect.w() * scaleDpi;
      const Int32 ih = mySrcRect.h() * scaleDpi;
      const float zoom = std::min(1.F, // do not zoom beyond original size
                                  std::min(static_cast<float>(lw) / iw,
                                           static_cast<float>(lh) / ih));
      const Int32 w = iw * zoom;
      const Int32 h = ih * zoom;

      mySurface->setDstSize(w, h);

      myFrameSurface->resize(w + b * 2, h + b * 2);
      myFrameSurface->setDstSize(w + b * 2, h + b * 2);
      myFrameSurface->frameRect(0, 0, myFrameSurface->width(), myFrameSurface->height(), kColor);

      myZoomTimer = DELAY_TIME * REQUEST_SPEED; // zoom immediately
    }
    positionSurfaces();
    setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::positionSurfaces()
{
  // Make sure when positioning the image surface that we take
  // the dialog surface position into account
  const Common::Rect& s_dst = dialog().surface().dstRect();
  const Int32 scaleDpi = instance().frameBuffer().hidpiScaleFactor();
  const Int32 w = mySurface->dstRect().w();
  const Int32 h = mySurface->dstRect().h();

  if(!myIsZoomed)
  {
    // Position image and navigation surface
    const uInt32 x = s_dst.x() + _x * scaleDpi;
    const uInt32 y = s_dst.y() + _y * scaleDpi + 1;

    mySurface->setDstPos(x + ((_w * scaleDpi - w) >> 1),
                         y + ((myImageHeight * scaleDpi - h) >> 1));
    myNavSurface->setDstPos(x, y);
  }
  else
  {
    // Display zoomed image centered over mouse position, considering launcher borders
    // Note: Using Int32 to avoid more casting
    const Int32 zx = myZoomPos.x;
    const Int32 zy = myZoomPos.y;
    const Int32 b = 3 * scaleDpi;
    const bool fs = instance().frameBuffer().fullScreen();
    const Common::Size maxSize = fs
      ? instance().frameBuffer().screenSize()
      : dialog().surface().dstRect().size();
    const Int32 lw = maxSize.w - b * 2;
    const Int32 lh = maxSize.h - b * 2;
    // Position at right top
    const Int32 x = std::min(
      static_cast<Int32>(s_dst.x()) + (_x + zx) * scaleDpi - w / 2 + b,
      lw - w + b);
    const Int32 y = std::min(
      lh - h + b,
      std::max(static_cast<Int32>(s_dst.y()) + (zy + _y) * scaleDpi - h / 2 + b, b));

    mySurface->setDstPos(x, y);
    myFrameSurface->setDstPos(x - b, y - b);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomImageWidget::handleEvent(Event::Type event)
{
  switch(event)
  {
    case Event::UIPgUp:   // controller
    case Event::UILeft:   // keyboard
      changeImage(-1);
      return true;

    case Event::UIPgDown: // controller
    case Event::UIRight:  // keyboard
      changeImage(1);
      return true;

    case Event::UIOK:     // keyboard & controller
    case Event::UISelect: // keyboard & controller
      toggleImageZoom();
      return true;

    default:
      break;
  }
  return Widget::handleEvent(event);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  if(isEnabled() && x >= 0 && x < _w && y >= 0 && y < myImageHeight)
  {
    if(myMouseArea == Area::LEFT)
      changeImage(-1);
    else if(myMouseArea == Area::RIGHT)
      changeImage(1);
    else
      zoomSurfaces(true);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::handleMouseMoved(int x, int y)
{
  const Area oldArea = myMouseArea;

  myMousePos = Common::Point(x, y);

  if(myZoomRect.contains(x, y))
    myMouseArea = Area::ZOOM;
  else if(x < _w >> 1)
    myMouseArea = Area::LEFT;
  else
    myMouseArea = Area::RIGHT;

  if(myMouseArea != oldArea)
    setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::tick()
{
  if(myMouseArea == Area::ZOOM || myZoomMode)
  {
    myZoomTimer += REQUEST_SPEED;
    if(myZoomTimer >= DELAY_TIME * REQUEST_SPEED)
      zoomSurfaces(true);
  }
  else
  {
    zoomSurfaces(false);
    if(myZoomTimer)
      --myZoomTimer;
  }

  Widget::tick();
}
#endif // IMAGE_SUPPORT

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomImageWidget::drawWidget(bool hilite)
{
  FBSurface& s = dialog().surface();

  if(!myHaveProperties || !mySurfaceIsValid || !mySurfaceErrorMsg.empty())
  {
    s.fillRect(_x, _y + 1, _w, _h - 1, _bgcolor);
    s.frameRect(_x, _y, _w, myImageHeight, kColor);
  }

  if(!myHaveProperties)
  {
    clearDirty();
    return;
  }

#ifdef IMAGE_SUPPORT
  if(mySurfaceIsValid)
  {
    s.fillRect(_x, _y, _w, myImageHeight, 0);
    positionSurfaces();
  }
  else
#endif
    if(!mySurfaceErrorMsg.empty())
    {
      const uInt32 x = _x + ((_w - _font.getStringWidth(mySurfaceErrorMsg)) >> 1);
      const uInt32 y = _y + ((myImageHeight - _font.getLineHeight()) >> 1);
      s.drawString(_font, mySurfaceErrorMsg, x, y, _w - 10, _textcolor);
    }

  // Draw the image label and counter
  ostringstream buf;
  buf << myImageIdx + 1 << "/" << myImageList.size();
  const int yText = _y + _h - _font.getFontHeight() * 10 / 8;
  const int wText = _font.getStringWidth(buf.str()) + 8;

  s.fillRect(_x, yText, _w, _font.getFontHeight(), _bgcolor);
  if(!myLabel.empty())
    s.drawString(_font, myLabel, _x + 8, yText, _w - wText - 16 - _font.getMaxCharWidth() * 2, _textcolor);
  if(!myImageList.empty())
    s.drawString(_font, buf.str(), _x + _w - wText, yText, wText, _textcolor);

  // Draw the navigation icons
  myNavSurface->invalidate();
  if(isHighlighted())
  {
    // Draw arrows
    for(int dir = 0; dir < 2; ++dir)
    {
      // Is direction arrow shown?
      if((!dir && myImageIdx) || (dir && myImageIdx + 1 < myImageList.size()))
      {
        const bool highlight =
          (!dir && myMouseArea == Area::LEFT) ||
          (dir && myMouseArea == Area::RIGHT);
        const int w = _w / 64;
        const int w2 = 1; // w / 2;
        const int ax = !dir ? _w / 12 - w / 2 : _w - _w / 12 - w / 2;
        const int ay = myImageHeight >> 1;
        const int dx = (_w / 32) * (!dir ? 1 : -1);
        const int dy = myImageHeight / 16;

        // Draw dark arrow frame
        for(int i = 0; i < w; ++i)
        {
          myNavSurface->line(ax + dx + i + w2, ay - dy, ax + i + w2, ay, kBGColor);
          myNavSurface->line(ax + dx + i + w2, ay + dy, ax + i + w2, ay, kBGColor);
          myNavSurface->line(ax + dx + i, ay - dy + w2, ax + i, ay + w2, kBGColor);
          myNavSurface->line(ax + dx + i, ay + dy + w2, ax + i, ay + w2, kBGColor);
          myNavSurface->line(ax + dx + i + w2, ay - dy + w2, ax + i + w2, ay + w2, kBGColor);
          myNavSurface->line(ax + dx + i + w2, ay + dy + w2, ax + i + w2, ay + w2, kBGColor);
        }
        // Draw bright arrow
        for(int i = 0; i < w; ++i)
        {
          myNavSurface->line(ax + dx + i, ay - dy, ax + i, ay, highlight ? kColorInfo : kColor);
          myNavSurface->line(ax + dx + i, ay + dy, ax + i, ay, highlight ? kColorInfo : kColor);
        }
      }
    } // arrows
    if(!myImageList.empty())
    {
      // Draw zoom icon
      const int dx = myZoomRect.w() / 2;
      const int dy = myZoomRect.h() / 2;
      const int w = dx * 2 / 3;
      const int h = dy * 2 / 3;

      for(int b = 1; b >= 0; --b) // First shadow, then bright
      {
        const ColorId color = b ? kBGColor : myMouseArea == Area::ZOOM ? kColorInfo : kColor;
        const int ax = _w / 2 + b;
        const int ay = myImageHeight / 2 + b;

        for(int i = 0; i < myImageHeight / 80; ++i)
        {
          // Top left
          myNavSurface->line(ax - dx, ay - dy + i, ax - dx + w, ay - dy + i, color);
          myNavSurface->line(ax - dx + i, ay - dy, ax - dx + i, ay - dy + h, color);
          // Top right
          myNavSurface->line(ax + dx, ay - dy + i, ax + dx - w, ay - dy + i, color);
          myNavSurface->line(ax + dx - i, ay - dy, ax + dx - i, ay - dy + h, color);
          // Bottom left
          myNavSurface->line(ax - dx, ay + dy - i, ax - dx + w, ay + dy - i, color);
          myNavSurface->line(ax - dx + i, ay + dy, ax - dx + i, ay + dy - h, color);
          // Bottom right
          myNavSurface->line(ax + dx, ay + dy - i, ax + dx - w, ay + dy - i, color);
          myNavSurface->line(ax + dx - i, ay + dy, ax + dx - i, ay + dy - h, color);
        }
      }
    } // zoom icon
  }
  s.frameRect(_x, _y, _w, _h, isHighlighted() ? kWidColorHi : kColor);
  clearDirty();
}
