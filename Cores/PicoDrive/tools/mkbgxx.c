#include <stdio.h>
#include <zlib.h>

static unsigned char buff[0x10140];
static unsigned char buff2[0x10140];

static void do_file(const char *ifn, const char *ofn)
{
	FILE *fi, *fo;
	int ret;
	unsigned long dlen = sizeof(buff2);

	fi = fopen(ifn, "rb");
	if (!fi) return;
	fseek(fi, 0x10020, SEEK_SET);
	fread(buff, 1, 0x10000, fi);
	fseek(fi, 0x2000, SEEK_CUR);
	fread(buff + 0x10000, 1, 0x80*2, fi);
	fseek(fi, 0x221a0, SEEK_SET);
	fread(buff + 0x10100, 1, 0x40, fi);
	fclose(fi);

	ret = compress2(buff2, &dlen, buff, sizeof(buff), Z_BEST_COMPRESSION);
	if (ret) { printf("compress2 failed with %i\n", ret); return; }

	fo = fopen(ofn, "wb");
	if (!fo) return;
	fwrite(buff2, 1, dlen, fo);
	fclose(fo);

	printf("%s: %6i -> %6li\n", ofn, sizeof(buff), dlen);
}

int main(int argc, char *argv[])
{
	if (argc != 3) return 1;

	do_file(argv[1], "bg40.bin");
	do_file(argv[2], "bg32.bin");

	return 0;
}

