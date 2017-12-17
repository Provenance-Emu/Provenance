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

#include <mednafen/mednafen.h>
#include "CDAFReader.h"
#include "CDAFReader_MPC.h"

#if 0
 #include <mpc/mpcdec.h>
#else
 #include <mednafen/mpcdec/mpcdec.h>
#endif

class CDAFReader_MPC final : public CDAFReader
{
 public:
 CDAFReader_MPC(Stream *fp);
 ~CDAFReader_MPC();

 uint64 Read_(int16 *buffer, uint64 frames) override;
 bool Seek_(uint64 frame_offset) override;
 uint64 FrameCount(void) override;

 private:
 mpc_reader reader;
 mpc_demux *demux;
 mpc_streaminfo si;

 MPC_SAMPLE_FORMAT MPCBuffer[MPC_DECODER_BUFFER_LENGTH];

 uint32 MPCBufferIn;
 uint32 MPCBufferOffs;
 Stream *fw;
};


/// Reads size bytes of data into buffer at ptr.
static mpc_int32_t impc_read(mpc_reader *p_reader, void *ptr, mpc_int32_t size)
{
 Stream *fw = (Stream*)(p_reader->data);

 try
 {
  return fw->read(ptr, size, false);
 }
 catch(...)
 {
  return(MPC_STATUS_FAIL);
 }
}

/// Seeks to byte position offset.
static mpc_bool_t impc_seek(mpc_reader *p_reader, mpc_int32_t offset)
{
 Stream *fw = (Stream*)(p_reader->data);

 try
 {
  fw->seek(offset, SEEK_SET);
  return(MPC_TRUE);
 }
 catch(...)
 {
  return(MPC_FALSE);
 }
}

/// Returns the current byte offset in the stream.
static mpc_int32_t impc_tell(mpc_reader *p_reader)
{
 Stream *fw = (Stream*)(p_reader->data);

 try
 {
  return fw->tell();
 }
 catch(...)
 {
  return(MPC_STATUS_FAIL);
 }
}

/// Returns the total length of the source stream, in bytes.
static mpc_int32_t impc_get_size(mpc_reader *p_reader)
{
 Stream *fw = (Stream*)(p_reader->data);

 try
 {
  return fw->size();
 }
 catch(...)
 {
  return(MPC_STATUS_FAIL);
 }
}

/// True if the stream is a seekable stream.
static mpc_bool_t impc_canseek(mpc_reader *p_reader)
{
 return(MPC_TRUE);
}

CDAFReader_MPC::CDAFReader_MPC(Stream *fp) : fw(fp)
{
	demux = NULL;
	memset(&si, 0, sizeof(si));
	memset(MPCBuffer, 0, sizeof(MPCBuffer));
	MPCBufferOffs = 0;
	MPCBufferIn = 0;

	memset(&reader, 0, sizeof(reader));
	reader.read = impc_read;
	reader.seek = impc_seek;
	reader.tell = impc_tell;
	reader.get_size = impc_get_size;
	reader.canseek = impc_canseek;
	reader.data = (void*)fp;

	if(!(demux = mpc_demux_init(&reader)))
	{
	 throw(0);
	}
	mpc_demux_get_info(demux, &si);

	if(si.channels != 2)
	{
         mpc_demux_exit(demux);
         demux = NULL;
	 throw MDFN_Error(0, _("MusePack stream has wrong number of channels(%u); the correct number is 2."), si.channels);
	}

	if(si.sample_freq != 44100)
	{
         mpc_demux_exit(demux);
         demux = NULL;
	 throw MDFN_Error(0, _("MusePack stream has wrong samplerate(%u Hz); the correct samplerate is 44100 Hz."), si.sample_freq);
	}
}

CDAFReader_MPC::~CDAFReader_MPC()
{
 if(demux)
 {
  mpc_demux_exit(demux);
  demux = NULL;
 }
}

uint64 CDAFReader_MPC::Read_(int16 *buffer, uint64 frames)
{
  mpc_status err;
  int16 *cowbuf = (int16 *)buffer;
  int32 toread = frames * 2;

  while(toread > 0)
  {
   int32 tmplen;

   if(!MPCBufferIn)
   {
    mpc_frame_info fi;
    memset(&fi, 0, sizeof(fi));

    fi.buffer = MPCBuffer;
    if((err = mpc_demux_decode(demux, &fi)) < 0 || fi.bits == -1)
     return(frames - toread / 2);

    MPCBufferIn = fi.samples * 2;
    MPCBufferOffs = 0;
   }

   tmplen = MPCBufferIn;

   if(tmplen >= toread)
    tmplen = toread;

   for(int x = 0; x < tmplen; x++)
   {
#ifdef MPC_FIXED_POINT
    int32 samp = MPCBuffer[MPCBufferOffs + x] >> MPC_FIXED_POINT_FRACTPART;
#else
    #warning Floating-point MPC decoding path not tested.
    int32 samp = (int32)(MPCBuffer[MPCBufferOffs + x] * 32767);
#endif
    if(samp < -32768)
     samp = -32768;

    if(samp > 32767)
     samp = 32767;

    *cowbuf = (int16)samp;
    cowbuf++;
   }
      
   MPCBufferOffs += tmplen;
   toread -= tmplen;
   MPCBufferIn -= tmplen;
  }

  return(frames - toread / 2);
}

bool CDAFReader_MPC::Seek_(uint64 frame_offset)
{
 MPCBufferOffs = 0;
 MPCBufferIn = 0;

 if(mpc_demux_seek_sample(demux, frame_offset) < 0)
  return(false);

 return(true);
}

uint64 CDAFReader_MPC::FrameCount(void)
{
 return(mpc_streaminfo_get_length_samples(&si));
}


CDAFReader* CDAFR_MPC_Open(Stream* fp)
{
 return new CDAFReader_MPC(fp);
}
