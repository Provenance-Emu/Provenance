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
#include <math.h>
#include "x6502.h"
#include "sound.h"
#include "cart.h"
#include "nsf.h"
#include "nsfe.h"

void LoadNSFE(NSFINFO *nfe, const uint8 *buf, int32 size, int info_only)
{
 const uint8 *nbuf = 0;

 size -= 4;
 buf += 4;

 while(size)
 {
  uint32 chunk_size;
  uint8 tb[4];

  if(size < 4)
   throw MDFN_Error(0, _("Unexpected EOF while reading NSFE."));

  chunk_size = MDFN_de32lsb(buf);

  size -= 4;
  buf += 4;
  if(size < 4)
   throw MDFN_Error(0, _("Unexpected EOF while reading NSFE."));

  memcpy(tb, buf, 4);

  buf += 4;
  size -= 4;

  if((int32)chunk_size < 0 || (int32)chunk_size > size)
   throw MDFN_Error(0, _("NSFE chunk \"%.4s\" size(%u) is invalid."), (char*)&tb[0], chunk_size);

  //printf("\nChunk: %.4s %d\n", tb, chunk_size);
  if(!memcmp(tb, "INFO", 4))
  {
   if(chunk_size < 8)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" size(%u) is invalid."), (char*)&tb[0], chunk_size);

   nfe->LoadAddr = MDFN_de16lsb(buf);
   buf+=2; size-=2;

   nfe->InitAddr = MDFN_de16lsb(buf);
   buf+=2; size-=2;

   nfe->PlayAddr = MDFN_de16lsb(buf);
   buf+=2; size-=2;

   nfe->VideoSystem = *buf; buf++; size--;
   nfe->SoundChip = *buf; buf++; size--;

   chunk_size-=8;

   if(chunk_size) { nfe->TotalSongs = *buf; buf++; size--; chunk_size--; }
   else nfe->TotalSongs = 1;

   if(chunk_size) { nfe->StartingSong = *buf; buf++; size--; chunk_size--; }
   else nfe->StartingSong = 0;

   nfe->SongNames = (char **)malloc(sizeof(char *) * nfe->TotalSongs);
   memset(nfe->SongNames, 0, sizeof(char *) * nfe->TotalSongs);

   nfe->SongLengths = (int32 *)malloc(sizeof(int32) * nfe->TotalSongs);
   nfe->SongFades = (int32 *)malloc(sizeof(int32) * nfe->TotalSongs);
   {
    int x;
    for(x=0; x<nfe->TotalSongs; x++) {nfe->SongLengths[x] = -1; nfe->SongFades[x] = -1; }
   }
  }
  else if(!memcmp(tb, "DATA", 4))
  {
   nfe->NSFSize=chunk_size;
   nbuf = buf;
  }
  else if(!memcmp(tb, "BANK", 4))
  {
   memcpy(nfe->BankSwitch, buf, (chunk_size > 8) ? 8 : chunk_size);
  }
  else if(!memcmp(tb, "NEND", 4))
  {
   if(chunk_size != 0)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" size(%u) is invalid."), (char*)&tb[0], chunk_size);
   else if(!nbuf)
    throw MDFN_Error(0, _("NEND reached without preceding DATA chunk."));
   else
   {
    nfe->NSFMaxBank = ((nfe->NSFSize+(nfe->LoadAddr&0xfff)+4095)/4096);
    nfe->NSFMaxBank = round_up_pow2(nfe->NSFMaxBank);

    if(!info_only)
    {
     if(!(nfe->NSFDATA=(uint8 *)malloc(nfe->NSFMaxBank*4096)))
      throw MDFN_Error(errno, _("Error allocating memory."));

     memset(nfe->NSFDATA,0x00,nfe->NSFMaxBank*4096);
     memcpy(nfe->NSFDATA+(nfe->LoadAddr&0xfff),nbuf,nfe->NSFSize);

     nfe->NSFRawData = nfe->NSFDATA + (nfe->LoadAddr & 0xFFF);
     nfe->NSFRawDataSize = nfe->NSFSize;
    }
    nfe->NSFMaxBank--;
    return;
   }
  }
  else if(!memcmp(tb, "tlbl", 4))
  {
   int songcount = 0;

   if(!nfe->TotalSongs)
    throw MDFN_Error(0, _("NSFE chunk \"%.4s\" is out of order."), (char*)&tb[0]);	// Out of order chunk.

   while(chunk_size > 0)
   {
    int slen = strlen((char *)buf);

    nfe->SongNames[songcount++] = (char*)MDFN_RemoveControlChars(strdup((char *)buf));

    buf += slen + 1;
    chunk_size -= slen + 1;
   }
  }
  else if(!memcmp(tb, "time", 4))
  {
   int count = chunk_size / 4;
   int ws = 0;
   chunk_size -= count * 4;

   while(count--)
   {
    nfe->SongLengths[ws] = (int32)MDFN_de32lsb(buf);
    //printf("%d\n",fe->SongLengths[ws]/1000);
    buf += 4;
    ws++;
   }
  }
  else if(!memcmp(tb, "fade", 4))
  {
   int count = chunk_size / 4;
   int ws = 0;
   chunk_size -= count * 4;

   while(count--)
   {
    nfe->SongFades[ws] = (int32)MDFN_de32lsb(buf);
    //printf("%d\n",fe->SongFades[ws]);
    buf += 4;
    ws++;
   }
  }
  else if(!memcmp(tb, "auth", 4))
  {
   int which = 0;
   while(chunk_size > 0)
   {
    int slen = strlen((char *)buf);

    if(!which) nfe->GameName = (char*)MDFN_RemoveControlChars(strdup((char *)buf));
    else if(which == 1) nfe->Artist = (char*)MDFN_RemoveControlChars(strdup((char *)buf));
    else if(which == 2) nfe->Copyright = (char*)MDFN_RemoveControlChars(strdup((char *)buf));
    else if(which == 3) nfe->Ripper = (char*)MDFN_RemoveControlChars(strdup((char *)buf));

    which++;
    buf += slen +1;
    chunk_size -= slen + 1;
   }
  }
  else if(tb[0] >= 'A' && tb[0] <= 'Z') /* Unrecognized mandatory chunk */
  {
   throw MDFN_Error(0, _("NSFE unrecognized mandatory chunk \"%.4s\"."), (char*)&tb[0]);
  }

  buf += chunk_size;
  size -= chunk_size;
 }
}
