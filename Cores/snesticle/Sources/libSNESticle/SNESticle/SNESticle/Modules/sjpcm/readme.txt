----------------------------------------------
SjPCM v2.0 - PCM streaming library for the PS2
----------------------------------------------

SjPCM v2.0 - by Nicholas Van Veen (aka Sjeep)
Buffer status code by Wonko
Documentation by Wonko and Sjeep

Introduction
------------

SjPCM provides a PS2 IOP module (sjpcm.irx) and EE-side interface (sjpcm.h
and sjpcm_rpc.c) to output a continuos sound stream to a stereo channel.

All sound must be sampled at 48kHz, 16bit and uncompressed.

SjPCM operated in two modes: synchronised and unsynchronised. Synchronised
mode is suited for use in applications where audio output must be accurately
synchronised with video output, and the ability to buffer sound a few frames
ahead is not possible (i.e.: emulator ports). Unsynchronised mode is suited for
use in applications where audio data can be buffered a few frames ahead
(i.e.: audio players - mod, mp3).

Synchronised mode may be necessary because the rates of video output and
audio output seem to differ, as the read and write offsets in the sound
buffer progress at _slightly_ different rates, causing gradual de-sync of
sound and video output. To remedy this, the read and write offsets are
synchronised every few frames - however this means that some samples will be
skipped, causing an undesirable crackling effect in the audio output.

In unsynchronised mode, the different video and audio output rates are not a
problem since if a buffer underrun is predicted to occur, you can just enqueue
another frame of sound data. If a buffer overrun is predicted to occur, you
can just skip sending sound data for that frame.

EE-side function reference
--------------------------

*** void SjPCM_Puts(char *format, ...);
Output log messages.

*** int SjPCM_Init(int sync);
Initialize sjpcm. Must be called once before any other call to the
sjpcm library. 'sync' is 1 for synchronised mode, 0 for unsyncrhonised mode.

*** void SjPCM_Enqueue(short *left, short *right, int size, int wait);
Send 'size' samples from 'left' and 'right' to the sjpcm sound output 
buffers. 'size' MUST be 800 for NTSC machines or 960 for PAL machines. 

'wait' = 0 for non-blocking mode, 1 for blocking mode (ie: wait for DMA
transfer of sound data to IOP to complete).

*** void SjPCM_Play();
Make the audio output audible.

*** void SjPCM_Pause();
Mute the audio output.

*** void SjPCM_Setvol(unsigned int volume);
Change the audio volume (0...0x3ff)

*** void SjPCM_Clearbuff();
Set the sound buffers to 0.

*** int SjPCM_Available();
Available space in the output buffer. Returns the number of
stereo 16bit samples that will fit into the buffer before
a buffer overrun.

*** int SjPCM_Buffered();
Number of stereo samples still available in the output buffer
before a buffer underrun.

*** int SjPCM_Quit();
Free SPU2 resources claimed by SjPCM, so they are available
for other libsd-based audio IRX's to use (such as Vzzrzzn's
modplayer).

Note on using unsynchronised mode
---------------------------------

SjPCM assumes that the sound chip plays 800/960 samples per
vertical blank period. However, this rate can change slightly 
over time. It is the users responsibility to avoid buffer 
overruns and buffer underruns.

*Example (NTSC):

This example keeps the buffered audio data one frame ahead
of the vertical sync, avoiding underrun and overrun.

while(1) {
  int buffered = SjPCM_Buffered();
  if (buffered<1*800) SjPCM_Enqueue(...); // avoid underrun
  if (buffered<2*800) SjPCM_Enqueue(...); // regular buffer fill
  vsync();  
}

LEGAL
-----

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
