/* Decode a Game Genie code into an M68000 address/data pair.
 * The Game Genie code is made of the characters
 * ABCDEFGHJKLMNPRSTVWXYZ0123456789 (notice the missing I, O, Q and U).
 * Where A = 00000, B = 00001, C = 00010, ... , on to 9 = 11111.
 *
 * These come out to a very scrambled bit pattern like this:
 * (SCRA-MBLE is just an example)
 *
 *   S     C     R     A  -  M     B     L     E
 * 01111 00010 01110 00000 01011 00001 01010 00100
 * ijklm nopIJ KLMNO PABCD EFGHd efgha bcQRS TUVWX
 *
 * Our goal is to rearrange that to this:
 *
 * 0000 0101 1001 1100 0100 0100 : 1011 0000 0111 1000
 * ABCD EFGH IJKL MNOP QRST UVWX : abcd efgh ijkl mnop
 *
 * which in Hexadecimal is 059C44:B078. Simple, huh? ;)
 *
 * So, then, we dutifully change memory location 059C44 to B078!
 * (of course, that's handled by a different source file :)
 */

#include "pico_int.h"
#include "memory.h"
#include "patch.h"

struct patch
{
   unsigned int addr;
   unsigned short data;
   unsigned char comp;
};

struct patch_inst *PicoPatches = NULL;
int PicoPatchCount = 0;

static char genie_chars_md[] = "AaBbCcDdEeFfGgHhJjKkLlMmNnPpRrSsTtVvWwXxYyZz0O1I2233445566778899";

/* genie_decode
 * This function converts a Game Genie code to an address:data pair.
 * The code is given as an 8-character string, like "BJX0SA1C". It need not
 * be null terminated, since only the first 8 characters are taken. It is
 * assumed that the code is already made of valid characters, i.e. there are no
 * Q's, U's, or symbols. If such a character is
 * encountered, the function will return with a warning on stderr.
 *
 * The resulting address:data pair is returned in the struct patch pointed to
 * by result. If an error results, both the address and data will be set to -1.
 */

static void genie_decode_md(const char* code, struct patch* result)
{
  int i = 0, n;
  char* x;

  for(; i < 9; ++i)
  {
    /* Skip i=4; it's going to be the separating hyphen */
    if (i==4) continue;

    /* If strchr returns NULL, we were given a bad character */
    if(!(x = strchr(genie_chars_md, code[i])))
    {
      result->addr = -1; result->data = -1;
      return;
    }
    n = (x - genie_chars_md) >> 1;
    /* Now, based on which character this is, fit it into the result */
    switch(i)
    {
    case 0:
      /* ____ ____ ____ ____ ____ ____ : ____ ____ ABCD E___ */
      result->data |= n << 3;
      break;
    case 1:
      /* ____ ____ DE__ ____ ____ ____ : ____ ____ ____ _ABC */
      result->data |= n >> 2;
      result->addr |= (n & 3) << 14;
      break;
    case 2:
      /* ____ ____ __AB CDE_ ____ ____ : ____ ____ ____ ____ */
      result->addr |= n << 9;
      break;
    case 3:
      /* BCDE ____ ____ ___A ____ ____ : ____ ____ ____ ____ */
      result->addr |= (n & 0xF) << 20 | (n >> 4) << 8;
      break;
    case 5:
      /* ____ ABCD ____ ____ ____ ____ : ___E ____ ____ ____ */
      result->data |= (n & 1) << 12;
      result->addr |= (n >> 1) << 16;
      break;
    case 6:
      /* ____ ____ ____ ____ ____ ____ : E___ ABCD ____ ____ */
      result->data |= (n & 1) << 15 | (n >> 1) << 8;
      break;
    case 7:
      /* ____ ____ ____ ____ CDE_ ____ : _AB_ ____ ____ ____ */
      result->data |= (n >> 3) << 13;
      result->addr |= (n & 7) << 5;
      break;
    case 8:
      /* ____ ____ ____ ____ ___A BCDE : ____ ____ ____ ____ */
      result->addr |= n;
      break;
    }
    /* Go around again */
  }
  return;
}

/* "Decode" an address/data pair into a structure. This is for "012345:ABCD"
 * type codes. You're more likely to find Genie codes circulating around, but
 * there's a chance you could come on to one of these. Which is nice, since
 * they're MUCH easier to implement ;) Once again, the input should be depunc-
 * tuated already. */

static char hex_chars[] = "00112233445566778899AaBbCcDdEeFf";

static void hex_decode_md(const char *code, struct patch *result)
{
  char *x;
  int i;
  /* 6 digits for address */
  for(i = 0; i < 6; ++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->addr = (result->addr << 4) | ((x - hex_chars) >> 1);
  }
  /* 4 digits for data */
  for(i = 7; i < 11; ++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      if (i==8) break;
      result->addr = result->data = -1;
      return;
    }
    result->data = (result->data << 4) | ((x - hex_chars) >> 1);
  }
}

