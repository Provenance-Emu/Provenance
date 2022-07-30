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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef TIA_DELAY_QUEUE_ITERATOR
#define TIA_DELAY_QUEUE_ITERATOR

#include "bspf.hxx"

class DelayQueueIterator
{
  public:
    DelayQueueIterator() = default;
    virtual ~DelayQueueIterator() = default;

  public:
    virtual bool isValid() const = 0;

    virtual uInt8 delay() const = 0;

    virtual uInt8 address() const = 0;

    virtual uInt8 value() const = 0;

    virtual bool next() = 0;

  private:
    // Following constructors and assignment operators not supported
    DelayQueueIterator(const DelayQueueIterator&) = delete;
    DelayQueueIterator(DelayQueueIterator&&) = delete;
    DelayQueueIterator& operator=(const DelayQueueIterator&) = delete;
    DelayQueueIterator& operator=(DelayQueueIterator&&) = delete;
};

#endif // TIA_DELAY_QUEUE_ITERATOR
