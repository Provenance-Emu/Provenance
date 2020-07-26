#include <stdio.h>
#include <stdlib.h>

static unsigned char *ptr[100];
static int ptrc;

#define M 256

static struct 
{
	int pos;
	int cnt;
} max[M];


static int active[100];
static int activec;

static int active_pos;

static void
fill_max(void)
{
	int i, n, b, c, u;


	memset(max, 0, sizeof(max));

	for (b = 0; b < 0x800; b++)
	{
		c = 0;
		for (i = 0; i < activec; i++)
		{
			for (u = i + 1; u < activec; u++)
			{
				if (ptr[active[i]][b] == ptr[active[u]][b])
				{
					goto bad;
				}
			}
			c ++;
bad:;
		}

		for (i = 0; i < M; i ++)
		{
			if (max[i].cnt < c)
			{
				max[i].pos = b;
				max[i].cnt = c;
				break;
			}
		}
	}
}

static void
select_max(void)
{
	int i, m, c;

	m = max[0].cnt;

	if (max[0].cnt == 1)
	{
		printf("no solution!\n");
		exit(1);
	}
	c = 0;
	for (i = 0; i < M; i++)
	{
		if (m == max[i].cnt)
		{
			c++;
		}
	}

	i = random() % c;
	active_pos = max[i].pos;
	printf("0x%03X (%d) ", active_pos, max[i].cnt);
}


static void
search_active(void)
{
	int i, j, a;
	int tmpa[100];


	a = 0;
	for (i = 0; i < activec; i++)
	{
		for (j = 0; j < activec; j++)
		{
			if (i == j)
			{
				continue;
			}
			if (ptr[active[i]][active_pos] ==
				ptr[active[j]][active_pos])
			{
				tmpa[a] = active[i];
				a++;
				break;
			}
		}
	}

	printf("(%d) ", a);
	for (i = 0; i < activec; i++)
	{
		printf("%02X ", ptr[active[i]][active_pos]);
	}

	printf("\n");

	memcpy(active, tmpa, sizeof(active));
	activec = a;
}

int
main(int argc, char *argv[])
{
	int i, u, b, c;
	FILE *f;


	srandom(time(NULL));

	ptrc = argc - 1;

	/*
	 * read data
	 */

	for (i = 0; i < ptrc; i++)
	{
		ptr[i] = malloc(0x800);
		f = fopen(argv[i + 1], "rb");
		fread(ptr[i], 1, 0x800, f);
		fclose(f);
		active[i] = i;
	}
	activec = ptrc;

	while (activec > 0)
	{
		fill_max();
		select_max();
		search_active();
	}

	return 0;
}

