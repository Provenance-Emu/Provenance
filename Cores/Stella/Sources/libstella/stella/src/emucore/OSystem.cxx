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
#include "Logger.hxx"

#include "MediaFactory.hxx"
#include "Sound.hxx"

#ifdef CHEATCODE_SUPPORT
  #include "CheatManager.hxx"
#endif
#ifdef DEBUGGER_SUPPORT
  #include "Debugger.hxx"
#endif
#ifdef GUI_SUPPORT
  #include "BrowserDialog.hxx"
  #include "OptionsMenu.hxx"
  #include "CommandMenu.hxx"
  #include "HighScoresMenu.hxx"
  #include "MessageMenu.hxx"
  #include "PlusRomsMenu.hxx"
  #include "Launcher.hxx"
  #include "TimeMachine.hxx"
#endif

#include "FSNode.hxx"
#include "MD5.hxx"
#include "Cart.hxx"
#include "CartCreator.hxx"
#include "CartDetector.hxx"
#include "FrameBuffer.hxx"
#include "TIASurface.hxx"
#include "TIAConstants.hxx"
#include "Settings.hxx"
#include "PropsSet.hxx"
#include "EventHandler.hxx"
#include "PNGLibrary.hxx"
#include "JPGLibrary.hxx"
#include "Console.hxx"
#include "Random.hxx"
#include "StateManager.hxx"
#include "TimerManager.hxx"
#ifdef GUI_SUPPORT
  #include "HighScoresManager.hxx"
#endif
#include "Version.hxx"
#include "TIA.hxx"
#include "DispatchResult.hxx"
#include "EmulationWorker.hxx"
#include "AudioSettings.hxx"
#include "M6532.hxx"

#include "OSystem.hxx"

