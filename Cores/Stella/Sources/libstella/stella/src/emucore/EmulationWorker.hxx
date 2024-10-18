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

/*
 * This class is the core of stella's scheduling. Scheduling is a two step process
 * that is shared between the main loop in OSystem and this class.
 *
 * In emulation mode (as opposed to debugger, menu, etc.), each iteration of the main loop
 * instructs the emulation worker to start emulation on a separate thread and then proceeds
 * to render the last frame produced by the TIA (if any). After the frame has been rendered,
 * the worker is stopped, and the main thread sleeps until the time allotted to the emulation
 * timeslice (as calculated from the 6507 cycles that have passed) has been reached. After
 * that, it iterates.
 *
 * The emulation worker does its own microscheduling. After emulating a timeslice, it sleeps
 * until either the allotted time is up or it has been signalled to stop. If the time is up
 * without being signalled, the worker will emulate another timeslice, etc.
 *
 * In combination, the scheduling in the main loop and the microscheduling in the worker
 * ensure that the emulation continues to run even if rendering blocks, ensuring the real
 * time scheduling required for cycle exact audio to work.
 */

#ifndef EMULATION_WORKER_HXX
#define EMULATION_WORKER_HXX

#include <atomic>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <exception>
#include <chrono>

#include "bspf.hxx"

class TIA;
class DispatchResult;

class EmulationWorker
{
  public:

    /**
      The constructor starts the worker thread and waits until it has initialized.
     */
    EmulationWorker();

    /**
      The destructor signals quit to the worker and joins.
     */
    ~EmulationWorker();

    /**
      Wake up the worker and start emulation with the specified parameters.
     */
    void start(uInt32 cyclesPerSecond, uInt64 maxCycles, uInt64 minCycles, DispatchResult* dispatchResult, TIA* tia);

    /**
      Stop emulation and return the number of 6507 cycles emulated.
     */
    uInt64 stop();

  private:

    /**
      Check whether an exception occurred on the thread and rethrow if appicable.
     */
    void handlePossibleException();

    /**
      The main thread entry point.
      Passing references into a thread is awkward and requires std::ref -> use pointers here
     */
    void threadMain(std::condition_variable* initializedCondition, std::mutex* initializationMutex);

    /**
      Handle thread wakeup after sleep depending on the thread state.
     */
    void handleWakeup(std::unique_lock<std::mutex>& lock);

    /**
      Handle wakeup while sleeping and waiting to be resumed.
     */
    void handleWakeupFromWaitingForResume(std::unique_lock<std::mutex>& lock);

    /**
      Handle wakeup while sleeping and waiting to be stopped (or for the timeslice
      to expire).
     */
    void handleWakeupFromWaitingForStop(std::unique_lock<std::mutex>& lock);

    /**
      Run the emulation, adjust the thread state according to the result and sleep.
     */
    void dispatchEmulation(std::unique_lock<std::mutex>& lock);

    /**
      Clear any pending signal and wake up the main thread (if it is waiting for the signal
      to be cleared).
     */
    void clearSignal();

    /**
     * Signal quit and wake up the main thread if applicable.
     */
    void signalQuit();

    /**
      Wait and sleep until a pending signal has been processed (or quit sigmalled).
      This is called from the main thread.
     */
    void waitUntilPendingSignalHasProcessed();

    /**
      Log a fatal error to cerr and throw a runtime exception.
     */
    [[noreturn]] static void fatal(const string& message);

  private:
  /**
    Thread state.
   */
    enum class State {
      // Initial state
      initializing,
      // Thread has initialized. From the point, myThreadIsRunningMutex is locked if and only if
      // the thread is running.
      initialized,
      // Sleeping and waiting for emulation to be resumed
      waitingForResume,
      // Running and emulating
      running,
      // Sleeping and waiting for emulation to be stopped
      waitingForStop,
      // An exception occurred and the thread has terminated (or is terminating)
      exception
    };

    /**
      Thread behavior is controlled by signals that are raised prior to waking up the thread.
     */
    enum class Signal {
      // Resume emulation
      resume,
      // Stop emulation
      stop,
      // Quit (either during destruction or after an exception)
      quit,
      // No pending signal
      none
    };

  private:

    // Worker thread
    std::thread myThread;

    // Condition variable for waking up the thread
    std::condition_variable myWakeupCondition;
    // The thread is running if and only if while this mutex is locked
    std::mutex myThreadIsRunningMutex;

    // Condition variable to signal changes to the pending signal
    std::condition_variable mySignalChangeCondition;
    // This mutex guards reading and writing the pending signal.
    std::mutex mySignalChangeMutex;

    // Any exception on the worker thread is saved here to be rethrown on the main thread.
    std::exception_ptr myPendingException;

    // Any pending signal (or Signal::none)
    Signal myPendingSignal{Signal::none};
    // The initial access to myState is not synchronized -> make this atomic
    std::atomic<State> myState{State::initializing};

    // Emulation parameters
    TIA* myTia{nullptr};
    uInt64 myCyclesPerSecond{0};
    uInt64 myMaxCycles{0};
    uInt64 myMinCycles{0};
    DispatchResult* myDispatchResult{nullptr};

    // Total number of cycles during this emulation run
    uInt64 myTotalCycles{0};
    // 6507 time
    std::chrono::time_point<std::chrono::high_resolution_clock> myVirtualTime;

  private:

    EmulationWorker(const EmulationWorker&) = delete;

    EmulationWorker(EmulationWorker&&) = delete;

    EmulationWorker& operator=(const EmulationWorker&) = delete;

    EmulationWorker& operator=(EmulationWorker&&) = delete;
};

#endif // EMULATION_WORKER_HXX
