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

#ifndef BREAKPOINT_HXX
#define BREAKPOINT_HXX

#include <unordered_map>

#include "bspf.hxx"

/**
  This class handles simple debugger breakpoints.

  @author  Thomas Jentzsch
*/
class BreakpointMap
{
  private:
    static constexpr uInt16 ADDRESS_MASK = 0x1fff;  // either 0x1fff or 0xffff (not needed then)

  public:
    // breakpoint flags
    static constexpr uInt32 ONE_SHOT = 1 << 0;      // used for 'trace' command
    static constexpr uInt8 ANY_BANK = 255;          // breakpoint valid in any bank

    struct Breakpoint
    {
      uInt16 addr{0};
      uInt8 bank{0};

      explicit constexpr Breakpoint(uInt16 c_addr, uInt8 c_bank) : addr{c_addr}, bank{c_bank} { }

      bool operator==(const Breakpoint& other) const
      {
        if(addr == other.addr)
        {
          if(bank == ANY_BANK || other.bank == ANY_BANK)
            return true;
          else
            return bank == other.bank;
        }
        return false;
      }
      bool operator<(const Breakpoint& other) const
      {
        return bank < other.bank || (bank == other.bank && addr < other.addr);
      }
    };
    using BreakpointList = std::vector<Breakpoint>;

    BreakpointMap() = default;

    inline bool isInitialized() const { return myInitialized; }

    /** Add new breakpoint */
    void add(const Breakpoint& breakpoint, const uInt32 flags = 0);
    void add(const uInt16 addr, const uInt8 bank, const uInt32 flags = 0);

    /** Erase breakpoint */
    void erase(const Breakpoint& breakpoint);
    void erase(const uInt16 addr, const uInt8 bank);

    /** Get info for breakpoint */
    uInt32 get(const Breakpoint& breakpoint) const;
    uInt32 get(uInt16 addr, uInt8 bank) const;

    /** Check if a breakpoint exists */
    bool check(const Breakpoint& breakpoint) const;
    bool check(const uInt16 addr, const uInt8 bank) const;

    /** Returns a sorted list of breakpoints */
    BreakpointList getBreakpoints() const;

    /** clear all breakpoints */
    void clear() { myMap.clear(); }
    size_t size() const { return myMap.size(); }

  private:
    static Breakpoint convertBreakpoint(const Breakpoint& breakpoint);

    struct BreakpointHash {
      size_t operator()(const Breakpoint& bp) const {
        return std::hash<uInt64>()(
          uInt64(bp.addr) * 13 // only check for address, bank check via == operator
        );
      }
    };

    std::unordered_map<Breakpoint, uInt32, BreakpointHash> myMap;
    bool myInitialized{false};

    // Following constructors and assignment operators not supported
    BreakpointMap(const BreakpointMap&) = delete;
    BreakpointMap(BreakpointMap&&) = delete;
    BreakpointMap& operator=(const BreakpointMap&) = delete;
    BreakpointMap& operator=(BreakpointMap&&) = delete;
};

#endif
