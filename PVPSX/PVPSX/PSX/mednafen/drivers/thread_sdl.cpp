/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "main.h"

MDFN_Thread *MDFND_CreateThread(int (*fn)(void *), void *data)
{
 return (MDFN_Thread*)SDL_CreateThread(fn, data);
}

void MDFND_WaitThread(MDFN_Thread *thread, int *status)
{
 SDL_WaitThread((SDL_Thread*)thread, status);
}

MDFN_Mutex *MDFND_CreateMutex(void)
{
 return (MDFN_Mutex*)SDL_CreateMutex();
}

void MDFND_DestroyMutex(MDFN_Mutex *mutex)
{
 SDL_DestroyMutex((SDL_mutex*)mutex);
}

int MDFND_LockMutex(MDFN_Mutex *mutex)
{
 return SDL_mutexP((SDL_mutex*)mutex);
}

int MDFND_UnlockMutex(MDFN_Mutex *mutex)
{
 return SDL_mutexV((SDL_mutex*)mutex);
}

MDFN_Cond* MDFND_CreateCond(void)
{
 return (MDFN_Cond*)SDL_CreateCond();
}

void MDFND_DestroyCond(MDFN_Cond* cond)
{
 SDL_DestroyCond((SDL_cond*)cond);
}

int MDFND_SignalCond(MDFN_Cond* cond)
{
 return SDL_CondSignal((SDL_cond*)cond);
}

int MDFND_WaitCond(MDFN_Cond* cond, MDFN_Mutex* mutex)
{
 return SDL_CondWait((SDL_cond*)cond, (SDL_mutex*)mutex);
}

int MDFND_WaitCondTimeout(MDFN_Cond* cond, MDFN_Mutex* mutex, unsigned ms)
{
 int ret = SDL_CondWaitTimeout((SDL_cond*)cond, (SDL_mutex*)mutex, ms);

 if(ret == SDL_MUTEX_TIMEDOUT)
  return(MDFND_COND_TIMEDOUT);
 else
  return(ret);
}

MDFN_Sem* MDFND_CreateSem(void)
{
 return (MDFN_Sem*)SDL_CreateSemaphore(0);
}

void MDFND_DestroySem(MDFN_Sem* sem)
{
 SDL_DestroySemaphore((SDL_sem*)sem);
}

int MDFND_PostSem(MDFN_Sem* sem)
{
 return SDL_SemPost((SDL_sem*)sem);
}

int MDFND_WaitSem(MDFN_Sem* sem)
{
 return SDL_SemWait((SDL_sem*)sem);
}

int MDFND_WaitSemTimeout(MDFN_Sem* sem, unsigned ms)
{
 int ret = SDL_SemWaitTimeout((SDL_sem*)sem, ms);

 if(ret == SDL_MUTEX_TIMEDOUT)
  return(MDFND_SEM_TIMEDOUT);
 else
  return(ret);
}

uint32 MDFND_ThreadID(void)
{
 return SDL_ThreadID();
}
