/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* state_rewind.cpp:
**  Copyright (C) 2014-2018 Mednafen Team
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

#include "mednafen.h"
#include "state.h"
#include "movie.h"
#include "state_rewind.h"

#include <mednafen/MemoryStream.h>
#include <mednafen/quicklz/quicklz.h>

#if QLZ_COMPRESSION_LEVEL != 0
 #error "State rewinding code untested with QLZ_COMPRESSION_LEVEL != 0"
#endif

struct StateMemPacket
{
	std::unique_ptr<MemoryStream> data;
	uint32 uncompressed_len = 0;
};

static bool Active = false;
static bool Enabled = false;
static std::vector<StateMemPacket> bcs;
static size_t bcs_pos;

static uint32 SRW_AllocHint;
static std::unique_ptr<MemoryStream> ss_prev;

static union
{
 char compress[QLZ_SCRATCH_COMPRESS];
 char decompress[QLZ_SCRATCH_DECOMPRESS];
} qlz_scratch;

static void Cleanup(void)
{
 bcs.clear();
 ss_prev.reset(nullptr);
}

void MDFNSRW_Begin(void) noexcept
{
 if(!Enabled)
  return;

 if(!Active)
 {
  try
  {
   bcs.resize(std::max<size_t>(3, MDFN_GetSettingUI("srwframes")) - 1);
   bcs_pos = 0;
   memset(&qlz_scratch, 0, sizeof(qlz_scratch));

   SRW_AllocHint = 8192;

   Active = true;
  }
  catch(std::exception &e)
  {
   Cleanup();

   MDFN_Notify(MDFN_NOTICE_ERROR, _("State rewinding error: %s"), e.what());
  }
 }
}

void MDFNSRW_End(void) noexcept
{
 if(Active)
 {
  Cleanup();

  Active = false;
 }
}

bool MDFNSRW_IsRunning(void) noexcept
{
 return Active;
}

static INLINE void DoXORFilter(MemoryStream* prev, MemoryStream* cur) noexcept
{
 MDFN_FastMemXOR(prev->map(), cur->map(), std::min(prev->size(), cur->size()));
}


static INLINE std::unique_ptr<MemoryStream> DoCompress(MemoryStream* data)
{
 const uint32 uncompressed_len = data->size();
 const uint32 max_compressed_len = (uncompressed_len + 400);
 std::unique_ptr<MemoryStream> tmp_buf(new MemoryStream(max_compressed_len, -1));
 uint32 dst_len;

 dst_len = qlz_compress(data->map(), (char*)tmp_buf->map(), uncompressed_len, qlz_scratch.compress);
 tmp_buf->truncate(dst_len);
 tmp_buf->shrink_to_fit();

 return tmp_buf;
}

//
//
//
static bool DoRewind(void)
{
 //
 // No save states available.
 //
 if(!ss_prev)
  return false;

 //
 // Load most recent state.
 //
 ss_prev->rewind();
 MDFNSS_LoadSM(ss_prev.get(), true);

 //
 // If a compressed state exists, decompress it.
 //
 StateMemPacket* smp = &bcs[(bcs_pos + bcs.size() - 1) % bcs.size()];

 if(smp->data)
 {
  std::unique_ptr<MemoryStream> tmp(new MemoryStream(smp->uncompressed_len, -1));
  qlz_decompress((char*)smp->data->map(), tmp->map(), qlz_scratch.decompress);
  smp->data.reset(nullptr);
  bcs_pos = (bcs_pos + bcs.size() - 1) % bcs.size();
  //
  DoXORFilter(tmp.get(), ss_prev.get());
  //
  ss_prev = std::move(tmp);
 }

 return true;
}

//
//
//
static void DoRecord(void)
{
 //
 // Save current state
 //
 std::unique_ptr<MemoryStream> ss_cur(new MemoryStream(SRW_AllocHint));

 MDFNSS_SaveSM(ss_cur.get(), true);

 SRW_AllocHint = std::max<uint32>(SRW_AllocHint, ss_cur->size());

 //
 // Compress previous state if it exists.
 //
 if(ss_prev)
 {
  DoXORFilter(ss_prev.get(), ss_cur.get());

  //printf("Compress: %zu\n", ss_prev->size());

  bcs[bcs_pos].data = DoCompress(ss_prev.get());
  bcs[bcs_pos].uncompressed_len = ss_prev->size();
  bcs_pos = (bcs_pos + 1) % bcs.size();
 }

 //
 // Make current state previous for next time.
 //
 ss_prev = std::move(ss_cur);
}

bool MDFNSRW_Frame(bool rewind) noexcept
{
 if(!Active)
  return false;

 try
 {
  if(rewind)
  {
   return DoRewind();
  }
  else
  {
   DoRecord();
   return false;
  }
 }
 catch(std::exception &e)
 {
  MDFNSRW_End();

  MDFN_Notify(MDFN_NOTICE_ERROR, _("State rewinding error: %s"), e.what());

  return false;
 }
}

bool MDFNI_EnableStateRewind(bool enable)
{
 Enabled = enable;

 if(Enabled)
  MDFNSRW_Begin();
 else
  MDFNSRW_End();

 return Active;
}

