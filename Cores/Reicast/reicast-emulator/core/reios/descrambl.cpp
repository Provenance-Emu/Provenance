/*
	Based on work of Marcus Comstedt
	http://mc.pp.se, http://mc.pp.se/dc/sw.html, http://mc.pp.se/dc/files/scramble.c
	License: Gotta verify

	Adapted by Stefanos Kornilios Mitsis Poiitidis (skmp) for reicast
*/

#include "descrambl.h"
#include <algorithm>

#define MAXCHUNK (2048*1024)

static unsigned int seed;

void my_srand(unsigned int n)
{
	seed = n & 0xffff;
}

unsigned int my_rand()
{
	seed = (seed * 2109 + 9273) & 0x7fff;
	return (seed + 0xc000) & 0xffff;
}

/*
void load(FILE *fh, unsigned char *ptr, unsigned long sz)
{
	if (fread(ptr, 1, sz, fh) != sz)
	{
		fprintf(stderr, "Read error!\n");
		exit(1);
	}
}
*/

void load_chunk(u8* &src, unsigned char *ptr, unsigned long sz)
{
	verify(sz <= MAXCHUNK);

	static int idx[MAXCHUNK / 32];

	int i;

	/* Convert chunk size to number of slices */
	sz /= 32;

	/* Initialize index table with unity,
	so that each slice gets loaded exactly once */
	for (i = 0; i < sz; i++)
		idx[i] = i;

	for (i = sz - 1; i >= 0; --i)
	{
		/* Select a replacement index */
		int x = (my_rand() * i) >> 16;

		/* Swap */
		swap(idx[i], idx[x]);

		/*
			int tmp = idx[i];
			idx[i] = idx[x];
			idx[x] = tmp;
		*/

		/* Load resulting slice */
		//load(fh, ptr + 32 * idx[i], 32);
		memcpy(ptr + 32 * idx[i], src, 32);
		src += 32;
	}
}

void descrambl_buffer(u8* src, unsigned char *dst, unsigned long filesz)
{
	unsigned long chunksz;

	my_srand(filesz);

	/* Descramble 2 meg blocks for as long as possible, then
	gradually reduce the window down to 32 bytes (1 slice) */
	for (chunksz = MAXCHUNK; chunksz >= 32; chunksz >>= 1)
		while (filesz >= chunksz)
		{
			load_chunk(src, dst, chunksz);
			filesz -= chunksz;
			dst += chunksz;
		}

	/* Load final incomplete slice */
	if (filesz)
		memcpy(dst, src, filesz);
}

void descrambl_file(u32 FAD, u32 file_size, u8* dst) {
	u8* temp_file = new u8[file_size + 2048];
	libGDR_ReadSector(temp_file, FAD, (file_size+2047) / 2048, 2048);

	descrambl_buffer(temp_file, dst, file_size);

	delete[] temp_file;
}