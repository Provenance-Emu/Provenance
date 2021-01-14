/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include <ctype.h>
#include "snes9x.h"
#include "memmap.h"
#include "cheats.h"

#define WRAM_BITS	ALL_BITS
#define SRAM_BITS	ALL_BITS + (0x20000 >> 5)
#define IRAM_BITS	ALL_BITS + (0x30000 >> 5)

#define BIT_CLEAR(a, v)	(a)[(v) >> 5] &= ~(1 << ((v) & 31))

#define TEST_BIT(a, v)	((a)[(v) >> 5] & (1 << ((v) & 31)))

#define _S9XCHTC(c, a, b) \
	((c) == S9X_LESS_THAN             ? (a) <  (b) : \
	 (c) == S9X_GREATER_THAN          ? (a) >  (b) : \
	 (c) == S9X_LESS_THAN_OR_EQUAL    ? (a) <= (b) : \
	 (c) == S9X_GREATER_THAN_OR_EQUAL ? (a) >= (b) : \
	 (c) == S9X_EQUAL                 ? (a) == (b) : \
	                                    (a) != (b))

#define _S9XCHTD(s, m, o) \
	((s) == S9X_8_BITS  ? ((uint8)   (*((m) + (o)))) : \
	 (s) == S9X_16_BITS ? ((uint16)  (*((m) + (o)) + (*((m) + (o) + 1) << 8))) : \
	 (s) == S9X_24_BITS ? ((uint32)  (*((m) + (o)) + (*((m) + (o) + 1) << 8) + (*((m) + (o) + 2) << 16))) : \
	                      ((uint32)  (*((m) + (o)) + (*((m) + (o) + 1) << 8) + (*((m) + (o) + 2) << 16) + (*((m) + (o) + 3) << 24))))

#define _S9XCHTDS(s, m, o) \
	((s) == S9X_8_BITS  ?  ((int8)   (*((m) + (o)))) : \
	 (s) == S9X_16_BITS ?  ((int16)  (*((m) + (o)) + (*((m) + (o) + 1) << 8))) : \
	 (s) == S9X_24_BITS ? (((int32) ((*((m) + (o)) + (*((m) + (o) + 1) << 8) + (*((m) + (o) + 2) << 16)) << 8)) >> 8): \
                           ((int32)  (*((m) + (o)) + (*((m) + (o) + 1) << 8) + (*((m) + (o) + 2) << 16) + (*((m) + (o) + 3) << 24))))

static bool8 S9xAllHex (const char *, int);


static bool8 S9xAllHex (const char *code, int len)
{
	for (int i = 0; i < len; i++)
		if ((code[i] < '0' || code[i] > '9') && (code[i] < 'a' || code[i] > 'f') && (code[i] < 'A' || code[i] > 'F'))
			return (FALSE);

	return (TRUE);
}

const char * S9xProActionReplayToRaw (const char *code, uint32 &address, uint8 &byte)
{
	uint32	data = 0;

	if (strlen(code) != 8 || !S9xAllHex(code, 8) || sscanf(code, "%x", &data) != 1)
		return ("Invalid Pro Action Replay code - should be 8 hex digits in length.");

	address = data >> 8;
	byte = (uint8) data;

	return (NULL);
}

const char * S9xGoldFingerToRaw (const char *code, uint32 &address, bool8 &sram, uint8 &num_bytes, uint8 bytes[3])
{
	char	tmp[15];
	int		i;

	if (strlen(code) != 14)
		return ("Invalid Gold Finger code - should be 14 hex digits in length.");

	strncpy(tmp, code, 5);
	tmp[5] = 0;
	if (sscanf(tmp, "%x", &address) != 1)
		return ("Invalid Gold Finger code.");

	// Correct GoldFinger Address
	address = (address & 0x7FFF) | ((address & 0x7F8000) << 1) | 0x8000;

	for (i = 0; i < 3; i++)
	{
		unsigned int	byte;

		strncpy(tmp, code + 5 + i * 2, 2);
		tmp[2] = 0;
		if (sscanf(tmp, "%x", &byte) != 1)
			break;
		bytes[i] = (uint8) byte;
	}

	num_bytes = i;
	sram = code[13] == '1';

	return (NULL);
}

