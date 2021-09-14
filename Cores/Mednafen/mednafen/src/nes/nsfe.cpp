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

#include "nes.h"
#include "x6502.h"
#include "sound.h"
#include "cart.h"
#include "nsf.h"
#include "nsfe.h"

namespace MDFN_IEN_NES
{

static void GetString(Stream* fp, uint32* chunk_size, std::string* str)
{
 str->clear();

 while(*chunk_size)
 {
  uint8 c;

  fp->read(&c, 1);

  (*chunk_size)--;

  if(!c)
   break;

  if(c < 0x20)
   c = 0x20;

  str->push_back(c);
 }
}

void LoadNSFE(NSFINFO *nfe, Stream* fp, int info_only)
{
 uint8 magic[4];

 fp->read(magic, 4);

 for(;;)
 {
  uint8 subhead[8];
  uint32 chunk_size;

  fp->read(subhead, 8);
  chunk_size =  MDFN_de32lsb(&subhead[0]);

  if(chunk_size > 64 * 1024 * 1024)
   throw MDFN_Error(0, _("NSFE chunk \"%.4s\" size(%u) is invalid."), (char*)&subhead[4], chunk_size);

  //printf("\nChunk: %.4s %d\n", &subhead[4], chunk_size);
  if(!memcmp(&subhead[4], "INFO", 4))
  {
   if(nfe->TotalSongs)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" is duplicate."), (char*)&subhead[4]);

   if(chunk_size < 8)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" size(%u) is invalid."), (char*)&subhead[4], chunk_size);

   nfe->LoadAddr = fp->get_LE<uint16>();
   nfe->InitAddr = fp->get_LE<uint16>();
   nfe->PlayAddr = fp->get_LE<uint16>();
   nfe->VideoSystem = fp->get_u8();
   nfe->SoundChip = fp->get_u8();

   chunk_size -= 8;

   if(chunk_size)
   {
    nfe->TotalSongs = fp->get_u8();
    if(!nfe->TotalSongs)
     nfe->TotalSongs = 256;
    chunk_size--;
   }
   else
    nfe->TotalSongs = 1;

   if(chunk_size)
   {
    nfe->StartingSong = fp->get_u8();
    chunk_size--;
   }
   else
    nfe->StartingSong = 0;

   nfe->SongNames.resize(nfe->TotalSongs);
  }
  else if(!memcmp(&subhead[4], "DATA", 4))
  {
   if(!nfe->TotalSongs)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" is out of order."), (char*)&subhead[4]);

   if(nfe->NSFDATA)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" is duplicate."), (char*)&subhead[4]);

   nfe->NSFSize = chunk_size;
   nfe->NSFMaxBank = round_up_pow2((nfe->NSFSize + (nfe->LoadAddr & 0xfff) + 0xfff) / 0x1000) - 1;
   if(!info_only)
   {
    nfe->NSFDATA = new uint8[(nfe->NSFMaxBank + 1) * 4096];
    memset(nfe->NSFDATA, 0, (nfe->NSFMaxBank + 1) * 4096);
    fp->read(nfe->NSFDATA + (nfe->LoadAddr & 0xfff), nfe->NSFSize);
    chunk_size -= nfe->NSFSize;
   }
  }
  else if(!memcmp(&subhead[4], "BANK", 4))
  {
   uint64 tr = std::min<uint64>(chunk_size, 8);

   fp->read(nfe->BankSwitch, tr);
   chunk_size -= 8;
  }
  else if(!memcmp(&subhead[4], "NEND", 4))
  {
   if(chunk_size != 0)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" size(%u) is invalid."), (char*)&subhead[4], chunk_size);
   else if(!nfe->NSFDATA)
    throw MDFN_Error(0, _("NEND reached without preceding DATA chunk."));
   else
    return;
  }
  else if(!memcmp(&subhead[4], "tlbl", 4))
  {
   if(!nfe->TotalSongs)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" is out of order."), (char*)&subhead[4]);

   for(unsigned ws = 0; ws < nfe->TotalSongs && chunk_size > 0; ws++)
   {
    GetString(fp, &chunk_size, &nfe->SongNames[ws]);
   }
  }
  else if(!memcmp(&subhead[4], "auth", 4))
  {
   for(unsigned which = 0; which < 4 && chunk_size > 0; which++)
   {
    switch(which)
    {
     case 0: GetString(fp, &chunk_size, &nfe->GameName);  break;
     case 1: GetString(fp, &chunk_size, &nfe->Artist);	  break;
     case 2: GetString(fp, &chunk_size, &nfe->Copyright); break;
     case 3: GetString(fp, &chunk_size, &nfe->Ripper); 	  break;
    }
   }
  }
  else if(subhead[4] >= 'A' && subhead[4] <= 'Z') /* Unrecognized mandatory chunk */
  {
   throw MDFN_Error(0, _("NSFE unrecognized mandatory chunk \"%.4s\"."), (char*)&subhead[4]);
  }
  else
  {
   //printf("Skip chunk: %.4s\n", (char*)&subhead[4]);
  }

  if(chunk_size)
  {
   fp->seek(chunk_size, SEEK_CUR);
   chunk_size = 0;
  }
 }
}

}
