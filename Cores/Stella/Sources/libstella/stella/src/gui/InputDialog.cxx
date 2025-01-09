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
#include "OSystem.hxx"
#include "Console.hxx"
#include "EventHandler.hxx"
#include "Paddles.hxx"
#include "MindLink.hxx"
#include "PointingDevice.hxx"
#include "Driving.hxx"
#include "SaveKey.hxx"
#include "AtariVox.hxx"
#include "Settings.hxx"
#include "EventMappingWidget.hxx"
#include "JoystickDialog.hxx"
#include "PopUpWidget.hxx"
#include "TabWidget.hxx"
#include "Widget.hxx"
#include "Font.hxx"
#include "MessageBox.hxx"
#include "MediaFactory.hxx"
#include "InputDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
InputDialog::InputDialog(OSystem& osystem, DialogContainer& parent,
                         const GUI::Font& font, int max_w, int max_h)
  : Dialog(osystem, parent, font, "Input settings"),
    myMaxWidth{max_w},
    myMaxHeight{max_h}
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();

  // Set real dimensions
  setSize(49 * fontWidth + PopUpWidget::dropDownWidth(_font) + HBORDER * 2,
          _th + VGAP * 3 + lineHeight + 13 * (lineHeight + VGAP) + VGAP * 9 + buttonHeight + VBORDER * 3,
          max_w, max_h);

  // The tab widget
  constexpr int xpos = 2;
  const int ypos = VGAP + _th;
  myTab = new TabWidget(this, _font, xpos, ypos,
                        _w - 2*xpos,
                        _h -_th - VGAP - buttonHeight - VBORDER * 2);
  addTabWidget(myTab);

  // 1) Event mapper
  const int tabID = myTab->addTab(" Event Mappings ", TabWidget::AUTO_WIDTH);
  myEventMapper = new EventMappingWidget(myTab, _font, 2, 2,
                                             myTab->getWidth(),
                                             myTab->getHeight() - VGAP);
  myTab->setParentWidget(tabID, myEventMapper);
  addToFocusList(myEventMapper->getFocusList(), myTab, tabID);
  myTab->parentWidget(tabID)->setHelpAnchor("Remapping");

  // 2) Devices & ports
  addDevicePortTab();

  // 3) Mouse
  addMouseTab();

  // Finalize the tabs, and activate the first tab
  myTab->activateTabs();
  myTab->setActiveTab(0);

  // Add Defaults, OK and Cancel buttons
  WidgetArray wid;
  addDefaultsOKCancelBGroup(wid, _font);
  addBGroupToFocusList(wid);

  setHelpAnchor("Remapping");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
