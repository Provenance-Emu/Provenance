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

#ifndef OSYSTEM_HXX
#define OSYSTEM_HXX

class Console;
class FrameBuffer;
class EventHandler;
class Properties;
class PropertiesSet;
class Random;
class Sound;
class StateManager;
class TimerManager;
class HighScoresManager;
class EmulationWorker;
class AudioSettings;
#ifdef CHEATCODE_SUPPORT
  class CheatManager;
#endif
#ifdef DEBUGGER_SUPPORT
  class Debugger;
#endif
#ifdef GUI_SUPPORT
  class CommandMenu;
  class HighScoresMenu;
  class Launcher;
  class OptionsMenu;
  class MessageMenu;
  class PlusRomsMenu;
  class TimeMachine;
  class VideoAudioDialog;
#endif
#ifdef IMAGE_SUPPORT
  class PNGLibrary;
  class JPGLibrary;
#endif

#include <chrono>

#include "FSNode.hxx"
#include "FrameBufferConstants.hxx"
#include "EventHandlerConstants.hxx"
#include "FpsMeter.hxx"
#include "Settings.hxx"
#include "Logger.hxx"
#include "bspf.hxx"
#include "repository/KeyValueRepository.hxx"
#include "repository/CompositeKeyValueRepository.hxx"

/**
  This class provides an interface for accessing operating system specific
  functions.  It also comprises an overall parent object, to which all the
  other objects belong.

  @author  Stephen Anthony
*/
class OSystem
{
  friend class EventHandler;

  public:
    OSystem();
    virtual ~OSystem();

    /**
      Create all child objects which belong to this OSystem
    */
    virtual bool initialize(const Settings::Options& options);

    /**
      Creates the various framebuffers/renderers available in this system.
      Note that it will only create one type per run of Stella.

      @return  Success or failure of the framebuffer creation
    */
    FBInitStatus createFrameBuffer();

  public:
    /**
      Get the event handler of the system.

      @return The event handler
    */
    EventHandler& eventHandler() const { return *myEventHandler; }

    /**
      Get the frame buffer of the system.

      @return The frame buffer
    */
    FrameBuffer& frameBuffer() const { return *myFrameBuffer; }
    bool hasFrameBuffer() const { return myFrameBuffer.get() != nullptr; }

    /**
      Get the sound object of the system.

      @return The sound object
    */
    Sound& sound() const { return *mySound; }

    /**
      Get the settings object of the system.

      @return The settings object
    */
    Settings& settings() const { return *mySettings; }

    /**
      Get the random object of the system.

      @return The random object
    */
    Random& random() const { return *myRandom; }

    /**
      Get the set of game properties for the system.

      @return The properties set object
    */
    PropertiesSet& propSet() const { return *myPropSet; }

    /**
      Get the console of the system.  The console won't always exist,
      so we should test if it's available.

      @return The console object
    */
    Console& console() const { return *myConsole; }
    bool hasConsole() const;

    /**
      Get the audio settings object of the system.

      @return The audio settings object
    */
    AudioSettings& audioSettings() { return *myAudioSettings; }

  #ifdef GUI_SUPPORT
    /**
      Get the high score manager of the system.

      @return The highscore manager object
    */
    HighScoresManager& highScores() const { return *myHighScoresManager; }
  #endif

    /**
      Get the state manager of the system.

      @return The statemanager object
    */
    StateManager& state() const { return *myStateManager; }

    /**
      Get the timer/callback manager of the system.

      @return The timermanager object
    */
    TimerManager& timer() const { return *myTimerManager; }

    /**
      This method should be called to save the current settings. It first asks
      each subsystem to update its settings, then it saves all settings to the
      config file.
    */
    void saveConfig();

  #ifdef CHEATCODE_SUPPORT
    /**
      Get the cheat manager of the system.

      @return The cheatmanager object
    */
    CheatManager& cheat() const { return *myCheatManager; }
  #endif

  #ifdef DEBUGGER_SUPPORT
    /**
      Get the ROM debugger of the system.

      @return The debugger object
    */
    Debugger& debugger() const { return *myDebugger; }
  #endif

  #ifdef GUI_SUPPORT
    /**
      Get the option menu of the system.

      @return The option menu object
    */
    OptionsMenu& optionsMenu() const { return *myOptionsMenu; }

    /**
      Get the command menu of the system.

      @return The command menu object
    */
    CommandMenu& commandMenu() const { return *myCommandMenu; }

