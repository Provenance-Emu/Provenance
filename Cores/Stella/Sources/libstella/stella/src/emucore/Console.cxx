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

#include "AtariVox.hxx"
#include "Booster.hxx"
#include "Cart.hxx"
#include "Control.hxx"
#include "CartCM.hxx"
#include "Driving.hxx"
#include "EventHandler.hxx"
#include "ControllerDetector.hxx"
#include "Joystick.hxx"
#include "Keyboard.hxx"
#include "KidVid.hxx"
#include "Genesis.hxx"
#include "MindLink.hxx"
#include "CompuMate.hxx"
#include "AmigaMouse.hxx"
#include "AtariMouse.hxx"
#include "TrakBall.hxx"
#include "Lightgun.hxx"
#include "QuadTari.hxx"
#include "Joy2BPlus.hxx"
#include "M6502.hxx"
#include "M6532.hxx"
#include "TIA.hxx"
#include "Paddles.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "SaveKey.hxx"
#include "Settings.hxx"
#include "Sound.hxx"
#include "StateManager.hxx"
#include "Switches.hxx"
#include "System.hxx"
#include "FrameBuffer.hxx"
#include "TIASurface.hxx"
#include "OSystem.hxx"
#include "Serializer.hxx"
#include "TimerManager.hxx"
#include "Version.hxx"
#include "TIAConstants.hxx"
#include "FrameLayout.hxx"
#include "AudioQueue.hxx"
#include "AudioSettings.hxx"
#include "DevSettingsHandler.hxx"
#include "frame-manager/FrameManager.hxx"
#include "frame-manager/FrameLayoutDetector.hxx"

#ifdef CHEATCODE_SUPPORT
  #include "CheatManager.hxx"
#endif
#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
#endif

