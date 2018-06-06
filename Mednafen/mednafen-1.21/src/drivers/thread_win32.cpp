/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* thread_win32.cpp:
**  Copyright (C) 2014-2017 Mednafen Team
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
 Condition variables here are implemented in a half-assed manner(thin wrapper around Win32 events).
 This implementation is prone to large numbers of spurious wakeups, and is not easily extended to allow for correctly waking up all waiting threads.
 We don't need that feature right now, and by the time we need it, maybe we can just use Vista+ condition variables and forget about XP ;).

 ...but at least the code is simple and should be much faster than SDL 1.2's condition variables for our purposes.
*/

#include "main.h"

#include <stdio.h>
#include <assert.h>
#include <windows.h>
#include <limits.h>

#if 0
typedef struct
{
 union
 {
  void* something;
  unsigned char lalala[64];
 };
} NAKED_CONDITION_VARIABLE;

static int use_cv = -1;
static HMODULE kdh = NULL;
static void WINAPI (*p_InitializeConditionVariable)(NAKED_CONDITION_VARIABLE*) = NULL;
static BOOL WINAPI (*p_SleepConditionVariableCS)(NAKED_CONDITION_VARIABLE*, PCRITICAL_SECTION, DWORD) = NULL;
static void WINAPI (*p_WakeConditionVariable)(NAKED_CONDITION_VARIABLE*) = NULL;

template<typename T>
static bool GetPAW(HMODULE dll_handle, T& pf, const char *name)
{
 pf = (T)GetProcAddress(dll_handle, name);
 return(pf != NULL);
}

static void InitCVStuff(void)
{
 kdh = LoadLibrary("Kernel32.dll");

 GetPAW(kdh, p_InitializeConditionVariable, "InitializeConditionVariable");
 GetPAW(kdh, p_SleepConditionVariableCS, "SleepConditionVariableCS");
 GetPAW(kdh, p_WakeConditionVariable, "WakeConditionVariable");

 use_cv = (p_InitializeConditionVariable && p_SleepConditionVariableCS && p_WakeConditionVariable);

 fprintf(stderr, "use_cv=%d\n", use_cv);
}
#endif

struct MDFN_Thread
{
 HANDLE thr;
 int (*fn)(void *);
 void* data;
};

struct MDFN_Cond
{
#if 0
 union
 {
  HANDLE evt;
  NAKED_CONDITION_VARIABLE cv;
 };
#endif
 HANDLE evt;
};

struct MDFN_Sem
{
 HANDLE sem;
};

struct MDFN_Mutex
{
 CRITICAL_SECTION cs;
};

static void TestStackAlign(void) NO_INLINE;
static void TestStackAlign(void)
{
 alignas(16) char test_array[17];
 unsigned volatile memloc = ((unsigned long long)&test_array[0]);
 assert((memloc & 0xF) == 0);

 //unsigned char memloc = ((unsigned long long)&test_array[0]) & 0xFF;

 //assert(((((memloc * 0x80200802ULL) & 0x0884422110ULL) * 0x0101010101ULL) >> 36) == 0);

 //printf("%02x\n", memloc);
 //trio_snprintf(test_array, sizeof(test_array), "%02x", memloc);
 //assert(test_array[1] == '0');
}

static unsigned __stdcall ThreadPivot(void* data) __attribute__((force_align_arg_pointer));
static unsigned __stdcall ThreadPivot(void* data)
{
 TestStackAlign();

 MDFN_Thread* t = (MDFN_Thread*)data;

 return t->fn(t->data);
}

MDFN_Thread *MDFND_CreateThread(int (*fn)(void *), void *data)
{
 MDFN_Thread* ret = NULL;

#if 0
 if(use_cv < 0)
  InitCVStuff();
#endif

 if(!(ret = (MDFN_Thread*)calloc(1, sizeof(MDFN_Thread))))
 {
  return(NULL);
 }

 ret->fn = fn;
 ret->data = data;

 if(!(ret->thr = (HANDLE)_beginthreadex(NULL, 0, ThreadPivot, ret, 0, NULL)))
 {
  // TODO: Check errno.
  free(ret);
  return(NULL);
 }

 return(ret);
}

void MDFND_WaitThread(MDFN_Thread *thread, int *status)
{
 DWORD exc = -1;

 WaitForSingleObject(thread->thr, INFINITE);
 GetExitCodeThread(thread->thr, &exc);
 if(status != NULL)
  *status = exc;

 CloseHandle(thread->thr);

 free(thread);
}

uint32 MDFND_ThreadID(void)
{
 return GetCurrentThreadId();
}

//
//
//

MDFN_Mutex *MDFND_CreateMutex(void)
{
 MDFN_Mutex* ret;

 if(!(ret = (MDFN_Mutex*)calloc(1, sizeof(MDFN_Mutex))))
 {
  fprintf(stderr, "Error allocating memory for critical section.");
  return(NULL);
 }

 InitializeCriticalSection(&ret->cs);

 return ret;
}

