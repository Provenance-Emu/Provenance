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

#include "main.h"
#include "memdebugger.h"
#include "debugger.h"
#include "prompt.h"
#include <mednafen/FileStream.h>

#include <ctype.h>
#include <trio/trio.h>
#include <errno.h>

bool MemDebugger::ICV_Init(const char *newcode)
{
 if((size_t)ict != (size_t)-1)
 {
  iconv_close(ict);
  ict = (iconv_t)-1;
 }

 if((size_t)ict_to_utf8 != (size_t)-1)
 {
  iconv_close(ict_to_utf8);
  ict_to_utf8 = (iconv_t)-1;
 }

 if((size_t)ict_utf16_to_game != (size_t)-1)
 {
  iconv_close(ict_utf16_to_game);
  ict_utf16_to_game = (iconv_t)-1;
 }

 ict = iconv_open(newcode, "UTF-8");
 if((size_t)ict == (size_t)-1)
 {
  error_string = trio_aprintf("iconv_open() error: %m");
  error_time = SDL_GetTicks();
  return(0);
 }

 ict_to_utf8 = iconv_open("UTF-8", newcode);
 if((size_t)ict_to_utf8 == (size_t)-1)
 {
  error_string = trio_aprintf("iconv_open() error: %m");
  error_time = SDL_GetTicks();
  return(0);
 }

 ict_utf16_to_game = iconv_open(newcode, "UTF-16");
 if((size_t)ict_utf16_to_game == (size_t)-1)
 {
  error_string = trio_aprintf("iconv_open() error: %m");
  error_time = SDL_GetTicks();
  return(0);
 }

 GameCode = std::string(newcode);
 return(1);
}

class MemDebuggerPrompt : public HappyPrompt
{
        public:

        MemDebuggerPrompt(MemDebugger* memdbg_in, const std::string &ptext, const std::string &zestring) : HappyPrompt(ptext, zestring), memdbg(memdbg_in)
        {

        }
        ~MemDebuggerPrompt()
        {

        }

        private:

        void TheEnd(const std::string &pstring);

	MemDebugger* memdbg;
};

void MemDebuggerPrompt::TheEnd(const std::string &pstring)
{
	memdbg->PromptFinish(pstring);
}


bool MemDebugger::DoBSSearch(uint32 byte_count, uint8 *thebytes)
{
	 const uint64 zemod = SizeCache[CurASpace];
         const uint32 start_a = ASpacePos[CurASpace] % zemod;
         uint32 a = start_a;
	 bool found = FALSE;
	 uint8 *bbuffer = (uint8 *)calloc(1, byte_count);

	 
         do
         {
          ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), a, byte_count, bbuffer);
          if(!memcmp(bbuffer, thebytes, byte_count))
          {
           ASpacePos[CurASpace] = a;
           found = TRUE;
           break;
          }
          a = (a + 1) % zemod;
         } while(a != start_a);
	 

	 free(bbuffer);
	 return(found);
}

bool MemDebugger::DoRSearch(uint32 byte_count, uint8 *the_bytes)
{
	 const uint64 zemod = SizeCache[CurASpace];
         const uint32 start_a = (ASpacePos[CurASpace] - 1) % zemod;
         uint32 a = start_a;
	 bool found = FALSE;
	 uint8 *bbuffer = (uint8 *)calloc(1, byte_count);

	 
         do
         {
          ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), a, byte_count + 1, bbuffer);
          bool match = TRUE;

          for(uint32 i = 1; i <= byte_count; i++)
          {
           if(((bbuffer[i] - bbuffer[i - 1]) & 0xFF) != the_bytes[i - 1])
           {
            match = FALSE;
            break;
           }
          }
          if(match)
          {
           found = TRUE;
           ASpacePos[CurASpace] = (a + 1) % zemod;
           break;
          }
          a = (a + 1) % zemod;
         } while(a != start_a);
	 
	 free(bbuffer);

	 return(found);
}

