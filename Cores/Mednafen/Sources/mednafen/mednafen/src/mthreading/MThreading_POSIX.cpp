/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* MThreading_POSIX.cpp:
**  Copyright (C) 2018-2020 Mednafen Team
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
 TODO: Make thread ID correct for threads created outside
       of Mednafen's framework.
*/

#include <mednafen/mednafen.h>
#include <mednafen/MThreading.h>
//
//
//
#if !defined(HAVE_PTHREAD_CONDATTR_SETCLOCK) && defined(HAVE_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP)
 #define MDFN_USE_COND_TIMEDWAIT_RELATIVE_NP
#endif

#if defined(HAVE_SEM_CLOCKWAIT)
 #define MDFN_USE_SEM_CLOCKWAIT
#elif defined(HAVE_SEM_CLOCKWAIT_NP)
 #define MDFN_USE_SEM_CLOCKWAIT_NP
#elif !defined(HAVE_SEM_TIMEDWAIT)
 #define MDFN_USE_CONDVAR_SEMAPHORES
#else

#endif
//
//
//
#include <pthread.h>

#if defined HAVE_SCHED_H
 #include <sched.h>
#endif

#if defined(HAVE_PTHREAD_NP_H)
 #include <pthread_np.h>
#endif

#if !defined(MDFN_USE_CONDVAR_SEMAPHORES)
 #include <semaphore.h>
#endif

#include <time.h>

namespace Mednafen
{
namespace MThreading
{
static __thread uintptr_t LocalThreadID = 0;

static INLINE void TimeSpec_AddNanoseconds(struct timespec* ts, uint64 add_ns)
{
 uint64 ns = (uint64)ts->tv_nsec + add_ns;

 ts->tv_sec += ns / (1000 * 1000 * 1000);
 ts->tv_nsec = ns % (1000 * 1000 * 1000);
}

struct Thread
{
 Thread() { }

 pthread_t t;
 int (*ep)(void*);
 void* data;
 int rv;
 private:
 Thread(const Thread&);
};

struct Mutex
{
 Mutex() { }

 pthread_mutex_t m;
 private:
 Mutex(const Mutex&);
};

struct Cond
{
 Cond() { }