void genie_decode_ms(const char *code, struct patch *result)
{
  char *x;
  int i;
  /* 2 digits for data */
  for(i=0;i<2;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->data = (result->data << 4) | ((x - hex_chars) >> 1);
  }
  /* 4 digits for address */
  for(i=2;i<7;++i)
  {
    /* 4th character is hyphen and can be skipped*/
    if (i==3) continue;
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->addr = (result->addr << 4) | ((x - hex_chars) >> 1);
  }
  /* Correct the address */
  result->addr = ((result->addr >> 4) | (result->addr << 12 & 0xF000)) ^ 0xF000;
  /* Optional: 3 digits for comp */
  if (code[7]=='-')
  {
    for(i=8;i<11;++i)
    {
      if (i==9) continue; /* 2nd character is ignored */
      if(!(x = strchr(hex_chars, code[i])))
      {
         result->addr = result->data = -1;
         return;
      }
      result->comp = (result->comp << 4) | ((x - hex_chars) >> 1);
    }
    /* Correct the comp */
    result->comp = ((result->comp >> 2) | ((result->comp << 6) & 0xC0)) ^ 0xBA;
  }
}

void ar_decode_ms(const char *code, struct patch *result){
  char *x;
  int i;
  /* 2 digits of padding*/
  /* 4 digits for address */
  for(i=2;i<7;++i)
  {
    /* 5th character is hyphen and can be skipped*/
    if (i==4) continue;
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->addr = (result->addr << 4) | ((x - hex_chars) >> 1);
  }
  /* 2 digits for data */
  for(i=7;i<9;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->data = (result->data << 4) | ((x - hex_chars) >> 1);
  }
}

void fusion_ram_decode(const char *code, struct patch *result){
  char *x;
  int i;
  /* 4 digits for address */
  for(i=0;i<4;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->addr = (result->addr << 4) | ((x - hex_chars) >> 1);
  }
  /* Skip the ':' */
  /* 2 digits for data */
  for(i=5;i<7;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->data = (result->data << 4) | ((x - hex_chars) >> 1);
  }
}

void fusion_rom_decode(const char *code, struct patch *result){
  char *x;
  int i;
  /* 2 digits for comp */
  for(i=0;i<2;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->comp = (result->comp << 4) | ((x - hex_chars) >> 1);
  }
  /* 4 digits for address */
  for(i=2;i<6;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->addr = (result->addr << 4) | ((x - hex_chars) >> 1);
  }
  /* 2 digits for data */
  for(i=7;i<9;++i)
  {
    if(!(x = strchr(hex_chars, code[i])))
    {
      result->addr = result->data = -1;
      return;
    }
    result->data = (result->data << 4) | ((x - hex_chars) >> 1);
  }
}

/* THIS is the function you call from the MegaDrive or whatever. This figures
 * out whether it's a genie or hex code, depunctuates it, and calls the proper
 * decoder. */
void decode(const char* code, struct patch* result)
{
  int len = strlen(code);

  /* Initialize the result */
  result->addr = result->data = result->comp = 0;

  if(!(PicoIn.AHW & PAHW_SMS))
  {
    //If Genesis

    //Game Genie
    if(len == 9 && code[4] == '-')
    {
      genie_decode_md(code, result);
      return;
    }

    //Master
    else if(len >=9 && code[6] == ':')
    {
      hex_decode_md(code, result);
    }

    else
    {
      goto bad_code;
    }
  } else {
    //If Master System

    //Genie
    if(len >= 7 && code[3] == '-')
    {
      genie_decode_ms(code, result);
    }

    //AR
    else if(len == 9 && code[4] == '-')
    {
      ar_decode_ms(code, result);
    }

    //Fusion RAM
    else if(len == 7 && code[4] == ':')
    {
      fusion_ram_decode(code, result);
    }

    //Fusion ROM
    else if(len == 9 && code[6] == ':')
    {
      fusion_rom_decode(code, result);
    }

    else
    {
      goto bad_code;
    }

    //Convert RAM address space to Genesis location.
    if (result->addr>=0xC000)
      result->addr= 0xFF0000 | (0x1FFF & result->addr);
  }

  return;

  bad_code:
  result->data = result->addr = -1;
  return;
}

void PicoPatchUnload(void)
{
   if (PicoPatches != NULL)
   {
      free(PicoPatches);
      PicoPatches = NULL;
   }
   PicoPatchCount = 0;
}

