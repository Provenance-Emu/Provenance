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
#include "FrameBuffer.hxx"
#include "RadioButtonWidget.hxx"
#include "TIASurface.hxx"

#include "EmulationDialog.hxx"

namespace {
  // Emulation speed is a positive float that multiplies the framerate. However,
  // the UI controls adjust speed in terms of a speedup factor (1/10,
  // 1/9 .. 1/2, 1, 2, 3, .., 10). The following mapping and formatting
  // functions implement this conversion. The speedup factor is represented
  // by an integer value between -900 and 900 (0 means no speedup).

  constexpr int MAX_SPEED = 900;
  constexpr int MIN_SPEED = -900;
  constexpr int SPEED_STEP = 10;

  int mapSpeed(float speed)
  {
    speed = std::abs(speed);

    return BSPF::clamp(
      static_cast<int>(round(100 * (speed >= 1 ? speed - 1 : -1 / speed + 1))),
      MIN_SPEED, MAX_SPEED
    );
  }

  constexpr float unmapSpeed(int speed)
  {
    const float f_speed = static_cast<float>(speed) / 100;

    return speed < 0 ? -1 / (f_speed - 1) : 1 + f_speed;
  }

  string formatSpeed(int speed) {
    stringstream ss;

    ss
      << std::setw(3) << std::fixed << std::setprecision(0)
      << (unmapSpeed(speed) * 100);

    return ss.str();
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationDialog::EmulationDialog(OSystem& osystem, DialogContainer& parent,
                                 const GUI::Font& font, int max_w, int max_h)
  : Dialog(osystem, parent, font, "Emulation settings")
{
  const int lineHeight   = Dialog::lineHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap(),
            INDENT       = Dialog::indent();
  const int lwidth = font.getStringWidth("Emulation speed ");
  WidgetArray wid;
  const int swidth = fontWidth * 10;

  // Set real dimensions
  _w = 37 * fontWidth + HBORDER * 2 + CheckboxWidget::prefixSize(_font);
  _h = 13 * (lineHeight + VGAP) + VGAP * 7 + VBORDER * 3 + _th + buttonHeight;

  int xpos = HBORDER, ypos = VBORDER + _th;

  // Speed
  mySpeed =
    new SliderWidget(this, _font, xpos, ypos-1, swidth, lineHeight,
                     "Emulation speed ", lwidth, kSpeedupChanged, fontWidth * 5, "%");
  mySpeed->setMinValue(MIN_SPEED); mySpeed->setMaxValue(MAX_SPEED);
  mySpeed->setStepValue(SPEED_STEP);
  mySpeed->setTickmarkIntervals(2);
  mySpeed->setToolTip(Event::DecreaseSpeed, Event::IncreaseSpeed);
  wid.push_back(mySpeed);
  ypos += lineHeight + VGAP;

  // Use sync to vblank
  myUseVSync = new CheckboxWidget(this, _font, xpos, ypos + 1, "VSync");
  myUseVSync->setToolTip("Check to enable vertical synced display updates.");
  wid.push_back(myUseVSync);
  ypos += lineHeight + VGAP;


  myTurbo = new CheckboxWidget(this, _font, xpos, ypos + 1, "Turbo mode");
  myTurbo->setToolTip(Event::ToggleTurbo);
  wid.push_back(myTurbo);
  ypos += lineHeight + VGAP * 3;

  // Use multi-threading
  myUseThreads = new CheckboxWidget(this, _font, xpos, ypos + 1, "Multi-threading");
  wid.push_back(myUseThreads);
  ypos += lineHeight + VGAP;

  // Skip progress load bars for SuperCharger ROMs
  // Doesn't really belong here, but I couldn't find a better place for it
  myFastSCBios = new CheckboxWidget(this, _font, xpos, ypos + 1, "Fast SuperCharger load");
  wid.push_back(myFastSCBios);
  ypos += lineHeight + VGAP;

  // Show UI messages onscreen
  myUIMessages = new CheckboxWidget(this, _font, xpos, ypos + 1, "Show UI messages");
  wid.push_back(myUIMessages);
  ypos += lineHeight + VGAP;

  // Automatically pause emulation when focus is lost
  xpos = HBORDER; ypos += VGAP * 3;
  myAutoPauseWidget = new CheckboxWidget(this, _font, xpos, ypos, "Automatic pause");
  myAutoPauseWidget->setToolTip("Check for automatic pause/continue of\nemulation when Stella loses/gains focus.");
  wid.push_back(myAutoPauseWidget);

  // Confirm dialog when exiting emulation
  ypos += lineHeight + VGAP;
  myConfirmExitWidget = new CheckboxWidget(this, _font, xpos, ypos, "Confirm exiting emulation");
  wid.push_back(myConfirmExitWidget);

  xpos = HBORDER + INDENT;
  ypos += lineHeight + VGAP * 3;
  new StaticTextWidget(this, font, HBORDER, ypos + 1,
                       "When entering/exiting emulation:");
  ypos += lineHeight + VGAP;
  mySaveOnExitGroup = new RadioButtonGroup();
  auto* r = new RadioButtonWidget(this, font, xpos, ypos + 1,
                                  "Do nothing", mySaveOnExitGroup);
  wid.push_back(r);
  ypos += lineHeight + VGAP;
  r = new RadioButtonWidget(this, font, xpos, ypos + 1,
                            "Save current state in current slot", mySaveOnExitGroup);
  wid.push_back(r);
  ypos += lineHeight + VGAP;
  r = new RadioButtonWidget(this, font, xpos, ypos + 1,
                            "Load/save all Time Machine states", mySaveOnExitGroup);
  wid.push_back(r);
  ypos += lineHeight + VGAP;
  xpos = HBORDER;


  myAutoSlotWidget = new CheckboxWidget(this, font, xpos, ypos + 1, "Automatically change save state slots");
  myAutoSlotWidget->setToolTip("Cycle to next state slot after saving.", Event::ToggleAutoSlot);
  wid.push_back(myAutoSlotWidget);

  // Add Defaults, OK and Cancel buttons
  addDefaultsOKCancelBGroup(wid, font);

  addToFocusList(wid);

  setHelpAnchor("Emulation");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationDialog::loadConfig()
{
  const Settings& settings = instance().settings();

  // Emulation speed
  const int speed = mapSpeed(settings.getFloat("speed"));
  mySpeed->setValue(speed);
  mySpeed->setValueLabel(formatSpeed(speed));

  // Use sync to vertical blank
  myUseVSync->setState(settings.getBool("vsync"));

  // Enable 'Turbo' mode
  myTurbo->setState(settings.getBool("turbo"));

  // Show UI messages
  myUIMessages->setState(settings.getBool("uimessages"));

  // Fast loading of Supercharger BIOS
  myFastSCBios->setState(settings.getBool("fastscbios"));

  // Multi-threaded rendering
  myUseThreads->setState(settings.getBool("threads"));

  // Automatically pause emulation when focus is lost
  myAutoPauseWidget->setState(settings.getBool("autopause"));

  // Confirm dialog when exiting emulation
  myConfirmExitWidget->setState(settings.getBool("confirmexit"));

  // Save on exit
  const string saveOnExit = settings.getString("saveonexit");
  mySaveOnExitGroup->setSelected(saveOnExit == "all" ? 2 : saveOnExit == "current" ? 1 : 0);
  // Automatically change save state slots
  myAutoSlotWidget->setState(settings.getBool("autoslot"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationDialog::saveConfig()
{
  Settings& settings = instance().settings();

  // Speed
  const int speedup = mySpeed->getValue();
  settings.setValue("speed", unmapSpeed(speedup));
  if(instance().hasConsole())
    instance().console().initializeAudio();

  // Use sync to vertical blank
  settings.setValue("vsync", myUseVSync->getState());

  // Enable 'Turbo' mode
  settings.setValue("turbo", myTurbo->getState());

  // Show UI messages
  settings.setValue("uimessages", myUIMessages->getState());

  // Fast loading of Supercharger BIOS
  settings.setValue("fastscbios", myFastSCBios->getState());

  // Multi-threaded rendering
  settings.setValue("threads", myUseThreads->getState());

  // Automatically pause emulation when focus is lost
  settings.setValue("autopause", myAutoPauseWidget->getState());

  // Confirm dialog when exiting emulation
  settings.setValue("confirmexit", myConfirmExitWidget->getState());

  // Save on exit
  const int saveOnExit = mySaveOnExitGroup->getSelected();
  settings.setValue("saveonexit",
                    saveOnExit == 0 ? "none" : saveOnExit == 1 ? "current" : "all");
  // Automatically change save state slots
  settings.setValue("autoslot", myAutoSlotWidget->getState());

  if(instance().hasConsole())
  {
    // update speed
    instance().console().initializeAudio();
    // update VSync
    instance().console().initializeVideo();
    instance().createFrameBuffer();

    instance().frameBuffer().tiaSurface().ntsc().enableThreading(myUseThreads->getState());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationDialog::setDefaults()
{
  // speed
  mySpeed->setValue(0);
  myUseVSync->setState(true);
  // misc
  myUIMessages->setState(true);
  myFastSCBios->setState(true);
  myUseThreads->setState(false);
  myAutoPauseWidget->setState(false);
  myConfirmExitWidget->setState(false);

  mySaveOnExitGroup->setSelected(0);
  myAutoSlotWidget->setState(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationDialog::handleCommand(CommandSender* sender, int cmd,
                                    int data, int id)
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

    case kSpeedupChanged:
      mySpeed->setValueLabel(formatSpeed(mySpeed->getValue()));
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
      break;
  }
}
