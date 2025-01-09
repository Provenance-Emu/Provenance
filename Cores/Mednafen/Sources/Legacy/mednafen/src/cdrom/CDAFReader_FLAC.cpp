/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAFReader_FLAC.cpp:
**  Copyright (C) 2020 Mednafen Team
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
#include "CDAFReader_FLAC.h"

//#include <FLAC/all.h>

namespace Mednafen
{

class CDAFReader_FLAC final : public CDAFReader
{
 public:
 CDAFReader_FLAC(Stream *fp);
 ~CDAFReader_FLAC();

 uint64 Read_(int16 *buffer, uint64 frames) override;
 bool Seek_(uint64 frame_offset) override;
 uint64 FrameCount(void) override;

 FLAC__StreamDecoderReadStatus read_cb(FLAC__byte* data, size_t* count);
 FLAC__StreamDecoderSeekStatus seek_cb(FLAC__uint64 offset);
 FLAC__StreamDecoderTellStatus tell_cb(FLAC__uint64* offset);
 FLAC__StreamDecoderLengthStatus length_cb(FLAC__uint64* size);
 FLAC__bool eof_cb(void);
 FLAC__StreamDecoderWriteStatus write_cb(const FLAC__Frame* frame, const FLAC__int32* const* buf);
 void metadata_cb(const FLAC__StreamMetadata* meta);
 void error_cb(FLAC__StreamDecoderErrorStatus status);

 private:
 Stream *fw;
 bool eof;

 uint64 num_frames;
 FLAC__StreamDecoder* dec;

