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

#include <cassert>
#include "TimerManager.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimerManager::TimerManager()
  : nextId{no_timer + 1}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimerManager::~TimerManager()
{
  ScopedLock lock(sync);

  // The worker might not be running
  if (worker.joinable())
  {
    done = true;
    lock.unlock();
    wakeUp.notify_all();

    // If a timer handler is running, this
    // will make sure it has returned before
    // allowing any deallocations to happen
    worker.join();

    // Note that any timers still in the queue
    // will be destructed properly but they
    // will not be invoked
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimerManager::TimerId TimerManager::addTimer(
    millisec msDelay,
    millisec msPeriod,
    const TFunction& func)
{
  ScopedLock lock(sync);

  // Lazily start thread when first timer is requested
  if (!worker.joinable())
    worker = std::thread(&TimerManager::timerThreadWorker, this);

  // Assign an ID and insert it into function storage
  auto id = nextId++;
  const auto iter = active.emplace(id, Timer(id, Clock::now() + Duration(msDelay),
      Duration(msPeriod), func));

  // Insert a reference to the Timer into ordering queue
  const auto place = queue.emplace(iter.first->second);

  // We need to notify the timer thread only if we inserted
  // this timer into the front of the timer queue
  const bool needNotify = (place == queue.begin());

  lock.unlock();

  if (needNotify)
    wakeUp.notify_all();

  return id;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TimerManager::clear(TimerId id)
{
  ScopedLock lock(sync);
  const auto i = active.find(id);
  return destroy_impl(lock, i, true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimerManager::clear()
{
  ScopedLock lock(sync);
  while (!active.empty())
    destroy_impl(lock, active.begin(), queue.size() == 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::size_t TimerManager::size() const noexcept
{
  const ScopedLock lock(sync);
  return active.size();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool TimerManager::empty() const noexcept
{
  const ScopedLock lock(sync);
  return active.empty();  // NOLINT: bugprone-standalone-empty
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimerManager& TimerManager::global()
{
  static TimerManager singleton;
  return singleton;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimerManager::timerThreadWorker()
{
  ScopedLock lock(sync);

  while (!done)
  {
    if (queue.empty())
    {
      // Wait for done or work
      wakeUp.wait(lock, [this] { return done || !queue.empty(); });
      continue;
    }

    const auto queueHead = queue.begin();
    Timer& timer = *queueHead;
    const auto now = Clock::now();
    if (now >= timer.next)
    {
      queue.erase(queueHead);

      // Mark it as running to handle racing destroy
      timer.running = true;

      // Call the handler outside the lock
      lock.unlock();
      timer.handler();
      lock.lock();

      if (timer.running)
      {
        timer.running = false;

        // If it is periodic, schedule a new one
        if (timer.period.count() > 0)
        {
          timer.next = timer.next + timer.period;
          queue.emplace(timer);
        }
        else
        {
          // Not rescheduling, destruct it
          active.erase(timer.id);
        }
      }
      else
      {
        // timer.running changed!
        //
        // Running was set to false, destroy was called
        // for this Timer while the callback was in progress
        // (this thread was not holding the lock during the callback)
        // The thread trying to destroy this timer is waiting on
        // a condition variable, so notify it
        timer.waitCond->notify_all();

        // The clearTimer call expects us to remove the instance
        // when it detects that it is racing with its callback
        active.erase(timer.id);
      }
    }
    else
    {
      // Wait until the timer is ready or a timer creation notifies
      wakeUp.wait_until(lock, timer.next);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// NOTE: if notify is true, returns with lock unlocked
bool TimerManager::destroy_impl(ScopedLock& lock, TimerMap::iterator i,
                                bool notify)
{
  assert(lock.owns_lock());

  if (i == active.end())
    return false;

  Timer& timer = i->second;
  if (timer.running)
  {
    // A callback is in progress for this Timer,
    // so flag it for deletion in the worker
    timer.running = false;

    // Assign a condition variable to this timer
    timer.waitCond = std::make_unique<ConditionVar>();

    // Block until the callback is finished
    if (std::this_thread::get_id() != worker.get_id())
      timer.waitCond->wait(lock);
  }
  else
  {
    queue.erase(timer);
    active.erase(i);

    if (notify)
    {
      lock.unlock();
      wakeUp.notify_all();
    }
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// TimerManager::Timer implementation
//

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimerManager::Timer::Timer(Timer&& r) noexcept
  : id{r.id},
    next{r.next},
    period{r.period},
    handler{std::move(r.handler)},
    running{r.running}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimerManager::Timer::Timer(TimerId tid, Timestamp tnext, Duration tperiod,
                           const TFunction& func) noexcept
  : id{tid},
    next{tnext},
    period{tperiod},
    handler{func}
{
}
