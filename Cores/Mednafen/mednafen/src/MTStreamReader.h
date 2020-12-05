/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* MTStreamReader.h:
**  Copyright (C) 2019 Mednafen Team
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

#include <mednafen/MThreading.h>
#include <mednafen/Stream.h>

#ifndef __MDFN_MTSTREAMREADER_H
#define __MDFN_MTSTREAMREADER_H

namespace Mednafen
{
//
// Prebuffer the entire buffer, then buffer in 1/4 size chunks(1/2 size chunks would create a race condition in get_buffer()).
//
class MTStreamReader
{
 public:

 MTStreamReader(const uint64 affinity);
 ~MTStreamReader();

 enum { Overbuffer_Count = 256 };
 enum : size_t { Buffer_Size = 0x10000 }; // 0x100
 enum : size_t { Buffer_Size_Mask = Buffer_Size - 1 };
 enum : size_t { Chunk_Size = Buffer_Size / 4 };

 INLINE uint8* get_buffer(size_t count)
 {
  //assert(count <= Overbuffer_Count);
  if(MDFN_UNLIKELY(need_sync))
  {
   MThreading::Sem_Wait(ack_sem);
   //
   pending_command = Command_NOP;
   //
   MThreading::Sem_Post(command_sem);
   //
   need_sync = false;
  }

  return &buffer[read_pos & Buffer_Size_Mask];
 }

 INLINE void advance(size_t count)
 {
  const size_t prev_pos = read_pos;

  read_pos += count;

  if((prev_pos ^ read_pos) & Chunk_Size)
  {
   // Wait for command ack, then send read next buffer command to read thread
   MThreading::Sem_Wait(ack_sem);
   pending_command = Command_BufferNext;
   MThreading::Sem_Post(command_sem);
  }
 }

 struct StreamInfo
 {
  std::unique_ptr<Stream> stream;
  uint64 pos;	// [0, size)
  //
  uint64 size;
  uint64 loop_pos; // [0, size)
 };

 void add_stream(StreamInfo si);
 INLINE void set_active_stream(uint32 w, uint64 skip = 0, uint32 pzb = 0)
 {
  assert(pzb <= sizeof(buffer));
  MThreading::Sem_Wait(ack_sem);
  //
  pending_command = Command_SetActive;
  pending_which = w;
  pending_skip = skip;
  pending_pzb = pzb;

  read_pos = 0;
  write_pos = 0;
  //
  MThreading::Sem_Post(command_sem);
  //
  need_sync = true;
 }

 private:

 static int read_thread_entry_(void* data);
 int read_thread_entry(void);

 void cleanup(void);
 void zero_into_buffer(uint32 count);
 void read_into_buffer(uint32 count);

 enum
 {
  Command_SetActive = 0,
  Command_BufferNext,
  Command_NOP,
  Command_Exit
 };

 MThreading::Thread* thread = nullptr;
 MThreading::Sem* command_sem = nullptr;
 MThreading::Sem* ack_sem = nullptr;
 uint32 pending_command = 0;
 uint32 pending_which = 0;
 uint64 pending_skip = 0;
 uint32 pending_pzb = 0;
 bool need_sync = false;

 std::vector<StreamInfo> streams;
 StreamInfo* active = nullptr;
 size_t write_pos = 0;
 //
 uint32 read_pos = 0;
 uint8 buffer[Buffer_Size + Overbuffer_Count];
};

}
#endif
