#include <stdio.h>
#include <string.h>

static FILE *fo = NULL;

static void out(int r, int is_last)
{
	if (!is_last)
	{
		fprintf(fo, "    or      $t%i, $t%i, $a2\n", r, r);
		fprintf(fo, "    sb      $t%i, %i($a0)\n", r, r);
	}
	else
	{
		fprintf(fo, "    or      $t%i, $t%i, $a2\n", r, r);
		fprintf(fo, "    jr      $ra\n");
		fprintf(fo, "    sb      $t%i, %i($a0)\n", r, r);
	}
}

unsigned char pattern_db[0x100];

static int check_label(unsigned char i)
{
	if (!pattern_db[i]) {
		fprintf(fo, "tile%i%i%i%i%i%i%i%i:\n", (i&0x80)?1:0, (i&0x40)?1:0, (i&0x20)?1:0, (i&0x10)?1:0,
			(i&0x08)?1:0, (i&0x04)?1:0, (i&0x02)?1:0, (i&0x01)?1:0);
		pattern_db[i] = 1;
		return 0;
	}

	return 1;
}


int main()
{
	int i;

	fo = fopen("out.s", "w");
	if (!fo) return 1;

	memset(pattern_db, 0, sizeof(pattern_db));

	for (i = 0xff; i > 0; i--)
	{
		if (check_label(i)) continue;

		if (i & 0x01) out(0, !(i&0xfe));
		check_label(i&0xfe);
		if (i & 0x02) out(1, !(i&0xfc));
		check_label(i&0xfc);
		if (i & 0x04) out(2, !(i&0xf8));
		check_label(i&0xf8);
		if (i & 0x08) out(3, !(i&0xf0));
		check_label(i&0xf0);
		if (i & 0x10) out(4, !(i&0xe0));
		check_label(i&0xe0);
		if (i & 0x20) out(5, !(i&0xc0));
		check_label(i&0xc0);
		if (i & 0x40) out(6, !(i&0x80));
		check_label(i&0x80);
		if (i & 0x80) out(7, 1);
	}

	fclose(fo);

	return 0;
}