 pthread_cond_t c;
 private:
 Cond(const Cond&);
};

static void* PTCEP(void* arg)
{
 Thread* t = (Thread*)arg;

 LocalThreadID = (uintptr_t)t;

 //printf("%016llx\n", (unsigned long long)ThreadID);

 t->rv = t->ep(t->data);

 return &t->rv;
}

// Dummy
template<typename T>
static int PTSNW(T fn, pthread_t t, const char* n)
{
 return 0;
}

// NetBSD
static MDFN_NOWARN_UNUSED int PTSNW(int (*fn)(pthread_t, const char*, void*), pthread_t t, const char* n)
{
 return fn(t, "%s", (void*)n);
}

// Linux
static MDFN_NOWARN_UNUSED int PTSNW(int (*fn)(pthread_t, const char*), pthread_t t, const char* n)
{
 return fn(t, n);
}

// Mac OS X
static MDFN_NOWARN_UNUSED int PTSNW(int (*fn)(const char*), pthread_t t, const char* n)
{
 return fn(n);
}

Thread* Thread_Create(int (*fn)(void *), void *data, const char* debug_name)
{
 std::unique_ptr<Thread> ret(new Thread());
 int ptec;

 ret->ep = fn;
 ret->data = data;

 if((ptec = pthread_create(&ret->t, nullptr, PTCEP, ret.get())))
 {
  ErrnoHolder ene(ptec);

  throw MDFN_Error(0, _("%s failed: %s"), "pthread_create()", ene.StrError());
 }

 if(debug_name)
 {
#if defined(HAVE_PTHREAD_SETNAME_NP) && !defined(pthread_setname_np)
  char tmp[16];

  strncpy(tmp, debug_name, 16);
  tmp[15] = 0;

  PTSNW(pthread_setname_np, ret->t, tmp);
#elif defined(HAVE_PTHREAD_SET_NAME_NP)
  pthread_set_name_np(ret->t, debug_name);
#endif
 }

 return ret.release();
}

void Thread_Wait(Thread* thread, int* status)
{
 try
 {
  void* vp;
  int ptec;

  if((ptec = pthread_join(thread->t, &vp)))
  {
   ErrnoHolder ene(ptec);

   throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_join()", ene.StrError());
  }

  if(vp != &thread->rv)
  {
   delete thread;
   throw MDFN_Error(0, _("Thread being joined exited improperly."));
  }

  if(status)
   *status = thread->rv;

  delete thread;
 }
 catch(std::exception& e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }
}

uintptr_t Thread_ID(void)
{
 //printf("%16llx -- %16llx -- %16llx\n", (unsigned long long)ThreadID, (unsigned long long)pthread_self(), (unsigned long long)SDL_ThreadID());
 return LocalThreadID;
}

#if defined(PTHREAD_AFFINITY_NP)
//template<typename T> static T MDFN_PTHREAD_NP_CPUSET_T_HELPER(int (*)(pthread_t, size_t, T*)) { T dummy; CPU_ZERO(&dummy); return dummy; }
//typedef decltype(MDFN_PTHREAD_NP_CPUSET_T_HELPER(pthread_getaffinity_np)) MDFN_PTHREAD_NP_CPUSET_T;

uint64 Thread_SetAffinity(Thread* thread, const uint64 mask)
{
 try
 {
  assert(mask != 0);
  //
  pthread_t const t = thread ? thread->t : pthread_self();
  PTHREAD_AFFINITY_NP c;
  uint64 ret = 0;
  int ptec;

  //printf("SetAffinity() %016llx %08x\n", (unsigned long long)t, mask);
  //
  //
  CPU_ZERO(&c);
  if((ptec = pthread_getaffinity_np(t, sizeof(c), &c)))
  {
   ErrnoHolder ene(ptec);

   throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_getaffinity_np()", ene.StrError());
  }

  for(unsigned i = 0; i < sizeof(ret) * 8 && i < CPU_SETSIZE; i++)
  {
   if(CPU_ISSET(i, &c))
    ret |= (uint64)1 << i;
  }
  //
  //
  CPU_ZERO(&c);

  for(unsigned i = 0; i < sizeof(mask) * 8 && i < CPU_SETSIZE; i++)
  {
   if((mask >> i) & 1)
    CPU_SET(i, &c);
  }

  if(CPU_SETSIZE < 64 && mask >= ((uint64)1 << CPU_SETSIZE))
  {
   throw MDFN_Error(EINVAL, _("Affinity mask specifies CPU beyond capacity of the CPU set."));
  }

  if((ptec = pthread_setaffinity_np(t, sizeof(c), &c)))
  {
   ErrnoHolder ene(ptec);

   throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_setaffinity_np()", ene.StrError());
  }

  return ret;
 }
 catch(std::exception& e)
 {
  throw MDFN_Error(0, _("Setting affinity to 0x%016llx failed: %s"), (unsigned long long)mask, e.what());
 }
}
#else

#warning "Compiling without affinity setting support."
uint64 Thread_SetAffinity(Thread* thread, uint64 mask)
{
 assert(mask != 0);
 //
 throw MDFN_Error(0, _("Setting affinity to 0x%016llx failed: %s"), (unsigned long long)mask, _("pthread_setaffinity_np() not available."));
}
#endif

static void CreateMutex(Mutex* ret)
{
 pthread_mutexattr_t attr;
 int ptec;

 if((ptec = pthread_mutexattr_init(&attr)))
 {
  ErrnoHolder ene(ptec);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_mutexattr_init()", ene.StrError());
 }

 if((ptec = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK/*PTHREAD_MUTEX_NORMAL*/)))
 {
  ErrnoHolder ene(ptec);

  pthread_mutexattr_destroy(&attr);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_mutexattr_settype()", ene.StrError());
 }

