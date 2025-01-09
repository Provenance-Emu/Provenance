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

#ifndef CONSOLE_HXX
#define CONSOLE_HXX

class Event;
class Switches;
class System;
class TIA;
class M6502;
class M6532;
class Cartridge;
class CompuMate;
class Debugger;
class AudioQueue;
class AudioSettings;
class DevSettingsHandler;

#include "bspf.hxx"
#include "ConsoleIO.hxx"
#include "Control.hxx"
#include "Props.hxx"
#include "TIAConstants.hxx"
#include "FrameBuffer.hxx"
#include "FrameBufferConstants.hxx"
#include "Serializable.hxx"
#include "EventHandlerConstants.hxx"
#include "EmulationTiming.hxx"
#include "ConsoleTiming.hxx"
#include "frame-manager/AbstractFrameManager.hxx"

/**
  Contains detailed info about a console.
*/
struct ConsoleInfo
{
  string BankSwitch;
  string CartName;
  string CartMD5;
  string Control0;
  string Control1;
  string DisplayFormat;
};

/**
  This class represents the entire game console.

  @author  Bradford W. Mott
*/
class Console : public Serializable, public ConsoleIO
{
  public:
    /**
      Create a new console for emulating the specified game using the
      given game image and operating system.

      @param osystem  The OSystem object to use
      @param cart     The cartridge to use with this console
      @param props    The properties for the cartridge
    */
    Console(OSystem& osystem, unique_ptr<Cartridge>& cart,
            const Properties& props, AudioSettings& audioSettings);
    ~Console() override;

  public:
    /**
      Sets the left and right controllers for the console.
    */
    void setControllers(string_view romMd5);

    /**
      Get the controller plugged into the specified jack

      @return The specified controller
    */
    Controller& leftController() const override { return *myLeftControl;  }
    Controller& rightController() const override { return *myRightControl; }

    /**
      Change to next or previous controller type
    */
    void changeLeftController(int direction = +1);
    void changeRightController(int direction = +1);

    /**
      Get the TIA for this console

      @return The TIA
    */
    TIA& tia() const { return *myTIA; }

    /**
      Get the properties being used by the game

      @return The properties being used by the game
    */
    const Properties& properties() const { return myProperties; }

    /**
      Get the console switches

      @return The console switches
    */
    Switches& switches() const override { return *mySwitches; }

    /**
      Get the 6502 based system used by the console to emulate the game

      @return The 6502 based system
    */
    System& system() const { return *mySystem; }

    /**
      Get the cartridge used by the console which contains the ROM code

      @return The cartridge for this console
    */
    Cartridge& cartridge() const { return *myCart; }

    /**
      Get the 6532 used by the console

      @return The 6532 for this console
    */
    M6532& riot() const { return *myRiot; }

    /**
      Saves the current state of this console class to the given Serializer.

      @param out The serializer device to save to.
      @return The result of the save.  True on success, false on failure.
    */
    bool save(Serializer& out) const override;

    /**
      Loads the current state of this console class from the given Serializer.

      @param in The Serializer device to load from.
      @return The result of the load.  True on success, false on failure.
    */
    bool load(Serializer& in) override;

    /**
      Set the properties to those given

      @param props The properties to use for the current game
    */
    void setProperties(const Properties& props);

    /**
      Query detailed information about this console.
    */
    const ConsoleInfo& about() const { return myConsoleInfo; }

    /**
      Timing information for this console.
    */
    ConsoleTiming timing() const { return myConsoleTiming; }

    /**
      Set up the console to use the debugger.
    */
    void attachDebugger(Debugger& dbg);

    /**
      Informs the Console of a change in EventHandler state.
    */
    void stateChanged(EventHandlerState state);

    /**
      Retrieve emulation timing provider.
     */
    EmulationTiming& emulationTiming() { return myEmulationTiming; }

    /**
      Toggle left and right controller ports swapping
    */
    void toggleSwapPorts(bool toggle = true);

    /**
      Toggle paddle controllers swapping
    */
    void toggleSwapPaddles(bool toggle = true);

    /**
      Change x-center of paddles
    */
    void changePaddleCenterX(int direction = +1);

    /**
      Change y-center of paddles
    */
    void changePaddleCenterY(int direction = +1);

