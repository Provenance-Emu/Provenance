// hrtimer.h - originally written and placed in the public domain by Wei Dai

/// \file hrtimer.h
/// \brief Classes for timers

#ifndef CRYPTOPP_HRTIMER_H
#define CRYPTOPP_HRTIMER_H

#include "config.h"

#if !defined(HIGHRES_TIMER_AVAILABLE) || (defined(CRYPTOPP_WIN32_AVAILABLE) && !defined(THREAD_TIMER_AVAILABLE))
#include <time.h>
#endif

NAMESPACE_BEGIN(CryptoPP)

#ifdef HIGHRES_TIMER_AVAILABLE
	/// \brief TimerWord is a 64-bit word
	typedef word64 TimerWord;
#else
	/// \brief TimerWord is a clock_t
	typedef clock_t TimerWord;
#endif

/// \brief Base class for timers
/// \sa ThreadUserTimer, Timer
class CRYPTOPP_DLL CRYPTOPP_NO_VTABLE TimerBase
{
public:
	/// \brief Unit of measure
	/// \details Unit selects the unit of measure as returned by functions
	///  ElapsedTimeAsDouble() and ElapsedTime().
	/// \sa ElapsedTimeAsDouble, ElapsedTime
	enum Unit {
		/// \brief Timer unit is seconds
		/// \details All timers support seconds
		SECONDS = 0,
		/// \brief Timer unit is milliseconds
		/// \details All timers support milliseconds
		MILLISECONDS,
		/// \brief Timer unit is microseconds
		/// \details The timer requires hardware support microseconds
		MICROSECONDS,
		/// \brief Timer unit is nanoseconds
		/// \details The timer requires hardware support nanoseconds
		NANOSECONDS
	};

	/// \brief Construct a TimerBase
	/// \param unit the unit of measure
	/// \param stuckAtZero flag
	TimerBase(Unit unit, bool stuckAtZero)
		: m_timerUnit(unit), m_stuckAtZero(stuckAtZero), m_started(false)
		, m_start(0), m_last(0) {}

	/// \brief Retrieve the current timer value
	/// \return the current timer value
	virtual TimerWord GetCurrentTimerValue() =0;

	/// \brief Retrieve ticks per second
	/// \return ticks per second
	/// \details TicksPerSecond() is not the timer resolution. It is a
	///  conversion factor into seconds.
	virtual TimerWord TicksPerSecond() =0;

	/// \brief Start the timer
	void StartTimer();

	/// \brief Retrieve the elapsed time
	/// \return the elapsed time as a double
	/// \details The return value of ElapsedTimeAsDouble() depends upon
	///  the Unit selected during construction of the timer. For example,
	///  if <tt>Unit = SECONDS</tt> and ElapsedTimeAsDouble() returns 3,
	///  then the timer has run for 3 seconds. If
	///  <tt>Unit = MILLISECONDS</tt> and ElapsedTimeAsDouble() returns
	///  3000, then the timer has run for 3 seconds.
	/// \sa Unit, ElapsedTime
	double ElapsedTimeAsDouble();

	/// \brief Retrieve the elapsed time
	/// \return the elapsed time as an unsigned long
	/// \details The return value of ElapsedTime() depends upon the
	///  Unit selected during construction of the timer. For example, if
	///  <tt>Unit = SECONDS</tt> and ElapsedTime() returns 3, then
	///  the timer has run for 3 seconds. If <tt>Unit = MILLISECONDS</tt>
	///  and ElapsedTime() returns 3000, then the timer has run for 3
	///  seconds.
	/// \sa Unit, ElapsedTimeAsDouble
	unsigned long ElapsedTime();

private:
	double ConvertTo(TimerWord t, Unit unit);

	Unit m_timerUnit;	// HPUX workaround: m_unit is a system macro on HPUX
	bool m_stuckAtZero, m_started;
	TimerWord m_start, m_last;
};

/// \brief Measure CPU time spent executing instructions of this thread
/// \details ThreadUserTimer requires support of the OS. On Unix-based it
///  reports process time. On Windows NT or later desktops and servers it
///  reports thread times with performance counter precision.. On Windows
///  Phone and Windows Store it reports wall clock time with performance
///  counter precision. On all others it reports wall clock time.
/// \note ThreadUserTimer only works correctly on Windows NT or later
///  desktops and servers.
/// \sa Timer
class ThreadUserTimer : public TimerBase
{
public:
	/// \brief Construct a ThreadUserTimer
	/// \param unit the unit of measure
	/// \param stuckAtZero flag
	ThreadUserTimer(Unit unit = TimerBase::SECONDS, bool stuckAtZero = false) : TimerBase(unit, stuckAtZero) {}
	TimerWord GetCurrentTimerValue();
	TimerWord TicksPerSecond();
};

/// \brief High resolution timer
/// \sa ThreadUserTimer
class CRYPTOPP_DLL Timer : public TimerBase
{
public:
	/// \brief Construct a Timer
	/// \param unit the unit of measure
	/// \param stuckAtZero flag
	Timer(Unit unit = TimerBase::SECONDS, bool stuckAtZero = false)	: TimerBase(unit, stuckAtZero) {}
	TimerWord GetCurrentTimerValue();
	TimerWord TicksPerSecond();
};

NAMESPACE_END

#endif
