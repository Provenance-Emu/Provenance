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
#include "Launcher.hxx"
#include "PropsSet.hxx"
#include "ControllerDetector.hxx"
#include "NTSCFilter.hxx"
#include "PopUpWidget.hxx"
#include "MessageBox.hxx"
#include "TIASurface.hxx"

#include "StellaSettingsDialog.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StellaSettingsDialog::StellaSettingsDialog(OSystem& osystem, DialogContainer& parent,
  int max_w, int max_h, AppMode mode)
  : Dialog(osystem, parent, osystem.frameBuffer().font(), "Basic settings"),
    myMode{mode}
{
  const int iLineHeight = instance().frameBuffer().infoFont().getLineHeight();
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            buttonWidth  = Dialog::buttonWidth("  Help  " + ELLIPSIS),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap(),
            INDENT       = Dialog::indent();
  ButtonWidget* bw = nullptr;

  WidgetArray wid;

  // Set real dimensions
  setSize(35 * fontWidth + HBORDER * 2 + 5,
          VBORDER * 2 +_th + 10 * (lineHeight + VGAP) + 3 * (iLineHeight + VGAP)
          + VGAP * 12 + buttonHeight * 2, max_w, max_h);

  int xpos = HBORDER;
  int ypos = VBORDER + _th;

  bw = new ButtonWidget(this, _font, xpos, ypos, _w - HBORDER * 2 - buttonWidth - 8, buttonHeight,
    "Use Advanced Settings" + ELLIPSIS, kAdvancedSettings);
  wid.push_back(bw);
  bw = new ButtonWidget(this, _font, bw->getRight() + 8, ypos, buttonWidth, buttonHeight,
    "Help" + ELLIPSIS, kHelp);
  wid.push_back(bw);

  ypos += buttonHeight + VGAP * 2;

  new StaticTextWidget(this, _font, xpos, ypos + 1, "Global settings:");
  xpos += INDENT;
  ypos += lineHeight + VGAP;

  addUIOptions(wid, xpos, ypos);
  ypos += VGAP * 4;
  addVideoOptions(wid, xpos, ypos);
  ypos += VGAP * 4;

  xpos -= INDENT;
  myGameSettings = new StaticTextWidget(this, _font, xpos, ypos + 1, "Game settings:");
  xpos += INDENT;
  ypos += lineHeight + VGAP;

  addGameOptions(wid, xpos, ypos);

  // Add Defaults, OK and Cancel buttons
  addDefaultsOKCancelBGroup(wid, _font);

  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StellaSettingsDialog::~StellaSettingsDialog() // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::addUIOptions(WidgetArray& wid, int xpos, int& ypos)
{
  const int lineHeight = Dialog::lineHeight(),
            VGAP       = Dialog::vGap();
  VariantList items;
  const int pwidth = _font.getStringWidth("Right bottom"); // align width with other popup

  ypos += 1;
  VarList::push_back(items, "Standard", "standard");
  VarList::push_back(items, "Classic", "classic");
  VarList::push_back(items, "Light", "light");
  myThemePopup = new PopUpWidget(this, _font, xpos, ypos, pwidth, lineHeight, items, "UI theme           ");
  wid.push_back(myThemePopup);
  ypos += lineHeight + VGAP;

  // Dialog position
  items.clear();
  VarList::push_back(items, "Centered", 0);
  VarList::push_back(items, "Left top", 1);
  VarList::push_back(items, "Right top", 2);
  VarList::push_back(items, "Right bottom", 3);
  VarList::push_back(items, "Left bottom", 4);
  myPositionPopup = new PopUpWidget(this, _font, xpos, ypos, pwidth, lineHeight,
    items, "Dialogs position   ");
  wid.push_back(myPositionPopup);
  ypos += lineHeight + VGAP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::addVideoOptions(WidgetArray& wid, int xpos, int& ypos)
{
  const int lineHeight = Dialog::lineHeight(),
            fontWidth  = Dialog::fontWidth(),
            VGAP       = Dialog::vGap();
  const GUI::Font& ifont = instance().frameBuffer().infoFont();
  VariantList items;

  // TV effects options
  const int swidth = _font.getMaxCharWidth() * 11;

  // TV Mode
  VarList::push_back(items, "Disabled", static_cast<uInt32>(NTSCFilter::Preset::OFF));
  VarList::push_back(items, "RGB", static_cast<uInt32>(NTSCFilter::Preset::RGB));
  VarList::push_back(items, "S-Video", static_cast<uInt32>(NTSCFilter::Preset::SVIDEO));
  VarList::push_back(items, "Composite", static_cast<uInt32>(NTSCFilter::Preset::COMPOSITE));
  VarList::push_back(items, "Bad adjust", static_cast<uInt32>(NTSCFilter::Preset::BAD));
  const int pwidth = _font.getStringWidth("Right bottom");
  const int lwidth = _font.getStringWidth("Scanline intensity ");

  myTVMode = new PopUpWidget(this, _font, xpos, ypos, pwidth, lineHeight,
    items, "TV mode            ");
  wid.push_back(myTVMode);
  ypos += lineHeight + VGAP;

  // Scanline intensity
  myTVScanIntense = new SliderWidget(this, _font, xpos, ypos-1, swidth, lineHeight,
    "Scanline intensity", lwidth, kScanlinesChanged, fontWidth * 3);
  myTVScanIntense->setMinValue(0); myTVScanIntense->setMaxValue(10);
  myTVScanIntense->setTickmarkIntervals(2);
  wid.push_back(myTVScanIntense);
  ypos += lineHeight + VGAP;

  // TV Phosphor blend level
  myTVPhosLevel = new SliderWidget(this, _font, xpos, ypos-1, swidth, lineHeight,
    "Phosphor blend  ", lwidth, kPhosphorChanged, fontWidth * 3);
  myTVPhosLevel->setMinValue(0); myTVPhosLevel->setMaxValue(10);
  myTVPhosLevel->setTickmarkIntervals(2);
  wid.push_back(myTVPhosLevel);
  ypos += lineHeight + VGAP;

  // FS overscan
  myTVOverscan = new SliderWidget(this, _font, xpos, ypos - 1, swidth, lineHeight,
    "Overscan (*)    ", lwidth, kOverscanChanged, fontWidth * 3);
  myTVOverscan->setMinValue(0); myTVOverscan->setMaxValue(10);
  myTVOverscan->setTickmarkIntervals(2);
  wid.push_back(myTVOverscan);
  ypos += lineHeight + VGAP;

  new StaticTextWidget(this, ifont, xpos, ypos + 1, "(*) Change requires launcher reboot");
  ypos += ifont.getLineHeight() + VGAP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::addGameOptions(WidgetArray& wid, int xpos, int& ypos)
{
  const int lineHeight = Dialog::lineHeight(),
            VGAP       = Dialog::vGap();
  const GUI::Font& ifont = instance().frameBuffer().infoFont();
  VariantList ctrls;

  VarList::push_back(ctrls, "Auto-detect", "AUTO");
  VarList::push_back(ctrls, "Joystick", "JOYSTICK");
  VarList::push_back(ctrls, "Paddles", "PADDLES");
  VarList::push_back(ctrls, "Booster Grip", "BOOSTERGRIP");
  VarList::push_back(ctrls, "Driving", "DRIVING");
  VarList::push_back(ctrls, "Keyboard", "KEYBOARD");
  VarList::push_back(ctrls, "Amiga mouse", "AMIGAMOUSE");
  VarList::push_back(ctrls, "Atari mouse", "ATARIMOUSE");
  VarList::push_back(ctrls, "Trak-Ball", "TRAKBALL");
  VarList::push_back(ctrls, "Sega Genesis", "GENESIS");
  VarList::push_back(ctrls, "Joy2B+", "JOY_2B+"); // TODO: should work, but needs testing with real hardware
  VarList::push_back(ctrls, "QuadTari", "QUADTARI");

  const int pwidth = _font.getStringWidth("Sega Genesis");
  myLeftPortLabel = new StaticTextWidget(this, _font, xpos, ypos + 1, "Left port  ");
  myLeftPort = new PopUpWidget(this, _font, myLeftPortLabel->getRight(),
    myLeftPortLabel->getTop() - 1, pwidth, lineHeight, ctrls, "", 0, kLeftCChanged);
  wid.push_back(myLeftPort);
  ypos += lineHeight + VGAP;

  myLeftPortDetected = new StaticTextWidget(this, ifont, myLeftPort->getLeft(), ypos,
    "Sega Genesis detected");
  ypos += ifont.getLineHeight() + VGAP;

  myRightPortLabel = new StaticTextWidget(this, _font, xpos, ypos + 1, "Right port ");
  myRightPort = new PopUpWidget(this, _font, myRightPortLabel->getRight(),
    myRightPortLabel->getTop() - 1, pwidth, lineHeight, ctrls, "", 0, kRightCChanged);
  wid.push_back(myRightPort);
  ypos += lineHeight + VGAP;
  myRightPortDetected = new StaticTextWidget(this, ifont, myRightPort->getLeft(), ypos,
    "Sega Genesis detected");
  ypos += ifont.getLineHeight() + VGAP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::loadConfig()
{
  const Settings& settings = instance().settings();

  // UI palette
  const string& theme = settings.getString("uipalette");
  myThemePopup->setSelected(theme, "standard");
  // Dialog position
  myPositionPopup->setSelected(settings.getString("dialogpos"), "0");

  // TV Mode
  myTVMode->setSelected(
    settings.getString("tv.filter"), "0");

  // TV scanline intensity
  myTVScanIntense->setValue(valueToLevel(settings.getInt("tv.scanlines")));

  // TV phosphor blend
  myTVPhosLevel->setValue(valueToLevel(settings.getInt(PhosphorHandler::SETTING_BLEND)));

  // TV overscan
  myTVOverscan->setValue(settings.getInt("tia.fs_overscan"));

  handleOverscanChange();

  // Controllers
  if (instance().hasConsole())
  {
    myGameProperties = instance().console().properties();
  }
  else
  {
    const string& md5 = instance().launcher().selectedRomMD5();
    instance().propSet().getMD5(md5, myGameProperties);
  }
  loadControllerProperties(myGameProperties);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::saveConfig()
{
  Settings& settings = instance().settings();

  // UI palette
  settings.setValue("uipalette",
    myThemePopup->getSelectedTag().toString());
  instance().frameBuffer().setUIPalette();
  instance().frameBuffer().update(FrameBuffer::UpdateMode::REDRAW);

  // Dialog position
  settings.setValue("dialogpos", myPositionPopup->getSelectedTag().toString());

  // TV Mode
  instance().settings().setValue("tv.filter",
    myTVMode->getSelectedTag().toString());

  // TV phosphor mode
  instance().settings().setValue(PhosphorHandler::SETTING_MODE,
    myTVPhosLevel->getValue() > 0 ? PhosphorHandler::VALUE_ALWAYS : PhosphorHandler::VALUE_BYROM);
  // TV phosphor blend
  instance().settings().setValue(PhosphorHandler::SETTING_BLEND,
    levelToValue(myTVPhosLevel->getValue()));

  // TV scanline intensity and interpolation
  instance().settings().setValue("tv.scanlines",
    levelToValue(myTVScanIntense->getValue()));

  // TV overscan
  instance().settings().setValue("tia.fs_overscan", myTVOverscan->getValueLabel());

  // Controller properties
  myGameProperties.set(PropType::Controller_Left, myLeftPort->getSelectedTag().toString());
  myGameProperties.set(PropType::Controller_Right, myRightPort->getSelectedTag().toString());

  // Always insert; if the properties are already present, nothing will happen
  instance().propSet().insert(myGameProperties);
  instance().saveConfig();

  // In any event, inform the Console
  if (instance().hasConsole())
  {
    instance().console().setProperties(myGameProperties);
  }

  // Finally, issue a complete framebuffer re-initialization...
  instance().createFrameBuffer();

  // ... and apply potential setting changes to the TIA surface
  instance().frameBuffer().tiaSurface().updateSurfaceSettings();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::setDefaults()
{
  // UI Theme
  myThemePopup->setSelected("standard");
  // Dialog position
  myPositionPopup->setSelected("0");

  // TV effects
  myTVMode->setSelected("RGB", static_cast<uInt32>(NTSCFilter::Preset::RGB));
  // TV scanline intensity
  myTVScanIntense->setValue(3); // 18
  // TV phosphor blend
  myTVPhosLevel->setValue(6); // = 45
  // TV overscan
  myTVOverscan->setValue(0);

  // Load the default game properties
  Properties defaultProperties;
  const string& md5 = myGameProperties.get(PropType::Cart_MD5);

  instance().propSet().getMD5(md5, defaultProperties, true);

  loadControllerProperties(defaultProperties);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::handleCommand(CommandSender* sender, int cmd,
  int data, int id)
{
  switch (cmd)
  {
    case GuiObject::kDefaultsCmd:
      setDefaults();
      break;

    case GuiObject::kOKCmd:
      saveConfig();
      [[fallthrough]];
    case GuiObject::kCloseCmd:
      if (myMode != AppMode::emulator)
        close();
      else
        instance().eventHandler().leaveMenuMode();
      break;

    case kAdvancedSettings:
      switchSettingsMode();
      break;

    case kConfirmSwitchCmd:
      instance().settings().setValue("basic_settings", false);
      if (myMode != AppMode::emulator)
        close();
      else
        instance().eventHandler().leaveMenuMode();
      break;

    case kHelp:
      openHelp();
      break;

    case kScanlinesChanged:
      if(myTVScanIntense->getValue() == 0)
        myTVScanIntense->setValueLabel("Off");
      break;

    case kPhosphorChanged:
      if(myTVPhosLevel->getValue() == 0)
        myTVPhosLevel->setValueLabel("Off");
      break;

    case kOverscanChanged:
      handleOverscanChange();
      break;

    case kLeftCChanged:
    case kRightCChanged:
      updateControllerStates();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::handleOverscanChange()
{
  if (myTVOverscan->getValue() == 0)
  {
    myTVOverscan->setValueLabel("Off");
    myTVOverscan->setValueUnit("");
  }
  else
    myTVOverscan->setValueUnit("%");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::switchSettingsMode()
{
  StringList msg;

  msg.emplace_back("Warning!");
  msg.emplace_back("");
  msg.emplace_back("Advanced settings should be");
  msg.emplace_back("handled with care! When in");
  msg.emplace_back("doubt, read the manual.");
  msg.emplace_back("");
  msg.emplace_back("If you are sure you want to");
  msg.emplace_back("proceed with the switch, click");
  msg.emplace_back("'OK', otherwise click 'Cancel'.");

  myConfirmMsg = make_unique<GUI::MessageBox>(this, _font, msg,
      _w-16, _h, kConfirmSwitchCmd, "OK", "Cancel", "Switch settings mode", false);
  myConfirmMsg->show();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::loadControllerProperties(const Properties& props)
{
  // Determine whether we should enable the "Game settings:"
  // We always enable it in emulation mode, or if a valid ROM is selected
  // in launcher mode
  bool enable = false;

  // Note: The state returned seems not consistent here
  switch (instance().eventHandler().state())
  {
    case EventHandlerState::OPTIONSMENU: // game is running!
    case EventHandlerState::CMDMENU: // game is running!
      enable = true;
      break;
    case EventHandlerState::LAUNCHER:
      enable = !instance().launcher().selectedRomMD5().empty();
      break;
    default:
      break;
  }

  myGameSettings->setEnabled(enable);
  myLeftPort->setEnabled(enable);
  myLeftPortLabel->setEnabled(enable);
  myLeftPortDetected->setEnabled(enable);
  myRightPort->setEnabled(enable);
  myRightPortLabel->setEnabled(enable);
  myRightPortDetected->setEnabled(enable);

  if (enable)
  {
    string controller = props.get(PropType::Controller_Left);
    myLeftPort->setSelected(controller, "AUTO");
    controller = props.get(PropType::Controller_Right);
    myRightPort->setSelected(controller, "AUTO");

    updateControllerStates();
  }
  else
  {
    myLeftPort->clearSelection();
    myRightPort->clearSelection();
    myLeftPortDetected->setLabel("");
    myRightPortDetected->setLabel("");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int StellaSettingsDialog::levelToValue(int level)
{
  static constexpr int NUM_LEVELS = 11;
  static constexpr std::array<uInt8, NUM_LEVELS> values = {
    0, 5, 11, 18, 26, 35, 45, 56, 68, 81, 95
  };

  return values[std::min(level, NUM_LEVELS - 1)];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int StellaSettingsDialog::valueToLevel(int value)
{
  static constexpr int NUM_LEVELS = 11;
  static constexpr std::array<uInt8, NUM_LEVELS> values = {
    0, 5, 11, 18, 26, 35, 45, 56, 68, 81, 95
  };

  for (int i = NUM_LEVELS - 1; i > 0; --i)
  {
    if (value >= values[i])
      return i;
  }
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::openHelp()
{
  // Create an help dialog, similar to the in-game one
  if (myHelpDialog == nullptr)
  #if defined(RETRON77)
    myHelpDialog = make_unique<R77HelpDialog>(instance(), parent(), _font);
  #else
    myHelpDialog = make_unique<HelpDialog>(instance(), parent(), _font);
  #endif
  myHelpDialog->open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaSettingsDialog::updateControllerStates()
{
  bool autoDetect = false;
  ByteBuffer image;
  string md5 = myGameProperties.get(PropType::Cart_MD5);
  size_t size = 0;

  // try to load the image for auto detection
  if(!instance().hasConsole())
  {
    const FSNode& node = FSNode(instance().launcher().selectedRom());

    autoDetect = node.exists() && !node.isDirectory() && (image = instance().openROM(node, md5, size)) != nullptr;
  }
  string label;
  Controller::Type type = Controller::getType(myLeftPort->getSelectedTag().toString());

  if(type == Controller::Type::Unknown)
  {
    if(instance().hasConsole())
      label = (instance().console().leftController().name()) + " detected";
    else if(autoDetect)
      label = ControllerDetector::detectName(image, size, type,
                                             Controller::Jack::Left,
                                             instance().settings()) + " detected";
  }
  myLeftPortDetected->setLabel(label);

  label = "";
  type = Controller::getType(myRightPort->getSelectedTag().toString());

  if(type == Controller::Type::Unknown)
  {
    if(instance().hasConsole())
      label = (instance().console().rightController().name()) + " detected";
    else if(autoDetect)
      label = ControllerDetector::detectName(image, size, type,
                                             Controller::Jack::Right,
                                             instance().settings()) + " detected";
  }
  myRightPortDetected->setLabel(label);

  // Compumate bankswitching scheme doesn't allow to select controllers
  const bool enableSelectControl = myGameProperties.get(PropType::Cart_Type) != "CM";

  myLeftPortLabel->setEnabled(enableSelectControl);
  myRightPortLabel->setEnabled(enableSelectControl);
  myLeftPort->setEnabled(enableSelectControl);
  myRightPort->setEnabled(enableSelectControl);
}

