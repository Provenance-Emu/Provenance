/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* MThreading.h:
**  Copyright (C) 2019 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 Notes:
	The *_Destroy() functions will call MDFN_Notify() with MDFN_NOTICE_ERROR on error.
	All other noexcept functions will fprintf() to stderr on error, without using gettext() or any Mednafen facilities.

	noexcept functions returning a bool will return true on success, false on error(or wait time expired for
	the *_TimedWait() functions).

	Do not attempt to use the synchronization primitives(mutex, cond variables, etc.) for inter-process synchronization,
	they'll only work reliably with intra-process synchronization(the "mutex" is implemented as a a critical section
	under Windows, for example).
*/


#ifndef __MDFN_MTHREADING_H
#define __MDFN_MTHREADING_H

namespace Mednafen
{
namespace MThreading
{

struct Thread;
struct Mutex;
struct Cond;	// mmm condiments
struct Sem;

//
// Thread creation/attributes
//
Thread* Thread_Create(int (*fn)(void *), void *data, const char* debug_name = nullptr);
void Thread_Wait(Thread *thread, int *status);
uintptr_t Thread_ID(void);
uint64 Thread_SetAffinity(Thread* thread, uint64 mask) MDFN_COLD;

//
// Mutexes
//
Mutex* Mutex_Create(void) MDFN_COLD;
void Mutex_Destroy(Mutex* mutex) noexcept MDFN_COLD;

bool Mutex_Lock(Mutex* mutex) noexcept;
bool Mutex_Unlock(Mutex* mutex) noexcept;

//
// Condition variables
//
Cond* Cond_Create(void) MDFN_COLD;
void Cond_Destroy(Cond* cond) noexcept MDFN_COLD;

// SignalCond() *MUST* be called with a lock on the mutex used with WaitCond() or WaitCondTimeout()
bool Cond_Signal(Cond* cond) noexcept;
bool Cond_Wait(Cond* cond, Mutex* mutex) noexcept;
bool Cond_TimedWait(Cond* cond, Mutex* mutex, unsigned ms) noexcept;

//
// Semaphores
//
Sem* Sem_Create(void) MDFN_COLD;
void Sem_Destroy(Sem* sem) noexcept MDFN_COLD;

bool Sem_Wait(Sem* sem) noexcept;
bool Sem_TimedWait(Sem* sem, unsigned ms) noexcept;
bool Sem_Post(Sem* sem) noexcept;

}
}

#endif
