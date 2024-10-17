


#ifndef _WINDSOUND_H
#define _WINDSOUND_H

#include <dsound.h>
class CMixBuffer;

typedef LPDIRECTSOUND DSoundObjectT;

void DSoundInit(HWND hWnd);
void DSoundShutdown();
LPDIRECTSOUND DSoundGetObject();

void DSoundSetFormat(Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels, Uint32 nSamples);
CMixBuffer *DSoundGetBuffer();

#endif