 if((ptec = pthread_mutex_init(&ret->m, &attr)))
 {
  ErrnoHolder ene(ptec);

  pthread_mutexattr_destroy(&attr);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_mutex_init()", ene.StrError());
 }

 pthread_mutexattr_destroy(&attr);
 //
 //
 //
 if((ptec = pthread_mutex_lock(&ret->m)))
 {
  ErrnoHolder ene(ptec);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_mutex_lock()", ene.StrError());
 }

 if((ptec = pthread_mutex_unlock(&ret->m)))
 {
  ErrnoHolder ene(ptec);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_mutex_unlock()", ene.StrError());
 }
}

Mutex* Mutex_Create(void)
{
 std::unique_ptr<Mutex> ret(new Mutex);

 CreateMutex(ret.get());

 return ret.release();
}

void Mutex_Destroy(Mutex* mutex) noexcept
{
 int ptec;

 if((ptec = pthread_mutex_destroy(&mutex->m)))
 {
  ErrnoHolder ene(ptec);

  MDFN_Notify(MDFN_NOTICE_ERROR, _("%s failed: %s"), "pthread_mutex_destroy()", ene.StrError());
 }

 delete mutex;
}

bool Mutex_Lock(Mutex* mutex) noexcept
{
 int ptec;

 if((ptec = pthread_mutex_lock(&mutex->m)))
 {
  fprintf(stderr, "pthread_mutex_lock() failed: %d\n", ptec);
  return false;
 }

 return true;
}

bool Mutex_Unlock(Mutex* mutex) noexcept
{
 int ptec;

 if((ptec = pthread_mutex_unlock(&mutex->m)))
 {
  fprintf(stderr, "pthread_mutex_unlock() failed: %d\n", ptec);
  return false;
 }

 return true;
}

static void CreateCond(Cond* ret)
{
 pthread_condattr_t attr;
 int ptec;

 if((ptec = pthread_condattr_init(&attr)))
 {
  ErrnoHolder ene(ptec);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_condattr_init()", ene.StrError());
 }

#if !defined(MDFN_USE_COND_TIMEDWAIT_RELATIVE_NP)
 if((ptec = pthread_condattr_setclock(&attr, CLOCK_MONOTONIC)))
 {
  ErrnoHolder ene(ptec);

  pthread_condattr_destroy(&attr);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_condattr_setclock()", ene.StrError());
 }
#endif

 if((ptec = pthread_cond_init(&ret->c, &attr)))
 {
  ErrnoHolder ene(ptec);

  pthread_condattr_destroy(&attr);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "pthread_cond_init()", ene.StrError());
 }

 pthread_condattr_destroy(&attr);
}

Cond* Cond_Create(void)
{
 std::unique_ptr<Cond> ret(new Cond);

 CreateCond(ret.get());

 return ret.release();
}

void Cond_Destroy(Cond* cond) noexcept
{
 int ptec;

 if((ptec = pthread_cond_destroy(&cond->c)))
 {
  ErrnoHolder ene(ptec);

  MDFN_Notify(MDFN_NOTICE_ERROR, _("%s failed: %s"), "pthread_cond_destroy()", ene.StrError());
 }

 delete cond;
}

bool Cond_Signal(Cond* cond) noexcept
{
 int ptec;

 if((ptec = pthread_cond_signal(&cond->c)))
 {
  fprintf(stderr, "pthread_cond_signal() failed: %d\n", ptec);
  return false;
 }

 return true;
}

bool Cond_Wait(Cond* cond, Mutex* mutex) noexcept
{
 int ptec;

 if((ptec = pthread_cond_wait(&cond->c, &mutex->m)))
 {
  fprintf(stderr, "pthread_cond_wait() failed: %d\n", ptec);
  return false;
 }

 return true;
}