void MDFND_DestroyMutex(MDFN_Mutex *mutex)
{
 DeleteCriticalSection(&mutex->cs);
 free(mutex);
}

int MDFND_LockMutex(MDFN_Mutex *mutex)
{
 EnterCriticalSection(&mutex->cs);
 return(0);
}

int MDFND_UnlockMutex(MDFN_Mutex *mutex)
{
 LeaveCriticalSection(&mutex->cs);
 return(0);
}

//
//
//

MDFN_Cond* MDFND_CreateCond(void)
{
#if 0
 if(use_cv < 0)
  InitCVStuff();
#endif

 MDFN_Cond* ret;

 if(!(ret = (MDFN_Cond*)calloc(1, sizeof(MDFN_Cond))))
 {
  return(NULL);
 }

#if 0
 if(use_cv)
 {
  memset(ret->cv.lalala, 0xAA, 64);
  p_InitializeConditionVariable(&ret->cv);
  for(int i = 0; i < 64; i++)
  {
   printf("%2d: %02x\n", i, ret->cv.lalala[i]);
  }
 }
 else
#endif
 {
  if(!(ret->evt = CreateEvent(NULL, FALSE, FALSE, NULL)))
  {
   free(ret);
   return(NULL);
  }
 }

 return(ret);
}

void MDFND_DestroyCond(MDFN_Cond* cond)
{
#if 0
 if(use_cv)
 {

 }
 else
#endif
 {
  CloseHandle(cond->evt);
 }
 free(cond);
}

int MDFND_SignalCond(MDFN_Cond* cond)
{
#if 0
 if(use_cv)
 {
  p_WakeConditionVariable(&cond->cv);
  return(0);
 }
 else
#endif
 {
  return(SetEvent(cond->evt) ? 0 : -1);
 }
}

int MDFND_WaitCond(MDFN_Cond* cond, MDFN_Mutex* mutex)
{
#if 0
 if(use_cv)
 {
  if(p_SleepConditionVariableCS(&cond->cv, &mutex->cs, INFINITE) == 0)
  {
   fprintf(stderr, "SleepConditionVariableCS() failed.\n");
   return(-1);
  }

  return(0);
 }
 else
#endif
 {
  LeaveCriticalSection(&mutex->cs);

  WaitForSingleObject(cond->evt, INFINITE);

  EnterCriticalSection(&mutex->cs);

  return(0);
 }
}

int MDFND_WaitCondTimeout(MDFN_Cond* cond, MDFN_Mutex* mutex, unsigned ms)
{
 int ret = 0;

#if 0
 if(use_cv)
 {
  if(p_SleepConditionVariableCS(&cond->cv, &mutex->cs, ms) == 0)
  {
   fprintf(stderr, "SleepConditionVariableCS() failed.\n");
   ret = -1;
  }
 }
 else
#endif
 {
  ResetEvent(cond->evt);	// Reset before unlocking mutex.
  LeaveCriticalSection(&mutex->cs);

  switch(WaitForSingleObject(cond->evt, ms))
  {
   case WAIT_OBJECT_0:
	ret = 0;
	break;

   case WAIT_TIMEOUT:
	ret = MDFND_COND_TIMEDOUT;
	break;

   default:
	ret = -1;
	break;
  }

  EnterCriticalSection(&mutex->cs);
 }

 return(ret);
}

//
//
//

MDFN_Sem* MDFND_CreateSem(void)
{
 MDFN_Sem* ret;

 if(!(ret = (MDFN_Sem*)calloc(1, sizeof(MDFN_Sem))))
 {
  fprintf(stderr, "Error allocating memory for semaphore.");
  return(NULL);
 }

 if(!(ret->sem = CreateSemaphore(NULL, 0, INT_MAX, NULL)))
 {
  fprintf(stderr, "CreateSemaphore() failed.\n");
  free(ret);
  return(NULL);
 }

 return(ret);
}

void MDFND_DestroySem(MDFN_Sem* sem)
{
 CloseHandle(sem->sem);
 sem->sem = NULL;
 free(sem);
}

int MDFND_PostSem(MDFN_Sem* sem)
{
 if(ReleaseSemaphore(sem->sem, 1, NULL) != 0)
  return(0);
 else
  return(-1);
}

int MDFND_WaitSem(MDFN_Sem* sem)
{
 if(WaitForSingleObject(sem->sem, INFINITE) == WAIT_OBJECT_0)
  return(0);
 else
  return(-1);
}

int MDFND_WaitSemTimeout(MDFN_Sem* sem, unsigned ms)
{
 int ret = 0;

 switch(WaitForSingleObject(sem->sem, ms))
 {
   case WAIT_OBJECT_0:
	ret = 0;
	break;

   case WAIT_TIMEOUT:
	ret = MDFND_SEM_TIMEDOUT;
	break;

   default:
	ret = -1;
	break;
 }
 return(ret);
}

