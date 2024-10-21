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

#ifndef TIMER_MAP_HXX
#define TIMER_MAP_HXX

#include <cmath>
#include <map>
#include <deque>

#include "bspf.hxx"

/**
  This class handles debugger timers. Each timer needs a 'from' and a 'to'
  address.

  @author  Thomas Jentzsch
*/
class TimerMap
{
  private:
    static constexpr uInt16 ADDRESS_MASK = 0x1fff;  // either 0x1fff or 0xffff (not needed then)
    static constexpr uInt8 ANY_BANK = 255;  // timer point valid in any bank

  private:
    struct TimerPoint
    {
      uInt16 addr{0};
      uInt8  bank{ANY_BANK};

      explicit constexpr TimerPoint(uInt16 c_addr, uInt8 c_bank)
        : addr{c_addr}, bank{c_bank} {}

      TimerPoint()
        : addr{0}, bank(ANY_BANK) {}

      bool operator<(const TimerPoint& other) const
      {
        if(bank == ANY_BANK || other.bank == ANY_BANK)
          return addr < other.addr;

        return bank < other.bank || (bank == other.bank && addr < other.addr);
      }
    };

  public:
    struct Timer
    {
      TimerPoint from{};
      TimerPoint to{};
      bool   mirrors{false};
      bool   anyBank{false};
      bool   isPartial{false};

      uInt64 execs{0};
      uInt64 lastCycles{0};
      uInt64 totalCycles{0};
      uInt64 minCycles{ULONG_MAX};
      uInt64 maxCycles{0};
      bool   isStarted{false};

      explicit constexpr Timer(const TimerPoint& c_from, const TimerPoint& c_to,
                               bool c_mirrors = false, bool c_anyBank = false)
        : from{c_from}, to{c_to}, mirrors{c_mirrors}, anyBank{c_anyBank} {}

      Timer(uInt16 fromAddr, uInt16 toAddr, uInt8 fromBank, uInt8 toBank,
            bool c_mirrors = false, bool c_anyBank = false)
      {
        Timer(TimerPoint(fromAddr, fromBank), TimerPoint(fromAddr, fromBank),
              c_mirrors, c_anyBank);
      }

      explicit Timer(const TimerPoint& tp, bool c_mirrors = false,
                     bool c_anyBank = false)
        : from{tp}, mirrors{c_mirrors}, anyBank{c_anyBank}, isPartial{true} {}

      Timer(uInt16 addr, uInt8 bank, bool c_mirrors = false,
            bool c_anyBank = false)
      {
        Timer(TimerPoint(addr, bank), c_mirrors, c_anyBank);
      }

      void setTo(const TimerPoint& tp, bool c_mirrors = false,
                 bool c_anyBank = false)
      {
        to = tp;
        mirrors |= c_mirrors;
        anyBank |= c_anyBank;
        isPartial = false;
      }

      void reset()
      {
        execs = lastCycles = totalCycles = maxCycles = 0;
        minCycles = ULONG_MAX;
      }

      // Start the timer
      void start(uInt64 cycles)
      {
        lastCycles = cycles;
        isStarted = true;
      }

      // Stop the timer and update stats
      void stop(uInt64 cycles)
      {
        if(isStarted)
        {
          const uInt64 diffCycles = cycles - lastCycles;

          ++execs;
          totalCycles += diffCycles;
          minCycles = std::min(minCycles, diffCycles);
          maxCycles = std::max(maxCycles, diffCycles);
          isStarted = false;
        }
      }

      uInt32 averageCycles() const {
        return execs ? std::round(totalCycles / execs) : 0; }
    }; // Timer

    explicit TimerMap() = default;

    inline bool isInitialized() const { return myList.size(); }

    /** Add new timer */
    uInt32 add(uInt16 fromAddr, uInt16 toAddr,
               uInt8 fromBank, uInt8 toBank,
               bool mirrors, bool anyBank);
    uInt32 add(uInt16 addr, uInt8 bank,
               bool mirrors, bool anyBank);

    /** Erase timer */
    bool erase(const uInt32 idx);

    /** Clear all timers */
    void clear();

    /** Reset all timers */
    void reset();

    /** Get timer */
    const Timer& get(uInt32 idx) const { return myList[idx]; }
    uInt32 size() const { return static_cast<uInt32>(myList.size()); }

    /** Update timer */
    void update(uInt16 addr, uInt8 bank,
                const uInt64 cycles);

  private:
    static void toKey(TimerPoint& tp, bool mirrors, bool anyBank);

  private:
    using TimerList = std::deque<Timer>; // makes sure that the element pointers do NOT change
    using TimerPair = std::pair<TimerPoint, Timer*>;
    using FromMap = std::multimap<TimerPoint, Timer*>;
    using ToMap = std::multimap<TimerPoint, Timer*>;

    TimerList myList;
    FromMap myFromMap;
    ToMap myToMap;

    // Following constructors and assignment operators not supported
    TimerMap(const TimerMap&) = delete;
    TimerMap(TimerMap&&) = delete;
    TimerMap& operator=(const TimerMap&) = delete;
    TimerMap& operator=(TimerMap&&) = delete;
};

#endif