      /**
      Get the highscores menu of the system.

      @return The highscores menu object
      */
    HighScoresMenu& highscoresMenu() const { return *myHighScoresMenu; }

    /**
      Get the message menu of the system.

      @return The message menu object
    */
    MessageMenu& messageMenu() const { return *myMessageMenu; }

    /**
      Get the Plus ROM menu of the system.

      @return The Plus ROM menu object
    */
    PlusRomsMenu& plusRomsMenu() const { return *myPlusRomMenu; }

    /**
      Get the ROM launcher of the system.

      @return The launcher object
    */
    Launcher& launcher() const { return *myLauncher; }

    /**
      Get the time machine of the system (manages state files).

      @return The time machine object
    */
    TimeMachine& timeMachine() const { return *myTimeMachine; }
  #endif

  #ifdef IMAGE_SUPPORT
    /**
      Get the PNG handler of the system.

      @return The PNGlib object
    */
    PNGLibrary& png() const { return *myPNGLib; }

    /**
      Get the JPG handler of the system.

      @return The JPGlib object
    */
    JPGLibrary& jpg() const { return *myJPGLib; }
#endif

    /**
      Set all config file paths for the OSystem.
    */
    void setConfigPaths();

    /**
      Return the default full/complete path name for storing data.
    */
    const FSNode& baseDir() const { return myBaseDir; }

    /**
      Return the full/complete path name for storing state files.
    */
    const FSNode& stateDir() const { return myStateDir; }

    /**
      Return the full/complete path name for storing nvram
      (flash/EEPROM) files.
    */
    const FSNode& nvramDir() const { return myNVRamDir; }

  #ifdef CHEATCODE_SUPPORT
    /**
      Return the full/complete path name of the cheat file.
    */
    const FSNode& cheatFile() const { return myCheatFile; }
  #endif

  #ifdef DEBUGGER_SUPPORT
    /**
      Return the full/complete path name for storing Distella cfg files.
    */
    const FSNode& cfgDir() const { return myCfgDir; }
  #endif

  #ifdef IMAGE_SUPPORT
    /**
      Return the full/complete path name for saving snapshots, loading
      launcher images and loading bezels.
    */
    const FSNode& snapshotSaveDir();
    const FSNode& snapshotLoadDir();
    const FSNode& bezelDir();
  #endif

    /**
      Return the full/complete path name of the (optional) palette file.
    */
    const FSNode& paletteFile() const { return myPaletteFile; }

    /**
      Checks if a valid a user-defined palette file exists.
    */
    bool checkUserPalette(bool outputError = false) const;

    /**
      Return the full/complete path name of the currently loaded ROM.
    */
    const FSNode& romFile() const { return myRomFile; }

    /**
      The default and user defined locations for saving and loading various
      files that don't already have a specific location.
    */
    const FSNode& homeDir() const { return myHomeDir; }
    const FSNode& userDir() const { return myUserDir; }

    /**
      Open the given ROM and return an array containing its contents.
      Also, the properties database is updated with a valid ROM name
      for this ROM (if necessary).

      @param rom    The file node of the ROM to open (contains path)
      @param md5    The md5 calculated from the ROM file
                    (will be recalculated if necessary)
      @param size   The amount of data read into the image array

      @return  Unique pointer to the array
    */
    ByteBuffer openROM(const FSNode& rom, string& md5, size_t& size);

    /**
      Open the given ROM and return the MD5sum of the data.

      @param rom  The file node of the ROM to open (contains path)

      @return  MD5 of the ROM image (if valid), otherwise EmptyString
    */
    static string getROMMD5(const FSNode& rom);

    /**
      Creates a new game console from the specified romfile, and correctly
      initializes the system state to start emulation of the Console.

      @param rom     The FSNode of the ROM to use (contains path, etc)
      @param md5     The MD5sum of the ROM
      @param newrom  Whether this is a new ROM, or a reload of current one

      @return  String indicating any error message (EmptyString for no errors)
    */
    string createConsole(const FSNode& rom, string_view md5 = "",
                         bool newrom = true);

    /**
      Reloads the current console (essentially deletes and re-creates it).
      This can be thought of as a real console off/on toggle.

      @param nextrom  If true select next multicart ROM, else previous one

      @return  True on successful creation, otherwise false
    */
    bool reloadConsole(bool nextrom = true);

