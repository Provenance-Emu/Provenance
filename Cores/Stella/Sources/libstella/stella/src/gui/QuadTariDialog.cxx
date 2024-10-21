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

#include "OSystem.hxx"
#include "Console.hxx"
#include "EventHandler.hxx"
#include "Widget.hxx"
#include "PopUpWidget.hxx"
#include "Font.hxx"
#include "Variant.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "Launcher.hxx"
#include "ControllerDetector.hxx"
#include "QuadTari.hxx"
#include "QuadTariDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
QuadTariDialog::QuadTariDialog(GuiObject* boss, const GUI::Font& font, int max_w, int max_h,
                               Properties& properties)
  : Dialog(boss->instance(), boss->parent(), font, "QuadTari controllers", 0, 0, max_w, max_h),
    myGameProperties{properties}
{
  const GUI::Font& ifont = instance().frameBuffer().infoFont();
  const int lineHeight = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            VBORDER    = Dialog::vBorder(),
            HBORDER    = Dialog::hBorder(),
            VGAP       = Dialog::vGap();
  WidgetArray wid;
  VariantList ctrls;

  int xpos = HBORDER, ypos = VBORDER + _th;

  ctrls.clear();
  VarList::push_back(ctrls, "Auto-detect", "AUTO");
  VarList::push_back(ctrls, "Joystick", "JOYSTICK");
  VarList::push_back(ctrls, "Paddles", "PADDLES");
  //VarList::push_back(ctrls, "Paddles_IAxis", "PADDLES_IAXIS");
  //VarList::push_back(ctrls, "Paddles_IAxDr", "PADDLES_IAXDR");
  //VarList::push_back(ctrls, "Booster Grip", "BOOSTERGRIP");
  VarList::push_back(ctrls, "Driving", "DRIVING");
  //VarList::push_back(ctrls, "Keyboard", "KEYBOARD");
  //VarList::push_back(ctrls, "Amiga mouse", "AMIGAMOUSE");
  //VarList::push_back(ctrls, "Atari mouse", "ATARIMOUSE");
  //VarList::push_back(ctrls, "Trak-Ball", "TRAKBALL");
  VarList::push_back(ctrls, "AtariVox", "ATARIVOX");
  VarList::push_back(ctrls, "SaveKey", "SAVEKEY");
  //VarList::push_back(ctrls, "Sega Genesis", "GENESIS");
  //VarList::push_back(items, "Joy2B+", "JOY_2B+");
  //VarList::push_back(ctrls, "Kid Vid", "KIDVID");
  //VarList::push_back(ctrls, "Light Gun", "LIGHTGUN");
  //VarList::push_back(ctrls, "MindLink", "MINDLINK");
  //VarList::push_back(ctrls, "QuadTari", "QUADTARI");

  const int pwidth = font.getStringWidth("Auto-detect  "); // a bit wider looks better overall

  myLeftPortLabel = new StaticTextWidget(this, font, xpos, ypos + 1, "Left port");

  ypos += lineHeight + VGAP * 2;
  myLeft1Port = new PopUpWidget(this, font, xpos, ypos,
                               pwidth, lineHeight, ctrls, "P1 ");
  wid.push_back(myLeft1Port);
  ypos += lineHeight + VGAP;

  myLeft1PortDetected = new StaticTextWidget(this, ifont,
    myLeft1Port->getLeft() + fontWidth * 3, ypos, "                 ");
  ypos += lineHeight + VGAP;

  myLeft2Port = new PopUpWidget(this, font, xpos, ypos,
                               pwidth, lineHeight, ctrls, "P3 ");
  wid.push_back(myLeft2Port);
  ypos += lineHeight + VGAP;

  myLeft2PortDetected = new StaticTextWidget(this, ifont,
    myLeft2Port->getLeft() + fontWidth * 3, ypos, "                 ");

  xpos = _w - HBORDER - myLeft1Port->getWidth(); // aligned right
  ypos = myLeftPortLabel->getTop() - 1;
  myRightPortLabel = new StaticTextWidget(this, font, xpos, ypos + 1, "Right port");

  ypos += lineHeight + VGAP * 2;
  myRight1Port = new PopUpWidget(this, font, xpos, ypos,
                                pwidth, lineHeight, ctrls, "P2 ");
  wid.push_back(myRight1Port);
  ypos += lineHeight + VGAP;

  myRight1PortDetected = new StaticTextWidget(this, ifont,
    myRight1Port->getLeft() + fontWidth * 3, ypos, "                 ");
  ypos += lineHeight + VGAP;

  //ypos += lineHeight + VGAP * 2;
  myRight2Port = new PopUpWidget(this, font, xpos, ypos,
                                pwidth, lineHeight, ctrls, "P4 ");
  wid.push_back(myRight2Port);
  ypos += lineHeight + VGAP;

  myRight2PortDetected = new StaticTextWidget(this, ifont,
    myRight2Port->getLeft() + fontWidth * 3, ypos, "                 ");

  addDefaultsOKCancelBGroup(wid, _font);
  addBGroupToFocusList(wid);

  setHelpAnchor("Quadtari");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariDialog::show(bool enableLeft, bool enableRight)
{
  myLeftPortLabel->setEnabled(enableLeft);
  myLeft1Port->setEnabled(enableLeft);
  myLeft2Port->setEnabled(enableLeft);
  myRightPortLabel->setEnabled(enableRight);
  myRight1Port->setEnabled(enableRight);
  myRight2Port->setEnabled(enableRight);

  open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariDialog::loadControllerProperties(const Properties& props)
{
  string controller;

  if(myLeftPortLabel->isEnabled())
  {
    defineController(props, PropType::Controller_Left1, Controller::Jack::Left,
      myLeft1Port, myLeft1PortDetected);
    defineController(props, PropType::Controller_Left2, Controller::Jack::Left,
      myLeft2Port, myLeft2PortDetected, false);
  }

  if(myRightPortLabel->isEnabled())
  {
    defineController(props, PropType::Controller_Right1, Controller::Jack::Right,
      myRight1Port, myRight1PortDetected);
    defineController(props, PropType::Controller_Right2, Controller::Jack::Right,
      myRight2Port, myRight2PortDetected, false);
  }
}

void QuadTariDialog::defineController(const Properties& props, PropType key,
  Controller::Jack jack, PopUpWidget* popupWidget, StaticTextWidget* labelWidget, bool first)
{
  bool autoDetect = false;
  ByteBuffer image;
  size_t size = 0;

  string controllerName = props.get(key);
  popupWidget->setSelected(controllerName, "AUTO");

  // try to load the image for auto detection
  if(!instance().hasConsole())
  {
    const FSNode& node = FSNode(instance().launcher().selectedRom());
    string md5 = myGameProperties.get(PropType::Cart_MD5);

    autoDetect = node.exists() && !node.isDirectory()
      && (image = instance().openROM(node, md5, size)) != nullptr;
  }
  string label;
  Controller::Type type = Controller::getType(popupWidget->getSelectedTag().toString());

  if(type == Controller::Type::Unknown)
  {
    if(instance().hasConsole())
    {
      Controller& controller = (jack == Controller::Jack::Left
        ? instance().console().leftController()
        : instance().console().rightController());

      if(BSPF::startsWithIgnoreCase(controller.name(), "QT"))
      {
        const QuadTari* qt = static_cast<QuadTari*>(&controller);
        label = (first
          ? qt->firstController().name()
          : qt->secondController().name())
        + " detected";
      }
      else
        label = "nothing detected";
    }
    else if(autoDetect)
      label = ControllerDetector::detectName(
        image, size, type, jack, instance().settings(), true) + " detected";
  }
  labelWidget->setLabel(label);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariDialog::loadConfig()
{
  loadControllerProperties(myGameProperties);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariDialog::saveConfig()
{
  if(myLeftPortLabel->isEnabled())
  {
    string controller = myLeft1Port->getSelectedTag().toString();
    myGameProperties.set(PropType::Controller_Left1, controller);
    controller = myLeft2Port->getSelectedTag().toString();
    myGameProperties.set(PropType::Controller_Left2, controller);
  }
  else
  {
    myGameProperties.set(PropType::Controller_Left1, "");
    myGameProperties.set(PropType::Controller_Left2, "");
  }

  if(myRightPortLabel->isEnabled())
  {
    string controller = myRight1Port->getSelectedTag().toString();
    myGameProperties.set(PropType::Controller_Right1, controller);
    controller = myRight2Port->getSelectedTag().toString();
    myGameProperties.set(PropType::Controller_Right2, controller);
  }
  else
  {
    myGameProperties.set(PropType::Controller_Right1, "");
    myGameProperties.set(PropType::Controller_Right2, "");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariDialog::setDefaults()
{
  // Load the default properties
  const string& md5 = myGameProperties.get(PropType::Cart_MD5);
  Properties defaultProperties;

  instance().propSet().getMD5(md5, defaultProperties, true);
  loadControllerProperties(defaultProperties);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void QuadTariDialog::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
      saveConfig();
      close();
      break;

    case GuiObject::kDefaultsCmd:
      setDefaults();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, id);
      break;
  }
}
