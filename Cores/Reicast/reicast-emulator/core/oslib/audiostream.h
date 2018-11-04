#pragma once
#include "types.h"

//Get used size in the ring buffer
u32 asRingUsedCount();
//Get free size in the ring buffer
u32 asRingFreeCount();
//Read 'Count' samples from the ring buffer.Returns true if successful.
//If sz==0 then a whole buffer is read
bool asRingRead(u8* dst,u32 count=0);
void UpdateBuff(u8* pos);

typedef void (*audio_backend_init_func_t)();
typedef u32 (*audio_backend_push_func_t)(void*, u32, bool);
typedef void (*audio_backend_term_func_t)();
typedef struct {
    string slug;
    string name;
    audio_backend_init_func_t init;
    audio_backend_push_func_t push;
    audio_backend_term_func_t term;
} audiobackend_t;
extern bool RegisterAudioBackend(audiobackend_t* backend);
extern void InitAudio();
extern u32 PushAudio(void* frame, u32 amt, bool wait);
extern void TermAudio();
