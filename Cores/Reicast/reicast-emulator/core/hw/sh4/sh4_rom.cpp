#include "types.h"
#include "sh4_rom.h"

u32 sin_coefs[0x8000]=
{
	#include "fsca-table.h"
};

f32_x2 sin_table[0x10000];

void sh4rom_init()
{
	for (int i=0x0000;i<0x10000;i++)
	{
		if (i<0x8000)
			sin_table[i].u[0]=(f32&)sin_coefs[i];
		else
			sin_table[i].u[0]=-(f32&)sin_coefs[i-0x8000];
	}


	verify(sin_table[0x8000].u[0]==0);//this is required by Ikaruga, for the bullets to behave normally

	for (int i=0x0000;i<0x10000;i++)
	{
		sin_table[i].u[1]=sin_table[(i+0x4000)&0xFFFF].u[0];//fill in [1] (interleave sin/cos)
	}
}

static OnLoad ol_sh4rom(&sh4rom_init);