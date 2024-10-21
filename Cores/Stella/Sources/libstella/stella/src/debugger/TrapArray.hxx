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

#ifndef TRAP_ARRAY_HXX
#define TRAP_ARRAY_HXX

#include "bspf.hxx"

class TrapArray
{
  public:
    TrapArray() = default;

    inline bool isSet(const uInt16 address) const { return myCount[address]; }
    inline bool isClear(const uInt16 address) const { return myCount[address] == 0; }

    void add(const uInt16 address) { myCount[address]++; }
    void remove(const uInt16 address) { myCount[address]--; }
    // void toggle(uInt16 address) { myCount[address] ? remove(address) : add(address); } // TODO condition

    void initialize() {
      if(!myInitialized)
        myCount.fill(0);
      myInitialized = true;
    }
    void clearAll() { myInitialized = false; myCount.fill(0); }

    inline bool isInitialized() const { return myInitialized; }

  private:
    // The actual counts
    std::array<uInt8, 0x10000> myCount;

    // Indicates whether we should treat this array as initialized
    bool myInitialized{false};

  private:
    // Following constructors and assignment operators not supported
    TrapArray(const TrapArray&) = delete;
    TrapArray(TrapArray&&) = delete;
    TrapArray& operator=(const TrapArray&) = delete;
    TrapArray& operator=(TrapArray&&) = delete;
};

#endif
