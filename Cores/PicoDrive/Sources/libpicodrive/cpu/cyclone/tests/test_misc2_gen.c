#include <stdio.h>
#include <stdlib.h>
#include <time.h>


static FILE *f;

#define bswap16(x) (x=(unsigned short)((x<<8)|(x>>8)))
#define bswap32(x) (x=((x<<24)|((x<<8)&0xff0000)|((x>>8)&0x00ff00)|((unsigned)x>>24)))

static void write_op(unsigned short op, unsigned short word0, unsigned short word1, unsigned short word2)
{
	bswap16(op);
	bswap16(word0);
	bswap16(word1);
	bswap16(word2);

	fwrite(&op,    1, sizeof(op), f);
	fwrite(&word0, 1, sizeof(word0), f);
	fwrite(&word1, 1, sizeof(word1), f);
	fwrite(&word2, 1, sizeof(word2), f);
}

static void write32(unsigned int a)
{
	bswap32(a);
	fwrite(&a,     1, sizeof(a),  f);
}

static int op_check(unsigned short op)
{
	if ((op&0xf000) == 0x6000) return 0; // Bxx
	if ((op&0xf0f8) == 0x50c8) return 0; // DBxx
	if ((op&0xff80) == 0x4e80) return 0; // Jsr
	if ((op&0xf000) == 0xa000) return 0; // a-line
	if ((op&0xf000) == 0xf000) return 0; // f-line
	if ((op&0xfff8)==0x4e70&&op!=0x4e71&&op!=0x4e76) return 0; // reset, rte, rts

	if ((op&0x3f) >= 0x28) op = (op&~0x3f) | (rand() % 0x28);
	return 1;
}

static unsigned short safe_rand(void)
{
	unsigned short op;

	/* avoid branch opcodes */
	do
	{
		op = rand();
	}
	while (!op_check(op));

	return op;
}

int main()
{
	int i, op;

	srand(time(0));

	f = fopen("test_misc2.bin", "wb");
	if (!f) return 1;

	write32(0x00ff8000); // stack
	write32(0x300); // IP

	for (i=0x100/4-2; i; i--)
	{
		write32(0x200+i*4); // exception vectors
	}

	for (i=0x100/4; i; i--)
	{
		write32(0); // pad
	}

	for (i=0x100/4; i; i--)
	{
		write32(0x4e734e73); // fill with rte instructions
	}

	for (op = 0; op < 0x10000; op++)
	{
		if ((op&0xf000) == 0x6000) // Bxx
		{
			if ((op&0x00ff) == 0)
				write_op(op, 6, 0, 0);
		}
		else if ((op&0xf0f8)==0x50c8) // DBxx
		{
			write_op(op, 6, 0, 0);
		}
		else if ((op&0xff80)==0x4e80) // Jsr
		{
			int addr = 0x300 + op*8 + 8;
			if ((op&0x3f) == 0x39)
				write_op(op, addr >> 16, addr & 0xffff, 0);
		}
		else if ((op&0xf000)==0xa000 || (op&0xf000)==0xf000) // a-line, f-line
		{
			if (op != 0xa000 && op != 0xf000) continue;
		}
		else if ((op&0xfff8)==0x4e70&&op!=0x4e71&&op!=0x4e76); // rte, rts, stop, reset
		else
		{
			write_op(op, safe_rand(), safe_rand(), safe_rand());
		}
	}

	// jump to the beginning
	write_op(0x4ef8, 0x300, 0x4ef8, 0x300);
	write_op(0x4ef8, 0x300, 0x4ef8, 0x300);

	fclose(f);
	return 0;
}