#include "Console.hxx"

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
Console::Console(OSystem& osystem, unique_ptr<Cartridge>& cart,
                 const Properties& props, AudioSettings& audioSettings)
  : myOSystem{osystem},
    myEvent{osystem.eventHandler().event()},
    myProperties{props},
    myCart{std::move(cart)},
    myAudioSettings{audioSettings}
{
  // Create subsystems for the console
  my6502 = make_unique<M6502>(myOSystem.settings());
  myRiot = make_unique<M6532>(*this, myOSystem.settings());

  const TIA::onPhosphorCallback callback = [&frameBuffer = this->myOSystem.frameBuffer()](bool enable)
  {
    frameBuffer.tiaSurface().enablePhosphor(enable);
#ifdef DEBUG_BUILD
    ostringstream msg;
    msg << "Phosphor effect automatically " << (enable ? "enabled" : "disabled");
    frameBuffer.showTextMessage(msg.str());
#endif
  };
  myTIA  = make_unique<TIA>(*this, [this]() { return timing(); }, myOSystem.settings(), callback);
  myFrameManager = make_unique<FrameManager>();
  mySwitches = make_unique<Switches>(myEvent, myProperties, myOSystem.settings());

  myTIA->setFrameManager(myFrameManager.get());
  myOSystem.sound().stopWav();

  // Reinitialize the RNG
  myOSystem.random().initSeed(static_cast<uInt32>(TimerManager::getTicks()));

  // Construct the system and components
  mySystem = make_unique<System>(myOSystem.random(), *my6502, *myRiot, *myTIA, *myCart);

  // The real controllers for this console will be added later
  // For now, we just add dummy joystick controllers, since autodetection
  // runs the emulation for a while, and this may interfere with 'smart'
  // controllers such as the AVox and SaveKey
  myLeftControl  = make_unique<Joystick>(Controller::Jack::Left, myEvent, *mySystem);
  myRightControl = make_unique<Joystick>(Controller::Jack::Right, myEvent, *mySystem);

  // Let the cart know how to query for the 'Cartridge.StartBank' property
  myCart->setStartBankFromPropsFunc([this]() {
    const string_view startbank = myProperties.get(PropType::Cart_StartBank);
    return (startbank == EmptyString || BSPF::equalsIgnoreCase(startbank, "AUTO"))
        ? -1 : BSPF::stoi(startbank);
  });

  // We can only initialize after all the devices/components have been created
  mySystem->initialize();

  // Create developer/player settings handler (handles switching sets)
  myDevSettingsHandler = make_unique<DevSettingsHandler>(myOSystem);

  // Auto-detect NTSC/PAL mode if it's requested
  string autodetected;
  myDisplayFormat = myProperties.get(PropType::Display_Format);

  if (myDisplayFormat == "AUTO")
    myDisplayFormat = formatFromFilename();

  // Add the real controllers for this system
  // This must be done before the debugger is initialized
  setControllers(myProperties.get(PropType::Cart_MD5));

  // Pause audio and clear framebuffer while autodetection runs
  myOSystem.sound().pause(true);
  myOSystem.frameBuffer().clear();

  if(myDisplayFormat == "AUTO" || myOSystem.settings().getBool("rominfo"))
  {
    autodetectFrameLayout();

    if(myProperties.get(PropType::Display_Format) == "AUTO")
    {
      autodetected = "*";
      myCurrentFormat = 0;
      myFormatAutodetected = true;
    }
  }

  myConsoleInfo.DisplayFormat = myDisplayFormat + autodetected;

  // Set up the correct properties used when toggling format
  // Note that this can be overridden if a format is forced
  //   For example, if a PAL ROM is forced to be NTSC, it will use NTSC-like
  //   properties (60Hz, 262 scanlines, etc), but likely result in flicker
  if(myDisplayFormat == "NTSC")
  {
    myCurrentFormat = 1;
  }
  else if(myDisplayFormat == "PAL")
  {
    myCurrentFormat = 2;
  }
  else if(myDisplayFormat == "SECAM")
  {
    myCurrentFormat = 3;
  }
  else if(myDisplayFormat == "NTSC50")
  {
    myCurrentFormat = 4;
  }
  else if(myDisplayFormat == "PAL60")
  {
    myCurrentFormat = 5;
  }
  else if(myDisplayFormat == "SECAM60")
  {
    myCurrentFormat = 6;
  }
  setConsoleTiming();

  setTIAProperties();

  const bool joyallow4 = myOSystem.settings().getBool("joyallow4");
  myOSystem.eventHandler().allowAllDirections(joyallow4);

  // Reset the system to its power-on state
  mySystem->reset();
  myRiot->update();

  // Finally, add remaining info about the console
  myConsoleInfo.CartName   = myProperties.get(PropType::Cart_Name);
  myConsoleInfo.CartMD5    = myProperties.get(PropType::Cart_MD5);
  const bool swappedPorts  = properties().get(PropType::Console_SwapPorts) == "YES";
  myConsoleInfo.Control0   = myLeftControl->about(swappedPorts);
  myConsoleInfo.Control1   = myRightControl->about(swappedPorts);
  myConsoleInfo.BankSwitch = myCart->about();

  // Some carts have an associated nvram file
  myCart->setNVRamFile(myOSystem.nvramDir().getPath() + myConsoleInfo.CartName);

  // Let the other devices know about the new console
  mySystem->consoleChanged(myConsoleTiming);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Console::~Console()
{
  // Some smart controllers need to be informed that the console is going away
  myLeftControl->close();
  myRightControl->close();

  // Close audio to prevent invalid access in the audio callback
  if(myAudioQueue)
  {
    myAudioQueue->closeSink(nullptr);  // TODO: is this needed?
    myAudioQueue.reset();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::setConsoleTiming()
{
  if (myDisplayFormat == "NTSC" || myDisplayFormat == "NTSC50")
  {
    myConsoleTiming = ConsoleTiming::ntsc;
  }
  else if (myDisplayFormat == "PAL" || myDisplayFormat == "PAL60")
  {
    myConsoleTiming = ConsoleTiming::pal;
  }
  else if (myDisplayFormat == "SECAM" || myDisplayFormat == "SECAM60")
  {
    myConsoleTiming = ConsoleTiming::secam;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::autodetectFrameLayout(bool reset)
{
  // Run the TIA, looking for PAL scanline patterns
  // We turn off the SuperCharger progress bars, otherwise the SC BIOS
  // will take over 250 frames!
  // The 'fastscbios' option must be changed before the system is reset
  Settings& settings = myOSystem.settings();
  const bool fastscbios = settings.getBool("fastscbios");
  settings.setValue("fastscbios", true);

  FrameLayoutDetector frameLayoutDetector;
  myTIA->setFrameManager(&frameLayoutDetector, true);

  if (reset) {
    mySystem->reset(true);
    myRiot->update();
  }

  // Sample colors, ratio is 1/5 title (if existing), 4/5 game screen.
  for(int i = 0; i < 20; ++i)
    myTIA->update();

  FrameLayoutDetector::simulateInput(*myRiot, myOSystem.eventHandler(), true);
  myTIA->update();
  FrameLayoutDetector::simulateInput(*myRiot, myOSystem.eventHandler(), false);

  for(int i = 0; i < 40; ++i)
    myTIA->update();

  switch(frameLayoutDetector.detectedLayout(
    settings.getBool("detectpal60"), settings.getBool("detectntsc50"),
    myProperties.get(PropType::Cart_Name)))
  {
    case FrameLayout::pal:
      myDisplayFormat = "PAL";
      break;

    case FrameLayout::pal60:
      myDisplayFormat = "PAL60";
      break;

    case FrameLayout::ntsc50:
      myDisplayFormat = "NTSC50";
      break;

    default:
      myDisplayFormat = "NTSC";
      break;
  }

  myTIA->setFrameManager(myFrameManager.get());

  // Don't forget to reset the SC progress bars again
  settings.setValue("fastscbios", fastscbios);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::redetectFrameLayout()
{
  Serializer s;

  save(s);
  autodetectFrameLayout(false);
  load(s);

  initializeAudio();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Console::formatFromFilename() const
{
  static const BSPF::array2D<string, 8, 2> Pattern = {{
    { R"([ _\-(\[<]+NTSC[ _-]?50)",          "NTSC50"  },
    { R"([ _\-(\[<]+PAL[ _-]?N[ _\-)\]>.])", "NTSC50"  }, // PAL-N == NTSC50
    { R"([ _\-(\[<]+PAL[ _-]?60)",           "PAL60"   },
    { R"([ _\-(\[<]+SECAM[ _-]?60)",         "SECAM60" },
    { R"([ _\-(\[<]+NTSC[ _\-)\]>.])",       "NTSC"    },
    { R"([ _\-(\[<]+PAL[ _-]?M[ _\-)\]>.])", "NTSC"    }, // PAL-M == NTSC
    { R"([ _\-(\[<]+PAL[ _\-)\]>.])",        "PAL"     },
    { R"([ _\-(\[<]+SECAM[ _\-)\]>.])",      "SECAM"   }
  }};

  // Get filename, and search using regex's above
  const string_view filename = myOSystem.romFile().getName();
  for(const auto& pat: Pattern)
  {
    try
    {
      const std::regex rgx(pat[0], std::regex_constants::icase);
      if(std::regex_search(filename.cbegin(), filename.cend(), rgx))
        return pat[1];
    }
    catch(...)
    {
      continue;
    }
  }

  // Nothing found
  return "AUTO";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Console::save(Serializer& out) const
{
  try
  {
    // First save state for the system
    if(!mySystem->save(out))
      return false;

    // Now save the console controllers and switches
    if(!(myLeftControl->save(out) && myRightControl->save(out) &&
         mySwitches->save(out)))
      return false;
  }
  catch(...)
  {
    cerr << "ERROR: Console::save\n";
    return false;
  }

  return true;  // success
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Console::load(Serializer& in)
{
  try
  {
    // First load state for the system
    if(!mySystem->load(in))
      return false;

    // Then load the console controllers and switches
    if(!(myLeftControl->load(in) && myRightControl->load(in) &&
         mySwitches->load(in)))
      return false;
  }
  catch(...)
  {
    cerr << "ERROR: Console::load\n";
    return false;
  }

  return true;  // success
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::selectFormat(int direction)
{
  Int32 format = myCurrentFormat;

  format = BSPF::clampw(format + direction, 0, 6);

  setFormat(format, true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::setFormat(uInt32 format, bool force)
{
  if(!force && myCurrentFormat == format)
    return;

  string saveformat, message, autodetected;

  myCurrentFormat = format;
  switch(myCurrentFormat)
  {
    case 0:  // auto-detect
    {
      if (!force && myFormatAutodetected) return;

      myDisplayFormat = formatFromFilename();
      if (myDisplayFormat == "AUTO")
      {
        redetectFrameLayout();
        myFormatAutodetected = true;
        autodetected = "*";
        message = "Auto-detect mode: " + myDisplayFormat;
      }
      else
      {
        message = myDisplayFormat + " mode";
      }
      saveformat = "AUTO";
      setConsoleTiming();
      break;
    }
    case 1:
      saveformat = myDisplayFormat = "NTSC";
      myConsoleTiming = ConsoleTiming::ntsc;
      message = "NTSC mode";
      myFormatAutodetected = false;
      break;
    case 2:
      saveformat = myDisplayFormat = "PAL";
      myConsoleTiming = ConsoleTiming::pal;
      message = "PAL mode";
      myFormatAutodetected = false;
      break;
    case 3:
      saveformat = myDisplayFormat = "SECAM";
      myConsoleTiming = ConsoleTiming::secam;
      message = "SECAM mode";
      myFormatAutodetected = false;
      break;
    case 4:
      saveformat = myDisplayFormat = "NTSC50";
      myConsoleTiming = ConsoleTiming::ntsc;
      message = "NTSC50 mode";
      myFormatAutodetected = false;
      break;
    case 5:
      saveformat = myDisplayFormat = "PAL60";
      myConsoleTiming = ConsoleTiming::pal;
      message = "PAL60 mode";
      myFormatAutodetected = false;
      break;
    case 6:
      saveformat = myDisplayFormat = "SECAM60";
      myConsoleTiming = ConsoleTiming::secam;
      message = "SECAM60 mode";
      myFormatAutodetected = false;
      break;
    default:  // satisfy compiler
      break;
  }
  myProperties.set(PropType::Display_Format, saveformat);

  myConsoleInfo.DisplayFormat = myDisplayFormat + autodetected;

  setTIAProperties();
  if(myOSystem.eventHandler().inTIAMode())
  {
    initializeVideo();    // takes care of refreshing the screen
    initializeAudio();    // ensure that audio synthesis is set up to match emulation rate
    myOSystem.resetFps(); // Reset FPS measurement

    enableColorLoss(myOSystem.settings().getBool(
      myOSystem.settings().getBool("dev.settings") ? "dev.colorloss" : "plr.colorloss"));

    myOSystem.frameBuffer().showTextMessage(message);
  }

  // Let the other devices know about the console change
  mySystem->consoleChanged(myConsoleTiming);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleColorLoss(bool toggle)
{
  bool colorloss = myTIA->colorLossEnabled();
  if(toggle)
  {
    colorloss = !colorloss;
    if(myTIA->enableColorLoss(colorloss))
      myOSystem.settings().setValue(
        myOSystem.settings().getBool("dev.settings") ? "dev.colorloss" : "plr.colorloss", colorloss);
    else {
      myOSystem.frameBuffer().showTextMessage(
        "PAL color-loss not available in non PAL modes");
      return;
    }
  }
  const string message = string("PAL color-loss ") + (colorloss ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::enableColorLoss(bool state)
{
  myTIA->enableColorLoss(state);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleInter(bool toggle)
{
  if(myOSystem.settings().getString("video") != "software")
  {
    bool enabled = myOSystem.settings().getBool("tia.inter");

    if(toggle)
    {
      enabled = !enabled;

      myOSystem.settings().setValue("tia.inter", enabled);

      // Apply potential setting changes to the TIA surface
      myOSystem.frameBuffer().tiaSurface().updateSurfaceSettings();
    }
    ostringstream ss;

    ss << "Interpolation " << (enabled ? "enabled" : "disabled");
    myOSystem.frameBuffer().showTextMessage(ss.str());
  }
  else
    myOSystem.frameBuffer().showTextMessage(
      "Interpolation not available for Software renderer");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleTurbo()
{
  const bool enabled = myOSystem.settings().getBool("turbo");

  myOSystem.settings().setValue("turbo", !enabled);

  // update rate
  initializeAudio();

  // update VSync
  initializeVideo();

  ostringstream ss;
  ss << "Turbo mode " << (!enabled ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(ss.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeSpeed(int direction)
{
  int speed = mapSpeed(myOSystem.settings().getFloat("speed"));
  const bool turbo = myOSystem.settings().getBool("turbo");

  speed = BSPF::clamp(speed + direction * SPEED_STEP, MIN_SPEED, MAX_SPEED);
  myOSystem.settings().setValue("speed", unmapSpeed(speed));

  // update rate
  initializeAudio();

  if(turbo)
  {
    myOSystem.settings().setValue("turbo", false);
    // update VSync
    initializeVideo();
  }

  ostringstream val;

  val << formatSpeed(speed) << "%";
  myOSystem.frameBuffer().showGaugeMessage("Emulation speed", val.str(), speed, MIN_SPEED, MAX_SPEED);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::togglePhosphor(bool toggle)
{
  bool enable = myOSystem.frameBuffer().tiaSurface().phosphorEnabled();

  if(toggle)
  {
    enable = !enable;
    if(!enable)
      myProperties.set(PropType::Display_Phosphor, "NO");
    else
      myProperties.set(PropType::Display_Phosphor, "YES");
    myOSystem.frameBuffer().tiaSurface().enablePhosphor(enable);

    // disable auto-phosphor
    myTIA->enableAutoPhosphor(false);
  }

  ostringstream msg;
  msg << "Phosphor effect " << (enable ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::cyclePhosphorMode(int direction)
{
  static constexpr std::array<string_view, PhosphorHandler::NumTypes> MESSAGES = {
    "by ROM", "always on", "auto-enabled", "auto-enabled/disabled"
  };
  PhosphorHandler::PhosphorMode mode =
    PhosphorHandler::toPhosphorMode(myOSystem.settings().getString(PhosphorHandler::SETTING_MODE));

  if(direction)
  {
    mode = static_cast<PhosphorHandler::PhosphorMode>
      (BSPF::clampw(mode + direction, 0, static_cast<int>(PhosphorHandler::NumTypes - 1)));
    switch(mode)
    {
      case PhosphorHandler::Always:
        myOSystem.frameBuffer().tiaSurface().enablePhosphor(
          true, myOSystem.settings().getInt(PhosphorHandler::SETTING_BLEND));
        myTIA->enableAutoPhosphor(false);
        break;

      case PhosphorHandler::Auto_on:
      case PhosphorHandler::Auto:
        myOSystem.frameBuffer().tiaSurface().enablePhosphor(
          false, myOSystem.settings().getInt(PhosphorHandler::SETTING_BLEND));
        myTIA->enableAutoPhosphor(true, mode == PhosphorHandler::Auto_on);
        break;

      default: // PhosphorHandler::ByRom
        myOSystem.frameBuffer().tiaSurface().enablePhosphor(
          myProperties.get(PropType::Display_Phosphor) == "YES",
          BSPF::stoi(myProperties.get(PropType::Display_PPBlend)));
        myTIA->enableAutoPhosphor(false);
        break;
    }
    myOSystem.settings().setValue(PhosphorHandler::SETTING_MODE,
                                  PhosphorHandler::toPhosphorName(mode));
  }
  ostringstream msg;
  msg << "Phosphor mode " << MESSAGES[mode];
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changePhosphor(int direction)
{
  int blend = BSPF::stoi(myProperties.get(PropType::Display_PPBlend));

  if(direction)
  {
    blend = BSPF::clamp(blend + direction * 2, 0, 100);
    myOSystem.frameBuffer().tiaSurface().enablePhosphor(true, blend);
  }

  ostringstream val;
  val << blend;
  myProperties.set(PropType::Display_PPBlend, val.str());
  if(blend)
    val << "%";
  else
  {
    val.str("");
    val << "Off";
  }
  myOSystem.frameBuffer().showGaugeMessage("Phosphor blend", val.str(), blend);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::setProperties(const Properties& props)
{
  myProperties = props;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBInitStatus Console::initializeVideo(bool full)
{
  FBInitStatus fbstatus = FBInitStatus::Success;

  if(full)
  {
    auto size = myOSystem.settings().getBool("tia.correct_aspect") ?
      Common::Size(TIAConstants::viewableWidth, TIAConstants::viewableHeight) :
      Common::Size(2 * myTIA->width(), myTIA->height());

    const bool devSettings = myOSystem.settings().getBool("dev.settings");
    const string title = string{"Stella "} + STELLA_VERSION +
                   ": \"" + myProperties.get(PropType::Cart_Name) + "\"";
    fbstatus = myOSystem.frameBuffer().createDisplay(title,
        BufferType::Emulator, size, false);
    if(fbstatus != FBInitStatus::Success)
      return fbstatus;

    myOSystem.frameBuffer().showFrameStats(
      myOSystem.settings().getBool(devSettings ? "dev.stats" : "plr.stats"));
  }
  return fbstatus;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::initializeAudio()
{
  myEmulationTiming
    .updatePlaybackRate(myAudioSettings.sampleRate())
    .updatePlaybackPeriod(myAudioSettings.fragmentSize())
    .updateAudioQueueExtraFragments(myAudioSettings.bufferSize())
    .updateAudioQueueHeadroom(myAudioSettings.headroom())
    .updateSpeedFactor(myOSystem.settings().getBool("turbo")
      ? 50.0F
      : myOSystem.settings().getFloat("speed"));

  createAudioQueue();
  myTIA->setAudioQueue(myAudioQueue);
  myTIA->setAudioRewindMode(myOSystem.state().mode() != StateManager::Mode::Off);

  myOSystem.sound().open(myAudioQueue, &myEmulationTiming);
}

/* Original frying research and code by Fred Quimby.
   I've tried the following variations on this code:
   - Both OR and Exclusive OR instead of AND. This generally crashes the game
     without ever giving us realistic "fried" effects.
   - Loop only over the RIOT RAM. This still gave us frying-like effects, but
     it seemed harder to duplicate most effects. I have no idea why, but
     munging the TIA regs seems to have some effect (I'd think it wouldn't).

   Fred says he also tried mangling the PC and registers, but usually it'd just
   crash the game (e.g. black screen, no way out of it).

   It's definitely easier to get some effects (e.g. 255 lives in Battlezone)
   with this code than it is on a real console. My guess is that most "good"
   frying effects come from a RIOT location getting cleared to 0. Fred's
   code is more likely to accomplish this than frying a real console is...

   Until someone comes up with a more accurate way to emulate frying, I'm
   leaving this as Fred posted it.   -- B.
*/
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::fry() const
{
  for(int i = 0; i < 0x100; i += mySystem->randGenerator().next() % 4)
    mySystem->poke(i, mySystem->peek(i) & mySystem->randGenerator().next());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeVerticalCenter(int direction)
{
  Int32 vcenter = myTIA->vcenter();

  vcenter = BSPF::clamp(vcenter + direction, myTIA->minVcenter(), myTIA->maxVcenter());

  ostringstream ss, val;
  ss << vcenter;

  myProperties.set(PropType::Display_VCenter, ss.str());
  if (vcenter != myTIA->vcenter()) myTIA->setVcenter(vcenter);

  val << (vcenter ? vcenter > 0 ? "+" : "" : " ") << vcenter << "px";
  myOSystem.frameBuffer().showGaugeMessage("V-Center", val.str(), vcenter,
                                      myTIA->minVcenter(), myTIA->maxVcenter());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::updateVcenter(Int32 vcenter)
{
  if ((vcenter > TIAConstants::maxVcenter) || (vcenter < TIAConstants::minVcenter))
    return;

  if (vcenter != myTIA->vcenter()) myTIA->setVcenter(vcenter);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeVSizeAdjust(int direction)
{
  Int32 newAdjustVSize = myTIA->adjustVSize();

  newAdjustVSize = BSPF::clamp(newAdjustVSize + direction, -5, 5);

  if (newAdjustVSize != myTIA->adjustVSize()) {
      myTIA->setAdjustVSize(newAdjustVSize);
      myOSystem.settings().setValue("tia.vsizeadjust", newAdjustVSize);
      initializeVideo();
  }

  ostringstream val;

  val << (newAdjustVSize ? newAdjustVSize > 0 ? "+" : "" : " ")
      << newAdjustVSize << "%";
  myOSystem.frameBuffer().showGaugeMessage("V-Size", val.str(), newAdjustVSize, -5, 5);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleCorrectAspectRatio(bool toggle)
{
  bool enabled = myOSystem.settings().getBool("tia.correct_aspect");

  if(toggle)
  {
    enabled = !enabled;
    myOSystem.settings().setValue("tia.correct_aspect", enabled);
    initializeVideo();
  }
  const string& message = string("Correct aspect ratio ") +
      (enabled ? "enabled" : "disabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::setTIAProperties()
{
  const Int32 vcenter = BSPF::clamp(
    static_cast<Int32>(BSPF::stoi(myProperties.get(PropType::Display_VCenter))), TIAConstants::minVcenter, TIAConstants::maxVcenter
  );

  if(gameRefreshRate() == 60)
  {
    // Assume we've got ~262 scanlines (NTSC-like format)
    myTIA->setLayout(FrameLayout::ntsc);
  }
  else
  {
    // Assume we've got ~312 scanlines (PAL-like format)
    myTIA->setLayout(FrameLayout::pal);
  }

  myTIA->setAdjustVSize(myOSystem.settings().getInt("tia.vsizeadjust"));
  myTIA->setVcenter(vcenter);

  myEmulationTiming.updateFrameLayout(myTIA->frameLayout());
  myEmulationTiming.updateConsoleTiming(myConsoleTiming);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::createAudioQueue()
{
  const bool useStereo = myOSystem.settings().getBool(AudioSettings::SETTING_STEREO)
    || myProperties.get(PropType::Cart_Sound) == "STEREO";

  myAudioQueue = make_shared<AudioQueue>(
    myEmulationTiming.audioFragmentSize(),
    myEmulationTiming.audioQueueCapacity(),
    useStereo
  );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::setControllers(string_view romMd5)
{
  // Check for CompuMate scheme; it is special in that a handler creates both
  // controllers for us, and associates them with the bankswitching class
  if(myCart->detectedType() == "CM")
  {
    myCMHandler = make_shared<CompuMate>(*this, myEvent, *mySystem);

    // A somewhat ugly bit of code that casts to CartridgeCM to
    // add the CompuMate, and then back again for the actual
    // Cartridge
    unique_ptr<CartridgeCM> cartcm(static_cast<CartridgeCM*>(myCart.release()));
    cartcm->setCompuMate(myCMHandler);
    myCart = std::move(cartcm);

    myLeftControl  = std::move(myCMHandler->leftController());
    myRightControl = std::move(myCMHandler->rightController());
    myOSystem.eventHandler().defineKeyControllerMappings(
        Controller::Type::CompuMate, Controller::Jack::Left, myProperties);
    myOSystem.eventHandler().defineJoyControllerMappings(
        Controller::Type::CompuMate, Controller::Jack::Left, myProperties);
  }
  else
  {
    // Setup the controllers based on properties
    Controller::Type leftType =
        Controller::getType(myProperties.get(PropType::Controller_Left));
    Controller::Type rightType =
        Controller::getType(myProperties.get(PropType::Controller_Right));
    size_t size = 0;
    const ByteBuffer& image = myCart->getImage(size);
    const bool swappedPorts =
        myProperties.get(PropType::Console_SwapPorts) == "YES";

    // Try to detect controllers
    if(image != nullptr && size != 0)
    {
      Logger::debug(myProperties.get(PropType::Cart_Name) + ":");
      leftType = ControllerDetector::detectType(image, size, leftType,
          !swappedPorts ? Controller::Jack::Left : Controller::Jack::Right, myOSystem.settings());
      rightType = ControllerDetector::detectType(image, size, rightType,
          !swappedPorts ? Controller::Jack::Right : Controller::Jack::Left, myOSystem.settings());
    }

    unique_ptr<Controller>
      leftC = getControllerPort(leftType, Controller::Jack::Left, romMd5),
      rightC = getControllerPort(rightType, Controller::Jack::Right, romMd5);

    // Swap the ports if necessary
    if(!swappedPorts)
    {
      myLeftControl = std::move(leftC);
      myRightControl = std::move(rightC);
    }
    else
    {
      myLeftControl = std::move(rightC);
      myRightControl = std::move(leftC);
    }
  }

  myTIA->bindToControllers();

  // now that we know the controllers, enable the event mappings
  myOSystem.eventHandler().enableEmulationKeyMappings();
  myOSystem.eventHandler().enableEmulationJoyMappings();

  myOSystem.eventHandler().setMouseControllerMode(myOSystem.settings().getString("usemouse"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeLeftController(int direction)
{
  int type = static_cast<int>(Controller::getType(myProperties.get(PropType::Controller_Left)));
  if(!type)
    type = static_cast<int>(Controller::getType(leftController().name()));
  type = BSPF::clampw(type + direction,
                      1, static_cast<int>(Controller::Type::LastType) - 1);

  myProperties.set(PropType::Controller_Left, Controller::getPropName(Controller::Type{type}));
  setControllers(myProperties.get(PropType::Cart_MD5));

  ostringstream msg;
  msg << "Left controller " << Controller::getName(Controller::Type{type});
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeRightController(int direction)
{
  int type = static_cast<int>(Controller::getType(myProperties.get(PropType::Controller_Right)));
  if(!type)
    type = static_cast<int>(Controller::getType(rightController().name()));
  type = BSPF::clampw(type + direction,
                      1, static_cast<int>(Controller::Type::LastType) - 1);

  myProperties.set(PropType::Controller_Right, Controller::getPropName(Controller::Type{type}));
  setControllers(myProperties.get(PropType::Cart_MD5));

  ostringstream msg;
  msg << "Right controller " << Controller::getName(Controller::Type{type});
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unique_ptr<Controller> Console::getControllerPort(
    const Controller::Type type, const Controller::Jack port, string_view romMd5)
{
  unique_ptr<Controller> controller;

  if(type != Controller::Type::QuadTari)
  {
    myOSystem.eventHandler().defineKeyControllerMappings(type, port, myProperties);
    myOSystem.eventHandler().defineJoyControllerMappings(type, port, myProperties);
  }

  switch(type)
  {
    case Controller::Type::BoosterGrip:
      controller = make_unique<BoosterGrip>(port, myEvent, *mySystem);
      break;

    case Controller::Type::Driving:
      controller = make_unique<Driving>(port, myEvent, *mySystem);
      break;

    case Controller::Type::Keyboard:
      controller = make_unique<Keyboard>(port, myEvent, *mySystem);
      break;

    case Controller::Type::Paddles:
    case Controller::Type::PaddlesIAxis:
    case Controller::Type::PaddlesIAxDr:
    {
      // Also check if we should swap the paddles plugged into a jack
      const bool swapPaddles =
        myProperties.get(PropType::Controller_SwapPaddles) == "YES";
      bool swapAxis = false, swapDir = false;
      if(type == Controller::Type::PaddlesIAxis)
        swapAxis = true;
      else if(type == Controller::Type::PaddlesIAxDr)
        swapAxis = swapDir = true;

      Paddles::setAnalogXCenter(BSPF::stoi(myProperties.get(PropType::Controller_PaddlesXCenter)));
      Paddles::setAnalogYCenter(BSPF::stoi(myProperties.get(PropType::Controller_PaddlesYCenter)));
      Paddles::setAnalogSensitivity(myOSystem.settings().getInt("psense"));

      controller = make_unique<Paddles>(port, myEvent, *mySystem,
                                        swapPaddles, swapAxis, swapDir);
      break;
    }
    case Controller::Type::AmigaMouse:
      controller = make_unique<AmigaMouse>(port, myEvent, *mySystem);
      break;

    case Controller::Type::AtariMouse:
      controller = make_unique<AtariMouse>(port, myEvent, *mySystem);
      break;

    case Controller::Type::TrakBall:
      controller = make_unique<TrakBall>(port, myEvent, *mySystem);
      break;

    case Controller::Type::AtariVox:
    {
      FSNode nvramfile = myOSystem.nvramDir();
      nvramfile /= "atarivox_eeprom.dat";
      const Controller::onMessageCallback callback = [&os = myOSystem]
      (string_view msg)
        {
          const bool devSettings = os.settings().getBool("dev.settings");
          if(os.settings().getBool(devSettings ? "dev.extaccess" : "plr.extaccess"))
            os.frameBuffer().showTextMessage(msg);
        };
      controller = make_unique<AtariVox>(port, myEvent, *mySystem,
          myOSystem.settings().getString("avoxport"), nvramfile, callback);
      break;
    }
    case Controller::Type::SaveKey:
    {
      FSNode nvramfile = myOSystem.nvramDir();
      nvramfile /= "savekey_eeprom.dat";
      const Controller::onMessageCallback callback = [&os = myOSystem]
      (string_view msg)
        {
          const bool devSettings = os.settings().getBool("dev.settings");
          if(os.settings().getBool(devSettings ? "dev.extaccess" : "plr.extaccess"))
            os.frameBuffer().showTextMessage(msg);
        };
      controller = make_unique<SaveKey>(port, myEvent, *mySystem, nvramfile, callback);
      break;
    }
    case Controller::Type::Genesis:
      controller = make_unique<Genesis>(port, myEvent, *mySystem);
      break;

    case Controller::Type::KidVid:
    {
      const Controller::onMessageCallbackForced callback = [&os = myOSystem]
      (string_view msg, bool force) {
        const bool devSettings = os.settings().getBool("dev.settings");
        if(force || os.settings().getBool(devSettings ? "dev.extaccess" : "plr.extaccess"))
          os.frameBuffer().showTextMessage(msg);
        };
      controller = make_unique<KidVid>
        (port, myEvent, myOSystem, *mySystem, romMd5, callback);
      break;
    }

    case Controller::Type::MindLink:
      controller = make_unique<MindLink>(port, myEvent, *mySystem);
      break;

    case Controller::Type::Lightgun:
      controller = make_unique<Lightgun>
        (port, myEvent, *mySystem, romMd5, myOSystem.frameBuffer());
      break;

    case Controller::Type::QuadTari:
    {
      unique_ptr<QuadTari> quadTari = make_unique<QuadTari>(port, myOSystem, *mySystem, myProperties, *myCart);

      myOSystem.eventHandler().defineKeyControllerMappings(type, port, myProperties,
        quadTari->firstController().type(), quadTari->secondController().type());
      myOSystem.eventHandler().defineJoyControllerMappings(type, port, myProperties,
        quadTari->firstController().type(), quadTari->secondController().type());
      controller = std::move(quadTari);
      break;
    }
    case Controller::Type::Joy2BPlus:
      controller = make_unique<Joy2BPlus>(port, myEvent, *mySystem);
      break;

    default:
      // What else can we do?
      // always create because it may have been changed by user dialog
      controller = make_unique<Joystick>(port, myEvent, *mySystem);
  }

  return controller;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleSwapPorts(bool toggle)
{
  bool swapped = myProperties.get(PropType::Console_SwapPorts) == "YES";

  if(toggle)
  {
    swapped = !swapped;
    myProperties.set(PropType::Console_SwapPorts, (swapped ? "YES" : "NO"));
    //myOSystem.propSet().insert(myProperties);
    setControllers(myProperties.get(PropType::Cart_MD5));
  }

  ostringstream msg;
  msg << "Swap ports " << (swapped ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleSwapPaddles(bool toggle)
{
  bool swapped = myProperties.get(PropType::Controller_SwapPaddles) == "YES";

  if(toggle)
  {
    swapped = !swapped;
    myProperties.set(PropType::Controller_SwapPaddles, (swapped ? "YES" : "NO"));
    //myOSystem.propSet().insert(myProperties);
    setControllers(myProperties.get(PropType::Cart_MD5));
  }

  ostringstream msg;
  msg << "Swap paddles " << (swapped ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changePaddleCenterX(int direction)
{
  const int center =
    BSPF::clamp(BSPF::stoi(myProperties.get(PropType::Controller_PaddlesXCenter)) + direction,
                Paddles::MIN_ANALOG_CENTER, Paddles::MAX_ANALOG_CENTER);
  myProperties.set(PropType::Controller_PaddlesXCenter, std::to_string(center));
  Paddles::setAnalogXCenter(center);

  ostringstream val;
  val << (center ? center > 0 ? "+" : "" : " ") << center * 5 << "px";
  myOSystem.frameBuffer().showGaugeMessage("Paddles x-center ", val.str(), center,
                                           Paddles::MIN_ANALOG_CENTER, Paddles::MAX_ANALOG_CENTER);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changePaddleCenterY(int direction)
{
  const int center =
    BSPF::clamp(BSPF::stoi(myProperties.get(PropType::Controller_PaddlesYCenter)) + direction,
                Paddles::MIN_ANALOG_CENTER, Paddles::MAX_ANALOG_CENTER);
  myProperties.set(PropType::Controller_PaddlesYCenter, std::to_string(center));
  Paddles::setAnalogYCenter(center);

  ostringstream val;
  val << (center ? center > 0 ? "+" : "" : " ") << center * 5 << "px";
  myOSystem.frameBuffer().showGaugeMessage("Paddles y-center ", val.str(), center,
                                           Paddles::MIN_ANALOG_CENTER, Paddles::MAX_ANALOG_CENTER);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changePaddleAxesRange(int direction)
{
  istringstream m_axis(myProperties.get(PropType::Controller_MouseAxis));
  string mode = "AUTO";
  int range{0};

  m_axis >> mode;
  if(!(m_axis >> range))
    range = Paddles::MAX_MOUSE_RANGE;

  range = BSPF::clamp(range + direction,
                      Paddles::MIN_MOUSE_RANGE, Paddles::MAX_MOUSE_RANGE);

  ostringstream control;
  control << mode;
  if(range != 100)
    control << " " << std::to_string(range);
  myProperties.set(PropType::Controller_MouseAxis, control.str());

  Paddles::setDigitalPaddleRange(range);

  ostringstream val;
  val << range << "%";
  myOSystem.frameBuffer().showGaugeMessage("Mouse axes range", val.str(), range);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleAutoFire(bool toggle)
{
  bool enabled = myOSystem.settings().getBool("autofire");

  if(toggle)
  {
    enabled = !enabled;
    myOSystem.settings().setValue("autofire", enabled);
    Controller::setAutoFire(enabled);
  }

  ostringstream ss;
  ss << "Autofire " << (enabled ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(ss.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeAutoFireRate(int direction)
{
  const Int32 scanlines = std::max<Int32>(tia().scanlinesLastFrame(), 240);
  const bool isNTSC = scanlines <= 287;

  int rate = myOSystem.settings().getInt("autofirerate");

  rate = BSPF::clamp(rate + direction, 0, isNTSC ? 30 : 25);

  myOSystem.settings().setValue("autofirerate", rate);
  Controller::setAutoFireRate(rate);

  ostringstream val;

  if(rate)
  {
    myOSystem.settings().setValue("autofire", true);
    Controller::setAutoFire(true);
    val << rate << " Hz";
  }
  else
    val << "Off";

  myOSystem.frameBuffer().showGaugeMessage("Autofire rate", val.str(), rate, 0, isNTSC ? 30 : 25);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float Console::currentFrameRate() const
{
  return
    (myConsoleTiming == ConsoleTiming::ntsc ? 262.F * 60.F : 312.F * 50.F) /
     myTIA->frameBufferScanlinesLastFrame();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int Console::gameRefreshRate() const
{
  return
    myDisplayFormat == "NTSC" || myDisplayFormat == "PAL60" ||
    myDisplayFormat == "SECAM60" ? 60 : 50;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleDeveloperSet(bool toggle)
{
  bool devSettings = myOSystem.settings().getBool("dev.settings");
  if(toggle)
  {
    devSettings = !devSettings;
    const DevSettingsHandler::SettingsSet set = devSettings
      ? DevSettingsHandler::SettingsSet::developer
      : DevSettingsHandler::SettingsSet::player;

    myOSystem.settings().setValue("dev.settings", devSettings);
    myDevSettingsHandler->loadSettings(set);
    myDevSettingsHandler->applySettings(set);
  }
  const string message = (devSettings ? "Developer" : "Player") + string(" settings enabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleTIABit(TIABit bit, string_view bitname,
                           bool show, bool toggle) const
{
  const bool result = myTIA->toggleBit(bit, toggle ? 2 : 3);
  const string message = string{bitname} + (result ? " enabled" : " disabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleBits(bool toggle) const
{
  const bool enabled = myTIA->toggleBits(toggle);
  const string message = string("TIA bits ") + (enabled ? "enabled" : "disabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleTIACollision(TIABit bit, string_view bitname,
                                 bool show, bool toggle) const
{
  const bool result = myTIA->toggleCollision(bit, toggle ? 2 : 3);
  const string message = string{bitname} +
      (result ? " collision enabled" : " collision disabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleCollisions(bool toggle) const
{
  const bool enabled = myTIA->toggleCollisions(toggle);
  const string message = string("TIA collisions ") + (enabled ? "enabled" : "disabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleFixedColors(bool toggle) const
{
  const bool enabled = toggle ? myTIA->toggleFixedColors() : myTIA->usingFixedColors();
  const string message = string("Fixed debug colors ") + (enabled ? "enabled" : "disabled");

  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::toggleJitter(bool toggle) const
{
  const bool enabled = myTIA->toggleJitter(toggle ? 2 : 3);
  const string message = string("TV scanline jitter ") + (enabled ? "enabled" : "disabled");

  myOSystem.settings().setValue(
    myOSystem.settings().getBool("dev.settings") ? "dev.tv.jitter" : "plr.tv.jitter", enabled);
  myOSystem.frameBuffer().showTextMessage(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeJitterSense(int direction) const
{
  const string prefix = myOSystem.settings().getBool("dev.settings") ? "dev." : "plr.";
  int sensitivity = myOSystem.settings().getInt(prefix + "tv.jitter_sense");
  const bool enabled = direction ? sensitivity + direction > 0 : myTIA->toggleJitter(3);

  // if disabled, enable before first before increasing recovery
  if(!myTIA->toggleJitter(3))
    direction = 0;

  sensitivity = BSPF::clamp(static_cast<Int32>(sensitivity + direction),
    JitterEmulation::MIN_SENSITIVITY, JitterEmulation::MAX_SENSITIVITY);
  myOSystem.settings().setValue(prefix + "tv.jitter", enabled);

  if(enabled)
  {
    ostringstream val;

    myTIA->toggleJitter(1);
    myTIA->setJitterSensitivity(sensitivity);
    myOSystem.settings().setValue(prefix + "tv.jitter_sense", sensitivity);
    val << sensitivity;
    myOSystem.frameBuffer().showGaugeMessage("TV jitter sensitivity", val.str(), sensitivity,
      0, JitterEmulation::MAX_SENSITIVITY);
  }
  else
  {
    myTIA->toggleJitter(0);
    myOSystem.frameBuffer().showTextMessage("TV scanline jitter disabled");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::changeJitterRecovery(int direction) const
{
  const string prefix = myOSystem.settings().getBool("dev.settings") ? "dev." : "plr.";
  int recovery = myOSystem.settings().getInt(prefix + "tv.jitter_recovery");
  const bool enabled = direction ? recovery + direction > 0 : myTIA->toggleJitter(3);

  // if disabled, enable before first before increasing recovery
  if(!myTIA->toggleJitter(3))
    direction = 0;

  recovery = BSPF::clamp(static_cast<Int32>(recovery + direction),
    JitterEmulation::MIN_RECOVERY, JitterEmulation::MAX_RECOVERY);
  myOSystem.settings().setValue(prefix + "tv.jitter", enabled);

  if(enabled)
  {
    ostringstream val;

    myTIA->toggleJitter(1);
    myTIA->setJitterRecoveryFactor(recovery);
    myOSystem.settings().setValue(prefix + "tv.jitter_recovery", recovery);
    val << recovery;
    myOSystem.frameBuffer().showGaugeMessage("TV jitter roll", val.str(), recovery,
      0, JitterEmulation::MAX_RECOVERY);
  }
  else
  {
    myTIA->toggleJitter(0);
    myOSystem.frameBuffer().showTextMessage("TV scanline jitter disabled");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::attachDebugger(Debugger& dbg)
{
#ifdef DEBUGGER_SUPPORT
//  myOSystem.createDebugger(*this);
  mySystem->m6502().attach(dbg);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Console::stateChanged(EventHandlerState state)
{
  // only the CompuMate used to care about state changes
}
