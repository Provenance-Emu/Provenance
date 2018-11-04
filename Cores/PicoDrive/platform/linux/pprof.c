#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#include <pico/pico_int.h>

struct pp_counters *pp_counters;
static int shmemid;

void pprof_init(void)
{
	int this_is_new_shmem = 1;
	key_t shmemkey;
	void *shmem;

#ifndef PPROF_TOOL
	unsigned int tmp = pprof_get_one();
	printf("pprof: measured diff is %u\n", pprof_get_one() - tmp);
#endif

	shmemkey = ftok(".", 0x02ABC32E);
	if (shmemkey == -1)
	{
		perror("pprof: ftok failed");
		return;
	}

#ifndef PPROF_TOOL
	shmemid = shmget(shmemkey, sizeof(*pp_counters),
		IPC_CREAT | IPC_EXCL | 0644);
	if (shmemid == -1)
#endif
	{
		shmemid = shmget(shmemkey, sizeof(*pp_counters),
				0644);
		if (shmemid == -1)
		{
			perror("pprof: shmget failed");
			return;
		}
		this_is_new_shmem = 0;
	}

	shmem = shmat(shmemid, NULL, 0);
	if (shmem == (void *)-1)
	{
		perror("pprof: shmat failed");
		return;
	}

	pp_counters = shmem;
	if (this_is_new_shmem) {
		memset(pp_counters, 0, sizeof(*pp_counters));
		printf("pprof: pp_counters cleared.\n");
	}
}

void pprof_finish(void)
{
	shmdt(pp_counters);
	shmctl(shmemid, IPC_RMID, NULL);
}

#ifdef PPROF_TOOL

#define IT(n) { pp_##n, #n }
static const struct {
	enum pprof_points pp;
	const char *name;
} pp_tab[] = {
	IT(main),
	IT(frame),
	IT(draw),
	IT(sound),
	IT(m68k),
	IT(z80),
	IT(msh2),
	IT(ssh2),
	IT(dummy),
};

int main(int argc, char *argv[])
{
	unsigned long long old[pp_total_points], new[pp_total_points];
	int base = 0;
	int l, i;

	pprof_init();
	if (pp_counters == NULL)
		return 1;

	if (argc >= 2)
		base = atoi(argv[1]);

	memset(old, 0, sizeof(old));
	for (l = 0; ; l++)
	{
		if ((l & 0x1f) == 0) {
			for (i = 0; i < ARRAY_SIZE(pp_tab); i++)
				printf("%6s ", pp_tab[i].name);
			printf("\n");
		}

		memcpy(new, pp_counters->counter, sizeof(new));
		for (i = 0; i < ARRAY_SIZE(pp_tab); i++)
		{
			unsigned long long idiff = new[i] - old[i];
			unsigned long long bdiff = (new[base] - old[base]) | 1;
			printf("%6.2f ", (double)idiff * 100.0 / bdiff);
		}
		printf("\n");
		memcpy(old, new, sizeof(old));

		if (argc < 3)
			break;
		usleep(atoi(argv[2]));
	}

	return 0;
}

#endif // PPROF_TOOL

