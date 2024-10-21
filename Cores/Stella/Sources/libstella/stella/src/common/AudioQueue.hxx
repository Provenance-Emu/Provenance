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

#ifndef AUDIO_QUEUE_HXX
#define AUDIO_QUEUE_HXX

#include <mutex>

#include "bspf.hxx"
#include "StaggeredLogger.hxx"

/**
  This class implements an audio queue that acts both like a ring buffer
  and a pool of audio fragments. The TIA emulation core fills a fragment
  with samples and then returns it to the queue, receiving a new fragment
  in return. The sound driver removes fragments for playback from the
  queue and returns the used fragment in this process.

  The queue needs to be threadsafe as the (SDL) audio driver runs on a
  separate thread. Samples are stored as signed 16 bit integers
  (platform endian).
*/
class AudioQueue
{
  public:

    /**
       Create a new AudioQueue.

       @param fragmentSize  The size (in stereo / mono samples) of each fragment
       @param capacity      The number of fragments that can be queued before wrapping.
       @param isStereo      Whether samples are stereo or mono.
     */
    AudioQueue(uInt32 fragmentSize, uInt32 capacity, bool isStereo);

    /**
       Capacity getter.
     */
    uInt32 capacity() const;

    /**
      Size getter.
     */
    uInt32 size() const;

    /**
      Stereo / mono getter.
     */
    bool isStereo() const;

    /**
      Fragment size getter.
     */
    uInt32 fragmentSize() const;

    /**
      Enqueue a new fragment and get a new fragmen to fill.

      @param fragment   The returned fragment. This must be empty on the first call (when
                        there is nothing to return)
     */
    Int16* enqueue(Int16* fragment = nullptr);

    /**
      Dequeue a fragment for playback and return the played fragment. This may
      return 0 if there is no queued fragment to return (in this case, the returned
      fragment is not enqueued and must be passed in the next invocation).

      @param fragment  The returned fragment. This must be empty on the first call (when
                       there is nothing to return).
     */
    Int16* dequeue(Int16* fragment = nullptr);

    /**
      Return the currently playing fragment without drawing a new one. This is called
      if the sink is closed and prepares the queue to be reopened.
     */
    void closeSink(Int16* fragment);

    /**
      Should we ignore overflows?
     */
    void ignoreOverflows(bool shouldIgnoreOverflows);

  private:

    // The size of an individual fragment (in stereo / mono samples)
    uInt32 myFragmentSize{0};

    // Are we using stereo samples?
    bool myIsStereo{false};

    // The fragment queue
    vector<Int16*> myFragmentQueue;

    // All fragments, including the two fragments that are in circulation.
    vector<Int16*> myAllFragments;

    // We allocate a consecutive slice of memory for the fragments.
    unique_ptr<Int16[]> myFragmentBuffer;

    // The nubmer if queued fragments
    uInt32 mySize{0};

    // The next fragment.
    uInt32 myNextFragment{0};

    // We need a mutex for thread safety.
    mutable std::mutex myMutex;

    // The first (empty) enqueue call returns this fragment.
    Int16* myFirstFragmentForEnqueue{nullptr};
    // The first (empty) dequeue call replaces the returned fragment with this fragment.
    Int16* myFirstFragmentForDequeue{nullptr};

    // Log overflows?
    bool myIgnoreOverflows{true};

    StaggeredLogger myOverflowLogger{"audio buffer overflow", Logger::Level::INFO};

  private:

    AudioQueue() = delete;
    AudioQueue(const AudioQueue&) = delete;
    AudioQueue(AudioQueue&&) = delete;
    AudioQueue& operator=(const AudioQueue&) = delete;
    AudioQueue& operator=(AudioQueue&&) = delete;
};

#endif // AUDIO_QUEUE_HXX
