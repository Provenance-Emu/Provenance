/***************************************************************************************
 *  Genesis Plus
 *  CD drive processor & CD-DA fader
 *
 *  Copyright (C) 2012-2013  Eke-Eke (Genesis Plus GX)
 *
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************************/
#ifndef _HW_CDD_
#define _HW_CDD_

#ifdef USE_LIBTREMOR
#include "tremor/ivorbisfile.h"
#endif

/* CDD status */
#define NO_DISC  0x00
#define CD_PLAY  0x01
#define CD_SEEK  0x02
#define CD_SCAN  0x03
#define CD_READY 0x04
#define CD_OPEN  0x05 /* similar to 0x0E ? */
#define CD_STOP  0x09
#define CD_END   0x0C

/* CD blocks scanning speed */
#define CD_SCAN_SPEED 30

#define CD_MAX_TRACKS 100

/* CD track */
typedef struct
{
  void *fd;
#ifdef USE_LIBTREMOR
  OggVorbis_File vf;
#endif
  int offset;
  int start;
  int end;
} track_t; 

/* CD TOC */
typedef struct
{
  int end;
  int last;
  track_t tracks[CD_MAX_TRACKS];
} toc_t; 

/* CDD hardware */
typedef struct
{
  uint32 cycles;
  uint32 latency;
  int loaded;
  int index;
  int lba;
  int scanOffset;
  int volume;
  uint8 status;
  uint16 sectorSize;
  toc_t toc;
  int16 audio[2];
} cdd_t; 

extern cdd_t cdd;

#endif
