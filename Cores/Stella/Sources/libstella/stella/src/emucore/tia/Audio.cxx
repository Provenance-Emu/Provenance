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

#include "Audio.hxx"
#include "AudioQueue.hxx"

#include <cmath>

namespace {
  constexpr double R_MAX = 30.;
  constexpr double R = 1.;

  Int16 mixingTableEntry(uInt8 v, uInt8 vMax)
  {
    return static_cast<Int16>(
      floor(0x7fff * static_cast<double>(v) / static_cast<double>(vMax) *
            (R_MAX + R * static_cast<double>(vMax)) / (R_MAX + R * static_cast<double>(v)))
    );
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Audio::Audio()
{
  for (uInt8 i = 0; i <= 0x1e; ++i) myMixingTableSum[i] = mixingTableEntry(i, 0x1e);
  for (uInt8 i = 0; i <= 0x0f; ++i) myMixingTableIndividual[i] = mixingTableEntry(i, 0x0f);

  reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Audio::reset()
{
  myCounter = 0;
  mySampleIndex = 0;

  myChannel0.reset();
  myChannel1.reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Audio::setAudioQueue(const shared_ptr<AudioQueue>& queue)
{
  myAudioQueue = queue;

  myCurrentFragment = myAudioQueue->enqueue();
  mySampleIndex = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Audio::phase1()
{
  const uInt8 sample0 = myChannel0.phase1();
  const uInt8 sample1 = myChannel1.phase1();

  addSample(sample0, sample1);
#ifdef GUI_SUPPORT
  if(myRewindMode)
    mySamples.push_back(sample0 | (sample1 << 4));
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Audio::addSample(uInt8 sample0, uInt8 sample1)
{
  if(!myAudioQueue) return;

  if(myAudioQueue->isStereo()) {
    myCurrentFragment[static_cast<size_t>(2 * mySampleIndex)] =
      myMixingTableIndividual[sample0];
    myCurrentFragment[static_cast<size_t>(2 * mySampleIndex + 1)] =
      myMixingTableIndividual[sample1];
  }
  else {
    myCurrentFragment[mySampleIndex] = myMixingTableSum[sample0 + sample1];
  }

  if(++mySampleIndex == myAudioQueue->fragmentSize()) {
    mySampleIndex = 0;
    myCurrentFragment = myAudioQueue->enqueue(myCurrentFragment);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Audio::save(Serializer& out) const
{
  try
  {
    out.putByte(myCounter);

    // The queue starts out pristine after loading, so we don't need to save
    // any other parts of our state

    if (!myChannel0.save(out)) return false;
    if (!myChannel1.save(out)) return false;
  #ifdef GUI_SUPPORT
    out.putLong(static_cast<uInt64>(mySamples.size()));
    out.putByteArray(mySamples.data(), mySamples.size());

    // TODO: check if this improves sound of playback for larger state gaps
    //out.putInt(mySampleIndex);
    //out.putShortArray((uInt16*)myCurrentFragment, myAudioQueue->fragmentSize());

    mySamples.clear();
  #endif
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Audio::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Audio::load(Serializer& in)
{
  try
  {
    myCounter = in.getByte();

    if (!myChannel0.load(in)) return false;
    if (!myChannel1.load(in)) return false;
  #ifdef GUI_SUPPORT
    const uInt64 sampleSize = in.getLong();
    ByteArray samples(sampleSize);
    in.getByteArray(samples.data(), sampleSize);

    //mySampleIndex = in.getInt();
    //in.getShortArray((uInt16*)myCurrentFragment, myAudioQueue->fragmentSize());

    // Feed all loaded samples into the audio queue
    for(size_t i = 0; i < sampleSize; i++)
    {
      const uInt8 sample = samples[i];
      const uInt8 sample0 = sample & 0x0f;
      const uInt8 sample1 = sample >> 4;

      addSample(sample0, sample1);
    }
  #endif
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Audio::load\n";
    return false;
  }

  return true;
}
