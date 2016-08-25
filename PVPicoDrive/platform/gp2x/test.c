#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h>
#include "gp2x.h"

void spend_cycles(int c);

int main(void)
{
	struct timeval tval; // timing
	int thissec = 0, frames_done = 0;

	gp2x_init();

	for (;;)
	{
		gettimeofday(&tval, 0);

		if(thissec != tval.tv_sec)
		{
			thissec = tval.tv_sec;

			printf("frames_done: %i\n", frames_done);
			frames_done = 0;
		}


		//gp2x_video_wait_vsync();
		//usleep(1); // sleeps a minimum of ~20ms
		//gp2x_video_flip(); // can be called ~430000 times/sec
		spend_cycles(1000);
		frames_done++;
	}

}

