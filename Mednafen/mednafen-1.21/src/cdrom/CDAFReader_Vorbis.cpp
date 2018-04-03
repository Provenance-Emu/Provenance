/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAFReader_Vorbis.cpp:
**  Copyright (C) 2010-2016 Mednafen Team
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

#include <mednafen/mednafen.h>
#include "CDAFReader.h"
#include "CDAFReader_Vorbis.h"

#ifdef HAVE_EXTERNAL_TREMOR
 #include <tremor/ivorbisfile.h>
#else
 #include <mednafen/tremor/ivorbisfile.h>
#endif

class CDAFReader_Vorbis final : public CDAFReader
{
 public:
 CDAFReader_Vorbis(Stream *fp);
 ~CDAFReader_Vorbis();

 uint64 Read_(int16 *buffer, uint64 frames) override;
 bool Seek_(uint64 frame_offset) override;
 uint64 FrameCount(void) override;

 private:
 OggVorbis_File ovfile;
 Stream *fw;
};


static size_t iov_read_func(void *ptr, size_t size, size_t nmemb, void *user_data)
{
 Stream *fw = (Stream*)user_data;

 if(!size)
  return(0);

 try
 {
  return fw->read(ptr, size * nmemb, false) / size;
 }
 catch(...)
 {
  return(0);
 }
}

static int iov_seek_func(void *user_data, ogg_int64_t offset, int whence)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  fw->seek(offset, whence);
  return(0);
 }
 catch(...)
 {
  return(-1);
 }
}

static int iov_close_func(void *user_data)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  fw->close();
  return(0);
 }
 catch(...)
 {
  return EOF;
 }
}

static long iov_tell_func(void *user_data)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  return fw->tell();
 }
 catch(...)
 {
  return(-1);
 }
}

CDAFReader_Vorbis::CDAFReader_Vorbis(Stream *fp) : fw(fp)
{
 ov_callbacks cb;

 memset(&cb, 0, sizeof(cb));
 cb.read_func = iov_read_func;
 cb.seek_func = iov_seek_func;
 cb.close_func = iov_close_func;
 cb.tell_func = iov_tell_func;

 if(ov_open_callbacks(fp, &ovfile, NULL, 0, cb))
  throw(0);
}

CDAFReader_Vorbis::~CDAFReader_Vorbis()
{
 ov_clear(&ovfile);
}

uint64 CDAFReader_Vorbis::Read_(int16 *buffer, uint64 frames)
{
 uint8 *tw_buf = (uint8 *)buffer;
 int cursection = 0;
 long toread = frames * sizeof(int16) * 2;

 while(toread > 0)
 {
  long didread = ov_read(&ovfile, (char*)tw_buf, toread, &cursection);

  if(didread == 0)
   break;

  tw_buf = (uint8 *)tw_buf + didread;
  toread -= didread;
 }

 return(frames - toread / sizeof(int16) / 2);
}

bool CDAFReader_Vorbis::Seek_(uint64 frame_offset)
{
 ov_pcm_seek(&ovfile, frame_offset);
 return(true);
}

uint64 CDAFReader_Vorbis::FrameCount(void)
{
 return(ov_pcm_total(&ovfile, -1));
}

CDAFReader* CDAFR_Vorbis_Open(Stream* fp)
{
 return new CDAFReader_Vorbis(fp);
}
