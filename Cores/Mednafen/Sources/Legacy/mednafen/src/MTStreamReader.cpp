/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* MTStreamReader.cpp:
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

#include <mednafen/mednafen.h>
#include "MTStreamReader.h"

#undef NDEBUG
#include <assert.h>

namespace Mednafen
{

void MTStreamReader::cleanup(void)
{
 if(thread)
 {
  MThreading::Sem_Wait(ack_sem);
  pending_command = Command_Exit;
  MThreading::Sem_Post(command_sem);
  //
  MThreading::Thread_Wait(thread, nullptr);
  thread = nullptr;
 }

 if(command_sem)
 {
  MThreading::Sem_Destroy(command_sem);
  command_sem = nullptr;
 }

 if(ack_sem)
 {
  MThreading::Sem_Destroy(ack_sem);
  ack_sem = nullptr;
 }
}

int MTStreamReader::read_thread_entry_(void* data)
{
 return ((MTStreamReader*)data)->read_thread_entry();
}

MTStreamReader::MTStreamReader(const uint64 affinity)
{
 try
 {
  command_sem = MThreading::Sem_Create();
  ack_sem = MThreading::Sem_Create();
  thread = MThreading::Thread_Create(read_thread_entry_, this);
  if(affinity)
   MThreading::Thread_SetAffinity(thread, affinity);

  pending_command = Command_NOP;
  MThreading::Sem_Post(command_sem);
 }
 catch(...)
 {
  cleanup();
  throw;
 }
}

MTStreamReader::~MTStreamReader()
{
 cleanup();
}

void MTStreamReader::zero_into_buffer(uint32 count)
{
 while(count)
 {
  size_t sub_count = std::min<uint64>(Buffer_Size - (write_pos & Buffer_Size_Mask), count);

  memset(&buffer[write_pos & Buffer_Size_Mask], 0, sub_count);
  //printf("Zero: %04zx %zu\n", write_pos & Buffer_Size_Mask, sub_count);
  write_pos += sub_count;
  count -= sub_count;
 }
 //
 memcpy(&buffer[Buffer_Size], &buffer[0], Overbuffer_Count);
}

void MTStreamReader::read_into_buffer(uint32 count)
{
 assert(count <= Buffer_Size);
 //
 uint8* basep = nullptr;

 //printf("ruh read_into_buffer %u\n", count);

 while(count)
 {
  if(active->pos == active->size)
  {
   //printf("Ruh roh: %u\n", count);
   //puts("Ruh roh");
   zero_into_buffer(count);
   count = 0;
   break;
  }
  //
  //const size_t prev_pos = active->pos;
  //const size_t prev_write_pos = write_pos;
  size_t sub_count = std::min<uint64>(Buffer_Size - (write_pos & Buffer_Size_Mask), std::min<uint64>(count, active->size - active->pos));
  uint8* const dp = &buffer[write_pos & Buffer_Size_Mask];
  if(basep)
  {
   //assert(active->pos == active->loop_pos); 
   memmove(dp, basep + (active->pos - active->loop_pos), sub_count);
  }
  else
   active->stream->read(dp, sub_count);
  //printf("Read: %04zx %zu %08x\n", write_pos & Buffer_Size_Mask, sub_count, (uint32)active->pos);
  write_pos += sub_count;
  active->pos += sub_count;
  count -= sub_count;

  if(active->pos == active->size)
  {
   //printf("ruh %llu %llu %llu %u\n", (unsigned long long)active->pos, (unsigned long long)active->size, (unsigned long long)active->loop_pos, count);
   //
   active->pos = active->loop_pos;

   if(!basep)
   {
    if(active->loop_pos < active->size && (active->size - active->loop_pos) == sub_count)
     basep = &buffer[(write_pos - sub_count) & Buffer_Size_Mask];
    else
     active->stream->seek(active->pos);
   }
  }
 }

 if(basep)
  active->stream->seek(active->pos);
 //
 memcpy(&buffer[Buffer_Size], &buffer[0], Overbuffer_Count);
}

int MTStreamReader::read_thread_entry(void)
{
 bool running = true;

 try
 {
  while(running)
  {
   MThreading::Sem_Wait(command_sem);
   //
   const uint32 command = pending_command;

   if(command == Command_Exit)
   {
    running = false;
   }
   else if(command == Command_NOP)
   {

   }
   else if(command == Command_SetActive)
   {
    const uint32 w = pending_which;
    const uint64 skip = pending_skip;
    const uint32 pzb = pending_pzb;
    uint64 pos;

    active = &streams[w];

    if(skip >= active->size)
    {
     if(active->loop_pos == active->size)
      pos = active->size;
     else
      pos = active->loop_pos + ((skip - active->loop_pos) % (active->size - active->loop_pos));
    }
    else
     pos = skip;

    active->pos = pos;
    active->stream->seek(pos);
    //
    zero_into_buffer(pzb);
    read_into_buffer(Buffer_Size - pzb);
   }
   else if(command == Command_BufferNext)
   {
    read_into_buffer(Chunk_Size);
   }
   //
   MThreading::Sem_Post(ack_sem);
  }
 }
 catch(std::exception& e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("MTStreamReader() error: %s"), e.what());

  while(running)
  {
   MThreading::Sem_Wait(command_sem);
   //
   if(pending_command == Command_Exit)
    running = false;
   //
   MThreading::Sem_Post(ack_sem); 
  }
 }

 return 0;
}

void MTStreamReader::add_stream(StreamInfo si)
{
 assert(si.loop_pos <= si.size);
 streams.push_back(std::move(si));
}

}
