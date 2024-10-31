/*
 * :make compdecomp CFLAGS=-Wall LDFLAGS=-lz
 */
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>

#define MEM_LIMIT (128*1024*1024)

int main(int argc, char *argv[])
{
	void *pi, *po = NULL;
	FILE *fi, *fo;
	int ret, si, so;

	if (argc != 4)
	{
		printf("usage: %s <0|1> <infile> <outfile>\n", argv[0]);
		return 1;
	}

	fi = fopen(argv[2], "rb");
	if (fi == NULL) return 2;

	fseek(fi, 0, SEEK_END);
	si = ftell(fi);
	fseek(fi, 0, SEEK_SET);
	pi = malloc(si);
	if (pi == NULL) return 3;
	fread(pi, 1, si, fi);
	fclose(fi);

	if (atoi(argv[1]))
	{
		// decompress
		so = si;
		do
		{
			so *= 16;
			if (so > MEM_LIMIT) return 4;
			po = realloc(po, so);
			if (po == NULL) return 5;
			ret = uncompress(po, (uLongf *) &so, pi, si);
		}
		while (ret == Z_BUF_ERROR);
	}
	else
	{
		// compress
		so = si + 1024;
		po = malloc(so);
		if (po == NULL) return 5;
		ret = compress2(po, (uLongf *) &so, pi, si, Z_BEST_COMPRESSION);
	}

	if (ret == Z_OK)
	{
		fo = fopen(argv[3], "wb");
		if (fo == NULL) return 6;
		fwrite(po, 1, so, fo);
		fclose(fo);
	}

	printf("result %i, size %i -> %i\n", ret, si, so);

	return ret;
}