 uint32 decbuf_alloced;
 uint32 decbuf_size;
 uint32 decbuf_read_offs;
 std::unique_ptr<int16[]> decbuf;
};

INLINE FLAC__StreamDecoderReadStatus CDAFReader_FLAC::read_cb(FLAC__byte* data, size_t* count)
{
 if(!*count)
  return FLAC__STREAM_DECODER_READ_STATUS_ABORT;

 try
 {
  const size_t to_read = *count;
  size_t did_read = fw->read(data, to_read, false);

  *count = did_read;

  eof |= did_read < to_read;

  if(to_read && !did_read)
   return FLAC__STREAM_DECODER_READ_STATUS_END_OF_STREAM;

  return FLAC__STREAM_DECODER_READ_STATUS_CONTINUE;
 } 
 catch(...)
 {
  return FLAC__STREAM_DECODER_READ_STATUS_ABORT;
 }
}

INLINE FLAC__StreamDecoderSeekStatus CDAFReader_FLAC::seek_cb(FLAC__uint64 offset)
{
 try
 {
  fw->seek(offset, SEEK_SET);
  eof = false;

  return FLAC__STREAM_DECODER_SEEK_STATUS_OK;
 }
 catch(...)
 {
  return FLAC__STREAM_DECODER_SEEK_STATUS_ERROR;
 }
}

INLINE FLAC__StreamDecoderTellStatus CDAFReader_FLAC::tell_cb(FLAC__uint64* offset)
{
 try
 {
  *offset = fw->tell();

  return FLAC__STREAM_DECODER_TELL_STATUS_OK;
 }
 catch(...)
 {
  return FLAC__STREAM_DECODER_TELL_STATUS_ERROR;
 }
}

INLINE FLAC__StreamDecoderLengthStatus CDAFReader_FLAC::length_cb(FLAC__uint64* size)
{
 try
 {
  *size = fw->size();

  return FLAC__STREAM_DECODER_LENGTH_STATUS_OK;
 }
 catch(...)
 {
  return FLAC__STREAM_DECODER_LENGTH_STATUS_ERROR;
 }
}

INLINE FLAC__bool CDAFReader_FLAC::eof_cb(void)
{
 return eof;
}

INLINE FLAC__StreamDecoderWriteStatus CDAFReader_FLAC::write_cb(const FLAC__Frame* frame, const FLAC__int32*const* buf)
{
 try
 {
  const unsigned num_ch = frame->header.channels;
  const unsigned bits_per_sample = frame->header.bits_per_sample;
  const uint32 new_decbuf_size = frame->header.blocksize;

  //printf("blocksize=%u, channels=%u bits_per_sample=%u\n", frame->header.blocksize, frame->header.channels, frame->header.bits_per_sample);

  assert(num_ch);
  assert(decbuf_read_offs == decbuf_size);

  if(decbuf_alloced < new_decbuf_size)
  {
   decbuf.reset();
   decbuf_alloced = 0;
   //
   decbuf.reset(new int16[2 * new_decbuf_size]);
   decbuf_alloced = new_decbuf_size;
  }

  decbuf_read_offs = 0;
  decbuf_size = new_decbuf_size;

  for(uint32 i = 0; i < new_decbuf_size; i++)
  {
   int16 out_l, out_r;
   //printf("%08x\n", buf[0][i]);

   out_l = out_r = ((uint32)buf[0][i] << (32 - bits_per_sample)) >> 16;
   if(num_ch >= 2)
    out_r = ((uint32)buf[1][i] << (32 - bits_per_sample)) >> 16;

   decbuf[i * 2 + 0] = out_l;
   decbuf[i * 2 + 1] = out_r;
  }
 }
 catch(...)
 {
  return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
 }

 return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

INLINE void CDAFReader_FLAC::metadata_cb(const FLAC__StreamMetadata* meta)
{

}

INLINE void CDAFReader_FLAC::error_cb(FLAC__StreamDecoderErrorStatus status)
{

}


static FLAC__StreamDecoderReadStatus C_read_cb(const FLAC__StreamDecoder* dec, FLAC__byte* data, size_t* count, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->read_cb(data, count);
}

static FLAC__StreamDecoderSeekStatus C_seek_cb(const FLAC__StreamDecoder* dec, FLAC__uint64 offset, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->seek_cb(offset);
}

static FLAC__StreamDecoderTellStatus C_tell_cb(const FLAC__StreamDecoder* dec, FLAC__uint64* offset, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->tell_cb(offset);
}

static FLAC__StreamDecoderLengthStatus C_length_cb(const FLAC__StreamDecoder* dec, FLAC__uint64* size, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->length_cb(size);
}

static FLAC__bool C_eof_cb(const FLAC__StreamDecoder* dec, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->eof_cb();
}

static FLAC__StreamDecoderWriteStatus C_write_cb(const FLAC__StreamDecoder* dec, const FLAC__Frame* frame, const FLAC__int32* const* buf, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->write_cb(frame, buf);
}

static void C_metadata_cb(const FLAC__StreamDecoder* dec, const FLAC__StreamMetadata* meta, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->metadata_cb(meta);
}

static void C_error_cb(const FLAC__StreamDecoder* dec, FLAC__StreamDecoderErrorStatus status, void* pdata)
{
 return ((CDAFReader_FLAC*)pdata)->error_cb(status);
}

CDAFReader_FLAC::CDAFReader_FLAC(Stream *fp) : fw(fp), eof(false), num_frames(0), dec(nullptr), decbuf_alloced(0), decbuf_size(0), decbuf_read_offs(0)
{
 uint8 magic[0x4];
 //bool is_ogg = false;

 if(fp->read(magic, 0x4) != 0x4)
  throw 0;

 //is_ogg = !memcmp(magic, "OggS", 4);

 if(memcmp(magic, "fLaC", 4) /*&& !is_ogg*/)
  throw 0;
 
 fp->rewind();
 //
 //
 //
 try
 {
  if(!(dec = FLAC__stream_decoder_new()))
   throw MDFN_Error(0, _("Error creating FLAC stream decoder."));
  //
  FLAC__StreamDecoderInitStatus init_status;

  //if(is_ogg)
  // init_status = FLAC__stream_decoder_init_ogg_stream(dec, C_read_cb, C_seek_cb, C_tell_cb, C_length_cb, C_eof_cb, C_write_cb, C_metadata_cb, C_error_cb, this);
  //else
   init_status = FLAC__stream_decoder_init_stream(dec, C_read_cb, C_seek_cb, C_tell_cb, C_length_cb, C_eof_cb, C_write_cb, C_metadata_cb, C_error_cb, this);
  if(init_status != FLAC__STREAM_DECODER_INIT_STATUS_OK)
  {
   if(init_status == FLAC__STREAM_DECODER_INIT_STATUS_UNSUPPORTED_CONTAINER)
    throw 0;
   //
   throw MDFN_Error(0, _("Error initializing FLAC stream decoder: %s"), FLAC__StreamDecoderInitStatusString[init_status]);
  }

  if(!FLAC__stream_decoder_process_until_end_of_metadata(dec))
   throw MDFN_Error(0, _("Error reading/processing FLAC metadata."));

  //printf("%s\n", FLAC__StreamDecoderStateString[FLAC__stream_decoder_get_state(dec)]);

  if(!(num_frames = FLAC__stream_decoder_get_total_samples(dec)))
   throw MDFN_Error(0, _("FLAC total sample count is zero."));
 }
 catch(...)
 {
  if(dec)
   FLAC__stream_decoder_delete(dec);

  throw;
 }
}

CDAFReader_FLAC::~CDAFReader_FLAC()
{
 if(dec)
 {
  FLAC__stream_decoder_delete(dec);
  dec = nullptr;
 }
}

uint64 CDAFReader_FLAC::Read_(int16 *buffer, uint64 frames)
{
 uint64 ret = 0;

 while(frames)
 {
  if(decbuf_read_offs == decbuf_size)
  {
   if(!FLAC__stream_decoder_process_single(dec))
   {
    //printf("FLAC__stream_decoder_process_single failed; decstate=%s\n", FLAC__StreamDecoderStateString[FLAC__stream_decoder_get_state(dec)]);
    if(decbuf_read_offs == decbuf_size)
     break;
   }

   if(FLAC__stream_decoder_get_state(dec) == FLAC__STREAM_DECODER_END_OF_STREAM)
   {
    //printf("End of stream?\n");
    if(decbuf_read_offs == decbuf_size)
     break;
   }
  }
  //
  //
  //printf("%d %d\n", decbuf_size, decbuf_read_offs);
  uint32 frames_to_copy = std::min<uint64>(frames, decbuf_size - decbuf_read_offs);
  memcpy(buffer, decbuf.get() + decbuf_read_offs * 2, frames_to_copy * sizeof(int16) * 2);
  decbuf_read_offs += frames_to_copy;
  buffer += frames_to_copy * 2;
  ret += frames_to_copy;
  frames -= frames_to_copy;
 }

 return ret;
}

bool CDAFReader_FLAC::Seek_(uint64 frame_offset)
{
 decbuf_read_offs = 0;
 decbuf_size = 0;

 if(!FLAC__stream_decoder_seek_absolute(dec, frame_offset))
 {
  //printf("FLAC__stream_decoder_seek_absolute() failed; decstate=%s\n", FLAC__StreamDecoderStateString[FLAC__stream_decoder_get_state(dec)]);

  if(FLAC__stream_decoder_get_state(dec) == FLAC__STREAM_DECODER_SEEK_ERROR)
  {
   //printf("flac seek error\n");
   decbuf_read_offs = 0;
   decbuf_size = 0;

   FLAC__stream_decoder_reset(dec);
  }

  return false;
 }

 return true;
}

uint64 CDAFReader_FLAC::FrameCount(void)
{
 return num_frames;
}

CDAFReader* CDAFR_FLAC_Open(Stream* fp)
{
 return new CDAFReader_FLAC(fp);
}

}