uint8 *MemDebugger::TextToBS(const char *text, size_t *TheCount)
{
          size_t byte_count;
          uint8 *thebytes = NULL;
	  size_t text_len = strlen(text);
          size_t nib_count;

          thebytes = (uint8 *)calloc(1, text_len / 2);

          nib_count = 0;
          for(size_t x = 0; x < text_len; x++)
          {
           int c = tolower(text[x]);
           if(c >= '0' && c <= '9')
            c -= '0';
           else if(c >= 'a' && c <= 'f')
           {
            c = c - 'a' + 0xa;
           }
           else if(c == ' ')
           {
            continue;
           }
           else
           {
            error_string = trio_aprintf("Invalid character '%c' in bytestring.", c);
            error_time = SDL_GetTicks();
            InPrompt = None;
	    free(thebytes);
            return(NULL);
           }
           thebytes[nib_count >> 1] |= c << ((nib_count & 1) ? 0 : 4);
           nib_count++;
          }

          if(nib_count & 1)
          {
           error_string = trio_aprintf("Invalid number of characters in bytestring.");
           error_time = SDL_GetTicks();
           InPrompt = None;
	   free(thebytes);
           return(NULL);;
          }

          byte_count = nib_count >> 1;
	  *TheCount = byte_count;
	  return(thebytes);
}

void MemDebugger::PromptFinish(const std::string &pstring)
{
	 if(error_string)
	 {
	  free(error_string);
	  error_string = NULL;
	 }
         if(InPrompt == Goto || InPrompt == GotoDD)
         {
	  unsigned long long NewAddie;

	  if(trio_sscanf(pstring.c_str(), "%llx", &NewAddie) == 1)
	  {
	   ASpacePos[CurASpace] = NewAddie;
	   LowNib = FALSE;
	   if(InPrompt == GotoDD)
	    GoGoPowerDD[CurASpace] = NewAddie;
	  }
         }
	 else if(InPrompt == SetCharset)
	 {
	  if(ICV_Init(pstring.c_str()))
	  {
	   
	   MDFNI_SetSetting(std::string(CurGame->shortname) + "." + std::string("debugger.memcharenc"), pstring);
	   
	  }
	 }
         else if(InPrompt == DumpMem)
         {
          uint32 A1, A2, tmpsize;
          char fname[256];
	  bool acceptable = FALSE;


          if(trio_sscanf(pstring.c_str(), "%08x %08x %255[^\r\n]", &A1, &A2, fname) == 3)
	   acceptable = TRUE;
          else if(trio_sscanf(pstring.c_str(), "%08x +%08x %255[^\r\n]", &A1, &tmpsize, fname) == 3)
	  {
	   acceptable = TRUE;
	   A2 = A1 + tmpsize - 1;
	  }

	  if(acceptable)
          {
           
	   try
	   {
	    FileStream fp(fname, FileStream::MODE_WRITE);
            uint8 write_buffer[256];
            uint64 a = A1;

	    //printf("%08x %08x\n", A1, A2);

	    while(a <= A2)
	    {
             size_t to_write;
             to_write = A2 - a + 1;
             if(to_write > 256) to_write = 256;

	     ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), a, to_write, write_buffer);

	     fp.write(write_buffer, to_write);
	     a += to_write;
	    }
           }
	   catch(std::exception &e)
	   {
            error_string = trio_aprintf("%s", e.what());
            error_time = SDL_GetTicks();
	   }
           
          }
	  else
	  {
	   error_string = trio_aprintf("Invalid memory dump specification.");
	   error_time = SDL_GetTicks();
	  }
         }
         else if(InPrompt == LoadMem)
         {
          uint32 A1, A2, tmpsize;
          char fname[256];
          bool acceptable = FALSE;

          if(trio_sscanf(pstring.c_str(), "%08x %08x %255[^\r\n]", &A1, &A2, fname) == 3)
           acceptable = TRUE;
          else if(trio_sscanf(pstring.c_str(), "%08x +%08x %255[^\r\n]", &A1, &tmpsize, fname) == 3)
          {
           acceptable = TRUE;
           A2 = A1 + tmpsize - 1;
          }

          if(acceptable)
          {
	   

	   try
	   {
            FileStream fp(fname, FileStream::MODE_READ);
	    uint8 read_buffer[256];
	    uint64 a = A1;

	    while(a <= A2)
	    {
	     size_t to_read; 
	     size_t read_len;

	     to_read = A2 - a + 1;
	     if(to_read > 256) to_read = 256;

	     read_len = fp.read(read_buffer, to_read, false);

	     if(read_len > 0)
              ASpace->PutAddressSpaceBytes(ASpace->name.c_str(), a, read_len, 1, TRUE, read_buffer);

             a += read_len;

	     if(read_len != to_read)
	     {
	      error_string = trio_aprintf("Warning: unexpected EOF(short by %08llx byte(s))", (unsigned long long)(A2 - a + 1));
	      error_time = SDL_GetTicks();
	      break;
	     }
	    }
           }
	   catch(std::exception &e)
	   {
            error_string = trio_aprintf("%s", e.what());
            error_time = SDL_GetTicks();
	   }
	   
          }
          else
          {
           error_string = trio_aprintf("Invalid memory load specification.");
           error_time = SDL_GetTicks();
          }
         }
	 else if(InPrompt == TextSearch)
	 {
          uint8 *thebytes;
	  uint32 bcount;

          TS_String = pstring;

          char *inbuf, *outbuf;
          char *utf8_string;
          size_t ibl, obl, obl_start;
          size_t result;

          utf8_string = strdup(pstring.c_str());

          ibl = strlen(utf8_string);
          obl_start = obl = (ibl + 1) * 8; // Hehe, ugly maximum estimation!
          thebytes = (uint8 *)calloc(1, obl_start);

          inbuf = utf8_string;
          outbuf = (char*)thebytes;

	  result = iconv(ict, (ICONV_CONST char **)&inbuf, &ibl, &outbuf, &obl);

          if(result == (size_t)-1)
          {
           error_string = trio_aprintf("iconv() error: %m");
           error_time = SDL_GetTicks();
           InPrompt = None;
	   free(utf8_string);
	   free(thebytes);
           return;
          }
	  bcount = obl_start - obl;
          free(utf8_string);

	  if(!DoBSSearch(bcount, thebytes))
	  {
	   error_string = trio_aprintf("String not found.");
	   error_time = SDL_GetTicks();
	   InPrompt = None;
	  }
	  free(thebytes);
	 }
	 else if(InPrompt == ByteStringSearch)
	 {
	  size_t byte_count;
	  uint8 *the_bytes;
	  BSS_String = pstring;

	  if(!(the_bytes = TextToBS(pstring.c_str(), &byte_count)))
	   return;

	  if(!DoBSSearch(byte_count, the_bytes))
          {
	   free(the_bytes);
           error_string = trio_aprintf("Bytestring \"%s\" not found.", pstring.c_str());
           error_time = SDL_GetTicks();
           InPrompt = None;
           return;
          }
	  free(the_bytes);
	 }
	 else if(InPrompt == RelSearch)
	 {
          size_t byte_count;
          uint8 *the_bytes;
	  RS_String = pstring;

          if(!(the_bytes = TextToBS(pstring.c_str(), &byte_count)))
           return;

	  if(!DoRSearch(byte_count, the_bytes))
	  {
	   free(the_bytes);
           error_string = trio_aprintf("Bytestring \"%s\" not found.", pstring.c_str());
           error_time = SDL_GetTicks();
           InPrompt = None;
           return;
	  }
	  free(the_bytes);
	 }
         InPrompt = None;
}