    /**
      Creates a new ROM launcher, to select a new ROM to emulate.

      @param startdir  The directory to use when opening the launcher;
                       if blank, use 'romdir' setting.

      @return  True on successful creation, otherwise false
    */
    bool createLauncher(string_view startdir = "");

    /**
      Answers whether the ROM launcher was actually successfully used
      at some point since the app started.

      @return  True if launcher was ever used, otherwise false
    */
    bool launcherUsed() const { return myLauncherUsed; }

    /**
      Answers whether the ROM launcher has lost focus after starting emulation.

      @return  True if launcher has lost focus, otherwise false
    */
    bool launcherLostFocus();

    /**
      Gets all possible info about the ROM by creating a temporary
      Console object and querying it.

      @param romfile  The file node of the ROM to use
      @return  Some information about this ROM
    */
    string getROMInfo(const FSNode& romfile);

    /**
      Toggle state rewind recording mode; this uses the RewindManager
      for its functionality. Also makes sure that audio samples are
      only saved if the recording mode is enabled.
    */
    void toggleTimeMachine();

    /**
      The features which are conditionally compiled into Stella.

      @return  The supported features
    */
    const string& features() const { return myFeatures; }

    /**
      The build information for Stella (toolkit version, architecture, etc).

      @return  The build info
    */
    const string& buildInfo() const { return myBuildInfo; }

    /**
      Issue a quit event to the OSystem.
    */
    void quit() { myQuitLoop = true; }

    /**
      Reset FPS measurement.
    */
    void resetFps();

    float frameRate() const;

    /**
      Attempt to override the base directory that will be used by derived
      classes, and use this one instead.  Note that this is only a hint;
      derived classes are free to ignore this, as some can't use an
      alternate base directory.

      Alternatively, attempt to use the application directory directly.
      Again, this is not supported on all systems, so it may be simply
      ignored.
    */
    static void overrideBaseDir(string_view path) { ourOverrideBaseDir = path; }
    static void overrideBaseDirWithApp() { ourOverrideBaseDirWithApp = true; }

    // Update the path of the user directory
    void setUserDir(string_view path);

  public:
    //////////////////////////////////////////////////////////////////////
    // The following methods are system-specific and can be overrided in
    // derived classes.  Otherwise, the base methods will be used.
    //////////////////////////////////////////////////////////////////////
    /**
      This method runs the main loop.  Since different platforms
      may use different timing methods and/or algorithms, this method can
      be overrided.  However, the port then takes all responsibility for
      running the emulation and taking care of timing.
    */
    virtual void mainLoop();

    /**
      Informs the OSystem of a change in EventHandler state.
    */
    virtual void stateChanged(EventHandlerState state) { }

    virtual shared_ptr<KeyValueRepository> getSettingsRepository() = 0;

    virtual shared_ptr<CompositeKeyValueRepository> getPropertyRepository() = 0;

    virtual shared_ptr<CompositeKeyValueRepositoryAtomic> getHighscoreRepository() = 0;

  protected:

    //////////////////////////////////////////////////////////////////////
    // The following methods are system-specific and *must* be
    // implemented in derived classes.
    //////////////////////////////////////////////////////////////////////
    /**
      Determine the base directory and home directory from the derived
      class.  It can also use hints, as described below.

      @param basedir  The base directory for all configuration files
      @param homedir  The default directory to store various other files
      @param useappdir  A hint that the base dir should be set to the
                        app directory; not all ports can do this, so
                        they are free to ignore it
      @param usedir     A hint that the base dir should be set to this
                        parameter; not all ports can do this, so
                        they are free to ignore it
    */
    virtual void getBaseDirectories(string& basedir, string& homedir,
                                    bool useappdir, string_view usedir) = 0;

    virtual void initPersistence(FSNode& basedir) = 0;

    virtual string describePresistence() = 0;

  protected:
    // Pointer to the EventHandler object
    unique_ptr<EventHandler> myEventHandler;

    // Pointer to the FrameBuffer object
    unique_ptr<FrameBuffer> myFrameBuffer;

    // Pointer to the Sound object
    unique_ptr<Sound> mySound;

    // Pointer to the Settings object
    unique_ptr<Settings> mySettings;

    // Pointer to the Random object
    unique_ptr<Random> myRandom;

    // Pointer to the PropertiesSet object
    unique_ptr<PropertiesSet> myPropSet;

    // Pointer to the (currently defined) Console object
    unique_ptr<Console> myConsole;

