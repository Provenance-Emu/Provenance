/***************************************************************************************
 *  Genesis Plus
 *  CD drive processor & CD-DA fader
 *
 *  Copyright (C) 2012-2020  Eke-Eke (Genesis Plus GX)
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

#include "blip_buf.h"

#if defined(USE_LIBVORBIS)
#include <vorbis/vorbisfile.h>
#elif defined(USE_LIBTREMOR)
#include "tremor/ivorbisfile.h"
#endif

#if defined(USE_LIBCHDR)
#include "libchdr/src/chd.h"
#include "libchdr/src/cdrom.h"
#endif

#define cdd scd.cdd_hw

/* CDD status */
#define CD_STOP       0x00
#define CD_PLAY       0x01
#define CD_SEEK       0x02
#define CD_SCAN       0x03
#define CD_PAUSE      0x04
#define CD_OPEN       0x05
#define NO_VALID_CHK  0x06  /* unused */
#define NO_VALID_CMD  0x07  /* unused */
#define CD_ERROR      0x08  /* unused */
#define CD_TOC        0x09
#define CD_TRACK_MOVE 0x0A  /* unused */
#define NO_DISC       0x0B
#define CD_END        0x0C
#define CD_TRAY       0x0E  /* unused */
#define CD_TEST       0x0F  /* unusec */

/* CD-DA digital filter types */
#define CD_TYPE_DEFAULT       0x00
#define CD_TYPE_WONDERMEGA    0x01
#define CD_TYPE_WONDERMEGA_M2 0x02

/* CD track */
typedef struct
{
    FILE *fd;
#if defined(USE_LIBTREMOR) || defined(USE_LIBVORBIS)
  OggVorbis_File vf;
#endif
  int offset;
  int start;
  int end;
  int type;
} track_t; 

/* CD TOC */
typedef struct
{
  int end;
  int last;
  track_t tracks[100];
    FILE *sub;
} toc_t; 

#if defined(USE_LIBCHDR)
/* CHD file */
typedef struct
{
  chd_file *file;
  uint8 *hunk;
  int hunkbytes;
  int hunknum;
  int hunkofs;
} chd_t;
#endif

/* CDD hardware */
typedef struct
{
  uint32 cycles;
  uint32 latency;
  int type;
  int loaded;
  int index;
  int lba;
  int scanOffset;
  uint16 fader[2];
  uint8 status;
  uint16 sectorSize;
  toc_t toc;
#if defined(USE_LIBCHDR)
  chd_t chd;
#endif
  int16 audio[2];
} cdd_t; 

/* Function prototypes */
extern void cdd_init(int samplerate);
extern void cdd_reset(void);
extern int cdd_context_save(uint8 *state);
extern int cdd_context_load(uint8 *state);
extern int cdd_load(char *filename, char *header);
extern void cdd_unload(void);
extern void cdd_read_data(uint8 *dst, uint8 *subheader);
extern void cdd_read_audio(unsigned int samples);
extern void cdd_update(void);
extern void cdd_process(void);

#endif
