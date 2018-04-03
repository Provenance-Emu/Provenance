/* Mednafen - NES/Famicom Emulator
 * 
 * Copyright notice for this file:
 *  Copyright (C) 2003 Xodnizel
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

static void FastRefreshLine(int firsttile, uint8 *target)
{
	if(scanline == -1) return;

        uint32 smorkus=RefreshAddr;

        #define RefreshAddr smorkus
        uint32 vofs;
        int X1;
	int XOC;

        register uint8 *P;
        static int norecurse=0; /*  Prevent recursion:
                                    PPU_hook() functions can call
                                    mirroring/chr bank switching functions,
                                    which call MDFNPPU_LineUpdate, which call this
                                    function. */
        if(norecurse) return;

	target += firsttile << 3;
	P = target;

        vofs=((PPU[0]&0x10)<<8) | ((RefreshAddr>>12)&7);
        
        memset(emphlinebuf + (firsttile << 3), PPU[1] >> 5, (32 - firsttile) << 3);

        if(!ScreenON && !SpriteON)
        {
         memset(target,PALRAM[poopoo()],(32 - firsttile)<<3);
         return;
        }

        if(!RCBGOn)
	{
	 memset(target, PALRAM[0] | 0x40, (32 - firsttile)<<3);
	 return;
	}
	/* Priority bits, needed for sprite emulation. */
        PALRAMCache[0x0]=PALRAMCache[0x4]=PALRAMCache[0x8]=PALRAMCache[0xC]=PALRAM[0] | 64;

        /* This high-level graphics MMC5 emulation code was written
           for MMC5 carts in "CL" mode.  It's probably not totally
           correct for carts in "SL" mode.
        */      

	XOC = 16 - XOffset;

	#define PPUT_MMC5
        if(MMC5Hack && geniestage!=1)
        {
         if(MMC5HackCHRMode==0 && (MMC5HackSPMode&0x80))
         {
          for(X1=firsttile;X1<32;X1++)
          {
           if((tochange<=0 && MMC5HackSPMode&0x40) || (tochange>0 && !(MMC5HackSPMode&0x40)))
           {
            #define PPUT_MMC5SP
            #include "fast-pputile.h"
 	    #undef PPUT_MMC5SP
	   }
	   else
	   {
	    #include "fast-pputile.h"	    
	   }
	   tochange--;
	   xs++;
	  }
	 }
         else if(MMC5HackCHRMode==1 && (MMC5HackSPMode&0x80))
	 {
          #define PPUT_MMC5SP
	  #define PPUT_MMC5CHR1
          for(X1=firsttile;X1<32;X1++)
          {
           #include "fast-pputile.h"
          }
	  #undef PPUT_MMC5CHR1
          #undef PPUT_MMC5SP
	 }
         else if(MMC5HackCHRMode==1)
	 {
          #define PPUT_MMC5CHR1
          for(X1=firsttile;X1<32;X1++)
          {
           #include "fast-pputile.h"
          }
          #undef PPUT_MMC5CHR1
	 }
         else
	 {
	  for(X1=firsttile;X1<32;X1++)
	  {
	   #include "fast-pputile.h"
	  }
	 }
	}
	#undef PPUT_MMC5
	else if(PPU_hook)
	{
	 norecurse=1;
	 #define PPUT_HOOK
         for(X1=firsttile;X1<32;X1++)
         {
          #include "fast-pputile.h"
         }
	 #undef PPUT_HOOK
	 norecurse=0;
	}
	else
	{
         for(X1=firsttile;X1<32;X1++)
         {
	  #include "fast-pputile.h"
         }
	}

        #undef vofs
        #undef RefreshAddr

        RefreshAddr=smorkus;
        if(!firsttile && !(PPU[1]&2)) 
	 memset(target, PALRAM[0] | 0x40, 8);
}

static void FastLineEffects(int firsttile, uint8 *target)
{
 if(scanline == -1) return;

 if(ScreenON || SpriteON)
 {
  if(PPU[1]&0x01)
  {
   for(int x = 63; x >= 0; x--)
   {
    uint8* p = &target[x << 2];

    MDFN_ennsb<uint32, true>(p, MDFN_densb<uint32, true>(p) & 0x30303030);
   }
  }
 }
}