// Call this function from the game thread.
void MemDebugger::SetActive(bool newia)
{
 if(CurGame->Debugger)
 {
  IsActive = newia;
  if(!newia)
  {
   InEditMode = FALSE;
   LowNib = FALSE;
  }
 }
}

#define MK_COLOR_A(r,g,b,a) (pf_cache.MakeColor(r, g, b, a))

// Call this function from the game thread
void MemDebugger::Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect)
{
 if(!IsActive) return;

 const MDFN_PixelFormat pf_cache = surface->format;
 uint32 *pixels = surface->pixels;
 uint32 pitch32 = surface->pitchinpix;
 const uint64 zemod = SizeCache[CurASpace];

 

 DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, ASpace->long_name.c_str(), MK_COLOR_A(0x20, 0xFF, 0x20, 0xFF), 1, 1);
 pixels += 10 * pitch32;

 uint32 A;
 uint32 Ameow; // A meow for a cat

 if(ASpacePos[CurASpace] < 128)
  A = (SizeCache[CurASpace] - 128 + ASpacePos[CurASpace]) % SizeCache[CurASpace];
 else
  A = ASpacePos[CurASpace] - 128;

 Ameow = A &~ 0xF;

 int numrows = zemod / 16;

 if(numrows > 16)
  numrows = 16;
 else if(numrows < 4)
  numrows = 4;

 for(int y = 0; y < numrows; y++)
 {
  uint8 byte_buffer[16];
  char abuf[32];

  Ameow %= zemod;

  ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), Ameow, 16, byte_buffer);

  if(zemod <= (1 << 16))
   trio_snprintf(abuf, 32, "%04X:", Ameow);
  else if(zemod <= (1 << 24))
   trio_snprintf(abuf, 32, "%06X:", Ameow);
  else
   trio_snprintf(abuf, 32, "%08X:", Ameow);

  uint32 alen;
  uint32 addr_color = MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF);

  if(Ameow == (ASpacePos[CurASpace] & ~0xF))
   addr_color = MK_COLOR_A(0x80, 0xB0, 0xFF, 0xFF);

  alen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, abuf, addr_color, 0, 1);
  alen += 3;

  for(int x = 0; x < 16; x++)
  {
   uint32 bcolor = MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF);
   uint32 acolor = MK_COLOR_A(0xA0, 0xA0, 0xA0, 0xFF);

   char quickbuf[16];
   uint32 test_match_pos;
   char ascii_str[2];

   ascii_str[1] = 0;
   ascii_str[0] = byte_buffer[x];

   if((uint8)ascii_str[0] < 0x20 || (uint8)ascii_str[0] >= 128)
    ascii_str[0] = '.';

   trio_snprintf(quickbuf, 16, "%02X", byte_buffer[x]);

   test_match_pos = ASpacePos[CurASpace] % zemod;

   if(Ameow == test_match_pos)
   {
    if(InEditMode)
     if(SDL_GetTicks() & 0x80)
     {
      int pix_offset = alen;

      if(InTextArea)
       pix_offset += 16 * 12 + x * 5;
      else
       pix_offset += (LowNib ? 5 : 0) + x * 12;

      DrawTextTrans(pixels + pix_offset, surface->pitchinpix << 2, rect->w, "▉", MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);
     }
    if(InTextArea)
    {
     acolor = MK_COLOR_A(0xFF, 0x00, 0x00, 0xFF);
     bcolor = MK_COLOR_A(0xFF, 0x80, 0x80, 0xFF);
    }
    else
    {
     acolor = MK_COLOR_A(0xFF, 0x80, 0x80, 0xFF);
     bcolor = MK_COLOR_A(0xFF, 0x00, 0x00, 0xFF);
    }
   }

   // hex display
   DrawTextTrans(pixels + alen + x * 12, surface->pitchinpix << 2, rect->w, quickbuf, bcolor, 0, 1);

   // ASCII display
   DrawTextTrans(pixels + alen + 16 * 12 + x * 5, surface->pitchinpix << 2, rect->w, ascii_str, acolor, 0, 1);
   Ameow++;
  }
  pixels += 9 * pitch32;
 }

 {
  char cpstr[32];
  uint32 curpos = ASpacePos[CurASpace];
  uint8 zebytes[4];
  uint32 tmpval;

  curpos %= zemod;

  ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), curpos, 4, zebytes);

  pixels += 8 + 5 * pitch32;

  if(zemod <= (1 << 16))
   trio_snprintf(cpstr, 32, "%04X", curpos);
  else if(zemod <= (1 << 24))
   trio_snprintf(cpstr, 32, "%06X", curpos);
  else
   trio_snprintf(cpstr, 32, "%08X", curpos);

  uint32 cpplen;
  uint32 cplen;

  cpplen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, "Cursor position: ", MK_COLOR_A(0xa0, 0xa0, 0xFF, 0xFF), 0, 1);
  cplen = DrawTextTrans(pixels + cpplen, surface->pitchinpix << 2, rect->w, cpstr , MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);
  if(GoGoPowerDD[CurASpace])
  {
   char ggddstr[32];

   if(zemod <= (1 << 16))
    trio_snprintf(ggddstr, 32, "%04llX", (unsigned long long)(curpos - GoGoPowerDD[CurASpace]));
   else if(zemod <= (1 << 24))
    trio_snprintf(ggddstr, 32, "%06llX", (unsigned long long)(curpos - GoGoPowerDD[CurASpace]));
   else
    trio_snprintf(ggddstr, 32, "%08llX", (unsigned long long)(curpos - GoGoPowerDD[CurASpace]));

   DrawTextTrans(pixels + cpplen + cplen + 8, surface->pitchinpix << 2, rect->w, ggddstr, MK_COLOR_A(0xFF, 0x80, 0x80, 0xFF), 0, 1);
  }
  pixels += 5 + 10 * pitch32;

  tmpval = zebytes[0];
  trio_snprintf(cpstr, 32, "%02x(%u, %d)", tmpval, (uint8)tmpval, (int8)tmpval);
  cpplen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, "1-byte value: ", MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, 1);
  DrawTextTrans(pixels + cpplen, surface->pitchinpix << 2, rect->w, cpstr , MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);

  pixels += 10 * pitch32;


  if(ASpace->IsWave && SizeCache[CurASpace] <= 128 && ASpace->WaveBits <= 6)
  {
   const int32 wf_size = SizeCache[CurASpace];
   uint8 waveform[wf_size];
   const int32 pcm_max = (1 << ASpace->WaveBits) - 1;

   DrawTextTrans(pixels - 5, surface->pitchinpix << 2, rect->w, "Full waveform:", MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, 1);
   pixels += 9 * pitch32;

   // BLECK, FIXME to not be so crazy.
   {
    uint32 tx, ty;

    tx = (pixels - surface->pixels) % surface->pitchinpix;
    ty = (pixels - surface->pixels) / surface->pitchinpix;

    MDFN_DrawFillRect(surface, tx, ty, 2 + wf_size * 2 + 2, 2 + (pcm_max + 1) + 2, MK_COLOR_A(0xA0,0xA0,0xA0,0xFF), MK_COLOR_A(0,0,0,0xFF));
   }

   ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), 0, wf_size, waveform);

   for(int i = 0; i < wf_size; i++)
   {
    int32 delta;
    int32 current;
    int32 previous;

    current = waveform[i];
    previous = waveform[(i + wf_size - 1) % wf_size];

    delta = current - previous;

    for(int y = previous; y != current; y += delta / abs(delta))
     pixels[2 + i * 2 + 0 + (2 + (pcm_max - y)) * surface->pitchinpix] = MK_COLOR_A(0x00,0xA0,0x00,0xFF);

    pixels[2 + i * 2 + 0 + (2 + (pcm_max - current)) * surface->pitchinpix] = MK_COLOR_A(0x00,0xA0,0x00,0xFF);
    pixels[2 + i * 2 + 1 + (2 + (pcm_max - current)) * surface->pitchinpix] = MK_COLOR_A(0x00,0xA0,0x00,0xFF);
   }
  }
  else
  {
  tmpval = zebytes[0] | (zebytes[1] << 8);
  trio_snprintf(cpstr, 32, "%04x(%u, %d)", tmpval, (uint16)tmpval, (int16)tmpval);
  cpplen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, "2-byte value(LSB): ", MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, 1);
  DrawTextTrans(pixels + cpplen, surface->pitchinpix << 2, rect->w, cpstr , MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);

  pixels += 10 * pitch32;
  tmpval = zebytes[0] | (zebytes[1] << 8) | (zebytes[2] << 16) | (zebytes[3] << 24);
  trio_snprintf(cpstr, 32, "%08x(%u, %d)", tmpval, (uint32)tmpval, (int32)tmpval);
  cpplen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, "4-byte value(LSB): ", MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, 1);
  DrawTextTrans(pixels + cpplen, surface->pitchinpix << 2, rect->w, cpstr , MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);

  pixels += 10 * pitch32;
  tmpval = zebytes[1] | (zebytes[0] << 8);
  trio_snprintf(cpstr, 32, "%04x(%u, %d)", tmpval, (uint16)tmpval, (int16)tmpval);
  cpplen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, "2-byte value(MSB): ", MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, 1);
  DrawTextTrans(pixels + cpplen, surface->pitchinpix << 2, rect->w, cpstr , MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);

  pixels += 10 * pitch32;
  tmpval = zebytes[3] | (zebytes[2] << 8) | (zebytes[1] << 16) | (zebytes[0] << 24);
  trio_snprintf(cpstr, 32, "%08x(%u, %d)", tmpval, (uint32)tmpval, (int32)tmpval);
  cpplen = DrawTextTrans(pixels, surface->pitchinpix << 2, rect->w, "4-byte value(MSB): ", MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, 1);
  DrawTextTrans(pixels + cpplen, surface->pitchinpix << 2, rect->w, cpstr , MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, 1);

  trio_snprintf(cpstr, 32, "%s text: ", GameCode.c_str());
  cpplen = DrawTextTrans(pixels + 10 * pitch32, surface->pitchinpix << 2, rect->w, cpstr, MK_COLOR_A(0xA0, 0xA0, 0xFF, 0xFF), 0, MDFN_FONT_5x7);

  {
   char rawbuf[64];
   char textbuf[256];

   ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), curpos, 64, (uint8*)rawbuf);

   size_t ibl, obl, obl_start;
   char *inbuf, *outbuf;
   ibl = 64;
   obl_start = obl = 255; // Hehe, ugly maximum estimation!
   inbuf = rawbuf;
   outbuf = textbuf;

   iconv(ict_to_utf8, (ICONV_CONST char **)&inbuf, &ibl, &outbuf, &obl);
   textbuf[obl_start - obl] = 0;

   DrawTextTrans(pixels + 8 * pitch32 + cpplen, surface->pitchinpix << 2, rect->w - cpplen - 13, textbuf, MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, MDFN_FONT_9x18_18x18);
  }

 }

 }
 

 if(InPrompt)
  myprompt->Draw(surface, rect);
 else if(myprompt)
 {
  delete myprompt;
  myprompt = NULL;
 }

 if(error_string)
 {
  if(SDL_GetTicks() >= (error_time + 4000))
  {
   free(error_string);
   error_string = NULL;
  }
  else
  {
   DrawTextTrans((uint32*)surface->pixels + (rect->h - 7) * pitch32, surface->pitchinpix << 2, rect->w, error_string, MK_COLOR_A(0xFF, 0x00, 0x00, 0xFF), 1, 1);
  }
 }
}

