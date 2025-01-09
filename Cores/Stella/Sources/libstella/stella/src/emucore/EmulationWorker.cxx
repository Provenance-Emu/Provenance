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

#include <exception>

#include "EmulationWorker.hxx"
#include "DispatchResult.hxx"
#include "TIA.hxx"
#include "Logger.hxx"

using namespace std::chrono;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationWorker::EmulationWorker()
{
  std::mutex mutex;
  std::unique_lock<std::mutex> lock(mutex);
  std::condition_variable threadInitialized;

  myThread = std::thread(
    &EmulationWorker::threadMain, this, &threadInitialized, &mutex
  );

  // Wait until the thread has acquired myThreadIsRunningMutex and moved on
  while (myState == State::initializing) threadInitialized.wait(lock);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EmulationWorker::~EmulationWorker()
{
  // This has to run in a block in order to release the mutex before joining
  {
    const std::unique_lock<std::mutex> lock(myThreadIsRunningMutex);

    if (myState != State::exception) {
      signalQuit();
      myWakeupCondition.notify_one();
    }
  }

  myThread.join();

  handlePossibleException();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::handlePossibleException()
{
  if (myState == State::exception && myPendingException) {
    const std::exception_ptr ex = myPendingException;
    // Make sure that the exception is not thrown a second time (destructor!!!)
    myPendingException = nullptr;

    std::rethrow_exception(ex);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::start(uInt32 cyclesPerSecond, uInt64 maxCycles, uInt64 minCycles, DispatchResult* dispatchResult, TIA* tia)
{
  // Wait until any pending signal has been processed
  waitUntilPendingSignalHasProcessed();

  // Run in a block to release the mutex before notifying; this avoids an unecessary
  // block that will waste a timeslice
  {
    // Acquire the mutex -> wait until the thread is suspended
    const std::unique_lock<std::mutex> lock(myThreadIsRunningMutex);

    // Pass on possible exceptions
    handlePossibleException();

    // Make sure that we don't overwrite the exit condition.
    // This case is hypothetical and cannot happen, but handling it does not hurt, either
    if (myPendingSignal == Signal::quit) return;

    // NB: The thread does not suspend execution in State::initialized
    if (myState != State::waitingForResume)
      fatal("start called on running or dead worker");

    // Store the parameters for emulation
    myTia = tia;
    myCyclesPerSecond = cyclesPerSecond;
    myMaxCycles = maxCycles;
    myMinCycles = minCycles;
    myDispatchResult = dispatchResult;

    // Raise the signal...
    myPendingSignal = Signal::resume;
  }

  // ... and wakeup the thread
  myWakeupCondition.notify_one();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt64 EmulationWorker::stop()
{
  // See EmulationWorker::start above for the gory details
  waitUntilPendingSignalHasProcessed();

  uInt64 totalCycles{0};
  {
    const std::unique_lock<std::mutex> lock(myThreadIsRunningMutex);

    // Paranoia: make sure that we don't doublecount an emulation timeslice
    totalCycles = myTotalCycles;
    myTotalCycles = 0;

    handlePossibleException();

    if (myPendingSignal == Signal::quit) return totalCycles;

    // If the worker has stopped on its own, we return
    if (myState == State::waitingForResume) return totalCycles;

    // NB: The thread does not suspend execution in State::initialized or State::running
    if (myState != State::waitingForStop)
      fatal("stop called on a dead worker");

    myPendingSignal = Signal::stop;
  }

  myWakeupCondition.notify_one();

  return totalCycles;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::threadMain(std::condition_variable* initializedCondition, std::mutex* initializationMutex)
{
  std::unique_lock<std::mutex> lock(myThreadIsRunningMutex);

  try {
    {
      // Wait until our parent releases the lock and sleeps
      const std::lock_guard<std::mutex> guard(*initializationMutex);

      // Update the state...
      myState = State::initialized;

      // ... and wake up our parent to notifiy that we have initialized. From this point, the
      // parent can safely assume that we are running while the mutex is locked.
      initializedCondition->notify_one();
    }

    // Loop until we have an exit condition
    while (myPendingSignal != Signal::quit) handleWakeup(lock);
  }
  catch (...) {
    // Store away the exception and the state accordingly
    myPendingException = std::current_exception();
    myState = State::exception;

    // Raising the exit condition is consistent and makes shure that the main thread
    // will not deadlock if an exception is raised while it is waiting for a signal
    // to be processed.
    signalQuit();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::handleWakeup(std::unique_lock<std::mutex>& lock)
{
  switch (myState) {
    case State::initialized:
      // Enter waitingForResume and sleep after initialization
      myState = State::waitingForResume;
      myWakeupCondition.wait(lock);
      break;

    case State::waitingForResume:
      handleWakeupFromWaitingForResume(lock);
      break;

    case State::waitingForStop:
      handleWakeupFromWaitingForStop(lock);
      break;

    default:
      fatal("wakeup in invalid worker state");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::handleWakeupFromWaitingForResume(std::unique_lock<std::mutex>& lock)
{
  switch (myPendingSignal) {
    case Signal::resume:
      // Clear the pending signal and notify the main thread
      clearSignal();

      // Reset virtual clock and cycle counter
      myVirtualTime = high_resolution_clock::now();
      myTotalCycles = 0;

      // Enter emulation. This will emulate a timeslice and set the state upon completion.
      dispatchEmulation(lock);
      break;

    case Signal::none:
      // Reenter sleep on spurious wakeups
      myWakeupCondition.wait(lock);
      break;

    case Signal::quit:
      break;

    default:
      fatal("invalid signal while waiting for resume");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::handleWakeupFromWaitingForStop(std::unique_lock<std::mutex>& lock)
{
  switch (myPendingSignal) {
    case Signal::stop:
      // Clear the pending signal and notify the main thread
      clearSignal();

      // Enter waiting for resume and sleep
      myState = State::waitingForResume;
      myWakeupCondition.wait(lock);
      break;

    case Signal::none:
      if(myVirtualTime <= high_resolution_clock::now())
        // The time allotted to the emulation timeslice has passed and we haven't been stopped?
        // -> go for another emulation timeslice
      {
        Logger::debug("Frame dropped!");
        dispatchEmulation(lock);
      }
      else
        // Wakeup was spurious, reenter sleep
        myWakeupCondition.wait_until(lock, myVirtualTime);

      break;

    case Signal::quit:
      break;

    default:
      fatal("invalid signal while waiting for stop");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::dispatchEmulation(std::unique_lock<std::mutex>& lock)
{
  // Technically, we could do without State::running, but it is cleaner and might be useful in the future
  myState = State::running;

  uInt64 totalCycles = 0;

  do {
    myTia->update(*myDispatchResult, totalCycles > 0 ? myMinCycles - totalCycles : myMaxCycles);
    totalCycles += myDispatchResult->getCycles();
  } while (totalCycles < myMinCycles && myDispatchResult->getStatus() == DispatchResult::Status::ok);

  myTotalCycles += totalCycles;

  bool continueEmulating = false;

  if (myDispatchResult->getStatus() == DispatchResult::Status::ok) {
    // If emulation finished successfully, we are free to go for another round
    const duration<double> timesliceSeconds(static_cast<double>(totalCycles) / static_cast<double>(myCyclesPerSecond));
    myVirtualTime += duration_cast<high_resolution_clock::duration>(timesliceSeconds);

    // If we aren't fast enough to keep up with the emulation, we stop immediatelly to avoid
    // starving the system for processing time --- emulation will stutter anyway.
    continueEmulating = myVirtualTime > high_resolution_clock::now();
  }

  if (continueEmulating) {
    // If we are free to continue emulating, we sleep until either the timeslice has passed or we
    // have been signalled from the main thread
    myState = State::waitingForStop;
    myWakeupCondition.wait_until(lock, myVirtualTime);
  } else {
    // If can't continue, we just stop and wait to be signalled
    myState = State::waitingForResume;
    myWakeupCondition.wait(lock);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::clearSignal()
{
  {
    const std::unique_lock<std::mutex> lock(mySignalChangeMutex);
    myPendingSignal = Signal::none;
  }

  mySignalChangeCondition.notify_one();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::signalQuit()
{
  {
    const std::unique_lock<std::mutex> lock(mySignalChangeMutex);
    myPendingSignal = Signal::quit;
  }

  mySignalChangeCondition.notify_one();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::waitUntilPendingSignalHasProcessed()
{
  std::unique_lock<std::mutex> lock(mySignalChangeMutex);

  // White until there is no pending signal (or the exit condition has been raised)
  while (myPendingSignal != Signal::none && myPendingSignal != Signal::quit)
    mySignalChangeCondition.wait(lock);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void EmulationWorker::fatal(const string& message)
{
  (cerr << "FATAL in emulation worker: " << message << '\n').flush();
  throw runtime_error(message);
}
