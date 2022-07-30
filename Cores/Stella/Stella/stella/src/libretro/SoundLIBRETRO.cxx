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

#ifdef SOUND_SUPPORT

#include <sstream>
#include <cassert>
#include <cmath>

#include "Logger.hxx"
#include "FrameBuffer.hxx"
#include "Settings.hxx"
#include "System.hxx"
#include "OSystem.hxx"
#include "Console.hxx"
#include "SoundLIBRETRO.hxx"
#include "AudioQueue.hxx"
#include "EmulationTiming.hxx"
#include "AudioSettings.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SoundLIBRETRO::SoundLIBRETRO(OSystem& osystem, AudioSettings& audioSettings)
  : Sound(osystem),
    myAudioSettings{audioSettings}
{
  Logger::debug("SoundLIBRETRO::SoundLIBRETRO started ...");
  Logger::debug("SoundLIBRETRO::SoundLIBRETRO initialized");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SoundLIBRETRO::~SoundLIBRETRO()
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundLIBRETRO::open(shared_ptr<AudioQueue> audioQueue,
                         EmulationTiming* emulationTiming)
{
  myEmulationTiming = emulationTiming;

  Logger::debug("SoundLIBRETRO::open started ...");

  audioQueue->ignoreOverflows(!myAudioSettings.enabled());

  myAudioQueue = audioQueue;
  myUnderrun = true;
  myCurrentFragment = nullptr;

  Logger::debug("SoundLIBRETRO::open finished");

  myIsInitializedFlag = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundLIBRETRO::close()
{
  if(!myIsInitializedFlag) return;

  if (myAudioQueue) myAudioQueue->closeSink(myCurrentFragment);
  myAudioQueue.reset();
  myCurrentFragment = nullptr;

  Logger::debug("SoundLIBRETRO::close");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SoundLIBRETRO::dequeue(Int16* stream, uInt32* samples)
{
  uInt32 outIndex = 0;

  while (myAudioQueue->size())
  {
    Int16* nextFragment = myAudioQueue->dequeue(myCurrentFragment);

    if (!nextFragment)
    {
      *samples = outIndex / 2;
      return;
    }

    myCurrentFragment = nextFragment;

    for (uInt32 i = 0; i < myAudioQueue->fragmentSize(); ++i)
    {
      Int16 sampleL, sampleR;

      if (myAudioQueue->isStereo())
      {
        sampleL = static_cast<Int16>(myCurrentFragment[2*i + 0]);
        sampleR = static_cast<Int16>(myCurrentFragment[2*i + 1]);
      }
      else
        sampleL = sampleR = static_cast<Int16>(myCurrentFragment[i]);

      stream[outIndex++] = sampleL;
      stream[outIndex++] = sampleR;
    }
  }

  *samples = outIndex / 2;
}

#endif  // SOUND_SUPPORT
