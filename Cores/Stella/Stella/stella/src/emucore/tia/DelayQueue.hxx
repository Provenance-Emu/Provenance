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

#ifndef TIA_DELAY_QUEUE
#define TIA_DELAY_QUEUE

#include "Serializable.hxx"
#include "bspf.hxx"
#include "smartmod.hxx"
#include "DelayQueueMember.hxx"

template<unsigned length, unsigned capacity>
class DelayQueueIteratorImpl;

template<unsigned length, unsigned capacity>
class DelayQueue : public Serializable
{
  public:
    friend DelayQueueIteratorImpl<length, capacity>;

  public:
    DelayQueue();

  public:

    void push(uInt8 address, uInt8 value, uInt8 delay);

    void reset();

    template<typename T> void execute(T executor);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

  private:
    std::array<DelayQueueMember<capacity>, length> myMembers;
    uInt8 myIndex{0};
    std::array<uInt8, 0xFF> myIndices;

  private:
    DelayQueue(const DelayQueue&) = delete;
    DelayQueue(DelayQueue&&) = delete;
    DelayQueue& operator=(const DelayQueue&) = delete;
    DelayQueue& operator=(DelayQueue&&) = delete;
};

// ############################################################################
// Implementation
// ############################################################################

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned length, unsigned capacity>
DelayQueue<length, capacity>::DelayQueue()
{
  myIndices.fill(0xFF);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned length, unsigned capacity>
void DelayQueue<length, capacity>::push(uInt8 address, uInt8 value, uInt8 delay)
{
  if (delay >= length)
    throw runtime_error("delay exceeds queue length");

  const uInt8 currentIndex = myIndices[address];

  if (currentIndex < length)
    myMembers[currentIndex].remove(address);

  const uInt8 index = smartmod<length>(myIndex + delay);
  myMembers[index].push(address, value);

  myIndices[address] = index;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned length, unsigned capacity>
void DelayQueue<length, capacity>::reset()
{
  for (uInt32 i = 0; i < length; ++i)
    myMembers[i].clear();

  myIndex = 0;
  myIndices.fill(0xFF);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned length, unsigned capacity>
template<typename T>
void DelayQueue<length, capacity>::execute(T executor)
{
  DelayQueueMember<capacity>& currentMember = myMembers[myIndex];

  for (uInt8 i = 0; i < currentMember.mySize; ++i) {
    executor(currentMember.myEntries[i].address, currentMember.myEntries[i].value);
    myIndices[currentMember.myEntries[i].address] = 0xFF;
  }

  currentMember.clear();

  myIndex = smartmod<length>(myIndex + 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned length, unsigned capacity>
bool DelayQueue<length, capacity>::save(Serializer& out) const
{
  try
  {
    out.putInt(length);

    for (uInt32 i = 0; i < length; ++i)
      myMembers[i].save(out);

    out.putByte(myIndex);
    out.putByteArray(myIndices.data(), myIndices.size());
  }
  catch(...)
  {
    cerr << "ERROR: TIA_DelayQueue::save" << endl;
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<unsigned length, unsigned capacity>
bool DelayQueue<length, capacity>::load(Serializer& in)
{
  try
  {
    if (in.getInt() != length) throw runtime_error("delay queue length mismatch");

    for (uInt32 i = 0; i < length; ++i)
      myMembers[i].load(in);

    myIndex = in.getByte();
    in.getByteArray(myIndices.data(), myIndices.size());
  }
  catch(...)
  {
    cerr << "ERROR: TIA_DelayQueue::load" << endl;
    return false;
  }

  return true;
}

#endif //  TIA_DELAY_QUEUE