const char * S9xGameGenieToRaw (const char *code, uint32 &address, uint8 &byte)
{
	char	new_code[12];

	if (strlen(code) != 9 || *(code + 4) != '-' || !S9xAllHex(code, 4) || !S9xAllHex(code + 5, 4))
		return ("Invalid Game Genie(tm) code - should be 'xxxx-xxxx'.");

	strcpy(new_code, "0x");
	strncpy(new_code + 2, code, 4);
	strcpy(new_code + 6, code + 5);

	static const char	*real_hex  = "0123456789ABCDEF";
	static const char	*genie_hex = "DF4709156BC8A23E";

	for (int i = 2; i < 10; i++)
	{
		if (islower(new_code[i]))
			new_code[i] = toupper(new_code[i]);

		int j;
		for (j = 0; j < 16; j++)
		{
			if (new_code[i] == genie_hex[j])
			{
				new_code[i] = real_hex[j];
				break;
			}
		}

		if (j == 16)
			return ("Invalid hex-character in Game Genie(tm) code.");
	}

	uint32	data = 0;
	sscanf(new_code, "%x", &data);
	byte = (uint8) (data >> 24);
	address = data & 0xffffff;
	address = ((address & 0x003c00) << 10) +
			  ((address & 0x00003c) << 14) +
			  ((address & 0xf00000) >>  8) +
			  ((address & 0x000003) << 10) +
			  ((address & 0x00c000) >>  6) +
			  ((address & 0x0f0000) >> 12) +
			  ((address & 0x0003c0) >>  6);

	return (NULL);
}

void S9xStartCheatSearch (SCheatData *d)
{
	memmove(d->CWRAM, d->RAM, 0x20000);
	memmove(d->CSRAM, d->SRAM, 0x10000);
	memmove(d->CIRAM, &d->FillRAM[0x3000], 0x2000);
	memset((char *) d->ALL_BITS, 0xff, 0x32000 >> 3);
}

void S9xSearchForChange (SCheatData *d, S9xCheatComparisonType cmp, S9xCheatDataSize size, bool8 is_signed, bool8 update)
{
	int	l, i;

	switch (size)
	{
		case S9X_8_BITS:	l = 0; break;
		case S9X_16_BITS:	l = 1; break;
		case S9X_24_BITS:	l = 2; break;
		default:
		case S9X_32_BITS:	l = 3; break;
	}

	if (is_signed)
	{
		for (i = 0; i < 0x20000 - l; i++)
		{
			if (TEST_BIT(d->WRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTDS(size, d->RAM, i), _S9XCHTDS(size, d->CWRAM, i)))
			{
				if (update)
					d->CWRAM[i] = d->RAM[i];
			}
			else
				BIT_CLEAR(d->WRAM_BITS, i);
		}

		for (i = 0; i < 0x10000 - l; i++)
		{
			if (TEST_BIT(d->SRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTDS(size, d->SRAM, i), _S9XCHTDS(size, d->CSRAM, i)))
			{
				if (update)
					d->CSRAM[i] = d->SRAM[i];
			}
			else
				BIT_CLEAR(d->SRAM_BITS, i);
		}

		for (i = 0; i < 0x2000 - l; i++)
		{
			if (TEST_BIT(d->IRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTDS(size, d->FillRAM + 0x3000, i), _S9XCHTDS(size, d->CIRAM, i)))
			{
				if (update)
					d->CIRAM[i] = d->FillRAM[i + 0x3000];
			}
			else
				BIT_CLEAR(d->IRAM_BITS, i);
		}
	}
	else
	{
		for (i = 0; i < 0x20000 - l; i++)
		{
			if (TEST_BIT(d->WRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTD(size, d->RAM, i), _S9XCHTD(size, d->CWRAM, i)))
			{
				if (update)
					d->CWRAM[i] = d->RAM[i];
			}
			else
				BIT_CLEAR(d->WRAM_BITS, i);
		}

		for (i = 0; i < 0x10000 - l; i++)
		{
			if (TEST_BIT(d->SRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTD(size, d->SRAM, i), _S9XCHTD(size, d->CSRAM, i)))
			{
				if (update)
					d->CSRAM[i] = d->SRAM[i];
			}
			else
				BIT_CLEAR(d->SRAM_BITS, i);
		}

		for (i = 0; i < 0x2000 - l; i++)
		{
			if (TEST_BIT(d->IRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTD(size, d->FillRAM + 0x3000, i), _S9XCHTD(size, d->CIRAM, i)))
			{
				if (update)
					d->CIRAM[i] = d->FillRAM[i + 0x3000];
			}
			else
				BIT_CLEAR(d->IRAM_BITS, i);
		}
	}

	for (i = 0x20000 - l; i < 0x20000; i++)
		BIT_CLEAR(d->WRAM_BITS, i);

	for (i = 0x10000 - l; i < 0x10000; i++)
		BIT_CLEAR(d->SRAM_BITS, i);
}

