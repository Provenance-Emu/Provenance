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
#include "patch.h"

struct patch
{
	unsigned int addr;
	unsigned short data;
};

struct patch_inst *PicoPatches = NULL;
int PicoPatchCount = 0;

static char genie_chars[] = "AaBbCcDdEeFfGgHhJjKkLlMmNnPpRrSsTtVvWwXxYyZz0O1I2233445566778899";

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

static void genie_decode(const char* code, struct patch* result)
{
  int i = 0, n;
  char* x;

  for(; i < 8; ++i)
  {
    /* If strchr returns NULL, we were given a bad character */
    if(!(x = strchr(genie_chars, code[i])))
    {
      result->addr = -1; result->data = -1;
      return;
    }
    n = (x - genie_chars) >> 1;
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
    case 4:
      /* ____ ABCD ____ ____ ____ ____ : ___E ____ ____ ____ */
      result->data |= (n & 1) << 12;
      result->addr |= (n >> 1) << 16;
      break;
    case 5:
      /* ____ ____ ____ ____ ____ ____ : E___ ABCD ____ ____ */
      result->data |= (n & 1) << 15 | (n >> 1) << 8;
      break;
    case 6:
      /* ____ ____ ____ ____ CDE_ ____ : _AB_ ____ ____ ____ */
      result->data |= (n >> 3) << 13;
      result->addr |= (n & 7) << 5;
      break;
    case 7:
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

static void hex_decode(const char *code, struct patch *result)
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
  for(i = 6; i < 10; ++i)
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
static void decode(const char* code, struct patch* result)
{
  int len = strlen(code), i, j;
  char code_to_pass[16], *x;
  const char *ad, *da;
  int adl, dal;

  /* Initialize the result */
  result->addr = result->data = 0;

  /* Just assume 8 char long string to be Game Genie code */
  if (len == 8)
  {
    genie_decode(code, result);
    return;
  }

  /* If it's 9 chars long and the 5th is a hyphen, we have a Game Genie
   * code. */
    if(len == 9 && code[4] == '-')
    {
      /* Remove the hyphen and pass to genie_decode */
      code_to_pass[0] = code[0];
      code_to_pass[1] = code[1];
      code_to_pass[2] = code[2];
      code_to_pass[3] = code[3];
      code_to_pass[4] = code[5];
      code_to_pass[5] = code[6];
      code_to_pass[6] = code[7];
      code_to_pass[7] = code[8];
      code_to_pass[8] = '\0';
      genie_decode(code_to_pass, result);
      return;
    }

  /* Otherwise, we assume it's a hex code.
   * Find the colon so we know where address ends and data starts. If there's
   * no colon, then we haven't a code at all! */
  if(!(x = strchr(code, ':'))) goto bad_code;
  ad = code; da = x + 1; adl = x - code; dal = len - adl - 1;

  /* If a section is empty or too long, toss it */
  if(adl == 0 || adl > 6 || dal == 0 || dal > 4) goto bad_code;

  /* Pad the address with zeros, then fill it with the value */
  for(i = 0; i < (6 - adl); ++i) code_to_pass[i] = '0';
  for(j = 0; i < 6; ++i, ++j) code_to_pass[i] = ad[j];

  /* Do the same for data */
  for(i = 6; i < (10 - dal); ++i) code_to_pass[i] = '0';
  for(j = 0; i < 10; ++i, ++j) code_to_pass[i] = da[j];

  code_to_pass[10] = '\0';

  /* Decode and goodbye */
  hex_decode(code_to_pass, result);
  return;

bad_code:

  /* AGH! Invalid code! */
  result->data = result->addr = -1;
  return;
}



unsigned int PicoRead16(unsigned int a);
void PicoWrite16(unsigned int a, unsigned short d);


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
		//	PicoPatches[PicoPatchCount-1].name);
	}
	fclose(f);

	return 0;
}

/* to be called when the Rom is loaded and byteswapped */
void PicoPatchPrepare(void)
{
	int i;

	for (i = 0; i < PicoPatchCount; i++)
	{
		PicoPatches[i].addr &= ~1;
		if (PicoPatches[i].addr < Pico.romsize)
			PicoPatches[i].data_old = *(unsigned short *)(Pico.rom + PicoPatches[i].addr);
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
				*(unsigned short *)(Pico.rom + addr) = PicoPatches[i].data;
			else {
				// if current addr is not patched by older patch, write back original val
				for (u = 0; u < i; u++)
					if (PicoPatches[u].addr == addr) break;
				if (u == i)
					*(unsigned short *)(Pico.rom + addr) = PicoPatches[i].data_old;
			}
			// fprintf(stderr, "patched %i: %06x:%04x\n", PicoPatches[i].active, addr,
			//	*(unsigned short *)(Pico.rom + addr));
		}
		else
		{
			/* TODO? */
		}
	}
}

