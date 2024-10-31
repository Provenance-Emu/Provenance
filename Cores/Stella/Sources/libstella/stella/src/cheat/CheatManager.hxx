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

#ifndef CHEAT_MANAGER_HXX
#define CHEAT_MANAGER_HXX

#include <map>

class Cheat;
class OSystem;

#include "bspf.hxx"

using CheatList = vector<shared_ptr<Cheat>>;

/**
  This class provides an interface for performing all cheat operations
  in Stella.  It is accessible from the OSystem interface, and contains
  the list of all cheats currently in use.

  @author  Stephen Anthony
*/
class CheatManager
{
  public:
    explicit CheatManager(OSystem& osystem);

    /**
      Adds the specified cheat to an internal list.

      @param name    Name of the cheat (not absolutely required)
      @param code    The actual cheatcode (in hex)
      @param enable  Whether to enable this cheat right away
      @param idx     Index at which to insert the cheat

      @return  Whether the cheat was created and enabled.
    */
    bool add(string_view name, string_view code,
             bool enable = true, int idx = -1);

    /**
      Remove the cheat at 'idx' from the cheat list(s).

      @param idx  Location in myCheatList of the cheat to remove
    */
    void remove(int idx);

    /**
      Adds the specified cheat to the internal per-frame list.
      This method doesn't create a new cheat; it just adds/removes
      an already created cheat to the per-frame list.

      @param name    Name of the cheat
      @param code    The actual cheatcode
      @param enable  Add or remove the cheat to the per-frame list
    */
    void addPerFrame(string_view name, string_view code, bool enable);

    /**
      Creates and enables a one-shot cheat.  One-shot cheats are the
      same as normal cheats, except they are only enabled once, and
      they're not saved at all.

      @param name  Name of the cheat (not absolutely required)
      @param code  The actual cheatcode (in hex)
    */
    void addOneShot(string_view name, string_view code);

    /**
      Enable/disabled the cheat specified by the given code.

      @param code    The actual cheatcode to search for
      @param enable  Enable/disable the cheat
    */
    void enable(string_view code, bool enable);

    /**
      Returns the game cheatlist.
    */
    const CheatList& list() { return myCheatList; }

    /**
      Returns the per-frame cheatlist (needed to evaluate cheats each frame)
    */
    const CheatList& perFrame() { return myPerFrameList; }

    /**
      Load all cheats (for all ROMs) from disk to internal database.
    */
    void loadCheatDatabase();

    /**
      Save all cheats (for all ROMs) in internal database to disk.
    */
    void saveCheatDatabase();

    /**
      Load cheats for ROM with given MD5sum to cheatlist(s).
    */
    void loadCheats(string_view md5sum);

    /**
      Saves cheats for ROM with given MD5sum to cheat map.
    */
    void saveCheats(string_view md5sum);

    /**
      Checks if a code is valid.
    */
    static bool isValidCode(string_view code);

  private:
    /**
      Create a cheat defined by the given code.

      @param name  Name of the cheat (not absolutely required)
      @param code  The actual cheatcode (in hex)

      @return  The cheat (if was created), else nullptr.
    */
    shared_ptr<Cheat> createCheat(string_view name, string_view code) const;

    /**
      Parses a list of cheats and adds/enables each one.

      @param cheats  Comma-separated list of cheats (without any names)
    */
    void parse(string_view cheats);

  private:
    OSystem& myOSystem;

    CheatList myCheatList;
    CheatList myPerFrameList;

    std::map<string,string, std::less<>> myCheatMap;
    string myCheatFile;

    // This is set each time a new cheat/ROM is loaded, for later
    // comparison to see if the cheatcode list has actually been modified
    string myCurrentCheat;

    // Indicates that the list has been modified, and should be saved to disk
    bool myListIsDirty{false};

  private:
    // Following constructors and assignment operators not supported
    CheatManager() = delete;
    CheatManager(const CheatManager&) = delete;
    CheatManager(CheatManager&&) = delete;
    CheatManager& operator=(const CheatManager&) = delete;
    CheatManager& operator=(CheatManager&&) = delete;
};

#endif
