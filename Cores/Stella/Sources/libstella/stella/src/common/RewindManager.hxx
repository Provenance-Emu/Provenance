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

#ifndef REWIND_MANAGER_HXX
#define REWIND_MANAGER_HXX

class OSystem;
class StateManager;

#include "LinkedObjectPool.hxx"
#include "bspf.hxx"

/**
  This class is used to save (and later 'replay') system save states.
  In this implementation, we assume states are added at the end of the list.

  Rewinding involves moving the internal iterator backwards in time (towards
  the beginning of the list).

  Unwinding involves moving the internal iterator forwards in time (towards
  the end of the list).

  Any time a new state is added, all states from the current iterator position
  to the end of the list (aka, all future states) are removed, and the internal
  iterator moves to the insertion point of the data (the end of the list).

  If the list is full, states are either removed at the beginning (compression
  off) or at selective positions (compression on).

  @author  Stephen Anthony
*/
class RewindManager
{
  public:
    RewindManager(OSystem& system, StateManager& statemgr);

  public:
    static constexpr uInt32 MAX_BUF_SIZE = 1000;
    static constexpr int NUM_INTERVALS = 7;
    // cycle values for the intervals
    const std::array<uInt32, NUM_INTERVALS> INTERVAL_CYCLES = {
      76 * 262,
      76 * 262 * 3,
      76 * 262 * 10,
      76 * 262 * 30,
      76 * 262 * 60,
      76 * 262 * 60 * 3,
      76 * 262 * 60 * 10
    };
    // settings values for the intervals
    const std::array<string, NUM_INTERVALS> INT_SETTINGS = {
      "1f",
      "3f",
      "10f",
      "30f",
      "1s",
      "3s",
      "10s"
    };

    static constexpr int NUM_HORIZONS = 8;
    // cycle values for the horzions
    const std::array<uInt64, NUM_HORIZONS> HORIZON_CYCLES = {
      uInt64{76} * 262 * 60 * 3,
      uInt64{76} * 262 * 60 * 10,
      uInt64{76} * 262 * 60 * 30,
      uInt64{76} * 262 * 60 * 60,
      uInt64{76} * 262 * 60 * 60 * 3,
      uInt64{76} * 262 * 60 * 60 * 10,
      uInt64{76} * 262 * 60 * 60 * 30,
      uInt64{76} * 262 * 60 * 60 * 60
    };
    // settings values for the horzions
    const std::array<string, NUM_HORIZONS> HOR_SETTINGS = {
      "3s",
      "10s",
      "30s",
      "1m",
      "3m",
      "10m",
      "30m",
      "60m"
    };

    /**
      Initializes state list and calculates compression factor.
    */
    void setup();

    /**
      Add a new state file with the given message; this message will be
      displayed when the state is replayed.

      @param message  Message to display when replaying this state
    */
    bool addState(string_view message, bool timeMachine = false);

    /**
      Rewind numStates levels of the state list, and display the message associated
      with that state.

      @param numStates  Number of states to rewind
      @return           Number of states to rewinded
    */
    uInt32 rewindStates(uInt32 numStates = 1);

    /**
      Unwind numStates levels of the state list, and display the message associated
      with that state.

      @param numStates  Number of states to unwind
      @return           Number of states to unwinded
    */
    uInt32 unwindStates(uInt32 numStates = 1);

    /**
      Rewind/unwind numStates levels of the state list, and display the message associated
      with that state.

      @param numStates  Number of states to wind
      @param unwind     unwind or rewind
      @return           Number of states to winded
    */
    uInt32 windStates(uInt32 numStates, bool unwind);

    string saveAllStates();
    string loadAllStates();

    bool atFirst() const { return myStateList.atFirst(); }
    bool atLast() const  { return myStateList.atLast();  }
    void resize(uInt32 size) { myStateList.resize(size); }
    void clear() {
      myStateList.clear();
    }

    /**
      Convert the cycles into a unit string.
    */
    string getUnitString(Int64 cycles);

    uInt32 getCurrentIdx() { return myStateList.currentIdx(); }
    uInt32 getLastIdx() { return myStateList.size(); }

    uInt64 getFirstCycles() const;
    uInt64 getCurrentCycles() const;
    uInt64 getLastCycles() const;
    uInt64 getInterval() const { return myInterval; }

    /**
      Get a collection of cycle timestamps, offset from the first one in
      the list.  This also determines the number of states in the list.
    */
    IntArray cyclesList() const;

  private:
    OSystem& myOSystem;
    StateManager& myStateManager;

    uInt32 mySize{0};
    uInt32 myUncompressed{0};
    uInt32 myInterval{0};
    uInt64 myHorizon{0};
    double myFactor{0.0};
    bool   myLastTimeMachineAdd{false};

    struct RewindState {
      Serializer data;  // actual save state
      string message;   // describes save state origin
      uInt64 cycles{0}; // cycles since emulation started

      // We do nothing on object instantiation or copy
      // The goal of LinkedObjectPool is to not do any allocations at all
      RewindState() = default;
      ~RewindState() = default;
      RewindState(const RewindState& rs) : cycles(rs.cycles) { }
      RewindState& operator= (const RewindState& rs) { cycles = rs.cycles; return *this; }
      RewindState(RewindState&&) = default;
      RewindState& operator=(RewindState&&) = default;

      // Output object info; used for debugging only
      friend ostream& operator<<(ostream& os, const RewindState& s) {
        return os << "msg: " << s.message << "   cycle: " << s.cycles;
      }
    };

    // The linked-list to store states (internally it takes care of reducing
    // frequent (de)-allocations)
    Common::LinkedObjectPool<RewindState> myStateList;

    /**
      Remove a save state from the list
    */
    void compressStates();

    /**
      Load the current state and get the message string for the rewind/unwind

      @return  The message
    */
    string loadState(Int64 startCycles, uInt32 numStates);

  private:
    // Following constructors and assignment operators not supported
    RewindManager() = delete;
    RewindManager(const RewindManager&) = delete;
    RewindManager(RewindManager&&) = delete;
    RewindManager& operator=(const RewindManager&) = delete;
    RewindManager& operator=(RewindManager&&) = delete;
};

#endif