int PicoPatchLoad(const char *fname)
{
   FILE *f;
   char buff[256];
   struct patch pt;
   int array_len = 0;

   PicoPatchUnload();

   f = fopen(fname, "r");
   if (f == NULL)
   {
      return -1;
   }

   while (fgets(buff, sizeof(buff), f))
   {
      int llen, clen;

      llen = strlen(buff);
      for (clen = 0; clen < llen; clen++)
         if (isspace_(buff[clen]))
            break;
      buff[clen] = 0;

      if (clen > 11 || clen < 8)
         continue;

      decode(buff, &pt);
      if (pt.addr == (unsigned int)-1 || pt.data == (unsigned short)-1)
         continue;

      /* code was good, add it */
      if (array_len < PicoPatchCount + 1)
      {
         void *ptr;
         array_len *= 2;
         array_len++;
         ptr = realloc(PicoPatches, array_len * sizeof(PicoPatches[0]));
         if (ptr == NULL) break;
         PicoPatches = ptr;
      }
      strcpy(PicoPatches[PicoPatchCount].code, buff);
      /* strip */
      for (clen++; clen < llen; clen++)
         if (!isspace_(buff[clen]))
            break;
      for (llen--; llen > 0; llen--)
         if (!isspace_(buff[llen]))
            break;
      buff[llen+1] = 0;
      strncpy(PicoPatches[PicoPatchCount].name, buff + clen, 51);
      PicoPatches[PicoPatchCount].name[51] = 0;
      PicoPatches[PicoPatchCount].active = 0;
      PicoPatches[PicoPatchCount].addr = pt.addr;
      PicoPatches[PicoPatchCount].data = pt.data;
      PicoPatches[PicoPatchCount].data_old = 0;
      PicoPatchCount++;
      // fprintf(stderr, "loaded patch #%i: %06x:%04x \"%s\"\n", PicoPatchCount-1, pt.addr, pt.data,
      // PicoPatches[PicoPatchCount-1].name);
   }
   fclose(f);

   return 0;
}

/* to be called when the Rom is loaded and byteswapped */
void PicoPatchPrepare(void)
{
   int i;
   int addr;

   for (i = 0; i < PicoPatchCount; i++)
   {
      addr=PicoPatches[i].addr;
      addr &= ~1;
      if (addr < Pico.romsize)
         PicoPatches[i].data_old = *(u16 *)(Pico.rom + addr);
      else
      {
         if(!(PicoIn.AHW & PAHW_SMS))
            PicoPatches[i].data_old = (u16) m68k_read16(addr);
         else
            ;// wrong: PicoPatches[i].data_old = (unsigned char) PicoRead8_z80(addr);
      }
      if (strstr(PicoPatches[i].name, "AUTO"))
         PicoPatches[i].active = 1;
   }
}

void PicoPatchApply(void)
{
   int i, u;
   unsigned int addr;

   for (i = 0; i < PicoPatchCount; i++)
   {
      addr = PicoPatches[i].addr;

      if (addr < Pico.romsize)
      {
         if (PicoPatches[i].active)
         {
            if (!(PicoIn.AHW & PAHW_SMS))
               *(u16 *)(Pico.rom + addr) = PicoPatches[i].data;
            else if (!PicoPatches[i].comp || PicoPatches[i].comp == *(char *)(Pico.rom + addr))
               *(char *)(Pico.rom + addr) = (char) PicoPatches[i].data;
         }
         else
         {
            // if current addr is not patched by older patch, write back original val
            for (u = 0; u < i; u++)
               if (PicoPatches[u].addr == addr) break;
            if (u == i)
            {
               if (!(PicoIn.AHW & PAHW_SMS))
                  *(u16 *)(Pico.rom + addr) = PicoPatches[i].data_old;
               else
                  *(char *)(Pico.rom + addr) = (char) PicoPatches[i].data_old;
            }
         }
      // fprintf(stderr, "patched %i: %06x:%04x\n", PicoPatches[i].active, addr,
      // *(u16 *)(Pico.rom + addr));
      }
      else
      {
         if (PicoPatches[i].active)
         {
            if (!(PicoIn.AHW & PAHW_SMS))
              m68k_write16(addr,PicoPatches[i].data);
            else
              ;// wrong: PicoWrite8_z80(addr,PicoPatches[i].data);
         }
         else
         {
            // if current addr is not patched by older patch, write back original val
            for (u = 0; u < i; u++)
               if (PicoPatches[u].addr == addr) break;
            if (u == i)
            {
              if (!(PicoIn.AHW & PAHW_SMS))
                 m68k_write16(PicoPatches[i].addr,PicoPatches[i].data_old);
              else
                ;// wrong: PicoWrite8_z80(PicoPatches[i].addr,PicoPatches[i].data_old);
            }
         }
      }
   }
}