InputDialog::~InputDialog()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::addDevicePortTab()
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  const int swidth = 13 * fontWidth;
  WidgetArray wid;

  // Devices/ports
  const int tabID = myTab->addTab(" Devices & Ports ", TabWidget::AUTO_WIDTH);

  int xpos = HBORDER, ypos = VBORDER;
  int lwidth = _font.getStringWidth("Digital paddle sensitivity ");

  // Add digital dead zone setting
  myDigitalDeadzone = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                        "Digital dead zone size ",
                                        lwidth, kDDeadzoneChanged, 3 * fontWidth, "%");
  myDigitalDeadzone->setMinValue(Controller::MIN_DIGITAL_DEADZONE);
  myDigitalDeadzone->setMaxValue(Controller::MAX_DIGITAL_DEADZONE);
  myDigitalDeadzone->setTickmarkIntervals(5);
  myDigitalDeadzone->setToolTip("Adjust dead zone size for analog joysticks when emulating digital controllers.",
    Event::DecreaseDeadzone, Event::IncreaseDeadzone);
  wid.push_back(myDigitalDeadzone);

  // Add analog dead zone
  ypos += lineHeight + VGAP;
  myAnalogDeadzone = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                      "Analog dead zone size",
                                      lwidth, kADeadzoneChanged, 3 * fontWidth, "%");
  myAnalogDeadzone->setMinValue(Controller::MIN_ANALOG_DEADZONE);
  myAnalogDeadzone->setMaxValue(Controller::MAX_ANALOG_DEADZONE);
  myAnalogDeadzone->setTickmarkIntervals(5);
  myAnalogDeadzone->setToolTip("Adjust dead zone size for analog joysticks when emulating analog controllers.",
    Event::DecAnalogDeadzone, Event::IncAnalogDeadzone);
  wid.push_back(myAnalogDeadzone);

  ypos += lineHeight + VGAP * (3 - 2);
  new StaticTextWidget(myTab, _font, xpos, ypos+1, "Analog paddle:");
  xpos += fontWidth * 2;

  // Add analog paddle sensitivity
  ypos += lineHeight;
  myPaddleSpeed = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                 "Sensitivity",
                                 lwidth - fontWidth * 2, kPSpeedChanged, 4 * fontWidth, "%");
  myPaddleSpeed->setMinValue(0);
  myPaddleSpeed->setMaxValue(Paddles::MAX_ANALOG_SENSE);
  myPaddleSpeed->setTickmarkIntervals(3);
  myPaddleSpeed->setToolTip(Event::DecAnalogSense, Event::IncAnalogSense);
  wid.push_back(myPaddleSpeed);

  // Add analog paddle linearity
  ypos += lineHeight + VGAP;
  myPaddleLinearity = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                       "Linearity", lwidth - fontWidth * 2, 0, 4 * fontWidth, "%");
  myPaddleLinearity->setMinValue(Paddles::MIN_ANALOG_LINEARITY);
  myPaddleLinearity->setMaxValue(Paddles::MAX_ANALOG_LINEARITY);
  myPaddleLinearity->setStepValue(5);
  myPaddleLinearity->setTickmarkIntervals(3);
  myPaddleLinearity->setToolTip("Adjust paddle movement linearity.",
    Event::DecAnalogLinear, Event::IncAnalogLinear);
  wid.push_back(myPaddleLinearity);

  // Add dejitter (analog paddles)
  ypos += lineHeight + VGAP;
  myDejitterBase = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                    "Dejitter averaging", lwidth - fontWidth * 2,
                                    kDejitterAvChanged, 3 * fontWidth);
  myDejitterBase->setMinValue(Paddles::MIN_DEJITTER);
  myDejitterBase->setMaxValue(Paddles::MAX_DEJITTER);
  myDejitterBase->setTickmarkIntervals(5);
  myDejitterBase->setToolTip("Adjust paddle input averaging.\n"
                             "Note: Already implemented in 2600-daptor",
    Event::DecDejtterAveraging, Event::IncDejtterAveraging);
  //xpos += myDejitterBase->getWidth() + fontWidth - 4;
  wid.push_back(myDejitterBase);

  ypos += lineHeight + VGAP;
  myDejitterDiff = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                    "Dejitter reaction", lwidth - fontWidth * 2,
                                    kDejitterReChanged, 3 * fontWidth);
  myDejitterDiff->setMinValue(Paddles::MIN_DEJITTER);
  myDejitterDiff->setMaxValue(Paddles::MAX_DEJITTER);
  myDejitterDiff->setTickmarkIntervals(5);
  myDejitterDiff->setToolTip("Adjust paddle reaction to fast movements.",
    Event::DecDejtterReaction, Event::IncDejtterReaction);
  wid.push_back(myDejitterDiff);

  // Add paddle speed (digital emulation)
  ypos += lineHeight + VGAP * (3 - 2);
  myDPaddleSpeed = new SliderWidget(myTab, _font, HBORDER, ypos - 1, swidth, lineHeight,
                                    "Digital paddle sensitivity",
                                    lwidth, kDPSpeedChanged, 4 * fontWidth, "%");
  myDPaddleSpeed->setMinValue(1); myDPaddleSpeed->setMaxValue(20);
  myDPaddleSpeed->setTickmarkIntervals(4);
  myDPaddleSpeed->setToolTip(Event::DecDigitalSense, Event::IncDigitalSense);
  wid.push_back(myDPaddleSpeed);

  ypos += lineHeight + VGAP * (3 - 2);
  myAutoFire = new CheckboxWidget(myTab, _font, HBORDER, ypos + 1, "Autofire", kAutoFireChanged);
  myAutoFire->setToolTip(Event::ToggleAutoFire);
  wid.push_back(myAutoFire);

  myAutoFireRate = new SliderWidget(myTab, _font, HBORDER + lwidth - fontWidth * 5,
    ypos - 1, swidth, lineHeight, "Rate ", 0, kAutoFireRate, 5 * fontWidth, "Hz");
  myAutoFireRate->setMinValue(0); myAutoFireRate->setMaxValue(30);
  myAutoFireRate->setTickmarkIntervals(6);
  myAutoFireRate->setToolTip(Event::DecreaseAutoFire, Event::IncreaseAutoFire);
  wid.push_back(myAutoFireRate);

  // Add 'allow all 4 directions' for joystick
  ypos += lineHeight + VGAP * (4 - 2);
  myAllowAll4 = new CheckboxWidget(myTab, _font, HBORDER, ypos,
                                   "Allow all 4 directions on joystick");
  myAllowAll4->setToolTip(Event::ToggleFourDirections);
  wid.push_back(myAllowAll4);

  // Enable/disable modifier key-combos
  ypos += lineHeight + VGAP;
  myModCombo = new CheckboxWidget(myTab, _font, HBORDER, ypos,
                                  "Use modifier key combos");
  myModCombo->setToolTip(Event::ToggleKeyCombos);
  wid.push_back(myModCombo);
  ypos += lineHeight + VGAP;

  // Stelladaptor mappings
  mySAPort = new CheckboxWidget(myTab, _font, HBORDER, ypos,
                                "Swap Stelladaptor ports");
  mySAPort->setToolTip(Event::ToggleSAPortOrder);
  wid.push_back(mySAPort);

  // Add EEPROM erase (part 1/2)
  ypos += VGAP * (3 - 1);
  int fwidth = _font.getStringWidth("AtariVox/SaveKey");
  new StaticTextWidget(myTab, _font, _w - HBORDER - 2 - fwidth, ypos,
                       "AtariVox/SaveKey");

  // Show joystick database
  ypos += lineHeight;
  lwidth = Dialog::buttonWidth("Controller Database" + ELLIPSIS);
  myJoyDlgButton = new ButtonWidget(myTab, _font, HBORDER, ypos, lwidth, buttonHeight,
                                    "Controller Database" + ELLIPSIS, kDBButtonPressed);
  wid.push_back(myJoyDlgButton);

  // Add EEPROM erase (part 1/2)
  myEraseEEPROMButton = new ButtonWidget(myTab, _font, _w - HBORDER - 2 - fwidth, ypos,
                                         fwidth, buttonHeight,
                                        "Erase EEPROM", kEEButtonPressed);
  wid.push_back(myEraseEEPROMButton);

  // Add AtariVox serial port
  ypos += lineHeight + VGAP * 3;
  lwidth = _font.getStringWidth("AtariVox serial port ");
  fwidth = _w - HBORDER * 2 - 2 - lwidth - PopUpWidget::dropDownWidth(_font);
  myAVoxPort = new PopUpWidget(myTab, _font, HBORDER, ypos, fwidth, lineHeight,
                  VariantList{}, "AtariVox serial port ", lwidth,
                  kCursorStateChanged);
  myAVoxPort->setEditable(true);
  wid.push_back(myAVoxPort);

  // Add items for virtual device ports
  addToFocusList(wid, myTab, tabID);

  myTab->parentWidget(tabID)->setHelpAnchor("DevicesPorts");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::addMouseTab()
{
  const int lineHeight = Dialog::lineHeight(),
            fontWidth  = Dialog::fontWidth(),
            VBORDER    = Dialog::vBorder(),
            HBORDER    = Dialog::hBorder(),
            VGAP       = Dialog::vGap(),
            INDENT     = Dialog::indent();
  const int swidth = 13 * fontWidth;
  WidgetArray wid;
  VariantList items;

  // Mouse
  const int tabID = myTab->addTab("  Mouse  ", TabWidget::AUTO_WIDTH);

  int xpos = HBORDER, ypos = VBORDER;
  int lwidth = _font.getStringWidth("Use mouse as a controller ");
  const int pwidth = _font.getStringWidth("-UI, -Emulation");

  // Use mouse as controller
  VarList::push_back(items, "Always", "always");
  VarList::push_back(items, "Analog devices", "analog");
  VarList::push_back(items, "Never", "never");
  myMouseControl = new PopUpWidget(myTab, _font, xpos, ypos, pwidth, lineHeight, items,
                                   "Use mouse as a controller ", lwidth, kMouseCtrlChanged);
  myMouseControl->setToolTip(Event::PrevMouseAsController, Event::NextMouseAsController);
  wid.push_back(myMouseControl);

  ypos += lineHeight + VGAP;
  myMouseSensitivity = new StaticTextWidget(myTab, _font, xpos, ypos + 1, "Sensitivity:");

  // Add paddle speed (mouse emulation)
  xpos += INDENT;  ypos += lineHeight + VGAP;
  lwidth -= INDENT;
  myMPaddleSpeed = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                    "Paddle",
                                    lwidth, kMPSpeedChanged, 4 * fontWidth, "%");
  myMPaddleSpeed->setMinValue(1); myMPaddleSpeed->setMaxValue(20);
  myMPaddleSpeed->setTickmarkIntervals(4);
  myMPaddleSpeed->setToolTip(Event::DecMousePaddleSense, Event::IncMousePaddleSense);
  wid.push_back(myMPaddleSpeed);

  // Add trackball speed
  ypos += lineHeight + VGAP;
  myTrackBallSpeed = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                      "Trackball",
                                      lwidth, kTBSpeedChanged, 4 * fontWidth, "%");
  myTrackBallSpeed->setMinValue(1); myTrackBallSpeed->setMaxValue(20);
  myTrackBallSpeed->setTickmarkIntervals(4);
  myTrackBallSpeed->setToolTip(Event::DecMouseTrackballSense, Event::IncMouseTrackballSense);
  wid.push_back(myTrackBallSpeed);

  // Add driving controller speed
  ypos += lineHeight + VGAP;
  myDrivingSpeed = new SliderWidget(myTab, _font, xpos, ypos - 1, swidth, lineHeight,
                                    "Driving controller",
                                    lwidth, kDCSpeedChanged, 4 * fontWidth, "%");
  myDrivingSpeed->setMinValue(1); myDrivingSpeed->setMaxValue(20);
  myDrivingSpeed->setTickmarkIntervals(4);
  myDrivingSpeed->setToolTip("Adjust driving controller sensitivity for digital and mouse input.",
    Event::DecreaseDrivingSense, Event::IncreaseDrivingSense);
  wid.push_back(myDrivingSpeed);

  // Mouse cursor state
  lwidth += INDENT;
  ypos += lineHeight + VGAP * 4;
  items.clear();
  VarList::push_back(items, "-UI, -Emulation", "0");
  VarList::push_back(items, "-UI, +Emulation", "1");
  VarList::push_back(items, "+UI, -Emulation", "2");
  VarList::push_back(items, "+UI, +Emulation", "3");
  myCursorState = new PopUpWidget(myTab, _font, HBORDER, ypos, pwidth, lineHeight, items,
                                  "Mouse cursor visibility ", lwidth, kCursorStateChanged);
  myCursorState->setToolTip(Event::PreviousCursorVisbility, Event::NextCursorVisbility);
  wid.push_back(myCursorState);