void MemDebugger::ChangePos(int64 delta)
{
 int64 prevpos = ASpacePos[CurASpace];
 int64 newpos;

 newpos = prevpos + delta;

 while(newpos < 0)
  newpos += SizeCache[CurASpace];

 newpos %= SizeCache[CurASpace];
 ASpacePos[CurASpace] = newpos;

 LowNib = FALSE;
}

void MemDebugger::DoCrazy(void)
{
 uint32 start = ASpacePos[CurASpace];
 uint32 A = ASpacePos[CurASpace];

 for(;;)
 {
  uint8 zebyte;

  ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), A, 1, &zebyte);

  // Simple control codes
  if(zebyte < 0x20)
  {
   switch(zebyte)
   {
    default:    printf("UNKNOWN GAHGAHGAH:  %02x\n", zebyte); 
		return;

    case 0x00: goto GetOut; // Crazy escape
    case 0x05: goto GetOut; // Pause+close text box

    // Print numbers, 3 arguments
    case 0x06: 
    case 0x07:
    case 0x08: A += 3; break;

    // Transfer control, 4 arguments
    case 0x12: A += 4; break;

    case 0x0C: break; // Clear text box
    case 0x0D: break; // New line
    case 0x0F: goto GetOut; // Pause+close text box

    case 0x10: break; // Prompt for button to continue
    case 0x11: goto GetOut; // Binary selection magic
    case 0x14: A += 1; break; // Set draw speed, 1 argument
    case 0x17: A += 1; break; // Delay, 1 argument
   }
  }
  else if(zebyte <= 0x7F) // ASCII
  {

  }
  else if(zebyte < 0xEB) // 2-byte SJIS
  {
   A += 1;
  }
  else
  {
   printf("UNKNOWN GAHGAHGAH:  %02x\n", zebyte);
   return;
  }
  A++;
 }

 GetOut:

 ASpacePos[CurASpace] = A;
 printf("%08x\n", A);
 FILE *fp = fopen("markers.txt", "ab");
 fprintf(fp, "%08x %08x\n", start, ASpacePos[CurASpace]);
 fclose(fp);

 
}

