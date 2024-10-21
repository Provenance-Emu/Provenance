/*
    -----------------------------------------------------------------------
    sjpcm.h - SjPCM EE-side prototypes. (c) Nick Van Veen (aka Sjeep), 2002
	-----------------------------------------------------------------------

    This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/

#ifndef _SJPCM_H
#define _SJPCM_H

#define	SJPCM_IRX		0xB0110C5
#define SJPCM_PUTS		0x01
#define	SJPCM_INIT		0x02
#define SJPCM_PLAY		0x03
#define SJPCM_PAUSE		0x04
#define SJPCM_SETVOL	0x05
#define SJPCM_ENQUEUE	0x06
#define SJPCM_CLEARBUFF	0x07
#define SJPCM_QUIT		0x08
#define SJPCM_GETAVAIL  0x09
#define SJPCM_GETBUFFD  0x10

void SjPCM_Puts(char *format, ...);
//int SjPCM_Init(int sync);
int SjPCM_Init(int sync, int buffersize, int maxenqueuesamples);

void SjPCM_Enqueue(short *left, short *right, int size, int wait);
void SjPCM_Play();
void SjPCM_Pause();
void SjPCM_Setvol(unsigned int volume);
void SjPCM_Clearbuff();
int SjPCM_Available();
int SjPCM_Buffered();
void SjPCM_Quit();


void SjPCM_BufferedAsyncStart();
int SjPCM_BufferedAsyncGet();
void SjPCM_EnqueueAsync(short *left, short *right, int size);
void SjPCM_Wait();

int SjPCM_IsInitialized();


#endif // _SJPCM_H
