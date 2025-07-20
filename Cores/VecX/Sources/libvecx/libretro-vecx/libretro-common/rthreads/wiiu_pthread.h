/* Copyright  (C) 2010-2016 The RetroArch team
 *
 * ---------------------------------------------------------------------------------------
 * The following license statement only applies to this file (wiiu_pthread.h).
 * ---------------------------------------------------------------------------------------
 *
 * Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef _WIIU_PTHREAD_WRAP_WIIU_
#define _WIIU_PTHREAD_WRAP_WIIU_

#include <retro_inline.h>
#include <wiiu/os/condition.h>
#include <wiiu/os/thread.h>
#include <wiiu/os/mutex.h>
#include <malloc.h>
#define STACKSIZE (8 * 1024)

typedef OSThread* pthread_t;
typedef OSMutex* pthread_mutex_t;
typedef void* pthread_mutexattr_t;
typedef int pthread_attr_t;
typedef OSCondition* pthread_cond_t;
typedef OSCondition* pthread_condattr_t;

static INLINE int pthread_create(pthread_t *thread,
      const pthread_attr_t *attr, void *(*start_routine)(void*), void *arg)
{
   OSThread *t = memalign(8, sizeof(OSThread));
   void *stack = memalign(32, STACKSIZE);
   bool ret = OSCreateThread(t, (OSThreadEntryPointFn)start_routine, 
      (uint32_t)arg, NULL, (void*)(((uint32_t)stack)+STACKSIZE), STACKSIZE, 8, OS_THREAD_ATTRIB_AFFINITY_ANY);
   if(ret == true)
   {
      OSResumeThread(t);
      *thread = t;
   }
   else
      *thread = NULL;
   return (ret == true) ? 0 : -1;
}

static INLINE pthread_t pthread_self(void)
{
   return OSGetCurrentThread();
}

static INLINE int pthread_mutex_init(pthread_mutex_t *mutex,
      const pthread_mutexattr_t *attr)
{
   OSMutex *m = malloc(sizeof(OSMutex));
   OSInitMutex(m);
   *mutex = m;
   return 0;
}

static INLINE int pthread_mutex_destroy(pthread_mutex_t *mutex)
{
   if(*mutex)
      free(*mutex);
   *mutex = NULL;
   return 0;
}

static INLINE int pthread_mutex_lock(pthread_mutex_t *mutex)
{
   OSLockMutex(*mutex);
   return 0;
}

static INLINE int pthread_mutex_unlock(pthread_mutex_t *mutex)
{
   OSUnlockMutex(*mutex);
   return 0;
}

static INLINE void pthread_exit(void *retval)
{
   (void)retval;
   OSExitThread(0);
}

static INLINE int pthread_detach(pthread_t thread)
{
   OSDetachThread(thread);
   return 0;
}

static INLINE int pthread_join(pthread_t thread, void **retval)
{
   (void)retval;
   bool ret = OSJoinThread(thread, NULL);
   if(ret == true)
   {
      free(thread->stackEnd);
      free(thread);
   }
   return (ret == true) ? 0 : -1;
}

static INLINE int pthread_mutex_trylock(pthread_mutex_t *mutex)
{
   return OSTryLockMutex(*mutex);
}

static INLINE int pthread_cond_wait(pthread_cond_t *cond,
      pthread_mutex_t *mutex)
{
   OSWaitCond(*cond, *mutex);
   return 0;
}

static INLINE int pthread_cond_timedwait(pthread_cond_t *cond,
      pthread_mutex_t *mutex, const struct timespec *abstime)
{
   //FIXME: actual timeout needed
   (void)abstime;
   return pthread_cond_wait(cond, mutex);
}

static INLINE int pthread_cond_init(pthread_cond_t *cond,
      const pthread_condattr_t *attr)
{
   OSCondition *c = malloc(sizeof(OSCondition));
   OSInitCond(c);
   *cond = c;
   return 0;
}

static INLINE int pthread_cond_signal(pthread_cond_t *cond)
{
   OSSignalCond(*cond);
   return 0;
}

static INLINE int pthread_cond_broadcast(pthread_cond_t *cond)
{
   //FIXME: no OS equivalent
   (void)cond;
   return 0;
}

static INLINE int pthread_cond_destroy(pthread_cond_t *cond)
{
   if(*cond)
      free(*cond);
   *cond = NULL;
   return 0;
}

extern int pthread_equal(pthread_t t1, pthread_t t2);

#endif