// Call this from the game thread
int MemDebugger::Event(const SDL_Event *event)
{
 if(!InPrompt && myprompt)
 {
  delete myprompt;
  myprompt = NULL;
 }
 unsigned int keysym = event->key.keysym.sym;

 switch(event->type)
 {
  case SDL_KEYDOWN:
	if(event->key.keysym.mod & KMOD_ALT)
	 break;

        if(InPrompt)
        {
         myprompt->Event(event);
        }
	else if(InEditMode && InTextArea && keysym != SDLK_TAB && keysym != SDLK_INSERT && keysym != SDLK_UP && keysym != SDLK_DOWN && keysym != SDLK_LEFT
	 && keysym != SDLK_RIGHT && (event->key.keysym.unicode >= 0x20))
	{
	 uint8 to_write[16];
	 int to_write_len;

	 size_t ibl, obl, obl_start;
	 char *inbuf, *outbuf;

	 ibl = 2;
	 obl_start = obl = 16;

	 inbuf = (char *)&event->key.keysym.unicode;
	 outbuf = (char*)to_write;

	 size_t result = iconv(ict_utf16_to_game, (ICONV_CONST char **)&inbuf, &ibl, &outbuf, &obl);
	 if(result != (size_t)-1)
	 {
          to_write_len = obl_start - obl;

	  
	  ASpace->PutAddressSpaceBytes(ASpace->name.c_str(), ASpacePos[CurASpace], to_write_len, 1, TRUE, to_write);
	  

	  LowNib = 0;
	  ChangePos(to_write_len);
	 }
	}
	else if(InEditMode && ((event->key.keysym.sym >= SDLK_0 && event->key.keysym.sym <= SDLK_9)	|| 
	   (event->key.keysym.sym >= SDLK_a && event->key.keysym.sym <= SDLK_f)))
	{
         uint8 tc = 0;
         uint8 meowbyte = 0;

         if(event->key.keysym.sym >= SDLK_0 && event->key.keysym.sym <= SDLK_9)
          tc = 0x0 + event->key.keysym.sym - SDLK_0;
         else if(event->key.keysym.sym >= SDLK_a && event->key.keysym.sym <= SDLK_f)
          tc = 0xA + event->key.keysym.sym - SDLK_a;

	 
         ASpace->GetAddressSpaceBytes(ASpace->name.c_str(), ASpacePos[CurASpace], 1, &meowbyte);
         meowbyte &= 0xF << ((LowNib) * 4);
         meowbyte |= tc << ((!LowNib) * 4);
         ASpace->PutAddressSpaceBytes(ASpace->name.c_str(), ASpacePos[CurASpace], 1, 1, TRUE, &meowbyte);
	 

         LowNib = !LowNib;
         if(!LowNib)
	  ChangePos(1);
        }
	else switch(event->key.keysym.sym)
	{
	 default: break;

         case SDLK_MINUS: Debugger_GT_ModOpacity(-8);
                          break;
         case SDLK_EQUALS: Debugger_GT_ModOpacity(8);
                           break;

	 case SDLK_TAB:
		InTextArea = !InTextArea;
		LowNib = FALSE;
		break;

	 case SDLK_d:
                InPrompt = DumpMem;
                myprompt = new MemDebuggerPrompt(this, "Dump Memory(start end filename)", "");
		break;
	 case SDLK_l:
                InPrompt = LoadMem;
                myprompt = new MemDebuggerPrompt(this, "Load Memory(start end filename)", "");
                break;
	 case SDLK_s:
	        if(SizeCache[CurASpace] > (1 << 24))
                {
                 error_string = trio_aprintf("Address space is too large to search!");
                 error_time = SDL_GetTicks();
                }
		else
		{
		 InPrompt = ByteStringSearch;
		 myprompt = new MemDebuggerPrompt(this, "Byte String Search", BSS_String);
		}
		break;
	 case SDLK_r:
		if(SizeCache[CurASpace] > (1 << 24))
                {
                 error_string = trio_aprintf("Address space is too large to search!");
                 error_time = SDL_GetTicks();
                }
                else
                {
		 InPrompt = RelSearch;
		 myprompt = new MemDebuggerPrompt(this, "Byte String Relative/Delta Search", RS_String);
		}
		break;

	 case SDLK_c:
		InPrompt = SetCharset;
		myprompt = new MemDebuggerPrompt(this, "Charset", GameCode);
		break;

         case SDLK_t:
                if(ASpace->TotalBits > 24)
                {
                 error_string = trio_aprintf("Address space is too large to search!");
                 error_time = SDL_GetTicks();
                }
                else
                {
                 InPrompt = TextSearch;
                 myprompt = new MemDebuggerPrompt(this, "Text Search", TS_String);
                }
                break;

	 case SDLK_RETURN:
	 case SDLK_g:
	        if(event->key.keysym.mod & KMOD_SHIFT)
		{
                 InPrompt = GotoDD;
                 myprompt = new MemDebuggerPrompt(this, "Goto Address(DD)", "");
		}
		else
		{
		 InPrompt = Goto;
		 myprompt = new MemDebuggerPrompt(this, "Goto Address", "");
		}
		break;

	 case SDLK_INSERT:
		InEditMode = !InEditMode;
		LowNib = FALSE;
		break;

	 case SDLK_END: ASpacePos[CurASpace] = (SizeCache[CurASpace] - 128) % SizeCache[CurASpace]; 
			LowNib = FALSE;
			break;

	 case SDLK_HOME: ASpacePos[CurASpace] = 0;
			 LowNib = FALSE;
			 break;


         case SDLK_PAGEUP: ChangePos(-16 * 16); break;
	 case SDLK_PAGEDOWN: ChangePos(16 * 16); break;
	 case SDLK_UP: ChangePos(-16); break;
	 case SDLK_DOWN: ChangePos(16); break;
	 case SDLK_LEFT: ChangePos(-1); break;
	 case SDLK_RIGHT: ChangePos(1); break;

	 case SDLK_COMMA: 
			if(CurASpace)
			 CurASpace--;
			else
			 CurASpace = AddressSpaces->size() - 1;

			ASpace = &(*AddressSpaces)[CurASpace];

			LowNib = FALSE;
			break;
	 case SDLK_PERIOD:
			CurASpace = (CurASpace + 1) % AddressSpaces->size();
			ASpace = &(*AddressSpaces)[CurASpace];

			LowNib = FALSE;
			break;

	 case SDLK_b: DoCrazy();
		      break;
	}
	break;
 }
 return(1);
}


