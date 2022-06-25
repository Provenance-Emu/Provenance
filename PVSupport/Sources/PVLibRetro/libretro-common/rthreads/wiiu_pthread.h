#ifndef _WIIU_PTHREAD_WRAP_WIIU_
#define _WIIU_PTHREAD_WRAP_WIIU_

#include "../include/retro_inline.h"
#include <stdint.h>
#include <string.h>
#include <malloc.h>

#ifdef __cplusplus
extern "C" {
#endif

#define OS_THREAD_TAG 0x74487244u
typedef struct __attribute__ ((aligned (8))) OSThread { uint64_t tag, buf[299]; } OSThread;
typedef uint8_t OSThreadAttributes;
enum OS_THREAD_ATTRIB
{
   OS_THREAD_ATTRIB_AFFINITY_CPU0   = 1 << 0, /*! Allow the thread to run on CPU0. */
   OS_THREAD_ATTRIB_AFFINITY_CPU1   = 1 << 1, /*! Allow the thread to run on CPU1. */
   OS_THREAD_ATTRIB_AFFINITY_CPU2   = 1 << 2, /*! Allow the thread to run on CPU2. */
   OS_THREAD_ATTRIB_AFFINITY_ANY    = ((1 << 0) | (1 << 1) | (1 << 2)), /*! Allow the thread to run any CPU. */
   OS_THREAD_ATTRIB_DETACHED        = 1 << 3, /*! Start the thread detached. */
   OS_THREAD_ATTRIB_STACK_USAGE     = 1 << 5 /*! Enables tracking of stack usage. */
};
typedef int (*OSThreadEntryPointFn)(int argc, const char **argv);
typedef void (*OSThreadCleanupCallbackFn)(OSThread *thread, void *stack);
int OSCreateThread(OSThread *thread, OSThreadEntryPointFn entry, int32_t argc, char **argv, void *stack, uint32_t stackSize, int32_t priority, OSThreadAttributes attributes);
void OSDetachThread(OSThread *thread);
OSThreadCleanupCallbackFn OSSetThreadCleanupCallback(OSThread *thread, OSThreadCleanupCallbackFn callback);
int OSResumeThread(OSThread *thread);

#define OS_MUTEX_TAG 0x6D557458u
typedef struct __attribute__ ((aligned (8))) OSMutex { uint32_t tag, buf[31]; } OSMutex;
void OSInitMutex(OSMutex *mutex);
void OSLockMutex(OSMutex *mutex);
void OSUnlockMutex(OSMutex *mutex);

#define OS_CONDITION_TAG 0x634E6456u
typedef struct __attribute__ ((aligned (8))) OSCondition { uint32_t tag, buf[16]; } OSCondition;
void OSInitCond(OSCondition *condition);
void OSWaitCond(OSCondition *condition, OSMutex *mutex);
void OSSignalCond(OSCondition *condition);

#ifdef __cplusplus
}
#endif

typedef struct WiiUThread* pthread_t;
typedef int pthread_attr_t;
#define pthread_attr_init(a)
#define pthread_attr_setstacksize(a,b)
#define pthread_attr_destroy(a)

typedef struct WiiUThread
{
   unsigned char stack[DBP_STACK_SIZE];
   OSThread osthread;
   void *(*start_routine)(void*);
   void *start_arg;
} WiiUThread;

static int WiiUThreadEntryPoint(int, WiiUThread *t)
{
   return (int)(size_t)t->start_routine(t->start_arg);
}

static void WiiUThreadCleanup(OSThread *thread, WiiUThread *t)
{
   free(t);
}

static INLINE int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void*), void *arg)
{
   WiiUThread* t = (WiiUThread*)memalign(16, sizeof(WiiUThread));
   if (!t) return 0;
   memset(t, 0, sizeof(WiiUThread));

   t->osthread.tag = OS_THREAD_TAG;
   t->start_routine = start_routine;
   t->start_arg = arg;
   int res = OSCreateThread(&t->osthread, (OSThreadEntryPointFn)WiiUThreadEntryPoint, 1, (char**)t, (t->stack+sizeof(t->stack)), sizeof(t->stack), 10, (OSThreadAttributes)(OS_THREAD_ATTRIB_AFFINITY_ANY | OS_THREAD_ATTRIB_DETACHED));
   if (!res)
      return 0;

   OSSetThreadCleanupCallback(&t->osthread, (OSThreadCleanupCallbackFn)WiiUThreadCleanup);
   OSResumeThread(&t->osthread);
   return res;
}

static INLINE int pthread_detach(pthread_t thread)
{
   // Seems with devkitPPC_r29-1, OSDetachThread is not available
   //OSDetachThread(&wiiu_one_thread);
   return 0;
}

typedef OSMutex pthread_mutex_t;
typedef int pthread_mutexattr_t;

static INLINE int pthread_mutex_init(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr)
{
   memset(mutex, 0, sizeof(*mutex));
   mutex->tag = OS_MUTEX_TAG;
   return OSInitMutex(mutex), 0;
}

static INLINE int pthread_mutex_destroy(pthread_mutex_t *mutex)
{
   return 0;
}

static INLINE int pthread_mutex_lock(pthread_mutex_t *mutex)
{
   return OSLockMutex(mutex),0;
}

static INLINE int pthread_mutex_unlock(pthread_mutex_t *mutex)
{
   return OSUnlockMutex(mutex),0;
}

typedef OSCondition pthread_cond_t;
typedef int pthread_condattr_t;

static INLINE int pthread_cond_init(pthread_cond_t *cond, const pthread_condattr_t *attr)
{
   memset(cond, 0, sizeof(*cond));
   cond->tag = OS_CONDITION_TAG;
   return OSInitCond(cond), 0;
}

static INLINE int pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex)
{
   return OSWaitCond(cond, mutex), 0;
}

static INLINE int pthread_cond_signal(pthread_cond_t *cond)
{
   return OSSignalCond(cond), 0;
}

static INLINE int pthread_cond_broadcast(pthread_cond_t *cond)
{
   return OSSignalCond(cond), 0;
}

static INLINE int pthread_cond_destroy(pthread_cond_t *cond)
{
   return 0;
}

#endif