void S9xSearchForValue (SCheatData *d, S9xCheatComparisonType cmp, S9xCheatDataSize size, uint32 value, bool8 is_signed, bool8 update)
{
	int l, i;

	switch (size)
	{
		case S9X_8_BITS:	l = 0; break;
		case S9X_16_BITS:	l = 1; break;
		case S9X_24_BITS:	l = 2; break;
		default:
		case S9X_32_BITS:	l = 3; break;
	}

	if (is_signed)
	{
		for (i = 0; i < 0x20000 - l; i++)
		{
			if (TEST_BIT(d->WRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTDS(size, d->RAM, i), (int32) value))
			{
				if (update)
					d->CWRAM[i] = d->RAM[i];
			}
			else
				BIT_CLEAR(d->WRAM_BITS, i);
		}

		for (i = 0; i < 0x10000 - l; i++)
		{
			if (TEST_BIT(d->SRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTDS(size, d->SRAM, i), (int32) value))
			{
				if (update)
					d->CSRAM[i] = d->SRAM[i];
			}
			else
				BIT_CLEAR(d->SRAM_BITS, i);
		}

		for (i = 0; i < 0x2000 - l; i++)
		{
			if (TEST_BIT(d->IRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTDS(size, d->FillRAM + 0x3000, i), (int32) value))
			{
				if (update)
					d->CIRAM[i] = d->FillRAM[i + 0x3000];
			}
			else
				BIT_CLEAR(d->IRAM_BITS, i);
		}
	}
	else
	{
		for (i = 0; i < 0x20000 - l; i++)
		{
			if (TEST_BIT(d->WRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTD(size, d->RAM, i), value))
			{
				if (update)
					d->CWRAM[i] = d->RAM[i];
			}
			else
				BIT_CLEAR(d->WRAM_BITS, i);
		}

		for (i = 0; i < 0x10000 - l; i++)
		{
			if (TEST_BIT(d->SRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTD(size, d->SRAM, i), value))
			{
				if (update)
					d->CSRAM[i] = d->SRAM[i];
			}
			else
				BIT_CLEAR(d->SRAM_BITS, i);
		}

		for (i = 0; i < 0x2000 - l; i++)
		{
			if (TEST_BIT(d->IRAM_BITS, i) && _S9XCHTC(cmp, _S9XCHTD(size, d->FillRAM + 0x3000, i), value))
			{
				if (update)
					d->CIRAM[i] = d->FillRAM[i + 0x3000];
			}
			else
				BIT_CLEAR(d->IRAM_BITS, i);
		}
	}

	for (i = 0x20000 - l; i < 0x20000; i++)
		BIT_CLEAR(d->WRAM_BITS, i);

	for (i = 0x10000 - l; i < 0x10000; i++)
		BIT_CLEAR(d->SRAM_BITS, i);
}

void S9xSearchForAddress (SCheatData *d, S9xCheatComparisonType cmp, S9xCheatDataSize size, uint32 value, bool8 update)
{
	int	l, i;

	switch (size)
	{
		case S9X_8_BITS:	l = 0; break;
		case S9X_16_BITS:	l = 1; break;
		case S9X_24_BITS:	l = 2; break;
		default:
		case S9X_32_BITS:	l = 3; break;
	}

	for (i = 0; i < 0x20000 - l; i++)
	{
		if (TEST_BIT(d->WRAM_BITS, i) && _S9XCHTC(cmp, i, (int32) value))
		{
			if (update)
				d->CWRAM[i] = d->RAM[i];
		}
		else
			BIT_CLEAR(d->WRAM_BITS, i);
	}

	for (i = 0; i < 0x10000 - l; i++)
	{
		if (TEST_BIT(d->SRAM_BITS, i) && _S9XCHTC(cmp, i + 0x20000, (int32) value))
		{
			if (update)
				d->CSRAM[i] = d->SRAM[i];
		}
		else
			BIT_CLEAR(d->SRAM_BITS, i);
	}

	for (i = 0; i < 0x2000 - l; i++)
	{
		if (TEST_BIT(d->IRAM_BITS, i) && _S9XCHTC(cmp, i + 0x30000, (int32) value))
		{
			if (update)
				d->CIRAM[i] = d->FillRAM[i + 0x3000];
		}
		else
			BIT_CLEAR(d->IRAM_BITS, i);
	}

	for (i = 0x20000 - l; i < 0x20000; i++)
		BIT_CLEAR(d->WRAM_BITS, i);

	for (i = 0x10000 - l; i < 0x10000; i++)
		BIT_CLEAR(d->SRAM_BITS, i);
}

void S9xOutputCheatSearchResults (SCheatData *d)
{
	int	i;

	for (i = 0; i < 0x20000; i++)
	{
		if (TEST_BIT(d->WRAM_BITS, i))
			printf("WRAM: %05x: %02x\n", i, d->RAM[i]);
	}

	for (i = 0; i < 0x10000; i++)
	{
		if (TEST_BIT(d->SRAM_BITS, i))
			printf("SRAM: %04x: %02x\n", i, d->SRAM[i]);
	}

	for (i = 0; i < 0x2000; i++)
	{
		if (TEST_BIT(d->IRAM_BITS, i))
			printf("IRAM: %05x: %02x\n", i, d->FillRAM[i + 0x3000]);
	}
}