// Called after a game is loaded.
MemDebugger::MemDebugger() : AddressSpaces(NULL), ASpace(NULL), IsActive(false), CurASpace(0),
			     LowNib(false), InEditMode(false), InTextArea(false), error_string(NULL), error_time(0),
			     ict((iconv_t)-1), ict_to_utf8((iconv_t)-1), ict_utf16_to_game((iconv_t)-1), InPrompt(None), myprompt(NULL)			     
{
 if(CurGame->Debugger)
 {
  AddressSpaces = CurGame->Debugger->AddressSpaces;

  CurASpace = 0;
  ASpace = &(*AddressSpaces)[CurASpace];

  size_t num = AddressSpaces->size();

  ASpacePos.resize(num);
  SizeCache.resize(num);
  GoGoPowerDD.resize(num);

  for(size_t i = 0; i < num; i++)
  {
   uint64 tmpsize;

   tmpsize = (*AddressSpaces)[i].NP2Size;

   if(!tmpsize)
    tmpsize = (uint64)1 << (*AddressSpaces)[i].TotalBits;

   SizeCache[i] = tmpsize;
  }

  ICV_Init( MDFN_GetSettingS(std::string(CurGame->shortname) + "." + std::string("debugger.memcharenc")).c_str() );
 }
}

MemDebugger::~MemDebugger()
{
 if(ict != (iconv_t)-1)
 {
  iconv_close(ict);
  ict = (iconv_t)-1;
 }

 if(ict_to_utf8 != (iconv_t)-1)
 {
  iconv_close(ict_to_utf8);
  ict_to_utf8 = (iconv_t)-1;
 }

 if(ict_utf16_to_game != (iconv_t)-1)
 {
  iconv_close(ict_utf16_to_game);
  ict_utf16_to_game = (iconv_t)-1;
 }

 if(error_string)
 {
  free(error_string);
  error_string = NULL;
 }
}