using namespace std::chrono;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
OSystem::OSystem()
{
  // Get built-in features
  #ifdef SOUND_SUPPORT
    myFeatures += "Sound ";
  #endif
  #ifdef JOYSTICK_SUPPORT
    myFeatures += "Joystick ";
  #endif
  #ifdef DEBUGGER_SUPPORT
    myFeatures += "Debugger ";
  #endif
  #ifdef CHEATCODE_SUPPORT
    myFeatures += "Cheats ";
  #endif
  #ifdef IMAGE_SUPPORT
    myFeatures += "Images ";
  #endif
  #ifdef ZIP_SUPPORT
    myFeatures += "ZIP";
  #endif

  // Get build info
  ostringstream info;
  info << "Build " << STELLA_BUILD << ", using " << MediaFactory::backendName()
       << " [" << BSPF::ARCH << "]";
  myBuildInfo = info.str();

  mySettings = MediaFactory::createSettings();

  myPropSet = make_unique<PropertiesSet>();

  Logger::instance().setLogParameters(Logger::Level::MAX, false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
OSystem::~OSystem()
{
#ifdef GUI_SUPPORT
  // BrowserDialog is a special dialog that is statically allocated
  // So we need to make sure that it is destroyed in the normal d'tor chain;
  // not at the very end of program exit, when some objects it requires
  // have already been destroyed
  BrowserDialog::hide();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool OSystem::initialize(const Settings::Options& options)
{
  loadConfig(options);

  ostringstream buf;
  buf << "Stella " << STELLA_VERSION << '\n'
      << "  Features: " << myFeatures << '\n'
      << "  " << myBuildInfo << "\n\n"
      << "Base directory:     '"
      << myBaseDir.getShortPath() << "'\n"
      << "State directory:    '"
      << myStateDir.getShortPath() << "'\n"
      << "NVRam directory:    '"
      << myNVRamDir.getShortPath() << "'\n"
      << "Persistence:        '"
      << describePresistence() << "'\n"
      << "Cheat file:         '"
      << myCheatFile.getShortPath() << "'\n"
      << "Palette file:       '"
      << myPaletteFile.getShortPath() << "'\n";
  Logger::info(buf.str());

  // NOTE: The framebuffer MUST be created before any other object!!!
  // Get relevant information about the video hardware
  // This must be done before any graphics context is created, since
  // it may be needed to initialize the size of graphical objects
  try
  {
    myFrameBuffer = make_unique<FrameBuffer>(*this);
    myFrameBuffer->initialize();
  }
  catch(const runtime_error& e)
  {
    Logger::error(e.what());
    return false;
  }

  // Create the event handler for the system
  myEventHandler = MediaFactory::createEventHandler(*this);
  myEventHandler->initialize();

  myStateManager = make_unique<StateManager>(*this);
  myTimerManager = make_unique<TimerManager>();

  myAudioSettings = make_unique<AudioSettings>(*mySettings);

  // Create the sound object; the sound subsystem isn't actually
  // opened until needed, so this is non-blocking (on those systems
  // that only have a single sound device (no hardware mixing))
  createSound();

  // Create random number generator
  myRandom = make_unique<Random>(static_cast<uInt32>(TimerManager::getTicks()));

#ifdef CHEATCODE_SUPPORT
  myCheatManager = make_unique<CheatManager>(*this);
  myCheatManager->loadCheatDatabase();
#endif

#ifdef GUI_SUPPORT
  // Create various subsystems (menu and launcher GUI objects, etc)
  myOptionsMenu = make_unique<OptionsMenu>(*this);
  myCommandMenu = make_unique<CommandMenu>(*this);
  myHighScoresManager = make_unique<HighScoresManager>(*this);
  myHighScoresMenu = make_unique<HighScoresMenu>(*this);
  myMessageMenu = make_unique<MessageMenu>(*this);
  myPlusRomMenu = make_unique<PlusRomsMenu>(*this);
  myTimeMachine = make_unique<TimeMachine>(*this);
  myLauncher = make_unique<Launcher>(*this);

  myHighScoresManager->setRepository(getHighscoreRepository());
#endif

#ifdef IMAGE_SUPPORT
  // Create PNG handler
  myPNGLib = make_unique<PNGLibrary>(*this);
  // Create JPG handler
  myJPGLib = make_unique<JPGLibrary>(*this);
#endif

  // Detect serial port for AtariVox-USB
  // If a previously set port is defined, use it;
  // otherwise use the first one found (if any)
  const string_view avoxport = mySettings->getString("avoxport");
  const StringList ports = MediaFactory::createSerialPort()->portNames();

  if(avoxport.empty() && !ports.empty())
    mySettings->setValue("avoxport", ports[0]);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::loadConfig(const Settings::Options& options)
{
  // Get base directory and config file from derived class
  // It will decide whether it can override its default location
  string baseDir, homeDir;
  getBaseDirectories(baseDir, homeDir,
                     ourOverrideBaseDirWithApp, ourOverrideBaseDir);

  // Get fully-qualified pathnames, and make directories when needed
  myBaseDir = FSNode(baseDir);
  if(!myBaseDir.isDirectory())
    myBaseDir.makeDir();

  myHomeDir = FSNode(homeDir);
  if(!myHomeDir.isDirectory())
    myHomeDir.makeDir();

  initPersistence(myBaseDir);

  mySettings->setRepository(getSettingsRepository());
  myPropSet->setRepository(getPropertyRepository());

  mySettings->load(options);

  // userDir is NOT affected by '-baseDir'and '-basedirinapp' params
  string userDir = mySettings->getString("userdir");
  if(userDir.empty())
    userDir = homeDir;
  myUserDir = FSNode(userDir);
  if(!myUserDir.isDirectory())
    myUserDir.makeDir();

  Logger::instance().setLogParameters(mySettings->getInt("loglevel"),
                                      mySettings->getBool("logtoconsole"));
  Logger::debug("Loading config options ...");

  // Get updated paths for all configuration files
  setConfigPaths();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::saveConfig()
{
  // Ask all subsystems to save their settings
  if(myFrameBuffer && mySettings)
    myFrameBuffer->saveConfig(settings());

  if(mySettings)
  {
    Logger::debug("Saving config options ...");
    mySettings->save();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::setConfigPaths()
{
  // Make sure all required directories actually exist
  const auto buildDirIfRequired = [](FSNode& path,
                                     const FSNode& initialPath,
                                     string_view pathToAppend = EmptyString)
  {
    path = initialPath;
    if(pathToAppend != EmptyString)
      path /= pathToAppend;
    if(!path.isDirectory())
      path.makeDir();
  };

  buildDirIfRequired(myStateDir, myBaseDir, "state");
  buildDirIfRequired(myNVRamDir, myBaseDir, "nvram");
#ifdef DEBUGGER_SUPPORT
  buildDirIfRequired(myCfgDir, myBaseDir, "cfg");
#endif

  myCheatFile = myBaseDir;  myCheatFile /= "stella.cht";
  myPaletteFile = myBaseDir;  myPaletteFile /= "stella.pal";

#if 0
  // Debug code
  auto dbgPath = [](string_view desc, const FSNode& location)
  {
    cerr << desc << ": " << location << '\n';
  };
  dbgPath("base dir  ", myBaseDir);
  dbgPath("state dir ", myStateDir);
  dbgPath("nvram dir ", myNVRamDir);
  dbgPath("cfg dir   ", myCfgDir);
  dbgPath("ssave dir ", mySnapshotSaveDir);
  dbgPath("sload dir ", mySnapshotLoadDir);
  dbgPath("bezel dir ", myBezelDir);
  dbgPath("cheat file", myCheatFile);
  dbgPath("pal file  ", myPaletteFile);
#endif
}

#ifdef IMAGE_SUPPORT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& OSystem::snapshotSaveDir()
{
  const string_view ssSaveDir = mySettings->getString("snapsavedir");
  if(ssSaveDir == EmptyString)
    mySnapshotSaveDir = userDir();
  else
    mySnapshotSaveDir = FSNode(ssSaveDir);
  if(!mySnapshotSaveDir.isDirectory())
    mySnapshotSaveDir.makeDir();

  return mySnapshotSaveDir;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& OSystem::snapshotLoadDir()
{
  const string_view ssLoadDir = mySettings->getString("snaploaddir");
  if(ssLoadDir == EmptyString)
    mySnapshotLoadDir = userDir();
  else
    mySnapshotLoadDir = FSNode(ssLoadDir);
  if(!mySnapshotLoadDir.isDirectory())
    mySnapshotLoadDir.makeDir();

  return mySnapshotLoadDir;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& OSystem::bezelDir()
{
  const string_view bezelDir = mySettings->getString("bezel.dir");
  if(bezelDir == EmptyString)
    myBezelDir = userDir();
  else
    myBezelDir = FSNode(bezelDir);
  if(!myBezelDir.isDirectory())
    myBezelDir.makeDir();

  return myBezelDir;
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::setUserDir(string_view path)
{
  mySettings->setValue("userdir", path);

  myUserDir = FSNode(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool OSystem::checkUserPalette(bool outputError) const
{
  try
  {
    ByteBuffer palette;
    const size_t size = paletteFile().read(palette);

    // Make sure the contains enough data for the NTSC, PAL and SECAM palettes
    // This means 128 colours each for NTSC and PAL, at 3 bytes per pixel
    // and 8 colours for SECAM at 3 bytes per pixel
    if(size != 128 * 3 * 2 + 8 * 3)
    {
      if(outputError)
        cerr << "ERROR: invalid palette file " << paletteFile() << '\n';

      return false;
    }
  }
  catch(...)
  {
    return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBInitStatus OSystem::createFrameBuffer()
{
  // Re-initialize the framebuffer to current settings
  FBInitStatus fbstatus = FBInitStatus::FailComplete;
  switch(myEventHandler->state())
  {
    case EventHandlerState::EMULATION:
    case EventHandlerState::PAUSE:
  #ifdef GUI_SUPPORT
    case EventHandlerState::OPTIONSMENU:
    case EventHandlerState::CMDMENU:
    case EventHandlerState::TIMEMACHINE:
  #endif
    case EventHandlerState::PLAYBACK:
      if((fbstatus = myConsole->initializeVideo()) != FBInitStatus::Success)
        return fbstatus;
      break;

  #ifdef GUI_SUPPORT
    case EventHandlerState::LAUNCHER:
      if((fbstatus = myLauncher->initializeVideo()) != FBInitStatus::Success)
        return fbstatus;
      break;
  #endif

  #ifdef DEBUGGER_SUPPORT
    case EventHandlerState::DEBUGGER:
      if((fbstatus = myDebugger->initializeVideo()) != FBInitStatus::Success)
        return fbstatus;
      break;
  #endif

    case EventHandlerState::NONE:  // Should never happen
    default:
      Logger::error("ERROR: Unknown emulation state in createFrameBuffer()");
      break;
  }
  return fbstatus;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::createSound()
{
  if(!mySound)
    mySound = MediaFactory::createAudio(*this, *myAudioSettings);
#ifndef SOUND_SUPPORT
  myAudioSettings->setEnabled(false);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystem::createConsole(const FSNode& rom, string_view md5sum, bool newrom)
{
  bool showmessage = false;

  // If same ROM has been given, we reload the current one (assuming one exists)
  if(!newrom && rom == myRomFile)
  {
    showmessage = true;  // we show a message if a ROM is being reloaded
  }
  else
  {
    myRomFile = rom;
    myRomMD5  = md5sum;

    // Each time a new console is loaded, we simulate a cart removal
    // Some carts need knowledge of this, as they behave differently
    // based on how many power-cycles they've been through since plugged in
    mySettings->setValue("romloadcount", -1); // we move to the next game initially
  }

  // Create an instance of the 2600 game console
  ostringstream buf;

  myEventHandler->handleConsoleStartupEvents();

  try
  {
    closeConsole();
    myConsole = openConsole(myRomFile, myRomMD5);
  }
  catch(const runtime_error& e)
  {
    buf << "ERROR: " << e.what();
    Logger::error(buf.str());
    return buf.str();
  }

  if(myConsole)
  {
  #ifdef DEBUGGER_SUPPORT
    myDebugger = make_unique<Debugger>(*this, *myConsole);
    myDebugger->initialize();
    myConsole->attachDebugger(*myDebugger);
  #endif
  #ifdef CHEATCODE_SUPPORT
    myCheatManager->loadCheats(myRomMD5);
  #endif
    myEventHandler->reset(EventHandlerState::EMULATION);
    myEventHandler->setMouseControllerMode(mySettings->getString("usemouse"));
    if(createFrameBuffer() != FBInitStatus::Success)  // Takes care of initializeVideo()
    {
      Logger::error("ERROR: Couldn't create framebuffer for console");
      myEventHandler->reset(EventHandlerState::LAUNCHER);
      return "ERROR: Couldn't create framebuffer for console";
    }
    myConsole->initializeAudio();

    const string saveOnExit = settings().getString("saveonexit");
    const bool devSettings = settings().getBool("dev.settings");
    const bool activeTM = settings().getBool(
      devSettings ? "dev.timemachine" : "plr.timemachine");

    if (saveOnExit == "all" && activeTM)
      myEventHandler->handleEvent(Event::LoadAllStates);

    if(showmessage)
    {
      const string& id = myConsole->cartridge().multiCartID();
      if(id.empty())
        myFrameBuffer->showTextMessage("New console created");
      else
        myFrameBuffer->showTextMessage("Multicart " +
          myConsole->cartridge().detectedType() + ", loading ROM" + id);
    }
    buf << "Game console created:\n"
        << "  ROM file: " << myRomFile.getShortPath() << '\n';
    const FSNode propsFile(myRomFile.getPathWithExt(".pro"));
    if(propsFile.exists())
      buf << "  PRO file: " << propsFile.getShortPath() << '\n';
    buf << '\n' << getROMInfo(*myConsole);
    Logger::info(buf.str());

    myFrameBuffer->setCursorState();

    myEventHandler->handleConsoleStartupEvents();
    myConsole->riot().update();

  #ifdef DEBUGGER_SUPPORT
    if(mySettings->getBool("debug"))
      myEventHandler->enterDebugMode();
  #endif

    if(!showmessage)
    {
      if(settings().getBool(devSettings ? "dev.detectedinfo" : "plr.detectedinfo"))
      {
        ostringstream msg;

        msg << myConsole->leftController().name() << "/" << myConsole->rightController().name()
          << " - " << myConsole->cartridge().detectedType()
          << (myConsole->cartridge().isPlusROM() ? " PlusROM " : "")
          << " - " << myConsole->getFormatString();
        myFrameBuffer->showTextMessage(msg.str());
      }
      else if(!myLauncherUsed)
      {
        ostringstream msg;

        msg << "Stella " << STELLA_VERSION;
        myFrameBuffer->showTextMessage(msg.str());
      }
    }

    // Check for first PlusROM start
    if(myConsole->cartridge().isPlusROM())
    {
      if(settings().getString("plusroms.fixedid") == EmptyString)
      {
        // Make sure there always is an id
        constexpr int ID_LEN = 32;
        constexpr string_view HEX_DIGITS{ "0123456789ABCDEF" };
        char id_chr[ID_LEN] = { 0 };
        const Random rnd;

        for(char& c : id_chr)
          c = HEX_DIGITS[rnd.next() % 16];

        settings().setValue("plusroms.fixedid", string(id_chr, ID_LEN));

        myEventHandler->changeStateByEvent(Event::PlusRomsSetupMode);
      }

      string id = settings().getString("plusroms.id");

      if(id == EmptyString)
        id = settings().getString("plusroms.fixedid");

      Logger::info("PlusROM Nick: " + settings().getString("plusroms.nick") + ", ID: " + id);
    }
  }

  return EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool OSystem::reloadConsole(bool nextrom)
{
  mySettings->setValue("romloadprev", !nextrom);

  return createConsole(myRomFile, myRomMD5, false) == EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool OSystem::hasConsole() const
{
  return myConsole != nullptr &&
         myEventHandler->state() != EventHandlerState::LAUNCHER;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool OSystem::createLauncher(string_view startdir)
{
  closeConsole();

  if(mySound)
    mySound->pause(true);

  mySettings->setValue("tmpromdir", startdir);
  bool status = false;

#ifdef GUI_SUPPORT
  myEventHandler->reset(EventHandlerState::LAUNCHER);
  if(createFrameBuffer() == FBInitStatus::Success)
  {
    myLauncher->reStack();
    myFrameBuffer->setCursorState();

    status = true;
  }
  else
    Logger::error("ERROR: Couldn't create launcher");
#endif

  myLauncherUsed = myLauncherUsed || status;
  myLauncherLostFocus = !status;
  return status;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool OSystem::launcherLostFocus()
{
  if(myLauncherLostFocus)
    return true;

  myLauncherLostFocus = true;
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystem::getROMInfo(const FSNode& romfile)
{
  unique_ptr<Console> console;
  try
  {
    string md5;
    console = openConsole(romfile, md5);
  }
  catch(const runtime_error& e)
  {
    ostringstream buf;
    buf << "ERROR: Couldn't get ROM info (" << e.what() << ")";
    return buf.str();
  }

  return getROMInfo(*console);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::toggleTimeMachine()
{
  myStateManager->toggleTimeMachine();
  myConsole->tia().setAudioRewindMode(myStateManager->mode() != StateManager::Mode::Off);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::resetFps()
{
  myFpsMeter.reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unique_ptr<Console> OSystem::openConsole(const FSNode& romfile, string& md5)
{
  unique_ptr<Console> console;

  // Open the cartridge image and read it in
  ByteBuffer image;
  size_t size = 0;
  if((image = openROM(romfile, md5, size)) != nullptr)
  {
    // Get a valid set of properties, including any entered on the commandline
    // For initial creation of the Cart, we're only concerned with the BS type
    Properties props;
    myPropSet->getMD5(md5, props);

    // Local helper method
    const auto CMDLINE_PROPS_UPDATE = [&](string_view name, PropType prop)
    {
      const string_view s = mySettings->getString(name);
      if(!s.empty()) props.set(prop, s);
    };

    CMDLINE_PROPS_UPDATE("bs", PropType::Cart_Type);
    CMDLINE_PROPS_UPDATE("type", PropType::Cart_Type);
    CMDLINE_PROPS_UPDATE("startbank", PropType::Cart_StartBank);

    // Now create the cartridge
    string cartmd5 = md5;
    const string& type = props.get(PropType::Cart_Type);
    const Cartridge::messageCallback callback = [&os = *this](string_view msg)
    {
      const bool devSettings = os.settings().getBool("dev.settings");

      if(os.settings().getBool(devSettings ? "dev.extaccess" : "plr.extaccess"))
        os.frameBuffer().showTextMessage(msg);
    };

    unique_ptr<Cartridge> cart =
      CartCreator::create(romfile, image, size, cartmd5, type, *mySettings);
    cart->setMessageCallback(callback);

    // Some properties may not have a name set; we can't leave it blank
    if(props.get(PropType::Cart_Name) == EmptyString)
      props.set(PropType::Cart_Name, romfile.getNameWithExt(""));

    // It's possible that the cart created was from a piece of the image,
    // and that the md5 (and hence the cart) has changed
    if(props.get(PropType::Cart_MD5) != cartmd5)
    {
      if(!myPropSet->getMD5(cartmd5, props))
      {
        // Cart md5 wasn't found, so we create a new props for it
        props.set(PropType::Cart_MD5, cartmd5);
        props.set(PropType::Cart_Name, props.get(PropType::Cart_Name)+cart->multiCartID());
        myPropSet->insert(props, false);
      }
    }

    CMDLINE_PROPS_UPDATE("sp", PropType::Console_SwapPorts);
    CMDLINE_PROPS_UPDATE("lc", PropType::Controller_Left);
    CMDLINE_PROPS_UPDATE("lq1", PropType::Controller_Left1);
    CMDLINE_PROPS_UPDATE("lq2", PropType::Controller_Left2);
    CMDLINE_PROPS_UPDATE("rc", PropType::Controller_Right);
    CMDLINE_PROPS_UPDATE("rq1", PropType::Controller_Right1);
    CMDLINE_PROPS_UPDATE("rq2", PropType::Controller_Right2);
    const string& bc = mySettings->getString("bc");
    if(!bc.empty()) {
      props.set(PropType::Controller_Left, bc);
      props.set(PropType::Controller_Right, bc);
    }
    const string& aq = mySettings->getString("aq");
    if(!aq.empty())
    {
      props.set(PropType::Controller_Left1, aq);
      props.set(PropType::Controller_Left2, aq);
      props.set(PropType::Controller_Right1, aq);
      props.set(PropType::Controller_Right2, aq);
    }
    CMDLINE_PROPS_UPDATE("cp", PropType::Controller_SwapPaddles);
    CMDLINE_PROPS_UPDATE("ma", PropType::Controller_MouseAxis);
    CMDLINE_PROPS_UPDATE("channels", PropType::Cart_Sound);
    CMDLINE_PROPS_UPDATE("ld", PropType::Console_LeftDiff);
    CMDLINE_PROPS_UPDATE("rd", PropType::Console_RightDiff);
    CMDLINE_PROPS_UPDATE("tv", PropType::Console_TVType);
    CMDLINE_PROPS_UPDATE("format", PropType::Display_Format);
    CMDLINE_PROPS_UPDATE("vcenter", PropType::Display_VCenter);
    CMDLINE_PROPS_UPDATE("pp", PropType::Display_Phosphor);
    CMDLINE_PROPS_UPDATE("ppblend", PropType::Display_PPBlend);
    CMDLINE_PROPS_UPDATE("pxcenter", PropType::Controller_PaddlesXCenter);
    CMDLINE_PROPS_UPDATE("pycenter", PropType::Controller_PaddlesYCenter);
    CMDLINE_PROPS_UPDATE("bezelname", PropType::Bezel_Name);

    // Finally, create the cart with the correct properties
    if(cart)
      console = make_unique<Console>(*this, cart, props, *myAudioSettings);
  }

  return console;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::closeConsole()
{
  if(myConsole)
  {
  #ifdef CHEATCODE_SUPPORT
    // If a previous console existed, save cheats before creating a new one
    myCheatManager->saveCheats(myConsole->properties().get(PropType::Cart_MD5));
  #endif
    myConsole.reset();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ByteBuffer OSystem::openROM(const FSNode& rom, string& md5, size_t& size)
{
  // This method has a documented side-effect:
  // It not only loads a ROM and creates an array with its contents,
  // but also adds a properties entry if the one for the ROM doesn't
  // contain a valid name

  ByteBuffer image = openROM(rom, size, true);  // handle error message here
  if(image)
  {
    // If we get to this point, we know we have a valid file to open
    // Now we make sure that the file has a valid properties entry
    // To save time, only generate an MD5 if we really need one
    if(md5.empty())
      md5 = MD5::hash(image, size);

    // Make sure to load a per-ROM properties entry, if one exists
    myPropSet->loadPerROM(rom, md5);
  }

  return image;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystem::getROMMD5(const FSNode& rom)
{
  size_t size = 0;
  const ByteBuffer image = openROM(rom, size, false);  // ignore error message

  return image ? MD5::hash(image, size) : EmptyString;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ByteBuffer OSystem::openROM(const FSNode& rom, size_t& size,
                            bool showErrorMessage)
{
  // First check if this is a valid ROM filename
  const bool isValidROM = rom.isFile() && Bankswitch::isValidRomName(rom);
  if(!isValidROM && showErrorMessage)
    throw runtime_error("Unrecognized ROM file type");

  // Next check for a proper file size
  // Streaming ROMs read only a portion of the file
  // Otherwise the size to read is 0 (meaning read the entire file)
  const size_t sizeToRead = CartDetector::isProbablyMVC(rom);
  const bool isStreaming = sizeToRead > 0;

  // Make sure we only read up to the maximum supported cart size
  const bool isValidSize = isValidROM && (isStreaming ||
                           rom.getSize() <= Cartridge::maxSize());
  if(!isValidSize)
  {
    if(showErrorMessage)
      throw runtime_error("ROM file too large");
    else
      return nullptr;
  }

  // Now we can try to open the file
  ByteBuffer image;
  try
  {
    if((size = rom.read(image, sizeToRead)) == 0)
      return nullptr;
  }
  catch(const runtime_error&)
  {
    if(showErrorMessage)  // If caller wants error messages, pass it back
      throw;
  }

  return image;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystem::getROMInfo(const Console& console)
{
  const ConsoleInfo& info = console.about();
  ostringstream buf;

  buf << "  Cart Name:       " << info.CartName << '\n'
      << "  Cart MD5:        " << info.CartMD5 << '\n'
      << "  Controller 0:    " << info.Control0 << '\n'
      << "  Controller 1:    " << info.Control1 << '\n'
      << "  Display Format:  " << info.DisplayFormat << '\n'
      << "  Bankswitch Type: " << info.BankSwitch << '\n';

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float OSystem::frameRate() const
{
  return myConsole ? myConsole->currentFrameRate() : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
double OSystem::dispatchEmulation(EmulationWorker& emulationWorker)
{
  if (!myConsole) return 0.;

  TIA& tia(myConsole->tia());
  const EmulationTiming& timing = myConsole->emulationTiming();
  DispatchResult dispatchResult;

  // Check whether we have a frame pending for rendering...
  const bool framePending = tia.newFramePending();
  // ... and copy it to the frame buffer. It is important to do this before
  // the worker is started to avoid racing.
  if (framePending) {
    myFpsMeter.render(tia.framesSinceLastRender());
    tia.renderToFrameBuffer();
  }

  // Start emulation on a dedicated thread. It will do its own scheduling to
  // sync 6507 and real time and will run until we stop the worker.
  emulationWorker.start(
    timing.cyclesPerSecond(),
    timing.maxCyclesPerTimeslice(),
    timing.minCyclesPerTimeslice(),
    &dispatchResult,
    &tia
  );

  // Render the frame. This may block, but emulation will continue to run on
  // the worker, so the audio pipeline is kept fed :)
  if (framePending) myFrameBuffer->updateInEmulationMode(myFpsMeter.fps());

  // Stop the worker and wait until it has finished
  const uInt64 totalCycles = emulationWorker.stop();

  // Handle the dispatch result
  switch (dispatchResult.getStatus()) {
    case DispatchResult::Status::ok:
      break;

    case DispatchResult::Status::debugger:
      #ifdef DEBUGGER_SUPPORT
       myDebugger->start(
          dispatchResult.getMessage(),
          dispatchResult.getAddress(),
          dispatchResult.wasReadTrap(),
          dispatchResult.getToolTip()
        );
      #endif

      break;

    case DispatchResult::Status::fatal:
      #ifdef DEBUGGER_SUPPORT
        myDebugger->startWithFatalError(dispatchResult.getMessage());
      #else
        cerr << dispatchResult.getMessage() << '\n';
      #endif
        break;

    default:
      throw runtime_error("invalid emulation dispatch result");
  }

  // Handle frying
  if (dispatchResult.getStatus() == DispatchResult::Status::ok &&
      myEventHandler->frying())
    myConsole->fry();

  // Return the 6507 time used in seconds
  return static_cast<double>(totalCycles) /
      static_cast<double>(timing.cyclesPerSecond());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystem::mainLoop()
{
  // 6507 time
  time_point<high_resolution_clock> virtualTime = high_resolution_clock::now();
  // The emulation worker
  EmulationWorker emulationWorker;

  myFpsMeter.reset(TIAConstants::initialGarbageFrames);

  for(;;)
  {
    const bool wasEmulation = myEventHandler->state() == EventHandlerState::EMULATION;

    myEventHandler->poll(TimerManager::getTicks());
    if(myQuitLoop) break;  // Exit if the user wants to quit

    if (!wasEmulation && myEventHandler->state() == EventHandlerState::EMULATION) {
      myFpsMeter.reset();
      virtualTime = high_resolution_clock::now();
    }

    double timesliceSeconds;  // NOLINT

    if (myEventHandler->state() == EventHandlerState::EMULATION)
      // Dispatch emulation and render frame (if applicable)
      timesliceSeconds = dispatchEmulation(emulationWorker);
    else if(myEventHandler->state() == EventHandlerState::PLAYBACK)
    {
      // Playback at emulation speed
      timesliceSeconds = static_cast<double>(myConsole->tia().scanlinesLastFrame() * 76) /
        static_cast<double>(myConsole->emulationTiming().cyclesPerSecond());
      myFrameBuffer->update();
    }
    else
    {
      // Render the GUI with 60 Hz in all other modes
      timesliceSeconds = 1. / 60.;
      myFrameBuffer->update();
    }

    const duration<double> timeslice(timesliceSeconds);
    virtualTime += duration_cast<high_resolution_clock::duration>(timeslice);
    const time_point<high_resolution_clock> now = high_resolution_clock::now();

    // We allow 6507 time to lag behind by one frame max
    const double maxLag = myConsole
      ? (
        static_cast<double>(myConsole->emulationTiming().cyclesPerFrame()) /
        static_cast<double>(myConsole->emulationTiming().cyclesPerSecond())
      )
      : 0;

    if (duration_cast<duration<double>>(now - virtualTime).count() > maxLag)
      // If 6507 time is lagging behind more than one frame we reset it to real time
      virtualTime = now;
    else if (virtualTime > now) {
      // Wait until we have caught up with 6507 time
      std::this_thread::sleep_until(virtualTime);
    }
  }

  // Cleanup time
#ifdef CHEATCODE_SUPPORT
  if(myConsole)
    myCheatManager->saveCheats(myConsole->properties().get(PropType::Cart_MD5));

  myCheatManager->saveCheatDatabase();
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystem::ourOverrideBaseDir;
bool OSystem::ourOverrideBaseDirWithApp = false;