#if !defined(MDFN_USE_COND_TIMEDWAIT_RELATIVE_NP)
bool Cond_TimedWait(Cond* cond, Mutex* mutex, unsigned ms) noexcept
{
 struct timespec abstime;

 memset(&abstime, 0, sizeof(abstime));

 if(clock_gettime(CLOCK_MONOTONIC, &abstime))
 {
  fprintf(stderr, "clock_gettime() failed: %m\n");
  return false;
 }

 TimeSpec_AddNanoseconds(&abstime, (uint64)ms * 1000 * 1000);

 int ctw_rv = pthread_cond_timedwait(&cond->c, &mutex->m, &abstime);
 if(ctw_rv == ETIMEDOUT)
  return false;
 else if(ctw_rv)
 {
  fprintf(stderr, "pthread_cond_timedwait() failed: %d\n", ctw_rv);
  return false;
 }

 return true;
}
#else
bool Cond_TimedWait(Cond* cond, Mutex* mutex, unsigned ms) noexcept
{
 struct timespec reltime;

 memset(&reltime, 0, sizeof(reltime));

 TimeSpec_AddNanoseconds(&reltime, (uint64)ms * 1000 * 1000);

 int ctw_rv = pthread_cond_timedwait_relative_np(&cond->c, &mutex->m, &reltime);
 if(ctw_rv == ETIMEDOUT)
  return false;
 else if(ctw_rv)
 {
  fprintf(stderr, "pthread_cond_timedwait_relative_np() failed: %d\n", ctw_rv);
  return false;
 }

 return true;
}
#endif

#if !defined(MDFN_USE_CONDVAR_SEMAPHORES)
//
//
//
struct Sem
{
 Sem() { }

 sem_t s;
 private:
 Sem(const Sem&);
};

Sem* Sem_Create(void)
{
 std::unique_ptr<Sem> ret(new Sem);

 if(sem_init(&ret->s, 0, 0))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("%s failed: %s"), "sem_init()", ene.StrError());
 }

 return ret.release();
}

void Sem_Destroy(Sem* sem) noexcept
{
 if(sem_destroy(&sem->s))
 {
  ErrnoHolder ene(errno);

  MDFN_Notify(MDFN_NOTICE_ERROR, _("%s failed: %s"), "sem_destroy()", ene.StrError());
 }

 delete sem;
}

bool Sem_Wait(Sem* sem) noexcept
{
 tryagain:
 if(sem_wait(&sem->s))
 {
  if(errno == EINTR)
   goto tryagain;

  fprintf(stderr, "sem_wait() failed: %m");
  return false;
 }

 return true;
}

#if defined(MDFN_USE_SEM_CLOCKWAIT_NP)
bool Sem_TimedWait(Sem* sem, unsigned ms) noexcept
{
 struct timespec abstime;

 memset(&abstime, 0, sizeof(abstime));

 if(clock_gettime(CLOCK_MONOTONIC, &abstime))
 {
  fprintf(stderr, "clock_gettime() failed: %m");
  return false;
 }

 TimeSpec_AddNanoseconds(&abstime, (uint64)ms * 1000 * 1000);

 tryagain:
 if(sem_clockwait_np(&sem->s, CLOCK_MONOTONIC, TIMER_ABSTIME, &abstime, nullptr))
 {
  if(errno == EINTR)
   goto tryagain;

  if(errno == ETIMEDOUT)
   return false;
  //
  fprintf(stderr, "sem_clockwait_np() failed: %m");
  return false;
 }

 return true;
}
#elif defined(MDFN_USE_SEM_CLOCKWAIT)
bool Sem_TimedWait(Sem* sem, unsigned ms) noexcept
{
 struct timespec abstime;

 memset(&abstime, 0, sizeof(abstime));

 if(clock_gettime(CLOCK_MONOTONIC, &abstime))
 {
  fprintf(stderr, "clock_gettime() failed: %m");
  return false;
 }

 TimeSpec_AddNanoseconds(&abstime, (uint64)ms * 1000 * 1000);

 tryagain:
 if(sem_clockwait(&sem->s, CLOCK_MONOTONIC, &abstime))
 {
  if(errno == EINTR)
   goto tryagain;

  if(errno == ETIMEDOUT)
   return false;
  //
  fprintf(stderr, "sem_clockwait() failed: %m");
  return false;
 }

 return true;
}
#else