    // Pointer to audio settings object
    unique_ptr<AudioSettings> myAudioSettings;

  #ifdef CHEATCODE_SUPPORT
    // Pointer to the CheatManager object
    unique_ptr<CheatManager> myCheatManager;
  #endif

  #ifdef DEBUGGER_SUPPORT
    // Pointer to the Debugger object
    unique_ptr<Debugger> myDebugger;
  #endif

  #ifdef GUI_SUPPORT
    // Pointer to the OptionMenu object
    unique_ptr<OptionsMenu> myOptionsMenu;

    // Pointer to the CommandMenu object
    unique_ptr<CommandMenu> myCommandMenu;

    // Pointer to the HighScoresMenu object
    unique_ptr<HighScoresMenu> myHighScoresMenu;

    // Pointer to the Launcher object
    unique_ptr<Launcher> myLauncher;

    // Pointer to the MessageMenu object
    unique_ptr<MessageMenu> myMessageMenu;

    // Pointer to the PlusRomsMenu object
    unique_ptr<PlusRomsMenu> myPlusRomMenu;

    // Pointer to the TimeMachine object
    unique_ptr<TimeMachine> myTimeMachine;
  #endif

  #ifdef IMAGE_SUPPORT
    // PNG object responsible for loading/saving PNG images
    unique_ptr<PNGLibrary> myPNGLib;

    // JPG object responsible for loading/saving JPG images
    unique_ptr<JPGLibrary> myJPGLib;
  #endif

    // Pointer to the StateManager object
    unique_ptr<StateManager> myStateManager;

    // Pointer to the TimerManager object
    unique_ptr<TimerManager> myTimerManager;

  #ifdef GUI_SUPPORT
    // Pointer to the HighScoresManager object
    unique_ptr<HighScoresManager> myHighScoresManager;
  #endif

    // Indicates whether ROM launcher was ever opened during this run
    bool myLauncherUsed{false};

    // Indicates whether ROM launcher has focus after starting emulation
    bool myLauncherLostFocus{true};

    // Indicates whether to stop the main loop
    bool myQuitLoop{false};

  private:
    FSNode myBaseDir, myStateDir, mySnapshotSaveDir, mySnapshotLoadDir,
           myNVRamDir, myCfgDir, myHomeDir, myUserDir, myBezelDir;
    FSNode myCheatFile, myPaletteFile;
    FSNode myRomFile;  string myRomMD5;

    string myFeatures;
    string myBuildInfo;

    static constexpr uInt32 FPS_METER_QUEUE_SIZE = 100;
    FpsMeter myFpsMeter{FPS_METER_QUEUE_SIZE};

    // If not empty, a hint for derived classes to use this as the
    // base directory (where all settings are stored)
    // Derived classes are free to ignore it and use their own defaults
    static string ourOverrideBaseDir;
    static bool ourOverrideBaseDirWithApp;

  private:
    /**
      This method should be called to initiate the process of loading settings
      from the config file.  It takes care of loading settings, applying
      commandline overrides, and finally validating all settings.
    */
    void loadConfig(const Settings::Options& options);

    /**
      Creates the various sound devices available in this system
    */
    void createSound();

    /**
      Open the given ROM and return an array containing its contents.
      This method takes care of using only a valid size for the

      @param romfile  The file node of the ROM to open (contains path)
      @param size     The amount of data read into the image array
      @param showErrorMessage  Whether to show (or ignore) any errors
                               when opening the ROM

      @return  Unique pointer to the array, otherwise nullptr
    */
    static ByteBuffer openROM(const FSNode& romfile, size_t& size,
                              bool showErrorMessage);

    /**
      Creates an actual Console object based on the given info.

      @param romfile  The file node of the ROM to use (contains path)
      @param md5      The MD5sum of the ROM

      @return  The actual Console object, otherwise nullptr
    */
    unique_ptr<Console> openConsole(const FSNode& romfile, string& md5);

    /**
      Close and finalize any currently open console.
    */
    void closeConsole();

    /**
      Gets all possible info about the given console.

      @param console  The console to use
      @return  Some information about this console
    */
    static string getROMInfo(const Console& console);

    double dispatchEmulation(EmulationWorker& emulationWorker);

    // Following constructors and assignment operators not supported
    OSystem(const OSystem&) = delete;
    OSystem(OSystem&&) = delete;
    OSystem& operator=(const OSystem&) = delete;
    OSystem& operator=(OSystem&&) = delete;
};

#endif
