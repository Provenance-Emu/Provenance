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

#ifndef STATE_MANAGER_HXX
#define STATE_MANAGER_HXX

#define STATE_HEADER "06070002state"

class OSystem;
class RewindManager;

#include "Serializer.hxx"

/**
  This class provides an interface to all things related to emulation state.
  States can be loaded or saved here, as well as recorded, rewound, and later
  played back.

  @author  Stephen Anthony
*/
class StateManager
{
  public:
    enum class Mode {
      Off,
      TimeMachine,
      MovieRecord,
      MoviePlayback
    };

    /**
      Create a new statemananger class.
    */
    explicit StateManager(OSystem& osystem);
    ~StateManager();

  public:
    /**
      Answers whether the manager is in record or playback mode.
    */
    Mode mode() const { return myActiveMode; }

#if 0
    /**
      Toggle movie recording mode (FIXME - currently disabled)
    */
    void toggleRecordMode();
#endif

    /**
      Toggle state rewind recording mode; this uses the RewindManager
      for its functionality.
    */
    void toggleTimeMachine();

    /**
      Sets state rewind recording mode; this uses the RewindManager
      for its functionality.
    */
    void setRewindMode(Mode mode) { myActiveMode = mode; }

    /**
      Optionally adds one extra state when entering the Time Machine dialog;
      this uses the RewindManager for its functionality.
    */
    bool addExtraState(string_view message);

    /**
      Rewinds states; this uses the RewindManager for its functionality.
    */
    bool rewindStates(uInt32 numStates = 1);

    /**
      Unwinds states; this uses the RewindManager for its functionality.
    */
    bool unwindStates(uInt32 numStates = 1);

    /**
      Rewinds/unwinds states; this uses the RewindManager for its functionality.
    */
    bool windStates(uInt32 numStates, bool unwind);

    /**
      Updates the state of the system based on the currently active mode.
    */
    void update();

    /**
      Load a state into the current system.

      @param slot  The state 'slot' to load state from
    */
    void loadState(int slot = -1);

    /**
      Save the current state from the system.

      @param slot  The state 'slot' to save into
    */
    void saveState(int slot = -1);

    /**
      Switches to the next higher or lower state slot (circular queue style).

      @param direction  +1 indicates increase, -1 indicates decrease.
    */
    void changeState(int direction = +1);

    /**
      Toggles auto slot mode.
    */
    void toggleAutoSlot();

    /**
      Load a state into the current system from the given Serializer.
      No messages are printed to the screen.

      @param in  The Serializer object to use

      @return  False on any load errors, else true
    */
    bool loadState(Serializer& in);

    /**
      Save the current state from the system into the given Serializer.
      No messages are printed to the screen.

      @param out  The Serializer object to use

      @return  False on any save errors, else true
    */
    bool saveState(Serializer& out);

    /**
      Resets manager to defaults.
    */
    void reset();

    /**
      Returns the current slot number
    */
    int currentSlot() const { return myCurrentSlot; }

    /**
      The rewind facility for the state manager
    */
    RewindManager& rewindManager() const { return *myRewindManager; }

  private:
    // The parent OSystem object
    OSystem& myOSystem;

    // The current slot for load/save states
    int myCurrentSlot{0};

    // Whether the manager is in record or playback mode
    Mode myActiveMode{Mode::Off};

    // MD5 of the currently active ROM (either in movie or rewind mode)
    string myMD5;

#if 0
    // Serializer classes used to save/load the eventstream
    Serializer myMovieWriter;
    Serializer myMovieReader;
#endif

    // Stored savestates to be later rewound
    unique_ptr<RewindManager> myRewindManager;

  private:
    // Following constructors and assignment operators not supported
    StateManager() = delete;
    StateManager(const StateManager&) = delete;
    StateManager(StateManager&&) = delete;
    StateManager& operator=(const StateManager&) = delete;
    StateManager& operator=(StateManager&&) = delete;
};

#endif