static void FastCopySprites(int firsttile, uint8 *target, int skip)
{
      uint8 n=((PPU[1]&4)^4)<<1;
      uint8 *P=target;

      if(scanline == -1) return;

      if(sphitx != 0x100 && scanline >= 0)
      {
       int meep, maxmeep, firstmeep;
       
       firstmeep = sphitx;
       maxmeep = sphitx + 8;
   
       if(firstmeep < (firsttile << 3)) firstmeep = firsttile << 3;
       if(maxmeep > 255) maxmeep = 255;	// Don't go over 256 pixels(the screen isn't that wide!), and don't check on the 255th column(NES PPU bug).

       for(meep = firstmeep; meep < maxmeep; meep++)
       {
        if((sphitdata & (0x80 >> (meep - sphitx)))&& !(target[meep]&64))
        {
         //printf("Hit: %d\n",scanline);
         PPU_status |= 0x40;
        }
       }
      }

      if(rendis & 1)
       MDFN_FastArraySet(target + firsttile * 8, 0x40 | 0x3C, (256 - firsttile * 8));

      if(!RCSPROn || skip) return;

      if(n < (firsttile << 3)) n = firsttile << 3;

#if 0 //defined(__MMX__)
      {
       __m64 foofoo = _mm_set1_pi8(0xFF);
       __m64 fourfour = _mm_set1_pi8(0x40);

       do
       {
	__m64 t = *(__m64*)&sprlinebuf[n];
	__m64 poo = *(__m64*)&P[n];
	__m64 choo, bgmask, sprmask;

	choo = _mm_srli_pi32(_mm_and_si64(_mm_or_si64(_mm_xor_si64(_mm_or_si64(poo, t), foofoo), _mm_srli_pi32(t, 1)), fourfour), 6);
	bgmask = _mm_add_pi8(choo, foofoo);
	sprmask = _mm_xor_si64(bgmask, foofoo);

	*(__m64*)&P[n] = _mm_or_si64(_mm_and_si64(t, bgmask), _mm_and_si64(poo, sprmask));
	n += 8;
       } while(n);
       _mm_empty();
      }
#else
      do
      {
       #ifdef HAVE_NATIVE64BIT
       uint64 t = MDFN_densb<uint64, true>(sprlinebuf + n);
       uint64 poo = MDFN_densb<uint64, true>(P + n);
       uint64 choo = (((~(poo | t)) | (t >> 1)) & 0x4040404040404040) >> 6;
       uint64 bgmask = ((choo - 0x01) & 0xFF) | ((choo - 0x0100) & 0xFF00) | ((choo - 0x010000) & 0xFF0000) | ((choo - 0x01000000) & 0xFF000000) | 
			((choo - 0x0100000000) & 0xFF00000000) | ((choo - 0x010000000000) & 0xFF0000000000) | ((choo - 0x01000000000000) & 0xFF000000000000) | ((choo - 0x0100000000000000) & 0xFF00000000000000);
       uint64 sprmask = ~bgmask;

       MDFN_ennsb<uint64, true>(P + n, (t & bgmask) | (poo & sprmask));
       n += 8;
       #else
       uint32 t = MDFN_densb<uint32, true>(sprlinebuf + n);
       uint32 poo = MDFN_densb<uint32, true>(P + n);
       uint32 choo = (((~(poo | t)) | (t >> 1)) & 0x40404040) >> 6;
       uint32 bgmask = ((choo - 0x01) & 0xFF) | ((choo - 0x0100) & 0xFF00) | ((choo - 0x010000) & 0xFF0000) | ((choo - 0x01000000) & 0xFF000000);
       uint32 sprmask = ~bgmask;
       
       MDFN_ennsb<uint32, true>(P + n, (t & bgmask) | (poo & sprmask));
       n += 4;
       #endif
      } while(n);
#endif
}
