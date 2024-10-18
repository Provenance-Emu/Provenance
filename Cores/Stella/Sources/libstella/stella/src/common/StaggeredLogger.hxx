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

#ifndef STAGGERED_LOGGER
#define STAGGERED_LOGGER

#include <functional>
#include <chrono>
#include <thread>
#include <mutex>

#include "bspf.hxx"
#include "TimerManager.hxx"
#include "Logger.hxx"

/**
 * This class buffers log events and logs them after a certain time window has
 * expired.  The timout increases after every log line by a factor of two until
 * a maximum is reached.  If no events are reported, the window size decreases
 * again.
 */

class StaggeredLogger
{
  public:

    StaggeredLogger(string_view message, Logger::Level level);
    ~StaggeredLogger();

    void log();

  private:

    void _log();

    void onTimerExpired(uInt32 timerCallbackId);

    void startInterval();

    void increaseInterval();

    void decreaseInterval();

    void logLine();

    string myMessage;
    Logger::Level myLevel;

    uInt32 myCurrentEventCount{0};
    bool myIsCurrentlyCollecting{false};

    std::chrono::high_resolution_clock::time_point myLastIntervalStartTimestamp;
    std::chrono::high_resolution_clock::time_point myLastIntervalEndTimestamp;

    uInt32 myCurrentIntervalSize{100};
    uInt32 myMaxIntervalFactor{9};
    uInt32 myCurrentIntervalFactor{1};
    uInt32 myCooldownTime{1000};

    std::mutex myMutex;

    // We need control over the destruction porcess and over the exact point where
    // the worker thread joins -> allocate on the heap end delete explicitly in
    // our destructor.
    unique_ptr<TimerManager> myTimer{make_unique<TimerManager>()};
    TimerManager::TimerId myTimerId{0};

    // It is possible that the timer callback is running even after TimerManager::clear
    // returns. This id is unique per timer and is used to return from the callback
    // early in case the time is stale.
    uInt32 myTimerCallbackId{0};

  private:
    // Following constructors and assignment operators not supported
    StaggeredLogger(const StaggeredLogger&) = delete;
    StaggeredLogger(StaggeredLogger&&) = delete;
    StaggeredLogger& operator=(const StaggeredLogger&) = delete;
    StaggeredLogger& operator=(StaggeredLogger&&) = delete;
};

#endif // STAGGERED_LOGGER