#warning "Using realtime-clock-based sem_timedwait()"

bool Sem_TimedWait(Sem* sem, unsigned ms) noexcept
{
 struct timespec abstime;

 memset(&abstime, 0, sizeof(abstime));

 if(clock_gettime(CLOCK_REALTIME, &abstime))
 {
  fprintf(stderr, "clock_gettime() failed: %m");
  return false;
 }

 TimeSpec_AddNanoseconds(&abstime, (uint64)ms * 1000 * 1000);

 tryagain:
 if(sem_timedwait(&sem->s, &abstime))
 {
  if(errno == EINTR)
   goto tryagain;

  if(errno == ETIMEDOUT)
   return false;
  //
  fprintf(stderr, "sem_timedwait() failed: %m");
  return false;
 }

 return true;
}
#endif

bool Sem_Post(Sem* sem) noexcept
{
 if(sem_post(&sem->s))
 { 
  fprintf(stderr, "sem_post() failed: %m");
  return false;
 }

 return true;
}
#else
#warning "Cond var semaphore"
//
// Semaphores via condition var.
//
struct Sem
{
 Sem() { }

 Cond c;
 Mutex m;
 int v;
 
 private:
 Sem(const Sem&);
};

Sem* Sem_Create(void)
{
 std::unique_ptr<Sem> ret(new Sem);

 CreateCond(&ret->c);
 CreateMutex(&ret->m);

 ret->v = 0;

 return ret.release();
}

void Sem_Destroy(Sem* sem) noexcept
{
 int ptec;

 if((ptec = pthread_cond_destroy(&sem->c.c)))
 {
  ErrnoHolder ene(ptec);

  MDFN_Notify(MDFN_NOTICE_ERROR, _("%s failed: %s"), "pthread_cond_destroy()", ene.StrError());
 }

 if((ptec = pthread_mutex_destroy(&sem->m.m)))
 {
  ErrnoHolder ene(ptec);

  MDFN_Notify(MDFN_NOTICE_ERROR, _("%s failed: %s"), "pthread_mutex_destroy()", ene.StrError());
 }

 delete sem;
}

bool Sem_Wait(Sem* sem) noexcept
{
 if(!Mutex_Lock(&sem->m))
  return false;

 while(!sem->v)
 {
  if(!Cond_Wait(&sem->c, &sem->m))
  {
   Mutex_Unlock(&sem->m);
   return false;
  }
 }

 sem->v--;
 assert(sem->v >= 0);
 return Mutex_Unlock(&sem->m);
}

bool Sem_TimedWait(Sem* sem, unsigned ms) noexcept
{
 if(!Mutex_Lock(&sem->m))
  return false;

 while(!sem->v)
 {
  if(!Cond_TimedWait(&sem->c, &sem->m, ms))
  {
   Mutex_Unlock(&sem->m);
   return false;
  }
 }

 sem->v--;
 assert(sem->v >= 0);
 return Mutex_Unlock(&sem->m);
}

bool Sem_Post(Sem* sem) noexcept
{
 if(!Mutex_Lock(&sem->m))
  return false;

 if(sem->v == INT_MAX)
 {
  Mutex_Unlock(&sem->m);
  return false;
 }

 sem->v++;

 bool ret = true;

 ret &= Cond_Signal(&sem->c);
 ret &= Mutex_Unlock(&sem->m);

 return ret;
}

#endif

}
}
