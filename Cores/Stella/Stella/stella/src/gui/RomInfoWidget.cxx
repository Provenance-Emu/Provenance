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

#include "EventHandler.hxx"
#include "FrameBuffer.hxx"
#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "OSystem.hxx"
#include "ControllerDetector.hxx"
#include "Bankswitch.hxx"
#include "CartDetector.hxx"
#include "Logger.hxx"
#include "Props.hxx"
#include "PNGLibrary.hxx"
#include "PropsSet.hxx"
#include "Rect.hxx"
#include "Widget.hxx"
#include "RomInfoWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomInfoWidget::RomInfoWidget(GuiObject* boss, const GUI::Font& font,
                             int x, int y, int w, int h,
                             const Common::Size& imgSize)
  : Widget(boss, font, x, y, w, h),
    CommandSender(boss),
    myAvail{imgSize}
{
  _flags = Widget::FLAG_ENABLED;
  _bgcolor = kDlgColor;
  _bgcolorlo = kBGColorLo;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::setProperties(const FSNode& node, const string& md5)
{
  myHaveProperties = true;

  // Make sure to load a per-ROM properties entry, if one exists
  instance().propSet().loadPerROM(node, md5);

  // And now get the properties for this ROM
  instance().propSet().getMD5(md5, myProperties);

  // Decide whether the information should be shown immediately
  if(instance().eventHandler().state() == EventHandlerState::LAUNCHER)
    parseProperties(node);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::clearProperties()
{
  myHaveProperties = mySurfaceIsValid = false;
  if(mySurface)
    mySurface->setVisible(mySurfaceIsValid);

  // Decide whether the information should be shown immediately
  if(instance().eventHandler().state() == EventHandlerState::LAUNCHER)
    setDirty();
  myUrl.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::reloadProperties(const FSNode& node)
{
  // The ROM may have changed since we were last in the browser, either
  // by saving a different image or through a change in video renderer,
  // so we reload the properties
  if(myHaveProperties)
    parseProperties(node);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::parseProperties(const FSNode& node)
{
  // Check if a surface has ever been created; if so, we use it
  // The surface will always be the maximum size, but sometimes we'll
  // only draw certain parts of it
  if(mySurface == nullptr)
  {
    mySurface = instance().frameBuffer().allocateSurface(
        myAvail.w, myAvail.h, ScalingInterpolation::blur);
    mySurface->applyAttributes();

    dialog().addRenderCallback([this]() {
      if(mySurfaceIsValid)
        mySurface->render();
      }
    );
  }

  // Initialize to empty properties entry
  mySurfaceErrorMsg = "";
  mySurfaceIsValid = false;
  myRomInfo.clear();

#ifdef PNG_SUPPORT
  // Get a valid filename representing a snapshot file for this rom and load the snapshot
  const string& path = instance().snapshotLoadDir().getPath();

  // 1. Try to load snapshot by property name
  mySurfaceIsValid = loadPng(path + myProperties.get(PropType::Cart_Name) + ".png");

  if(!mySurfaceIsValid)
  {
    // 2. If no snapshot with property name exists, try to load snapshot image by filename
    mySurfaceIsValid = loadPng(path + node.getNameWithExt("") + ".png");

    if(!mySurfaceIsValid)
    {
      // 3. If no ROM snapshot exists, try to load a default snapshot
      mySurfaceIsValid = loadPng(path + "default_snapshot.png");
    }
  }
#else
  mySurfaceErrorMsg = "PNG image loading not supported";
#endif
  if(mySurface)
    mySurface->setVisible(mySurfaceIsValid);

  myUrl = myProperties.get(PropType::Cart_Url);

  // Now add some info for the message box below the image
  myRomInfo.push_back("Name: " + myProperties.get(PropType::Cart_Name));

  string value;

  if((value = myProperties.get(PropType::Cart_Manufacturer)) != EmptyString)
    myRomInfo.push_back("Manufacturer: " + value);
  if((value = myProperties.get(PropType::Cart_ModelNo)) != EmptyString)
    myRomInfo.push_back("Model: " + value);
  if((value = myProperties.get(PropType::Cart_Rarity)) != EmptyString)
    myRomInfo.push_back("Rarity: " + value);
  if((value = myProperties.get(PropType::Cart_Note)) != EmptyString)
    myRomInfo.push_back("Note: " + value);
  const bool swappedPorts = myProperties.get(PropType::Console_SwapPorts) == "YES";

  // Load the image for controller and bankswitch type auto detection
  string left = myProperties.get(PropType::Controller_Left);
  string right = myProperties.get(PropType::Controller_Right);
  const Controller::Type leftType = Controller::getType(left);
  const Controller::Type rightType = Controller::getType(right);
  string bsDetected = myProperties.get(PropType::Cart_Type);
  bool isPlusCart = false;
  size_t size = 0;
  try
  {
    ByteBuffer image;
    string md5 = "";

    if(node.exists() && !node.isDirectory() &&
      (image = instance().openROM(node, md5, size)) != nullptr)
    {
      Logger::debug(myProperties.get(PropType::Cart_Name) + ":");
      left = ControllerDetector::detectName(image, size, leftType,
          !swappedPorts ? Controller::Jack::Left : Controller::Jack::Right,
          instance().settings());
      right = ControllerDetector::detectName(image, size, rightType,
          !swappedPorts ? Controller::Jack::Right : Controller::Jack::Left,
          instance().settings());
      if (bsDetected == "AUTO")
        bsDetected = Bankswitch::typeToName(CartDetector::autodetectType(image, size));

      isPlusCart = CartDetector::isProbablyPlusROM(image, size);
    }
  }
  catch(const runtime_error&)
  {
    // Do nothing; we simply don't update the controllers if openROM
    // failed for any reason
    left = right = "";
  }
  if(left != "" && right != "")
    myRomInfo.push_back("Controllers: " + (left + " (left), " + right + " (right)"));

  if(bsDetected != "")
  {
    ostringstream buf;

    // Display actual ROM size in developer mode
    if(instance().settings().getBool("dev.settings"))
    {
      buf << " - ";
      if(size < 1_KB)
        buf << size << "B";
      else
        buf << (std::round(size / static_cast<float>(1_KB))) << "K";
    }
    myRomInfo.push_back("Type: " + Bankswitch::typeToDesc(Bankswitch::nameToType(bsDetected))
                        + (isPlusCart ? " - PlusROM" : "")
                        + buf.str());
  }
  setDirty();
}

#ifdef PNG_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool RomInfoWidget::loadPng(const string& filename)
{
  try
  {
    instance().png().loadImage(filename, *mySurface);

    // Scale surface to available image area
    const Common::Rect& src = mySurface->srcRect();
    const float scale = std::min(float(myAvail.w) / src.w(), float(myAvail.h) / src.h()) *
      instance().frameBuffer().hidpiScaleFactor();
    mySurface->setDstSize(static_cast<uInt32>(src.w() * scale), static_cast<uInt32>(src.h() * scale));

    return true;
  }
  catch(const runtime_error& e)
  {
    mySurfaceErrorMsg = e.what();
  }
  return false;
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  if(isEnabled() && x >= 0 && x < _w && y >= 0 && y < _h)
  {
    clearFlags(Widget::FLAG_HILITED);
    sendCommand(kClickedCmd, 0, _id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::drawWidget(bool hilite)
{
  FBSurface& s = dialog().surface();
  const int yoff = myAvail.h + _font.getFontHeight() / 2;

  s.fillRect(_x+2, _y+2, _w-4, _h-4, _bgcolor);
  s.frameRect(_x, _y, _w, myAvail.h, kColor);
  s.frameRect(_x, _y+yoff, _w, _h-yoff, kColor);

  if(!myHaveProperties)
  {
    clearDirty();
    return;
  }

  if(mySurfaceIsValid)
  {
    const Common::Rect& dst = mySurface->dstRect();
    const uInt32 scale = instance().frameBuffer().hidpiScaleFactor();
    const uInt32 x = _x * scale + ((_w * scale - dst.w()) >> 1);
    const uInt32 y = _y * scale + ((myAvail.h * scale - dst.h()) >> 1);

    // Make sure when positioning the snapshot surface that we take
    // the dialog surface position into account
    const Common::Rect& s_dst = s.dstRect();
    mySurface->setDstPos(x + s_dst.x(), y + s_dst.y());
  }
  else if(mySurfaceErrorMsg != "")
  {
    const uInt32 x = _x + ((_w - _font.getStringWidth(mySurfaceErrorMsg)) >> 1);
    const uInt32 y = _y + ((yoff - _font.getLineHeight()) >> 1);
    s.drawString(_font, mySurfaceErrorMsg, x, y, _w - 10, _textcolor);
  }

  const int xpos = _x + 8;
  int ypos = _y + yoff + 5;
  for(const auto& info : myRomInfo)
  {
    if(info.length() * _font.getMaxCharWidth() <= static_cast<size_t>(_w - 16))

    {
      // 1 line for next entry
      if(ypos + _font.getFontHeight() > _h + _y)
        break;
    }
    else
    {
      // assume 2 lines for next entry
      if(ypos + _font.getLineHeight() + _font.getFontHeight() > _h + _y )
        break;
    }

    int lines = 0;

    if(BSPF::startsWithIgnoreCase(info, "Name: ") && myUrl != EmptyString)
    {
      lines = s.drawString(_font, info, xpos, ypos, _w - 16, _font.getFontHeight() * 3,
                           _textcolor, TextAlign::Left, 0, true, kNone,
                           6, info.length() - 6, hilite);
    }
    else
      lines = s.drawString(_font, info, xpos, ypos, _w - 16, _font.getFontHeight() * 3,
                           _textcolor);
    ypos += _font.getLineHeight() + (lines - 1) * _font.getFontHeight();
  }
  clearDirty();
}