#ifndef WINDOWED_SUPPORT
  myCursorState->clearFlags(Widget::FLAG_ENABLED);
#endif

  // Grab mouse (in windowed mode)
  ypos += lineHeight + VGAP;
  myGrabMouse = new CheckboxWidget(myTab, _font, HBORDER, ypos,
                                   "Grab mouse in emulation mode");
  myGrabMouse->setToolTip(Event::ToggleGrabMouse);
  wid.push_back(myGrabMouse);
#ifndef WINDOWED_SUPPORT
  myGrabMouse->clearFlags(Widget::FLAG_ENABLED);
#endif

  // Add items for mouse
  addToFocusList(wid, myTab, tabID);

  myTab->parentWidget(tabID)->setHelpAnchor("Mouse");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::loadConfig()
{
  const Settings& settings = instance().settings();

  // Left & right ports
  mySAPort->setState(settings.getString("saport") == "rl");

  // Use mouse as a controller
  myMouseControl->setSelected(
    settings.getString("usemouse"), "analog");
  handleMouseControlState();

  // Mouse cursor state
  myCursorState->setSelected(settings.getString("cursor"), "2");
  handleCursorState();

  // Digital dead zone
  myDigitalDeadzone->setValue(settings.getInt("joydeadzone"));
  // Analog dead zone
  myAnalogDeadzone->setValue(settings.getInt("adeadzone"));

  // Paddle speed (analog)
  myPaddleSpeed->setValue(settings.getInt("psense"));
  // Paddle linearity (analog)
  myPaddleLinearity->setValue(settings.getInt("plinear"));
  // Paddle dejitter (analog)
  myDejitterBase->setValue(settings.getInt("dejitter.base"));
  myDejitterDiff->setValue(settings.getInt("dejitter.diff"));

  // Paddle speed (digital and mouse)
  myDPaddleSpeed->setValue(settings.getInt("dsense"));
  myMPaddleSpeed->setValue(settings.getInt("msense"));

  // Trackball speed
  myTrackBallSpeed->setValue(settings.getInt("tsense"));
  // Driving controller speed
  myDrivingSpeed->setValue(settings.getInt("dcsense"));

  // Autofire
  myAutoFire->setState(settings.getBool("autofire"));

  // Autofire rate
  myAutoFireRate->setValue(settings.getInt("autofirerate"));

  // AtariVox serial port
  const string& avoxport = settings.getString("avoxport");
  const StringList ports = MediaFactory::createSerialPort()->portNames();
  VariantList items;

  for(const auto& port: ports)
    VarList::push_back(items, port, port);
  if(avoxport != EmptyString && !BSPF::contains(ports, avoxport))
    VarList::push_back(items, avoxport, avoxport);
  if(items.empty())
    VarList::push_back(items, "None detected");

  myAVoxPort->addItems(items);
  myAVoxPort->setSelected(avoxport);

  // EEPROM erase (only enable in emulation mode and for valid controllers)
  if(instance().hasConsole())
  {
    const Controller& lport = instance().console().leftController();
    const Controller& rport = instance().console().rightController();

    myEraseEEPROMButton->setEnabled(
        lport.type() == Controller::Type::SaveKey || lport.type() == Controller::Type::AtariVox ||
        rport.type() == Controller::Type::SaveKey || rport.type() == Controller::Type::AtariVox);
  }
  else
    myEraseEEPROMButton->setEnabled(false);

  // Allow all 4 joystick directions
  myAllowAll4->setState(settings.getBool("joyallow4"));

  // Grab mouse
  myGrabMouse->setState(settings.getBool("grabmouse"));

  // Enable/disable modifier key-combos
  myModCombo->setState(settings.getBool("modcombo"));

  myTab->loadConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::saveConfig()
{
  Settings& settings = instance().settings();

  // *** Device & Ports ***
  // Digital dead zone
  int deadZone = myDigitalDeadzone->getValue();
  settings.setValue("joydeadzone", deadZone);
  Controller::setDigitalDeadZone(deadZone);
  // Analog dead zone
  deadZone = myAnalogDeadzone->getValue();
  settings.setValue("adeadzone", deadZone);
  Controller::setAnalogDeadZone(deadZone);

  // Paddle speed (analog)
  int sensitivity = myPaddleSpeed->getValue();
  settings.setValue("psense", sensitivity);
  Paddles::setAnalogSensitivity(sensitivity);
  // Paddle linearity (analog)
  const int linearity = myPaddleLinearity->getValue();
  settings.setValue("plinear", linearity);
  Paddles::setAnalogLinearity(linearity);

  // Paddle dejitter (analog)
  int dejitter = myDejitterBase->getValue();
  settings.setValue("dejitter.base", dejitter);
  Paddles::setDejitterBase(dejitter);
  dejitter = myDejitterDiff->getValue();
  settings.setValue("dejitter.diff", dejitter);
  Paddles::setDejitterDiff(dejitter);

  sensitivity = myDPaddleSpeed->getValue();
  settings.setValue("dsense", sensitivity);
  Paddles::setDigitalSensitivity(sensitivity);

  // Autofire mode & rate
  const bool enabled = myAutoFire->getState();
  settings.setValue("autofire", enabled);
  Controller::setAutoFire(enabled);

  const int rate = myAutoFireRate->getValue();
  settings.setValue("autofirerate", rate);
  Controller::setAutoFireRate(rate);

  // Allow all 4 joystick directions
  const bool allowall4 = myAllowAll4->getState();
  settings.setValue("joyallow4", allowall4);
  instance().eventHandler().allowAllDirections(allowall4);

  // Enable/disable modifier key-combos
  settings.setValue("modcombo", myModCombo->getState());

  // Left & right ports
  instance().eventHandler().mapStelladaptors(mySAPort->getState() ? "rl" : "lr");

  // AtariVox serial port
  settings.setValue("avoxport", myAVoxPort->getText());

  // *** Mouse ***
  // Use mouse as a controller
  const string& usemouse = myMouseControl->getSelectedTag().toString();
  settings.setValue("usemouse", usemouse);
  instance().eventHandler().setMouseControllerMode(usemouse);

  sensitivity = myMPaddleSpeed->getValue();
  settings.setValue("msense", sensitivity);
  Paddles::setMouseSensitivity(sensitivity);
  MindLink::setMouseSensitivity(sensitivity);

  // Trackball speed
  sensitivity = myTrackBallSpeed->getValue();
  settings.setValue("tsense", sensitivity);
  PointingDevice::setSensitivity(sensitivity);

  // Driving controller speed
  sensitivity = myDrivingSpeed->getValue();
  settings.setValue("dcsense", sensitivity);
  Driving::setSensitivity(sensitivity);

  // Grab mouse and hide cursor
  const string& cursor = myCursorState->getSelectedTag().toString();
  settings.setValue("cursor", cursor);

  // only allow grab mouse if cursor is hidden in emulation
  const int state = myCursorState->getSelected();
  const bool enableGrab = state != 1 && state != 3;
  const bool grab = enableGrab ? myGrabMouse->getState() : false;
  settings.setValue("grabmouse", grab);
  instance().frameBuffer().enableGrabMouse(grab);

  instance().eventHandler().saveKeyMapping();
  instance().eventHandler().saveJoyMapping();
//  instance().saveConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::setDefaults()
{
  switch(myTab->getActiveTab())
  {
    case 0:  // Emulation events
      myEventMapper->setDefaults();
      break;

    case 1:  // Devices & Ports
      // Digital dead zone
      myDigitalDeadzone->setValue(0);

      // Analog dead zone
      myAnalogDeadzone->setValue(0);

      // Paddle speed (analog)
      myPaddleSpeed->setValue(20);

      // Paddle linearity
      myPaddleLinearity->setValue(100);
    #if defined(RETRON77)
      myDejitterBase->setValue(2);
      myDejitterDiff->setValue(6);
    #else
      myDejitterBase->setValue(0);
      myDejitterDiff->setValue(0);
    #endif

      // Paddle speed (digital)
      myDPaddleSpeed->setValue(10);

      // Autofire
      myAutoFire->setState(false);

      // Autofire rate
      myAutoFireRate->setValue(0);

      // Allow all 4 joystick directions
      myAllowAll4->setState(false);

      // Enable/disable modifier key-combos
      myModCombo->setState(true);

      // Left & right ports
      mySAPort->setState(false);

      // AtariVox serial port
      myAVoxPort->setSelectedIndex(0);
      break;

    case 2:  // Mouse
      // Use mouse as a controller
      myMouseControl->setSelected("analog");

      // Paddle speed (mouse)
      myMPaddleSpeed->setValue(10);
      myTrackBallSpeed->setValue(10);
      myDrivingSpeed->setValue(10);

      // Mouse cursor state
      myCursorState->setSelected("2");

      // Grab mouse
      myGrabMouse->setState(true);

      handleMouseControlState();
      handleCursorState();
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool InputDialog::repeatEnabled()
{
  return !myEventMapper->isRemapping();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  // Remap key events in remap mode, otherwise pass to parent dialog
  if (myEventMapper->remapMode())
    myEventMapper->handleKeyDown(key, mod);
  else
    Dialog::handleKeyDown(key, mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleKeyUp(StellaKey key, StellaMod mod)
{
  // Remap key events in remap mode, otherwise pass to parent dialog
  if (myEventMapper->remapMode())
    myEventMapper->handleKeyUp(key, mod);
  else
    Dialog::handleKeyUp(key, mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleJoyDown(int stick, int button, bool longPress)
{
  // Remap joystick buttons in remap mode, otherwise pass to parent dialog
  if(myEventMapper->remapMode())
    myEventMapper->handleJoyDown(stick, button);
  else
    Dialog::handleJoyDown(stick, button);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleJoyUp(int stick, int button)
{
  // Remap joystick buttons in remap mode, otherwise pass to parent dialog
  if (myEventMapper->remapMode())
    myEventMapper->handleJoyUp(stick, button);
  else
    Dialog::handleJoyUp(stick, button);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleJoyAxis(int stick, JoyAxis axis, JoyDir adir, int button)
{
  // Remap joystick axis in remap mode, otherwise pass to parent dialog
  if(myEventMapper->remapMode())
    myEventMapper->handleJoyAxis(stick, axis, adir, button);
  else
    Dialog::handleJoyAxis(stick, axis, adir, button);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool InputDialog::handleJoyHat(int stick, int hat, JoyHatDir hdir, int button)
{
  // Remap joystick hat in remap mode, otherwise pass to parent dialog
  if(myEventMapper->remapMode())
    return myEventMapper->handleJoyHat(stick, hat, hdir, button);
  else
    return Dialog::handleJoyHat(stick, hat, hdir, button);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::eraseEEPROM()
{
  // This method will only be callable if a console exists, so we don't
  // need to check again here
  Controller& lport = instance().console().leftController();
  Controller& rport = instance().console().rightController();

  if(lport.type() == Controller::Type::SaveKey || lport.type() == Controller::Type::AtariVox)
  {
    auto& skey = static_cast<SaveKey&>(lport);
    skey.eraseCurrent();
  }

  if(rport.type() == Controller::Type::SaveKey || rport.type() == Controller::Type::AtariVox)
  {
    auto& skey = static_cast<SaveKey&>(rport);
    skey.eraseCurrent();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleCommand(CommandSender* sender, int cmd,
                                int data, int id)
{
  switch(cmd)
  {
    case GuiObject::kOKCmd:
      saveConfig();
      close();
      break;

    case GuiObject::kCloseCmd:
      // Revert changes made to event mapping
      close();
      break;

    case GuiObject::kDefaultsCmd:
      setDefaults();
      break;

    case kDDeadzoneChanged:
      myDigitalDeadzone->setValueLabel(std::round(
          Controller::digitalDeadZoneValue(myDigitalDeadzone->getValue()) *
          100.F / (Paddles::ANALOG_RANGE / 2)));  // NOLINT
      break;

    case kADeadzoneChanged:
      myAnalogDeadzone->setValueLabel(std::round(
          Controller::analogDeadZoneValue(myAnalogDeadzone->getValue()) *
          100.F / (Paddles::ANALOG_RANGE / 2)));  // NOLINT
      break;

    case kPSpeedChanged:
      myPaddleSpeed->setValueLabel(std::round(Paddles::setAnalogSensitivity(
          myPaddleSpeed->getValue()) * 100.F));
      break;

    case kDejitterAvChanged:
      updateDejitterAveraging();
      break;

    case kDejitterReChanged:
      updateDejitterReaction();
      break;

    case kDPSpeedChanged:
      myDPaddleSpeed->setValueLabel(myDPaddleSpeed->getValue() * 10);
      break;

    case kDCSpeedChanged:
      myDrivingSpeed->setValueLabel(myDrivingSpeed->getValue() * 10);
      break;

    case kTBSpeedChanged:
      myTrackBallSpeed->setValueLabel(myTrackBallSpeed->getValue() * 10);
      break;

    case kAutoFireChanged:
    case kAutoFireRate:
      updateAutoFireRate();
      break;

    case kDBButtonPressed:
      if(!myJoyDialog)
      {
        const GUI::Font& font = instance().frameBuffer().font();
        myJoyDialog = make_unique<JoystickDialog>
          (this, font, fontWidth() * 60 + 20, fontHeight() * 18 + 20);
      }
      myJoyDialog->show();
      break;

    case kEEButtonPressed:
      if(!myConfirmMsg)
      {
        StringList msg;
        msg.emplace_back("This operation cannot be undone.");
        msg.emplace_back("All data stored on your AtariVox");
        msg.emplace_back("or SaveKey will be erased!");
        msg.emplace_back("");
        msg.emplace_back("If you are sure you want to erase");
        msg.emplace_back("the data, click 'OK', otherwise ");
        msg.emplace_back("click 'Cancel'.");
        myConfirmMsg = make_unique<GUI::MessageBox>
          (this, instance().frameBuffer().font(), msg,
           myMaxWidth, myMaxHeight, kConfirmEEEraseCmd,
           "OK", "Cancel", "Erase EEPROM", false);
      }
      myConfirmMsg->show();
      break;

    case kConfirmEEEraseCmd:
      eraseEEPROM();
      break;

    case kMouseCtrlChanged:
      handleMouseControlState();
      handleCursorState();
      break;

    case kCursorStateChanged:
      handleCursorState();
      break;

    case kMPSpeedChanged:
      myMPaddleSpeed->setValueLabel(myMPaddleSpeed->getValue() * 10);
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::updateDejitterAveraging()
{
  const int strength = myDejitterBase->getValue();

  myDejitterBase->setValueLabel(strength ? std::to_string(strength) : "Off");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::updateDejitterReaction()
{
  const int strength = myDejitterDiff->getValue();

  myDejitterDiff->setValueLabel(strength ? std::to_string(strength) : "Off");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::updateAutoFireRate()
{
  const bool enable = myAutoFire->getState();
  const int rate = myAutoFireRate->getValue();

  myAutoFireRate->setEnabled(enable);
  myAutoFireRate->setValueLabel(rate ? std::to_string(rate) : "Off");
  myAutoFireRate->setValueUnit(rate ? " Hz" : "");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleMouseControlState()
{
  const bool enable = myMouseControl->getSelected() != 2;

  myMPaddleSpeed->setEnabled(enable);
  myTrackBallSpeed->setEnabled(enable);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void InputDialog::handleCursorState()
{
  const int state = myCursorState->getSelected();
  const bool enableGrab = state != 1 && state != 3 && myMouseControl->getSelected() != 2;

  myGrabMouse->setEnabled(enableGrab);
}
