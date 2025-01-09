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

#include "StaggeredLogger.hxx"
#include "Logger.hxx"

#include <ctime>

using namespace std::chrono;

namespace {
  string currentTimestamp()
  {
    const std::tm now = BSPF::localTime();

    std::array<char, 100> formattedTime;
    formattedTime.fill(0);
    std::ignore = std::strftime(formattedTime.data(), 99, "%H:%M:%S", &now);

    return formattedTime.data();
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StaggeredLogger::StaggeredLogger(string_view message, Logger::Level level)
  : myMessage{message},
    myLevel{level}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StaggeredLogger::~StaggeredLogger()
{
  myTimer->clear(myTimerId);

  // make sure that the worker thread joins before continuing with the destruction
  myTimer.reset();

  // the worker thread has joined and there will be no more reentrant calls ->
  // continue with destruction
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::log()
{
  const std::lock_guard<std::mutex> lock(myMutex);

  _log();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::_log()
{
  if (!myIsCurrentlyCollecting) startInterval();

  ++myCurrentEventCount;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::logLine()
{
  const high_resolution_clock::time_point now = high_resolution_clock::now();
  const Int64 millisecondsSinceIntervalStart =
    duration_cast<duration<Int64, std::milli>>(now - myLastIntervalStartTimestamp).count();

  stringstream ss;
  ss
    << currentTimestamp() << ": "
    << myMessage
    << " (" << myCurrentEventCount << " times in "
      << millisecondsSinceIntervalStart << "  milliseconds"
    << ")";

  Logger::log(ss.str(), myLevel);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::increaseInterval()
{
  if (myCurrentIntervalFactor >= myMaxIntervalFactor) return;

  ++myCurrentIntervalFactor;
  myCurrentIntervalSize *= 2;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::decreaseInterval()
{
  if (myCurrentIntervalFactor <= 1) return;

  --myCurrentIntervalFactor;
  myCurrentIntervalSize /= 2;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::startInterval()
{
  if (myIsCurrentlyCollecting) return;

  myIsCurrentlyCollecting = true;

  const high_resolution_clock::time_point now = high_resolution_clock::now();
  Int64 msecSinceLastIntervalEnd =
    duration_cast<duration<Int64, std::milli>>(now - myLastIntervalEndTimestamp).count();

  while (msecSinceLastIntervalEnd > myCooldownTime && myCurrentIntervalFactor > 1) {
    msecSinceLastIntervalEnd -= myCooldownTime;
    decreaseInterval();
  }

  myCurrentEventCount = 0;
  myLastIntervalStartTimestamp = now;

  myTimer->clear(myTimerId);
  myTimerId = myTimer->setTimeout(std::bind(&StaggeredLogger::onTimerExpired, this, ++myTimerCallbackId), myCurrentIntervalSize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StaggeredLogger::onTimerExpired(uInt32 timerCallbackId)
{
  const std::lock_guard<std::mutex> lock(myMutex);

  if (timerCallbackId != myTimerCallbackId) return;

  logLine();

  myIsCurrentlyCollecting = false;
  increaseInterval();

  myLastIntervalEndTimestamp = high_resolution_clock::now();
}
