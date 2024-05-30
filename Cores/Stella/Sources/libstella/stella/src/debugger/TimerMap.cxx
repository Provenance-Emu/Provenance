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

#include "TimerMap.hxx"

/*
  TODOs:
    x unordered_multimap (not required for just a few timers)
    o 13 vs 16 bit, use ADDRESS_MASK & ANY_BANK, when???
      - never, unless the user defines * for the bank
    o any bank
      - never unless the user defines *
    ? timer line display in disassembly? (color, symbol,...?)
    - keep original from and to addresses for label display
*/

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimerMap::toKey(TimerPoint& tp, bool mirrors, bool anyBank)
{
  if(mirrors)
    tp.addr &= ADDRESS_MASK;
  if(anyBank)
    tp.bank = ANY_BANK;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 TimerMap::add(uInt16 fromAddr, uInt16 toAddr,
                     uInt8 fromBank, uInt8 toBank,
                     bool mirrors, bool anyBank)
{
  TimerPoint tpFrom(fromAddr, fromBank);
  TimerPoint tpTo(toAddr, toBank);
  const Timer complete(tpFrom, tpTo, mirrors, anyBank);

  myList.push_back(complete);
  toKey(tpFrom, mirrors, anyBank);
  toKey(tpTo, mirrors, anyBank);
  myFromMap.insert(TimerPair(tpFrom, &myList.back()));
  myToMap.insert(TimerPair(tpTo, &myList.back()));

  return size() - 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 TimerMap::add(uInt16 addr, uInt8 bank, bool mirrors, bool anyBank)
{
  uInt32 idx = size() - 1;
  uInt32 i = 0; // find first incomplete timer, if any
  for(auto it = myList.begin(); it != myList.end(); ++it, ++i)
    if(it->isPartial)
    {
      idx = i;
      break;
    }
  const bool isPartialTimer = size() && get(idx).isPartial;
  TimerPoint tp(addr, bank);

  if(!isPartialTimer)
  {
    // create a new timer:
    const Timer tmNew(tp, mirrors, anyBank);

    myList.push_back(tmNew);
    toKey(tp, mirrors, anyBank);
    myFromMap.insert(TimerPair(tp, &myList.back()));
    return size() - 1;
  }
  else
  {
    // complete a partial timer:
    Timer& tmPartial = myList[idx];
    TimerPoint tpFrom = tmPartial.from;
    const bool oldMirrors = tmPartial.mirrors;
    const bool oldAnyBank = tmPartial.anyBank;

    tmPartial.setTo(tp, mirrors, anyBank);
    toKey(tp, tmPartial.mirrors, tmPartial.anyBank);
    myToMap.insert(TimerPair(tp, &tmPartial));

    // update tp key in myFromMap for new mirrors & anyBank settings
    // 1. find map entry using OLD tp key settings:
    toKey(tpFrom, oldMirrors, oldAnyBank);
    auto from = myFromMap.equal_range(tpFrom);
    for(auto it = from.first; it != from.second; ++it)
      if(it->second == &tmPartial)
      {
        // 2. erase old map entry
        myFromMap.erase(it);
        // ...and add new map entry with NEW tp key settings:
        toKey(tpFrom, tmPartial.mirrors, tmPartial.anyBank);
        myFromMap.insert(TimerPair(tpFrom, &tmPartial));
        break;
      }
    return idx;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TimerMap::erase(uInt32 idx)
{
  if(size() > idx)
  {
    const Timer* timer = &myList[idx];
    const TimerPoint tpFrom(timer->from);
    const TimerPoint tpTo(timer->to);

    // Find address in from and to maps, TODO what happens if not found???
    const auto from = myFromMap.equal_range(tpFrom);
    for(auto it = from.first; it != from.second; ++it)
      if(it->second == timer)
      {
        myFromMap.erase(it);
        break;
      }

    const auto to = myToMap.equal_range(tpTo);
    for(auto it = to.first; it != to.second; ++it)
      if(it->second == timer)
      {
        myToMap.erase(it);
        break;
      }

    // Finally remove from list
    myList.erase(myList.begin() + idx);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimerMap::clear()
{
  myList.clear();
  myFromMap.clear();
  myToMap.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimerMap::reset()
{
  for(auto& it: myList)
    it.reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimerMap::update(uInt16 addr, uInt8 bank, const uInt64 cycles)
{
  if((addr & ADDRESS_MASK) != addr)
  {
    // 13 bit timerpoint
    const TimerPoint tp(addr & ADDRESS_MASK, bank);

    // Find address in from and to maps
    const auto from = myFromMap.equal_range(tp);
    for(auto it = from.first; it != from.second; ++it)
      if(!it->second->isPartial)
        it->second->start(cycles);

    const auto to = myToMap.equal_range(tp);
    for(auto it = to.first; it != to.second; ++it)
      if(!it->second->isPartial)
        it->second->stop(cycles);
  }

  // 16 bit timerpoint
  const TimerPoint tp(addr, bank);

  // Find address in from and to maps
  const auto from = myFromMap.equal_range(tp);
  for(auto it = from.first; it != from.second; ++it)
    if(!it->second->isPartial)
      it->second->start(cycles);

  const auto to = myToMap.equal_range(tp);
  for(auto it = to.first; it != to.second; ++it)
    if(!it->second->isPartial)
      it->second->stop(cycles);
}
