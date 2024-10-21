/*

Copyright (c) 2011, 2012, Simon Howard

Permission to use, copy, modify, and/or distribute this software
for any purpose with or without fee is hereby granted, provided
that the above copyright notice and this permission notice appear
in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <inttypes.h>

#include "lib/crc16.h"

typedef struct {
	uint8_t data[16];
	uint16_t crc;
	unsigned int change_bit;
} TestSequence;

static TestSequence test_data[] = {
	{ { 0xe5, 0x8a, 0xa7, 0x73, 0x01, 0xec, 0x50, 0xe2,
	    0x3e, 0x0e, 0x02, 0x9e, 0x38, 0xe0, 0xc3, 0x78},
	  0xBF43, 97
	},
	{ { 0xb2, 0x4b, 0x17, 0x9f, 0x4d, 0x13, 0x4a, 0x3e,
	    0xaa, 0x93, 0x5e, 0xcb, 0xff, 0xc5, 0x05, 0x38},
	  0x5D13, 57
	},
	{ { 0xc1, 0x87, 0x63, 0xa2, 0x62, 0xbd, 0x50, 0x38,
	    0x18, 0x54, 0x78, 0x15, 0xaa, 0x52, 0x03, 0xa3},
	  0xDF44, 101
	},
	{ { 0x28, 0x8f, 0xf6, 0x98, 0xb5, 0xac, 0xc0, 0x72,
	    0xaa, 0x28, 0x89, 0x71, 0x38, 0xfe, 0xde, 0xba},
	  0xBF06, 36
	},
	{ { 0x39, 0x97, 0x18, 0x48, 0xc5, 0x08, 0xea, 0x37,
	    0xdb, 0xe4, 0xfb, 0x74, 0x91, 0xfa, 0x4e, 0x8f},
	  0x7EBA, 63
	},
	{ { 0x55, 0x70, 0xd5, 0x25, 0x77, 0xab, 0x3e, 0x89,
	    0x1e, 0xc4, 0x25, 0x0b, 0xe0, 0x26, 0xb4, 0xb3},
	  0x3396, 25
	},
	{ { 0xde, 0xfb, 0x9d, 0x4b, 0xa4, 0x70, 0x0e, 0xf0,
	    0xca, 0xcb, 0x60, 0xd4, 0x95, 0x27, 0xa9, 0x67},
	  0xBFCA, 0
	},
	{ { 0xce, 0xdc, 0x03, 0x02, 0xf0, 0x23, 0xcd, 0x77,
	    0x03, 0x74, 0xd0, 0xa3, 0x42, 0x45, 0x4f, 0x6a},
	  0xB42E, 127
	},
	{ { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff},
	  0x7040, 8
	},
	{ { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
	  0x0000, 77
	},
};

// Test that a simple CRC of the data block matches the expected CRC.

static void test_crc16_pass(void)
{
	unsigned int i;
	uint16_t crc;

	for (i = 0; i < sizeof(test_data) / sizeof(TestSequence); ++i) {
		crc = 0;
		lha_crc16_buf(&crc, test_data[i].data, 16);
		assert(test_data[i].crc == crc);
	}
}

// Test CRC match, but performed as several calls to the CRC16 function.

static void test_crc16_progressive(void)
{
	unsigned int remaining, bytes;
	unsigned int i;
	uint16_t crc;

	for (i = 0; i < sizeof(test_data) / sizeof(TestSequence); ++i) {
		crc = 0;
		remaining = 16;

		// Calculate as part of several calls to process the full
		// chunk of data:

		while (remaining > 0) {
			bytes = i + 1;

			if (bytes > remaining) {
				bytes = remaining;
			}

			lha_crc16_buf(&crc, test_data[i].data + 16 - remaining,
			              bytes);
			remaining -= bytes;
		}

		assert(test_data[i].crc == crc);
	}
}

// Test CRC fail.

static void test_crc16_fail(void)
{
	uint8_t data[16];
	unsigned int i, bit;
	uint16_t crc;

	for (i = 0; i < sizeof(test_data) / sizeof(TestSequence); ++i) {
		memcpy(data, test_data[i].data, 16);

		// Change 1 bit:

		bit = test_data[i].change_bit;
		data[bit / 8] ^= (uint8_t) (1 << (bit % 8));

		// Check CRC fails:

		crc = 0;
		lha_crc16_buf(&crc, data, 16);
		assert(test_data[i].crc != crc);
	}
}

// Test CRC of empty block.

static void test_crc16_empty(void)
{
	uint16_t crc;

	crc = 0;

	lha_crc16_buf(&crc, NULL, 0);

	assert(crc == 0);
}

int main(int argc, char *argv[])
{
	test_crc16_pass();
	test_crc16_progressive();
	test_crc16_fail();
	test_crc16_empty();

	return 0;
}

