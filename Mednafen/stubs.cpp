#include "mednafen/types.h"
#include "mednafen/git.h"
#include "mednafen/mednafen-driver.h"
#include "thread.h"

#include <iostream>
#include <sys/time.h>
#include <unistd.h>

void MDFND_Sleep(unsigned int time)
{
    usleep(time * 1000);
}

void MDFND_DispMessage(char *str)
{
    //std::cerr << str;
}

void MDFND_Message(const char *str)
{
    std::cerr << str;
}

void MDFND_MidSync(const EmulateSpecStruct *)
{}

void MDFND_PrintError(const char* err)
{
    std::cerr << err;
}

void MDFND_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{}

void MDFND_NetplayText(const char* text, bool NetEcho)
{}

MDFN_Thread *MDFND_CreateThread(int (*fn)(void *), void *data)
{
    return (MDFN_Thread*)sthread_create((void (*)(void*))fn, data);
}

void MDFND_SetMovieStatus(StateStatusStruct *) {}
void MDFND_SetStateStatus(StateStatusStruct *) {}

void MDFND_WaitThread(MDFN_Thread *thr, int *val)
{
    sthread_join((sthread_t*)thr);

    if(val)
    {
        *val = 0;
        std::cerr << "WaitThread relies on return value." << std::endl;
    }
}

void MDFND_KillThread(MDFN_Thread *)
{
    std::cerr << "Killing a thread is a BAD IDEA!" << std::endl;
}

MDFN_Mutex *MDFND_CreateMutex()
{
    return (MDFN_Mutex*)slock_new();
}

void MDFND_DestroyMutex(MDFN_Mutex *lock)
{
    slock_free((slock_t*)lock);
}

int MDFND_LockMutex(MDFN_Mutex *lock)
{
    slock_lock((slock_t*)lock);
    return 0;
}

int MDFND_UnlockMutex(MDFN_Mutex *lock)
{
    slock_unlock((slock_t*)lock);
    return 0;
}

MDFN_Cond* MDFND_CreateCond(void)
{
    return (MDFN_Cond*)scond_new();
}

void MDFND_DestroyCond(MDFN_Cond* cond)
{
    scond_free((scond_t*)cond);
}

int MDFND_SignalCond(MDFN_Cond* cond)
{
    scond_signal((scond_t*)cond);
    return 0;
}

int MDFND_WaitCond(MDFN_Cond* cond, MDFN_Mutex* mutex)
{
    scond_wait((scond_t*)cond, (slock_t*)mutex);
    return 0;
}

void MDFND_SendData(const void*, uint32) {}
void MDFND_RecvData(void *, uint32) {}
void MDFND_NetplayText(const uint8*, bool) {}
void MDFND_NetworkClose() {}
int MDFND_NetworkConnect() { return 0; }

uint32 MDFND_GetTime()
{
    static bool first = true;
    static uint32_t start_ms;

    struct timeval val;
    gettimeofday(&val, NULL);
    uint32_t ms = val.tv_sec * 1000 + val.tv_usec / 1000;

    if(first)
    {
        start_ms = ms;
        first = false;
    }
    
    return ms - start_ms;
}
