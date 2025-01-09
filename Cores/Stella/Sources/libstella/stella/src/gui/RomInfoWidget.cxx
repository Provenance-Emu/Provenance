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

#include "EventHandler.hxx"
#include "Dialog.hxx"
#include "FBSurface.hxx"
#include "Font.hxx"
#include "OSystem.hxx"
#include "ControllerDetector.hxx"
#include "Bankswitch.hxx"
#include "CartDetector.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "RomInfoWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RomInfoWidget::RomInfoWidget(GuiObject* boss, const GUI::Font& font,
                             int x, int y, int w, int h)
  : Widget(boss, font, x, y, w, h),
    CommandSender(boss)
{
  _flags = Widget::FLAG_ENABLED;
  _bgcolor = kDlgColor;
  _bgcolorlo = kBGColorLo;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::setProperties(const FSNode& node,
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
    cerr << "RomInfoWidget::setProperties: else!\n";
    Logger::debug("RomInfoWidget::setProperties: else!");
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::clearProperties()
{
  myHaveProperties = false;

  // Decide whether the information should be shown immediately
  if(instance().eventHandler().state() == EventHandlerState::LAUNCHER)
    setDirty();
#ifdef DEBUGGER_SUPPORT
  else
  {
    cerr << "RomInfoWidget::clearProperties: else!\n";
    Logger::debug("RomInfoWidget::clearProperties: else!");
  }
#endif
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
void RomInfoWidget::parseProperties(const FSNode& node, bool full)
{
  // Initialize to empty properties entry
  myRomInfo.clear();

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

  if(full)
  {
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
      string md5;

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
        if(bsDetected == "AUTO")
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
    if(!left.empty() && !right.empty())
      myRomInfo.push_back("Controllers: " + (left + " (left), " + right + " (right)"));

    if(!bsDetected.empty())
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
#if defined(DEBUG_BUILD) && defined(IMAGE_SUPPORT)
    // Debug bezel properties:
    if(myProperties.get(PropType::Bezel_Name).empty())
      myRomInfo.push_back("*Bezel: " + Bezel::getName(instance().bezelDir().getPath(), myProperties));
    else
      myRomInfo.push_back(" Bezel: " + myProperties.get(PropType::Bezel_Name));
#endif
  }

  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  if(isEnabled() && isHighlighted()
    && x >= 0 && x < _w && y >= 0 && y < _h)
  {
    clearFlags(Widget::FLAG_HILITED); // avoid double clicks and opened URLs
    sendCommand(kClickedCmd, 0, _id);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void RomInfoWidget::drawWidget(bool hilite)
{
  FBSurface& s = dialog().surface();

  s.fillRect(_x+2, _y+2, _w-4, _h-4, _bgcolor);
  s.frameRect(_x, _y, _w, _h, kColor);

  if(!myHaveProperties)
  {
    clearDirty();
    return;
  }

  const int xpos = _x + 8;
  int ypos = _y + 5;
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