    /**
      Change paddle range for digital/mouse emulation
    */
    void changePaddleAxesRange(int direction = +1);

  public:
    /**
      Switch between NTSC/PAL/SECAM (and variants) display format.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void selectFormat(int direction = +1);

    /**
      Set NTSC/PAL/SECAM (and variants) display format.
    */
    void setFormat(uInt32 format, bool force = false);

    /**
      Get NTSC/PAL/SECAM (and variants) display format name
    */
    string getFormatString() const { return myDisplayFormat; }

    /**
      Toggle interpolation on/off
    */
    void toggleInter(bool toggle = true);

    /**
      Toggle turbo mode on/off
    */
    void toggleTurbo();

    /**
      Change emulation speed

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeSpeed(int direction = +1);

    /**
      Toggles phosphor effect.
    */
    void togglePhosphor(bool toggle = true);

    /**
      Toggles auto-phosphor.
    */
    void cyclePhosphorMode(int direction = +1);

    /**
      Change the "Display.PPBlend" variable.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changePhosphor(int direction = +1);

    /**
      Toggles the PAL color-loss effect.
    */
    void toggleColorLoss(bool toggle = true);
    void enableColorLoss(bool state);

    /**
      Initialize the video subsystem wrt this class.
      This is required for changing window size, title, etc.

      @param full  Whether we want a full initialization,
                   or only reset certain attributes.

      @return  The results from FrameBuffer::initialize()
    */
    FBInitStatus initializeVideo(bool full = true);

    /**
      Initialize the audio subsystem wrt this class.
      This is required any time the sound settings change.
    */
    void initializeAudio();

    /**
      "Fry" the Atari (mangle memory/TIA contents)
    */
    void fry() const;

    /**
      Change the "Display.VCenter" variable.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeVerticalCenter(int direction = +1);

    /**
      Change the "TIA scanline adjust" variable.
      Note that there are currently two of these (NTSC and PAL).  The currently
      active mode will determine which one is used.

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeVSizeAdjust(int direction = +1);

    /**
      Toggle the aspect ratio correction.
    */
    void toggleCorrectAspectRatio(bool toggle = true);

    /**
      Returns the current framerate.  Note that this is the actual,
      dynamic frame rate while a game is running.
    */
    float currentFrameRate() const;

    /**
      Retrieve the current game's refresh rate.  Note that this is a
      static, basic frame rate based on the current TV format.
    */
    int gameRefreshRate() const;

    /**
      Toggle between developer settings sets (player/developer)
    */
    void toggleDeveloperSet(bool toggle = true);

    /**
      Toggles the TIA bit specified in the method name.
    */
    void toggleP0Bit(bool toggle = true) const { toggleTIABit(P0Bit, "P0", true, toggle); }
    void toggleP1Bit(bool toggle = true) const { toggleTIABit(P1Bit, "P1", true, toggle); }
    void toggleM0Bit(bool toggle = true) const { toggleTIABit(M0Bit, "M0", true, toggle); }
    void toggleM1Bit(bool toggle = true) const { toggleTIABit(M1Bit, "M1", true, toggle); }
    void toggleBLBit(bool toggle = true) const { toggleTIABit(BLBit, "BL", true, toggle); }
    void togglePFBit(bool toggle = true) const { toggleTIABit(PFBit, "PF", true, toggle); }
    void toggleBits(bool toggle = true) const;

    /**
      Toggles the TIA collisions specified in the method name.
    */
    void toggleP0Collision(bool toggle = true) const { toggleTIACollision(P0Bit, "P0", true, toggle); }
    void toggleP1Collision(bool toggle = true) const { toggleTIACollision(P1Bit, "P1", true, toggle); }
    void toggleM0Collision(bool toggle = true) const { toggleTIACollision(M0Bit, "M0", true, toggle); }
    void toggleM1Collision(bool toggle = true) const { toggleTIACollision(M1Bit, "M1", true, toggle); }
    void toggleBLCollision(bool toggle = true) const { toggleTIACollision(BLBit, "BL", true, toggle); }
    void togglePFCollision(bool toggle = true) const { toggleTIACollision(PFBit, "PF", true, toggle); }
    void toggleCollisions(bool toggle = true) const;

    /**
      Toggles the TIA 'fixed debug colors' mode.
    */
    void toggleFixedColors(bool toggle = true) const;

    /**
      Toggles the TIA 'scanline jitter' mode.
    */
    void toggleJitter(bool toggle = true) const;

    /**
      Changes the TIA 'scanline jitter' sensitivity.
    */
    void changeJitterSense(int direction = +1) const;

    /**
      Changes the TIA 'scanline jitter' revcovery rate.
    */
    void changeJitterRecovery(int direction = +1) const;

    /**
      Return whether vertical sync length is according to spec.
    */
    bool vsyncCorrect() const { return myFrameManager->vsyncCorrect(); }

    /**
     * Update vcenter
     */
    void updateVcenter(Int32 vcenter);

    /**
      Set up various properties of the TIA (vcenter, Height, etc) based on
      the current display format.
    */
    void setTIAProperties();

    /**
      Toggle autofire for all controllers
    */
    void toggleAutoFire(bool toggle = true);

    /**
      Change the autofire speed for all controllers
    */
    void changeAutoFireRate(int direction = +1);

  private:
    /**
     * Define console timing based on current display format
     */
    void setConsoleTiming();

    /**
     * Dry-run the emulation and detect the frame layout (PAL / NTSC).
     */
    void autodetectFrameLayout(bool reset = true);

    /**
     * Rerun frame layout autodetection
     */
    void redetectFrameLayout();

    /**
     * Determine display format by filename
     * Returns "AUTO" if nothing is found
     */
    string formatFromFilename() const;

    /**
      Create the audio queue
     */
    void createAudioQueue();

    /**
      Selects the left or right controller depending on ROM properties
    */
    unique_ptr<Controller> getControllerPort(const Controller::Type type,
                                             const Controller::Jack port,
                                             string_view romMd5);

    void toggleTIABit(TIABit bit, string_view bitname,
                      bool show = true, bool toggle = true) const;
    void toggleTIACollision(TIABit bit, string_view bitname,
                            bool show = true, bool toggle = true) const;

  private:
    // Reference to the osystem object
    OSystem& myOSystem;

    // Reference to the event object to use
    const Event& myEvent;

    // Properties for the game
    Properties myProperties;

    // Pointer to the 6502 based system being emulated
    unique_ptr<System> mySystem;

    // Pointer to the M6502 CPU
    unique_ptr<M6502> my6502;

    // Pointer to the 6532 (aka RIOT) (the debugger needs it)
    // A RIOT of my own! (...with apologies to The Clash...)
    unique_ptr<M6532> myRiot;

    // Pointer to the TIA object
    unique_ptr<TIA> myTIA;

    // The frame manager instance that is used during emulation
    unique_ptr<AbstractFrameManager> myFrameManager;

    // The audio fragment queue that connects TIA and audio driver
    shared_ptr<AudioQueue> myAudioQueue;

    // Pointer to the Cartridge (the debugger needs it)
    unique_ptr<Cartridge> myCart;

    // Pointer to the switches on the front of the console
    unique_ptr<Switches> mySwitches;

    // Pointers to the left and right controllers
    unique_ptr<Controller> myLeftControl, myRightControl;

    // Pointer to handler for switching developer settings sets
    unique_ptr<DevSettingsHandler> myDevSettingsHandler;

    // Pointer to CompuMate handler (only used in CompuMate ROMs)
    shared_ptr<CompuMate> myCMHandler;

    // The currently defined display format (NTSC/PAL/SECAM)
    string myDisplayFormat;

    // Display format currently in use
    uInt32 myCurrentFormat{0};

    // Is the TV format autodetected?
    bool myFormatAutodetected{false};

    // Contains detailed info about this console
    ConsoleInfo myConsoleInfo;

    // Contains timing information for this console
    ConsoleTiming myConsoleTiming{ConsoleTiming::ntsc};

    // Emulation timing provider. This ties together the timing of the core emulation loop
    // and the parameters that govern audio synthesis
    EmulationTiming myEmulationTiming;

    // The audio settings
    AudioSettings& myAudioSettings;

  private:
    // Following constructors and assignment operators not supported
    Console() = delete;
    Console(const Console&) = delete;
    Console(Console&&) = delete;
    Console& operator=(const Console&) = delete;
    Console& operator=(Console&&) = delete;
};

#endif
